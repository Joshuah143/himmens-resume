from __future__ import annotations

import typer

from . import build, maintenance, publish, validate

app = typer.Typer(
    add_completion=False,
    help="Build, validate, and publish resumes from the structured content in this repository.",
)

build.register(app)
validate.register(app)
maintenance.register(app)
publish.register(app)

__all__ = ["app"]
