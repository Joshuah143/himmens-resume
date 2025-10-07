from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from string import Template
from typing import Iterable, List, Optional, Sequence

import typer


class CLIError(RuntimeError):
    """Raised when a command cannot complete successfully."""


PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = PROJECT_ROOT / "output"
TEMPLATES_DIR = PROJECT_ROOT / "resume_templates"
TEMP_PATTERN = "temp_{resume_type}_{language}.typ"
CONTENT_PATTERN = "cv_content_{language}.yaml"
DEFAULT_TYPES = ("academic", "business")
DEFAULT_LANGUAGES = ("en", "fr")
PERSONAL_DOMAINS = ("himmens.com",)
WHITELISTED_HOSTS = ("linkedin.com", "github.com")
DEFAULT_HTTP_TIMEOUT = 10
DEFAULT_LINK_DELAY = 0.5
DEFAULT_MESSAGE_TEMPLATE = "Publish resumes (${timestamp})"


class ResumeType(str, Enum):
    academic = "academic"
    business = "business"


class ResumeLanguage(str, Enum):
    en = "en"
    fr = "fr"


@dataclass
class PublishTarget:
    remote: str
    branch: str


@dataclass
class PublishOptions:
    targets: List[PublishTarget] = field(default_factory=list)
    skip_build: bool = False
    skip_tests: bool = False
    offline_tests: bool = False
    message_template: str = DEFAULT_MESSAGE_TEMPLATE
    types: Optional[List[ResumeType]] = None
    languages: Optional[List[ResumeLanguage]] = None


def echo_command(cmd: Sequence[str], cwd: Optional[Path] = None) -> None:
    location = f" (cwd={cwd})" if cwd else ""
    typer.echo(f"$ {' '.join(cmd)}{location}")


def run_command(
    cmd: Sequence[str],
    *,
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
    check: bool = True,
) -> subprocess.CompletedProcess:
    echo_command(cmd, cwd)
    try:
        return subprocess.run(cmd, cwd=cwd, env=env, check=check)
    except subprocess.CalledProcessError as exc:  # pragma: no cover - fatal path
        raise CLIError(
            f"Command failed with exit code {exc.returncode}: {' '.join(cmd)}"
        ) from exc


def ensure_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise CLIError(f"Required tool '{name}' is not available on PATH.")


def resolve_types(types: Optional[Iterable[ResumeType]]) -> List[ResumeType]:
    return list(types) if types else [ResumeType(t) for t in DEFAULT_TYPES]


def resolve_languages(languages: Optional[Iterable[ResumeLanguage]]) -> List[ResumeLanguage]:
    return list(languages) if languages else [ResumeLanguage(l) for l in DEFAULT_LANGUAGES]


def output_filename(resume_type: ResumeType, language: ResumeLanguage) -> str:
    suffix = "_fr" if language == ResumeLanguage.fr else ""
    return f"himmens_joshua_{resume_type.value}_resume{suffix}.pdf"


def collect_pdfs(paths: Optional[List[Path]]) -> List[Path]:
    if paths:
        pdfs = [path.resolve() for path in paths]
    else:
        pdfs = sorted(OUTPUT_DIR.glob("*.pdf"))
    return [pdf for pdf in pdfs if pdf.exists()]


def apply_message(template: str, **values: str) -> str:
    return Template(template).safe_substitute(**values)
