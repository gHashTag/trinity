//! Logging for AGENT MU
//!
//! Records successful fixes and unfixable errors to Ralph memory files.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;
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
    var files_str = ArrayListManaged(u8).init(allocator);
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
    var fixes_str = ArrayListManaged(u8).init(allocator);
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

// ============================================================================
// MUTATION STATISTICS TRACKING v8.12
// ============================================================================

/// Sacred constant for intelligence gain
pub const MU: f64 = 1.0 / (1.618033988749895 * 1.618033988749895) / 10.0; // = 0.0382

/// Mutation statistics tracking
pub const MutationStats = struct {
    total_fixes: u32 = 0,
    successful_fixes: u32 = 0,
    failed_fixes: u32 = 0,
    intelligence_gain: f64 = 0.0, // μ accumulated

    /// Calculate current intelligence gain
    pub fn calculateGain(self: *const MutationStats) f64 {
        return @as(f64, @floatFromInt(self.successful_fixes)) * MU;
    }

    /// Get success rate (0.0 to 1.0)
    pub fn successRate(self: *const MutationStats) f64 {
        if (self.total_fixes == 0) return 0.0;
        return @as(f64, @floatFromInt(self.successful_fixes)) / @as(f64, @floatFromInt(self.total_fixes));
    }

    /// Record a successful fix
    pub fn recordSuccess(self: *MutationStats) void {
        self.total_fixes += 1;
        self.successful_fixes += 1;
        self.intelligence_gain = self.calculateGain();
    }

    /// Record a failed fix
    pub fn recordFailure(self: *MutationStats) void {
        self.total_fixes += 1;
        self.failed_fixes += 1;
    }

    /// Format stats as string
    pub fn format(self: *const MutationStats, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\Mutation Statistics:
            \\  Total fixes: {d}
            \\  Successful: {d}
            \\  Failed: {d}
            \\  Success rate: {d:.1}%
            \\  Intelligence gain (μ): {d:.4}
            \\  Projected intelligence (100 fixes): ×{d:.1}
        , .{
            self.total_fixes,
            self.successful_fixes,
            self.failed_fixes,
            self.successRate() * 100.0,
            self.intelligence_gain,
            // Projected: intelligence × (1 + μ)^100 ≈ intelligence × 47× after 100 fixes
            std.math.pow(f64, 1.0 + MU, 100.0),
        });
    }
};

/// Global mutation statistics (persisted to file)
var global_stats = MutationStats{};

/// Get global mutation statistics
pub fn getGlobalStats() *const MutationStats {
    return &global_stats;
}

/// Record fix result and update global stats
pub fn recordFixResult(success: bool) void {
    if (success) {
        global_stats.recordSuccess();
    } else {
        global_stats.recordFailure();
    }
}

/// Save stats to .ralph/memory/MUTATION_STATS.md
pub fn saveStats(allocator: std.mem.Allocator) !void {
    const stats_file = ".ralph/memory/MUTATION_STATS.md";

    const content = try global_stats.format(allocator);
    defer allocator.free(content);

    // Overwrite file with current stats
    const file = try std.fs.cwd().createFile(stats_file, .{ .read = true });
    defer file.close();

    try file.writeAll(content);
}

/// Load stats from .ralph/memory/MUTATION_STATS.md
pub fn loadStats(allocator: std.mem.Allocator) !void {
    const stats_file = ".ralph/memory/MUTATION_STATS.md";

    const file = std.fs.cwd().openFile(stats_file, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // File doesn't exist yet, use default stats
            return;
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    // Parse stats from file (simple line-based parsing)
    // Format: "  Total fixes: N", etc.
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "Total fixes:")) |pos| {
            const num_str = line[pos + "Total fixes:".len ..];
            global_stats.total_fixes = std.fmt.parseInt(u32, std.mem.trim(u8, num_str, &std.ascii.whitespace), 10) catch 0;
        } else if (std.mem.indexOf(u8, line, "Successful:")) |pos| {
            const num_str = line[pos + "Successful:".len ..];
            global_stats.successful_fixes = std.fmt.parseInt(u32, std.mem.trim(u8, num_str, &std.ascii.whitespace), 10) catch 0;
        } else if (std.mem.indexOf(u8, line, "Failed:")) |pos| {
            const num_str = line[pos + "Failed:".len ..];
            global_stats.failed_fixes = std.fmt.parseInt(u32, std.mem.trim(u8, num_str, &std.ascii.whitespace), 10) catch 0;
        }
    }

    global_stats.intelligence_gain = global_stats.calculateGain();
}
