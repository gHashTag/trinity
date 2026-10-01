# OWNERS -- specs/trinity/

**T-Queen** (the manifest and its work packages) with **A-Architect** (dispositions and profiles).
Consumer: `gHashTag/trinity` (S12 of gHashTag/trinity#988), which vendors these files byte-identical
and generates its manifest from them.

## Conventions

- One card per capability, `capabilities/<id>.t27`, module `trinity_capability_<id>` with `-` and
  `.` written as `_`, `ID = "trinity/<id>"`; the schema is in `README.md` and enforced by
  `tools/trinity_manifest.py check`, the compiler by `t27c typecheck` and the seals.
- Every card names a work package (S01..S12) and every package has at least one card; adding a
  capability is a reviewable card, changing scope is a reviewable diff of a card.
- A measured claim cites a public CI run or a command whose output is in a repository, with the
  revision. The catalog counts are a snapshot and never stand in for coverage.
- Re-inventory before changing counts: `tools/trinity_manifest.py inventory --trinity-root` on a
  clean clone at the new revision, then update `project.t27` (`PINNED_REVISION`, `PINNED_AT`, the
  counts) and re-seal.

## Pitfalls of the pinned compiler, recorded so the files avoid them

- A bare `;` line ahead of `module` is a statement, not a comment: the parser drops the module
  line. Header paragraphs are separated by blank lines.
- String literals carry no `"` inside; quotations in notes use single quotes.
- `[0]str = []` is accepted for an empty list; every array is annotated with its exact length.
