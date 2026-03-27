//! TRI Array — Generated from specs/tri/tri_array.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Non-owning view into a slice (for i32)
pub const ArrayViewi32 = struct {
    ptr: [*]const i32,
    len: usize,

    pub fn init(arr_slice: []const i32) ArrayViewi32 {
        return .{
            .ptr = arr_slice.ptr,
            .len = arr_slice.len,
        };
    }

    pub fn slice(self: ArrayViewi32, start: usize, end: usize) []const i32 {
        std.debug.assert(start <= end);
        std.debug.assert(end <= self.len);
        return self.ptr[start..end];
    }

    pub fn get(self: ArrayViewi32, index: usize) i32 {
        std.debug.assert(index < self.len);
        return self.ptr[index];
    }
};

/// Range for slice operations
pub const SliceRange = struct {
    start: usize,
    end: usize,
    step: i64,

    pub fn init(start: usize, end: usize) SliceRange {
        return .{
            .start = start,
            .end = end,
            .step = 1,
        };
    }

    pub fn initWithStep(start: usize, end: usize, step: i64) SliceRange {
        return .{
            .start = start,
            .end = end,
            .step = step,
        };
    }

    pub fn isValid(self: SliceRange) bool {
        return self.start <= self.end and self.step != 0;
    }

    pub fn count(self: SliceRange) usize {
        if (!self.isValid()) return 0;
        const diff = @as(i64, @intCast(self.end)) - @as(i64, @intCast(self.start));
        const step_abs = if (self.step < 0) -self.step else self.step;
        return @as(usize, @intCast(@divTrunc(diff + step_abs - 1, step_abs)));
    }
};

// ============================================================================
// SLICE OPERATIONS (i32)
// ============================================================================

/// Get sub-slice [start:end)
pub fn slice(arr: []const i32, start: usize, end: usize) []const i32 {
    std.debug.assert(start <= end);
    std.debug.assert(end <= arr.len);
    return arr[start..end];
}

/// Get sub-slice from start to end
pub fn sliceFrom(arr: []const i32, start: usize) []const i32 {
    std.debug.assert(start <= arr.len);
    return arr[start..];
}

/// Get first element
pub fn first(arr: []const i32) i32 {
    std.debug.assert(arr.len > 0);
    return arr[0];
}

/// Get last element
pub fn last(arr: []const i32) i32 {
    std.debug.assert(arr.len > 0);
    return arr[arr.len - 1];
}

/// Check if array is empty
pub fn isEmpty(arr: []const i32) bool {
    return arr.len == 0;
}

/// Check if array contains item
pub fn contains(arr: []const i32, item: i32) bool {
    for (arr) |elem| {
        if (elem == item) return true;
    }
    return false;
}

/// Find index of item (returns null if not found)
pub fn indexOf(arr: []const i32, item: i32) ?usize {
    for (arr, 0..) |elem, i| {
        if (elem == item) return i;
    }
    return null;
}

/// Create reversed copy
pub fn reverse(allocator: std.mem.Allocator, arr: []const i32) ![]i32 {
    const result = try allocator.alloc(i32, arr.len);
    for (arr, 0..) |elem, i| {
        result[arr.len - 1 - i] = elem;
    }
    return result;
}

/// Concatenate two arrays
pub fn concat(allocator: std.mem.Allocator, a: []const i32, b: []const i32) ![]i32 {
    const result = try allocator.alloc(i32, a.len + b.len);
    @memcpy(result[0..a.len], a);
    @memcpy(result[a.len..], b);
    return result;
}

// ============================================================================
// BYTE SLICE OPERATIONS (u8)
// ============================================================================

/// Get sub-slice [start:end) for bytes
pub fn sliceBytes(arr: []const u8, start: usize, end: usize) []const u8 {
    std.debug.assert(start <= end);
    std.debug.assert(end <= arr.len);
    return arr[start..end];
}

/// Check if byte array contains item
pub fn containsByte(arr: []const u8, item: u8) bool {
    for (arr) |elem| {
        if (elem == item) return true;
    }
    return false;
}

/// Find index of byte (returns null if not found)
pub fn indexOfByte(arr: []const u8, item: u8) ?usize {
    for (arr, 0..) |elem, i| {
        if (elem == item) return i;
    }
    return null;
}

/// Reverse byte array
pub fn reverseBytes(allocator: std.mem.Allocator, arr: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, arr.len);
    for (arr, 0..) |elem, i| {
        result[arr.len - 1 - i] = elem;
    }
    return result;
}

/// Concatenate byte arrays
pub fn concatBytes(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, a.len + b.len);
    @memcpy(result[0..a.len], a);
    @memcpy(result[a.len..], b);
    return result;
}

// ============================================================================
// TESTS
// ============================================================================

test "Array: slice" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    const result = slice(&arr, 1, 3);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 3), result[1]);
}

test "Array: sliceFrom" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    const result = sliceFrom(&arr, 2);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 3), result[0]);
}

test "Array: first" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(i32, 1), first(&arr));
}

test "Array: last" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(i32, 5), last(&arr));
}

test "Array: isEmpty" {
    const arr1 = [_]i32{ 1, 2, 3 };
    const arr2 = [_]i32{};
    try std.testing.expect(!isEmpty(&arr1));
    try std.testing.expect(isEmpty(&arr2));
}

test "Array: contains" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expect(contains(&arr, 3));
    try std.testing.expect(!contains(&arr, 10));
}

test "Array: indexOf" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(usize, 2), indexOf(&arr, 3).?);
    try std.testing.expect(indexOf(&arr, 10) == null);
}

test "Array: reverse" {
    const allocator = std.testing.allocator;
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try reverse(allocator, &arr);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(i32, 5), result[0]);
    try std.testing.expectEqual(@as(i32, 1), result[4]);
}

test "Array: concat" {
    const allocator = std.testing.allocator;
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 4, 5, 6 };
    const result = try concat(allocator, &a, &b);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 6), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0]);
    try std.testing.expectEqual(@as(i32, 6), result[5]);
}

test "Array: sliceBytes" {
    const arr = [_]u8{ 1, 2, 3, 4, 5 };
    const result = sliceBytes(&arr, 1, 3);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(@as(u8, 2), result[0]);
}

test "Array: containsByte" {
    const arr = [_]u8{ 1, 2, 3, 4, 5 };
    try std.testing.expect(containsByte(&arr, 3));
    try std.testing.expect(!containsByte(&arr, 10));
}

test "Array: ArrayView" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    const view = ArrayViewi32.init(&arr);
    try std.testing.expectEqual(@as(usize, 5), view.len);
    const sub = view.slice(1, 3);
    try std.testing.expectEqual(@as(usize, 2), sub.len);
    try std.testing.expectEqual(@as(i32, 2), view.get(1));
}

test "Array: SliceRange" {
    const range = SliceRange.init(0, 10);
    try std.testing.expect(range.isValid());
    try std.testing.expectEqual(@as(usize, 10), range.count());

    const range_with_step = SliceRange.initWithStep(0, 10, 2);
    try std.testing.expect(range_with_step.isValid());
    try std.testing.expectEqual(@as(usize, 5), range_with_step.count());
}
