// @origin(spec:beal.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// BEAL MODULE - Beal Conjecture Counterexample Scanner
// ═══════════════════════════════════════════════════════════════════════════════
// Search for A^x + B^y = C^z with coprime bases, exponents > 2
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const simd = @import("beal/simd_neon.zig");
pub const gcd = @import("beal/gcd.zig");
pub const mod_filter = @import("beal/mod_filter.zig");
pub const search = @import("beal/search.zig");
pub const bigint_verify = @import("beal/bigint_verify.zig");
pub const near_miss = @import("beal/near_miss.zig");

// Re-export commonly used types
pub const simd_types = simd;
pub const Candidate = gcd.Candidate;
pub const PowerTable = mod_filter.PowerTable;
pub const SearchConfig = search.SearchConfig;
pub const SearchStats = search.SearchStats;
pub const Counterexample = search.Counterexample;
pub const NearMiss = near_miss.NearMiss;
pub const NearMissStats = near_miss.NearMissStats;

// Main entry point for standalone execution
pub const main = @import("beal/main.zig").main;

test "beal module - SIMD tests" {
    _ = @import("beal/simd_neon.zig");
}

test "beal module - GCD tests" {
    _ = @import("beal/gcd.zig");
}

test "beal module - modular filter tests" {
    _ = @import("beal/mod_filter.zig");
}

test "beal module - search tests" {
    _ = @import("beal/search.zig");
}

test "beal module - bigint verification tests" {
    _ = @import("beal/bigint_verify.zig");
}

test "beal module - near-miss analyzer tests" {
    _ = @import("beal/near_miss.zig");
}

test "beal module - basic functionality" {
    const allocator = std.testing.allocator;

    // Test GCD
    try std.testing.expect(gcd.gcdTwo(48, 18) == 6);
    try std.testing.expect(gcd.isCoprime(3, 4, 5));

    // Test SIMD detection
    const target = simd.detectSimdTarget();
    try std.testing.expect(target != .scalar);

    // Test power table creation
    var table = try mod_filter.PowerTable.init(
        allocator,
        &mod_filter.RECOMMENDED_PRIMES,
        100,
        10,
    );
    defer table.deinit();

    try std.testing.expect(table.primes.len == 3);
}
