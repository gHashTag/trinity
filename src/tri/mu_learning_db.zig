// @origin(spec:mu_learning_db.tri) @regen(manual-impl)
// MU LEARNING DB — Pattern database with hippocampus dual-write
const std = @import("std");
const Allocator = std.mem.Allocator;
const hippocampus = @import("hippocampus.zig");

const DB_PATH = ".trinity/mu/learning_db.json";

pub const AutoFixRule = struct {
    id: []const u8,
    pattern: []const u8,
    replacement: []const u8,
    category: []const u8,
    description: []const u8,
    apply_count: usize,
    success_count: usize,
};

/// Save DB to file + hippocampus dual-write.
pub fn saveDB(allocator: Allocator, rules: []const AutoFixRule) !void {
    std.fs.cwd().makePath(".trinity/mu") catch {};
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("[\n");
    for (rules, 0..) |rule, i| {
        try w.print("  {{\"id\":\"{s}\",\"pattern\":\"{s}\",\"replacement\":\"{s}\"", .{ rule.id, rule.pattern, rule.replacement });
        try w.print(",\"category\":\"{s}\",\"description\":\"{s}\",\"apply_count\":{d},\"success_count\":{d}}}\n", .{ rule.category, rule.description, rule.apply_count, rule.success_count });
    }
    try w.writeAll("]\n");
    const json = try buf.toOwnedSlice(allocator);
    defer allocator.free(json);
    const file = try std.fs.cwd().createFile(DB_PATH, .{});
    defer file.close();
    try file.writeAll(json);

    // Hippocampus dual-write
    var record: hippocampus.MemoryRecord = undefined;
    const ts: u64 = @intCast(std.time.timestamp());
    hippocampus.generateId(&record.id_buf, &record.id_len, ts, "mu_pattern");
    hippocampus.copyToFixed(32, &record.agent_buf, &record.agent_len, "mu_pattern");
    record.kind = .learning;
    record.ts = ts;
    record.ttl = 0;
    hippocampus.copyToFixed(256, &record.summary_buf, &record.summary_len, "Pattern DB update");
    hippocampus.copyToFixed(2048, &record.data_buf, &record.data_len, json);
    const tags = [2][]const u8{ "mu", "pattern_db" };
    std.mem.copyForwards(u8, record.tags[0][0..tags[0].len], tags[0]);
    std.mem.copyForwards(u8, record.tags[1][0..tags[1].len], tags[1]);
    record.tag_count = 2;
    record.tag_lens[0] = @intCast(tags[0].len);
    record.tag_lens[1] = @intCast(tags[1].len);
    hippocampus.write(allocator, &record) catch {};
}

/// Apply fixes + hippocampus dual-write.
pub fn applyFixes(allocator: Allocator, fixes_made: usize, total_errors: usize) !void {
    // Hippocampus dual-write
    var record: hippocampus.MemoryRecord = undefined;
    const ts: u64 = @intCast(std.time.timestamp());
    hippocampus.generateId(&record.id_buf, &record.id_len, ts, "mu_fix");
    hippocampus.copyToFixed(32, &record.agent_buf, &record.agent_len, "mu");
    record.kind = .learning;
    record.ts = ts;
    record.ttl = 0;
    const summary = try std.fmt.allocPrint(allocator, "Auto-fix: {d}/{d}", .{ fixes_made, total_errors });
    defer allocator.free(summary);
    hippocampus.copyToFixed(256, &record.summary_buf, &record.summary_len, summary);
    const data = try std.fmt.allocPrint(allocator, "{{\"fixes\":{d},\"errors\":{d}}}", .{ fixes_made, total_errors });
    defer allocator.free(data);
    hippocampus.copyToFixed(2048, &record.data_buf, &record.data_len, data);
    const tags = [2][]const u8{ "mu", "auto_fix" };
    std.mem.copyForwards(u8, record.tags[0][0..tags[0].len], tags[0]);
    std.mem.copyForwards(u8, record.tags[1][0..tags[1].len], tags[1]);
    record.tag_count = 2;
    record.tag_lens[0] = @intCast(tags[0].len);
    record.tag_lens[1] = @intCast(tags[1].len);
    hippocampus.write(allocator, &record) catch {};
}

pub fn runMuLearnCommand(allocator: Allocator) !void {
    _ = allocator;
    std.debug.print("\n\x1b[33m🧠 MU LEARN\x1b[0m\n", .{});
}

pub fn runMuFixCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("\n\x1b[33m🧠 MU FIX\x1b[0m\n", .{});
}
