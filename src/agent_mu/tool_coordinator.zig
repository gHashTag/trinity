//! AGENT MU v8.25 - Tool Coordinator
//!
//! This module implements the TOOL phase in the AGENT MU Golden Chain:
//! V01 -> Phi02 -> Pi03 -> TOOL -> Mu05 -> Sigma07 -> Chi06
//!
//! The TOOL phase routes requests to appropriate sub-agents for:
//! - File reading (source code, configs, documentation)
//! - Command execution (zig build, zig test, git operations)
//! - Web search (error solutions, documentation)
//! - Code analysis (semantic understanding with pattern matching)

const std = @import("std");

const SacredConstants = struct {
    pub const PHI: f64 = 1.618033988749895;
    pub const PHI_SQ: f64 = 2.618033988749895;
    pub const MU: f64 = 1.0 / (PHI * PHI) / 10.0; // = 0.0382
    pub const CHI: f64 = 1.0 / (PHI * PHI * PHI); // = 0.23607
    pub const MIN_CONFIDENCE: f32 = 0.95;
    pub const MAX_COMMAND_TIMEOUT_MS: u64 = 30000;
    pub const MAX_FILE_SIZE_BYTES: usize = 1024 * 1024; // 1MB
};

pub const ToolType = enum {
    file_read,
    command_exec,
    web_search,
    git_op,
    code_analysis,

    pub fn toString(self: ToolType) []const u8 {
        return switch (self) {
            .file_read => "file_read",
            .command_exec => "command_exec",
            .web_search => "web_search",
            .git_op => "git_op",
            .code_analysis => "code_analysis",
        };
    }
};

pub const ToolRequest = struct {
    tool_type: ToolType,
    target: []const u8,
    parameters: std.StringHashMap([]const u8),
    confidence: f32,
    timestamp_ms: u64,

    pub fn init(allocator: std.mem.Allocator, tool_type: ToolType, target: []const u8, confidence: f32) !ToolRequest {
        return ToolRequest{
            .tool_type = tool_type,
            .target = try allocator.dupe(u8, target),
            .parameters = std.StringHashMap([]const u8).init(allocator),
            .confidence = confidence,
            .timestamp_ms = std.time.nanoTimestamp() / 1_000_000,
        };
    }

    pub fn deinit(self: *ToolRequest) void {
        self.target.deinit();
        var it = self.parameters.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.parameters.deinit();
    }
};

pub const ToolResponse = struct {
    success: bool,
    output: []const u8,
    err_msg: []const u8,
    execution_time_ms: u64,
    tool_type: ToolType,

    pub fn ok(allocator: std.mem.Allocator, output: []const u8, exec_time_ms: u64, tool_type: ToolType) !ToolResponse {
        return ToolResponse{
            .success = true,
            .output = try allocator.dupe(u8, output),
            .err_msg = "",
            .execution_time_ms = exec_time_ms,
            .tool_type = tool_type,
        };
    }

    pub fn fail(allocator: std.mem.Allocator, err_msg: []const u8, tool_type: ToolType) !ToolResponse {
        return ToolResponse{
            .success = false,
            .output = "",
            .err_msg = try allocator.dupe(u8, err_msg),
            .execution_time_ms = 0,
            .tool_type = tool_type,
        };
    }

    pub fn deinit(self: *ToolResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.output);
        allocator.free(self.err_msg);
    }
};

pub const ToolConfig = struct {
    min_confidence: f32 = SacredConstants.MIN_CONFIDENCE,
    max_command_timeout_ms: u64 = SacredConstants.MAX_COMMAND_TIMEOUT_MS,
    max_file_size_bytes: usize = SacredConstants.MAX_FILE_SIZE_BYTES,
    sacred_log_path: []const u8 = ".ralph/logs/sacred_tool_calls.log",
};

/// Main tool execution router with safety validation
pub fn executeTool(allocator: std.mem.Allocator, req: ToolRequest, config: ToolConfig) !ToolResponse {
    const start_time = std.time.nanoTimestamp();

    // Safety gate: confidence threshold
    if (req.confidence < config.min_confidence) {
        std.log.warn("Tool request rejected: confidence {d:.3} below threshold {d:.3}", .{ req.confidence, config.min_confidence });
        return ToolResponse.fail(allocator, "Confidence below threshold", req.tool_type);
    }

    // Route to appropriate handler
    const result = switch (req.tool_type) {
        .file_read => try readFile(allocator, req.target, config),
        .command_exec => try executeCommand(allocator, req.target, config),
        .git_op => try executeGitCommand(allocator, req.target, config),
        .code_analysis => try analyzeCode(allocator, req.target, req.parameters),
        .web_search => try webSearch(allocator, req.parameters.get("query")),
    };

    const elapsed_ms = @as(u64, @intCast((std.time.nanoTimestamp() - start_time) / 1_000_000));

    // Log to sacred log
    try writeToSacredLog(req, result, elapsed_ms);

    return result;
}

/// Safe file reading with path validation and size limits
fn readFile(allocator: std.mem.Allocator, path: []const u8, config: ToolConfig) !ToolResponse {
    const start_time = std.time.nanoTimestamp();

    // Path validation: must be within repository
    if (!isValidPath(path)) {
        return ToolResponse.fail(allocator, "Path outside repository or invalid", .file_read);
    }

    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "Cannot open file: {s}", .{@errorName(err)}), .file_read);
    };
    defer file.close();

    const stat = file.stat() catch |err| {
        return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "Cannot stat file: {s}", .{@errorName(err)}), .file_read);
    };

    // Size limit check
    if (stat.size > config.max_file_size_bytes) {
        return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "File too large: {d} bytes", .{stat.size}), .file_read);
    }

    const contents = file.readAllAlloc(allocator, config.max_file_size_bytes) catch |err| {
        return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "Cannot read file: {s}", .{@errorName(err)}), .file_read);
    };

    const elapsed_ms = @as(u64, @intCast((std.time.nanoTimestamp() - start_time) / 1_000_000));

    return ToolResponse{
        .success = true,
        .output = contents,
        .err_msg = "",
        .execution_time_ms = elapsed_ms,
        .tool_type = .file_read,
    };
}

/// Sandboxed command execution with resource limits
fn executeCommand(allocator: std.mem.Allocator, command: []const u8, _: ToolConfig) !ToolResponse {
    const start_time = std.time.nanoTimestamp();

    // Command validation: whitelist allowed commands
    if (!isSafeCommand(command)) {
        return ToolResponse.fail(allocator, "Command not in safe whitelist", .command_exec);
    }

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    const max_output_size: usize = 64 * 1024; // 64KB output limit

    const process = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", command },
        .max_output_bytes = max_output_size,
    }) catch |err| {
        return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "Command execution failed: {s}", .{@errorName(err)}), .command_exec);
    };

    defer {
        allocator.free(process.stdout);
        allocator.free(process.stderr);
    }

    const tc_exit = switch (process.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    };
    if (tc_exit != 0) {
        return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "Command failed (exit {d}): {s}", .{ tc_exit, process.stderr }), .command_exec);
    }

    const elapsed_ms = @as(u64, @intCast((std.time.nanoTimestamp() - start_time) / 1_000_000));

    return ToolResponse.ok(allocator, process.stdout, elapsed_ms, .command_exec);
}

/// Execute git commands safely
fn executeGitCommand(allocator: std.mem.Allocator, command: []const u8, config: ToolConfig) !ToolResponse {
    // Git command validation
    if (!std.mem.startsWith(u8, command, "git ")) {
        return ToolResponse.fail(allocator, "Not a git command", .git_op);
    }

    // Disallow destructive git commands
    const destructive = [_][]const u8{
        "git push --force",
        "git reset --hard",
        "git clean -fd",
        "git branch -D",
    };

    for (destructive) |forbidden| {
        if (std.mem.indexOf(u8, command, forbidden) != null) {
            return ToolResponse.fail(allocator, try std.fmt.allocPrint(allocator, "Destructive git command blocked: {s}", .{forbidden}), .git_op);
        }
    }

    return executeCommand(allocator, command, config);
}

/// Web search for error solutions and documentation
fn webSearch(allocator: std.mem.Allocator, query: ?[]const u8) !ToolResponse {
    if (query == null or query.?.len == 0) {
        return ToolResponse.fail(allocator, "Empty search query", .web_search);
    }

    // For now, return a placeholder
    // In production, this would integrate with MCP WebSearch tool
    const output = try std.fmt.allocPrint(allocator, "Web search for: {s}\n\n(Web search via MCP tool integration pending v8.26)", .{query.?});

    return ToolResponse.ok(allocator, output, 0, .web_search);
}

/// Code analysis using pattern matching
fn analyzeCode(allocator: std.mem.Allocator, file_path: []const u8, params: std.StringHashMap([]const u8)) !ToolResponse {
    const error_context = params.get("error_context") orelse "";

    // Read file first
    const config = ToolConfig{};
    const file_result = try readFile(allocator, file_path, config);

    if (!file_result.success) {
        return file_result;
    }

    defer allocator.free(file_result.output);

    // Simple pattern analysis (would use REGRESSION_PATTERNS.md in production)
    const analysis = try std.fmt.allocPrint(allocator, "Code analysis for: {s}\nError context: {s}\n\nFile size: {d} bytes\n\n(Pattern matching via REGRESSION_PATTERNS.md pending v8.26)", .{ file_path, error_context, file_result.output.len });

    return ToolResponse.ok(allocator, analysis, 0, .code_analysis);
}

/// Path validation: ensure path is within repository
fn isValidPath(path: []const u8) bool {
    // Reject absolute paths outside /Users/playra/trinity
    if (std.mem.startsWith(u8, path, "/") and
        !std.mem.startsWith(u8, path, "/Users/playra/trinity"))
    {
        return false;
    }

    // Reject parent directory traversal
    if (std.mem.indexOf(u8, path, "..") != null) {
        return false;
    }

    return true;
}

/// Command whitelist for safe execution
fn isSafeCommand(command: []const u8) bool {
    const safe_prefixes = [_][]const u8{
        "echo ",
        "zig build",
        "zig test",
        "zig fmt",
        "ls ",
        "pwd",
        "cat ",
        "head ",
        "tail ",
        "wc ",
        "grep ",
        "git status",
        "git diff",
        "git log",
        "git show",
        "git branch",
    };

    // Block sensitive system paths
    const blocked_paths = [_][]const u8{
        "/etc/",
        "/proc/",
        "/sys/",
        "/root/",
        "/home/",
        "/var/",
        "~/",
    };

    for (blocked_paths) |path| {
        if (std.mem.indexOf(u8, command, path) != null) {
            return false;
        }
    }

    for (safe_prefixes) |prefix| {
        if (std.mem.startsWith(u8, command, prefix)) {
            return true;
        }
    }

    return false;
}

/// Write tool call to sacred log
fn writeToSacredLog(req: ToolRequest, resp: ToolResponse, elapsed_ms: u64) !void {
    const log_path = ".ralph/logs/sacred_tool_calls.log";

    // Ensure log file exists
    _ = std.fs.cwd().openFile(log_path, .{ .mode = .write }) catch |err| {
        if (err == error.FileNotFound) {
            // Create log file with header
            const file = try std.fs.cwd().createFile(log_path, .{});
            try file.writeAll("# SACRED TOOL CALLS LOG - AGENT MU v8.25\n");
            try file.writeAll("# Format: timestamp | tool_type | target | success | duration_ms\n");
            try file.writeAll("# φ = 1.618033988749895 | μ = 0.0382\n\n");
            file.close();
        } else {
            std.log.err("Cannot open sacred log: {s}", .{@errorName(err)});
            return;
        }
    };

    const timestamp = req.timestamp_ms;
    const tool_name = req.tool_type.toString();
    const status = if (resp.success) "OK" else "FAIL";

    const entry = std.fmt.allocPrint(std.heap.page_allocator, "{d} | {s} | {s} | {s} | {d}ms\n", .{ timestamp, tool_name, req.target, status, elapsed_ms }) catch return;

    const file = try std.fs.cwd().openFile(log_path, .{ .mode = .write });
    defer file.close();

    try file.seekFromEnd(0);
    try file.writeAll(entry);
}

/// Sub-agent task specification
pub const SubAgentTask = struct {
    agent_type: []const u8,
    task_description: []const u8,
    timeout_ms: u64 = 10000,
    retry_count: u32 = 3,

    pub fn spawnAndExecute(allocator: std.mem.Allocator, task: SubAgentTask) !ToolResponse {
        _ = task;
        // Placeholder for MCP agent spawn integration
        // Will be implemented in v8.26 with full MCP tool support
        return ToolResponse.fail(allocator, "Sub-agent spawn pending MCP integration (v8.26)", .code_analysis);
    }
};

test "ToolType toString" {
    try std.testing.expectEqualSlices(u8, "file_read", ToolType.file_read.toString());
    try std.testing.expectEqualSlices(u8, "command_exec", ToolType.command_exec.toString());
}

test "isValidPath - valid paths" {
    try std.testing.expect(isValidPath("src/main.zig"));
    try std.testing.expect(isValidPath("CLAUDE.md"));
    try std.testing.expect(isValidPath("/Users/playra/trinity/src/vsa.zig"));
}

test "isValidPath - invalid paths" {
    try std.testing.expect(!isValidPath("/etc/passwd"));
    try std.testing.expect(!isValidPath("../secret.txt"));
    try std.testing.expect(!isValidPath("/tmp/test"));
}

test "isSafeCommand" {
    try std.testing.expect(isSafeCommand("echo 'test'"));
    try std.testing.expect(isSafeCommand("zig build"));
    try std.testing.expect(isSafeCommand("git status"));
    try std.testing.expect(!isSafeCommand("rm -rf /"));
    try std.testing.expect(!isSafeCommand("cat /etc/passwd"));
}
