//! TRI Net — Generated from specs/tri/tri_net.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const IpAddress = struct {
    is_v6: bool,
    bytes: [16]u8,
};

pub const SocketAddr = struct {
    ip: IpAddress,
    port: u16,
};

pub fn parseIp(addr: []const u8) ?IpAddress {
    if (std.mem.indexOfScalar(u8, addr, '.')) |_| {
        // IPv4
        var result = IpAddress{ .is_v6 = false, .bytes = [_]u8{0} ** 16 };
        var parts = std.mem.splitScalar(u8, addr, '.');
        var i: usize = 0;
        while (parts.next()) |part| {
            if (std.fmt.parseUnsigned(u8, part, 10)) |byte| {
                result.bytes[i] = byte;
                i += 1;
            } else |_| {}
        }
        return result;
    }
    return null;
}

pub fn isLocalhost(addr: IpAddress) bool {
    if (addr.is_v6) {
        return addr.bytes[0] == 0 and addr.bytes[1] == 0 and addr.bytes[15] == 1;
    }
    return addr.bytes[0] == 127;
}

pub fn isValidPort(port: u16) bool {
    return port > 0 and port <= 65535;
}

test "Net: parseIp IPv4" {
    const ip = parseIp("127.0.0.1").?;
    try std.testing.expect(!ip.is_v6);
    try std.testing.expect(isLocalhost(ip));
}

test "Net: isValidPort" {
    try std.testing.expect(isValidPort(80));
    try std.testing.expect(isValidPort(8080));
    try std.testing.expect(isValidPort(65535));
    try std.testing.expect(!isValidPort(0));
}
