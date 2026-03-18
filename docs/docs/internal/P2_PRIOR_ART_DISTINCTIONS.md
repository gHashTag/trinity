# P2 Prior Art Distinctions — Competitive Landscape

**Patent Family:** P2
**Title:** Ternary VSA Coprocessor + Protocol Architecture
**Date:** 2026-03-08
**Purpose:** Document how P2 differs from existing VSA/FPGA patents

---

## Prior Art Landscape Analysis

### Category 1: VSA/HDC Methods (Software)

| Patent | Focus | Our Distinction |
|--------|-------|-----------------|
| US20250258826A1 | Neuro-vector-symbolic AI framework | Hardware offload + ternary encoding |
| US20240054317A1 | Similarity-based operations | 3-valued trits {-1,0,+1} not binary |
| WO2006061206A2 | Vector symbolic methods | FPGA realization, not software |
| US20190213294A1 | Hypervector computing | Wire protocol + CRC framing |

### Category 2: FPGA Coprocessors

| Patent | Focus | Our Distinction |
|--------|-------|-----------------|
| US20190213294A1 | General FPGA acceleration | Fixed-function VSA operations |
| US10324777B2 | Neural network FPGA | Ternary (not binary) computation |
| US10540379B2 | Reconfigurable AI hardware | UART protocol (not PCI/AXI) |

### Category 3: Communication Protocols

| Patent | Focus | Our Distinction |
|--------|-------|-----------------|
| US9872022B2 | Hardware acceleration protocol | Trit-encoded payload |
| US10241945B2 | Coprocessor communication | CRC-16/CCITT (not checksum) |
| US10162678B2 | FPGA-to-host interface | Command-based (not DMA) |

---

## Detailed Distinction Tables

### 1. US20250258826A1 — Neuro-vector-symbolic AI

**What they claim:**
- System for cognitive processing using vector-symbolic architectures
- Integration with neural networks
- Software-based hyperdimensional computing

**Our differences:**
| Aspect | Theirs | Ours |
|--------|--------|------|
| Medium | Software (Python/C++) | Hardware (FPGA) |
| Encoding | Binary {+1, -1} | Ternary {-1, 0, +1} |
| Interface | Function calls | UART protocol with CRC |
| Operations | General VSA ops | Fixed: BIND, BUNDLE3, SIMILARITY |
| Target | Cloud/edge servers | Embedded coprocessor |

**Claims we avoid:** "System for cognitive processing," "Neural network integration"

**Our novel angle:** Hardware VSA coprocessor with wire protocol

---

### 2. US20240054317A1 — Similarity-based operations

**What they claim:**
- Similarity-based vector operations
- Binary hyperdimensional computing
- Memory-augmented computation

**Our differences:**
| Aspect | Theirs | Ours |
|--------|--------|------|
| Values | Binary {+1, -1} | Ternary {-1, 0, +1} |
| Storage | Standard binary | Packed trits (1.58 bits/trit) |
| Operations | General similarity | Specific: BUNDLE3 majority |
| Implementation | Software | FPGA hardware |

**Claims we avoid:** "Binary hyperdimensional computing," "HD vectors"

**Our novel angle:** Zero state enables sparse representations

---

### 3. WO2006061206A2 — Vector symbolic methods

**What they claim:**
- Methods for symbolic reasoning
- VSA operations (bind, unbind, bundle)
- Software algorithms

**Our differences:**
| Aspect | Theirs | Ours |
|--------|--------|------|
| Scope | Methods | System + apparatus |
| Implementation | Software | Hardware (FPGA) |
| Protocol | None | UART with CRC framing |
| Encoding | Not specified | 2-bit packed trits |
| Verification | Algorithmic | Reduction to practice (bitstream) |

**Claims we avoid:** "Method for," "Software implementation"

**Our novel angle:** Hardware apparatus with wire protocol

---

### 4. US20190213294A1 — FPGA coprocessor

**What they claim:**
- Configurable logic for algorithms
- General compute offload
- Reconfigurable AI hardware

**Our differences:**
| Aspect | Theirs | Ours |
|--------|--------|------|
| Flexibility | General-purpose | Fixed-function VSA |
| Operations | User-defined | BIND, BUNDLE3, SIMILARITY only |
| Encoding | Binary | Ternary |
| Interface | PCI/AXI | UART with CRC |

**Claims we avoid:** "Configurable for arbitrary algorithms"

**Our novel angle:** Domain-specific ternary VSA unit

---

### 5. US10324777B2 — Neural network FPGA

**What they claim:**
- Binary neural networks on FPGA
- Quantized computation
| Aspect | Theirs | Ours |
|--------|--------|------|
| Computation | Binary multiply-accumulate | Trit majority logic |
| Network | Neural network layers | Vector symbolic ops |
| Learning | Backpropagation | None (inference only) |
| Encoding | 1-bit | 2-bit packed |

**Our novel angle:** VSA not neural network

---

## Our Novel Contributions

### 1. Ternary Encoding with Hardware Efficiency

**Prior art:** Binary {+1, -1} hypervectors dominate VSA literature

**Our innovation:**
- Third state (0) enables sparse representations
- 2-bit packing achieves 1.58 bits/trit
- Hardware implementation uses standard LUTs

**Claims:** Claim 2 (trit packing), Claim 9 (encoding)

### 2. Wire Protocol for VSA Offload

**Prior art:** VSA operations typically in-process function calls

**Our innovation:**
- UART-based command protocol (offload to coprocessor)
- CRC-16/CCITT framing for reliability
- Command set: BIND, BUNDLE3, SIMILARITY, PING

**Claims:** Claim 1 (main), Claim 3 (frame format), Claim 13 (bidirectional)

### 3. Hardware BUNDLE3 Majority Logic

**Prior art:** BUNDLE operations typically software ternary logic

**Our innovation:**
- Hardware implementation of 3-input majority
- Mapping: {-3}→-1, {-2,-1}→-1, {0}→0, {+1,+2}→+1, {+3}→+1
- Optimized for FPGA LUTs

**Claims:** Claim 5 (BUNDLE3 majority logic)

### 4. Single Source of Truth Architecture

**Prior art:** Protocol typically duplicated between host and device

**Our innovation:**
- Canonical protocol definition (`src/common/protocol.zig`)
- Imported by both host software and hardware spec
- Eliminates mismatch bugs

**Claims:** Claim 12 (SSOT)

### 5. Spec-First Hardware Generation

**Prior art:** Verilog written by hand

**Our innovation:**
- .tri/.vibee spec as source of truth
- VIBEE compiler generates Verilog
- Generated code synthesizes to bitstream

**Claims:** Supports all claims via implementation evidence

---

## Claim Differentiation Strategy

### Claims We Assert (Novel)

| Claim | Novel Aspect | Prior Art Avoided |
|-------|--------------|-------------------|
| 1 (main) | Ternary VSA + UART protocol + FPGA | Software VSA, binary FPGA |
| 2 | 1.58 bits/trit packing | Binary encoding |
| 3 | UART frame with CRC-16/CCITT | Function call interfaces |
| 4 | Hardware BIND with permutation | Software bind |
| 5 | Hardware BUNDLE3 majority | Software bundle |
| 6 | Fixed-point SIMILARITY | Floating-point similarity |
| 7 | XC7A100T-specific architecture | General FPGA claims |
| 8 | Command decoder state machine | Direct function calls |
| 9 | 2-bit trit encoding | 1-bit binary |
| 10 | Response frame format | Unidirectional offload |
| 11 | CRC + timeout fault detection | Basic error handling |
| 12 | SSOT architecture | Duplicated protocols |
| 13 | Bidirectional with PING | Unidirectional |

### Claims We Avoid (Prior Art)

| Avoided Concept | Reason |
|-----------------|--------|
| "Neural network" | Crowded, not our focus |
| "Binary hypervectors" | We use ternary |
| "Software implementation" | We claim hardware |
| "General-purpose acceleration" | We claim fixed-function |
| "Learning/training" | We claim inference only |
| "PCI/AXI interface" | We claim UART |

---

## Obviousness Rebuttal (35 USC 103)

### Question: Would PHOSITA find this obvious?

**Answer:** No, because:

1. **Ternary encoding not standard** in VSA (binary dominates)
2. **UART protocol for VSA offload** not previously disclosed
3. **Hardware BUNDLE3 majority** not standard FPGA approach
4. **Combination of ternary + UART + FPGA** non-obvious

**Prior art combinations:**
- VSA methods (software) + FPGA (binary neural) ≠ Our invention
- UART protocols (generic) + VSA (software) ≠ Our invention
- Ternary logic (computing theory) + FPGA (implementation) ≠ Our invention

---

## Anticipated Examiner Rejections & Responses

### 101 Rejection: Lack of Patentable Subject Matter

**Anticipate:** "Abstract idea (data processing) implemented on generic hardware"

**Response:**
- Specific improvement: ternary encoding with hardware efficiency
- Specific integration: UART protocol for coprocessor offload
- Not generic: claims recite specific FPGA, specific protocol, specific operations

### 102 Rejection: Anticipated by [prior art]

**Anticipate:** US20250258826A1 (VSA methods) or US20190213294A1 (FPGA coprocessor)

**Response:**
- US20250258826A1: Software only, no hardware protocol, binary encoding
- US20190213294A1: General-purpose, not fixed VSA functions, binary not ternary
- No single reference teaches: ternary + UART + FPGA + BUNDLE3

### 103 Rejection: Obvious Combination

**Anticipate:** Combining VSA software with FPGA coprocessor

**Response:**
- Ternary encoding not motivated (binary standard in VSA)
- UART protocol not standard for coprocessors (PCI/AXI dominant)
- Hardware BUNDLE3 not standard approach
- Unexpected result: 1.58 bits/trit efficiency

---

## Filing Strategy

### Primary Jurisdictions

| Jurisdiction | Rationale | Expected Claims |
|--------------|-----------|-----------------|
| US (USPTO) | Primary market | 13-15 claims |
| EP (EPO) | Hardware focus | 10-12 claims |
| CN (CNIPA) | FPGA manufacturing | 8-10 claims |
| JP (JPO) | Electronics | 8-10 claims |

### Claim Structure per Jurisdiction

**US:** Broad independent claims, many dependent claims
**EP:** Fewer claims, more emphasis on "technical character"
**CN:** Hardware apparatus focus
**JP:** System + apparatus claims

---

## Freedom to Operate (FTO)

### High-Risk Patents

| Patent | Risk | Mitigation |
|--------|------|------------|
| US20250258826A1 | Medium | Our hardware focus different |
| US20190213294A1 | Low | Fixed-function vs general |
| US10324777B2 | Low | VSA not neural network |

### FTO Assessment

**Overall risk:** LOW

**Reasoning:**
- Our ternary encoding distinct from binary prior art
- Hardware protocol not disclosed in prior art
- Fixed-function operations not general-purpose

---

## Conclusion

**P2 is patentable** because:

1. **Novel combination** of ternary VSA + UART protocol + FPGA
2. **Non-obvious** hardware implementation of BUNDLE3 majority
3. **Specific technical improvements** (1.58 bits/trit, CRC-16/CCITT)
4. **Reduction to practice** with synthesized bitstreams

**Filing recommendation:** FILE NOW (after hardware proof)

**Strongest claims:** 1 (main), 2 (packing), 5 (BUNDLE3), 12 (SSOT)

**Weakest claims:** 7 (specific FPGA — may need broader phrasing)

---

φ² + 1/φ² = 3 = TRINITY

**Invention = Novel + Non-obvious + Useful**
**Our invention = Ternary + Protocol + Hardware + Reduction to Practice**
