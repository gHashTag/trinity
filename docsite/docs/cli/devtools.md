---
sidebar_position: 3
sidebar_label: Development Tools
---

# Development Tools

Project health checks, code formatting, diagnostics, and quality tools.

## doctor

Comprehensive project health check running 8 diagnostics.

```bash
tri doctor
```

**Checks performed:**
1. Zig compiler version
2. `build.zig` exists
3. `src/tri/main.zig` exists
4. `tri_colors.zig` exists
5. Binary `zig-out/bin/tri` exists
6. `specs/` directory exists
7. Core tests pass (`src/vsa.zig`)
8. VM tests pass (`src/vm.zig`)

**Example output:**
```
TRI DOCTOR
Running diagnostics...
  ✓ Zig compiler: 0.15.2
  ✓ build.zig found
  ✓ src/tri/main.zig found
  ✓ tri_colors.zig found
  ✓ zig-out/bin/tri binary exists
  ✓ specs/ directory found
  ✓ Core tests passed (vsa.zig)
  ✓ VM tests passed (vm.zig)

  Passed: 8/8
  Status: ALL CHECKS PASSED
```

## clean

Clean build artifacts and cache.

```bash
tri clean
```

Removes `zig-cache/`, `zig-out/`, and other build artifacts.

## fmt

Format Zig source code using `zig fmt`.

```bash
tri fmt
```

Runs `zig fmt src/` on the entire source tree.

## stats

Show codebase metrics.

```bash
tri stats
```

**Example output:**
```
TRI STATS
  Codebase:
    Zig files:     1014
    Lines of code:  636328
    VIBEE specs:    825
    Test files:     775

  Architecture:
    Platform:      macos
    Arch:          aarch64
    Encoding:      Ternary (1.58 bits/trit)
```

## test-all

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

Start Language Server Protocol server.

**Aliases:** `language-server`

```bash
tri lsp                    # stdio mode (default)
tri lsp --port 9999        # TCP mode
tri lsp --verbose          # Detailed logging
tri lsp start              # Start LSP server
tri lsp status             # Show server status
tri lsp stop               # Stop running server
tri lsp info               # Show capabilities
```

**Options:**

| Flag | Description |
|------|-------------|
| `--port N` | LSP server port (TCP mode) |
| `--verbose` | Enable detailed logging |

Provides diagnostics, completion, and code intelligence for `.zig` and `.vibee` files.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `start` | Start LSP server (stdio or TCP) |
| `status` | Show server running state |
| `stop` | Stop running LSP server |
| `info` | Display 27 LSP capabilities |

### Capabilities (27)

Diagnostics, completion, hover, definition, references, rename, formatting, code actions, signature help, document symbols, workspace symbols, folding ranges, semantic tokens, inlay hints, and more.

## autofix

Automatically fix common code issues.

**Aliases:** `auto-fix`

```bash
tri autofix [file]
tri autofix src/main.zig
```

Fixes: trailing whitespace, missing newlines at EOF, runs `zig fmt`.

## lint

5-check code quality scanner.

**Aliases:** `check`

```bash
tri lint [file]
tri lint src/vsa.zig
```

**Checks:**
1. Trailing whitespace
2. Missing final newline
3. Long lines (>120 chars)
4. TODO/FIXME comments
5. Unused imports
