// Double Q-Learning for FrozenLake - Zig Implementation
// φ² + 1/φ² = 3 | TRINITY
// Double Q-Learning reduces overestimation bias

const std = @import("std");
const print = std.debug.print;

const FrozenLakeEnv = struct {
    state: u8 = 0,
    
    pub fn reset(self: *FrozenLakeEnv) u8 {
        self.state = 0;
        return 0;
    }
    
    pub fn step(self: *FrozenLakeEnv, action: u8) struct { state: u8, reward: f64, done: bool } {
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

const DoubleQLearningAgent = struct {
    q1: [16][4]f64 = [_][4]f64{[_]f64{0.0} ** 4} ** 16,
    q2: [16][4]f64 = [_][4]f64{[_]f64{0.0} ** 4} ** 16,
    lr: f64 = 0.5,
    gamma: f64 = 0.95,
    epsilon: f64 = 1.0,
    epsilon_min: f64 = 0.001,  // Very low minimum for near-perfect exploitation
    epsilon_decay: f64 = 0.997, // Even slower decay for better exploration
    rng: std.Random,
    
    pub fn init(seed: u64) DoubleQLearningAgent {
        var prng = std.Random.DefaultPrng.init(seed);
        return DoubleQLearningAgent{
            .rng = prng.random(),
        };
    }
    
    pub fn chooseAction(self: *DoubleQLearningAgent, state: u8) u8 {
        if (self.rng.float(f64) < self.epsilon) {
            return @intCast(self.rng.intRangeAtMost(u8, 0, 3));
        }
        
        // Use sum of both Q-tables for action selection
        var best_action: u8 = 0;
        var best_value = self.q1[state][0] + self.q2[state][0];
        
        for (1..4) |a| {
            const combined = self.q1[state][a] + self.q2[state][a];
            if (combined > best_value) {
                best_value = combined;
                best_action = @intCast(a);
            }
        }
        
        return best_action;
    }
    
    pub fn learn(self: *DoubleQLearningAgent, state: u8, action: u8, reward: f64, next_state: u8, done: bool) void {
        // Randomly update Q1 or Q2
        if (self.rng.float(f64) < 0.5) {
            // Update Q1 using Q2 for evaluation
            const current_q = self.q1[state][action];
            var target = reward;
            
            if (!done) {
                // Find best action using Q1
                var best_action: u8 = 0;
                var best_value = self.q1[next_state][0];
                for (1..4) |a| {
                    if (self.q1[next_state][a] > best_value) {
                        best_value = self.q1[next_state][a];
                        best_action = @intCast(a);
                    }
                }
                // Evaluate using Q2
                target = reward + self.gamma * self.q2[next_state][best_action];
            }
            
            self.q1[state][action] = current_q + self.lr * (target - current_q);
        } else {
            // Update Q2 using Q1 for evaluation
            const current_q = self.q2[state][action];
            var target = reward;
            
            if (!done) {
                // Find best action using Q2
                var best_action: u8 = 0;
                var best_value = self.q2[next_state][0];
                for (1..4) |a| {
                    if (self.q2[next_state][a] > best_value) {
                        best_value = self.q2[next_state][a];
                        best_action = @intCast(a);
                    }
                }
                // Evaluate using Q1
                target = reward + self.gamma * self.q1[next_state][best_action];
            }
            
            self.q2[state][action] = current_q + self.lr * (target - current_q);
        }
    }
    
    pub fn decayEpsilon(self: *DoubleQLearningAgent) void {
        self.epsilon = @max(self.epsilon_min, self.epsilon * self.epsilon_decay);
    }
};

pub fn main() !void {
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     DOUBLE Q-LEARNING - FROZEN LAKE                          ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY                                  ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});
    
    print("Training Double Q-Learning agent...\n", .{});
    print("Params: lr=0.5, gamma=0.95, epsilon_decay=0.995\n\n", .{});
    
    var env = FrozenLakeEnv{};
    var agent = DoubleQLearningAgent.init(42);
    
    const n_episodes: u32 = 10000;
    var wins: u32 = 0;
    var total_reward: f64 = 0.0;
    var consecutive_wins: u32 = 0;
    var max_consecutive: u32 = 0;
    
    // Track last 1000 for convergence
    var last_1000: [1000]bool = [_]bool{false} ** 1000;
    var idx: usize = 0;
    
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
            const win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(episode + 1)) * 100.0;
            const recent_rate = @as(f64, @floatFromInt(last_1000_wins)) / 10.0;
            print("Episode {d:5} | Total: {d:5.1}% | Last 1000: {d:5.1}% | ε: {d:.4}\n", .{ episode + 1, win_rate, recent_rate, agent.epsilon });
        }
    }
    
    // Calculate final last 1000
    var final_last_1000: u32 = 0;
    for (last_1000) |w| {
        if (w) final_last_1000 += 1;
    }
    
    print("\n═══════════════════════════════════════════════════════════════\n", .{});
    print("                    FINAL RESULTS\n", .{});
    print("═══════════════════════════════════════════════════════════════\n", .{});
    print("  Episodes:           {d}\n", .{n_episodes});
    print("  Total Wins:         {d}\n", .{wins});
    print("  Overall Win Rate:   {d:.2}%\n", .{@as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(n_episodes)) * 100.0});
    print("  Last 1000 Rate:     {d:.1}%\n", .{@as(f64, @floatFromInt(final_last_1000)) / 10.0});
    print("  Max Consecutive:    {d}\n", .{max_consecutive});
    
    // Print Q-table best actions (using combined Q1+Q2)
    print("\nQ-table (best actions from Q1+Q2):\n", .{});
    const arrows = [_][]const u8{ "←", "↓", "→", "↑" };
    
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
                var best_value = agent.q1[state][0] + agent.q2[state][0];
                for (1..4) |a| {
                    const combined = agent.q1[state][a] + agent.q2[state][a];
                    if (combined > best_value) {
                        best_value = combined;
                        best_action = @intCast(a);
                    }
                }
                print(" {s}  ", .{arrows[best_action]});
            }
        }
        print("\n", .{});
    }
    
    const final_rate = @as(f64, @floatFromInt(final_last_1000)) / 10.0;
    print("\n", .{});
    if (final_rate >= 99.9) {
        print("🏆 PERFECT AGENT! 99.9%+ WIN RATE (last 1000)! 🏆\n", .{});
    } else if (final_rate >= 99.0) {
        print("✅ EXCELLENT! 99%+ WIN RATE (last 1000)!\n", .{});
    } else if (final_rate >= 98.0) {
        print("📈 Very good: 98%+ WIN RATE (last 1000)\n", .{});
    } else {
        print("📊 Win rate: {d:.1}%\n", .{final_rate});
    }
}

test "double_q_learning" {
    var env = FrozenLakeEnv{};
    _ = env.reset();
    const result = env.step(2);
    try std.testing.expect(result.state == 1);
}
