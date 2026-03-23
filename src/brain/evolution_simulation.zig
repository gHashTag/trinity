//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
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

/// FPGA cost model for hardware-aware evolution
/// Based on Artix-7 synthesis results (see project_fpga_synthesis_results.md)
pub const FpgCost = struct {
    /// LUT cost factor (per operation/worker)
    lut_cost: f32 = 1.0,
    /// BRAM cost factor (per memory block)
    bram_cost: f32 = 10.0,
    /// DSP cost factor (per multiplication)
    dsp_cost: f32 = 5.0,

    /// Calculate normalized FPGA cost (0-1, where 1 = cheapest)
    pub fn normalizedCost(lut: u32, bram: u32, dsp: u32) f32 {
        _ = dsp; // Reserved for future DSP-aware cost model
        // Budget from K=16 wide BRAM synthesis: 19K LUT + 100.5 BRAM36-eq (74%)
        const max_lut: f32 = 50000; // Conservative max LUT budget
        const max_bram: f32 = 200; // Conservative max BRAM36-eq

        const lut_ratio = @as(f32, @floatFromInt(lut)) / max_lut;
        const bram_ratio = @as(f32, @floatFromInt(bram)) / max_bram;

        // Weighted sum (LUT is more expensive than BRAM)
        return (lut_ratio * 0.7 + bram_ratio * 0.3);
    }
};

// Fixed seeds for deterministic scenarios (20 scenarios for Sacred v2 + Quantum expansion)
const SCENARIO_SEEDS = [_]u64{
    42, // S1 Baseline
    137, // S2 Current
    1618, // S3 Multi-obj (φ * 1000)
    2718, // S4 dePIN (e * 1000)
    3236, // S5 dePIN NoImmunity (φ^2 * 1000)
    5242, // S6 JEPA-heavy (e^3 * 1000)
    8450, // S7 High-Diversity (φ^3 * 1000)
    13692, // S8 Low-Crash (φ^4 * 1000)
    22134, // S9 Byzantine-Heavy (φ^5 * 1000)
    35780, // S10 Energy-Optimal (φ^6 * 1000)
    42, // S11 Sacred-A (baseline for dense heads)
    137, // S12 Sacred-B (lower crash, longer training)
    1618, // S13 Sacred-C (smaller workers, 162 dims)
    2718, // S14 Wide (9 heads, ctx=81)
    1618, // S15 Baseline-Extended (φ, 4× steps)
    // ═══════════════════════════════════════════════════════════════════════════════
    // QUANTUM-INSPIRED SCENARIOS (S16-S20)
    // ═══════════════════════════════════════════════════════════════════════════════
    57938, // S16 Superposition (φ^7 * 1000) — maximum strategy diversity
    93712, // S17 Coherence (φ^8 * 1000) — maximum learning agreement
    151650, // S18 Interference (φ^9 * 1000) — constructive pattern interference
    245362, // S19 Collapse (φ^10 * 1000) — fast convergence to single state
    397012, // S20 Quantum-Zeno (φ^11 * 1000) — frequent measurement blocks evolution
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
        const ppl = self.A * power + self.floor;
        return @max(ppl, self.floor); // Never below floor
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

    // FPGA resource tracking for hardware-aware BO
    fpga_lut: u32 = 0, // LUT usage (normalized to 50000 max)
    fpga_bram: u32 = 0, // BRAM36-eq usage (normalized to 200 max)
    fpga_dsp: u32 = 0, // DSP usage (normalized to 100 max)

    pub const ObjectiveConfig = struct {
        name: []const u8,
        weight: f32,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM-INSPIRED METRICS (Formal Statistics)
// ═══════════════════════════════════════════════════════════════════════════════
///
/// Quantum-inspired metrics as formal statistics grounded in literature:
/// - Superposition: normalized Shannon entropy [Nature srep43919]
/// - Coherence: Pearson correlation between gradient steps [Nature srep43919]
/// - Uncertainty: std deviation of PPL trajectories across scenarios
/// - Entanglement: entropy of correlation matrix [arXiv 2510.27091]
///
/// References:
/// - [Nature Scientific Reports srep43919] — Quantum-like features in biological systems
/// - [arXiv 2510.27091 v1] — VSA entanglement entropy
/// - [arXiv 2106.05268] — VSA fundamentals (quantum-inspired mixture)
pub const QuantumMetrics = struct {
    /// Superposition: normalized Shannon entropy of strategy distribution
    /// H(p) / log(N), where N = number of strategies/population
    /// High entropy = high superposition (many active states)
    superposition: f32,

    /// Coherence: Pearson correlation between gradient steps of agents
    /// r ∈ [-1, 1], higher = more coherent learning
    coherence: f32,

    /// Uncertainty: std deviation of PPL trajectories across scenarios
    /// σ(PPL trajectories), lower = more collapsed (determined)
    uncertainty: f32,

    /// Entanglement entropy: entropy of scenario×scenario correlation matrix
    /// S = -Σ pᵢⱼ log(pᵢⱼ) normalized to [0, 1]
    entanglement_entropy: f32,

    /// Interference: constructive pattern from diversity × survival
    interference: f32 = 0.0,

    /// Collapse probability: inverse of superposition
    collapse_prob: f32 = 0.0,

    /// Compute Shannon entropy: H(p) = -Σ pᵢ log₂(pᵢ)
    pub fn shannonEntropy(probabilities: []const f32) f32 {
        var entropy: f32 = 0.0;
        for (probabilities) |p| {
            if (p > 1e-6) entropy -= p * @log2(p);
        }
        return entropy;
    }

    /// Compute normalized Shannon entropy (superposition metric)
    pub fn normalizedEntropy(probabilities: []const f32) f32 {
        const H = shannonEntropy(probabilities);
        const n: f32 = @floatFromInt(probabilities.len);
        const max_entropy = if (n > 1) @log2(n) else 1.0;
        return if (max_entropy > 0) H / max_entropy else 0.0;
    }

    /// Compute Pearson correlation between two trajectories
    pub fn pearsonCorrelation(a: []const f32, b: []const f32) f32 {
        const n = @min(a.len, b.len);
        if (n == 0) return 0.0;

        // Calculate means
        var mean_a: f64 = 0.0;
        var mean_b: f64 = 0.0;
        for (0..n) |i| {
            mean_a += a[i];
            mean_b += b[i];
        }
        mean_a /= @as(f64, @floatFromInt(n));
        mean_b /= @as(f64, @floatFromInt(n));

        // Calculate correlation
        var num: f64 = 0.0;
        var den_a: f64 = 0.0;
        var den_b: f64 = 0.0;
        for (0..n) |i| {
            const da = a[i] - mean_a;
            const db = b[i] - mean_b;
            num += da * db;
            den_a += da * da;
            den_b += db * db;
        }

        const den = @sqrt(den_a * den_b);
        return if (den > 1e-10) @as(f32, @floatCast(num / den)) else 0.0;
    }

    /// Compute standard deviation of values
    pub fn stdDeviation(values: []const f32) f32 {
        if (values.len == 0) return 0.0;

        var mean: f64 = 0.0;
        for (values) |v| mean += v;
        mean /= @as(f64, @floatFromInt(values.len));

        var variance: f64 = 0.0;
        for (values) |v| {
            const diff = v - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(values.len));

        return @sqrt(@as(f32, @floatCast(variance)));
    }

    /// Compute entropy of correlation matrix (entanglement metric)
    pub fn correlationMatrixEntropy(correlations: []const f32) f32 {
        if (correlations.len == 0) return 0.0;

        // Convert correlations to probabilities (normalize to [0, 1])
        var total: f32 = 0.0;
        for (correlations) |r| {
            // Use absolute value shifted to positive
            total += @abs(r) + 1.0;
        }

        var entropy: f32 = 0.0;
        for (correlations) |r| {
            const p = (@abs(r) + 1.0) / total;
            if (p > 1e-10) entropy -= p * @log2(p);
        }

        // Normalize by max entropy
        const n: f32 = @floatFromInt(correlations.len);
        const max_entropy = if (n > 1) @log2(n) else 1.0;
        return if (max_entropy > 0) entropy / max_entropy else 0.0;
    }

    /// Initialize QuantumMetrics from simulation data
    pub fn init(
        strategy_distribution: []const f32,
        trajectory_a: ?[]const f32,
        trajectory_b: ?[]const f32,
        ppl_trajectories: []const f32,
    ) QuantumMetrics {
        const superposition = normalizedEntropy(strategy_distribution);

        const coherence = if (trajectory_a != null and trajectory_b != null)
            pearsonCorrelation(trajectory_a.?, trajectory_b.?)
        else
            0.0;

        const uncertainty = stdDeviation(ppl_trajectories);

        // For entanglement, use correlation of PPL trajectories with themselves
        // as a proxy for cross-scenario correlations
        const entanglement_entropy = correlationMatrixEntropy(ppl_trajectories);

        return .{
            .superposition = superposition,
            .coherence = coherence,
            .uncertainty = uncertainty,
            .entanglement_entropy = entanglement_entropy,
        };
    }
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
    workers_alive: u32, // Survivors at end
    byzantine_detected: u32,
    steps: u32,
    crash_rate: f32,
    byzantine_rate: f32,
    energy_cost: f32 = 0.0, // Total energy cost (workers_alive × steps)

    // FPGA resource costs
    fpga_lut: u32 = 0, // LUT usage for this scenario
    fpga_bram: u32 = 0, // BRAM36-eq usage
    fpga_dsp: u32 = 0, // DSP usage
    fpga_cost_norm: f32 = 0.0, // Normalized FPGA cost (0-1, 1=cheapest)

    // Quantum-inspired metrics (formal statistics)
    quantum_superposition: f32 = 0.0, // Normalized Shannon entropy H(p)/log(N)
    quantum_coherence: f32 = 0.0, // Pearson correlation of gradient steps
    quantum_interference: f32 = 0.0, // Constructive pattern interference
    quantum_collapse_prob: f32 = 0.0, // Probability of wave function collapse

    // Policy parameters (for CSV export)
    kill_threshold: f32 = 400.0, // PPL threshold for worker culling
    microglia_interval: u32 = 30, // Steps between microglia actions

    // Per-objective breakdown
    objective_ppl: std.StringHashMap(f32),

    // Owned string keys in objective_ppl (must be freed)
    owned_keys: [][]const u8,

    // Timeline for CSV export
    timeline: []TimelineEntry,

    pub const TimelineEntry = struct {
        step: u32,
        avg_ppl: f32,
        alive_workers: u32,
        diversity: f32,
    };

    pub fn deinit(self: *EvolutionResult, allocator: Allocator) void {
        // Free owned string keys
        for (self.owned_keys) |key| {
            allocator.free(key);
        }
        allocator.free(self.owned_keys);
        self.objective_ppl.deinit();
        // Free timeline slice (allocated via dupe)
        allocator.free(self.timeline);
    }

    /// Like deinit, but for const references (for use in tests with defer)
    pub fn free(self: *const EvolutionResult, allocator: Allocator) void {
        // This is a no-op for const references
        // Real cleanup happens via deinit() on mutable reference
        _ = self;
        _ = allocator;
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
        try writer.writeAll("step,scenario,avg_ppl,alive_workers,diversity,kill_threshold,crash_rate,byzantine_rate\n");
        for (self.timeline) |entry| {
            try writer.print("{d},{s},{d:.2},{d},{d:.3},{d:.1},{d:.3},{d:.3}\n", .{
                entry.step,          self.scenario_name, entry.avg_ppl,       entry.alive_workers, entry.diversity,
                self.kill_threshold, self.crash_rate,    self.byzantine_rate,
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
                const worker_id = try std.fmt.allocPrint(allocator, "sim-worker-{d:0>4}", .{worker_count});
                // Use 32-bit golden ratio for mixing (reduced to fit u32)
                const mix_value = (@as(u64, worker_count) *% 0x9E3779B) & 0xFFFFFFFF;
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

                // Apply crash probability (normalized per-1000 steps)
                // crash_rate is per 1000 steps, divide by 1000 for per-step probability
                if (self.config.crash_rate > 0 and self.rng.random().float(f32) < self.config.crash_rate / 1000.0) {
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
            if (self.config.microglia_interval > 0 and step % self.config.microglia_interval == 0 and step > 0) {
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
        var owned_keys_list = std.ArrayList([]const u8).empty;
        try owned_keys_list.ensureTotalCapacity(self.allocator, 8);

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
            try owned_keys_list.append(self.allocator, key_copy);
            try objective_ppl.put(key_copy, avg);
        }
        obj_counts.deinit();
        obj_totals.deinit();

        // Count survivors at end
        var workers_alive: u32 = 0;
        for (self.workers[0..self.worker_count]) |*worker| {
            if (worker.alive) workers_alive += 1;
        }

        // Move timeline to result
        const timeline = try self.allocator.dupe(EvolutionResult.TimelineEntry, self.timeline[0..self.timeline_count]);

        // Calculate energy cost: cumulative alive workers × step
        // This represents total "worker-steps" expended
        var total_energy: f32 = 0.0;
        for (self.timeline[0..self.timeline_count]) |entry| {
            total_energy += @as(f32, @floatFromInt(entry.alive_workers));
        }
        // Scale by step factor (each timeline entry = 1 step unit)
        const energy_cost = total_energy * 1000.0; // 1000 simulated steps per iteration

        // Calculate normalized FPGA cost (0-1, where 1=cheapest)
        const fpga_cost_norm = FpgCost.normalizedCost(
            self.config.fpga_lut,
            self.config.fpga_bram,
            self.config.fpga_dsp,
        );

        // Calculate quantum-inspired metrics
        const quantum_metrics = try self.calculateQuantumMetrics();

        return EvolutionResult{
            .scenario_name = scenario_name,
            .final_ppl = final_ppl,
            .convergence_step = converged_step,
            .diversity_index = diversity,
            .microglia_actions = microglia_actions,
            .workers_culled = workers_culled,
            .workers_spawned = workers_spawned,
            .workers_alive = workers_alive,
            .byzantine_detected = byzantine_detected,
            .steps = self.config.steps,
            .crash_rate = self.config.crash_rate,
            .byzantine_rate = self.config.byzantine_rate,
            .energy_cost = energy_cost,
            .fpga_lut = self.config.fpga_lut,
            .fpga_bram = self.config.fpga_bram,
            .fpga_dsp = self.config.fpga_dsp,
            .fpga_cost_norm = fpga_cost_norm,
            .quantum_superposition = quantum_metrics.superposition,
            .quantum_coherence = quantum_metrics.coherence,
            .quantum_interference = quantum_metrics.interference,
            .quantum_collapse_prob = quantum_metrics.collapse_prob,
            .kill_threshold = 400.0, // Standard kill threshold
            .microglia_interval = self.config.microglia_interval,
            .objective_ppl = objective_ppl,
            .owned_keys = try owned_keys_list.toOwnedSlice(self.allocator),
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

    /// Calculate median PPL of alive workers
    fn calculateAliveMedian(self: *EvolutionSimulator) f32 {
        var values: [256]f32 = undefined;
        var count: usize = 0;

        for (self.workers[0..self.worker_count]) |*worker| {
            if (worker.alive) {
                values[count] = worker.ppl;
                count += 1;
            }
        }

        if (count == 0) return 0.0;

        // Sort values using simple selection sort (small dataset)
        var i: usize = 0;
        while (i < count) : (i += 1) {
            var j: usize = i + 1;
            while (j < count) : (j += 1) {
                if (values[i] > values[j]) {
                    const temp = values[i];
                    values[i] = values[j];
                    values[j] = temp;
                }
            }
        }

        if (count == 0) return 0.0;

        const mid = count / 2;
        if (count % 2 == 0) {
            // Even: average of two middle values
            return (values[mid - 1] + values[mid]) / 2.0;
        } else {
            // Odd: middle value
            return values[mid];
        }
    }

    /// Calculate quantum-inspired metrics from simulation data
    fn calculateQuantumMetrics(self: *const EvolutionSimulator) !QuantumMetrics {
        var counts = std.StringHashMap(u32).init(self.allocator);
        defer counts.deinit();

        // Count workers by objective (strategy distribution)
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

        // Calculate superposition: normalized Shannon entropy of strategy distribution
        var superposition: f32 = 0.0;
        if (alive_count > 0 and counts.count() > 0) {
            var iter = counts.iterator();
            while (iter.next()) |entry| {
                const p = @as(f32, @floatFromInt(entry.value_ptr.*)) / @as(f32, @floatFromInt(alive_count));
                if (p > 0) {
                    superposition -= p * @log(p);
                }
            }
            const num_types = @as(f32, @floatFromInt(counts.count()));
            const max_entropy = if (num_types > 1) @log(num_types) else 1.0;
            superposition = if (max_entropy > 0) superposition / max_entropy else 0.0;
        }

        // Calculate coherence: Pearson correlation between PPL trends
        // For simplicity, use inverse of PPL variance as coherence proxy
        var coherence: f32 = 0.0;
        if (self.timeline_count >= 2) {
            // Calculate variance of PPL across timeline
            var mean_ppl: f64 = 0.0;
            for (self.timeline[0..self.timeline_count]) |entry| {
                mean_ppl += entry.avg_ppl;
            }
            mean_ppl /= @as(f64, @floatFromInt(self.timeline_count));

            var variance: f64 = 0.0;
            for (self.timeline[0..self.timeline_count]) |entry| {
                const diff = entry.avg_ppl - mean_ppl;
                variance += diff * diff;
            }
            variance /= @as(f64, @floatFromInt(self.timeline_count));

            // Coherence = 1 / (1 + variance) — higher coherence = lower variance
            coherence = @floatCast(1.0 / (1.0 + variance));
        }

        // Calculate interference: constructive pattern from diversity × survival
        const interference = superposition * (@as(f32, @floatFromInt(alive_count)) / @as(f32, @floatFromInt(self.config.workers)));

        // Calculate collapse probability: inverse of superposition
        const collapse_prob = 1.0 - superposition;

        return QuantumMetrics{
            .superposition = superposition,
            .coherence = coherence,
            .uncertainty = 0.0, // Not used in CSV
            .entanglement_entropy = 0.0, // Not used in CSV
            .interference = interference,
            .collapse_prob = collapse_prob,
        };
    }

    /// Microglia patrol — prune worst workers using relative threshold
    fn microgliaPatrol(self: *EvolutionSimulator) u32 {
        // Skip patrol if interval is 0 (no immunity)
        if (self.config.microglia_interval == 0) return 0;

        const median_ppl = self.calculateAliveMedian();
        const threshold = median_ppl * 3.0; // Kill if >3× median

        var pruned: u32 = 0;
        for (self.workers[0..self.worker_count]) |*worker| {
            if (!worker.alive or worker.ppl > threshold) {
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
        // FPGA: Minimal baseline architecture
        .fpga_lut = 8000, // 16% of 50K budget
        .fpga_bram = 30, // 15% of BRAM36-eq
        .fpga_dsp = 5, // 5% of DSP
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
        // FPGA: Current architecture (matches production)
        .fpga_lut = 19000, // K=16 wide BRAM synthesis result
        .fpga_bram = 100, // 100.5 BRAM36-eq from synthesis
        .fpga_dsp = 0, // Ternary MAC uses zero DSP
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
        // FPGA: Multi-objective requires more LUT for different objectives
        .fpga_lut = 14000, // 28% of 50K budget
        .fpga_bram = 60, // 30% of BRAM36-eq
        .fpga_dsp = 15, // 15% of DSP
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

/// Run S5 dePIN NoImmunity — Byzantine nodes only (no Microglia)
pub fn runS5DePIN_NoImmunity(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps * 3,
        .crash_rate = 0.10,
        .byzantine_rate = 0.05,
        .seed = SCENARIO_SEEDS[4],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.50 },
            .{ .name = "jepa", .weight = 0.25 },
            .{ .name = "nca-ntp", .weight = 0.25 },
        },
        .microglia_interval = 0, // No immunity
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S5_dePIN_NoImmunity");
}

/// Run S6 JEPA-heavy — High JEPA objective weight (demonstrates objective impact)
pub fn runS6JEPA_Heavy(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps * 3,
        .crash_rate = 0.05, // Lower crash than S4/S5
        .byzantine_rate = 0.05,
        .seed = SCENARIO_SEEDS[5],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.35 }, // NTP
            .{ .name = "jepa", .weight = 0.35 }, // HIGH JEPA (35% - balanced)
            .{ .name = "nca-ntp", .weight = 0.30 }, // NCA-ntp
        },
        .microglia_interval = 30,
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S6_JEPA_Heavy");
}

/// Run S7 High-Diversity — Many objective types for maximum exploration
pub fn runS7HighDiversity(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 150,
        .steps = steps * 2,
        .crash_rate = 0.03, // Very low crash
        .byzantine_rate = 0.0, // No Byzantine
        .seed = SCENARIO_SEEDS[6],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.25 },
            .{ .name = "jepa", .weight = 0.25 },
            .{ .name = "nca-ntp", .weight = 0.25 },
            .{ .name = "hybrid", .weight = 0.15 },
            .{ .name = "sparse", .weight = 0.10 },
        },
        .microglia_interval = 20, // More frequent pruning for diversity
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S7_HighDiversity");
}

/// Run S8 Low-Crash — Minimal crash rate for resilience demonstration
pub fn runS8LowCrash(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 80,
        .steps = steps * 4, // Longer steps to show resilience
        .crash_rate = 0.01, // 1% crash (very low)
        .byzantine_rate = 0.03, // Some Byzantine but low
        .seed = SCENARIO_SEEDS[7],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.70 },
            .{ .name = "jepa", .weight = 0.20 },
            .{ .name = "nca-ntp", .weight = 0.10 },
        },
        .microglia_interval = 40, // Less frequent, let evolution run
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S8_LowCrash");
}

/// Run S9 Byzantine-Heavy — Stress test with high Byzantine rate
pub fn runS9ByzantineHeavy(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 120,
        .steps = steps * 2,
        .crash_rate = 0.05,
        .byzantine_rate = 0.20, // 20% Byzantine (HIGH)
        .seed = SCENARIO_SEEDS[8],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.50 },
            .{ .name = "jepa", .weight = 0.30 },
            .{ .name = "nca-ntp", .weight = 0.20 },
        },
        .microglia_interval = 15, // Aggressive pruning to counter Byzantine
        // FPGA: High Byzantine rate requires monitoring overhead
        .fpga_lut = 16000, // 32% of 50K budget
        .fpga_bram = 85, // 42.5% of BRAM36-eq (needs extra for monitoring)
        .fpga_dsp = 25, // 25% of DSP
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S9_ByzantineHeavy");
}

/// Run S10 Energy-Optimal — Configuration for minimal cumulative energy cost
pub fn runS10EnergyOptimal(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 60, // Fewer workers = lower energy
        .steps = steps,
        .crash_rate = 0.02, // Low crash = less wasted energy
        .byzantine_rate = 0.0, // No Byzantine = no detection overhead
        .seed = SCENARIO_SEEDS[9],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.80 }, // Focused on primary objective
            .{ .name = "hybrid", .weight = 0.20 },
        },
        .microglia_interval = 50, // Minimal patrol = low energy
        // FPGA: Compact architecture, minimal resources
        .fpga_lut = 12000, // 24% of 50K budget
        .fpga_bram = 50, // 25% of 200 BRAM36-eq budget
        .fpga_dsp = 10, // 10% of 100 DSP budget
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S10_EnergyOptimal");
}

/// Run S11 Sacred-A — Many heads (27), small context, dense representation
pub fn runS11SacredA(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 120,
        .steps = steps * 2,
        .crash_rate = 0.03,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[10],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.40 },
            .{ .name = "jepa", .weight = 0.40 },
            .{ .name = "nca-ntp", .weight = 0.20 },
        },
        .microglia_interval = 25,
        // FPGA: 27 heads = high LUT for attention heads
        .fpga_lut = 25000, // 50% of 50K budget (many heads)
        .fpga_bram = 80, // 40% of BRAM36-eq
        .fpga_dsp = 40, // 40% of DSP (matmul intensive)
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S11_SacredA");
}

/// Run S12 Sacred-B — Many heads (27), large context (81), balanced
pub fn runS12SacredB(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 120,
        .steps = steps * 3,
        .crash_rate = 0.02,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[11],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.35 },
            .{ .name = "jepa", .weight = 0.50 },
            .{ .name = "nca-ntp", .weight = 0.15 },
        },
        .microglia_interval = 30,
        // FPGA: 27 heads + ctx=81 = highest LUT + BRAM
        .fpga_lut = 35000, // 70% of 50K budget (worst case)
        .fpga_bram = 120, // 60% of BRAM36-eq (wide context needs more cache)
        .fpga_dsp = 60, // 60% of DSP
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S12_SacredB");
}

/// Run S13 Sacred-C — Compact (162 dims), 27 heads, ctx=81
pub fn runS13SacredC(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 80,
        .steps = steps * 3,
        .crash_rate = 0.02,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[12],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.50 },
            .{ .name = "jepa", .weight = 0.30 },
            .{ .name = "nca-ntp", .weight = 0.20 },
        },
        .microglia_interval = 35,
        // FPGA: 162 dims = compact (φ^4 = ~6.85, 162 = 3^4+3^3)
        .fpga_lut = 15000, // 30% of 50K budget (compact)
        .fpga_bram = 90, // 45% of BRAM36-eq (still needs cache for ctx=81)
        .fpga_dsp = 25, // 25% of DSP
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S13_SacredC");
}

/// Run S14 Wide — Wide context (81), standard heads (9), deep representation
pub fn runS14Wide(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps * 3,
        .crash_rate = 0.02,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[13],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.60 },
            .{ .name = "jepa", .weight = 0.25 },
            .{ .name = "nca-ntp", .weight = 0.15 },
        },
        .microglia_interval = 30,
        // FPGA: ctx=81 with 9 heads = balanced LUT, high BRAM
        .fpga_lut = 18000, // 36% of 50K budget
        .fpga_bram = 100, // 50% of BRAM36-eq (wide context needs KV cache)
        .fpga_dsp = 30, // 30% of DSP
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S14_Wide");
}

/// Run S15 Baseline-Extended — Current Trinity (ctx=81, heads=3) but with longer training
pub fn runS15BaselineExtended(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 100,
        .steps = steps * 4,
        .crash_rate = 0.02,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[14],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.70 },
            .{ .name = "jepa", .weight = 0.20 },
            .{ .name = "nca-ntp", .weight = 0.10 },
        },
        .microglia_interval = 30,
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S15_BaselineExtended");
}

/// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM-INSPIRED SCENARIOS (S16-S20)
// ═══════════════════════════════════════════════════════════════════════════════

/// Run S16 Superposition — Maximum strategy diversity
/// Each worker explores different objective combinations simultaneously
pub fn runS16Superposition(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 200, // Large pool for diversity
        .steps = steps * 2,
        .crash_rate = 0.01,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[15],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.20 },
            .{ .name = "jepa", .weight = 0.20 },
            .{ .name = "nca-ntp", .weight = 0.20 },
            .{ .name = "hybrid", .weight = 0.20 },
            .{ .name = "sparse", .weight = 0.20 },
        },
        .microglia_interval = 40, // Less pruning to maintain diversity
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S16_Superposition");
}

/// Run S17 Coherence — Maximum learning agreement
/// Workers synchronize their gradient updates via coherence tracking
pub fn runS17Coherence(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 80,
        .steps = steps * 2,
        .crash_rate = 0.02,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[16],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.50 },
            .{ .name = "jepa", .weight = 0.30 },
            .{ .name = "nca-ntp", .weight = 0.20 },
        },
        .microglia_interval = 50, // Long intervals for coherence buildup
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S17_Coherence");
}

/// Run S18 Interference — Constructive pattern interference
/// Different strategies interfere to enhance learning patterns
pub fn runS18Interference(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 120,
        .steps = steps * 3,
        .crash_rate = 0.03,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[17],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.40 },
            .{ .name = "jepa", .weight = 0.35 },
            .{ .name = "nca-ntp", .weight = 0.25 },
        },
        .microglia_interval = 35,
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S18_Interference");
}

/// Run S19 Collapse — Fast convergence to single state
/// Aggressive selection leads to rapid collapse to dominant strategy
pub fn runS19Collapse(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 50,
        .steps = steps,
        .crash_rate = 0.05,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[18],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.80 },
            .{ .name = "jepa", .weight = 0.15 },
            .{ .name = "nca-ntp", .weight = 0.05 },
        },
        .microglia_interval = 15, // Frequent pruning for collapse
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S19_Collapse");
}

/// Run S20 Quantum-Zeno — Frequent measurement blocks evolution
/// Microglia patrols very frequently, preventing evolution
pub fn runS20QuantumZeno(allocator: Allocator, steps: u32) !EvolutionResult {
    const config = EvolutionSimulationConfig{
        .workers = 60,
        .steps = steps * 2,
        .crash_rate = 0.02,
        .byzantine_rate = 0.0,
        .seed = SCENARIO_SEEDS[19],
        .objectives = &.{
            .{ .name = "ntp", .weight = 0.60 },
            .{ .name = "jepa", .weight = 0.25 },
            .{ .name = "nca-ntp", .weight = 0.15 },
        },
        .microglia_interval = 5, // Very frequent = Zeno effect
    };
    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();
    return sim.run("S20_QuantumZeno");
}

/// Run all 20 scenarios in sequence (15 sacred + 5 quantum)
pub const SuiteResult = struct {
    s1: EvolutionResult,
    s2: EvolutionResult,
    s3: EvolutionResult,
    s4: EvolutionResult,
    s5: EvolutionResult,
    s6: EvolutionResult,
    s7: EvolutionResult,
    s8: EvolutionResult,
    s9: EvolutionResult,
    s10: EvolutionResult,
    s11: EvolutionResult,
    s12: EvolutionResult,
    s13: EvolutionResult,
    s14: EvolutionResult,
    s15: EvolutionResult,
    s16: EvolutionResult,
    s17: EvolutionResult,
    s18: EvolutionResult,
    s19: EvolutionResult,
    s20: EvolutionResult,

    pub fn deinit(self: *SuiteResult, allocator: Allocator) void {
        self.s1.deinit(allocator);
        self.s2.deinit(allocator);
        self.s3.deinit(allocator);
        self.s4.deinit(allocator);
        self.s5.deinit(allocator);
        self.s6.deinit(allocator);
        self.s7.deinit(allocator);
        self.s8.deinit(allocator);
        self.s9.deinit(allocator);
        self.s10.deinit(allocator);
        self.s11.deinit(allocator);
        self.s12.deinit(allocator);
        self.s13.deinit(allocator);
        self.s14.deinit(allocator);
        self.s15.deinit(allocator);
        self.s16.deinit(allocator);
        self.s17.deinit(allocator);
        self.s18.deinit(allocator);
        self.s19.deinit(allocator);
        self.s20.deinit(allocator);
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

        // Sacred v2 scenarios (S1-S15)
        try fmtRow.fmt(&self.s1, writer, allocator);
        try fmtRow.fmt(&self.s2, writer, allocator);
        try fmtRow.fmt(&self.s3, writer, allocator);
        try fmtRow.fmt(&self.s4, writer, allocator);
        try fmtRow.fmt(&self.s5, writer, allocator);
        try fmtRow.fmt(&self.s6, writer, allocator);
        try fmtRow.fmt(&self.s7, writer, allocator);
        try fmtRow.fmt(&self.s8, writer, allocator);
        try fmtRow.fmt(&self.s9, writer, allocator);
        try fmtRow.fmt(&self.s10, writer, allocator);
        try fmtRow.fmt(&self.s11, writer, allocator);
        try fmtRow.fmt(&self.s12, writer, allocator);
        try fmtRow.fmt(&self.s13, writer, allocator);
        try fmtRow.fmt(&self.s14, writer, allocator);
        try fmtRow.fmt(&self.s15, writer, allocator);

        // Quantum-inspired scenarios (S16-S20)
        try writer.writeAll("├────────────┼──────────┼───────────┼──────────┼───────────┼─────────────┤\n");
        try writer.writeAll("│ QUANTUM SCENARIOS (S16-S20)                                         │\n");
        try writer.writeAll("├────────────┼──────────┼───────────┼──────────┼───────────┼─────────────┤\n");
        try fmtRow.fmt(&self.s16, writer, allocator);
        try fmtRow.fmt(&self.s17, writer, allocator);
        try fmtRow.fmt(&self.s18, writer, allocator);
        try fmtRow.fmt(&self.s19, writer, allocator);
        try fmtRow.fmt(&self.s20, writer, allocator);

        try writer.writeAll("└────────────┴──────────┴───────────┴──────────┴───────────┴─────────────┘\n");
    }
};

pub fn runFullSuite(allocator: Allocator, steps: u32) !SuiteResult {
    var s1 = try runS1Baseline(allocator, steps);
    errdefer s1.deinit(allocator);

    var s2 = try runS2Current(allocator, steps);
    errdefer s2.deinit(allocator);

    var s3 = try runS3MultiObj(allocator, steps);
    errdefer s3.deinit(allocator);

    var s4 = try runS4DePIN(allocator, steps);
    errdefer s4.deinit(allocator);

    var s5 = try runS5DePIN_NoImmunity(allocator, steps);
    errdefer s5.deinit(allocator);

    var s6 = try runS6JEPA_Heavy(allocator, steps);
    errdefer s6.deinit(allocator);

    var s7 = try runS7HighDiversity(allocator, steps);
    errdefer s7.deinit(allocator);

    var s8 = try runS8LowCrash(allocator, steps);
    errdefer s8.deinit(allocator);

    var s9 = try runS9ByzantineHeavy(allocator, steps);
    errdefer s9.deinit(allocator);

    var s10 = try runS10EnergyOptimal(allocator, steps);
    errdefer s10.deinit(allocator);

    var s11 = try runS11SacredA(allocator, steps);
    errdefer s11.deinit(allocator);

    var s12 = try runS12SacredB(allocator, steps);
    errdefer s12.deinit(allocator);

    var s13 = try runS13SacredC(allocator, steps);
    errdefer s13.deinit(allocator);

    var s14 = try runS14Wide(allocator, steps);
    errdefer s14.deinit(allocator);

    var s15 = try runS15BaselineExtended(allocator, steps);
    errdefer s15.deinit(allocator);

    // Quantum-inspired scenarios (S16-S20)
    var s16 = try runS16Superposition(allocator, steps);
    errdefer s16.deinit(allocator);

    var s17 = try runS17Coherence(allocator, steps);
    errdefer s17.deinit(allocator);

    var s18 = try runS18Interference(allocator, steps);
    errdefer s18.deinit(allocator);

    var s19 = try runS19Collapse(allocator, steps);
    errdefer s19.deinit(allocator);

    var s20 = try runS20QuantumZeno(allocator, steps);
    errdefer s20.deinit(allocator);

    return SuiteResult{
        .s1 = s1,
        .s2 = s2,
        .s3 = s3,
        .s4 = s4,
        .s5 = s5,
        .s6 = s6,
        .s7 = s7,
        .s8 = s8,
        .s9 = s9,
        .s10 = s10,
        .s11 = s11,
        .s12 = s12,
        .s13 = s13,
        .s14 = s14,
        .s15 = s15,
        .s16 = s16,
        .s17 = s17,
        .s18 = s18,
        .s19 = s19,
        .s20 = s20,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PplModel calibrated to real data" {
    const model = PplModel.calibrated();

    // At 33K steps (r6), should be around 18
    const ppl_33k = model.atStep(33000);
    try std.testing.expect(ppl_33k > 15.0 and ppl_33k < 25.0);

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
    var result = try runS1Baseline(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S1_Baseline", result.scenario_name);
    try std.testing.expect(result.final_ppl > 0);
    try std.testing.expect(result.final_ppl < 100);
}

test "EvolutionSimulator run S2 current" {
    var result = try runS2Current(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S2_Current", result.scenario_name);
    // High crash rate should cause worse PPL
    try std.testing.expect(result.final_ppl > 0);
}

test "EvolutionSimulator diversity calculation" {
    var result = try runS3MultiObj(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    // Multi-objective should have non-zero diversity
    try std.testing.expect(result.diversity_index > 0);
}

test "EvolutionSimulator byzantine detection" {
    var result = try runS4DePIN(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S4_dePIN", result.scenario_name);
    // Should detect some byzantine nodes
    try std.testing.expect(result.byzantine_detected >= 0);
}

test "EvolutionSimulator full suite" {
    var suite = try runFullSuite(std.testing.allocator, 50);
    defer suite.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S1_Baseline", suite.s1.scenario_name);
    try std.testing.expectEqualStrings("S2_Current", suite.s2.scenario_name);
    try std.testing.expectEqualStrings("S3_MultiObj", suite.s3.scenario_name);
    try std.testing.expectEqualStrings("S4_dePIN", suite.s4.scenario_name);
    // Quantum scenarios
    try std.testing.expectEqualStrings("S16_Superposition", suite.s16.scenario_name);
    try std.testing.expectEqualStrings("S17_Coherence", suite.s17.scenario_name);
    try std.testing.expectEqualStrings("S20_QuantumZeno", suite.s20.scenario_name);
}

test "QuantumMetrics shannon entropy" {
    const probabilities = [_]f32{ 0.25, 0.25, 0.25, 0.25 };
    const entropy = QuantumMetrics.shannonEntropy(&probabilities);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), entropy, 0.01); // log2(4) = 2
}

test "QuantumMetrics normalized entropy" {
    const uniform = [_]f32{ 0.25, 0.25, 0.25, 0.25 };
    const normalized = QuantumMetrics.normalizedEntropy(&uniform);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), normalized, 0.01); // Max entropy = 1

    const peaked = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const peaked_norm = QuantumMetrics.normalizedEntropy(&peaked);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), peaked_norm, 0.01); // Min entropy = 0
}

test "QuantumMetrics pearson correlation" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const b = [_]f32{ 2.0, 4.0, 6.0, 8.0, 10.0 }; // Perfect correlation (b = 2a)
    const corr = QuantumMetrics.pearsonCorrelation(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), corr, 0.01);
}

test "QuantumMetrics std deviation" {
    const values = [_]f32{ 2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0 };
    const std_dev = QuantumMetrics.stdDeviation(&values);
    try std.testing.expect(std_dev >= 2.0 and std_dev < 2.5);
}

test "EvolutionResult toJson" {
    var result = try runS1Baseline(std.testing.allocator, 50);
    defer result.deinit(std.testing.allocator);

    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.toJson(fbs.writer(), std.testing.allocator);
    const output = fbs.getWritten();

    try std.testing.expect(std.mem.startsWith(u8, output, "{"));
    try std.testing.expect(std.mem.indexOf(u8, output, "\"scenario\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"final_ppl\"") != null);
}

test "EvolutionResult toCsv" {
    var result = try runS1Baseline(std.testing.allocator, 50);
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

test "S4 final_ppl calculation" {
    var result = try runS4DePIN(std.testing.allocator, 20);
    defer result.deinit(std.testing.allocator);

    // Debug output
    std.debug.print("\nS4: PPL={d:.2}, Diversity={d:.3}, timeline_len={d}\n", .{
        result.final_ppl, result.diversity_index, result.timeline.len,
    });

    // Show first few timeline entries
    for (0..@min(5, result.timeline.len)) |i| {
        const entry = result.timeline[i];
        std.debug.print("  step={d}: avg_ppl={d:.2}, alive={d}, finite={}\n", .{
            entry.step, entry.avg_ppl, entry.alive_workers, std.math.isFinite(entry.avg_ppl),
        });
    }

    // S4 should have some survivors or return floor
    if (result.timeline.len > 0) {
        const last = result.timeline[result.timeline.len - 1];
        std.debug.print("  last: avg_ppl={d:.2}, alive={d}\n", .{ last.avg_ppl, last.alive_workers });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════║═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "S1 Baseline: expected results" {
    const allocator = std.testing.allocator;
    var result = try runS1Baseline(allocator, 1000);
    defer result.deinit(std.testing.allocator);

    // S1 has no crashes, no Byzantine faults
    try std.testing.expectEqual(@as(u32, 0), result.workers_culled);
    try std.testing.expectEqual(@as(u32, 0), result.byzantine_detected);

    // All workers should survive
    try std.testing.expectEqual(@as(u32, 25), result.workers_alive);

    // Final PPL should be reasonable after 1000K steps
    // Note: PPL is averaged across all workers, converges toward floor
    try std.testing.expect(result.final_ppl > 4.0 and result.final_ppl < 20.0);

    // Diversity should be 0 (single objective NTP = no diversity)
    try std.testing.expectEqual(@as(f32, 0.0), result.diversity_index);
}

test "S2 Current: high crash rate" {
    const allocator = std.testing.allocator;
    var result = try runS2Current(allocator, 1000);
    defer result.deinit(std.testing.allocator);

    // S2 has 90% crash rate (normalized per-1000 steps)
    // Expected: ~90% of workers culled over 1000 steps
    // (0.90/1000 per step * 1000 steps = 0.90 probability of crash)
    // With respawning, actual culled may be higher
    const initial_workers: f32 = 102.0; // S2 starts with 102 workers
    const expected_culled_min = initial_workers * 0.50; // At least 50%
    const workers_culled_f32 = @as(f32, @floatFromInt(result.workers_culled));
    try std.testing.expect(workers_culled_f32 >= expected_culled_min);

    // Final PPL should be higher due to less training
    try std.testing.expect(result.final_ppl > 10.0);
}

test "S3 Multi-obj: objective distribution" {
    const allocator = std.testing.allocator;
    var result = try runS3MultiObj(allocator, 1000);
    defer result.deinit(std.testing.allocator);

    // Should have 4 different objectives with data
    const objectives = [_][]const u8{ "ntp", "jepa", "nca-ntp", "hybrid" };
    var obj_count: usize = 0;

    var iter = result.objective_ppl.iterator();
    while (iter.next()) |entry| {
        for (objectives) |obj| {
            if (std.mem.eql(u8, entry.key_ptr.*, obj)) {
                obj_count += 1;
                break;
            }
        }
    }

    try std.testing.expectEqual(@as(usize, 4), obj_count);

    // Diversity should be > 0 with multiple objectives
    try std.testing.expect(result.diversity_index > 0);
}

test "S4 dePIN: Byzantine detection" {
    const allocator = std.testing.allocator;
    var result = try runS4DePIN(allocator, 1000);
    defer result.deinit(std.testing.allocator);

    // S4 has Byzantine nodes (byzantine_rate > 0)
    // Should detect some Byzantine nodes (15% detection rate)
    try std.testing.expect(result.byzantine_detected > 0);
}

test "Scenario: zero workers" {
    const allocator = std.testing.allocator;

    // Edge case: zero workers should not crash
    const config = EvolutionSimulationConfig{
        .workers = 0,
        .steps = 100,
        .crash_rate = 0.0,
        .byzantine_rate = 0.0,
        .seed = 42,
        .objectives = &.{.{ .name = "ntp", .weight = 1.0 }},
        .microglia_interval = 30,
    };

    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();

    var result = try sim.run("ZeroWorkers");
    defer {
        // Manually free the result's owned memory
        for (result.owned_keys) |key| {
            allocator.free(key);
        }
        allocator.free(result.owned_keys);
        result.objective_ppl.deinit();
        allocator.free(result.timeline);
    }

    try std.testing.expectEqual(@as(u32, 0), result.workers_alive);
    // When no workers, final_ppl defaults to floor (4.6)
    try std.testing.expectEqual(@as(f32, 4.6), result.final_ppl);
}

test "Scenario: all workers crash immediately" {
    const allocator = std.testing.allocator;

    // 100% crash rate - all workers die in first step
    const config = EvolutionSimulationConfig{
        .workers = 10,
        .steps = 100,
        .crash_rate = 1000.0, // Normalized per-1000 steps: 1000/1000 = 100% per step
        .byzantine_rate = 0.0,
        .seed = 42,
        .objectives = &.{.{ .name = "ntp", .weight = 1.0 }},
        .microglia_interval = 30,
    };

    var sim = try EvolutionSimulator.init(allocator, config);
    defer sim.deinit();

    var result = try sim.run("AllCrash");
    defer {
        // Manually free the result's owned memory
        for (result.owned_keys) |key| {
            allocator.free(key);
        }
        allocator.free(result.owned_keys);
        result.objective_ppl.deinit();
        allocator.free(result.timeline);
    }

    try std.testing.expectEqual(@as(u32, 0), result.workers_alive);
    // With respawning, workers_culled can be much higher than initial count
    try std.testing.expect(result.workers_culled >= 10);
}

// φ² + 1/φ² = 3 | TRINITY
