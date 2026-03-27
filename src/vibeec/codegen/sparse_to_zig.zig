// ═══════════════════════════════════════════════════════════════════════════════
// sparse_to_zig.zig — Sparse VSA Codegen (Island 1)
// ═══════════════════════════════════════════════════════════════════════════════
// Generates SparseVector struct and methods from .tri spec
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Full SparseVector implementation template
const SPARSE_VECTOR_IMPL = 
\\pub const SparseVector = struct {
\\    indices: []const usize,
\\    values: []const Trit,
\\    len: usize,
\\
\\    /// Create from dense vector
\\    pub fn fromDense(allocator: std.mem.Allocator, dense: []const Trit) !SparseVector {
\\        var nnz: usize = 0;
\\        for (dense) |t| {
\\            if (t != 0) nnz += 1;
\\        }
\\
\\        var indices = try allocator.alloc(usize, nnz);
\\        var values = try allocator.alloc(Trit, nnz);
\\
\\        var pos: usize = 0;
\\        for (dense, 0..) |t, i| {
\\            if (t != 0) {
\\                indices[pos] = i;
\\                values[pos] = t;
\\                pos += 1;
\\            }
\\        }
\\
\\        return .{
\\            .indices = indices,
\\            .values = values,
\\            .len = dense.len,
\\        };
\\    }
\\
\\    /// Convert to dense vector
\\    pub fn toDense(self: SparseVector, allocator: std.mem.Allocator) ![]Trit {
\\        var result = try allocator.alloc(Trit, self.len);
\\        @memset(result, 0);
\\
\\        for (self.indices, self.values) |idx, val| {
\\            if (idx < self.len) {
\\                result[idx] = val;
\\            }
\\        }
\\
\\        return result;
\\    }
\\
\\    /// Dot product (only iterate over non-zeros)
\\    pub fn dotProductSparse(self: SparseVector, other: SparseVector) i64 {
\\        var sum: i64 = 0;
\\        var i: usize = 0;
\\        var j: usize = 0;
\\
\\        while (i < self.indices.len and j < other.indices.len) {
\\            const idx_a = self.indices[i];
\\            const idx_b = other.indices[j];
\\
\\            if (idx_a == idx_b) {
\\                sum += @as(i64, self.values[i]) * @as(i64, other.values[j]);
\\                i += 1;
\\                j += 1;
\\            } else if (idx_a < idx_b) {
\\                i += 1;
\\            } else {
\\                j += 1;
\\            }
\\        }
\\
\\        return sum;
\\    }
\\
\\    /// Cosine similarity
\\    pub fn cosineSimilaritySparse(self: SparseVector, other: SparseVector) f64 {
\\        var dot: i64 = 0;
\\        var norm_a: i64 = 0;
\\        var norm_b: i64 = 0;
\\
\\        var i: usize = 0;
\\        var j: usize = 0;
\\
\\        while (i < self.indices.len and j < other.indices.len) {
\\            const idx_a = self.indices[i];
\\            const idx_b = other.indices[j];
\\
\\            if (idx_a == idx_b) {
\\                dot += @as(i64, self.values[i]) * @as(i64, other.values[j]);
\\                norm_a += @as(i64, self.values[i]) * @as(i64, self.values[i]);
\\                norm_b += @as(i64, other.values[j]) * @as(i64, other.values[j]);
\\                i += 1;
\\                j += 1;
\\            } else if (idx_a < idx_b) {
\\                norm_a += @as(i64, self.values[i]) * @as(i64, self.values[i]);
\\                i += 1;
\\            } else {
\\                norm_b += @as(i64, other.values[j]) * @as(i64, other.values[j]);
\\                j += 1;
\\            }
\\        }
\\
\\        while (i < self.indices.len) {
\\            norm_a += @as(i64, self.values[i]) * @as(i64, self.values[i]);
\\            i += 1;
\\        }
\\        while (j < other.indices.len) {
\\            norm_b += @as(i64, other.values[j]) * @as(i64, other.values[j]);
\\            j += 1;
\\        }
\\
\\        const norm_product = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));
\\        if (norm_product == 0) return 0;
\\
\\        return @as(f64, @floatFromInt(dot)) / norm_product;
\\    }
\\
\\    /// Get sparsity ratio (0 = dense, 1 = empty)
\\    pub fn sparsity(self: SparseVector) f64 {
\\        if (self.len == 0) return 1;
\\        return 1.0 - @as(f64, @floatFromInt(self.indices.len)) / @as(f64, @floatFromInt(self.len));
\\    }
\\
\\    /// Memory usage in bytes
\\    pub fn memoryUsage(self: SparseVector) usize {
\\        return self.indices.len * @sizeOf(usize) + self.values.len * @sizeOf(Trit);
\\    }
\\
\\    /// Deallocate
\\    pub fn deinitSparse(self: SparseVector, allocator: std.mem.Allocator) void {
\\        allocator.free(self.indices);
\\        allocator.free(self.values);
\\    }
\\};
;

pub fn generate(allocator: Allocator, source: []const u8) ![]const u8 {
    _ = source; // Spec ignored for now - full template
    var output = std.ArrayListUnmanaged(u8){};

    try output.appendSlice(allocator,
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\// VSA Core — Sparse Operations (GENERATED from specs/vsa/sparse.tri)
        \\// Island 1: Sparse VSA operations
        \\// DO NOT EDIT — Regenerate from .tri spec
        \\//
        \\// φ² + 1/φ² = 3 | TRINITY
        \\// ═══════════════════════════════════════════════════════════════════════════════
        \\
        \\const std = @import("std");
        \\const common = @import("common.zig");
        \\const Trit = common.Trit;
        \\
        \\
    );

    try output.appendSlice(allocator, SPARSE_VECTOR_IMPL);

    // Add tests
    try output.appendSlice(allocator,
        \\
        \\test "SparseVector fromDense" {
        \\    const dense = [_]Trit{ 0, 1, 0, -1, 0, 0, 1 };
        \\    var sparse = try SparseVector.fromDense(std.testing.allocator, &dense);
        \\    defer sparse.deinitSparse(std.testing.allocator);
        \\
        \\    try std.testing.expectEqual(@as(usize, 3), sparse.indices.len);
        \\    try std.testing.expectEqual(@as(usize, 1), sparse.indices[0]);
        \\    try std.testing.expectEqual(@as(usize, 3), sparse.indices[1]);
        \\    try std.testing.expectEqual(@as(usize, 6), sparse.indices[2]);
        \\}
        \\
        \\test "SparseVector toDense roundtrip" {
        \\    const dense = [_]Trit{ 0, 1, 0, -1, 0, 0, 1 };
        \\    var sparse = try SparseVector.fromDense(std.testing.allocator, &dense);
        \\    defer sparse.deinitSparse(std.testing.allocator);
        \\
        \\    const recovered = try sparse.toDense(std.testing.allocator);
        \\    defer std.testing.allocator.free(recovered);
        \\
        \\    try std.testing.expectEqualSlices(Trit, &dense, recovered);
        \\}
        \\
        \\test "SparseVector dotProductSparse" {
        \\    const a = [_]Trit{ 0, 1, 0, -1, 0, 0, 1 };
        \\    const b = [_]Trit{ 0, 1, 0, 1, 0, 0, -1 };
        \\
        \\    var sparse_a = try SparseVector.fromDense(std.testing.allocator, &a);
        \\    defer sparse_a.deinitSparse(std.testing.allocator);
        \\
        \\    var sparse_b = try SparseVector.fromDense(std.testing.allocator, &b);
        \\    defer sparse_b.deinitSparse(std.testing.allocator);
        \\
        \\    const dot = sparse_a.dotProductSparse(sparse_b);
        \\    try std.testing.expectEqual(@as(i64, -1), dot);
        \\}
        \\
        \\test "SparseVector sparsity" {
        \\    const dense = [_]Trit{ 0, 1, 0, -1, 0, 0, 1 };
        \\    var sparse = try SparseVector.fromDense(std.testing.allocator, &dense);
        \\    defer sparse.deinitSparse(std.testing.allocator);
        \\
        \\    const sparsity = sparse.sparsity();
        \\    try std.testing.expectApproxEqAbs(@as(f64, 4.0 / 7.0), sparsity, 0.001);
        \\}
        \\
    );

    return output.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const args = try std.process.argsAlloc(arena_alloc);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.tri>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_path = args[1];
    const source = try std.fs.cwd().readFileAlloc(arena_alloc, input_path, 1024 * 1024);

    const output = try generate(arena_alloc, source);

    try std.fs.File.stdout().writeAll(output);
}
