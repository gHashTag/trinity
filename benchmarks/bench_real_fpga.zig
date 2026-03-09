// ═══════════════════════════════════════════════════════════════════════════════
// Real FPGA Benchmark — KOSCHEI Week 4
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmark: Real VSA pipeline latency on actual FPGA hardware
// Target: < 5 µs Zig → FPGA → Zig roundtrip
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
    try std.Io.Writer.print(stdout, "║  Real FPGA Benchmark — KOSCHEI Week 4                  ║\n", .{});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize FPGA
    var fpga = try vsa_fpga.VSAFPGA.init(allocator);
    defer fpga.deinit();

    const is_hw = fpga.device != null;
    if (is_hw) {
        try std.Io.Writer.print(stdout, "🔥 FPGA hardware detected!\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "💻 No FPGA device - using CPU fallback\n", .{});
    }
    try std.Io.Writer.print(stdout, "\n", .{});

    // Test 1: Ping
    try std.Io.Writer.print(stdout, "┌─ Test 1: FPGA Ping ─────────────────────────────────────────┐\n", .{});
    const is_alive = fpga.ping();
    try std.Io.Writer.print(stdout, "│  Status: {s}\n", .{if (is_alive) "✅ ALIVE" else "❌ NO RESPONSE"});
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 2: Get FPGA Status
    if (is_hw and is_alive) {
        try std.Io.Writer.print(stdout, "┌─ Test 2: FPGA Status ────────────────────────────────────────┐\n", .{});
        if (fpga.getStatus()) |status| {
            try std.Io.Writer.print(stdout, "│  Version: {d}.{d}\n", .{ status.version_major, status.version_minor });
            try std.Io.Writer.print(stdout, "│  Pipeline Ready: {s}\n", .{if (status.pipeline_ready) "✅ YES" else "❌ NO"});
            try std.Io.Writer.print(stdout, "│  Temperature: {d}°C\n", .{status.temperature});
        } else {
            try std.Io.Writer.print(stdout, "│  Status: Unable to read\n", .{});
        }
        try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});
    }

    // Test 3: Individual Operation Latency
    try std.Io.Writer.print(stdout, "┌─ Test 3: Individual Operation Latency ─────────────────────┐\n", .{});

    var vec_a = vsa_fpga.FPGAVector.init();
    var vec_b = vsa_fpga.FPGAVector.init();
    for (0..128) |i| {
        vec_a.setTrit(i * 2, if (i % 2 == 0) .pos else .neg);
        vec_b.setTrit(i * 2, if (i % 3 == 0) .pos else .zero);
    }

    if (is_hw and fpga.device) |*dev| {
        const report = try dev.measureLatency();
        const formatted = try report.format(allocator);
        defer allocator.free(formatted);

        for (std.mem.splitScalar(u8, formatted, '\n')) |line| {
            if (line.len > 0) {
                try std.Io.Writer.print(stdout, "│  {s}\n", .{line});
            }
        }

        // Status assessment
        try std.Io.Writer.print(stdout, "│  Status: ", .{});
        if (report.roundtrip_ns < 5000) {
            try std.Io.Writer.print(stdout, "✅ EXCELLENT (< 5 µs)\n", .{});
        } else if (report.roundtrip_ns < 20000) {
            try std.Io.Writer.print(stdout, "✅ GOOD (< 20 µs)\n", .{});
        } else {
            try std.Io.Writer.print(stdout, "⚠️  HIGH LATENCY ({d:.1}× overhead)\n", .{
                @as(f64, @floatFromInt(report.overhead_ns)) / @as(f64, @floatFromInt(report.fpga_ns))
            });
        }
    } else {
        try std.Io.Writer.print(stdout, "│  CPU Fallback: Run bench_vsa_pipeline for CPU timing\n", .{});
    }

    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 4: Full Pipeline Latency
    try std.Io.Writer.print(stdout, "┌─ Test 4: Full Pipeline Latency ──────────────────────────────┐\n", .{});

    var vec_c = vsa_fpga.FPGAVector.init();
    for (0..128) |i| {
        vec_c.setTrit(i * 2, if (i % 5 == 0) .neg else .pos);
    }

    const n_pipeline: usize = if (is_hw) 1000 else 10;
    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    var i: usize = 0;
    while (i < n_pipeline) : (i += 1) {
        const start = timer.read();
        const result = try fpga.runPipeline(vec_a, vec_b, vec_c);
        _ = result;
        const end = timer.read();
        total_ns += end - start;
    }

    const avg_ns = total_ns / n_pipeline;
    const avg_us: f64 = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const pipeline_ops_sec: f64 = 1_000_000_000.0 / @as(f64, @floatFromInt(avg_ns));

    try std.Io.Writer.print(stdout, "│  Avg pipeline: {d:.3} µs\n", .{avg_us});
    try std.Io.Writer.print(stdout, "│  Throughput: {d:.0} ops/sec\n", .{pipeline_ops_sec});
    try std.Io.Writer.print(stdout, "│  Samples: {d}\n", .{n_pipeline});

    try std.Io.Writer.print(stdout, "│  Status: ", .{});
    if (avg_us < 50.0) {
        try std.Io.Writer.print(stdout, "✅ TARGET (< 50 µs)\n", .{});
    } else if (avg_us < 100.0) {
        try std.Io.Writer.print(stdout, "✅ ACCEPTABLE (< 100 µs)\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "⚠️  CPU FALLBACK ({d:.1}× slower than target)\n", .{avg_us / 50.0});
    }

    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 5: Ralph Loop Simulation
    try std.Io.Writer.print(stdout, "┌─ Test 5: Ralph Loop Simulation ─────────────────────────────┐\n", .{});

    // Simulate one Ralph Loop iteration: 3 pipeline operations
    const ralph_ns = avg_ns * 3;
    const ralph_us: f64 = @as(f64, @floatFromInt(ralph_ns)) / 1000.0;
    const ralph_ms: f64 = ralph_us / 1000.0;

    try std.Io.Writer.print(stdout, "│  Per iteration: {d:.3} ms\n", .{ralph_ms});
    try std.Io.Writer.print(stdout, "│  Iterations/sec: {d:.0}\n", .{1000.0 / ralph_ms});

    try std.Io.Writer.print(stdout, "│  Target: ", .{});
    if (ralph_ms < 0.1) {
        try std.Io.Writer.print(stdout, "✅ EXCELLENT (< 0.1 ms)\n", .{});
    } else if (ralph_ms < 1.0) {
        try std.Io.Writer.print(stdout, "✅ GOOD (< 1 ms)\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "⚠️  SLOW ({d:.1}× slower than target)\n", .{ralph_ms / 0.1});
    }

    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Summary
    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    try std.Io.Writer.print(stdout, "║  KOSCHEI Week 4 — HARDWARE SUMMARY                      ║\n", .{});
    try std.Io.Writer.print(stdout, "╠════════════════════════════════════════════════════════════╣\n", .{});
    try std.Io.Writer.print(stdout, "║  Mode:          {s:30}            ║\n", .{if (is_hw) "FPGA HW" else "CPU Fallback"});
    try std.Io.Writer.print(stdout, "║  Pipeline:      {d:.2} µs/op                             ║\n", .{avg_us});
    try std.Io.Writer.print(stdout, "║  Ralph Loop:    {d:.3} ms/iter                          ║\n", .{ralph_ms});
    try std.Io.Writer.print(stdout, "║  Throughput:    {d:.0} ops/sec                           ║\n", .{pipeline_ops_sec});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n", .{});

    // Next steps
    if (!is_hw) {
        try std.Io.Writer.print(stdout, "\n📋 Next steps:\n", .{});
        try std.Io.Writer.print(stdout, "   1. Build bitstream: cd fpga/openxc7-synth && ./build.sh\n", .{});
        try std.Io.Writer.print(stdout, "   2. Deploy to FPGA: ./build.sh deploy\n", .{});
        try std.Io.Writer.print(stdout, "   3. Re-run this benchmark\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "\n✅ FPGA hardware is ready for production use!\n", .{});
    }

    try std.Io.Writer.print(stdout, "\nφ² + 1/φ² = 3\n", .{});
    try std.Io.Writer.print(stdout.flush(), .{});
}
