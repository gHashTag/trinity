// ═══════════════════════════════════════════════════════════════════════════════
// VSA Root Module (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code for core VSA operations
const gen = @import("gen_vsa");

// Re-export core symbols from generated code
pub const common = gen.common;
pub const ops = gen.ops;
pub const sparse = gen.sparse;
pub const encoding = gen.encoding;
pub const Trit = gen.Trit;
pub const Vec32i8 = gen.Vec32i8;
pub const Vec32i16 = gen.Vec32i16;
pub const SIMD_WIDTH = gen.SIMD_WIDTH;
pub const MAX_TRITS = gen.MAX_TRITS;
pub const SearchResult = gen.SearchResult;
pub const HybridBigInt = gen.HybridBigInt;

// Re-export VSA operations from gen_vsa (Zig 0.15 compatible - avoids module conflict)
pub const bind = gen.bind;
pub const unbind = gen.unbind;
pub const bundle2 = gen.bundle2;
pub const bundle3 = gen.bundle3;
pub const permute = gen.permute;
pub const inversePermute = gen.inversePermute;
pub const cosineSimilarity = gen.cosineSimilarity;
pub const hammingDistance = gen.hammingDistance;
pub const hammingSimilarity = gen.hammingSimilarity;
pub const dotSimilarity = gen.dotSimilarity;
pub const vectorNorm = gen.vectorNorm;
pub const bundleN = gen.bundleN;
pub const countNonZero = gen.countNonZero;
pub const randomVector = gen.randomVector;
pub const encodeSequence = gen.encodeSequence;
pub const probeSequence = gen.probeSequence;

// Import VSA submodules directly from src/vsa/ (Zig 0.15 compatibility)
pub const vsa_common = @import("vsa/common.zig");
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

// Re-export from vsa_encoding
pub const charToVector = vsa_encoding.charToVector;
pub const encodeText = vsa_encoding.encodeText;
pub const decodeText = vsa_encoding.decodeText;
pub const encodeTextWords = vsa_encoding.encodeTextWords;
pub const textSimilarity = vsa_encoding.textSimilarity;
pub const textsAreSimilar = vsa_encoding.textsAreSimilar;
pub const TEXT_VECTOR_DIM = vsa_encoding.TEXT_VECTOR_DIM;

// Re-export from vsa_storage
pub const TextCorpus = vsa_storage.TextCorpus;

// Re-export from vsa_concurrency
pub const ChaseLevDeque = vsa_concurrency.ChaseLevDeque;
pub const LockFreePool = vsa_concurrency.LockFreePool;
pub const DependencyGraph = vsa_concurrency.DependencyGraph;
pub const TaskNode = vsa_concurrency.TaskNode;
pub const TaskState = vsa_concurrency.TaskState;
pub const getGlobalPool = vsa_concurrency.getGlobalPool;

// Re-export from vsa_agent
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
pub const getUnifiedAgent = vsa_agent.getUnifiedAgent;
pub const getAgentMemory = vsa_agent.getAgentMemory;
pub const getAutonomousAgent = vsa_agent.getAutonomousAgent;
pub const getUnifiedSystem = vsa_agent.getUnifiedSystem;

// Manual (disabled):
// const manual = @import("vsa/vsa_manual.zig");
// ... re-export all symbols from manual
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
