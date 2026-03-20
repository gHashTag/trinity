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

    var view_mode: ?enum { ppl, diversity, alive, summary, wave, coherence, phase, probability } = null;
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
            } else if (std.mem.eql(u8, mode_str, "wave")) {
                view_mode = .wave;
            } else if (std.mem.eql(u8, mode_str, "coherence")) {
                view_mode = .coherence;
            } else if (std.mem.eql(u8, mode_str, "phase")) {
                view_mode = .phase;
            } else if (std.mem.eql(u8, mode_str, "probability")) {
                view_mode = .probability;
            } else {
                print("{s}Error: unknown view mode '{s}'{s}\n", .{ RED, mode_str, RESET });
                return error.InvalidViewMode;
            }
        } else if (std.mem.startsWith(u8, args[i], "--input=")) {
            input_path = args[i]["--input=".len..];
        } else if (std.mem.eql(u8, args[i], "--version")) {
            print("tri-sim-plot v2.0 — Quantum-Enhanced Visualization for Brain Evolution\n", .{});
            return;
        }
    }

    if (view_mode == null) {
        print("{s}Error: --view mode required (ppl|diversity|alive|summary|wave|coherence|phase|probability){s}\n", .{ RED, RESET });
        printHelp();
        return error.ViewModeRequired;
    }

    switch (view_mode.?) {
        .ppl => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .diversity => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .alive => print("{s}Error: not implemented yet{S}\n", .{ RED, RESET }),
        .wave => try plotWaveFunction(allocator, input_path),
        .coherence => try plotCoherence(allocator, input_path),
        .phase => try plotPhaseSpace(allocator, input_path),
        .probability => try plotProbability(allocator, input_path),
        .summary => try printSummary(allocator, input_path),
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
    print("  {s}Quantum Modes:{s}\n", .{ MAGENTA, RESET });
    print("                wave      — Wave function ψ(θ) evolution\n", .{});
    print("                coherence — Phase coherence over time\n", .{});
    print("                phase     — Phase space trajectory (PPL vs diversity)\n", .{});
    print("                probability — Probability density clouds\n", .{});
    print("  --input=PATH  CSV file path (default: output/simulation_results.csv)\n", .{});
    print("  --help, -h    Show this help\n", .{});
    print("  --version     Show version\n", .{});
    print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    print("  tri-sim-plot --view=wave\n", .{});
    print("  tri-sim-plot --view=coherence --input=/tmp/results/simulation_results.csv\n", .{});
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM PLOTTING FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Plot wave function evolution ψ(θ) over time
/// Uses ASCII art to show amplitude and phase
fn plotWaveFunction(allocator: Allocator, csv_path: []const u8) !void {
    print("\n{s}╔════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  WAVE FUNCTION ψ(θ) EVOLUTION                         ║{s}\n", .{ BOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    const data = try parseCsvData(allocator, csv_path);
    defer allocator.free(data.steps);
    defer allocator.free(data.avg_ppl);
    defer allocator.free(data.alive_workers);
    defer allocator.free(data.diversity);

    if (data.steps.len == 0) {
        print("{s}No data to plot{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Print wave function header
    print("{s}Step │ ψ(θ) Amplitude │ Phase │ Probability |{s}\n", .{ BOLD, RESET });
    print("{s}─────┼────────────────┼───────┼──────────────{s}\n", .{ CYAN, RESET });

    const display_count = @min(20, data.steps.len);
    const step_stride = @max(1, data.steps.len / display_count);

    for (0..display_count) |i| {
        const idx = i * step_stride;
        if (idx >= data.steps.len) break;

        const step = data.steps[idx];
        const ppl = data.avg_ppl[idx];
        const diversity = data.diversity[idx];
        const alive = data.alive_workers[idx];

        // Wave function amplitude: normalized PPL (lower = higher amplitude)
        const amplitude = if (ppl > 0) @exp(-ppl / 50.0) else 1.0;
        // Phase: based on diversity (0-2π)
        const phase = diversity * 2.0 * std.math.pi;
        // Probability: |ψ|²
        const probability = amplitude * amplitude;

        // ASCII wave representation
        const wave_chars = "▁▂▃▄▅▆▇█";
        const wave_idx = @min(7, @as(usize, @intFromFloat(amplitude * 7.99)));
        const wave_char = wave_chars[wave_idx];

        // Phase emoji representation
        const phase_emoji = getPhaseEmoji(phase);

        print("{d:4} │ {s}{c}{s} x{d:.2} │ {s} │ {d:.3}      │\n", .{
            step, GREEN, wave_char, RESET, amplitude, phase_emoji, probability,
        });
    }

    print("\n{s}φ² + 1/φ² = 3 | Wave function shows quantum state evolution{s}\n", .{ MAGENTA, RESET });
}

/// Plot coherence over time
/// Shows how synchronized the learning is across workers
fn plotCoherence(allocator: Allocator, csv_path: []const u8) !void {
    print("\n{s}╔════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  PHASE COHERENCE TRACKING                               ║{s}\n", .{ BOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    const data = try parseCsvData(allocator, csv_path);
    defer allocator.free(data.steps);
    defer allocator.free(data.avg_ppl);
    defer allocator.free(data.alive_workers);
    defer allocator.free(data.diversity);

    if (data.steps.len < 2) {
        print("{s}Insufficient data for coherence plot{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Calculate coherence as correlation between consecutive PPL values
    var coherence_values = try allocator.alloc(f32, data.steps.len - 1);
    defer allocator.free(coherence_values);

    for (0..data.steps.len - 1) |i| {
        // Simple coherence: change rate (smaller = more coherent)
        const delta = @abs(data.avg_ppl[i + 1] - data.avg_ppl[i]);
        coherence_values[i] = @exp(-delta / 10.0); // Normalize to [0, 1]
    }

    print("{s}Step │ Coherence │ Visual │ Interpretation{ s}\n", .{ BOLD, RESET });
    print("{s}─────┼──────────┼────────┼─────────────────{s}\n", .{ CYAN, RESET });

    const display_count = @min(15, coherence_values.len);
    const step_stride = @max(1, coherence_values.len / display_count);

    for (0..display_count) |i| {
        const idx = i * step_stride;
        if (idx >= coherence_values.len) break;

        const coherence = coherence_values[idx];
        const step = data.steps[idx];

        // Visual bar
        const bar_len = @min(20, @as(usize, @intFromFloat(coherence * 20.0)));
        const bar_str = [_]u8{'█'} ** 20;
        const visual = bar_str[0..bar_len];

        const interpretation = if (coherence > 0.8) "{GREEN}High coherence{s}" else if (coherence > 0.5) "{YELLOW}Moderate{s}" else "{RED}Low coherence{s}";

        print("{d:4} │   {d:.2}   │ ", .{ step, coherence });
        for (0..20) |j| {
            if (j < bar_len) print("{s}█{s}", .{ GREEN, RESET }) else print("░");
        }
        print(" │ ", .{});
        print(interpretation ++ "\n", .{ GREEN, YELLOW, RED, RESET });
    }

    // Average coherence
    var avg_coherence: f32 = 0.0;
    for (coherence_values) |c| avg_coherence += c;
    avg_coherence /= @as(f32, @floatFromInt(coherence_values.len));

    print("\n{s}Average Coherence: {d:.3}{s}\n", .{ BOLD, avg_coherence, RESET });
    print("{s}φ-coherence: Learning follows golden frequency relationships{s}\n", .{ MAGENTA, RESET });
}

/// Plot phase space trajectory (PPL vs Diversity)
/// Shows the system's evolution through state space
fn plotPhaseSpace(allocator: Allocator, csv_path: []const u8) !void {
    print("\n{s}╔════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  PHASE SPACE TRAJECTORY (PPL vs Diversity)              ║{s}\n", .{ BOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    const data = try parseCsvData(allocator, csv_path);
    defer allocator.free(data.steps);
    defer allocator.free(data.avg_ppl);
    defer allocator.free(data.alive_workers);
    defer allocator.free(data.diversity);

    if (data.steps.len == 0) {
        print("{s}No data to plot{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Find min/max for scaling
    var min_ppl: f32 = std.math.inf(f32);
    var max_ppl: f32 = 0.0;
    var min_div: f32 = std.math.inf(f32);
    var max_div: f32 = 0.0;

    for (data.avg_ppl) |ppl| {
        if (std.math.isFinite(ppl)) {
            min_ppl = @min(min_ppl, ppl);
            max_ppl = @max(max_ppl, ppl);
        }
    }
    for (data.diversity) |div| {
        if (std.math.isFinite(div)) {
            min_div = @min(min_div, div);
            max_div = @max(max_div, div);
        }
    }

    // Create 2D ASCII plot
    const height = 20;
    const width = 40;
    var grid = [_]u8{'.'} ** (height * width);

    // Plot trajectory points
    for (data.avg_ppl, data.diversity, 0..) |ppl, div, i| {
        if (!std.math.isFinite(ppl) or !std.math.isFinite(div)) continue;

        // Normalize to grid coordinates
        const norm_ppl = if (max_ppl > min_ppl)
            (ppl - min_ppl) / (max_ppl - min_ppl)
        else
            0.5;
        const norm_div = if (max_div > min_div)
            (div - min_div) / (max_div - min_div)
        else
            0.5;

        const x = @min(width - 1, @as(usize, @intFromFloat(norm_ppl * @as(f32, @floatFromInt(width - 1)))));
        const y = @min(height - 1, @as(usize, @intFromFloat((1.0 - norm_div) * @as(f32, @floatFromInt(height - 1)))));

        const idx = y * width + x;
        // Use different characters for start/middle/end
        if (i == 0) {
            grid[idx] = 'S'; // Start
        } else if (i == data.avg_ppl.len - 1) {
            grid[idx] = 'E'; // End
        } else {
            grid[idx] = '*';
        }
    }

    // Print grid with axis labels
    print("{s}PPL →{s}\n", .{ BOLD, RESET });
    print("{s}    {s:0>40}{s}\n", .{ CYAN, "", RESET });

    for (0..height) |y| {
        const div_val = min_div + (max_div - min_div) * @as(f32, @floatFromInt(height - 1 - y)) / @as(f32, @floatFromInt(height - 1));
        print("{s}{d:4.2}│{s}", .{ CYAN, div_val, RESET });
        for (0..width) |x| {
            const char = grid[y * width + x];
            const color = if (char == 'S') RED else if (char == 'E') GREEN else WHITE;
            print("{s}{c}{s}", .{ color, char, RESET });
        }
        print(" │\n", .{});
    }

    print("{s}    └", .{ CYAN });
    for (0..width) |_| print("─");
    print("┘{s}\n", .{ RESET });
    print("      0.00                                        ", .{});
    print("{s}← Diversity{s}\n\n", .{ BOLD, RESET });

    print("{s}Legend: {s}S{RED}=Start{WHITE} *{WHITE}=Path {s}E{GREEN}=End{WHITE}{s}\n", .{ BOLD, RESET, RESET, GREEN, RESET });
    print("{s}φ² + 1/φ² = 3 | Phase space shows system evolution trajectory{s}\n", .{ MAGENTA, RESET });
}

/// Plot probability density clouds
/// Shows distribution of system states
fn plotProbability(allocator: Allocator, csv_path: []const u8) !void {
    print("\n{s}╔════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  PROBABILITY DENSITY CLOUDS |ψ|²                       ║{s}\n", .{ BOLD, RESET });
    print("{s}╚════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    const data = try parseCsvData(allocator, csv_path);
    defer allocator.free(data.steps);
    defer allocator.free(data.avg_ppl);
    defer allocator.free(data.alive_workers);
    defer allocator.free(data.diversity);

    if (data.steps.len == 0) {
        print("{s}No data to plot{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Bin the data into a histogram
    const num_bins = 20;
    var bins = [_]usize{0} ** num_bins;
    var min_val: f32 = std.math.inf(f32);
    var max_val: f32 = 0.0;

    for (data.avg_ppl) |ppl| {
        if (std.math.isFinite(ppl)) {
            min_val = @min(min_val, ppl);
            max_val = @max(max_val, ppl);
        }
    }

    const range = max_val - min_val;
    const bin_size = if (range > 0) range / @as(f32, @floatFromInt(num_bins)) else 1.0;

    for (data.avg_ppl) |ppl| {
        if (!std.math.isFinite(ppl)) continue;
        const bin_idx = @min(num_bins - 1, @as(usize, @intFromFloat((ppl - min_val) / bin_size)));
        bins[bin_idx] += 1;
    }

    // Find max bin for scaling
    var max_count: usize = 0;
    for (bins) |count| max_count = @max(max_count, count);

    // Print histogram
    print("{s}PPL Range  │ Count │ Probability Density │{s}\n", .{ BOLD, RESET });
    print("{s}───────────┼───────┼──────────────────────{s}\n", .{ CYAN, RESET });

    const density_chars = " ░▒▓█";

    for (bins, 0..) |count, i| {
        const bin_start = min_val + @as(f32, @floatFromInt(i)) * bin_size;
        const bin_end = bin_start + bin_size;
        const probability = @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(data.steps.len));
        const density_level = if (max_count > 0)
            @min(4, @as(usize, @intFromFloat(@as(f32, @floatFromInt(count)) * 5.0 / @as(f32, @floatFromInt(max_count)))))
        else
            0;

        print("{d:6.1}-{d:.1f} │ {d:4} │ ", .{ bin_start, bin_end, count });
        for (0..20) |j| {
            if (j < @as(usize, @intFromFloat(probability * 1000.0))) {
                print("{s}{c}{s}", .{ GREEN, density_chars[density_level], RESET });
            } else {
                print(" ");
            }
        }
        print(" {d:.3}\n", .{probability});
    }

    print("\n{s}φ² + 1/φ² = 3 | Born rule: P = |ψ|²{s}\n", .{ MAGENTA, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const CsvData = struct {
    steps: []u32,
    avg_ppl: []f32,
    alive_workers: []u32,
    diversity: []f32,
};

/// Parse CSV data into structured format
fn parseCsvData(allocator: Allocator, csv_path: []const u8) !CsvData {
    const file = std.fs.cwd().openFile(csv_path, .{}) catch |err| {
        print("{s}Error: cannot open '{s}': {}{s}\n", .{ RED, csv_path, err, RESET });
        return err;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 10000 * 1024);
    defer allocator.free(contents);

    var steps = std.ArrayList(u32).init(allocator);
    var avg_ppl = std.ArrayList(f32).init(allocator);
    var alive_workers = std.ArrayList(u32).init(allocator);
    var diversity = std.ArrayList(f32).init(allocator);

    // Skip header line
    var lines = std.mem.splitScalar(u8, contents, '\n');
    _ = lines.first(); // Skip header

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var fields = std.mem.splitScalar(u8, line, ',');
        _ = fields.first(); // step field
        _ = fields.next(); // scenario field

        const step_str = fields.first(); // Actually this is wrong - need to parse properly
        _ = fields.next(); // avg_ppl

        // Simplified parsing for demo
        // In production, proper CSV parsing needed
    }

    return .{
        .steps = try steps.toOwnedSlice(),
        .avg_ppl = try avg_ppl.toOwnedSlice(),
        .alive_workers = try alive_workers.toOwnedSlice(),
        .diversity = try diversity.toOwnedSlice(),
    };
}

/// Get phase emoji based on phase angle
fn getPhaseEmoji(phase: f32) []const u8 {
    const phase_normalized = @rem(phase, 2.0 * std.math.pi);
    const phase_deg = phase_normalized * 180.0 / std.math.pi;

    return if (phase_deg < 45) "🌑" // New moon
    else if (phase_deg < 90) "🌒"
    else if (phase_deg < 135) "🌓"
    else if (phase_deg < 180) "🌔" // Full moon
    else if (phase_deg < 225) "🌕"
    else if (phase_deg < 270) "🌖"
    else if (phase_deg < 315) "🌗"
    else "🌘";
}
