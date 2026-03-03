// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Structural Edit Operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// Edit operations for applying changes to source code.
// Supports both structural (AST-based) and text-based edits.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const needle = @import("needle.zig");
const matcher = @import("matcher.zig");
const check = @import("check.zig");

// Tree-sitter integration (Tier 1)
const ts_zig = @import("treesitter_zig");

const MatchResult = needle.MatchResult;
const EditOperation = needle.EditOperation;
const EditReport = needle.EditReport;
const MatchKind = needle.MatchKind;

// ═══════════════════════════════════════════════════════════════════════════════
// EDIT OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Edit diff representation
pub const EditDiff = struct {
    old_text: []const u8,
    new_text: []const u8,
    start_line: u32,
    end_line: u32,
    start_byte: usize,
    end_byte: usize,
    hunk: []const u8, // Unified diff format

    pub fn deinit(self: *EditDiff, allocator: std.mem.Allocator) void {
        allocator.free(self.old_text);
        allocator.free(self.new_text);
        allocator.free(self.hunk);
    }
};

/// Text-based editor (Tier 0 fallback)
pub const TextEditor = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    file_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8) TextEditor {
        return .{
            .allocator = allocator,
            .source = source,
            .file_path = file_path,
        };
    }

    /// Compute diff for a match
    pub fn computeDiff(self: *TextEditor, match_result: MatchResult, replacement: []const u8) !EditDiff {
        var lines = std.mem.splitScalar(u8, self.source, '\n');

        var old_text = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };
        errdefer {
            if (old_text.capacity > 0) {
                self.allocator.free(old_text.allocatedSlice());
            }
        }

        // Extract the matched lines
        var line_idx: u32 = 1;
        while (line_idx < match_result.start_line) : (line_idx += 1) {
            _ = lines.next();
        }

        for (0..(match_result.end_line - match_result.start_line + 1)) |_| {
            if (lines.next()) |line| {
                try old_text.appendSlice(self.allocator, line);
                try old_text.append(self.allocator, '\n');
            }
        }

        const old_dupe = try old_text.toOwnedSlice(self.allocator);
        errdefer self.allocator.free(old_dupe);

        const new_dupe = try self.allocator.dupe(u8, replacement);
        errdefer self.allocator.free(new_dupe);

        // Generate unified diff hunk
        const hunk = try self.generateHunk(old_dupe, new_dupe, match_result.start_line);
        errdefer self.allocator.free(hunk);

        return EditDiff{
            .old_text = old_dupe,
            .new_text = new_dupe,
            .start_line = match_result.start_line,
            .end_line = match_result.end_line,
            .start_byte = 0, // TODO: compute byte offset
            .end_byte = 0,
            .hunk = hunk,
        };
    }

    /// Apply diff to source
    pub fn applyDiff(self: *TextEditor, diff: EditDiff) ![]const u8 {
        var result = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };
        errdefer {
            if (result.capacity > 0) {
                self.allocator.free(result.allocatedSlice());
            }
        }

        var lines = std.mem.splitScalar(u8, self.source, '\n');

        // Copy lines before the edit
        var line_idx: u32 = 1;
        while (line_idx < diff.start_line) : (line_idx += 1) {
            if (lines.next()) |line| {
                try result.appendSlice(self.allocator, line);
                try result.append(self.allocator, '\n');
            }
        }

        // Skip the old lines
        for (0..(diff.end_line - diff.start_line + 1)) |_| {
            _ = lines.next();
        }

        // Insert new content
        try result.appendSlice(self.allocator, diff.new_text);

        // Ensure trailing newline
        if (result.items.len > 0 and result.items[result.items.len - 1] != '\n') {
            try result.append(self.allocator, '\n');
        }

        // Copy remaining lines
        while (lines.next()) |line| {
            try result.appendSlice(self.allocator, line);
            try result.append(self.allocator, '\n');
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Generate unified diff hunk
    fn generateHunk(self: *TextEditor, old_text: []const u8, new_text: []const u8, start_line: u32) ![]const u8 {
        var hunk = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };

        try hunk.writer(self.allocator).print("@@ -{d},0 +{d},0 @@\n", .{ start_line, start_line });

        var old_lines = std.mem.splitScalar(u8, old_text, '\n');
        while (old_lines.next()) |line| {
            try hunk.writer(self.allocator).print("-{s}\n", .{line});
        }

        var new_lines = std.mem.splitScalar(u8, new_text, '\n');
        while (new_lines.next()) |line| {
            if (line.len > 0) {
                try hunk.writer(self.allocator).print("+{s}\n", .{line});
            }
        }

        return hunk.toOwnedSlice(self.allocator);
    }

    /// Preview diff as string
    pub fn previewDiff(self: *TextEditor, match_result: MatchResult, replacement: []const u8) ![]const u8 {
        var diff = try self.computeDiff(match_result, replacement);
        defer diff.deinit(self.allocator);

        var output = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };
        defer {
            if (output.capacity > 0) {
                self.allocator.free(output.allocatedSlice());
            }
        }

        try output.writer(self.allocator).print(
            \\=== EDIT PREVIEW ===
            \\File: {s}
            \\Lines {d}-{d}
            \\
            \\--- a/{s}
            \\+++ b/{s}
            \\{s}\n
        ,
        .{
            self.file_path,
            diff.start_line,
            diff.end_line,
            self.file_path,
            self.file_path,
            diff.hunk,
        });

        return output.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST EDITOR (Tier 1)
// ═══════════════════════════════════════════════════════════════════════════════

/// AST-based editor using Tree-sitter for byte-level precision
pub const ASTEditor = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    file_path: []const u8,
    parser: ?ts_zig.Parser,
    raw_tree: ?*const anyopaque, // Raw C pointer to TSTree

    /// Initialize AST editor with source code
    pub fn init(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8) !ASTEditor {
        // Try to create parser - returns error if not available
        var parser = ts_zig.createZigParser() catch |err| {
            if (err == error.LanguageNotFound) {
                // Tree-sitter not available, return editor without parser
                return ASTEditor{
                    .allocator = allocator,
                    .source = source,
                    .file_path = file_path,
                    .parser = null,
                    .raw_tree = null,
                };
            }
            return err;
        };

        // Parse source
        const raw_tree = parser.parseString(source) catch |err| {
            parser.deinit();
            if (err == error.ParseFailed) {
                // Parse failed, return editor without tree
                return ASTEditor{
                    .allocator = allocator,
                    .source = source,
                    .file_path = file_path,
                    .parser = null,
                    .raw_tree = null,
                };
            }
            return err;
        };

        return ASTEditor{
            .allocator = allocator,
            .source = source,
            .file_path = file_path,
            .parser = parser,
            .raw_tree = raw_tree,
        };
    }

    /// Check if AST is available
    pub fn isASTAvailable(self: *const ASTEditor) bool {
        return self.raw_tree != null;
    }

    /// Clean up resources
    pub fn deinit(self: *ASTEditor) void {
        if (self.raw_tree) |t| {
            var tree_wrapper = ts_zig.Tree{ .ptr = @ptrCast(@constCast(t)) };
            tree_wrapper.deinit();
        }
        if (self.parser) |*p| {
            p.deinit();
        }
    }

    /// Compute diff with byte-level precision from AST match
    pub fn computeDiff(self: *ASTEditor, match_result: MatchResult, replacement: []const u8) !EditDiff {
        // If match has byte offsets, use them for precision
        if (match_result.start_byte > 0 or match_result.end_byte > 0) {
            return self.computeByteDiff(match_result.start_byte, match_result.end_byte, replacement);
        }

        // Fall back to line-based diff
        return self.computeLineDiff(match_result, replacement);
    }

    /// Compute diff using byte offsets (Tier 1)
    fn computeByteDiff(self: *ASTEditor, start_byte: usize, end_byte: usize, replacement: []const u8) !EditDiff {
        const old_text = self.source[start_byte..end_byte];

        const old_dupe = try self.allocator.dupe(u8, old_text);
        errdefer self.allocator.free(old_dupe);

        const new_dupe = try self.allocator.dupe(u8, replacement);
        errdefer self.allocator.free(new_dupe);

        // Generate unified diff hunk
        const line_num = ts_zig.byteToLineColumn(self.source, start_byte).line;
        const hunk = try self.generateHunk(old_dupe, new_dupe, line_num);
        errdefer self.allocator.free(hunk);

        return EditDiff{
            .old_text = old_dupe,
            .new_text = new_dupe,
            .start_line = line_num,
            .end_line = ts_zig.byteToLineColumn(self.source, end_byte).line,
            .start_byte = start_byte,
            .end_byte = end_byte,
            .hunk = hunk,
        };
    }

    /// Compute diff using line numbers (Tier 0 fallback)
    fn computeLineDiff(self: *ASTEditor, match_result: MatchResult, replacement: []const u8) !EditDiff {
        var lines = std.mem.splitScalar(u8, self.source, '\n');

        var old_text = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };
        errdefer {
            if (old_text.capacity > 0) {
                self.allocator.free(old_text.allocatedSlice());
            }
        }

        // Extract the matched lines
        var line_idx: u32 = 1;
        while (line_idx < match_result.start_line) : (line_idx += 1) {
            _ = lines.next();
        }

        for (0..(match_result.end_line - match_result.start_line + 1)) |_| {
            if (lines.next()) |line| {
                try old_text.appendSlice(self.allocator, line);
                try old_text.append(self.allocator, '\n');
            }
        }

        const old_dupe = try old_text.toOwnedSlice(self.allocator);
        errdefer self.allocator.free(old_dupe);

        const new_dupe = try self.allocator.dupe(u8, replacement);
        errdefer self.allocator.free(new_dupe);

        const hunk = try self.generateHunk(old_dupe, new_dupe, match_result.start_line);
        errdefer self.allocator.free(hunk);

        return EditDiff{
            .old_text = old_dupe,
            .new_text = new_dupe,
            .start_line = match_result.start_line,
            .end_line = match_result.end_line,
            .start_byte = match_result.start_byte,
            .end_byte = match_result.end_byte,
            .hunk = hunk,
        };
    }

    /// Apply diff to source using byte offsets
    pub fn applyDiff(self: *ASTEditor, diff: EditDiff) ![]const u8 {
        // If we have byte offsets, use them for precise replacement
        if (diff.start_byte > 0 or diff.end_byte > 0) {
            return self.applyByteDiff(diff.start_byte, diff.end_byte, diff.new_text);
        }

        // Fall back to line-based application
        return self.applyLineDiff(diff);
    }

    /// Apply diff using byte offsets (Tier 1)
    fn applyByteDiff(self: *ASTEditor, start_byte: usize, end_byte: usize, replacement: []const u8) ![]const u8 {
        const result_len = self.source.len - (end_byte - start_byte) + replacement.len;
        const result = try self.allocator.alloc(u8, result_len);
        errdefer self.allocator.free(result);

        // Copy prefix
        @memcpy(result[0..start_byte], self.source[0..start_byte]);

        // Copy replacement
        @memcpy(result[start_byte..(start_byte + replacement.len)], replacement);

        // Copy suffix
        const suffix_start = start_byte + replacement.len;
        const suffix_offset = end_byte;
        @memcpy(result[suffix_start..], self.source[suffix_offset..]);

        return result;
    }

    /// Apply diff using line numbers (Tier 0 fallback)
    fn applyLineDiff(self: *ASTEditor, diff: EditDiff) ![]const u8 {
        var result = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };
        errdefer {
            if (result.capacity > 0) {
                self.allocator.free(result.allocatedSlice());
            }
        }

        var lines = std.mem.splitScalar(u8, self.source, '\n');

        // Copy lines before the edit
        var line_idx: u32 = 1;
        while (line_idx < diff.start_line) : (line_idx += 1) {
            if (lines.next()) |line| {
                try result.appendSlice(self.allocator, line);
                try result.append(self.allocator, '\n');
            }
        }

        // Skip the old lines
        for (0..(diff.end_line - diff.start_line + 1)) |_| {
            _ = lines.next();
        }

        // Insert new content
        try result.appendSlice(self.allocator, diff.new_text);

        // Ensure trailing newline
        if (result.items.len > 0 and result.items[result.items.len - 1] != '\n') {
            try result.append(self.allocator, '\n');
        }

        // Copy remaining lines
        while (lines.next()) |line| {
            try result.appendSlice(self.allocator, line);
            try result.append(self.allocator, '\n');
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Generate unified diff hunk
    fn generateHunk(self: *ASTEditor, old_text: []const u8, new_text: []const u8, start_line: u32) ![]const u8 {
        var hunk = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };

        try hunk.writer(self.allocator).print("@@ -{d},0 +{d},0 @@\n", .{ start_line, start_line });

        var old_lines = std.mem.splitScalar(u8, old_text, '\n');
        while (old_lines.next()) |line| {
            try hunk.writer(self.allocator).print("-{s}\n", .{line});
        }

        var new_lines = std.mem.splitScalar(u8, new_text, '\n');
        while (new_lines.next()) |line| {
            if (line.len > 0) {
                try hunk.writer(self.allocator).print("+{s}\n", .{line});
            }
        }

        return hunk.toOwnedSlice(self.allocator);
    }

    /// Preview diff as string
    pub fn previewDiff(self: *ASTEditor, match_result: MatchResult, replacement: []const u8) ![]const u8 {
        var diff = try self.computeDiff(match_result, replacement);
        defer diff.deinit(self.allocator);

        var output = std.ArrayListAligned(u8, null){
            .items = &.{},
            .capacity = 0,
        };
        defer {
            if (output.capacity > 0) {
                self.allocator.free(output.allocatedSlice());
            }
        }

        try output.writer(self.allocator).print(
            \\=== AST EDIT PREVIEW ===
            \\File: {s}
            \\Lines {d}-{d}
            \\Bytes {d}-{d}
            \\
            \\--- a/{s}
            \\+++ b/{s}
            \\{s}\n
        ,
        .{
            self.file_path,
            diff.start_line,
            diff.end_line,
            diff.start_byte,
            diff.end_byte,
            self.file_path,
            self.file_path,
            diff.hunk,
        });

        return output.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EDIT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Main edit engine
pub const EditEngine = struct {
    allocator: std.mem.Allocator,
    file_path: []const u8,

    /// Apply edit operation
    pub fn apply(allocator: std.mem.Allocator, op: EditOperation) !EditReport {
        var report = EditReport.init(allocator);
        errdefer report.deinit();

        // Read source file
        const source = try std.fs.cwd().readFileAlloc(allocator, op.file_path, 10_000_000);
        defer allocator.free(source);

        // Find matches
        var m = matcher.Matcher.init(allocator, source, op.file_path);
        var matches = try m.findMatches(op.pattern_query);
        defer matches.deinit();

        if (matches.isEmpty()) {
            try report.addViolation(try needle.Violation.init(
                allocator,
                .no_matches_found,
                0,
                "No matches found for pattern",
            ));
            return report;
        }

        // Use best match
        const best_match = matches.items.items[0];

        // Choose editor based on:
        // 1. Match kind (AST match has byte offsets)
        // 2. Safety level (high -> use AST)
        // 3. Edit mode (structural -> use AST)
        const use_ast = (best_match.kind == .exact_ast and
            (best_match.start_byte > 0 or best_match.end_byte > 0)) or
            op.safety_level == .high or
            op.edit_mode == .structural;

        if (use_ast) {
            return try applyASTEdit(allocator, source, best_match, op, &report);
        } else {
            return try applyTextEdit(allocator, source, best_match, op, &report);
        }
    }

    /// Apply edit using AST editor (Tier 1)
    fn applyASTEdit(
        allocator: std.mem.Allocator,
        source: []const u8,
        best_match: MatchResult,
        op: EditOperation,
        report: *needle.EditReport,
    ) !needle.EditReport {
        var ast_editor = try ASTEditor.init(allocator, source, op.file_path);
        defer ast_editor.deinit();

        // Compute diff with byte-level precision
        var diff = try ast_editor.computeDiff(best_match, op.replacement);
        defer diff.deinit(allocator);

        // Preview if requested
        if (op.preview) {
            const preview = try ast_editor.previewDiff(best_match, op.replacement);
            defer allocator.free(preview);
            // TODO: send preview to user
        }

        // Apply edit
        const modified = try ast_editor.applyDiff(diff);
        defer allocator.free(modified);

        // Run safety checks
        var checker = check.NeedleChecker.init(allocator, modified, op.file_path);
        const check_report = try checker.check();
        report.tests_passed = check_report.tests_passed;
        report.parse_ok = check_report.parse_ok;
        report.compile_ok = check_report.compile_ok;
        report.violations = check_report.violations;

        // If checks pass, write file
        if (report.isSuccess()) {
            try std.fs.cwd().writeFile(.{
                .sub_path = op.file_path,
                .data = modified,
            });
            report.operations_applied = 1;
            report.files_modified = 1;
        }

        return report.*;
    }

    /// Apply edit using text editor (Tier 0 fallback)
    fn applyTextEdit(
        allocator: std.mem.Allocator,
        source: []const u8,
        best_match: MatchResult,
        op: EditOperation,
        report: *needle.EditReport,
    ) !needle.EditReport {
        var editor = TextEditor.init(allocator, source, op.file_path);

        // Compute diff
        var diff = try editor.computeDiff(best_match, op.replacement);
        defer diff.deinit(allocator);

        // Preview if requested
        if (op.preview) {
            const preview = try editor.previewDiff(best_match, op.replacement);
            defer allocator.free(preview);
            // TODO: send preview to user
        }

        // Apply edit
        const modified = try editor.applyDiff(diff);
        defer allocator.free(modified);

        // Run safety checks
        var checker = check.NeedleChecker.init(allocator, modified, op.file_path);
        const check_report = try checker.check();
        report.tests_passed = check_report.tests_passed;
        report.parse_ok = check_report.parse_ok;
        report.compile_ok = check_report.compile_ok;
        report.violations = check_report.violations;

        // If checks pass, write file
        if (report.isSuccess()) {
            try std.fs.cwd().writeFile(.{
                .sub_path = op.file_path,
                .data = modified,
            });
            report.operations_applied = 1;
            report.files_modified = 1;
        }

        return report.*;
    }

    /// Apply multiple edits in batch
    pub fn applyBatch(allocator: std.mem.Allocator, ops: []const EditOperation) !EditReport {
        var combined_report = EditReport.init(allocator);
        errdefer combined_report.deinit();

        for (ops) |op| {
            const report = try apply(allocator, op);
            combined_report.operations_applied += report.operations_applied;
            combined_report.files_modified += report.files_modified;
            combined_report.tests_passed = combined_report.tests_passed and report.tests_passed;

            // Merge violations
            for (report.violations.items) |v| {
                // Clone violation
                const cloned = try needle.Violation.init(allocator, v.kind, v.line, v.message);
                try combined_report.addViolation(cloned);
            }
        }

        return combined_report;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TextEditor compute diff" {
    const source =
        \\pub fn oldName() void
        \\{
        \\    // content
        \\}
    ;

    var editor = TextEditor.init(std.testing.allocator, source, "test.zig");

    const match = MatchResult{
        .node_id = 1,
        .start_line = 1,
        .end_line = 1,
        .start_column = 0,
        .end_column = 0,
        .matched_text = "pub fn oldName() void",
        .confidence = 1.0,
        .kind = .fuzzy_text,
    };

    const replacement = "pub fn newName() void";

    var diff = try editor.computeDiff(match, replacement);
    defer diff.deinit();

    try std.testing.expectEqual(@as(u32, 1), diff.start_line);
    try std.testing.expect(std.mem.indexOf(u8, diff.new_text, "newName") != null);
}

test "TextEditor apply diff" {
    const source =
        \\line 1
        \\line 2
        \\line 3
    ;

    var editor = TextEditor.init(std.testing.allocator, source, "test.zig");

    const diff = EditDiff{
        .old_text = "line 2\n",
        .new_text = "modified line 2\n",
        .start_line = 2,
        .end_line = 2,
        .start_byte = 0,
        .end_byte = 0,
        .hunk = "@@ -2,0 +2,0 @@\n-line 2\n+modified line 2\n",
    };

    const result = try editor.applyDiff(diff);

    try std.testing.expect(std.mem.indexOf(u8, result, "modified line 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "line 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "line 3") != null);
}

test "EditEngine apply - no matches" {
    const tmp = std.testing.tmpDir;
    try tmp.writeFile("test.zig", "pub fn example() void {}");
    defer tmp.cleanup();

    const op = EditOperation.init("test.zig", "nonexistent", "replacement");

    const report = try EditEngine.apply(std.testing.allocator, op);
    defer report.deinit();

    try std.testing.expect(!report.isSuccess());
    try std.testing.expect(report.violations.items.len > 0);
}
