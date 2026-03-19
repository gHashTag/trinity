// Module proxy for token_rotator.zig
// This file exists to allow importing as "token_rotator_mod" in build.zig

const std = @import("std");

// Re-export everything from token_rotator.zig
pub const TokenRotator = @import("token_rotator.zig").TokenRotator;
pub const TokenInfo = @import("token_rotator.zig").TokenInfo;
pub const TokenStatus = @import("token_rotator.zig").TokenStatus;
