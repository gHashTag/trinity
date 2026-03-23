---
sidebar_position: 8
sidebar_label: VIBEE Tools
---

# VIBEE Integration & Tools

VIBEE compiler integration, model inference, self-improvement, validation, and server tools.

> **Note:** Some VIBEE tools (`improve`, `improve-all`, `improve-loop`, `validate`, `gguf-chat`, `metal`, `prometheus`) are available through the **VIBEE binary** (`zig build vibee -- <cmd>`) rather than the `tri` CLI. The `tri` CLI provides `gen`, `serve`, `convert`, `bench`, `evolve`, `distributed`, and `strict` directly.

## improve

Run the VIBEE self-improvement engine.

**Aliases:** `self-improve`

```bash
tri improve                             # Show config
tri improve --iterations 5              # Run 5 iterations
tri improve --threshold 95.0            # Set quality threshold
tri improve --dry-run --verbose         # Preview without changes
```

**Options:**

| Flag | Description |
|------|-------------|
| `--iterations N` | Number of improvement iterations |
| `--threshold F` | Quality threshold (0-100) |
| `--dry-run` | Preview changes without applying |
| `--verbose` | Show detailed output |

Uses the `vibee-self-improve` binary. Cycle: analyze → suggest → patch → regenerate → validate.

## improve-all

Full 4-step improvement pipeline.

**Aliases:** `improve_all`, `fix-all`

```bash
tri improve-all
tri improve-all --dry-run
```

**Steps:**

1. **Scan compliance** — check for violations and warnings
2. **Auto-fix missing specs** — run `tri strict fix`
3. **Regenerate warning files** — refresh spec timestamps
4. **Final verification** — confirm all issues resolved

Produces an IMPROVE-ALL REPORT with before/after metrics.

## improve-loop

Continuous self-improvement loop with phi-scaled iterations.

**Aliases:** `improve_loop`, `loop`

```bash
tri improve-loop [iterations]
```

Runs analyze → suggest → patch → verify in a continuous loop.

## strict

VIBEE-first strict mode enforcement.

**Aliases:** `strict-mode`

```bash
tri strict enable                       # Activate enforcement
tri strict disable                      # Deactivate
tri strict status                       # Show rules
tri strict check [path]                 # Validate compliance
tri strict fix [--dry-run]              # Auto-generate missing .vibee specs
```

**Protected directories:** `var/trinity/output/`, `generated/` — code in these directories must come from `.vibee` specifications.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `enable` | Activate VIBEE-first enforcement |
| `disable` | Deactivate strict mode |
| `status` | Show current enforcement rules |
| `check [path]` | Validate a file or directory for compliance |
| `fix [--dry-run]` | Auto-generate missing `.vibee` specs |

## validate

Validate `.vibee` specs or Zig source files.

```bash
tri validate [file]
tri validate specs/tri/my_module.vibee
tri validate src/main.zig --strict
tri validate src/main.zig --fix
```

**Options:**

| Flag | Description |
|------|-------------|
| `--strict` | Enable strict validation |
| `--fix` | Auto-fix detected issues |

## gguf-chat

Chat with a local GGUF model.

```bash
tri gguf-chat --model <path.gguf>
tri gguf-chat --model model.gguf --stream
```

**Options:**

| Flag | Description |
|------|-------------|
| `--model [path]` | Path to GGUF model file |
| `--stream` | Enable streaming (typing effect) |

## metal

Show GPU acceleration status.

```bash
tri metal
```

Displays Metal GPU acceleration status for Apple Silicon.

## prometheus

Convert Float32 weights to ternary format.

```bash
tri prometheus <file>
tri prometheus model.safetensors
tri prometheus weights.pt --info
```

**Options:**

| Flag | Description |
|------|-------------|
| `--info` | Show conversion info without converting |

Supports safetensors and PyTorch weight formats. Output: `.tri` ternary format.

## tvc-compile

Compile TVC specifications to binary.

**Aliases:** `tvcc`

```bash
tri tvc-compile <spec>
tri tvc-compile specs/tri/module.vibee --output build/
tri tvc-compile specs/tri/module.vibee --debug
```

**Options:**

| Flag | Description |
|------|-------------|
| `--output [path]` | Output directory |
| `--debug` | Enable debug symbols |

## competitive-repl

Multilingual competitive programming REPL.

```bash
tri competitive-repl
tri competitive-repl --lang en          # English
tri competitive-repl --lang ru          # Russian
tri competitive-repl --lang th          # Thai
```

## kg-server

Start the Knowledge Graph server.

**Aliases:** `kg`

```bash
tri kg-server
tri kg-server --port 8081
tri kg-server --persist
```

**Options:**

| Flag | Description |
|------|-------------|
| `--port N` | Server port (default: 8081) |
| `--persist` | Enable persistent storage |

## serve

Start the HTTP API server.

```bash
tri serve                               # Default HTTP API server
tri serve --port 8080                   # Custom port
tri serve --self-host                   # Self-hosting dev server v2.1
tri serve --chat --model model.gguf     # Chat server v2.3 with model
```

**Options:**

| Flag | Description |
|------|-------------|
| `--port N` | Server port (default: 8080) |
| `--chat` | Enable chat server mode (v2.3) |
| `--self-host` | Enable self-hosting dev server (v2.1) |
| `--model [path]` | Path to GGUF model file (for chat mode) |

Provides REST API access to VIBEE compiler and inference.

## convert

Format conversion between different representations.

```bash
tri convert <file>                      # Auto-detect format
tri convert module.wasm --wasm          # Force WASM → TVC conversion
tri convert weights.bin --b2t           # Force Binary → Ternary conversion
```

**Options:**

| Flag | Description |
|------|-------------|
| `--wasm` | Force WASM → TVC conversion mode |
| `--b2t` | Force Binary → Ternary conversion mode |

Supports WASM → TVC, Binary → Ternary, and other format conversions.

## bench

Run standalone performance benchmarks.

```bash
tri bench
```

Measures compute time, operations per second, and memory usage across core subsystems.

## evolve

Evolutionary algorithms for code optimization.

```bash
tri evolve                              # Default parameters
tri evolve --dim 10000 --pop 50 --gen 100
```

**Options:**

| Flag | Default | Description |
|------|---------|-------------|
| `--dim N` | 10000 | Vector dimension |
| `--pop N` | 50 | Population size |
| `--gen N` | 100 | Number of generations |

Uses genetic algorithms with phi-scaled fitness functions.

## distributed

Distributed computing and multi-node coordination.

**Aliases:** `dist`

```bash
# Coordinator node
tri distributed --role coordinator --model model.gguf --peer localhost:9335 --prompt "Hello"

# Worker node
tri distributed --role worker --model model.gguf --layers 0-10 --port 9335
```

**Options:**

| Flag | Default | Description |
|------|---------|-------------|
| `--role [role]` | — | Node role: `coordinator` or `worker` |
| `--model [path]` | — | Path to GGUF model file |
| `--layers [range]` | — | Layer range (e.g., `0-10`, `11-21`) |
| `--port N` | 9335 | Worker listen port |
| `--peer [host:port]` | — | Worker address (for coordinator) |
| `--prompt [text]` | — | Prompt text (for coordinator) |
| `--max-tokens N` | 20 | Maximum tokens to generate |

Manages distributed inference across multiple nodes with layer-parallel splitting.

## gen

Compile a `.vibee` specification into code.

```bash
tri gen <spec.vibee>
tri gen specs/tri/my_module.vibee
```

**Output locations:**

| Language | Output Directory |
|----------|-----------------|
| Zig | `var/trinity/output/` |
| Verilog | `var/trinity/output/fpga/` |

See [Core Commands](/cli/core) for full `gen` documentation.
