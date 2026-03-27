//! tri/dns_resolver — DNS resolution placeholder
//! TTT Dogfood v0.2 Stage 260

const std = @import("std");

pub const DnsRecord = struct {
    name: []const u8,
    ip: []const u8,
};

pub fn resolve(domain: []const u8, allocator: std.mem.Allocator) !DnsRecord {
    _ = domain;
    const ip = try allocator.alloc(u8, 4);
    return .{
        .name = "example.com",
        .ip = ip,
    };
}

test "dns resolve" {
    const record = try resolve("example.com", std.testing.allocator);
    defer std.testing.allocator.free(record.ip);
    try std.testing.expect(record.name.len > 0);
}
