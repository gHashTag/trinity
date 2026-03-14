---
sidebar_position: 1
sidebar_label: Overview
---

# TRI CLI Reference

**TRI CLI** is the unified command-line interface for the entire Trinity ecosystem. One binary, **300+ commands** across **15 categories** — covering AI chat, code generation, SWE agent, sacred mathematics, sacred science, swarm orchestration, VIBEE compilation, training farm, cloud orchestration, and more.

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
./zig-out/bin/tri

# Run with command
./zig-out/bin/tri <command> [args]
```

## Quick Reference

| Category | Commands | Description |
|----------|----------|-------------|
| **AI & Chat** | `chat`, `code`, `reason`, `igla` | 5 commands for AI assistance |
| **Sacred Science** | `bio`, `cosmos`, `neuro`, `chem`, `music`, `frequency`, `scale`, `chord`, `resonance`, `waveform`, `harmony`, `phi-series`, `intelligence`, `identity`, `swarm`, `govern`, `omega`, `quantum`, `conscious` | 25 commands for sacred science |
| **Sacred Math** | `constants`, `phi`, `fib`, `lucas`, `spiral`, `gematria`, `formula`, `sacred` | 8 commands for sacred mathematics |
| **Git** | `status`, `diff`, `log`, `commit` | 4 commands for Git workflow |
| **Development** | `fix`, `explain`, `test`, `doc`, `refactor`, `analyze`, `search`, `query`, `context-info`, `doctor`, `clean`, `fmt`, `stats`, `gen`, `convert`, `serve`, `build`, `deploy`, `deck`, `bench`, `time`, `install` | 22 commands for development |
| **System** | `info`, `version`, `help`, `deps`, `tvc-stats`, `math-agent` | 6 commands for system operations |
| **Demos** | `*-demo` (37 commands) | 37 demo commands |
| **Benchmarks** | `*-bench` (36 commands) | 36 benchmark commands |
| **Golden Chain** | `pipeline`, `pipeline-demo`, `decompose`, `plan`, `spec-create`, `loop-decide`, `verify`, `verdict` | 8 commands for autonomous development |
| **Advanced** | `evolve`, `distributed`, `multi-cluster`, `hardware`, `fpga-demo`, `sacred-full-cycle`, `research`, `launch`, `needle`, `needle-search`, `needle-check`, `monitor`, `math-agent` | 13 advanced commands |
| **DePIN** | `wallet`, `mesh`, `reputation`, `hardware` | 4 commands for DePIN operations |
| **Infrastructure** | `farm`, `cloud`, `dev`, `train` | 50+ commands for training farm, cloud dev, agent swarm |
| **Operations** | `notify`, `deploy`, `loop`, `job` | 15+ commands for notifications, deployment, async jobs |
| **Research** | `research`, `experiment`, `zenodo` | 15+ commands for web research, experiment tracking, DOI publishing |
| **Agents** | `faculty`, `experience`, `issue`, `doctor`, `fpga` | 30+ commands for agent board, memory, issues, health, FPGA |

**Total: 300+ commands**

## Most Used Commands

### AI & Chat
```bash
tri chat "Explain ternary computing"    # Chat with AI
tri code fibonacci                        # Generate code
tri reason "how does VSA work"           # Chain-of-thought
```

### Development
```bash
tri fix src/main.zig                     # Detect and fix bugs
tri explain src/vsa.zig                  # Explain code
tri test src/vsa.zig                     # Generate tests
tri gen specs/my_module.vibee            # Compile VIBEE spec
tri serve --port 8080                    # Start HTTP server
```

### Sacred Math
```bash
tri constants                             # Show φ, π, e, Lucas, Fibonacci
tri phi 10                               # Compute φ^10
tri fib 50                               # Fibonacci with BigInt
tri lucas 10                             # Lucas L(10)
```

### Git
```bash
tri status                               # Git status --short
tri diff                                 # Show changes
tri log                                  # Show last 10 commits
tri commit "fix: memory leak"            # Stage all and commit
```

## Interactive REPL

Running `tri` without arguments launches the interactive REPL:

```bash
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

## Command Categories

### AI & Chat (5 commands)
Chat, code generation, and reasoning assistance.

### Sacred Science (25 commands)
Biology, cosmology, neuroscience, chemistry, music, consciousness, quantum mechanics.

### Sacred Math (8 commands)
Golden ratio (φ), Fibonacci, Lucas, spiral coordinates.

### Git (4 commands)
Streamlined Git workflow: status, diff, log, commit.

### Development (22 commands)
SWE agent tools (fix, explain, test, doc), VIBEE compiler, build tools, HTTP server.

### System (6 commands)
System info, version, dependencies, health check.

### Demos (37 commands)
Interactive demonstrations of all Trinity features.

### Benchmarks (36 commands)
Performance benchmarks for all subsystems.

### Golden Chain (8 commands)
Autonomous development pipeline (22-link Golden Chain).

### Advanced (13 commands)
Distributed computing, FPGA, research tools.

### DePIN (4 commands)
Wallet management, mesh networking, reputation system.

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
    ├── pipeline/decompose → Golden Chain (22 links)
    │   plan/verify/verdict  └── TVC gate → spec → gen → test → bench → verdict
    │
    ├── math/phi/fib ──────→ Sacred Math Engine (φ calculations)
    │   lucas/spiral          └── Cycles 82-90
    │
    ├── status/diff/log ───→ Git Integration (child process)
    │   commit
    │
    ├── *-demo/*-bench ────→ Demo Engine (52+ cycles)
    │                        └── Needle Check: threshold = φ^-1 = 0.618
    │
    └── swarm/omega/... ───→ Swarm & Economy ($TRI)
                             └── 16 agents, marketplace, staking
```

## Help System

```bash
tri help                    # Show all commands by category
tri help --category math     # Show commands in category
tri help --search "test"     # Search commands
tri help fix                # Show detailed command help
tri --help                  # Show all commands
tri -h                      # Show all commands
```

## Version

```bash
$ tri version
TRI CLI v3.0.0
Trinity Unified Command Line Interface
phi^2 + 1/phi^2 = 3 = TRINITY
```

## Next Steps

- [Command Categories](/cli/categories) — Browse commands by category
- [Sacred Mathematics](/cli/math) — φ, π, e, Fibonacci, Lucas
- [Development Tools](/cli/devtools) — fix, explain, test, gen
- [Golden Chain Pipeline](/cli/pipeline) — Autonomous development
- [Demos & Benchmarks](/cli/demos) — 73 commands for testing
- [Training Farm](/cli/farm) — Railway training farm management
- [Cloud Orchestration](/cli/cloud) — Agent containers & Railway
- [SWE Agent Farm](/cli/dev) — Autonomous dev agents
- [HSLM Training](/cli/train) — Training monitor & control
- [FPGA](/cli/fpga) — Synthesis & ternary inference
