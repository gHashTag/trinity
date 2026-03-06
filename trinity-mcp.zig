//! Trinity MCP Server - Zig implementation
const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = MCPServer.init(allocator);
    try server.run();
}

const MCPServer = struct {
    allocator: std.mem.Allocator,
    buffer: [16384]u8,
    buffer_used: usize,

    fn init(allocator: std.mem.Allocator) MCPServer {
        return .{
            .allocator = allocator,
            .buffer = undefined,
            .buffer_used = 0,
        };
    }

    fn run(self: *MCPServer) !void {
        self.buffer_used = 0;

        while (true) {
            // Read more data
            const bytes = posix.read(0, self.buffer[self.buffer_used..]) catch |err| {
                if (err == error.EndOfStream) break;
                continue;
            };
            if (bytes == 0) break; // EOF
            self.buffer_used += bytes;

            // Process all complete messages
            while (try self.processOneMessage()) {}
        }
    }

    fn processOneMessage(self: *MCPServer) !bool {
        // Skip leading whitespace
        while (self.buffer_used > 0) {
            const c = self.buffer[0];
            if (c == ' ' or c == '\n' or c == '\r' or c == '\t') {
                std.mem.copyForwards(u8, self.buffer[0 .. self.buffer_used - 1], self.buffer[1..self.buffer_used]);
                self.buffer_used -= 1;
            } else {
                break;
            }
        }

        if (self.buffer_used == 0) return false;

        // Try Content-Length header format first
        if (try self.processWithHeaders()) |has_more| return has_more;

        // Fallback: raw JSON without headers
        return self.processRawJson();
    }

    fn processWithHeaders(self: *MCPServer) !?bool {
        var content_length: ?usize = null;
        var header_end: usize = 0;
        var offset: usize = 0;

        // Parse headers line by line
        while (offset < self.buffer_used) {
            // Find end of current line
            var line_end = offset;
            while (line_end < self.buffer_used and self.buffer[line_end] != '\n') {
                line_end += 1;
            }

            // Extract line (without \r)
            var line = self.buffer[offset..line_end];
            if (line.len > 0 and line[line.len - 1] == '\r') {
                line = line[0 .. line.len - 1];
            }

            offset = line_end + 1; // Move past \n

            // Empty line = end of headers
            if (line.len == 0) {
                header_end = offset;
                break;
            }

            // Check for Content-Length header
            if (line.len > "Content-Length:".len) {
                const header_name = line[0.."Content-Length".len];
                // Case-insensitive compare
                var matches = true;
                for (header_name, "Content-Length") |c, expected| {
                    if (std.ascii.toLower(c) != std.ascii.toLower(expected)) {
                        matches = false;
                        break;
                    }
                }
                if (matches and line.len > "Content-Length:".len and line["Content-Length".len] == ':') {
                    const value = std.mem.trim(u8, line["Content-Length:".len + 1 ..], " \t");
                    content_length = std.fmt.parseInt(usize, value, 10) catch null;
                }
            }
        }

        if (content_length) |length| {
            // Check if we have the full message
            if (header_end + length > self.buffer_used) {
                return null; // Need more data
            }

            const body = self.buffer[header_end .. header_end + length];
            try self.handleMessage(body);

            // Remove processed message
            const total_len = header_end + length;
            const remaining = self.buffer_used - total_len;
            if (remaining > 0) {
                std.mem.copyForwards(u8, self.buffer[0..remaining], self.buffer[total_len..]);
            }
            self.buffer_used = remaining;
            return remaining > 0;
        }

        return null; // No Content-Length found
    }

    fn processRawJson(self: *MCPServer) !bool {
        const msg_end = self.findJsonEnd() orelse return false;
        const body = self.buffer[0..msg_end];
        try self.handleMessage(body);

        const remaining = self.buffer_used - msg_end;
        if (remaining > 0) {
            std.mem.copyForwards(u8, self.buffer[0..remaining], self.buffer[msg_end..]);
        }
        self.buffer_used = remaining;
        return remaining > 0;
    }

    fn findJsonEnd(self: *const MCPServer) ?usize {
        var brace_count: usize = 0;
        var in_string = false;
        var escape_next = false;

        for (self.buffer[0..self.buffer_used], 0..) |byte, i| {
            if (escape_next) {
                escape_next = false;
                continue;
            }
            if (byte == '\\') {
                escape_next = true;
                continue;
            }
            if (byte == '"') {
                in_string = !in_string;
                continue;
            }
            if (!in_string and byte == '{') {
                brace_count += 1;
            }
            if (!in_string and byte == '}') {
                if (brace_count == 0) return null;
                brace_count -= 1;
                if (brace_count == 0) return i + 1;
            }
        }
        return null;
    }

    fn handleMessage(self: *MCPServer, body: []const u8) !void {
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        ) catch return;
        defer parsed.deinit();

        const obj = parsed.value.object;
        const id_val = obj.get("id");

        // Check if notification (no id field)
        if (id_val == null) return; // Don't respond to notifications

        const method = obj.get("method").?.string;
        const id_str = blk: {
            switch (id_val.?) {
                .integer => |i| {
                    break :blk try std.fmt.allocPrint(self.allocator, "{d}", .{i});
                },
                .string => |s| {
                    break :blk try self.allocator.dupe(u8, s);
                },
                else => {
                    break :blk try self.allocator.dupe(u8, "0");
                },
            }
        };
        defer self.allocator.free(id_str);

        // Build and send response
        const response = try self.buildResponse(method, id_str);
        defer self.allocator.free(response);

        const header = try std.fmt.allocPrint(
            self.allocator,
            "Content-Length: {d}\r\n\r\n",
            .{response.len}
        );
        defer self.allocator.free(header);

        _ = try posix.write(1, header);
        _ = try posix.write(1, response);
    }

    fn buildResponse(self: *MCPServer, method: []const u8, id_str: []const u8) ![]const u8 {
        if (std.mem.eql(u8, method, "initialize")) {
            return std.fmt.allocPrint(
                self.allocator,
                \\{{"jsonrpc":"2.0","id":"{s}","result":{{"protocolVersion":"2024-11-05","capabilities":{{"tools":{{}}}},"serverInfo":{{"name":"Trinity","version":"1.0"}}}}}}
            , .{id_str});
        }

        if (std.mem.eql(u8, method, "tools/list")) {
            return self.buildToolsList(id_str);
        }

        if (std.mem.eql(u8, method, "tools/call")) {
            return std.fmt.allocPrint(
                self.allocator,
                \\{{"jsonrpc":"2.0","id":"{s}","result":{{"content":[{{"type":"text","text":"Tool call received"}}]}}}}
            , .{id_str});
        }

        return std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":"{s}","result":{{}}}}
        , .{id_str});
    }

    fn buildToolsList(self: *MCPServer, id_str: []const u8) ![]const u8 {
        const tools =
            \\[
            \\  {{"name":"echo","description":"Echo back the input text","inputSchema":{{"type":"object","properties":{{"text":{{"type":"string"}}}},"required":["text"]}}}}
            \\, {{"name":"trinity_info","description":"Get information about Trinity","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\, {{"name":"phi_power","description":"Compute φ^n (phi to the power of n)","inputSchema":{{"type":"object","properties":{{"n":{{"type":"integer"}}}},"required":["n"]}}}}
            \\, {{"name":"fibonacci","description":"Compute n-th Fibonacci number","inputSchema":{{"type":"object","properties":{{"n":{{"type":"integer"}}}},"required":["n"]}}}}
            \\, {{"name":"lucas","description":"Compute n-th Lucas number","inputSchema":{{"type":"object","properties":{{"n":{{"type":"integer"}}}},"required":["n"]}}}}
            \\, {{"name":"tri_commands","description":"List all TRI commands","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\, {{"name":"sacred_constants","description":"Display sacred mathematical constants","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\, {{"name":"trinity_status","description":"Get git status","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\, {{"name":"list_vibee_specs","description":"List all .vibee files","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\, {{"name":"run_vibee","description":"Compile .vibee to Zig","inputSchema":{{"type":"object","properties":{{"spec_file":{{"type":"string"}}}},"required":["spec_file"]}}}}
            \\, {{"name":"vibee_help","description":"VIBEE compiler help","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\, {{"name":"element_info","description":"Get chemical element info","inputSchema":{{"type":"object","properties":{{"symbol_or_number":{{"type":"string"}}}},"required":["symbol_or_number"]}}}}
            \\, {{"name":"molar_mass","description":"Calculate molar mass","inputSchema":{{"type":"object","properties":{{"formula":{{"type":"string"}}}},"required":["formula"]}}}}
            \\, {{"name":"trinity_version","description":"Get Trinity version","inputSchema":{{"type":"object","properties":{{}}}}}}
            \\]
        ;

        return std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc":"2.0","id":"{s}","result":{{"tools":{s}}}}}
        , .{ id_str, tools });
    }
};
