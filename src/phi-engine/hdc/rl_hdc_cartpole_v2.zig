// HDC Double Q-Learning for CartPole-v1 - Version 2
// φ² + 1/φ² = 3 | TRINITY
// Uses tile coding + HDC for better generalization

const std = @import("std");
const print = std.debug.print;
const math = std.math;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const DIMENSION: usize = 2048;
pub const N_ACTIONS: usize = 2;
pub const N_TILES: usize = 8; // Number of tilings
pub const TILES_PER_DIM: usize = 10; // Tiles per dimension per tiling

// ============================================================================
// HYPERVECTOR
// ============================================================================

pub const Hypervector = struct {
    data: [DIMENSION]f32,

    pub fn init() Hypervector {
        return Hypervector{ .data = [_]f32{0.0} ** DIMENSION };
    }

    pub fn randomBipolar(rng: *std.Random) Hypervector {
        var hv = Hypervector.init();
        for (&hv.data) |*d| {
            d.* = if (rng.float(f32) < 0.5) -1.0 else 1.0;
        }
        return hv;
    }

    pub fn dot(self: Hypervector, other: Hypervector) f32 {
        var sum: f32 = 0.0;
        for (0..DIMENSION) |i| {
            sum += self.data[i] * other.data[i];
        }
        return sum;
    }

    pub fn addScaled(self: *Hypervector, other: Hypervector, scale: f32) void {
        for (0..DIMENSION) |i| {
            self.data[i] += scale * other.data[i];
        }
    }

    pub fn bind(self: Hypervector, other: Hypervector) Hypervector {
        var result = Hypervector.init();
        for (0..DIMENSION) |i| {
            result.data[i] = self.data[i] * other.data[i];
        }
        return result;
    }
};

// ============================================================================
// TILE CODING ENCODER
// ============================================================================

pub const TileCodingEncoder = struct {
    // Tile hypervectors: [tiling][tile_index] -> HV
    // Total tiles = N_TILES * TILES_PER_DIM^4 (too many, use hashing)
    tile_seeds: [N_TILES]Hypervector, // One seed per tiling
    offsets: [N_TILES][4]f32, // Random offsets for each tiling

    // State bounds
    const bounds: [4][2]f32 = .{
        .{ -2.4, 2.4 },   // cart position
        .{ -3.0, 3.0 },   // cart velocity
        .{ -0.21, 0.21 }, // pole angle
        .{ -3.0, 3.0 },   // pole angular velocity
    };

    pub fn init(rng: *std.Random) TileCodingEncoder {
        var encoder = TileCodingEncoder{
            .tile_seeds = undefined,
            .offsets = undefined,
        };

        for (0..N_TILES) |t| {
            encoder.tile_seeds[t] = Hypervector.randomBipolar(rng);
            for (0..4) |d| {
                encoder.offsets[t][d] = rng.float(f32) / @as(f32, TILES_PER_DIM);
            }
        }

        return encoder;
    }

    /// Get tile index for a dimension
    fn getTileIndex(value: f32, min_val: f32, max_val: f32, offset: f32) usize {
        const range = max_val - min_val;
        const normalized = (value - min_val) / range + offset;
        const tile: usize = @intFromFloat(@max(0.0, @min(@as(f32, TILES_PER_DIM - 1), normalized * @as(f32, TILES_PER_DIM))));
        return tile;
    }

    /// Encode state using tile coding + HDC
    pub fn encode(self: TileCodingEncoder, state: [4]f32) Hypervector {
        var result = Hypervector.init();

        for (0..N_TILES) |t| {
            // Get tile indices for this tiling
            var tile_hash: u32 = 0;
            for (0..4) |d| {
                const idx = getTileIndex(state[d], bounds[d][0], bounds[d][1], self.offsets[t][d]);
                tile_hash = tile_hash *% @as(u32, TILES_PER_DIM) +% @as(u32, @intCast(idx));
            }

            // Use hash to permute the seed
            const shift = tile_hash % DIMENSION;
            for (0..DIMENSION) |i| {
                result.data[i] += self.tile_seeds[t].data[(i + shift) % DIMENSION];
            }
        }

        // Normalize
        for (&result.data) |*d| {
            d.* /= @as(f32, N_TILES);
        }

        return result;
    }
};

// ============================================================================
// HDC Q-ESTIMATOR
// ============================================================================

pub const HDCQEstimator = struct {
    weights: [N_ACTIONS]Hypervector,

    pub fn init() HDCQEstimator {
        var estimator = HDCQEstimator{ .weights = undefined };
        for (0..N_ACTIONS) |i| {
            estimator.weights[i] = Hypervector.init();
        }
        return estimator;
    }

    pub fn computeQ(self: HDCQEstimator, state_vec: Hypervector, action: u8) f32 {
        return self.weights[action].dot(state_vec) / @as(f32, DIMENSION);
    }

    pub fn update(self: *HDCQEstimator, action: u8, state_vec: Hypervector, td_error: f32, lr: f32) void {
        self.weights[action].addScaled(state_vec, lr * td_error);
    }
};

// ============================================================================
// EXPERIENCE REPLAY
// ============================================================================

const Experience = struct {
    state: [4]f32,
    action: u8,
    reward: f32,
    next_state: [4]f32,
    done: bool,
};

const BUFFER_SIZE: usize = 5000;

pub const ReplayBuffer = struct {
    buffer: [BUFFER_SIZE]Experience,
    size: usize,
    idx: usize,

    pub fn init() ReplayBuffer {
        return ReplayBuffer{
            .buffer = [_]Experience{.{
                .state = [_]f32{ 0, 0, 0, 0 },
                .action = 0,
                .reward = 0,
                .next_state = [_]f32{ 0, 0, 0, 0 },
                .done = false,
            }} ** BUFFER_SIZE,
            .size = 0,
            .idx = 0,
        };
    }

    pub fn add(self: *ReplayBuffer, exp: Experience) void {
        self.buffer[self.idx] = exp;
        self.idx = (self.idx + 1) % BUFFER_SIZE;
        if (self.size < BUFFER_SIZE) self.size += 1;
    }

    pub fn sampleAndLearn(self: *ReplayBuffer, batch_size: usize, agent: *HDCCartPoleAgent) void {
        if (self.size < batch_size) return;

        for (0..batch_size) |_| {
            const i = agent.rng.intRangeAtMost(usize, 0, self.size - 1);
            const exp = self.buffer[i];

            const state_vec = agent.encoder.encode(exp.state);
            const next_state_vec = agent.encoder.encode(exp.next_state);

            if (agent.rng.float(f32) < 0.5) {
                const q1_0 = agent.q1.computeQ(next_state_vec, 0);
                const q1_1 = agent.q1.computeQ(next_state_vec, 1);
                const a_star: u8 = if (q1_1 > q1_0) 1 else 0;

                const target = if (exp.done) exp.reward else exp.reward + agent.gamma * agent.q2.computeQ(next_state_vec, a_star);
                const current = agent.q1.computeQ(state_vec, exp.action);
                const td_error = target - current;
                agent.q1.update(exp.action, state_vec, td_error, agent.learning_rate);
            } else {
                const q2_0 = agent.q2.computeQ(next_state_vec, 0);
                const q2_1 = agent.q2.computeQ(next_state_vec, 1);
                const a_star: u8 = if (q2_1 > q2_0) 1 else 0;

                const target = if (exp.done) exp.reward else exp.reward + agent.gamma * agent.q1.computeQ(next_state_vec, a_star);
                const current = agent.q2.computeQ(state_vec, exp.action);
                const td_error = target - current;
                agent.q2.update(exp.action, state_vec, td_error, agent.learning_rate);
            }
        }
    }
};

// ============================================================================
// HDC DOUBLE Q AGENT
// ============================================================================

pub const HDCCartPoleAgent = struct {
    q1: HDCQEstimator,
    q2: HDCQEstimator,
    encoder: TileCodingEncoder,
    replay: ReplayBuffer,
    epsilon: f32,
    epsilon_min: f32,
    epsilon_decay: f32,
    learning_rate: f32,
    gamma: f32,
    rng: std.Random,

    pub fn init(seed: u64) HDCCartPoleAgent {
        var prng = std.Random.DefaultPrng.init(seed);
        var rng = prng.random();

        return HDCCartPoleAgent{
            .q1 = HDCQEstimator.init(),
            .q2 = HDCQEstimator.init(),
            .encoder = TileCodingEncoder.init(&rng),
            .replay = ReplayBuffer.init(),
            .epsilon = 1.0,
            .epsilon_min = 0.01,
            .epsilon_decay = 0.995,
            .learning_rate = 0.1,
            .gamma = 0.99,
            .rng = rng,
        };
    }

    pub fn chooseAction(self: *HDCCartPoleAgent, state: [4]f32) u8 {
        if (self.rng.float(f32) < self.epsilon) {
            return @intCast(self.rng.intRangeAtMost(u8, 0, N_ACTIONS - 1));
        }

        const state_vec = self.encoder.encode(state);
        const q0 = self.q1.computeQ(state_vec, 0) + self.q2.computeQ(state_vec, 0);
        const q1 = self.q1.computeQ(state_vec, 1) + self.q2.computeQ(state_vec, 1);

        return if (q1 > q0) 1 else 0;
    }

    pub fn remember(self: *HDCCartPoleAgent, state: [4]f32, action: u8, reward: f32, next_state: [4]f32, done: bool) void {
        self.replay.add(.{
            .state = state,
            .action = action,
            .reward = reward,
            .next_state = next_state,
            .done = done,
        });
    }

    pub fn learn(self: *HDCCartPoleAgent, batch_size: usize) void {
        self.replay.sampleAndLearn(batch_size, self);
    }

    pub fn decayEpsilon(self: *HDCCartPoleAgent) void {
        self.epsilon = @max(self.epsilon_min, self.epsilon * self.epsilon_decay);
    }
};

// ============================================================================
// CARTPOLE ENVIRONMENT
// ============================================================================

pub const CartPoleEnv = struct {
    state: [4]f32 = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
    rng: std.Random,

    const gravity: f32 = 9.8;
    const cart_mass: f32 = 1.0;
    const pole_mass: f32 = 0.1;
    const total_mass: f32 = cart_mass + pole_mass;
    const pole_length: f32 = 0.5;
    const pole_mass_length: f32 = pole_mass * pole_length;
    const force_mag: f32 = 10.0;
    const tau: f32 = 0.02;

    pub fn init(seed: u64) CartPoleEnv {
        var prng = std.Random.DefaultPrng.init(seed);
        return CartPoleEnv{ .rng = prng.random() };
    }

    pub fn reset(self: *CartPoleEnv) [4]f32 {
        for (&self.state) |*s| {
            s.* = (self.rng.float(f32) - 0.5) * 0.1;
        }
        return self.state;
    }

    pub fn step(self: *CartPoleEnv, action: u8) struct { state: [4]f32, reward: f32, done: bool } {
        const x = self.state[0];
        const x_dot = self.state[1];
        const theta = self.state[2];
        const theta_dot = self.state[3];

        const force: f32 = if (action == 1) force_mag else -force_mag;

        const cos_theta = @cos(theta);
        const sin_theta = @sin(theta);

        const temp = (force + pole_mass_length * theta_dot * theta_dot * sin_theta) / total_mass;
        const theta_acc = (gravity * sin_theta - cos_theta * temp) /
            (pole_length * (4.0 / 3.0 - pole_mass * cos_theta * cos_theta / total_mass));
        const x_acc = temp - pole_mass_length * theta_acc * cos_theta / total_mass;

        self.state[0] = x + tau * x_dot;
        self.state[1] = x_dot + tau * x_acc;
        self.state[2] = theta + tau * theta_dot;
        self.state[3] = theta_dot + tau * theta_acc;

        const done = self.state[0] < -2.4 or self.state[0] > 2.4 or
            self.state[2] < -0.21 or self.state[2] > 0.21;

        const reward: f32 = if (done) -1.0 else 1.0;

        return .{ .state = self.state, .reward = reward, .done = done };
    }
};

// ============================================================================
// TRAINING
// ============================================================================

pub fn trainCartPole(n_episodes: u32) !void {
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     HDC DOUBLE Q + TILE CODING - CARTPOLE-v1                 ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY | D={d}                        ║\n", .{DIMENSION});
    print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    print("Training with Experience Replay + Tile Coding...\n", .{});
    print("Params: D={d}, tiles={d}, lr=0.1, gamma=0.99\n", .{ DIMENSION, N_TILES });
    print("Target: ≥195 average reward over 100 episodes\n\n", .{});

    var env = CartPoleEnv.init(42);
    var agent = HDCCartPoleAgent.init(42);

    var total_rewards: [100]f32 = [_]f32{0.0} ** 100;
    var idx: usize = 0;
    var best_avg: f32 = 0.0;
    var solved = false;
    var solved_episode: u32 = 0;

    for (0..n_episodes) |episode| {
        _ = env.reset();
        var episode_reward: f32 = 0.0;
        var steps: u32 = 0;

        for (0..500) |_| {
            const state = env.state;
            const action = agent.chooseAction(state);
            const result = env.step(action);

            agent.remember(state, action, result.reward, result.state, result.done);
            agent.learn(32); // Batch learning

            episode_reward += 1.0; // Count steps as reward
            steps += 1;

            if (result.done) break;
        }

        agent.decayEpsilon();

        total_rewards[idx] = @floatFromInt(steps);
        idx = (idx + 1) % 100;

        var sum: f32 = 0.0;
        for (total_rewards) |r| {
            sum += r;
        }
        const avg = sum / 100.0;

        if (avg > best_avg) {
            best_avg = avg;
        }

        if (!solved and avg >= 195.0 and episode >= 100) {
            solved = true;
            solved_episode = @intCast(episode);
            print("🎯 SOLVED at episode {d}! Avg reward: {d:.1}\n", .{ episode, avg });
        }

        if ((episode + 1) % 100 == 0) {
            print("Episode {d:5} | Steps: {d:3} | Avg(100): {d:5.1} | Best: {d:5.1} | ε: {d:.3}\n", .{ episode + 1, steps, avg, best_avg, agent.epsilon });
        }
    }

    var final_sum: f32 = 0.0;
    for (total_rewards) |r| {
        final_sum += r;
    }
    const final_avg = final_sum / 100.0;

    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    FINAL RESULTS\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("  Dimension:          {d}\n", .{DIMENSION});
    print("  Tilings:            {d}\n", .{N_TILES});
    print("  Episodes:           {d}\n", .{n_episodes});
    print("  Final Avg (100):    {d:.1}\n", .{final_avg});
    print("  Best Avg:           {d:.1}\n", .{best_avg});

    if (solved) {
        print("  Solved at:          Episode {d}\n", .{solved_episode});
        print("\n🏆 CARTPOLE SOLVED! ≥195 average reward! 🏆\n", .{});
    } else if (best_avg >= 100.0) {
        print("\n✅ Good progress: {d:.1} best average\n", .{best_avg});
    } else {
        print("\n📊 Best average: {d:.1}\n", .{best_avg});
    }
}

pub fn main() !void {
    try trainCartPole(1000);
}

test "tile_coding" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    const encoder = TileCodingEncoder.init(&rng);

    const state1 = [4]f32{ 0.0, 0.0, 0.0, 0.0 };
    const state2 = [4]f32{ 0.1, 0.0, 0.0, 0.0 };

    const hv1 = encoder.encode(state1);
    const hv2 = encoder.encode(state2);

    // Similar states should have similar encodings
    const sim = hv1.dot(hv2) / @as(f32, DIMENSION);
    try std.testing.expect(sim > 0.5);
}
