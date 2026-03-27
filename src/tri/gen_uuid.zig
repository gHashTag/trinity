//! tri/uuid — Unique identifiers
//! Auto-generated from specs/tri/tri_uuid.tri
//! TTT Dogfood v0.2 Stage 99

const std = @import("std");

/// UUID variant enum
pub const Variant = enum(u2) {
    ncs = 0, // 0b00 - NCS backward compatibility
    rfc4122 = 2, // 0b10 - RFC 4122
    microsoft = 3, // 0b11 - Microsoft GUID
};

/// UUID version enum
pub const Version = enum(u4) {
    time = 1,
    dce_security = 2,
    md5 = 3,
    random = 4,
    sha1 = 5,
};

/// 128-bit UUID
pub const UUID = struct {
    data: [16]u8,

    /// All-zero UUID
    pub fn nil() UUID {
        return .{ .data = [_]u8{0} ** 16 };
    }

    /// Generate random UUID (version 4)
    pub fn v4(rng: *std.Random.DefaultPrng) UUID {
        var data: [16]u8 = undefined;
        rng.fill(&data);

        // Set version 4 bits
        data[6] = (data[6] & 0x0F) | 0x40;
        // Set variant bits
        data[8] = (data[8] & 0x3F) | 0x80;

        return .{ .data = data };
    }

    /// Parse xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    pub fn parse(str: []const u8) !UUID {
        if (str.len != 36) return error.InvalidLength;
        if (str[8] != '-' or str[13] != '-' or str[18] != '-' or str[23] != '-') {
            return error.InvalidFormat;
        }

        var data: [16]u8 = undefined;
        var idx: usize = 0;
        var i: usize = 0;

        while (i < 36) {
            if (i == 8 or i == 13 or i == 18 or i == 23) {
                i += 1;
                continue;
            }
            data[idx] = try hexToVal(str[i], str[i + 1]);
            idx += 1;
            i += 2;
        }

        return .{ .data = data };
    }

    /// Format with hyphens
    pub fn format(uuid: UUID, allocator: std.mem.Allocator) ![]const u8 {
        const result = try allocator.alloc(u8, 36);
        const hex = "0123456789abcdef";

        var out: usize = 0;
        for (0..16) |i| {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                result[out] = '-';
                out += 1;
            }
            result[out] = hex[uuid.data[i] >> 4];
            result[out + 1] = hex[uuid.data[i] & 0x0F];
            out += 2;
        }

        return result;
    }

    /// Compare two UUIDs
    pub fn equals(a: UUID, b: UUID) bool {
        for (0..16) |i| {
            if (a.data[i] != b.data[i]) return false;
        }
        return true;
    }

    /// Get UUID variant
    pub fn variant(uuid: UUID) Variant {
        // Variant is in bits 7-6 of byte 8 (0b10xxxxxx = RFC 4122)
        const v = (uuid.data[8] >> 6) & 0x3;
        return @enumFromInt(v);
    }

    /// Get UUID version or null
    pub fn version(uuid: UUID) ?Version {
        const v = uuid.data[6] >> 4;
        return if (v >= 1 and v <= 5) @enumFromInt(v) else null;
    }

    fn hexToVal(c1: u8, c2: u8) !u8 {
        const high = try charToVal(c1);
        const low = try charToVal(c2);
        return (high << 4) | low;
    }

    fn charToVal(c: u8) !u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => error.InvalidCharacter,
        };
    }
};

test "UUID.nil" {
    const uuid = UUID.nil();
    for (uuid.data) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }
}

test "UUID.v4" {
    var rng = std.Random.DefaultPrng.init(42);
    const uuid = UUID.v4(&rng);
    try std.testing.expectEqual(@as(?Version, Version.random), uuid.version());
    try std.testing.expectEqual(Variant.rfc4122, uuid.variant());
}

test "UUID.parse format" {
    const parsed = try UUID.parse("00000000-0000-4000-8000-000000000000");
    const formatted = try parsed.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);
    try std.testing.expectEqualSlices(u8, "00000000-0000-4000-8000-000000000000", formatted);
}

test "UUID.equals" {
    var rng = std.Random.DefaultPrng.init(42);
    const a = UUID.v4(&rng);
    const b = UUID.v4(&rng);
    try std.testing.expect(!a.equals(b));
    try std.testing.expect(a.equals(a));
}
