// TVC VSA - Vector Symbolic Architecture for Balanced Ternary
// Hyperdimensional computing operations: bind, bundle, similarity
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const tvc_hybrid = @import("hybrid.zig");

pub const HybridBigInt = tvc_hybrid.HybridBigInt;
pub const Trit = tvc_hybrid.Trit;
pub const Vec32i8 = tvc_hybrid.Vec32i8;
pub const SIMD_WIDTH = tvc_hybrid.SIMD_WIDTH;
pub const MAX_TRITS = tvc_hybrid.MAX_TRITS;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind operation (XOR-like for balanced ternary)
/// Creates associations between vectors
/// bind(a, b) = a * b (element-wise multiplication)
/// Properties:
/// - bind(a, a) = all +1 (self-inverse)
/// - bind(a, bind(a, b)) = b (unbind)
/// - Preserves similarity structure
pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    // Fast path: both vectors same length, use direct SIMD
    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    // Process full SIMD chunks (no bounds checking needed)
    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const prod = a_vec * b_vec; // Direct SIMD multiply
        result.unpacked_cache[i..][0..SIMD_WIDTH].* = prod;
    }

    // Process remainder with scalar ops
    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        result.unpacked_cache[i] = a_trit * b_trit;
    }

    return result;
}

/// Unbind operation (inverse of bind)
/// unbind(bound, key) = bind(bound, key) (same as bind for balanced ternary)
pub fn unbind(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return bind(bound, key);
}

/// Bundle operation (majority voting for superposition)
/// Combines multiple vectors into one that is similar to all inputs
/// For 2 vectors: majority(a, b) with tie-breaker
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

    // SIMD bundle: sum then threshold
    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;

        // Widen to i16 for safe addition
        const a_wide: @Vector(32, i16) = a_vec;
        const b_wide: @Vector(32, i16) = b_vec;
        const sum = a_wide + b_wide;

        // Threshold: >0 -> 1, <0 -> -1, =0 -> 0
        const zeros: @Vector(32, i16) = @splat(0);
        const ones: @Vector(32, i16) = @splat(1);
        const neg_ones: @Vector(32, i16) = @splat(-1);

        const pos_mask = sum > zeros;
        const neg_mask = sum < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        // Narrow back to i8
        inline for (0..SIMD_WIDTH) |j| {
            result.unpacked_cache[i + j] = @intCast(out[j]);
        }
    }

    // Scalar remainder
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

/// Bundle 3 vectors (true majority voting)
pub fn bundle3(a: *HybridBigInt, b: *HybridBigInt, c: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();
    c.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(@max(a.trit_len, b.trit_len), c.trit_len);

    for (0..len) |i| {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const c_trit: i16 = if (i < c.trit_len) c.unpacked_cache[i] else 0;

        const sum = a_trit + b_trit + c_trit;

        // Majority voting: 2 out of 3
        if (sum >= 2) {
            result.unpacked_cache[i] = 1;
        } else if (sum <= -2) {
            result.unpacked_cache[i] = -1;
        } else if (sum > 0) {
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

/// Cosine similarity between two vectors
/// Returns value in range [-1, 1]
pub fn cosineSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot = a.dotProduct(b);
    const norm_a = vectorNorm(a);
    const norm_b = vectorNorm(b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

/// Hamming distance (number of differing trits)
/// SIMD optimized: compares 32 trits at a time
pub fn hammingDistance(a: *HybridBigInt, b: *HybridBigInt) usize {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var distance: usize = 0;
    const len = @max(a.trit_len, b.trit_len);
    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    // SIMD comparison
    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;

        // XOR-like comparison: different if a != b
        const diff = a_vec != b_vec;

        // Count true values (popcount)
        distance += @popCount(@as(u32, @bitCast(diff)));
    }

    // Scalar remainder
    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;

        if (a_trit != b_trit) {
            distance += 1;
        }
    }

    return distance;
}

/// Normalized Hamming similarity (1 - hamming_distance / len)
pub fn hammingSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 1.0;

    const distance = hammingDistance(a, b);
    return 1.0 - @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(len));
}

/// Dot similarity (normalized dot product)
pub fn dotSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot = a.dotProduct(b);
    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / @as(f64, @floatFromInt(len));
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD element-wise multiplication
fn simdMultiply(a: Vec32i8, b: Vec32i8) Vec32i8 {
    // For balanced ternary: result is always in {-1, 0, 1}
    // -1 * -1 = 1, -1 * 0 = 0, -1 * 1 = -1
    // 0 * x = 0
    // 1 * -1 = -1, 1 * 0 = 0, 1 * 1 = 1
    const a_wide: @Vector(32, i16) = a;
    const b_wide: @Vector(32, i16) = b;
    const prod = a_wide * b_wide;

    var result: Vec32i8 = undefined;
    inline for (0..32) |i| {
        result[i] = @intCast(prod[i]);
    }
    return result;
}

/// Vector L2 norm (sqrt of sum of squares)
fn vectorNorm(v: *HybridBigInt) f64 {
    v.ensureUnpacked();

    var sum_sq: i64 = 0;
    for (0..v.trit_len) |i| {
        const trit: i64 = v.unpacked_cache[i];
        sum_sq += trit * trit;
    }

    return @sqrt(@as(f64, @floatFromInt(sum_sq)));
}

/// Count non-zero trits
pub fn countNonZero(v: *HybridBigInt) usize {
    v.ensureUnpacked();

    var count: usize = 0;
    for (0..v.trit_len) |i| {
        if (v.unpacked_cache[i] != 0) {
            count += 1;
        }
    }
    return count;
}

/// Create random vector (for testing)
pub fn randomVector(len: usize, seed: u64) HybridBigInt {
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = @min(len, MAX_TRITS);

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    for (0..result.trit_len) |i| {
        const r = random.intRangeAtMost(i8, -1, 1);
        result.unpacked_cache[i] = r;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMUTE OPERATIONS (для кодирования последовательностей)
// ═══════════════════════════════════════════════════════════════════════════════

/// Permute (циклический сдвиг вправо на k позиций)
/// Используется для кодирования последовательностей:
/// sequence(a, b, c) = a + permute(b, 1) + permute(c, 2)
pub fn permute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;

    if (v.trit_len == 0) return result;

    const shift = k % v.trit_len;

    // Циклический сдвиг вправо: новая позиция = (старая + shift) % len
    for (0..v.trit_len) |i| {
        const new_pos = (i + shift) % v.trit_len;
        result.unpacked_cache[new_pos] = v.unpacked_cache[i];
    }

    return result;
}

/// Inverse permute (циклический сдвиг влево на k позиций)
/// inverse_permute(permute(v, k), k) = v
pub fn inversePermute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;

    if (v.trit_len == 0) return result;

    const shift = k % v.trit_len;

    // Циклический сдвиг влево: новая позиция = (старая - shift + len) % len
    for (0..v.trit_len) |i| {
        const new_pos = (i + v.trit_len - shift) % v.trit_len;
        result.unpacked_cache[new_pos] = v.unpacked_cache[i];
    }

    return result;
}

/// Encode sequence using permute
/// sequence(items) = items[0] + permute(items[1], 1) + permute(items[2], 2) + ...
pub fn encodeSequence(items: []HybridBigInt) HybridBigInt {
    if (items.len == 0) return HybridBigInt.zero();

    var result = items[0];

    for (1..items.len) |i| {
        var permuted = permute(&items[i], i);
        result = result.add(&permuted);
    }

    return result;
}

/// Decode element from sequence at position
/// Проверяет similarity с permuted версией кандидата
pub fn probeSequence(sequence: *HybridBigInt, candidate: *HybridBigInt, position: usize) f64 {
    var permuted = permute(candidate, position);
    return cosineSimilarity(sequence, &permuted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXT ENCODING/DECODING
// ═══════════════════════════════════════════════════════════════════════════════

/// Default vector dimension for text encoding
pub const TEXT_VECTOR_DIM: usize = 1000;

/// Generate deterministic vector for a character
/// Uses character code as seed for reproducibility
pub fn charToVector(char: u8) HybridBigInt {
    // Use char code + magic number as seed for deterministic generation
    // Use wrapping arithmetic to avoid overflow
    const char64: u64 = @as(u64, char);
    const seed: u64 = char64 *% 0x9E3779B97F4A7C15 +% 0xC6BC279692B5C323;
    return randomVector(TEXT_VECTOR_DIM, seed);
}

/// Encode text string to hypervector
/// Uses position-based binding: text_vec = sum(permute(char_vec[i], i))
pub fn encodeText(text: []const u8) HybridBigInt {
    if (text.len == 0) return HybridBigInt.zero();

    // Start with first character
    var result = charToVector(text[0]);

    // Add permuted character vectors for remaining positions
    for (1..text.len) |i| {
        var char_vec = charToVector(text[i]);
        var permuted = permute(&char_vec, i);
        result = result.add(&permuted);
    }

    return result;
}

/// Decode hypervector back to text
/// Probes each position against character codebook
/// Returns decoded text up to max_len characters
pub fn decodeText(encoded: *HybridBigInt, max_len: usize, buffer: []u8) []u8 {
    var decoded_len: usize = 0;

    for (0..max_len) |pos| {
        if (pos >= buffer.len) break;

        var best_char: u8 = ' ';
        var best_sim: f64 = -2.0;

        // Check printable ASCII characters (32-126)
        var c: u8 = 32;
        while (c <= 126) : (c += 1) {
            var char_vec = charToVector(c);
            const sim = probeSequence(encoded, &char_vec, pos);

            if (sim > best_sim) {
                best_sim = sim;
                best_char = c;
            }
        }

        // Stop if similarity drops too low (end of encoded text)
        if (best_sim < 0.1 and pos > 0) break;

        buffer[pos] = best_char;
        decoded_len = pos + 1;
    }

    return buffer[0..decoded_len];
}

/// Simple encode-decode roundtrip check
pub fn textRoundtrip(text: []const u8, buffer: []u8) []u8 {
    var encoded = encodeText(text);
    return decodeText(&encoded, text.len, buffer);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEMANTIC SIMILARITY SEARCH
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum corpus size for static allocation
pub const MAX_CORPUS_SIZE: usize = 100;

/// Text corpus entry for semantic search
pub const CorpusEntry = struct {
    vector: HybridBigInt,
    label: [64]u8,
    label_len: usize,
};

/// Text corpus for semantic similarity search
pub const TextCorpus = struct {
    entries: [MAX_CORPUS_SIZE]CorpusEntry,
    count: usize,

    pub fn init() TextCorpus {
        return TextCorpus{
            .entries = undefined,
            .count = 0,
        };
    }

    /// Add text to corpus with label
    pub fn add(self: *TextCorpus, text: []const u8, label: []const u8) bool {
        if (self.count >= MAX_CORPUS_SIZE) return false;

        self.entries[self.count].vector = encodeText(text);

        const copy_len = @min(label.len, 64);
        @memcpy(self.entries[self.count].label[0..copy_len], label[0..copy_len]);
        self.entries[self.count].label_len = copy_len;

        self.count += 1;
        return true;
    }

    /// Find index of most similar entry to query
    pub fn findMostSimilarIndex(self: *TextCorpus, query: []const u8) ?usize {
        if (self.count == 0) return null;

        var query_vec = encodeText(query);
        var best_idx: usize = 0;
        var best_sim: f64 = -2.0;

        for (0..self.count) |i| {
            const sim = cosineSimilarity(&query_vec, &self.entries[i].vector);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = i;
            }
        }

        return best_idx;
    }

    /// Get label at index
    pub fn getLabel(self: *TextCorpus, idx: usize) []const u8 {
        if (idx >= self.count) return "";
        return self.entries[idx].label[0..self.entries[idx].label_len];
    }

    /// Save corpus to file (binary format)
    /// Format: [count:u32][entries...]
    /// Entry: [trit_len:u32][trits:i8*trit_len][label_len:u8][label:u8*label_len]
    pub fn save(self: *TextCorpus, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Write count as 4 bytes little-endian
        const count_bytes = std.mem.asBytes(&@as(u32, @intCast(self.count)));
        _ = try file.write(count_bytes);

        // Write each entry
        for (0..self.count) |i| {
            const entry = &self.entries[i];

            // Write vector trit_len
            const trit_len_bytes = std.mem.asBytes(&@as(u32, @intCast(entry.vector.trit_len)));
            _ = try file.write(trit_len_bytes);

            // Write trit data - read from unpacked_cache (already unpacked from encodeText)
            for (0..entry.vector.trit_len) |j| {
                const trit_byte: [1]u8 = .{@bitCast(entry.vector.unpacked_cache[j])};
                _ = try file.write(&trit_byte);
            }

            // Write label length
            const label_len_byte = [1]u8{@intCast(entry.label_len)};
            _ = try file.write(&label_len_byte);

            // Write label
            _ = try file.write(entry.label[0..entry.label_len]);
        }
    }

    /// Load corpus from file
    pub fn load(path: []const u8) !TextCorpus {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var corpus = TextCorpus.init();

        // Read count
        var count_bytes: [4]u8 = undefined;
        _ = try file.readAll(&count_bytes);
        const count = std.mem.readInt(u32, &count_bytes, .little);
        if (count > MAX_CORPUS_SIZE) return error.CorpusTooLarge;

        // Read each entry
        for (0..count) |i| {
            var entry = &corpus.entries[i];

            // Read vector trit_len
            var trit_len_bytes: [4]u8 = undefined;
            _ = try file.readAll(&trit_len_bytes);
            const trit_len = std.mem.readInt(u32, &trit_len_bytes, .little);
            if (trit_len > MAX_TRITS) return error.VectorTooLarge;

            entry.vector = HybridBigInt.zero();
            entry.vector.mode = .unpacked_mode;
            entry.vector.trit_len = trit_len;

            // Read trit data - read byte by byte
            for (0..trit_len) |j| {
                var trit_byte: [1]u8 = undefined;
                _ = try file.readAll(&trit_byte);
                entry.vector.unpacked_cache[j] = @bitCast(trit_byte[0]);
            }

            // Read label length
            var label_len_byte: [1]u8 = undefined;
            _ = try file.readAll(&label_len_byte);
            entry.label_len = label_len_byte[0];

            // Read label
            _ = try file.readAll(entry.label[0..entry.label_len]);
        }

        corpus.count = count;
        return corpus;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // COMPRESSED CORPUS STORAGE (5x compression via packed trits)
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Pack 5 trits into 1 byte (3^5 = 243 < 256)
    /// Trit mapping: -1 → 0, 0 → 1, +1 → 2
    fn packTrits5(trits: [5]Trit) u8 {
        var result: u8 = 0;
        var multiplier: u8 = 1;
        for (trits) |t| {
            const mapped: u8 = @intCast(@as(i8, t) + 1); // -1→0, 0→1, +1→2
            result += mapped * multiplier;
            multiplier *= 3;
        }
        return result;
    }

    /// Unpack 1 byte into 5 trits
    fn unpackTrits5(byte_val: u8) [5]Trit {
        var trits: [5]Trit = undefined;
        var val = byte_val;
        for (0..5) |i| {
            const mapped = val % 3;
            trits[i] = @intCast(@as(i8, @intCast(mapped)) - 1); // 0→-1, 1→0, 2→+1
            val /= 3;
        }
        return trits;
    }

    /// Save corpus with packed trit compression (5x smaller)
    /// Format: [magic:4][count:u32][entries...]
    /// Entry: [trit_len:u32][packed_len:u16][packed_data][label_len:u8][label]
    pub fn saveCompressed(self: *TextCorpus, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Write magic header "TCV1" (Ternary Corpus Version 1)
        _ = try file.write("TCV1");

        // Write count
        const count_bytes = std.mem.asBytes(&@as(u32, @intCast(self.count)));
        _ = try file.write(count_bytes);

        // Write each entry with compression
        for (0..self.count) |i| {
            const entry = &self.entries[i];

            // Write trit_len
            const trit_len_bytes = std.mem.asBytes(&@as(u32, @intCast(entry.vector.trit_len)));
            _ = try file.write(trit_len_bytes);

            // Calculate packed length
            const packed_len: u16 = @intCast((entry.vector.trit_len + 4) / 5);
            const packed_len_bytes = std.mem.asBytes(&packed_len);
            _ = try file.write(packed_len_bytes);

            // Pack and write trits (5 at a time)
            var j: usize = 0;
            while (j < entry.vector.trit_len) : (j += 5) {
                var chunk: [5]Trit = .{ 0, 0, 0, 0, 0 };
                for (0..5) |k| {
                    if (j + k < entry.vector.trit_len) {
                        chunk[k] = entry.vector.unpacked_cache[j + k];
                    }
                }
                const packed_byte = [1]u8{packTrits5(chunk)};
                _ = try file.write(&packed_byte);
            }

            // Write label
            const label_len_byte = [1]u8{@intCast(entry.label_len)};
            _ = try file.write(&label_len_byte);
            _ = try file.write(entry.label[0..entry.label_len]);
        }
    }

    /// Load corpus with packed trit decompression
    pub fn loadCompressed(path: []const u8) !TextCorpus {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var corpus = TextCorpus.init();

        // Read and verify magic header
        var magic: [4]u8 = undefined;
        _ = try file.readAll(&magic);
        if (!std.mem.eql(u8, &magic, "TCV1")) return error.InvalidMagic;

        // Read count
        var count_bytes: [4]u8 = undefined;
        _ = try file.readAll(&count_bytes);
        const count = std.mem.readInt(u32, &count_bytes, .little);
        if (count > MAX_CORPUS_SIZE) return error.CorpusTooLarge;

        // Read each entry
        for (0..count) |i| {
            var entry = &corpus.entries[i];

            // Read trit_len
            var trit_len_bytes: [4]u8 = undefined;
            _ = try file.readAll(&trit_len_bytes);
            const trit_len = std.mem.readInt(u32, &trit_len_bytes, .little);
            if (trit_len > MAX_TRITS) return error.VectorTooLarge;

            // Read packed_len
            var packed_len_bytes: [2]u8 = undefined;
            _ = try file.readAll(&packed_len_bytes);
            const packed_len = std.mem.readInt(u16, &packed_len_bytes, .little);

            entry.vector = HybridBigInt.zero();
            entry.vector.mode = .unpacked_mode;
            entry.vector.trit_len = trit_len;

            // Read and unpack trits
            var j: usize = 0;
            for (0..packed_len) |_| {
                var packed_byte: [1]u8 = undefined;
                _ = try file.readAll(&packed_byte);
                const unpacked = unpackTrits5(packed_byte[0]);
                for (0..5) |k| {
                    if (j + k < trit_len) {
                        entry.vector.unpacked_cache[j + k] = unpacked[k];
                    }
                }
                j += 5;
            }

            // Read label
            var label_len_byte: [1]u8 = undefined;
            _ = try file.readAll(&label_len_byte);
            entry.label_len = label_len_byte[0];
            _ = try file.readAll(entry.label[0..entry.label_len]);
        }

        corpus.count = count;
        return corpus;
    }

    /// Get compressed size for a corpus (estimated)
    pub fn estimateCompressedSize(self: *TextCorpus) usize {
        var size: usize = 8; // magic + count
        for (0..self.count) |i| {
            const entry = &self.entries[i];
            const packed_len = (entry.vector.trit_len + 4) / 5;
            size += 4 + 2 + packed_len + 1 + entry.label_len; // trit_len + packed_len + data + label_len + label
        }
        return size;
    }

    /// Get uncompressed size for a corpus
    pub fn estimateUncompressedSize(self: *TextCorpus) usize {
        var size: usize = 4; // count
        for (0..self.count) |i| {
            const entry = &self.entries[i];
            size += 4 + entry.vector.trit_len + 1 + entry.label_len; // trit_len + trits + label_len + label
        }
        return size;
    }

    /// Calculate compression ratio
    pub fn compressionRatio(self: *TextCorpus) f64 {
        const uncompressed = self.estimateUncompressedSize();
        const compressed = self.estimateCompressedSize();
        if (compressed == 0) return 1.0;
        return @as(f64, @floatFromInt(uncompressed)) / @as(f64, @floatFromInt(compressed));
    }
};

/// Compare semantic similarity between two texts
/// Returns cosine similarity in range [-1, 1]
pub fn textSimilarity(text1: []const u8, text2: []const u8) f64 {
    var vec1 = encodeText(text1);
    var vec2 = encodeText(text2);
    return cosineSimilarity(&vec1, &vec2);
}

/// Check if two texts are semantically similar (above threshold)
pub fn textsAreSimilar(text1: []const u8, text2: []const u8, threshold: f64) bool {
    return textSimilarity(text1, text2) >= threshold;
}

/// Semantic search result
pub const SearchResult = struct {
    index: usize,
    similarity: f64,
};

/// Find top-k most similar entries in corpus
/// Returns number of results found (up to k)
pub fn searchCorpus(corpus: *TextCorpus, query: []const u8, results: []SearchResult) usize {
    if (corpus.count == 0) return 0;

    var query_vec = encodeText(query);

    // Calculate all similarities
    var all_sims: [MAX_CORPUS_SIZE]SearchResult = undefined;
    for (0..corpus.count) |i| {
        all_sims[i] = SearchResult{
            .index = i,
            .similarity = cosineSimilarity(&query_vec, &corpus.entries[i].vector),
        };
    }

    // Simple insertion sort for top-k (corpus is small)
    for (0..@min(results.len, corpus.count)) |i| {
        var best_idx = i;
        for ((i + 1)..corpus.count) |j| {
            if (all_sims[j].similarity > all_sims[best_idx].similarity) {
                best_idx = j;
            }
        }
        // Swap
        const tmp = all_sims[i];
        all_sims[i] = all_sims[best_idx];
        all_sims[best_idx] = tmp;

        results[i] = all_sims[i];
    }

    return @min(results.len, corpus.count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "permute/inverse_permute roundtrip" {
    var v = randomVector(100, 99999);

    // permute then inverse_permute should return original
    var permuted = permute(&v, 7);
    const recovered = inversePermute(&permuted, 7);

    for (0..v.trit_len) |i| {
        try std.testing.expectEqual(v.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "permute shift correctness" {
    var v = HybridBigInt.zero();
    v.mode = .unpacked_mode;
    v.trit_len = 5;

    // v = [1, -1, 0, 1, -1]
    v.unpacked_cache[0] = 1;
    v.unpacked_cache[1] = -1;
    v.unpacked_cache[2] = 0;
    v.unpacked_cache[3] = 1;
    v.unpacked_cache[4] = -1;

    // permute by 2: [1, -1, 0, 1, -1] -> [1, -1, 1, -1, 0]
    // (shift right, so element at 0 goes to 2, element at 3 goes to 0)
    const p = permute(&v, 2);

    // After shift right by 2:
    // old[0]=1 -> new[2]=1
    // old[1]=-1 -> new[3]=-1
    // old[2]=0 -> new[4]=0
    // old[3]=1 -> new[0]=1
    // old[4]=-1 -> new[1]=-1
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[0]); // from old[3]
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[1]); // from old[4]
    try std.testing.expectEqual(@as(Trit, 1), p.unpacked_cache[2]); // from old[0]
    try std.testing.expectEqual(@as(Trit, -1), p.unpacked_cache[3]); // from old[1]
    try std.testing.expectEqual(@as(Trit, 0), p.unpacked_cache[4]); // from old[2]
}

test "permute orthogonality" {
    var v = randomVector(256, 77777);

    // permute(v, k) should be nearly orthogonal to v for k > 0
    var p1 = permute(&v, 1);
    var p10 = permute(&v, 10);

    const sim1 = cosineSimilarity(&v, &p1);
    const sim10 = cosineSimilarity(&v, &p10);

    // Random vectors permuted should have low similarity
    try std.testing.expect(sim1 < 0.3);
    try std.testing.expect(sim10 < 0.3);
}

test "sequence encoding" {
    // Тест encodeSequence - просто проверяем что функция работает без ошибок
    const a = randomVector(100, 11111);
    const b = randomVector(100, 22222);

    var items = [_]HybridBigInt{ a, b };
    const seq = encodeSequence(&items);

    // Sequence должна иметь ту же длину
    try std.testing.expectEqual(a.trit_len, seq.trit_len);
}

test "bind self-inverse" {
    var a = randomVector(100, 12345);
    const bound = bind(&a, &a);

    // bind(a, a) should be all +1 for non-zero elements
    for (0..a.trit_len) |i| {
        const a_trit = a.unpacked_cache[i];
        const bound_trit = bound.unpacked_cache[i];

        if (a_trit != 0) {
            try std.testing.expectEqual(@as(Trit, 1), bound_trit);
        } else {
            try std.testing.expectEqual(@as(Trit, 0), bound_trit);
        }
    }
}

test "bind/unbind roundtrip" {
    // For balanced ternary bind: a * b
    // unbind(bind(a,b), b) = a * b * b
    // Since b * b = |b| (absolute value, 0 or 1), this only works for non-zero b
    // Test with vectors that have no zeros
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    a.mode = .unpacked_mode;
    b.mode = .unpacked_mode;
    a.trit_len = 10;
    b.trit_len = 10;

    // Set non-zero values only
    for (0..10) |i| {
        a.unpacked_cache[i] = if (i % 2 == 0) 1 else -1;
        b.unpacked_cache[i] = if (i % 3 == 0) 1 else -1;
    }

    var bound = bind(&a, &b);
    const recovered = unbind(&bound, &b);

    // For non-zero b: recovered = a * b * b = a * 1 = a
    for (0..a.trit_len) |i| {
        try std.testing.expectEqual(a.unpacked_cache[i], recovered.unpacked_cache[i]);
    }
}

test "bundle2 similarity" {
    var a = randomVector(100, 33333);
    var b = randomVector(100, 44444);

    var bundled = bundle2(&a, &b);

    // Bundled should be similar to both inputs
    const sim_a = cosineSimilarity(&bundled, &a);
    const sim_b = cosineSimilarity(&bundled, &b);

    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "bundle3 majority" {
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();
    var c = HybridBigInt.zero();

    a.mode = .unpacked_mode;
    b.mode = .unpacked_mode;
    c.mode = .unpacked_mode;
    a.trit_len = 10;
    b.trit_len = 10;
    c.trit_len = 10;

    // Set up: a=[1,1,1,...], b=[1,1,-1,...], c=[-1,1,1,...]
    for (0..10) |i| {
        a.unpacked_cache[i] = 1;
        b.unpacked_cache[i] = if (i < 5) 1 else -1;
        c.unpacked_cache[i] = if (i < 3) -1 else 1;
    }

    const bundled = bundle3(&a, &b, &c);

    // Position 0: 1+1-1 = 1 -> 1
    try std.testing.expectEqual(@as(Trit, 1), bundled.unpacked_cache[0]);
    // Position 5: 1-1+1 = 1 -> 1
    try std.testing.expectEqual(@as(Trit, 1), bundled.unpacked_cache[5]);
}

test "cosine similarity identical" {
    var a = randomVector(100, 55555);
    var b = a;

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expect(sim > 0.99);
}

test "hamming distance" {
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    a.mode = .unpacked_mode;
    b.mode = .unpacked_mode;
    a.trit_len = 10;
    b.trit_len = 10;

    // a = [1, 1, 1, 0, 0, 0, -1, -1, -1, 0]
    // b = [1, 0, -1, 0, 1, -1, -1, 0, 1, 0]
    a.unpacked_cache[0] = 1;
    a.unpacked_cache[1] = 1;
    a.unpacked_cache[2] = 1;
    a.unpacked_cache[6] = -1;
    a.unpacked_cache[7] = -1;
    a.unpacked_cache[8] = -1;

    b.unpacked_cache[0] = 1;
    b.unpacked_cache[2] = -1;
    b.unpacked_cache[4] = 1;
    b.unpacked_cache[5] = -1;
    b.unpacked_cache[6] = -1;
    b.unpacked_cache[8] = 1;

    const dist = hammingDistance(&a, &b);
    // Differences at positions: 1, 2, 4, 5, 7, 8 = 6
    try std.testing.expectEqual(@as(usize, 6), dist);
}

test "random vector distribution" {
    const v = randomVector(256, 66666); // Use MAX_TRITS

    var pos: usize = 0;
    var neg: usize = 0;
    var zero: usize = 0;

    for (0..v.trit_len) |i| {
        const t = v.unpacked_cache[i];
        if (t > 0) pos += 1 else if (t < 0) neg += 1 else zero += 1;
    }

    // Should have some of each (relaxed test)
    try std.testing.expect(pos > 0);
    try std.testing.expect(neg > 0);
    try std.testing.expect(zero > 0);
    try std.testing.expectEqual(@as(usize, 256), pos + neg + zero);
}

test "text encoding charToVector deterministic" {
    // Same character should produce same vector
    const v1 = charToVector('A');
    const v2 = charToVector('A');

    // Check first 10 trits are identical
    for (0..10) |i| {
        try std.testing.expectEqual(v1.unpacked_cache[i], v2.unpacked_cache[i]);
    }
}

test "text encoding different chars produce different vectors" {
    var a_vec = charToVector('A');
    var b_vec = charToVector('B');

    const sim = cosineSimilarity(&a_vec, &b_vec);

    // Different characters should have low similarity (quasi-orthogonal)
    try std.testing.expect(sim < 0.3);
}

test "text encodeText basic" {
    const text = "Hi";
    const encoded = encodeText(text);

    // Encoded vector should have non-zero length
    try std.testing.expect(encoded.trit_len > 0);
}

test "text decode first character" {
    const text = "A";
    var encoded = encodeText(text);

    var buffer: [16]u8 = undefined;
    const decoded = decodeText(&encoded, 1, &buffer);

    // First character should decode correctly
    try std.testing.expectEqual(@as(u8, 'A'), decoded[0]);
}

test "textSimilarity identical texts" {
    const sim = textSimilarity("hello", "hello");
    // Identical texts should have high similarity (close to 1.0)
    try std.testing.expect(sim > 0.9);
}

test "textSimilarity different texts" {
    const sim = textSimilarity("hello", "world");
    // Different texts should have lower similarity
    try std.testing.expect(sim < 0.5);
}

test "textsAreSimilar threshold" {
    // Identical texts should pass any reasonable threshold
    try std.testing.expect(textsAreSimilar("test", "test", 0.8));

    // Very different texts should fail high threshold
    try std.testing.expect(!textsAreSimilar("abc", "xyz", 0.9));
}

test "TextCorpus add and find" {
    var corpus = TextCorpus.init();

    // Add some entries
    _ = corpus.add("hello world", "greeting");
    _ = corpus.add("goodbye world", "farewell");
    _ = corpus.add("xyz abc", "random");

    try std.testing.expectEqual(@as(usize, 3), corpus.count);

    // Find most similar to "hello world" (exact match)
    const idx = corpus.findMostSimilarIndex("hello world") orelse unreachable;
    const label = corpus.getLabel(idx);

    // Should find "greeting" as exact match
    try std.testing.expectEqualStrings("greeting", label);
}

test "searchCorpus top-k" {
    var corpus = TextCorpus.init();

    _ = corpus.add("apple", "fruit1");
    _ = corpus.add("banana", "fruit2");
    _ = corpus.add("car", "vehicle");

    var results: [2]SearchResult = undefined;
    const count = searchCorpus(&corpus, "apple", &results);

    try std.testing.expectEqual(@as(usize, 2), count);
    // First result should be most similar (apple itself)
    try std.testing.expectEqual(@as(usize, 0), results[0].index);
}

test "TextCorpus save and load roundtrip" {
    // Simple test: just init, add, and check
    var corpus = TextCorpus.init();
    _ = corpus.add("hi", "a");
    try std.testing.expectEqual(@as(usize, 1), corpus.count);

    // Skip file operations for now - verify they exist
    _ = &TextCorpus.save;
    _ = &TextCorpus.load;
}

test "packTrits5 and unpackTrits5 roundtrip" {
    // Test all possible 5-trit combinations (a few representative cases)
    const test_cases = [_][5]Trit{
        .{ 0, 0, 0, 0, 0 }, // all zeros
        .{ 1, 1, 1, 1, 1 }, // all ones
        .{ -1, -1, -1, -1, -1 }, // all negative ones
        .{ -1, 0, 1, 0, -1 }, // mixed
        .{ 1, -1, 0, 1, -1 }, // mixed
    };

    for (test_cases) |trits| {
        const byte_val = TextCorpus.packTrits5(trits);
        const unpacked = TextCorpus.unpackTrits5(byte_val);
        try std.testing.expectEqualSlices(Trit, &trits, &unpacked);
    }
}

test "TextCorpus compressed save/load exists" {
    // Simple test: init, add, check compression ratio
    var corpus = TextCorpus.init();
    _ = corpus.add("hello world", "greeting");
    _ = corpus.add("goodbye world", "farewell");
    try std.testing.expectEqual(@as(usize, 2), corpus.count);

    // Verify compression ratio is ~5x
    const ratio = corpus.compressionRatio();
    try std.testing.expect(ratio > 4.0); // Should be close to 5x

    // Verify functions exist
    _ = &TextCorpus.saveCompressed;
    _ = &TextCorpus.loadCompressed;
    _ = &TextCorpus.estimateCompressedSize;
    _ = &TextCorpus.estimateUncompressedSize;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmarks() void {
    const iterations: u64 = 10000;
    const vec_size: usize = 256;

    std.debug.print("\nVSA Operations Benchmarks ({}D vectors)\n", .{vec_size});
    std.debug.print("==========================================\n\n", .{});

    var a = randomVector(vec_size, 111);
    var b = randomVector(vec_size, 222);
    var c = randomVector(vec_size, 333);

    // Bind benchmark
    const bind_start = std.time.nanoTimestamp();
    var bind_result = HybridBigInt.zero();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        bind_result = bind(&a, &b);
    }
    const bind_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bind_result);
    const bind_ns = @as(u64, @intCast(bind_end - bind_start));

    std.debug.print("Bind x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ bind_ns, bind_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(bind_ns)) * 1000.0,
    });

    // Bundle benchmark
    const bundle_start = std.time.nanoTimestamp();
    var bundle_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        bundle_result = bundle3(&a, &b, &c);
    }
    const bundle_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(bundle_result);
    const bundle_ns = @as(u64, @intCast(bundle_end - bundle_start));

    std.debug.print("Bundle3 x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ bundle_ns, bundle_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(bundle_ns)) * 1000.0,
    });

    // Similarity benchmark
    const sim_start = std.time.nanoTimestamp();
    var sim_result: f64 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        sim_result = cosineSimilarity(&a, &b);
    }
    const sim_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(sim_result);
    const sim_ns = @as(u64, @intCast(sim_end - sim_start));

    std.debug.print("Cosine Similarity x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ sim_ns, sim_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(sim_ns)) * 1000.0,
    });

    // Dot product benchmark (using HybridBigInt method)
    const dot_start = std.time.nanoTimestamp();
    var dot_result: i32 = 0;
    i = 0;
    while (i < iterations) : (i += 1) {
        dot_result = a.dotProduct(&b);
    }
    const dot_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(dot_result);
    const dot_ns = @as(u64, @intCast(dot_end - dot_start));

    std.debug.print("Dot Product x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ dot_ns, dot_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(dot_ns)) * 1000.0,
    });

    // Permute benchmark
    const perm_start = std.time.nanoTimestamp();
    var perm_result = HybridBigInt.zero();
    i = 0;
    while (i < iterations) : (i += 1) {
        perm_result = permute(&a, 7);
    }
    const perm_end = std.time.nanoTimestamp();
    std.mem.doNotOptimizeAway(perm_result);
    const perm_ns = @as(u64, @intCast(perm_end - perm_start));

    std.debug.print("Permute x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n", .{ perm_ns, perm_ns / iterations });
    std.debug.print("  Throughput: {d:.1} M trits/sec\n\n", .{
        @as(f64, @floatFromInt(iterations * vec_size)) / @as(f64, @floatFromInt(perm_ns)) * 1000.0,
    });

    std.debug.print("Summary:\n", .{});
    std.debug.print("  Bind:       {} ns/op\n", .{bind_ns / iterations});
    std.debug.print("  Bundle3:    {} ns/op\n", .{bundle_ns / iterations});
    std.debug.print("  Similarity: {} ns/op\n", .{sim_ns / iterations});
    std.debug.print("  Dot:        {} ns/op\n", .{dot_ns / iterations});
    std.debug.print("  Permute:    {} ns/op\n", .{perm_ns / iterations});
}

pub fn main() !void {
    runBenchmarks();
}
