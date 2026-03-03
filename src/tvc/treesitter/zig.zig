// ═══════════════════════════════════════════════════════════════════════════════
// Tree-sitter Zig FFI Bindings
// ═══════════════════════════════════════════════════════════════════════════════
//
// Zig FFI bindings for Tree-sitter parsing library.
// Provides AST parsing for Zig and VIBEE source files.
//
// Requirements:
//   - brew install tree-sitter (macOS)
//   - tree-sitter cli installed for generating parsers
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// C FFI bindings to tree-sitter API
const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Tree-sitter language type
pub const Language = *c.TSLanguage;

/// Tree-sitter parser
pub const Parser = struct {
    ptr: *c.TSParser,

    /// Create a new parser
    pub fn init() !Parser {
        const parser = c.ts_parser_new() orelse return error.ParserInitFailed;
        return Parser{ .ptr = parser };
    }

    /// Set the language for the parser
    pub fn setLanguage(self: *Parser, language: Language) !void {
        if (!c.ts_parser_set_language(self.ptr, language)) {
            return error.LanguageSetFailed;
        }
    }

    /// Parse a string
    pub fn parseString(self: *Parser, source: []const u8) !*c.TSTree {
        const tree = c.ts_parser_parse_string(
            self.ptr,
            null, // old_tree
            source.ptr,
            @intCast(source.len),
        ) orelse return error.ParseFailed;
        return tree;
    }

    /// Parse a file (reads entire file into memory first)
    pub fn parseFile(self: *Parser, allocator: Allocator, path: []const u8) !*c.TSTree {
        const source = try std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024); // 10MB limit
        defer allocator.free(source);
        return self.parseString(source);
    }

    /// Destroy the parser
    pub fn deinit(self: *Parser) void {
        c.ts_parser_delete(self.ptr);
    }
};

/// Tree-sitter tree (AST)
pub const Tree = struct {
    ptr: *c.TSTree,

    /// Get the root node
    pub fn root(self: *const Tree) Node {
        return Node{ .ptr = c.ts_tree_root_node(self.ptr) };
    }

    /// Destroy the tree
    pub fn deinit(self: *Tree) void {
        c.ts_tree_delete(self.ptr);
    }
};

/// Tree-sitter syntax node
pub const Node = struct {
    ptr: c.TSNode,

    /// Check if node is null
    pub fn isNull(self: Node) bool {
        return c.ts_node_is_null(self.ptr);
    }

    /// Get node type as string
    pub fn getType(self: Node) []const u8 {
        const c_str = c.ts_node_type(self.ptr);
        const len = std.mem.len(c_str);
        return c_str[0..len];
    }

    /// Get node symbol
    pub fn getSymbol(self: Node) c.TSSymbol {
        return c.ts_node_symbol(self.ptr);
    }

    /// Get start byte offset
    pub fn startByte(self: Node) u32 {
        return @intCast(c.ts_node_start_byte(self.ptr));
    }

    /// Get end byte offset
    pub fn endByte(self: Node) u32 {
        return @intCast(c.ts_node_end_byte(self.ptr));
    }

    /// Get start point (row, column)
    pub fn startPoint(self: Node) Point {
        var point: c.TSPoint = undefined;
        point = c.ts_node_start_point(self.ptr);
        return Point{
            .row = @intCast(point.row),
            .column = @intCast(point.column),
        };
    }

    /// Get end point (row, column)
    pub fn endPoint(self: Node) Point {
        var point: c.TSPoint = undefined;
        point = c.ts_node_end_point(self.ptr);
        return Point{
            .row = @intCast(point.row),
            .column = @intCast(point.column),
        };
    }

    /// Get child count
    pub fn childCount(self: Node) u32 {
        return @intCast(c.ts_node_child_count(self.ptr));
    }

    /// Get named child count
    pub fn namedChildCount(self: Node) u32 {
        return @intCast(c.ts_node_named_child_count(self.ptr));
    }

    /// Get child at index
    pub fn child(self: Node, index: u32) Node {
        return Node{ .ptr = c.ts_node_child(self.ptr, index) };
    }

    /// Get named child at index
    pub fn namedChild(self: Node, index: u32) Node {
        return Node{ .ptr = c.ts_node_named_child(self.ptr, index) };
    }

    /// Get child by field name
    pub fn childByFieldName(self: Node, _: []const u8, field_name: []const u8) ?Node {
        const c_str = @as([*c]const u8, @ptrCast(field_name.ptr));
        const result = c.ts_node_child_by_field_name(self.ptr, c_str, @intCast(field_name.len));
        if (c.ts_node_is_null(result)) return null;
        return Node{ .ptr = result };
    }

    /// Get parent node
    pub fn parent(self: Node) ?Node {
        const p = c.ts_node_parent(self.ptr);
        if (c.ts_node_is_null(p)) return null;
        return Node{ .ptr = p };
    }

    /// Get next sibling
    pub fn nextSibling(self: Node) ?Node {
        const s = c.ts_node_next_sibling(self.ptr);
        if (c.ts_node_is_null(s)) return null;
        return Node{ .ptr = s };
    }

    /// Get previous sibling
    pub fn prevSibling(self: Node) ?Node {
        const s = c.ts_node_prev_sibling(self.ptr);
        if (c.ts_node_is_null(s)) return null;
        return Node{ .ptr = s };
    }

    /// Check if node is named
    pub fn isNamed(self: Node) bool {
        return c.ts_node_is_named(self.ptr);
    }

    /// Check if node is extra
    pub fn isExtra(self: Node) bool {
        return c.ts_node_is_extra(self.ptr);
    }

    /// Check if node has error
    pub fn hasError(self: Node) bool {
        return c.ts_node_has_error(self.ptr);
    }

    /// Extract node text from source
    pub fn text(self: Node, source: []const u8) []const u8 {
        const start = self.startByte();
        const end = self.endByte();
        return source[start..end];
    }

    /// Iterate over all children
    pub fn iterateChildren(self: Node) ChildIterator {
        return ChildIterator{
            .node = self,
            .index = 0,
        };
    }

    /// Iterate over named children only
    pub fn iterateNamedChildren(self: Node) ChildIterator {
        return ChildIterator{
            .node = self,
            .index = 0,
            .named_only = true,
        };
    }
};

/// Source code point (row, column)
pub const Point = struct {
    row: u32,
    column: u32,

    /// Convert to 0-indexed line number
    pub fn toLineNumber(self: Point) u32 {
        return self.row + 1;
    }
};

/// Child iterator
pub const ChildIterator = struct {
    node: Node,
    index: u32,
    named_only: bool = false,

    pub fn next(self: *ChildIterator) ?Node {
        const count = if (self.named_only) self.node.namedChildCount() else self.node.childCount();
        if (self.index >= count) return null;

        const child = if (self.named_only)
            self.node.namedChild(self.index)
        else
            self.node.child(self.index);

        self.index += 1;
        return child;
    }
};

/// Query cursor for pattern matching
pub const Query = struct {
    ptr: *c.TSQuery,

    /// Create a query from a string
    pub fn init(_: Allocator, language: Language, source: []const u8) !Query {
        var error_offset: u32 = 0;
        var error_type: c.TSQueryError = 0;

        const query = c.ts_query_new(
            language,
            source.ptr,
            @intCast(source.len),
            &error_offset,
            &error_type,
        ) orelse return error.QueryError;

        return Query{ .ptr = query };
    }

    /// Destroy the query
    pub fn deinit(self: *Query) void {
        c.ts_query_delete(self.ptr);
    }
};

/// Query capture (match result)
pub const QueryCapture = struct {
    node: Node,
    index: u32,
};

/// Query match (all captures for one pattern match)
pub const QueryMatch = struct {
    id: u32,
    pattern_index: u16,
    captures: []QueryCapture,
};

/// Query cursor for executing queries
pub const QueryCursor = struct {
    ptr: *c.TSQueryCursor,
    capture_buffer: std.ArrayList(QueryCapture),
    allocator: Allocator,

    /// Create a new query cursor
    pub fn init(allocator: Allocator) QueryCursor {
        const ptr = c.ts_query_cursor_new() orelse unreachable;
        return QueryCursor{
            .ptr = ptr,
            .capture_buffer = .{ .items = &.{}, .capacity = 0 },
            .allocator = allocator,
        };
    }

    /// Execute a query on a syntax node
    pub fn exec(self: *QueryCursor, query: Query, node: Node) void {
        c.ts_query_cursor_exec(self.ptr, query.ptr, node.ptr);
    }

    /// Get next match from the query cursor
    /// Returns null when no more matches
    pub fn nextMatch(self: *QueryCursor) !?QueryMatch {
        self.capture_buffer.clearRetainingCapacity();

        var match: c.TSQueryMatch = undefined;
        var capture_index: u32 = undefined;
        const has_match = c.ts_query_cursor_next_capture(self.ptr, &match, &capture_index);

        if (!has_match) return null;

        // Copy captures into buffer
        for (0..@intCast(match.capture_count)) |i| {
            const capture = match.captures[i];
            try self.capture_buffer.append(self.allocator, QueryCapture{
                .node = Node{ .ptr = capture.node },
                .index = @intCast(capture.index),
            });
        }

        return QueryMatch{
            .id = match.id,
            .pattern_index = match.pattern_index,
            .captures = self.capture_buffer.items,
        };
    }

    /// Destroy the cursor
    pub fn deinit(self: *QueryCursor) void {
        self.capture_buffer.deinit(self.allocator);
        c.ts_query_cursor_delete(self.ptr);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LANGUAGE LOADERS
// ═══════════════════════════════════════════════════════════════════════════════

/// External function to load Zig language
/// Provided by tree-sitter-zig grammar, or by zig_lang_stub.c (returns NULL)
extern fn tree_sitter_zig() ?*c.TSLanguage;

/// Load the Zig language parser
/// Returns null if tree-sitter-zig grammar is not available (stub returns NULL)
pub fn loadZigLanguage() ?Language {
    return tree_sitter_zig();
}

/// Create a parser pre-configured for Zig
pub fn createZigParser() !Parser {
    var parser = try Parser.init();
    errdefer parser.deinit();

    const lang = loadZigLanguage() orelse return error.LanguageNotFound;
    try parser.setLanguage(lang);

    return parser;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert byte offset to line and column
pub fn byteToLineColumn(source: []const u8, byte_offset: usize) struct { line: u32, column: u32 } {
    var line: u32 = 0;
    var column: u32 = 0;
    var i: usize = 0;

    while (i < byte_offset and i < source.len) : (i += 1) {
        if (source[i] == '\n') {
            line += 1;
            column = 0;
        } else {
            column += 1;
        }
    }

    return .{ .line = line + 1, .column = column };
}

/// Find all nodes of a specific type
pub fn findNodesOfType(allocator: Allocator, node: Node, node_type: []const u8) ![]Node {
    var list: std.ArrayList(Node) = .empty;

    try findNodesOfTypeRecursive(allocator, node, node_type, &list);

    return list.toOwnedSlice(allocator);
}

fn findNodesOfTypeRecursive(allocator: Allocator, node: Node, node_type: []const u8, list: *std.ArrayList(Node)) !void {
    var iter = node.iterateChildren();
    while (iter.next()) |child_node| {
        if (child_node.isNamed()) {
            const child_type = child_node.getType();
            if (std.mem.eql(u8, child_type, node_type)) {
                try list.append(allocator, child_node);
            }
            try findNodesOfTypeRecursive(allocator, child_node, node_type, list);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Parser.init" {
    const parser = try Parser.init();
    defer parser.deinit();

    // Parser should be created successfully
    try std.testing.expect(parser.ptr != null);
}

test "Parser.setLanguage - Zig" {
    var parser = try Parser.init();
    defer parser.deinit();

    const lang = loadZigLanguage();
    if (lang) |l| {
        try parser.setLanguage(l);
        try std.testing.expect(true);
    } else {
        // Language not available, skip test
        std.debug.print("Warning: tree-sitter-zig not available\n", .{});
    }
}

test "Parser.parseString - simple Zig function" {
    var parser = try createZigParser() catch |err| {
        if (err == error.LanguageNotFound) {
            std.debug.print("Warning: tree-sitter-zig not available, skipping test\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };
    defer parser.deinit();

    const source = "pub fn add(a: i32, b: i32) i32 { return a + b; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.root();
    try std.testing.expect(!root.isNull());
    try std.testing.expectEqual(@as(usize, source.len), root.endByte());
}

test "Node.text extraction" {
    var parser = try createZigParser() catch |err| {
        if (err == error.LanguageNotFound) return error.SkipZigTest;
        return err;
    };
    defer parser.deinit();

    const source = "pub fn add(a: i32, b: i32) i32 { return a + b; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.root();
    const text = root.text(source);
    try std.testing.expectEqualStrings(source, text);
}

test "byteToLineColumn" {
    const source = "line1\nline2\nline3";
    const result = byteToLineColumn(source, 7);
    try std.testing.expectEqual(@as(u32, 2), result.line);
    try std.testing.expectEqual(@as(u32, 0), result.column);
}
