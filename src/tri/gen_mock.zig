//! tri/mock — Mock objects
//! TTT Dogfood v0.2 Stage 302

const std = @import("std");

pub const Mock = struct {
    calls: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Mock {
        return .{
            .calls = std.ArrayList([]const u8).initCapacity(allocator, 8) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn record(mock: *Mock, method: []const u8) !void {
        const copy = try mock.allocator.dupe(u8, method);
        try mock.calls.append(mock.allocator, copy);
    }

    pub fn wasCalled(mock: *const Mock, method: []const u8) bool {
        for (mock.calls.items) |call| {
            if (std.mem.eql(u8, call, method)) return true;
        }
        return false;
    }

    pub fn deinit(mock: *Mock) void {
        for (mock.calls.items) |call| {
            mock.allocator.free(call);
        }
        mock.calls.deinit(mock.allocator);
    }
};

test "mock" {
    var mock = Mock.init(std.testing.allocator);
    defer mock.deinit();
    try mock.record("foo");
    try std.testing.expect(mock.wasCalled("foo"));
}
