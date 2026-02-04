---
sidebar_position: 2
---

# Installation

Complete installation guide for Trinity.

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| Zig | 0.13.0 |
| RAM | 4 GB |
| Disk | 1 GB |

## Installing Zig

### macOS

```bash
# Option 1: Direct download (recommended)
curl -LO https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz
tar -xf zig-macos-aarch64-0.13.0.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.13.0:$PATH"

# Option 2: Homebrew
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

## Clone Repository

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

## Build

```bash
# Build all
zig build

# Build specific target
zig build firebird    # LLM CLI
zig build release     # Cross-platform builds
```

## Verify Installation

```bash
# Run tests
zig build test

# Or test specific module
zig test src/vsa.zig
```

## Troubleshooting

### Zig Version Mismatch

If you see errors like `no field named 'addStaticLibrary'`, you have the wrong Zig version.

**Solution:** Install Zig 0.13.0 as shown above.

### Build Failures

Try running tests directly:

```bash
zig test src/vsa.zig  # Bypasses build.zig
```

## Next Steps

- [Quick Start](/docs/getting-started/quickstart) — First steps
- [Development Setup](/docs/getting-started/development-setup) — IDE configuration
