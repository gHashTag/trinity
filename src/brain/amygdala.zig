//! AMYGDALA — Emotional Salience Detection v1.0
//!
//! Detects emotionally significant events and prioritizes them.
//! Brain Region: Amygdala (Emotional Processing)

const std = @import("std");

pub const SalienceLevel = enum(u3) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
    critical = 4,

    pub fn fromScore(score: f32) SalienceLevel {
        return if (score < 20) .none
        else if (score < 40) .low
        else if (score < 60) .medium
        else if (score < 80) .high
        else .critical;
    }

    pub fn emoji(self: SalienceLevel) []const u8 {
        return switch (self) {
            .none => "⚪",
            .low => "🟢",
            .medium => "🟡",
            .high => "🟠",
            .critical => "🔴",
        };
    }
};

pub const EventSalience = struct {
    level: SalienceLevel,
    score: f32,
    reason: []const u8,
};

pub const Amygdala = struct {
    const Self = @This();

    /// Analyze task salience based on multiple factors
    pub fn analyzeTask(task_id: []const u8, realm: []const u8, priority: []const u8) EventSalience {
        var score: f32 = 0;
        var reasons = std.ArrayList(u8).init(std.heap.page_allocator);
        defer reasons.deinit();

        // Critical realms get higher salience
        if (std.mem.eql(u8, realm, "dukh")) {
            score += 40;
            reasons.appendSlice("Dukh realm;") catch {};
        }
        if (std.mem.eql(u8, realm, "razum")) {
            score += 30;
            reasons.appendSlice("Razum realm;") catch {};
        }

        // Priority keywords
        if (std.mem.indexOf(u8, task_id, "urgent") != null) {
            score += 30;
            reasons.appendSlice("Urgent;") catch {};
        }
        if (std.mem.indexOf(u8, task_id, "critical") != null) {
            score += 50;
            reasons.appendSlice("Critical;") catch {};
        }
        if (std.mem.indexOf(u8, task_id, "security") != null) {
            score += 40;
            reasons.appendSlice("Security;") catch {};
        }

        // Priority field
        if (std.mem.eql(u8, priority, "high")) {
            score += 20;
        } else if (std.mem.eql(u8, priority, "critical")) {
            score += 30;
        }

        // Cap at 100
        if (score > 100) score = 100;

        return .{
            .level = SalienceLevel.fromScore(score),
            .score = score,
            .reason = "Computed from realm/priority/task",
        };
    }

    /// Analyze error salience
    pub fn analyzeError(err_msg: []const u8) EventSalience {
        var score: f32 = 20; // Base score for any error

        // Critical error patterns
        const critical_patterns = [_][]const u8{
            "segfault", "panic", "out of memory", "deadlock",
            "corruption", "security", "authentication", "injection",
        };

        for (critical_patterns) |pattern| {
            if (std.mem.indexOf(u8, err_msg, pattern) != null) {
                score += 30;
            }
        }

        // High severity patterns
        const high_patterns = [_][]const u8{
            "timeout", "connection refused", "not found",
        };

        for (high_patterns) |pattern| {
            if (std.mem.indexOf(u8, err_msg, pattern) != null) {
                score += 15;
            }
        }

        if (score > 100) score = 100;

        return .{
            .level = SalienceLevel.fromScore(score),
            .score = score,
            .reason = "Error severity",
        };
    }

    /// Check if event requires immediate attention
    pub fn requiresAttention(salience: EventSalience) bool {
        return salience.level == .critical or salience.level == .high;
    }

    /// Get urgency score (0-1, higher = more urgent)
    pub fn urgency(salience: EventSalience) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(salience.level))) / 4.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SalienceLevel fromScore" {
    try std.testing.expectEqual(SalienceLevel.none, SalienceLevel.fromScore(10));
    try std.testing.expectEqual(SalienceLevel.low, SalienceLevel.fromScore(25));
    try std.testing.expectEqual(SalienceLevel.medium, SalienceLevel.fromScore(50));
    try std.testing.expectEqual(SalienceLevel.high, SalienceLevel.fromScore(70));
    try std.testing.expectEqual(SalienceLevel.critical, SalienceLevel.fromScore(90));
}

test "Amygdala task analysis" {
    const result = Amygdala.analyzeTask("urgent-security-fix", "dukh", "high");
    try std.testing.expect(result.score > 50);
    try std.testing.expect(result.level == .critical or result.level == .high);
}

test "Amygdala error analysis" {
    const result = Amygdala.analyzeError("segfault in critical module");
    try std.testing.expect(result.score > 40);
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala urgency" {
    const critical: EventSalience = .{ .level = .critical, .score = 90, .reason = "" };
    const low: EventSalience = .{ .level = .low, .score = 30, .reason = "" };

    try std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical));
    try std.testing.expect(Amygdala.urgency(low) < 0.5);
}
