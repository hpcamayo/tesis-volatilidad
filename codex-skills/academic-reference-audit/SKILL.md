---
name: academic-reference-audit
description: Systematically discover, verify, document, and export academic references for theses, papers, literature reviews, and technical reports. Use when Codex must find sources for unsupported claims, audit whether citations actually support nearby text, verify DOI and publisher metadata, build or update a claim-to-source evidence ledger, produce BibTeX, or distinguish literature-backed statements from the author's own design choices.
---

# Academic Reference Audit

Build a traceable chain from each claim to the evidence that supports it. Treat discovery, metadata verification, substantive reading, and citation management as separate steps.

## Non-Negotiable Rules

1. Start from the exact claim, not from a broad topic.
2. Prefer the version of record on a publisher, journal, DOI, or institutional site.
3. Use OpenAlex for discovery and citation chaining; use Crossref for metadata verification. Neither substitutes for reading the source.
4. Read at least the abstract, method or design description, and the passage relevant to the claim before marking a source `verified`.
5. Record both an `evidence_note` and a `limitation_note` for every verified source.
6. Never cite a source merely because it uses similar terminology.
7. Never invent authors, dates, pages, DOI values, quotations, or empirical findings.
8. Mark thesis-specific choices as `decision_without_citation` when no external authority is needed. Do not manufacture a citation to make a design choice look standard.
9. Preserve the distinction between evidence about another sample and evidence about the current sample.
10. Fail closed: leave a claim unresolved when the evidence is only adjacent or metadata cannot be verified.

## Locate the Working Files

At the beginning of a task, identify:

- the thesis or paper source (`.tex`, `.md`, `.docx`, or extracted PDF text);
- the existing bibliography (`.bib`, `thebibliography`, or reference section);
- the evidence ledger, normally `reference_audit.csv`;
- the writing log or roadmap;
- the installed skill directory and `scripts/reference_audit.py`.

Read [references/audit-schema.md](references/audit-schema.md) before creating or changing the ledger.

## Workflow

### 1. Inventory Claims

Search the manuscript and writing log for markers such as `REF-`, `TODO-CITE`, `CITATION-NEEDED`, uncited methodological assertions, causal language, and numerical claims sourced outside reproducible outputs.

Classify each claim as:

- `theoretical`;
- `methodological`;
- `empirical_external`;
- `institutional_context`;
- `design_choice`.

Use stable claim identifiers. Reuse an existing `REF-XX` rather than renumbering it.

To scan explicit markers:

```bash
python3 "$SKILL_DIR/scripts/reference_audit.py" scan \
  --input tesis_draft.tex \
  --output reference_claims.csv
```

### 2. Initialize the Ledger

If no ledger exists:

```bash
python3 "$SKILL_DIR/scripts/reference_audit.py" init \
  --output reference_audit.csv
```

Use one row per claim-source relationship. A source supporting two claims must have two rows unless the project deliberately uses a semicolon-separated claim ID convention.

### 3. Discover Candidates

Use several query families for each claim:

- the exact construct and method;
- the construct plus the empirical domain;
- a known seminal author or paper;
- backward references from a strong seed source;
- forward citations to the seed source;
- contradictory or boundary-condition terms.

When an OpenAlex API key is available:

```bash
python3 "$SKILL_DIR/scripts/reference_audit.py" discover \
  --query "FX implied volatility surface random walk benchmark" \
  --output reference_candidates.csv \
  --limit 25
```

Also search publisher and institutional sites directly. For technical questions, rely on primary documentation and original papers rather than tertiary summaries.

### 4. Screen Candidates

Reject or defer candidates when:

- only the title appears relevant;
- the source studies a materially different estimand and the distinction is ignored;
- a working paper has a published version that can be cited instead;
- the source is retracted, corrected in a way that affects the claim, or lacks verifiable provenance;
- the evidence is a search-result snippet without inspection of the underlying page;
- the claim is causal but the cited study is merely descriptive.

Use institutional sources such as BIS, IMF, central banks, standards bodies, and official documentation for market structure, definitions, and current institutional facts. Label them as institutional rather than peer-reviewed.

### 5. Verify Metadata

Normalize DOI values and query Crossref:

```bash
python3 "$SKILL_DIR/scripts/reference_audit.py" verify \
  --audit reference_audit.csv \
  --output reference_audit.csv \
  --report reference_verification_report.json
```

Crossref verification confirms metadata, not substantive support. Do not promote a row from `candidate` to `verified` until the source has been read.

For sources without Crossref DOI values, verify against the publisher, library catalog, or institution and record that origin in `metadata_source`.

### 6. Write the Evidence Dossier

For every incorporated source, write:

- full citation and DOI or primary URL;
- source type and relevance;
- central contribution;
- exact way it supports the manuscript;
- manuscript section where it is used;
- explicit evidentiary limit.

Place the citation next to the supported sentence. Avoid dropping one citation at the end of a paragraph containing several distinct claims.

### 7. Validate and Export

Run validation before editing the manuscript bibliography:

```bash
python3 "$SKILL_DIR/scripts/reference_audit.py" validate \
  --audit reference_audit.csv
```

Export only `verified` and `incorporated` rows:

```bash
python3 "$SKILL_DIR/scripts/reference_audit.py" export-bib \
  --audit reference_audit.csv \
  --output references.bib
```

The exporter deduplicates by citation key and DOI. Review the resulting BibTeX before wiring it into LaTeX.

### 8. Close the Loop

Update the roadmap with:

- resolved and unresolved claim IDs;
- accepted and rejected sources;
- decisions intentionally left uncited;
- remaining limitations;
- verification date.

Rebuild the manuscript and confirm there are no undefined citations. When the output is a PDF, render and inspect the bibliography and citation-heavy pages.

## Status Semantics

- `candidate`: discovered but not substantively verified.
- `verified`: metadata checked and relevant passages read.
- `incorporated`: verified and cited in the manuscript.
- `rejected`: inspected but unsuitable; explain why in `notes`.
- `decision_without_citation`: an explicit design or scope choice that should not be presented as a literature standard.

## Source Hierarchy

Use this default order, adjusting when the domain requires it:

1. Original peer-reviewed article or scholarly book.
2. Version of record on the publisher or DOI landing page.
3. Official institutional report or technical standard.
4. Accepted manuscript or reputable repository copy when the version of record is inaccessible.
5. Working paper when no published version exists.
6. Tertiary sources only for orientation, never as the final support for a technical claim.

## Quotation and Copyright

Prefer paraphrase. When an exact quotation is necessary, keep it short, record the page or section, and comply with source-specific quotation limits. Never reconstruct a quotation from a snippet.

## Deliverables

A completed audit should leave:

- an updated manuscript with citations placed at claim level;
- `reference_audit.csv` with evidence and limitation notes;
- `references.bib` or the project's native bibliography updated;
- an updated writing log with source dossiers;
- a short summary of unresolved evidence gaps and rejected overclaims.
