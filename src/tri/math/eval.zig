// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — EVAL MODULE
// ═══════════════════════════════════════════════════════════════════════════════
// phi^n, fib(n), lucas(n) computation
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const parent_mod = @import("mod.zig");
const format = @import("format.zig");

// stdout writer provided by caller

// ═══════════════════════════════════════════════════════════════════════════════
// PHI POWER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn phiPower(n: usize) f64 {
    return std.math.pow(f64, parent_mod.PHI, @floatFromInt(n));
}

pub fn printPhiPower(writer: anytype, n: usize) !void {
    const result = phiPower(n);

    try writer.print("phi^{d} = {d:.16}\n", .{ n, result });

    // Special notes
    if (n == 0) {
        try writer.writeAll("  Note: φ⁰ = 1\n");
    } else if (n == 1) {
        try writer.writeAll("  Note: φ¹ = φ\n");
    } else if (n == 2) {
        try writer.writeAll("  Note: φ² = φ + 1 ≈ 2.618\n");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI
// ═══════════════════════════════════════════════════════════════════════════════

pub fn fibonacciBigInt(allocator: std.mem.Allocator, n: usize) ![]const u8 {
    if (n < parent_mod.FIBONACCI_TABLE.len) {
        const value = parent_mod.FIBONACCI_TABLE[n];
        return std.fmt.allocPrint(allocator, "{d}", .{value});
    }

    // For large n, use the existing fibonacci function
    const value = parent_mod.fibonacci(@intCast(n));

    // Format with digit grouping
    const str = try std.fmt.allocPrint(allocator, "{d}", .{value});
    errdefer allocator.free(str);

    // Add commas every 3 digits from right
    const num_commas = (str.len - 1) / 3;
    const result_len = str.len + num_commas;
    var result = try allocator.alloc(u8, result_len);

    var write_pos: usize = 0;
    var count: usize = 0;
    var i: usize = str.len;
    while (i > 0) {
        if (count == 3) {
            result[write_pos] = ',';
            write_pos += 1;
            count = 0;
        }
        i -= 1;
        result[write_pos] = str[i];
        write_pos += 1;
        count += 1;
    }

    // Reverse the result
    std.mem.reverse(u8, result[0..write_pos]);

    return result[0..write_pos];
}

pub fn printFibonacci(writer: anytype, allocator: std.mem.Allocator, n: usize) !void {
    const formatted = try fibonacciBigInt(allocator, n);
    defer allocator.free(formatted);

    try writer.print("F({d}) = ", .{n});
    try writer.writeAll(formatted);

    const digit_count = formatted.len - @as(usize, @intCast(@divTrunc(formatted.len - 1, 3)));
    try writer.print(" [{d} digits]\n", .{digit_count});

    // Special notes
    if (n == 4) {
        try writer.writeAll("  * F(4) = 3 = TRINITY\n");
    } else if (n == 7) {
        try writer.writeAll("  * F(7) = 13 = TRYTE_MAX\n");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LUCAS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn lucasBigInt(allocator: std.mem.Allocator, n: usize) ![]const u8 {
    if (n < parent_mod.LUCAS_TABLE.len) {
        const value = parent_mod.LUCAS_TABLE[n];
        return std.fmt.allocPrint(allocator, "{d}", .{value});
    }

    // For large n, use the existing lucas function
    const value = parent_mod.lucas(@intCast(n));

    // Format with digit grouping
    const str = try std.fmt.allocPrint(allocator, "{d}", .{value});
    errdefer allocator.free(str);

    // Add commas every 3 digits from right
    const num_commas = (str.len - 1) / 3;
    const result_len = str.len + num_commas;
    var result = try allocator.alloc(u8, result_len);

    var write_pos: usize = 0;
    var count: usize = 0;
    var i: usize = str.len;
    while (i > 0) {
        if (count == 3) {
            result[write_pos] = ',';
            write_pos += 1;
            count = 0;
        }
        i -= 1;
        result[write_pos] = str[i];
        write_pos += 1;
        count += 1;
    }

    // Reverse the result
    std.mem.reverse(u8, result[0..write_pos]);

    return result[0..write_pos];
}

pub fn printLucas(writer: anytype, allocator: std.mem.Allocator, n: usize) !void {
    const formatted = try lucasBigInt(allocator, n);
    defer allocator.free(formatted);

    try writer.print("L({d}) = ", .{n});
    try writer.writeAll(formatted);

    const digit_count = formatted.len - @as(usize, @intCast(@divTrunc(formatted.len - 1, 3)));
    try writer.print(" [{d} digits]\n", .{digit_count});

    // Special notes
    if (n == 2) {
        try writer.writeAll("  * L(2) = 3 = TRINITY\n");
        try writer.writeAll("  * L(n) = phi^n + 1/phi^n (Binet's formula for Lucas)\n");
    } else if (n == 10) {
        try writer.writeAll("  * L(10) = 123 (Lucas number L(10))\n");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi power" {
    const p0 = phiPower(0);
    try std.testing.expectApproxEqAbs(1.0, p0, 0.001);

    const p1 = phiPower(1);
    try std.testing.expectApproxEqAbs(parent_mod.PHI, p1, 0.001);

    const p2 = phiPower(2);
    try std.testing.expectApproxEqAbs(parent_mod.PHI_SQUARED, p2, 0.001);
}

test "fibonacci small" {
    const result = try fibonacciBigInt(std.testing.allocator, 10);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("55", result);
}

test "lucas small" {
    const result = try lucasBigInt(std.testing.allocator, 10);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("123", result);
}
