# specs/skills — skills as first-class `.t27` specs

One file per Claude Code skill the site publishes (`apps/website/public/skills/manifest.json`).
The `.t27` file is the source of truth for the skill card on t27.ai; the JSON the site
serves (`public/skills/spec-skills.json`) is generated from these files by the real
compiler (`t27_compiler.wasm`), never by a regex.

File name: `<repo>-<skill-dir>.t27`; module name: `skill_<file name with underscores>`.

## Schema (every constant is `pub const`)

| constant      | type      | meaning                                                                 |
|---------------|-----------|-------------------------------------------------------------------------|
| `KIND`        | `str`     | always `"skill"`                                                        |
| `ID`          | `str`     | `<repo>/<dir>`; must equal the id in the code manifest                  |
| `NAME`        | `str`     | display name (frontmatter `name`, else the directory)                   |
| `REPO`        | `str`     | short repo name (`t27`, `trinity`, …)                                   |
| `SOURCE`      | `str`     | the skill file inside its directory (`SKILL.md` / `skill.md`)           |
| `SUMMARY_EN`  | `str`     | one-paragraph summary, English                                          |
| `SUMMARY_RU`  | `str`     | the same, Russian                                                       |
| `COMMAND`     | `str`     | how it is invoked (`/name argument-hint`); `""` when nothing is declared |
| `SPECS`       | `[N]str`  | `.t27` paths the skill stands on; `[0]str = []` when none is declared    |
| `TAGS`        | `[N]str`  | short topical tags                                                      |
| `ENABLED`     | `bool`    | whether the skill is offered                                            |
| `TIMEOUT_MIN` | `u16`     | budget in minutes (30 = default, nothing declared in SKILL.md)           |

## Witness labels the site derives

- `spec+code` — a spec here **and** the skill exists in the code manifest.
- `spec-only` — a spec here with no matching skill in code (warn).
- `code-only` — a skill in code with no spec here (listed, not invented).

A cron spec (`../crons/`) names the skills it launches in its `RUNS`; the site
shows that link in both directions (`runBy` on the skill card).

Validity: every file must pass `typecheck.ok === true` with empty
`discarded` / `lexerDiscarded` / `swallowed` under the vendored wasm compiler —
the site's `scripts/agents-from-specs.mjs` fails the build otherwise.
