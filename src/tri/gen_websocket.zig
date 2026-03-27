//! tri/websocket — WebSocket protocol placeholder
//! TTT Dogfood v0.2 Stage 259

const std = @import("std");

pub const WebSocket = struct {
    state: enum { open, closed },

    pub fn init() WebSocket {
        return .{ .state = .open };
    }

    pub fn send(ws: *WebSocket, data: []const u8) !void {
        _ = data;
        if (ws.state == .closed) return error.Closed;
    }

    pub fn close(ws: *WebSocket) void {
        ws.state = .closed;
    }
};

test "websocket" {
    var ws = WebSocket.init();
    try ws.send("hello");
    ws.close();
}
