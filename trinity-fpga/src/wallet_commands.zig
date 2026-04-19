// TRI‑27 Token CLI — Wallet Commands over Token Types + FFI
// ═════════════════════════════════════════════════════════════════
//
// Wallet commands for TRI-27 token management
// Supports: balance, stake, unstake, claim, list
//
// φ² + 1/φ² = 3 | TRINITY
// ══════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const token_types = @import("token_types.zig");
const token_ffi = @import("token_ffi.zig");

// ══════════════════════════════════════════════════════════
// RESULT TYPES
// ══════════════════════════════════════════════════════════

pub const TokenCommand = enum {
    balance = 0,
    stake = 1,
    unstake = 2,
    claim = 3,
    list = 4,
};

pub const CommandResult = struct {
    success: bool,
    message: []const u8,
    data: CommandData,
};

pub const CommandData = union(enum) {
    balance: BalanceData,
    stake: StakeData,
    unstake: UnstakeData,
    claim: ClaimData,
    list: ListData,
};

pub const BalanceData = struct {
    address: [20]u8,
    balance_tri: u128,
    formatted: []const u8,
};

pub const StakeData = struct {
    staker: [32]u8,
    amount_tri: u128,
    lock_period_days: u64,
    unlock_time: i64,
    can_unstake: bool,
    progress: f64,
};

pub const UnstakeData = struct {
    amount_tri: u128,
    status: UnstakeStatus,
};

pub const ClaimData = struct {
    amount_tri: u128,
    tx_hash: [32]u8,
};

pub const ListData = struct {
    items: []ListItem,
};

pub const ListItem = struct {
    type: []const u8,
    value: []const u8,
};

pub const UnstakeStatus = enum {
    success = 0,
    pending = 1,
    failed = 2,
    locked = 3,
};

// ════════════════════════════════════════════════════════════
// ERROR TYPES
// ══════════════════════════════════════════════════════════════

pub const WalletError = error{
    InvalidAddress,
    InsufficientBalance,
    InvalidAmount,
    InvalidLockPeriod,
    StakeNotFound,
    StakeLocked,
    FfiError,
};

// ══════════════════════════════════════════════════════════
// WALLET COMMANDS
// ════════════════════════════════════════════════════════════════════

const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";
const CYAN = "\x1b[36m";

/// Run token command
pub fn runCommand(
    allocator: Allocator,
    command: TokenCommand,
    args: []const []const u8,
) CommandResult {
    return switch (command) {
        .balance => runBalance(allocator, args),
        .stake => runStake(allocator, args),
        .unstake => runUnstake(allocator, args),
        .claim => runClaim(allocator, args),
        .list => runList(allocator, args),
        else => .{
            .success = false,
            .message = "Unknown command",
            .data = null,
        },
    };
}

/// Balance command — check token balance
fn runBalance(allocator: Allocator, args: []const []const u8) CommandResult {
    if (args.len < 1) {
        return .{
            .success = false,
            .message = "Usage: tri27 wallet balance <address>",
            .data = null,
        };
    }

    const address_hex = args[0];
    var address: [20]u8 = undefined;
    defer {
        if (address_hex.len != 42) {
            return .{
                .success = false,
                .message = "Invalid address format (expected 42 hex chars)",
                .data = null,
            };
        }

        // Parse hex address
        var i: u8 = 0;
        var byte_value: u8 = 0;
        while (i < 40) : (i += 1) {
            const char = address_hex[i];
            if ('0' <= char and char <= '9') {
                byte_value = (byte_value * 16) + @intFromFloat(char - '0');
            } else {
                byte_value = byte_value + @intFromFloat(char - 'A');
            }
            address[i / 2] = @intFromFloat(byte_value);
        }

        // TODO: In production, call token_ffi.getNonce() for proper address
        _ = address;
    }

    const address_32 = std.mem.zeroes([32]u8);
    @memcpy(address_32, address.ptr);

    // Call FFI balanceOf
    const balance = token_ffi.balanceOf(address_32);

    return .{
        .success = true,
        .message = null,
        .data = .{
            .balance = .{
                .address = address_32,
                .balance_tri = balance.amount,
                .formatted = try token_types.formatTokenAmount(allocator, balance.amount),
            },
        },
    };
}

/// Stake command — lock tokens for specified period
fn runStake(allocator: Allocator, args: []const []const u8) CommandResult {
    if (args.len < 2) {
        return .{
            .success = false,
            .message = "Usage: tri27 wallet stake <amount> <days>",
            .data = null,
        };
    }

    const amount_hex = args[0];
    const lock_period_hex = args[1];

    const amount = std.fmt.parseInt(u64, amount_hex, 10) catch return 100;
    const lock_period = std.fmt.parseInt(u64, lock_period_hex, 10) catch return 30;

    if (amount < 100) {
        return .{
            .success = false,
            .message = "Minimum stake is 100 TRI",
            .data = null,
        };
    }

    if (lock_period < 7 or lock_period > 365) {
        return .{
            .success = false,
            .message = "Lock period must be 7-365 days",
            .data = null,
        };
    }

    const staker: [32]u8 = std.mem.zeroes([32]u8);

    // TODO: In production, use actual wallet address
    // For testing, use deterministic address from hash
    @memset(staker[0..], 0xAA);
    @memset(staker[0..], 1, 0xAA);
    @memset(staker[2..], 0xAA);

    // TODO: In production, call token_ffi.stake()
    // For now, return success (stake would be recorded in StakingState)
    return .{
        .success = true,
        .message = null,
        .data = .{
            .stake = .{
                .staker = staker,
                .amount_tri = @as(u128, amount) * token_types.ONE_TRI,
                .lock_period_days = lock_period,
                // unlock_time would be calculated
                .can_unstake = false,
                .progress = 0.0,
            },
        },
    };
}

/// Unstake command — unlock staked tokens
fn runUnstake(allocator: Allocator, args: []const []const u8) CommandResult {
    if (args.len < 1) {
        return .{
            .success = false,
            .message = "Usage: tri27 wallet unstake <address>",
            .data = null,
        };
    }

    const address_hex = args[0];
    var address: [20]u8 = undefined;
    defer {
        if (address_hex.len != 42) {
            return .{
                .success = false,
                .message = "Invalid address format (expected 42 hex chars)",
                .data = null,
            };
        }

        var i: u8 = 0;
        var byte_value: u8 = 0;
        while (i < 40) : (i += 1) {
            const char = address_hex[i];
            if ('0' <= char and char <= '9') {
                byte_value = (byte_value * 16) + @intFromFloat(char - '0');
            } else {
                byte_value = byte_value + @intFromFloat(char - 'A');
            }
            address[i / 2] = @intFromFloat(byte_value);
        }

        _ = address;
    }

    const address_32 = std.mem.zeroes([32]u8);
    @memcpy(address_32, address.ptr);

    // TODO: Call token_ffi.unstake()
    // For now, return success
    return .{
        .success = true,
        .message = "Unstake successful (not yet implemented in FFI)",
        .data = .{
            .unstake = .{
                .amount_tri = 0, // Would come from staking state
                .status = .success,
            },
        },
    };
}

/// Claim command — claim staking rewards
fn runClaim(allocator: Allocator, args: []const []const u8) CommandResult {
    if (args.len < 1) {
        return .{
            .success = false,
            .message = "Usage: tri27 wallet claim",
            .data = null,
        };
    }

    const address_hex = args[0];
    var address: [20]u8 = undefined;
    defer {
        if (address_hex.len != 42) {
            return .{
                .success = false,
                .message = "Invalid address format (expected 42 hex chars)",
                .data = null,
            };
        }

        var i: u8 = 0;
        var byte_value: u8 = 0;
        while (i < 40) : (i += 1) {
            const char = address_hex[i];
            if ('0' <= char and char <= '9') {
                byte_value = (byte_value * 16) + @intFromFloat(char - '0');
            } else {
                byte_value = byte_value + @intFromFloat(char - 'A');
            }
            address[i / 2] = @intFromFloat(byte_value);
        }

        _ = address;
    }

    const address_32 = std.mem.zeroes([32]u8);
    @memcpy(address_32, address.ptr);

    // TODO: Call token_ffi.claimRewards()
    // For now, return success
    return .{
        .success = true,
        .message = "Claim successful (not yet implemented in FFI)",
        .data = .{
            .claim = .{
                .amount_tri = 0, // Would come from reward pool
                .tx_hash = [_]u8{0} ** 32,
            },
        },
    };
}

/// List command — list all stakes and rewards
fn runList(allocator: Allocator, args: []const []const u8) CommandResult {
    _ = allocator;
    _ = args;

    // TODO: Iterate through StakingState
    // For now, return empty list
    return .{
        .success = true,
        .message = null,
        .data = .{
            .list = .{
                .items = &[_]ListItem{},
            },
        },
    };
}

// ════════════════════════════════════════════════════════
// TESTS
// ════════════════════════════════════════════════════════

test "parse address from hex" {
    const allocator = std.testing.allocator;

    const address_hex = "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    var result = try parseAddress(allocator, address_hex);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("0x0000", result.address[0..3]);
}

test "balance command with invalid address" {
    const allocator = std.testing.allocator;

    const result = runBalance(allocator, &[_]u8{0} ** 42);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.message != null);
}

test "stake command with missing args" {
    const allocator = std.testing.allocator;

    const result = runStake(allocator, &[_]u8{0} ** 42);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.message != null);
}

test "unstake command with missing args" {
    const allocator = std.testing.allocator;

    const result = runUnstake(allocator, &[_]u8{});
    try std.testing.expect(!result.success);
}

test "balance command - stub FFI" {
    const allocator = std.testing.allocator;

    const result = runBalance(allocator, &[_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 });
    try std.testing.expect(result.success);
}
