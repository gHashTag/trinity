// @origin(spec:tri_sacred_commands.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════
// TRI SACRED COMMANDS — Benchmark & Synthesis Report CLI
// ═════════════════════════════════════════════════════════════════════
//
// Sacred Trinity FPGA benchmarking and synthesis reporting:
// - Phase 6.3: sacred_bench — Run iverilog benchmarks
// - Phase 6.4: sacred_synth_report — Parse Yosys synthesis JSON
//
// φ² + 1/φ² = 3 | TRINITY
// ═════════════════════════════════════════════════════════════════════════

const std = @import("std");

// =============================================================================
// PUBLIC FUNCTIONS (exported for main.zig)
// =============================================================================

/// Run Sacred ALU benchmark (Phase 6.3)
/// Usage: tri sacred bench [--n=N] [--mode=ALL|gf16_add|...] [--output=csv|human]
pub fn runSacredBenchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    @import("sacred_bench").runSacredBenchCommand(allocator, args);
}

/// Parse Yosys synthesis JSON and display resource statistics (Phase 6.4)
/// Usage: tri sacred synth-report [--input=PATH] [--output=human|csv|json]
pub fn runSacredSynthReportCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    @import("sacred_synth_report").runSacredSynthReportCommand(allocator, args);
}

// =============================================================================
// ERROR SETS
// =============================================================================

pub const SacredCommandError = error{
    InvalidArguments,
};
