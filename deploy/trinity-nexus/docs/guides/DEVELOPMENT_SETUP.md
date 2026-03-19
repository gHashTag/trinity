# Development Setup Guide

> Complete setup instructions for Trinity development

---

## Prerequisites

### Required

| Tool | Version | Purpose |
|------|---------|---------|
| **Zig** | 0.13.0 | Primary language |
| **Git** | 2.x+ | Version control |

### Optional

| Tool | Purpose |
|------|---------|
| **VSCode** | IDE with Zig extension |
| **Zed** | Fast editor with Zig support |
| **Make** | Convenience scripts |

---

## Installing Zig 0.13.0

### macOS

```bash
# Option 1: Direct download (recommended)
curl -LO https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz
tar -xf zig-macos-aarch64-0.13.0.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.13.0:$PATH"

# Option 2: Homebrew (may have different version)
brew install zig@0.13
```

### Linux

```bash
curl -LO https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar -xf zig-linux-x86_64-0.13.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.13.0:$PATH"
```

### Windows

1. Download from https://ziglang.org/download/
2. Extract to `C:\zig`
3. Add `C:\zig` to PATH

### Verify Installation

```bash
zig version
# Output: 0.13.0
```

---

## Cloning the Repository

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

---

## Building

### Build Library

```bash
zig build
```

### Build Specific Targets

```bash
zig build firebird    # Firebird LLM CLI
zig build release     # Cross-platform release builds
zig build bench       # Benchmarks
zig build examples    # Example programs
```

---

## Running Tests

### All Tests

```bash
zig build test
```

### Specific Module Tests

```bash
zig test src/vsa.zig              # VSA operations
zig test src/vm.zig               # Virtual machine
zig test src/hybrid.zig           # HybridBigInt
zig test src/firebird/b2t_integration.zig  # Firebird
```

### Test with Verbose Output

```bash
zig test src/vsa.zig --verbose
```

### Filter Specific Test

```bash
zig test src/vsa.zig --filter "bind"
```

---

## IDE Setup

### VSCode

1. Install [Zig Language](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig) extension
2. Install [ZLS](https://github.com/zigtools/zls) (Zig Language Server)

**settings.json:**
```json
{
  "zig.path": "/path/to/zig",
  "zig.zls.path": "/path/to/zls",
  "editor.formatOnSave": true
}
```

### Zed

Zig support is built-in. Just open the project.

### Vim/Neovim

```vim
" Install zig.vim plugin
Plug 'ziglang/zig.vim'
```

---

## Project Structure

```
trinity/
├── src/                 # Source code
│   ├── vsa.zig         # Vector Symbolic Architecture
│   ├── vm.zig          # Virtual Machine
│   ├── hybrid.zig      # HybridBigInt
│   ├── firebird/       # LLM engine
│   └── vibeec/         # VIBEE compiler
├── specs/              # .vibee specifications
├── examples/           # Example programs
├── docs/               # Documentation
├── book/               # Educational book
├── build.zig           # Build configuration
└── CLAUDE.md           # Developer guidance
```

---

## Common Tasks

### Format Code

```bash
zig fmt src/
```

### Generate Code from Spec

```bash
./bin/vibee gen specs/tri/module.vibee
```

### Run Example

```bash
zig run examples/memory.zig
```

### Run Benchmarks

```bash
zig build bench
./zig-out/bin/trinity-bench
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ZIG_DEBUG_LOG` | Enable debug logging |
| `ZIG_VERBOSE` | Verbose compilation |

---

## Debugging

### Debug Build

```bash
zig build -Doptimize=Debug
```

### With GDB/LLDB

```bash
zig build -Doptimize=Debug
lldb ./zig-out/bin/trinity-bench
```

### Memory Debugging

```bash
zig test src/module.zig -Dleak-detection
```

---

## Troubleshooting

### Zig Version Mismatch

**Error:** `no field or member function named 'addStaticLibrary'`

**Solution:** Install Zig 0.13.0 (see installation above)

### Build Failures

**Solution:** Try running tests directly:
```bash
zig test src/vsa.zig  # Bypasses build.zig
```

### Missing Files

**Solution:** Ensure you're in project root:
```bash
pwd  # Should show /path/to/trinity
```

---

## Next Steps

1. Read [CLAUDE.md](../../CLAUDE.md) for development guidance
2. Explore [docs/api/](../api/) for API reference
3. Try [examples/](../../examples/) to understand usage

---

## See Also

- [CONTRIBUTING.md](../../CONTRIBUTING.md) — Contribution guidelines
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) — Common issues
- [INDEX.md](../INDEX.md) — Documentation index
