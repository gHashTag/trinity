// Trinity Python Bindings — C ABI exports for ctypes
// Migrated from bindings/python/igla_lib.zig
// Exports: sacred constants, .tri parser, math functions, array operations

const std = @import("std");

// Sacred Constants (exported for Python ctypes)
pub export const IGLA_PHI: f64 = 1.618033988749895;
pub export const IGLA_TRINITY: i64 = 3;
pub export const IGLA_PHOENIX: i64 = 999;
pub export const IGLA_SPEED_OF_LIGHT: i64 = 299792458;

// Version info
pub fn iglaVersionMajor() i32 {
    return 3;
}

pub fn iglaVersionMinor() i32 {
    return 0;
}

pub fn iglaVersionPatch() i32 {
    return 0;
}

/// Result of parsing a .tri key-value file
pub const TriParseResult = extern struct {
    entries: i64,
    keys: i64,
    values: i64,
    bytes_parsed: i64,
    success: i32,
};

/// Parse .tri format key-value content
pub fn iglaTriParse(source: [*]const u8, length: usize) TriParseResult {
    const data = source[0..length];
    var entries: i64 = 0;
    var keys: i64 = 0;
    var values: i64 = 0;
    var pos: usize = 0;

    while (pos < data.len) {
        while (pos < data.len and (data[pos] == ' ' or data[pos] == '\t')) pos += 1;
        if (pos >= data.len) break;

        if (data[pos] == '#') {
            while (pos < data.len and data[pos] != '\n') pos += 1;
            if (pos < data.len) pos += 1;
            continue;
        }

        const key_start = pos;
        while (pos < data.len and data[pos] != ':' and data[pos] != '\n') pos += 1;
        if (pos > key_start) keys += 1;

        if (pos < data.len and data[pos] == ':') {
            pos += 1;
            while (pos < data.len and (data[pos] == ' ' or data[pos] == '\t')) pos += 1;
            const value_start = pos;
            while (pos < data.len and data[pos] != '\n') pos += 1;
            if (pos > value_start) values += 1;
            entries += 1;
        }

        while (pos < data.len and data[pos] != '\n') pos += 1;
        if (pos < data.len) pos += 1;
    }

    return .{
        .entries = entries,
        .keys = keys,
        .values = values,
        .bytes_parsed = @intCast(pos),
        .success = 1,
    };
}

// Math functions
pub fn iglaFibonacci(n: i64) i64 {
    if (n <= 1) return n;
    var a: i64 = 0;
    var b: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

pub fn iglaFactorial(n: i64) i64 {
    if (n <= 1) return 1;
    var result: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) result *= i;
    return result;
}

pub fn iglaIsPrime(n: i64) i32 {
    if (n <= 1) return 0;
    if (n <= 3) return 1;
    if (@mod(n, 2) == 0 or @mod(n, 3) == 0) return 0;
    var i: i64 = 5;
    while (i * i <= n) {
        if (@mod(n, i) == 0 or @mod(n, i + 2) == 0) return 0;
        i += 6;
    }
    return 1;
}

pub fn iglaGoldenIdentity() f64 {
    const phi_sq = IGLA_PHI * IGLA_PHI;
    return phi_sq + 1.0 / phi_sq;
}

// Array operations
pub fn iglaDotProduct(a: [*]const f64, b: [*]const f64, length: usize) f64 {
    var sum: f64 = 0.0;
    for (0..length) |i| sum += a[i] * b[i];
    return sum;
}

pub fn iglaArraySum(arr: [*]const i64, length: usize) i64 {
    var sum: i64 = 0;
    for (arr[0..length]) |val| sum += val;
    return sum;
}

test "fibonacci" {
    try std.testing.expectEqual(@as(i64, 55), iglaFibonacci(10));
    try std.testing.expectEqual(@as(i64, 6765), iglaFibonacci(20));
}

test "factorial" {
    try std.testing.expectEqual(@as(i64, 120), iglaFactorial(5));
}

test "golden_identity" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), iglaGoldenIdentity(), 0.0001);
}

test "is_prime" {
    try std.testing.expectEqual(@as(i32, 1), iglaIsPrime(7));
    try std.testing.expectEqual(@as(i32, 1), iglaIsPrime(37));
    try std.testing.expectEqual(@as(i32, 0), iglaIsPrime(4));
}

test "tri parser" {
    const input = "key1: value1\nkey2: value2\n# comment\nkey3: value3\n";
    const result = iglaTriParse(input.ptr, input.len);
    try std.testing.expectEqual(@as(i64, 3), result.entries);
    try std.testing.expectEqual(@as(i32, 1), result.success);
}
