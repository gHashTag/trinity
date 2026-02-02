// RL Agent for FrozenLake - Zig Implementation
// φ² + 1/φ² = 3 | TRINITY
// Optimal params: lr=0.5, gamma=0.95, epsilon_decay=0.99

const std = @import("std");
const print = std.debug.print;

// FrozenLake 4x4 grid
// S=start(0), F=frozen, H=hole, G=goal(15)
// Actions: 0=left, 1=down, 2=right, 3=up

const FrozenLakeEnv = struct {
    state: u8 = 0,
    
    // Grid: SFFF, FHFH, FFFH, HFFG
    // Holes at: 5, 7, 11, 12
    // Goal at: 15
    
    pub fn reset(self: *FrozenLakeEnv) u8 {
        self.state = 0;
        return 0;
    }
    
    pub fn step(self: *FrozenLakeEnv, action: u8) struct { state: u8, reward: f64, done: bool } {
        var row: i8 = @intCast(self.state / 4);
        var col: i8 = @intCast(self.state % 4);
        
        switch (action) {
            0 => col = @max(0, col - 1),      // left
            1 => row = @min(3, row + 1),      // down
            2 => col = @min(3, col + 1),      // right
            3 => row = @max(0, row - 1),      // up
            else => {},
        }
        
        self.state = @intCast(@as(i8, row) * 4 + col);
        
        // Check cell type
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

const QLearningAgent = struct {
    q_table: [16][4]f64 = [_][4]f64{[_]f64{0.0} ** 4} ** 16,
    lr: f64 = 0.5,
    gamma: f64 = 0.95,
    epsilon: f64 = 1.0,
    epsilon_min: f64 = 0.01,
    epsilon_decay: f64 = 0.99,
    rng: std.Random,
    
    pub fn init(seed: u64) QLearningAgent {
        var prng = std.Random.DefaultPrng.init(seed);
        return QLearningAgent{
            .rng = prng.random(),
        };
    }
    
    pub fn chooseAction(self: *QLearningAgent, state: u8) u8 {
        if (self.rng.float(f64) < self.epsilon) {
            return @intCast(self.rng.intRangeAtMost(u8, 0, 3));
        }
        
        // Greedy
        var best_action: u8 = 0;
        var best_value = self.q_table[state][0];
        
        for (1..4) |a| {
            if (self.q_table[state][a] > best_value) {
                best_value = self.q_table[state][a];
                best_action = @intCast(a);
            }
        }
        
        return best_action;
    }
    
    pub fn learn(self: *QLearningAgent, state: u8, action: u8, reward: f64, next_state: u8, done: bool) void {
        const current_q = self.q_table[state][action];
        
        var target = reward;
        if (!done) {
            var max_next_q = self.q_table[next_state][0];
            for (1..4) |a| {
                if (self.q_table[next_state][a] > max_next_q) {
                    max_next_q = self.q_table[next_state][a];
                }
            }
            target = reward + self.gamma * max_next_q;
        }
        
        self.q_table[state][action] = current_q + self.lr * (target - current_q);
    }
    
    pub fn decayEpsilon(self: *QLearningAgent) void {
        self.epsilon = @max(self.epsilon_min, self.epsilon * self.epsilon_decay);
    }
};

pub fn main() !void {
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     RL FROZEN LAKE - ZIG IMPLEMENTATION                      ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY                                  ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});
    
    print("Training Q-Learning agent...\n", .{});
    print("Params: lr=0.5, gamma=0.95, epsilon_decay=0.99\n\n", .{});
    
    var env = FrozenLakeEnv{};
    var agent = QLearningAgent.init(42);
    
    const n_episodes: u32 = 5000;
    var wins: u32 = 0;
    var total_reward: f64 = 0.0;
    var consecutive_wins: u32 = 0;
    var max_consecutive: u32 = 0;
    
    for (0..n_episodes) |episode| {
        _ = env.reset();
        var episode_reward: f64 = 0.0;
        
        for (0..100) |_| {
            const state = env.state;
            const action = agent.chooseAction(state);
            const result = env.step(action);
            
            agent.learn(state, action, result.reward, result.state, result.done);
            episode_reward += result.reward;
            
            if (result.done) break;
        }
        
        agent.decayEpsilon();
        total_reward += episode_reward;
        
        if (episode_reward > 5.0) {
            wins += 1;
            consecutive_wins += 1;
            if (consecutive_wins > max_consecutive) {
                max_consecutive = consecutive_wins;
            }
        } else {
            consecutive_wins = 0;
        }
        
        if ((episode + 1) % 500 == 0) {
            const win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(episode + 1)) * 100.0;
            print("Episode {d:5} | Wins: {d:4} | Rate: {d:5.1}% | ε: {d:.4}\n", .{ episode + 1, wins, win_rate, agent.epsilon });
        }
    }
    
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    FINAL RESULTS\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("  Episodes:           {d}\n", .{n_episodes});
    print("  Wins:               {d}\n", .{wins});
    print("  Win Rate:           {d:.2}%\n", .{@as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(n_episodes)) * 100.0});
    print("  Avg Reward:         {d:.2}\n", .{total_reward / @as(f64, @floatFromInt(n_episodes))});
    print("  Max Consecutive:    {d}\n", .{max_consecutive});
    
    // Print Q-table best actions
    print("\nQ-table (best actions):\n", .{});
    print("  ↑=3, ↓=1, ←=0, →=2\n", .{});
    const arrows = [_][]const u8{ "←", "↓", "→", "↑" };
    const grid = "SFFFFFFHFHFFFHHFFG";
    _ = grid;
    
    for (0..4) |i| {
        print("  ", .{});
        for (0..4) |j| {
            const state: u8 = @intCast(i * 4 + j);
            const holes = [_]u8{ 5, 7, 11, 12 };
            var is_hole = false;
            for (holes) |h| {
                if (state == h) is_hole = true;
            }
            
            if (is_hole) {
                print(" ⬛ ", .{});
            } else if (state == 15) {
                print(" 🎯 ", .{});
            } else {
                var best_action: u8 = 0;
                var best_value = agent.q_table[state][0];
                for (1..4) |a| {
                    if (agent.q_table[state][a] > best_value) {
                        best_value = agent.q_table[state][a];
                        best_action = @intCast(a);
                    }
                }
                print(" {s}  ", .{arrows[best_action]});
            }
        }
        print("\n", .{});
    }
    
    const final_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(n_episodes)) * 100.0;
    print("\n", .{});
    if (final_rate >= 99.9) {
        print("🏆 PERFECT AGENT ACHIEVED! 99.9%+ WIN RATE! 🏆\n", .{});
    } else if (final_rate >= 99.0) {
        print("✅ EXCELLENT! 99%+ WIN RATE!\n", .{});
    } else if (final_rate >= 95.0) {
        print("📈 Good progress: 95%+ WIN RATE\n", .{});
    } else {
        print("📊 Room for improvement\n", .{});
    }
}

test "rl_frozen_lake" {
    var env = FrozenLakeEnv{};
    _ = env.reset();
    
    // Test basic movement
    const result = env.step(2); // right
    try std.testing.expect(result.state == 1);
    try std.testing.expect(!result.done);
}
