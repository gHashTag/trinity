//! SIMULATION PLOTTER — ASCII Visualization
//!
//! Reads simulation_results.csv and displays:
//!   --view ppl       PPL evolution curves
//!   --view diversity Diversity index trends
//!   --view alive     Worker survival curves
//!   --view summary   Final metrics ranking table
//!
//! Usage: tri-sim-plot --view MODE --input PATH
//!
//! φ² + 1/phi² = 3 = TRINITY

const std = @import("std");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const WHITE = "\x1b[37m";

const ViewMode = enum {
    ppl,
    diversity,
    alive,
    summary,
};

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
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len > 1 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        printHelp();
        return;
    }

    var view_mode: ?ViewMode = null;
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
                print("Valid modes: ppl, diversity, alive, summary\n", .{});
                return error.InvalidViewMode;
            }
        } else if (std.mem.startsWith(u8, args[i], "--input=")) {
            input_path = args[i]["--input=".len..];
        } else if (std.mem.eql(u8, args[i], "--version")) {
            print("tri-sim-plot v1.0 — Terminal Visualization for Brain Evolution\n", .{});
            return;
        }
    }

    if (view_mode == null) {
        print("{s}Error: --view mode required (ppl|diversity|alive|summary){s}\n", .{ RED, RESET });
        printHelp();
        return error.ViewModeRequired;
    }

    const scenarios = try loadCSV(allocator, input_path);
    defer {
        for (scenarios) |s| {
            allocator.free(s.id);
            allocator.free(s.name);
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

    var scenario_map = std.StringHashMap(ScenarioData).init(allocator);
    defer scenario_map.deinit();

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
                1 => scenario_id = try allocator.dupe(u8, field_str),
                2 => ppl = std.fmt.parseFloat(f32, field_str) catch 0.0,
                3 => diversity = std.fmt.parseFloat(f32, field_str) catch 0.0,
                4 => alive = std.fmt.parseInt(usize, field_str, 10) catch 0,
                8 => energy = std.fmt.parseFloat(f32, field_str) catch 0.0,
                else => {},
            }
            step_idx += 1;
        }

        if (scenario_map.getPtr(scenario_id)) |entry| {
            try entry.points.append(allocator, DataPoint{
                .step = step,
                .scenario_id = scenario_id,
                .ppl = ppl,
                .diversity = diversity,
                .alive = alive,
                .energy = energy,
            });

            entry.final_ppl = ppl;
            entry.final_diversity = diversity;
            entry.final_alive = alive;
            entry.total_energy = energy;
        } else {
            const new_points = try std.ArrayList(DataPoint).initCapacity(allocator, 16);
            const new_data = ScenarioData{
                .points = new_points,
                .final_ppl = ppl,
                .final_diversity = diversity,
                .final_alive = alive,
                .total_energy = energy,
            };
            try scenario_map.put(try allocator.dupe(u8, scenario_id), new_data);
            // Try again to append to the newly created entry
            if (scenario_map.getPtr(scenario_id)) |entry| {
                try entry.points.append(allocator, DataPoint{
                    .step = step,
                    .scenario_id = scenario_id,
                    .ppl = ppl,
                    .diversity = diversity,
                    .alive = alive,
                    .energy = energy,
                });
            }
        }
    }

    var result = try std.ArrayList(ScenarioStats).initCapacity(allocator, 16);
    var iter = scenario_map.iterator();
    while (iter.next()) |entry| {
        const stats = ScenarioStats{
            .id = try allocator.dupe(u8, entry.key_ptr.*),
            .name = getScenarioName(entry.key_ptr.*),
            .final_ppl = entry.value_ptr.*.final_ppl,
            .final_diversity = entry.value_ptr.*.final_diversity,
            .final_alive = entry.value_ptr.*.final_alive,
            .total_energy = entry.value_ptr.*.total_energy,
            .converged = entry.value_ptr.*.final_alive > 0,
            .category = getScenarioCategory(entry.key_ptr.*),
        };
        try result.append(allocator, stats);
    }

    return result.toOwnedSlice(allocator);
}

const ScenarioData = struct {
    points: std.ArrayList(DataPoint),
    final_ppl: f32,
    final_diversity: f32,
    final_alive: usize,
    total_energy: f32,
};

fn getScenarioName(id: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "S1")) return "Baseline-1";
    if (std.mem.eql(u8, id, "S2")) return "Baseline-2 (High Crash)";
    if (std.mem.eql(u8, id, "S3")) return "S3-Mixed";
    if (std.mem.eql(u8, id, "S4")) return "S4-Mixed";
    if (std.mem.eql(u8, id, "S5")) return "S5-Mixed";
    if (std.mem.eql(u8, id, "S6")) return "JEPA-Heavy";
    if (std.mem.eql(u8, id, "S7")) return "High-Diversity";
    if (std.mem.eql(u8, id, "S8")) return "Low-Crash (Sacred-B)";
    if (std.mem.eql(u8, id, "S9")) return "Byzantine-Heavy";
    if (std.mem.eql(u8, id, "S10")) return "Energy-Optimal (Sacred-C)";
    if (std.mem.eql(u8, id, "S11")) return "Sacred-A";
    if (std.mem.eql(u8, id, "S12")) return "Sacred-B";
    if (std.mem.eql(u8, id, "S13")) return "Wide (K=32)";
    if (std.mem.eql(u8, id, "S14")) return "Baseline-Extended";
    if (std.mem.eql(u8, id, "S15")) return "Baseline-Extended-2";
    return id;
}

fn getScenarioCategory(id: []const u8) []const u8 {
    if (std.mem.startsWith(u8, id, "S1") or std.mem.startsWith(u8, id, "S2") or std.mem.startsWith(u8, id, "S14") or std.mem.startsWith(u8, id, "S15")) {
        return "Baseline";
    }
    if (std.mem.startsWith(u8, id, "S8") or std.mem.startsWith(u8, id, "S9") or std.mem.startsWith(u8, id, "S10") or std.mem.startsWith(u8, id, "S11") or std.mem.startsWith(u8, id, "S12")) {
        return "Sacred";
    }
    if (std.mem.startsWith(u8, id, "S7")) {
        return "dePIN";
    }
    if (std.mem.startsWith(u8, id, "S13")) {
        return "Wide";
    }
    return "Mixed";
}

fn getScenarioColor(category: []const u8) []const u8 {
    if (std.mem.eql(u8, category, "Baseline")) return GREEN;
    if (std.mem.eql(u8, category, "Sacred")) return MAGENTA;
    if (std.mem.eql(u8, category, "dePIN")) return YELLOW;
    if (std.mem.eql(u8, category, "Wide")) return CYAN;
    if (std.mem.eql(u8, category, "Mixed")) return BLUE;
    return WHITE;
}

fn plotPPL(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    var scenario_points = std.StringHashMap(std.ArrayList(DataPoint)).init(allocator);
    defer {
        var iter = scenario_points.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
            allocator.free(entry.key_ptr.*);
        }
        scenario_points.deinit();
    }

    var max_step: usize = 0;
    var max_ppl: f32 = 0.0;
    var min_ppl: f32 = std.math.floatMax(f32);

    // Group points by scenario
    for (scenarios) |s| {
        var points = try std.ArrayList(DataPoint).initCapacity(allocator, 16);
        try scenario_points.put(try allocator.dupe(u8, s.id), points);

        // Re-parse CSV for this scenario
        const csv_path = "output/simulation_results.csv";
        const file = std.fs.cwd().openFile(csv_path, .{}) catch continue;
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(contents);

        var lines = std.mem.tokenizeScalar(u8, contents, '\n');
        _ = lines.next(); // Skip header

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            var fields = std.mem.tokenizeScalar(u8, line, ',');
            var step_idx: usize = 0;
            var step: usize = 0;
            var scenario_id: []const u8 = "";
            var ppl: f32 = 0.0;

            while (fields.next()) |field| {
                const field_str = std.mem.trim(u8, field, " \r\n");
                switch (step_idx) {
                    0 => step = std.fmt.parseInt(usize, field_str, 10) catch 0,
                    1 => scenario_id = field_str,
                    2 => ppl = std.fmt.parseFloat(f32, field_str) catch 0.0,
                    else => {},
                }
                step_idx += 1;
            }

            if (std.mem.eql(u8, scenario_id, s.id) and ppl > 0) {
                try points.append(allocator, DataPoint{
                    .step = step,
                    .scenario_id = s.id,
                    .ppl = ppl,
                    .diversity = 0,
                    .alive = 0,
                    .energy = 0,
                });
                max_step = @max(max_step, step);
                max_ppl = @max(max_ppl, ppl);
                if (ppl < min_ppl) min_ppl = ppl;
            }
        }
    }

    if (max_step == 0) {
        print("{s}No PPL data found. Run simulation first.{s}\n", .{ YELLOW, RESET });
        return;
    }

    const graph_height = 20;
    const graph_width = 50;
    const y_max = @ceil(max_ppl * 1.1);
    const y_min = @floor(min_ppl * 0.9);

    print("\n{s}PPL Evolution (max {d} steps){s}\n", .{ BOLD, max_step, RESET });

    // Top border
    print("┌", .{});
    var i: usize = 0;
    while (i < graph_width) : (i += 1) print("─", .{});
    print("┐\n", .{});

    // Y-axis labels and graph
    var row: usize = graph_height;
    while (row > 0) : (row -= 1) {
        const y_val = y_min + (@as(f32, @floatFromInt(row)) / @as(f32, graph_height)) * (y_max - y_min);
        const y_label = @as(usize, @intFromFloat(y_val));
        print("{s}{d: >3}{s}│{s}", .{ DIM, y_label, RESET, WHITE });

        // Plot points for this Y level
        var col: usize = 0;
        while (col < graph_width) : (col += 1) {
            const step = (col * max_step) / graph_width;
            var plotted = false;

            var iter = scenario_points.iterator();
            while (iter.next()) |entry| {
                const points = entry.value_ptr.*;
                const color = getScenarioColor(getScenarioCategory(entry.key_ptr.*));

                for (points.items) |pt| {
                    if (pt.step == step and @abs(pt.ppl - y_val) < (y_max - y_min) / @as(f32, graph_height)) {
                        print("{s}●{s}", .{ color, WHITE });
                        plotted = true;
                        break;
                    }
                }
                if (plotted) break;
            }

            if (!plotted) print(" ", .{});
        }

        print("│\n", .{});
    }

    // Bottom border
    print("└", .{});
    i = 0;
    while (i < graph_width) : (i += 1) print("─", .{});
    print("┘\n", .{});

    // X-axis labels
    print("  ", .{});
    const x_labels = [5]usize{ 0, max_step / 4, max_step / 2, max_step * 3 / 4, max_step };
    for (x_labels) |x_label| {
        const pos = (x_label * graph_width) / max_step;
        var j: usize = 0;
        while (j < pos - 2) : (j += 1) print(" ", .{});
        print("{d}", .{x_label});
        const label_str = try std.fmt.allocPrint(allocator, "{d}", .{x_label});
        defer allocator.free(label_str);
        j += label_str.len;
    }
    print("\n\n", .{});

    // Legend
    print("{s}Legend:{s}\n", .{ BOLD, RESET });
    const categories = [_][]const u8{ "Baseline", "Sacred", "dePIN", "Wide", "Mixed" };
    for (categories) |cat| {
        const color = getScenarioColor(cat);
        print("  {s}●{s} {s}\n", .{ color, RESET, cat });
    }
    print("\n", .{});
}

fn plotDiversity(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    var scenario_points = std.StringHashMap(std.ArrayList(DataPoint)).init(allocator);
    defer {
        var iter = scenario_points.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
            allocator.free(entry.key_ptr.*);
        }
        scenario_points.deinit();
    }

    var max_step: usize = 0;
    var max_div: f32 = 0.0;

    // Group points by scenario
    for (scenarios) |s| {
        var points = try std.ArrayList(DataPoint).initCapacity(allocator, 16);
        try scenario_points.put(try allocator.dupe(u8, s.id), points);

        const csv_path = "output/simulation_results.csv";
        const file = std.fs.cwd().openFile(csv_path, .{}) catch continue;
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(contents);

        var lines = std.mem.tokenizeScalar(u8, contents, '\n');
        _ = lines.next();

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            var fields = std.mem.tokenizeScalar(u8, line, ',');
            var step_idx: usize = 0;
            var step: usize = 0;
            var scenario_id: []const u8 = "";
            var diversity: f32 = 0.0;

            while (fields.next()) |field| {
                const field_str = std.mem.trim(u8, field, " \r\n");
                switch (step_idx) {
                    0 => step = std.fmt.parseInt(usize, field_str, 10) catch 0,
                    1 => scenario_id = field_str,
                    3 => diversity = std.fmt.parseFloat(f32, field_str) catch 0.0,
                    else => {},
                }
                step_idx += 1;
            }

            if (std.mem.eql(u8, scenario_id, s.id) and diversity > 0) {
                try points.append(allocator, DataPoint{
                    .step = step,
                    .scenario_id = s.id,
                    .ppl = 0,
                    .diversity = diversity,
                    .alive = 0,
                    .energy = 0,
                });
                max_step = @max(max_step, step);
                max_div = @max(max_div, diversity);
            }
        }
    }

    if (max_step == 0) {
        print("{s}No diversity data found. Run simulation first.{s}\n", .{ YELLOW, RESET });
        return;
    }

    const graph_height = 20;
    const graph_width = 50;

    print("\n{s}Diversity Index Trends (max {d} steps){s}\n", .{ BOLD, max_step, RESET });

    print("┌", .{});
    var i: usize = 0;
    while (i < graph_width) : (i += 1) print("─", .{});
    print("┐\n", .{});

    var row: usize = graph_height;
    while (row > 0) : (row -= 1) {
        const y_val = (@as(f32, @floatFromInt(row)) / @as(f32, graph_height)) * max_div;
        print("{s}{d:.1}{s}│{s}", .{ DIM, y_val, RESET, WHITE });

        var col: usize = 0;
        while (col < graph_width) : (col += 1) {
            const step = (col * max_step) / graph_width;
            var plotted = false;

            var iter = scenario_points.iterator();
            while (iter.next()) |entry| {
                const points = entry.value_ptr.*;
                const color = getScenarioColor(getScenarioCategory(entry.key_ptr.*));

                for (points.items) |pt| {
                    if (pt.step == step and @abs(pt.diversity - y_val) < max_div / @as(f32, graph_height)) {
                        print("{s}●{s}", .{ color, WHITE });
                        plotted = true;
                        break;
                    }
                }
                if (plotted) break;
            }

            if (!plotted) print(" ", .{});
        }

        print("│\n", .{});
    }

    print("└", .{});
    i = 0;
    while (i < graph_width) : (i += 1) print("─", .{});
    print("┘\n", .{});

    print("  0", .{});
    const pos1 = (max_step * graph_width) / max_step;
    var j: usize = 0;
    while (j < pos1 - 3) : (j += 1) print(" ", .{});
    print("{d}", .{max_step});
    print("\n\n", .{});

    print("{s}Legend:{s}\n", .{ BOLD, RESET });
    const categories = [_][]const u8{ "Baseline", "Sacred", "dePIN", "Wide", "Mixed" };
    for (categories) |cat| {
        const color = getScenarioColor(cat);
        print("  {s}●{s} {s}\n", .{ color, RESET, cat });
    }
    print("\n", .{});
}

fn plotAlive(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    var scenario_points = std.StringHashMap(std.ArrayList(DataPoint)).init(allocator);
    defer {
        var iter = scenario_points.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
            allocator.free(entry.key_ptr.*);
        }
        scenario_points.deinit();
    }

    var max_step: usize = 0;
    var max_alive: usize = 0;

    // Group points by scenario
    for (scenarios) |s| {
        var points = try std.ArrayList(DataPoint).initCapacity(allocator, 16);
        try scenario_points.put(try allocator.dupe(u8, s.id), points);

        const csv_path = "output/simulation_results.csv";
        const file = std.fs.cwd().openFile(csv_path, .{}) catch continue;
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(contents);

        var lines = std.mem.tokenizeScalar(u8, contents, '\n');
        _ = lines.next();

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            var fields = std.mem.tokenizeScalar(u8, line, ',');
            var step_idx: usize = 0;
            var step: usize = 0;
            var scenario_id: []const u8 = "";
            var alive: usize = 0;

            while (fields.next()) |field| {
                const field_str = std.mem.trim(u8, field, " \r\n");
                switch (step_idx) {
                    0 => step = std.fmt.parseInt(usize, field_str, 10) catch 0,
                    1 => scenario_id = field_str,
                    4 => alive = std.fmt.parseInt(usize, field_str, 10) catch 0,
                    else => {},
                }
                step_idx += 1;
            }

            if (std.mem.eql(u8, scenario_id, s.id)) {
                try points.append(allocator, DataPoint{
                    .step = step,
                    .scenario_id = s.id,
                    .ppl = 0,
                    .diversity = 0,
                    .alive = alive,
                    .energy = 0,
                });
                max_step = @max(max_step, step);
                max_alive = @max(max_alive, alive);
            }
        }
    }

    if (max_step == 0) {
        print("{s}No survival data found. Run simulation first.{s}\n", .{ YELLOW, RESET });
        return;
    }

    const graph_height = 20;
    const graph_width = 50;

    print("\n{s}Worker Survival Curves (max {d} steps){s}\n", .{ BOLD, max_step, RESET });

    print("┌", .{});
    var i: usize = 0;
    while (i < graph_width) : (i += 1) print("─", .{});
    print("┐\n", .{});

    var row: usize = graph_height;
    while (row > 0) : (row -= 1) {
        const row_f: f32 = @floatFromInt(row);
        const graph_h: f32 = @floatFromInt(graph_height);
        const max_a: f32 = @floatFromInt(max_alive);
        const y_val = (row_f / graph_h) * max_a;
        print("{s}{d: >3}{s}│{s}", .{ DIM, @as(usize, @intFromFloat(y_val)), RESET, WHITE });

        var col: usize = 0;
        while (col < graph_width) : (col += 1) {
            const step = (col * max_step) / graph_width;
            var plotted = false;

            var iter = scenario_points.iterator();
            while (iter.next()) |entry| {
                const points = entry.value_ptr.*;
                const color = getScenarioColor(getScenarioCategory(entry.key_ptr.*));

                for (points.items) |pt| {
                    const threshold = max_a / graph_h;
                    if (pt.step == step and @abs(@as(f32, pt.alive) - y_val) < threshold) {
                        print("{s}●{s}", .{ color, WHITE });
                        plotted = true;
                        break;
                    }
                }
                if (plotted) break;
            }

            if (!plotted) print(" ", .{});
        }

        print("│\n", .{});
    }

    print("└", .{});
    i = 0;
    while (i < graph_width) : (i += 1) print("─", .{});
    print("┘\n", .{});

    print("  0", .{});
    const pos1 = (max_step * graph_width) / max_step;
    var j: usize = 0;
    while (j < pos1 - 3) : (j += 1) print(" ", .{});
    print("{d}", .{max_step});
    print("\n\n", .{});

    print("{s}Legend:{s}\n", .{ BOLD, RESET });
    const categories = [_][]const u8{ "Baseline", "Sacred", "dePIN", "Wide", "Mixed" };
    for (categories) |cat| {
        const color = getScenarioColor(cat);
        print("  {s}●{s} {s}\n", .{ color, RESET, cat });
    }
    print("\n", .{});
}

fn printSummary(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    // Sort by PPL (lower is better)
    const sorted = try allocator.dupe(ScenarioStats, scenarios);
    std.sort.heap(ScenarioStats, sorted, {}, structCmp);

    print("\n{s}┌────────────────────────────────────────────────────────────────┐{s}\n", .{ CYAN, RESET });
    print("{s}│  SIMULATION SUMMARY — Ranked by PPL                 │{s}\n", .{ BOLD, RESET });
    print("{s}├────────────────────────────────────────────────────────────────┤{s}\n", .{ CYAN, RESET });

    print("{s}┌──────┬──────────────────┬───────┬───────────┬────────┬───────┐{s}\n", .{ WHITE, RESET });
    print("{s}│ Rank │ Scenario         │  PPL  │ Diversity │ Alive  │ Energy│{s}\n", .{ BOLD, RESET });
    print("{s}├──────┼──────────────────┼───────┼───────────┼────────┼───────┤{s}\n", .{ CYAN, RESET });

    for (sorted, 0..) |s, i| {
        const color = getScenarioColor(s.category);
        print("{s}", .{color});

        const name_with_status = try std.fmt.allocPrint(allocator, "{s}{s}", .{ s.name, if (!s.converged) " (DEAD)" else "" });
        defer allocator.free(name_with_status);

        print("│ {:>4} │ {:<14} │ {:>5.2} │ {:>9.3} │ {:>6} │ {:>5.0} │{s}\n", .{ i + 1, name_with_status, s.final_ppl, s.final_diversity, s.final_alive, s.total_energy / 1000.0, RESET });

        if (i == sorted.len - 1) {
            print("{s}└──────┴──────────────────┴───────┴───────────┴────────┴───────┘{s}\n\n", .{ CYAN, RESET });
        } else {
            print("{s}├──────┼──────────────────┼───────┼───────────┼────────┼───────┤{s}\n", .{ DIM, RESET });
        }
    }

    print("{s}Statistics:{s}\n", .{ BOLD, RESET });

    var sum: f32 = 0;
    for (scenarios) |s| sum += s.final_ppl;
    const avg_ppl = sum / @as(f32, scenarios.len);

    var best_idx: usize = 0;
    var best_ppl = scenarios[0].final_ppl;
    for (scenarios, 1..) |s, i| {
        if (s.final_ppl < best_ppl) {
            best_ppl = s.final_ppl;
            best_idx = i;
        }
    }

    var converged_count: usize = 0;
    for (scenarios) |s| {
        if (s.converged) converged_count += 1;
    }

    print("  {s}Best PPL:{s} {d:.2} ({s})\n", .{ GREEN, RESET, scenarios[best_idx].final_ppl, scenarios[best_idx].id });
    print("  Average PPL: {d:.2}\n", .{avg_ppl});
    print("  Converged: {d}/{}\n", .{ converged_count, scenarios.len });
    var best_energy_idx: usize = 0;
    var best_energy = scenarios[0].total_energy;
    for (scenarios, 1..) |s, i| {
        if (s.total_energy < best_energy) {
            best_energy = s.total_energy;
            best_energy_idx = i;
        }
    }
    print("  {s}Best Energy:{s} {d:.0}K ({s})\n", .{ GREEN, RESET, best_energy / 1000.0, scenarios[best_energy_idx].id });
}

fn structCmp(_: void, a: ScenarioStats, b: ScenarioStats) bool {
    return a.final_ppl < b.final_ppl;
}

fn printHelp() void {
    print("\n{s}SIMULATION PLOTTER — Terminal Visualization{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=MODE --input=PATH\n", .{});
    print("\n{s}View Modes:{s}\n", .{ CYAN, RESET });
    print("  ppl       — PPL evolution curves (all scenarios on one graph)\n", .{});
    print("  diversity — Diversity index trends over time\n", .{});
    print("  alive     — Worker survival curves\n", .{});
    print("  summary   — Final metrics ranking table (ranked by PPL)\n", .{});
    print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    print("  --input=PATH  CSV file path (default: output/simulation_results.csv)\n", .{});
    print("  --help, -h    Show this help\n", .{});
    print("  --version     Show version\n", .{});
    print("\n{s}Scenario Categories:{s}\n", .{ CYAN, RESET });
    print("  Baseline {s}●{s} — S1, S2, S14, S15\n", .{ GREEN, RESET });
    print("  Sacred   {s}●{s} — S8-S12 (Sacred search variants)\n", .{ MAGENTA, RESET });
    print("  dePIN     {s}●{s} — S7 (High-Diversity)\n", .{ YELLOW, RESET });
    print("  Wide     {s}●{s} — S13 (K=32)\n", .{ CYAN, RESET });
    print("  Mixed    {s}●{s} — S3-S6 (JEPA/NCA mixed)\n", .{ BLUE, RESET });
    print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=ppl\n", .{});
    print("  tri-sim-plot --view=summary --input=/tmp/results.csv\n", .{});
    print("  tri-sim-plot --view=alive\n", .{});
    print("\n", .{});
}
