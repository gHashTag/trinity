// Simple standalone API server for fly.io
// Bypasses CLI initialization to avoid tvc_corpus segfault

const std = @import("std");

pub fn main() !void {
    // Get port from env or use default
    const port_str = std.process.getEnvVarOwned(std.heap.page_allocator, "PORT") catch "8080";
    const port = std.fmt.parseInt(u16, port_str, 10) catch 8080;

    // Create TCP listener
    const address = try std.net.Address.parseIp("0.0.0.0", port);
    var listener = try address.listen(.{ .reuse_address = true });

    std.debug.print("TRINITY API Server listening on port {d}...\n", .{port});

    // Simple accept loop
    var buffer: [4096]u8 = undefined;
    while (true) {
        const connection = listener.accept() catch |err| {
            std.debug.print("Accept error: {}\n", .{err});
            continue;
        };

        // Handle in loop (would spawn thread in real server)
        var conn = connection;
        defer conn.stream.close();

        const request = conn.stream.read(&buffer) catch |err| {
            std.debug.print("Read error: {}\n", .{err});
            continue;
        };

        // Simple health check response
        const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\",\"service\":\"trinity-api\"}\r\n";
        _ = conn.stream.writeAll(response) catch {};

        // Log request
        const request_str = buffer[0..request];
        if (std.mem.indexOf(u8, request_str, "GET / ") != null) {
            std.debug.print("Health check OK\n", .{});
        }
    }
}
