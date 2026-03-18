# Testing Tutorial

**15 minutes to learn testing in Trinity**

---

## Goal of This Tutorial

Learn how to write and run tests.

**What you'll learn:**
- How to write unit tests
- How to test VSA operations
- How to test VIBEE generated code
- How to run benchmarks

---

## Zig Testing Framework

Trinity uses Zig's built-in testing framework:

```zig
test "test name" {
    try std.testing.expectEqual(2, 1 + 1);
}
```

---

## Step 1: Write Your First Test

```zig
// tests/math_test.zig
const std = @import("std");

test "Golden Identity" {
    const phi: f64 = 1.618033988749895;
    const phi_sq = phi * phi;
    const result = phi_sq + 1.0 / phi_sq;

    try std.testing.expectApproxEqAbs(
        @as(f64, 3.0),
        result,
        1e-10
    );
}
```

**Run:**
```bash
zig test tests/math_test.zig
```

---

## Step 2: Test VSA Operations

```zig
// tests/vsa_test.zig
const std = @import("std");
const vsa = @import("vsa");

test "bind and unbind" {
    var allocator = std.testing.allocator;

    var key = try vsa.HybridBigInt.random(allocator, 100);
    defer key.deinit(allocator);

    var value = try vsa.HybridBigInt.random(allocator, 100);
    defer value.deinit(allocator);

    // Bind
    const bound = try vsa.bind(&key, &value);
    defer bound.deinit(allocator);

    // Unbind
    const retrieved = try vsa.unbind(&bound, &key);
    defer retrieved.deinit(allocator);

    // Check similarity
    const sim = vsa.cosineSimilarity(&value, &retrieved);
    try std.testing.expect(sim > 0.8); // Should be similar
}
```

---

## Step 3: Test Generated Code

```zig
// tests/generated_test.zig
const std = @import("std");
const Todo = @import("trinity/output/todo_manager.zig");

test "create_task" {
    const allocator = std.testing.allocator;
    const task = try Todo.createTask(allocator, "Test task");
    defer allocator.free(task.title);

    try std.testing.expectEqual(@as(i64, 0), task.id); // Placeholder
    try std.testing.expectEqual(false, task.completed);
}

test "add_and_complete_task" {
    const allocator = std.testing.allocator;
    var list = Todo.TaskList.init(allocator);
    defer list.tasks.deinit();

    const task = try Todo.createTask(allocator, "Test");
    defer allocator.free(task.title);

    try Todo.addTask(&list, task);
    try std.testing.expectEqual(@as(usize, 1), list.count);

    const found = Todo.completeTask(&list, task.id);
    try std.testing.expect(found);
}
```

---

## Step 4: Run All Tests

```bash
# Run all tests
zig build test

# Run specific file
zig test src/vsa.zig

# Run with verbose output
zig test --summary all

# Run tests in release mode
zig build test -Drelease
```

---

## Step 5: Benchmarks

```zig
// benchmarks/vsa_bench.zig
const std = @import("std");
const vsa = @import("vsa");

fn benchmarkBind(iterations: usize) !f64 {
    var allocator = std.testing.allocator;
    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var a = try vsa.HybridBigInt.random(allocator, 1000);
        defer a.deinit(allocator);
        var b = try vsa.HybridBigInt.random(allocator, 1000);
        defer b.deinit(allocator);
        const bound = try vsa.bind(&a, &b);
        _ = bound;
    }

    const elapsed = timer.read();
    return @as(f64, @floatFromInt(elapsed)) / 1_000_000.0; // ms
}

test "bind benchmark" {
    const iterations = 1000;
    const time_ms = try benchmarkBind(iterations);
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (time_ms / 1000.0);

    std.debug.print("Bind: {d:.2} ms for {} ops = {d:.0} ops/sec\n",
        .{ time_ms, iterations, ops_per_sec });
}
```

---

## Test Organization

```
tests/
├── unit/           # Unit tests
│   ├── math_test.zig
│   └── vsa_test.zig
├── integration/    # Integration tests
│   └── pipeline_test.zig
├── benchmarks/     # Benchmarks
│   └── vsa_bench.zig
└── generated/      # Generated code tests
    └── todo_test.zig
```

---

## Best Practices

| Rule | Description |
|------|-------------|
| **AAA** | Arrange-Act-Assert structure |
| **One assert** | One assert per test |
| **Descriptive names** | test "bind_returns_association" |
| **Cleanup** | defer for memory deallocation |
| **Table tests** | For many similar test cases |

---

## Example: Table Tests

```zig
test "triton multiplication" {
    const cases = [_]struct { trit: i3, a: i32, expected: i32 }{
        .{ .trit = -1, .a = 5, .expected = -5 },
        .{ .trit =  0, .a = 5, .expected =  0 },
        .{ .trit =  1, .a = 5, .expected =  5 },
    };

    inline for (cases) |case| {
        const result = tritonMul(case.a, case.trit);
        try std.testing.expectEqual(case.expected, result);
    };
}

fn tritonMul(a: i32, trit: i3) i32 {
    return switch (trit) {
        -1 => -a,
         0 =>  0,
         1 =>  a,
    };
}
```

---

## What's Next?

| Tutorial | Description |
|----------|-------------|
| [VSA Operations](vsa-operations.md) | VSA basics |
| [BitNet Inference](bitnet-inference.md) | LLM testing |

---

**φ² + 1/φ² = 3 = TRINITY**
