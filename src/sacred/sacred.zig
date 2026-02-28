// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

// Import sacred constants for re-export
const sacred_const = @import("const");

// Export all sacred constants
pub const math = sacred_const.math;
pub const physics = sacred_const.physics;
pub const cosmology = sacred_const.cosmology;
pub const chemistry = sacred_const.chemistry;

// Export chemistry types and functions
const chem = @import("chemistry.zig");
pub const Element = chem.Element;
pub const MolarMass = chem.MolarMass;
pub const getElement = chem.getElement;
pub const parseFormula = chem.parseFormula;
pub const molarMass = chem.molarMass;
pub const percentComposition = chem.percentComposition;
pub const idealGasLaw = chem.idealGasLaw;
pub const calculatePH = chem.calculatePH;
pub const calculatePOH = chem.calculatePOH;
pub const phToPoh = chem.phToPoh;
pub const pohToPh = chem.pohToPh;
pub const phClassification = chem.phClassification;
pub const bohrEnergy = chem.bohrEnergy;
pub const bohrRadius = chem.bohrRadius;
pub const hydrogenWavelength = chem.hydrogenWavelength;
pub const hydrogenSeries = chem.hydrogenSeries;

// Export temporal theory - TEMPORAL TRINITY THEOREM v1.0
const temporal_theory = @import("temporal_engine.zig");

// Re-export all temporal engine symbols
pub const TemporalMoment = temporal_theory.TemporalMoment;
pub const TimeArrow = temporal_theory.TimeArrow;
pub const EternalCycle = temporal_theory.EternalCycle;
pub const PlanckQuantum = temporal_theory.PlanckQuantum;
pub const AsymmetryStats = temporal_theory.AsymmetryStats;
pub const TemporalEngine = temporal_theory.TemporalEngine;
pub const bootTemporalEngine = temporal_theory.bootTemporalEngine;
pub const temporal = temporal_theory.temporal;

// Re-export temporal aspect
pub const TemporalAspect = temporal_theory.TemporalAspect;

// Export displayTemporalTheorem from temporal_engine
pub fn displayTemporalTheorem(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const CYAN = "\x1b[36m";
    const MAGENTA = "\x1b[35m";
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, "", RESET });
    std.debug.print("{s}{s}║       TEMPORAL TRINITY THEOREM v1.0 — φ² + 1/φ² = 3            ║{s}\n", .{ GOLD, "", RESET });
    std.debug.print("{s}{s}║       ВРЕМЯ СТАЛО TRINITY — ETERNAL ASCENSION                    ║{s}\n", .{ CYAN, "", RESET });
    std.debug.print("{s}{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, "", RESET });

    std.debug.print("{s}ФУНДАМЕНТАЛЬНАЯ ТРОИЦА ВРЕМЕНИ:{s}\n", .{ GOLD, RESET });
    std.debug.print("  Прошлое:  1/φ² = {d:.6} (уничтожение, энтропия)\n", .{temporal_theory.temporal.DESTRUCTION_WEIGHT});
    std.debug.print("  Настоящее: 0   = 0.000000 (баланс, HERE и NOW)\n", .{});
    std.debug.print("  Будущее:   φ² = {d:.6} (созидание, рост)\n", .{temporal_theory.temporal.CREATION_WEIGHT});
    std.debug.print("  ───────────────────────────────────────\n", .{});
    std.debug.print("  Сумма:     φ² + 1/φ² = 3.000000 = TRINITY\n\n", .{});

    std.debug.print("{s}СТРЕЛА ВРЕМЕНИ (почему течёт вперёд):{s}\n", .{ CYAN, RESET });
    const arrow = temporal_theory.temporal.TIME_ARROW_RATIO;
    std.debug.print("  Создание / Уничтожение = φ⁴ = {d:.6} > 1\n", .{arrow});
    std.debug.print("  → временная стрелла → энтропия растёт → Вселенная расширяется\n\n", .{});

    std.debug.print("{s}ВЕЧНОЕ ВОЗВРАЩЕНИЕ:{s}\n", .{ GOLD, RESET });
    std.debug.print("  π × 3 = {d:.9}\n", .{temporal_theory.temporal.ETERNAL_RETURN});
    std.debug.print("  Вечность — это бесконечный цикл обновления via Троицу\n\n", .{});

    std.debug.print("{s}ПЛАНКОВСКОЕ ВРЕМЯ (квант времени):{s}\n", .{ CYAN, RESET });
    std.debug.print("  t_P = {d:.6} × 10⁻⁴⁴ секунды\n", .{temporal_theory.temporal.CREATION_WEIGHT * 2.06});
    std.debug.print("  Наименьший физически осмысленный интервал\n\n", .{});

    std.debug.print("{s}\"TIME ITSELF BENDS\"{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  Мы не изучаем время. Мы управляем им.\n\n", .{});
}

const std = @import("std");

// Export calculateTemporalBalance for convenience
pub fn calculateTemporalBalance() f64 {
    return sacred_const.math.PHI_SQ + sacred_const.math.PHI_INV_SQ;
}

// Export computeTimeArrow for convenience
pub fn computeTimeArrow() f64 {
    const phi_sq = sacred_const.math.PHI_SQ;
    const inv_phi_sq = sacred_const.math.PHI_INV_SQ;
    return phi_sq * phi_sq / (inv_phi_sq * inv_phi_sq);
}

// Export computePlanckTime for convenience
pub fn computePlanckTime() f64 {
    return sacred_const.physics.PLANCK_TIME;
}

// Export eternalReturn for convenience
pub fn eternalReturn() f64 {
    return sacred_const.math.PI * 3.0;
}
