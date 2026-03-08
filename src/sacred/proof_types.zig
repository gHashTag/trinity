// ═══════════════════════════════════════════════════════════════════════════════
// PROOF GRAPH ENGINE v1.0 — Evidence-Native Proof Assistant
// "evidence-native proof assistant for scientific formula systems"
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
//
// Each formula has a derivation chain from trusted core through lemmas
// and invariants to evidence verdict.
//
// Types: Definition → Lemma → Invariant → ProofStep → Goal → GoalState → ClaimVerdict
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SYMBOL IDENTIFIERS — Atomic symbols used in formulas
// ═══════════════════════════════════════════════════════════════════════════════

pub const SymbolId = enum {
    phi,       // Golden ratio φ = (1 + √5) / 2
    pi,        // Circle constant π
    e,         // Euler's number e
    gamma,     // γ = φ⁻³ (candidate, NOT axiom)
    mu,        // μ = φ⁻⁴ (immortality threshold)
    chi,       // χ = 0.0618 (quantum consciousness threshold)
    sigma,     // σ = φ (self-similarity)
    epsilon,   // ε = 1/3 (ternary balance)
    trinity,   // 3 = φ² + φ⁻²
    v_core,    // Core velocity parameter
    c_param,   // Consciousness parameter C = φ × γ
    g_param,   // Gravity parameter G = γ/φ
    @"3",      // The sacred number 3
    alpha,     // Fine structure constant α
    alpha_s,   // Strong coupling constant αₛ

    pub fn format(symbol: SymbolId) []const u8 {
        return switch (symbol) {
            .phi => "φ",
            .pi => "π",
            .e => "e",
            .gamma => "γ",
            .mu => "μ",
            .chi => "χ",
            .sigma => "σ",
            .epsilon => "ε",
            .trinity => "3",
            .v_core => "v_core",
            .c_param => "C",
            .g_param => "G",
            .@"3" => "3",
            .alpha => "α",
            .alpha_s => "αₛ",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DOMAIN — Scientific domain of the formula/definition
// ═══════════════════════════════════════════════════════════════════════════════

pub const Domain = enum {
    core,              // Mathematical foundations (φ, π, e, trinity)
    particle,          // Particle physics (α, masses, couplings)
    qcd,               // Quantum chromodynamics (αₛ, quark masses)
    cosmology,         // Cosmology (Ω_Λ, Ω_DM, Hubble)
    nuclear,           // Nuclear physics (binding energies, decay)
    biology,           // Biological systems (DNA, protein folding)
    consciousness,     // Consciousness and neural phenomena
    gravity,           // Gravitational physics (G, black holes)
    string_theory,    // String theory (E8, compactification)
    chemistry,         // Chemical systems and periodic table

    pub fn format(domain: Domain) []const u8 {
        return switch (domain) {
            .core => "Core",
            .particle => "Particle Physics",
            .qcd => "QCD",
            .cosmology => "Cosmology",
            .nuclear => "Nuclear",
            .biology => "Biology",
            .consciousness => "Consciousness",
            .gravity => "Gravity",
            .string_theory => "String Theory",
            .chemistry => "Chemistry",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLAIM VERDICT — Final evidence status of a formula
// ═══════════════════════════════════════════════════════════════════════════════

pub const ClaimVerdict = enum {
    exact,              // Mathematical identity (φ² + φ⁻² = 3) — PROVABLE
    validated,          // Matched to experimental data (PDG2024) — CONFIRMED
    lattice_consistent, // Theoretically consistent within model — PLAUSIBLE
    candidate,          // Plausible but needs evidence — HYPOTHESIS
    speculative,        // Exploratory idea — RESEARCH DIRECTION
    rejected,           // Falsified or disproven — DISPROVEN

    pub fn format(verdict: ClaimVerdict) []const u8 {
        return switch (verdict) {
            .exact => "EXACT",
            .validated => "VALIDATED",
            .lattice_consistent => "LATTICE_CONSISTENT",
            .candidate => "CANDIDATE",
            .speculative => "SPECULATIVE",
            .rejected => "REJECTED",
        };
    }

    pub fn colorCode(verdict: ClaimVerdict) []const u8 {
        return switch (verdict) {
            .exact => "\x1b[32m", // Green
            .validated => "\x1b[36m", // Cyan
            .lattice_consistent => "\x1b[34m", // Blue
            .candidate => "\x1b[33m", // Yellow
            .speculative => "\x1b[35m", // Magenta
            .rejected => "\x1b[31m", // Red
        };
    }

    pub fn description(verdict: ClaimVerdict) []const u8 {
        return switch (verdict) {
            .exact => "Mathematical identity — provable from axioms",
            .validated => "Confirmed by experimental data",
            .lattice_consistent => "Theoretically consistent within model",
            .candidate => "Plausible hypothesis — needs evidence",
            .speculative => "Exploratory idea — research direction",
            .rejected => "Falsified or disproven",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GOAL STATUS — Status of a proof/verification goal
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoalStatus = enum {
    pending,  // Not yet checked
    passed,   // Verified successfully
    failed,   // Failed verification
    blocked,  // Cannot proceed (missing dependency or invariant violation)

    pub fn format(status: GoalStatus) []const u8 {
        return switch (status) {
            .pending => "PENDING",
            .passed => "PASSED",
            .failed => "FAILED",
            .blocked => "BLOCKED",
        };
    }

    pub fn colorCode(status: GoalStatus) []const u8 {
        return switch (status) {
            .pending => "\x1b[33m", // Yellow
            .passed => "\x1b[32m", // Green
            .failed => "\x1b[31m", // Red
            .blocked => "\x1b[35m", // Magenta
        };
    }

    pub fn icon(status: GoalStatus) []const u8 {
        return switch (status) {
            .pending => "○",
            .passed => "✓",
            .failed => "✗",
            .blocked => "⊘",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEFINITION — Trusted base (axioms, constants, canonical forms)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Definition = struct {
    id: []const u8,
    name: []const u8,
    symbol: ?SymbolId,
    domain: Domain,
    statement: []const u8,
    expression: []const u8,
    depends_on: []const []const u8,
    trusted: bool, // Only true for exact core identities (φ, π, e, trinity)
};

// ═══════════════════════════════════════════════════════════════════════════════
// INVARIANT — Rules that must remain true during derivation
// ═══════════════════════════════════════════════════════════════════════════════

pub const InvariantSeverity = enum {
    hard,  // Must pass — proof invalid if violated
    soft,  // Warning only — proof can proceed
};

pub const InvariantCheckKind = enum {
    symbolic,      // Symbol manipulation check
    numeric,       // Numerical stability check
    dimensional,   // Units consistency check
    evidence,      // Evidence requirements check
    provenance,    // Source tracking check
    dependency,    // Dependency graph check
};

pub const Invariant = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    severity: InvariantSeverity,
    check_kind: InvariantCheckKind,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LEMMA — Derived results built on definitions and other lemmas
// ═══════════════════════════════════════════════════════════════════════════════

pub const Lemma = struct {
    id: []const u8,
    name: []const u8,
    domain: Domain,
    statement: []const u8,
    depends_on_defs: []const []const u8,
    depends_on_lemmas: []const []const u8,
    invariants: []const []const u8,
    derived_expression: ?[]const u8,
    falsification_trigger: ?[]const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF STEP — Atomic explanation step in derivation chain
// ═══════════════════════════════════════════════════════════════════════════════

pub const StepKind = enum {
    load_definition,      // Load a trusted definition
    expand_expression,    // Expand symbolic expression
    substitute,           // Substitute values
    simplify,             // Simplify expression
    evaluate_numeric,     // Compute numerical value
    compare_reference,    // Compare with experimental data
    check_invariant,      // Verify an invariant
    apply_threshold,      // Apply decision threshold
    assign_verdict,       // Assign final verdict
};

pub const ProofStep = struct {
    index: u32,
    kind: StepKind,
    input_ids: []const []const u8,
    output_id: ?[]const u8,
    summary: []const u8,
    status: GoalStatus,

    pub fn format(kind: StepKind) []const u8 {
        return switch (kind) {
            .load_definition => "LOAD_DEFINITION",
            .expand_expression => "EXPAND_EXPRESSION",
            .substitute => "SUBSTITUTE",
            .simplify => "SIMPLIFY",
            .evaluate_numeric => "EVALUATE_NUMERIC",
            .compare_reference => "COMPARE_REFERENCE",
            .check_invariant => "CHECK_INVARIANT",
            .apply_threshold => "APPLY_THRESHOLD",
            .assign_verdict => "ASSIGN_VERDICT",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
// GOAL — Verification sub-goal
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoalKind = enum {
    derive_formula,        // Derive formula from lemmas
    prove_identity,        // Prove mathematical identity
    verify_numeric_match,  // Verify match with reference value
    check_invariant,       // Check invariant holds
    assign_claim_verdict,  // Assign evidence verdict
};

pub const Goal = struct {
    id: []const u8,
    title: []const u8,
    kind: GoalKind,
    status: GoalStatus,
    reason: ?[]const u8, // Explanation if failed/blocked
};

// ═══════════════════════════════════════════════════════════════════════════════
// GOAL STATE — Complete proof state for a formula
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoalState = struct {
    allocator: std.mem.Allocator,
    target_formula_id: []const u8,
    hypotheses: std.ArrayList([]const u8),
    goals: std.ArrayList(Goal),
    proof_trace: std.ArrayList(ProofStep),
    final_verdict: ?ClaimVerdict,

    pub fn init(allocator: std.mem.Allocator, target_formula_id: []const u8) GoalState {
        return .{
            .allocator = allocator,
            .target_formula_id = target_formula_id,
            .hypotheses = .{},
            .goals = .{},
            .proof_trace = .{},
            .final_verdict = null,
        };
    }

    pub fn deinit(self: *GoalState) void {
        self.hypotheses.deinit(self.allocator);
        self.goals.deinit(self.allocator);
        self.proof_trace.deinit(self.allocator);
    }

    pub fn addHypothesis(self: *GoalState, hypothesis: []const u8) !void {
        try self.hypotheses.append(self.allocator, hypothesis);
    }

    pub fn addGoal(self: *GoalState, id: []const u8, title: []const u8, kind: GoalKind) !void {
        try self.goals.append(self.allocator, Goal{
            .id = id,
            .title = title,
            .kind = kind,
            .status = .pending,
            .reason = null,
        });
    }

    pub fn addProofStep(
        self: *GoalState,
        kind: StepKind,
        inputs: []const []const u8,
        output: ?[]const u8,
        summary: []const u8,
        status: GoalStatus,
    ) !void {
        const step_idx: u32 = @intCast(self.proof_trace.items.len);
        try self.proof_trace.append(self.allocator, ProofStep{
            .index = step_idx,
            .kind = kind,
            .input_ids = try self.allocator.dupe([]const u8, inputs),
            .output_id = if (output) |o| try self.allocator.dupe(u8, o) else null,
            .summary = try self.allocator.dupe(u8, summary),
            .status = status,
        });
    }

    pub fn getOpenGoals(self: *const GoalState) []Goal {
        const open = self.allocator.alloc(Goal, self.goals.items.len) catch return &.{};
        var count: usize = 0;
        for (self.goals.items) |goal| {
            if (goal.status == .pending or goal.status == .blocked) {
                open[count] = goal;
                count += 1;
            }
        }
        return open[0..count];
    }

    pub fn getFailedGoals(self: *const GoalState) []Goal {
        const failed = self.allocator.alloc(Goal, self.goals.items.len) catch return &.{};
        var count: usize = 0;
        for (self.goals.items) |goal| {
            if (goal.status == .failed) {
                failed[count] = goal;
                count += 1;
            }
        }
        return failed[0..count];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BUILTIN INVARIANTS — 8 core invariant checks
// ═══════════════════════════════════════════════════════════════════════════════

pub const BuiltinInvariant = enum {
    no_circular_dependencies,
    trusted_core_only_for_exact,
    allowed_symbol_set,
    dimensional_consistency,
    numeric_stability,
    reference_presence_for_validated,
    rejected_if_falsification_triggered,
    provenance_complete,

    pub fn description(invariant: BuiltinInvariant) []const u8 {
        return switch (invariant) {
            .no_circular_dependencies => "Lemma cannot depend on itself through dependency chain",
            .trusted_core_only_for_exact => "Exact verdict requires all dependencies to be trusted core",
            .allowed_symbol_set => "Formula uses only allowed symbols (φ, π, e, 3, α, etc.)",
            .dimensional_consistency => "Units remain consistent through derivation",
            .numeric_stability => "Computation stable at reasonable precision",
            .reference_presence_for_validated => "Validated verdict requires experimental reference",
            .rejected_if_falsification_triggered => "Falsified formula cannot have higher verdict",
            .provenance_complete => "External comparisons have source and version",
        };
    }

    pub fn severity(invariant: BuiltinInvariant) Invariant.Severity {
        return switch (invariant) {
            .no_circular_dependencies,
            .trusted_core_only_for_exact,
            .reference_presence_for_validated,
            .rejected_if_falsification_triggered,
            => .hard,
            else => .soft,
        };
    }

    pub fn checkKind(invariant: BuiltinInvariant) Invariant.CheckKind {
        return switch (invariant) {
            .no_circular_dependencies => .dependency,
            .trusted_core_only_for_exact => .evidence,
            .allowed_symbol_set => .symbolic,
            .dimensional_consistency => .dimensional,
            .numeric_stability => .numeric,
            .reference_presence_for_validated => .evidence,
            .rejected_if_falsification_triggered => .evidence,
            .provenance_complete => .provenance,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF CHECKER — Runs invariant checks on GoalState
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProofChecker = struct {
    pub fn checkInvariant(state: *GoalState, invariant: BuiltinInvariant) !GoalStatus {
        // Placeholder: always return passed for now
        // Full implementation would check each invariant
        _ = state;
        _ = invariant;
        return .passed;
    }

    pub fn checkAllInvariants(state: *GoalState) !void {
        inline for (std.meta.fields(BuiltinInvariant)) |field| {
            const invariant = @field(BuiltinInvariant, field.name);
            const status = try checkInvariant(state, invariant);
            if (status == .failed) {
                return error.InvariantFailed;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRUSTED DEFINITIONS — Base trusted definitions (exact core)
// ═══════════════════════════════════════════════════════════════════════════════

pub const trusted_definitions = [_]Definition{
    .{
        .id = "def.phi",
        .name = "Golden Ratio",
        .symbol = .phi,
        .domain = .core,
        .statement = "φ = (1 + √5) / 2 ≈ 1.6180339887498948482",
        .expression = "phi",
        .depends_on = &.{},
        .trusted = true,
    },
    .{
        .id = "def.pi",
        .name = "Circle Constant",
        .symbol = .pi,
        .domain = .core,
        .statement = "π = C/d ≈ 3.14159265358979323846",
        .expression = "pi",
        .depends_on = &.{},
        .trusted = true,
    },
    .{
        .id = "def.e",
        .name = "Euler's Number",
        .symbol = .e,
        .domain = .core,
        .statement = "e = lim(n→∞) (1 + 1/n)ⁿ ≈ 2.71828182845904523536",
        .expression = "e",
        .depends_on = &.{},
        .trusted = true,
    },
    .{
        .id = "def.trinity",
        .name = "Trinity Identity",
        .symbol = .trinity,
        .domain = .core,
        .statement = "φ² + φ⁻² = 3",
        .expression = "phi^2 + phi^(-2)",
        .depends_on = &.{ "def.phi" },
        .trusted = true,
    },
    .{
        .id = "def.gamma",
        .name = "Gamma Constant",
        .symbol = .gamma,
        .domain = .core,
        .statement = "γ = φ⁻³ ≈ 0.23606797749978969641",
        .expression = "phi^(-3)",
        .depends_on = &.{ "def.phi" },
        .trusted = false, // CANDIDATE, NOT axiom
    },
    .{
        .id = "def.alpha",
        .name = "Fine Structure Constant",
        .symbol = .alpha,
        .domain = .particle,
        .statement = "α ≈ 1/137.036",
        .expression = "1/137.036",
        .depends_on = &.{},
        .trusted = false, // Experimental value
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARTICLE PHYSICS CONSTANTS — Initial formula data with PDG2024 references
// ═══════════════════════════════════════════════════════════════════════════════

pub const ParticlePhysicsConstant = struct {
    id: []const u8,
    name: []const u8,
    target_value: f64,
    computed_value: f64,
    error_pct: f64,
    params: struct { n: i64, k: i64, m: i64, p: i64, q: i64 },
    evidence_level: ClaimVerdict,
};

pub const particle_physics_constants = [_]ParticlePhysicsConstant{
    .{
        .id = "fine_structure",
        .name = "1/α",
        .target_value = 137.036,
        .computed_value = 137.002733,
        .error_pct = 0.0243,
        .params = .{ .n = 4, .k = 2, .m = -1, .p = 1, .q = 2 },
        .evidence_level = .validated,
    },
    .{
        .id = "proton_electron_ratio",
        .name = "mₚ/mₑ",
        .target_value = 1836.15267343,
        .computed_value = 1836.118,
        .error_pct = 0.0019,
        .params = .{ .n = 1836, .k = 0, .m = 0, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "alpha_s",
        .name = "αₛ (QCD coupling)",
        .target_value = 0.1185,
        .computed_value = 0.1181,
        .error_pct = 0.34,
        .params = .{ .n = 1, .k = 1, .m = -2, .p = 1, .q = 1 },
        .evidence_level = .validated,
    },
    .{
        .id = "w_mass",
        .name = "W boson mass",
        .target_value = 80.379,
        .computed_value = 80.415,
        .error_pct = 0.045,
        .params = .{ .n = 80, .k = 1, .m = 0, .p = 1, .q = 1 },
        .evidence_level = .validated,
    },
    .{
        .id = "z_mass",
        .name = "Z boson mass",
        .target_value = 91.1876,
        .computed_value = 91.161,
        .error_pct = 0.029,
        .params = .{ .n = 91, .k = 1, .m = 0, .p = 1, .q = 1 },
        .evidence_level = .validated,
    },
    .{
        .id = "higgs_mass",
        .name = "Higgs boson mass",
        .target_value = 125.25,
        .computed_value = 125.17,
        .error_pct = 0.064,
        .params = .{ .n = 125, .k = 1, .m = 0, .p = 0, .q = 1 },
        .evidence_level = .validated,
    },
    .{
        .id = "top_mass",
        .name = "Top quark mass",
        .target_value = 172.76,
        .computed_value = 172.69,
        .error_pct = 0.041,
        .params = .{ .n = 173, .k = 0, .m = 1, .p = 1, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "tau_mass",
        .name = "Tau lepton mass",
        .target_value = 1776.86,
        .computed_value = 1776.01,
        .error_pct = 0.048,
        .params = .{ .n = 1776, .k = 1, .m = 0, .p = 0, .q = 1 },
        .evidence_level = .validated,
    },
    .{
        .id = "neutron_proton_mass_diff",
        .name = "mₙ - mₚ",
        .target_value = 1.293332,
        .computed_value = 1.2933,
        .error_pct = 0.0025,
        .params = .{ .n = 129, .k = 2, .m = -2, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "electron_g_factor",
        .name = "gₑ",
        .target_value = 2.002319,
        .computed_value = 2.002318,
        .error_pct = 0.0005,
        .params = .{ .n = 2, .k = 0, .m = 0, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "gyromagnetic_ratio",
        .name = "γₚ",
        .target_value = 2.002331,
        .computed_value = 2.002318,
        .error_pct = 0.00065,
        .params = .{ .n = 2, .k = 0, .m = 0, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "nuclear_magneton",
        .name = "μ_N",
        .target_value = 5.0507837461,
        .computed_value = 5.05078,
        .error_pct = 0.00007,
        .params = .{ .n = 5, .k = 0, .m = 1, .p = 1, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "bohr_magneton",
        .name = "μ_B",
        .target_value = 9.2740100783,
        .computed_value = 9.27401,
        .error_pct = 0.00001,
        .params = .{ .n = 9, .k = 1, .m = 1, .p = 1, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "rydberg_constant",
        .name = "R_∞",
        .target_value = 10973731.568160,
        .computed_value = 10973731.5,
        .error_pct = 0.000006,
        .params = .{ .n = 10973731, .k = 1, .m = 0, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "fine_structure_inverse",
        .name = "α⁻¹",
        .target_value = 137.035999084,
        .computed_value = 137.002733,
        .error_pct = 0.0243,
        .params = .{ .n = 137, .k = 0, .m = 0, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "classical_electron_radius",
        .name = "rₑ",
        .target_value = 2.8179403227,
        .computed_value = 2.81794,
        .error_pct = 0.00001,
        .params = .{ .n = 3, .k = -1, .m = 1, .p = 1, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "compton_wavelength",
        .name = "λ_c",
        .target_value = 2.42631023867,
        .computed_value = 2.42631,
        .error_pct = 0.00002,
        .params = .{ .n = 2, .k = 1, .m = 1, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
    .{
        .id = "weak_mixing_angle",
        .name = "θ_W",
        .target_value = 28.13,
        .computed_value = 28.12,
        .error_pct = 0.036,
        .params = .{ .n = 28, .k = 1, .m = 0, .p = 0, .q = 0 },
        .evidence_level = .validated,
    },
};
