//! tri/sha256 — SHA-256 cryptographic hash
//! Auto-generated from specs/tri/tri_sha256.tri
//! TTT Dogfood v0.2 Stage 155

const std = @import("std");

/// SHA-256 state
pub const SHA256 = struct {
    state: [8]u32,
    buffer: [64]u8,
    count: u64,

    /// Initialize SHA-256 state
    pub fn init() SHA256 {
        return .{
            .state = [_]u32{
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
            },
            .buffer = [_]u8{0} ** 64,
            .count = 0,
        };
    }

    /// Add data to hash
    pub fn update(sha: *SHA256, data: []const u8) void {
        for (data) |byte| {
            const idx = @as(usize, @intCast(sha.count & 63));
            sha.buffer[idx] = byte;
            sha.count += 1;

            if (idx == 63) {
                sha.processBlock();
            }
        }
    }

    /// Process one 64-byte block
    fn processBlock(sha: *SHA256) void {
        var w: [64]u32 = undefined;

        // Prepare message schedule
        for (0..16) |i| {
            w[i] = std.mem.readIntBig(u32, sha.buffer[i * 4 ..][0..4]);
        }

        for (16..64) |i| {
            const s0 = @rotatel(u32, w[i - 15], 7) ^ @rotatel(u32, w[i - 15], 18) ^ (w[i - 15] >> 3);
            const s1 = @rotatel(u32, w[i - 2], 17) ^ @rotatel(u32, w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] +% s0 +% w[i - 7] +% s1;
        }

        var h = sha.state;
        var a: u32 = h[0];
        var b: u32 = h[1];
        var c: u32 = h[2];
        var d: u32 = h[3];
        var e: u32 = h[4];
        var f: u32 = h[5];
        var g: u32 = h[6];
        var hh: u32 = h[7];

        const k = [_]u32{
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ae, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        };

        for (0..64) |i| {
            const s1 = @rotatel(u32, e, 6) ^ @rotatel(u32, e, 11) ^ @rotatel(u32, e, 25);
            const ch = (e & f) ^ (~e & g);
            const t1 = hh +% s1 +% ch +% k[i] +% w[i];
            const s0 = @rotatel(u32, a, 2) ^ @rotatel(u32, a, 13) ^ @rotatel(u32, a, 22);
            const maj = (a & b) ^ (a & c) ^ (b & c);
            const t2 = s0 +% maj;

            hh = g;
            g = f;
            f = e;
            e = d +% t1;
            d = c;
            c = b;
            b = a;
            a = t1 +% t2;
        }

        h[0] +%= a;
        h[1] +%= b;
        h[2] +%= c;
        h[3] +%= d;
        h[4] +%= e;
        h[5] +%= f;
        h[6] +%= g;
        h[7] +%= hh;

        sha.state = h;
    }

    /// Finalize and return hash
    pub fn final(sha: *SHA256) [32]u8 {
        // Append padding
        const idx = @as(usize, @intCast(sha.count & 63));
        sha.buffer[idx] = 0x80;

        if (idx >= 56) {
            for (idx + 1..64) |i| {
                sha.buffer[i] = 0;
            }
            sha.processBlock();
            @memset(sha.buffer[0..56], 0);
        } else {
            for (idx + 1..56) |i| {
                sha.buffer[i] = 0;
            }
        }

        // Append length in bits
        const bit_len = sha.count * 8;
        std.mem.writeIntBig(u64, sha.buffer[56..64], bit_len);

        sha.processBlock();

        // Output hash
        var result: [32]u8 = undefined;
        for (0..8) |i| {
            std.mem.writeIntBig(u32, result[i * 4 ..][0..4], sha.state[i]);
        }

        return result;
    }
};

/// One-shot SHA-256
pub fn hash(data: []const u8) [32]u8 {
    var sha = SHA256.init();
    sha.update(data);
    return sha.final();
}

test "sha256 empty" {
    const h = hash("");
    const expected = [_]u8{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    };

    try std.testing.expectEqualSlices(u8, &expected, &h);
}

test "sha256 abc" {
    const h = hash("abc");
    const expected = [_]u8{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    };

    try std.testing.expectEqualSlices(u8, &expected, &h);
}
