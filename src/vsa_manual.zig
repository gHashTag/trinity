// VSA module — Zone Root
// Re-exports all VSA modules for Anti-Fragile Import Law
//
// Now a thin glue layer over vsa_core (single source of truth)
// HybridBigInt consumers import from hybrid module
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const vsa_core = @import("vsa_core");
const hybrid_mod = @import("hybrid");

// ═══════════════════════════════════════════════════════════════════════════════
// Re-export from vsa_core (pure algorithms, no HybridBigInt)
// ═══════════════════════════════════════════════════════════════════════════════

pub const common = vsa_core.common;
pub const ops = vsa_core.ops;
pub const sparse = vsa_core.sparse;
pub const encoding = vsa_core.encoding;

// Re-export core types from vsa_core
pub const Trit = vsa_core.Trit;
pub const Vec32i8 = vsa_core.Vec32i8;
pub const Vec32i16 = vsa_core.Vec32i16;
pub const SIMD_WIDTH = vsa_core.SIMD_WIDTH;
pub const MAX_TRITS = vsa_core.MAX_TRITS;
pub const SearchResult = vsa_core.SearchResult;

// ═══════════════════════════════════════════════════════════════════════════════
// HybridBigInt from hybrid module (re-export for convenience)
// ═══════════════════════════════════════════════════════════════════════════════

pub const HybridBigInt = hybrid_mod.HybridBigInt;

// ═══════════════════════════════════════════════════════════════════════════════
// Backward Compatibility: re-export VSA submodules from src/vsa/
// ═══════════════════════════════════════════════════════════════════════════════

// These files in src/vsa/ are now convenience wrappers around vsa_core + hybrid
pub const vsa_common = @import("vsa/common.zig");
pub const vsa_core_compat = @import("vsa/core.zig"); // HybridBigInt operations
pub const vsa_encoding = @import("vsa/encoding.zig");
pub const vsa_storage = @import("vsa/storage.zig");
pub const vsa_concurrency = @import("vsa/concurrency.zig");
pub const vsa_agent = @import("vsa/agent.zig");
pub const vsa_hrr = @import("vsa/hrr.zig");
pub const vsa_bsd = @import("vsa/bsd.zig");
pub const vsa_benchmarks = @import("vsa/benchmarks.zig");
pub const vsa_fpga_bind = @import("vsa/fpga_bind.zig");
pub const vsa_tests = @import("vsa/tests.zig");

// Re-export HRR convenience
pub const HRR = vsa_hrr.HRR;

// ═══════════════════════════════════════════════════════════════════════════════
// HybridBigInt VSA Operations (from src/vsa/core.zig)
// ═══════════════════════════════════════════════════════════════════════════════

// These are HybridBigInt-specific operations, kept in src/vsa/core.zig
// for backward compatibility with existing code

pub const bind = vsa_core_compat.bind;
pub const unbind = vsa_core_compat.unbind;
pub const bundle2 = vsa_core_compat.bundle2;
pub const bundle3 = vsa_core_compat.bundle3;
pub const permute = vsa_core_compat.permute;
pub const inversePermute = vsa_core_compat.inversePermute;
pub const cosineSimilarity = vsa_core_compat.cosineSimilarity;
pub const hammingDistance = vsa_core_compat.hammingDistance;
pub const hammingSimilarity = vsa_core_compat.hammingSimilarity;
pub const dotSimilarity = vsa_core_compat.dotSimilarity;
pub const vectorNorm = vsa_core_compat.vectorNorm;
pub const bundleN = vsa_core_compat.bundleN;
pub const countNonZero = vsa_core_compat.countNonZero;
pub const randomVector = vsa_core_compat.randomVector;
pub const encodeSequence = vsa_core_compat.encodeSequence;
pub const probeSequence = vsa_core_compat.probeSequence;

// ═══════════════════════════════════════════════════════════════════════════════
// Text Encoding (from src/vsa/encoding.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const charToVector = vsa_encoding.charToVector;
pub const encodeText = vsa_encoding.encodeText;
pub const decodeText = vsa_encoding.decodeText;
pub const encodeTextWords = vsa_encoding.encodeTextWords;
pub const textSimilarity = vsa_encoding.textSimilarity;
pub const textsAreSimilar = vsa_encoding.textsAreSimilar;
pub const TEXT_VECTOR_DIM = vsa_encoding.TEXT_VECTOR_DIM;

// ═══════════════════════════════════════════════════════════════════════════════
// Storage (from src/vsa/storage.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TextCorpus = vsa_storage.TextCorpus;

// ═══════════════════════════════════════════════════════════════════════════════
// Concurrency & DAG (from src/vsa/concurrency.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChaseLevDeque = vsa_concurrency.ChaseLevDeque;
pub const LockFreePool = vsa_concurrency.LockFreePool;
pub const DependencyGraph = vsa_concurrency.DependencyGraph;
pub const TaskNode = vsa_concurrency.TaskNode;
pub const TaskState = vsa_concurrency.TaskState;
pub const getGlobalPool = vsa_concurrency.getGlobalPool;

// ═══════════════════════════════════════════════════════════════════════════════
// Agentic systems (from src/vsa/agent.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedAgent = vsa_agent.UnifiedAgent;
pub const AgentMemory = vsa_agent.AgentMemory;
pub const AgentRole = vsa_agent.AgentRole;
pub const Modality = vsa_agent.Modality;
pub const MultiModalToolUse = vsa_agent.MultiModalToolUse;
pub const AutonomousAgent = vsa_agent.AutonomousAgent;
pub const ImprovementLoop = vsa_agent.ImprovementLoop;
pub const UnifiedAutonomousSystem = vsa_agent.UnifiedAutonomousSystem;
pub const UnifiedRequest = vsa_agent.UnifiedRequest;
pub const UnifiedResponse = vsa_agent.UnifiedResponse;
pub const SystemCapability = vsa_agent.SystemCapability;

// Prototypical accessors
pub const getUnifiedAgent = vsa_agent.getUnifiedAgent;
pub const getAgentMemory = vsa_agent.getAgentMemory;
pub const getAutonomousAgent = vsa_agent.getAutonomousAgent;
pub const getUnifiedSystem = vsa_agent.getUnifiedSystem;

test "vsa module imports vsa_core" {
    _ = vsa_core.ops;
    _ = vsa_core.sparse;
    _ = vsa_core.encoding;

    // Verify HybridBigInt is available
    _ = hybrid_mod.HybridBigInt;
}

test "vsa module backward compatibility" {
    // Old code using @import("vsa").bind should still work
    const a = try hybrid_mod.HybridBigInt.fromI64(123);
    const b = try hybrid_mod.HybridBigInt.fromI64(456);

    _ = bind(&a, &b);
    _ = unbind(&a, &b);
}
