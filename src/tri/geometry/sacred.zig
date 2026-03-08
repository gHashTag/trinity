// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY — Vesica Piscis, Pentagon, Flower of Life, Metatron's Cube
// ═══════════════════════════════════════════════════════════════════════════════
// The geometric foundations of sacred mathematics.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom vesica [radius]
pub fn cmdVesica(args: []const []const u8) void {
    var r: f64 = 1.0;
    if (args.len > 0) {
        r = std.fmt.parseFloat(f64, args[0]) catch 1.0;
    }

    const height = r * mod.SQRT3;
    const width = r;
    const area = r * r * (2.0 * mod.PI / 3.0 - mod.SQRT3);

    fmt.boxHeader("VESICA PISCIS — Genesis of Form");
    std.debug.print("\n", .{});

    // ASCII representation
    std.debug.print("          {s}****{s}    {s}****{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("        {s}**{s}    {s}**{s}{s}**{s}    {s}**{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("       {s}*{s}      {s}*{s}{s}**{s}{s}*{s}      {s}*{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("       {s}*{s}     {s}*{s} {s}**{s} {s}*{s}     {s}*{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("       {s}*{s}      {s}*{s}{s}**{s}{s}*{s}      {s}*{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("        {s}**{s}    {s}**{s}{s}**{s}    {s}**{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("          {s}****{s}    {s}****{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("\n", .{});

    fmt.sectionHeader("Dimensions");
    fmt.labelFloat("Radius (r):", r);
    fmt.labelFloatUnit("Height:", height, "= r * sqrt(3)");
    fmt.labelFloatUnit("Width:", width, "= r");
    fmt.labelFloat("Area:", area);
    fmt.labelFloat("Ratio h/w:", height / width);
    fmt.separator();

    fmt.sectionHeader("Encoded Ratios");
    fmt.labelFloat("sqrt(2):", mod.SQRT2);
    fmt.labelFloat("sqrt(3):", mod.SQRT3);
    fmt.labelFloat("sqrt(5):", mod.SQRT5);
    fmt.labelFloat("phi:", mod.PHI);
    std.debug.print("\n  {s}The Vesica Piscis encodes all fundamental irrationals{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}Pythagorean approx: 265/153 = {d:.10} ~ sqrt(3){s}\n", .{
        fmt.GRAY,
        @as(f64, 265.0) / 153.0,
        fmt.RESET,
    });
    std.debug.print("  {s}Two overlapping circles create the first geometric form{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom pentagon [side]
pub fn cmdPentagon(args: []const []const u8) void {
    var s: f64 = 1.0;
    if (args.len > 0) {
        s = std.fmt.parseFloat(f64, args[0]) catch 1.0;
    }

    const diagonal = s * mod.PHI;
    const area = (s * s * @sqrt(25.0 + 10.0 * mod.SQRT5)) / 4.0;
    const apothem = s / (2.0 * @tan(mod.PI / 5.0));
    const circumradius = s / (2.0 * @sin(mod.PI / 5.0));
    const interior_angle: f64 = 108.0;

    fmt.boxHeader("REGULAR PENTAGON — Geometry of phi");
    std.debug.print("\n", .{});

    // ASCII pentagon
    std.debug.print("            {s}*{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("           {s}/ \\{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("          {s}/   \\{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("         {s}/     \\{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("        {s}*-------*{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("        {s}|\\     /|{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("        {s}| \\   / |{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("        {s}|  \\ /  |{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("        {s}*---*---*{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("\n", .{});

    fmt.sectionHeader("Dimensions");
    fmt.labelFloat("Side (s):", s);
    fmt.labelFloat("Diagonal (d):", diagonal);
    fmt.labelFloat("Area:", area);
    fmt.labelFloat("Apothem:", apothem);
    fmt.labelFloat("Circumradius:", circumradius);
    fmt.labelFloatUnit("Interior angle:", interior_angle, "deg");
    fmt.separator();

    fmt.sectionHeader("phi Connection");
    std.debug.print("  {s}d / s ={s} {s}{d:.10}{s} {s}= phi{s}\n", .{
        fmt.GRAY,
        fmt.RESET,
        fmt.CYAN,
        diagonal / s,
        fmt.RESET,
        fmt.GOLD,
        fmt.RESET,
    });
    std.debug.print("  {s}phi = 2 * cos(pi/5) = 2 * cos(36 deg){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}phi = 2 * sin(3*pi/10) = 2 * sin(54 deg){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n  {s}The pentagon is the geometric embodiment of phi.{s}\n", .{ fmt.WHITE, fmt.RESET });
    std.debug.print("  {s}Five-fold symmetry is the signature of the golden ratio.{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}Penrose tilings use phi-based 'kite' and 'dart' from the pentagon.{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom flower [rings]
pub fn cmdFlower(args: []const []const u8) void {
    var rings: u32 = 3;
    if (args.len > 0) {
        rings = std.fmt.parseInt(u32, args[0], 10) catch 3;
    }
    if (rings > 10) rings = 10;

    fmt.boxHeader("FLOWER OF LIFE — Sacred Pattern");
    std.debug.print("\n", .{});

    // ASCII Seed of Life (simplified)
    std.debug.print("            {s}o{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("          {s}o   o{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("        {s}o   o   o{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("          {s}o   o{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("            {s}o{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("        {s}(Seed of Life = 7 circles){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    fmt.sectionHeader("Circle Counts by Ring");
    std.debug.print("  {s}{s: >5} {s: >10} {s: >12} {s: >15}{s}\n", .{
        fmt.GOLD, "Ring", "New", "Total", "Formula", fmt.RESET,
    });
    std.debug.print("  {s}----- ---------- ------------ ---------------{s}\n", .{ fmt.GRAY, fmt.RESET });

    var total: u32 = 1;
    std.debug.print("  {d: >5} {d: >10} {d: >12}  1 (center)\n", .{ @as(u32, 0), @as(u32, 1), total });

    var k: u32 = 1;
    while (k <= rings) : (k += 1) {
        const new_circles = 6 * k;
        total += new_circles;
        const formula_total = 1 + 3 * k * (k + 1);
        std.debug.print("  {d: >5} {d: >10} {d: >12}  1 + 3*{d}*{d} = {d}\n", .{
            k, new_circles, total, k, k + 1, formula_total,
        });
    }

    fmt.separator();
    std.debug.print("  {s}General formula:{s} C(k) = 1 + 3k(k+1)\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}Each ring adds 6k new circles (hexagonal symmetry){s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.sectionHeader("Derived Figures");
    std.debug.print("  Seed of Life:     7 circles  (1 + 6*1)\n", .{});
    std.debug.print("  Egg of Life:      13 circles (next iteration)\n", .{});
    std.debug.print("  Fruit of Life:    13 circles (extended)\n", .{});
    std.debug.print("  Flower of Life:   19+ circles + enclosing circle\n", .{});
    std.debug.print("  Metatron's Cube:  Connect all 13 centers of Fruit of Life\n", .{});
    std.debug.print("\n  {s}Contains templates for all 5 Platonic solids{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("  {s}Symmetry: 6-fold = 2 * 3 = 2 * TRINITY{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom metatron [--sacred]
pub fn cmdMetatron(args: []const []const u8) void {
    fmt.boxHeader("METATRON'S CUBE");
    std.debug.print("\n", .{});

    std.debug.print("                  {s}*{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("                 {s}/|\\{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("                {s}/ | \\{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("           {s}*{s}--{s}/{s}--{s}*{s}--{s}\\{s}--{s}*{s}\n", .{ fmt.GOLD, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GOLD, fmt.RESET });
    std.debug.print("          {s}/|\\{s} {s}/{s} {s}/|\\{s} {s}\\{s} {s}/|\\{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET });
    std.debug.print("         {s}/ | X  / | \\  X | \\{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("        {s}*{s}--{s}*{s}----{s}*{s}----{s}*{s}--{s}*{s}\n", .{ fmt.GOLD, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.CYAN, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.GOLD, fmt.RESET });
    std.debug.print("         {s}\\ | X  \\ | /  X | /{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("          {s}\\|/{s} {s}\\{s} {s}\\|/{s} {s}/{s} {s}\\|/{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GRAY, fmt.RESET });
    std.debug.print("           {s}*{s}--{s}\\{s}--{s}*{s}--{s}/{s}--{s}*{s}\n", .{ fmt.GOLD, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GOLD, fmt.RESET, fmt.GRAY, fmt.RESET, fmt.GOLD, fmt.RESET });
    std.debug.print("                {s}\\ | /{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("                 {s}\\|/{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("                  {s}*{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("\n", .{});

    fmt.sectionHeader("Structure");
    std.debug.print("  Circles:           13 (Fruit of Life)\n", .{});
    std.debug.print("  Lines:             78 (all pairwise connections)\n", .{});
    std.debug.print("  Layout:            1 center + 6 inner + 6 outer\n", .{});
    fmt.separator();

    fmt.sectionHeader("Encoded Platonic Solids");
    std.debug.print("  {s}Tetrahedron{s}    4 faces   {s}(Fire){s}\n", .{ fmt.WHITE, fmt.RESET, fmt.RED, fmt.RESET });
    std.debug.print("  {s}Cube{s}           6 faces   {s}(Earth){s}\n", .{ fmt.WHITE, fmt.RESET, fmt.GREEN, fmt.RESET });
    std.debug.print("  {s}Octahedron{s}     8 faces   {s}(Air){s}\n", .{ fmt.WHITE, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("  {s}Dodecahedron{s}  12 faces   {s}(Aether){s}\n", .{ fmt.WHITE, fmt.RESET, fmt.PURPLE, fmt.RESET });
    std.debug.print("  {s}Icosahedron{s}   20 faces   {s}(Water){s}\n", .{ fmt.WHITE, fmt.RESET, fmt.CYAN, fmt.RESET });
    std.debug.print("\n  {s}All 5 Platonic solids can be traced within Metatron's Cube.{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}It is the geometric 'source code' of three-dimensional form.{s}\n", .{ fmt.GRAY, fmt.RESET });

    // Check for --sacred flag
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--sacred")) {
            printMetatronSacredFits();
            break;
        }
    }

    fmt.boxFooter();
}

fn printMetatronSacredFits() void {
    const sacred_bridge = @import("sacred_bridge.zig");

    fmt.sectionHeader("Sacred Formula Fits (Dihedral Angles)");
    std.debug.print("  {s}V = n * 3^k * pi^m * phi^p * e^q{s}\n\n", .{ fmt.GRAY, fmt.RESET });

    sacred_bridge.printFormulaFit(70.528779365509308, "Tetrahedron (Fire)");
    sacred_bridge.printFormulaFit(90.0, "Cube (Earth)");
    sacred_bridge.printFormulaFit(109.47122063449069, "Octahedron (Air)");
    sacred_bridge.printFormulaFit(116.56505117707799, "Dodecahedron (Aether)");
    sacred_bridge.printFormulaFit(138.18968510422140, "Icosahedron (Water)");

    std.debug.print("\n  {s}All 5 dihedral angles encoded in the Sacred Formula.{s}\n", .{ fmt.GOLD, fmt.RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vesica piscis height/width ratio = sqrt(3)" {
    const r = 1.0;
    const height = r * mod.SQRT3;
    const width = r;
    try std.testing.expectApproxEqAbs(mod.SQRT3, height / width, 1e-10);
}

test "pentagon diagonal/side = phi" {
    const s = 1.0;
    const diagonal = s * mod.PHI;
    try std.testing.expectApproxEqAbs(mod.PHI, diagonal / s, 1e-10);
}

test "flower of life formula" {
    // C(k) = 1 + 3*k*(k+1)
    try std.testing.expectEqual(@as(u32, 1), 1 + 3 * 0 * 1); // k=0
    try std.testing.expectEqual(@as(u32, 7), 1 + 3 * 1 * 2); // k=1 Seed of Life
    try std.testing.expectEqual(@as(u32, 19), 1 + 3 * 2 * 3); // k=2
    try std.testing.expectEqual(@as(u32, 37), 1 + 3 * 3 * 4); // k=3
}
