// @origin(manual) @regen(pending)
// Performance monitoring for cell commands
const std = @import("std");
const colors = @import("tri_colors.zig");

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const WHITE = colors.WHITE;
const GOLDEN = colors.GOLDEN;

pub const TimingPhase = struct {
    name: []const u8,
    duration_ns: u64,
    memory_bytes: usize,

    pub fn formatMs(self: TimingPhase) f64 {
        return @as(f64, @floatFromInt(self.duration_ns)) / 1_000_000.0;
    }
};

pub const PerformanceReport = struct {
    command: []const u8,
    total_ns: u64,
    phases: []const TimingPhase,
    peak_memory_bytes: usize,
    cells_processed: usize,

    pub fn printReport(self: PerformanceReport) void {
        const total_ms = @as(f64, @floatFromInt(self.total_ns)) / 1_000_000.0;

        std.debug.print("\n{s}═══ PERFORMANCE REPORT: {s} ═══{s}\n\n", .{ GOLDEN, self.command, RESET });
        std.debug.print("  {s}Total time:{s}     {d:.2} ms\n", .{ CYAN, RESET, total_ms });
        std.debug.print("  {s}Cells processed:{s} {d}\n", .{ CYAN, RESET, self.cells_processed });
        std.debug.print("  {s}Peak memory:{s}    ", .{ CYAN, RESET });
        if (self.peak_memory_bytes < 1024) {
            std.debug.print("{d} B\n", .{self.peak_memory_bytes});
        } else if (self.peak_memory_bytes < 1024 * 1024) {
            std.debug.print("{d:.2} KB\n", .{@as(f64, @floatFromInt(self.peak_memory_bytes)) / 1024.0});
        } else {
            std.debug.print("{d:.2} MB\n", .{@as(f64, @floatFromInt(self.peak_memory_bytes)) / (1024.0 * 1024.0)});
        }

        std.debug.print("\n  {s}Phase breakdown:{s}\n", .{ CYAN, RESET });
        for (self.phases) |phase| {
            const pct = if (self.total_ns > 0)
                @as(f64, @floatFromInt(phase.duration_ns)) / @as(f64, @floatFromInt(self.total_ns)) * 100.0
            else
                0.0;
            std.debug.print("    {s}{s:<16}{s} {d:>8.2} ms ({d:>5.1}%)", .{ WHITE, phase.name, RESET, phase.formatMs(), pct });
            if (phase.memory_bytes > 0) {
                if (phase.memory_bytes < 1024 * 1024) {
                    std.debug.print("  [{d:.1} KB]", .{@as(f64, @floatFromInt(phase.memory_bytes)) / 1024.0});
                } else {
                    std.debug.print("  [{d:.2} MB]", .{@as(f64, @floatFromInt(phase.memory_bytes)) / (1024.0 * 1024.0)});
                }
            }
            std.debug.print("{s}\n", .{""});
        }

        const verdict = if (total_ms < 100) "🚀 EXCELLENT (<100ms)" else if (total_ms < 500) "✓ GOOD (<500ms)" else if (total_ms < 1000) "⚠ OK (<1s)" else "🐌 SLOW (>1s)";
        const vcolor = if (total_ms < 100) GREEN else if (total_ms < 500) GREEN else if (total_ms < 1000) YELLOW else RED;
        std.debug.print("\n  {s}Verdict:{s} {s}{s}{s}\n\n", .{ CYAN, RESET, vcolor, verdict, RESET });
    }
};

pub const PerfFlags = struct {
    benchmark: bool = false,
    profile: bool = false,

    pub fn parse(args: []const []const u8) PerfFlags {
        var flags: PerfFlags = .{};
        for (args) |arg| {
            if (std.mem.eql(u8, arg, "--benchmark")) flags.benchmark = true;
            if (std.mem.eql(u8, arg, "--profile")) flags.profile = true;
        }
        return flags;
    }
};
