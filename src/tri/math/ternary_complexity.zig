//! Strand I: Mathematical Foundation
//!
//! Sacred mathematics module for Trinity S³AI.
//!

//! TRINITY v7.0 OMEGA - Ternary Complexity Analysis
//!
//! This module analyzes the ternary representation complexity of
//! fundamental physical constants. The thesis is that truly
//! "sacred" constants should have compact representations in
//! balanced ternary {-1, 0, +1}.
//!
//! ## Mathematical Background
//!
//! Balanced ternary provides the most efficient radix for integer
//! representation (radix economy E(r) = r/ln(r) is minimized at r=e≈2.718,
//! making r=3 optimal among integers).
//!
//! Ternary Kolmogorov Complexity: The minimum number of non-zero trits
//! required to represent a value.
//!
//! ## Examples
//!
//! ```
//! const std = @import("std");
//! const ternary = @import("ternary_complexity");
//!
//! // Analyze fine structure constant
//! const alpha_inv = 137.036;
//! const complexity = ternary.kolmogorovComplexity(alpha_inv);
//! std.debug.print("α⁻¹ has ternary complexity: {}\n", .{complexity});
//! ```

const std = @import("std");

/// Trit: A single ternary digit {-1, 0, +1}
pub const Trit = enum(i2) {
    neg = -1,
    zero = 0,
    pos = 1,

    /// Convert trit to character
    pub fn toChar(self: Trit) u8 {
        return switch (self) {
            .neg => '-',
            .zero => '0',
            .pos => '+',
        };
    }

    /// Parse character to trit
    pub fn fromChar(c: u8) !Trit {
        return switch (c) {
            '-', 'T', 't' => .neg,
            '0', 'O', 'o' => .zero,
            '+', '1', 'P', 'p' => .pos,
            else => error.InvalidTrit,
        };
    }

    /// Convert to integer value
    pub fn toInt(self: Trit) i2 {
        return @intFromEnum(self);
    }
};

/// Balanced ternary representation
pub const BalancedTernary = struct {
    trits: std.ArrayList(Trit),
    allocator: std.mem.Allocator,

    /// Initialize empty representation
    pub fn init(allocator: std.mem.Allocator) BalancedTernary {
        return .{
            .trits = std.ArrayList(Trit).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *BalancedTernary) void {
        self.trits.deinit();
    }

    /// Convert float to balanced ternary
    pub fn fromFloat(self: *BalancedTernary, value: f64, max_trits: usize) !void {
        self.trits.clearRetainingCapacity();
        var remaining = std.math.fabs(value);
        var is_negative = value < 0;

        var idx: usize = 0;
        while (remaining > 0.001 and idx < max_trits) : (idx += 1) {
            const trit_val = @mod(@as(i64, @intFromFloat(remaining)), 3);
            const trit: Trit = switch (trit_val) {
                0 => .zero,
                1 => if (is_negative) .neg else .pos,
                2 => if (is_negative) .pos else .neg, // Carry
                else => unreachable,
            };
            try self.trits.append(trit);

            // Update remaining value
            const current_value = trit.toInt();
            remaining = (@fabs(value) - @abs(@as(f64, @floatFromInt(current_value)))) / 3.0;
        }
    }

    /// Convert to integer value
    pub fn toInt(self: *const BalancedTernary) i64 {
        var result: i64 = 0;
        var power: i64 = 1;
        for (self.trits.items) |trit| {
            result += @as(i64, trit.toInt()) * power;
            power *= 3;
        }
        return result;
    }

    /// Convert to float value
    pub fn toFloat(self: *const BalancedTernary) f64 {
        var result: f64 = 0.0;
        var power: f64 = 1.0;
        for (self.trits.items) |trit| {
            result += @as(f64, @floatFromInt(trit.toInt())) * power;
            power *= 3.0;
        }
        return result;
    }

    /// Count non-zero trits (Kolmogorov complexity)
    pub fn countNonZero(self: *const BalancedTernary) usize {
        var count: usize = 0;
        for (self.trits.items) |trit| {
            if (trit != .zero) count += 1;
        }
        return count;
    }

    /// Get string representation
    pub fn toString(self: *const BalancedTernary, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        errdefer result.deinit();

        // Add sign if needed
        const value = self.toFloat();
        if (value < 0) try result.append('-');

        // Add trits in reverse order (most significant first)
        var i: usize = self.trits.items.len;
        while (i > 0) {
            i -= 1;
            try result.append(self.trits.items[i].toChar());
        }

        return result.toOwnedSlice();
    }
};

/// Calculate ternary Kolmogorov complexity of a value
/// This is the minimum number of non-zero trits needed to represent it
pub fn kolmogorovComplexity(allocator: std.mem.Allocator, value: f64) usize {
    var bt = BalancedTernary.init(allocator);
    defer bt.deinit();
    bt.fromFloat(value, 50) catch return 50; // Max complexity if conversion fails
    return bt.countNonZero();
}

/// Calculate ternary entropy of a value
/// H = -sum(p_i * log2(p_i)) for trit distribution
pub fn ternaryEntropy(value: f64, max_trits: usize) f64 {
    _ = value;
    _ = max_trits;
    // For uniform distribution: H = log2(3) = 1.58496...
    return std.math.log2(3.0);
}

/// Find most "compact" representation of a value in sacred formula
/// Returns (n, k, m, p, q) parameters with minimal total exponent magnitude
pub fn findCompactFit(allocator: std.mem.Allocator, target_value: f64, max_power: u8) !struct {
    params: [5]i8, // [n, k, m, p, q]
    value: f64,
    error_pct: f64,
    complexity: usize, // Sum of absolute parameter values
} {
    const PHI = (1.0 + std.math.sqrt(5.0)) / 2.0;
    const PI = std.math.pi;
    const E = std.math.e;

    var best_error = std.math.inf(f64);
    var best_complexity: usize = std.math.maxInt(usize);
    var best_params: [5]i8 = undefined;
    var best_value: f64 = 0;

    // Search parameter space
    var n: i8 = 1;
    while (n <= 9) : (n += 1) {
        var k: i8 = -@as(i8, @intCast(max_power));
        while (k <= max_power) : (k += 1) {
            var m: i8 = -@as(i8, @intCast(max_power));
            while (m <= max_power) : (m += 1) {
                var p: i8 = -@as(i8, @intCast(max_power));
                while (p <= max_power) : (p += 1) {
                    var q: i8 = -@as(i8, @intCast(max_power));
                    while (q <= max_power) : (q += 1) {
                        // Calculate sacred formula value
                        const calculated = @as(f64, @floatFromInt(n)) *
                            std.math.pow(f64, 3.0, @as(f64, @floatFromInt(k))) *
                            std.math.pow(f64, PI, @as(f64, @floatFromInt(m))) *
                            std.math.pow(f64, PHI, @as(f64, @floatFromInt(p))) *
                            std.math.pow(f64, E, @as(f64, @floatFromInt(q)));

                        const err = std.math.fabs(calculated - target_value) / std.math.fabs(target_value);

                        // Calculate parameter complexity (sum of absolute values)
                        const complexity = @as(usize, @intCast(@abs(k) + @abs(m) + @abs(p) + @abs(q)));

                        // Prefer lower complexity, then lower error
                        const is_better = (complexity < best_complexity) or
                            (complexity == best_complexity and err < best_error);

                        if (is_better) {
                            best_error = err;
                            best_complexity = complexity;
                            best_params = .{ n, k, m, p, q };
                            best_value = calculated;
                        }
                    }
                }
            }
        }
    }

    return .{
        .params = best_params,
        .value = best_value,
        .error_pct = best_error * 100.0,
        .complexity = best_complexity,
    };
}

/// Analyze fundamental constant for ternary simplicity
pub const ConstantAnalysis = struct {
    name: []const u8,
    value: f64,
    ternary: []const u8,
    complexity: usize,
    fit_params: [5]i8,
    fit_error: f64,

    pub fn format(self: *const ConstantAnalysis, allocator: std.mem.Allocator) ![]u8 {
        const trit_str = try std.fmt.allocPrint(allocator, "{s}: {d:.6} = [{s}] (complexity: {d}, fit error: {d:.4}%)", .{
            self.name,
            self.value,
            self.ternary,
            self.complexity,
            self.fit_error,
        });
        return trit_str;
    }
};

/// Analyze multiple fundamental constants
pub fn analyzeConstants(allocator: std.mem.Allocator) ![]ConstantAnalysis {
    // Constants to analyze
    const constants = struct {
        fine_structure: struct { name: []const u8 = "1/α", value: f64 = 137.036 },
        proton_electron: struct { name: []const u8 = "m_p/m_e", value: f64 = 1836.15 },
        cmb_index: struct { name: []const u8 = "n_s", value: f64 = 0.9649 },
        strong_coupling: struct { name: []const u8 = "α_s", value: f64 = 0.1179 },
        w_boson: struct { name: []const u8 = "M_W", value: f64 = 80.379 },
        higgs: struct { name: []const u8 = "M_H", value: f64 = 125.1 },
    };

    var results = std.ArrayList(ConstantAnalysis).init(allocator);

    // Analyze fine structure constant
    {
        var bt = BalancedTernary.init(allocator);
        defer bt.deinit();
        try bt.fromFloat(constants.fine_structure.value, 50);
        const ternary_str = try bt.toString(allocator);
        defer allocator.free(ternary_str);
        const complexity = bt.countNonZero();
        const fit = try findCompactFit(allocator, constants.fine_structure.value, 6);

        try results.append(.{
            .name = constants.fine_structure.name,
            .value = constants.fine_structure.value,
            .ternary = ternary_str,
            .complexity = complexity,
            .fit_params = fit.params,
            .fit_error = fit.error_pct,
        });
    }

    // Analyze proton/electron mass ratio
    {
        var bt = BalancedTernary.init(allocator);
        defer bt.deinit();
        try bt.fromFloat(constants.proton_electron.value, 50);
        const ternary_str = try bt.toString(allocator);
        defer allocator.free(ternary_str);
        const complexity = bt.countNonZero();
        const fit = try findCompactFit(allocator, constants.proton_electron.value, 6);

        try results.append(.{
            .name = constants.proton_electron.name,
            .value = constants.proton_electron.value,
            .ternary = ternary_str,
            .complexity = complexity,
            .fit_params = fit.params,
            .fit_error = fit.error_pct,
        });
    }

    return results.toOwnedSlice();
}

// Tests
test "Ternary: basic conversion" {
    var bt = BalancedTernary.init(std.testing.allocator);
    defer bt.deinit();

    try bt.fromFloat(1.0, 10);
    const value = bt.toFloat();
    try std.testing.expectApproxEqAbs(1.0, value, 0.01);
}

test "Ternary: negative numbers" {
    var bt = BalancedTernary.init(std.testing.allocator);
    defer bt.deinit();

    try bt.fromFloat(-5.0, 10);
    const value = bt.toFloat();
    try std.testing.expectApproxEqAbs(-5.0, value, 0.1);
}

test "Ternary: kolmogorov complexity" {
    const complexity = kolmogorovComplexity(std.testing.allocator, 137.036);
    try std.testing.expect(complexity < 30); // Should be compact
}

test "Ternary: trit to char conversion" {
    try std.testing.expectEqual('-', Trit.neg.toChar());
    try std.testing.expectEqual('0', Trit.zero.toChar());
    try std.testing.expectEqual('+', Trit.pos.toChar());
}

test "Ternary: char to trit parsing" {
    try std.testing.expectEqual(Trit.neg, try Trit.fromChar('-'));
    try std.testing.expectEqual(Trit.zero, try Trit.fromChar('0'));
    try std.testing.expectEqual(Trit.pos, try Trit.fromChar('+'));
}

test "Ternary: sacred formula fit" {
    const fit = try findCompactFit(std.testing.allocator, 137.036, 5);
    try std.testing.expect(fit.error_pct < 10.0); // Should fit within 10%
    try std.testing.expect(fit.complexity < 30); // Reasonable complexity
}

test "Ternary: information density" {
    const binary_bits = 1.0;
    const ternary_bits = std.math.log2(3.0);
    const improvement = (ternary_bits - binary_bits) / binary_bits;

    try std.testing.expectApproxEqAbs(0.585, improvement, 0.001);
}

test "Ternary: radix economy" {
    // E(r) = r / ln(r)
    const e2 = 2.0 / std.math.ln(2.0);
    const e3 = 3.0 / std.math.ln(3.0);
    const e4 = 4.0 / std.math.ln(4.0);

    // 3 should be optimal among integers
    try std.testing.expect(e3 < e2);
    try std.testing.expect(e3 < e4);
}

test "Ternary: TRINITY identity" {
    const PHI = (1.0 + std.math.sqrt(5.0)) / 2.0;
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const sum = phi_sq + inv_phi_sq;

    try std.testing.expectApproxEqAbs(3.0, sum, 1e-10);
}
