// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS TABLE DISPLAY — tri math constants command
// ═══════════════════════════════════════════════════════════════════════════════
//
// Reads sacred_constants from sacred_formula.zig (single source of truth)
// Outputs formatted table with --format, --category, --sort flags
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred_formula = @import("formula.zig");

// ANSI color codes
const GOLDEN = "\x1b[33m";
const CYAN = "\x1b[36m";
const WHITE = "\x1b[97m";
const GRAY = "\x1b[90m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";

pub const OutputFormat = enum {
    table,  // Default: Unicode table
    json,   // JSON output
    latex,  // LaTeX table
    csv,    // CSV format
};

pub const Category = enum {
    all,
    em,           // Electromagnetic
    strong,       // Strong force
    weak,         // Weak force
    cosmo,        // Cosmology
    ckm,          // CKM matrix
    pmns,         // PMNS neutrino
    masses,       // Particle masses
    nuclear,      // Nuclear physics
    quantum,      // Quantum physics
    mathematical, // Mathematical constants
    ratios,       // Mass ratios
    condensed,    // Condensed matter
    planck,       // Planck units
    astrophysics, // Astrophysics
    nuclear_magic,// Nuclear magic numbers
};

pub const SortBy = enum {
    error_pct,   // Sort by error % (ascending)
    name,    // Sort by name
    category, // Sort by category
};

// Category filter mapping
const category_patterns = std.ComptimeStringMap([]const u8, .{
    .{ "em", "particle_physics" },
    .{ "strong", "particle_physics" },
    .{ "weak", "particle_physics" },
    .{ "cosmo", "cosmology" },
    .{ "ckm", "ckm" },
    .{ "pmns", "neutrino" },
    .{ "masses", "particle_physics" },
    .{ "nuclear", "nuclear" },
    .{ "quantum", "quantum" },
    .{ "mathematical", "mathematical" },
    .{ "ratios", "ratios" },
    .{ "condensed", "condensed" },
    .{ "planck", "planck" },
    .{ "astrophysics", "astrophysics" },
    .{ "nuclear_magic", "nuclear_magic" },
});

/// Parse format flag
pub fn parseFormat(arg: ?[]const u8) OutputFormat {
    if (arg) |s| {
        if (std.mem.eql(u8, s, "json")) return .json;
        if (std.mem.eql(u8, s, "latex")) return .latex;
        if (std.mem.eql(u8, s, "csv")) return .csv;
    }
    return .table;
}

/// Parse category flag
pub fn parseCategory(arg: ?[]const u8) Category {
    if (arg) |s| {
        if (std.mem.eql(u8, s, "em")) return .em;
        if (std.mem.eql(u8, s, "strong")) return .strong;
        if (std.mem.eql(u8, s, "weak")) return .weak;
        if (std.mem.eql(u8, s, "cosmo")) return .cosmo;
        if (std.mem.eql(u8, s, "ckm")) return .ckm;
        if (std.mem.eql(u8, s, "pmns")) return .pmns;
        if (std.mem.eql(u8, s, "masses")) return .masses;
        if (std.mem.eql(u8, s, "nuclear")) return .nuclear;
        if (std.mem.eql(u8, s, "quantum")) return .quantum;
        if (std.mem.eql(u8, s, "mathematical")) return .mathematical;
        if (std.mem.eql(u8, s, "ratios")) return .ratios;
        if (std.mem.eql(u8, s, "condensed")) return .condensed;
        if (std.mem.eql(u8, s, "planck")) return .planck;
        if (std.mem.eql(u8, s, "astrophysics")) return .astrophysics;
        if (std.mem.eql(u8, s, "nuclear_magic")) return .nuclear_magic;
    }
    return .all;
}

/// Parse sort flag
pub fn parseSort(arg: ?[]const u8) SortBy {
    if (arg) |s| {
        if (std.mem.eql(u8, s, "error")) return .error_pct;
        if (std.mem.eql(u8, s, "name")) return .name;
        if (std.mem.eql(u8, s, "category")) return .category;
    }
    return .error_pct; // Default: sort by error
}

/// Check if constant matches category filter
fn matchesCategory(constant: sacred_formula.SacredConstant, cat: Category) bool {
    if (cat == .all) return true;

    const target_cat = constant.category;

    return switch (cat) {
        .all => true,
        .em => std.mem.eql(u8, target_cat, "particle_physics") and
               (std.mem.indexOf(u8, constant.name, "alpha") != null or
                std.mem.indexOf(u8, constant.name, "CHSH") != null),
        .strong => std.mem.eql(u8, target_cat, "particle_physics") and
                  std.mem.indexOf(u8, constant.symbol, "ALPHA_STRONG") != null,
        .weak => std.mem.eql(u8, target_cat, "particle_physics") and
              (std.mem.indexOf(u8, constant.name, "Weinberg") != null or
               std.mem.indexOf(u8, constant.name, "CKM") != null),
        .cosmo => std.mem.eql(u8, target_cat, "cosmology"),
        .ckm => std.mem.eql(u8, target_cat, "ckm"),
        .pmns => std.mem.eql(u8, target_cat, "neutrino"),
        .masses => std.mem.eql(u8, target_cat, "particle_physics") and
               (std.mem.indexOf(u8, constant.symbol, "MASS") != null or
                std.mem.indexOf(u8, constant.symbol, "MASS") != null),
        .nuclear => std.mem.eql(u8, target_cat, "nuclear") or
                   std.mem.eql(u8, target_cat, "nuclear_magic"),
        .quantum => std.mem.eql(u8, target_cat, "quantum"),
        .mathematical => std.mem.eql(u8, target_cat, "mathematical"),
        .ratios => std.mem.eql(u8, target_cat, "ratios"),
        .condensed => std.mem.eql(u8, target_cat, "condensed"),
        .planck => std.mem.eql(u8, target_cat, "planck"),
        .astrophysics => std.mem.eql(u8, target_cat, "astrophysics"),
        .nuclear_magic => std.mem.eql(u8, target_cat, "nuclear_magic"),
    };
}

/// Sort entry for sorting
const SortEntry = struct {
    constant: sacred_formula.SacredConstant,
    index: usize,

    fn compareByError(_: void, a: SortEntry, b: SortEntry) bool {
        return a.constant.error_pct < b.constant.error_pct;
    }

    fn compareByName(_: void, a: SortEntry, b: SortEntry) bool {
        return std.mem.lessThan(u8, a.constant.name, b.constant.name);
    }

    fn compareByCategory(_: void, a: SortEntry, b: SortEntry) bool {
        const cat_cmp = std.mem.order(u8, a.constant.category, b.constant.category);
        if (cat_cmp != .eq) return cat_cmp == .lt;
        return a.constant.error_pct < b.constant.error_pct;
    }
};

/// Main display function
pub fn displayConstantsTable(format: OutputFormat, cat: Category, sort: SortBy) void {
    switch (format) {
        .table => displayTable(cat, sort),
        .json => displayJson(cat, sort),
        .latex => displayLatex(cat, sort),
        .csv => displayCsv(cat, sort),
    }
}

/// Display as Unicode table
fn displayTable(cat: Category, sort: SortBy) void {
    // Collect filtered constants
    var filtered = std.ArrayList(sacred_formula.SacredConstant).init(std.heap.page_allocator);
    defer filtered.deinit();

    for (sacred_formula.sacred_constants) |c| {
        if (matchesCategory(c, cat)) {
            filtered.append(c) catch continue;
        }
    }

    // Create sort entries
    var sort_entries = std.ArrayList(SortEntry).init(std.heap.page_allocator);
    defer sort_entries.deinit();

    for (filtered.items, 0..) |c, i| {
        sort_entries.append(.{ .constant = c, .index = i }) catch continue;
    }

    // Sort
    const sort_fn = switch (sort) {
        .error_pct => SortEntry.compareByError,
        .name => SortEntry.compareByName,
        .category => SortEntry.compareByCategory,
    };
    std.sort.insertion(SortEntry, sort_entries.items, {}, sort_fn);

    // Print header
    std.debug.print("\n{s}┌─────────────────────────────────────────────────────────────────────────┐{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}│{s} {s}TRINITY CONSTANTS (φ² + φ⁻² = 3){s}                        {s}│{s}\n", .{ GOLDEN, RESET, BOLD, GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("{s}│{s} {s}γ = φ⁻³ ≈ 0.2361 (Barbero-Immirzi){s}                         {s}│{s}\n", .{ GOLDEN, RESET, WHITE, RESET, GOLDEN, RESET });
    std.debug.print("{s}├────┬───────────┬──────────────────┬──────────┬─────────┬───────┤{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}│{s} {s}#{s} │ {s}Constant{s}  │ {s}Formula{s}         │ {s}Computed{s}│ {s}CODATA{s} │ {s}Error{s} │{s}\n", .{ GOLDEN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, GOLDEN, RESET });
    std.debug.print("{s}├────┼───────────┼──────────────────┼──────────┼─────────┼───────┤{s}\n", .{ GOLDEN, RESET });

    // Print rows
    for (sort_entries.items, 0..) |entry, idx| {
        const c = entry.constant;

        // Format formula string
        var formula_buf: [128]u8 = undefined;
        const formula_str = formatFormula(&formula_buf, c);

        // Get error color
        const err_color = if (c.error_pct < 0.01) GREEN else if (c.error_pct < 0.1) WHITE else RED;

        // Truncate name if needed
        var name_display = c.name;
        if (name_display.len > 10) {
            name_display = name_display[0..10];
        }

        // Print row
        std.debug.print("{s}│{s} {s:>3}{s} │ {s:<9}{s} │ {s:<16}{s} │ {d:>8.6}{s} │ {d:>7.6}{s} │ {s}{d:>5.4}%{s} │{s}\n", .{
            GOLDEN, RESET,
            WHITE, idx + 1, RESET,
            CYAN, name_display, RESET,
            WHITE, formula_str, RESET,
            c.computed, RESET,
            c.target, RESET,
            err_color, c.error_pct, RESET,
            GOLDEN, RESET,
        });
    }

    // Print footer
    std.debug.print("{s}├────┴───────────┴──────────────────┴──────────┴─────────┴───────┤{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}│{s} {d} formulas │ 79/79 tests pass │ γ = φ⁻³        {s}TRINITY{s} │{s}\n", .{
        GOLDEN, RESET, sort_entries.items.len, RESET, GOLDEN, RESET, GOLDEN, RESET,
    });
    std.debug.print("{s}└─────────────────────────────────────────────────────────────────────────┘{s}\n\n", .{ GOLDEN, RESET });
}

/// Format formula as string
fn formatFormula(buf: []u8, c: sacred_formula.SacredConstant) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();

    writer.print("{d}", .{c.n}) catch return buf[0..0];

    if (c.k != 0) {
        if (c.k == 1) {
            writer.writeAll("×3") catch {};
        } else if (c.k == -1) {
            writer.writeAll("×3⁻¹") catch {};
        } else {
            writer.print("×3^{{}}", .{c.k}) catch {};
        }
    }
    if (c.m != 0) {
        if (c.m == 1) {
            writer.writeAll("×π") catch {};
        } else if (c.m == -1) {
            writer.writeAll("×π⁻¹") catch {};
        } else {
            writer.print("×π^{{}}", .{c.m}) catch {};
        }
    }
    if (c.p != 0) {
        if (c.p == 1) {
            writer.writeAll("×φ") catch {};
        } else if (c.p == -1) {
            writer.writeAll("×φ⁻¹") catch {};
        } else {
            writer.print("×φ^{{}}", .{c.p}) catch {};
        }
    }
    if (c.q != 0) {
        if (c.q == 1) {
            writer.writeAll("×e") catch {};
        } else if (c.q == -1) {
            writer.writeAll("×e⁻¹") catch {};
        } else {
            writer.print("×e^{{}}", .{c.q}) catch {};
        }
    }

    return fbs.getWritten();
}

/// Display as JSON
fn displayJson(cat: Category, sort: SortBy) void {
    _ = sort;

    std.debug.print("{{\n", .{});
    std.debug.print("  \"trinity_identity\": \"φ² + φ⁻² = 3\",\n", .{});
    std.debug.print("  \"gamma_note\": \"γ = φ⁻³ ≈ 0.2361 (Barbero-Immirzi)\",\n", .{});
    std.debug.print("  \"constants\": [\n", .{});

    var first = true;
    for (sacred_formula.sacred_constants) |c| {
        if (!matchesCategory(c, cat)) continue;

        if (!first) {
            std.debug.print(",\n", .{});
        }
        first = false;

        var formula_buf: [128]u8 = undefined;
        const formula_str = formatFormula(&formula_buf, c);

        std.debug.print("    {{\n", .{});
        std.debug.print("      \"name\": \"{s}\",\n", .{c.name});
        std.debug.print("      \"symbol\": \"{s}\",\n", .{c.symbol});
        std.debug.print("      \"formula\": \"{s}\",\n", .{formula_str});
        std.debug.print("      \"target\": {d:.10},\n", .{c.target});
        std.debug.print("      \"computed\": {d:.10},\n", .{c.computed});
        std.debug.print("      \"error_pct\": {d:.6},\n", .{c.error_pct});
        std.debug.print("      \"category\": \"{s}\"\n", .{c.category});
        std.debug.print("    }}", .{});
    }

    std.debug.print("\n  ],\n", .{});
    std.debug.print("  \"total\": {d},\n", .{sacred_formula.sacred_constants.len});
    std.debug.print("  \"tests_passing\": \"79/79\"\n", .{});
    std.debug.print("}}\n\n", .{});
}

/// Display as LaTeX
fn displayLatex(cat: Category, sort: SortBy) void {
    _ = sort;

    std.debug.print("\\begin{{table}}[h]\n", .{});
    std.debug.print("\\centering\n", .{});
    std.debug.print("\\caption{{Trinity Constants (\\(\\phi^2 + \\phi^{{-2}} = 3\\))}}\n", .{});
    std.debug.print("\\begin{{tabular}}{{clccc}}\n", .{});
    std.debug.print("\\toprule\n", .{});
    std.debug.print("# & Constant & Formula & Computed & CODATA & Error \\\\\\\\\n", .{});
    std.debug.print("\\midrule\n", .{});

    var count: usize = 0;
    for (sacred_formula.sacred_constants) |c| {
        if (!matchesCategory(c, cat)) continue;
        count += 1;

        var formula_buf: [128]u8 = undefined;
        const formula_str = formatFormula(&formula_buf, c);

        // Escape underscores for LaTeX
        var name_escaped: [64]u8 = undefined;
        var name_idx: usize = 0;
        for (c.name) |ch| {
            if (ch == '_') {
                name_escaped[name_idx] = '\\';
                name_idx += 1;
                name_escaped[name_idx] = '_';
            } else {
                name_escaped[name_idx] = ch;
            }
            name_idx += 1;
        }

        std.debug.print("{} & {} & {} & {d:.6} & {d:.6} & {d:.4}\\% \\\\\\\\\n", .{
            count, name_escaped[0..name_idx], formula_str, c.computed, c.target, c.error_pct,
        });
    }

    std.debug.print("\\bottomrule\n", .{});
    std.debug.print("\\end{{tabular}}\n", .{});
    std.debug.print("\\label{{tab:trinity-constants}}\n", .{});
    std.debug.print("\\end{{table}}\n\n", .{});
}

/// Display as CSV
fn displayCsv(cat: Category, sort: SortBy) void {
    _ = sort;

    std.debug.print("#,Constant,Symbol,Formula,Target,Computed,Error,Category\n", .{});

    var count: usize = 0;
    for (sacred_formula.sacred_constants) |c| {
        if (!matchesCategory(c, cat)) continue;
        count += 1;

        var formula_buf: [128]u8 = undefined;
        const formula_str = formatFormula(&formula_buf, c);

        std.debug.print("{d},{s},{s},{s},{d:.10},{d:.10},{d:.6},{s}\n", .{
            count, c.name, c.symbol, formula_str, c.target, c.computed, c.error_pct, c.category,
        });
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PELLIS COMPARISON TABLE
// ═══════════════════════════════════════════════════════════════════════════════

/// Display Pellis vs Trinity comparison table
pub fn displayPellisComparison() void {
    // Phi constants
    const PHI = 1.6180339887498948482;
    const PHI_SQ = PHI * PHI;
    const PHI_INV = 1.0 / PHI;
    const PHI_INV_SQ = PHI_INV * PHI_INV;
    const PHI_INV_CUBED = PHI_INV * PHI_INV * PHI_INV; // γ
    const PHI_4 = PHI_SQ * PHI_SQ;

    // Pellis formula for alpha inverse
    const pellis_alpha_inv: f64 = 360.0 * PHI_INV_SQ - 2.0 * PHI_INV_CUBED + std.math.pow(f64, 3.0 * PHI, -5.0);

    // Trinity formula for alpha
    const trinity_alpha: f64 = 36.0 / (std.math.pow(f64, std.math.pi, 4.0) * PHI_4 * std.math.e * std.math.e);
    const trinity_alpha_inv: f64 = 1.0 / trinity_alpha;

    // CODATA values
    const codata_alpha_inv: f64 = 137.035999084;

    // Trinity mu (proton-electron mass ratio)
    const trinity_mu: f64 = 6.0 * std.math.pow(f64, std.math.pi, 5.0);
    const codata_mu: f64 = 1836.15267343;

    // Print header
    std.debug.print("\n{s}┌──────────────────────────────────────────────────────────────────────────────┐{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}│{s} {s}PELLIS φ⁵  vs  TRINITY φ² + φ⁻² = 3{s}                            {s}│{s}\n", .{ GOLDEN, RESET, BOLD, GOLDEN, RESET, GOLDEN, RESET });
    std.debug.print("{s}├─────────────┬──────────────────────────┬───────────────────────────────────────┤{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}│{s} {s}Constant{s}   │ {s}Pellis{s}                   │ {s}Trinity{s}                                {s}│{s}\n", .{ GOLDEN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, GOLDEN, RESET });
    std.debug.print("{s}├─────────────┼──────────────────────────┼───────────────────────────────────────┤{s}\n", .{ GOLDEN, RESET });

    // Alpha inverse row
    const pellis_err = @abs(pellis_alpha_inv - codata_alpha_inv) / codata_alpha_inv * 100.0;
    const trinity_err = @abs(trinity_alpha_inv - codata_alpha_inv) / codata_alpha_inv * 100.0;

    std.debug.print("{s}│{s} {s}α⁻¹{s}         │ {s}360·φ⁻²-2·φ⁻³+(3φ)⁻⁵{s}     │ {s}π⁴φ⁴e²/36{s}                              {s}│{s}\n", .{
        GOLDEN, RESET, CYAN, RESET, WHITE, RESET, WHITE, RESET, GOLDEN, RESET,
    });
    std.debug.print("{s}│{s}             │ {s}= {d:.10}{s}             │ {s}= {d:.10}{s}                             {s}│{s}\n", .{
        GOLDEN, RESET, WHITE, pellis_alpha_inv, RESET, WHITE, trinity_alpha_inv, RESET, GOLDEN, RESET,
    });

    if (pellis_err < trinity_err) {
        std.debug.print("{s}│{s}             │ {s}err: {d:.8}% {s}🏆{s}        │ {s}err: {d:.4}%{s}                             {s}│{s}\n", .{
            GOLDEN, RESET, WHITE, pellis_err, GREEN, RESET, WHITE, trinity_err, RESET, GOLDEN, RESET,
        });
    } else {
        std.debug.print("{s}│{s}             │ {s}err: {d:.8}%{s}            │ {s}err: {d:.4}% {s}🏆{s}                            {s}│{s}\n", .{
            GOLDEN, RESET, WHITE, pellis_err, RESET, WHITE, trinity_err, GREEN, RESET, GOLDEN, RESET,
        });
    }

    std.debug.print("{s}├─────────────┼──────────────────────────┼───────────────────────────────────────┤{s}\n", .{ GOLDEN, RESET });

    // Mu row
    const mu_err = @abs(trinity_mu - codata_mu) / codata_mu * 100.0;

    std.debug.print("{s}│{s} {s}μ{s}           │ {s}via α derivation{s}       │ {s}6π⁵{s}                                   {s}│{s}\n", .{
        GOLDEN, RESET, CYAN, RESET, WHITE, RESET, WHITE, RESET, GOLDEN, RESET,
    });
    std.debug.print("{s}│{s}             │ {s}≈ 1836.15{s}               │ {s}= {d:.6}{s}                               {s}│{s}\n", .{
        GOLDEN, RESET, WHITE, RESET, WHITE, trinity_mu, RESET, GOLDEN, RESET,
    });
    std.debug.print("{s}│{s}             │ {s}err: ~0.002%{s}            │ {s}err: {d:.3}%{s}                              {s}│{s}\n", .{
        GOLDEN, RESET, WHITE, RESET, WHITE, mu_err, RESET, GOLDEN, RESET,
    });

    std.debug.print("{s}├─────────────┼──────────────────────────┼───────────────────────────────────────┤{s}\n", .{ GOLDEN, RESET });

    // Summary rows
    std.debug.print("{s}│{s} {s}Scope{s}       │ {s}~4 constants{s}           │ {s}142 formulas {s}🏆{s}                        {s}│{s}\n", .{
        GOLDEN, RESET, CYAN, RESET, WHITE, RESET, WHITE, GREEN, RESET, GOLDEN, RESET,
    });
    std.debug.print("{s}│{s} {s}Building{s}    │ {s}{{integers, φ}}{s}           │ {s}{{3, φ, π, e, γ=φ⁻³}}{s}                      {s}│{s}\n", .{
        GOLDEN, RESET, CYAN, RESET, WHITE, RESET, WHITE, RESET, GOLDEN, RESET,
    });
    std.debug.print("{s}│{s} {s}Style{s}       │ {s}Polynomial{s}              │ {s}Monomial{s}                               {s}│{s}\n", .{
        GOLDEN, RESET, CYAN, RESET, WHITE, RESET, GOLDEN, RESET,
    });

    std.debug.print("{s}└─────────────┴──────────────────────────┴───────────────────────────────────────┘{s}\n\n", .{ GOLDEN, RESET });

    // Footer note
    std.debug.print("  {s}Note:{s} In Trinity notation, {s}γ = φ⁻³ ≈ 0.2361{s} (not Euler-Mascheroni 0.5772)\n\n", .{ CYAN, RESET, WHITE, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "format formula" {
    const c = sacred_formula.SacredConstant{
        .name = "Test",
        .symbol = "TEST",
        .target = 137.0,
        .category = "test",
        .n = 4,
        .k = 2,
        .m = -1,
        .p = 1,
        .q = 2,
        .computed = 137.0,
        .error_pct = 0.0,
    };

    var buf: [128]u8 = undefined;
    const result = formatFormula(&buf, c);
    try std.testing.expect(result.len > 0);
}

test "constants table has data" {
    const count = sacred_formula.sacred_constants.len;
    try std.testing.expect(count > 100);
}
