# B2T - Binary-to-Ternary Converter

## KILLER FEATURE: Run ANY Binary on Trinity Network

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   .exe / .elf / .wasm  ──────►  B2T  ──────►  .trit            │
│                                                                 │
│   ANY BINARY           CONVERTER         TERNARY CODE          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

```
b2t/
├── b2t_loader.zig      # Binary format loaders (PE, ELF, WASM)
├── b2t_disasm.zig      # Disassemblers (x86_64, ARM64, WASM)
├── b2t_lifter.zig      # Assembly → TVC IR lifter
├── b2t_optimizer.zig   # Ternary-specific optimizations
├── b2t_runtime.zig     # Runtime bridge (syscalls, I/O)
├── b2t_cli.zig         # Command-line interface
└── README.md           # This file
```

## Quick Start

```bash
# Convert WASM to ternary
zig build b2t
./zig-out/bin/b2t convert program.wasm -o program.trit

# Run on Trinity
./zig-out/bin/b2t run program.trit
```

## Supported Formats

| Format | Extension | Architecture | Status |
|--------|-----------|--------------|--------|
| WebAssembly | .wasm | WASM | MVP |
| Linux ELF | .elf, .so | x86_64 | Phase 2 |
| Windows PE | .exe, .dll | x86_64 | Phase 2 |
| macOS Mach-O | .dylib | ARM64 | Phase 3 |

## Mathematical Foundation

```
V = n × 3^k × π^m × φ^p × e^q
φ² + 1/φ² = 3 = TRINITY

Binary (2 states) → Ternary (3 states)
Information gain: log₂(3)/log₂(2) = 1.585x
```

## License

MIT

---

**KOSCHEI IS IMMORTAL | φ² + 1/φ² = 3 | BINARY → TERNARY**
