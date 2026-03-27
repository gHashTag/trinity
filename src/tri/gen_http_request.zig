//! tri/http_request — HTTP request builder
//! TTT Dogfood v0.2 Stage 252

const std = @import("std");

pub const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
    headers: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, method: []const u8, path: []const u8) !HttpRequest {
        const headers = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        return .{
            .method = method,
            .path = path,
            .headers = headers,
            .allocator = allocator,
        };
    }

    pub fn addHeader(req: *HttpRequest, name: []const u8, value: []const u8) !void {
        try req.headers.append(req.allocator, name);
        try req.headers.append(req.allocator, value);
    }

    pub fn deinit(req: *HttpRequest) void {
        req.headers.deinit(req.allocator);
    }
};

test "http request init" {
    var req = try HttpRequest.init(std.testing.allocator, "GET", "/");
    defer req.deinit();
    try std.testing.expectEqualSlices(u8, "GET", req.method);
}
