// Trinity Sparse Hypervectors
// Memory-efficient representation for sparse data (>50% zeros)
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const hybrid = @import("hybrid.zig");
const vsa = @import("vsa.zig");

const HybridBigInt = hybrid.HybridBigInt;
const Trit = hybrid.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSE HYPERVECTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Sparse hypervector using coordinate list (COO) format
/// Stores only non-zero elements with their indices
/// Memory: O(nnz) instead of O(dimension)
pub const SparseVector = struct {
    /// Indices of non-zero elements (sorted)
    indices: std.ArrayListUnmanaged(u32) = .{},
    /// Values at those indices (-1, 0, or +1)
    values: std.ArrayListUnmanaged(Trit) = .{},
    /// Total dimension of the vector
    dimension: u32,
    /// Allocator for dynamic memory
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create empty sparse vector
    pub fn init(allocator: std.mem.Allocator, dimension: u32) Self {
        return Self{
            .indices = .{},
            .values = .{},
            .dimension = dimension,
            .allocator = allocator,
        };
    }

    /// Free memory
    pub fn deinit(self: *Self) void {
        self.indices.deinit(self.allocator);
        self.values.deinit(self.allocator);
    }

    /// Number of non-zero elements
    pub fn nnz(self: *const Self) usize {
        return self.indices.items.len;
    }

    /// Sparsity ratio (0 = all non-zero, 1 = all zero)
    pub fn sparsity(self: *const Self) f64 {
        if (self.dimension == 0) return 1.0;
        return 1.0 - @as(f64, @floatFromInt(self.nnz())) / @as(f64, @floatFromInt(self.dimension));
    }

    /// Memory usage in bytes
    pub fn memoryBytes(self: *const Self) usize {
        return self.indices.items.len * @sizeOf(u32) +
            self.values.items.len * @sizeOf(Trit) +
            @sizeOf(Self);
    }

    /// Memory savings vs dense (ratio)
    pub fn memorySavings(self: *const Self) f64 {
        const sparse_bytes = self.memoryBytes();
        const dense_bytes = self.dimension * @sizeOf(Trit);
        if (dense_bytes == 0) return 0;
        return 1.0 - @as(f64, @floatFromInt(sparse_bytes)) / @as(f64, @floatFromInt(dense_bytes));
    }

    /// Set value at index
    pub fn set(self: *Self, index: u32, value: Trit) !void {
        if (index >= self.dimension) return;

        // Binary search for insertion point
        const pos = self.findPosition(index);

        if (pos < self.indices.items.len and self.indices.items[pos] == index) {
            // Update existing
            if (value == 0) {
                // Remove element
                _ = self.indices.orderedRemove(pos);
                _ = self.values.orderedRemove(pos);
            } else {
                self.values.items[pos] = value;
            }
        } else if (value != 0) {
            // Insert new non-zero
            try self.indices.insert(self.allocator, pos, index);
            try self.values.insert(self.allocator, pos, value);
        }
    }

    /// Get value at index
    pub fn get(self: *const Self, index: u32) Trit {
        if (index >= self.dimension) return 0;

        const pos = self.findPosition(index);
        if (pos < self.indices.items.len and self.indices.items[pos] == index) {
            return self.values.items[pos];
        }
        return 0;
    }

    /// Binary search for index position
    fn findPosition(self: *const Self, index: u32) usize {
        var left: usize = 0;
        var right: usize = self.indices.items.len;

        while (left < right) {
            const mid = left + (right - left) / 2;
            if (self.indices.items[mid] < index) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        return left;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONVERSION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Convert from dense HybridBigInt
    pub fn fromDense(allocator: std.mem.Allocator, dense: *HybridBigInt) !Self {
        dense.ensureUnpacked();

        var sparse = Self.init(allocator, @intCast(dense.trit_len));

        for (0..dense.trit_len) |i| {
            const t = dense.unpacked_cache[i];
            if (t != 0) {
                try sparse.indices.append(allocator, @intCast(i));
                try sparse.values.append(allocator, t);
            }
        }

        return sparse;
    }

    /// Convert to dense HybridBigInt
    pub fn toDense(self: *const Self) HybridBigInt {
        var dense = HybridBigInt.zero();
        dense.mode = .unpacked_mode;
        dense.trit_len = self.dimension;
        dense.dirty = true;

        // Initialize to zeros
        for (0..self.dimension) |i| {
            dense.unpacked_cache[i] = 0;
        }

        // Set non-zero values
        for (0..self.indices.items.len) |i| {
            const idx = self.indices.items[i];
            dense.unpacked_cache[idx] = self.values.items[i];
        }

        return dense;
    }

    /// Create random sparse vector with given density
    pub fn random(allocator: std.mem.Allocator, dimension: u32, density: f64, seed: u64) !Self {
        var sparse = Self.init(allocator, dimension);

        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();

        for (0..dimension) |i| {
            if (rand.float(f64) < density) {
                const value: Trit = if (rand.boolean()) 1 else -1;
                try sparse.indices.append(allocator, @intCast(i));
                try sparse.values.append(allocator, value);
            }
        }

        return sparse;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VSA OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Sparse bind (element-wise multiply)
    /// Result is sparse: only non-zero where BOTH inputs are non-zero
    pub fn bind(allocator: std.mem.Allocator, a: *const Self, b: *const Self) !Self {
        const dim = @max(a.dimension, b.dimension);
        var result = Self.init(allocator, dim);

        var i: usize = 0;
        var j: usize = 0;

        // Merge-join on sorted indices
        while (i < a.indices.items.len and j < b.indices.items.len) {
            const a_idx = a.indices.items[i];
            const b_idx = b.indices.items[j];

            if (a_idx == b_idx) {
                const prod = a.values.items[i] * b.values.items[j];
                if (prod != 0) {
                    try result.indices.append(allocator, a_idx);
                    try result.values.append(allocator, prod);
                }
                i += 1;
                j += 1;
            } else if (a_idx < b_idx) {
                i += 1;
            } else {
                j += 1;
            }
        }

        return result;
    }

    /// Sparse unbind (same as bind for balanced ternary)
    pub fn unbind(allocator: std.mem.Allocator, a: *const Self, b: *const Self) !Self {
        return bind(allocator, a, b);
    }

    /// Sparse bundle (element-wise sum with threshold)
    /// Result may be denser than inputs
    pub fn bundle(allocator: std.mem.Allocator, a: *const Self, b: *const Self) !Self {
        const dim = @max(a.dimension, b.dimension);
        var result = Self.init(allocator, dim);

        var i: usize = 0;
        var j: usize = 0;

        // Merge-join on sorted indices
        while (i < a.indices.items.len or j < b.indices.items.len) {
            var idx: u32 = undefined;
            var sum: i16 = 0;

            if (i >= a.indices.items.len) {
                idx = b.indices.items[j];
                sum = b.values.items[j];
                j += 1;
            } else if (j >= b.indices.items.len) {
                idx = a.indices.items[i];
                sum = a.values.items[i];
                i += 1;
            } else {
                const a_idx = a.indices.items[i];
                const b_idx = b.indices.items[j];

                if (a_idx == b_idx) {
                    idx = a_idx;
                    sum = @as(i16, a.values.items[i]) + @as(i16, b.values.items[j]);
                    i += 1;
                    j += 1;
                } else if (a_idx < b_idx) {
                    idx = a_idx;
                    sum = a.values.items[i];
                    i += 1;
                } else {
                    idx = b_idx;
                    sum = b.values.items[j];
                    j += 1;
                }
            }

            // Threshold
            var value: Trit = 0;
            if (sum > 0) {
                value = 1;
            } else if (sum < 0) {
                value = -1;
            }

            if (value != 0) {
                try result.indices.append(allocator, idx);
                try result.values.append(allocator, value);
            }
        }

        return result;
    }

    /// Sparse permute (cyclic shift)
    pub fn permute(allocator: std.mem.Allocator, v: *const Self, k: u32) !Self {
        var result = Self.init(allocator, v.dimension);

        if (v.dimension == 0) return result;

        const shift = k % v.dimension;

        for (0..v.indices.items.len) |i| {
            const old_idx = v.indices.items[i];
            const new_idx = (old_idx + shift) % v.dimension;
            try result.indices.append(allocator, new_idx);
            try result.values.append(allocator, v.values.items[i]);
        }

        // Sort by new indices
        sortByIndices(&result);

        return result;
    }

    /// Sort indices and values together
    fn sortByIndices(self: *Self) void {
        // Simple insertion sort (good for nearly-sorted data)
        var i: usize = 1;
        while (i < self.indices.items.len) : (i += 1) {
            const key_idx = self.indices.items[i];
            const key_val = self.values.items[i];
            var j: usize = i;

            while (j > 0 and self.indices.items[j - 1] > key_idx) {
                self.indices.items[j] = self.indices.items[j - 1];
                self.values.items[j] = self.values.items[j - 1];
                j -= 1;
            }

            self.indices.items[j] = key_idx;
            self.values.items[j] = key_val;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SIMILARITY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Sparse dot product
    pub fn dot(a: *const Self, b: *const Self) i64 {
        var result: i64 = 0;

        var i: usize = 0;
        var j: usize = 0;

        // Merge-join
        while (i < a.indices.items.len and j < b.indices.items.len) {
            const a_idx = a.indices.items[i];
            const b_idx = b.indices.items[j];

            if (a_idx == b_idx) {
                result += @as(i64, a.values.items[i]) * @as(i64, b.values.items[j]);
                i += 1;
                j += 1;
            } else if (a_idx < b_idx) {
                i += 1;
            } else {
                j += 1;
            }
        }

        return result;
    }

    /// Sparse cosine similarity
    pub fn cosineSimilarity(a: *const Self, b: *const Self) f64 {
        const dot_prod = dot(a, b);

        // Compute norms
        var norm_a_sq: i64 = 0;
        for (a.values.items) |v| {
            norm_a_sq += @as(i64, v) * @as(i64, v);
        }

        var norm_b_sq: i64 = 0;
        for (b.values.items) |v| {
            norm_b_sq += @as(i64, v) * @as(i64, v);
        }

        if (norm_a_sq == 0 or norm_b_sq == 0) return 0;

        return @as(f64, @floatFromInt(dot_prod)) /
            (@sqrt(@as(f64, @floatFromInt(norm_a_sq))) * @sqrt(@as(f64, @floatFromInt(norm_b_sq))));
    }

    /// Sparse Hamming distance
    pub fn hammingDistance(a: *const Self, b: *const Self) usize {
        var distance: usize = 0;

        var i: usize = 0;
        var j: usize = 0;

        while (i < a.indices.items.len or j < b.indices.items.len) {
            if (i >= a.indices.items.len) {
                // Remaining b elements differ from 0
                distance += b.indices.items.len - j;
                break;
            } else if (j >= b.indices.items.len) {
                // Remaining a elements differ from 0
                distance += a.indices.items.len - i;
                break;
            } else {
                const a_idx = a.indices.items[i];
                const b_idx = b.indices.items[j];

                if (a_idx == b_idx) {
                    if (a.values.items[i] != b.values.items[j]) {
                        distance += 1;
                    }
                    i += 1;
                    j += 1;
                } else if (a_idx < b_idx) {
                    distance += 1; // a has non-zero, b has zero
                    i += 1;
                } else {
                    distance += 1; // b has non-zero, a has zero
                    j += 1;
                }
            }
        }

        return distance;
    }

    /// Clone sparse vector
    pub fn clone(self: *const Self) !Self {
        var result = Self.init(self.allocator, self.dimension);
        try result.indices.appendSlice(self.indices.items);
        try result.values.appendSlice(self.values.items);
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SparseVector basic operations" {
    var sparse = SparseVector.init(std.testing.allocator, 1000);
    defer sparse.deinit();

    try sparse.set(10, 1);
    try sparse.set(50, -1);
    try sparse.set(100, 1);

    try std.testing.expectEqual(@as(usize, 3), sparse.nnz());
    try std.testing.expectEqual(@as(Trit, 1), sparse.get(10));
    try std.testing.expectEqual(@as(Trit, -1), sparse.get(50));
    try std.testing.expectEqual(@as(Trit, 0), sparse.get(0));

    // Sparsity should be high
    try std.testing.expect(sparse.sparsity() > 0.99);
}

test "SparseVector fromDense/toDense roundtrip" {
    var dense = vsa.randomVector(256, 12345);

    var sparse = try SparseVector.fromDense(std.testing.allocator, &dense);
    defer sparse.deinit();

    const recovered = sparse.toDense();

    // Should match original
    for (0..256) |i| {
        try std.testing.expectEqual(dense.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "SparseVector bind" {
    var a = SparseVector.init(std.testing.allocator, 100);
    defer a.deinit();
    var b = SparseVector.init(std.testing.allocator, 100);
    defer b.deinit();

    try a.set(10, 1);
    try a.set(20, -1);
    try a.set(30, 1);

    try b.set(10, 1);
    try b.set(20, 1);
    try b.set(40, -1);

    var result = try SparseVector.bind(std.testing.allocator, &a, &b);
    defer result.deinit();

    // Only indices 10 and 20 are in both
    try std.testing.expectEqual(@as(usize, 2), result.nnz());
    try std.testing.expectEqual(@as(Trit, 1), result.get(10)); // 1 * 1 = 1
    try std.testing.expectEqual(@as(Trit, -1), result.get(20)); // -1 * 1 = -1
}

test "SparseVector bundle" {
    var a = SparseVector.init(std.testing.allocator, 100);
    defer a.deinit();
    var b = SparseVector.init(std.testing.allocator, 100);
    defer b.deinit();

    try a.set(10, 1);
    try a.set(20, -1);

    try b.set(10, 1);
    try b.set(20, 1);
    try b.set(30, -1);

    var result = try SparseVector.bundle(std.testing.allocator, &a, &b);
    defer result.deinit();

    try std.testing.expectEqual(@as(Trit, 1), result.get(10)); // 1 + 1 = 2 -> 1
    try std.testing.expectEqual(@as(Trit, 0), result.get(20)); // -1 + 1 = 0 -> 0
    try std.testing.expectEqual(@as(Trit, -1), result.get(30)); // 0 + -1 = -1 -> -1
}

test "SparseVector similarity" {
    var a = SparseVector.init(std.testing.allocator, 100);
    defer a.deinit();
    var b = SparseVector.init(std.testing.allocator, 100);
    defer b.deinit();

    // Same non-zero positions, same values
    try a.set(10, 1);
    try a.set(20, 1);
    try a.set(30, 1);

    try b.set(10, 1);
    try b.set(20, 1);
    try b.set(30, 1);

    const sim = SparseVector.cosineSimilarity(&a, &b);
    try std.testing.expect(sim > 0.99); // Should be ~1.0
}

test "SparseVector memory efficiency" {
    // Create sparse vector with 1% density
    var sparse = try SparseVector.random(std.testing.allocator, 10000, 0.01, 12345);
    defer sparse.deinit();

    const savings = sparse.memorySavings();

    // With 1% density, should save >90% memory
    try std.testing.expect(savings > 0.9);
}

test "SparseVector permute" {
    var v = SparseVector.init(std.testing.allocator, 100);
    defer v.deinit();

    try v.set(10, 1);
    try v.set(20, -1);

    var permuted = try SparseVector.permute(std.testing.allocator, &v, 5);
    defer permuted.deinit();

    try std.testing.expectEqual(@as(Trit, 1), permuted.get(15)); // 10 + 5 = 15
    try std.testing.expectEqual(@as(Trit, -1), permuted.get(25)); // 20 + 5 = 25
}
