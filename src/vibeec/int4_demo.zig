// INT4 QUANTIZATION DEMO
// Demonstrates INT4 compression for LLM weights

const std = @import("std");
const quantizer = @import("trinity_quantizer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("INT4 QUANTIZATION DEMO\n", .{});
    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
    std.debug.print("\n", .{});

    // Simulate a weight tensor (like from a transformer layer)
    const tensor_size: usize = 1024 * 1024; // 1M elements = 4MB in f32
    std.debug.print("Creating test tensor: {d} elements ({d:.2} MB in f32)\n", .{ tensor_size, @as(f64, @floatFromInt(tensor_size * 4)) / 1e6 });

    const weights = try allocator.alloc(f32, tensor_size);
    defer allocator.free(weights);

    // Initialize with random-like values (simulating trained weights)
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    for (weights) |*w| {
        // Normal-ish distribution centered at 0
        const r1 = random.float(f32);
        const r2 = random.float(f32);
        const z = @sqrt(-2.0 * @log(r1 + 0.0001)) * @cos(2.0 * std.math.pi * r2);
        w.* = z * 0.1; // Scale to typical weight range
    }

    // Quantize
    std.debug.print("Quantizing to INT4...\n", .{});
    var timer = try std.time.Timer.start();

    var quant = try quantizer.quantizeTensor(allocator, weights);
    defer quantizer.deinitPacked(allocator, &quant);

    const quant_time = timer.read();
    std.debug.print("Quantization time: {d:.2} ms\n", .{@as(f64, @floatFromInt(quant_time)) / 1e6});

    // Dequantize
    std.debug.print("Dequantizing back to f32...\n", .{});
    timer.reset();

    const deq = try quantizer.dequantizeTensor(allocator, &quant);
    defer allocator.free(deq);

    const deq_time = timer.read();
    std.debug.print("Dequantization time: {d:.2} ms\n", .{@as(f64, @floatFromInt(deq_time)) / 1e6});

    // Calculate stats
    const stats = quantizer.calcStats(weights, &quant, deq);

    std.debug.print("\n", .{});
    std.debug.print("RESULTS\n", .{});
    std.debug.print("  Original size:    {d:.2} MB\n", .{@as(f64, @floatFromInt(stats.orig_size)) / 1e6});
    std.debug.print("  Quantized size:   {d:.2} MB\n", .{@as(f64, @floatFromInt(stats.quant_size)) / 1e6});
    std.debug.print("  Compression:      {d:.2}x\n", .{stats.ratio});
    std.debug.print("  Max error:        {d:.6}\n", .{stats.max_err});
    std.debug.print("  Mean error:       {d:.6}\n", .{stats.mean_err});

    // Project to 7B model
    const params_7b: u64 = 7_000_000_000;
    const orig_7b_gb = @as(f64, @floatFromInt(params_7b * 2)) / 1e9; // BF16
    const int4_7b_gb = orig_7b_gb / stats.ratio;

    std.debug.print("\n", .{});
    std.debug.print("PROJECTED FOR 7B MODEL\n", .{});
    std.debug.print("  Original (BF16):  {d:.2} GB\n", .{orig_7b_gb});
    std.debug.print("  INT4 quantized:   {d:.2} GB\n", .{int4_7b_gb});
    std.debug.print("  Fits in 8GB RAM:  {s}\n", .{if (int4_7b_gb < 7.5) "YES" else "NO"});

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}

test "demo" {
    // Just verify it compiles
}
