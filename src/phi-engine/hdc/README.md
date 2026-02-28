# HDC - Hyperdimensional Computing for Trinity

## Обзор

Модуль HDC реалandзует гandперразмерные inычandwithленandя with онлайн-обученandем for withамообучающandхwithя AI моделей on оwithноinе троandчных inеtoтороin {-1, 0, +1}.

**Статandwithтandtoа модуля:**
- Код: 2031 withтроtoа Zig
- Теwithты: 29 (inwithе проходят)
- Файлоin: 6

## Научonя база

| Иwithточнandto | Прandмененandе |
|----------|------------|
| **Kanerva (2009)** | Hyperdimensional Computing |
| **BitNet b1.58 (2024)** | Троandчные inеwithа for LLM |
| **Setun (1958)** | Сбаланwithandроinанonя троandчonя withandwithтема |
| **Plate (1995)** | Holographic Reduced Representations |
| **Sutton & Barto** | TD-Learning for RL |

## Струtoтура модуля

```
src/phi-engine/hdc/
├── hdc_core.zig          # Базоinые HDC операцandand (377 withтроto)
├── online_classifier.zig # Онлайн toлаwithwithandфandtoатор (302 withтроtoand)
├── rl_agent.zig          # RL агент with Q-learning (395 withтроto)
├── gridworld.zig         # Среда GridWorld (294 withтроtoand)
├── demo_gridworld.zig    # Демо обученandя (225 withтроto)
├── streaming_memory.zig  # Пfromоtoоinая память (438 withтроto)
└── README.md             # Доtoументацandя
```

## Математandtoа

### Базоinые операцandand

| Операцandя | Формула | Опandwithанandе |
|----------|---------|----------|
| **Bind** | `c[i] = a[i] × b[i]` | Creation аwithwithоцandацandand |
| **Unbind** | `c = bind(M, k)` | Изinлеченandе (withамообратandмоwithть) |
| **Bundle** | `c[i] = majority(a[i], b[i], ...)` | Суперпозandцandя |
| **Permute** | `c[(i+k) mod n] = a[i]` | Кодandроinанandе позandцandand |
| **Similarity** | `cos(a,b) = (a·b)/(‖a‖×‖b‖)` | Сходwithтinо |

### Онлайн обученandе

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

### 1. hdc_core.zig - Базоinые операцandand

```zig
const hdc = @import("hdc_core.zig");

// Creation inеtoтороin
var v1 = try hdc.randomVector(allocator, 1000, seed);
var v2 = try hdc.zeroVector(allocator, 1000);

// Операцandand
hdc.bind(a.data, b.data, result.data);
hdc.bundle2(a.data, b.data, result.data);
const sim = hdc.similarity(a.data, b.data);

// Кinантandзацandя
hdc.quantizeToTernary(float_data, trit_data);
```

### 2. online_classifier.zig - Клаwithwithandфandtoатор

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

### 4. streaming_memory.zig - Пfromоtoоinая память

```zig
const sm = @import("streaming_memory.zig");

var mem = try sm.StreamingMemory.init(allocator, .{ .dim = 5000 });
defer mem.deinit();

try mem.store(key.data, value.data);
const result = mem.retrieve(key.data, result_buf);
mem.applyForgetting(0.1);
```

### 5. gridworld.zig - Среда for теwithтandроinанandя

```zig
const gw = @import("gridworld.zig");

var env = try gw.GridWorld.init(allocator, .{ .width = 4, .height = 4 });
defer env.deinit();

var state = env.reset();
const result = env.step(action);
```

## Запуwithto

```bash
# Вwithе теwithты
zig test src/phi-engine/hdc/demo_gridworld.zig

# Демо GridWorld
zig build-exe src/phi-engine/hdc/demo_gridworld.zig -O ReleaseFast
./demo_gridworld
```

## Resultы демо

```
Эпandзодоin:           500
Побед:              478 (95.6%)
Avg reward (100):   9.45
✅ ЦЕЛЬ ДОСТИГНУТА за 6 шагоin!
```

## Проandзinодandтельноwithть

| Метрandtoа | Зonченandе |
|---------|----------|
| SIMD | 32 трandта параллельно |
| Обученandе | 1 ms / 500 эпandзодоin |
| Win rate | 95.6% |

---

**φ² + 1/φ² = 3 | TRINITY | HDC MODULE**
