# Joshua Himmens Resume

A system that generates multiple resume formats in different languages from structured YAML content.

## Public Information

### Available Resume Formats

- **Academic Resume**: [English](https://github.com/Joshuah143/himmens-resume/raw/published/output/himmens_joshua_academic_resume.pdf) | [French](https://github.com/Joshuah143/himmens-resume/raw/published/output/himmens_joshua_academic_resume_fr.pdf)
- **Business Resume**: [English](https://github.com/Joshuah143/himmens-resume/raw/published/output/himmens_joshua_business_resume.pdf) | [French](https://github.com/Joshuah143/himmens-resume/raw/published/output/himmens_joshua_business_resume_fr.pdf)

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

# Clean generated files
make clean

# Full release process (clean, build, test)
make release

# Simulate CI pipeline
make ci-test
```

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

### Continuous Integration

The project uses GitHub Actions for CI/CD with the following features:

#### PDF Generation

When changes are pushed to the repository:

1. The CI pipeline automatically builds all resume formats
2. Tests are run to validate all links and content
3. PDFs are stored in three ways:
   - As GitHub Actions artifacts (available for 90 days)
   - In a separate "published" branch for direct GitHub access
   - As GitHub Releases (when merged to main branch)

#### Build Provenance and Security

For PDFs generated from the main branch, our CI pipeline uses GitHub's [Build Provenance](https://docs.github.com/en/actions/security-guides/using-build-attestations-with-github-actions) attestation to create cryptographically verifiable signatures. This ensures:

- PDFs are built from the exact source code in the repository
- The build process is traceable and tamper-evident
- Chain of custody for the PDFs is maintained

To verify attestations of downloaded PDFs, use:

```bash
gh attestation verify <pdf-file> --repo joshuah143/himmens-resume
```

**Note:** Attestation requires proper repository permissions. Make sure the repository settings allow GitHub Actions to create attestations by:
1. Going to Settings → Actions → General → Workflow permissions
2. Enabling "Read and write permissions" 
3. Checking "Allow GitHub Actions to create and approve pull requests"

#### Repository Organization

The repository uses a branch structure where:
- `develop`: Active development work
- `main`: Production-ready code
- `published`: Contains the built PDF artifacts

When making changes, work on the `develop` branch and merge to `main` when ready to publish.
