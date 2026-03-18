// @origin(spec:ternary_schedule.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Ternary 3-Phase LR Schedule
// 3-phase (warmup/cruise/cooldown) × 3 cycles with φ-decaying max LR.
// Cycle 1: max_lr, Cycle 2: max_lr × 0.618, Cycle 3: max_lr × 0.382.

const std = @import("std");
const phi_scaling = @import("phi_scaling.zig");

pub const TernarySchedule = struct {
    max_lr: f32,
    min_lr: f32,
    /// Phase boundaries within each cycle (fractions)
    warmup_frac: f32 = 0.10, // 10%
    cruise_frac: f32 = 0.60, // 60%
    // cooldown = remaining 30%

    /// Get learning rate for given step.
    /// 3 cycles, each with warmup → cruise → cooldown.
    pub fn getLR(self: TernarySchedule, step: u64, total_steps: u64) f32 {
        return self.getLRDecaying(step, total_steps, self.max_lr);
    }

    /// Get LR with φ-decaying max per cycle.
    /// Cycle 0: max_lr × 1.0, Cycle 1: max_lr × 0.618, Cycle 2: max_lr × 0.382
    pub fn getLRDecaying(self: TernarySchedule, step: u64, total_steps: u64, max_lr: f32) f32 {
        if (total_steps == 0) return self.min_lr;

        const steps_per_cycle = total_steps / 3;
        if (steps_per_cycle == 0) return self.min_lr;

        const cycle: u32 = @intCast(@min(step / steps_per_cycle, 2));
        const cycle_step = step - @as(u64, cycle) * steps_per_cycle;

        // φ-decaying max LR per cycle
        const cycle_max = max_lr * phi_scaling.layerScale(cycle);

        // Phase boundaries
        const warmup_end: u64 = @intFromFloat(@as(f32, @floatFromInt(steps_per_cycle)) * self.warmup_frac);
        const cruise_end: u64 = @intFromFloat(@as(f32, @floatFromInt(steps_per_cycle)) * (self.warmup_frac + self.cruise_frac));

        if (cycle_step < warmup_end) {
            // Warmup: linear ramp from min_lr to cycle_max
            if (warmup_end == 0) return cycle_max;
            const progress = @as(f32, @floatFromInt(cycle_step)) / @as(f32, @floatFromInt(warmup_end));
            return self.min_lr + (cycle_max - self.min_lr) * progress;
        } else if (cycle_step < cruise_end) {
            // Cruise: constant at cycle_max
            return cycle_max;
        } else {
            // Cooldown: linear decay from cycle_max to min_lr
            const cooldown_steps = steps_per_cycle - cruise_end;
            if (cooldown_steps == 0) return self.min_lr;
            const progress = @as(f32, @floatFromInt(cycle_step - cruise_end)) / @as(f32, @floatFromInt(cooldown_steps));
            return cycle_max - (cycle_max - self.min_lr) * progress;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TernarySchedule 9 transitions" {
    const schedule = TernarySchedule{
        .max_lr = 3e-4,
        .min_lr = 1e-6,
    };
    const total: u64 = 9000; // 3000 per cycle

    // Cycle 0, warmup start
    const lr_start = schedule.getLR(0, total);
    try std.testing.expectApproxEqAbs(schedule.min_lr, lr_start, 1e-5);

    // Cycle 0, cruise
    const lr_cruise0 = schedule.getLR(1500, total);
    try std.testing.expectApproxEqAbs(schedule.max_lr, lr_cruise0, 1e-5);

    // Cycle 1, cruise (should be φ-decayed)
    const lr_cruise1 = schedule.getLR(4500, total);
    const expected_c1 = schedule.max_lr * phi_scaling.INV_PHI;
    try std.testing.expectApproxEqAbs(expected_c1, lr_cruise1, 1e-5);

    // Cycle 2, cruise (should be φ²-decayed)
    const lr_cruise2 = schedule.getLR(7500, total);
    const expected_c2 = schedule.max_lr * phi_scaling.INV_PHI_SQ;
    try std.testing.expectApproxEqAbs(expected_c2, lr_cruise2, 1e-5);
}

test "TernarySchedule bounds" {
    const schedule = TernarySchedule{
        .max_lr = 1e-3,
        .min_lr = 1e-6,
    };
    const total: u64 = 9000;

    for (0..total) |step| {
        const lr = schedule.getLR(@intCast(step), total);
        try std.testing.expect(lr >= schedule.min_lr - 1e-7);
        try std.testing.expect(lr <= schedule.max_lr + 1e-7);
    }
}

test "TernarySchedule decaying sum decreases" {
    const schedule = TernarySchedule{
        .max_lr = 1e-3,
        .min_lr = 1e-6,
    };
    const total: u64 = 9000;
    const spc = total / 3;

    // Sum LR per cycle
    var sums: [3]f64 = .{ 0, 0, 0 };
    for (0..total) |step| {
        const cycle = @min(step / spc, 2);
        const lr: f64 = schedule.getLR(@intCast(step), total);
        sums[cycle] += lr;
    }

    // Each cycle should have lower total LR
    try std.testing.expect(sums[1] < sums[0]);
    try std.testing.expect(sums[2] < sums[1]);
}
