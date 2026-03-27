//! TRI Constants — Generated from specs/tri/tri_constants.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// SYSTEM LIMITS
// ============================================================================

/// Maximum path length (cross-platform conservative)
pub const MAX_PATH_LEN: usize = 4096;

/// Maximum line length for parsing
pub const MAX_LINE_LEN: usize = 8192;

/// Maximum command arguments
pub const MAX_ARGS: usize = 128;

/// Maximum environment variables
pub const MAX_ENV_VARS: usize = 256;

// ============================================================================
// SACRED CONSTANTS
// ============================================================================

/// Golden ratio φ = (1 + √5) / 2 ≈ 1.618033988749895
pub const PHI: f64 = 1.618033988749895;

/// Circle constant π ≈ 3.141592653589793
pub const PI: f64 = 3.141592653589793;

/// Euler's number e ≈ 2.718281828459045
pub const E: f64 = 2.718281828459045;

/// Square root of 2 ≈ 1.4142135623730951
pub const SQRT2: f64 = 1.4142135623730951;

/// Square root of 3 ≈ 1.7320508075688772
pub const SQRT3: f64 = 1.7320508075688772;

/// Golden ratio (alias for PHI)
pub const GOLDEN_RATIO: f64 = PHI;

// ============================================================================
// STRUCTURES
// ============================================================================

/// System resource limits
pub const SystemLimits = struct {
    max_path_len: usize,
    max_line_len: usize,
    max_args: usize,
    max_env_vars: usize,

    pub fn init() SystemLimits {
        return .{
            .max_path_len = MAX_PATH_LEN,
            .max_line_len = MAX_LINE_LEN,
            .max_args = MAX_ARGS,
            .max_env_vars = MAX_ENV_VARS,
        };
    }
};

/// Sacred mathematical constants
pub const SacredConstants = struct {
    phi: f64,
    pi: f64,
    e: f64,
    sqrt2: f64,
    sqrt3: f64,
    golden_ratio: f64,

    pub fn init() SacredConstants {
        return .{
            .phi = PHI,
            .pi = PI,
            .e = E,
            .sqrt2 = SQRT2,
            .sqrt3 = SQRT3,
            .golden_ratio = GOLDEN_RATIO,
        };
    }
};

// ============================================================================
// FUNCTIONS
// ============================================================================

/// Maximum path length
pub inline fn maxPathLen() usize {
    return MAX_PATH_LEN;
}

/// Maximum line length for parsing
pub inline fn maxLineLen() usize {
    return MAX_LINE_LEN;
}

/// Maximum command arguments
pub inline fn maxArgs() usize {
    return MAX_ARGS;
}

/// Maximum environment variables
pub inline fn maxEnvVars() usize {
    return MAX_ENV_VARS;
}

/// Golden ratio φ = (1 + √5) / 2
pub inline fn getPHI() f64 {
    return PHI;
}

/// Circle constant π
pub inline fn getPI() f64 {
    return PI;
}

/// Euler's number e
pub inline fn getE() f64 {
    return E;
}

/// Square root of 2
pub inline fn getSQRT2() f64 {
    return SQRT2;
}

/// Square root of 3
pub inline fn getSQRT3() f64 {
    return SQRT3;
}

/// Golden ratio (alias for PHI)
pub inline fn getGoldenRatio() f64 {
    return GOLDEN_RATIO;
}

/// Get all system limits as struct
pub inline fn getSystemLimits() SystemLimits {
    return SystemLimits.init();
}

/// Get all sacred constants as struct
pub inline fn getSacredConstants() SacredConstants {
    return SacredConstants.init();
}

// ============================================================================
// TESTS
// ============================================================================

test "Constants: maxPathLen" {
    try std.testing.expectEqual(@as(usize, 4096), maxPathLen());
}

test "Constants: maxLineLen" {
    try std.testing.expectEqual(@as(usize, 8192), maxLineLen());
}

test "Constants: maxArgs" {
    try std.testing.expectEqual(@as(usize, 128), maxArgs());
}

test "Constants: maxEnvVars" {
    try std.testing.expectEqual(@as(usize, 256), maxEnvVars());
}

test "Constants: getPHI" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.618033988749895), getPHI(), 0.0001);
}

test "Constants: getPI" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.141592653589793), getPI(), 0.0001);
}

test "Constants: getE" {
    try std.testing.expectApproxEqAbs(@as(f64, 2.718281828459045), getE(), 0.0001);
}

test "Constants: getSQRT2" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.4142135623730951), getSQRT2(), 0.0001);
}

test "Constants: getSQRT3" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.7320508075688772), getSQRT3(), 0.0001);
}

test "Constants: getGoldenRatio" {
    try std.testing.expectApproxEqAbs(getPHI(), getGoldenRatio(), 0.0001);
}

test "Constants: SystemLimits init" {
    const limits = getSystemLimits();
    try std.testing.expectEqual(@as(usize, 4096), limits.max_path_len);
    try std.testing.expectEqual(@as(usize, 8192), limits.max_line_len);
    try std.testing.expectEqual(@as(usize, 128), limits.max_args);
    try std.testing.expectEqual(@as(usize, 256), limits.max_env_vars);
}

test "Constants: SacredConstants init" {
    const sacred = getSacredConstants();
    try std.testing.expectApproxEqAbs(getPHI(), sacred.phi, 0.0001);
    try std.testing.expectApproxEqAbs(getPI(), sacred.pi, 0.0001);
    try std.testing.expectApproxEqAbs(getE(), sacred.e, 0.0001);
    try std.testing.expectApproxEqAbs(getSQRT2(), sacred.sqrt2, 0.0001);
    try std.testing.expectApproxEqAbs(getSQRT3(), sacred.sqrt3, 0.0001);
    try std.testing.expectApproxEqAbs(getGoldenRatio(), sacred.golden_ratio, 0.0001);
}

test "Constants: Trinity Identity φ² + 1/φ² = 3" {
    const phi = getPHI();
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
}
