# Trinity UART/FPGA Module

**Version:** 6.0 (Current: v6, v5 deprecated)
**Status:** Stable
**Location:** `fpga/openxc7-synth/`

---

## Purpose

The UART/FPGA module provides communication between host software and Xilinx 7-series FPGA hardware (QMTECH Artix-7 XC7A100T). It enables offloading of VSA operations (bind, bundle, similarity) to hardware for massive performance acceleration.

---

## Key Files

### Host Software (Zig)

| File | Purpose | Status |
|------|---------|--------|
| `uart_protocol.zig` | **Canonical** protocol definitions | ✅ Use this |
| `uart_vectors.zig` | 16-trit vector types and operations | ✅ Stable |
| `uart_host_v6_refactored.zig` | UART host v6.0 (1-byte length, improved CRC) | ✅ **Current** |
| `uart_host_v5_refactored.zig` | UART host v5.0 (2-byte length) | ⚠️ Legacy |
| `uart_correctness_tests.zig` | Protocol validation tests | ✅ Comprehensive |

### FPGA Verilog

| File | Purpose | Status |
|------|---------|--------|
| `vsa_coprocessor.v` | VSA operations in hardware (bind, bundle3, similarity) | ✅ Production |
| `uart_top.v` | UART transceiver + command decoder | ✅ Stable |
| `uart_bridge.v` | Host-FPGA bridge logic | ✅ Stable |
| `trinity_uart.v` | Legacy UART implementation | ⚠️ Deprecated |

### Test/Verification Files

| File | Purpose |
|------|---------|
| `vsa_correctness_tests.zig` | VSA math correctness (bundle3 truth table, etc.) |
| `test_*.v` | FPGA test benches for individual components |

---

## Public API

### uart_protocol.zig (Canonical Protocol)

```zig
const protocol = @import("uart_protocol.zig");

// === TRIT ENCODING (2-bit packed) ===
protocol.Trit.NEGATIVE    // 0b10 = -1
protocol.Trit.ZERO        // 0b00 = 0
protocol.Trit.POSITIVE    // 0b01 = +1

// === COMMANDS (Host → FPGA) ===
protocol.Command.MODE        // 0x01 - Set VSA mode
protocol.Command.BIND        // 0x02 - Bind two vectors
protocol.Command.BUNDLE      // 0x03 - Bundle vectors
protocol.Command.SIMILARITY  // 0x04 - Compute similarity
protocol.Command.BITNET      // 0x05 - BitNet operation
protocol.Command.PING        // 0xFF - Ping/PONG

// === RESPONSES (FPGA → Host) ===
protocol.Response.OK     // 0x00 - Success
protocol.Response.PONG   // 0xAA - Ping response

// === CRC-16/CCITT CHECKSUM ===
protocol.crc16Ccitt(data: []const u8) u16
// Polynomial: 0x1021, Initial: 0xFFFF
// Test: crc16Ccitt("123456789") == 0x29B1

// === PROTOCOL CONSTANTS ===
protocol.SYNC_BYTE       // 0xAA - Frame synchronization
protocol.BAUD_RATE       // 115200 - Default baud
protocol.TIMEOUT_MS      // 5000 - Operation timeout
protocol.VECTOR_SIZE     // 16 - Trits per vector
protocol.VECTOR_BYTES    // 4 - Bytes per packed vector
```

### uart_vectors.zig

```zig
const vectors = @import("uart_vectors.zig");

// === VECTOR TYPES ===
vectors.Vector16    // [16]Trit - Standard VSA vector
vectors.PackedVector4 // [4]u8 - Packed representation

// === VECTOR OPERATIONS ===
vectors.zeroVector() Vector16
vectors.randomVector(seed: u64) Vector16
vectors.tritToPacked(vec: Vector16) PackedVector4
vectors.packedToTrit(packed: PackedVector4) Vector16

// === TRIT CONVERSION ===
vectors.tritToInt(trit: Trit) i8  // -1, 0, +1
vectors.intToTrit(val: i8) Trit  // Clamps to valid trit
```

### uart_host_v6_refactored.zig (Current)

```zig
const uart = @import("uart_host_v6_refactored.zig");

// === HOST DEVICE ===
const UARTDevice = struct {
    // Initialize UART connection
    pub fn init(port: []const u8, baud: u32) !UARTDevice

    // Close connection
    pub fn deinit(self: *UARTDevice) void

    // === VSA OPERATIONS ===

    // Bind two vectors: result = a ⊗ b
    pub fn vsaBind(self: *UARTDevice, a: Vector16, b: Vector16) !Vector16

    // Bundle 3 vectors: result = majority(a, b, c)
    pub fn vsaBundle3(self: *UARTDevice, a: Vector16, b: Vector16, c: Vector16) !Vector16

    // Compute cosine similarity [-1, 1]
    pub fn vsaSimilarity(self: *UARTDevice, a: Vector16, b: Vector16) !f32

    // === PROTOCOL OPERATIONS ===

    // Send ping, wait for PONG
    pub fn ping(self: *UARTDevice) !void

    // Set VSA mode
    pub fn setMode(self: *UARTDevice, mode: u8) !void
};
```

---

## Protocol Specification

### Frame Format (v6 - Current)

```
┌────────┬───────────┬─────────────┬─────────┬────────────┐
│ SYNC   │ LENGTH    │ COMMAND     │ PAYLOAD│ CRC        │
│ (1B)   │ (1B)      │ (1B)        │ (0-255B)│ (2B)       │
├────────┼───────────┼─────────────┼─────────┼────────────┤
│ 0xAA   │ N bytes   │ CMD_ID      │ Data    │ CRC16/CCITT │
└────────┴───────────┴─────────────┴─────────┴────────────┘
```

### Frame Format (v5 - Legacy)

```
┌────────┬───────────┬─────────────┬─────────┬────────────┐
│ SYNC   │ LENGTH    │ COMMAND     │ PAYLOAD│ CRC        │
│ (1B)   │ (2B)      │ (1B)        │ (0-64KB)│ (2B)       │
├────────┼───────────┼─────────────┼─────────┼────────────┤
│ 0xAA   │ N bytes   │ CMD_ID      │ Data    │ CRC16/CCITT │
└────────┴───────────┴─────────────┴─────────┴────────────┘
```

**Difference:** v5 uses 2-byte length (legacy), v6 uses 1-byte length (current standard).

### Command: BIND (0x02)

**Request:**
| Offset | Size | Value | Description |
|--------|------|-------|-------------|
| 0 | 1 | 0xAA | Sync byte |
| 1 | 1 | 4 | Payload length |
| 2 | 1 | 0x02 | BIND command |
| 3 | 4 | PackedVecA | Vector A (16 trits) |
| 7 | 4 | PackedVecB | Vector B (16 trits) |
| 11 | 2 | CRC | Checksum |

**Response:**
| Offset | Size | Value | Description |
|--------|------|-------|-------------|
| 0 | 1 | 0xAA | Sync byte |
| 1 | 1 | 5 | Payload length |
| 2 | 1 | 0x00 | OK response |
| 3 | 4 | Result | A ⊗ B |
| 7 | 2 | CRC | Checksum |

### Command: SIMILARITY (0x04)

**Request:**
| Offset | Size | Value | Description |
|--------|------|-------|-------------|
| 0 | 1 | 0xAA | Sync byte |
| 1 | 1 | 4 | Payload length |
| 2 | 1 | 0x04 | SIMILARITY command |
| 3 | 4 | PackedVecA | Vector A |
| 7 | 4 | PackedVecB | Vector B |
| 11 | 2 | CRC | Checksum |

**Response:**
| Offset | Size | Value | Description |
|--------|------|-------|-------------|
| 0 | 1 | 0xAA | Sync byte |
| 1 | 1 | 5 | Payload length |
| 2 | 1 | 0x00 | OK response |
| 3 | 4 | Float32 | Similarity value |
| 7 | 2 | CRC | Checksum |

---

## Contracts

### Preconditions

**All operations:**
- UART device must be opened and initialized
- Baud rate must match FPGA configuration (default: 115200)
- Input vectors must be exactly 16 trits

**vsaBind:**
- Both vectors must have same dimension (16 trits)

**vsaBundle3:**
- All three vectors must have same dimension (16 trits)

**vsaSimilarity:**
- Both vectors must have same dimension (16 trits)

### Postconditions

**vsaBind:**
- Returns vector C where C[i] = A[i] × B[i] (trit multiplication)
- Result has same dimension as inputs

**vsaBundle3:**
- Returns vector with majority trit at each position
- Ties broken in order: NEGATIVE > ZERO > POSITIVE

**vsaSimilarity:**
- Returns value in range [-1.0, 1.0]
- 1.0 = identical vectors, -1.0 = opposite vectors, 0.0 = orthogonal

### Error Handling

All operations return error unions:
- `error.Timeout` - No response within TIMEOUT_MS
- `error.InvalidChecksum` - CRC mismatch
- `error.InvalidResponse` - Unexpected response code
- `error.DeviceNotFound` - UART port not found
- `error.VectorLengthMismatch` - Dimension mismatch (recoverable)

---

## Examples

### Example 1: Basic VSA bind operation

```zig
const std = @import("std");
const uart = @import("uart_host_v6_refactored.zig");
const vectors = @import("uart_vectors.zig");

pub fn main() !void {
    // Connect to FPGA
    var device = try uart.UARTDevice.init("/dev/ttyUSB0", 115200);
    defer device.deinit();

    // Create two random vectors
    const vec_a = vectors.randomVector(42);
    const vec_b = vectors.randomVector(137);

    // Bind on FPGA
    const bound = try device.vsaBind(vec_a, vec_b);

    std.debug.print("Bind operation complete\n", .{});
}
```

### Example 2: Batch similarity computation

```zig
const uart = @import("uart_host_v6_refactored.zig");
const vectors = @import("uart_vectors.zig");

pub fn findMostSimilar(query: Vector16, candidates: []const Vector16) !usize {
    var device = try uart.UARTDevice.init("/dev/ttyUSB0", 115200);
    defer device.deinit();

    var best_idx: usize = 0;
    var best_sim: f32 = -1.0;

    for (candidates, 0..) |candidate, i| {
        const sim = try device.vsaSimilarity(query, candidate);
        if (sim > best_sim) {
            best_sim = sim;
            best_idx = i;
        }
    }

    return best_idx;
}
```

### Example 3: Error handling with retry

```zig
const uart = @import("uart_host_v6_refactored.zig");
const errors = @import("common").errors;

pub fn bindWithRetry(device: *uart.UARTDevice, a: Vector16, b: Vector16) !Vector16 {
    var attempts: u32 = 0;
    while (attempts < 3) : (attempts += 1) {
        device.vsaBind(a, b) catch |err| {
            if (err == error.Timeout) {
                std.debug.print("Timeout, retrying...\n", .{});
                continue;
            }
            return err; // Non-recoverable
        };
        return device.vsaBind(a, b); // Success
    }
    return error.Timeout; // All retries failed
}
```

---

## Testing

### Run correctness tests

```bash
cd fpga/openxc7-synth
zig test uart_correctness_tests.zig
zig test vsa_correctness_tests.zig
```

**Coverage:**
- ✅ CRC-16/CCITT with known test vectors
- ✅ Command/Response enum validation
- ✅ Trit encoding/decoding
- ✅ Protocol constants
- ✅ Bundle3 complete truth table (27 combinations)
- ✅ Bind/unbind mathematical properties
- ✅ Similarity bounds checking

### Hardware testing

```bash
# Flash bitstream to FPGA
fpga/tools/flash_safe.sh vsa_coprocessor.bit

# Run hardware test
./zig-out/bin/vsa_fpga_test
```

---

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v6.0 | 2025-03 | 1-byte length, refactored protocol, improved CRC |
| v5.0 | 2025-02 | 2-byte length, expanded commands |
| v4.0 | 2025-01 | Initial UART protocol |
| v3.0 | 2024-12 | JTAG UART integration |
| v2.0 | 2024-11 | Basic VSA operations |
| v1.0 | 2024-10 | Initial implementation |

---

## Hardware Requirements

**FPGA:** QMTECH Artix-7 XC7A100T-1FGG676C
**JTAG:** Xilinx Platform Cable USB II (requires fxload firmware)
**Baud Rate:** 115200 (configurable)
**Timeout:** 5000ms (configurable)

### Pin Configuration (qmtech_fgg676.xdc)

```
set_property PACKAGE_PIN U22 [get_ports clk]       # 50 MHz oscillator
set_property PACKAGE_PIN T23 [get_ports led]       # Status LED
set_property PACKAGE_PIN ... [get_ports uart_rx]  # UART RX
set_property PACKAGE_PIN ... [get_ports uart_tx]  # UART TX
```

---

## Dependencies

**Internal:**
- `src/common/protocol.zig` - Protocol definitions (canonical source)
- `src/common/errors.zig` - Error types

**External:**
- `std` - Zig standard library
- Serial port device (Linux: `/dev/ttyUSB*`, macOS: `/dev/tty.usb*`)

---

## Troubleshooting

### "No USB probe found"
**Cause:** JTAG cable not initialized
**Fix:** Run `sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex`, then replug cable

### "Timeout on operation"
**Cause:** FPGA not programmed or wrong baud rate
**Fix:** Flash bitstream, verify baud rate matches

### "Invalid checksum"
**Cause:** CRC mismatch in protocol
**Fix:** Check frame length, verify CRC implementation

### "LED stuck ON"
**Cause:** FORGE toolchain bug (use openXC7 instead)
**Fix:** Use Docker openXC7 toolchain for synthesis

---

## Future Work

- [ ] Add streaming mode for batch operations
- [ ] Implement DMA for bulk transfers
- [ ] Add support for larger vector dimensions (256, 10K)
- [ ] Implement error correction codes
- [ ] Add performance counters

---

**φ² + 1/φ² = 3 = TRINITY**
