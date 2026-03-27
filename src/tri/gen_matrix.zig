//! tri/matrix — Matrix operations
//! Auto-generated from specs/tri/tri_matrix.tri
//! TTT Dogfood v0.2 Stage 187

const std = @import("std");

/// 2D matrix
pub const Matrix = struct {
    data: []f64,
    rows: usize,
    cols: usize,
    allocator: std.mem.Allocator,

    /// Create rows x cols matrix
    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        const data = try allocator.alloc(f64, rows * cols);
        @memset(data, 0);

        return .{
            .data = data,
            .rows = rows,
            .cols = cols,
            .allocator = allocator,
        };
    }

    /// Get element at (row, col)
    pub fn get(m: *const Matrix, row: usize, col: usize) f64 {
        if (row >= m.rows or col >= m.cols) return 0;
        return m.data[row * m.cols + col];
    }

    /// Set element at (row, col)
    pub fn set(m: *Matrix, row: usize, col: usize, value: f64) void {
        if (row >= m.rows or col >= m.cols) return;
        m.data[row * m.cols + col] = value;
    }

    /// Matrix multiplication
    pub fn multiply(a: *Matrix, b: *Matrix, allocator: std.mem.Allocator) !Matrix {
        if (a.cols != b.cols) return error.DimensionMismatch;

        var result = try Matrix.init(allocator, a.rows, b.cols);

        for (0..a.rows) |i| {
            for (0..b.cols) |j| {
                var sum: f64 = 0;
                for (0..a.cols) |k| {
                    sum += a.get(i, k) * b.get(k, j);
                }
                result.set(i, j, sum);
            }
        }

        return result;
    }

    /// Matrix transpose
    pub fn transpose(m: *Matrix, allocator: std.mem.Allocator) !Matrix {
        var result = try Matrix.init(allocator, m.cols, m.rows);

        for (0..m.rows) |i| {
            for (0..m.cols) |j| {
                result.set(j, i, m.get(i, j));
            }
        }

        return result;
    }

    /// Create identity matrix
    pub fn identity(allocator: std.mem.Allocator, size: usize) !Matrix {
        var result = try Matrix.init(allocator, size, size);

        for (0..size) |i| {
            result.set(i, i, 1);
        }

        return result;
    }

    /// Free matrix
    pub fn deinit(m: *Matrix) void {
        m.allocator.free(m.data);
    }
};

test "matrix init get set" {
    var m = try Matrix.init(std.testing.allocator, 2, 3);
    defer m.deinit();

    try std.testing.expectEqual(@as(usize, 2), m.rows);
    try std.testing.expectEqual(@as(usize, 3), m.cols);

    m.set(1, 2, 5.5);
    try std.testing.expectApproxEqAbs(@as(f64, 5.5), m.get(1, 2), 0.001);
}

test "matrix identity" {
    var m = try Matrix.identity(std.testing.allocator, 3);
    defer m.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 1), m.get(0, 0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0), m.get(0, 1), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1), m.get(1, 1), 0.001);
}

test "matrix transpose" {
    var m = try Matrix.init(std.testing.allocator, 2, 3);
    defer m.deinit();

    m.set(0, 0, 1);
    m.set(0, 1, 2);
    m.set(0, 2, 3);
    m.set(1, 0, 4);
    m.set(1, 1, 5);
    m.set(1, 2, 6);

    var mt = try m.transpose(std.testing.allocator);
    defer mt.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 1), mt.get(0, 0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 4), mt.get(0, 1), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2), mt.get(1, 0), 0.001);
}
