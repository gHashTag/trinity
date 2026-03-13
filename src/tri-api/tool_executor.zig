// tool_executor.zig — Execute tools (read_file, write_file, bash, grep, MCP) via std
// Self-contained: no cross-directory imports. Uses std.fs + std.process.Child only.
// Phase 6: Permission checks + git checkpoints before writes.
// Phase 7: MCP tool routing.
const std = @import("std");
const json = @import("tool_protocol.zig");
const permissions = @import("permissions.zig");
const checkpoint_mod = @import("checkpoint.zig");
const mcp_client = @import("mcp_client.zig");

pub const ToolName = enum {
    read_file,
    write_file,
    bash,
    grep,

    pub fn fromString(name: []const u8) ?ToolName {
        if (std.mem.eql(u8, name, "read_file")) return .read_file;
        if (std.mem.eql(u8, name, "write_file")) return .write_file;
        if (std.mem.eql(u8, name, "bash")) return .bash;
        if (std.mem.eql(u8, name, "grep")) return .grep;
        return null;
    }

    pub fn toString(self: ToolName) []const u8 {
        return switch (self) {
            .read_file => "read_file",
            .write_file => "write_file",
            .bash => "bash",
            .grep => "grep",
        };
    }
};

pub const ToolResult = struct {
    output: []const u8,
    is_error: bool,
};

pub const ToolExecutor = struct {
    allocator: std.mem.Allocator,
    perms: ?*const permissions.PermissionConfig = null,
    checkpoint: checkpoint_mod.Checkpoint = undefined,
    mcp: ?*mcp_client.McpManager = null,
    audit_file: ?std.fs.File = null,

    pub fn init(allocator: std.mem.Allocator, perms: ?*const permissions.PermissionConfig, mcp: ?*mcp_client.McpManager) ToolExecutor {
        // Open audit log (append-only JSONL)
        const audit_path = std.process.getEnvVarOwned(allocator, "AUDIT_LOG_PATH") catch null;
        const path = audit_path orelse blk: {
            // Default: ~/.tri-api/audit.jsonl
            const home = std.process.getEnvVarOwned(allocator, "HOME") catch null;
            if (home) |h| {
                defer allocator.free(h);
                const dir_path = std.fmt.allocPrint(allocator, "{s}/.tri-api", .{h}) catch break :blk null;
                defer allocator.free(dir_path);
                std.fs.makeDirAbsolute(dir_path) catch {};
                break :blk std.fmt.allocPrint(allocator, "{s}/.tri-api/audit.jsonl", .{h}) catch null;
            }
            break :blk null;
        };
        defer if (audit_path) |p| allocator.free(p);
        defer if (audit_path == null) if (path) |p| allocator.free(p);

        const audit = if (path) |p|
            std.fs.createFileAbsolute(p, .{ .truncate = false }) catch null
        else
            null;
        if (audit) |f| f.seekFromEnd(0) catch {};

        return .{
            .allocator = allocator,
            .perms = perms,
            .checkpoint = .{ .allocator = allocator },
            .mcp = mcp,
            .audit_file = audit,
        };
    }

    pub fn deinit(self: *ToolExecutor) void {
        if (self.audit_file) |f| f.close();
    }

    /// Append audit entry (tool name + result status, never file contents)
    fn auditLog(self: *ToolExecutor, tool: []const u8, arg: []const u8, ok: bool) void {
        const f = self.audit_file orelse return;
        const ts = std.time.timestamp();
        const status: []const u8 = if (ok) "ok" else "error";
        // Truncate arg to 200 chars to avoid logging secrets
        const safe_arg = arg[0..@min(arg.len, 200)];
        var buf: [512]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "{{\"ts\":{d},\"tool\":\"{s}\",\"arg\":\"{s}\",\"result\":\"{s}\"}}\n", .{
            ts, tool, safe_arg, status,
        }) catch return;
        _ = f.write(line) catch {};
    }

    /// Execute a tool by string name — routes to built-in or MCP.
    pub fn executeDynamic(self: *ToolExecutor, name: []const u8, input_json: []const u8) ToolResult {
        // Try built-in first
        if (ToolName.fromString(name)) |builtin| {
            return self.execute(builtin, input_json);
        }

        // Try MCP (tool names contain "." prefix like "server.tool")
        if (self.mcp) |m| {
            if (m.isMcpTool(name)) {
                // Permission check for MCP tools
                if (self.perms) |p| {
                    if (p.check(name, "") == .deny) {
                        std.debug.print("[tri-api] DENIED MCP: {s}\n", .{name});
                        return .{ .output = "Permission denied", .is_error = true };
                    }
                }
                if (m.callTool(name, input_json)) |result| {
                    return .{ .output = result, .is_error = false };
                }
                return .{ .output = "MCP tool call failed", .is_error = true };
            }
        }

        const msg = std.fmt.allocPrint(self.allocator, "unknown tool: {s}", .{name}) catch
            return .{ .output = "unknown tool", .is_error = true };
        return .{ .output = msg, .is_error = true };
    }

    pub fn execute(self: *ToolExecutor, name: ToolName, input_json: []const u8) ToolResult {
        // Permission check
        if (self.perms) |p| {
            const tool_str = name.toString();
            const arg = self.extractArg(name, input_json);
            if (p.check(tool_str, arg) == .deny) {
                const msg = std.fmt.allocPrint(self.allocator, "Permission denied: {s}({s})", .{ tool_str, arg }) catch
                    return .{ .output = "Permission denied", .is_error = true };
                std.debug.print("[tri-api] DENIED: {s}({s})\n", .{ tool_str, arg });
                return .{ .output = msg, .is_error = true };
            }
        }

        const audit_arg = self.extractArg(name, input_json);
        const result = switch (name) {
            .read_file => self.readFile(input_json),
            .write_file => self.writeFileWithCheckpoint(input_json),
            .bash => self.runBash(input_json),
            .grep => self.runGrep(input_json),
        };
        self.auditLog(name.toString(), audit_arg, !result.is_error);
        return result;
    }

    /// Extract the primary argument for permission checking.
    fn extractArg(self: *ToolExecutor, name: ToolName, input_json: []const u8) []const u8 {
        _ = self;
        return switch (name) {
            .read_file, .write_file => json.extractField(input_json, "path") orelse "",
            .bash => json.extractField(input_json, "command") orelse "",
            .grep => json.extractField(input_json, "pattern") orelse "",
        };
    }

    /// Write file with git checkpoint.
    fn writeFileWithCheckpoint(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const path = json.extractField(input_json, "path") orelse
            return .{ .output = "error: missing 'path' field", .is_error = true };

        // Create checkpoint before writing
        self.checkpoint.createBeforeWrite(path);

        return self.writeFile(input_json);
    }

    /// Reject paths containing traversal sequences
    fn isPathSafe(path: []const u8) bool {
        // Block .. traversal
        if (std.mem.indexOf(u8, path, "..") != null) return false;
        // Block null bytes
        if (std.mem.indexOfScalar(u8, path, 0) != null) return false;
        return true;
    }

    fn readFile(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const path = json.extractField(input_json, "path") orelse
            return .{ .output = "error: missing 'path' field", .is_error = true };

        if (!isPathSafe(path))
            return .{ .output = "error: path traversal blocked", .is_error = true };

        const file = std.fs.cwd().openFile(path, .{}) catch |err|
            return self.errResult("read_file: open failed: ", err);

        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 512 * 1024) catch |err|
            return self.errResult("read_file: read failed: ", err);

        return .{ .output = content, .is_error = false };
    }

    fn writeFile(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const path = json.extractField(input_json, "path") orelse
            return .{ .output = "error: missing 'path' field", .is_error = true };

        if (!isPathSafe(path))
            return .{ .output = "error: path traversal blocked", .is_error = true };

        const content = json.extractField(input_json, "content") orelse
            return .{ .output = "error: missing 'content' field", .is_error = true };

        // Unescape JSON string content (handle \n, \t, \\, \")
        const unescaped = json.unescapeString(self.allocator, content) catch
            return .{ .output = "error: unescape failed", .is_error = true };
        defer self.allocator.free(unescaped);

        const file = std.fs.cwd().createFile(path, .{}) catch |err|
            return self.errResult("write_file: create failed: ", err);
        defer file.close();

        file.writeAll(unescaped) catch |err|
            return self.errResult("write_file: write failed: ", err);

        const msg = std.fmt.allocPrint(self.allocator, "wrote {d} bytes to {s}", .{ unescaped.len, path }) catch
            return .{ .output = "wrote file", .is_error = false };
        return .{ .output = msg, .is_error = false };
    }

    /// Allowed command prefixes for bash tool
    const allowed_bash_cmds = [_][]const u8{
        "git ",  "git\x00", "zig ", "zig\x00", "cat ",    "ls ",    "grep ", "find ",
        "echo ", "mkdir ",  "rm ",  "tri ",    "docker ", "gh ",    "head ", "tail ",
        "wc ",   "pwd",     "date", "env",     "which ",  "file ",  "diff ", "sort ",
        "test ", "cd ",     "cp ",  "mv ",     "chmod ",  "touch ", "sed ",  "awk ",
    };

    fn isBashAllowed(command: []const u8) bool {
        const trimmed = std.mem.trimLeft(u8, command, &std.ascii.whitespace);
        for (allowed_bash_cmds) |prefix| {
            if (std.mem.startsWith(u8, trimmed, prefix)) return true;
        }
        // Also allow bare commands without args
        const bare_ok = [_][]const u8{ "pwd", "date", "env", "ls" };
        for (bare_ok) |cmd| {
            if (std.mem.eql(u8, trimmed, cmd)) return true;
        }
        return false;
    }

    fn runBash(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const command = json.extractField(input_json, "command") orelse
            return .{ .output = "error: missing 'command' field", .is_error = true };

        if (!isBashAllowed(command))
            return .{ .output = "error: command not in allowed list", .is_error = true };

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "sh", "-c", command },
            .max_output_bytes = 512 * 1024,
        }) catch |err| return self.errResult("bash: spawn failed: ", err);

        defer self.allocator.free(result.stderr);

        // If non-zero exit, combine stderr + stdout
        const exit_code = switch (result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };
        if (exit_code != 0) {
            defer self.allocator.free(result.stdout);
            const combined = std.fmt.allocPrint(
                self.allocator,
                "exit code {d}\n{s}{s}",
                .{ exit_code, result.stderr, result.stdout },
            ) catch return .{ .output = "bash: error", .is_error = true };
            return .{ .output = combined, .is_error = true };
        }

        return .{ .output = result.stdout, .is_error = false };
    }

    fn runGrep(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const pattern = json.extractField(input_json, "pattern") orelse
            return .{ .output = "error: missing 'pattern' field", .is_error = true };
        const path = json.extractField(input_json, "path") orelse ".";

        if (!isPathSafe(path))
            return .{ .output = "error: path traversal blocked", .is_error = true };

        // Use timeout to prevent ReDoS, limit to 1000 matches
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "timeout", "5", "grep", "-rn", "--max-count=1000", pattern, path },
            .max_output_bytes = 256 * 1024,
        }) catch |err| return self.errResult("grep: spawn failed: ", err);

        defer self.allocator.free(result.stderr);

        // grep returns exit 1 for "no matches" — not an error
        if (result.stdout.len == 0) {
            self.allocator.free(result.stdout);
            return .{ .output = "no matches found", .is_error = false };
        }

        return .{ .output = result.stdout, .is_error = false };
    }

    fn errResult(self: *ToolExecutor, prefix: []const u8, err: anyerror) ToolResult {
        const msg = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ prefix, @errorName(err) }) catch
            return .{ .output = prefix, .is_error = true };
        return .{ .output = msg, .is_error = true };
    }
};

test "ToolName.fromString" {
    try std.testing.expectEqual(ToolName.read_file, ToolName.fromString("read_file").?);
    try std.testing.expectEqual(ToolName.bash, ToolName.fromString("bash").?);
    try std.testing.expect(ToolName.fromString("unknown") == null);
}
