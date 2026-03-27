//! tri/statistics — Statistical functions
//! Auto-generated from specs/tri/tri_statistics.tri
//! TTT Dogfood v0.2 Stage 186

const std = @import("std");

/// Arithmetic mean
pub fn mean(values: []const f64) f64 {
    if (values.len == 0) return 0;

    var sum: f64 = 0;
    for (values) |v| {
        sum += v;
    }
    return sum / @as(f64, @floatFromInt(values.len));
}

/// Sample variance
pub fn variance(values: []const f64) f64 {
    if (values.len <= 1) return 0;

    const m = mean(values);
    var sum_sq_diff: f64 = 0;

    for (values) |v| {
        const diff = v - m;
        sum_sq_diff += diff * diff;
    }

    return sum_sq_diff / @as(f64, @floatFromInt(values.len - 1));
}

/// Standard deviation
pub fn stdDev(values: []const f64) f64 {
    return std.math.sqrt(variance(values));
}

/// Median value
pub fn median(allocator: std.mem.Allocator, values: []const f64) !f64 {
    if (values.len == 0) return 0;

    const sorted = try allocator.alloc(f64, values.len);
    defer allocator.free(sorted);
    @memcpy(sorted, values);

    // Simple bubble sort
    var i: usize = 0;
    while (i < sorted.len - 1) : (i += 1) {
        var j: usize = 0;
        while (j < sorted.len - i - 1) : (j += 1) {
            if (sorted[j] > sorted[j + 1]) {
                const tmp = sorted[j];
                sorted[j] = sorted[j + 1];
                sorted[j + 1] = tmp;
            }
        }
    }

    const mid = sorted.len / 2;
    if (sorted.len % 2 == 0) {
        return (sorted[mid - 1] + sorted[mid]) / 2;
    } else {
        return sorted[mid];
    }
}

/// P-th percentile (0-100)
pub fn percentile(allocator: std.mem.Allocator, values: []const f64, p: f64) !f64 {
    if (values.len == 0) return 0;
    if (p < 0 or p > 100) return error.InvalidPercentile;

    const sorted = try allocator.alloc(f64, values.len);
    defer allocator.free(sorted);
    @memcpy(sorted, values);

    // Sort
    var i: usize = 0;
    while (i < sorted.len - 1) : (i += 1) {
        var j: usize = 0;
        while (j < sorted.len - i - 1) : (j += 1) {
            if (sorted[j] > sorted[j + 1]) {
                const tmp = sorted[j];
                sorted[j] = sorted[j + 1];
                sorted[j + 1] = tmp;
            }
        }
    }

    const idx = @as(usize, @intFromFloat(@floor(p / 100 * @as(f64, @floatFromInt(sorted.len - 1)))));
    return sorted[@min(idx, sorted.len - 1)];
}

/// Pearson correlation coefficient
pub fn correlation(x: []const f64, y: []const f64) f64 {
    if (x.len != y.len or x.len == 0) return 0;

    const mean_x = mean(x);
    const mean_y = mean(y);

    var numerator: f64 = 0;
    var sum_sq_x: f64 = 0;
    var sum_sq_y: f64 = 0;

    for (0..x.len) |i| {
        const dx = x[i] - mean_x;
        const dy = y[i] - mean_y;
        numerator += dx * dy;
        sum_sq_x += dx * dx;
        sum_sq_y += dy * dy;
    }

    const denominator = std.math.sqrt(sum_sq_x * sum_sq_y);
    if (denominator == 0) return 0;

    return numerator / denominator;
}

test "mean" {
    const values = [_]f64{ 1, 2, 3, 4, 5 };
    try std.testing.expectApproxEqAbs(@as(f64, 3), mean(&values), 0.001);
}

test "variance" {
    const values = [_]f64{ 1, 2, 3, 4, 5 };
    try std.testing.expectApproxEqAbs(@as(f64, 2.5), variance(&values), 0.001);
}

test "std dev" {
    const values = [_]f64{ 2, 4, 4, 4, 5, 5, 7, 9 };
    const result = stdDev(&values);
    // Population std dev of this set is approximately 2.138
    try std.testing.expect(result > 2 and result < 2.2);
}

test "median" {
    const values = [_]f64{ 3, 1, 4, 1, 5 };
    const m = try median(std.testing.allocator, &values);
    try std.testing.expectApproxEqAbs(@as(f64, 3), m, 0.001);
}

test "percentile" {
    const values = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const p50 = try percentile(std.testing.allocator, &values, 50);
    try std.testing.expectApproxEqAbs(@as(f64, 5), p50, 0.5);
}

test "correlation" {
    const x = [_]f64{ 1, 2, 3, 4, 5 };
    const y = [_]f64{ 2, 4, 6, 8, 10 };
    const r = correlation(&x, &y);
    try std.testing.expectApproxEqAbs(@as(f64, 1), r, 0.001);
}
