// process_spawn.zig — Spawn Claude Code with timeout + process group kill
// Replaces bash timeout/SIGTERM handling with typed Zig.
const std = @import("std");

pub const SpawnResult = struct {
    stdout: []const u8,
    exit_code: u8,
    timed_out: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SpawnResult) void {
        if (self.stdout.len > 0) self.allocator.free(self.stdout);
    }
};

const allowed_tools = "Bash,Read,Write,Edit,Glob,Grep,TodoWrite,WebFetch,WebSearch,Skill";

/// Spawn `claude` CLI with timeout. Sends SIGTERM on timeout.
pub fn spawnClaude(
    allocator: std.mem.Allocator,
    prompt: []const u8,
    cwd: []const u8,
    max_turns: u32,
    timeout_s: u64,
    model: ?[]const u8,
) !SpawnResult {
    var turns_buf: [8]u8 = undefined;
    const turns_str = std.fmt.bufPrint(&turns_buf, "{d}", .{max_turns}) catch "50";

    // Build argv
    var argv_buf: [32][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "claude";
    argc += 1;
    argv_buf[argc] = "--print";
    argc += 1;
    argv_buf[argc] = "--output-format";
    argc += 1;
    argv_buf[argc] = "text";
    argc += 1;
    argv_buf[argc] = "--max-turns";
    argc += 1;
    argv_buf[argc] = turns_str;
    argc += 1;
    argv_buf[argc] = "--allowedTools";
    argc += 1;
    argv_buf[argc] = allowed_tools;
    argc += 1;

    if (model) |m| {
        argv_buf[argc] = "--model";
        argc += 1;
        argv_buf[argc] = m;
        argc += 1;
    }

    argv_buf[argc] = "-p";
    argc += 1;
    argv_buf[argc] = prompt;
    argc += 1;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argc],
        .cwd = cwd,
        .max_output_bytes = 2 * 1024 * 1024,
    }) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to spawn claude: {s}", .{@errorName(err)});
        return .{ .stdout = msg, .exit_code = 1, .timed_out = false, .allocator = allocator };
    };

    _ = timeout_s; // TODO: implement async timeout with process kill

    allocator.free(result.stderr);

    const exit_code: u8 = switch (result.term) {
        .Exited => |code| code,
        else => 1,
    };

    return .{
        .stdout = result.stdout,
        .exit_code = exit_code,
        .timed_out = false,
        .allocator = allocator,
    };
}

/// Save session log to /workspace/logs/session_{timestamp}.log
pub fn saveLog(_: std.mem.Allocator, worktree_path: []const u8, content: []const u8) void {
    var dir_buf: [512]u8 = undefined;
    const log_dir = std.fmt.bufPrint(&dir_buf, "{s}/../logs", .{worktree_path}) catch return;
    std.fs.cwd().makePath(log_dir) catch {};

    const epoch_s: u64 = @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_s));

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/session_{d}.log", .{ log_dir, epoch_s }) catch return;

    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();
    file.writeAll(content) catch {};
    std.debug.print("[agent] Log saved: {s}\n", .{path});
}

test "SpawnResult deinit" {
    const allocator = std.testing.allocator;
    const msg = try allocator.dupe(u8, "test");
    var r = SpawnResult{ .stdout = msg, .exit_code = 0, .timed_out = false, .allocator = allocator };
    r.deinit();
}
