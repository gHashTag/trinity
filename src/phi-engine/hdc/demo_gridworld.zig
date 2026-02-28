//! Demo GridWorld - [CYR:[EN]]with[CYR:[EN]]and[EN] [CYR:[EN]]and[EN] RL agent[EN] in GridWorld
//!
//! [CYR:[EN]]withto: zig build-exe src/phi-engine/hdc/demo_gridworld.zig && ./demo_gridworld
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const rl = @import("rl_agent.zig");
const gw = @import("gridworld.zig");

const print = std.debug.print;

/// [CYR:[EN]]and[CYR:[EN]]and[EN] demo
const DemoConfig = struct {
    grid_size: usize = 4,
    num_episodes: usize = 500,
    state_dim: usize = 256,
    learning_rate: f64 = 0.1,
    gamma: f64 = 0.95,
    epsilon_start: f64 = 1.0,
    epsilon_end: f64 = 0.01,
    epsilon_decay: f64 = 0.995,
    print_every: usize = 50,
    render_final: bool = true,
};

/// [CYR:[EN]]with[EN]and[EN] demo [CYR:[EN]]and[EN]
pub fn runDemo(allocator: std.mem.Allocator, config: DemoConfig) !void {
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     TRINITY HDC RL AGENT - GRIDWORLD DEMO                    ║\n", .{});
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
    print("[CYR:[EN]]: ({d}, {d})\n", .{ env.goal_pos.x, env.goal_pos.y });
    print("[EN]with[CYR:[EN]]and[EN]: {d}\n", .{ env.numStates() });
    print("[CYR:[EN]]with[EN]inand[EN]: {d}\n", .{gw.NUM_ACTIONS});
    print("\n", .{});

    // [CYR:[EN]]yes[EN] agent[EN]
    var agent = try rl.RLAgent.init(allocator, .{
        .state_dim = config.state_dim,
        .num_actions = gw.NUM_ACTIONS,
        .gamma = config.gamma,
        .learning_rate = config.learning_rate,
        .epsilon_start = config.epsilon_start,
        .epsilon_end = config.epsilon_end,
        .epsilon_decay = config.epsilon_decay,
    });
    defer agent.deinit();

    print("Agent: HDC RL with {d}-dimensional vectors\n", .{config.state_dim});
    print("Parameters: γ={d:.2}, α={d:.2}, ε={d:.2}→{d:.2}\n", .{
        config.gamma,
        config.learning_rate,
        config.epsilon_start,
        config.epsilon_end,
    });
    print("\n", .{});

    // Initialize Q-[CYR:[EN]]and[EN]
    try agent.initQTable(env.numStates());

    print("[CYR:[EN]]andon[EN] [CYR:[EN]]and[EN] ({d} [EN]and[EN]beforein)...\n", .{config.num_episodes});
    print("─────────────────────────────────────────────────────────────\n", .{});

    var total_steps: u64 = 0;
    var wins: u64 = 0;
    var recent_rewards: [100]f64 = [_]f64{0} ** 100;
    var recent_idx: usize = 0;

    const start_time = std.time.milliTimestamp();

    for (0..config.num_episodes) |episode| {
        var state = env.reset();
        var episode_reward: f64 = 0;
        var episode_steps: usize = 0;

        while (true) {
            // [CYR:[EN]]and[CYR:[EN]] [CYR:[EN]]with[EN]inand[EN]
            const action = agent.selectAction(state);

            // [EN]by[CYR:[EN]] [CYR:[EN]]with[EN]inand[EN]
            const result = env.step(action);

            // [CYR:[EN]]in[CYR:[EN]] agent[EN] (Q-learning)
            _ = agent.tdUpdate(state, action, result.reward, result.next_state, result.done);

            episode_reward += result.reward;
            episode_steps += 1;
            state = result.next_state;

            if (result.done) {
                if (std.mem.eql(u8, result.info, "goal")) {
                    wins += 1;
                }
                break;
            }
        }

        agent.endEpisode(episode_reward);
        total_steps += episode_steps;

        // [CYR:[EN]] on[CYR:[EN]] for withto[CYR:[EN]] with[CYR:[EN]]not[EN]
        recent_rewards[recent_idx] = episode_reward;
        recent_idx = (recent_idx + 1) % 100;

        // [CYR:[EN]] [CYR:[EN]]withwith
        if ((episode + 1) % config.print_every == 0) {
            var avg_reward: f64 = 0;
            const count = @min(episode + 1, 100);
            for (0..count) |i| {
                avg_reward += recent_rewards[i];
            }
            avg_reward /= @as(f64, @floatFromInt(count));

            const win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(episode + 1)) * 100;

            print("[EN]and[CYR:[EN]] {d:4}: avg_reward={d:6.2}, win_rate={d:5.1}%, ε={d:.3}\n", .{
                episode + 1,
                avg_reward,
                win_rate,
                agent.epsilon,
            });
        }
    }

    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;

    print("─────────────────────────────────────────────────────────────\n", .{});
    print("\n", .{});

    // [EN]thatin[EN] statistics
    const metrics = agent.getMetrics();
    const final_win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(config.num_episodes)) * 100;

    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║                    [CYR:[EN]] [CYR:[EN]]                       ║\n", .{});
    print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    print("║ [EN]and[EN]beforein:        {d:6}                                       ║\n", .{config.num_episodes});
    print("║ [EN]with[CYR:[EN]] step[EN]in:     {d:6}                                       ║\n", .{total_steps});
    print("║ [CYR:[EN]]:           {d:6} ({d:.1}%)                              ║\n", .{ wins, final_win_rate });
    print("║ Avg reward (100):{d:7.2}                                      ║\n", .{metrics.avg_reward_100});
    print("║ [EN]andon[CYR:[EN]] ε:     {d:6.4}                                      ║\n", .{agent.epsilon});
    print("║ [CYR:[EN]]:           {d:6} ms                                    ║\n", .{duration_ms});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // [CYR:[EN]]with[CYR:[EN]]and[EN] [CYR:[EN]] agent[EN]
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
    print("φ² + 1/φ² = 3 | TRINITY HDC RL DEMO COMPLETE\n", .{});
}

/// [CYR:[EN]]to[EN] login[EN]
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runDemo(allocator, .{
        .grid_size = 4,
        .num_episodes = 500,
        .state_dim = 256,
        .print_every = 100,
    });
}

// ═══════════════════════════════════════════════════════════════
// [CYR:[EN]]
// ═══════════════════════════════════════════════════════════════

test "demo runs without crash" {
    const allocator = std.testing.allocator;

    // [CYR:[EN]]fromtoand[EN] test
    try runDemo(allocator, .{
        .grid_size = 2,
        .num_episodes = 10,
        .state_dim = 64,
        .print_every = 100,
        .render_final = false,
    });
}
