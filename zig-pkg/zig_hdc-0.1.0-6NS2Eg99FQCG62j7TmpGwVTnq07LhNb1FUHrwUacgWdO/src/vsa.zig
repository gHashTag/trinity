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
// vsa/agent.zig is not exported, because it cannot compile and never could.
// It imports agent/types.zig, agent/memory.zig, agent/unified.zig,
// agent/autonomous.zig and agent/system.zig -- five files that have never
// been tracked in this repository and do not exist in gHashTag/trinity
// either, which is where the rest of this package was migrated from. So
// the facade was never buildable by anybody, and exporting it from the
// module root made the whole package unbuildable for every consumer.
//
// The file is left in place rather than deleted: unreferenced sources are
// not compiled, and whether the agent layer should be finished or dropped
// is a decision about this library, not a way to turn a build green.
// pub const agent = @import("vsa/agent.zig");
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
// LockFreePool is not re-exported. It has never existed in this repository's
// concurrency module, nor in golden-float's -- both export the same
// twenty-three names and that is not one of them. The line sat here referring
// to nothing, and nothing complained, because lazy analysis never asked what it
// pointed at. Forcing the whole surface through the compiler asked, and the
// answer was that it points at nothing.
pub const DependencyGraph = concurrency.DependencyGraph;
pub const TaskNode = concurrency.TaskNode;
pub const TaskState = concurrency.TaskState;
pub const getGlobalPool = concurrency.getGlobalPool;

// Re-export Agentic systems -- withdrawn with the facade above. Every name here
// resolved through vsa/agent.zig, whose five parts have never existed in any
// repository, so none of these has ever been a symbol anybody could reference.
// pub const UnifiedAgent = agent.UnifiedAgent;
// pub const AgentMemory = agent.AgentMemory;
// pub const AgentRole = agent.AgentRole;
// pub const Modality = agent.Modality;
// pub const MultiModalToolUse = agent.MultiModalToolUse;
// pub const AutonomousAgent = agent.AutonomousAgent;
// pub const ImprovementLoop = agent.ImprovementLoop;
// pub const UnifiedAutonomousSystem = agent.UnifiedAutonomousSystem;
// pub const UnifiedRequest = agent.UnifiedRequest;
// pub const UnifiedResponse = agent.UnifiedResponse;
// pub const SystemCapability = agent.SystemCapability;

// Prototypical accessors -- withdrawn with the facade, same reason.
// pub const getUnifiedAgent = agent.getUnifiedAgent;
// pub const getAgentMemory = agent.getAgentMemory;
// pub const getAutonomousAgent = agent.getAutonomousAgent;
// pub const getUnifiedSystem = agent.getUnifiedSystem;

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
    // vsa/tests.zig pulls in agent.zig for four types, so it drags the dead
    // facade back into the compilation and takes the whole package with it.
    // Those tests have never run: the files they test do not exist.
    // _ = @import("vsa/tests.zig");
}

// φ² + 1/φ² = 3 | TRINITY

test "every public declaration of this module is analysed" {
    // Zig analyses top-level declarations lazily, so `zig build test` proves only
    // that the declarations the tests happen to reference compile. A consumer
    // referencing anything else got errors this package's own green CI could not
    // see -- which is how five API-drift errors sat here while the badge stayed
    // green, and how gHashTag/trinity#701 found them within a minute of trying
    // to depend on this.
    //
    // With the duplicated files now re-exporting one repaired implementation,
    // this is what proves the whole surface goes through the compiler rather
    // than only the part the tests walk.
    @import("std").testing.refAllDeclsRecursive(@This());
}
