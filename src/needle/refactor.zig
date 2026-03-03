// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 2 — Safe Multi-File Refactoring
// ═══════════════════════════════════════════════════════════════════════════════
//
// Atomic multi-file edits with topological ordering and rollback
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const graph = @import("graph.zig");
const symbols = @import("symbols.zig");
const matcher = @import("matcher.zig");
const edit = @import("edit.zig");
const check = @import("check.zig");

const CallGraph = graph.CallGraph;
const EditPlan = graph.EditPlan;
const MultiFileEditResult = graph.MultiFileEditResult;
const UsageList = graph.UsageList;
const UsageLocation = graph.UsageLocation;
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
