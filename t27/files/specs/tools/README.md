# specs/tools — the `tri` CLI and the MCP servers as first-class `.t27` specs

> **Where this lives.** The `tri/` and `mcp/` directories in `gHashTag/t27` are the canonical
> home of these specs — edit them here. `gHashTag/trinity` keeps a vendored copy under
> `apps/website/public/t27/files/specs/tools/` and its build reads that copy through the
> vendored compiler wasm (`t27_compiler.wasm`). The wasm's `typecheck.ok` is necessary, not
> sufficient, so the site's generator (`scripts/agents-from-specs.mjs`) also checks the field
> schema below. The bootstrap compiler on `master` was not run against these files in the
> commit that added them.


Layer 5 of the ladder. One file per `tri` command (`tri/<command>.t27`) and one per MCP
server (`mcp/<server>.t27`), so that every agent can find the tools the repositories actually
ship: what a command is for, which nested actions it has, which agent letter a source binds it
to, and where its code is. The JSON the site serves (`public/tools/spec-tools.json`) is
generated from these files by the real compiler (`t27_compiler.wasm`), never by a regex over
the `.t27`.

The three files at the top of this directory (`registry.t27`, `schema.t27`,
`tri_to_t27_converter.t27`) predate the catalog and are ordinary corpus specs; they are not
tool cards and the generator does not read them.

## The ladder

```
Specs  ->  Skills  ->  Crons  ->  Agents  ->  Tools
specs/**   specs/skills specs/crons specs/agents specs/tools/{tri,mcp}
what is    what a run   what starts  who holds the  what the agents can call:
declared   does         a run and    skills, under  the tri CLI commands and
                        when         which law      the MCP servers, each with
                                                    its source and its owner(s)
```

Links go downward through declared fields only: a tool names the agent letters that own it
(`AGENTS`), an agent names the tools it holds (`TOOLS`), and the generator checks the two
directions agree and that every letter and every tool ID exists.

## Extraction and witness rule

Nothing in these files is typed by hand. Each file records where its text came from:

* **`tri/`** — read from the clap `#[derive(Subcommand)] enum Commands` in `cli/tri/src/main.rs`
  and the action enums in `cli/tri/src/*.rs` at the commit named in the file header. The
  witness label is `source-parse`: `cargo` was not available where the catalog was produced,
  so `tri --help` was **not** executed; the enum, its `///` doc comments and the nested enums
  were read from the source and rendered the way clap derives them (kebab-case names, first
  doc paragraph as `ABOUT`). Running `cargo run -q -p tri -- <command> --help` and diffing
  against `ABOUT` / `ACTIONS` is the next witness tier and has not been done.
* 15 of the 52 variants carry no `///` doc (`status`, `skill`, `cell`, `gen`, `test`,
  `verdict`, `experience`, `doctor`, `health`, `serve`, `fleet`, `red`, `mods`, `types`,
  `unparsed`). For those `ABOUT` quotes, in this order of preference, the `//!` module doc of
  the command's source file, the description of the mirroring tool in `cli/tri-mcp/src/main.rs`,
  or the handler's own strings in `main.rs` (routes, state-file paths, match arms).
  `ABOUT_SOURCE` names the exact source and line for every file.
* Some `///` docs in `main.rs` sit above a different variant than their text describes
  (e.g. the text about attached hardware sits above `Ci`, the text about unreachable source
  files above `Harness`, the text about duplicate type names above `Fmt`). The specs reproduce
  what clap would print for that variant; the misplacement is a defect of the source, reported
  here, not repaired silently.
* **`mcp/`** — tool names, descriptions and `inputSchema` property keys are read from the
  server code or manifest named in `SOURCE`: `scripts/mcp-traceability-server.js` (JS object
  literals), `cli/tri-mcp/src/main.rs` (`serde_json::json!` literals),
  `.claude/mcp/tri-ssot/manifest.json`, and in `gHashTag/trinity`
  `tools/mcp/trinity_mcp/server.zig` and `tools/mcp/needle_mcp/server.zig` (Zig string
  literals). The trinity server's static list has 210 entries, 32 of which have an unbalanced
  trailing brace in the source literal; they were parsed after adding or removing one, and the
  count is recorded in `TOOLS_NOTE`. Cell-generated tools appended at runtime from
  `data/cells/mcp_tools.json` are not listed (the file is not in the repository).
  `.trinity/mcp_schemas.json` (29 names) and `.claude/rules/mcp-servers.md` ("47+ tools") are
  other declarations of the same server and disagree with the code; the code is the source.
* Servers that are external packages (`gitbutler`, `notebooklm`, `zig-docs`,
  `railway-mcp-server`, `neon`) have `EXTERNAL = true`, `TOOLS = []` and a `TOOLS_NOTE` saying
  the list lives outside the repository. Nothing is listed rather than guessed.
* `tri-mcp` is a crate in `cli/tri-mcp` and is **not** registered in `.mcp.json` at this
  commit (`CONFIG = ""`). `tri-ssot`'s manifest names `python3 -m contrib.backend.github.mcp_server`,
  which the tree does not contain; its tools are declared, not executed.
* `gHashTag/trinity` has no `tri` binary of its own at the pinned commit (`build.zig` defines
  no `tri` executable; `.claude/skills/tri/SKILL.md` is a skill and is already in the skills
  catalog). Its MCP servers are recorded under `mcp/` with `REPO = "gHashTag/trinity"`; the
  two repositories' tools are never merged into one list.
* No absolute developer home path appears in any file. Where a config file names one
  (`.claude-plugin/.mcp.json`, needle), the home prefix is written as `<checkout>`.

## Agent bindings

`AGENTS` on a tool and `TOOLS` on an agent (`specs/agents/<letter>.t27`) are filled only where
a source line names the command for that letter; the note field cites the line. At this commit:

| tool | agents | source |
|---|---|---|
| `tri/gen` | C, T | `.claude/agents/agent-c-compiler.md:40`, `.claude/agents/trinity.md:68` |
| `tri/test` | T, V | `.claude/agents/agent-v-verify.md:47`, `.claude/agents/trinity.md:70` |
| `tri/verdict` | V | `.claude/agents/agent-v-verify.md:49`, `docs/agents/AGENTS_ALPHABET.md:80` |
| `tri/experience` | E | `.claude/agents/agent-e-experience.md:64` |
| `tri/cell` | W | `docs/agents/AGENTS_ALPHABET.md:144` (domain "Workflow / tri cell") |

Everything else is `[]` with a note. `tri seal`, `tri verify`, `tri experience query`,
`tri notebook` and `tri bench` are named in agent files but are not commands of the CLI at
this commit; they are quoted in the notes and bound to nothing. `creator.md` and `verifier.md`
name `tri gen`/`tri test` but are not letter agents. The alphabet's key files point at
`src/tri/*.zig`, which neither repository contains at the pinned commits.

## Schema — `tri/<command>.t27` (module `tool_tri_<command>`, `-` → `_`)

| constant | type | meaning |
|---|---|---|
| `KIND` | `str` | `"tool"` |
| `FAMILY` | `str` | `"tri-cli"` |
| `ID` | `str` | `tri/<command>` |
| `COMMAND` | `str` | `tri <command>` |
| `VARIANT` | `str` | the clap enum variant, `Commands::<Name>` |
| `SOURCE` | `str` | the `.rs` file the command dispatches to |
| `ENTRY` | `str` | `cli/tri/src/main.rs` |
| `ABOUT` | `str` | the clap about text, or the fallback named in `ABOUT_SOURCE` |
| `ABOUT_SOURCE` | `str` | where `ABOUT` was read from (file and line) |
| `ACTIONS` | `[N]str` | nested subcommands, kebab-case |
| `ACTIONS_ABOUT` | `[N]str` | first doc paragraph per action, `""` when none (same N) |
| `ARGS` | `[N]str` | top-level arguments/flags, `"<name>: doc"` |
| `AGENTS` | `[N]str` | owning letters, only where a source names the command |
| `AGENTS_NOTE` | `str` | the source line, or why the list is empty |
| `WHEN_TO_USE` | `str` | the long about when the doc has more than one paragraph, else `ABOUT` |
| `WITNESS` | `str` | `"source-parse"` |
| `ENABLED` | `bool` | |

## Schema — `mcp/<server>.t27` (module `tool_mcp_<server>`, `-` → `_`)

| constant | type | meaning |
|---|---|---|
| `KIND` | `str` | `"tool"` |
| `FAMILY` | `str` | `"mcp"` |
| `ID` | `str` | `mcp/<server>` |
| `SERVER` | `str` | server name as registered |
| `SERVER_VERSION` | `str` | from the code/manifest, `""` when none |
| `TRANSPORT` | `str` | `stdio` |
| `LAUNCH` | `str` | command and args as the config states them |
| `ENV` | `[N]str` | environment variable names the config sets |
| `CONFIG` | `str` | the `.mcp.json` (or manifest) that registers it, `""` when none |
| `REPO` | `str` | `gHashTag/t27` or `gHashTag/trinity` |
| `SOURCE` | `str` | the file the tool list was read from |
| `ABOUT`, `ABOUT_SOURCE` | `str` | |
| `TOOLS` | `[N]str` | tool names as `tools/list` returns them |
| `TOOLS_ABOUT` | `[N]str` | descriptions (same N) |
| `TOOLS_INPUTS` | `[N]str` | comma-joined `inputSchema.properties` keys (same N) |
| `RESOURCES`, `RESOURCES_ABOUT` | `[N]str` | resources and their descriptions |
| `TOOLS_NOTE` | `str` | why `TOOLS` is empty or differs from other declarations |
| `EXTERNAL` | `bool` | third-party package or outside binary |
| `AGENTS`, `AGENTS_NOTE` | | as for `tri/` |
| `WITNESS` | `str` | `"source-parse"` |
| `ENABLED` | `bool` | |

Specs are English-only and ASCII-only (t27 LANG-EN / L3 PURITY); Greek letters and dashes in
the source texts are transliterated (`phi`, `--`). Russian summaries live in the bundle
declared by `specs/i18n/agents-ru.t27`, whose `SCOPE` includes `specs/tools`.

## Editing

Edit in `gHashTag/t27` (`specs/tools/tri/*.t27`, `specs/tools/mcp/*.t27`), re-vendor the
byte-identical copy into `gHashTag/trinity` `apps/website/public/t27/files/specs/tools/`, then
run `node scripts/agents-from-specs.mjs` and `npm run check:tools` in `apps/website`. To
refresh from the code, re-run the extraction against the current commit rather than editing
`ABOUT` by hand.
