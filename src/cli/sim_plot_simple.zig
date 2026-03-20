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
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const WHITE = "\x1b[37m";

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

    switch (view_mode.?) {
        .ppl => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .diversity => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .alive => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .summary => {
            try printSummary(allocator, input_path);
        },
    }
}

fn printSummary(allocator: Allocator, csv_path: []const u8) !void {
    const file = std.fs.cwd().openFile(csv_path, .{}) catch |err| {
        print("{s}Error: cannot open '{s}': {}{s}\n", .{ RED, csv_path, err, RESET });
        return err;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 10000 * 1024);
    defer allocator.free(contents);

    print("{s}╔════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  SIMULATION SUMMARY                                    ║{s}\n", .{ BOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    print("  Run simulation suite first: {s}zig build sim-suite --output /tmp/sim{s}\n", .{ YELLOW, RESET });
}

fn printHelp() void {
    print("\n{s}SIMULATION PLOTTER — Terminal Visualization{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=MODE --input=PATH\n", .{});
    print("\n{s}Options:{s}\n", .{ CYAN, RESET });
    print("  --view=MODE   View mode (required)\n", .{});
    print("                ppl       — PPL evolution curves\n", .{});
    print("                diversity — Diversity index trends\n", .{});
    print("                alive     — Worker survival curves\n", .{});
    print("                summary   — Final metrics ranking table\n", .{});
    print("  --input=PATH  CSV file path (default: output/simulation_results.csv)\n", .{});
    print("  --help, -h    Show this help\n", .{});
    print("  --version     Show version\n", .{});
    print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=ppl\n", .{});
    print("  tri-sim-plot --view=summary --input=/tmp/results/simulation_results.csv\n", .{});
    print("\n", .{});
}
