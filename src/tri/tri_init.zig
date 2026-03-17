// ═══════════════════════════════════════════════════════════════════════════════
// TRI INIT — Fork & Contribution Scaffolding
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands: tri init | tri init --cell <name> [--kind tool|agent|backend|frontend]
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const YELLOW = colors.YELLOW;
const WHITE = colors.WHITE;
const GOLDEN = colors.GOLDEN;

pub fn runInitCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Check for --cell flag
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--cell")) {
            if (i + 1 < args.len) {
                // Forward to tri cell init with remaining args
                const cell = @import("cytoplasm.zig");
                var cell_args = std.ArrayListUnmanaged([]const u8){};
                defer cell_args.deinit(allocator);
                try cell_args.append(allocator, "init");
                for (args[i + 1 ..]) |arg| {
                    try cell_args.append(allocator, arg);
                }
                return cell.runCellCommand(allocator, cell_args.items);
            }
        }
    }

    // Default: show fork instructions
    printForkGuide();
}

fn printForkGuide() void {
    std.debug.print("\n{s}🐝 TRINITY — Getting Started{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n  Trinity is a modular AI system with a core + honeycomb cells architecture.\n", .{});
    std.debug.print("\n  {s}Fork & Clone:{s}\n", .{ CYAN, RESET });
    std.debug.print("    1. Fork gHashTag/trinity on GitHub\n", .{});
    std.debug.print("    2. git clone <your-fork-url> && cd trinity\n", .{});
    std.debug.print("    3. zig build                          # Build all binaries\n", .{});
    std.debug.print("    4. tri test                            # Run tests\n", .{});
    std.debug.print("\n  {s}Create a New Cell:{s}\n", .{ CYAN, RESET });
    std.debug.print("    tri cell init my-feature --kind tool   # Scaffold cell + tests\n", .{});
    std.debug.print("    # ... develop ...\n", .{});
    std.debug.print("    tri cell check                         # Validate manifest\n", .{});
    std.debug.print("    tri git commit \"feat(my-feature): add module\"\n", .{});
    std.debug.print("    git push && gh pr create               # PR to upstream\n", .{});
    std.debug.print("\n  {s}Project Structure:{s}\n", .{ CYAN, RESET });
    std.debug.print("    src/          Core + backend/agent/tool cells\n", .{});
    std.debug.print("    apps/         Frontend cells (SwiftUI, etc.)\n", .{});
    std.debug.print("    tools/        Tool cells (MCP, etc.)\n", .{});
    std.debug.print("    fpga/         FPGA cells\n", .{});
    std.debug.print("    specs/        .tri specifications\n", .{});
    std.debug.print("    data/cells/   Cell registry\n", .{});
    std.debug.print("\n  {s}Commands:{s}\n", .{ CYAN, RESET });
    std.debug.print("    tri cell list                # List all cells\n", .{});
    std.debug.print("    tri cell info <id>           # Cell details\n", .{});
    std.debug.print("    tri cell init <name>         # Create new cell\n", .{});
    std.debug.print("    tri cell check               # Validate all\n\n", .{});
}
