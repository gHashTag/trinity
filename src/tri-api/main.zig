// main.zig — TRI-API: Direct Anthropic API agentic loop
// No claude CLI dependency. Talks to api.anthropic.com/v1/messages directly.
// Self-contained in src/tri-api/. Issues #60, #64.
const std = @import("std");
const proto = @import("tool_protocol.zig");
const executor = @import("tool_executor.zig");
const session_store = @import("session_store.zig");

const api_url = "https://api.anthropic.com/v1/messages";
const api_version = "2023-06-01";
const max_turns = 20;
const default_model = "claude-sonnet-4-20250514";

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read API key
    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch {
        std.debug.print("error: ANTHROPIC_API_KEY not set\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(api_key);

    // Parse CLI args: [--model <model>] [--continue] [--resume <id>] [--sessions] <prompt...>
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var model: []const u8 = default_model;
    var do_continue = false;
    var resume_id: ?[]const u8 = null;
    var do_list_sessions = false;
    var prompt_start: usize = 1; // skip argv[0]

    while (prompt_start < args.len) {
        const arg = args[prompt_start];
        if (std.mem.eql(u8, arg, "--model") and prompt_start + 1 < args.len) {
            model = args[prompt_start + 1];
            prompt_start += 2;
        } else if (std.mem.eql(u8, arg, "--continue")) {
            do_continue = true;
            prompt_start += 1;
        } else if (std.mem.eql(u8, arg, "--resume") and prompt_start + 1 < args.len) {
            resume_id = args[prompt_start + 1];
            prompt_start += 2;
        } else if (std.mem.eql(u8, arg, "--sessions")) {
            do_list_sessions = true;
            prompt_start += 1;
        } else break;
    }

    // Session store
    var store = session_store.SessionStore.init(allocator);
    defer store.deinit();

    // --sessions: list and exit
    if (do_list_sessions) {
        if (store.listSessions()) |list| {
            defer allocator.free(list);
            const stdout_file = std.fs.File.stdout();
            var write_buf: [4096]u8 = undefined;
            var w = stdout_file.writer(&write_buf);
            std.Io.Writer.writeAll(&w.interface, list) catch {};
            w.end() catch {};
        } else {
            std.debug.print("No sessions found.\n", .{});
        }
        return;
    }

    if (prompt_start >= args.len) {
        std.debug.print("usage: tri-api [--model <m>] [--continue] [--resume <id>] [--sessions] <prompt>\n", .{});
        std.process.exit(1);
    }

    // Join remaining args as prompt
    const prompt = std.mem.join(allocator, " ", args[prompt_start..]) catch {
        std.debug.print("error: out of memory\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(prompt);

    // Load session history if --continue or --resume
    const resume_messages: ?[]const u8 = blk: {
        if (do_continue) {
            break :blk store.loadLatest();
        } else if (resume_id) |rid| {
            break :blk store.load(rid);
        }
        break :blk null;
    };
    defer if (resume_messages) |rm| allocator.free(rm);

    if (do_continue or resume_id != null) {
        if (resume_messages != null) {
            std.debug.print("[tri-api] Resuming session\n", .{});
        } else {
            std.debug.print("[tri-api] No session found to resume\n", .{});
        }
    }

    std.debug.print("[tri-api] model={s} prompt={d} chars\n", .{ model, prompt.len });

    // Build conversation: messages accumulate across turns
    var messages = std.ArrayList(u8).empty;
    defer messages.deinit(allocator);

    // If resuming, prepend previous messages
    if (resume_messages) |rm| {
        // rm is like "[{...},{...}]" — strip trailing ] so we can append
        if (rm.len > 1 and rm[rm.len - 1] == ']') {
            try messages.appendSlice(allocator, rm[0 .. rm.len - 1]);
            try messages.appendSlice(allocator, ",{\"role\":\"user\",\"content\":\"");
        } else {
            try messages.appendSlice(allocator, "[{\"role\":\"user\",\"content\":\"");
        }
    } else {
        try messages.appendSlice(allocator, "[{\"role\":\"user\",\"content\":\"");
    }
    try proto.writeJsonEscaped(messages.writer(allocator), prompt);
    try messages.appendSlice(allocator, "\"}");

    var tool_exec = executor.ToolExecutor{ .allocator = allocator };
    var total_input_tokens: u32 = 0;
    var total_output_tokens: u32 = 0;

    // Agentic loop
    var turn: u32 = 0;
    while (turn < max_turns) : (turn += 1) {
        // Close messages array
        var request_body = std.ArrayList(u8).empty;
        defer request_body.deinit(allocator);

        try request_body.appendSlice(allocator, "{\"model\":\"");
        try request_body.appendSlice(allocator, model);
        try request_body.appendSlice(allocator, "\",\"max_tokens\":8192,\"tools\":");
        try proto.writeToolDefinitions(request_body.writer(allocator));
        try request_body.appendSlice(allocator, ",\"messages\":");
        try request_body.appendSlice(allocator, messages.items);
        try request_body.appendSlice(allocator, "]}");

        std.debug.print("[tri-api] turn {d}: sending {d} bytes...\n", .{ turn + 1, request_body.items.len });

        // POST to Anthropic API
        const response_body = httpPost(allocator, api_key, request_body.items) catch |err| {
            std.debug.print("[tri-api] HTTP error: {s}\n", .{@errorName(err)});
            break;
        };
        defer allocator.free(response_body);

        // Parse response
        var parsed = proto.parseResponse(allocator, response_body);
        defer parsed.deinit(allocator);

        total_input_tokens += parsed.input_tokens;
        total_output_tokens += parsed.output_tokens;

        // Process content blocks
        var has_tool_use = false;

        // Build assistant message for conversation history
        try messages.appendSlice(allocator, ",{\"role\":\"assistant\",\"content\":");
        try messages.appendSlice(allocator, extractContentArray(response_body) orelse "[]");
        try messages.appendSlice(allocator, "}");

        for (parsed.blocks.items) |block| {
            switch (block) {
                .text => |text| {
                    const stdout_file = std.fs.File.stdout();
                    var write_buf: [4096]u8 = undefined;
                    var w = stdout_file.writer(&write_buf);
                    std.Io.Writer.writeAll(&w.interface, text) catch {};
                    std.Io.Writer.writeAll(&w.interface, "\n") catch {};
                    w.end() catch {};
                },
                .tool_use => |tool| {
                    has_tool_use = true;
                    std.debug.print("[tri-api] tool: {s}({s})\n", .{ tool.name, tool.id });

                    const tool_name = executor.ToolName.fromString(tool.name) orelse {
                        std.debug.print("[tri-api] unknown tool: {s}\n", .{tool.name});
                        continue;
                    };

                    const result = tool_exec.execute(tool_name, tool.input_json);

                    // Append tool result to messages
                    try messages.appendSlice(allocator, ",{\"role\":\"user\",\"content\":[");
                    try proto.writeToolResult(messages.writer(allocator), tool.id, result.output, result.is_error);
                    try messages.appendSlice(allocator, "]}");
                },
            }
        }

        // Check stop condition
        if (std.mem.eql(u8, parsed.stop_reason, "end_turn") or !has_tool_use) {
            std.debug.print("[tri-api] done: {s}\n", .{parsed.stop_reason});
            break;
        }
    }

    // Close messages array and save session
    try messages.appendSlice(allocator, "]");
    store.save(messages.items, prompt);

    std.debug.print("[tri-api] {d} turns, {d} input + {d} output tokens\n", .{ turn + 1, total_input_tokens, total_output_tokens });
}

/// Extract the raw "content":[...] array from response body.
fn extractContentArray(body: []const u8) ?[]const u8 {
    const needle = "\"content\":[";
    const idx = std.mem.indexOf(u8, body, needle) orelse return null;
    const start = idx + "\"content\":".len;
    // Find matching ]
    var depth: u32 = 0;
    var end = start;
    var in_string = false;
    while (end < body.len) : (end += 1) {
        if (in_string) {
            if (body[end] == '"' and (end == 0 or body[end - 1] != '\\')) in_string = false;
            continue;
        }
        switch (body[end]) {
            '"' => in_string = true,
            '[' => depth += 1,
            ']' => {
                depth -= 1;
                if (depth == 0) return body[start .. end + 1];
            },
            else => {},
        }
    }
    return null;
}

/// POST JSON to Anthropic Messages API using Zig 0.15 std.http.Client.
fn httpPost(allocator: std.mem.Allocator, api_key: []const u8, body: []const u8) ![]const u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(api_url) catch unreachable;

    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "x-api-key", .value = api_key },
            .{ .name = "anthropic-version", .value = api_version },
        },
    }) catch return error.ConnectionFailed;
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch return error.ConnectionFailed;
    body_writer.writer.writeAll(body) catch return error.ConnectionFailed;
    body_writer.end() catch return error.ConnectionFailed;
    if (req.connection) |conn| conn.flush() catch {};

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch return error.ConnectionFailed;

    if (@intFromEnum(response.head.status) >= 400) {
        std.debug.print("[tri-api] API status: {d}\n", .{@intFromEnum(response.head.status)});
    }

    var transfer_buf: [8192]u8 = undefined;
    var reader = response.reader(&transfer_buf);
    const resp_body = reader.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return error.OutOfMemory;

    return resp_body;
}
