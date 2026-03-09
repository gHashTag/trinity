---
sidebar_position: 3
sidebar_label: Development Tools
---

# Development Tools

Project health checks, code formatting, diagnostics, and quality tools.

## doctor

System health check running 5 diagnostics.

```bash
tri doctor
```

**Checks performed:**
1. Zig Version — reports the installed Zig compiler version
2. Compiler — verifies the Zig compiler is functional
3. Std Lib — checks standard library availability
4. Allocator — reports the active memory allocator
5. Build — reports the current build mode

**Example output:**
```
TRINITY DOCTOR - System Health Check
═══════════════════════════════════════════════════════

[1/5] Zig Version:  0.15.2
[2/5] Compiler:  ok
[3/5] Std Lib:   ok
[4/5] Allocator: page_allocator
[5/5] Build:     debug

All systems operational!
```

## clean

Clean build artifacts and cache.

```bash
tri clean
```

Displays instructions for removing `zig-cache/` and `zig-out/` build directories.

**Example output:**
```
Cleaning build artifacts...
  Build directory: zig-cache/, zig-out/
  Use: rm -rf zig-cache zig-out
```

## fmt

Format Zig source code using `zig fmt`.

```bash
tri fmt
```

Runs `zig fmt src/` on the entire source tree.

**Example output:**
```
Formatting Zig code...
  Command: zig fmt src/
```

## stats

Show system statistics and core metrics.

```bash
tri stats
```

**Example output:**
```
TRINITY STATISTICS
═══════════════════════════════════════════════════════

Code Statistics:
  Core modules: 6
  VSA operations: 8
  VM instructions: 16

Performance Metrics:
  VSA ops/ms: 1000
  VM instr/ms: 500
```

## test-all

> **Status:** Planned — not yet available in TRI CLI. Use `zig build test` directly.

Run all test suites.

**Aliases:** `test_all`

```bash
tri test-all
```

Runs VSA, VM, and integration tests.

## igla

IGLA vector compression and hybrid chat system.

```bash
tri igla
```

Runs the IGLA (Igla Vector Compression) engine — combines TVC corpus (10,000-entry ternary vector corpus) with local chat for hybrid AI responses. Displays compression metrics, vector stats, and response quality scores.

**Example output:**

```
IGLA VECTOR COMPRESSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Corpus:      10,000 entries
  Dimensions:  256
  Compression: 20x (vs float32)
  Encoding:    Ternary {-1, 0, +1}

  Chat mode: hybrid (TVC + local)
  Status:    READY
```

## lsp

> **Status:** Planned — not yet available in TRI CLI.

Start Language Server Protocol server.

**Aliases:** `language-server`

```bash
tri lsp                    # stdio mode (default)
tri lsp --port 9999        # TCP mode
tri lsp --verbose          # Detailed logging
```

Planned to provide diagnostics, completion, and code intelligence for `.zig` and `.vibee` files.

## autofix

> **Status:** Planned — not yet available in TRI CLI. Use `tri fmt` for formatting.

Automatically fix common code issues.

**Aliases:** `auto-fix`

```bash
tri autofix [file]
tri autofix src/main.zig
```

Planned to fix: trailing whitespace, missing newlines at EOF, run `zig fmt`.

## lint

> **Status:** Planned — not yet available in TRI CLI.

5-check code quality scanner.

**Aliases:** `check`

```bash
tri lint [file]
tri lint src/vsa.zig
```

Planned checks:
1. Trailing whitespace
2. Missing final newline
3. Long lines (>120 chars)
4. TODO/FIXME comments
5. Unused imports
