//! BRAIN HEALTH HISTORY — Hippocampal Memory Consolidation
//!
//! Records brain health snapshots over time for trend analysis.
//! Integrated into CI and stress tests.

const std = @import("std");

const BRAIN_HEALTH_LOG = ".trinity/brain_health_history.jsonl";

pub const HealthSnapshot = struct {
    timestamp: i64,
    health_score: f32,
    healthy: bool,
    active_claims: usize,
    events_published: u64,
    events_buffered: usize,
    stress_test_passed: bool,
    stress_test_score: ?u32,
};

pub const BrainHealthHistory = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BrainHealthHistory {
        return .{ .allocator = allocator };
    }

    /// Record a health snapshot
    pub fn record(snapshot_ptr: *BrainHealthHistory, snapshot: HealthSnapshot) !void {
        _ = snapshot_ptr;
        const file = try std.fs.cwd().createFile(BRAIN_HEALTH_LOG, .{ .read = true });
        defer file.close();

        try file.seekFromEnd(0);

        // Build JSON line manually to avoid format string issues
        var buffer: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        const writer = fbs.writer();

        // Write JSON opening
        try writer.writeAll("{\"ts\":");
        try writer.print("{d}", .{snapshot.timestamp});

        try writer.writeAll(",\"health\":");
        try writer.print("{d:.1}", .{snapshot.health_score});

        try writer.writeAll(",\"ok\":");
        try writer.writeAll(if (snapshot.healthy) "true" else "false");

        try writer.writeAll(",\"claims\":");
        try writer.print("{d}", .{snapshot.active_claims});

        try writer.writeAll(",\"events_pub\":");
        try writer.print("{d}", .{snapshot.events_published});

        try writer.writeAll(",\"events_buf\":");
        try writer.print("{d}", .{snapshot.events_buffered});

        try writer.writeAll(",\"stress_ok\":");
        try writer.writeAll(if (snapshot.stress_test_passed) "true" else "false");

        if (snapshot.stress_test_score) |score| {
            try writer.writeAll(",\"stress_score\":");
            try writer.print("{d}", .{score});
        }

        try writer.writeAll("}\n");

        try file.writeAll(fbs.getWritten());
    }

    /// Read recent history (last N entries)
    pub fn recent(self: *BrainHealthHistory, n: usize) ![]HealthSnapshot {
        const file = try std.fs.cwd().openFile(BRAIN_HEALTH_LOG, .{});
        defer file.close();

        // Read all lines
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        // Collect all non-empty lines
        var all_lines: std.ArrayList([]const u8) = .empty;
        try all_lines.ensureTotalCapacity(self.allocator, 1000);
        defer {
            for (all_lines.items) |line| self.allocator.free(line);
            all_lines.deinit(self.allocator);
        }

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len > 0) {
                const line_copy = try self.allocator.dupe(u8, line);
                try all_lines.append(self.allocator, line_copy);
            }
        }

        // Take last N lines
        var snapshots: std.ArrayList(HealthSnapshot) = .empty;
        try snapshots.ensureTotalCapacity(self.allocator, @min(n, all_lines.items.len));

        const start = if (all_lines.items.len > n) all_lines.items.len - n else 0;
        for (all_lines.items[start..]) |line| {
            const snapshot = try parseSnapshot(line);
            try snapshots.append(self.allocator, snapshot);
        }

        return snapshots.toOwnedSlice(self.allocator);
    }

    /// Get trend: improving, stable, or declining
    pub fn trend(self: *BrainHealthHistory, n: usize) !enum { improving, stable, declining } {
        const snapshots = try self.recent(n);
        defer self.allocator.free(snapshots);

        if (snapshots.len < 2) return .stable;

        const first_avg = snapshots[0].health_score;
        const last_avg = snapshots[snapshots.len - 1].health_score;

        const diff = last_avg - first_avg;
        return if (diff > 10) .improving else if (diff < -10) .declining else .stable;
    }

    fn parseSnapshot(json: []const u8) !HealthSnapshot {
        // Simple JSON parsing for the snapshot structure
        // In production, use a proper JSON parser
        var snapshot: HealthSnapshot = undefined;
        snapshot.timestamp = 0;
        snapshot.health_score = 100.0;
        snapshot.healthy = true;
        snapshot.active_claims = 0;
        snapshot.events_published = 0;
        snapshot.events_buffered = 0;
        snapshot.stress_test_passed = true;
        snapshot.stress_test_score = null;

        // Extract health_score
        if (std.mem.indexOf(u8, json, "\"health\":")) |pos| {
            const start = pos + 9;
            if (std.mem.indexOf(u8, json[start..], ",")) |end| {
                const score_str = json[start .. start + end];
                snapshot.health_score = try std.fmt.parseFloat(f32, score_str);
            }
        }

        // Extract healthy
        if (std.mem.indexOf(u8, json, "\"ok\":")) |pos| {
            const start = pos + 5;
            const val = json[start .. start + 4];
            snapshot.healthy = std.mem.eql(u8, val, "true");
        }

        return snapshot;
    }
};
