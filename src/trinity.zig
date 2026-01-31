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

// SDK modules (high-level API)
pub const sdk = @import("sdk.zig");
pub const science = @import("science.zig");
pub const sparse = @import("sparse.zig");
pub const jit = @import("jit.zig");

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

// Re-export SDK types (for developers)
pub const Hypervector = sdk.Hypervector;
pub const Codebook = sdk.Codebook;
pub const AssociativeMemory = sdk.AssociativeMemory;
pub const SequenceEncoder = sdk.SequenceEncoder;
pub const GraphEncoder = sdk.GraphEncoder;
pub const Classifier = sdk.Classifier;

// Re-export Science types (for researchers)
pub const VectorStats = science.VectorStats;
pub const DistanceMetric = science.DistanceMetric;
pub const ResonatorNetwork = science.ResonatorNetwork;
pub const computeStats = science.computeStats;
pub const distance = science.distance;
pub const mutualInformation = science.mutualInformation;
pub const batchSimilarity = science.batchSimilarity;
pub const batchBundle = science.batchBundle;
pub const weightedBundle = science.weightedBundle;

// Re-export Sparse types
pub const SparseVector = sparse.SparseVector;

// Re-export JIT types
pub const JitCompiler = jit.JitCompiler;
pub const JitCache = jit.JitCache;

// Constants
pub const MAX_TRITS = hybrid.MAX_TRITS;
pub const TRITS_PER_BYTE = hybrid.TRITS_PER_BYTE;
pub const PHI = science.PHI;
pub const PHI_SQUARED = science.PHI_SQUARED;
pub const GOLDEN_IDENTITY = science.GOLDEN_IDENTITY;

// Version
pub const version = "0.2.0";

test {
    // Run all tests from submodules
    std.testing.refAllDecls(@This());
}
