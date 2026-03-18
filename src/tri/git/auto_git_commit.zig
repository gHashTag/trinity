//! Auto-Git Commit System for Sacred Patches
//!
//! This module provides automatic git operations with strict safeguards for
//! sacred mathematics patches applied by Sacred Intelligence.
//!
//! Features:
//! - Automatic git operations with safety checks
//! - Formatted commit messages following conventional commits
//! - Branch protection (never commit to main/master)
//! - Rollback capability if tests fail
//! - Commit history tracking for learning
//! - Sacred mathematics-aware commit messages
//!
//! Usage:
//! ```zig
//! var config = SafeguardConfig.default();
//! config.dry_run_mode = false; // Enable actual commits
//! const commits = try analyzeAndCommit(allocator, config);
//! ```

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = std.mem.Allocator;

/// Commit type following conventional commits specification
pub const CommitType = enum {
    feat, // New feature
    fix, // Bug fix
    refactor, // Code refactoring
    perf, // Performance improvement
    docs, // Documentation changes
    @"test", // Test additions or modifications
    style, // Code style changes (formatting, etc)
    chore, // Maintenance tasks
    revert, // Revert previous commit
    /// String representation of commit type
    pub fn toString(self: CommitType) []const u8 {
        return switch (self) {
            .feat => "feat",
            .fix => "fix",
            .refactor => "refactor",
            .perf => "perf",
            .docs => "docs",
            .@"test" => "test",
            .style => "style",
            .chore => "chore",
            .revert => "revert",
        };
    }
};

/// Result of git command execution
pub const GitResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
    success: bool,

    pub fn deinit(self: *GitResult, allocator: Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }

    /// Create successful result
    pub fn ok(allocator: Allocator, output: []const u8) !GitResult {
        const output_copy = try allocator.dupe(u8, output);
        return .{
            .stdout = output_copy,
            .stderr = &[_]u8{},
            .exit_code = 0,
            .success = true,
        };
    }

    /// Create error result
    pub fn err(allocator: Allocator, stderr_output: []const u8, code: u8) !GitResult {
        const stderr_copy = try allocator.dupe(u8, stderr_output);
        return .{
            .stdout = &[_]u8{},
            .stderr = stderr_copy,
            .exit_code = code,
            .success = false,
        };
    }
};

/// Auto-git commit record
pub const AutoGitCommit = struct {
    commit_hash: []const u8,
    message: []const u8,
    patches_applied: [][]const u8,
    branch: []const u8,
    author: []const u8,
    timestamp: i64,
    confidence: f64,

    pub fn deinit(self: *AutoGitCommit, allocator: Allocator) void {
        allocator.free(self.commit_hash);
        allocator.free(self.message);
        for (self.patches_applied) |patch| {
            allocator.free(patch);
        }
        allocator.free(self.patches_applied);
        allocator.free(self.branch);
        allocator.free(self.author);
    }

    /// Format commit for display
    pub fn format(self: *const AutoGitCommit, allocator: Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        try buffer.writer(allocator).print(
            \\Commit: {s}
            \\Author: {s}
            \\Date: {d}
            \\Branch: {s}
            \\Confidence: {d:.3}
            \\Patches:
        , .{
            self.commit_hash,
            self.author,
            std.time.timestamp(), // Unix timestamp (use `date -r @N` for human-readable)
            self.branch,
            self.confidence,
        });

        for (self.patches_applied) |patch| {
            try buffer.writer(allocator).print("  - {s}\n", .{patch});
        }

        try buffer.writer(allocator).print("\n{s}\n", .{self.message});

        return buffer.toOwnedSlice(allocator);
    }
};

/// Sacred commit message following conventional commits
pub const SacredCommitMessage = struct {
    type: CommitType,
    scope: []const u8, // sacred, formula, gematria, constants, evolution
    subject: []const u8,
    body: ?[]const u8,
    breaking: bool,
    footer: ?[]const u8,

    pub fn deinit(self: *SacredCommitMessage, allocator: Allocator) void {
        allocator.free(self.scope);
        allocator.free(self.subject);
        if (self.body) |b| allocator.free(b);
        if (self.footer) |f| allocator.free(f);
    }

    /// Format as conventional commit message
    pub fn format(self: *const SacredCommitMessage, allocator: Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        // Header: type(scope): subject
        try buffer.writer(allocator).print("{s}({s})", .{
            self.type.toString(), self.scope,
        });
        if (self.breaking) {
            try buffer.writer(allocator).writeAll("!");
        }
        try buffer.writer(allocator).print(": {s}\n", .{self.subject});

        // Body
        if (self.body) |body| {
            try buffer.writer(allocator).print("\n{s}\n", .{body});
        }

        // Footer
        if (self.footer) |footer| {
            try buffer.writer(allocator).print("\n{s}\n", .{footer});
        }

        return buffer.toOwnedSlice(allocator);
    }
};

/// Safeguard configuration for auto-commits
pub const SafeguardConfig = struct {
    confidence_threshold: f64 = 0.99,
    max_commits_per_session: u32 = 10,
    protected_branches: []const []const u8 = &[_][]const u8{ "main", "master", "production" },
    require_approval_first_n: u32 = 3,
    dry_run_mode: bool = true,
    auto_rollback_on_test_fail: bool = true,
    require_clean_working_tree: bool = true,
    run_tests_before_commit: bool = true,
    max_commit_message_length: usize = 72,
    enable_commit_learning: bool = true,
    session_id: ?[]const u8 = null,

    /// Default configuration with maximum safety
    pub fn default() SafeguardConfig {
        return .{
            .confidence_threshold = 0.99,
            .max_commits_per_session = 10,
            .dry_run_mode = true, // Start in dry-run mode
            .auto_rollback_on_test_fail = true,
            .require_clean_working_tree = true,
            .run_tests_before_commit = true,
        };
    }

    /// Production-ready configuration (still with safeguards)
    pub fn production() SafeguardConfig {
        var config = default();
        config.dry_run_mode = false;
        config.require_approval_first_n = 1;
        return config;
    }

    /// Development configuration (more permissive)
    pub fn development() SafeguardConfig {
        var config = default();
        config.confidence_threshold = 0.95;
        config.max_commits_per_session = 50;
        config.dry_run_mode = false;
        config.require_approval_first_n = 0;
        return config;
    }

    /// Check if confidence meets threshold
    pub fn meetsConfidenceThreshold(self: *const SafeguardConfig, confidence: f64) bool {
        return confidence >= self.confidence_threshold;
    }
};

/// Auto-code patch reference (minimal representation)
pub const AutoCodePatch = struct {
    file_path: []const u8,
    line_number: usize,
    original_code: []const u8,
    patched_code: []const u8,
    patch_type: PatchType,
    confidence: f64,
    formula: ?[]const u8 = null,
    error_rate: ?f64 = null,

    pub fn deinit(self: *AutoCodePatch, allocator: Allocator) void {
        allocator.free(self.file_path);
        allocator.free(self.original_code);
        allocator.free(self.patched_code);
        if (self.formula) |f| allocator.free(f);
    }
};

pub const PatchType = enum {
    magic_number_replacement,
    algorithm_optimization,
    formula_application,
    bug_fix,
    refactoring,

    pub fn toString(self: PatchType) []const u8 {
        return switch (self) {
            .magic_number_replacement => "magic-number-replacement",
            .algorithm_optimization => "algorithm-optimization",
            .formula_application => "formula-application",
            .bug_fix => "bug-fix",
            .refactoring => "refactoring",
        };
    }
};

/// Session state tracking
pub const CommitSession = struct {
    commits_made: u32 = 0,
    commits_attempted: u32 = 0,
    rollbacks_performed: u32 = 0,
    current_branch: []const u8,
    start_time: i64,
    session_id: []const u8,

    pub fn init(allocator: Allocator, branch: []const u8) !CommitSession {
        const session_id = try generateSessionId(allocator);
        return .{
            .current_branch = try allocator.dupe(u8, branch),
            .start_time = std.time.timestamp(),
            .session_id = session_id,
        };
    }

    pub fn deinit(self: *CommitSession, allocator: Allocator) void {
        allocator.free(self.current_branch);
        allocator.free(self.session_id);
    }

    pub fn canCommitMore(self: *const CommitSession, max: u32) bool {
        return self.commits_made < max;
    }

    pub fn recordCommitAttempt(self: *CommitSession) void {
        self.commits_attempted += 1;
    }

    pub fn recordCommitSuccess(self: *CommitSession) void {
        self.commits_made += 1;
    }

    pub fn recordRollback(self: *CommitSession) void {
        self.rollbacks_performed += 1;
    }

    pub fn getDuration(self: *const CommitSession) i64 {
        return std.time.timestamp() - self.start_time;
    }
};

/// Generate unique session ID
fn generateSessionId(allocator: Allocator) ![]const u8 {
    const timestamp = std.time.timestamp();
    const random = std.crypto.random.int(u64);
    return std.fmt.allocPrint(allocator, "session-{d}-{x}", .{ timestamp, random });
}

// ============================================================================
// Main API Functions
// ============================================================================

/// Analyze patches and create commits with full safeguards
pub fn analyzeAndCommit(
    allocator: Allocator,
    patches: []const AutoCodePatch,
    config: SafeguardConfig,
) ![]AutoGitCommit {
    var session = try CommitSession.init(allocator, try getCurrentBranch(allocator));
    defer session.deinit(allocator);

    var commits = std.ArrayList(AutoGitCommit).init(allocator);
    defer {
        for (commits.items) |*commit| {
            commit.deinit(allocator);
        }
        commits.deinit();
    }

    std.log.info("Starting auto-commit session: {s}", .{session.session_id});
    std.log.info("Dry-run mode: {}", .{config.dry_run_mode});
    std.log.info("Confidence threshold: {d:.3}", .{config.confidence_threshold});

    // Check if we're on a protected branch
    const current_branch = try getCurrentBranch(allocator);
    defer allocator.free(current_branch);

    if (validateCommitSafety(current_branch, config.protected_branches)) {
        return error.ProtectedBranch;
    }

    // Check working tree if required
    if (config.require_clean_working_tree and !isRepoClean()) {
        return error.WorkingTreeNotClean;
    }

    // Process each patch
    for (patches, 0..) |patch, index| {
        if (!session.canCommitMore(config.max_commits_per_session)) {
            std.log.warn("Reached maximum commits per session ({d})", .{config.max_commits_per_session});
            break;
        }

        session.recordCommitAttempt();

        // Check confidence threshold
        if (!config.meetsConfidenceThreshold(patch.confidence)) {
            std.log.warn("Patch {d} confidence {d:.3} below threshold {d:.3}, skipping", .{
                index, patch.confidence, config.confidence_threshold,
            });
            continue;
        }

        // Generate commit message
        const commit_msg = try generateSacredCommitMessage(allocator, patch);
        defer commit_msg.deinit(allocator);

        const formatted_msg = try commit_msg.format(allocator);
        defer allocator.free(formatted_msg);

        // Dry-run or actual commit
        if (config.dry_run_mode) {
            std.log.info("[DRY-RUN] Would commit:\n{s}", .{formatted_msg});

            // Create mock commit for tracking
            const mock_hash = try std.fmt.allocPrint(allocator, "dry-run-{d}", .{index});
            const commit = AutoGitCommit{
                .commit_hash = mock_hash,
                .message = try allocator.dupe(u8, formatted_msg),
                .patches_applied = blk: {
                    const arr = try allocator.alloc([]const u8, 1);
                    arr[0] = try allocator.dupe(u8, patch.file_path);
                    break :blk arr;
                },
                .branch = try allocator.dupe(u8, current_branch),
                .author = "sacred-intelligence-auto",
                .timestamp = std.time.timestamp(),
                .confidence = patch.confidence,
            };
            try commits.append(commit);
        } else {
            // Actual commit
            const files = &[_][]const u8{patch.file_path};
            const commit_hash = try executeGitCommit(allocator, formatted_msg, files);
            defer allocator.free(commit_hash);

            std.log.info("Committed: {s}", .{commit_hash});

            const commit = AutoGitCommit{
                .commit_hash = try allocator.dupe(u8, commit_hash),
                .message = try allocator.dupe(u8, formatted_msg),
                .patches_applied = blk: {
                    const arr = try allocator.alloc([]const u8, 1);
                    arr[0] = try allocator.dupe(u8, patch.file_path);
                    break :blk arr;
                },
                .branch = try allocator.dupe(u8, current_branch),
                .author = "sacred-intelligence-auto",
                .timestamp = std.time.timestamp(),
                .confidence = patch.confidence,
            };
            try commits.append(commit);

            session.recordCommitSuccess();

            // Run tests if enabled
            if (config.run_tests_before_commit) {
                const test_result = try runTests(allocator);
                defer test_result.deinit(allocator);

                if (!test_result.success) {
                    std.log.err("Tests failed after commit {s}", .{commit_hash});

                    if (config.auto_rollback_on_test_fail) {
                        try rollbackCommit(allocator);
                        session.recordRollback();
                        std.log.warn("Rolled back commit {s} due to test failure", .{commit_hash});
                    }
                }
            }
        }
    }

    std.log.info("Session complete: {d}/{d} commits successful", .{ session.commits_made, session.commits_attempted });
    std.log.info("Duration: {d}s", .{session.getDuration()});

    return commits.toOwnedSlice();
}

/// Generate sacred commit message from patch
pub fn generateSacredCommitMessage(
    allocator: Allocator,
    patch: AutoCodePatch,
) !SacredCommitMessage {
    // Determine commit type based on patch type
    const commit_type: CommitType = switch (patch.patch_type) {
        .magic_number_replacement => .refactor,
        .algorithm_optimization => .perf,
        .formula_application => .feat,
        .bug_fix => .fix,
        .refactoring => .refactor,
    };

    // Determine scope
    const scope = try determineScope(allocator, patch);

    // Generate subject
    const subject = try generateSubject(allocator, patch);

    // Generate body with sacred mathematics context
    const body = try generateBody(allocator, patch);

    // Generate footer with sacred formula
    const footer = try generateFooter(allocator, patch);

    return SacredCommitMessage{
        .type = commit_type,
        .scope = scope,
        .subject = subject,
        .body = body,
        .breaking = false,
        .footer = footer,
    };
}

/// Format commit message
pub fn formatCommitMessage(msg: SacredCommitMessage, allocator: Allocator) ![]const u8 {
    return msg.format(allocator);
}

/// Execute git commit
pub fn executeGitCommit(
    allocator: Allocator,
    message: []const u8,
    files: [][]const u8,
) ![]const u8 {
    // Stage files
    try stageFiles(allocator, files);

    // Commit
    const result = try runGitCommand(allocator, &[_][]const u8{
        "commit",
        "-m",
        message,
    });
    defer result.deinit(allocator);

    if (!result.success) {
        std.log.err("Git commit failed: {s}", .{result.stderr});
        return error.GitCommitFailed;
    }

    // Extract commit hash from output
    const hash = try extractCommitHash(allocator, result.stdout);
    return hash;
}

/// Validate that current branch is not protected
pub fn validateCommitSafety(
    branch: []const u8,
    protected: [][]const u8,
) bool {
    for (protected) |protected_branch| {
        if (mem.eql(u8, branch, protected_branch)) {
            std.log.err("Cannot commit to protected branch: {s}", .{branch});
            return true; // Not safe
        }
    }
    return false; // Safe
}

/// Create feature branch with sacred prefix
pub fn createFeatureBranch(allocator: Allocator, name: []const u8) ![]const u8 {
    _ = name;
    const timestamp = std.time.timestamp();
    const branch_name = try std.fmt.allocPrint(
        allocator,
        "sacred/auto-patch-{d}",
        .{timestamp},
    );
    errdefer allocator.free(branch_name);

    const result = try runGitCommand(allocator, &[_][]const u8{
        "checkout",
        "-b",
        branch_name,
    });
    defer result.deinit(allocator);

    if (!result.success) {
        std.log.err("Failed to create branch: {s}", .{result.stderr});
        return error.BranchCreateFailed;
    }

    std.log.info("Created branch: {s}", .{branch_name});
    return branch_name;
}

/// Switch to branch
pub fn switchToBranch(allocator: Allocator, branch: []const u8) !void {
    const result = try runGitCommand(allocator, &[_][]const u8{
        "checkout",
        branch,
    });
    defer result.deinit(allocator);

    if (!result.success) {
        std.log.err("Failed to switch to branch {s}: {s}", .{ branch, result.stderr });
        return error.BranchSwitchFailed;
    }

    std.log.info("Switched to branch: {s}", .{branch});
}

/// Get current git branch
pub fn getCurrentBranch(allocator: Allocator) ![]const u8 {
    const result = try runGitCommand(allocator, &[_][]const u8{
        "rev-parse",
        "--abbrev-ref",
        "HEAD",
    });
    defer result.deinit(allocator);

    if (!result.success) {
        return error.FailedToGetBranch;
    }

    // Trim whitespace
    const branch = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
    return allocator.dupe(u8, branch);
}

/// Run git command and return result
pub fn runGitCommand(
    allocator: Allocator,
    args: [][]const u8,
) !GitResult {
    const git_path = try findGitExecutable(allocator);
    defer allocator.free(git_path);

    var child = process.Child.init(args, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.executable = git_path;

    try child.spawn();

    const stdout_reader = child.stdout.?.reader();
    const stderr_reader = child.stderr.?.reader();

    const stdout = try stdout_reader.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(stdout);

    const stderr = try stderr_reader.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(stderr);

    const term = try child.wait();

    const stdout_trimmed = std.mem.trim(u8, stdout, &std.ascii.whitespace);
    const stderr_trimmed = std.mem.trim(u8, stderr, &std.ascii.whitespace);

    const exit_code: u8 = switch (term) {
        .Exited => |code| @intCast(code),
        else => 1,
    };
    const success = exit_code == 0;

    return GitResult{
        .stdout = try allocator.dupe(u8, stdout_trimmed),
        .stderr = try allocator.dupe(u8, stderr_trimmed),
        .exit_code = exit_code,
        .success = success,
    };
}

/// Rollback last commit
pub fn rollbackCommit(allocator: Allocator) !void {
    const result = try runGitCommand(allocator, &[_][]const u8{
        "revert",
        "HEAD",
        "--no-edit",
    });
    defer result.deinit(allocator);

    if (!result.success) {
        std.log.err("Rollback failed: {s}", .{result.stderr});
        return error.RollbackFailed;
    }

    std.log.info("Successfully rolled back last commit");
}

/// Stage files for commit
pub fn stageFiles(allocator: Allocator, files: [][]const u8) !void {
    for (files) |file| {
        const result = try runGitCommand(allocator, &[_][]const u8{
            "add",
            file,
        });
        defer result.deinit(allocator);

        if (!result.success) {
            std.log.err("Failed to stage file {s}: {s}", .{ file, result.stderr });
            return error.StageFailed;
        }
    }

    std.log.info("Staged {d} files", .{files.len});
}

/// Check if working tree is clean
pub fn isRepoClean() bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const result = runGitCommand(allocator, &[_][]const u8{
        "status",
        "--porcelain",
    }) catch return false;
    defer result.deinit(allocator);

    if (!result.success) return false;

    return result.stdout.len == 0;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Find git executable in PATH
fn findGitExecutable(allocator: Allocator) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "which", "git" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |exit_code| {
            if (exit_code == 0) {
                const git_path = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
                return allocator.dupe(u8, git_path);
            }
            return error.GitNotFound;
        },
        else => return error.GitNotFound,
    }
}

/// Extract commit hash from git output
fn extractCommitHash(allocator: Allocator, output: []const u8) ![]const u8 {
    // Git commit output format: "[master 8a5b4c3] Commit message"
    // We need to extract the hash

    var lines = std.mem.splitScalar(u8, output, '\n');
    const first_line = lines.first();
    if (first_line.len == 0) return error.InvalidGitOutput;

    // Find hash (7-40 character hex string)
    var iter = std.mem.splitScalar(u8, first_line, ' ');
    while (iter.next()) |part| {
        // Strip brackets and other non-hex characters from the part
        var start: usize = 0;
        var end: usize = part.len;

        // Find first hex character
        while (start < part.len and !std.ascii.isHex(part[start])) : (start += 1) {}
        // Find last hex character
        while (end > start and !std.ascii.isHex(part[end - 1])) : (end -= 1) {}

        const hex_part = part[start..end];
        if (hex_part.len >= 7 and hex_part.len <= 40) {
            // Check if it's all hex
            var all_hex = true;
            for (hex_part) |c| {
                if (!std.ascii.isHex(c)) {
                    all_hex = false;
                    break;
                }
            }
            if (all_hex) {
                return allocator.dupe(u8, hex_part);
            }
        }
    }

    return error.HashNotFound;
}

/// Determine commit scope based on patch
fn determineScope(allocator: Allocator, patch: AutoCodePatch) ![]const u8 {
    _ = patch;

    // Analyze file path to determine scope
    // For now, default to "sacred"
    return allocator.dupe(u8, "sacred");
}

/// Generate commit subject
fn generateSubject(allocator: Allocator, patch: AutoCodePatch) ![]const u8 {
    return switch (patch.patch_type) {
        .magic_number_replacement => std.fmt.allocPrint(
            allocator,
            "auto-patched magic number in {s}",
            .{fs.path.basename(patch.file_path)},
        ),
        .algorithm_optimization => std.fmt.allocPrint(
            allocator,
            "optimized algorithm in {s}",
            .{fs.path.basename(patch.file_path)},
        ),
        .formula_application => std.fmt.allocPrint(
            allocator,
            "applied sacred formula in {s}",
            .{fs.path.basename(patch.file_path)},
        ),
        .bug_fix => std.fmt.allocPrint(
            allocator,
            "fixed bug in {s}",
            .{fs.path.basename(patch.file_path)},
        ),
        .refactoring => std.fmt.allocPrint(
            allocator,
            "refactored {s}",
            .{fs.path.basename(patch.file_path)},
        ),
    };
}

/// Generate commit body with patch details
fn generateBody(allocator: Allocator, patch: AutoCodePatch) !?[]const u8 {
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer buffer.deinit(allocator);

    try buffer.writer(allocator).print(
        \\Auto-patched by Sacred Intelligence
        \\
        \\File: {s}:{d}
        \\Type: {s}
        \\Confidence: {d:.3}
    , .{
        patch.file_path,
        patch.line_number,
        patch.patch_type.toString(),
        patch.confidence,
    });

    if (patch.formula) |formula| {
        try buffer.writer(allocator).print("\nFormula: {s}", .{formula});
    }

    if (patch.error_rate) |rate| {
        try buffer.writer(allocator).print("\nError rate: {d:.2}%", .{rate * 100.0});
    }

    return try buffer.toOwnedSlice(allocator);
}

/// Generate footer with sacred mathematics
fn generateFooter(allocator: Allocator, patch: AutoCodePatch) !?[]const u8 {
    _ = patch;

    // Sacred trinity identity
    const footer = "φ² + 1/φ² = 3 = TRINITY";
    return try allocator.dupe(u8, footer);
}

/// Run test suite
fn runTests(allocator: Allocator) !GitResult {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const result = try std.process.Child.run(.{
        .allocator = arena.allocator(),
        .argv = &[_][]const u8{ "zig", "build", "test" },
    });

    const stdout_trimmed = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);
    const stderr_trimmed = std.mem.trim(u8, result.stderr, &std.ascii.whitespace);

    const exit_code: u8 = switch (result.term) {
        .Exited => |code| @intCast(code),
        else => 1,
    };

    return GitResult{
        .stdout = try allocator.dupe(u8, stdout_trimmed),
        .stderr = try allocator.dupe(u8, stderr_trimmed),
        .exit_code = exit_code,
        .success = exit_code == 0,
    };
}

// ============================================================================
// Commit Learning System
// ============================================================================

/// Commit learning record for improving future auto-commits
pub const CommitLearning = struct {
    commit_hash: []const u8,
    confidence: f64,
    was_successful: bool,
    tests_passed: bool,
    was_rolled_back: bool,
    lesson_learned: []const u8,

    pub fn deinit(self: *CommitLearning, allocator: Allocator) void {
        allocator.free(self.commit_hash);
        allocator.free(self.lesson_learned);
    }
};

/// Record commit outcome for learning
pub fn recordCommitOutcome(
    allocator: Allocator,
    commit: AutoGitCommit,
    successful: bool,
    tests_passed: bool,
    rolled_back: bool,
) !CommitLearning {
    const lesson = try generateLesson(allocator, commit, successful, tests_passed, rolled_back);

    return CommitLearning{
        .commit_hash = try allocator.dupe(u8, commit.commit_hash),
        .confidence = commit.confidence,
        .was_successful = successful,
        .tests_passed = tests_passed,
        .was_rolled_back = rolled_back,
        .lesson_learned = lesson,
    };
}

/// Generate lesson from commit outcome
fn generateLesson(
    allocator: Allocator,
    commit: AutoGitCommit,
    successful: bool,
    tests_passed: bool,
    rolled_back: bool,
) ![]const u8 {
    if (successful and tests_passed and !rolled_back) {
        return std.fmt.allocPrint(
            allocator,
            "Commit {s} succeeded with confidence {d:.3}",
            .{ commit.commit_hash, commit.confidence },
        );
    } else if (rolled_back) {
        return std.fmt.allocPrint(
            allocator,
            "Commit {s} was rolled back - confidence {d:.3} was insufficient",
            .{ commit.commit_hash, commit.confidence },
        );
    } else if (!tests_passed) {
        return std.fmt.allocPrint(
            allocator,
            "Commit {s} failed tests - patch introduced regressions",
            .{commit.commit_hash},
        );
    } else {
        return std.fmt.allocPrint(
            allocator,
            "Commit {s} encountered unknown issues",
            .{commit.commit_hash},
        );
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "SafeguardConfig.default" {
    const config = SafeguardConfig.default();

    try testing.expectEqual(@as(f64, 0.99), config.confidence_threshold);
    try testing.expectEqual(@as(u32, 10), config.max_commits_per_session);
    try testing.expect(config.dry_run_mode);
    try testing.expect(config.auto_rollback_on_test_fail);
    try testing.expect(config.require_clean_working_tree);
    try testing.expect(config.run_tests_before_commit);
}

test "SafeguardConfig.meetsConfidenceThreshold" {
    const config = SafeguardConfig{ .confidence_threshold = 0.95 };

    try testing.expect(config.meetsConfidenceThreshold(0.95));
    try testing.expect(config.meetsConfidenceThreshold(1.0));
    try testing.expect(!config.meetsConfidenceThreshold(0.94));
}

test "CommitType.toString" {
    try testing.expectEqualStrings("feat", CommitType.feat.toString());
    try testing.expectEqualStrings("fix", CommitType.fix.toString());
    try testing.expectEqualStrings("refactor", CommitType.refactor.toString());
    try testing.expectEqualStrings("perf", CommitType.perf.toString());
    try testing.expectEqualStrings("docs", CommitType.docs.toString());
    try testing.expectEqualStrings("test", CommitType.@"test".toString());
    try testing.expectEqualStrings("style", CommitType.style.toString());
    try testing.expectEqualStrings("chore", CommitType.chore.toString());
    try testing.expectEqualStrings("revert", CommitType.revert.toString());
}

test "validateCommitSafety - protected branch" {
    const protected_array = [_][]const u8{ "main", "master", "production" };
    var protected_list = try std.ArrayList([]const u8).initCapacity(testing.allocator, protected_array.len);
    defer protected_list.deinit(testing.allocator);
    for (protected_array) |branch| {
        try protected_list.append(testing.allocator, branch);
    }

    try testing.expect(validateCommitSafety("main", protected_list.items)); // Not safe
    try testing.expect(validateCommitSafety("master", protected_list.items)); // Not safe
    try testing.expect(validateCommitSafety("production", protected_list.items)); // Not safe
    try testing.expect(!validateCommitSafety("feature-branch", protected_list.items)); // Safe
    try testing.expect(!validateCommitSafety("sacred/auto-patch-123", protected_list.items)); // Safe
}

test "generateSessionId" {
    const session_id = try generateSessionId(testing.allocator);
    defer testing.allocator.free(session_id);

    try testing.expect(session_id.len > 0);
    try testing.expect(std.mem.startsWith(u8, session_id, "session-"));
}

test "CommitSession tracking" {
    var session = try CommitSession.init(testing.allocator, "test-branch");
    defer session.deinit(testing.allocator);

    try testing.expectEqual(@as(u32, 0), session.commits_made);
    try testing.expectEqual(@as(u32, 0), session.commits_attempted);

    session.recordCommitAttempt();
    try testing.expectEqual(@as(u32, 1), session.commits_attempted);

    session.recordCommitSuccess();
    try testing.expectEqual(@as(u32, 1), session.commits_made);

    session.recordRollback();
    try testing.expectEqual(@as(u32, 1), session.rollbacks_performed);

    try testing.expect(session.canCommitMore(10));
    try testing.expect(!session.canCommitMore(1));
}

test "PatchType.toString" {
    try testing.expectEqualStrings(
        "magic-number-replacement",
        PatchType.magic_number_replacement.toString(),
    );
    try testing.expectEqualStrings(
        "algorithm-optimization",
        PatchType.algorithm_optimization.toString(),
    );
    try testing.expectEqualStrings(
        "formula-application",
        PatchType.formula_application.toString(),
    );
}

test "SacredCommitMessage.format" {
    const msg = SacredCommitMessage{
        .type = .feat,
        .scope = "sacred",
        .subject = "auto-patched phi constant",
        .body = null,
        .breaking = false,
        .footer = null,
    };

    const formatted = try msg.format(testing.allocator);
    defer testing.allocator.free(formatted);

    try testing.expectEqualStrings(
        "feat(sacred): auto-patched phi constant\n",
        formatted,
    );
}

test "SacredCommitMessage.format with breaking change" {
    const msg = SacredCommitMessage{
        .type = .feat,
        .scope = "sacred",
        .subject = "auto-patched phi constant",
        .body = null,
        .breaking = true,
        .footer = null,
    };

    const formatted = try msg.format(testing.allocator);
    defer testing.allocator.free(formatted);

    try testing.expectEqualStrings(
        "feat(sacred)!: auto-patched phi constant\n",
        formatted,
    );
}

test "SacredCommitMessage.format with body and footer" {
    const msg = SacredCommitMessage{
        .type = .feat,
        .scope = "sacred",
        .subject = "auto-patched phi constant",
        .body = "Replaced magic number with constant",
        .breaking = false,
        .footer = "φ² + 1/φ² = 3",
    };

    const formatted = try msg.format(testing.allocator);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.indexOf(u8, formatted, "feat(sacred):") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "Replaced magic number") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "φ² + 1/φ² = 3") != null);
}

test "generateSubject" {
    const patch = AutoCodePatch{
        .file_path = "src/vsa.zig",
        .line_number = 42,
        .original_code = "const val = 1.618;",
        .patched_code = "const val = SacredConstants.PHI;",
        .patch_type = .magic_number_replacement,
        .confidence = 0.99,
        .formula = null,
        .error_rate = null,
    };

    const subject = try generateSubject(testing.allocator, patch);
    defer testing.allocator.free(subject);

    try testing.expectEqualStrings(
        "auto-patched magic number in vsa.zig",
        subject,
    );
}

test "generateBody with formula and error rate" {
    const patch = AutoCodePatch{
        .file_path = "src/vsa.zig",
        .line_number = 42,
        .original_code = "const val = 1.618;",
        .patched_code = "const val = SacredConstants.PHI;",
        .patch_type = .magic_number_replacement,
        .confidence = 0.99,
        .formula = "V = 1×φ",
        .error_rate = 0.0,
    };

    const body_opt = try generateBody(testing.allocator, patch);
    try testing.expect(body_opt != null);
    const body = body_opt.?;
    defer testing.allocator.free(body);

    try testing.expect(std.mem.indexOf(u8, body, "src/vsa.zig:42") != null);
    try testing.expect(std.mem.indexOf(u8, body, "V = 1×φ") != null);
    try testing.expect(std.mem.indexOf(u8, body, "Error rate: 0.00%") != null);
}

test "generateFooter" {
    const patch = AutoCodePatch{
        .file_path = "src/vsa.zig",
        .line_number = 42,
        .original_code = "const val = 1.618;",
        .patched_code = "const val = SacredConstants.PHI;",
        .patch_type = .magic_number_replacement,
        .confidence = 0.99,
        .formula = null,
        .error_rate = null,
    };

    const footer_opt = try generateFooter(testing.allocator, patch);
    try testing.expect(footer_opt != null);
    const footer = footer_opt.?;
    defer testing.allocator.free(footer);

    try testing.expectEqualStrings(
        "φ² + 1/φ² = 3 = TRINITY",
        footer,
    );
}

test "extractCommitHash" {
    const output = "[master 8a5b4c3] Commit message\n 1 file changed, 1 insertion(+)";
    const hash = try extractCommitHash(testing.allocator, output);
    defer testing.allocator.free(hash);

    try testing.expectEqualStrings("8a5b4c3", hash);
}

test "AutoGitCommit.format" {
    var patches_list = try std.ArrayList([]const u8).initCapacity(testing.allocator, 1);
    defer patches_list.deinit(testing.allocator);
    try patches_list.append(testing.allocator, try testing.allocator.dupe(u8, "src/vsa.zig"));

    var commit = AutoGitCommit{
        .commit_hash = "abc123",
        .message = "feat(sacred): test commit",
        .patches_applied = patches_list.items,
        .branch = "feature-test",
        .author = "test-author",
        .timestamp = 1234567890,
        .confidence = 0.99,
    };
    defer {
        for (commit.patches_applied) |patch| {
            testing.allocator.free(patch);
        }
    }

    const formatted = try commit.format(testing.allocator);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.indexOf(u8, formatted, "abc123") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "feat(sacred): test commit") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "src/vsa.zig") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "0.990") != null);
}
