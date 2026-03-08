// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FILE ENCODER - Binary-to-Ternary Encoding
// Converts arbitrary binary data to balanced ternary representation
// Each byte (0-255) -> 6 balanced trits (3^6 = 729 > 256)
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const crypto = @import("crypto.zig");

pub const Trit = i8;
pub const TRITS_PER_BYTE: usize = 6; // 3^6 = 729 > 256

// ═══════════════════════════════════════════════════════════════════════════════
// FILE ENCODER
// ═══════════════════════════════════════════════════════════════════════════════

pub const FileEncoder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FileEncoder {
        return .{ .allocator = allocator };
    }

    /// Encode binary data to balanced ternary trits
    /// Each byte (0-255) becomes 6 balanced trits {-1, 0, +1}
    pub fn encodeBinaryToTernary(self: *const FileEncoder, data: []const u8) ![]Trit {
        const trit_count = data.len * TRITS_PER_BYTE;
        const trits = try self.allocator.alloc(Trit, trit_count);
        errdefer self.allocator.free(trits);

        for (data, 0..) |byte, i| {
            const t = byteToBalancedTernary(byte);
            @memcpy(trits[i * TRITS_PER_BYTE ..][0..TRITS_PER_BYTE], &t);
        }

        return trits;
    }

    /// Decode balanced ternary trits back to binary data
    /// Every 6 trits become 1 byte
    pub fn decodeTernaryToBinary(self: *const FileEncoder, trits: []const Trit) ![]u8 {
        if (trits.len % TRITS_PER_BYTE != 0) return error.InvalidTritCount;

        const byte_count = trits.len / TRITS_PER_BYTE;
        const data = try self.allocator.alloc(u8, byte_count);
        errdefer self.allocator.free(data);

        for (0..byte_count) |i| {
            const chunk = trits[i * TRITS_PER_BYTE ..][0..TRITS_PER_BYTE];
            data[i] = balancedTernaryToByte(chunk);
        }

        return data;
    }

    /// Hash file data using SHA-256
    pub fn hashFile(data: []const u8) [32]u8 {
        return crypto.sha256(data);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BYTE <-> BALANCED TERNARY CONVERSION
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert a byte (0-255) to 6 balanced ternary trits
/// Uses balanced ternary representation: digits are {-1, 0, +1}
pub fn byteToBalancedTernary(byte: u8) [TRITS_PER_BYTE]Trit {
    var result: [TRITS_PER_BYTE]Trit = undefined;
    var value: i16 = @intCast(byte);

    for (0..TRITS_PER_BYTE) |i| {
        const rem_val: i16 = @rem(value, 3);
        if (rem_val == 2) {
            result[i] = -1;
            value = @divTrunc(value + 1, 3);
        } else {
            result[i] = @intCast(rem_val);
            value = @divTrunc(value, 3);
        }
    }

    return result;
}

/// Convert 6 balanced ternary trits back to a byte
pub fn balancedTernaryToByte(trits: *const [TRITS_PER_BYTE]Trit) u8 {
    var value: i16 = 0;
    var power: i16 = 1;

    for (0..TRITS_PER_BYTE) |i| {
        value += @as(i16, trits[i]) * power;
        power *= 3;
    }

    if (value < 0) value += 729; // 3^6
    return @intCast(@as(u16, @intCast(value)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT PACKING (5 trits -> 1 byte, for compression pipeline)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRITS_PER_PACK: usize = 5; // 3^5 = 243 < 256

/// Pack 5 balanced trits into 1 byte (values 0-242)
pub fn packTrits5(trits: [5]Trit) u8 {
    const t0: u16 = @intCast(@as(i16, trits[0]) + 1);
    const t1: u16 = @intCast(@as(i16, trits[1]) + 1);
    const t2: u16 = @intCast(@as(i16, trits[2]) + 1);
    const t3: u16 = @intCast(@as(i16, trits[3]) + 1);
    const t4: u16 = @intCast(@as(i16, trits[4]) + 1);
    return @intCast(t0 + t1 * 3 + t2 * 9 + t3 * 27 + t4 * 81);
}

/// Unpack 1 byte back to 5 balanced trits
pub fn unpackTrits5(byte_val: u8) [5]Trit {
    var v: u16 = byte_val;
    const d0 = v % 3;
    v /= 3;
    const d1 = v % 3;
    v /= 3;
    const d2 = v % 3;
    v /= 3;
    const d3 = v % 3;
    v /= 3;
    const d4 = v % 3;
    return .{
        @as(i8, @intCast(d0)) - 1,
        @as(i8, @intCast(d1)) - 1,
        @as(i8, @intCast(d2)) - 1,
        @as(i8, @intCast(d3)) - 1,
        @as(i8, @intCast(d4)) - 1,
    };
}

/// Pack a slice of trits into packed bytes
pub fn packTrits(trits: []const Trit, output: []u8) usize {
    var pi: usize = 0;
    var ti: usize = 0;
    while (ti < trits.len) : (ti += 5) {
        var chunk = [5]Trit{ 0, 0, 0, 0, 0 };
        for (0..5) |k| {
            if (ti + k < trits.len) chunk[k] = trits[ti + k];
        }
        if (pi >= output.len) break;
        output[pi] = packTrits5(chunk);
        pi += 1;
    }
    return pi;
}

/// Unpack packed bytes back to trits
pub fn unpackTrits(pack_data: []const u8, output: []Trit, trit_count: usize) void {
    var ti: usize = 0;
    for (pack_data) |byte| {
        const result = unpackTrits5(byte);
        for (0..5) |k| {
            if (ti + k < trit_count and ti + k < output.len) {
                output[ti + k] = result[k];
            }
        }
        ti += 5;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "byte to balanced ternary roundtrip - all values 0-255" {
    for (0..256) |i| {
        const byte: u8 = @intCast(i);
        const trits = byteToBalancedTernary(byte);

        // Verify all trits are in {-1, 0, +1}
        for (trits) |t| {
            try std.testing.expect(t >= -1 and t <= 1);
        }

        // Verify roundtrip
        const recovered = balancedTernaryToByte(&trits);
        try std.testing.expectEqual(byte, recovered);
    }
}

test "file encoder roundtrip" {
    const allocator = std.testing.allocator;
    const encoder = FileEncoder.init(allocator);

    const test_data = "Hello, Trinity Storage Network!";
    const trits = try encoder.encodeBinaryToTernary(test_data);
    defer allocator.free(trits);

    try std.testing.expectEqual(test_data.len * TRITS_PER_BYTE, trits.len);

    const recovered = try encoder.decodeTernaryToBinary(trits);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, test_data, recovered);
}

test "file encoder roundtrip - binary data" {
    const allocator = std.testing.allocator;
    const encoder = FileEncoder.init(allocator);

    // Test with all byte values
    var test_data: [256]u8 = undefined;
    for (0..256) |i| test_data[i] = @intCast(i);

    const trits = try encoder.encodeBinaryToTernary(&test_data);
    defer allocator.free(trits);

    const recovered = try encoder.decodeTernaryToBinary(trits);
    defer allocator.free(recovered);

    try std.testing.expectEqualSlices(u8, &test_data, recovered);
}

test "file encoder roundtrip - empty data" {
    const allocator = std.testing.allocator;
    const encoder = FileEncoder.init(allocator);

    const trits = try encoder.encodeBinaryToTernary("");
    defer allocator.free(trits);

    try std.testing.expectEqual(@as(usize, 0), trits.len);

    const recovered = try encoder.decodeTernaryToBinary(trits);
    defer allocator.free(recovered);

    try std.testing.expectEqual(@as(usize, 0), recovered.len);
}

test "pack/unpack trits roundtrip" {
    const trits = [5]Trit{ 1, -1, 0, 1, -1 };
    const byte_val = packTrits5(trits);
    const recovered = unpackTrits5(byte_val);
    try std.testing.expectEqual(trits, recovered);
}

test "pack/unpack trits slice" {
    const input = [_]Trit{ 1, 0, -1, 1, 0, -1, 1, 0, -1, 0, 1, -1 };
    var pack_buf: [3]u8 = undefined;
    const pack_len = packTrits(&input, &pack_buf);
    try std.testing.expectEqual(@as(usize, 3), pack_len);

    var output: [12]Trit = undefined;
    unpackTrits(pack_buf[0..pack_len], &output, 12);

    // First 12 should match (last 3 are padded zeros in the last group)
    for (0..12) |i| {
        try std.testing.expectEqual(input[i], output[i]);
    }
}

test "file hash" {
    const hash1 = FileEncoder.hashFile("hello");
    const hash2 = FileEncoder.hashFile("hello");
    const hash3 = FileEncoder.hashFile("world");

    try std.testing.expectEqualSlices(u8, &hash1, &hash2);
    try std.testing.expect(!std.mem.eql(u8, &hash1, &hash3));
}
