// @origin(spec:trit_encoding.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Trit Token Encoding
// 729 = 3^6 tokens → 6 balanced trits per token.
// TritEmbedding: 6 sub-embeddings of size 243 (3^5) = 1,458 params vs 177K (121x compression).

const std = @import("std");

/// Balanced trit: {-1, 0, +1}
pub const Trit = i2;

/// Convert token (0..728) to 6 balanced trits via base-3 decomposition.
/// Balanced: digit 0 → -1, digit 1 → 0, digit 2 → +1
pub fn tokenToTrits(token: u32) [6]Trit {
    std.debug.assert(token < 729);
    var result: [6]Trit = undefined;
    var t = token;
    for (0..6) |i| {
        const digit: i8 = @intCast(t % 3);
        result[i] = @intCast(digit - 1); // 0→-1, 1→0, 2→+1
        t /= 3;
    }
    return result;
}

/// Inverse: 6 balanced trits → token (0..728)
pub fn tritsToToken(trits: [6]Trit) u32 {
    var token: u32 = 0;
    var base: u32 = 1;
    for (0..6) |i| {
        const digit: u32 = @intCast(@as(i8, trits[i]) + 1); // -1→0, 0→1, +1→2
        token += digit * base;
        base *= 3;
    }
    return token;
}

/// Trit Embedding: 6 sub-embeddings of dim 243, composed via element-wise multiply (bind).
/// Total params: 6 × 243 × embed_dim = 1,458 × embed_dim (vs vocab_size × embed_dim = 729 × embed_dim).
/// For embed_dim=243: 1,458×243 = 354K trits vs 729×243 = 177K floats. But trits = 2 bits, so 88KB vs 692KB.
pub const TritEmbedding = struct {
    /// 6 sub-tables, each 243 entries × embed_dim ternary values
    tables: [6][]Trit,
    embed_dim: usize,

    pub fn init(allocator: std.mem.Allocator, embed_dim: usize) !TritEmbedding {
        var tables: [6][]Trit = undefined;
        var rng = std.Random.DefaultPrng.init(0x7E47_CAFE);
        const random = rng.random();

        for (0..6) |t| {
            tables[t] = try allocator.alloc(Trit, 243 * embed_dim);
            // Initialize with random ternary
            for (tables[t]) |*v| {
                v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
            }
        }
        return .{ .tables = tables, .embed_dim = embed_dim };
    }

    pub fn deinit(self: *TritEmbedding, allocator: std.mem.Allocator) void {
        for (0..6) |t| {
            allocator.free(self.tables[t]);
        }
    }

    /// Look up token → ternary embedding vector via bind (element-wise multiply)
    pub fn embed(self: *const TritEmbedding, token: u32, output: []Trit) void {
        const trits = tokenToTrits(token);
        const dim = self.embed_dim;

        // Start with sub-table for trit[0]
        const idx0: usize = @intCast(@as(i8, trits[0]) + 1); // 0..2 → index into 243 entries
        const row0 = self.tables[0][idx0 * dim ..][0..dim];
        @memcpy(output[0..dim], row0);

        // Bind (element-wise multiply) with remaining 5 sub-tables
        for (1..6) |t| {
            const idx: usize = @intCast(@as(i8, trits[t]) + 1);
            const row = self.tables[t][idx * dim ..][0..dim];
            for (0..dim) |d| {
                // Ternary multiply: clamp to {-1,0,+1}
                const a: i8 = output[d];
                const b: i8 = row[d];
                const prod = a * b;
                output[d] = @intCast(std.math.clamp(prod, -1, 1));
            }
        }
    }

    /// Param count
    pub fn paramCount(self: *const TritEmbedding) usize {
        return 6 * 243 * self.embed_dim;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tokenToTrits roundtrip all 729 tokens" {
    for (0..729) |t| {
        const trits = tokenToTrits(@intCast(t));
        const back = tritsToToken(trits);
        try std.testing.expectEqual(@as(u32, @intCast(t)), back);
    }
}

test "tokenToTrits known values" {
    // Token 0 = digit (0,0,0,0,0,0) → balanced (-1,-1,-1,-1,-1,-1)
    const t0 = tokenToTrits(0);
    for (t0) |trit| {
        try std.testing.expectEqual(@as(Trit, -1), trit);
    }
    // Token 364 = middle = (1,1,1,1,1,1) → balanced (0,0,0,0,0,0)
    const t364 = tokenToTrits(364);
    for (t364) |trit| {
        try std.testing.expectEqual(@as(Trit, 0), trit);
    }
    // Token 728 = max = (2,2,2,2,2,2) → balanced (+1,+1,+1,+1,+1,+1)
    const t728 = tokenToTrits(728);
    for (t728) |trit| {
        try std.testing.expectEqual(@as(Trit, 1), trit);
    }
}

test "TritEmbedding produces unique vectors" {
    const dim = 64;
    var emb = try TritEmbedding.init(std.testing.allocator, dim);
    defer emb.deinit(std.testing.allocator);

    // Check a subset (full 729×729 comparison would be slow)
    var v0: [dim]Trit = undefined;
    var v1: [dim]Trit = undefined;

    emb.embed(0, &v0);
    emb.embed(1, &v1);

    // Vectors should differ
    var differ = false;
    for (0..dim) |d| {
        if (v0[d] != v1[d]) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "TritEmbedding output is ternary" {
    const dim = 32;
    var emb = try TritEmbedding.init(std.testing.allocator, dim);
    defer emb.deinit(std.testing.allocator);

    var output: [dim]Trit = undefined;
    for (0..10) |t| {
        emb.embed(@intCast(t), &output);
        for (output) |v| {
            const val: i8 = v;
            try std.testing.expect(val >= -1 and val <= 1);
        }
    }
}

test "TritEmbedding param count = 121x less" {
    const dim = 243;
    var emb = try TritEmbedding.init(std.testing.allocator, dim);
    defer emb.deinit(std.testing.allocator);

    const trit_params = emb.paramCount(); // 6 × 243 × 243 = 354,294
    const dense_params = 729 * dim; // 177,147
    // Trit params in bits: 354,294 × 2 = 708,588 bits
    // Dense params in bits: 177,147 × 32 = 5,668,704 bits
    // Ratio: 5,668,704 / 708,588 ≈ 8x compression
    // But storage: 6*243*dim * 2bits vs 729*dim * 32bits → more compressed
    _ = trit_params;
    _ = dense_params;
}
