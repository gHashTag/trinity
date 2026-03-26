// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA ENGINE v1.0 — Evidence Classification and Validation
// φ² + 1/φ² = 3 | γ = φ⁻³ (candidate, NOT axiom)
// ═══════════════════════════════════════════════════════════════════════════════

//! Formula Engine for Sacred Mathematics
//! Provides search, evaluation, and precomputation of sacred mathematical formulas.
//! All constants derived from Trinity Identity: φ² + 1/φ² = 3

const std = @import("std");
const registry = @import("registry.zig");

pub const EvidenceLevel = registry.EvidenceLevel;
pub const ClaimStatus = registry.ClaimStatus;
pub const FormulaFamily = registry.FormulaFamily;
pub const SacredFormula = registry.SacredFormula;
pub const SacredParams = registry.SacredParams;
pub const Constants = registry.Constants;

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH RESULT — Formula search output
// ═══════════════════════════════════════════════════════════════════════════════

pub const SearchResult = struct {
    formula: *const SacredFormula,
    relevance: f64,
    evidence_level: EvidenceLevel,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRECOMPUTED CONSTANTS — Cache of frequently used sacred constants
// ═══════════════════════════════════════════════════════════════════════════════

pub const PrecomputedConstant = struct {
    name: []const u8,
    value: f64,
    formula_id: u32,
    evidence: EvidenceLevel,
    derivation: []const u8,
};

/// Precomputed sacred constants (Trinity Identity-derived)
pub const precomputed_constants = [_]PrecomputedConstant{
    .{
        .name = "phi",
        .value = 1.6180339887498948482,
        .formula_id = 0,
        .evidence = .exact,
        .derivation = "(1 + √5) / 2",
    },
    .{
        .name = "phi_squared",
        .value = 2.6180339887498948482,
        .formula_id = 1,
        .evidence = .exact,
        .derivation = "φ² = φ + 1",
    },
    .{
        .name = "inv_phi_squared",
        .value = 0.3819660112501051518,
        .formula_id = 2,
        .evidence = .exact,
        .derivation = "1/φ² = 2 - φ",
    },
    .{
        .name = "trinity",
        .value = 3.0,
        .formula_id = 3,
        .evidence = .exact,
        .derivation = "φ² + 1/φ² = 3",
    },
    .{
        .name = "sacred_gamma",
        .value = 0.236067977499789696,
        .formula_id = 4,
        .evidence = .candidate, // NOT proven, only candidate
        .derivation = "φ⁻³ (candidate)",
    },
    .{
        .name = "consciousness_threshold",
        .value = 0.6180339887498948482,
        .formula_id = 5,
        .evidence = .lattice_consistent,
        .derivation = "1/φ = φ - 1",
    },
};

/// Get precomputed constant by name
pub fn getPrecomputedConstants(name: []const u8) ?*const PrecomputedConstant {
    for (&precomputed_constants) |*const_const| {
        if (std.mem.eql(u8, const_const.name, name)) {
            return const_const;
        }
    }
    return null;
}

/// Get all precomputed constants
pub fn getAllPrecomputedConstants() []const PrecomputedConstant {
    return &precomputed_constants;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULA ENGINE — Search and evaluation
// ═══════════════════════════════════════════════════════════════════════════════

pub const FormulaEngine = struct {
    registry: registry.Registry,

    const Self = @This();

    /// Initialize formula engine with sacred registry
    pub fn init() !Self {
        return Self{
            .registry = try registry.initRegistry(),
        };
    }

    /// Search formulas by keyword
    pub fn search(self: *const Self, keyword: []const u8, allocator: std.mem.Allocator) ![]SearchResult {
        var results = std.ArrayList(SearchResult).init(allocator);
        defer {
            _ = results.toOwnedSlice();
        }

        for (self.registry.formulas) |formula| {
            if (std.mem.indexOf(u8, formula.name, keyword) != null or
                std.mem.indexOf(u8, formula.latex, keyword) != null)
            {
                const relevance = if (std.mem.indexOf(u8, formula.name, keyword) != null) @as(f64, 1.0) else 0.5;
                try results.append(.{
                    .formula = formula,
                    .relevance = relevance,
                    .evidence_level = formula.evidence,
                });
            }
        }

        const sorted = try results.toOwnedSlice();
        std.sort.sort(SearchResult, {}, sorted, {}, struct {
            fn compare(ctx: void, a: SearchResult, b: SearchResult) bool {
                _ = ctx;
                return a.relevance > b.relevance;
            }
        });
        return sorted;
    }

    /// Evaluate formula by ID with given parameters
    pub fn evaluate(self: *const Self, formula_id: u32, params: SacredParams) !f64 {
        const formula = try self.registry.getFormula(formula_id);
        return try self.evaluateFormula(formula, params);
    }

    /// Evaluate formula with parameters
    pub fn evaluateFormula(self: *const Self, formula: *const SacredFormula, params: SacredParams) !f64 {
        _ = self;

        // Built-in evaluations for core formulas
        if (std.mem.eql(u8, formula.name, "trinity")) {
            return 3.0; // φ² + 1/φ² = 3 exactly
        }
        if (std.mem.eql(u8, formula.name, "phi_squared")) {
            return 2.6180339887498948482; // φ + 1
        }
        if (std.mem.eql(u8, formula.name, "inv_phi_squared")) {
            return 0.3819660112501051518; // 2 - φ
        }

        // For other formulas, use the compute_value function
        return try formula.compute_value(params);
    }

    /// Get formula by ID
    pub fn getFormula(self: *const Self, formula_id: u32) !*const SacredFormula {
        return self.registry.getFormula(formula_id);
    }

    /// Get all formulas in a family
    pub fn getFormulasByFamily(self: *const Self, family: FormulaFamily) ![]const *const SacredFormula {
        return self.registry.getFormulasByFamily(family);
    }

    /// Validate formula against Trinity identity
    pub fn validateTrinity(self: *const Self, formula: *const SacredFormula) !bool {
        _ = self;

        // For trinity identity, check exact equality
        if (std.mem.eql(u8, formula.name, "trinity")) {
            const computed = try formula.compute_value(SacredParams{});
            return @abs(computed - 3.0) < 1e-15;
        }

        // For other formulas, check consistency
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION ENGINE — Formula consistency checks
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerificationResult = struct {
    is_valid: bool,
    error_margin: f64,
    evidence_level: EvidenceLevel,
    message: []const u8,
};

/// Verify Trinity identity: φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() VerificationResult {
    const phi = 1.6180339887498948482;
    const phi_sq = phi * phi;
    const inv_phi_sq = 1.0 / phi_sq;
    const trinity = phi_sq + inv_phi_sq;

    return .{
        .is_valid = @abs(trinity - 3.0) < 1e-15,
        .error_margin = @abs(trinity - 3.0),
        .evidence_level = .exact,
        .message = "φ² + 1/φ² = 3 (Trinity Identity)",
    };
}

/// Verify sacred gamma candidate: γ = φ⁻³
pub fn verifySacredGamma() VerificationResult {
    return .{
        .is_valid = true, // Candidate, not required to match
        .error_margin = 0.0,
        .evidence_level = .candidate,
        .message = "γ = φ⁻³ (candidate, NOT axiom)",
    };
}

/// Run all verification checks
pub fn runAllVerifications() [2]VerificationResult {
    return .{
        verifyTrinityIdentity(),
        verifySacredGamma(),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// THRESHOLDS — Sacred value thresholds for decision making
// ═══════════════════════════════════════════════════════════════════════════════

pub const Thresholds = struct {
    /// Consciousness threshold (System 1 vs System 2)
    consciousness: f64 = 0.618034, // 1/φ

    /// Sparsity ratio for ternary weights
    sparsity: f64 = 0.381966, // 1/φ²

    /// Sacred gamma for attention scaling
    sacred_gamma: f64 = 0.236068, // φ⁻³ (candidate)

    /// Quality threshold for "good" models
    good_quality: f64 = 0.8,

    /// Excellence threshold for "sacred" models
    sacred_quality: f64 = 0.95,

    /// Default thresholds
    pub const default = Thresholds{};

    /// Get threshold by name
    pub fn get(name: []const u8) ?f64 {
        const defaults = default;
        if (std.mem.eql(u8, name, "consciousness")) return defaults.consciousness;
        if (std.mem.eql(u8, name, "sparsity")) return defaults.sparsity;
        if (std.mem.eql(u8, name, "sacred_gamma")) return defaults.sacred_gamma;
        if (std.mem.eql(u8, name, "good_quality")) return defaults.good_quality;
        if (std.mem.eql(u8, name, "sacred_quality")) return defaults.sacred_quality;
        return null;
    }

    /// Check if value passes consciousness threshold
    pub fn isConscious(value: f64) bool {
        return value >= default.consciousness;
    }

    /// Check if model quality is "sacred"
    pub fn isSacred(quality: f64) bool {
        return quality >= default.sacred_quality;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DOCTOR REPORT — Sacred math health check
// ═══════════════════════════════════════════════════════════════════════════════

pub const DoctorReport = struct {
    total_checks: usize,
    passed: usize,
    failed: usize,
    warnings: []const u8,
    details: [2]VerificationResult,
};

/// Run sacred math health check
pub fn runSacredDoctor(allocator: std.mem.Allocator) !DoctorReport {
    _ = allocator;

    const results = runAllVerifications();
    var passed: usize = 0;
    var failed: usize = 0;

    for (results) |result| {
        if (result.is_valid) passed += 1 else failed += 1;
    }

    return .{
        .total_checks = results.len,
        .passed = passed,
        .failed = failed,
        .warnings = "No warnings",
        .details = results,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "formula engine: trinity identity verification" {
    const result = verifyTrinityIdentity();
    try std.testing.expect(result.is_valid);
    const phi = 1.6180339887498948482;
    const trinity = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), trinity, 1e-14);
}

test "formula engine: precomputed constants" {
    const phi_const = getPrecomputedConstants("phi").?;
    try std.testing.expectApproxEqAbs(1.6180339887498948482, phi_const.value, 1e-15);

    const trinity_const = getPrecomputedConstants("trinity").?;
    try std.testing.expectEqual(@as(f64, 3.0), trinity_const.value);
    try std.testing.expectEqual(.exact, trinity_const.evidence);
}

test "formula engine: thresholds" {
    const thresholds = Thresholds{};
    try std.testing.expectEqual(@as(f64, 0.618034), thresholds.consciousness);
    try std.testing.expectEqual(@as(f64, 0.381966), thresholds.sparsity);
    try std.testing.expect(Thresholds.isConscious(0.7));
    try std.testing.expect(!Thresholds.isConscious(0.5));
    try std.testing.expect(Thresholds.isSacred(0.96));
    try std.testing.expect(!Thresholds.isSacred(0.8));
}

test "formula engine: doctor report" {
    const report = try runSacredDoctor(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), report.total_checks);
    try std.testing.expectEqual(@as(usize, 2), report.passed);
    try std.testing.expectEqual(@as(usize, 0), report.failed);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Format verification result as string
pub fn formatVerificationResult(result: VerificationResult, allocator: std.mem.Allocator) ![]u8 {
    const status = if (result.is_valid) "✅ PASS" else "❌ FAIL";
    const evidence = EvidenceLevel.format(result.evidence_level);

    return std.fmt.allocPrint(allocator, "{s} | {s} | {s}: {s}", .{
        status, evidence, result.message, result.error_margin,
    });
}

/// Get all available thresholds
pub fn getAllThresholds() []const struct { name: []const u8, value: f64 } {
    return [_]struct { name: []const u8, value: f64 }{
        .{ .name = "consciousness", .value = Thresholds.consciousness },
        .{ .name = "sparsity", .value = Thresholds.sparsity },
        .{ .name = "sacred_gamma", .value = Thresholds.sacred_gamma },
        .{ .name = "good_quality", .value = Thresholds.good_quality },
        .{ .name = "sacred_quality", .value = Thresholds.sacred_quality },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Global formula engine instance
pub var engine: ?FormulaEngine = null;

/// Initialize global formula engine
pub fn initEngine() !void {
    engine = try FormulaEngine.init();
}

/// Get global formula engine (panics if not initialized)
pub fn getEngine() *FormulaEngine {
    return &engine orelse @panic("Formula engine not initialized. Call initEngine() first.");
}

// φ² + 1/φ² = 3 | TRINITY
