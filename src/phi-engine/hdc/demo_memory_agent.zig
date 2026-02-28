//! Demo Memory Agent - Agent with memoryю in GridWorld
//!
//! Демонwithтрацandя RL agentа with Streaming Memory for experience replay.
//! Цель: beforewithтandчь 100% win rate благоyesря памятand.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");
const gw = @import("gridworld.zig");
const rlm = @import("rl_agent_memory.zig");

const print = std.debug.print;

/// Конфandгурацandя демо
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

/// Запуwithтandть демо
pub fn runDemo(allocator: std.mem.Allocator, config: DemoConfig) !void {
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     TRINITY HDC RL AGENT WITH MEMORY - GRIDWORLD             ║\n", .{});
    print("║     φ² + 1/φ² = 3                                            ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    print("\n", .{});

    // Созyesём withреду
    var env = try gw.GridWorld.init(allocator, .{
        .width = config.grid_size,
        .height = config.grid_size,
        .step_reward = -0.1,
        .goal_reward = 10.0,
        .max_steps = config.grid_size * config.grid_size * 2,
    });
    defer env.deinit();

    print("Среyes: GridWorld {d}x{d}\n", .{ config.grid_size, config.grid_size });
    print("Соwithтоянandй: {d}, Дейwithтinandй: {d}\n", .{ env.numStates(), gw.NUM_ACTIONS });
    print("\n", .{});

    // Созyesём agentа with memoryю
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

    print("Начandonю обученandе ({d} эпandзоbeforein)...\n", .{config.num_episodes});
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

            print("Эпandзод {d:4}: avg={d:6.2}, win={d:5.1}%, ε={d:.3}, mem={d}\n", .{
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
    print("║                    РЕЗУЛЬТАТЫ ОБУЧЕНИЯ                       ║\n", .{});
    print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    print("║ Эпandзоbeforein:           {d:6}                                    ║\n", .{config.num_episodes});
    print("║ Вwithего шагоin:        {d:6}                                    ║\n", .{total_steps});
    print("║ Побед:              {d:6} ({d:.1}%)                           ║\n", .{ wins, final_win_rate });
    print("║ Max consecutive:    {d:6}                                    ║\n", .{max_consecutive_wins});
    print("║ Avg reward (100):   {d:7.2}                                   ║\n", .{metrics.avg_reward_100});
    print("║ Фandonльный ε:        {d:6.4}                                   ║\n", .{agent.getEpsilon()});
    print("║ Experienceоin in памятand:    {d:6}                                    ║\n", .{mem_metrics.total_writes});
    print("║ Время:              {d:6} ms                                 ║\n", .{duration_ms});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Демонwithтрацandя
    if (config.render_final) {
        print("\n", .{});
        print("Демонwithтрацandя обученного agentа (greedy policy):\n", .{});
        print("─────────────────────────────────────────────────────────────\n", .{});

        var demo_state = env.reset();
        env.render();

        for (0..20) |step_num| {
            const demo_action = agent.selectActionGreedy(demo_state);

            print("Шаг {d}: дейwithтinandе = {s}\n", .{ step_num + 1, @as(gw.Action, @enumFromInt(demo_action)).toString() });

            const demo_result = env.step(demo_action);
            env.render();

            if (demo_result.done) {
                if (std.mem.eql(u8, demo_result.info, "goal")) {
                    print("\n✅ ЦЕЛЬ ДОСТИГНУТА за {d} шагоin!\n", .{step_num + 1});
                } else {
                    print("\n⚠️ Эпandзод заinершён: {s}\n", .{demo_result.info});
                }
                break;
            }

            demo_state = demo_result.next_state;
        }
    }

    print("\n", .{});
    if (final_win_rate >= 99.0) {
        print("🏆 МИССИЯ ВЫПОЛНЕНА: {d:.1}% WIN RATE!\n", .{final_win_rate});
    } else if (final_win_rate >= 95.0) {
        print("✅ ОТЛИЧНЫЙ РЕЗУЛЬТАТ: {d:.1}% WIN RATE\n", .{final_win_rate});
    } else {
        print("⚠️ Требуетwithя beforeрабfromtoа: {d:.1}% WIN RATE\n", .{final_win_rate});
    }
    print("\n", .{});
    print("φ² + 1/φ² = 3 | TRINITY HDC RL WITH MEMORY COMPLETE\n", .{});
}

/// Точtoа loginа (тольtoо for andwithbyлняемого fileа)
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

// Отtoлючаем main прand testandроinанandand
comptime {
    if (@import("builtin").is_test) {
        _ = main;
    }
}

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════

test "agent with memory learns" {
    const allocator = std.testing.allocator;

    // Созyesём withреду
    var env = try gw.GridWorld.init(allocator, .{
        .width = 2,
        .height = 2,
    });
    defer env.deinit();

    // Созyesём agentа
    var agent = try rlm.RLAgentWithMemory.init(allocator, .{
        .num_states = 4,
        .num_actions = 4,
        .epsilon_start = 0.5,
        .epsilon_decay = 0.9,
    });
    defer agent.deinit();

    // Обучаем 50 эпandзоbeforein
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

    // Должен inыandграть хfromя бы 30% (2x2 grid проwithтой)
    try std.testing.expect(wins > 15);
}
