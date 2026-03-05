const std = @import("std");
const posix = std.posix;

// Debug helper - writes to stderr (fd 2)
fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    if (std.fmt.bufPrint(&buf, fmt, args)) |msg| {
        _ = posix.write(2, msg) catch {};
    } else |_| {}
}

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var buffer_used: usize = 0;
    var eof_reached = false;
    var msg_count: usize = 0;

    while (true) {
        // Read more data if available
        if (!eof_reached and buffer_used < buffer.len) {
            const bytes = posix.read(0, buffer[buffer_used..]) catch |err| {
                debugPrint("READ ERROR: {}\n", .{err});
                if (err == error.EndOfStream) {
                    eof_reached = true;
                } else {
                    break;
                }
                continue;
            };
            if (bytes == 0) {
                debugPrint("EOF (bytes=0)\n", .{});
                eof_reached = true;
            } else {
                debugPrint("READ {d} bytes\n", .{bytes});
                buffer_used += bytes;
            }
        }

        // Skip leading whitespace
        while (buffer_used > 0 and (buffer[0] == ' ' or buffer[0] == '\n' or buffer[0] == '\r' or buffer[0] == '\t')) {
            std.mem.copyForwards(u8, buffer[0 .. buffer_used - 1], buffer[1 .. buffer_used]);
            buffer_used -= 1;
        }

        if (buffer_used == 0) {
            if (eof_reached) break;
            continue;
        }

        // Need at least '{' to start JSON
        if (buffer[0] != '{') {
            debugPrint("SKIP: {d} (not '{{')\n", .{buffer[0]});
            if (eof_reached) break;
            std.mem.copyForwards(u8, buffer[0 .. buffer_used - 1], buffer[1 .. buffer_used]);
            buffer_used -= 1;
            continue;
        }

        // Find end of JSON object
        var brace_count: usize = 0;
        var in_string = false;
        var escape_next = false;
        var msg_end: usize = 0;
        for (buffer[0..buffer_used], 0..) |byte, i| {
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
            if (!in_string) {
                if (byte == '{') brace_count += 1;
                if (byte == '}') {
                    brace_count -= 1;
                    if (brace_count == 0) {
                        msg_end = i + 1;
                        break;
                    }
                }
            }
        }

        if (msg_end == 0) {
            debugPrint("WAITING for more data (buffer_used={d})\n", .{buffer_used});
            if (eof_reached) break;
            continue;
        }

        const msg = buffer[0..msg_end];
        msg_count += 1;
        debugPrint("MSG #{d}: {s}\n", .{msg_count, msg});

        // Check if this is a notification (no "id" field)
        const is_notification = std.mem.indexOf(u8, msg, "\"id\"") == null;
        debugPrint("is_notification={}\n", .{is_notification});

        // For notifications, just consume and continue
        if (is_notification) {
            debugPrint("NOTIFICATION - no response\n", .{});
            const remaining = buffer_used - msg_end;
            if (remaining > 0) {
                std.mem.copyForwards(u8, buffer[0..remaining], buffer[msg_end..]);
            }
            buffer_used = remaining;
            if (eof_reached and buffer_used == 0) break;
            continue;
        }

        // Extract request id
        const req_id = if (std.mem.indexOf(u8, msg, "\"id\":0")) |_| "0"
                       else if (std.mem.indexOf(u8, msg, "\"id\":1")) |_| "1"
                       else if (std.mem.indexOf(u8, msg, "\"id\":2")) |_| "2"
                       else "0";

        debugPrint("req_id={s}\n", .{req_id});

        // Simple response based on method
        var response: []const u8 = undefined;

        if (std.mem.indexOf(u8, msg, "\"initialize\"") != null) {
            debugPrint("METHOD: initialize\n", .{});
            response = "{\"jsonrpc\":\"2.0\",\"id\":" ++ req_id ++ ",\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"serverInfo\":{\"name\":\"simple-mcp\",\"version\":\"1.0\"}}}";
        } else if (std.mem.indexOf(u8, msg, "\"tools/list\"") != null) {
            debugPrint("METHOD: tools/list\n", .{});
            response = "{\"jsonrpc\":\"2.0\",\"id\":" ++ req_id ++ ",\"result\":{\"tools\":[{\"name\":\"echo\",\"description\":\"Echo tool\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"}}}}]}}";
        } else if (std.mem.indexOf(u8, msg, "\"tools/call\"") != null) {
            debugPrint("METHOD: tools/call\n", .{});
            response = "{\"jsonrpc\":\"2.0\",\"id\":" ++ req_id ++ ",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Hello from simple MCP!\"}]}}";
        } else {
            debugPrint("METHOD: unknown\n", .{});
            response = "{\"jsonrpc\":\"2.0\",\"id\":" ++ req_id ++ ",\"result\":{}}";
        }

        debugPrint("RESPONSE: {s}\n", .{response});

        // Write response
        const header = std.fmt.allocPrint(std.heap.page_allocator, "Content-Length: {d}\r\n\r\n", .{response.len}) catch continue;
        defer std.heap.page_allocator.free(header);
        _ = try posix.write(1, header);
        _ = try posix.write(1, response);
        debugPrint("SENT {d} bytes\n", .{response.len + header.len});

        // Remove processed message from buffer
        const remaining = buffer_used - msg_end;
        if (remaining > 0) {
            std.mem.copyForwards(u8, buffer[0..remaining], buffer[msg_end..]);
        }
        buffer_used = remaining;

        // Exit if EOF and no more data
        if (eof_reached and buffer_used == 0) break;
    }

    debugPrint("EXIT: processed {} messages\n", .{msg_count});
}
