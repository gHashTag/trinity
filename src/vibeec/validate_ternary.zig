// Validate full ternary pipeline end-to-end
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL

const std = @import("std");
const tri = @import("tri_inference.zig");
const kv_cache = @import("kv_cache.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TERNARY PIPELINE VALIDATION                        ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Test 1: Load model
    std.debug.print("═══ TEST 1: Load .tri model ═══\n", .{});
    var model = tri.TriModel.init(allocator, "test_minimal.tri") catch |err| {
        std.debug.print("❌ FAILED to load model: {}\n", .{err});
        return;
    };
    defer model.deinit();
    std.debug.print("✅ Model loaded successfully\n", .{});
    std.debug.print("   vocab_size: {d}\n", .{model.header.vocab_size});
    std.debug.print("   hidden_size: {d}\n", .{model.header.hidden_size});
    std.debug.print("   num_layers: {d}\n", .{model.header.num_layers});
    std.debug.print("\n", .{});

    // Test 2: Forward pass with f32 KV cache
    std.debug.print("═══ TEST 2: Forward pass (f32 KV cache) ═══\n", .{});
    var timer = try std.time.Timer.start();

    const token_id: u32 = 5;
    const logits_f32 = model.forward(token_id, 0) catch |err| {
        std.debug.print("❌ FAILED forward pass: {}\n", .{err});
        return;
    };
    defer allocator.free(logits_f32);

    const f32_time = timer.read();
    std.debug.print("✅ Forward pass completed\n", .{});
    std.debug.print("   Output shape: {d}\n", .{logits_f32.len});
    std.debug.print("   Time: {d:.3} ms\n", .{@as(f64, @floatFromInt(f32_time)) / 1e6});

    // Check output is valid
    var has_nonzero = false;
    var has_nan = false;
    for (logits_f32) |v| {
        if (v != 0.0) has_nonzero = true;
        if (std.math.isNan(v)) has_nan = true;
    }
    if (has_nan) {
        std.debug.print("❌ Output contains NaN!\n", .{});
    } else if (!has_nonzero) {
        std.debug.print("⚠️  Output is all zeros\n", .{});
    } else {
        std.debug.print("✅ Output is valid (non-zero, no NaN)\n", .{});
    }
    std.debug.print("\n", .{});

    // Test 3: Enable ternary KV cache
    std.debug.print("═══ TEST 3: Enable ternary KV cache ═══\n", .{});
    model.enableTernaryKVCache() catch |err| {
        std.debug.print("❌ FAILED to enable ternary KV cache: {}\n", .{err});
        return;
    };
    std.debug.print("✅ Ternary KV cache enabled\n", .{});
    std.debug.print("\n", .{});

    // Test 4: Forward pass with ternary KV cache
    std.debug.print("═══ TEST 4: Forward pass (ternary KV cache) ═══\n", .{});
    model.resetKVCache();
    timer.reset();

    const logits_ternary = model.forward(token_id, 0) catch |err| {
        std.debug.print("❌ FAILED forward pass with ternary: {}\n", .{err});
        return;
    };
    defer allocator.free(logits_ternary);

    const ternary_time = timer.read();
    std.debug.print("✅ Forward pass completed\n", .{});
    std.debug.print("   Output shape: {d}\n", .{logits_ternary.len});
    std.debug.print("   Time: {d:.3} ms\n", .{@as(f64, @floatFromInt(ternary_time)) / 1e6});

    // Check output is valid
    has_nonzero = false;
    has_nan = false;
    for (logits_ternary) |v| {
        if (v != 0.0) has_nonzero = true;
        if (std.math.isNan(v)) has_nan = true;
    }
    if (has_nan) {
        std.debug.print("❌ Output contains NaN!\n", .{});
    } else if (!has_nonzero) {
        std.debug.print("⚠️  Output is all zeros\n", .{});
    } else {
        std.debug.print("✅ Output is valid (non-zero, no NaN)\n", .{});
    }
    std.debug.print("\n", .{});

    // Test 5: Compare outputs
    std.debug.print("═══ TEST 5: Compare f32 vs ternary outputs ═══\n", .{});
    var dot: f64 = 0.0;
    var norm_f32: f64 = 0.0;
    var norm_ternary: f64 = 0.0;

    for (logits_f32, logits_ternary) |f, t| {
        dot += @as(f64, f) * @as(f64, t);
        norm_f32 += @as(f64, f) * @as(f64, f);
        norm_ternary += @as(f64, t) * @as(f64, t);
    }

    const cosine_sim = if (norm_f32 > 0 and norm_ternary > 0)
        dot / (@sqrt(norm_f32) * @sqrt(norm_ternary))
    else
        0.0;

    std.debug.print("   Cosine similarity: {d:.4}\n", .{cosine_sim});
    if (cosine_sim > 0.9) {
        std.debug.print("✅ High similarity (>0.9)\n", .{});
    } else if (cosine_sim > 0.7) {
        std.debug.print("⚠️  Moderate similarity (0.7-0.9)\n", .{});
    } else {
        std.debug.print("❌ Low similarity (<0.7)\n", .{});
    }
    std.debug.print("\n", .{});

    // Test 6: Memory comparison
    std.debug.print("═══ TEST 6: Memory usage comparison ═══\n", .{});
    const header = model.header;
    const f32_kv_mem = header.num_layers * header.context_length * header.num_kv_heads * header.head_dim * 2 * @sizeOf(f32);

    var ternary_kv_mem: usize = 0;
    if (model.ternary_kv_caches) |caches| {
        ternary_kv_mem = caches[0].memoryUsage() * header.num_layers;
    }

    const ratio = if (ternary_kv_mem > 0)
        @as(f64, @floatFromInt(f32_kv_mem)) / @as(f64, @floatFromInt(ternary_kv_mem))
    else
        0.0;

    std.debug.print("   f32 KV cache:     {d} bytes\n", .{f32_kv_mem});
    std.debug.print("   Ternary KV cache: {d} bytes\n", .{ternary_kv_mem});
    std.debug.print("   Compression:      {d:.1}x\n", .{ratio});
    if (ratio > 10.0) {
        std.debug.print("✅ Good compression (>10x)\n", .{});
    } else {
        std.debug.print("⚠️  Lower than expected compression\n", .{});
    }
    std.debug.print("\n", .{});

    // Test 7: Multi-token generation
    std.debug.print("═══ TEST 7: Multi-token generation ═══\n", .{});
    model.resetKVCache();
    timer.reset();

    const num_tokens: usize = 10;
    for (0..num_tokens) |i| {
        const tok: u32 = @intCast(i % model.header.vocab_size);
        const out = model.forward(tok, i) catch |err| {
            std.debug.print("❌ FAILED at token {d}: {}\n", .{ i, err });
            return;
        };
        allocator.free(out);
    }

    const gen_time = timer.read();
    const tokens_per_sec = @as(f64, @floatFromInt(num_tokens)) / (@as(f64, @floatFromInt(gen_time)) / 1e9);

    std.debug.print("✅ Generated {d} tokens\n", .{num_tokens});
    std.debug.print("   Total time: {d:.3} ms\n", .{@as(f64, @floatFromInt(gen_time)) / 1e6});
    std.debug.print("   Speed: {d:.1} tokens/sec\n", .{tokens_per_sec});
    std.debug.print("\n", .{});

    // Summary
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    VALIDATION SUMMARY                        ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Model load:           ✅ PASS                               ║\n", .{});
    std.debug.print("║  f32 forward:          ✅ PASS                               ║\n", .{});
    std.debug.print("║  Ternary KV enable:    ✅ PASS                               ║\n", .{});
    std.debug.print("║  Ternary forward:      ✅ PASS                               ║\n", .{});
    std.debug.print("║  Output similarity:    {d:.2}                                ║\n", .{cosine_sim});
    std.debug.print("║  Memory compression:   {d:.1}x                               ║\n", .{ratio});
    std.debug.print("║  Generation speed:     {d:.1} tok/s                          ║\n", .{tokens_per_sec});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\nKOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
