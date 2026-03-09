// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY MODULE v1.0
// ═══════════════════════════════════════════════════════════════════════════════
// Constants, types, and submodule re-exports for the geometry CLI.
// φ² + 1/φ² = 3 = TRINITY
// Sierpinski dimension = log(3)/log(2) = 1.585 = bits per trit
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_SQ: f64 = 2.6180339887498948482; // φ² = φ + 1
pub const INV_PHI: f64 = 0.6180339887498948482; // 1/φ = φ - 1
pub const INV_PHI_SQ: f64 = 0.3819660112501051518; // 1/φ²
pub const PI: f64 = std.math.pi;
pub const E_CONST: f64 = std.math.e;
pub const SQRT2: f64 = std.math.sqrt2;
pub const SQRT3: f64 = 1.7320508075688772935;
pub const SQRT5: f64 = 2.2360679774997896964;

// Fractal dimensions — KEY: Sierpinski = bits per trit!
pub const SIERPINSKI_DIM: f64 = 1.5849625007211561815; // log(3)/log(2)
pub const KOCH_DIM: f64 = 1.2618595071429148280; // log(4)/log(3)
pub const CANTOR_DIM: f64 = 0.6309297535714573293; // log(2)/log(3)
pub const GOLDEN_SPIRAL_B: f64 = 0.3063489625388736468; // 2*ln(φ)/π

// ═══════════════════════════════════════════════════════════════════════════════
// PLATONIC SOLID
// ═══════════════════════════════════════════════════════════════════════════════

pub const SolidIndex = enum(u3) {
    tetrahedron = 0,
    cube = 1,
    octahedron = 2,
    dodecahedron = 3,
    icosahedron = 4,
};

pub const PlatonicSolid = struct {
    name: []const u8,
    faces: u32,
    vertices: u32,
    edges: u32,
    face_type: []const u8,
    schlafli: []const u8,
    element: []const u8,
    phi_connection: ?[]const u8,
    idx: SolidIndex,

    pub fn surfaceArea(self: PlatonicSolid, a: f64) f64 {
        const a2 = a * a;
        return switch (self.idx) {
            .tetrahedron => SQRT3 * a2,
            .cube => 6.0 * a2,
            .octahedron => 2.0 * SQRT3 * a2,
            .dodecahedron => 3.0 * @sqrt(25.0 + 10.0 * SQRT5) * a2,
            .icosahedron => 5.0 * SQRT3 * a2,
        };
    }

    pub fn volume(self: PlatonicSolid, a: f64) f64 {
        const a3 = a * a * a;
        return switch (self.idx) {
            .tetrahedron => a3 / (6.0 * SQRT2),
            .cube => a3,
            .octahedron => SQRT2 / 3.0 * a3,
            .dodecahedron => (15.0 + 7.0 * SQRT5) / 4.0 * a3,
            .icosahedron => 5.0 * (3.0 + SQRT5) / 12.0 * a3,
        };
    }

    pub fn circumradius(self: PlatonicSolid, a: f64) f64 {
        return switch (self.idx) {
            .tetrahedron => a * @sqrt(6.0) / 4.0,
            .cube => a * @sqrt(3.0) / 2.0,
            .octahedron => a * SQRT2 / 2.0,
            .dodecahedron => a * @sqrt(3.0) * PHI / 2.0,
            .icosahedron => a * PHI * @sqrt(5.0) / 2.0,
        };
    }

    pub fn inradius(self: PlatonicSolid, a: f64) f64 {
        return switch (self.idx) {
            .tetrahedron => a * @sqrt(6.0) / 12.0,
            .cube => a / 2.0,
            .octahedron => a * @sqrt(6.0) / 6.0,
            .dodecahedron => a * PHI * PHI / (2.0 * @sqrt(3.0 - 1.0 / (PHI * PHI))),
            .icosahedron => a * PHI * PHI / (2.0 * @sqrt(3.0)),
        };
    }

    pub fn dihedralAngleDeg(self: PlatonicSolid) f64 {
        // Precomputed dihedral angles (acos not available at comptime)
        return switch (self.idx) {
            .tetrahedron => 70.528779365509308, // acos(1/3) * 180/pi
            .cube => 90.0,
            .octahedron => 109.47122063449069, // acos(-1/3) * 180/pi
            .dodecahedron => 116.56505117707799, // acos(-1/sqrt(5)) * 180/pi
            .icosahedron => 138.18968510422140, // acos(-sqrt(5)/3) * 180/pi
        };
    }

    pub fn eulerCheck(self: PlatonicSolid) bool {
        const v: i32 = @intCast(self.vertices);
        const e: i32 = @intCast(self.edges);
        const f: i32 = @intCast(self.faces);
        return v - e + f == 2;
    }
};

pub const PLATONIC_SOLIDS = [5]PlatonicSolid{
    .{
        .name = "Tetrahedron",
        .faces = 4,
        .vertices = 4,
        .edges = 6,
        .face_type = "triangle",
        .schlafli = "{3,3}",
        .element = "Fire",
        .phi_connection = null,
        .idx = .tetrahedron,
    },
    .{
        .name = "Cube",
        .faces = 6,
        .vertices = 8,
        .edges = 12,
        .face_type = "square",
        .schlafli = "{4,3}",
        .element = "Earth",
        .phi_connection = null,
        .idx = .cube,
    },
    .{
        .name = "Octahedron",
        .faces = 8,
        .vertices = 6,
        .edges = 12,
        .face_type = "triangle",
        .schlafli = "{3,4}",
        .element = "Air",
        .phi_connection = null,
        .idx = .octahedron,
    },
    .{
        .name = "Dodecahedron",
        .faces = 12,
        .vertices = 20,
        .edges = 30,
        .face_type = "pentagon",
        .schlafli = "{5,3}",
        .element = "Aether",
        .phi_connection = "Pentagonal faces: diagonal/side = phi",
        .idx = .dodecahedron,
    },
    .{
        .name = "Icosahedron",
        .faces = 20,
        .vertices = 12,
        .edges = 30,
        .face_type = "triangle",
        .schlafli = "{3,5}",
        .element = "Water",
        .phi_connection = "Edge pairs form 3 golden rectangles (phi:1)",
        .idx = .icosahedron,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// POINT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Point2D = struct {
    x: f64,
    y: f64,
};

pub const Point3D = struct {
    x: f64,
    y: f64,
    z: f64,
};

/// Orientation test — returns a TERNARY result:
///   +1 = counterclockwise (left turn)
///    0 = collinear
///   -1 = clockwise (right turn)
pub fn orientation(p: Point2D, q: Point2D, r: Point2D) i8 {
    const val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
    if (@abs(val) < 1e-10) return 0;
    return if (val > 0) -1 else 1;
}

/// Hausdorff dimension for self-similar fractals: D = log(N)/log(S)
pub fn hausdorffDimension(copies: f64, scale_factor: f64) f64 {
    return @log(copies) / @log(scale_factor);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBMODULE RE-EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const platonic = @import("platonic.zig");
pub const fractal = @import("fractal.zig");
pub const sacred_geom = @import("sacred.zig");
pub const computational = @import("computational.zig");
pub const non_euclidean = @import("non_euclidean.zig");
pub const format = @import("format.zig");

// v2.0: Sacred Formula bridge, golden spiral, Coptic overlay
pub const sacred_bridge = @import("sacred_bridge.zig");
pub const spiral_geom = @import("spiral.zig");
pub const coptic_overlay = @import("coptic_overlay.zig");

pub const version = "2.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "euler formula for all platonic solids" {
    for (&PLATONIC_SOLIDS) |solid| {
        try std.testing.expect(solid.eulerCheck());
    }
}

test "sierpinski dimension equals bits per trit" {
    const bits_per_trit = @log(@as(f64, 3.0)) / @log(@as(f64, 2.0));
    try std.testing.expectApproxEqAbs(SIERPINSKI_DIM, bits_per_trit, 1e-10);
}

test "trinity identity phi^2 + 1/phi^2 = 3" {
    try std.testing.expectApproxEqAbs(PHI_SQ + INV_PHI_SQ, 3.0, 1e-10);
}

test "orientation returns ternary values" {
    const p = Point2D{ .x = 0, .y = 0 };
    const q = Point2D{ .x = 1, .y = 0 };
    const r_ccw = Point2D{ .x = 1, .y = 1 };
    const r_cw = Point2D{ .x = 1, .y = -1 };
    const r_col = Point2D{ .x = 2, .y = 0 };
    try std.testing.expectEqual(@as(i8, 1), orientation(p, q, r_ccw));
    try std.testing.expectEqual(@as(i8, -1), orientation(p, q, r_cw));
    try std.testing.expectEqual(@as(i8, 0), orientation(p, q, r_col));
}

test "hausdorff dimension known values" {
    // Sierpinski: 3 copies, scale 2
    try std.testing.expectApproxEqAbs(SIERPINSKI_DIM, hausdorffDimension(3.0, 2.0), 1e-10);
    // Koch: 4 copies, scale 3
    try std.testing.expectApproxEqAbs(KOCH_DIM, hausdorffDimension(4.0, 3.0), 1e-10);
    // Cantor: 2 copies, scale 3
    try std.testing.expectApproxEqAbs(CANTOR_DIM, hausdorffDimension(2.0, 3.0), 1e-10);
}

test "unit cube volume and surface area" {
    const cube = PLATONIC_SOLIDS[1];
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), cube.volume(1.0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 6.0), cube.surfaceArea(1.0), 1e-10);
}

test "unit tetrahedron volume" {
    const tet = PLATONIC_SOLIDS[0];
    const expected = 1.0 / (6.0 * SQRT2);
    try std.testing.expectApproxEqAbs(expected, tet.volume(1.0), 1e-10);
}

test "all platonic solid volumes positive" {
    for (&PLATONIC_SOLIDS) |solid| {
        const vol = solid.volume(1.0);
        try std.testing.expect(vol > 0.0);
        try std.testing.expect(!std.math.isNan(vol));
    }
}

test "all platonic solid surface areas positive" {
    for (&PLATONIC_SOLIDS) |solid| {
        const sa = solid.surfaceArea(1.0);
        try std.testing.expect(sa > 0.0);
        try std.testing.expect(!std.math.isNan(sa));
    }
}

test "dodecahedron and icosahedron are phi-dual" {
    // Dodecahedron has 12 faces, 20 vertices; icosahedron has 20 faces, 12 vertices
    const dodec = PLATONIC_SOLIDS[3];
    const icos = PLATONIC_SOLIDS[4];
    try std.testing.expectEqual(dodec.faces, icos.vertices);
    try std.testing.expectEqual(dodec.vertices, icos.faces);
    try std.testing.expectEqual(dodec.edges, icos.edges);
}

test "platonic circumradius > inradius" {
    for (&PLATONIC_SOLIDS) |solid| {
        const cr = solid.circumradius(1.0);
        const ir = solid.inradius(1.0);
        try std.testing.expect(cr > ir);
        try std.testing.expect(ir > 0.0);
    }
}

test "scaling: volume scales as a^3" {
    const cube = PLATONIC_SOLIDS[1];
    const v1 = cube.volume(1.0);
    const v2 = cube.volume(2.0);
    try std.testing.expectApproxEqAbs(v1 * 8.0, v2, 1e-10);
}

test "scaling: surface area scales as a^2" {
    const cube = PLATONIC_SOLIDS[1];
    const sa1 = cube.surfaceArea(1.0);
    const sa2 = cube.surfaceArea(3.0);
    try std.testing.expectApproxEqAbs(sa1 * 9.0, sa2, 1e-10);
}
