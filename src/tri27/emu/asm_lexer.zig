// @origin(spec:tri_asm.tri) @regen(manual-impl)
// TRI-27 ASSEMBLER LEXER — Minimal lexer for .tasm files
//
// Tokenizes .tasm source into structured tokens for parsing.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TokenType = enum {
    LabelDef,
    LabelRef,
    Mnemonic,
    Register,
    Immediate,
    Comma,
    EOL,
    EOF,
    Comment,
    Unknown,
};

pub const Token = struct {
    type: TokenType,
    text: []const u8,
    line: u32,
    column: u32,
};

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: u32 = 1,
    column: u32 = 1,
    tokens: std.ArrayList(Token),
    allocator: Allocator,

    pub fn init(allocator: Allocator, source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .pos = 0,
            .tokens = std.ArrayList(Token).initCapacity(allocator, 128) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn tokenize(self: *Lexer) ![]Token {
        while (self.pos < self.source.len) {
            try self.nextToken();
        }

        try self.tokens.append(self.allocator, Token{
            .type = .EOF,
            .text = "",
            .line = self.line,
            .column = self.column,
        });

        return self.tokens.toOwnedSlice(self.allocator);
    }

    fn nextToken(self: *Lexer) !void {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return;
        }

        const c = self.source[self.pos];

        if (c == ';' or c == '#') {
            try self.lexComment();
            return;
        }

        if (self.isLabelDef()) {
            try self.lexLabelDef();
            return;
        }

        if ((c == 'r' or c == 't' or c == 'R' or c == 'T') and self.pos + 1 < self.source.len) {
            if (self.source[self.pos + 1] >= '0' and self.source[self.pos + 1] <= '9') {
                try self.lexRegister();
                return;
            }
        }

        // Coptic register names: alpha0, beta1, ..., shmima26
        // Check if we have alphabetic characters followed by digits
        if (std.ascii.isAlphabetic(c)) {
            var i = self.pos + 1;
            // Skip all alphabetic characters
            while (i < self.source.len and std.ascii.isAlphabetic(self.source[i])) {
                i += 1;
            }
            // Check if followed by digits
            if (i < self.source.len and self.source[i] >= '0' and self.source[i] <= '9') {
                // Could be a Coptic register - try to lex it
                if (self.tryLexCopticRegister()) {
                    return; // Successfully lexed as Coptic register
                }
                // Not a Coptic register, fall through to mnemonic
            }
        }

        // Check hex immediate
        if (c == '0' and self.pos + 1 < self.source.len and self.source[self.pos + 1] == 'x') {
            try self.lexHexImmediate();
            return;
        }

        if (c == '-' or (c >= '0' and c <= '9')) {
            try self.lexImmediate();
            return;
        }

        if (c == ',') {
            try self.tokens.append(self.allocator, Token{
                .type = .Comma,
                .text = ",",
                .line = self.line,
                .column = self.column,
            });
            self.pos += 1;
            self.column += 1;
            return;
        }

        try self.lexIdentifier();
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\n') {
                self.pos += 1;
                self.line += 1;
                self.column = 1;
            } else if (c == '\r') {
                self.pos += 1;
                // Skip CR, next will be LF handled above
            } else if (c == ' ' or c == '\t') {
                self.pos += 1;
                self.column += 1;
            } else {
                break;
            }
        }
    }

    fn isLabelDef(self: *Lexer) bool {
        var i: usize = self.pos;
        while (i < self.source.len) {
            const c = self.source[i];
            if (c == ':') return true;
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') return false;
            if (c == ',' or c == ';') return false;
            i += 1;
        }
        return false;
    }

    fn lexLabelDef(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        while (self.pos < self.source.len and self.source[self.pos] != ':') {
            self.pos += 1;
            self.column += 1;
        }

        const text = self.source[start..self.pos];
        try self.tokens.append(self.allocator, Token{
            .type = .LabelDef,
            .text = text,
            .line = start_line,
            .column = start_col,
        });

        self.pos += 1; // skip :
        self.column += 1;
    }

    fn lexRegister(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        self.pos += 1; // skip 'r'
        self.column += 1;

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c < '0' or c > '9') break;
            self.pos += 1;
            self.column += 1;
        }

        const text = self.source[start..self.pos];
        if (text.len < 2) return error.InvalidRegister;
        const reg_str = text[1..];
        const reg_num = std.fmt.parseInt(u8, reg_str, 10) catch return error.InvalidRegister;
        if (reg_num > 31) return error.InvalidRegister;

        try self.tokens.append(self.allocator, Token{
            .type = .Register,
            .text = text,
            .line = start_line,
            .column = start_col,
        });
    }

    fn lexCopticRegister(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        // Parse Coptic name: alpha0, beta1, ..., shmima26
        // Find the end of the alphabetic part
        var name_end = self.pos;
        while (name_end < self.source.len and std.ascii.isAlphabetic(self.source[name_end])) {
            name_end += 1;
        }

        if (name_end == self.pos) return error.InvalidRegister; // No letters

        // Check for numeric suffix (0-26)
        var num_end = name_end;
        while (num_end < self.source.len and self.source[num_end] >= '0' and self.source[num_end] <= '9') {
            num_end += 1;
        }

        if (num_end == name_end) return error.InvalidRegister; // No digits

        const name = self.source[self.pos..name_end];
        const suffix = self.source[name_end..num_end];

        // Validate it's a known Coptic name
        const lower = std.ascii.allocLowerString(self.allocator, name) catch return error.InvalidRegister;
        defer self.allocator.free(lower);

        const CopticNames = [_][]const u8{
            "alpha",  "beta",  "gamma",  "delta",   "epsilon", "zeta", "theta",   "eta",
            "iota",   "kappa", "lambda", "mu",      "nu",      "xi",   "omicron", "pi",
            "rho",    "sigma", "tau",    "upsilon", "phi",     "chi",  "psi",     "omega",
            "shmima",
        };

        var is_coptic = false;
        for (CopticNames) |optic_name| {
            if (std.mem.eql(u8, lower, optic_name)) {
                is_coptic = true;
                break;
            }
        }

        if (!is_coptic) return error.InvalidRegister;

        // Parse suffix digit
        const suffix_num = std.fmt.parseInt(u8, suffix, 10) catch return error.InvalidRegister;
        if (suffix_num > 26) return error.InvalidRegister; // 0-26 for Coptic

        try self.tokens.append(self.allocator, Token{
            .type = .Register,
            .text = self.source[start..num_end],
            .line = start_line,
            .column = start_col,
        });

        self.pos = num_end;
        self.column = start_col + @as(u32, @intCast(num_end - start));
    }

    /// Try to lex a Coptic register, returning true if successful, false if not
    fn tryLexCopticRegister(self: *Lexer) bool {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        // Find the end of the alphabetic part
        var name_end = self.pos;
        while (name_end < self.source.len and std.ascii.isAlphabetic(self.source[name_end])) {
            name_end += 1;
        }

        if (name_end == self.pos) return false; // No letters

        // Check for numeric suffix (0-26)
        var num_end = name_end;
        while (num_end < self.source.len and self.source[num_end] >= '0' and self.source[num_end] <= '9') {
            num_end += 1;
        }

        if (num_end == name_end) return false; // No digits

        const name = self.source[self.pos..name_end];
        const suffix = self.source[name_end..num_end];

        // Validate it's a known Coptic name
        const lower = std.ascii.allocLowerString(self.allocator, name) catch return false;
        defer self.allocator.free(lower);

        const CopticNames = [_][]const u8{
            "alpha",  "beta",  "gamma",  "delta",   "epsilon", "zeta", "theta",   "eta",
            "iota",   "kappa", "lambda", "mu",      "nu",      "xi",   "omicron", "pi",
            "rho",    "sigma", "tau",    "upsilon", "phi",     "chi",  "psi",     "omega",
            "shmima",
        };

        var is_coptic = false;
        for (CopticNames) |optic_name| {
            if (std.mem.eql(u8, lower, optic_name)) {
                is_coptic = true;
                break;
            }
        }

        if (!is_coptic) return false;

        // Parse suffix digit
        const suffix_num = std.fmt.parseInt(u8, suffix, 10) catch return false;
        if (suffix_num > 26) return false; // 0-26 for Coptic

        self.tokens.append(self.allocator, Token{
            .type = .Register,
            .text = self.source[start..num_end],
            .line = start_line,
            .column = start_col,
        }) catch return false;

        self.pos = num_end;
        self.column = start_col + @as(u32, @intCast(num_end - start));
        return true;
    }

    fn lexImmediate(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        self.pos += 1;
        self.column += 1;

        if (self.pos < self.source.len and self.source[start] == '-' and
            (self.source[self.pos] >= '0' and self.source[self.pos] <= '9'))
        {
            self.pos += 1;
            self.column += 1;
        }

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c < '0' or c > '9') break;
            self.pos += 1;
            self.column += 1;
        }

        const text = self.source[start..self.pos];
        _ = std.fmt.parseInt(i16, text, 10) catch return error.InvalidImmediate;

        try self.tokens.append(self.allocator, Token{
            .type = .Immediate,
            .text = text,
            .line = start_line,
            .column = start_col,
        });
    }

    fn lexHexImmediate(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        self.pos += 2; // skip "0x"
        self.column += 2;

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'))) break;
            self.pos += 1;
            self.column += 1;
        }

        const text = self.source[start..self.pos];
        _ = std.fmt.parseInt(u16, text[2..], 16) catch return error.InvalidImmediate;

        try self.tokens.append(self.allocator, Token{
            .type = .Immediate,
            .text = text,
            .line = start_line,
            .column = start_col,
        });
    }

    fn lexIdentifier(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (!isIdentChar(c)) break;
            self.pos += 1;
            self.column += 1;
        }

        const text = self.source[start..self.pos];
        const token_type = if (self.pos < self.source.len and self.source[self.pos] == ':')
            TokenType.LabelDef
        else
            TokenType.Mnemonic;

        try self.tokens.append(self.allocator, Token{
            .type = token_type,
            .text = text,
            .line = start_line,
            .column = start_col,
        });
    }

    fn lexComment(self: *Lexer) !void {
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            self.pos += 1;
            if (c == '\n') {
                self.line += 1;
                self.column = 1;
                break;
            }
        }

        const text = self.source[start..self.pos];
        try self.tokens.append(self.allocator, Token{
            .type = .Comment,
            .text = text,
            .line = start_line,
            .column = start_col,
        });
    }

    fn isIdentChar(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '_';
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit(self.allocator);
    }
};

test "lexer tokenizes nop" {
    const allocator = std.testing.allocator;
    const source = "nop";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqualStrings("nop", tokens[0].text);
    try std.testing.expectEqual(TokenType.EOF, tokens[1].type);
}

test "lexer tokenizes add with registers" {
    const allocator = std.testing.allocator;
    const source = "add r5, r10, r15";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 7), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqual(TokenType.Register, tokens[1].type);
    try std.testing.expectEqual(TokenType.Comma, tokens[2].type);
    try std.testing.expectEqual(TokenType.Register, tokens[3].type);
    try std.testing.expectEqual(TokenType.Comma, tokens[4].type);
    try std.testing.expectEqual(TokenType.Register, tokens[5].type);
    try std.testing.expectEqual(TokenType.EOF, tokens[6].type);
}

test "lexer tokenizes load_imm" {
    const allocator = std.testing.allocator;
    const source = "load_imm r7, -42";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 5), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqual(TokenType.Register, tokens[1].type);
    try std.testing.expectEqual(TokenType.Comma, tokens[2].type);
    try std.testing.expectEqual(TokenType.Immediate, tokens[3].type);
    try std.testing.expectEqual(TokenType.EOF, tokens[4].type);
}

test "lexer tokenizes label definition" {
    const allocator = std.testing.allocator;
    const source = "loop: nop";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 3), tokens.len);
    try std.testing.expectEqual(TokenType.LabelDef, tokens[0].type);
    try std.testing.expectEqualStrings("loop", tokens[0].text);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[1].type);
    try std.testing.expectEqual(TokenType.EOF, tokens[2].type);
}

test "lexer tokenizes comment" {
    const allocator = std.testing.allocator;
    const source = "nop ; this is a comment\nadd r1, r2, r3";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    // nop, comment, add, r1, comma, r2, comma, r3, EOF = 9 tokens
    try std.testing.expectEqual(@as(usize, 9), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqual(TokenType.Comment, tokens[1].type);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[2].type);
    try std.testing.expectEqual(TokenType.Register, tokens[3].type);
    try std.testing.expectEqual(TokenType.Comma, tokens[4].type);
    try std.testing.expectEqual(TokenType.Register, tokens[5].type);
    try std.testing.expectEqual(TokenType.Comma, tokens[6].type);
    try std.testing.expectEqual(TokenType.Register, tokens[7].type);
    try std.testing.expectEqual(TokenType.EOF, tokens[8].type);
}

test "lexer handles hex immediates" {
    const allocator = std.testing.allocator;
    const source = "load_imm r5, 0x1000";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(TokenType.Immediate, tokens[3].type);
    try std.testing.expectEqualStrings("0x1000", tokens[3].text);
}

test "lexer handles newlines" {
    const allocator = std.testing.allocator;
    const source = "nop\nadd r1, r2";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    // nop, add, r1, comma, r2, EOF = 6 tokens
    try std.testing.expectEqual(@as(usize, 6), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[1].type);
    try std.testing.expectEqual(TokenType.Register, tokens[2].type);
    try std.testing.expectEqual(TokenType.Comma, tokens[3].type);
    try std.testing.expectEqual(TokenType.Register, tokens[4].type);
    try std.testing.expectEqual(TokenType.EOF, tokens[5].type);
}

test "lexer handles t-registers" {
    const allocator = std.testing.allocator;
    const source = "inc t0";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 3), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqual(TokenType.Register, tokens[1].type);
    try std.testing.expectEqualStrings("t0", tokens[1].text);
    try std.testing.expectEqual(TokenType.EOF, tokens[2].type);
}

test "lexer handles t-register arithmetic" {
    const allocator = std.testing.allocator;
    const source = "add t1, t2, t3";
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try std.testing.expectEqual(@as(usize, 7), tokens.len);
    try std.testing.expectEqual(TokenType.Mnemonic, tokens[0].type);
    try std.testing.expectEqual(TokenType.Register, tokens[1].type);
    try std.testing.expectEqualStrings("t1", tokens[1].text);
    try std.testing.expectEqual(TokenType.Comma, tokens[2].type);
    try std.testing.expectEqual(TokenType.Register, tokens[3].type);
    try std.testing.expectEqualStrings("t2", tokens[3].text);
    try std.testing.expectEqual(TokenType.Comma, tokens[4].type);
    try std.testing.expectEqual(TokenType.Register, tokens[5].type);
    try std.testing.expectEqualStrings("t3", tokens[5].text);
    try std.testing.expectEqual(TokenType.EOF, tokens[6].type);
}
