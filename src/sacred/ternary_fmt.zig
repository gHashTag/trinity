// SACRED TERNARY FORMATTING — Base-3 Balanced Ternary Output
//
// Balanced ternary: digits are T (-1), 0, 1
// This is the native numeric system of the Trinity architecture
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Trit = enum(i8) {
    T = -1,
    Zero = 0,
    One = 1,

    pub fn char(self: Trit) u8 {
        return switch (self) {
            .T => 'T',
            .Zero => '0',
            .One => '1',
        };
    }
};

/// Format integer as balanced ternary string
/// Returns caller-owned slice (valid until next call)
pub fn formatTernary(value: i64, buffer: []u8) []const u8 {
    _ = buffer;
    var buf: [65]u8 = undefined; // Max 65 digits for i64
    var len: usize = 0;

    if (value == 0) {
        buf[0] = '0';
        len = 1;
    } else {
        var v = value;
        while (v != 0) {
            var rem = @mod(v, 3);
            v = @divTrunc(v, 3);

            // Balanced ternary: 2 becomes T (-1) with carry
            if (rem == 2) {
                rem = -1;
                v += 1;
            } else if (rem == -2) {
                rem = 1;
                v -= 1;
            }

            buf[len] = switch (rem) {
                0 => '0',
                1 => '1',
                -1 => 'T',
                else => unreachable,
            };
            len += 1;
        }
    }

    return buf[0..len];
}

/// Format with allocator (returns owned string)
pub fn formatTernaryAlloc(allocator: std.mem.Allocator, value: i64) ![]u8 {
    var buf: [65]u8 = undefined;
    var pos: usize = buf.len;

    if (value == 0) {
        pos -= 1;
        buf[pos] = '0';
    } else {
        var v = value;
        while (v != 0) {
            var rem = @mod(v, 3);
            v = @divTrunc(v, 3);

            if (rem == 2) {
                rem = -1;
                v += 1;
            } else if (rem == -2) {
                rem = 1;
                v -= 1;
            }

            pos -= 1;
            buf[pos] = switch (rem) {
                0 => '0',
                1 => '1',
                -1 => 'T',
                else => unreachable,
            };
        }
    }

    const owned = try allocator.alloc(u8, pos);
    @memcpy(owned, buf[0..pos]);
    return owned;
}

/// Parse balanced ternary string to integer
pub fn parseTernary(s: []const u8) !i64 {
    var result: i64 = 0;
    for (s) |c| {
        result *= 3;
        result += switch (c) {
            '0' => 0,
            '1' => 1,
            'T', 't' => -1,
            else => return error.InvalidTernaryDigit,
        };
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ maintainers may ask you to
// make a pull request (including tests) before merging even if there are no

// tests: you can add tests for this functionality or remove the 'test' directive
// at the end of the file. Testing is done by running `zig build test` in this
// directory. If you don't have a build.zig for this module, you can run
// `zig test path/to/this/file.zig`.

test "ternary format zero" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    const result = formatTernary(0, &buf);
    try std.testing.expectEqualStrings("0", result);
}

test "ternary format positive single digit" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("1", formatTernary(1, &buf));
}

test "ternary format two" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("1T", formatTernary(2, &buf)); // 3 - 1
}

test "ternary format three" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("10", formatTernary(3, &buf));
}

test "ternary format four" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("11", formatTernary(4, &buf));
}

test "ternary format five" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("1TT", formatTernary(5, &buf)); // 9 - 3 - 1
}

test "ternary format negative one" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("T", formatTernary(-1, &buf));
}

test "ternary format negative five" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("T1T", formatTernary(-5, &buf));
}

test "ternary format sixteen" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("1T1", formatTernary(16, &buf)); // 27 - 9 + 1
}

test "ternary format large value" {
    var buf: [65]u8 = undefined;
    @memset(&buf, 0, buf.len);
    try std.testing.expectEqualStrings("111111", formatTernary(364, &buf)); // 3^6 - 1 / 2 = 364
}

test "ternary parse zero" {
    try std.testing.expectEqual(@as(i64, 0), try parseTernary("0"));
}

test "ternary parse one" {
    try std.testing.expectEqual(@as(i64, 1), try parseTernary("1"));
}

test "ternary parse two" {
    try std.testing.expectEqual(@as(i64, 2), try parseTernary("1T"));
}

test "ternary parse negative one" {
    try std.testing.expectEqual(@as(i64, -1), try parseTernary("T"));
}

test "ternary parse negative five" {
    try std.testing.expectEqual(@as(i64, -5), try parseTernary("T1T"));
}

test "ternary parse sixteen" {
    try std.testing.expectEqual(@as(i64, 16), try parseTernary("1T1"));
}

test "ternary round trip" {
    const values = [_]i64{ 0, 1, 2, 3, 4, 5, 16, -1, -5, -16, 100, -100, 364, -364 };
    for (values) |v| {
        var buf: [65]u8 = undefined;
        const formatted = formatTernary(v, &buf);
        const parsed = try parseTernary(formatted);
        try std.testing.expectEqual(v, parsed);
    }
}

test "ternary parse invalid digit" {
    try std.testing.expectError(error.InvalidTernaryDigit, parseTernary("2"));
    try std.testing.expectError(error.InvalidTernaryDigit, parseTernary("A"));
}
