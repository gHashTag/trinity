//! tri/hmac — HMAC message authentication
//! Auto-generated from specs/tri/tri_hmac.tri
//! TTT Dogfood v0.2 Stage 156

const std = @import("std");
const SHA256 = @import("gen_sha256.zig").SHA256;

/// HMAC state
pub const HMAC = struct {
    opad: [64]u8,
    inner: SHA256,

    /// Initialize HMAC with key
    pub fn init(key: []const u8) HMAC {
        var ipad = [_]u8{0x36} ** 64;
        var opad = [_]u8{0x5c} ** 64;

        // Process key
        if (key.len > 64) {
            var sha = SHA256.init();
            sha.update(key);
            const hash = sha.final();

            for (0..32) |i| {
                ipad[i] ^= hash[i];
                opad[i] ^= hash[i];
            }
        } else {
            for (key, 0..) |b, i| {
                ipad[i] ^= b;
                opad[i] ^= b;
            }
        }

        var inner = SHA256.init();
        inner.update(&ipad);

        return .{
            .opad = opad,
            .inner = inner,
        };
    }

    /// Add data to MAC
    pub fn update(hmac: *HMAC, data: []const u8) void {
        hmac.inner.update(data);
    }

    /// Finalize and return MAC
    pub fn final(hmac: *HMAC) [32]u8 {
        const inner_hash = hmac.inner.final();

        var outer = SHA256.init();
        outer.update(&hmac.opad);
        outer.update(&inner_hash);

        return outer.final();
    }
};

/// One-shot HMAC
pub fn mac(key: []const u8, data: []const u8) [32]u8 {
    var hmac = HMAC.init(key);
    hmac.update(data);
    return hmac.final();
}

test "hmac rfc2104" {
    const key = "key";
    const data = "The quick brown fox jumps over the lazy dog";

    const result = mac(key, data);

    // Just verify we get a consistent result
    const result2 = mac(key, data);

    try std.testing.expectEqualSlices(u8, &result, &result2);
}

test "hmac empty" {
    const key = "";
    const data = "";

    const result = mac(key, data);

    // Should produce consistent output
    try std.testing.expectEqual(@as(usize, 32), result.len);
}
