---
sidebar_position: 1
sidebar_label: Overview
---

# TRI CLI Reference

**TRI CLI** is the unified command-line interface for the entire Trinity ecosystem. One binary, **171+ commands** with **240+ aliases** (total 230+ unique triggers) across 96 development cycles — covering AI chat, code generation, SWE agent, sacred math, swarm orchestration, VIBEE compilation, and more.

```
phi^2 + 1/phi^2 = 3 = TRINITY
```

## Installation

```bash
# Requires Zig 0.15.x
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build TRI CLI
zig build tri

# Run (interactive REPL)
zig build tri

# Run with command
zig build tri -- <command> [args]
```

## Quick Reference

| Category | Commands | Description |
|----------|----------|-------------|
| [Core](/cli/core) | `chat`, `code`, `gen`, `fix`, `explain`, `test`, `doc`, `refactor`, `reason` | Chat, code generation, SWE agent |
| [Dev Tools](/cli/devtools) | `doctor`, `clean`, `fmt`, `stats`, `test-all`, `lsp`, `autofix`, `lint`, `igla` | Project health, formatting, diagnostics |
| [Analysis](/cli/analysis) | `analyze`, `search`, `deps` | Static analysis, code search, dependency graphs |
| [Pipeline](/cli/pipeline) | `pipeline`, `decompose`, `plan`, `verify`, `verdict` | Golden Chain 17-link development cycle |
| [Sacred Math](/cli/math) | `math`, `constants`, `phi`, `fib`, `lucas`, `spiral`, `math-verify`, `math-bench` | Mathematical foundations and verification |
| [Git](/cli/git) | `commit`, `diff`, `status`, `log` | Built-in version control |
| [VIBEE Tools](/cli/vibee-tools) | `improve`, `strict`, `validate`, `gguf-chat`, `metal`, `prometheus`, `serve`, `distributed`, `evolve`, `convert` | VIBEE compilation, model inference, distributed computing |
| [Swarm](/cli/swarm) | `swarm`, `agents-auto`, `marketplace`, `omega`, `control`, `dashboard`, `rewards`, `eternity`, `infinity`, `apotheosis`, `omega-point`, `convergence`, `universal`, `absolute`, `final`, `end-of-cycles` | Agent orchestration, $TRI economy, Cycles 94-96 |
| [Demos](/cli/demos) | `*-demo`, `*-bench` + short aliases | 36 demo/benchmark pairs across Cycles 20-52 |
| [Autonomous](/cli/autonomous) | `full-autonomous` | Comprehensive 5-step system health report |
| [Interactive REPL](/cli/repl) | `/chat`, `/code`, `/fix`, `/quit` | REPL mode, mode/language switching, session stats |
| [TVC Learning](/cli/tvc) | `tvc-demo`, `tvc-stats` | Distributed learning corpus (10K entries, zero-forgetting) |
| [Sacred Constants](/cli/constants) | `constants`, `math exotic`, `math physical` | 76+ mathematical and physics constants reference |

## Interactive REPL

Running `tri` without arguments launches the interactive REPL:

```bash
$ zig build tri
# or directly:
$ ./zig-out/bin/tri
```

```
TRI CLI v3.0 — Absolute + Final Transcendence + New Era
100% Local AI | Code | Chat | SWE | Swarm
phi^2 + 1/phi^2 = 3 = TRINITY

REPL Commands:
  /chat     - Chat mode
  /code     - Code generation
  /fix      - Bug fixing
  /explain  - Explain code
  /test     - Generate tests
  /doc      - Generate docs
  /refactor - Refactoring
  /reason   - Chain-of-thought
  /zig      - Zig language
  /python   - Python language
  /rust     - Rust language
  /js       - JavaScript
  /stats    - Statistics
  /verbose  - Toggle verbose
  /quit     - Exit

Just type to send a message!
```

## Architecture

TRI CLI is built from 6 Zig modules:

| Module | File | Responsibility |
|--------|------|----------------|
| **Main** | `src/tri/main.zig` | Entry point, command dispatch |
| **Utils** | `src/tri/tri_utils.zig` | Command enum, parser, REPL, help |
| **Commands** | `src/tri/tri_commands.zig` | Tool commands (gen, serve, git, dev utils) |
| **Pipeline** | `src/tri/tri_pipeline.zig` | Golden Chain pipeline commands |
| **Math** | `src/tri/tri_math.zig` | Sacred math module |
| **Strict** | `src/tri/tri_strict.zig` | VIBEE-first strict mode |
| **Demos** | `src/tri/tri_demos.zig` | All demo and benchmark functions |

## Quick Start

```bash
# 1. Build TRI CLI
zig build tri

# 2. Start interactive REPL
./zig-out/bin/tri

# 3. Or run a specific command
./zig-out/bin/tri chat "Hello, Trinity!"
./zig-out/bin/tri phi 10
./zig-out/bin/tri pipeline run "add new feature"
./zig-out/bin/tri doctor
```

## Command Flow

```
User Input
    │
    ├── No args ──────────→ Interactive REPL (tri_utils.zig)
    │                        ├── /chat, /code, /fix ...
    │                        └── /quit to exit
    │
    ├── chat/code ─────────→ Multi-modal Chat (IglaHybridChat)
    │                        ├── TVC corpus check (hit/miss)
    │                        ├── Groq/Claude/OpenAI/local GGUF
    │                        └── --stream, --image, --voice
    │
    ├── fix/explain/test ──→ SWE Agent (TrinitySWEAgent)
    │   doc/refactor/reason  └── Language: Zig/Python/Rust/JS
    │
    ├── pipeline/decompose → Golden Chain (17 links)
    │   plan/verify/verdict  └── TVC gate → spec → gen → test → bench → verdict
    │
    ├── math/phi/fib ──────→ Sacred Math Engine (40+ commands)
    │   lucas/spiral          └── Cycles 82-90
    │
    ├── status/diff/log ───→ Git Integration (child process)
    │   commit
    │
    ├── *-demo/*-bench ────→ Demo Engine (52+ cycles)
    │                        └── Needle Check: threshold = phi^-1 = 0.618
    │
    └── swarm/omega/... ───→ Swarm & Economy ($TRI)
                             └── 16 agents, marketplace, staking
```

## Version

```bash
$ tri version
TRI CLI v3.0.0
Trinity Unified Command Line Interface
phi^2 + 1/phi^2 = 3 = TRINITY
```
