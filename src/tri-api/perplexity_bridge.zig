// perplexity_bridge.zig — HTTP GET endpoint server for Perplexity AI integration
// Enables Perplexity to query/control Trinity agent via get_full_page_content.
// Issue #101: feat(api): Perplexity Bridge
// Uses raw TCP — minimal HTTP parsing without std.http.Server complexity.
const std = @import("std");

const max_output = 64 * 1024;

pub const Bridge = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    port: u16,

    pub fn init(allocator: std.mem.Allocator) ?Bridge {
        const token = std.process.getEnvVarOwned(allocator, "PX_BRIDGE_TOKEN") catch {
            std.debug.print("[px-bridge] error: PX_BRIDGE_TOKEN not set\n", .{});
            return null;
        };
        const port_str = std.process.getEnvVarOwned(allocator, "PX_BRIDGE_PORT") catch null;
        defer if (port_str) |p| allocator.free(p);
        const port: u16 = if (port_str) |p| std.fmt.parseInt(u16, p, 10) catch 8077 else 8077;

        return .{ .allocator = allocator, .token = token, .port = port };
    }

    pub fn deinit(self: *Bridge) void {
        self.allocator.free(self.token);
    }

    pub fn serve(self: *Bridge) !void {
        const address = std.net.Address.parseIp4("0.0.0.0", self.port) catch unreachable;
        var server = try address.listen(.{ .reuse_address = true });
        defer server.deinit();

        std.debug.print("[px-bridge] listening on 0.0.0.0:{d}\n", .{self.port});
        std.debug.print("[px-bridge] routes: /px/status /px/exec /px/issues /px/log\n", .{});

        while (true) {
            const conn = server.accept() catch continue;
            defer conn.stream.close();
            self.handleRequest(conn.stream) catch |err| {
                std.debug.print("[px-bridge] request error: {s}\n", .{@errorName(err)});
            };
        }
    }

    fn handleRequest(self: *Bridge, stream: std.net.Stream) !void {
        // Read HTTP request (up to 4KB header)
        var buf: [4096]u8 = undefined;
        const n = stream.read(&buf) catch return;
        if (n == 0) return;
        const request = buf[0..n];

        // Parse first line: GET /path?query HTTP/1.1
        const line_end = std.mem.indexOf(u8, request, "\r\n") orelse return;
        const first_line = request[0..line_end];

        // Must be GET
        if (!std.mem.startsWith(u8, first_line, "GET ")) {
            try writeResponse(stream, "405", "{\"error\":\"GET only\"}");
            return;
        }

        // Extract path+query
        const path_start = 4; // after "GET "
        const path_end = std.mem.lastIndexOf(u8, first_line, " HTTP/") orelse return;
        const target = first_line[path_start..path_end];

        const q_pos = std.mem.indexOf(u8, target, "?");
        const path = target[0..(q_pos orelse target.len)];
        const query = if (q_pos) |p| target[p + 1 ..] else "";

        // Validate token
        const token_val = getQueryParam(query, "token");
        if (token_val == null or !std.mem.eql(u8, token_val.?, self.token)) {
            try writeResponse(stream, "403", "{\"error\":\"invalid token\"}");
            return;
        }

        std.debug.print("[px-bridge] {s}\n", .{path});

        // Route
        if (std.mem.eql(u8, path, "/px/status")) {
            try self.handleStatus(stream);
        } else if (std.mem.eql(u8, path, "/px/exec")) {
            const cmd = getQueryParam(query, "cmd") orelse "status";
            try self.handleExec(stream, cmd);
        } else if (std.mem.eql(u8, path, "/px/issues")) {
            try self.handleIssues(stream);
        } else if (std.mem.eql(u8, path, "/px/log")) {
            const n_str = getQueryParam(query, "n") orelse "50";
            const count = std.fmt.parseInt(u32, n_str, 10) catch 50;
            try self.handleLog(stream, count);
        } else {
            try writeResponse(stream, "404", "{\"error\":\"not found\",\"routes\":[\"/px/status\",\"/px/exec\",\"/px/issues\",\"/px/log\"]}");
        }
    }

    fn handleStatus(self: *Bridge, stream: std.net.Stream) !void {
        const compile = self.runCmd("PASS=$(grep -c '✅' specs/REGENERATION_REPORT.md 2>/dev/null || echo 0) && FAIL=$(grep -c '❌' specs/REGENERATION_REPORT.md 2>/dev/null || echo 0) && TOTAL=$((PASS+FAIL)) && RATE=$((TOTAL>0?PASS*100/TOTAL:0)) && echo $PASS/$TOTAL=$RATE%") catch "N/A";
        defer self.allocator.free(compile);

        const dirty = self.runCmd("git status --short | wc -l | tr -d ' '") catch "N/A";
        defer self.allocator.free(dirty);

        const branch = self.runCmd("git branch --show-current") catch "N/A";
        defer self.allocator.free(branch);

        const last_commit = self.runCmd("git log --oneline -1") catch "N/A";
        defer self.allocator.free(last_commit);

        const binaries = self.runCmd("ls zig-out/bin/ 2>/dev/null | wc -l | tr -d ' '") catch "0";
        defer self.allocator.free(binaries);

        const issues = self.runCmd("gh issue list --state open --json number --limit 100 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))' 2>/dev/null || echo N/A") catch "N/A";
        defer self.allocator.free(issues);

        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const w = resp.writer(self.allocator);
        try w.writeAll("{\"status\":\"ok\"");
        try w.writeAll(",\"compile\":\"");
        try writeJsonEscaped(w, std.mem.trim(u8, compile, &std.ascii.whitespace));
        try w.writeAll("\",\"branch\":\"");
        try writeJsonEscaped(w, std.mem.trim(u8, branch, &std.ascii.whitespace));
        try w.writeAll("\",\"dirty\":");
        try w.writeAll(std.mem.trim(u8, dirty, &std.ascii.whitespace));
        try w.writeAll(",\"binaries\":");
        try w.writeAll(std.mem.trim(u8, binaries, &std.ascii.whitespace));
        try w.writeAll(",\"open_issues\":");
        try w.writeAll(std.mem.trim(u8, issues, &std.ascii.whitespace));
        try w.writeAll(",\"last_commit\":\"");
        try writeJsonEscaped(w, std.mem.trim(u8, last_commit, &std.ascii.whitespace));
        try w.writeAll("\"}");

        try writeResponse(stream, "200", resp.items);
    }

    fn handleExec(self: *Bridge, stream: std.net.Stream, cmd: []const u8) !void {
        // Decode '+' as spaces
        const decoded = try self.allocator.alloc(u8, cmd.len);
        defer self.allocator.free(decoded);
        for (cmd, 0..) |c, i| {
            decoded[i] = if (c == '+') ' ' else c;
        }

        const shell_cmd = self.mapCommand(decoded) catch {
            try writeResponse(stream, "400", "{\"error\":\"unknown command\"}");
            return;
        };
        defer self.allocator.free(shell_cmd);

        const output = self.runCmd(shell_cmd) catch {
            try writeResponse(stream, "500", "{\"error\":\"exec failed\"}");
            return;
        };
        defer self.allocator.free(output);

        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const w = resp.writer(self.allocator);
        try w.writeAll("{\"cmd\":\"");
        try writeJsonEscaped(w, decoded);
        try w.writeAll("\",\"output\":\"");
        try writeJsonEscaped(w, std.mem.trim(u8, output, &std.ascii.whitespace));
        try w.writeAll("\"}");

        try writeResponse(stream, "200", resp.items);
    }

    fn handleIssues(self: *Bridge, stream: std.net.Stream) !void {
        const output = self.runCmd("gh issue list --state open --json number,title,labels --limit 20 2>/dev/null || echo '[]'") catch "[]";
        defer self.allocator.free(output);

        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const w = resp.writer(self.allocator);
        try w.writeAll("{\"issues\":");
        try w.writeAll(std.mem.trim(u8, output, &std.ascii.whitespace));
        try w.writeAll("}");

        try writeResponse(stream, "200", resp.items);
    }

    fn handleLog(self: *Bridge, stream: std.net.Stream, count: u32) !void {
        var cmd_buf: [128]u8 = undefined;
        const safe_n = @min(count, 100);
        const cmd = std.fmt.bufPrint(&cmd_buf, "git log --oneline -{d}", .{safe_n}) catch "git log --oneline -20";

        const output = self.runCmd(cmd) catch "error";
        defer self.allocator.free(output);

        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const w = resp.writer(self.allocator);
        try w.writeAll("{\"log\":\"");
        try writeJsonEscaped(w, std.mem.trim(u8, output, &std.ascii.whitespace));
        try w.writeAll("\"}");

        try writeResponse(stream, "200", resp.items);
    }

    /// Whitelist of safe commands. Returns shell command string.
    fn mapCommand(self: *Bridge, cmd: []const u8) ![]const u8 {
        const commands = .{
            .{ "diag", "zig build 2>&1; echo EXIT:$? && PASS=$(grep -c '✅' specs/REGENERATION_REPORT.md 2>/dev/null || echo 0) && FAIL=$(grep -c '❌' specs/REGENERATION_REPORT.md 2>/dev/null || echo 0) && echo COMPILE:$PASS/$((PASS+FAIL)) && git status --short | wc -l | xargs printf 'DIRTY:%d\\n'" },
            .{ "status", "git status --short && git log --oneline -3" },
            .{ "commit", "git add -A && git commit -m 'chore: auto-commit from px-bridge' 2>&1 || echo 'nothing to commit'" },
            .{ "build", "zig build 2>&1; echo EXIT:$?" },
            .{ "test", "zig build test 2>&1; echo EXIT:$?" },
            .{ "issues", "gh issue list --state open --json number,title --limit 20 2>/dev/null || echo '[]'" },
            .{ "push", "git push 2>&1" },
        };

        inline for (commands) |entry| {
            if (std.mem.eql(u8, cmd, entry[0])) {
                return try self.allocator.dupe(u8, entry[1]);
            }
        }

        // swarm run <N>
        if (std.mem.startsWith(u8, cmd, "swarm run ")) {
            const num = cmd["swarm run ".len..];
            _ = std.fmt.parseInt(u32, num, 10) catch return error.InvalidCommand;
            return try std.fmt.allocPrint(self.allocator, "./zig-out/bin/tri swarm run {s} 2>&1", .{num});
        }

        return error.InvalidCommand;
    }

    fn runCmd(self: *Bridge, cmd: []const u8) ![]const u8 {
        var child = std.process.Child.init(&.{ "/bin/sh", "-c", cmd }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        try child.spawn();

        const stdout = child.stdout orelse return error.NoStdout;
        const output = try stdout.readToEndAlloc(self.allocator, max_output);

        _ = try child.wait();
        return output;
    }
};

fn writeResponse(stream: std.net.Stream, status: []const u8, body: []const u8) !void {
    var header_buf: [512]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 {s} OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ status, body.len }) catch return;
    _ = stream.write(header) catch return;
    _ = stream.write(body) catch return;
}

fn getQueryParam(query: []const u8, name: []const u8) ?[]const u8 {
    var it = std.mem.splitScalar(u8, query, '&');
    while (it.next()) |param| {
        const eq = std.mem.indexOf(u8, param, "=") orelse continue;
        if (std.mem.eql(u8, param[0..eq], name)) {
            return param[eq + 1 ..];
        }
    }
    return null;
}

fn writeJsonEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}
