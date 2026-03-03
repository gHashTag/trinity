// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 2 — Safe Multi-File Refactoring
// ═══════════════════════════════════════════════════════════════════════════════
//
// Atomic multi-file edits with topological ordering and rollback
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const graph_mod = @import("graph.zig");
const symbols = @import("symbols.zig");
const matcher = @import("matcher.zig");
const edit = @import("edit.zig");
const check = @import("check.zig");

const CallGraph = graph_mod.CallGraph;
const EditPlan = graph_mod.EditPlan;
const MultiFileEditResult = graph_mod.MultiFileEditResult;
const UsageList = graph_mod.UsageList;
const UsageLocation = graph_mod.UsageLocation;
const MatchResult = matcher.MatchResult;
const MatchResultList = matcher.MatchResultList;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Refactor operation type
pub const RefactorKind = enum {
    rename_symbol,
    extract_function,
    inline_function,
    change_signature,
    move_symbol,
};

/// Refactor configuration
pub const RefactorConfig = struct {
    kind: RefactorKind,
    symbol_name: []const u8,
    new_name: []const u8 = "", // For rename
    file_path: []const u8 = "", // For extract/inline
    preview_only: bool = true,
    create_backups: bool = true,
    run_quality_gates: bool = true,

    pub fn initRename(symbol: []const u8, new: []const u8) RefactorConfig {
        return .{
            .kind = .rename_symbol,
            .symbol_name = symbol,
            .new_name = new,
            .preview_only = true,
            .create_backups = true,
            .run_quality_gates = true,
        };
    }
};

/// File backup for rollback
pub const FileBackup = struct {
    file_path: []const u8,
    original_content: []const u8,
    hash: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8, content: []const u8) !FileBackup {
        // Simple hash of content for verification
        var hash_state = std.hash.Wyhash.init(0);
        hash_state.update(content);
        const hash_int = hash_state.final();
        const hash_str = try std.fmt.allocPrint(allocator, "{x}", .{hash_int});

        return .{
            .file_path = try allocator.dupe(u8, file_path),
            .original_content = try allocator.dupe(u8, content),
            .hash = hash_str,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FileBackup) void {
        self.allocator.free(self.file_path);
        self.allocator.free(self.original_content);
        self.allocator.free(self.hash);
    }
};

/// Refactor execution context
pub const RefactorContext = struct {
    allocator: std.mem.Allocator,
    call_graph: *CallGraph,
    config: RefactorConfig,
    backups: std.ArrayList(FileBackup),
    files_edited: std.ArrayList([]const u8),
    total_changes: usize,

    pub fn init(allocator: std.mem.Allocator, call_graph: *CallGraph, config: RefactorConfig) RefactorContext {
        return .{
            .allocator = allocator,
            .call_graph = call_graph,
            .config = config,
            .backups = std.ArrayList(FileBackup).init(allocator),
            .files_edited = std.ArrayList([]const u8).init(allocator),
            .total_changes = 0,
        };
    }

    pub fn deinit(self: *RefactorContext) void {
        for (self.backups.items) |*backup| {
            backup.deinit();
        }
        self.backups.deinit();

        for (self.files_edited.items) |path| {
            self.allocator.free(path);
        }
        self.files_edited.deinit();
    }

    /// Rollback all changes
    pub fn rollback(self: *RefactorContext) !void {
        for (self.backups.items) |backup| {
            try std.fs.cwd().writeFile(.{ .sub_path = backup.file_path }, backup.original_content);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REFACTOR OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Plan a symbol rename operation
pub fn planRename(
    allocator: std.mem.Allocator,
    call_graph: *CallGraph,
    old_name: []const u8,
    new_name: []const u8,
) !EditPlan {
    _ = new_name; // Will be used for validation in future
    var plan = EditPlan.init(allocator, old_name);

    // Get affected files
    const files = try call_graph.getAffectedFiles(old_name, allocator);
    defer {
        for (files.items) |f| {
            allocator.free(f);
        }
        files.deinit();
    }

    // Add files to plan
    for (files.items) |file| {
        try plan.addFile(file);
    }

    // Compute safe edit order
    const edit_order = try call_graph.computeEditOrder(files.items, allocator);
    defer {
        for (edit_order.items) |f| {
            allocator.free(f);
        }
        edit_order.deinit();
    }

    try plan.setEditOrder(edit_order.items);

    return plan;
}

/// Preview a refactor without applying changes
pub fn previewRename(
    allocator: std.mem.Allocator,
    call_graph: *CallGraph,
    old_name: []const u8,
    new_name: []const u8,
) !MultiFileEditResult {
    return call_graph.previewMultiFileEdit(old_name, new_name, allocator);
}

/// Apply a symbol rename operation
pub fn applyRename(
    allocator: std.mem.Allocator,
    call_graph: *CallGraph,
    old_name: []const u8,
    new_name: []const u8,
    preview_only: bool,
) !MultiFileEditResult {
    var result = MultiFileEditResult.init(allocator);
    errdefer result.deinit();

    // Get affected files
    const files = try call_graph.getAffectedFiles(old_name, allocator);
    defer {
        for (files.items) |f| {
            allocator.free(f);
        }
        files.deinit();
    }

    // Compute safe edit order
    const edit_order = try call_graph.computeEditOrder(files.items, allocator);
    defer {
        for (edit_order.items) |f| {
            allocator.free(f);
        }
        edit_order.deinit();
    }

    // Setup refactor context
    var config = RefactorConfig.initRename(old_name, new_name);
    config.preview_only = preview_only;

    var ctx = RefactorContext.init(allocator, call_graph, config);
    defer ctx.deinit();

    // Process each file in topological order
    for (edit_order.items) |file_path| {
        const content = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
            try result.addError(try std.fmt.allocPrint(allocator, "Failed to read {s}: {}", .{ file_path, err }));
            continue;
        };
        defer allocator.free(content);

        // Create backup
        if (config.create_backups) {
            const backup = try FileBackup.init(allocator, file_path, content);
            try ctx.backups.append(backup);
        }

        // Find usages in this file
        var m = matcher.Matcher.init(allocator, content, file_path);
        const matches = try m.findMatches(old_name);
        defer matches.deinit();

        if (matches.items.items.len == 0) {
            // No matches in this file
            continue;
        }

        // Apply edits from bottom to top (to preserve line numbers)
        var changes_this_file: usize = 0;
        var i: usize = matches.items.items.len;
        while (i > 0) {
            i -= 1;
            const match = matches.items.items[i];

            if (preview_only) {
                changes_this_file += 1;
                continue;
            }

            // Apply the edit
            const editor = edit.TextEditor.init(allocator, content);
            _ = try editor.replaceRange(
                match.start_line,
                match.start_column,
                match.end_line,
                match.end_column,
                new_name,
            );

            const new_content = try editor.getEditedContent();
            defer allocator.free(new_content);

            // Write back
            try std.fs.cwd().writeFile(.{ .sub_path = file_path }, new_content);

            changes_this_file += 1;
        }

        if (changes_this_file > 0) {
            try ctx.files_edited.append(try allocator.dupe(u8, file_path));
            ctx.total_changes += changes_this_file;

            // Run quality gates if requested
            if (config.run_quality_gates and !preview_only) {
                const violations = try check.checkFile(allocator, file_path);
                defer {
                    for (violations.items) |*v| {
                        v.deinit(allocator);
                    }
                    violations.deinit();
                }

                // Check for critical violations
                for (violations.items) |v| {
                    if (v.severity == .critical) {
                        // Rollback this file
                        try ctx.rollback();
                        try result.addError(try std.fmt.allocPrint(allocator, "Critical violation in {s}: {s}", .{ file_path, v.message }));
                        result.success = false;
                        return result;
                    }
                }
            }
        }
    }

    result.files_modified = ctx.files_edited.items.len;
    result.total_changes = ctx.total_changes;

    return result;
}

/// Extract a function from selected code
pub fn extractFunction(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    start_line: u32,
    end_line: u32,
    function_name: []const u8,
    preview_only: bool,
) !MultiFileEditResult {
    var result = MultiFileEditResult.init(allocator);
    errdefer result.deinit();

    const content = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        try result.addError(try std.fmt.allocPrint(allocator, "Failed to read {s}: {}", .{ file_path, err }));
        result.success = false;
        return result;
    };
    defer allocator.free(content);

    // Find the code to extract
    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_num: u32 = 1;
    var selected_code = std.ArrayList(u8).init(allocator);
    defer selected_code.deinit();

    while (lines.next()) |line| {
        if (line_num >= start_line and line_num <= end_line) {
            try selected_code.appendSlice(line);
            try selected_code.append('\n');
        }
        line_num += 1;
    }

    if (preview_only) {
        result.preview = try std.fmt.allocPrint(allocator,
            \\Extract Function Preview
            \\====================
            \\File: {s}
            \\Lines: {d} - {d}
            \\Function Name: {s}
            \\
            \\Code to extract:
            \\{s}
        , .{ file_path, start_line, end_line, function_name, selected_code.items });

        result.files_modified = 1;
        result.total_changes = 1;
        return result;
    }

    // TODO: Implement actual extraction
    // 1. Analyze selected code for variables
    // 2. Determine parameters and return type
    // 3. Insert new function
    // 4. Replace selected code with function call

    try result.addError("extractFunction not yet implemented");
    result.success = false;

    return result;
}

/// Generate a unified diff preview
pub fn generateDiffPreview(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    old_content: []const u8,
    new_content: []const u8,
) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    try result.appendSlice("--- ");
    try result.appendSlice(file_path);
    try result.appendSlice("\n+++ ");
    try result.appendSlice(file_path);
    try result.appendSlice("\n");

    // Simple line-by-line diff
    var old_lines = std.mem.splitScalar(u8, old_content, '\n');
    var new_lines = std.mem.splitScalar(u8, new_content, '\n');

    while (true) {
        const old_line = old_lines.next();
        const new_line = new_lines.next();

        if (old_line == null and new_line == null) break;

        if (old_line) |ol| {
            if (new_line) |nl| {
                if (std.mem.eql(u8, ol, nl)) {
                    try result.appendSlice(" ");
                    try result.appendSlice(ol);
                } else {
                    try result.appendSlice("-");
                    try result.appendSlice(ol);
                    try result.appendSlice("\n+");
                    try result.appendSlice(nl);
                }
            } else {
                try result.appendSlice("-");
                try result.appendSlice(ol);
            }
        } else if (new_line) |nl| {
            try result.appendSlice("+");
            try result.appendSlice(nl);
        }

        try result.appendSlice("\n");
    }

    return result.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASTGRAPH-BASED REFACTORING (Tier 2.3)
// ═══════════════════════════════════════════════════════════════════════════════

const zig_parser = @import("zig_parser.zig");
const ASTGraph = zig_parser.ASTGraph;

/// Refactoring result using ASTGraph
pub const RefactorResult = struct {
    success: bool,
    files_modified: usize,
    total_changes: usize,
    errors: std.ArrayList([]const u8),
    diffs: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) RefactorResult {
        return .{
            .success = true,
            .files_modified = 0,
            .total_changes = 0,
            .errors = std.ArrayList([]const u8).init(allocator),
            .diffs = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *RefactorResult, allocator: std.mem.Allocator) void {
        for (self.errors.items) |msg| {
            allocator.free(msg);
        }
        self.errors.deinit(allocator);

        for (self.diffs.items) |diff| {
            allocator.free(diff);
        }
        self.diffs.deinit(allocator);
    }

    pub fn addError(self: *RefactorResult, allocator: std.mem.Allocator, msg: []const u8) !void {
        try self.errors.append(allocator, try allocator.dupe(u8, msg));
        self.success = false;
    }

    pub fn addDiff(self: *RefactorResult, allocator: std.mem.Allocator, diff: []const u8) !void {
        try self.diffs.append(allocator, diff);
    }
};

/// Rename a symbol across all files in the AST graph
pub fn renameSymbol(
    allocator: std.mem.Allocator,
    graph: *ASTGraph,
    old_name: []const u8,
    new_name: []const u8,
    preview_only: bool,
) !RefactorResult {
    var result = RefactorResult.init(allocator);
    errdefer result.deinit(allocator);

    // Find all references to the symbol
    const refs = try graph.findReferences(old_name);
    defer allocator.free(refs);

    // Track files that need modification
    var files_to_modify = std.StringHashMap(void).init(allocator);
    defer {
        var iter = files_to_modify.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        files_to_modify.deinit();
    }

    // Group references by file
    for (refs) |ref| {
        try files_to_modify.put(try allocator.dupe(u8, ref.file), {});
    }

    // Process each file
    var file_iter = files_to_modify.iterator();
    while (file_iter.next()) |entry| {
        const file_path = entry.key_ptr.*;

        const content = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
            try result.addError(allocator, try std.fmt.allocPrint(allocator, "Failed to read {s}: {}", .{file_path, err}));
            continue;
        };
        defer allocator.free(content);

        var new_content = std.ArrayList(u8).init(allocator);
        defer new_content.deinit(allocator);

        // Simple string replacement for now (can be improved with AST-based replacement)
        var content_copy = content;
        var replaced: bool = false;

        while (std.mem.indexOf(u8, content_copy, old_name)) |idx| {
            try new_content.appendSlice(content_copy[0..idx]);
            try new_content.appendSlice(new_name);
            content_copy = content_copy[idx + old_name.len..];
            replaced = true;
        }
        try new_content.appendSlice(content_copy);

        if (replaced) {
            if (!preview_only) {
                try std.fs.cwd().writeFile(.{ .sub_path = file_path }, new_content.items);
            }

            result.files_modified += 1;
            result.total_changes += 1;

            // Generate diff
            const diff = try generateDiffPreview(allocator, file_path, content, new_content.items);
            try result.addDiff(allocator, diff);
        }
    }

    // Also rename the definition
    if (graph.findSymbol(old_name)) |defs| {
        for (defs) |def| {
            const content = std.fs.cwd().readFileAlloc(allocator, def.file, 10 * 1024 * 1024) catch |err| {
                try result.addError(allocator, try std.fmt.allocPrint(allocator, "Failed to read {s}: {}", .{def.file, err}));
                continue;
            };
            defer allocator.free(content);

            // Replace definition
            var new_content = std.ArrayList(u8).init(allocator);
            defer new_content.deinit(allocator);

            var content_copy = content;
            var replaced: bool = false;

            while (std.mem.indexOf(u8, content_copy, old_name)) |idx| {
                try new_content.appendSlice(content_copy[0..idx]);
                try new_content.appendSlice(new_name);
                content_copy = content_copy[idx + old_name.len..];
                replaced = true;
            }
            try new_content.appendSlice(content_copy);

            if (replaced and !preview_only) {
                try std.fs.cwd().writeFile(.{ .sub_path = def.file }, new_content.items);
                result.total_changes += 1;
            }
        }
    }

    return result;
}

/// Find all usages of a symbol across the project
pub fn findUsages(
    graph: *ASTGraph,
    symbol_name: []const u8,
) ![]const zig_parser.SymbolRef {
    _ = graph;
    _ = symbol_name;
    // This is a placeholder - the actual implementation uses graph.findReferences
    // The allocator parameter was removed since findReferences returns an owned slice
    return &.{};
}
