// Diagnostic: Test RoPE values
const std = @import("std");
const transformer = @import("src/vibeec/gguf_transformer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const head_dim: usize = 64;
    const max_seq_len: usize = 2048;
    const theta: f32 = 10000.0;

    std.debug.print("=== RoPE DIAGNOSTIC ===\n\n", .{});
    std.debug.print("head_dim={d}, max_seq_len={d}, theta={d}\n\n", .{ head_dim, max_seq_len, theta });

    var rope = try transformer.RoPE.init(allocator, head_dim, max_seq_len, theta);
    defer rope.deinit();

    // Print cos/sin values for position 0
    std.debug.print("Position 0 cos values (first 10):\n", .{});
    for (0..10) |i| {
        std.debug.print("  [{d}] = {d:.6}\n", .{ i, rope.cos_cache[i] });
    }

    std.debug.print("\nPosition 0 sin values (first 10):\n", .{});
    for (0..10) |i| {
        std.debug.print("  [{d}] = {d:.6}\n", .{ i, rope.sin_cache[i] });
    }

    // Print for position 1
    std.debug.print("\nPosition 1 cos values (first 10):\n", .{});
    for (0..10) |i| {
        std.debug.print("  [{d}] = {d:.6}\n", .{ i, rope.cos_cache[head_dim + i] });
    }

    std.debug.print("\nPosition 1 sin values (first 10):\n", .{});
    for (0..10) |i| {
        std.debug.print("  [{d}] = {d:.6}\n", .{ i, rope.sin_cache[head_dim + i] });
    }

    // Test apply on a simple vector
    var test_vec: [64]f32 = undefined;
    for (&test_vec, 0..) |*v, i| {
        v.* = @floatFromInt(i + 1);
    }

    std.debug.print("\nBefore RoPE (first 8): ", .{});
    for (test_vec[0..8]) |v| {
        std.debug.print("{d:.2} ", .{v});
    }
    std.debug.print("\n", .{});

    rope.apply(&test_vec, 0);

    std.debug.print("After RoPE pos=0 (first 8): ", .{});
    for (test_vec[0..8]) |v| {
        std.debug.print("{d:.2} ", .{v});
    }
    std.debug.print("\n", .{});

    // Expected: at pos=0, angle=0 for all i, so cos=1, sin=0
    // x'[i] = x[i] * 1 - x[i+1] * 0 = x[i]
    // x'[i+1] = x[i] * 0 + x[i+1] * 1 = x[i+1]
    // So at pos=0, values should be unchanged!

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
