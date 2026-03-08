// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Structural Editor Core Module Exports
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

// Tier 4 Autonomous Refactoring Engine
pub const autonomous_refactor = @import("autonomous_refactor.zig");

// HNSW Index (Tier 3.5)
pub const hnsw = @import("hnsw.zig");

// IVF Index (Tier 4.1)
pub const ivf = @import("ivf.zig");

// Core types and configuration
pub const needle = @import("needle.zig");

// Fuzzy text matcher (Tier 0 fallback)
pub const fuzzy = @import("fuzzy.zig");

// Unified matcher with tier-based fallback
pub const matcher = @import("matcher.zig");

// Structural edit operations
pub const edit = @import("edit.zig");

// Quality gates and safety checks
pub const check = @import("check.zig");

// Zig parser (Tier 2)
pub const zig_parser = @import("zig_parser.zig");

// Graph multi-file refactoring (Tier 2)
pub const graph = @import("graph.zig");

// Symbol extraction (Tier 2)
pub const symbols = @import("symbols.zig");

// Safe multi-file refactoring (Tier 2)
pub const refactor = @import("refactor.zig");

// Semantic VSA (Tier 3)
pub const vsa = @import("vsa.zig");

// Safe Cross-File (Tier 4)
pub const safe_cross = @import("safe_cross.zig");

// Omega Autonomy (Tier 5)
pub const omega = @import("omega.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Core Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const EditOperation = needle.EditOperation;
pub const MatchResult = needle.MatchResult;
pub const MatchResultList = needle.MatchResultList;
pub const MatchKind = needle.MatchKind;
pub const NeedleConfig = needle.NeedleConfig;
pub const EditReport = needle.EditReport;
pub const Violation = needle.Violation;
pub const ViolationKind = needle.ViolationKind;
pub const Severity = needle.Severity;
pub const SafetyLevel = needle.SafetyLevel;
pub const EditMode = needle.EditMode;
pub const Query = needle.Query;
pub const QueryKind = needle.QueryKind;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Matchers
// ═══════════════════════════════════════════════════════════════════════════════

pub const FuzzyMatcher = fuzzy.FuzzyMatcher;
pub const Matcher = matcher.Matcher;
pub const Searcher = matcher.Searcher;

// Convenience functions
pub const search = matcher.search;
pub const searchSource = matcher.searchSource;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Edit Operations
// ═══════════════════════════════════════════════════════════════════════════════

pub const TextEditor = edit.TextEditor;
pub const EditEngine = edit.EditEngine;
pub const EditDiff = edit.EditDiff;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Quality Gates
// ═══════════════════════════════════════════════════════════════════════════════

pub const NeedleChecker = check.NeedleChecker;

// Convenience functions
pub const checkSource = check.checkSource;
pub const checkFile = check.checkFile;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Zig Parser (Tier 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZigNode = zig_parser.ZigNode;
pub const NodeType = zig_parser.NodeType;
pub const ASTGraph = zig_parser.ASTGraph;
pub const SymbolRef = zig_parser.SymbolRef;
pub const SymbolDef = zig_parser.SymbolDef;
pub const GraphStats = zig_parser.GraphStats;

pub const ZigParser = zig_parser.ZigParser;

// Zig parser functions
pub const parseZig = zig_parser.parseZig;
pub const buildASTGraph = zig_parser.buildASTGraph;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Graph (Tier 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallGraph = graph.CallGraph;
pub const GraphNode = graph.GraphNode;
pub const Symbol = graph.Symbol;
pub const SymbolKind = graph.SymbolKind;
pub const Edge = graph.Edge;
pub const EdgeType = graph.EdgeType;
pub const EditPlan = graph.EditPlan;
pub const UsageLocation = graph.UsageLocation;
pub const UsageList = graph.UsageList;
pub const MultiFileEditResult = graph.MultiFileEditResult;

// Graph algorithms
pub const computeEditOrder = graph.computeEditOrder;
pub const detectCycles = graph.detectCycles;
pub const computeImpactZone = graph.computeImpactZone;
pub const previewMultiFileEdit = graph.previewMultiFileEdit;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Symbol Extraction (Tier 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExtractionResult = symbols.ExtractionResult;
pub const ZigSymbolExtractor = symbols.ZigSymbolExtractor;

// Symbol extraction functions
pub const buildCallGraph = symbols.buildCallGraph;
pub const buildCallGraphSingleFile = symbols.buildCallGraphSingleFile;
pub const findUsages = symbols.findUsages;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Safe Refactoring (Tier 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub const RefactorKind = refactor.RefactorKind;
pub const FileBackup = refactor.FileBackup;
pub const RefactorContext = refactor.RefactorContext;

// Refactor functions
pub const planRename = refactor.planRename;
pub const previewRename = refactor.previewRename;
pub const applyRename = refactor.applyRename;
pub const extractFunction = refactor.extractFunction;
pub const generateDiffPreview = refactor.generateDiffPreview;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Semantic VSA (Tier 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SemanticVector = vsa.SemanticVector;
pub const VSARule = vsa.VSARule;
pub const VSAMatch = vsa.VSAMatch;
pub const VSASafetyLevel = vsa.SafetyLevel;
pub const SemanticIndex = vsa.SemanticIndex;
pub const IndexType = vsa.IndexType;

// VSA functions
pub const generateHashEmbedding = vsa.generateHashEmbedding;
pub const generateVSAEmbedding = vsa.generateVSAEmbedding;
pub const cosineSimilarity = vsa.cosineSimilarity;
pub const l2Norm = vsa.l2Norm;
pub const euclideanDistance = vsa.euclideanDistance;
pub const bind = vsa.bind;
pub const unbind = vsa.unbind;
pub const bundle = vsa.bundle;
pub const buildSemanticIndex = vsa.buildSemanticIndex;
pub const semanticSearch = vsa.semanticSearch;
pub const semanticFind = vsa.semanticFind;
pub const semanticFindCached = vsa.semanticFindCached;
pub const clearSemanticCache = vsa.clearSemanticCache;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - HNSW Index (Tier 3.5)
// ═══════════════════════════════════════════════════════════════════════════════

pub const HNSWIndex = hnsw.HNSWIndex;
pub const HNSWConfig = hnsw.HNSWConfig;
pub const SearchResult = hnsw.SearchResult;
pub const DEFAULT_M = hnsw.DEFAULT_M;
pub const DEFAULT_EF_CONSTRUCTION = hnsw.DEFAULT_EF_CONSTRUCTION;
pub const DEFAULT_EF_SEARCH = hnsw.DEFAULT_EF_SEARCH;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - ANN Alternatives (Tier 3.6)
// ═══════════════════════════════════════════════════════════════════════════════

// Unified ANN interface
pub const ann_interface = @import("ann_interface.zig");
pub const ann_utils = @import("ann_utils.zig");

// ANN implementations
pub const ann_brute_simd = @import("ann_brute_simd.zig");
pub const ann_lsh_ternary = @import("ann_lsh_ternary.zig");
pub const ann_ivf_pq = @import("ann_ivf_pq.zig");
pub const ann_benchmark = @import("ann_benchmark.zig");

// ANN types
pub const ANNType = ann_interface.ANNType;
pub const ANNConfig = ann_interface.ANNConfig;
pub const ANNResult = ann_interface.ANNResult;
pub const ANNStats = ann_interface.ANNStats;
pub const DistanceMetric = ann_interface.DistanceMetric;

// ANN implementations
pub const BruteIndex = ann_brute_simd.BruteIndex;
pub const BruteConfig = ann_brute_simd.BruteConfig;
pub const LSHIndex = ann_lsh_ternary.LSHIndex;
pub const LSHConfig = ann_lsh_ternary.LSHConfig;
pub const TernaryVector = ann_lsh_ternary.TernaryVector;
pub const IVFPQIndex = ann_ivf_pq.IVFPQIndex;
pub const IVFConfig = ann_ivf_pq.IVFConfig;

// Benchmark types
pub const BenchmarkConfig = ann_benchmark.BenchmarkConfig;
pub const BenchmarkResult = ann_benchmark.BenchmarkResult;
pub const BenchmarkSuite = ann_benchmark.BenchmarkSuite;
pub const OutputFormat = ann_benchmark.OutputFormat;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Safe Cross-File (Tier 4)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SafeVSARule = safe_cross.SafeVSARule;
pub const CrossFileEdit = safe_cross.CrossFileEdit;
pub const CrossFileImpact = safe_cross.CrossFileImpact;
pub const SafetyGate = safe_cross.SafetyGate;
pub const CrossFileResult = safe_cross.CrossFileResult;
pub const SafetyResult = safe_cross.SafetyResult;
pub const UnifiedPreview = safe_cross.UnifiedPreview;
pub const RuleValidation = safe_cross.RuleValidation;

// Safe cross-file functions
pub const validateWithVSARules = safe_cross.validateWithVSARules;
pub const runSafetyGates = safe_cross.runSafetyGates;
pub const computeCrossImpact = safe_cross.computeCrossImpact;
pub const applySafeCrossRefactor = safe_cross.applySafeCrossRefactor;
pub const rollbackAll = safe_cross.rollbackAll;
pub const crossPreview = safe_cross.crossPreview;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Omega Autonomy (Tier 5)
// ═══════════════════════════════════════════════════════════════════════════════

pub const AgentState = omega.AgentState;
pub const AutonomyLevel = omega.AutonomyLevel;
pub const RiskLevel = omega.RiskLevel;
pub const RefactorHistory = omega.RefactorHistory;
pub const RefactorStep = omega.RefactorStep;
pub const StepOperation = omega.StepOperation;
pub const ImprovementSuggestion = omega.ImprovementSuggestion;
pub const AutonomousResult = omega.AutonomousResult;
pub const HealthReport = omega.HealthReport;
pub const OmegaAgent = omega.OmegaAgent;

// Omega functions
pub const omegaInit = omega.omegaInit;
pub const omegaHealthCheck = omega.omegaHealthCheck;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Tier 4 Autonomous Refactoring Engine
// ═══════════════════════════════════════════════════════════════════════════════

pub const AutonomousRefactorEngine = autonomous_refactor.AutonomousRefactorEngine;
pub const RefactorIntent = autonomous_refactor.RefactorIntent;
pub const RefactorPlan = autonomous_refactor.RefactorPlan;
pub const RefactorResult = autonomous_refactor.RefactorResult;
pub const RefactorScope = autonomous_refactor.RefactorScope;
pub const TransformType = autonomous_refactor.TransformType;
pub const Transformation = autonomous_refactor.Transformation;
pub const SymbolLocation = autonomous_refactor.SymbolLocation;
pub const RollbackPlan = autonomous_refactor.RollbackPlan;
pub const RalphLoop = autonomous_refactor.RalphLoop;
pub const RefactorConfig = autonomous_refactor.RefactorConfig;

// ═══════════════════════════════════════════════════════════════════════════════
// MCP AST Query Tool (Tier 2.4)
// ═══════════════════════════════════════════════════════════════════════════════

pub const mcp_ast = @import("mcp_ast.zig");
pub const McpServer = mcp_ast.McpServer;
pub const McpRequest = mcp_ast.McpRequest;
pub const McpResponse = mcp_ast.McpResponse;
pub const McpMethod = mcp_ast.McpMethod;
pub const parseMcpRequest = mcp_ast.parseRequest;

// ═══════════════════════════════════════════════════════════════════════════════
// Tier 3 VSA Tests
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

test "vsa.1: Hash-based embedding generation" {
    const allocator = std.testing.allocator;
    const embedding = try vsa.generateHashEmbedding(allocator, "test", "sig", "ctx", 64);
    defer allocator.free(embedding);
    try std.testing.expectEqual(@as(usize, 64), embedding.len);
    const norm = vsa.l2Norm(embedding);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), norm, 0.01);
}

test "vsa.2: SemanticVector init and deinit" {
    const allocator = std.testing.allocator;
    var vec = try vsa.SemanticVector.init(allocator, "testSymbol", 128);
    defer vec.deinit();
    try std.testing.expectEqual(@as(usize, 128), vec.embedding.len);
    try std.testing.expectEqualStrings("testSymbol", vec.symbol_id);
}

test "vsa.3: SemanticIndex init" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 256);
    defer index.deinit();
    try std.testing.expectEqual(@as(usize, 256), index.embedding_dim);
}

test "vsa.4: Add vector to index" {
    const allocator = std.testing.allocator;
    var index = try vsa.SemanticIndex.init(allocator, 128);
    defer index.deinit();
    var vec = try vsa.SemanticVector.init(allocator, "add_test", 128);
    defer vec.deinit();
    try index.addVector(vec);
    try std.testing.expectEqual(@as(usize, 1), index.vectors.count());
}

test "vsa.5: Cosine similarity of identical vectors" {
    const vec = [_]f32{ 0.5, 0.5, 0.5, 0.5 };
    const similarity = vsa.cosineSimilarity(&vec, &vec) catch 0.0;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), similarity, 0.001);
}

test "vsa.6: L2 norm calculation" {
    const vec = [_]f32{ 3.0, 4.0 };
    const norm = vsa.l2Norm(&vec);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), norm, 0.01);
}

test "vsa.7: Euclidean distance" {
    const vec1 = [_]f32{ 0.0, 0.0 };
    const vec2 = [_]f32{ 3.0, 4.0 };
    const dist = vsa.euclideanDistance(&vec1, &vec2);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dist, 0.01);
}

test "vsa.8: VSAMatch confidence computation" {
    var match = vsa.VSAMatch.init(std.testing.allocator);
    defer match.deinit();
    match.similarity = 0.8;
    match.context_match = 0.6;
    match.computeConfidence();
    try std.testing.expectApproxEqAbs(@as(f32, 0.74), match.confidence, 0.01);
}
