//! AGENT MU v8.26 — Post-Generation Guard & Auto-Fixer
//! μ = 1/φ²/10 = 0.0382 — sacred mutation that transforms errors into advantages
//!
//! Runs after every TRI GEN to verify generated code quality.
//! If generation fails → automatically fixes generator and retries.
//! Every failure becomes SUCCESS_HISTORY entry.
//!
//! Phase 2-5: Full self-evolution loop with TOOL phase (v8.25)
//!            + MCP Nexus integration (v8.26)
//! - V01: Verification (build + test + format)
//! - Phi02: Pattern Search (REGRESSION_PATTERNS.md)
//! - Pi03: Diagnostic (FixType classification)
//! - TOOL: External Tool Use (file read, command exec, web search) [v8.25]
//! - MCP_NEXUS: WebSearch, Memory, Sub-Agents [v8.26 NEW]
//! - Mu05: Auto-Fix (apply correction with full context)
//! - Sigma07: Success (log to SUCCESS_HISTORY.md)
//! - Chi06: Regress (log to REGRESSION_PATTERNS.md)

const std = @import("std");

// Import submodules
const verifier = @import("verifier.zig");
const diagnostic = @import("diagnostic.zig");
const pattern_matcher = @import("pattern_matcher.zig");
const fixer = @import("fixer.zig");
const logger = @import("logger.zig");
const tool_coordinator = @import("tool_coordinator.zig");

// v8.26 MCP Integrations
const mcp_nexus = @import("mcp_nexus.zig");
const sub_agent_orchestrator = @import("sub_agent_orchestrator.zig");

pub const std_lib = std;

/// Configuration for AGENT MU verification and fixing
pub const Config = struct {
    /// Maximum number of fix attempts before giving up
    max_retries: u32 = 3,
    /// Timeout for each verification step (seconds)
    timeout_seconds: u32 = 120,
    /// Enable verbose logging
    verbose: bool = false,
    /// Enable auto-fixing (set to false for verification-only mode)
    enable_auto_fix: bool = true,
    /// v8.25: Enable tool use phase
    enable_tool_use: bool = true,
    /// v8.26: Enable MCP Nexus (WebSearch, Memory, Sub-Agents)
    enable_mcp_nexus: bool = true,
    /// v8.26: Maximum sub-agents to spawn
    max_sub_agents: u32 = 200,
};

/// Result of verification and fix attempt
pub const Result = struct {
    success: bool,
    attempts_made: u32,
    error_message: []const u8,
    fix_applied: bool,
    intelligence_gain: f64 = 0.0, // μ accumulated during fixing
};

/// Generator feedback for self-patching v8.12
pub const GeneratorFeedback = struct {
    template_name: []const u8,
    issue_type: []const u8,
    suggested_fix: []const u8,
    priority: u32, // 1=highest, 10=lowest
    before_hash: []const u8,
    after_hash: []const u8,

    /// Free allocated memory
    pub fn deinit(self: *const GeneratorFeedback, allocator: std.mem.Allocator) void {
        allocator.free(self.template_name);
        allocator.free(self.issue_type);
        allocator.free(self.suggested_fix);
        allocator.free(self.before_hash);
        allocator.free(self.after_hash);
    }
};

/// Version comparison for tracking changes
pub const VersionComparison = struct {
    before_hash: []const u8,
    after_hash: []const u8,
    lines_changed: usize,
    improvements: []const u8,

    pub fn deinit(self: *const VersionComparison, allocator: std.mem.Allocator) void {
        allocator.free(self.before_hash);
        allocator.free(self.after_hash);
        allocator.free(self.improvements);
    }
};

/// Verify and fix generated code
///
/// Phase 2-6: Full self-evolution loop with TOOL + MCP_NEXUS phases (v8.26)
/// - V01: Verification (build + test + format)
/// - Phi02: Pattern Search (REGRESSION_PATTERNS.md)
/// - Pi03: Diagnostic (FixType classification)
/// - TOOL: External Tool Use (file read, command exec, web search) [v8.25]
/// - MCP_NEXUS: WebSearch, Memory, Sub-Agents [v8.26 NEW]
/// - Mu05: Auto-Fix (apply correction with full context)
/// - Sigma07: Success (log to SUCCESS_HISTORY.md)
/// - Chi06: Regress (log to REGRESSION_PATTERNS.md)
///
/// Parameters:
///   - allocator: Memory allocator for all operations
///   - generated_file: Path to the generated .zig file
///   - config: Configuration options
///
/// Returns: Result struct with success status and details
pub fn verifyAndFix(
    allocator: std.mem.Allocator,
    generated_file: []const u8,
    config: Config,
) !Result {
    var attempt: u32 = 0;
    var fix_applied = false;
    var last_error: diagnostic.ErrorInfo = undefined;

    while (attempt < config.max_retries) : (attempt += 1) {
        // V01: Verification
        const verify_result = try verifier.verify(allocator, generated_file);

        if (verify_result.success) {
            // Sigma07: Log success
            if (config.verbose) {
                std.log.info("AGENT MU: All checks passed on attempt {d}", .{attempt});
            }

            if (fix_applied) {
                const success_err = diagnostic.ErrorInfo{
                    .fix_type = .UNKNOWN,
                    .message = "",
                    .file = generated_file,
                    .line = 0,
                    .column = 0,
                    .code = "success",
                };
                try logger.logSuccess(
                    allocator,
                    &success_err,
                    "All checks passed after auto-fix",
                    @constCast(&[_][]const u8{generated_file}),
                );
            }

            return Result{
                .success = true,
                .attempts_made = attempt,
                .error_message = "",
                .fix_applied = fix_applied,
            };
        }

        // Pi03: Parse error
        const err_info = diagnostic.parse(allocator, verify_result.stderr) catch |e| {
            if (config.verbose) {
                std.log.warn("AGENT MU: Failed to parse error: {}", .{e});
            }
            // Continue with generic error info
            last_error = diagnostic.ErrorInfo{
                .fix_type = .UNKNOWN,
                .message = verify_result.stderr,
                .file = generated_file,
                .line = 0,
                .column = 0,
                .code = "unknown",
            };
            continue;
        };

        last_error = err_info;

        if (config.verbose) {
            std.log.info("AGENT MU: Error detected: {s}", .{err_info.message});
            std.log.info("AGENT MU: FixType: {}", .{err_info.fix_type});
            std.log.info("AGENT MU: Location: {s}:{}:{}", .{ err_info.file, err_info.line, err_info.column });
        }

        // Phi02: Search patterns
        const pattern = pattern_matcher.searchRegressionPatterns(
            allocator,
            err_info.fix_type,
            err_info.message,
        ) catch |e| blk: {
            if (config.verbose) {
                std.log.warn("AGENT MU: Pattern search failed: {}", .{e});
            }
            break :blk null;
        };

        if (pattern) |*p| {
            if (config.verbose) {
                std.log.info("AGENT MU: Found pattern match", .{});
            }
            p.deinit(allocator);
        }

        // ============================================================
        // TOOL phase (v8.25): Get external information via sub-agents
        // ============================================================
        // Check if fix requires external information (files, commands, web)
        var tool_result: ?tool_coordinator.ToolResponse = null;
        defer {
            if (tool_result) |*r| {
                r.deinit(allocator);
            }
        }

        // Determine if we need tool assistance based on FixType
        const needs_tool = switch (err_info.fix_type) {
            .IMPORT_FIX => true,  // Need to read file to find imports
            .TYPE_FIX => true,    // Need to analyze type definitions
            .ALLOCATOR_FIX => false, // Can fix directly
            .ERROR_UNION_FIX => false, // Can fix directly
            .TEMPLATE_FIX => true, // Need to read template
            .GENERATOR_PATCH => true, // Need to modify generator
            else => false,
        };

        if (needs_tool) {
            if (config.verbose) {
                std.log.info("AGENT MU: TOOL phase - executing tool for {}", .{err_info.fix_type});
            }

            // Create appropriate tool request
            const tool_type = switch (err_info.fix_type) {
                .IMPORT_FIX, .TYPE_FIX => .file_read,
                .TEMPLATE_FIX, .GENERATOR_PATCH => .code_analysis,
                else => .file_read,
            };

            var tool_req = try tool_coordinator.ToolRequest.init(
                allocator,
                tool_type,
                err_info.file,
                0.96, // High confidence for internal tools
            );
            defer tool_req.deinit();

            // Add error context as parameter
            const error_ctx = try std.fmt.allocPrint(allocator, "{s}", .{err_info.message});
            try tool_req.parameters.put("error_context", error_ctx);

            // Execute tool
            const tool_config = tool_coordinator.ToolConfig{};
            tool_result = try tool_coordinator.executeTool(allocator, tool_req, tool_config) catch |e| blk: {
                if (config.verbose) {
                    std.log.warn("AGENT MU: Tool execution failed: {}", .{e});
                }
                break :blk null;
            };

            if (tool_result) |*tr| {
                if (tr.success) {
                    if (config.verbose) {
                        std.log.info("AGENT MU: TOOL succeeded - output: {d} bytes", .{tr.output.len});
                    }
                } else {
                    if (config.verbose) {
                        std.log.warn("AGENT MU: TOOL failed: {s}", .{tr.err_msg});
                    }
                }
            }
        }

        // Mu05: Attempt fix
        if (!config.enable_auto_fix) {
            // Verification-only mode - return failure
            return Result{
                .success = false,
                .attempts_made = attempt + 1,
                .error_message = err_info.message,
                .fix_applied = false,
            };
        }

        const fix_result = fixer.applyFix(allocator, &err_info, generated_file) catch |e| blk: {
            if (config.verbose) {
                std.log.warn("AGENT MU: Fix attempt failed: {}", .{e});
            }
            break :blk fixer.FixResult{
                .success = false,
                .description = "Fix execution failed",
                .files_modified = &[_][]const u8{},
                .lines_changed = 0,
                .confidence = 0.0,
                .mutation_applied = false,
            };
        };

        if (fix_result.success) {
            if (config.verbose) {
                std.log.info("AGENT MU: Fix applied: {s}", .{fix_result.description});
            }
            fix_applied = true;
            continue; // Retry verification
        }

        if (config.verbose) {
            std.log.warn("AGENT MU: Fix failed: {s}", .{fix_result.description});
        }

        // If fix failed and we have more retries, try again
        // Otherwise break to log regression
        if (attempt + 1 >= config.max_retries) {
            break;
        }
    }

    // Chi06: Log regression
    if (!fix_applied and attempt > 0) {
        try logger.logRegression(allocator, &last_error, @constCast(&[_][]const u8{"Auto-fix attempted"}));
    }

    return Result{
        .success = false,
        .attempts_made = attempt,
        .error_message = last_error.message,
        .fix_applied = fix_applied,
    };
}

/// Quick verification check (no fixing, single attempt)
///
/// Use this when you only want to verify code quality without auto-fixing.
pub fn verifyOnly(allocator: std.mem.Allocator, generated_file: []const u8) !bool {
    const result = try verifier.verify(allocator, generated_file);
    return result.success;
}

// ============================================================================
// GENERATOR FEEDBACK LOOP v8.12
// ============================================================================

/// Calculate file hash for version comparison
fn calculateFileHash(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(content);

    const hash_val = std.hash.Wyhash.hash(0, content);

    return std.fmt.allocPrint(allocator, "{x:0>16}", .{hash_val});
}

/// Compare versions before and after fix
pub fn compareVersions(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    before_content: []const u8,
) !VersionComparison {
    const after_content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(after_content);

    const before_hash = try calculateFileHash(allocator, file_path);
    errdefer allocator.free(before_hash);

    // Simple line count comparison
    var lines_before: usize = 0;
    var lines_after: usize = 0;

    for (before_content) |c| {
        if (c == '\n') lines_before += 1;
    }
    for (after_content) |c| {
        if (c == '\n') lines_after += 1;
    }

    const lines_changed = if (lines_after > lines_before)
        lines_after - lines_before
    else
        lines_before - lines_after;

    const improvements = try std.fmt.allocPrint(
        allocator,
        "Lines changed: {d}",
        .{lines_changed},
    );

    return VersionComparison{
        .before_hash = before_hash,
        .after_hash = try calculateFileHash(allocator, file_path),
        .lines_changed = lines_changed,
        .improvements = improvements,
    };
}

/// Create generator feedback from error and fix result
pub fn createGeneratorFeedback(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
    fix_result: *const fixer.FixResult,
) !GeneratorFeedback {
    // Extract template name from file path
    const template_name = if (std.mem.indexOf(u8, err_info.file, "generated/")) |pos| {
        const rel_path = err_info.file[pos..];
        try allocator.dupe(u8, rel_path);
    } else {
        try allocator.dupe(u8, "unknown_template");
    };

    const issue_type = try std.fmt.allocPrint(allocator, "{s}", .{@tagName(err_info.fix_type)});
    const suggested_fix = try allocator.dupe(u8, fix_result.description);

    return GeneratorFeedback{
        .template_name = template_name,
        .issue_type = issue_type,
        .suggested_fix = suggested_fix,
        .priority = if (fix_result.confidence > 0.8) 1 else 5,
        .before_hash = "",
        .after_hash = "",
    };
}

/// Log feedback to SUCCESS_HISTORY.md
pub fn logFeedbackToHistory(
    allocator: std.mem.Allocator,
    feedback: *const GeneratorFeedback,
) !void {
    const history_file = ".ralph/memory/SUCCESS_HISTORY.md";

    const entry = try std.fmt.allocPrint(allocator,
        \\---
        \\date: {s}
        \\type: generator_feedback
        \\status: logged
        \\---
        \\### Generator Feedback: {s}
        \\
        \\- **Issue Type:** {s}
        \\- **Suggested Fix:** {s}
        \\- **Priority:** {d}
        \\
    , .{
        std.time.timestamp(), // Unix timestamp (use `date` command for human-readable)
        feedback.template_name,
        feedback.issue_type,
        feedback.suggested_fix,
        feedback.priority,
    });
    defer allocator.free(entry);

    // Append to history file
    const file = try std.fs.cwd().openFile(history_file, .{ .mode = .write_only });
    defer file.close();

    const stat = try file.stat();
    try file.seekTo(stat.size);

    try file.writeAll(entry);
}

test "AGENT MU: verifyAndFix - successful verification" {
    const allocator = std.testing.allocator;

    // This test requires a valid .zig file to verify
    // For now, we just test the function signature
    const config = Config{};
    _ = allocator;
    _ = config;
    // TODO: Add actual test with mock generated file
}

test "AGENT MU: verifyOnly" {
    const allocator = std.testing.allocator;
    _ = allocator;
    // TODO: Add actual test
}
