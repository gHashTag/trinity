# Trinity Common Module

**Version:** 1.0
**Status:** Stable
**Location:** `src/common/`

---

## Purpose

The `common` module is the **single source of truth** for shared constants, protocol definitions, and error types used throughout Trinity. It eliminates code duplication and ensures consistency across all subsystems (VSA, UART, FPGA, consciousness, etc.).

---

## Key Files

| File | Purpose | Public Exports |
|------|---------|----------------|
| `constants.zig` | Sacred mathematical constants (φ, γ, TRINITY) | `PHI`, `PHI_INV`, `GAMMA`, `TRINITY`, etc. |
| `protocol.zig` | UART protocol definitions (Trit, Commands, CRC) | `Trit`, `Command`, `Response`, `crc16Ccitt()` |
| `errors.zig` | Unified error types for all domains | `VSAError`, `ProtocolError`, `UARTError`, `FPGAError`, etc. |
| `output_config.zig` | Unified build output configuration | `OutputConfig`, global output paths |
| `consistency_tests.zig` | Validation tests for common module | — |

---

## Public API

### constants.zig

```zig
const sacred = @import("common").constants;

// Golden Ratio (φ)
sacred.PHI       // 1.6180339887498948482
sacred.PHI_INV   // 0.618033988749895 (Immortality Threshold)
sacred.PHI_SQ    // 2.618033988749895
sacred.GAMMA     // 0.23606797749978969641 (φ⁻³)

// Trinity Identity
sacred.TRINITY   // 3.0 (φ² + φ⁻² = 3 exactly)

// Mathematical constants
sacred.PI        // 3.14159265358979323846
sacred.E         // 2.71828182845904523536
```

### protocol.zig

```zig
const protocol = @import("common").protocol;

// Trit encoding (2-bit packed)
protocol.Trit.NEGATIVE    // 0b10 = -1
protocol.Trit.ZERO        // 0b00 = 0
protocol.Trit.POSITIVE    // 0b01 = +1

// Convert to/from integer value
protocol.tritValue(protocol.Trit.POSITIVE)  // returns 1

// UART Commands
protocol.Command.MODE        // 0x01
protocol.Command.BIND        // 0x02
protocol.Command.BUNDLE      // 0x03
protocol.Command.SIMILARITY  // 0x04
protocol.Command.BITNET      // 0x05
protocol.Command.PING        // 0xFF

// UART Responses
protocol.Response.OK     // 0x00
protocol.Response.PONG   // 0xAA

// CRC-16/CCITT checksum
_ = protocol.crc16Ccitt("123456789");  // returns 0x29B1

// Protocol constants
protocol.SYNC_BYTE       // 0xAA
protocol.BAUD_RATE       // 115200
protocol.TIMEOUT_MS      // 5000
protocol.VECTOR_SIZE     // 16
protocol.VECTOR_BYTES    // 4
```

### errors.zig

```zig
const errors = @import("common").errors;

// VSA Errors
errors.VSAError.InvalidDimension
errors.VSAError.IndexOutOfBounds
errors.VSAError.VectorLengthMismatch
errors.VSAError.InvalidTrit
errors.VSAError.ConceptNotFound

// Protocol Errors
errors.ProtocolError.InvalidChecksum
errors.ProtocolError.InvalidSync
errors.ProtocolError.UnknownCommand

// UART Errors
errors.UARTError.Timeout
errors.UARTError.DeviceNotFound
errors.UARTError.Overflow

// FPGA Errors
errors.FPGAError.PlacementFailed
errors.FPGAError.RoutingFailed
errors.FPGAError.TimingViolation

// Combined error sets
errors.TrinityError              // All errors combined
errors.VSAIOError                // VSA + UART + Common

// Utilities
errors.isRecoverable(err)        // bool
errors.getDescription(err)       // []const u8
```

---

## Contracts

### constants.zig

**Preconditions:** None
**Postconditions:** All constants are computed at compile time
**Invariants:**
- `TRINITY = PHI_SQ + PHI_INV_SQ = 3.0` (exact)
- `GAMMA = PHI^(-3)`
- All constants are `f64` precision

### protocol.zig

**Preconditions:**
- `crc16Ccitt()`: input data must be valid UTF-8 or binary
- `tritValue()`: must receive valid Trit enum value

**Postconditions:**
- `crc16Ccitt()`: returns 16-bit checksum (0x0000-0xFFFF)
- `tritValue()`: returns -1, 0, or +1 as i8

**Invariants:**
- Trit encoding uses exactly 2 bits per trit
- CRC-16/CCITT uses polynomial 0x1021, initial value 0xFFFF
- All command/response IDs are single-byte values

### errors.zig

**Preconditions:** None
**Postconditions:** All error sets are composable via `||` operator

**Invariants:**
- `isRecoverable()` returns true only for errors that can be retried
- `getDescription()` never returns null for known error types

---

## Examples

### Example 1: Using sacred constants in VSA

```zig
const std = @import("std");
const sacred = @import("common").constants;

pub fn calculateImmortalityThreshold(consciousness: f64) bool {
    return consciousness >= sacred.PHI_INV;
}

pub fn dimensionFromPhi(n: usize) usize {
    return @intFromFloat(@as(f64, @floatFromInt(n)) * sacred.PHI);
}
```

### Example 2: UART communication with error handling

```zig
const protocol = @import("common").protocol;
const errors = @import("common").errors;

pub fn sendBindCommand(device: std.fs.File, a: Vector16, b: Vector16) !void {
    const cmd = protocol.Command.BIND;
    const checksum = protocol.crc16Ccitt(&[_]u8{ @intFromEnum(cmd), a[0], b[0] });

    if (checksum == 0) {
        return errors.ProtocolError.InvalidChecksum;
    }

    try device.writeAll(&[_]u8{ protocol.SYNC_BYTE, @intFromEnum(cmd) });
}
```

### Example 3: Recoverable error handling

```zig
const errors = @import("common").errors;

pub fn safeVsaOperation(vec: *Vector16, index: usize) !Trit {
    if (index >= vec.len) {
        return errors.VSAError.IndexOutOfBounds;
    }
    return vec[index];
}

pub fn executeWithRetry(comptime Operation: type) !void {
    var attempts: u32 = 0;
    while (attempts < 3) : (attempts += 1) {
        Operation.execute() catch |err| {
            if (!errors.isRecoverable(err)) return err;
            continue;
        };
        return;
    }
}
```

---

## Testing

**Location:** `src/common/consistency_tests.zig`

**Run tests:**
```bash
zig test src/common/consistency_tests.zig
```

**Coverage:**
- ✅ Golden identity validation (φ² + φ⁻² = 3)
- ✅ Trit enum encoding verification
- ✅ Command/Response enum values
- ✅ CRC-16/CCITT known test vectors
- ✅ Protocol constants
- ✅ Error set completeness

---

## Dependencies

**Internal:** None (base module)
**External:** `std` (Zig standard library)

---

## Migration Notes

### From local constants to common module

**Before (DO NOT DO THIS):**
```zig
// In your file - DON'T!
const PHI: f64 = 1.618033988749895;
const Trit = enum(u2) { NEGATIVE = 0b10, ... };
const VSAError = error { InvalidDimension, ... };
```

**After (CORRECT):**
```zig
// Import from common module
const sacred = @import("common").constants;
const protocol = @import("common").protocol;
const errors = @import("common").errors;

// Use
const phi = sacred.PHI;
const Trit = protocol.Trit;
const VSAError = errors.VSAError;
```

---

## Design Principles

1. **Single Source of Truth:** All shared constants live here
2. **No Duplicates:** Never redefine sacred constants elsewhere
3. **Composability:** Error sets compose via `||` operator
4. **Zero-Cost Abstractions:** All constants computed at compile time
5. **Recoverability:** Errors distinguish recoverable vs fatal

---

## φ² + 1/φ² = 3 = TRINITY
