//! tri/socket_client — TCP socket client
//! TTT Dogfood v0.2 Stage 251

const std = @import("std");

pub const TcpClient = struct {
    stream: std.net.Stream,

    pub fn connect(host: []const u8, port: u16) !TcpClient {
        const address = try std.net.Address.parseIp(host, port);
        const stream = try std.net.tcpConnectToAddress(address);
        return .{ .stream = stream };
    }

    pub fn send(client: *TcpClient, data: []const u8) !usize {
        return client.stream.writeAll(data);
    }

    pub fn recv(client: *TcpClient, buffer: []u8) !usize {
        return client.stream.read(buffer);
    }

    pub fn close(client: *TcpClient) void {
        client.stream.close();
    }
};

test "tcp client init" {
    _ = TcpClient;
}
