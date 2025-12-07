# Joshua Himmens Resume

A system that generates multiple resume formats in different languages from structured YAML content.

## Public Information

### Available Resume Formats

- **Academic Resume**: [English](https://github.com/Joshuah143/himmens-resume/blob/published/output/himmens_joshua_academic_resume.pdf) | [French](https://github.com/Joshuah143/himmens-resume/blob/published/output/himmens_joshua_academic_resume_fr.pdf)
- **Business Resume**: [English](https://github.com/Joshuah143/himmens-resume/blob/published/output/himmens_joshua_business_resume.pdf) | [French](https://github.com/Joshuah143/himmens-resume/blob/published/output/himmens_joshua_business_resume_fr.pdf)

### Content Structure

The resume content is stored in YAML files:
- [English Content](https://github.com/Joshuah143/himmens-resume/blob/main/cv_content_en.yaml)
- [French Content](https://github.com/Joshuah143/himmens-resume/blob/main/cv_content_fr.yaml)

### How It Works

This repository uses a content-template separation approach with:
- YAML files storing structured content and UI text
- [Typst](https://typst.app/) templates for academic and business formats
- A Rust CLI using the Typst API directly for seamless PDF generation

### Attribution

- Academic resume template adapted from [ImpreCV](https://github.com/jskherman/imprecv)
- While all content in my resume is my own authorship, large parts of this build system were generated with Claude

---

## Quick Reference

Common commands for working with the resume CLI:

```bash
# Install the CLI
make install

# Build all resumes
resume build

# Build specific resume type
resume build --type academic --language en

# Validate links
resume check-links

# Full release pipeline (clean, build, validate)
resume release

# Publish to GitHub
resume publish

# Install shell completions
resume completions

# Get help
resume --help
```

---

## Details for Maintainer

*This section contains detailed information for maintaining and extending the system.*

### Directory Structure

- `cv_content_en.yaml` - English content file
- `cv_content_fr.yaml` - French content file
- `resume_templates/` - Reusable Typst templates
  - `academic.typ` - Academic resume template
  - `business.typ` - Business resume template
  - `utils.typ` - Utility functions for formatting
- `src/` - Rust CLI source code using clap and the Typst API
  - `main.rs` - CLI entry point and completions handling
  - `build.rs` - Build command (Typst compilation)
  - `validate.rs` - Link validation
  - `maintenance.rs` - Clean and release commands
  - `publish.rs` - Git worktree publishing
  - `common.rs` - Shared types and utilities
- `output/` - Generated PDF resume files
- `Cargo.toml` - Rust project configuration
- `Makefile` - Build and installation helpers

### Prerequisites

- **Rust toolchain**: Install via [rustup](https://rustup.rs/)
- Fonts: The system uses New Computer Modern fonts (install via your package manager or download from CTAN)

### Building and Installing the CLI

Build the CLI in release mode:

```bash
cargo build --release
```

The binary will be at `target/release/resume`.

#### Installation Options

**Option 1: Using the Makefile (recommended)**

```bash
# Build and symlink to ~/.local/bin/resume
make install

# Clean build artifacts
make clean
```

**Option 2: Manual installation**

Add the binary to your PATH or create a symlink:

```bash
# Create symlink to user-local bin directory
mkdir -p ~/.local/bin
ln -sf "$(pwd)/target/release/resume" ~/.local/bin/resume

# Ensure ~/.local/bin is in your PATH (add to ~/.zshrc, ~/.bashrc, etc.)
export PATH="$HOME/.local/bin:$PATH"
```

### Shell Completions

The CLI supports shell completions for bash, zsh, fish, PowerShell, and elvish. To install completions:

```bash
# Auto-detect shell and install to standard user-local directory
resume completions

# Or specify a shell explicitly
resume completions zsh

# Generate to stdout (for manual installation)
resume completions zsh --stdout
```

#### Important: Zsh Configuration

For zsh completions to work, you **must** ensure that the user-local completion directory is in your `fpath` before `compinit` is called. Add this to your `~/.zshrc`:

```zsh
# Add user-local completion directory to fpath
fpath=(~/.local/share/zsh/site-functions $fpath)

# Initialize completion system
autoload -Uz compinit && compinit
```

Without this configuration, zsh will fall back to filename completion instead of showing available commands.

#### Using the Makefile

You can also use the Makefile to install completions:

```bash
# Install completions for bash, zsh, and fish
make install-completions

# Generate completions for a specific shell to a custom directory
make completions TARGET_SHELL=zsh OUTDIR=./completions

# Remove installed completions
make uninstall-completions
```

### Build Commands

#### Building Resumes

To build all resume formats in all languages:

```bash
resume build
```

To build specific types or languages:

```bash
# Build only academic resumes (both languages)
resume build --type academic

# Build only French resumes (both types)
resume build --language fr

# Build only English business resumes
resume build --type business --language en
```

#### Development Mode

When working directly with Typst files, you can use dev mode to keep the temporary files:

```bash
# Generate all formats and keep temp files
resume build --keep-temp

# Generate only academic English resume and keep temp file
resume build --type academic --language en --keep-temp
```

The temporary files are created in the project root with names like `temp_academic_en.typ`. You can edit these files directly for quick development and testing.

#### Testing and Cleaning

```bash
# Run link validation (performs HTTP checks)
resume check-links

# Run link validation in offline mode (skips network calls)
resume check-links --offline

# Clean generated files
resume clean

# Full release process (clean, build, test)
resume release

# Simulate CI pipeline
resume release --offline
```

#### Publishing PDFs

```bash
# Build, validate, and push PDFs to the published branch
resume publish

# Publish with custom options (JSON config optional)
resume publish --config publish.config.json
```

The `publish` command creates a temporary git worktree, copies PDFs from `output/`, and commits artifacts to each configured target. By default it:

- Rebuilds the PDFs locally with Typst
- Runs the built-in link validation against the live network
- Pushes the resulting commit to `origin/published`

Optional flags:

- `--skip-build` – reuse the PDFs already in `output/`
- `--skip-tests` – skip running the link checker before publishing
- `--offline-tests` – run link checks in offline mode (skips network calls)
- `--target origin:main` – publish to additional remote/branch pairs
- `--config publish.config.json` – load publish settings (targets, skip flags, custom message template)

Paths on `published` continue to work with the README links, so no additional GitHub automation is required.

### Content Structure

The YAML content files contain:
- Personal information
- Education
- Work experience
- Publications
- Awards
- Skills
- Advocacy/leadership
- Additional experiences
- UI text for localization

Use the `visible` or `show` flags to control which items appear in the resumes.

### Template Customization

Edit the template files in the `resume_templates/` directory:
- `academic.typ` for academic resumes
- `business.typ` for business resumes

#### Repository Organization

The repository uses a branch structure where:
- `main`: Production-ready code
- `published`: Contains the built PDF artifacts
