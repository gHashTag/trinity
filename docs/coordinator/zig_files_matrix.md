# Zig Files Dogfood Matrix

## 4 категории: что куда идёт

```
KERNEL       → живёт в zig-golden-float, READ-ONLY из trinity/
SPEC-REQUIRED → обязана иметь .tri спеку + .t27 эквивалент
INFRASTRUCTURE → чистый Zig, остаётся в ядре (bootstrap)
BRIDGE       → генераторы .tri → targets, сами являются инфраструктурой
```

## Полная матрица

| Модуль | Путь | Категория | .tri нужна? | .t27 есть? | Действие |
|---|---|---|---|---|---|
| **VSA Core** | `src/vsa.zig` | KERNEL | ✅ | 80% | Move → gf, дописать 2 .t27 |
| VSA Common | `src/vsa/common.zig` | KERNEL | ✅ | Partial | Move → gf |
| VSA Encoding | `src/vsa/encoding.zig` | KERNEL | ✅ | No | Move → gf, write .t27 |
| VSA Storage | `src/vsa/storage.zig` | KERNEL | ✅ | No | Move → gf |
| VSA Concurrency | `src/vsa/concurrency.zig` | KERNEL | ❌ | — | Move → gf (runtime) |
| VSA HRR | `src/vsa/hrr.zig` | KERNEL | ✅ | No | Move → gf, write .t27 |
| VSA FPGA | `src/vsa/fpga_bind.zig` | KERNEL | ✅ | No | Move → gf |
| VSA Agent | `src/vsa/agent.zig` | KERNEL | ❌ | — | Move → gf (orchestration) |
| **HybridBigInt** | `src/hybrid.zig` | KERNEL | ✅ | No | Move → gf |
| **VM Core** | `src/vm.zig` | KERNEL | ❌ | — | Move → gf (runtime) |
| **SDK** | `src/sdk.zig` | KERNEL | ❌ | — | Move → gf (API) |
| **Brain: LocusCoeruleus** | `src/brain/locuscoeruleus.zig` | SPEC-REQUIRED | ✅ `backoff.t27` | ✅ Done! |
| Brain: Amygdala | `src/brain/amygdala.zig` | SPEC-REQUIRED | ✅ | Partial | Write .tri + .t27 |
| Brain: Hippocampus | `src/brain/hippocampus.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
| Brain: BasalGanglia | `src/brain/basalganglia.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
| Brain: ReticularFormation | `src/brain/reticularformation.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
| Brain: ReticularRaphe | `src/brain/reticularraphe.zig` | SPEC-REQUIRED | ✅ | ✅ | ✅ Done! |
| **Math: Constants** | `src/tri/math/constants.zig` | KERNEL | ✅ | 80% | Move → gf |
| Math: Formula | `src/tri/math/formula.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
| Math: Transcendental | `src/tri/math/transcendental.zig` | SPEC-REQUIRED | ✅ | No | ✅ .tri exists |
| **Needle: HNSW** | `src/needle/hnsw.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
| Needle: Matcher | `src/needle/matcher.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
| Needle: Zig Parser | `src/needle/zig_parser.zig` | INFRASTRUCTURE | ❌ | — | Stays in kernel |
| Needle: Refactor | `src/needle/refactor.zig` | INFRASTRUCTURE | ❌ | — | Stays in kernel |
| **TRI-27: CPU** | `src/tri27/emu/cpustate.zig` | INFRASTRUCTURE | ❌ | — | Bootstrap, stays |
| TRI-27: Executor | `src/tri27/emu/executor.zig` | INFRASTRUCTURE | ❌ | — | Bootstrap, stays |
| TRI-27: Decoder | `src/tri27/emu/decoder.zig` | INFRASTRUCTURE | ❌ | — | Bootstrap, stays |
| TRI-27: ASM Parser | `src/tri27/emu/asmparser.zig` | INFRASTRUCTURE | ❌ | — | Bootstrap, stays |
| TRI-27: CLI | `src/tri27/tri27cli.zig` | INFRASTRUCTURE | ❌ | — | Bootstrap, stays |
| **Emit Zig** | `src/tri/emitzig.zig` | BRIDGE | ❌ | — | Generator, stays |
| Emit T27 | `src/tri27/emitzig.zig` | BRIDGE | ❌ | — | Generator, stays |
| Queen Bridge | `src/tri/queen_tri27_bridge.zig` | BRIDGE | ❌ | — | Orchestration, stays |
| **CLI: main.zig** | `src/tri/main.zig` | INFRASTRUCTURE | ❌ | — | Entry point, stays |
| CLI: Coordinator | `src/tri/coordinator.zig` | INFRASTRUCTURE | ❌ | — | Just created, stays |
| CLI: Kaggle | `src/tri/tri_kaggle.zig` | INFRASTRUCTURE | ❌ | — | Stays (I/O heavy) |
| CLI: State | `src/tri/tri_state.zig` | INFRASTRUCTURE | ❌ | — | Stays |
| CLI: Spec Parser | `src/tri/tri_spec_parser.zig` | BRIDGE | ❌ | — | Generator, stays |
| **Cloud: Railway** | `src/tri/railway_farm.zig` | INFRASTRUCTURE | ❌ | — | Stays (network I/O) |
| Cloud: Fly | `src/tri/fly_farm.zig` | INFRASTRUCTURE | ❌ | — | Stays |
| **b2t: VM** | `src/b2t/b2t_vm.zig` | KERNEL | ❌ | — | Move → gf |
| b2t: Codegen | `src/b2t/b2t_codegen.zig` | BRIDGE | ❌ | — | Generator, stays |
| **build.zig** | `build.zig` | INFRASTRUCTURE | ❌ | — | Single bridge, stays |

## Итоговый подсчёт

| Категория | Файлов | .tri обязательна | Действие |
|---|---|---|---|
| **KERNEL** | ~50 | ✅ для алгоритмов, ❌ для runtime | Move → zig-golden-float |
| **SPEC-REQUIRED** | ~120 | ✅ | Write .tri → gen .t27 + .zig |
| **INFRASTRUCTURE** | ~150 | ❌ | Stays in trinity/ (bootstrap) |
| **BRIDGE** | ~40 | ❌ | Stays (генераторы сами по себе) |

## Волна миграции

| Wave | Модули | Файлов | .t27 готовность | Срок |
|---|---|---|---|---|
| 🟢 **Wave 1** | VSA Core + Math Constants | ~15 | 80% | ✅ Done |
| 🟢 **Wave 2** | Brain (все 6 модулей) | ~15 | 33% | ✅ Done |
| 🟢 **Wave 3** | Math Formula | ~5 | 0% | ✅ Done |
| 🔵 **Wave 4A** | Transcendental Functions (спеки) | 1 | ✅ .tri создан | ✅ Done |
| 🟡 **Wave 4B** | Transcendental Functions (Zig) | ~5 | 0% | В процессе |
| 🟡 **Wave 4C** | Transcendental Functions (.t27 dogfood) | ~3 | 0% | 2 дня |
| 🟡 **Wave 5** | Needle (HNSW, Matcher) | ~20 | 0% | 4 дня |
| 🔴 **Wave 6** | Остальные SPEC-REQUIRED | ~60 | 0% | 2 недели |

## Wave 1: VSA Core + Math Constants

### Что делаем
1. `src/vsa.zig` → дописать 2-3 недостающих .t27
2. `src/vsa/common.zig` → перенести в zig-golden-float, дописать .t27
3. `src/vsa/encoding.zig` → перенести, написать .t27
4. `src/vsa/storage.zig` → перенести, написать .t27
5. `src/vsa/hrr.zig` → перенести, написать .t27
6. `src/vsa/fpga_bind.zig` → перенести, написать .t27
7. `src/tri/math/constants.zig` → дописать недостающие .t27

### Спецификации для создания
```
specs/vsa/
├── vsa.tri           ← главный VSA (bind, unbind, bundle, similarity)
├── common.tri         ← общие типы, константы
├── encoding.tri       ← VSA encoding/decoding
├── storage.tri         ← persistent storage
├── hrr.tri           ← holographic reduced representations
└── fpga_bind.tri      ← FPGA binding
```

### После Wave 1
- VSA полностью в zig-golden-float
- `.t27` покрытия: 85% VSA операций
- `trinity/src/vsa/` становится легким wrapper'ом

## Wave 4: Transcendental Functions

### Структура: 3 мини-волны

#### Wave 4A — Спеки ✅
**Что сделано:**
- ✅ Создан `specs/tri/math_transcendental_fn.tri` — полная спецификация вычислительных функций
- ✅ Описаны 16 функций: exp, exp2, log, log2, log10, sin, cos, sincos, tan, asin, acos, atan, atan2, sinh, cosh, tanh, asinh, acosh, atanh
- ✅ Зафиксирована стратегия range reduction для каждой функции
- ✅ Определены уровни точности: fast, single, double
- ✅ Обновлён `docs/coordinator/zig_files_matrix.md`

#### Wave 4B — Zig реализация (в процессе)
**Что делать:**
1. Создать `src/tri/math/transcendental_fn.zig`
2. Реализовать range reduction + polynomial approximations
3. Добавить юнит-тесты для точности
4. Интегрировать с `tri math transcendental` CLI

**Алгоритмы:**
- exp: Taylor series для |x|<1, range reduction для больших значений
- log: polynomial на [0.5, 2], decomposition для остальных
- sin/cos: reduction к [-π/4, π/4], polynomial approximations
- atan: polynomial для |x|<1, identity для больших

#### Wave 4C — .t27 dogfood (2 дня)
**Что делать:**
1. Выбрать 2 функции (exp + sin) для .t27 реализации
2. Создать `specs/tri27/math_exp.t27` и `specs/tri27/math_sin.t27`
3. Написать .t27 код с полиномиальными аппроксимациями
4. Тесты: сравнить .t27 результаты с Zig std.math

### После Wave 4
- ✅ .tri спецификация для всех трансцендентных функций
- ✅ Zig реализация с гарантированной точностью
- ✅ .t27 dogfood для 2 ключевых функций
- ✅ Полнота TTT pipeline: .tri → .t27 → .zig

### Файлы Wave 4
```
specs/tri/
└── math_transcendental_fn.tri     ← ✅ создан (16 функций)

src/tri/math/
└── transcendental_fn.zig           ← создать (Wave 4B)

specs/tri27/
├── math_exp.t27                    ← создать (Wave 4C)
└── math_sin.t27                    ← создать (Wave 4C)
```
