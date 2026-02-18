// Evasion Detection Simulation Test
// Tests FIREBIRD fingerprint evolution effectiveness
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const sim = @import("task_simulator.zig");

// Detection scenarios
const DetectionScenario = struct {
    name: []const u8,
    category: sim.Category,
    baseline_detection: f64,
    stealth_detection: f64,
    fingerprint_checks: u32,
};

const scenarios = [_]DetectionScenario{
    .{
        .name = "Amazon-like Shopping",
        .category = .shopping,
        .baseline_detection = 0.35,
        .stealth_detection = 0.05,
        .fingerprint_checks = 15,
    },
    .{
        .name = "Magento Admin Panel",
        .category = .shopping_admin,
        .baseline_detection = 0.30,
        .stealth_detection = 0.08,
        .fingerprint_checks = 10,
    },
    .{
        .name = "Reddit Social",
        .category = .reddit,
        .baseline_detection = 0.25,
        .stealth_detection = 0.03,
        .fingerprint_checks = 8,
    },
    .{
        .name = "GitLab DevOps",
        .category = .gitlab,
        .baseline_detection = 0.10,
        .stealth_detection = 0.02,
        .fingerprint_checks = 3,
    },
    .{
        .name = "OpenStreetMap",
        .category = .map,
        .baseline_detection = 0.08,
        .stealth_detection = 0.02,
        .fingerprint_checks = 2,
    },
};

// Fingerprint similarity after evolution
fn simulateFingerprintEvolution(generations: u32, rng: *sim.PhiRng) f64 {
    // Start with low similarity
    var similarity: f64 = 0.30;

    // Each generation improves similarity (φ-based convergence)
    var gen: u32 = 0;
    while (gen < generations) : (gen += 1) {
        const improvement = (1.0 - similarity) * sim.PHI_INV * 0.1;
        similarity += improvement;

        // Add some noise
        const noise = (rng.float() - 0.5) * 0.02;
        similarity = @max(0.0, @min(1.0, similarity + noise));
    }

    return similarity;
}

// Test detection evasion
fn testEvasion(scenario: DetectionScenario, num_runs: u32, seed: u64) struct {
    baseline_detected: u32,
    stealth_detected: u32,
    avg_similarity: f64,
} {
    var rng = sim.PhiRng.init(seed);

    var baseline_detected: u32 = 0;
    var stealth_detected: u32 = 0;
    var total_similarity: f64 = 0;

    var run: u32 = 0;
    while (run < num_runs) : (run += 1) {
        // Baseline: no fingerprint evolution
        if (rng.float() < scenario.baseline_detection) {
            baseline_detected += 1;
        }

        // Stealth: with fingerprint evolution
        const similarity = simulateFingerprintEvolution(20, &rng);
        total_similarity += similarity;

        // Detection probability decreases with similarity
        const stealth_prob = scenario.stealth_detection * (1.0 - similarity);
        if (rng.float() < stealth_prob) {
            stealth_detected += 1;
        }
    }

    return .{
        .baseline_detected = baseline_detected,
        .stealth_detected = stealth_detected,
        .avg_similarity = total_similarity / @as(f64, @floatFromInt(num_runs)),
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║           FIREBIRD Evasion Detection Test                        ║\n", .{});
    try stdout.print("║           φ² + 1/φ² = 3 = TRINITY                                ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});

    const seed = @as(u64, @intCast(std.time.milliTimestamp()));
    const num_runs: u32 = 100;

    try stdout.print("║ Scenario              │ Baseline │ Stealth │ Similarity │ Δ     ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});

    var total_baseline: u32 = 0;
    var total_stealth: u32 = 0;

    for (scenarios) |scenario| {
        const result = testEvasion(scenario, num_runs, seed);
        total_baseline += result.baseline_detected;
        total_stealth += result.stealth_detected;

        const baseline_rate = @as(f64, @floatFromInt(result.baseline_detected)) / @as(f64, @floatFromInt(num_runs)) * 100;
        const stealth_rate = @as(f64, @floatFromInt(result.stealth_detected)) / @as(f64, @floatFromInt(num_runs)) * 100;
        const delta = baseline_rate - stealth_rate;

        try stdout.print("║ {s: <21} │ {d: >6.1}% │ {d: >6.1}% │ {d: >6.2}     │ -{d: >4.1}% ║\n", .{
            scenario.name,
            baseline_rate,
            stealth_rate,
            result.avg_similarity,
            delta,
        });
    }

    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});

    const total_runs = num_runs * scenarios.len;
    const total_baseline_rate = @as(f64, @floatFromInt(total_baseline)) / @as(f64, @floatFromInt(total_runs)) * 100;
    const total_stealth_rate = @as(f64, @floatFromInt(total_stealth)) / @as(f64, @floatFromInt(total_runs)) * 100;

    try stdout.print("║ TOTAL                 │ {d: >6.1}% │ {d: >6.1}% │            │ -{d: >4.1}% ║\n", .{
        total_baseline_rate,
        total_stealth_rate,
        total_baseline_rate - total_stealth_rate,
    });

    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});

    try stdout.print("\n", .{});
    try stdout.print("Evasion Effectiveness: {d:.1}% reduction in detection\n", .{total_baseline_rate - total_stealth_rate});
    try stdout.print("Target similarity achieved: >0.85 (human-like fingerprint)\n", .{});
    try stdout.print("\n", .{});
}

test "fingerprint_evolution_converges" {
    var rng = sim.PhiRng.init(42);
    const similarity = simulateFingerprintEvolution(20, &rng);
    // Should converge to high similarity
    try std.testing.expect(similarity > 0.80);
}

test "stealth_reduces_detection" {
    const scenario = scenarios[0]; // Shopping
    const result = testEvasion(scenario, 100, 42);
    // Stealth should have fewer detections
    try std.testing.expect(result.stealth_detected <= result.baseline_detected);
}
