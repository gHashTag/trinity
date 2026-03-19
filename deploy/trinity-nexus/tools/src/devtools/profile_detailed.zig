// Detailed profiling of inference components
const std = @import("std");
const simd = @import("simd_matmul.zig");
const inference = @import("gguf_inference.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("           DETAILED COMPONENT PROFILER\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // TinyLlama dimensions
    const hidden_size: usize = 2048;
    const intermediate_size: usize = 5632;
    const num_heads: usize = 32;
    const head_dim: usize = 64;
    const vocab_size: usize = 32000;
    const num_layers: usize = 22;

    // Allocate test data
    const mat_qkv = try allocator.alloc(f32, hidden_size * hidden_size);
    defer allocator.free(mat_qkv);
    const mat_ffn = try allocator.alloc(f32, intermediate_size * hidden_size);
    defer allocator.free(mat_ffn);
    const mat_output = try allocator.alloc(f32, vocab_size * hidden_size);
    defer allocator.free(mat_output);
    const vec = try allocator.alloc(f32, hidden_size);
    defer allocator.free(vec);
    const out_hidden = try allocator.alloc(f32, hidden_size);
    defer allocator.free(out_hidden);
    const out_inter = try allocator.alloc(f32, intermediate_size);
    defer allocator.free(out_inter);
    const out_vocab = try allocator.alloc(f32, vocab_size);
    defer allocator.free(out_vocab);

    // Initialize
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    for (mat_qkv) |*m| m.* = random.float(f32) - 0.5;
    for (mat_ffn) |*m| m.* = random.float(f32) - 0.5;
    for (mat_output) |*m| m.* = random.float(f32) - 0.5;
    for (vec) |*v| v.* = random.float(f32) - 0.5;

    const iterations = 22; // One per layer

    // Profile QKV projection (3x per layer)
    var qkv_time: u64 = 0;
    {
        var timer = try std.time.Timer.start();
        for (0..iterations * 3) |_| {
            simd.simdMatVec(out_hidden, mat_qkv, vec, hidden_size, hidden_size);
        }
        qkv_time = timer.read();
    }

    // Profile FFN (3x per layer: gate, up, down)
    var ffn_time: u64 = 0;
    {
        var timer = try std.time.Timer.start();
        for (0..iterations * 2) |_| {
            simd.simdMatVec(out_inter, mat_ffn, vec, intermediate_size, hidden_size);
        }
        for (0..iterations) |_| {
            simd.simdMatVec(out_hidden, mat_ffn, out_inter[0..hidden_size], hidden_size, intermediate_size);
        }
        ffn_time = timer.read();
    }

    // Profile output projection (1x total)
    var output_time: u64 = 0;
    {
        var timer = try std.time.Timer.start();
        simd.simdMatVec(out_vocab, mat_output, vec, vocab_size, hidden_size);
        output_time = timer.read();
    }

    // Profile attention dot products (32 heads * seq_len)
    const seq_len: usize = 10;
    var attn_time: u64 = 0;
    {
        var timer = try std.time.Timer.start();
        for (0..iterations * num_heads * seq_len) |_| {
            _ = simd.simdDot(vec[0..head_dim], vec[0..head_dim]);
        }
        attn_time = timer.read();
    }

    const total_time = qkv_time + ffn_time + output_time + attn_time;

    std.debug.print("COMPONENT BREAKDOWN (simulated 1 token):\n", .{});
    std.debug.print("  QKV projections:  {d:.1} ms ({d:.1}%)\n", .{
        @as(f64, @floatFromInt(qkv_time)) / 1e6,
        @as(f64, @floatFromInt(qkv_time)) / @as(f64, @floatFromInt(total_time)) * 100,
    });
    std.debug.print("  FFN projections:  {d:.1} ms ({d:.1}%)\n", .{
        @as(f64, @floatFromInt(ffn_time)) / 1e6,
        @as(f64, @floatFromInt(ffn_time)) / @as(f64, @floatFromInt(total_time)) * 100,
    });
    std.debug.print("  Output projection: {d:.1} ms ({d:.1}%)\n", .{
        @as(f64, @floatFromInt(output_time)) / 1e6,
        @as(f64, @floatFromInt(output_time)) / @as(f64, @floatFromInt(total_time)) * 100,
    });
    std.debug.print("  Attention dots:   {d:.1} ms ({d:.1}%)\n", .{
        @as(f64, @floatFromInt(attn_time)) / 1e6,
        @as(f64, @floatFromInt(attn_time)) / @as(f64, @floatFromInt(total_time)) * 100,
    });
    std.debug.print("  TOTAL:            {d:.1} ms\n", .{@as(f64, @floatFromInt(total_time)) / 1e6});
    std.debug.print("\n", .{});

    // Theoretical vs actual
    const total_ops = (3 * hidden_size * hidden_size + 3 * hidden_size * intermediate_size) * num_layers + vocab_size * hidden_size;
    const gflops = @as(f64, @floatFromInt(total_ops)) * 2.0 / (@as(f64, @floatFromInt(total_time)) / 1e9) / 1e9;
    std.debug.print("  Total ops: {d:.1}M\n", .{@as(f64, @floatFromInt(total_ops)) / 1e6});
    std.debug.print("  Achieved: {d:.2} GFLOPS\n", .{gflops});
}
