//! tri/url — URL parsing and encoding
//! Auto-generated from specs/tri/tri_url.tri
//! TTT Dogfood v0.2 Stage 104

const std = @import("std");

/// Parsed URL
pub const Url = struct {
    scheme: []const u8 = "",
    host: []const u8 = "",
    port: ?u16 = null,
    path: []const u8 = "",
    query: []const u8 = "",
    fragment: []const u8 = "",

    /// Free owned resources
    pub fn deinit(self: *Url, allocator: std.mem.Allocator) void {
        if (self.scheme.len > 0) allocator.free(self.scheme);
        if (self.host.len > 0) allocator.free(self.host);
        if (self.path.len > 0) allocator.free(self.path);
        if (self.query.len > 0) allocator.free(self.query);
        if (self.fragment.len > 0) allocator.free(self.fragment);
    }
};

/// Parse URL string (simplified)
pub fn parse(str: []const u8, allocator: std.mem.Allocator) !Url {
    var result = Url{};

    // Find scheme
    const colon_idx = std.mem.indexOfScalar(u8, str, ':') orelse return result;
    if (colon_idx > 0 and std.mem.eql(u8, str[colon_idx..][0..3], "://")) {
        result.scheme = try allocator.dupe(u8, str[0..colon_idx]);
        var rest_idx = colon_idx + 3;

        // Find host (until / or :)
        var host_end = rest_idx;
        while (host_end < str.len and str[host_end] != '/' and str[host_end] != ':') : (host_end += 1) {}
        result.host = try allocator.dupe(u8, str[rest_idx..host_end]);
        rest_idx = host_end;

        // Parse port
        if (rest_idx < str.len and str[rest_idx] == ':') {
            const port_start = rest_idx + 1;
            var port_end = port_start;
            while (port_end < str.len and str[port_end] != '/' and str[port_end] != '?' and str[port_end] != '#') : (port_end += 1) {}
            const port_str = str[port_start..port_end];
            result.port = std.fmt.parseUnsigned(u16, port_str, 10) catch null;
            rest_idx = port_end;
        }

        // Parse path, query, fragment
        if (rest_idx < str.len and str[rest_idx] == '/') {
            const path_end = if (std.mem.indexOfScalarPos(u8, str, '?', rest_idx)) |q| q else if (std.mem.indexOfScalarPos(u8, str, '#', rest_idx)) |h| h else str.len;
            result.path = try allocator.dupe(u8, str[rest_idx..path_end]);
            rest_idx = path_end;
        }
    }

    return result;
}

/// Percent-encode component
pub fn encode(component: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, component.len * 3);
    for (component) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or
            c == '-' or c == '_' or c == '.' or c == '~')
        {
            try result.append(allocator, c);
        } else {
            try result.append(allocator, '%');
            const hex_chars = "0123456789ABCDEF";
            try result.append(allocator, hex_chars[c >> 4]);
            try result.append(allocator, hex_chars[c & 0x0F]);
        }
    }
    return result.toOwnedSlice(allocator);
}

/// Percent-decode string
pub fn decode(encoded: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, encoded.len);
    var i: usize = 0;
    while (i < encoded.len) {
        if (encoded[i] == '%' and i + 2 < encoded.len) {
            const hi = std.fmt.charToDigit(encoded[i + 1], 16) catch return error.InvalidHex;
            const lo = std.fmt.charToDigit(encoded[i + 2], 16) catch return error.InvalidHex;
            try result.append(allocator, @as(u8, hi * 16 + lo));
            i += 3;
        } else {
            try result.append(allocator, encoded[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice(allocator);
}

test "encode" {
    const result = try encode("hello world", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expect(!std.mem.eql(u8, "hello world", result));
}

test "decode" {
    const encoded = "hello%20world";
    const result = try decode(encoded, std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, "hello world", result);
}
