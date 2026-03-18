// @origin(spec:ternary_position.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Ternary Positional Encoding
// 4 trit levels × 243 entries, multi-scale frequencies (1, 1/3, 1/9, 1/27).
// Replaces sinusoidal/RoPE float PE with pure ternary lookup.

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;

/// 4-level ternary positional encoding.
/// Each level has period 3^level: level 0 = period 3, level 1 = period 9, etc.
/// Total unique positions: 3^4 = 81 (extendable via more levels).
pub const TernaryPE = struct {
    /// 4 frequency tables, each 3 entries × embed_dim
    /// (only 3 entries needed per level since ternary has 3 states)
    tables: [4][]Trit,
    embed_dim: usize,

    pub fn init(allocator: std.mem.Allocator, embed_dim: usize) !TernaryPE {
        var tables: [4][]Trit = undefined;
        var rng = std.Random.DefaultPrng.init(0xCAFE_1234);

        for (0..4) |level| {
            tables[level] = try allocator.alloc(Trit, 3 * embed_dim);
            // Initialize: orthogonal-ish ternary patterns
            const random = rng.random();
            for (tables[level]) |*v| {
                v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
            }
        }
        return .{ .tables = tables, .embed_dim = embed_dim };
    }

    pub fn deinit(self: *TernaryPE, allocator: std.mem.Allocator) void {
        for (0..4) |level| {
            allocator.free(self.tables[level]);
        }
    }

    /// Decompose position into 4 trit levels.
    /// Level k has frequency 1/3^k: position mod 3^(k+1) / 3^k
    pub fn positionToTrits4(pos: u32) [4]Trit {
        var result: [4]Trit = undefined;
        var p = pos;
        for (0..4) |level| {
            const digit: i8 = @intCast(p % 3);
            result[level] = @intCast(digit - 1); // 0→-1, 1→0, 2→+1
            p /= 3;
        }
        return result;
    }

    /// Encode position → ternary vector via multi-scale bind.
    pub fn encode(self: *const TernaryPE, pos: u32, output: []Trit) void {
        const trits = positionToTrits4(pos);
        const dim = self.embed_dim;

        // Start with level 0
        const idx0: usize = @intCast(@as(i8, trits[0]) + 1);
        const row0 = self.tables[0][idx0 * dim ..][0..dim];
        @memcpy(output[0..dim], row0);

        // Bind with levels 1-3
        for (1..4) |level| {
            const idx: usize = @intCast(@as(i8, trits[level]) + 1);
            const row = self.tables[level][idx * dim ..][0..dim];
            for (0..dim) |d| {
                const a: i8 = output[d];
                const b: i8 = row[d];
                output[d] = @intCast(std.math.clamp(a * b, -1, 1));
            }
        }
    }

    /// Number of unique positions = 3^4 = 81
    pub fn maxPositions() u32 {
        return 81;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "positionToTrits4 covers 81 unique positions" {
    var seen = std.AutoHashMap([4]Trit, void).init(std.testing.allocator);
    defer seen.deinit();

    for (0..81) |pos| {
        const trits = TernaryPE.positionToTrits4(@intCast(pos));
        try seen.put(trits, {});
    }
    try std.testing.expectEqual(@as(usize, 81), seen.count());
}

test "positionToTrits4 frequency scales" {
    // Level 0 changes every position (period 3)
    const t0 = TernaryPE.positionToTrits4(0);
    const t1 = TernaryPE.positionToTrits4(1);
    const t3 = TernaryPE.positionToTrits4(3);
    // Level 0 should differ between pos 0 and 1
    try std.testing.expect(t0[0] != t1[0]);
    // Level 0 should repeat at period 3
    try std.testing.expectEqual(t0[0], t3[0]);

    // Level 1 changes every 3 positions (period 9)
    try std.testing.expectEqual(t0[1], t1[1]); // same within period
    const t9 = TernaryPE.positionToTrits4(9);
    try std.testing.expectEqual(t0[1], t9[1]); // period 9
}

test "TernaryPE encode output is ternary" {
    const dim = 32;
    var pe = try TernaryPE.init(std.testing.allocator, dim);
    defer pe.deinit(std.testing.allocator);

    var output: [dim]Trit = undefined;
    for (0..81) |pos| {
        pe.encode(@intCast(pos), &output);
        for (output) |v| {
            const val: i8 = v;
            try std.testing.expect(val >= -1 and val <= 1);
        }
    }
}

test "TernaryPE different positions produce different vectors" {
    const dim = 64;
    var pe = try TernaryPE.init(std.testing.allocator, dim);
    defer pe.deinit(std.testing.allocator);

    var v0: [dim]Trit = undefined;
    var v1: [dim]Trit = undefined;
    pe.encode(0, &v0);
    pe.encode(1, &v1);

    var differ = false;
    for (0..dim) |d| {
        if (v0[d] != v1[d]) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}
