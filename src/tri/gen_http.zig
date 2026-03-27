//! TRI HTTP — Generated from specs/tri/tri_http.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// HTTP methods
pub const HttpMethod = enum(u8) {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
};

/// HTTP status codes
pub const HttpStatus = struct {
    code: u16,
    reason: []const u8,
};

/// Parsed URL components
pub const Url = struct {
    scheme: ?[]const u8,
    host: ?[]const u8,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,

    pub fn deinit(self: *Url, allocator: std.mem.Allocator) void {
        if (self.scheme) |s| allocator.free(s);
        if (self.host) |h| allocator.free(h);
        if (self.query) |q| allocator.free(q);
        if (self.fragment) |f| allocator.free(f);
        if (self.path.len > 0 and @intFromPtr(self.path.ptr) > 0) {
            allocator.free(self.path);
        }
        self.* = undefined;
    }

    pub fn deinitConst(self: *const Url, allocator: std.mem.Allocator) void {
        @as(*Url, @constCast(self)).deinit(allocator);
    }
};

// ============================================================================
// HTTP METHOD
// ============================================================================

/// Convert method to string
pub fn methodToString(method: HttpMethod) []const u8 {
    return switch (method) {
        HttpMethod.GET => "GET",
        HttpMethod.POST => "POST",
        HttpMethod.PUT => "PUT",
        HttpMethod.DELETE => "DELETE",
        HttpMethod.PATCH => "PATCH",
        HttpMethod.HEAD => "HEAD",
        HttpMethod.OPTIONS => "OPTIONS",
    };
}

// ============================================================================
// HTTP STATUS
// ============================================================================

/// Get status info from code
pub fn statusFromCode(code: u16) HttpStatus {
    return switch (code) {
        100 => .{ .code = 100, .reason = "Continue" },
        101 => .{ .code = 101, .reason = "Switching Protocols" },
        200 => .{ .code = 200, .reason = "OK" },
        201 => .{ .code = 201, .reason = "Created" },
        202 => .{ .code = 202, .reason = "Accepted" },
        204 => .{ .code = 204, .reason = "No Content" },
        301 => .{ .code = 301, .reason = "Moved Permanently" },
        302 => .{ .code = 302, .reason = "Found" },
        304 => .{ .code = 304, .reason = "Not Modified" },
        307 => .{ .code = 307, .reason = "Temporary Redirect" },
        308 => .{ .code = 308, .reason = "Permanent Redirect" },
        400 => .{ .code = 400, .reason = "Bad Request" },
        401 => .{ .code = 401, .reason = "Unauthorized" },
        403 => .{ .code = 403, .reason = "Forbidden" },
        404 => .{ .code = 404, .reason = "Not Found" },
        405 => .{ .code = 405, .reason = "Method Not Allowed" },
        409 => .{ .code = 409, .reason = "Conflict" },
        429 => .{ .code = 429, .reason = "Too Many Requests" },
        500 => .{ .code = 500, .reason = "Internal Server Error" },
        502 => .{ .code = 502, .reason = "Bad Gateway" },
        503 => .{ .code = 503, .reason = "Service Unavailable" },
        else => .{ .code = code, .reason = "Unknown" },
    };
}

/// Check if status is 2xx
pub fn isSuccess(code: u16) bool {
    return code >= 200 and code < 300;
}

/// Check if status is 3xx
pub fn isRedirect(code: u16) bool {
    return code >= 300 and code < 400;
}

/// Check if status is 4xx
pub fn isClientError(code: u16) bool {
    return code >= 400 and code < 500;
}

/// Check if status is 5xx
pub fn isServerError(code: u16) bool {
    return code >= 500 and code < 600;
}

// ============================================================================
// URL PARSING
// ============================================================================

/// Parse URL into components
pub fn parseUrl(allocator: std.mem.Allocator, url_str: []const u8) !Url {
    var result = Url{
        .scheme = null,
        .host = null,
        .port = null,
        .path = "",
        .query = null,
        .fragment = null,
    };

    var rest = url_str;

    // Parse scheme
    if (std.mem.indexOf(u8, rest, "://")) |scheme_end| {
        const scheme_str = rest[0..scheme_end];
        result.scheme = try allocator.dupe(u8, scheme_str);
        rest = rest[scheme_end + 3 ..];
    }

    // Parse fragment
    if (std.mem.indexOf(u8, rest, "#")) |frag_idx| {
        const frag_str = rest[frag_idx + 1 ..];
        result.fragment = try allocator.dupe(u8, frag_str);
        rest = rest[0..frag_idx];
    }

    // Parse query
    if (std.mem.indexOf(u8, rest, "?")) |query_idx| {
        const query_str = rest[query_idx + 1 ..];
        result.query = try allocator.dupe(u8, query_str);
        rest = rest[0..query_idx];
    }

    // Parse path
    const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
    if (path_start < rest.len) {
        const path_str = rest[path_start..];
        result.path = try allocator.dupe(u8, path_str);
        rest = rest[0..path_start];
    } else {
        result.path = try allocator.dupe(u8, "/");
    }

    // Parse host and port
    const colon_idx = std.mem.lastIndexOf(u8, rest, ":");
    if (colon_idx) |idx| {
        // Has port
        const host_str = rest[0..idx];
        if (host_str.len > 0) {
            result.host = try allocator.dupe(u8, host_str);
        }
        const port_str = rest[idx + 1 ..];
        result.port = try std.fmt.parseUnsigned(u16, port_str, 10);
    } else {
        // No port
        if (rest.len > 0) {
            result.host = try allocator.dupe(u8, rest);
        }
    }

    return result;
}

// ============================================================================
// TESTS
// ============================================================================

test "HTTP: methodToString" {
    try std.testing.expectEqualStrings("GET", methodToString(HttpMethod.GET));
    try std.testing.expectEqualStrings("POST", methodToString(HttpMethod.POST));
    try std.testing.expectEqualStrings("DELETE", methodToString(HttpMethod.DELETE));
}

test "HTTP: statusFromCode" {
    const s200 = statusFromCode(200);
    try std.testing.expectEqual(@as(u16, 200), s200.code);
    try std.testing.expectEqualStrings("OK", s200.reason);

    const s404 = statusFromCode(404);
    try std.testing.expectEqual(@as(u16, 404), s404.code);
    try std.testing.expectEqualStrings("Not Found", s404.reason);

    const s999 = statusFromCode(999);
    try std.testing.expectEqual(@as(u16, 999), s999.code);
    try std.testing.expectEqualStrings("Unknown", s999.reason);
}

test "HTTP: isSuccess" {
    try std.testing.expect(isSuccess(200));
    try std.testing.expect(isSuccess(204));
    try std.testing.expect(isSuccess(299));
    try std.testing.expect(!isSuccess(199));
    try std.testing.expect(!isSuccess(300));
    try std.testing.expect(!isSuccess(400));
}

test "HTTP: isRedirect" {
    try std.testing.expect(isRedirect(301));
    try std.testing.expect(isRedirect(302));
    try std.testing.expect(isRedirect(399));
    try std.testing.expect(!isRedirect(299));
    try std.testing.expect(!isRedirect(400));
}

test "HTTP: isClientError" {
    try std.testing.expect(isClientError(400));
    try std.testing.expect(isClientError(404));
    try std.testing.expect(isClientError(499));
    try std.testing.expect(!isClientError(399));
    try std.testing.expect(!isClientError(500));
}

test "HTTP: isServerError" {
    try std.testing.expect(isServerError(500));
    try std.testing.expect(isServerError(503));
    try std.testing.expect(isServerError(599));
    try std.testing.expect(!isServerError(499));
    try std.testing.expect(!isServerError(600));
}

test "HTTP: parseUrl simple" {
    const allocator = std.testing.allocator;
    const url = try parseUrl(allocator, "https://example.com/path");
    defer url.deinitConst(allocator);

    try std.testing.expectEqualStrings("https", url.scheme.?);
    try std.testing.expectEqualStrings("example.com", url.host.?);
    try std.testing.expectEqualStrings("/path", url.path);
}

test "HTTP: parseUrl with port" {
    const allocator = std.testing.allocator;
    const url = try parseUrl(allocator, "http://localhost:8080/api");
    defer url.deinitConst(allocator);

    try std.testing.expectEqualStrings("http", url.scheme.?);
    try std.testing.expectEqualStrings("localhost", url.host.?);
    try std.testing.expectEqual(@as(u16, 8080), url.port.?);
}

test "HTTP: parseUrl with query and fragment" {
    const allocator = std.testing.allocator;
    const url = try parseUrl(allocator, "https://example.com/path?key=value#section");
    defer url.deinitConst(allocator);

    try std.testing.expectEqualStrings("key=value", url.query.?);
    try std.testing.expectEqualStrings("section", url.fragment.?);
    try std.testing.expectEqualStrings("/path", url.path);
}
