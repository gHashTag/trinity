// =============================================================================
// TRINITY NEXUS -- Core Module (trinity-core)
// VSA operations, Ternary VM, HybridBigInt, packed trit encoding, SDK
// =============================================================================
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

// Foundation types
pub const bigint = @import("bigint.zig");
pub const packed_trit = @import("packed_trit.zig");
pub const hybrid = @import("hybrid.zig");

// VSA operations
pub const vsa = @import("vsa.zig");

// Ternary Virtual Machine
pub const vm = @import("vm.zig");

// High-level SDK
pub const sdk = @import("sdk.zig");

// JIT acceleration
pub const jit = @import("jit.zig");
pub const vsa_jit = @import("vsa_jit.zig");

// Re-export core types for convenience
pub const HybridBigInt = hybrid.HybridBigInt;
pub const Trit = hybrid.Trit;
pub const MAX_TRITS = hybrid.MAX_TRITS;

pub const VERSION = "0.1.0";
pub const MODULE = "trinity-core";

test {
    _ = bigint;
    _ = packed_trit;
    _ = hybrid;
    _ = vsa;
    _ = vm;
    _ = sdk;
}

test "trinity-core module identity" {
    try std.testing.expectEqualStrings("trinity-core", MODULE);
}
