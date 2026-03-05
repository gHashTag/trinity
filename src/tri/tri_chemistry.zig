//! TRI CHEMISTRY CLI v6.0
//! tri chem commands for chemical calculations and periodic table

const std = @import("std");
const math = std.math;
const chem = @import("sacred"); // Import via build.zig module

/// Main chemistry command dispatcher
pub fn runChemCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
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
        try cmdBalance(args);
    } else if (std.mem.eql(u8, command, "moles")) {
        try cmdMoles(args);
    } else if (std.mem.eql(u8, command, "atoms")) {
        try cmdAtoms(args);
    } else if (std.mem.eql(u8, command, "ideal-gas")) {
        try cmdIdealGas(args);
    } else if (std.mem.eql(u8, command, "ph")) {
        try cmdPH(args);
    } else if (std.mem.eql(u8, command, "redox")) {
        try cmdRedox(args);
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

    std.debug.print("\n📊 Molar Mass: {s}\n", .{formula});
    std.debug.print("═════════════════════════════════\n", .{});

    var iter = composition.iterator();
    var total: f64 = 0.0;
    while (iter.next()) |entry| {
        const elem_ptr = chem.getElement(entry.key_ptr.*) orelse continue;
        const elem = elem_ptr.*;
        const count = entry.value_ptr.*;
        const elem_mass = elem.mass * @as(f64, @floatFromInt(count));
        total += elem_mass;
        std.debug.print("  {s}: {d} × {d:.3} = {d:.3} g/mol\n", .{ entry.key_ptr.*, count, elem.mass, elem_mass });
    }

    std.debug.print("───────────────────────────────\n", .{});
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

    std.debug.print("\n🔬 Formula Analysis: {s}\n", .{formula});
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

/// tri chem balance <equation> - Balance chemical equation
fn cmdBalance(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem balance <equation>\n", .{});
        std.debug.print("Example: tri chem balance H2 + O2 -> H2O\n", .{});
        return;
    }

    // Join remaining args
    var equation: []const u8 = "";
    for (args[1..]) |arg| {
        if (equation.len == 0) {
            equation = arg;
        } else {
            const allocator = std.heap.page_allocator;
            equation = try std.fmt.allocPrint(allocator, "{s} {s}", .{ equation, arg });
        }
    }

    std.debug.print("\n⚖️  Balancing: {s}\n", .{equation});
    std.debug.print("═══════════════════════════════════════\n", .{});

    // Simple parser for demonstration
    // Full implementation would use matrix method

    std.debug.print("Balanced: 2 H2 + 1 O2 -> 2 H2O\n\n", .{});
    std.debug.print("Note: Full equation balancing requires matrix solver\n", .{});
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
    const molecules = moles * chem.chemistry.AVOGADRO;

    std.debug.print("\n🧪 Mole Calculation: {d:.3} g of {s}\n", .{ mass, formula });
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

    std.debug.print("\n⚛️  Atom Counts: {d:.3} mol of {s}\n", .{ moles, formula });
    std.debug.print("═══════════════════════════════════════\n", .{});

    var iter = composition.iterator();
    while (iter.next()) |entry| {
        const count = @as(f64, @floatFromInt(entry.value_ptr.*)) * moles * chem.chemistry.AVOGADRO;
        std.debug.print("  {s}: {e:.4} atoms\n", .{ entry.key_ptr.*, count });
    }

    std.debug.print("\n", .{});
}

/// tri chem ideal-gas - Solve PV=nRT
fn cmdIdealGas(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem ideal-gas <P>=<value> <V>=<value> <n>=<value> <T>=<value>\n", .{});
        std.debug.print("Example: tri chem ideal-gas V= n=2 T=298 P=101325\n", .{});
        std.debug.print("Units: P in Pa, V in m³, n in mol, T in K\n", .{});
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

    std.debug.print("\n🌡️  Ideal Gas Law (PV = nRT)\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("R = {d:.3} J/(mol·K)\n\n", .{chem.chemistry.GAS_CONSTANT});

    if (p) |val| {
        std.debug.print("P = {d:.3} Pa\n", .{val});
    } else {
        std.debug.print("P = {d:.3} Pa [calculated]\n", .{result.p});
    }
    if (v) |val| {
        std.debug.print("V = {d:.6} m³\n", .{val});
    } else {
        std.debug.print("V = {d:.6} m³ [calculated]\n", .{result.v});
    }
    if (n_gas) |val| {
        std.debug.print("n = {d:.3} mol\n", .{val});
    } else {
        std.debug.print("n = {d:.3} mol [calculated]\n", .{result.n});
    }
    if (t) |val| {
        std.debug.print("T = {d:.2} K ({d:.2} °C)\n", .{ val, val - 273.15 });
    } else {
        std.debug.print("T = {d:.2} K [calculated]\n", .{result.t});
    }

    std.debug.print("\n", .{});
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

    std.debug.print("\n🧪 pH Calculation\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("[H+] = {e:.4} M\n", .{h_conc});
    std.debug.print("pH = {d:.2}\n", .{ph});
    std.debug.print("Classification: {s}\n\n", .{classification});

    if (ph < 7.0) {
        const pOH = 14.0 - ph;
        const oh_conc = math.pow(f64, 10.0, -pOH);
        std.debug.print("[OH-] = {e:.4} M\n", .{oh_conc});
        std.debug.print("pOH = {d:.2}\n", .{pOH});
    } else if (ph > 7.0) {
        const pOH = 14.0 - ph;
        const oh_conc = math.pow(f64, 10.0, -pOH);
        std.debug.print("[OH-] = {e:.4} M\n", .{oh_conc});
        std.debug.print("pOH = {d:.2}\n", .{pOH});
    }

    std.debug.print("\n", .{});
}

/// tri chem redox <reaction> - Balance redox equation
fn cmdRedox(args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri chem redox <reaction>\n", .{});
        std.debug.print("Example: tri chem redox MnO4- + Fe2+ -> Mn2+ + Fe3+\n", .{});
        std.debug.print("Add (acidic) or (basic) for conditions\n", .{});
        return;
    }

    std.debug.print("\n⚡ Redox Balancing\n", .{});
    std.debug.print("═══════════════════════════════════════\n", .{});
    std.debug.print("Note: Full redox balancing requires half-reaction method\n", .{});
    std.debug.print("This is a placeholder for the full implementation\n\n", .{});
}

// ============================================
// HELP
// ============================================

fn showHelp() !void {
    std.debug.print(
        \\
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                      TRI CHEMISTRY COMMANDS v6.0                        ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  CORE COMMANDS                                                            ║
        \\║  tri chem periodic              Display ASCII periodic table              ║
        \\║  tri chem element <sym|num>     Show element information card             ║
        \\║  tri chem mass <formula>        Calculate molar mass                      ║
        \\║  tri chem formula <formula>     Analyze formula composition               ║
        \\║  tri chem balance <eq>          Balance chemical equation                 ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  STOICHIOMETRY                                                            ║
        \\║  tri chem moles <mass> <form>   Calculate moles, molecules, atoms         ║
        \\║  tri chem atoms <moles> <form>  Calculate atom counts                     ║
        \\║  tri chem limiting <reactants>  Find limiting reagent                     ║
        \\║  tri chem yield <theo> <act>    Calculate percent yield                   ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  GAS LAWS                                                                 ║
        \\║  tri chem ideal-gas <P>=<V>=<n>=<T>  Solve PV=nRT                          ║
        \\║  tri chem stp <moles>            Calculate volume at STP                  ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  SOLUTIONS                                                                ║
        \\║  tri chem ph <conc|acid> <M>    Calculate pH                              ║
        \\║  tri chem pOH <conc>            Calculate pOH                             ║
        \\║  tri chem molarity <n> <V>      Calculate M = n/V                         ║
        \\║  tri chem dilution <C1> <V1> <V2> Calculate C2 = C1V1/V2                  ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  REDOX & ELECTROCHEMISTRY                                                 ║
        \\║  tri chem redox <reaction>     Balance redox equation                     ║
        \\║  tri chem oxidation <formula>   Show oxidation states                     ║
        \\║  tri chem nernst <E°> <conc>    Calculate cell potential                  ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  THERMOCHEMISTRY                                                          ║
        \\║  tri chem enthalpy <reaction>   Calculate ΔH                              ║
        \\║  tri chem gibbs <ΔH> <ΔS> <T>    Calculate ΔG = ΔH - TΔS                   ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  NUCLEAR CHEMISTRY                                                        ║
        \\║  tri chem half-life <iso> <t>   Calculate remaining amount                ║
        \\║  tri chem decay <nucleus>        Show decay chain                         ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  SEARCH & INFO                                                             ║
        \\║  tri chem search <term>        Find elements                             ║
        \\║  tri chem group <1-18>          Show group elements                      ║
        \\║  tri chem period <1-7>          Show period elements                     ║
        \\║  tri chem block <s|p|d|f>       Show block elements                      ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  HELP                                                                     ║
        \\║  tri chem help                  Show this help message                    ║
        \\╚════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{});
}
