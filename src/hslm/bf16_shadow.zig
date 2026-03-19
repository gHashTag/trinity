const std = @import("std");

const bf16 = std.math.bf16;
const f32 = std.math.float;

/// bf16 shadow weight storage
/// - Stores 8×bf16 vectors (128 weights total)
/// - Uses 2× less memory than f32 weights
pub const Bf16ShadowStorage = struct {
    weights: [8 * 16]bf16,

    pub fn init(self: *Self) void {
        @memset(self.weights, @as(f16, 0.0));
    },
};
