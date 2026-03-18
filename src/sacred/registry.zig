// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA REGISTRY — Centralized formula storage with metadata
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const proof_types = @import("proof_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// EVIDENCE LEVEL — Scientific evidence status
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvidenceLevel = enum {
    exact, // Mathematical identity (provable from axioms)
    validated, // Confirmed by experimental data
    lattice_consistent, // Theoretically consistent
    candidate, // Plausible hypothesis
    speculative, // Exploratory idea
    rejected, // Falsified or disproven

    pub fn format(level: EvidenceLevel) []const u8 {
        return switch (level) {
            .exact => "EXACT",
            .validated => "VALIDATED",
            .lattice_consistent => "LATTICE_CONSISTENT",
            .candidate => "CANDIDATE",
            .speculative => "SPECULATIVE",
            .rejected => "REJECTED",
        };
    }

    pub fn colorCode(level: EvidenceLevel) []const u8 {
        return switch (level) {
            .exact => "\x1b[32m", // Green
            .validated => "\x1b[36m", // Cyan
            .lattice_consistent => "\x1b[34m", // Blue
            .candidate => "\x1b[33m", // Yellow
            .speculative => "\x1b[35m", // Magenta
            .rejected => "\x1b[31m", // Red
        };
    }

    pub fn fromClaimVerdict(verdict: proof_types.ClaimVerdict) EvidenceLevel {
        return switch (verdict) {
            .exact => .exact,
            .validated => .validated,
            .lattice_consistent => .lattice_consistent,
            .candidate => .candidate,
            .speculative => .speculative,
            .formula_mismatch => .candidate, // Mismatch treated as candidate (needs revision)
            .rejected => .rejected,
        };
    }

    pub fn toClaimVerdict(level: EvidenceLevel) proof_types.ClaimVerdict {
        return switch (level) {
            .exact => .exact,
            .validated => .validated,
            .lattice_consistent => .lattice_consistent,
            .candidate => .candidate,
            .speculative => .speculative,
            .rejected => .rejected,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLAIM STATUS — Publication status of formula
// ═══════════════════════════════════════════════════════════════════════════════

pub const ClaimStatus = enum {
    canonical, // Established, accepted value
    active_hypothesis, // Currently being tested
    deprecated, // Superseded but kept for reference
    superseded, // Replaced by newer version
    retracted, // Withdrawn by authors

    pub fn format(status: ClaimStatus) []const u8 {
        return switch (status) {
            .canonical => "CANONICAL",
            .active_hypothesis => "ACTIVE_HYPOTHESIS",
            .deprecated => "DEPRECATED",
            .superseded => "SUPERSEDED",
            .retracted => "RETRACTED",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROVENANCE — Source tracking for formulas
// ═══════════════════════════════════════════════════════════════════════════════

pub const Provenance = struct {
    source: []const u8, // "PDG2024", "arXiv:2603.00001", etc.
    version: []const u8, // "2024", "v1.0", etc.
    doi: ?[]const u8, // DOI if available
    url: ?[]const u8, // URL if available
    authors: []const []const u8, // Author list (const-correct for literals)
    date_added: i64, // Unix timestamp when added to registry

    pub fn init(_: std.mem.Allocator) Provenance {
        return .{
            .source = "unknown",
            .version = "1.0",
            .doi = null,
            .url = null,
            .authors = &.{},
            .date_added = std.time.timestamp(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA — Complete formula record with metadata
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredFormula = struct {
    id: []const u8,
    name: []const u8,
    domain: proof_types.Domain,

    // Formula parameters: V = n × 3^k × π^m × φ^p × e^q × γ^r × C^t × G^u
    params: struct {
        n: f64 = 1.0,
        k: f64 = 0.0,
        m: f64 = 0.0,
        p: f64 = 0.0,
        q: f64 = 0.0,
        r: f64 = 0.0,
        t: f64 = 0.0,
        u: f64 = 0.0,
    },

    // Evidence and status
    evidence_level: EvidenceLevel,
    claim_status: ClaimStatus,

    // Reference value (for experimental comparison)
    target_value: ?f64,
    computed_value: f64,
    error_pct: f64,

    // Metadata
    references: []const []const u8, // ["PDG2024", "arXiv:2603.00001"]
    falsification_trigger: ?[]const u8, // "Error > 1%"
    provenance: Provenance,

    // Epistemic tracking (I16-I17)
    declared_expression: ?[]const u8 = null, // Text formula from papers/narrative
    fit_origin: ?proof_types.FitOrigin = null, // canonical | search_fit | postdiction

    // Proof graph links
    depends_on_defs: []const []const u8, // ["def.phi", "def.gamma"]
    depends_on_lemmas: []const []const u8, // ["lem.scale_relation"]

    pub fn compute(self: *const SacredFormula) f64 {
        const phi: f64 = 1.6180339887498948482;
        const pi: f64 = 3.14159265358979323846;
        const e: f64 = 2.71828182845904523536;
        const gamma: f64 = std.math.pow(f64, phi, -3.0);
        const C: f64 = phi * gamma;
        const G: f64 = gamma / phi;

        // Core factors (n, 3^k, π^m, φ^p, e^q)
        const n_factor = self.params.n;
        const _3k = std.math.pow(f64, 3.0, self.params.k);
        const pi_m = std.math.pow(f64, pi, self.params.m);
        const phi_p = std.math.pow(f64, phi, self.params.p);
        const e_q = std.math.pow(f64, e, self.params.q);

        // Extended factors (γ^r, C^t, G^u)
        const gamma_r = std.math.pow(f64, gamma, self.params.r);
        const C_t = std.math.pow(f64, C, self.params.t);
        const G_u = std.math.pow(f64, G, self.params.u);

        // Log intermediate values for debugging γ-dependent formulas
        if (self.params.r != 0 or self.params.t != 0 or self.params.u != 0) {
            std.debug.print("\n[COMPUTE DEBUG] {s} (n={d},k={d},m={d},p={d},q={d},r={d},t={d},u={d})\n", .{
                self.id,       self.params.n, self.params.k, self.params.m,
                self.params.p, self.params.q, self.params.r, self.params.t,
                self.params.u,
            });
            std.debug.print("  Constants: phi={d:.6}, pi={d:.6}, e={d:.6}\n", .{ phi, pi, e });
            std.debug.print("  Extended: gamma={d:.6}, C={d:.6}, G={d:.6}\n", .{ gamma, C, G });
            std.debug.print("  Core factors: n={d:.6}, 3^k={d:.6}, pi^m={d:.6}, phi^p={d:.6}, e^q={d:.6}\n", .{
                n_factor, _3k, pi_m, phi_p, e_q,
            });
            std.debug.print("  Extended factors: gamma^r={d:.6}, C^t={d:.6}, G^u={d:.6}\n", .{
                gamma_r, C_t, G_u,
            });
            const core_product = n_factor * _3k * pi_m * phi_p * e_q;
            const extended_product = gamma_r * C_t * G_u;
            std.debug.print("  Partial products: core={d:.6}, extended={d:.6}\n", .{
                core_product, extended_product,
            });
        }

        return n_factor * _3k * pi_m * phi_p * e_q * gamma_r * C_t * G_u;
    }

    pub fn formatExpression(self: *const SacredFormula, allocator: std.mem.Allocator) ![]const u8 {
        // Constants available for future use in expression formatting
        _ = f64; // Type marker for unused constants below
        const _phi: f64 = 1.6180339887498948482;
        const _pi: f64 = 3.14159265358979323846;
        const _e: f64 = 2.71828182845904523536;
        _ = _phi;
        _ = _pi;
        _ = _e;

        var parts = std.ArrayList([]const u8){};

        // Always show n
        if (self.params.n != 1.0) {
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "{d:.0}", .{self.params.n}));
        }

        // Show 3^k if k != 0
        if (self.params.k != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "3^{d:.0}", .{self.params.k}));
        }

        // Show π^m if m != 0
        if (self.params.m != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "π^{d:.0}", .{self.params.m}));
        }

        // Show φ^p if p != 0
        if (self.params.p != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "φ^{d:.0}", .{self.params.p}));
        }

        // Show e^q if q != 0
        if (self.params.q != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "e^{d:.0}", .{self.params.q}));
        }

        // Show γ^r if r != 0
        if (self.params.r != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "γ^{d:.0}", .{self.params.r}));
        }

        // Show C^t if t != 0
        if (self.params.t != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "C^{d:.0}", .{self.params.t}));
        }

        // Show G^u if u != 0
        if (self.params.u != 0.0) {
            if (parts.items.len > 0) try parts.append(allocator, " × ");
            try parts.append(allocator, try std.fmt.allocPrint(allocator, "G^{d:.0}", .{self.params.u}));
        }

        if (parts.items.len == 0) {
            try parts.append(allocator, "1");
        }

        return std.mem.join(allocator, "", parts.items);
    }

    pub fn getVerdict(self: *const SacredFormula) proof_types.ClaimVerdict {
        return self.evidence_level.toClaimVerdict();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRY — Centralized formula storage
// ═══════════════════════════════════════════════════════════════════════════════

pub const Registry = struct {
    allocator: std.mem.Allocator,
    formulas: std.StringHashMap(SacredFormula),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .allocator = allocator,
            .formulas = std.StringHashMap(SacredFormula).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        var iter = self.formulas.iterator();
        while (iter.next()) |entry| {
            // Formula strings are owned by the registry or should be managed externally
            // For now, we don't free them as they may be static
            _ = entry.value_ptr.*;
        }
        self.formulas.deinit();
    }

    pub fn get(self: *Registry, id: []const u8) ?*SacredFormula {
        return self.formulas.getPtr(id);
    }

    pub fn add(self: *Registry, formula: SacredFormula) !void {
        try self.formulas.put(formula.id, formula);
    }

    pub fn remove(self: *Registry, id: []const u8) bool {
        return self.formulas.remove(id);
    }

    pub fn count(self: *const Registry) usize {
        return self.formulas.count();
    }

    pub fn listByEvidenceLevel(self: *const Registry, level: EvidenceLevel) ![]const []const u8 {
        const ids = try self.allocator.alloc([]const u8, self.formulas.count());
        var result_count: usize = 0;

        var iter = self.formulas.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.evidence_level == level) {
                ids[result_count] = entry.key_ptr.*;
                result_count += 1;
            }
        }

        return ids[0..result_count];
    }

    pub fn listByDomain(self: *const Registry, domain: proof_types.Domain) ![]const []const u8 {
        const ids = try self.allocator.alloc([]const u8, self.formulas.count());
        var result_count: usize = 0;

        var iter = self.formulas.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.domain == domain) {
                ids[result_count] = entry.key_ptr.*;
                result_count += 1;
            }
        }

        return ids[0..result_count];
    }

    /// Load initial particle physics data into registry
    pub fn loadParticlePhysicsData(self: *Registry) !void {
        inline for (proof_types.particle_physics_constants) |const_data| {
            // Determine domain from formula ID (Charter Rule 5: Domain-specific tags)
            const domain = if (std.mem.startsWith(u8, const_data.id, "qcd_"))
                proof_types.Domain.qcd
            else if (std.mem.startsWith(u8, const_data.id, "omega_") or
                std.mem.startsWith(u8, const_data.id, "zc_") or
                std.mem.startsWith(u8, const_data.id, "w_z_"))
                proof_types.Domain.cosmology
            else
                proof_types.Domain.particle;

            // Determine dependencies based on extended parameters
            // Charter Rule 3: Gamma is not axiom — formulas using γ (r>0) depend on def.gamma
            const uses_gamma = const_data.params.r != 0;

            // Determine dependencies (max 2: def.phi + def.gamma)
            const deps_slice = if (uses_gamma)
                &[_][]const u8{ "def.phi", "def.gamma" }
            else
                &[_][]const u8{"def.phi"};

            // Determine reference based on evidence level
            const references = if (const_data.evidence_level == .validated)
                &[_][]const u8{"PDG2024"}
            else if (const_data.evidence_level == .speculative)
                &[_][]const u8{"Pre-registered prediction"}
            else
                &[_][]const u8{};

            var formula = SacredFormula{
                .id = const_data.id,
                .name = const_data.name,
                .domain = domain,
                .params = .{
                    .n = @floatFromInt(const_data.params.n),
                    .k = @floatFromInt(const_data.params.k),
                    .m = @floatFromInt(const_data.params.m),
                    .p = @floatFromInt(const_data.params.p),
                    .q = @floatFromInt(const_data.params.q),
                    .r = @floatFromInt(const_data.params.r),
                    .t = @floatFromInt(const_data.params.t),
                    .u = @floatFromInt(const_data.params.u),
                },
                .evidence_level = EvidenceLevel.fromClaimVerdict(const_data.evidence_level),
                .claim_status = if (const_data.evidence_level == .validated)
                    ClaimStatus.canonical
                else if (const_data.evidence_level == .candidate)
                    ClaimStatus.active_hypothesis
                else
                    ClaimStatus.active_hypothesis,

                // Epistemic tracking (I16-I17)
                .declared_expression = const_data.declared_expression,
                .fit_origin = if (const_data.fit_origin) |origin|
                    @as(proof_types.FitOrigin, origin)
                else
                    null,

                .target_value = const_data.target_value,
                .computed_value = const_data.computed_value,
                .error_pct = const_data.error_pct,
                .references = references,
                .falsification_trigger = if (const_data.evidence_level == .speculative)
                    "Lack of experimental confirmation within 5 years"
                else
                    null,
                .provenance = Provenance{
                    .source = if (const_data.evidence_level == .validated) "PDG2024" else "TRINITY",
                    .version = "2024",
                    .doi = null,
                    .url = null,
                    .authors = if (const_data.evidence_level == .validated)
                        &[_][]const u8{"Particle Data Group"}
                    else
                        &[_][]const u8{},
                    .date_added = std.time.timestamp(),
                },
                .depends_on_defs = deps_slice,
                .depends_on_lemmas = &.{},
            };

            // Compute actual value
            formula.computed_value = formula.compute();

            try self.add(formula);
        }
    }

    /// Load all formulas into registry (particle physics + baryogenesis)
    pub fn loadAllFormulas(self: *Registry) !void {
        try self.loadParticlePhysicsData();
        try self.loadBaryogenesisData();
    }

    /// Load baryogenesis formulas (141-160) into registry
    pub fn loadBaryogenesisData(self: *Registry) !void {
        inline for (proof_types.baryogenesis_formulas) |const_data| {
            // Baryogenesis formulas use nuclear domain
            const domain = proof_types.Domain.nuclear;

            // Determine dependencies based on extended parameters
            const uses_gamma = const_data.params.r != 0;

            // Determine dependencies
            const deps_slice = if (uses_gamma)
                &[_][]const u8{ "def.phi", "def.gamma" }
            else
                &[_][]const u8{"def.phi"};

            // Determine reference based on evidence level
            const references = if (const_data.evidence_level == .validated)
                &[_][]const u8{ "Planck 2018", "BBN observations" }
            else if (const_data.evidence_level == .candidate)
                &[_][]const u8{"Pre-registered prediction"}
            else
                &[_][]const u8{};

            var formula = SacredFormula{
                .id = const_data.id,
                .name = const_data.name,
                .domain = domain,
                .params = .{
                    .n = @floatFromInt(const_data.params.n),
                    .k = @floatFromInt(const_data.params.k),
                    .m = @floatFromInt(const_data.params.m),
                    .p = @floatFromInt(const_data.params.p),
                    .q = @floatFromInt(const_data.params.q),
                    .r = @floatFromInt(const_data.params.r),
                    .t = @floatFromInt(const_data.params.t),
                    .u = @floatFromInt(const_data.params.u),
                },
                .evidence_level = EvidenceLevel.fromClaimVerdict(const_data.evidence_level),
                .claim_status = if (const_data.evidence_level == .validated)
                    ClaimStatus.canonical
                else if (const_data.evidence_level == .candidate)
                    ClaimStatus.active_hypothesis
                else
                    ClaimStatus.active_hypothesis,

                // Epistemic tracking (I16-I17)
                .declared_expression = const_data.declared_expression,
                .fit_origin = if (const_data.fit_origin) |origin|
                    @as(proof_types.FitOrigin, origin)
                else
                    null,

                .target_value = const_data.target_value,
                .computed_value = const_data.computed_value,
                .error_pct = const_data.error_pct,
                .references = references,
                .falsification_trigger = if (const_data.evidence_level == .speculative)
                    "Lack of experimental confirmation within 5 years"
                else
                    null,
                .provenance = Provenance{
                    .source = if (const_data.evidence_level == .validated) "Planck 2018" else "TRINITY",
                    .version = "2024",
                    .doi = null,
                    .url = null,
                    .authors = if (const_data.evidence_level == .validated)
                        &[_][]const u8{"TRINITY Collaboration"}
                    else
                        &[_][]const u8{},
                    .date_added = std.time.timestamp(),
                },
                .depends_on_defs = deps_slice,
                .depends_on_lemmas = &.{},
            };

            // Compute actual value
            formula.computed_value = formula.compute();

            try self.add(formula);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // GAMMA DEPENDENCY TRACKING — Research Cycle Section 1
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Get γ-dependency info for a specific formula
    pub fn getGammaDependency(self: *const Registry, formula_id: []const u8) ?proof_types.GammaDependency {
        const formula = self.get(formula_id) orelse return null;
        const gamma_power: i64 = @intFromFloat(formula.params.r);
        const indirect_gamma = formula.params.t != 0 or formula.params.u != 0;

        return proof_types.GammaDependency{
            .formula_id = formula.id,
            .gamma_power = gamma_power,
            .indirect_gamma = indirect_gamma,
            .domain = formula.domain,
        };
    }

    /// Calculate domain-level γ metrics
    pub fn getGammaDomainMetrics(self: *const Registry, domain: proof_types.Domain) !proof_types.GammaDomainMetrics {
        var total: usize = 0;
        var gamma_dependent: usize = 0;
        var gamma_exposure_sum: f64 = 0.0;

        var iter = self.formulas.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.domain == domain) {
                total += 1;
                const gamma_power: i64 = @intFromFloat(entry.value_ptr.params.r);
                const indirect_gamma = entry.value_ptr.params.t != 0 or entry.value_ptr.params.u != 0;

                if (gamma_power != 0 or indirect_gamma) {
                    gamma_dependent += 1;
                    const direct_weight: f64 = if (gamma_power != 0) 1.0 else 0.0;
                    const indirect_weight: f64 = if (indirect_gamma) 0.5 else 0.0;
                    gamma_exposure_sum += direct_weight + indirect_weight;
                }
            }
        }

        return proof_types.GammaDomainMetrics{
            .domain = domain,
            .total_formulas = total,
            .gamma_dependent = gamma_dependent,
            .gamma_exposure_sum = gamma_exposure_sum,
        };
    }

    /// List all γ-dependent formulas in a domain
    pub fn listGammaDependent(self: *const Registry, domain: proof_types.Domain) ![]const []const u8 {
        const ids = try self.allocator.alloc([]const u8, self.formulas.count());
        var result_count: usize = 0;

        var iter = self.formulas.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.domain == domain) {
                const gamma_power: i64 = @intFromFloat(entry.value_ptr.params.r);
                const indirect_gamma = entry.value_ptr.params.t != 0 or entry.value_ptr.params.u != 0;

                if (gamma_power != 0 or indirect_gamma) {
                    ids[result_count] = entry.key_ptr.*;
                    result_count += 1;
                }
            }
        }

        return ids[0..result_count];
    }

    /// Check if formula is eligible for EXACT verdict (Charter Rule 3)
    pub fn eligibleForExact(self: *const Registry, formula_id: []const u8) bool {
        const dep = self.getGammaDependency(formula_id) orelse return false;
        return dep.eligibleForExact();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRE-COMPUTED CONSTANTS — Fast access to common values
// ═══════════════════════════════════════════════════════════════════════════════

pub const PrecomputedConstant = struct {
    id: []const u8,
    value: f64,
    domain: proof_types.Domain,
    evidence_level: EvidenceLevel,
};

pub fn getPrecomputedConstants(allocator: std.mem.Allocator) ![]PrecomputedConstant {
    // Common sacred constants
    const constants = [_]PrecomputedConstant{
        .{ .id = "phi", .value = 1.6180339887498948482, .domain = .core, .evidence_level = .exact },
        .{ .id = "pi", .value = 3.14159265358979323846, .domain = .core, .evidence_level = .exact },
        .{ .id = "e", .value = 2.71828182845904523536, .domain = .core, .evidence_level = .exact },
        .{ .id = "trinity", .value = 3.0, .domain = .core, .evidence_level = .exact },
        .{ .id = "gamma", .value = 0.23606797749978969641, .domain = .core, .evidence_level = .candidate },
        .{ .id = "alpha_inv", .value = 137.036, .domain = .particle, .evidence_level = .validated },
        .{ .id = "alpha_s", .value = 0.1185, .domain = .qcd, .evidence_level = .validated },
    };

    const result = try allocator.alloc(PrecomputedConstant, constants.len);
    @memcpy(result, &constants);
    return result;
}
