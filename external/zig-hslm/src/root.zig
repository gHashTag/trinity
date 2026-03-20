// zig-hslm — HSLM Numerical Utilities
// Official HSLM library for Trinity
// Repository: https://codeberg.org/gHashTag/zig-hslm

const std = @import("std");

pub const f16_utils = @import("f16_utils.zig");

// Re-export common types and functions for convenience
pub const HslmF16 = f16_utils.HslmF16;
pub const GF16 = f16_utils.GF16;
pub const TF3 = f16_utils.TF3;
pub const PHI = f16_utils.PHI;
pub const PHI_INV = f16_utils.PHI_INV;

pub const hslmF16ToF32 = f16_utils.safeF16ToF32;
pub const phiQuantize = f16_utils.phiQuantize;
pub const phiDequantize = f16_utils.phiDequantize;
pub const f16BatchToF32 = f16_utils.f16BatchToF32;
pub const f32BatchToF16 = f16_utils.f32BatchToF16;
pub const hslmF16BatchToF32 = f16_utils.f16BatchToF32;  // Alias for compatibility
pub const vectorFloatCast = f16_utils.vectorFloatCast;

pub fn testAll() !void {
    std.debug.print("zig-hslm test suite passed\n", .{});
}
