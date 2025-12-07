//! Common types, constants, and utilities shared across CLI commands.

use std::path::PathBuf;

use clap::ValueEnum;
use serde::{Deserialize, Serialize};

/// Resume types available for building.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, ValueEnum, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ResumeType {
    Academic,
    Business,
}

impl ResumeType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ResumeType::Academic => "academic",
            ResumeType::Business => "business",
        }
    }

    pub fn all() -> &'static [ResumeType] {
        &[ResumeType::Academic, ResumeType::Business]
    }
}

impl std::fmt::Display for ResumeType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Languages available for resume content.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, ValueEnum, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ResumeLanguage {
    En,
    Fr,
}

impl ResumeLanguage {
    pub fn as_str(&self) -> &'static str {
        match self {
            ResumeLanguage::En => "en",
            ResumeLanguage::Fr => "fr",
        }
    }

    pub fn all() -> &'static [ResumeLanguage] {
        &[ResumeLanguage::En, ResumeLanguage::Fr]
    }
}

impl std::fmt::Display for ResumeLanguage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Configuration for publish targets.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PublishTarget {
    pub remote: String,
    pub branch: String,
}

impl Default for PublishTarget {
    fn default() -> Self {
        Self {
            remote: "origin".to_string(),
            branch: "published".to_string(),
        }
    }
}

/// Options for the publish command.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PublishOptions {
    #[serde(default)]
    pub targets: Vec<PublishTarget>,
    #[serde(default)]
    pub skip_build: bool,
    #[serde(default)]
    pub skip_tests: bool,
    #[serde(default)]
    pub offline_tests: bool,
    #[serde(default)]
    pub message_template: Option<String>,
    #[serde(default)]
    pub types: Option<Vec<ResumeType>>,
    #[serde(default)]
    pub languages: Option<Vec<ResumeLanguage>>,
}

/// Project path constants.
pub struct ProjectPaths {
    pub root: PathBuf,
    pub output: PathBuf,
    pub templates: PathBuf,
}

impl ProjectPaths {
    /// Initialize project paths from the current executable or working directory.
    pub fn discover() -> anyhow::Result<Self> {
        // Try to find project root by looking for cv_content_en.yaml
        let current_dir = std::env::current_dir()?;
        let mut search_dir = current_dir.clone();

        loop {
            if search_dir.join("cv_content_en.yaml").exists() {
                return Ok(Self {
                    root: search_dir.clone(),
                    output: search_dir.join("output"),
                    templates: search_dir.join("resume_templates"),
                });
            }
            if !search_dir.pop() {
                break;
            }
        }

        // Fallback to current directory
        Ok(Self {
            root: current_dir.clone(),
            output: current_dir.join("output"),
            templates: current_dir.join("resume_templates"),
        })
    }
}

/// Default constants.
pub const DEFAULT_HTTP_TIMEOUT_SECS: u64 = 10;
pub const DEFAULT_LINK_DELAY_MS: u64 = 500;
pub const DEFAULT_MESSAGE_TEMPLATE: &str = "Publish resumes (${timestamp})";
pub const PERSONAL_DOMAINS: &[&str] = &["himmens.com"];
pub const WHITELISTED_HOSTS: &[&str] = &["linkedin.com", "github.com"];

/// Generate output filename for a resume.
pub fn output_filename(resume_type: ResumeType, language: ResumeLanguage) -> String {
    let suffix = match language {
        ResumeLanguage::Fr => "_fr",
        ResumeLanguage::En => "",
    };
    format!(
        "himmens_joshua_{}_resume{}.pdf",
        resume_type.as_str(),
        suffix
    )
}

/// Generate content filename for a language.
pub fn content_filename(language: ResumeLanguage) -> String {
    format!("cv_content_{}.yaml", language.as_str())
}

/// Generate temp typst filename.
pub fn temp_filename(resume_type: ResumeType, language: ResumeLanguage) -> String {
    format!("temp_{}_{}.typ", resume_type.as_str(), language.as_str())
}

/// Resolve types, defaulting to all if none specified.
pub fn resolve_types(types: Option<Vec<ResumeType>>) -> Vec<ResumeType> {
    types.unwrap_or_else(|| ResumeType::all().to_vec())
}

/// Resolve languages, defaulting to all if none specified.
pub fn resolve_languages(languages: Option<Vec<ResumeLanguage>>) -> Vec<ResumeLanguage> {
    languages.unwrap_or_else(|| ResumeLanguage::all().to_vec())
}

/// Apply template substitutions to a message string.
pub fn apply_message_template(
    template: &str,
    timestamp: &str,
    remote: &str,
    branch: &str,
) -> String {
    template
        .replace("${timestamp}", timestamp)
        .replace("${remote}", remote)
        .replace("${branch}", branch)
}

/// Collect PDF files from the output directory.
pub fn collect_pdfs(paths: &ProjectPaths, explicit: Option<Vec<PathBuf>>) -> Vec<PathBuf> {
    if let Some(explicit_paths) = explicit {
        return explicit_paths.into_iter().filter(|p| p.exists()).collect();
    }

    if !paths.output.exists() {
        return Vec::new();
    }

    let mut pdfs: Vec<PathBuf> = std::fs::read_dir(&paths.output)
        .ok()
        .into_iter()
        .flatten()
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|ext| ext == "pdf"))
        .collect();

    pdfs.sort();
    pdfs
}
