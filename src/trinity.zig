// Trinity - Ternary Vector Symbolic Architecture
// High-performance hyperdimensional computing library
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");

// Core modules
pub const bigint = @import("bigint.zig");
pub const packed_trit = @import("packed_trit.zig");
pub const hybrid = @import("hybrid.zig");
pub const vsa = @import("vsa.zig");
pub const vm = @import("vm.zig");

// Re-export main types
pub const BigInt = bigint.TVCBigInt;
pub const PackedBigInt = packed_trit.PackedBigInt;
pub const HybridBigInt = hybrid.HybridBigInt;
pub const Trit = hybrid.Trit;

// Re-export VSA operations
pub const bind = vsa.bind;
pub const unbind = vsa.unbind;
pub const bundle2 = vsa.bundle2;
pub const bundle3 = vsa.bundle3;
pub const cosineSimilarity = vsa.cosineSimilarity;
pub const hammingDistance = vsa.hammingDistance;
pub const hammingSimilarity = vsa.hammingSimilarity;
pub const dotSimilarity = vsa.dotSimilarity;
pub const permute = vsa.permute;
pub const inversePermute = vsa.inversePermute;
pub const encodeSequence = vsa.encodeSequence;
pub const probeSequence = vsa.probeSequence;
pub const randomVector = vsa.randomVector;

// Re-export VM
pub const VSAVM = vm.VSAVM;
pub const VSAInstruction = vm.VSAInstruction;
pub const VSAOpcode = vm.VSAOpcode;

// Constants
pub const MAX_TRITS = hybrid.MAX_TRITS;
pub const TRITS_PER_BYTE = hybrid.TRITS_PER_BYTE;

// Version
pub const version = "0.1.0";

test {
    // Run all tests from submodules
    std.testing.refAllDecls(@This());
}
