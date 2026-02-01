// TRINITY BENCHMARK - Code Generation Benchmark Suite
// Тестирование Trinity LLM на задачах кодинга
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const trinity_format = @import("trinity_format.zig");
const prometheus = @import("prometheus_seed.zig");
const simd = @import("simd_trit_ops.zig");
const engine = @import("trinity_inference_engine.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK TASKS (HumanEval-style)
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkTask = struct {
    id: []const u8,
    prompt: []const u8,
    expected_contains: []const u8, // Substring that should be in output
    language: []const u8,
};

pub const CODING_TASKS = [_]BenchmarkTask{
    .{
        .id = "fizzbuzz",
        .prompt = "Write a function fizzbuzz(n) that returns 'Fizz' if n is divisible by 3, 'Buzz' if divisible by 5, 'FizzBuzz' if divisible by both, otherwise the number as string.",
        .expected_contains = "def fizzbuzz",
        .language = "python",
    },
    .{
        .id = "factorial",
        .prompt = "Write a recursive function factorial(n) that returns n!",
        .expected_contains = "def factorial",
        .language = "python",
    },
    .{
        .id = "fibonacci",
        .prompt = "Write a function fibonacci(n) that returns the nth Fibonacci number.",
        .expected_contains = "def fibonacci",
        .language = "python",
    },
    .{
        .id = "is_prime",
        .prompt = "Write a function is_prime(n) that returns True if n is prime, False otherwise.",
        .expected_contains = "def is_prime",
        .language = "python",
    },
    .{
        .id = "reverse_string",
        .prompt = "Write a function reverse_string(s) that returns the reversed string.",
        .expected_contains = "def reverse",
        .language = "python",
    },
    .{
        .id = "sum_list",
        .prompt = "Write a function sum_list(lst) that returns the sum of all elements in the list.",
        .expected_contains = "def sum",
        .language = "python",
    },
    .{
        .id = "max_element",
        .prompt = "Write a function max_element(lst) that returns the maximum element in the list.",
        .expected_contains = "def max",
        .language = "python",
    },
    .{
        .id = "binary_search",
        .prompt = "Write a function binary_search(arr, target) that returns the index of target in sorted array arr, or -1 if not found.",
        .expected_contains = "def binary_search",
        .language = "python",
    },
    .{
        .id = "merge_sort",
        .prompt = "Write a function merge_sort(arr) that sorts the array using merge sort algorithm.",
        .expected_contains = "def merge",
        .language = "python",
    },
    .{
        .id = "gcd",
        .prompt = "Write a function gcd(a, b) that returns the greatest common divisor of a and b.",
        .expected_contains = "def gcd",
        .language = "python",
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    task_id: []const u8,
    passed: bool,
    output: []const u8,
    latency_ms: f64,
    tokens_generated: usize,
};

pub const BenchmarkStats = struct {
    total_tasks: usize,
    passed_tasks: usize,
    total_tokens: usize,
    total_time_ms: f64,

    pub fn passRate(self: *const BenchmarkStats) f64 {
        if (self.total_tasks == 0) return 0.0;
        return @as(f64, @floatFromInt(self.passed_tasks)) / @as(f64, @floatFromInt(self.total_tasks)) * 100.0;
    }

    pub fn tokensPerSecond(self: *const BenchmarkStats) f64 {
        if (self.total_time_ms == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_tokens)) / (self.total_time_ms / 1000.0);
    }
};

/// Simple token counter (approximation)
fn countTokens(text: []const u8) usize {
    var count: usize = 0;
    var in_word = false;
    for (text) |c| {
        if (c == ' ' or c == '\n' or c == '\t') {
            if (in_word) {
                count += 1;
                in_word = false;
            }
        } else {
            in_word = true;
        }
    }
    if (in_word) count += 1;
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MODEL LOADER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityModel = struct {
    allocator: std.mem.Allocator,
    reader: trinity_format.TrinityReader,
    config: ModelConfig,

    pub const ModelConfig = struct {
        vocab_size: u32,
        hidden_size: u32,
        num_layers: u32,
        num_heads: u32,
    };

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !TrinityModel {
        const reader = try trinity_format.TrinityReader.init(allocator, path);

        const config = ModelConfig{
            .vocab_size = reader.header.vocab_size,
            .hidden_size = reader.header.hidden_size,
            .num_layers = reader.header.num_layers,
            .num_heads = reader.header.num_heads,
        };

        return TrinityModel{
            .allocator = allocator,
            .reader = reader,
            .config = config,
        };
    }

    pub fn deinit(self: *TrinityModel) void {
        self.reader.deinit();
    }

    pub fn printInfo(self: *const TrinityModel) void {
        self.reader.printInfo();
    }

    /// Generate text (simplified - returns mock output for now)
    /// Real implementation would do full transformer inference
    pub fn generate(self: *TrinityModel, prompt: []const u8, max_tokens: usize) ![]u8 {
        _ = max_tokens;
        _ = prompt;

        // For now, return a placeholder
        // Real implementation would:
        // 1. Tokenize prompt
        // 2. Run through transformer layers
        // 3. Sample from output distribution
        // 4. Decode tokens to text

        const output = try self.allocator.alloc(u8, 256);
        const template = "def function():\n    # Implementation\n    pass\n";
        @memcpy(output[0..template.len], template);
        return output[0..template.len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK EXECUTION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: std.mem.Allocator, model_path: []const u8) !BenchmarkStats {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRINITY CODE BENCHMARK                             ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Model: {s:<53} ║\n", .{model_path[0..@min(model_path.len, 53)]});
    std.debug.print("║ Tasks: {d:<53} ║\n", .{CODING_TASKS.len});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Load model
    std.debug.print("\nLoading model...\n", .{});
    var model = TrinityModel.load(allocator, model_path) catch |err| {
        std.debug.print("⚠️  Failed to load model: {}\n", .{err});
        return BenchmarkStats{
            .total_tasks = 0,
            .passed_tasks = 0,
            .total_tokens = 0,
            .total_time_ms = 0,
        };
    };
    defer model.deinit();

    model.printInfo();

    var stats = BenchmarkStats{
        .total_tasks = CODING_TASKS.len,
        .passed_tasks = 0,
        .total_tokens = 0,
        .total_time_ms = 0,
    };

    std.debug.print("\nRunning benchmark tasks...\n", .{});
    std.debug.print("─────────────────────────────────────────────────────────────────\n", .{});

    for (CODING_TASKS) |task| {
        var timer = try std.time.Timer.start();

        // Generate code
        const output = model.generate(task.prompt, 256) catch |err| {
            std.debug.print("  [{s}] ❌ Error: {}\n", .{ task.id, err });
            continue;
        };
        defer allocator.free(output);

        const elapsed_ns = timer.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;

        // Check if output contains expected substring
        const passed = std.mem.indexOf(u8, output, task.expected_contains) != null;

        if (passed) {
            stats.passed_tasks += 1;
            std.debug.print("  [{s}] ✅ PASS ({d:.1}ms)\n", .{ task.id, elapsed_ms });
        } else {
            std.debug.print("  [{s}] ❌ FAIL ({d:.1}ms)\n", .{ task.id, elapsed_ms });
        }

        stats.total_tokens += countTokens(output);
        stats.total_time_ms += elapsed_ms;
    }

    // Print results
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           BENCHMARK RESULTS                                  ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Pass rate:        {d:>10.1}%                               ║\n", .{stats.passRate()});
    std.debug.print("║ Passed/Total:     {d:>5}/{d:<5}                               ║\n", .{ stats.passed_tasks, stats.total_tasks });
    std.debug.print("║ Total tokens:     {d:>10}                               ║\n", .{stats.total_tokens});
    std.debug.print("║ Total time:       {d:>10.1} ms                            ║\n", .{stats.total_time_ms});
    std.debug.print("║ Tokens/sec:       {d:>10.1}                               ║\n", .{stats.tokensPerSecond()});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    return stats;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFERENCE SPEED BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkInferenceSpeed(allocator: std.mem.Allocator, model_path: []const u8) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           INFERENCE SPEED BENCHMARK                          ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Load model
    var model = TrinityModel.load(allocator, model_path) catch |err| {
        std.debug.print("⚠️  Failed to load model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    // Benchmark matrix operations
    const hidden_size = model.config.hidden_size;
    const batch_size: usize = 1;

    std.debug.print("\nBenchmarking SIMD matmul ({d}x{d})...\n", .{ hidden_size, hidden_size });

    // Create test data
    const input = try allocator.alloc(f32, hidden_size);
    defer allocator.free(input);
    for (input) |*x| x.* = 0.5;

    const weights = try allocator.alloc(prometheus.TritWeight, hidden_size * hidden_size);
    defer allocator.free(weights);
    for (weights, 0..) |*w, i| {
        w.* = switch (i % 3) {
            0 => .pos,
            1 => .neg,
            else => .zero,
        };
    }

    const trit_buffer = try allocator.alloc(i8, weights.len);
    defer allocator.free(trit_buffer);
    for (weights, 0..) |w, i| {
        trit_buffer[i] = w.toInt();
    }

    const output = try allocator.alloc(f32, hidden_size);
    defer allocator.free(output);

    // Warmup
    for (0..10) |_| {
        simd.simdTritMatmul(output, input, trit_buffer, hidden_size, hidden_size);
    }

    // Benchmark
    const iterations: usize = 100;
    var timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        simd.simdTritMatmul(output, input, trit_buffer, hidden_size, hidden_size);
    }

    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const per_iter_ms = elapsed_ms / @as(f64, iterations);

    // Calculate throughput
    const ops_per_matmul = hidden_size * hidden_size * 2; // add + potential sub
    const gops = @as(f64, @floatFromInt(ops_per_matmul)) / (per_iter_ms * 1_000_000.0);

    // Estimate tokens/sec for full model
    // Rough estimate: 1 token = num_layers * 4 matmuls (Q, K, V, O) + 3 MLP matmuls
    const matmuls_per_token = model.config.num_layers * 7;
    const ms_per_token = per_iter_ms * @as(f64, @floatFromInt(matmuls_per_token));
    const tokens_per_sec = 1000.0 / ms_per_token;

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           SPEED RESULTS                                      ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Matrix size:      {d:>5} x {d:<5}                             ║\n", .{ hidden_size, hidden_size });
    std.debug.print("║ Per matmul:       {d:>10.3} ms                            ║\n", .{per_iter_ms});
    std.debug.print("║ Throughput:       {d:>10.2} GOP/s                         ║\n", .{gops});
    std.debug.print("║ Matmuls/token:    {d:>10}                               ║\n", .{matmuls_per_token});
    std.debug.print("║ Est. tokens/sec:  {d:>10.1}                               ║\n", .{tokens_per_sec});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    _ = batch_size;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: trinity_benchmark <model.tri> [speed]\n", .{});
        std.debug.print("  trinity_benchmark model.tri        - Run coding benchmark\n", .{});
        std.debug.print("  trinity_benchmark model.tri speed  - Run speed benchmark\n", .{});
        return;
    }

    const model_path = args[1];

    if (args.len > 2 and std.mem.eql(u8, args[2], "speed")) {
        try benchmarkInferenceSpeed(allocator, model_path);
    } else {
        _ = try runBenchmark(allocator, model_path);
    }
}

test "benchmark stats" {
    var stats = BenchmarkStats{
        .total_tasks = 10,
        .passed_tasks = 7,
        .total_tokens = 1000,
        .total_time_ms = 500.0,
    };

    try std.testing.expectEqual(@as(f64, 70.0), stats.passRate());
    try std.testing.expectEqual(@as(f64, 2000.0), stats.tokensPerSecond());
}

test "count tokens" {
    try std.testing.expectEqual(@as(usize, 4), countTokens("hello world foo bar"));
    try std.testing.expectEqual(@as(usize, 1), countTokens("hello"));
    try std.testing.expectEqual(@as(usize, 0), countTokens(""));
}
