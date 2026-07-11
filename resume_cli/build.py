from __future__ import annotations

from pathlib import Path
from typing import Iterable, List, Optional

import typer

from .common import (
    CLIError,
    CONTENT_PATTERN,
    OUTPUT_DIR,
    PROJECT_ROOT,
    TEMP_PATTERN,
    ResumeLanguage,
    ResumeType,
    output_filename,
    resolve_languages,
    resolve_types,
    run_command,
)


def generate_temp_typst_file(resume_type: ResumeType, language: ResumeLanguage) -> Path:
    temp_name = TEMP_PATTERN.format(resume_type=resume_type.value, language=language.value)
    temp_path = PROJECT_ROOT / temp_name
    template_name = f"{resume_type.value}.typ"
    template_path = PROJECT_ROOT / "resume_templates" / template_name
    if not template_path.exists():
        raise CLIError(f"Missing template: {template_path}")

    content_name = CONTENT_PATTERN.format(language=language.value)
    content_path = PROJECT_ROOT / content_name
    if not content_path.exists():
        raise CLIError(f"Missing content file: {content_path}")

    temp_content = f"""
#import \"resume_templates/{template_name}\": {resume_type.value}_template
// load content file
#let content_file = (content_file: \"{content_name}\").content_file
#let content = yaml(content_file)
// generate resume
#{resume_type.value}_template(content)
    """
    temp_path.write_text(temp_content, encoding="utf-8")
    return temp_path


def build_single(
    resume_type: ResumeType,
    language: ResumeLanguage,
    *,
    keep_temp: bool,
    output_dir: Path,
    goc: bool = False,
) -> None:
    temp_file = generate_temp_typst_file(resume_type, language)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / output_filename(resume_type, language, goc=goc)

    typer.echo(f"Building {output_file.relative_to(PROJECT_ROOT)}")
    cmd = [
        "typst",
        "compile",
        "--input",
        f"content_file={CONTENT_PATTERN.format(language=language.value)}",
        "--input",
        f"goc={'true' if goc else 'false'}",
        str(temp_file),
        str(output_file),
    ]

    try:
        run_command(cmd)
    finally:
        if not keep_temp and temp_file.exists():
            temp_file.unlink()


def build_resumes(
    *,
    types: Optional[Iterable[ResumeType]] = None,
    languages: Optional[Iterable[ResumeLanguage]] = None,
    keep_temp: bool = False,
    output_dir: Path = OUTPUT_DIR,
    goc: bool = False,
) -> None:
    resolved_types = resolve_types(types)
    resolved_languages = resolve_languages(languages)

    for resume_type in resolved_types:
        for language in resolved_languages:
            build_single(
                resume_type,
                language,
                keep_temp=keep_temp,
                output_dir=output_dir,
                goc=goc,
            )


def register(app: typer.Typer) -> None:
    @app.command()
    def build(
        types: Optional[List[ResumeType]] = typer.Option(
            None,
            "--type",
            "-t",
            help="Resume types to build (repeat flag for multiples). Defaults to all.",
        ),
        languages: Optional[List[ResumeLanguage]] = typer.Option(
            None,
            "--language",
            "-l",
            help="Languages to build (repeat flag for multiples). Defaults to all.",
        ),
        keep_temp: bool = typer.Option(
            False,
            "--keep-temp",
            help="Keep the intermediate Typst files (equivalent to previous dev targets).",
        ),
        output: Path = typer.Option(
            OUTPUT_DIR,
            "--output",
            "-o",
            help="Directory for generated PDFs.",
        ),
        goc: bool = typer.Option(
            False,
            "--goc",
            help=(
                "Render the Government of Canada variant: include home address, PRI, "
                "month/year dates, and full-time/part-time status with hours per week."
            ),
        ),
    ) -> None:
        """Compile resume PDFs for the requested type/language combinations."""
        try:
            build_resumes(
                types=types,
                languages=languages,
                keep_temp=keep_temp,
                output_dir=output,
                goc=goc,
            )
        except CLIError as exc:
            typer.secho(str(exc), fg=typer.colors.RED)
            raise typer.Exit(1)
