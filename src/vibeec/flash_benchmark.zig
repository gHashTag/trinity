// ═══════════════════════════════════════════════════════════════════════════════
// FLASH ATTENTION BENCHMARK
// Compare standard vs Flash Attention at different sequence lengths
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const flash = @import("flash_attention.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           FLASH ATTENTION BENCHMARK                          ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    const num_heads: usize = 32;
    const num_kv_heads: usize = 32;
    const head_dim: usize = 64;
    const iterations: usize = 100;

    // Test different sequence lengths (including long sequences)
    const seq_lengths = [_]usize{ 128, 256, 512, 1024, 2048, 4096 };

    std.debug.print("Config: {d} heads, {d} KV heads, {d} head_dim, {d} iterations\n\n", .{ num_heads, num_kv_heads, head_dim, iterations });
    std.debug.print("┌──────────┬────────────────┬────────────────┬──────────┐\n", .{});
    std.debug.print("│ Seq Len  │ Standard (ms)  │ Flash (ms)     │ Speedup  │\n", .{});
    std.debug.print("├──────────┼────────────────┼────────────────┼──────────┤\n", .{});

    for (seq_lengths) |seq_len| {
        const scale: f32 = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

        // Allocate test data
        const q = try allocator.alloc(f32, num_heads * head_dim);
        defer allocator.free(q);
        const k_cache = try allocator.alloc(f32, seq_len * num_kv_heads * head_dim);
        defer allocator.free(k_cache);
        const v_cache = try allocator.alloc(f32, seq_len * num_kv_heads * head_dim);
        defer allocator.free(v_cache);
        const output = try allocator.alloc(f32, num_heads * head_dim);
        defer allocator.free(output);

        // Initialize with random-ish values
        for (q, 0..) |*v, i| v.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
        for (k_cache, 0..) |*v, i| v.* = @cos(@as(f32, @floatFromInt(i)) * 0.1);
        for (v_cache, 0..) |*v, i| v.* = @sin(@as(f32, @floatFromInt(i)) * 0.2);

        // Benchmark standard attention
        var timer = try std.time.Timer.start();
        for (0..iterations) |_| {
            try flash.standardAttention(allocator, output, q, k_cache, v_cache, num_heads, num_kv_heads, head_dim, seq_len, scale);
        }
        const standard_time = timer.read();

        // Benchmark Flash attention
        timer.reset();
        for (0..iterations) |_| {
            try flash.flashAttentionGQA(allocator, output, q, k_cache, v_cache, num_heads, num_kv_heads, head_dim, seq_len, scale);
        }
        const flash_time = timer.read();

        const standard_ms = @as(f64, @floatFromInt(standard_time)) / 1e6 / @as(f64, @floatFromInt(iterations));
        const flash_ms = @as(f64, @floatFromInt(flash_time)) / 1e6 / @as(f64, @floatFromInt(iterations));
        const speedup = standard_ms / flash_ms;

        std.debug.print("│ {d:>8} │ {d:>14.3} │ {d:>14.3} │ {d:>7.2}x │\n", .{ seq_len, standard_ms, flash_ms, speedup });
    }

    std.debug.print("└──────────┴────────────────┴────────────────┴──────────┘\n", .{});
    std.debug.print("\nKOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
