//! Publish command - pushes built PDFs to a publish branch.

use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use chrono::Local;
use colored::Colorize;
use git2::{
    BranchType, Cred, FetchOptions, PushOptions, RemoteCallbacks, Repository, ResetType, Signature,
};
use tempfile::TempDir;

use crate::build::build_resumes;
use crate::common::{
    apply_message_template, collect_pdfs, ProjectPaths, PublishOptions, PublishTarget,
    ResumeLanguage, ResumeType, DEFAULT_LINK_DELAY_MS, DEFAULT_MESSAGE_TEMPLATE,
};
use crate::validate::validate_links;

/// Load publish configuration from a JSON file.
pub fn load_publish_config(path: &Path) -> Result<PublishOptions> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("Failed to read config file: {}", path.display()))?;

    let data: serde_json::Value =
        serde_json::from_str(&content).with_context(|| "Invalid JSON in config file")?;

    let mut options = PublishOptions::default();

    // Parse targets
    if let Some(targets) = data.get("targets").and_then(|v| v.as_array()) {
        for entry in targets {
            let remote = entry
                .get("remote")
                .and_then(|v| v.as_str())
                .unwrap_or("origin")
                .to_string();
            let branch = entry
                .get("branch")
                .and_then(|v| v.as_str())
                .unwrap_or("published")
                .to_string();
            options.targets.push(PublishTarget { remote, branch });
        }
    }

    // Fallback to single remote/branch if no targets array
    if options.targets.is_empty() {
        let remote = data
            .get("remote")
            .and_then(|v| v.as_str())
            .unwrap_or("origin")
            .to_string();
        let branch = data
            .get("branch")
            .and_then(|v| v.as_str())
            .unwrap_or("published")
            .to_string();
        options.targets.push(PublishTarget { remote, branch });
    }

    // Parse other options
    options.skip_build = data
        .get("skip_build")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    options.skip_tests = data
        .get("skip_tests")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    options.offline_tests = data
        .get("offline_tests")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    if let Some(template) = data.get("message_template").and_then(|v| v.as_str()) {
        if !template.trim().is_empty() {
            options.message_template = Some(template.to_string());
        }
    }

    if let Some(types) = data.get("types").and_then(|v| v.as_array()) {
        options.types = Some(
            types
                .iter()
                .filter_map(|v| v.as_str())
                .filter_map(|s| match s {
                    "academic" => Some(ResumeType::Academic),
                    "business" => Some(ResumeType::Business),
                    _ => None,
                })
                .collect(),
        );
    }

    if let Some(languages) = data.get("languages").and_then(|v| v.as_array()) {
        options.languages = Some(
            languages
                .iter()
                .filter_map(|v| v.as_str())
                .filter_map(|s| match s {
                    "en" => Some(ResumeLanguage::En),
                    "fr" => Some(ResumeLanguage::Fr),
                    _ => None,
                })
                .collect(),
        );
    }

    Ok(options)
}

/// Parse target string in format "remote:branch".
pub fn parse_target_option(target: &str) -> Result<PublishTarget> {
    if !target.contains(':') {
        bail!("Targets must use the format remote:branch (e.g. origin:published)");
    }

    let parts: Vec<&str> = target.splitn(2, ':').collect();
    let remote = if parts[0].is_empty() {
        "origin".to_string()
    } else {
        parts[0].to_string()
    };
    let branch = if parts.len() > 1 && !parts[1].is_empty() {
        parts[1].to_string()
    } else {
        "published".to_string()
    };

    Ok(PublishTarget { remote, branch })
}

/// Create git callbacks for authentication.
fn create_callbacks<'a>() -> RemoteCallbacks<'a> {
    let mut callbacks = RemoteCallbacks::new();
    callbacks.credentials(|_url, username_from_url, _allowed_types| {
        // Try SSH agent first
        Cred::ssh_key_from_agent(username_from_url.unwrap_or("git"))
    });
    callbacks
}

/// Publish PDFs to a target branch.
pub fn publish_to_target(
    paths: &ProjectPaths,
    target: &PublishTarget,
    message_template: &str,
    pdfs: &[PathBuf],
) -> Result<()> {
    if pdfs.is_empty() {
        bail!("No PDFs found in output/. Build resumes before publishing.");
    }

    let repo = Repository::open(&paths.root).context("Failed to open git repository")?;

    // Try to fetch the remote branch
    let fetch_result = (|| -> Result<()> {
        let mut remote = repo.find_remote(&target.remote)?;
        let mut fetch_opts = FetchOptions::new();
        fetch_opts.remote_callbacks(create_callbacks());
        remote.fetch(&[&target.branch], Some(&mut fetch_opts), None)?;
        Ok(())
    })();

    if let Err(e) = fetch_result {
        println!(
            "{}",
            format!(
                "Warning: could not fetch {}/{}: {}. Proceeding with local refs.",
                target.remote, target.branch, e
            )
            .yellow()
        );
    }

    // Create a temporary directory for the worktree
    let temp_dir = TempDir::new().context("Failed to create temporary directory")?;
    let worktree_path = temp_dir.path();

    // Try to find the starting point for the branch
    let remote_ref = format!("refs/remotes/{}/{}", target.remote, target.branch);
    let local_ref = format!("refs/heads/{}", target.branch);

    let start_commit = repo
        .find_reference(&remote_ref)
        .or_else(|_| repo.find_reference(&local_ref))
        .and_then(|r| r.peel_to_commit())
        .unwrap_or_else(|_| repo.head().unwrap().peel_to_commit().unwrap());

    // Create worktree
    let worktree_name = format!("publish-{}", target.branch);

    // Clean up any existing worktree with this name
    if let Ok(wt) = repo.find_worktree(&worktree_name) {
        let _ = wt.prune(Some(
            git2::WorktreePruneOptions::new()
                .working_tree(true)
                .locked(true),
        ));
    }

    // Get or create the branch
    let branch_ref = repo
        .find_branch(&target.branch, BranchType::Local)
        .map(|b| b.into_reference())
        .unwrap_or_else(|_| {
            // Create the branch if it doesn't exist
            repo.branch(&target.branch, &start_commit, false)
                .unwrap()
                .into_reference()
        });

    // Create the worktree
    let worktree = repo
        .worktree(
            &worktree_name,
            worktree_path,
            Some(git2::WorktreeAddOptions::new().reference(Some(&branch_ref))),
        )
        .context("Failed to create worktree")?;

    // Scope for the worktree repository operations
    let commit_result = {
        let wt_repo =
            Repository::open(worktree_path).context("Failed to open worktree repository")?;

        // Reset to start commit
        wt_repo
            .reset(start_commit.as_object(), ResetType::Hard, None)
            .context("Failed to reset worktree")?;

        // Copy PDFs to worktree
        let target_output = worktree_path.join("output");
        fs::create_dir_all(&target_output)
            .context("Failed to create output directory in worktree")?;

        // Remove existing PDFs
        if target_output.exists() {
            for entry in fs::read_dir(&target_output)? {
                let entry = entry?;
                let path = entry.path();
                if path.extension().is_some_and(|ext| ext == "pdf") {
                    fs::remove_file(&path)?;
                }
            }
        }

        // Copy new PDFs
        for pdf in pdfs {
            let dest = target_output.join(pdf.file_name().unwrap());
            fs::copy(pdf, &dest)
                .with_context(|| format!("Failed to copy PDF: {}", pdf.display()))?;
        }

        // Stage changes
        let mut index = wt_repo.index()?;

        // Add output directory
        index.add_all(["output/*"].iter(), git2::IndexAddOption::DEFAULT, None)?;
        index.write()?;

        // Check if there are changes
        let tree_id = index.write_tree()?;

        let head_tree_id = wt_repo
            .head()
            .ok()
            .and_then(|h| h.peel_to_tree().ok())
            .map(|t| t.id());

        let has_changes = head_tree_id.map(|ht_id| ht_id != tree_id).unwrap_or(true);

        if !has_changes {
            println!(
                "{}",
                format!(
                    "No changes to publish for {}/{}.",
                    target.remote, target.branch
                )
                .cyan()
            );
            return Ok(());
        }

        // Create commit
        let tree = wt_repo.find_tree(tree_id)?;
        let timestamp = Local::now().format("%Y-%m-%d %H:%M").to_string();
        let message =
            apply_message_template(message_template, &timestamp, &target.remote, &target.branch);

        let sig = Signature::now("Resume CLI", "resume-cli@himmens.com")?;

        let parent = wt_repo.head().ok().and_then(|h| h.peel_to_commit().ok());
        let parents: Vec<&git2::Commit> = parent.iter().collect();

        wt_repo.commit(Some("HEAD"), &sig, &sig, &message, &tree, &parents)?;

        // Push
        let mut remote = wt_repo.find_remote(&target.remote)?;
        let mut push_opts = PushOptions::new();
        push_opts.remote_callbacks(create_callbacks());

        let refspec = format!("refs/heads/{}:refs/heads/{}", target.branch, target.branch);
        remote.push(&[&refspec], Some(&mut push_opts))?;

        Ok::<_, anyhow::Error>(())
    };

    // Clean up worktree
    let _ = worktree.prune(Some(
        git2::WorktreePruneOptions::new()
            .working_tree(true)
            .locked(true),
    ));

    commit_result?;

    println!(
        "{}",
        format!(
            "Published {} PDFs to {}/{}.",
            pdfs.len(),
            target.remote,
            target.branch
        )
        .green()
    );

    Ok(())
}

/// Input parameters for merging publish options.
#[derive(Default)]
pub struct MergePublishInputs<'a> {
    pub branch: &'a str,
    pub remote: &'a str,
    pub config_path: Option<&'a Path>,
    pub cli_targets: Option<Vec<String>>,
    pub skip_build: bool,
    pub skip_tests: bool,
    pub offline_tests: bool,
    pub message_template: Option<&'a str>,
    pub types: Option<Vec<ResumeType>>,
    pub languages: Option<Vec<ResumeLanguage>>,
}

/// Merge CLI options with config file options.
#[allow(clippy::too_many_arguments)]
pub fn merge_publish_inputs(inputs: MergePublishInputs<'_>) -> Result<PublishOptions> {
    let MergePublishInputs {
        branch,
        remote,
        config_path,
        cli_targets,
        skip_build,
        skip_tests,
        offline_tests,
        message_template,
        types,
        languages,
    } = inputs;
    let mut options = PublishOptions {
        skip_build,
        skip_tests,
        offline_tests,
        message_template: message_template.map(|s| s.to_string()),
        types,
        languages,
        ..Default::default()
    };

    // Load config file if provided
    if let Some(config_path) = config_path {
        let config_options = load_publish_config(config_path)?;

        if options.types.is_none() {
            options.types = config_options.types;
        }
        if options.languages.is_none() {
            options.languages = config_options.languages;
        }

        options.skip_build = options.skip_build || config_options.skip_build;
        options.skip_tests = options.skip_tests || config_options.skip_tests;
        options.offline_tests = options.offline_tests || config_options.offline_tests;

        if options.message_template.is_none() {
            options.message_template = config_options.message_template;
        }

        options.targets = config_options.targets;
    }

    // CLI targets override config targets
    if let Some(targets) = cli_targets {
        options.targets = targets
            .iter()
            .map(|t| parse_target_option(t))
            .collect::<Result<Vec<_>>>()?;
    }

    // Default target if none specified
    if options.targets.is_empty() {
        options.targets.push(PublishTarget {
            remote: remote.to_string(),
            branch: branch.to_string(),
        });
    }

    Ok(options)
}

/// Run the full publish workflow.
pub fn run_publish(paths: &ProjectPaths, options: PublishOptions) -> Result<()> {
    // Build if not skipped
    if !options.skip_build {
        build_resumes(
            paths,
            options.types.clone(),
            options.languages.clone(),
            false,
        )?;
    } else {
        println!(
            "{}",
            "Skipping build step; reusing existing PDFs in output/.".cyan()
        );
    }

    // Validate if not skipped
    if !options.skip_tests {
        let is_ci = std::env::var("CI")
            .map(|v| v.to_lowercase() == "true")
            .unwrap_or(false);
        let offline = options.offline_tests || is_ci;

        let issues = validate_links(paths, offline, DEFAULT_LINK_DELAY_MS, false, None)?;

        if !issues.is_empty() {
            for issue in &issues {
                eprintln!("{}", issue.to_string().red());
            }
            bail!("Link validation failed with {} issue(s)", issues.len());
        }
    } else {
        println!("{}", "Skipping link validation step as requested.".cyan());
    }

    // Collect PDFs
    let pdfs = collect_pdfs(paths, None);

    // Get message template
    let message_template = options
        .message_template
        .as_deref()
        .unwrap_or(DEFAULT_MESSAGE_TEMPLATE);

    // Publish to each target
    for target in &options.targets {
        publish_to_target(paths, target, message_template, &pdfs)?;
    }

    Ok(())
}
