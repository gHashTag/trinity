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
    exact,              // Mathematical identity (provable from axioms)
    validated,          // Confirmed by experimental data
    lattice_consistent, // Theoretically consistent
    candidate,          // Plausible hypothesis
    speculative,        // Exploratory idea
    rejected,           // Falsified or disproven

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
    canonical,           // Established, accepted value
    active_hypothesis,  // Currently being tested
    deprecated,         // Superseded but kept for reference
    superseded,         // Replaced by newer version
    retracted,          // Withdrawn by authors

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
    source: []const u8,           // "PDG2024", "arXiv:2603.00001", etc.
    version: []const u8,         // "2024", "v1.0", etc.
    doi: ?[]const u8,            // DOI if available
    url: ?[]const u8,             // URL if available
    authors: []const []const u8,  // Author list (const-correct for literals)
    date_added: i64,             // Unix timestamp when added to registry

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
    references: []const []const u8,          // ["PDG2024", "arXiv:2603.00001"]
    falsification_trigger: ?[]const u8, // "Error > 1%"
    provenance: Provenance,

    // Proof graph links
    depends_on_defs: []const []const u8,     // ["def.phi", "def.gamma"]
    depends_on_lemmas: []const []const u8,   // ["lem.scale_relation"]

    pub fn compute(self: *const SacredFormula) f64 {
        const phi: f64 = 1.6180339887498948482;
        const pi: f64 = 3.14159265358979323846;
        const e: f64 = 2.71828182845904523536;
        const gamma: f64 = std.math.pow(f64, phi, -3.0);
        const C: f64 = phi * gamma;
        const G: f64 = gamma / phi;

        return self.params.n *
            std.math.pow(f64, 3.0, self.params.k) *
            std.math.pow(f64, pi, self.params.m) *
            std.math.pow(f64, phi, self.params.p) *
            std.math.pow(f64, e, self.params.q) *
            std.math.pow(f64, gamma, self.params.r) *
            std.math.pow(f64, C, self.params.t) *
            std.math.pow(f64, G, self.params.u);
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
            var formula = SacredFormula{
                .id = const_data.id,
                .name = const_data.name,
                .domain = .particle,
                .params = .{
                    .n = @floatFromInt(const_data.params.n),
                    .k = @floatFromInt(const_data.params.k),
                    .m = @floatFromInt(const_data.params.m),
                    .p = @floatFromInt(const_data.params.p),
                    .q = @floatFromInt(const_data.params.q),
                    .r = 0.0,
                    .t = 0.0,
                    .u = 0.0,
                },
                .evidence_level = EvidenceLevel.fromClaimVerdict(const_data.evidence_level),
                .claim_status = .canonical,
                .target_value = const_data.target_value,
                .computed_value = const_data.computed_value,
                .error_pct = const_data.error_pct,
                .references = &.{"PDG2024"},
                .falsification_trigger = null,
                .provenance = Provenance{
                    .source = "PDG2024",
                    .version = "2024",
                    .doi = null,
                    .url = null,
                    .authors = &.{"Particle Data Group"},
                    .date_added = std.time.timestamp(),
                },
                .depends_on_defs = &.{"def.phi"},
                .depends_on_lemmas = &.{},
            };

            // Compute actual value
            formula.computed_value = formula.compute();

            try self.add(formula);
        }
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
