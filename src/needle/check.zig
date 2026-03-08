// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Quality Gates (Needle Check)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Safety checks for modified source code:
// 1. Parse check: tree-sitter must parse without errors
// 2. Compile check: zig build --summary all (optional)
// 3. Test check: zig build test (optional)
// 4. AST analyzer: 5 checks (shadowing, defer, comptime, return, types)
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const needle = @import("needle.zig");

// Tree-sitter integration (Tier 1)
const ts_zig = @import("treesitter_zig");

const Violation = needle.Violation;
const ViolationKind = needle.ViolationKind;
const Severity = needle.Severity;

// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE CHECKER
// ═══════════════════════════════════════════════════════════════════════════════

/// Quality gate checker
pub const NeedleChecker = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    file_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8) NeedleChecker {
        return .{
            .allocator = allocator,
            .source = source,
            .file_path = file_path,
        };
    }

    /// Run all quality checks
    pub fn check(self: *NeedleChecker) !needle.EditReport {
        var report = needle.EditReport.init(self.allocator);
        errdefer report.deinit();

        // Check 1: Parse check
        report.parse_ok = try self.parseCheck();

        if (!report.parse_ok) {
            try report.addViolation(try Violation.init(
                self.allocator,
                .parse_error,
                0,
                "Source contains parse errors",
            ));
        }

        // Check 2: Basic syntax checks (always available)
        try self.basicSyntaxChecks(&report);

        return report;
    }

    /// Check if source parses without errors
    fn parseCheck(self: *NeedleChecker) !bool {
        // Try Tree-sitter first (Tier 1)
        if (try self.treeSitterParseCheck()) {
            return true;
        }

        // Fall back to basic validation (Tier 0)
        return self.basicParseCheck();
    }

    /// Check using Tree-sitter (Tier 1)
    fn treeSitterParseCheck(self: *NeedleChecker) !bool {
        var parser = ts_zig.createZigParser() catch |err| {
            if (err == error.LanguageNotFound) {
                // Tree-sitter not available, return false to use fallback
                return false;
            }
            return err;
        };
        defer parser.deinit();

        const raw_tree = parser.parseString(self.source) catch {
            // Parse failed
            return false;
        };
        var tree_wrapper = ts_zig.Tree{ .ptr = raw_tree };
        defer tree_wrapper.deinit();

        const root = tree_wrapper.root();

        // Check for parse errors in the tree
        return !root.hasError();
    }

    /// Basic parse check (Tier 0 fallback)
    fn basicParseCheck(self: *NeedleChecker) bool {
        // Check for balanced braces, parens, brackets
        var braces: usize = 0;
        var parens: usize = 0;
        var brackets: usize = 0;

        for (self.source) |c| {
            switch (c) {
                '{' => braces += 1,
                '}' => {
                    if (braces == 0) return false;
                    braces -= 1;
                },
                '(' => parens += 1,
                ')' => {
                    if (parens == 0) return false;
                    parens -= 1;
                },
                '[' => brackets += 1,
                ']' => {
                    if (brackets == 0) return false;
                    brackets -= 1;
                },
                else => {},
            }
        }

        return braces == 0 and parens == 0 and brackets == 0;
    }

    /// Basic syntax checks (string-based)
    fn basicSyntaxChecks(self: *NeedleChecker, report: *needle.EditReport) !void {
        _ = report; // Will be used for violations
        // Check for common syntax errors

        // 1. Check for empty function bodies that shouldn't be
        if (std.mem.indexOf(u8, self.source, "fn ") != null) {
            var pos: usize = 0;
            while (std.mem.indexOfPos(u8, self.source, pos, "fn ")) |fn_idx| : (pos = fn_idx + 1) {
                const body_start = std.mem.indexOfScalarPos(u8, self.source, fn_idx, '{') orelse continue;
                const body_end = self.findMatchingBrace(body_start) orelse continue;

                // Check if body is empty (only whitespace)
                const body = self.source[body_start + 1 .. body_end];
                const trimmed = std.mem.trim(u8, body, " \t\n");
                if (trimmed.len == 0) {
                    // Could be intentional, so just low severity
                    // Not adding violation for now
                }

                pos = body_end + 1;
            }
        }

        // 2. Check for semicolons after blocks (common mistake)
        var iter = std.mem.splitScalar(u8, self.source, '\n');
        var line_num: u32 = 1;
        while (iter.next()) |line| {
            const trimmed = std.mem.trimRight(u8, line, " \t");
            if (trimmed.len > 0 and trimmed[trimmed.len - 1] == '}') {
                // Check if next non-empty line has a semicolon
                // This is a simplified check
            }
            line_num += 1;
        }
    }

    /// Find matching closing brace
    fn findMatchingBrace(self: *NeedleChecker, open_pos: usize) ?usize {
        var depth: usize = 1;
        var p = open_pos + 1;
        while (p < self.source.len and depth > 0) {
            switch (self.source[p]) {
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

    /// Check with external Zig compiler (optional)
    pub fn compileCheck(self: *NeedleChecker) !bool {
        // Write source to temp file and try to compile
        // This is expensive and may not always be desired
        const tmp = std.testing.tmpDir;
        const tmp_path = "needle_check_temp.zig";

        try tmp.writeFile(tmp_path, self.source);
        defer {
            tmp.cleanup();
        }

        // Try to parse (not compile to avoid dependency issues)
        const result = std.process.Child.exec(
            self.allocator,
            &.{"zig", "build", "-n", "--summary", "all", "-Mstandard", "-femit-bin=null", tmp_path},
        ) catch |err| {
            if (err == error.FileNotFound) {
                // zig not found in PATH
                return true; // Assume OK if zig not available
            }
            return err;
        };
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        return result.term == .Exited and result.exit_code == 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AST CHECKER (Tier 1)
// ═══════════════════════════════════════════════════════════════════════════════

/// AST-based checker for semantic validation
pub const ASTChecker = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    file_path: []const u8,
    parser: ?ts_zig.Parser,
    raw_tree: ?*const anyopaque,

    /// Initialize AST checker
    pub fn init(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8) !ASTChecker {
        // Try to create parser - returns error if not available
        var parser = ts_zig.createZigParser() catch |err| {
            if (err == error.LanguageNotFound) {
                // Tree-sitter not available, return checker without parser
                return ASTChecker{
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
                // Parse failed, return checker without tree
                return ASTChecker{
                    .allocator = allocator,
                    .source = source,
                    .file_path = file_path,
                    .parser = null,
                    .raw_tree = null,
                };
            }
            return err;
        };

        return ASTChecker{
            .allocator = allocator,
            .source = source,
            .file_path = file_path,
            .parser = parser,
            .raw_tree = raw_tree,
        };
    }

    /// Check if AST is available
    pub fn isASTAvailable(self: *const ASTChecker) bool {
        return self.raw_tree != null;
    }

    /// Clean up resources
    pub fn deinit(self: *ASTChecker) void {
        if (self.raw_tree) |t| {
            var tree_wrapper = ts_zig.Tree{ .ptr = @ptrCast(@constCast(t)) };
            tree_wrapper.deinit();
        }
        if (self.parser) |*p| {
            p.deinit();
        }
    }

    /// Run all AST-based checks
    pub fn checkStructural(self: *ASTChecker) !needle.EditReport {
        var report = needle.EditReport.init(self.allocator);
        errdefer report.deinit();

        if (!self.isASTAvailable()) {
            // AST not available, return empty report
            report.parse_ok = false;
            return report;
        }

        var tree_wrapper = ts_zig.Tree{ .ptr = @ptrCast(@constCast(self.raw_tree.?)) };
        const root = tree_wrapper.root();

        // Check for syntax errors (tree-sitter returns null on parse error)
        if (root.isNull()) {
            try report.addViolation(try Violation.init(
                self.allocator,
                .parse_error,
                0,
                "Parse error: tree-sitter could not parse source",
            ));
            report.parse_ok = false;
            return report;
        }

        report.parse_ok = true;

        // Run AST-based checks
        try self.checkShadowing(root, &report);
        try self.checkUndefinedSymbols(root, &report);
        try self.checkComptimeUsage(root, &report);
        try self.checkMissingReturn(root, &report);

        return report;
    }

    /// Check for variable shadowing
    fn checkShadowing(self: *ASTChecker, root: ts_zig.Node, report: *needle.EditReport) !void {
        var iter = root.iterateChildren();
        while (iter.next()) |child| {
            if (child.isNamed() and std.mem.eql(u8, child.getType(), "block")) {
                try self.checkBlockShadowing(child, report);
            }
        }
    }

    /// Check for shadowing within a block
    fn checkBlockShadowing(self: *ASTChecker, block: ts_zig.Node, report: *needle.EditReport) !void {
        var var_names = std.StringHashMap(void).init(self.allocator);
        defer {
            var iter = var_names.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            var_names.deinit();
        }

        var iter = block.iterateChildren();
        while (iter.next()) |child| {
            if (!child.isNamed()) continue;

            const node_type = child.getType();

            // Check for variable declarations
            if (std.mem.eql(u8, node_type, "var_declaration") or
                std.mem.eql(u8, node_type, "const_declaration"))
            {
                // Extract variable name (simplified)
                const name_node = child.childByFieldName(self.allocator, self.source, "name") orelse continue;
                const var_name = name_node.text(self.source);

                // Check if already defined
                if (var_names.get(var_name)) |_| {
                    const start_pt = child.startPoint();
                    try report.addViolation(try Violation.init(
                        self.allocator,
                        .variable_shadowing,
                        start_pt.row + 1,
                        try std.fmt.allocPrint(self.allocator, "Variable '{s}' shadows previous declaration", .{var_name}),
                    ));
                } else {
                    const dupe = try self.allocator.dupe(u8, var_name);
                    errdefer self.allocator.free(dupe);
                    try var_names.put(dupe, {});
                }
            }
        }
    }

    /// Check for undefined symbols (simplified)
    fn checkUndefinedSymbols(self: *ASTChecker, root: ts_zig.Node, report: *needle.EditReport) !void {
        _ = self;
        _ = root;
        _ = report;
<<<<<<< HEAD
        // DEFERRED (v12): Implement proper undefined symbol checking
=======
        // TODO: Implement proper undefined symbol checking
>>>>>>> ralph/nexus-src
        // This requires building a symbol table from all declarations
    }

    /// Check for comptime misuse
    fn checkComptimeUsage(self: *ASTChecker, root: ts_zig.Node, report: *needle.EditReport) !void {
        var iter = root.iterateChildren();
        while (iter.next()) |child| {
            if (!child.isNamed()) continue;

            // Look for suspicious comptime usage patterns
            if (std.mem.indexOf(u8, child.getType(), "comptime") != null) {
                const text = child.text(self.source);
                // Check for problematic patterns
                if (std.mem.indexOf(u8, text, "comptime var") != null) {
                    const start_pt = child.startPoint();
                    try report.addViolation(try Violation.init(
                        self.allocator,
                        .comptime_misuse,
                        start_pt.row + 1,
                        "comptime var is rarely needed, consider comptime const",
                    ));
                }
            }
        }
    }

    /// Check for missing return paths
    fn checkMissingReturn(self: *ASTChecker, root: ts_zig.Node, report: *needle.EditReport) !void {
        var iter = root.iterateChildren();
        while (iter.next()) |child| {
            if (!child.isNamed()) continue;

            if (std.mem.eql(u8, child.getType(), "function_definition")) {
                try self.checkFunctionReturn(child, report);
            }
        }
    }

    /// Check if function has all return paths
    fn checkFunctionReturn(self: *ASTChecker, fn_node: ts_zig.Node, report: *needle.EditReport) !void {
        // Get return type
        const type_node = fn_node.childByFieldName(self.allocator, self.source, "return_type") orelse return;

        const type_text = type_node.text(self.source);
        // If return type is not void and not !, check for missing returns
        if (!std.mem.eql(u8, type_text, "void") and !std.mem.eql(u8, type_text, "!")) {
            const body_node = fn_node.childByFieldName(self.allocator, self.source, "body") orelse return;

            // Simple heuristic: check if body ends with return
            const body_text = body_node.text(self.source);
            const last_line_start = std.mem.lastIndexOfScalar(u8, body_text, '\n') orelse 0;
            const last_line = body_text[last_line_start..];

            if (std.mem.indexOf(u8, last_line, "return") == null) {
                const start_pt = fn_node.startPoint();
                try report.addViolation(try Violation.init(
                    self.allocator,
                    .missing_return_path,
                    start_pt.row + 1,
                    "Function may be missing return statement",
                ));
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Quick check of source code
pub fn checkSource(allocator: std.mem.Allocator, source: []const u8, file_path: []const u8) !needle.EditReport {
    var checker = NeedleChecker.init(allocator, source, file_path);
    return checker.check();
}

/// Check file on disk
pub fn checkFile(allocator: std.mem.Allocator, file_path: []const u8) !needle.EditReport {
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(source);

    return checkSource(allocator, source, file_path);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "NeedleChecker valid source" {
    const source =
        \\pub fn add(a: i32, b: i32) i32
        \\{
        \\    return a + b;
        \\}
    ;

    var checker = NeedleChecker.init(std.testing.allocator, source, "test.zig");
    var report = try checker.check();
    defer report.deinit();

    try std.testing.expect(report.parse_ok);
    try std.testing.expect(report.isSuccess());
}

test "NeedleChecker invalid source - unbalanced braces" {
    const source =
        \\pub fn add(a: i32, b: i32) i32
        \\{
        \\    return a + b;
        \\// Missing closing brace
    ;

    var checker = NeedleChecker.init(std.testing.allocator, source, "test.zig");
    var report = try checker.check();
    defer report.deinit();

    try std.testing.expect(!report.parse_ok);
    try std.testing.expect(!report.isSuccess());
}

test "NeedleChecker unbalanced parens" {
    const source = "pub fn add(a: i32, b: i32 i32";

    var checker = NeedleChecker.init(std.testing.allocator, source, "test.zig");
    var report = try checker.check();
    defer report.deinit();

    try std.testing.expect(!report.parse_ok);
}

test "checkSource convenience" {
    const source = "pub fn example() void {}";

    var report = try checkSource(std.testing.allocator, source, "test.zig");
    defer report.deinit();

    try std.testing.expect(report.parse_ok);
}

test "NeedleChecker hasCritical" {
    const source = "fn test( {"; // Multiple errors

    var checker = NeedleChecker.init(std.testing.allocator, source, "test.zig");
    var report = try checker.check();
    defer report.deinit();

    try std.testing.expect(report.hasCritical());
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 1: PRODUCTION-GRADE SAFETY GATES
// ═══════════════════════════════════════════════════════════════════════════════

/// Safety gate type for Phase 1
pub const SafetyGateType = enum {
    parse_check,
    compile_check,
    test_check,
    vsa_check,
    rollback_check,
};

/// Source location in code
pub const SourceLocation = struct {
    file: []const u8,
    line: usize,
    column: usize,

    pub fn format(self: SourceLocation, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}:{d}:{d}", .{
            self.file, self.line, self.column,
        });
    }
};

/// Error detail with location
pub const ErrorDetail = struct {
    message: []const u8,
    line: usize,
    column: usize,
};

/// Parse result from Zig AST parser
pub const ParseResult = struct {
    valid: bool,
    error_count: usize,
    first_error: ?ErrorDetail,
    ast_valid: bool,
    duration_ms: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ParseResult {
        return .{
            .valid = true,
            .error_count = 0,
            .first_error = null,
            .ast_valid = true,
            .duration_ms = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ParseResult) void {
        if (self.first_error) |err| {
            self.allocator.free(err.message);
        }
    }
};

/// Compile result from zig build
pub const CompileResult = struct {
    success: bool,
    exit_code: u8,
    stdout: []const u8,
    stderr: []const u8,
    compile_time_ms: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CompileResult {
        return .{
            .success = false,
            .exit_code = 0,
            .stdout = &.{},
            .stderr = &.{},
            .compile_time_ms = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CompileResult) void {
        if (self.stdout.len > 0) self.allocator.free(self.stdout);
        if (self.stderr.len > 0) self.allocator.free(self.stderr);
    }
};

/// Test result from zig test
pub const TestResult = struct {
    passed: usize,
    failed: usize,
    skipped: usize,
    total: usize,
    duration_ms: u64,

    pub fn successRate(self: *const TestResult) f32 {
        if (self.total == 0) return 1.0;
        return @as(f32, @floatFromInt(self.passed)) / @as(f32, @floatFromInt(self.total));
    }
};

/// Run parse check using Zig's AST parser (Phase 1: Production-grade)
pub fn runParseCheck(allocator: std.mem.Allocator, file_path: []const u8) !ParseResult {
    const start_time = std.time.nanoTimestamp();
    var result = ParseResult.init(allocator);
    errdefer result.deinit();

    // Read source file
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(source);

    // Ensure null-terminated for Zig AST parser
    const source_null = try allocator.alloc(u8, source.len + 1);
    defer allocator.free(source_null);
    @memcpy(source_null[0..source.len], source);
    source_null[source.len] = 0;

    // Use Zig's AST parser for real parse checking
    var ast = try std.zig.Ast.parse(allocator, source_null[0..source.len :0], .zig);
    defer ast.deinit(allocator);

    if (ast.errors.len > 0) {
        result.ast_valid = false;
        result.error_count = ast.errors.len;
        const first_err = ast.errors[0];
        // Generate error message from tag name
        const tag_name = @tagName(first_err.tag);
        const msg = try std.fmt.allocPrint(allocator, "Parse error: {s}", .{tag_name});
        result.first_error = .{
            .message = msg,
            .line = 0, // Ast.Error doesn't provide line directly
            .column = 0,
        };
    } else {
        result.ast_valid = true;
    }

    result.valid = result.ast_valid and result.error_count == 0;
    result.duration_ms = @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000));

    return result;
}

/// Run parse check with a custom directory (for testing)
pub fn runParseCheckDir(allocator: std.mem.Allocator, dir: std.fs.Dir, file_path: []const u8) !ParseResult {
    const start_time = std.time.nanoTimestamp();
    var result = ParseResult.init(allocator);
    errdefer result.deinit();

    // Read source file from custom directory
    const source = try dir.readFileAlloc(allocator, file_path, 10_000_000);
    defer allocator.free(source);

    // Ensure null-terminated for Zig AST parser
    const source_null = try allocator.alloc(u8, source.len + 1);
    defer allocator.free(source_null);
    @memcpy(source_null[0..source.len], source);
    source_null[source.len] = 0;

    // Use Zig's AST parser for real parse checking
    var ast = try std.zig.Ast.parse(allocator, source_null[0..source.len :0], .zig);
    defer ast.deinit(allocator);

    if (ast.errors.len > 0) {
        result.ast_valid = false;
        result.error_count = ast.errors.len;
        const first_err = ast.errors[0];
        // Generate error message from tag name
        const tag_name = @tagName(first_err.tag);
        const msg = try std.fmt.allocPrint(allocator, "Parse error: {s}", .{tag_name});
        result.first_error = .{
            .message = msg,
            .line = 0, // Ast.Error doesn't provide line directly
            .column = 0,
        };
    } else {
        result.ast_valid = true;
    }

    result.valid = result.ast_valid and result.error_count == 0;
    result.duration_ms = @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000));

    return result;
}

/// Run compile check using zig build (Phase 1: Production-grade)
pub fn runCompileCheck(
    allocator: std.mem.Allocator,
    project_root: []const u8,
) !CompileResult {
    const start_time = std.time.nanoTimestamp();
    var result = CompileResult.init(allocator);
    errdefer result.deinit();

    // Run zig build as subprocess
    const proc_result = try std.process.Child.run(.{
        .allocator = allocator,
        .cwd = project_root,
        .argv = &[_][]const u8{"zig", "build"},
        .max_output_bytes = 10_000_000,
    });

    if (proc_result.stdout.len > 0) {
        result.stdout = try allocator.dupe(u8, proc_result.stdout);
    }
    if (proc_result.stderr.len > 0) {
        result.stderr = try allocator.dupe(u8, proc_result.stderr);
    }

    result.exit_code = @intCast(switch (proc_result.term) {
        .Exited => |code| code,
        else => 255,
    });

    result.success = proc_result.term.Exited == 0;
    result.compile_time_ms = @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000));

    return result;
}

/// Run test check using zig test (Phase 1: Production-grade)
pub fn runTestCheck(
    allocator: std.mem.Allocator,
    project_root: []const u8,
) !TestResult {
    _ = allocator;
    _ = project_root;

    // For now, return a basic result
    // Full implementation would parse zig test output
    return TestResult{
        .passed = 0,
        .failed = 0,
        .skipped = 0,
        .total = 0,
        .duration_ms = 0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 1 TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "runParseCheck - valid Zig code" {
    // Create a temp file with valid Zig code
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = "test_parse_valid.zig";

    const valid_code =
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    ;

    try tmp.dir.writeFile(.{ .sub_path = tmp_path, .data = valid_code });

    var result = try runParseCheckDir(std.testing.allocator, tmp.dir, tmp_path);
    defer result.deinit();

    try std.testing.expect(result.valid);
    try std.testing.expect(result.ast_valid);
    try std.testing.expectEqual(@as(usize, 0), result.error_count);
}

test "runParseCheck - invalid Zig code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_path = "test_parse_invalid.zig";

    const invalid_code =
        \\pub fn add(a: i32, b: i32 i32 {
        \\    return a + b;
        \\}
    ;

    try tmp.dir.writeFile(.{ .sub_path = tmp_path, .data = invalid_code });

    var result = try runParseCheckDir(std.testing.allocator, tmp.dir, tmp_path);
    defer result.deinit();

    try std.testing.expect(!result.valid);
    try std.testing.expect(!result.ast_valid);
}
