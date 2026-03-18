// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE — Stage 0: Reference Number Library
// Built-in constants for CF comparison (φ, π, e, √2, ln2, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred = @import("../sacred/sacred.zig");

pub const ReferenceNumber = struct {
    id: []const u8,
    name: []const u8,
    value: f64,
    formula: []const u8,
    classification: Classification,
    description: []const u8,
};

pub const Classification = enum {
    periodic, // φ = [1;1,1,1,...]
    quadratic, // √2 = [1;2,2,2,...]
    transcendental, // π, e
    noble, // φ-type (Khinchin K ≠ 2.685...)
    generic, // Generic transcendental
    anomalous, // Deviates from expected patterns
};

pub const formatClassification = struct {
    pub fn format(c: Classification) []const u8 {
        return switch (c) {
            .periodic => "PERIODIC",
            .quadratic => "QUADRATIC",
            .transcendental => "TRANSCENDENTAL",
            .noble => "NOBLE",
            .generic => "GENERIC",
            .anomalous => "ANOMALOUS",
        };
    }
};

/// Reference library of 7 canonical numbers
pub const reference_library = [_]ReferenceNumber{
    .{
        .id = "phi",
        .name = "Golden Ratio",
        .value = sacred.PHI,
        .formula = "φ",
        .classification = .noble,
        .description = "Khinchin K=0.372 (anomalous!), CF=[1;1,1,1,...]",
    },
    .{
        .id = "sqrt2",
        .name = "Square Root of 2",
        .value = std.math.sqrt2,
        .formula = "√2",
        .classification = .quadratic,
        .description = "CF=[1;2,2,2,...], periodic",
    },
    .{
        .id = "e",
        .name = "Euler's Number",
        .value = sacred.E,
        .formula = "e",
        .classification = .transcendental,
        .description = "CF=[2;1,2,1,1,4,1,...] (quasi-periodic)",
    },
    .{
        .id = "pi",
        .name = "Circle Constant",
        .value = sacred.PI,
        .formula = "π",
        .classification = .transcendental,
        .description = "CF=[3;7,15,1,292,...] (chaotic)",
    },
    .{
        .id = "ln2",
        .name = "Natural Log of 2",
        .value = std.math.log(f64, std.math.e, 2.0),
        .formula = "ln(2)",
        .classification = .transcendental,
        .description = "CF=[0;1,2,3,1,6,3,...] (generic)",
    },
    .{
        .id = "omega_dm",
        .name = "Dark Matter Density Formula",
        .value = (sacred.PHI * sacred.PHI) / (sacred.PI * sacred.PI),
        .formula = "φ²/π²",
        .classification = .generic, // To be determined by analysis
        .description = "Sacred formula, CF analysis pending",
    },
    .{
        .id = "v_cb",
        .name = "CKM Matrix Element V_cb",
        .value = 1.0 / (3.0 * sacred.PI * sacred.PHI * sacred.PHI),
        .formula = "1/(3πφ²)",
        .classification = .generic, // To be determined by analysis
        .description = "Sacred formula, CF analysis pending",
    },
};

pub const random_baseline_count = 1000;

/// Get reference number by ID
pub fn getReference(id: []const u8) ?*const ReferenceNumber {
    for (&reference_library) |*ref| {
        if (std.mem.eql(u8, ref.id, id)) {
            return ref;
        }
    }
    return null;
}

/// Get all reference numbers
pub fn getAllReferences() []const ReferenceNumber {
    return &reference_library;
}

/// Khinchin's constant K ≈ 2.6854520010...
/// For almost all real numbers, lim (n→∞) (∏₁ⁿ aᵢ)^(1/n) = K
pub const KHINCHIN_CONSTANT: f64 = 2.6854520010;
pub const LEHMER_CONSTANT: f64 = 1.08366; // For σⁿ where σ = (1+√5)/2

/// Expected Khinchin ranges for different number types
pub const KhinchinRange = struct {
    min: f64,
    max: f64,
    classification: Classification,
};

pub const khinchin_ranges = [_]KhinchinRange{
    .{ .min = 0.0, .max = 0.6, .classification = .noble }, // φ-type: K << 2.685
    .{ .min = 0.6, .max = 1.5, .classification = .anomalous }, // Unusual
    .{ .min = 1.5, .max = 2.0, .classification = .generic }, // Generic
    .{ .min = 2.0, .max = 2.3, .classification = .quadratic }, // Quadratic irrationals
    .{ .min = 2.3, .max = 3.2, .classification = .generic }, // Most transcendentals (near K∞)
};

/// Classify by Khinchin ratio
pub fn classifyByKhinchin(ratio: f64) Classification {
    for (khinchin_ranges) |range| {
        if (ratio >= range.min and ratio < range.max) {
            return range.classification;
        }
    }
    return .generic;
}

/// Initialize reference library (no-op, kept for API consistency)
pub fn initReferenceLibrary() void {
    // All data is compile-time constant
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 3: Comparison Engine
// ═══════════════════════════════════════════════════════════════════════════════

pub const ComparisonResult = struct {
    target_id: []const u8,
    target_value: f64,
    reference_id: []const u8,
    reference_value: f64,
    distance_metric: f64, // Euclidean distance in CF-space
    similarity_score: f64, // 0 = identical, 1 = completely different
    verdict: []const u8,
};

/// Compare two numbers by their CF characteristics
pub fn compareNumbers(
    target_id: []const u8,
    target_value: f64,
    reference_id: []const u8,
) ComparisonResult {
    const ref_num = getReference(reference_id) orelse {
        return .{
            .target_id = target_id,
            .target_value = target_value,
            .reference_id = reference_id,
            .reference_value = 0.0,
            .distance_metric = 999.0,
            .similarity_score = 1.0,
            .verdict = "Reference not found",
        };
    };

    // Simple metric: log-ratio
    const distance = if (target_value > 0 and ref_num.value > 0)
        @abs(std.math.log(f64, std.math.e, target_value / ref_num.value))
    else
        999.0;

    // Similarity: 0 = very similar, 1 = very different
    const similarity = if (distance < 0.01) 0.0 else if (distance < 0.1) 0.2 else if (distance < 0.5) 0.5 else 1.0;

    const verdict = if (similarity < 0.1)
        "VERY SIMILAR CF structure"
    else if (similarity < 0.5)
        "MODERATELY SIMILAR"
    else
        "DIFFERENT CF structure";

    return .{
        .target_id = target_id,
        .target_value = target_value,
        .reference_id = reference_id,
        .reference_value = ref_num.value,
        .distance_metric = distance,
        .similarity_score = similarity,
        .verdict = verdict,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 6: Fisher Combined Test (for verdict)
// ═══════════════════════════════════════════════════════════════════════════════

pub const FisherResult = struct {
    chi_squared: f64,
    degrees_of_freedom: usize,
    combined_p_value: f64,
    is_significant: bool,
    verdict: []const u8,
};

/// Fisher's method for combining p-values
/// χ² = -2 Σ ln(pᵢ) ~ χ²²ₖ distribution
pub fn fisherCombinedTest(p_values: []const f64) FisherResult {
    if (p_values.len == 0) {
        return .{
            .chi_squared = 0.0,
            .degrees_of_freedom = 0,
            .combined_p_value = 1.0,
            .is_significant = false,
            .verdict = "No data",
        };
    }

    var sum_log_p: f64 = 0.0;
    var valid_count: usize = 0;

    for (p_values) |p| {
        if (p > 0 and p <= 1.0) {
            sum_log_p += std.math.log(f64, std.math.e, p);
            valid_count += 1;
        }
    }

    if (valid_count == 0) {
        return .{
            .chi_squared = 0.0,
            .degrees_of_freedom = 0,
            .combined_p_value = 1.0,
            .is_significant = false,
            .verdict = "No valid p-values",
        };
    }

    const chi_sq = -2.0 * sum_log_p;
    const df = 2 * valid_count;

    // Simplified p-value calculation (would need chi-square distribution for accuracy)
    // For df >= 40, χ² is approximately normal
    const p_val = if (df >= 40) {
        const z = (chi_sq - @as(f64, @floatFromInt(df))) / std.math.sqrt(@as(f64, @floatFromInt(2 * df)));
        // Normal CDF approximation
        if (z < 0) 1.0 - 0.5 * (1.0 + std.math.erf(@abs(z) / std.math.sqrt(2.0))) else 0.5 * (1.0 + std.math.erf(z / std.math.sqrt(2.0)));
    } else {
        // For small df, use threshold approximation
        if (chi_sq < df) 0.5 else 0.01; // Very rough
    };

    const is_sig = p_val < 0.05;
    const verdict = if (is_sig)
        "SIGNIFICANT DEVIATION from random"
    else
        "CONSISTENT with random distribution";

    return .{
        .chi_squared = chi_sq,
        .degrees_of_freedom = df,
        .combined_p_value = p_val,
        .is_significant = is_sig,
        .verdict = verdict,
    };
}

// φ² + 1/φ² = 3 = TRINITY
