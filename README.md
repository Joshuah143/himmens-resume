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
- GitHub Actions for automated generation and publishing
- Security through verifiable build provenance

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
- `build.py` - Python script to build all resume formats
- `tests/` - Tests for validating resumes
- `output/` - Generated PDF resume files

### Build Commands

#### Building Resumes

To build all resume formats in all languages:

```bash
make build
# or
uv run build.py
```

To build specific types or languages:

```bash
# Build only academic resumes (both languages)
make academic
# or
uv run build.py --types academic

# Build only French resumes (both types)
make fr
# or
uv run build.py --languages fr

# Build only English business resumes
uv run build.py --types business --languages en
```

#### Development Mode

When working directly with Typst files, you can use dev mode to keep the temporary files:

```bash
# Generate all formats and keep temp files
make dev

# Generate only academic English resume and keep temp file
make dev-academic-en

# Other specific dev targets
make dev-academic-fr
make dev-business-en
make dev-business-fr
```

The temporary files are created in the project root with names like `temp_academic_en.typ`. You can edit these files directly for quick development and testing.

#### Testing and Cleaning

```bash
# Run tests (will check links)
make test

# Run tests in offline mode (skips actual URL validation)
make test-offline

# Check code style with Ruff
make lint

# Clean generated files
make clean

# Full release process (clean, build, test)
make release

# Simulate CI pipeline
make ci-test
```

#### Publishing PDFs

```bash
# Build, run offline link checks, and push PDFs to the published branch
make publish

# The same flow with custom options
uv run python publish.py --skip-tests --branch published --remote origin
```

The helper script (`publish.py`) creates a temporary git worktree, copies every
PDF from `output/`, and commits the artifacts to the `published` branch (or any
branch you supply via `--branch`). By default it:

- Rebuilds the PDFs locally with Typst
- Runs the pytest link checks against the live network
- Pushes the resulting commit to `origin/published`

Optional flags:

- `--skip-build` – reuse the PDFs already in `output/`
- `--skip-tests` – skip running the link checker before publishing
- `--offline-tests` – run link checks in offline mode (skips network calls)

Paths on `published` continue to work with the README links, so no additional
GitHub automation is required.

Note: `make clean` runs the Ruff lint check first, so fix any lint issues (or
run `make lint` directly) before cleaning completes.

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

### Continuous Integration (optional)

The GitHub Actions workflow in `.github/workflows/build-resumes.yml` remains
available if you still want automated builds, provenance attestations, or
release artifacts. With the new `publish.py` helper you can also skip CI
entirely and publish from your workstation. Disable or remove the workflow when
it is no longer needed.

#### Repository Organization

The repository uses a branch structure where:
- `develop`: Active development work
- `main`: Production-ready code
- `published`: Contains the built PDF artifacts

When making changes, work on the `develop` branch and merge to `main` when ready to publish.
