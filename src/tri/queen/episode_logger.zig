const std = @import("std");
const EpisodeRequest = @import("episode_handler.zig").EpisodeRequest;

pub const EpisodeLogger = struct {
    logs_dir: []const u8,

    pub fn init(logs_dir: []const u8) EpisodeLogger {
        return .{ .logs_dir = logs_dir };
    }

    pub fn log(self: *EpisodeLogger, allocator: std.mem.Allocator, ep: EpisodeRequest) !void {
        // Create directory if missing
        std.fs.cwd().makePath(self.logs_dir) catch {};

        // Build path: .trinity/logs/agent-gamma.jsonl
        var path_buf: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/agent-{s}.jsonl", .{
            self.logs_dir,
            ep.agent,
        });

        // Open file for append (create if not exists, preserve if exists)
        const file = blk: {
            const f = std.fs.cwd().openFile(path, .{}) catch {
                // File doesn't exist, create it
                std.fs.cwd().makePath(self.logs_dir) catch {};
                break :blk try std.fs.cwd().createFile(path, .{});
            };
            break :blk f;
        };
        defer file.close();
        try file.seekFromEnd(0);

        // Write JSON + newline using Stringify API
        const json_str = try std.json.Stringify.valueAlloc(allocator, ep, .{});
        defer allocator.free(json_str);
        try file.writeAll(json_str);
        try file.writeAll("\n");
    }
};
