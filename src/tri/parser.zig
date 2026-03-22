//! Parser — AST builder for Tri language
//! v0.1 — Converts token stream to AST

const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const Node = @import("ast.zig").Node;
const Statement = @import("ast.zig").Statement;
const Expression = @import("ast.zig").Expression;

pub const Parser = struct {
    tokens: []Token,
    pos: usize,
};

pub fn parse(tokens: []Token) !Node {
    var p = Parser{ .tokens = tokens, .pos = 0 };

    var statements = std.ArrayList(Statement).init(p.tokens.allocator);

    while (p.peek()) |token| {
        switch (token) {
            .semicolon => {
                p.consume(token);
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
                try statements.append(.{ .expression = stmt });
            },
            .underscore => {
                p.consume(token);
            },
            .identifier => {
                // For now, just consume identifier as expression
                const ident = try p.parseIdentifier();
                try statements.append(.{ .expression = ident });
            },
            else => return error.UnexpectedToken;
        }
    }

    return Node{ .program = try statements.toOwnedSlice() };
}

// Parse function declaration
fn parseFnDecl(p: *Parser) !Statement.FnDecl {
    p.consume(.kw_fn);

    const name = try p.parseIdentifier();
    if (p.peek() == .colon) return error.ExpectedColon;
    p.consume(.colon);

    const params = try p.parseParams();
    const return_type = try p.parseType();

    if (p.peek() == .l_paren) {
        p.consume(.l_paren);
        while (p.peek()) |t| : (p.consume(t)) {
            if (t == .r_paren) break;
        }
        p.consume(.r_paren);
    } else return error.ExpectedLparen;
    }

    return Statement{ .fn_decl = .{
        .name = name,
        .params = params,
        .return_type = return_type,
    }};
}

// Parse variable declaration
fn parseVarDecl(p: *Parser) !Statement.VarDecl {
    p.consume(.kw_let);

    const name = try p.parseIdentifier();
    if (p.peek() == .colon) return error.ExpectedColon;
    p.consume(.colon);

    const init = p.parseOptionalInit();

    return Statement{ .var_decl = .{
        .name = name,
        .type = init,
        .init = init,
    }};
}

// Parse return statement
fn parseReturnStmt(p: *Parser) !Statement.Return {
    p.consume(.kw_return);

    const value = p.parseOptionalExpression();

    if (p.peek() == .semicolon) return error.ExpectedSemicolon;
    p.consume(.semicolon);

    return Statement{ .return_stmt = .{ .value = value }};
}

// Parse parameters
fn parseParams(p: *Parser) ![]Param {
    var params = std.ArrayList(Param).init(p.tokens.allocator);

    if (p.peek() == .l_paren) return error.ExpectedLparen;
    p.consume(.l_paren);

    while (p.peek()) |t| : (p.consume(t)) {
        if (t == .r_paren) break;
        if (t == .colon) {
            const name = try p.parseIdentifier();
            const type = try p.parseType();

            p.consume(.colon);
            try params.append(.{ .name = name, .type = type });

            if (p.peek() == .comma) {
                p.consume(.comma);
            } else return error.ExpectedComma;
        }
    }

    p.consume(.r_paren);
    return try params.toOwnedSlice();
}

// Parse type
fn parseType(p: *Parser) !Type {
    p.consumeIdentifier(); // Returns Token.identifier

    if (std.mem.eql(u8, "trit")) return .t_trit;
    if (std.mem.eql(u8, "t3")) return .t_t3;
    if (std.mem.eql(u8, "t9")) return .t_t9;
    if (std.mem.eql(u8, "t27")) return .t_t27;
    if (std.mem.eql(u8, "gf16")) return .t_gf16;
    if (std.mem.eql(u8, "tf3")) return .t_tf3;
    if (std.mem.eql(u8, "void")) return .t_void;

    return error.UnexpectedType;
}

fn parseIdentifier(p: *Parser) ![]const u8 {
    const start = p.pos;

    while (p.peek()) |ch| : (p.consume()) {
        if (!isAlpha(ch) and !isDigit(ch) and ch != '_') break;
    }

    return p.tokens.items[start..p.pos];
}

// Parse optional expression (right side of = or :)
fn parseOptionalExpression(p: *Parser) !Expression {
    if (p.peek()) == null) return error.ExpectedExpression;

    const left = try parseExpression();
    if (p.peek() == .op_question) return Expression{ .identifier = "left" };
    p.consume(.op_question);

    if (p.peek() != null) {
        const right = try parseExpression();
        return Expression{ .binary_op = .{
            .op = .op_plus_plus,
            .left = left,
            .right = right,
        }};
    }

    return Expression{ .binary_op = .{
        .op = .op_plus,
        .left = left,
        .right = right,
    }};
}

// Parse simple expression (no binary for now)
fn parseExpression(p: *Parser) !Expression {
    if (p.peek() == null) return error.ExpectedExpression;

    return p.parseTerm();
}

fn parseTerm(p: *Parser) !Expression {
    const token = p.peek().?;
    if (token == .identifier) {
        p.consume(token);
        return Expression{ .identifier = p.tokens.items[p.tokens.len - 1] };
    }

    // Handle literals
    if (token == .lit_trit) {
        p.consume(token);
        const value = token.lit_trit;
        return Expression{ .literal_trit = value };
    }

    if (token == .literal_int) {
        p.consume(token);
        const value = token.lit_int;
        return Expression{ .literal_int = value };
    }

    if (token == .literal_float) {
        p.consume(token);
        const value = token.lit_float;
        return Expression{ .literal_float = value };
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
