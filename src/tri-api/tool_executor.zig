// tool_executor.zig — Execute tools (read_file, write_file, bash, grep) via std
// Self-contained: no cross-directory imports. Uses std.fs + std.process.Child only.
const std = @import("std");
const json = @import("tool_protocol.zig");

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
};

pub const ToolResult = struct {
    output: []const u8,
    is_error: bool,
};

pub const ToolExecutor = struct {
    allocator: std.mem.Allocator,

    pub fn execute(self: *ToolExecutor, name: ToolName, input_json: []const u8) ToolResult {
        return switch (name) {
            .read_file => self.readFile(input_json),
            .write_file => self.writeFile(input_json),
            .bash => self.runBash(input_json),
            .grep => self.runGrep(input_json),
        };
    }

    fn readFile(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const path = json.extractField(input_json, "path") orelse
            return .{ .output = "error: missing 'path' field", .is_error = true };

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

    fn runBash(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const command = json.extractField(input_json, "command") orelse
            return .{ .output = "error: missing 'command' field", .is_error = true };

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "sh", "-c", command },
            .max_output_bytes = 512 * 1024,
        }) catch |err| return self.errResult("bash: spawn failed: ", err);

        defer self.allocator.free(result.stderr);

        // If non-zero exit, combine stderr + stdout
        if (result.term.Exited != 0) {
            defer self.allocator.free(result.stdout);
            const combined = std.fmt.allocPrint(
                self.allocator,
                "exit code {d}\n{s}{s}",
                .{ result.term.Exited, result.stderr, result.stdout },
            ) catch return .{ .output = "bash: error", .is_error = true };
            return .{ .output = combined, .is_error = true };
        }

        return .{ .output = result.stdout, .is_error = false };
    }

    fn runGrep(self: *ToolExecutor, input_json: []const u8) ToolResult {
        const pattern = json.extractField(input_json, "pattern") orelse
            return .{ .output = "error: missing 'pattern' field", .is_error = true };
        const path = json.extractField(input_json, "path") orelse ".";

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "grep", "-rn", pattern, path },
            .max_output_bytes = 512 * 1024,
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
