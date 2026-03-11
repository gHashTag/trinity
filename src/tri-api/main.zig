// main.zig — TRI-API: Direct Anthropic API agentic loop
// No claude CLI dependency. Talks to api.anthropic.com/v1/messages directly.
// Self-contained in src/tri-api/. Issues #60, #64, #66, #67.
const std = @import("std");
const proto = @import("tool_protocol.zig");
const executor = @import("tool_executor.zig");
const session_store = @import("session_store.zig");
const permissions = @import("permissions.zig");
const tui = @import("tui.zig");
const mcp_client = @import("mcp_client.zig");
const context = @import("context.zig");
const claude_md = @import("claude_md.zig");
const memory_mod = @import("memory.zig");
const px_bridge = @import("perplexity_bridge.zig");

const default_api_base = "https://api.anthropic.com";
const api_version = "2023-06-01";
const max_turns = 20;
const default_model = "claude-sonnet-4-20250514";

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI args first (--serve needs no API key)
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var model: []const u8 = default_model;
    var do_continue = false;
    var resume_id: ?[]const u8 = null;
    var do_list_sessions = false;
    var do_serve = false;
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
        } else if (std.mem.eql(u8, arg, "--serve")) {
            do_serve = true;
            prompt_start += 1;
        } else break;
    }

    // --serve: start Perplexity Bridge HTTP server (no API key needed)
    if (do_serve) {
        var bridge = px_bridge.Bridge.init(allocator) orelse {
            std.debug.print("error: PX_BRIDGE_TOKEN must be set for --serve mode\n", .{});
            std.process.exit(1);
        };
        defer bridge.deinit();
        bridge.serve() catch |err| {
            std.debug.print("[px-bridge] server error: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        };
        return;
    }

    // Session store
    var store = session_store.SessionStore.init(allocator);
    defer store.deinit();

    // Read API key (required for all modes except --serve)
    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch {
        std.debug.print("error: ANTHROPIC_API_KEY not set\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(api_key);

    // Read base URL (supports z.ai, custom proxies)
    const api_base_owned = std.process.getEnvVarOwned(allocator, "ANTHROPIC_BASE_URL") catch null;
    defer if (api_base_owned) |b| allocator.free(b);
    const api_base = if (api_base_owned) |b| b else default_api_base;

    // Build messages endpoint URL
    const api_url = try std.fmt.allocPrint(allocator, "{s}/v1/messages", .{api_base});
    defer allocator.free(api_url);

    // --sessions: list and exit
    if (do_list_sessions) {
        if (store.listSessions()) |list| {
            defer allocator.free(list);
            const stdout_file = std.fs.File.stdout();
            var write_buf: [4096]u8 = undefined;
            var w = stdout_file.writer(&write_buf);
            std.Io.Writer.writeAll(&w.interface, list) catch |err| {
                std.log.debug("tri-api/main: failed to write session list: {}", .{err});
            };
            w.end() catch |err| {
                std.log.debug("tri-api/main: failed to flush stdout: {}", .{err});
            };
        } else {
            std.debug.print("No sessions found.\n", .{});
        }
        return;
    }

    // Load permission config
    var perms = permissions.loadConfig(allocator);
    defer perms.deinit(allocator);

    // Load MCP servers from settings
    var mcp = mcp_client.McpManager.init(allocator);
    defer mcp.deinit();
    loadMcpServers(allocator, &mcp);

    // Load system prompt: CLAUDE.md hierarchy + memory
    var mem = memory_mod.Memory.init(allocator);
    const system_prompt = blk: {
        var parts = std.ArrayList(u8).empty;
        if (claude_md.loadSystemPrompt(allocator)) |sp| {
            parts.appendSlice(allocator, sp) catch |err| {
                std.log.warn("tri-api/main: failed to append system prompt: {}", .{err});
            };
            allocator.free(sp);
        }
        if (mem.load()) |mem_content| {
            claude_md.appendMemory(allocator, &parts, mem_content);
            allocator.free(mem_content);
        }
        if (parts.items.len > 0) {
            break :blk parts.toOwnedSlice(allocator) catch null;
        }
        parts.deinit(allocator);
        break :blk @as(?[]const u8, null);
    };
    defer if (system_prompt) |sp| allocator.free(sp);

    // Interactive mode (no prompt args) or batch mode
    if (prompt_start >= args.len and !do_list_sessions) {
        // Interactive TUI mode
        var ui = tui.Tui.init(allocator);
        ui.printBanner(model, @intCast(perms.allow_rules.items.len + perms.deny_rules.items.len));

        // Show MCP servers
        for (mcp.servers.items) |server| {
            ui.printMcp(server.name, countServerTools(&mcp, server.name));
        }

        var tool_exec = executor.ToolExecutor.init(allocator, &perms, &mcp);
        var messages = std.ArrayList(u8).empty;
        defer messages.deinit(allocator);

        while (true) {
            const input = ui.readPrompt() orelse break;
            defer allocator.free(input);

            // Handle slash commands
            if (input.len > 0 and input[0] == '/') {
                if (std.mem.eql(u8, input, "/quit") or std.mem.eql(u8, input, "/exit")) break;
                if (std.mem.eql(u8, input, "/sessions")) {
                    if (store.listSessions()) |list| {
                        defer allocator.free(list);
                        ui.printSession(list);
                    } else {
                        ui.printAssistant("No sessions found.");
                    }
                    continue;
                }
                ui.printError("Unknown command. Use /quit or /sessions.");
                continue;
            }

            // Build messages
            if (messages.items.len == 0) {
                try messages.appendSlice(allocator, "[{\"role\":\"user\",\"content\":\"");
            } else {
                // Strip trailing ] and append new user message
                if (messages.items.len > 0 and messages.items[messages.items.len - 1] == ']') {
                    _ = messages.pop();
                }
                try messages.appendSlice(allocator, ",{\"role\":\"user\",\"content\":\"");
            }
            try proto.writeJsonEscaped(messages.writer(allocator), input);
            try messages.appendSlice(allocator, "\"}");

            // Run agentic loop for this prompt
            const stats = runAgenticLoop(allocator, api_key, api_url, model, system_prompt, &messages, &tool_exec, &mcp, &ui);
            ui.printTokens(stats.input_tokens, stats.output_tokens);

            // Save session
            var save_buf = std.ArrayList(u8).empty;
            defer save_buf.deinit(allocator);
            try save_buf.appendSlice(allocator, messages.items);
            try save_buf.appendSlice(allocator, "]");
            store.save(save_buf.items, input);
        }
        return;
    }

    // Batch mode: join remaining args as prompt
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

    var tool_exec = executor.ToolExecutor.init(allocator, &perms, &mcp);

    std.debug.print("[tri-api] permissions: {d} allow, {d} deny rules\n", .{ perms.allow_rules.items.len, perms.deny_rules.items.len });

    const stats = runAgenticLoop(allocator, api_key, api_url, model, system_prompt, &messages, &tool_exec, &mcp, null);

    // Close messages array and save session
    try messages.appendSlice(allocator, "]");
    store.save(messages.items, prompt);

    std.debug.print("[tri-api] {d} input + {d} output tokens\n", .{ stats.input_tokens, stats.output_tokens });
}

const LoopStats = struct { input_tokens: u32, output_tokens: u32 };

/// Run the agentic loop: send messages → parse → execute tools → repeat.
fn runAgenticLoop(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    api_url_param: []const u8,
    model: []const u8,
    system_prompt: ?[]const u8,
    messages: *std.ArrayList(u8),
    tool_exec: *executor.ToolExecutor,
    mcp: *mcp_client.McpManager,
    ui_opt: ?*tui.Tui,
) LoopStats {
    var total_input_tokens: u32 = 0;
    var total_output_tokens: u32 = 0;

    var ctx = context.ContextManager.init(allocator);

    var turn: u32 = 0;
    while (turn < max_turns) : (turn += 1) {
        // Auto-compact if near context limit
        if (ctx.isNearLimit(messages)) {
            const truncated = ctx.truncateOldToolOutputs(messages);
            if (truncated) {
                std.debug.print("[tri-api] compacted: truncated old tool outputs\n", .{});
            }
            // If still over limit after truncation, try API summarization
            if (ctx.isNearLimit(messages)) {
                if (ctx.buildCompactionRequest(messages, model)) |compact_body| {
                    defer allocator.free(compact_body);
                    if (httpPost(allocator, api_key, api_url_param, compact_body)) |summary_resp| {
                        defer allocator.free(summary_resp);
                        var parsed_summary = proto.parseResponse(allocator, summary_resp);
                        defer parsed_summary.deinit(allocator);
                        for (parsed_summary.blocks.items) |block| {
                            switch (block) {
                                .text => |text| {
                                    ctx.applySummary(messages, text);
                                    std.debug.print("[tri-api] compacted: summarized conversation\n", .{});
                                },
                                else => {},
                            }
                        }
                    } else |_| {}
                }
            }
        }

        var request_body = std.ArrayList(u8).empty;
        defer request_body.deinit(allocator);

        request_body.appendSlice(allocator, "{\"model\":\"") catch break;
        request_body.appendSlice(allocator, model) catch break;
        request_body.appendSlice(allocator, "\",\"max_tokens\":8192") catch break;

        // System prompt (CLAUDE.md + memory)
        if (system_prompt) |sp| {
            request_body.appendSlice(allocator, ",\"system\":\"") catch break;
            proto.writeJsonEscaped(request_body.writer(allocator), sp) catch break;
            request_body.appendSlice(allocator, "\"") catch break;
        }

        request_body.appendSlice(allocator, ",\"tools\":") catch break;

        // Write built-in + MCP tool definitions
        const rw = request_body.writer(allocator);
        rw.writeByte('[') catch break;
        proto.writeToolDefinitions(rw) catch break;
        if (mcp.tools.items.len > 0) {
            rw.writeByte(',') catch break;
            mcp.writeToolDefinitions(rw) catch break;
        }
        rw.writeByte(']') catch break;

        request_body.appendSlice(allocator, ",\"messages\":") catch break;
        request_body.appendSlice(allocator, messages.items) catch break;
        request_body.appendSlice(allocator, "]}") catch break;

        if (ui_opt == null) {
            std.debug.print("[tri-api] turn {d}: sending {d} bytes...\n", .{ turn + 1, request_body.items.len });
        }

        const response_body = httpPost(allocator, api_key, api_url_param, request_body.items) catch |err| {
            if (ui_opt) |ui| {
                ui.printError(@errorName(err));
            } else {
                std.debug.print("[tri-api] HTTP error: {s}\n", .{@errorName(err)});
            }
            break;
        };
        defer allocator.free(response_body);

        var parsed = proto.parseResponse(allocator, response_body);
        defer parsed.deinit(allocator);

        total_input_tokens += parsed.input_tokens;
        total_output_tokens += parsed.output_tokens;
        ctx.trackApiUsage(parsed.input_tokens, parsed.output_tokens);

        var has_tool_use = false;

        // Build assistant message for conversation history
        messages.appendSlice(allocator, ",{\"role\":\"assistant\",\"content\":") catch break;
        messages.appendSlice(allocator, extractContentArray(response_body) orelse "[]") catch break;
        messages.appendSlice(allocator, "}") catch break;

        for (parsed.blocks.items) |block| {
            switch (block) {
                .text => |text| {
                    if (ui_opt) |ui| {
                        ui.printAssistant(text);
                    } else {
                        const stdout = std.fs.File.stdout();
                        stdout.writeAll(text) catch |err| {
                            std.log.debug("tri-api/main: failed to write text output: {}", .{err});
                        };
                        stdout.writeAll("\n") catch |err| {
                            std.log.debug("tri-api/main: failed to write newline: {}", .{err});
                        };
                    }
                },
                .tool_use => |tool| {
                    has_tool_use = true;

                    if (ui_opt) |ui| {
                        ui.printTool(tool.name, tool.input_json);
                    } else {
                        std.debug.print("[tri-api] tool: {s}({s})\n", .{ tool.name, tool.id });
                    }

                    const result = tool_exec.executeDynamic(tool.name, tool.input_json);

                    if (result.is_error) {
                        if (ui_opt) |ui| ui.printDenied(tool.name, "");
                    }

                    // Append tool result to messages
                    messages.appendSlice(allocator, ",{\"role\":\"user\",\"content\":[") catch break;
                    proto.writeToolResult(messages.writer(allocator), tool.id, result.output, result.is_error) catch break;
                    messages.appendSlice(allocator, "]}") catch break;
                },
            }
        }

        if (std.mem.eql(u8, parsed.stop_reason, "end_turn") or !has_tool_use) {
            if (ui_opt == null) {
                std.debug.print("[tri-api] done: {s}\n", .{parsed.stop_reason});
            }
            break;
        }
    }

    return .{ .input_tokens = total_input_tokens, .output_tokens = total_output_tokens };
}

/// Load MCP servers from user + project settings.json.
fn loadMcpServers(allocator: std.mem.Allocator, mcp: *mcp_client.McpManager) void {
    // Try project-local .tri-api/settings.json first, then user ~/.tri-api/settings.json
    const settings_data = blk: {
        break :blk std.fs.cwd().readFileAlloc(allocator, ".tri-api/settings.json", 64 * 1024) catch {
            const home = std.posix.getenv("HOME") orelse break :blk @as(?[]const u8, null);
            var path_buf: [512]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "{s}/.tri-api/settings.json", .{home}) catch break :blk @as(?[]const u8, null);
            break :blk std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024) catch @as(?[]const u8, null);
        };
    };
    if (settings_data == null) return;
    defer allocator.free(settings_data.?);

    var configs = mcp_client.loadMcpConfig(allocator, settings_data.?);
    for (configs.items) |cfg| {
        // Dupe name since cfg.name points into settings_data which gets freed
        const name_owned = allocator.dupe(u8, cfg.name) catch continue;
        const tool_count = mcp.connectServer(name_owned, cfg.command);
        if (tool_count > 0) {
            std.debug.print("[tri-api] MCP: {s} ({d} tools)\n", .{ name_owned, tool_count });
        }
    }
    configs.deinit(allocator);
}

/// Count tools belonging to a specific server.
fn countServerTools(mcp: *mcp_client.McpManager, server_name: []const u8) u32 {
    var count: u32 = 0;
    for (mcp.tools.items) |tool| {
        // Tool names are "server.tool_name"
        if (std.mem.startsWith(u8, tool.name, server_name)) {
            count += 1;
        }
    }
    return count;
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
fn httpPost(allocator: std.mem.Allocator, api_key: []const u8, url: []const u8, body: []const u8) ![]const u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch unreachable;

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
    if (req.connection) |conn| conn.flush() catch |err| {
        std.log.debug("tri-api/main: failed to flush connection: {}", .{err});
    };

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch return error.ConnectionFailed;

    if (@intFromEnum(response.head.status) >= 400) {
        std.debug.print("[tri-api] API status: {d}\n", .{@intFromEnum(response.head.status)});
    }

    // Allocate decompression buffer based on content encoding (handles gzip/deflate from proxies like z.ai)
    const decompress_buffer: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .zstd => allocator.alloc(u8, std.compress.zstd.default_window_len) catch return error.OutOfMemory,
        .deflate, .gzip => allocator.alloc(u8, std.compress.flate.max_window_len) catch return error.OutOfMemory,
        .compress => return error.ConnectionFailed,
    };
    defer if (decompress_buffer.len > 0) allocator.free(decompress_buffer);

    var transfer_buf: [8192]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    var reader = response.readerDecompressing(&transfer_buf, &decompress, decompress_buffer);
    const resp_body = reader.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return error.OutOfMemory;

    return resp_body;
}
