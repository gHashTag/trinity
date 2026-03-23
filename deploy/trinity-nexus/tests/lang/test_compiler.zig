// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NEXUS - Language Frontend Tests
// Lexer, Parser, Type System, Codegen
// V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN TYPES (mirrors lang/src/lexer.zig)
// ═══════════════════════════════════════════════════════════════════════════════

const TokenKind = enum {
    // Literals
    integer,
    float_lit,
    string_lit,
    trit_lit,
    // Keywords
    kw_fn,
    kw_let,
    kw_const,
    kw_if,
    kw_else,
    kw_return,
    kw_trit,
    kw_vector,
    kw_bind,
    kw_bundle,
    kw_permute,
    // Operators
    plus,
    minus,
    star,
    slash,
    eq,
    eq_eq,
    bang_eq,
    // Delimiters
    lparen,
    rparen,
    lbrace,
    rbrace,
    semicolon,
    colon,
    // Special
    eof,
    invalid,
};

const Token = struct {
    kind: TokenKind,
    start: usize,
    len: usize,
    line: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MINIMAL LEXER for testing
// ═══════════════════════════════════════════════════════════════════════════════

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn classifyKeyword(src: []const u8) TokenKind {
    const keywords = .{
        .{ "fn", TokenKind.kw_fn },
        .{ "let", TokenKind.kw_let },
        .{ "const", TokenKind.kw_const },
        .{ "if", TokenKind.kw_if },
        .{ "else", TokenKind.kw_else },
        .{ "return", TokenKind.kw_return },
        .{ "trit", TokenKind.kw_trit },
        .{ "vector", TokenKind.kw_vector },
        .{ "bind", TokenKind.kw_bind },
        .{ "bundle", TokenKind.kw_bundle },
        .{ "permute", TokenKind.kw_permute },
    };
    inline for (keywords) |kw| {
        if (std.mem.eql(u8, src, kw[0])) return kw[1];
    }
    return .string_lit; // identifier fallback
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Token Classification
// ═══════════════════════════════════════════════════════════════════════════════

test "classify vibee keywords" {
    try std.testing.expectEqual(TokenKind.kw_fn, classifyKeyword("fn"));
    try std.testing.expectEqual(TokenKind.kw_let, classifyKeyword("let"));
    try std.testing.expectEqual(TokenKind.kw_trit, classifyKeyword("trit"));
    try std.testing.expectEqual(TokenKind.kw_vector, classifyKeyword("vector"));
    try std.testing.expectEqual(TokenKind.kw_bind, classifyKeyword("bind"));
    try std.testing.expectEqual(TokenKind.kw_bundle, classifyKeyword("bundle"));
    try std.testing.expectEqual(TokenKind.kw_permute, classifyKeyword("permute"));
}

test "non-keywords return identifier" {
    try std.testing.expectEqual(TokenKind.string_lit, classifyKeyword("foo"));
    try std.testing.expectEqual(TokenKind.string_lit, classifyKeyword("myVar"));
    try std.testing.expectEqual(TokenKind.string_lit, classifyKeyword("trinity_value"));
}

test "keyword matching is exact" {
    // "functions" should NOT match "fn"
    try std.testing.expectEqual(TokenKind.string_lit, classifyKeyword("functions"));
    try std.testing.expectEqual(TokenKind.string_lit, classifyKeyword("letter"));
    try std.testing.expectEqual(TokenKind.string_lit, classifyKeyword("constant"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Character Classification
// ═══════════════════════════════════════════════════════════════════════════════

test "digit classification" {
    for ('0'..'9' + 1) |c| {
        try std.testing.expect(isDigit(@intCast(c)));
    }
    try std.testing.expect(!isDigit('a'));
    try std.testing.expect(!isDigit(' '));
    try std.testing.expect(!isDigit('+'));
}

test "alpha classification" {
    try std.testing.expect(isAlpha('a'));
    try std.testing.expect(isAlpha('z'));
    try std.testing.expect(isAlpha('A'));
    try std.testing.expect(isAlpha('Z'));
    try std.testing.expect(isAlpha('_'));
    try std.testing.expect(!isAlpha('0'));
    try std.testing.expect(!isAlpha(' '));
    try std.testing.expect(!isAlpha('+'));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Token Structure
// ═══════════════════════════════════════════════════════════════════════════════

test "token struct layout" {
    const tok = Token{
        .kind = .kw_bind,
        .start = 10,
        .len = 4,
        .line = 3,
    };
    try std.testing.expectEqual(TokenKind.kw_bind, tok.kind);
    try std.testing.expectEqual(@as(usize, 10), tok.start);
    try std.testing.expectEqual(@as(usize, 4), tok.len);
    try std.testing.expectEqual(@as(u32, 3), tok.line);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS: Type System
// ═══════════════════════════════════════════════════════════════════════════════

const TrinityType = enum {
    t_trit,
    t_int,
    t_float,
    t_vector,
    t_string,
    t_void,
    t_error,
};

fn typeCompatible(from: TrinityType, to: TrinityType) bool {
    if (from == to) return true;
    // int can widen to float
    if (from == .t_int and to == .t_float) return true;
    // trit can widen to int
    if (from == .t_trit and to == .t_int) return true;
    // trit can widen to float (transitive)
    if (from == .t_trit and to == .t_float) return true;
    return false;
}

test "type identity compatibility" {
    const types = [_]TrinityType{ .t_trit, .t_int, .t_float, .t_vector, .t_string, .t_void };
    for (types) |t| {
        try std.testing.expect(typeCompatible(t, t));
    }
}

test "trit widens to int and float" {
    try std.testing.expect(typeCompatible(.t_trit, .t_int));
    try std.testing.expect(typeCompatible(.t_trit, .t_float));
}

test "int widens to float" {
    try std.testing.expect(typeCompatible(.t_int, .t_float));
}

test "narrowing is rejected" {
    try std.testing.expect(!typeCompatible(.t_float, .t_int));
    try std.testing.expect(!typeCompatible(.t_int, .t_trit));
    try std.testing.expect(!typeCompatible(.t_vector, .t_int));
}
