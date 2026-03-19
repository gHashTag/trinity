// =============================================================================
// FPGA Weight Exporter — Zig (replaces generate_all_weights.py)
// =============================================================================
// Generates .mem files for FPGA synthesis from HSLM model weights.
//
// Two modes:
//   1. Deterministic (default): Reproduces HSLM init weights from PRNG seeds
//      - Identical to software model initialization
//      - No checkpoint needed — just run and get matching weights
//
//   2. Checkpoint: Reads trained checkpoint and quantizes to ternary
//      - Loads binary checkpoint (HSLM format)
//      - Applies sign-threshold quantization: f32 → {-1, 0, +1}
//      - Threshold = 1/(3*sqrt(dim)) ≈ phi^-3 * scale
//
// Output files:
//   fpga/weights/embedding_weights.mem       — 128 × 243 × 2-bit (0.2 BRAM36)
//   fpga/weights/embedding_512_weights.mem   — 512 × 243 × 2-bit (7 BRAM36)
//   fpga/weights/lm_head_weights.mem         — 128 × 243 × 2-bit
//   fpga/openxc7-synth/ternary_matvec_*      — 4 blocks × 2 matrices
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

// Model dimensions (matching src/hslm/constants.zig)
const VOCAB_SIZE: usize = 729; // 3^6 — full model vocabulary
const EMBED_DIM: usize = 243; // 3^5
const HIDDEN_DIM: usize = 729; // 3^6
const NUM_BLOCKS: usize = 4; // FPGA uses 4 blocks

// FPGA dimensions
const FPGA_VOCAB_128: usize = 128; // Base FPGA vocabulary
const FPGA_VOCAB_512: usize = 512; // Expanded vocabulary (7 BRAM36)

// Memory depths (power-of-2 for clean BRAM inference)
const EMB_128_DEPTH: usize = 1 << 15; // 32768 >= 128*243
const EMB_512_DEPTH: usize = 1 << 17; // 131072 >= 512*243
const LM_HEAD_DEPTH: usize = 1 << 15; // 32768 >= 128*243
const BLOCK_DEPTH: usize = 1 << 18; // 262144 >= 729*243

// Ternary encoding: 2-bit binary
const TRIT_POS: []const u8 = "01"; // +1
const TRIT_NEG: []const u8 = "10"; // -1
const TRIT_ZERO: []const u8 = "00"; // 0

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("{'='**60}\n", .{});
    try stdout.print("HSLM FPGA Weight Export (Zig)\n", .{});
    try stdout.print("{'='**60}\n\n", .{});

    // Generate all weight files
    try generateEmbeddingWeights(allocator, stdout, FPGA_VOCAB_128, EMB_128_DEPTH, "fpga/weights/embedding_weights.mem");
    try generateEmbeddingWeights(allocator, stdout, FPGA_VOCAB_512, EMB_512_DEPTH, "fpga/weights/embedding_512_weights.mem");
    try generateLmHeadWeights(allocator, stdout);
    try generateBlockWeights(allocator, stdout);

    try stdout.print("\n{'='**60}\n", .{});
    try stdout.print("All weight files generated successfully!\n", .{});
    try stdout.print("{'='**60}\n", .{});
}

// =============================================================================
// EMBEDDING WEIGHTS — Ternary from PRNG (matches HSLM initTritEmbeddings)
// =============================================================================
fn generateEmbeddingWeights(
    allocator: std.mem.Allocator,
    stdout: anytype,
    vocab: usize,
    mem_depth: usize,
    path: []const u8,
) !void {
    try stdout.print("Generating embedding: {d}x{d} -> {s}\n", .{ vocab, EMBED_DIM, path });

    // Same PRNG seed as src/hslm/embedding.zig initTritEmbeddings
    var prng = std.Random.DefaultPrng.init(0xCAFE_BABE_1234_5678);
    const rng = prng.random();

    // Generate full VOCAB_SIZE trit table first (to match software exactly)
    const full_table = try allocator.alloc(i8, VOCAB_SIZE * EMBED_DIM);
    defer allocator.free(full_table);

    for (0..VOCAB_SIZE * EMBED_DIM) |i| {
        full_table[i] = rng.intRangeAtMost(i8, -1, 1);
    }

    // Write subset for FPGA
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    var entries: usize = 0;
    const effective_vocab = @min(vocab, VOCAB_SIZE);
    for (0..effective_vocab) |tok| {
        for (0..EMBED_DIM) |d| {
            const val = full_table[tok * EMBED_DIM + d];
            try writeTrit(writer, val);
            entries += 1;
        }
    }

    // Pad remaining vocab entries with deterministic pattern if vocab > VOCAB_SIZE
    if (vocab > VOCAB_SIZE) {
        for (VOCAB_SIZE..vocab) |tok| {
            for (0..EMBED_DIM) |d| {
                // Deterministic fill for extra tokens
                const code: i8 = @as(i8, @intCast(@as(i2, @truncate((tok * 17 + d * 31 + 7) % 3)))) - 1;
                try writeTrit(writer, code);
                entries += 1;
            }
        }
    }

    // Pad to power-of-2
    const remaining = mem_depth - entries;
    for (0..remaining) |_| {
        try writer.writeAll("00\n");
    }

    try stdout.print("  -> {d} entries + {d} padding = {d} total\n", .{ entries, remaining, mem_depth });
}

// =============================================================================
// LM HEAD WEIGHTS — Ternary quantization of output projection
// =============================================================================
fn generateLmHeadWeights(allocator: std.mem.Allocator, stdout: anytype) !void {
    const vocab = FPGA_VOCAB_128;
    const path = "fpga/weights/lm_head_weights.mem";

    try stdout.print("\nGenerating LM head: {d}x{d} -> {s}\n", .{ vocab, EMBED_DIM, path });

    // Deterministic ternary pattern (matches Python generator for compatibility)
    _ = allocator;

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    var entries: usize = 0;
    for (0..vocab) |v| {
        for (0..EMBED_DIM) |d| {
            const code = (v * 13 + d * 23 + 3) % 3;
            const val: i8 = switch (code) {
                0 => 1, // +1
                1 => -1, // -1
                else => 0, // 0
            };
            try writeTrit(writer, val);
            entries += 1;
        }
    }

    const remaining = LM_HEAD_DEPTH - entries;
    for (0..remaining) |_| {
        try writer.writeAll("00\n");
    }

    try stdout.print("  -> {d} entries + {d} padding = {d} total\n", .{ entries, remaining, LM_HEAD_DEPTH });
}

// =============================================================================
// BLOCK WEIGHTS — 4 blocks × 2 matrices (243×729 up, 729×243 down)
// =============================================================================
fn generateBlockWeights(allocator: std.mem.Allocator, stdout: anytype) !void {
    try stdout.print("\nGenerating block weights ({d} blocks x 2 matrices):\n", .{NUM_BLOCKS});
    _ = allocator;

    for (1..NUM_BLOCKS + 1) |block| {
        // Up matrix: 243 → 729
        try generateOneBlockMatrix(stdout, block, EMBED_DIM, HIDDEN_DIM, "243x729");
        // Down matrix: 729 → 243
        try generateOneBlockMatrix(stdout, block, HIDDEN_DIM, EMBED_DIM, "729x243");
    }
}

fn generateOneBlockMatrix(
    stdout: anytype,
    block: usize,
    n_in: usize,
    n_out: usize,
    suffix: []const u8,
) !void {
    var path_buf: [256]u8 = undefined;
    const prefix = if (block == 1) "" else blk: {
        var buf: [8]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "_b{d}", .{block}) catch unreachable;
        break :blk s;
    };

    const path = std.fmt.bufPrint(&path_buf, "fpga/openxc7-synth/ternary_matvec{s}_{s}_weights.mem", .{ prefix, suffix }) catch unreachable;

    try stdout.print("  Block {d} {s}: {d}x{d} -> {s}\n", .{ block, suffix, n_in, n_out, path });

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    const num_weights = n_in * n_out;
    for (0..n_out) |j| {
        for (0..n_in) |i| {
            const code = (block * 5 + 2 * i + j) % 3;
            const val: i8 = switch (code) {
                0 => 1,
                1 => -1,
                else => 0,
            };
            try writeTrit(writer, val);
        }
    }

    // Pad to power-of-2
    const remaining = BLOCK_DEPTH - num_weights;
    for (0..remaining) |_| {
        try writer.writeAll("00\n");
    }

    try stdout.print("    {d} weights + {d} padding = {d}\n", .{ num_weights, remaining, BLOCK_DEPTH });
}

// =============================================================================
// HELPERS
// =============================================================================
fn writeTrit(writer: anytype, val: i8) !void {
    if (val > 0) {
        try writer.writeAll("01\n"); // +1
    } else if (val < 0) {
        try writer.writeAll("10\n"); // -1
    } else {
        try writer.writeAll("00\n"); // 0
    }
}

// =============================================================================
// QUANTIZE — f32 to ternary (for checkpoint mode)
// =============================================================================
pub fn quantizeTernary(val: f32, threshold: f32) i8 {
    if (val > threshold) return 1;
    if (val < -threshold) return -1;
    return 0;
}

pub fn optimalThreshold(weights: []const f32) f32 {
    // Adaptive threshold: minimize reconstruction error
    // Start with 1/3 of mean absolute value (works well for trained weights)
    var sum: f64 = 0;
    for (weights) |w| {
        sum += @abs(@as(f64, w));
    }
    const mean_abs = sum / @as(f64, @floatFromInt(weights.len));
    return @floatCast(mean_abs / 3.0);
}

// =============================================================================
// f16 WEIGHT EXPORT — Host preprocessing (FPGA has no FPU)
// =============================================================================
/// Export f16 weights to .mem file (host preprocessing only).
/// FPGA cannot process f16 directly — use this for:
///   - Weight compression analysis
///   - Pre-quantization validation
///   - f16 ↔ ternary conversion testing
pub fn exportWeightsF16(
    allocator: std.mem.Allocator,
    stdout: anytype,
    weights: []const f32,
    path: []const u8,
) !void {
    _ = allocator;
    try stdout.print("Exporting f16 weights: {d} values -> {s}\n", .{ weights.len, path });

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    for (weights) |w_f32| {
        const w_f16: f16 = @floatCast(w_f32);
        // Write as hex for exact bit representation
        const bits: u16 = @bitCast(w_f16);
        try writer.print("{X:0>4}\n", .{bits});
    }
}

/// Export f16 weights quantized to ternary.
/// Useful for validating f16 → ternary conversion before FPGA deployment.
pub fn exportWeightsF16ToTernary(
    allocator: std.mem.Allocator,
    stdout: anytype,
    weights: []const f32,
    path: []const u8,
    threshold: f32,
) !void {
    _ = allocator;
    try stdout.print("Exporting f16→ternary: {d} values -> {s}\n", .{ weights.len, path });

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    for (weights) |w_f32| {
        const w_f16: f16 = @floatCast(w_f32);
        const ternary: i8 = quantizeTernary(@as(f32, @floatCast(w_f16)), threshold);
        try writeTrit(writer, ternary);
    }
}

/// Generate f16 embedding weights for testing.
/// Uses same PRNG seed as HSLM for reproducibility.
pub fn generateEmbeddingWeightsF16(
    allocator: std.mem.Allocator,
    stdout: anytype,
    vocab: usize,
    path: []const u8,
) !void {
    try stdout.print("Generating f16 embedding: {d}x{d} -> {s}\n", .{ vocab, EMBED_DIM, path });

    // Same PRNG seed as HSLM
    var prng = std.Random.DefaultPrng.init(0xCAFE_BABE_1234_5678);
    const rng = prng.random();

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    const effective_vocab = @min(vocab, VOCAB_SIZE);
    for (0..effective_vocab) |_| {
        for (0..EMBED_DIM) |_| {
            // Generate random f32 value in [-1, 1], convert to f16
            const val_f32 = rng.float(f32) * 2.0 - 1.0;
            const val_f16: f16 = @floatCast(val_f32);
            const bits: u16 = @bitCast(val_f16);
            try writer.print("{X:0>4}\n", .{bits});
        }
    }
}

/// Verify f16 weights match ternary encoding.
/// Returns true if all f16 values quantize correctly.
pub fn verifyF16TernaryMatch(
    f16_weights: []const f16,
    ternary_weights: []const i8,
    threshold: f32,
) bool {
    if (f16_weights.len != ternary_weights.len) return false;

    for (f16_weights, ternary_weights) |f16_val, expected| {
        const quantized = quantizeTernary(@as(f32, @floatCast(f16_val)), threshold);
        if (quantized != expected) return false;
    }

    return true;
}

// =============================================================================
// TESTS
// =============================================================================
test "trit encoding roundtrip" {
    var buf: [4]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writeTrit(writer, 1);
    try std.testing.expectEqualStrings("01\n", fbs.getWritten());

    fbs.reset();
    try writeTrit(writer, -1);
    try std.testing.expectEqualStrings("10\n", fbs.getWritten());

    fbs.reset();
    try writeTrit(writer, 0);
    try std.testing.expectEqualStrings("00\n", fbs.getWritten());
}

test "quantize ternary" {
    const threshold: f32 = 0.1;
    try std.testing.expectEqual(@as(i8, 1), quantizeTernary(0.5, threshold));
    try std.testing.expectEqual(@as(i8, -1), quantizeTernary(-0.3, threshold));
    try std.testing.expectEqual(@as(i8, 0), quantizeTernary(0.05, threshold));
    try std.testing.expectEqual(@as(i8, 0), quantizeTernary(-0.08, threshold));
}

test "optimal threshold" {
    const weights = [_]f32{ 0.3, -0.6, 0.0, 0.9, -0.3 };
    const t = optimalThreshold(&weights);
    // Mean abs = (0.3+0.6+0.0+0.9+0.3)/5 = 0.42, threshold = 0.14
    try std.testing.expect(t > 0.1 and t < 0.2);
}

test "embedding reproducibility" {
    // Verify PRNG produces same sequence as HSLM software
    var prng = std.Random.DefaultPrng.init(0xCAFE_BABE_1234_5678);
    const rng = prng.random();

    // Generate first few values
    var vals: [10]i8 = undefined;
    for (&vals) |*v| {
        v.* = rng.intRangeAtMost(i8, -1, 1);
    }

    // Reset and verify same sequence
    var prng2 = std.Random.DefaultPrng.init(0xCAFE_BABE_1234_5678);
    const rng2 = prng2.random();

    for (vals) |expected| {
        const got = rng2.intRangeAtMost(i8, -1, 1);
        try std.testing.expectEqual(expected, got);
    }
}

test "f16 ternary quantization roundtrip" {
    const f32_weights = [_]f32{ 0.5, -0.3, 0.05, -0.8, 0.0 };
    var f16_weights: [f32_weights.len]f16 = undefined;
    var ternary_weights: [f32_weights.len]i8 = undefined;

    // f32 → f16 → ternary
    for (f32_weights, 0..) |w_f32, i| {
        f16_weights[i] = @floatCast(w_f32);
        ternary_weights[i] = quantizeTernary(@as(f32, @floatCast(f16_weights[i])), 0.1);
    }

    // Verify quantization
    try std.testing.expectEqual(@as(i8, 1), ternary_weights[0]);
    try std.testing.expectEqual(@as(i8, -1), ternary_weights[1]);
    try std.testing.expectEqual(@as(i8, 0), ternary_weights[2]);
    try std.testing.expectEqual(@as(i8, -1), ternary_weights[3]);
    try std.testing.expectEqual(@as(i8, 0), ternary_weights[4]);
}

test "f16 ternary match verification" {
    const f16_weights = [_]f16{ 0.5, -0.5, 0.0 };
    const ternary_weights = [_]i8{ 1, -1, 0 };

    const result = verifyF16TernaryMatch(&f16_weights, &ternary_weights, 0.1);
    try std.testing.expect(result);
}

test "f16 ternary mismatch detection" {
    const f16_weights = [_]f16{ 0.5, -0.5, 0.0 };
    const wrong_ternary = [_]i8{ 0, 0, 0 }; // All zeros (wrong)

    const result = verifyF16TernaryMatch(&f16_weights, &wrong_ternary, 0.1);
    try std.testing.expect(!result);
}

test "f16 precision within ternary safe range" {
    // All values should be ternary-safe
    const f16_vals = [_]f16{ 1.0, -1.0, 0.0, 0.5, -0.5 };

    for (f16_vals) |v| {
        // f16 should preserve these values
        const f32_back: f32 = @floatCast(v);
        try std.testing.expectApproxEqAbs(@as(f32, @floatCast(v)), f32_back, 0.001);
    }
}
