# Repository Guidelines

## Project Structure & Module Organization
- This is a Rust CLI built with clap that uses the Typst API directly for PDF generation. Source files are in `src/` with modular commands (`build.rs`, `validate.rs`, `maintenance.rs`, `publish.rs`, `common.rs`, and `main.rs` for CLI entry and completions).
- `resume_templates/` holds `academic.typ`, `business.typ`, `utils.typ`. YAML content lives at the repo root (`cv_content_en.yaml`, `cv_content_fr.yaml`). `assets/` stores shared graphics, and `output/` contains generated PDFs (gitignored).
- The CLI binary is built with `cargo build --release` and outputs to `target/release/resume`.
- Use `make install` to build and symlink the binary to `~/.local/bin/resume` for easy access.

## Build, Test, and Development Commands
- Build the CLI: `cargo build --release`
- Install the CLI: `make install` (builds and creates symlink to `~/.local/bin/resume`)
- Run the CLI: `resume build` renders every resume variant (assumes CLI is in PATH)
- Use `--type` / `--language` flags (repeatable) to scope builds. Example: `resume build --type business --language fr`.
- Pass `--keep-temp` to preserve `temp_<type>_<lang>.typ` files for iterative Typst edits.
- `resume --help` or `resume -h` for quick reminders.
- Install shell completions: `resume completions` (auto-detects shell) or `resume completions zsh` (specific shell)

## Coding Style & Naming Conventions
- Rust code follows standard Rust conventions: snake_case for functions/variables, CamelCase for types, 4-space indentation. Run `cargo fmt` and `cargo clippy` before committing.
- Keep resume filenames consistent: `himmens_joshua_<type>_resume[_fr].pdf`. Temporary files follow `temp_<type>_<lang>.typ`.
- YAML keys mirror template expectations; prefer `visible`/`show` flags instead of deleting sections.

## Testing Guidelines
- After building, run `resume check-links` for live URL checks or add `--offline` when network access is unavailable.
- The CLI reads PDFs from `output/`; rebuild first or reuse artifacts with `--skip-build` when invoking `publish`. Investigate any failing link before marking offline.

## Commit & Pull Request Guidelines
- Commit messages are concise and action-oriented (see `git log`), e.g., `update french version` or `Fix attestation configuration in GitHub Actions`. Use the imperative mood when possible.
- Work on feature branches off `develop`; merge to `main` once resumes are ready, and run `resume publish` to push PDFs to `published`.
- Pull requests summarize resume or template changes, note whether PDFs were rebuilt, and attach representative diffs or screenshots. Reference related issues and flag follow-up tasks explicitly.

## Publishing Tips
- `resume publish` rebuilds (unless skipped), runs link checks, and commits PDFs via a temporary worktree. Use flags such as `--skip-tests`, `--offline-tests`, `--target remote:branch`, or a JSON `--config` only with explicit justification.

## Shell Completions
- The CLI supports completions for bash, zsh, fish, PowerShell, and elvish via `clap_complete`.
- Install with `resume completions` or `make install-completions`.
- **Important for zsh users**: Ensure `~/.local/share/zsh/site-functions` is in your `fpath` before `compinit` is called. Add to `~/.zshrc`:
  ```zsh
  fpath=(~/.local/share/zsh/site-functions $fpath)
  autoload -Uz compinit && compinit
  ```
- Without proper fpath configuration, completions will fall back to filename completion instead of showing available commands.
