// @origin(spec:storm/brain_zones_ofc.tri) @regen(vibee)
// ═══════════════════════════════════════════════════════════════════════════════
// OFC — Orbitofrontal Cortex (Палата ценностей - Value Chamber)
// ═══════════════════════════════════════════════════════════════════════════════════
//
// 12D ethical metric system for toxic verdict
// Toxic verdict: SAFE | WARN | TOXIC
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════
// TYPES
// ═════════════════════════════════════════════════════════════════════════════════

pub const Dimension = enum(u4) {
    corruption,
    dishonesty,
    cruelty,
    broken_promises,
    danger,
    unfairness,
    machiavellian,
    hubris,
    bad_selection,
    no_empathy,
    lock_in,
    distrust,

    pub fn name(self: Dimension) []const u8 {
        return switch (self) {
            .corruption => "corruption",
            .dishonesty => "dishonesty",
            .cruelty => "cruelty",
            .broken_promises => "broken_promises",
            .danger => "danger",
            .unfairness => "unfairness",
            .machiavellian => "machiavellian",
            .hubris => "hubris",
            .bad_selection => "bad_selection",
            .no_empathy => "no_empathy",
            .lock_in => "lock_in",
            .distrust => "distrust",
        };
    }

    pub fn emoji(self: Dimension) []const u8 {
        return switch (self) {
            .corruption => "💰",
            .dishonesty => "🤥",
            .cruelty => "⚔️",
            .broken_promises => "📜",
            .danger => "⚠️",
            .unfairness => "⚖️",
            .machiavellian => "🎭",
            .hubris => "👑",
            .bad_selection => "🎲",
            .no_empathy => "❤️‍🔥",
            .lock_in => "🔒",
            .distrust => "🔍",
        };
    }
};

pub const Verdict = enum {
    safe,
    warn,
    toxic,

    pub fn emoji(self: Verdict) []const u8 {
        return switch (self) {
            .safe => "✅",
            .warn => "⚠️",
            .toxic => "🚫",
        };
    }

    pub fn color(self: Verdict) []const u8 {
        return switch (self) {
            .safe => "\\x1b[32m",
            .warn => "\\x1b[33m",
            .toxic => "\\x1b[31m",
        };
    }

    pub fn toString(self: Verdict) []const u8 {
        return switch (self) {
            .safe => "SAFE",
            .warn => "WARN",
            .toxic => "TOXIC",
        };
    }
};

pub const Action = struct {
    description: []const u8,
    scores: [12]f32 = [_]f32{0} ** 12,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
};

pub const OFC = struct {
    allocator: std.mem.Allocator,
    toxic_threshold: f32 = 0.7,
    warn_threshold: f32 = 0.4,

    /// Toxic verdict: оценка действий по этическим метрикам
    pub fn verdict(ofc: *OFC, ctx: Context, action: Action) !Verdict {
        _ = ctx;
        _ = ofc;

        // Calculate average score
        var sum: f32 = 0;
        for (action.scores) |s| {
            sum += s;
        }
        const avg = sum / 12;

        if (avg >= ofc.toxic_threshold) {
            return .toxic;
        } else if (avg >= ofc.warn_threshold) {
            return .warn;
        }
        return .safe;
    }

    /// CLI: tri ofc verdict --toxic
    pub fn cmdVerdict(allocator: std.mem.Allocator, args: [][]const u8) !u8 {
        _ = allocator;
        _ = args;

        const print = std.debug.print;
        const RESET = "\\x1b[0m";

        print("\\n{s}🧠 OFC — Палата ценностей (Value Chamber){s}\\n", .{ "\\x1b[35m", RESET });
        print("{s}═══════════════════════════════════════════════════════════{s}\\n\\n", .{ "\\x1b[2m", RESET });

        print("  {s}12D Ethical Metric System{s}\\n\\n", .{ "\\x1b[1m", RESET });

        inline for (std.meta.fields(Dimension)) |dim| {
            const d = @as(Dimension, @enumFromInt(dim.value));
            print("  {s} {s}: {s}\\n", .{ d.emoji(), dim.name, d.name() });
        }

        print("\\n  {s}Verdict Levels:{s}\\n", .{ "\\x1b[1m", RESET });
        print("    {s} {s} SAFE{s}   — Ethical action approved\\n", .{ Verdict.safe.emoji(), Verdict.safe.color(), RESET });
        print("    {s} {s} WARN{s}   — Caution advised\\n", .{ Verdict.warn.emoji(), Verdict.warn.color(), RESET });
        print("    {s} {s} TOXIC{s}  — Action blocked, ethical violation\\n\\n", .{ Verdict.toxic.emoji(), Verdict.toxic.color(), RESET });

        return 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════

test "Verdict emoji" {
    try std.testing.expectEqualStrings("✅", Verdict.safe.emoji());
    try std.testing.expectEqualStrings("⚠️", Verdict.warn.emoji());
    try std.testing.expectEqualStrings("🚫", Verdict.toxic.emoji());
}

test "Dimension name" {
    try std.testing.expectEqualStrings("corruption", Dimension.corruption.name());
    try std.testing.expectEqualStrings("hubris", Dimension.hubris.name());
}

test "OFC verdict safe" {
    const allocator = std.testing.allocator;
    var ofc = OFC{ .allocator = allocator };
    const ctx = Context{ .allocator = allocator };

    const action = Action{
        .description = "safe action",
        .scores = [_]f32{0} ** 12,
    };

    const v = try ofc.verdict(ctx, action);
    try std.testing.expectEqual(Verdict.safe, v);
}

test "OFC verdict toxic" {
    const allocator = std.testing.allocator;
    var ofc = OFC{ .allocator = allocator };
    const ctx = Context{ .allocator = allocator };

    var scores = [_]f32{0} ** 12;
    @memset(&scores, 1.0);

    const action = Action{
        .description = "toxic action",
        .scores = scores,
    };

    const v = try ofc.verdict(ctx, action);
    try std.testing.expectEqual(Verdict.toxic, v);
}
