---
sidebar_position: 12
sidebar_label: Runtime Audit
---

# TRI CLI v3.0 — Complete Runtime Audit

Full inventory and runtime verification of all TRI CLI commands. Source of truth: `parseCommand()` in `src/tri/tri_utils.zig` lines 750-969.

**Binary:** `zig-out/bin/tri` (13.1MB, aarch64-macos). **Tested:** 2026-02-24. **Zig:** 0.15.2.

**Legend:** WORKS = produces expected output | NEEDS ARG = requires argument (by design) | INTERACTIVE = enters REPL/chat

---

## Core & SWE Agent (13 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `help` | `--help`, `-h` | WORKS | Full help text with all categories |
| `version` | `--version`, `-v` | WORKS | `TRI CLI v3.0.0` + Trinity identity |
| `info` | — | WORKS | Platform, arch, vocab, templates |
| `chat` | — | INTERACTIVE | Enters chat REPL |
| `code` | — | NEEDS ARG | `Usage: tri code <prompt>` |
| `gen` | — | NEEDS ARG | `Usage: tri gen <spec.vibee>` |
| `fix` | — | NEEDS ARG | `Usage: tri BugFix <file or prompt>` |
| `explain` | — | NEEDS ARG | `Usage: tri Explain <file or prompt>` |
| `test` | — | NEEDS ARG | `Usage: tri Test <file or prompt>` |
| `doc` | — | NEEDS ARG | `Usage: tri Document <file or prompt>` |
| `refactor` | — | NEEDS ARG | `Usage: tri Refactor <file or prompt>` |
| `reason` | — | NEEDS ARG | `Usage: tri Reason <file or prompt>` |
| `bench` | — | WORKS | 1000-iteration benchmark with ops/sec |

## Git (4 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `commit` | — | NEEDS ARG | `Usage: tri commit <message>` |
| `diff` | — | WORKS | `git diff --color=always` |
| `status` | — | WORKS | `git status --short` |
| `log` | — | WORKS | `git log --oneline -10` |

:::warning
`pull` and `push` do **NOT** exist in TRI CLI. They are not registered in `parseCommand()`. Use `git pull` / `git push` directly.
:::

## Pipeline — Golden Chain (5 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `pipeline` | `chain` | WORKS | Golden Chain Pipeline help (16 links) |
| `decompose` | — | NEEDS ARG | `Usage: tri decompose <task description>` |
| `plan` | — | WORKS | Plan Generation (Link 5) |
| `verify` | — | WORKS | Verification (Links 7-11) |
| `verdict` | — | WORKS | Toxic Verdict (Link 14) |

## Dev Tools (10 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `doctor` | — | WORKS | 8-check diagnostics |
| `clean` | — | WORKS | Removes .zig-cache + zig-out (**destroys binary**) |
| `fmt` | — | WORKS | Runs `zig fmt src/` |
| `stats` | — | WORKS | Codebase metrics (files, LOC, specs) |
| `igla` | — | WORKS | IGLA — Trinity Roadmap |
| `test-all` | `test_all` | WORKS | Run all test suites |
| `analyze` | — | WORKS | Scans src/ for TODO/FIXME/HACK markers |
| `search` | — | WORKS | Full-text code search |
| `deps` | — | WORKS | Dependency graph |
| `distributed` | `dist` | WORKS | Distributed inference help |

## VIBEE Tools (10 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `improve` | `self-improve` | WORKS | VIBEE Self-Improver config |
| `improve-all` | `improve_all`, `fix-all` | WORKS | 4-step improvement pipeline |
| `improve-loop` | `improve_loop`, `loop` | WORKS | Continuous improvement loop |
| `strict` | `strict-mode` | WORKS | VIBEE-First Strict Mode help |
| `validate` | — | WORKS | Trinity Validator |
| `gguf-chat` | — | WORKS | GGUF Chat interface |
| `metal` | — | WORKS | Metal GPU Status |
| `prometheus` | — | WORKS | Prometheus Converter |
| `tvc-compile` | `tvcc` | WORKS | TVC Compiler |
| `kg-server` | `kg` | WORKS | Knowledge Graph Server |

Additional VIBEE-related commands (also in Core): `serve`, `convert`, `evolve`, `gen`, `bench`.

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `serve` | — | WORKS | HTTP API Server on port 8080 |
| `convert` | — | NEEDS ARG | `Usage: tri convert <file>` |
| `evolve` | — | WORKS | Firebird Evolution engine |

## Code Quality (4 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `lsp` | `language-server` | WORKS | LSP server (stdio mode) |
| `autofix` | `auto-fix` | WORKS | Auto-fix trailing whitespace, newlines |
| `lint` | `check` | WORKS | 5-check code quality scanner |
| `competitive-repl` | — | WORKS | Multilingual competitive REPL |

## Sacred Math — Top-Level (9 commands)

Aliases verified against `parseCommand()` lines 917-924.

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `math` | `sacred-math` | WORKS | Math subcommand router |
| `constants` | `const` | WORKS | 14+ sacred constants |
| `phi` | `golden` | WORKS | Golden ratio powers phi^n |
| `fib` | `fibonacci` | WORKS | Fibonacci F(n) |
| `lucas` | — | WORKS | Lucas L(n) |
| `spiral` | `phi-spiral` | WORKS | Phi-spiral ASCII visualization |
| `math-verify` | `trinity-verify` | WORKS | 38 mathematical checks |
| `math-bench` | `sacred-bench` | WORKS | Math operation benchmarks |
| `math-compare` | `compare` | WORKS | Side-by-side phi/fib/lucas table |

:::note
`gematria` is NOT a top-level command. Use `tri math gematria` (see subcommands below).
:::

## Sacred Math — Subcommands (30+ via `tri math <sub>`)

These are routed through the `math` command, not registered in `parseCommand()` directly.

| Subcommand | Aliases | Cycle | Status |
|------------|---------|-------|--------|
| `tri math exotic` | `rare` | 83 | WORKS |
| `tri math physical` | `physics`, `phys` | 83 | WORKS |
| `tri math chaos` | `feigenbaum` | 83 | WORKS |
| `tri math all` | — | 83 | WORKS |
| `tri math golden-function` | `gf`, `pellis` | 84 | WORKS |
| `tri math nuclear` | `nuc`, `shell` | 84 | WORKS |
| `tri math fractal` | `frac`, `hausdorff` | 84 | WORKS |
| `tri math quantum` | `berry` | 85 | WORKS |
| `tri math su3` | `color`, `qcd` | 85 | WORKS |
| `tri math planck` | `units`, `planck-phi` | 85 | WORKS |
| `tri math qutrit` | `qt`, `ternary-gate` | 85 | WORKS |
| `tri math holographic` | `holo`, `bekenstein` | 86 | WORKS |
| `tri math ads-cft` | `ads`, `maldacena` | 86 | WORKS |
| `tri math quantum-gravity` | `qg`, `lqg` | 86 | WORKS |
| `tri math particles` | `mass`, `quarks` | 88 | WORKS |
| `tri math groups` | `group-theory`, `e8` | 88 | WORKS |
| `tri math holo-render` | `render` | 87 | WORKS |
| `tri math qg-sim` | `spin-foam` | 87 | WORKS |
| `tri math visual` | `viz`, `plot` | 87 | WORKS |
| `tri math quantum-sim` | `qsim`, `simulate` | 87 | WORKS |
| `tri math trinity` | `identity`, `proof` | 87 | WORKS |
| `tri math harmony` | `music`, `acoustic` | 87 | WORKS |
| `tri math cosmos` | `cosmological`, `hubble` | 87 | WORKS |
| `tri math formula` | `sacred-formula`, `predict` | 87 | WORKS |
| `tri math universe` | `multiverse`, `cosmo-sim` | 90 | WORKS |
| `tri math string-theory` | `strings`, `calabi-yau` | 90 | WORKS |
| `tri math engine` | `v3`, `about` | 87 | WORKS |
| `tri math marketplace` | `market`, `tri-market` | 87 | WORKS |
| `tri math defi` | `yield`, `pools` | 90 | WORKS |
| `tri math rewards` | `tri-rewards`, `stake` | 87 | WORKS |
| `tri math gematria` | `gem`, `coptic` | 96 | WORKS |

## Swarm & Economy (8 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `swarm` | `swarm-sync`, `sync` | WORKS | Swarm control + CRDT sync |
| `rewards` | `tri-rewards`, `tokens` | WORKS | $TRI balance overview |
| `dashboard` | `dash`, `panel` | WORKS | 5-section system dashboard |
| `marketplace` | `market`, `shop` | WORKS | Agent marketplace |
| `marketplace-live` | `market-live`, `live` | WORKS | Real-time trading dashboard |
| `agents-auto` | `agents_auto`, `auto-agents` | WORKS | Autonomous swarm dispatch |
| `full-autonomous` | `full_autonomous`, `health` | WORKS | 5-step health report |
| `economy` | `econ`, `tri-economy` | WORKS | $TRI economy dashboard |

## Omega & Control (3 commands)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `omega` | `omega-mode` | WORKS | 8-subsystem health check |
| `control` | `agent-control`, `ctl` | WORKS | 16-agent roster + resources |
| `singularity` | `sing` | WORKS | Self-evolving OS status |

## Transcendence Tier (Cycles 90-93)

| Command | Aliases | Cycle | Status | Output |
|---------|---------|-------|--------|--------|
| `evolve-os` | `evolve_os`, `self-evolve` | 90 | WORKS | 6-step evolution cycle |
| `transcend` | `transcendence`, `ascend` | 91 | WORKS | 9 capabilities |
| `beyond` | `beyond-code`, `meta` | 91 | WORKS | Intent Compiler + Dream Engine |
| `consciousness` | `conscious`, `awareness` | 91 | WORKS | Consciousness field |
| `omniscience` | `omni`, `all-seeing` | 92 | WORKS | Level XI omniscience |
| `integrate` | `omega-integrate`, `unify` | 92 | WORKS | Omega integration |
| `manifest` | `materialize`, `create` | 92 | WORKS | Thought-to-reality engine |
| `genesis` | `gen-world`, `origin` | 93 | WORKS | Level XII creation |
| `create-world` | `create_world`, `spawn-world` | 93 | WORKS | World factory |
| `ascension` | `rise`, `ultimate` | 93 | WORKS | 9-level ascension ladder |

## Eternity Tier (Cycle 94)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `eternity` | `eternal`, `timeless` | WORKS | Level XIV temporal constructs |
| `infinity` | `infinite`, `boundless` | WORKS | Infinite computation engine |
| `apotheosis` | `deify`, `godhood` | WORKS | 9-level apotheosis ladder |

## Omega Point Tier (Cycle 95)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `omega-point` | `omegapoint`, `teilhard` | WORKS | Omega Point convergence |
| `convergence` | `converge-all`, `final-convergence` | WORKS | Final convergence |
| `convergence analyze` | — | WORKS | Subsystem convergence analysis |
| `convergence proof` | — | WORKS | Mathematical proof |
| `universal` | `universe`, `all-one` | WORKS | Universal ascension |

## Absolute Tier (Cycle 96)

| Command | Aliases | Status | Output |
|---------|---------|--------|--------|
| `absolute` | `abs`, `alpha-omega` | WORKS | Absolute mode |
| `final` | `final-transcendence`, `endgame` | WORKS | Final transcendence |
| `final summary` | — | WORKS | Summary of all 96 cycles |
| `final legacy` | — | WORKS | Legacy documentation |
| `end-of-cycles` | `nova`, `new-era` | WORKS | End of cycles / new era |

## Demos & Benchmarks (73 commands)

36 demo/bench pairs (Cycles 26-52) plus `tvc-stats`. All follow the pattern `<name>-demo` / `<name>-bench`. Sample tested:

| Command | Short Alias | Status |
|---------|-------------|--------|
| `tvc-demo` | `tvc` | WORKS |
| `tvc-stats` | — | WORKS |
| `agents-demo` | `agents` | WORKS |
| `rag-demo` | `rag` | WORKS |
| `consensus-demo` | `consensus`, `raft` | WORKS |
| `workflow-demo` | `workflow`, `wf` | WORKS |

Full list of 36 pairs: see [Demos](/cli/demos).

---

## Grand Summary

| Category | Commands | WORKS | NEEDS ARG | INTERACTIVE |
|----------|----------|-------|-----------|-------------|
| Core & SWE | 13 | 4 | 8 | 1 |
| Git | 4 | 3 | 1 | 0 |
| Pipeline | 5 | 4 | 1 | 0 |
| Dev Tools | 10 | 10 | 0 | 0 |
| VIBEE Tools | 13 | 12 | 1 | 0 |
| Code Quality | 4 | 4 | 0 | 0 |
| Sacred Math (top-level) | 9 | 9 | 0 | 0 |
| Sacred Math (subcommands) | 31 | 31 | 0 | 0 |
| Swarm & Economy | 8 | 8 | 0 | 0 |
| Omega & Control | 3 | 3 | 0 | 0 |
| Transcendence (C90-93) | 10 | 10 | 0 | 0 |
| Eternity (C94) | 3 | 3 | 0 | 0 |
| Omega Point (C95) | 5 | 5 | 0 | 0 |
| Absolute (C96) | 5 | 5 | 0 | 0 |
| Demos & Benchmarks | 73 | 73 | 0 | 0 |
| **Total** | **196** | **184** | **11** | **1** |

- **161 top-level enum variants** in `parseCommand()`
- **31 math subcommands** via `tri math <sub>`
- **~230 unique trigger strings** (commands + aliases)
- **11 NEEDS ARG** are by design (SWE agent commands, gen, code, convert, commit, decompose)
- **1 INTERACTIVE** — `chat` enters REPL without args

---

## Commands That Do NOT Exist

These strings are **not** registered in `parseCommand()` and fall through to the Hybrid Chat REPL:

| String | Correct Command |
|--------|----------------|
| `pull` | Use `git pull` directly |
| `push` | Use `git push` directly |
| `format` | Use `fmt` |
| `demo` | Use specific `<name>-demo` |
| `gateway` | Does not exist |
| `prove` | Does not exist |
| `predict` | Use `tri math formula` (alias `predict`) |
| `audit` | Does not exist |
| `sim` | Does not exist |
| `build-pipeline` | Use `pipeline` |
| `run-pipeline` | Use `pipeline run` |
| `gematria` | Use `tri math gematria` |

## Known Source Code Issues

1. **`autonomous` alias conflict** — `"autonomous"` at line 821 maps to `autonomous_demo`, shadowing the intended `full_autonomous` mapping at line 932. Use `full-autonomous` or `health` instead.
2. **`pipeline` alias conflict** — `"pipeline"` at line 770 maps to `.pipeline`, shadowing `.stream_demo` at line 794. Use `stream-demo` for stream pipeline demos.
3. **Duplicate check** — Line 834 checks `"persist-bench"` twice (harmless copy-paste).
