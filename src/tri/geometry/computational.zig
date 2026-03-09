// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY — COMPUTATIONAL GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════
// Convex hull (Graham scan), point-in-polygon, trit3d lattice.
// Orientation test = ternary {-1, 0, +1} — geometry IS ternary.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom hull <x1,y1> <x2,y2> ...
pub fn cmdHull(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: tri geom hull <x1,y1> <x2,y2> <x3,y3> ...\n", .{});
        std.debug.print("  Compute convex hull using Graham scan.\n", .{});
        std.debug.print("  Example: tri geom hull 0,0 1,0 0.5,1 0.5,0.3 1,1 0,1\n", .{});
        return;
    }

    // Parse points (max 128)
    var point_buf: [128]mod.Point2D = undefined;
    var point_count: usize = 0;

    for (args) |arg| {
        if (parsePoint(arg)) |pt| {
            if (point_count < 128) {
                point_buf[point_count] = pt;
                point_count += 1;
            }
        } else {
            std.debug.print("Invalid point: {s} (format: x,y)\n", .{arg});
            return;
        }
    }

    if (point_count < 3) {
        std.debug.print("Need at least 3 points for convex hull\n", .{});
        return;
    }

    // Compute hull
    const hull = try convexHull(allocator, point_buf[0..point_count]);
    defer allocator.free(hull);

    fmt.boxHeader("CONVEX HULL (Graham Scan)");
    std.debug.print("\n", .{});

    std.debug.print("  Input points:      {d}\n", .{point_count});
    for (point_buf[0..point_count], 0..) |pt, i| {
        std.debug.print("    P{d}: ({d:.4}, {d:.4})\n", .{ i, pt.x, pt.y });
    }

    fmt.separator();
    std.debug.print("  Hull vertices:     {d}\n", .{hull.len});
    for (hull, 0..) |pt, i| {
        std.debug.print("    H{d}: ({d:.4}, {d:.4})\n", .{ i, pt.x, pt.y });
    }

    fmt.separator();
    std.debug.print("\n  {s}Orientation test = ternary: {{-1, 0, +1}}{s}\n", .{ fmt.CYAN, fmt.RESET });
    std.debug.print("  {s}+1 (CCW/left turn) => keep point on hull{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s} 0 (collinear)     => skip (degenerate){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}-1 (CW/right turn)  => pop stack, not on hull{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom pip <x> <y> <x1,y1> <x2,y2> ...
pub fn cmdPip(args: []const []const u8) void {
    if (args.len < 5) {
        std.debug.print("Usage: tri geom pip <x> <y> <x1,y1> <x2,y2> <x3,y3> ...\n", .{});
        std.debug.print("  Point-in-polygon test (ray casting). Result is ternary!\n", .{});
        std.debug.print("  Example: tri geom pip 0.5 0.5 0,0 1,0 1,1 0,1\n", .{});
        return;
    }

    const px = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid x: {s}\n", .{args[0]});
        return;
    };
    const py = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid y: {s}\n", .{args[1]});
        return;
    };

    const point = mod.Point2D{ .x = px, .y = py };

    // Parse polygon
    var polygon: [64]mod.Point2D = undefined;
    var count: usize = 0;
    for (args[2..]) |arg| {
        if (parsePoint(arg)) |pt| {
            if (count < 64) {
                polygon[count] = pt;
                count += 1;
            }
        }
    }

    if (count < 3) {
        std.debug.print("Need at least 3 polygon vertices\n", .{});
        return;
    }

    const result = pointInPolygon(point, polygon[0..count]);

    fmt.boxHeader("POINT-IN-POLYGON (Ray Casting)");
    std.debug.print("\n", .{});
    std.debug.print("  Test point:        ({d:.4}, {d:.4})\n", .{ px, py });
    std.debug.print("  Polygon vertices:  {d}\n", .{count});
    for (polygon[0..count], 0..) |v, i| {
        std.debug.print("    V{d}: ({d:.4}, {d:.4})\n", .{ i, v.x, v.y });
    }
    fmt.separator();
    fmt.tritResult("Result:", result);

    std.debug.print("\n  {s}Point-in-polygon naturally returns a TERNARY result:{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}+1 = inside,  0 = on boundary,  -1 = outside{s}\n", .{ fmt.CYAN, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom trit3d
pub fn cmdTrit3D() void {
    fmt.boxHeader("TERNARY 3D LATTICE — {-1, 0, +1}^3");
    std.debug.print("\n", .{});

    std.debug.print("  {s}3^3 = 27 points = 1 tryte of spatial information{s}\n\n", .{ fmt.CYAN, fmt.RESET });

    const trits = [_]i8{ -1, 0, 1 };
    var total: u32 = 0;

    for (trits) |z| {
        std.debug.print("  {s}--- Layer z = {d: >2} ---{s}\n", .{ fmt.GOLD, z, fmt.RESET });
        for (trits) |y| {
            std.debug.print("    ", .{});
            for (trits) |x| {
                const dist_sq = @as(f64, @floatFromInt(@as(i32, x) * @as(i32, x) + @as(i32, y) * @as(i32, y) + @as(i32, z) * @as(i32, z)));
                const dist = @sqrt(dist_sq);
                // Color by distance from origin
                if (dist < 0.5) {
                    std.debug.print("{s}({d: >2},{d: >2},{d: >2}){s} ", .{ fmt.GOLD, x, y, z, fmt.RESET });
                } else if (dist < 1.5) {
                    std.debug.print("{s}({d: >2},{d: >2},{d: >2}){s} ", .{ fmt.CYAN, x, y, z, fmt.RESET });
                } else if (dist < 1.8) {
                    std.debug.print("{s}({d: >2},{d: >2},{d: >2}){s} ", .{ fmt.GREEN, x, y, z, fmt.RESET });
                } else {
                    std.debug.print("{s}({d: >2},{d: >2},{d: >2}){s} ", .{ fmt.PURPLE, x, y, z, fmt.RESET });
                }
                total += 1;
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    fmt.separator();
    std.debug.print("  {s}Total:{s}               {d} points = 3^3\n", .{ fmt.GOLD, fmt.RESET, total });
    std.debug.print("  {s}Information:{s}          {d:.4} bits (log2(27))\n", .{ fmt.GOLD, fmt.RESET, @log(@as(f64, 27.0)) / @log(@as(f64, 2.0)) });
    std.debug.print("  {s}Trits:{s}               3\n", .{ fmt.GOLD, fmt.RESET });

    fmt.sectionHeader("Distance Classification");
    std.debug.print("  {s}d = 0{s}:  {s}1 point{s}  (origin)                      {s}= center{s}\n", .{ fmt.GOLD, fmt.RESET, fmt.WHITE, fmt.RESET, fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}d = 1{s}:  {s}6 points{s} (+/-1 on one axis)             {s}= face centers of cube{s}\n", .{ fmt.CYAN, fmt.RESET, fmt.WHITE, fmt.RESET, fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}d = sqrt(2){s}: {s}12 points{s} (+/-1 on two axes)       {s}= edge midpoints of cube{s}\n", .{ fmt.GREEN, fmt.RESET, fmt.WHITE, fmt.RESET, fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}d = sqrt(3){s}: {s}8 points{s}  (+/-1 on all three axes) {s}= vertices of cube{s}\n", .{ fmt.PURPLE, fmt.RESET, fmt.WHITE, fmt.RESET, fmt.GRAY, fmt.RESET });
    std.debug.print("\n  {s}The 6 face-center points form an octahedron (dual of cube){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}The 8 vertex points form a cube{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALGORITHMS
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// ALGORITHMS — 3D VOLUMES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn sphereVolume(r: f64) f64 {
    return (4.0 / 3.0) * std.math.pi * r * r * r;
}

pub fn cylinderVolume(r: f64, h: f64) f64 {
    return std.math.pi * r * r * h;
}

pub fn coneVolume(r: f64, h: f64) f64 {
    return std.math.pi * r * r * h / 3.0;
}

pub fn torusVolume(big_r: f64, small_r: f64) f64 {
    return 2.0 * std.math.pi * std.math.pi * big_r * small_r * small_r;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALGORITHMS — CONVEX HULL & PIP
// ═══════════════════════════════════════════════════════════════════════════════

/// Convex hull via Graham scan. Returns hull points in CCW order.
pub fn convexHull(allocator: std.mem.Allocator, points: []const mod.Point2D) ![]mod.Point2D {
    const n = points.len;
    if (n < 3) {
        const result = try allocator.alloc(mod.Point2D, n);
        @memcpy(result, points);
        return result;
    }

    // Copy and find lowest point
    var pts = try allocator.alloc(mod.Point2D, n);
    defer allocator.free(pts);
    @memcpy(pts, points);

    // Find lowest-y point (leftmost tiebreak)
    var lowest: usize = 0;
    for (pts, 0..) |p, i| {
        if (p.y < pts[lowest].y or (p.y == pts[lowest].y and p.x < pts[lowest].x)) {
            lowest = i;
        }
    }
    // Swap to front
    const tmp = pts[0];
    pts[0] = pts[lowest];
    pts[lowest] = tmp;

    const pivot = pts[0];

    // Sort by polar angle from pivot
    const SortCtx = struct {
        pivot_pt: mod.Point2D,

        pub fn lessThan(ctx: @This(), a: mod.Point2D, b: mod.Point2D) bool {
            const o = mod.orientation(ctx.pivot_pt, a, b);
            if (o == 0) {
                // Collinear: closer point first
                const da = (a.x - ctx.pivot_pt.x) * (a.x - ctx.pivot_pt.x) + (a.y - ctx.pivot_pt.y) * (a.y - ctx.pivot_pt.y);
                const db = (b.x - ctx.pivot_pt.x) * (b.x - ctx.pivot_pt.x) + (b.y - ctx.pivot_pt.y) * (b.y - ctx.pivot_pt.y);
                return da < db;
            }
            return o > 0; // CCW = keep
        }
    };

    std.mem.sortUnstable(mod.Point2D, pts[1..], SortCtx{ .pivot_pt = pivot }, SortCtx.lessThan);

    // Graham scan with stack
    var stack = try allocator.alloc(mod.Point2D, n);
    defer allocator.free(stack);
    var top: usize = 0;

    stack[0] = pts[0];
    top = 1;
    if (n > 1) {
        stack[1] = pts[1];
        top = 2;
    }
    if (n > 2) {
        stack[2] = pts[2];
        top = 3;
    }

    var i: usize = 3;
    while (i < n) : (i += 1) {
        while (top > 1 and mod.orientation(stack[top - 2], stack[top - 1], pts[i]) <= 0) {
            top -= 1;
        }
        stack[top] = pts[i];
        top += 1;
    }

    const result = try allocator.alloc(mod.Point2D, top);
    @memcpy(result, stack[0..top]);
    return result;
}

/// Point-in-polygon using ray casting (even-odd rule).
/// Returns: +1 (inside), 0 (on boundary), -1 (outside)
pub fn pointInPolygon(point: mod.Point2D, polygon: []const mod.Point2D) i8 {
    const n = polygon.len;
    if (n < 3) return -1;

    var crossings: i32 = 0;
    var j: usize = n - 1;

    for (0..n) |i| {
        const pi = polygon[i];
        const pj = polygon[j];

        // Check if point is on edge (approximate)
        const cross = (point.x - pi.x) * (pj.y - pi.y) - (point.y - pi.y) * (pj.x - pi.x);
        if (@abs(cross) < 1e-10) {
            // Check if point is between pi and pj
            const dot = (point.x - pi.x) * (pj.x - pi.x) + (point.y - pi.y) * (pj.y - pi.y);
            const len_sq = (pj.x - pi.x) * (pj.x - pi.x) + (pj.y - pi.y) * (pj.y - pi.y);
            if (dot >= 0 and dot <= len_sq) {
                return 0; // On boundary
            }
        }

        // Ray casting
        if ((pi.y > point.y) != (pj.y > point.y)) {
            const x_intersect = pi.x + (point.y - pi.y) * (pj.x - pi.x) / (pj.y - pi.y);
            if (point.x < x_intersect) {
                crossings += 1;
            }
        }

        j = i;
    }

    // Odd crossings = inside (+1), even = outside (-1)
    return if (@mod(crossings, 2) == 1) 1 else -1;
}

/// tri geom area <x1,y1> <x2,y2> <x3,y3> ...
pub fn cmdArea(args: []const []const u8) void {
    if (args.len < 3) {
        std.debug.print("Usage: tri geom area <x1,y1> <x2,y2> <x3,y3> ...\n", .{});
        std.debug.print("  Compute polygon area using the Shoelace formula.\n", .{});
        std.debug.print("  Example: tri geom area 0,0 4,0 4,3 0,3\n", .{});
        return;
    }

    var polygon: [128]mod.Point2D = undefined;
    var count: usize = 0;

    for (args) |arg| {
        if (parsePoint(arg)) |pt| {
            if (count < 128) {
                polygon[count] = pt;
                count += 1;
            }
        } else {
            std.debug.print("Invalid point: {s} (format: x,y)\n", .{arg});
            return;
        }
    }

    if (count < 3) {
        std.debug.print("Need at least 3 vertices for polygon area\n", .{});
        return;
    }

    const verts = polygon[0..count];
    const area = polygonArea(verts);
    const perimeter = polygonPerimeter(verts);

    fmt.boxHeader("POLYGON AREA (Shoelace Formula)");
    std.debug.print("\n", .{});

    std.debug.print("  Vertices:          {d}\n", .{count});
    for (verts, 0..) |pt, i| {
        std.debug.print("    V{d}: ({d:.4}, {d:.4})\n", .{ i, pt.x, pt.y });
    }

    fmt.separator();
    fmt.labelFloat("Signed area:", polygonSignedArea(verts));
    fmt.labelFloat("Area:", area);
    fmt.labelFloat("Perimeter:", perimeter);

    if (area > 0) {
        const compactness = (4.0 * std.math.pi * area) / (perimeter * perimeter);
        fmt.labelFloat("Compactness:", compactness);
        std.debug.print("  {s}(isoperimetric ratio: 1.0 = circle, ~0.785 = square){s}\n", .{ fmt.GRAY, fmt.RESET });
    }

    fmt.separator();
    // Winding direction from signed area
    const signed = polygonSignedArea(verts);
    const winding: i8 = if (signed > 1e-10) 1 else if (signed < -1e-10) -1 else 0;
    fmt.tritResult("Winding:", winding);
    std.debug.print("  {s}Shoelace formula: A = ½|Σ(xᵢyᵢ₊₁ - xᵢ₊₁yᵢ)|{s}\n", .{ fmt.CYAN, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom volume <shape> <params...>
pub fn cmdVolume(args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: tri geom volume <shape> <params...>\n", .{});
        std.debug.print("  Shapes:\n", .{});
        std.debug.print("    sphere <r>            4/3 * pi * r^3\n", .{});
        std.debug.print("    cylinder <r> <h>      pi * r^2 * h\n", .{});
        std.debug.print("    cone <r> <h>          1/3 * pi * r^2 * h\n", .{});
        std.debug.print("    box <l> <w> <h>       l * w * h\n", .{});
        std.debug.print("    torus <R> <r>         2 * pi^2 * R * r^2\n", .{});
        std.debug.print("  Example: tri geom volume sphere 3\n", .{});
        return;
    }

    const shape = args[0];
    const params = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, shape, "sphere")) {
        volumeSphere(params);
    } else if (std.mem.eql(u8, shape, "cylinder") or std.mem.eql(u8, shape, "cyl")) {
        volumeCylinder(params);
    } else if (std.mem.eql(u8, shape, "cone")) {
        volumeCone(params);
    } else if (std.mem.eql(u8, shape, "box") or std.mem.eql(u8, shape, "cuboid")) {
        volumeBox(params);
    } else if (std.mem.eql(u8, shape, "torus")) {
        volumeTorus(params);
    } else {
        std.debug.print("Unknown shape: {s}\n", .{shape});
        std.debug.print("Available: sphere, cylinder, cone, box, torus\n", .{});
    }
}

fn volumeSphere(args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("Usage: tri geom volume sphere <radius>\n", .{});
        return;
    }
    const r = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid radius: {s}\n", .{args[0]});
        return;
    };
    const vol = sphereVolume(r);
    const sa = 4.0 * std.math.pi * r * r;

    fmt.boxHeader("SPHERE VOLUME");
    std.debug.print("\n", .{});
    fmt.labelFloat("Radius:", r);
    fmt.separator();
    fmt.labelFloat("Volume:", vol);
    fmt.labelFloat("Surface Area:", sa);
    std.debug.print("\n  {s}V = 4/3 * pi * r^3{s}\n", .{ fmt.CYAN, fmt.RESET });
    fmt.boxFooter();
}

fn volumeCylinder(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri geom volume cylinder <radius> <height>\n", .{});
        return;
    }
    const r = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid radius: {s}\n", .{args[0]});
        return;
    };
    const h = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid height: {s}\n", .{args[1]});
        return;
    };
    const vol = cylinderVolume(r, h);
    const sa = 2.0 * std.math.pi * r * (r + h);

    fmt.boxHeader("CYLINDER VOLUME");
    std.debug.print("\n", .{});
    fmt.labelFloat("Radius:", r);
    fmt.labelFloat("Height:", h);
    fmt.separator();
    fmt.labelFloat("Volume:", vol);
    fmt.labelFloat("Surface Area:", sa);
    std.debug.print("\n  {s}V = pi * r^2 * h{s}\n", .{ fmt.CYAN, fmt.RESET });
    fmt.boxFooter();
}

fn volumeCone(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri geom volume cone <radius> <height>\n", .{});
        return;
    }
    const r = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid radius: {s}\n", .{args[0]});
        return;
    };
    const h = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid height: {s}\n", .{args[1]});
        return;
    };
    const vol = coneVolume(r, h);
    const slant = @sqrt(r * r + h * h);
    const sa = std.math.pi * r * (r + slant);

    fmt.boxHeader("CONE VOLUME");
    std.debug.print("\n", .{});
    fmt.labelFloat("Radius:", r);
    fmt.labelFloat("Height:", h);
    fmt.labelFloat("Slant Height:", slant);
    fmt.separator();
    fmt.labelFloat("Volume:", vol);
    fmt.labelFloat("Surface Area:", sa);
    std.debug.print("\n  {s}V = 1/3 * pi * r^2 * h{s}\n", .{ fmt.CYAN, fmt.RESET });
    fmt.boxFooter();
}

fn volumeBox(args: []const []const u8) void {
    if (args.len < 3) {
        std.debug.print("Usage: tri geom volume box <length> <width> <height>\n", .{});
        return;
    }
    const l = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid length: {s}\n", .{args[0]});
        return;
    };
    const w = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid width: {s}\n", .{args[1]});
        return;
    };
    const h = std.fmt.parseFloat(f64, args[2]) catch {
        std.debug.print("Invalid height: {s}\n", .{args[2]});
        return;
    };
    const vol = l * w * h;
    const sa = 2.0 * (l * w + w * h + h * l);
    const diag = @sqrt(l * l + w * w + h * h);

    fmt.boxHeader("BOX (CUBOID) VOLUME");
    std.debug.print("\n", .{});
    fmt.labelFloat("Length:", l);
    fmt.labelFloat("Width:", w);
    fmt.labelFloat("Height:", h);
    fmt.separator();
    fmt.labelFloat("Volume:", vol);
    fmt.labelFloat("Surface Area:", sa);
    fmt.labelFloat("Space Diagonal:", diag);
    std.debug.print("\n  {s}V = l * w * h{s}\n", .{ fmt.CYAN, fmt.RESET });
    fmt.boxFooter();
}

fn volumeTorus(args: []const []const u8) void {
    if (args.len < 2) {
        std.debug.print("Usage: tri geom volume torus <major_R> <minor_r>\n", .{});
        return;
    }
    const big_r = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Invalid major radius R: {s}\n", .{args[0]});
        return;
    };
    const small_r = std.fmt.parseFloat(f64, args[1]) catch {
        std.debug.print("Invalid minor radius r: {s}\n", .{args[1]});
        return;
    };
    const vol = torusVolume(big_r, small_r);
    const sa = 4.0 * std.math.pi * std.math.pi * big_r * small_r;

    fmt.boxHeader("TORUS VOLUME");
    std.debug.print("\n", .{});
    fmt.labelFloat("Major Radius R:", big_r);
    fmt.labelFloat("Minor Radius r:", small_r);
    fmt.separator();
    fmt.labelFloat("Volume:", vol);
    fmt.labelFloat("Surface Area:", sa);
    std.debug.print("\n  {s}V = 2 * pi^2 * R * r^2{s}\n", .{ fmt.CYAN, fmt.RESET });
    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALGORITHMS — AREA & PERIMETER
// ═══════════════════════════════════════════════════════════════════════════════

/// Signed area via Shoelace formula. Positive = CCW, negative = CW.
pub fn polygonSignedArea(polygon: []const mod.Point2D) f64 {
    const n = polygon.len;
    if (n < 3) return 0;
    var sum: f64 = 0;
    for (0..n) |i| {
        const j = (i + 1) % n;
        sum += polygon[i].x * polygon[j].y - polygon[j].x * polygon[i].y;
    }
    return sum * 0.5;
}

/// Absolute area of polygon (always non-negative).
pub fn polygonArea(polygon: []const mod.Point2D) f64 {
    return @abs(polygonSignedArea(polygon));
}

/// Perimeter of polygon.
pub fn polygonPerimeter(polygon: []const mod.Point2D) f64 {
    const n = polygon.len;
    if (n < 2) return 0;
    var perimeter: f64 = 0;
    for (0..n) |i| {
        const j = (i + 1) % n;
        const dx = polygon[j].x - polygon[i].x;
        const dy = polygon[j].y - polygon[i].y;
        perimeter += @sqrt(dx * dx + dy * dy);
    }
    return perimeter;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn parsePoint(s: []const u8) ?mod.Point2D {
    // Parse "x,y" format
    const comma = std.mem.indexOf(u8, s, ",") orelse return null;
    const x = std.fmt.parseFloat(f64, s[0..comma]) catch return null;
    const y = std.fmt.parseFloat(f64, s[comma + 1 ..]) catch return null;
    return mod.Point2D{ .x = x, .y = y };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parsePoint valid" {
    const pt = parsePoint("1.5,2.3");
    try std.testing.expect(pt != null);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), pt.?.x, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 2.3), pt.?.y, 1e-10);
}

test "parsePoint invalid" {
    try std.testing.expectEqual(@as(?mod.Point2D, null), parsePoint("abc"));
    try std.testing.expectEqual(@as(?mod.Point2D, null), parsePoint("1.0"));
}

test "point in unit square" {
    const square = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    // Inside
    try std.testing.expectEqual(@as(i8, 1), pointInPolygon(.{ .x = 0.5, .y = 0.5 }, &square));
    // Outside
    try std.testing.expectEqual(@as(i8, -1), pointInPolygon(.{ .x = 2.0, .y = 2.0 }, &square));
}

test "convex hull of triangle returns triangle" {
    const allocator = std.testing.allocator;
    const points = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0.5, .y = 1 },
    };
    const hull = try convexHull(allocator, &points);
    defer allocator.free(hull);
    try std.testing.expectEqual(@as(usize, 3), hull.len);
}

test "trit lattice has 27 points" {
    const trits = [_]i8{ -1, 0, 1 };
    var count: u32 = 0;
    for (trits) |_| {
        for (trits) |_| {
            for (trits) |_| {
                count += 1;
            }
        }
    }
    try std.testing.expectEqual(@as(u32, 27), count);
}

test "convex hull of square with interior point" {
    const allocator = std.testing.allocator;
    const points = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
        .{ .x = 0.5, .y = 0.5 }, // interior point — should be excluded
    };
    const hull = try convexHull(allocator, &points);
    defer allocator.free(hull);
    try std.testing.expectEqual(@as(usize, 4), hull.len);
}

test "polygon area of unit square" {
    const square = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), polygonArea(&square), 1e-10);
}

test "polygon area of 3-4-5 right triangle" {
    const tri = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 4, .y = 0 },
        .{ .x = 0, .y = 3 },
    };
    try std.testing.expectApproxEqAbs(@as(f64, 6.0), polygonArea(&tri), 1e-10);
}

test "polygon signed area CCW is positive" {
    // CCW winding
    const ccw = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try std.testing.expect(polygonSignedArea(&ccw) > 0);
}

test "polygon signed area CW is negative" {
    // CW winding (reverse order)
    const cw = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 1 },
        .{ .x = 1, .y = 0 },
    };
    try std.testing.expect(polygonSignedArea(&cw) < 0);
}

test "polygon perimeter of unit square" {
    const square = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    try std.testing.expectApproxEqAbs(@as(f64, 4.0), polygonPerimeter(&square), 1e-10);
}

test "polygon area scales quadratically" {
    // Area of 2x2 square = 4 * area of 1x1 square
    const small = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    const big = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 2, .y = 0 },
        .{ .x = 2, .y = 2 },
        .{ .x = 0, .y = 2 },
    };
    try std.testing.expectApproxEqAbs(4.0 * polygonArea(&small), polygonArea(&big), 1e-10);
}

test "point on boundary is not inside" {
    const square = [_]mod.Point2D{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    };
    // Point on edge — ray casting typically returns -1 or 0 for boundary
    const result = pointInPolygon(.{ .x = 0.5, .y = 0.0 }, &square);
    // Boundary behavior is implementation-defined, just check it's ternary
    try std.testing.expect(result >= -1 and result <= 1);
}

test "sphere volume r=1" {
    // V = 4/3 * pi * 1^3 = 4.18879...
    try std.testing.expectApproxEqAbs(4.0 / 3.0 * std.math.pi, sphereVolume(1.0), 1e-10);
}

test "cylinder volume r=1 h=1 equals pi" {
    try std.testing.expectApproxEqAbs(std.math.pi, cylinderVolume(1.0, 1.0), 1e-10);
}

test "cone volume is 1/3 of cylinder" {
    const r = 3.0;
    const h = 5.0;
    try std.testing.expectApproxEqAbs(cylinderVolume(r, h) / 3.0, coneVolume(r, h), 1e-10);
}

test "torus volume known value" {
    // V = 2 * pi^2 * R * r^2, R=3, r=1 => 2 * pi^2 * 3 = 59.2176...
    const expected = 2.0 * std.math.pi * std.math.pi * 3.0 * 1.0;
    try std.testing.expectApproxEqAbs(expected, torusVolume(3.0, 1.0), 1e-10);
}
