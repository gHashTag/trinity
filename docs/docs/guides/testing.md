---
sidebar_position: 3
---

# Testing Strategy

Comprehensive testing guide for Trinity applications. Learn test organization, unit testing, integration testing, and benchmark testing.

## Overview

Trinity provides a robust testing framework built on Zig's testing infrastructure:

| Test Type | Purpose | Tool |
|-----------|---------|------|
| **Unit Tests** | Test individual functions | `zig test` |
| **Integration Tests** | Test module interactions | Custom test runners |
| **Benchmarks** | Performance regression testing | `zig build bench` |
| **Property Tests** | Randomized testing | Custom fuzzers |

## Test Organization

### Directory Structure

```
trinity/
├── src/
│   ├── vsa.zig              # Main implementation
│   └── vsa_test.zig         # Unit tests (in same file)
├── tests/
│   ├── integration_tests.zig  # Integration tests
│   └── test_helpers.zig       # Test utilities
└── benchmarks/
    └── bench_vsa.zig        # Performance benchmarks
```

### Inline vs. Separate Test Files

Zig supports two approaches to testing:

#### Inline Tests (Recommended for Unit Tests)

```zig
// src/vsa.zig
const std = @import("std");
const testing = std.testing;

pub fn bind(a: *const HybridBigInt, b: *const HybridBigInt) !HybridBigInt {
    // Implementation
}

test "bind: self-inverse property" {
    const allocator = testing.allocator;

    var vec = try HybridBigInt.random(allocator, 100);
    defer vec.deinit(allocator);

    var result = try bind(&vec, &vec);
    defer result.deinit(allocator);

    // bind(A, A) should produce all +1s
    for (0..vec.len) |i| {
        try testing.expectEqual(@as(i2, 1), result.get(i));
    }
}

test "bind: unbind reverses bind" {
    const allocator = testing.allocator;

    var vec_a = try HybridBigInt.random(allocator, 100);
    defer vec_a.deinit(allocator);
    var vec_b = try HybridBigInt.random(allocator, 100);
    defer vec_b.deinit(allocator);

    var bound = try bind(&vec_a, &vec_b);
    defer bound.deinit(allocator);

    var recovered = try unbind(&bound, &vec_b);
    defer recovered.deinit(allocator);

    // unbind(bind(A, B), B) = A
    try testing.expectEqualDeep(vec_a, recovered);
}
```

#### Separate Test Files (Best for Integration Tests)

```zig
// tests/integration_tests.zig
const std = @import("std");
const testing = std.testing;
const vsa = @import("trinity/vsa");
const vm = @import("trinity/vm");

test "VSA + VM integration" {
    const allocator = testing.allocator;

    // Create VSA vectors
    var input = try vsa.HybridBigInt.random(allocator, 1000);
    defer input.deinit(allocator);
    var weights = try vsa.HybridBigInt.random(allocator, 1000);
    defer weights.deinit(allocator);

    // Bind in VSA
    var bound = try vsa.bind(&input, &weights);
    defer bound.deinit(allocator);

    // Convert to VM format
    var vm_input = try vm.Stack.fromHybridBigInt(&bound);
    defer vm_input.deinit(allocator);

    // Execute VM program
    var machine = try vm.Machine.init(allocator);
    defer machine.deinit();

    try machine.loadProgram(&[_]vm.Opcode{
        .push, .pop, .halt
    });

    try machine.execute();

    // Verify results
    try testing.expectEqual(@as(usize, 0), machine.stack.len);
}
```

## Unit Testing Guidelines

### Test Naming Conventions

```zig
// Pattern: <module>_<function>_<property_or_edge_case>
test "vsa_bind_self_inverse" { }
test "vsa_bind_unbind_reversal" { }
test "vsa_bind_empty_vectors" { }
test "vsa_bind_vector_size_mismatch" { }

// GOOD: Descriptive and specific
test "bundle3_majority_voting_with_all_same" { }

// BAD: Vague
test "bundle_test" { }
```

### Test Structure (AAA Pattern)

```zig
test "cosineSimilarity: identical vectors have similarity 1.0" {
    // Arrange
    const allocator = testing.allocator;
    var vec = try HybridBigInt.random(allocator, 1000);
    defer vec.deinit(allocator);

    // Act
    const similarity = try cosineSimilarity(&vec, &vec);

    // Assert
    try testing.expectApproxEqAbs(@as(f64, 1.0), similarity, 0.0001);
}
```

### Testing Error Conditions

```zig
test "bind: returns error for size mismatch" {
    const allocator = testing.allocator;

    var vec_a = try HybridBigInt.init(allocator, 100);
    defer vec_a.deinit(allocator);
    var vec_b = try HybridBigInt.init(allocator, 200);  // Different size
    defer vec_b.deinit(allocator);

    // Should return error.SizeMismatch
    try testing.expectError(
        error.SizeMismatch,
        bind(&vec_a, &vec_b)
    );
}
```

### Property-Based Testing

```zig
test "property: bind is self-inverse for all vectors" {
    const allocator = testing.allocator;
    const num_tests = 100;

    for (0..num_tests) |_| {
        var vec = try HybridBigInt.random(allocator, 1000);
        defer vec.deinit(allocator);

        var bound = try bind(&vec, &vec);
        defer bound.deinit(allocator);

        // All trits should be +1
        for (0..vec.len) |i| {
            try testing.expectEqual(@as(i2, 1), bound.get(i));
        }
    }
}

test "property: similarity is symmetric" {
    const allocator = testing.allocator;
    const num_tests = 100;

    for (0..num_tests) |_| {
        var vec_a = try HybridBigInt.random(allocator, 1000);
        defer vec_a.deinit(allocator);
        var vec_b = try HybridBigInt.random(allocator, 1000);
        defer vec_b.deinit(allocator);

        const sim_ab = try cosineSimilarity(&vec_a, &vec_b);
        const sim_ba = try cosineSimilarity(&vec_b, &vec_a);

        try testing.expectApproxEqAbs(sim_ab, sim_ba, 0.0001);
    }
}
```

### Test Helpers and Fixtures

```zig
// tests/test_helpers.zig
const std = @import("std");
const vsa = @import("trinity/vsa");

pub fn assertSimilarity(
    a: *const vsa.HybridBigInt,
    b: *const vsa.HybridBigInt,
    expected: f64,
    epsilon: f64
) !void {
    const actual = try vsa.cosineSimilarity(a, b);
    if (@abs(actual - expected) > epsilon) {
        std.debug.print(
            \\Expected similarity {d:.3}, got {d:.3}
        , .{ expected, actual });
        return error.SimilarityMismatch;
    }
}

// Usage in tests
test "similarity helper" {
    const allocator = std.testing.allocator;

    var vec = try vsa.HybridBigInt.random(allocator, 100);
    defer vec.deinit(allocator);

    try assertSimilarity(&vec, &vec, 1.0, 0.0001);
}
```

## Integration Testing

### Full Pipeline Testing

```zig
test "full pipeline: encode -> bind -> decode" {
    const allocator = testing.allocator;

    // Step 1: Encode text to VSA
    const text = "hello world";
    var encoded = try textEncoder.encode(allocator, text);
    defer encoded.deinit(allocator);

    // Step 2: Bind with key
    var key = try vsa.HybridBigInt.random(allocator, encoded.len);
    defer key.deinit(allocator);

    var bound = try vsa.bind(&encoded, &key);
    defer bound.deinit(allocator);

    // Step 3: Unbind
    var recovered = try vsa.unbind(&bound, &key);
    defer recovered.deinit(allocator);

    // Step 4: Decode back to text
    const decoded = try textEncoder.decode(allocator, &recovered);
    defer allocator.free(decoded);

    // Verify round-trip
    try testing.expectEqualStrings(text, decoded);
}
```

### Multi-Module Integration

```zig
test "VSA + VM + Firebird integration" {
    const allocator = testing.allocator;

    // 1. Create VSA hypervector
    var hypervector = try vsa.HybridBigInt.random(allocator, 10000);
    defer hypervector.deinit(allocator);

    // 2. Load into Firebird
    var firebird = try firebird.Model.load(allocator);
    defer firebird.deinit(allocator);

    try firebird.setHyperVector(&hypervector);

    // 3. Execute inference
    const input = "what is trinity?";
    const output = try firebird.inference(allocator, input);
    defer allocator.free(output);

    // 4. Verify output contains expected keywords
    const keywords = [_][]const u8{ "ternary", "vector", "symbolic" };
    for (keywords) |keyword| {
        const found = std.mem.indexOf(u8, output, keyword) != null;
        try testing.expect(found, "Missing keyword: {s}", .{keyword});
    }
}
```

### Testing with Real Data

```zig
test "real corpus: Wikipedia articles" {
    const allocator = testing.allocator;

    const corpus = &[_][]const u8{
        @embedFile("test_data/article1.txt"),
        @embedFile("test_data/article2.txt"),
        @embedFile("test_data/article3.txt"),
    };

    for (corpus) |article| {
        var encoded = try textEncoder.encode(allocator, article);
        defer encoded.deinit(allocator);

        // Should encode without errors
        try testing.expect(encoded.len > 0);

        // Should be able to decode back
        const decoded = try textEncoder.decode(allocator, &encoded);
        defer allocator.free(decoded);

        try testing.expectEqualStrings(article, decoded);
    }
}
```

## Benchmark Testing

### Microbenchmark Template

```zig
// benchmarks/bench_bind.zig
const std = @import("std");
const vsa = @import("trinity/vsa");
const Timer = std.time.Timer;

const ITERATIONS = 10_000;
const WARMUP = 100;

fn benchmarkBind(allocator: std.mem.Allocator, vec_size: usize) !void {
    var timer = try Timer.start();

    // Setup
    var vec_a = try vsa.HybridBigInt.random(allocator, vec_size);
    defer vec_a.deinit(allocator);
    var vec_b = try vsa.HybridBigInt.random(allocator, vec_size);
    defer vec_b.deinit(allocator);
    var result = try vsa.HybridBigInt.init(allocator, vec_size);
    defer result.deinit(allocator);

    // Warmup
    for (0..WARMUP) |_| {
        _ = try vsa.bind(&vec_a, &vec_b, &result);
    }

    // Benchmark
    const start = timer.lap();
    for (0..ITERATIONS) |_| {
        _ = try vsa.bind(&vec_a, &vec_b, &result);
    }
    const end = timer.read();

    // Report
    const elapsed_ns = end - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(ITERATIONS));
    const ops_per_sec = 1_000_000_000.0 / avg_ns;

    std.debug.print(
        \\bind() benchmark (size={}):
        \\  Total:     {d:.2} ms
        \\  Avg/op:    {d:.3} ns
        \\  Ops/sec:   {d:.0}
        \\  Throughput: {d:.2} M trits/sec
        \\
    , .{
        vec_size,
        @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0,
        avg_ns,
        ops_per_sec,
        @as(f64, @floatFromInt(vec_size)) * ops_per_sec / 1_000_000.0,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== VSA Bind Benchmarks ===\n\n", .{});

    const sizes = [_]usize{ 100, 1_000, 10_000, 100_000 };
    for (sizes) |size| {
        try benchmarkBind(allocator, size);
    }
}
```

### Regression Testing

```zig
// benchmarks/regression_tests.zig
const BenchmarkResult = struct {
    name: []const u8,
    avg_ns: f64,
    ops_per_sec: f64,
};

const BASELINE = [_]BenchmarkResult{
    .{ .name = "bind_1000",       .avg_ns = 45.2,  .ops_per_sec = 22_124_000 },
    .{ .name = "similarity_1000", .avg_ns = 32.1,  .ops_per_sec = 31_152_000 },
    .{ .name = "bundle_1000",     .avg_ns = 28.4,  .ops_per_sec = 35_211_000 },
};

fn checkRegression(current: BenchmarkResult) !void {
    for (BASELINE) |baseline| {
        if (std.mem.eql(u8, baseline.name, current.name)) {
            const change_pct = ((current.avg_ns - baseline.avg_ns) / baseline.avg_ns) * 100.0;

            if (change_pct > 10.0) {
                std.debug.print(
                    \\REGRESSION: {s}
                    \\  Baseline: {d:.3} ns/op
                    \\  Current:  {d:.3} ns/op
                    \\  Change:   +{d:.1}%
                    \\
                , .{ baseline.name, baseline.avg_ns, current.avg_ns, change_pct });
                return error.PerformanceRegression;
            }

            if (change_pct < -10.0) {
                std.debug.print(
                    \\IMPROVEMENT: {s}
                    \\  Baseline: {d:.3} ns/op
                    \\  Current:  {d:.3} ns/op
                    \\  Change:   {d:.1}%
                    \\
                , .{ baseline.name, baseline.avg_ns, current.avg_ns, change_pct });
            }

            return;
        }
    }

    std.debug.print("WARNING: No baseline found for {s}\n", .{current.name});
}
```

### Comparative Benchmarks

```zig
test "benchmark: packed vs unpacked performance" {
    const allocator = testing.allocator;
    const size = 10000;

    // Packed (HybridBigInt)
    var packed_a = try vsa.HybridBigInt.random(allocator, size);
    defer packed_a.deinit(allocator);
    var packed_b = try vsa.HybridBigInt.random(allocator, size);
    defer packed_b.deinit(allocator);

    var timer_packed = try std.time.Timer.start();
    const start_packed = timer_packed.lap();
    {
        var result = try vsa.HybridBigInt.init(allocator, size);
        defer result.deinit(allocator);
        _ = try vsa.bind(&packed_a, &packed_b, &result);
    }
    const elapsed_packed = timer_packed.read();

    // Unpacked ([]i2)
    var unpacked_a = try allocator.alloc(i2, size);
    defer allocator.free(unpacked_a);
    var unpacked_b = try allocator.alloc(i2, size);
    defer allocator.free(unpacked_b);

    // ... unpacked benchmark ...

    std.debug.print(
        \\Packed:   {d:.3} ns
        \\Unpacked: {d:.3} ns
        \\Speedup:  {d:.2}x
        \\
    , .{
        @as(f64, @floatFromInt(elapsed_packed)),
        @as(f64, @floatFromInt(elapsed_unpacked)),
        @as(f64, @floatFromInt(elapsed_unpacked)) / @as(f64, @floatFromInt(elapsed_packed)),
    });
}
```

## Running Tests

### Running All Tests

```bash
# Run all tests
zig build test

# Run with verbose output
zig build test --summary all

# Run specific test file
zig test src/vsa.zig

# Run specific test by name filter
zig test src/vsa.zig --test-filter "bind"
```

### Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.15.0

      - name: Run Tests
        run: |
          zig build test
          zig build bench

      - name: Check Formatting
        run: zig fmt --check src/
```

## Best Practices

### 1. Test Isolation

```zig
// GOOD: Each test is independent
test "test 1" {
    const allocator = testing.allocator;
    var vec = try HybridBigInt.random(allocator, 100);
    defer vec.deinit(allocator);
    // ...
}

test "test 2" {
    const allocator = testing.allocator;
    var vec = try HybridBigInt.random(allocator, 100);
    defer vec.deinit(allocator);
    // ... doesn't depend on test 1
}
```

### 2. Use Allocators Properly

```zig
// GOOD: Proper cleanup
test "with allocator" {
    const allocator = testing.allocator;

    var vec1 = try HybridBigInt.random(allocator, 100);
    defer vec1.deinit(allocator);

    var vec2 = try HybridBigInt.random(allocator, 100);
    defer vec2.deinit(allocator);

    // Even if error occurs, deferred cleanup runs
}
```

### 3. Test Edge Cases

```zig
test "edge cases" {
    const allocator = testing.allocator;

    // Empty vectors
    {
        var empty = try HybridBigInt.init(allocator, 0);
        defer empty.deinit(allocator);
        // Should handle gracefully
    }

    // Single trit
    {
        var single = try HybridBigInt.init(allocator, 1);
        defer single.deinit(allocator);
        // Should work with size=1
    }

    // All same values
    {
        var all_plus_one = try allocator.alloc(i2, 100);
        defer allocator.free(all_plus_one);
        @memset(all_plus_one, 1);
        // Test with all +1s
    }
}
```

### 4. Deterministic Tests

```zig
// GOOD: Seeded random for reproducibility
test "deterministic" {
    const allocator = testing.allocator;
    var rng = std.Random.DefaultPrng.init(42);  // Fixed seed

    var vec = try HybridBigInt.randomWith(allocator, &rng.random, 100);
    defer vec.deinit(allocator);

    // Always produces same sequence
}
```

## Test Coverage

```bash
# Generate coverage report (requires LLVM)
zig build test -femit-llvm -fcoverage-instrumentation

# Run tests to collect coverage
./zig-out/test/trinity-test

# Generate report
llvm-cov report -instr-profile=default.profdata \
  -object=zig-out/test/trinity-test
```

## Testing Checklist

Before committing code:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] No regression in benchmarks
- [ ] Edge cases covered
- [ ] Error paths tested
- [ ] Memory leaks checked (valgrind/sanitizers)
- [ ] Test coverage >80%

## Further Reading

- [Performance Tuning Guide](/guides/performance-tuning) — Benchmarking strategies
- [Security Best Practices](/guides/security) — Security testing
- [Benchmarks](/benchmarks/) — Performance metrics

---

**Happy testing!** For more help, join the [community forum](https://github.com/gHashTag/trinity/discussions).
