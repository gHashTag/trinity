# Trinity S³AI — Unified Scientific Documentation

## Overview

Trinity S³AI — целостная система для исследования и разработки тернарных нейросетей, объединяющая три оси (S³), восемь уровней стека и полную воспроизводимость.

**Математическая основа**: φ² + 1/φ² = 3, где φ = (1 + √5)/2 — золотое сечение. Число 3 — фундаментальная константа тернарных вычислений.

---

## Три оси S³

### Sacred (Священный)
Слой форматов данных и арифметики:
- **GF16**: 16-битный формат с exp=6, mant=9, φ-based distance
- **TF3**: тернарный folding формат, 9 параметров
- **FPGA ALU**: 0 DSP, чисто LUT-реализация

**Ключевые файлы**:
- `src/hslm/f16_utils.zig` — GF16/TF3 implementation
- `fpga/openxc7-synth/sacred_alu.v` — FPGA ALU

**Научные вопросы**:
1. Как GF16 distance (φ-based) влияет на качество представления?
2. Можно ли достичь FP16 точности с меньшими битами на экспоненту?

### Superhuman (Сверхчеловеческий)
Оркестрация self-learning:
- **Queen Lotus Cycle**: Phases 0-5, замкнутый цикл адаптации
- **Tri27Config**: kill_threshold, crash_rate_limit, byzantine_rate_limit
- **Episodes**: JSONL логирование всех событий

**Ключевые файлы**:
- `src/tri/queen/self_learning.zig` — Self-Learning
- `src/tri/queen/observe.zig` — Phase 1
- `src/tri/queen/plan.zig` — Phase 2
- `src/tri/queen/evaluate.zig` — Phase 3
- `src/tri/queen/act.zig` — Phase 4

**Научные вопросы**:
1. **H1**: self_learning снижает crash/byzantine rate vs фиксированный конфиг
2. **H2**: feedback loop ускоряет выход на стабильный режим

### Specialized (Специализированный)
Узко специализированные операции:
- **TRI-27**: тернарный ISA с 36 опкодами
- **Dot-product**: тернарный MAC без умножения
- **TNN**: Ternary Neural Network

**Ключевые файлы**:
- `src/tri27/isa.zig` — ISA specification
- `src/tri27/emu/` — Zig backend (CPU)
- `src/tri27/verilog_backend.zig` — Verilog backend

**Научные вопросы**:
1. Какова energy/latency trade-off TRI-27 VM vs Sacred ALU vs CPU SIMD?
2. Влияет ли тернарный ISA на code density?

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

## Карта кода

### HSLM (Hybrid Symbolic Language Model)
| Путь | LOC | Назначение |
|------|-----|------------|
| `src/hslm/model.zig` | ~800 | 1.95M параметров, powers-of-three |
| `src/hslm/train.zig` | ~600 | Training loop |
| `src/hslm/tjepa.zig` | ~568 | T-JEPA implementation |
| `src/hslm/trinity_block.zig` | ~400 | TNN + Sacred Attention |
| `src/hslm/f16_utils.zig` | ~1085 | GF16/TF3 arithmetic |
| `src/hslm/tokenizer.zig` | ~300 | BPE tokenizer |
| **Всего** | **~4000** | **Pure Zig, std only** |

### TRI-27 (Ternary Computing ISA)
| Путь | LOC | Назначение |
|------|-----|------------|
| `src/tri27/isa.zig` | ~300 | ISA reference |
| `src/tri27/emu/decoder.zig` | ~200 | Instruction decoder |
| `src/tri27/emu/executor.zig` | ~400 | Execution engine |
| `src/tri27/emu/cpu_state.zig` | ~150 | CPU state, registers |
| `src/tri27/verilog_backend.zig` | ~200 | Zig → Verilog |
| **Всего** | **~1250** | **36 opcodes, 27 registers** |

### Queen (Self-Learning Orchestrator)
| Путь | LOC | Назначение |
|------|-----|------------|
| `src/tri/queen/self_learning.zig` | ~338 | Phase 5: Self-Learning |
| `src/tri/queen/observe.zig` | ~150 | Phase 1: Observe |
| `src/tri/queen/plan.zig` | ~100 | Phase 2: Plan |
| `src/tri/queen/evaluate.zig` | ~100 | Phase 3: Evaluate |
| `src/tri/queen/act.zig` | ~100 | Phase 4: Act |
| **Всего** | **~788** | **Closed-loop learning** |

### FPGA (Synthesis & Bitstreams)
| Путь | LOC | Назначение |
|------|-----|------------|
| `fpga/openxc7-synth/hslm_ternary_mac.v` | ~300 | Zero-DSP MAC |
| `fpga/openxc7-synth/sacred_alu.v` | ~200 | GF16/TF3 ALU |
| `src/hslm/fpga_backend.zig` | ~400 | Weight export |
| **Всего** | **~900** | **Yosys 0.63 + nextpnr** |

---

## Экспериментальные Pipelines

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

## Научные гипотезы

### H1: Self-Learning Reduces Crash Rate
**Утверждение**: Tri27Config с auto_adapt=true показывает <5% crash rate vs ~15% с фиксированным конфигом.

**Метрики**:
- crash_rate = crashes / total_episodes
- byzantine_rate = byzantine / total_episodes
- success_rate = successful / total_episodes

**Эксперимент**: A/B тест на Railway farm (Queen vs без Queen)

### H2: Ternary ISA Improves Code Density
**Утверждение**: TRI-27 код в 2-3× компактнее бинарного RISC для тех же алгоритмов.

**Метрики**:
- instructions_per_algorithm
- bytes_per_instruction (4 bytes для TRI-27)
- cyclomatic_complexity

**Эксперимент**: Компиляция benchmark suite → TRI-27 vs x86_64 vs ARM64

### H3: Zero-DSP FPGA Matches DSP Accuracy
**Утверждение**: Sacred ALU (LUT-only) достигает FP16 точности с <1% ошибки.

**Метрики**:
- LUT/FF/DSP utilisation
- timing_critical_path (ns)
- inference_accuracy (%)

**Эксперимент**: Синтез sacred_alu.v → сравнение с DSP48E1 baseline

---

## Публикации

### Paper 1: HSLM (TinyStories)
**Статус**: ✅ Published (Zenodo 18950696)

**Содержание**:
- 1.95M ternary params, PPL=125
- 5 independent runs, 2 platforms (M1 Pro, Railway)
- FPGA inference: 35 tok/s @ 0.5W on $30 Artix-7

**Файлы**: `docs/lab/papers/hslm/draft.md`

### Paper 2: Trinity FPGA
**Статус**: ✅ Published (Zenodo 18939352)

**Содержание**:
- Zero-DSP ternary inference
- Yosys 0.63 + nextpnr open toolchain
- 4,267 LUT, 0 DSP, 135 BRAM36-eq

**Файлы**: `docs/lab/papers/trinity-fpga/draft.md`

### Paper 3: TRI-27 + Queen
**Статус**: 🔄 In Progress

**Содержание**:
- TRI-27 ternary ISA
- Queen Lotus Cycle (Phases 0-5)
- Self-Learning experimental results

**Файлы**: `docs/research/tri27_platform.md`, `docs/research/queen_lotus_experiments.md`

---

## Базовые метрики

| Компонент | Tests | LOC | Params | Status |
|-----------|-------|-----|--------|--------|
| HSLM | 74/74 | ~4000 | 1.95M | ✅ PPL=125 |
| TRI-27 | 68/68 | ~1250 | — | ✅ All passing |
| Queen | 4/4 | ~788 | — | ✅ Feedback loop |
| FPGA | — | ~900 | 708K ternary | ✅ Synthesized |

---

## DOI и цитирование

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

## Следующие шаги

1. ✅ Создать `docs/research/` структуру
2. ⏳ Заполнить компонентные доки гипотезами
3. ⏳ Связать эксперименты с кодом (file paths, modules)
4. ⏳ Подготовить Paper 3 submission

---

**φ² + 1/φ² = 3 | TRINITY**
