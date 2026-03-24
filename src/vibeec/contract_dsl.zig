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

    // Logical operations
    and: *const BinOp,
    or: *const BinOp,

    // Membership (x in [min, max])
    in: *const BinOp,

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
            .tokens = ArrayList(Token).init(allocator),
        };
    }

    fn deinit(self: *Parser) void {
        self.tokens.deinit();
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
                try self.tokens.append(.{
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
                try self.tokens.append(.{
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
                    try self.tokens.append(.{ .kind = .plus, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '-' => {
                    try self.tokens.append(.{ .kind = .minus, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '*' => {
                    try self.tokens.append(.{ .kind = .star, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '/' => {
                    try self.tokens.append(.{ .kind = .slash, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '%' => {
                    try self.tokens.append(.{ .kind = .percent, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '=' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(.{ .kind = .eq, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        return error.UnexpectedToken;
                    }
                },
                '!' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(.{ .kind = .ne, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        return error.UnexpectedToken;
                    }
                },
                '<' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(.{ .kind = .le, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        try self.tokens.append(.{ .kind = .lt, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                        self.pos += 1;
                        col += 1;
                    }
                },
                '>' => {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == '=') {
                        try self.tokens.append(.{ .kind = .ge, .lexeme = self.input[self.pos .. self.pos + 2], .line = line, .col = col });
                        self.pos += 2;
                        col += 2;
                    } else {
                        try self.tokens.append(.{ .kind = .gt, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                        self.pos += 1;
                        col += 1;
                    }
                },
                '(' => {
                    try self.tokens.append(.{ .kind = .lparen, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                ')' => {
                    try self.tokens.append(.{ .kind = .rparen, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                '[' => {
                    try self.tokens.append(.{ .kind = .lbracket, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                ']' => {
                    try self.tokens.append(.{ .kind = .rbracket, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
                    self.pos += 1;
                    col += 1;
                },
                ',' => {
                    try self.tokens.append(.{ .kind = .comma, .lexeme = self.input[self.pos .. self.pos + 1], .line = line, .col = col });
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
        try self.tokens.append(.{
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
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Parse a contract expression into an AST
pub fn parseContract(allocator: Allocator, contract: []const u8) !*const ExprNode {
    var parser = Parser.init(allocator, contract);
    defer parser.deinit();

    try parser.tokenize();

    // For now, return a placeholder
    _ = parser;
    return error.NotImplemented;
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

    try std.testing.expectEqual(@as(usize, 9), parser.tokens.items.len);
}

test "tokenize range expression" {
    const allocator = std.testing.allocator;
    const input = "x in [0, 100]";

    var parser = Parser.init(allocator, input);
    defer parser.deinit();

    try parser.tokenize();

    try std.testing.expectEqual(@as(usize, 7), parser.tokens.items.len);
}

test "tokenize complex boolean" {
    const allocator = std.testing.allocator;
    const input = "(x > 0 or y > 0) and not z";

    var parser = Parser.init(allocator, input);
    defer parser.deinit();

    try parser.tokenize();

    // Count tokens
    var count: usize = 0;
    for (parser.tokens.items) |t| {
        if (t.kind != .eof) count += 1;
    }

    try std.testing.expectEqual(@as(usize, 11), count);
}
