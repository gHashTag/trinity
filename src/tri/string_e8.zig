// @origin(spec:string_e8.tri) @regen(manual-impl)
//! E8 lattice mathematics — real Cartan matrix, γ-deformation, φ-coupling.

const std = @import("std");
const SacredConstants = @import("sacred_constants.zig").SacredConstants;

const PHI = SacredConstants.PHI;
const PHI_INV = SacredConstants.PHI_INVERSE;
const GAMMA = SacredConstants.GAMMA;

pub const E8Root = struct {
    x: i32,
    y: i32,
    z: i32,
    components: [3]i32 = [_]i32{ 0, 0, 0 },
};

pub const E8Lattice = struct {
    roots: [1]E8Root = .{.{ .x = 0, .y = 0, .z = 0, .components = [_]i32{ 0, 0, 0 } }},

    pub fn init() !@This() {
        return @This(){};
    }

    /// Returns the real E8 Cartan matrix (8×8).
    /// Dynkin diagram: 1-2-3-4-5-6-7 with 8 branching from 5.
    pub fn gramMatrix(self: @This()) [8][8]f64 {
        _ = self;
        var m = [_][8]f64{[_]f64{0} ** 8} ** 8;

        // Diagonal = 2
        for (0..8) |i| m[i][i] = 2.0;

        // A6 chain: nodes 0-1-2-3-4-5
        for (0..6) |i| {
            m[i][i + 1] = -1.0;
            m[i + 1][i] = -1.0;
        }

        // E8 branch: node 7 connects to node 4 (0-indexed)
        m[7][4] = -1.0;
        m[4][7] = -1.0;

        return m;
    }

    /// Check positive definiteness via diagonal dominance (sufficient condition).
    pub fn isPositiveDefinite(gram: anytype) bool {
        const G = gram;
        for (0..8) |i| {
            var off_diag_sum: f64 = 0;
            for (0..8) |j| {
                if (i != j) off_diag_sum += @abs(G[i][j]);
            }
            if (G[i][i] <= off_diag_sum) return false;
        }
        return true;
    }
};

/// Gamma-phi deformation: scale root components by GAMMA
pub const GammaDeformation = struct {
    components: [3]i32 = [_]i32{ 0, 0, 0 },

    pub fn deformWithGammaPhi(sample: anytype) @This() {
        const root: E8Root = sample;
        return .{
            .components = .{
                @intFromFloat(@as(f64, @floatFromInt(root.components[0])) * GAMMA),
                @intFromFloat(@as(f64, @floatFromInt(root.components[1])) * GAMMA),
                @intFromFloat(@as(f64, @floatFromInt(root.components[2])) * GAMMA),
            },
        };
    }
};

/// φ-coupling between E8 roots
pub const PhiCoupling = struct {
    /// Returns φ × (1 - |cos θ|). Self-coupling = 0, orthogonal = φ.
    pub fn couplingStrength(a: anytype, b: anytype) f64 {
        const ra: E8Root = a;
        const rb: E8Root = b;
        var dot: f64 = 0;
        var na: f64 = 0;
        var nb: f64 = 0;
        for (0..3) |i| {
            const ai: f64 = @floatFromInt(ra.components[i]);
            const bi: f64 = @floatFromInt(rb.components[i]);
            dot += ai * bi;
            na += ai * ai;
            nb += bi * bi;
        }
        if (na == 0 or nb == 0) return PHI;
        const cos_theta = dot / @sqrt(na * nb);
        return PHI * (1.0 - @abs(cos_theta));
    }
};

/// Project E8 root to 4D, scaled by φ⁻¹
pub const E8Projection = struct {
    data: [4]f64 = [_]f64{ 0, 0, 0, 0 },

    pub fn to4D(sample: anytype) @This() {
        const root: E8Root = sample;
        return .{
            .data = .{
                @as(f64, @floatFromInt(root.x)) * PHI_INV,
                @as(f64, @floatFromInt(root.y)) * PHI_INV,
                @as(f64, @floatFromInt(root.z)) * PHI_INV,
                @as(f64, @floatFromInt(root.components[0])) * PHI_INV,
            },
        };
    }

    pub fn isPositiveDefinite(gram: anytype) bool {
        return E8Lattice.isPositiveDefinite(gram);
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

const testing = std.testing;

test "E8 Cartan matrix diagonal is 2" {
    const lattice = try E8Lattice.init();
    const m = lattice.gramMatrix();
    for (0..8) |i| {
        try testing.expectEqual(@as(f64, 2.0), m[i][i]);
    }
}

test "E8 Cartan matrix branch at node 4" {
    const lattice = try E8Lattice.init();
    const m = lattice.gramMatrix();
    // Node 7 connects ONLY to node 4 (E8 branch)
    try testing.expectEqual(@as(f64, -1.0), m[7][4]);
    try testing.expectEqual(@as(f64, -1.0), m[4][7]);
    // Node 7 does NOT connect to node 6
    try testing.expectEqual(@as(f64, 0.0), m[7][6]);
    try testing.expectEqual(@as(f64, 0.0), m[6][7]);
}

test "GammaDeformation scales by gamma" {
    const root = E8Root{ .x = 10, .y = 20, .z = 30, .components = .{ 100, 200, 300 } };
    const d = GammaDeformation.deformWithGammaPhi(root);
    try testing.expectEqual(@as(i32, 23), d.components[0]);
    try testing.expectEqual(@as(i32, 47), d.components[1]);
}

test "PhiCoupling self-coupling is zero" {
    const root = E8Root{ .x = 1, .y = 0, .z = 0, .components = .{ 1, 0, 0 } };
    const c = PhiCoupling.couplingStrength(root, root);
    try testing.expect(@abs(c) < 1e-10);
}

test "PhiCoupling zero-root returns phi" {
    const zero = E8Root{ .x = 0, .y = 0, .z = 0, .components = .{ 0, 0, 0 } };
    const other = E8Root{ .x = 1, .y = 0, .z = 0, .components = .{ 1, 0, 0 } };
    const c = PhiCoupling.couplingStrength(zero, other);
    try testing.expect(@abs(c - PHI) < 1e-10);
}

// φ² + 1/φ² = 3 = TRINITY
