//! tri/bitvector — Growable bit array
//! Auto-generated from specs/tri/tri_bitvector.tri
//! TTT Dogfood v0.2 Stage 95

const std = @import("std");

const USIZE_BITS = @typeInfo(usize).int.bits;

/// Dynamic bit array
pub const BitVector = struct {
    bits: []usize,
    length: usize,
    allocator: std.mem.Allocator,

    /// Create empty bit vector
    pub fn empty(allocator: std.mem.Allocator) BitVector {
        return .{ .bits = &[_]usize{}, .length = 0, .allocator = allocator };
    }

    /// Pre-allocate for n bits
    pub fn withCapacity(bits: usize, allocator: std.mem.Allocator) !BitVector {
        const words = (bits + USIZE_BITS - 1) / USIZE_BITS;
        const data = try allocator.alloc(usize, words);
        @memset(data, 0);
        return .{ .bits = data, .length = 0, .allocator = allocator };
    }

    pub fn deinit(self: BitVector) void {
        self.allocator.free(self.bits);
    }

    /// Append bit
    pub fn push(self: *BitVector, bit: bool) !void {
        const word_index = self.length / USIZE_BITS;
        const bit_index = @as(u6, @intCast(self.length % USIZE_BITS));

        if (word_index >= self.bits.len) {
            // Need to grow
            const new_len = if (self.bits.len == 0) 4 else self.bits.len * 2;
            const new_bits = try self.allocator.realloc(self.bits, new_len);
            @memset(new_bits[self.bits.len..], 0);
            self.bits = new_bits;
        }

        if (bit) {
            self.bits[word_index] |= @as(usize, 1) << bit_index;
        } else {
            self.bits[word_index] &= ~(@as(usize, 1) << bit_index);
        }
        self.length += 1;
    }

    /// Remove last bit
    pub fn pop(self: *BitVector) ?bool {
        if (self.length == 0) return null;
        self.length -= 1;
        const word_index = self.length / USIZE_BITS;
        const bit_index = @as(u6, @intCast(self.length % USIZE_BITS));
        return (self.bits[word_index] & (@as(usize, 1) << bit_index)) != 0;
    }

    /// Get bit at index
    pub fn get(self: BitVector, index: usize) bool {
        if (index >= self.length) return false;
        const word_index = index / USIZE_BITS;
        const bit_index = @as(u6, @intCast(index % USIZE_BITS));
        return (self.bits[word_index] & (@as(usize, 1) << bit_index)) != 0;
    }

    /// Set bit at index
    pub fn set(self: *BitVector, index: usize, value: bool) void {
        if (index >= self.length) return;
        const word_index = index / USIZE_BITS;
        const bit_index = @as(u6, @intCast(index % USIZE_BITS));
        if (value) {
            self.bits[word_index] |= @as(usize, 1) << bit_index;
        } else {
            self.bits[word_index] &= ~(@as(usize, 1) << bit_index);
        }
    }

    /// Number of bits
    pub fn len(self: BitVector) usize {
        return self.length;
    }

    /// Concatenate bit vectors
    pub fn append(self: *BitVector, other: BitVector) !void {
        for (0..other.length) |i| {
            try self.push(other.get(i));
        }
    }
};

test "BitVector.empty" {
    var bv = BitVector.empty(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), bv.len());
    bv.deinit();
}

test "BitVector.push pop" {
    var bv = BitVector.empty(std.testing.allocator);
    defer bv.deinit();
    try bv.push(true);
    try bv.push(false);
    try bv.push(true);
    try std.testing.expectEqual(@as(usize, 3), bv.len());
    try std.testing.expectEqual(true, bv.pop());
    try std.testing.expectEqual(false, bv.pop());
}

test "BitVector.get set" {
    var bv = BitVector.empty(std.testing.allocator);
    defer bv.deinit();
    try bv.push(false);
    try bv.push(true);
    try bv.push(false);
    try std.testing.expect(bv.get(1));
    try std.testing.expect(!bv.get(0));
}
