import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from resume_cli.common import collect_pdfs


class PublicationTests(unittest.TestCase):
    def test_default_selection_excludes_private_and_legacy_pdfs(self):
        expected = {
            "himmens_joshua_academic_resume.pdf",
            "himmens_joshua_academic_resume_fr.pdf",
            "himmens_joshua_business_resume.pdf",
            "himmens_joshua_business_resume_fr.pdf",
        }
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            for name in expected | {"private.pdf", "himmens_joshua_academic_resume_goc.pdf"}:
                (output / name).touch()
            with patch("resume_cli.common.OUTPUT_DIR", output):
                self.assertEqual({p.name for p in collect_pdfs(None)}, expected)
