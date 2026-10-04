//! JWT Token Implementation (HMAC-SHA256)
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const crypto = std.crypto;
const hmac = crypto.auth.hmac.sha2;

/// JWT header (base64url encoded)
const JWT_HEADER = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9";

/// JWT payload structure
pub const Payload = struct {
    sub: []const u8, // Subject (user ID)
    iat: i64,        // Issued at (Unix timestamp)
    exp: i64,        // Expiration (Unix timestamp)
};

/// JWT error set
pub const Error = error{
    InvalidToken,
    MissingSecret,
    ExpiredToken,
    SignatureMismatch,
    EncodingFailed,
    DecodingFailed,
};

/// Base64URL encode (without padding)
fn base64UrlEncode(allocator: Allocator, input: []const u8) ![]u8 {
    var base64_encoder = std.base64.standard.Encoder;
    var encoded = try base64_encoder.encode(allocator, input);
    errdefer allocator.free(encoded);

    // Convert to URL-safe: + -> -, / -> _, remove padding =
    for (encoded) |*c| {
        switch (c.*) {
            '+' => c.* = '-',
            '/' => c.* = '_',
            '=' => c.* = 0, // Mark for removal
            else => {},
        }
    }

    // Remove trailing = (now 0s)
    var len = encoded.len;
    while (len > 0 and encoded[len - 1] == 0) : (len -= 1) {}

    if (len == encoded.len) {
        return encoded;
    }

    const result = try allocator.alloc(u8, len);
    @memcpy(result, encoded[0..len]);
    allocator.free(encoded);
    return result;
}

/// Base64URL decode (handles URL-safe encoding)
fn base64UrlDecode(allocator: Allocator, input: []const u8) ![]u8 {
    // Convert from URL-safe: - -> +, _ -> /
    const normalized = try allocator.alloc(u8, input.len + 3);
    defer allocator.free(normalized);

    for (input, 0..) |c, i| {
        normalized[i] = switch (c) {
            '-' => '+',
            '_' => '/',
            else => c,
        };
    }

    // Add padding if needed
    // One buffer, allocated with room for the padding from the start: the
    // previous shape freed `normalized` here and again through its defer, a
    // double free that corrupts the allocator on every padded segment — which
    // is most of them, since a 32-byte signature encodes to 43 characters.
    const padding = (4 - (input.len % 4)) % 4;
    const padded = normalized[0 .. input.len + padding];
    for (padded[input.len..]) |*c| c.* = '=';

    // Zig 0.15 base64 API: calculate size, allocate, decode
    const decoder = std.base64.standard.Decoder;
    const size = try decoder.calcSizeForSlice(padded);
    const result = try allocator.alloc(u8, size);
    try decoder.decode(result, padded);
    return result;
}

/// Generate JWT token
pub fn generateToken(allocator: Allocator, secret: []const u8, payload: Payload) ![]u8 {
    // Build JSON payload
    var payload_json = std.ArrayList(u8).init(allocator);
    defer payload_json.deinit();

    try payload_json.writer().print(
        \\{{"sub":"{s}","iat":{d},"exp":{d}}}
    , .{ payload.sub, payload.iat, payload.exp });

    // Encode payload
    const payload_encoded = try base64UrlEncode(allocator, payload_json.items);
    errdefer allocator.free(payload_encoded);

    // Build signature input: header.payload
    var signature_input = std.ArrayList(u8).init(allocator);
    defer signature_input.deinit();

    try signature_input.appendSlice(JWT_HEADER);
    try signature_input.append('.');
    try signature_input.appendSlice(payload_encoded);

    // Compute HMAC-SHA256 signature
    var mac: [hmac.sha256.mac_length]u8 = undefined;
    hmac.sha256.create(&mac, signature_input.items, secret);

    // Encode signature
    const signature_encoded = try base64UrlEncode(allocator, &mac);
    errdefer allocator.free(signature_encoded);

    // Build final token: header.payload.signature
    var token = std.ArrayList(u8).init(allocator);
    try token.appendSlice(JWT_HEADER);
    try token.append('.');
    try token.appendSlice(payload_encoded);
    try token.append('.');
    try token.appendSlice(signature_encoded);

    allocator.free(signature_encoded);
    allocator.free(payload_encoded);

    return token.toOwnedSlice();
}

/// Verify and decode JWT token
pub fn verifyToken(allocator: Allocator, token: []const u8, secret: []const u8) !Payload {
    // Split token into parts
    var parts = std.mem.splitScalar(u8, token, '.');
    const header_encoded = parts.first();
    const payload_encoded = if (parts.next()) |p| p else return error.InvalidToken;
    const signature_encoded = if (parts.next()) |s| s else return error.InvalidToken;

    if (parts.next() != null) return error.InvalidToken; // Too many parts

    // Rebuild signature input
    var signature_input = try std.ArrayList(u8).initCapacity(allocator, 256);
    defer signature_input.deinit(allocator);

    try signature_input.writer(allocator).print("{s}.{s}", .{ header_encoded, payload_encoded });

    // Decode provided signature
    const provided_sig = try base64UrlDecode(allocator, signature_encoded);
    defer allocator.free(provided_sig);

    // Compute expected signature (Zig 0.15 API)
    var expected_mac: [crypto.auth.hmac.sha2.HmacSha256.mac_length]u8 = undefined;
    crypto.auth.hmac.sha2.HmacSha256.create(&expected_mac, signature_input.items, secret);

    // An empty secret still produces a valid HMAC, so a server running without
    // one accepts any token a forger cares to sign with "". Fail closed: no
    // secret means no authentication, not open authentication.
    if (secret.len == 0) return error.MissingSecret;

    // Constant time: mem.eql returns on the first differing byte, which leaks
    // how much of a guessed signature was right.
    if (provided_sig.len != expected_mac.len) return error.SignatureMismatch;
    if (!crypto.timing_safe.eql([expected_mac.len]u8, provided_sig[0..expected_mac.len].*, expected_mac)) {
        return error.SignatureMismatch;
    }

    // Decode payload
    const payload_json = try base64UrlDecode(allocator, payload_encoded);
    defer allocator.free(payload_json);

    // Parse JSON payload
    const parsed = try std.json.parseFromSlice(struct {
        sub: []const u8,
        iat: i64,
        exp: i64,
    }, allocator, payload_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const now = std.time.timestamp();

    // Check expiration
    if (parsed.value.exp < now) {
        return error.ExpiredToken;
    }

    return Payload{
        .sub = try allocator.dupe(u8, parsed.value.sub),
        .iat = parsed.value.iat,
        .exp = parsed.value.exp,
    };
}

test "jwt: generate and verify" {
    const allocator = std.testing.allocator;
    const secret = "test-secret-key";

    const now = std.time.timestamp();
    const payload = Payload{
        .sub = "user_123",
        .iat = now,
        .exp = now + 3600, // 1 hour
    };

    const token = try generateToken(allocator, secret, payload);
    defer allocator.free(token);

    try std.testing.expect(token.len > 0);

    const verified = try verifyToken(allocator, token, secret);
    defer allocator.free(verified.sub);

    try std.testing.expectEqualStrings(payload.sub, verified.sub);
    try std.testing.expectEqual(payload.iat, verified.iat);
    try std.testing.expectEqual(payload.exp, verified.exp);
}

test "jwt: reject invalid signature" {
    const allocator = std.testing.allocator;
    const secret = "test-secret-key";
    const wrong_secret = "wrong-secret";

    const now = std.time.timestamp();
    const payload = Payload{
        .sub = "user_123",
        .iat = now,
        .exp = now + 3600,
    };

    const token = try generateToken(allocator, secret, payload);
    defer allocator.free(token);

    const result = verifyToken(allocator, token, wrong_secret);
    try std.testing.expectError(error.SignatureMismatch, result);
}

test "jwt: reject expired token" {
    const allocator = std.testing.allocator;
    const secret = "test-secret-key";

    const now = std.time.timestamp();
    const payload = Payload{
        .sub = "user_123",
        .iat = now - 7200,
        .exp = now - 3600, // Expired 1 hour ago
    };

    const token = try generateToken(allocator, secret, payload);
    defer allocator.free(token);

    const result = verifyToken(allocator, token, secret);
    try std.testing.expectError(error.ExpiredToken, result);
}
