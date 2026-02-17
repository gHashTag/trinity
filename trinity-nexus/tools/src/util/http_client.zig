// VIBEE HTTP Client - Pure Zig Implementation
// Uses std.http.Client for HTTPS requests
// Target: OpenAI/Anthropic API calls with quantum speed
// φ² + 1/φ² = 3

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
};

pub const HttpError = error{
    ConnectionFailed,
    TlsHandshakeFailed,
    Timeout,
    InvalidResponse,
    InvalidUrl,
    OutOfMemory,
    RequestFailed,
};

pub const HttpResponse = struct {
    status: u16,
    body: []const u8,
    latency_ns: i64,
    allocator: Allocator,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
    }
};

pub const HttpClient = struct {
    allocator: Allocator,
    client: std.http.Client,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }

    /// Make a GET request
    pub fn get(self: *Self, url: []const u8) HttpError!HttpResponse {
        return self.request(.GET, url, null, null);
    }

    /// Make a PUT request (for Chrome DevTools Protocol)
    pub fn put(self: *Self, url: []const u8) HttpError!HttpResponse {
        return self.request(.PUT, url, null, null);
    }

    /// Make a POST request with JSON body
    pub fn postJson(self: *Self, url: []const u8, body: []const u8, auth_token: ?[]const u8) HttpError!HttpResponse {
        return self.request(.POST, url, body, auth_token);
    }

    /// Make a POST request (simple version)
    pub fn post(self: *Self, url: []const u8, body: []const u8, content_type: []const u8) HttpError!HttpResponse {
        _ = content_type; // Content-Type is set in request()
        return self.request(.POST, url, body, null);
    }

    /// Make a generic HTTP request (Zig 0.15 API)
    pub fn request(
        self: *Self,
        method: HttpMethod,
        url: []const u8,
        body: ?[]const u8,
        auth_token: ?[]const u8,
    ) HttpError!HttpResponse {
        const start_time = std.time.nanoTimestamp();

        const uri = std.Uri.parse(url) catch return HttpError.InvalidUrl;

        // Build extra headers
        var extra_headers_buf: [4]std.http.Header = undefined;
        var extra_headers_len: usize = 0;

        extra_headers_buf[extra_headers_len] = .{ .name = "User-Agent", .value = "VIBEE-Agent/12.0 (Zig)" };
        extra_headers_len += 1;

        extra_headers_buf[extra_headers_len] = .{ .name = "Accept", .value = "application/json" };
        extra_headers_len += 1;

        if (body != null) {
            extra_headers_buf[extra_headers_len] = .{ .name = "Content-Type", .value = "application/json" };
            extra_headers_len += 1;
        }

        if (auth_token) |token| {
            extra_headers_buf[extra_headers_len] = .{ .name = "Authorization", .value = token };
            extra_headers_len += 1;
        }

        var req = self.client.request(
            switch (method) {
                .GET => .GET,
                .POST => .POST,
                .PUT => .PUT,
                .DELETE => .DELETE,
                .PATCH => .PATCH,
            },
            uri,
            .{
                .extra_headers = extra_headers_buf[0..extra_headers_len],
                .redirect_behavior = .unhandled,
            },
        ) catch return HttpError.ConnectionFailed;
        defer req.deinit();

        // Send body if present
        if (body) |b| {
            req.transfer_encoding = .{ .content_length = b.len };
            var body_writer = req.sendBodyUnflushed(&.{}) catch return HttpError.RequestFailed;
            body_writer.writer.writeAll(b) catch return HttpError.RequestFailed;
            body_writer.end() catch return HttpError.RequestFailed;
            if (req.connection) |conn| conn.flush() catch return HttpError.RequestFailed;
        } else {
            req.sendBodiless() catch return HttpError.RequestFailed;
        }

        // Receive response head
        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return HttpError.Timeout;

        // Read response body
        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);

        const response_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return HttpError.OutOfMemory;

        const end_time = std.time.nanoTimestamp();

        return HttpResponse{
            .status = @intFromEnum(response.head.status),
            .body = response_body,
            .latency_ns = @intCast(end_time - start_time),
            .allocator = self.allocator,
        };
    }

    /// Make a POST request with Anthropic-specific headers
    /// Anthropic requires: x-api-key, anthropic-version, content-type
    pub fn postJsonAnthropic(self: *Self, url: []const u8, body: []const u8, api_key: []const u8) HttpError!HttpResponse {
        const start_time = std.time.nanoTimestamp();

        const uri = std.Uri.parse(url) catch return HttpError.InvalidUrl;

        // Anthropic-specific headers
        const extra_headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "VIBEE-Agent/23.3 (Zig)" },
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "x-api-key", .value = api_key },
            .{ .name = "anthropic-version", .value = "2023-06-01" },
        };

        var req = self.client.request(
            .POST,
            uri,
            .{
                .extra_headers = &extra_headers,
                .redirect_behavior = .unhandled,
            },
        ) catch return HttpError.ConnectionFailed;
        defer req.deinit();

        // Send body
        req.transfer_encoding = .{ .content_length = body.len };
        var body_writer = req.sendBodyUnflushed(&.{}) catch return HttpError.RequestFailed;
        body_writer.writer.writeAll(body) catch return HttpError.RequestFailed;
        body_writer.end() catch return HttpError.RequestFailed;
        if (req.connection) |conn| conn.flush() catch return HttpError.RequestFailed;

        // Receive response head
        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return HttpError.Timeout;

        // Read response body
        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);

        const response_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return HttpError.OutOfMemory;

        const end_time = std.time.nanoTimestamp();

        return HttpResponse{
            .status = @intFromEnum(response.head.status),
            .body = response_body,
            .latency_ns = @intCast(end_time - start_time),
            .allocator = self.allocator,
        };
    }
    /// POST with multipart/form-data body (for Whisper audio upload)
    pub fn postMultipart(
        self: *Self,
        url: []const u8,
        file_field_name: []const u8,
        file_name: []const u8,
        file_content_type: []const u8,
        file_data: []const u8,
        extra_fields: []const [2][]const u8,
        auth_token: []const u8,
    ) HttpError!HttpResponse {
        const start_time = std.time.nanoTimestamp();
        const boundary = "----TrinityBoundary2026";

        // Build multipart body
        var body_buf: std.ArrayListUnmanaged(u8) = .{};
        defer body_buf.deinit(self.allocator);
        const w = body_buf.writer(self.allocator);

        // File part
        w.writeAll("--") catch return HttpError.OutOfMemory;
        w.writeAll(boundary) catch return HttpError.OutOfMemory;
        w.writeAll("\r\n") catch return HttpError.OutOfMemory;
        w.writeAll("Content-Disposition: form-data; name=\"") catch return HttpError.OutOfMemory;
        w.writeAll(file_field_name) catch return HttpError.OutOfMemory;
        w.writeAll("\"; filename=\"") catch return HttpError.OutOfMemory;
        w.writeAll(file_name) catch return HttpError.OutOfMemory;
        w.writeAll("\"\r\n") catch return HttpError.OutOfMemory;
        w.writeAll("Content-Type: ") catch return HttpError.OutOfMemory;
        w.writeAll(file_content_type) catch return HttpError.OutOfMemory;
        w.writeAll("\r\n\r\n") catch return HttpError.OutOfMemory;
        w.writeAll(file_data) catch return HttpError.OutOfMemory;
        w.writeAll("\r\n") catch return HttpError.OutOfMemory;

        // Extra string fields
        for (extra_fields) |field| {
            w.writeAll("--") catch return HttpError.OutOfMemory;
            w.writeAll(boundary) catch return HttpError.OutOfMemory;
            w.writeAll("\r\n") catch return HttpError.OutOfMemory;
            w.writeAll("Content-Disposition: form-data; name=\"") catch return HttpError.OutOfMemory;
            w.writeAll(field[0]) catch return HttpError.OutOfMemory;
            w.writeAll("\"\r\n\r\n") catch return HttpError.OutOfMemory;
            w.writeAll(field[1]) catch return HttpError.OutOfMemory;
            w.writeAll("\r\n") catch return HttpError.OutOfMemory;
        }

        // Closing boundary
        w.writeAll("--") catch return HttpError.OutOfMemory;
        w.writeAll(boundary) catch return HttpError.OutOfMemory;
        w.writeAll("--\r\n") catch return HttpError.OutOfMemory;

        // Build content-type header with boundary
        var ct_buf: [128]u8 = undefined;
        const content_type_header = std.fmt.bufPrint(&ct_buf, "multipart/form-data; boundary={s}", .{boundary}) catch return HttpError.OutOfMemory;

        // Build auth header
        var auth_buf: [512]u8 = undefined;
        const auth_header = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{auth_token}) catch return HttpError.OutOfMemory;

        const uri = std.Uri.parse(url) catch return HttpError.InvalidUrl;

        const extra_headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "VIBEE-Agent/23.4 (Zig)" },
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "Content-Type", .value = content_type_header },
            .{ .name = "Authorization", .value = auth_header },
        };

        var req = self.client.request(
            .POST,
            uri,
            .{
                .extra_headers = &extra_headers,
                .redirect_behavior = .unhandled,
            },
        ) catch return HttpError.ConnectionFailed;
        defer req.deinit();

        // Send body
        req.transfer_encoding = .{ .content_length = body_buf.items.len };
        var body_writer = req.sendBodyUnflushed(&.{}) catch return HttpError.RequestFailed;
        body_writer.writer.writeAll(body_buf.items) catch return HttpError.RequestFailed;
        body_writer.end() catch return HttpError.RequestFailed;
        if (req.connection) |conn| conn.flush() catch return HttpError.RequestFailed;

        // Receive response
        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return HttpError.Timeout;

        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const response_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return HttpError.OutOfMemory;

        const end_time = std.time.nanoTimestamp();

        return HttpResponse{
            .status = @intFromEnum(response.head.status),
            .body = response_body,
            .latency_ns = @intCast(end_time - start_time),
            .allocator = self.allocator,
        };
    }
};

test "HttpClient initialization" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();
    try std.testing.expect(true);
}

test "URL parsing" {
    const url = "https://api.openai.com/v1/chat/completions";
    const uri = std.Uri.parse(url) catch unreachable;
    try std.testing.expect(uri.host != null);
}

test "phi constant" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const result = phi * phi + 1.0 / (phi * phi);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}
