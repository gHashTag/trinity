# [EPIC] GF16/TF3 Arithmetic Unit на XC7A100T (Artix-7, 28nm)

**Labels:** `epic`, `fpga`, `hardware`, `priority:high`
**Milestone:** Sacred Formats Hardware
**Parent:** #357 (Training Farm Tracker)

---

## Goal

Implement and test a native hardware block for **GF16 (Golden Float 16)** and **TF3-9 (Ternary Float 9)** on FPGA XC7A100T (Artix-7, 28nm), with clean interfaces for Trinity.

> "Launch Sacred formats with Level 0 (hardware) to Level 6 (RTL)" — this is a key differentiator for Trinity against GPU-bound frameworks (PyTorch, JAX, TensorRT).

---

## Motivation

Trinity uses sacred number formats (GF16, TF3-9) for hardware-efficient computation. Running these formats natively on FPGA rather than emulating in software will provide:
- **Energy efficiency**: Hardware calculation is ~100x more efficient
- **Speed**: Dedicated arithmetic units (DSP48E1) for high throughput
- **Deterministic latency**: No OS scheduling overhead

---

## Specification

### Target Platform
| Parameter | Value |
|-----------|-------|
| FPGA | XC7A100T-1FGG676C (QMTECH) |
| Process | 28nm Artix-7 |
| Clock | 50 MHz (target) |
| Voltage | 3.3V logic levels |
| I/O | FGG676C package |

### Target Chip
| Parameter | Value |
|-----------|-------|
| FPGA | XC7A100T-1FGG676C (Artix-7, 28nm) |
| LUT | 126,800 total |
| FF | 190,800 total |
| BRAM | 270 36Kb total |
| DSP48E1 | 240 (available) |

---

## Implementation Phases

### Phase 1: GF16 Adder (4-stage pipeline)
- Stage 1: Decode (sign/exp, align exponents)
- Stage 2: Core add (mantissa addition)
- Stage 3: Normalize (shift result, adjust exponent)
- Stage 4: Round to nearest-even, pack to 16-bit

### Phase 2: GF16 Multiplier (DSP48E1 optional)
- Stage 1: Decode, multiply mantissas
- Stage 2: DSP48E1 for 18×18 multiply (6 cycles)
- Stage 3: Normalize, pack

### Phase 3: TF3-9 ALU (Arithmetic operations)
- Stage 1: Ternary decode (00=-1, 01=0, 10=+1)
- Stage 2: Arithmetic operations (add, sub, mul)
- Stage 3: Result encode

### Phase 4: Sacred ALU Wrapper
- Unified interface for GF16/TF3 operations
- φ-distance error checking

### Phase 5: Trinity Integration
- FPGABackend interface for calling operations
- Zig backend wrapper for hardware access

---

## Motivation

| Aspect | CPU (Software) | FPGA (Hardware) |
|---------|-----------------|-----------------|
| Energy | ~5W per operation | ~0.05W per operation |
| Latency | ~50ns (single op) | ~20ns (single op) |
| Throughput | ~20M ops/sec | ~100M ops/sec |
| Precision | IEEE 754 (binary64) | GF16 (10-bit exp, 6-bit mant) / TF3-9 (ternary) |

---

## Implementation Timeline

| Phase | Estimated Effort | Dependencies |
|-------|-----------------|-------------|
| Phase 1: GF16 Adder | 2-3 days | Phase 0 completed |
| Phase 2: GF16 Multiplier | 2-3 days | Phase 1 completed |
| Phase 3: TF3-9 ALU | 3-4 days | Phase 1,2 completed |
| Phase 4: Sacred ALU | 2-3 days | Phase 1-3 completed |
| Phase 5: Integration | 3-5 days | Phase 1-4 completed |
| **Total** | **12-18 days** |

---

## Architecture

```
┌─────────────────────────────────────┐
│                     FPGA Architecture                        │
├─────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────┐  │
│  │    GF16/TF3 Arithmetic Unit │  │
│  │  ┌─────────────────────┐   │  │
│  │  │                  │   │  │
│  │  │                  │   │  │
│  │  └─────────────────────┘   │  │
│  └───────────────────────────────┘   │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  │  ZIG BACKEND         │  │
│  │  └───────────────────────┘   │
└─────────────────────────────────────┘
```

### Data Path
1. **CPU → FPGA**: Write operands, read results via memory-mapped I/O
2. **FPGA → CPU**: Interrupt when operation complete (optional)

---

## Interfaces

### GF16/TF3 Operation Interface

```zig
pub const GF16Ops = enum {
    ADD,
    MUL,
    SUB,
    DIV,
    SQRT,
    TF3_ADD,
    TF3_MUL,
    TF3_SUB,
    SACRED_ALU,
};
```

### Trinity Integration

```zig
const trinity_backend = @import("fpga_backend.zig");

// GF16 operation
pub fn gf16Add(a: GoldenFloat16, b: GoldenFloat16) !GoldenFloat16 {
    return trinity_backend.call(GF16_ADD, @bitCast(operandBytes(a)), @bitCast(operandBytes(b)));
}

// TF3 operation
pub fn tf3Add(a: TernaryFloat9, b: TernaryFloat9) !TernaryFloat9 {
    return trinity_backend.call(TF3_ADD, @bitCast(operandBytes(a)), @bitCast(operandBytes(b)));
}
```

---

## File Structure

```
epic-gf16-tf3-fpga.md        # This file
src/hslm/intraparietal_sulcus.zig  # GF16/TF3 reference
fpga/openxc7-synth/
├── gf16_adder.v              # GF16 adder hardware
├── gf16_multiplier.v         # GF16 multiplier (DSP48E1)
├── tf3_alu.v                # TF3-9 ALU
├── sacred_alu.v              # Sacred format wrapper
└── trinity_top.v             # Integration top

tests/
├── gf16_adder_test.zig        # Software tests
├── tf3_alu_test.zig           # Software tests
└── sacred_alu_test.zig        # Software tests

docs/
├── positioning-zighalf-trinity.md  # Level 6 positioning
└── phi-distance-formats.md    # φ-distance analysis
```

---

## Success Criteria

| Criterion | Threshold | Status |
|-----------|----------|--------|
| GF16 adder passes all tests | 100% | ⬜ TBD |
| GF16 multiplier correct (≤1 LSB) | ≤ 1 LSB | ⬜ TBD |
| TF3 ALU correct (φ-distance ≤ 0.05) | ≤ 0.05 | ⬜ TBD |
| FPGA synthesis succeeds | No critical warnings | ⬜ TBD |
| FPGA timing met (≥100 MHz) | ≥ 100 MHz | ⬜ TBD |
| Integration tests pass | All | ⬜ TBD |

---

## Success Criteria

| Criterion | Threshold | Status |
|-----------|----------|--------|
| GF16 adder passes all tests | 100% | ⬜ TBD |
| GF16 multiplier correct (≤1 LSB) | ≤ 1 LSB | ⬜ TBD |
| TF3 ALU correct (φ-distance ≤ 0.05) | ≤ 0.05 | ⬜ TBD |
| FPGA synthesis succeeds | No critical warnings | ⬜ TBD |
| FPGA timing met (≥100 MHz) | ≥ 100 MHz | ⬜ TBD |
| Integration tests pass | All | ⬜ TBD |

---

## Known Issues

| Issue | Impact | Mitigation |
|-------|--------|------------|
| DSP48E1 availability | May not exist | Use LUTs for multiply if needed |
| Timing closure | Complex pipeline | Use pipelining |
| BRAM constraints | Need dual-port for read/write | Use two single-port BRAMs |

---

## References

- [Yosys documentation](https://yosyshq.readthedocs.io/)
- [Xilinx DSP48E1 user guide](https://www.xilinx.com/support/documentation/user_guides/ug479.pdf)
- [Trinity FPGA docs](../fpga/openxc7-synth/)
- [Sacred Math spec](../src/sacred/CHARTER.md)

---

*φ² + 1/φ² = 3 | TRINITY*
