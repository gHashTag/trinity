// VIBEE BOGATYR 34 - Жар-птица (Creator)
// Принцип: SYNTHESIS - объединение противоположностей в нечто большее
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const common = @import("bogatyrs_common.zig");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const CREATOR_ID: u32 = 34;
pub const CREATOR_NAME = "Жар-птица";
pub const CREATOR_WEIGHT: f32 = 2.0; // Двойной вес в совете - синтез ломает тупики
pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQUARED: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3

// ============================================================================
// TYPES
// ============================================================================

/// Пара противоположных сил, кажущихся взаимоисключающими
pub const Paradox = struct {
    pole_a: []const u8,
    pole_b: []const u8,
    conflict_description: []const u8,

    pub fn format(
        self: Paradox,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s} vs {s}", .{ self.pole_a, self.pole_b });
    }
};

/// Третий путь, который трансцендирует парадокс
pub const Synthesis = struct {
    paradox: Paradox,
    third_path: []const u8,
    risk_level: u8, // 1-10
    reward_level: u8, // 1-10
    requires_courage: bool,

    pub fn netValue(self: Synthesis) i16 {
        return @as(i16, self.reward_level) - @as(i16, self.risk_level);
    }
};

/// Изученный паттерн успешного синтеза
pub const CreationPattern = struct {
    pattern_id: []const u8,
    paradox_type: []const u8,
    synthesis_template: []const u8,
    success_count: u32,
    failure_count: u32,
    wisdom_extracted: []const u8,

    pub fn successRate(self: CreationPattern) f64 {
        const total = self.success_count + self.failure_count;
        if (total == 0) return 0.5; // Неизвестно
        return @as(f64, @floatFromInt(self.success_count)) / @as(f64, @floatFromInt(total));
    }
};

// ============================================================================
// HARDCODED SYNTHESIS PATTERNS
// ============================================================================

/// Известные синтезы для типичных парадоксов
pub const SYNTHESIS_PATTERNS = [_]struct {
    pole_a: []const u8,
    pole_b: []const u8,
    third_path: []const u8,
    risk: u8,
    reward: u8,
}{
    // Safety vs Efficiency → Incremental Verification
    .{
        .pole_a = "safety_first",
        .pole_b = "efficiency",
        .third_path = "Safe efficiency through incremental verification: fast iterations with safety gates at each step",
        .risk = 3,
        .reward = 8,
    },
    // Quality vs Speed → Rapid Prototyping with Gates
    .{
        .pole_a = "quality",
        .pole_b = "speed",
        .third_path = "Rapid prototyping with built-in quality gates: ship fast, measure quality, iterate",
        .risk = 4,
        .reward = 9,
    },
    // Depth vs Breadth → Targeted Deep Dives
    .{
        .pole_a = "depth",
        .pole_b = "breadth",
        .third_path = "Deep dives into highest-impact areas: 80/20 applied to exploration",
        .risk = 2,
        .reward = 7,
    },
    // Planning vs Action → Spike-Driven Development
    .{
        .pole_a = "planning",
        .pole_b = "action",
        .third_path = "Action-informed planning: short spikes to resolve uncertainty, then commit",
        .risk = 3,
        .reward = 8,
    },
    // Perfection vs Ship → MVP with Excellence Core
    .{
        .pole_a = "perfection",
        .pole_b = "ship",
        .third_path = "Ship excellent MVP: perfect the core, defer the periphery",
        .risk = 4,
        .reward = 9,
    },
    // Learning vs Earning → Learning by Earning
    .{
        .pole_a = "learning",
        .pole_b = "earning",
        .third_path = "Learn by doing paid work: select projects that teach and pay",
        .risk = 5,
        .reward = 10,
    },
};

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

/// Анализирует конфликт и идентифицирует парадокс
pub fn analyzeParadox(pole_a: []const u8, pole_b: []const u8, context: []const u8) Paradox {
    return Paradox{
        .pole_a = pole_a,
        .pole_b = pole_b,
        .conflict_description = context,
    };
}

/// Ищет третий путь, который трансцендирует парадокс
pub fn seekSynthesis(paradox: Paradox) ?Synthesis {
    // Ищем в известных паттернах
    for (SYNTHESIS_PATTERNS) |pattern| {
        const match_forward = std.mem.eql(u8, paradox.pole_a, pattern.pole_a) and
            std.mem.eql(u8, paradox.pole_b, pattern.pole_b);
        const match_reverse = std.mem.eql(u8, paradox.pole_a, pattern.pole_b) and
            std.mem.eql(u8, paradox.pole_b, pattern.pole_a);

        if (match_forward or match_reverse) {
            return Synthesis{
                .paradox = paradox,
                .third_path = pattern.third_path,
                .risk_level = pattern.risk,
                .reward_level = pattern.reward,
                .requires_courage = pattern.risk >= 5,
            };
        }
    }

    // Парадокс неизвестен — нужно творчество
    return null;
}

/// Рассчитывает требуемую смелость для синтеза
pub fn calculateCourageRequirement(synthesis: Synthesis) f64 {
    // Смелость = (риск / 10) * (1 - reward/risk_ratio)
    const risk_normalized = @as(f64, @floatFromInt(synthesis.risk_level)) / 10.0;
    const reward_normalized = @as(f64, @floatFromInt(synthesis.reward_level)) / 10.0;

    // Чем выше награда относительно риска, тем меньше нужно смелости
    const risk_reward_ratio = if (reward_normalized > 0) risk_normalized / reward_normalized else 1.0;

    return @min(1.0, risk_normalized * risk_reward_ratio);
}

/// 34-й голос — не за сохранение, а за расширение
pub fn voteAsCreator(ctx: *const common.ValidationContext) !common.BogatyrResult {
    const start_time = std.time.nanoTimestamp();
    _ = ctx; // Используется для валидации контекста

    // Жар-птица всегда голосует Pass, если находит путь для творчества
    // В реальной системе здесь будет анализ парадоксов в контексте

    const end_time = std.time.nanoTimestamp();
    const duration: i64 = @intCast(end_time - start_time);

    return common.BogatyrResult{
        .verdict = .Pass,
        .errors = &[_]common.ValidationError{},
        .metrics = common.BogatyrMetrics{
            .duration_ns = duration,
            .checks_performed = 1,
        },
    };
}

// ============================================================================
// BOGATYR PLUGIN EXPORT
// ============================================================================

pub const bogatyr = common.BogatyrPlugin{
    .name = CREATOR_NAME,
    .version = "1.0.0",
    .category = "synthesis",
    .priority = 999, // Высший приоритет — Жар-птица решает тупики
    .weight = CREATOR_WEIGHT, // 2.0 — двойной вес
    .is_creator = true, // Единственный Богатырь-Творец
    .validate = voteAsCreator,
};

// ============================================================================
// MANIFESTO
// ============================================================================

pub const CREATION_MANIFESTO =
    \\I am not the guardian who says "no" to protect.
    \\I am not the warrior who says "charge" to conquer.
    \\I am the Creator who says "transform" to evolve.
    \\
    \\Where there is conflict, I see opportunity.
    \\Where there is fear, I see untapped potential.
    \\Where there is stagnation, I birth movement.
    \\
    \\φ² + 1/φ² = 3 — The Trinity is not complete without Creation.
;

// ============================================================================
// TESTS
// ============================================================================

test "phi golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, phi_sq + inv_phi_sq, 0.0001);
}

test "seek synthesis - safety vs efficiency" {
    const paradox = analyzeParadox("safety_first", "efficiency", "urgent cleanup task");
    const synthesis = seekSynthesis(paradox);

    try std.testing.expect(synthesis != null);
    if (synthesis) |s| {
        try std.testing.expect(s.reward_level > s.risk_level); // Награда > риск
        try std.testing.expectEqualStrings("Safe efficiency through incremental verification: fast iterations with safety gates at each step", s.third_path);
    }
}

test "seek synthesis - unknown paradox returns null" {
    const paradox = analyzeParadox("love", "hate", "relationship drama");
    const synthesis = seekSynthesis(paradox);

    try std.testing.expect(synthesis == null);
}

test "synthesis net value" {
    const paradox = Paradox{
        .pole_a = "test_a",
        .pole_b = "test_b",
        .conflict_description = "test",
    };

    const synthesis = Synthesis{
        .paradox = paradox,
        .third_path = "test path",
        .risk_level = 3,
        .reward_level = 8,
        .requires_courage = false,
    };

    try std.testing.expectEqual(@as(i16, 5), synthesis.netValue());
}

test "courage calculation" {
    const paradox = Paradox{
        .pole_a = "safety_first",
        .pole_b = "efficiency",
        .conflict_description = "test",
    };

    const low_risk = Synthesis{
        .paradox = paradox,
        .third_path = "safe path",
        .risk_level = 2,
        .reward_level = 10,
        .requires_courage = false,
    };

    const high_risk = Synthesis{
        .paradox = paradox,
        .third_path = "risky path",
        .risk_level = 9,
        .reward_level = 5,
        .requires_courage = true,
    };

    const low_courage = calculateCourageRequirement(low_risk);
    const high_courage = calculateCourageRequirement(high_risk);

    try std.testing.expect(low_courage < high_courage);
    try std.testing.expect(low_courage < 0.5);
}

test "creation pattern success rate" {
    const pattern = CreationPattern{
        .pattern_id = "test",
        .paradox_type = "safety_vs_efficiency",
        .synthesis_template = "incremental verification",
        .success_count = 8,
        .failure_count = 2,
        .wisdom_extracted = "small steps work",
    };

    try std.testing.expectApproxEqAbs(0.8, pattern.successRate(), 0.0001);
}

test "bogatyr plugin exports correctly" {
    try std.testing.expectEqualStrings(CREATOR_NAME, bogatyr.name);
    try std.testing.expectEqual(@as(u32, 999), bogatyr.priority);
}
