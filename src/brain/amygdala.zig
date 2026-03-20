//! AMYGDALA — Emotional Salience Detection v1.0
//!
//! Detects emotionally significant events and prioritizes them.
//! Brain Region: Amygdala (Emotional Processing)

const std = @import("std");
const array_list = std.array_list;

pub const SalienceLevel = enum(u3) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
    critical = 4,

    pub fn fromScore(score: f32) SalienceLevel {
        return if (score < 20) .none else if (score < 40) .low else if (score < 60) .medium else if (score < 80) .high else .critical;
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
        var reasons = array_list.Managed(u8).initCapacity(std.heap.page_allocator, 128) catch |err| {
            std.log.err("Failed to allocate reasons: {}", .{err});
            return EventSalience{
                .level = .low,
                .score = score,
                .reason = "Allocation failed",
            };
        };
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
            "segfault",   "panic",    "out of memory",  "deadlock",
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

test "Amygdala SalienceLevel emoji" {
    try std.testing.expectEqual(@as(usize, 3), SalienceLevel.none.emoji().len);
    try std.testing.expectEqual(@as(usize, 3), SalienceLevel.low.emoji().len);
    try std.testing.expect(std.mem.eql(u8, "🔴", SalienceLevel.critical.emoji()));
}

test "Amygdala analyzeTask - dukh realm critical" {
    const result = Amygdala.analyzeTask("fix-urgent", "dukh", "critical");
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
    try std.testing.expect(result.score >= 70);
}

test "Amygdala analyzeTask - razum realm" {
    const result = Amygdala.analyzeTask("compute-stuff", "razum", "normal");
    try std.testing.expect(result.score >= 30);
}

test "Amygdala analyzeTask - unknown realm" {
    const result = Amygdala.analyzeTask("task-123", "unknown", "low");
    try std.testing.expect(result.score < 30);
}

test "Amygdala analyzeTask - security keyword" {
    const result = Amygdala.analyzeTask("security-patch-needed", "unknown", "high");
    try std.testing.expect(result.level == .high or result.level == .critical);
}

test "Amygdala analyzeError - segfault" {
    const result = Amygdala.analyzeError("segfault at address 0x0");
    try std.testing.expect(result.score >= 50);
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala analyzeError - panic" {
    const result = Amygdala.analyzeError("panic: reached unreachable code");
    try std.testing.expect(result.score >= 50);
}

test "Amygdala analyzeError - timeout" {
    const result = Amygdala.analyzeError("connection timeout after 30s");
    try std.testing.expect(result.score >= 35);
}

test "Amygdala analyzeError - generic error" {
    const result = Amygdala.analyzeError("file not found");
    try std.testing.expect(result.score >= 20);
}

test "Amygdala requiresAttention - critical level" {
    const salience: EventSalience = .{ .level = .critical, .score = 100, .reason = "" };
    try std.testing.expect(Amygdala.requiresAttention(salience));
}

test "Amygdala requiresAttention - high level" {
    const salience: EventSalience = .{ .level = .high, .score = 70, .reason = "" };
    try std.testing.expect(Amygdala.requiresAttention(salience));
}

test "Amygdala requiresAttention - medium level" {
    const salience: EventSalience = .{ .level = .medium, .score = 50, .reason = "" };
    try std.testing.expect(!Amygdala.requiresAttention(salience));
}

test "Amygdala requiresAttention - none level" {
    const salience: EventSalience = .{ .level = .none, .score = 0, .reason = "" };
    try std.testing.expect(!Amygdala.requiresAttention(salience));
}

test "Amygdala urgency - all levels" {
    const none: EventSalience = .{ .level = .none, .score = 0, .reason = "" };
    const low: EventSalience = .{ .level = .low, .score = 25, .reason = "" };
    const medium: EventSalience = .{ .level = .medium, .score = 50, .reason = "" };
    const high: EventSalience = .{ .level = .high, .score = 75, .reason = "" };
    const critical: EventSalience = .{ .level = .critical, .score = 100, .reason = "" };

    try std.testing.expectEqual(@as(f32, 0.0), Amygdala.urgency(none));
    try std.testing.expectEqual(@as(f32, 0.25), Amygdala.urgency(low));
    try std.testing.expectEqual(@as(f32, 0.5), Amygdala.urgency(medium));
    try std.testing.expectEqual(@as(f32, 0.75), Amygdala.urgency(high));
    try std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical));
}

test "Amygdala score capping at 100" {
    const result = Amygdala.analyzeTask("urgent-critical-security-fix", "dukh", "critical");
    try std.testing.expect(result.score <= 100);
}
