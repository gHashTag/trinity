//! Demo GridWorld - withand and RL agent in GridWorld
//!
//! withto: zig build-exe src/phi-engine/hdc/demo_gridworld.zig && ./demo_gridworld
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const rl = @import("rl_agent.zig");
const gw = @import("gridworld.zig");

const print = std.debug.print;

/// and demo
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

/// withand demo and
pub fn runDemo(allocator: std.mem.Allocator, config: DemoConfig) !void {
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     TRINITY HDC RL AGENT - GRIDWORLD DEMO                    ║\n", .{});
    print("║     φ² + 1/φ² = 3                                            ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    print("\n", .{});

    // yes with
    var env = try gw.GridWorld.init(allocator, .{
        .width = config.grid_size,
        .height = config.grid_size,
        .step_reward = -0.1,
        .goal_reward = 10.0,
        .max_steps = config.grid_size * config.grid_size * 2,
    });
    defer env.deinit();

    print("yes: GridWorld {d}x{d}\n", .{ config.grid_size, config.grid_size });
    print(": ({d}, {d})\n", .{ env.goal_pos.x, env.goal_pos.y });
    print("withand: {d}\n", .{env.numStates()});
    print("withinand: {d}\n", .{gw.NUM_ACTIONS});
    print("\n", .{});

    // yes agent
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

    // Initialize Q-and
    try agent.initQTable(env.numStates());

    print("andon and ({d} andbeforein)...\n", .{config.num_episodes});
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
            // and withinand
            const action = agent.selectAction(state);

            // by withinand
            const result = env.step(action);

            // in agent (Q-learning)
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

        //  on for withto withnot
        recent_rewards[recent_idx] = episode_reward;
        recent_idx = (recent_idx + 1) % 100;

        //  with
        if ((episode + 1) % config.print_every == 0) {
            var avg_reward: f64 = 0;
            const count = @min(episode + 1, 100);
            for (0..count) |i| {
                avg_reward += recent_rewards[i];
            }
            avg_reward /= @as(f64, @floatFromInt(count));

            const win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(episode + 1)) * 100;

            print("and {d:4}: avg_reward={d:6.2}, win_rate={d:5.1}%, ε={d:.3}\n", .{
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

    // thatin statistics
    const metrics = agent.getMetrics();
    const final_win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(config.num_episodes)) * 100;

    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║                                            ║\n", .{});
    print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    print("║ andbeforein:        {d:6}                                       ║\n", .{config.num_episodes});
    print("║ with stepin:     {d:6}                                       ║\n", .{total_steps});
    print("║ :           {d:6} ({d:.1}%)                              ║\n", .{ wins, final_win_rate });
    print("║ Avg reward (100):{d:7.2}                                      ║\n", .{metrics.avg_reward_100});
    print("║ andon ε:     {d:6.4}                                      ║\n", .{agent.epsilon});
    print("║ :           {d:6} ms                                    ║\n", .{duration_ms});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // withand  agent
    if (config.render_final) {
        print("\n", .{});
        print("withand  agent (greedy policy):\n", .{});
        print("─────────────────────────────────────────────────────────────\n", .{});

        var demo_state = env.reset();
        env.render();

        for (0..20) |step_num| {
            const demo_action = agent.selectActionGreedy(demo_state);

            print(" {d}: withinand = {s}\n", .{ step_num + 1, @as(gw.Action, @enumFromInt(demo_action)).toString() });

            const demo_result = env.step(demo_action);
            env.render();

            if (demo_result.done) {
                if (std.mem.eql(u8, demo_result.info, "goal")) {
                    print("\n✅    {d} stepin!\n", .{step_num + 1});
                } else {
                    print("\n⚠️ and in: {s}\n", .{demo_result.info});
                }
                break;
            }

            demo_state = demo_result.next_state;
        }
    }

    print("\n", .{});
    print("φ² + 1/φ² = 3 | TRINITY HDC RL DEMO COMPLETE\n", .{});
}

/// to login
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
//
// ═══════════════════════════════════════════════════════════════

test "demo runs without crash" {
    const allocator = std.testing.allocator;

    // fromtoand test
    try runDemo(allocator, .{
        .grid_size = 2,
        .num_episodes = 10,
        .state_dim = 64,
        .print_every = 100,
        .render_final = false,
    });
}
