//! Hyperparameter Tuning - Поиск оптимальных параметров для 100% win rate
//!
//! Перебор:
//! - learning_rate: [0.05, 0.1, 0.2, 0.3, 0.5]
//! - gamma: [0.9, 0.95, 0.99]
//! - epsilon_decay: [0.99, 0.995, 0.999]
//!
//! φ² + 1/φ² = 3 | TRINITY | ОПЕРАЦИЯ "PERFECT AGENT"

const std = @import("std");
const gw = @import("gridworld.zig");
const rl = @import("rl_agent.zig");

const print = std.debug.print;

/// Результат эксперимента
const ExperimentResult = struct {
    lr: f64,
    gamma: f64,
    epsilon_decay: f64,
    win_rate: f64,
    avg_reward: f64,
    max_consecutive: u64,
    total_wins: u64,
    episodes: usize,
};

/// Запустить один эксперимент
fn runExperiment(
    allocator: std.mem.Allocator,
    lr: f64,
    gamma: f64,
    epsilon_decay: f64,
    num_episodes: usize,
    seed: u64,
) !ExperimentResult {
    // Создаём среду
    var env = try gw.GridWorld.init(allocator, .{
        .width = 4,
        .height = 4,
        .step_reward = -0.1,
        .goal_reward = 10.0,
        .max_steps = 32,
    });
    defer env.deinit();

    // Создаём агента
    var agent = try rl.RLAgent.init(allocator, .{
        .state_dim = 256,
        .num_actions = 4,
        .gamma = gamma,
        .learning_rate = lr,
        .epsilon_start = 1.0,
        .epsilon_end = 0.01,
        .epsilon_decay = epsilon_decay,
    });
    defer agent.deinit();

    // Фиксируем seed
    agent.rng = std.Random.DefaultPrng.init(seed);

    try agent.initQTable(env.numStates());

    var wins: u64 = 0;
    var consecutive: u64 = 0;
    var max_consecutive: u64 = 0;
    var total_reward: f64 = 0;

    for (0..num_episodes) |_| {
        var state = env.reset();
        var episode_reward: f64 = 0;

        while (true) {
            const action = agent.selectAction(state);
            const result = env.step(action);

            _ = agent.tdUpdate(state, action, result.reward, result.next_state, result.done);

            episode_reward += result.reward;
            state = result.next_state;

            if (result.done) {
                if (std.mem.eql(u8, result.info, "goal")) {
                    wins += 1;
                    consecutive += 1;
                    if (consecutive > max_consecutive) {
                        max_consecutive = consecutive;
                    }
                } else {
                    consecutive = 0;
                }
                break;
            }
        }

        agent.decayEpsilon();
        total_reward += episode_reward;
    }

    return .{
        .lr = lr,
        .gamma = gamma,
        .epsilon_decay = epsilon_decay,
        .win_rate = @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(num_episodes)) * 100.0,
        .avg_reward = total_reward / @as(f64, @floatFromInt(num_episodes)),
        .max_consecutive = max_consecutive,
        .total_wins = wins,
        .episodes = num_episodes,
    };
}

/// Запустить grid search
pub fn runGridSearch(allocator: std.mem.Allocator) !void {
    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║     HYPERPARAMETER TUNING - ОПЕРАЦИЯ PERFECT AGENT          ║\n", .{});
    print("║     φ² + 1/φ² = 3 | TRINITY                                  ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    print("\n", .{});

    const learning_rates = [_]f64{ 0.05, 0.1, 0.2, 0.3, 0.5 };
    const gammas = [_]f64{ 0.9, 0.95, 0.99 };
    const epsilon_decays = [_]f64{ 0.99, 0.995, 0.999 };

    const num_episodes: usize = 2000;
    const num_runs: usize = 3; // Среднее по 3 запускам

    print("Параметры поиска:\n", .{});
    print("  learning_rate: {any}\n", .{learning_rates});
    print("  gamma: {any}\n", .{gammas});
    print("  epsilon_decay: {any}\n", .{epsilon_decays});
    print("  episodes: {d}, runs: {d}\n", .{ num_episodes, num_runs });
    print("\n", .{});

    var best_result: ExperimentResult = .{
        .lr = 0,
        .gamma = 0,
        .epsilon_decay = 0,
        .win_rate = 0,
        .avg_reward = -1000,
        .max_consecutive = 0,
        .total_wins = 0,
        .episodes = 0,
    };

    var results = std.ArrayList(ExperimentResult).init(allocator);
    defer results.deinit();

    print("─────────────────────────────────────────────────────────────\n", .{});
    print("  LR    | Gamma | Eps_dec | Win%   | Avg Rew | Max Cons\n", .{});
    print("─────────────────────────────────────────────────────────────\n", .{});

    var exp_count: usize = 0;
    const total_experiments = learning_rates.len * gammas.len * epsilon_decays.len;

    for (learning_rates) |lr| {
        for (gammas) |gamma| {
            for (epsilon_decays) |eps_decay| {
                var total_win_rate: f64 = 0;
                var total_avg_reward: f64 = 0;
                var total_max_cons: u64 = 0;

                for (0..num_runs) |run| {
                    const seed = @as(u64, exp_count) * 1000 + @as(u64, run) * 100 + 42;
                    const result = try runExperiment(allocator, lr, gamma, eps_decay, num_episodes, seed);
                    total_win_rate += result.win_rate;
                    total_avg_reward += result.avg_reward;
                    if (result.max_consecutive > total_max_cons) {
                        total_max_cons = result.max_consecutive;
                    }
                }

                const avg_win_rate = total_win_rate / @as(f64, num_runs);
                const avg_reward = total_avg_reward / @as(f64, num_runs);

                const result = ExperimentResult{
                    .lr = lr,
                    .gamma = gamma,
                    .epsilon_decay = eps_decay,
                    .win_rate = avg_win_rate,
                    .avg_reward = avg_reward,
                    .max_consecutive = total_max_cons,
                    .total_wins = @intFromFloat(avg_win_rate * @as(f64, num_episodes) / 100.0),
                    .episodes = num_episodes,
                };

                try results.append(result);

                print(" {d:.2} | {d:.2} | {d:.3}  | {d:5.1}% | {d:7.2} | {d:4}\n", .{
                    lr,
                    gamma,
                    eps_decay,
                    avg_win_rate,
                    avg_reward,
                    total_max_cons,
                });

                if (avg_win_rate > best_result.win_rate or
                    (avg_win_rate == best_result.win_rate and total_max_cons > best_result.max_consecutive))
                {
                    best_result = result;
                }

                exp_count += 1;
            }
        }
    }

    print("─────────────────────────────────────────────────────────────\n", .{});
    print("\n", .{});

    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║                    ЛУЧШИЕ ПАРАМЕТРЫ                          ║\n", .{});
    print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    print("║ learning_rate:  {d:.3}                                        ║\n", .{best_result.lr});
    print("║ gamma:          {d:.3}                                        ║\n", .{best_result.gamma});
    print("║ epsilon_decay:  {d:.4}                                       ║\n", .{best_result.epsilon_decay});
    print("║ Win Rate:       {d:.1}%                                       ║\n", .{best_result.win_rate});
    print("║ Avg Reward:     {d:.2}                                        ║\n", .{best_result.avg_reward});
    print("║ Max Consecutive:{d:4}                                         ║\n", .{best_result.max_consecutive});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Топ-5 результатов
    print("\n", .{});
    print("ТОП-5 КОНФИГУРАЦИЙ:\n", .{});
    print("─────────────────────────────────────────────────────────────\n", .{});

    // Сортируем по win_rate
    std.mem.sort(ExperimentResult, results.items, {}, struct {
        fn lessThan(_: void, a: ExperimentResult, b: ExperimentResult) bool {
            if (a.win_rate != b.win_rate) return a.win_rate > b.win_rate;
            return a.max_consecutive > b.max_consecutive;
        }
    }.lessThan);

    for (0..@min(5, results.items.len)) |i| {
        const r = results.items[i];
        print("{d}. lr={d:.2}, γ={d:.2}, ε_dec={d:.3} → {d:.1}% (cons={d})\n", .{
            i + 1,
            r.lr,
            r.gamma,
            r.epsilon_decay,
            r.win_rate,
            r.max_consecutive,
        });
    }

    print("\n", .{});
    print("Всего экспериментов: {d}\n", .{total_experiments});
    print("\n", .{});
    print("φ² + 1/φ² = 3 | TRINITY | TUNING COMPLETE\n", .{});
}

/// Точка входа
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runGridSearch(allocator);
}

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════

test "single experiment" {
    const allocator = std.testing.allocator;
    const result = try runExperiment(allocator, 0.1, 0.95, 0.99, 100, 42);
    try std.testing.expect(result.win_rate >= 0);
}
