// ═══════════════════════════════════════════════════════════════════════════
// parser.zig - Parser for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #408: ADT Enum + Exhaustive Match + Pipe
//
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ast = @import("ast.zig");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;

/// Parse error
pub const ParseError = error{
    UnexpectedToken,
    ExpectedIdentifier,
    ExpectedType,
    ExpectedLeftParen,
    ExpectedRightParen,
    ExpectedLeftBrace,
    ExpectedRightBrace,
    ExpectedArrow,
    ExpectedPipe,
    IncompleteMatch,
    DuplicateVariant,
    OutOfMemory,
};

/// Parser state
pub const Parser = struct {
    lexer: Lexer,
    current_token: Token,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(source: []const u8, allocator: std.mem.Allocator) !Self {
        var lexer = Lexer.init(source, allocator);
        const first_token = try lexer.next();
        return .{
            .lexer = lexer,
            .current_token = first_token,
            .allocator = allocator,
        };
    }

    /// Advance to next token
    fn advance(self: *Self) !void {
        self.current_token = try self.lexer.next();
    }

    /// Check if current token is keyword
    fn isKeyword(self: *const Self, kw: Token.Keyword) bool {
        return if (self.current_token == .Keyword)
            self.current_token.Keyword == kw
        else
            false;
    }

    /// Expect current token to be keyword, consume if matches
    fn expectKeyword(self: *Self, kw: Token.Keyword) !void {
        if (!self.isKeyword(kw)) {
            return error.UnexpectedToken;
        }
        try self.advance();
    }

    /// Parse a program (list of declarations)
    pub fn parseProgram(self: *Self) ![]ast.Node {
        var nodes = std.ArrayList(ast.Node).init(self.allocator);

        while (self.current_token != .Eof) {
            const node = try self.parseDecl();
            try nodes.append(node);
        }

        return nodes.toOwnedSlice();
    }

    /// Parse a declaration (function, struct, enum, type alias, pipeline, effect)
    fn parseDecl(self: *Self) ParseError!ast.Node {
        // Check for visibility modifier
        var is_pub = false;
        if (self.isKeyword(.Pub)) {
            is_pub = true;
            try self.advance();
        }

        if (self.isKeyword(.Fn)) {
            return self.parseFunctionDecl(is_pub);
        }
        if (self.isKeyword(.Struct)) {
            return self.parseStructDecl(is_pub);
        }
        if (self.isKeyword(.Enum)) {
            return self.parseEnumDecl(is_pub);
        }
        if (self.isKeyword(.Type)) {
            return self.parseTypeAlias(is_pub);
        }
        if (self.isKeyword(.Pipeline)) {
            return self.parsePipelineDecl(is_pub);
        }
        // Wave 2: Effects + Handlers
        if (self.isKeyword(.Effect)) {
            return self.parseEffectDecl(is_pub);
        }

        return error.UnexpectedToken;
    }

    /// Parse function declaration
    fn parseFunctionDecl(self: *Self, is_pub: bool) ParseError!ast.Node {
        _ = is_pub; // TODO: track visibility
        const loc = self.lexer.location();

        try self.expectKeyword(.Fn);

        const name = try self.expectIdentifier();
        try self.expectToken(.LeftParen);

        var params = std.ArrayList(ast.Param).init(self.allocator);
        if (self.current_token != .RightParen) {
            try self.parseParams(&params);
        }
        try self.expectToken(.RightParen);

        // Return type (optional)
        var return_type: ast.Type = undefined;
        if (self.current_token == .DoubleArrow) {
            try self.advance();
            return_type = try self.parseType();
        } else {
            // Default to void/no return
            return_type = ast.Type{ .Int = .I32 }; // Placeholder
        }

        try self.expectToken(.LeftBrace);
        const body = try self.parseBlock();
        try self.expectToken(.RightBrace);

        return ast.Node{
            .Function = .{
                .name = name,
                .params = try params.toOwnedSlice(),
                .return_type = return_type,
                .body = body,
                .loc = loc,
            },
        };
    }

    /// Parse struct declaration
    fn parseStructDecl(self: *Self, is_pub: bool) ParseError!ast.Node {
        _ = is_pub;
        const loc = self.lexer.location();

        try self.expectKeyword(.Struct);
        const name = try self.expectIdentifier();

        try self.expectToken(.LeftBrace);

        var fields = std.ArrayList(ast.Field).init(self.allocator);
        while (self.current_token != .RightBrace) {
            const field_name = try self.expectIdentifier();
            try self.expectToken(.Colon);
            const field_type = try self.parseType();

            try fields.append(.{
                .name = field_name,
                .field_type = field_type,
                .loc = loc,
            });

            if (self.current_token == .Comma) {
                try self.advance();
            }
        }

        try self.expectToken(.RightBrace);

        return ast.Node{
            .StructDef = .{
                .name = name,
                .fields = try fields.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// Parse enum declaration (ADT enum with data-carrying variants)
    fn parseEnumDecl(self: *Self, is_pub: bool) ParseError!ast.Node {
        _ = is_pub;
        const loc = self.lexer.location();

        try self.expectKeyword(.Enum);
        const name = try self.expectIdentifier();

        try self.expectToken(.LeftBrace);

        var variants = std.ArrayList(ast.EnumVariant).init(self.allocator);
        while (self.current_token != .RightBrace) {
            const variant_name = try self.expectIdentifier();

            // Check for data type: Variant(Type)
            var data_type: ?ast.Type = null;
            if (self.current_token == .LeftParen) {
                try self.advance();
                data_type = try self.parseType();
                try self.expectToken(.RightParen);
            }

            try variants.append(.{
                .name = variant_name,
                .data_type = data_type,
                .loc = loc,
            });

            if (self.current_token == .Comma) {
                try self.advance();
            }
        }

        try self.expectToken(.RightBrace);

        return ast.Node{
            .EnumDef = .{
                .name = name,
                .variants = try variants.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// Parse type alias
    fn parseTypeAlias(self: *Self, is_pub: bool) ParseError!ast.Node {
        _ = is_pub;
        const loc = self.lexer.location();

        try self.expectKeyword(.Type);
        const name = try self.expectIdentifier();
        try self.expectToken(.Equal);
        const aliased_type = try self.parseType();

        return ast.Node{
            .TypeAlias = .{
                .name = name,
                .aliased_type = aliased_type,
                .loc = loc,
            },
        };
    }

    /// Parse named pipeline declaration
    fn parsePipelineDecl(self: *Self, is_pub: bool) ParseError!ast.Node {
        _ = is_pub;
        const loc = self.lexer.location();

        try self.expectKeyword(.Pipeline);
        const name = try self.expectIdentifier();
        try self.expectToken(.Equal);

        // Pipeline body is an expression (usually a pipe expression)
        _ = try self.parseExpr();

        return ast.Node{
            .PipelineRef = .{ // Reusing existing node type
                .name = name,
                .loc = loc,
            },
        };
    }

    /// Parse parameters
    fn parseParams(self: *Self, params: *std.ArrayList(ast.Param)) !void {
        while (true) {
            const param_name = try self.expectIdentifier();
            try self.expectToken(.Colon);
            const param_type = try self.parseType();

            try params.append(.{
                .name = param_name,
                .param_type = param_type,
                .loc = self.lexer.location(),
            });

            if (self.current_token != .Comma) break;
            try self.advance();
        }
    }

    /// Parse a block of statements
    fn parseBlock(self: *Self) ![]ast.Statement {
        var stmts = std.ArrayList(ast.Statement).init(self.allocator);

        while (self.current_token != .RightBrace and self.current_token != .Eof) {
            const stmt = try self.parseStmt();
            try stmts.append(stmt);
        }

        return stmts.toOwnedSlice();
    }

    /// Parse a statement
    fn parseStmt(self: *Self) ParseError!ast.Statement {
        if (self.isKeyword(.Return)) {
            return self.parseReturnStmt();
        }
        if (self.isKeyword(.Let)) {
            return self.parseLetStmt();
        }
        if (self.isKeyword(.If)) {
            return self.parseIfStmt();
        }
        if (self.isKeyword(.While)) {
            return self.parseWhileStmt();
        }
        if (self.isKeyword(.For)) {
            return self.parseForStmt();
        }
        if (self.isKeyword(.Match)) {
            return self.parseMatchExpr();
        }
        // Wave 2: Effects + Handlers
        if (self.isKeyword(.Perform)) {
            return self.parsePerformExpr();
        }
        if (self.isKeyword(.Handle)) {
            return self.parseHandleExpr();
        }
        if (self.isKeyword(.Try)) {
            return self.parseTryExpr();
        }

        // Expression statement
        const expr = try self.parseExpr();
        if (self.current_token == .Semicolon) {
            try self.advance();
        }

        return ast.Statement{ .Expression = .{ .expr = expr } };
    }

    /// Parse return statement
    fn parseReturnStmt(self: *Self) ParseError!ast.Statement {
        const loc = self.lexer.location();
        try self.expectKeyword(.Return);
        const value = try self.parseExpr();
        if (self.current_token == .Semicolon) {
            try self.advance();
        }

        return ast.Statement{
            .Return = .{ .value = value, .loc = loc },
        };
    }

    /// Parse let statement
    fn parseLetStmt(self: *Self) ParseError!ast.Statement {
        const loc = self.lexer.location();
        try self.expectKeyword(.Let);
        const name = try self.expectIdentifier();
        try self.expectToken(.Equal);
        const value = try self.parseExpr();
        if (self.current_token == .Semicolon) {
            try self.advance();
        }

        return ast.Statement{
            .Let = .{ .name = name, .value = value, .loc = loc },
        };
    }

    /// Parse if statement
    fn parseIfStmt(self: *Self) ParseError!ast.Statement {
        const loc = self.lexer.location();
        try self.expectKeyword(.If);
        const condition = try self.parseExpr();
        try self.expectToken(.LeftBrace);
        const then_branch = try self.parseBlock();
        try self.expectToken(.RightBrace);

        var else_branch: ?[]ast.Statement = null;
        if (self.isKeyword(.Else)) {
            try self.advance();
            try self.expectToken(.LeftBrace);
            else_branch = try self.parseBlock();
            try self.expectToken(.RightBrace);
        }

        return ast.Statement{
            .If = .{
                .condition = condition,
                .then_branch = then_branch,
                .else_branch = else_branch,
                .loc = loc,
            },
        };
    }

    /// Parse while statement
    fn parseWhileStmt(self: *Self) ParseError!ast.Statement {
        const loc = self.lexer.location();
        try self.expectKeyword(.While);
        const condition = try self.parseExpr();
        try self.expectToken(.LeftBrace);
        const body = try self.parseBlock();
        try self.expectToken(.RightBrace);

        return ast.Statement{
            .While = .{ .condition = condition, .body = body, .loc = loc },
        };
    }

    /// Parse for statement
    fn parseForStmt(self: *Self) ParseError!ast.Statement {
        const loc = self.lexer.location();
        try self.expectKeyword(.For);
        const var_name = try self.expectIdentifier();

        try self.expectToken(.Keyword); // "in" keyword (reuse token)
        const start = try self.parseExpr();

        var range: ast.Range = undefined;
        if (self.current_token == .DoubleDot) {
            try self.advance();
            const end = try self.parseExpr();
            range = ast.Range{ .To = .{ .start = start, .end = end } };
        } else if (self.current_token == .DoubleDotEq) {
            try self.advance();
            const end = try self.parseExpr();
            range = ast.Range{ .ToEq = .{ .start = start, .end = end } };
        } else {
            return error.UnexpectedToken;
        }

        try self.expectToken(.LeftBrace);
        const body = try self.parseBlock();
        try self.expectToken(.RightBrace);

        return ast.Statement{
            .For = .{
                .var_name = var_name,
                .range = range,
                .body = body,
                .loc = loc,
            },
        };
    }

    /// Parse an expression (with precedence climbing)
    fn parseExpr(self: *Self) ParseError!ast.Expression {
        return self.parsePipeExpr();
    }

    /// Parse pipe expression (Elixir-style: a |> b |> c)
    fn parsePipeExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        const source = try self.parseUnaryExpr();

        var stages = std.ArrayList(ast.Expression).init(self.allocator);

        while (self.current_token == .PipeForward) {
            try self.advance(); // consume |>

            const stage = try self.parseUnaryExpr();
            try stages.append(stage);
        }

        if (stages.items.len > 0) {
            return ast.Expression{
                .Pipe = .{
                    .source = source,
                    .stages = try stages.toOwnedSlice(),
                    .loc = loc,
                },
            };
        }

        return source;
    }

    /// Parse unary expression
    fn parseUnaryExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();

        if (self.current_token == .Operator) {
            // Check for unary operators
            const op_token = self.current_token;
            try self.advance();
            const operand = try self.parseUnaryExpr();

            const op: ast.UnaryOperator = switch (op_token.Operator) {
                .Sub => .Neg,
                .BitNot => .BitNot,
                else => return error.UnexpectedToken,
            };

            return ast.Expression{
                .UnaryOp = .{ .op = op, .operand = operand, .loc = loc },
            };
        }

        return self.parsePrimaryExpr();
    }

    /// Parse primary expression
    fn parsePrimaryExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();

        // Wave 4: Check for array combinators first
        if (self.isKeyword(.Map)) return self.parseMapExpr();
        if (self.isKeyword(.Reduce)) return self.parseReduceExpr();
        if (self.isKeyword(.Scan)) return self.parseScanExpr();
        if (self.isKeyword(.Filter)) return self.parseFilterExpr();
        if (self.isKeyword(.FlatMap)) return self.parseFlatMapExpr();
        if (self.isKeyword(.Zip)) return self.parseZipExpr();

        switch (self.current_token) {
            .IntLiteral => |v| {
                try self.advance();
                return ast.Expression{ .IntLiteral = .{ .value = v, .loc = loc } };
            },
            .FloatLiteral => |v| {
                try self.advance();
                return ast.Expression{ .FloatLiteral = .{ .value = v, .loc = loc } };
            },
            .StringLiteral => |v| {
                try self.advance();
                return ast.Expression{ .StringLiteral = .{ .value = v, .loc = loc } };
            },
            .CharLiteral => |v| {
                try self.advance();
                return ast.Expression{ .CharLiteral = .{ .value = v, .loc = loc } };
            },
            .BoolLiteral => |v| {
                try self.advance();
                return ast.Expression{ .BoolLiteral = .{ .value = v, .loc = loc } };
            },
            .Identifier => |name| {
                try self.advance();
                return ast.Expression{ .Identifier = .{ .name = name, .loc = loc } };
            },
            .LeftParen => {
                try self.advance();
                const expr = try self.parseExpr();
                try self.expectToken(.RightParen);
                return expr;
            },
            .LeftBracket => {
                return self.parseArrayLiteral();
            },
            else => return error.UnexpectedToken,
        }
    }

    /// Parse array literal
    fn parseArrayLiteral(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectToken(.LeftBracket);

        var elements = std.ArrayList(ast.Expression).init(self.allocator);

        while (self.current_token != .RightBracket) {
            const elem = try self.parseExpr();
            try elements.append(elem);

            if (self.current_token == .Comma) {
                try self.advance();
            }
        }

        try self.expectToken(.RightBracket);

        return ast.Expression{
            .ArrayLiteral = .{
                .elements = try elements.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// ═══════════════════════════════════════════════════════════════════════
    // WAVE 4: ARRAY COMBINATORS
    // ═════════════════════════════════════════════════════════════════════════════════════

    /// Parse map expression: map(array, func)
    fn parseMapExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectKeyword(.Map);
        try self.expectToken(.LeftParen);

        const array = try self.parseExpr();
        try self.expectToken(.Comma);

        const func = try self.parseExpr();
        try self.expectToken(.RightParen);

        return ast.Expression{
            .Map = .{
                .array = array,
                .func = func,
                .loc = loc,
            },
        };
    }

    /// Parse reduce expression: reduce(array, init, op)
    fn parseReduceExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectKeyword(.Reduce);
        try self.expectToken(.LeftParen);

        const array = try self.parseExpr();
        try self.expectToken(.Comma);

        const init_val = try self.parseExpr();
        try self.expectToken(.Comma);

        // Parse operator (binary operator token)
        if (self.current_token != .Operator) {
            return error.UnexpectedToken;
        }
        const op_token = self.current_token.Operator;
        try self.advance();

        try self.expectToken(.RightParen);

        // Map operator token to AST BinaryOperator
        const op: ast.BinaryOperator = switch (op_token) {
            .Add => .Add,
            .Sub => .Sub,
            .Mul => .Mul,
            .Div => .Div,
            .Mod => .Mod,
            .BitAnd => .BitAnd,
            .BitOr => .BitOr,
            .BitXor => .BitXor,
            else => .Add, // Default to Add
        };

        return ast.Expression{
            .Reduce = .{
                .array = array,
                .init = init_val,
                .operation = op,
                .loc = loc,
            },
        };
    }

    /// Parse scan expression: scan(array, init, op, scan_type?)
    fn parseScanExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectKeyword(.Scan);
        try self.expectToken(.LeftParen);

        const array = try self.parseExpr();
        try self.expectToken(.Comma);

        const init_val = try self.parseExpr();
        try self.expectToken(.Comma);

        // Parse operator
        if (self.current_token != .Operator) {
            return error.UnexpectedToken;
        }
        const op_token = self.current_token.Operator;
        try self.advance();

        // Optional scan type specifier
        var scan_type: ast.ScanType = .Prefix;
        if (self.current_token == .Comma) {
            try self.advance();
            if (self.isKeyword(.Inclusive)) {
                scan_type = .Inclusive;
                try self.advance();
            } else if (self.isKeyword(.Exclusive)) {
                scan_type = .Exclusive;
                try self.advance();
            } else if (self.isKeyword(.Prefix)) {
                scan_type = .Prefix;
                try self.advance();
            }
        }

        try self.expectToken(.RightParen);

        const op: ast.BinaryOperator = switch (op_token) {
            .Add => .Add,
            .Sub => .Sub,
            .Mul => .Mul,
            .Div => .Div,
            else => .Add,
        };

        return ast.Expression{
            .Scan = .{
                .array = array,
                .init = init_val,
                .operation = op,
                .scan_type = scan_type,
                .loc = loc,
            },
        };
    }

    /// Parse filter expression: filter(array, pred)
    fn parseFilterExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectKeyword(.Filter);
        try self.expectToken(.LeftParen);

        const array = try self.parseExpr();
        try self.expectToken(.Comma);

        const predicate = try self.parseExpr();
        try self.expectToken(.RightParen);

        return ast.Expression{
            .Filter = .{
                .array = array,
                .predicate = predicate,
                .loc = loc,
            },
        };
    }

    /// Parse flatMap expression: flatMap(array, func)
    fn parseFlatMapExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectKeyword(.FlatMap);
        try self.expectToken(.LeftParen);

        const array = try self.parseExpr();
        try self.expectToken(.Comma);

        const func = try self.parseExpr();
        try self.expectToken(.RightParen);

        return ast.Expression{
            .FlatMap = .{
                .array = array,
                .func = func,
                .loc = loc,
            },
        };
    }

    /// Parse zip expression: zip(arr1, arr2)
    fn parseZipExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();
        try self.expectKeyword(.Zip);
        try self.expectToken(.LeftParen);

        const array1 = try self.parseExpr();
        try self.expectToken(.Comma);

        const array2 = try self.parseExpr();
        try self.expectToken(.RightParen);

        return ast.Expression{
            .Zip = .{
                .array1 = array1,
                .array2 = array2,
                .loc = loc,
            },
        };
    }

    /// Parse type
    fn parseType(self: *Self) ParseError!ast.Type {
        if (self.isKeyword(.Trit)) {
            try self.advance();
            return ast.Type{ .Trit = .Trit };
        }
        if (self.isKeyword(.Trit3)) {
            try self.advance();
            return ast.Type{ .Trit = .Trit3 };
        }
        if (self.isKeyword(.Trit9)) {
            try self.advance();
            return ast.Type{ .Trit = .Trit9 };
        }
        if (self.isKeyword(.Trit27)) {
            try self.advance();
            return ast.Type{ .Trit = .Trit27 };
        }
        if (self.isKeyword(.I8)) {
            try self.advance();
            return ast.Type{ .Int = .I8 };
        }
        if (self.isKeyword(.I16)) {
            try self.advance();
            return ast.Type{ .Int = .I16 };
        }
        if (self.isKeyword(.I32)) {
            try self.advance();
            return ast.Type{ .Int = .I32 };
        }
        if (self.isKeyword(.I64)) {
            try self.advance();
            return ast.Type{ .Int = .I64 };
        }
        if (self.isKeyword(.F16)) {
            try self.advance();
            return ast.Type{ .Float = .F16 };
        }
        if (self.isKeyword(.F32)) {
            try self.advance();
            return ast.Type{ .Float = .F32 };
        }
        if (self.isKeyword(.F64)) {
            try self.advance();
            return ast.Type{ .Float = .F64 };
        }
        if (self.isKeyword(.String)) {
            try self.advance();
            return ast.Type{ .String = {} };
        }
        if (self.isKeyword(.Bool)) {
            try self.advance();
            return ast.Type{ .Bool = {} };
        }
        if (self.isKeyword(.Gf16)) {
            try self.advance();
            return ast.Type{ .Float = .F16 }; // Map GF16 to f16
        }
        if (self.isKeyword(.Tf3)) {
            try self.advance();
            return ast.Type{ .Int = .I32 }; // Placeholder for TF3
        }

        // Wave 2: Result type: Result(T, E)
        if (self.isKeyword(.Result)) {
            return self.parseResultType();
        }

        // Wave 2: Linear type: linear T
        if (self.isKeyword(.Linear)) {
            return self.parseLinearType();
        }

        // Wave 2: Banked type: Banked(T, Bank)
        if (self.isKeyword(.Banked)) {
            return self.parseBankedType();
        }

        // Wave 2: Fixed-size array: [N]T
        if (self.current_token == .LeftBracket) {
            return self.parseArrayType();
        }

        // Wave 4: Platform type: CPU, FPGA, VM, Auto
        if (self.isKeyword(.CPU)) {
            try self.advance();
            return ast.Type{ .Platform = .{ .target = .CPU } };
        }
        if (self.isKeyword(.FPGA)) {
            try self.advance();
            return ast.Type{ .Platform = .{ .target = .FPGA } };
        }
        if (self.isKeyword(.VM)) {
            try self.advance();
            return ast.Type{ .Platform = .{ .target = .VM } };
        }
        if (self.isKeyword(.Auto)) {
            try self.advance();
            return ast.Type{ .Platform = .{ .target = .Auto } };
        }

        // Named type (struct or enum)
        if (self.current_token == .Identifier) {
            const name = self.current_token.Identifier;
            try self.advance();
            return ast.Type{ .Named = .{ .name = name } };
        }

        return error.ExpectedType;
    }

    /// Parse Result type: Result(T, E)
    fn parseResultType(self: *Self) ParseError!ast.Type {
        try self.expectKeyword(.Result);
        try self.expectToken(.LeftParen);

        const ok_type_ptr = try self.allocator.create(ast.Type);
        ok_type_ptr.* = try self.parseType();

        try self.expectToken(.Comma);

        const err_type_ptr = try self.allocator.create(ast.Type);
        err_type_ptr.* = try self.parseType();

        try self.expectToken(.RightParen);

        return ast.Type{
            .Result = .{
                .ok_type = ok_type_ptr,
                .err_type = err_type_ptr,
            },
        };
    }

    /// Parse Linear type: linear T
    fn parseLinearType(self: *Self) ParseError!ast.Type {
        try self.expectKeyword(.Linear);
        const inner_type_ptr = try self.allocator.create(ast.Type);
        inner_type_ptr.* = try self.parseType();
        return ast.Type{
            .Linear = .{
                .inner_type = inner_type_ptr,
            },
        };
    }

    /// Parse Banked type: Banked(T, BankN)
    fn parseBankedType(self: *Self) ParseError!ast.Type {
        try self.expectKeyword(.Banked);
        try self.expectToken(.LeftParen);

        const value_type_ptr = try self.allocator.create(ast.Type);
        value_type_ptr.* = try self.parseType();

        try self.expectToken(.Comma);

        // Parse bank: Bank0, Bank1, ..., Bank8
        const bank: ast.Bank = if (self.isKeyword(.Bank0)) blk: {
            try self.advance();
            break :blk .ALU;
        } else if (self.isKeyword(.Bank1)) blk: {
            try self.advance();
            break :blk .Sacred;
        } else if (self.isKeyword(.Bank2)) blk: {
            try self.advance();
            break :blk .Constant;
        } else blk: {
            // For now, default to ALU for Bank3-8
            try self.advance();
            break :blk .ALU;
        };

        try self.expectToken(.RightParen);

        return ast.Type{
            .Banked = .{
                .value_type = value_type_ptr,
                .bank = bank,
            },
        };
    }

    /// Parse array type: [T] or [N]T (fixed-size)
    fn parseArrayType(self: *Self) ParseError!ast.Type {
        try self.expectToken(.LeftBracket);

        // Check if this is a fixed-size array [N]T or dynamic [T]
        if (self.current_token == .IntLiteral) {
            // Fixed-size array: [N]T
            const size = @as(usize, @intCast(self.current_token.IntLiteral));
            try self.advance();

            const element_type_ptr = try self.allocator.create(ast.Type);
            element_type_ptr.* = try self.parseType();

            try self.expectToken(.RightBracket);

            return ast.Type{
                .ArrayFixed = .{
                    .element_type = element_type_ptr,
                    .size = size,
                },
            };
        } else {
            // Dynamic array: [T]
            const element_type_ptr = try self.allocator.create(ast.Type);
            element_type_ptr.* = try self.parseType();

            try self.expectToken(.RightBracket);

            return ast.Type{
                .Array = .{
                    .element_type = element_type_ptr,
                    .size = null,
                },
            };
        }
    }

    /// Expect identifier, return its name
    fn expectIdentifier(self: *Self) ![]const u8 {
        if (self.current_token != .Identifier) {
            return error.ExpectedIdentifier;
        }
        const name = self.current_token.Identifier;
        try self.advance();
        return name;
    }

    /// Expect specific token
    fn expectToken(self: *Self, token_tag: std.meta.Tag(Token)) !void {
        if (std.meta.activeTag(self.current_token) != token_tag) {
            return error.UnexpectedToken;
        }
        try self.advance();
    }

    /// ═══════════════════════════════════════════════════════════════════════
    // MATCH EXPRESSION (Exhaustive match with guards)
    // ═════════════════════════════════════════════════════════════════════════════════════

    /// Parse match expression
    fn parseMatchExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();

        try self.expectKeyword(.Match);
        const value = try self.parseExpr();
        try self.expectToken(.LeftBrace);

        var arms = std.ArrayList(ast.MatchArm).init(self.allocator);

        while (self.current_token != .RightBrace) {
            const arm = try self.parseMatchArm();
            try arms.append(arm);

            if (self.current_token == .Comma) {
                try self.advance();
            }
        }

        try self.expectToken(.RightBrace);

        // TODO: Validate exhaustiveness (all enum variants covered)

        return ast.Expression{
            .Match = .{
                .value = value,
                .arms = try arms.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// Parse single match arm: pattern => expr or pattern | guard => expr
    fn parseMatchArm(self: *Self) ParseError!ast.MatchArm {
        const loc = self.lexer.location();

        const pattern = try self.parsePattern();

        // Check for guard: | condition
        var guard: ?ast.Guard = null;
        if (self.current_token == .Pipe) {
            try self.advance();
            const condition = try self.parseExpr();
            guard = .{ .condition = condition, .loc = loc };
        }

        try self.expectToken(.Arrow);
        const body = try self.parseExpr();

        return .{
            .pattern = pattern,
            .guard = guard,
            .body = body,
            .loc = loc,
        };
    }

    /// Parse pattern
    fn parsePattern(self: *Self) ParseError!ast.Pattern {
        _ = self.lexer.location();

        if (self.current_token == .Wildcard) {
            try self.advance();
            return ast.Pattern{ .Wildcard = {} };
        }

        if (self.current_token == .IntLiteral) {
            const value = self.current_token.IntLiteral;
            try self.advance();
            return ast.Pattern{
                .Literal = .{ .value = .{ .Int = value } },
            };
        }

        if (self.current_token == .BoolLiteral) {
            const value = self.current_token.BoolLiteral;
            try self.advance();
            return ast.Pattern{
                .Literal = .{ .value = .{ .Bool = value } },
            };
        }

        if (self.current_token == .Identifier) {
            // Check if this is an enum variant pattern
            const name = self.current_token.Identifier;

            // Look ahead for (data) pattern
            try self.advance();

            if (self.current_token == .LeftParen) {
                // Enum variant with data: Variant(data_pattern)
                try self.advance();
                const data_pattern = try self.parsePattern();
                try self.expectToken(.RightParen);

                return ast.Pattern{
                    .EnumVariant = .{
                        .enum_name = "", // TODO: resolve from scope
                        .variant_name = name,
                        .data_pattern = data_pattern,
                    },
                };
            }

            // Simple identifier pattern
            return ast.Pattern{
                .Identifier = .{ .name = name },
            };
        }

        if (self.current_token == .LeftBracket) {
            // Array pattern: [p1, p2, ...]
            try self.advance();

            var elements = std.ArrayList(ast.Pattern).init(self.allocator);

            while (self.current_token != .RightBracket) {
                const elem = try self.parsePattern();
                try elements.append(elem);

                if (self.current_token == .Comma) {
                    try self.advance();
                }
            }

            try self.expectToken(.RightBracket);

            return ast.Pattern{
                .Array = .{
                    .elements = try elements.toOwnedSlice(),
                },
            };
        }

        return error.UnexpectedToken;
    }

    /// ═══════════════════════════════════════════════════════════════════════
    // WAVE 2: EFFECTS + HANDLERS
    // ═════════════════════════════════════════════════════════════════════════════════════

    /// Parse effect declaration: effect State { get, set(value) }
    fn parseEffectDecl(self: *Self, is_pub: bool) ParseError!ast.Node {
        _ = is_pub;
        const loc = self.lexer.location();

        try self.expectKeyword(.Effect);
        const name = try self.expectIdentifier();

        try self.expectToken(.LeftBrace);

        var operations = std.ArrayList(ast.EffectOperation).init(self.allocator);
        while (self.current_token != .RightBrace) {
            const op_name = try self.expectIdentifier();

            // Check for payload: op(value)
            var payload_type: ?ast.Type = null;
            if (self.current_token == .LeftParen) {
                try self.advance();
                payload_type = try self.parseType();
                try self.expectToken(.RightParen);
            }

            try operations.append(.{
                .name = op_name,
                .payload_type = payload_type,
                .loc = loc,
            });

            if (self.current_token == .Comma) {
                try self.advance();
            }
        }

        try self.expectToken(.RightBrace);

        return ast.Node{
            .EffectDef = .{
                .name = name,
                .operations = try operations.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// Parse perform expression: perform effect.operation(args)
    fn parsePerformExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();

        try self.expectKeyword(.Perform);

        // Parse effect name or direct operation
        const effect_or_op = try self.expectIdentifier();

        // Check for effect.operation syntax
        var effect_name: []const u8 = undefined;
        var op_name: []const u8 = undefined;

        if (self.current_token == .Dot) {
            // effect.operation syntax
            effect_name = effect_or_op;
            try self.advance(); // consume .
            op_name = try self.expectIdentifier();
        } else {
            // Direct operation name (infer effect from context)
            effect_name = "";
            op_name = effect_or_op;
        }

        // Parse arguments
        var args = std.ArrayList(ast.Expression).init(self.allocator);
        if (self.current_token == .LeftParen) {
            try self.advance();
            while (self.current_token != .RightParen) {
                const arg = try self.parseExpr();
                try args.append(arg);

                if (self.current_token == .Comma) {
                    try self.advance();
                }
            }
            try self.expectToken(.RightParen);
        }

        return ast.Expression{
            .Perform = .{
                .effect_name = effect_name,
                .operation = op_name,
                .args = try args.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// Parse handle expression: handle effect { computation }
    fn parseHandleExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();

        try self.expectKeyword(.Handle);

        // Parse effect name
        const effect_name = try self.expectIdentifier();

        // Parse handler clauses: { op1(pattern) => body, op2(pattern) => body }
        try self.expectToken(.LeftBrace);

        var clauses = std.ArrayList(ast.HandlerClause).init(self.allocator);
        while (self.current_token != .RightBrace) {
            const op_name = try self.expectIdentifier();

            // Parse parameter pattern
            var param_pattern: ast.Pattern = undefined;
            if (self.current_token == .LeftParen) {
                try self.advance();
                param_pattern = try self.parsePattern();
                try self.expectToken(.RightParen);
            } else {
                // No parameter, use wildcard
                param_pattern = ast.Pattern{ .Wildcard = {} };
            }

            try self.expectToken(.Arrow);
            const body = try self.parseExpr();

            try clauses.append(.{
                .operation = op_name,
                .param_pattern = param_pattern,
                .body = body,
                .loc = loc,
            });

            if (self.current_token == .Comma) {
                try self.advance();
            }
        }

        try self.expectToken(.RightBrace);

        return ast.Expression{
            .Handle = .{
                .effect_name = effect_name,
                .clauses = try clauses.toOwnedSlice(),
                .loc = loc,
            },
        };
    }

    /// Parse try expression: try { computation } with { handlers }
    fn parseTryExpr(self: *Self) ParseError!ast.Expression {
        const loc = self.lexer.location();

        try self.expectKeyword(.Try);

        // Parse computation block
        try self.expectToken(.LeftBrace);
        const computation = try self.parseExpr();
        try self.expectToken(.RightBrace);

        // Parse with clause (optional)
        var handlers: []ast.HandlerClause = &[_]ast.HandlerClause{};
        if (self.current_token == .LeftBrace) {
            try self.advance();

            var clauses = std.ArrayList(ast.HandlerClause).init(self.allocator);
            while (self.current_token != .RightBrace) {
                const op_name = try self.expectIdentifier();

                // Parse parameter pattern
                var param_pattern: ast.Pattern = undefined;
                if (self.current_token == .LeftParen) {
                    try self.advance();
                    param_pattern = try self.parsePattern();
                    try self.expectToken(.RightParen);
                } else {
                    param_pattern = ast.Pattern{ .Wildcard = {} };
                }

                try self.expectToken(.Arrow);
                const body = try self.parseExpr();

                try clauses.append(.{
                    .operation = op_name,
                    .param_pattern = param_pattern,
                    .body = body,
                    .loc = loc,
                });

                if (self.current_token == .Comma) {
                    try self.advance();
                }
            }

            try self.expectToken(.RightBrace);
            handlers = try clauses.toOwnedSlice();
        }

        return ast.Expression{
            .Try = .{
                .computation = computation,
                .handlers = handlers,
                .loc = loc,
            },
        };
    }
};
