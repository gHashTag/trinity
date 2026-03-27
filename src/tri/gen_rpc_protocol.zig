//! tri/rpc_protocol — RPC protocol helpers
//! TTT Dogfood v0.2 Stage 257

const std = @import("std");

pub const RpcRequest = struct {
    id: u64,
    method: []const u8,
    params: []const u8,
};

pub const RpcResponse = struct {
    id: u64,
    result: []const u8,
    err: ?[]const u8,
};

pub fn createRequest(allocator: std.mem.Allocator, id: u64, method: []const u8) !RpcRequest {
    _ = allocator;
    return .{
        .id = id,
        .method = method,
        .params = "",
    };
}

test "rpc request" {
    const req = try createRequest(std.testing.allocator, 1, "test");
    try std.testing.expectEqual(@as(u64, 1), req.id);
}
