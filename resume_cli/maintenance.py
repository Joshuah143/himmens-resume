from __future__ import annotations

import os
import shutil

import typer

from .build import build_resumes
from .common import (
    CLIError,
    DEFAULT_LINK_DELAY,
    OUTPUT_DIR,
    PROJECT_ROOT,
    ensure_tool,
    run_command,
)
from .validate import validate_links


def clean_artifacts(*, remove_pdfs: bool, remove_temp: bool) -> None:
    if remove_pdfs and OUTPUT_DIR.exists():
        for pdf in OUTPUT_DIR.glob("*.pdf"):
            typer.echo(f"Removing {pdf.relative_to(PROJECT_ROOT)}")
            pdf.unlink()
    if remove_temp:
        for temp in PROJECT_ROOT.glob("temp_*.typ"):
            typer.echo(f"Removing {temp.relative_to(PROJECT_ROOT)}")
            temp.unlink()


def run_lint(*, use_uv: bool, fix: bool) -> None:
    command = ["ruff", "check", "."]
    if fix:
        command.append("--fix")

    if use_uv and shutil.which("uv"):
        run_command(["uv", "tool", "run", *command])
    else:
        ensure_tool(command[0])
        run_command(command)


def release_pipeline(*, keep_temp: bool, offline: bool) -> None:
    clean_artifacts(remove_pdfs=True, remove_temp=True)
    build_resumes(keep_temp=keep_temp)
    invalid = validate_links(
        offline=offline or os.environ.get("CI", "").lower() == "true",
        delay=DEFAULT_LINK_DELAY,
        fail_fast=False,
    )
    if invalid:
        raise CLIError("\n".join(invalid))


def register(app: typer.Typer) -> None:
    @app.command()
    def lint(
        fix: bool = typer.Option(False, "--fix", help="Automatically apply lint fixes if Ruff supports them."),
        use_uv: bool = typer.Option(
            True,
            "--use-uv/--no-use-uv",
            help="Invoke Ruff via 'uv tool run' when available (defaults to enabled).",
        ),
    ) -> None:
        """Run Ruff against the repository."""
        try:
            run_lint(use_uv=use_uv, fix=fix)
        except CLIError as exc:
            typer.secho(str(exc), fg=typer.colors.RED)
            raise typer.Exit(1)

    @app.command()
    def clean(
        remove_pdfs: bool = typer.Option(True, "--pdfs/--no-pdfs", help="Delete PDFs in output/."),
        remove_temp: bool = typer.Option(True, "--temps/--no-temps", help="Delete temp Typst files in repo root."),
    ) -> None:
        """Remove generated PDFs and/or Typst scratch files."""
        clean_artifacts(remove_pdfs=remove_pdfs, remove_temp=remove_temp)

    @app.command()
    def release(
        keep_temp: bool = typer.Option(False, "--keep-temp", help="Keep temp Typst sources after the build."),
        offline: bool = typer.Option(False, "--offline", help="Run link checks without touching the network."),
    ) -> None:
        """Clean, rebuild every resume, and validate links in a single flow."""
        try:
            release_pipeline(keep_temp=keep_temp, offline=offline)
        except CLIError as exc:
            typer.secho(str(exc), fg=typer.colors.RED)
            raise typer.Exit(1)
        typer.secho("Release pipeline completed successfully.", fg=typer.colors.GREEN)
