//! Logging for AGENT MU
//!
//! Records successful fixes and unfixable errors to Ralph memory files.

const std = @import("std");
const ArrayListManaged = std.array_list.AlignedManaged;
const diagnostic = @import("diagnostic.zig");

/// Log a successful fix to SUCCESS_HISTORY.md
///
/// Parameters:
///   - allocator: Memory allocator
///   - err_info: The error that was fixed
///   - fix_description: Description of what fix was applied
///   - files_modified: List of files that were modified
pub fn logSuccess(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
    fix_description: []const u8,
    files_modified: [][]const u8,
) !void {
    const history_file = ".ralph/memory/SUCCESS_HISTORY.md";

    // Get current timestamp
    const timestamp = try getTimestamp(allocator);
    defer allocator.free(timestamp);

    // Build file list string
    var files_str = ArrayListManaged(u8, null).init(allocator);
    defer files_str.deinit();
    try files_str.append('[');
    for (files_modified, 0..) |f, i| {
        if (i > 0) {
            try files_str.append(',');
            try files_str.append(' ');
        }
        try files_str.appendSlice(f);
    }
    try files_str.append(']');
    const files_list = try files_str.toOwnedSlice();
    defer allocator.free(files_list);

    // Build entry
    const entry = try std.fmt.allocPrint(allocator,
        \\---
        \\date: {s}
        \\type: feature
        \\files: {s}
        \\branch: ralph/agent-mu-auto
        \\tech_tree: NEXUS-011
        \\status: success
        \\---
        \\### AGENT MU Auto-Fix
        \\
        \\- **Pattern:** {s}
        \\- **What worked:** {s}
        \\- **Lesson:** Auto-fixed at {s}:{}:{}
        \\
    , .{
        timestamp,
        files_list,
        err_info.message,
        fix_description,
        err_info.file,
        err_info.line,
        err_info.column,
    });
    defer allocator.free(entry);

    // Append to SUCCESS_HISTORY.md
    try appendToFile(allocator, history_file, entry);
}

/// Log an unfixable error to REGRESSION_PATTERNS.md
///
/// Parameters:
///   - allocator: Memory allocator
///   - err_info: The error that couldn't be fixed
///   - attempted_fixes: List of fixes that were attempted
pub fn logRegression(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
    attempted_fixes: [][]const u8,
) !void {
    const patterns_file = ".ralph/memory/REGRESSION_PATTERNS.md";

    // Get current timestamp
    const timestamp = try getTimestamp(allocator);
    defer allocator.free(timestamp);

    // Build anti-pattern name from fix type
    const anti_pattern = try std.fmt.allocPrint(allocator, "{s} error", .{
        diagnostic.fixTypeDescription(err_info.fix_type),
    });
    defer allocator.free(anti_pattern);

    // Build attempted fixes list
    var fixes_str = ArrayListManaged(u8, null).init(allocator);
    defer fixes_str.deinit();
    for (attempted_fixes) |fix| {
        try fixes_str.appendSlice("  ");
        try fixes_str.appendSlice(fix);
        try fixes_str.appendSlice("\n");
    }
    const fixes_list = try fixes_str.toOwnedSlice();
    defer allocator.free(fixes_list);

    // Build entry
    const entry = try std.fmt.allocPrint(allocator,
        \\---
        \\date: {s}
        \\anti-pattern: {s}
        \\root-cause: Auto-fix not yet implemented for this error type
        \\---
        \\### {s}
        \\
        \\- **Anti-pattern:** {s}
        \\- **Symptom:** {s}
        \\- **Correct approach:** TBD
        \\- **Files:** {s}:{}:{}
        \\- **Attempted fixes:**
        \\{s}
        \\- **Manual review required:** Yes
        \\
    , .{
        timestamp,
        anti_pattern,
        err_info.code,
        anti_pattern,
        err_info.message,
        err_info.file,
        err_info.line,
        err_info.column,
        fixes_list,
    });
    defer allocator.free(entry);

    // Append to REGRESSION_PATTERNS.md
    try appendToFile(allocator, patterns_file, entry);
}

/// Get current timestamp in ISO 8601 format
fn getTimestamp(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp = std.time.timestamp();

    // Convert to broken-down time
    var epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(timestamp) };
    const epoch_day = epoch.getEpochDay();
    const day_seconds = epoch.getDaySeconds();

    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const year = year_day.year;
    const month = month_day.month;
    const day = month_day.day_index;
    const hour: u8 = @intCast(day_seconds.getHoursIntoDay());
    const minute: u8 = @intCast(day_seconds.getMinutesIntoHour());
    const second: u8 = @intCast(day_seconds.getSecondsIntoMinute());

    return std.fmt.allocPrint(allocator, "{d:04}-{d:02}-{d:02}T{d:02}:{d:02}:{d:02}+00:00", .{
        year,
        @intFromEnum(month),
        day,
        hour,
        minute,
        second,
    });
}

/// Append content to a file, creating it if it doesn't exist
fn appendToFile(_: std.mem.Allocator, file_path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().openFile(file_path, .{ .mode = .write_only });
    defer file.close();

    // Seek to end
    const end_pos = try file.getEndPos();
    try file.seekTo(end_pos);

    // Write content
    try file.writeAll(content);
}
