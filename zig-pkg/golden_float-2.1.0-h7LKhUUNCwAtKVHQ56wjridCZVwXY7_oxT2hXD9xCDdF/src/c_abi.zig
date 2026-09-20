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
    const fa = rawToGf16(a).toF32();
    const fb = rawToGf16(b).toF32();
    const fc = rawToGf16(c).toF32();
    return gf16ToRaw(golden.GF16.fromF32(fa * fb + fc));
}

export fn gf16_phi_fma(a: gf16_t, b: gf16_t, c: gf16_t) callconv(.c) gf16_t {
    return gf16ToRaw(golden.GF16.phiFma(rawToGf16(a), rawToGf16(b), rawToGf16(c)));
}

export fn gf16_phi_fms(a: gf16_t, b: gf16_t, c: gf16_t) callconv(.c) gf16_t {
    return gf16ToRaw(golden.GF16.phiFms(rawToGf16(a), rawToGf16(b), rawToGf16(c)));
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
// GF-T16 — balanced-ternary-exponent GoldenFloat (thin FFI over formats/gft.zig).
// The raw value is the 17-bit packed encoding carried in a u32 (declared in
// src/c/gft.h). This is FFI glue only; all arithmetic lives in the gft.zig codec.
// ═══════════════════════════════════════════════════════════════════════════════

const gft = @import("formats/gft.zig");

/// gft16_t is the raw 17-bit GF-T16 pattern in the low bits of a u32.
const gft16_t = u32;

inline fn gft16ToRaw(g: gft.GFT16) gft16_t {
    return @as(gft16_t, g.bits());
}
inline fn rawToGft16(raw: gft16_t) gft.GFT16 {
    return gft.GFT16.fromBits(@truncate(raw));
}

export fn gft16_from_f32(x: f32) callconv(.c) gft16_t {
    return gft16ToRaw(gft.GFT16.fromF32(x));
}
export fn gft16_to_f32(g: gft16_t) callconv(.c) f32 {
    return rawToGft16(g).toF32();
}
export fn gft16_add(a: gft16_t, b: gft16_t) callconv(.c) gft16_t {
    return gft16ToRaw(gft.GFT16.add(rawToGft16(a), rawToGft16(b)));
}
export fn gft16_sub(a: gft16_t, b: gft16_t) callconv(.c) gft16_t {
    return gft16ToRaw(gft.GFT16.sub(rawToGft16(a), rawToGft16(b)));
}
export fn gft16_mul(a: gft16_t, b: gft16_t) callconv(.c) gft16_t {
    return gft16ToRaw(gft.GFT16.mul(rawToGft16(a), rawToGft16(b)));
}
export fn gft16_div(a: gft16_t, b: gft16_t) callconv(.c) gft16_t {
    return gft16ToRaw(gft.GFT16.div(rawToGft16(a), rawToGft16(b)));
}
export fn gft16_neg(g: gft16_t) callconv(.c) gft16_t {
    return gft16ToRaw(rawToGft16(g).neg());
}
export fn gft16_abs(g: gft16_t) callconv(.c) gft16_t {
    return gft16ToRaw(rawToGft16(g).abs());
}
export fn gft16_is_finite(g: gft16_t) callconv(.c) u8 {
    return @intFromBool(rawToGft16(g).isFinite());
}

// ═══════════════════════════════════════════════════════════════════════════════
// The other GF-T rungs — GF-T4 (u8), GF-T8 (u16), GF-T32 (u64). Same thin glue
// pattern as gft16; the packed value rides in the low bits of the C carrier type.
// ═══════════════════════════════════════════════════════════════════════════════

const gft4_t = u8;
const gft8_t = u16;
const gft32_t = u64;

export fn gft4_from_f32(x: f32) callconv(.c) gft4_t {
    return @as(gft4_t, gft.GFT4.fromF32(x).bits());
}
export fn gft4_to_f32(g: gft4_t) callconv(.c) f32 {
    return gft.GFT4.fromBits(@truncate(g)).toF32();
}
export fn gft4_mul(a: gft4_t, b: gft4_t) callconv(.c) gft4_t {
    return @as(gft4_t, gft.GFT4.mul(gft.GFT4.fromBits(@truncate(a)), gft.GFT4.fromBits(@truncate(b))).bits());
}
export fn gft4_is_finite(g: gft4_t) callconv(.c) u8 {
    return @intFromBool(gft.GFT4.fromBits(@truncate(g)).isFinite());
}

export fn gft8_from_f32(x: f32) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.fromF32(x).bits());
}
export fn gft8_to_f32(g: gft8_t) callconv(.c) f32 {
    return gft.GFT8.fromBits(@truncate(g)).toF32();
}
export fn gft8_add(a: gft8_t, b: gft8_t) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.add(gft.GFT8.fromBits(@truncate(a)), gft.GFT8.fromBits(@truncate(b))).bits());
}
export fn gft8_mul(a: gft8_t, b: gft8_t) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.mul(gft.GFT8.fromBits(@truncate(a)), gft.GFT8.fromBits(@truncate(b))).bits());
}
export fn gft8_sub(a: gft8_t, b: gft8_t) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.sub(gft.GFT8.fromBits(@truncate(a)), gft.GFT8.fromBits(@truncate(b))).bits());
}
export fn gft8_div(a: gft8_t, b: gft8_t) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.div(gft.GFT8.fromBits(@truncate(a)), gft.GFT8.fromBits(@truncate(b))).bits());
}
export fn gft8_neg(g: gft8_t) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.neg(gft.GFT8.fromBits(@truncate(g))).bits());
}
export fn gft8_abs(g: gft8_t) callconv(.c) gft8_t {
    return @as(gft8_t, gft.GFT8.abs(gft.GFT8.fromBits(@truncate(g))).bits());
}
export fn gft8_is_finite(g: gft8_t) callconv(.c) u8 {
    return @intFromBool(gft.GFT8.fromBits(@truncate(g)).isFinite());
}

export fn gft32_from_f32(x: f32) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.fromF32(x).bits());
}
export fn gft32_to_f32(g: gft32_t) callconv(.c) f32 {
    return gft.GFT32.fromBits(@truncate(g)).toF32();
}
export fn gft32_add(a: gft32_t, b: gft32_t) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.add(gft.GFT32.fromBits(@truncate(a)), gft.GFT32.fromBits(@truncate(b))).bits());
}
export fn gft32_mul(a: gft32_t, b: gft32_t) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.mul(gft.GFT32.fromBits(@truncate(a)), gft.GFT32.fromBits(@truncate(b))).bits());
}
export fn gft32_sub(a: gft32_t, b: gft32_t) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.sub(gft.GFT32.fromBits(@truncate(a)), gft.GFT32.fromBits(@truncate(b))).bits());
}
export fn gft32_div(a: gft32_t, b: gft32_t) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.div(gft.GFT32.fromBits(@truncate(a)), gft.GFT32.fromBits(@truncate(b))).bits());
}
export fn gft32_neg(g: gft32_t) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.neg(gft.GFT32.fromBits(@truncate(g))).bits());
}
export fn gft32_abs(g: gft32_t) callconv(.c) gft32_t {
    return @as(gft32_t, gft.GFT32.abs(gft.GFT32.fromBits(@truncate(g))).bits());
}
export fn gft32_is_finite(g: gft32_t) callconv(.c) u8 {
    return @intFromBool(gft.GFT32.fromBits(@truncate(g)).isFinite());
}

// ═══════════════════════════════════════════════════════════════════════════════
// Binary GF ladder — the φ²-sized rungs from the gf_binary.zig factory.
// GF16 is already covered by the rich gf16_* API above (identical [1:6:9] b31), so
// this exposes GF8/GF12/GF20/GF24/GF32. GF4 is intentionally omitted: [1:1:2] gives a
// 1-bit exponent (exp 0 = zero, exp 1 = reserved Inf/NaN) with NO normal values.
// The packed N-bit value rides in the low bits of the next byte-sized carrier.
// ═══════════════════════════════════════════════════════════════════════════════

const gfl = @import("formats/gf_binary.zig");

// ---- GF8 (8-bit value in u8) ----
export fn gf8_from_f32(x: f32) callconv(.c) u8 {
    return @as(u8, gfl.GF8.fromF32(x).bits_());
}
export fn gf8_to_f32(g: u8) callconv(.c) f32 {
    return gfl.GF8.fromBits(@truncate(g)).toF32();
}
export fn gf8_add(a: u8, b: u8) callconv(.c) u8 {
    return @as(u8, gfl.GF8.add(gfl.GF8.fromBits(@truncate(a)), gfl.GF8.fromBits(@truncate(b))).bits_());
}
export fn gf8_sub(a: u8, b: u8) callconv(.c) u8 {
    return @as(u8, gfl.GF8.sub(gfl.GF8.fromBits(@truncate(a)), gfl.GF8.fromBits(@truncate(b))).bits_());
}
export fn gf8_mul(a: u8, b: u8) callconv(.c) u8 {
    return @as(u8, gfl.GF8.mul(gfl.GF8.fromBits(@truncate(a)), gfl.GF8.fromBits(@truncate(b))).bits_());
}
export fn gf8_div(a: u8, b: u8) callconv(.c) u8 {
    return @as(u8, gfl.GF8.div(gfl.GF8.fromBits(@truncate(a)), gfl.GF8.fromBits(@truncate(b))).bits_());
}
export fn gf8_neg(g: u8) callconv(.c) u8 {
    return @as(u8, gfl.GF8.neg(gfl.GF8.fromBits(@truncate(g))).bits_());
}
export fn gf8_abs(g: u8) callconv(.c) u8 {
    return @as(u8, gfl.GF8.abs(gfl.GF8.fromBits(@truncate(g))).bits_());
}
export fn gf8_is_finite(g: u8) callconv(.c) u8 {
    return @intFromBool(gfl.GF8.fromBits(@truncate(g)).isFinite());
}

// ---- GF12 (12-bit value in u16) ----
export fn gf12_from_f32(x: f32) callconv(.c) u16 {
    return @as(u16, gfl.GF12.fromF32(x).bits_());
}
export fn gf12_to_f32(g: u16) callconv(.c) f32 {
    return gfl.GF12.fromBits(@truncate(g)).toF32();
}
export fn gf12_add(a: u16, b: u16) callconv(.c) u16 {
    return @as(u16, gfl.GF12.add(gfl.GF12.fromBits(@truncate(a)), gfl.GF12.fromBits(@truncate(b))).bits_());
}
export fn gf12_sub(a: u16, b: u16) callconv(.c) u16 {
    return @as(u16, gfl.GF12.sub(gfl.GF12.fromBits(@truncate(a)), gfl.GF12.fromBits(@truncate(b))).bits_());
}
export fn gf12_mul(a: u16, b: u16) callconv(.c) u16 {
    return @as(u16, gfl.GF12.mul(gfl.GF12.fromBits(@truncate(a)), gfl.GF12.fromBits(@truncate(b))).bits_());
}
export fn gf12_div(a: u16, b: u16) callconv(.c) u16 {
    return @as(u16, gfl.GF12.div(gfl.GF12.fromBits(@truncate(a)), gfl.GF12.fromBits(@truncate(b))).bits_());
}
export fn gf12_neg(g: u16) callconv(.c) u16 {
    return @as(u16, gfl.GF12.neg(gfl.GF12.fromBits(@truncate(g))).bits_());
}
export fn gf12_abs(g: u16) callconv(.c) u16 {
    return @as(u16, gfl.GF12.abs(gfl.GF12.fromBits(@truncate(g))).bits_());
}
export fn gf12_is_finite(g: u16) callconv(.c) u8 {
    return @intFromBool(gfl.GF12.fromBits(@truncate(g)).isFinite());
}

// ---- GF20 (20-bit value in u32) ----
export fn gf20_from_f32(x: f32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.fromF32(x).bits_());
}
export fn gf20_to_f32(g: u32) callconv(.c) f32 {
    return gfl.GF20.fromBits(@truncate(g)).toF32();
}
export fn gf20_add(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.add(gfl.GF20.fromBits(@truncate(a)), gfl.GF20.fromBits(@truncate(b))).bits_());
}
export fn gf20_sub(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.sub(gfl.GF20.fromBits(@truncate(a)), gfl.GF20.fromBits(@truncate(b))).bits_());
}
export fn gf20_mul(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.mul(gfl.GF20.fromBits(@truncate(a)), gfl.GF20.fromBits(@truncate(b))).bits_());
}
export fn gf20_div(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.div(gfl.GF20.fromBits(@truncate(a)), gfl.GF20.fromBits(@truncate(b))).bits_());
}
export fn gf20_neg(g: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.neg(gfl.GF20.fromBits(@truncate(g))).bits_());
}
export fn gf20_abs(g: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF20.abs(gfl.GF20.fromBits(@truncate(g))).bits_());
}
export fn gf20_is_finite(g: u32) callconv(.c) u8 {
    return @intFromBool(gfl.GF20.fromBits(@truncate(g)).isFinite());
}

// ---- GF24 (24-bit value in u32) ----
export fn gf24_from_f32(x: f32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.fromF32(x).bits_());
}
export fn gf24_to_f32(g: u32) callconv(.c) f32 {
    return gfl.GF24.fromBits(@truncate(g)).toF32();
}
export fn gf24_add(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.add(gfl.GF24.fromBits(@truncate(a)), gfl.GF24.fromBits(@truncate(b))).bits_());
}
export fn gf24_sub(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.sub(gfl.GF24.fromBits(@truncate(a)), gfl.GF24.fromBits(@truncate(b))).bits_());
}
export fn gf24_mul(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.mul(gfl.GF24.fromBits(@truncate(a)), gfl.GF24.fromBits(@truncate(b))).bits_());
}
export fn gf24_div(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.div(gfl.GF24.fromBits(@truncate(a)), gfl.GF24.fromBits(@truncate(b))).bits_());
}
export fn gf24_neg(g: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.neg(gfl.GF24.fromBits(@truncate(g))).bits_());
}
export fn gf24_abs(g: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF24.abs(gfl.GF24.fromBits(@truncate(g))).bits_());
}
export fn gf24_is_finite(g: u32) callconv(.c) u8 {
    return @intFromBool(gfl.GF24.fromBits(@truncate(g)).isFinite());
}

// ---- GF32 (32-bit value in u32) ----
export fn gf32_from_f32(x: f32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.fromF32(x).bits_());
}
export fn gf32_to_f32(g: u32) callconv(.c) f32 {
    return gfl.GF32.fromBits(@truncate(g)).toF32();
}
export fn gf32_add(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.add(gfl.GF32.fromBits(@truncate(a)), gfl.GF32.fromBits(@truncate(b))).bits_());
}
export fn gf32_sub(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.sub(gfl.GF32.fromBits(@truncate(a)), gfl.GF32.fromBits(@truncate(b))).bits_());
}
export fn gf32_mul(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.mul(gfl.GF32.fromBits(@truncate(a)), gfl.GF32.fromBits(@truncate(b))).bits_());
}
export fn gf32_div(a: u32, b: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.div(gfl.GF32.fromBits(@truncate(a)), gfl.GF32.fromBits(@truncate(b))).bits_());
}
export fn gf32_neg(g: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.neg(gfl.GF32.fromBits(@truncate(g))).bits_());
}
export fn gf32_abs(g: u32) callconv(.c) u32 {
    return @as(u32, gfl.GF32.abs(gfl.GF32.fromBits(@truncate(g))).bits_());
}
export fn gf32_is_finite(g: u32) callconv(.c) u8 {
    return @intFromBool(gfl.GF32.fromBits(@truncate(g)).isFinite());
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

    const nan_val = gf16_from_f32(std.math.nan(f32));
    try std.testing.expect(gf16_is_nan(nan_val));
    try std.testing.expect(!gf16_is_inf(nan_val));
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

test "C-ABI: gf16_phi_fma" {
    const a = gf16_phi_quantize(2.0);
    const b = gf16_phi_quantize(3.0);
    const c = gf16_phi_quantize(4.0);
    const result = gf16_phi_fma(a, b, c);
    const deq = gf16_phi_dequantize(result);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), deq, 1.5);
}

test "C-ABI: gf16_phi_fms" {
    const a = gf16_phi_quantize(5.0);
    const b = gf16_phi_quantize(3.0);
    const c = gf16_phi_quantize(4.0);
    const result = gf16_phi_fms(a, b, c);
    const deq = gf16_phi_dequantize(result);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), deq, 2.0);
}

test "C-ABI: library version" {
    const version = std.mem.span(goldenfloat_version());
    try std.testing.expectEqualStrings("1.1.0", version);
}

test "C-ABI: goldenfloat_trinity returns 3.0" {
    const trinity = goldenfloat_trinity();
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), trinity, 1e-10);
}

test "C-ABI: gft16_from_f32 and gft16_to_f32" {
    const val: f32 = 3.14159;
    const g = gft16_from_f32(val);
    const back = gft16_to_f32(g);
    try std.testing.expect(@abs(val - back) / (@abs(val) + 1e-9) < 0.005);
    // raw is a 17-bit value carried in u32
    try std.testing.expect(g <= 0x1FFFF);
}

test "C-ABI: gft16 arithmetic matches the codec" {
    const a = gft16_from_f32(1.5);
    const b = gft16_from_f32(2.5);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), gft16_to_f32(gft16_add(a, b)), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), gft16_to_f32(gft16_sub(b, a)), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), gft16_to_f32(gft16_mul(a, b)), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), gft16_to_f32(gft16_div(a, b)), 0.02);
}

test "C-ABI: gft16_neg / gft16_abs / gft16_is_finite" {
    const x = gft16_from_f32(3.5);
    try std.testing.expectApproxEqAbs(@as(f32, -3.5), gft16_to_f32(gft16_neg(x)), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), gft16_to_f32(gft16_abs(gft16_neg(x))), 0.02);
    try std.testing.expectEqual(@as(u8, 1), gft16_is_finite(gft16_from_f32(1.0)));
    try std.testing.expectEqual(@as(u8, 0), gft16_is_finite(gft16_from_f32(1e30))); // overflow -> Inf
}

test "C-ABI: gft16 round-trips through the raw u32 (FFI stability)" {
    const g = gft16_from_f32(-6.28);
    try std.testing.expectEqual(gft16_to_f32(g), gft16_to_f32(gft16_from_f32(gft16_to_f32(g))));
}

test "C-ABI: gft4 / gft8 / gft32 from/to + carrier widths" {
    // GF-T4 (u8, 1-bit mantissa -> coarse)
    try std.testing.expect(gft4_from_f32(2.0) <= 0x3F); // 6-bit value
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), gft4_to_f32(gft4_from_f32(2.0)), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), gft4_to_f32(gft4_mul(gft4_from_f32(2.0), gft4_from_f32(2.0))), 0.5);
    // GF-T8 (u16, 4-bit mantissa)
    try std.testing.expect(gft8_from_f32(3.0) <= 0x3FF); // 10-bit value
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), gft8_to_f32(gft8_from_f32(3.0)), 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), gft8_to_f32(gft8_add(gft8_from_f32(2.0), gft8_from_f32(3.0))), 0.2);
    // GF-T32 (u64, 25-bit mantissa, huge range)
    try std.testing.expect(gft32_from_f32(1.0) <= 0xFFFFFFFFF); // 36-bit value
    try std.testing.expectApproxEqAbs(@as(f32, 3.14159), gft32_to_f32(gft32_from_f32(3.14159)), 1e-4);
    try std.testing.expect(gft32_is_finite(gft32_from_f32(6.022e23)) == 1); // GF-T32 holds it
    try std.testing.expect(gft32_to_f32(gft32_mul(gft32_from_f32(1e10), gft32_from_f32(1e10))) > 5e19);
}
