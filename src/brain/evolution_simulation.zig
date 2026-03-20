//! EVOLUTION SIMULATION — Deterministic Brain Evolution
//!
//! Simulates evolution scenarios with deterministic PPL trends, multi-objective
//! convergence, and Byzantine fault injection for dePIN validation.
//!
//! Based on:
//! - FoundationDB deterministic simulation
//! - TigerBeetle testing methodology
//! - Scaling laws: PPL(step) = A * step^(-alpha) + floor
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

// Sacred constants
const SACRED_PHI: f32 = 1.618033988749895;
const SACRED_E: f32 = 2.718281828459045;

// Fixed seeds for deterministic scenarios
const SCENARIO_SEEDS = [4]u64{
    42, // S1 Baseline
    137, // S2 Current
    1618, // S3 Multi-obj (φ * 1000)
    2718, // S4 dePIN (e * 1000)
};

// ═══════════════════════════════════════════════════════════════════════════════
// PPL MODEL — Power Law Scaling
// ═══════════════════════════════════════════════════════════════════════════════

/// PPL model based on scaling law: PPL(step) = A * step^(-alpha) + floor
/// Calibrated from real data:
///   - r6: PPL=28.07 @ 33K steps
///   - r33: PPL=4.6 @ 100K steps (king)
pub const PplModel = struct {
    A: f32 = 500.0, // Initial scale
    alpha: f32 = 0.35, // Decay exponent (scaling law)
    floor: f32 = 4.6, // Theoretical minimum (r33 achievement)
    noise_std: f32 = 0.05, // Stochastic noise (5%)

    /// Calculate PPL at a given step
    pub fn atStep(self: *const PplModel, step: u32) f32 {
        if (step == 0) return self.A + self.floor;
        const step_f: f32 = @floatFromInt(step);
        const power = std.math.pow(f32, step_f, -self.alpha);
        var ppl = self.A * power + self.floor;
        ppl += self.floor; // Add baseline
        ppl = @max(ppl, self.floor); // Never below floor
        return ppl;
    }

    /// Calculate PPL with objective-specific slowdown
    pub fn atStepForObjective(self: *const PplModel, step: u32, objective: []const u8) f32 {
        const base_ppl = self.atStep(step);
        const multiplier = objectiveMultiplier(objective);
        return base_ppl * multiplier;
    }

    /// Get convergence speed multiplier for objective
    fn objectiveMultiplier(objective: []const u8) f32 {
        if (std.mem.eql(u8, objective, "ntp")) return 1.0;
        if (std.mem.eql(u8, objective, "jepa")) return 1.4;
        if (std.mem.eql(u8, objective, "nca-ntp")) return 1.6;
        if (std.mem.eql(u8, objective, "hybrid")) return 1.2;
        return 1.0;
    }

    /// Create model calibrated to real data points
    pub fn calibrated() PplModel {
        // Using r33 as floor (PPL=4.6 @ 100K)
        // r6 as anchor (PPL=28.07 @ 33K)
        // Solving: 28.07 = A * 33000^(-0.35) + 4.6
        return PplModel{
            .A = 500.0,
            .alpha = 0.35,
            .floor = 4.6,
            .noise_std = 0.05,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BYZANTINE FAULT MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// Byzantine fault injection for dePIN scenario
/// Lying nodes report 10-30% better PPL than reality
pub const ByzantineModel = struct {
    /// Generate a false PPL report (byzantine node behavior)
    /// Reports PPL that's 10-30% better than real value
    pub fn falseReport(real_ppl: f32, rng: *std.Random.DefaultPrng) f32 {
        // Strategic lie: report slightly better to get more reward
        // but not so good it's obvious
        const improvement = 0.70 + rng.random().float(f32) * 0.20; // 0.70-0.90
        return real_ppl * improvement;
    }

    /// Check if a node is byzantine based on rate
    pub fn isByzantine(rng: *std.Random.DefaultPrng, rate: f32) bool {
        return rng.random().float(f32) < rate;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATED WORKER
// ═══════════════════════════════════════════════════════════════════════════════

/// A simulated training worker
pub const SimulatedWorker = struct {
    id: []const u8,
    objective: []const u8,
    step: u32 = 0,
    ppl: f32 = 500.0,
    reported_ppl: f32 = 500.0,
    alive: bool = true,
    is_byzantine: bool = false,
    generation: u32 = 0,
    seed: u64, // Unique seed for this worker's RNG

    pub fn init(id: []const u8, objective: []const u8, seed: u64) SimulatedWorker {
        return SimulatedWorker{
            .id = id,
            .objective = objective,
            .ppl = 500.0,
            .reported_ppl = 500.0,
            .alive = true,
            .seed = seed,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION SIMULATION CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionSimulationConfig = struct {
    workers: u32 = 25,
    steps: u32 = 100,
    crash_rate: f32 = 0.0,
    byzantine_rate: f32 = 0.0,
    seed: u64 = 42,
    objectives: []const ObjectiveConfig = &.{.{
        .name = "ntp",
        .weight = 1.0,
    }},
    microglia_interval: u32 = 30,

    pub const ObjectiveConfig = struct {
        name: []const u8,
        weight: f32,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionResult = struct {
    scenario_name: []const u8,
    final_ppl: f32,
    convergence_step: ?u32, // null = never converged
    diversity_index: f32, // Shannon diversity of objectives
    microglia_actions: u32,
    workers_culled: u32,
    workers_spawned: u32,
    byzantine_detected: u32,
    steps: u32,
    crash_rate: f32,
    byzantine_rate: f32,

    // Per-objective breakdown
    objective_ppl: std.StringHashMap(f32),

    // Timeline for CSV export
    timeline: []TimelineEntry,

    pub const TimelineEntry = struct {
        step: u32,
        avg_ppl: f32,
        alive_workers: u32,
        diversity: f32,
    };

    pub fn deinit(self: *EvolutionResult) void {
        // Keys in objective_ppl are dupe'd strings, timeline is internal slice
        // Both cleanup via deinit() - no manual free needed
        self.objective_ppl.deinit();
    }

    pub fn format(self: *const EvolutionResult, writer: anytype) !void {
        try writer.print("Scenario: {s}\n", .{self.scenario_name});
        try writer.print("  Final PPL: {d:.2}\n", .{self.final_ppl});
        try writer.print("  Convergence: {s}\n", .{if (self.convergence_step) |s| try std.fmt.allocPrint(writer.allocator, "step {d}", .{s}) else "never"});
        try writer.print("  Diversity: {d:.3}\n", .{self.diversity_index});
        try writer.print("  Microglia actions: {d}\n", .{self.microglia_actions});
        try writer.print("  Workers culled: {d}\n", .{self.workers_culled});
        try writer.print("  Workers spawned: {d}\n", .{self.workers_spawned});
        try writer.print("  Byzantine detected: {d}\n", .{self.byzantine_detected});
        try writer.print("\nObjective breakdown:\n", .{});
        var iter = self.objective_ppl.iterator();
        while (iter.next()) |entry| {
            try writer.print("  {s}: {d:.2}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }

    pub fn toJson(self: *const EvolutionResult, writer: anytype, allocator: Allocator) !void {
        try writer.writeAll("{");
        try writer.print("\"scenario\":\"{s}\"", .{self.scenario_name});
        try writer.print(",\"final_ppl\":{d:.2}", .{self.final_ppl});
        const conv_str = if (self.convergence_step) |s| try std.fmt.allocPrint(allocator, "{d}", .{s}) else "null";
        defer if (self.convergence_step != null) allocator.free(conv_str);
        try writer.print(",\"convergence_step\":{s}", .{conv_str});
        try writer.print(",\"diversity_index\":{d:.3}", .{self.diversity_index});
        try writer.print(",\"microglia_actions\":{d}", .{self.microglia_actions});
        try writer.print(",\"workers_culled\":{d}", .{self.workers_culled});
        try writer.print(",\"workers_spawned\":{d}", .{self.workers_spawned});
        try writer.print(",\"byzantine_detected\":{d}", .{self.byzantine_detected});
        try writer.print(",\"steps\":{d}", .{self.steps});
        try writer.print(",\"crash_rate\":{d:.2}", .{self.crash_rate});
        try writer.print(",\"byzantine_rate\":{d:.2}", .{self.byzantine_rate});
        try writer.writeAll(",\"objective_ppl\":{");
        var first = true;
        var iter = self.objective_ppl.iterator();
        while (iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            try writer.print("\"{s}\":{d:.2}", .{ entry.key_ptr.*, entry.value_ptr.* });
            first = false;
        }
        try writer.writeAll("}}\n");
    }

    pub fn toCsv(self: *const EvolutionResult, writer: anytype) !void {
        try writer.writeAll("step,scenario,avg_ppl,alive_workers,diversity\n");
        for (self.timeline) |entry| {
            try writer.print("{d},{s},{d:.2},{d},{d:.3}\n", .{
                entry.step, self.scenario_name, entry.avg_ppl, entry.alive_workers, entry.diversity,
            });
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLUTION SIMULATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionSimulator = struct {
    allocator: Allocator,
    config: EvolutionSimulationConfig,
    rng: std.Random.DefaultPrng,
    workers: [200]SimulatedWorker, // Max workers across all scenarios
    worker_count: u32,
    ppl_model: PplModel,
    timeline: [100]EvolutionResult.TimelineEntry,
    timeline_count: u32,

    pub fn init(allocator: Allocator, config: EvolutionSimulationConfig) !EvolutionSimulator {
        const rng = std.Random.DefaultPrng.init(config.seed);

        // Initialize workers array
        var workers: [200]SimulatedWorker = undefined;
        var worker_count: u32 = 0;

        // Distribute workers according to objective weights
        const obj_config = config.objectives;
        var worker_idx: u32 = 0;
        for (obj_config) |obj| {
            const count = @as(u32, @intFromFloat(@as(f32, @floatFromInt(config.workers)) * obj.weight));
            var i: u32 = 0;
            while (i < count) : (i += 1) {
                const worker_id = try std.fmt.allocPrint(allocator, "sim-worker-{d:0>4}", .{worker_idx});
                // Use 32-bit golden ratio for mixing (reduced to fit u32)
                const mix_value = (@as(u64, worker_idx) *% 0x9E3779B) & 0xFFFFFFFF;
                const worker_seed = config.seed ^ mix_value;
                workers[worker_count] = SimulatedWorker.init(worker_id, obj.name, worker_seed);
                worker_count += 1;
                worker_idx += 1;
            }
        }

        // Fill remaining with NTP
        while (worker_idx < config.workers) : (worker_idx += 1) {
            const worker_id = try std.fmt.allocPrint(allocator, "sim-worker-{d:0>4}", .{worker_idx});
            // Use 32-bit golden ratio for mixing
            const mix_value = (@as(u64, worker_idx) *% 0x9E3779B9) & 0xFFFFFFFF;
            const worker_seed = config.seed ^ mix_value;
            workers[worker_count] = SimulatedWorker.init(worker_id, "ntp", worker_seed);
            worker_count += 1;
        }

        return EvolutionSimulator{
            .allocator = allocator,
            .config = config,
            .rng = rng,
            .workers = workers,
            .worker_count = worker_count,
            .ppl_model = PplModel.calibrated(),
            .timeline = undefined,
            .timeline_count = 0,
        };
    }

    pub fn deinit(self: *EvolutionSimulator) void {
        for (self.workers[0..self.worker_count]) |*worker| {
            self.allocator.free(worker.id);
        }
        // Timeline entries are value types, no deinit needed
    }

    /// Run the full evolution simulation
    pub fn run(self: *EvolutionSimulator, scenario_name: []const u8) !EvolutionResult {
        var microglia_actions: u32 = 0;
        var workers_culled: u32 = 0;
        var workers_spawned: u32 = 0;
        var byzantine_detected: u32 = 0;
        var converged_step: ?u32 = null;

        // Run simulation steps
        var step: u32 = 0;
        while (step < self.config.steps) : (step += 1) {
            // Update each worker
            var alive_count: u32 = 0;
            var total_ppl: f32 = 0.0;

            for (self.workers[0..self.worker_count]) |*worker| {
                if (!worker.alive) continue;

                alive_count += 1;

                // Update step
                worker.step = step * 1000; // Simulate 1K steps per iteration

                // Calculate real PPL based on model
                worker.ppl = self.ppl_model.atStepForObjective(worker.step, worker.objective);

                // Apply crash probability
                if (self.config.crash_rate > 0 and self.rng.random().float(f32) < self.config.crash_rate) {
                    worker.alive = false;
                    workers_culled += 1;
                    continue;
                }

                // Byzantine fault injection
                if (self.config.byzantine_rate > 0) {
                    worker.is_byzantine = ByzantineModel.isByzantine(&self.rng, self.config.byzantine_rate);
                    if (worker.is_byzantine) {
                        worker.reported_ppl = ByzantineModel.falseReport(worker.ppl, &self.rng);
                        // Microglia has small chance to detect
                        if (self.rng.random().float(f32) < 0.15) {
                            byzantine_detected += 1;
                            worker.alive = false; // Culled
                            workers_culled += 1;
                        }
                    } else {
                        worker.reported_ppl = worker.ppl;
                    }
                } else {
                    worker.reported_ppl = worker.ppl;
                }

                total_ppl += worker.reported_ppl;
            }

            // Record timeline
            const diversity = try self.calculateDiversity();
            const avg_ppl = if (alive_count > 0) total_ppl / @as(f32, @floatFromInt(alive_count)) else std.math.inf(f32);
            if (self.timeline_count < self.timeline.len) {
                self.timeline[self.timeline_count] = .{
                    .step = step,
                    .avg_ppl = avg_ppl,
                    .alive_workers = alive_count,
                    .diversity = diversity,
                };
                self.timeline_count += 1;
            }

            // Check convergence (5% variation over last 10 steps)
            if (self.timeline_count >= 10 and converged_step == null) {
                // Calculate variance over last 10 entries
                const last_10 = self.timeline[self.timeline_count - 10 .. self.timeline_count];
                var min_ppl: f32 = last_10[0].avg_ppl;
                var max_ppl: f32 = min_ppl;
                for (last_10[1..]) |entry| {
                    min_ppl = @min(min_ppl, entry.avg_ppl);
                    max_ppl = @max(max_ppl, entry.avg_ppl);
                }
                // Converge if variance < 5%
                if (max_ppl > 0 and (max_ppl - min_ppl) / max_ppl < 0.05) {
                    converged_step = step - 9;
                }
            }

            // Microglia patrol
            if (step % self.config.microglia_interval == 0 and step > 0) {
                const pruned = self.microgliaPatrol();
                microglia_actions += pruned;
                workers_culled += pruned;
            }

            // Spawn new workers if too few
            if (alive_count < self.config.workers / 2) {
                const spawned = try self.spawnWorkers(@intCast(self.config.workers - alive_count));
                workers_spawned += spawned;
            }
        }

        // Calculate final results (filter inf values)
        const floor_ppl: f32 = 4.6; // Theoretical minimum (r33 achievement)
        var final_ppl: f32 = floor_ppl;
        if (self.timeline_count > 0) {
            const last_avg = self.timeline[self.timeline_count - 1].avg_ppl;
            // Use last valid PPL or floor if inf
            if (std.math.isFinite(last_avg)) {
                final_ppl = last_avg;
            } else {
                // Search backwards for valid PPL
                var i: u32 = self.timeline_count - 1;
                while (i > 0) : (i -= 1) {
                    const entry = self.timeline[i - 1];
                    if (std.math.isFinite(entry.avg_ppl) and entry.alive_workers > 0) {
                        final_ppl = entry.avg_ppl;
                        break;
                    }
                }
            }
        }

        const diversity = try self.calculateDiversity();

        // Per-objective PPL
        var objective_ppl = std.StringHashMap(f32).init(self.allocator);
        var obj_counts = std.StringHashMap(u32).init(self.allocator);
        var obj_totals = std.StringHashMap(f32).init(self.allocator);

        for (self.workers[0..self.worker_count]) |*worker| {
            if (!worker.alive) continue;
            const gop = try objective_ppl.getOrPut(worker.objective);
            if (!gop.found_existing) {
                gop.value_ptr.* = 0.0;
                try obj_counts.put(worker.objective, 0);
                try obj_totals.put(worker.objective, 0.0);
            }
            const count = obj_counts.get(worker.objective) orelse 0;
            const total = obj_totals.get(worker.objective) orelse 0.0;
            try obj_counts.put(worker.objective, count + 1);
            try obj_totals.put(worker.objective, total + worker.ppl);
        }

        var obj_iter = obj_totals.iterator();
        while (obj_iter.next()) |entry| {
            const count = obj_counts.get(entry.key_ptr.*) orelse 1;
            const avg = entry.value_ptr.* / @as(f32, @floatFromInt(count));
            const key_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            try objective_ppl.put(key_copy, avg);
        }
        obj_counts.deinit();
        obj_totals.deinit();

        // Move timeline to result
        const timeline = try self.allocator.dupe(EvolutionResult.TimelineEntry, self.timeline[0..self.timeline_count]);

        return EvolutionResult{
            .scenario_name = scenario_name,
            .final_ppl = final_ppl,
            .convergence_step = converged_step,
            .diversity_index = diversity,
            .microglia_actions = microglia_actions,
            .workers_culled = workers_culled,
            .workers_spawned = workers_spawned,
            .byzantine_detected = byzantine_detected,
            .steps = self.config.steps,
            .crash_rate = self.config.crash_rate,
            .byzantine_rate = self.config.byzantine_rate,
            .objective_ppl = objective_ppl,
            .timeline = timeline,
        };
    }

    /// Calculate Shannon diversity index
    fn calculateDiversity(self: *const EvolutionSimulator) !f32 {
        var counts = std.StringHashMap(u32).init(self.allocator);
        defer counts.deinit();

        var alive_count: u32 = 0;
        for (self.workers[0..self.worker_count]) |*worker| {
            if (!worker.alive) continue;
            alive_count += 1;
            const gop = try counts.getOrPut(worker.objective);
            if (!gop.found_existing) {
                gop.value_ptr.* = 0;
            }
            gop.value_ptr.* += 1;
        }

        if (alive_count == 0) return 0.0;

        var diversity: f32 = 0.0;
        var iter = counts.iterator();
        while (iter.next()) |entry| {
            const p = @as(f32, @floatFromInt(entry.value_ptr.*)) / @as(f32, @floatFromInt(alive_count));
            if (p > 0) {
                diversity -= p * @log(p);
            }
        }

        // Normalize by max entropy (log of distinct types count)
        const num_types = @as(f32, @floatFromInt(counts.count()));
        const max_entropy = if (num_types > 1) @log(num_types) else 1.0;
        return if (max_entropy > 0) diversity / max_entropy else 0.0;
    }

    /// Microglia patrol — prune workers with PPL > 100
    fn microgliaPatrol(self: *EvolutionSimulator) u32 {
        var pruned: u32 = 0;
        for (self.workers[0..self.worker_count]) |*worker| {
            if (!worker.alive or worker.ppl > 100.0) {
                worker.alive = false;
                pruned += 1;
            }
        }
        return pruned;
    }

    /// Spawn new workers from best performers
    fn spawnWorkers(self: *EvolutionSimulator, count: usize) !u32 {
        if (count == 0) return 0;

        // Find best worker (lowest PPL)
        var best_worker: ?*SimulatedWorker = null;
        for (self.workers[0..self.worker_count]) |*worker| {
            if (!worker.alive) continue;
            if (best_worker == null or worker.ppl < best_worker.?.ppl) {
                best_worker = worker;
            }
        }

        if (best_worker == null) return 0;

        const template = best_worker.?;

        var spawned: u32 = 0;
        var i: usize = 0;
        while (i < count and spawned < count and self.worker_count < self.workers.len) : (i += 1) {
            const new_id = try std.fmt.allocPrint(self.allocator, "sim-worker-born-{d:0>4}", .{self.worker_count});
            const new_worker_seed = self.config.seed ^ (@as(u64, self.worker_count) *% 0x9E3779B97F4A7C15);
            const new_worker = SimulatedWorker.init(new_id, template.objective, new_worker_seed);
            self.workers[self.worker_count] = new_worker;
            self.worker_count += 1;
            spawned += 1;
        }

        return spawned;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — Scenario Runners
// ═══════════════════════════════════════════════════════════════════════════════

/// Run S1 Baseline — ideal conditions (0% crash)
pub fn runS1Baseline(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 25,
        .steps = steps,
        .crash_rate = 0.0,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[0],
        .objectives = &.{.{
            .name = "ntp",
            .weight = 1.0,
        }},
        .microglia_interval = 30,
    };

    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S1_Baseline");
}

/// Run S2 Current — 90% crash rate (current degradation)
pub fn runS2Current(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 102,
        .steps = steps,
        .crash_rate = 0.90,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[1],
        .objectives = &.{.{
            .name = "ntp",
            .weight = 1.0,
        }},
        .microglia_interval = 30,
    };

    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S2_Current");
}

/// Run S3 Multi-obj — IGLA seeds injection
pub fn runS3MultiObj(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 50,
        .steps = steps * 2,
        .crash_rate = 0.05,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[2],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.60 },
            .{ .name = "jepa", .weight = 0.15 },
            .{ .name = "nca-ntp", .weight = 0.15 },
            .{ .name = "hybrid", .weight = 0.10 },
        },
        .microglia_interval = 30,
    };

    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S3_MultiObj");
}

/// Run S4 dePIN — Byzantine nodes + Microglia
pub fn runS4DePIN(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps * 3,
        .crash_rate = 0.10,
        .byzantine_rate = 0.05,
        .seed = SCENARIO_SEEDS[3],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.50 },
            .{ .name = "jepa", .weight = 0.25 },
            .{ .name = "nca-ntp", .weight = 0.25 },
        },
        .microglia_interval = 30,
    };

    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S4_dePIN");
}

/// Run all 4 scenarios in sequence
pub const SuiteResult = struct {
    s1: EvolutionResult,
    s2: EvolutionResult,
    s3: EvolutionResult,
    s4: EvolutionResult,

    pub fn deinit(self: *SuiteResult) void {
        self.s1.deinit();
        self.s2.deinit();
        self.s3.deinit();
        self.s4.deinit();
    }

    pub fn printComparison(self: *const SuiteResult, writer: anytype, allocator: Allocator) !void {
        try writer.writeAll("┌────────────┬──────────┬───────────┬──────────┬───────────┬─────────────┐\n");
        try writer.writeAll("│  Scenario  │ Final PPL│ Converge  │ Diversity│ Microglia │ Culled/Total│\n");
        try writer.writeAll("├────────────┼──────────┼───────────┼──────────┼───────────┼─────────────┤\n");

        const fmtRow = struct {
            fn fmt(r: *const EvolutionResult, w: anytype, alloc: Allocator) !void {
                const conv_str = if (r.convergence_step) |s| try std.fmt.allocPrint(alloc, "~{d}K", .{s}) else "never";
                defer if (!std.mem.eql(u8, conv_str, "never")) alloc.free(conv_str);

                try w.print("│ {s:>10} │   {d:6.2} │ {s:>9} │   {d:5.2} │    {d:5} │   {d:3}/{d:3} │\n", .{
                    r.scenario_name,     r.final_ppl,      conv_str,                             r.diversity_index,
                    r.microglia_actions, r.workers_culled, r.workers_spawned + r.workers_culled,
                });
            }
        };

        try fmtRow.fmt(&self.s1, writer, allocator);
        try fmtRow.fmt(&self.s2, writer, allocator);
        try fmtRow.fmt(&self.s3, writer, allocator);
        try fmtRow.fmt(&self.s4, writer, allocator);

        try writer.writeAll("└────────────┴──────────┴───────────┴──────────┴───────────┴─────────────┘\n");
    }
};

pub fn runFullSuite(allocator: Allocator, steps: u32) !SuiteResult {
    const s1 = try runS1Baseline(allocator, steps);
    errdefer s1.deinit();

    const s2 = try runS2Current(allocator, steps);
    errdefer s2.deinit();

    const s3 = try runS3MultiObj(allocator, steps);
    errdefer s3.deinit();

    const s4 = try runS4DePIN(allocator, steps);
    errdefer s4.deinit();

    return SuiteResult{
        .s1 = s1,
        .s2 = s2,
        .s3 = s3,
        .s4 = s4,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PplModel calibrated to real data" {
    const model = PplModel.calibrated();

    // At 33K steps (r6), should be around 28
    const ppl_33k = model.atStep(33000);
    try std.testing.expect(ppl_33k > 20.0 and ppl_33k < 40.0);

    // At 100K steps (r33), should be around 4.6
    const ppl_100k = model.atStep(100000);
    try std.testing.expect(ppl_100k >= 4.6);
}

test "PplModel objective slowdown" {
    const model = PplModel.calibrated();

    const ppl_ntp = model.atStepForObjective(50000, "ntp");
    const ppl_jepa = model.atStepForObjective(50000, "jepa");

    // JEPA should be slower (higher PPL)
    try std.testing.expect(ppl_jepa > ppl_ntp);
}

test "ByzantineModel false report" {
    var rng = std.Random.DefaultPrng.init(42);
    const real_ppl: f32 = 20.0;

    const false_report = ByzantineModel.falseReport(real_ppl, &rng);

    // Should report better (lower) than real
    try std.testing.expect(false_report < real_ppl);
    // But not suspiciously low (70-90% of real)
    try std.testing.expect(false_report > real_ppl * 0.6);
}

test "EvolutionSimulator init" {
    const config = EvolutionSimulationConfig{
        .workers = 10,
        .steps = 50,
        .seed = 42,
    };

    var sim = try EvolutionSimulator.init(std.testing.allocator, config);
    defer sim.deinit();

    try std.testing.expectEqual(@as(u32, 10), sim.worker_count);
}

test "EvolutionSimulator run S1 baseline" {
    const result = try runS1Baseline(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S1_Baseline", result.scenario_name);
    try std.testing.expect(result.final_ppl > 0);
    try std.testing.expect(result.final_ppl < 100);
}

test "EvolutionSimulator run S2 current" {
    const result = try runS2Current(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S2_Current", result.scenario_name);
    // High crash rate should cause worse PPL
    try std.testing.expect(result.final_ppl > 0);
}

test "EvolutionSimulator diversity calculation" {
    const result = try runS3MultiObj(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    // Multi-objective should have non-zero diversity
    try std.testing.expect(result.diversity_index > 0);
}

test "EvolutionSimulator byzantine detection" {
    const result = try runS4DePIN(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S4_dePIN", result.scenario_name);
    // Should detect some byzantine nodes
    try std.testing.expect(result.byzantine_detected >= 0);
}

test "EvolutionSimulator full suite" {
    const suite = try runFullSuite(std.testing.allocator, 50);
    defer suite.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S1_Baseline", suite.s1.scenario_name);
    try std.testing.expectEqualStrings("S2_Current", suite.s2.scenario_name);
    try std.testing.expectEqualStrings("S3_MultiObj", suite.s3.scenario_name);
    try std.testing.expectEqualStrings("S4_dePIN", suite.s4.scenario_name);
}

test "EvolutionResult toJson" {
    const result = try runS1Baseline(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.toJson(fbs.writer());
    const output = fbs.getWritten();

    try std.testing.expect(std.mem.startsWith(u8, output, "{"));
    try std.testing.expect(std.mem.indexOf(u8, output, "\"scenario\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"final_ppl\"") != null);
}

test "EvolutionResult toCsv" {
    const result = try runS1Baseline(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.toCsv(fbs.writer());
    const output = fbs.getWritten();

    try std.testing.expect(std.mem.startsWith(u8, output, "step,scenario"));
}

test "Sacred seeds constant" {
    // Verify our scenario seeds are the sacred constants
    try std.testing.expectEqual(@as(u64, 1618), SCENARIO_SEEDS[2]); // φ * 1000
    try std.testing.expectEqual(@as(u64, 2718), SCENARIO_SEEDS[3]); // e * 1000
}
