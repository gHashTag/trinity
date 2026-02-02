// HDC Double Q-Learning Implementation
// φ² + 1/φ² = 3 | TRINITY
// Hyperdimensional Computing for Reinforcement Learning

const std = @import("std");
const print = std.debug.print;
const math = std.math;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const DIMENSION: usize = 10240; // Hypervector dimension
pub const N_ACTIONS: usize = 4; // FrozenLake: left, down, right, up
pub const N_STATES: usize = 16; // FrozenLake 4x4
pub const TERNARY_THRESHOLD: f32 = 0.3;

// ============================================================================
// HYPERVECTOR TYPES
// ============================================================================

/// Ternary hypervector: values in {-1, 0, +1}
pub const TernaryHypervector = struct {
    data: [DIMENSION]i8,

    pub fn init() TernaryHypervector {
        return TernaryHypervector{ .data = [_]i8{0} ** DIMENSION };
    }

    /// Generate random ternary hypervector
    pub fn random(rng: *std.Random) TernaryHypervector {
        var hv = TernaryHypervector.init();
        for (&hv.data) |*d| {
            const r = rng.float(f32);
            if (r < 0.33) {
                d.* = -1;
            } else if (r < 0.66) {
                d.* = 0;
            } else {
                d.* = 1;
            }
        }
        return hv;
    }

    /// Bind operation (element-wise product)
    pub fn bind(self: TernaryHypervector, other: TernaryHypervector) TernaryHypervector {
        var result = TernaryHypervector.init();
        for (0..DIMENSION) |i| {
            result.data[i] = self.data[i] * other.data[i];
        }
        return result;
    }

    /// Flip random trits for noise testing
    pub fn flipTrits(self: *TernaryHypervector, flip_rate: f32, rng: *std.Random) void {
        for (&self.data) |*d| {
            if (rng.float(f32) < flip_rate) {
                const r = rng.float(f32);
                if (r < 0.33) {
                    d.* = -1;
                } else if (r < 0.66) {
                    d.* = 0;
                } else {
                    d.* = 1;
                }
            }
        }
    }
};

/// Real-valued hypervector for accumulation
pub const RealHypervector = struct {
    data: [DIMENSION]f32,

    pub fn init() RealHypervector {
        return RealHypervector{ .data = [_]f32{0.0} ** DIMENSION };
    }

    /// Initialize from ternary
    pub fn fromTernary(thv: TernaryHypervector) RealHypervector {
        var rhv = RealHypervector.init();
        for (0..DIMENSION) |i| {
            rhv.data[i] = @floatFromInt(thv.data[i]);
        }
        return rhv;
    }

    /// Add scaled ternary vector
    pub fn addScaled(self: *RealHypervector, thv: TernaryHypervector, scale: f32) void {
        for (0..DIMENSION) |i| {
            self.data[i] += scale * @as(f32, @floatFromInt(thv.data[i]));
        }
    }

    /// Cosine similarity with ternary vector
    pub fn similarity(self: RealHypervector, thv: TernaryHypervector) f32 {
        var dot: f32 = 0.0;
        var norm_self: f32 = 0.0;
        var norm_thv: f32 = 0.0;

        for (0..DIMENSION) |i| {
            const t: f32 = @floatFromInt(thv.data[i]);
            dot += self.data[i] * t;
            norm_self += self.data[i] * self.data[i];
            norm_thv += t * t;
        }

        const denom = @sqrt(norm_self) * @sqrt(norm_thv) + 1e-8;
        return dot / denom;
    }

    /// Quantize to ternary
    pub fn quantize(self: RealHypervector, threshold: f32) TernaryHypervector {
        var thv = TernaryHypervector.init();
        for (0..DIMENSION) |i| {
            if (self.data[i] > threshold) {
                thv.data[i] = 1;
            } else if (self.data[i] < -threshold) {
                thv.data[i] = -1;
            } else {
                thv.data[i] = 0;
            }
        }
        return thv;
    }
};

// ============================================================================
// STATE & ACTION ENCODERS
// ============================================================================

pub const StateEncoder = struct {
    state_seeds: [N_STATES]TernaryHypervector,

    pub fn init(rng: *std.Random) StateEncoder {
        var encoder = StateEncoder{ .state_seeds = undefined };
        for (0..N_STATES) |i| {
            encoder.state_seeds[i] = TernaryHypervector.random(rng);
        }
        return encoder;
    }

    pub fn encode(self: StateEncoder, state: u8) TernaryHypervector {
        return self.state_seeds[state];
    }
};

pub const ActionEncoder = struct {
    action_seeds: [N_ACTIONS]TernaryHypervector,

    pub fn init(rng: *std.Random) ActionEncoder {
        var encoder = ActionEncoder{ .action_seeds = undefined };
        for (0..N_ACTIONS) |i| {
            encoder.action_seeds[i] = TernaryHypervector.random(rng);
        }
        return encoder;
    }
};

// ============================================================================
// HDC Q-ESTIMATOR
// ============================================================================

pub const HDCQEstimator = struct {
    q_vectors: [N_ACTIONS]RealHypervector,

    pub fn init() HDCQEstimator {
        var estimator = HDCQEstimator{ .q_vectors = undefined };
        for (0..N_ACTIONS) |i| {
            estimator.q_vectors[i] = RealHypervector.init();
        }
        return estimator;
    }

    /// Compute Q(s, a) as similarity between state vector and Q-vector
    pub fn computeQ(self: HDCQEstimator, state_vec: TernaryHypervector, action: u8) f32 {
        const sim = self.q_vectors[action].similarity(state_vec);
        return sim * 10.0; // Scale to reward range [-10, 10]
    }

    /// Update Q-vector for action with TD error
    pub fn update(self: *HDCQEstimator, action: u8, state_vec: TernaryHypervector, td_error: f32, lr: f32) void {
        self.q_vectors[action].addScaled(state_vec, lr * td_error);
    }

    /// Quantize all Q-vectors to ternary
    pub fn quantize(self: *HDCQEstimator, threshold: f32) void {
        for (0..N_ACTIONS) |a| {
            const ternary = self.q_vectors[a].quantize(threshold);
            self.q_vectors[a] = RealHypervector.fromTernary(ternary);
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
    action_encoder: ActionEncoder,
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
            .action_encoder = ActionEncoder.init(&rng),
            .epsilon = 1.0,
            .epsilon_min = 0.001,
            .epsilon_decay = 0.997,
            .learning_rate = 0.1,
            .gamma = 0.95,
            .rng = rng,
        };
    }

    /// Choose action using epsilon-greedy over combined Q1+Q2
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

    /// TD Update with Double Q mechanism
    pub fn tdUpdate(self: *HDCDoubleQAgent, state: u8, action: u8, reward: f32, next_state: u8, done: bool) void {
        const state_vec = self.state_encoder.encode(state);
        const next_state_vec = self.state_encoder.encode(next_state);

        // Randomly choose which estimator to update
        if (self.rng.float(f32) < 0.5) {
            // Update Q1, use Q2 for evaluation
            var a_star: u8 = 0;
            var best_q1 = self.q1.computeQ(next_state_vec, 0);
            for (1..N_ACTIONS) |a| {
                const q = self.q1.computeQ(next_state_vec, @intCast(a));
                if (q > best_q1) {
                    best_q1 = q;
                    a_star = @intCast(a);
                }
            }

            const target = if (done) reward else reward + self.gamma * self.q2.computeQ(next_state_vec, a_star);
            const current = self.q1.computeQ(state_vec, action);
            const td_error = target - current;
            self.q1.update(action, state_vec, td_error, self.learning_rate);
        } else {
            // Update Q2, use Q1 for evaluation
            var a_star: u8 = 0;
            var best_q2 = self.q2.computeQ(next_state_vec, 0);
            for (1..N_ACTIONS) |a| {
                const q = self.q2.computeQ(next_state_vec, @intCast(a));
                if (q > best_q2) {
                    best_q2 = q;
                    a_star = @intCast(a);
                }
            }

            const target = if (done) reward else reward + self.gamma * self.q1.computeQ(next_state_vec, a_star);
            const current = self.q2.computeQ(state_vec, action);
            const td_error = target - current;
            self.q2.update(action, state_vec, td_error, self.learning_rate);
        }
    }

    /// Decay epsilon
    pub fn decayEpsilon(self: *HDCDoubleQAgent) void {
        self.epsilon = @max(self.epsilon_min, self.epsilon * self.epsilon_decay);
    }

    /// Quantize both Q-estimators
    pub fn quantize(self: *HDCDoubleQAgent) void {
        self.q1.quantize(TERNARY_THRESHOLD);
        self.q2.quantize(TERNARY_THRESHOLD);
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
            0 => col = @max(0, col - 1), // left
            1 => row = @min(3, row + 1), // down
            2 => col = @min(3, col + 1), // right
            3 => row = @max(0, row - 1), // up
            else => {},
        }

        self.state = @intCast(@as(i8, row) * 4 + col);

        // Holes at: 5, 7, 11, 12
        const holes = [_]u8{ 5, 7, 11, 12 };
        for (holes) |h| {
            if (self.state == h) {
                return .{ .state = self.state, .reward = -1.0, .done = true };
            }
        }

        // Goal at 15
        if (self.state == 15) {
            return .{ .state = self.state, .reward = 10.0, .done = true };
        }

        return .{ .state = self.state, .reward = -0.01, .done = false };
    }
};

// ============================================================================
// TRAINING
// ============================================================================

pub fn trainHDCDoubleQ(n_episodes: u32, quantize_interval: u32, noise_test: bool) !void {
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     HDC DOUBLE Q-LEARNING - FROZEN LAKE                      ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY | D={d}                       ║\n", .{DIMENSION});
    print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    print("Training HDC Double Q-Learning agent...\n", .{});
    print("Params: D={d}, lr=0.1, gamma=0.95, ε_decay=0.997\n", .{DIMENSION});
    print("Quantize interval: {d} episodes\n\n", .{quantize_interval});

    var env = FrozenLakeEnv{};
    var agent = HDCDoubleQAgent.init(42);

    var wins: u32 = 0;
    var total_reward: f32 = 0.0;
    var consecutive_wins: u32 = 0;
    var max_consecutive: u32 = 0;

    // Track last 1000
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
        if ((episode + 1) % quantize_interval == 0) {
            agent.quantize();
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

    // Final stats
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
    if (noise_test) {
        print("\n═══════════════════════════════════════════════════════════════\n", .{});
        print("                    NOISE ROBUSTNESS TEST\n", .{});
        print("═══════════════════════════════════════════════════════════════\n", .{});

        // Test with 20% trit flips
        var noisy_wins: u32 = 0;
        const test_episodes: u32 = 1000;

        for (0..test_episodes) |_| {
            _ = env.reset();
            var episode_reward: f32 = 0.0;

            for (0..100) |_| {
                const state = env.state;

                // Get state vector and add noise
                var state_vec = agent.state_encoder.encode(state);
                state_vec.flipTrits(0.2, &agent.rng); // 20% noise

                // Choose action with noisy state
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
        print("  20% Trit Flip Test: {d:.1}% win rate ({d}/{d})\n", .{ noisy_rate, noisy_wins, test_episodes });

        const clean_rate = @as(f32, @floatFromInt(final_last_1000)) / 10.0;
        const degradation = clean_rate - noisy_rate;
        print("  Degradation:        {d:.1}%\n", .{degradation});

        if (degradation < 5.0) {
            print("  ✅ EXCELLENT noise robustness!\n", .{});
        } else if (degradation < 10.0) {
            print("  📈 Good noise robustness\n", .{});
        } else {
            print("  ⚠️  Significant noise sensitivity\n", .{});
        }
    }

    // Memory comparison
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    MEMORY COMPARISON\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});
    const tabular_memory = N_STATES * N_ACTIONS * 8; // f64 per Q-value
    const hdc_memory = N_ACTIONS * DIMENSION * 2 * 2; // 2 bits per trit, 2 estimators
    print("  Tabular Q:          {d} bytes ({d} Q-values × 8 bytes)\n", .{ tabular_memory, N_STATES * N_ACTIONS });
    print("  HDC Double Q:       {d} bytes ({d} actions × {d}D × 2 bits × 2)\n", .{ hdc_memory / 8, N_ACTIONS, DIMENSION });
    print("  Ratio:              {d:.1}x\n", .{@as(f32, @floatFromInt(hdc_memory / 8)) / @as(f32, @floatFromInt(tabular_memory))});

    const final_rate = @as(f32, @floatFromInt(final_last_1000)) / 10.0;
    print("\n", .{});
    if (final_rate >= 99.0) {
        print("🏆 HDC DOUBLE Q SUCCESS! ≥99% WIN RATE! 🏆\n", .{});
    } else if (final_rate >= 95.0) {
        print("✅ Good performance: {d:.1}% win rate\n", .{final_rate});
    } else {
        print("📊 Win rate: {d:.1}%\n", .{final_rate});
    }
}

pub fn main() !void {
    try trainHDCDoubleQ(10000, 100, true);
}

test "hdc_double_q_basic" {
    var agent = HDCDoubleQAgent.init(42);
    const action = agent.chooseAction(0);
    try std.testing.expect(action < N_ACTIONS);
}

test "ternary_hypervector" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    const hv = TernaryHypervector.random(&rng);

    // Check all values are in {-1, 0, 1}
    for (hv.data) |d| {
        try std.testing.expect(d >= -1 and d <= 1);
    }
}

test "similarity" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    const hv1 = TernaryHypervector.random(&rng);
    const rhv = RealHypervector.fromTernary(hv1);

    // Self-similarity should be ~1.0
    const sim = rhv.similarity(hv1);
    try std.testing.expect(sim > 0.9);
}
