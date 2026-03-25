// ═══════════════════════════════════════════════════════════════════════════
// array_combinators.zig - Array Combinators for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #413: Array Combinators (map/reduce/scan)
//
// Implements:
// - map: apply function to each element
// - reduce: fold array with binary operation
// - scan: prefix scan (cumulative fold)
// - filter: keep elements matching predicate
// - flatMap: bind for array monad
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ═══════════════════════════════════════════════════════════════════════
// MAP COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Map function: apply f to each element of array
/// map(array, f) -> [f(x) for x in array]
pub fn map(comptime T: type, comptime U: type, allocator: std.mem.Allocator, array: []const T, f: fn (T) U) ![]U {
    const result = try allocator.alloc(U, array.len);
    for (array, 0..) |item, i| {
        result[i] = f(item);
    }
    return result;
}

/// Map in-place (mutates original array)
pub fn mapInPlace(comptime T: type, array: []T, f: fn (T) T) void {
    for (array, 0..) |item, i| {
        array[i] = f(item);
    }
}

// ═══════════════════════════════════════════════════════════════════════
// REDUCE COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Reduce function: fold array with binary operation
/// reduce(array, init, op) -> op(...op(op(init, arr[0]), arr[1]), ...)
pub fn reduce(comptime T: type, array: []const T, init: T, op: fn (T, T) T) T {
    var acc = init;
    for (array) |item| {
        acc = op(acc, item);
    }
    return acc;
}

/// Reduce with index
pub fn reduceIndexed(comptime T: type, array: []const T, init: T, op: fn (T, T, usize) T) T {
    var acc = init;
    for (array, 0..) |item, i| {
        acc = op(acc, item, i);
    }
    return acc;
}

// ═══════════════════════════════════════════════════════════════════════
// SCAN COMBINATOR (Prefix Scan)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Scan function: prefix cumulative sum
/// scan(array, init, op) -> [init, op(init, arr[0]), op(op(init, arr[0]), arr[1]), ...]
pub fn scan(comptime T: type, allocator: std.mem.Allocator, array: []const T, init: T, op: fn (T, T) T) ![]T {
    const result = try allocator.alloc(T, array.len);
    var acc = init;
    for (array, 0..) |item, i| {
        acc = op(acc, item);
        result[i] = acc;
    }
    return result;
}

/// Inclusive scan (includes current element)
pub fn scanInclusive(comptime T: type, allocator: std.mem.Allocator, array: []const T, init: T, op: fn (T, T) T) ![]T {
    const result = try allocator.alloc(T, array.len);
    if (array.len == 0) return result;

    var acc = op(init, array[0]);
    result[0] = acc;

    for (array[1..], 0..) |item, i| {
        acc = op(acc, item);
        result[i + 1] = acc;
    }
    return result;
}

/// Exclusive scan (excludes current element)
pub fn scanExclusive(comptime T: type, allocator: std.mem.Allocator, array: []const T, init: T, op: fn (T, T) T) ![]T {
    const result = try allocator.alloc(T, array.len);
    var acc = init;
    for (array, 0..) |item, i| {
        result[i] = acc;
        acc = op(acc, item);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
// FILTER COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Filter function: keep elements matching predicate
/// filter(array, pred) -> [x for x in array if pred(x)]
pub fn filter(comptime T: type, allocator: std.mem.Allocator, array: []const T, pred: fn (T) bool) ![]T {
    // First pass: count matching elements
    var count: usize = 0;
    for (array) |item| {
        if (pred(item)) count += 1;
    }

    // Second pass: copy matching elements
    const result = try allocator.alloc(T, count);
    var idx: usize = 0;
    for (array) |item| {
        if (pred(item)) {
            result[idx] = item;
            idx += 1;
        }
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
// FLATMAP COMBINATOR (Array Monad Bind)
// ═════════════════════════════════════════════════════════════════════════════════════

/// FlatMap function: apply f that returns array, flatten results
/// flatMap(array, f) -> concat([f(x) for x in array])
pub fn flatMap(comptime T: type, comptime U: type, allocator: std.mem.Allocator, array: []const T, f: fn (T) []const U) ![]U {
    // First pass: count total elements
    var total: usize = 0;
    for (array) |item| {
        const mapped = f(item);
        total += mapped.len;
    }

    // Second pass: copy elements
    const result = try allocator.alloc(U, total);
    var idx: usize = 0;
    for (array) |item| {
        const mapped = f(item);
        @memcpy(result[idx..], mapped);
        idx += mapped.len;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
// FOLD COMBINATORS (Left/Right)
// ═════════════════════════════════════════════════════════════════════════════════════

/// FoldLeft: op(op(...op(init, arr[0]), arr[1]), arr[n-1])
pub fn foldLeft(comptime T: type, array: []const T, init: T, op: fn (T, T) T) T {
    return reduce(T, array, init, op);
}

/// FoldRight: op(arr[0], op(arr[1], ...op(arr[n-1], init)...))
pub fn foldRight(comptime T: type, array: []const T, init: T, op: fn (T, T) T) T {
    var acc = init;
    var i: isize = @intCast(array.len);
    while (i > 0) {
        i -= 1;
        acc = op(array[@intCast(i)], acc);
    }
    return acc;
}

// ═══════════════════════════════════════════════════════════════════════
// ZIP COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Zip two arrays into pairs
/// zip([a1, a2], [b1, b2]) -> [(a1, b1), (a2, b2)]
pub fn zip(comptime T: type, comptime U: type, allocator: std.mem.Allocator, a: []const T, b: []const U) ![]struct { first: T, second: U } {
    const Pair = struct { first: T, second: U };
    const len = @min(a.len, b.len);
    const result = try allocator.alloc(Pair, len);

    for (0..len) |i| {
        result[i] = .{ .first = a[i], .second = b[i] };
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
// PARTITION COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Partition array by predicate
/// partition(array, pred) -> { passing: [x for x if pred(x)], failing: [x for x if !pred(x)] }
pub fn partition(comptime T: type, allocator: std.mem.Allocator, array: []const T, pred: fn (T) bool) !struct { passing: []T, failing: []T } {
    // Count partitions
    var pass_count: usize = 0;
    var fail_count: usize = 0;
    for (array) |item| {
        if (pred(item)) pass_count += 1 else fail_count += 1;
    }

    // Allocate partitions
    const passing = try allocator.alloc(T, pass_count);
    const failing = try allocator.alloc(T, fail_count);

    var pass_idx: usize = 0;
    var fail_idx: usize = 0;
    for (array) |item| {
        if (pred(item)) {
            passing[pass_idx] = item;
            pass_idx += 1;
        } else {
            failing[fail_idx] = item;
            fail_idx += 1;
        }
    }

    return .{ .passing = passing, .failing = failing };
}

// ═══════════════════════════════════════════════════════════════════════
// CHUNKBING COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Chunk array into fixed-size groups
/// chunk([1,2,3,4,5], 2) -> [[1,2], [3,4], [5]]
pub fn chunk(comptime T: type, allocator: std.mem.Allocator, array: []const T, size: usize) ![][]T {
    const chunk_count = (array.len + size - 1) / size;
    const result = try allocator.alloc([]T, chunk_count);

    for (0..chunk_count) |i| {
        const start = i * size;
        const end = @min(start + size, array.len);
        result[i] = array[start..end];
    }

    return result;
}

/// ChunkWithPredicate: chunk by predicate boundary
pub fn chunkBy(comptime T: type, allocator: std.mem.Allocator, array: []const T, pred: fn (T, T) bool) ![][]T {
    var chunks = std.ArrayList([]T).init(allocator);

    if (array.len == 0) {
        try chunks.append(array[0..0]);
        return chunks.toOwnedSlice();
    }

    var start: usize = 0;
    for (array[1..], 0..) |item, i| {
        if (pred(array[i], item)) {
            try chunks.append(array[start .. i + 1]);
            start = i + 1;
        }
    }

    // Add remaining elements
    if (start < array.len) {
        try chunks.append(array[start..]);
    }

    return chunks.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════
// REVERSE COMBINATOR
// ═════════════════════════════════════════════════════════════════════════════════════

/// Reverse array
pub fn reverse(comptime T: type, allocator: std.mem.Allocator, array: []const T) ![]T {
    const result = try allocator.alloc(T, array.len);
    for (array, 0..) |item, i| {
        result[array.len - 1 - i] = item;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
// TAKE/DROP COMBINATORS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Take first n elements
pub fn take(comptime T: type, array: []const T, n: usize) []const T {
    if (n >= array.len) return array;
    return array[0..n];
}

/// Drop first n elements
pub fn drop(comptime T: type, array: []const T, n: usize) []const T {
    if (n >= array.len) return array[0..0];
    return array[n..];
}

/// TakeWhile predicate
pub fn takeWhile(comptime T: type, allocator: std.mem.Allocator, array: []const T, pred: fn (T) bool) ![]T {
    var count: usize = 0;
    for (array) |item| {
        if (!pred(item)) break;
        count += 1;
    }

    const result = try allocator.alloc(T, count);
    @memcpy(result, array[0..count]);
    return result;
}

/// DropWhile predicate
pub fn dropWhile(comptime T: type, allocator: std.mem.Allocator, array: []const T, pred: fn (T) bool) ![]T {
    var start: usize = 0;
    for (array) |item| {
        if (!pred(item)) break;
        start += 1;
    }

    const result = try allocator.alloc(T, array.len - start);
    @memcpy(result, array[start..]);
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
// FIND COMBINATORS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Find first element matching predicate
pub fn find(comptime T: type, array: []const T, pred: fn (T) bool) ?usize {
    for (array, 0..) |item, i| {
        if (pred(item)) return i;
    }
    return null;
}

/// FindLast element matching predicate
pub fn findLast(comptime T: type, array: []const T, pred: fn (T) bool) ?usize {
    var i: isize = @intCast(array.len);
    while (i > 0) : (i -= 1) {
        if (pred(array[@intCast(i - 1)])) return @intCast(i - 1);
    }
    return null;
}

/// FindIndex of element
pub fn findIndex(comptime T: type, array: []const T, value: T) ?usize {
    for (array, 0..) |item, i| {
        if (item == value) return i;
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

// Helper functions for tests
fn double(x: i32) i32 {
    return x * 2;
}

fn isEven(x: i32) bool {
    return @rem(x, 2) == 0;
}

fn dup(x: i32) []const i32 {
    return &[_]i32{ x, x };
}
test "map_identity" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3, 4, 5 };

    const result = try map(i32, i32, allocator, &input, double);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 10), result[4]);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "reduce_sum" {
    const input = [_]i32{ 1, 2, 3, 4, 5 };
    const result = reduce(i32, &input, 0, add);

    try std.testing.expectEqual(@as(i32, 15), result);
}

test "scan_prefix_sum" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try scan(i32, allocator, &input, 0, add);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0]);
    try std.testing.expectEqual(@as(i32, 3), result[1]);
    try std.testing.expectEqual(@as(i32, 6), result[2]);
    try std.testing.expectEqual(@as(i32, 10), result[3]);
    try std.testing.expectEqual(@as(i32, 15), result[4]);
}

test "filter_even" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3, 4, 5, 6 };
    const result = try filter(i32, allocator, &input, isEven);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 4), result[1]);
    try std.testing.expectEqual(@as(i32, 6), result[2]);
}

test "flatMap_duplicate" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3 };
    const result = try flatMap(i32, i32, allocator, &input, dup);

    try std.testing.expectEqual(@as(usize, 6), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0]);
    try std.testing.expectEqual(@as(i32, 1), result[1]);
    try std.testing.expectEqual(@as(i32, 2), result[2]);
    try std.testing.expectEqual(@as(i32, 2), result[3]);
}

test "foldLeft_vs_foldRight" {
    const input = [_]i32{ 1, 2, 3 };
    const left = foldLeft(i32, &input, 0, sub);
    const right = foldRight(i32, &input, 0, sub);

    // left: ((0 - 1) - 2) - 3 = -6
    // right: 1 - (2 - (3 - 0)) = 2
    try std.testing.expectEqual(@as(i32, -6), left);
    try std.testing.expectEqual(@as(i32, 2), right);
}

test "zip_arrays" {
    const allocator = std.testing.allocator;
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 4, 5, 6 };
    const result = try zip(i32, i32, allocator, &a, &b);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0].T);
    try std.testing.expectEqual(@as(i32, 4), result[0].U);
}

test "partition_even_odd" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try partition(i32, allocator, &input, isEven);

    try std.testing.expectEqual(@as(usize, 2), result.passing.len);
    try std.testing.expectEqual(@as(i32, 2), result.passing[0]);
    try std.testing.expectEqual(@as(usize, 3), result.failing.len);
}

test "chunk_array" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try chunk(i32, allocator, &input, 2);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(usize, 2), result[0].len);
    try std.testing.expectEqual(@as(usize, 1), result[2].len);
}

test "reverse_array" {
    const allocator = std.testing.allocator;
    const input = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try reverse(i32, allocator, &input);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(i32, 5), result[0]);
    try std.testing.expectEqual(@as(i32, 1), result[4]);
}

test "take_drop" {
    const input = [_]i32{ 1, 2, 3, 4, 5 };

    const taken = take(i32, &input, 3);
    try std.testing.expectEqual(@as(usize, 3), taken.len);
    try std.testing.expectEqual(@as(i32, 1), taken[0]);

    const dropped = drop(i32, &input, 2);
    try std.testing.expectEqual(@as(usize, 3), dropped.len);
    try std.testing.expectEqual(@as(i32, 3), dropped[0]);
}

test "find_predicate" {
    const input = [_]i32{ 1, 2, 3, 4, 5 };

    const found = find(i32, &input, gt3);
    try std.testing.expectEqual(@as(usize, 3), found.?);

    const not_found = find(i32, &input, gt10);
    try std.testing.expect(not_found == null);
}

test "findIndex_value" {
    const input = [_]i32{ 1, 2, 3, 4, 5 };

    const found = findIndex(i32, &input, 3);
    try std.testing.expectEqual(@as(usize, 2), found.?);

    const not_found = findIndex(i32, &input, 10);
    try std.testing.expect(not_found == null);
}

fn gt3(x: i32) bool {
    return x > 3;
}

fn gt10(x: i32) bool {
    return x > 10;
}

fn sub(a: i32, b: i32) i32 {
    return a - b;
}
