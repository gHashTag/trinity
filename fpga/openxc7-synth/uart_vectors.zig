//! ═══════════════════════════════════════════════════════════════════════════════
//! UART VSA OPERATIONS — Vector operations for UART communication
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! VSA operations (bind, bundle, similarity) for 16-trit vectors.
//! Used in UART communication with FPGA VSA coprocessor.
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("uart_protocol.zig");

pub const Vector16 = [protocol.VECTOR_SIZE]protocol.Trit;

/// ═══════════════════════════════════════════════════════════════════════════════
/// VECTOR GENERATION
/// ═══════════════════════════════════════════════════════════════════════════════
var prng = std.Random.DefaultPrng.init(12345);

/// Generate random vector
pub fn randomVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        const r = prng.random().intRangeAtMost(u2, 0, 2);
        vec[i] = @enumFromInt(r);
    }
    return vec;
}

/// Generate vector of all positive trits
pub fn allOnesVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        vec[i] = .POSITIVE;
    }
    return vec;
}

/// Generate vector of all zero trits
pub fn allZerosVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        vec[i] = .ZERO;
    }
    return vec;
}

/// Generate alternating positive/negative vector
pub fn alternatingVector() Vector16 {
    var vec: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        vec[i] = if (i % 2 == 0) .POSITIVE else .NEGATIVE;
    }
    return vec;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// VECTOR ENCODING/DECODING
/// ═══════════════════════════════════════════════════════════════════════════════
/// Encode vector to bytes (2 bits per trit)
pub fn encodeVector(vec: Vector16) [protocol.VECTOR_BYTES]u8 {
    var bytes: [protocol.VECTOR_BYTES]u8 = undefined;
    @memset(&bytes, 0);
    for (0..protocol.VECTOR_SIZE) |i| {
        const trit_bits = @intFromEnum(vec[i]);
        const byte_idx: usize = i / 4;
        const bit_idx: u3 = @intCast((i % 4) * 2);
        bytes[byte_idx] |= @as(u8, trit_bits) << bit_idx;
    }
    return bytes;
}

/// Decode bytes to vector
pub fn decodeVector(bytes: [protocol.VECTOR_BYTES]u8) Vector16 {
    var vec: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        const byte_idx: usize = i / 4;
        const bit_idx: u3 = @intCast((i % 4) * 2);
        const trit_bits = (bytes[byte_idx] >> bit_idx) & 0x3;
        vec[i] = @enumFromInt(trit_bits);
    }
    return vec;
}

/// Print vector for debugging
pub fn printVector(vec: Vector16) void {
    std.debug.print("[", .{});
    for (vec, 0..) |t, i| {
        const label = switch (t) {
            .POSITIVE => "+",
            .NEGATIVE => "-",
            .ZERO => "0",
        };
        std.debug.print("{s}", .{label});
        if (i < protocol.VECTOR_SIZE - 1) std.debug.print("", .{});
    }
    std.debug.print("]", .{});
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// VSA OPERATIONS (Software Implementation)
/// ═══════════════════════════════════════════════════════════════════════════════
/// Cosine similarity (scaled 0-255)
pub fn similarityVectors(a: Vector16, b: Vector16) u8 {
    var dot_product: i16 = 0;
    var norm_a: i16 = 0;
    var norm_b: i16 = 0;

    for (0..protocol.VECTOR_SIZE) |i| {
        const a_val = protocol.tritValue(a[i]);
        const b_val = protocol.tritValue(b[i]);

        dot_product += a_val * b_val;
        norm_a += a_val * a_val;
        norm_b += b_val * b_val;
    }

    if (norm_a == 0 or norm_b == 0)
        return 0;

    const abs_dot = if (dot_product < 0) -dot_product else dot_product;
    const norm_sum = norm_a + norm_b;
    const score = @divTrunc(abs_dot * 255, @max(norm_sum, 1));
    return @intCast(score);
}

/// Bind two vectors (element-wise ternary multiply)
pub fn bindVectors(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        const ta = a[i];
        const tb = b[i];

        result[i] = if (ta == .ZERO or tb == .ZERO)
            .ZERO
        else if (ta == tb)
            .POSITIVE
        else
            .NEGATIVE;
    }
    return result;
}

/// Bundle two vectors (majority vote)
pub fn bundleVectors(a: Vector16, b: Vector16) Vector16 {
    var result: Vector16 = undefined;
    for (0..protocol.VECTOR_SIZE) |i| {
        const ta = a[i];
        const tb = b[i];

        result[i] = if (ta == .NEGATIVE and tb == .NEGATIVE)
            .NEGATIVE
        else if (ta == .POSITIVE and tb == .POSITIVE)
            .POSITIVE
        else if (ta == .ZERO)
            tb
        else if (tb == .ZERO)
            ta
        else
            .ZERO;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════
test "Vector: encode/decode roundtrip" {
    const testing = std.testing;

    const original = randomVector();
    const encoded = encodeVector(original);
    const decoded = decodeVector(encoded);

    try testing.expectEqual(original, decoded);
}

test "Vector: bind identity" {
    const testing = std.testing;

    const vec = randomVector();
    const ones = allOnesVector();
    const result = bindVectors(vec, ones);

    // Bind with all-ones should preserve the vector
    try testing.expectEqual(vec, result);
}

test "Vector: similarity bounds" {
    const testing = std.testing;

    const ones = allOnesVector();
    const zeros = allZerosVector();
    const score = similarityVectors(ones, zeros);

    // Similarity with zero vector should be 0
    try testing.expectEqual(@as(u8, 0), score);
}

test "Vector: bundle with zero" {
    const testing = std.testing;

    const vec = randomVector();
    const zeros = allZerosVector();
    const result = bundleVectors(vec, zeros);

    // Bundle with zero should preserve the vector
    try testing.expectEqual(vec, result);
}
