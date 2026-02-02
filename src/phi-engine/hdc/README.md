# HDC - Hyperdimensional Computing для Trinity

## Обзор

Модуль HDC реализует гиперразмерные вычисления с онлайн-обучением для самообучающихся AI моделей на основе троичных векторов {-1, 0, +1}.

**Статистика модуля:**
- Код: 2031 строка Zig
- Тесты: 29 (все проходят)
- Файлов: 6

## Научная база

| Источник | Применение |
|----------|------------|
| **Kanerva (2009)** | Hyperdimensional Computing |
| **BitNet b1.58 (2024)** | Троичные веса для LLM |
| **Setun (1958)** | Сбалансированная троичная система |
| **Plate (1995)** | Holographic Reduced Representations |
| **Sutton & Barto** | TD-Learning для RL |

## Структура модуля

```
src/phi-engine/hdc/
├── hdc_core.zig          # Базовые HDC операции (377 строк)
├── online_classifier.zig # Онлайн классификатор (302 строки)
├── rl_agent.zig          # RL агент с Q-learning (395 строк)
├── gridworld.zig         # Среда GridWorld (294 строки)
├── demo_gridworld.zig    # Демо обучения (225 строк)
├── streaming_memory.zig  # Потоковая память (438 строк)
└── README.md             # Документация
```

## Математика

### Базовые операции

| Операция | Формула | Описание |
|----------|---------|----------|
| **Bind** | `c[i] = a[i] × b[i]` | Создание ассоциации |
| **Unbind** | `c = bind(M, k)` | Извлечение (самообратимость) |
| **Bundle** | `c[i] = majority(a[i], b[i], ...)` | Суперпозиция |
| **Permute** | `c[(i+k) mod n] = a[i]` | Кодирование позиции |
| **Similarity** | `cos(a,b) = (a·b)/(‖a‖×‖b‖)` | Сходство |

### Онлайн обучение

```
P(t+1) = P(t) + η × (v - P(t))
P_ternary = quantize(P)
```

### Streaming Memory

```
Store:    M ← M + bind(key, value)
Retrieve: value ≈ unbind(M, key)
Forget:   M ← (1-λ)M
```

## Компоненты

### 1. hdc_core.zig - Базовые операции

```zig
const hdc = @import("hdc_core.zig");

// Создание векторов
var v1 = try hdc.randomVector(allocator, 1000, seed);
var v2 = try hdc.zeroVector(allocator, 1000);

// Операции
hdc.bind(a.data, b.data, result.data);
hdc.bundle2(a.data, b.data, result.data);
const sim = hdc.similarity(a.data, b.data);

// Квантизация
hdc.quantizeToTernary(float_data, trit_data);
```

### 2. online_classifier.zig - Классификатор

```zig
const clf = @import("online_classifier.zig");

var classifier = clf.OnlineClassifier.init(allocator, .{
    .dim = 10240,
    .learning_rate = 0.01,
});
defer classifier.deinit();

try classifier.train(input_vector, "class_label");
const result = classifier.predict(test_vector);
```

### 3. rl_agent.zig - RL агент

```zig
const rl = @import("rl_agent.zig");

var agent = try rl.RLAgent.init(allocator, .{
    .state_dim = 256,
    .num_actions = 4,
    .gamma = 0.95,
});
defer agent.deinit();

try agent.initQTable(num_states);
const action = agent.selectAction(state_id);
_ = agent.tdUpdate(state, action, reward, next_state, done);
```

### 4. streaming_memory.zig - Потоковая память

```zig
const sm = @import("streaming_memory.zig");

var mem = try sm.StreamingMemory.init(allocator, .{ .dim = 5000 });
defer mem.deinit();

try mem.store(key.data, value.data);
const result = mem.retrieve(key.data, result_buf);
mem.applyForgetting(0.1);
```

### 5. gridworld.zig - Среда для тестирования

```zig
const gw = @import("gridworld.zig");

var env = try gw.GridWorld.init(allocator, .{ .width = 4, .height = 4 });
defer env.deinit();

var state = env.reset();
const result = env.step(action);
```

## Запуск

```bash
# Все тесты
zig test src/phi-engine/hdc/demo_gridworld.zig

# Демо GridWorld
zig build-exe src/phi-engine/hdc/demo_gridworld.zig -O ReleaseFast
./demo_gridworld
```

## Результаты демо

```
Эпизодов:           500
Побед:              478 (95.6%)
Avg reward (100):   9.45
✅ ЦЕЛЬ ДОСТИГНУТА за 6 шагов!
```

## Производительность

| Метрика | Значение |
|---------|----------|
| SIMD | 32 трита параллельно |
| Обучение | 1 ms / 500 эпизодов |
| Win rate | 95.6% |

---

**φ² + 1/φ² = 3 | TRINITY | HDC MODULE**
