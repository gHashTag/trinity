// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 TRIT27 TYPE — Ternary 27‑Trit Packed Integer
//
// Encoding: 2 bits per trit, 27 trits = 54 bits (fits in i64)
// Values: {-1, 0, +1} stored as {00, 01, 11}
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
pub const Trit27 = struct {
    trits: i64,

    /// Create Trit27 from i8 value (-1, 0, 1)
    pub fn fromI8(value: i8) Trit27 {
        const clamped = if (value > 0) 1 else if (value < 0) -1 else 0;
        return .{ .trits = @as(i64, clamped) };
    }

    /// Clamp to i8 range
    pub fn toI8Clamped(self: Trit27) i8 {
        if (self.trits == 0) return 0;
        if (self.trits < 0) return -1;
        return 1;
    }

    /// Add two Trit27 values (ternary addition with carry)
    pub fn add(self: Trit27, other: Trit27) Trit27 {
        const sum = self.trits + other.trits;
        // Calculate carry using 3-trit balanced ternary arithmetic
        const half_carry = sum >> 54; // Carry for 27-trit values
        // Reduce result modulo 3^27 and add carry
        const base: i64 = 19683; // 3^27
        const result = (sum % base) + half_carry;
        return .{ .trits = result };
    }

    /// Subtract two Trit27 values
    pub fn sub(self: Trit27, other: Trit27) Trit27 {
        return self.add(Trit27{ .trits = -other.trits });
    }

    /// Compare two Trit27 values
    pub fn cmp(self: Trit27, other: Trit27) struct { lt: bool, eq: bool } {
        if (self.trits == other.trits) {
            return .{ .lt = false, .eq = true };
        }
        return .{ .lt = self.trits < other.trits, .eq = false };
    }
};

// Constants
pub const ZERO = Trit27{ .trits = 0 };
pub const ONE = Trit27{ .trits = 1 };
pub const MINUS_ONE = Trit27{ .trits = -1 };

// Additional constants for convenience
pub const TWO = Trit27{ .trits = 1 }; // ONE + ONE
pub const NEG_ONE = Trit27{ .trits = -1 }; // MINUS_ONE
pub const THREE = Trit27{ .trits = 1 }; // TWO + ONE
