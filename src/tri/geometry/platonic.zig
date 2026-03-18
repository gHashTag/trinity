// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY — PLATONIC SOLIDS
// ═══════════════════════════════════════════════════════════════════════════════
// 5 Platonic solids: Tetrahedron, Cube, Octahedron, Dodecahedron, Icosahedron
// Euler's polyhedron formula: V - E + F = 2
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom platonic [name] [edge]
pub fn cmdPlatonic(args: []const []const u8) void {
    if (args.len == 0) {
        // Show all solids with default edge=1
        printAllSolids(1.0);
        return;
    }

    const first = args[0];

    // Check if first arg is "verify"
    if (std.mem.eql(u8, first, "verify")) {
        printEulerVerification();
        return;
    }

    // Check if first arg is "coords"
    if (std.mem.eql(u8, first, "coords")) {
        if (args.len > 1) {
            printCoords(args[1]);
        } else {
            printCoords("icosahedron");
        }
        return;
    }

    // Try to parse as number (edge length for all solids)
    if (std.fmt.parseFloat(f64, first)) |edge| {
        printAllSolids(edge);
        return;
    } else |_| {}

    // Must be a solid name
    const edge: f64 = if (args.len > 1)
        std.fmt.parseFloat(f64, args[1]) catch 1.0
    else
        1.0;

    if (findSolid(first)) |solid| {
        printSolidCard(solid, edge);
    } else {
        std.debug.print("Unknown solid: {s}\n", .{first});
        std.debug.print("Available: tetrahedron, cube, octahedron, dodecahedron, icosahedron\n", .{});
    }
}

/// tri geom euler <V> <E> <F>
pub fn cmdEuler(args: []const []const u8) void {
    if (args.len < 3) {
        std.debug.print("Usage: tri geom euler <V> <E> <F>\n", .{});
        std.debug.print("  Verify Euler's polyhedron formula: V - E + F = 2\n", .{});
        std.debug.print("  Example: tri geom euler 4 6 4  (tetrahedron)\n", .{});
        return;
    }

    const v = std.fmt.parseInt(i32, args[0], 10) catch {
        std.debug.print("Invalid V: {s}\n", .{args[0]});
        return;
    };
    const e = std.fmt.parseInt(i32, args[1], 10) catch {
        std.debug.print("Invalid E: {s}\n", .{args[1]});
        return;
    };
    const f = std.fmt.parseInt(i32, args[2], 10) catch {
        std.debug.print("Invalid F: {s}\n", .{args[2]});
        return;
    };

    const chi = v - e + f;

    fmt.boxHeader("EULER'S POLYHEDRON FORMULA");
    std.debug.print("\n", .{});
    fmt.labelInt("Vertices (V):", v);
    fmt.labelInt("Edges (E):", e);
    fmt.labelInt("Faces (F):", f);
    fmt.separator();
    fmt.labelInt("V - E + F:", chi);
    fmt.verified("Euler check (=2):", chi == 2);

    if (chi == 2) {
        std.debug.print("\n  {s}Topologically equivalent to a sphere (genus 0){s}\n", .{ fmt.GRAY, fmt.RESET });
    } else if (chi == 0) {
        std.debug.print("\n  {s}Topologically equivalent to a torus (genus 1){s}\n", .{ fmt.GRAY, fmt.RESET });
    } else {
        const genus = @divTrunc(2 - chi, 2);
        std.debug.print("\n  {s}Euler characteristic = {d}, genus = {d}{s}\n", .{ fmt.GRAY, chi, genus, fmt.RESET });
    }
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISPLAY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn printAllSolids(edge: f64) void {
    fmt.boxHeader("PLATONIC SOLIDS — 5 Perfect Forms");
    std.debug.print("  {s}Edge length: {d:.4}{s}\n", .{ fmt.GRAY, edge, fmt.RESET });
    std.debug.print("\n", .{});

    // Table header
    std.debug.print("  {s}{s: <14} {s: >3} {s: >3} {s: >3} {s: >6} {s: >12} {s: >12} {s: >10}{s}\n", .{
        fmt.GOLD, "Solid", "F", "V", "E", "V-E+F", "Area", "Volume", "Dihedral", fmt.RESET,
    });
    std.debug.print("  {s}------------- --- --- --- ------ ------------ ------------ ----------{s}\n", .{ fmt.GRAY, fmt.RESET });

    for (&mod.PLATONIC_SOLIDS) |solid| {
        const chi = @as(i32, @intCast(solid.vertices)) - @as(i32, @intCast(solid.edges)) + @as(i32, @intCast(solid.faces));
        const ok: []const u8 = if (chi == 2) "  2" else " !!";
        std.debug.print("  {s: <14} {d: >3} {d: >3} {d: >3} {s: >6} {d: >12.4} {d: >12.4} {d: >9.2}{s}deg{s}\n", .{
            solid.name,
            solid.faces,
            solid.vertices,
            solid.edges,
            ok,
            solid.surfaceArea(edge),
            solid.volume(edge),
            solid.dihedralAngleDeg(),
            fmt.GRAY,
            fmt.RESET,
        });
    }

    std.debug.print("\n  {s}Dual pairs:{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("    Tetrahedron  <->  self-dual\n", .{});
    std.debug.print("    Cube         <->  Octahedron\n", .{});
    std.debug.print("    Dodecahedron <->  Icosahedron  {s}(both phi-connected){s}\n", .{ fmt.CYAN, fmt.RESET });

    std.debug.print("\n  {s}phi connections:{s}\n", .{ fmt.GOLD, fmt.RESET });
    for (&mod.PLATONIC_SOLIDS) |solid| {
        if (solid.phi_connection) |conn| {
            std.debug.print("    {s}: {s}\n", .{ solid.name, conn });
        }
    }

    fmt.boxFooter();
}

fn printSolidCard(solid: mod.PlatonicSolid, edge: f64) void {
    var buf: [80]u8 = undefined;
    const title = std.fmt.bufPrint(&buf, "{s} — Platonic Solid", .{solid.name}) catch "Platonic Solid";
    fmt.boxHeader(title);
    std.debug.print("\n", .{});

    fmt.labelStr("Name:", solid.name);
    fmt.labelStr("Schlafli Symbol:", solid.schlafli);
    fmt.labelStr("Face Type:", solid.face_type);
    fmt.labelStr("Element:", solid.element);
    fmt.separator();

    fmt.labelInt("Faces (F):", @intCast(solid.faces));
    fmt.labelInt("Vertices (V):", @intCast(solid.vertices));
    fmt.labelInt("Edges (E):", @intCast(solid.edges));

    const chi = @as(i32, @intCast(solid.vertices)) - @as(i32, @intCast(solid.edges)) + @as(i32, @intCast(solid.faces));
    fmt.labelInt("V - E + F:", chi);
    fmt.verified("Euler (=2):", chi == 2);
    fmt.separator();

    fmt.labelFloat("Edge Length:", edge);
    fmt.labelFloatUnit("Surface Area:", solid.surfaceArea(edge), "units\xc2\xb2");
    fmt.labelFloatUnit("Volume:", solid.volume(edge), "units\xc2\xb3");
    fmt.labelFloatUnit("Circumradius:", solid.circumradius(edge), "units");
    fmt.labelFloatUnit("Inradius:", solid.inradius(edge), "units");
    fmt.labelFloatUnit("Dihedral Angle:", solid.dihedralAngleDeg(), "deg");

    if (solid.phi_connection) |conn| {
        fmt.separator();
        std.debug.print("  {s}phi:{s} {s}\n", .{ fmt.GOLD, fmt.RESET, conn });
    }

    fmt.boxFooter();
}

fn printEulerVerification() void {
    fmt.boxHeader("EULER FORMULA VERIFICATION: V - E + F = 2");
    std.debug.print("\n", .{});

    for (&mod.PLATONIC_SOLIDS) |solid| {
        const v: i32 = @intCast(solid.vertices);
        const e: i32 = @intCast(solid.edges);
        const f: i32 = @intCast(solid.faces);
        const chi = v - e + f;
        std.debug.print("  {s: <14} {d} - {d} + {d} = {d}  ", .{ solid.name, v, e, f, chi });
        if (chi == 2) {
            std.debug.print("{s}VERIFIED{s}\n", .{ fmt.GREEN, fmt.RESET });
        } else {
            std.debug.print("{s}FAILED{s}\n", .{ fmt.RED, fmt.RESET });
        }
    }

    std.debug.print("\n  {s}Euler characteristic chi = 2 for all convex polyhedra{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}Proof: Cauchy (1813) — flatten, triangulate, remove boundary triangles{s}\n", .{ fmt.GRAY, fmt.RESET });
    fmt.boxFooter();
}

fn printCoords(name: []const u8) void {
    const lower = name;
    if (std.mem.startsWith(u8, lower, "ico") or std.mem.eql(u8, lower, "icosahedron")) {
        fmt.boxHeader("ICOSAHEDRON VERTEX COORDINATES (unit edge)");
        std.debug.print("\n  {s}3 mutually perpendicular golden rectangles:{s}\n\n", .{ fmt.CYAN, fmt.RESET });
        const coords = [_][3][]const u8{
            .{ "(0, +1, +phi)", "(0, +1, -phi)", "(0, -1, +phi)" },
            .{ "(0, -1, -phi)", "(+1, +phi, 0)", "(+1, -phi, 0)" },
            .{ "(-1, +phi, 0)", "(-1, -phi, 0)", "(+phi, 0, +1)" },
            .{ "(+phi, 0, -1)", "(-phi, 0, +1)", "(-phi, 0, -1)" },
        };
        for (coords) |row| {
            std.debug.print("  ", .{});
            for (row) |c| {
                std.debug.print("{s: <20}", .{c});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n  {s}phi = {d:.10}{s}\n", .{ fmt.GOLD, mod.PHI, fmt.RESET });
        std.debug.print("  {s}Golden rectangles define icosahedral symmetry{s}\n", .{ fmt.GRAY, fmt.RESET });
    } else if (std.mem.startsWith(u8, lower, "dodec") or std.mem.eql(u8, lower, "dodecahedron")) {
        fmt.boxHeader("DODECAHEDRON VERTEX COORDINATES (unit edge)");
        std.debug.print("\n  {s}8 cube vertices + 12 phi-scaled vertices:{s}\n\n", .{ fmt.CYAN, fmt.RESET });
        std.debug.print("  Cube:     (+/-1, +/-1, +/-1)         [8 vertices]\n", .{});
        std.debug.print("  Rect XY:  (0, +/-1/phi, +/-phi)      [4 vertices]\n", .{});
        std.debug.print("  Rect YZ:  (+/-1/phi, +/-phi, 0)      [4 vertices]\n", .{});
        std.debug.print("  Rect XZ:  (+/-phi, 0, +/-1/phi)      [4 vertices]\n", .{});
        std.debug.print("\n  {s}Total: 8 + 4 + 4 + 4 = 20 vertices{s}\n", .{ fmt.GOLD, fmt.RESET });
        std.debug.print("  {s}phi = {d:.10}, 1/phi = {d:.10}{s}\n", .{ fmt.GRAY, mod.PHI, mod.INV_PHI, fmt.RESET });
    } else {
        std.debug.print("Coordinates available for: icosahedron, dodecahedron\n", .{});
        std.debug.print("  (phi-connected solids have the most interesting coordinates)\n", .{});
    }
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn findSolid(name: []const u8) ?mod.PlatonicSolid {
    for (&mod.PLATONIC_SOLIDS) |solid| {
        if (std.ascii.startsWithIgnoreCase(solid.name, name)) {
            return solid;
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "findSolid matches prefix" {
    const cube = findSolid("cube");
    try std.testing.expect(cube != null);
    try std.testing.expectEqualStrings("Cube", cube.?.name);

    const ico = findSolid("ico");
    try std.testing.expect(ico != null);
    try std.testing.expectEqualStrings("Icosahedron", ico.?.name);
}

test "all solids have euler = 2" {
    for (&mod.PLATONIC_SOLIDS) |solid| {
        try std.testing.expect(solid.eulerCheck());
    }
}
