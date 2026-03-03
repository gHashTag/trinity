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
        const lines = std.mem.splitScalar(u8, self.source, '\n');

        var old_text = std.ArrayList(u8).init(self.allocator);
        errdefer old_text.deinit();

        // Extract the matched lines
        var line_idx: u32 = 1;
        while (line_idx < match_result.start_line) : (line_idx += 1) {
            _ = lines.next();
        }

        for (0..(match_result.end_line - match_result.start_line + 1)) |_| {
            if (lines.next()) |line| {
                try old_text.appendSlice(line);
                try old_text.append('\n');
            }
        }

        const old_dupe = try old_text.toOwnedSlice();
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
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        const lines = std.mem.splitScalar(u8, self.source, '\n');

        // Copy lines before the edit
        var line_idx: u32 = 1;
        while (line_idx < diff.start_line) : (line_idx += 1) {
            if (lines.next()) |line| {
                try result.appendSlice(line);
                try result.append('\n');
            }
        }

        // Skip the old lines
        for (0..(diff.end_line - diff.start_line + 1)) |_| {
            _ = lines.next();
        }

        // Insert new content
        try result.appendSlice(diff.new_text);

        // Ensure trailing newline
        if (result.items.len > 0 and result.items[result.items.len - 1] != '\n') {
            try result.append('\n');
        }

        // Copy remaining lines
        while (lines.next()) |line| {
            try result.appendSlice(line);
            try result.append('\n');
        }

        return result.toOwnedSlice();
    }

    /// Generate unified diff hunk
    fn generateHunk(self: *TextEditor, old_text: []const u8, new_text: []const u8, start_line: u32) ![]const u8 {
        var hunk = std.ArrayList(u8).init(self.allocator);
        try hunk.writer().print("@@ -{d},0 +{d},0 @@\n", .{ start_line, start_line });

        var old_lines = std.mem.splitScalar(u8, old_text, '\n');
        while (old_lines.next()) |line| {
            try hunk.writer().print("-{s}\n", .{line});
        }

        var new_lines = std.mem.splitScalar(u8, new_text, '\n');
        while (new_lines.next()) |line| {
            if (line.len > 0) {
                try hunk.writer().print("+{s}\n", .{line});
            }
        }

        return hunk.toOwnedSlice();
    }

    /// Preview diff as string
    pub fn previewDiff(self: *TextEditor, match_result: MatchResult, replacement: []const u8) ![]const u8 {
        var diff = try self.computeDiff(match_result, replacement);
        defer diff.deinit();

        var output = std.ArrayList(u8).init(self.allocator);
        try output.writer().print(
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

        return output.toOwnedSlice();
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
        const best_match = matches.items[0];

        // Compute diff
        var editor = TextEditor.init(allocator, source, op.file_path);
        const diff = try editor.computeDiff(best_match, op.replacement);
        defer diff.deinit();

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
        const checker = @import("check.zig").NeedleChecker;
        const check_report = try checker.checkSource(allocator, modified, op.file_path);
        report.tests_passed = check_report.tests_passed;
        report.parse_ok = check_report.parse_ok;
        report.compile_ok = check_report.compile_ok;
        report.violations = check_report.violations;
        report.violations.allocator = allocator;

        // If checks pass, write file
        if (report.isSuccess()) {
            try std.fs.cwd().writeFile(op.file_path, modified);
            report.operations_applied = 1;
            report.files_modified = 1;
        }

        return report;
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
