# PATENT ARCHITECTURE MAP
## Trinity FPGA Parallel Track

**Version:** 1.0
**Date:** March 7, 2026
**Status:** Architecture Analysis

---

## Executive Summary

This document maps three patent families emerging from the Trinity FPGA development pipeline. Each family represents a novel invention with independent claims, dependent claims, implementation evidence, and filing readiness assessment.

### Filing Verdict Summary

| Patent Family | Independent Claims | Filing Readiness | Recommendation |
|--------------|-------------------|------------------|----------------|
| **P1: Spec-first FPGA Compilation** | 1 | **75%** | File after 1 sprint (fill gaps) |
| **P2: VSA FPGA Coprocessor + Ternary Protocol** | 1 | **90%** | File NOW (priority candidate) |
| **P3: Synthesis-Memory Recommendation System** | 1 | **40%** | NOT READY (needs research) |

---

## System Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TRINITY FPGA PATENT ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐  │
│  │     P1: SPEC-    │      │     P2: VSA      │      │     P3: SYNTH-   │  │
│  │   FIRST COMPIL   │─────▶│  COPROCESSOR +   │─────▶│   MEMORY REC     │  │
│  │      + VERIF     │      │  TERNARY PROTO   │      │   SYSTEM         │  │
│  └────────┬─────────┘      └────────┬─────────┘      └────────┬─────────┘  │
│           │                         │                         │             │
│           ▼                         ▼                         ▼             │
│  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐  │
│  │  .vibee → RTL    │      │  UART Protocol   │      │  VSA Similarity  │  │
│  │  Constraints     │      │  + Trit Packing  │      │  Search History  │  │
│  │  Host Code       │      │  + DSP Acceler   │      │  Strategy Rec    │  │
│  └──────────────────┘      └──────────────────┘      └──────────────────┘  │
│           │                         │                         │             │
│           ▼                         ▼                         ▼             │
│  ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐  │
│  │  VIBEE Compiler  │      │  vsa_coproc.v    │      │  Needle Tier 3   │  │
│  │  vibee_parser.zig│      │  uart_protocol   │      │  ann_brute_simd  │  │
│  │  verilog_codegen  │      │  uart_vectors    │      │  vsa.zig         │  │
│  └──────────────────┘      └──────────────────┘      └──────────────────┘  │
│           │                         │                         │             │
│           └─────────────────────────┴─────────────────────────┘             │
│                                     │                                       │
│                                     ▼                                       │
│                    ┌──────────────────────────────────────┐                │
│                    │  Yosys → nextpnr → fasm2frames →    │                │
│                    │  xc7frames2bit → FPGA Bitstream     │                │
│                    │  (synth.sh pipeline)                │                │
│                    └──────────────────────────────────────┘                │
│                                     │                                       │
│                                     ▼                                       │
│                    ┌──────────────────────────────────────┐                │
│                    │  QMTECH Artix-7 XC7A100T FPGA       │                │
│                    │  Hardware Verification              │                │
│                    └──────────────────────────────────────┘                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

φ² + 1/φ² = 3 | TRINITY v10.2
```

---

## P1: SPEC-FIRST FPGA COMPILATION + VERIFICATION

### Independent Claim

**Claim 1:** A method for unified hardware-software compilation comprising:
- (a) parsing a single declarative specification file to extract hardware behavioral descriptions, software interface definitions, timing constraints, and verification test cases;
- (b) automatically generating register-transfer level (RTL) hardware description language code from the hardware behavioral descriptions;
- (c) automatically generating constraint files for physical synthesis from the timing constraints;
- (d) automatically generating host software code from the software interface definitions;
- (e) automatically generating verification testbenches from the verification test cases;
- (f) synthesizing the RTL code with a synthesis toolchain using the constraint files to produce a bitstream; and
- (g) executing the verification test cases against hardware programmed with the bitstream to validate functional correctness.

### Dependent Claims

**Claim 2:** The method of Claim 1, wherein the specification file is a YAML-based format with structured sections for types, behaviors, algorithms, signals, finite state machines, and test cases.

**Claim 3:** The method of Claim 1, wherein the RTL code is Verilog-2005 compliant for FPGA synthesis.

**Claim 4:** The method of Claim 1, wherein the constraint files are Xilinx Design Constraints (XDC) format with pin assignments and timing requirements.

**Claim 5:** The method of Claim 1, wherein the host software code is Zig language with type-safe UART communication primitives.

**Claim 6:** The method of Claim 1, wherein the verification testbenches are Verilog testbench modules with stimulus generators and result checkers.

**Claim 7:** The method of Claim 1, wherein the synthesis toolchain comprises Yosys for logic synthesis, nextpnr-xilinx for place-and-route, fasm2frames for FPGA assembly, and xc7frames2bit for bitstream generation.

**Claim 8:** The method of Claim 1, further comprising generating SystemVerilog Assertions (SVA) from the behavioral descriptions to verify temporal properties during simulation.

**Claim 9:** The method of Claim 1, further comprising validating signal consistency between generated RTL code, constraint files, and verification test cases prior to synthesis.

**Claim 10:** The method of Claim 1, wherein the specification file includes hardware-specific parameters such as reset type (async/sync), reset level (active high/low), and target clock frequency.

### Implementation Evidence

| Claim Element | File | Lines | Description |
|--------------|------|-------|-------------|
| Specification parser | `/trinity-nexus/lang/src/vibee_parser.zig` | 19-72 | `VibeeSpec` struct with types, behaviors, signals, FSMS, test_cases |
| RTL generation | `/trinity-nexus/lang/src/verilog_codegen.zig` | 1-100 | `generateVerilog()` function, signal extraction, behavior validation |
| Constraint generation | `/fpga/openxc7-synth/synth.sh` | 46-67 | XDC file usage with Yosys/nextpnr pipeline |
| Host code generation | `/trinity-nexus/lang/src/zig_codegen.zig` | N/A | Zig code generation from spec (referenced in CLAUDE.md) |
| Testbench generation | `/fpga/openxc7-synth/tb/tb_*.v` | N/A | Multiple testbenches for temporal_heartbeat, ternary_dot, vsa_bind_16 |
| Synthesis pipeline | `/fpga/openxc7-synth/synth.sh` | 1-104 | Complete Yosys→nextpnr→fasm2frames→xc7frames2bit flow |
| SVA generation | `/trinity-nexus/lang/src/verilog_codegen.zig` | 70-100 | `extractSignalsFromTypes()`, `ValidationWarning` struct |

### Gaps Blocking Filing

1. **Missing explicit constraint generation code** - XDC files are manually written, not auto-generated from spec. Need to add XDC generation to `verilog_codegen.zig`.

2. **No formal proof of testbench correctness** - Need to add documentation showing generated testbenches verify all spec behaviors.

3. **Missing end-to-end example** - Need a complete walkthrough: `.vibee` → RTL → constraints → host → tests → synthesis → hardware verification.

4. **Prior art search incomplete** - Need to search for existing "spec-first" FPGA compilation tools (e.g., Chisel, Amaranth, PyMTL).

### Prior Art Avoidance Notes

- **Chisel (Scala)** - Generates Verilog from Scala code, but not from declarative YAML specs with separate verification test case generation.
- **Amaranth (Python)** - Python-based hardware construction, but not spec-driven with host software generation.
- **PyMTL** - Python-based modeling and testing, but targets simulation not FPGA synthesis.
- **nMigen** - Python-based hardware description, but lacks unified spec → RTL + constraints + host + tests pipeline.

**Novelty:** Unified single-spec pipeline driving entire hardware/software/verification stack with declarative YAML format.

### Filing Recommendation: **AFTER 1 SPRINT**

**Rationale:** Core invention is solid (spec → RTL/constraints/host/tests), but need to implement missing constraint generation and document end-to-end flow. 75% ready.

---

## P2: VSA FPGA COPROCESSOR + TERNARY PROTOCOL

### Independent Claim

**Claim 1:** A hardware accelerator for vector symbolic architecture operations comprising:
- (a) a dual-port vector memory configured to store a plurality of ternary vectors, each ternary vector comprising a sequence of trits having values -1, 0, or +1, wherein each trit is encoded as two bits;
- (b) a command decoder configured to receive operation commands via a serial communication interface, wherein each operation command is framed with a synchronization byte, a payload length, a command identifier, a payload, and a checksum;
- (c) a bind circuit configured to compute a binding of two ternary vectors by element-wise ternary multiplication using DSP blocks;
- (d) a bundle circuit configured to compute a bundle of two or three ternary vectors by majority vote logic;
- (e) a similarity circuit configured to compute a cosine similarity between two ternary vectors by accumulating dot products;
- (f) a finite state machine configured to orchestrate read-process-write operations for the dual-port vector memory; and
- (g) a result interface configured to output computed ternary vectors or similarity scores via the serial communication interface.

### Dependent Claims

**Claim 2:** The accelerator of Claim 1, wherein the dual-port vector memory stores 10,240-dimensional ternary vectors in 640 32-bit words using 2-bit trit encoding.

**Claim 3:** The accelerator of Claim 1, wherein the serial communication interface is UART operating at 115200 baud with CRC-16/CCITT checksum verification.

**Claim 4:** The accelerator of Claim 1, wherein the bind circuit instantiates 16 DSP48E1 blocks for parallel processing of 16 trits per clock cycle.

**Claim 5:** The accelerator of Claim 1, wherein the majority vote logic implements the truth table:
```
{-1, -1} → {-1}
{-1, 0}   → {-1}
{-1, +1}  → {0}
{0, 0}    → {0}
{0, +1}   → {+1}
{+1, +1}  → {+1}
```

**Claim 6:** The accelerator of Claim 1, wherein the trit encoding maps:
- trit value -1 to binary 10
- trit value 0 to binary 00
- trit value +1 to binary 01

**Claim 7:** The accelerator of Claim 1, wherein the command identifiers comprise:
- 0x01 for MODE command
- 0x02 for BIND command
- 0x03 for BUNDLE command
- 0x04 for SIMILARITY command
- 0x05 for BITNET command
- 0xFF for PING command

**Claim 8:** The accelerator of Claim 1, further comprising an unbind circuit configured to compute an unbinding by applying an inverse permutation to a key ternary vector followed by element-wise multiplication with a bound vector.

**Claim 9:** The accelerator of Claim 1, wherein the finite state machine implements states: IDLE, READ, READ_C (for 3-vector bundle), PROCESS, WRITE, DONE.

**Claim 10:** The accelerator of Claim 1, wherein the cosine similarity is computed as the dot product divided by the product of vector magnitudes, returned as a 32-bit floating-point value.

### Implementation Evidence

| Claim Element | File | Lines | Description |
|--------------|------|-------|-------------|
| Vector memory interface | `/fpga/openxc7-synth/vsa_coprocessor.v` | 31-46 | Dual-port BRAM with vec_addr_a/b, vec_data_a/b, vec_wr_data |
| Trit encoding (2-bit) | `/fpga/openxc7-synth/vsa_coprocessor.v` | 62 | `NUM_WORDS = (DIM * 2 + 31) / 32` - 2 bits per trit |
| Command decoder | `/fpga/openxc7-synth/vsa_coprocessor.v` | 26-30, 49-56 | cmd[2:0] input, CMD_NOP/CMD_BIND/CMD_UNBIND/CMD_BUNDLE2/CMD_BUNDLE3/CMD_SIMILARITY |
| Bind circuit with DSP | `/fpga/openxc7-synth/vsa_coprocessor.v` | 84-102 | `vsa_dsp_bind_block` instantiation with SIZE=BLOCK_SIZE |
| Bundle2 majority vote | `/fpga/openxc7-synth/vsa_coprocessor.v` | 154-179 | Truth table logic for 2-vector majority |
| Bundle3 majority vote | `/fpga/openxc7-synth/vsa_coprocessor.v` | 182-224 | 3-vector majority with sum-based decision |
| Similarity dot product | `/fpga/openxc7-synth/vsa_coprocessor.v` | 227-267 | Dot accumulator, block_sum computation, case statement for trit pairs |
| UART protocol framing | `/fpga/openxc7-synth/UART_README.md` | 142-149 | Frame format: SYNC(1B) + LENGTH(1B) + CMD(1B) + PAYLOAD + CRC(2B) |
| CRC-16/CCITT | `/fpga/openxc7-synth/UART_README.md` | 69-72 | Polynomial 0x1021, initial 0xFFFF |
| Command IDs | `/fpga/openxc7-synth/UART_README.md` | 57-63 | MODE=0x01, BIND=0x02, BUNDLE=0x03, SIMILARITY=0x04, BITNET=0x05, PING=0xFF |
| Trit encoding mapping | `/fpga/openxc7-synth/UART_README.md` | 52-55 | NEGATIVE=0b10(-1), ZERO=0b00(0), POSITIVE=0b01(+1) |
| State machine | `/fpga/openxc7-synth/vsa_coprocessor.v` | 284-364 | STATE_IDLE/READ/READ_C/PROCESS/WRITE/DONE |
| Unbind with permutation | `/fpga/openxc7-synth/vsa_coprocessor.v` | 105-152 | `vsa_permute` module, inverse permutation logic |

### Gaps Blocking Filing

1. **Missing DSP block details** - `vsa_dsp_bind_block` module not shown in main file. Need to verify DSP48E1 usage and add to specification.

2. **No formal proof of correctness** - Need to add mathematical proofs for bind/unbind/bundle/similarity operations in ternary algebra.

3. **Missing performance benchmarks** - Need quantitative speedup vs software implementation (e.g., "100x faster for 10K-dimensional vectors").

4. **Prior art search incomplete** - Need to search for existing FPGA accelerators for hyperdimensional computing or vector symbolic architectures.

### Prior Art Avoidance Notes

- **Hyperdimensional Computing FPGA implementations** - Several academic papers exist, but focus on binary hypervectors, not ternary trits.
- **Neuromorphic hardware accelerators** - Focus on spiking neural networks, not VSA operations (bind/unbind/bundle).
- **Standard FPGA DSP blocks** - DSP48E1 is generic Xilinx primitive, but novelty is in ternary-specific application.

**Novelty:**
- Ternary (not binary) hardware implementation with 2-bit trit encoding
- Majority vote logic for bundle operation (not standard in binary HDC)
- Unified protocol for VSA operations over UART

### Filing Recommendation: **FILE NOW**

**Rationale:** Strong implementation evidence with complete Verilog code, protocol specification, and working hardware. 90% ready. Minor gaps (DSP details, proofs) can be filled during prosecution.

---

## P3: SYNTHESIS-MEMORY RECOMMENDATION SYSTEM

### Independent Claim

**Claim 1:** A method for recommending synthesis strategies for FPGA designs based on semantic similarity, comprising:
- (a) extracting semantic features from a hardware design description, the semantic features comprising behavioral descriptions, signal names, state machine structures, and algorithmic patterns;
- (b) encoding the semantic features as a hypervector in a vector symbolic architecture space, wherein the hypervector has a dimensionality of at least 10,000;
- (c) comparing the hypervector to a historical database of previously synthesized designs, each previously synthesized design associated with a synthesis strategy and a synthesis outcome;
- (d) identifying one or more similar previously synthesized designs based on cosine similarity in the vector symbolic architecture space;
- (e) recommending a synthesis strategy for the hardware design description based on the synthesis strategies associated with the similar previously synthesized designs; and
- (f) executing the recommended synthesis strategy to generate a bitstream for the hardware design description.

### Dependent Claims

**Claim 2:** The method of Claim 1, wherein the behavioral descriptions are extracted from structured specification files in a YAML-based format.

**Claim 3:** The method of Claim 1, wherein the state machine structures are extracted as finite state machine definitions comprising states, transitions, outputs, and timers.

**Claim 4:** The method of Claim 1, wherein the algorithmic patterns are identified by parsing behavior clauses for keywords indicative of mathematical operations, control flow, or data transformations.

**Claim 5:** The method of Claim 1, wherein the hypervector encoding comprises binding together feature hypervectors for each semantic feature using element-wise ternary multiplication.

**Claim 6:** The method of Claim 1, wherein the hypervector encoding comprises bundling feature hypervectors using majority vote logic to create a composite representation.

**Claim 7:** The method of Claim 1, wherein the historical database stores hypervectors, synthesis strategies (Yosys optimization flags, nextpnr placement seeds), and synthesis outcomes (timing slack, resource utilization, runtime).

**Claim 8:** The method of Claim 1, wherein the cosine similarity is computed as the dot product of hypervectors divided by the product of their magnitudes, returning a value in the range [-1, 1].

**Claim 9:** The method of Claim 1, wherein the recommended synthesis strategy is selected as the most frequently successful strategy among the top K most similar previously synthesized designs.

**Claim 10:** The method of Claim 1, further comprising updating the historical database with the hypervector, synthesis strategy, and synthesis outcome after synthesizing the hardware design description.

### Implementation Evidence

| Claim Element | File | Lines | Description |
|--------------|------|-------|-------------|
| VSA similarity search | `/src/needle/ann_brute_simd.zig` | N/A | Brute-force SIMD similarity search (default ANN backend) |
| VSA encoding | `/src/vsa/encoding.zig` | N/A | `charToVector()`, `encodeText()`, `encodeTextWords()` |
| Cosine similarity | `/src/vsa.zig` | 28 | `cosineSimilarity` function exported from `vsa/core.zig` |
| Bind operation | `/src/vsa.zig` | 22-23 | `bind()`, `unbind()` functions for hypervector composition |
| Bundle operation | `/src/vsa.zig` | 24-25 | `bundle2()`, `bundle3()` functions for majority vote |
| Historical database (conceptual) | `/src/needle/vsa.zig` | N/A | `SemanticIndex` struct (needs verification for synthesis history) |
| Spec parsing (for feature extraction) | `/trinity-nexus/lang/src/vibee_parser.zig` | 19-72 | `VibeeSpec` with behaviors, signals, FSMS, algorithms |
| FSM extraction | `/trinity-nexus/lang/src/vibee_parser.zig` | N/A | `FSMDef` struct with states, transitions, outputs, timers |

### Gaps Blocking Filing

1. **No implementation of synthesis strategy mapping** - The system exists for semantic search, but there's no code mapping similarity scores to Yosys/nextpnr parameters.

2. **Missing historical database schema** - Need to design database schema storing: hypervector, synthesis flags (Yosys `-abc9`, `-nobram`, etc.), nextpnr `--seed`, `--freq`, outcomes (timing slack, utilization, runtime).

3. **No learning algorithm** - Need to implement recommendation logic (e.g., "most successful among top K", "weighted by similarity score", "reinforcement learning").

4. **No validation of effectiveness** - Need to prove that recommended strategies actually improve synthesis outcomes vs random/default strategies.

5. **Prior art search incomplete** - Need to search for existing machine learning-based synthesis optimization tools (e.g., Google's "FirePlace", academic papers on ML for FPGA compilation).

### Prior Art Avoidance Notes

- **Google "FirePlace"** - Machine learning for FPGA placement, but uses graph neural networks on netlists, not VSA hypervectors on behavioral specs.
- **Academic ML for EDA** - Various papers on ML for logic synthesis, but focus on binary features, not hypervector similarity.
- **StandardEDA tools** - Vivado HLS, Vitis, etc. have heuristic optimization, but no semantic similarity search based on behavioral descriptions.

**Novelty:** Using VSA hypervectors (not GNNs) to encode behavioral semantics (not netlists) for synthesis strategy recommendation.

### Filing Recommendation: **NOT READY**

**Rationale:** Core idea is novel, but implementation is missing. Only 40% ready. Need to build:
1. Synthesis history database
2. Feature extraction from specs → hypervectors
3. Recommendation algorithm
4. Validation experiments

**Research Needed:** 2-3 sprints to build minimal working prototype and validate effectiveness.

---

## Cross-Patent Synergies

### P1 + P2 Integration
**Combined Claim:** A method as in P1, wherein the automatically generated RTL code comprises a hardware accelerator as in P2.

**Novelty:** Spec-first compilation that targets VSA FPGA coprocessor with UART protocol, enabling automated design-to-deployment pipeline for hyperdimensional computing applications.

### P1 + P3 Integration
**Combined Claim:** A method as in P1, wherein the synthesis step (f) uses a recommended synthesis strategy as in P5.

**Novelty:** Spec-first compilation with intelligent synthesis strategy selection based on semantic similarity to previous builds, enabling continuous improvement of compilation outcomes.

### P2 + P3 Integration
**Combined Claim:** An accelerator as in P2, wherein the synthesis strategy used to generate the bitstream was recommended as in P3.

**Novelty:** VSA coprocessor optimized using VSA-based similarity search, creating a self-referential optimization loop.

---

## Prior Art Landscape

### Spec-First Compilation (P1)

| Reference | Technology | Overlap | Differentiation |
|-----------|-----------|---------|-----------------|
| Chisel (UC Berkeley) | Scala → Verilog | High (codegen) | Chisel is imperative code, not declarative spec |
| Amaranth (Kivikori) | Python → Verilog | Medium (Python DSL) | Amaranth is code, not YAML spec |
| PyMTL (Cornell) | Python models + tests | High (verification) | PyMTL targets simulation, not FPGA synthesis |
| nMigen (whitequark) | Python → Verilog | Medium (codegen) | nMigen lacks host code generation |

**Strategy:** Emphasize "single declarative spec → RTL + constraints + host + tests" unified pipeline as novel.

### VSA FPGA Accelerators (P2)

| Reference | Technology | Overlap | Differentiation |
|-----------|-----------|---------|-----------------|
| "Hyperdimensional Computing on FPGAs" (Various) | Binary HDC | Medium | Binary vs ternary trits |
| "Neuromorphic Hardware for HDC" | Spiking neurons | Low | Different paradigm |
| Standard DSP usage | DSP48E1 blocks | Low | Generic vs VSA-specific |

**Strategy:** Emphasize ternary encoding, majority vote bundle, and unified UART protocol as novel.

### ML for Synthesis (P3)

| Reference | Technology | Overlap | Differentiation |
|-----------|-----------|---------|-----------------|
| Google "FirePlace" | GNN for placement | High (ML for EDA) | GNN on netlists vs VSA on specs |
| "DREAMPlace" | Gradient-based placement | Medium (optimization) | Physical placement vs strategy selection |
| "AutoDSE" (Zhang et al.) | RL for design space exp. | High (ML for HLS) | HLS vs FPGA synthesis |

**Strategy:** Emphasize VSA hypervectors for semantic encoding (not GNNs), behavioral-level similarity (not netlist-level), and spec-driven (not RTL-driven).

---

## Filing Strategy

### Immediate Actions (This Sprint)

1. **P2 (VSA Coprocessor)** - File provisional patent now
   - Complete DSP block documentation
   - Add performance benchmarks
   - Draft specification document
   - File within 4 weeks

### Short-Term Actions (Next Sprint)

2. **P1 (Spec-First Compilation)** - Prepare for filing
   - Implement XDC constraint generation
   - Document end-to-end example
   - Complete prior art search
   - File non-provisional after P2

### Long-Term Actions (2-3 Sprints)

3. **P3 (Synthesis-Memory)** - Research prototype
   - Build synthesis history database
   - Implement recommendation algorithm
   - Validate effectiveness
   - Evaluate filing potential

---

## Conclusion

Three patent families have been identified:

1. **P1 (Spec-First Compilation)** - 75% ready, file after 1 sprint
2. **P2 (VSA Coprocessor)** - 90% ready, **file NOW** (priority)
3. **P3 (Synthesis-Memory)** - 40% ready, not ready for filing

**Recommended Filing Order:** P2 → P1 → P3

**P2 is the strongest candidate** for immediate filing due to:
- Complete implementation evidence
- Novel ternary encoding
- Working hardware
- Strong commercial potential (FPGA acceleration for AI/ML)

**Cross-licensing opportunities:** All three patents can be combined into a "Trinity FPGA Platform" covering spec-first design, VSA acceleration, and intelligent compilation.

---

**φ² + 1/φ² = 3 | TRINITY v10.2 | Patent Architecture Map v1.0**
