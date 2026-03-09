// handover.zig — Read/write .ralph/HANDOVER.md between agent sessions
const std = @import("std");

/// Read HANDOVER.md content. Returns null if not found.
pub fn read(allocator: std.mem.Allocator, project_root: []const u8) ?[]const u8 {
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/HANDOVER.md", .{project_root}) catch return null;
    return std.fs.cwd().readFileAlloc(allocator, path, 32768) catch null;
}

/// Write emergency handover when the agent session didn't produce one.
pub fn writeEmergency(allocator: std.mem.Allocator, project_root: []const u8, wake_count: u32, issue: ?[]const u8) !void {
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/HANDOVER.md", .{project_root}) catch return error.PathTooLong;

    const issue_str = issue orelse "unknown";

    var ts_buf: [32]u8 = undefined;
    const ts = timestamp(&ts_buf);

    const content = try std.fmt.allocPrint(allocator,
        \\# HANDOVER (Emergency — auto-generated)
        \\
        \\## Timestamp
        \\{s}
        \\
        \\## Wake #{d}
        \\
        \\## Current Issue
        \\{s}
        \\
        \\## Status
        \\Session ended without writing handover. Check logs.
        \\
        \\## Next Steps
        \\- Review `.ralph/logs/` for last session output
        \\- Continue from where previous session left off
        \\
    , .{ ts, wake_count, issue_str });
    defer allocator.free(content);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}

fn timestamp(buf: []u8) []const u8 {
    const epoch_s: u64 = @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_s));
    const es = std.time.epoch.EpochSeconds{ .secs = epoch_s };
    const day = es.getDaySeconds();
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        yd.year,               @intFromEnum(md.month),   md.day_index + 1,
        day.getHoursIntoDay(), day.getMinutesIntoHour(), day.getSecondsIntoMinute(),
    }) catch "unknown";
}

test "read returns null for missing file" {
    const result = read(std.testing.allocator, "/nonexistent");
    try std.testing.expect(result == null);
}
