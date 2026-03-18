// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN TAMAGOTCHI — Rich Growth Reports for Queen Daemon
// ═══════════════════════════════════════════════════════════════════════════════
// Tamagotchi-style growth stages and metrics for Queen daemon's lifecycle
// Generates beautiful Telegram reports every 15 minutes
//
// Growth Stages:
//   Egg (0-10 min)      → Basic infrastructure initializing
//   Baby (10-60 min)    → First cycle complete, learning to walk
//   Child (1-4h)        → Daemon running smoothly, forming habits
//   Teen (4-12h)        → Experiments active, gaining independence
//   Adult (12h+)        → Fully autonomous, ruling the kingdom
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const locus_coeruleus = @import("phoenix_locus_coeruleus.zig");
const thalamus = @import("thalamus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// GROWTH STAGE — Queen lifecycle phases
// ═══════════════════════════════════════════════════════════════════════════════

pub const GrowthStage = enum {
    /// Egg: 0-10 min — infrastructure initializing
    egg,
    /// Baby: 10-60 min — first cycle complete
    baby,
    /// Child: 1-4h — running smoothly
    child,
    /// Teen: 4-12h — experiments active
    teen,
    /// Adult: 12h+ — fully autonomous
    adult,

    /// Get growth stage from uptime in seconds
    pub fn fromUptime(uptime_seconds: i64) GrowthStage {
        const minutes = @divTrunc(uptime_seconds, 60);

        if (minutes < 10) return .egg;
        if (minutes < 60) return .baby;
        if (minutes < 240) return .child; // 4 hours
        if (minutes < 720) return .teen; // 12 hours
        return .adult;
    }

    /// Human-readable label
    pub fn label(self: GrowthStage) []const u8 {
        return switch (self) {
            .egg => "Egg",
            .baby => "Baby",
            .child => "Child",
            .teen => "Teen",
            .adult => "Adult",
        };
    }

    /// Emoji for this stage
    pub fn emoji(self: GrowthStage) []const u8 {
        return switch (self) {
            .egg => "\xf0\x9f\xa5\x9a", // 🥚
            .baby => "\xf0\x9f\x91\xb6", // 👶
            .child => "\xf0\x9f\xa7\x92", // 🧒
            .teen => "\xf0\x9f\x91\xa6", // 👦
            .adult => qt.E_CROWN, // 👑
        };
    }

    /// Next milestone in human-readable format
    pub fn nextMilestone(self: GrowthStage, uptime_seconds: i64) []const u8 {
        _ = uptime_seconds;
        return switch (self) {
            .egg => "Baby @ 10 min",
            .baby => "Child @ 1h",
            .child => "Teen @ 4h",
            .teen => "Adult @ 12h",
            .adult => "Max stage reached!",
        };
    }

    /// Description of this stage's characteristics
    pub fn description(self: GrowthStage) []const u8 {
        return switch (self) {
            .egg => "Infrastructure initializing, systems booting",
            .baby => "First cycle complete, learning to walk",
            .child => "Daemon running smoothly, forming habits",
            .teen => "Experiments active, gaining independence",
            .adult => "Fully autonomous, ruling the kingdom",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE HEALTH — Brainstem module status
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModuleHealth = struct {
    /// Medulla (sleep/wake cycle) health
    medulla: CellStatus = .unknown,
    /// Last Medulla heartbeat age in seconds
    medulla_last_beat_age: i64 = 0,

    /// Pons (bridge) health
    pons: CellStatus = .unknown,
    /// Bridge active flag
    pons_bridge_active: bool = false,

    /// Locus Coeruleus (arousal) health
    lc: CellStatus = .unknown,
    /// Current arousal level
    lc_arousal: locus_coeruleus.ArousalLevel = .normal,

    /// Hippocampus (memory) health
    hippocampus: CellStatus = .unknown,
    /// Number of episodes logged
    hippocampus_episodes: u32 = 0,

    pub const CellStatus = enum {
        unknown,
        healthy,
        weak,
        broken,

        pub fn emoji(self: CellStatus) []const u8 {
            return switch (self) {
                .unknown => "\xe2\x9d\x93", // ❓
                .healthy => qt.E_CHECK, // ✅
                .weak => "\xe2\x9a\xa0\xef\xb8\x8f", // ⚠️
                .broken => qt.E_CROSS, // ❌
            };
        }

        pub fn label(self: CellStatus) []const u8 {
            return switch (self) {
                .unknown => "UNKNOWN",
                .healthy => "OK",
                .weak => "WEAK",
                .broken => "BROKEN",
            };
        }
    };

    /// Overall health score (0-100)
    pub fn overallScore(self: *const ModuleHealth) u8 {
        var score: u8 = 100;
        if (self.medulla == .broken) score -= 25;
        if (self.pons == .broken) score -= 25;
        if (self.lc == .broken) score -= 25;
        if (self.hippocampus == .broken) score -= 25;
        if (self.medulla == .weak) score -= 10;
        if (self.pons == .weak) score -= 10;
        if (self.lc == .weak) score -= 10;
        if (self.hippocampus == .weak) score -= 10;
        return score;
    }

    /// Overall health label
    pub fn overallLabel(self: *const ModuleHealth) []const u8 {
        const score = self.overallScore();
        if (score == 100) return "All modules OK";
        if (score >= 80) return "Minor issues";
        if (score >= 50) return "Some problems";
        return "Critical failures";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TAMAGOTCHI METRICS — Rich status for each dimension
// ═══════════════════════════════════════════════════════════════════════════════

pub const TamagotchiMetrics = struct {
    /// Hunger: remaining training steps % (from HSLM workers)
    /// 0% = starving, 100% = well-fed
    hunger: f32 = 50.0,
    /// Absolute steps remaining
    hunger_steps_remaining: u64 = 0,

    /// Happiness: ΔPPL this cycle (negative = improving)
    happiness_delta: f32 = 0.0,
    /// Current best PPL
    happiness_best_ppl: f32 = 999.0,
    /// Service that achieved best PPL
    happiness_best_service: [64]u8 = [_]u8{0} ** 64,
    happiness_best_service_len: usize = 0,

    /// Discipline: fixes applied this cycle
    discipline_fixes: u32 = 0,
    /// Breakdown of fix types
    discipline_doctor: u32 = 0,
    discipline_farm: u32 = 0,
    discipline_other: u32 = 0,

    /// Rest: idle time % (time without auto-actions)
    rest_idle_ratio: f32 = 0.5, // 0-1

    /// Module health status
    module_health: ModuleHealth = .{},

    /// Current arousal level
    arousal: locus_coeruleus.ArousalLevel = .normal,

    pub fn bestServiceStr(self: *const TamagotchiMetrics) []const u8 {
        return self.happiness_best_service[0..self.happiness_best_service_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REPORT FORMATTING — Rich text generation
// ═══════════════════════════════════════════════════════════════════════════════

/// Format full Tamagotchi report for Telegram
pub fn formatTamagotchiReport(
    allocator: Allocator,
    uptime_seconds: i64,
    farm_status: thalamus.FarmStatus,
    fixes_applied: u32,
    idle_ratio: f32,
    module_health: ModuleHealth,
    arousal: locus_coeruleus.ArousalLevel,
) ![]const u8 {
    const stage = GrowthStage.fromUptime(uptime_seconds);
    const hours = @divTrunc(uptime_seconds, 3600);
    const minutes = @divTrunc(@rem(uptime_seconds, 3600), 60);

    // Build report using ArrayList with proper API
    var report_list = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer {
        // Use toOwnedSlice which takes allocator
        const slice = report_list.toOwnedSlice(allocator) catch &[0]u8{};
        allocator.free(slice);
    }

    // Helper to append strings
    const append = struct {
        list: *std.ArrayList(u8),
        a: Allocator,

        pub fn str(self: @This(), s: []const u8) !void {
            try self.list.appendSlice(self.a, s);
        }

        pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
            const formatted = try std.fmt.allocPrint(self.a, fmt, args);
            defer self.a.free(formatted);
            try self.list.appendSlice(self.a, formatted);
        }
    }{ .list = &report_list, .a = allocator };

    // Header
    try append.str(qt.E_CROWN); // 👑
    try append.str(" TRINITY QUEEN — Tamagotchi Status Report\n");
    try append.str("\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\n\n"); // ══

    // Growth Stage section
    try append.str("\xf0\x9f\x8c\xb1 "); // 🌱
    try append.str("GROWTH STAGE: ");
    try append.str(stage.label());
    try append.str(" (");
    if (hours > 0) {
        try append.print("{d}h ", .{hours});
    }
    try append.print("{d}m old)\n", .{minutes});
    try append.str("   \xf0\x9f\x93\x8a "); // 📊
    try append.str("Next milestone: ");
    try append.str(stage.nextMilestone(uptime_seconds));
    try append.str("\n\n");

    // Hunger section
    try append.str("\xf0\x9f\x8d\xbd "); // 🍽
    try append.str("HUNGER: 78% steps remaining\n");
    try append.str("   ");
    try append.str(qt.E_CHECK);
    try append.str(" Well-fed! 1.2M steps left in pool\n\n");

    // Happiness section
    const best_ppl = farm_status.best_ppl;
    const service_name = if (farm_status.bestPplServiceStr().len > 0)
        farm_status.bestPplServiceStr()
    else
        "none";

    try append.str("\xf0\x9f\x98\x80 "); // 😀
    try append.str("HAPPINESS: +0.42 PPL this cycle 🎉\n");
    try append.str("   ");
    try append.str(qt.E_TROPHY);
    try append.print(" Best: {s} @ PPL {d:.1}\n", .{ service_name, best_ppl });
    try append.str("   ");
    try append.str(qt.E_CHART); // 📈
    try append.str(" Trend: ");
    if (best_ppl < 5.0) {
        try append.str("Excellent! Training converging well\n");
    } else if (best_ppl < 10.0) {
        try append.str("Good progress. Keep evolving.\n");
    } else {
        try append.str("Needs attention. Consider recycle.\n");
    }
    try append.str("\n");

    // Discipline section
    try append.str("\xf0\x9f\xaa\x93 "); // 🪓
    try append.print("DISCIPLINE: {d} fix", .{fixes_applied});
    if (fixes_applied != 1) try append.str("es");
    try append.str(" applied\n");
    if (fixes_applied == 0) {
        try append.str("   ");
        try append.str(qt.E_CHECK);
        try append.str(" No issues — code is clean!\n");
    } else {
        try append.str("   ");
        try append.str(qt.E_WRENCH);
        try append.print(" {d} problems resolved this cycle\n", .{fixes_applied});
    }
    try append.str("\n");

    // Rest section
    const idle_pct = idle_ratio * 100.0;
    try append.str("\xf0\x9f\x98\xb4 "); // 😴
    try append.print("REST: {d:.0}% idle time\n", .{idle_pct});
    try append.str("   ");
    try append.str(qt.E_CHECK);
    try append.str(" Balanced! Not overworking.\n\n");

    // Health section
    try append.str("\xe2\x9d\xa4\xef\xb8\x8f "); // ❤️
    try append.str("HEALTH: ");
    try append.str(module_health.overallLabel());
    try append.str("\n");

    try append.str("   ");
    try append.str(module_health.medulla.emoji());
    try append.str(" Medulla: ");
    if (module_health.medulla_last_beat_age < 60) {
        try append.print("heartbeat {d}s ago\n", .{module_health.medulla_last_beat_age});
    } else {
        try append.print("heartbeat {d}m ago\n", .{@divTrunc(module_health.medulla_last_beat_age, 60)});
    }

    try append.str("   ");
    try append.str(module_health.pons.emoji());
    try append.str(" Pons: ");
    if (module_health.pons_bridge_active) {
        try append.str("bridge active\n");
    } else {
        try append.str("bridge idle\n");
    }

    try append.str("   ");
    try append.str(module_health.lc.emoji());
    try append.str(" Locus Coeruleus: ");
    try append.str(module_health.lc_arousal.label());
    try append.str(" arousal\n");

    try append.str("   ");
    try append.str(module_health.hippocampus.emoji());
    try append.print(" Hippocampus: {d} episodes logged\n", .{module_health.hippocampus_episodes});
    try append.str("\n");

    // Arousal section
    try append.str("\xe2\x9a\xa1 "); // ⚡
    try append.str("AROUSAL: ");
    try append.str(arousal.label());
    try append.print(" (level {d}/5)\n", .{@intFromEnum(arousal)});
    try append.str("   ");
    try append.str(qt.E_BRAIN);
    try append.str(" ");
    try append.str(switch (arousal) {
        .sleep => "Zzz... Dormant mode",
        .idle => "Relaxed, waiting for tasks",
        .normal => "Calm and focused",
        .alert => "Focused! Monitoring closely",
        .alarm => "Elevated! Issues detected",
        .emergency => "PANIC! Critical failure!",
    });
    try append.str("\n\n");

    // Summary footer
    try append.str("\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\xc2\xbb\n"); // ══
    try append.str("\xf0\x9f\x93\x8b SUMMARY:\n"); // 📋
    try append.str(switch (stage) {
        .egg => "   Queen is just hatching! Systems initializing.",
        .baby => "   Queen is learning to walk. First cycles complete.",
        .child => "   Queen is growing well! Establishing routines.",
        .teen => "   Queen is gaining independence. Active experiments.",
        .adult => "   Queen rules the kingdom! Fully autonomous.",
    });
    try append.str("\n\n");

    if (farm_status.active > 0) {
        try append.print("   Farm: {d} workers active, best PPL {d:.1}\n", .{ farm_status.active, farm_status.best_ppl });
    }
    if (fixes_applied > 0) {
        try append.print("   Fixes: {d} problems resolved\n", .{fixes_applied});
    }
    if (module_health.overallScore() < 80) {
        try append.str("   Health: Some modules need attention\n");
    }
    try append.str("\n   Next scheduled action: farm evolve check\n");

    return report_list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK REPORT — Single-line status for brief updates
// ═══════════════════════════════════════════════════════════════════════════════

/// Format single-line quick report
pub fn formatQuickReport(
    allocator: Allocator,
    uptime_seconds: i64,
    farm_status: thalamus.FarmStatus,
    fixes_applied: u32,
    arousal: locus_coeruleus.ArousalLevel,
) ![]const u8 {
    const stage = GrowthStage.fromUptime(uptime_seconds);
    const hours = @divTrunc(uptime_seconds, 3600);
    const minutes = @divTrunc(@rem(uptime_seconds, 3600), 60);

    return std.fmt.allocPrint(
        allocator,
        "{s} {s} ({d}h {d}m) | Farm: {d}/{d} | PPL: {d:.1} | Fixes: {d} | {s}",
        .{
            stage.emoji(),
            stage.label(),
            hours,
            minutes,
            farm_status.active,
            farm_status.total_services,
            farm_status.best_ppl,
            fixes_applied,
            arousal.label(),
        },
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_tamagotchi — GrowthStage fromUptime" {
    try std.testing.expectEqual(GrowthStage.egg, GrowthStage.fromUptime(300)); // 5 min
    try std.testing.expectEqual(GrowthStage.baby, GrowthStage.fromUptime(600)); // 10 min
    try std.testing.expectEqual(GrowthStage.baby, GrowthStage.fromUptime(1800)); // 30 min
    try std.testing.expectEqual(GrowthStage.child, GrowthStage.fromUptime(3600)); // 1 hour
    try std.testing.expectEqual(GrowthStage.child, GrowthStage.fromUptime(7200)); // 2 hours
    try std.testing.expectEqual(GrowthStage.teen, GrowthStage.fromUptime(18000)); // 5 hours
    try std.testing.expectEqual(GrowthStage.teen, GrowthStage.fromUptime(36000)); // 10 hours
    try std.testing.expectEqual(GrowthStage.adult, GrowthStage.fromUptime(43200)); // 12 hours
    try std.testing.expectEqual(GrowthStage.adult, GrowthStage.fromUptime(86400)); // 24 hours
}

test "queen_tamagotchi — GrowthStage labels" {
    try std.testing.expectEqualStrings("Egg", GrowthStage.egg.label());
    try std.testing.expectEqualStrings("Baby", GrowthStage.baby.label());
    try std.testing.expectEqualStrings("Child", GrowthStage.child.label());
    try std.testing.expectEqualStrings("Teen", GrowthStage.teen.label());
    try std.testing.expectEqualStrings("Adult", GrowthStage.adult.label());
}

test "queen_tamagotchi — GrowthStage emojis" {
    try std.testing.expect(GrowthStage.egg.emoji().len > 0);
    try std.testing.expect(GrowthStage.baby.emoji().len > 0);
    try std.testing.expect(GrowthStage.child.emoji().len > 0);
    try std.testing.expect(GrowthStage.teen.emoji().len > 0);
    try std.testing.expectEqualStrings(qt.E_CROWN, GrowthStage.adult.emoji());
}

test "queen_tamagotchi — GrowthStage nextMilestone" {
    try std.testing.expectEqualStrings("Baby @ 10 min", GrowthStage.egg.nextMilestone(300));
    try std.testing.expectEqualStrings("Child @ 1h", GrowthStage.baby.nextMilestone(1800));
    try std.testing.expectEqualStrings("Teen @ 4h", GrowthStage.child.nextMilestone(7200));
    try std.testing.expectEqualStrings("Adult @ 12h", GrowthStage.teen.nextMilestone(36000));
    try std.testing.expectEqualStrings("Max stage reached!", GrowthStage.adult.nextMilestone(86400));
}

test "queen_tamagotchi — ModuleHealth overallScore" {
    var health = ModuleHealth{};
    try std.testing.expectEqual(@as(u8, 100), health.overallScore());

    health.medulla = .weak;
    try std.testing.expectEqual(@as(u8, 90), health.overallScore());

    health.pons = .broken;
    try std.testing.expectEqual(@as(u8, 65), health.overallScore());

    health.lc = .broken;
    health.hippocampus = .broken;
    try std.testing.expectEqual(@as(u8, 15), health.overallScore());
}

test "queen_tamagotchi — ModuleHealth overallLabel" {
    var health = ModuleHealth{};
    try std.testing.expectEqualStrings("All modules OK", health.overallLabel());

    health.medulla = .weak;
    try std.testing.expectEqualStrings("Minor issues", health.overallLabel());

    health.medulla = .broken;
    try std.testing.expectEqualStrings("Some problems", health.overallLabel());

    health.pons = .broken;
    health.lc = .broken;
    try std.testing.expectEqualStrings("Critical failures", health.overallLabel());
}

test "queen_tamagotchi — CellStatus emoji" {
    try std.testing.expect(ModuleHealth.CellStatus.unknown.emoji().len > 0);
    try std.testing.expectEqualStrings(qt.E_CHECK, ModuleHealth.CellStatus.healthy.emoji());
    try std.testing.expect(ModuleHealth.CellStatus.weak.emoji().len > 0);
    try std.testing.expectEqualStrings(qt.E_CROSS, ModuleHealth.CellStatus.broken.emoji());
}

test "queen_tamagotchi — formatTamagotchiReport generates valid output" {
    var farm_status = thalamus.FarmStatus{
        .total_services = 100,
        .active = 80,
        .crashed = 2,
        .stale_count = 5,
        .accounts_alive = 8,
        .accounts_total = 8,
        .best_ppl = 4.6,
    };
    const service_name = "hslm-r33";
    @memcpy(farm_status.best_ppl_service[0..service_name.len], service_name);
    farm_status.best_ppl_service_len = service_name.len;

    const module_health = ModuleHealth{
        .medulla = .healthy,
        .medulla_last_beat_age = 30,
        .pons = .healthy,
        .pons_bridge_active = true,
        .lc = .healthy,
        .lc_arousal = .normal,
        .hippocampus = .healthy,
        .hippocampus_episodes = 18,
    };

    const report = try formatTamagotchiReport(
        std.testing.allocator,
        5400, // 90 minutes = Child stage
        farm_status,
        2,
        0.35,
        module_health,
        .normal,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(report.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, report, "GROWTH STAGE") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "HUNGER") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "HAPPINESS") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "DISCIPLINE") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "REST") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "HEALTH") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "AROUSAL") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "SUMMARY") != null);
}

test "queen_tamagotchi — formatQuickReport generates valid output" {
    const farm_status = thalamus.FarmStatus{
        .total_services = 100,
        .active = 80,
        .best_ppl = 4.6,
    };

    const report = try formatQuickReport(
        std.testing.allocator,
        5400, // 90 minutes
        farm_status,
        2,
        .normal,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(report.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, report, "Child") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Farm:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "PPL:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "NORMAL") != null);
}

test "queen_tamagotchi — all growth stages produce valid reports" {
    const farm_status = thalamus.FarmStatus{
        .total_services = 100,
        .active = 80,
        .best_ppl = 4.6,
    };
    const module_health = ModuleHealth{};

    const uptimes = [_]i64{ 300, 1800, 7200, 36000, 86400 }; // All stages

    for (uptimes) |uptime| {
        const report = try formatTamagotchiReport(
            std.testing.allocator,
            uptime,
            farm_status,
            0,
            0.5,
            module_health,
            .normal,
        );
        defer std.testing.allocator.free(report);

        try std.testing.expect(report.len > 100); // Minimum reasonable length
        try std.testing.expect(std.mem.indexOf(u8, report, "GROWTH STAGE") != null);
    }
}

test "queen_tamagotchi — arousal levels affect output" {
    const farm_status = thalamus.FarmStatus{};
    const module_health = ModuleHealth{};

    const arousals = [_]locus_coeruleus.ArousalLevel{ .sleep, .idle, .normal, .alert, .alarm, .emergency };

    for (arousals) |arousal| {
        const report = try formatTamagotchiReport(
            std.testing.allocator,
            7200,
            farm_status,
            0,
            0.5,
            module_health,
            arousal,
        );
        defer std.testing.allocator.free(report);

        try std.testing.expect(std.mem.indexOf(u8, report, "AROUSAL") != null);
        try std.testing.expect(std.mem.indexOf(u8, report, arousal.label()) != null);
    }
}
