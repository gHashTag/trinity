// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY — NON-EUCLIDEAN GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════
// Spherical, hyperbolic, and projective geometry.
// Curvature K = {-1, 0, +1} = TERNARY classification.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const EARTH_RADIUS_KM: f64 = 6371.0;
const DEG_TO_RAD: f64 = mod.PI / 180.0;
const RAD_TO_DEG: f64 = 180.0 / mod.PI;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom sphere <subcommand>
pub fn cmdSphere(args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage:\n", .{});
        std.debug.print("  tri geom sphere distance <lat1> <lon1> <lat2> <lon2>  Great circle (haversine)\n", .{});
        std.debug.print("  tri geom sphere triangle <a> <b> <c>                  Spherical triangle area\n", .{});
        return;
    }

    const sub = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "distance") or std.mem.eql(u8, sub, "dist")) {
        cmdSphereDistance(sub_args);
    } else if (std.mem.eql(u8, sub, "triangle") or std.mem.eql(u8, sub, "tri")) {
        cmdSphereTriangle(sub_args);
    } else {
        std.debug.print("Unknown sphere subcommand: {s}\n", .{sub});
        std.debug.print("Available: distance, triangle\n", .{});
    }
}

/// tri geom hyper <subcommand>
pub fn cmdHyper(args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage:\n", .{});
        std.debug.print("  tri geom hyper triangle <a> <b> <c>   Hyperbolic triangle area (angle defect)\n", .{});
        return;
    }

    const sub = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "triangle") or std.mem.eql(u8, sub, "tri")) {
        cmdHyperTriangle(sub_args);
    } else {
        std.debug.print("Unknown hyper subcommand: {s}\n", .{sub});
    }
}

/// tri geom curvature
pub fn cmdCurvature() void {
    fmt.boxHeader("CURVATURE CLASSIFICATION = TERNARY");
    std.debug.print("\n", .{});

    std.debug.print("  {s}Gaussian curvature K classifies all 2D geometries into THREE types:{s}\n\n", .{ fmt.WHITE, fmt.RESET });

    // K < 0
    std.debug.print("  {s}K < 0  =>  trit = -1  =>  HYPERBOLIC{s}\n", .{ fmt.PURPLE, fmt.RESET });
    std.debug.print("  {s}  - Saddle surfaces, Poincare disk model{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Triangle angle sum < 180 deg (angle DEFECT){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Area = R^2 * (pi - A - B - C){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Infinitely many parallels through external point{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Natural model for hierarchical/tree-like data{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    // K = 0
    std.debug.print("  {s}K = 0  =>  trit =  0  =>  EUCLIDEAN (flat){s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("  {s}  - Planes, cylinders (intrinsically flat){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Triangle angle sum = 180 deg (exact){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Euclid's parallel postulate holds{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Pythagorean theorem: a^2 + b^2 = c^2{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    // K > 0
    std.debug.print("  {s}K > 0  =>  trit = +1  =>  SPHERICAL{s}\n", .{ fmt.GREEN, fmt.RESET });
    std.debug.print("  {s}  - Spheres, ellipsoids{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Triangle angle sum > 180 deg (angle EXCESS){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Area = R^2 * (A + B + C - pi){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - No parallel lines exist (all great circles intersect){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}  - Similar triangles are congruent (no free scaling){s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.separator();
    std.debug.print("\n  {s}Geometry IS ternary.{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}Every point on every surface has a curvature sign: {{-1, 0, +1}}.{s}\n", .{ fmt.WHITE, fmt.RESET });
    std.debug.print("  {s}Klein's Erlangen Program (1872): all three geometries are{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}special cases of projective geometry, determined by a ternary choice.{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPHERE SUBCOMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdSphereDistance(args: []const []const u8) void {
    if (args.len < 4) {
        std.debug.print("Usage: tri geom sphere distance <lat1> <lon1> <lat2> <lon2>\n", .{});
        std.debug.print("  Coordinates in degrees. Uses haversine formula.\n", .{});
        std.debug.print("  Example: tri geom sphere distance 55.75 37.62 40.71 -74.01\n", .{});
        std.debug.print("           (Moscow -> New York)\n", .{});
        return;
    }

    const lat1 = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid lat1: {s}\n", .{args[0]});
        return;
    };
    const lon1 = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid lon1: {s}\n", .{args[1]});
        return;
    };
    const lat2 = std.fmt.parseFloat(f64, args[2]) catch {
        std.debug.print("Invalid lat2: {s}\n", .{args[2]});
        return;
    };
    const lon2 = std.fmt.parseFloat(f64, args[3]) catch {
        std.debug.print("Invalid lon2: {s}\n", .{args[3]});
        return;
    };

    const dist = haversineDistance(lat1, lon1, lat2, lon2);
    const angle_rad = dist / EARTH_RADIUS_KM;
    const angle_deg = angle_rad * RAD_TO_DEG;

    fmt.boxHeader("GREAT CIRCLE DISTANCE (Haversine)");
    std.debug.print("\n", .{});
    std.debug.print("  Point 1:           ({d:.4} deg, {d:.4} deg)\n", .{ lat1, lon1 });
    std.debug.print("  Point 2:           ({d:.4} deg, {d:.4} deg)\n", .{ lat2, lon2 });
    fmt.separator();
    fmt.labelFloatUnit("Distance:", dist, "km");
    fmt.labelFloatUnit("Central angle:", angle_deg, "deg");
    fmt.labelFloatUnit("Central angle:", angle_rad, "rad");
    fmt.labelFloatUnit("Earth radius:", EARTH_RADIUS_KM, "km");

    std.debug.print("\n  {s}Formula: d = R * 2 * arcsin(sqrt(sin^2(dlat/2) + cos(lat1)*cos(lat2)*sin^2(dlon/2))){s}\n", .{
        fmt.GRAY, fmt.RESET,
    });
    std.debug.print("  {s}This is the shortest path on a sphere (K > 0 geometry, trit = +1){s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

fn cmdSphereTriangle(args: []const []const u8) void {
    if (args.len < 3) {
        std.debug.print("Usage: tri geom sphere triangle <A> <B> <C>\n", .{});
        std.debug.print("  A, B, C = angles in degrees (must sum > 180)\n", .{});
        std.debug.print("  Example: tri geom sphere triangle 90 90 90\n", .{});
        std.debug.print("           (octant of a sphere)\n", .{});
        return;
    }

    const a_deg = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid A: {s}\n", .{args[0]});
        return;
    };
    const b_deg = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid B: {s}\n", .{args[1]});
        return;
    };
    const c_deg = std.fmt.parseFloat(f64, args[2]) catch {
        std.debug.print("Invalid C: {s}\n", .{args[2]});
        return;
    };

    const a_rad = a_deg * DEG_TO_RAD;
    const b_rad = b_deg * DEG_TO_RAD;
    const c_rad = c_deg * DEG_TO_RAD;

    const angle_sum = a_deg + b_deg + c_deg;
    const excess = a_rad + b_rad + c_rad - mod.PI;
    const area_unit = excess; // Area on unit sphere = R^2 * excess

    fmt.boxHeader("SPHERICAL TRIANGLE (K > 0)");
    std.debug.print("\n", .{});
    std.debug.print("  Angle A:           {d:.4} deg\n", .{a_deg});
    std.debug.print("  Angle B:           {d:.4} deg\n", .{b_deg});
    std.debug.print("  Angle C:           {d:.4} deg\n", .{c_deg});
    fmt.separator();
    fmt.labelFloatUnit("Angle sum:", angle_sum, "deg");
    fmt.labelFloatUnit("Excess (E):", excess * RAD_TO_DEG, "deg");
    fmt.labelFloatUnit("Excess (E):", excess, "rad");
    fmt.labelFloat("Area (R=1):", area_unit);
    std.debug.print("\n", .{});

    if (angle_sum > 180.0) {
        std.debug.print("  {s}Angle sum > 180 deg => positive curvature => SPHERICAL{s}\n", .{ fmt.GREEN, fmt.RESET });
        std.debug.print("  {s}Area = R^2 * (A + B + C - pi) = R^2 * {d:.6}{s}\n", .{ fmt.GRAY, excess, fmt.RESET });
    } else if (@abs(angle_sum - 180.0) < 0.001) {
        std.debug.print("  {s}Angle sum = 180 deg => flat => EUCLIDEAN{s}\n", .{ fmt.CYAN, fmt.RESET });
    } else {
        std.debug.print("  {s}Angle sum < 180 deg => this is HYPERBOLIC, not spherical{s}\n", .{ fmt.PURPLE, fmt.RESET });
    }

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// HYPERBOLIC SUBCOMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn cmdHyperTriangle(args: []const []const u8) void {
    if (args.len < 3) {
        std.debug.print("Usage: tri geom hyper triangle <A> <B> <C>\n", .{});
        std.debug.print("  A, B, C = angles in degrees (must sum < 180)\n", .{});
        std.debug.print("  Example: tri geom hyper triangle 50 50 50\n", .{});
        std.debug.print("           (triangle on saddle surface)\n", .{});
        return;
    }

    const a_deg = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid A: {s}\n", .{args[0]});
        return;
    };
    const b_deg = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid B: {s}\n", .{args[1]});
        return;
    };
    const c_deg = std.fmt.parseFloat(f64, args[2]) catch {
        std.debug.print("Invalid C: {s}\n", .{args[2]});
        return;
    };

    const a_rad = a_deg * DEG_TO_RAD;
    const b_rad = b_deg * DEG_TO_RAD;
    const c_rad = c_deg * DEG_TO_RAD;

    const angle_sum = a_deg + b_deg + c_deg;
    const defect = mod.PI - (a_rad + b_rad + c_rad);
    const area_unit = defect; // Area on unit hyperbolic plane

    fmt.boxHeader("HYPERBOLIC TRIANGLE (K < 0)");
    std.debug.print("\n", .{});
    std.debug.print("  Angle A:           {d:.4} deg\n", .{a_deg});
    std.debug.print("  Angle B:           {d:.4} deg\n", .{b_deg});
    std.debug.print("  Angle C:           {d:.4} deg\n", .{c_deg});
    fmt.separator();
    fmt.labelFloatUnit("Angle sum:", angle_sum, "deg");
    fmt.labelFloatUnit("Defect (D):", defect * RAD_TO_DEG, "deg");
    fmt.labelFloatUnit("Defect (D):", defect, "rad");
    fmt.labelFloat("Area (R=1):", area_unit);
    std.debug.print("\n", .{});

    if (angle_sum < 180.0) {
        std.debug.print("  {s}Angle sum < 180 deg => negative curvature => HYPERBOLIC{s}\n", .{ fmt.PURPLE, fmt.RESET });
        std.debug.print("  {s}Area = R^2 * (pi - A - B - C) = R^2 * {d:.6}{s}\n", .{ fmt.GRAY, defect, fmt.RESET });
        std.debug.print("  {s}Maximum area (all angles -> 0): pi * R^2{s}\n", .{ fmt.GRAY, fmt.RESET });
    } else if (@abs(angle_sum - 180.0) < 0.001) {
        std.debug.print("  {s}Angle sum = 180 deg => flat => EUCLIDEAN{s}\n", .{ fmt.CYAN, fmt.RESET });
    } else {
        std.debug.print("  {s}Angle sum > 180 deg => this is SPHERICAL, not hyperbolic{s}\n", .{ fmt.GREEN, fmt.RESET });
    }

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Haversine great circle distance between two points on Earth
pub fn haversineDistance(lat1_deg: f64, lon1_deg: f64, lat2_deg: f64, lon2_deg: f64) f64 {
    const dlat = (lat2_deg - lat1_deg) * DEG_TO_RAD;
    const dlon = (lon2_deg - lon1_deg) * DEG_TO_RAD;
    const lat1 = lat1_deg * DEG_TO_RAD;
    const lat2 = lat2_deg * DEG_TO_RAD;

    const sin_dlat = @sin(dlat / 2.0);
    const sin_dlon = @sin(dlon / 2.0);
    const a = sin_dlat * sin_dlat + @cos(lat1) * @cos(lat2) * sin_dlon * sin_dlon;
    const c = 2.0 * std.math.atan2(@sqrt(a), @sqrt(1.0 - a));
    return EARTH_RADIUS_KM * c;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "haversine equator to pole" {
    // From equator (0,0) to north pole (90,0) = pi/2 * R
    const dist = haversineDistance(0, 0, 90, 0);
    const expected = mod.PI / 2.0 * EARTH_RADIUS_KM;
    try std.testing.expectApproxEqAbs(expected, dist, 1.0); // within 1 km
}

test "haversine same point" {
    const dist = haversineDistance(55.75, 37.62, 55.75, 37.62);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), dist, 0.001);
}

test "haversine antipodal" {
    // Antipodal points: distance = pi * R
    const dist = haversineDistance(0, 0, 0, 180);
    const expected = mod.PI * EARTH_RADIUS_KM;
    try std.testing.expectApproxEqAbs(expected, dist, 1.0);
}

test "spherical excess positive for spherical triangle" {
    // On a sphere, angle sum > 180 deg. Excess = sum - 180
    // Equilateral triangle on unit sphere with each angle = 90 deg
    const excess = (90.0 + 90.0 + 90.0) - 180.0;
    try std.testing.expect(excess > 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 90.0), excess, 1e-10);
}

test "hyperbolic defect positive for hyperbolic triangle" {
    // On hyperbolic plane, angle sum < 180. Defect = 180 - sum
    const defect = 180.0 - (50.0 + 50.0 + 50.0);
    try std.testing.expect(defect > 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 30.0), defect, 1e-10);
}

test "haversine known distance London to New York" {
    // London (51.5074, -0.1278) to New York (40.7128, -74.0060)
    // Known great circle distance ~5570 km
    const dist = haversineDistance(51.5074, -0.1278, 40.7128, -74.0060);
    try std.testing.expect(dist > 5500.0);
    try std.testing.expect(dist < 5600.0);
}
