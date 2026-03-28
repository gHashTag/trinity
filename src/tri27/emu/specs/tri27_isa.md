# TRI-27 Instruction Set Architecture (ISA) Reference

## Overview

TRI-27 is a ternary RISC processor with:
- **27 ternary registers** (t0-t26): Store values in {-1, 0, +1} encoded as Trit27
- **8 GF16 registers** (f0-f7): 16-bit floating point values
- **16 vector registers** (v0-v15): Each is 16×GF16 for SIMD operations
- **32K words of memory**: Byte-addressable, 64-bit words
- **32-bit instructions**: Unified encoding for all operations
- **3 flag bits**: Z (zero), N (negative), V (overflow), H (halted)

## Register File

### Ternary Registers (t0-t26)
- Store Trit27 values: packed 27 trits into i64
- Trit27 range: -9841 to +9841 (3^27 possible values)
- Used for: general computation, operands, results

### GF16 Registers (f0-f7)
- 16-bit GF16 floating point format
- Used for: floating-point arithmetic, neural network weights

### Vector Registers (v0-v15)
- 16-element SIMD registers
- Each element: GF16 (16-bit float)
- Used for: SIMD operations, parallel processing

### Control Registers
- **PC** (Program Counter): 32-bit, instruction pointer
- **SP** (Stack Pointer): 32-bit, stack management
- **FP** (Frame Pointer): 32-bit, call frame management

### Flags Register (packed)
```
Bit 7: H - Halted flag
Bit 6: Reserved
Bit 5: V - Overflow flag
Bit 4: Reserved
Bit 3: Reserved
Bit 2: Reserved
Bit 1: N - Negative result flag
Bit 0: Z - Zero result flag
```

## Instruction Encoding

All TRI-27 instructions are **32 bits** with **hybrid encoding** that separates immediate instructions from 3-operand instructions.

### Hybrid Encoding Scheme

The instruction word uses different bit layouts depending on instruction type to avoid bit overlap:

```
┌─────────────────────────────────────────────────────┐
│ opcode (8) │ dst (5) │ [variant encoding] │
├──────────────┼───────────┼──────────────────────────┤
│ bits 7-0   │ bits 12-8 │ bits 13-31 (variant)     │
└─────────────────────────────────────────────────────┘
```

**For Immediate Instructions (LDI, STI, JMP, JZ, JNZ, JGT, JLT, CALL, SHL, SHR, etc.):**
```
┌──────────┬───────┬─────────────┬──────────────────┐
│ opcode(8)│ dst(5)│ src1(4)     │ immediate(15)    │
│ bits 7-0 │ 12-8  │ bits 16-13  │ bits 31-17       │
└──────────┴───────┴─────────────┴──────────────────┘
```
- **src1**: 4 bits (registers 0-15 only for immediate instructions)
- **immediate**: 15-bit signed value (-16384 to +16383)

**For 3-Operand Instructions (ADD, SUB, MUL, DIV, AND, OR, XOR):**
```
┌──────────┬───────┬─────────────┬──────────────────┐
│ opcode(8)│ dst(5)│ src1(5)     │ src2(5)          │
│ bits 7-0 │ 12-8  │ bits 17-13  │ bits 22-18       │
└──────────┴───────┴─────────────┴──────────────────┘
```
- **src1**: 5 bits (full register range 0-26)
- **src2**: 5 bits (full register range 0-26)

**For 2-Operand Instructions (MOV, NOT, INC, DEC):**
```
┌──────────┬───────┬─────────────┬──────────────────┐
│ opcode(8)│ dst(5)│ src1(5)     │ [reserved]       │
│ bits 7-0 │ 12-8  │ bits 17-13  │ bits 18-31       │
└──────────┴───────┴─────────────┴──────────────────┘
```
- **src1**: 5 bits (full register range 0-26)

### Why Hybrid Encoding?

The original encoding had src1 at bits 13-17 and immediate at bits 17-31, causing **bit 17 overlap**. This meant:
- When encoding an immediate instruction, src1 values ≥ 16 would corrupt the immediate sign bit
- The SHR instruction `SHR t0, t0, 16` would encode src1=16, setting bit 17 and corrupting the immediate value

The hybrid encoding fixes this by:
1. **Immediate instructions**: Use only 4 bits for src1 (bits 13-16), immediate at bits 17-31
2. **3-operand instructions**: Use full 5 bits for src1 (bits 13-17), src2 at bits 18-22

This eliminates the overlap while maintaining full register range for 3-operand instructions.

### Immediate Value Range

- **15-bit signed immediate**: -16384 to +16383
- **Sign extension**: Bit 31 of the instruction word is the sign bit
- **Clamping**: Values outside range are clamped during encoding

## Opcode Groups

### 1. Control Flow (0x40-0x4F)

| Opcode | Value | Description | Cycles |
|--------|--------|-------------|---------|
| NOP    | 0x00   | No operation | 1 |
| HALT   | 0x4D   | Halt execution, set H flag | 1 |
| JMP    | 0x40   | Unconditional jump to PC+imm | 1 |
| JZ     | 0x41   | Jump if Z flag set | 1 |
| JNZ    | 0x42   | Jump if Z flag clear | 1 |
| CALL   | 0x43   | Push return address, jump | 3 |
| RET    | 0x4B   | Pop return address, jump | 3 |

### 2. Memory Operations (0x02-0x05)

| Opcode | Value | Description | Cycles |
|--------|--------|-------------|---------|
| LD     | 0x02   | Load from memory address | 1 |
| LD_IMM | 0x84   | Load immediate value | 1 |
| ST     | 0x03   | Store to memory address | 2 |

### 3. Arithmetic Operations (0x10-0x17)

| Opcode | Value | Description | Cycles | Flags Affected |
|--------|--------|-------------|---------|---------------|
| ADD  | 0x10   | t[dst] = t[src1] + t[src2] | 2 | Z, N, V |
| SUB  | 0x11   | t[dst] = t[src1] - t[src2] | 2 | Z, N, V |
| INC  | 0x14   | t[dst] = t[dst] + 1 | 1 | Z, N |
| DEC  | 0x15   | t[dst] = t[dst] - 1 | 1 | Z, N |
| MUL  | 0x12   | t[dst] = t[src1] * t[src2] | 2 | Z, N |
| DIV  | 0x13   | t[dst] = t[src1] / t[src2] | 2 | Z, N |

### 4. Logical Operations (0x18-0x1D)

| Opcode | Value | Description | Cycles | Flags Affected |
|--------|--------|-------------|---------|---------------|
| AND  | 0x18   | t[dst] = t[src1] ∧ t[src2] | 1 | Z, N |
| OR   | 0x19   | t[dst] = t[src1] ∨ t[src2] | 1 | Z, N |
| XOR  | 0x1A   | t[dst] = t[src1] ⊕ t[src2] | 1 | Z, N |
| NOT  | 0x1B   | t[dst] = ¬t[src1] | 1 | Z, N |
| SHL  | 0x1C   | t[dst] = t[src1] << t[src2] | 1 | Z, N |
| SHR  | 0x1D   | t[dst] = t[src1] >> t[src2] | 1 | Z, N |

### 5. Ternary Operations (0x60-0x6D)

| Opcode | Value | Description | Cycles |
|--------|--------|-------------|---------|
| DOT     | 0x60   | t[dst] = t[src1] · t[src2] (dot product mod 19683) | 1 |
| BIND    | 0x61   | t[dst] = t[src1] ⊕ t[src2] (binding) | 1 |
| BUNDLE2 | 0x62   | t[dst] = majority(t[src1], t[src2]) | 1 |
| BUNDLE3 | 0x63   | t[dst] = majority(t[src1], t[src2], t[cond]) | 1 |

**Ternary Semantics:**
- **DOT**: Ternary dot product (mod 19683 for overflow)
- **BIND**: XOR-like binding operation
- **BUNDLE2**: If either operand is zero, return other; else (a+b)/2
- **BUNDLE3**: Returns first operand if two match; otherwise returns first

**BUNDLE3 Special Encoding:**
BUNDLE3 uses a special 3-operand encoding (not immediate):
- src1: bits 13-16 (4 bits, range 0-15)
- src2: bits 18-22 (5 bits, range 0-26)
- v3 (third source): bits 23-27 (5 bits, range 0-26, stored in `cond` field)

This encoding allows BUNDLE3 to access three source operands within 32 bits.

### 6. Sacred Constant Operations (0x80-0x92)

| Opcode | Value | Description | Cycles |
|--------|--------|-------------|---------|
| PHI_CONST | 0x80   | t[dst] = φ (phi) | 1 |
| PI_CONST  | 0x81   | t[dst] = π (pi) | 1 |
| E_CONST  | 0x82   | t[dst] = e (Euler) | 1 |
| SACR     | 0x83   | Sacred arithmetic (mode in imm) | 2 |

**Sacred Constants (as Trit27):**
- φ = 9842 (phi × 6075)
- π = 19088 (pi × 6075)
- e = 16514 (e × 6075)

**SACR Modes (imm bits 1-3):**
- 0: Addition (a + b)
- 1: Multiplication (a × b)
- 2: Division (a / b, error if b=0)
- 3: Power (a^b)
- 4: Sacred sine

### 7. System Operations (0x88)

| Opcode | Value | Description | Cycles |
|--------|--------|-------------|---------|
| SYSCALL | 0x88   | System call (delegate to OS handler) | 10 |

## Assembly Syntax

### Basic Instruction Format
```
<opcode> <dst>, <src1>[, <src2>][, <imm>]
```

### Examples
```asm
; Arithmetic
ADD t5, t1, t2       ; t5 = t1 + t2
SUB t5, t5, t1       ; t5 = t5 - t1

; Memory
LD  t0, [t1]          ; Load from address in t1
ST  [t0], t5           ; Store t5 to address in t0
LD_IMM t0, 42          ; Load immediate 42 into t0

; Control Flow
JMP 100                ; Jump to address 100
JZ 200                 ; Jump to 200 if Z flag set
CALL func_start          ; Call function at func_start
RET                     ; Return from call

; Ternary
DOT t3, t1, t2        ; t3 = t1 · t2
BIND t3, t1, t2        ; t3 = t1 ⊕ t2
BUNDLE2 t3, t1, t2     ; t3 = majority(t1, t2)

; Sacred Constants
PHI_CONST t0           ; t0 = φ
PI_CONST t1            ; t1 = π
E_CONST t2              ; t2 = e
```

### Labels and Directives
```asm
; Label definitions
my_func:
    NOP
    LD_IMM t0, 5
    ; ...
    RET

; Data directives
.data
    MY_CONSTANT: .tri 42
    ZERO: .tri 0
```

## Binary Format (.tbin)

TRI-27 programs are compiled to `.tbin` format containing:
1. **Header** (12 bytes): Magic, version, section count
2. **Code section** (variable length): 32-bit instructions in little-endian
3. **Data sections** (optional): Constant data
4. **Metadata** (optional): Debug symbols, comments

See [`tbin_format.md`](./tbin_format.md) for detailed binary specification.

## Memory Map

```
Address Range     | Description
----------------|------------------
0x0000 - 0x4BFF  | Code segment (19,456 instructions)
0x4C00 - 0x7FFF  | Data segment
0x8000 - 0xFFFF  | Stack / heap
```

## Calling Convention

- **t0-t3**: Scratch registers (caller-save)
- **t4-t7**: Argument registers
- **t8**: Return value register
- **t9-t26**: Callee-save registers

**Stack Frame Layout:**
```
[higher addresses]
    └─────────────
    Return addr
    └─────────────
    Arguments (t4-t7)
    └─────────────
    Saved regs (t9-t26)
    └─────────────
    [SP]           ← Stack pointer
[lower addresses]
```

## Performance Characteristics

| Operation | Latency | Throughput | Notes |
|-----------|----------|-------------|--------|
| ALU ops  | 2 cycles | 1/cycle | Pipelined |
| Memory LD | 1 cycle  | 1/cycle | Cached |
| Memory ST | 2 cycles | 1/cycle | Cached |
| Branch    | 1 cycle  | 1/cycle | Predicted |
| Call/Ret  | 3 cycles | 1/cycle | Stack ops |

## Security Considerations

- Memory bounds checking prevents buffer overflows
- Division by zero trap with SACR DIV mode
- Stack overflow/underflow detection in CALL/RET
- Halted flag prevents execution after error conditions

## Toolchain Support

- **Assembler**: `tri-asm` — .tri → .tbin
- **Disassembler**: `tri27 disassemble` — .tbin → .tri listing
- **Emulator**: `tri-emu` — Execute .tbin programs
- **Validator**: `tri27 validate` — Check .tri syntax

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0     | 2026-03-24 | Initial ISA reference, 36 opcodes documented |

---

**φ² + 1/φ² = 3 | TRINITY**
