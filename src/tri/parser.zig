//! Strand III: Language \& Hardware Bridge
//!
//! TRI-27 compiler component or VSA operations for Trinity S³AI.
//!
//! Parser — AST builder for Tri language
//! v0.2 — Converts token stream to AST

const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const TritValue = @import("token.zig").TritValue;
const Node = @import("ast.zig").Node;
const Statement = @import("ast.zig").Statement;
const Expression = @import("ast.zig").Expression;
const FnDecl = @import("ast.zig").FnDecl;
const VarDecl = @import("ast.zig").VarDecl;
const ReturnStmt = @import("ast.zig").ReturnStmt;
const BinOp = @import("ast.zig").BinOp;
const Param = @import("ast.zig").Param;
const Type = @import("ast.zig").Type;

// Map token types to BinOp enum values
fn tokenToBinOp(token: Token) BinOp {
    return switch (token) {
        .op_at_at => BinOp.at_at,
        .op_plus_plus => BinOp.plus_plus,
        .op_tilde => BinOp.tilde,
        .op_plus => BinOp.plus,
        .op_minus => BinOp.minus,
        .op_times => BinOp.times,
        .op_eq => BinOp.eq,
        .op_neq => BinOp.neq,
        .op_gt => BinOp.gt,
        .op_lt => BinOp.lt,
        else => unreachable,
    };
}

pub const Parser = struct {
    tokens: []Token,
    pos: usize,
    allocator: Allocator,
};

pub fn parse(alloc: Allocator, tokens: []Token) !Node {
    var p = Parser{ .tokens = tokens, .pos = 0, .allocator = alloc };
    var statements = try std.ArrayList(Statement).initCapacity(alloc, 256);

    // Parse top-level constructs
    while (peek(&p)) |token| {
        switch (token) {
            .semicolon => {
                try consume(&p, .semicolon);
            },
            .kw_fn => {
                const decl = try parseFnDecl(&p);
                try statements.append(alloc, .{ .fn_decl = decl });
            },
            .kw_let => {
                const decl = try parseVarDecl(&p);
                try statements.append(alloc, .{ .var_decl = decl });
            },
            .kw_return => {
                const stmt = try parseReturnStmt(&p);
                try statements.append(alloc, .{ .return_stmt = stmt });
            },
            .underscore => {
                try consume(&p, .underscore);
            },
            else => {
                const expr = try parseExpression(&p);
                try statements.append(alloc, .{ .expression = expr });
            },
        }
    }

    return Node{ .program = try statements.toOwnedSlice(alloc) };
}

// Parse return statement: return <expression>;
fn parseReturnStmt(p: *Parser) !ReturnStmt {
    try consume(p, .kw_return);

    const token = peek(p);
    if (token) |actual| {
        switch (actual) {
            .null => return ReturnStmt{ .value = null },
            .semicolon, .kw_fn, .kw_let => {
                // No value expression
                return ReturnStmt{ .value = null };
            },
        }
    }

    const expr = try parseExpression(p);
    return ReturnStmt{ .value = expr };
}

// Parse function declaration: fn name(params) -> return_type
fn parseFnDecl(p: *Parser) !FnDecl {
    try consume(p, .kw_fn);

    const token = peek(p) orelse return error.ExpectedIdentifier;
    if (token) |name_token| {
        switch (name_token) {
            .identifier => |id| {
                try consume(p, name_token);
                const name = id;
            },
            else => return error.ExpectedIdentifier,
        }
    }

    if (peek(p)) |actual| {
        if (actual == .colon) return error.ExpectedColon;
    }
    try consume(p, .colon);

    const params = try parseParams(p);
    const return_type = try parseType(p);

    return FnDecl{
        .name = name,
        .params = params,
        .body = &[_]Statement{}, // TODO: Parse function body
        .return_type = return_type,
    };
}

// Parse variable declaration: let name: type = <expr>;
fn parseVarDecl(p: *Parser) !VarDecl {
    try consume(p, .kw_let);

    if (peek(p)) |name_token| {
        if (name_token == .identifier) {
            const name = name_token.identifier;
            try consume(p, name_token);
        } else return error.ExpectedIdentifier;
    }

    if (peek(p)) |actual| {
        if (actual == .colon) return error.ExpectedColon;
    }
    try consume(p, .colon);

    const typ = try parseType(p);

    var init: ?Expression = null;
    if (peek(p)) |token| {
        if (token == .op_assign) {
            try consume(p, .op_assign);
            init = parseExpression(p);
        }
    }

    return VarDecl{
        .name = name,
        .type = typ,
        .init = init,
    };
}

// Parse parameters: (param1: type1, param2: type2)
fn parseParams(p: *Parser) ![]Param {
    var params_list = try std.ArrayList(Param).initCapacity(p.allocator, 16);

    try consume(p, .l_paren);

    // First parameter (required)
    const name1_token = peek(p) orelse return error.ExpectedIdentifier;
    const name1 = switch (name1_token) {
        .identifier => |id| id,
        else => return error.ExpectedIdentifier,
    };
    try consume(p, name1_token);

    const type1 = try parseType(p);
    try params_list.append(p.allocator, .{ .name = name1, .type = type1 });
    try consume(p, .colon);

    // Additional parameters
    while (peek(p)) |t| {
        switch (t) {
            .comma => {
                try consume(p, .comma);
                const name_token = peek(p) orelse return error.ExpectedIdentifier;
                const name = switch (name_token) {
                    .identifier => |id| id,
                    else => return error.ExpectedIdentifier,
                };
                try consume(p, name_token);

                const typ = try parseType(p);
                try consume(p, .colon);
                try params_list.append(p.allocator, .{ .name = name, .type = typ });
            },
            .r_paren => break,
            else => break,
        }
    }

    try consume(p, .r_paren);

    return params_list.toOwnedSlice(p.allocator);
}

// Parse type: trit | t3 | t9 | t27 | gf16 | tf3 | void | [N]trit | [N]type
fn parseType(p: *Parser) !Type {
    const token = peek(p) orelse return error.ExpectedType;
    try consume(p, token);

    return switch (token) {
        .t_trit => Type.t_trit,
        .t_t3 => Type.t_t3,
        .t_t9 => Type.t_t9,
        .t_t27 => Type.t_t27,
        .t_gf16 => Type.t_gf16,
        .t_tf3 => Type.t_tf3,
        .t_void => Type.t_void,
        else => error.UnexpectedType,
    };
}

// Parse expression (left op right)
fn parseExpression(p: *Parser) !Expression {
    return parseTerm(p);
}

fn parseTerm(p: *Parser) !Expression {
    var result: Expression = parseFactor(p);

    while (peek(p)) |op| {
        const op_token = op;

        switch (op_token) {
            .op_plus_plus, .op_tilde, .op_plus, .op_minus, .op_times => {
                try consume(p, op_token);
                const right = parseFactor(p);
                result = Expression{ .binary_op = .{
                    .op = tokenToBinOp(op_token),
                    .left = result,
                    .right = right,
                } };
            },
            else => {
                break;
            },
        }
    }

    return result;
}

fn parseFactor(p: *Parser) !Expression {
    // Factor: identifier, literal, or parenthesized expression
    const token = peek(p) orelse return error.UnexpectedToken;

    return switch (token) {
        .identifier => |id| {
            consume(p, .identifier);
            return Expression{ .identifier = id };
        },
        .lit_trit => |tv| {
            consume(p, .lit_trit);
            return Expression{ .literal_trit = tv };
        },
        .lit_int => |ival| {
            try consume(p, .lit_int);
            return Expression{ .literal_int = ival };
        },
        .lit_float => |fval| {
            try consume(p, .lit_float);
            return Expression{ .literal_float = fval };
        },
        .l_paren => {
            try consume(p, .l_paren);
            const expr = try parseExpression(p);
            if (peek(p) != .r_paren) return error.ExpectedRparen;
            try consume(p, .r_paren);
            return expr;
        },
        .underscore => {
            try consume(p, .underscore);
            return Expression{ .wildcard = {} };
        },
        else => return error.UnexpectedToken,
    };
}

// Helper functions
fn peek(p: *Parser) ?Token {
    if (p.pos >= p.tokens.len) return null;
    return p.tokens[p.pos];
}

fn consume(p: *Parser, token: Token) !void {
    if (peek(p)) |actual| {
        if (std.mem.eql(u8, @tagName(actual), @tagName(token))) {
            p.pos += 1;
            return;
        }
    }
    return error.UnexpectedToken;
}

fn expect(p: *Parser, expected: Token) !void {
    const actual = peek(p);
    if (actual != expected) return error.UnexpectedToken;
}
