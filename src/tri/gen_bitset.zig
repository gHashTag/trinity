//! tri/bitset — Bitset for boolean operations
//! Auto-generated from specs/tri/tri_bitset.tri
//! TTT Dogfood v0.2 Stage 184

const std = @import("std");

/// Fixed-size bitset
pub const Bitset = struct {
    data: []usize,
    size: usize,
    allocator: std.mem.Allocator,

    /// Create bitset for n bits
    pub fn init(allocator: std.mem.Allocator, bit_count: usize) !Bitset {
        const words = (bit_count + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);
        const data = try allocator.alloc(usize, words);
        @memset(data, 0);

        return .{
            .data = data,
            .size = bit_count,
            .allocator = allocator,
        };
    }

    /// Set bit to 1
    pub fn set(bs: *Bitset, index: usize) void {
        if (index >= bs.size) return;
        const word = index / @bitSizeOf(usize);
        const bit = index % @bitSizeOf(usize);
        bs.data[word] |= @as(usize, 1) << @intCast(bit);
    }

    /// Set bit to 0
    pub fn clear(bs: *Bitset, index: usize) void {
        if (index >= bs.size) return;
        const word = index / @bitSizeOf(usize);
        const bit = index % @bitSizeOf(usize);
        bs.data[word] &= ~(@as(usize, 1) << @intCast(bit));
    }

    /// Check if bit is set
    pub fn testBit(bs: *const Bitset, index: usize) bool {
        if (index >= bs.size) return false;
        const word = index / @bitSizeOf(usize);
        const bit = index % @bitSizeOf(usize);
        return (bs.data[word] & (@as(usize, 1) << @intCast(bit))) != 0;
    }

    /// Bitwise OR
    pub fn unionOp(a: *Bitset, b: *Bitset, allocator: std.mem.Allocator) !Bitset {
        var result = try Bitset.init(allocator, @max(a.size, b.size));

        const min_words = @min(a.data.len, b.data.len);
        for (0..min_words) |i| {
            result.data[i] = a.data[i] | b.data[i];
        }

        return result;
    }

    /// Bitwise AND
    pub fn intersect(a: *Bitset, b: *Bitset, allocator: std.mem.Allocator) !Bitset {
        var result = try Bitset.init(allocator, @max(a.size, b.size));

        const min_words = @min(a.data.len, b.data.len);
        for (0..min_words) |i| {
            result.data[i] = a.data[i] & b.data[i];
        }

        return result;
    }

    /// Free bitset
    pub fn deinit(bs: *Bitset) void {
        bs.allocator.free(bs.data);
    }
};

test "bitset set clear test" {
    var bs = try Bitset.init(std.testing.allocator, 100);
    defer bs.deinit();

    bs.set(10);
    bs.set(50);

    try std.testing.expect(bs.testBit(10));
    try std.testing.expect(bs.testBit(50));
    try std.testing.expect(!bs.testBit(5));

    bs.clear(10);
    try std.testing.expect(!bs.testBit(10));
}

test "bitset union" {
    var bs1 = try Bitset.init(std.testing.allocator, 64);
    defer bs1.deinit();
    var bs2 = try Bitset.init(std.testing.allocator, 64);
    defer bs2.deinit();

    bs1.set(5);
    bs1.set(10);
    bs2.set(10);
    bs2.set(15);

    var result = try bs1.unionOp(&bs2, std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(result.testBit(5));
    try std.testing.expect(result.testBit(10));
    try std.testing.expect(result.testBit(15));
}

test "bitset intersect" {
    var bs1 = try Bitset.init(std.testing.allocator, 64);
    defer bs1.deinit();
    var bs2 = try Bitset.init(std.testing.allocator, 64);
    defer bs2.deinit();

    bs1.set(5);
    bs1.set(10);
    bs2.set(10);
    bs2.set(15);

    var result = try bs1.intersect(&bs2, std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(!result.testBit(5));
    try std.testing.expect(result.testBit(10));
    try std.testing.expect(!result.testBit(15));
}
