#!/usr/bin/env python3
"""Regression tests for reference_audit.py that require no network access."""

from __future__ import annotations

import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("reference_audit.py")
SPEC = importlib.util.spec_from_file_location("reference_audit", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def valid_row() -> dict[str, str]:
    row = {field: "" for field in MODULE.FIELDS}
    row.update(
        {
            "claim_id": "REF-01",
            "claim_type": "methodological",
            "claim_text": "A checked methodological claim.",
            "section": "Methodology",
            "source_key": "Example2026",
            "doi_or_url": "10.1234/example",
            "title": "Example & Evidence",
            "authors": "Doe, Jane; Roe, John",
            "year": "2026",
            "venue": "Journal of Tests",
            "volume": "4",
            "issue": "2",
            "pages": "10-20",
            "publisher": "Example Press",
            "source_type": "article",
            "evidence_note": "The source directly establishes the stated method.",
            "limitation_note": "It does not evaluate the thesis sample.",
            "verification_status": "incorporated",
            "metadata_source": "Publisher",
            "verified_on": "2026-07-16",
            "notes": "",
        }
    )
    return row


class ReferenceAuditTests(unittest.TestCase):
    def test_doi_normalization(self) -> None:
        self.assertEqual(MODULE.normalize_doi("https://doi.org/10.1234/ABC"), "10.1234/abc")
        self.assertEqual(MODULE.normalize_doi("not a DOI"), "")

    def test_valid_row(self) -> None:
        errors, warnings = MODULE.validation_messages([valid_row()], MODULE.FIELDS)
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_verified_row_requires_limitation(self) -> None:
        row = valid_row()
        row["limitation_note"] = ""
        errors, _ = MODULE.validation_messages([row], MODULE.FIELDS)
        self.assertTrue(any("limitation_note" in message for message in errors))

    def test_uncited_decision_has_no_source(self) -> None:
        row = valid_row()
        row.update(
            {
                "source_key": "",
                "doi_or_url": "",
                "title": "",
                "authors": "",
                "year": "",
                "venue": "",
                "source_type": "none",
                "verification_status": "decision_without_citation",
                "verified_on": "",
            }
        )
        errors, warnings = MODULE.validation_messages([row], MODULE.FIELDS)
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_conflicting_doi_keys_fail(self) -> None:
        first = valid_row()
        second = valid_row()
        second["claim_id"] = "REF-02"
        second["source_key"] = "Other2026"
        errors, _ = MODULE.validation_messages([first, second], MODULE.FIELDS)
        self.assertTrue(any("also assigned" in message for message in errors))

    def test_scan_and_bib_export(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manuscript = root / "draft.tex"
            claims = root / "claims.csv"
            audit = root / "audit.csv"
            bib = root / "references.bib"
            manuscript.write_text("% REF-03: Benchmark claim\n% TODO-CITE: Another claim\n", encoding="utf-8")
            scan_args = type("Args", (), {"input": str(manuscript), "output": str(claims)})
            self.assertEqual(MODULE.cmd_scan(scan_args), 0)
            with claims.open(newline="", encoding="utf-8") as handle:
                scanned = list(csv.DictReader(handle))
            self.assertEqual([row["claim_id"] for row in scanned], ["REF-03", "SCAN-001"])

            MODULE.write_rows(audit, [valid_row()])
            export_args = type("Args", (), {"audit": str(audit), "output": str(bib)})
            self.assertEqual(MODULE.cmd_export_bib(export_args), 0)
            exported = bib.read_text(encoding="utf-8")
            self.assertIn("@article{Example2026", exported)
            self.assertIn("pages = {10--20}", exported)


if __name__ == "__main__":
    unittest.main()
