//! GoldenFloat C-ABI v1.1.0 — Zig Implementation
//!
//! This file provides extern "C" functions that implement the GF16 API
//! defined in src/c/gf16.h. The shared library (libgoldenfloat) is
//! compiled from this Zig source.
//!
//! **Architecture:**
//! - Header (src/c/gf16.h) = specification
//! - This file (src/c_abi.zig) = Zig implementation
//! - build.zig = compiles to libgoldenfloat.{so,dylib,dll}
//!
//! **Usage from other languages:**
//! ```rust
//! // Rust
//! extern "C" {
//!     fn gf16_from_f32(x: f32) -> u16;
//!     fn gf16_to_f32(g: u16) -> f32;
//! }
//! ```
//!
//! ```python
//! # Python
//! import ctypes
//! lib = ctypes.CDLL("libgoldenfloat.so")
//! lib.gf16_from_f32.restype = ctypes.c_uint16
//! lib.gf16_from_f32.argtypes = [ctypes.c_float]
//! ```

const std = @import("std");
const golden = @import("formats/golden_float16.zig");

// ═══════════════════════════════════════════════════════════════════
// Type Aliases
// ═════════════════════════════════════════════════════════════════

/// gf16_t is a raw u16 bit pattern
const gf16_t = u16;

/// Convert GF16 struct to raw u16
inline fn gf16ToRaw(gf: golden.GF16) gf16_t {
    return @as(u16, @bitCast(gf));
}

/// Convert raw u16 to GF16 struct
inline fn rawToGf16(raw: gf16_t) golden.GF16 {
    return @as(golden.GF16, @bitCast(raw));
}

// ═════════════════════════════════════════════════════════════════════
// Conversion Functions
// ═════════════════════════════════════════════════════════════════

export fn gf16_from_f32(x: f32) callconv(.c) gf16_t {
    return gf16ToRaw(golden.GF16.fromF32(x));
}

export fn gf16_to_f32(g: gf16_t) callconv(.c) f32 {
    return rawToGf16(g).toF32();
}

// ═══════════════════════════════════════════════════════════════════
// Arithmetic Functions
// ═════════════════════════════════════════════════════════════════════

export fn gf16_add(a: gf16_t, b: gf16_t) callconv(.c) gf16_t {
    const gf_a = rawToGf16(a);
    const gf_b = rawToGf16(b);
    return gf16ToRaw(golden.GF16.add(gf_a, gf_b));
}

export fn gf16_sub(a: gf16_t, b: gf16_t) callconv(.c) gf16_t {
    const gf_a = rawToGf16(a);
    const gf_b = rawToGf16(b);
    return gf16ToRaw(golden.GF16.sub(gf_a, gf_b));
}

export fn gf16_mul(a: gf16_t, b: gf16_t) callconv(.c) gf16_t {
    const gf_a = rawToGf16(a);
    const gf_b = rawToGf16(b);
    return gf16ToRaw(golden.GF16.mul(gf_a, gf_b));
}

export fn gf16_div(a: gf16_t, b: gf16_t) callconv(.c) gf16_t {
    const gf_a = rawToGf16(a);
    const gf_b = rawToGf16(b);
    return gf16ToRaw(golden.GF16.div(gf_a, gf_b));
}

// ═════════════════════════════════════════════════════════════════════
// Unary Functions
// ═════════════════════════════════════════════════════════════════

export fn gf16_neg(g: gf16_t) callconv(.c) gf16_t {
    return gf16ToRaw(rawToGf16(g).neg());
}

export fn gf16_abs(g: gf16_t) callconv(.c) gf16_t {
    return gf16ToRaw(rawToGf16(g).abs());
}

// ═════════════════════════════════════════════════════════════════════
// Comparison Functions
// ═════════════════════════════════════════════════════════════════════

export fn gf16_eq(a: gf16_t, b: gf16_t) callconv(.c) bool {
    const gf_a = rawToGf16(a);
    const gf_b = rawToGf16(b);
    const fa = gf_a.toF32();
    const fb = gf_b.toF32();
    // Handle NaN: NaN != NaN (IEEE 754 semantics)
    if (std.math.isNan(fa) or std.math.isNan(fb)) return false;
    return fa == fb;
}

export fn gf16_lt(a: gf16_t, b: gf16_t) callconv(.c) bool {
    const gf_a = rawToGf16(a);
    const gf_b = rawToGf16(b);
    const fa = gf_a.toF32();
    const fb = gf_b.toF32();
    // Handle NaN: comparisons with NaN are false
    if (std.math.isNan(fa) or std.math.isNan(fb)) return false;
    return fa < fb;
}

export fn gf16_le(a: gf16_t, b: gf16_t) callconv(.c) bool {
    return gf16_lt(a, b) or gf16_eq(a, b);
}

export fn gf16_cmp(a: gf16_t, b: gf16_t) callconv(.c) c_int {
    if (gf16_lt(a, b)) return -1;
    if (gf16_eq(a, b)) return 0;
    return 1;
}

// ═══════════════════════════════════════════════════════════════════════
// Predicate Functions
// ═══════════════════════════════════════════════════════════════════

export fn gf16_is_nan(g: gf16_t) callconv(.c) bool {
    const gf = rawToGf16(g);
    // NaN: exp = 0x3F and mant != 0
    return gf.exp == 0x3F and gf.mant != 0;
}

export fn gf16_is_inf(g: gf16_t) callconv(.c) bool {
    const gf = rawToGf16(g);
    // Infinity: exp = 0x3F and mant = 0
    return gf.exp == 0x3F and gf.mant == 0;
}

export fn gf16_is_zero(g: gf16_t) callconv(.c) bool {
    const gf = rawToGf16(g);
    // Zero: exp = 0 and mant = 0
    return gf.exp == 0 and gf.mant == 0;
}

export fn gf16_is_subnormal(g: gf16_t) callconv(.c) bool {
    const gf = rawToGf16(g);
    // GF16 has no true subnormals (exp = 0 means zero)
    return gf.exp == 0 and gf.mant != 0;
}

export fn gf16_is_negative(g: gf16_t) callconv(.c) bool {
    const gf = rawToGf16(g);
    return gf.sign == 1;
}

// ═════════════════════════════════════════════════════════════════════
// φ-Math Functions
// ═══════════════════════════════════════════════════════════════════════

export fn gf16_phi_quantize(x: f32) callconv(.c) gf16_t {
    return gf16ToRaw(golden.GF16.phiQuantize(x));
}

export fn gf16_phi_dequantize(g: gf16_t) callconv(.c) f32 {
    const gf = rawToGf16(g);
    return golden.GF16.phiDequantize(gf);
}

// ═══════════════════════════════════════════════════════════════════════
// Utility Functions
// ═════════════════════════════════════════════════════════════════════════════

export fn gf16_copysign(target: gf16_t, source: gf16_t) callconv(.c) gf16_t {
    const gf_target = rawToGf16(target);
    const gf_source = rawToGf16(source);
    return gf16ToRaw(.{
        .mant = gf_target.mant,
        .exp = gf_target.exp,
        .sign = gf_source.sign,
    });
}

export fn gf16_min(a: gf16_t, b: gf16_t) callconv(.c) gf16_t {
    return if (gf16_lt(a, b)) a else b;
}

export fn gf16_max(a: gf16_t, b: gf16_t) callconv(.c) gf16_t {
    return if (gf16_lt(a, b)) b else a;
}

export fn gf16_fma(a: gf16_t, b: gf16_t, c: gf16_t) callconv(.c) gf16_t {
    // Compute a * b + c in f32, then round to GF16
    const fa = rawToGf16(a).toF32();
    const fb = rawToGf16(b).toF32();
    const fc = rawToGf16(c).toF32();
    return gf16ToRaw(golden.GF16.fromF32(fa * fb + fc));
}

// ═══════════════════════════════════════════════════════════════════
// Library Info
// ═════════════════════════════════════════════════════════════════════

export fn goldenfloat_version() callconv(.c) [*:0]const u8 {
    return "1.1.0";
}

export fn goldenfloat_phi() callconv(.c) f64 {
    return golden.PHI;
}

export fn goldenfloat_trinity() callconv(.c) f64 {
    return golden.TRINITY;
}

// ═════════════════════════════════════════════════════════════════════
// Compile-Time Guards
// ═══════════════════════════════════════════════════════════════════════════════

comptime {
    std.debug.assert(@sizeOf(gf16_t) == 2);
    std.debug.assert(@sizeOf(golden.GF16) == 2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═════════════════════════════════════════════════════════════════════════════

test "C-ABI: gf16_from_f32 and gf16_to_f32" {
    const val: f32 = 3.14;
    const gf = gf16_from_f32(val);
    const back = gf16_to_f32(gf);
    const err = @abs(val - back) / (@abs(val) + 0.001);
    try std.testing.expect(err < 0.05);
}

test "C-ABI: gf16_add" {
    const a = gf16_from_f32(1.5);
    const b = gf16_from_f32(2.5);
    const sum = gf16_add(a, b);
    const result = gf16_to_f32(sum);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result, 0.05);
}

test "C-ABI: gf16_mul" {
    const a = gf16_from_f32(2.0);
    const b = gf16_from_f32(3.0);
    const prod = gf16_mul(a, b);
    const result = gf16_to_f32(prod);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), result, 0.05);
}

test "C-ABI: gf16_neg and gf16_abs" {
    const val = gf16_from_f32(-3.14);
    const neg = gf16_neg(val);
    const abs = gf16_abs(val);
    try std.testing.expect(gf16_to_f32(neg) > 0);
    try std.testing.expect(gf16_to_f32(abs) > 0);
}

test "C-ABI: gf16_eq and gf16_lt" {
    const a = gf16_from_f32(1.0);
    const b = gf16_from_f32(1.0);
    const c = gf16_from_f32(2.0);
    try std.testing.expect(gf16_eq(a, b));
    try std.testing.expect(gf16_lt(a, c));
    try std.testing.expect(!gf16_lt(c, a));
}

test "C-ABI: gf16_is_nan and gf16_is_inf" {
    const inf_val = gf16_from_f32(std.math.inf(f32));
    try std.testing.expect(gf16_is_inf(inf_val));
    try std.testing.expect(!gf16_is_nan(inf_val));

    const zero = gf16_from_f32(0.0);
    try std.testing.expect(gf16_is_zero(zero));
}

test "C-ABI: gf16_phi_quantize" {
    const original = 2.71828;
    const quantized = gf16_phi_quantize(original);
    const dequantized = gf16_phi_dequantize(quantized);

    const error_pct = @abs((dequantized - original) / original) * 100.0;
    try std.testing.expect(error_pct < 10.0);
}

test "C-ABI: gf16_fma" {
    const a = gf16_from_f32(2.0);
    const b = gf16_from_f32(3.0);
    const c = gf16_from_f32(4.0);
    const result = gf16_fma(a, b, c);
    const val = gf16_to_f32(result);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), val, 0.05);
}

test "C-ABI: library version" {
    const version = std.mem.span(goldenfloat_version());
    try std.testing.expectEqualStrings("1.1.0", version);
}

test "C-ABI: goldenfloat_trinity returns 3.0" {
    const trinity = goldenfloat_trinity();
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), trinity, 1e-10);
}
