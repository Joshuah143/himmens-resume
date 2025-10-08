# Repository Guidelines

## Project Structure & Module Organization
- `resume_cli/` is a Typer package composed of modular commands (`build.py`, `validate.py`, `maintenance.py`, `publish.py`, `common.py`) that build, lint, validate, and publish resumes. `resume_templates/` holds `academic.typ`, `business.typ`, `utils.typ`. YAML content lives at the repo root. `assets/` stores shared graphics, and `output/` contains generated PDFs (gitignored).
- The Makefile now only points contributors to the CLI; `pyproject.toml` exposes the `resume` / `build-resume` console entry points and records dependencies.

## Build, Test, and Development Commands
- `uv run resume build` renders every resume variant (entry point defined in `pyproject.toml`).
- Use `--type` / `--language` flags (repeatable) to scope builds. Example: `uv run resume build --type business --language fr`.
- Pass `--keep-temp` to preserve `temp_<type>_<lang>.typ` files for iterative Typst edits.
- Ensure Typst CLI and `uv` are on PATH before running builds.
- `resume -h` mirrors `resume --help` for quick reminders.

## Coding Style & Naming Conventions
- Python code follows Ruff defaults: 4-space indentation, double-quoted docstrings, f-strings, and type hints where practical. Run `uv run resume lint` before committing.
- Keep resume filenames consistent: `himmens_joshua_<type>_resume[_fr].pdf`. Temporary files follow `temp_<type>_<lang>.typ`.
- YAML keys mirror template expectations; prefer `visible`/`show` flags instead of deleting sections.

## Testing Guidelines
- After building, run `uv run resume check-links` for live URL checks or add `--offline` when network access is unavailable.
- The CLI reads PDFs from `output/`; rebuild first or reuse artifacts with `--skip-build` when invoking `publish`. Investigate any failing link before marking offline.

## Commit & Pull Request Guidelines
- Commit messages are concise and action-oriented (see `git log`), e.g., `update french version` or `Fix attestation configuration in GitHub Actions`. Use the imperative mood when possible.
- Work on feature branches off `develop`; merge to `main` once resumes are ready, and run `uv run resume publish` to push PDFs to `published`.
- Pull requests summarize resume or template changes, note whether PDFs were rebuilt, and attach representative diffs or screenshots. Reference related issues and flag follow-up tasks explicitly.

## Publishing Tips
- `uv run resume publish` rebuilds (unless skipped), runs link checks, and commits PDFs via a temporary worktree. Use flags such as `--skip-tests`, `--offline-tests`, `--target remote:branch`, or a JSON `--config` only with explicit justification.
