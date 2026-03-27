//! tri/generic — Generic type utilities and type-level programming
//! Auto-generated from specs/tri/tri_generic.tri
//! TTT Dogfood v0.2 Stage 66

const std = @import("std");

/// Get the size of a type in bytes
pub fn SizeOf(comptime T: type) comptime_int {
    return @sizeOf(T);
}

/// Get the alignment of a type
pub fn AlignOf(comptime T: type) comptime_int {
    return @alignOf(T);
}

/// Check if type is integer
pub fn isInt(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => true,
        else => false,
    };
}

/// Check if type is float
pub fn isFloat(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .float, .comptime_float => true,
        else => false,
    };
}

/// Check if type is number (int or float)
pub fn isNumber(comptime T: type) bool {
    return isInt(T) or isFloat(T);
}

/// Check if type is optional
pub fn isOptional(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

/// Check if type is error union
pub fn isErrorUnion(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .error_union => true,
        else => false,
    };
}

/// Check if type is slice
pub fn isSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .slice,
        else => false,
    };
}

/// Check if type is pointer
pub fn isPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => true,
        else => false,
    };
}

/// Check if type is array
pub fn isArray(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .array => true,
        else => false,
    };
}

/// Get element type of slice or pointer
pub fn ElemType(comptime T: type) type {
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            return ptr.child;
        },
        .array => |arr| {
            return arr.child;
        },
        else => {
            @compileError("Type " ++ @typeName(T) ++ " has no element type");
        },
    }
}

/// Get length of array or slice (runtime for slices, comptime for arrays)
pub fn Len(container: anytype) usize {
    const T = @TypeOf(container);
    switch (@typeInfo(T)) {
        .array => |arr| {
            return arr.len;
        },
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                return container.len;
            }
            @compileError("Cannot get length of non-slice pointer");
        },
        .@"struct" => |s| {
            inline for (s.fields) |field| {
                if (comptime std.mem.eql(u8, field.name, "len")) {
                    return @field(container, "len");
                }
            }
            @compileError("Type " ++ @typeName(T) ++ " has no len field");
        },
        else => {
            @compileError("Cannot get length of type " ++ @typeName(T));
        },
    }
}

/// Identity function (useful for generic type erasure)
pub fn Identity(comptime T: type) type {
    return T;
}

/// Const-qualified type
pub fn Const(comptime T: type) type {
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            var new_ptr = ptr;
            new_ptr.is_const = true;
            return @Type(.{ .pointer = new_ptr });
        },
        else => {
            @compileError("Type " ++ @typeName(T) ++ " is not a pointer");
        },
    }
}

/// Mut-qualified type
pub fn Mut(comptime T: type) type {
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            var new_ptr = ptr;
            new_ptr.is_const = false;
            return @Type(.{ .pointer = new_ptr });
        },
        else => {
            @compileError("Type " ++ @typeName(T) ++ " is not a pointer");
        },
    }
}

/// Create a slice type
pub fn Slice(comptime Child: type) type {
    return []Child;
}

/// Create an optional type
pub fn Optional(comptime T: type) type {
    return ?T;
}

/// Max of two comptime integers
pub fn Max(comptime a: comptime_int, comptime b: comptime_int) comptime_int {
    return if (a > b) a else b;
}

/// Min of two comptime integers
pub fn Min(comptime a: comptime_int, comptime b: comptime_int) comptime_int {
    return if (a < b) a else b;
}

/// Clamp value between min and max
pub fn Clamp(value: anytype, min_val: anytype, max_val: anytype) @TypeOf(value) {
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

/// Swap two values
pub fn Swap(a: anytype, b: anytype) void {
    const T = @TypeOf(a);
    const BType = @TypeOf(b);
    comptime {
        std.debug.assert(T == BType);
        std.debug.assert(switch (@typeInfo(T)) {
            .pointer => |ptr| ptr.size == .one,
            else => false,
        });
    }
    const temp = a.*;
    a.* = b.*;
    b.* = temp;
}

test "SizeOf" {
    try std.testing.expectEqual(@as(usize, 4), SizeOf(i32));
    try std.testing.expectEqual(@as(usize, 8), SizeOf(i64));
    try std.testing.expectEqual(@as(usize, 1), SizeOf(u8));
}

test "AlignOf" {
    try std.testing.expectEqual(@as(usize, 4), AlignOf(i32));
    try std.testing.expectEqual(@as(usize, 8), AlignOf(i64));
}

test "isInt" {
    try std.testing.expect(isInt(i32));
    try std.testing.expect(isInt(u64));
    try std.testing.expect(!isInt(f64));
    try std.testing.expect(!isInt(bool));
}

test "isFloat" {
    try std.testing.expect(isFloat(f32));
    try std.testing.expect(isFloat(f64));
    try std.testing.expect(!isFloat(i32));
}

test "isNumber" {
    try std.testing.expect(isNumber(i32));
    try std.testing.expect(isNumber(f64));
    try std.testing.expect(!isNumber(bool));
}

test "isOptional" {
    try std.testing.expect(isOptional(?i32));
    try std.testing.expect(!isOptional(i32));
}

test "isSlice" {
    try std.testing.expect(isSlice([]const u8));
    try std.testing.expect(isSlice([]i32));
    try std.testing.expect(!isSlice([5]i32));
    try std.testing.expect(!isSlice(*const i32));
}

test "isPointer" {
    try std.testing.expect(isPointer(*const i32));
    try std.testing.expect(isPointer([]i32));
    try std.testing.expect(!isPointer(i32));
}

test "isArray" {
    try std.testing.expect(isArray([5]i32));
    try std.testing.expect(isArray([0]u8));
    try std.testing.expect(!isArray([]i32));
}

test "ElemType slice" {
    try std.testing.expect(EqualTypes(u8, ElemType([]const u8)));
    try std.testing.expect(EqualTypes(i32, ElemType([]i32)));
}

test "ElemType pointer" {
    try std.testing.expect(EqualTypes(u8, ElemType(*const u8)));
    try std.testing.expect(EqualTypes(i32, ElemType(*i32)));
}

test "ElemType array" {
    try std.testing.expect(EqualTypes(i32, ElemType([10]i32)));
}

test "Len array" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(usize, 5), Len(arr));
}

test "Len slice" {
    const slice: []const i32 = &[_]i32{ 1, 2, 3 };
    try std.testing.expectEqual(@as(usize, 3), Len(slice));
}

test "Identity" {
    try std.testing.expect(EqualTypes(i32, Identity(i32)));
    try std.testing.expect(EqualTypes([]u8, Identity([]u8)));
}

test "Const" {
    try std.testing.expect(EqualTypes([]const u8, Const([]u8)));
    try std.testing.expect(EqualTypes(*const i32, Const(*i32)));
}

test "Mut" {
    try std.testing.expect(EqualTypes([]u8, Mut([]const u8)));
    try std.testing.expect(EqualTypes(*i32, Mut(*const i32)));
}

test "Slice" {
    try std.testing.expect(EqualTypes([]i32, Slice(i32)));
    try std.testing.expect(EqualTypes([]u8, Slice(u8)));
}

test "Optional" {
    try std.testing.expect(EqualTypes(?i32, Optional(i32)));
    try std.testing.expect(EqualTypes(?bool, Optional(bool)));
}

test "Max" {
    try std.testing.expectEqual(@as(comptime_int, 10), Max(5, 10));
    try std.testing.expectEqual(@as(comptime_int, 20), Max(20, 5));
}

test "Min" {
    try std.testing.expectEqual(@as(comptime_int, 5), Min(5, 10));
    try std.testing.expectEqual(@as(comptime_int, 5), Min(20, 5));
}

test "Clamp" {
    try std.testing.expectEqual(@as(i32, 5), Clamp(@as(i32, 3), 5, 10));
    try std.testing.expectEqual(@as(i32, 7), Clamp(@as(i32, 7), 5, 10));
    try std.testing.expectEqual(@as(i32, 10), Clamp(@as(i32, 15), 5, 10));
}

test "Swap" {
    var a = @as(i32, 1);
    var b = @as(i32, 2);
    Swap(&a, &b);
    try std.testing.expectEqual(@as(i32, 2), a);
    try std.testing.expectEqual(@as(i32, 1), b);
}

/// Helper for type equality checks
fn EqualTypes(comptime A: type, comptime B: type) bool {
    return A == B;
}
