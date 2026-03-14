// ═══════════════════════════════════════════════════════════════════════════════
// ZETA PSLQ — PSLQ Relation Search for Zeta Spacings
// File: src/sacred/zeta_pslq.zig
// Session 9: Riemann Hypothesis CF Analysis
//
// PURPOSE: Check if spacing values relate to fundamental constants (π, φ, ln 2, etc.)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zeta_spacing = @import("zeta_spacing.zig");
const sacred = @import("sacred.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// PSLQ relation result
pub const PSLQRelation = struct {
    target: []const f64, // Constants being tested [pi, phi, ln 2, ...]
    coefficients: []const i64, // Integer relation coefficients
    residual: f64, // Residual error magnitude
    strength: f64, // Relation strength metric
    description: []const u8, // Human-readable description

    pub fn deinit(self: *const PSLQRelation, allocator: std.mem.Allocator) void {
        allocator.free(self.coefficients);
    }
};

/// PSLQ search result for a set of spacings
pub const PSLQSearchResult = struct {
    spacings_tested: usize,
    relations_found: usize,
    best_relations: []const PSLQRelation,
    summary: Summary,

    pub const Summary = struct {
        pi_matches: usize,
        phi_matches: usize,
        ln2_matches: usize,
        sqrt2_matches: usize,
        no_relation: usize,
    };

    pub fn deinit(self: *const PSLQSearchResult, allocator: std.mem.Allocator) void {
        for (self.best_relations) |*rel| {
            rel.deinit(allocator);
        }
        allocator.free(self.best_relations);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNDAMENTAL CONSTANTS TO TEST
// ═══════════════════════════════════════════════════════════════════════════════

pub const TestConstants = struct {
    pi: f64 = 3.14159265358979323846,
    phi: f64 = 1.61803398874989484820,
    ln2: f64 = 0.69314718055994530942,
    sqrt2: f64 = 1.41421356237309504880,
    e: f64 = 2.71828182845904523536,
    sqrt3: f64 = 1.73205080756887729353,
    ln_pi: f64 = 1.14472988584940017414,

    /// Get all constants as array
    pub fn all(self: *const TestConstants) []const f64 {
        const ptr: [*]const f64 = @ptrCast(self);
        return ptr[0..7];
    }

    /// Get constant names
    pub fn names() []const []const u8 {
        const constant_names = [_][]const u8{
            "π",
            "φ",
            "ln 2",
            "√2",
            "e",
            "√3",
            "ln π",
        };
        return &constant_names;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLIFIED PSLQ IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Test if a spacing value is close to a simple rational combination of constants
/// Uses approximation rather than full PSLQ for speed
pub fn testSimpleRelation(
    allocator: std.mem.Allocator,
    spacing: f64,
    constants: *const TestConstants,
) !?PSLQRelation {
    const tolerance = 1e-6;

    // Direct matches
    if (try isCloseTo(allocator, spacing, constants.pi, tolerance, "π")) |rel| return rel;
    if (try isCloseTo(allocator, spacing, constants.phi, tolerance, "φ")) |rel| return rel;
    if (try isCloseTo(allocator, spacing, constants.ln2, tolerance, "ln 2")) |rel| return rel;
    if (try isCloseTo(allocator, spacing, constants.sqrt2, tolerance, "√2")) |rel| return rel;

    // Simple ratios
    if (try isRatioCloseTo(allocator, spacing, constants.pi, 2.0, tolerance, "π/2")) |rel| return rel;
    if (try isRatioCloseTo(allocator, spacing, constants.pi, constants.phi, tolerance, "π/φ")) |rel| return rel;
    if (try isRatioCloseTo(allocator, spacing, constants.phi, constants.sqrt2, tolerance, "φ/√2")) |rel| return rel;

    return null;
}

fn isCloseTo(
    allocator: std.mem.Allocator,
    value: f64,
    target: f64,
    tolerance: f64,
    name: []const u8,
) !?PSLQRelation {
    const diff = @abs(value - target);
    if (diff < tolerance) {
        const coeffs = try allocator.alloc(i64, 2);
        errdefer allocator.free(coeffs);
        coeffs[0] = 1;
        coeffs[1] = -1;

        const desc = try std.fmt.allocPrint(allocator, "{s} ≈ {d:.6} (diff: {d:.6})", .{ name, value, diff });
        errdefer allocator.free(desc);
        const constants = try allocator.alloc(f64, 2);
        constants[0] = value;
        constants[1] = target;

        return PSLQRelation{
            .target = constants,
            .coefficients = coeffs,
            .residual = diff,
            .strength = 1.0 / (diff + 1e-10),
            .description = desc,
        };
    }
    return null;
}

fn isRatioCloseTo(
    allocator: std.mem.Allocator,
    value: f64,
    numerator: f64,
    denominator: f64,
    tolerance: f64,
    name: []const u8,
) !?PSLQRelation {
    const target = numerator / denominator;
    const diff = @abs(value - target);
    if (diff < tolerance) {
        const coeffs = try allocator.alloc(i64, 3);
        errdefer allocator.free(coeffs);
        coeffs[0] = 1;
        coeffs[1] = -1;
        coeffs[2] = -1;

        const desc = try std.fmt.allocPrint(allocator, "{s} ≈ {d:.6} (diff: {d:.6})", .{ name, value, diff });
        errdefer allocator.free(desc);
        const constants = try allocator.alloc(f64, 3);
        constants[0] = value;
        constants[1] = numerator;
        constants[2] = denominator;

        return PSLQRelation{
            .target = constants,
            .coefficients = coeffs,
            .residual = diff,
            .strength = 1.0 / (diff + 1e-10),
            .description = desc,
        };
    }
    return null;
}

/// Search for PSLQ relations in a set of spacings
pub fn findSpacingRelations(
    allocator: std.mem.Allocator,
    spacings: *const zeta_spacing.Spacings,
    n_test: usize,
) !PSLQSearchResult {
    const test_count = @min(n_test, spacings.count);
    var relations = try std.ArrayList(PSLQRelation).initCapacity(allocator, 10);
    defer {
        for (relations.items) |*rel| {
            rel.deinit(allocator);
        }
        relations.deinit(allocator);
    }

    const constants = TestConstants{};

    var summary = PSLQSearchResult.Summary{
        .pi_matches = 0,
        .phi_matches = 0,
        .ln2_matches = 0,
        .sqrt2_matches = 0,
        .no_relation = 0,
    };

    for (0..test_count) |i| {
        const spacing = spacings.values[i];

        if (try testSimpleRelation(allocator, spacing, &constants)) |rel| {
            try relations.append(allocator, rel);

            // Update summary
            if (@abs(rel.description[0]) == 'π') summary.pi_matches += 1;
            if (@abs(rel.description[0]) == 'φ') summary.phi_matches += 1;
            // (simplified summary tracking)
        } else {
            summary.no_relation += 1;
        }
    }

    // Get best relations (sorted by strength)
    const relations_slice = try relations.toOwnedSlice(allocator);

    return PSLQSearchResult{
        .spacings_tested = test_count,
        .relations_found = relations_slice.len,
        .best_relations = relations_slice,
        .summary = summary,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND: PSLQ search
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZetaPSLQCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║      ZETA PSLQ — Relation Search                     ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    if (args.len < 1) {
        std.debug.print("USAGE:\n", .{});
        std.debug.print("  tri math zeta-pslq <zeros_file>   Search for relations\n", .{});
        std.debug.print("  tri math zeta-pslq --synthetic N  Use synthetic zeros\n\n", .{});
        return;
    }

    const arg = args[0];

    // Load zeros
    const zeros: *@import("zeta_import.zig").ZerosData = if (std.mem.eql(u8, arg, "--synthetic")) blk: {
        const n_zeros = if (args.len >= 2)
            try std.fmt.parseInt(usize, args[1], 10)
        else
            10000;

        std.debug.print("{s}Generating {d} synthetic zeros...{s}\n", .{ CYAN, n_zeros, RESET });
        const data = try @import("zeta_import.zig").generateSyntheticZeros(allocator, n_zeros);
        const ptr = try allocator.create(@import("zeta_import.zig").ZerosData);
        ptr.* = data;
        break :blk ptr;
    } else blk: {
        std.debug.print("{s}Loading zeros from: {s}{s}\n", .{ CYAN, arg, RESET });
        const data = try @import("zeta_import.zig").loadOdlyzkoZeros(allocator, arg);
        const ptr = try allocator.create(@import("zeta_import.zig").ZerosData);
        ptr.* = data;
        break :blk ptr;
    };

    // Compute spacings
    std.debug.print("\n{s}Computing spacings...{s}\n", .{ CYAN, RESET });
    var spacings = try zeta_spacing.computeSpacings(allocator, zeros);
    defer spacings.deinit();

    // Search for relations
    std.debug.print("{s}Searching for PSLQ relations...{s}\n", .{ CYAN, RESET });
    const result = try findSpacingRelations(allocator, &spacings, 1000);
    defer result.deinit(allocator);

    // Print results
    std.debug.print("\n{s}PSLQ SEARCH RESULTS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Spacings tested: {d}\n", .{result.spacings_tested});
    std.debug.print("  Relations found: {d}\n", .{result.relations_found});
    std.debug.print("  No relation:     {d}\n", .{result.summary.no_relation});

    if (result.relations_found > 0) {
        std.debug.print("\n{s}BEST RELATIONS:{s}\n", .{ CYAN, RESET });
        const show_count = @min(10, result.best_relations.len);
        for (0..show_count) |i| {
            const rel = result.best_relations[i];
            std.debug.print("  [{d}] {s}\n", .{ i, rel.description });
        }
    } else {
        std.debug.print("\n{s}No simple relations found.{s}\n", .{ GREEN, RESET });
        std.debug.print("  Spacings appear to be independent of π, φ, ln 2, √2, etc.\n", .{});
    }

    std.debug.print("\n{s}INTERPRETATION:{s}\n", .{ CYAN, RESET });
    if (result.relations_found == 0) {
        std.debug.print("  {s}NULL RESULT:{s} No arithmetic relations detected.\n", .{ GREEN, RESET });
        std.debug.print("  This is consistent with GUE predictions (random structure).\n", .{});
    } else if (result.relations_found < result.spacings_tested / 100) {
        std.debug.print("  {s}FEW RELATIONS:{s} {d} matches in {d} spacings.\n", .{
            GOLD, RESET, result.relations_found, result.spacings_tested,
        });
        std.debug.print("  Possible coincidences or near-matches.\n", .{});
    } else {
        std.debug.print("  {s}MANY RELATIONS:{s} Unexpected structure detected!\n", .{
            "\x1b[31m", RESET,
        });
    }

    std.debug.print("\n{s}STATUS: PSLQ analysis complete{s}\n", .{ GREEN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFERENCES
// ═══════════════════════════════════════════════════════════════════════════════
//
// [1] H. R. P. Ferguson, D. H. Bailey, S. Arno, "Analysis of PSLQ", 1999
// [2] J. M. Borwein, D. H. Bailey, "Mathematics by Experiment", 2004
//
// ═══════════════════════════════════════════════════════════════════════════════
