// ═══════════════════════════════════════════════════════════════════════════════
// token_types v1.0.0 - Generated from .tri specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// Author:
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

// Базовые φ-константы (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// ERC20-compatible token account with 18 decimal precision
pub const TokenAccount = struct {
    balance: u128,
    nonce: u64,
    allowance: u128,
};

/// Staked token position with lock time
pub const TokenStake = struct {
    staker: [32]u8,
    amount: u128,
    lock_time: i64,
    unlock_time: i64,
    is_active: bool,
};

/// Token-related error codes
pub const TokenErrorCode = enum(u8) {
    /// Not enough tokens for operation
    InsufficientBalance = 0,
    /// Invalid transaction nonce
    InvalidNonce = 1,
    /// Transfer amount exceeds allowance
    AllowanceExceeded = 2,
    /// Stake is still in lock period
    StakeLocked = 3,
    /// No active stake for operation
    NotStaked = 4,
    /// Invalid address format (not 32 bytes)
    InvalidAddress = 5,
    /// Web3 RPC call failed
    NetworkError = 6,
};

/// Convert error code to string
pub fn errorToString(err: TokenErrorCode) []const u8 {
    return switch (err) {
        .InsufficientBalance => "Insufficient balance",
        .InvalidNonce => "Invalid transaction nonce",
        .AllowanceExceeded => "Allowance exceeded",
        .StakeLocked => "Stake is locked",
        .NotStaked => "Not staked",
        .InvalidAddress => "Invalid address",
        .NetworkError => "Network error",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit - ternary digit (-1, 0, +1)
pub const Trit = enum(i8) {
    negative = -1, // FALSE
    zero = 0, // UNKNOWN
    positive = 1, // TRUE

    pub fn trit_and(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_or(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    pub fn trit_xor(a: Trit, b: Trit) Trit {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        if (av == 0 or bv == 0) return .zero;
        if (av == bv) return .negative;
        return .positive;
    }
};

/// Проверка TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-интерполяция
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Генерация φ-спирали
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Token decimals for TRI (18 decimals, compatible with ERC20)
pub const TOKEN_DECIMALS: u8 = 18;

/// One TRI in smallest units (10^18)
pub const ONE_TRI: u128 = 1_000_000_000_000_000_000;

/// Minimum stake amount (100 TRI)
pub const MIN_STAKE: u128 = 100 * ONE_TRI;

/// Maximum lock period (365 days)
pub const MAX_LOCK_PERIOD: u64 = 365 * 24 * 3600;

/// Minimum lock period (7 days)
pub const MIN_LOCK_PERIOD: u64 = 7 * 24 * 3600;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Global token state storage
pub const TokenState = struct {
    allocator: std.mem.Allocator,
    accounts: std.AutoHashMap([32]u8, TokenAccount),
    stakes: std.AutoHashMap([32]u8, TokenStake),
    total_supply: u128,
    total_staked: u128,

    pub fn init(allocator: std.mem.Allocator) TokenState {
        return .{
            .allocator = allocator,
            .accounts = std.AutoHashMap([32]u8, TokenAccount).init(allocator),
            .stakes = std.AutoHashMap([32]u8, TokenStake).init(allocator),
            .total_supply = 0,
            .total_staked = 0,
        };
    }

    pub fn deinit(self: *TokenState) void {
        self.accounts.deinit();
        self.stakes.deinit();
    }

    /// Get token balance for address (returns 0 if not found)
    pub fn getBalance(self: *const TokenState, address: [32]u8) u128 {
        if (self.accounts.get(address)) |account| {
            return account.balance;
        }
        return 0;
    }

    /// Update token balance with overflow/underflow protection
    pub fn updateBalance(self: *TokenState, address: [32]u8, delta: i128) TokenErrorCode!void {
        const entry = try self.accounts.getOrPut(address, .{
            .balance = 0,
            .nonce = 0,
            .allowance = 0,
        });

        if (delta >= 0) {
            const add_amount: u128 = @intCast(delta);
            if (entry.value_ptr.balance > std.math.maxInt(u128) - add_amount) {
                return error.Overflow;
            }
            entry.value_ptr.balance += add_amount;
        } else {
            const sub_amount: u128 = @intCast(-delta);
            if (entry.value_ptr.balance < sub_amount) {
                return error.InsufficientBalance;
            }
            entry.value_ptr.balance -= sub_amount;
        }
        return;
    }

    /// Get stake info for address
    pub fn getStake(self: *const TokenState, address: [32]u8) ?TokenStake {
        return self.stakes.get(address);
    }

    /// Check if stake is unlocked
    pub fn isStakeUnlocked(self: *const TokenState, address: [32]u8) bool {
        const now = std.time.timestamp();
        if (self.getStake(address)) |stake| {
            return stake.is_active and now >= stake.unlock_time;
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Format token amount (18 decimals) as TRI string
pub fn formatTokenAmount(allocator: std.mem.Allocator, amount: u128) ![]u8 {
    const tri = amount / ONE_TRI;
    const sub = amount % ONE_TRI;

    if (sub == 0) {
        return std.fmt.allocPrint(allocator, "{d} TRI", .{tri});
    }

    // Format with decimal places
    const sub_str = try std.fmt.allocPrint(allocator, "{d:0>18}", .{sub});
    defer allocator.free(sub_str);

    // Find trailing zeros to trim
    var trim: u8 = 18;
    while (trim > 0 and sub_str[trim - 1] == '0') : (trim -= 1) {}

    return std.fmt.allocPrint(allocator, "{d}.{s} TRI", .{ tri, sub_str[0..trim] });
}

/// Parse token amount string to u128 (18 decimals)
pub fn parseTokenAmount(str: []const u8) TokenErrorCode!u128 {
    const dot_idx = std.mem.indexOfScalar(u8, str, '.') orelse {
        // No decimal point - integer TRI
        const tri_val = std.fmt.parseInt(u128, str, 10) catch {
            return error.InvalidFormat;
        };
        if (tri_val > std.math.maxInt(u128) / ONE_TRI) {
            return error.Overflow;
        }
        return tri_val * ONE_TRI;
    };

    // Has decimal point
    const int_part = str[0..dot_idx];
    const dec_part = str[dot_idx + 1 ..];

    const tri_val = std.fmt.parseInt(u128, int_part, 10) catch {
        return error.InvalidFormat;
    };

    if (dec_part.len > 18) {
        return error.InvalidFormat; // Too many decimals
    }

    var dec_val: u128 = 0;
    if (dec_part.len > 0) {
        dec_val = std.fmt.parseInt(u128, dec_part, 10) catch {
            return error.InvalidFormat;
        };
        // Pad to 18 decimals
        const zeros: u5 = 18 - @as(u5, @intCast(dec_part.len));
        var i: u5 = 0;
        while (i < zeros) : (i += 1) {
            dec_val *= 10;
        }
    }

    return tri_val * ONE_TRI + dec_val;
}

/// Calculate APY from stake rewards
pub fn calculateAPY(staked: u128, rewards: u128, lock_period_seconds: i64) f64 {
    if (staked == 0 or lock_period_seconds <= 0) return 0.0;

    const reward_ratio: f64 = @floatFromInt(rewards) / @floatFromInt(staked);
    const year_seconds: f64 = 365.0 * 24.0 * 3600.0;
    const periods_per_year: f64 = year_seconds / @floatFromInt(lock_period_seconds);

    return reward_ratio * periods_per_year * 100.0;
}

/// Check if address is valid (32 bytes, non-zero)
pub fn isValidAddress(addr: [32]u8) bool {
    // Check if all zeros (invalid)
    for (addr) |byte| {
        if (byte != 0) return true;
    }
    return false;
}

/// Create zero address
pub fn zeroAddress() [32]u8 {
    return [_]u8{0} ** 32;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR FUNCTIONS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_constants" {
    const phi_val: f64 = PHI;
    const phi_inv_val: f64 = PHI_INV;
    try std.testing.expectApproxEqAbs(phi_val * phi_inv_val, 1.0, 1e-10);
    const phi_sq_val: f64 = PHI_SQ;
    try std.testing.expectApproxEqAbs(phi_sq_val - phi_val, 1.0, 1e-10);
}
