# Evidence Ledger Schema

Use UTF-8 CSV with one header row. Keep notes on one logical line; CSV quoting may contain commas.

## Fields

| Field | Required | Meaning |
|---|---:|---|
| `claim_id` | yes | Stable manuscript claim identifier, such as `REF-03` |
| `claim_type` | yes | `theoretical`, `methodological`, `empirical_external`, `institutional_context`, or `design_choice` |
| `claim_text` | yes | Exact claim or a faithful, independently understandable summary |
| `section` | yes | Manuscript chapter or subsection |
| `source_key` | conditional | Stable BibTeX key; required for verified or incorporated sources |
| `doi_or_url` | conditional | DOI or primary URL; required for verified or incorporated sources |
| `title` | conditional | Verified source title |
| `authors` | conditional | Semicolon-separated `Family, Given` author names |
| `year` | conditional | Four-digit publication year |
| `venue` | conditional | Journal, publisher, or institution |
| `volume` | no | Journal or series volume |
| `issue` | no | Journal issue or number |
| `pages` | no | Page range or article number |
| `publisher` | no | Publisher or issuing institution |
| `source_type` | yes | `article`, `book`, `chapter`, `working_paper`, `institutional`, `thesis`, or `none` |
| `evidence_note` | yes | Exact reason the source supports the claim, or why no citation is required |
| `limitation_note` | yes | What the source does not establish |
| `verification_status` | yes | `candidate`, `verified`, `incorporated`, `rejected`, or `decision_without_citation` |
| `metadata_source` | no | Crossref, publisher, institution, library catalog, or another primary metadata source |
| `verified_on` | conditional | ISO date `YYYY-MM-DD`; required for verified or incorporated rows |
| `notes` | no | Rejection reason, correction notice, quotation location, or follow-up action |

## Row Model

Prefer one row per claim-source relationship. Repeating a source key is valid when the same paper supports several claims. Every repeated source key must have identical bibliographic metadata.

Use a row with `source_type=none` and `verification_status=decision_without_citation` for a deliberate uncited design choice. Leave `source_key` and `doi_or_url` blank, explain the decision in `evidence_note`, and state the boundary in `limitation_note`.

## Validation Rules

- Never reuse a DOI under two citation keys.
- Never reuse a citation key for conflicting DOI, title, year, venue, volume, issue, pages, or publisher values.
- Require evidence and limitation notes before `verified` or `incorporated`.
- Treat Crossref metadata verification as separate from substantive verification.
- Do not change a row to `verified` solely because an API request succeeded.
- Use the primary institutional URL when a report has no DOI.
- Preserve rejected candidates when the rejection prevents the same weak source from being reconsidered later.

## Recommended Project Files

```text
project_root/
  reference_audit.csv
  reference_candidates.csv        # optional, usually temporary
  reference_verification_report.json
  references.bib
  writing_log.md
```

Version `reference_audit.csv`, `references.bib`, and the writing log. Candidate and API report files may be regenerated unless the project needs a formal systematic-review trail.
