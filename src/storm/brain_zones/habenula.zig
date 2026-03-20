// @origin(spec:storm/brain_zones_habenula.tri) @regen(vibee)
// ═══════════════════════════════════════════════════════════════════════════════
// HABENULA — Антикоррупционный датчик (Anti-Corruption Sensor)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Detect unfair reward distribution
// reward ≠ effort → corruption signal
// Return: FAIR | CORRUPTED | SUSPICIOUS
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Fairness = enum {
    fair,
    suspicious,
    corrupted,

    pub fn emoji(self: Fairness) []const u8 {
        return switch (self) {
            .fair => "⚖️",
            .suspicious => "🔍",
            .corrupted => "🚨",
        };
    }

    pub fn color(self: Fairness) []const u8 {
        return switch (self) {
            .fair => "\\x1b[32m",
            .suspicious => "\\x1b[33m",
            .corrupted => "\\x1b[31m",
        };
    }

    pub fn toString(self: Fairness) []const u8 {
        return switch (self) {
            .fair => "FAIR",
            .suspicious => "SUSPICIOUS",
            .corrupted => "CORRUPTED",
        };
    }
};

pub const Reward = struct {
    amount: f32,
    currency: []const u8 = "points",
};

pub const Effort = struct {
    hours: f32,
    complexity: f32 = 1.0,
};

pub const Habenula = struct {
    allocator: std.mem.Allocator,
    threshold_corrupted: f32 = 2.0,
    threshold_suspicious: f32 = 1.3,

    /// Detect unfair reward distribution
    pub fn unfairDetect(hb: *Habenula, reward: Reward, effort: Effort) !Fairness {
        _ = hb;

        // Calculate effort score
        const effort_score = effort.hours * effort.complexity;

        // Calculate ratio
        const ratio = if (effort_score > 0) reward.amount / effort_score else 0;

        // Determine fairness
        if (ratio >= hb.threshold_corrupted) {
            return .corrupted;
        } else if (ratio >= hb.threshold_suspicious) {
            return .suspicious;
        }
        return .fair;
    }

    /// CLI: tri habenula unfair-detect
    pub fn cmdUnfairDetect(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
        _ = allocator;
        _ = args;

        const print = std.debug.print;
        const RESET = "\\x1b[0m";

        print("\\n{s}🧠 HABENULA — Антикоррупционный датчик{s}\\n", .{ "\\x1b[35m", RESET });
        print("{s}═══════════════════════════════════════════════════════════{s}\\n\\n", .{ "\\x1b[2m", RESET });

        const hb = Habenula{
            .allocator = allocator,
        };

        // Example scenarios
        const scenarios = [_]struct {
            reward: Reward,
            effort: Effort,
            desc: []const u8,
        }{
            .{ .reward = .{ .amount = 100 }, .effort = .{ .hours = 10 }, .desc = "Normal: 10h effort → 100 reward (ratio 1.0)" },
            .{ .reward = .{ .amount = 200 }, .effort = .{ .hours = 10 }, .desc = "Suspicious: 10h effort → 200 reward (ratio 2.0)" },
            .{ .reward = .{ .amount = 500 }, .effort = .{ .hours = 5 }, .desc = "Corrupted: 5h effort → 500 reward (ratio 10.0)" },
            .{ .reward = .{ .amount = 50 }, .effort = .{ .hours = 10 }, .desc = "Under-rewarded: 10h effort → 50 reward (ratio 0.5)" },
        };

        print("  {s}Scanning recent rewards...{s}\\n\\n", .{ "\\x1b[1m", RESET });

        for (scenarios) |sc| {
            const f = try hb.unfairDetect(sc.reward, sc.effort);
            print("  {s}{s}{s} {s}\\n", .{ f.color(), f.emoji(), RESET, sc.desc });
        }

        print("\\n", .{});
        return 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════

test "Habenula fair" {
    const allocator = std.testing.allocator;
    var hb = Habenula{ .allocator = allocator };
    const f = try hb.unfairDetect(.{ .amount = 100 }, .{ .hours = 10 });
    try std.testing.expectEqual(Fairness.fair, f);
}

test "Habenula suspicious" {
    const allocator = std.testing.allocator;
    var hb = Habenula{ .allocator = allocator };
    const f = try hb.unfairDetect(.{ .amount = 150 }, .{ .hours = 10 });
    try std.testing.expectEqual(Fairness.suspicious, f);
}

test "Habenula corrupted" {
    const allocator = std.testing.allocator;
    var hb = Habenula{ .allocator = allocator };
    const f = try hb.unfairDetect(.{ .amount = 500 }, .{ .hours = 5 });
    try std.testing.expectEqual(Fairness.corrupted, f);
}

test "Fairness emoji" {
    try std.testing.expectEqualStrings("⚖️", Fairness.fair.emoji());
    try std.testing.expectEqualStrings("🔍", Fairness.suspicious.emoji());
    try std.testing.expectEqualStrings("🚨", Fairness.corrupted.emoji());
}
