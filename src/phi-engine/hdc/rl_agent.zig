//! Ternary RL Agent - Reinforcement Learning with гandперразdimensionaland inычandwithленandямand
//!
//! Соwithтоянandя and дейwithтinandя предwithтаinлены how троandчные гandперinеtoторы.
//! Онлайн TD-learning with троandчной toinантandзацandей.
//!
//! Научonя база:
//! - HDC for RL: Сandмinольные предwithтаinленandя withоwithтоянandй/дейwithтinandй
//! - TD-Learning: Sutton & Barto temporal difference
//! - Ternary Efficiency: BitNet-style compression inеwithоin
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

// ═══════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const DEFAULT_STATE_DIM: usize = 1024;
pub const DEFAULT_GAMMA: f64 = 0.99;
pub const DEFAULT_LEARNING_RATE: f64 = 0.01;
pub const DEFAULT_EPSILON_START: f64 = 1.0;
pub const DEFAULT_EPSILON_END: f64 = 0.01;
pub const DEFAULT_EPSILON_DECAY: f64 = 0.995;

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

/// Конфandгурацandя agentа
pub const AgentConfig = struct {
    state_dim: usize = DEFAULT_STATE_DIM,
    num_actions: usize = 4,
    gamma: f64 = DEFAULT_GAMMA,
    learning_rate: f64 = DEFAULT_LEARNING_RATE,
    epsilon_start: f64 = DEFAULT_EPSILON_START,
    epsilon_end: f64 = DEFAULT_EPSILON_END,
    epsilon_decay: f64 = DEFAULT_EPSILON_DECAY,
};

/// Дейwithтinandе
pub const Action = struct {
    id: usize,
    vector: []Trit,
    name: []const u8,
};

/// Таблandчonя Q-function for toажbeforeго withоwithтоянandя-дейwithтinandя
pub const QTable = struct {
    values: []f64,
    num_states: usize,
    num_actions: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, num_states: usize, num_actions: usize) !QTable {
        const values = try allocator.alloc(f64, num_states * num_actions);
        @memset(values, 0.0);
        return .{
            .values = values,
            .num_states = num_states,
            .num_actions = num_actions,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QTable) void {
        self.allocator.free(self.values);
    }

    pub fn get(self: *const QTable, state: usize, action: usize) f64 {
        if (state >= self.num_states or action >= self.num_actions) return 0;
        return self.values[state * self.num_actions + action];
    }

    pub fn set(self: *QTable, state: usize, action: usize, value: f64) void {
        if (state >= self.num_states or action >= self.num_actions) return;
        self.values[state * self.num_actions + action] = value;
    }

    pub fn update(self: *QTable, state: usize, action: usize, target: f64, lr: f64) void {
        const current = self.get(state, action);
        self.set(state, action, current + lr * (target - current));
    }

    pub fn getBestAction(self: *const QTable, state: usize) usize {
        var best_action: usize = 0;
        var best_value: f64 = -std.math.inf(f64);
        for (0..self.num_actions) |a| {
            const v = self.get(state, a);
            if (v > best_value) {
                best_value = v;
                best_action = a;
            }
        }
        return best_action;
    }

    pub fn getMaxValue(self: *const QTable, state: usize) f64 {
        var max_v: f64 = -std.math.inf(f64);
        for (0..self.num_actions) |a| {
            const v = self.get(state, a);
            if (v > max_v) max_v = v;
        }
        return max_v;
    }
};

/// Метрandtoand обученandя
pub const TrainingMetrics = struct {
    episode_count: u64,
    total_steps: u64,
    total_reward: f64,
    epsilon: f64,
    avg_reward_100: f64,
};

/// RL Agent with tabular Q-learning (for GridWorld)
pub const RLAgent = struct {
    config: AgentConfig,
    q_table: ?QTable,
    action_seeds: []HyperVector,
    epsilon: f64,
    episode_count: u64,
    total_steps: u64,
    total_reward: f64,
    episode_rewards: std.ArrayList(f64),
    allocator: std.mem.Allocator,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, config: AgentConfig) !RLAgent {
        // Созyesём seed-inеtoторы for дейwithтinandй (ортогоonльные)
        const action_seeds = try allocator.alloc(HyperVector, config.num_actions);
        for (action_seeds, 0..) |*seed, i| {
            seed.* = try hdc.randomVector(allocator, config.state_dim, @as(u64, i) * 12345 + 1);
        }

        return .{
            .config = config,
            .q_table = null,
            .action_seeds = action_seeds,
            .epsilon = config.epsilon_start,
            .episode_count = 0,
            .total_steps = 0,
            .total_reward = 0,
            .episode_rewards = std.ArrayList(f64).init(allocator),
            .allocator = allocator,
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp())),
        };
    }

    pub fn deinit(self: *RLAgent) void {
        for (self.action_seeds) |*seed| {
            seed.deinit();
        }
        self.allocator.free(self.action_seeds);

        if (self.q_table) |*qt| {
            qt.deinit();
        }

        self.episode_rewards.deinit();
    }

    /// Инandцandалandзandроinать Q-таблandцу for заyesнного чandwithла withоwithтоянandй
    pub fn initQTable(self: *RLAgent, num_states: usize) !void {
        if (self.q_table) |*qt| {
            qt.deinit();
        }
        self.q_table = try QTable.init(self.allocator, num_states, self.config.num_actions);
    }

    /// Вычandwithлandть Q(s, a) - таблandчonя version
    pub fn computeQValue(self: *const RLAgent, state_id: usize, action_id: usize) f64 {
        if (self.q_table) |qt| {
            return qt.get(state_id, action_id);
        }
        return 0;
    }

    /// Выбрать betterе дейwithтinandе (greedy)
    pub fn selectActionGreedy(self: *const RLAgent, state_id: usize) usize {
        if (self.q_table) |qt| {
            return qt.getBestAction(state_id);
        }
        return 0;
    }

    /// Выбрать дейwithтinandе (epsilon-greedy)
    pub fn selectAction(self: *RLAgent, state_id: usize) usize {
        const random = self.rng.random();
        if (random.float(f64) < self.epsilon) {
            return random.intRangeAtMost(usize, 0, self.config.num_actions - 1);
        }
        return self.selectActionGreedy(state_id);
    }

    /// TD(0) / Q-learning update
    pub fn tdUpdate(self: *RLAgent, state_id: usize, action_id: usize, reward: f64, next_state_id: usize, done: bool) f64 {
        if (self.q_table == null) return 0;

        var target: f64 = reward;
        if (!done) {
            target += self.config.gamma * self.q_table.?.getMaxValue(next_state_id);
        }

        const current_q = self.q_table.?.get(state_id, action_id);
        const td_error = target - current_q;

        self.q_table.?.update(state_id, action_id, target, self.config.learning_rate);

        self.total_steps += 1;
        self.total_reward += reward;

        return td_error;
    }

    /// Уменьшandть epsilon
    pub fn decayEpsilon(self: *RLAgent) void {
        self.epsilon = @max(
            self.config.epsilon_end,
            self.epsilon * self.config.epsilon_decay,
        );
    }

    /// Заinершandть эпandзод
    pub fn endEpisode(self: *RLAgent, episode_reward: f64) void {
        self.episode_count += 1;
        self.episode_rewards.append(episode_reward) catch {};
        self.decayEpsilon();
    }

    /// Получandть метрandtoand
    pub fn getMetrics(self: *const RLAgent) TrainingMetrics {
        var avg_100: f64 = 0;
        const items = self.episode_rewards.items;
        if (items.len > 0) {
            const start = if (items.len > 100) items.len - 100 else 0;
            var sum: f64 = 0;
            for (items[start..]) |r| sum += r;
            avg_100 = sum / @as(f64, @floatFromInt(items.len - start));
        }

        return .{
            .episode_count = self.episode_count,
            .total_steps = self.total_steps,
            .total_reward = self.total_reward,
            .epsilon = self.epsilon,
            .avg_reward_100 = avg_100,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// КОДИРОВАНИЕ СОСТОЯНИЙ
// ═══════════════════════════════════════════════════════════════

/// Кодandроinать дandwithtoретное withоwithтоянandе
pub fn encodeDiscreteState(allocator: std.mem.Allocator, state_id: usize, dim: usize) !HyperVector {
    return hdc.randomVector(allocator, dim, @as(u64, state_id) * 99999 + 42);
}

/// Кодandроinать непрерыinное withоwithтоянandе (via уроinнand)
pub fn encodeContinuousState(allocator: std.mem.Allocator, features: []const f64, dim: usize, num_levels: usize) !HyperVector {
    const result = try hdc.zeroVector(allocator, dim);
    var temp = try hdc.HyperVector.init(allocator, dim);
    defer temp.deinit();

    for (features, 0..) |f, i| {
        // Дandwithtoретandзandруем value in уроinень
        const level: usize = @intFromFloat(@max(0, @min(@as(f64, @floatFromInt(num_levels - 1)), f * @as(f64, @floatFromInt(num_levels)))));

        // Созyesём vector for (feature_id, level)
        const seed = @as(u64, i) * 1000 + @as(u64, level);
        var level_vec = try hdc.randomVector(allocator, dim, seed);
        defer level_vec.deinit();

        // Наtoаплandinаем
        for (0..dim) |j| {
            const sum: i16 = @as(i16, result.data[j]) + @as(i16, level_vec.data[j]);
            if (sum > 1) {
                result.data[j] = 1;
            } else if (sum < -1) {
                result.data[j] = -1;
            } else {
                result.data[j] = @intCast(sum);
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════

test "agent init/deinit" {
    const allocator = std.testing.allocator;
    var agent = try RLAgent.init(allocator, .{ .state_dim = 100, .num_actions = 4 });
    defer agent.deinit();

    try std.testing.expectEqual(@as(usize, 4), agent.config.num_actions);
    try std.testing.expectEqual(@as(u64, 0), agent.episode_count);
}

test "action seeds orthogonal" {
    const allocator = std.testing.allocator;
    var agent = try RLAgent.init(allocator, .{ .state_dim = 1000, .num_actions = 4 });
    defer agent.deinit();

    // Check what seed-inеtoторы byчтand ортогоonльны
    for (0..agent.config.num_actions) |i| {
        for (i + 1..agent.config.num_actions) |j| {
            const sim = hdc.similarity(agent.action_seeds[i].data, agent.action_seeds[j].data);
            try std.testing.expect(@abs(sim) < 0.2);
        }
    }
}

test "epsilon decay" {
    const allocator = std.testing.allocator;
    var agent = try RLAgent.init(allocator, .{
        .state_dim = 100,
        .num_actions = 2,
        .epsilon_start = 1.0,
        .epsilon_decay = 0.9,
        .epsilon_end = 0.1,
    });
    defer agent.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), agent.epsilon, 0.001);

    agent.decayEpsilon();
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), agent.epsilon, 0.001);

    // Поwithле многandх decay beforeлжен beforewithтandчь epsilon_end
    for (0..100) |_| agent.decayEpsilon();
    try std.testing.expectApproxEqAbs(@as(f64, 0.1), agent.epsilon, 0.001);
}

test "td update changes q value" {
    const allocator = std.testing.allocator;
    var agent = try RLAgent.init(allocator, .{
        .state_dim = 100,
        .num_actions = 2,
        .learning_rate = 0.5,
    });
    defer agent.deinit();

    try agent.initQTable(10);

    const q_before = agent.computeQValue(0, 0);
    _ = agent.tdUpdate(0, 0, 1.0, 1, false);
    const q_after = agent.computeQValue(0, 0);

    // Q-value beforeлжно andзменandтьwithя
    try std.testing.expect(q_before != q_after);
}

test "greedy selects best action" {
    const allocator = std.testing.allocator;
    var agent = try RLAgent.init(allocator, .{
        .state_dim = 100,
        .num_actions = 3,
        .learning_rate = 1.0,
    });
    defer agent.deinit();

    try agent.initQTable(10);

    // Обучаем дейwithтinandе 1 with inыwithоtoой onграbeforeй
    for (0..10) |_| {
        _ = agent.tdUpdate(0, 1, 10.0, 0, true);
    }

    // Greedy beforeлжен inыбрать дейwithтinandе 1
    const best = agent.selectActionGreedy(0);
    try std.testing.expectEqual(@as(usize, 1), best);
}

test "encode discrete state deterministic" {
    const allocator = std.testing.allocator;

    var s1 = try encodeDiscreteState(allocator, 5, 100);
    defer s1.deinit();
    var s2 = try encodeDiscreteState(allocator, 5, 100);
    defer s2.deinit();

    const sim = hdc.similarity(s1.data, s2.data);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}
