// @origin(spec:string_manifold.tri) @regen(manual-impl)
//! Calabi-Yau manifold Hodge numbers — χ = 2(h11 - h12), mirror symmetry.

const std = @import("std");

pub const HodgeNumbers = struct {
    h11: u32,
    h12: u32,

    pub fn init(h11: u32, h12: u32) !@This() {
        return @This(){ .h11 = h11, .h12 = h12 };
    }

    /// Euler characteristic χ = 2(h^{1,1} - h^{1,2})
    pub fn eulerChi(self: @This()) i64 {
        return 2 * (@as(i64, self.h11) - @as(i64, self.h12));
    }

    /// Fermion generations = |χ|/2 = |h11 - h12|
    pub fn fermionGenerations(self: @This()) u32 {
        const diff = @as(i64, self.h11) - @as(i64, self.h12);
        return @intCast(@as(u64, @abs(diff)));
    }

    /// Mirror symmetry: swap h^{1,1} ↔ h^{1,2}
    pub fn mirror(self: @This()) HodgeNumbers {
        return .{ .h11 = self.h12, .h12 = self.h11 };
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

const testing = std.testing;

test "eulerChi uses minus sign" {
    const h = try HodgeNumbers.init(19, 19);
    try testing.expectEqual(@as(i64, 0), h.eulerChi());
}

test "eulerChi(3,3) is zero" {
    const h = try HodgeNumbers.init(3, 3);
    try testing.expectEqual(@as(i64, 0), h.eulerChi());
}

test "fermionGenerations for Standard Model" {
    // |h11 - h12| = 3 → exactly 3 fermion generations
    const h = try HodgeNumbers.init(6, 3);
    try testing.expectEqual(@as(u32, 3), h.fermionGenerations());
    try testing.expectEqual(@as(i64, 6), h.eulerChi());
}

test "mirror symmetry swaps Hodge numbers" {
    const h = try HodgeNumbers.init(5, 10);
    const m = h.mirror();
    try testing.expectEqual(@as(u32, 10), m.h11);
    try testing.expectEqual(@as(u32, 5), m.h12);
    // Mirror flips sign of Euler characteristic
    try testing.expectEqual(-h.eulerChi(), m.eulerChi());
}

// φ² + 1/φ² = 3 = TRINITY
