// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY REED-SOLOMON v1.4 - Erasure Coding for Fault-Tolerant Storage
// k-of-n shard recovery using GF(2^8) Vandermonde matrix encoding
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const galois = @import("galois.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// REED-SOLOMON ENCODER/DECODER
// Systematic encoding: data shards unchanged, only parity shards computed
// Recovery: any k-of-n shards sufficient to reconstruct all data
// ═══════════════════════════════════════════════════════════════════════════════

pub const ReedSolomon = struct {
    data_shards: u32, // k
    parity_shards: u32, // m
    total_shards: u32, // n = k + m
    gf: galois.GF256,

    pub fn init(data_shards: u32, parity_shards: u32) ReedSolomon {
        return .{
            .data_shards = data_shards,
            .parity_shards = parity_shards,
            .total_shards = data_shards + parity_shards,
            .gf = galois.GF256.init(),
        };
    }

    /// Check if recovery is possible given the number of present shards
    pub fn canRecover(self: *const ReedSolomon, present_count: u32) bool {
        return present_count >= self.data_shards;
    }

    /// Encode: produce parity shards from data shards
    /// data_slices: k slices of equal length (the data shards)
    /// parity_out: m pre-allocated slices of same length (will be filled with parity)
    pub fn encode(self: *const ReedSolomon, data_slices: []const []const u8, parity_out: [][]u8) void {
        const shard_len = data_slices[0].len;
        const k = self.data_shards;

        // For each byte position across all shards
        for (0..shard_len) |byte_idx| {
            // For each parity shard
            for (0..self.parity_shards) |p| {
                var val: u8 = 0;
                // parity[p][byte_idx] = sum over i of (data[i][byte_idx] * matrix[k+p][i])
                // Vandermonde: matrix[k+p][i] = (p+1)^i in GF(2^8)
                // But for systematic encoding, we use the coding matrix rows only
                const row_val: u8 = @intCast(p + 1); // Row element for Vandermonde
                for (0..k) |i| {
                    const coeff = self.gf.pow(row_val, @intCast(i));
                    val = self.gf.add(val, self.gf.mul(data_slices[i][byte_idx], coeff));
                }
                parity_out[p][byte_idx] = val;
            }
        }
    }

    /// Decode: recover missing shards given at least k present shards
    /// shards: array of n optional shard pointers (null = missing)
    /// shard_len: length of each shard
    /// recovered: pre-allocated slices for each missing shard that needs recovery
    /// missing_indices: which shard indices are missing
    /// Returns error if not enough shards present
    pub fn decode(
        self: *const ReedSolomon,
        shards: []const ?[]const u8,
        shard_len: usize,
        recovered: [][]u8,
        missing_indices: []const u32,
        allocator: std.mem.Allocator,
    ) !void {
        const k = self.data_shards;
        const n = self.total_shards;

        // Count present shards
        var present_count: u32 = 0;
        for (shards) |s| {
            if (s != null) present_count += 1;
        }
        if (present_count < k) return error.NotEnoughShards;

        // Build the encoding matrix (Vandermonde-based)
        // Top k rows = identity (data shards), bottom m rows = Vandermonde coding
        const matrix = try self.buildEncodingMatrix(allocator);
        defer {
            for (matrix) |row| allocator.free(row);
            allocator.free(matrix);
        }

        // Select k present shards and build sub-matrix
        var present_indices = try allocator.alloc(u32, k);
        defer allocator.free(present_indices);
        var pi: u32 = 0;
        for (0..n) |i| {
            if (pi >= k) break;
            if (shards[i] != null) {
                present_indices[pi] = @intCast(i);
                pi += 1;
            }
        }

        // Build sub-matrix from present rows
        var sub_matrix = try allocator.alloc([]u8, k);
        defer {
            for (sub_matrix) |row| allocator.free(row);
            allocator.free(sub_matrix);
        }
        for (0..k) |i| {
            sub_matrix[i] = try allocator.alloc(u8, k);
            const row_idx = present_indices[i];
            @memcpy(sub_matrix[i], matrix[row_idx][0..k]);
        }

        // Invert the sub-matrix
        const inv = try invertMatrix(&self.gf, sub_matrix, k, allocator);
        defer {
            for (inv) |row| allocator.free(row);
            allocator.free(inv);
        }

        // Recover missing shards by multiplying inverse matrix with present data
        for (0..missing_indices.len) |mi| {
            const missing_idx = missing_indices[mi];

            // For each byte position
            for (0..shard_len) |byte_idx| {
                var val: u8 = 0;
                // Compute the row of the encoding matrix for missing_idx
                // Then multiply by inv to get coefficients for present shards
                // result[byte_idx] = sum_j( recovery_coeff[j] * present_shard[j][byte_idx] )
                for (0..k) |j| {
                    // recovery_coeff[j] = sum_l( matrix[missing_idx][l] * inv[l][j] )
                    var coeff: u8 = 0;
                    for (0..k) |l| {
                        coeff = self.gf.add(coeff, self.gf.mul(matrix[missing_idx][l], inv[l][j]));
                    }
                    const present_shard = shards[present_indices[j]].?;
                    val = self.gf.add(val, self.gf.mul(coeff, present_shard[byte_idx]));
                }
                recovered[mi][byte_idx] = val;
            }
        }
    }

    /// Build the full n×k encoding matrix
    /// Top k rows = identity matrix (systematic encoding)
    /// Bottom m rows = Vandermonde coding matrix
    fn buildEncodingMatrix(self: *const ReedSolomon, allocator: std.mem.Allocator) ![][]u8 {
        const k = self.data_shards;
        const n = self.total_shards;

        var matrix = try allocator.alloc([]u8, n);
        errdefer {
            for (matrix[0..n]) |row| allocator.free(row);
            allocator.free(matrix);
        }

        // Top k rows: identity matrix
        for (0..k) |i| {
            matrix[i] = try allocator.alloc(u8, k);
            @memset(matrix[i], 0);
            matrix[i][i] = 1;
        }

        // Bottom m rows: Vandermonde coding rows
        for (0..self.parity_shards) |p| {
            matrix[k + p] = try allocator.alloc(u8, k);
            const row_val: u8 = @intCast(p + 1);
            for (0..k) |j| {
                matrix[k + p][j] = self.gf.pow(row_val, @intCast(j));
            }
        }

        return matrix;
    }
};

/// Invert a square matrix over GF(2^8) using Gaussian elimination
fn invertMatrix(gf: *const galois.GF256, matrix: [][]u8, size: u32, allocator: std.mem.Allocator) ![][]u8 {
    const n = size;

    // Create augmented matrix [A | I]
    var aug = try allocator.alloc([]u8, n);
    errdefer {
        for (aug[0..n]) |row| allocator.free(row);
        allocator.free(aug);
    }
    for (0..n) |i| {
        aug[i] = try allocator.alloc(u8, 2 * n);
        // Copy original matrix
        @memcpy(aug[i][0..n], matrix[i][0..n]);
        // Identity on the right
        @memset(aug[i][n .. 2 * n], 0);
        aug[i][n + i] = 1;
    }

    // Forward elimination
    for (0..n) |col| {
        // Find pivot
        var pivot_row: ?usize = null;
        for (col..n) |row| {
            if (aug[row][col] != 0) {
                pivot_row = row;
                break;
            }
        }
        if (pivot_row == null) return error.SingularMatrix;

        // Swap rows
        if (pivot_row.? != col) {
            const tmp = aug[col];
            aug[col] = aug[pivot_row.?];
            aug[pivot_row.?] = tmp;
        }

        // Scale pivot row so pivot element = 1
        const pivot_val = aug[col][col];
        const pivot_inv = gf.inverse(pivot_val);
        for (0..2 * n) |j| {
            aug[col][j] = gf.mul(aug[col][j], pivot_inv);
        }

        // Eliminate column in all other rows
        for (0..n) |row| {
            if (row == col) continue;
            const factor = aug[row][col];
            if (factor == 0) continue;
            for (0..2 * n) |j| {
                aug[row][j] = gf.add(aug[row][j], gf.mul(factor, aug[col][j]));
            }
        }
    }

    // Extract inverse from right half
    var result = try allocator.alloc([]u8, n);
    errdefer {
        for (result[0..n]) |row| allocator.free(row);
        allocator.free(result);
    }
    for (0..n) |i| {
        result[i] = try allocator.alloc(u8, n);
        @memcpy(result[i], aug[i][n .. 2 * n]);
    }

    // Free augmented matrix
    for (aug) |row| allocator.free(row);
    allocator.free(aug);

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RS encode/decode - no loss" {
    const rs = ReedSolomon.init(4, 2); // 4 data + 2 parity = 6 total

    // Create 4 data shards (each 8 bytes)
    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };

    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    // Allocate parity shards
    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };

    rs.encode(&data_slices, &parity_out);

    // Verify all shards present → decode is a no-op (all present)
    try std.testing.expect(rs.canRecover(6));
    try std.testing.expect(rs.canRecover(4));
    try std.testing.expect(!rs.canRecover(3));
}

test "RS recover 1 missing" {
    const allocator = std.testing.allocator;
    const rs = ReedSolomon.init(4, 2);

    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };

    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };

    rs.encode(&data_slices, &parity_out);

    // Lose data shard 1 (index 1)
    const shards: [6]?[]const u8 = .{
        &data0, // present
        null, // MISSING
        &data2, // present
        &data3, // present
        &parity0, // present
        &parity1, // present
    };

    var recovered_buf: [8]u8 = undefined;
    var recovered: [1][]u8 = .{&recovered_buf};
    const missing: [1]u32 = .{1};

    try rs.decode(&shards, 8, &recovered, &missing, allocator);

    // Verify recovered data matches original
    try std.testing.expectEqualSlices(u8, &data1, &recovered_buf);
}

test "RS recover max parity" {
    const allocator = std.testing.allocator;
    const rs = ReedSolomon.init(4, 2);

    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };

    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };

    rs.encode(&data_slices, &parity_out);

    // Lose both parity shards (data shards all present → trivial recovery)
    const shards: [6]?[]const u8 = .{
        &data0,
        &data1,
        &data2,
        &data3,
        null, // parity 0 MISSING
        null, // parity 1 MISSING
    };

    var rec0: [8]u8 = undefined;
    var rec1: [8]u8 = undefined;
    var recovered: [2][]u8 = .{ &rec0, &rec1 };
    const missing: [2]u32 = .{ 4, 5 };

    try rs.decode(&shards, 8, &recovered, &missing, allocator);

    // Recovered parity should match originals
    try std.testing.expectEqualSlices(u8, &parity0, &rec0);
    try std.testing.expectEqualSlices(u8, &parity1, &rec1);
}

test "RS recover mixed data+parity" {
    const allocator = std.testing.allocator;
    const rs = ReedSolomon.init(4, 2);

    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };

    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };

    rs.encode(&data_slices, &parity_out);

    // Lose 1 data shard + 1 parity shard (still have 4 = k, should work)
    const shards: [6]?[]const u8 = .{
        &data0,
        null, // data1 MISSING
        &data2,
        &data3,
        null, // parity0 MISSING
        &parity1,
    };

    var rec_data1: [8]u8 = undefined;
    var rec_parity0: [8]u8 = undefined;
    var recovered: [2][]u8 = .{ &rec_data1, &rec_parity0 };
    const missing: [2]u32 = .{ 1, 4 };

    try rs.decode(&shards, 8, &recovered, &missing, allocator);

    // Verify recovered data matches originals
    try std.testing.expectEqualSlices(u8, &data1, &rec_data1);
    try std.testing.expectEqualSlices(u8, &parity0, &rec_parity0);
}

test "RS fails when too many lost" {
    const allocator = std.testing.allocator;
    const rs = ReedSolomon.init(4, 2);

    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };

    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };

    rs.encode(&data_slices, &parity_out);

    // Lose 3 shards (only 3 present < k=4)
    const shards: [6]?[]const u8 = .{
        &data0,
        null, // MISSING
        null, // MISSING
        &data3,
        null, // MISSING
        &parity1,
    };

    var rec0: [8]u8 = undefined;
    var rec1: [8]u8 = undefined;
    var rec2: [8]u8 = undefined;
    var recovered: [3][]u8 = .{ &rec0, &rec1, &rec2 };
    const missing: [3]u32 = .{ 1, 2, 4 };

    const result = rs.decode(&shards, 8, &recovered, &missing, allocator);
    try std.testing.expectError(error.NotEnoughShards, result);
}
