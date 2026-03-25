// ═══════════════════════════════════════════════════════════════════════════════
// TRI SPEC COMMAND — TRI-27 Idiom 11 Tools
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri spec audit      — Scan .tri files, report annotation coverage
//   tri spec apply      — Auto-apply annotations to files (TODO)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors");

const audit = @import("tri_spec_audit.zig");
const apply = @import("tri_spec_apply.zig");
const YELLOW = colors.YELLOW;
const GREEN = colors.GREEN;
const RESET = colors.RESET;

/// Main entry point for `tri spec` command
pub fn runSpecCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printSpecHelp();
        return;
    }

    const subcommand = args[0];

    if (std.mem.eql(u8, subcommand, "audit")) {
        return runSpecAudit(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcommand, "apply")) {
        return runSpecApply(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        printSpecHelp();
    } else {
        std.debug.print("{s}Error:{s} Unknown spec subcommand: {s}\n", .{ YELLOW, RESET, subcommand });
        std.debug.print("  Run: tri spec help\n", .{});
        return error.UnknownSubcommand;
    }
}

/// Run `tri spec audit` — scan .tri files and report coverage
fn runSpecAudit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var specs_dir: []const u8 = "specs";
    var fail_below: f64 = 0.0; // Default: don't fail

    // Parse args
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--fail-below")) {
            if (i + 1 < args.len) {
                i += 1;
                fail_below = try std.fmt.parseFloat(f64, args[i]);
            } else {
                std.debug.print("{s}Error:{s} --fail-below requires a percentage value\n", .{ YELLOW, RESET });
                return error.MissingArgument;
            }
        } else if (std.mem.startsWith(u8, arg, "--")) {
            std.debug.print("{s}Error:{s} Unknown flag: {s}\n", .{ YELLOW, RESET, arg });
            return error.UnknownFlag;
        } else {
            specs_dir = arg;
        }
    }

    std.debug.print("{s}Scanning {s} for .tri files...{s}\n\n", .{ YELLOW, specs_dir, RESET });

    const report = try audit.auditSpecs(allocator, specs_dir);
    audit.printAuditReport(report);

    // Exit code based on coverage threshold
    if (fail_below > 0.0 and report.spec_coverage < fail_below) {
        std.debug.print("\n{s}❌ FAILED: Coverage {d:.1}% < threshold {d:.1}%{s}\n", .{
            YELLOW, report.spec_coverage, fail_below, RESET,
        });
        return error.LowCoverage;
    }

    // Default: warn if below 50%
    if (fail_below == 0.0 and report.spec_coverage < 50.0) {
        std.debug.print("\n{s}⚠️  WARNING: Only {d:.1}% of behaviors have @spec annotation{s}\n", .{
            YELLOW, report.spec_coverage, RESET,
        });
    }
}

/// Run `tri spec apply` — auto-apply annotations
fn runSpecApply(allocator: std.mem.Allocator, args: []const []const u8) !void {
    try apply.runSpecApply(allocator, args);
}

fn printSpecHelp() void {
    std.debug.print("\n{s}TRI SPEC COMMAND — TRI-27 Idiom 11 Tools{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Usage:{s} tri spec <subcommand> [args]\n\n", .{ YELLOW, RESET });
    std.debug.print("{s}Subcommands:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}audit{d}[dir]     Scan .tri files, report annotation coverage\n", .{ RESET, 15 });
    std.debug.print("  {s}apply{d}[files]   Auto-apply annotations\n", .{ RESET, 15 });
    std.debug.print("  {s}help{d}          Show this help\n", .{ RESET, 15 });
    std.debug.print("\n{s}Audit Options:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}--fail-below N{s}  Exit with error if coverage < N%% (for CI)\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Examples:{s}\n", .{ YELLOW, RESET });
    std.debug.print("  tri spec audit              # Scan specs/ directory\n", .{});
    std.debug.print("  tri spec audit specs/fpga    # Scan specific directory\n", .{});
    std.debug.print("  tri spec audit --fail-below 80  # CI: fail if coverage < 80%%\n", .{});
    std.debug.print("\n{s}Annotations (TRI-27 Idiom 11):{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}@spec{s}       — Function/behavior specification name\n", .{ GREEN, RESET });
    std.debug.print("  {s}@require{s}    — Preconditions (must hold before call)\n", .{ GREEN, RESET });
    std.debug.print("  {s}@ensure{s}     — Postconditions (guaranteed after call)\n", .{ GREEN, RESET });
    std.debug.print("  {s}@example{s}    — Concrete test case for auto-test generation\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});
}

// Tests
test "spec command - audit help" {
    const allocator = std.testing.allocator;
    // Just verify it doesn't crash
    try runSpecCommand(allocator, &[_][]const u8{});
}
