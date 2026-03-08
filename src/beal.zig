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

// Re-export commonly used types
pub const simd_types = simd;
pub const Candidate = gcd.Candidate;
pub const PowerTable = mod_filter.PowerTable;
pub const SearchConfig = search.SearchConfig;
pub const SearchStats = search.SearchStats;
pub const Counterexample = search.Counterexample;

// Main entry point for standalone execution
pub const main = @import("beal/main.zig").main;

test "beal module - SIMD tests" {
    @import("beal/simd_neon.zig").refAllDecls();
}

test "beal module - GCD tests" {
    @import("beal/gcd.zig").refAllDecls();
}

test "beal module - modular filter tests" {
    @import("beal/mod_filter.zig").refAllDecls();
}

test "beal module - search tests" {
    @import("beal/search.zig").refAllDecls();
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
