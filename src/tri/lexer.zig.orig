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

    // Allocate token array (maximum 256 tokens to avoid repeated allocations)
    var tokens = std.ArrayList(Token).initCapacity(alloc, 256);

    while (lexer.pos < source.len) {
        const ch = source[lexer.pos];
        switch (ch) {
            ' ', '\t', '\r' => {},
            '\n' => {},
            '(' => try tokens.append(.l_paren),
            ')' => try tokens.append(.r_paren),
            '[' => try tokens.append(.l_bracket),
            ']' => try tokens.append(.r_bracket),
            '{' => try tokens.append(.l_brace),
            '}' => try tokens.append(.r_brace),
            ',' => try tokens.append(.comma),
            ':' => try tokens.append(.colon),
            ';' => try tokens.append(.semicolon),
            '_' => try tokens.append(.underscore),
            '@' => try lexAtAt(&lexer, &tokens),
            '+' => try lexPlus(&lexer, &tokens),
            '~' => try tokens.append(.op_tilde),
            '-' => try tokens.append(.op_minus),
            '*' => try tokens.append(.op_times),
            '=' => try lexEq(&lexer, &tokens),
            '!' => try lexNeq(&lexer, &tokens),
            '>' => try tokens.append(.op_gt),
            '<' => try tokens.append(.op_lt),
            else => {
                if (isDigit(ch)) {
                    const num = try lexNumber(&lexer);
                    try tokens.append(num);
                } else if (isAlpha(ch) or ch == '_' or ch == '$') {
                    const ident = try lexIdent(&lexer);
                    try tokens.append(ident);
                } else return error.InvalidChar;
            },
        }
    }

    return tokens.toOwnedSlice();
}

fn lexAtAt(lexer: *Lexer, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < source.len and source[lexer.pos] == '@') {
        lexer.pos += 1;
        try tokens.append(.op_at_at);
        return;
    } else if (lexer.pos < source.len and isAlpha(source[lexer.pos])) {
        const attr = try lexAttribute(lexer);
        try tokens.append(attr);
    }
}

fn lexAttribute(lexer: *Lexer) !Token {
    const start = lexer.pos + 1;
    while (lexer.pos < source.len) {
        const nc = source[lexer.pos];
        if (!isAlpha(nc) and !isDigit(nc) and nc != '_') {
            lexer.pos += 1;
        } else break;
    }

    const attr = source[start..lexer.pos];
    if (std.mem.eql(u8, attr, "cpu")) return .t_cpu;
    if (std.mem.eql(u8, attr, "fpga")) return .t_fpga;
    if (std.mem.eql(u8, attr, "any")) return .t_any;

    return error.UnknownAttribute;
}

fn lexPlus(lexer: *Lexer, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < source.len and source[lexer.pos] == '+') {
        lexer.pos += 2;
        try tokens.append(.op_plus_plus);
        return;
    }
    try tokens.append(.op_plus);
}

fn lexEq(lexer: *Lexer, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < source.len) {
        const next = source[lexer.pos];
        if (next == '=') {
            lexer.pos += 2;
            if (lexer.pos < source.len and source[lexer.pos] == '>') {
                lexer.pos += 1;
                try tokens.append(.arrow);
                return;
            }
        }
    }
    try tokens.append(.op_assign);
}

fn lexNeq(lexer: *Lexer, tokens: *std.ArrayList(Token)) !void {
    lexer.pos += 1;
    if (lexer.pos < source.len and source[lexer.pos] == '=') {
        lexer.pos += 2;
        try tokens.append(.op_neq);
        return;
    }
    return error.InvalidChar;
}

fn lexNumber(lexer: *Lexer) !Token {
    const start = lexer.pos;
    var has_dot = false;

    while (lexer.pos < source.len) {
        const nc = source[lexer.pos];
        if (nc == '.') {
            if (has_dot) return error.InvalidNumber;
            has_dot = true;
        } else if (!isDigit(nc)) break;
        lexer.pos += 1;
    }

    const s = source[start..lexer.pos];
    if (has_dot) {
        const val = std.fmt.parseFloat(f64, s) catch return error.InvalidNumber;
        return Token{ .lit_float = val };
    }
    const val = std.fmt.parseInt(i64, s, 10) catch return error.InvalidNumber;
    return Token{ .lit_int = val };
}

fn lexIdent(lexer: *Lexer) !Token {
    const start = lexer.pos;
    while (lexer.pos < source.len) {
        const nc = source[lexer.pos];
        if (isAlpha(nc) or isDigit(nc) or nc == '_') {
            lexer.pos += 1;
        } else break;
    }

    const s = source[start..lexer.pos];
    return identToToken(s);
}

fn identToToken(s: []const u8) Token {
    if (std.mem.eql(u8, s, "fn")) return .kw_fn;
    if (std.mem.eql(u8, s, "const")) return .kw_const;
    if (std.mem.eql(u8, s, "let")) return .kw_let;
    if (std.mem.eql(u8, s, "match")) return .kw_match;
    if (std.mem.eql(u8, s, "loop")) return .kw_loop;
    if (std.mem.eql(u8, s, "return")) return .kw_return;
    if (std.mem.eql(u8, s, "pub")) return .kw_pub;
    if (std.mem.eql(u8, s, "type")) return .kw_type;
    if (std.mem.eql(u8, s, "struct")) return .kw_struct;
    if (std.mem.eql(u8, s, "void")) return .kw_void;

    if (std.mem.eql(u8, s, "trit")) return .t_trit;
    if (std.mem.eql(u8, s, "t3")) return .t_t3;
    if (std.mem.eql(u8, s, "t9")) return .t_t9;
    if (std.mem.eql(u8, s, "t27")) return .t_t27;
    if (std.mem.eql(u8, s, "gf16")) return .t_gf16;
    if (std.mem.eql(u8, s, "tf3")) return .t_gf16;
}

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
