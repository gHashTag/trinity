// ═══════════════════════════════════════════════════════════════════════════
// lexer.zig - Lexical Analysis for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #408: ADT Enum + Exhaustive Match + Pipe
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// All token types for Tri Language
pub const Token = union(enum) {
    // Keywords
    Keyword: Keyword,

    // Identifiers
    Identifier: []const u8,

    // Literals
    IntLiteral: i64,
    FloatLiteral: f64,
    StringLiteral: []const u8,
    CharLiteral: u8,
    BoolLiteral: bool,

    // Operators
    Operator: Operator,

    // Delimiters
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Comma,
    Colon,
    Semicolon,
    Dot,
    DoubleDot, // .. for ranges
    DoubleDotEq, // ..= for inclusive ranges

    // Special
    Pipe: void, // | for guards
    PipeForward: void, // |> for Elixir-style pipe
    Arrow: void, // => for match arms
    DoubleArrow: void, // => for function types
    FatArrow: void, // => for match arms (same as Arrow)
    Equal: void, // =
    EqualEqual: void, // ==
    BangEqual: void, // !=
    Less: void, // <
    LessEqual: void, // <=
    Greater: void, // >
    GreaterEqual: void, // >=

    // Pattern matching
    Wildcard: void, // _
    RangeToEq: void, // ..=

    // End of file
    Eof,

    // Error (invalid token)
    Error: []const u8,
};

/// Keywords in Tri
pub const Keyword = enum(u16) {
    // Control flow
    Fn,
    Return,
    If,
    Else,
    While,
    For,
    Match,

    // Type declarations
    Type,
    Struct,
    Enum,
    Union,

    // Variable bindings
    Let,
    Const,

    // Ternary types
    Trit,
    Trit3,
    Trit9,
    Trit27,

    // Sacred types
    Gf16,
    Tf3,

    // Integer types
    I8,
    I16,
    I32,
    I64,

    // Float types
    F16,
    F32,
    F64,

    // String and boolean
    String,
    Bool,

    // Pipeline
    Pipeline,

    // Modifiers
    Pub,
    Export,
};

/// Operators
pub const Operator = enum(u8) {
    // Arithmetic
    Add, // +
    Sub, // -
    Mul, // *
    Div, // /
    Mod, // %

    // Bitwise
    BitAnd, // &
    BitOr, // |
    BitXor, // ^
    BitNot, // ~
    ShiftLeft, // <<
    ShiftRight, // >>

    // Ternary logic
    TernaryAnd,
    TernaryOr,
    TernaryXor,

    // Sacred
    Dot, // dot product

    // Assignment
    Assign,
};

/// Lexer state
pub const Lexer = struct {
    source: []const u8,
    pos: usize = 0,
    line: usize = 1,
    column: usize = 1,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(source: []const u8, allocator: std.mem.Allocator) Self {
        return .{
            .source = source,
            .allocator = allocator,
        };
    }

    /// Get next token from source
    pub fn next(self: *Self) !Token {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return .Eof;
        }

        const start_col = self.column;
        const c = self.source[self.pos];

        // Check for two-character operators first
        if (self.pos + 1 < self.source.len) {
            const two_chars = self.source[self.pos .. self.pos + 2];
            if (std.mem.eql(u8, two_chars, "..")) {
                self.pos += 2;
                self.column += 2;
                // Check for ..=
                if (self.pos < self.source.len and self.source[self.pos] == '=') {
                    self.pos += 1;
                    self.column += 1;
                    return .DoubleDotEq;
                }
                return .DoubleDot;
            }
            if (std.mem.eql(u8, two_chars, "|>")) {
                self.pos += 2;
                self.column += 2;
                return .PipeForward;
            }
            if (std.mem.eql(u8, two_chars, "==")) {
                self.pos += 2;
                self.column += 2;
                return .EqualEqual;
            }
            if (std.mem.eql(u8, two_chars, "!=")) {
                self.pos += 2;
                self.column += 2;
                return .BangEqual;
            }
            if (std.mem.eql(u8, two_chars, "<=")) {
                self.pos += 2;
                self.column += 2;
                return .LessEqual;
            }
            if (std.mem.eql(u8, two_chars, ">=")) {
                self.pos += 2;
                self.column += 2;
                return .GreaterEqual;
            }
            if (std.mem.eql(u8, two_chars, "<<")) {
                self.pos += 2;
                self.column += 2;
                return Token{ .Operator = .ShiftLeft };
            }
            if (std.mem.eql(u8, two_chars, ">>")) {
                self.pos += 2;
                self.column += 2;
                return Token{ .Operator = .ShiftRight };
            }
            if (std.mem.eql(u8, two_chars, "=>")) {
                self.pos += 2;
                self.column += 2;
                return .Arrow;
            }
            if (std.mem.eql(u8, two_chars, "->")) {
                self.pos += 2;
                self.column += 2;
                return .DoubleArrow;
            }
        }

        // Single character tokens
        switch (c) {
            '(' => {
                self.pos += 1;
                self.column += 1;
                return .LeftParen;
            },
            ')' => {
                self.pos += 1;
                self.column += 1;
                return .RightParen;
            },
            '{' => {
                self.pos += 1;
                self.column += 1;
                return .LeftBrace;
            },
            '}' => {
                self.pos += 1;
                self.column += 1;
                return .RightBrace;
            },
            '[' => {
                self.pos += 1;
                self.column += 1;
                return .LeftBracket;
            },
            ']' => {
                self.pos += 1;
                self.column += 1;
                return .RightBracket;
            },
            ',' => {
                self.pos += 1;
                self.column += 1;
                return .Comma;
            },
            ':' => {
                self.pos += 1;
                self.column += 1;
                return .Colon;
            },
            ';' => {
                self.pos += 1;
                self.column += 1;
                return .Semicolon;
            },
            '.' => {
                self.pos += 1;
                self.column += 1;
                return .Dot;
            },
            '=' => {
                self.pos += 1;
                self.column += 1;
                return .Equal;
            },
            '<' => {
                self.pos += 1;
                self.column += 1;
                return .Less;
            },
            '>' => {
                self.pos += 1;
                self.column += 1;
                return .Greater;
            },
            '+' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .Add };
            },
            '-' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .Sub };
            },
            '*' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .Mul };
            },
            '/' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .Div };
            },
            '%' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .Mod };
            },
            '&' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .BitAnd };
            },
            '|' => {
                self.pos += 1;
                self.column += 1;
                return .Pipe;
            },
            '^' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .BitXor };
            },
            '~' => {
                self.pos += 1;
                self.column += 1;
                return Token{ .Operator = .BitNot };
            },
            '_' => {
                self.pos += 1;
                self.column += 1;
                return .Wildcard;
            },
            else => {},
        }

        // String literal
        if (c == '"') {
            return self.readStringLiteral();
        }

        // Char literal (trit literal)
        if (c == '\'') {
            return self.readCharLiteral();
        }

        // Number literal
        if (c >= '0' and c <= '9') {
            return self.readNumberLiteral(start_col);
        }

        // Identifier or keyword
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_') {
            return self.readIdentifierOrKeyword();
        }

        // Unknown character
        self.pos += 1;
        self.column += 1;
        return Token{ .Error = &[_]u8{c} };
    }

    /// Skip whitespace and comments
    fn skipWhitespace(self: *Self) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            switch (c) {
                ' ', '\t' => {
                    self.pos += 1;
                    self.column += 1;
                },
                '\n' => {
                    self.pos += 1;
                    self.line += 1;
                    self.column = 1;
                },
                '\r' => {
                    self.pos += 1;
                    if (self.pos < self.source.len and self.source[self.pos] == '\n') {
                        self.pos += 1;
                    }
                    self.line += 1;
                    self.column = 1;
                },
                // Line comment (//)
                '/' => {
                    if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '/') {
                        self.pos += 2;
                        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                            self.pos += 1;
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    /// Read string literal
    fn readStringLiteral(self: *Self) !Token {
        std.debug.assert(self.source[self.pos] == '"');
        self.pos += 1; // skip opening quote
        self.column += 1;

        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] != '"') {
            if (self.source[self.pos] == '\\') {
                self.pos += 1; // skip escape char
                self.column += 1;
                if (self.pos >= self.source.len) {
                    return Token{ .Error = "Unterminated string literal" };
                }
            }
            self.pos += 1;
            self.column += 1;
        }

        if (self.pos >= self.source.len) {
            return Token{ .Error = "Unterminated string literal" };
        }

        const value = self.source[start..self.pos];
        self.pos += 1; // skip closing quote
        self.column += 1;

        // Allocate and copy string
        const value_copy = try self.allocator.dupe(u8, value);
        return Token{ .StringLiteral = value_copy };
    }

    /// Read char literal (trit literal)
    fn readCharLiteral(self: *Self) !Token {
        std.debug.assert(self.source[self.pos] == '\'');
        self.pos += 1; // skip opening quote
        self.column += 1;

        if (self.pos >= self.source.len) {
            return Token{ .Error = "Unterminated char literal" };
        }

        const c = self.source[self.pos];
        self.pos += 1;
        self.column += 1;

        if (self.pos >= self.source.len or self.source[self.pos] != '\'') {
            return Token{ .Error = "Unterminated char literal" };
        }

        self.pos += 1; // skip closing quote
        self.column += 1;

        return Token{ .CharLiteral = c };
    }

    /// Read number literal (integer or float)
    fn readNumberLiteral(self: *Self, start_col: usize) !Token {
        const start = self.pos;
        var is_float = false;

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c >= '0' and c <= '9') {
                self.pos += 1;
                self.column += 1;
            } else if (c == '.' and !is_float) {
                // Check for float
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] >= '0' and self.source[self.pos + 1] <= '9') {
                    is_float = true;
                    self.pos += 1;
                    self.column += 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        const num_str = self.source[start..self.pos];
        if (is_float) {
            const value = try std.fmt.parseFloat(f64, num_str);
            return Token{ .FloatLiteral = value };
        } else {
            const value = try std.fmt.parseInt(i64, num_str, 10);
            return Token{ .IntLiteral = value };
        }
    }

    /// Read identifier or keyword
    fn readIdentifierOrKeyword(self: *Self) !Token {
        const start = self.pos;

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_') {
                self.pos += 1;
                self.column += 1;
            } else {
                break;
            }
        }

        const name = self.source[start..self.pos];

        // Check for keywords
        if (isKeyword(name)) |kw| {
            return Token{ .Keyword = kw };
        }

        // Check for boolean literals
        if (std.mem.eql(u8, name, "true")) {
            return Token{ .BoolLiteral = true };
        }
        if (std.mem.eql(u8, name, "false")) {
            return Token{ .BoolLiteral = false };
        }

        // Regular identifier
        const name_copy = try self.allocator.dupe(u8, name);
        return Token{ .Identifier = name_copy };
    }

    /// Check if string is a keyword
    fn isKeyword(name: []const u8) ?Keyword {
        const keywords = struct {
            fn get(str: []const u8) ?Keyword {
                if (std.mem.eql(u8, str, "fn")) return .Fn;
                if (std.mem.eql(u8, str, "return")) return .Return;
                if (std.mem.eql(u8, str, "if")) return .If;
                if (std.mem.eql(u8, str, "else")) return .Else;
                if (std.mem.eql(u8, str, "while")) return .While;
                if (std.mem.eql(u8, str, "for")) return .For;
                if (std.mem.eql(u8, str, "match")) return .Match;
                if (std.mem.eql(u8, str, "type")) return .Type;
                if (std.mem.eql(u8, str, "struct")) return .Struct;
                if (std.mem.eql(u8, str, "enum")) return .Enum;
                if (std.mem.eql(u8, str, "union")) return .Union;
                if (std.mem.eql(u8, str, "let")) return .Let;
                if (std.mem.eql(u8, str, "const")) return .Const;
                if (std.mem.eql(u8, str, "trit")) return .Trit;
                if (std.mem.eql(u8, str, "trit3")) return .Trit3;
                if (std.mem.eql(u8, str, "trit9")) return .Trit9;
                if (std.mem.eql(u8, str, "trit27")) return .Trit27;
                if (std.mem.eql(u8, str, "gf16")) return .Gf16;
                if (std.mem.eql(u8, str, "tf3")) return .Tf3;
                if (std.mem.eql(u8, str, "i8")) return .I8;
                if (std.mem.eql(u8, str, "i16")) return .I16;
                if (std.mem.eql(u8, str, "i32")) return .I32;
                if (std.mem.eql(u8, str, "i64")) return .I64;
                if (std.mem.eql(u8, str, "f16")) return .F16;
                if (std.mem.eql(u8, str, "f32")) return .F32;
                if (std.mem.eql(u8, str, "f64")) return .F64;
                if (std.mem.eql(u8, str, "string")) return .String;
                if (std.mem.eql(u8, str, "bool")) return .Bool;
                if (std.mem.eql(u8, str, "pipeline")) return .Pipeline;
                if (std.mem.eql(u8, str, "pub")) return .Pub;
                if (std.mem.eql(u8, str, "export")) return .Export;
                return null;
            }
        };
        return keywords.get(name);
    }

    /// Get current location for error reporting
    pub fn location(self: *const Self) ast.SourceLocation {
        return .{
            .line = self.line,
            .column = self.column,
        };
    }
};

// Forward declaration for ast dependency
const ast = struct {
    pub const SourceLocation = struct {
        line: usize,
        column: usize,
    };
};
