// ═══════════════════════════════════════════════════════════════════════════════
// VSA Root Module (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_vsa.zig");

// Re-export all module-level symbols
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
pub const vsa_common = gen.vsa_common;
pub const vsa_core_compat = gen.vsa_core_compat;
pub const vsa_encoding = gen.vsa_encoding;
pub const vsa_storage = gen.vsa_storage;
pub const vsa_concurrency = gen.vsa_concurrency;
pub const vsa_agent = gen.vsa_agent;
pub const vsa_hrr = gen.vsa_hrr;
pub const vsa_bsd = gen.vsa_bsd;
pub const vsa_benchmarks = gen.vsa_benchmarks;
pub const vsa_fpga_bind = gen.vsa_fpga_bind;
pub const vsa_tests = gen.vsa_tests;
pub const HRR = gen.HRR;
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
pub const charToVector = gen.charToVector;
pub const encodeText = gen.encodeText;
pub const decodeText = gen.decodeText;
pub const encodeTextWords = gen.encodeTextWords;
pub const textSimilarity = gen.textSimilarity;
pub const textsAreSimilar = gen.textsAreSimilar;
pub const TEXT_VECTOR_DIM = gen.TEXT_VECTOR_DIM;
pub const TextCorpus = gen.TextCorpus;
pub const ChaseLevDeque = gen.ChaseLevDeque;
pub const LockFreePool = gen.LockFreePool;
pub const DependencyGraph = gen.DependencyGraph;
pub const TaskNode = gen.TaskNode;
pub const TaskState = gen.TaskState;
pub const getGlobalPool = gen.getGlobalPool;
pub const UnifiedAgent = gen.UnifiedAgent;
pub const AgentMemory = gen.AgentMemory;
pub const AgentRole = gen.AgentRole;
pub const Modality = gen.Modality;
pub const MultiModalToolUse = gen.MultiModalToolUse;
pub const AutonomousAgent = gen.AutonomousAgent;
pub const ImprovementLoop = gen.ImprovementLoop;
pub const UnifiedAutonomousSystem = gen.UnifiedAutonomousSystem;
pub const UnifiedRequest = gen.UnifiedRequest;
pub const UnifiedResponse = gen.UnifiedResponse;
pub const SystemCapability = gen.SystemCapability;
pub const getUnifiedAgent = gen.getUnifiedAgent;
pub const getAgentMemory = gen.getAgentMemory;
pub const getAutonomousAgent = gen.getAutonomousAgent;
pub const getUnifiedSystem = gen.getUnifiedSystem;

// Manual (disabled):
// const manual = @import("vsa/vsa_manual.zig");
// ... re-export all symbols from manual
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
