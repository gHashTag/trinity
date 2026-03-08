//! AST Analyzer for VIBEE Compiler
//!
//! Parses Zig source to extract codegen templates,
//! identifies bug patterns, extracts metadata.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;

/// AST node type
pub const NodeType = enum {
    root,
    struct_decl,
    function_decl,
    call_expr,
    field_access,
    if_statement,
    for_statement,
    return_statement,
    error_union,
    unknown,
};

/// Simple AST node
pub const ASTNode = struct {
    type: NodeType,
    name: []const u8,
    line: usize,
    column: usize,
    children: ArrayListManaged(*ASTNode),

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType) !ASTNode {
        return ASTNode{
            .type = node_type,
            .name = "",
            .line = 0,
            .column = 0,
            .children = ArrayListManaged(*ASTNode).init(allocator),
        };
    }

    pub fn deinit(self: *ASTNode) void {
        for (self.children.items) |child| {
            child.deinit();
            self.children.allocator.destroy(child);
        }
        self.children.deinit();
    }
};

/// Codegen template metadata
pub const TemplateMetadata = struct {
    name: []const u8,
    file_path: []const u8,
    line_start: usize,
    line_end: usize,
    parameters: ArrayListManaged([]const u8),
    bug_patterns: ArrayListManaged([]const u8),
    last_modified: i64,
};

/// AST analysis result
pub const ASTAnalysisResult = struct {
    success: bool,
    templates: ArrayListManaged(TemplateMetadata),
    errors: ArrayListManaged([]const u8),
    total_lines: usize,
};

/// Parse Zig source to extract AST
pub fn parseAST(allocator: std.mem.Allocator, source: []const u8) !*ASTNode {
    const root = try allocator.create(ASTNode);
    root.* = try ASTNode.init(allocator, .root);

    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_num: usize = 0;

    while (lines.next()) |line| {
        line_num += 1;
        try parseLine(allocator, root, line, line_num);
    }

    return root;
}

/// Parse single line into AST nodes
fn parseLine(allocator: std.mem.Allocator, root: *ASTNode, line: []const u8, line_num: usize) !void {
    _ = line_num;

    // Detect struct declarations
    if (std.mem.indexOf(u8, line, "pub const") != null) {
        const node = try allocator.create(ASTNode);
        node.* = try ASTNode.init(allocator, .function_decl);
        try root.children.append(node);
    }

    // Detect function declarations
    if (std.mem.indexOf(u8, line, "pub fn") != null) {
        const node = try allocator.create(ASTNode);
        node.* = try ASTNode.init(allocator, .function_decl);
        try root.children.append(node);
    }

    // Detect if statements
    if (std.mem.indexOf(u8, line, "if (") != null) {
        const node = try allocator.create(ASTNode);
        node.* = try ASTNode.init(allocator, .if_statement);
        try root.children.append(node);
    }

    // Detect for loops
    if (std.mem.indexOf(u8, line, "for (") != null) {
        const node = try allocator.create(ASTNode);
        node.* = try ASTNode.init(allocator, .for_statement);
        try root.children.append(node);
    }

    // Detect error unions
    if (std.mem.indexOf(u8, line, "!") != null) {
        const node = try allocator.create(ASTNode);
        node.* = try ASTNode.init(allocator, .error_union);
        try root.children.append(node);
    }

    _ = allocator;
}

/// Analyze VIBEE compiler source for codegen templates
pub fn analyzeCompilerSource(allocator: std.mem.Allocator, source_path: []const u8) !ASTAnalysisResult {
    var result = ASTAnalysisResult{
        .success = true,
        .templates = ArrayListManaged(TemplateMetadata).init(allocator),
        .errors = ArrayListManaged([]const u8).init(allocator),
        .total_lines = 0,
    };

    // Read source file
    const source = try std.fs.cwd().readFileAlloc(allocator, source_path, 1024 * 1024);
    defer allocator.free(source);

    // Count lines
    result.total_lines = std.mem.count(u8, source, '\n');

    // Extract templates (simplified - looks for specific patterns)
    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_num: usize = 0;

    while (lines.next()) |line| {
        line_num += 1;

        // Look for codegen function patterns
        if (std.mem.indexOf(u8, line, "generate") != null and
            std.mem.indexOf(u8, line, "fn") != null)
        {
            const meta = try extractTemplateMetadata(allocator, line, source_path, line_num);
            try result.templates.append(meta);
        }
    }

    return result;
}

/// Extract template metadata from function declaration
fn extractTemplateMetadata(allocator: std.mem.Allocator, line: []const u8, file_path: []const u8, line_num: usize) !TemplateMetadata {
    var params = ArrayListManaged([]const u8).init(allocator);
    var bugs = ArrayListManaged([]const u8).init(allocator);

    // Extract function name
    const name = if (std.mem.indexOf(u8, line, "fn ")) |pos| {
        const after_fn = line[pos + 3 ..];
        const end = std.mem.indexOfScalar(u8, after_fn, '(') orelse after_fn.len;
        after_fn[0..end]
    } else {
        "unknown_template"
    };

    // TODO: Extract parameters and bug patterns from actual source
    _ = file_path;
    _ = line_num;

    return TemplateMetadata{
        .name = name,
        .file_path = "",
        .line_start = 0,
        .line_end = 0,
        .parameters = params,
        .bug_patterns = bugs,
        .last_modified = std.time.timestamp(),
    };
}

/// Find codegen templates by pattern
pub fn findTemplatesByPattern(allocator: std.mem.Allocator, pattern: []const u8) ![][]const u8 {
    _ = allocator;
    _ = pattern;
    // TODO: Search codebase for templates matching pattern
    return &[_][]const u8{};
}

test "parseAST: simple struct" {
    const allocator = std.testing.allocator;
    const source = "pub const Test = struct { x: u32 };";

    const root = try parseAST(allocator, source);
    defer root.deinit();

    try std.testing.expect(root.type == .root);
    try std.testing.expect(root.children.items.len >= 1);
}

test "analyzeCompilerSource: basic" {
    const allocator = std.testing.allocator;
    // Mock source file - in real usage, this would read actual compiler files
    const source_path = "src/vibeec/zig_codegen.zig";

    const file_exists = std.fs.cwd().openFile(source_path, .{}) catch |err| blk: {
        if (err == error.FileNotFound) {
            // File doesn't exist in test - skip
            return;
        }
        break :blk err;
    };
    if (file_exists) |file| file.close();

    // Skip test if file doesn't exist
    if (std.fs.cwd().openFile(source_path, .{}) catch error.FileNotFound) {
        return;
    }

    const result = try analyzeCompilerSource(allocator, source_path);
    try std.testing.expect(result.success);
}
