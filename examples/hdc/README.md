# Прand[CYR:меры] andwith[CYR:пользо]inанandя HDC [CYR:модуля]

## Быwith[CYR:трый] with[CYR:тарт]

### 1. [CYR:Базо]inые HDC [CYR:операц]andand

```zig
const std = @import("std");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:Создаём] дinа with[CYR:лучайных] inеto[CYR:тора]
    var a = try hdc.randomVector(allocator, 1000, 12345);
    defer a.deinit();
    var b = try hdc.randomVector(allocator, 1000, 67890);
    defer b.deinit();

    // Bind - with[CYR:оздан]andе аwithwithоцandацandand
    var bound = try hdc.HyperVector.init(allocator, 1000);
    defer bound.deinit();
    hdc.bind(a.data, b.data, bound.data);

    // Unbind - andзin[CYR:лечен]andе (with[CYR:амообрат]andмоwithть)
    var recovered = try hdc.HyperVector.init(allocator, 1000);
    defer recovered.deinit();
    hdc.unbind(bound.data, b.data, recovered.data);

    // [CYR:Про]in[CYR:еряем] with[CYR:ход]withтinо
    const sim = hdc.similarity(a.data, recovered.data);
    std.debug.print("[CYR:Сход]withтinо поwithле unbind: {d:.3}\n", .{sim});
}
```

### 2. [CYR:Онлайн] toлаwithwithandфandto[CYR:атор]

```zig
const clf = @import("../../src/phi-engine/hdc/online_classifier.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:Создаём] toлаwithwithandфandto[CYR:атор]
    var classifier = clf.OnlineClassifier.init(allocator, .{
        .dim = 1000,
        .learning_rate = 0.1,
    });
    defer classifier.deinit();

    // [CYR:Создаём] прand[CYR:меры] for дinух toлаwithwithоin
    var class_a = try hdc.randomVector(allocator, 1000, 11111);
    defer class_a.deinit();
    var class_b = try hdc.randomVector(allocator, 1000, 22222);
    defer class_b.deinit();

    // [CYR:Обучаем]
    try classifier.train(class_a.data, "toошtoа");
    try classifier.train(class_b.data, "with[CYR:оба]toа");

    // [CYR:Пред]withto[CYR:азы]in[CYR:аем]
    const result = classifier.predict(class_a.data);
    std.debug.print("[CYR:Кла]withwith: {s}, Уin[CYR:еренно]withть: {d:.2}\n", .{
        result.label,
        result.confidence,
    });
}
```

### 3. RL [CYR:агент] in GridWorld

```zig
const rl = @import("../../src/phi-engine/hdc/rl_agent.zig");
const gw = @import("../../src/phi-engine/hdc/gridworld.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:Создаём] with[CYR:реду] 4x4
    var env = try gw.GridWorld.init(allocator, .{
        .width = 4,
        .height = 4,
    });
    defer env.deinit();

    // [CYR:Создаём] [CYR:агента]
    var agent = try rl.RLAgent.init(allocator, .{
        .num_actions = 4,
        .gamma = 0.95,
        .learning_rate = 0.1,
    });
    defer agent.deinit();

    try agent.initQTable(env.numStates());

    // [CYR:Обучаем] 100 эпand[CYR:зодо]in
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

    std.debug.print("[CYR:Обучен]andе заin[CYR:ершено]!\n", .{});
}
```

### 4. Пfromоtoоinая [CYR:память]

```zig
const sm = @import("../../src/phi-engine/hdc/streaming_memory.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:Создаём] [CYR:память]
    var mem = try sm.StreamingMemory.init(allocator, .{
        .dim = 2000,
        .forgetting_factor = 0.01,
    });
    defer mem.deinit();

    // [CYR:Создаём] to[CYR:люч] and зon[CYR:чен]andе
    var key = try hdc.randomVector(allocator, 2000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 2000, 22222);
    defer value.deinit();

    // [CYR:Сохраняем]
    try mem.store(key.data, value.data);

    // Изinлеto[CYR:аем]
    const result_buf = try allocator.alloc(hdc.Trit, 2000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);
    std.debug.print("[CYR:Найдено]: {}, Уin[CYR:еренно]withть: {d:.3}\n", .{
        result.found,
        result.confidence,
    });

    // Прand[CYR:меняем] [CYR:забы]inанandе
    mem.applyForgetting(0.5);
    std.debug.print("[CYR:Память] поwithле [CYR:забы]inанandя\n", .{});
}
```

## [CYR:Запу]withto прand[CYR:меро]in

```bash
# [CYR:Комп]and[CYR:ляц]andя and [CYR:запу]withto
cd examples/hdc
zig run example_basic.zig
zig run example_classifier.zig
zig run example_rl.zig
zig run example_memory.zig
```

## [CYR:Полное] demo

```bash
# [CYR:Запу]withto demo GridWorld with inand[CYR:зуал]and[CYR:зац]andей
cd /workspaces/trinity
zig build-exe src/phi-engine/hdc/demo_gridworld.zig -O ReleaseFast
./demo_gridworld
```

---

**φ² + 1/φ² = 3 | TRINITY | HDC EXAMPLES**
