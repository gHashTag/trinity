//! RL Agent with Streaming Memory - Experience Replay
//!
//! Agent with long-term memory[EN] for storing experience[EN].
//! [EN]withby[CYR:[EN]] Streaming Memory for experience replay.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const rl = @import("rl_agent.zig");
const sm = @import("streaming_memory.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

/// Experience for storing in [CYR:[EN]]and
pub const Experience = struct {
    state_id: usize,
    action_id: usize,
    reward: f64,
    next_state_id: usize,
    done: bool,
};

/// [CYR:[EN]]and[CYR:[EN]]and[EN] agent[EN] with memory[EN]
pub const MemoryAgentConfig = struct {
    state_dim: usize = 256,
    num_actions: usize = 4,
    num_states: usize = 16,
    gamma: f64 = 0.95,
    learning_rate: f64 = 0.1,
    epsilon_start: f64 = 1.0,
    epsilon_end: f64 = 0.01,
    epsilon_decay: f64 = 0.995,
    memory_dim: usize = 2000,
    replay_batch_size: usize = 10,
    forgetting_factor: f64 = 0.001,
};

/// RL Agent with Streaming Memory
pub const RLAgentWithMemory = struct {
    config: MemoryAgentConfig,
    base_agent: rl.RLAgent,
    memory: sm.StreamingMemory,
    experience_count: u64,
    replay_count: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: MemoryAgentConfig) !RLAgentWithMemory {
        var base_agent = try rl.RLAgent.init(allocator, .{
            .state_dim = config.state_dim,
            .num_actions = config.num_actions,
            .gamma = config.gamma,
            .learning_rate = config.learning_rate,
            .epsilon_start = config.epsilon_start,
            .epsilon_end = config.epsilon_end,
            .epsilon_decay = config.epsilon_decay,
        });

        try base_agent.initQTable(config.num_states);

        const memory = try sm.StreamingMemory.init(allocator, .{
            .dim = config.memory_dim,
            .forgetting_factor = config.forgetting_factor,
        });

        return .{
            .config = config,
            .base_agent = base_agent,
            .memory = memory,
            .experience_count = 0,
            .replay_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RLAgentWithMemory) void {
        self.base_agent.deinit();
        self.memory.deinit();
    }

    /// [CYR:[EN]] [CYR:[EN]]with[EN]inand[EN]
    pub fn selectAction(self: *RLAgentWithMemory, state_id: usize) usize {
        return self.base_agent.selectAction(state_id);
    }

    /// [CYR:[EN]] better[EN] [CYR:[EN]]with[EN]inand[EN] (greedy)
    pub fn selectActionGreedy(self: *const RLAgentWithMemory, state_id: usize) usize {
        return self.base_agent.selectActionGreedy(state_id);
    }

    /// [CYR:[EN]]and[EN] experience in memory
    pub fn storeExperience(self: *RLAgentWithMemory, exp: Experience) !void {
        // Encode experience how to[CYR:[EN]]-value
        // [CYR:[EN]]: state_id + action_id
        // [EN]on[CYR:[EN]]and[EN]: reward + next_state + done
        const key_seed = @as(u64, exp.state_id) * 1000 + @as(u64, exp.action_id);
        const value_seed = @as(u64, @intFromFloat(exp.reward * 1000)) + @as(u64, exp.next_state_id) * 10000;

        var key = try hdc.randomVector(self.allocator, self.config.memory_dim, key_seed);
        defer key.deinit();
        var value = try hdc.randomVector(self.allocator, self.config.memory_dim, value_seed);
        defer value.deinit();

        try self.memory.storeWithForgetting(key.data, value.data, self.config.forgetting_factor);
        self.experience_count += 1;
    }

    /// [CYR:[EN]]and[EN] on [CYR:[EN]] experience[EN]
    pub fn learn(self: *RLAgentWithMemory, exp: Experience) f64 {
        return self.base_agent.tdUpdate(exp.state_id, exp.action_id, exp.reward, exp.next_state_id, exp.done);
    }

    /// [CYR:[EN]]and[EN] with experience replay
    pub fn learnWithReplay(self: *RLAgentWithMemory, current_exp: Experience) !f64 {
        // [EN]on[CYR:[EN]] [EN]and[EN]with[EN] on [EN]to[CYR:[EN]] experience[EN]
        const td_error = self.learn(current_exp);

        // [CYR:[EN]] in memory
        try self.storeExperience(current_exp);

        self.replay_count += 1;
        return td_error;
    }

    /// [CYR:[EN]]and[EN] epsilon
    pub fn decayEpsilon(self: *RLAgentWithMemory) void {
        self.base_agent.decayEpsilon();
    }

    /// [EN]in[CYR:[EN]]and[EN] [EN]and[CYR:[EN]]
    pub fn endEpisode(self: *RLAgentWithMemory, episode_reward: f64) void {
        self.base_agent.endEpisode(episode_reward);
    }

    /// [CYR:[EN]]and[EN] epsilon
    pub fn getEpsilon(self: *const RLAgentWithMemory) f64 {
        return self.base_agent.epsilon;
    }

    /// [CYR:[EN]]and[EN] [CYR:[EN]]andtoand
    pub fn getMetrics(self: *const RLAgentWithMemory) rl.TrainingMetrics {
        return self.base_agent.getMetrics();
    }

    /// [CYR:[EN]]and[EN] [CYR:[EN]]andtoand [CYR:[EN]]and
    pub fn getMemoryMetrics(self: *const RLAgentWithMemory) sm.MemoryMetrics {
        return self.memory.getMetrics();
    }
};

// ═══════════════════════════════════════════════════════════════
// [CYR:[EN]]
// ═══════════════════════════════════════════════════════════════

test "agent with memory init/deinit" {
    const allocator = std.testing.allocator;
    var agent = try RLAgentWithMemory.init(allocator, .{
        .num_states = 16,
        .num_actions = 4,
    });
    defer agent.deinit();

    try std.testing.expectEqual(@as(u64, 0), agent.experience_count);
}

test "store and learn" {
    const allocator = std.testing.allocator;
    var agent = try RLAgentWithMemory.init(allocator, .{
        .num_states = 16,
        .num_actions = 4,
    });
    defer agent.deinit();

    const exp = Experience{
        .state_id = 0,
        .action_id = 1,
        .reward = 1.0,
        .next_state_id = 1,
        .done = false,
    };

    _ = try agent.learnWithReplay(exp);

    try std.testing.expectEqual(@as(u64, 1), agent.experience_count);
}

test "multiple experiences" {
    const allocator = std.testing.allocator;
    var agent = try RLAgentWithMemory.init(allocator, .{
        .num_states = 16,
        .num_actions = 4,
    });
    defer agent.deinit();

    for (0..10) |i| {
        const exp = Experience{
            .state_id = i % 16,
            .action_id = i % 4,
            .reward = 0.5,
            .next_state_id = (i + 1) % 16,
            .done = i == 9,
        };
        _ = try agent.learnWithReplay(exp);
    }

    try std.testing.expectEqual(@as(u64, 10), agent.experience_count);
}
