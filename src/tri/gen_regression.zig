//! tri/regression — Regression test suite
//! TTT Dogfood v0.2 Stage 310

const std = @import("std");

pub const RegressionSuite = struct {
    bugs: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RegressionSuite {
        return .{
            .bugs = std.ArrayList([]const u8).initCapacity(allocator, 8) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn add(suite: *RegressionSuite, bug_id: []const u8) !void {
        const copy = try suite.allocator.dupe(u8, bug_id);
        try suite.bugs.append(suite.allocator, copy);
    }

    pub fn has(suite: *const RegressionSuite, bug_id: []const u8) bool {
        for (suite.bugs.items) |bug| {
            if (std.mem.eql(u8, bug, bug_id)) return true;
        }
        return false;
    }

    pub fn deinit(suite: *RegressionSuite) void {
        for (suite.bugs.items) |bug| {
            suite.allocator.free(bug);
        }
        suite.bugs.deinit(suite.allocator);
    }
};

test "regression" {
    var suite = RegressionSuite.init(std.testing.allocator);
    defer suite.deinit();
    try suite.add("BUG-123");
    try std.testing.expect(suite.has("BUG-123"));
}
