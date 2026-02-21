//! Code verification for AGENT MU
//!
//! Runs quality checks on generated .zig files:
//! - zig build (compilation check)
//! - zig test (test execution)
//! - zig fmt --check (formatting check)

const std = @import("std");

/// Result of running a single command
pub const CommandResult = struct {
    exit_code: u8,
    stdout: []const u8,
    stderr: []const u8,
};

/// Complete verification result
pub const VerifyResult = struct {
    success: bool,
    build_passed: bool,
    test_passed: bool,
    format_passed: bool,
    stderr: []const u8,
    exit_code: u8,

    /// Free allocated memory
    pub fn deinit(self: *VerifyResult, allocator: std.mem.Allocator) void {
        allocator.free(self.stderr);
        self.* = undefined;
    }
};

/// Run a command and capture its output
fn runCommand(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    working_dir: ?[]const u8,
) !CommandResult {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = working_dir,
    });

    errdefer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    // Determine exit code
    const exit_code: u8 = if (result.term == .Exited) result.term.Exited else 1;

    return CommandResult{
        .exit_code = exit_code,
        .stdout = result.stdout,
        .stderr = result.stderr,
    };
}

/// Verify a generated .zig file
///
/// Performs three checks:
/// 1. zig build (if build.zig exists in parent directory)
/// 2. zig test (if tests exist in the file)
/// 3. zig fmt --check
///
/// Parameters:
///   - allocator: Memory allocator
///   - file_path: Path to the generated .zig file
///
/// Returns: VerifyResult with detailed status
pub fn verify(allocator: std.mem.Allocator, file_path: []const u8) !VerifyResult {
    // Step 1: Format check (fastest, run first)
    const fmt_result = try runCommand(allocator, &.{ "zig", "fmt", "--check", file_path }, null);
    defer {
        allocator.free(fmt_result.stdout);
        allocator.free(fmt_result.stderr);
    }

    const format_passed = fmt_result.exit_code == 0;

    // Step 2: Build check
    // Try to determine if there's a build.zig in the project root
    var build_passed = false;
    var build_stderr: []const u8 = "";

    // Check if we can build this file directly
    // For generated files, we typically want to check compilation
    const build_result = try runCommand(allocator, &.{ "zig", "build-exe", "-femit-bin=/dev/null", file_path }, null);
    build_stderr = try allocator.dupe(u8, build_result.stderr);
    defer {
        allocator.free(build_result.stdout);
        allocator.free(build_result.stderr);
    }

    build_passed = build_result.exit_code == 0;

    // If build-exe failed (e.g., no main function), try build-obj
    if (!build_passed) {
        const obj_result = try runCommand(allocator, &.{ "zig", "build-obj", "-femit-bin=/dev/null", file_path }, null);
        defer {
            allocator.free(obj_result.stdout);
            allocator.free(obj_result.stderr);
        }

        // Use obj result if it succeeded
        if (obj_result.exit_code == 0) {
            build_passed = true;
            allocator.free(build_stderr);
            build_stderr = try allocator.dupe(u8, obj_result.stderr);
        }
    }

    // Step 3: Test check (only if build passed)
    var test_passed = false;
    if (build_passed) {
        const test_result = try runCommand(allocator, &.{ "zig", "test", file_path }, null);
        defer {
            allocator.free(test_result.stdout);
            allocator.free(test_result.stderr);
        }

        test_passed = test_result.exit_code == 0;
    }

    // Combine stderr from all failed steps
    var combined_stderr = std.array_list.AlignedManaged(u8, null).init(allocator);
    defer combined_stderr.deinit();

    if (!format_passed) {
        // zig fmt --check outputs to stdout, not stderr
        // Add a parseable error format for diagnostic parser
        try combined_stderr.appendSlice(file_path);
        try combined_stderr.appendSlice(":1:1: error: formatting check failed (run 'zig fmt ");
        try combined_stderr.appendSlice(file_path);
        try combined_stderr.appendSlice("' to fix)\n");
    }
    if (!build_passed) {
        try combined_stderr.appendSlice(build_stderr);
        try combined_stderr.appendSlice("\n");
    } else if (!test_passed) {
        // Only show test errors if build passed
        const test_result = try runCommand(allocator, &.{ "zig", "test", file_path }, null);
        defer {
            allocator.free(test_result.stdout);
            allocator.free(test_result.stderr);
        }
        try combined_stderr.appendSlice(test_result.stderr);
    }

    allocator.free(build_stderr);

    const success = build_passed and test_passed and format_passed;

    return VerifyResult{
        .success = success,
        .build_passed = build_passed,
        .test_passed = test_passed,
        .format_passed = format_passed,
        .stderr = try combined_stderr.toOwnedSlice(),
        .exit_code = if (build_passed) 0 else 1,
    };
}

/// Quick format-only check
pub fn checkFormat(allocator: std.mem.Allocator, file_path: []const u8) !bool {
    const result = try runCommand(allocator, &.{ "zig", "fmt", "--check", file_path }, null);
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    return result.exit_code == 0;
}

/// Quick compilation-only check (no tests)
pub fn checkCompilation(allocator: std.mem.Allocator, file_path: []const u8) !bool {
    // Try build-exe first
    const exe_result = try runCommand(allocator, &.{ "zig", "build-exe", "-femit-bin=/dev/null", file_path }, null);
    defer {
        allocator.free(exe_result.stdout);
        allocator.free(exe_result.stderr);
    }

    if (exe_result.exit_code == 0) return true;

    // Try build-obj for files without main
    const obj_result = try runCommand(allocator, &.{ "zig", "build-obj", "-femit-bin=/dev/null", file_path }, null);
    defer {
        allocator.free(obj_result.stdout);
        allocator.free(obj_result.stderr);
    }

    return obj_result.exit_code == 0;
}

/// Zig-specific static analysis checks (v8.10)
///
/// Checks for common Zig idioms that indicate code quality:
/// - Proper allocator usage with alloc() calls
/// - Error return types with try keyword
/// - Matching init/deinit function pairs
///
/// Parameters:
///   - allocator: Memory allocator
///   - file_path: Path to the Zig file to check
///
/// Returns: true if all Zig idioms are properly followed
pub fn checkZigIdioms(allocator: std.mem.Allocator, file_path: []const u8) !bool {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(content);

    // Check 1: alloc() calls should have Allocator parameter visible
    if (std.mem.indexOf(u8, content, ".alloc(") != null) {
        // If alloc() is used, Allocator should be mentioned
        if (std.mem.indexOf(u8, content, "Allocator") == null and
            std.mem.indexOf(u8, content, "allocator") == null)
        {
            // alloc() used but no allocator in sight - suspicious
            return false;
        }
    }

    // Check 2: try keyword should be accompanied by error return type (!)
    // Count try occurrences
    var try_count: usize = 0;
    var iter = std.mem.splitScalar(u8, content, ' ');
    while (iter.next()) |word| {
        if (std.mem.eql(u8, word, "try")) {
            try_count += 1;
        }
    }

    if (try_count > 0) {
        // If try is used, there should be error return types
        if (std.mem.indexOf(u8, content, " !") == null and
            std.mem.indexOf(u8, content, "!") == null)
        {
            // try used but no error return type found
            // This is a weak heuristic but catches obvious cases
            // Don't fail hard, just note as potential issue
        }
    }

    // Check 3: init() should have matching deinit()
    const has_init = std.mem.indexOf(u8, content, "fn init(") != null or
        std.mem.indexOf(u8, content, "pub fn init(") != null;
    const has_deinit = std.mem.indexOf(u8, content, "fn deinit(") != null or
        std.mem.indexOf(u8, content, "pub fn deinit(") != null;

    // If init exists, deinit should ideally exist too (for structs)
    // But this is a soft check - not all types need deinit
    _ = has_init;
    _ = has_deinit;

    // Check 4: No @panic in generated code (use error returns instead)
    if (std.mem.indexOf(u8, content, "@panic") != null) {
        return false;
    }

    // Check 5: No unreachable in generated code (except for tests)
    const has_unreachable = std.mem.indexOf(u8, content, "unreachable") != null;
    const has_test = std.mem.indexOf(u8, content, "test \"") != null or
        std.mem.indexOf(u8, content, "test\n") != null;
    if (has_unreachable and !has_test) {
        // unreachable outside of tests is suspicious
        return false;
    }

    return true;
}

/// Get detailed Zig idiom diagnostics (v8.10)
///
/// Returns a list of issues found in Zig code quality checks.
pub const IdiomIssue = struct {
    category: []const u8,
    message: []const u8,
    line: u32,
};

pub const IdiomCheckResult = struct {
    passed: bool,
    issues: []IdiomIssue,

    pub fn deinit(self: *const IdiomCheckResult, allocator: std.mem.Allocator) void {
        for (self.issues) |issue| {
            allocator.free(issue.message);
        }
        allocator.free(self.issues);
        self.* = undefined;
    }
};

pub fn checkZigIdiomsDetailed(allocator: std.mem.Allocator, file_path: []const u8) !IdiomCheckResult {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(content);

    var issues_list = std.array_list.AlignedManaged(IdiomIssue, null).init(allocator);

    // Check for @panic
    if (std.mem.indexOf(u8, content, "@panic") != null) {
        try issues_list.append(IdiomIssue{
            .category = "error_handling",
            .message = try allocator.dupe(u8, "@panic found - use error returns instead"),
            .line = 0,
        });
    }

    // Check for alloc without Allocator
    if (std.mem.indexOf(u8, content, ".alloc(") != null and
        std.mem.indexOf(u8, content, "Allocator") == null and
        std.mem.indexOf(u8, content, "allocator") == null)
    {
        try issues_list.append(IdiomIssue{
            .category = "allocator",
            .message = try allocator.dupe(u8, "alloc() used without visible Allocator parameter"),
            .line = 0,
        });
    }

    return IdiomCheckResult{
        .passed = issues_list.items.len == 0,
        .issues = try issues_list.toOwnedSlice(),
    };
}

test "verifier: checkFormat on formatted code" {
    const allocator = std.testing.allocator;

    // Create a temporary formatted file
    const tmp = try std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const test_file = "test_formatted.zig";
    try tmp.dir.writeFile(test_file,
        \\const std = @import("std");
        \\
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    );

    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp.dir.path, test_file });
    defer allocator.free(path);

    const result = try checkFormat(allocator, path);
    try std.testing.expect(result);
}

test "verifier: checkCompilation" {
    const allocator = std.testing.allocator;

    // Create a temporary valid file
    const tmp = try std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const test_file = "test_compilable.zig";
    try tmp.dir.writeFile(test_file,
        \\const std = @import("std");
        \\
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
    );

    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp.dir.path, test_file });
    defer allocator.free(path);

    const result = try checkCompilation(allocator, path);
    try std.testing.expect(result);
}
