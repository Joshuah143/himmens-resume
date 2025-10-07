from __future__ import annotations

import os
import re
import time
import warnings
from pathlib import Path
from typing import List, Optional

import pymupdf
import requests
import typer

from .common import (
    CLIError,
    DEFAULT_HTTP_TIMEOUT,
    DEFAULT_LINK_DELAY,
    PERSONAL_DOMAINS,
    PROJECT_ROOT,
    WHITELISTED_HOSTS,
    collect_pdfs,
)


def check_uri(uri: str, *, offline: bool, delay: float) -> bool:
    if not uri:
        return False

    scheme_split = uri.split(":", 1)
    if len(scheme_split) < 2:
        return False

    protocol = scheme_split[0].lower()

    if protocol == "https":
        try:
            domain = uri.split("//", 1)[1].split("/", 1)[0]
        except IndexError:
            return False

        if any(domain.endswith(d) or d in domain for d in PERSONAL_DOMAINS):
            return True
        if any(host in domain for host in WHITELISTED_HOSTS):
            return True
        if offline:
            return True

        headers = {"User-Agent": "Mozilla/5.0 (Resume-Link-Checker; Bot)"}
        time.sleep(max(delay, 0))
        try:
            response = requests.get(uri, headers=headers, timeout=DEFAULT_HTTP_TIMEOUT, allow_redirects=True)
            return response.status_code < 400
        except requests.RequestException:
            return False

    if protocol == "mailto":
        email_part = scheme_split[1].strip()
        email_regex = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        return bool(re.match(email_regex, email_part))

    if protocol == "tel":
        phone_part = scheme_split[1].strip()
        phone_clean = re.sub(r"[\s\-\(\).]", "", phone_part)
        return len(phone_clean) >= 7 and phone_clean.isdigit()

    return False


def validate_links(
    *,
    offline: bool,
    delay: float,
    fail_fast: bool,
    explicit_pdfs: Optional[List[Path]] = None,
) -> List[str]:
    warnings.filterwarnings("ignore", category=DeprecationWarning, message=".*SwigPy.*")
    pdfs = collect_pdfs(explicit_pdfs)
    if not pdfs:
        raise CLIError("No PDFs found to validate. Build resumes first or supply --pdf paths.")

    invalid: List[str] = []
    for pdf in pdfs:
        typer.echo(f"Validating links in {pdf.relative_to(PROJECT_ROOT)}")
        with pymupdf.open(pdf) as doc:  # type: ignore[arg-type]
            if len(doc) == 0:
                invalid.append(f"{pdf.name}: empty PDF")
                if fail_fast:
                    return invalid
            for idx, page in enumerate(doc, start=1):
                for link in page.get_links():
                    uri = link.get("uri")
                    if uri and not check_uri(uri, offline=offline, delay=delay):
                        invalid.append(f"{pdf.name}: invalid URL {uri} on page {idx}")
                        if fail_fast:
                            return invalid
    return invalid


def register(app: typer.Typer) -> None:
    @app.command("check-links")
    def check_links_command(
        offline: bool = typer.Option(
            False,
            "--offline",
            help="Skip network checks and only validate link format.",
        ),
        delay: float = typer.Option(
            DEFAULT_LINK_DELAY,
            "--delay",
            help="Delay (seconds) between HTTP requests to avoid rate limiting.",
        ),
        fail_fast: bool = typer.Option(
            False,
            "--fail-fast",
            help="Exit on the first invalid link instead of collecting all failures.",
        ),
        pdf: Optional[List[Path]] = typer.Option(
            None,
            "--pdf",
            help="Specific PDF paths to validate. Defaults to every resume in output/.",
        ),
    ) -> None:
        """Validate embedded links inside the generated PDF resumes."""
        resolved_offline = offline or os.environ.get("CI", "").lower() == "true"
        try:
            invalid = validate_links(
                offline=resolved_offline,
                delay=delay,
                fail_fast=fail_fast,
                explicit_pdfs=pdf,
            )
        except CLIError as exc:
            typer.secho(str(exc), fg=typer.colors.RED)
            raise typer.Exit(1)

        if invalid:
            for issue in invalid:
                typer.secho(issue, fg=typer.colors.RED)
            raise typer.Exit(1)
        typer.secho("All links look good!", fg=typer.colors.GREEN)
