// ═══════════════════════════════════════════════════════════════════════════
// Array Types (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/tri-lang/array_types.tri
//
// Issue #413: Array Combinators
//
// Implements:
// - Fixed-size arrays with compile-time size
// - Runtime bounds checking
// - Array combinators: map, reduce, scan, filter, flatMap, zip
// - TRI-27 lowering: [bank:3bits][offset:12bits]
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════
// FIXED-SIZE ARRAY
// ═══════════════════════════════════════════════════════════════════════

/// Fixed-size array with compile-time bounds checking
/// ArrayFixed(N, T) — array of N elements of type T
pub fn ArrayFixed(comptime T: type, comptime N: usize) type {
    return struct {
        /// Underlying data storage
        data: [N]T,

        const Self = @This();

        /// Create a new array with undefined values
        pub fn initUndefined() Self {
            return .{ .data = undefined };
        }

        /// Create a new array filled with a default value
        pub fn initDefault(default_value: T) Self {
            var result: Self = undefined;
            for (&result.data) |*item| {
                item.* = default_value;
            }
            return result;
        }

        /// Create an array from a slice
        pub fn fromSlice(slice: []const T) !Self {
            if (slice.len != N) {
                return error.SliceLengthMismatch;
            }
            var result: Self = undefined;
            @memcpy(&result.data, slice);
            return result;
        }

        /// Get element at index with bounds checking
        pub fn get(self: *const Self, index: usize) !T {
            if (index >= N) {
                return error.OutOfBounds;
            }
            return self.data[index];
        }

        /// Get element at index without bounds checking (unsafe)
        pub fn getUnsafe(self: *const Self, index: usize) T {
            return self.data[index];
        }

        /// Set element at index with bounds checking
        pub fn set(self: *Self, index: usize, value: T) !void {
            if (index >= N) {
                return error.OutOfBounds;
            }
            self.data[index] = value;
        }

        /// Set element at index without bounds checking (unsafe)
        pub fn setUnsafe(self: *Self, index: usize, value: T) void {
            self.data[index] = value;
        }

        /// Get array length (compile-time constant)
        pub fn len(self: *const Self) usize {
            _ = self;
            return N;
        }

        /// Get array size in bytes
        pub fn byteLen(self: *const Self) usize {
            _ = self;
            return N * @sizeOf(T);
        }

        /// Convert to slice
        pub fn asSlice(self: *const Self) []const T {
            return &self.data;
        }

        /// Convert to mutable slice
        pub fn asMutSlice(self: *Self) []T {
            return &self.data;
        }

        /// Fill array with a value
        pub fn fill(self: *Self, value: T) void {
            for (&self.data) |*item| {
                item.* = value;
            }
        }

        /// Copy contents from another array
        pub fn copyFrom(self: *Self, other: Self) void {
            @memcpy(&self.data, &other.data);
        }

        /// Check if array contains a value
        pub fn contains(self: *const Self, value: T) bool {
            for (self.data) |item| {
                if (item == value) return true;
            }
            return false;
        }

        /// Find index of value, returns null if not found
        pub fn indexOf(self: *const Self, value: T) ?usize {
            for (self.data, 0..) |item, i| {
                if (item == value) return i;
            }
            return null;
        }

        /// Reverse the array in place
        pub fn reverse(self: *Self) void {
            var i: usize = 0;
            var j: usize = N - 1;
            while (i < j) : ({
                i += 1;
                j -= 1;
            }) {
                const temp = self.data[i];
                self.data[i] = self.data[j];
                self.data[j] = temp;
            }
        }

        // ═══════════════════════════════════════════════════════════════════════
        // ARRAY COMBINATORS (Futhark-style)
        // ═══════════════════════════════════════════════════════════════════════

        /// Map: apply function to each element
        pub fn map(self: *const Self, comptime U: type, mapper: fn (T) U) ArrayFixed(U, N) {
            var result: ArrayFixed(U, N) = undefined;
            for (&self.data, &result.data, 0..) |*src, *dst, i| {
                dst.* = mapper(src.*);
                _ = i;
            }
            return result;
        }

        /// Reduce: fold array using binary operation
        pub fn reduce(self: *const Self, initial: T, op: fn (T, T) T) T {
            var result = initial;
            for (self.data) |item| {
                result = op(result, item);
            }
            return result;
        }

        /// Scan: prefix scan (inclusive)
        pub fn scan(self: *const Self, initial: T, op: fn (T, T) T) ArrayFixed(T, N) {
            var result: ArrayFixed(T, N) = undefined;
            var acc = initial;
            for (self.data, &result.data) |item, *out| {
                acc = op(acc, item);
                out.* = acc;
            }
            return result;
        }

        /// Filter: keep elements matching predicate
        /// Returns slice of elements (may be shorter than N)
        pub fn filter(self: *const Self, allocator: std.mem.Allocator, predicate: fn (T) bool) ![]T {
            var result = std.ArrayList(T).init(allocator);
            for (self.data) |item| {
                if (predicate(item)) {
                    try result.append(item);
                }
            }
            return result.toOwnedSlice();
        }

        /// Zip: combine with another array element-wise
        pub fn zip(self: *const Self, comptime U: type, other: ArrayFixed(U, N)) ArrayFixed(std.meta.Tuple(&.{ T, U }), N) {
            var result: ArrayFixed(std.meta.Tuple(&.{ T, U }), N) = undefined;
            for (&self.data, &other.data, &result.data) |*a, *b, *out| {
                out.* = .{ a.*, b.* };
            }
            return result;
        }

        /// FlatMap: apply function returning array and flatten
        /// Result size depends on the function
        /// Usage: arr.flatMap(U, M, mapper)
        pub fn flatMap(self: Self, comptime U: type, comptime M: usize, mapper: fn (T) ArrayFixed(U, M)) ArrayFixed(U, N * M) {
            var result: ArrayFixed(U, N * M) = undefined;
            var offset: usize = 0;
            for (self.data) |item| {
                const mapped = mapper(item);
                @memcpy(result.data[offset..][0..M], &mapped.data);
                offset += M;
            }
            return result;
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════
// TRI-27 LOWERING
// ═══════════════════════════════════════════════════════════════════════

/// Lowered array representation for TRI-27 VM
/// Format: [bank:3bits][size:12bits][data...]
pub const LoweredArray = struct {
    /// Base address (includes bank in high bits)
    base_addr: u16,
    /// Number of elements
    size: u12,
    /// Element size in bytes
    element_size: u8,
};

/// Get TRI-27 memory address for array element
/// Format: [bank:3bits][offset:12bits]
pub fn arrayAddress(bank: u4, offset: u12) u16 {
    return (@as(u16, bank) << 12) | offset;
}

/// Lower array to TRI-27 representation
pub fn lowerArrayFixed(comptime T: type, comptime N: usize, array: ArrayFixed(T, N)) LoweredArray {
    _ = array;
    return LoweredArray{
        .base_addr = arrayAddress(0, 0), // TODO: allocate actual memory
        .size = @intCast(N),
        .element_size = @intCast(@sizeOf(T)),
    };
}

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════

test "ArrayFixed init and get" {
    const arr = ArrayFixed(i32, 5).initDefault(42);
    try std.testing.expectEqual(@as(usize, 5), arr.len());
    const val = try arr.get(0);
    try std.testing.expectEqual(@as(i32, 42), val);
}

test "ArrayFixed bounds check" {
    const arr = ArrayFixed(i32, 3).initUndefined();
    try std.testing.expectError(error.OutOfBounds, arr.get(10));
}

test "ArrayFixed set and get" {
    var arr = ArrayFixed(i32, 4).initUndefined();
    try arr.set(2, 99);
    const val = try arr.get(2);
    try std.testing.expectEqual(@as(i32, 99), val);
}

test "ArrayFixed fill" {
    var arr = ArrayFixed(i32, 5).initUndefined();
    arr.fill(42);
    for (0..5) |i| {
        const val = arr.getUnsafe(i);
        try std.testing.expectEqual(@as(i32, 42), val);
    }
}

test "ArrayFixed contains" {
    const arr = blk: {
        var a: ArrayFixed(i32, 5) = undefined;
        a.data = .{ 1, 2, 3, 4, 5 };
        break :blk a;
    };
    try std.testing.expect(arr.contains(3));
    try std.testing.expect(!arr.contains(99));
}

test "ArrayFixed indexOf" {
    const arr = blk: {
        var a: ArrayFixed(i32, 5) = undefined;
        a.data = .{ 10, 20, 30, 40, 50 };
        break :blk a;
    };
    try std.testing.expectEqual(@as(?usize, 2), arr.indexOf(30));
    try std.testing.expectEqual(@as(?usize, null), arr.indexOf(99));
}

test "ArrayFixed reverse" {
    var arr = blk: {
        var a: ArrayFixed(i32, 5) = undefined;
        a.data = .{ 1, 2, 3, 4, 5 };
        break :blk a;
    };
    arr.reverse();
    try std.testing.expectEqual(@as(i32, 5), arr.data[0]);
    try std.testing.expectEqual(@as(i32, 1), arr.data[4]);
}

test "ArrayFixed map" {
    const arr = blk: {
        var a: ArrayFixed(i32, 4) = undefined;
        a.data = .{ 1, 2, 3, 4 };
        break :blk a;
    };

    const doubled = arr.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 2), doubled.data[0]);
    try std.testing.expectEqual(@as(i32, 8), doubled.data[3]);
}

test "ArrayFixed reduce" {
    const arr = blk: {
        var a: ArrayFixed(i32, 5) = undefined;
        a.data = .{ 1, 2, 3, 4, 5 };
        break :blk a;
    };

    const sum = arr.reduce(0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 15), sum);
}

test "ArrayFixed scan" {
    const arr = blk: {
        var a: ArrayFixed(i32, 4) = undefined;
        a.data = .{ 1, 2, 3, 4 };
        break :blk a;
    };

    const prefix_sum = arr.scan(0, struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 1), prefix_sum.data[0]);
    try std.testing.expectEqual(@as(i32, 3), prefix_sum.data[1]);
    try std.testing.expectEqual(@as(i32, 6), prefix_sum.data[2]);
    try std.testing.expectEqual(@as(i32, 10), prefix_sum.data[3]);
}

test "ArrayFixed zip" {
    const arr1 = blk: {
        var a: ArrayFixed(i32, 3) = undefined;
        a.data = .{ 1, 2, 3 };
        break :blk a;
    };
    const arr2 = blk: {
        var a: ArrayFixed(i32, 3) = undefined;
        a.data = .{ 10, 20, 30 };
        break :blk a;
    };

    const zipped = arr1.zip(i32, arr2);

    try std.testing.expectEqual(@as(i32, 1), zipped.data[0].@"0");
    try std.testing.expectEqual(@as(i32, 10), zipped.data[0].@"1");
    try std.testing.expectEqual(@as(i32, 3), zipped.data[2].@"0");
    try std.testing.expectEqual(@as(i32, 30), zipped.data[2].@"1");
}

test "ArrayFixed flatMap" {
    const arr = blk: {
        var a: ArrayFixed(i32, 2) = undefined;
        a.data = .{ 1, 2 };
        break :blk a;
    };

    const doubled = arr.flatMap(i32, 2, struct {
        fn duplicate(x: i32) ArrayFixed(i32, 2) {
            var result: ArrayFixed(i32, 2) = undefined;
            result.data = .{ x, x * 2 };
            return result;
        }
    }.duplicate);

    try std.testing.expectEqual(@as(usize, 4), doubled.len());
    try std.testing.expectEqual(@as(i32, 1), doubled.data[0]);
    try std.testing.expectEqual(@as(i32, 2), doubled.data[1]);
    try std.testing.expectEqual(@as(i32, 2), doubled.data[2]);
    try std.testing.expectEqual(@as(i32, 4), doubled.data[3]);
}

test "ArrayFixed fromSlice" {
    const slice = &[_]i32{ 1, 2, 3, 4, 5 };
    const arr = try ArrayFixed(i32, 5).fromSlice(slice);
    try std.testing.expectEqualSlices(i32, slice, &arr.data);
}

test "ArrayFixed fromSlice wrong length fails" {
    const slice = &[_]i32{ 1, 2, 3 };
    const result = ArrayFixed(i32, 5).fromSlice(slice);
    try std.testing.expectError(error.SliceLengthMismatch, result);
}

test "arrayAddress" {
    const addr1 = arrayAddress(0, 100);
    try std.testing.expectEqual(@as(u16, 100), addr1);

    const addr2 = arrayAddress(1, 100);
    try std.testing.expectEqual(@as(u16, 0x1000 + 100), addr2);

    const addr3 = arrayAddress(7, 0xFFF);
    try std.testing.expectEqual(@as(u16, 0x7FFF), addr3);
}
