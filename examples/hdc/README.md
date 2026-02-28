# Прand[CYR:[TRANSLATED]] andwith[TRANSLATED]]inанandя HDC [CYR:[TRANSLATED]]

## Быwith[TRANSLATED]] with[TRANSLATED]]

### 1. [CYR:[TRANSLATED]]inые HDC [CYR:[TRANSLATED]]and

```zig
const std = @import("std");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:[TRANSLATED]] дinа with[TRANSLATED]] inеfor[TRANSLATED]]
    var a = try hdc.randomVector(allocator, 1000, 12345);
    defer a.deinit();
    var b = try hdc.randomVector(allocator, 1000, 67890);
    defer b.deinit();

    // Bind - with[TRANSLATED]]andе аwithоцandацand
    var bound = try hdc.HyperVector.init(allocator, 1000);
    defer bound.deinit();
    hdc.bind(a.data, b.data, bound.data);

    // Unbind - andзin[CYR:[TRANSLATED]]andе (with[TRANSLATED]]andмоwithть)
    var recovered = try hdc.HyperVector.init(allocator, 1000);
    defer recovered.deinit();
    hdc.unbind(bound.data, b.data, recovered.data);

    // [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] with[TRANSLATED]]withтinо
    const sim = hdc.similarity(a.data, recovered.data);
    std.debug.print("[CYR:[TRANSLATED]]withтinо поwithле unbind: {d:.3}\n", .{sim});
}
```

### 2. [CYR:[TRANSLATED]] toлаwithandфandfor[TRANSLATED]]

```zig
const clf = @import("../../src/phi-engine/hdc/online_classifier.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:[TRANSLATED]] toлаwithandфandfor[TRANSLATED]]
    var classifier = clf.OnlineClassifier.init(allocator, .{
        .dim = 1000,
        .learning_rate = 0.1,
    });
    defer classifier.deinit();

    // [CYR:[TRANSLATED]] прand[CYR:[TRANSLATED]] for дinух toлаwithоin
    var class_a = try hdc.randomVector(allocator, 1000, 11111);
    defer class_a.deinit();
    var class_b = try hdc.randomVector(allocator, 1000, 22222);
    defer class_b.deinit();

    // [CYR:[TRANSLATED]]
    try classifier.train(class_a.data, "toошtoа");
    try classifier.train(class_b.data, "with[TRANSLATED]]toа");

    // [CYR:[TRANSLATED]]withfor[TRANSLATED]]in[CYR:[TRANSLATED]]
    const result = classifier.predict(class_a.data);
    std.debug.print("[CYR:[TRANSLATED]]with: {s}, Уin[CYR:[TRANSLATED]]withть: {d:.2}\n", .{
        result.label,
        result.confidence,
    });
}
```

### 3. RL [CYR:[TRANSLATED]] in GridWorld

```zig
const rl = @import("../../src/phi-engine/hdc/rl_agent.zig");
const gw = @import("../../src/phi-engine/hdc/gridworld.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:[TRANSLATED]] with[TRANSLATED]] 4x4
    var env = try gw.GridWorld.init(allocator, .{
        .width = 4,
        .height = 4,
    });
    defer env.deinit();

    // [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]
    var agent = try rl.RLAgent.init(allocator, .{
        .num_actions = 4,
        .gamma = 0.95,
        .learning_rate = 0.1,
    });
    defer agent.deinit();

    try agent.initQTable(env.numStates());

    // [CYR:[TRANSLATED]] 100 эпand[CYR:[TRANSLATED]]in
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

    std.debug.print("[CYR:[TRANSLATED]]andе заin[CYR:[TRANSLATED]]!\n", .{});
}
```

### 4. Пfromоtoоinая [CYR:memory]

```zig
const sm = @import("../../src/phi-engine/hdc/streaming_memory.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // [CYR:[TRANSLATED]] [CYR:memory]
    var mem = try sm.StreamingMemory.init(allocator, .{
        .dim = 2000,
        .forgetting_factor = 0.01,
    });
    defer mem.deinit();

    // [CYR:[TRANSLATED]] for[TRANSLATED]] and зon[CYR:[TRANSLATED]]andе
    var key = try hdc.randomVector(allocator, 2000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 2000, 22222);
    defer value.deinit();

    // [CYR:[TRANSLATED]]
    try mem.store(key.data, value.data);

    // Изinлеfor[TRANSLATED]]
    const result_buf = try allocator.alloc(hdc.Trit, 2000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);
    std.debug.print("[CYR:[TRANSLATED]]: {}, Уin[CYR:[TRANSLATED]]withть: {d:.3}\n", .{
        result.found,
        result.confidence,
    });

    // Прand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inанandе
    mem.applyForgetting(0.5);
    std.debug.print("[CYR:[TRANSLATED]] поwithле [CYR:[TRANSLATED]]inанandя\n", .{});
}
```

## [CYR:[TRANSLATED]]withto прand[CYR:[TRANSLATED]]in

```bash
# [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя and [CYR:[TRANSLATED]]withto
cd examples/hdc
zig run example_basic.zig
zig run example_classifier.zig
zig run example_rl.zig
zig run example_memory.zig
```

## [CYR:[TRANSLATED]] demo

```bash
# [CYR:[TRANSLATED]]withto demo GridWorld with inand[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andей
cd /workspaces/trinity
zig build-exe src/phi-engine/hdc/demo_gridworld.zig -O ReleaseFast
./demo_gridworld
```

---

**φ² + 1/φ² = 3 | TRINITY | HDC EXAMPLES**
