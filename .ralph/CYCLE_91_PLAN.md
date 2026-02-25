# CYCLE-91: TRI MATH v3.6 — FIX VIBEE COMPILER + COMPLETE REAL IMPLEMENTATION

**Приоритет:** КРИТИЧЕСКИЙ — FIX BUGS FIRST
**Ветка:** `ralph/cycle-91-fix-vibee-full-implementation`
**Статус:** IN_PLANNING
**Дата:** 2026-02-25

## Цикл

Cycle 91 исправляет критические проблемы VIBEE компилятора и доводит Cycle 90 до 100% compliance с реальными реализациями (без заглушек).

**ПРОБЛЕМА:**
- VIBEE компилятор генерирует сломанный код (коррумпированные имена функций)
- Engine файлы содержат только заглушки `// TODO: implement`
- Бенчмарк код устарел и не работает

**РЕШЕНИЕ:**
- Исправить VIBEE codegen (создать недостающие `codegen/` подмодули)
- Реализовать все движки (autonomous_universe, formula_discovery, sacred_economy, self_improver, nft_marketplace)
- Убрать заглушки, написать реальный код
- Обновить бенчмарки для актуального Zig API
- Сравнить v3.6 с v3.5 и v3.4

## Критерии приёмки

- [ ] VIBEE компилятор исправлен и работает
- [ ] Все engine файлы сгенерированы через `tri gen`
- [ ] В engine файлах нет заглушек `// TODO: implement`
- [ ] Все тесты проходят (цель: 100%)
- [ ] Производительность v3.6 > v3.5 минимум на 10% по всем метрикам
- [ ] Полная интеграция: CLI + API + Frontend
- [ ] i18n для 5 языков (en, ru, de, zh, es)
- [ ] Документация по стандартному шаблону
- [ ] Токсичный вердикт в конце

## Задачи

### Phase A: Fix VIBEE Compiler

| Задача | Статус | Описание |
|---------|----------|-----------|
| A1 | TODO | Создать `trinity-nexus/lang/src/codegen/types.zig` |
| A2 | TODO | Создать `trinity-nexus/lang/src/codegen/builder.zig` |
| A3 | TODO | Создать `trinity-nexus/lang/src/codegen/utils.zig` |
| A4 | TODO | Создать `trinity-nexus/lang/src/codegen/patterns.zig` |
| A5 | TODO | Создать `trinity-nexus/lang/src/codegen/tests_gen.zig` |
| A6 | TODO | Создать `trinity-nexus/lang/src/codegen/emitter.zig` |
| A7 | TODO | Создать `trinity-nexus/lang/src/codegen/mod.zig` |
| A8 | TODO | Исправить zig_codegen.zig импорт путей |
| A9 | TODO | Протестировать VIBEE со всеми spec файлами |

### Phase B: Create .tri Specs (Source of Truth)

| Задача | Статус | Описание |
|---------|----------|-----------|
| B1 | TODO | Обновить autonomous_universe.tri |
| B2 | TODO | Обновить formula_discovery.tri (добавить hybrid modes) |
| B3 | TODO | Обновить sacred_economy.tri (добавить global modes) |
| B4 | TODO | Обновить self_improver_v2.tri (добавить Adam/EWC++ modes) |
| B5 | TODO | Обновить nft_marketplace.tri |
| B6 | TODO | Создать self_improving_formula_discovery.tri |
| B7 | TODO | Создать sacred_economy_global.tri |

### Phase C: Real Implementation (NO STUBS)

| Задача | Статус | Описание |
|---------|----------|-----------|
| C1 | TODO | autonomous_universe: реализовать все 7 modes |
| C2 | TODO | formula_discovery: реализовать hybrid symbolic+numeric |
| C3 | TODO | sacred_economy: реализовать global oracle, staking, marketplace |
| C4 | TODO | self_improver_v2: реализовать Adam optimizer с EWC++ |
| C5 | TODO | nft_marketplace: реализовать все 6 modes |
| C6 | TODO | self_improving_formula_discovery: полная реализация |
| C7 | TODO | sacred_economy_global: полная реализация |

### Phase D: Testing

| Задача | Статус | Описание |
|---------|----------|-----------|
| D1 | TODO | `zig test` для всех engine файлов — цель 100% pass |
| D2 | TODO | Интеграционные тесты для всех движков |

### Phase E: Benchmarks

| Задача | Статус | Описание |
|---------|----------|-----------|
| E1 | TODO | Обновить bench_core.zig для актуального Zig API |
| E2 | TODO | Сравнить v3.6 vs v3.5 |
| E3 | TODO | Сравнить v3.6 vs v3.4 |
| E4 | TODO | Создать отчёт с реальными метриками |

### Phase F: Frontend

| Задача | Статус | Описание |
|---------|----------|-----------|
| F1 | TODO | Обновить chatApi.ts для новых endpoints |
| F2 | TODO | Создать виджеты SelfImprovingFormulaDiscoverySection.tsx |
| F3 | TODO | Создать виджет SacredEconomyGlobalSection.tsx |
| F4 | TODO | Добавить переводы в i18n для новых режимов |
| F5 | TODO | Интегрировать в TrinityCanvas.tsx |

### Phase G: Documentation

| Задача | Статус | Описание |
|---------|----------|-----------|
| G1 | TODO | Обновить docs/tri/tri-math-v4.0.md |
| G2 | TODO | Создать docs/research/tri-math-v4.0-architecture.md |
| G3 | TODO | Обновить TECHNOLOGY_TREE.md (добавить Cycle 91) |
| G4 | TODO | Добавить entry в sidebars.ts |

### Phase H: Git

| Задача | Статус | Описание |
|---------|----------|-----------|
| H1 | TODO | git pull origin ralph/nexus-src |
| H2 | TODO | git checkout -b ralph/cycle-91-fix-vibee-full-implementation |
| H3 | TODO | git add .ralph/CYCLE_91_PLAN.md |
| H4 | TODO | git commit -m "plan: Cycle 91 - Fix VIBEE + real implementation" |
| H5 | TODO | git push origin ralph/cycle-91-fix-vibee-full-implementation |

## Метрики для сравнения

| Метрика | v3.5 (цель) | v3.6 (минимум) | Улучшение |
|----------|---------------|-------------------|-----------|
| VIBEE работающий | ❌ Сломан | ✅ Исправлен |
| Real engine код | ❌ Заглушки | ✅ Реализация |
| Тесты | 99.7% | 100% | Стабильно |
| Автономность | Заглушки | Реальный код | Живая система |
| Compliance | 33% | 100% | +67% |

## Технические детали

### VIBEE Compiler Fix

**Проблема:** `trinity-nexus/lang/src/zig_codegen.zig` импортирует из несуществующего `codegen/mod.zig`

**Решение:**
```zig
// Создать недостающие файлы в trinity-nexus/lang/src/codegen/
// - types.zig (типы: ZigCodeGen, CodeBuilder, PatternMatcher, TestGenerator)
// - builder.zig (CodeBuilder для генерации кода)
// - utils.zig (mapType и другие утилиты)
// - patterns.zig (pattern matching для DSL, VSA, Metal)
// - tests_gen.zig (генерация тестов)
// - emitter.zig (главный ZigCodeGen движок)
// - mod.zig (module re-exports)

// Исправить импорт в zig_codegen.zig:
// pub const codegen = @import("codegen/mod.zig");
```

### Real Implementation Requirements

**autonomous_universe_engine.zig:**
- Автономные пузыри (autonomous_bubbles)
- Авто-тюнирование параметров (auto_tune_parameters)
- Эволюция вселенной (universe_evolution)
- Интеграция открытия (discovery_integration)
- Снэпшот состояния (state_snapshot)
- Проверка сходимости (convergence_check)
- Сброс вселенной (reset_universe)

**formula_discovery_engine.zig (hybrid):**
- Гибридный поиск: symbolic + numeric approximation
- AST парсинг (parse_ast)
- Символическая упрощение (symbolic_simplify)
- Числовая аппроксимация (numeric_approximate)
- Точный расчёт (evaluate_exact)
- Проверка эквивалентности (find_equivalence)
- Оптимизация сложности (optimize_complexity)

**sacred_economy_engine.zig (global):**
- Глобальный оракул (global_oracle)
- Глобальный стейкинг (global_staking)
- Разстейкинг (unstake_global)
- Глобальный маркетплейс (global_marketplace)
- Ставки (place_global_bid)
- Принятие офферов (accept_global_offer)
- Yield farming (get_yield_pool, claim_yield_rewards)
- DAO управление (create_proposal, vote, execute_proposal)
- Cross-chain bridge (bridge_assets, confirm_bridge_transfer)

**self_improver_v2_engine.zig:**
- Adam optimizer (adam_step) — beta1=0.9, beta2=0.999, epsilon=1e-8
- EWC синапсы (ewc_synapse) — lambda=0.5, decay=0.99
- Градиентный спуск (gradient_descent)
- Momentum обновления (momentum_update)
- Трекинг траектории (trajectory)
- Клипирование градиентов (clip_gradients)
- Консолидация (consolidate)

**nft_marketplace_engine.zig:**
- Просмотр листингов (browse)
- Создание ставки (bid)
- Создание листинга (create_listing)
- Принятие оффера (accept_offer)
- Отмена листинга (cancel_listing)
- Торговля (trade)
- История продаж (sales_history)

**self_improving_formula_discovery_engine.zig:**
- Все режимы formula_discovery + self-improvement
- Adam optimize (adam_optimize)
- Трекинг траектории (track_trajectory)
- Прунинг библиотеки (prune_library)
- Слияние концептов (merge_concepts)
- Священная проверка (verify_sacred)
- Метрики самоулучшения (get_self_improving_metrics)
- Сброс состояния (reset_learning_state)

### Бенчмарк Requirements

**Обновить для Zig 0.15.x:**
- Заменить `std.io.getStdOut()` на актуальный API
- Использовать `std.debug.print()` для вывода
- Обеспечить совместимость с new Zig стандартами

**Сравнительная метрика:**
```
Formula Discovery Speed: v3.6 / v3.5 (цель: +50%)
Convergence Rate: v3.6 / v3.5 (цель: +40%)
APY Calculation Speed: v3.6 / v3.5 (цель: +100%)
```

## Выходные условия (EXIT_SIGNAL)

```
EXIT_SIGNAL = (
    vibee_compiler_fixed AND
    all_engines_real_implementation AND
    all_tests_pass_100_percent AND
    benchmarks_complete_with_v3_6_vs_v3_5_comparison AND
    frontend_widgets_created AND
    documentation_updated AND
    git_committed AND
    pushed_to_ralph_cycle_91 AND
    toxic_verdict_written AND
    compliance_100_percent
)
```

## Примечания

**КРИТИЧЕСКО ПРАВИЛО №1:** Никаких ручных правок `.zig`. Весь код генерируется ТОЛЬКО через `tri gen` из `.tri` спецификаций.

**КРИТИЧЕСКО ПРАВИЛО №2:** Никаких заглушек `// TODO: implement`. Все движки имеют реальную реализацию.

**КРИТИЧЕСКО ПРАВИЛО №3:** Если VIBEE компилятор снова сломается — полная остановка цикла до исправления.

**Цель Cycle 91:**
Довести TRI MATH v3.5 до состояния **автономной живой математической вселенной** с:
- Рабочей VIBEE генерацией
- Реальными движками (без заглушек)
- Полными тестами (100% pass rate)
- Обновлёнными бенчмарками
- Визуализацией (виджеты)

---

**Создано:** 2026-02-25 (Ko Samui, Cycle 91 Planning)

Golden Chain eternal. 🔥
