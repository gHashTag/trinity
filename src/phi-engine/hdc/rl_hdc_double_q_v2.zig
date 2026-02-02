// HDC Double Q-Learning v2 - Linear Function Approximation
// φ² + 1/φ² = 3 | TRINITY
// Uses HDC state encoding with linear Q-function approximation

const std = @import("std");
const print = std.debug.print;
const math = std.math;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const DIMENSION: usize = 10240; // Full dimension for maximum robustness
pub const N_ACTIONS: usize = 4;
pub const N_STATES: usize = 16;

// ============================================================================
// HYPERVECTOR TYPES
// ============================================================================

pub const Hypervector = struct {
    data: [DIMENSION]f32,

    pub fn init() Hypervector {
        return Hypervector{ .data = [_]f32{0.0} ** DIMENSION };
    }

    /// Generate random bipolar hypervector {-1, +1}
    pub fn randomBipolar(rng: *std.Random) Hypervector {
        var hv = Hypervector.init();
        for (&hv.data) |*d| {
            d.* = if (rng.float(f32) < 0.5) -1.0 else 1.0;
        }
        return hv;
    }

    /// Dot product
    pub fn dot(self: Hypervector, other: Hypervector) f32 {
        var sum: f32 = 0.0;
        for (0..DIMENSION) |i| {
            sum += self.data[i] * other.data[i];
        }
        return sum;
    }

    /// Add scaled vector
    pub fn addScaled(self: *Hypervector, other: Hypervector, scale: f32) void {
        for (0..DIMENSION) |i| {
            self.data[i] += scale * other.data[i];
        }
    }

    /// L2 norm
    pub fn norm(self: Hypervector) f32 {
        var sum: f32 = 0.0;
        for (self.data) |d| {
            sum += d * d;
        }
        return @sqrt(sum);
    }

    /// Normalize to unit length
    pub fn normalize(self: *Hypervector) void {
        const n = self.norm();
        if (n > 1e-8) {
            for (&self.data) |*d| {
                d.* /= n;
            }
        }
    }

    /// Quantize to ternary {-1, 0, +1}
    pub fn quantize(self: *Hypervector, threshold: f32) void {
        for (&self.data) |*d| {
            if (d.* > threshold) {
                d.* = 1.0;
            } else if (d.* < -threshold) {
                d.* = -1.0;
            } else {
                d.* = 0.0;
            }
        }
    }

    /// Add noise (flip percentage of elements)
    pub fn addNoise(self: *Hypervector, flip_rate: f32, rng: *std.Random) void {
        for (&self.data) |*d| {
            if (rng.float(f32) < flip_rate) {
                d.* = -d.*;
            }
        }
    }
};

// ============================================================================
// STATE ENCODER - One-hot to HDC
// ============================================================================

pub const StateEncoder = struct {
    basis_vectors: [N_STATES]Hypervector,

    pub fn init(rng: *std.Random) StateEncoder {
        var encoder = StateEncoder{ .basis_vectors = undefined };
        for (0..N_STATES) |i| {
            encoder.basis_vectors[i] = Hypervector.randomBipolar(rng);
        }
        return encoder;
    }

    /// Encode state as hypervector
    pub fn encode(self: StateEncoder, state: u8) Hypervector {
        return self.basis_vectors[state];
    }
};

// ============================================================================
// HDC Q-ESTIMATOR with Linear Function Approximation
// ============================================================================

pub const HDCQEstimator = struct {
    // Weight vectors for each action: Q(s,a) = w_a · φ(s)
    weights: [N_ACTIONS]Hypervector,

    pub fn init() HDCQEstimator {
        var estimator = HDCQEstimator{ .weights = undefined };
        for (0..N_ACTIONS) |i| {
            estimator.weights[i] = Hypervector.init();
        }
        return estimator;
    }

    /// Compute Q(s, a) = w_a · φ(s) / D (normalized)
    pub fn computeQ(self: HDCQEstimator, state_vec: Hypervector, action: u8) f32 {
        return self.weights[action].dot(state_vec) / @as(f32, DIMENSION);
    }

    /// Update weights: w_a += lr * td_error * φ(s)
    pub fn update(self: *HDCQEstimator, action: u8, state_vec: Hypervector, td_error: f32, lr: f32) void {
        self.weights[action].addScaled(state_vec, lr * td_error);
    }

    /// Quantize weights to ternary
    pub fn quantize(self: *HDCQEstimator, threshold: f32) void {
        for (0..N_ACTIONS) |a| {
            self.weights[a].quantize(threshold);
        }
    }
};

// ============================================================================
// HDC DOUBLE Q AGENT
// ============================================================================

pub const HDCDoubleQAgent = struct {
    q1: HDCQEstimator,
    q2: HDCQEstimator,
    state_encoder: StateEncoder,
    epsilon: f32,
    epsilon_min: f32,
    epsilon_decay: f32,
    learning_rate: f32,
    gamma: f32,
    rng: std.Random,

    pub fn init(seed: u64) HDCDoubleQAgent {
        var prng = std.Random.DefaultPrng.init(seed);
        var rng = prng.random();

        return HDCDoubleQAgent{
            .q1 = HDCQEstimator.init(),
            .q2 = HDCQEstimator.init(),
            .state_encoder = StateEncoder.init(&rng),
            .epsilon = 1.0,
            .epsilon_min = 0.001,
            .epsilon_decay = 0.995,
            .learning_rate = 0.5, // Higher LR for linear approx
            .gamma = 0.95,
            .rng = rng,
        };
    }

    /// Choose action using epsilon-greedy
    pub fn chooseAction(self: *HDCDoubleQAgent, state: u8) u8 {
        if (self.rng.float(f32) < self.epsilon) {
            return @intCast(self.rng.intRangeAtMost(u8, 0, N_ACTIONS - 1));
        }

        const state_vec = self.state_encoder.encode(state);
        var best_action: u8 = 0;
        var best_value = self.q1.computeQ(state_vec, 0) + self.q2.computeQ(state_vec, 0);

        for (1..N_ACTIONS) |a| {
            const combined = self.q1.computeQ(state_vec, @intCast(a)) + self.q2.computeQ(state_vec, @intCast(a));
            if (combined > best_value) {
                best_value = combined;
                best_action = @intCast(a);
            }
        }

        return best_action;
    }

    /// Get best action for a state (greedy)
    fn getBestAction(_: *HDCDoubleQAgent, state_vec: Hypervector, estimator: *HDCQEstimator) u8 {
        var best_action: u8 = 0;
        var best_q = estimator.computeQ(state_vec, 0);
        for (1..N_ACTIONS) |a| {
            const q = estimator.computeQ(state_vec, @intCast(a));
            if (q > best_q) {
                best_q = q;
                best_action = @intCast(a);
            }
        }
        return best_action;
    }

    /// TD Update with Double Q mechanism
    pub fn tdUpdate(self: *HDCDoubleQAgent, state: u8, action: u8, reward: f32, next_state: u8, done: bool) void {
        const state_vec = self.state_encoder.encode(state);
        const next_state_vec = self.state_encoder.encode(next_state);

        if (self.rng.float(f32) < 0.5) {
            // Update Q1, use Q2 for evaluation
            const a_star = self.getBestAction(next_state_vec, &self.q1);
            const target = if (done) reward else reward + self.gamma * self.q2.computeQ(next_state_vec, a_star);
            const current = self.q1.computeQ(state_vec, action);
            const td_error = target - current;
            self.q1.update(action, state_vec, td_error, self.learning_rate);
        } else {
            // Update Q2, use Q1 for evaluation
            const a_star = self.getBestAction(next_state_vec, &self.q2);
            const target = if (done) reward else reward + self.gamma * self.q1.computeQ(next_state_vec, a_star);
            const current = self.q2.computeQ(state_vec, action);
            const td_error = target - current;
            self.q2.update(action, state_vec, td_error, self.learning_rate);
        }
    }

    pub fn decayEpsilon(self: *HDCDoubleQAgent) void {
        self.epsilon = @max(self.epsilon_min, self.epsilon * self.epsilon_decay);
    }

    pub fn quantize(self: *HDCDoubleQAgent, threshold: f32) void {
        self.q1.quantize(threshold);
        self.q2.quantize(threshold);
    }
};

// ============================================================================
// FROZEN LAKE ENVIRONMENT
// ============================================================================

pub const FrozenLakeEnv = struct {
    state: u8 = 0,

    pub fn reset(self: *FrozenLakeEnv) u8 {
        self.state = 0;
        return 0;
    }

    pub fn step(self: *FrozenLakeEnv, action: u8) struct { state: u8, reward: f32, done: bool } {
        var row: i8 = @intCast(self.state / 4);
        var col: i8 = @intCast(self.state % 4);

        switch (action) {
            0 => col = @max(0, col - 1),
            1 => row = @min(3, row + 1),
            2 => col = @min(3, col + 1),
            3 => row = @max(0, row - 1),
            else => {},
        }

        self.state = @intCast(@as(i8, row) * 4 + col);

        const holes = [_]u8{ 5, 7, 11, 12 };
        for (holes) |h| {
            if (self.state == h) {
                return .{ .state = self.state, .reward = -1.0, .done = true };
            }
        }

        if (self.state == 15) {
            return .{ .state = self.state, .reward = 10.0, .done = true };
        }

        return .{ .state = self.state, .reward = -0.01, .done = false };
    }
};

// ============================================================================
// TRAINING
// ============================================================================

pub fn trainHDCDoubleQ(n_episodes: u32, quantize_interval_param: u32) !void {
    const quantize_interval = quantize_interval_param;
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     HDC DOUBLE Q-LEARNING v2 - LINEAR APPROX                 ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY | D={d}                        ║\n", .{DIMENSION});
    print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    print("Training HDC Double Q-Learning agent...\n", .{});
    print("Params: D={d}, lr=0.5, gamma=0.95, ε_decay=0.995\n", .{DIMENSION});
    print("Quantize interval: {d} episodes\n\n", .{quantize_interval});

    var env = FrozenLakeEnv{};
    var agent = HDCDoubleQAgent.init(42);

    var wins: u32 = 0;
    var total_reward: f32 = 0.0;
    var consecutive_wins: u32 = 0;
    var max_consecutive: u32 = 0;

    var last_1000: [1000]bool = [_]bool{false} ** 1000;
    var idx: usize = 0;

    for (0..n_episodes) |episode| {
        _ = env.reset();
        var episode_reward: f32 = 0.0;

        for (0..100) |_| {
            const state = env.state;
            const action = agent.chooseAction(state);
            const result = env.step(action);

            agent.tdUpdate(state, action, result.reward, result.state, result.done);
            episode_reward += result.reward;

            if (result.done) break;
        }

        agent.decayEpsilon();
        total_reward += episode_reward;

        // Quantize periodically
        if (quantize_interval > 0 and (episode + 1) % quantize_interval == 0) {
            agent.quantize(0.1);
        }

        const won = episode_reward > 5.0;
        last_1000[idx] = won;
        idx = (idx + 1) % 1000;

        if (won) {
            wins += 1;
            consecutive_wins += 1;
            if (consecutive_wins > max_consecutive) {
                max_consecutive = consecutive_wins;
            }
        } else {
            consecutive_wins = 0;
        }

        if ((episode + 1) % 1000 == 0) {
            var last_1000_wins: u32 = 0;
            for (last_1000) |w| {
                if (w) last_1000_wins += 1;
            }
            const win_rate = @as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(episode + 1)) * 100.0;
            const recent_rate = @as(f32, @floatFromInt(last_1000_wins)) / 10.0;
            print("Episode {d:5} | Total: {d:5.1}% | Last 1000: {d:5.1}% | ε: {d:.4}\n", .{ episode + 1, win_rate, recent_rate, agent.epsilon });
        }
    }

    var final_last_1000: u32 = 0;
    for (last_1000) |w| {
        if (w) final_last_1000 += 1;
    }

    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    FINAL RESULTS\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("  Dimension:          {d}\n", .{DIMENSION});
    print("  Episodes:           {d}\n", .{n_episodes});
    print("  Total Wins:         {d}\n", .{wins});
    print("  Overall Win Rate:   {d:.2}%\n", .{@as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(n_episodes)) * 100.0});
    print("  Last 1000 Rate:     {d:.1}%\n", .{@as(f32, @floatFromInt(final_last_1000)) / 10.0});
    print("  Max Consecutive:    {d}\n", .{max_consecutive});

    // Noise robustness test
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    NOISE ROBUSTNESS TEST (20%% flip)\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});

    var noisy_wins: u32 = 0;
    const test_episodes: u32 = 1000;

    for (0..test_episodes) |_| {
        _ = env.reset();
        var episode_reward: f32 = 0.0;

        for (0..100) |_| {
            const state = env.state;
            var state_vec = agent.state_encoder.encode(state);
            state_vec.addNoise(0.2, &agent.rng);

            var best_action: u8 = 0;
            var best_value = agent.q1.computeQ(state_vec, 0) + agent.q2.computeQ(state_vec, 0);
            for (1..N_ACTIONS) |a| {
                const combined = agent.q1.computeQ(state_vec, @intCast(a)) + agent.q2.computeQ(state_vec, @intCast(a));
                if (combined > best_value) {
                    best_value = combined;
                    best_action = @intCast(a);
                }
            }

            const result = env.step(best_action);
            episode_reward += result.reward;

            if (result.done) break;
        }

        if (episode_reward > 5.0) {
            noisy_wins += 1;
        }
    }

    const noisy_rate = @as(f32, @floatFromInt(noisy_wins)) / @as(f32, @floatFromInt(test_episodes)) * 100.0;
    const clean_rate = @as(f32, @floatFromInt(final_last_1000)) / 10.0;
    print("  Clean:              {d:.1}%\n", .{clean_rate});
    print("  With 20%% noise:    {d:.1}%\n", .{noisy_rate});
    print("  Degradation:        {d:.1}%\n", .{clean_rate - noisy_rate});

    // Memory comparison
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    MEMORY COMPARISON\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});
    const tabular_memory = N_STATES * N_ACTIONS * 2 * 8; // Double Q tabular
    const hdc_memory = N_ACTIONS * DIMENSION * 4 * 2; // f32 weights, 2 estimators
    const hdc_ternary = N_ACTIONS * DIMENSION * 2 / 8; // 2 bits per trit
    print("  Tabular Double Q:   {d} bytes\n", .{tabular_memory});
    print("  HDC Double Q (f32): {d} bytes\n", .{hdc_memory});
    print("  HDC Double Q (ternary): {d} bytes\n", .{hdc_ternary * 2});

    const final_rate = @as(f32, @floatFromInt(final_last_1000)) / 10.0;
    print("\n", .{});
    if (final_rate >= 99.0) {
        print("🏆 HDC DOUBLE Q SUCCESS! ≥99%% WIN RATE! 🏆\n", .{});
    } else if (final_rate >= 95.0) {
        print("✅ Good: {d:.1}%% win rate\n", .{final_rate});
    } else {
        print("📊 Win rate: {d:.1}%%\n", .{final_rate});
    }
}

pub fn main() !void {
    try trainHDCDoubleQ(10000, 0); // No quantization during training
}

test "hdc_v2_basic" {
    var agent = HDCDoubleQAgent.init(42);
    const action = agent.chooseAction(0);
    try std.testing.expect(action < N_ACTIONS);
}
