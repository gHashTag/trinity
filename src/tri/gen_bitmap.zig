//! tri/bitmap — Fixed-size bit set
//! Auto-generated from specs/tri/tri_bitmap.tri
//! TTT Dogfood v0.2 Stage 94

const std = @import("std");

const USIZE_BITS = @typeInfo(usize).int.bits;

/// Fixed-capacity bit set
pub const Bitmap = struct {
    bits: []usize,
    capacity: usize,
    allocator: std.mem.Allocator,

    /// Create bitmap with n bits
    pub fn init(capacity: usize, allocator: std.mem.Allocator) !Bitmap {
        const words = (capacity + USIZE_BITS - 1) / USIZE_BITS;
        const bits = try allocator.alloc(usize, words);
        @memset(bits, 0);
        return .{ .bits = bits, .capacity = capacity, .allocator = allocator };
    }

    pub fn deinit(self: Bitmap) void {
        self.allocator.free(self.bits);
    }

    /// Test bit at index
    pub fn get(self: Bitmap, index: usize) bool {
        if (index >= self.capacity) return false;
        const word = index / USIZE_BITS;
        const bit = @as(u6, @intCast(index % USIZE_BITS));
        return (self.bits[word] & (@as(usize, 1) << bit)) != 0;
    }

    /// Set bit to 1
    pub fn set(self: *Bitmap, index: usize) void {
        if (index >= self.capacity) return;
        const word = index / USIZE_BITS;
        const bit = @as(u6, @intCast(index % USIZE_BITS));
        self.bits[word] |= @as(usize, 1) << bit;
    }

    /// Set bit to 0
    pub fn clear(self: *Bitmap, index: usize) void {
        if (index >= self.capacity) return;
        const word = index / USIZE_BITS;
        const bit = @as(u6, @intCast(index % USIZE_BITS));
        self.bits[word] &= ~(@as(usize, 1) << bit);
    }

    /// Toggle bit
    pub fn flip(self: *Bitmap, index: usize) void {
        if (index >= self.capacity) return;
        const word = index / USIZE_BITS;
        const bit = @as(u6, @intCast(index % USIZE_BITS));
        self.bits[word] ^= @as(usize, 1) << bit;
    }

    /// Set all bits to 1
    pub fn setAll(self: *Bitmap) void {
        const full_words = self.capacity / USIZE_BITS;
        for (0..full_words) |i| {
            self.bits[i] = ~@as(usize, 0);
        }
        // Partial word
        const remaining = self.capacity % USIZE_BITS;
        if (remaining > 0) {
            self.bits[full_words] = (@as(usize, 1) << remaining) - 1;
        }
    }

    /// Set all bits to 0
    pub fn clearAll(self: *Bitmap) void {
        @memset(self.bits, 0);
    }

    /// Count set bits (popcount)
    pub fn count(self: Bitmap) usize {
        var total: usize = 0;
        for (self.bits) |word| {
            total += @popCount(word);
        }
        return total;
    }

    /// Index of first set bit
    pub fn findFirst(self: Bitmap) ?usize {
        for (self.bits, 0..) |word, wi| {
            if (word != 0) {
                const ctz = @ctz(word);
                const index = wi * USIZE_BITS + ctz;
                if (index < self.capacity) return index;
            }
        }
        return null;
    }

    /// Index of last set bit
    pub fn findLast(self: Bitmap) ?usize {
        var i = self.bits.len;
        while (i > 0) {
            i -= 1;
            const word = self.bits[i];
            if (word != 0) {
                const clz = @clz(word);
                const bit_index = USIZE_BITS - 1 - clz;
                const index = i * USIZE_BITS + bit_index;
                if (index < self.capacity) return index;
            }
        }
        return null;
    }
};

test "Bitmap.init" {
    var bm = try Bitmap.init(100, std.testing.allocator);
    defer bm.deinit();
    try std.testing.expectEqual(@as(usize, 100), bm.capacity);
}

test "Bitmap.set get" {
    var bm = try Bitmap.init(100, std.testing.allocator);
    defer bm.deinit();
    bm.set(42);
    try std.testing.expect(bm.get(42));
    try std.testing.expect(!bm.get(41));
}

test "Bitmap.count" {
    var bm = try Bitmap.init(100, std.testing.allocator);
    defer bm.deinit();
    bm.set(1);
    bm.set(2);
    bm.set(3);
    try std.testing.expectEqual(@as(usize, 3), bm.count());
}
