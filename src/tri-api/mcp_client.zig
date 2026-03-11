// mcp_client.zig — MCP stdio client for tri-api
// Spawns MCP servers as subprocesses, communicates via JSON-RPC 2.0 over stdio.
// Issue #66: Phase 7B MCP Client
const std = @import("std");
const proto = @import("tool_protocol.zig");

const max_response_size = 10 * 1024 * 1024; // 10MB per response

pub const McpToolDef = struct {
    name: []const u8, // "server_name.tool_name"
    description: []const u8,
    input_schema: []const u8, // raw JSON schema
    server_idx: u32, // which server owns this tool
};

pub const McpServer = struct {
    name: []const u8,
    child: std.process.Child,
    alive: bool,
};

pub const McpManager = struct {
    allocator: std.mem.Allocator,
    servers: std.ArrayList(McpServer),
    tools: std.ArrayList(McpToolDef),
    next_id: u32,

    pub fn init(allocator: std.mem.Allocator) McpManager {
        return .{
            .allocator = allocator,
            .servers = std.ArrayList(McpServer).empty,
            .tools = std.ArrayList(McpToolDef).empty,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *McpManager) void {
        // Kill all servers
        for (self.servers.items) |*server| {
            if (server.alive) {
                _ = server.child.kill() catch |err| {
                    std.log.debug("mcp_client: failed to kill server {s}: {}", .{ server.name, err });
                };
            }
        }
        self.servers.deinit(self.allocator);
        self.tools.deinit(self.allocator);
    }

    /// Connect to an MCP server: spawn, initialize, list tools.
    /// Returns number of tools discovered, or 0 on failure.
    pub fn connectServer(self: *McpManager, name: []const u8, command: []const []const u8) u32 {
        if (command.len == 0) return 0;

        var child = std.process.Child.init(command, self.allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        child.spawn() catch |err| {
            std.debug.print("[mcp] Failed to spawn {s}: {s}\n", .{ name, @errorName(err) });
            return 0;
        };

        const server_idx: u32 = @intCast(self.servers.items.len);
        self.servers.append(self.allocator, .{
            .name = name,
            .child = child,
            .alive = true,
        }) catch return 0;

        // Send initialize request
        const init_ok = self.sendRequest(server_idx, "initialize", "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"tri-api\",\"version\":\"1.0\"}}");
        if (!init_ok) {
            std.debug.print("[mcp] {s}: initialize failed\n", .{name});
            return 0;
        }

        // Send initialized notification
        self.sendNotification(server_idx, "notifications/initialized");

        // List tools
        const tool_count = self.discoverTools(server_idx, name);
        return tool_count;
    }

    /// Call a tool on an MCP server. Returns result text (caller owns memory).
    pub fn callTool(self: *McpManager, tool_name: []const u8, args_json: []const u8) ?[]const u8 {
        // Find the tool
        for (self.tools.items) |tool| {
            if (std.mem.eql(u8, tool.name, tool_name)) {
                // Build params: {"name":"actual_tool_name","arguments":{...}}
                // Strip server prefix from name to get actual tool name
                const dot_idx = std.mem.indexOf(u8, tool.name, ".") orelse 0;
                const actual_name = if (dot_idx > 0) tool.name[dot_idx + 1 ..] else tool.name;

                var params: std.ArrayList(u8) = .empty;
                defer params.deinit(self.allocator);

                params.appendSlice(self.allocator, "{\"name\":\"") catch return null;
                params.appendSlice(self.allocator, actual_name) catch return null;
                params.appendSlice(self.allocator, "\",\"arguments\":") catch return null;
                params.appendSlice(self.allocator, args_json) catch return null;
                params.appendSlice(self.allocator, "}") catch return null;

                if (self.sendRequestGetResult(tool.server_idx, "tools/call", params.items)) |response| {
                    return response;
                }
                return null;
            }
        }
        return null;
    }

    /// Write MCP tool definitions as JSON for Anthropic API.
    pub fn writeToolDefinitions(self: *McpManager, writer: anytype) !void {
        for (self.tools.items, 0..) |tool, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.writeAll("{\"name\":\"");
            try writer.writeAll(tool.name);
            try writer.writeAll("\",\"description\":\"");
            try proto.writeJsonEscaped(writer, tool.description);
            try writer.writeAll("\",\"input_schema\":");
            try writer.writeAll(tool.input_schema);
            try writer.writeByte('}');
        }
    }

    /// Check if a tool name belongs to an MCP server.
    pub fn isMcpTool(self: *McpManager, name: []const u8) bool {
        for (self.tools.items) |tool| {
            if (std.mem.eql(u8, tool.name, name)) return true;
        }
        return false;
    }

    // ─── Internal ────────────────────────────────────────────────────────

    fn discoverTools(self: *McpManager, server_idx: u32, server_name: []const u8) u32 {
        if (!self.sendRequest(server_idx, "tools/list", "{}")) return 0;

        // Read response
        const response = self.readResponse(server_idx) orelse return 0;
        defer self.allocator.free(response);

        // Parse tool entries from response
        // Look for "name":"..." and "description":"..." and "inputSchema":{...}
        var count: u32 = 0;
        const tools_needle = "\"tools\":[";
        const tools_start = std.mem.indexOf(u8, response, tools_needle) orelse return 0;
        var pos = tools_start + tools_needle.len;

        while (pos < response.len and response[pos] != ']') {
            // Find next tool object
            const name = proto.extractFieldFrom(response, pos, "name") orelse break;
            const desc = proto.extractFieldFrom(response, pos, "description") orelse "";
            const schema = extractSchema(response, pos) orelse "{}";

            // Build prefixed name: "server.tool"
            const full_name = std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ server_name, name }) catch break;

            self.tools.append(self.allocator, .{
                .name = full_name,
                .description = desc,
                .input_schema = schema,
                .server_idx = server_idx,
            }) catch break;

            count += 1;

            // Advance past this tool object
            if (std.mem.indexOfPos(u8, response, pos + 1, "\"name\":\"")) |next| {
                pos = next;
            } else break;
        }

        return count;
    }

    fn sendRequest(self: *McpManager, server_idx: u32, method: []const u8, params: []const u8) bool {
        if (server_idx >= self.servers.items.len) return false;
        const server = &self.servers.items[server_idx];
        if (!server.alive) return false;

        const stdin_file = server.child.stdin orelse return false;
        const id = self.next_id;
        self.next_id += 1;

        // Build JSON-RPC request
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);

        buf.appendSlice(self.allocator, "{\"jsonrpc\":\"2.0\",\"id\":") catch return false;
        var id_buf: [16]u8 = undefined;
        const id_str = std.fmt.bufPrint(&id_buf, "{d}", .{id}) catch return false;
        buf.appendSlice(self.allocator, id_str) catch return false;
        buf.appendSlice(self.allocator, ",\"method\":\"") catch return false;
        buf.appendSlice(self.allocator, method) catch return false;
        buf.appendSlice(self.allocator, "\",\"params\":") catch return false;
        buf.appendSlice(self.allocator, params) catch return false;
        buf.appendSlice(self.allocator, "}\n") catch return false;

        _ = stdin_file.write(buf.items) catch return false;
        return true;
    }

    fn sendNotification(self: *McpManager, server_idx: u32, method: []const u8) void {
        if (server_idx >= self.servers.items.len) return;
        const server = &self.servers.items[server_idx];
        if (!server.alive) return;

        const stdin_file = server.child.stdin orelse return;

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{{\"jsonrpc\":\"2.0\",\"method\":\"{s}\"}}\n", .{method}) catch return;
        _ = stdin_file.write(msg) catch |err| {
            std.log.debug("mcp_client: sendNotification write failed: {}", .{err});
        };
    }

    fn sendRequestGetResult(self: *McpManager, server_idx: u32, method: []const u8, params: []const u8) ?[]const u8 {
        if (!self.sendRequest(server_idx, method, params)) return null;
        const response = self.readResponse(server_idx) orelse return null;
        defer self.allocator.free(response);

        // Extract content text from response
        // MCP tool results: {"result":{"content":[{"type":"text","text":"..."}]}}
        const text_needle = "\"text\":\"";
        const result_needle = "\"result\":";
        const result_pos = std.mem.indexOf(u8, response, result_needle) orelse return null;
        const text_idx = std.mem.indexOfPos(u8, response, result_pos, text_needle) orelse return null;
        const start = text_idx + text_needle.len;
        var end = start;
        while (end < response.len) : (end += 1) {
            if (response[end] == '"' and (end == start or response[end - 1] != '\\')) break;
        }
        if (end > start) {
            return self.allocator.dupe(u8, response[start..end]) catch null;
        }
        return null;
    }

    fn readResponse(self: *McpManager, server_idx: u32) ?[]const u8 {
        if (server_idx >= self.servers.items.len) return null;
        const server = &self.servers.items[server_idx];
        const stdout_file = server.child.stdout orelse return null;

        // Read until newline (JSON-RPC stdio uses newline-delimited JSON)
        var line: std.ArrayList(u8) = .empty;
        var byte_buf: [1]u8 = undefined;

        // Set a timeout by limiting reads
        var total_bytes: usize = 0;
        while (total_bytes < max_response_size) {
            const n = stdout_file.read(&byte_buf) catch return null;
            if (n == 0) break; // EOF
            total_bytes += 1;
            if (byte_buf[0] == '\n') break;
            line.append(self.allocator, byte_buf[0]) catch return null;
        }

        if (line.items.len == 0) {
            line.deinit(self.allocator);
            return null;
        }

        return line.toOwnedSlice(self.allocator) catch null;
    }
};

/// Extract "inputSchema":{...} from a tool definition JSON.
fn extractSchema(data: []const u8, start_pos: usize) ?[]const u8 {
    const needle = "\"inputSchema\":";
    const idx = std.mem.indexOfPos(u8, data, start_pos, needle) orelse return null;
    var pos = idx + needle.len;

    // Skip whitespace
    while (pos < data.len and (data[pos] == ' ' or data[pos] == '\n')) : (pos += 1) {}
    if (pos >= data.len or data[pos] != '{') return null;

    // Match braces
    var depth: u32 = 0;
    var end = pos;
    var in_string = false;
    while (end < data.len) : (end += 1) {
        if (in_string) {
            if (data[end] == '"' and (end == 0 or data[end - 1] != '\\')) in_string = false;
            continue;
        }
        switch (data[end]) {
            '"' => in_string = true,
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return data[pos .. end + 1];
            },
            else => {},
        }
    }
    return null;
}

/// Load MCP server configs from settings.json.
/// Format: {"mcp_servers":{"name":{"command":["cmd","arg"]}}}
pub fn loadMcpConfig(allocator: std.mem.Allocator, settings_json: []const u8) std.ArrayList(ServerConfig) {
    var configs = std.ArrayList(ServerConfig).empty;

    const needle = "\"mcp_servers\":{";
    const start = std.mem.indexOf(u8, settings_json, needle) orelse return configs;
    var pos = start + needle.len;

    // Scan for server entries: "name":{"command":[...]}
    while (pos < settings_json.len and settings_json[pos] != '}') {
        // Find server name
        const name_start_idx = std.mem.indexOfPos(u8, settings_json, pos, "\"") orelse break;
        const name_start = name_start_idx + 1;
        var name_end = name_start;
        while (name_end < settings_json.len and settings_json[name_end] != '"') : (name_end += 1) {}
        const name = settings_json[name_start..name_end];

        // Find "command":["...","..."]
        const cmd_needle = "\"command\":[";
        const cmd_idx = std.mem.indexOfPos(u8, settings_json, name_end, cmd_needle) orelse break;
        var cmd_pos = cmd_idx + cmd_needle.len;

        var args = std.ArrayList([]const u8).empty;
        while (cmd_pos < settings_json.len and settings_json[cmd_pos] != ']') {
            if (settings_json[cmd_pos] == '"') {
                const arg_start = cmd_pos + 1;
                var arg_end = arg_start;
                while (arg_end < settings_json.len and settings_json[arg_end] != '"') : (arg_end += 1) {}
                args.append(allocator, settings_json[arg_start..arg_end]) catch break;
                cmd_pos = arg_end + 1;
            } else {
                cmd_pos += 1;
            }
        }

        if (args.items.len > 0) {
            configs.append(allocator, .{
                .name = name,
                .command = args.toOwnedSlice(allocator) catch &.{},
            }) catch |err| {
                std.log.warn("mcp_client: failed to append server config {s}: {}", .{ name, err });
            };
        } else {
            args.deinit(allocator);
        }

        // Move past this server block
        pos = cmd_pos + 1;
        // Skip to next server or end
        while (pos < settings_json.len and settings_json[pos] != '"' and settings_json[pos] != '}') : (pos += 1) {}
    }

    return configs;
}

pub const ServerConfig = struct {
    name: []const u8,
    command: []const []const u8,
};
