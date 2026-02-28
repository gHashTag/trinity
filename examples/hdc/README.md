# Prand:] andwith]inanandya HDC :]

## Bywith] with]

### 1. :]inye HDC :]and

```zig
const std = @import("std");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // :] dina with] inefor]
    var a = try hdc.randomVector(allocator, 1000, 12345);
    defer a.deinit();
    var b = try hdc.randomVector(allocator, 1000, 67890);
    defer b.deinit();

    // Bind - with]ande awithabouttsandatsand
    var bound = try hdc.HyperVector.init(allocator, 1000);
    defer bound.deinit();
    hdc.bind(a.data, b.data, bound.data);

    // Unbind - andzin:]ande (with]andmaboutwitht)
    var recovered = try hdc.HyperVector.init(allocator, 1000);
    defer recovered.deinit();
    hdc.unbind(bound.data, b.data, recovered.data);

    // :]in:] with]withtinabout
    const sim = hdc.similarity(a.data, recovered.data);
    std.debug.print(":]withtinabout bywithle unbind: {d:.3}\n", .{sim});
}
```

### 2. :] tolawithandfandfor]

```zig
const clf = @import("../../src/phi-engine/hdc/online_classifier.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // :] tolawithandfandfor]
    var classifier = clf.OnlineClassifier.init(allocator, .{
        .dim = 1000,
        .learning_rate = 0.1,
    });
    defer classifier.deinit();

    // :] prand:] for dinatkh tolawithaboutin
    var class_a = try hdc.randomVector(allocator, 1000, 11111);
    defer class_a.deinit();
    var class_b = try hdc.randomVector(allocator, 1000, 22222);
    defer class_b.deinit();

    // :]
    try classifier.train(class_a.data, "toaboutshtoa");
    try classifier.train(class_b.data, "with]toa");

    // :]withfor]in:]
    const result = classifier.predict(class_a.data);
    std.debug.print(":]with: {s}, Uin:]witht: {d:.2}\n", .{
        result.label,
        result.confidence,
    });
}
```

### 3. RL :] in GridWorld

```zig
const rl = @import("../../src/phi-engine/hdc/rl_agent.zig");
const gw = @import("../../src/phi-engine/hdc/gridworld.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // :] with] 4x4
    var env = try gw.GridWorld.init(allocator, .{
        .width = 4,
        .height = 4,
    });
    defer env.deinit();

    // :] :]
    var agent = try rl.RLAgent.init(allocator, .{
        .num_actions = 4,
        .gamma = 0.95,
        .learning_rate = 0.1,
    });
    defer agent.deinit();

    try agent.initQTable(env.numStates());

    // :] 100 epand:]in
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

    std.debug.print(":]ande zain:]!\n", .{});
}
```

### 4. Pfromabouttoaboutinaya :memory]

```zig
const sm = @import("../../src/phi-engine/hdc/streaming_memory.zig");
const hdc = @import("../../src/phi-engine/hdc/hdc_core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // :] :memory]
    var mem = try sm.StreamingMemory.init(allocator, .{
        .dim = 2000,
        .forgetting_factor = 0.01,
    });
    defer mem.deinit();

    // :] for] and zon:]ande
    var key = try hdc.randomVector(allocator, 2000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 2000, 22222);
    defer value.deinit();

    // :]
    try mem.store(key.data, value.data);

    // Izinlefor]
    const result_buf = try allocator.alloc(hdc.Trit, 2000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);
    std.debug.print(":]: {}, Uin:]witht: {d:.3}\n", .{
        result.found,
        result.confidence,
    });

    // Prand:] :]inanande
    mem.applyForgetting(0.5);
    std.debug.print(":] bywithle :]inanandya\n", .{});
}
```

## :]withto prand:]in

```bash
# :]and:]andya and :]withto
cd examples/hdc
zig run example_basic.zig
zig run example_classifier.zig
zig run example_rl.zig
zig run example_memory.zig
```

## :] demo

```bash
# :]withto demo GridWorld with inand:]and:]andey
cd /workspaces/trinity
zig build-exe src/phi-engine/hdc/demo_gridworld.zig -O ReleaseFast
./demo_gridworld
```

---

**φ² + 1/φ² = 3 | TRINITY | HDC EXAMPLES**
