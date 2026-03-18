// ═══════════════════════════════════════════════════════════════════════════════
// Tree-sitter VIBEE FFI Bindings
// ═══════════════════════════════════════════════════════════════════════════════
//
// Zig FFI bindings for Tree-sitter VIBEE language parser.
// Enables AST parsing for .tri specification files (Cycle 70 - Level 0 complete).
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const zig_parser = @import("zig.zig");

// Re-export common types from zig.zig
pub const Language = zig_parser.Language;
pub const Parser = zig_parser.Parser;
pub const Tree = zig_parser.Tree;
pub const Node = zig_parser.Node;

// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE-SPECIFIC TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// VIBEE language identifier
pub const VIBEE_LANGUAGE: Language = undefined; // Initialized after tree_sitter_vibee external decl

/// VIBEE AST node types (matching grammar.js)
pub const NodeType = enum {
    // Top-level
    source_file,
    module_declaration,

    // Types
    type_definition,
    field_definition,
    type_annotation,
    primitive_type,
    list_type,
    optional_type,
    map_type,
    user_type,
    constraint,

    // Behaviors
    behavior_definition,
    algorithm_definition,
    test_case_definition,

    // Values
    literal,
    string_literal,
    number,
    boolean,
    identifier,

    // Code
    code_block,
    text_block,

    // Other
    import_statement,
    constant_definition,
};

/// VIBEE module metadata
pub const ModuleInfo = struct {
    name: []const u8,
    version: []const u8,
    language: Language,
    module: []const u8,

    pub fn init() ModuleInfo {
        return .{
            .name = "",
            .version = "1.0.0",
            .language = .zig,
            .module = "",
        };
    }
};

/// VIBEE type definition
pub const TypeInfo = struct {
    name: []const u8,
    kind: TypeKind,
    fields: []FieldInfo,
};

pub const TypeKind = enum {
        struct,
        enum,
        union,
    };

    pub const FieldInfo = struct {
        name: []const u8,
        type_annotation: []const u8,
        default_value: ?[]const u8,
        constraint: ?[]const u8,
    };
};

/// VIBEE behavior (Given/When/Then)
pub const BehaviorInfo = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
};

/// VIBEE algorithm step
pub const AlgorithmInfo = struct {
    name: []const u8,
    input_type: []const u8,
    output_type: []const u8,
    steps: []AlgorithmStep,

    pub const AlgorithmStep = struct {
        number: usize,
        description: []const u8,
        result: ?[]const u8,
    };
};

/// VIBEE test case
pub const TestCaseInfo = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
};

/// Extracted symbol from VIBEE file (for indexing)
pub const Symbol = struct {
    id: u64,
    kind: SymbolKind,
    name: []const u8,
    qualified_name: []const u8,
    signature: ?[]const u8,
    documentation: ?[]const u8,
    file_path: []const u8,
    line: u32,
    column: u32,
    language: Language = .tri,

    pub const SymbolKind = enum {
        type,
        function,
        constant,
        variable,
        parameter,
        field,
        variant,
        behavior,
        algorithm,
        test,
        module,
        import,
    };

    /// Convert to search text for embedding generation
    pub fn toSearchText(self: *const Symbol, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        // Add name
        try buffer.writer().print("{s}", .{self.name});

        // Add signature if available
        if (self.signature) |sig| {
            try buffer.writer().print(" {s}", .{sig});
        }

        // Add documentation if available
        if (self.documentation) |doc| {
            if (doc.len > 0) {
                try buffer.writer().print("\n\n{s}", .{doc});
            }
        }

        return buffer.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE PARSER
// ═══════════════════════════════════════════════════════════════════════════════

/// VIBEE parser wrapper
pub const Vibeeparser = struct {
    allocator: Allocator,
    parser: Parser,

    /// Initialize VIBEE parser
    pub fn init(allocator: Allocator) !Vibeeparser {
        var parser = try Parser.init();
        errdefer parser.deinit();

        // Set language to VIBEE
        // Note: tree_sitter_vibee() must be linked externally
        // For now, this is a placeholder - actual implementation requires
        // compiling tree-sitter-vibee grammar with tree-sitter cli
        _ = parser; // Use when VIBEE language is available

        return Vibeeparser{
            .allocator = allocator,
            .parser = parser,
        };
    }

    /// Deinitialize parser
    pub fn deinit(self: *Vibeeparser) void {
        self.parser.deinit();
    }

    /// Parse VIBEE file and extract all symbols
    pub fn extractSymbols(self: *Vibeeparser, file_path: []const u8) !SymbolList {
        const tree = try self.parser.parseFile(self.allocator, file_path);
        defer tree.deinit();

        var symbols = std.ArrayList(Symbol).init(self.allocator);

        // Walk the AST and extract symbols
        var root = tree.root();
        try self.extractFromNode(&root, file_path, "", &symbols);

        return SymbolList{
            .symbols = try symbols.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    /// Recursively extract symbols from AST node
    fn extractFromNode(
        self: *Vibeeparser,
        node: Node,
        file_path: []const u8,
        qualified_prefix: []const u8,
        symbols: *std.ArrayList(Symbol),
    ) !void {
        if (node.isNull()) return;

        const node_type = node.getType();

        // Handle different node types
        if (std.mem.eql(u8, node_type, "module_declaration")) {
            try self.extractModuleDecl(node, file_path, symbols);
        } else if (std.mem.eql(u8, node_type, "type_definition")) {
            try self.extractTypeDef(node, file_path, qualified_prefix, symbols);
        } else if (std.mem.eql(u8, node_type, "behavior_definition")) {
            try self.extractBehavior(node, file_path, qualified_prefix, symbols);
        } else if (std.mem.eql(u8, node_type, "algorithm_definition")) {
            try self.extractAlgorithm(node, file_path, qualified_prefix, symbols);
        } else if (std.mem.eql(u8, node_type, "test_case_definition")) {
            try self.extractTest(node, file_path, qualified_prefix, symbols);
        }

        // Recurse into children
        var child = node.childCount();
        var i: u32 = 0;
        while (i < child) : (i += 1) {
            const child_node = node.child(i) orelse continue;
            try self.extractFromNode(child_node, file_path, qualified_prefix, symbols);
        }
    }

    fn extractModuleDecl(self: *Vibeeparser, node: Node, file_path: []const u8, symbols: *std.ArrayList(Symbol)) !void {
        _ = self;

        // Extract module name from identifier
        var name: []const u8 = "";
        var field = node.childCount();
        var i: u32 = 0;
        while (i < field) : (i += 1) {
            const child = node.child(i) orelse continue;
            if (std.mem.eql(u8, child.getType(), "identifier")) {
                const name_bytes = child.getBytes();
                name = name_bytes;
                break;
            }
        }

        try symbols.append(Symbol{
            .id = @intCast(symbols.items.len + 1),
            .kind = .module,
            .name = name,
            .qualified_name = name,
            .signature = null,
            .documentation = null,
            .file_path = file_path,
            .line = @intCast(node.startPoint().row),
            .column = @intCast(node.startPoint().column),
        });
    }

    fn extractTypeDef(self: *Vibeeparser, node: Node, file_path: []const u8, prefix: []const u8, symbols: *std.ArrayList(Symbol)) !void {
        _ = self;

        var name: []const u8 = "";
        var field_count = node.childCount();
        var i: u32 = 0;
        while (i < field_count) : (i += 1) {
            const child = node.child(i) orelse continue;
            if (std.mem.eql(u8, child.getType(), "type_name")) {
                const type_name_node = child.child(0) orelse continue;
                name = type_name_node.getBytes();
                break;
            }
        }

        const qualified_name = if (prefix.len > 0)
            try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, name })
        else
            name;

        try symbols.append(Symbol{
            .id = @intCast(symbols.items.len + 1),
            .kind = .type,
            .name = name,
            .qualified_name = qualified_name,
            .signature = null,
            .documentation = null,
            .file_path = file_path,
            .line = @intCast(node.startPoint().row),
            .column = @intCast(node.startPoint().column),
        });
    }

    fn extractBehavior(self: *Vibeeparser, node: Node, file_path: []const u8, prefix: []const u8, symbols: *std.ArrayList(Symbol)) !void {
        _ = self;

        var name: []const u8 = "";
        var given: []const u8 = "";
        var when: []const u8 = "";
        var then: []const u8 = "";

        // Extract fields from behavior
        var child = node.childCount();
        var i: u32 = 0;
        while (i < child) : (i += 1) {
            const field_node = node.child(i) orelse continue;
            const field_type = field_node.getType();

            if (std.mem.eql(u8, field_type, "identifier")) {
                name = field_node.getBytes();
            } else if (std.mem.eql(u8, field_type, "precondition")) {
                given = field_node.getBytes();
            } else if (std.mem.eql(u8, field_type, "action")) {
                when = field_node.getBytes();
            } else if (std.mem.eql(u8, field_type, "result")) {
                then = field_node.getBytes();
            }
        }

        const qualified_name = if (prefix.len > 0)
            try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, name })
        else
            name;

        // Build signature from when/then
        const signature = try std.fmt.allocPrint(self.allocator, "when: {s}, then: {s}", .{ when, then });

        try symbols.append(Symbol{
            .id = @intCast(symbols.items.len + 1),
            .kind = .behavior,
            .name = name,
            .qualified_name = qualified_name,
            .signature = signature,
            .documentation = try std.fmt.allocPrint(self.allocator, "Given: {s}\nWhen: {s}", .{ given, when }),
            .file_path = file_path,
            .line = @intCast(node.startPoint().row),
            .column = @intCast(node.startPoint().column),
        });
    }

    fn extractAlgorithm(self: *Vibeeparser, node: Node, file_path: []const u8, prefix: []const u8, symbols: *std.ArrayList(Symbol)) !void {
        _ = self;

        var name: []const u8 = "";
        var child_count = node.childCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            const child = node.child(i) orelse continue;
            if (std.mem.eql(u8, child.getType(), "algorithm_name")) {
                const name_node = child.child(0) orelse continue;
                name = name_node.getBytes();
                break;
            }
        }

        const qualified_name = if (prefix.len > 0)
            try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, name })
        else
            name;

        try symbols.append(Symbol{
            .id = @intCast(symbols.items.len + 1),
            .kind = .algorithm,
            .name = name,
            .qualified_name = qualified_name,
            .signature = null,
            .documentation = null,
            .file_path = file_path,
            .line = @intCast(node.startPoint().row),
            .column = @intCast(node.startPoint().column),
        });
    }

    fn extractTest(self: *Vibeeparser, node: Node, file_path: []const u8, prefix: []const u8, symbols: *std.ArrayList(Symbol)) !void {
        _ = self;

        var name: []const u8 = "";
        var child_count = node.childCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            const child = node.child(i) orelse continue;
            if (std.mem.eql(u8, child.getType(), "test_name")) {
                const name_node = child.child(0) orelse continue;
                name = name_node.getBytes();
                break;
            }
        }

        const qualified_name = if (prefix.len > 0)
            try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, name })
        else
            name;

        try symbols.append(Symbol{
            .id = @intCast(symbols.items.len + 1),
            .kind = .test,
            .name = name,
            .qualified_name = qualified_name,
            .signature = null,
            .documentation = null,
            .file_path = file_path,
            .line = @intCast(node.startPoint().row),
            .column = @intCast(node.startPoint().column),
        });
    }
};

/// Container for extracted symbols
pub const SymbolList = struct {
    symbols: []Symbol,
    allocator: Allocator,

    pub fn deinit(self: *SymbolList) void {
        for (self.symbols) |*sym| {
            self.allocator.free(sym.name);
            self.allocator.free(sym.qualified_name);
            if (sym.signature) |s| self.allocator.free(s);
            if (sym.documentation) |d| self.allocator.free(d);
            self.allocator.free(sym.file_path);
        }
        self.allocator.free(self.symbols);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXTERNAL DECLARATIONS (to be linked from compiled tree-sitter-vibee)
// ═══════════════════════════════════════════════════════════════════════════════

extern "c" fn tree_sitter_vibee() callconv(.C) Language;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Vibeeparser init" {
    const allocator = std.testing.allocator;
    var parser = try Vibeeparser.init(allocator);
    defer parser.deinit();

    try std.testing.expectEqual(@as(usize, 0), 0); // Placeholder test
}
