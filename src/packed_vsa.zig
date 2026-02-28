// Trinity Packed VSA Operations
// VSA operation on [CYR:[EN]]to[EN]in[CYR:[EN]] [EN]and[CYR:[EN]] (5 [EN]and[EN]in/[CYR:[EN]])
// [EN]withby[CYR:[EN]] lookup tables for [EN]with[CYR:[EN]] [CYR:[EN]]and[EN] [CYR:[EN]] [EN]with[EN]to[EN]intoand
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const packed_trit = @import("packed_trit.zig");
const hybrid = @import("hybrid.zig");
const vsa = @import("vsa.zig");

const PackedBigInt = packed_trit.PackedBigInt;
const HybridBigInt = hybrid.HybridBigInt;
const Trit = packed_trit.Trit;
const TRITS_PER_BYTE = packed_trit.TRITS_PER_BYTE;
const MAX_PACKED_BYTES = packed_trit.MAX_PACKED_BYTES;

// ═══════════════════════════════════════════════════════════════════════════════
// LOOKUP TABLES for [CYR:[EN]]and[EN] on [CYR:[EN]]to[EN]in[CYR:[EN]] [CYR:[EN]]
// ═══════════════════════════════════════════════════════════════════════════════

/// Lookup table for bind: BIND_LUT[a][b] = packed(bind(unpack(a), unpack(b)))
/// [CYR:[EN]]: 243 * 243 = 59049 [CYR:[EN]] (~58KB)
const BIND_LUT: [243][243]u8 = blk: {
    @setEvalBranchQuota(1000000);
    var lut: [243][243]u8 = undefined;
    for (0..243) |a| {
        for (0..243) |b| {
            const trits_a = packed_trit.decodePack(@intCast(a));
            const trits_b = packed_trit.decodePack(@intCast(b));
            // bind = element-wise multiply
            const result = [5]i8{
                trits_a[0] * trits_b[0],
                trits_a[1] * trits_b[1],
                trits_a[2] * trits_b[2],
                trits_a[3] * trits_b[3],
                trits_a[4] * trits_b[4],
            };
            lut[a][b] = packed_trit.encodePack(result);
        }
    }
    break :blk lut;
};

/// Lookup table for bundle2: BUNDLE_LUT[a][b] = packed(bundle(unpack(a), unpack(b)))
const BUNDLE_LUT: [243][243]u8 = blk: {
    @setEvalBranchQuota(1000000);
    var lut: [243][243]u8 = undefined;
    for (0..243) |a| {
        for (0..243) |b| {
            const trits_a = packed_trit.decodePack(@intCast(a));
            const trits_b = packed_trit.decodePack(@intCast(b));
            var result: [5]i8 = undefined;
            for (0..5) |i| {
                const sum: i16 = @as(i16, trits_a[i]) + @as(i16, trits_b[i]);
                if (sum > 0) {
                    result[i] = 1;
                } else if (sum < 0) {
                    result[i] = -1;
                } else {
                    result[i] = 0;
                }
            }
            lut[a][b] = packed_trit.encodePack(result);
        }
    }
    break :blk lut;
};

/// Lookup table for dot product: DOT_LUT[a][b] = sum of element-wise products
/// [EN]and[CYR:[EN]]: -5 before +5, [CYR:[EN]]and[EN] how u8 with[EN] with[CYR:[EN]]and[EN] +5
const DOT_LUT: [243][243]u8 = blk: {
    @setEvalBranchQuota(1000000);
    var lut: [243][243]u8 = undefined;
    for (0..243) |a| {
        for (0..243) |b| {
            const trits_a = packed_trit.decodePack(@intCast(a));
            const trits_b = packed_trit.decodePack(@intCast(b));
            var sum: i16 = 0;
            for (0..5) |i| {
                sum += @as(i16, trits_a[i]) * @as(i16, trits_b[i]);
            }
            // [CYR:[EN]]and[EN] +5 what[EN] [CYR:[EN]]and[EN] in u8 ([EN]and[CYR:[EN]] 0-10)
            lut[a][b] = @intCast(@as(i16, sum) + 5);
        }
    }
    break :blk lut;
};

// ═══════════════════════════════════════════════════════════════════════════════
// PACKED VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Packed bind - andwithby[CYR:[EN]] lookup table, [CYR:[EN]] [EN]with[EN]to[EN]intoand
pub fn packedBind(a: *const PackedBigInt, b: *const PackedBigInt) PackedBigInt {
    var result = PackedBigInt.zero();
    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const packed_len = (len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    for (0..packed_len) |i| {
        const a_byte = if (i < a.packedLen()) a.data[i] else packed_trit.encodePack(.{ 0, 0, 0, 0, 0 });
        const b_byte = if (i < b.packedLen()) b.data[i] else packed_trit.encodePack(.{ 0, 0, 0, 0, 0 });

        // Lookup in[EN]with[EN] [EN]with[EN]to[EN]intoand!
        result.data[i] = BIND_LUT[a_byte][b_byte];
    }

    return result;
}

/// Packed bundle - andwithby[CYR:[EN]] lookup table
pub fn packedBundle(a: *const PackedBigInt, b: *const PackedBigInt) PackedBigInt {
    var result = PackedBigInt.zero();
    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const packed_len = (len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    for (0..packed_len) |i| {
        const a_byte = if (i < a.packedLen()) a.data[i] else packed_trit.encodePack(.{ 0, 0, 0, 0, 0 });
        const b_byte = if (i < b.packedLen()) b.data[i] else packed_trit.encodePack(.{ 0, 0, 0, 0, 0 });

        result.data[i] = BUNDLE_LUT[a_byte][b_byte];
    }

    return result;
}

/// Packed dot product - andwithby[CYR:[EN]] lookup table
pub fn packedDot(a: *const PackedBigInt, b: *const PackedBigInt) i64 {
    const len = @min(a.trit_len, b.trit_len);
    const packed_len = (len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    var total: i64 = 0;

    for (0..packed_len) |i| {
        const a_byte = a.data[i];
        const b_byte = b.data[i];

        // Lookup returns value with[EN] with[CYR:[EN]]and[EN] +5
        const dot_shifted = DOT_LUT[a_byte][b_byte];
        total += @as(i64, dot_shifted) - 5;
    }

    return total;
}

/// Packed unbind - for [EN]and[EN]in unbind = bind (with[CYR:[EN]]on[EN] operation)
/// unbind(bind(a, b), b) = a
pub fn packedUnbind(a: *const PackedBigInt, b: *const PackedBigInt) PackedBigInt {
    // [CYR:[EN]] [EN]and[EN]in: unbind = bind, [EN]from[CYR:[EN]] what:
    // bind(a, b) = a * b
    // unbind(a*b, b) = (a*b) * b = a * (b*b) = a * 1 = a
    // (for b ∈ {-1, 1}, b*b = 1)
    return packedBind(a, b);
}

/// Packed cosine similarity
pub fn packedCosineSimilarity(a: *const PackedBigInt, b: *const PackedBigInt) f64 {
    const dot_ab = packedDot(a, b);
    const dot_aa = packedDot(a, a);
    const dot_bb = packedDot(b, b);

    if (dot_aa == 0 or dot_bb == 0) return 0.0;

    const norm_a = @sqrt(@as(f64, @floatFromInt(dot_aa)));
    const norm_b = @sqrt(@as(f64, @floatFromInt(dot_bb)));

    return @as(f64, @floatFromInt(dot_ab)) / (norm_a * norm_b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSION UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// [CYR:[EN]]in[CYR:[EN]]and[EN] HybridBigInt → PackedBigInt
pub fn fromHybrid(h: *HybridBigInt) PackedBigInt {
    h.ensureUnpacked();

    var result = PackedBigInt.zero();
    result.trit_len = h.trit_len;

    const packed_len = (h.trit_len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    for (0..packed_len) |i| {
        const base = i * TRITS_PER_BYTE;
        var trits: [5]i8 = .{ 0, 0, 0, 0, 0 };

        for (0..5) |j| {
            if (base + j < h.trit_len) {
                trits[j] = h.unpacked_cache[base + j];
            }
        }

        result.data[i] = packed_trit.encodePack(trits);
    }

    return result;
}

/// [CYR:[EN]]in[CYR:[EN]]and[EN] PackedBigInt → HybridBigInt
pub fn toHybrid(p: *const PackedBigInt) HybridBigInt {
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.trit_len = p.trit_len;
    result.dirty = true;

    for (0..p.trit_len) |i| {
        result.unpacked_cache[i] = p.getTrit(i);
    }

    return result;
}

/// [CYR:[EN]]yes[EN] with[CYR:[EN]] [CYR:[EN]]to[EN]in[CYR:[EN]] vector
pub fn randomPackedVector(size: usize, seed: u64) PackedBigInt {
    var result = PackedBigInt.zero();
    result.trit_len = size;

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    const packed_len = (size + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    for (0..packed_len) |i| {
        // [EN]not[EN]and[CYR:[EN]] with[CYR:[EN]] [CYR:[EN]]to[EN]in[CYR:[EN]] [CYR:[EN]] (0-242)
        result.data[i] = @intCast(random.intRangeAtMost(u8, 0, 242));
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "packed bind correctness" {
    // [CYR:[EN]]yes[EN] test[EN]in[EN] in[EN]to[CYR:[EN]] via HybridBigInt
    var h_a = vsa.randomVector(100, 12345);
    var h_b = vsa.randomVector(100, 67890);

    // [CYR:[EN]]with[CYR:[EN]] result (unpacked)
    const ref_result = vsa.bind(&h_a, &h_b);

    // Packed version
    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_result = packedBind(&p_a, &p_b);

    // Compare
    for (0..100) |i| {
        const ref_trit = ref_result.unpacked_cache[i];
        const packed_trit_val = packed_result.getTrit(i);
        try std.testing.expectEqual(ref_trit, packed_trit_val);
    }
}

test "packed bundle correctness" {
    var h_a = vsa.randomVector(100, 11111);
    var h_b = vsa.randomVector(100, 22222);

    const ref_result = vsa.bundle2(&h_a, &h_b);

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_result = packedBundle(&p_a, &p_b);

    for (0..100) |i| {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], packed_result.getTrit(i));
    }
}

test "packed dot correctness" {
    var h_a = vsa.randomVector(100, 33333);
    var h_b = vsa.randomVector(100, 44444);

    // [CYR:[EN]]with[CYR:[EN]] dot product
    var ref_dot: i64 = 0;
    for (0..100) |i| {
        ref_dot += @as(i64, h_a.unpacked_cache[i]) * @as(i64, h_b.unpacked_cache[i]);
    }

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_dot_val = packedDot(&p_a, &p_b);

    try std.testing.expectEqual(ref_dot, packed_dot_val);
}

test "packed cosine similarity" {
    var h_a = vsa.randomVector(100, 55555);
    var h_b = vsa.randomVector(100, 55555); // [EN]from [EN] seed = and[CYR:[EN]]and[CYR:[EN]]

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);

    const sim = packedCosineSimilarity(&p_a, &p_b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "packed unbind correctness" {
    // [CYR:[EN]]yes[EN] [EN]in[EN] with[CYR:[EN]] in[EN]to[CYR:[EN]]
    const p_a = randomPackedVector(100, 12345);
    const p_b = randomPackedVector(100, 67890);

    // bind(a, b)
    const bound = packedBind(&p_a, &p_b);

    // unbind(bind(a, b), b) before[CYR:[EN]] yes[EN] vector by[CYR:[EN]]and[EN] on a
    const unbound = packedUnbind(&bound, &p_b);

    // Check with[CYR:[EN]]with[EN]in[EN] with [EN]and[EN]andon[CYR:[EN]]
    const sim = packedCosineSimilarity(&unbound, &p_a);

    // [CYR:[EN]] [EN]and[EN]in [CYR:[EN]] [CYR:[EN]] with[CYR:[EN]]with[EN]in[EN] before[CYR:[EN]] [CYR:[EN]] in[EN]with[EN]toand[EN]
    // [EN] and[EN]-[EN] [CYR:[EN]] in in[EN]to[CYR:[EN]] [CYR:[EN]] [CYR:[EN]] [EN]from[CYR:[EN]] and[CYR:[EN]]andand
    std.debug.print("\nUnbind similarity: {d:.3}\n", .{sim});
    try std.testing.expect(sim > 0.5); // [CYR:[EN]] [CYR:[EN]] [EN]on[EN]and[CYR:[EN]] with[CYR:[EN]]with[EN]in[EN]
}

test "packed unbind retrieval" {
    // [EN]and[CYR:[EN]]and[EN] [CYR:[EN]]with[EN] to [CYR:[EN]] [EN]on[EN]and[EN]
    // [EN]to[EN]: bind(Paris, bind(capital_of, France))
    // [CYR:[EN]]with: unbind(fact, bind(Paris, capital_of)) → France

    const paris = randomPackedVector(100, Entity.hashString("Paris"));
    const capital_of = randomPackedVector(100, Entity.hashString("capital_of") ^ 0xDEADBEEF);
    const france = randomPackedVector(100, Entity.hashString("France"));

    // Encode [EN]to[EN]: Paris is capital_of France
    const pred_obj = packedBind(&capital_of, &france);
    const fact = packedBind(&paris, &pred_obj);

    // [CYR:[EN]]with: what is with[CYR:[EN]]and[CYR:[EN]] [CYR:[EN]]andand?
    // unbind(fact, bind(capital_of, France)) → Paris
    const query_pattern = packedBind(&capital_of, &france);
    const result = packedUnbind(&fact, &query_pattern);

    // Result before[CYR:[EN]] [CYR:[EN]] by[CYR:[EN]] on Paris
    const sim_paris = packedCosineSimilarity(&result, &paris);
    const sim_france = packedCosineSimilarity(&result, &france);

    std.debug.print("\nQuery result similarity to Paris: {d:.3}\n", .{sim_paris});
    std.debug.print("Query result similarity to France: {d:.3}\n", .{sim_france});

    // Paris before[CYR:[EN]] [CYR:[EN]] more by[CYR:[EN]]
    try std.testing.expect(sim_paris > sim_france);
}

const Entity = @import("knowledge_graph.zig").Entity;

test "large vector bind correctness (1000 trits)" {
    var h_a = vsa.randomVector(1000, 12345);
    var h_b = vsa.randomVector(1000, 67890);

    const ref_result = vsa.bind(&h_a, &h_b);

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_result = packedBind(&p_a, &p_b);

    // Check each 100-[EN] [EN]and[EN] for withto[CYR:[EN]]with[EN]and
    var i: usize = 0;
    while (i < 1000) : (i += 100) {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], packed_result.getTrit(i));
    }
}

test "large vector bind correctness (5000 trits)" {
    var h_a = vsa.randomVector(5000, 11111);
    var h_b = vsa.randomVector(5000, 22222);

    const ref_result = vsa.bind(&h_a, &h_b);

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_result = packedBind(&p_a, &p_b);

    // Check each 500-[EN] [EN]and[EN]
    var i: usize = 0;
    while (i < 5000) : (i += 500) {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], packed_result.getTrit(i));
    }
}

test "large vector bind correctness (10000 trits)" {
    var h_a = vsa.randomVector(10000, 33333);
    var h_b = vsa.randomVector(10000, 44444);

    const ref_result = vsa.bind(&h_a, &h_b);

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_result = packedBind(&p_a, &p_b);

    // Check each 1000-[EN] [EN]and[EN]
    var i: usize = 0;
    while (i < 10000) : (i += 1000) {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], packed_result.getTrit(i));
    }
}

test "large vector dot correctness (10000 trits)" {
    var h_a = vsa.randomVector(10000, 55555);
    var h_b = vsa.randomVector(10000, 66666);

    // [CYR:[EN]]with[CYR:[EN]] dot product
    var ref_dot: i64 = 0;
    for (0..10000) |i| {
        ref_dot += @as(i64, h_a.unpacked_cache[i]) * @as(i64, h_b.unpacked_cache[i]);
    }

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_dot_val = packedDot(&p_a, &p_b);

    try std.testing.expectEqual(ref_dot, packed_dot_val);
}

test "benchmark Packed vs Unpacked" {
    // PackedBigInt [CYR:[EN]] supports before 12000 [EN]and[EN]in
    const sizes = [_]usize{ 100, 500, 1000, 2000, 5000, 10000 };
    const iterations = 1000;

    std.debug.print("\n\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              BENCHMARK: PACKED (5 trits/byte) vs UNPACKED (1 trit/byte)          ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Size  │ Unpacked  │  Packed   │  Speedup  │ Mem Unpack│ Mem Pack  │ Mem Saving ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════╣\n", .{});

    for (sizes) |size| {
        var h_a = vsa.randomVector(size, 12345);
        var h_b = vsa.randomVector(size, 67890);

        const p_a = fromHybrid(&h_a);
        const p_b = fromHybrid(&h_b);

        // Benchmark Unpacked (vsa.bind)
        var timer = std.time.Timer.start() catch unreachable;
        for (0..iterations) |_| {
            const result = vsa.bind(&h_a, &h_b);
            std.mem.doNotOptimizeAway(&result);
        }
        const unpacked_ns = timer.read();

        // Benchmark Packed
        timer.reset();
        for (0..iterations) |_| {
            const result = packedBind(&p_a, &p_b);
            std.mem.doNotOptimizeAway(&result);
        }
        const packed_ns = timer.read();

        const unpacked_us = @as(f64, @floatFromInt(unpacked_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));
        const packed_us = @as(f64, @floatFromInt(packed_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));
        const speedup = unpacked_us / packed_us;

        const mem_unpacked = size; // 1 byte per trit
        const mem_packed = (size + 4) / 5; // 5 trits per byte
        const mem_saving = @as(f64, @floatFromInt(mem_unpacked)) / @as(f64, @floatFromInt(mem_packed));

        std.debug.print("║ {d:5} │ {d:6.1} us │ {d:6.1} us │   {d:5.2}x  │ {d:6} B  │ {d:6} B  │    {d:4.1}x   ║\n", .{ size, unpacked_us, packed_us, speedup, mem_unpacked, mem_packed, mem_saving });
    }

    std.debug.print("╚═══════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Speedup > 1.0 [EN]on[CYR:[EN]] Packed [EN]with[CYR:[EN]]\n", .{});
    std.debug.print("Mem Saving byto[CYR:[EN]]in[CYR:[EN]] [EN]to[CYR:[EN]]and[EN] [CYR:[EN]]and (5x [CYR:[EN]]and[EN]withtoand[EN] [EN]towithand[CYR:[EN]])\n", .{});
}
