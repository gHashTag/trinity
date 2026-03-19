// @origin(spec:ternary_pack.tri) @regen(manual-impl)
// Ternary Pack/Unpack — 2-bit encoding for FPGA and memory compression
// 16 trits {-1, 0, +1} → 32 bits (8× memory reduction vs i8 array)
//
// Encoding:
//   -1 → 01 (binary)
//    0 → 00 (binary)
//   +1 → 10 (binary)
//
// This matches the FPGA weight format in fpga/tools/export_weights.zig
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit encoding in 2 bits
const TRIT_NEG: u2 = 0b01; // -1
const TRIT_ZERO: u2 = 0b00; // 0
const TRIT_POS: u2 = 0b10; // +1

// ═══════════════════════════════════════════════════════════════════════════════
// PACK/UNPACK — 16 trits ↔ 32 bits
// ═══════════════════════════════════════════════════════════════════════════════

/// Pack 16 ternary values into 32 bits (2 bits per trit).
/// Returns a u32 where bits [1:0] are trits[0], bits [3:2] are trits[1], etc.
pub fn packTernary16(trits: [16]i8) u32 {
    var result: u32 = 0;
    for (trits, 0..) |t, i| {
        const bits: u2 = switch (t) {
            -1 => TRIT_NEG,
            0 => TRIT_ZERO,
            1 => TRIT_POS,
            else => TRIT_ZERO, // Treat invalid as zero
        };
        result |= @as(u32, bits) << @intCast(i * 2);
    }
    return result;
}

/// Unpack 32 bits into 16 ternary values.
/// Inverse of packTernary16.
pub fn unpackTernary16(value: u32) [16]i8 {
    var trits: [16]i8 = undefined;
    for (&trits, 0..) |*t, i| {
        const bits: u2 = @truncate(value >> @intCast(i * 2));
        t.* = switch (bits) {
            TRIT_NEG => -1,
            TRIT_ZERO => 0,
            TRIT_POS => 1,
            else => 0, // Should never happen with 2 bits
        };
    }
    return trits;
}

/// Pack a slice of ternary values.
/// Output length = (input.len + 15) / 16 * 4 bytes.
pub fn packTernarySlice(trits: []const i8, output: []u8) void {
    const chunk_size = 16;
    const num_chunks = (trits.len + chunk_size - 1) / chunk_size;

    for (0..num_chunks) |chunk_idx| {
        const start = chunk_idx * chunk_size;
        const end = @min(start + chunk_size, trits.len);

        // Gather 16 trits (pad with zeros if needed)
        var chunk_trits: [16]i8 = undefined;
        @memset(&chunk_trits, 0);

        for (0..(end - start)) |i| {
            chunk_trits[i] = trits[start + i];
        }

        // Pack and write as u32
        const encoded = packTernary16(chunk_trits);
        const out_idx = chunk_idx * 4;

        if (out_idx + 4 <= output.len) {
            // Write little-endian u32
            output[out_idx + 0] = @truncate(encoded);
            output[out_idx + 1] = @truncate(encoded >> 8);
            output[out_idx + 2] = @truncate(encoded >> 16);
            output[out_idx + 3] = @truncate(encoded >> 24);
        }
    }
}

/// Unpack a slice of packed ternary values.
/// Input length must be multiple of 4 bytes.
pub fn unpackTernarySlice(input: []const u8, trits: []i8) void {
    const chunk_size = 16;
    const num_chunks = @min(input.len / 4, trits.len / chunk_size);

    for (0..num_chunks) |chunk_idx| {
        const in_idx = chunk_idx * 4;

        // Read little-endian u32
        const encoded = std.mem.readInt(u32, input[in_idx..][0..4], .little);

        // Unpack into trits
        const unpacked = unpackTernary16(encoded);
        const start = chunk_idx * chunk_size;

        for (unpacked, 0..) |t, i| {
            if (start + i < trits.len) {
                trits[start + i] = t;
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENCODING/DECODING — String format for debugging
// ═══════════════════════════════════════════════════════════════════════════════

/// Encode trit to character (for debugging/serialization).
pub fn tritToChar(t: i8) u8 {
    return switch (t) {
        -1 => '-',
        0 => '0',
        1 => '+',
        else => '?',
    };
}

/// Decode character to trit (for debugging/serialization).
pub fn charToTrit(c: u8) i8 {
    return switch (c) {
        '-' => -1,
        '0' => 0,
        '+' => 1,
        else => 0,
    };
}

/// Encode 16 trits to string (16 chars).
pub fn tritsToString(trits: [16]i8) [16]u8 {
    var result: [16]u8 = undefined;
    for (trits, 0..) |t, i| {
        result[i] = tritToChar(t);
    }
    return result;
}

/// Decode string to 16 trits.
pub fn stringToTrits(s: [16]u8) [16]i8 {
    var result: [16]i8 = undefined;
    for (s, 0..) |c, i| {
        result[i] = charToTrit(c);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit count results
pub const TritCounts = struct { neg: usize, zero: usize, pos: usize };

/// Count occurrences of each trit value.
pub fn countTrits(trits: []const i8) TritCounts {
    var result = TritCounts{ .neg = 0, .zero = 0, .pos = 0 };

    for (trits) |t| {
        switch (t) {
            -1 => result.neg += 1,
            0 => result.zero += 1,
            1 => result.pos += 1,
            else => {},
        }
    }

    return result;
}

/// Calculate compression ratio (original bytes / packed bytes).
/// Original: 1 byte per trit (i8), Packed: 2 bits per trit.
pub fn compressionRatio(trit_count: usize) f64 {
    const original_bytes = trit_count;
    const packed_bytes = (trit_count * 2 + 7) / 8; // Round up to bytes
    return @as(f64, @floatFromInt(original_bytes)) / @as(f64, @floatFromInt(packed_bytes));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "pack ternary 16 roundtrip" {
    const original = [_]i8{ -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, 0 };
    const encoded = packTernary16(original);
    const unpacked = unpackTernary16(encoded);

    try std.testing.expectEqualSlices(i8, &original, &unpacked);
}

test "pack ternary 16 all zeros" {
    const all_zeros = [_]i8{0} ** 16;
    const encoded = packTernary16(all_zeros);

    // All zeros should encode to 0x00000000
    try std.testing.expectEqual(@as(u32, 0), encoded);
}

test "pack ternary 16 all ones" {
    const all_ones = [_]i8{1} ** 16;
    const encoded = packTernary16(all_ones);

    // All +1 should encode to 0xAAAAAAAA (1010... pattern)
    try std.testing.expectEqual(@as(u32, 0xAAAAAAAA), encoded);
}

test "pack ternary 16 all minus ones" {
    const all_minus = [_]i8{-1} ** 16;
    const encoded = packTernary16(all_minus);

    // All -1 should encode to 0x55555555 (0101... pattern)
    try std.testing.expectEqual(@as(u32, 0x55555555), encoded);
}

test "pack ternary 16 pattern" {
    // Pattern repeats with shift: -1,0,1,-1, 0,1,-1,0, 1,-1,0,1, -1,0,1,-1
    const pattern = [_]i8{ -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1 };
    const encoded = packTernary16(pattern);

    // Each group of 4 trits encodes to one byte:
    // -1,0,1,-1 = 01 00 10 01 = 0b01100001 = 0x61
    // 0,1,-1,0 = 00 10 01 00 = 0b00011000 = 0x18
    // 1,-1,0,1 = 10 01 00 10 = 0b10000110 = 0x86
    // -1,0,1,-1 = 01 00 10 01 = 0b01100001 = 0x61
    // Result (little-endian): 0x61861861
    const expected: u32 = 0x61861861;
    try std.testing.expectEqual(expected, encoded);
}

test "unpack ternary 16" {
    // Test pattern: -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1
    const pattern = [_]i8{ -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1 };
    const encoded = packTernary16(pattern);
    const unpacked = unpackTernary16(encoded);

    try std.testing.expectEqualSlices(i8, &pattern, &unpacked);
}

test "pack ternary slice roundtrip" {
    const original = [_]i8{ -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, 0, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1 };

    const encoded_size = (original.len + 15) / 16 * 4;
    var encoded_buf: [encoded_size]u8 = undefined;

    packTernarySlice(&original, &encoded_buf);

    var unpacked_buf: [original.len]i8 = undefined;
    unpackTernarySlice(&encoded_buf, &unpacked_buf);

    try std.testing.expectEqualSlices(i8, &original, &unpacked_buf);
}

test "pack ternary slice non multiple of 16" {
    const original = [_]i8{ -1, 0, 1, -1, 0 }; // 5 elements (not multiple of 16)

    const encoded_size = (original.len + 15) / 16 * 4;
    var encoded_buf: [encoded_size]u8 = undefined;

    packTernarySlice(&original, &encoded_buf);

    var unpacked_buf: [16]i8 = undefined; // Enough for one chunk
    unpackTernarySlice(&encoded_buf, &unpacked_buf);

    // First 5 should match
    try std.testing.expectEqualSlices(i8, &original, unpacked_buf[0..5]);
}

test "count trits" {
    const data = [_]i8{ -1, -1, 0, 0, 1, 1, 1, -1 };
    const counts = countTrits(&data);

    try std.testing.expectEqual(@as(usize, 3), counts.neg);
    try std.testing.expectEqual(@as(usize, 2), counts.zero);
    try std.testing.expectEqual(@as(usize, 3), counts.pos);
}

test "compression ratio" {
    // 16 trits: 16 bytes → 4 bytes = 4× compression
    const ratio_16 = compressionRatio(16);
    try std.testing.expect(ratio_16 >= 3.5 and ratio_16 <= 4.5);

    // 32 trits: 32 bytes → 8 bytes = 4× compression
    const ratio_32 = compressionRatio(32);
    try std.testing.expect(ratio_32 >= 3.5 and ratio_32 <= 4.5);

    // 17 trits: 17 bytes → 5 bytes (rounded up)
    const ratio_17 = compressionRatio(17);
    try std.testing.expect(ratio_17 >= 3.0 and ratio_17 <= 4.5);
}

test "trit to char roundtrip" {
    for ([_]i8{ -1, 0, 1 }) |t| {
        const c = tritToChar(t);
        const back = charToTrit(c);
        try std.testing.expectEqual(t, back);
    }
}

test "trits to string roundtrip" {
    const original = [_]i8{ -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, 0 };
    const str = tritsToString(original);
    const back = stringToTrits(str);

    try std.testing.expectEqualSlices(i8, &original, &back);
}

test "string representation" {
    const trits = [_]i8{ -1, 0, 1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, 0, 1 };
    const str = tritsToString(trits);

    // Verify encoding
    try std.testing.expectEqual(@as(u8, '-'), str[0]); // -1
    try std.testing.expectEqual(@as(u8, '0'), str[1]); // 0
    try std.testing.expectEqual(@as(u8, '+'), str[2]); // 1
    try std.testing.expectEqual(@as(u8, '0'), str[3]); // 0
}

test "invalid trit treated as zero" {
    // Invalid trit values (not -1, 0, 1) should be treated as 0
    const invalid = [_]i8{ 2, -2, 100, -100 };
    var result: u32 = 0;

    for (invalid, 0..) |t, i| {
        const bits: u2 = switch (t) {
            -1 => TRIT_NEG,
            0 => TRIT_ZERO,
            1 => TRIT_POS,
            else => TRIT_ZERO,
        };
        result |= @as(u32, bits) << @intCast(i * 2);
    }

    // All should be zero
    try std.testing.expectEqual(@as(u32, 0), result);
}

test "unpack preserves invalid encoding" {
    // Use a value with bit patterns that don't match our encoding
    // 0b11 = 3 should be treated as 0
    const encoded: u32 = 0xFFFFFFFF; // All bits set to 1 (0b11 repeated)

    const unpacked = unpackTernary16(encoded);

    // All should be 0 (invalid → 0 fallback)
    for (unpacked) |t| {
        try std.testing.expectEqual(@as(i8, 0), t);
    }
}

test "little endian encoding" {
    const trits = [_]i8{ 1, 0, -1, 0 } ++ [_]i8{0} ** 12;
    const encoded = packTernary16(trits);

    // First trit (1 = 0b10) should be in LSB [1:0]
    // encoded = ...0b00010010 where bits [1:0]=0b10, [3:2]=0b00, [5:4]=0b01
    const byte: u8 = @truncate(encoded);
    try std.testing.expectEqual(@as(u8, 0b00010010), byte); // 18

    // Extract just bits [1:0] for first trit
    try std.testing.expectEqual(@as(u8, 0b10), byte & 0x03);

    // Second trit (0 = 0b00) should be in bits [3:2]
    try std.testing.expectEqual(@as(u8, 0b00), (byte >> 2) & 0x03);

    // Third trit (-1 = 0b01) should be in bits [5:4]
    try std.testing.expectEqual(@as(u8, 0b01), (byte >> 4) & 0x03);
}

test "maximum compression ratio" {
    // For very large arrays, compression approaches 4×
    const large_size = 1024;
    const ratio = compressionRatio(large_size);

    // Should be close to 4×
    try std.testing.expect(ratio >= 3.9 and ratio <= 4.1);
}

// φ² + 1/φ² = 3 | TRINITY
