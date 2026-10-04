# TRI-27 .tbin Binary Format Specification

## Overview

`.tbin` (TRI Binary) is the binary format for TRI-27 executable programs. It contains:
- Magic number and version information
- Code section with 32-bit instructions
- Optional sections for data, metadata

## Header Layout (12 bytes)

The container `tri_asm.zig` writes and `loader.load` reads: a six-byte main
header, a four-byte CODE section header, and two padding bytes. The first
instruction word starts at byte 12, which is word 3 of the fetch at `pc * 4`.

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 | Magic | `0x54524932` ("2IRT" little-endian) |
| 0x04 | 1 | Version | Format version (current: 1) |
| 0x05 | 1 | Section count | Number of sections |

### Magic Number
```
Hex: 0x54524932
ASCII: "2IRT" (stored little-endian)
Bytes: [0x32, 0x49, 0x52, 0x54]
```

## Code Section

### Section Header (4 bytes)
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 1 | Section ID | 1 = Code section |
| 0x01 | 1 | Padding | Reserved (0) |
| 0x02 | 2 | Size | Payload size in bytes (u16 little-endian) |

### Container Padding (2 bytes)
Two reserved bytes after the CODE section header align the payload to byte 12
(word 3). The loader skips them; a payload written without them loads shifted
by two bytes.

### Code Data (4 bytes per instruction)
All instructions are 32-bit words stored in **little-endian** byte order.
The loader packs each four payload bytes into one four-byte fetch unit at
byte `12 + i * 4`, so `run`'s fetch at `pc * 4` reads exactly one written word
per instruction, starting at `pc = 3`.

Byte layout:
```
Offset 0: byte0 (LSB of instruction)
Offset 1: byte1
Offset 2: byte2
Offset 3: byte3 (MSB of instruction)
```

To reconstruct a 32-bit instruction word:
```zig
const word_value: u32 =
    @as(u32, byte0) |
    @as(u32, byte1) << 8 |
    @as(u32, byte2) << 16 |
    @as(u32, byte3) << 24;
```

## Instruction Encoding (32-bit)

```
| 31..24 | 23..19 | 18..14 | 13..9 | 8..4 | 3..0 |
| opcode |  dst   |  src1  | src2  | cond | imm  |
|   8    |   5    |   5    |   5   |  5   |  4   |
```

- **opcode (8 bits)**: Operation type (see decoder.zig)
- **dst (5 bits)**: Destination register (t0-t31)
- **src1 (5 bits)**: First source register
- **src2 (5 bits)**: Second source register
- **cond (5 bits)**: Condition code OR third register (for BUNDLE3)
- **imm (4 bits)**: Immediate value (extended to 9 bits in Instruction struct)

### Special Cases

#### BUNDLE3 Encoding
For `BUNDLE3 t5, t0, t1, t2`:
- dst = t5
- src1 = t0
- src2 = t1
- cond = t2 (third operand, 5-bit register index)
- immediate = 0

#### Immediate Instructions
For instructions with immediate values:
- has_imm flag is set in the high-level Instruction struct
- The 9-bit immediate is encoded: 4 bits in imm field + extended from other fields

## Example: LDI t0, 42

Assembly:
```asm
LDI t0, 42
HALT
```

Binary representation:
```
Header:
[32 49 52 54]     # Magic "2IRT"
[01]              # Version 1
[01]              # 1 section

Code section header + padding:
[01 00 08 00]     # Section ID 1, padding, size 8 (u16 little-endian)
[00 00]           # Container padding to byte 12

Instructions (little-endian) at byte 12:
LDI t0, 42  ->  0x0000002A  # opcode=LDI, dst=t0, imm=42
HALT        ->  0x0000004D  # opcode=HALT

Full file (20 bytes):
32 49 52 54 01 01 01 00 08 00 00 00 2A 00 00 00 4D 00 00 00
```

## Constants Section

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 1 | Section ID | 2 = Constants |
| 0x01 | 1 | Count | Number of f64 constants |
| 0x02 | 8 * count | Data | One eight-byte value per constant |

The loader reads the id, then the count, then skips `count * 8` payload bytes;
the values themselves come from the `constants` array the caller passes, and
only the first three reach `cpu.f`.

## File Extension
- Source: `.tri` (assembly)
- Object: `.tbin` (binary executable)

## Loader Requirements

The loader must:
1. Verify magic number equals `0x54524932`
2. Check version compatibility (major version must match)
3. Read section count and iterate through sections
4. For code section (ID 0x04): load bytes into memory at word 0
5. Set PC = 0 (first instruction at memory address 0)

## Endianness Note
All multi-byte values in .tbin are stored in **little-endian** format to match common ISAs and simplify loader implementation.

## Version History

| Version | Changes |
|---------|---------|
| 1.0 | Initial format with magic + code |
| 1.1 | Added section-based format, version field |
