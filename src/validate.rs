//! Validate command - checks links in generated PDF resumes.

use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use colored::Colorize;
use lopdf::Document;
use regex::Regex;
use reqwest::blocking::Client;
use reqwest::header::USER_AGENT;

use crate::common::{
    collect_pdfs, ProjectPaths, DEFAULT_HTTP_TIMEOUT_SECS, PERSONAL_DOMAINS, WHITELISTED_HOSTS,
};

/// Extract URIs from PDF annotations.
fn extract_links_from_pdf(path: &Path) -> Result<Vec<(usize, String)>> {
    let doc =
        Document::load(path).with_context(|| format!("Failed to load PDF: {}", path.display()))?;

    let mut links = Vec::new();

    for (page_num, page_id) in doc.get_pages() {
        if let Ok(page) = doc.get_object(page_id) {
            if let Ok(page_dict) = page.as_dict() {
                if let Ok(annots) = page_dict.get(b"Annots") {
                    let annots_array = match annots {
                        lopdf::Object::Array(arr) => arr.clone(),
                        lopdf::Object::Reference(r) => {
                            if let Ok(lopdf::Object::Array(arr)) = doc.get_object(*r) {
                                arr.clone()
                            } else {
                                continue;
                            }
                        }
                        _ => continue,
                    };

                    for annot_ref in annots_array {
                        if let lopdf::Object::Reference(r) = annot_ref {
                            if let Ok(annot) = doc.get_object(r) {
                                if let Ok(annot_dict) = annot.as_dict() {
                                    // Check if it's a Link annotation
                                    if let Ok(subtype) = annot_dict.get(b"Subtype") {
                                        if let Ok(name) = subtype.as_name() {
                                            if name != b"Link" {
                                                continue;
                                            }
                                        }
                                    }

                                    // Get the action
                                    if let Ok(action) = annot_dict.get(b"A") {
                                        let action_dict = match action {
                                            lopdf::Object::Dictionary(d) => d,
                                            lopdf::Object::Reference(r) => {
                                                if let Ok(lopdf::Object::Dictionary(d)) =
                                                    doc.get_object(*r)
                                                {
                                                    d
                                                } else {
                                                    continue;
                                                }
                                            }
                                            _ => continue,
                                        };

                                        // Check for URI action
                                        if let Ok(uri) = action_dict.get(b"URI") {
                                            let uri_str = match uri {
                                                lopdf::Object::String(s, _) => {
                                                    String::from_utf8_lossy(s).to_string()
                                                }
                                                _ => continue,
                                            };
                                            links.push((page_num as usize, uri_str));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(links)
}

/// Check if a URI is valid.
fn check_uri(uri: &str, offline: bool, delay_ms: u64, client: &Client) -> bool {
    if uri.is_empty() {
        return false;
    }

    let parts: Vec<&str> = uri.splitn(2, ':').collect();
    if parts.len() < 2 {
        return false;
    }

    let protocol = parts[0].to_lowercase();

    match protocol.as_str() {
        "https" | "http" => {
            // Extract domain
            let domain = uri
                .split("//")
                .nth(1)
                .and_then(|s| s.split('/').next())
                .unwrap_or("");

            // Check personal domains
            for personal in PERSONAL_DOMAINS {
                if domain.ends_with(personal) || domain.contains(personal) {
                    return true;
                }
            }

            // Check whitelisted hosts
            for host in WHITELISTED_HOSTS {
                if domain.contains(host) {
                    return true;
                }
            }

            // If offline mode, accept the URL format
            if offline {
                return true;
            }

            // Actually check the URL
            if delay_ms > 0 {
                thread::sleep(Duration::from_millis(delay_ms));
            }

            match client
                .get(uri)
                .header(USER_AGENT, "Mozilla/5.0 (Resume-Link-Checker; Bot)")
                .timeout(Duration::from_secs(DEFAULT_HTTP_TIMEOUT_SECS))
                .send()
            {
                Ok(response) => response.status().as_u16() < 400,
                Err(_) => false,
            }
        }
        "mailto" => {
            let email = parts[1].trim();
            let email_regex =
                Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap();
            email_regex.is_match(email)
        }
        "tel" => {
            let phone = parts[1].trim();
            let clean: String = phone
                .chars()
                .filter(|c| c.is_ascii_digit() || *c == '+')
                .collect();
            clean.len() >= 7
        }
        _ => false,
    }
}

/// Result of link validation.
#[derive(Debug)]
pub struct ValidationIssue {
    pub pdf_name: String,
    pub page: usize,
    pub uri: String,
    pub message: String,
}

impl std::fmt::Display for ValidationIssue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}: {} on page {} - {}",
            self.pdf_name, self.uri, self.page, self.message
        )
    }
}

/// Validate links in PDF files.
pub fn validate_links(
    paths: &ProjectPaths,
    offline: bool,
    delay_ms: u64,
    fail_fast: bool,
    explicit_pdfs: Option<Vec<PathBuf>>,
) -> Result<Vec<ValidationIssue>> {
    let pdfs = collect_pdfs(paths, explicit_pdfs);

    if pdfs.is_empty() {
        bail!("No PDFs found to validate. Build resumes first or supply --pdf paths.");
    }

    let client = Client::builder()
        .timeout(Duration::from_secs(DEFAULT_HTTP_TIMEOUT_SECS))
        .redirect(reqwest::redirect::Policy::limited(10))
        .build()
        .context("Failed to create HTTP client")?;

    let mut issues = Vec::new();

    for pdf in pdfs {
        let relative = pdf.strip_prefix(&paths.root).unwrap_or(&pdf);

        println!(
            "{}",
            format!("Validating links in {}", relative.display()).cyan()
        );

        let links = extract_links_from_pdf(&pdf)?;

        if links.is_empty() {
            // Check if PDF has pages
            let doc = Document::load(&pdf)?;
            if doc.get_pages().is_empty() {
                issues.push(ValidationIssue {
                    pdf_name: pdf.file_name().unwrap().to_string_lossy().to_string(),
                    page: 0,
                    uri: String::new(),
                    message: "Empty PDF".to_string(),
                });
                if fail_fast {
                    return Ok(issues);
                }
            }
        }

        for (page, uri) in links {
            if !check_uri(&uri, offline, delay_ms, &client) {
                issues.push(ValidationIssue {
                    pdf_name: pdf.file_name().unwrap().to_string_lossy().to_string(),
                    page,
                    uri: uri.clone(),
                    message: "Invalid URL".to_string(),
                });
                if fail_fast {
                    return Ok(issues);
                }
            }
        }
    }

    Ok(issues)
}
