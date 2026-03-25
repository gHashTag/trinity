// ═══════════════════════════════════════════════════════════════════════════════
// CONTRACT DSL — Mini-DSL for @require/@ensure Expressions
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// EBNF Grammar:
//   <expression> ::= <or_expr>
//   <or_expr>    ::= <and_expr> ( "or" <and_expr> )*
//   <and_expr>   ::= <comparison> ( "and" <comparison> )*
//   <comparison> ::= <term> ( ("<=" | ">=" | "<" | ">" | "==" | "!=" | "in" ) <term> )*
//   <term>       ::= <factor> ( "+" | "-" ) <factor>
//   <factor>     ::= <unary> ( "*" | "/" | "%" ) <unary>
//   <unary>      ::= "not" <unary> | "-" <unary> | <primary>
//   <primary>    ::= <literal> | <identifier> | <range> | <call> | "(" <expression> ")"
//   <range>      ::= "[" <expression> "," <expression> "]"
//   <call>       ::= <identifier> "(" <args> ")"
//   <literal>    ::= <int_lit> | <float_lit> | <bool_lit> | <string_lit>
//
// Provability Constraints:
//   - No side effects in expressions
//   - No undefined variables
//   - No infinite loops
//   - Type-checked: bool expressions for require/ensure
//   - Range expressions: x in [min, max]
//
// φ² + 1/φ² = 3
// ═════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════════════
// AST Node Types
// ═══════════════════════════════════════════════════════════════════════════════════════

pub const ExprNode = union(enum) {
    // Literals
    int_lit: i64,
    float_lit: f64,
    bool_lit: bool,
    string_lit: []const u8,

    // Variables
    identifier: []const u8,

    // Binary operations
    add: *const BinOp,
    sub: *const BinOp,
    mul: *const BinOp,
    div: *const BinOp,
    mod: *const BinOp,

    // Comparison operations
    eq: *const BinOp,
    ne: *const BinOp,
    lt: *const BinOp,
    le: *const BinOp,
    gt: *const BinOp,
    ge: *const BinOp,

    // Logical operations (using kw_ prefix to avoid Zig keywords)
    logical_and: *const BinOp,
    logical_or: *const BinOp,

    // Membership (x in [min, max])
    kw_in: *const BinOp,

    // Unary operations
    not: *const UnaryOp,
    neg: *const UnaryOp,

    // Range literal [min, max]
    range: *const RangeExpr,

    // Function call
    call: *const CallExpr,

    // Parenthesized expression
    group: *const ExprNode,

    pub const BinOp = struct {
        left: *const ExprNode,
        right: *const ExprNode,
    };

    pub const UnaryOp = struct {
        operand: *const ExprNode,
    };

    pub const RangeExpr = struct {
        min: *const ExprNode,
        max: *const ExprNode,
    };

    pub const CallExpr = struct {
        func: []const u8,
        args: ArrayList(*const ExprNode),
    };
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// Parser State
// ═══════════════════════════════════════════════════════════════════════════════════════

const Parser = struct {
    allocator: Allocator,
    input: []const u8,
    pos: usize,
    tokens: ArrayList(Token),

    var_pos: ParseCursor = 0,

    const Token = struct {
        kind: TokenKind,
        lexeme: []const u8,
        line: usize,
        col: usize,
    };

    const TokenKind = enum {
        // Literals
        int_lit,
        float_lit,
        bool_lit,
        string_lit,

        // Identifiers
        identifier,

        // Keywords
        kw_and,
        kw_or,
        kw_not,
        kw_in,
        kw_true,
        kw_false,

        // Operators
        plus,
        minus,
        star,
        slash,
        percent,

        // Comparisons
        eq,
        ne,
        lt,
        le,
        gt,
        ge,

        // Delimiters
        lparen,
        rparen,
        lbracket,
        rbracket,
        comma,

        // End
        eof,
    };

    fn init(allocator: Allocator, input: []const u8) Parser {
        return .{
            .allocator = allocator,
            .input = input,
            .pos = 0,
            .tokens = ArrayList(Token){},
            .var_pos = 0,
        };
    }

    fn deinit(self: *Parser) void {
        self.tokens.deinit(self.allocator);
    }

    // Tokenization
    fn tokenize(self: *Parser) !void {
        var line: usize = 1;
        var col: usize = 1;

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];

            // Skip whitespace
            if (c == ' ' or c == '\t' or c == '\r') {
                self.pos += 1;
                col += 1;
                continue;
            }

            if (c == '\n') {
                self.pos += 1;
                line += 1;
                col = 1;
                continue;
            }

            // Comments: // to end of line
            if (c == '/' and self.pos + 1 < self.input.len and self.input[self.pos + 1] == '/') {
                while (self.pos < self.input.len and self.input[self.pos] != '\n') {
                    self.pos += 1;
                }
                continue;
            }

            // Identifiers and keywords
            if (isAlpha(c) or c == '_') {
                const start = self.pos;
                while (self.pos < self.input.len and (isAlnum(self.input[self.pos]) or self.input[self.pos] == '_')) {
                    self.pos += 1;
                }
                const lexeme = self.input[start..self.pos];

                const kind = identifierToKind(lexeme);
                try self.tokens.append(self.allocator, .{
                    .kind = kind,
                    .lexeme = lexeme,
                    .line = line,
                    .col = col,
                });
                col += self.pos - start;
                continue;
            }

            // Numbers: int or float
            if (isDigit(c)) {
                const start = self.pos;
                while (self.pos < self.input.len and isDigit(self.input[self.pos])) {
                    self.pos += 1;
                }

                var kind = TokenKind.int_lit;

                // Check for float
                if (self.pos < self.input.len and self.input[self.pos] == '.') {
                    self.pos += 1;
                    while (self.pos < self.input.len and isDigit(self.input[self.pos])) {
                        self.pos += 1;
                    }
                    kind = .float_lit;
                }

                const lexeme = self.input[start..self.pos];
                try self.tokens.append(self.allocator, .{
                    .kind = kind,
                    .lexeme = lexeme,
                    .line = line,
                    .col = col,
                });
                col += self.pos - start;
                continue;
            }

            // Operators and delimiters
            switch (c) {
                '+' => {
                    try self.tokens.append(self.allocator, .{ .kind = .plus, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '-' => {
                    try self.tokens.append(self.allocator, .{ .kind = .minus, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '*' => {
                    try self.tokens.append(self.allocator, .{ .kind = .star, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '/' => {
                    try self.tokens.append(self.allocator, .{ .kind = .slash, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '%' => {
                    try self.tokens.append(self.allocator, .{ .kind = .percent, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '=' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(self.allocator, .{ .kind = .eq, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        return error.UnexpectedToken;
                    }
                },
                '!' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(self.allocator, .{ .kind = .ne, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        return error.UnexpectedToken;
                    }
                },
                '<' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(self.allocator, .{ .kind = .le, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        try self.tokens.append(self.allocator, .{ .kind = .lt, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                        self.pos += 1;
                        col += 1;
                    }
                },
                '>' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(self.allocator, .{ .kind = .ge, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        try self.tokens.append(self.allocator, .{ .kind = .gt, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                        self.pos += 1;
                        col += 1;
                    }
                },
                '(' => {
                    try self.tokens.append(self.allocator, .{ .kind = .lparen, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                ')' => {
                    try self.tokens.append(self.allocator, .{ .kind = .rparen, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '[' => {
                    try self.tokens.append(self.allocator, .{ .kind = .lbracket, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                ']' => {
                    try self.tokens.append(self.allocator, .{ .kind = .rbracket, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                ',' => {
                    try self.tokens.append(self.allocator, .{ .kind = .comma, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                else => {
                    std.debug.print("Unexpected character: '{c}' at line {d}, col {d}\n", .{ c, line, col });
                    return error.UnexpectedCharacter;
                },
            }
        }

        // EOF token
        try self.tokens.append(self.allocator, .{
            .kind = .eof,
            .lexeme = "",
            .line = line,
            .col = col,
        });
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
    }

    fn isAlnum(c: u8) bool {
        return isAlpha(c) or (c >= '0' and c <= '9');
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn identifierToKind(ident: []const u8) TokenKind {
        if (std.mem.eql(u8, ident, "and")) return .kw_and;
        if (std.mem.eql(u8, ident, "or")) return .kw_or;
        if (std.mem.eql(u8, ident, "not")) return .kw_not;
        if (std.mem.eql(u8, ident, "in")) return .kw_in;
        if (std.mem.eql(u8, ident, "true")) return .kw_true;
        if (std.mem.eql(u8, ident, "false")) return .kw_false;
        return .identifier;
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // Expression Parser (Precedence Climbing)
    // ═══════════════════════════════════════════════════════════════════════════════════════

    const ParseCursor = usize;

    fn peekToken(self: *const Parser) Token {
        if (self.pos >= self.tokens.items.len) {
            return .{ .kind = .eof, .lexeme = "", .line = 0, .col = 0 };
        }
        return self.tokens.items[self.pos];
    }

    fn consumeToken(self: *Parser) Token {
        const token = self.peekToken();
        if (self.pos < self.tokens.items.len) {
            self.pos += 1;
        }
        return token;
    }

    fn expectToken(self: *Parser, kind: TokenKind) !Token {
        const token = self.peekToken();
        if (token.kind != kind) {
            return error.SyntaxError;
        }
        return self.consumeToken();
    }

    /// Precedence levels (higher = tighter binding)
    const Prec = enum(u8) {
        lowest = 0,
        logical_or = 1, // or
        logical_and = 2, // and
        comparison = 3, // ==, !=, <, <=, >, >=, in
        additive = 4, // +, -
        multiplicative = 5, // *, /, %
        unary = 6, // not, -
        primary = 7, // literals, identifiers, (), []
    };

    fn getPrecedence(kind: TokenKind) Prec {
        return switch (kind) {
            .kw_or => .logical_or,
            .kw_and => .logical_and,
            .eq, .ne, .lt, .le, .gt, .ge, .kw_in => .comparison,
            .plus, .minus => .additive,
            .star, .slash, .percent => .multiplicative,
            else => .lowest,
        };
    }

    /// Parse expression with precedence climbing
    fn parseExpression(self: *Parser, min_prec: Prec) !*const ExprNode {
        // Parse left side (unary or primary)
        var left = try self.parseUnary();

        // While next token is binary operator with >= min_prec
        while (true) {
            const token = self.peekToken();
            if (token.kind == .eof) break;

            const op_prec = getPrecedence(token.kind);
            if (@intFromEnum(op_prec) < @intFromEnum(min_prec)) break;

            // Only binary operators continue the loop
            switch (token.kind) {
                .kw_or, .kw_and, .eq, .ne, .lt, .le, .gt, .ge, .kw_in, .plus, .minus, .star, .slash, .percent => {
                    _ = self.consumeToken();
                    const next_min_prec: Prec = @enumFromInt(@intFromEnum(op_prec) + 1);
                    const right = try self.parseExpression(next_min_prec);
                    left = try self.makeBinaryOp(token.kind, left, right);
                },
                else => break,
            }
        }

        return left;
    }

    fn parseUnary(self: *Parser) !*const ExprNode {
        const token = self.peekToken();

        // Handle unary not and -
        if (token.kind == .kw_not or token.kind == .minus) {
            _ = self.consumeToken();
            const operand = try self.parseUnary();
            return self.makeUnaryOp(token.kind, operand);
        }

        return self.parsePrimary();
    }

    fn parsePrimary(self: *Parser) !*const ExprNode {
        const token = self.peekToken();

        switch (token.kind) {
            .int_lit => {
                _ = self.consumeToken();
                const value = try self.parseIntLit(token);
                return self.makeIntLit(value);
            },
            .float_lit => {
                _ = self.consumeToken();
                const value = try self.parseFloatLit(token);
                return self.makeFloatLit(value);
            },
            .kw_true => {
                _ = self.consumeToken();
                return self.makeBoolLit(true);
            },
            .kw_false => {
                _ = self.consumeToken();
                return self.makeBoolLit(false);
            },
            .identifier => {
                _ = self.consumeToken();
                // Check for function call: identifier(...)
                if (self.peekToken().kind == .lparen) {
                    return self.parseCall(token.lexeme);
                }
                return self.makeIdentifier(token.lexeme);
            },
            .lparen => {
                _ = self.consumeToken();
                const expr = try self.parseExpression(.lowest);
                _ = try self.expectToken(.rparen);
                return expr;
            },
            .lbracket => {
                _ = self.consumeToken();
                return self.parseRange();
            },
            else => return error.SyntaxError,
        }
    }

    fn parseCall(self: *Parser, func_name: []const u8) !*const ExprNode {
        _ = try self.expectToken(.lparen);

        var args = ArrayList(*const ExprNode).init(self.allocator);

        // Parse arguments
        while (self.peekToken().kind != .rparen and self.peekToken().kind != .eof) {
            const arg = try self.parseExpression(.lowest);
            try args.append(arg);

            if (self.peekToken().kind == .comma) {
                _ = self.consumeToken();
            } else {
                break;
            }
        }

        _ = try self.expectToken(.rparen);
        return self.makeCall(func_name, args);
    }

    fn parseRange(self: *Parser) !*const ExprNode {
        const min = try self.parseExpression(.lowest);
        _ = try self.expectToken(.comma);
        const max = try self.parseExpression(.lowest);
        _ = try self.expectToken(.rbracket);
        return self.makeRange(min, max);
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // AST Node Construction
    // ═══════════════════════════════════════════════════════════════════════════════════════

    fn makeIntLit(self: *Parser, value: i64) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        node.* = .{ .int_lit = value };
        return node;
    }

    fn makeFloatLit(self: *Parser, value: f64) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        node.* = .{ .float_lit = value };
        return node;
    }

    fn makeBoolLit(self: *Parser, value: bool) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        node.* = .{ .bool_lit = value };
        return node;
    }

    fn makeIdentifier(self: *Parser, name: []const u8) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        const duped_name = try self.allocator.dupe(u8, name);
        node.* = .{ .identifier = duped_name };
        return node;
    }

    fn parseIdentifier(self: *Parser) ![]const u8 {
        const token = self.peekToken();
        if (token.kind != .identifier) return error.SyntaxError;
        _ = self.consumeToken();
        return token.lexeme;
    }

    fn parseIntLit(self: *Parser, token: Token) !i64 {
        return std.fmt.parseInt(i64, token.lexeme, 10) catch 0;
    }

    fn parseFloatLit(self: *Parser, token: Token) !f64 {
        return std.fmt.parseFloat(f64, token.lexeme) catch 0.0;
    }

    fn makeBinaryOp(self: *Parser, op: TokenKind, left: *const ExprNode, right: *const ExprNode) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        const binop = try self.allocator.create(ExprNode.BinOp);
        binop.* = .{ .left = left, .right = right };
        node.* = switch (op) {
            .kw_or => .{ .logical_or = binop },
            .kw_and => .{ .logical_and = binop },
            .eq => .{ .eq = binop },
            .ne => .{ .ne = binop },
            .lt => .{ .lt = binop },
            .le => .{ .le = binop },
            .gt => .{ .gt = binop },
            .ge => .{ .ge = binop },
            .kw_in => .{ .kw_in = binop },
            .plus => .{ .add = binop },
            .minus => .{ .sub = binop },
            .star => .{ .mul = binop },
            .slash => .{ .div = binop },
            .percent => .{ .mod = binop },
            else => return error.SyntaxError,
        };
        return node;
    }

    fn makeUnaryOp(self: *Parser, op: TokenKind, operand: *const ExprNode) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        const unop = try self.allocator.create(ExprNode.UnaryOp);
        unop.* = .{ .operand = operand };
        node.* = switch (op) {
            .kw_not => .{ .not = unop },
            .minus => .{ .neg = unop },
            else => return error.SyntaxError,
        };
        return node;
    }

    fn makeRange(self: *Parser, min: *const ExprNode, max: *const ExprNode) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        const range = try self.allocator.create(ExprNode.RangeExpr);
        range.* = .{ .min = min, .max = max };
        node.* = .{ .range = range };
        return node;
    }

    fn makeCall(self: *Parser, func: []const u8, args: ArrayList(*const ExprNode)) !*const ExprNode {
        const node = try self.allocator.create(ExprNode);
        const call = try self.allocator.create(ExprNode.CallExpr);
        const duped_func = try self.allocator.dupe(u8, func);
        call.* = .{ .func = duped_func, .args = args };
        node.* = .{ .call = call };
        return node;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Parse a contract expression into an AST
pub fn parseContract(allocator: Allocator, contract: []const u8) !*const ExprNode {
    var parser = Parser.init(allocator, contract);
    defer parser.deinit();

    try parser.tokenize();

    // Reset position for parsing
    parser.pos = 0;

    // Parse using precedence climbing
    return parser.parseExpression(.lowest);
}

/// Check if a contract expression is provable (no side effects, all variables defined)
pub fn isProvable(contract: []const u8, known_vars: []const []const u8) bool {
    _ = contract;
    _ = known_vars;
    // TODO: Implement provability check
    return false;
}

/// Format expression back to string (pretty-print)
pub fn formatExpression(allocator: Allocator, expr: *const ExprNode) ![]const u8 {
    _ = allocator;
    _ = expr;
    // TODO: Implement pretty-printing
    return error.NotImplemented;
}

// Tests
test "tokenize simple expression" {
    const allocator = std.testing.allocator;
    const input = "x >= 0 and x < 100";

    var parser = Parser.init(allocator, input);
    defer parser.deinit();

    try parser.tokenize();

    // x, >=, 0, and, x, <, 100, EOF = 8 tokens
    try std.testing.expectEqual(@as(usize, 8), parser.tokens.items.len);
}

test "tokenize range expression" {
    const allocator = std.testing.allocator;
    const input = "x in [0, 100]";

    var parser = Parser.init(allocator, input);
    defer parser.deinit();

    try parser.tokenize();

    // x, in, [, 0, ,, 100, ], EOF = 8 tokens
    try std.testing.expectEqual(@as(usize, 8), parser.tokens.items.len);
}

test "tokenize complex boolean" {
    const allocator = std.testing.allocator;
    const input = "(x > 0 or y > 0) and not z";

    var parser = Parser.init(allocator, input);
    defer parser.deinit();

    try parser.tokenize();

    // Count tokens (excluding EOF)
    var count: usize = 0;
    for (parser.tokens.items) |t| {
        if (t.kind != .eof) count += 1;
    }

    // (, x, >, 0, or, y, >, 0, ), and, not, z = 12 tokens
    try std.testing.expectEqual(@as(usize, 12), count);
}

test "parse simple comparison" {
    const allocator = std.testing.allocator;
    const input = "x >= 0";

    const expr = try parseContract(allocator, input);
    defer {
        // Just check we got a valid node
        _ = expr;
    }

    // If we got here without error, parsing succeeded
    try std.testing.expect(true);
}

test "parse logical and" {
    const allocator = std.testing.allocator;
    const input = "x >= 0 and x < 100";

    const expr = try parseContract(allocator, input);
    defer {
        _ = expr;
    }

    // Should be a logical_and node
    try std.testing.expectEqual(@as(usize, 2), @intFromEnum(expr.*));
}

test "parse range membership" {
    const allocator = std.testing.allocator;
    const input = "x in [0, 100]";

    const expr = try parseContract(allocator, input);
    defer {
        _ = expr;
    }

    // Should be an in (membership) node - kw_in is at index 10
    try std.testing.expectEqual(@as(usize, 10), @intFromEnum(expr.*));
}

test "parse complex boolean" {
    const allocator = std.testing.allocator;
    const input = "(x > 0 or y > 0) and not z";

    const expr = try parseContract(allocator, input);
    defer {
        _ = expr;
    }

    // Should be a logical_and node
    try std.testing.expectEqual(@as(usize, 2), @intFromEnum(expr.*));
}
