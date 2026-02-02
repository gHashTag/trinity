# Примеры использования HDC модуля

## Быстрый старт

### 1. Базовые HDC операции

```zig
const std = @import("std");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Создаём два случайных вектора
    var a = try hdc.randomVector(allocator, 1000, 12345);
    defer a.deinit();
    var b = try hdc.randomVector(allocator, 1000, 67890);
    defer b.deinit();

    // Bind - создание ассоциации
    var bound = try hdc.HyperVector.init(allocator, 1000);
    defer bound.deinit();
    hdc.bind(a.data, b.data, bound.data);

    // Unbind - извлечение (самообратимость)
    var recovered = try hdc.HyperVector.init(allocator, 1000);
    defer recovered.deinit();
    hdc.unbind(bound.data, b.data, recovered.data);

    // Проверяем сходство
    const sim = hdc.similarity(a.data, recovered.data);
    std.debug.print("Сходство после unbind: {d:.3}\n", .{sim});
}
```

### 2. Онлайн классификатор

```zig
const clf = @import("../../src/phi-engine/hdc/online_classifier.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Создаём классификатор
    var classifier = clf.OnlineClassifier.init(allocator, .{
        .dim = 1000,
        .learning_rate = 0.1,
    });
    defer classifier.deinit();

    // Создаём примеры для двух классов
    var class_a = try hdc.randomVector(allocator, 1000, 11111);
    defer class_a.deinit();
    var class_b = try hdc.randomVector(allocator, 1000, 22222);
    defer class_b.deinit();

    // Обучаем
    try classifier.train(class_a.data, "кошка");
    try classifier.train(class_b.data, "собака");

    // Предсказываем
    const result = classifier.predict(class_a.data);
    std.debug.print("Класс: {s}, Уверенность: {d:.2}\n", .{
        result.label,
        result.confidence,
    });
}
```

### 3. RL агент в GridWorld

```zig
const rl = @import("../../src/phi-engine/hdc/rl_agent.zig");
const gw = @import("../../src/phi-engine/hdc/gridworld.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Создаём среду 4x4
    var env = try gw.GridWorld.init(allocator, .{
        .width = 4,
        .height = 4,
    });
    defer env.deinit();

    // Создаём агента
    var agent = try rl.RLAgent.init(allocator, .{
        .num_actions = 4,
        .gamma = 0.95,
        .learning_rate = 0.1,
    });
    defer agent.deinit();

    try agent.initQTable(env.numStates());

    // Обучаем 100 эпизодов
    for (0..100) |_| {
        var state = env.reset();
        while (true) {
            const action = agent.selectAction(state);
            const result = env.step(action);
            _ = agent.tdUpdate(state, action, result.reward, result.next_state, result.done);
            state = result.next_state;
            if (result.done) break;
        }
        agent.decayEpsilon();
    }

    std.debug.print("Обучение завершено!\n", .{});
}
```

### 4. Потоковая память

```zig
const sm = @import("../../src/phi-engine/hdc/streaming_memory.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Создаём память
    var mem = try sm.StreamingMemory.init(allocator, .{
        .dim = 2000,
        .forgetting_factor = 0.01,
    });
    defer mem.deinit();

    // Создаём ключ и значение
    var key = try hdc.randomVector(allocator, 2000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 2000, 22222);
    defer value.deinit();

    // Сохраняем
    try mem.store(key.data, value.data);

    // Извлекаем
    const result_buf = try allocator.alloc(hdc.Trit, 2000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);
    std.debug.print("Найдено: {}, Уверенность: {d:.3}\n", .{
        result.found,
        result.confidence,
    });

    // Применяем забывание
    mem.applyForgetting(0.5);
    std.debug.print("Память после забывания\n", .{});
}
```

## Запуск примеров

```bash
# Компиляция и запуск
cd examples/hdc
zig run example_basic.zig
zig run example_classifier.zig
zig run example_rl.zig
zig run example_memory.zig
```

## Полное демо

```bash
# Запуск демо GridWorld с визуализацией
cd /workspaces/trinity
zig build-exe src/phi-engine/hdc/demo_gridworld.zig -O ReleaseFast
./demo_gridworld
```

---

**φ² + 1/φ² = 3 | TRINITY | HDC EXAMPLES**
