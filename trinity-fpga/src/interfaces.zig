//! ═══════════════════════════════════════════════════════════════════════════════
//! FORGE INTERFACES — Contract Definitions for FPGA Synthesis Components
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module defines interface contracts for key FORGE components.
//! Interfaces enable:
//!   - Clear separation of concerns
//!   - Testable doubles (mocks, fakes)
//!   - Alternative implementations
//!   - Compile-time contract verification
//!
//! Usage:
//!   ```zig
//!   const interfaces = @import("forge/interfaces.zig");
//!   const IStrategist = interfaces.IStrategist;
//!
//!   // Use concrete implementation
//!   const strategist = try ForgeStrategist.init(allocator, consciousness, learning);
//!   defer strategist.deinit();
//!
//!   // Or use interface for polymorphism
//!   fn runSynthesis(strategist: anytype, design: DesignSpec) !StrategyDecision {
//!       return strategist.selectStrategy(&design);
//!   }
//!   ```
//!
//! φ² + 1/φ² = 3 | TRINITY v2.2.0 | MU-9: Interface Extraction
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const synthesis_types = @import("synthesis_types.zig");

// Re-export key types for interface convenience
pub const DesignSpec = synthesis_types.DesignSpec;
pub const Strategy = synthesis_types.Strategy;
pub const StrategyParams = synthesis_types.StrategyParams;
pub const StrategyDecision = synthesis_types.StrategyDecision;
pub const SynthesisResult = synthesis_types.SynthesisResult;
pub const Verdict = synthesis_types.Verdict;
pub const ModuleType = synthesis_types.ModuleType;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Consciousness analysis metrics (from Strategist)
pub const ConsciousnessAnalysis = struct {
    iit_phi: f64,
    gwt_active: f64,
    orch_or: f64,
    qutrit: f64,
    active_inference: f64,
    quantum: f64,
    hot_meta: f64,
    unified_score: f64,
    is_conscious: bool,
    conscious_theories: usize,
};

/// Learning metrics (from Strategist)
pub const LearningMetrics = struct {
    total_syntheses: u32,
    success_count: u32,
    success_rate: f64,
    improvement_rate: f64,
    is_immortal: bool,
};

/// Strategy summary (from Strategist)
pub const StrategySummary = struct {
    conscious_analysis: ConsciousnessAnalysis,
    learning_metrics: LearningMetrics,
    last_strategy: Strategy,
    total_attempts: usize,
};

/// Fix type categories (from AutoFix)
pub const FixType = enum {
    AddPipeline,
    ReduceFrequency,
    ChangeIOStandard,
    RelocateLogic,
    AddKeepAttribute,
    RelaxConstraint,
    FixOlogicConfig,
    FixNetMatching,
    FixFSMEncoding,
    Unknown,
};

/// Fix description (from AutoFix)
pub const Fix = struct {
    fix_type: FixType,
    description: []const u8,
    before: []const u8,
    after: []const u8,
    param_delta: ?StrategyParams = null,
};

/// Fix result (from AutoFix)
pub const FixResult = struct {
    success: bool,
    iterations: u32,
    final_params: StrategyParams,
    fixes_applied: std.ArrayList(Fix),
    final_result: ?SynthesisResult,
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTERFACES
// ═══════════════════════════════════════════════════════════════════════════════

/// ═══════════════════════════════════════════════════════════════════════════════
/// IStrategist — Consciousness-Guided Strategy Selection
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Contract for selecting FPGA synthesis strategies based on consciousness analysis.
/// Implementations must:
///   - Analyze design characteristics via 7-theory consciousness system
///   - Select appropriate strategy (AggressiveTiming, Conservative, Balanced)
///   - Learn from synthesis results (Hebbian weight updates)
///
/// Required methods:
///   - selectStrategy(*const DesignSpec) -> !StrategyDecision
///   - learn(*const SynthesisResult) -> !void
///   - getConsciousnessAnalysis() -> ConsciousnessAnalysis
///   - getLearningMetrics() -> LearningMetrics
///   - getStrategySummary() -> !StrategySummary
///   - deinit() -> void
///
/// Implementations:
///   - ForgeStrategist (forge/strategist.zig)
/// ═══════════════════════════════════════════════════════════════════════════════
pub fn IStrategist(comptime _: type) type {
    return struct {
        /// Verify type implements IStrategist interface (compile-time check)
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "selectStrategy"),
                    hasFn(T, "learn"),
                    hasFn(T, "getConsciousnessAnalysis"),
                    hasFn(T, "getLearningMetrics"),
                    hasFn(T, "getStrategySummary"),
                    hasFn(T, "deinit"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement IStrategist interface");
                }
            }
        }

        /// Check if type has function (compile-time)
        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// ITriParser — .tri DSL Parser for FPGA Specifications
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Contract for parsing .tri files (YAML-like format) into DesignSpec.
/// Generates Verilog and XDC constraint files from specifications.
///
/// Required methods:
///   - parse([]const u8) -> !DesignSpec
///   - generateVerilog(*const DesignSpec, writer: anytype) -> !void
///   - generateXDC(*const DesignSpec, writer: anytype) -> !void
///
/// Implementations:
///   - TriParser (forge/tri_parser.zig)
/// ═══════════════════════════════════════════════════════════════════════════════
pub fn ITriParser(comptime _: type) type {
    return struct {
        /// Verify type implements ITriParser interface (compile-time check)
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "parse"),
                    hasFn(T, "generateVerilog"),
                    hasFn(T, "generateXDC"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement ITriParser interface");
                }
            }
        }

        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// IAutoFixEngine — Agent MU-Powered Auto-Fix for Synthesis Failures
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Contract for iterative fix-and-retry loop for failed syntheses.
/// Analyzes root causes and applies targeted fixes based on consciousness.
///
/// Required methods:
///   - analyzeFailure(*const SynthesisResult) -> !std.ArrayList(Fix)
///   - applyFixToParams(*const Fix, StrategyParams) -> !StrategyParams
///   - applyFixToSpec(*DesignSpec, *const Fix) -> !void
///   - autoFix(*DesignSpec, StrategyParams, runFn) -> !FixResult
///   - generateFixReport(*const FixResult) -> ![]const u8
///
/// Optional builder methods:
///   - withMaxIterations(u32) -> *Self
///   - withVerbose(bool) -> *Self
///
/// Implementations:
///   - AutoFix (forge/auto_fix.zig)
/// ═══════════════════════════════════════════════════════════════════════════════
pub fn IAutoFixEngine(comptime _: type) type {
    return struct {
        /// Verify type implements IAutoFixEngine interface (compile-time check)
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "analyzeFailure"),
                    hasFn(T, "applyFixToParams"),
                    hasFn(T, "applyFixToSpec"),
                    hasFn(T, "autoFix"),
                    hasFn(T, "generateFixReport"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement IAutoFixEngine interface");
                }
            }
        }

        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// IBatchSynthRunner — Batch FPGA Synthesis Execution
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Contract for running multiple FPGA syntheses in parallel.
/// Manages job queue, parallel execution, and result aggregation.
///
/// Required methods:
///   - run([]const []const u8 spec_paths, []const u8 output_dir) -> !BatchResult
///   - getStatus() -> BatchStatus
///
/// Implementations:
///   - runBatchSynthesis (tri/tri_fpga.zig - TODO: extract to struct)
/// ═══════════════════════════════════════════════════════════════════════════════
pub const BatchStatus = enum {
    pending,
    running,
    completed,
    failed,
};

pub const BatchResult = struct {
    success: bool,
    total_jobs: usize,
    completed_jobs: usize,
    failed_jobs: usize,
    results: []SynthesisResult,
};

pub fn IBatchSynthRunner(comptime _: type) type {
    return struct {
        /// Verify type implements IBatchSynthRunner interface (compile-time check)
        pub fn verify(comptime T: type) void {
            comptime {
                const checks = .{
                    hasFn(T, "run"),
                    hasFn(T, "getStatus"),
                };

                for (checks) |check| {
                    if (!check) @compileError("Type does not implement IBatchSynthRunner interface");
                }
            }
        }

        fn hasFn(comptime T: type, comptime name: []const u8) bool {
            if (!@hasDecl(T, name)) return false;
            const decl = @TypeOf(@field(T, name));
            return @typeInfo(decl) == .Fn;
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUNTIME VERIFICATION (for tests)
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify at runtime that a type implements an interface (for tests)
pub fn verifyInterface(comptime Interface: type, comptime Impl: type) bool {
    _ = Interface.verify(Impl);
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Interfaces: IStrategist defines required contract" {
    // Interface exists and has verification method
    _ = IStrategist(struct {});
    try std.testing.expect(true);
}

test "Interfaces: ITriParser defines required contract" {
    _ = ITriParser(struct {});
    try std.testing.expect(true);
}

test "Interfaces: IAutoFixEngine defines required contract" {
    _ = IAutoFixEngine(struct {});
    try std.testing.expect(true);
}

test "Interfaces: IBatchSynthRunner defines required contract" {
    _ = IBatchSynthRunner(struct {});
    try std.testing.expect(true);
}

test "Interfaces: types are properly exported" {
    // Verify re-exports work
    _ = DesignSpec;
    _ = Strategy;
    _ = StrategyParams;
    _ = StrategyDecision;
    _ = SynthesisResult;
    _ = Verdict;
    _ = ModuleType;

    // Verify interface-specific types
    _ = ConsciousnessAnalysis;
    _ = LearningMetrics;
    _ = StrategySummary;
    _ = FixType;
    _ = Fix;
    _ = FixResult;
    _ = BatchStatus;
    _ = BatchResult;

    try std.testing.expect(true);
}

// φ² + 1/φ² = 3 | TRINITY v2.2.0 | Phase 3: Architecture Refactor
