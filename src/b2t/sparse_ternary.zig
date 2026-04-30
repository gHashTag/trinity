const std = @import("std");

pub const Trit = enum(i8) { P = 1, Z = 0, N = -1 };

pub const SparseEntry = packed struct {
    row: u16,
    col: u16,
    value: Trit,
};

pub const SparseTernaryMatrix = struct {
    entries: []SparseEntry,
    rows: usize,
    cols: usize,
    nnz: usize,

    pub fn init(allocator: std.mem.Allocator, dense_rows: usize, dense_cols: usize, weights: []const Trit) !SparseTernaryMatrix {
        var nnz_count: usize = 0;
        for (weights) |w| {
            if (w != .Z) nnz_count += 1;
        }

        const entries = try allocator.alloc(SparseEntry, nnz_count);
        var idx: usize = 0;
        for (weights, 0..) |w, flat| {
            if (w == .Z) continue;
            const r = flat / dense_cols;
            const c = flat % dense_cols;
            entries[idx] = SparseEntry{
                .row = @intCast(r),
                .col = @intCast(c),
                .value = w,
            };
            idx += 1;
        }

        return .{
            .entries = entries,
            .rows = dense_rows,
            .cols = dense_cols,
            .nnz = nnz_count,
        };
    }

    pub fn deinit(self: *SparseTernaryMatrix, allocator: std.mem.Allocator) void {
        allocator.free(self.entries);
    }

    pub fn sparsity(self: *const SparseTernaryMatrix) f32 {
        const total: f32 = @floatFromInt(self.rows * self.cols);
        return 1.0 - @as(f32, @floatFromInt(self.nnz)) / total;
    }

    pub fn matmul(self: *const SparseTernaryMatrix, input: []const f32, output: []f32) void {
        std.debug.assert(input.len >= self.cols);
        std.debug.assert(output.len >= self.rows);

        @memset(output[0..self.rows], 0);

        for (self.entries[0..self.nnz]) |entry| {
            const val: f32 = switch (entry.value) {
                .P => input[entry.col],
                .N => -input[entry.col],
                .Z => 0.0,
            };
            output[entry.row] += val;
        }
    }

    pub fn matmulBatch(self: *const SparseTernaryMatrix, inputs: []const f32, outputs: []f32, batch_size: usize, seq_len: usize) void {
        for (0..batch_size * seq_len) |b| {
            const in_offset = b * self.cols;
            const out_offset = b * self.rows;
            self.matmul(inputs[in_offset..][0..self.cols], outputs[out_offset..][0..self.rows]);
        }
    }
};

pub const SparseStats = struct {
    nnz: usize,
    total: usize,
    sparsity: f32,
    compression_ratio: f32,

    pub fn format(self: SparseStats, writer: anytype) !void {
        try writer.print("SparseStats(nnz={}, total={}, sparsity={d:.1}%, compression={d:.1}x)\n", .{
            self.nnz,
            self.total,
            self.sparsity * 100.0,
            self.compression_ratio,
        });
    }
};

pub fn computeStats(matrix: *const SparseTernaryMatrix) SparseStats {
    const total = matrix.rows * matrix.cols;
    const ratio: f32 = if (matrix.nnz > 0)
        @as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(matrix.nnz))
    else
        0.0;
    return .{
        .nnz = matrix.nnz,
        .total = total,
        .sparsity = matrix.sparsity(),
        .compression_ratio = ratio,
    };
}

test "sparse matmul matches dense" {
    const allocator = std.testing.allocator;

    const rows: usize = 3;
    const cols: usize = 4;
    const weights = [_]Trit{ .P, .Z, .N, .P, .Z, .P, .Z, .N, .N, .P, .Z, .Z };

    var sparse = try SparseTernaryMatrix.init(allocator, rows, cols, &weights);
    defer sparse.deinit(allocator);

    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var sparse_out: [3]f32 = undefined;
    sparse.matmul(&input, &sparse_out);

    var dense_out: [3]f32 = [_]f32{0} ** 3;
    for (0..rows) |r| {
        for (0..cols) |c| {
            const w: f32 = switch (weights[r * cols + c]) {
                .P => 1.0,
                .N => -1.0,
                .Z => 0.0,
            };
            dense_out[r] += w * input[c];
        }
    }

    for (0..rows) |i| {
        try std.testing.expectApproxEqAbs(dense_out[i], sparse_out[i], 1e-6);
    }
}

test "sparse matmul skips zeros" {
    const allocator = std.testing.allocator;

    const weights = [_]Trit{ .Z, .Z, .Z, .Z };
    var sparse = try SparseTernaryMatrix.init(allocator, 2, 2, &weights);
    defer sparse.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), sparse.nnz);
    try std.testing.expectEqual(@as(f32, 1.0), sparse.sparsity());

    const input = [_]f32{ 1.0, 2.0 };
    var output: [2]f32 = undefined;
    sparse.matmul(&input, &output);
    for (output) |v| try std.testing.expect(v == 0.0);
}

test "sparse matmul all non-zero" {
    const allocator = std.testing.allocator;

    const weights = [_]Trit{ .P, .N, .N, .P };
    var sparse = try SparseTernaryMatrix.init(allocator, 2, 2, &weights);
    defer sparse.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), sparse.nnz);
    try std.testing.expectEqual(@as(f32, 0.0), sparse.sparsity());

    const input = [_]f32{ 3.0, 5.0 };
    var output: [2]f32 = undefined;
    sparse.matmul(&input, &output);

    try std.testing.expectApproxEqAbs(@as(f32, -2.0), output[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), output[1], 1e-6);
}

test "sparse stats" {
    const allocator = std.testing.allocator;

    const weights = [_]Trit{ .P, .Z, .Z, .P, .Z, .N, .P, .Z, .N };
    var sparse = try SparseTernaryMatrix.init(allocator, 3, 3, &weights);
    defer sparse.deinit(allocator);

    const stats = computeStats(&sparse);
    try std.testing.expectEqual(@as(usize, 5), stats.nnz);
    try std.testing.expectEqual(@as(usize, 9), stats.total);
    try std.testing.expect(stats.sparsity > 0.4);
    try std.testing.expect(stats.compression_ratio > 1.0);
}

test "batch sparse matmul" {
    const allocator = std.testing.allocator;

    const weights = [_]Trit{ .P, .N, .Z, .P };
    var sparse = try SparseTernaryMatrix.init(allocator, 2, 2, &weights);
    defer sparse.deinit(allocator);

    const inputs = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var outputs: [4]f32 = undefined;
    sparse.matmulBatch(&inputs, &outputs, 2, 1);

    try std.testing.expectApproxEqAbs(@as(f32, -1.0), outputs[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), outputs[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), outputs[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), outputs[3], 1e-6);
}
