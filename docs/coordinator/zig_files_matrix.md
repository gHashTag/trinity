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
| Math: Transcendental | `src/tri/math/transcendental.zig` | SPEC-REQUIRED | ✅ | No | Write .tri + .t27 |
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
| 🟢 **Wave 1** | VSA Core + Math Constants | ~15 | 80% | 2 дня |
| 🟢 **Wave 2** | Brain (все 6 модулей) | ~15 | 33% | 3 дня |
| 🟡 **Wave 3** | Math Formula + Transcendental | ~10 | 0% | 3 дня |
| 🟡 **Wave 4** | Needle (HNSW, Matcher) | ~20 | 0% | 4 дня |
| 🔴 **Wave 5** | Остальные SPEC-REQUIRED | ~60 | 0% | 2 недели |

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
