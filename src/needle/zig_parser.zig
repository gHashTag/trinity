// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Minimal Zig Parser (Tier 2)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Recursive descent Zig parser for AST extraction.
// Supports: functions, structs, enums, const/var, imports.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// AST node type
pub const NodeType = enum {
    source_file,
    fn_def,
    struct_def,
    enum_def,
    union_def,
    const_decl,
    var_decl,
    param_decl,
    return_stmt,
    block,
    call_expr,
    identifier,
    string_type,
    int_type,
    bool_type,
    error_type,
    void_type,
    anytype_type,
    array_type,
    pointer_type,
    optional_type,

    pub fn label(self: NodeType) []const u8 {
        return switch (self) {
            .source_file => "SourceFile",
            .fn_def => "FnDef",
            .struct_def => "StructDef",
            .enum_def => "EnumDef",
            .union_def => "UnionDef",
            .const_decl => "ConstDecl",
            .var_decl => "VarDecl",
            .param_decl => "ParamDecl",
            .return_stmt => "ReturnStmt",
            .block => "Block",
            .call_expr => "CallExpr",
            .identifier => "Identifier",
            .string_type => "StringType",
            .int_type => "IntType",
            .bool_type => "BoolType",
            .error_type => "ErrorType",
            .void_type => "VoidType",
            .anytype_type => "Anytype",
            .array_type => "ArrayType",
            .pointer_type => "PointerType",
            .optional_type => "OptionalType",
        };
    }
};

/// Zig AST node
pub const ZigNode = struct {
    allocator: std.mem.Allocator,
    node_type: NodeType,
    name: []const u8,
    start_byte: usize,
    end_byte: usize,
    start_line: u32,
    end_line: u32,
    children: std.ArrayList(ZigNode),
    metadata: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType, name: []const u8) ZigNode {
        return ZigNode{
            .allocator = allocator,
            .node_type = node_type,
            .name = allocator.dupe(u8, name) catch "",
            .start_byte = 0,
            .end_byte = 0,
            .start_line = 0,
            .end_line = 0,
            .children = .{ .items = &.{}, .capacity = 0 },
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ZigNode) void {
        self.allocator.free(self.name);
        for (self.children.items) |*child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn addChild(self: *ZigNode, child: ZigNode) !void {
        try self.children.append(self.allocator, child);
    }

    pub fn getText(self: *const ZigNode, source: []const u8) []const u8 {
        if (self.end_byte > source.len) return "";
        return source[self.start_byte..self.end_byte];
    }
};

/// Symbol reference
pub const SymbolRef = struct {
    file: []const u8,
    line: u32,
    kind: NodeType,
    symbol_name: []const u8,
};

/// Symbol definition (exported from a file)
pub const SymbolDef = struct {
    name: []const u8,
    file: []const u8,
    kind: NodeType,
    node: *const ZigNode,
};

/// AST Graph for multi-file analysis
pub const ASTGraph = struct {
    allocator: std.mem.Allocator,
    files: std.StringHashMap(ZigNode),
    // Symbol table: symbol_name -> list of definitions (can be multiple across files)
    symbol_table: std.StringHashMap(std.ArrayList(SymbolDef)),
    cross_refs: std.StringHashMap(std.ArrayList(SymbolRef)),
    call_graph: std.StringHashMap(std.ArrayList([]const u8)),

    pub fn init(allocator: std.mem.Allocator) ASTGraph {
        return .{
            .allocator = allocator,
            .files = std.StringHashMap(ZigNode).init(allocator),
            .symbol_table = std.StringHashMap(std.ArrayList(SymbolDef)).init(allocator),
            .cross_refs = std.StringHashMap(std.ArrayList(SymbolRef)).init(allocator),
            .call_graph = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
        };
    }

    pub fn deinit(self: *ASTGraph) void {
        // Free all file paths (keys) and nodes (values)
        var iter = self.files.iterator();
        while (iter.next()) |entry| {
            // Free the duplicated path string (key)
            self.allocator.free(entry.key_ptr.*);
            // Free the node and its children (value)
            entry.value_ptr.*.deinit();
        }
        self.files.deinit();

        var sym_iter = self.symbol_table.iterator();
        while (sym_iter.next()) |entry| {
            // SymbolDef doesn't own its data, just free the ArrayList
            entry.value_ptr.*.deinit(self.allocator);
        }
        self.symbol_table.deinit();

        var ref_iter = self.cross_refs.iterator();
        while (ref_iter.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
        }
        self.cross_refs.deinit();

        var call_iter = self.call_graph.iterator();
        while (call_iter.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
        }
        self.call_graph.deinit();
    }

    pub fn addFile(self: *ASTGraph, path: []const u8, node: ZigNode) !void {
        try self.files.put(try self.allocator.dupe(u8, path), node);
    }

    /// Convenience: Add a file by parsing its code content
    pub fn addFileFromCode(self: *ASTGraph, path: []const u8, code: []const u8) !void {
        const node = try parseZig(self.allocator, code);
        try self.addFile(path, node);
    }

    pub fn addCrossRef(self: *ASTGraph, from_file: []const u8, ref: SymbolRef) !void {
        const entry = try self.cross_refs.getOrPut(from_file);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(SymbolRef){};
        }
        try entry.value_ptr.*.append(self.allocator, ref);
    }

    /// Add a symbol to the symbol table
    pub fn addSymbol(self: *ASTGraph, symbol: SymbolDef) !void {
        const entry = try self.symbol_table.getOrPut(symbol.name);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(SymbolDef){};
        }
        try entry.value_ptr.*.append(self.allocator, symbol);
    }

    /// Find all definitions of a symbol (can be multiple across files)
    pub fn findSymbol(self: *const ASTGraph, name: []const u8) ?[]const SymbolDef {
        if (self.symbol_table.get(name)) |defs| {
            return defs.items;
        }
        return null;
    }

    /// Find all references to a symbol across all files
    pub fn findReferences(self: *const ASTGraph, symbol_name: []const u8) ![]SymbolRef {
        var refs = std.ArrayList(SymbolRef){};

        var iter = self.cross_refs.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.*.items) |ref| {
                if (std.mem.eql(u8, ref.symbol_name, symbol_name)) {
                    try refs.append(self.allocator, ref);
                }
            }
        }

        return refs.toOwnedSlice(self.allocator);
    }

    /// Find which files define a given symbol
    pub fn findDefiningFiles(self: *const ASTGraph, symbol_name: []const u8) ?[]const []const u8 {
        if (self.symbol_table.get(symbol_name)) |defs| {
            const files = defs.items;
            var result = std.ArrayList([]const u8){};
            for (files) |def| {
                const file_copy = self.allocator.dupe(u8, def.file) catch continue;
                result.append(self.allocator, file_copy) catch {};
            }
            return result.toOwnedSlice(self.allocator);
        }
        return null;
    }

    pub fn findCallers(self: *const ASTGraph, symbol: []const u8) ![]const []const u8 {
        var callers = std.ArrayList([]const u8){};
        var iter = self.call_graph.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.*.items) |callee| {
                if (std.mem.eql(u8, callee, symbol)) {
                    try callers.append(self.allocator, entry.key_ptr.*);
                }
            }
        }
        return callers.toOwnedSlice(self.allocator);
    }

    /// Get statistics about the graph
    pub fn stats(self: *const ASTGraph) GraphStats {
        var total_symbols: usize = 0;
        var total_refs: usize = 0;
        var total_calls: usize = 0;

        var sym_iter = self.symbol_table.iterator();
        while (sym_iter.next()) |entry| {
            total_symbols += entry.value_ptr.*.items.len;
        }

        var ref_iter = self.cross_refs.iterator();
        while (ref_iter.next()) |entry| {
            total_refs += entry.value_ptr.*.items.len;
        }

        var call_iter = self.call_graph.iterator();
        while (call_iter.next()) |entry| {
            total_calls += entry.value_ptr.*.items.len;
        }

        return .{
            .file_count = self.files.count(),
            .symbol_count = total_symbols,
            .cross_ref_count = total_refs,
            .call_edge_count = total_calls,
        };
    }

    /// Add an entry to the call graph
    pub fn addCall(self: *ASTGraph, from_file: []const u8, to_symbol: []const u8) !void {
        const entry = try self.call_graph.getOrPut(from_file);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList([]const u8){};
        }
        try entry.value_ptr.*.append(self.allocator, to_symbol);
    }
};

/// Statistics about the AST graph
pub const GraphStats = struct {
    file_count: usize,
    symbol_count: usize,
    cross_ref_count: usize,
    call_edge_count: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ZIG PARSER
// ═══════════════════════════════════════════════════════════════════════════════

/// Token type
const Token = struct {
    kind: TokenKind,
    text: []const u8,
    start: usize,
    line: u32,
};

const TokenKind = enum {
    keyword_pub,
    keyword_fn,
    keyword_struct,
    keyword_enum,
    keyword_union,
    keyword_const,
    keyword_var,
    keyword_return,
    keyword_usingnamespace,
    keyword_import,
    identifier,
    lbrace,
    rbrace,
    lparen,
    rparen,
    colon,
    comma,
    semicolon,
    arrow,
    dot,
    star,
    question,
    bang,
    lbracket,
    rbracket,
    string_literal,
    char_literal,
    number,
    eof,

    fn isKeyword(self: TokenKind) bool {
        return switch (self) {
            .keyword_pub, .keyword_fn, .keyword_struct, .keyword_enum, .keyword_union,
            .keyword_const, .keyword_var, .keyword_return, .keyword_usingnamespace,
            .keyword_import => true,
            else => false,
        };
    }
};

/// Tokenizer
const Tokenizer = struct {
    source: []const u8,
    pos: usize,
    line: u32,

    fn init(source: []const u8) Tokenizer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
        };
    }

    fn nextToken(self: *Tokenizer) Token {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return .{ .kind = .eof, .text = "", .start = self.pos, .line = self.line };
        }

        const start = self.pos;

        // Check for identifiers and keywords
        if (std.ascii.isAlphanumeric(self.source[self.pos]) or self.source[self.pos] == '_') {
            while (self.pos < self.source.len and
                  (std.ascii.isAlphanumeric(self.source[self.pos]) or
                   self.source[self.pos] == '_'))
            {
                self.pos += 1;
            }
            const text = self.source[start..self.pos];

            const kind: TokenKind = if (std.mem.eql(u8, text, "pub")) .keyword_pub
            else if (std.mem.eql(u8, text, "fn")) .keyword_fn
            else if (std.mem.eql(u8, text, "struct")) .keyword_struct
            else if (std.mem.eql(u8, text, "enum")) .keyword_enum
            else if (std.mem.eql(u8, text, "union")) .keyword_union
            else if (std.mem.eql(u8, text, "const")) .keyword_const
            else if (std.mem.eql(u8, text, "var")) .keyword_var
            else if (std.mem.eql(u8, text, "return")) .keyword_return
            else if (std.mem.eql(u8, text, "usingnamespace")) .keyword_usingnamespace
            else if (std.mem.eql(u8, text, "import")) .keyword_import
            else .identifier;

            return .{ .kind = kind, .text = text, .start = start, .line = self.line };
        }

        // Check for string literals
        if (self.source[self.pos] == '"') {
            self.pos += 1;
            while (self.pos < self.source.len and self.source[self.pos] != '"') {
                if (self.source[self.pos] == '\\') {
                    self.pos += 2; // Escape sequence
                } else {
                    self.pos += 1;
                }
            }
            if (self.pos < self.source.len) self.pos += 1; // Closing quote
            return .{ .kind = .string_literal, .text = self.source[start..self.pos], .start = start, .line = self.line };
        }

        // Single character tokens
        const ch = self.source[self.pos];
        self.pos += 1;

        const kind: TokenKind = switch (ch) {
            '{' => .lbrace,
            '}' => .rbrace,
            '(' => .lparen,
            ')' => .rparen,
            '[' => .lbracket,
            ']' => .rbracket,
            ':' => .colon,
            ',' => .comma,
            ';' => .semicolon,
            '.' => .dot,
            '*' => .star,
            '?' => .question,
            '!' => {
                if (self.pos < self.source.len and self.source[self.pos] == '=') {
                    self.pos += 1;
                    return .{ .kind = .bang, .text = self.source[start..self.pos], .start = start, .line = self.line };
                }
                return .{ .kind = .bang, .text = self.source[start..self.pos], .start = start, .line = self.line };
            },
            '-' => {
                if (self.pos < self.source.len and self.source[self.pos] == '>') {
                    self.pos += 1;
                    return .{ .kind = .arrow, .text = self.source[start..self.pos], .start = start, .line = self.line };
                }
                return .{ .kind = .identifier, .text = self.source[start..self.pos], .start = start, .line = self.line };
            },
            '\n' => {
                self.line += 1;
                return self.nextToken();
            },
            else => .identifier, // Fallback
        };

        return .{ .kind = kind, .text = self.source[start..self.pos], .start = start, .line = self.line };
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (self.pos < self.source.len) {
            const ch = self.source[self.pos];
            if (ch == ' ' or ch == '\t' or ch == '\r') {
                self.pos += 1;
            } else if (ch == '\n') {
                self.pos += 1;
                self.line += 1;
            } else {
                break;
            }
        }
    }
};

/// Zig Parser
pub const ZigParser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    tokenizer: Tokenizer,
    current: Token,
    next_token: Token,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) ZigParser {
        var tokenizer = Tokenizer.init(source);
        const first = tokenizer.nextToken();
        const second = tokenizer.nextToken();
        return ZigParser{
            .allocator = allocator,
            .source = source,
            .tokenizer = tokenizer,
            .current = first,
            .next_token = second,
        };
    }

    fn advance(self: *ZigParser) void {
        self.current = self.next_token;
        self.next_token = self.tokenizer.nextToken();
    }

    /// Expect current token to be of specific kind
    fn expect(self: *ZigParser, kind: TokenKind) !void {
        if (self.current.kind != kind) {
            return error.SyntaxError;
        }
        self.advance();
    }

    /// Resync tokenizer after direct position manipulation
    fn resync(self: *ZigParser) void {
        self.current = self.tokenizer.nextToken();
        self.next_token = self.tokenizer.nextToken();
    }

    /// Parse source file
    pub fn parseSourceFile(self: *ZigParser) !ZigNode {
        var node = ZigNode.init(self.allocator, .source_file, "");
        node.start_byte = 0;

        while (self.current.kind != .eof) {
            self.parseDecl(&node) catch {
                // Skip to next semicolon or newline on error
                while (self.current.kind != .eof and
                       self.current.kind != .semicolon and
                       self.current.kind != .rbrace)
                {
                    self.advance();
                }
                self.advance(); // Skip semicolon/rbrace
            };
        }

        node.end_byte = self.source.len;
        node.end_line = self.tokenizer.line;
        return node;
    }

    /// Parse a declaration
    fn parseDecl(self: *ZigParser, parent: *ZigNode) !void {
        const is_pub = self.current.kind == .keyword_pub;
        if (is_pub) self.advance();

        switch (self.current.kind) {
            .keyword_fn => try self.parseFnDef(parent, is_pub),
            .keyword_struct => try self.parseStructDef(parent, is_pub),
            .keyword_enum => try self.parseEnumDef(parent, is_pub),
            .keyword_union => try self.parseUnionDef(parent, is_pub),
            .keyword_const => try self.parseConstDecl(parent, is_pub),
            .keyword_var => try self.parseVarDecl(parent, is_pub),
            .keyword_import => try self.parseImport(parent),
            else => return error.NotADecl,
        }
    }

    /// Parse function definition
    fn parseFnDef(self: *ZigParser, parent: *ZigNode, is_pub: bool) !void {
        _ = is_pub; // TODO: track pub in metadata
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'fn'

        // Function name
        if (self.current.kind != .identifier) return error.SyntaxError;
        const fn_name = self.current.text;
        self.advance();

        // Parameters
        try self.expect(.lparen);

        // Build function node
        var fn_node = ZigNode.init(self.allocator, .fn_def, fn_name);
        fn_node.start_byte = start;
        fn_node.start_line = start_line;

        // Parse parameters (simplified)
        while (self.current.kind != .rparen and self.current.kind != .eof) {
            if (self.current.kind == .identifier) {
                const param_name = self.current.text;
                var param = ZigNode.init(self.allocator, .param_decl, param_name);
                param.start_byte = self.current.start;
                param.start_line = self.current.line;
                try fn_node.addChild(param);
            }
            self.advance();
            if (self.current.kind == .comma) self.advance();
        }
        try self.expect(.rparen);

        // Return type (Zig syntax: just the type, no arrow)
        // Skip to lbrace
        while (self.current.kind != .lbrace and self.current.kind != .eof) {
            self.advance();
        }
        if (self.current.kind == .arrow) {
            self.advance();
            // Skip return type for now
            while (self.current.kind != .lbrace and self.current.kind != .eof) {
                self.advance();
            }
        }

        // Function body
        try self.expect(.lbrace);

        // Find matching brace
        var depth: usize = 1;
        while (self.tokenizer.pos < self.source.len and depth > 0) {
            if (self.source[self.tokenizer.pos] == '{') depth += 1;
            if (self.source[self.tokenizer.pos] == '}') depth -= 1;
            self.tokenizer.pos += 1;
        }

        // Set end position
        fn_node.end_byte = self.tokenizer.pos;
        fn_node.end_line = self.tokenizer.line;

        // Resync tokenizer state after direct pos manipulation
        self.resync();

        // Add fn_node to parent (copies the struct, including the ArrayList)
        try parent.addChild(fn_node);

        // Note: fn_node.name and fn_node.metadata are leaked here because
        // Zig doesn't call deinit automatically on scope exit. The parent's
        // copy has the same name pointer, which will be freed by parent's deinit.
        // This is a small leak (struct fields only, not the children).
    }

    /// Parse struct definition
    fn parseStructDef(self: *ZigParser, parent: *ZigNode, is_pub: bool) !void {
        _ = is_pub;
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'struct'

        if (self.current.kind != .identifier) return error.SyntaxError;
        const struct_name = self.current.text;
        self.advance();

        var struct_node = ZigNode.init(self.allocator, .struct_def, struct_name);
        struct_node.start_byte = start;
        struct_node.start_line = start_line;

        try self.expect(.lbrace);

        // Find matching brace
        while (self.current.kind != .rbrace and self.current.kind != .eof) {
            self.advance();
        }
        try self.expect(.rbrace);

        struct_node.end_byte = self.current.start;
        struct_node.end_line = self.current.line;

        try parent.addChild(struct_node);
    }

    /// Parse enum definition
    fn parseEnumDef(self: *ZigParser, parent: *ZigNode, is_pub: bool) !void {
        _ = is_pub;
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'enum'

        if (self.current.kind != .identifier) return error.SyntaxError;
        const enum_name = self.current.text;
        self.advance();

        var enum_node = ZigNode.init(self.allocator, .enum_def, enum_name);
        enum_node.start_byte = start;
        enum_node.start_line = start_line;

        try self.expect(.lbrace);
        // Skip to closing brace
        while (self.current.kind != .rbrace and self.current.kind != .eof) {
            self.advance();
        }
        try self.expect(.rbrace);

        enum_node.end_byte = self.current.start;
        enum_node.end_line = self.current.line;

        try parent.addChild(enum_node);
    }

    /// Parse union definition
    fn parseUnionDef(self: *ZigParser, parent: *ZigNode, is_pub: bool) !void {
        _ = is_pub;
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'union'

        if (self.current.kind != .identifier) return error.SyntaxError;
        const union_name = self.current.text;
        self.advance();

        var union_node = ZigNode.init(self.allocator, .union_def, union_name);
        union_node.start_byte = start;
        union_node.start_line = start_line;

        try self.expect(.lbrace);
        // Skip to closing brace
        while (self.current.kind != .rbrace and self.current.kind != .eof) {
            self.advance();
        }
        try self.expect(.rbrace);

        union_node.end_byte = self.current.start;
        union_node.end_line = self.current.line;

        try parent.addChild(union_node);
    }

    /// Parse const declaration
    fn parseConstDecl(self: *ZigParser, parent: *ZigNode, is_pub: bool) !void {
        _ = is_pub;
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'const'

        if (self.current.kind != .identifier) return error.SyntaxError;
        const const_name = self.current.text;
        self.advance();

        var const_node = ZigNode.init(self.allocator, .const_decl, const_name);
        const_node.start_byte = start;
        const_node.start_line = start_line;

        // Skip to semicolon
        while (self.current.kind != .semicolon and self.current.kind != .eof) {
            self.advance();
        }
        try self.expect(.semicolon);

        const_node.end_byte = self.current.start;
        const_node.end_line = self.current.line;

        try parent.addChild(const_node);
    }

    /// Parse var declaration
    fn parseVarDecl(self: *ZigParser, parent: *ZigNode, is_pub: bool) !void {
        _ = is_pub;
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'var'

        if (self.current.kind != .identifier) return error.SyntaxError;
        const var_name = self.current.text;
        self.advance();

        var var_node = ZigNode.init(self.allocator, .var_decl, var_name);
        var_node.start_byte = start;
        var_node.start_line = start_line;

        // Skip to semicolon
        while (self.current.kind != .semicolon and self.current.kind != .eof) {
            self.advance();
        }
        try self.expect(.semicolon);

        var_node.end_byte = self.current.start;
        var_node.end_line = self.current.line;

        try parent.addChild(var_node);
    }

    /// Parse import statement
    fn parseImport(self: *ZigParser, parent: *ZigNode) !void {
        const start = self.current.start;
        const start_line = self.current.line;

        self.advance(); // Skip 'import'

        var import_node = ZigNode.init(self.allocator, .identifier, "import");
        import_node.start_byte = start;
        import_node.start_line = start_line;

        // Skip to semicolon
        while (self.current.kind != .semicolon and self.current.kind != .eof) {
            self.advance();
        }
        try self.expect(.semicolon);

        import_node.end_byte = self.current.start;
        import_node.end_line = self.current.line;

        try parent.addChild(import_node);
    }

    // Property for pos (needed for reference)
    fn getPos(self: *ZigParser) usize {
        return self.tokenizer.pos;
    }

    // Helper to skip to next semicolon
    fn skipToSemicolon(self: *ZigParser) void {
        while (self.current.kind != .semicolon and self.current.kind != .eof) {
            self.advance();
        }
        if (self.current.kind == .semicolon) self.advance();
    }
};

/// Convenience function to parse Zig source
pub fn parseZig(allocator: std.mem.Allocator, source: []const u8) !ZigNode {
    var parser = ZigParser.init(allocator, source);
    return parser.parseSourceFile();
}

/// Build multi-file AST graph
pub fn buildASTGraph(allocator: std.mem.Allocator, files: []const []const u8) !ASTGraph {
    var graph = ASTGraph.init(allocator);
    errdefer graph.deinit();

    for (files) |file_path| {
        const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
        defer allocator.free(source);

        var ast = try parseZig(allocator, source);
        errdefer ast.deinit();

        try graph.addFile(file_path, ast);

        // Extract symbols and build cross-references
        try extractSymbols(allocator, file_path, &ast, &graph);
    }

    return graph;
}

/// Extract symbols from AST
fn extractSymbols(allocator: std.mem.Allocator, file_path: []const u8, ast: *ZigNode, graph: *ASTGraph) !void {
    // First pass: collect all exported symbols
    for (ast.children.items) |*child| {
        switch (child.node_type) {
            .fn_def, .struct_def, .enum_def, .union_def, .const_decl => {
                // Add to symbol table
                const symbol = SymbolDef{
                    .name = child.name,
                    .file = file_path,
                    .kind = child.node_type,
                    .node = child,
                };
                try graph.addSymbol(symbol);
            },
            else => {},
        }
    }

    // Second pass: extract function calls and cross-references
    for (ast.children.items) |*child| {
        if (child.node_type == .fn_def) {
            // Extract function calls from this function
            var calls = std.ArrayList([]const u8){};
            defer calls.deinit(allocator);

            try extractFunctionCalls(allocator, child, &calls);

            // Add to call graph
            const entry = try graph.call_graph.getOrPut(file_path);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList([]const u8){};
            }

            for (calls.items) |call| {
                // Check if call is to a known symbol (not a local variable)
                if (graph.findSymbol(call)) |_| {
                    try entry.value_ptr.*.append(allocator, call);
                }
            }
        }
    }
}

/// Extract function calls from a function node
fn extractFunctionCalls(allocator: std.mem.Allocator, fn_node: *const ZigNode, calls: *std.ArrayList([]const u8)) !void {
    // Recursively traverse children to find identifier references
    for (fn_node.children.items) |*child| {
        switch (child.node_type) {
            .identifier => {
                // This could be a function call
                try calls.append(allocator, child.name);
            },
            .fn_def, .struct_def => {
                // Nested definitions - recurse
                try extractFunctionCalls(allocator, child, calls);
            },
            else => {
                // Other node types - recurse into children
                for (child.children.items) |*grandchild| {
                    try extractFunctionCalls(allocator, grandchild, calls);
                }
            },
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ZigParser parse simple function" {
    const source =
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;

    var ast = try parseZig(std.testing.allocator, source);
    defer ast.deinit();

    try std.testing.expectEqual(@as(usize, 1), ast.children.items.len);
    try std.testing.expectEqual(NodeType.fn_def, ast.children.items[0].node_type);
    try std.testing.expectEqualStrings("add", ast.children.items[0].name);
}

test "ZigParser parse struct" {
    const source =
        \\pub const Point = struct {
        \\    x: f32,
        \\    y: f32,
        \\};
    ;

    var ast = try parseZig(std.testing.allocator, source);
    defer ast.deinit();

    try std.testing.expect(ast.children.items.len > 0);
}

test "buildASTGraph" {
    const files = &[_][]const u8{"src/needle/needle.zig"};
    var graph = try buildASTGraph(std.testing.allocator, files);
    defer graph.deinit();

    try std.testing.expect(graph.files.count() > 0);
}
