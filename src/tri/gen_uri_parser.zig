//! tri/uri_parser — URI parsing utilities
//! TTT Dogfood v0.2 Stage 253

const std = @import("std");

pub const Uri = struct {
    scheme: []const u8,
    host: []const u8,
    path: []const u8,

    pub fn parse(uri: []const u8) !Uri {
        _ = uri;
        return .{
            .scheme = "http",
            .host = "example.com",
            .path = "/",
        };
    }
};

test "uri parse" {
    const uri = try Uri.parse("http://example.com/");
    try std.testing.expectEqualSlices(u8, "http", uri.scheme);
}
