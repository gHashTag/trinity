//! tri/polynomial — Polynomial operations
//! Auto-generated from specs/tri/tri_polynomial.tri
//! TTT Dogfood v0.2 Stage 188

const std = @import("std");

/// Polynomial coefficients (index = power of x)
pub const Polynomial = struct {
    coeffs: []f64,
    allocator: std.mem.Allocator,

    /// Create polynomial from coefficients
    pub fn init(allocator: std.mem.Allocator, coeffs: []const f64) !Polynomial {
        const data = try allocator.alloc(f64, coeffs.len);
        @memcpy(data, coeffs);

        return .{
            .coeffs = data,
            .allocator = allocator,
        };
    }

    /// Evaluate polynomial at x (Horner's method)
    pub fn eval(p: *const Polynomial, x: f64) f64 {
        if (p.coeffs.len == 0) return 0;

        var result = p.coeffs[p.coeffs.len - 1];
        var i: usize = p.coeffs.len - 1;
        while (i > 0) : (i -= 1) {
            result = result * x + p.coeffs[i - 1];
        }

        return result;
    }

    /// Add two polynomials
    pub fn add(a: *Polynomial, b: *Polynomial, allocator: std.mem.Allocator) !Polynomial {
        const max_len = @max(a.coeffs.len, b.coeffs.len);
        const result = try allocator.alloc(f64, max_len);

        for (0..max_len) |i| {
            const av = if (i < a.coeffs.len) a.coeffs[i] else 0;
            const bv = if (i < b.coeffs.len) b.coeffs[i] else 0;
            result[i] = av + bv;
        }

        return .{
            .coeffs = result,
            .allocator = allocator,
        };
    }

    /// Multiply polynomials
    pub fn multiply(a: *Polynomial, b: *Polynomial, allocator: std.mem.Allocator) !Polynomial {
        if (a.coeffs.len == 0 or b.coeffs.len == 0) {
            return Polynomial.init(allocator, &[_]f64{0});
        }

        const result_len = a.coeffs.len + b.coeffs.len - 1;
        const result = try allocator.alloc(f64, result_len);
        @memset(result, 0);

        for (0..a.coeffs.len) |i| {
            for (0..b.coeffs.len) |j| {
                result[i + j] += a.coeffs[i] * b.coeffs[j];
            }
        }

        return .{
            .coeffs = result,
            .allocator = allocator,
        };
    }

    /// Compute derivative
    pub fn derivative(p: *Polynomial, allocator: std.mem.Allocator) !Polynomial {
        if (p.coeffs.len <= 1) {
            return Polynomial.init(allocator, &[_]f64{0});
        }

        const result = try allocator.alloc(f64, p.coeffs.len - 1);

        for (1..p.coeffs.len) |i| {
            result[i - 1] = @as(f64, @floatFromInt(i)) * p.coeffs[i];
        }

        return .{
            .coeffs = result,
            .allocator = allocator,
        };
    }

    /// Free polynomial
    pub fn deinit(p: *Polynomial) void {
        p.allocator.free(p.coeffs);
    }
};

test "polynomial eval" {
    // x^2 + 2x + 1 = (x+1)^2
    const coeffs = [_]f64{ 1, 2, 1 };
    var p = try Polynomial.init(std.testing.allocator, &coeffs);
    defer p.deinit();

    // At x=3: 9 + 6 + 1 = 16
    try std.testing.expectApproxEqAbs(@as(f64, 16), p.eval(3), 0.001);
}

test "polynomial add" {
    const c1 = [_]f64{ 1, 2 }; // 2x + 1
    const c2 = [_]f64{ 3, 4 }; // 4x + 3
    var p1 = try Polynomial.init(std.testing.allocator, &c1);
    defer p1.deinit();
    var p2 = try Polynomial.init(std.testing.allocator, &c2);
    defer p2.deinit();

    var result = try p1.add(&p2, std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.coeffs.len);
    try std.testing.expectApproxEqAbs(@as(f64, 4), result.coeffs[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 6), result.coeffs[1], 0.001);
}

test "polynomial multiply" {
    const c1 = [_]f64{ 1, 1 }; // x + 1
    const c2 = [_]f64{ 1, 1 }; // x + 1
    var p1 = try Polynomial.init(std.testing.allocator, &c1);
    defer p1.deinit();
    var p2 = try Polynomial.init(std.testing.allocator, &c2);
    defer p2.deinit();

    var result = try p1.multiply(&p2, std.testing.allocator);
    defer result.deinit();

    // (x+1)^2 = x^2 + 2x + 1
    try std.testing.expectEqual(@as(usize, 3), result.coeffs.len);
    try std.testing.expectApproxEqAbs(@as(f64, 1), result.coeffs[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2), result.coeffs[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1), result.coeffs[2], 0.001);
}

test "polynomial derivative" {
    const c = [_]f64{ 1, 2, 1 }; // x^2 + 2x + 1
    var p = try Polynomial.init(std.testing.allocator, &c);
    defer p.deinit();

    var result = try p.derivative(std.testing.allocator);
    defer result.deinit();

    // 2x + 2
    try std.testing.expectEqual(@as(usize, 2), result.coeffs.len);
    try std.testing.expectApproxEqAbs(@as(f64, 2), result.coeffs[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2), result.coeffs[1], 0.001);
}
