# specs/docs — the system documentation as a declared document

> **Where this lives.** `specs/docs/` and the Markdown bodies under `docs/system/` in
> `gHashTag/t27` are the canonical home of the system documentation — edit them here.
> `gHashTag/trinity` keeps a byte-identical vendored copy under
> `apps/website/public/t27/files/specs/docs/` and `apps/website/public/t27/files/docs/system/`;
> its build reads that copy through the vendored compiler wasm (`t27_compiler.wasm`) and
> renders it at `t27.ai/#/docs`. The wasm's `typecheck.ok` is necessary, not sufficient, so
> the site's generator (`scripts/docs-from-specs.mjs`) also checks the field schema below.
> The bootstrap compiler on `master` was not run against these files in the commit that
> added them. A checkout of this repository is referred to as `T27_ROOT` (an environment
> variable) or `git rev-parse --show-toplevel`; no file here names an absolute path.

The documentation describes the project, the rules of the game for agents, the five-layer
system (Specs -> Skills -> Crons -> Agents -> Tools), the 27-agent alphabet, the Queen's
cycle, the tooling and the evidence. One `.t27` module declares the document, one per
chapter declares the chapter; the English prose is Markdown in `docs/system/<id>.md`
(LANG-EN: canonical prose is English and lives outside the spec); the Russian prose travels
through the translation contract `specs/i18n/docs-ru.t27` and the bundle it names.

Nothing in `public/docs/system-docs.json` on the site is typed by hand: chapters, sections,
tables (laws, phases, agents, tools, ladder counts, witnesses) and the source list with
sha256 per file are generated from these specs and the catalogs they point to.

## Files

| File | Module | Role |
|---|---|---|
| `system.t27` | `docs_system` | The document: `KIND = "docs"`, `ID`, `TITLE`, `CHAPTERS` (ids in reading order), `SOURCES` (catalogs and canon documents), `DIAGRAMS` (figures the site draws from data), `LOCALES`, `ENABLED` |
| `chapters/<id>.t27` | `docs_chapter_<id>` | One chapter: `KIND = "docs-chapter"`, `ID = "docs/<id>"`, `DOCUMENT`, `ORDER`, `TITLE`, `SOURCES`, `SECTIONS`, `DIAGRAM`, `TABLE`, `BODY_EN`, `ENABLED` |
| `../i18n/docs-ru.t27` | `i18n_docs_ru` | Translation contract for Russian: scope, fields, bundle path in `gHashTag/trinity` |
| `../../docs/system/<id>.md` | — | English canonical prose of chapter `<id>`; every `SECTIONS` entry is a level-2 heading, in order |

## Chapters

| Order | ID | Title | Figure | Table |
|---|---|---|---|---|
| 1 | `docs/project` | The project | `ladder` | `claims` |
| 2 | `docs/rules` | Constitution and the rules of the game for agents | `law-hierarchy` | `laws` |
| 3 | `docs/layers` | The five-layer system | `skills-crons-agents` | `ladder-counts` |
| 4 | `docs/alphabet` | The 27-agent alphabet | `agent-ring` | `agents` |
| 5 | `docs/queen` | Queen orchestration | `phase-cycle` | `phases` |
| 6 | `docs/tooling` | Tooling | `tools-map` | `tools` |
| 7 | `docs/evidence` | Evidence and witnesses | — | `witnesses` |

## Schema

`system.t27`

| Constant | Type | Meaning |
|---|---|---|
| `KIND` | `str` | Always `"docs"` |
| `ID` | `str` | `"docs/system"` |
| `TITLE` | `str` | Document title, English |
| `CHAPTERS` | `[N]str` | Chapter ids in reading order; each must resolve to `chapters/<id>.t27` with `ENABLED = true` |
| `SOURCES` | `[N]str` | Catalog directories and canon files the chapters draw on; each must exist in the tree |
| `DIAGRAMS` | `[N]str` | Figure ids the site knows how to draw; a chapter's `DIAGRAM` must be one of them or empty |
| `LOCALES` | `[N]str` | `"en"` first; each other locale must have `specs/i18n/docs-<locale>.t27` |
| `ENABLED` | `bool` | Whether the site renders the document |

`chapters/<id>.t27`

| Constant | Type | Meaning |
|---|---|---|
| `KIND` | `str` | Always `"docs-chapter"` |
| `ID` | `str` | `"docs/<id>"`, `<id>` = file stem |
| `DOCUMENT` | `str` | `"docs/system"` |
| `ORDER` | `u8` | Position in the document; must match the index in `CHAPTERS` |
| `TITLE` | `str` | Chapter title, English |
| `SOURCES` | `[N]str` | Files the chapter quotes or is generated from; paths from the t27 root, or from the trinity root with the prefix `trinity:`; each must exist |
| `SECTIONS` | `[N]str` | Section headings in order; the body must carry each as `## <heading>` in the same order, and no other level-2 heading |
| `DIAGRAM` | `str` | One of `DIAGRAMS` or `""` |
| `TABLE` | `str` | One of `claims`, `laws`, `ladder-counts`, `agents`, `phases`, `tools`, `witnesses`, or `""`; the generator must be able to produce it non-empty |
| `BODY_EN` | `str` | `docs/system/<id>.md`; must exist and start with a level-1 heading |
| `ENABLED` | `bool` | Whether the chapter is rendered |

## Rules of the catalog

- English and ASCII only in the `.t27` and in `docs/system/*.md` (SOUL Article I, LANG-EN);
  translations live in bundles declared by `specs/i18n/docs-<locale>.t27`.
- No ranking words ("first", "only", "best" and their translations) in English or Russian
  prose; the site's `check:docs` fails a build that contains them.
- Every number in the prose carries a status tag (`[measured]`, `[declared]`, `[specified]`,
  `[external]`, `[not claimed]`) or is generated into a table with a source line.
- Quote canon files; do not paraphrase a rule into a stronger one. Where two canon files
  disagree, record the disagreement (the chapters do this for L1-L7 versus "L1-L8" and for
  the two statements of the Queen's loop).
- Change the spec or the body and regenerate; never edit `public/docs/system-docs.json`.
- Ownership: `Z-Zeta` (documentation), with `T-Queen` for the orchestration chapter
  (`specs/OWNERS.md`).
