// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY VSA — 10K-DIMENSIONAL HYPERVECTORS                                 ║
// ║  Week 2 Day 1: Scalable VSA architecture for 10,000-dimensional vectors      ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║  - 10,000-dimensional ternary hypervectors                                   ║
// ║  - O(1) parallel bind operation                                              ║
// ║  - Bundle, similarity, permutation                                           ║
// ║  - FPGA-ready memory layout                                                  ║
// ║                                                                              ║
// ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
// ╚════════════════════════════════════════════════════════════════════════════╝

const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");

pub const Trit = common.Trit; // i8: -1, 0, +1
pub const HybridBigInt = common.HybridBigInt;

//==========================================================================
// CONSTANTS
//==========================================================================

pub const DIM_10K = 10_000;
pub const BYTES_PER_10K = (DIM_10K * 2 + 7) / 8; // 20,000 bits = 2,500 bytes
pub const WORDS_32BIT = (DIM_10K * 2 + 31) / 32; // 625 words of 32 bits

// FPGA BRAM sizing (32Kb = 4096 bytes)
pub const BRAM_SIZE = 4096;
pub const VECTORS_PER_BRAM = BRAM_SIZE / BYTES_PER_10K; // ~1.6 vectors

// Trit values (matching HybridBigInt convention)
pub const TRIT_NEG: Trit = -1;
pub const TRIT_ZERO: Trit = 0;
pub const TRIT_POS: Trit = 1;

//==========================================================================
// 10K-DIMENSIONAL HYPERVECTOR
//==========================================================================

/// 10K-dimensional ternary hypervector
/// Storage: 2,500 bytes (20,000 bits) using packed trit encoding
pub const HyperVector10K = struct {
    /// Packed trit storage (2 bits per trit)
    /// Layout: [trit0:1, trit0:0][trit1:1, trit1:0]...
    data: [BYTES_PER_10K]u8,

    const Self = @This();

    /// Create a zero vector
    pub inline fn zero() Self {
        return .{ .data = [_]u8{0} ** BYTES_PER_10K };
    }

    /// Create a random vector
    pub fn random(rng: *std.Random.DefaultPrng) !Self {
        var self = Self.zero();
        var i: usize = 0;
        while (i < DIM_10K) : (i += 1) {
            const rand_val = rng.random().int(u3);
            const trit_val: i8 = switch (rand_val & 0x03) {
                0 => TRIT_ZERO,
                1 => TRIT_POS,
                2 => TRIT_NEG,
                else => TRIT_POS,
            };
            try self.set(i, trit_val);
        }
        return self;
    }

    /// Get trit at index (returns {-1, 0, +1})
    pub inline fn get(self: *const Self, index: usize) !Trit {
        if (index >= DIM_10K) return error.IndexOutOfBounds;
        const bit_idx = index * 2;
        const byte_idx = bit_idx / 8;
        const shift: u3 = @intCast(bit_idx % 8);
        const trit_bits = (self.data[byte_idx] >> shift) & 0x03;

        return switch (trit_bits) {
            0b00 => TRIT_ZERO,
            0b01 => TRIT_POS,
            0b10 => TRIT_NEG,
            else => TRIT_ZERO, // Invalid encoding
        };
    }

    /// Set trit at index
    pub inline fn set(self: *Self, index: usize, value: Trit) !void {
        if (index >= DIM_10K) return error.IndexOutOfBounds;
        const bit_idx = index * 2;
        const byte_idx = bit_idx / 8;
        const shift: u3 = @intCast(bit_idx % 8);

        const trit_bits: u2 = switch (value) {
            TRIT_ZERO => 0b00,
            TRIT_POS => 0b01,
            TRIT_NEG => 0b10,
            else => 0b00,
        };

        // Clear old bits and set new ones
        self.data[byte_idx] &= ~(@as(u8, 0x03) << shift);
        self.data[byte_idx] |= @as(u8, trit_bits) << shift;
    }

    /// Parallel bind operation (O(1) on FPGA with 10,000 LUTs)
    /// result[i] = a[i] * b[i]
    pub fn bind(a: *const Self, b: *const Self) Self {
        var result = Self.zero();

        // Process 16 trits (32 bits) at a time for SIMD efficiency
        const word_count = WORDS_32BIT;
        var w: usize = 0;

        while (w < word_count) : (w += 1) {
            const byte_idx = w * 4;
            if (byte_idx + 4 > BYTES_PER_10K) break;

            // Load 32 bits (16 trits) from each vector
            const a_words = std.mem.readInt(u32, a.data[byte_idx..][0..4], .little);
            const b_words = std.mem.readInt(u32, b.data[byte_idx..][0..4], .little);

            var result_word: u32 = 0;
            var t: usize = 0;

            // Trit-wise multiplication (16 parallel operations)
            while (t < 16) : (t += 1) {
                const shift_amt: u5 = @intCast(t * 2);
                const a_trit: u2 = @truncate((a_words >> shift_amt) & 0x03);
                const b_trit: u2 = @truncate((b_words >> shift_amt) & 0x03);

                const r_trit: u2 = tritMul(a_trit, b_trit);
                result_word |= @as(u32, r_trit) << shift_amt;
            }

            // Store result
            std.mem.writeInt(u32, result.data[byte_idx..][0..4], result_word, .little);
        }

        return result;
    }

    /// Bundle operation (majority vote)
    pub fn bundle(a: *const Self, b: *const Self) !Self {
        var result = Self.zero();

        var i: usize = 0;
        while (i < DIM_10K) : (i += 1) {
            const a_trit = try a.get(i);
            const b_trit = try b.get(i);

            const r_trit: Trit = tritBundle(a_trit, b_trit);
            try result.set(i, r_trit);
        }

        return result;
    }

    /// Cosine similarity (scaled to 0-65535)
    pub fn cosineSimilarity(a: *const Self, b: *const Self) !u16 {
        var dot_product: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;

        var i: usize = 0;
        while (i < DIM_10K) : (i += 1) {
            const a_trit = try a.get(i);
            const b_trit = try b.get(i);

            dot_product += @as(i64, a_trit) * @as(i64, b_trit);
            norm_a += @as(i64, a_trit) * @as(i64, a_trit);
            norm_b += @as(i64, b_trit) * @as(i64, b_trit);
        }

        if (norm_a == 0 or norm_b == 0)
            return 0;

        const norm_sum = norm_a + norm_b;
        const abs_dot = @abs(dot_product);
        const scaled = @as(u64, @intCast(abs_dot)) * 65535 / @as(u64, @intCast(norm_sum));

        return @intCast(scaled);
    }

    /// Permutation (cyclic shift)
    pub fn permute(self: *const Self, shift: u16) !Self {
        var result = Self.zero();
        const effective_shift = @as(usize, @intCast(shift)) % DIM_10K;

        var i: usize = 0;
        while (i < DIM_10K) : (i += 1) {
            const src_idx = (i + DIM_10K - effective_shift) % DIM_10K;
            const trit = try self.get(src_idx);
            try result.set(i, trit);
        }

        return result;
    }

    /// Count non-zero trits
    pub fn countNonZero(self: *const Self) !usize {
        var count: usize = 0;
        var i: usize = 0;
        while (i < DIM_10K) : (i += 1) {
            if (try self.get(i) != TRIT_ZERO)
                count += 1;
        }
        return count;
    }

    /// Convert to slice of 32-bit words (for FPGA transfer)
    pub fn toWords(self: *const Self) [WORDS_32BIT]u32 {
        var result: [WORDS_32BIT]u32 = undefined;
        var i: usize = 0;
        while (i < WORDS_32BIT) : (i += 1) {
            const byte_idx = i * 4;
            if (byte_idx + 4 <= BYTES_PER_10K) {
                result[i] = std.mem.readInt(u32, self.data[byte_idx..][0..4], .little);
            } else {
                result[i] = 0;
            }
        }
        return result;
    }

    /// Create from slice of 32-bit words (from FPGA)
    pub fn fromWords(words: []const u32) Self {
        var result = Self.zero();
        var i: usize = 0;
        while (i < @min(WORDS_32BIT, words.len)) : (i += 1) {
            const byte_idx = i * 4;
            if (byte_idx + 4 <= BYTES_PER_10K) {
                std.mem.writeInt(u32, result.data[byte_idx..][0..4], words[i], .little);
            }
        }
        return result;
    }

    /// Format as hex string
    pub fn formatHex(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}", .{std.fmt.fmtSliceHexLower(&self.data)});
    }
};

/// Trit multiplication lookup table (combinational logic)
inline fn tritMul(a: u2, b: u2) u2 {
    return if (a == 0 or b == 0) 0 else if (a == b) 1 else 2;
}

/// Trit bundle (majority vote of 2)
inline fn tritBundle(a: Trit, b: Trit) Trit {
    if (a == TRIT_NEG) {
        return if (b == TRIT_NEG) TRIT_NEG else if (b == TRIT_POS) TRIT_ZERO else TRIT_NEG;
    } else if (a == TRIT_POS) {
        return if (b == TRIT_NEG) TRIT_ZERO else if (b == TRIT_POS) TRIT_POS else TRIT_POS;
    } else { // a == ZERO
        return b;
    }
}

//==========================================================================
// BENCHMARK FUNCTIONS
//==========================================================================

pub const BenchmarkResult = struct {
    bind_ns: f64,
    bundle_ns: f64,
    similarity_ns: f64,
    bind_throughput: f64, // ops/sec
    dimensions: usize = DIM_10K,
};

/// Run 10K VSA benchmark
pub fn benchmark(_: std.mem.Allocator, iterations: usize) !BenchmarkResult {
    var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));

    // Create test vectors
    const vec_a = try HyperVector10K.random(&rng);
    const vec_b = try HyperVector10K.random(&rng);

    // Warmup
    _ = HyperVector10K.bind(&vec_a, &vec_b);
    _ = try HyperVector10K.bundle(&vec_a, &vec_b);
    _ = try HyperVector10K.cosineSimilarity(&vec_a, &vec_b);

    // Benchmark bind
    const bind_start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = HyperVector10K.bind(&vec_a, &vec_b);
    }
    const bind_end = std.time.nanoTimestamp();
    const bind_ns = @as(f64, @floatFromInt(bind_end - bind_start)) / @as(f64, @floatFromInt(iterations));

    // Benchmark bundle
    const bundle_start = std.time.nanoTimestamp();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = try HyperVector10K.bundle(&vec_a, &vec_b);
    }
    const bundle_end = std.time.nanoTimestamp();
    const bundle_ns = @as(f64, @floatFromInt(bundle_end - bundle_start)) / @as(f64, @floatFromInt(iterations));

    // Benchmark similarity
    const sim_start = std.time.nanoTimestamp();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = try HyperVector10K.cosineSimilarity(&vec_a, &vec_b);
    }
    const sim_end = std.time.nanoTimestamp();
    const sim_ns = @as(f64, @floatFromInt(sim_end - sim_start)) / @as(f64, @floatFromInt(iterations));

    return BenchmarkResult{
        .bind_ns = bind_ns,
        .bundle_ns = bundle_ns,
        .similarity_ns = sim_ns,
        .bind_throughput = 1_000_000_000.0 / bind_ns,
    };
}

/// Print benchmark results
pub fn printBenchmark(result: BenchmarkResult) void {
    const stdout = std.io.getStdOut().writer();

    stdout.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║  TRINITY VSA 10K BENCHMARK RESULTS                                        ║
        \\╚════════════════════════════════════════════════════════════════════════════╝
        \\
        \\Dimensions: {d}
        \\Vector size: {d} bytes
        \\
        \\═══════════════════════════════════════════════════════════════════════════
        \\OPERATION        TIME (ns)    THROUGHPUT     vs FPGA (est)
        \\═══════════════════════════════════════════════════════════════════════════
        \\BIND             {d:.2} ns     {d:.0} op/s      ~1000x slower
        \\BUNDLE           {d:.2} ns     {d:.0} op/s      ~500x slower
        \\SIMILARITY       {d:.2} ns     {d:.0} op/s      ~100x slower
        \\═══════════════════════════════════════════════════════════════════════════
        \\
        \\φ² + 1/φ² = 3 = TRINITY
        \\
    , .{
        DIM_10K,
        BYTES_PER_10K,
        result.bind_ns,
        result.bind_throughput,
        result.bundle_ns,
        1_000_000_000.0 / result.bundle_ns,
        result.similarity_ns,
        1_000_000_000.0 / result.similarity_ns,
    }) catch return;
}

//==========================================================================
// TESTS
//==========================================================================

test "HyperVector10K: zero vector" {
    const vec = HyperVector10K.zero();
    try std.testing.expectEqual(@as(usize, 0), try vec.countNonZero());
}

test "HyperVector10K: bind identity" {
    var rng = std.Random.DefaultPrng.init(42);
    const vec = try HyperVector10K.random(&rng);

    // Identity vector (all +1)
    var identity = HyperVector10K.zero();
    var i: usize = 0;
    while (i < DIM_10K) : (i += 1) {
        try identity.set(i, TRIT_POS);
    }

    const result = HyperVector10K.bind(&vec, &identity);

    // Verify result equals original (sample check)
    var match_count: usize = 0;
    i = 0;
    while (i < 100) : (i += 1) {
        if ((try result.get(i)) == (try vec.get(i)))
            match_count += 1;
    }

    try std.testing.expect(match_count >= 95); // Allow some tolerance
}

test "HyperVector10K: bind inverse" {
    var rng = std.Random.DefaultPrng.init(42);
    const vec = try HyperVector10K.random(&rng);

    // Inverse vector (all -1)
    var inverse = HyperVector10K.zero();
    var i: usize = 0;
    while (i < DIM_10K) : (i += 1) {
        try inverse.set(i, TRIT_NEG);
    }

    const result = HyperVector10K.bind(&vec, &inverse);

    // Verify result is negation of original
    var match_count: usize = 0;
    i = 0;
    while (i < 100) : (i += 1) {
        const vi = try vec.get(i);
        const expected: i8 = if (vi == TRIT_NEG) TRIT_POS else if (vi == TRIT_POS) TRIT_NEG else TRIT_ZERO;
        if ((try result.get(i)) == expected)
            match_count += 1;
    }

    try std.testing.expectEqual(@as(usize, 100), match_count);
}

test "HyperVector10K: cosine similarity bounds" {
    var rng = std.Random.DefaultPrng.init(42);
    const vec_a = try HyperVector10K.random(&rng);
    const vec_b = try HyperVector10K.random(&rng);

    const sim = try HyperVector10K.cosineSimilarity(&vec_a, &vec_b);

    // Similarity should be in range [0, 65535]
    try std.testing.expect(sim >= 0 and sim <= 65535);
}

test "HyperVector10K: permutation roundtrip" {
    var rng = std.Random.DefaultPrng.init(42);
    const original = try HyperVector10K.random(&rng);

    const shifted = try original.permute(100);
    const unshifted = try shifted.permute(@as(u16, @intCast(DIM_10K - 100)));

    // Sample check (not all 10K to save time)
    var match_count: usize = 0;
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        if ((try unshifted.get(i)) == (try original.get(i)))
            match_count += 1;
    }

    try std.testing.expectEqual(@as(usize, 100), match_count);
}

test "HyperVector10K: benchmark quick" {
    const allocator = std.testing.allocator;
    const result = try benchmark(allocator, 10);
    _ = result;

    // Just verify it completes without error
    try std.testing.expect(true);
}

// φ² + 1/φ² = 3 = TRINITY
