//! tri/utf8 — Unicode string handling
//! Auto-generated from specs/tri/tri_utf8.tri
//! TTT Dogfood v0.2 Stage 101

const std = @import("std");

/// UTF-8 encoded character
pub const Rune = struct {
    bytes: [4]u8 = [_]u8{0} ** 4,
    len: u8 = 0,

    /// Create from codepoint
    pub fn fromCodepoint(cp: u21) Rune {
        if (cp <= 0x7F) {
            return .{ .bytes = [_]u8{ @intCast(cp), 0, 0, 0 }, .len = 1 };
        } else if (cp <= 0x7FF) {
            return .{
                .bytes = [_]u8{
                    @intCast(0xC0 | (cp >> 6)),
                    @intCast(0x80 | (cp & 0x3F)),
                    0,
                    0,
                },
                .len = 2,
            };
        } else if (cp <= 0xFFFF) {
            return .{
                .bytes = [_]u8{
                    @intCast(0xE0 | (cp >> 12)),
                    @intCast(0x80 | ((cp >> 6) & 0x3F)),
                    @intCast(0x80 | (cp & 0x3F)),
                    0,
                },
                .len = 3,
            };
        } else {
            return .{
                .bytes = [_]u8{
                    @intCast(0xF0 | (cp >> 18)),
                    @intCast(0x80 | ((cp >> 12) & 0x3F)),
                    @intCast(0x80 | ((cp >> 6) & 0x3F)),
                    @intCast(0x80 | (cp & 0x3F)),
                },
                .len = 4,
            };
        }
    }

    /// Get slice of valid bytes
    pub fn slice(self: Rune) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// Decode UTF-8 character at index
pub fn decode(str: []const u8, index: usize) Rune {
    if (index >= str.len) return Rune{};
    const b0 = str[index];

    if (b0 <= 0x7F) {
        return .{ .bytes = [_]u8{ b0, 0, 0, 0 }, .len = 1 };
    }

    var cp: u21 = 0;
    var len: u8 = 0;

    if ((b0 & 0xE0) == 0xC0) {
        // 2-byte
        if (index + 1 >= str.len) return Rune{};
        cp = @as(u21, b0 & 0x1F) << 6;
        cp |= str[index + 1] & 0x3F;
        len = 2;
    } else if ((b0 & 0xF0) == 0xE0) {
        // 3-byte
        if (index + 2 >= str.len) return Rune{};
        cp = @as(u21, b0 & 0x0F) << 12;
        cp |= @as(u21, str[index + 1] & 0x3F) << 6;
        cp |= str[index + 2] & 0x3F;
        len = 3;
    } else if ((b0 & 0xF8) == 0xF0) {
        // 4-byte
        if (index + 3 >= str.len) return Rune{};
        cp = @as(u21, b0 & 0x07) << 18;
        cp |= @as(u21, str[index + 1] & 0x3F) << 12;
        cp |= @as(u21, str[index + 2] & 0x3F) << 6;
        cp |= str[index + 3] & 0x3F;
        len = 4;
    } else {
        return .{}; // Invalid
    }

    var result: Rune = undefined;
    @memcpy(result.bytes[0..len], str[index..][0..len]);
    result.len = len;
    return result;
}

/// Encode codepoint to UTF-8
pub fn encode(codepoint: u21, allocator: std.mem.Allocator) ![]u8 {
    const r = Rune.fromCodepoint(codepoint);
    return try allocator.dupe(u8, r.slice());
}

/// Count Unicode characters
pub fn countCodepoints(str: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < str.len) {
        const r = decode(str, i);
        if (r.len == 0) break;
        count += 1;
        i += r.len;
    }
    return count;
}

/// Check valid UTF-8
pub fn validate(str: []const u8) bool {
    var i: usize = 0;
    while (i < str.len) {
        const r = decode(str, i);
        if (r.len == 0) return false;
        i += r.len;
    }
    return true;
}

test "Rune.fromCodepoint" {
    const r = Rune.fromCodepoint(0x41); // 'A'
    try std.testing.expectEqual(@as(u8, 1), r.len);
    try std.testing.expectEqual(@as(u8, 0x41), r.bytes[0]);
}

test "encode" {
    const result = try encode(0x20AC, std.testing.allocator); // Euro sign
    defer std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
}

test "countCodepoints" {
    const str = "hello";
    try std.testing.expectEqual(@as(usize, 5), countCodepoints(str));
}

test "validate" {
    try std.testing.expect(validate("hello"));
    try std.testing.expect(validate("hello world"));
}
