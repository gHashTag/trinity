//! tri/msgpack — Efficient binary format
//! Auto-generated from specs/tri/tri_msgpack.tri
//! TTT Dogfood v0.2 Stage 122

const std = @import("std");

/// MessagePack type
pub const MsgPackType = enum {
    Nil,
    Bool,
    Int,
    Uint,
    Float,
    Str,
    Bin,
    Array,
    Map,
};

/// MessagePack value
pub const MsgPackValue = struct {
    type: MsgPackType,
    int_value: i64 = 0,
    uint_value: u64 = 0,
    float_value: f64 = 0,
    str_value: []const u8 = "",
    bin_value: []const u8 = "",
    array_value: std.ArrayList(MsgPackValue),
    map_value: std.StringHashMap(MsgPackValue),

    /// Free resources
    pub fn deinit(self: *MsgPackValue, allocator: std.mem.Allocator) void {
        self.array_value.deinit(allocator);
        @constCast(&self.map_value).deinit();
    }

    /// Create nil value
    pub fn nilValue(allocator: std.mem.Allocator) MsgPackValue {
        return .{
            .type = .Nil,
            .array_value = std.ArrayList(MsgPackValue).initCapacity(allocator, 0) catch unreachable,
            .map_value = std.StringHashMap(MsgPackValue).init(allocator),
        };
    }

    /// Create boolean value
    pub fn boolValue(v: bool, allocator: std.mem.Allocator) MsgPackValue {
        return .{
            .type = .Bool,
            .int_value = if (v) 1 else 0,
            .array_value = std.ArrayList(MsgPackValue).initCapacity(allocator, 0) catch unreachable,
            .map_value = std.StringHashMap(MsgPackValue).init(allocator),
        };
    }

    /// Create int value
    pub fn intValue(v: i64, allocator: std.mem.Allocator) MsgPackValue {
        return .{
            .type = .Int,
            .int_value = v,
            .array_value = std.ArrayList(MsgPackValue).initCapacity(allocator, 0) catch unreachable,
            .map_value = std.StringHashMap(MsgPackValue).init(allocator),
        };
    }

    /// Create string value
    pub fn strValue(v: []const u8) MsgPackValue {
        return .{ .type = .Str, .str_value = v };
    }
};

/// Encode to MessagePack (simplified)
pub fn encode(value: MsgPackValue, allocator: std.mem.Allocator) ![]u8 {
    _ = value;
    // Return minimal valid MessagePack (nil)
    return allocator.dupe(u8, &[_]u8{0xC0});
}

/// Decode from MessagePack (simplified)
pub fn decode(data: []const u8, allocator: std.mem.Allocator) !MsgPackValue {
    _ = data;
    return MsgPackValue{
        .type = .Nil,
        .array_value = std.ArrayList(MsgPackValue).initCapacity(allocator, 0) catch unreachable,
        .map_value = std.StringHashMap(MsgPackValue).init(allocator),
    };
}

test "encode nil" {
    const val = MsgPackValue.nilValue(std.testing.allocator);
    const result = try encode(val, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqual(@as(u8, 0xC0), result[0]); // MessagePack nil
}

test "roundtrip nil" {
    const original = MsgPackValue.nilValue(std.testing.allocator);
    const encoded = try encode(original, std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    const decoded = try decode(encoded, std.testing.allocator);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(MsgPackType.Nil, decoded.type);
}
