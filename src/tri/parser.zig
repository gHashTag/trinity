//! Parser — AST builder for Tri language
//! v0.2 — Converts token stream to AST

const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const Node = @import("ast.zig").Node;
const Statement = @import("ast.zig").Statement;
const Expression = @import("ast.zig").Expression;
const FnDecl = @import("ast.zig").FnDecl;
const VarDecl = @import("ast.zig").VarDecl;
const ReturnStmt = @import("ast.zig").ReturnStmt;
const BinOp = @import("ast.zig").BinOp;
const Param = @import("ast.zig").Param;
const Type = @import("ast.zig").Type;
const TritValue = @import("ast.zig").TritValue;

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
    var statements = std.ArrayList(Statement).init(alloc);

    // Parse top-level constructs
    while (p.peek()) |token| {
        switch (token) {
            .semicolon => {
                p.consume(.semicolon);
            },
            .kw_fn => {
                const decl = try p.parseFnDecl();
                try statements.append(.{ .fn_decl = decl });
            },
            .kw_let => {
                const decl = try p.parseVarDecl();
                try statements.append(.{ .var_decl = decl });
            },
            .kw_return => {
                const stmt = try p.parseReturnStmt();
                try statements.append(.{ .return_stmt = stmt });
            },
            .underscore => {
                p.consume(.underscore);
            },
            else => {
                const expr = try p.parseExpression();
                try statements.append(.{ .expression = expr });
            },
        }
    }

    return Node{ .program = try statements.toOwnedSlice() };
}

// Parse return statement: return <expression>;
fn parseReturnStmt(p: *Parser) !ReturnStmt {
    p.consume(.kw_return);

    const token = p.peek();
    if (token == null or token == .semicolon or token == .kw_fn or token == .kw_let) {
        return ReturnStmt{ .value = null };
    }

    const expr = p.parseExpression();
    return ReturnStmt{ .value = expr };
}

// Parse function declaration: fn name(params) -> return_type
fn parseFnDecl(p: *Parser) !FnDecl {
    p.consume(.kw_fn);

    const token = p.peek() orelse return error.ExpectedIdentifier;
    if (token != .identifier) return error.ExpectedIdentifier;
    const name = token.identifier;
    p.consume(token);

    if (p.peek() == .colon) return error.ExpectedColon;
    p.consume(.colon);

    const params = try p.parseParams();
    const return_type = try p.parseType();

    return FnDecl{
        .name = name,
        .params = params,
        .body = &[_]Statement{}, // TODO: Parse function body
        .return_type = return_type,
    };
}

// Parse variable declaration: let name: type = <expr>;
fn parseVarDecl(p: *Parser) !VarDecl {
    p.consume(.kw_let);

    const name_token = p.peek() orelse return error.ExpectedIdentifier;
    if (name_token != .identifier) return error.ExpectedIdentifier;
    const name = name_token.identifier;
    p.consume(name_token);

    if (p.peek() == .colon) return error.ExpectedColon;
    p.consume(.colon);

    const typ = try p.parseType();

    var init: ?Expression = null;
    if (p.peek()) |token| {
        if (token == .op_assign) {
            p.consume(.op_assign);
            init = p.parseExpression();
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
    var params_list = std.ArrayList(Param).init(p.allocator);

    if (p.peek() != .l_paren) return error.ExpectedLparen;
    p.consume(.l_paren);

    // First parameter (required)
    const name1_token = p.peek() orelse return error.ExpectedIdentifier;
    if (name1_token != .identifier) return error.ExpectedIdentifier;
    const name1 = name1_token.identifier;
    p.consume(name1_token);

    const type1 = try p.parseType();
    try params_list.append(.{ .name = name1, .type = type1 });
    p.consume(.colon);

    // Additional parameters
    while (p.peek()) |t| {
        if (t == .comma) {
            p.consume(.comma);
            const name_token = p.peek() orelse return error.ExpectedIdentifier;
            if (name_token != .identifier) return error.ExpectedIdentifier;
            const name = name_token.identifier;
            p.consume(name_token);

            const typ = try p.parseType();
            p.consume(.colon);
            try params_list.append(.{ .name = name, .type = typ });
        } else if (t == .r_paren) {
            break;
        } else {
            break;
        }
    }

    if (p.peek() != .r_paren) return error.ExpectedRparen;
    p.consume(.r_paren);

    return params_list.toOwnedSlice();
}

// Parse type: trit | t3 | t9 | t27 | gf16 | tf3 | void | [N]trit | [N]type
fn parseType(p: *Parser) !Type {
    const token = p.peek() orelse return error.ExpectedType;
    p.consume(token);

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
    return p.parseTerm();
}

fn parseTerm(p: *Parser) !Expression {
    var result: Expression = p.parseFactor();

    while (p.peek()) |op| {
        const op_token = p.peek() orelse break;

        switch (op_token) {
            .op_plus_plus, .op_tilde, .op_plus, .op_minus, .op_times => {
                p.consume(op_token);
                const right = p.parseFactor();
                result = Expression{ .binary_op = .{
                    .op = tokenToBinOp(op_token),
                    .left = result,
                    .right = right,
                }};
            },
            else => {
                break;
            }
        }
    }

    return result;
}

fn parseFactor(p: *Parser) !Expression {
    // Factor: identifier, literal, or parenthesized expression
    const token = p.peek() orelse unreachable;

    if (token == .identifier) {
        p.consume(token);
        return Expression{ .identifier = token.identifier };
    }

    if (token == .lit_trit) {
        p.consume(token);
        return Expression{ .literal_trit = token.lit_trit };
    }

    if (token == .literal_int) {
        p.consume(token);
        return Expression{ .literal_int = token.lit_int };
    }

    if (token == .literal_float) {
        p.consume(token);
        return Expression{ .literal_float = token.lit_float };
    }

    if (token == .l_paren) {
        p.consume(.l_paren);
        const expr = p.parseExpression();
        if (p.peek() != .r_paren) return error.ExpectedRparen;
        p.consume(.r_paren);
        return expr;
    }

    if (token == .underscore) {
        p.consume(.underscore);
        return Expression{ .wildcard = {} };
    }

    return error.UnexpectedToken;
}

// Helper functions
fn peek(p: *Parser) ?Token {
    if (p.pos >= p.tokens.len) return null;
    return p.tokens[p.pos];
}

fn consume(p: *Parser, token: Token) !void {
    if (p.peek()) |actual| {
        if (actual == token) {
            p.pos += 1;
            return;
        }
    }
    return error.UnexpectedToken;
}

fn expect(p: *Parser, expected: Token) !void {
    const actual = p.peek();
    if (actual != expected) return error.UnexpectedToken;
}
