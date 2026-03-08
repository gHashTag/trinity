// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Zig Parser (Stub)
// ═══════════════════════════════════════════════════════════════════════════════
//
// STUB: This module provides minimal stubs for Zig parsing.
// The full implementation would use tree-sitter or Zig's AST parser.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Node type enum (for VSA integration)
pub const NodeType = enum {
    source_file,
    function,
    struct_type,
    enum_type,
    union_type,
    constant,
    variable,
    parameter,
    identifier,
    call_expression,
    assignment,
    return_statement,
    if_statement,
    while_statement,
    for_statement,
    block,
    root,
    unknown,
};

/// AST node (stub)
pub const ASTNode = struct {
    file_path: []const u8,
    source: []const u8,
    error_count: usize = 0,

    pub fn init(file_path: []const u8, source: []const u8) ASTNode {
        return .{
            .file_path = file_path,
            .source = source,
        };
    }
};

/// AST graph (stub)
pub const ASTGraph = struct {
    allocator: std.mem.Allocator,
    files: std.StringHashMap(ASTNode),

    pub fn init(allocator: std.mem.Allocator) ASTGraph {
        return .{
            .allocator = allocator,
            .files = std.StringHashMap(ASTNode).init(allocator),
        };
    }

    pub fn deinit(self: *ASTGraph) void {
        // Note: file_path and source slices are not freed in stub implementation
        // since they're just references, not owned allocations
        self.files.deinit();
    }
};

/// Zig parser (stub)
pub const ZigParser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) ZigParser {
        return .{
            .allocator = allocator,
            .source = source,
        };
    }

    pub fn parseSourceFile(self: *ZigParser) !ASTNode {
        // Stub: just return a basic node without actual parsing
        return ASTNode{
            .file_path = "unknown",
            .source = self.source,
            .error_count = 0,
        };
    }

    pub fn deinit(self: *ZigParser) void {
        _ = self;
    }
};
