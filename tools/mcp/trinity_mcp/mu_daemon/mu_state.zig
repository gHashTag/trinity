// mu_state.zig — File-based key-value state for MU agent
// Keys stored as individual files in .trinity/mu/state/
const std = @import("std");

pub const State = struct {
    allocator: std.mem.Allocator,
    state_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, project_root: []const u8) !State {
        const state_dir = try std.fmt.allocPrint(allocator, "{s}/.trinity/mu/state", .{project_root});
        // Ensure directory exists
        std.fs.cwd().makePath(state_dir) catch |err| {
            std.log.warn("mu_state: failed to create state dir: {}", .{err});
        };
        return .{ .allocator = allocator, .state_dir = state_dir };
    }

    pub fn deinit(self: *State) void {
        self.allocator.free(self.state_dir);
    }

    /// Read a state value by key. Returns null if not found.
    pub fn read(self: *const State, key: []const u8) ?[]const u8 {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ self.state_dir, key }) catch return null;
        return std.fs.cwd().readFileAlloc(self.allocator, path, 4096) catch null;
    }

    /// Write a state value by key. Creates or overwrites file.
    pub fn write(self: *const State, key: []const u8, value: []const u8) !void {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ self.state_dir, key }) catch return error.PathTooLong;
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(value);
    }

    /// Read wake_count as integer, defaulting to 0.
    pub fn readWakeCount(self: *const State) u32 {
        const val = self.read("wake_count") orelse return 0;
        defer self.allocator.free(val);
        return std.fmt.parseInt(u32, std.mem.trim(u8, val, &std.ascii.whitespace), 10) catch 0;
    }

    /// Increment and persist wake_count.
    pub fn incrementWakeCount(self: *const State) !u32 {
        const count = self.readWakeCount() + 1;
        var buf: [16]u8 = undefined;
        const val = std.fmt.bufPrint(&buf, "{d}", .{count}) catch return error.FormatError;
        try self.write("wake_count", val);
        return count;
    }
};

test "mu state read/write roundtrip" {
    const allocator = std.testing.allocator;
    var state = try State.init(allocator, "/tmp/mu-test");
    defer state.deinit();

    try state.write("test_key", "test_value");
    const val = state.read("test_key") orelse return error.ReadFailed;
    defer allocator.free(val);
    try std.testing.expectEqualStrings("test_value", val);
}
