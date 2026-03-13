// @origin(generated) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI EXPERIMENT — HSLM Experiment Visualization CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri experiment chart [dir]     ASCII PPL vs Step chart
//   tri experiment list [dir]      List all experiments with metrics
//   tri experiment compare <d1> <d2>  Side-by-side comparison
//   tri experiment export           Generate docs/EXPERIMENTS.md
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("train_types.zig");
const diag = @import("train_diagnostics.zig");
const CheckpointInfo = types.CheckpointInfo;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";
const GOLDEN = "\x1b[38;5;220m";
const MAGENTA = "\x1b[35m";
const BLUE = "\x1b[34m";

const print = std.debug.print;

// Run symbols for multi-run charts
const RUN_SYMBOLS = [_]u8{ '*', 'o', '#', 'x', '+', '@', '~', '^', '=', '.' };
const RUN_COLORS = [_][]const u8{ GREEN, CYAN, YELLOW, MAGENTA, RED, BLUE, GOLDEN, GRAY, GREEN, CYAN };

const CHART_WIDTH: usize = 72;
const CHART_HEIGHT: usize = 20;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runExperimentCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    if (args.len < 1) {
        printHelp();
        return;
    }

    const subcmd = args[0];
    const sub_args = args[1..];

    if (std.mem.eql(u8, subcmd, "chart")) {
        runChart(sub_args);
    } else if (std.mem.eql(u8, subcmd, "list")) {
        runList(sub_args);
    } else if (std.mem.eql(u8, subcmd, "compare")) {
        runCompare(sub_args);
    } else if (std.mem.eql(u8, subcmd, "export")) {
        runExport();
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHART — ASCII PPL vs Step
// ═══════════════════════════════════════════════════════════════════════════════

fn runChart(args: []const []const u8) void {
    const dirs = getCheckpointDirs(args);
    const n_dirs = dirs.len;

    if (n_dirs == 0) {
        print("{s}No checkpoint directories found.{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Scan all directories
    var all_ckpts: [10][64]CheckpointInfo = undefined;
    var counts: [10]usize = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    for (0..n_dirs) |i| {
        counts[i] = diag.scanCheckpoints(dirs.paths[i], &all_ckpts[i]);
    }

    // Find global min/max PPL and step range
    var min_ppl: f32 = 999999.0;
    var max_ppl: f32 = 0.0;
    var max_step: u32 = 0;

    for (0..n_dirs) |i| {
        for (all_ckpts[i][0..counts[i]]) |ck| {
            if (ck.ppl > 0 and ck.ppl < min_ppl) min_ppl = ck.ppl;
            if (ck.ppl > max_ppl) max_ppl = ck.ppl;
            if (ck.step > max_step) max_step = ck.step;
        }
    }

    if (max_step == 0) {
        print("{s}No valid checkpoints found.{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Use log scale for Y axis
    const log_min = @log(min_ppl);
    const log_max = @log(max_ppl);
    const log_range = if (log_max > log_min) log_max - log_min else 1.0;

    // Build ASCII grid
    var grid: [CHART_HEIGHT][CHART_WIDTH]u8 = undefined;
    var color_grid: [CHART_HEIGHT][CHART_WIDTH]u8 = undefined; // run index, 255 = none

    for (0..CHART_HEIGHT) |y| {
        for (0..CHART_WIDTH) |x| {
            grid[y][x] = ' ';
            color_grid[y][x] = 255;
        }
    }

    // Plot each run
    for (0..n_dirs) |run_idx| {
        for (all_ckpts[run_idx][0..counts[run_idx]]) |ck| {
            const x_frac = @as(f32, @floatFromInt(ck.step)) / @as(f32, @floatFromInt(max_step));
            const x: usize = @min(@as(usize, @intFromFloat(x_frac * @as(f32, @floatFromInt(CHART_WIDTH - 1)))), CHART_WIDTH - 1);

            const log_ppl = @log(ck.ppl);
            const y_frac = (log_ppl - log_min) / log_range;
            const y_inv = 1.0 - y_frac; // invert: low PPL at bottom
            const y: usize = @min(@as(usize, @intFromFloat(y_inv * @as(f32, @floatFromInt(CHART_HEIGHT - 1)))), CHART_HEIGHT - 1);

            grid[y][x] = RUN_SYMBOLS[run_idx % RUN_SYMBOLS.len];
            color_grid[y][x] = @intCast(run_idx % RUN_COLORS.len);
        }
    }

    // Print header
    print("\n{s}═══════════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("{s}  HSLM EXPERIMENT CHART — PPL vs Step (log scale){s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Print chart with Y axis labels
    for (0..CHART_HEIGHT) |y| {
        // Y axis label (PPL value)
        if (y == 0 or y == CHART_HEIGHT / 2 or y == CHART_HEIGHT - 1) {
            const y_frac = 1.0 - @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(CHART_HEIGHT - 1));
            const log_val = log_min + y_frac * log_range;
            const ppl_val = @exp(log_val);
            print("  {s}{d:>7.1}{s} |", .{ GRAY, ppl_val, RESET });
        } else {
            print("          |", .{});
        }

        // Print row with colors
        for (0..CHART_WIDTH) |x| {
            if (color_grid[y][x] != 255) {
                const ci = color_grid[y][x];
                print("{s}{c}{s}", .{ RUN_COLORS[ci], grid[y][x], RESET });
            } else {
                print("{c}", .{grid[y][x]});
            }
        }
        print("\n", .{});
    }

    // X axis
    print("          +", .{});
    for (0..CHART_WIDTH) |_| print("-", .{});
    print("\n", .{});

    // X axis labels
    print("          0", .{});
    const mid_step = max_step / 2;
    const pad_mid = CHART_WIDTH / 2 - 1;
    for (0..pad_mid) |_| print(" ", .{});
    print("{d}K", .{mid_step / 1000});
    const pad_end = CHART_WIDTH - pad_mid - 4;
    for (0..pad_end) |_| print(" ", .{});
    print("{d}K\n", .{max_step / 1000});

    // Legend
    print("\n  {s}Legend:{s}\n", .{ BOLD, RESET });
    for (0..n_dirs) |i| {
        if (counts[i] > 0) {
            // Find best PPL for this run
            var best_ppl: f32 = 999999.0;
            var best_step: u32 = 0;
            for (all_ckpts[i][0..counts[i]]) |ck| {
                if (ck.ppl < best_ppl) {
                    best_ppl = ck.ppl;
                    best_step = ck.step;
                }
            }
            print("    {s}{c}{s} = {s} ({d} checkpoints, best PPL={d:.2} @ step {d})\n", .{
                RUN_COLORS[i % RUN_COLORS.len],
                RUN_SYMBOLS[i % RUN_SYMBOLS.len],
                RESET,
                dirs.paths[i],
                counts[i],
                best_ppl,
                best_step,
            });
        }
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIST — All experiments sorted by best PPL
// ═══════════════════════════════════════════════════════════════════════════════

fn runList(args: []const []const u8) void {
    const dirs = getCheckpointDirs(args);
    const n_dirs = dirs.len;

    print("\n{s}═══════════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("{s}  HSLM EXPERIMENTS — Sorted by Best PPL{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Collect summaries
    var summaries: [10]RunSummary = undefined;
    var n_summaries: usize = 0;

    for (0..n_dirs) |i| {
        var ckpts: [64]CheckpointInfo = undefined;
        const count = diag.scanCheckpoints(dirs.paths[i], &ckpts);
        if (count == 0) continue;

        var best_ppl: f32 = 999999.0;
        var best_loss: f32 = 999.0;
        var best_step: u32 = 0;
        var max_step: u32 = 0;
        var latest_loss: f32 = 0;
        var latest_ppl: f32 = 0;

        for (ckpts[0..count]) |ck| {
            if (ck.ppl < best_ppl) {
                best_ppl = ck.ppl;
                best_loss = ck.loss;
                best_step = ck.step;
            }
            if (ck.step > max_step) {
                max_step = ck.step;
                latest_loss = ck.loss;
                latest_ppl = ck.ppl;
            }
        }

        summaries[n_summaries] = .{
            .dir = dirs.paths[i],
            .checkpoints = count,
            .best_ppl = best_ppl,
            .best_loss = best_loss,
            .best_step = best_step,
            .max_step = max_step,
            .latest_loss = latest_loss,
            .latest_ppl = latest_ppl,
        };
        n_summaries += 1;
    }

    // Sort by best PPL (ascending)
    sortSummaries(summaries[0..n_summaries]);

    // Print table
    print("  {s}Rank{s} | {s}Directory{s}                       | {s}Best PPL{s} | {s}Loss{s}  | {s}Step{s}  | {s}Ckpts{s}\n", .{
        BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET, BOLD, RESET,
    });
    print("  -----|-----------------------------------|---------|-------|-------|------\n", .{});

    for (summaries[0..n_summaries], 0..) |s, rank| {
        const crown = if (rank == 0) GOLDEN else if (rank < 3) GREEN else RESET;
        const medal = if (rank == 0) " KING" else "";
        print("  {s}{d:>3}{s}  | {s:<33} | {s}{d:>7.2}{s} | {d:.3} | {d:>5} | {d:>4}{s}\n", .{
            crown,         rank + 1,    RESET,
            s.dir,         crown,       s.best_ppl,
            RESET,         s.best_loss, s.best_step,
            s.checkpoints, medal,
        });
    }

    print("\n  Total: {d} experiments, {d} directories scanned\n\n", .{ n_summaries, n_dirs });
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPARE — Two runs side by side
// ═══════════════════════════════════════════════════════════════════════════════

fn runCompare(args: []const []const u8) void {
    if (args.len < 2) {
        print("{s}Usage: tri experiment compare <dir1> <dir2>{s}\n", .{ YELLOW, RESET });
        return;
    }

    const dir1 = args[0];
    const dir2 = args[1];

    var ckpts1: [64]CheckpointInfo = undefined;
    var ckpts2: [64]CheckpointInfo = undefined;
    const n1 = diag.scanCheckpoints(dir1, &ckpts1);
    const n2 = diag.scanCheckpoints(dir2, &ckpts2);

    print("\n{s}═══════════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("{s}  EXPERIMENT COMPARISON{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    print("  {s}A:{s} {s} ({d} checkpoints)\n", .{ CYAN, RESET, dir1, n1 });
    print("  {s}B:{s} {s} ({d} checkpoints)\n\n", .{ MAGENTA, RESET, dir2, n2 });

    if (n1 == 0 and n2 == 0) {
        print("  {s}No checkpoints in either directory.{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    // Find metrics for each
    const stats1 = computeStats(ckpts1[0..n1]);
    const stats2 = computeStats(ckpts2[0..n2]);

    print("  {s}Metric{s}          | {s}A{s}         | {s}B{s}         | {s}Winner{s}\n", .{
        BOLD, RESET, CYAN, RESET, MAGENTA, RESET, BOLD, RESET,
    });
    print("  ----------------|-----------|-----------|--------\n", .{});

    printCompareRow("Best PPL", stats1.best_ppl, stats2.best_ppl, true);
    printCompareRow("Best Loss", stats1.best_loss, stats2.best_loss, true);
    printCompareRow("Latest PPL", stats1.latest_ppl, stats2.latest_ppl, true);
    printCompareRow("Latest Loss", stats1.latest_loss, stats2.latest_loss, true);

    print("  Best Step       | {d:>9} | {d:>9} |\n", .{ stats1.best_step, stats2.best_step });
    print("  Max Step        | {d:>9} | {d:>9} |\n", .{ stats1.max_step, stats2.max_step });
    print("  Checkpoints     | {d:>9} | {d:>9} |\n", .{ stats1.count, stats2.count });

    print("\n", .{});
}

fn printCompareRow(label: []const u8, a: f32, b: f32, lower_is_better: bool) void {
    const a_wins = if (lower_is_better) a < b else a > b;
    const winner = if (a == 0 and b == 0) "  --" else if (a_wins) "  A" else "  B";
    print("  {s:<16} | {d:>9.3} | {d:>9.3} | {s}\n", .{ label, a, b, winner });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPORT — Generate docs/EXPERIMENTS.md
// ═══════════════════════════════════════════════════════════════════════════════

fn runExport() void {
    const dirs = getCheckpointDirs(&.{});
    const n_dirs = dirs.len;

    // Collect summaries
    var summaries: [10]RunSummary = undefined;
    var n_summaries: usize = 0;

    for (0..n_dirs) |i| {
        var ckpts: [64]CheckpointInfo = undefined;
        const count = diag.scanCheckpoints(dirs.paths[i], &ckpts);
        if (count == 0) continue;

        var best_ppl: f32 = 999999.0;
        var best_loss: f32 = 999.0;
        var best_step: u32 = 0;
        var max_step: u32 = 0;
        var latest_loss: f32 = 0;
        var latest_ppl: f32 = 0;

        for (ckpts[0..count]) |ck| {
            if (ck.ppl < best_ppl) {
                best_ppl = ck.ppl;
                best_loss = ck.loss;
                best_step = ck.step;
            }
            if (ck.step > max_step) {
                max_step = ck.step;
                latest_loss = ck.loss;
                latest_ppl = ck.ppl;
            }
        }

        summaries[n_summaries] = .{
            .dir = dirs.paths[i],
            .checkpoints = count,
            .best_ppl = best_ppl,
            .best_loss = best_loss,
            .best_step = best_step,
            .max_step = max_step,
            .latest_loss = latest_loss,
            .latest_ppl = latest_ppl,
        };
        n_summaries += 1;
    }

    sortSummaries(summaries[0..n_summaries]);

    // Write markdown to docs/EXPERIMENTS.md
    const cwd = std.fs.cwd();
    const file = cwd.createFile("docs/EXPERIMENTS.md", .{}) catch {
        print("{s}Error: cannot write docs/EXPERIMENTS.md{s}\n", .{ RED, RESET });
        return;
    };
    defer file.close();

    const header =
        \\# HSLM Experiment Results
        \\
        \\Auto-generated by `tri experiment export`. Do not edit manually.
        \\
        \\## Leaderboard (sorted by best PPL)
        \\
        \\| Rank | Directory | Best PPL | Best Loss | Best Step | Max Step | Checkpoints |
        \\|------|-----------|----------|-----------|-----------|----------|-------------|
        \\
    ;
    file.writeAll(header) catch return;

    var line_buf: [256]u8 = undefined;
    for (summaries[0..n_summaries], 0..) |s, rank| {
        const line = std.fmt.bufPrint(&line_buf, "| {d} | `{s}` | {d:.2} | {d:.3} | {d} | {d} | {d} |\n", .{
            rank + 1, s.dir, s.best_ppl, s.best_loss, s.best_step, s.max_step, s.checkpoints,
        }) catch continue;
        file.writeAll(line) catch return;
    }

    const wave6 =
        \\
        \\## Wave 6 Configurations
        \\
        \\All share: `HSLM_OPTIMIZER=lamb`, `HSLM_LR_SCHEDULE=cosine`, `HSLM_BATCH=66`, `HSLM_WARMUP=2000`
        \\
        \\| ID | LR | Context | Steps | Seed | Special |
        \\|----|------|---------|-------|------|---------|
        \\| W6-1 | 5e-4 | 27 | 100K | 61 | LR sweep |
        \\| W6-2 | 7e-4 | 27 | 100K | 62 | LR sweep |
        \\| W6-3 | 1.5e-3 | 27 | 100K | 63 | LR sweep |
        \\| W6-4 | 2e-3 | 27 | 100K | 64 | LR sweep |
        \\| W6-5 | 1e-3 | 9 | 100K | 65 | Short context |
        \\| W6-6 | 1e-3 | 18 | 100K | 66 | Medium context |
        \\| W6-7 | 1e-3 | 54 | 100K | 67 | Long context |
        \\| W6-8 | 1e-3 | 81 | 100K | 68 | Overfitting test |
        \\| W6-9 | 1e-3 | 27 | 100K | 69 | GRAD_ACCUM=1 |
        \\| W6-10 | 1e-3 | 27 | 100K | 70 | GRAD_ACCUM=4 |
        \\| W6-11 | 1e-3 | 27 | 100K | 71 | GRAD_ACCUM=8 |
        \\| W6-12 | 1e-3 | 27 | 100K | 72 | PHI schedule |
        \\| W6-13 | 1e-3 | 27 | 100K | 73 | Restart period=33K |
        \\| W6-14 | 1e-3 | 27 | 100K | 74 | Warmup=5000 |
        \\| W6-15 | 1e-3 | 27 | 100K | 75 | PHI_SCALE=1 |
        \\| W6-16 | 1e-3 | 27 | 100K | 76 | Adaptive sparsity |
        \\| W6-17 | 1e-3 | 27 | 100K | 77 | PHI+PHI_SCALE |
        \\| W6-18 | 1e-3 | 27 | 100K | 78 | Dropout=0.15 |
        \\| W6-19 | 1e-3 | 27 | 200K | 79 | Extended run |
        \\| W6-20 | 1e-3 | 27 | 200K | 80 | PHI extended |
        \\
        \\## Key Findings
        \\
        \\- **R5 KING**: PPL=2.96 (LAMB 1e-3, cosine, ctx=27) — best result to date
        \\- Cosine LR schedule essential — flat schedule dies by step 20K
        \\- LAMB optimizer outperforms AdamW for ternary weights
        \\- Context length 27 appears optimal for current architecture
        \\- Batch size 66 with gradient accumulation 2 is default baseline
        \\
    ;
    file.writeAll(wave6) catch return;

    print("{s}Exported to docs/EXPERIMENTS.md{s}\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

const RunSummary = struct {
    dir: []const u8,
    checkpoints: usize,
    best_ppl: f32,
    best_loss: f32,
    best_step: u32,
    max_step: u32,
    latest_loss: f32,
    latest_ppl: f32,
};

const RunStats = struct {
    best_ppl: f32,
    best_loss: f32,
    best_step: u32,
    max_step: u32,
    latest_ppl: f32,
    latest_loss: f32,
    count: usize,
};

fn computeStats(ckpts: []const CheckpointInfo) RunStats {
    var stats = RunStats{
        .best_ppl = 999999.0,
        .best_loss = 999.0,
        .best_step = 0,
        .max_step = 0,
        .latest_ppl = 0,
        .latest_loss = 0,
        .count = ckpts.len,
    };

    for (ckpts) |ck| {
        if (ck.ppl < stats.best_ppl) {
            stats.best_ppl = ck.ppl;
            stats.best_loss = ck.loss;
            stats.best_step = ck.step;
        }
        if (ck.step > stats.max_step) {
            stats.max_step = ck.step;
            stats.latest_ppl = ck.ppl;
            stats.latest_loss = ck.loss;
        }
    }

    if (ckpts.len == 0) {
        stats.best_ppl = 0;
        stats.best_loss = 0;
    }

    return stats;
}

fn sortSummaries(items: []RunSummary) void {
    // Simple insertion sort (max 10 items)
    for (1..items.len) |i| {
        const key = items[i];
        var j: usize = i;
        while (j > 0 and items[j - 1].best_ppl > key.best_ppl) {
            items[j] = items[j - 1];
            j -= 1;
        }
        items[j] = key;
    }
}

const DirList = struct {
    paths: [10][]const u8,
    len: usize,
};

fn getCheckpointDirs(args: []const []const u8) DirList {
    var result = DirList{ .paths = undefined, .len = 0 };

    // If explicit dirs given, use those
    if (args.len > 0) {
        for (args) |arg| {
            if (result.len >= 10) break;
            if (arg[0] == '-') continue; // skip flags
            result.paths[result.len] = arg;
            result.len += 1;
        }
        if (result.len > 0) return result;
    }

    // Auto-detect checkpoint directories
    const known_dirs = [_][]const u8{
        "data/checkpoints",
        "data/checkpoints/real",
        "data/checkpoints_v3",
        "data/checkpoints_v13_lamb128",
    };

    for (known_dirs) |dir| {
        if (result.len >= 10) break;
        // Check if directory exists
        var d = std.fs.cwd().openDir(dir, .{}) catch continue;
        d.close();
        result.paths[result.len] = dir;
        result.len += 1;
    }

    return result;
}

fn printHelp() void {
    print("\n{s}TRI EXPERIMENT — HSLM Experiment Visualization{s}\n\n", .{ BOLD, RESET });
    print("  {s}Usage:{s}\n", .{ GOLDEN, RESET });
    print("    tri experiment chart [dir...]     ASCII PPL vs Step chart\n", .{});
    print("    tri experiment list  [dir...]     List experiments sorted by PPL\n", .{});
    print("    tri experiment compare <d1> <d2>  Side-by-side comparison\n", .{});
    print("    tri experiment export             Generate docs/EXPERIMENTS.md\n", .{});
    print("\n  {s}Examples:{s}\n", .{ GOLDEN, RESET });
    print("    tri experiment chart                              # All known dirs\n", .{});
    print("    tri experiment chart data/checkpoints              # Single dir\n", .{});
    print("    tri experiment chart data/checkpoints data/checkpoints_v3  # Compare\n", .{});
    print("    tri experiment list                               # Leaderboard\n", .{});
    print("    tri experiment compare data/checkpoints data/checkpoints_v3\n", .{});
    print("\n", .{});
}

test "sort summaries" {
    var items = [_]RunSummary{
        .{ .dir = "b", .checkpoints = 1, .best_ppl = 10.0, .best_loss = 2.3, .best_step = 100, .max_step = 100, .latest_loss = 2.3, .latest_ppl = 10.0 },
        .{ .dir = "a", .checkpoints = 1, .best_ppl = 2.96, .best_loss = 1.08, .best_step = 50, .max_step = 50, .latest_loss = 1.08, .latest_ppl = 2.96 },
        .{ .dir = "c", .checkpoints = 1, .best_ppl = 5.0, .best_loss = 1.6, .best_step = 75, .max_step = 75, .latest_loss = 1.6, .latest_ppl = 5.0 },
    };
    sortSummaries(&items);
    try std.testing.expectEqualStrings("a", items[0].dir);
    try std.testing.expectEqualStrings("c", items[1].dir);
    try std.testing.expectEqualStrings("b", items[2].dir);
}
