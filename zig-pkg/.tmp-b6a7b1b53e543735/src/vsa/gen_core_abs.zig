// VSA Core — HybridBigInt Operations (GENERATED)
// Using absolute imports to avoid module boundary issues

const std = @import("std");
const hybrid = @import("../vsa_hybrid/hybrid.zig");
const HybridBigInt = hybrid.HybridBigInt;
const Trit = hybrid.Trit;
const Vec32i8 = hybrid.Vec32i8;
const Vec32i16 = hybrid.Vec32i16;
const SIMD_WIDTH = hybrid.SIMD_WIDTH;

pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const prod = a_vec * b_vec;
        result.unpacked_cache[i..][0..SIMD_WIDTH].* = prod;
    }

    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        result.unpacked_cache[i] = a_trit * b_trit;
    }

    return result;
}

pub fn unbind(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return bind(bound, key);
}

pub fn bundle2(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;

        const a_wide: Vec32i16 = a_vec;
        const b_wide: Vec32i16 = b_vec;
        const sum = a_wide + b_wide;

        const zeros: Vec32i16 = @splat(0);
        const ones: Vec32i16 = @splat(1);
        const neg_ones: Vec32i16 = @splat(-1);

        const pos_mask = sum > zeros;
        const neg_mask = sum < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            result.unpacked_cache[i + j] = @truncate(out[j]);
        }
    }

    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const sum = a_trit + b_trit;

        if (sum > 0) {
            result.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            result.unpacked_cache[i] = 0;
        }
    }

    return result;
}

pub fn bundle3(a: *HybridBigInt, b: *HybridBigInt, c: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();
    c.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(@max(a.trit_len, b.trit_len), c.trit_len);
    const min_len = @min(@min(a.trit_len, b.trit_len), c.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const c_vec: Vec32i8 = c.unpacked_cache[i..][0..SIMD_WIDTH].*;

        const a_wide: Vec32i16 = a_vec;
        const b_wide: Vec32i16 = b_vec;
        const c_wide: Vec32i16 = c_vec;
        const sum = a_wide + b_wide + c_wide;

        const zeros: Vec32i16 = @splat(0);
        const ones: Vec32i16 = @splat(1);
        const neg_ones: Vec32i16 = @splat(-1);

        const pos_mask = sum > zeros;
        const neg_mask = sum < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            result.unpacked_cache[i + j] = @truncate(out[j]);
        }
    }

    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const c_trit: i16 = if (i < c.trit_len) c.unpacked_cache[i] else 0;
        const sum = a_trit + b_trit + c_trit;

        if (sum > 0) {
            result.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            result.unpacked_cache[i] = 0;
        }
    }

    result.trit_len = len;
    return result;
}

pub fn permute(v: *HybridBigInt, n: usize) HybridBigInt {
    v.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;

    const rotate = if (v.trit_len > 0) @mod(n, v.trit_len) else 0;

    for (0..v.trit_len) |i| {
        const src_idx = if (i >= rotate) i - rotate else i + v.trit_len - rotate;
        result.unpacked_cache[i] = v.unpacked_cache[src_idx];
    }

    return result;
}

pub fn inversePermute(v: *HybridBigInt, n: usize) HybridBigInt {
    v.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;

    const rotate = if (v.trit_len > 0) @mod(n, v.trit_len) else 0;

    for (0..v.trit_len) |i| {
        const src_idx = (i + rotate) % v.trit_len;
        result.unpacked_cache[i] = v.unpacked_cache[src_idx];
    }

    return result;
}

pub fn dotProduct(a: *HybridBigInt, b: *HybridBigInt) i64 {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var sum: i64 = 0;
    const len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const a_wide: Vec32i16 = a_vec;
        const b_wide: Vec32i16 = b_vec;
        const prod = a_wide * b_wide;
        sum += @reduce(.Add, prod);
    }

    while (i < len) : (i += 1) {
        const a_trit: i64 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i64 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        sum += a_trit * b_trit;
    }

    return sum;
}

pub fn vectorNorm(v: *HybridBigInt) f64 {
    v.ensureUnpacked();

    var sum: f64 = 0.0;
    for (0..v.trit_len) |i| {
        const t: f64 = @floatFromInt(v.unpacked_cache[i]);
        sum += t * t;
    }
    return @sqrt(sum);
}

pub fn cosineSimilarity(a: *const HybridBigInt, b: *const HybridBigInt) f64 {
    const dot = @constCast(a).dotProduct(@constCast(b));
    const norm_a = vectorNorm(@constCast(a));
    const norm_b = vectorNorm(@constCast(b));

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}
