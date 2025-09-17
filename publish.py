#!/usr/bin/env python3
"""Build resume PDFs locally and push them to a publication branch.

Running ``python publish.py`` (or ``make publish`` after adding the Makefile
helper) performs three high-level steps:

1. Build the PDFs with Typst (unless ``--skip-build`` is given).
2. Optionally run the pytest suite in offline mode to check embedded links.
3. Copy the PDFs into a dedicated git worktree for the publication branch and
   push a commit containing the updated artifacts.

This keeps the publishing flow lightweight and developer-operated without
relying on GitHub Actions.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Sequence

PROJECT_ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = PROJECT_ROOT / "output"
DEFAULT_BRANCH = "published"
DEFAULT_REMOTE = "origin"


class PublishError(RuntimeError):
    """Raised when publishing cannot proceed."""


def run(cmd: Sequence[str], *, cwd: Path | None = None, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess:
    """Execute a subprocess while echoing the invoked command."""
    printable_cwd = f" (cwd={cwd})" if cwd else ""
    print(f"$ {' '.join(cmd)}{printable_cwd}")
    try:
        return subprocess.run(cmd, cwd=cwd, env=env, check=check)
    except subprocess.CalledProcessError as exc:  # pragma: no cover - fatal path
        raise PublishError(f"Command failed with exit code {exc.returncode}: {' '.join(cmd)}") from exc


def ensure_prerequisites() -> None:
    """Ensure the required CLI tools exist before starting."""
    if shutil.which("git") is None:
        raise PublishError("git is not available on PATH. Install git to continue.")
    if shutil.which("typst") is None:
        raise PublishError(
            "typst is not available on PATH. Install Typst from https://github.com/typst/typst/releases "
            "and make sure the binary is accessible."
        )


def build_pdfs(skip_build: bool) -> None:
    """Build all resume PDFs unless explicitly skipped."""
    if skip_build:
        print("Skipping build step as requested. Using existing PDFs in output/.")
        return
    run([sys.executable, "build.py"], cwd=PROJECT_ROOT)


def run_tests(skip_tests: bool, offline: bool) -> None:
    """Run pytest to validate generated PDFs."""
    if skip_tests:
        print("Skipping tests as requested.")
        return

    cmd = [sys.executable, "-m", "pytest", "-v", "tests/"]
    env = os.environ.copy()
    if offline:
        env["CI"] = "true"  # triggers offline-friendly behaviour in tests
    else:
        env.pop("CI", None)

    run(cmd, cwd=PROJECT_ROOT, env=env)


def ref_exists(ref: str) -> bool:
    """Return True if the given ref exists in the repository."""
    result = subprocess.run(["git", "show-ref", "--verify", "--quiet", ref], cwd=PROJECT_ROOT)
    return result.returncode == 0


def ensure_worktree(path: Path, branch: str, remote: str) -> None:
    """Create a git worktree checked out at the publication branch."""
    remote_ref = f"{remote}/{branch}"
    local_args: list[str]

    if ref_exists(f"refs/remotes/{remote}/{branch}"):
        # Align the local branch with the remote reference before adding the worktree.
        local_args = ["git", "worktree", "add", "--force", "-B", branch, str(path), remote_ref]
    elif ref_exists(f"refs/heads/{branch}"):
        local_args = ["git", "worktree", "add", "--force", str(path), branch]
    else:
        # Create a new branch starting from the current HEAD.
        local_args = ["git", "worktree", "add", "-B", branch, str(path), "HEAD"]

    run(local_args, cwd=PROJECT_ROOT)


def copy_pdfs_to_worktree(worktree_path: Path, pdfs: list[Path]) -> None:
    """Copy built PDFs into the worktree output directory."""
    target_output = worktree_path / "output"
    target_output.mkdir(parents=True, exist_ok=True)

    # Remove existing PDFs so obsolete files do not linger.
    for existing_pdf in target_output.glob("*.pdf"):
        existing_pdf.unlink()

    for pdf in pdfs:
        shutil.copy2(pdf, target_output / pdf.name)


def stage_changes(worktree_path: Path, pdfs: list[Path]) -> bool:
    """Stage output changes and return True when there is something to commit."""
    if not pdfs:
        return False

    run(["git", "add", "-u", "output"], cwd=worktree_path, check=False)
    # Add PDFs explicitly with -f to bypass .gitignore rules.
    for pdf in pdfs:
        run(["git", "add", "-f", str((worktree_path / 'output' / pdf.name).relative_to(worktree_path))], cwd=worktree_path)

    diff_check = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=worktree_path)
    return diff_check.returncode != 0


def commit_and_push(worktree_path: Path, branch: str, remote: str) -> None:
    """Create a commit with the staged PDFs and push it to the remote."""
    timestamp = _dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    message = f"Publish resumes ({timestamp})"
    run(["git", "commit", "-m", message], cwd=worktree_path)
    run(["git", "push", remote, branch], cwd=worktree_path)


def publish(branch: str, remote: str) -> None:
    """Copy PDFs into a dedicated worktree and push them."""
    pdfs = sorted(OUTPUT_DIR.glob("*.pdf"))
    if not pdfs:
        raise PublishError("No PDFs found in output/. Run the build step before publishing.")

    # Fetch remote refs to ensure we publish on top of the latest commit when possible.
    try:
        run(["git", "fetch", remote, branch], cwd=PROJECT_ROOT)
    except PublishError as fetch_error:
        print(f"Warning: could not fetch {remote}/{branch}: {fetch_error}")
        print("Proceeding with local refs only.")

    with tempfile.TemporaryDirectory(prefix="publish-worktree-") as tmp_dir:
        worktree_path = Path(tmp_dir)
        ensure_worktree(worktree_path, branch, remote)

        try:
            copy_pdfs_to_worktree(worktree_path, pdfs)
            if not stage_changes(worktree_path, pdfs):
                print("Nothing new to publish. PDFs already up to date.")
                return
            commit_and_push(worktree_path, branch, remote)
            print(f"Published {len(pdfs)} PDFs to {remote}/{branch}.")
        finally:
            run(["git", "worktree", "remove", "--force", str(worktree_path)], cwd=PROJECT_ROOT, check=False)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build PDFs and publish them to a git branch.")
    parser.add_argument("--branch", default=DEFAULT_BRANCH, help="Branch used to store published PDFs (default: published)")
    parser.add_argument("--remote", default=DEFAULT_REMOTE, help="Remote that receives the publication branch (default: origin)")
    parser.add_argument("--skip-build", action="store_true", help="Skip rebuilding PDFs and reuse existing output")
    parser.add_argument("--skip-tests", action="store_true", help="Skip running pytest before publishing")
    parser.add_argument("--offline-tests", action="store_true", help="Run link checks without touching the network")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])

    try:
        ensure_prerequisites()
        build_pdfs(args.skip_build)
        run_tests(args.skip_tests, offline=args.offline_tests)
        publish(args.branch, args.remote)
    except PublishError as exc:
        print(f"Publish failed: {exc}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
