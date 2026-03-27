//! tri/crypto — Cryptographic primitives
//! Auto-generated from specs/tri/tri_crypto.tri
//! TTT Dogfood v0.2 Stage 111

const std = @import("std");

/// Public/private key pair
pub const KeyPair = struct {
    public_key: []u8,
    private_key: []u8,

    /// Free resources
    pub fn deinit(self: KeyPair, allocator: std.mem.Allocator) void {
        allocator.free(self.public_key);
        allocator.free(self.private_key);
    }
};

/// Generate new key pair (Ed25519)
pub fn generateKeyPair(allocator: std.mem.Allocator) !KeyPair {
    // Generate key pair using Ed25519
    const key_pair = std.crypto.sign.Ed25519.KeyPair.generate();

    // Export public key
    const public_key = try allocator.dupe(u8, &key_pair.public_key.bytes);
    errdefer allocator.free(public_key);

    // Export secret key
    const secret_key_bytes = key_pair.secret_key.toBytes();
    const private_key = try allocator.dupe(u8, &secret_key_bytes);
    errdefer allocator.free(private_key);

    return .{
        .public_key = public_key,
        .private_key = private_key,
    };
}

/// SHA-256 hash
pub fn sha256(data: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return allocator.dupe(u8, &hash);
}

/// HMAC signature
pub fn hmac(key: []const u8, message: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Use HMAC with SHA-256
    var mac: [32]u8 = undefined;
    var h = std.crypto.auth.hmac.sha2.HmacSha256.init(key);
    h.update(message);
    h.final(&mac);
    return allocator.dupe(u8, &mac);
}

test "sha256" {
    const input = "hello";
    const result = try sha256(input, std.testing.allocator);
    defer std.testing.allocator.free(result);

    // Known SHA-256 of "hello"
    const expected = [_]u8{
        0x2c, 0xf2, 0x4d, 0xba, 0x5f, 0xb0, 0xa3, 0x0e,
        0x26, 0xe8, 0x3b, 0x2a, 0xc5, 0xb9, 0xe2, 0x9e,
        0x1b, 0x16, 0x1e, 0x5c, 0x1f, 0xa7, 0x42, 0x5e,
        0x73, 0x04, 0x33, 0x62, 0x93, 0x8b, 0x98, 0x24,
    };

    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "hmac" {
    const key = "key";
    const message = "message";
    const result = try hmac(key, message, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 32), result.len);
}

test "generate key pair" {
    const key_pair = try generateKeyPair(std.testing.allocator);
    defer key_pair.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 32), key_pair.public_key.len);
    try std.testing.expectEqual(@as(usize, 64), key_pair.private_key.len); // seed + public
}
