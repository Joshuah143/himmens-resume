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
- A custom `typer` based python application to make the workflow seamless

### Attribution

- Academic resume template adapted from [ImpreCV](https://github.com/jskherman/imprecv)
- While all content in my resume is my own authorship, large parts of this build system were generated with Claude 3.7

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
- `resume_cli/` - Typer-based CLI package that builds, validates, and publishes resumes
- `tests/` - Tests for validating resumes
- `output/` - Generated PDF resume files

### Build Commands

#### Building Resumes

Make sure the CLI is on your `PATH` first. Easiest options:
- prefix commands with `uv run resume …` (no shell changes)
- activate the virtualenv: `source .venv/bin/activate`
- add `.venv/bin` to your shell init if you want `resume` always available

To build all resume formats in all languages once the command resolves:

```bash
resume build
```

To build specific types or languages:

```bash
# Setup the environment
uv sync
make activate 

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
uv run resume build --keep-temp

# Generate only academic English resume and keep temp file
uv run resume build --type academic --language en --keep-temp

# Other specific dev targets
uv run resume build --type academic --language fr --keep-temp
uv run resume build --type business --language en --keep-temp
uv run resume build --type business --language fr --keep-temp
```

The temporary files are created in the project root with names like `temp_academic_en.typ`. You can edit these files directly for quick development and testing.

#### Testing and Cleaning

```bash
# Run link validation (performs HTTP checks)
uv run resume check-links

# Run link validation in offline mode (skips network calls)
uv run resume check-links --offline

# Check code style with Ruff
uv run resume lint

# Clean generated files
uv run resume clean

# Full release process (clean, build, test)
uv run resume release

# Simulate CI pipeline
uv run resume release --offline
```

#### Publishing PDFs

```bash
# Build, validate, and push PDFs to the published branch
uv run resume publish

# Publish with custom options (JSON config optional)
uv run resume publish --config publish.config.json
```

The `publish` command reuses the CLI logic to create a temporary git worktree,
copy PDFs from `output/`, and commit artifacts to each configured target. By
default it:

- Rebuilds the PDFs locally with Typst
- Runs the built-in link validation against the live network
- Pushes the resulting commit to `origin/published`

Optional flags:

- `--skip-build` – reuse the PDFs already in `output/`
- `--skip-tests` – skip running the link checker before publishing
- `--offline-tests` – run link checks in offline mode (skips network calls)
- `--target origin:main` – publish to additional remote/branch pairs
- `--config publish.config.json` – load publish settings (targets, skip flags, custom message template)

Paths on `published` continue to work with the README links, so no additional
GitHub automation is required.

Note: the consolidated CLI now owns linting, cleaning, release, and publish workflows.

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
