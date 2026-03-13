//! TRI CHEMISTRY CLI v8.0
//! tri chem commands for chemical calculations, periodic table, and sacred chemistry
// @origin(manual) @regen(pending)

const std = @import("std");
const math = std.math;
const chem = @import("sacred"); // Import via build.zig module
const sacred_formula = @import("math/formula.zig");
const gematria_mod = @import("gematria.zig");
const math_mod = @import("math/mod.zig");

/// Main chemistry command dispatcher
pub fn runChemCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showHelp();
        return;
    }

    const command = args[0];

    // Core Commands
    if (std.mem.eql(u8, command, "periodic")) {
        try cmdPeriodic();
    } else if (std.mem.eql(u8, command, "element")) {
        try cmdElement(args);
    } else if (std.mem.eql(u8, command, "mass")) {
        try cmdMass(args);
    } else if (std.mem.eql(u8, command, "formula")) {
        try cmdFormula(args);
    } else if (std.mem.eql(u8, command, "balance")) {
        try cmdBalance(allocator, args);
    } else if (std.mem.eql(u8, command, "moles")) {
        try cmdMoles(args);
    } else if (std.mem.eql(u8, command, "atoms")) {
        try cmdAtoms(args);
    } else if (std.mem.eql(u8, command, "ideal-gas")) {
        try cmdIdealGas(args);
    } else if (std.mem.eql(u8, command, "stp")) {
        cmdSTP(args);
    } else if (std.mem.eql(u8, command, "ph")) {
        try cmdPH(args);
    } else if (std.mem.eql(u8, command, "poh") or std.mem.eql(u8, command, "pOH")) {
        try cmdPOH(args);
    } else if (std.mem.eql(u8, command, "molarity")) {
        try cmdMolarity(args);
    } else if (std.mem.eql(u8, command, "dilution")) {
        try cmdDilution(args);
    } else if (std.mem.eql(u8, command, "yield")) {
        try cmdYield(args);
    } else if (std.mem.eql(u8, command, "redox")) {
        try cmdRedox(allocator, args);
    } else if (std.mem.eql(u8, command, "oxidation")) {
        try cmdOxidation(allocator, args);
    } else if (std.mem.eql(u8, command, "gibbs")) {
        try cmdGibbs(args);
    } else if (std.mem.eql(u8, command, "nernst")) {
        try cmdNernst(args);
    } else if (std.mem.eql(u8, command, "half-life")) {
        try cmdHalfLife(args);
    } else if (std.mem.eql(u8, command, "search")) {
        cmdSearch(args);
    } else if (std.mem.eql(u8, command, "group")) {
        try cmdGroup(args);
    } else if (std.mem.eql(u8, command, "period")) {
        try cmdPeriodFilter(args);
    } else if (std.mem.eql(u8, command, "block")) {
        cmdBlock(args);
    } else if (std.mem.eql(u8, command, "limiting")) {
        try cmdLimiting(allocator, args);
    } else if (std.mem.eql(u8, command, "titration")) {
        try cmdTitration(args);
    } else if (std.mem.eql(u8, command, "buffer")) {
        try cmdBuffer(args);
    } else if (std.mem.eql(u8, command, "ksp")) {
        try cmdKsp(args);
    } else if (std.mem.eql(u8, command, "sacred")) {
        try cmdSacred(allocator, args);
    } else if (std.mem.eql(u8, command, "trinity")) {
        try cmdTrinity(allocator, args);
    } else if (std.mem.eql(u8, command, "phi")) {
        try cmdPhiPatterns(allocator, args);
    } else if (std.mem.eql(u8, command, "bonds")) {
        try cmdBonds(allocator, args);
    } else if (std.mem.eql(u8, command, "help")) {
        try showHelp();
    } else {
        std.debug.print("Unknown chemistry command: {s}\n\n", .{command});
        try showHelp();
    }
}

// ============================================
// COMMAND IMPLEMENTATIONS
// ============================================

/// tri chem periodic - Display ASCII periodic table
fn cmdPeriodic() !void {
    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                   PERIODIC TABLE OF ELEMENTS (118 elements)               ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\
    , .{});

    try printPeriodicTable();

    std.debug.print("\n[s-block: yellow] [p-block: blue] [d-block: red] [f-block: green]\n\n", .{});
    std.debug.print("Use 'tri chem element <symbol>' for detailed information\n", .{});
}

/// Print periodic table (placeholder - would render full ASCII table)
fn printPeriodicTable() !void {
    _ = try printPeriodicTableCompact();
}

/// Compact periodic table display
fn printPeriodicTableCompact() !void {
    std.debug.print(
        \\     1H  2He
        \\  3Li 4Be 5B  6C  7N  8O  9F  10Ne
        \\ 11Na12Mg13Al14Si15P  16S 17Cl18Ar
        \\ 19K 20Ca21Sc22Ti23V 24Cr25Mn26Fe27Co28Ni29Cu30Zn31Ga32Ge33As34Se35Br36Kr
        \\ 37Rb38Sr39Y 40Zr41Nb42Mo43Tc44Ru45Rh46Pd47Ag48Cd49In50Sn51Sb52Te53I  54Xe
        \\ 55Cs56Ba    72Hf73Ta74W 75Re76Os77Ir78Pt79Au80Hg81Tl82Pb83Bi84Po85At86Rn
        \\ 87Fr88Ra
        \\  [Lanthanides 57-71] [Actinides 89-103]
        \\
    , .{});
}

/// tri chem element <symbol|number> - Display element information card
fn cmdElement(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem element <symbol|atomic_number>\n", .{});
        std.debug.print("Example: tri chem element Au  or  tri chem element 79\n", .{});
        return;
    }

    const input = args[1];

    // getElement handles both symbols and numbers
    const element_ptr = chem.getElement(input);

    if (element_ptr) |el_ptr| {
        try printElementCard(el_ptr.*);
    } else {
        std.debug.print("Element not found: {s}\n", .{input});
    }
}

/// Print detailed element card
fn printElementCard(el: chem.Element) !void {
    const block_chars = [_]u8{ 's', 'p', 'd', 'f' };
    const block_char = if (el.block < 4) block_chars[el.block] else '?';

    const block_color = switch (el.block) {
        0 => "\x1b[33m", // s-block: yellow
        1 => "\x1b[34m", // p-block: blue
        2 => "\x1b[31m", // d-block: red
        3 => "\x1b[32m", // f-block: green
        else => "\x1b[0m",
    };
    const reset = "\x1b[0m";

    // Derive state at STP from melting point
    const state_at_stp = if (el.melting_point) |mp|
        if (mp > 298.15) "solid" else if (mp > 0) "liquid" else "gas"
    else
        "unknown";

    std.debug.print(
        \\
        \\╔════════════════════════════════════════════════════════════╗
        \\║  {s} {s}  - {s}                     ║
        \\╠════════════════════════════════════════════════════════════╣
        \\║  Atomic Number: {d}                                         ║
        \\║  Atomic Mass:  {d:.3} amu                                  ║
        \\║  Group:        {d}   Period: {d}   Block: {s}{c}{s}            ║
        \\║  Electron Config: {s}                                      ║
        \\
    , .{ block_color, el.symbol, el.name, el.number, el.mass, el.group, el.period, block_color, block_char, reset, el.electron_config });

    if (el.electronegativity) |en| {
        std.debug.print("║  Electronegativity: {d:.2} (Pauling)                       ║\n", .{en});
    } else {
        std.debug.print("║  Electronegativity: N/A                                   ║\n", .{});
    }

    if (el.ionization_energy) |ie| {
        std.debug.print("║  Ionization Energy: {d:.1} kJ/mol                         ║\n", .{ie});
    } else {
        std.debug.print("║  Ionization Energy: N/A                                  ║\n", .{});
    }

    if (el.atomic_radius) |r| {
        std.debug.print("║  Atomic Radius: {d:.1} pm                                ║\n", .{r});
    } else {
        std.debug.print("║  Atomic Radius: N/A                                     ║\n", .{});
    }

    std.debug.print(
        \\║  Valence Electrons: {d}                                     ║
        \\║  State at STP: {s}                                         ║
        \\║  Category: {s}                                              ║
        \\╚════════════════════════════════════════════════════════════╝
        \\
    , .{ el.valence, state_at_stp, el.category });
}

/// tri chem mass <formula> - Calculate molar mass
fn cmdMass(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem mass <formula>\n", .{});
        std.debug.print("Example: tri chem mass H2O  or  tri chem mass C6H12O6\n", .{});
        return;
    }

    const formula = args[1];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse and show breakdown
    const composition = chem.parseFormula(allocator, formula) catch |err| {
        std.debug.print("Error parsing formula: {s}\n", .{@errorName(err)});
        return;
    };

    std.debug.print("\nMolar Mass: {s}\n", .{formula});
    std.debug.print("═════════════════════════════════\n", .{});

    var iter = composition.iterator();
    var total: f64 = 0.0;
    while (iter.next()) |entry| {
        const elem_ptr = chem.getElement(entry.key_ptr.*) orelse continue;
        const elem = elem_ptr.*;
        const count = entry.value_ptr.*;
        const elem_mass = elem.mass * @as(f64, @floatFromInt(count));
        total += elem_mass;
        std.debug.print("  {s}: {d} x {d:.3} = {d:.3} g/mol\n", .{ entry.key_ptr.*, count, elem.mass, elem_mass });
    }

    std.debug.print("-------------------------------\n", .{});
    std.debug.print("  Total: {d:.3} g/mol\n\n", .{total});
}

/// tri chem formula <formula> - Analyze formula composition
fn cmdFormula(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem formula <formula>\n", .{});
        return;
    }

    const formula = args[1];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const composition = chem.parseFormula(allocator, formula) catch |err| {
        std.debug.print("Error parsing formula: {s}\n", .{@errorName(err)});
        return;
    };

    const mass = chem.molarMass(allocator, formula) catch {
        std.debug.print("Error calculating molar mass\n", .{});
        return;
    };

    std.debug.print("\nFormula Analysis: {s}\n", .{formula});
    std.debug.print("═══════════════════════════════════════\n", .{});

    // Element count
    std.debug.print("Element Counts:\n", .{});
    var iter = composition.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    // Percent composition
    std.debug.print("\nPercent Composition:\n", .{});
    const percent_comp = chem.percentComposition(allocator, formula) catch {
        std.debug.print("Error calculating percent composition\n", .{});
        return;
    };

    var iter2 = percent_comp.iterator();
    while (iter2.next()) |entry| {
        std.debug.print("  {s}: {d:.2}%\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    std.debug.print("\nMolar Mass: {d:.3} g/mol\n\n", .{mass});
}

// ============================================
// EQUATION BALANCING (Gaussian Elimination)
// ============================================

/// tri chem balance <equation> - Balance chemical equation using matrix method
fn cmdBalance(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem balance <equation>\n", .{});
        std.debug.print("Example: tri chem balance H2 + O2 -> H2O\n", .{});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Join remaining args into equation string
    var eq_parts: std.ArrayList(u8) = .empty;
    for (args[1..]) |arg| {
        if (eq_parts.items.len > 0) try eq_parts.append(alloc, ' ');
        try eq_parts.appendSlice(alloc, arg);
    }
    const equation = eq_parts.items;

    std.debug.print("\nBalancing: {s}\n", .{equation});
    std.debug.print("═══════════════════════════════════════\n", .{});

    // Split on -> or = to get reactants and products
    var reactant_str: []const u8 = "";
    var product_str: []const u8 = "";
    if (std.mem.indexOf(u8, equation, "->")) |idx| {
        reactant_str = std.mem.trim(u8, equation[0..idx], " ");
        product_str = std.mem.trim(u8, equation[idx + 2 ..], " ");
    } else if (std.mem.indexOfScalar(u8, equation, '=')) |idx| {
        reactant_str = std.mem.trim(u8, equation[0..idx], " ");
        product_str = std.mem.trim(u8, equation[idx + 1 ..], " ");
    } else {
        std.debug.print("Error: Use '->' or '=' to separate reactants and products\n", .{});
        return;
    }

    // Split each side on '+'
    var reactant_formulas: std.ArrayList([]const u8) = .empty;
    var prod_formulas: std.ArrayList([]const u8) = .empty;

    var r_iter = std.mem.splitScalar(u8, reactant_str, '+');
    while (r_iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        if (trimmed.len > 0) try reactant_formulas.append(alloc, trimmed);
    }
    var p_iter = std.mem.splitScalar(u8, product_str, '+');
    while (p_iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        if (trimmed.len > 0) try prod_formulas.append(alloc, trimmed);
    }

    const n_reactants = reactant_formulas.items.len;
    const n_products = prod_formulas.items.len;
    const n_compounds = n_reactants + n_products;

    if (n_compounds < 2) {
        std.debug.print("Error: Need at least 2 compounds\n", .{});
        return;
    }

    // Parse all formulas and collect unique elements
    var all_compositions: std.ArrayList(std.StringHashMap(u32)) = .empty;
    var all_formulas: std.ArrayList([]const u8) = .empty;
    var element_set = std.StringHashMap(void).init(alloc);

    for (reactant_formulas.items) |f| {
        const comp = chem.parseFormula(alloc, f) catch {
            std.debug.print("Error parsing: {s}\n", .{f});
            return;
        };
        var it = comp.iterator();
        while (it.next()) |entry| try element_set.put(entry.key_ptr.*, {});
        try all_compositions.append(alloc, comp);
        try all_formulas.append(alloc, f);
    }
    for (prod_formulas.items) |f| {
        const comp = chem.parseFormula(alloc, f) catch {
            std.debug.print("Error parsing: {s}\n", .{f});
            return;
        };
        var it = comp.iterator();
        while (it.next()) |entry| try element_set.put(entry.key_ptr.*, {});
        try all_compositions.append(alloc, comp);
        try all_formulas.append(alloc, f);
    }

    // Collect element names
    var elements: std.ArrayList([]const u8) = .empty;
    var el_iter = element_set.iterator();
    while (el_iter.next()) |entry| try elements.append(alloc, entry.key_ptr.*);

    const n_elements = elements.items.len;
    if (n_elements == 0) {
        std.debug.print("Error: No elements found\n", .{});
        return;
    }

    // Build composition matrix: rows=elements, cols=compounds
    // Reactants are positive, products are negative
    const matrix = try alloc.alloc([]f64, n_elements);
    for (matrix, 0..) |*row, i| {
        row.* = try alloc.alloc(f64, n_compounds);
        for (row.*, 0..) |*val, j| {
            const comp = all_compositions.items[j];
            const count = comp.get(elements.items[i]) orelse 0;
            const sign: f64 = if (j < n_reactants) 1.0 else -1.0;
            val.* = sign * @as(f64, @floatFromInt(count));
        }
    }

    // Gaussian elimination with partial pivoting
    var pivot_col: usize = 0;
    var pivot_row: usize = 0;
    while (pivot_row < n_elements and pivot_col < n_compounds) {
        // Find max in column
        var max_val: f64 = 0;
        var max_row: usize = pivot_row;
        for (pivot_row..n_elements) |i| {
            const abs_val = @abs(matrix[i][pivot_col]);
            if (abs_val > max_val) {
                max_val = abs_val;
                max_row = i;
            }
        }
        if (max_val < 1e-10) {
            pivot_col += 1;
            continue;
        }
        // Swap rows
        if (max_row != pivot_row) {
            const tmp = matrix[pivot_row];
            matrix[pivot_row] = matrix[max_row];
            matrix[max_row] = tmp;
        }
        // Eliminate
        const piv = matrix[pivot_row][pivot_col];
        for (0..n_compounds) |j| matrix[pivot_row][j] /= piv;
        for (0..n_elements) |i| {
            if (i == pivot_row) continue;
            const factor = matrix[i][pivot_col];
            if (@abs(factor) < 1e-10) continue;
            for (0..n_compounds) |j| matrix[i][j] -= factor * matrix[pivot_row][j];
        }
        pivot_row += 1;
        pivot_col += 1;
    }

    // Back-substitute to find null space — set last free variable = 1
    const coeffs = try alloc.alloc(f64, n_compounds);
    coeffs[n_compounds - 1] = 1.0;

    // Back-substitute from bottom
    var row_idx: usize = n_elements;
    while (row_idx > 0) {
        row_idx -= 1;
        // Find pivot column in this row
        var pcol: ?usize = null;
        for (0..n_compounds) |j| {
            if (@abs(matrix[row_idx][j] - 1.0) < 1e-10) {
                pcol = j;
                break;
            }
        }
        if (pcol) |pc| {
            var val: f64 = 0;
            for (pc + 1..n_compounds) |j| val += matrix[row_idx][j] * coeffs[j];
            coeffs[pc] = -val;
        }
    }

    // Scale to positive integers
    // First make all positive
    for (coeffs) |*c| if (c.* < 0) {
        for (coeffs) |*d| d.* = -d.*;
        break;
    };

    // Find multiplier to make all integer
    var best_mult: f64 = 1.0;
    for (1..101) |m| {
        const mf = @as(f64, @floatFromInt(m));
        var all_int = true;
        for (coeffs) |c| {
            const scaled = c * mf;
            if (@abs(scaled - @round(scaled)) > 0.01) {
                all_int = false;
                break;
            }
        }
        if (all_int) {
            best_mult = mf;
            break;
        }
    }

    const int_coeffs = try alloc.alloc(u32, n_compounds);
    for (coeffs, 0..) |c, i| {
        const rounded = @round(c * best_mult);
        int_coeffs[i] = @intFromFloat(@max(rounded, 1.0));
    }

    // Print balanced equation
    std.debug.print("\n", .{});
    for (0..n_compounds) |i| {
        if (i == n_reactants) {
            std.debug.print(" -> ", .{});
        } else if (i > 0) {
            std.debug.print(" + ", .{});
        }
        if (int_coeffs[i] != 1) {
            std.debug.print("{d} ", .{int_coeffs[i]});
        }
        std.debug.print("{s}", .{all_formulas.items[i]});
    }
    std.debug.print("\n", .{});

    // Verify conservation
    std.debug.print("\nVerification:\n", .{});
    var balanced = true;
    for (elements.items) |elem| {
        var left: i64 = 0;
        var right: i64 = 0;
        for (0..n_compounds) |j| {
            const comp = all_compositions.items[j];
            const count: i64 = @intCast(comp.get(elem) orelse 0);
            const coeff: i64 = @intCast(int_coeffs[j]);
            if (j < n_reactants) {
                left += count * coeff;
            } else {
                right += count * coeff;
            }
        }
        const ok = if (left == right) "OK" else "MISMATCH";
        if (left != right) balanced = false;
        std.debug.print("  {s}: {d} = {d} [{s}]\n", .{ elem, left, right, ok });
    }
    if (balanced) {
        std.debug.print("\nBalance verified: all atoms conserved\n", .{});
    } else {
        std.debug.print("\nWARNING: equation may not be balanced correctly\n", .{});
    }
    std.debug.print("\n", .{});
}

/// tri chem moles <mass> <formula> - Calculate moles
fn cmdMoles(args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: tri chem moles <mass> <formula>\n", .{});
        std.debug.print("Example: tri chem moles 18.015 H2O\n", .{});
        return;
    }

    const mass = try std.fmt.parseFloat(f64, args[1]);
    const formula = args[2];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const molar_mass = chem.molarMass(allocator, formula) catch {
        std.debug.print("Error parsing formula\n", .{});
        return;
    };

    const moles = mass / molar_mass;
    const molecules = moles * chem.AVOGADRO;

    std.debug.print("\nMole Calculation: {d:.3} g of {s}\n", .{ mass, formula });
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Molar Mass: {d:.3} g/mol\n", .{molar_mass});
    std.debug.print("Moles: {d:.6} mol\n", .{moles});
    std.debug.print("Molecules: {e:.4}\n", .{molecules});

    // Count total atoms
    const composition = chem.parseFormula(allocator, formula) catch {
        std.debug.print("Error parsing formula\n", .{});
        return;
    };

    var total_atoms: u64 = 0;
    var iter = composition.iterator();
    while (iter.next()) |entry| {
        total_atoms += entry.value_ptr.*;
    }
    const total_atoms_count = @as(f64, @floatFromInt(total_atoms)) * molecules;
    std.debug.print("Total Atoms: {e:.4}\n\n", .{total_atoms_count});
}

/// tri chem atoms <moles> <formula> - Calculate atom counts
fn cmdAtoms(args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: tri chem atoms <moles> <formula>\n", .{});
        std.debug.print("Example: tri chem atoms 2.5 H2SO4\n", .{});
        return;
    }

    const moles = try std.fmt.parseFloat(f64, args[1]);
    const formula = args[2];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const composition = chem.parseFormula(allocator, formula) catch {
        std.debug.print("Error parsing formula\n", .{});
        return;
    };

    std.debug.print("\nAtom Counts: {d:.3} mol of {s}\n", .{ moles, formula });
    std.debug.print("═══════════════════════════════════════\n", .{});

    var iter = composition.iterator();
    while (iter.next()) |entry| {
        const count = @as(f64, @floatFromInt(entry.value_ptr.*)) * moles * chem.AVOGADRO;
        std.debug.print("  {s}: {e:.4} atoms\n", .{ entry.key_ptr.*, count });
    }

    std.debug.print("\n", .{});
}

/// tri chem ideal-gas - Solve PV=nRT
fn cmdIdealGas(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem ideal-gas <P>=<value> <V>=<value> <n>=<value> <T>=<value>\n", .{});
        std.debug.print("Example: tri chem ideal-gas V= n=2 T=298 P=101325\n", .{});
        std.debug.print("Units: P in Pa, V in m3, n in mol, T in K\n", .{});
        return;
    }

    var p: ?f64 = null;
    var v: ?f64 = null;
    var n_gas: ?f64 = null;
    var t: ?f64 = null;

    for (args[1..]) |arg| {
        if (arg.len > 2) {
            const var_name = arg[0..1];
            const eq_idx = std.mem.indexOfScalar(u8, arg, '=') orelse continue;
            const value_str = arg[eq_idx + 1 ..];
            const value = std.fmt.parseFloat(f64, value_str) catch continue;

            if (std.mem.eql(u8, var_name, "P")) p = value;
            if (std.mem.eql(u8, var_name, "V")) v = value;
            if (std.mem.eql(u8, var_name, "n")) n_gas = value;
            if (std.mem.eql(u8, var_name, "T")) t = value;
        }
    }

    const result = chem.idealGasLaw(p, v, n_gas, t);

    std.debug.print("\nIdeal Gas Law (PV = nRT)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("R = {d:.3} J/(mol*K)\n\n", .{chem.GAS_CONSTANT});

    if (p) |val| {
        std.debug.print("P = {d:.3} Pa\n", .{val});
    } else {
        std.debug.print("P = {d:.3} Pa [calculated]\n", .{result.p});
    }
    if (v) |val| {
        std.debug.print("V = {d:.6} m3\n", .{val});
    } else {
        std.debug.print("V = {d:.6} m3 [calculated]\n", .{result.v});
    }
    if (n_gas) |val| {
        std.debug.print("n = {d:.3} mol\n", .{val});
    } else {
        std.debug.print("n = {d:.3} mol [calculated]\n", .{result.n});
    }
    if (t) |val| {
        std.debug.print("T = {d:.2} K ({d:.2} C)\n", .{ val, val - 273.15 });
    } else {
        std.debug.print("T = {d:.2} K [calculated]\n", .{result.t});
    }

    std.debug.print("\n", .{});
}

/// tri chem stp <moles> - Volume at STP
fn cmdSTP(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem stp <moles>\n", .{});
        std.debug.print("Example: tri chem stp 2.5\n", .{});
        return;
    }
    const moles = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Error: invalid number\n", .{});
        return;
    };
    const volume = moles * 22.414; // L at STP
    std.debug.print("\nVolume at STP\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("n = {d:.4} mol\n", .{moles});
    std.debug.print("V = n x 22.414 L/mol = {d:.4} L\n\n", .{volume});
}

/// tri chem ph <conc|acid> <molarity> - Calculate pH
fn cmdPH(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem ph <H+ concentration in M>\n", .{});
        std.debug.print("       tri chem ph <acid> <molarity>\n", .{});
        std.debug.print("Example: tri chem ph 0.01  or  tri chem ph HCl 0.01\n", .{});
        return;
    }

    var h_conc: f64 = undefined;

    // Try to parse as H+ concentration directly
    if (args.len == 2) {
        h_conc = try std.fmt.parseFloat(f64, args[1]);
    } else {
        // Strong acid approximation
        const acid = args[1];
        const molarity = try std.fmt.parseFloat(f64, args[2]);

        // Common strong acids fully dissociate
        if (std.mem.eql(u8, acid, "HCl") or
            std.mem.eql(u8, acid, "HBr") or
            std.mem.eql(u8, acid, "HI") or
            std.mem.eql(u8, acid, "HNO3") or
            std.mem.eql(u8, acid, "H2SO4"))
        {
            h_conc = molarity; // Strong acid, fully dissociates
        } else {
            std.debug.print("Note: {s} is not a strong acid. Using molarity as [H+].\n", .{acid});
            h_conc = molarity;
        }
    }

    const ph = chem.calculatePH(h_conc);
    const classification = chem.phClassification(ph);

    std.debug.print("\npH Calculation\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("[H+] = {e:.4} M\n", .{h_conc});
    std.debug.print("pH = {d:.2}\n", .{ph});
    std.debug.print("Classification: {s}\n", .{classification});

    const pOH = 14.0 - ph;
    const oh_conc = math.pow(f64, 10.0, -pOH);
    std.debug.print("[OH-] = {e:.4} M\n", .{oh_conc});
    std.debug.print("pOH = {d:.2}\n\n", .{pOH});
}

/// tri chem poh <conc> - Calculate pOH
fn cmdPOH(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem poh <OH- concentration in M>\n", .{});
        std.debug.print("Example: tri chem poh 0.001\n", .{});
        return;
    }
    const oh_conc = try std.fmt.parseFloat(f64, args[1]);
    const poh = chem.calculatePOH(oh_conc);
    const ph = 14.0 - poh;

    std.debug.print("\npOH Calculation\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("[OH-] = {e:.4} M\n", .{oh_conc});
    std.debug.print("pOH = {d:.2}\n", .{poh});
    std.debug.print("pH = 14 - pOH = {d:.2}\n", .{ph});
    std.debug.print("Classification: {s}\n\n", .{chem.phClassification(ph)});
}

/// tri chem molarity <moles> <volume_L> - Calculate molarity
fn cmdMolarity(args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: tri chem molarity <moles> <volume_L>\n", .{});
        std.debug.print("Example: tri chem molarity 0.5 0.25\n", .{});
        return;
    }
    const n = try std.fmt.parseFloat(f64, args[1]);
    const vol = try std.fmt.parseFloat(f64, args[2]);
    const m = n / vol;

    std.debug.print("\nMolarity Calculation\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("n = {d:.4} mol\n", .{n});
    std.debug.print("V = {d:.4} L\n", .{vol});
    std.debug.print("M = n/V = {d:.4} mol/L\n\n", .{m});
}

/// tri chem dilution <C1> <V1> <V2> - Calculate C2 = C1*V1/V2
fn cmdDilution(args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: tri chem dilution <C1> <V1> <V2>\n", .{});
        std.debug.print("Example: tri chem dilution 1.0 50 200\n", .{});
        return;
    }
    const c1 = try std.fmt.parseFloat(f64, args[1]);
    const v1 = try std.fmt.parseFloat(f64, args[2]);
    const v2 = try std.fmt.parseFloat(f64, args[3]);
    const c2 = c1 * v1 / v2;

    std.debug.print("\nDilution (C1V1 = C2V2)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("C1 = {d:.4} M\n", .{c1});
    std.debug.print("V1 = {d:.4} mL\n", .{v1});
    std.debug.print("V2 = {d:.4} mL\n", .{v2});
    std.debug.print("C2 = C1*V1/V2 = {d:.4} M\n\n", .{c2});
}

/// tri chem yield <theoretical> <actual> - Percent yield
fn cmdYield(args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: tri chem yield <theoretical_g> <actual_g>\n", .{});
        std.debug.print("Example: tri chem yield 10.0 8.5\n", .{});
        return;
    }
    const theoretical = try std.fmt.parseFloat(f64, args[1]);
    const actual = try std.fmt.parseFloat(f64, args[2]);
    const pct = (actual / theoretical) * 100.0;

    std.debug.print("\nPercent Yield\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Theoretical: {d:.3} g\n", .{theoretical});
    std.debug.print("Actual: {d:.3} g\n", .{actual});
    std.debug.print("Yield = (actual/theoretical) x 100 = {d:.2}%\n\n", .{pct});
}

// ============================================
// REDOX & ELECTROCHEMISTRY
// ============================================

/// Assign oxidation state for a target element in a compound
fn assignOxidationState(target: []const u8, formula: *const std.StringHashMap(u32)) i8 {
    return assignOxidationStateDepth(target, formula, 0);
}

/// Inner oxidation state solver with recursion depth limit
fn assignOxidationStateDepth(target: []const u8, formula: *const std.StringHashMap(u32), depth: u8) i8 {
    // Count elements
    var n_elements: u32 = 0;
    var it = formula.iterator();
    while (it.next()) |_| n_elements += 1;

    // Single element substance: oxidation state = 0
    if (n_elements == 1) return 0;

    // Fixed oxidation states (priority order)
    const known = knownOxState(target, formula);
    if (known) |k| return @intCast(k);

    // Compute from charge neutrality: sum of all (ox_state * count) = 0
    var known_sum: i32 = 0;
    var unknown_count: u32 = 0;
    var target_count: u32 = 0;

    var it2 = formula.iterator();
    while (it2.next()) |entry| {
        const sym = entry.key_ptr.*;
        const cnt = entry.value_ptr.*;
        if (std.mem.eql(u8, sym, target)) {
            target_count = cnt;
            continue;
        }
        const k = knownOxState(sym, formula);
        if (k) |ox| {
            known_sum += ox * @as(i32, @intCast(cnt));
        } else {
            const poly = polyatomicOxState(sym, formula);
            if (poly) |pox| {
                known_sum += pox * @as(i32, @intCast(cnt));
            } else if (depth < 1) {
                // Try resolving the unknown element recursively (1 level deep)
                const resolved = assignOxidationStateDepth(sym, formula, depth + 1);
                if (resolved != 0) {
                    known_sum += @as(i32, resolved) * @as(i32, @intCast(cnt));
                } else {
                    unknown_count += 1;
                }
            } else {
                unknown_count += 1;
            }
        }
    }

    if (unknown_count == 0 and target_count > 0) {
        // target_count * ox + known_sum = 0
        const ox = @divTrunc(-known_sum, @as(i32, @intCast(target_count)));
        if (ox >= -8 and ox <= 8) return @intCast(ox);
    }

    return 0;
}

/// Known fixed oxidation states
fn knownOxState(sym: []const u8, formula: *const std.StringHashMap(u32)) ?i32 {
    // Group 1 metals: always +1
    if (std.mem.eql(u8, sym, "H")) {
        // H is -1 in metal hydrides, +1 otherwise
        if (formula.get("Na") != null or formula.get("K") != null or formula.get("Ca") != null or formula.get("Li") != null)
            return -1;
        return 1;
    }
    if (std.mem.eql(u8, sym, "Li") or std.mem.eql(u8, sym, "Na") or std.mem.eql(u8, sym, "K") or
        std.mem.eql(u8, sym, "Rb") or std.mem.eql(u8, sym, "Cs")) return 1;
    // Group 2: always +2
    if (std.mem.eql(u8, sym, "Be") or std.mem.eql(u8, sym, "Mg") or std.mem.eql(u8, sym, "Ca") or
        std.mem.eql(u8, sym, "Sr") or std.mem.eql(u8, sym, "Ba")) return 2;
    // Oxygen: -2 (except peroxides)
    if (std.mem.eql(u8, sym, "O")) return -2;
    // Fluorine: always -1
    if (std.mem.eql(u8, sym, "F")) return -1;
    // Aluminum: +3
    if (std.mem.eql(u8, sym, "Al")) return 3;
    // Zinc: +2
    if (std.mem.eql(u8, sym, "Zn")) return 2;
    // Silver: +1
    if (std.mem.eql(u8, sym, "Ag")) return 1;

    return null;
}

/// Strip leading stoichiometric coefficient from a formula string (e.g. "2Fe" -> "Fe")
fn stripCoefficient(formula: []const u8) []const u8 {
    var i: usize = 0;
    while (i < formula.len and formula[i] >= '0' and formula[i] <= '9') : (i += 1) {}
    // Only strip if there's an uppercase letter after the digits (actual formula start)
    if (i > 0 and i < formula.len and formula[i] >= 'A' and formula[i] <= 'Z') {
        return formula[i..];
    }
    return formula;
}

/// Count elements in a formula map
fn countFormulaElements(formula: *const std.StringHashMap(u32)) u32 {
    var count: u32 = 0;
    var iter = formula.iterator();
    while (iter.next()) |_| count += 1;
    return count;
}

/// Pattern-based oxidation state for transition metals and non-metals
fn polyatomicOxState(sym: []const u8, formula: *const std.StringHashMap(u32)) ?i32 {
    // Halogens (Cl, Br, I) in binary compounds with metals: -1
    if (std.mem.eql(u8, sym, "Cl") or std.mem.eql(u8, sym, "Br") or std.mem.eql(u8, sym, "I")) {
        if (formula.get("O") == null) return -1;
        return null;
    }

    const n_elems = countFormulaElements(formula);

    // Sulfur in oxy-compounds with other elements (metal sulfates/sulfites)
    if (std.mem.eql(u8, sym, "S")) {
        if (formula.get("O")) |o_cnt| {
            if (formula.get("S")) |s_cnt| {
                if (n_elems > 2) {
                    // Ratio of O to S determines sulfate/sulfite pattern
                    const ratio = @divTrunc(@as(i32, @intCast(o_cnt)), @as(i32, @intCast(s_cnt)));
                    if (ratio >= 4) return 6; // sulfate (SO4²⁻)
                    if (ratio == 3) return 4; // sulfite (SO3²⁻)
                    if (ratio == 2) return 4; // thionyl-like
                }
            }
        }
        return null;
    }

    // Nitrogen in oxy-compounds (metal nitrates/nitrites)
    if (std.mem.eql(u8, sym, "N")) {
        if (formula.get("O")) |o_cnt| {
            if (formula.get("N")) |n_cnt| {
                if (n_elems > 2) {
                    const ratio = @divTrunc(@as(i32, @intCast(o_cnt)), @as(i32, @intCast(n_cnt)));
                    if (ratio >= 3) return 5; // nitrate (NO3⁻)
                    if (ratio == 2) return 3; // nitrite (NO2⁻)
                }
            }
        }
        return null;
    }

    // Carbon in oxy-compounds (metal carbonates)
    if (std.mem.eql(u8, sym, "C")) {
        if (formula.get("O")) |o_cnt| {
            if (formula.get("C")) |c_cnt| {
                if (n_elems > 2) {
                    const ratio = @divTrunc(@as(i32, @intCast(o_cnt)), @as(i32, @intCast(c_cnt)));
                    if (ratio >= 3) return 4; // carbonate (CO3²⁻)
                }
            }
        }
        return null;
    }

    // Phosphorus in oxy-compounds (metal phosphates)
    if (std.mem.eql(u8, sym, "P")) {
        if (formula.get("O")) |o_cnt| {
            if (formula.get("P")) |p_cnt| {
                if (n_elems > 2) {
                    const ratio = @divTrunc(@as(i32, @intCast(o_cnt)), @as(i32, @intCast(p_cnt)));
                    if (ratio >= 4) return 5; // phosphate (PO4³⁻)
                }
            }
        }
        return null;
    }

    // Transition metals: common defaults when in compounds
    if (std.mem.eql(u8, sym, "Cu")) return 2;
    if (std.mem.eql(u8, sym, "Fe")) return null; // varies (+2/+3), solved via charge neutrality
    if (std.mem.eql(u8, sym, "Mn")) return null;

    return null;
}

/// tri chem redox <reaction> - Analyze redox reaction
fn cmdRedox(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem redox <reaction>\n", .{});
        std.debug.print("Example: tri chem redox Fe + O2 -> Fe2O3\n", .{});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Join args
    var eq_parts: std.ArrayList(u8) = .empty;
    for (args[1..]) |arg| {
        if (eq_parts.items.len > 0) try eq_parts.append(alloc, ' ');
        try eq_parts.appendSlice(alloc, arg);
    }
    const equation = eq_parts.items;

    std.debug.print("\nRedox Analysis: {s}\n", .{equation});
    std.debug.print("═══════════════════════════════════════\n", .{});

    // Split on -> or =
    var reactant_str: []const u8 = "";
    var product_str: []const u8 = "";
    if (std.mem.indexOf(u8, equation, "->")) |idx| {
        reactant_str = std.mem.trim(u8, equation[0..idx], " ");
        product_str = std.mem.trim(u8, equation[idx + 2 ..], " ");
    } else if (std.mem.indexOfScalar(u8, equation, '=')) |idx| {
        reactant_str = std.mem.trim(u8, equation[0..idx], " ");
        product_str = std.mem.trim(u8, equation[idx + 1 ..], " ");
    } else {
        std.debug.print("Error: Use '->' or '=' to separate reactants and products\n", .{});
        return;
    }

    // Parse formulas on each side
    var reactant_formulas: std.ArrayList([]const u8) = .empty;
    var product_formulas: std.ArrayList([]const u8) = .empty;

    var r_iter = std.mem.splitScalar(u8, reactant_str, '+');
    while (r_iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        if (trimmed.len > 0) try reactant_formulas.append(alloc, stripCoefficient(trimmed));
    }
    var p_iter = std.mem.splitScalar(u8, product_str, '+');
    while (p_iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        if (trimmed.len > 0) try product_formulas.append(alloc, stripCoefficient(trimmed));
    }

    // Parse all compositions
    var reactant_comps: std.ArrayList(std.StringHashMap(u32)) = .empty;
    var product_comps: std.ArrayList(std.StringHashMap(u32)) = .empty;

    for (reactant_formulas.items) |f| {
        const comp = chem.parseFormula(alloc, f) catch {
            std.debug.print("Error parsing: {s}\n", .{f});
            return;
        };
        try reactant_comps.append(alloc, comp);
    }
    for (product_formulas.items) |f| {
        const comp = chem.parseFormula(alloc, f) catch {
            std.debug.print("Error parsing: {s}\n", .{f});
            return;
        };
        try product_comps.append(alloc, comp);
    }

    // Show oxidation states for each compound
    std.debug.print("\nOxidation States:\n", .{});
    std.debug.print("  Reactants:\n", .{});
    // Collect all element ox states across all reactants and products
    var reactant_ox = std.StringHashMap(i8).init(alloc);
    var product_ox = std.StringHashMap(i8).init(alloc);

    for (reactant_formulas.items, 0..) |f, idx| {
        std.debug.print("    {s}: ", .{f});
        var comp = reactant_comps.items[idx];
        var it = comp.iterator();
        while (it.next()) |entry| {
            const ox = assignOxidationState(entry.key_ptr.*, &comp);
            std.debug.print("{s}={d} ", .{ entry.key_ptr.*, @as(i32, ox) });
            // Store — if multiple compounds have same element, keep latest
            try reactant_ox.put(entry.key_ptr.*, ox);
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("  Products:\n", .{});
    for (product_formulas.items, 0..) |f, idx| {
        std.debug.print("    {s}: ", .{f});
        var comp = product_comps.items[idx];
        var it = comp.iterator();
        while (it.next()) |entry| {
            const ox = assignOxidationState(entry.key_ptr.*, &comp);
            std.debug.print("{s}={d} ", .{ entry.key_ptr.*, @as(i32, ox) });
            try product_ox.put(entry.key_ptr.*, ox);
        }
        std.debug.print("\n", .{});
    }

    // Compare oxidation states to find changes
    std.debug.print("\nElectron Transfer:\n", .{});
    var found_change = false;
    var total_e_transferred: i32 = 0;

    // Track oxidized/reduced elements for half-reactions
    const max_changes = 8;
    var oxidized_elems: [max_changes][]const u8 = undefined;
    var oxidized_from: [max_changes]i32 = undefined;
    var oxidized_to: [max_changes]i32 = undefined;
    var oxidized_e: [max_changes]i32 = undefined;
    var n_oxidized: usize = 0;

    var reduced_elems: [max_changes][]const u8 = undefined;
    var reduced_from: [max_changes]i32 = undefined;
    var reduced_to: [max_changes]i32 = undefined;
    var reduced_e: [max_changes]i32 = undefined;
    var n_reduced: usize = 0;

    var r_ox_iter = reactant_ox.iterator();
    while (r_ox_iter.next()) |entry| {
        const elem = entry.key_ptr.*;
        const r_val = entry.value_ptr.*;
        if (product_ox.get(elem)) |p_val| {
            if (r_val != p_val) {
                found_change = true;
                const r_i: i32 = r_val;
                const p_i: i32 = p_val;
                const diff = p_i - r_i;
                if (diff > 0) {
                    std.debug.print("  {s}: {d} -> {d} (lost {d} e⁻, OXIDIZED)\n", .{ elem, r_i, p_i, diff });
                    std.debug.print("    → {s} is the REDUCING AGENT\n", .{elem});
                    total_e_transferred += diff;
                    if (n_oxidized < max_changes) {
                        oxidized_elems[n_oxidized] = elem;
                        oxidized_from[n_oxidized] = r_i;
                        oxidized_to[n_oxidized] = p_i;
                        oxidized_e[n_oxidized] = diff;
                        n_oxidized += 1;
                    }
                } else {
                    std.debug.print("  {s}: {d} -> {d} (gained {d} e⁻, REDUCED)\n", .{ elem, r_i, p_i, -diff });
                    std.debug.print("    → {s} is the OXIDIZING AGENT\n", .{elem});
                    if (n_reduced < max_changes) {
                        reduced_elems[n_reduced] = elem;
                        reduced_from[n_reduced] = r_i;
                        reduced_to[n_reduced] = p_i;
                        reduced_e[n_reduced] = -diff;
                        n_reduced += 1;
                    }
                }
            }
        }
    }

    if (!found_change) {
        std.debug.print("  No oxidation state changes detected.\n", .{});
        std.debug.print("  This may not be a redox reaction.\n", .{});
    } else {
        // Half-reactions
        std.debug.print("\nHalf-Reactions:\n", .{});
        for (0..n_oxidized) |i| {
            const sign_from: u8 = if (oxidized_from[i] >= 0) '+' else '-';
            const abs_from: u32 = @intCast(if (oxidized_from[i] < 0) -oxidized_from[i] else oxidized_from[i]);
            const sign_to: u8 = if (oxidized_to[i] >= 0) '+' else '-';
            const abs_to: u32 = @intCast(if (oxidized_to[i] < 0) -oxidized_to[i] else oxidized_to[i]);
            if (abs_from == 0) {
                std.debug.print("  Oxidation: {s} → {s}({c}{d}) + {d}e⁻\n", .{
                    oxidized_elems[i], oxidized_elems[i], sign_to, abs_to, @as(u32, @intCast(oxidized_e[i])),
                });
            } else {
                std.debug.print("  Oxidation: {s}({c}{d}) → {s}({c}{d}) + {d}e⁻\n", .{
                    oxidized_elems[i], sign_from, abs_from, oxidized_elems[i], sign_to, abs_to, @as(u32, @intCast(oxidized_e[i])),
                });
            }
        }
        for (0..n_reduced) |i| {
            const sign_from: u8 = if (reduced_from[i] >= 0) '+' else '-';
            const abs_from: u32 = @intCast(if (reduced_from[i] < 0) -reduced_from[i] else reduced_from[i]);
            const sign_to: u8 = if (reduced_to[i] >= 0) '+' else '-';
            const abs_to: u32 = @intCast(if (reduced_to[i] < 0) -reduced_to[i] else reduced_to[i]);
            if (abs_to == 0) {
                std.debug.print("  Reduction: {s}({c}{d}) + {d}e⁻ → {s}\n", .{
                    reduced_elems[i], sign_from, abs_from, @as(u32, @intCast(reduced_e[i])), reduced_elems[i],
                });
            } else {
                std.debug.print("  Reduction: {s}({c}{d}) + {d}e⁻ → {s}({c}{d})\n", .{
                    reduced_elems[i], sign_from, abs_from, @as(u32, @intCast(reduced_e[i])), reduced_elems[i], sign_to, abs_to,
                });
            }
        }

        // Electron balance summary
        std.debug.print("\n  Total electrons transferred: {d}\n", .{@as(u32, @intCast(total_e_transferred))});
    }

    // Also balance the equation
    std.debug.print("\nBalanced equation:\n", .{});
    try cmdBalance(allocator, args);
}

/// tri chem oxidation <formula> - Show oxidation states
fn cmdOxidation(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem oxidation <formula>\n", .{});
        std.debug.print("Example: tri chem oxidation H2SO4\n", .{});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const formula = args[1];
    var comp = chem.parseFormula(alloc, formula) catch |err| {
        std.debug.print("Error parsing formula: {s}\n", .{@errorName(err)});
        return;
    };

    std.debug.print("\nOxidation States: {s}\n", .{formula});
    std.debug.print("═══════════════════════════════════════\n", .{});

    var it = comp.iterator();
    while (it.next()) |entry| {
        const ox = assignOxidationState(entry.key_ptr.*, &comp);
        const sign: u8 = if (ox >= 0) '+' else '-';
        const abs_ox: u32 = @intCast(if (ox < 0) -@as(i32, ox) else @as(i32, ox));
        std.debug.print("  {s}: {c}{d}\n", .{ entry.key_ptr.*, sign, abs_ox });
    }
    std.debug.print("\n", .{});
}

/// tri chem gibbs <dH> <dS> <T> - Gibbs free energy
fn cmdGibbs(args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: tri chem gibbs <dH_kJ> <dS_J_per_K> <T_K>\n", .{});
        std.debug.print("Example: tri chem gibbs -285.8 69.9 298\n", .{});
        return;
    }
    const dh = try std.fmt.parseFloat(f64, args[1]); // kJ
    const ds = try std.fmt.parseFloat(f64, args[2]); // J/(mol*K)
    const t = try std.fmt.parseFloat(f64, args[3]); // K
    const dg = dh * 1000.0 - t * ds; // in J
    const dg_kj = dg / 1000.0;

    std.debug.print("\nGibbs Free Energy (dG = dH - T*dS)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("dH = {d:.2} kJ/mol\n", .{dh});
    std.debug.print("dS = {d:.2} J/(mol*K)\n", .{ds});
    std.debug.print("T  = {d:.2} K\n", .{t});
    std.debug.print("dG = {d:.2} kJ/mol\n", .{dg_kj});
    if (dg_kj < 0) {
        std.debug.print("Reaction is SPONTANEOUS (dG < 0)\n\n", .{});
    } else if (dg_kj > 0) {
        std.debug.print("Reaction is NON-SPONTANEOUS (dG > 0)\n\n", .{});
    } else {
        std.debug.print("Reaction is at EQUILIBRIUM (dG = 0)\n\n", .{});
    }
}

/// tri chem nernst <E0> <n> <Q> - Nernst equation
fn cmdNernst(args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: tri chem nernst <E0_V> <n_electrons> <Q>\n", .{});
        std.debug.print("Example: tri chem nernst 1.10 2 0.01\n", .{});
        return;
    }
    const e0 = try std.fmt.parseFloat(f64, args[1]);
    const n = try std.fmt.parseFloat(f64, args[2]);
    const q = try std.fmt.parseFloat(f64, args[3]);

    // E = E0 - (RT/nF)ln(Q) at 298K: E = E0 - (0.02569/n)ln(Q)
    const rt_over_f = 0.025693; // RT/F at 298K in V
    const e = e0 - (rt_over_f / n) * @log(q);

    std.debug.print("\nNernst Equation: E = E0 - (RT/nF)ln(Q)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("E0 = {d:.4} V\n", .{e0});
    std.debug.print("n = {d:.0} electrons\n", .{n});
    std.debug.print("Q = {d:.4}\n", .{q});
    std.debug.print("T = 298.15 K (25 C)\n", .{});
    std.debug.print("E = {d:.4} V\n\n", .{e});
}

/// tri chem half-life <N0> <t_half> <t> - Radioactive decay
fn cmdHalfLife(args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: tri chem half-life <N0> <t_half> <t_elapsed>\n", .{});
        std.debug.print("Example: tri chem half-life 100 5730 10000\n", .{});
        return;
    }
    const n0 = try std.fmt.parseFloat(f64, args[1]);
    const t_half = try std.fmt.parseFloat(f64, args[2]);
    const t = try std.fmt.parseFloat(f64, args[3]);

    // N = N0 * (1/2)^(t/t_half)
    const n_half_lives = t / t_half;
    const remaining = n0 * math.pow(f64, 0.5, n_half_lives);

    std.debug.print("\nRadioactive Decay: N = N0 * (1/2)^(t/t1/2)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("N0 = {d:.4}\n", .{n0});
    std.debug.print("t1/2 = {d:.4}\n", .{t_half});
    std.debug.print("t = {d:.4}\n", .{t});
    std.debug.print("Half-lives elapsed: {d:.4}\n", .{n_half_lives});
    std.debug.print("Remaining: {d:.4}\n", .{remaining});
    std.debug.print("Decayed: {d:.4} ({d:.2}%)\n\n", .{ n0 - remaining, ((n0 - remaining) / n0) * 100.0 });
}

// ============================================
// SEARCH & INFO
// ============================================

/// tri chem search <term> - Search elements by name/symbol/category
fn cmdSearch(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem search <term>\n", .{});
        std.debug.print("Example: tri chem search metal  or  tri chem search gold\n", .{});
        return;
    }
    const term = args[1];
    std.debug.print("\nSearch Results for '{s}':\n", .{term});
    std.debug.print("═══════════════════════════════════════\n", .{});

    var count: u32 = 0;
    for (&chem.PERIODIC_TABLE) |*el| {
        // Search in symbol, name, category
        if (containsIgnoreCase(el.symbol, term) or
            containsIgnoreCase(el.name, term) or
            containsIgnoreCase(el.category, term))
        {
            std.debug.print("  {d:>3}  {s:<3} {s:<15} {d:.3} amu  [{s}]\n", .{ el.number, el.symbol, el.name, el.mass, el.category });
            count += 1;
        }
    }
    if (count == 0) {
        std.debug.print("  No elements found matching '{s}'\n", .{term});
    } else {
        std.debug.print("\n  Found {d} element(s)\n", .{count});
    }
    std.debug.print("\n", .{});
}

/// Case-insensitive substring search
fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    if (needle.len == 0) return true;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (0..needle.len) |j| {
            const h = if (haystack[i + j] >= 'A' and haystack[i + j] <= 'Z') haystack[i + j] + 32 else haystack[i + j];
            const n = if (needle[j] >= 'A' and needle[j] <= 'Z') needle[j] + 32 else needle[j];
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

/// tri chem group <1-18> - Show elements in a group
fn cmdGroup(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem group <1-18>\n", .{});
        return;
    }
    const group_num = try std.fmt.parseInt(u8, args[1], 10);
    std.debug.print("\nGroup {d} Elements:\n", .{group_num});
    std.debug.print("═══════════════════════════════════════\n", .{});

    for (&chem.PERIODIC_TABLE) |*el| {
        if (el.group == group_num) {
            std.debug.print("  {d:>3}  {s:<3} {s:<15} Period {d}  {d:.3} amu\n", .{ el.number, el.symbol, el.name, el.period, el.mass });
        }
    }
    std.debug.print("\n", .{});
}

/// tri chem period <1-7> - Show elements in a period
fn cmdPeriodFilter(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem period <1-7>\n", .{});
        return;
    }
    const period_num = try std.fmt.parseInt(u8, args[1], 10);
    std.debug.print("\nPeriod {d} Elements:\n", .{period_num});
    std.debug.print("═══════════════════════════════════════\n", .{});

    for (&chem.PERIODIC_TABLE) |*el| {
        if (el.period == period_num) {
            std.debug.print("  {d:>3}  {s:<3} {s:<15} Group {d}  {d:.3} amu\n", .{ el.number, el.symbol, el.name, el.group, el.mass });
        }
    }
    std.debug.print("\n", .{});
}

/// tri chem block <s|p|d|f> - Show elements in a block
fn cmdBlock(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem block <s|p|d|f>\n", .{});
        return;
    }
    const block_str = args[1];
    const block_idx: ?u8 = if (std.mem.eql(u8, block_str, "s"))
        0
    else if (std.mem.eql(u8, block_str, "p"))
        1
    else if (std.mem.eql(u8, block_str, "d"))
        2
    else if (std.mem.eql(u8, block_str, "f"))
        3
    else
        null;

    if (block_idx == null) {
        std.debug.print("Error: block must be s, p, d, or f\n", .{});
        return;
    }

    std.debug.print("\n{s}-block Elements:\n", .{block_str});
    std.debug.print("═══════════════════════════════════════\n", .{});

    for (&chem.PERIODIC_TABLE) |*el| {
        if (el.block == block_idx.?) {
            std.debug.print("  {d:>3}  {s:<3} {s:<15} {d:.3} amu\n", .{ el.number, el.symbol, el.name, el.mass });
        }
    }
    std.debug.print("\n", .{});
}

// ============================================
// LIMITING REAGENT, TITRATION, BUFFER, Ksp
// ============================================

/// tri chem limiting <mol1> <form1> <mol2> <form2> <product> - Limiting reagent
fn cmdLimiting(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 6) {
        std.debug.print("Usage: tri chem limiting <mol1> <formula1> <mol2> <formula2> <product>\n", .{});
        std.debug.print("Example: tri chem limiting 2 H2 1 O2 H2O\n", .{});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const mol1 = try std.fmt.parseFloat(f64, args[1]);
    const form1 = args[2];
    const mol2 = try std.fmt.parseFloat(f64, args[3]);
    const form2 = args[4];
    const product = args[5];

    // Parse formulas to estimate stoichiometric ratio from atom balance
    const comp1 = chem.parseFormula(alloc, form1) catch {
        std.debug.print("Error parsing {s}\n", .{form1});
        return;
    };
    const comp2 = chem.parseFormula(alloc, form2) catch {
        std.debug.print("Error parsing {s}\n", .{form2});
        return;
    };
    const comp_prod = chem.parseFormula(alloc, product) catch {
        std.debug.print("Error parsing {s}\n", .{product});
        return;
    };

    // Estimate stoichiometric coefficients from product composition
    // For each element in product, find which reactant provides it
    // Simple heuristic: ratio of product atoms / reactant atoms
    var ratio1: f64 = 1.0;
    var ratio2: f64 = 1.0;

    // Find an element unique to reactant 1 and check ratio
    var it1 = comp1.iterator();
    while (it1.next()) |entry| {
        if (comp_prod.get(entry.key_ptr.*)) |prod_count| {
            if (comp2.get(entry.key_ptr.*) == null) {
                // Element only in reactant 1 and product
                ratio1 = @as(f64, @floatFromInt(prod_count)) / @as(f64, @floatFromInt(entry.value_ptr.*));
                break;
            }
        }
    }

    var it2 = comp2.iterator();
    while (it2.next()) |entry| {
        if (comp_prod.get(entry.key_ptr.*)) |prod_count| {
            if (comp1.get(entry.key_ptr.*) == null) {
                ratio2 = @as(f64, @floatFromInt(prod_count)) / @as(f64, @floatFromInt(entry.value_ptr.*));
                break;
            }
        }
    }

    // Effective moles available considering stoichiometry
    const eff1 = mol1 / ratio1;
    const eff2 = mol2 / ratio2;

    const m1 = chem.molarMass(alloc, product) catch 0.0;

    std.debug.print("\nLimiting Reagent Analysis\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Reactant 1: {d:.3} mol {s} (stoich ratio: {d:.1})\n", .{ mol1, form1, ratio1 });
    std.debug.print("Reactant 2: {d:.3} mol {s} (stoich ratio: {d:.1})\n", .{ mol2, form2, ratio2 });
    std.debug.print("Product: {s}\n\n", .{product});

    if (eff1 <= eff2) {
        const yield_mol = mol1 / ratio1;
        std.debug.print("Limiting reagent: {s}\n", .{form1});
        std.debug.print("Excess reagent: {s}\n", .{form2});
        std.debug.print("Theoretical yield: {d:.4} mol of {s}", .{ yield_mol, product });
        if (m1 > 0) std.debug.print(" = {d:.3} g", .{yield_mol * m1});
        std.debug.print("\n", .{});
    } else {
        const yield_mol = mol2 / ratio2;
        std.debug.print("Limiting reagent: {s}\n", .{form2});
        std.debug.print("Excess reagent: {s}\n", .{form1});
        std.debug.print("Theoretical yield: {d:.4} mol of {s}", .{ yield_mol, product });
        if (m1 > 0) std.debug.print(" = {d:.3} g", .{yield_mol * m1});
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

/// tri chem titration <C_acid> <V_acid_mL> <C_base> - Equivalence point
fn cmdTitration(args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: tri chem titration <C_acid_M> <V_acid_mL> <C_base_M>\n", .{});
        std.debug.print("Example: tri chem titration 0.1 25 0.05\n", .{});
        std.debug.print("Calculates volume of base needed for equivalence point\n", .{});
        return;
    }
    const c_acid = try std.fmt.parseFloat(f64, args[1]);
    const v_acid = try std.fmt.parseFloat(f64, args[2]);
    const c_base = try std.fmt.parseFloat(f64, args[3]);

    // n_acid * C_acid * V_acid = n_base * C_base * V_base
    // For monoprotic acid/base: n_acid = n_base = 1
    const v_base = (c_acid * v_acid) / c_base;

    std.debug.print("\nAcid-Base Titration (Equivalence Point)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("C(acid) = {d:.4} M\n", .{c_acid});
    std.debug.print("V(acid) = {d:.2} mL\n", .{v_acid});
    std.debug.print("C(base) = {d:.4} M\n", .{c_base});
    std.debug.print("\nn(acid) = C * V = {d:.4} mmol\n", .{c_acid * v_acid});
    std.debug.print("At equivalence: n(acid) = n(base)\n", .{});
    std.debug.print("V(base) = n(acid) / C(base) = {d:.2} mL\n", .{v_base});
    std.debug.print("\nAt equivalence point: pH = 7.00 (strong acid + strong base)\n\n", .{});
}

/// tri chem buffer <pKa> <conc_acid> <conc_base> - Henderson-Hasselbalch
fn cmdBuffer(args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: tri chem buffer <pKa> <[HA]_M> <[A-]_M>\n", .{});
        std.debug.print("Example: tri chem buffer 4.75 0.1 0.15\n", .{});
        std.debug.print("Henderson-Hasselbalch: pH = pKa + log([A-]/[HA])\n", .{});
        return;
    }
    const pka = try std.fmt.parseFloat(f64, args[1]);
    const ha = try std.fmt.parseFloat(f64, args[2]);
    const a_minus = try std.fmt.parseFloat(f64, args[3]);

    const ratio = a_minus / ha;
    const ph = pka + @log(ratio) / @log(10.0);
    const capacity = @min(ha, a_minus); // simple approximation

    std.debug.print("\nBuffer pH (Henderson-Hasselbalch)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("pKa = {d:.2}\n", .{pka});
    std.debug.print("[HA] = {d:.4} M (weak acid)\n", .{ha});
    std.debug.print("[A-] = {d:.4} M (conjugate base)\n", .{a_minus});
    std.debug.print("[A-]/[HA] = {d:.4}\n", .{ratio});
    std.debug.print("log([A-]/[HA]) = {d:.4}\n", .{@log(ratio) / @log(10.0)});
    std.debug.print("\npH = pKa + log([A-]/[HA]) = {d:.2}\n", .{ph});
    std.debug.print("Buffer capacity (approx): {d:.4} M\n", .{capacity});
    std.debug.print("Effective range: pH {d:.1} - {d:.1}\n\n", .{ pka - 1.0, pka + 1.0 });
}

/// tri chem ksp <salt> <Ksp> - Molar solubility from Ksp
fn cmdKsp(args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: tri chem ksp <salt_formula> <Ksp_value>\n", .{});
        std.debug.print("Example: tri chem ksp AgCl 1.8e-10\n", .{});
        std.debug.print("Example: tri chem ksp Ca3PO42 2.07e-33\n", .{});
        return;
    }
    const salt = args[1];
    const ksp = try std.fmt.parseFloat(f64, args[2]);

    // Detect stoichiometry from formula
    // Common patterns: AB (1:1), A2B (2:1), AB2 (1:2), A3B2 (3:2)
    // For AxBy: Ksp = (a*s)^a * (b*s)^b = a^a * b^b * s^(a+b)
    // s = (Ksp / (a^a * b^b))^(1/(a+b))

    // Default: assume 1:1 (like AgCl, NaCl)
    var a: f64 = 1.0;
    var b: f64 = 1.0;
    var cation: []const u8 = @as([]const u8, "Cation");
    var anion: []const u8 = @as([]const u8, "Anion");

    // Recognize common salts
    if (std.mem.eql(u8, salt, "AgCl")) {
        a = 1;
        b = 1;
        cation = "Ag+";
        anion = "Cl-";
    } else if (std.mem.eql(u8, salt, "AgBr")) {
        a = 1;
        b = 1;
        cation = "Ag+";
        anion = "Br-";
    } else if (std.mem.eql(u8, salt, "AgI")) {
        a = 1;
        b = 1;
        cation = "Ag+";
        anion = "I-";
    } else if (std.mem.eql(u8, salt, "BaSO4")) {
        a = 1;
        b = 1;
        cation = "Ba2+";
        anion = "SO4(2-)";
    } else if (std.mem.eql(u8, salt, "CaF2")) {
        a = 1;
        b = 2;
        cation = "Ca2+";
        anion = "F-";
    } else if (std.mem.eql(u8, salt, "PbCl2")) {
        a = 1;
        b = 2;
        cation = "Pb2+";
        anion = "Cl-";
    } else if (std.mem.eql(u8, salt, "PbI2")) {
        a = 1;
        b = 2;
        cation = "Pb2+";
        anion = "I-";
    } else if (std.mem.eql(u8, salt, "Ag2CrO4")) {
        a = 2;
        b = 1;
        cation = "Ag+";
        anion = "CrO4(2-)";
    } else if (std.mem.eql(u8, salt, "Fe(OH)3") or std.mem.eql(u8, salt, "FeOH3")) {
        a = 1;
        b = 3;
        cation = "Fe3+";
        anion = "OH-";
    } else if (std.mem.eql(u8, salt, "Ca3(PO4)2") or std.mem.eql(u8, salt, "Ca3PO42")) {
        a = 3;
        b = 2;
        cation = "Ca2+";
        anion = "PO4(3-)";
    }

    const total = a + b;
    const coeff = math.pow(f64, a, a) * math.pow(f64, b, b);
    const s = math.pow(f64, ksp / coeff, 1.0 / total);

    std.debug.print("\nSolubility Product (Ksp)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Salt: {s}\n", .{salt});
    std.debug.print("Ksp = {e:.3}\n", .{ksp});
    std.debug.print("\nDissociation: {s} -> {d:.0} {s} + {d:.0} {s}\n", .{ salt, a, cation, b, anion });
    std.debug.print("Ksp = [{s}]^{d:.0} * [{s}]^{d:.0}\n", .{ cation, a, anion, b });
    std.debug.print("Ksp = ({d:.0}s)^{d:.0} * ({d:.0}s)^{d:.0}\n", .{ a, a, b, b });
    std.debug.print("\nMolar solubility: s = {e:.4} M\n", .{s});

    // Convert to g/L if we can calculate molar mass
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    if (chem.molarMass(alloc, salt)) |mm| {
        std.debug.print("Solubility: {e:.4} g/L\n", .{s * mm});
    } else |_| {}
    std.debug.print("\n", .{});
}

// ============================================
// HELP
// ============================================

// ============================================
// SACRED CHEMISTRY v8.0
// ============================================

/// Encode UTF-8 codepoint into buffer, return bytes written
fn encodeUtf8(cp: u21, buf: *[4]u8) u3 {
    if (cp < 0x80) {
        buf[0] = @intCast(cp);
        return 1;
    } else if (cp < 0x800) {
        buf[0] = @intCast(0xC0 | (cp >> 6));
        buf[1] = @intCast(0x80 | (cp & 0x3F));
        return 2;
    } else if (cp < 0x10000) {
        buf[0] = @intCast(0xE0 | (cp >> 12));
        buf[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        buf[2] = @intCast(0x80 | (cp & 0x3F));
        return 3;
    } else {
        buf[0] = @intCast(0xF0 | (cp >> 18));
        buf[1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
        buf[2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        buf[3] = @intCast(0x80 | (cp & 0x3F));
        return 4;
    }
}

/// Convert number to balanced ternary representation
fn toBalancedTernary(z: u32, buf: *[20]i8) u8 {
    var n: i32 = @intCast(z);
    var len: u8 = 0;
    if (n == 0) {
        buf[0] = 0;
        return 1;
    }
    while (n != 0 and len < 20) {
        var rem = @mod(n, @as(i32, 3));
        n = @divFloor(n, @as(i32, 3));
        if (rem == 2) {
            rem = -1;
            n += 1;
        }
        buf[len] = @intCast(rem);
        len += 1;
    }
    // Reverse in place
    var i: u8 = 0;
    while (i < len / 2) : (i += 1) {
        const tmp = buf[i];
        buf[i] = buf[len - 1 - i];
        buf[len - 1 - i] = tmp;
    }
    return len;
}

/// tri chem sacred <formula> — Sacred formula decomposition of molecular properties
fn cmdSacred(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem sacred <formula>\nExample: tri chem sacred H2O\n", .{});
        return;
    }

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const GRAY = "\x1b[90m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    const formula = args[1];
    const mass_result = chem.molarMass(allocator, formula);
    const molar_mass = mass_result catch {
        std.debug.print("Error: Cannot parse formula '{s}'\n", .{formula});
        return;
    };

    std.debug.print("\n{s}SACRED CHEMISTRY: {s}{s}\n", .{ GOLDEN, formula, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    // Sacred formula decomposition of molar mass
    const fit = sacred_formula.fitSacredFormula(molar_mass);
    var formula_buf: [128]u8 = undefined;
    const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);
    std.debug.print("Molar Mass: {d:.3} g/mol\n", .{molar_mass});
    std.debug.print("{s}Sacred:{s}     {s}  = {d:.3}  ({d:.4}%)\n\n", .{ MAGENTA, RESET, formula_str, fit.computed, fit.error_pct });

    // Element decomposition
    const composition = chem.parseFormula(allocator, formula) catch {
        return;
    };

    std.debug.print("{s}Element Sacred Decomposition:{s}\n", .{ CYAN, RESET });
    var total_en: f64 = 0;
    var en_count: f64 = 0;

    var it = composition.iterator();
    while (it.next()) |entry| {
        const sym = entry.key_ptr.*;
        const count = entry.value_ptr.*;
        const el = chem.getElement(sym) orelse continue;

        // Mass fit
        const mass_fit = sacred_formula.fitSacredFormula(el.mass);
        var mbuf: [128]u8 = undefined;
        const mstr = sacred_formula.formatFormulaString(&mbuf, mass_fit);
        std.debug.print("  {s}{s:<3}{s} mass={d:>8.3}  {s}{s}{s}  ({d:.3}%)\n", .{ GREEN, sym, RESET, el.mass, GRAY, mstr, RESET, mass_fit.error_pct });

        // Ionization energy fit
        if (el.ionization_energy) |ie| {
            const ie_fit = sacred_formula.fitSacredFormula(ie);
            var ibuf: [128]u8 = undefined;
            const istr = sacred_formula.formatFormulaString(&ibuf, ie_fit);
            std.debug.print("  {s:<3} IE  ={d:>8.3}  {s}{s}{s}  ({d:.3}%)\n", .{ "", ie, GRAY, istr, RESET, ie_fit.error_pct });
        }

        // Accumulate electronegativity
        if (el.electronegativity) |en| {
            total_en += en * @as(f64, @floatFromInt(count));
            en_count += @as(f64, @floatFromInt(count));
        }
    }

    // Average electronegativity
    if (en_count > 0) {
        const avg_en = total_en / en_count;
        const en_fit = sacred_formula.fitSacredFormula(avg_en);
        var ebuf: [128]u8 = undefined;
        const estr = sacred_formula.formatFormulaString(&ebuf, en_fit);
        std.debug.print("\n{s}Avg Electronegativity:{s} {d:.3}\n", .{ CYAN, RESET, avg_en });
        std.debug.print("  {s}Sacred:{s} {s}  ({d:.3}%)\n", .{ MAGENTA, RESET, estr, en_fit.error_pct });
    }

    std.debug.print("\n{s}V = n x 3^k x pi^m x phi^p x e^q{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

/// tri chem trinity <element> — Element's Trinity connections
fn cmdTrinity(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 2) {
        std.debug.print("Usage: tri chem trinity <element>\nExample: tri chem trinity Au\n", .{});
        return;
    }

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    const input = args[1];
    const el = chem.getElement(input) orelse {
        std.debug.print("Error: Element '{s}' not found\n", .{input});
        return;
    };

    const z: u32 = @intCast(el.number);

    std.debug.print("\n{s}TRINITY ANALYSIS: {s} ({s}){s}\n", .{ GOLDEN, el.symbol, el.name, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("Atomic Number: {d}\n\n", .{el.number});

    // 1. Balanced ternary encoding
    var trit_buf: [20]i8 = undefined;
    const trit_len = toBalancedTernary(z, &trit_buf);
    std.debug.print("{s}Balanced Ternary:{s} ", .{ CYAN, RESET });
    for (0..trit_len) |i| {
        const t = trit_buf[i];
        if (t == 1) {
            std.debug.print("{s}+1{s} ", .{ GREEN, RESET });
        } else if (t == -1) {
            std.debug.print("{s}-1{s} ", .{ MAGENTA, RESET });
        } else {
            std.debug.print(" 0 ", .{});
        }
    }
    std.debug.print("\nTrit Count: {d} trits\n\n", .{trit_len});

    // 2. Sacred formula fits
    std.debug.print("{s}Sacred Formula:{s}\n", .{ CYAN, RESET });
    {
        const mass_fit = sacred_formula.fitSacredFormula(el.mass);
        var mbuf: [128]u8 = undefined;
        const mstr = sacred_formula.formatFormulaString(&mbuf, mass_fit);
        std.debug.print("  Mass ({d:.3}):  {s}  ({d:.3}%)\n", .{ el.mass, mstr, mass_fit.error_pct });
    }
    if (el.ionization_energy) |ie| {
        const ie_fit = sacred_formula.fitSacredFormula(ie);
        var ibuf: [128]u8 = undefined;
        const istr = sacred_formula.formatFormulaString(&ibuf, ie_fit);
        std.debug.print("  IE ({d:.3} eV): {s}  ({d:.3}%)\n", .{ ie, istr, ie_fit.error_pct });
    }
    if (el.electronegativity) |en| {
        const en_fit = sacred_formula.fitSacredFormula(en);
        var ebuf: [128]u8 = undefined;
        const estr = sacred_formula.formatFormulaString(&ebuf, en_fit);
        std.debug.print("  EN ({d:.2}):     {s}  ({d:.3}%)\n", .{ en, estr, en_fit.error_pct });
    }

    // 3. Fibonacci/Lucas check
    std.debug.print("\n{s}Sequence Check:{s}\n", .{ CYAN, RESET });
    var is_fib = false;
    var is_lucas = false;
    var fib_idx: u32 = 0;
    var lucas_idx: u32 = 0;
    for (0..25) |i| {
        const idx: u32 = @intCast(i);
        const f = math_mod.fibonacci(idx);
        if (f == @as(i64, z)) {
            is_fib = true;
            fib_idx = idx;
        }
        const l = math_mod.lucas(idx);
        if (l == @as(i64, z)) {
            is_lucas = true;
            lucas_idx = idx;
        }
    }
    if (is_fib) {
        std.debug.print("  {s}Fibonacci:{s} YES — F({d}) = {d}\n", .{ GREEN, RESET, fib_idx, z });
    } else {
        std.debug.print("  Fibonacci: No\n", .{});
    }
    if (is_lucas) {
        std.debug.print("  {s}Lucas:{s}     YES — L({d}) = {d}\n", .{ GREEN, RESET, lucas_idx, z });
    } else {
        std.debug.print("  Lucas:     No\n", .{});
    }

    // 4. Golden angle
    const golden_angle = chem.math.GOLDEN_ANGLE_DEG;
    const angle = @mod(@as(f64, @floatFromInt(z)) * golden_angle, 360.0);
    const sector: u32 = @intFromFloat(angle / 45.0);
    std.debug.print("\n{s}Golden Angle:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {d} x 137.508 = {d:.1} deg (sector {d}/8)\n", .{ z, angle, sector });

    // 5. Coptic glyph
    const glyph_idx = z % 27;
    const glyph = gematria_mod.COPTIC_TABLE[glyph_idx];
    var utf8_buf: [4]u8 = undefined;
    const utf8_len = encodeUtf8(glyph.codepoint, &utf8_buf);
    const kingdom: []const u8 = if (glyph_idx < 9) "Matter" else if (glyph_idx < 18) "Energy" else "Info";

    std.debug.print("\n{s}Coptic Glyph:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}{s}{s} (value={d}, kingdom={s})\n", .{ GOLDEN, utf8_buf[0..utf8_len], RESET, glyph.value, kingdom });
    std.debug.print("  {d} mod 27 = {d} -> glyph index {d}\n", .{ z, glyph_idx, glyph_idx });

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

/// tri chem phi [ratios|fibonacci|spiral|fits] — Golden ratio patterns
fn cmdPhiPatterns(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const GRAY = "\x1b[90m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    const phi = chem.math.PHI;
    const filter: ?[]const u8 = if (args.len >= 2) args[1] else null;
    const show_all = filter == null;

    std.debug.print("\n{s}GOLDEN RATIO IN THE PERIODIC TABLE{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}phi = {d:.10}{s}\n\n", .{ GRAY, phi, RESET });

    // a) Consecutive mass ratios near phi
    if (show_all or (filter != null and std.mem.eql(u8, filter.?, "ratios"))) {
        std.debug.print("{s}Mass Ratios Near phi (|ratio - phi| < 0.05):{s}\n", .{ CYAN, RESET });
        var found: u32 = 0;
        for (0..117) |i| {
            const m1 = chem.PERIODIC_TABLE[i].mass;
            const m2 = chem.PERIODIC_TABLE[i + 1].mass;
            if (m1 > 0) {
                const ratio = m2 / m1;
                const diff = @abs(ratio - phi);
                if (diff < 0.05) {
                    std.debug.print("  {s}{s:<3}{s}/{s:<3} = {d:.6} / {d:.6} = {s}{d:.6}{s} (delta={d:.4})\n", .{
                        GREEN,
                        chem.PERIODIC_TABLE[i + 1].symbol,
                        RESET,
                        chem.PERIODIC_TABLE[i].symbol,
                        m2,
                        m1,
                        GOLDEN,
                        ratio,
                        RESET,
                        diff,
                    });
                    found += 1;
                }
            }
        }
        if (found == 0) std.debug.print("  (none within threshold)\n", .{});
        std.debug.print("  Found {d} ratio(s)\n\n", .{found});
    }

    // b) Fibonacci / noble gas / magic numbers
    if (show_all or (filter != null and std.mem.eql(u8, filter.?, "fibonacci"))) {
        std.debug.print("{s}Fibonacci & Noble Gas Numbers:{s}\n", .{ CYAN, RESET });
        const noble_gases = [_]u8{ 2, 10, 18, 36, 54, 86 };
        for (noble_gases) |ng| {
            var fib_match: ?u32 = null;
            for (0..25) |j| {
                const idx: u32 = @intCast(j);
                if (math_mod.fibonacci(idx) == @as(i64, ng)) {
                    fib_match = idx;
                    break;
                }
            }
            const el = chem.getElement(@as(u8, ng));
            const sym: []const u8 = if (el) |e| e.symbol else "??";
            const name: []const u8 = if (el) |e| e.name else "Unknown";
            if (fib_match) |fi| {
                std.debug.print("  Z={d:>3} {s:<3} {s:<12} {s}= F({d}) FIBONACCI!{s}\n", .{ ng, sym, name, GREEN, fi, RESET });
            } else {
                std.debug.print("  Z={d:>3} {s:<3} {s:<12}\n", .{ ng, sym, name });
            }
        }

        // Nuclear magic numbers
        std.debug.print("\n  {s}Nuclear Magic Numbers:{s}\n", .{ MAGENTA, RESET });
        const magic = [_]u8{ 2, 8, 20, 28, 50, 82, 126 };
        for (magic) |mn| {
            var fib_match: ?u32 = null;
            var lucas_match: ?u32 = null;
            for (0..25) |j| {
                const idx: u32 = @intCast(j);
                if (math_mod.fibonacci(idx) == @as(i64, mn)) fib_match = idx;
                if (math_mod.lucas(idx) == @as(i64, mn)) lucas_match = idx;
            }
            var tag_buf: [32]u8 = undefined;
            var tag_len: usize = 0;
            if (fib_match) |fi| {
                const s = std.fmt.bufPrint(tag_buf[tag_len..], "F({d}) ", .{fi}) catch "";
                tag_len += s.len;
            }
            if (lucas_match) |li| {
                const s = std.fmt.bufPrint(tag_buf[tag_len..], "L({d}) ", .{li}) catch "";
                tag_len += s.len;
            }
            if (tag_len > 0) {
                std.debug.print("  {d:>3}  {s}{s}{s}\n", .{ mn, GREEN, tag_buf[0..tag_len], RESET });
            } else {
                std.debug.print("  {d:>3}\n", .{mn});
            }
        }
        std.debug.print("\n", .{});
    }

    // c) Golden angle spiral
    if (show_all or (filter != null and std.mem.eql(u8, filter.?, "spiral"))) {
        std.debug.print("{s}Golden Angle Spiral (first 30 elements):{s}\n", .{ CYAN, RESET });
        const golden_angle = chem.math.GOLDEN_ANGLE_DEG;
        for (1..31) |z| {
            const angle = @mod(@as(f64, @floatFromInt(z)) * golden_angle, 360.0);
            const bar_len: u32 = @intFromFloat(angle / 10.0);
            const el = chem.getElement(@as(u8, @intCast(z)));
            const sym: []const u8 = if (el) |e| e.symbol else "??";
            std.debug.print("  {d:>3} {s:<3} {d:>6.1} |", .{ z, sym, angle });
            for (0..bar_len) |_| {
                std.debug.print("{s}#{s}", .{ GOLDEN, RESET });
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    // d) Best sacred formula fits
    if (show_all or (filter != null and std.mem.eql(u8, filter.?, "fits"))) {
        std.debug.print("{s}Best Sacred Formula Fits (error < 0.5%%):{s}\n", .{ CYAN, RESET });
        // Collect and display (no dynamic sort needed — just iterate and print low-error ones)
        var count: u32 = 0;
        for (&chem.PERIODIC_TABLE) |*el_ptr| {
            const fit = sacred_formula.fitSacredFormula(el_ptr.mass);
            if (fit.error_pct < 0.5) {
                var fbuf: [128]u8 = undefined;
                const fstr = sacred_formula.formatFormulaString(&fbuf, fit);
                std.debug.print("  {d:>3} {s:<3} {s:<15} {d:>10.3} -> {s}  {s}({d:.4}%%){s}\n", .{
                    el_ptr.number, el_ptr.symbol, el_ptr.name, el_ptr.mass, fstr, GREEN, fit.error_pct, RESET,
                });
                count += 1;
            }
        }
        std.debug.print("  {s}Total: {d} element(s) with < 0.5%% error{s}\n\n", .{ GRAY, count, RESET });
    }

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

/// tri chem bonds <formula> — Sacred bond analysis
fn cmdBonds(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem bonds <formula>\nExample: tri chem bonds H2O\n", .{});
        return;
    }

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    const formula = args[1];
    const composition = chem.parseFormula(allocator, formula) catch {
        std.debug.print("Error: Cannot parse formula '{s}'\n", .{formula});
        return;
    };

    // Count total atoms, electrons, estimate bonds
    var total_atoms: u32 = 0;
    var total_electrons: u32 = 0;
    var total_valence: u32 = 0;

    var it = composition.iterator();
    while (it.next()) |entry| {
        const count: u32 = entry.value_ptr.*;
        const el = chem.getElement(entry.key_ptr.*) orelse continue;
        total_atoms += count;
        total_electrons += @as(u32, el.number) * count;
        total_valence += @as(u32, el.valence) * count;
    }

    const est_bonds = total_valence / 2;

    // Average bond energy estimate (kJ/mol)
    const avg_bond_energy: f64 = 350.0; // Reasonable average for organic/inorganic
    // Known bond energies for common pairs
    const bond_energy: f64 = blk: {
        // Simple heuristic: check for common molecules
        if (std.mem.eql(u8, formula, "H2O")) break :blk 926.0; // 2 x O-H (463)
        if (std.mem.eql(u8, formula, "CO2")) break :blk 1598.0; // 2 x C=O (799)
        if (std.mem.eql(u8, formula, "CH4")) break :blk 1652.0; // 4 x C-H (413)
        if (std.mem.eql(u8, formula, "NH3")) break :blk 1173.0; // 3 x N-H (391)
        if (std.mem.eql(u8, formula, "NaCl")) break :blk 411.0; // ionic
        if (std.mem.eql(u8, formula, "H2")) break :blk 436.0;
        if (std.mem.eql(u8, formula, "O2")) break :blk 498.0;
        if (std.mem.eql(u8, formula, "N2")) break :blk 945.0;
        break :blk avg_bond_energy * @as(f64, @floatFromInt(est_bonds));
    };

    std.debug.print("\n{s}SACRED BOND ANALYSIS: {s}{s}\n", .{ GOLDEN, formula, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    // Atom counts
    std.debug.print("Atoms: ", .{});
    var it2 = composition.iterator();
    var first = true;
    while (it2.next()) |entry| {
        if (!first) std.debug.print(", ", .{});
        std.debug.print("{s}={d}", .{ entry.key_ptr.*, entry.value_ptr.* });
        first = false;
    }
    std.debug.print("  (total: {d})\n", .{total_atoms});
    std.debug.print("Total electrons: {d}\n", .{total_electrons});
    std.debug.print("Estimated bonds: {d}\n", .{est_bonds});
    std.debug.print("Bond energy (est): {d:.0} kJ/mol\n\n", .{bond_energy});

    // Sacred formula of bond energy
    const fit = sacred_formula.fitSacredFormula(bond_energy);
    var fbuf: [128]u8 = undefined;
    const fstr = sacred_formula.formatFormulaString(&fbuf, fit);
    std.debug.print("{s}Sacred Formula:{s} {s}  ({d:.3}%)\n\n", .{ MAGENTA, RESET, fstr, fit.error_pct });

    // Ternary molecular signature
    const trit_atoms: i8 = @intCast(@as(i32, @intCast(total_atoms % 3)));
    const trit_electrons: i8 = @intCast(@as(i32, @intCast(total_electrons % 3)));
    const trit_bonds: i8 = @intCast(@as(i32, @intCast(est_bonds % 3)));

    const trit_sym = [_][]const u8{ "0 (●)", "+1 (▲)", "-1 (▼)" };

    std.debug.print("{s}Ternary Molecular Signature:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Atoms:     {d} mod 3 = {s}\n", .{ total_atoms, trit_sym[@intCast(trit_atoms)] });
    std.debug.print("  Electrons: {d} mod 3 = {s}\n", .{ total_electrons, trit_sym[@intCast(trit_electrons)] });
    std.debug.print("  Bonds:     {d} mod 3 = {s}\n", .{ est_bonds, trit_sym[@intCast(trit_bonds)] });

    const trit_sum: i8 = trit_atoms + trit_electrons + trit_bonds;
    const balance_str: []const u8 = if (@mod(trit_sum, 3) == 0) "TRINITY BALANCED" else if (trit_sum > 0) "CREATIVE" else "ENTROPIC";
    std.debug.print("  Sum: {d} -> {s}{s}{s}\n\n", .{ trit_sum, GREEN, balance_str, RESET });

    // Coptic glyph
    const glyph_idx = total_atoms % 27;
    const glyph = gematria_mod.COPTIC_TABLE[glyph_idx];
    var utf8_buf: [4]u8 = undefined;
    const utf8_len = encodeUtf8(glyph.codepoint, &utf8_buf);
    const kingdom: []const u8 = if (glyph_idx < 9) "Matter" else if (glyph_idx < 18) "Energy" else "Info";

    std.debug.print("{s}Coptic Glyph:{s} {s}{s}{s} (value={d}, kingdom={s})\n", .{ CYAN, RESET, GOLDEN, utf8_buf[0..utf8_len], RESET, glyph.value, kingdom });
    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn showHelp() !void {
    std.debug.print(
        \\
        \\  TRI CHEMISTRY v8.0
        \\  ═══════════════════════════════════════════════════════
        \\
        \\  CORE
        \\    tri chem periodic                 Periodic table
        \\    tri chem element <sym|num>        Element info card
        \\    tri chem mass <formula>           Molar mass
        \\    tri chem formula <formula>        Composition analysis
        \\    tri chem balance <eq>             Balance chemical equation
        \\    tri chem search <term>            Find elements
        \\    tri chem group <1-18>             Elements by group
        \\    tri chem period <1-7>             Elements by period
        \\    tri chem block <s|p|d|f>          Elements by block
        \\
        \\  STOICHIOMETRY
        \\    tri chem moles <mass> <formula>   Mass to moles
        \\    tri chem atoms <moles> <formula>  Moles to atoms
        \\    tri chem limiting <m1> <f1> <m2> <f2> <prod>  Limiting reagent
        \\    tri chem yield <theo> <actual>    Percent yield
        \\
        \\  GAS LAWS
        \\    tri chem ideal-gas P= V= n= T=   Solve PV=nRT
        \\    tri chem stp <moles>              Volume at STP
        \\
        \\  SOLUTIONS
        \\    tri chem ph <conc|acid> [M]       pH calculation
        \\    tri chem poh <conc>               pOH calculation
        \\    tri chem molarity <n> <V_L>       M = n/V
        \\    tri chem dilution <C1> <V1> <V2>  C1V1 = C2V2
        \\
        \\  REDOX & ELECTROCHEMISTRY
        \\    tri chem redox <reaction>         Redox analysis + balancing
        \\    tri chem oxidation <formula>      Oxidation states
        \\    tri chem nernst <E0> <n> <Q>      Nernst equation
        \\
        \\  THERMOCHEMISTRY
        \\    tri chem gibbs <dH> <dS> <T>      dG = dH - TdS
        \\
        \\  NUCLEAR
        \\    tri chem half-life <N0> <t1/2> <t>  Radioactive decay
        \\
        \\  ACID-BASE
        \\    tri chem titration <Ca> <Va> <Cb> Equivalence point
        \\    tri chem buffer <pKa> <HA> <A->   Henderson-Hasselbalch
        \\
        \\  SOLUBILITY
        \\    tri chem ksp <salt> <Ksp>         Molar solubility
        \\
        \\  SACRED CHEMISTRY (v8.0)
        \\    tri chem sacred <formula>         Sacred formula decomposition
        \\    tri chem trinity <element>        Element's Trinity connections
        \\    tri chem phi [property]           Golden ratio patterns
        \\    tri chem bonds <formula>          Sacred bond analysis
        \\
        \\  tri chem help                       This message
        \\
    , .{});
}

// ============================================
// TESTS
// ============================================

test "stripCoefficient removes leading digits" {
    try std.testing.expectEqualStrings("Fe", stripCoefficient("2Fe"));
    try std.testing.expectEqualStrings("FeCl3", stripCoefficient("2FeCl3"));
    try std.testing.expectEqualStrings("Cl2", stripCoefficient("3Cl2"));
    // No coefficient — unchanged
    try std.testing.expectEqualStrings("NaCl", stripCoefficient("NaCl"));
    try std.testing.expectEqualStrings("H2O", stripCoefficient("H2O"));
}

test "oxidation state: pure element = 0" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("Fe", 1);
    try std.testing.expectEqual(@as(i8, 0), assignOxidationState("Fe", &m));
}

test "oxidation state: H2O" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("H", 2);
    try m.put("O", 1);
    try std.testing.expectEqual(@as(i8, 1), assignOxidationState("H", &m));
    try std.testing.expectEqual(@as(i8, -2), assignOxidationState("O", &m));
}

test "oxidation state: CuSO4" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("Cu", 1);
    try m.put("S", 1);
    try m.put("O", 4);
    try std.testing.expectEqual(@as(i8, 2), assignOxidationState("Cu", &m));
    try std.testing.expectEqual(@as(i8, 6), assignOxidationState("S", &m));
    try std.testing.expectEqual(@as(i8, -2), assignOxidationState("O", &m));
}

test "oxidation state: FeSO4" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("Fe", 1);
    try m.put("S", 1);
    try m.put("O", 4);
    try std.testing.expectEqual(@as(i8, 2), assignOxidationState("Fe", &m));
    try std.testing.expectEqual(@as(i8, 6), assignOxidationState("S", &m));
}

test "oxidation state: NaCl" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("Na", 1);
    try m.put("Cl", 1);
    try std.testing.expectEqual(@as(i8, 1), assignOxidationState("Na", &m));
    try std.testing.expectEqual(@as(i8, -1), assignOxidationState("Cl", &m));
}

test "oxidation state: Fe2O3" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("Fe", 2);
    try m.put("O", 3);
    try std.testing.expectEqual(@as(i8, 3), assignOxidationState("Fe", &m));
    try std.testing.expectEqual(@as(i8, -2), assignOxidationState("O", &m));
}

test "oxidation state: H2SO4" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("H", 2);
    try m.put("S", 1);
    try m.put("O", 4);
    try std.testing.expectEqual(@as(i8, 1), assignOxidationState("H", &m));
    try std.testing.expectEqual(@as(i8, 6), assignOxidationState("S", &m));
    try std.testing.expectEqual(@as(i8, -2), assignOxidationState("O", &m));
}

test "countFormulaElements" {
    const alloc = std.testing.allocator;
    var m = std.StringHashMap(u32).init(alloc);
    defer m.deinit();
    try m.put("Fe", 1);
    try m.put("S", 1);
    try m.put("O", 4);
    try std.testing.expectEqual(@as(u32, 3), countFormulaElements(&m));
}
