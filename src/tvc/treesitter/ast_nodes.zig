// ═══════════════════════════════════════════════════════════════════════════════
// AST Symbol Extraction
// ═══════════════════════════════════════════════════════════════════════════════
//
// Extract symbols (functions, types, constants, imports) from Tree-sitter AST.
// Supports Zig and VIBEE source files.
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const zig_parser = @import("zig.zig");
const Node = zig_parser.Node;
const Parser = zig_parser.Parser;
const Tree = zig_parser.Tree;
const Point = zig_parser.Point;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Supported programming languages
pub const Language = enum {
    zig,
    vibee,

    pub fn fromExtension(ext: []const u8) ?Language {
        if (std.mem.eql(u8, ext, ".zig")) return .zig;
        if (std.mem.eql(u8, ext, ".vibee")) return .vibee;
        return null;
    }

    pub fn fromPath(path: []const u8) ?Language {
        if (path.len < 4) return null;
        const ext = path[path.len - 5 ..];
        if (ext[0] != '.') return null;
        return fromExtension(ext);
    }
};

/// Kind of symbol extracted from AST
pub const SymbolKind = enum {
    function,
    type,
    constant,
    variable,
    parameter,
    struct_field,
    enum_variant,
    import,
    module,
    @"test",

    pub fn jsonStringify(value: SymbolKind, allocator: Allocator) ![]const u8 {
        const s = switch (value) {
            .function => "function",
            .type => "type",
            .constant => "constant",
            .variable => "variable",
            .parameter => "parameter",
            .struct_field => "struct_field",
            .enum_variant => "enum_variant",
            .import => "import",
            .module => "module",
            .@"test" => "test",
        };
        return std.fmt.allocPrint(allocator, "\"{s}\"", .{s});
    }
};

/// A symbol extracted from source code
pub const Symbol = struct {
    id: u64,
    kind: SymbolKind,
    name: []const u8,
    qualified_name: []const u8,
    signature: ?[]const u8,
    doc_comment: ?[]const u8,
    file_path: []const u8,
    line: u32,
    column: u32,
    language: Language,
    context: []const u8,
    imports: std.ArrayList([]const u8),

    /// Create a new symbol (caller owns returned memory)
    pub fn init(
        allocator: Allocator,
        id: u64,
        kind: SymbolKind,
        name: []const u8,
        file_path: []const u8,
        line: u32,
        column: u32,
        language: Language,
    ) !Symbol {
        return Symbol{
            .id = id,
            .kind = kind,
            .name = try allocator.dupe(u8, name),
            .qualified_name = try allocator.dupe(u8, name), // DEFERRED (v12): build qualified name (module.submodule.symbol)
            .signature = null,
            .doc_comment = null,
            .file_path = try allocator.dupe(u8, file_path),
            .line = line,
            .column = column,
            .language = language,
            .context = "",
            .imports = std.ArrayList([]const u8).init(allocator),
        };
    }

    /// Free symbol's allocated memory
    pub fn deinit(self: *Symbol) void {
        self.imports.deinit();
        // Note: other fields are slices into source or owned by allocator
    }

    /// Generate searchable text from symbol
    pub fn toSearchText(self: *const Symbol, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);

        // Format: kind:name:signature:doc
        try buffer.appendSlice(@tagName(self.kind));
        try buffer.append(':');
        try buffer.appendSlice(self.name);

        if (self.signature) |sig| {
            try buffer.appendSlice(":");
            try buffer.appendSlice(sig);
        }

        if (self.doc_comment) |doc| {
            try buffer.appendSlice(":");
            try buffer.appendSlice(doc);
        }

        if (self.context.len > 0) {
            try buffer.appendSlice(":");
            try buffer.appendSlice(self.context);
        }

        return buffer.toOwnedSlice();
    }
};

/// Result of extracting symbols from a file
pub const ExtractResult = struct {
    symbols: std.ArrayList(Symbol),
    imports: std.ArrayList([]const u8),
    module_name: ?[]const u8,

    pub fn init(allocator: Allocator) ExtractResult {
        return .{
            .symbols = std.ArrayList(Symbol).init(allocator),
            .imports = std.ArrayList([]const u8).init(allocator),
            .module_name = null,
        };
    }

    pub fn deinit(self: *ExtractResult) void {
        for (self.symbols.items) |*sym| {
            sym.deinit();
        }
        self.symbols.deinit();
        self.imports.deinit();
        if (self.module_name) |name| {
            self.symbols.items.allocator.free(name);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Symbol extractor for a specific language
pub const Extractor = struct {
    allocator: Allocator,
    language: Language,
    file_path: []const u8,
    source: []const u8,
    next_id: u64 = 1,

    /// Extract all symbols from parsed tree
    pub fn extract(
        self: *Extractor,
        tree: *Tree,
    ) !ExtractResult {
        var result = ExtractResult.init(self.allocator);
        const root = tree.root();

        // Extract imports first
        try self.extractImports(root, &result);

        // Extract module declaration if present
        try self.extractModule(root, &result);

        // Extract declarations based on language
        switch (self.language) {
            .zig => try self.extractZigDeclarations(root, &result),
            .vibee => try self.extractVibeeDeclarations(root, &result),
        }

        return result;
    }

    /// Extract import statements
    fn extractImports(self: *const Extractor, node: Node, result: *ExtractResult) !void {
        var iter = node.iterateChildren();

        while (iter.next()) |child| {
            if (!child.isNamed()) continue;

            const node_type = child.getType();

            // Zig: import_statement, builtin_identifier
            // VIBEE: import
            if (std.mem.eql(u8, node_type, "import_statement") or
                std.mem.eql(u8, node_type, "import") or
                std.mem.eql(u8, node_type, "@import"))
            {
                const import_text = child.text(self.source);
                // Try to extract module name from import
                if (try self.parseImport(import_text)) |module| {
                    try result.imports.append(module);
                }
            }

            // Recurse into children
            try self.extractImports(child, result);
        }
    }

    /// Parse module name from import statement
    fn parseImport(self: *const Extractor, import_text: []const u8) !?[]const u8 {
        // Simple extraction: look for quoted strings in import
        var start: ?usize = null;
        var in_string = false;

        for (import_text, 0..) |c, i| {
            if (c == '"') {
                if (start == null) {
                    start = i + 1;
                    in_string = true;
                } else {
                    in_string = false;
                    const module = import_text[start.?..i];
                    return try self.allocator.dupe(u8, module);
                }
            }
        }

        // Fallback: return entire import text trimmed
        return null;
    }

    /// Extract module name declaration
    fn extractModule(self: *const Extractor, node: Node, result: *ExtractResult) !void {
        _ = self;
        _ = node;
        _ = result;
        // DEFERRED (v12): Parse module declaration if present (e.g., "const std = @import("std");")
        // Requires: AST pattern matching for import statements
    }

    /// Extract Zig declarations (functions, types, constants, tests)
    fn extractZigDeclarations(self: *Extractor, node: Node, result: *ExtractResult) !void {
        var iter = node.iterateChildren();

        while (iter.next()) |child| {
            if (!child.isNamed()) continue;

            const node_type = child.getType();

            // Top-level declarations
            if (std.mem.eql(u8, node_type, "FnProto") or
                std.mem.eql(u8, node_type, "FunctionDefinition"))
            {
                if (try self.extractFunction(child)) |sym| {
                    try result.symbols.append(sym);
                }
            } else if (std.mem.eql(u8, node_type, "ContainerDecl") or
                std.mem.eql(u8, node_type, "StructDecl"))
            {
                if (try self.extractType(child)) |sym| {
                    try result.symbols.append(sym);
                }
            } else if (std.mem.eql(u8, node_type, "VarDecl")) {
                if (try self.extractConstant(child)) |sym| {
                    try result.symbols.append(sym);
                }
            } else if (std.mem.eql(u8, node_type, "TestDecl")) {
                if (try self.extractTest(child)) |sym| {
                    try result.symbols.append(sym);
                }
            }
        }
    }

    /// Extract VIBEE declarations
    fn extractVibeeDeclarations(self: *Extractor, node: Node, result: *ExtractResult) !void {
        var iter = node.iterateChildren();

        while (iter.next()) |child| {
            if (!child.isNamed()) continue;

            const node_type = child.getType();

            // VIBEE-specific node types
            if (std.mem.eql(u8, node_type, "function_definition") or
                std.mem.eql(u8, node_type, "tool_definition"))
            {
                if (try self.extractFunction(child)) |sym| {
                    try result.symbols.append(sym);
                }
            } else if (std.mem.eql(u8, node_type, "type_definition") or
                std.mem.eql(u8, node_type, "struct_definition"))
            {
                if (try self.extractType(child)) |sym| {
                    try result.symbols.append(sym);
                }
            }
        }
    }

    /// Extract function symbol
    fn extractFunction(self: *Extractor, node: Node) !?Symbol {
        // Find function name
        const name_node = node.childByFieldName(self.source, "name") orelse return null;
        const name = name_node.text(self.source);

        // Get position
        const start = node.startPoint();
        const line = start.toLineNumber();

        // Create symbol
        const id = self.next_id;
        self.next_id += 1;

        var sym = try Symbol.init(
            self.allocator,
            id,
            .function,
            name,
            self.file_path,
            line,
            @intCast(start.column),
            self.language,
        );

        // Extract signature
        const node_text = node.text(self.source);
        // Find first { or : to get signature portion
        const sig_end = std.mem.indexOfScalar(u8, node_text, '{') orelse
            std.mem.indexOfScalar(u8, node_text, ':') orelse node_text.len;
        sym.signature = try self.allocator.dupe(u8, node_text[0..sig_end]);

        // Extract doc comment (preceding comments)
        // DEFERRED (v12): Implement comment extraction
        // Requires: tree-sitter comment node traversal, "///" pattern detection

        // Extract context (first few lines of body)
        if (std.mem.indexOfScalar(u8, node_text, '{')) |brace_start| {
            const body_start = brace_start + 1;
            const snippet_len = @min(200, node_text.len - body_start);
            sym.context = try self.allocator.dupe(u8, node_text[body_start .. body_start + snippet_len]);
        }

        return sym;
    }

    /// Extract type/struct symbol
    fn extractType(self: *Extractor, node: Node) !?Symbol {
        const name_node = node.childByFieldName(self.source, "name") orelse return null;
        const name = name_node.text(self.source);

        const start = node.startPoint();
        const id = self.next_id;
        self.next_id += 1;

        var sym = try Symbol.init(
            self.allocator,
            id,
            .type,
            name,
            self.file_path,
            start.toLineNumber(),
            @intCast(start.column),
            self.language,
        );

        const node_text = node.text(self.source);
        sym.signature = try self.allocator.dupe(u8, node_text);

        return sym;
    }

    /// Extract constant/variable symbol
    fn extractConstant(self: *Extractor, node: Node) !?Symbol {
        const name_node = node.childByFieldName(self.source, "name") orelse return null;
        const name = name_node.text(self.source);

        const start = node.startPoint();
        const id = self.next_id;
        self.next_id += 1;

        return try Symbol.init(
            self.allocator,
            id,
            .constant,
            name,
            self.file_path,
            start.toLineNumber(),
            @intCast(start.column),
            self.language,
        );
    }

    /// Extract test symbol
    fn extractTest(self: *Extractor, node: Node) !?Symbol {
        const name_node = node.childByFieldName(self.source, "name") orelse return null;
        const name = name_node.text(self.source);

        const start = node.startPoint();
        const id = self.next_id;
        self.next_id += 1;

        return try Symbol.init(
            self.allocator,
            id,
            .@"test",
            name,
            self.file_path,
            start.toLineNumber(),
            @intCast(start.column),
            self.language,
        );
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract symbols from a source file
pub fn extractSymbols(
    allocator: Allocator,
    file_path: []const u8,
    source: []const u8,
) !ExtractResult {
    const lang = Language.fromPath(file_path) orelse return error.UnsupportedLanguage;
    const parser = try Parser.init();
    defer parser.deinit();

    // Set language based on file
    const language_fn = switch (lang) {
        .zig => @extern(*const fn () ?*anyopaque, .{ .name = "tree_sitter_zig" }),
        .vibee => return error.VibeeNotSupported, // DEFERRED (v12): implement VIBEE parser (requires tree-sitter-vibee grammar)
    };

    const ts_lang = if (@as(?*anyopaque, @call(.auto, language_fn, .{}))) |l|
        @as(zig_parser.Language, @ptrCast(l))
    else
        return error.LanguageNotFound;

    try parser.setLanguage(ts_lang);

    const tree = try parser.parseString(source);
    defer tree.deinit();

    var extractor = Extractor{
        .allocator = allocator,
        .language = lang,
        .file_path = file_path,
        .source = source,
    };

    return extractor.extract(tree);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Language.fromPath" {
    try std.testing.expectEqual(Language.zig, Language.fromPath("test.zig").?);
    try std.testing.expectEqual(Language.vibee, Language.fromPath("test.vibee").?);
    try std.testing.expect(Language.fromPath("test.txt") == null);
}

test "extractSymbols - simple Zig function" {
    const source =
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;

    const result = extractSymbols(
        std.testing.allocator,
        "test.zig",
        source,
    ) catch |err| {
        if (err == error.LanguageNotFound) {
            std.debug.print("Warning: tree-sitter-zig not available, skipping test\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };
    defer result.deinit();

    try std.testing.expect(result.symbols.items.len >= 1);
    const sym = &result.symbols.items[0];
    try std.testing.expectEqual(SymbolKind.function, sym.kind);
    try std.testing.expectEqualStrings("add", sym.name);
}

test "extractSymbols - Zig constant" {
    const source =
        \\const MAX_ITEMS = 100;
    ;

    const result = extractSymbols(
        std.testing.allocator,
        "test.zig",
        source,
    ) catch |err| {
        if (err == error.LanguageNotFound) return error.SkipZigTest;
        return err;
    };
    defer result.deinit();

    try std.testing.expect(result.symbols.items.len >= 1);
    const sym = &result.symbols.items[0];
    try std.testing.expectEqual(SymbolKind.constant, sym.kind);
    try std.testing.expectEqualStrings("MAX_ITEMS", sym.name);
}

test "Symbol.toSearchText" {
    const allocator = std.testing.allocator;
    var sym = try Symbol.init(
        allocator,
        1,
        .function,
        "add",
        "test.zig",
        10,
        4,
        .zig,
    );
    defer sym.deinit();

    sym.signature = try allocator.dupe(u8, "pub fn add(a: i32, b: i32) i32");

    const text = try sym.toSearchText(allocator);
    defer allocator.free(text);

    try std.testing.expectStringStartsWith("function:add:", text);
}
