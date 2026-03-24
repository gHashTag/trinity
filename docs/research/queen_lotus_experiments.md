# Queen Lotus Cycle — Self-Learning Experiments

## Overview

Queen Lotus Cycle — оркестратор self-learning для Trinity S³AI. Замкнутый цикл из 6 фаз: Experience Recall → Observe → Plan → Evaluate → Act → Self-Learning.

**Цель**: Автоматическая адаптация конфигурации на основе исторических episodic данных.

---

## Lotus Cycle Phases

### Phase 0: Experience Recall
**Файл**: `src/tri27/tri27_experience.zig`

**Функция**:
- Загружает последние N episodes из `.trinity/queen/episodes.jsonl`
- Вычисляет Jaccard similarity для поиска паттернов
- Предоставляет контекст для Observe фазы

**Метрики**:
- `recall_accuracy` — точность recall (целевой >0.8)
- `jaccard_threshold` — порог схожести (по умолчанию 0.3)

**Команды**:
```bash
tri queen experience-recall --recent 20
tri queen jaccard --episode <ID> --threshold 0.3
```

---

### Phase 1: Observe
**Файл**: `src/tri/queen/observe.zig`

**Функция**:
- Читает `policy.json` — текущая конфигурация
- Читает `senses.json` — сенсорные данные (farm metrics)
- Формирует `Context` для планирования

**Политика (PolicySnapshot)**:
```json
{
  "kill_threshold": 5.0,
  "crash_rate_limit": 0.1,
  "byzantine_rate_limit": 0.1,
  "god_mode": false,
  "max_auto_level": 2
}
```

**Сенсоры (Senses)**:
```json
{
  "farm_best_ppl": 125.0,
  "test_rate": 0.95,
  "dirty_files": 3,
  "active_issues": 2,
  "last_commit_age_hours": 1.5
}
```

---

### Phase 2: Plan
**Файл**: `src/tri/queen/plan.zig`

**Функция**:
- Генерирует `PolicyDelta[]` на основе `WindowEvaluation`
- Типы действий: scale_up, scale_down, set, wait

**PolicyDelta варианты**:
```zig
pub const PolicyDelta = union(enum) {
    scale_up: struct { key: []const u8, factor: f64 },
    scale_down: struct { key: []const u8, factor: f64 },
    set: struct { key: []const u8, value: f64 },
    wait: void,
};
```

**Логика планирования**:
| Quality | Действие | Фактор |
|---------|----------|--------|
| good | wait | — |
| unstable | scale_down | ×0.9 |
| bad | scale_down | ×0.8 |
| unknown | scale_up | ×1.1 |

---

### Phase 3: Evaluate
**Файл**: `src/tri/queen/evaluate.zig`

**Функция**:
- Оценивает окно episodes на success_rate
- Классифицирует качество: good/unstable/bad/unknown

**WindowEvaluation**:
```zig
pub const WindowEvaluation = struct {
    total_episodes: usize,
    successful: usize,
    failed: usize,
    crashed: usize,
    byzantine: usize,
    success_rate: f64,
    quality: Quality,
};

pub const Quality = enum {
    good,       // success_rate ≥ 95%
    unstable,   // 70% < success_rate < 95%
    bad,        // success_rate ≤ 70%
    unknown,    // нет данных
};
```

---

### Phase 4: Act
**Файл**: `src/tri/queen/act.zig`

**Функция**:
- Исполняет `PolicyDelta[]`
- Применяет изменения к `Tri27Config`
- Сохраняет конфигурацию

**Tri27Config**:
```zig
pub const Tri27Config = struct {
    kill_threshold: f64 = 5.0,        // PPL threshold
    crash_rate_limit: f64 = 0.1,      // Max crash rate
    byzantine_rate_limit: f64 = 0.1,  // Max byzantine ratio
    env_status: EnvStatus = .active,   // Environment status
    max_retries: u32 = 3,             // Max retries
    auto_adapt: bool = true,           // Enable self-learning
};
```

---

### Phase 5: Self-Learning
**Файл**: `src/tri/queen/self_learning.zig`

**Функция**:
- Замыкает цикл: episodes → evaluation → plan → act → config
- Записывает episode о self-learning_cycle
- Сохраняет обновлённую конфигурацию

**Замкнутый цикл**:
```
tri tri27 run test.tbin
    → Episode → episodes.jsonl
    → loadRecentEpisodes(20)
    → evaluateWindow() → WindowEvaluation
    → generatePlan() → PolicyDelta[]
    → applyPolicyDelta() → Tri27Config
    → saveConfig() → tri27_config.json
    → Episode о self_learning_cycle
```

---

## Научные гипотезы

### H1: Self-Learning снижает crash rate
**Утверждение**: Tri27Config с `auto_adapt=true` показывает <5% crash rate vs ~15% с фиксированным конфигом.

**Переменные**:
- Независимая: `auto_adapt` (bool)
- Зависимая: `crash_rate` = crashes / total_episodes
- Контролируемые: `kill_threshold`, `crash_rate_limit`, `byzantine_rate_limit`

**Эксперимент**:
```bash
# A/B тест на Railway farm
tri farm spawn --config queen_enabled.json --count 10
tri farm spawn --config queen_disabled.json --count 10
tri farm monitor --duration 24h --metrics crash_rate,success_rate
```

**Ожидаемый результат**:
- Queen enabled: crash_rate < 0.05
- Queen disabled: crash_rate ~ 0.15

### H2: Feedback loop ускоряет стабилизацию
**Утверждение**: Системы с self-learning достигают стабильного режима (quality=good) в 2× быстрее.

**Переменные**:
- Независимая: `auto_adapt` (bool)
- Зависимая: `time_to_stable` = steps до quality=good
- Контролируемые: начальная конфигурация

**Эксперимент**:
```bash
# Мониторинг сходимости
tri queen self-learning --window 20 --monitor
tri plot convergence.jsonl --x steps --y quality
```

**Ожидаемый результат**:
- Queen enabled: time_to_stable ~ 100 episodes
- Queen disabled: time_to_stable ~ 200 episodes

### H3: Auto-adapt предотвращает byzantine failure
**Утверждение**: `byzantine_rate_limit` с auto-adapt снижает byzantine ratio до <5%.

**Переменные**:
- Независимая: `auto_adapt` × `byzantine_rate_limit`
- Зависимая: `byzantine_rate` = byzantine / total_episodes

**Эксперимент**:
```bash
tri farm inject --config byzantine_stress.json
tri queen self-learning --window 50
tri farm metrics --filter byzantine_rate
```

---

## Экспериментальные сценарии

### Сценарий A: Queen vs No-Queen (A/B)
**Цель**: Измерить влияние Queen на farm stability.

**Setup**:
- Контрольная группа: 50 services без Queen
- Экспериментальная группа: 50 services с Queen
- Длительность: 48 часов
- Метрики: crash_rate, byzantine_rate, success_rate, ppl

**Команды**:
```bash
tri farm ab-test \
    --control queen_disabled.json \
    --treatment queen_enabled.json \
    --count 50 \
    --duration 48h \
    --metrics crash_rate,byzantine_rate,success_rate,ppl
```

### Сценарий B: Tri27Config вариации
**Цель**: Найть оптимальные threshold values.

**Setup**:
- `kill_threshold`: {3.0, 5.0, 7.0, 10.0}
- `crash_rate_limit`: {0.05, 0.1, 0.15, 0.2}
- Grid search: 4 × 4 = 16 конфигураций

**Команды**:
```bash
tri farm grid-search \
    --params kill_threshold,crash_rate_limit \
    --values 3.0,5.0,7.0,10.0 0.05,0.1,0.15,0.2 \
    --count 5 \
    --duration 24h
```

### Сценарий C: Quality evolution
**Цель**: Наблюдать за переходами quality состояний.

**Setup**:
- Начальное состояние: quality=unknown
- Цель: достичь quality=good
- Записывать все переходы: unknown → unstable → good

**Команды**:
```bash
tri queen self-learning --window 20 --trace
tri plot quality-transitions.jsonl --state-machine
```

---

## Quality metrics

| Quality | Success rate | Действие |
|---------|--------------|----------|
| good | ≥95% | wait (maintain) |
| unstable | 70-95% | scale_down (adjust) |
| bad | ≤70% | scale_down (aggressive) |
| unknown | нет данных | scale_up (explore) |

---

## Мониторинг

### CLI команды
```bash
# Показать текущий статус
tri queen status

# Показать последние episodes
tri queen episode-list --recent 20

# Запустить self-learning cycle
tri queen self-learning --window 20

# Показать Tri27Config
tri queen config show

# Изменить Tri27Config
tri queen config set kill_threshold 7.0
```

### JSONL логирование
```
.trinity/queen/
├── episodes.jsonl       # Все episodes
├── tri27_config.json    # Текущая конфигурация
└── self_learning_log.jsonl  # Self-learning cycles
```

---

## Status

✅ Phase 0: Experience Recall
✅ Phase 1: Observe (policy/senses)
✅ Phase 2: Plan (PolicyDelta generation)
✅ Phase 3: Evaluate (WindowEvaluation)
✅ Phase 4: Act (execute actions)
✅ Phase 5: Self-Learning (closed loop)
✅ Tests: 4/4 passing

---

## Связь с другими компонентами

| Компонент | Интерфейс | Файл |
|-----------|-----------|------|
| TRI-27 | Episode logging | `.trinity/queen/episodes.jsonl` |
| HSLM farm | Senses input | `.trinity/queen/senses.json` |
| Railway | Service recycling | `tri farm recycle` |

---

**φ² + 1/φ² = 3 | TRINITY**
