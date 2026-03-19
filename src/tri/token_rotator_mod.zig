// Module proxy for token_rotator.zig
// This file exists to allow importing as "token_rotator_mod" in build.zig

const std = @import("std");
pub const token_rotator = @import("token_rotator.zig");

pub usingnamespace token_rotator_mod;

pub const TokenState = token_rotator.TokenState;
pub const TokenInfo = token_rotator.TokenInfo;
pub const TokenStatus = token_rotator.TokenStatus;

pub const is429Error = token_rotator.is429Error;
pub const parseRetryAfter = token_rotator.parseRetryAfter;

pub const init = token_rotator.TokenState.init;
pub const deinit = token_rotator.TokenState.deinit;
pub const getActiveToken = token_rotator.TokenState.getActiveToken;
pub const getNextToken = token_rotator.TokenState.getNextToken;
pub const on429Error = token_rotator.TokenState.on429Error;
pub const rotate = token_rotator.TokenState.rotate;
pub const reset = token_rotator.TokenState.reset;
