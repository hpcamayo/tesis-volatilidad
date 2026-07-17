#!/usr/bin/env python3
"""Inventory and verify a LaTeX ``thebibliography`` section."""

from __future__ import annotations

import argparse
import csv
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path


FIELDS = [
    "source_key",
    "citation_count",
    "citation_lines",
    "citation_sections",
    "citation_contexts",
    "doi_or_url",
    "metadata_provider",
    "metadata_status",
    "source_type",
    "title",
    "authors",
    "year",
    "venue",
    "volume",
    "issue",
    "pages",
    "publisher",
    "is_referenced_by_count",
    "metadata_notes",
    "review_status",
    "recommended_action",
    "raw_entry",
]

CITE_RE = re.compile(r"\\cite\{([^}]+)\}")
BIB_RE = re.compile(
    r"\\bibitem\{(?P<key>[^}]+)\}\s*(?P<entry>.*?)(?=\n\s*\\bibitem\{|\n\s*\\end\{thebibliography\})",
    re.S,
)
HEADING_RE = re.compile(r"\\(?:chapter|section|subsection|subsubsection)\*?\{([^}]+)\}")
URL_RE = re.compile(r"\\url\{([^}]+)\}")
HREF_RE = re.compile(r"\\href\{([^}]+)\}\{[^}]*\}")
DOI_RE = re.compile(r"10\.\d{4,9}/[^\s}]+", re.I)


def clean_space(value: str) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", html.unescape(str(value))).strip()


def plain_tex(value: str) -> str:
    value = re.sub(r"\\(?:emph|textit|textbf|url)\{([^}]*)\}", r"\1", value)
    value = value.replace(r"\&", "&").replace("--", "-")
    value = re.sub(r"\\[A-Za-z]+", "", value)
    return clean_space(value)


def comparable(value: str) -> str:
    value = plain_tex(value).casefold()
    value = unicodedata.normalize("NFKD", value)
    value = "".join(char for char in value if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "", value)


def normalize_doi(value: str) -> str:
    value = clean_space(value)
    value = re.sub(r"^https?://(?:dx\.)?doi\.org/", "", value, flags=re.I)
    match = DOI_RE.search(value)
    return match.group(0).rstrip(".,").lower() if match else ""


def parse_manuscript(path: Path) -> tuple[list[dict], dict[str, list[dict]], list[str]]:
    text = path.read_text(encoding="utf-8")
    body = text.split(r"\begin{thebibliography}", 1)[0]
    citations: dict[str, list[dict]] = defaultdict(list)
    current_section = "Front matter"
    for line_number, line in enumerate(body.splitlines(), start=1):
        headings = HEADING_RE.findall(line)
        if headings:
            current_section = plain_tex(headings[-1])
        for match in CITE_RE.finditer(line):
            for key in (item.strip() for item in match.group(1).split(",")):
                citations[key].append(
                    {
                        "line": line_number,
                        "section": current_section,
                        "context": plain_tex(line)[:800],
                    }
                )

    entries = []
    for match in BIB_RE.finditer(text):
        entry = clean_space(match.group("entry"))
        url_match = URL_RE.search(entry) or HREF_RE.search(entry)
        url = url_match.group(1) if url_match else ""
        doi = normalize_doi(url or entry)
        entries.append({"source_key": match.group("key"), "raw_entry": entry, "doi_or_url": doi or url})
    return entries, citations, list(citations)


def request_json(url: str, mailto: str = "") -> dict:
    agent = "ThesisBibliographyAudit/1.0"
    if mailto:
        agent += f" (mailto:{mailto})"
    request = urllib.request.Request(url, headers={"User-Agent": agent, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def crossref_authors(authors: list[dict]) -> str:
    names = []
    for author in authors or []:
        family = clean_space(author.get("family", ""))
        given = clean_space(author.get("given", ""))
        literal = clean_space(author.get("name", ""))
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


def crossref_metadata(doi: str, mailto: str) -> dict:
    url = "https://api.crossref.org/works/" + urllib.parse.quote(doi, safe="")
    message = request_json(url, mailto).get("message", {})
    return {
        "metadata_provider": "Crossref",
        "metadata_status": "verified",
        "source_type": clean_space(message.get("type", "")),
        "title": clean_space(message.get("title", "") if isinstance(message.get("title"), str) else (message.get("title") or [""])[0]),
        "authors": crossref_authors(message.get("author") or []),
        "year": crossref_year(message),
        "venue": clean_space((message.get("container-title") or [""])[0]),
        "volume": clean_space(message.get("volume", "")),
        "issue": clean_space(message.get("issue", "")),
        "pages": clean_space(message.get("page", "") or message.get("article-number", "")),
        "publisher": clean_space(message.get("publisher", "")),
        "is_referenced_by_count": str(message.get("is-referenced-by-count", "")),
    }


def datacite_authors(creators: list[dict]) -> str:
    names = []
    for creator in creators or []:
        family = clean_space(creator.get("familyName", ""))
        given = clean_space(creator.get("givenName", ""))
        name = clean_space(creator.get("name", ""))
        names.append(f"{family}, {given}".rstrip(", ") if family else name)
    return "; ".join(name for name in names if name)


def datacite_metadata(doi: str, mailto: str) -> dict:
    url = "https://api.datacite.org/dois/" + urllib.parse.quote(doi, safe="")
    attributes = request_json(url, mailto).get("data", {}).get("attributes", {})
    titles = attributes.get("titles") or []
    container = attributes.get("container") or {}
    return {
        "metadata_provider": "DataCite",
        "metadata_status": "verified",
        "source_type": clean_space((attributes.get("types") or {}).get("resourceTypeGeneral", "")),
        "title": clean_space(titles[0].get("title", "") if titles else ""),
        "authors": datacite_authors(attributes.get("creators") or []),
        "year": clean_space(attributes.get("publicationYear", "")),
        "venue": clean_space(container.get("title", "") or attributes.get("publisher", "")),
        "volume": clean_space(container.get("volume", "")),
        "issue": clean_space(container.get("issue", "")),
        "pages": clean_space(container.get("firstPage", "")),
        "publisher": clean_space(attributes.get("publisher", "")),
        "is_referenced_by_count": "",
    }


def fetch_metadata(doi: str, mailto: str) -> dict:
    errors = []
    for provider in (crossref_metadata, datacite_metadata):
        try:
            return provider(doi, mailto)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            errors.append(f"{provider.__name__}: {exc}")
    return {
        "metadata_provider": "",
        "metadata_status": "lookup_failed",
        "metadata_notes": " | ".join(errors),
    }


def metadata_differences(raw_entry: str, metadata: dict) -> list[str]:
    notes = []
    raw_norm = comparable(raw_entry)
    for field in ("title", "year", "volume", "issue"):
        value = metadata.get(field, "")
        if value and comparable(value) not in raw_norm:
            notes.append(f"{field} differs or is absent: {value}")
    pages = metadata.get("pages", "")
    if pages:
        page_norm = comparable(pages.replace("–", "-").replace("—", "-"))
        if page_norm not in raw_norm:
            notes.append(f"pages differ or are absent: {pages}")
    return notes


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in FIELDS})


def write_summary(path: Path, manuscript: Path, rows: list[dict], undefined: list[str]) -> None:
    cited = [row for row in rows if int(row["citation_count"]) > 0]
    uncited = [row for row in rows if int(row["citation_count"]) == 0]
    verified = [row for row in rows if row["metadata_status"] == "verified"]
    manual = [row for row in rows if row["metadata_status"] == "manual_review"]
    issues = [row for row in rows if row["recommended_action"] != "retain"]
    uncited_keys = ", ".join(f"`{row['source_key']}`" for row in uncited) or "none"
    undefined_keys = ", ".join(f"`{key}`" for key in undefined) or "none"
    lines = [
        "# Full Bibliography Audit",
        "",
        f"- Manuscript: `{manuscript}`",
        f"- Bibliography entries: {len(rows)}",
        f"- Cited entries: {len(cited)}",
        f"- Uncited entries: {len(uncited)}",
        f"- Undefined citation keys: {len(undefined)}",
        f"- DOI metadata verified: {len(verified)}",
        f"- Sources requiring manual metadata review: {len(manual)}",
        "",
        "## Structural Findings",
        "",
        f"- Uncited keys: {uncited_keys}",
        f"- Undefined keys: {undefined_keys}",
        "",
        "## Items Requiring Action",
        "",
        "| Key | Citations | Metadata | Recommended action | Notes |",
        "|---|---:|---|---|---|",
    ]
    for row in issues:
        notes = (row.get("metadata_notes") or "").replace("|", "/")
        lines.append(
            f"| `{row['source_key']}` | {row['citation_count']} | {row['metadata_status']} | "
            f"{row['recommended_action']} | {notes} |"
        )
    if not issues:
        lines.append("| None | | | | |")
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "Metadata verification confirms bibliographic identity; it does not establish that a source supports every nearby claim. "
            "Claim fit and evidentiary limits require substantive reading and are documented separately in the writing roadmap.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tex", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--cache", required=True)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--mailto", default=os.environ.get("REFERENCE_AUDIT_MAILTO", ""))
    args = parser.parse_args()

    manuscript = Path(args.tex)
    entries, citations, cited_keys = parse_manuscript(manuscript)
    bibliography_keys = [entry["source_key"] for entry in entries]
    undefined = sorted(set(cited_keys) - set(bibliography_keys))
    duplicates = [key for key, count in Counter(bibliography_keys).items() if count > 1]
    if duplicates:
        print(f"Duplicate bibliography keys: {', '.join(duplicates)}", file=sys.stderr)
        return 2

    cache_path = Path(args.cache)
    cache = json.loads(cache_path.read_text(encoding="utf-8")) if cache_path.exists() else {}
    rows = []
    for entry in entries:
        key = entry["source_key"]
        contexts = citations.get(key, [])
        doi = normalize_doi(entry["doi_or_url"])
        row = {
            **entry,
            "citation_count": str(len(contexts)),
            "citation_lines": "; ".join(str(item["line"]) for item in contexts),
            "citation_sections": " | ".join(dict.fromkeys(item["section"] for item in contexts)),
            "citation_contexts": " || ".join(dict.fromkeys(item["context"] for item in contexts)),
            "metadata_status": "manual_review",
            "review_status": "pending_substantive_review",
            "recommended_action": "retain" if contexts else "remove_uncited",
        }
        if doi and args.verify:
            if doi not in cache:
                cache[doi] = fetch_metadata(doi, args.mailto)
                time.sleep(0.05)
            row.update(cache[doi])
            notes = metadata_differences(entry["raw_entry"], row)
            prior = row.get("metadata_notes", "")
            row["metadata_notes"] = " | ".join(filter(None, [prior, *notes]))
            if row["metadata_status"] != "verified":
                row["recommended_action"] = "manual_metadata_check"
            elif notes and contexts:
                row["recommended_action"] = "inspect_metadata_difference"
        elif doi:
            row["metadata_status"] = "not_checked"
        if not contexts:
            row["recommended_action"] = "remove_uncited"
        rows.append(row)

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(cache, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_csv(Path(args.output), rows)
    write_summary(Path(args.summary), manuscript, rows, undefined)
    print(
        f"Audited {len(rows)} bibliography entries: {sum(bool(citations.get(row['source_key'])) for row in rows)} cited, "
        f"{sum(not citations.get(row['source_key']) for row in rows)} uncited, {len(undefined)} undefined."
    )
    return 1 if undefined else 0


if __name__ == "__main__":
    raise SystemExit(main())
