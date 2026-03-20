//! SIMULATION PLOTTER — ASCII Visualization
//!
//! Reads simulation_results.csv and displays:
//!   --view summary   Final metrics ranking table
//!   --view ppl       PPL evolution curves
//!   --view diversity Diversity index trends
//!   --view alive     Worker survival curves
//! Usage: tri-sim-plot --view MODE --input PATH
//!
//! φ² + 1/phi² = 3 = TRINITY

const std = @import("std");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const WHITE = "\x1b[37m";

const DataPoint = struct {
    step: usize,
    scenario_id: []const u8,
    ppl: f32,
    diversity: f32,
    alive: usize,
    energy: f32,
};

const ScenarioStats = struct {
    id: []const u8,
    name: []const u8,
    final_ppl: f32,
    final_diversity: f32,
    final_alive: usize,
    total_energy: f32,
    converged: bool,
    category: []const u8,
    points: []const DataPoint,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len > 1 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        printHelp();
        return;
    }

    var view_mode: ?enum { ppl, diversity, alive, summary } = null;
    var input_path: []const u8 = "output/simulation_results.csv";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.startsWith(u8, args[i], "--view=")) {
            const mode_str = args[i]["--view=".len..];
            if (std.mem.eql(u8, mode_str, "ppl")) {
                view_mode = .ppl;
            } else if (std.mem.eql(u8, mode_str, "diversity")) {
                view_mode = .diversity;
            } else if (std.mem.eql(u8, mode_str, "alive")) {
                view_mode = .alive;
            } else if (std.mem.eql(u8, mode_str, "summary")) {
                view_mode = .summary;
            } else {
                print("{s}Error: unknown view mode '{s}'{s}\n", .{ RED, mode_str, RESET });
                return error.InvalidViewMode;
            }
        } else if (std.mem.startsWith(u8, args[i], "--input=")) {
            input_path = args[i]["--input=".len..];
        }
    }

    if (view_mode == null) {
        print("{s}Error: --view mode required (summary|ppl|diversity|alive){s}\n", .{ RED, RESET });
        printHelp();
        return error.ViewModeRequired;
    }

    const scenarios = try loadCSV(allocator, input_path);
    defer {
        for (scenarios) |s| {
            allocator.free(s.id);
            allocator.free(s.points);
        }
        allocator.free(scenarios);
    }

    switch (view_mode.?) {
        .ppl => try plotPPL(allocator, scenarios),
        .diversity => try plotDiversity(allocator, scenarios),
        .alive => try plotAlive(allocator, scenarios),
        .summary => try printSummary(allocator, scenarios),
    }
}

fn loadCSV(allocator: Allocator, csv_path: []const u8) ![]ScenarioStats {
    const file = std.fs.cwd().openFile(csv_path, .{}) catch |err| {
        print("{s}Error: cannot open '{s}': {}{s}\n", .{ RED, csv_path, err, RESET });
        return err;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(contents);

    const ScenarioData = struct {
        points: std.ArrayList(DataPoint),
        final_ppl: f32,
        final_diversity: f32,
        final_alive: usize,
        total_energy: f32,
    };

    var scenario_map = std.StringHashMap(ScenarioData).init(allocator);
    defer {
        var iter = scenario_map.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.points.deinit(allocator);
        }
        scenario_map.deinit();
    }

    var lines = std.mem.tokenizeScalar(u8, contents, '\n');

    // Skip header
    _ = lines.next();

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var fields = std.mem.tokenizeScalar(u8, line, ',');
        var step_idx: usize = 0;
        var step: usize = 0;
        var scenario_id: []const u8 = "";
        var ppl: f32 = 0.0;
        var diversity: f32 = 0.0;
        var alive: usize = 0;
        var energy: f32 = 0.0;

        while (fields.next()) |field| {
            const field_str = std.mem.trim(u8, field, " \r\n");
            switch (step_idx) {
                0 => step = std.fmt.parseInt(usize, field_str, 10) catch 0,
                1 => scenario_id = field_str,
                2 => ppl = std.fmt.parseFloat(f32, field_str) catch 0.0,
                3 => diversity = std.fmt.parseFloat(f32, field_str) catch 0.0,
                4 => alive = std.fmt.parseInt(usize, field_str, 10) catch 0,
                8 => energy = std.fmt.parseFloat(f32, field_str) catch 0.0,
                else => {},
            }
            step_idx += 1;
        }

        const entry = try scenario_map.getOrPut(scenario_id);
        if (!entry.found_existing) {
            entry.key_ptr.* = try allocator.dupe(u8, scenario_id);
            entry.value_ptr.* = ScenarioData{
                .points = std.ArrayList(DataPoint).initCapacity(allocator, 32) catch |err| return err,
                .final_ppl = ppl,
                .final_diversity = diversity,
                .final_alive = alive,
                .total_energy = energy,
            };
        }

        try entry.value_ptr.points.append(allocator, DataPoint{
            .step = step,
            .scenario_id = entry.key_ptr.*,
            .ppl = ppl,
            .diversity = diversity,
            .alive = alive,
            .energy = energy,
        });

        entry.value_ptr.final_ppl = ppl;
        entry.value_ptr.final_diversity = diversity;
        entry.value_ptr.final_alive = alive;
        entry.value_ptr.total_energy = energy;
    }

    var result = std.ArrayList(ScenarioStats).initCapacity(allocator, 16) catch |err| return err;
    var iter = scenario_map.iterator();
    while (iter.next()) |entry| {
        const points_slice = try entry.value_ptr.points.toOwnedSlice(allocator);
        const stats = ScenarioStats{
            .id = try allocator.dupe(u8, entry.key_ptr.*),
            .name = getScenarioName(entry.key_ptr.*),
            .final_ppl = entry.value_ptr.final_ppl,
            .final_diversity = entry.value_ptr.final_diversity,
            .final_alive = entry.value_ptr.final_alive,
            .total_energy = entry.value_ptr.total_energy,
            .converged = entry.value_ptr.final_alive > 0,
            .category = getScenarioCategory(entry.key_ptr.*),
            .points = points_slice,
        };
        try result.append(allocator, stats);
    }

    return result.toOwnedSlice(allocator);
}

fn getScenarioName(id: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "S1")) return "Baseline-1";
    if (std.mem.eql(u8, id, "S2")) return "Baseline-2";
    if (std.mem.eql(u8, id, "S3")) return "S3-Mixed";
    if (std.mem.eql(u8, id, "S4")) return "S4-Mixed";
    if (std.mem.eql(u8, id, "S5")) return "S5-Mixed";
    if (std.mem.eql(u8, id, "S6")) return "JEPA-Heavy";
    if (std.mem.eql(u8, id, "S7")) return "High-Div";
    if (std.mem.eql(u8, id, "S8")) return "Low-Crash";
    if (std.mem.eql(u8, id, "S9")) return "Byzantine";
    if (std.mem.eql(u8, id, "S10")) return "Energy-Opt";
    if (std.mem.eql(u8, id, "S11")) return "Sacred-A";
    if (std.mem.eql(u8, id, "S12")) return "Sacred-B";
    if (std.mem.eql(u8, id, "S13")) return "Wide";
    if (std.mem.eql(u8, id, "S14")) return "Base-Ext";
    if (std.mem.eql(u8, id, "S15")) return "Base-Ext2";
    return id;
}

fn getScenarioCategory(id: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "S1") or std.mem.eql(u8, id, "S2") or
        std.mem.eql(u8, id, "S14") or std.mem.eql(u8, id, "S15")) {
        return "Baseline";
    }
    if (std.mem.eql(u8, id, "S11") or std.mem.eql(u8, id, "S12")) {
        return "Sacred";
    }
    if (std.mem.eql(u8, id, "S7")) {
        return "dePIN";
    }
    if (std.mem.eql(u8, id, "S13")) {
        return "Wide";
    }
    return "Mixed";
}

fn getScenarioColor(category: []const u8) []const u8 {
    if (std.mem.eql(u8, category, "Baseline")) return GREEN;
    if (std.mem.eql(u8, category, "Sacred")) return MAGENTA;
    if (std.mem.eql(u8, category, "dePIN")) return YELLOW;
    if (std.mem.eql(u8, category, "Wide")) return CYAN;
    return BLUE;
}

fn printSummary(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    _ = allocator;
    print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  SIMULATION SUMMARY                                     ║{s}\n", .{ BOLD, RESET });
    print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    print("{s}┌──────┬──────────────────┬───────┬───────────┬────────┬────────┐{s}\n", .{ BOLD, RESET });
    print("{s}│ Rank │ Scenario         │  PPL  │ Diversity │ Alive  │ Energy │{s}\n", .{ BOLD, RESET });
    print("{s}├──────┼──────────────────┼───────┼───────────┼────────┼────────┤{s}\n", .{ BOLD, RESET });

    for (scenarios, 0..) |s, i| {
        const color = getScenarioColor(s.category);
        print("{s}│ {d:>4} │ {s:<16} │ {} │    {} │ {d:>6} │ {}K │{s}\n", .{
            color, i + 1, s.name, s.final_ppl, s.final_diversity, s.final_alive, s.total_energy / 1000.0, RESET,
        });
    }

    print("{s}└──────┴──────────────────┴───────┴───────────┴────────┴────────┘{s}\n\n", .{ BOLD, RESET });

    print("{s}Legend:{s} {s}●{s}Baseline  {s}●{s}Sacred  {s}●{s}dePIN  {s}●{s}Wide  {s}●{s}Mixed\n\n",
        .{ BOLD, RESET, GREEN, RESET, MAGENTA, RESET, YELLOW, RESET, CYAN, RESET, BLUE, RESET });
}

fn plotPPL(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    const graph_width = 60;
    const graph_height = 20;

    // Find min/max PPL values
    var min_ppl: f32 = std.math.floatMax(f32);
    var max_ppl: f32 = 0.0;
    var max_step: usize = 0;

    for (scenarios) |s| {
        for (s.points) |pt| {
            if (pt.ppl < min_ppl) min_ppl = pt.ppl;
            if (pt.ppl > max_ppl) max_ppl = pt.ppl;
            if (pt.step > max_step) max_step = pt.step;
        }
    }

    if (max_ppl == 0.0) {
        print("{s}No data to plot{s}\n", .{ RED, RESET });
        return;
    }

    const ppl_range = max_ppl - min_ppl;
    const step_scale = @as(f32, @floatFromInt(graph_width)) / @as(f32, @floatFromInt(max_step));

    print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  PPL EVOLUTION ({d:0>2} steps)                           ║{s}\n", .{ BOLD, max_step, RESET });
    print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    // Plot from top to bottom
    var y_idx: usize = 0;
    while (y_idx < graph_height) : (y_idx += 1) {
        const y_val = max_ppl - (@as(f32, @floatFromInt(y_idx)) * ppl_range / @as(f32, @floatFromInt(graph_height - 1)));

        // Y-axis label
        if (y_idx % 5 == 0) {
            const y_str = try std.fmt.allocPrint(allocator, "{d:>5.1}", .{y_val});
            defer allocator.free(y_str);
            print("{s} │", .{y_str});
        } else {
            print("      │", .{});
        }

        // Plot each column
        var x_idx: usize = 0;
        while (x_idx < graph_width) : (x_idx += 1) {
            const step_val = @as(usize, @intFromFloat(@as(f32, @floatFromInt(x_idx)) / step_scale));
            var plotted = false;

            for (scenarios) |s| {
                for (s.points) |pt| {
                    if (pt.step == step_val and @abs(pt.ppl - y_val) < ppl_range / @as(f32, @floatFromInt(graph_height))) {
                        const color = getScenarioColor(s.category);
                        print("{s}●{s}", .{ color, RESET });
                        plotted = true;
                        break;
                    }
                }
                if (plotted) break;
            }

            if (!plotted) {
                print(" ", .{});
            }
        }
        print("\n", .{});
    }

    // X-axis
    print("      └", .{});
    var i: usize = 0;
    while (i < graph_width) : (i += 1) {
        print("─", .{});
    }
    print("\n      ", .{});

    // X-axis labels
    i = 0;
    while (i <= 10) : (i += 1) {
        const label_pos = @as(usize, @intFromFloat(@as(f32, @floatFromInt(i)) * @as(f32, @floatFromInt(graph_width)) / 10.0));
        var j: usize = 0;
        while (j < label_pos) : (j += 1) {
            print(" ", .{});
        }
        print("{d}", .{ i * @as(usize, @intFromFloat(@as(f32, @floatFromInt(max_step)) / 10.0)) / 10 });
    }
    print("\n\n", .{});

    print("{s}Legend:{s} {s}●{s}Baseline  {s}●{s}Sacred  {s}●{s}dePIN  {s}●{s}Wide  {s}●{s}Mixed\n\n",
        .{ BOLD, RESET, GREEN, RESET, MAGENTA, RESET, YELLOW, RESET, CYAN, RESET, BLUE, RESET });
}

fn plotDiversity(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    const graph_width = 60;
    const graph_height = 15;

    var min_div: f32 = std.math.floatMax(f32);
    var max_div: f32 = 0.0;
    var max_step: usize = 0;

    for (scenarios) |s| {
        for (s.points) |pt| {
            if (pt.diversity < min_div) min_div = pt.diversity;
            if (pt.diversity > max_div) max_div = pt.diversity;
            if (pt.step > max_step) max_step = pt.step;
        }
    }

    if (max_div == 0.0) {
        print("{s}No data to plot{s}\n", .{ RED, RESET });
        return;
    }

    const div_range = max_div - min_div;
    const step_scale = @as(f32, @floatFromInt(graph_width)) / @as(f32, @floatFromInt(max_step));

    print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  DIVERSITY INDEX TRENDS ({d:0>2} steps)                  ║{s}\n", .{ BOLD, max_step, RESET });
    print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    var y_idx: usize = 0;
    while (y_idx < graph_height) : (y_idx += 1) {
        const y_val = max_div - (@as(f32, @floatFromInt(y_idx)) * div_range / @as(f32, @floatFromInt(graph_height - 1)));

        if (y_idx % 3 == 0) {
            const y_str = try std.fmt.allocPrint(allocator, "{d:>6.2}", .{y_val});
            defer allocator.free(y_str);
            print("{s} │", .{y_str});
        } else {
            print("      │", .{});
        }

        var x_idx: usize = 0;
        while (x_idx < graph_width) : (x_idx += 1) {
            const step_val = @as(usize, @intFromFloat(@as(f32, @floatFromInt(x_idx)) / step_scale));
            var plotted = false;

            for (scenarios) |s| {
                for (s.points) |pt| {
                    if (pt.step == step_val and @abs(pt.diversity - y_val) < div_range / @as(f32, @floatFromInt(graph_height))) {
                        const color = getScenarioColor(s.category);
                        print("{s}●{s}", .{ color, RESET });
                        plotted = true;
                        break;
                    }
                }
                if (plotted) break;
            }

            if (!plotted) print(" ", .{});
        }
        print("\n", .{});
    }

    print("      └", .{});
    var i: usize = 0;
    while (i < graph_width) : (i += 1) {
        print("─", .{});
    }
    print("\n\n", .{});

    print("{s}Legend:{s} {s}●{s}Baseline  {s}●{s}Sacred  {s}●{s}dePIN  {s}●{s}Wide  {s}●{s}Mixed\n\n",
        .{ BOLD, RESET, GREEN, RESET, MAGENTA, RESET, YELLOW, RESET, CYAN, RESET, BLUE, RESET });
}

fn plotAlive(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    _ = allocator;
    const graph_width = 60;
    _ = 12;

    var max_alive: usize = 0;
    var max_step: usize = 0;

    for (scenarios) |s| {
        for (s.points) |pt| {
            if (pt.alive > max_alive) max_alive = pt.alive;
            if (pt.step > max_step) max_step = pt.step;
        }
    }

    if (max_alive == 0) {
        print("{s}No data to plot{s}\n", .{ RED, RESET });
        return;
    }

    const step_scale = @as(f32, @floatFromInt(graph_width)) / @as(f32, @floatFromInt(max_step));

    print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  WORKER SURVIVAL CURVES ({d:0>2} steps)                    ║{s}\n", .{ BOLD, max_step, RESET });
    print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    var y_idx: isize = @intCast(max_alive);
    while (y_idx >= 0) : (y_idx -= 1) {
        const y_val: usize = @intCast(y_idx);
        const alive_f: f32 = @floatFromInt(y_val);

        if (@as(usize, @intCast(y_idx)) % 20 == 0) {
            print("{d:>4} │", .{y_val});
        } else {
            print("      │", .{});
        }

        var x_idx: usize = 0;
        while (x_idx < graph_width) : (x_idx += 1) {
            const step_val = @as(usize, @intFromFloat(@as(f32, @floatFromInt(x_idx)) / step_scale));
            var plotted = false;

            for (scenarios) |s| {
                for (s.points) |pt| {
                    const pt_alive_f: f32 = @floatFromInt(pt.alive);
                    if (pt.step == step_val and @abs(pt_alive_f - alive_f) < 1.0) {
                        const color = getScenarioColor(s.category);
                        print("{s}●{s}", .{ color, RESET });
                        plotted = true;
                        break;
                    }
                }
                if (plotted) break;
            }

            if (!plotted) print(" ", .{});
        }
        print("\n", .{});
    }

    print("      └", .{});
    var i: usize = 0;
    while (i < graph_width) : (i += 1) {
        print("─", .{});
    }
    print("\n\n", .{});

    print("{s}Legend:{s} {s}●{s}Baseline  {s}●{s}Sacred  {s}●{s}dePIN  {s}●{s}Wide  {s}●{s}Mixed\n\n",
        .{ BOLD, RESET, GREEN, RESET, MAGENTA, RESET, YELLOW, RESET, CYAN, RESET, BLUE, RESET });
}

fn printHelp() void {
    print("\n{s}SIMULATION PLOTTER — Terminal Visualization{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=MODE [--input=PATH]\n", .{});
    print("\n{s}View Modes:{s}\n", .{ CYAN, RESET });
    print("  summary   — Final metrics ranking table\n", .{});
    print("  ppl       — PPL evolution curves\n", .{});
    print("  diversity — Diversity index trends\n", .{});
    print("  alive     — Worker survival curves\n", .{});
    print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    print("  --input=PATH  CSV file path (default: output/simulation_results.csv)\n", .{});
    print("  --help, -h    Show this help\n", .{});
    print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=summary\n", .{});
    print("  tri-sim-plot --view=ppl --input=/tmp/sim/simulation_results.csv\n", .{});
    print("\n", .{});
}
