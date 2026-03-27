//! TRI Crypto — Generated from specs/tri/tri_crypto.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Fixed-size hash result (256 bits)
pub const HashResult = struct {
    data: [32]u8,

    pub fn init() HashResult {
        return .{ .data = [_]u8{0} ** 32 };
    }

    pub fn hex(self: *const HashResult, allocator: std.mem.Allocator) ![]u8 {
        const hex_chars = "0123456789abcdef";
        const result = try allocator.alloc(u8, 64);
        for (0..32) |i| {
            result[i * 2] = hex_chars[self.data[i] >> 4];
            result[i * 2 + 1] = hex_chars[self.data[i] & 0xF];
        }
        return result;
    }
};

/// Base64 encoding/decoding errors
pub const Base64Error = error{
    invalid_length,
    invalid_char,
    padding_error,
};

// ============================================================================
// HASH FUNCTIONS
// ============================================================================

/// Simple hash function (not cryptographically secure, for demonstration)
/// Uses FNV-1a 32-bit algorithm extended to 256 bits
pub fn simpleHash(data: []const u8) HashResult {
    var result = HashResult.init();

    // Create 8 different FNV-1a hashes
    for (0..8) |i| {
        var fnv1a_32: u32 = 2166136261 +% @as(u32, @intCast(i));

        for (data) |byte| {
            fnv1a_32 ^= byte;
            fnv1a_32 *%= 16777619;
        }

        result.data[i * 4] = @truncate(fnv1a_32 >> 24);
        result.data[i * 4 + 1] = @truncate(fnv1a_32 >> 16);
        result.data[i * 4 + 2] = @truncate(fnv1a_32 >> 8);
        result.data[i * 4 + 3] = @truncate(fnv1a_32);
    }

    return result;
}

/// Compute SHA-256 hash (placeholder - use simple hash for now)
pub fn sha256(data: []const u8) HashResult {
    return simpleHash(data);
}

// ============================================================================
// XOR OPERATIONS
// ============================================================================

/// XOR two byte arrays (same length)
pub fn xorBytes(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    if (a.len != b.len) return error.LengthMismatch;
    const result = try allocator.alloc(u8, a.len);
    for (a, b, 0..) |byte_a, byte_b, i| {
        result[i] = byte_a ^ byte_b;
    }
    return result;
}

/// XOR data with repeating key
pub fn xorRepeat(allocator: std.mem.Allocator, data: []const u8, key: []const u8) ![]u8 {
    if (key.len == 0) return error.EmptyKey;
    const result = try allocator.alloc(u8, data.len);
    for (data, 0..) |byte, i| {
        result[i] = byte ^ key[i % key.len];
    }
    return result;
}

// ============================================================================
// BASE64 ENCODING/DECODING
// ============================================================================

const base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// Encode bytes to base64
pub fn base64Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const out_len = (data.len + 2) / 3 * 4;
    const result = try allocator.alloc(u8, out_len);

    var out_idx: usize = 0;
    var i: usize = 0;

    while (i + 3 <= data.len) : (i += 3) {
        const triple = (@as(u32, data[i]) << 16) | (@as(u32, data[i + 1]) << 8) | data[i + 2];
        result[out_idx] = base64_alphabet[(triple >> 18) & 0x3F];
        result[out_idx + 1] = base64_alphabet[(triple >> 12) & 0x3F];
        result[out_idx + 2] = base64_alphabet[(triple >> 6) & 0x3F];
        result[out_idx + 3] = base64_alphabet[triple & 0x3F];
        out_idx += 4;
    }

    const remaining = data.len - i;
    if (remaining == 1) {
        const triple = @as(u32, data[i]) << 16;
        result[out_idx] = base64_alphabet[(triple >> 18) & 0x3F];
        result[out_idx + 1] = base64_alphabet[(triple >> 12) & 0x3F];
        result[out_idx + 2] = '=';
        result[out_idx + 3] = '=';
    } else if (remaining == 2) {
        const triple = (@as(u32, data[i]) << 16) | (@as(u32, data[i + 1]) << 8);
        result[out_idx] = base64_alphabet[(triple >> 18) & 0x3F];
        result[out_idx + 1] = base64_alphabet[(triple >> 12) & 0x3F];
        result[out_idx + 2] = base64_alphabet[(triple >> 6) & 0x3F];
        result[out_idx + 3] = '=';
    }

    return result;
}

/// Decode base64 character to value
fn base64DecodeChar(c: u8) !u6 {
    if (c >= 'A' and c <= 'Z') return @intCast(c - 'A');
    if (c >= 'a' and c <= 'z') return @intCast(c - 'a' + 26);
    if (c >= '0' and c <= '9') return @intCast(c - '0' + 52);
    if (c == '+') return 62;
    if (c == '/') return 63;
    if (c == '=') return 0; // Padding
    return Base64Error.invalid_char;
}

/// Decode base64 to bytes
pub fn base64Decode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (data.len % 4 != 0) return Base64Error.invalid_length;

    // Calculate output length
    var out_len: usize = data.len / 4 * 3;
    if (data.len > 0) {
        if (data[data.len - 1] == '=') out_len -= 1;
        if (data[data.len - 2] == '=') out_len -= 1;
    }

    const result = try allocator.alloc(u8, out_len);
    var out_idx: usize = 0;

    for (0..data.len / 4) |quad_idx| {
        const i = quad_idx * 4;
        const c0 = try base64DecodeChar(data[i]);
        const c1 = try base64DecodeChar(data[i + 1]);
        const c2 = try base64DecodeChar(data[i + 2]);
        const c3 = try base64DecodeChar(data[i + 3]);

        const triple = (@as(u32, c0) << 18) | (@as(u32, c1) << 12) | (@as(u32, c2) << 6) | c3;

        if (out_idx < result.len) result[out_idx] = @truncate(triple >> 16);
        out_idx += 1;
        if (out_idx < result.len) result[out_idx] = @truncate(triple >> 8);
        out_idx += 1;
        if (out_idx < result.len) result[out_idx] = @truncate(triple);
        out_idx += 1;
    }

    return result;
}

// ============================================================================
// TESTS
// ============================================================================

test "Crypto: xorBytes" {
    const allocator = std.testing.allocator;
    const a = "hello";
    const b = "world";

    const result = try xorBytes(allocator, a, b);
    defer allocator.free(result);

    // XOR with itself should give zeros
    const zeros = try xorBytes(allocator, result, result);
    defer allocator.free(zeros);

    for (zeros) |z| {
        try std.testing.expectEqual(@as(u8, 0), z);
    }
}

test "Crypto: xorRepeat" {
    const allocator = std.testing.allocator;
    const data = "hello world";
    const key = "key";

    const encrypted = try xorRepeat(allocator, data, key);
    defer allocator.free(encrypted);

    const decrypted = try xorRepeat(allocator, encrypted, key);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(data, decrypted);
}

test "Crypto: base64Encode empty" {
    const allocator = std.testing.allocator;
    const result = try base64Encode(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "Crypto: base64Encode basic" {
    const allocator = std.testing.allocator;
    const result = try base64Encode(allocator, "abc");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("YWJj", result);
}

test "Crypto: base64Encode with padding" {
    const allocator = std.testing.allocator;
    const result = try base64Encode(allocator, "abcd");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("YWJjZA==", result);
}

test "Crypto: base64Decode basic" {
    const allocator = std.testing.allocator;
    const result = try base64Decode(allocator, "YWJj");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc", result);
}

test "Crypto: base64EncodeDecode roundtrip" {
    const allocator = std.testing.allocator;
    const original = "The quick brown fox jumps over the lazy dog.";

    const encoded = try base64Encode(allocator, original);
    defer allocator.free(encoded);

    const decoded = try base64Decode(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}

test "Crypto: sha256 same input" {
    const h1 = sha256("test");
    const h2 = sha256("test");
    try std.testing.expectEqualSlices(u8, &h1.data, &h2.data);
}

test "Crypto: sha256 different input" {
    const h1 = sha256("test");
    const h2 = sha256("Test");
    try std.testing.expect(!std.mem.eql(u8, &h1.data, &h2.data));
}

test "Crypto: HashResult hex" {
    const allocator = std.testing.allocator;
    const hash = sha256("test");
    const hex = try hash.hex(allocator);
    defer allocator.free(hex);
    try std.testing.expectEqual(@as(usize, 64), hex.len);
    // All hex chars should be valid
    for (hex) |c| {
        const is_hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
        try std.testing.expect(is_hex);
    }
}
