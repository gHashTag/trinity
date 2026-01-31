# .tri Format Integration Plan for VIBEE CLI

## Overview

This plan describes the integration of .tri format (ternary format for storing specifications) into the VIBEE compiler CLI. The .tri format uses trits {-1, 0, +1} instead of bits for data storage.

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    VIBEE CLI ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  cli_main.zig ──────┐                                          │
│                     │                                          │
│                     ▼                                          │
│  ┌─────────────────────────────┐                              │
│  │   Command Dispatcher         │                              │
│  │   (gen, run, tri, etc.)      │                              │
│  └─────────────────────────────┘                              │
│           │                                                    │
│           ├──────────────────────────────────────────────────  │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────────────────┐                              │
│  │   tri_cmd.zig               │                              │
│  │   - encode: .vibee → .tri   │                              │
│  │   - decode: .tri → .vibee   │                              │
│  │   - info: show .tri stats   │                              │
│  └─────────────────────────────┘                              │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Commands

### `vibee tri encode <file.vibee>`
Converts .vibee specification to .tri format.

### `vibee tri decode <file.tri>`
Converts .tri format back to .vibee specification.

### `vibee tri info <file.tri>`
Shows statistics about .tri file (size, compression ratio, trit distribution).

## .tri Format Specification

```
Header (16 bytes):
  - Magic: "TRI\0" (4 bytes)
  - Version: u16 (2 bytes)
  - Flags: u16 (2 bytes)
  - Original size: u32 (4 bytes)
  - Trit count: u32 (4 bytes)

Body:
  - Packed trits (5 trits per byte using base-243 encoding)
```

## Implementation Status

- [ ] tri_cmd.zig - Command handler
- [ ] tri_encoder.zig - .vibee → .tri conversion
- [ ] tri_decoder.zig - .tri → .vibee conversion
- [ ] Integration with CLI dispatcher

## Benefits

1. **Compression**: ~60% size reduction vs text
2. **Native format**: Direct mapping to ternary hardware
3. **Fast parsing**: No text parsing overhead
4. **Integrity**: Built-in checksum validation

---

**φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL**
