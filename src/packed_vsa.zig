// Trinity Packed VSA Operations
// VSA операции на упакованных тритах (5 тритов/байт)
// Использует lookup tables для быстрых операций без распаковки
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
// LOOKUP TABLES для операций на упакованных байтах
// ═══════════════════════════════════════════════════════════════════════════════

/// Lookup table для bind: BIND_LUT[a][b] = packed(bind(unpack(a), unpack(b)))
/// Размер: 243 * 243 = 59049 байт (~58KB)
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

/// Lookup table для bundle2: BUNDLE_LUT[a][b] = packed(bundle(unpack(a), unpack(b)))
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

/// Lookup table для dot product: DOT_LUT[a][b] = sum of element-wise products
/// Диапазон: -5 до +5, храним как u8 со смещением +5
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
            // Смещение +5 чтобы хранить в u8 (диапазон 0-10)
            lut[a][b] = @intCast(@as(i16, sum) + 5);
        }
    }
    break :blk lut;
};

// ═══════════════════════════════════════════════════════════════════════════════
// PACKED VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Packed bind - использует lookup table, без распаковки
pub fn packedBind(a: *const PackedBigInt, b: *const PackedBigInt) PackedBigInt {
    var result = PackedBigInt.zero();
    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const packed_len = (len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    for (0..packed_len) |i| {
        const a_byte = if (i < a.packedLen()) a.data[i] else packed_trit.encodePack(.{ 0, 0, 0, 0, 0 });
        const b_byte = if (i < b.packedLen()) b.data[i] else packed_trit.encodePack(.{ 0, 0, 0, 0, 0 });

        // Lookup вместо распаковки!
        result.data[i] = BIND_LUT[a_byte][b_byte];
    }

    return result;
}

/// Packed bundle - использует lookup table
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

/// Packed dot product - использует lookup table
pub fn packedDot(a: *const PackedBigInt, b: *const PackedBigInt) i64 {
    const len = @min(a.trit_len, b.trit_len);
    const packed_len = (len + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    var total: i64 = 0;

    for (0..packed_len) |i| {
        const a_byte = a.data[i];
        const b_byte = b.data[i];

        // Lookup возвращает значение со смещением +5
        const dot_shifted = DOT_LUT[a_byte][b_byte];
        total += @as(i64, dot_shifted) - 5;
    }

    return total;
}

/// Packed unbind - для тритов unbind = bind (самообратная операция)
/// unbind(bind(a, b), b) = a
pub fn packedUnbind(a: *const PackedBigInt, b: *const PackedBigInt) PackedBigInt {
    // Для тритов: unbind = bind, потому что:
    // bind(a, b) = a * b
    // unbind(a*b, b) = (a*b) * b = a * (b*b) = a * 1 = a
    // (для b ∈ {-1, 1}, b*b = 1)
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

/// Конвертация HybridBigInt → PackedBigInt
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

/// Конвертация PackedBigInt → HybridBigInt
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

/// Создать случайный упакованный вектор
pub fn randomPackedVector(size: usize, seed: u64) PackedBigInt {
    var result = PackedBigInt.zero();
    result.trit_len = size;

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    const packed_len = (size + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;

    for (0..packed_len) |i| {
        // Генерируем случайный упакованный байт (0-242)
        result.data[i] = @intCast(random.intRangeAtMost(u8, 0, 242));
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "packed bind correctness" {
    // Создаём тестовые векторы через HybridBigInt
    var h_a = vsa.randomVector(100, 12345);
    var h_b = vsa.randomVector(100, 67890);

    // Референсный результат (unpacked)
    const ref_result = vsa.bind(&h_a, &h_b);

    // Packed версия
    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);
    const packed_result = packedBind(&p_a, &p_b);

    // Сравниваем
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

    // Референсный dot product
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
    var h_b = vsa.randomVector(100, 55555); // Тот же seed = идентичные

    const p_a = fromHybrid(&h_a);
    const p_b = fromHybrid(&h_b);

    const sim = packedCosineSimilarity(&p_a, &p_b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "packed unbind correctness" {
    // Создаём два случайных вектора
    const p_a = randomPackedVector(100, 12345);
    const p_b = randomPackedVector(100, 67890);

    // bind(a, b)
    const bound = packedBind(&p_a, &p_b);

    // unbind(bind(a, b), b) должен дать вектор похожий на a
    const unbound = packedUnbind(&bound, &p_b);

    // Проверяем сходство с оригиналом
    const sim = packedCosineSimilarity(&unbound, &p_a);

    // Для тритов без нулей сходство должно быть высоким
    // Но из-за нулей в векторах может быть потеря информации
    std.debug.print("\nUnbind similarity: {d:.3}\n", .{sim});
    try std.testing.expect(sim > 0.5); // Должно быть значительное сходство
}

test "packed unbind retrieval" {
    // Симуляция запроса к графу знаний
    // Факт: bind(Paris, bind(capital_of, France))
    // Запрос: unbind(fact, bind(Paris, capital_of)) → France

    const paris = randomPackedVector(100, Entity.hashString("Paris"));
    const capital_of = randomPackedVector(100, Entity.hashString("capital_of") ^ 0xDEADBEEF);
    const france = randomPackedVector(100, Entity.hashString("France"));

    // Кодируем факт: Paris is capital_of France
    const pred_obj = packedBind(&capital_of, &france);
    const fact = packedBind(&paris, &pred_obj);

    // Запрос: что является столицей Франции?
    // unbind(fact, bind(capital_of, France)) → Paris
    const query_pattern = packedBind(&capital_of, &france);
    const result = packedUnbind(&fact, &query_pattern);

    // Результат должен быть похож на Paris
    const sim_paris = packedCosineSimilarity(&result, &paris);
    const sim_france = packedCosineSimilarity(&result, &france);

    std.debug.print("\nQuery result similarity to Paris: {d:.3}\n", .{sim_paris});
    std.debug.print("Query result similarity to France: {d:.3}\n", .{sim_france});

    // Paris должен быть более похож
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

    // Проверяем каждый 100-й трит для скорости
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

    // Проверяем каждый 500-й трит
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

    // Проверяем каждый 1000-й трит
    var i: usize = 0;
    while (i < 10000) : (i += 1000) {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], packed_result.getTrit(i));
    }
}

test "large vector dot correctness (10000 trits)" {
    var h_a = vsa.randomVector(10000, 55555);
    var h_b = vsa.randomVector(10000, 66666);

    // Референсный dot product
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
    // PackedBigInt теперь поддерживает до 12000 тритов
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
    std.debug.print("Speedup > 1.0 означает Packed быстрее\n", .{});
    std.debug.print("Mem Saving показывает экономию памяти (5x теоретический максимум)\n", .{});
}
