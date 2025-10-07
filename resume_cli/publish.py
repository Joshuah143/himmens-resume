from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Iterable, List, Optional

import typer

from .build import build_resumes
from .common import (
    CLIError,
    DEFAULT_LINK_DELAY,
    DEFAULT_MESSAGE_TEMPLATE,
    PROJECT_ROOT,
    PublishOptions,
    PublishTarget,
    ResumeLanguage,
    ResumeType,
    apply_message,
    collect_pdfs,
    run_command,
)
from .validate import validate_links


def load_publish_config(path: Path) -> PublishOptions:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise CLIError(f"Invalid JSON in {path}: {exc}") from exc

    options = PublishOptions()

    targets_definition = data.get("targets")
    if isinstance(targets_definition, list):
        for entry in targets_definition:
            if not isinstance(entry, dict):
                raise CLIError("Each target in config must be an object with 'remote' and 'branch'.")
            remote = entry.get("remote") or "origin"
            branch = entry.get("branch") or "published"
            options.targets.append(PublishTarget(remote=remote, branch=branch))

    if not options.targets:
        remote = data.get("remote", "origin")
        branch = data.get("branch", "published")
        options.targets.append(PublishTarget(remote=remote, branch=branch))

    options.skip_build = bool(data.get("skip_build", False))
    options.skip_tests = bool(data.get("skip_tests", False))
    options.offline_tests = bool(data.get("offline_tests", False))
    message_template = data.get("message_template")
    if isinstance(message_template, str) and message_template.strip():
        options.message_template = message_template

    if types := data.get("types"):
        options.types = [ResumeType(t) for t in types]
    if languages := data.get("languages"):
        options.languages = [ResumeLanguage(l) for l in languages]

    return options


def parse_target_options(targets: List[str]) -> List[PublishTarget]:
    parsed: List[PublishTarget] = []
    for target in targets:
        if ":" not in target:
            raise CLIError("Targets must use the format remote:branch (e.g. origin:published).")
        remote, branch = target.split(":", 1)
        parsed.append(PublishTarget(remote=remote or "origin", branch=branch or "published"))
    return parsed


def ensure_worktree(worktree_path: Path, *, branch: str, remote: str) -> None:
    remote_ref = f"{remote}/{branch}"

    remote_exists = run_command(
        ["git", "show-ref", "--verify", "--quiet", f"refs/remotes/{remote}/{branch}"],
        cwd=PROJECT_ROOT,
        check=False,
    )

    if remote_exists.returncode == 0:
        args = ["git", "worktree", "add", "--force", "-B", branch, str(worktree_path), remote_ref]
    else:
        branch_exists = run_command(
            ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
            cwd=PROJECT_ROOT,
            check=False,
        )
        if branch_exists.returncode == 0:
            args = ["git", "worktree", "add", "--force", str(worktree_path), branch]
        else:
            args = ["git", "worktree", "add", "-B", branch, str(worktree_path), "HEAD"]

    run_command(args, cwd=PROJECT_ROOT)


def copy_pdfs_to_worktree(worktree_path: Path, pdfs: List[Path]) -> None:
    target_output = worktree_path / "output"
    target_output.mkdir(parents=True, exist_ok=True)

    for existing in target_output.glob("*.pdf"):
        existing.unlink()

    for pdf in pdfs:
        (target_output / pdf.name).write_bytes(pdf.read_bytes())


def stage_worktree_changes(worktree_path: Path, pdfs: List[Path]) -> bool:
    run_command(["git", "add", "-u", "output"], cwd=worktree_path, check=False)
    for pdf in pdfs:
        relative_pdf = (worktree_path / "output" / pdf.name).relative_to(worktree_path)
        run_command(["git", "add", "-f", str(relative_pdf)], cwd=worktree_path)

    diff_check = run_command(["git", "diff", "--cached", "--quiet"], cwd=worktree_path, check=False)
    return diff_check.returncode != 0


def publish_to_target(target: PublishTarget, *, message_template: str, pdfs: List[Path]) -> None:
    if not pdfs:
        raise CLIError("No PDFs found in output/. Build resumes before publishing.")

    try:
        run_command(["git", "fetch", target.remote, target.branch], cwd=PROJECT_ROOT)
    except CLIError:
        typer.echo(f"Warning: could not fetch {target.remote}/{target.branch}. Proceeding with local refs.")

    with tempfile.TemporaryDirectory(prefix="publish-worktree-") as tmp_dir:
        worktree_path = Path(tmp_dir)
        ensure_worktree(worktree_path, branch=target.branch, remote=target.remote)
        try:
            copy_pdfs_to_worktree(worktree_path, pdfs)
            if not stage_worktree_changes(worktree_path, pdfs):
                typer.echo(f"No changes to publish for {target.remote}/{target.branch}.")
                return

            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
            message = apply_message(
                message_template,
                timestamp=timestamp,
                branch=target.branch,
                remote=target.remote,
            )
            run_command(["git", "commit", "-m", message], cwd=worktree_path)
            run_command(["git", "push", target.remote, target.branch], cwd=worktree_path)
            typer.echo(f"Published {len(pdfs)} PDFs to {target.remote}/{target.branch}.")
        finally:
            run_command(["git", "worktree", "remove", "--force", str(worktree_path)], cwd=PROJECT_ROOT, check=False)


def merge_publish_inputs(
    *,
    branch: str,
    remote: str,
    config: Optional[Path],
    targets: Optional[List[str]],
    skip_build: bool,
    skip_tests: bool,
    offline_tests: bool,
    message_template: str,
    types: Optional[Iterable[ResumeType]],
    languages: Optional[Iterable[ResumeLanguage]],
) -> PublishOptions:
    options = PublishOptions()
    options.skip_build = skip_build
    options.skip_tests = skip_tests
    options.offline_tests = offline_tests
    options.message_template = message_template or DEFAULT_MESSAGE_TEMPLATE
    if types:
        options.types = list(types)
    if languages:
        options.languages = list(languages)

    if config:
        config_options = load_publish_config(config)
        options.targets = config_options.targets
        if types is None:
            options.types = config_options.types
        if languages is None:
            options.languages = config_options.languages
        options.skip_build = options.skip_build or config_options.skip_build
        options.skip_tests = options.skip_tests or config_options.skip_tests
        options.offline_tests = options.offline_tests or config_options.offline_tests
        if message_template == DEFAULT_MESSAGE_TEMPLATE and config_options.message_template:
            options.message_template = config_options.message_template

    if targets:
        options.targets = parse_target_options(targets)
    elif not options.targets:
        options.targets = [PublishTarget(remote=remote, branch=branch)]

    return options


def register(app: typer.Typer) -> None:
    @app.command()
    def publish(
        branch: str = typer.Option("published", "--branch", help="Default branch that receives published PDFs."),
        remote: str = typer.Option("origin", "--remote", help="Git remote to push to."),
        target: Optional[List[str]] = typer.Option(
            None,
            "--target",
            "-t",
            help="Override remote/branch pairs using remote:branch syntax (repeatable).",
        ),
        config: Optional[Path] = typer.Option(
            None,
            "--config",
            help="Optional JSON file with publish settings (targets, skip flags, message template).",
        ),
        skip_build: bool = typer.Option(False, "--skip-build", help="Reuse existing PDFs instead of rebuilding."),
        skip_tests: bool = typer.Option(False, "--skip-tests", help="Skip link validation before publishing."),
        offline_tests: bool = typer.Option(False, "--offline-tests", help="Run link checks offline when publishing."),
        message_template: str = typer.Option(
            DEFAULT_MESSAGE_TEMPLATE,
            "--message-template",
            help="Template for commit messages. Supports ${timestamp}, ${remote}, ${branch}.",
        ),
        types: Optional[List[ResumeType]] = typer.Option(
            None,
            "--type",
            "-T",
            help="Limit build step to specific resume types when publishing.",
        ),
        languages: Optional[List[ResumeLanguage]] = typer.Option(
            None,
            "--language",
            "-L",
            help="Limit build step to specific languages when publishing.",
        ),
    ) -> None:
        """Build (unless skipped), validate, and push PDFs to one or more publish targets."""
        options = merge_publish_inputs(
            branch=branch,
            remote=remote,
            config=config,
            targets=target,
            skip_build=skip_build,
            skip_tests=skip_tests,
            offline_tests=offline_tests,
            message_template=message_template,
            types=types,
            languages=languages,
        )

        if not options.skip_build:
            try:
                build_resumes(types=options.types, languages=options.languages, keep_temp=False)
            except CLIError as exc:
                typer.secho(str(exc), fg=typer.colors.RED)
                raise typer.Exit(1)
        else:
            typer.echo("Skipping build step; reusing existing PDFs in output/.")

        if options.skip_tests:
            typer.echo("Skipping link validation step as requested.")
            invalid: List[str] = []
        else:
            try:
                invalid = validate_links(
                    offline=options.offline_tests or os.environ.get("CI", "").lower() == "true",
                    delay=DEFAULT_LINK_DELAY,
                    fail_fast=False,
                )
            except CLIError as exc:
                typer.secho(str(exc), fg=typer.colors.RED)
                raise typer.Exit(1)

        if invalid:
            for issue in invalid:
                typer.secho(issue, fg=typer.colors.RED)
            raise typer.Exit(1)

        pdfs = collect_pdfs(None)
        try:
            for publish_target in options.targets:
                publish_to_target(publish_target, message_template=options.message_template, pdfs=pdfs)
        except CLIError as exc:
            typer.secho(str(exc), fg=typer.colors.RED)
            raise typer.Exit(1)
