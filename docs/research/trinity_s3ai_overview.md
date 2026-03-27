# Trinity S³AI — Unified Scientific Documentation

## Overview

Trinity S³AI is a unified system for research and development of ternary neural networks, combining three axes (S³), eight levels of the stack, and full reproducibility.

**Mathematical Foundation**: φ² + 1/φ² = 3, where φ = (1 + √5)/2 is the golden ratio. The number 3 is the fundamental constant of ternary computing.

---

## Three S³ Axes

### Sacred
Data format and arithmetic layer:
- **GF16**: 16-bit format with exp=6, mant=9, φ-based distance
- **TF3**: ternary folding format, 9 parameters
- **FPGA ALU**: 0 DSP, pure LUT implementation

**Key Files**:
- `src/hslm/f16_utils.zig` — GF16/TF3 implementation
- `fpga/openxc7-synth/sacred_alu.v` — FPGA ALU

**Scientific Questions**:
1. How does GF16 distance (φ-based) affect representation quality?
2. Can FP16 accuracy be achieved with fewer exponent bits?

### Superhuman
Self-learning orchestration:
- **Queen Lotus Cycle**: Phases 0-5, closed adaptation loop
- **Tri27Config**: kill_threshold, crash_rate_limit, byzantine_rate_limit
- **Episodes**: JSONL logging of all events

**Key Files**:
- `src/tri/queen/self_learning.zig` — Self-Learning
- `src/tri/queen/observe.zig` — Phase 1
- `src/tri/queen/plan.zig` — Phase 2
- `src/tri/queen/evaluate.zig` — Phase 3
- `src/tri/queen/act.zig` — Phase 4

**Scientific Questions**:
1. **H1**: self_learning reduces crash/byzantine rate vs fixed config
2. **H2**: feedback loop accelerates reaching stable mode

### Specialized
Narrowly specialized operations:
- **TRI-27**: ternary ISA with 36 opcodes
- **Dot-product**: ternary MAC without multiplication
- **TNN**: Ternary Neural Network

**Key Files**:
- `src/tri27/isa.zig` — ISA specification
- `src/tri27/emu/` — Zig backend (CPU)
- `src/tri27/verilog_backend.zig` — Verilog backend

**Scientific Questions**:
1. What is the energy/latency trade-off TRI-27 VM vs Sacred ALU vs CPU SIMD?
2. Does ternary ISA affect code density?

---

## Trinity 8-Level Stack

```
Level 8: HSLM Training (Railway farm, 152 services)
    ↓ src/hslm/train.zig, src/hslm/trainer.zig

Level 7: Queen Lotus Cycle (Phases 0-5, Self-Learning)
    ↓ src/tri/queen/self_learning.zig

Level 6: Sacred ALU (GF16/TF3, FPGA)
    ↓ fpga/openxc7-synth/sacred_alu.v

Level 5: TRI-27 ISA (36 opcodes, VM, Verilog)
    ↓ src/tri27/emu/executor.zig

Level 4: Tri Language (grammar, compiler)
    ↓ specs/tri/*.tri

Level 3: zig-half (GF16/TF3 implementation)
    ↓ src/hslm/f16_utils.zig

Level 2: LLVM IR (optional backend)
    ↓ (planned)

Level 1: FPGA bitstream (XC7A100T)
    ↓ fpga/openxc7-synth/build.sh
```

---

## Code Map

### HSLM (Hybrid Symbolic Language Model)
| Path | LOC | Purpose |
|------|-----|---------|
| `src/hslm/model.zig` | ~800 | 1.95M parameters, powers-of-three |
| `src/hslm/train.zig` | ~600 | Training loop |
| `src/hslm/tjepa.zig` | ~568 | T-JEPA implementation |
| `src/hslm/trinity_block.zig` | ~400 | TNN + Sacred Attention |
| `src/hslm/f16_utils.zig` | ~1085 | GF16/TF3 arithmetic |
| `src/hslm/tokenizer.zig` | ~300 | BPE tokenizer |
| **Total** | **~4000** | **Pure Zig, std only** |

### TRI-27 (Ternary Computing ISA)
| Path | LOC | Purpose |
|------|-----|---------|
| `src/tri27/isa.zig` | ~300 | ISA reference |
| `src/tri27/emu/decoder.zig` | ~200 | Instruction decoder |
| `src/tri27/emu/executor.zig` | ~400 | Execution engine |
| `src/tri27/emu/cpu_state.zig` | ~150 | CPU state, registers |
| `src/tri27/verilog_backend.zig` | ~200 | Zig → Verilog |
| **Total** | **~1250** | **36 opcodes, 27 registers** |

### Queen (Self-Learning Orchestrator)
| Path | LOC | Purpose |
|------|-----|---------|
| `src/tri/queen/self_learning.zig` | ~338 | Phase 5: Self-Learning |
| `src/tri/queen/observe.zig` | ~150 | Phase 1: Observe |
| `src/tri/queen/plan.zig` | ~100 | Phase 2: Plan |
| `src/tri/queen/evaluate.zig` | ~100 | Phase 3: Evaluate |
| `src/tri/queen/act.zig` | ~100 | Phase 4: Act |
| **Total** | **~788** | **Closed-loop learning** |

### FPGA (Synthesis & Bitstreams)
| Path | LOC | Purpose |
|------|-----|---------|
| `fpga/openxc7-synth/hslm_ternary_mac.v` | ~300 | Zero-DSP MAC |
| `fpga/openxc7-synth/sacred_alu.v` | ~200 | GF16/TF3 ALU |
| `src/hslm/fpga_backend.zig` | ~400 | Weight export |
| **Total** | **~900** | **Yosys 0.63 + nextpnr** |

---

## Experimental Pipelines

### HSLM Training
```bash
# Best config (v4R): LR=3e-4, cosine decay, 100K steps
zig build hslm-train
./zig-out/bin/hslm-train \
    --data data/tinystories/real_tinystories.txt \
    --steps 100000 --lr 3e-4 --batch 64 \
    --warmup 5000 --checkpoint-dir data/checkpoints
```

**Baseline**: PPL=125 ± 6 across 5 independent runs

### TRI-27 Self-Learning
```bash
# Run episode → trigger self-learning cycle
tri tri27 run test.tbin
tri queen episode-list --recent 20
tri queen self-learning --window 20
```

**Baseline**: 68/68 tests passing, Quality: good/unstable/bad/unknown

### FPGA Synthesis
```bash
# Full pipeline: Zig → Verilog → bitstream
zig build tri -- fpga synth
cd fpga/openxc7-synth
./build.sh  # Yosys + nextpnr
```

**Baseline**: 4,267 LUT (6.7%), 0 DSP, 35 tok/s @ 50MHz

---

## Scientific Hypotheses

### H1: Self-Learning Reduces Crash Rate
**Claim**: Tri27Config with auto_adapt=true shows <5% crash rate vs ~15% with fixed config.

**Metrics**:
- crash_rate = crashes / total_episodes
- byzantine_rate = byzantine / total_episodes
- success_rate = successful / total_episodes

**Experiment**: A/B test on Railway farm (Queen vs no Queen)

### H2: Ternary ISA Improves Code Density
**Claim**: TRI-27 code is 2-3× more compact than binary RISC for the same algorithms.

**Metrics**:
- instructions_per_algorithm
- bytes_per_instruction (4 bytes for TRI-27)
- cyclomatic_complexity

**Experiment**: Compile benchmark suite → TRI-27 vs x86_64 vs ARM64

### H3: Zero-DSP FPGA Matches DSP Accuracy
**Claim**: Sacred ALU (LUT-only) achieves FP16 accuracy with <1% error.

**Metrics**:
- LUT/FF/DSP utilisation
- timing_critical_path (ns)
- inference_accuracy (%)

**Experiment**: Synthesize sacred_alu.v → comparison with DSP48E1 baseline

---

## Publications

### Paper 1: HSLM (TinyStories)
**Status**: ✅ Published (Zenodo 18950696)

**Content**:
- 1.95M ternary params, PPL=125
- 5 independent runs, 2 platforms (M1 Pro, Railway)
- FPGA inference: 35 tok/s @ 0.5W on $30 Artix-7

**Files**: `docs/lab/papers/hslm/draft.md`

### Paper 2: Trinity FPGA
**Status**: ✅ Published (Zenodo 18939352)

**Content**:
- Zero-DSP ternary inference
- Yosys 0.63 + nextpnr open toolchain
- 4,267 LUT, 0 DSP, 135 BRAM36-eq

**Files**: `docs/lab/papers/trinity-fpga/draft.md`

### Paper 3: TRI-27 + Queen
**Status**: 🔄 In Progress

**Content**:
- TRI-27 ternary ISA
- Queen Lotus Cycle (Phases 0-5)
- Self-Learning experimental results

**Files**: `docs/research/tri27_platform.md`, `docs/research/queen_lotus_experiments.md`

---

## Baseline Metrics

| Component | Tests | LOC | Params | Status |
|-----------|-------|-----|--------|--------|
| HSLM | 74/74 | ~4000 | 1.95M | ✅ PPL=125 |
| TRI-27 | 68/68 | ~1250 | — | ✅ All passing |
| Queen | 4/4 | ~788 | — | ✅ Feedback loop |
| FPGA | — | ~900 | 708K ternary | ✅ Synthesized |

---

## DOI and Citation

```
Vasilev Dmitrii (2026). Trinity S³AI: FPGA Autoregressive Ternary LLM.
Zenodo. DOI: 10.5281/zenodo.18950696

@software{trinity_s3ai,
  author = {Vasilev, Dmitrii},
  title = {Trinity S³AI: FPGA Autoregressive Ternary LLM},
  year = {2026},
  doi = {10.5281/zenodo.18950696},
  url = {https://github.com/gHashTag/trinity}
}
```

---

## Next Steps

1. ✅ Create `docs/research/` structure
2. ⏳ Fill component docs with hypotheses
3. ⏳ Link experiments with code (file paths, modules)
4. ⏳ Prepare Paper 3 submission

---

**φ² + 1/φ² = 3 | TRINITY**
