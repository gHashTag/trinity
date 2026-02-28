//! Demo Memory Agent - Agent with memory[EN] in GridWorld
//!
//! [CYR:[EN]]with[CYR:[EN]]and[EN] RL agent[EN] with Streaming Memory for experience replay.
//! [CYR:[EN]]: beforewith[EN]and[EN] 100% win rate [CYR:[EN]]yes[EN] [CYR:[EN]]and.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const gw = @import("gridworld.zig");
const rlm = @import("rl_agent_memory.zig");

const print = std.debug.print;

/// [CYR:[EN]]and[CYR:[EN]]and[EN] demo
const DemoConfig = struct {
    grid_size: usize = 4,
    num_episodes: usize = 1000,
    state_dim: usize = 256,
    memory_dim: usize = 2000,
    learning_rate: f64 = 0.2,
    gamma: f64 = 0.95,
    epsilon_start: f64 = 1.0,
    epsilon_end: f64 = 0.01,
    epsilon_decay: f64 = 0.99,
    print_every: usize = 100,
    render_final: bool = true,
};

/// [CYR:[EN]]with[EN]and[EN] demo
pub fn runDemo(allocator: std.mem.Allocator, config: DemoConfig) !void {
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     TRINITY HDC RL AGENT WITH MEMORY - GRIDWORLD             ║\n", .{});
    print("║     φ² + 1/φ² = 3                                            ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    print("\n", .{});

    // [CYR:[EN]]yes[EN] with[CYR:[EN]]
    var env = try gw.GridWorld.init(allocator, .{
        .width = config.grid_size,
        .height = config.grid_size,
        .step_reward = -0.1,
        .goal_reward = 10.0,
        .max_steps = config.grid_size * config.grid_size * 2,
    });
    defer env.deinit();

    print("[CYR:[EN]]yes: GridWorld {d}x{d}\n", .{ config.grid_size, config.grid_size });
    print("[EN]with[CYR:[EN]]and[EN]: {d}, [CYR:[EN]]with[EN]inand[EN]: {d}\n", .{ env.numStates(), gw.NUM_ACTIONS });
    print("\n", .{});

    // [CYR:[EN]]yes[EN] agent[EN] with memory[EN]
    var agent = try rlm.RLAgentWithMemory.init(allocator, .{
        .state_dim = config.state_dim,
        .num_actions = gw.NUM_ACTIONS,
        .num_states = env.numStates(),
        .gamma = config.gamma,
        .learning_rate = config.learning_rate,
        .epsilon_start = config.epsilon_start,
        .epsilon_end = config.epsilon_end,
        .epsilon_decay = config.epsilon_decay,
        .memory_dim = config.memory_dim,
    });
    defer agent.deinit();

    print("Agent: HDC RL with Streaming Memory\n", .{});
    print("Parameters: γ={d:.2}, α={d:.2}, memory_dim={d}\n", .{
        config.gamma,
        config.learning_rate,
        config.memory_dim,
    });
    print("\n", .{});

    print("[CYR:[EN]]andon[EN] [CYR:[EN]]and[EN] ({d} [EN]and[EN]beforein)...\n", .{config.num_episodes});
    print("─────────────────────────────────────────────────────────────\n", .{});

    var total_steps: u64 = 0;
    var wins: u64 = 0;
    var recent_rewards: [100]f64 = [_]f64{0} ** 100;
    var recent_idx: usize = 0;
    var consecutive_wins: u64 = 0;
    var max_consecutive_wins: u64 = 0;

    const start_time = std.time.milliTimestamp();

    for (0..config.num_episodes) |episode| {
        var state = env.reset();
        var episode_reward: f64 = 0;
        var episode_steps: usize = 0;

        while (true) {
            const action = agent.selectAction(state);
            const result = env.step(action);

            const exp = rlm.Experience{
                .state_id = state,
                .action_id = action,
                .reward = result.reward,
                .next_state_id = result.next_state,
                .done = result.done,
            };

            _ = try agent.learnWithReplay(exp);

            episode_reward += result.reward;
            episode_steps += 1;
            state = result.next_state;

            if (result.done) {
                if (std.mem.eql(u8, result.info, "goal")) {
                    wins += 1;
                    consecutive_wins += 1;
                    if (consecutive_wins > max_consecutive_wins) {
                        max_consecutive_wins = consecutive_wins;
                    }
                } else {
                    consecutive_wins = 0;
                }
                break;
            }
        }

        agent.endEpisode(episode_reward);
        total_steps += episode_steps;

        recent_rewards[recent_idx] = episode_reward;
        recent_idx = (recent_idx + 1) % 100;

        if ((episode + 1) % config.print_every == 0) {
            var avg_reward: f64 = 0;
            const count = @min(episode + 1, 100);
            for (0..count) |i| {
                avg_reward += recent_rewards[i];
            }
            avg_reward /= @as(f64, @floatFromInt(count));

            const win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(episode + 1)) * 100;

            print("[EN]and[CYR:[EN]] {d:4}: avg={d:6.2}, win={d:5.1}%, ε={d:.3}, mem={d}\n", .{
                episode + 1,
                avg_reward,
                win_rate,
                agent.getEpsilon(),
                agent.experience_count,
            });
        }
    }

    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;

    print("─────────────────────────────────────────────────────────────\n", .{});
    print("\n", .{});

    const metrics = agent.getMetrics();
    const mem_metrics = agent.getMemoryMetrics();
    const final_win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(config.num_episodes)) * 100;

    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║                    [CYR:[EN]] [CYR:[EN]]                       ║\n", .{});
    print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    print("║ [EN]and[EN]beforein:           {d:6}                                    ║\n", .{config.num_episodes});
    print("║ [EN]with[CYR:[EN]] step[EN]in:        {d:6}                                    ║\n", .{total_steps});
    print("║ [CYR:[EN]]:              {d:6} ({d:.1}%)                           ║\n", .{ wins, final_win_rate });
    print("║ Max consecutive:    {d:6}                                    ║\n", .{max_consecutive_wins});
    print("║ Avg reward (100):   {d:7.2}                                   ║\n", .{metrics.avg_reward_100});
    print("║ [EN]andon[CYR:[EN]] ε:        {d:6.4}                                   ║\n", .{agent.getEpsilon()});
    print("║ Experience[EN]in in [CYR:[EN]]and:    {d:6}                                    ║\n", .{mem_metrics.total_writes});
    print("║ [CYR:[EN]]:              {d:6} ms                                 ║\n", .{duration_ms});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // [CYR:[EN]]with[CYR:[EN]]and[EN]
    if (config.render_final) {
        print("\n", .{});
        print("[CYR:[EN]]with[CYR:[EN]]and[EN] [CYR:[EN]] agent[EN] (greedy policy):\n", .{});
        print("─────────────────────────────────────────────────────────────\n", .{});

        var demo_state = env.reset();
        env.render();

        for (0..20) |step_num| {
            const demo_action = agent.selectActionGreedy(demo_state);

            print("[CYR:[EN]] {d}: [CYR:[EN]]with[EN]inand[EN] = {s}\n", .{ step_num + 1, @as(gw.Action, @enumFromInt(demo_action)).toString() });

            const demo_result = env.step(demo_action);
            env.render();

            if (demo_result.done) {
                if (std.mem.eql(u8, demo_result.info, "goal")) {
                    print("\n✅ [CYR:[EN]] [CYR:[EN]] [EN] {d} step[EN]in!\n", .{step_num + 1});
                } else {
                    print("\n⚠️ [EN]and[CYR:[EN]] [EN]in[CYR:[EN]]: {s}\n", .{demo_result.info});
                }
                break;
            }

            demo_state = demo_result.next_state;
        }
    }

    print("\n", .{});
    if (final_win_rate >= 99.0) {
        print("🏆 [CYR:[EN]] [CYR:[EN]]: {d:.1}% WIN RATE!\n", .{final_win_rate});
    } else if (final_win_rate >= 95.0) {
        print("✅ [CYR:[EN]] [CYR:[EN]]: {d:.1}% WIN RATE\n", .{final_win_rate});
    } else {
        print("⚠️ [CYR:[EN]]with[EN] before[CYR:[EN]]fromto[EN]: {d:.1}% WIN RATE\n", .{final_win_rate});
    }
    print("\n", .{});
    print("φ² + 1/φ² = 3 | TRINITY HDC RL WITH MEMORY COMPLETE\n", .{});
}

/// [CYR:[EN]]to[EN] login[EN] ([CYR:[EN]]to[EN] for andwithby[CYR:[EN]] file[EN])
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runDemo(allocator, .{
        .grid_size = 4,
        .num_episodes = 1000,
        .print_every = 200,
    });
}

// [EN]to[CYR:[EN]] main [EN]and testand[EN]in[EN]andand
comptime {
    if (@import("builtin").is_test) {
        _ = main;
    }
}

// ═══════════════════════════════════════════════════════════════
// [CYR:[EN]]
// ═══════════════════════════════════════════════════════════════

test "agent with memory learns" {
    const allocator = std.testing.allocator;

    // [CYR:[EN]]yes[EN] with[CYR:[EN]]
    var env = try gw.GridWorld.init(allocator, .{
        .width = 2,
        .height = 2,
    });
    defer env.deinit();

    // [CYR:[EN]]yes[EN] agent[EN]
    var agent = try rlm.RLAgentWithMemory.init(allocator, .{
        .num_states = 4,
        .num_actions = 4,
        .epsilon_start = 0.5,
        .epsilon_decay = 0.9,
    });
    defer agent.deinit();

    // [CYR:[EN]] 50 [EN]and[EN]beforein
    var wins: u32 = 0;
    for (0..50) |_| {
        var state = env.reset();
        while (true) {
            const action = agent.selectAction(state);
            const result = env.step(action);

            const exp = rlm.Experience{
                .state_id = state,
                .action_id = action,
                .reward = result.reward,
                .next_state_id = result.next_state,
                .done = result.done,
            };
            _ = try agent.learnWithReplay(exp);

            state = result.next_state;
            if (result.done) {
                if (std.mem.eql(u8, result.info, "goal")) wins += 1;
                break;
            }
        }
        agent.decayEpsilon();
    }

    // [CYR:[EN]] in[EN]and[CYR:[EN]] [EN]from[EN] [EN] 30% (2x2 grid [CYR:[EN]]with[CYR:[EN]])
    try std.testing.expect(wins > 15);
}
