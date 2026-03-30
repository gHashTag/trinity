//! Strand III: Language & Hardware Bridge
//!
//! TRI-27 compiler component or VSA operations for Trinity S³AI.
//!
//! Parser — AST builder for Tri language
//! v1.0 — Full statement parsing including function bodies

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
const MatchExpr = @import("ast.zig").MatchExpr;
const MatchArm = @import("ast.zig").MatchArm;
const Pattern = @import("ast.zig").Pattern;

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
            .semicolon => {
                try consume(p, .semicolon);
                return ReturnStmt{ .value = null };
            },
            .kw_fn, .kw_let => {
                // No value expression
                try consume(p, .semicolon);
                return ReturnStmt{ .value = null };
            },
            else => {
                const expr = try parseExpression(p);
                try consume(p, .semicolon);
                return ReturnStmt{ .value = expr };
            },
        }
    }

    try consume(p, .semicolon);
    return ReturnStmt{ .value = null };
}

// Parse function declaration: fn name(params) -> return_type { body }
fn parseFnDecl(p: *Parser) !FnDecl {
    try consume(p, .kw_fn);

    const name_token = peek(p) orelse return error.ExpectedIdentifier;
    const name = switch (name_token) {
        .identifier => |id| id,
        else => return error.ExpectedIdentifier,
    };
    try consume(p, name_token);

    try consume(p, .colon);

    const params = try parseParams(p);
    const return_type = try parseType(p);

    // Parse function body
    const body = try parseBlock(p);

    return FnDecl{
        .name = name,
        .params = params,
        .body = body,
        .return_type = return_type,
    };
}

// Parse block statement: { stmt1; stmt2; ... }
fn parseBlock(p: *Parser) ![]Statement {
    var statements = std.ArrayList(Statement).init(p.allocator);

    try consume(p, .l_brace);

    while (peek(p)) |token| {
        if (token == .r_brace) break;

        switch (token) {
            .semicolon => {
                try consume(p, .semicolon);
            },
            .kw_fn => {
                const decl = try parseFnDecl(p);
                try statements.append(p.allocator, .{ .fn_decl = decl });
            },
            .kw_let => {
                const decl = try parseVarDecl(p);
                try statements.append(p.allocator, .{ .var_decl = decl });
            },
            .kw_return => {
                const stmt = try parseReturnStmt(p);
                try statements.append(p.allocator, .{ .return_stmt = stmt });
            },
            .kw_if => {
                const if_stmt = try parseIfStmt(p);
                try statements.append(p.allocator, .{ .expression = if_stmt });
            },
            .kw_match => {
                const match_expr = try parseMatchExpr(p);
                try statements.append(p.allocator, .{ .match_expr = match_expr });
            },
            .kw_while => {
                const while_stmt = try parseWhileStmt(p);
                try statements.append(p.allocator, .{ .expression = while_stmt });
            },
            .underscore => {
                try consume(p, .underscore);
            },
            else => {
                const expr = try parseExpression(p);
                // Expect semicolon after expression statement
                if (peek(p) == .semicolon) {
                    try consume(p, .semicolon);
                }
                try statements.append(p.allocator, .{ .expression = expr });
            },
        }
    }

    try consume(p, .r_brace);

    return statements.toOwnedSlice(p.allocator);
}

// Parse if statement: if <expr> <block> else <block>?
fn parseIfStmt(p: *Parser) !Expression {
    try consume(p, .kw_if);

    const condition = try parseExpression(p);

    const then_block = try parseBlock(p);

    var else_expr: ?Expression = null;
    if (peek(p) == .kw_else) {
        try consume(p, .kw_else);

        if (peek(p) == .kw_if) {
            // else if
            else_expr = try parseIfStmt(p);
        } else {
            // else block
            const else_block = try parseBlock(p);
            // Convert block to expression (return last statement or void)
            else_expr = Expression{ .literal_int = 0 }; // Placeholder
        }
    }

    // Build if-else as a call expression for now
    // In a full implementation, this would be a proper IfExpr node
    _ = else_expr;
    return condition;
}

// Parse while statement: while <expr> <block>
fn parseWhileStmt(p: *Parser) !Expression {
    try consume(p, .kw_while);

    const condition = try parseExpression(p);
    _ = try parseBlock(p);

    // Return condition for now
    // In a full implementation, this would be a proper WhileStmt node
    return condition;
}

// Parse match expression: match <expr> { <arms> }
fn parseMatchExpr(p: *Parser) !MatchExpr {
    try consume(p, .kw_match);

    const value = try parseExpression(p);

    try consume(p, .l_brace);

    var arms = std.ArrayList(MatchArm).init(p.allocator);

    while (peek(p)) |token| {
        if (token == .r_brace) break;

        // Parse pattern: <pattern> => <block>
        const pattern = try parsePattern(p);

        try consume(p, .op_eq); // =>

        const arm_body = try parseBlock(p);
        const arm = MatchArm{
            .pattern = pattern,
            .body = arm_body,
        };
        try arms.append(arm);
    }

    try consume(p, .r_brace);

    return MatchExpr{
        .value = value,
        .arms = try arms.toOwnedSlice(p.allocator),
    };
}

// Parse match pattern: literal | identifier | wildcard
fn parsePattern(p: *Parser) !Pattern {
    const token = peek(p) orelse return error.UnexpectedToken;

    return switch (token) {
        .lit_trit => |tv| {
            try consume(p, .lit_trit);
            return Pattern{ .literal_trit = tv };
        },
        .underscore => {
            try consume(p, .underscore);
            return Pattern{ .wildcard = {} };
        },
        .identifier => |id| {
            try consume(p, .identifier);
            return Pattern{ .identifier = id };
        },
        else => return error.UnexpectedToken,
    };
}

// Parse variable declaration: let name: type = <expr>;
fn parseVarDecl(p: *Parser) !VarDecl {
    try consume(p, .kw_let);

    const name_token = peek(p) orelse return error.ExpectedIdentifier;
    const name = switch (name_token) {
        .identifier => |id| id,
        else => return error.ExpectedIdentifier,
    };
    try consume(p, name_token);

    try consume(p, .colon);

    const typ = try parseType(p);

    var init: ?Expression = null;
    if (peek(p)) |token| {
        if (token == .op_assign) {
            try consume(p, .op_assign);
            init = try parseExpression(p);
            try consume(p, .semicolon);
        } else if (token == .semicolon) {
            try consume(p, .semicolon);
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

    // Check for empty parameter list
    if (peek(p) == .r_paren) {
        try consume(p, .r_paren);
        return params_list.toOwnedSlice(p.allocator);
    }

    // First parameter
    const name1_token = peek(p) orelse return error.ExpectedIdentifier;
    const name1 = switch (name1_token) {
        .identifier => |id| id,
        else => return error.ExpectedIdentifier,
    };
    try consume(p, name1_token);

    try consume(p, .colon);
    const type1 = try parseType(p);
    try params_list.append(p.allocator, .{ .name = name1, .type = type1 });

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

                try consume(p, .colon);
                const typ = try parseType(p);
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

    // Check for array type [N]type
    if (token == .l_bracket) {
        try consume(p, .l_bracket);

        const size_token = peek(p) orelse return error.ExpectedType;
        const size = switch (size_token) {
            .lit_int => |ival| ival,
            else => return error.ExpectedArraySize,
        };
        try consume(p, size_token);

        try consume(p, .r_bracket);

        const elem_type = try parseBaseType(p);

        // Allocate element type on heap
        const elem_ptr = try p.allocator.create(Type);
        elem_ptr.* = elem_type;

        return Type{ .array = .{
            .size = @intCast(size),
            .elem = elem_ptr,
        } };
    }

    try consume(p, token);
    return parseBaseTypeFromToken(token);
}

fn parseBaseType(p: *Parser) !Type {
    const token = peek(p) orelse return error.ExpectedType;
    try consume(p, token);
    return parseBaseTypeFromToken(token);
}

fn parseBaseTypeFromToken(token: Token) !Type {
    return switch (token) {
        .t_trit => Type{ .t_trit = {} },
        .t_t3 => Type{ .t_t3 = {} },
        .t_t9 => Type{ .t_t9 = {} },
        .t_t27 => Type{ .t_t27 = {} },
        .t_gf16 => Type{ .t_gf16 = {} },
        .t_tf3 => Type{ .t_tf3 = {} },
        .t_void => Type{ .t_void = {} },
        else => error.UnexpectedType,
    };
}

// Parse expression (left op right)
fn parseExpression(p: *Parser) !Expression {
    return parseAssignment(p);
}

// Parse assignment: identifier = expr
fn parseAssignment(p: *Parser) !Expression {
    const left = try parseTerm(p);

    if (peek(p) == .op_assign) {
        try consume(p, .op_assign);
        const right = try parseAssignment(p);

        // Return binary op with assignment
        const left_ptr = try p.allocator.create(Expression);
        left_ptr.* = left;
        const right_ptr = try p.allocator.create(Expression);
        right_ptr.* = right;

        return Expression{
            .binary_op = .{
                .op = .eq, // Use eq for assignment
                .left = left_ptr,
                .right = right_ptr,
            },
        };
    }

    return left;
}

fn parseTerm(p: *Parser) !Expression {
    var result: Expression = try parseFactor(p);

    while (peek(p)) |op| {
        const op_token = op;

        switch (op_token) {
            .op_plus_plus, .op_tilde, .op_plus, .op_minus, .op_times => {
                try consume(p, op_token);
                const right = try parseFactor(p);

                const left_ptr = try p.allocator.create(Expression);
                left_ptr.* = result;
                const right_ptr = try p.allocator.create(Expression);
                right_ptr.* = right;

                result = Expression{ .binary_op = .{
                    .op = tokenToBinOp(op_token),
                    .left = left_ptr,
                    .right = right_ptr,
                } };
            },
            .op_eq, .op_neq, .op_gt, .op_lt => {
                try consume(p, op_token);
                const right = try parseFactor(p);

                const left_ptr = try p.allocator.create(Expression);
                left_ptr.* = result;
                const right_ptr = try p.allocator.create(Expression);
                right_ptr.* = right;

                result = Expression{ .binary_op = .{
                    .op = tokenToBinOp(op_token),
                    .left = left_ptr,
                    .right = right_ptr,
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
    const token = peek(p) orelse return error.UnexpectedToken;

    return switch (token) {
        .identifier => |id| {
            try consume(p, .identifier);

            // Check for function call
            if (peek(p) == .l_paren) {
                try consume(p, .l_paren);

                var args = std.ArrayList(Expression).init(p.allocator);

                while (peek(p)) |t| {
                    if (t == .r_paren) break;
                    const arg = try parseExpression(p);
                    try args.append(arg);

                    if (peek(p) == .comma) {
                        try consume(p, .comma);
                    }
                }

                try consume(p, .r_paren);

                return Expression{
                    .call = .{
                        .func = id,
                        .args = try args.toOwnedSlice(p.allocator),
                    },
                };
            }

            return Expression{ .identifier = id };
        },
        .lit_trit => |tv| {
            try consume(p, .lit_trit);
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

// φ² + 1/φ² = 3 | TRINITY
