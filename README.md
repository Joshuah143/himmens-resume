# Joshua Himmens Resume

A resume system that generates multiple resume formats (academic and business) in different languages (English and French) from YAML content files.

## Features

- Content-template separation using YAML files for content and Typst for formatting
- Multiple languages support (English, French)
- Multiple resume formats (academic, business)
- Automated PDF generation with GitHub Actions
- Link validation tests to ensure all URLs are valid
- Dynamically generated Typst files for each combination of resume type and language

## Directory Structure

- `cv_content_en.yaml` - English content file
- `cv_content_fr.yaml` - French content file
- `resume_templates/` - Reusable Typst templates
  - `academic.typ` - Academic resume template
  - `business.typ` - Business resume template
  - `utils.typ` - Utility functions for formatting
- `build.py` - Python script to build all resume formats
- `tests/` - Tests for validating resumes
- `output/` - Generated PDF resume files

## Usage

### Building Resumes

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

### Development Mode

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

### Running Tests

```bash
make test
# or
uv run -m pytest -v tests/
```

### Clean Generated Files

```bash
make clean
```

### Adding Content

1. Edit the YAML files:
   - `cv_content_en.yaml` for English
   - `cv_content_fr.yaml` for French

2. The YAML structure includes:
   - Personal information
   - Education
   - Work experience
   - Publications
   - Awards
   - Skills
   - Advocacy/leadership
   - Additional experiences
   - UI text for localization

3. Use the `visible` or `show` flags to control which items appear in the resumes

### Customizing Templates

1. Edit the template files in the `resume_templates/` directory:
   - `academic.typ` for academic resumes
   - `business.typ` for business resumes

2. Adjust formatting, fonts, colors, and sections as needed

## How It Works

The system uses a dynamic template approach:

1. Content is stored in language-specific YAML files
2. Templates are language-agnostic and read UI text from the content files
3. The build script generates temporary Typst files for each combination of template and language
4. Typst compiles these files into PDF resumes
5. GitHub Actions automates the build and test process for CI/CD

## Continuous Integration

The project uses GitHub Actions for CI/CD with the following features:

### PDF Generation

When changes are pushed to the repository:

1. The CI pipeline automatically builds all resume formats
2. Tests are run to validate all links and content
3. PDFs are stored in three ways:
   - As GitHub Actions artifacts (available for 90 days)
   - In a separate "published" branch for direct GitHub access
   - As GitHub Releases (when merged to main branch)

### Accessing Generated PDFs

You can access the latest PDFs in any of these ways:

1. **From the Releases page**: Visit the [Releases](../../releases) page to download specific versions
2. **From the "published" branch**: Browse the `output/` directory in the [published branch](../../tree/published/output)
3. **From Actions artifacts**: Find the most recent successful workflow run in [Actions](../../actions) and download the artifacts

### Running CI Locally

To simulate the CI process locally:

```bash
# Simulate the full CI pipeline (clean, build, test in offline mode)
make ci-test

# Run tests in offline mode (skips actual URL validation)
make test-offline

# Full release process (clean, build all formats, run tests with URL validation)
make release

# Just build and test with URL validation
make test
```

## Credits

Academic resume template adapted from [ImpreCV](https://github.com/jskherman/imprecv).
