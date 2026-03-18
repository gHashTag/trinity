// @origin(spec:string_dualities.tri) @regen(manual-impl)
//! String Dualities — S/T/U duality coupling via golden ratio.

const std = @import("std");
const SacredConstants = @import("sacred_constants.zig").SacredConstants;

const PHI = SacredConstants.PHI;

pub const CouplingConstant = struct {
    /// g_s at φ-point = φ/π
    pub fn stringCouplingAtPhi() f64 {
        return PHI / std.math.pi;
    }

    /// S-dual coupling = 1/g_s = π/φ
    pub fn sDualCoupling() f64 {
        return std.math.pi / PHI;
    }

    /// Self-dual when |g_s - 1/g_s| < 0.01
    pub fn isSelfDual(g_s: f64) bool {
        if (g_s <= 0) return false;
        return @abs(g_s - 1.0 / g_s) < 0.01;
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

const testing = std.testing;

test "stringCouplingAtPhi is phi/pi" {
    const g = CouplingConstant.stringCouplingAtPhi();
    try testing.expect(@abs(g - PHI / std.math.pi) < 1e-14);
    try testing.expect(g > 0.515 and g < 0.516);
}

test "S-dual coupling is pi/phi" {
    const g_dual = CouplingConstant.sDualCoupling();
    try testing.expect(@abs(g_dual - std.math.pi / PHI) < 1e-14);
}

test "S-duality product is 1" {
    const g = CouplingConstant.stringCouplingAtPhi();
    const g_dual = CouplingConstant.sDualCoupling();
    try testing.expect(@abs(g * g_dual - 1.0) < 1e-14);
}

test "self-dual at g_s=1" {
    try testing.expect(CouplingConstant.isSelfDual(1.0));
    try testing.expect(!CouplingConstant.isSelfDual(0.5));
}

// φ² + 1/φ² = 3 = TRINITY
