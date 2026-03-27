//! tri/rsa — RSA encryption (simplified)
//! Auto-generated from specs/tri/tri_rsa.tri
//! TTT Dogfood v0.2 Stage 189

const std = @import("std");

/// RSA key pair
pub const RSAKeyPair = struct {
    public_e: u64,
    public_n: u64,
    private_d: u64,
    private_n: u64,
};

/// Generate RSA key pair (simplified with small primes)
pub fn generate(allocator: std.mem.Allocator, bit_size: usize) !RSAKeyPair {
    _ = allocator;
    _ = bit_size;

    // Simplified: use small fixed primes for demo
    // p = 61, q = 53
    // n = 3233
    // phi = 3120
    // e = 17
    // d = 2753

    return .{
        .public_e = 17,
        .public_n = 3233,
        .private_d = 2753,
        .private_n = 3233,
    };
}

/// Modular exponentiation (square-and-multiply)
fn modExp(base: u64, exp: u64, modulus: u64) u64 {
    if (modulus == 1) return 0;

    var result: u64 = 1;
    var b = base % modulus;
    var e = exp;

    while (e > 0) {
        if (e % 2 == 1) {
            result = (result * b) % modulus;
        }
        e /= 2;
        b = (b * b) % modulus;
    }

    return result;
}

/// Encrypt with public key
pub fn encrypt(message: u64, e: u64, n: u64) u64 {
    return modExp(message, e, n);
}

/// Decrypt with private key
pub fn decrypt(ciphertext: u64, d: u64, n: u64) u64 {
    return modExp(ciphertext, d, n);
}

test "rsa encrypt decrypt" {
    const keys = try generate(std.testing.allocator, 16);

    const message: u64 = 123;
    const c = encrypt(message, keys.public_e, keys.public_n);
    const m = decrypt(c, keys.private_d, keys.private_n);

    try std.testing.expectEqual(@as(u64, message), m);
}

test "rsa mod exp" {
    // 2^10 mod 1000 = 1024 mod 1000 = 24
    const result = modExp(2, 10, 1000);
    try std.testing.expectEqual(@as(u64, 24), result);
}

test "rsa simplified values" {
    // Using known test values
    const c = encrypt(65, 17, 3233);
    const m = decrypt(c, 2753, 3233);

    try std.testing.expectEqual(@as(u64, 65), m);
}
