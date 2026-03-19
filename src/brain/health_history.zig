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
    pub fn record(self: *BrainHealthHistory, snapshot: HealthSnapshot) !void {
        const file = try std.fs.cwd().createFile(BRAIN_HEALTH_LOG, .{ .read = true });
        defer file.close();

        try file.seekFromEnd(0);

        // Write JSONL line
        try file.writer().print(
            \\{"ts":{d},"health":{d:.1},"ok":{},"claims":{d},"events_pub":{d},"events_buf":{d},"stress_ok":{}}
        , .{
            snapshot.timestamp,
            snapshot.health_score,
            snapshot.healthy,
            snapshot.active_claims,
            snapshot.events_published,
            snapshot.events_buffered,
            snapshot.stress_test_passed,
        });
        if (snapshot.stress_test_score) |score| {
            try file.writer().print(",\"stress_score\":{d}", .{score});
        }
        try file.writer().writeAll("}\n");
    }

    /// Read recent history (last N entries)
    pub fn recent(self: *BrainHealthHistory, n: usize) ![]HealthSnapshot {
        const file = try std.fs.cwd().openFile(BRAIN_HEALTH_LOG, .{});
        defer file.close();

        // Read all lines
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');

        var snapshots = std.ArrayList(HealthSnapshot).init(self.allocator);

        // Parse last N non-empty lines
        var count: usize = 0;
        var line_iter = lines.reverseIterator();
        while (line_iter.next()) |line| {
            if (line.len == 0) continue;
            if (count >= n) break;

            // Parse JSON (simple manual parsing for key fields)
            const snapshot = try parseSnapshot(line);
            try snapshots.append(snapshot);
            count += 1;
        }

        return snapshots.toOwnedSlice();
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
                const score_str = json[start..start + end];
                snapshot.health_score = try std.fmt.parseFloat(f32, score_str);
            }
        }

        // Extract healthy
        if (std.mem.indexOf(u8, json, "\"ok\":")) |pos| {
            const start = pos + 5;
            const val = json[start..start + 4];
            snapshot.healthy = std.mem.eql(u8, val, "true");
        }

        return snapshot;
    }
};
