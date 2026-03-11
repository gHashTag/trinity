// perplexity_bridge.zig — HTTP endpoint server for Perplexity AI integration
// Issue #101: basic bridge, #102: Command Queue + Mac Bridge Agent
// Architecture: Railway (queue) ←→ Mac (executor) via HTTPS polling
// Uses raw TCP — minimal HTTP parsing without std.http.Server complexity.
const std = @import("std");

const max_output = 64 * 1024;
const max_body = 128 * 1024; // POST body limit for /px/done
const job_ttl_secs: i64 = 3600; // 1 hour TTL for jobs

pub const Bridge = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    port: u16,
    queue_dir: []const u8,
    job_counter: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) ?Bridge {
        const token = std.process.getEnvVarOwned(allocator, "PX_BRIDGE_TOKEN") catch {
            std.debug.print("[px-bridge] error: PX_BRIDGE_TOKEN not set\n", .{});
            return null;
        };
        const port_str = std.process.getEnvVarOwned(allocator, "PX_BRIDGE_PORT") catch
            std.process.getEnvVarOwned(allocator, "PORT") catch null;
        defer if (port_str) |p| allocator.free(p);
        const port: u16 = if (port_str) |p| std.fmt.parseInt(u16, p, 10) catch 8077 else 8077;

        // Queue dir: PX_QUEUE_DIR > /data/queue > ./px-queue
        const queue_dir = std.process.getEnvVarOwned(allocator, "PX_QUEUE_DIR") catch blk: {
            // Check if /data exists (Railway volume)
            std.fs.accessAbsolute("/data", .{}) catch break :blk allocator.dupe(u8, "./px-queue") catch return null;
            break :blk allocator.dupe(u8, "/data/queue") catch return null;
        };

        return .{ .allocator = allocator, .token = token, .port = port, .queue_dir = queue_dir };
    }

    pub fn deinit(self: *Bridge) void {
        self.allocator.free(self.token);
        self.allocator.free(self.queue_dir);
    }

    fn ensureQueueDir(self: *Bridge) void {
        if (self.queue_dir[0] == '/') {
            std.fs.makeDirAbsolute(self.queue_dir) catch |err| {
                std.log.debug("perplexity_bridge: failed to create queue dir (abs): {}", .{err});
            };
        } else {
            std.fs.cwd().makePath(self.queue_dir) catch |err| {
                std.log.debug("perplexity_bridge: failed to create queue dir (rel): {}", .{err});
            };
        }
    }

    pub fn serve(self: *Bridge) !void {
        self.ensureQueueDir();

        const address = std.net.Address.parseIp4("0.0.0.0", self.port) catch |err| {
            std.log.err("perplexity_bridge: failed to parse address: {}", .{err});
            return error.SocketError;
        };
        var server = try address.listen(.{ .reuse_address = true });
        defer server.deinit();

        std.debug.print("[px-bridge] listening on 0.0.0.0:{d}\n", .{self.port});
        std.debug.print("[px-bridge] queue dir: {s}\n", .{self.queue_dir});
        std.debug.print("[px-bridge] routes: /px/status /px/exec /px/result /px/queue /px/done /px/jobs /px/issues /px/log\n", .{});

        while (true) {
            const conn = server.accept() catch continue;
            defer conn.stream.close();
            self.handleRequest(conn.stream) catch |err| {
                std.debug.print("[px-bridge] request error: {s}\n", .{@errorName(err)});
            };
        }
    }

    fn handleRequest(self: *Bridge, stream: std.net.Stream) !void {
        // Read HTTP request headers (up to 8KB)
        var buf: [8192]u8 = undefined;
        const n = stream.read(&buf) catch return;
        if (n == 0) return;
        const request = buf[0..n];

        // Parse first line: METHOD /path?query HTTP/1.1
        const line_end = std.mem.indexOf(u8, request, "\r\n") orelse return;
        const first_line = request[0..line_end];

        // Determine method
        const is_get = std.mem.startsWith(u8, first_line, "GET ");
        const is_post = std.mem.startsWith(u8, first_line, "POST ");
        if (!is_get and !is_post) {
            try writeResponse(stream, "405", "{\"error\":\"GET or POST only\"}");
            return;
        }

        // Extract path+query
        const method_len: usize = if (is_get) 4 else 5;
        const path_end = std.mem.lastIndexOf(u8, first_line, " HTTP/") orelse return;
        const target = first_line[method_len..path_end];

        const q_pos = std.mem.indexOf(u8, target, "?");
        const path = target[0..(q_pos orelse target.len)];
        const query = if (q_pos) |p| target[p + 1 ..] else "";

        // Validate token
        const token_val = getQueryParam(query, "token");
        if (token_val == null or !std.mem.eql(u8, token_val.?, self.token)) {
            try writeResponse(stream, "403", "{\"error\":\"invalid token\"}");
            return;
        }

        std.debug.print("[px-bridge] {s} {s}\n", .{ if (is_get) "GET" else "POST", path });

        // Extract POST body — read full body based on Content-Length
        var post_body: ?[]const u8 = null;
        var body_alloc: ?[]u8 = null;
        defer if (body_alloc) |b| self.allocator.free(b);

        if (is_post) {
            if (std.mem.indexOf(u8, request, "\r\n\r\n")) |hdr_end| {
                const body_start = hdr_end + 4;
                const headers = request[0..hdr_end];

                // Parse Content-Length
                var content_length: usize = 0;
                var hdr_iter = std.mem.splitSequence(u8, headers, "\r\n");
                while (hdr_iter.next()) |line| {
                    if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
                        const val = std.mem.trim(u8, line["content-length:".len..], &std.ascii.whitespace);
                        content_length = std.fmt.parseInt(usize, val, 10) catch 0;
                        break;
                    }
                }

                if (content_length > max_body) content_length = max_body;

                if (content_length > 0) {
                    // Allocate buffer for full body
                    body_alloc = self.allocator.alloc(u8, content_length) catch null;
                    if (body_alloc) |full_body| {
                        // Copy what we already have
                        const already_read = @min(n - body_start, content_length);
                        @memcpy(full_body[0..already_read], request[body_start .. body_start + already_read]);

                        // Read remaining body from stream
                        var total: usize = already_read;
                        while (total < content_length) {
                            const r = stream.read(full_body[total..content_length]) catch break;
                            if (r == 0) break;
                            total += r;
                        }
                        post_body = full_body[0..total];
                    }
                } else if (body_start < n) {
                    // No Content-Length, use what's in buffer
                    post_body = request[body_start..n];
                }
            }
        }

        // Route
        if (std.mem.eql(u8, path, "/px/status")) {
            try self.handleStatus(stream);
        } else if (std.mem.eql(u8, path, "/px/exec")) {
            const cmd = getQueryParam(query, "cmd") orelse "status";
            try self.handleExecAsync(stream, cmd);
        } else if (std.mem.eql(u8, path, "/px/result")) {
            const id = getQueryParam(query, "id") orelse {
                try writeResponse(stream, "400", "{\"error\":\"missing id param\"}");
                return;
            };
            try self.handleResult(stream, id);
        } else if (std.mem.eql(u8, path, "/px/queue")) {
            try self.handleQueuePoll(stream);
        } else if (std.mem.eql(u8, path, "/px/done")) {
            const id = getQueryParam(query, "id") orelse {
                try writeResponse(stream, "400", "{\"error\":\"missing id param\"}");
                return;
            };
            const exit_str = getQueryParam(query, "exit") orelse "0";
            const exit_code = std.fmt.parseInt(i32, exit_str, 10) catch 0;
            // Result from query param or POST body
            const result = getQueryParam(query, "result") orelse
                (post_body orelse "");
            try self.handleDone(stream, id, result, exit_code);
        } else if (std.mem.eql(u8, path, "/px/jobs")) {
            try self.handleJobsList(stream);
        } else if (std.mem.eql(u8, path, "/px/issues")) {
            try self.handleIssues(stream);
        } else if (std.mem.eql(u8, path, "/px/log")) {
            const n_str = getQueryParam(query, "n") orelse "50";
            const count = std.fmt.parseInt(u32, n_str, 10) catch 50;
            try self.handleLog(stream, count);
        } else {
            try writeResponse(stream, "404", "{\"error\":\"not found\",\"routes\":[\"/px/status\",\"/px/exec\",\"/px/result\",\"/px/queue\",\"/px/done\",\"/px/jobs\",\"/px/issues\",\"/px/log\"]}");
        }
    }

    // ─── Job Queue ───────────────────────────────────────────────

    fn genJobId(self: *Bridge) ![]const u8 {
        self.job_counter +%= 1;
        const ts: u64 = @intCast(std.time.timestamp());
        return try std.fmt.allocPrint(self.allocator, "j_{x}_{d}", .{ ts, self.job_counter });
    }

    fn jobPath(self: *Bridge, id: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "{s}/{s}.json", .{ self.queue_dir, id });
    }

    fn createJob(self: *Bridge, cmd: []const u8) ![]const u8 {
        const id = try self.genJobId();

        const ts: i64 = std.time.timestamp();

        var json = std.ArrayList(u8).empty;
        defer json.deinit(self.allocator);
        const w = json.writer(self.allocator);
        try w.writeAll("{\"id\":\"");
        try w.writeAll(id);
        try w.writeAll("\",\"cmd\":\"");
        try writeJsonEscaped(w, cmd);
        try w.print("\",\"status\":\"pending\",\"created_at\":{d},\"started_at\":null,\"finished_at\":null,\"result\":null,\"exit_code\":null}}", .{ts});

        const path = try self.jobPath(id);
        defer self.allocator.free(path);

        const file = try openFileForWrite(self.queue_dir, id);
        defer file.close();
        try file.writeAll(json.items);

        std.debug.print("[px-bridge] job created: {s} cmd={s}\n", .{ id, cmd });
        return id;
    }

    fn readJobFile(self: *Bridge, id: []const u8) ![]const u8 {
        const path = try self.jobPath(id);
        defer self.allocator.free(path);

        const file = std.fs.cwd().openFile(path, .{}) catch return error.FileNotFound;
        defer file.close();
        return try file.readToEndAlloc(self.allocator, max_body);
    }

    fn updateJob(self: *Bridge, id: []const u8, status: []const u8, result: []const u8, exit_code: i32) !void {
        // Read existing job to get cmd and created_at
        const existing = self.readJobFile(id) catch return error.FileNotFound;
        defer self.allocator.free(existing);

        // Extract cmd and created_at from existing JSON (simple parsing)
        const cmd = extractJsonString(existing, "cmd") orelse "unknown";
        const created_at = extractJsonInt(existing, "created_at") orelse 0;
        const ts: i64 = std.time.timestamp();

        var json = std.ArrayList(u8).empty;
        defer json.deinit(self.allocator);
        const w = json.writer(self.allocator);
        try w.writeAll("{\"id\":\"");
        try w.writeAll(id);
        try w.writeAll("\",\"cmd\":\"");
        try writeJsonEscaped(w, cmd);
        try w.writeAll("\",\"status\":\"");
        try w.writeAll(status);
        try w.print("\",\"created_at\":{d},\"started_at\":{d},\"finished_at\":{d},\"result\":\"", .{ created_at, ts, ts });
        try writeJsonEscaped(w, result);
        try w.print("\",\"exit_code\":{d}}}", .{exit_code});

        const file = try openFileForWrite(self.queue_dir, id);
        defer file.close();
        try file.writeAll(json.items);

        std.debug.print("[px-bridge] job updated: {s} → {s}\n", .{ id, status });
    }

    fn findPendingJob(self: *Bridge) !?[]const u8 {
        var dir = std.fs.cwd().openDir(self.queue_dir, .{ .iterate = true }) catch return null;
        defer dir.close();

        var oldest_id: ?[]const u8 = null;
        var oldest_ts: i64 = std.math.maxInt(i64);

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
            const id = entry.name[0 .. entry.name.len - 5];

            // Read and check status
            const content = self.readJobFile(id) catch continue;
            defer self.allocator.free(content);

            const status = extractJsonString(content, "status") orelse continue;
            if (!std.mem.eql(u8, status, "pending")) continue;

            const ts = extractJsonInt(content, "created_at") orelse continue;
            if (ts < oldest_ts) {
                if (oldest_id) |old| self.allocator.free(old);
                oldest_id = self.allocator.dupe(u8, id) catch continue;
                oldest_ts = ts;
            }
        }
        return oldest_id;
    }

    // ─── Async Exec Handler ─────────────────────────────────────

    fn handleExecAsync(self: *Bridge, stream: std.net.Stream, cmd: []const u8) !void {
        // Full URL-decode: %XX hex sequences and '+' as spaces
        const decoded = try urlDecode(self.allocator, cmd);
        defer self.allocator.free(decoded);

        std.debug.print("[px-bridge] raw cmd: {s}\n", .{cmd});
        std.debug.print("[px-bridge] decoded cmd: {s}\n", .{decoded});

        // Validate command is in whitelist
        const shell_cmd = self.mapCommand(decoded) catch {
            var err_resp = std.ArrayList(u8).empty;
            defer err_resp.deinit(self.allocator);
            const ew = err_resp.writer(self.allocator);
            try ew.writeAll("{\"error\":\"unknown command\",\"cmd\":\"");
            try writeJsonEscaped(ew, decoded);
            try ew.writeAll("\",\"available\":[\"diag\",\"status\",\"build\",\"test\",\"issues\",\"log\",\"branch\",\"push\",\"commit\",\"tri-diag\",\"swarm run N\",\"claude:<prompt>\"]}");
            try writeResponse(stream, "200", err_resp.items);
            return;
        };
        defer self.allocator.free(shell_cmd);

        const id = self.createJob(shell_cmd) catch {
            try writeResponse(stream, "500", "{\"error\":\"failed to create job\"}");
            return;
        };
        defer self.allocator.free(id);

        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const w = resp.writer(self.allocator);
        try w.writeAll("{\"job_id\":\"");
        try w.writeAll(id);
        try w.writeAll("\",\"status\":\"queued\",\"poll\":\"/px/result?id=");
        try w.writeAll(id);
        try w.writeAll("&token=...\"}");

        try writeResponse(stream, "202", resp.items);
    }

    fn handleResult(self: *Bridge, stream: std.net.Stream, id: []const u8) !void {
        const content = self.readJobFile(id) catch {
            try writeResponse(stream, "404", "{\"error\":\"job not found\"}");
            return;
        };
        defer self.allocator.free(content);

        try writeResponse(stream, "200", content);
    }

    fn handleQueuePoll(self: *Bridge, stream: std.net.Stream) !void {
        const id = (try self.findPendingJob()) orelse {
            try writeResponse(stream, "200", "{\"status\":\"empty\",\"id\":null}");
            return;
        };
        defer self.allocator.free(id);

        // Mark as running
        const content = self.readJobFile(id) catch {
            try writeResponse(stream, "200", "{\"status\":\"empty\",\"id\":null}");
            return;
        };
        defer self.allocator.free(content);

        const cmd = extractJsonString(content, "cmd") orelse "unknown";

        // Update status to running
        const ts: i64 = std.time.timestamp();
        const created_at = extractJsonInt(content, "created_at") orelse ts;

        var json = std.ArrayList(u8).empty;
        defer json.deinit(self.allocator);
        const w = json.writer(self.allocator);
        try w.writeAll("{\"id\":\"");
        try w.writeAll(id);
        try w.writeAll("\",\"cmd\":\"");
        try writeJsonEscaped(w, cmd);
        try w.print("\",\"status\":\"running\",\"created_at\":{d},\"started_at\":{d},\"finished_at\":null,\"result\":null,\"exit_code\":null}}", .{ created_at, ts });

        const file = try openFileForWrite(self.queue_dir, id);
        defer file.close();
        try file.writeAll(json.items);

        // Return job for Mac agent
        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const rw = resp.writer(self.allocator);
        try rw.writeAll("{\"id\":\"");
        try rw.writeAll(id);
        try rw.writeAll("\",\"cmd\":\"");
        try writeJsonEscaped(rw, cmd);
        try rw.writeAll("\"}");

        try writeResponse(stream, "200", resp.items);
    }

    fn handleDone(self: *Bridge, stream: std.net.Stream, id: []const u8, result: []const u8, exit_code: i32) !void {
        self.updateJob(id, "done", result, exit_code) catch {
            try writeResponse(stream, "404", "{\"error\":\"job not found\"}");
            return;
        };

        try writeResponse(stream, "200", "{\"status\":\"ok\",\"updated\":true}");
    }

    fn handleJobsList(self: *Bridge, stream: std.net.Stream) !void {
        var dir = std.fs.cwd().openDir(self.queue_dir, .{ .iterate = true }) catch {
            try writeResponse(stream, "200", "{\"jobs\":[]}");
            return;
        };
        defer dir.close();

        var resp = std.ArrayList(u8).empty;
        defer resp.deinit(self.allocator);
        const w = resp.writer(self.allocator);
        try w.writeAll("{\"jobs\":[");

        var count: u32 = 0;
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
            const id = entry.name[0 .. entry.name.len - 5];

            const content = self.readJobFile(id) catch continue;
            defer self.allocator.free(content);

            if (count > 0) try w.writeAll(",");
            try w.writeAll(content);
            count += 1;
            if (count >= 20) break; // Limit to 20 most recent
        }

        try w.writeAll("]}");
        try writeResponse(stream, "200", resp.items);
    }

    // ─── Legacy Direct Handlers (local exec fallback) ───────────

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

        // Count pending jobs in queue
        var pending: u32 = 0;
        var running: u32 = 0;
        blk: {
            var dir = std.fs.cwd().openDir(self.queue_dir, .{ .iterate = true }) catch break :blk;
            defer dir.close();
            var iter = dir.iterate();
            while (iter.next() catch null) |entry| {
                if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
                const id = entry.name[0 .. entry.name.len - 5];
                const content = self.readJobFile(id) catch continue;
                defer self.allocator.free(content);
                const status = extractJsonString(content, "status") orelse continue;
                if (std.mem.eql(u8, status, "pending")) pending += 1;
                if (std.mem.eql(u8, status, "running")) running += 1;
            }
        }

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
        try w.print("\",\"queue_pending\":{d},\"queue_running\":{d}}}", .{ pending, running });

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
            .{ "tri diag", "zig build 2>&1; echo EXIT:$? && PASS=$(grep -c '✅' specs/REGENERATION_REPORT.md 2>/dev/null || echo 0) && FAIL=$(grep -c '❌' specs/REGENERATION_REPORT.md 2>/dev/null || echo 0) && echo COMPILE:$PASS/$((PASS+FAIL)) && git status --short | wc -l | xargs printf 'DIRTY:%d\\n'" },
            .{ "status", "git status --short && git log --oneline -3" },
            .{ "git status", "git status --short && git log --oneline -3" },
            .{ "commit", "git add -A && git commit -m 'chore: auto-commit from px-bridge' 2>&1 || echo 'nothing to commit'" },
            .{ "build", "zig build 2>&1; echo EXIT:$?" },
            .{ "zig build", "zig build 2>&1; echo EXIT:$?" },
            .{ "test", "zig build test 2>&1; echo EXIT:$?" },
            .{ "zig test", "zig build test 2>&1; echo EXIT:$?" },
            .{ "issues", "gh issue list --state open --json number,title --limit 20 2>/dev/null || echo '[]'" },
            .{ "push", "git push 2>&1" },
            .{ "log", "git log --oneline -20" },
            .{ "git log", "git log --oneline -20" },
            .{ "branch", "git branch --show-current" },
            .{ "tri-diag", "./zig-out/bin/tri diag 2>&1 || echo 'tri not available'" },
            .{ "help", "echo 'Commands: diag, status, build, test, issues, log, branch, push, commit, tri-diag, swarm run N, claude:<prompt>'" },
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

        // claude:<prompt> — pass to Claude Code CLI (timeout 600s)
        if (std.mem.startsWith(u8, cmd, "claude:")) {
            const prompt = cmd["claude:".len..];
            if (prompt.len == 0) return error.InvalidCommand;
            // Escape single quotes in prompt
            return try std.fmt.allocPrint(self.allocator, "timeout 600 claude --print '{s}' 2>&1 || echo 'CLAUDE_TIMEOUT'", .{prompt});
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

// ─── File Helpers ────────────────────────────────────────────

fn openFileForWrite(queue_dir: []const u8, id: []const u8) !std.fs.File {
    // Build filename: {id}.json
    var name_buf: [64]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "{s}.json", .{id}) catch return error.NameTooLong;

    var dir = std.fs.cwd().openDir(queue_dir, .{}) catch return error.QueueDirNotFound;
    defer dir.close();
    return dir.createFile(name, .{}) catch return error.JobFileCreateFailed;
}

// ─── Simple JSON Field Extraction ────────────────────────────
// Minimal parsing — extracts string/int values from flat JSON objects.
// No external JSON lib needed.

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Find "key":"value" pattern
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;
    const start_idx = std.mem.indexOf(u8, json, search) orelse return null;
    const val_start = start_idx + search.len;

    // Find closing quote (handle escaped quotes)
    var i: usize = val_start;
    while (i < json.len) : (i += 1) {
        if (json[i] == '\\') {
            i += 1; // skip escaped char
            continue;
        }
        if (json[i] == '"') break;
    }
    if (i >= json.len) return null;
    return json[val_start..i];
}

fn extractJsonInt(json: []const u8, key: []const u8) ?i64 {
    // Find "key":123 pattern
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return null;
    const start_idx = std.mem.indexOf(u8, json, search) orelse return null;
    const val_start = start_idx + search.len;

    // Skip whitespace
    var i: usize = val_start;
    while (i < json.len and json[i] == ' ') : (i += 1) {}
    if (i >= json.len) return null;

    // Check for null
    if (std.mem.startsWith(u8, json[i..], "null")) return null;

    // Parse integer
    var end: usize = i;
    if (json[end] == '-') end += 1;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    return std.fmt.parseInt(i64, json[i..end], 10) catch null;
}

// ─── HTTP Helpers ────────────────────────────────────────────

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

fn hexDigit(c: u8) ?u4 {
    return switch (c) {
        '0'...'9' => @intCast(c - '0'),
        'A'...'F' => @intCast(c - 'A' + 10),
        'a'...'f' => @intCast(c - 'a' + 10),
        else => null,
    };
}

fn urlDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = try allocator.alloc(u8, input.len);
    var j: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '+') {
            out[j] = ' ';
            j += 1;
            i += 1;
        } else if (input[i] == '%' and i + 2 < input.len) {
            const hi = hexDigit(input[i + 1]);
            const lo = hexDigit(input[i + 2]);
            if (hi != null and lo != null) {
                out[j] = (@as(u8, hi.?) << 4) | @as(u8, lo.?);
                j += 1;
                i += 3;
            } else {
                out[j] = input[i];
                j += 1;
                i += 1;
            }
        } else {
            out[j] = input[i];
            j += 1;
            i += 1;
        }
    }
    // Shrink to actual size
    const result = try allocator.alloc(u8, j);
    @memcpy(result, out[0..j]);
    allocator.free(out);
    return result;
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
