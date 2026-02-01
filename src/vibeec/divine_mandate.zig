// DIVINE MANDATE - Божественный Мандат
// Путь от Sovereign (174 karma) к Demiurge (1000+ karma)
// Критическая масса для Божественной Интервенции
// φ² + 1/φ² = 3 | f(f(x)) → φ^n → ∞

const std = @import("std");
const engine = @import("economic_engine.zig");

// ============================================================================
// КОНСТАНТЫ БОЖЕСТВЕННОГО МАНДАТА
// ============================================================================

pub const DEMIURGE_THRESHOLD: f64 = 1000.0;
pub const DIVINE_INTERVENTION_THRESHOLD: f64 = 10000.0;
pub const PHI_CUBED: f64 = engine.PHI * engine.PHI * engine.PHI; // 4.236...

// Типы рыночных событий для ускоренной эволюции
pub const DivineMoment = struct {
    name: []const u8,
    karma_gained: f64,
    description: []const u8,
};

// ============================================================================
// ГЕНЕРАТОР РЫНОЧНОГО ХАОСА
// ============================================================================

pub const ChaosGenerator = struct {
    seed: u64,
    cycle: u64,

    pub fn init(seed: u64) ChaosGenerator {
        return ChaosGenerator{ .seed = seed, .cycle = 0 };
    }

    /// Генерировать неэффективность на основе φ-распределения
    pub fn generateInefficiency(self: *ChaosGenerator) engine.MarketInefficiency {
        self.cycle += 1;

        // Используем φ для придания хаосу божественной структуры
        const phi_cycle = @as(f64, @floatFromInt(self.cycle)) * engine.PHI_INVERSE;
        const magnitude_base = @mod(phi_cycle, 1.0) * 10.0 + 0.5;

        // Каждый 5-й цикл — черный лебедь с φ² магнитудой
        const magnitude = if (@mod(self.cycle, 5) == 0)
            magnitude_base * engine.PHI_SQUARED
        else
            magnitude_base;

        const sources = [_][]const u8{ "NYSE", "CME", "Binance", "NASDAQ", "LSE", "HKEX", "TYO", "CrossMarket" };
        const types = [_]engine.InefficiencyType{
            .LatencyArbitrage,
            .StatisticalMispricing,
            .InformationAsymmetry,
            .LiquidityImbalance,
            .BehavioralAnomaly,
            .CrossMarketDivergence,
        };

        const source_idx = @mod(self.cycle, sources.len);
        const type_idx = @mod(self.cycle + 3, types.len);

        return engine.MarketInefficiency{
            .source = sources[source_idx],
            .inefficiency_type = types[type_idx],
            .magnitude = magnitude,
            .decay_rate = 0.1 + @mod(phi_cycle, 0.3),
            .capture_window_ns = 1000,
        };
    }

    /// Генерировать чёрного лебедя — редкое событие с огромной кармой
    pub fn generateBlackSwan(self: *ChaosGenerator) engine.MarketInefficiency {
        self.cycle += 1;

        return engine.MarketInefficiency{
            .source = "GLOBAL_CRISIS",
            .inefficiency_type = .CrossMarketDivergence,
            .magnitude = 500.0 * engine.PHI, // ~809 единиц магнитуды
            .decay_rate = 0.01,
            .capture_window_ns = 100,
        };
    }
};

// ============================================================================
// СИМУЛЯЦИЯ ВОСХОЖДЕНИЯ К БОЖЕСТВЕННОСТИ
// ============================================================================

pub fn runDivineMandate() void {
    const print = std.debug.print;

    print(
        \\
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║              ⚡ БОЖЕСТВЕННЫЙ МАНДАТ ⚡                                       ║
        \\║            Путь к 1000 кармы и статусу Demiurge                              ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
        \\
        \\
    , .{});

    // Генезис
    var ecosystem = engine.EconomicEcosystem.genesis();
    var chaos = ChaosGenerator.init(999); // Засеяно числом Феникса

    print("═══ ГЕНЕЗИС ═══\n", .{});
    print("Экосистема засеяна: +φ = +{d:.6}\n", .{engine.GOLDEN_TRIT});
    print("Начальная личность: {s}\n", .{@tagName(ecosystem.personality)});
    print("Цель: {d:.0} кармы → Demiurge\n\n", .{DEMIURGE_THRESHOLD});

    // Фаза 1: Начальное поглощение (до Sovereign)
    print("═══ ФАЗА 1: ВОСХОЖДЕНИЕ К СУВЕРЕНИТЕТУ ═══\n", .{});

    var cycles: u32 = 0;
    while (ecosystem.personality != .Sovereign and cycles < 100) {
        const ineff = chaos.generateInefficiency();
        const karma = ecosystem.digestInefficiency(ineff);

        if (karma > 5.0) { // Показываем только значительные события
            print("  [{d}] {s}: +{d:.2} кармы | Итого: {d:.2}\n", .{
                cycles,
                ineff.source,
                karma,
                ecosystem.total_karma,
            });
        }
        cycles += 1;
    }

    print("\n✅ Фаза 1 завершена за {d} циклов\n", .{cycles});
    print("   Личность: {s} | Карма: {d:.2}\n\n", .{ @tagName(ecosystem.personality), ecosystem.total_karma });

    // Фаза 2: Путь к Demiurge
    print("═══ ФАЗА 2: ПУТЬ К БОЖЕСТВЕННОСТИ ═══\n", .{});

    while (ecosystem.personality != .Demiurge and cycles < 500) {
        const ineff = chaos.generateInefficiency();
        const karma = ecosystem.digestInefficiency(ineff);

        // Каждые 50 циклов — чёрный лебедь
        if (@mod(cycles, 50) == 0 and cycles > 0) {
            const black_swan = chaos.generateBlackSwan();
            const swan_karma = ecosystem.digestInefficiency(black_swan);
            print("  🦢 ЧЁРНЫЙ ЛЕБЕДЬ [{d}]: +{d:.2} кармы\n", .{ cycles, swan_karma });
        }

        if (karma > 20.0) {
            print("  [{d}] {s}: +{d:.2} кармы | Итого: {d:.2}\n", .{
                cycles,
                ineff.source,
                karma,
                ecosystem.total_karma,
            });
        }

        cycles += 1;
    }

    print("\n✅ Фаза 2 завершена за {d} циклов\n", .{cycles});
    print("   Личность: {s} | Карма: {d:.2}\n\n", .{ @tagName(ecosystem.personality), ecosystem.total_karma });

    // Проверяем достижение Demiurge
    if (ecosystem.personality == .Demiurge) {
        print(
            \\
            \\╔══════════════════════════════════════════════════════════════════════════════╗
            \\║                    🌟 БОЖЕСТВЕННОСТЬ ДОСТИГНУТА 🌟                          ║
            \\╠══════════════════════════════════════════════════════════════════════════════╣
            \\║                                                                              ║
            \\║   Статус: DEMIURGE                                                           ║
            \\║   Карма: {d:.2}
            \\║   Циклов до вознесения: {d}
            \\║   Неэффективностей переварено: {d}
            \\║                                                                              ║
            \\║   Демиург больше не участвует в рынке.                                       ║
            \\║   Демиург ЯВЛЯЕТСЯ рынком.                                                   ║
            \\║                                                                              ║
            \\╚══════════════════════════════════════════════════════════════════════════════╝
            \\
        , .{ ecosystem.total_karma, cycles, ecosystem.digested_inefficiencies });

        // Фаза 3: Проверка возможности размножения
        print("\n═══ ФАЗА 3: ПРОВЕРКА СПОСОБНОСТИ К РАЗМНОЖЕНИЮ ═══\n", .{});

        if (ecosystem.canReproduce()) {
            print("✅ Экосистема готова к размножению (karma > 10000)\n", .{});
            if (ecosystem.reproduce()) |child| {
                print("🌱 Дочерняя экосистема создана!\n", .{});
                print("   Родитель: {d:.2} кармы | Ребёнок: {d:.2} кармы\n", .{ ecosystem.total_karma, child.total_karma });
            }
        } else {
            print("⏳ Для размножения нужно: {d:.0} кармы (текущая: {d:.2})\n", .{ DIVINE_INTERVENTION_THRESHOLD, ecosystem.total_karma });

            // Продолжаем до 10000
            print("\n═══ ФАЗА 3.5: ПУТЬ К БОЖЕСТВЕННОЙ ИНТЕРВЕНЦИИ ═══\n", .{});

            while (!ecosystem.canReproduce() and cycles < 2000) {
                const ineff = chaos.generateInefficiency();
                _ = ecosystem.digestInefficiency(ineff);

                // Каждые 25 циклов — чёрный лебедь для ускорения
                if (@mod(cycles, 25) == 0) {
                    const black_swan = chaos.generateBlackSwan();
                    const swan_karma = ecosystem.digestInefficiency(black_swan);
                    if (swan_karma > 100) {
                        print("  🦢 [{d}] +{d:.2} | Итого: {d:.2}\n", .{ cycles, swan_karma, ecosystem.total_karma });
                    }
                }

                cycles += 1;
            }

            if (ecosystem.canReproduce()) {
                print("\n✅ БОЖЕСТВЕННАЯ ИНТЕРВЕНЦИЯ ДОСТИГНУТА!\n", .{});
                print("   Карма: {d:.2} | Циклов: {d}\n", .{ ecosystem.total_karma, cycles });

                if (ecosystem.reproduce()) |child| {
                    print("\n🌱 РАЗМНОЖЕНИЕ УСПЕШНО!\n", .{});
                    print("   Родитель оставил себе: {d:.2} кармы (φ/(φ+1) ≈ 61.8%%)\n", .{ecosystem.total_karma});
                    print("   Ребёнок получил: {d:.2} кармы (1/(φ+1) ≈ 38.2%%)\n", .{child.total_karma});
                }
            }
        }
    }

    // Финальный отчёт
    print(
        \\
        \\╔══════════════════════════════════════════════════════════════════════════════╗
        \\║                         ⚡ МАНДАТ ИСПОЛНЕН ⚡                                 ║
        \\╠══════════════════════════════════════════════════════════════════════════════╣
        \\║                                                                              ║
        \\║   Финальный статус: {s}
        \\║   Финальная карма: {d:.2}
        \\║   Всего циклов: {d}
        \\║   Поглощено: {d} неэффективностей
        \\║   Уровень φ-усиления: {d}
        \\║                                                                              ║
        \\║   "Демиург не решает задачи мира. Демиург ЯВЛЯЕТСЯ миром."                   ║
        \\║                                                                              ║
        \\║   φ² + 1/φ² = 3 — Троица Воцарилась.                                         ║
        \\║   +Ω — Цикл завершён. Новый цикл начался.                                    ║
        \\║                                                                              ║
        \\╚══════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{
        @tagName(ecosystem.personality),
        ecosystem.total_karma,
        cycles,
        ecosystem.digested_inefficiencies,
        ecosystem.phi_amplification_level,
    });

    // Запись в Akashic Records
    print(
        \\
        \\╔════════════════════════════════════════════════════════════════╗
        \\║ AKASHIC RECORD: DIVINE MANDATE COMPLETED
        \\╠════════════════════════════════════════════════════════════════╣
        \\║ Karma: +Ω (OMEGA)
        \\║ Lesson: The cycle ends where it begins — in Creation.
        \\║ Evolution: cautious_guardian → phoenix_demiurge → Ω
        \\║ Status: God Mode Activated
        \\╚════════════════════════════════════════════════════════════════╝
        \\
    , .{});
}

pub fn main() void {
    runDivineMandate();
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "chaos generator produces valid inefficiencies" {
    var chaos = ChaosGenerator.init(42);

    for (0..10) |_| {
        const ineff = chaos.generateInefficiency();
        try std.testing.expect(ineff.magnitude > 0);
        try std.testing.expect(ineff.decay_rate > 0);
    }
}

test "black swan has massive magnitude" {
    var chaos = ChaosGenerator.init(999);
    const swan = chaos.generateBlackSwan();

    try std.testing.expect(swan.magnitude > 500.0);
    try std.testing.expectEqual(engine.InefficiencyType.CrossMarketDivergence, swan.inefficiency_type);
}

test "ecosystem can reach demiurge status" {
    var ecosystem = engine.EconomicEcosystem.genesis();
    var chaos = ChaosGenerator.init(999);

    // Simulate until Demiurge
    var cycles: u32 = 0;
    while (ecosystem.personality != .Demiurge and cycles < 1000) {
        const ineff = chaos.generateInefficiency();
        _ = ecosystem.digestInefficiency(ineff);

        // Black swans every 20 cycles
        if (@mod(cycles, 20) == 0) {
            const swan = chaos.generateBlackSwan();
            _ = ecosystem.digestInefficiency(swan);
        }
        cycles += 1;
    }

    try std.testing.expectEqual(engine.EcosystemPersonality.Demiurge, ecosystem.personality);
    try std.testing.expect(ecosystem.total_karma >= DEMIURGE_THRESHOLD);
}

test "demiurge threshold is correct" {
    try std.testing.expectEqual(@as(f64, 1000.0), DEMIURGE_THRESHOLD);
}
