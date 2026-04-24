# Полный каталог документов: JEPA-T, клеточные автоматы и типы моделей

## Обзор

Этот документ consolidates все найденные документы по трем категориям: JEPA-T, Neural Cellular Automata (NCA), и другие типы моделей (VSA, Ternary, Hybrid).

---

## 1. JEPA-T (Ternary Joint Embedding Predictive Architecture)

### Основные документы

| Документ | Ветка | Описание |
|----------|--------|-----------|
| [docs/lab/papers/2026-03-15-hslm-tjepa.md](../../lab/papers/2026-03-15-hslm-tjepa.md) | main | Ежедневный отчет HSLM/T-JEPA с результатами обучения |
| [docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](../../experiments/FOUND_EXPERIMENTS_SUMMARY.md) | main, feat/physics-migration-phase-a | Полный экспериментальный журнал |
| [crates/trios-train-cpu/src/tjepa.rs](../../../../../crates/trios-train-cpu/src/tjepa.rs) | main, feat/physics-migration-phase-a | Реализация T-JEPA на Rust |
| [crates/trios-train-cpu/src/objective.rs](../../../../../crates/trios-train-cpu/src/objective.rs) | main | Multi-objective система |
| [docs/lab/papers/sevo-method.md](../../lab/papers/sevo-method.md) | main | Документация SEVO с JEPA objective |

### Параметры T-JEPA

**Маска:** mask_ratio=0.3, min_span=3, max_span=9, num_spans=2
**EMA Sync:** decay_start=0.996, decay_end=1.0
**Потеря:** L2-нормализованная MSE для предотвращения коллапса
**Мультипликаторы:** JEPA=1.4x, NCA-NTP=1.6x, Hybrid=1.2x медленнее сходимости

### Исходные файлы

| Категория | Файл |
|-----------|-------|
| Реализация | crates/trios-train-cpu/src/tjepa.rs |
| Конфигурация | crates/trios-train-cpu/src/objective.rs |
| Консольидация | docs/research/models/JEPAT/ (новая структура) |

---

## 2. Клеточные автоматы (NCA - Neural Cellular Automata)

### Основные документы

| Документ | Ветка | Описание |
|----------|--------|-----------|
| [docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](../../experiments/FOUND_EXPERIMENTS_SUMMARY.md) | main, feat/physics-migration-phase-a | NCA конфигурация |
| [src/tri/evolution.zig](../../src/tri/evolution.zig) | main, feat/physics-migration-phase-a | Эволюция с NCA objectives |
| [src/tri/tri_farm.zig](../../src/tri/tri_farm.zig) | main, feat/physics-migration-phase-a | Управление фармой |
| [src/brain/evolution_simulation.zig](../../src/brain/evolution_simulation.zig) | main, feat/physics-migration-phase-a | Симуляция эволюции |

### Параметры NCA

**Сетка:** 9×9 = 81 клеток = CONTEXT_LEN
**Состояний:** K=9 на клетку
**Rollout:** 128 шагов
**Entropy band:** min=1.5, max=2.8 (log2(9)=3.17)
**Wave 8.5:** Sweep G1-G8 по энтропии

### Консольидация

| Категория | Путь |
|-----------|-------|
| Новая структура | docs/research/models/NCA/ |

---

## 3. Типы моделей

### 3.1 VSA (Vector Symbolic Architecture)

| Документ | Ветка | Описание |
|----------|--------|-----------|
| docs/docs/api/vsa.md | main | API reference VSA |
| docs/docs/tutorials/vsa-operations.md | main | Туториал VSA (15 минут) |
| docs/docs/cheatsheets/vsa-operations.md | main | Quick reference |
| crates/trios-vsa/README.md | main | FFI bindings |
| .trinity/ralph/examples/vsa_usage.zig | main | Примеры использования |

### 3.2 Ternary (Троичные) модели

| Документ | Ветка | Описание |
|----------|--------|-----------|
| docs/docs/concepts/balanced-ternary.md | main | Полное руководство |
| docs/docs/adr/002-ternary-representation.md | main | ADR для packed trits |
| docs/docs/research/trinity-level11-hybrid-bipolar-ternary-report.md | main | Отчет о hybrid bipolar ternary |

### 3.3 Hybrid (Гибридные) модели

| Документ | Ветка | Описание |
|----------|--------|-----------|
| docs/docs/api/hybrid.md | main | HybridBigInt API |
| crates/trios-hybrid/README.md | main | FFI bindings |
| deploy/trinity-nexus/docs/research/trinity-hybrid-v2.0-report.md | origin/gh-pages | v2.0 implementation |
| deploy/trinity-nexus/docs/research/trinity-hybrid-v2.1-report.md | origin/gh-pages | v2.1 improvements |

### 3.4 VIBEE спецификации моделей

| Документ | Ветка | Описание |
|----------|--------|-----------|
| specs/tri/model_repository.vibee | main | Репозиторий моделей |
| specs/tri/model_training.vibee | main | Спецификация обучения |
| deploy/trinity-nexus/phi/e2e_all_models.vibee | origin/gh-pages | Комплексное тестирование |
| specs/phi/native_ternary_e2e.vibee | main | Native ternary E2E |
| specs/phi/ternary_quant_pipeline.vibee | main | Пайплайн тернарной квантизации |

---

## Анализ веток Git

### Проверенные ветки

| Ветка | Содержит | Документы по теме |
|--------|---------|-------------------|
| **main** | Основная ветка | Все основные документы JEPA, NCA, VSA, Ternary, Hybrid |
| **feat/physics-migration-phase-a** | Текущая ветка | Дубликаты основных документов |
| **origin/gh-pages** | Страница | Hybrid v2.0, v2.1 reports |
| **origin/gamma-conjecture-paper** | Не проверена | Без уникальных документов по теме |
| **origin/feat/tri-math-migration-534** | Не проверена | Без уникальных документов по теме |

### Вывод

Все релевантные документы находятся в ветках **main** и **feat/physics-migration-phase-a**.

---

## Консолидация

Создана новая структура в `docs/research/models/` с консолидированной документацией:

- **JEPAT/** - Архитектура, параметры, эксперименты
- **NCA/** - Архитектура, entropy bands, интеграция
- **VSA/** - Обзор, операции, API reference
- **Ternary/** - Balanced ternary guide, ADR
- **Hybrid/** - API, v2.0-v2.1 reports

---

**Дата создания:** 2026-04-24
**Ветка:** feat/physics-migration-phase-a → main
