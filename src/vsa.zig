// VSA module — Zone Root
// Re-exports all VSA modules for Anti-Fragile Import Law
//
// Uses src/vsa.zig (not src/vsa/root.zig) to allow ../hybrid.zig imports
// φ² + 1/φ² = 3 | TRINITY

pub const common = @import("vsa/common.zig");
pub const core = @import("vsa/core.zig");
pub const encoding = @import("vsa/encoding.zig");
pub const storage = @import("vsa/storage.zig");
pub const concurrency = @import("vsa/concurrency.zig");
pub const agent = @import("vsa/agent.zig");
pub const HRR = @import("vsa/hrr.zig").HRR;
pub const bsd = @import("vsa/bsd.zig");

// Additional VSA modules
pub const benchmarks = @import("vsa/benchmarks.zig");
pub const fpga_bind = @import("vsa/fpga_bind.zig");
pub const hrr = @import("vsa/hrr.zig");
pub const photon = @import("vsa/photon.zig");
pub const quantum_transition = @import("vsa/quantum_transition.zig");
pub const tests = @import("vsa/tests.zig");

// Re-export common types for convenience
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
pub const charToVector = encoding.charToVector;
pub const encodeText = encoding.encodeText;
pub const decodeText = encoding.decodeText;
pub const encodeTextWords = encoding.encodeTextWords;
pub const textSimilarity = encoding.textSimilarity;
pub const textsAreSimilar = encoding.textsAreSimilar;
pub const TEXT_VECTOR_DIM = encoding.TEXT_VECTOR_DIM;

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

