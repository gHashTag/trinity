// Generated from specs/tri/sacred/sacred_language_model.tri — DO NOT EDIT
// Sacred Language Model: Gematria Tokenizer + Sacred Formula Embeddings
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const math = std.math;

pub const TRINITY: f64 = 3.00000000000000000000;
pub const PI: f64 = 3.14159265358979300000;
pub const PHI: f64 = 1.61803398874989500000;
pub const E_CONST: f64 = 2.71828182845904500000;

pub const EMBEDDING_DIM: usize = 64;
pub const SACRED_FORMULA_DIMS: usize = 5;
pub const KINGDOM_DIMS: usize = 3;
pub const POSITIONAL_DIMS: usize = 8;
pub const PROXIMITY_DIMS: usize = 16;
pub const DISTRIBUTIONAL_DIMS: usize = 32;

pub const GlyphEntry = struct {
    codepoint: u21,
    value: u16,
    kingdom: Kingdom,
};

pub const Kingdom = enum { matter, energy, information };

pub const GLYPH_COUNT: usize = 27;

pub const glyph_table = [_]GlyphEntry{
    .{ .codepoint = 0x2C80, .value = 1, .kingdom = .matter },
    .{ .codepoint = 0x2C82, .value = 2, .kingdom = .matter },
    .{ .codepoint = 0x2C84, .value = 3, .kingdom = .matter },
    .{ .codepoint = 0x2C86, .value = 4, .kingdom = .matter },
    .{ .codepoint = 0x2C88, .value = 5, .kingdom = .matter },
    .{ .codepoint = 0x2C8A, .value = 6, .kingdom = .matter },
    .{ .codepoint = 0x2C8C, .value = 7, .kingdom = .matter },
    .{ .codepoint = 0x2C8E, .value = 8, .kingdom = .matter },
    .{ .codepoint = 0x2C90, .value = 9, .kingdom = .matter },
    .{ .codepoint = 0x2C92, .value = 10, .kingdom = .energy },
    .{ .codepoint = 0x2C94, .value = 20, .kingdom = .energy },
    .{ .codepoint = 0x2C96, .value = 30, .kingdom = .energy },
    .{ .codepoint = 0x2C98, .value = 40, .kingdom = .energy },
    .{ .codepoint = 0x2C9A, .value = 50, .kingdom = .energy },
    .{ .codepoint = 0x2C9C, .value = 60, .kingdom = .energy },
    .{ .codepoint = 0x2C9E, .value = 70, .kingdom = .energy },
    .{ .codepoint = 0x2CA0, .value = 80, .kingdom = .energy },
    .{ .codepoint = 0x2CA2, .value = 90, .kingdom = .energy },
    .{ .codepoint = 0x2CA4, .value = 100, .kingdom = .information },
    .{ .codepoint = 0x2CA6, .value = 200, .kingdom = .information },
    .{ .codepoint = 0x2CA8, .value = 300, .kingdom = .information },
    .{ .codepoint = 0x2CAA, .value = 400, .kingdom = .information },
    .{ .codepoint = 0x2CAC, .value = 500, .kingdom = .information },
    .{ .codepoint = 0x2CAE, .value = 600, .kingdom = .information },
    .{ .codepoint = 0x2CB0, .value = 700, .kingdom = .information },
    .{ .codepoint = 0x03E2, .value = 800, .kingdom = .information },
    .{ .codepoint = 0x03E4, .value = 900, .kingdom = .information },
};

pub const SacredConstant = struct { name: []const u8, symbol: []const u8, value: f64, category: []const u8 };

pub const sacred_constants = [_]SacredConstant{
    .{ .name = "Fine Structure Inverse", .symbol = "ALPHA_INV", .value = 137.036, .category = "particle_physics" },
    .{ .name = "Proton-Electron Ratio", .symbol = "PROTON_ELECTRON", .value = 1836.15267343, .category = "particle_physics" },
    .{ .name = "CHSH Quantum Bound", .symbol = "CHSH", .value = 2.8284271247461903, .category = "quantum" },
    .{ .name = "Weinberg Angle", .symbol = "WEINBERG", .value = 0.23121, .category = "particle_physics" },
    .{ .name = "Hubble Constant", .symbol = "HUBBLE", .value = 67.4, .category = "cosmology" },
    .{ .name = "Dark Energy Fraction", .symbol = "OMEGA_LAMBDA", .value = 0.6889, .category = "cosmology" },
    .{ .name = "Golden Ratio", .symbol = "PHI", .value = 1.618033988749895, .category = "mathematics" },
    .{ .name = "Trinity", .symbol = "TRINITY", .value = 3, .category = "mathematics" },
    .{ .name = "Euler Number", .symbol = "EULER", .value = 2.718281828459045, .category = "mathematics" },
    .{ .name = "Pi", .symbol = "PI", .value = 3.141592653589793, .category = "mathematics" },
    .{ .name = "Planck Reduced", .symbol = "HBAR", .value = 1.054571817e-34, .category = "quantum" },
    .{ .name = "Speed of Light", .symbol = "C", .value = 299792458, .category = "physics" },
    .{ .name = "Boltzmann", .symbol = "K_B", .value = 1.380649e-23, .category = "physics" },
    .{ .name = "Gravitational", .symbol = "G", .value = 6.6743e-11, .category = "physics" },
    .{ .name = "Avogadro", .symbol = "N_A", .value = 6.02214076e23, .category = "physics" },
    .{ .name = "Electron Mass", .symbol = "M_E", .value = 9.1093837015e-31, .category = "particle_physics" },
};

pub const TokenType = enum(u8) {
    coptic_glyph = 1,
    word = 2,
    number = 3,
    symbol = 4,
    separator = 5,
};

pub const Token = struct {
    token_type: TokenType,
    text: []const u8,
    gematria_value: u32,
    glyph_index: ?u8,
};

pub fn glyphLookup(codepoint: u21) ?struct { value: u16, index: u8, kingdom: Kingdom } {
    for (glyph_table, 0..) |entry, i| {
        if (entry.codepoint == codepoint or entry.codepoint + 1 == codepoint) {
            return .{ .value = entry.value, .index = @intCast(i), .kingdom = entry.kingdom };
        }
    }
    return null;
}

pub fn tokenize(allocator: std.mem.Allocator, text: []const u8) ![]Token {
    var tokens: std.ArrayListUnmanaged(Token) = .{};
    var i: usize = 0;

    while (i < text.len) {
        // Skip whitespace
        if (text[i] == ' ' or text[i] == '\t' or text[i] == '\n' or text[i] == '\r') {
            i += 1;
            continue;
        }

        // Try Coptic glyph (multi-byte UTF-8)
        if (text[i] >= 0x80) {
            const cp_len = std.unicode.utf8ByteSequenceLength(text[i]) catch 1;
            if (i + cp_len <= text.len) {
                const cp = std.unicode.utf8Decode(text[i..][0..cp_len]) catch 0xFFFD;
                if (glyphLookup(cp)) |glyph| {
                    try tokens.append(allocator, .{
                        .token_type = .coptic_glyph,
                        .text = text[i..][0..cp_len],
                        .gematria_value = glyph.value,
                        .glyph_index = glyph.index,
                    });
                    i += cp_len;
                    continue;
                }
            }
            i += 1;
            continue;
        }

        // Number
        if (text[i] >= '0' and text[i] <= '9') {
            const start = i;
            while (i < text.len and ((text[i] >= '0' and text[i] <= '9') or text[i] == '.')) : (i += 1) {}
            const num_str = text[start..i];
            const num_val: u32 = std.fmt.parseInt(u32, num_str, 10) catch 0;
            try tokens.append(allocator, .{
                .token_type = .number,
                .text = num_str,
                .gematria_value = num_val,
                .glyph_index = null,
            });
            continue;
        }

        // Symbol
        if (text[i] == '+' or text[i] == '-' or text[i] == '*' or text[i] == '/' or
            text[i] == '^' or text[i] == '=' or text[i] == '(' or text[i] == ')') {
            try tokens.append(allocator, .{
                .token_type = .symbol,
                .text = text[i..][0..1],
                .gematria_value = 0,
                .glyph_index = null,
            });
            i += 1;
            continue;
        }

        // Word (ASCII)
        if ((text[i] >= 'a' and text[i] <= 'z') or (text[i] >= 'A' and text[i] <= 'Z') or text[i] == '_') {
            const start = i;
            while (i < text.len and ((text[i] >= 'a' and text[i] <= 'z') or
                (text[i] >= 'A' and text[i] <= 'Z') or
                (text[i] >= '0' and text[i] <= '9') or text[i] == '_')) : (i += 1) {}
            // Compute word gematria: sum of letter positions (A=1, B=2, ...)
            var word_gem: u32 = 0;
            for (text[start..i]) |ch| {
                if (ch >= 'a' and ch <= 'z') word_gem += (ch - 'a' + 1);
                if (ch >= 'A' and ch <= 'Z') word_gem += (ch - 'A' + 1);
            }
            try tokens.append(allocator, .{
                .token_type = .word,
                .text = text[start..i],
                .gematria_value = word_gem,
                .glyph_index = null,
            });
            continue;
        }

        // Skip unknown
        i += 1;
    }

    return tokens.toOwnedSlice(allocator);
}

pub const FormulaFit = struct {
    n: i8, k: i8, m: i8, p: i8, q: i8,
    computed: f64,
    error_pct: f64,
};

pub fn findBestFormula(target: f64) FormulaFit {
    var best = FormulaFit{ .n = 1, .k = 0, .m = 0, .p = 0, .q = 0, .computed = 3.0, .error_pct = 100.0 };
    if (target == 0) return best;

    var n: i8 = 1;
    while (n <= 9) : (n += 1) {
        var k: i8 = -4;
        while (k <= 4) : (k += 1) {
            var m: i8 = -3;
            while (m <= 3) : (m += 1) {
                var p: i8 = -4;
                while (p <= 4) : (p += 1) {
                    var q: i8 = -3;
                    while (q <= 3) : (q += 1) {
                        const val = @as(f64, @floatFromInt(n)) * powF(TRINITY, k) * powF(PI, m) * powF(PHI, p) * powF(E_CONST, q);
                        const err = @abs(val - target) / @abs(target) * 100.0;
                        if (err < best.error_pct) {
                            best = .{ .n = n, .k = k, .m = m, .p = p, .q = q, .computed = val, .error_pct = err };
                        }
                        // inner loop continues
                    }
                }
            }
        }
    }
    return best;
}

fn powF(base: f64, exp: i8) f64 {
    if (exp == 0) return 1.0;
    var result: f64 = 1.0;
    const abs_exp: u8 = if (exp < 0) @intCast(-exp) else @intCast(exp);
    for (0..abs_exp) |_| result *= base;
    return if (exp < 0) 1.0 / result else result;
}

pub const Embedding = [EMBEDDING_DIM]f64;

pub fn embed(token: Token) Embedding {
    var vec: Embedding = [_]f64{0.0} ** EMBEDDING_DIM;
    const gem_f: f64 = @floatFromInt(token.gematria_value);
    var offset: usize = 0;

    // Dims 0-4: Sacred Formula exponents (normalized)
    if (gem_f > 0) {
        const fit = findBestFormula(gem_f);
        vec[0] = @as(f64, @floatFromInt(fit.n)) / 9.0;
        vec[1] = @as(f64, @floatFromInt(fit.k)) / 4.0;
        vec[2] = @as(f64, @floatFromInt(fit.m)) / 3.0;
        vec[3] = @as(f64, @floatFromInt(fit.p)) / 4.0;
        vec[4] = @as(f64, @floatFromInt(fit.q)) / 3.0;
    }
    offset = SACRED_FORMULA_DIMS;

    // Dims 5-7: Kingdom encoding (one-hot)
    if (token.glyph_index) |idx| {
        if (idx < 9) {
            vec[offset] = 1.0; // matter
        } else if (idx < 18) {
            vec[offset + 1] = 1.0; // energy
        } else {
            vec[offset + 2] = 1.0; // information
        }
    }
    offset += KINGDOM_DIMS;

    // Dims 8-15: Positional (sin/cos of glyph index)
    if (token.glyph_index) |idx| {
        const angle = @as(f64, @floatFromInt(idx)) * 2.0 * math.pi / 27.0;
        var j: usize = 0;
        while (j < POSITIONAL_DIMS / 2) : (j += 1) {
            const freq = @as(f64, @floatFromInt(j + 1));
            vec[offset + j * 2] = @sin(angle * freq);
            vec[offset + j * 2 + 1] = @cos(angle * freq);
        }
    }
    offset += POSITIONAL_DIMS;

    // Dims 16-31: Sacred constant proximity
    if (gem_f > 0) {
        for (sacred_constants, 0..) |c, ci| {
            if (ci >= PROXIMITY_DIMS) break;
            // Proximity = 1 / (1 + |log(gem/constant)|)
            const ratio = if (c.value != 0) gem_f / @abs(c.value) else 0;
            vec[offset + ci] = if (ratio > 0) 1.0 / (1.0 + @abs(@log(ratio))) else 0;
        }
    }
    offset += PROXIMITY_DIMS;

    // Dims 32-63: Hash-based distributional features
    // Deterministic hash of token text → pseudo-random features
    if (token.text.len > 0) {
        var hash: u64 = 0x517cc1b727220a95; // FNV offset basis
        for (token.text) |byte| {
            hash ^= byte;
            hash *%= 0x100000001b3; // FNV prime
        }
        var j: usize = 0;
        while (j < DISTRIBUTIONAL_DIMS and offset + j < EMBEDDING_DIM) : (j += 1) {
            hash ^= hash >> 13;
            hash *%= 0x100000001b3;
            // Map to [-1, 1] range
            vec[offset + j] = @as(f64, @floatFromInt(@as(i64, @bitCast(hash)))) / @as(f64, @floatFromInt(@as(i64, math.maxInt(i64))));
        }
    }

    // L2 normalize
    var norm: f64 = 0;
    for (vec) |v| norm += v * v;
    norm = @sqrt(norm);
    if (norm > 1e-12) {
        for (&vec) |*v| v.* /= norm;
    }

    return vec;
}

pub fn cosineSimilarity(a: Embedding, b: Embedding) f64 {
    var dot: f64 = 0;
    var norm_a: f64 = 0;
    var norm_b: f64 = 0;
    for (a, b) |va, vb| {
        dot += va * vb;
        norm_a += va * va;
        norm_b += vb * vb;
    }
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    return if (denom > 1e-12) dot / denom else 0;
}

test "glyph table has correct count" {
    try std.testing.expectEqual(@as(usize, GLYPH_COUNT), glyph_table.len);
}

test "glyph lookup finds first entry" {
    const result = glyphLookup(glyph_table[0].codepoint);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(glyph_table[0].value, result.?.value);
}

test "tokenize produces tokens" {
    const tokens = try tokenize(std.testing.allocator, "hello 42");
    defer std.testing.allocator.free(tokens);
    try std.testing.expect(tokens.len >= 2);
    try std.testing.expectEqual(TokenType.word, tokens[0].token_type);
    try std.testing.expectEqual(TokenType.number, tokens[1].token_type);
    try std.testing.expectEqual(@as(u32, 42), tokens[1].gematria_value);
}

test "word gematria sums letter positions" {
    const tokens = try tokenize(std.testing.allocator, "abc");
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    // a=1, b=2, c=3 → 6
    try std.testing.expectEqual(@as(u32, 6), tokens[0].gematria_value);
}

test "embedding dimension is correct" {
    const tok = Token{ .token_type = .number, .text = "137", .gematria_value = 137, .glyph_index = null };
    const emb = embed(tok);
    try std.testing.expectEqual(@as(usize, EMBEDDING_DIM), emb.len);
}

test "embedding is normalized" {
    const tok = Token{ .token_type = .number, .text = "42", .gematria_value = 42, .glyph_index = null };
    const emb = embed(tok);
    var norm: f64 = 0;
    for (emb) |v| norm += v * v;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), @sqrt(norm), 1e-6);
}

test "cosine similarity self = 1.0" {
    const tok = Token{ .token_type = .number, .text = "137", .gematria_value = 137, .glyph_index = null };
    const emb = embed(tok);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), cosineSimilarity(emb, emb), 1e-6);
}

test "sacred formula bases verify trinity identity" {
    // φ² + 1/φ² = 3
    try std.testing.expectApproxEqAbs(TRINITY, PHI * PHI + 1.0 / (PHI * PHI), 1e-10);
}
