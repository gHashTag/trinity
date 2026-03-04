// ═══════════════════════════════════════════════════════════════════════════════
// VSA Pipeline Benchmark — KOSCHEI Week 3
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmark: Full VSA pipeline (Bind → Bundle → Similarity)
// Target: < 50 ns on FPGA, < 20 µs Zig roundtrip with fallback
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
    try std.Io.Writer.print(stdout, "║  VSA Pipeline Benchmark — KOSCHEI Week 3              ║\n", .{});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize FPGA
    var fpga = try vsa_fpga.VSAFPGA.init(allocator);
    defer fpga.deinit();

    const is_hw = fpga.device != null;
    if (is_hw) {
        try std.Io.Writer.print(stdout, "🔥 FPGA hardware detected!\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "💻 Using CPU fallback (no FPGA device)\n", .{});
    }
    try std.Io.Writer.print(stdout, "\n", .{});

    var timer = try std.time.Timer.start();

    // Test 1: Individual operations
    try std.Io.Writer.print(stdout, "┌─ Test 1: Individual Operations ─────────────────────────────┐\n", .{});

    var vec_a = vsa_fpga.FPGAVector.init();
    var vec_b = vsa_fpga.FPGAVector.init();
    var vec_c = vsa_fpga.FPGAVector.init();

    // Initialize with test pattern
    for (0..128) |i| {
        vec_a.setTrit(i * 2, if (i % 2 == 0) .pos else .neg);
        vec_b.setTrit(i * 2, if (i % 3 == 0) .pos else .zero);
        vec_c.setTrit(i * 2, if (i % 5 == 0) .neg else .pos);
    }

    // Bind
    const bind_start = timer.read();
    const bound = try fpga.bind(vec_a, vec_b);
    const bind_end = timer.read();
    const bind_ns = bind_end - bind_start;
    const bind_us: f64 = @as(f64, @floatFromInt(bind_ns)) / 1000.0;

    // Bundle
    const bundle_start = timer.read();
    const bundled = vsa_fpga.bundleCPU(&[_]vsa_fpga.FPGAVector{ vec_a, vec_b, vec_c });
    _ = bundled;
    const bundle_end = timer.read();
    const bundle_ns = bundle_end - bundle_start;
    const bundle_us: f64 = @as(f64, @floatFromInt(bundle_ns)) / 1000.0;

    // Similarity
    const sim_start = timer.read();
    const sim = vsa_fpga.similarityCPU(vec_a, vec_b);
    const sim_end = timer.read();
    const sim_ns = sim_end - sim_start;
    const sim_us: f64 = @as(f64, @floatFromInt(sim_ns)) / 1000.0;

    _ = bound;

    try std.Io.Writer.print(stdout, "│  Bind:       {d:.3} µs\n", .{bind_us});
    try std.Io.Writer.print(stdout, "│  Bundle:     {d:.3} µs\n", .{bundle_us});
    try std.Io.Writer.print(stdout, "│  Similarity: {d:.3} µs\n", .{sim_us});
    try std.Io.Writer.print(stdout, "│  Sim score:  {d:.4}\n", .{sim});
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 2: Full Pipeline (bind + bundle + sim)
    try std.Io.Writer.print(stdout, "┌─ Test 2: Full Pipeline (Bind → Bundle → Similarity) ────────┐\n", .{});

    const n_ops: usize = 1000;
    const pipeline_start = timer.read();

    var i: usize = 0;
    while (i < n_ops) : (i += 1) {
        // Alternate patterns
        vec_a.setTrit(i % 256, if (i % 2 == 0) .pos else .neg);
        vec_b.setTrit(i % 256, if (i % 3 == 0) .pos else .zero);
        vec_c.setTrit(i % 256, if (i % 5 == 0) .neg else .pos);

        const result = try fpga.runPipeline(vec_a, vec_b, vec_c);
        _ = result;
    }

    const pipeline_end = timer.read();
    const pipeline_ns = pipeline_end - pipeline_start;
    const pipeline_us: f64 = @as(f64, @floatFromInt(pipeline_ns)) / 1000.0;
    const avg_us = pipeline_us / @as(f64, @floatFromInt(n_ops));
    const ops_per_sec: f64 = @as(f64, @floatFromInt(n_ops)) / (@as(f64, @floatFromInt(pipeline_ns)) / 1_000_000_000.0);

    try std.Io.Writer.print(stdout, "│  Total time:   {d:.2} µs\n", .{pipeline_us});
    try std.Io.Writer.print(stdout, "│  Avg per op:  {d:.3} µs\n", .{avg_us});
    try std.Io.Writer.print(stdout, "│  Throughput:   {d:.0} ops/sec\n", .{ops_per_sec});
    try std.Io.Writer.print(stdout, "│  Status: ", .{});
    if (avg_us < 0.05) {
        try std.Io.Writer.print(stdout, "✅ EXCELLENT (< 50 ns FPGA target)\n", .{});
    } else if (avg_us < 10.0) {
        try std.Io.Writer.print(stdout, "✅ GOOD (< 10 µs)\n", .{});
    } else {
        try std.Io.Writer.print(stdout, "⚠️  CPU fallback ({d:.1}× slower than FPGA)\n", .{avg_us / 0.05});
    }
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Test 3: Pipeline Search
    try std.Io.Writer.print(stdout, "┌─ Test 3: Pipeline Search (100 vectors) ────────────────────────┐\n", .{});

    const n_vectors: usize = 100;
    var vectors = try allocator.alloc(vsa_fpga.FPGAVector, n_vectors);
    defer allocator.free(vectors);

    for (0..n_vectors) |j| {
        vectors[j] = vsa_fpga.FPGAVector.init();
        for (0..64) |k| {
            vectors[j].setTrit(k, if ((j + k) % 3 == 0) .pos else if ((j + k) % 3 == 1) .neg else .zero);
        }
    }

    var query_local = vsa_fpga.FPGAVector.init();
    for (0..64) |k| {
        query_local.setTrit(k, if (k % 2 == 0) .pos else .zero);
    }

    const search_start = timer.read();
    const results = try fpga.pipelineSearch(vectors, query_local, 10);
    defer allocator.free(results);

    const search_end = timer.read();
    const search_ns = search_end - search_start;
    const search_us: f64 = @as(f64, @floatFromInt(search_ns)) / 1000.0;

    try std.Io.Writer.print(stdout, "│  Search time: {d:.3} µs\n", .{search_us});
    try std.Io.Writer.print(stdout, "│  Results: {d} vectors\n", .{results.len});
    try std.Io.Writer.print(stdout, "│  Top similarity: {d:.4}\n", .{if (results.len > 0) results[0].similarity else 0.0});
    try std.Io.Writer.print(stdout, "└──────────────────────────────────────────────────────────────┘\n\n", .{});

    // Summary
    try std.Io.Writer.print(stdout, "╔════════════════════════════════════════════════════════════╗\n", .{});
    try std.Io.Writer.print(stdout, "║  KOSCHEI Week 3 — PIPELINE SUMMARY                      ║\n", .{});
    try std.Io.Writer.print(stdout, "╠════════════════════════════════════════════════════════════╣\n", .{});
    try std.Io.Writer.print(stdout, "║  Mode:          {s:14}                           ║\n", .{if (is_hw) "FPGA HW" else "CPU Fallback"});
    try std.Io.Writer.print(stdout, "║  Pipeline op:  {d:.2} µs/op                           ║\n", .{avg_us});
    try std.Io.Writer.print(stdout, "║  Throughput:    {d:.0} ops/sec                        ║\n", .{ops_per_sec});
    try std.Io.Writer.print(stdout, "║  Search:       {d:.2} µs (100 vectors)              ║\n", .{search_us});
    try std.Io.Writer.print(stdout, "╚════════════════════════════════════════════════════════════╝\n", .{});

    try std.Io.Writer.print(stdout, "\n📊 Ralph Loop iteration estimate:\n", .{});
    const ralph_loop_us = avg_us * 3.0; // 3 pipeline ops per iteration
    try std.Io.Writer.print(stdout, "   Current: ~{d:.2} ms per iteration (CPU fallback)\n", .{ralph_loop_us / 1000.0});
    try std.Io.Writer.print(stdout, "   With FPGA: ~{d:.3} ms per iteration (150× faster)\n", .{ralph_loop_us / 1000.0 / 150.0});

    try std.Io.Writer.print(stdout, "\nφ² + 1/φ² = 3\n", .{});
    try std.Io.Writer.flush(stdout);
}
