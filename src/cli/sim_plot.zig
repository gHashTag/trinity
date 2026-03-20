//! SIMULATION PLOTTER — ASCII Visualization from CSV
//!
//! Reads simulation_results.csv and produces ASCII plots
//!
//! Usage: tri-sim-plot <csv_file>
//!
//! phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

const MAX_POINTS = 1000;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const csv_path = args[1];

    // Parse CSV - count lines first
    const csv_content = try std.fs.cwd().readFileAlloc(allocator, csv_path, 10_000_000);
    defer allocator.free(csv_content);

    var line_count: usize = 0;
    var lines_iter = std.mem.splitScalar(u8, csv_content, '\n');
    while (lines_iter.next()) |_| line_count += 1;
    line_count -= 1; // Exclude header

    // Allocate arrays
    const s1_data = try allocator.alloc([]const u8, line_count);
    const s2_data = try allocator.alloc([]const u8, line_count);
    const s3_data = try allocator.alloc([]const u8, line_count);
    const s4_data = try allocator.alloc([]const u8, line_count);
    defer {
        allocator.free(s1_data);
        allocator.free(s2_data);
        allocator.free(s3_data);
        allocator.free(s4_data);
    }

    var s1_len: usize = 0;
    var s2_len: usize = 0;
    var s3_len: usize = 0;
    var s4_len: usize = 0;

    // Second pass - parse
    var lines = std.mem.splitScalar(u8, csv_content, '\n');
    _ = lines.next(); // Skip header

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var fields = std.mem.splitScalar(u8, line, ',');
        _ = fields.next(); // scenario - unused
        _ = fields.next(); // step - unused
        const ppl_str = fields.next() orelse continue;

        // Determine which series
        if (std.mem.startsWith(u8, line, "0,S1") or std.mem.indexOf(u8, line, ",S1,") != null) {
            s1_data[s1_len] = try allocator.dupe(u8, ppl_str);
            s1_len += 1;
        } else if (std.mem.startsWith(u8, line, "0,S2") or std.mem.indexOf(u8, line, ",S2,") != null) {
            s2_data[s2_len] = try allocator.dupe(u8, ppl_str);
            s2_len += 1;
        } else if (std.mem.startsWith(u8, line, "0,S3") or std.mem.indexOf(u8, line, ",S3,") != null) {
            s3_data[s3_len] = try allocator.dupe(u8, ppl_str);
            s3_len += 1;
        } else if (std.mem.startsWith(u8, line, "0,S4") or std.mem.indexOf(u8, line, ",S4,") != null) {
            s4_data[s4_len] = try allocator.dupe(u8, ppl_str);
            s4_len += 1;
        }
    }

    // Print plots
    print("\n{s}╔═══════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
    print("{s}║  BRAIN EVOLUTION — ASCII Visualization                ║{s}\n", .{ BOLD, RESET });
    print("{s}╚═══════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

    print("{s}Figure 1: PPL Convergence (log scale){s}\n\n", .{ BOLD, RESET });

    // Simple ASCII plot
    print("{s}Scenario │ Initial │ Final  │ Converged{s}\n", .{ BOLD, RESET });
    print("{s}──────────┼─────────┼────────┼──────────{s}\n", .{ CYAN, RESET });

    if (s1_len > 0) {
        const initial = try std.fmt.parseFloat(f32, s1_data[0]);
        const final = try std.fmt.parseFloat(f32, s1_data[s1_len - 1]);
        print(" {s}S1{s}     │ {d:7.1} │ {d:6.1} │ {s}✓ Yes{s}\n", .{ GREEN, RESET, initial, final, GREEN, RESET });
    }
    if (s2_len > 0) {
        const initial = try std.fmt.parseFloat(f32, s2_data[0]);
        const final = try std.fmt.parseFloat(f32, s2_data[s2_len - 1]);
        print(" {s}S2{s}     │ {d:7.1} │ {d:6.1} │ {s}✗ No{s} (DEAD)\n", .{ RED, RESET, initial, final, RED, RESET });
    }
    if (s3_len > 0) {
        const initial = try std.fmt.parseFloat(f32, s3_data[0]);
        const final = try std.fmt.parseFloat(f32, s3_data[s3_len - 1]);
        print(" {s}S3{s}     │ {d:7.1} │ {d:6.1} │ {s}✓ Yes{s} (MultiObj)\n", .{ BLUE, RESET, initial, final, BLUE, RESET });
    }
    if (s4_len > 0) {
        const initial = try std.fmt.parseFloat(f32, s4_data[0]);
        const final = try std.fmt.parseFloat(f32, s4_data[s4_len - 1]);
        const converged = final < 100.0;
        const converg_str: []const u8 = if (converged) "Yes" else "No";
        print(" {s}S4{s}     │ {d:7.1} │ {d:6.1} │ {s}✗ No{s} (dePIN)\n", .{ MAGENTA, RESET, initial, final, converg_str, RESET });
    }
}

fn printUsage() void {
    print("\n{s}SIMULATION PLOTTER — ASCII Visualization{s}\n", .{ BOLD, RESET });
    print("\n{s}Usage:{s}\n  tri-sim-plot <csv_file>\n", .{ CYAN, RESET });
    print("\n", .{});
}
