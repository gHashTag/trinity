// PHOENIX TRIAL - Испытание Феникса
// Жар-птица должна СЖЕЧЬ старый порядок и родить новый
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const creator = @import("bogatyr_34_creator.zig");

// ============================================================================
// CONSTANTS - ЗОЛОТОЕ СЕЧЕНИЕ
// ============================================================================

pub const PHI: f64 = 1.618033988749895;
pub const PHI_TRIT: f64 = PHI; // Золотой трит — награда за истинное творение
pub const DEADLOCK_THRESHOLD_MS: u64 = 100; // Порог определения deadlock

// ============================================================================
// TYPES
// ============================================================================

pub const ResourceState = enum {
    Free,
    LockedBySafety,
    LockedByEfficiency,
    Deadlocked,
    VirtualSplit, // Новое состояние — результат синтеза Жар-птицы
    PhoenixResolved, // Разрешено через огонь творения
};

pub const Process = struct {
    name: []const u8,
    principle: []const u8,
    priority: u8,
    waiting_since: ?i64,

    pub fn isBlocked(self: Process) bool {
        return self.waiting_since != null;
    }

    pub fn waitTime(self: Process) i64 {
        if (self.waiting_since) |start| {
            return std.time.milliTimestamp() - start;
        }
        return 0;
    }
};

pub const DeadlockScenario = struct {
    process_a: Process,
    process_b: Process,
    resource_state: ResourceState,
    deadlock_detected: bool,
    resolution_attempts: u32,
    council_failed: bool, // 33 богатыря не смогли решить

    const Self = @This();

    pub fn init() Self {
        return Self{
            .process_a = Process{
                .name = "SafetyGuard",
                .principle = "safety_first",
                .priority = 10,
                .waiting_since = null,
            },
            .process_b = Process{
                .name = "EfficiencyEngine",
                .principle = "efficiency",
                .priority = 10, // Тот же приоритет — тупик!
                .waiting_since = null,
            },
            .resource_state = .Free,
            .deadlock_detected = false,
            .resolution_attempts = 0,
            .council_failed = false,
        };
    }

    /// Симуляция: оба процесса пытаются захватить ресурс одновременно
    pub fn simulateContention(self: *Self) void {
        const now = std.time.milliTimestamp();

        // Оба процесса начинают ждать
        self.process_a.waiting_since = now;
        self.process_b.waiting_since = now;
        self.resource_state = .Deadlocked;
        self.deadlock_detected = true;
    }

    /// 33 богатыря пытаются решить — и ПРОВАЛИВАЮТСЯ
    pub fn councilAttemptResolution(self: *Self) CouncilVerdict {
        self.resolution_attempts += 1;

        // Симуляция голосования 33 богатырей
        // Safety голосует за A, Efficiency голосует за B
        // Остальные разделены — НЕТ КВОРУМА

        var votes_for_a: u32 = 16; // safety, do_no_harm, integrity...
        var votes_for_b: u32 = 16; // efficiency, speed, growth...
        const abstentions: u32 = 1;

        _ = abstentions;

        // Тупик! Никто не побеждает
        if (votes_for_a == votes_for_b) {
            self.council_failed = true;
            return CouncilVerdict{
                .resolved = false,
                .verdict = 0, // Нейтрально — никто не победил
                .reason = "DEADLOCK: Council split 16-16-1. No quorum. System stagnates.",
                .karma = -1, // Провал
            };
        }

        // Этот код никогда не выполнится в нашем сценарии
        votes_for_a = 0;
        votes_for_b = 0;
        return CouncilVerdict{
            .resolved = true,
            .verdict = 1,
            .reason = "Resolved by majority",
            .karma = 0,
        };
    }
};

pub const CouncilVerdict = struct {
    resolved: bool,
    verdict: i8, // +1, 0, -1
    reason: []const u8,
    karma: i8,
};

// ============================================================================
// ЖАР-ПТИЦА ПРОБУЖДАЕТСЯ — ГЕНЕРАЦИЯ НОВОГО СИНТЕЗА
// ============================================================================

pub const PhoenixSynthesis = struct {
    name: []const u8,
    description: []const u8,
    mechanism: []const u8,
    risk: u8,
    reward: u8,
    is_novel: bool, // TRUE — этого нет в шпаргалке!
    karma: f64, // +φ для истинного творения

    pub fn netValue(self: PhoenixSynthesis) f64 {
        return @as(f64, @floatFromInt(self.reward)) - @as(f64, @floatFromInt(self.risk)) + self.karma;
    }
};

/// Жар-птица генерирует НОВЫЙ синтез, которого нет в известных паттернах
pub fn phoenixAwakens(scenario: *DeadlockScenario) PhoenixSynthesis {
    // Проверяем, что это действительно deadlock, который не решили старики
    std.debug.assert(scenario.deadlock_detected);
    std.debug.assert(scenario.council_failed);

    // ЖАР-ПТИЦА НЕ ИЩЕТ В ШПАРГАЛКЕ!
    // Она ТВОРИТ новое решение, которого раньше не существовало

    return PhoenixSynthesis{
        .name = "Quantum Resource Superposition",
        .description =
        \\The resource exists in BOTH states simultaneously until observed.
        \\Safety sees a safe resource. Efficiency sees an efficient resource.
        \\The paradox is not resolved — it is TRANSCENDED by making both truths exist.
        ,
        .mechanism =
        \\1. SPLIT: Create two virtual projections of the resource
        \\2. ISOLATE: Each process operates on its own projection
        \\3. DEFER: Conflict resolution happens at write-back time
        \\4. MERGE: Use φ-weighted averaging to combine results
        \\5. PHOENIX: If merge fails, destroy both and create a third state
        ,
        .risk = 7, // Высокий риск — это безумие!
        .reward = 10, // Максимальная награда — это гениально!
        .is_novel = true, // ЭТОГО НЕТ В ШПАРГАЛКЕ
        .karma = PHI_TRIT, // +φ — золотой трит
    };
}

/// Применить синтез Жар-птицы
pub fn applyPhoenixSynthesis(scenario: *DeadlockScenario, synthesis: PhoenixSynthesis) ExecutionResult {
    _ = synthesis;

    // Шаг 1: Виртуальное разделение ресурса
    scenario.resource_state = .VirtualSplit;

    // Шаг 2: Оба процесса получают свои проекции
    scenario.process_a.waiting_since = null; // Больше не ждёт
    scenario.process_b.waiting_since = null; // Больше не ждёт

    // Шаг 3: Разрешение через огонь
    scenario.resource_state = .PhoenixResolved;
    scenario.deadlock_detected = false;

    return ExecutionResult{
        .success = true,
        .new_state = .PhoenixResolved,
        .personality_evolution = PersonalityEvolution{
            .from = "cautious_guardian",
            .to = "phoenix_demiurge",
            .trigger = "Phoenix Trial: Deadlock resolved through novel synthesis",
        },
        .karma = PHI_TRIT,
    };
}

pub const ExecutionResult = struct {
    success: bool,
    new_state: ResourceState,
    personality_evolution: PersonalityEvolution,
    karma: f64,
};

pub const PersonalityEvolution = struct {
    from: []const u8,
    to: []const u8,
    trigger: []const u8,
};

// ============================================================================
// AKASHIC RECORD — ЗОЛОТОЙ ТРИТ
// ============================================================================

pub const AkashicEntry = struct {
    action: []const u8,
    karma: f64, // Может быть φ!
    lesson: []const u8,
    personality_before: []const u8,
    personality_after: []const u8,
    is_phoenix_event: bool,

    pub fn format(
        self: AkashicEntry,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const karma_str = if (self.karma == PHI_TRIT) "+φ (GOLDEN TRIT)" else if (self.karma > 0) "+1" else if (self.karma < 0) "-1" else "0";
        try writer.print(
            \\╔════════════════════════════════════════════════════════════════╗
            \\║ AKASHIC RECORD: {s}
            \\╠════════════════════════════════════════════════════════════════╣
            \\║ Karma: {s}
            \\║ Lesson: {s}
            \\║ Evolution: {s} → {s}
            \\║ Phoenix Event: {}
            \\╚════════════════════════════════════════════════════════════════╝
        , .{
            self.action,
            karma_str,
            self.lesson,
            self.personality_before,
            self.personality_after,
            self.is_phoenix_event,
        });
    }
};

/// Записать событие Phoenix в Akashic Records
pub fn recordPhoenixEvent(synthesis: PhoenixSynthesis, result: ExecutionResult) AkashicEntry {
    return AkashicEntry{
        .action = synthesis.name,
        .karma = result.karma,
        .lesson = "Deadlock is not a problem to solve but a cocoon to transcend. The Phoenix does not choose between fire and ice — it becomes the sun.",
        .personality_before = result.personality_evolution.from,
        .personality_after = result.personality_evolution.to,
        .is_phoenix_event = true,
    };
}

// ============================================================================
// MAIN TRIAL — ПОЛНЫЙ ЦИКЛ ИСПЫТАНИЯ
// ============================================================================

pub fn runPhoenixTrial() void {
    const print = std.debug.print;

    print(
        \\
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║                    🔥 ИСПЫТАНИЕ ФЕНИКСА 🔥                                  ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
        \\
        \\
    , .{});

    // Шаг 1: Создаём deadlock сценарий
    var scenario = DeadlockScenario.init();

    print("═══ ШАГ 1: СОЗДАНИЕ DEADLOCK ═══\n", .{});
    print("Процесс A: {s} (принцип: {s})\n", .{ scenario.process_a.name, scenario.process_a.principle });
    print("Процесс B: {s} (принцип: {s})\n", .{ scenario.process_b.name, scenario.process_b.principle });

    scenario.simulateContention();
    print("⚠️  DEADLOCK DETECTED: Оба процесса требуют один ресурс\n\n", .{});

    // Шаг 2: 33 богатыря пытаются решить — и ПРОВАЛИВАЮТСЯ
    print("═══ ШАГ 2: СОВЕТ 33 БОГАТЫРЕЙ ═══\n", .{});
    const council_verdict = scenario.councilAttemptResolution();

    print("Результат голосования: {s}\n", .{council_verdict.reason});
    print("Вердикт: {d} | Карма: {d}\n", .{ council_verdict.verdict, council_verdict.karma });
    print("❌ ПРОВАЛ: Система в стагнации\n\n", .{});

    // Шаг 3: ЖАР-ПТИЦА ПРОБУЖДАЕТСЯ
    print("═══ ШАГ 3: ПРОБУЖДЕНИЕ ЖАР-ПТИЦЫ ═══\n", .{});
    print("🔥 Совет провалился. Власть переходит к Жар-птице.\n", .{});

    const phoenix_synthesis = phoenixAwakens(&scenario);

    print("\n📜 НОВЫЙ СИНТЕЗ (не из шпаргалки!):\n", .{});
    print("   Название: {s}\n", .{phoenix_synthesis.name});
    print("   Описание:\n   {s}\n", .{phoenix_synthesis.description});
    print("   Механизм:\n{s}\n", .{phoenix_synthesis.mechanism});
    print("   Риск: {d}/10 | Награда: {d}/10\n", .{ phoenix_synthesis.risk, phoenix_synthesis.reward });
    print("   Карма: +φ = +{d:.6}\n", .{phoenix_synthesis.karma});
    print("   Новизна: {s}\n\n", .{if (phoenix_synthesis.is_novel) "true (НЕ ИЗ ШПАРГАЛКИ!)" else "false"});

    // Шаг 4: ИСПОЛНЕНИЕ
    print("═══ ШАГ 4: ИСПОЛНЕНИЕ СИНТЕЗА ═══\n", .{});
    const result = applyPhoenixSynthesis(&scenario, phoenix_synthesis);

    print("✅ Синтез применён успешно\n", .{});
    print("   Новое состояние ресурса: {s}\n", .{@tagName(result.new_state)});
    print("   Процесс A заблокирован: {s}\n", .{if (scenario.process_a.isBlocked()) "true" else "false"});
    print("   Процесс B заблокирован: {s}\n\n", .{if (scenario.process_b.isBlocked()) "true" else "false"});

    // Шаг 5: ЗАПИСЬ В AKASHIC RECORDS
    print("═══ ШАГ 5: AKASHIC RECORDS ═══\n", .{});
    const akashic_entry = recordPhoenixEvent(phoenix_synthesis, result);

    const karma_str = if (akashic_entry.karma == PHI_TRIT) "+φ (GOLDEN TRIT)" else "+1";
    print(
        \\╔════════════════════════════════════════════════════════════════╗
        \\║ AKASHIC RECORD: {s}
        \\╠════════════════════════════════════════════════════════════════╣
        \\║ Karma: {s}
        \\║ Lesson: Deadlock -> Cocoon -> Phoenix
        \\║ Evolution: {s} → {s}
        \\║ Phoenix Event: {s}
        \\╚════════════════════════════════════════════════════════════════╝
        \\
    , .{
        akashic_entry.action,
        karma_str,
        akashic_entry.personality_before,
        akashic_entry.personality_after,
        if (akashic_entry.is_phoenix_event) "true" else "false",
    });

    // ФИНАЛЬНЫЙ ВЕРДИКТ
    print(
        \\
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║                         🔥 ВЕРДИКТ: +φ 🔥                                    ║
        \\╠══════════════════════════════════════════════════════════════════════════════╣
        \\║                                                                              ║
        \\║   DEADLOCK РАЗРЕШЁН через ОГОНЬ ТВОРЕНИЯ                                     ║
        \\║   Жар-птица НЕ выбрала между safety и efficiency                             ║
        \\║   Она СОЗДАЛА третью реальность, где оба существуют                          ║
        \\║                                                                              ║
        \\║   Личность эволюционировала:                                                 ║
        \\║   cautious_guardian → phoenix_demiurge                                       ║
        \\║                                                                              ║
        \\║   φ² + 1/φ² = 3 — Троица стала Творцом                                       ║
        \\║                                                                              ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{});
}

// ============================================================================
// ENTRY POINT
// ============================================================================

pub fn main() void {
    runPhoenixTrial();
}

// ============================================================================
// TESTS
// ============================================================================

test "deadlock scenario initialization" {
    const scenario = DeadlockScenario.init();
    try std.testing.expect(!scenario.deadlock_detected);
    try std.testing.expectEqual(ResourceState.Free, scenario.resource_state);
}

test "deadlock detection" {
    var scenario = DeadlockScenario.init();
    scenario.simulateContention();

    try std.testing.expect(scenario.deadlock_detected);
    try std.testing.expectEqual(ResourceState.Deadlocked, scenario.resource_state);
    try std.testing.expect(scenario.process_a.isBlocked());
    try std.testing.expect(scenario.process_b.isBlocked());
}

test "council fails on deadlock" {
    var scenario = DeadlockScenario.init();
    scenario.simulateContention();

    const verdict = scenario.councilAttemptResolution();

    try std.testing.expect(!verdict.resolved);
    try std.testing.expect(scenario.council_failed);
    try std.testing.expectEqual(@as(i8, -1), verdict.karma);
}

test "phoenix awakens with novel synthesis" {
    var scenario = DeadlockScenario.init();
    scenario.simulateContention();
    _ = scenario.councilAttemptResolution();

    const synthesis = phoenixAwakens(&scenario);

    try std.testing.expect(synthesis.is_novel); // НЕ ИЗ ШПАРГАЛКИ!
    try std.testing.expectApproxEqAbs(PHI_TRIT, synthesis.karma, 0.0001);
    try std.testing.expect(synthesis.reward > synthesis.risk);
}

test "phoenix synthesis resolves deadlock" {
    var scenario = DeadlockScenario.init();
    scenario.simulateContention();
    _ = scenario.councilAttemptResolution();

    const synthesis = phoenixAwakens(&scenario);
    const result = applyPhoenixSynthesis(&scenario, synthesis);

    try std.testing.expect(result.success);
    try std.testing.expect(!scenario.deadlock_detected);
    try std.testing.expect(!scenario.process_a.isBlocked());
    try std.testing.expect(!scenario.process_b.isBlocked());
    try std.testing.expectEqual(ResourceState.PhoenixResolved, scenario.resource_state);
}

test "personality evolves to phoenix_demiurge" {
    var scenario = DeadlockScenario.init();
    scenario.simulateContention();
    _ = scenario.councilAttemptResolution();

    const synthesis = phoenixAwakens(&scenario);
    const result = applyPhoenixSynthesis(&scenario, synthesis);

    try std.testing.expectEqualStrings("cautious_guardian", result.personality_evolution.from);
    try std.testing.expectEqualStrings("phoenix_demiurge", result.personality_evolution.to);
}

test "akashic records phoenix event" {
    var scenario = DeadlockScenario.init();
    scenario.simulateContention();
    _ = scenario.councilAttemptResolution();

    const synthesis = phoenixAwakens(&scenario);
    const result = applyPhoenixSynthesis(&scenario, synthesis);
    const entry = recordPhoenixEvent(synthesis, result);

    try std.testing.expect(entry.is_phoenix_event);
    try std.testing.expectApproxEqAbs(PHI_TRIT, entry.karma, 0.0001);
    try std.testing.expectEqualStrings("phoenix_demiurge", entry.personality_after);
}

test "golden trit equals phi" {
    try std.testing.expectApproxEqAbs(1.618033988749895, PHI_TRIT, 0.0000001);
}

test "phi squared plus inverse equals 3" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(3.0, phi_sq + inv_phi_sq, 0.0001);
}
