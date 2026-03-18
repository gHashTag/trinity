// ═══════════════════════════════════════════════════════════════════════════════
// VSA FPGA Benchmark — KOSCHEI Week 2
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmark: Zig roundtrip overhead for VSA FPGA operations
// Target: < 2 µs for 256-dim bind operation (with CPU fallback)
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa_fpga = @import("src/needle/vsa_fpga.zig");

const stdout_file = std.fs.File.stderr();
var write_buf: [4096]u8 = undefined;
var writer = stdout_file.writer(&write_buf);
const stdout = &writer.interface;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    try std.Io.Writer.print(stdout, "║  VSA FPGA Roundtrip Benchmark — KOSCHEI Week 2       ║\n", .{});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize FPGA accelerator (with CPU fallback)
    var fpga = try vsa_fpga.VSAFPGA.init(allocator);
    defer fpga.deinit();

    const is_hw = fpga.device != null;
    if (is_hw) {
        try std.Io.Writer.print(stdout, "🔥 FPGA hardware detected!\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "💻 Using CPU fallback (no FPGA device)\n", .{});
    }
    try std.Io.Writer.print(stdout, "\n", .{});

    // Test 1: Single bind operation
    try std.Io.Writer.print(stdout, "┌─ Test 1: Single 256-dim bind operation ─────────────────────┐\n", .{});
    var timer = try std.time.Timer.start();

    var vec_a = vsa_fpga.FPGAVector.init();
    var vec_b = vsa_fpga.FPGAVector.init();

    // Initialize with pattern
    for (0..128) |i| {
        vec_a.setTrit(i * 2, if (i % 2 == 0) .pos else .neg);
        vec_b.setTrit(i * 2, if (i % 3 == 0) .pos else .zero);
    }

    const bind_start = timer.read();
    const result = try fpga.bind(vec_a, vec_b);
    _ = result;
    const bind_end = timer.read();
    const bind_ns = bind_end - bind_start;
    const bind_us: f64 = @as(f64, @floatFromInt(bind_ns)) / 1000.0;

    try std.Io.Writer.print(stdout, "│  Latency: {d:.3} µs ({d} ns)\n", .{ bind_us, bind_ns });
    try std.Io.Writer.print(stdout, "│  Status: ", .{});
    if (bind_us < 2.0) {
        try std.Io.Writer.print(stdout, "✅ PASS (< 2 µs target)\n", .{});
    } else if (bind_us < 10.0) {
        try std.Io.Writer.print(stdout, "⚠️  WARNING (< 10 µs acceptable)\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "❌ FAIL (> 10 µs too slow)\n", .{});
    }
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 2: Throughput (1000 operations)
    try std.Io.Writer.print(stdout, "┌─ Test 2: Throughput (1000 bind operations) ──────────────────┐\n", .{});
    const n_ops: usize = 1000;

    const throughput_start = timer.read();
    var i: usize = 0;
    while (i < n_ops) : (i += 1) {
        // Alternate patterns
        vec_a.setTrit(i % 256, if (i % 2 == 0) .pos else .neg);
        vec_b.setTrit(i % 256, if (i % 3 == 0) .pos else .zero);

        const r = try fpga.bind(vec_a, vec_b);
        _ = r;
    }
    const throughput_end = timer.read();
    const throughput_ns = throughput_end - throughput_start;
    const throughput_us: f64 = @as(f64, @floatFromInt(throughput_ns)) / 1000.0;
    const avg_us = throughput_us / @as(f64, @floatFromInt(n_ops));
    const ops_per_sec: f64 = @as(f64, @floatFromInt(n_ops)) / (@as(f64, @floatFromInt(throughput_ns)) / 1_000_000_000.0);

    try std.Io.Writer.print(stdout, "│  Total time: {d:.2} µs\n", .{throughput_us});
    try std.Io.Writer.print(stdout, "│  Avg per op: {d:.3} µs\n", .{avg_us});
    try std.Io.Writer.print(stdout, "│  Throughput: {d:.0} ops/sec\n", .{ops_per_sec});
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 3: Needle format roundtrip
    try std.Io.Writer.print(stdout, "┌─ Test 3: Needle format roundtrip ─────────────────────────────┐\n", .{});

    // Create test vector in Needle format (i8 = {-1,0,1})
    const needle_vec_len = vsa_fpga.VSA_DIM;
    var needle_vec = try allocator.alloc(i8, needle_vec_len);
    defer allocator.free(needle_vec);

    for (0..needle_vec_len) |j| {
        needle_vec[j] = switch (j % 3) {
            0 => 1,
            1 => -1,
            else => 0,
        };
    }

    const roundtrip_start = timer.read();

    // Convert to FPGA format
    const fv_a = vsa_fpga.needleToFPGA(needle_vec);
    const fv_b = vsa_fpga.needleToFPGA(needle_vec);

    // Bind
    const fv_result = try fpga.bind(fv_a, fv_b);

    // Convert back
    const needle_result = try vsa_fpga.fpgaToNeedle(allocator, fv_result);
    defer allocator.free(needle_result);

    const roundtrip_end = timer.read();
    const roundtrip_ns = roundtrip_end - roundtrip_start;
    const roundtrip_us: f64 = @as(f64, @floatFromInt(roundtrip_ns)) / 1000.0;

    // Verify correctness
    var errors: usize = 0;
    for (0..@min(needle_vec_len, 50)) |j| {
        // Bind: x * x = 1 for non-zero x, 0 * 0 = 0
        const expected: i8 = if (needle_vec[j] == 0) 0 else 1;
        if (needle_result[j] != expected) errors += 1;
    }

    try std.Io.Writer.print(stdout, "│  Roundtrip time: {d:.3} µs\n", .{roundtrip_us});
    try std.Io.Writer.print(stdout, "│  Correctness: ", .{});
    if (errors == 0) {
        try std.Io.Writer.print(stdout, "✅ PASS (verified 50 trits)\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "❌ FAIL ({d} errors)\n", .{errors});
    }
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Summary
    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    try std.Io.Writer.print(stdout, "║  BENCHMARK SUMMARY                                       ║\n", .{});
    try std.Io.Writer.print(stdout, "╠════════════════════════════════════════════════════════════╣\n", .{});
    try std.Io.Writer.print(stdout, "║  Mode: {s:14}                                   ║\n", .{if (is_hw) "FPGA HW" else "CPU Fallback"});
    try std.Io.Writer.print(stdout, "║  Single bind: {d:.2} µs                                   ║\n", .{bind_us});
    try std.Io.Writer.print(stdout, "║  Throughput: {d:.0} ops/sec                             ║\n", .{ops_per_sec});
    try std.Io.Writer.print(stdout, "║  Roundtrip:  {d:.2} µs                                   ║\n", .{roundtrip_us});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n", .{});

    try std.Io.Writer.print(stdout, "\nφ² + 1/φ² = 3\n", .{});
    try std.Io.Writer.flush(stdout);
}
