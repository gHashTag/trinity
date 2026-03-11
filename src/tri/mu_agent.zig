const std = @import("std");

/// MU Agent — Memory Unit for the Trinity swarm.
/// Detects error patterns from compile output, logs them to JSONL storage,
/// suggests fixes based on known patterns, and reports statistics.
pub const MuAgent = struct {
    allocator: std.mem.Allocator,
    patterns: std.ArrayList(ErrorPattern),
    storage_path: []const u8,

    pub const ErrorCategory = enum {
        ast_fail,
        gen_fail,
        format_fail,
        type_mismatch,
        import_fail,
        unknown,

        pub fn toString(self: ErrorCategory) []const u8 {
            return switch (self) {
                .ast_fail => "ast_fail",
                .gen_fail => "gen_fail",
                .format_fail => "format_fail",
                .type_mismatch => "type_mismatch",
                .import_fail => "import_fail",
                .unknown => "unknown",
            };
        }

        pub fn fromString(s: []const u8) ErrorCategory {
            if (std.mem.eql(u8, s, "ast_fail")) return .ast_fail;
            if (std.mem.eql(u8, s, "gen_fail")) return .gen_fail;
            if (std.mem.eql(u8, s, "format_fail")) return .format_fail;
            if (std.mem.eql(u8, s, "type_mismatch")) return .type_mismatch;
            if (std.mem.eql(u8, s, "import_fail")) return .import_fail;
            return .unknown;
        }
    };

    pub const ErrorPattern = struct {
        id: []const u8,
        error_text: []const u8,
        category: ErrorCategory,
        count: u32,
        first_seen: i64,
        last_seen: i64,
        spec_file: []const u8,
        fix_suggestion: []const u8,
        auto_fixable: bool,
        resolved: bool,
    };

    pub const MuReport = struct {
        total_patterns: usize,
        unresolved: usize,
        auto_fixable: usize,
        by_category: [6]u32,
        top_patterns: []const ErrorPattern,
    };

    pub const DetectResult = struct {
        patterns: []ErrorPattern,
        new_count: usize,
        updated_count: usize,
    };

    pub fn init(allocator: std.mem.Allocator, storage_path: []const u8) MuAgent {
        return .{
            .allocator = allocator,
            .patterns = .empty,
            .storage_path = storage_path,
        };
    }

    pub fn deinit(self: *MuAgent) void {
        for (self.patterns.items) |p| {
            if (p.id.len > 0) self.allocator.free(p.id);
            if (p.error_text.len > 0) self.allocator.free(p.error_text);
            if (p.spec_file.len > 0) self.allocator.free(p.spec_file);
        }
        self.patterns.deinit(self.allocator);
    }

    /// Load patterns from JSONL storage file.
    pub fn load(self: *MuAgent) !void {
        const file = std.fs.cwd().openFile(self.storage_path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        var iter = std.mem.splitScalar(u8, content, '\n');
        while (iter.next()) |line| {
            if (line.len == 0) continue;
            const pattern = parsePatternLine(self.allocator, line) catch continue;
            try self.patterns.append(self.allocator, pattern);
        }
    }

    /// Detect error patterns from compile output text.
    /// Returns list of matched/new patterns.
    pub fn detect(self: *MuAgent, compile_output: []const u8, spec_file: []const u8) !DetectResult {
        var new_count: usize = 0;
        var updated_count: usize = 0;
        const now = std.time.timestamp();

        // Pattern detection rules
        const rules = [_]struct { needle: []const u8, category: ErrorCategory, suggestion: []const u8, fixable: bool }{
            .{ .needle = "error: expected type", .category = .type_mismatch, .suggestion = "Check type mapping in emitter — likely List/Option → std type mismatch", .fixable = true },
            .{ .needle = "error: expected expression", .category = .ast_fail, .suggestion = "Generated code has syntax error — check emitter output for malformed expressions", .fixable = true },
            .{ .needle = "formatting check failed", .category = .format_fail, .suggestion = "Run zig fmt on generated file before ast-check", .fixable = true },
            .{ .needle = "error: unused local", .category = .ast_fail, .suggestion = "Generated variable not used — emitter creating dead code", .fixable = true },
            .{ .needle = "error.OutOfMemory", .category = .gen_fail, .suggestion = "Generator OOM — spec may be too large or have circular refs", .fixable = false },
            .{ .needle = "error: unable to open", .category = .import_fail, .suggestion = "Generated @import references non-existent file", .fixable = true },
            .{ .needle = "panicked", .category = .gen_fail, .suggestion = "Generator panicked — likely assertion failure in emitter", .fixable = false },
            .{ .needle = "error:", .category = .unknown, .suggestion = "Unknown error — analyze manually", .fixable = false },
        };

        for (rules) |rule| {
            if (std.mem.indexOf(u8, compile_output, rule.needle)) |_| {
                // Check if pattern exists
                var found = false;
                for (self.patterns.items) |*p| {
                    if (p.category == rule.category and std.mem.eql(u8, p.spec_file, spec_file)) {
                        p.count += 1;
                        p.last_seen = now;
                        updated_count += 1;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    const id = try std.fmt.allocPrint(self.allocator, "{s}_{d}", .{ rule.category.toString(), now });
                    try self.patterns.append(self.allocator, .{
                        .id = id,
                        .error_text = try self.allocator.dupe(u8, extractErrorLine(compile_output, rule.needle)),
                        .category = rule.category,
                        .count = 1,
                        .first_seen = now,
                        .last_seen = now,
                        .spec_file = try self.allocator.dupe(u8, spec_file),
                        .fix_suggestion = rule.suggestion,
                        .auto_fixable = rule.fixable,
                        .resolved = false,
                    });
                    new_count += 1;
                }
                break; // Match first rule only (most specific first)
            }
        }

        return .{
            .patterns = self.patterns.items,
            .new_count = new_count,
            .updated_count = updated_count,
        };
    }

    /// Log a pattern to the JSONL storage file.
    pub fn log(self: *MuAgent, pattern: ErrorPattern) !void {
        if (std.fs.path.dirname(self.storage_path)) |dir| {
            std.fs.cwd().makePath(dir) catch {};
        }

        const file = try std.fs.cwd().createFile(self.storage_path, .{
            .truncate = false,
        });
        defer file.close();
        try file.seekFromEnd(0);

        const line = try std.fmt.allocPrint(self.allocator, "{{\"id\":\"{s}\",\"category\":\"{s}\",\"count\":{d},\"spec\":\"{s}\",\"fix\":\"{s}\",\"auto\":{},\"resolved\":{},\"first\":{d},\"last\":{d}}}\n", .{
            pattern.id,        pattern.category.toString(), pattern.count,
            pattern.spec_file, pattern.fix_suggestion,      pattern.auto_fixable,
            pattern.resolved,  pattern.first_seen,          pattern.last_seen,
        });
        defer self.allocator.free(line);
        try file.writeAll(line);
    }

    /// Suggest a fix for a given error text.
    pub fn suggest(self: *MuAgent, error_text: []const u8) ?[]const u8 {
        // Search existing patterns for a match
        for (self.patterns.items) |p| {
            if (!p.resolved and std.mem.indexOf(u8, error_text, p.error_text) != null) {
                return p.fix_suggestion;
            }
        }

        // Fallback rule-based suggestions
        if (std.mem.indexOf(u8, error_text, "expected type") != null) {
            return "Check type mapping in emitter — likely List/Option → std type mismatch";
        }
        if (std.mem.indexOf(u8, error_text, "formatting check") != null) {
            return "Run zig fmt on generated file before ast-check";
        }
        if (std.mem.indexOf(u8, error_text, "panicked") != null) {
            return "Generator panicked — check assertion in emitter";
        }

        return null;
    }

    /// Generate statistics report.
    pub fn stats(self: *MuAgent) MuReport {
        var by_category = [_]u32{0} ** 6;
        var unresolved: usize = 0;
        var auto_fixable: usize = 0;

        for (self.patterns.items) |p| {
            by_category[@intFromEnum(p.category)] += 1;
            if (!p.resolved) unresolved += 1;
            if (p.auto_fixable and !p.resolved) auto_fixable += 1;
        }

        return .{
            .total_patterns = self.patterns.items.len,
            .unresolved = unresolved,
            .auto_fixable = auto_fixable,
            .by_category = by_category,
            .top_patterns = self.patterns.items,
        };
    }

    /// Save all patterns to storage (full rewrite).
    pub fn save(self: *MuAgent) !void {
        if (std.fs.path.dirname(self.storage_path)) |dir| {
            std.fs.cwd().makePath(dir) catch {};
        }

        const file = try std.fs.cwd().createFile(self.storage_path, .{});
        defer file.close();

        for (self.patterns.items) |p| {
            const line = try std.fmt.allocPrint(self.allocator, "{{\"id\":\"{s}\",\"category\":\"{s}\",\"count\":{d},\"spec\":\"{s}\",\"fix\":\"{s}\",\"auto\":{},\"resolved\":{},\"first\":{d},\"last\":{d}}}\n", .{
                p.id,
                p.category.toString(),
                p.count,
                p.spec_file,
                p.fix_suggestion,
                p.auto_fixable,
                p.resolved,
                p.first_seen,
                p.last_seen,
            });
            defer self.allocator.free(line);
            try file.writeAll(line);
        }
    }

    /// Format a report as a printable string.
    pub fn formatReport(self: *MuAgent, writer: anytype) !void {
        const report = self.stats();
        try writer.print(
            \\🧠 MU STATUS REPORT
            \\═══════════════════════════════════════
            \\  Total patterns:  {d}
            \\  Unresolved:      {d}
            \\  Auto-fixable:    {d}
            \\
            \\  By category:
            \\    ast_fail:      {d}
            \\    gen_fail:      {d}
            \\    format_fail:   {d}
            \\    type_mismatch: {d}
            \\    import_fail:   {d}
            \\    unknown:       {d}
            \\
        , .{
            report.total_patterns,
            report.unresolved,
            report.auto_fixable,
            report.by_category[0],
            report.by_category[1],
            report.by_category[2],
            report.by_category[3],
            report.by_category[4],
            report.by_category[5],
        });

        if (report.total_patterns > 0) {
            try writer.print("  Top patterns:\n", .{});
            const limit = @min(report.total_patterns, 10);
            for (report.top_patterns[0..limit]) |p| {
                try writer.print("    [{s}] {s} — count:{d} fix:{s}\n", .{
                    p.category.toString(),
                    p.spec_file,
                    p.count,
                    if (p.auto_fixable) "auto" else "manual",
                });
            }
        }
    }

    // --- Internal helpers ---

    fn extractErrorLine(output: []const u8, needle: []const u8) []const u8 {
        const idx = std.mem.indexOf(u8, output, needle) orelse return needle;
        // Find line start
        var start = idx;
        while (start > 0 and output[start - 1] != '\n') start -= 1;
        // Find line end
        var end = idx + needle.len;
        while (end < output.len and output[end] != '\n') end += 1;
        return output[start..end];
    }

    fn parsePatternLine(allocator: std.mem.Allocator, line: []const u8) !ErrorPattern {
        // Simple JSON field extraction (no full parser needed for JSONL)
        return .{
            .id = try extractJsonString(allocator, line, "\"id\":\""),
            .error_text = "",
            .category = ErrorCategory.fromString(try extractJsonString(allocator, line, "\"category\":\"")),
            .count = extractJsonInt(line, "\"count\":") orelse 1,
            .first_seen = @intCast(extractJsonInt(line, "\"first\":") orelse 0),
            .last_seen = @intCast(extractJsonInt(line, "\"last\":") orelse 0),
            .spec_file = try extractJsonString(allocator, line, "\"spec\":\""),
            .fix_suggestion = try extractJsonString(allocator, line, "\"fix\":\""),
            .auto_fixable = std.mem.indexOf(u8, line, "\"auto\":true") != null,
            .resolved = std.mem.indexOf(u8, line, "\"resolved\":true") != null,
        };
    }

    fn extractJsonString(allocator: std.mem.Allocator, json: []const u8, prefix: []const u8) ![]const u8 {
        const start_idx = (std.mem.indexOf(u8, json, prefix) orelse return "") + prefix.len;
        const end_idx = std.mem.indexOfPos(u8, json, start_idx, "\"") orelse return "";
        return try allocator.dupe(u8, json[start_idx..end_idx]);
    }

    fn extractJsonInt(json: []const u8, prefix: []const u8) ?u32 {
        const start_idx = (std.mem.indexOf(u8, json, prefix) orelse return null) + prefix.len;
        var end_idx = start_idx;
        while (end_idx < json.len and json[end_idx] >= '0' and json[end_idx] <= '9') end_idx += 1;
        if (end_idx == start_idx) return null;
        return std.fmt.parseInt(u32, json[start_idx..end_idx], 10) catch null;
    }
};

test "MuAgent detect ast_fail" {
    var mu = MuAgent.init(std.testing.allocator, "/tmp/mu_test.jsonl");
    defer mu.deinit();

    const output = "error: expected expression after 'if'\nsomething else";
    const result = try mu.detect(output, "specs/tri/test.tri");
    try std.testing.expectEqual(@as(usize, 1), result.new_count);
    try std.testing.expectEqual(@as(usize, 1), mu.patterns.items.len);
    try std.testing.expectEqual(MuAgent.ErrorCategory.ast_fail, mu.patterns.items[0].category);
}

test "MuAgent detect format_fail" {
    var mu = MuAgent.init(std.testing.allocator, "/tmp/mu_test2.jsonl");
    defer mu.deinit();

    const output = "formatting check failed (run 'zig fmt ...')";
    const result = try mu.detect(output, "specs/tri/fmt_test.tri");
    try std.testing.expectEqual(@as(usize, 1), result.new_count);
    try std.testing.expectEqual(MuAgent.ErrorCategory.format_fail, mu.patterns.items[0].category);
}

test "MuAgent detect updates existing" {
    var mu = MuAgent.init(std.testing.allocator, "/tmp/mu_test3.jsonl");
    defer mu.deinit();

    const output = "error: expected expression";
    _ = try mu.detect(output, "specs/tri/dup.tri");
    const result2 = try mu.detect(output, "specs/tri/dup.tri");
    try std.testing.expectEqual(@as(usize, 0), result2.new_count);
    try std.testing.expectEqual(@as(usize, 1), result2.updated_count);
    try std.testing.expectEqual(@as(u32, 2), mu.patterns.items[0].count);
}

test "MuAgent suggest" {
    var mu = MuAgent.init(std.testing.allocator, "/tmp/mu_test4.jsonl");
    defer mu.deinit();

    const suggestion = mu.suggest("error: expected type 'u32', found 'List'");
    try std.testing.expect(suggestion != null);
}

test "MuAgent stats" {
    var mu = MuAgent.init(std.testing.allocator, "/tmp/mu_test5.jsonl");
    defer mu.deinit();

    _ = try mu.detect("error: expected expression", "specs/tri/a.tri");
    _ = try mu.detect("formatting check failed", "specs/tri/b.tri");

    const report = mu.stats();
    try std.testing.expectEqual(@as(usize, 2), report.total_patterns);
    try std.testing.expectEqual(@as(usize, 2), report.unresolved);
}
