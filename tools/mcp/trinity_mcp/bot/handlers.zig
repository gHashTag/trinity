// handlers.zig — Command handlers for tri-bot
// No claude CLI dependency. /status uses git directly.
const std = @import("std");
const telegram_api = @import("telegram_api.zig");

const BotConfig = telegram_api.BotConfig;

/// Runtime state that persists across commands within a bot run.
pub const BotState = struct {
    model_buf: [64]u8 = undefined,
    model_len: usize = 0,
    /// In-memory conversation history as Anthropic messages JSON array.
    /// Format: [{"role":"user","content":"..."},{"role":"assistant","content":"..."}]
    history: ?[]u8 = null,
    history_alloc: std.mem.Allocator = undefined,

    pub fn getModel(self: *const BotState) ?[]const u8 {
        if (self.model_len == 0) return null;
        return self.model_buf[0..self.model_len];
    }

    pub fn setModel(self: *BotState, name: []const u8) void {
        const len = @min(name.len, self.model_buf.len);
        @memcpy(self.model_buf[0..len], name[0..len]);
        self.model_len = len;
    }

    pub fn getHistory(self: *const BotState) ?[]const u8 {
        return self.history;
    }

    /// Append a user message to conversation history.
    pub fn appendUserMessage(self: *BotState, text: []const u8) void {
        self.appendMessage("user", text);
    }

    /// Append an assistant message to conversation history.
    pub fn appendAssistantMessage(self: *BotState, text: []const u8) void {
        self.appendMessage("assistant", text);
    }

    fn appendMessage(self: *BotState, role: []const u8, content: []const u8) void {
        const allocator = self.history_alloc;
        var buf: std.ArrayList(u8) = .empty;

        if (self.history) |h| {
            // Existing history: strip trailing ']', append comma + new message + ']'
            if (h.len > 1 and h[h.len - 1] == ']') {
                buf.appendSlice(allocator, h[0 .. h.len - 1]) catch {
                    buf.deinit(allocator);
                    return;
                };
                buf.appendSlice(allocator, ",") catch {
                    buf.deinit(allocator);
                    return;
                };
            } else {
                buf.appendSlice(allocator, "[") catch {
                    buf.deinit(allocator);
                    return;
                };
            }
            allocator.free(h);
            self.history = null;
        } else {
            buf.appendSlice(allocator, "[") catch return;
        }

        // Append {"role":"...","content":"..."}]
        const parts = [_][]const u8{ "{\"role\":\"", role, "\",\"content\":\"" };
        for (parts) |part| {
            buf.appendSlice(allocator, part) catch {
                buf.deinit(allocator);
                return;
            };
        }
        // JSON-escape content
        for (content) |c| {
            const ok = switch (c) {
                '"' => buf.appendSlice(allocator, "\\\""),
                '\\' => buf.appendSlice(allocator, "\\\\"),
                '\n' => buf.appendSlice(allocator, "\\n"),
                '\r' => buf.appendSlice(allocator, "\\r"),
                '\t' => buf.appendSlice(allocator, "\\t"),
                else => buf.append(allocator, c),
            };
            ok catch {
                buf.deinit(allocator);
                return;
            };
        }
        buf.appendSlice(allocator, "\"}]") catch {
            buf.deinit(allocator);
            return;
        };

        self.history = buf.toOwnedSlice(allocator) catch {
            buf.deinit(allocator);
            return;
        };
    }

    /// Clear conversation history.
    pub fn clearHistory(self: *BotState) void {
        if (self.history) |h| {
            self.history_alloc.free(h);
            self.history = null;
        }
    }
};

/// /help — Send list of available commands
pub fn handleHelp(allocator: std.mem.Allocator, config: BotConfig) void {
    const help_text =
        "\xf0\x9f\xa4\x96 TRI BOT v3.0 \xe2\x80\x94 Trinity AI Agent\n" ++
        "\n" ++
        "Just type a message \xe2\x80\x94 I'll respond!\n" ++
        "\n" ++
        "Commands:\n" ++
        "/tri <cmd> \xe2\x80\x94 Run tri CLI (constants, phi, fib, status...)\n" ++
        "/clear \xe2\x80\x94 Reset conversation history\n" ++
        "/model <name> \xe2\x80\x94 Set Claude model\n" ++
        "/status \xe2\x80\x94 Git project status\n" ++
        "/stop \xe2\x80\x94 Cancel active request\n" ++
        "/help \xe2\x80\x94 This message";
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, help_text);
}

/// /status — Show git project status (branch, commits, changes).
/// Uses git commands directly — no claude CLI.
pub fn handleStatus(allocator: std.mem.Allocator, config: BotConfig) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8a Checking status...");

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    out.appendSlice(allocator, "\xf0\x9f\x93\x8a Project Status\n\n") catch return;

    // Branch
    out.appendSlice(allocator, "Branch: ") catch return;
    appendCommandOutput(allocator, &out, config.project_root, &.{ "git", "branch", "--show-current" });

    // Recent commits
    out.appendSlice(allocator, "\nRecent commits:\n") catch return;
    appendCommandOutput(allocator, &out, config.project_root, &.{ "git", "log", "-5", "--oneline" });

    // Working tree changes
    out.appendSlice(allocator, "\nChanges:\n") catch return;
    const before_changes = out.items.len;
    appendCommandOutput(allocator, &out, config.project_root, &.{ "git", "status", "--short" });
    if (out.items.len == before_changes) {
        out.appendSlice(allocator, "(clean)\n") catch |err| {
            std.log.debug("handlers: failed to append clean status: {}", .{err});
        };
    }

    if (out.items.len > 20) {
        telegram_api.sendLongMessage(allocator, config, out.items);
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Could not get status");
    }
}

/// /model <name> — Set Claude model for subsequent requests.
pub fn handleModel(allocator: std.mem.Allocator, config: BotConfig, args: []const u8, bot_state: *BotState) void {
    if (args.len == 0) {
        // Show current model
        if (bot_state.getModel()) |model| {
            var buf: [256]u8 = undefined;
            telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xf0\x9f\xa4\x96 Current model: {s}", .{model});
        } else {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa4\x96 Model: default (claude-sonnet-4-20250514)");
        }
        return;
    }

    if (args.len > 64) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Model name too long (max 64 chars)");
        return;
    }

    bot_state.setModel(args);
    var buf: [256]u8 = undefined;
    telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9c\x85 Model set: {s}", .{args});
}

/// /undo — Restore last git checkpoint (created before write_file).
pub fn handleUndo(allocator: std.mem.Allocator, config: BotConfig) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x8f\xaa Checking for checkpoints...");

    // Run: git stash list --format="%gd %s" and find tri-api checkpoint
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "stash", "list", "--format=%gd %s" },
        .cwd = config.project_root,
        .max_output_bytes = 64 * 1024,
    }) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Not in a git repo");
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const stash_prefix = "tri-api checkpoint: ";

    // Find first tri-api stash entry
    var pos: usize = 0;
    while (pos < result.stdout.len) {
        var line_end = pos;
        while (line_end < result.stdout.len and result.stdout[line_end] != '\n') : (line_end += 1) {}
        const line = result.stdout[pos..line_end];

        if (std.mem.indexOf(u8, line, stash_prefix)) |prefix_idx| {
            const space_idx = std.mem.indexOf(u8, line, " ") orelse {
                pos = line_end + 1;
                continue;
            };
            const stash_ref = line[0..space_idx];
            const file_path = line[prefix_idx + stash_prefix.len ..];

            // Pop the stash
            const pop_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "git", "stash", "pop", stash_ref },
                .cwd = config.project_root,
                .max_output_bytes = 64 * 1024,
            }) catch {
                telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Undo failed: stash pop error");
                return;
            };
            defer allocator.free(pop_result.stdout);
            defer allocator.free(pop_result.stderr);

            var buf: [256]u8 = undefined;
            telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9c\x85 Restored: {s}", .{file_path});
            return;
        }

        pos = line_end + 1;
    }

    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No checkpoints found. Checkpoints are created when tri-api writes files.");
}

/// /clear — Reset conversation history
pub fn handleClear(allocator: std.mem.Allocator, config: BotConfig, bot_state: *BotState) void {
    bot_state.clearHistory();
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x97\x91 Conversation cleared. Starting fresh.");
}

/// /tri <command> — Execute a tri CLI command and send output to Telegram
pub fn handleTriCommand(allocator: std.mem.Allocator, config: BotConfig, args: []const u8) void {
    if (args.len == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Usage: /tri <command>\nExamples: /tri constants, /tri phi 10, /tri status");
        return;
    }

    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\x99 Running tri command...");

    // Build argv: split args by spaces (simple split, max 16 parts)
    var argv_buf: [18][]const u8 = undefined;
    var argv_len: usize = 0;

    // First two args are the binary path
    const tri_path = std.fmt.allocPrint(allocator, "{s}/zig-out/bin/tri", .{config.project_root}) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to build command path");
        return;
    };
    defer allocator.free(tri_path);

    argv_buf[0] = tri_path;
    argv_len = 1;

    // Split remaining args by space
    var pos: usize = 0;
    while (pos < args.len and argv_len < argv_buf.len) {
        // Skip spaces
        while (pos < args.len and args[pos] == ' ') : (pos += 1) {}
        if (pos >= args.len) break;
        const start = pos;
        while (pos < args.len and args[pos] != ' ') : (pos += 1) {}
        argv_buf[argv_len] = args[start..pos];
        argv_len += 1;
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argv_len],
        .cwd = config.project_root,
        .max_output_bytes = 64 * 1024,
    }) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Command failed to execute. Is tri built?");
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        telegram_api.sendLongMessage(allocator, config, result.stdout);
    } else if (result.stderr.len > 0) {
        telegram_api.sendLongMessage(allocator, config, result.stderr);
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No output from command");
    }
}

/// /sessions — List saved sessions from ~/.tri-api/sessions/index.json
pub fn handleSessions(allocator: std.mem.Allocator, config: BotConfig) void {
    const home = std.posix.getenv("HOME") orelse "/tmp";
    var path_buf: [512]u8 = undefined;
    const index_path = std.fmt.bufPrint(&path_buf, "{s}/.tri-api/sessions/index.json", .{home}) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Cannot resolve sessions path");
        return;
    };

    const content = readFileAbs(allocator, index_path) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8b No sessions yet. Use /ask to start one.");
        return;
    };
    defer allocator.free(content);

    // Format session list
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    out.appendSlice(allocator, "\xf0\x9f\x93\x8b Sessions:\n\n") catch return;

    const id_needle = "\"id\":\"";
    const preview_needle = "\"preview\":\"";
    var pos: usize = 0;
    var count: u32 = 0;

    while (pos < content.len) {
        const id_idx = std.mem.indexOfPos(u8, content, pos, id_needle) orelse break;
        const id_start = id_idx + id_needle.len;
        var id_end = id_start;
        while (id_end < content.len and content[id_end] != '"') : (id_end += 1) {}
        const id = content[id_start..id_end];

        const preview = blk: {
            if (std.mem.indexOfPos(u8, content, id_end, preview_needle)) |pi| {
                const ps = pi + preview_needle.len;
                var pe = ps;
                while (pe < content.len and content[pe] != '"') : (pe += 1) {}
                break :blk content[ps..pe];
            }
            break :blk "(no preview)";
        };

        count += 1;
        var line_buf: [256]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buf, "{d}. [{s}] {s}\n", .{ count, id, preview }) catch break;
        out.appendSlice(allocator, line) catch break;

        pos = id_end + 1;
    }

    if (count == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8b No sessions yet. Use /ask to start one.");
    } else {
        out.appendSlice(allocator, "\nUse /resume <id> to continue a session.") catch |err| {
            std.log.debug("handlers: failed to append resume hint: {}", .{err});
        };
        telegram_api.sendLongMessage(allocator, config, out.items);
    }
}

/// /resume [id] — Load session messages from ~/.tri-api/sessions/{id}.json.
/// Returns messages JSON (caller owns memory) or null if not found.
pub fn loadSessionMessages(allocator: std.mem.Allocator, session_id: []const u8) ?[]const u8 {
    const home = std.posix.getenv("HOME") orelse "/tmp";

    // If no ID provided, load latest
    if (session_id.len == 0) {
        return loadLatestSession(allocator, home);
    }

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.tri-api/sessions/{s}.json", .{ home, session_id }) catch return null;

    const content = readFileAbs(allocator, path) catch return null;
    defer allocator.free(content);

    return extractMessages(allocator, content);
}

/// Load the most recent session's messages.
fn loadLatestSession(allocator: std.mem.Allocator, home: []const u8) ?[]const u8 {
    var index_path_buf: [512]u8 = undefined;
    const index_path = std.fmt.bufPrint(&index_path_buf, "{s}/.tri-api/sessions/index.json", .{home}) catch return null;

    const index_content = readFileAbs(allocator, index_path) catch return null;
    defer allocator.free(index_content);

    // Find the last "id":" in index
    const needle = "\"id\":\"";
    var last_pos: ?usize = null;
    var pos: usize = 0;
    while (pos < index_content.len) {
        if (std.mem.indexOfPos(u8, index_content, pos, needle)) |idx| {
            last_pos = idx;
            pos = idx + needle.len;
        } else break;
    }

    if (last_pos) |lp| {
        const id_start = lp + needle.len;
        var id_end = id_start;
        while (id_end < index_content.len and index_content[id_end] != '"') : (id_end += 1) {}
        if (id_end > id_start) {
            return loadSessionMessages(allocator, index_content[id_start..id_end]);
        }
    }
    return null;
}

/// Extract "messages" field from session JSON, unescape it.
fn extractMessages(allocator: std.mem.Allocator, content: []const u8) ?[]const u8 {
    const needle = "\"messages\":\"";
    const idx = std.mem.indexOf(u8, content, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= content.len) return null;
    // Find closing unescaped quote
    var end = start;
    while (end < content.len) : (end += 1) {
        if (content[end] == '"' and (end == start or content[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    const escaped = content[start..end];
    // Unescape
    return unescapeJson(allocator, escaped);
}

/// Simple JSON unescape: \\n → \n, \\\\ → \\, \\" → "
fn unescapeJson(allocator: std.mem.Allocator, s: []const u8) ?[]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (s[i] == '\\' and i + 1 < s.len) {
            switch (s[i + 1]) {
                'n' => {
                    out.append(allocator, '\n') catch {
                        out.deinit(allocator);
                        return null;
                    };
                    i += 1;
                },
                't' => {
                    out.append(allocator, '\t') catch {
                        out.deinit(allocator);
                        return null;
                    };
                    i += 1;
                },
                'r' => {
                    out.append(allocator, '\r') catch {
                        out.deinit(allocator);
                        return null;
                    };
                    i += 1;
                },
                '\\' => {
                    out.append(allocator, '\\') catch {
                        out.deinit(allocator);
                        return null;
                    };
                    i += 1;
                },
                '"' => {
                    out.append(allocator, '"') catch {
                        out.deinit(allocator);
                        return null;
                    };
                    i += 1;
                },
                else => out.append(allocator, s[i]) catch {
                    out.deinit(allocator);
                    return null;
                },
            }
        } else {
            out.append(allocator, s[i]) catch {
                out.deinit(allocator);
                return null;
            };
        }
    }
    return out.toOwnedSlice(allocator) catch {
        out.deinit(allocator);
        return null;
    };
}

/// Read a file at an absolute path.
fn readFileAbs(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 10 * 1024 * 1024);
}

/// Run a command and append its stdout to the output buffer.
fn appendCommandOutput(allocator: std.mem.Allocator, out: *std.ArrayList(u8), cwd: []const u8, argv: []const []const u8) void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
        .max_output_bytes = 64 * 1024,
    }) catch {
        out.appendSlice(allocator, "(error)\n") catch |append_err| {
            std.log.debug("handlers: failed to append error status: {}", .{append_err});
        };
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        out.appendSlice(allocator, result.stdout) catch |err| {
            std.log.warn("handlers: failed to append stdout: {}", .{err});
        };
        // Ensure trailing newline
        if (result.stdout[result.stdout.len - 1] != '\n') {
            out.appendSlice(allocator, "\n") catch |err| {
                std.log.debug("handlers: failed to append newline: {}", .{err});
            };
        }
    }
}
