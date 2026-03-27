//! TRI JSON — Generated from specs/tri/tri_json.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// JSON value types
pub const JsonType = enum(u8) {
    null,
    boolean,
    number,
    string,
    array,
    object,
};

/// JSON value (variant type)
pub const JsonValue = struct {
    type: JsonType,
    string: ?[]const u8,
    number: ?f64,
    boolean: ?bool,
    array: ?[]JsonValue,
    object: ?[]JsonEntry,

    /// Free JSON value memory
    pub fn deinit(self: *JsonValue, allocator: std.mem.Allocator) void {
        if (self.string) |s| allocator.free(s);
        if (self.array) |arr| {
            for (arr) |*item| {
                item.deinit(allocator);
            }
            allocator.free(arr);
        }
        if (self.object) |obj| {
            for (obj) |*entry| {
                allocator.free(entry.key);
                entry.value.deinit(allocator);
            }
            allocator.free(obj);
        }
        self.* = undefined;
    }

    pub fn deinitConst(self: *const JsonValue, allocator: std.mem.Allocator) void {
        @as(*JsonValue, @constCast(self)).deinit(allocator);
    }
};

/// JSON object key-value pair
pub const JsonEntry = struct {
    key: []const u8,
    value: JsonValue,
};

// ============================================================================
// JSON VALUE CONSTRUCTORS
// ============================================================================

/// Create null JSON value
pub fn nullValue() JsonValue {
    return .{
        .type = JsonType.null,
        .string = null,
        .number = null,
        .boolean = null,
        .array = null,
        .object = null,
    };
}

/// Create boolean JSON value
pub fn boolValue(b: bool) JsonValue {
    return .{
        .type = JsonType.boolean,
        .string = null,
        .number = null,
        .boolean = b,
        .array = null,
        .object = null,
    };
}

/// Create number JSON value
pub fn numberValue(n: f64) JsonValue {
    return .{
        .type = JsonType.number,
        .string = null,
        .number = n,
        .boolean = null,
        .array = null,
        .object = null,
    };
}

/// Create string JSON value
pub fn stringValue(allocator: std.mem.Allocator, s: []const u8) !JsonValue {
    const str_copy = try allocator.dupe(u8, s);
    return .{
        .type = JsonType.string,
        .string = str_copy,
        .number = null,
        .boolean = null,
        .array = null,
        .object = null,
    };
}

/// Create array JSON value
pub fn arrayValue(allocator: std.mem.Allocator, items: []const JsonValue) !JsonValue {
    const arr = try allocator.alloc(JsonValue, items.len);
    for (items, 0..) |item, i| {
        // Shallow copy - caller should have allocated items properly
        arr[i] = item;
    }
    return .{
        .type = JsonType.array,
        .string = null,
        .number = null,
        .boolean = null,
        .array = arr,
        .object = null,
    };
}

/// Create object JSON value
pub fn objectValue(allocator: std.mem.Allocator, entries: []const JsonEntry) !JsonValue {
    const obj = try allocator.alloc(JsonEntry, entries.len);
    for (entries, 0..) |entry, i| {
        const key_copy = try allocator.dupe(u8, entry.key);
        obj[i] = .{
            .key = key_copy,
            .value = entry.value,
        };
    }
    return .{
        .type = JsonType.object,
        .string = null,
        .number = null,
        .boolean = null,
        .array = null,
        .object = obj,
    };
}

// ============================================================================
// JSON ACCESSORS
// ============================================================================

/// Get object property by key
pub fn get(obj: JsonValue, key: []const u8) ?JsonValue {
    if (obj.type != JsonType.object) return null;
    const entries = obj.object orelse return null;

    for (entries) |entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            return entry.value;
        }
    }
    return null;
}

/// Get array element by index
pub fn getAt(arr: JsonValue, index: usize) ?JsonValue {
    if (arr.type != JsonType.array) return null;
    const items = arr.array orelse return null;

    if (index >= items.len) return null;
    return items[index];
}

/// Get string value
pub fn asString(val: JsonValue) ?[]const u8 {
    return val.string;
}

/// Get number value
pub fn asNumber(val: JsonValue) ?f64 {
    return val.number;
}

/// Get boolean value
pub fn asBool(val: JsonValue) ?bool {
    return val.boolean;
}

/// Check if value is null
pub fn isNull(val: JsonValue) bool {
    return val.type == JsonType.null;
}

/// Get array length
pub fn arrayLen(val: JsonValue) usize {
    if (val.type != JsonType.array) return 0;
    return if (val.array) |arr| arr.len else 0;
}

/// Get object size
pub fn objectSize(val: JsonValue) usize {
    if (val.type != JsonType.object) return 0;
    return if (val.object) |obj| obj.len else 0;
}

// ============================================================================
// TESTS
// ============================================================================

test "JSON: nullValue" {
    const val = nullValue();
    try std.testing.expect(JsonType.null == val.type);
    try std.testing.expect(isNull(val));
}

test "JSON: boolValue" {
    const val = boolValue(true);
    try std.testing.expect(JsonType.boolean == val.type);
    try std.testing.expect(asBool(val).? == true);
}

test "JSON: numberValue" {
    const val = numberValue(42.5);
    try std.testing.expect(JsonType.number == val.type);
    try std.testing.expectApproxEqAbs(@as(f64, 42.5), asNumber(val).?, 0.001);
}

test "JSON: stringValue" {
    const allocator = std.testing.allocator;
    const val = try stringValue(allocator, "hello");
    defer val.deinitConst(allocator);

    try std.testing.expect(JsonType.string == val.type);
    try std.testing.expectEqualStrings("hello", asString(val).?);
}

test "JSON: arrayValue" {
    const allocator = std.testing.allocator;
    const items = [_]JsonValue{
        numberValue(1),
        numberValue(2),
        numberValue(3),
    };
    const val = try arrayValue(allocator, &items);
    defer val.deinitConst(allocator);

    try std.testing.expect(JsonType.array == val.type);
    try std.testing.expectEqual(@as(usize, 3), arrayLen(val));

    const elem = getAt(val, 1);
    try std.testing.expect(elem != null);
    try std.testing.expectApproxEqAbs(@as(f64, 2), asNumber(elem.?).?, 0.001);
}

test "JSON: objectValue" {
    const allocator = std.testing.allocator;
    const entries = [_]JsonEntry{
        .{ .key = "name", .value = try stringValue(allocator, "test") },
        .{ .key = "count", .value = numberValue(42) },
    };
    const val = try objectValue(allocator, &entries);
    defer val.deinitConst(allocator);

    try std.testing.expect(JsonType.object == val.type);
    try std.testing.expectEqual(@as(usize, 2), objectSize(val));

    const name_val = get(val, "name");
    try std.testing.expect(name_val != null);
    try std.testing.expectEqualStrings("test", asString(name_val.?).?);

    const count_val = get(val, "count");
    try std.testing.expect(count_val != null);
    try std.testing.expectApproxEqAbs(@as(f64, 42), asNumber(count_val.?).?, 0.001);
}

test "JSON: get missing key" {
    const allocator = std.testing.allocator;
    const entries = [_]JsonEntry{
        .{ .key = "name", .value = try stringValue(allocator, "test") },
    };
    const val = try objectValue(allocator, &entries);
    defer val.deinitConst(allocator);

    const missing = get(val, "missing");
    try std.testing.expect(missing == null);
}

test "JSON: getAt out of bounds" {
    const allocator = std.testing.allocator;
    const items = [_]JsonValue{numberValue(1)};
    const val = try arrayValue(allocator, &items);
    defer val.deinitConst(allocator);

    const out_of_bounds = getAt(val, 10);
    try std.testing.expect(out_of_bounds == null);
}
