//! Minimal HTTP Health Endpoint for Railway (v2)
//!
//! Uses std.net.Server instead of raw POSIX sockets.

const std = @import("std");

const PORT = 8080;

/// Health response for Railway + future DePIN consumers
const HealthResponse = struct {
    status: []const u8 = "ok",
    service: []const u8 = "trinity-inference",
    model: []const u8 = "hslm-v30",
    version: []const u8 = "1.0.0",
    uptime_seconds: u64 = 0,
    timestamp: i64 = 0,

    fn toJson(self: *const HealthResponse, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"status":"{s}","service":"{s}","model":"{s}","version":"{s}","uptime_seconds":{d},"timestamp":{d}}}
        , .{ self.status, self.service, self.model, self.version, self.uptime_seconds, self.timestamp });
    }
};

const ErrorResponse = struct {
    err_code: []const u8 = "auth required",
    message: []const u8 = "API key required for inference",

    fn toJson(self: *const ErrorResponse, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"error":"{s}","message":"{s}"}}
        , .{ self.err_code, self.message });
    }
};

pub fn start(allocator: std.mem.Allocator) !void {
    const address = try std.net.Address.parseIp4("0.0.0.0", PORT);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    const start_time = std.time.nanoTimestamp();
    std.log.info("Health endpoint: http://0.0.0.0:{d}/health", .{PORT});

    while (true) {
        const connection = server.accept() catch |err| {
            std.log.err("accept failed: {}", .{err});
            continue;
        };
        defer connection.stream.close();

        var read_buf: [2048]u8 = undefined;
        const n = connection.stream.read(&read_buf) catch |err| {
            std.log.err("read failed: {}", .{err});
            continue;
        };

        const request = read_buf[0..n];

        // Parse first line for GET method and path
        var iter = std.mem.tokenizeScalar(u8, request, ' ');
        const method = iter.next() orelse "";
        const path = iter.next() orelse "";

        var response_body: []const u8 = "";
        var status_code: []const u8 = "200 OK";

        if (std.mem.eql(u8, method, "GET")) {
            if (std.mem.eql(u8, path, "/health")) {
                const health = HealthResponse{
                    .uptime_seconds = @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, std.time.ns_per_s)),
                    .timestamp = @intCast(std.time.nanoTimestamp()),
                };
                response_body = health.toJson(allocator) catch continue;
                status_code = "200 OK";
            } else if (std.mem.eql(u8, path, "/api/v1/infer")) {
                const err_resp = ErrorResponse{};
                response_body = err_resp.toJson(allocator) catch continue;
                status_code = "401 Unauthorized";
            } else {
                response_body = "{\"error\":\"not_found\"}";
                status_code = "404 Not Found";
            }
        } else {
            response_body = "{\"error\":\"method_not_allowed\"}";
            status_code = "405 Method Not Allowed";
        }

        // Send HTTP response
        const header = std.fmt.allocPrint(allocator,
            \\HTTP/1.1 {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\n\r\n
        , .{ status_code, response_body.len }) catch continue;

        _ = connection.stream.writeAll(header) catch {};
        _ = connection.stream.writeAll(response_body) catch {};
        allocator.free(header);
        if (!std.mem.eql(u8, status_code, "200 OK")) {
            allocator.free(response_body);
        }
    }
}
