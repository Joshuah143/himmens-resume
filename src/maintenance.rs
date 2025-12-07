//! Maintenance commands - clean, release pipeline.

use std::fs;

use anyhow::{Context, Result};
use colored::Colorize;
use glob::glob;

use crate::build::build_resumes;
use crate::common::{ProjectPaths, DEFAULT_LINK_DELAY_MS};
use crate::validate::validate_links;

/// Remove generated artifacts.
pub fn clean_artifacts(paths: &ProjectPaths, remove_pdfs: bool, remove_temp: bool) -> Result<()> {
    if remove_pdfs && paths.output.exists() {
        for entry in fs::read_dir(&paths.output)? {
            let entry = entry?;
            let path = entry.path();
            if path.extension().is_some_and(|ext| ext == "pdf") {
                let relative = path.strip_prefix(&paths.root).unwrap_or(&path);
                println!("{}", format!("Removing {}", relative.display()).yellow());
                fs::remove_file(&path)
                    .with_context(|| format!("Failed to remove: {}", path.display()))?;
            }
        }
    }

    if remove_temp {
        let pattern = paths.root.join("temp_*.typ");
        let pattern_str = pattern.to_string_lossy();

        for path in glob(&pattern_str)?.flatten() {
            let relative = path.strip_prefix(&paths.root).unwrap_or(&path);
            println!("{}", format!("Removing {}", relative.display()).yellow());
            fs::remove_file(&path)
                .with_context(|| format!("Failed to remove: {}", path.display()))?;
        }
    }

    Ok(())
}

/// Run the full release pipeline: clean, build, validate.
pub fn release_pipeline(paths: &ProjectPaths, keep_temp: bool, offline: bool) -> Result<()> {
    // Clean all artifacts
    clean_artifacts(paths, true, true)?;

    // Build all resumes
    build_resumes(paths, None, None, keep_temp)?;

    // Validate links
    let issues = validate_links(paths, offline, DEFAULT_LINK_DELAY_MS, false, None)?;

    if !issues.is_empty() {
        for issue in &issues {
            eprintln!("{}", issue.to_string().red());
        }
        anyhow::bail!("Link validation failed with {} issue(s)", issues.len());
    }

    println!("{}", "Release pipeline completed successfully.".green());
    Ok(())
}
