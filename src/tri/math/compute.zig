// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — COMPUTE MODULE
// ═══════════════════════════════════════════════════════════════════════════════
// spiral, verify, compare operations
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const parent_mod = @import("mod.zig");
const format = @import("format.zig");
const eval = @import("eval.zig");

// stdout writer provided by caller

// ═══════════════════════════════════════════════════════════════════════════════
// SPIRAL
// ═══════════════════════════════════════════════════════════════════════════════

pub const PhiSpiralResult = struct {
    n: u32,
    angle: f64,
    angle_deg: f64,
    radius: f64,
    x: f64,
    y: f64,
};

pub fn computeSpiral(n: u32) PhiSpiralResult {
    const spiral = parent_mod.phiSpiral(n);
    const angle_deg = spiral.angle * 180.0 / parent_mod.PI;

    return .{
        .n = n,
        .angle = spiral.angle,
        .angle_deg = angle_deg,
        .radius = spiral.radius,
        .x = spiral.x,
        .y = spiral.y,
    };
}

pub fn printSpiral(writer: anytype, n: u32) !void {
    const result = computeSpiral(n);

    try writer.writeAll(format.colors.gold);
    try writer.writeAll("╔══════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║                       φ-SPIRAL                                ║\n");
    try writer.writeAll("╠══════════════════════════════════════════════════════════════╣\n");
    try writer.writeAll(format.colors.reset);

    try writer.print("  n      : {d}\n", .{result.n});
    try writer.print("  angle  : {d:.[1]}° ({d:.[4]} rad)\n", .{ result.angle_deg, 2, result.angle, 6 });
    try writer.print("  radius : {d:.[2]}\n", .{result.radius, 2});
    try writer.print("  x      : {d:.[3]}\n", .{result.x, 6 });
    try writer.print("  y      : {d:.[3]}\n", .{result.y, 6 });

    try writer.writeAll(format.colors.gold);
    try writer.writeAll("╚══════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll(format.colors.reset);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerifyResult = struct {
    name: []const u8,
    formula: []const u8,
    expected: []const u8,
    actual: []const u8,
    passed: bool,
};

pub fn verifyIdentities(allocator: std.mem.Allocator) ![]VerifyResult {
    const results = try allocator.alloc(VerifyResult, 8);

    // Trinity Identity
    const trinity = parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED;
    results[0] = .{
        .name = "Trinity Identity",
        .formula = "φ² + 1/φ² = 3",
        .expected = "3.0",
        .actual = try std.fmt.allocPrint(allocator, "{d:.[1]}", .{ trinity, 6 }),
        .passed = std.math.approxEqAbs(f64, trinity, 3.0, 0.0001),
    };

    // Phi Squared
    const phi_sq_check = parent_mod.PHI_SQUARED - parent_mod.PHI - 1.0;
    results[1] = .{
        .name = "Phi Squared",
        .formula = "φ² = φ + 1",
        .expected = "true",
        .actual = try std.fmt.allocPrint(allocator, "φ² - φ - 1 = {d:.[1]}", .{ phi_sq_check, 10 }),
        .passed = std.math.approxEqAbs(f64, phi_sq_check, 0.0, 0.0001),
    };

    // Phi Inverse
    const phi_inv_check = 1.0 / parent_mod.PHI - (parent_mod.PHI - 1.0);
    results[2] = .{
        .name = "Phi Inverse",
        .formula = "1/φ = φ - 1",
        .expected = "true",
        .actual = try std.fmt.allocPrint(allocator, "1/φ - (φ - 1) = {d:.[1]}", .{ phi_inv_check, 10 }),
        .passed = std.math.approxEqAbs(f64, phi_inv_check, 0.0, 0.0001),
    };

    // Lucas Trinity
    const L2 = parent_mod.lucas(2);
    results[3] = .{
        .name = "Lucas Trinity",
        .formula = "L(2) = 3",
        .expected = "3",
        .actual = try std.fmt.allocPrint(allocator, "{d}", .{L2}),
        .passed = L2 == 3,
    };

    // Fibonacci Trinity
    const F4 = parent_mod.fibonacci(4);
    results[4] = .{
        .name = "Fibonacci Trinity",
        .formula = "F(4) = 3",
        .expected = "3",
        .actual = try std.fmt.allocPrint(allocator, "{d}", .{F4}),
        .passed = F4 == 3,
    };

    // Fibonacci Tryte Max
    const F7 = parent_mod.fibonacci(7);
    results[5] = .{
        .name = "Fibonacci Tryte Max",
        .formula = "F(7) = 13 = TRYTE_MAX",
        .expected = "13",
        .actual = try std.fmt.allocPrint(allocator, "{d}", .{F7}),
        .passed = F7 == 13,
    };

    // Transcendental Tryte
    const transcendental = parent_mod.TRANSCENDENTAL;
    results[6] = .{
        .name = "Transcendental Tryte",
        .formula = "π × φ × e ≈ 13.82 ≈ TRYTE_MAX",
        .expected = "~13.82",
        .actual = try std.fmt.allocPrint(allocator, "{d:.[1]}", .{ transcendental, 2 }),
        .passed = std.math.approxEqAbs(f64, transcendental, 13.82, 0.5),
    };

    // Lucas Phi Powers (check L(5))
    const L5 = parent_mod.lucas(5);
    const phi5_1 = std.math.pow(f64, parent_mod.PHI, 5);
    const phi5_2 = std.math.pow(f64, 1.0 / parent_mod.PHI, 5);
    const lucas_phi_check = L5 - @as(i64, @intFromFloat(phi5_1 + phi5_2));
    results[7] = .{
        .name = "Lucas Phi Powers",
        .formula = "L(5) = φ⁵ + 1/φ⁵",
        .expected = "11",
        .actual = try std.fmt.allocPrint(allocator, "{d} (diff: {d})", .{ L5, lucas_phi_check }),
        .passed = lucas_phi_check == 0,
    };

    return results;
}

pub fn printVerification(writer: anytype) !void {
    const allocator = std.heap.page_allocator;

    const results = try verifyIdentities(allocator);
    defer {
        for (results[1..]) |r| {
            allocator.free(r.actual);
        }
        allocator.free(results);
    }

    try writer.writeAll(format.colors.bold);
    try writer.writeAll("╔════════════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║              SACRED IDENTITY VERIFICATION                          ║\n");
    try writer.writeAll("╠════════════════════════════════════════════════════════════════════╣\n");
    try writer.writeAll(format.colors.reset);

    for (results) |r| {
        const status_color = if (r.passed) format.colors.green else format.colors.red;
        const status_symbol = if (r.passed) "✓" else "✗";

        try writer.writeAll(status_color);
        try writer.print(" {s} {s}\n", .{ status_symbol, r.name });
        try writer.writeAll(format.colors.reset);
        try writer.print("   Formula: {s}\n", .{r.formula});
        try writer.print("   Expected: {s}\n", .{r.expected});
        try writer.print("   Actual: {s}\n\n", .{r.actual});
    }

    try writer.writeAll(format.colors.bold);
    try writer.writeAll("╚════════════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll(format.colors.reset);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPARE
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printCompare(writer: anytype, max_n: usize) !void {
    const allocator = std.heap.page_allocator;

    try writer.writeAll(format.colors.bold);
    try writer.writeAll("╔════════════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║                    SEQUENCE COMPARISON                            ║\n");
    try writer.writeAll("╠════════════════════════════════════════════════════════════════════╣\n");
    try writer.writeAll(format.colors.reset);

    // Print header
    try writer.writeAll("  n     │ φⁿ                    │ F(n)                   │ L(n)                   \n");
    try writer.writeAll("────────┼───────────────────────┼───────────────────────┼───────────────────────\n");

    // Print each row
    var n: usize = 0;
    while (n <= max_n) : (n += 1) {
        // phi^n
        const phi_n = eval.phiPower(n);
        const phi_str = try std.fmt.allocPrint(allocator, "{d:.[1]}", .{ phi_n, 6 });

        // F(n)
        const fib_str = try eval.fibonacciBigInt(allocator, n);

        // L(n)
        const lucas_str = try eval.lucasBigInt(allocator, n);

        try writer.print("  {d:5} │ {s:21} │ {s:21} │ {s:21} \n", .{ n, phi_str, fib_str, lucas_str });

        allocator.free(phi_str);
        allocator.free(fib_str);
        allocator.free(lucas_str);
    }

    try writer.writeAll("╚════════════════════════════════════════════════════════════════════╝\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "spiral computation" {
    const result = computeSpiral(0);
    try std.testing.expectEqual(@as(u32, 0), result.n);
    try std.testing.expectApproxEqAbs(0.0, result.angle, 0.001);
    try std.testing.expectApproxEqAbs(30.0, result.radius, 0.001);
}

test "trinity verification" {
    const results = try verifyIdentities(std.testing.allocator);
    defer {
        for (results[1..]) |r| {
            std.testing.allocator.free(r.actual);
        }
        std.testing.allocator.free(results);
    }

    // First three should always pass
    try std.testing.expect(results[0].passed); // Trinity Identity
    try std.testing.expect(results[1].passed); // Phi Squared
    try std.testing.expect(results[2].passed); // Phi Inverse
}
