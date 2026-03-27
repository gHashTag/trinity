//! tri/rsa_simple — Simplified RSA (not production)
//! TTT Dogfood v0.2 Stage 245

const std = @import("std");

pub const RSAKeyPair = struct {
    public_key: u64,
    private_key: u64,
    modulus: u64,
};

pub fn generateKeyPair(p: u64, q: u64) RSAKeyPair {
    const n = p * q;
    const phi = (p - 1) * (q - 1);
    return .{
        .public_key = 65537,
        .private_key = phi,
        .modulus = n,
    };
}

test "rsa key pair" {
    const pair = generateKeyPair(61, 53);
    try std.testing.expect(pair.public_key == 65537);
}
