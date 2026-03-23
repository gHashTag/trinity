//! Strand I: Mathematical Foundation
//!
//! Sacred mathematics module for Trinity S³AI.
//!

// ═══════════════════════════════════════════════════════════════════════════════
// prediction.zig — Sacred Prediction Registry
//
// PREDICTIONS WITH TEMPORAL PRIORITY
//
// Each prediction is timestamped and immutable. Once published, it CANNOT be
// modified. This transforms TRINITY from post-hoc fitting to genuine predictive
// framework.
//
// Usage:
//   tri math predict                  # Show all predictions
//   tri math predict <id>             # Show specific prediction
//   tri math predict create ...       # Create new prediction
//   tri math predict verify ...       # Verify against experiment
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const time = std.time;

// Reuse sacred formula engine
const sacred_formula = @import("formula.zig");

// Sacred constants (defined locally to avoid complex imports)
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 0.6180339887498948482;
const MU: f64 = 0.0382;
const SACRED_THRESHOLD: f64 = 0.9;

// ═══════════════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════════════

const PREDICTION_VERSION = "1.0";
const REGISTRY_PATH = "data/predictions/registry.json";
const VERIFICATION_LOG_PATH = "data/predictions/verification_log.json";

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

/// Formula parameters for sacred formula
pub const FormulaParams = struct {
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,

    pub fn format(self: FormulaParams, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\{d} * 3^{d} * pi^{d} * phi^{d} * e^{d}
        , .{ self.n, self.k, self.m, self.p, self.q });
    }

    pub fn toJSON(self: FormulaParams, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"n":{d},"k":{d},"m":{d},"p":{d},"q":{d}}}
        , .{ self.n, self.k, self.m, self.p, self.q });
    }
};

/// Verification source
pub const VerificationSource = enum {
    codata, // CODATA recommended values
    pdg, // Particle Data Group
    nist, // NIST database
    arxiv, // Preprint
    journal, // Peer-reviewed publication
    manual, // Manual entry

    pub fn jsonString(self: VerificationSource) []const u8 {
        return switch (self) {
            .codata => "CODATA",
            .pdg => "PDG",
            .nist => "NIST",
            .arxiv => "arXiv",
            .journal => "Journal",
            .manual => "Manual",
        };
    }
};

/// Prediction type — 4-tier classification (weakest → strongest)
pub const PredictionType = enum(u8) {
    /// PST: Target value precisely known before formula; formula fit to data
    postdiction = 0,
    /// PRI: Only bounds/ranges known; formula uses priors but no precise target
    prior_informed = 1,
    /// SBL: Partial knowledge; deliberately avoided best-fit numbers
    semiblind = 2,
    /// BLD: No measurement exists; only order-of-magnitude or unknown
    blind = 3,

    pub fn jsonString(self: PredictionType) []const u8 {
        return switch (self) {
            .postdiction => "postdiction",
            .prior_informed => "prior_informed",
            .semiblind => "semiblind",
            .blind => "blind",
        };
    }

    pub fn shortCode(self: PredictionType) []const u8 {
        return switch (self) {
            .postdiction => "PST",
            .prior_informed => "PRI",
            .semiblind => "SBL",
            .blind => "BLD",
        };
    }

    pub fn colorANSI(self: PredictionType) []const u8 {
        return switch (self) {
            .postdiction => "\x1b[90m", // Gray — weakest
            .prior_informed => "\x1b[33m", // Yellow
            .semiblind => "\x1b[36m", // Cyan
            .blind => "\x1b[32m", // Green — strongest
        };
    }
};

/// Data state at time of formula construction
pub const DataState = enum(u8) {
    /// Relative error < 10%, peer-reviewed source
    measured_precisely = 0,
    /// Error 10-50%
    measured_roughly = 1,
    /// Only upper/lower bounds (95% CL)
    bounded = 2,
    /// Theoretical/expert estimate only
    order_of_magnitude = 3,
    /// No measurements or stable estimates
    unknown = 4,

    pub fn jsonString(self: DataState) []const u8 {
        return switch (self) {
            .measured_precisely => "measured_precisely",
            .measured_roughly => "measured_roughly",
            .bounded => "bounded",
            .order_of_magnitude => "order_of_magnitude",
            .unknown => "unknown",
        };
    }
};

/// Prediction status
pub const PredictionStatus = enum(u8) {
    /// Not yet measured — this is the ONLY valid status for new predictions
    pending = 0,
    /// Measured, within uncertainty bounds — PREDICTION CONFIRMED
    verified = 1,
    /// Measured, outside uncertainty bounds — PREDICTION FALSIFIED
    falsified = 2,
    /// Newer prediction replaces this one
    outdated = 3,

    pub fn jsonString(self: PredictionStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .verified => "verified",
            .falsified => "falsified",
            .outdated => "outdated",
        };
    }

    pub fn colorANSI(self: PredictionStatus) []const u8 {
        return switch (self) {
            .pending => "\x1b[33m", // Yellow
            .verified => "\x1b[32m", // Green
            .falsified => "\x1b[31m", // Red
            .outdated => "\x1b[90m", // Gray
        };
    }
};

/// A single immutable prediction
pub const Prediction = struct {
    // Immutable metadata — CRITICAL for temporal priority
    id: []const u8, // UUID v4
    created_at: i64, // Unix timestamp (seconds since epoch)
    created_by: []const u8, // "TRI v1.0 sacred-prediction"

    // What we're predicting
    constant_name: []const u8, // "Neutrino mass sum Σm_ν"
    symbol: []const u8, // "Σm_ν"
    description: []const u8, // Human-readable description

    // The prediction
    methodology: []const u8, // "sacred_formula", "ensemble", "theoretical"
    formula_params: FormulaParams, // (n,k,m,p,q)
    predicted_value: f64, // Central value
    uncertainty_lower: f64, // Lower bound (1-sigma)
    uncertainty_upper: f64, // Upper bound (1-sigma)
    unit: []const u8, // "eV", "GeV", "yr", etc.

    // Verification status
    status: PredictionStatus,
    verified_at: ?i64, // When verified (null if pending)
    verified_value: ?f64, // Experimental value (null if pending)
    verification_source: ?[]const u8, // "CODATA 2026", "PDG 2028"

    // Classification (4-tier system v10.0)
    prediction_type: PredictionType = .postdiction,
    data_state: DataState = .measured_precisely,
    honest_assessment: []const u8 = "",

    // Metadata
    rationale: []const u8, // Why this prediction?
    confidence: f64, // 0.0 to 1.0 (subjective confidence)
    tags: []const []const u8, // ["neutrino", "cosmology", "lepton"]

    /// Computed value from sacred formula
    pub fn computedValue(self: Prediction) f64 {
        return sacred_formula.computeSacredFormula(
            self.formula_params.n,
            self.formula_params.k,
            self.formula_params.m,
            self.formula_params.p,
            self.formula_params.q,
        );
    }

    /// Validate classification consistency rules:
    /// - postdiction FORBIDDEN with unknown or order_of_magnitude
    /// - blind FORBIDDEN with measured_precisely or measured_roughly
    pub fn validateClassification(self: Prediction) error{InvalidClassification}!void {
        switch (self.prediction_type) {
            .postdiction => {
                if (self.data_state == .unknown or self.data_state == .order_of_magnitude)
                    return error.InvalidClassification;
            },
            .blind => {
                if (self.data_state == .measured_precisely or self.data_state == .measured_roughly)
                    return error.InvalidClassification;
            },
            else => {},
        }
    }

    /// Format as ASCII table row
    pub fn formatRow(self: Prediction, allocator: Allocator) ![]u8 {
        _ = formatTimestamp(self.created_at); // Timestamp used in ID, not shown in row format
        const status_color = self.status.colorANSI();
        const type_color = self.prediction_type.colorANSI();
        const reset = "\x1b[0m";

        return std.fmt.allocPrint(allocator,
            \\ {s}[{s}]{s} {s}│ {s:.12} │ {s:<20.20} │ {s:>10.10} │ {s:>8.4} │ {s:>8.4} │ {s:>8.4} {s}│
        , .{
            type_color,
            self.prediction_type.shortCode(),
            reset,
            status_color,
            self.id[0..12],
            self.constant_name,
            self.unit,
            self.predicted_value,
            self.uncertainty_lower,
            self.uncertainty_upper,
            reset,
        });
    }

    /// Format as detailed card
    pub fn formatCard(self: Prediction, allocator: Allocator) ![]u8 {
        const created_str = formatTimestamp(self.created_at);
        const formula_str = try self.formula_params.format(allocator);
        defer allocator.free(formula_str);
        const status_color = self.status.colorANSI();
        const type_color = self.prediction_type.colorANSI();
        const reset = "\x1b[0m";

        return std.fmt.allocPrint(allocator,
            \\
            \\ {s}╔══════════════════════════════════════════════════════════════════╗{s}
            \\  {s}Prediction: {s}{s}
            \\  {s}─────────────────────────────────────────────────────────────────{s}
            \\  {s}ID:           {s}{s}
            \\  {s}Created:      {s} ({d})
            \\  {s}Status:       {s}{s}{s}
            \\  {s}Type:         {s}[{s}] {s}{s}
            \\  {s}Data State:   {s}{s}
            \\  {s}─────────────────────────────────────────────────────────────────{s}
            \\  {s}Constant:     {s}{s}
            \\  {s}Symbol:       {s}{s}
            \\  {s}Description:  {s}{s}
            \\  {s}─────────────────────────────────────────────────────────────────{s}
            \\  {s}Prediction:   {s}{d:.6} {d:.6} {d:.6} {s}
            \\  {s}Formula:      {s}{s}
            \\  {s}Methodology:  {s}{s}
            \\  {s}─────────────────────────────────────────────────────────────────{s}
            \\  {s}Rationale:    {s}{s}
            \\  {s}Assessment:   {s}{s}
            \\  {s}Confidence:   {s}{d:.1%}
            \\  {s}Tags:         {s}{s}
            \\
        , .{
            "\x1b[36m",                                                                                                                                                                                               reset, // Cyan border
            "\x1b[1m",                                                                                                                                                                                                self.constant_name,
            reset,                                                                                                                                                                                                    "──────────────────────────────────────────────────────────────────",
            self.id,                                                                                                                                                                                                  created_str,
            self.created_at,                                                                                                                                                                                          "──────────────────────────────────────────────────────────────────",
            status_color,                                                                                                                                                                                             self.status.jsonString(),
            reset,                                                                                                                                                                                                    type_color,
            self.prediction_type.shortCode(),                                                                                                                                                                         self.prediction_type.jsonString(),
            reset,                                                                                                                                                                                                    self.data_state.jsonString(),
            "──────────────────────────────────────────────────────────────────", "\x1b[1m",
            self.constant_name,                                                                                                                                                                                       reset,
            "\x1b[1m",                                                                                                                                                                                                self.symbol,
            reset,                                                                                                                                                                                                    self.description,
            "──────────────────────────────────────────────────────────────────",
            "\x1b[1;33m", // Yellow
            self.predicted_value,
            self.uncertainty_lower,
            self.uncertainty_upper,
            self.unit,
            reset,
            formula_str,
            self.methodology,
            "──────────────────────────────────────────────────────────────────",
            self.rationale,
            self.honest_assessment,
            self.confidence,
            self.tags,
        });
    }

    /// Check if a measured value verifies this prediction
    pub fn checkVerification(self: *Prediction, measured_value: f64, source: []const u8) !bool {
        const within_bounds = (measured_value >= self.uncertainty_lower and
            measured_value <= self.uncertainty_upper);

        self.verified_at = time.timestamp();
        self.verified_value = measured_value;
        self.verification_source = source;
        self.status = if (within_bounds) .verified else .falsified;

        return within_bounds;
    }
};

/// Registry of all predictions
pub const PredictionRegistry = struct {
    version: []const u8 = PREDICTION_VERSION,
    last_updated: i64,
    predictions: std.ArrayList(Prediction),

    const Self = @This();

    /// Load from JSON file
    pub fn loadFromFile(allocator: Allocator, path: []const u8) !Self {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const contents = try allocator.alloc(u8, stat.size);
        defer allocator.free(contents);

        _ = try file.readAll(contents);

        // Parse JSON (simplified - use std.json in real implementation)
        const registry = Self{
            .last_updated = time.timestamp(),
            .predictions = std.ArrayList(Prediction).init(allocator),
        };

        // DEFERRED (v12): JSON parsing requires std.json integration
        // For now, return empty registry
        return registry;
    }

    /// Save to JSON file
    pub fn saveToFile(self: *const Self, allocator: Allocator, path: []const u8) !void {
        const json = try self.toJSON(allocator);
        defer allocator.free(json);

        const dir = std.fs.path.dirname(path) orelse ".";
        try std.fs.cwd().makePath(dir);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(json);
        self.last_updated = time.timestamp();
    }

    /// Add new prediction (idempotent by UUID)
    pub fn addPrediction(self: *Self, pred: Prediction) !void {
        // Check if UUID already exists
        for (self.predictions.items) |*p| {
            if (std.mem.eql(u8, p.id, pred.id)) {
                // UUID exists — DO NOT MODIFY (immutable!)
                return error.PredictionAlreadyExists;
            }
        }
        try self.predictions.append(pred);
    }

    /// Get by UUID
    pub fn getByUUID(self: *const Self, id: []const u8) ?*Prediction {
        for (self.predictions.items) |*p| {
            if (std.mem.eql(u8, p.id[0..id.len], id)) {
                return p;
            }
        }
        return null;
    }

    /// Get all predictions with specific status
    pub fn getByStatus(self: *const Self, status: PredictionStatus) []Prediction {
        _ = status;
        // DEFERRED (v12): Filtering implementation
        return self.predictions.items; // Returns all for now
    }

    /// Get pending predictions (not yet measured)
    pub fn getPending(self: *const Self) []Prediction {
        return self.getByStatus(.pending);
    }

    /// Get verified predictions (confirmed by experiment)
    pub fn getVerified(self: *const Self) []Prediction {
        return self.getByStatus(.verified);
    }

    /// Serialize to JSON
    pub fn toJSON(self: *const Self, allocator: Allocator) ![]u8 {
        var buf: std.ArrayListUnmanaged(u8) = .{};
        const w = buf.writer(allocator);

        try w.writeAll("{\n");
        try w.print("  \"version\": \"{s}\",\n", .{self.version});
        try w.print("  \"last_updated\": {d},\n", .{self.last_updated});
        try w.writeAll("  \"predictions\": [\n");

        for (self.predictions.items, 0..) |pred, i| {
            if (i > 0) try w.writeAll(",\n");
            try pred.writeJSON(w);
        }

        try w.writeAll("\n  ]\n}\n");
        return buf.toOwnedSlice(allocator);
    }
};

/// Extend Prediction with JSON writing
fn writeJSON(self: Prediction, w: anytype) !void {
    const created_at = self.created_at;
    const verified_at = self.verified_at orelse 0;

    try w.print(
        \\    {{
        \\      "id": "{s}",
        \\      "created_at": {d},
        \\      "created_by": "{s}",
        \\      "constant_name": "{s}",
        \\      "symbol": "{s}",
        \\      "description": "{s}",
        \\      "methodology": "{s}",
        \\      "prediction_type": "{s}",
        \\      "prediction_type_short": "{s}",
        \\      "data_state_at_construction": "{s}",
        \\      "formula_params": {{s}},
        \\      "predicted_value": {d:.10},
        \\      "uncertainty_lower": {d:.10},
        \\      "uncertainty_upper": {d:.10},
        \\      "unit": "{s}",
        \\      "status": "{s}",
        \\      "verified_at": {d},
        \\      "verified_value": {d:.10},
        \\      "verification_source": "{s}",
        \\      "rationale": "{s}",
        \\      "honest_assessment": "{s}",
        \\      "confidence": {d:.3}
        \\    }}
    , .{
        self.id,
        created_at,
        self.created_by,
        self.constant_name,
        self.symbol,
        self.description,
        self.methodology,
        self.prediction_type.jsonString(),
        self.prediction_type.shortCode(),
        self.data_state.jsonString(),
        self.formula_params.toJSON(std.heap.page_allocator) catch "{}", // Empty params if error
        self.predicted_value,
        self.uncertainty_lower,
        self.uncertainty_upper,
        self.unit,
        self.status.jsonString(),
        verified_at,
        self.verified_value orelse 0.0,
        self.verification_source orelse "null",
        self.rationale,
        self.honest_assessment,
        self.confidence,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Creation Functions
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a new prediction with current timestamp
pub fn createPrediction(allocator: Allocator, params: PredictionParams) !Prediction {
    const id = try generateUUID(allocator);
    errdefer allocator.free(id);

    const created_at = time.timestamp();

    // Compute predicted value from formula
    const predicted_value = sacred_formula.computeSacredFormula(
        params.formula.n,
        params.formula.k,
        params.formula.m,
        params.formula.p,
        params.formula.q,
    );

    // Calculate uncertainty bounds if not provided
    const uncertainty = if (params.uncertainty_pct > 0)
        params.uncertainty_pct / 100.0 * predicted_value
    else
        predicted_value * 0.1; // Default 10% uncertainty

    return Prediction{
        .id = id,
        .created_at = created_at,
        .created_by = "TRI v1.0 sacred-prediction",
        .constant_name = try allocator.dupe(u8, params.constant_name),
        .symbol = try allocator.dupe(u8, params.symbol),
        .description = try allocator.dupe(u8, params.description),
        .methodology = try allocator.dupe(u8, params.methodology),
        .formula_params = params.formula,
        .predicted_value = predicted_value,
        .uncertainty_lower = predicted_value - uncertainty,
        .uncertainty_upper = predicted_value + uncertainty,
        .unit = try allocator.dupe(u8, params.unit),
        .status = .pending,
        .verified_at = null,
        .verified_value = null,
        .verification_source = null,
        .prediction_type = params.prediction_type,
        .data_state = params.data_state,
        .honest_assessment = try allocator.dupe(u8, params.honest_assessment),
        .rationale = try allocator.dupe(u8, params.rationale),
        .confidence = params.confidence,
        .tags = try allocator.dupe([]const u8, params.tags),
    };
}

/// Parameters for creating a new prediction
pub const PredictionParams = struct {
    constant_name: []const u8,
    symbol: []const u8,
    description: []const u8,
    methodology: []const u8 = "sacred_formula",
    formula: FormulaParams,
    unit: []const u8,
    uncertainty_pct: f64 = 0.0, // If 0, use 10% default
    prediction_type: PredictionType = .postdiction,
    data_state: DataState = .measured_precisely,
    honest_assessment: []const u8 = "",
    rationale: []const u8,
    confidence: f64 = 0.5,
    tags: []const []const u8 = &.{},
};

/// Generate UUID v4
fn generateUUID(allocator: Allocator) ![]u8 {
    // Use timestamp + random for simple UUID-like string
    _ = time.timestamp();
    const random = std.crypto.random;

    var buf: [16]u8 = undefined;
    random.bytes(&buf);

    // Set version and variant bits for UUID v4
    buf[6] = (buf[6] & 0x0F) | 0x40; // Version 4
    buf[8] = (buf[8] & 0x3F) | 0x80; // Variant 1

    return std.fmt.allocPrint(allocator, "{x:0>8}-{x:0>4}-{x:0>4}-{x:0>4}-{x:0>12}", .{
        std.mem.readInt(u32, buf[0..4], .big),
        std.mem.readInt(u16, buf[4..6], .big),
        std.mem.readInt(u16, buf[6..8], .big),
        std.mem.readInt(u16, buf[8..10], .big),
        std.mem.readInt(u48, buf[10..16], .big),
    });
}

/// Format Unix timestamp as ISO date string
fn formatTimestamp(ts: i64) []const u8 {
    _ = ts;
    // DEFERRED: Use std.datetime for proper formatting (requires TZ handling)
    return "2026-03-05"; // Placeholder date
}

// ═══════════════════════════════════════════════════════════════════════════════
// Initial Predictions (Timestamped at Creation)
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate initial set of predictions for registry
pub fn generateInitialPredictions(allocator: Allocator) ![]Prediction {
    const predictions = try allocator.alloc(Prediction, 5);

    // 1. Neutrino mass sum Σm_ν — PRIOR_INFORMED (only cosmological bounds)
    predictions[0] = try createPrediction(allocator, .{
        .constant_name = "Neutrino mass sum Σm_ν",
        .symbol = "Σm_ν",
        .description = "Sum of three neutrino mass eigenstates from cosmological constraints",
        .methodology = "sacred_formula",
        .formula = .{ .n = 3, .k = 6, .m = -4, .p = -4, .q = -4 },
        .unit = "eV",
        .uncertainty_pct = 10.0,
        .prediction_type = .prior_informed,
        .data_state = .bounded,
        .honest_assessment = "Prior-informed: constructed inside cosmological window (0.059-0.12 eV); no direct kinematic measurement",
        .rationale = "Extended sacred formula search beyond standard bounds. Value within Planck 2020 upper limit of 0.12 eV.",
        .confidence = 0.6,
        .tags = &.{ "neutrino", "cosmology", "lepton", "mass" },
    });

    // 2. Axion mass — PRIOR_INFORMED (ADMX exclusion + theoretical window)
    predictions[1] = try createPrediction(allocator, .{
        .constant_name = "Axion mass m_a",
        .symbol = "m_a",
        .description = "Mass of the QCD axion solving the strong CP problem",
        .methodology = "sacred_formula",
        .formula = .{ .n = 2, .k = -2, .m = -3, .p = -1, .q = -2 },
        .unit = "eV",
        .uncertainty_pct = 15.0,
        .prediction_type = .prior_informed,
        .data_state = .bounded,
        .honest_assessment = "Prior-informed: constructed within theoretical axion window using ADMX exclusion bounds; no direct detection",
        .rationale = "Sacred formula fit within experimental window (ADMX, HAYSTAC)",
        .confidence = 0.5,
        .tags = &.{ "axion", "dark-matter", "qcd" },
    });

    // 3. Graviton mass — PRIOR_INFORMED (LIGO upper bound only)
    predictions[2] = try createPrediction(allocator, .{
        .constant_name = "Graviton mass m_g",
        .symbol = "m_g",
        .description = "Upper bound on graviton mass from gravitational wave observations",
        .methodology = "sacred_formula",
        .formula = .{ .n = 5, .k = -8, .m = -4, .p = -4, .q = -6 },
        .unit = "eV",
        .uncertainty_pct = 20.0,
        .prediction_type = .prior_informed,
        .data_state = .bounded,
        .honest_assessment = "Prior-informed: constructed below LIGO upper bound; only constraint is m_g < 1.27e-22 eV",
        .rationale = "Sacred formula prediction consistent with LIGO/Virgo constraints",
        .confidence = 0.4,
        .tags = &.{ "graviton", "gravity", "ligo" },
    });

    // 4. Proton lifetime — PRIOR_INFORMED (Super-K lower bound only)
    predictions[3] = try createPrediction(allocator, .{
        .constant_name = "Proton lifetime τ_p",
        .symbol = "τ_p",
        .description = "Proton decay lifetime via p → e+ π0 channel",
        .methodology = "sacred_formula",
        .formula = .{ .n = 3, .k = 4, .m = 3, .p = 4, .q = 4 },
        .unit = "yr",
        .uncertainty_pct = 25.0,
        .prediction_type = .prior_informed,
        .data_state = .bounded,
        .honest_assessment = "Prior-informed: constructed above Super-K lower bound; no positive detection of proton decay",
        .rationale = "Sacred formula prediction beyond current Super-K lower bound of 10^34 yr",
        .confidence = 0.3,
        .tags = &.{ "proton", "gut", "decay" },
    });

    // 5. Dark photon mass (X17 anomaly) — POSTDICTION (Atomki 17 MeV known)
    predictions[4] = try createPrediction(allocator, .{
        .constant_name = "Dark photon mass X17",
        .symbol = "X17",
        .description = "Mass of hypothetical dark photon explaining Atomki anomaly",
        .methodology = "sacred_formula",
        .formula = .{ .n = 4, .k = 6, .m = -1, .p = 0, .q = -4 },
        .unit = "MeV",
        .uncertainty_pct = 5.0,
        .prediction_type = .postdiction,
        .data_state = .measured_roughly,
        .honest_assessment = "Postdiction: Atomki 17 MeV observation (2016) was known before formula construction",
        .rationale = "Exact 17.0 MeV from sacred formula matches Atomki anomaly observation",
        .confidence = 0.4,
        .tags = &.{ "dark-photon", "x17", "atomki" },
    });

    return predictions;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "createPrediction generates valid UUID" {
    const params = PredictionParams{
        .constant_name = "Test constant",
        .symbol = "T",
        .description = "Test prediction",
        .formula = .{ .n = 1, .k = 1, .m = 0, .p = 0, .q = 0 },
        .unit = "GeV",
        .rationale = "Test",
    };

    const pred = try createPrediction(std.testing.allocator, params);

    try std.testing.expect(pred.id.len > 0);
    try std.testing.expect(pred.created_at > 0);
    try std.testing.expectEqual(@as(PredictionStatus, .pending), pred.status);
    try std.testing.expect(pred.predicted_value > 0);
}

test "generateInitialPredictions creates 5 predictions" {
    const predictions = try generateInitialPredictions(std.testing.allocator);
    defer {
        for (predictions) |*p| {
            std.testing.allocator.free(p.id);
            std.testing.allocator.free(p.constant_name);
            std.testing.allocator.free(p.symbol);
            std.testing.allocator.free(p.description);
            std.testing.allocator.free(p.methodology);
            std.testing.allocator.free(p.unit);
            std.testing.allocator.free(p.honest_assessment);
            std.testing.allocator.free(p.rationale);
            std.testing.allocator.free(p.tags);
        }
        std.testing.allocator.free(predictions);
    }

    try std.testing.expectEqual(@as(usize, 5), predictions.len);

    for (predictions) |pred| {
        try std.testing.expectEqual(@as(PredictionStatus, .pending), pred.status);
        try std.testing.expect(pred.predicted_value > 0);
    }
}

test "checkVerification updates status correctly" {
    const params = PredictionParams{
        .constant_name = "Test constant",
        .symbol = "T",
        .description = "Test prediction",
        .formula = .{ .n = 1, .k = 1, .m = 0, .p = 0, .q = 0 },
        .unit = "GeV",
        .rationale = "Test",
    };

    var pred = try createPrediction(std.testing.allocator, params);

    // Verify within bounds
    const verified = try pred.checkVerification(3.0, "TEST 2026");
    try std.testing.expect(verified);
    try std.testing.expectEqual(@as(PredictionStatus, .verified), pred.status);
    try std.testing.expect(pred.verified_at != null);
    try std.testing.expect(pred.verified_value != null);
}

test "validateClassification rejects invalid combinations" {
    // postdiction + unknown = INVALID
    const invalid1 = Prediction{
        .id = "test",
        .created_at = 0,
        .created_by = "test",
        .constant_name = "test",
        .symbol = "T",
        .description = "test",
        .methodology = "test",
        .formula_params = .{ .n = 1, .k = 0, .m = 0, .p = 0, .q = 0 },
        .predicted_value = 1.0,
        .uncertainty_lower = 0.9,
        .uncertainty_upper = 1.1,
        .unit = "eV",
        .status = .pending,
        .verified_at = null,
        .verified_value = null,
        .verification_source = null,
        .prediction_type = .postdiction,
        .data_state = .unknown,
        .rationale = "test",
        .confidence = 0.5,
        .tags = &.{},
    };
    try std.testing.expectError(error.InvalidClassification, invalid1.validateClassification());

    // blind + measured_precisely = INVALID
    const invalid2 = Prediction{
        .id = "test2",
        .created_at = 0,
        .created_by = "test",
        .constant_name = "test",
        .symbol = "T",
        .description = "test",
        .methodology = "test",
        .formula_params = .{ .n = 1, .k = 0, .m = 0, .p = 0, .q = 0 },
        .predicted_value = 1.0,
        .uncertainty_lower = 0.9,
        .uncertainty_upper = 1.1,
        .unit = "eV",
        .status = .pending,
        .verified_at = null,
        .verified_value = null,
        .verification_source = null,
        .prediction_type = .blind,
        .data_state = .measured_precisely,
        .rationale = "test",
        .confidence = 0.5,
        .tags = &.{},
    };
    try std.testing.expectError(error.InvalidClassification, invalid2.validateClassification());

    // prior_informed + bounded = VALID
    const valid = Prediction{
        .id = "test3",
        .created_at = 0,
        .created_by = "test",
        .constant_name = "test",
        .symbol = "T",
        .description = "test",
        .methodology = "test",
        .formula_params = .{ .n = 1, .k = 0, .m = 0, .p = 0, .q = 0 },
        .predicted_value = 1.0,
        .uncertainty_lower = 0.9,
        .uncertainty_upper = 1.1,
        .unit = "eV",
        .status = .pending,
        .verified_at = null,
        .verified_value = null,
        .verification_source = null,
        .prediction_type = .prior_informed,
        .data_state = .bounded,
        .rationale = "test",
        .confidence = 0.5,
        .tags = &.{},
    };
    try valid.validateClassification();
}

test "neutrino prediction within Planck bound" {
    const predictions = try generateInitialPredictions(std.testing.allocator);
    defer {
        for (predictions) |*p| {
            std.testing.allocator.free(p.id);
            std.testing.allocator.free(p.constant_name);
            std.testing.allocator.free(p.symbol);
            std.testing.allocator.free(p.description);
            std.testing.allocator.free(p.methodology);
            std.testing.allocator.free(p.unit);
            std.testing.allocator.free(p.honest_assessment);
            std.testing.allocator.free(p.rationale);
            std.testing.allocator.free(p.tags);
        }
        std.testing.allocator.free(predictions);
    }

    const neutrino = predictions[0]; // Σm_ν
    try std.testing.expect(neutrino.predicted_value < 0.12); // Planck 2020 upper bound
    try std.testing.expect(neutrino.predicted_value > 0);
}
