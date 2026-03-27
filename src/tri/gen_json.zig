//! tri/json — Data format handling
//! Auto-generated from specs/tri/tri_json.tri
//! TTT Dogfood v0.2 Stage 103

const std = @import("std");

/// JSON value kind
pub const JsonType = enum {
    Null,
    Bool,
    Number,
    String,
    Array,
    Object,
};

/// JSON value data (union)
pub const JsonValueData = union(JsonType) {
    Null: void,
    Bool: bool,
    Number: f64,
    String: []const u8,
    Array: std.ArrayList(JsonValue),
    Object: std.StringHashMap(JsonValue),
};

/// JSON value variant
pub const JsonValue = struct {
    type: JsonType,
    data: JsonValueData,

    /// Create null value
    pub fn nullValue() JsonValue {
        return .{ .type = .Null, .data = .{ .Null = {} } };
    }

    /// Create bool value
    pub fn boolValue(b: bool) JsonValue {
        return .{ .type = .Bool, .data = .{ .Bool = b } };
    }

    /// Create number value
    pub fn numberValue(n: f64) JsonValue {
        return .{ .type = .Number, .data = .{ .Number = n } };
    }

    /// Create string value
    pub fn stringValue(s: []const u8) JsonValue {
        return .{ .type = .String, .data = .{ .String = s } };
    }
};

/// JSON array
pub const JsonArray = struct {
    items: std.ArrayList(JsonValue),
};

/// JSON object
pub const JsonObject = struct {
    fields: std.StringHashMap(JsonValue),

    /// Get object field
    pub fn get(obj: *const JsonObject, key: []const u8) ?JsonValue {
        return obj.fields.get(key);
    }
};

/// Parse JSON text (simplified - only null, bool, numbers, strings)
pub fn parse(text: []const u8, allocator: std.mem.Allocator) !JsonValue {
    _ = allocator;
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    if (trimmed.len == 0) return error.EmptyInput;

    // Null
    if (std.mem.eql(u8, trimmed, "null")) {
        return JsonValue.nullValue();
    }

    // Bool
    if (std.mem.eql(u8, trimmed, "true")) {
        return JsonValue.boolValue(true);
    }
    if (std.mem.eql(u8, trimmed, "false")) {
        return JsonValue.boolValue(false);
    }

    // String
    if (trimmed[0] == '"') {
        const end = std.mem.indexOfScalarPos(u8, trimmed, '"', 1) orelse return error.UnterminatedString;
        return JsonValue.stringValue(trimmed[1..end]);
    }

    // Number (simplified)
    const num = std.fmt.parseFloat(f64, trimmed) catch return error.InvalidNumber;
    return JsonValue.numberValue(num);
}

/// Convert to JSON string (simplified)
pub fn stringify(value: JsonValue, allocator: std.mem.Allocator) ![]u8 {
    switch (value.type) {
        .Null => return allocator.dupe(u8, "null"),
        .Bool => return allocator.dupe(u8, if (value.data.Bool) "true" else "false"),
        .Number => {
            var buf: [64]u8 = undefined;
            const slice = std.fmt.bufPrint(&buf, "{d}", .{value.data.Number}) catch unreachable;
            return allocator.dupe(u8, slice);
        },
        .String => {
            const str = value.data.String;
            var result = try allocator.alloc(u8, str.len + 2);
            result[0] = '"';
            @memcpy(result[1..][0..str.len], str);
            result[str.len + 1] = '"';
            return result;
        },
        else => return error.NotImplemented,
    }
}

test "parse null" {
    const result = try parse("null", std.testing.allocator);
    try std.testing.expectEqual(JsonType.Null, result.type);
}

test "parse bool" {
    const result = try parse("true", std.testing.allocator);
    try std.testing.expectEqual(JsonType.Bool, result.type);
    try std.testing.expectEqual(true, result.data.Bool);
}

test "parse number" {
    const result = try parse("42.5", std.testing.allocator);
    try std.testing.expectEqual(JsonType.Number, result.type);
    try std.testing.expectApproxEqAbs(@as(f64, 42.5), result.data.Number, 0.001);
}

test "stringify bool" {
    const val = JsonValue.boolValue(true);
    const result = try stringify(val, std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, "true", result);
}
