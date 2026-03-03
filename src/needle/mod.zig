// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Structural Editor Core Module Exports
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

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
pub const RefactorConfig = refactor.RefactorConfig;
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
pub const RefactorPlan = omega.RefactorPlan;
pub const ImprovementSuggestion = omega.ImprovementSuggestion;
pub const AutonomousResult = omega.AutonomousResult;
pub const HealthReport = omega.HealthReport;
pub const OmegaAgent = omega.OmegaAgent;

// Omega functions
pub const omegaInit = omega.omegaInit;
pub const omegaHealthCheck = omega.omegaHealthCheck;
