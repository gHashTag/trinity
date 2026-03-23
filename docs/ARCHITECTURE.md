# Trinity S³AI DNA Architecture

> **Trinity Identity**: `φ² + 1/φ² = 3` — одно уравнение связывает математику, архитектуру мозга и язык Trinity.

## Overview

Trinity S³AI (Science-Structure-System AI) строится на **трёх переплетённых Strand** — каждый критичен для системы, но не может существовать без других двух.

| Strand | Роль | Код | Связи |
|--------|------|-----|--------|
| **I: Mathematical Foundation** | `src/tri/math/` | Священные константы, формулы, VSA |
| **II: Cognitive Architecture** | `src/brain/` | Нейроанатомическая карта, исполнительные функции |
| **III: Language & Hardware Bridge** | `src/tri/` + `fpga/` | TRI-27 язык, FPGA бэкенды |

```
Strand I (Math)
    ↓
Strand II (Brain)
    ↓
Strand III (Language + Hardware)
```

## Trinity Identity

```
φ² + 1/φ² = 3 = TRINITY
```

Эта формула — **архитектурный инвариант** Trinity:
- Математика: `V = n × 3^k × π^m × φ^p × e^q` в `src/tri/math/formula.zig`
- Константы: 75+ священных значений в `src/tri/math/constants.zig`
- Governance: 8 принципов в `src/sacred/CHARTER.md`

---

## Strand I — Mathematical Foundation

### Роль

Священная математическая рамка, которая задаёт **числовую геометрию** Trinity.

### Компоненты

| Модуль | Назначение | Ключевые элементы |
|--------|----------|-----------------|
| `src/tri/math/formula.zig` | Священная формула | V = n × 3^k × π^m × φ^p × e^q |
| `src/tri/math/constants.zig` | Священные константы | φ, π, e, γ, χ, σ, ε (75+) |
| `src/tri/math/identities.zig` | Идентичности | φ-distance, ternary resonance |
| `src/tri/math/transcendental.zig` | Трансцендентные функции | π, e, ln, exp |
| `src/sacred/CHARTER.md` | Governance | 8 принципов |
| `src/vsa.zig` | VSA операции | bind, unbind, bundle, similarity |

### Связи

- **→ Strand II**: Мозговые модули используют `src/tri/math/` для sacred операций
- **→ Strand III**: TRI-27 компилятор использует sacred константы

---

## Strand II — Cognitive Architecture

### Роль

Нейроанатомически вдохновлённая архитектура **виртуального мозга** Trinity.

### Компоненты

| Регион | Файл | Назначение | LOC |
|--------|-------|----------|-----|
| Prefrontal Cortex | `prefrontal_cortex.zig` | Исполнительные функции | 717 |
| Basal Ganglia | `basal_ganglia.zig` | Реестр задач | 889 |
| Reticular Formation | `reticular_formation.zig` | Шина событий (10K) | 746 |
| Locus Coeruleus | `locus_coeruleus.zig` | Регуляция возбуждения | 253 |
| Amygdala | `amygdala.zig` | Эмоциональная значимость | 578 |
| Persistence | `persistence.zig` | Журналирование JSONL | 804 |
| Health History | `health_history.zig` | Снимки здоровья | 305 |
| Cerebellum | `cerebellum.zig` | Моторное обучение | 1601 |
| Thalamus | `thalamus_logs.zig` | Ретрансляция | 435 |
| Telemetry | `telemetry.zig` | Временные ряды | 412 |
| Corpus Callosum | `federation.zig` | Агрегация, CRDT | 2166 |
| Microglia | `microglia.zig` | Иммунный мониторинг | 512 |
| Alerts | `alerts.zig` | Критические уведомления | 1241 |
| Metrics Dashboard | `metrics_dashboard.zig` | Управление метриками | 1884 |
| Visual Cortex | `visualization.zig` | ASCII карты | 1302 |
| Admin | `admin.zig` | Административный контроль | 1374 |
| State Recovery | `state_recovery.zig` | Восстановление | 2037 |
| Evolution Simulation | `evolution_simulation.zig` | Эволюция агентов | 1500+ |
| SEBO | `sebo.zig` | Sacred Bayesian Optimization | 800+ |
| Integration Test | `integration_test.zig` | Межмодульные тесты | 600+ |
| Performance Benchmarks | `benchmarks.zig`, `perf_*.zig` | Производительность | 1000+ |

### Связи

- **← Strand I**: Использует sacred математику из `src/tri/math/`
- **→ Strand III**: Выполняет TRI-27 bytecode, компилируемый в Zig

---

## Strand III — Language & Hardware Bridge (TRI-27)

### Роль

Связывает высокоуровневый язык **TRI-27** с двумя мирами исполнения: CPU (Zig) и FPGA (Verilog). TRI-27 — единственный язык высокого уровня, Zig/Verilog — бэкенды.

### Компоненты

| Компонент | Файл | Назначение |
|-----------|-------|----------|
| TRI-27 Lexer | `src/tri/lexer.zig` | Токенизация |
| TRI-27 Parser | `src/tri/parser.zig` | AST |
| TRI-27 AST | `src/tri/ast.zig` | Узлы |
| Zig Backend | `src/tri/emit_zig.zig` | CPU target |
| Verilog Backend | `src/tri/emit_verilog.zig` | FPGA target |
| VSA Operations | `src/vsa.zig` | bind, unbind, bundle, similarity |
| Sacred ALU | `fpga/openxc7-synth/sacred_alu.v` | φ-mathematics |
| TMU | `fpga/openxc7-synth/hslm_ternary_mac.v` | Ternary matrix |

### Цепочка компиляции

```
.tri spec (Single Source of Truth)
    ↓
TRI-27 language (Ternary types, AST)
    ↓              ↓
    Zig Backend    Verilog Backend
   (emit)        (emit)
```

**Важно**: Zig и Verilog — это **targets**, не source of truth. TRI-27 = source of truth.

### Связи

- **← Strand II**: Компилируется в Zig для выполнения мозговых модулей
- **← Strand I**: Использует sacred константы в FPGA Sacred ALU

---

## Rigid Process Framework

**Расположение**: `src/tri/dev/`

**State Machine**: `IDLE → ACTIVE → DIRTY → TESTED → COMMITTED → SHIPPED`

Все изменения кода проходят через этот pipeline, а не ручное редактирование.

---

## Tri Skill & Tri Cell

**Skill** — единица возможностей, определённая через `.claude/skills/*/SKILL.md`.

**Tri Cell** — самовосстанавливающаяся ячейка Phoenix System, определённая в `cell.tri`.

Все новые возможности проходят через **Rigid Process** и фиксируются в опыте Trinity.

Принципы:

- `.tri`/TRI-27 спецификации — **единственный источник истины**
- Codegen (Zig/Verilog) разрешён только через SKILL-ячейки и tri-CLI, под контролем state-machine
- Phoenix / Tri Cell уровнем выше обеспечивает самовосстановление и долговечность колонии SKILL-клеток

---

## Trinity S³AI DNA — сведение трёх Strand

Trinity становится целостной, когда три Strand синхронизированы:

- Strand I задаёт **числовую геометрию** (φ, 3, 27, ternary).
- Strand II размещает эту геометрию в **виртуальном мозге**.
- Strand III обеспечивает **исполнение и материализацию** — от TRI-27 до CPU/FPGA.

Всё новое знание, модуль или SKILL появляются только тогда, когда:

1. Их место описано в ARCHITECTURE (один из Strand).
2. Есть `.tri`/TRI-27 спецификация.
3. Они проведены через Rigid Process и зафиксированы в опыте Trinity.

---

## Аннотационные паттерны (для вставки в код)

**Strand I (Math)** — для всех файлов в `src/tri/math/*.zig`:
```zig
//! [Module Name] — [Brief description]
//! Strand I: Mathematical Foundation
//!
```

**Strand II (Brain)** — для всех файлов в `src/brain/*.zig`:
```zig
//! [Module Name] — [Neuroanatomical function]
//! Strand II: Cognitive Architecture
//!
```

**Strand III (Language + Hardware)** — для:
- `src/tri/token.zig`, `src/tri/lexer.zig`, `src/tri/ast.zig`, `src/tri/parser.zig`, `src/tri/emit_zig.zig`, `src/tri/emit_verilog.zig`, `src/vsa.zig`
- `fpga/openxc7-synth/*.v`

```zig
//! [Module Name] — [TRI-27/FPGA component]
//! Strand III: Language & Hardware Bridge
//!
```

---

## Queen Trinity Protocol

**Расположение**: `src/tri/queen_trinity.zig`

**Роль**: Lotus Cycle Protocol для очистки impure событий от всех трёх Strand.

**Lotus Cycle (φ² + 1/φ² = 3)**:
```
QUEUED → DIAGNOSING → REFINE → VERIFY → PURIFIED
   ↑        ↓         ↑        ↑
   ←────────────────── RESET ────────────────
```

**Максимум 3 попытки** (архитектурный лимит Trinity).

**Impure события** генерируются всеми Strand:
- **Strand I (Math)**: `src/tri/math/` — sacred вычисления, формулы
- **Strand II (Brain)**: `src/brain/` — обучение, telemetry, checkpoint
- **Strand III (Lang)**: `src/tri27/`, `fpga/` — компиляции, синтез, верификация

**Типы событий**:
| Тип | Код | Описание |
|-----|------|----------|
| BUILD_FAIL | `zig build` упал |
| TEST_FAIL | `zig build test` не прошёл |
| SPEC_MISMATCH | `.tri` spec не совпадает с кодом |
| GEN_FAIL | GEN фаза упала |
| VERIFY_FAIL | VERIFY фаза не прошла |
| DEPLOY_FAIL | деплой не удался |
| CHECKPOINT_FAIL | checkpoint не создан |

**Хранилище**: `.trinity/impure/*.json`

**CLI команды**:
```bash
tri queen status      # Показать очередь impure событий
tri queen purify     # Запустить Lotus Cycle на первом в очереди
tri queen purify --all # Очистить все queued
tri queen blocked     # Показать события, где Queen не смогла
```

**Интеграция**:
- Hook события записывают в `.trinity/impure/` автоматически
- Queen CLI читает очередь и выполняет Lotus Cycle
- Каждая фаза цикла (DIAGNOSING → VERIFY → PURIFY) записывает прогресс в событие
