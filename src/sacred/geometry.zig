// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY & FRACTALS — Platonic Solids, Archimedean Solids, Fractals v6.0
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const sacred_const = @import("const.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PLATONIC SOLIDS — 5 regular convex polyhedra
// ═══════════════════════════════════════════════════════════════════════════════

pub const PlatonicSolid = struct {
    name: []const u8,
    faces: u32,
    vertices: u32,
    edges: u32,
    face_type: []const u8,
    faces_per_vertex: u32,
    volume: f64, // at edge_length = 1
    surface_area: f64, // at edge_length = 1
    face_angle: f64, // interior angle of face (degrees)
    dihedral_angle: f64, // angle between faces (degrees)
    circumscribed_radius: f64, // R (circumsphere)
    inscribed_radius: f64, // r (insphere)
    midradius: f64, // ρ (midradius, edge-tangent)
    symmetry_group: []const u8,

    /// Calculate volume for given edge length a
    pub fn volumeAt(self: *const PlatonicSolid, a: f64) f64 {
        return self.volume * a * a * a;
    }

    /// Calculate surface area for given edge length a
    pub fn surfaceAreaAt(self: *const PlatonicSolid, a: f64) f64 {
        return self.surface_area * a * a;
    }
};

pub const PLATONIC_SOLIDS = [5]PlatonicSolid{
    .{
        .name = "Tetrahedron",
        .faces = 4,
        .vertices = 4,
        .edges = 6,
        .face_type = "triangle",
        .faces_per_vertex = 3,
        .volume = 0.11785113, // √2 / 12
        .surface_area = 1.7320508, // √3
        .face_angle = 60.0,
        .dihedral_angle = 70.528779,
        .circumscribed_radius = 0.612372, // √6 / 4
        .inscribed_radius = 0.204124, // √6 / 12
        .midradius = 0.353553, // √2 / 4
        .symmetry_group = "Tetrahedral (Td)",
    },
    .{
        .name = "Cube (Hexahedron)",
        .faces = 6,
        .vertices = 8,
        .edges = 12,
        .face_type = "square",
        .faces_per_vertex = 3,
        .volume = 1.0,
        .surface_area = 6.0,
        .face_angle = 90.0,
        .dihedral_angle = 90.0,
        .circumscribed_radius = 0.866025, // √3 / 2
        .inscribed_radius = 0.5,
        .midradius = 0.707107, // √2 / 2
        .symmetry_group = "Octahedral (Oh)",
    },
    .{
        .name = "Octahedron",
        .faces = 8,
        .vertices = 6,
        .edges = 12,
        .face_type = "triangle",
        .faces_per_vertex = 4,
        .volume = 0.47140452, // √2 / 3
        .surface_area = 3.4641016, // 2√3
        .face_angle = 60.0,
        .dihedral_angle = 109.47122,
        .circumscribed_radius = 0.707107, // √2 / 2
        .inscribed_radius = 0.408248, // √6 / 6
        .midradius = 0.5,
        .symmetry_group = "Octahedral (Oh)",
    },
    .{
        .name = "Dodecahedron",
        .faces = 12,
        .vertices = 20,
        .edges = 30,
        .face_type = "pentagon",
        .faces_per_vertex = 3,
        .volume = 7.66311896, // 15+7√5 / 4
        .surface_area = 20.645729, // 3√(25+10√5)
        .face_angle = 108.0,
        .dihedral_angle = 116.56505,
        .circumscribed_radius = 1.401258, // (√3×φ)/2 ≈ 1.401
        .inscribed_radius = 1.113516, // φ²√3 / (2×√(5-√5))
        .midradius = 1.309, // φ² / 2
        .symmetry_group = "Icosahedral (Ih)",
    },
    .{
        .name = "Icosahedron",
        .faces = 20,
        .vertices = 12,
        .edges = 30,
        .face_type = "triangle",
        .faces_per_vertex = 5,
        .volume = 2.5361507, // 5(3+√5)/12
        .surface_area = 8.660254, // 5√3
        .face_angle = 60.0,
        .dihedral_angle = 138.189685,
        .circumscribed_radius = 0.9510565, // √(10+2√5)√φ / 4
        .inscribed_radius = 0.755761, // √3 × φ² / (2×√5)
        .midradius = 0.809017, // φ/2
        .symmetry_group = "Icosahedral (Ih)",
    },
};

pub fn getPlatonicSolid(comptime name: []const u8) *const PlatonicSolid {
    inline for (&PLATONIC_SOLIDS) |*solid| {
        if (std.mem.eql(u8, solid.name, name)) return solid;
    }
    @panic("Unknown Platonic solid");
}

// ═══════════════════════════════════════════════════════════════════════════════
// ARCHIMEDEAN SOLIDS — 13 semi-regular convex polyhedra
// ═══════════════════════════════════════════════════════════════════════════════

pub const ArchimedeanSolid = struct {
    name: []const u8,
    faces: u32,
    vertices: u32,
    edges: u32,
    face_types: []const []const u8,
    face_counts: []const u32,
    volume: f64,
    surface_area: f64,
};

// Key Archimedean solids (subset)
pub const ARCHIMEDEAN_SOLIDS = [_]ArchimedeanSolid{
    .{
        .name = "Truncated Tetrahedron",
        .faces = 8,
        .vertices = 12,
        .edges = 18,
        .face_types = &[_][]const u8{ "triangle", "hexagon" },
        .face_counts = &[_]u32{ 4, 4 },
        .volume = 2.710576,
        .surface_area = 6.96968,
    },
    .{
        .name = "Cuboctahedron",
        .faces = 14,
        .vertices = 12,
        .edges = 24,
        .face_types = &[_][]const u8{ "triangle", "square" },
        .face_counts = &[_]u32{ 8, 6 },
        .volume = 2.357022,
        .surface_area = 9.46410,
    },
    .{
        .name = "Truncated Cube",
        .faces = 14,
        .vertices = 24,
        .edges = 36,
        .face_types = &[_][]const u8{ "triangle", "octagon" },
        .face_counts = &[_]u32{ 8, 6 },
        .volume = 13.59966,
        .surface_area = 17.7391,
    },
    .{
        .name = "Truncated Octahedron",
        .faces = 14,
        .vertices = 24,
        .edges = 36,
        .face_types = &[_][]const u8{ "square", "hexagon" },
        .face_counts = &[_]u32{ 6, 8 },
        .volume = 11.313708,
        .surface_area = 19.8587,
    },
    .{
        .name = "Rhombicuboctahedron",
        .faces = 26,
        .vertices = 24,
        .edges = 48,
        .face_types = &[_][]const u8{ "triangle", "square" },
        .face_counts = &[_]u32{ 8, 18 },
        .volume = 8.71404,
        .surface_area = 21.4641,
    },
    .{
        .name = "Truncated Cuboctahedron",
        .faces = 26,
        .vertices = 48,
        .edges = 72,
        .face_types = &[_][]const u8{ "square", "hexagon", "octagon" },
        .face_counts = &[_]u32{ 12, 8, 6 },
        .volume = 23.2098,
        .surface_area = 32.981,
    },
    .{
        .name = "Snub Cube",
        .faces = 38,
        .vertices = 24,
        .edges = 60,
        .face_types = &[_][]const u8{ "triangle", "square" },
        .face_counts = &[_]u32{ 32, 6 },
        .volume = 7.88948,
        .surface_area = 19.856,
    },
    .{
        .name = "Icosidodecahedron",
        .faces = 32,
        .vertices = 30,
        .edges = 60,
        .face_types = &[_][]const u8{ "triangle", "pentagon" },
        .face_counts = &[_]u32{ 20, 12 },
        .volume = 9.21915,
        .surface_area = 21.497,
    },
    .{
        .name = "Truncated Dodecahedron",
        .faces = 32,
        .vertices = 60,
        .edges = 90,
        .face_types = &[_][]const u8{ "triangle", "decagon" },
        .face_counts = &[_]u32{ 20, 12 },
        .volume = 85.0397,
        .surface_area = 73.664,
    },
    .{
        .name = "Truncated Icosahedron",
        .faces = 32,
        .vertices = 60,
        .edges = 90,
        .face_types = &[_][]const u8{ "hexagon", "pentagon" },
        .face_counts = &[_]u32{ 20, 12 },
        .volume = 55.2877,
        .surface_area = 72.607,
    },
    .{
        .name = "Rhombicosidodecahedron",
        .faces = 62,
        .vertices = 60,
        .edges = 120,
        .face_types = &[_][]const u8{ "triangle", "square", "pentagon" },
        .face_counts = &[_]u32{ 20, 30, 12 },
        .volume = 40.9188,
        .surface_area = 59.305,
    },
    .{
        .name = "Truncated Icosidodecahedron",
        .faces = 62,
        .vertices = 120,
        .edges = 180,
        .face_types = &[_][]const u8{ "square", "hexagon", "decagon" },
        .face_counts = &[_]u32{ 30, 20, 12 },
        .volume = 206.803,
        .surface_area = 174.292,
    },
    .{
        .name = "Snub Dodecahedron",
        .faces = 92,
        .vertices = 60,
        .edges = 150,
        .face_types = &[_][]const u8{ "triangle", "pentagon" },
        .face_counts = &[_]u32{ 80, 12 },
        .volume = 37.6169,
        .surface_area = 55.2867,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN ANGLE — 360/φ² ≈ 137.507764°
// Used in phyllotaxis (leaf arrangement), spiral sunflowers
// ═══════════════════════════════════════════════════════════════════════════════

pub const GOLDEN_ANGLE_DEG: f64 = sacred_const.math.GOLDEN_ANGLE_DEG;
pub const GOLDEN_ANGLE_RAD: f64 = sacred_const.math.GOLDEN_ANGLE_RAD;

/// Phyllotaxis coordinates (leaf arrangement on spiral)
/// Returns (r, θ) = (c√n, n × golden_angle)
pub fn phyllotaxisCoordinates(n: u32, c: f64) struct { r: f64, theta: f64 } {
    const nf: f64 = @floatFromInt(n);
    const r = c * math.sqrt(nf);
    const theta = nf * GOLDEN_ANGLE_RAD;
    return .{ .r = r, .theta = theta };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FRACTAL CONSTANTS — Dimensions and parameters
// ═══════════════════════════════════════════════════════════════════════════════

pub const SIERPINSKI_DIM: f64 = sacred_const.fractals.SIERPINSKI_DIM; // ln(3)/ln(2)
pub const KOCH_DIM: f64 = sacred_const.fractals.KOCH_DIM; // ln(4)/ln(3)
pub const MENGER_DIM: f64 = sacred_const.fractals.MENGER_DIM; // ln(20)/ln(3)
pub const CANTOR_DIM: f64 = sacred_const.fractals.CANTOR_DIM; // ln(2)/ln(3)

// ═══════════════════════════════════════════════════════════════════════════════
// ASCII FRACTAL GENERATORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Sierpinski triangle ASCII art (depth 1-6 recommended)
pub fn sierpinskiDepth(depth: u32, writer: anytype) !void {
    const size: u32 = 1 << depth; // 2^depth
    var y: u32 = 0;
    while (y < size) : (y += 1) {
        var x: u32 = 0;
        while (x < size) : (x += 1) {
            // Draw if (x & y) == 0 in binary for this position
            const draw = (x & y) == 0;
            try writer.writeAll(if (draw) "▲" else " ");
        }
        try writer.writeAll("\n");
    }
}

/// ASCII Mandelbrot set (center x, y, zoom level)
pub fn mandelbrotASCII(center_x: f64, center_y: f64, zoom: f64, width: u32, height: u32, writer: anytype) !void {
    const max_iter: u32 = 100;
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const cx = center_x + (@as(f64, @floatFromInt(x)) - @as(f64, @floatFromInt(width)) / 2) / zoom;
            const cy = center_y + (@as(f64, @floatFromInt(y)) - @as(f64, @floatFromInt(height)) / 2) / zoom;

            var zx: f64 = 0;
            var zy: f64 = 0;
            var iter: u32 = 0;
            while (zx * zx + zy * zy <= 4 and iter < max_iter) : (iter += 1) {
                const xt = zx * zx - zy * zy + cx;
                zy = 2 * zx * zy + cy;
                zx = xt;
            }

            const chars = " .:-=+*#%@";
            const idx = @min(iter, max_iter) * (chars.len - 1) / max_iter;
            try writer.writeByte(chars[idx]);
        }
        try writer.writeAll("\n");
    }
}

/// Julia set ASCII art (c = c_re + i*c_im)
pub fn juliaASCII(c_re: f64, c_im: f64, bounds_min: f64, bounds_max: f64, width: u32, height: u32, writer: anytype) !void {
    const max_iter: u32 = 50;
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            var zx = bounds_min + (@as(f64, @floatFromInt(x)) / @as(f64, @floatFromInt(width))) * (bounds_max - bounds_min);
            var zy = bounds_min + (@as(f64, @floatFromInt(y)) / @as(f64, @floatFromInt(height))) * (bounds_max - bounds_min);

            var iter: u32 = 0;
            while (zx * zx + zy * zy <= 4 and iter < max_iter) : (iter += 1) {
                const xt = zx * zx - zy * zy + c_re;
                zy = 2 * zx * zy + c_im;
                zx = xt;
            }

            const chars = " .:-=+*#%@";
            const idx = @min(iter, max_iter) * (chars.len - 1) / max_iter;
            try writer.writeByte(chars[idx]);
        }
        try writer.writeAll("\n");
    }
}

/// Barnsley fern ASCII (iterated function system)
pub fn barnsleyFern(iterations: u32, writer: anytype) !void {
    // Buffer to plot points
    var grid: [80][40]u8 = undefined;
    for (&grid) |*row| {
        for (row) |*c| c = ' ';
    }

    // IFS coefficients
    var x: f64 = 0;
    var y: f64 = 0;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        const r = @as(f64, @floatFromInt(std.crypto.random.intRangeLessThan(u8, 100))) / 100.0;

        var nx: f64 = undefined;
        var ny: f64 = undefined;

        if (r < 0.01) {
            // Stem (1%)
            nx = 0;
            ny = 0.16 * y;
        } else if (r < 0.86) {
            // Smaller leaflets (85%)
            nx = 0.85 * x + 0.04 * y;
            ny = -0.04 * x + 0.85 * y + 1.6;
        } else if (r < 0.93) {
            // Left largest leaflet (7%)
            nx = 0.2 * x - 0.26 * y;
            ny = 0.23 * x + 0.22 * y + 1.6;
        } else {
            // Right largest leaflet (7%)
            nx = -0.15 * x + 0.28 * y;
            ny = 0.26 * x + 0.24 * y + 0.44;
        }

        x = nx;
        y = ny;

        // Plot point
        const px = @as(usize, @intFromFloat(@mod(@floatFromInt(@as(i32, @intCast(x * 25))), 80)));
        const py = @as(usize, @intFromFloat(@min(39, @floatFromInt(@as(i32, @intCast(y * 6))))));
        if (px < 80 and py < 40) {
            grid[px][py] = '*';
        }
    }

    // Draw
    for (0..40) |row| {
        for (0..80) |col| {
            try writer.writeByte(grid[col][39 - row]);
        }
        try writer.writeAll("\n");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════

/// Vesica Piscis dimensions (lens formed by two circles of radius r)
pub fn vesicaPiscis(r: f64) struct { width: f64, height: f64, area: f64 } {
    const width = r; // overlap width
    const height = r * @sqrt(3.0); // √3 × r
    const area = (2.0 * math.pi / 3.0 - @sqrt(3.0) / 2.0) * r * r;
    return .{ .width = width, .height = height, .area = area };
}

/// Golden rectangle sides (a, a×φ)
pub fn goldenRectangle(a: f64) struct { a: f64, b: f64, diagonal: f64, area: f64 } {
    const b = a * sacred_const.math.PHI;
    const diagonal = a * @sqrt(1.0 + sacred_const.math.PHI * sacred_const.math.PHI);
    const area = a * b;
    return .{ .a = a, .b = b, .diagonal = diagonal, .area = area };
}

/// Regular polygon properties
pub fn regularPolygon(n: u32, circumradius: f64) struct {
    area: f64,
    perimeter: f64,
    interior_angle: f64,
    central_angle: f64,
    side_length: f64,
} {
    const pi = sacred_const.math.PI;
    const central_angle = 2 * pi / @as(f64, @floatFromInt(n));
    const side_length = 2 * circumradius * @sin(pi / @as(f64, @floatFromInt(n)));
    const perimeter = @as(f64, @floatFromInt(n)) * side_length;
    const area = 0.5 * @as(f64, @floatFromInt(n)) * circumradius * circumradius * @sin(2 * pi / @as(f64, @floatFromInt(n)));
    const interior_angle = (@as(f64, @floatFromInt(n)) - 2) * 180.0 / @as(f64, @floatFromInt(n));
    return .{
        .area = area,
        .perimeter = perimeter,
        .interior_angle = interior_angle,
        .central_angle = central_angle * 180 / pi,
        .side_length = side_length,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "platonic solids Euler's formula V - E + F = 2" {
    inline for (&PLATONIC_SOLIDS) |solid| {
        try std.testing.expectEqual(@as(i32, 2), solid.vertices - solid.edges + solid.faces);
    }
}

test "golden angle = 360/φ²" {
    try std.testing.expectApproxEqAbs(360.0 / (sacred_const.math.PHI * sacred_const.math.PHI), GOLDEN_ANGLE_DEG, 0.001);
}

test "sierpinski dimension = ln(3)/ln(2)" {
    try std.testing.expectApproxEqAbs(@log(3) / @log(2), SIERPINSKI_DIM, 0.001);
}

test "koch dimension = ln(4)/ln(3)" {
    try std.testing.expectApproxEqAbs(@log(4) / @log(3), KOCH_DIM, 0.001);
}

test "vesca piscis" {
    const result = vesicaPiscis(1.0);
    try std.testing.expectApproxEqAbs(@sqrt(3.0), result.height, 0.001);
}

test "golden rectangle" {
    const result = goldenRectangle(1.0);
    try std.testing.expectApproxEqAbs(sacred_const.math.PHI, result.b, 0.001);
}
