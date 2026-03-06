---
sidebar_position: 1
sidebar_label: Overview
---

# TRI CLI Reference

**TRI CLI** is the unified command-line interface for the entire Trinity ecosystem. One binary, **157 commands** across **10 categories** — covering AI chat, code generation, SWE agent, sacred mathematics, sacred science, swarm orchestration, VIBEE compilation, and more.

```
φ² + 1/φ² = 3 = TRINITY
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

| Category | Commands | Count |
|----------|----------|-------|
| **AI & Chat** | `chat`, `code` | 2 |
| **Sacred Science** | `bio`, `cosmos`, `neuro`, `music`, `frequency`, `scale`, `chord`, `resonance`, `waveform`, `harmony`, `phi-series` | 11 |
| **Sacred Math** | `math`, `constants`, `phi`, `fib`, `lucas`, `spiral`, `gematria`, `formula`, `sacred` | 8 |
| **Git** | `status`, `diff`, `log`, `commit` | 4 |
| **Development** | `fix`, `explain`, `test`, `doc`, `refactor`, `reason`, `analyze`, `search`, `doctor`, `clean`, `fmt`, `stats`, `igla`, `gen`, `convert`, `serve` | 16 |
| **System** | `info`, `version`, `help`, `bench`, `tvc-stats`, `deps` | 6 |
| **Demos** | `*-demo` (37 commands) | 37 |
| **Benchmarks** | `*-bench` (36 commands) | 36 |
| **Sacred Intelligence** | `identity`, `swarm`, `govern`, `dashboard`, `omega`, `intelligence`, `math-agent`, `wallet`, `mesh`, `reputation`, `quantum`, `release-cosmic` | 12 |
| **Advanced** | `pipeline`, `decompose`, `plan`, `spec-create`, `loop-decide`, `verify`, `verdict`, `evolve`, `distributed`, `multi-cluster`, `context-info`, `hardware`, `time`, `install`, `build`, `deck`, `fpga-demo`, `sacred-full-cycle`, `research`, `launch`, `needle`, `needle-search`, `needle-check`, `monitor` | 25 |

**Total: 157 commands**

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
