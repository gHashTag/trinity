// KV-CACHE BENCHMARK - Сравнение скорости с и без KV-cache
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const mistral = @import("mistral_trinity.zig");
const kv_cache = @import("kv_cache.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runBenchmark(allocator);
}

pub fn runBenchmark(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           KV-CACHE BENCHMARK                                 ║\n", .{});
    std.debug.print("║           With vs Without KV-Cache                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Use mini config for fast testing
    const config = mistral.MistralConfig.initMini();

    std.debug.print("\nModel config:\n", .{});
    std.debug.print("  vocab_size: {d}\n", .{config.vocab_size});
    std.debug.print("  hidden_size: {d}\n", .{config.hidden_size});
    std.debug.print("  num_layers: {d}\n", .{config.num_hidden_layers});
    std.debug.print("  num_heads: {d}\n", .{config.num_attention_heads});
    std.debug.print("  num_kv_heads: {d}\n", .{config.num_key_value_heads});

    // Initialize model
    std.debug.print("\nInitializing model...\n", .{});
    var model = try mistral.MistralTrinity.init(allocator, config);
    defer model.deinit();

    const num_tokens = 100; // Longer sequence to see KV-cache benefit
    const warmup_iterations = 2;
    const benchmark_iterations = 5;

    // Warmup
    std.debug.print("\nWarming up...\n", .{});
    for (0..warmup_iterations) |_| {
        var token: u32 = 1;
        for (0..5) |pos| {
            token = try model.forward(token, pos);
        }
    }

    // Benchmark WITHOUT KV-cache
    std.debug.print("\nBenchmarking WITHOUT KV-cache...\n", .{});
    var timer = try std.time.Timer.start();

    for (0..benchmark_iterations) |_| {
        var token: u32 = 1;
        for (0..num_tokens) |pos| {
            token = try model.forward(token, pos);
        }
    }

    const no_cache_ns = timer.read();
    const no_cache_ms = @as(f64, @floatFromInt(no_cache_ns)) / 1_000_000.0;
    const no_cache_per_token = no_cache_ms / @as(f64, benchmark_iterations * num_tokens);
    const no_cache_tok_per_sec = 1000.0 / no_cache_per_token;

    // Initialize KV-cache
    std.debug.print("Initializing KV-cache...\n", .{});
    try model.initCache(num_tokens + 10);

    // Benchmark WITH KV-cache
    std.debug.print("Benchmarking WITH KV-cache...\n", .{});
    timer.reset();

    for (0..benchmark_iterations) |_| {
        model.resetCache();
        var token: u32 = 1;
        for (0..num_tokens) |pos| {
            token = try model.forwardWithCache(token, pos, true);
        }
    }

    const with_cache_ns = timer.read();
    const with_cache_ms = @as(f64, @floatFromInt(with_cache_ns)) / 1_000_000.0;
    const with_cache_per_token = with_cache_ms / @as(f64, benchmark_iterations * num_tokens);
    const with_cache_tok_per_sec = 1000.0 / with_cache_per_token;

    // Calculate speedup
    const speedup = no_cache_per_token / with_cache_per_token;

    // Print results
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           BENCHMARK RESULTS                                  ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tokens generated: {d:>10}                               ║\n", .{num_tokens});
    std.debug.print("║ Iterations:       {d:>10}                               ║\n", .{benchmark_iterations});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ WITHOUT KV-cache:                                            ║\n", .{});
    std.debug.print("║   Total time:     {d:>10.2} ms                            ║\n", .{no_cache_ms});
    std.debug.print("║   Per token:      {d:>10.3} ms                            ║\n", .{no_cache_per_token});
    std.debug.print("║   Tokens/sec:     {d:>10.1}                               ║\n", .{no_cache_tok_per_sec});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ WITH KV-cache:                                               ║\n", .{});
    std.debug.print("║   Total time:     {d:>10.2} ms                            ║\n", .{with_cache_ms});
    std.debug.print("║   Per token:      {d:>10.3} ms                            ║\n", .{with_cache_per_token});
    std.debug.print("║   Tokens/sec:     {d:>10.1}                               ║\n", .{with_cache_tok_per_sec});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ SPEEDUP:          {d:>10.2}x                              ║\n", .{speedup});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Print cache info
    if (model.cache) |*cache| {
        cache.printInfo();
    }
}

test "kv cache benchmark" {
    try runBenchmark(std.testing.allocator);
}
