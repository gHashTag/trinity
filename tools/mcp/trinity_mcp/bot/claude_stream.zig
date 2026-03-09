// claude_stream.zig — Streaming Claude CLI execution with sendMessageDraft
// Spawns claude with --output-format stream-json, pipes stdout,
// reads NDJSON line-by-line, sends drafts every 500ms, final message when done.
const std = @import("std");
const telegram_api = @import("telegram_api.zig");
const json_utils = @import("json_utils.zig");

const BotConfig = telegram_api.BotConfig;

/// Shared state between main thread (polling) and worker thread (streaming).
/// Atomics for lock-free is_busy check, PID for /stop.
pub const StreamState = struct {
    is_busy: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    active_pid: std.atomic.Value(i32) = std.atomic.Value(i32).init(0),
};

/// Worker thread entry point: spawn claude, stream output, send drafts.
/// Called via std.Thread.spawn() from bot_loop dispatch.
pub fn runStreaming(
    allocator: std.mem.Allocator,
    config: BotConfig,
    args_owned: []const u8,
    use_continue: bool,
    state: *StreamState,
) void {
    defer {
        state.active_pid.store(0, .release);
        state.is_busy.store(false, .release);
        allocator.free(args_owned);
    }

    // Notify user
    if (use_continue) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x94\x84 TRI streaming...");
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa7\xa0 TRI streaming...");
    }

    // Build turns string
    var turns_buf: [16]u8 = undefined;
    const turns_str = std.fmt.bufPrint(&turns_buf, "{d}", .{config.max_turns}) catch "10";

    // Build argv dynamically based on args and --continue flag
    var argv_buf: [12][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "claude";
    argc += 1;
    if (args_owned.len > 0) {
        argv_buf[argc] = "-p";
        argc += 1;
        argv_buf[argc] = args_owned;
        argc += 1;
    }
    if (use_continue) {
        argv_buf[argc] = "--continue";
        argc += 1;
    }
    argv_buf[argc] = "--output-format";
    argc += 1;
    argv_buf[argc] = "stream-json";
    argc += 1;
    argv_buf[argc] = "--max-turns";
    argc += 1;
    argv_buf[argc] = turns_str;
    argc += 1;

    // Init child with piped stdout
    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = config.project_root;

    child.spawn() catch |err| {
        var err_buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &err_buf, "\xe2\x9d\x8c Spawn error: {s}", .{@errorName(err)});
        return;
    };

    // Store PID for /stop
    state.active_pid.store(@intCast(child.id), .release);

    std.debug.print("[tri-bot] Streaming started (PID {d})\n", .{child.id});

    // Read stdout line-by-line, accumulate text deltas, send drafts
    var text_buf: std.ArrayList(u8) = .empty;
    defer text_buf.deinit(allocator);

    var last_draft_ns: i128 = std.time.nanoTimestamp();
    const draft_interval: i128 = 500_000_000; // 500ms

    const stdout_file = child.stdout.?;
    var line_buf: [65536]u8 = undefined;
    var line_len: usize = 0;
    var read_chunk: [4096]u8 = undefined;

    while (true) {
        const n = stdout_file.read(&read_chunk) catch break;
        if (n == 0) break; // EOF

        for (read_chunk[0..n]) |byte| {
            if (byte == '\n') {
                // Process complete NDJSON line
                const line = line_buf[0..line_len];
                if (std.mem.indexOf(u8, line, "\"text_delta\"") != null) {
                    if (json_utils.extractString(line, "text")) |text_val| {
                        text_buf.appendSlice(allocator, text_val) catch {};
                    }
                }
                line_len = 0;

                // Throttle: sendDraft every 500ms
                const now = std.time.nanoTimestamp();
                if (now - last_draft_ns >= draft_interval and text_buf.items.len > 0) {
                    const draft_len = @min(text_buf.items.len, 4000);
                    telegram_api.sendDraft(allocator, config.bot_token, config.chat_id, text_buf.items[0..draft_len]);
                    last_draft_ns = now;
                }
            } else if (line_len < line_buf.len - 1) {
                line_buf[line_len] = byte;
                line_len += 1;
            }
        }
    }

    // Wait for child to finish
    _ = child.wait() catch {};

    std.debug.print("[tri-bot] Streaming done ({d} bytes)\n", .{text_buf.items.len});

    // Send final message
    if (text_buf.items.len > 0) {
        telegram_api.sendLongMessage(allocator, config, text_buf.items);
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Claude returned empty response");
    }
}

/// Stop the active Claude process via SIGTERM.
pub fn stopProcess(allocator: std.mem.Allocator, config: BotConfig, state: *StreamState) void {
    const pid = state.active_pid.load(.acquire);
    if (pid > 0) {
        const posix_pid: std.posix.pid_t = @intCast(pid);
        std.posix.kill(posix_pid, 15) catch |err| { // 15 = SIGTERM
            var err_buf: [256]u8 = undefined;
            telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &err_buf, "\xe2\x9d\x8c Kill error: {s}", .{@errorName(err)});
            return;
        };
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9b\x94 Claude process stopped");
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No active Claude process");
    }
}
