//! Resume CLI - Build, validate, and publish resumes using Typst.

mod build;
mod common;
mod maintenance;
mod publish;
mod validate;

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;

use common::{
    ProjectPaths, ResumeLanguage, ResumeType, DEFAULT_LINK_DELAY_MS, DEFAULT_MESSAGE_TEMPLATE,
};

/// Build, validate, and publish resumes from structured content.
#[derive(Parser)]
#[command(name = "resume")]
#[command(author = "Joshua Himmens <joshua@himmens.com>")]
#[command(version)]
#[command(about = "Build, validate, and publish resumes from structured content using Typst")]
#[command(propagate_version = true)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Compile resume PDFs for the requested type/language combinations
    Build {
        /// Resume types to build (repeat for multiples). Defaults to all.
        #[arg(short = 't', long = "type", value_enum)]
        types: Option<Vec<ResumeType>>,

        /// Languages to build (repeat for multiples). Defaults to all.
        #[arg(short = 'l', long = "language", value_enum)]
        languages: Option<Vec<ResumeLanguage>>,

        /// Keep the intermediate Typst files
        #[arg(long)]
        keep_temp: bool,

        /// Directory for generated PDFs
        #[arg(short = 'o', long = "output")]
        output: Option<PathBuf>,
    },

    /// Validate embedded links inside the generated PDF resumes
    #[command(name = "check-links")]
    CheckLinks {
        /// Skip network checks and only validate link format
        #[arg(long)]
        offline: bool,

        /// Delay (seconds) between HTTP requests to avoid rate limiting
        #[arg(long, default_value_t = DEFAULT_LINK_DELAY_MS as f64 / 1000.0)]
        delay: f64,

        /// Exit on the first invalid link instead of collecting all failures
        #[arg(long)]
        fail_fast: bool,

        /// Specific PDF paths to validate. Defaults to every resume in output/
        #[arg(long = "pdf")]
        pdfs: Option<Vec<PathBuf>>,
    },

    /// Remove generated PDFs and/or Typst scratch files
    Clean {
        /// Delete PDFs in output/
        #[arg(long = "pdfs", default_value_t = true, action = clap::ArgAction::Set)]
        remove_pdfs: bool,

        /// Delete temp Typst files in repo root
        #[arg(long = "temps", default_value_t = true, action = clap::ArgAction::Set)]
        remove_temp: bool,
    },

    /// Clean, rebuild every resume, and validate links in a single flow
    Release {
        /// Keep temp Typst sources after the build
        #[arg(long)]
        keep_temp: bool,

        /// Run link checks without touching the network
        #[arg(long)]
        offline: bool,
    },

    /// Build (unless skipped), validate, and push PDFs to one or more publish targets
    Publish {
        /// Default branch that receives published PDFs
        #[arg(long, default_value = "published")]
        branch: String,

        /// Git remote to push to
        #[arg(long, default_value = "origin")]
        remote: String,

        /// Override remote/branch pairs using remote:branch syntax (repeatable)
        #[arg(short = 't', long = "target")]
        targets: Option<Vec<String>>,

        /// Optional JSON file with publish settings
        #[arg(long)]
        config: Option<PathBuf>,

        /// Reuse existing PDFs instead of rebuilding
        #[arg(long)]
        skip_build: bool,

        /// Skip link validation before publishing
        #[arg(long)]
        skip_tests: bool,

        /// Run link checks offline when publishing
        #[arg(long)]
        offline_tests: bool,

        /// Template for commit messages. Supports ${timestamp}, ${remote}, ${branch}
        #[arg(long, default_value = DEFAULT_MESSAGE_TEMPLATE)]
        message_template: String,

        /// Limit build step to specific resume types when publishing
        #[arg(short = 'T', long = "type", value_enum)]
        types: Option<Vec<ResumeType>>,

        /// Limit build step to specific languages when publishing
        #[arg(short = 'L', long = "language", value_enum)]
        languages: Option<Vec<ResumeLanguage>>,
    },

    /// Install or generate shell completion scripts
    #[command(name = "completions")]
    Completions {
        /// Target shell (bash, zsh, fish, powershell, elvish). If omitted, tries to detect current shell.
        #[arg(value_enum)]
        shell: Option<Shell>,

        /// Optional directory to write the completion file into; if omitted, installs to standard user-local directory for the shell
        #[arg(long)]
        dir: Option<PathBuf>,

        /// Write to stdout instead of installing to a file (overrides --dir)
        #[arg(long)]
        stdout: bool,
    },
}

fn run() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let paths = ProjectPaths::discover()?;

    match cli.command {
        Commands::Build {
            types,
            languages,
            keep_temp,
            output,
        } => {
            let mut paths = paths;
            if let Some(output_dir) = output {
                paths.output = output_dir;
            }
            build::build_resumes(&paths, types, languages, keep_temp)?;
        }

        Commands::CheckLinks {
            offline,
            delay,
            fail_fast,
            pdfs,
        } => {
            let is_ci = std::env::var("CI")
                .map(|v| v.to_lowercase() == "true")
                .unwrap_or(false);
            let offline = offline || is_ci;
            let delay_ms = (delay * 1000.0) as u64;

            let issues = validate::validate_links(&paths, offline, delay_ms, fail_fast, pdfs)?;

            if !issues.is_empty() {
                for issue in &issues {
                    eprintln!("{}", issue.to_string().red());
                }
                anyhow::bail!("Link validation failed with {} issue(s)", issues.len());
            }

            println!("{}", "All links look good!".green());
        }

        Commands::Clean {
            remove_pdfs,
            remove_temp,
        } => {
            maintenance::clean_artifacts(&paths, remove_pdfs, remove_temp)?;
        }

        Commands::Release { keep_temp, offline } => {
            maintenance::release_pipeline(&paths, keep_temp, offline)?;
        }

        Commands::Publish {
            branch,
            remote,
            targets,
            config,
            skip_build,
            skip_tests,
            offline_tests,
            message_template,
            types,
            languages,
        } => {
            let options = publish::merge_publish_inputs(publish::MergePublishInputs {
                branch: &branch,
                remote: &remote,
                config_path: config.as_deref(),
                cli_targets: targets,
                skip_build,
                skip_tests,
                offline_tests,
                message_template: Some(&message_template),
                types,
                languages,
            })?;

            publish::run_publish(&paths, options)?;
        }

        Commands::Completions { shell, dir, stdout } => {
            // Build a clap Command from our Cli derive to feed into clap_complete
            let mut cmd = Cli::command();
            let bin_name = cmd.get_name().to_string();

            // Determine shell: CLI arg wins, otherwise detect
            let detected_shell = match shell {
                Some(s) => Some(s),
                None => detect_current_shell(),
            };

            let shell = match detected_shell {
                Some(s) => s,
                None => {
                    anyhow::bail!(
                        "Could not detect current shell. Specify explicitly, e.g.: 'resume completions zsh'"
                    );
                }
            };

            // If stdout requested, honor it regardless of dir
            if stdout {
                let mut out = std::io::stdout();
                generate(shell, &mut cmd, bin_name, &mut out);
                return Ok(());
            }

            // Determine target path
            let target_path = match dir {
                Some(mut d) => {
                    std::fs::create_dir_all(&d)?;
                    d.push(file_name_for_shell(shell));
                    d
                }
                None => default_install_path_for_shell(shell)?,
            };

            if let Some(parent) = target_path.parent() {
                std::fs::create_dir_all(parent)?;
            }

            let file = std::fs::File::create(&target_path)?;
            let mut writer = std::io::BufWriter::new(file);
            generate(shell, &mut cmd, bin_name, &mut writer);

            println!("Installed completions to {}", target_path.display());
            if matches!(shell, Shell::Zsh) {
                eprintln!(
                    "Note for zsh: ensure the directory is in your fpath and run 'autoload -Uz compinit && compinit'"
                );
            } else if matches!(shell, Shell::Bash) {
                eprintln!("Note for bash: requires bash-completion v2 and a new shell session or 'source' the file.");
            } else if matches!(shell, Shell::Fish) {
                // fish auto-detects, nothing needed
            } else if matches!(shell, Shell::PowerShell) {
                eprintln!("Note for PowerShell: to persist, dot-source this file from your $PROFILE.");
            }
        }
    }

    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{}", format!("Error: {:#}", e).red());
            ExitCode::FAILURE
        }
    }
}

// ----- Helpers for completions installation -----

fn detect_current_shell() -> Option<Shell> {
    // Prefer explicit SHELL env on Unix-like systems
    if let Ok(shell_path) = std::env::var("SHELL") {
        let name = std::path::Path::new(&shell_path)
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_ascii_lowercase();
        return match name.as_str() {
            "bash" => Some(Shell::Bash),
            "zsh" => Some(Shell::Zsh),
            "fish" => Some(Shell::Fish),
            "elvish" | "elv" => Some(Shell::Elvish),
            // PowerShell may report as pwsh when launched from Unix
            "pwsh" | "powershell" => Some(Shell::PowerShell),
            _ => None,
        };
    }

    // Heuristics on Windows or when SHELL is not set
    if let Ok(proc) = std::env::var("PSModulePath") {
        if !proc.is_empty() {
            return Some(Shell::PowerShell);
        }
    }

    None
}

fn file_name_for_shell(shell: Shell) -> String {
    match shell {
        Shell::Bash => "resume".to_string(),
        Shell::Zsh => "_resume".to_string(),
        Shell::Fish => "resume.fish".to_string(),
        Shell::PowerShell => "resume.ps1".to_string(),
        Shell::Elvish => "resume.elv".to_string(),
        _ => format!("resume.{}", shell.to_string().to_lowercase()),
    }
}

fn default_install_path_for_shell(shell: Shell) -> anyhow::Result<PathBuf> {
    let home = home_dir()?;
    match shell {
        Shell::Bash => {
            let xdg = std::env::var("XDG_DATA_HOME").ok().map(PathBuf::from).unwrap_or_else(|| home.join(".local/share"));
            Ok(xdg.join("bash-completion/completions").join("resume"))
        }
        Shell::Zsh => {
            // Follow Makefile default: ~/.local/share/zsh/site-functions/_resume
            Ok(home.join(".local/share/zsh/site-functions").join("_resume"))
        }
        Shell::Fish => Ok(home.join(".config/fish/completions").join("resume.fish")),
        Shell::PowerShell => {
            // Reasonable default for user-local PowerShell profile content
            // Linux/macOS PowerShell: use ~/.config/powershell/completions
            // Windows PowerShell: fallback to ~/Documents/PowerShell/Completions
            let path = if cfg!(windows) {
                home.join("Documents/PowerShell/Completions").join("resume.ps1")
            } else {
                home.join(".config/powershell/completions").join("resume.ps1")
            };
            Ok(path)
        }
        Shell::Elvish => Ok(home.join(".config/elvish/completions").join("resume.elv")),
        _ => {
            // Generic fallback into ~/.local/share/resume/completions
            Ok(home
                .join(".local/share/resume/completions")
                .join(file_name_for_shell(shell)))
        }
    }
}

fn home_dir() -> anyhow::Result<PathBuf> {
    if let Ok(h) = std::env::var("HOME") {
        return Ok(PathBuf::from(h));
    }
    if let Ok(h) = std::env::var("USERPROFILE") {
        return Ok(PathBuf::from(h));
    }
    anyhow::bail!("Could not determine home directory from HOME/USERPROFILE env vars")
}
