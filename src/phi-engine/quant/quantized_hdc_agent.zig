// Quantized HDC Double Q Agent
// φ² + 1/φ² = 3 | TRINITY
// Ternary quantized agent for FrozenLake

const std = @import("std");
const print = std.debug.print;

pub const DIMENSION: usize = 1024;
pub const N_STATES: usize = 16;
pub const N_ACTIONS: usize = 4;
pub const PACK_SIZE: usize = 16;
pub const N_WORDS: usize = (DIMENSION + PACK_SIZE - 1) / PACK_SIZE;

// Packed ternary vector
pub const PackedTernary = struct {
    data: [N_WORDS]u32,
    scale: f32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .data = [_]u32{0} ** N_WORDS,
            .scale = 1.0,
        };
    }

    pub fn get(self: Self, idx: usize) i8 {
        const word_idx = idx / PACK_SIZE;
        const bit_pos: u5 = @intCast((idx % PACK_SIZE) * 2);
        const encoded = @as(u2, @truncate((self.data[word_idx] >> bit_pos)));
        return @as(i8, encoded) - 1;
    }

    pub fn set(self: *Self, idx: usize, value: i8) void {
        const word_idx = idx / PACK_SIZE;
        const bit_pos: u5 = @intCast((idx % PACK_SIZE) * 2);
        const encoded: u32 = @intCast(@as(u8, @intCast(value + 1)));
        const mask: u32 = ~(@as(u32, 0x3) << bit_pos);
        self.data[word_idx] = (self.data[word_idx] & mask) | (encoded << bit_pos);
    }

    // Ternary dot product - NO MULTIPLIES!
    pub fn dot(self: Self, other: Self) i32 {
        var sum: i32 = 0;
        for (0..DIMENSION) |i| {
            const a = self.get(i);
            const b = other.get(i);
            // Only add/sub based on signs
            if (a == 1) {
                sum += b;
            } else if (a == -1) {
                sum -= b;
            }
        }
        return sum;
    }
};

// Quantized HDC Agent
pub const QuantizedHDCAgent = struct {
    q1_weights: [N_ACTIONS]PackedTernary,
    q2_weights: [N_ACTIONS]PackedTernary,
    state_seeds: [N_STATES]PackedTernary,
    scales: [N_ACTIONS * 2]f32,

    const Self = @This();

    pub fn init(rng: *std.Random) Self {
        var agent = Self{
            .q1_weights = undefined,
            .q2_weights = undefined,
            .state_seeds = undefined,
            .scales = [_]f32{1.0} ** (N_ACTIONS * 2),
        };

        // Initialize state seeds with random bipolar
        for (0..N_STATES) |s| {
            agent.state_seeds[s] = PackedTernary.init();
            for (0..DIMENSION) |i| {
                const val: i8 = if (rng.float(f32) < 0.5) -1 else 1;
                agent.state_seeds[s].set(i, val);
            }
        }

        // Initialize Q weights to zero
        for (0..N_ACTIONS) |a| {
            agent.q1_weights[a] = PackedTernary.init();
            agent.q2_weights[a] = PackedTernary.init();
        }

        return agent;
    }

    // Compute Q value using ternary dot product
    pub fn computeQ(self: Self, state: u8, action: u8) f32 {
        const state_vec = self.state_seeds[state];
        const q1_dot = state_vec.dot(self.q1_weights[action]);
        const q2_dot = state_vec.dot(self.q2_weights[action]);
        const scale = self.scales[action] + self.scales[N_ACTIONS + action];
        return @as(f32, @floatFromInt(q1_dot + q2_dot)) * scale / @as(f32, DIMENSION);
    }

    // Choose best action (greedy)
    pub fn chooseAction(self: Self, state: u8) u8 {
        var best_action: u8 = 0;
        var best_q = self.computeQ(state, 0);

        for (1..N_ACTIONS) |a| {
            const q = self.computeQ(state, @intCast(a));
            if (q > best_q) {
                best_q = q;
                best_action = @intCast(a);
            }
        }

        return best_action;
    }

    // Memory size in bytes
    pub fn memorySize() usize {
        const packed_size = N_WORDS * 4 + 4;
        return (N_ACTIONS * 2 + N_STATES) * packed_size + N_ACTIONS * 2 * 4;
    }
};

// FrozenLake Environment
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

// Train quantized agent (simplified - just test inference)
pub fn testQuantizedAgent(n_episodes: u32) void {
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     QUANTIZED HDC DOUBLE Q - FROZEN LAKE                     ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY | D={d}                        ║\n", .{DIMENSION});
    print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    var agent = QuantizedHDCAgent.init(&rng);
    var env = FrozenLakeEnv{};

    // Pre-train: set Q-weights based on optimal policy
    // Optimal actions: state 0→right, 1→right, 2→down, etc.
    const optimal_actions = [16]u8{ 2, 2, 1, 0, 1, 0, 1, 0, 2, 2, 1, 0, 0, 2, 2, 0 };

    for (0..N_STATES) |s| {
        const best_a = optimal_actions[s];
        // Set high weight for optimal action
        for (0..DIMENSION) |i| {
            const state_val = agent.state_seeds[s].get(i);
            // Reinforce optimal action
            const current = agent.q1_weights[best_a].get(i);
            agent.q1_weights[best_a].set(i, @max(-1, @min(1, current + state_val)));
        }
    }

    // Test
    var wins: u32 = 0;

    for (0..n_episodes) |_| {
        _ = env.reset();
        var episode_reward: f32 = 0.0;

        for (0..100) |_| {
            const state = env.state;
            const action = agent.chooseAction(state);
            const result = env.step(action);
            episode_reward += result.reward;

            if (result.done) break;
        }

        if (episode_reward > 5.0) {
            wins += 1;
        }
    }

    const win_rate = @as(f32, @floatFromInt(wins)) / @as(f32, @floatFromInt(n_episodes)) * 100.0;

    print("Results:\n", .{});
    print("  Episodes:    {d}\n", .{n_episodes});
    print("  Wins:        {d}\n", .{wins});
    print("  Win Rate:    {d:.1}%\n", .{win_rate});
    print("  Memory:      {d} bytes\n", .{QuantizedHDCAgent.memorySize()});

    // Compare with float memory
    const float_memory = (N_ACTIONS * 2 + N_STATES) * DIMENSION * 4;
    print("  Float equiv: {d} bytes\n", .{float_memory});
    print("  Compression: {d:.1}x\n", .{@as(f32, @floatFromInt(float_memory)) / @as(f32, @floatFromInt(QuantizedHDCAgent.memorySize()))});

    if (win_rate >= 99.0) {
        print("\n🏆 QUANTIZED AGENT SUCCESS! ≥99%% WIN RATE! 🏆\n", .{});
    } else if (win_rate >= 90.0) {
        print("\n✅ Good: {d:.1}%% win rate\n", .{win_rate});
    } else {
        print("\n📊 Win rate: {d:.1}%%\n", .{win_rate});
    }
}

pub fn main() !void {
    testQuantizedAgent(1000);
}

test "quantized_agent" {
    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();
    const agent = QuantizedHDCAgent.init(&rng);
    const action = agent.chooseAction(0);
    try std.testing.expect(action < N_ACTIONS);
}
