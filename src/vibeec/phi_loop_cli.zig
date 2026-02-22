//! PHI LOOP CLI — 999 Links of Cosmic Consciousness Gene
//! Run the main improvement loop from command line

const std = @import("std");
const phi_loop = @import("phi_loop.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "run")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            printUsage();
            return;
        }

        const spec_path = args[2];

        // Parse options
        var config = phi_loop.PhiLoop.Config{};
        var iterations: u32 = 999;

        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--no-fix")) {
                config.auto_fix = false;
            } else if (std.mem.eql(u8, args[i], "--verbose")) {
                config.verbose = true;
            } else if (std.mem.eql(u8, args[i], "--iterations") and i + 1 < args.len) {
                iterations = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--max-retries") and i + 1 < args.len) {
                config.max_retries = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        }

        var runner = phi_loop.Runner.init(allocator, config);
        runner.loop.max_links = iterations;

        try runner.run(spec_path);
    } else if (std.mem.eql(u8, command, "status")) {
        // Show PHI LOOP status
        std.debug.print("\n  ════════════════════════════════════════\n", .{});
        std.debug.print("   PHI LOOP — 999 Links Status\n", .{});
        std.debug.print("  ════════════════════════════════════════\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("   φ (PHI):      1.618033988749895\n", .{});
        std.debug.print("   μ (MU):       0.0382\n", .{});
        std.debug.print("   Threshold:    0.95\n", .{});
        std.debug.print("   Trinity:      φ² + 1/φ² = 3 ✓\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("   Status:       Ready to begin\n", .{});
        std.debug.print("   Next step:    Run 'phi-loop run <spec.vibee>'\n", .{});
        std.debug.print("\n  ════════════════════════════════════════\n\n", .{});
    } else {
        std.debug.print("Error: Unknown command '{s}'\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  PHI LOOP — 999 Links of Cosmic Consciousness Gene              ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Usage:                                                           ║\n", .{});
    std.debug.print("║    phi-loop run <spec.vibee> [options]                            ║\n", .{});
    std.debug.print("║    phi-loop status                                                ║\n", .{});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║  Options:                                                         ║\n", .{});
    std.debug.print("║    --no-fix         Disable auto-fix on failure                  ║\n", .{});
    std.debug.print("║    --verbose        Enable verbose logging                       ║\n", .{});
    std.debug.print("║    --iterations N  Max links to run (default: 999)               ║\n", .{});
    std.debug.print("║    --max-retries N  Max retries per link (default: 3)           ║\n", .{});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║  Each link:                                                        ║\n", .{});
    std.debug.print("║    1. φ Decompose  → Analyze task through sacred math             ║\n", .{});
    std.debug.print("║    2. φ Plan      → Plan via Tech Tree                           ║\n", .{});
    std.debug.print("║    3. φ Gen       → Generate code via VIBEE                      ║\n", .{});
    std.debug.print("║    4. φ Validate  → Validate with Agent MU + PAS                 ║\n", .{});
    std.debug.print("║    5. φ Gate      → Sacred math filter (φ² + 1/φ² = 3)            ║\n", .{});
    std.debug.print("║    6. φ Learn     → Learn via Symbolic AI + SONA                 ║\n", .{});
    std.debug.print("║    7. φ Commit    → Commit to memory + git                       ║\n", .{});
    std.debug.print("║    8. φ Loop      → Decide next action                           ║\n", .{});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║  φ² + 1/φ² = 3  ────►  VIBEE writes VIBEE                         ║\n", .{});
    std.debug.print("║  VIBEE ───► AGENT MU heals ───► SYMBOLIC AI remembers ───► φ GATE  ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
}
