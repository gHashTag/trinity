# [EPIC] GF16/TF3 Arithmetic Unit на XC7A100T (Artix-7, 28nm)

**Labels:** `epic`, `fpga`, `hardware`, `priority:high`
**Milestone:** Sacred Formats Hardware
**Parent:** #357 (Training Farm Tracker)

---

## Цель

Реализовать и протестировать нативный аппаратный блок для **GF16 (Golden Float 16)** и **TF3-9 (Ternary Float 9)** на FPGA XC7A100T (Artix-7), с чётким интерфейсом для Trinity.

> "Опустить Sacred форматы с Level 0 (язык) до Level 6 (RTL)" — это ключевой дифференциатор Trinity против GPU-bound frameworks (PyTorch, JAX, TensorRT).

---

## Мотивация

| Аспект | CPU (софт) | FPGA (этот EPIC) |
|--------|-------------|------------------|
| GF16 add | ~50 cycles | ~1 cycle (50×) |
| GF16 mul | ~100 cycles | ~1 cycle (100×) |
| TF3 mac | ~100 cycles | ~1 cycle (100×) |
| Энергия | Высокая | Низкая (DSP-free) |

**Связь с документацией:**
- [positioning-zighalf-trinity.md](../docs/positioning-zighalf-trinity.md) — Level 6 позиционирование
- [phi-distance-formats.md](../docs/phi-distance-formats.md) — φ-distance анализ
- [native-f16-comparison.md](../docs/native-f16-comparison.md) — Сравнение языковых стеков

---

## Целевой чип

| Параметр | Значение |
|----------|----------|
| FPGA | XC7A100T-1FGG484 (Artix-7, 28nm) |
| LUT | ~426k (6-input) |
| FF | ~852k |
| DSP48E1 | 240 |
| BRAM | ~16 Mbit |
| Целевая частота | 100–150 MHz (v1) |

---

## Спецификация форматов

### GF16 (Golden Float 16)

```
┌─────────────────────────────────────┐
│ 15 │ 14-9  │ 8-0                   │
│────┼────────┼───────────────────────┤
│ S  │ Exp(6) │ Mant(9)               │
└─────────────────────────────────────┘
exp:mant = 6:9 = 0.667
φ-distance = 0.049 (95.1% golden)
```

**Исходный код:** `src/hslm/intraparietal_sulcus.zig`

### TF3-9 (Ternary Float 9)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 17-16 │ 15-10    │ 9-0                                             │
│──────┼───────────┼─────────────────────────────────────────────────│
│ Sign │ Exp(3×2)  │ Mant(5×2)  // 3 exp trits + 5 mant trits         │
│      │ trits     │           // Each trit = 2 bits: 00=0, 01=-1, 10=+1 │
└─────────────────────────────────────────────────────────────────────┘
exp:mant = 3:5 = 0.600
φ-distance = 0.018 (98.2% golden) — ЛУЧШИЙ ФОРМАТ!
```

**Исходный код:** `src/hslm/intraparietal_sulcus.zig`

---

## Архитектура

```
                    ┌─────────────────────────────────────┐
                    │          SACRED_ALU_TOP             │
                    ├─────────────────────────────────────┤
                    │  ┌───────────┐    ┌───────────┐    │
AXI-Stream ────────►│  │  GF16_ALU │    │  TF3_ALU  │    │├───► AXI-Stream
                    │  │           │    │           │    │
                    │  │ add/mul/fma│   │ add/dot   │    │
                    │  └───────────┘    └───────────┘    │
                    │                                     │
                    │  Control: mode[1:0], csr[31:0]     │
                    └─────────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────────────────────┐
                    │  XC7A100T Fabric (28nm)            │
                    │  - LUT: GF16 ops, TF3 decode       │
                    │  - DSP48E1: GF16 mul (optional)    │
                    │  - FF: Pipeline registers          │
                    └─────────────────────────────────────┘
```

---

## Задачи (Phases)

### Phase 1: GF16 Adder

**Файл:** `fpga/openxc7-synth/gf16_adder.v`

- [ ] Реализовать 4-стадийный пайплайн:
  - [ ] Stage 1: Decode (sign/exp/mant), align exponents
  - [ ] Stage 2: Core add (mantissa addition)
  - [ ] Stage 3: Normalize (shift result, adjust exponent)
  - [ ] Stage 4: Round-to-nearest-even, pack to 16-bit

- [ ] Интерфейс (AXI-Stream compatible):
  ```verilog
  module gf16_adder (
      input  wire        clk,
      input  wire        rst,
      input  wire        in_valid,
      input  wire [15:0] in_a,    // GF16 operand A
      input  wire [15:0] in_b,    // GF16 operand B
      output wire        in_ready,

      output wire        out_valid,
      output wire [15:0] out_y,   // GF16 result
      input  wire        out_ready
  );
  ```

- [ ] Testbench: `fpga/openxc7-synth/tb/gf16_adder_tb.v`
  - [ ] Генерировать тестовые векторы из `src/hslm/intraparietal_sulcus.zig`
  - [ ] Сравнить с софт-референсом (Zig `gf16FromF32/gf16ToF32`)
  - [ ] Уточнение: ошибка ≤ 1 LSB

- [ ] Синтез:
  - [ ] Yosys synthesis report (LUT/FF count)
  - [ ] Timing: ≥ 100 MHz on -1 speed grade

**Метки:** `fpga`, `gf16`, `phase-1`

---

### Phase 2: GF16 Multiplier

**Файл:** `fpga/openxc7-synth/gf16_multiplier.v`

- [ ] Реализовать 3-4 стадийный пайплайн:
  - [ ] Stage 1: Decode, multiply mantissas
  - [ ] Stage 2: DSP48E1 usage (18×18 multiply)
  - [ ] Stage 3: Normalize, add exponents
  - [ ] Stage 4: Round, pack

- [ ] Интерфейс (аналогичный adder):
  ```verilog
  module gf16_multiplier (
      input  wire        clk, rst,
      input  wire        in_valid,
      input  wire [15:0] in_a, in_b,
      output wire        in_ready,
      output wire        out_valid,
      output wire [15:0] out_y,
      input  wire        out_ready
  );
  ```

- [ ] Testbench: `fpga/openxc7-synth/tb/gf16_multiplier_tb.v`
  - [ ] Random test vectors vs софт-референс
  - [ ] Corner cases: denormals, infinity, NaN

- [ ] Синтез:
  - [ ] Report: LUT/FF + 1× DSP48E1 usage
  - [ ] Timing: ≥ 100 MHz

**Метки:** `fpga`, `gf16`, `phase-2`

---

### Phase 3: TF3 ALU

**Файл:** `fpga/openxc7-synth/tf3_alu.v`

- [ ] Ternary decode:
  ```verilog
  // Trit encoding: 00=0, 01=-1, 10=+1, 11=invalid
  function [1:0] trit_decode(input [1:0] t);
      case (t)
          2'b00: trit_decode = 2'b00;  // 0
          2'b01: trit_decode = 2'b11;  // -1 (in 2's comp)
          2'b10: trit_decode = 2'b01;  // +1
          default: trit_decode = 2'b00; // treat as 0
      endcase
  endfunction
  ```

- [ ] `tf3_add`: saturating add двух TF3-9 чисел
- [ ] `tf3_dot`: N-длинный dot product (configurable N)

- [ ] Интерфейс:
  ```verilog
  module tf3_alu (
      input  wire        clk, rst,
      input  wire [1:0]  mode,    // 00=add, 01=dot
      input  wire        in_valid,
      input  wire [17:0] in_a, in_b,  // TF3-9 operands
      input  wire [7:0]  dot_len,      // N for dot product
      output wire        in_ready,
      output wire        out_valid,
      output wire [17:0] out_y,
      input  wire        out_ready
  );
  ```

- [ ] Testbench: `fpga/openxc7-synth/tb/tf3_alu_tb.v`
  - [ ] Сравнение с `src/hslm/intraparietal_sulcus.zig` (TernaryFloat9)

**Метки:** `fpga`, `tf3`, `phase-3`

---

### Phase 4: Sacred ALU Wrapper

**Файл:** `fpga/openxc7-synth/sacred_alu.v`

- [ ] Объединённый интерфейс:
  ```verilog
  module sacred_alu (
      // Clock/reset
      input  wire        clk, rst,

      // Control
      input  wire [1:0]  mode,    // 00=GF16_ADD, 01=GF16_MUL, 10=TF3_ADD, 11=TF3_DOT
      input  wire [31:0] csr,     // Control/status registers

      // Data stream
      input  wire        in_valid,
      input  wire [31:0] in_data, // [17:0] op_a, [17:0] op_b (packed)
      output wire        in_ready,

      output wire        out_valid,
      output wire [31:0] out_data,
      input  wire        out_ready
  );
  ```

- [ ] Мультиплексирование между GF16_ALU и TF3_ALU
- [ ] CSR регистры для конфигурации и статуса

**Метки:** `fpga`, `integration`, `phase-4`

---

### Phase 5: Trinity Integration

**Файлы:** `src/hslm/fpga_backend.zig` (новый)

- [ ] Zig backend для вызова FPGA ALU:
  ```zig
  const fpga = @import("fpga_backend.zig");

  pub fn gf16AddFpga(a: GoldenFloat16, b: GoldenFloat16) !GoldenFloat16 {
      return fpga.callAlu(.GF16_ADD, a, b);
  }
  ```

- [ ] Фоллбэк на софт-реализацию если FPGA недоступен
- [ ] Единый интерфейс: `fn gf16Add(a, b) -> result` (HW или SW)

**Метки:** `integration`, `zig`, `phase-5`

---

### Phase 6: Documentation & Benchmarks

- [ ] Обновить `papers/trinity-fpga/draft.md` с результатами
- [ ] Бенчмарки: HW vs SW (cycles, latency, throughput)
- [ ] Ресурсы: LUT/FF/DSP usage table
- [ ] Фотографии тайминга из Vivado/Yosys

**Метки:** `docs`, `benchmark`, `phase-6`

---

## Метрики приёмки

| Метрика | Цель | Как измерить |
|---------|------|--------------|
| **Корректность GF16 add** | ≤ 1 LSB | vs Zig `gf16FromF32` |
| **Корректность GF16 mul** | ≤ 1 LSB | vs Zig reference |
| **Корректность TF3** | Точное совпадение | vs TernaryFloat9 |
| **GF16 add ресурсы** | < 500 LUT, < 200 FF | Yosys report |
| **GF16 mul ресурсы** | < 300 LUT + 1 DSP | Yosys report |
| **TF3 ALU ресурсы** | < 1000 LUT, < 500 FF | Yosys report |
| **Частота** | ≥ 100 MHz | Timing report (wns > 0) |
| **Latency** | 4 cycles (GF16) | Simulation |
| **Throughput** | 1 op/cycle (pipelined) | Benchmark |

---

## Зависимости

| Задача | Блокирует |
|--------|-----------|
| Phase 1 (GF16 add) | Phase 2, Phase 4 |
| Phase 2 (GF16 mul) | Phase 4 |
| Phase 3 (TF3 ALU) | Phase 4 |
| Phase 4 (Wrapper) | Phase 5 |
| Phase 5 (Integration) | Phase 6 |

---

## Связанные Issues

- #357 — Training Farm Tracker (родительский)
- [HSLM Training Review](../papers/hslm/training-review-mar10-14.md) — Контекст тренировки
- [FPGA Synthesis Results](../papers/trinity-fpga/synthesis-real-data.md) — Существующий синтез

---

## Риски и митигация

| Риск | Вероятность | Митигация |
|------|-------------|-----------|
| Тайминг не сойдётся | Средняя | Упростить пайплайн (3 стадии) |
| DSP48E1 не хватит | Низкая | GF16 mul на LUT (fallback) |
| TF3 кодировка изменится | Низкая | Параметризовать trit encoding |

---

## Вопросы для обсуждения

1. **Пайплайн глубина:** 3 или 4 стадии для GF16 add? (влияет на latency vs area)
2. **DSP usage:** Использовать DSP48E1 для GF16 mul или чисто LUT?
3. **Интерфейс:** AXI-Stream или кастомный handshaking?

---

## Полезные ссылки

- [Yosys documentation](https://yosyshq.readthedocs.io/)
- [Xilinx DSP48E1 user guide](https://www.xilinx.com/support/documentation/user_guides/ug479_7Series_DSP48E1.pdf)
- [Trinity FPGA docs](../fpga/openxc7-synth/)

---

*φ² + 1/φ² = 3 | TRINITY*
