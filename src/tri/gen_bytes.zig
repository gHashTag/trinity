//! tri/bytes — Byte array utilities
//! Auto-generated from specs/tri/tri_bytes.tri
//! TTT Dogfood v0.2 Stage 96

const std = @import("std");

/// Mutable byte slice wrapper
pub const Bytes = struct {
    data: []u8,
    owned: bool,
    allocator: ?std.mem.Allocator = null,

    /// Create empty bytes
    pub fn empty() Bytes {
        return .{ .data = &[_]u8{}, .owned = false };
    }

    /// Wrap slice (non-owning)
    pub fn fromSlice(input: []const u8) Bytes {
        // Cast away const for internal use
        return .{
            .data = @constCast(input),
            .owned = false,
        };
    }

    /// Create owned copy
    pub fn clone(bytes: Bytes, allocator: std.mem.Allocator) !Bytes {
        const data = try allocator.alloc(u8, bytes.data.len);
        @memcpy(data, bytes.data);
        return .{ .data = data, .owned = true, .allocator = allocator };
    }

    /// Free owned data
    pub fn deinit(self: Bytes) void {
        if (self.owned) {
            if (self.allocator) |alloc| {
                alloc.free(self.data);
            }
        }
    }

    /// Constant-time comparison
    pub fn equals(a: Bytes, b: Bytes) bool {
        if (a.data.len != b.data.len) return false;
        var result: u8 = 0;
        for (0..a.data.len) |i| {
            result |= a.data[i] ^ b.data[i];
        }
        return result == 0;
    }

    /// Create view subrange
    pub fn slice(bytes: Bytes, start: usize, end: usize) Bytes {
        if (start >= end or end > bytes.data.len) {
            return .{ .data = &[_]u8{}, .owned = false };
        }
        return .{
            .data = bytes.data[start..end],
            .owned = false,
        };
    }

    /// Join two byte arrays
    pub fn concat(a: Bytes, b: Bytes, allocator: std.mem.Allocator) !Bytes {
        const data = try allocator.alloc(u8, a.data.len + b.data.len);
        @memcpy(data[0..a.data.len], a.data);
        @memcpy(data[a.data.len..], b.data);
        return .{ .data = data, .owned = true, .allocator = allocator };
    }

    /// Find pattern or null
    pub fn indexOf(bytes: Bytes, pattern: []const u8) ?usize {
        if (pattern.len == 0) return 0;
        if (pattern.len > bytes.data.len) return null;

        const limit = bytes.data.len - pattern.len + 1;
        for (0..limit) |i| {
            if (std.mem.eql(u8, bytes.data[i..][0..pattern.len], pattern)) {
                return i;
            }
        }
        return null;
    }
};

test "Bytes.empty" {
    const b = Bytes.empty();
    try std.testing.expectEqual(@as(usize, 0), b.data.len);
}

test "Bytes.fromSlice" {
    const input = "hello";
    const b = Bytes.fromSlice(input);
    try std.testing.expectEqualSlices(u8, input, b.data);
}

test "Bytes.equals" {
    const a = Bytes.fromSlice("test");
    const b = Bytes.fromSlice("test");
    const c = Bytes.fromSlice("other");
    try std.testing.expect(a.equals(b));
    try std.testing.expect(!a.equals(c));
}

test "Bytes.concat" {
    const a = Bytes.fromSlice("hello");
    const b = Bytes.fromSlice(" world");
    const result = try a.concat(b, std.testing.allocator);
    defer result.deinit();
    try std.testing.expectEqualSlices(u8, "hello world", result.data);
}
