// claude_runner.zig — Spawn Claude Code CLI as child process
// Supports --continue for native session resume (replaces HANDOVER.md)
const std = @import("std");

pub const RunResult = struct {
    stdout: []const u8,
    exit_code: u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *RunResult) void {
        self.allocator.free(self.stdout);
    }
};

const allowed_tools = "Bash,Read,Write,Edit,Glob,Grep,TodoWrite,WebFetch,WebSearch,Skill,mcp__telegram__SEND_MESSAGE";

/// Spawn `claude` CLI. If use_continue=true, uses --continue for session resume.
/// Otherwise, passes prompt via -p flag for a fresh session.
/// Hooks handle per-tool Telegram reporting — no stdout parsing needed.
pub fn spawn(
    allocator: std.mem.Allocator,
    prompt: []const u8,
    project_root: []const u8,
    max_turns: u32,
    use_continue: bool,
) !RunResult {
    var turns_buf: [8]u8 = undefined;
    const turns_str = std.fmt.bufPrint(&turns_buf, "{d}", .{max_turns}) catch "50";

    // Build argv based on resume mode
    // Wrap with `env AGENT_NAME=ralph` so any `tri` calls from Claude inherit the agent identity
    const result = if (use_continue) blk: {
        break :blk std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{
                "env",
                "AGENT_NAME=ralph",
                "claude",
                "--continue",
                "--print",
                "--output-format",
                "text",
                "--max-turns",
                turns_str,
                "--allowedTools",
                allowed_tools,
                "-p",
                prompt,
            },
            .cwd = project_root,
            .max_output_bytes = 1024 * 1024,
        }) catch |err| {
            const msg = try std.fmt.allocPrint(allocator, "Failed to spawn claude --continue: {s}", .{@errorName(err)});
            return RunResult{ .stdout = msg, .exit_code = 1, .allocator = allocator };
        };
    } else blk: {
        break :blk std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{
                "env",
                "AGENT_NAME=ralph",
                "claude",
                "--print",
                "--output-format",
                "text",
                "--max-turns",
                turns_str,
                "--allowedTools",
                allowed_tools,
                "-p",
                prompt,
            },
            .cwd = project_root,
            .max_output_bytes = 1024 * 1024,
        }) catch |err| {
            const msg = try std.fmt.allocPrint(allocator, "Failed to spawn claude: {s}", .{@errorName(err)});
            return RunResult{ .stdout = msg, .exit_code = 1, .allocator = allocator };
        };
    };

    // Free stderr, keep stdout
    allocator.free(result.stderr);

    const exit_code: u8 = switch (result.term) {
        .Exited => |code| code,
        else => 1,
    };

    return RunResult{
        .stdout = result.stdout,
        .exit_code = exit_code,
        .allocator = allocator,
    };
}

/// Save session log to .ralph/logs/session_{timestamp}.log
pub fn saveLog(_: std.mem.Allocator, project_root: []const u8, content: []const u8) void {
    var dir_buf: [512]u8 = undefined;
    const log_dir = std.fmt.bufPrint(&dir_buf, "{s}/.ralph/logs", .{project_root}) catch return;
    std.fs.cwd().makePath(log_dir) catch {};

    const epoch_s: u64 = @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_s));

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/session_{d}.log", .{ log_dir, epoch_s }) catch return;

    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();
    file.writeAll(content) catch {};

    std.debug.print("[ralph-agent] Log saved: {s}\n", .{path});
}

test "RunResult deinit does not crash" {
    const allocator = std.testing.allocator;
    const msg = try allocator.dupe(u8, "test output");
    var r = RunResult{ .stdout = msg, .exit_code = 0, .allocator = allocator };
    r.deinit();
}
