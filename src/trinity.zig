// @origin(spec:trinity.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// 🤖 TRINITY v1.0.1 "ASCENSION": Official Production Release
// Trinity - Ternary Vector Symbolic Architecture
// High-performance hyperdimensional computing library
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");

// Core modules.
//
// Four of these were files in this repository until 42490a22 moved them into
// gHashTag/zig-hdc and gHashTag/zig-golden-float without moving the references,
// which is one of the reasons this build failed from March. They come from
// those packages now.
//
// The aliasing is decided by what each module CONTAINS, checked symbol by
// symbol against the re-exports below, not by what it is called: golden-float
// exports `bigint` and that name points at its ternary/hybrid.zig, while the
// actual big-integer module is exported as `ternary_primitives`.
const golden_float = @import("golden_float");

pub const bigint = golden_float.ternary_primitives;
pub const packed_trit = golden_float.packed_trit;
pub const hybrid = golden_float.bigint;
pub const vsa = @import("hdc_vsa");
pub const vm = @import("vm.zig");

// vsa/agent.zig is not re-exported. Its five parts have never been tracked in
// this repository, and they are not in zig-hdc either -- the facade there was
// withdrawn for the same reason. Nothing below referenced vsa_agent, so this
// removes a name nobody could resolve rather than a capability anybody had.

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
pub const bundleN = vsa.bundleN;
pub const countNonZero = vsa.countNonZero;
pub const vectorNorm = vsa.vectorNorm;

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
pub const version = "1.0.1";

test {
    // Run all tests from submodules
    std.testing.refAllDecls(@This());
}

// φ² + 1/φ² = 3 | TRINITY
