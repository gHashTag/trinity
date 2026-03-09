// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY MODULE v1.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// Main command dispatcher for tri geom commands.
// φ² + 1/φ² = 3 = TRINITY | Sierpinski dim = 1.585 = bits/trit
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const platonic = @import("platonic.zig");
const fractal = @import("fractal.zig");
const sacred = @import("sacred.zig");
const computational = @import("computational.zig");
const non_euclidean = @import("non_euclidean.zig");
const sacred_bridge = @import("sacred_bridge.zig");
const spiral = @import("spiral.zig");
const coptic_overlay = @import("coptic_overlay.zig");

/// Main entry point: tri geom <subcommand> [args...]
pub fn runGeometryCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        showHelp();
        return;
    }

    const command = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    // Sacred Geometry
    if (std.mem.eql(u8, command, "platonic") or std.mem.eql(u8, command, "plato")) {
        platonic.cmdPlatonic(sub_args);
    } else if (std.mem.eql(u8, command, "euler")) {
        platonic.cmdEuler(sub_args);
    } else if (std.mem.eql(u8, command, "vesica")) {
        sacred.cmdVesica(sub_args);
    } else if (std.mem.eql(u8, command, "pentagon") or std.mem.eql(u8, command, "pent")) {
        sacred.cmdPentagon(sub_args);
    } else if (std.mem.eql(u8, command, "flower")) {
        sacred.cmdFlower(sub_args);
    } else if (std.mem.eql(u8, command, "metatron")) {
        sacred.cmdMetatron(sub_args);
    }
    // Sacred Integration (v2.0)
    else if (std.mem.eql(u8, command, "sacred")) {
        sacred_bridge.cmdSacred();
    } else if (std.mem.eql(u8, command, "formula-predict") or std.mem.eql(u8, command, "fp")) {
        sacred_bridge.cmdFormulaPredict(sub_args);
    } else if (std.mem.eql(u8, command, "spiral")) {
        spiral.cmdSpiral(sub_args);
    } else if (std.mem.eql(u8, command, "coptic")) {
        coptic_overlay.cmdCoptic();
    } else if (std.mem.eql(u8, command, "trit3d-coptic") or std.mem.eql(u8, command, "lattice-coptic")) {
        coptic_overlay.cmdTrit3DCoptic();
    }
    // Fractal Geometry
    else if (std.mem.eql(u8, command, "sierpinski") or std.mem.eql(u8, command, "sierp")) {
        fractal.cmdSierpinski(sub_args);
    } else if (std.mem.eql(u8, command, "koch")) {
        fractal.cmdKoch(sub_args);
    } else if (std.mem.eql(u8, command, "cantor")) {
        fractal.cmdCantor(sub_args);
    } else if (std.mem.eql(u8, command, "fractal-dim") or std.mem.eql(u8, command, "dim")) {
        fractal.cmdFractalDim(sub_args);
    } else if (std.mem.eql(u8, command, "mandelbrot") or std.mem.eql(u8, command, "mandel")) {
        fractal.cmdMandelbrot();
    }
    // Computational Geometry
    else if (std.mem.eql(u8, command, "hull")) {
        try computational.cmdHull(allocator, sub_args);
    } else if (std.mem.eql(u8, command, "pip")) {
        computational.cmdPip(sub_args);
    } else if (std.mem.eql(u8, command, "area")) {
        computational.cmdArea(sub_args);
    } else if (std.mem.eql(u8, command, "volume") or std.mem.eql(u8, command, "vol")) {
        computational.cmdVolume(sub_args);
    } else if (std.mem.eql(u8, command, "trit3d") or std.mem.eql(u8, command, "lattice")) {
        computational.cmdTrit3D();
    }
    // Non-Euclidean Geometry
    else if (std.mem.eql(u8, command, "sphere")) {
        non_euclidean.cmdSphere(sub_args);
    } else if (std.mem.eql(u8, command, "hyper")) {
        non_euclidean.cmdHyper(sub_args);
    } else if (std.mem.eql(u8, command, "curvature") or std.mem.eql(u8, command, "curv")) {
        non_euclidean.cmdCurvature();
    }
    // Help
    else if (std.mem.eql(u8, command, "help")) {
        showHelp();
    } else {
        std.debug.print("Unknown geometry command: {s}\n\n", .{command});
        showHelp();
    }
}

fn showHelp() void {
    std.debug.print(
        \\
        \\  +====================================================================+
        \\  |  SACRED GEOMETRY v2.0                                              |
        \\  |  phi^2 + 1/phi^2 = 3 = TRINITY                                   |
        \\  |  Sierpinski dim = log(3)/log(2) = 1.585 = bits/trit               |
        \\  +====================================================================+
        \\
        \\  SACRED GEOMETRY
        \\  ----------------------------------------------------------------
        \\  tri geom platonic [name] [edge]     5 Platonic solids (V-E+F=2)
        \\  tri geom platonic verify            Verify Euler's formula for all 5
        \\  tri geom platonic coords <name>     Vertex coordinates (phi-based)
        \\  tri geom euler <V> <E> <F>          Verify Euler's polyhedron formula
        \\  tri geom vesica [radius]            Vesica Piscis (sqrt(3) genesis)
        \\  tri geom pentagon [side]            Regular pentagon (d/s = phi)
        \\  tri geom flower [rings]             Flower of Life circle counts
        \\  tri geom metatron [--sacred]        Metatron's Cube (all 5 solids)
        \\
        \\  SACRED INTEGRATION (v2.0)
        \\  ----------------------------------------------------------------
        \\  tri geom sacred                     All constants as Sacred Formulas
        \\  tri geom formula-predict <val>      Fit any value to V=n*3^k*pi^m*phi^p*e^q
        \\  tri geom spiral [turns] [scale]     Golden logarithmic spiral (r=a*phi^(2t/pi))
        \\  tri geom coptic                     27 Coptic glyphs on ternary lattice
        \\  tri geom trit3d-coptic              27-point lattice with glyph labels
        \\
        \\  FRACTAL GEOMETRY
        \\  ----------------------------------------------------------------
        \\  tri geom sierpinski [depth]         Sierpinski triangle (dim=bits/trit!)
        \\  tri geom koch [depth]               Koch snowflake (dim=log4/log3)
        \\  tri geom cantor [depth]             Cantor set (ternary fractal)
        \\  tri geom fractal-dim <N> <r>        Hausdorff dimension: D=log(N)/log(r)
        \\  tri geom mandelbrot                 ASCII Mandelbrot set
        \\
        \\  COMPUTATIONAL GEOMETRY
        \\  ----------------------------------------------------------------
        \\  tri geom hull <x,y> <x,y> ...      Convex hull (orientation=ternary!)
        \\  tri geom pip <x> <y> <polygon...>   Point-in-polygon (result=ternary)
        \\  tri geom area <x,y> <x,y> ...      Polygon area (Shoelace formula)
        \\  tri geom volume <shape> <params>    3D volume (sphere/cyl/cone/box/torus)
        \\  tri geom trit3d                     27-point ternary 3D lattice
        \\
        \\  NON-EUCLIDEAN GEOMETRY
        \\  ----------------------------------------------------------------
        \\  tri geom sphere distance <coords>   Great circle distance (haversine)
        \\  tri geom sphere triangle <A> <B> <C> Spherical triangle (angle excess)
        \\  tri geom hyper triangle <A> <B> <C>  Hyperbolic triangle (angle defect)
        \\  tri geom curvature                  K = {{-1, 0, +1}} = ternary!
        \\
        \\  tri geom help                       This message
        \\
        \\  ALIASES: geo, geometry, fp (formula-predict), lattice-coptic
        \\
        \\  +====================================================================+
        \\
    , .{});
}
