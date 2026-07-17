#!/usr/bin/env python3
"""Claim-to-source audit, metadata verification, and BibTeX export."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import json
import os
import re
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


FIELDS = [
    "claim_id",
    "claim_type",
    "claim_text",
    "section",
    "source_key",
    "doi_or_url",
    "title",
    "authors",
    "year",
    "venue",
    "volume",
    "issue",
    "pages",
    "publisher",
    "source_type",
    "evidence_note",
    "limitation_note",
    "verification_status",
    "metadata_source",
    "verified_on",
    "notes",
]

CLAIM_TYPES = {
    "theoretical",
    "methodological",
    "empirical_external",
    "institutional_context",
    "design_choice",
}
SOURCE_TYPES = {
    "article",
    "book",
    "chapter",
    "working_paper",
    "institutional",
    "thesis",
    "none",
}
STATUSES = {
    "candidate",
    "verified",
    "incorporated",
    "rejected",
    "decision_without_citation",
}
VERIFIED_STATUSES = {"verified", "incorporated"}
KEY_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_:+.-]*$")
DOI_RE = re.compile(r"^10\.\d{4,9}/\S+$", re.I)
MARKER_RE = re.compile(
    r"(?P<id>REF-\d+|TODO-CITE|CITATION-NEEDED)\s*:\s*(?P<claim>.+?)\s*$",
    re.I,
)


def normalize_doi(value: str) -> str:
    value = value.strip()
    value = re.sub(r"^(?:https?://(?:dx\.)?doi\.org/|doi:\s*)", "", value, flags=re.I)
    return value.rstrip(". ").lower() if DOI_RE.match(value.rstrip(". ")) else ""


def clean_text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return clean_text(value[0] if value else "")
    return re.sub(r"\s+", " ", html.unescape(str(value))).strip()


def read_rows(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        headers = reader.fieldnames or []
        rows = [{key: clean_text(value) for key, value in row.items()} for row in reader]
    return rows, headers


def write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in FIELDS})


def http_json(url: str, mailto: str = "") -> dict:
    agent = "AcademicReferenceAudit/1.0"
    if mailto:
        agent += f" (mailto:{mailto})"
    request = urllib.request.Request(url, headers={"User-Agent": agent, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def cmd_init(args: argparse.Namespace) -> int:
    output = Path(args.output)
    if output.exists() and not args.force:
        print(f"Refusing to overwrite existing file: {output}", file=sys.stderr)
        return 2
    write_rows(output, [])
    print(f"Initialized {output}")
    return 0


def strip_comment_prefix(line: str) -> str:
    return re.sub(r"^\s*(?:%|#|//|<!--)\s*", "", line).replace("-->", "").strip()


def cmd_scan(args: argparse.Namespace) -> int:
    input_path = Path(args.input)
    findings = []
    auto_id = 1
    for number, raw_line in enumerate(input_path.read_text(encoding="utf-8").splitlines(), start=1):
        line = strip_comment_prefix(raw_line)
        match = MARKER_RE.search(line)
        if not match:
            continue
        marker = match.group("id").upper()
        claim_id = marker if marker.startswith("REF-") else f"SCAN-{auto_id:03d}"
        if not marker.startswith("REF-"):
            auto_id += 1
        findings.append(
            {
                "claim_id": claim_id,
                "marker": marker,
                "claim_text": match.group("claim").strip(),
                "input_file": str(input_path),
                "line": str(number),
            }
        )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    columns = ["claim_id", "marker", "claim_text", "input_file", "line"]
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(findings)
    print(f"Found {len(findings)} explicit citation markers in {input_path}")
    return 0


def inverted_abstract(index: dict | None) -> str:
    if not index:
        return ""
    positioned = []
    for word, positions in index.items():
        positioned.extend((position, word) for position in positions)
    return " ".join(word for _, word in sorted(positioned))


def cmd_discover(args: argparse.Namespace) -> int:
    api_key = args.api_key or os.environ.get("OPENALEX_API_KEY", "")
    params = {
        "search": args.query,
        "per-page": min(max(args.limit, 1), 100),
        "select": "id,doi,title,publication_year,authorships,primary_location,cited_by_count,is_retracted,abstract_inverted_index",
    }
    if api_key:
        params["api_key"] = api_key
    url = "https://api.openalex.org/works?" + urllib.parse.urlencode(params)
    try:
        payload = http_json(url, args.mailto)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"OpenAlex request failed: {exc}", file=sys.stderr)
        return 3

    columns = [
        "rank",
        "title",
        "year",
        "authors",
        "venue",
        "doi",
        "openalex_id",
        "cited_by_count",
        "is_retracted",
        "primary_url",
        "abstract",
    ]
    candidates = []
    for rank, work in enumerate(payload.get("results", []), start=1):
        authors = []
        for authorship in work.get("authorships") or []:
            name = (authorship.get("author") or {}).get("display_name")
            if name:
                authors.append(name)
        location = work.get("primary_location") or {}
        source = location.get("source") or {}
        candidates.append(
            {
                "rank": rank,
                "title": clean_text(work.get("title")),
                "year": clean_text(work.get("publication_year")),
                "authors": "; ".join(authors),
                "venue": clean_text(source.get("display_name")),
                "doi": normalize_doi(clean_text(work.get("doi"))),
                "openalex_id": clean_text(work.get("id")),
                "cited_by_count": clean_text(work.get("cited_by_count")),
                "is_retracted": str(bool(work.get("is_retracted"))).lower(),
                "primary_url": clean_text(location.get("landing_page_url") or location.get("pdf_url")),
                "abstract": inverted_abstract(work.get("abstract_inverted_index")),
            }
        )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(candidates)
    print(f"Wrote {len(candidates)} OpenAlex candidates to {output}")
    return 0


def crossref_authors(items: list[dict]) -> str:
    names = []
    for author in items or []:
        family = clean_text(author.get("family"))
        given = clean_text(author.get("given"))
        literal = clean_text(author.get("name"))
        if family:
            names.append(f"{family}, {given}".rstrip(", "))
        elif literal:
            names.append(literal)
    return "; ".join(names)


def crossref_year(message: dict) -> str:
    for key in ("published-print", "published-online", "issued", "created"):
        parts = ((message.get(key) or {}).get("date-parts") or [[]])[0]
        if parts:
            return str(parts[0])
    return ""


def crossref_metadata(doi: str, mailto: str) -> dict[str, str]:
    url = "https://api.crossref.org/works/" + urllib.parse.quote(doi, safe="")
    message = http_json(url, mailto).get("message", {})
    return {
        "doi_or_url": doi,
        "title": clean_text(message.get("title")),
        "authors": crossref_authors(message.get("author") or []),
        "year": crossref_year(message),
        "venue": clean_text(message.get("container-title")),
        "volume": clean_text(message.get("volume")),
        "issue": clean_text(message.get("issue")),
        "pages": clean_text(message.get("page") or message.get("article-number")),
        "publisher": clean_text(message.get("publisher")),
    }


def comparable(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", html.unescape(value.casefold()))
    ascii_text = "".join(char for char in normalized if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "", ascii_text)


def cmd_verify(args: argparse.Namespace) -> int:
    audit = Path(args.audit)
    rows, headers = read_rows(audit)
    missing = [field for field in FIELDS if field not in headers]
    if missing:
        print(f"Missing audit columns: {', '.join(missing)}", file=sys.stderr)
        return 2

    cache: dict[str, dict[str, str]] = {}
    report = {"audit": str(audit), "verified_at": dt.datetime.now(dt.timezone.utc).isoformat(), "items": []}
    for row_number, row in enumerate(rows, start=2):
        doi = normalize_doi(row.get("doi_or_url", ""))
        if not doi:
            continue
        item = {"row": row_number, "source_key": row.get("source_key", ""), "doi": doi, "status": "ok", "warnings": []}
        try:
            if doi not in cache:
                cache[doi] = crossref_metadata(doi, args.mailto)
            metadata = cache[doi]
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            item["status"] = "error"
            item["error"] = str(exc)
            report["items"].append(item)
            continue
        for field, api_value in metadata.items():
            current = row.get(field, "")
            if not current and api_value:
                row[field] = api_value
            elif current and api_value and field != "doi_or_url" and comparable(current) != comparable(api_value):
                item["warnings"].append({"field": field, "ledger": current, "crossref": api_value})
        row["metadata_source"] = "Crossref"
        if not row.get("verified_on"):
            row["verified_on"] = dt.date.today().isoformat()
        report["items"].append(item)

    output = Path(args.output)
    write_rows(output, rows)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    errors = sum(item["status"] == "error" for item in report["items"])
    warnings = sum(len(item.get("warnings", [])) for item in report["items"])
    print(f"Checked {len(report['items'])} DOI rows: {errors} request errors, {warnings} metadata differences")
    print("Metadata lookup did not change substantive verification statuses.")
    return 3 if errors else 0


def row_label(index: int, row: dict[str, str]) -> str:
    return f"row {index} ({row.get('claim_id') or 'no claim ID'})"


def validation_messages(rows: list[dict[str, str]], headers: list[str]) -> tuple[list[str], list[str]]:
    errors = []
    warnings = []
    missing = [field for field in FIELDS if field not in headers]
    if missing:
        errors.append(f"Missing columns: {', '.join(missing)}")
        return errors, warnings

    key_metadata: dict[str, dict[str, str]] = {}
    doi_keys: dict[str, str] = {}
    bibliographic = ["doi_or_url", "title", "authors", "year", "venue", "volume", "issue", "pages", "publisher"]
    for index, row in enumerate(rows, start=2):
        label = row_label(index, row)
        for field in ("claim_id", "claim_type", "claim_text", "section", "source_type", "evidence_note", "limitation_note", "verification_status"):
            if not row.get(field):
                errors.append(f"{label}: missing {field}")
        if row.get("claim_type") and row["claim_type"] not in CLAIM_TYPES:
            errors.append(f"{label}: invalid claim_type {row['claim_type']!r}")
        if row.get("source_type") and row["source_type"] not in SOURCE_TYPES:
            errors.append(f"{label}: invalid source_type {row['source_type']!r}")
        status = row.get("verification_status", "")
        if status and status not in STATUSES:
            errors.append(f"{label}: invalid verification_status {status!r}")
        key = row.get("source_key", "")
        if key and not KEY_RE.match(key):
            errors.append(f"{label}: invalid BibTeX source_key {key!r}")
        if status in VERIFIED_STATUSES:
            for field in ("source_key", "doi_or_url", "title", "authors", "year", "venue", "evidence_note", "limitation_note", "verified_on"):
                if not row.get(field):
                    errors.append(f"{label}: {status} row missing {field}")
        if row.get("year") and not re.match(r"^\d{4}[a-z]?$", row["year"]):
            errors.append(f"{label}: invalid year {row['year']!r}")
        if row.get("verified_on"):
            try:
                dt.date.fromisoformat(row["verified_on"])
            except ValueError:
                errors.append(f"{label}: verified_on must be YYYY-MM-DD")
        if status == "decision_without_citation":
            if row.get("source_type") != "none":
                errors.append(f"{label}: uncited decision must use source_type=none")
            if key or row.get("doi_or_url"):
                errors.append(f"{label}: uncited decision must not have a source key or DOI/URL")
        if status != "decision_without_citation" and row.get("source_type") == "none":
            warnings.append(f"{label}: source_type=none outside an uncited design decision")

        doi = normalize_doi(row.get("doi_or_url", ""))
        if doi and key:
            previous = doi_keys.get(doi)
            if previous and previous != key:
                errors.append(f"{label}: DOI {doi} is also assigned to source key {previous}")
            doi_keys[doi] = key
        if key:
            current = {field: row.get(field, "") for field in bibliographic}
            if key in key_metadata:
                for field in bibliographic:
                    old = key_metadata[key][field]
                    new = current[field]
                    if old and new and comparable(old) != comparable(new):
                        errors.append(f"{label}: source key {key} has conflicting {field}")
                    elif not old and new:
                        key_metadata[key][field] = new
            else:
                key_metadata[key] = current
    return errors, warnings


def cmd_validate(args: argparse.Namespace) -> int:
    rows, headers = read_rows(Path(args.audit))
    errors, warnings = validation_messages(rows, headers)
    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    print(f"Validated {len(rows)} rows: {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


def latex_escape(value: str) -> str:
    replacements = {
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    return "".join(replacements.get(char, char) for char in value)


def bib_authors(value: str) -> str:
    return " and ".join(latex_escape(name.strip()) for name in value.split(";") if name.strip())


def bib_entry(row: dict[str, str]) -> str:
    source_type = row["source_type"]
    entry_type = {
        "article": "article",
        "book": "book",
        "chapter": "incollection",
        "working_paper": "techreport",
        "institutional": "techreport",
        "thesis": "mastersthesis",
    }.get(source_type, "misc")
    fields = []

    def add(name: str, value: str) -> None:
        if value:
            fields.append(f"  {name} = {{{value}}}")

    add("author", bib_authors(row.get("authors", "")))
    add("title", "{" + latex_escape(row.get("title", "")) + "}" if row.get("title") else "")
    if entry_type == "article":
        add("journal", latex_escape(row.get("venue", "")))
    elif entry_type == "incollection":
        add("booktitle", latex_escape(row.get("venue", "")))
    else:
        add("institution", latex_escape(row.get("venue", "")))
    add("year", row.get("year", ""))
    add("volume", latex_escape(row.get("volume", "")))
    add("number", latex_escape(row.get("issue", "")))
    add("pages", latex_escape(row.get("pages", "")).replace("-", "--"))
    add("publisher", latex_escape(row.get("publisher", "")))
    doi = normalize_doi(row.get("doi_or_url", ""))
    if doi:
        add("doi", latex_escape(doi))
        add("url", latex_escape("https://doi.org/" + doi))
    elif row.get("doi_or_url"):
        add("url", latex_escape(row["doi_or_url"]))
    joined = ",\n".join(fields)
    return f"@{entry_type}{{{row['source_key']},\n{joined}\n}}"


def cmd_export_bib(args: argparse.Namespace) -> int:
    rows, headers = read_rows(Path(args.audit))
    errors, warnings = validation_messages(rows, headers)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print("BibTeX export stopped because the ledger is invalid.", file=sys.stderr)
        return 1
    for warning in warnings:
        print(f"WARNING: {warning}")

    selected: dict[str, dict[str, str]] = {}
    for row in rows:
        if row.get("verification_status") not in VERIFIED_STATUSES:
            continue
        key = row["source_key"]
        if key not in selected:
            selected[key] = row.copy()
        else:
            for field in FIELDS:
                if not selected[key].get(field) and row.get(field):
                    selected[key][field] = row[field]
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    preamble = "% Generated from the verified claim-to-source audit. Review before publication.\n\n"
    body = "\n\n".join(bib_entry(selected[key]) for key in sorted(selected, key=str.casefold))
    output.write_text(preamble + body + ("\n" if body else ""), encoding="utf-8")
    print(f"Exported {len(selected)} verified sources to {output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="initialize an empty evidence ledger")
    init_parser.add_argument("--output", required=True)
    init_parser.add_argument("--force", action="store_true")
    init_parser.set_defaults(func=cmd_init)

    scan_parser = subparsers.add_parser("scan", help="scan a text manuscript for explicit citation markers")
    scan_parser.add_argument("--input", required=True)
    scan_parser.add_argument("--output", required=True)
    scan_parser.set_defaults(func=cmd_scan)

    discover_parser = subparsers.add_parser("discover", help="discover candidate works through OpenAlex")
    discover_parser.add_argument("--query", required=True)
    discover_parser.add_argument("--output", required=True)
    discover_parser.add_argument("--limit", type=int, default=25)
    discover_parser.add_argument("--api-key", default="")
    discover_parser.add_argument("--mailto", default=os.environ.get("REFERENCE_AUDIT_MAILTO", ""))
    discover_parser.set_defaults(func=cmd_discover)

    verify_parser = subparsers.add_parser("verify", help="verify DOI metadata through Crossref")
    verify_parser.add_argument("--audit", required=True)
    verify_parser.add_argument("--output", required=True)
    verify_parser.add_argument("--report", required=True)
    verify_parser.add_argument("--mailto", default=os.environ.get("REFERENCE_AUDIT_MAILTO", ""))
    verify_parser.set_defaults(func=cmd_verify)

    validate_parser = subparsers.add_parser("validate", help="validate the evidence ledger")
    validate_parser.add_argument("--audit", required=True)
    validate_parser.set_defaults(func=cmd_validate)

    export_parser = subparsers.add_parser("export-bib", help="export verified sources as BibTeX")
    export_parser.add_argument("--audit", required=True)
    export_parser.add_argument("--output", required=True)
    export_parser.set_defaults(func=cmd_export_bib)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
