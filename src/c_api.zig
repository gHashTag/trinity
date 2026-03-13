// @origin(manual) @regen(pending)
// Trinity VSA C API — Zig-backed FFI bridge
// Exposes the real SIMD-accelerated VSA core to C/C++/Python/Swift/Go
//
// All functions use opaque handles (heap-allocated HybridBigInt).
// Thread-safe: each vector is independent. No global state.

const std = @import("std");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");

const HybridBigInt = hybrid.HybridBigInt;
const Trit = hybrid.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// ALLOCATOR
// ═══════════════════════════════════════════════════════════════════════════════

const allocator = std.heap.c_allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn heapAlloc() ?*HybridBigInt {
    return allocator.create(HybridBigInt) catch null;
}

fn heapFree(ptr: *HybridBigInt) void {
    allocator.destroy(ptr);
}

fn toHybrid(ptr: *anyopaque) *HybridBigInt {
    return @ptrCast(@alignCast(ptr));
}

fn toOpaque(ptr: *HybridBigInt) *anyopaque {
    return @ptrCast(ptr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERSION
// ═══════════════════════════════════════════════════════════════════════════════

export fn trinity_vsa_version() [*:0]const u8 {
    return "0.2.0";
}

// ═══════════════════════════════════════════════════════════════════════════════
// VECTOR LIFECYCLE
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a zero vector with given dimension (max 59049)
export fn trinity_vsa_vector_zeros(dim: usize) ?*anyopaque {
    const ptr = heapAlloc() orelse return null;
    ptr.* = HybridBigInt.zero();
    ptr.mode = .unpacked_mode;
    ptr.trit_len = @min(dim, vsa.MAX_TRITS);
    return toOpaque(ptr);
}

/// Create a random hypervector with given dimension and seed
export fn trinity_vsa_vector_random(dim: usize, seed: u64) ?*anyopaque {
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.randomVector(dim, seed);
    return toOpaque(ptr);
}

/// Create vector from an array of int8 values (-1, 0, +1)
export fn trinity_vsa_from_array(data: [*]const i8, dim: usize) ?*anyopaque {
    const ptr = heapAlloc() orelse return null;
    ptr.* = HybridBigInt.zero();
    ptr.mode = .unpacked_mode;
    ptr.dirty = true;

    const actual_dim = @min(dim, vsa.MAX_TRITS);
    ptr.trit_len = actual_dim;

    for (0..actual_dim) |i| {
        const val = data[i];
        if (val > 0) {
            ptr.unpacked_cache[i] = 1;
        } else if (val < 0) {
            ptr.unpacked_cache[i] = -1;
        } else {
            ptr.unpacked_cache[i] = 0;
        }
    }

    return toOpaque(ptr);
}

/// Clone a vector (deep copy)
export fn trinity_vsa_vector_clone(v: ?*anyopaque) ?*anyopaque {
    const src = toHybrid(v orelse return null);
    const ptr = heapAlloc() orelse return null;
    ptr.* = src.*;
    return toOpaque(ptr);
}

/// Free a vector (must be called for every created vector)
export fn trinity_vsa_vector_free(v: ?*anyopaque) void {
    if (v) |ptr| {
        heapFree(toHybrid(ptr));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind two vectors (element-wise multiplication, creates associations)
/// bind(a, a) = all +1 (self-inverse property)
export fn trinity_vsa_bind(a: ?*anyopaque, b: ?*anyopaque) ?*anyopaque {
    const ha = toHybrid(a orelse return null);
    const hb = toHybrid(b orelse return null);
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.bind(ha, hb);
    return toOpaque(ptr);
}

/// Unbind (inverse of bind — same operation for balanced ternary)
export fn trinity_vsa_unbind(a: ?*anyopaque, b: ?*anyopaque) ?*anyopaque {
    const ha = toHybrid(a orelse return null);
    const hb = toHybrid(b orelse return null);
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.unbind(ha, hb);
    return toOpaque(ptr);
}

/// Bundle 2 vectors (majority voting — result similar to both inputs)
export fn trinity_vsa_bundle2(a: ?*anyopaque, b: ?*anyopaque) ?*anyopaque {
    const ha = toHybrid(a orelse return null);
    const hb = toHybrid(b orelse return null);
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.bundle2(ha, hb);
    return toOpaque(ptr);
}

/// Bundle 3 vectors (true majority voting)
export fn trinity_vsa_bundle3(a: ?*anyopaque, b: ?*anyopaque, c: ?*anyopaque) ?*anyopaque {
    const ha = toHybrid(a orelse return null);
    const hb = toHybrid(b orelse return null);
    const hc = toHybrid(c orelse return null);
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.bundle3(ha, hb, hc);
    return toOpaque(ptr);
}

/// Permute vector (cyclic shift by k positions — for sequence encoding)
export fn trinity_vsa_permute(v: ?*anyopaque, k: usize) ?*anyopaque {
    const hv = toHybrid(v orelse return null);
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.permute(hv, k);
    return toOpaque(ptr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMILARITY MEASURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Cosine similarity in [-1.0, 1.0]
export fn trinity_vsa_cosine_similarity(a: ?*anyopaque, b: ?*anyopaque) f64 {
    const ha = toHybrid(a orelse return 0.0);
    const hb = toHybrid(b orelse return 0.0);
    return vsa.cosineSimilarity(ha, hb);
}

/// Hamming distance (number of differing trits)
export fn trinity_vsa_hamming_distance(a: ?*anyopaque, b: ?*anyopaque) usize {
    const ha = toHybrid(a orelse return 0);
    const hb = toHybrid(b orelse return 0);
    return vsa.hammingDistance(ha, hb);
}

/// Dot product (sum of element-wise products)
export fn trinity_vsa_dot_product(a: ?*anyopaque, b: ?*anyopaque) i64 {
    const ha = toHybrid(a orelse return 0);
    const hb = toHybrid(b orelse return 0);
    return ha.dotProduct(hb);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXT ENCODING (SEMANTIC SEARCH)
// ═══════════════════════════════════════════════════════════════════════════════

/// Encode text string to hypervector (for semantic search)
export fn trinity_vsa_encode_text(text: [*]const u8, len: usize) ?*anyopaque {
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.encodeText(text[0..len]);
    return toOpaque(ptr);
}

/// Encode text to hypervector using word-level bag-of-words
/// Better for search: texts sharing words have high similarity regardless of order
export fn trinity_vsa_encode_text_words(text: [*]const u8, len: usize) ?*anyopaque {
    const ptr = heapAlloc() orelse return null;
    ptr.* = vsa.encodeTextWords(text[0..len]);
    return toOpaque(ptr);
}

/// Decode hypervector back to text
/// Returns number of decoded characters written to buf
export fn trinity_vsa_decode_text(v: ?*anyopaque, buf: [*]u8, buf_len: usize) usize {
    const hv = toHybrid(v orelse return 0);
    const result = vsa.decodeText(hv, buf_len, buf[0..buf_len]);
    return result.len;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VECTOR ACCESS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get vector dimension (number of trits)
export fn trinity_vsa_get_dim(v: ?*anyopaque) usize {
    const hv = toHybrid(v orelse return 0);
    return hv.trit_len;
}

/// Get trit value at index (returns -1, 0, or +1)
export fn trinity_vsa_get_trit(v: ?*anyopaque, index: usize) i8 {
    const hv = toHybrid(v orelse return 0);
    hv.ensureUnpacked();
    if (index >= hv.trit_len) return 0;
    return hv.unpacked_cache[index];
}

/// Set trit value at index (value clamped to -1, 0, +1)
export fn trinity_vsa_set_trit(v: ?*anyopaque, index: usize, value: i8) void {
    const hv = toHybrid(v orelse return);
    hv.ensureUnpacked();
    if (index >= hv.trit_len) return;
    if (value > 0) {
        hv.unpacked_cache[index] = 1;
    } else if (value < 0) {
        hv.unpacked_cache[index] = -1;
    } else {
        hv.unpacked_cache[index] = 0;
    }
    hv.dirty = true;
}

/// Copy trit data to output array
/// Returns number of trits written
export fn trinity_vsa_to_array(v: ?*anyopaque, out: [*]i8, max_len: usize) usize {
    const hv = toHybrid(v orelse return 0);
    hv.ensureUnpacked();
    const copy_len = @min(hv.trit_len, max_len);
    for (0..copy_len) |i| {
        out[i] = hv.unpacked_cache[i];
    }
    return copy_len;
}

/// Get maximum supported vector dimension
export fn trinity_vsa_max_dim() usize {
    return vsa.MAX_TRITS;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "c_api: version" {
    const ver = trinity_vsa_version();
    const slice = std.mem.span(ver);
    try std.testing.expect(slice.len > 0);
}

test "c_api: vector zeros create/free" {
    const v = trinity_vsa_vector_zeros(1000) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(v);
    try std.testing.expectEqual(@as(usize, 1000), trinity_vsa_get_dim(v));
    // All trits should be 0
    try std.testing.expectEqual(@as(i8, 0), trinity_vsa_get_trit(v, 0));
    try std.testing.expectEqual(@as(i8, 0), trinity_vsa_get_trit(v, 999));
}

test "c_api: vector random" {
    const v = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(v);
    try std.testing.expectEqual(@as(usize, 1000), trinity_vsa_get_dim(v));
    // Random vector should have non-zero trits
    var non_zero: usize = 0;
    for (0..1000) |i| {
        if (trinity_vsa_get_trit(v, i) != 0) non_zero += 1;
    }
    try std.testing.expect(non_zero > 0);
}

test "c_api: from_array / to_array roundtrip" {
    const data = [_]i8{ 1, -1, 0, 1, -1, 0, 1, 0, -1, 1 };
    const v = trinity_vsa_from_array(&data, data.len) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(v);

    var out: [10]i8 = undefined;
    const copied = trinity_vsa_to_array(v, &out, out.len);
    try std.testing.expectEqual(@as(usize, 10), copied);
    try std.testing.expectEqualSlices(i8, &data, &out);
}

test "c_api: clone" {
    const v = trinity_vsa_vector_random(500, 123) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(v);

    const cloned = trinity_vsa_vector_clone(v) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(cloned);

    const sim = trinity_vsa_cosine_similarity(v, cloned);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "c_api: bind self-inverse" {
    const a = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(a);

    const bound = trinity_vsa_bind(a, a) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(bound);

    // bind(a, a) should give all +1 for non-zero trits
    for (0..1000) |i| {
        const a_trit = trinity_vsa_get_trit(a, i);
        const r_trit = trinity_vsa_get_trit(bound, i);
        if (a_trit != 0) {
            try std.testing.expectEqual(@as(i8, 1), r_trit);
        } else {
            try std.testing.expectEqual(@as(i8, 0), r_trit);
        }
    }
}

test "c_api: bind/unbind roundtrip" {
    const a = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(a);
    const b = trinity_vsa_vector_random(1000, 99) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(b);

    const bound = trinity_vsa_bind(a, b) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(bound);

    const recovered = trinity_vsa_unbind(bound, b) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(recovered);

    // Similarity > 0.7 because zero trits lose information in bind
    const sim = trinity_vsa_cosine_similarity(a, recovered);
    try std.testing.expect(sim > 0.7);
}

test "c_api: bundle2 similarity" {
    const a = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(a);
    const b = trinity_vsa_vector_random(1000, 99) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(b);

    const bundled = trinity_vsa_bundle2(a, b) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(bundled);

    // Bundled should be similar to both inputs
    const sim_a = trinity_vsa_cosine_similarity(bundled, a);
    const sim_b = trinity_vsa_cosine_similarity(bundled, b);
    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "c_api: permute" {
    const v = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(v);

    const permuted = trinity_vsa_permute(v, 5) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(permuted);

    // Permuted should be dissimilar to original (for high dimensions)
    const sim = trinity_vsa_cosine_similarity(v, permuted);
    try std.testing.expect(sim < 0.5);
}

test "c_api: cosine_similarity identical" {
    const a = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(a);
    const b = trinity_vsa_vector_clone(a) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(b);

    const sim = trinity_vsa_cosine_similarity(a, b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "c_api: hamming_distance identical is zero" {
    const a = trinity_vsa_vector_random(1000, 42) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(a);
    const b = trinity_vsa_vector_clone(a) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(b);

    const dist = trinity_vsa_hamming_distance(a, b);
    try std.testing.expectEqual(@as(usize, 0), dist);
}

test "c_api: encode_text + similarity" {
    const hello1 = trinity_vsa_encode_text("hello world", 11) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(hello1);
    const hello2 = trinity_vsa_encode_text("hello world", 11) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(hello2);
    const goodbye = trinity_vsa_encode_text("goodbye moon", 12) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(goodbye);

    // Same text should have perfect similarity
    const sim_same = trinity_vsa_cosine_similarity(hello1, hello2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim_same, 0.001);

    // Different text should have lower similarity
    const sim_diff = trinity_vsa_cosine_similarity(hello1, goodbye);
    try std.testing.expect(sim_diff < sim_same);
}

test "c_api: set_trit and get_trit" {
    const v = trinity_vsa_vector_zeros(100) orelse return error.AllocFailed;
    defer trinity_vsa_vector_free(v);

    trinity_vsa_set_trit(v, 0, 1);
    trinity_vsa_set_trit(v, 1, -1);
    trinity_vsa_set_trit(v, 2, 5); // should clamp to 1

    try std.testing.expectEqual(@as(i8, 1), trinity_vsa_get_trit(v, 0));
    try std.testing.expectEqual(@as(i8, -1), trinity_vsa_get_trit(v, 1));
    try std.testing.expectEqual(@as(i8, 1), trinity_vsa_get_trit(v, 2));
}

test "c_api: null safety" {
    // All functions should handle null gracefully
    trinity_vsa_vector_free(null);
    try std.testing.expectEqual(@as(usize, 0), trinity_vsa_get_dim(null));
    try std.testing.expectEqual(@as(i8, 0), trinity_vsa_get_trit(null, 0));
    try std.testing.expectEqual(@as(f64, 0.0), trinity_vsa_cosine_similarity(null, null));
    try std.testing.expectEqual(@as(usize, 0), trinity_vsa_hamming_distance(null, null));
    try std.testing.expectEqual(@as(?*anyopaque, null), trinity_vsa_bind(null, null));
    try std.testing.expectEqual(@as(?*anyopaque, null), trinity_vsa_vector_clone(null));
}

test "c_api: max_dim" {
    try std.testing.expectEqual(@as(usize, 59049), trinity_vsa_max_dim());
}
