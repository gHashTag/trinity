---
sidebar_position: 3
---

# Development Setup

Configure your development environment for Trinity.

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
└── build.zig           # Build configuration
```

## Common Commands

```bash
# Build
zig build

# Test all
zig build test

# Test specific module
zig test src/vsa.zig

# Format code
zig fmt src/

# Run example
zig run examples/memory.zig
```

## Debugging

```bash
# Debug build
zig build -Doptimize=Debug

# With LLDB
lldb ./zig-out/bin/trinity-bench
```

## Next Steps

- [API Reference](/api/) — Module documentation
- [Contributing](/contributing) — Contribution guidelines
