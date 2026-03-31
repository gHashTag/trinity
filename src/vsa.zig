// 🤖 TRINITY v0.11.0: Suborbital Order
//! Strand III: Language & Hardware Bridge
//!
//! VSA operations for Trinity S³AI — bind, unbind, bundle, similarity.
//!
//! TTT DOGFOOD ARCHITECTURE (Phase 2):
//! .tri specs → .t27 (TRI-27 Assembly) → .zig (via zig-golden-float kernel)
//!
//! Source of truth: specs/vsa/core.tri
//! Generated targets:
//!   - src/tri27/vsa_*.t27 (TRI-27 assembly)
//!   - external/zig-golden-float/src/vsa/core.zig (kernel implementation)
//!   - trinity/src/vsa/core.zig (duplicate, pending migration to import)
//!
//! Phase 2 Status:
//!   ✅ .tri specs exist (specs/vsa/core.tri, specs/vsa/ops.tri)
//!   ✅ .t27 files exist (bind, bundle2, cosine, permute, similarity, unbind)
//!   ✅ zig-golden-float has identical core.zig
//!   ⏳ Pending: Update build system to use zig-golden-float as module
//!
const std = @import("std");

// Local imports (duplicates of zig-golden-float, pending migration)
pub const common = @import("vsa/common.zig");
pub const core = @import("vsa/core.zig");
pub const encoding = @import("vsa/encoding.zig");
pub const storage = @import("vsa/storage.zig");
pub const concurrency = @import("vsa/concurrency.zig");
pub const agent = @import("vsa/agent.zig");
pub const HRR = @import("vsa/hrr.zig").HRR;

// Re-export common types
pub const HybridBigInt = common.HybridBigInt;
pub const Trit = common.Trit;
pub const Vec32i8 = common.Vec32i8;
pub const SIMD_WIDTH = common.SIMD_WIDTH;
pub const MAX_TRITS = common.MAX_TRITS;
pub const SearchResult = common.SearchResult;

// Re-export core functions
pub const randomVector = core.randomVector;
pub const bind = core.bind;
pub const unbind = core.unbind;
pub const bundle2 = core.bundle2;
pub const bundle3 = core.bundle3;
pub const permute = core.permute;
pub const inversePermute = core.inversePermute;
pub const cosineSimilarity = core.cosineSimilarity;
pub const hammingDistance = core.hammingDistance;
pub const hammingSimilarity = core.hammingSimilarity;
pub const dotSimilarity = core.dotSimilarity;
pub const vectorNorm = core.vectorNorm;
pub const bundleN = core.bundleN;
pub const countNonZero = core.countNonZero;
pub const encodeSequence = core.encodeSequence;
pub const probeSequence = core.probeSequence;

// Re-export encoding
// Text encoding stubs (not fully implemented in gen_encoding)
pub fn encodeText(allocator: std.mem.Allocator, text: []const u8) ![]i8 {
    _ = allocator;
    _ = text;
    return error.NotImplemented;
}

pub fn decodeText(allocator: std.mem.Allocator, vec: []const i8) ![]u8 {
    _ = allocator;
    _ = vec;
    return error.NotImplemented;
}

pub const TEXT_VECTOR_DIM: usize = 1000;

// Re-export text encoding functions from encoding module
pub const charToVector = encoding.charToVector;
pub const encodeTextWords = encoding.encodeTextWords;
pub const textSimilarity = encoding.textSimilarity;
pub const textsAreSimilar = encoding.textsAreSimilar;

// Re-export storage
pub const TextCorpus = storage.TextCorpus;

// Re-export concurrency & DAG
pub const ChaseLevDeque = concurrency.ChaseLevDeque;
pub const LockFreePool = concurrency.LockFreePool;
pub const DependencyGraph = concurrency.DependencyGraph;
pub const TaskNode = concurrency.TaskNode;
pub const TaskState = concurrency.TaskState;
pub const getGlobalPool = concurrency.getGlobalPool;

// Re-export Agentic systems
pub const UnifiedAgent = agent.UnifiedAgent;
pub const AgentMemory = agent.AgentMemory;
pub const AgentRole = agent.AgentRole;
pub const Modality = agent.Modality;
pub const MultiModalToolUse = agent.MultiModalToolUse;
pub const AutonomousAgent = agent.AutonomousAgent;
pub const ImprovementLoop = agent.ImprovementLoop;
pub const UnifiedAutonomousSystem = agent.UnifiedAutonomousSystem;
pub const UnifiedRequest = agent.UnifiedRequest;
pub const UnifiedResponse = agent.UnifiedResponse;
pub const SystemCapability = agent.SystemCapability;

// Prototypical accessors
pub const getUnifiedAgent = agent.getUnifiedAgent;
pub const getAgentMemory = agent.getAgentMemory;
pub const getAutonomousAgent = agent.getAutonomousAgent;
pub const getUnifiedSystem = agent.getUnifiedSystem;

/// Hamming distance for ternary trit slices.
/// Counts positions where trits differ. Unequal lengths add the difference.
pub fn hammingDistanceSlice(a: []const i8, b: []const i8) usize {
    const len = @min(a.len, b.len);
    var distance: usize = 0;
    for (0..len) |i| {
        if (a[i] != b[i]) distance += 1;
    }
    if (a.len > b.len) {
        distance += a.len - b.len;
    } else {
        distance += b.len - a.len;
    }
    return distance;
}

test {
    _ = @import("vsa/tests.zig");
}

// φ² + 1/φ² = 3 | TRINITY
