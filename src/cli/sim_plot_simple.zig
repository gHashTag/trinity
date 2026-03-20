//! SIMULATION PLOTTER — ASCII Visualization
//!
//! Reads simulation_results.csv and displays summary table
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
        .ppl => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .diversity => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .alive => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .summary => try printSummary(allocator, scenarios),
    }
}

fn loadCSV(allocator: Allocator, csv_path: []const u8) ![]ScenarioStats {
    const file = std.fs.cwd().openFile(csv_path, .{}) catch |err| {
        print("{s}Error: cannot open '{s}': {}{s}\n", .{ RED, csv_path, err, RESET });
        return err;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024, null);
    defer allocator.free(contents);

    var scenario_map = std.StringHashMap(ScenarioData).init(allocator);
    defer scenario_map.deinit();

    var lines = std.mem.tokenizeScalar(u8, contents, '\n');

    // Skip header
    _ = lines.next();

    const ScenarioData = struct {
        points: std.ArrayList(DataPoint),
        final_ppl: f32,
        final_diversity: f32,
        final_alive: usize,
        total_energy: f32,
    };

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

        const entry = scenario_map.get(scenario_id) orelse blk: {
            var points = try std.ArrayList(DataPoint).init(allocator);
            const new_data = ScenarioData{
                .points = points,
                .final_ppl = ppl,
                .final_diversity = diversity,
                .final_alive = alive,
                .total_energy = energy,
            };
            try scenario_map.put(try allocator.dupe(u8, scenario_id), new_data);
        };

        if (entry) |e| {
            try e.points.append(allocator, DataPoint{
                .step = step,
                .scenario_id = scenario_id,
                .ppl = ppl,
                .diversity = diversity,
                .alive = alive,
                .energy = energy,
            });

            e.value_ptr.*.final_ppl = ppl;
            e.value_ptr.*.final_diversity = diversity;
            e.value_ptr.*.final_alive = alive;
            e.value_ptr.*.total_energy = energy;
        }
    }

    var result = try std.ArrayList(ScenarioStats).init(allocator);
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

fn getScenarioName(id: []const u8) []const u8 {
    if (std.mem.eql(u8, id, "S1")) return "Baseline-1";
    if (std.mem.eql(u8, id, "S2")) return "Baseline-2 (High Crash)";
    if (std.mem.eql(u8, id, "S3")) return "S3-Mixed";
    if (std.mem.eql(u8, id, "S4")) return "S4-Mixed";
    if (std.mem.eql(u8, id, "S5")) return "S5-Mixed";
    if (std.mem.eql(u8, id, "S6")) return "JEPA-Heavy";
    if (std.mem.eql(u8, only, "S7")) return "High-Diversity";
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
    if (std.mem.eql(u8, id, "S1") or std.mem.eql(u8, id, "S2") or std.mem.eql(u8, id, "S14") or std.mem.eql(u8, id, "S15")) {
        return "Baseline";
    }
    if (std.mem.eql(u8, id, "S11") or std.mem.eql(u8, id, "S12") {
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
    if (std.mem.eql(u8, category, "Mixed")) return BLUE;
    return WHITE;
}

fn printSummary(allocator: Allocator, scenarios: []const ScenarioStats) !void {
    print("\n{s}╔════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  SIMULATION SUMMARY                                    ║{s}\n", .{ BOLD, RESET });
    print("{s}╚═════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    print("  Run simulation suite first: {s}zig build sim-suite --output /tmp/sim{s}\n", .{ YELLOW, RESET });
}

fn printHelp() void {
    print("\n{s}SIMULATION PLOTTER — Terminal Visualization{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=MODE --input=PATH\n", .{});
    print("\n{s}View Modes:{s}\n", .{ CYAN, RESET });
    print("  ppl       — Not implemented\n", .{});
    print("  diversity — Not implemented\n", .{});
    print("  alive     — Not implemented\n", .{});
    print("  summary   — Final metrics ranking table\n", .{});
    print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    print("  --input=PATH  CSV file path (default: output/simulation_results.csv)\n", .{});
    print("  --help, -h    Show this help\n", .{});
    print("  --version     Show version\n", .{});
    print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=summary\n", .{});
    print("\n", .{});
}
