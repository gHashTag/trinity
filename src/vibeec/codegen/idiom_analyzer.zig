// ═══════════════════════════════════════════════════════════════════════════════
// IDIOM ANALYZER — Post-gen idiomatic Zig compliance checker (Cycle 77)
// ═══════════════════════════════════════════════════════════════════════════════
//
// String-based analysis of generated Zig code for idiomatic compliance.
// Follows ast_analyzer.zig pattern (no Tree-Sitter C dependency).
//
// Checks:
// 1. Duplicate parameters in function signatures (CRITICAL)
// 2. Unused allocator parameters (HIGH)
// 3. Empty structs that should be enums/zero-bit (MEDIUM)
// 4. Missing errdefer in fallible functions (MEDIUM)
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const Severity = enum {
    critical,
    high,
    medium,
    low,

    pub fn label(self: Severity) []const u8 {
        return switch (self) {
            .critical => "CRITICAL",
            .high => "HIGH",
            .medium => "MEDIUM",
            .low => "LOW",
        };
    }
};

pub const ViolationKind = enum {
    // Cycle 77 (string-based)
    duplicate_param,
    unused_allocator,
    empty_struct,
    missing_errdefer,
    // Cycle 78 (AST-based, requires tree-sitter)
    variable_shadowing,
    scope_aware_defer,
    comptime_misuse,
    missing_return_path,
    type_annotation_missing,
};

pub const Violation = struct {
    kind: ViolationKind,
    line: u32,
    message: []const u8,
    severity: Severity,
};

pub const Report = struct {
    violations: std.ArrayList(Violation) = .empty,
    total_functions: usize = 0,
    compliant_functions: usize = 0,
    allocator: std.mem.Allocator,

    pub fn compliancePercent(self: Report) f32 {
        if (self.total_functions == 0) return 100.0;
        return @as(f32, @floatFromInt(self.compliant_functions)) / @as(f32, @floatFromInt(self.total_functions)) * 100.0;
    }

    pub fn deinit(self: *Report) void {
        self.violations.deinit(self.allocator);
    }
};

pub const IdiomAnalyzer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,

    /// Run all idiom compliance checks on the source
    pub fn analyze(self: *IdiomAnalyzer) !Report {
        var report = Report{
            .allocator = self.allocator,
        };

        try self.checkDuplicateParams(&report);
        try self.checkUnusedAllocator(&report);
        try self.checkEmptyStructs(&report);
        try self.checkMissingErrdefer(&report);

        return report;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 1: Duplicate parameters in function signatures
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkDuplicateParams(self: *IdiomAnalyzer, report: *Report) !void {
        var pos: usize = 0;
        while (pos < self.source.len) {
            const fn_idx = std.mem.indexOfPos(u8, self.source, pos, "pub fn ") orelse break;
            const line = lineNumber(self.source, fn_idx);

            // Extract params: find ( and )
            const paren_open = std.mem.indexOfScalarPos(u8, self.source, fn_idx, '(') orelse break;
            const paren_close = std.mem.indexOfScalarPos(u8, self.source, paren_open, ')') orelse break;
            const params_str = self.source[paren_open + 1 .. paren_close];

            report.total_functions += 1;

            // Split params by comma and extract names
            var seen_names: [16][]const u8 = undefined;
            var seen_count: usize = 0;
            var has_duplicate = false;

            var param_iter = std.mem.splitScalar(u8, params_str, ',');
            while (param_iter.next()) |param_raw| {
                const param = std.mem.trim(u8, param_raw, " \t\n");
                if (param.len == 0) continue;

                // Extract param name (before ':')
                const colon_idx = std.mem.indexOfScalar(u8, param, ':') orelse continue;
                const name = std.mem.trim(u8, param[0..colon_idx], " \t");
                if (name.len == 0) continue;

                // Check for duplicate
                for (seen_names[0..seen_count]) |seen| {
                    if (std.mem.eql(u8, seen, name)) {
                        has_duplicate = true;
                        break;
                    }
                }

                if (seen_count < seen_names.len) {
                    seen_names[seen_count] = name;
                    seen_count += 1;
                }
            }

            if (has_duplicate) {
                try report.violations.append(self.allocator, .{
                    .kind = .duplicate_param,
                    .line = line,
                    .message = "Duplicate parameter name in function signature",
                    .severity = .critical,
                });
            } else {
                report.compliant_functions += 1;
            }

            pos = paren_close + 1;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 2: Unused allocator parameters
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkUnusedAllocator(self: *IdiomAnalyzer, report: *Report) !void {
        var pos: usize = 0;
        while (pos < self.source.len) {
            const fn_idx = std.mem.indexOfPos(u8, self.source, pos, "pub fn ") orelse break;
            const line = lineNumber(self.source, fn_idx);

            // Check if this function has allocator param
            const paren_open = std.mem.indexOfScalarPos(u8, self.source, fn_idx, '(') orelse break;
            const paren_close = std.mem.indexOfScalarPos(u8, self.source, paren_open, ')') orelse break;
            const params_str = self.source[paren_open + 1 .. paren_close];

            if (std.mem.indexOf(u8, params_str, "allocator") == null) {
                pos = paren_close + 1;
                continue;
            }

            // Find function body
            const body_start = std.mem.indexOfScalarPos(u8, self.source, paren_close, '{') orelse break;
            const body_end = findMatchingBrace(self.source, body_start) orelse break;
            const body = self.source[body_start..body_end];

            // Check if allocator is only used as `_ = allocator;`
            const has_discard = std.mem.indexOf(u8, body, "_ = allocator;") != null;
            const has_real_use = std.mem.indexOf(u8, body, "allocator.") != null or
                std.mem.indexOf(u8, body, "allocator,") != null or
                std.mem.indexOf(u8, body, "allocator)") != null;

            if (has_discard and !has_real_use) {
                try report.violations.append(self.allocator, .{
                    .kind = .unused_allocator,
                    .line = line,
                    .message = "Allocator parameter is discarded with '_ = allocator;'",
                    .severity = .high,
                });
            }

            pos = body_end + 1;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 3: Empty structs
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkEmptyStructs(self: *IdiomAnalyzer, report: *Report) !void {
        var pos: usize = 0;
        while (pos < self.source.len) {
            // Find "= struct {};" pattern (empty struct)
            const struct_idx = std.mem.indexOfPos(u8, self.source, pos, "= struct {};") orelse break;
            const line = lineNumber(self.source, struct_idx);

            try report.violations.append(self.allocator, .{
                .kind = .empty_struct,
                .line = line,
                .message = "Empty struct — consider using enum or removing",
                .severity = .medium,
            });

            pos = struct_idx + 12;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CHECK 4: Missing errdefer in fallible functions
    // ═══════════════════════════════════════════════════════════════════════════

    fn checkMissingErrdefer(self: *IdiomAnalyzer, report: *Report) !void {
        var pos: usize = 0;
        while (pos < self.source.len) {
            const fn_idx = std.mem.indexOfPos(u8, self.source, pos, "pub fn ") orelse break;
            const line = lineNumber(self.source, fn_idx);

            // Check if return type has error union (!)
            const paren_close = std.mem.indexOfScalarPos(u8, self.source, fn_idx, ')') orelse break;
            const body_start = std.mem.indexOfScalarPos(u8, self.source, paren_close, '{') orelse break;
            const ret_section = self.source[paren_close..body_start];

            const is_fallible = std.mem.indexOfScalar(u8, ret_section, '!') != null;
            if (!is_fallible) {
                pos = body_start + 1;
                continue;
            }

            // Find function body
            const body_end = findMatchingBrace(self.source, body_start) orelse break;
            const body = self.source[body_start..body_end];

            // Check if body has `try` but no `errdefer`
            const has_try = std.mem.indexOf(u8, body, "try ") != null;
            const has_errdefer = std.mem.indexOf(u8, body, "errdefer") != null;

            if (has_try and !has_errdefer) {
                try report.violations.append(self.allocator, .{
                    .kind = .missing_errdefer,
                    .line = line,
                    .message = "Fallible function with 'try' but no 'errdefer'",
                    .severity = .medium,
                });
            }

            pos = body_end + 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Count line number (1-indexed) at a given byte offset
fn lineNumber(source: []const u8, offset: usize) u32 {
    var line: u32 = 1;
    for (source[0..@min(offset, source.len)]) |c| {
        if (c == '\n') line += 1;
    }
    return line;
}

/// Find matching closing brace for code block
fn findMatchingBrace(source: []const u8, open_pos: usize) ?usize {
    var depth: usize = 1;
    var p = open_pos + 1;
    while (p < source.len and depth > 0) {
        switch (source[p]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return p;
            },
            else => {},
        }
        p += 1;
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "detect_duplicate_params" {
    const source =
        \\pub fn parseFields(allocator: std.mem.Allocator, allocator: std.mem.Allocator) ![]const u8 {
        \\    return "";
        \\}
    ;
    var analyzer = IdiomAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try analyzer.analyze();
    defer report.deinit();

    var found_dup = false;
    for (report.violations.items) |v| {
        if (v.kind == .duplicate_param) found_dup = true;
    }
    try std.testing.expect(found_dup);
}

test "no_false_positive_unique_params" {
    const source =
        \\pub fn encode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        \\    _ = allocator;
        \\    _ = input;
        \\    return "";
        \\}
    ;
    var analyzer = IdiomAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try analyzer.analyze();
    defer report.deinit();

    for (report.violations.items) |v| {
        try std.testing.expect(v.kind != .duplicate_param);
    }
}

test "detect_unused_allocator" {
    const source =
        \\pub fn myFunc(allocator: std.mem.Allocator) !void {
        \\    _ = allocator;
        \\    return;
        \\}
    ;
    var analyzer = IdiomAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try analyzer.analyze();
    defer report.deinit();

    var found = false;
    for (report.violations.items) |v| {
        if (v.kind == .unused_allocator) found = true;
    }
    try std.testing.expect(found);
}

test "detect_empty_struct" {
    const source =
        \\pub const EmptyType = struct {};
    ;
    var analyzer = IdiomAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try analyzer.analyze();
    defer report.deinit();

    var found = false;
    for (report.violations.items) |v| {
        if (v.kind == .empty_struct) found = true;
    }
    try std.testing.expect(found);
}

test "detect_missing_errdefer" {
    const source =
        \\pub fn fallible(input: []const u8) !void {
        \\    const x = try parse(input);
        \\    _ = x;
        \\}
    ;
    var analyzer = IdiomAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try analyzer.analyze();
    defer report.deinit();

    var found = false;
    for (report.violations.items) |v| {
        if (v.kind == .missing_errdefer) found = true;
    }
    try std.testing.expect(found);
}

test "compliance_percent" {
    const source =
        \\pub fn good(n: u32) u32 {
        \\    return n + 1;
        \\}
        \\pub fn bad(allocator: std.mem.Allocator, allocator: std.mem.Allocator) !void {
        \\    return;
        \\}
    ;
    var analyzer = IdiomAnalyzer{ .allocator = std.testing.allocator, .source = source };
    var report = try analyzer.analyze();
    defer report.deinit();

    try std.testing.expect(report.total_functions == 2);
    try std.testing.expect(report.compliant_functions == 1);
    try std.testing.expectApproxEqAbs(report.compliancePercent(), 50.0, 0.1);
}
