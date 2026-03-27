const std = @import("std");
const telegram_pulse = @import("telegram_pulse.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Testing RALPH PULSE OF LIFE E2E...\n", .{});

    // Load config from environment
    const config = try telegram_pulse.loadConfig(allocator);
    if (!config.enabled) {
        std.debug.print("Pulse disabled. Set RALPH_PULSE_ENABLED=true\n", .{});
        return;
    }

    // Debug: print config
    std.debug.print("[DEBUG] Bot token: {s}...\n", .{config.bot_token[0..@min(30, config.bot_token.len)]});
    std.debug.print("[DEBUG] Chat ID: {s}\n", .{config.chat_id});

    // === CRITICAL: Delete webhook to enable long polling ===
    // Telegram Bot API forbids webhook and getUpdates simultaneously
    std.debug.print("Checking webhook status...\n", .{});
    const webhook_active = try telegram_pulse.getWebhookInfo(allocator, config);
    if (webhook_active) {
        std.debug.print("Webhook is active. Deleting to enable polling...\n", .{});
        try telegram_pulse.deleteWebhook(allocator, config);
        std.debug.print("Webhook deleted. Polling mode enabled.\n", .{});
    } else {
        std.debug.print("No webhook detected. Polling mode ready.\n", .{});
    }

    // Test 1: Send all pulse types
    std.debug.print("Test 1: Sending pulses...\n", .{});
    try telegram_pulse.sendPulse(allocator, config, .thought, "E2E Test - Starting...");
    try telegram_pulse.sendPulse(allocator, config, .action, "E2E Test - Testing new keyboard...");
    try telegram_pulse.sendPulse(allocator, config, .state_change, "TEST -> POLLING");
    try telegram_pulse.sendPulse(allocator, config, .heartbeat, "E2E Loop 1");

    // Test 2: Send improved InlineKeyboardMarkup
    std.debug.print("Test 2: Setting up InlineKeyboard with emojis...\n", .{});
    try sendInlineKeyboard(allocator, config);

    // Test 3: Start polling for commands and callbacks
    std.debug.print("Test 3: Starting polling... (Press Ctrl+C to stop)\n", .{});
    try startPolling(allocator, config);
}

// Send InlineKeyboardMarkup with emojis and logical grouping
fn sendInlineKeyboard(allocator: std.mem.Allocator, config: telegram_pulse.PulseConfig) !void {
    const url = try std.fmt.allocPrint(allocator, "https://api.telegram.org/bot{s}/sendMessage", .{config.bot_token});
    defer allocator.free(url);

    // Inline keyboard with emojis, grouped by theme
    // Row 1: INFO (Status, Tasks, Logs)
    // Row 2: CONTROLS (Pause, Resume, Stop) - together!
    // Row 3: ACTIONS (Approve, Pulse, Clear)
    // Row 4: TOOLS (Git, Bench, Verbose)
    const keyboard_json_template =
        \\{{"chat_id": {s}, "text": "🤖 RALPH CONTROL PANEL\\n━━━━━━━━━━━━━━━━━━━━━━━━", "reply_markup": {{"inline_keyboard": [[{{"text": "📊 Status", "callback_data": "/status"}}, {{"text": "📋 Tasks", "callback_data": "/tasks"}}, {{"text": "📜 Logs", "callback_data": "/logs"}}], [{{"text": "⏸️ Pause", "callback_data": "/pause"}}, {{"text": "▶️ Resume", "callback_data": "/resume"}}, {{"text": "⏹️ Stop", "callback_data": "/stop"}}], [{{"text": "✅ Approve", "callback_data": "/approve"}}, {{"text": "🔄 Pulse", "callback_data": "/pulse"}}, {{"text": "🗑️ Clear", "callback_data": "/clear"}}], [{{"text": "🌿 Git", "callback_data": "/git"}}, {{"text": "⚡ Bench", "callback_data": "/bench"}}, {{"text": "🔔 Verbose", "callback_data": "/verbose"}}]]}}}}
    ;

    var body_buffer: [2048]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buffer, keyboard_json_template, .{config.chat_id});

    const headers = [_]std.http.Header{
        .{ .name = "User-Agent", .value = "RALPH-PULSE/2.0" },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch return error.InvalidUrl;
    var req = try client.request(.POST, uri, .{
        .extra_headers = &headers,
        .redirect_behavior = .unhandled,
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = try req.sendBodyUnflushed(&.{});
    try body_writer.writer.writeAll(body);
    try body_writer.end();
    if (req.connection) |conn| try conn.flush();

    var redirect_buf: [0]u8 = .{};
    _ = req.receiveHead(&redirect_buf) catch return error.Timeout;

    std.debug.print("InlineKeyboard sent with emojis!\n", .{});
}

// Simple sleep using nanosleep (seconds, nanoseconds)
fn sleep(seconds: u64) void {
    std.posix.nanosleep(seconds, 0);
}

// Answer callback query to remove loading state
fn answerCallbackQuery(allocator: std.mem.Allocator, config: telegram_pulse.PulseConfig, callback_id: []const u8, text: []const u8) !void {
    var url_buffer: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "https://api.telegram.org/bot{s}/answerCallbackQuery", .{config.bot_token});

    // JSON body with callback_query_id and optional text
    const body_template =
        \\{{"callback_query_id": "{s}", "text": "{s}", "show_alert": false}}
    ;

    var body_buffer: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buffer, body_template, .{ callback_id, text });

    const headers = [_]std.http.Header{
        .{ .name = "User-Agent", .value = "RALPH-PULSE/2.0" },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch return error.InvalidUrl;
    var req = try client.request(.POST, uri, .{
        .extra_headers = &headers,
        .redirect_behavior = .unhandled,
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = try req.sendBodyUnflushed(&.{});
    try body_writer.writer.writeAll(body);
    try body_writer.end();
    if (req.connection) |conn| try conn.flush();

    var redirect_buf: [0]u8 = .{};
    _ = req.receiveHead(&redirect_buf) catch {};
}

fn startPolling(allocator: std.mem.Allocator, config: telegram_pulse.PulseConfig) !void {
    var offset: i64 = 0;
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    std.debug.print("Listening for commands/callbacks... (Press Ctrl+C to stop)\n", .{});

    while (true) {
        // Build getUpdates URL with long poll timeout
        var url_buffer: [512]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buffer, "https://api.telegram.org/bot{s}/getUpdates?offset={d}&timeout=30", .{ config.bot_token, offset });

        const uri = std.Uri.parse(url) catch {
            sleep(5);
            continue;
        };

        // Create request
        var req = client.request(.GET, uri, .{
            .extra_headers = &.{},
            .redirect_behavior = .unhandled,
        }) catch {
            sleep(5);
            continue;
        };
        defer req.deinit();

        req.sendBodiless() catch {
            sleep(5);
            continue;
        };

        // Receive response
        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch |err| {
            std.debug.print("[ERROR] receiveHead failed: {}\n", .{err});
            sleep(5);
            continue;
        };

        // Read response body
        var transfer_buffer: [16384]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const response_body = reader.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch |err| {
            std.debug.print("[ERROR] allocRemaining failed: {}\n", .{err});
            sleep(5);
            continue;
        };
        defer allocator.free(response_body);

        // Debug: Log first 500 chars of response
        if (response_body.len > 0) {
            const debug_len = @min(500, response_body.len);
            std.debug.print("[DEBUG] Response ({d} bytes): {s}...\n", .{ response_body.len, response_body[0..debug_len] });
        }

        // Skip empty responses
        if (response_body.len == 0) {
            sleep(5);
            continue;
        }

        // === HANDLE CALLBACK QUERIES (InlineKeyboard) ===
        const callback_pattern = 
            \\callback_query
        ;
        if (std.mem.indexOf(u8, response_body, callback_pattern)) |cb_idx| {
            std.debug.print("[CALLBACK] Detected callback query!\n", .{});

            // Extract callback data (look for "data":"/command" pattern)
            // Try both patterns: with comma (,"data":") and without ("data":")
            const data_with_comma = ",\"data\":\"";
            const data_no_comma = "\"data\":\"";

            const data_idx = if (std.mem.indexOf(u8, response_body[cb_idx..], data_with_comma)) |i| i else if (std.mem.indexOf(u8, response_body[cb_idx..], data_no_comma)) |i| i else null;

            if (data_idx) |data_start_idx| {
                // Determine which pattern matched and calculate start position
                const found_comma = std.mem.indexOf(u8, response_body[cb_idx..], data_with_comma) != null;
                const skip_len: usize = if (found_comma) 9 else 8; // ,"data":" = 9, "data": = 8
                const actual_data_start = cb_idx + data_start_idx + skip_len;
                var data_end = actual_data_start;
                while (data_end < response_body.len and response_body[data_end] != '"') : (data_end += 1) {}
                if (data_end < response_body.len) {
                    const command = response_body[actual_data_start..data_end];
                    std.debug.print("[CALLBACK] Command from callback: {s}\n", .{command});

                    // Extract callback query id (look for "id":" pattern before "data")
                    const id_pattern = 
                        \\id:
                    ;
                    if (std.mem.indexOfPos(u8, response_body[cb_idx..], 0, id_pattern)) |id_idx| {
                        const id_start = cb_idx + id_idx + 4;
                        var id_end = id_start;
                        while (id_end < response_body.len and response_body[id_end] != '"') : (id_end += 1) {}
                        if (id_end < response_body.len) {
                            const callback_id = response_body[id_start..id_end];
                            std.debug.print("[CALLBACK] Callback ID: {s}\n", .{callback_id});

                            // Handle the command
                            const response_text = try handleCommand(allocator, config, command);

                            // Answer the callback
                            try answerCallbackQuery(allocator, config, callback_id, response_text);
                        }
                    }
                }
            }
        }

        // === HANDLE REGULAR MESSAGES ===
        // Simplified parsing - just look for "text":"/command pattern
        const message_text_pattern_comma = ",\"text\":\"";
        const message_text_pattern_no_comma = "\"text\":\"";

        const text_idx = if (std.mem.indexOf(u8, response_body, message_text_pattern_comma)) |i| i else if (std.mem.indexOf(u8, response_body, message_text_pattern_no_comma)) |i| i else null;

        if (text_idx) |idx| {
            const found_comma = std.mem.indexOf(u8, response_body, message_text_pattern_comma) != null;
            const skip_len: usize = if (found_comma) 9 else 8; // ,"text":" = 9, "text": = 8
            const value_start = idx + skip_len;
            if (value_start < response_body.len) {
                var text_end = value_start;
                while (text_end < response_body.len and response_body[text_end] != '"') : (text_end += 1) {}
                if (text_end < response_body.len) {
                    const command = response_body[value_start..text_end];

                    // Only process if it starts with /
                    if (std.mem.startsWith(u8, command, "/")) {
                        // Log command
                        std.debug.print("[MESSAGE] Received command: {s}\n", .{command});

                        // Send pulse that we received command
                        try telegram_pulse.sendPulse(allocator, config, .action, command);

                        // Handle commands and send reply to user
                        const response_text = try handleCommand(allocator, config, command);
                        try telegram_pulse.sendMessage(allocator, config, response_text);

                        // Exit on /stop
                        if (std.mem.eql(u8, command, "/stop")) {
                            std.debug.print("Stop command received. Exiting.\n", .{});
                            return;
                        }
                    }
                }
            }
        }

        // Extract update_id for offset (from any update)
        // Try both patterns: with comma (,"update_id":) and without ("update_id":)
        const update_id_with_comma = ",\"update_id\":";
        const update_id_no_comma = "\"update_id\":";

        // Search both patterns
        var search_idx: usize = 0;
        while (true) {
            // Find next occurrence of either pattern
            const idx_comma = std.mem.indexOfPos(u8, response_body, search_idx, update_id_with_comma);
            const idx_no_comma = std.mem.indexOfPos(u8, response_body, search_idx, update_id_no_comma);

            const idx = if (idx_comma) |ic| if (idx_no_comma) |in| if (ic < in) ic else in else ic else if (idx_no_comma) |in| in else null;

            if (idx) |i| {
                // Extract offset: pattern len is 12 for both ("update_id": = 12 chars)
                const start = i + 12;
                if (start < response_body.len) {
                    // Skip whitespace after colon (JSON may have newlines)
                    var num_start = start;
                    while (num_start < response_body.len and (response_body[num_start] == ' ' or response_body[num_start] == '\n' or response_body[num_start] == '\r' or response_body[num_start] == '\t')) : (num_start += 1) {}

                    var end = num_start;
                    while (end < response_body.len and response_body[end] >= '0' and response_body[end] <= '9') : (end += 1) {}
                    if (end > num_start) {
                        const update_id_str = response_body[num_start..end];
                        if (std.fmt.parseInt(i64, update_id_str, 10)) |id| {
                            if (id + 1 > offset) {
                                offset = id + 1;
                                std.debug.print("[OFFSET] Updated to {d}\n", .{offset});
                            }
                        } else |_| {}
                    }
                }
                search_idx = i + 1;
            } else break;
        }
    }
}

// Returns response text for callback answering
fn handleCommand(allocator: std.mem.Allocator, config: telegram_pulse.PulseConfig, command: []const u8) ![]const u8 {
    if (std.mem.eql(u8, command, "/start")) {
        try telegram_pulse.sendPulse(allocator, config, .action, "User started bot");
        return "👋 Welcome to RALPH Control Panel!\n\nUse buttons or commands:\n/status, /tasks, /logs, /pause, /resume, /pulse, /approve, /git, /bench, /verbose, /clear";
    } else if (std.mem.eql(u8, command, "/status")) {
        try telegram_pulse.sendPulse(allocator, config, .thought, "Status: E2E Test Running - Polling active");
        return "✅ Status: Running";
    } else if (std.mem.eql(u8, command, "/tasks")) {
        try telegram_pulse.sendPulse(allocator, config, .thought, "Current tasks: E2E Testing");
        return "📋 Tasks: E2E Testing";
    } else if (std.mem.eql(u8, command, "/logs")) {
        try telegram_pulse.sendPulse(allocator, config, .thought, "Recent: E2E test started");
        return "📜 Recent: E2E started";
    } else if (std.mem.eql(u8, command, "/pause")) {
        try telegram_pulse.sendPulse(allocator, config, .state_change, "RUNNING -> PAUSED");
        return "⏸️ Paused";
    } else if (std.mem.eql(u8, command, "/resume")) {
        try telegram_pulse.sendPulse(allocator, config, .state_change, "PAUSED -> RUNNING");
        return "▶️ Resumed";
    } else if (std.mem.eql(u8, command, "/stop")) {
        try telegram_pulse.sendPulse(allocator, config, .state_change, "RUNNING -> STOPPED");
        return "⏹️ Stopping...";
    } else if (std.mem.eql(u8, command, "/pulse")) {
        try telegram_pulse.sendPulse(allocator, config, .heartbeat, "E2E Pulse test");
        return "🔄 Pulse sent!";
    } else if (std.mem.eql(u8, command, "/approve")) {
        try telegram_pulse.sendPulse(allocator, config, .action, "Action APPROVED via E2E");
        return "✅ Approved!";
    } else if (std.mem.eql(u8, command, "/git")) {
        try telegram_pulse.sendPulse(allocator, config, .thought, "Git status: Clean");
        return "🌿 Git: Clean";
    } else if (std.mem.eql(u8, command, "/bench")) {
        try telegram_pulse.sendPulse(allocator, config, .action, "Running benchmarks...");
        return "⚡ Benchmarks started";
    } else if (std.mem.eql(u8, command, "/verbose")) {
        try telegram_pulse.sendPulse(allocator, config, .thought, "Verbose mode: ON");
        return "🔔 Verbose: ON";
    } else if (std.mem.eql(u8, command, "/clear")) {
        try telegram_pulse.sendPulse(allocator, config, .action, "Queue cleared");
        return "🗑️ Queue cleared";
    }
    return "Done";
}
