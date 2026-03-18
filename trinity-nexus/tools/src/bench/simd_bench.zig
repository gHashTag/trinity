const std = @import("std");
const simd = @import("simd_matmul.zig");

// Scalar implementations for comparison
fn scalarMatVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    for (0..rows) |i| {
        var sum: f32 = 0.0;
        const row_start = i * cols;
        for (0..cols) |j| {
            sum += mat[row_start + j] * vec[j];
        }
        output[i] = sum;
    }
}

fn scalarDot(a: []const f32, b: []const f32) f32 {
    var sum: f32 = 0.0;
    for (a, b) |x, y| {
        sum += x * y;
    }
    return sum;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("           SIMD vs SCALAR BENCHMARK\n", .{});
    std.debug.print("           phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Test sizes (typical LLM dimensions)
    const sizes = [_]struct { rows: usize, cols: usize }{
        .{ .rows = 2048, .cols = 2048 },   // Hidden size
        .{ .rows = 5632, .cols = 2048 },   // Intermediate
        .{ .rows = 32000, .cols = 2048 },  // Vocab projection
    };
    
    for (sizes) |size| {
        const rows = size.rows;
        const cols = size.cols;
        
        // Allocate
        const mat = try allocator.alloc(f32, rows * cols);
        defer allocator.free(mat);
        const vec = try allocator.alloc(f32, cols);
        defer allocator.free(vec);
        const output_scalar = try allocator.alloc(f32, rows);
        defer allocator.free(output_scalar);
        const output_simd = try allocator.alloc(f32, rows);
        defer allocator.free(output_simd);
        
        // Initialize with random data
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();
        for (mat) |*m| m.* = random.float(f32) - 0.5;
        for (vec) |*v| v.* = random.float(f32) - 0.5;
        
        const iterations = 10;
        
        // Benchmark scalar
        var scalar_time: u64 = 0;
        {
            var timer = try std.time.Timer.start();
            for (0..iterations) |_| {
                scalarMatVec(output_scalar, mat, vec, rows, cols);
            }
            scalar_time = timer.read();
        }
        
        // Benchmark SIMD
        var simd_time: u64 = 0;
        {
            var timer = try std.time.Timer.start();
            for (0..iterations) |_| {
                simd.simdMatVec(output_simd, mat, vec, rows, cols);
            }
            simd_time = timer.read();
        }
        
        // Verify correctness
        var max_diff: f32 = 0.0;
        for (output_scalar, output_simd) |s, m| {
            const diff = @abs(s - m);
            if (diff > max_diff) max_diff = diff;
        }
        
        const scalar_ms = @as(f64, @floatFromInt(scalar_time)) / 1e6;
        const simd_ms = @as(f64, @floatFromInt(simd_time)) / 1e6;
        const speedup = scalar_ms / simd_ms;
        
        std.debug.print("Matrix {d}x{d}:\n", .{rows, cols});
        std.debug.print("  Scalar: {d:.2} ms\n", .{scalar_ms});
        std.debug.print("  SIMD:   {d:.2} ms\n", .{simd_ms});
        std.debug.print("  Speedup: {d:.2}x\n", .{speedup});
        std.debug.print("  Max diff: {e}\n", .{max_diff});
        std.debug.print("\n", .{});
    }
    
    // Dot product benchmark
    std.debug.print("Dot product (2048 elements):\n", .{});
    const dot_size: usize = 2048;
    const a = try allocator.alloc(f32, dot_size);
    defer allocator.free(a);
    const b = try allocator.alloc(f32, dot_size);
    defer allocator.free(b);
    
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    for (a) |*x| x.* = random.float(f32);
    for (b) |*x| x.* = random.float(f32);
    
    const dot_iters = 100000;
    
    var scalar_dot_time: u64 = 0;
    var scalar_result: f32 = 0;
    {
        var timer = try std.time.Timer.start();
        for (0..dot_iters) |_| {
            scalar_result = scalarDot(a, b);
        }
        scalar_dot_time = timer.read();
    }
    
    var simd_dot_time: u64 = 0;
    var simd_result: f32 = 0;
    {
        var timer = try std.time.Timer.start();
        for (0..dot_iters) |_| {
            simd_result = simd.simdDot(a, b);
        }
        simd_dot_time = timer.read();
    }
    
    const scalar_dot_ms = @as(f64, @floatFromInt(scalar_dot_time)) / 1e6;
    const simd_dot_ms = @as(f64, @floatFromInt(simd_dot_time)) / 1e6;
    const dot_speedup = scalar_dot_ms / simd_dot_ms;
    
    std.debug.print("  Scalar: {d:.2} ms ({d} iters)\n", .{scalar_dot_ms, dot_iters});
    std.debug.print("  SIMD:   {d:.2} ms ({d} iters)\n", .{simd_dot_ms, dot_iters});
    std.debug.print("  Speedup: {d:.2}x\n", .{dot_speedup});
    std.debug.print("  Results: scalar={d:.6}, simd={d:.6}\n", .{scalar_result, simd_result});
}
