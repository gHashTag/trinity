//! Strand III: Language \& Hardware Bridge
//!
//! TRI-27 compiler component or VSA operations for Trinity S³AI.
//!

//! Lexer — Tokenizer for Tri language
//! v0.8 — Converts source text to token stream

const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
};

pub fn tokenize(alloc: Allocator, source: []const u8) ![]Token {
    var lexer = Lexer{ .source = source, .pos = 0 };

    // Allocate token array (initial capacity 256 to avoid repeated allocations)
    var tokens = try std.ArrayList(Token).initCapacity(alloc, 256);

    while (lexer.pos < lexer.source.len) {
        const ch = lexer.source[lexer.pos];
        switch (ch) {
            ' ', '\t', '\r' => lexer.pos += 1,
            '\n' => lexer.pos += 1,
            '(' => {
                try tokens.append(alloc, .l_paren);
                lexer.pos += 1;
            },
            ')' => {
                try tokens.append(alloc, .r_paren);
                lexer.pos += 1;
            },
            '[' => {
                try tokens.append(alloc, .l_bracket);
                lexer.pos += 1;
            },
            ']' => {
                try tokens.append(alloc, .r_bracket);
                lexer.pos += 1;
            },
            '{' => {
                try tokens.append(alloc, .l_brace);
                lexer.pos += 1;
            },
            '}' => {
                try tokens.append(alloc, .r_brace);
                lexer.pos += 1;
            },
            ',' => {
                try tokens.append(alloc, .comma);
                lexer.pos += 1;
            },
            ':' => {
                try tokens.append(alloc, .colon);
                lexer.pos += 1;
            },
            ';' => {
                try tokens.append(alloc, .semicolon);
                lexer.pos += 1;
            },
            '_' => {
                try tokens.append(alloc, .underscore);
                lexer.pos += 1;
            },
            '@' => {
                try lexAtAt(&lexer, alloc, &tokens);
            },
            '+' => {
                try lexPlus(&lexer, alloc, &tokens);
            },
            '~' => {
                try tokens.append(alloc, .op_tilde);
                lexer.pos += 1;
            },
            '-' => {
                try tokens.append(alloc, .op_minus);
                lexer.pos += 1;
            },
            '*' => {
                try tokens.append(alloc, .op_times);
                lexer.pos += 1;
            },
            '=' => {
                try lexEq(&lexer, alloc, &tokens);
                lexer.pos += 1;
            },
            '!' => {
                try lexNeq(&lexer, alloc, &tokens);
                lexer.pos += 1;
            },
            '>' => {
                try tokens.append(alloc, .op_gt);
                lexer.pos += 1;
            },
            '<' => {
                try tokens.append(alloc, .op_lt);
                lexer.pos += 1;
            },
            else => {
                if (isDigit(ch)) {
                    const num = try lexNumber(&lexer);
                    try tokens.append(alloc, num);
                } else if (isAlpha(ch) or ch == '_' or ch == '$') {
                    const ident = try lexIdent(&lexer);
                    try tokens.append(alloc, ident);
                } else return error.InvalidChar;
            },
        }
    }

    return tokens.toOwnedSlice(alloc);
}

fn lexAtAt(lexer: *Lexer, alloc: Allocator, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < lexer.source.len and lexer.source[lexer.pos] == '@') {
        lexer.pos += 1;
        try tokens.append(alloc, .op_at_at);
        return;
    } else if (lexer.pos < lexer.source.len and isAlpha(lexer.source[lexer.pos])) {
        const attr = try lexAttribute(lexer);
        try tokens.append(alloc, attr);
    } else {
        // Single '@' without following character is invalid
        return error.InvalidChar;
    }
}

fn lexAttribute(lexer: *Lexer) !Token {
    const start = lexer.pos;
    // Read while characters are valid for attribute (alpha, digit, or underscore)
    while (lexer.pos < lexer.source.len) {
        const nc = lexer.source[lexer.pos];
        if (isAlpha(nc) or isDigit(nc) or nc == '_') {
            lexer.pos += 1;
        } else {
            break;
        }
    }

    const attr = lexer.source[start..lexer.pos];
    if (std.mem.eql(u8, attr, "cpu")) return .t_cpu;
    if (std.mem.eql(u8, attr, "fpga")) return .t_fpga;
    if (std.mem.eql(u8, attr, "any")) return .t_any;

    return error.UnknownAttribute;
}

fn lexPlus(lexer: *Lexer, alloc: Allocator, tokens: *std.ArrayList(Token)) !void {
    // Check for ++ (double plus)
    const next_pos = lexer.pos + 1;
    if (next_pos < lexer.source.len and lexer.source[next_pos] == '+') {
        // Found ++, add op_plus_plus token and advance past both characters
        try tokens.append(alloc, .op_plus_plus);
        lexer.pos += 2;
        return;
    }
    // Add + token and advance past the character
    try tokens.append(alloc, .op_plus);
    lexer.pos += 1;
}

fn lexEq(lexer: *Lexer, alloc: Allocator, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < lexer.source.len) {
        const next = lexer.source[lexer.pos];
        if (next == '=') {
            lexer.pos += 2;
            if (lexer.pos < lexer.source.len and lexer.source[lexer.pos] == '>') {
                lexer.pos += 1;
                try tokens.append(alloc, .arrow);
                return;
            }
        }
    }
    try tokens.append(alloc, .op_assign);
}

fn lexNeq(lexer: *Lexer, alloc: Allocator, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < lexer.source.len and lexer.source[lexer.pos] == '=') {
        lexer.pos += 2;
        try tokens.append(alloc, .op_neq);
        return;
    }
    return error.InvalidChar;
}

fn lexNumber(lexer: *Lexer) !Token {
    const start = lexer.pos;
    var has_dot = false;

    while (lexer.pos < lexer.source.len) {
        const nc = lexer.source[lexer.pos];
        if (nc == '.') {
            if (has_dot) return error.InvalidNumber;
            has_dot = true;
        } else if (!isDigit(nc)) break;
        lexer.pos += 1;
    }

    const s = lexer.source[start..lexer.pos];
    if (has_dot) {
        const val = std.fmt.parseFloat(f64, s) catch return error.InvalidNumber;
        return Token{ .lit_float = val };
    }
    const val = std.fmt.parseInt(i64, s, 10) catch return error.InvalidNumber;
    return Token{ .lit_int = val };
}

fn lexIdent(lexer: *Lexer) !Token {
    const start = lexer.pos;
    while (lexer.pos < lexer.source.len) {
        const nc = lexer.source[lexer.pos];
        if (isAlpha(nc) or isDigit(nc) or nc == '_') {
            lexer.pos += 1;
        } else break;
    }

    const s = lexer.source[start..lexer.pos];
    return identToToken(s);
}

fn identToToken(s: []const u8) Token {
    // Types - check FIRST (void is a keyword in most languages)
    if (std.mem.eql(u8, s, "trit")) return .t_trit;
    if (std.mem.eql(u8, s, "t3")) return .t_t3;
    if (std.mem.eql(u8, s, "t9")) return .t_t9;
    if (std.mem.eql(u8, s, "t27")) return .t_t27;
    if (std.mem.eql(u8, s, "gf16")) return .t_gf16;
    if (std.mem.eql(u8, s, "tf3")) return .t_tf3;
    if (std.mem.eql(u8, s, "void")) return .t_void;

    // Keywords (check AFTER types, void is special - keep as keyword)
    if (std.mem.eql(u8, s, "fn")) return .kw_fn;
    if (std.mem.eql(u8, s, "const")) return .kw_const;
    if (std.mem.eql(u8, s, "let")) return .kw_let;
    if (std.mem.eql(u8, s, "match")) return .kw_match;
    if (std.mem.eql(u8, s, "loop")) return .kw_loop;
    if (std.mem.eql(u8, s, "return")) return .kw_return;
    if (std.mem.eql(u8, s, "pub")) return .kw_pub;
    if (std.mem.eql(u8, s, "type")) return .kw_type;
    if (std.mem.eql(u8, s, "struct")) return .kw_struct;

    // Trit literals: N (neg), O (zero), P (pos)
    if (std.mem.eql(u8, s, "N")) return Token{ .lit_trit = .neg };
    if (std.mem.eql(u8, s, "O")) return Token{ .lit_trit = .zero };
    if (std.mem.eql(u8, s, "P")) return Token{ .lit_trit = .pos };

    // Tryte literal (word of 9 trits like NOOOPPPP)
    if (s.len == 9 and isTryteLiteral(s)) {
        return Token{ .lit_word = s };
    }

    return Token{ .identifier = s };
}

fn isTryteLiteral(s: []const u8) bool {
    for (s) |c| {
        if (c != 'N' and c != 'O' and c != 'P') return false;
    }
    return true;
}

inline fn isAlpha(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
}

inline fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}
