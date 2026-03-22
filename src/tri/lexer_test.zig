//! Unit tests for Tri lexer
//! v0.3 — Tests tokenize() function

const std = @import("std");
const testing = std.testing;
const Token = @import("token.zig").Token;
const tokenize = @import("lexer.zig").tokenize;

test "tokenize empty input" {
    const tokens = try tokenize(std.testing.allocator, "");
    try testing.expectEqual(@as(usize, tokens.len), 0);
}

test "tokenize trit literals" {
    const tokens = try tokenize(std.testing.allocator, "N O P");
    try testing.expectEqual(tokens.len, 3);
    try testing.expect(tokens[0] == .lit_trit and tokens[0].lit_trit == .neg);
    try testing.expect(tokens[1] == .lit_trit and tokens[1].lit_trit == .zero);
    try testing.expect(tokens[2] == .lit_trit and tokens[2].lit_trit == .pos);
}

test "tokenize tryte literal" {
    const tokens = try tokenize(std.testing.allocator, "NOOOPPPP");
    try testing.expectEqual(tokens.len, 1);
    try testing.expect(tokens[0] == .lit_word);
}

test "tokenize keywords" {
    const tokens = try tokenize(std.testing.allocator, "fn const let match");
    try testing.expectEqual(tokens.len, 4);
    try testing.expect(tokens[0] == .kw_fn);
    try testing.expect(tokens[1] == .kw_const);
    try testing.expect(tokens[2] == .kw_let);
    try testing.expect(tokens[3] == .kw_match);
}

test "tokenize types" {
    const tokens = try tokenize(std.testing.allocator, "trit t3 t9 t27 gf16 tf3 void");
    try testing.expectEqual(tokens.len, 7);
    try testing.expect(tokens[0] == .t_trit);
    try testing.expect(tokens[1] == .t_t3);
    try testing.expect(tokens[2] == .t_t9);
    try testing.expect(tokens[3] == .t_t27);
    try testing.expect(tokens[4] == .t_gf16);
    try testing.expect(tokens[5] == .t_tf3);
    try testing.expect(tokens[6] == .t_void);
}

test "tokenize operators" {
    const tokens = try tokenize(std.testing.allocator, "@@ ++ ~ + - * == != > <");
    try testing.expectEqual(tokens.len, 10);
    try testing.expect(tokens[0] == .op_at_at);
    try testing.expect(tokens[1] == .op_plus_plus);
    try testing.expect(tokens[2] == .op_tilde);
    try testing.expect(tokens[3] == .op_plus);
    try testing.expect(tokens[4] == .op_minus);
    try testing.expect(tokens[5] == .op_times);
    try testing.expect(tokens[6] == .op_eq);
    try testing.expect(tokens[7] == .op_neq);
    try testing.expect(tokens[8] == .op_gt);
}

test "tokenize delimiters" {
    const tokens = try tokenize(std.testing.allocator, "( ) [ ] { } , : => ;");
    try testing.expectEqual(tokens.len, 10);
    try testing.expect(tokens[0] == .l_paren);
    try testing.expect(tokens[1] == .r_paren);
    try testing.expect(tokens[2] == .l_bracket);
    try testing.expect(tokens[3] == .r_bracket);
    try testing.expect(tokens[4] == .l_brace);
    try testing.expect(tokens[5] == .r_brace);
    try testing.expect(tokens[6] == .comma);
    try testing.expect(tokens[7] == .colon);
    try testing.expect(tokens[8] == .arrow);
    try testing.expect(tokens[9] == .semicolon);
}

test "tokenize numeric literals" {
    const tokens = try tokenize(std.testing.allocator, "123 3.14");
    try testing.expectEqual(tokens.len, 2);
    try testing.expect(tokens[0] == .lit_int and tokens[0].lit_int == 123);
    try testing.expect(tokens[1] == .lit_float and tokens[1].lit_float == 3.14);
}

test "tokenize identifiers" {
    const tokens = try tokenize(std.testing.allocator, "my_var foo123 _internal");
    try testing.expectEqual(tokens.len, 3);
}

test "tokenize target attributes" {
    const tokens = try tokenize(std.testing.allocator, "@cpu @fpga @any");
    try testing.expectEqual(tokens.len, 3);
    try testing.expect(tokens[0] == .t_cpu);
    try testing.expect(tokens[1] == .t_fpga);
    try testing.expect(tokens[2] == .t_any);
}

test "tokenize wildcard" {
    const tokens = try tokenize(std.testing.allocator, "_");
    try testing.expectEqual(tokens.len, 1);
    try testing.expect(tokens[0] == .underscore);
}

test "tokenize simple function" {
    const tokens = try tokenize(std.testing.allocator, "fn add(a: trit, b: trit) trit");
    try testing.expectEqual(tokens.len, 12);
    try testing.expect(tokens[0] == .kw_fn);
    try testing.expect(tokens[6] == .colon);
    try testing.expect(tokens[11] == .t_trit);
}

test "tokenize ignores whitespace and newlines" {
    const tokens = try tokenize(std.testing.allocator, "  \n\t  N  \n  ");
    try testing.expectEqual(tokens.len, 1);
    try testing.expect(tokens[0] == .lit_trit and tokens[0].lit_trit == .neg);
}

test "tokenize dot product operator" {
    const tokens = try tokenize(std.testing.allocator, "@@");
    try testing.expectEqual(tokens.len, 1);
    try testing.expect(tokens[0] == .op_at_at);
}
