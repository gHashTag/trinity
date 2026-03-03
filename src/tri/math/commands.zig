// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// Main command dispatcher for tri math commands
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const parent_mod = @import("mod.zig");
const format = @import("format.zig");
const constants = @import("constants.zig");
const eval = @import("eval.zig");
const compute = @import("compute.zig");
const bench_mod = @import("bench.zig");
const identities_mod = @import("identities.zig");
const gematria_math = @import("gematria.zig");
const sacred_formula = @import("sacred_formula.zig");
const blind_spots_mod = @import("blind_spots.zig"); // TODO: Fix Zig 0.15 compatibility

// Direct writer that works with the compute/eval modules
// This works because it implements the Writer interface without std.io
const DirectWriter = struct {
    context: void = {},

    pub const Error = error{OutputFailed};
    pub const Child = DirectWriter;

    // Custom Writer type that matches what's expected
    pub const Writer = struct {
        context: *DirectWriter,

        pub fn write(_: Writer, data: []const u8) DirectWriter.Error!usize {
            for (data) |c| std.debug.print("{c}", .{c});
            return data.len;
        }

        pub fn writeAll(self: Writer, s: []const u8) !void {
            _ = try self.write(s);
        }

        pub fn print(_: Writer, comptime fmt: []const u8, args: anytype) !void {
            std.debug.print(fmt, args);
        }
    };

    pub fn writer(self: *DirectWriter) Writer {
        return .{ .context = self };
    }

    pub fn writeAll(_: *DirectWriter, s: []const u8) !void {
        std.debug.print("{s}", .{s});
    }

    pub fn print(_: *DirectWriter, comptime fmt: []const u8, args: anytype) !void {
        std.debug.print(fmt, args);
    }
};

// Get a writer that outputs to stdout (via debug.print to stderr for now)
fn getWriter() DirectWriter {
    return .{};
}

pub fn runMathCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showMathHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "constants")) {
        try runConstantsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "eval")) {
        try runEvalCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "compute")) {
        try runComputeCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "bench")) {
        try runBenchCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "identities")) {
        try runIdentitiesCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "gematria") or std.mem.eql(u8, subcommand, "gem")) {
        try gematria_math.runGematriaCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "formula")) {
        try runFormulaCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "sacred")) {
        try runSacredCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "blindspots") or std.mem.eql(u8, subcommand, "blind")) {
        try runBlindSpotsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showMathHelp();
    } else {
        std.debug.print("Unknown subcommand: {s}\n\n", .{subcommand});
        try showMathHelp();
    }
}

pub fn runConstantsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    var wr = DirectWriter{};
    try constants.printAllConstants(wr.writer());
}

pub fn runEvalCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri math eval [phi|fib|lucas] <n>\n", .{});
        return;
    }

    const seq_type = args[0];
    const n_str = args[1];
    const n = try std.fmt.parseInt(usize, n_str, 10);

    var wr = DirectWriter{};

    if (std.mem.eql(u8, seq_type, "phi")) {
        try eval.printPhiPower(wr.writer(), n);
    } else if (std.mem.eql(u8, seq_type, "fib")) {
        try eval.printFibonacci(wr.writer(), allocator, n);
    } else if (std.mem.eql(u8, seq_type, "lucas")) {
        try eval.printLucas(wr.writer(), allocator, n);
    } else {
        std.debug.print("Unknown sequence type: {s}\n", .{seq_type});
    }
}

pub fn runComputeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math compute [spiral|verify|compare] [args...]\n", .{});
        return;
    }

    const operation = args[0];
    const op_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, operation, "spiral")) {
        try runSpiralCommand(allocator, op_args);
    } else if (std.mem.eql(u8, operation, "verify")) {
        try runVerifyCommand(allocator, op_args);
    } else if (std.mem.eql(u8, operation, "compare")) {
        try runCompareCommand(allocator, op_args);
    } else {
        std.debug.print("Unknown operation: {s}\n", .{operation});
    }
}

pub fn runPhiCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len == 0) {
        std.debug.print("Usage: tri phi <n>\n", .{});
        return;
    }
    const n = try std.fmt.parseInt(usize, args[0], 10);
    var wr = DirectWriter{};
    try eval.printPhiPower(wr.writer(), n);
}

pub fn runFibCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri fib <n>\n", .{});
        return;
    }
    const n = try std.fmt.parseInt(usize, args[0], 10);
    var wr = DirectWriter{};
    try eval.printFibonacci(wr.writer(), allocator, n);
}

pub fn runLucasCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri lucas <n>\n", .{});
        return;
    }
    const n = try std.fmt.parseInt(usize, args[0], 10);
    var wr = DirectWriter{};
    try eval.printLucas(wr.writer(), allocator, n);
}

pub fn runSpiralCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    var n: u32 = 12;
    var show_plot = false;

    if (args.len > 0) {
        n = try std.fmt.parseInt(u32, args[0], 10);
    }

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--plot") or std.mem.eql(u8, arg, "-p")) {
            show_plot = true;
        }
    }

    var wr = DirectWriter{};
    try compute.printSpiral(wr.writer(), n);
    if (show_plot) {
        try wr.writeAll("\n");
        try format.plotSpiralAscii(wr.writer(), n + 1);
    }
}

pub fn runVerifyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    var wr = DirectWriter{};
    try compute.printVerification(wr.writer());
}

pub fn runCompareCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    var max_n: usize = 20;

    if (args.len > 0) {
        max_n = try std.fmt.parseInt(usize, args[0], 10);
    }

    var wr = DirectWriter{};
    try compute.printCompare(wr.writer(), max_n);
}

pub fn runBenchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var wr = DirectWriter{};
    try bench_mod.printBenchmarkResults(wr.writer(), allocator);
}

pub fn runIdentitiesCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    var wr = DirectWriter{};
    try identities_mod.printAllIdentities(wr.writer());
}

pub fn runGematriaTopLevel(allocator: std.mem.Allocator, args: []const []const u8) !void {
    try gematria_math.runGematriaCommand(allocator, args);
}

pub fn runFormulaCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len == 0) {
        std.debug.print("Usage: tri formula <number>\n", .{});
        std.debug.print("  Decompose a number using Sacred Formula V = n × 3^k × π^m × φ^p × e^q\n", .{});
        return;
    }
    const value = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Error: '{s}' is not a valid number\n", .{args[0]});
        return;
    };
    const fit = sacred_formula.fitSacredFormula(value);
    sacred_formula.printSacredFormulaFit(fit, value);
}

pub fn runSacredCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len > 0 and std.mem.eql(u8, args[0], "search")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri sacred search <value>\n", .{});
            std.debug.print("  Brute-force search for sacred formula fit (20,412 combos)\n", .{});
            return;
        }
        const value = std.fmt.parseFloat(f64, args[1]) catch {
            std.debug.print("Error: '{s}' is not a valid number\n", .{args[1]});
            return;
        };
        const fit = sacred_formula.fitSacredFormula(value);
        sacred_formula.printSacredFormulaFit(fit, value);
    } else if (args.len > 0 and std.mem.eql(u8, args[0], "deep")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri sacred deep <value>\n", .{});
            std.debug.print("  Extended search with wider bounds (123,201 combos, ~6x)\n", .{});
            std.debug.print("  Allows positive pi powers — finds dramatically better fits\n", .{});
            return;
        }
        const value = std.fmt.parseFloat(f64, args[1]) catch {
            std.debug.print("Error: '{s}' is not a valid number\n", .{args[1]});
            return;
        };
        // Run both standard and extended, show comparison
        const std_fit = sacred_formula.fitSacredFormula(value);
        const ext_fit = sacred_formula.fitSacredFormulaExtended(value);

        const GOLDEN = "\x1b[33m";
        const CYAN = "\x1b[36m";
        const WHITE = "\x1b[97m";
        const GRAY = "\x1b[90m";
        const GREEN = "\x1b[32m";
        const RESET = "\x1b[0m";

        std.debug.print("\n{s}Sacred Formula DEEP Search{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}================================{s}\n", .{ GRAY, RESET });
        std.debug.print("  {s}Target:{s}  {s}{d:.6}{s}\n\n", .{ GRAY, RESET, WHITE, value, RESET });

        // Standard result
        var buf1: [128]u8 = undefined;
        const f1 = sacred_formula.formatFormulaString(&buf1, std_fit);
        const c1 = if (std_fit.error_pct < 0.01) GREEN else WHITE;
        std.debug.print("  {s}Standard{s} (20,412 combos):\n", .{ CYAN, RESET });
        std.debug.print("    V = {s}{s}{s}  = {s}{d:.6}{s}  err={s}{d:.4}%{s}\n\n", .{ GOLDEN, f1, RESET, WHITE, std_fit.computed, RESET, c1, std_fit.error_pct, RESET });

        // Extended result
        var buf2: [128]u8 = undefined;
        const f2 = sacred_formula.formatFormulaString(&buf2, ext_fit);
        const c2 = if (ext_fit.error_pct < 0.01) GREEN else WHITE;
        std.debug.print("  {s}Extended{s} (123,201 combos):\n", .{ CYAN, RESET });
        std.debug.print("    V = {s}{s}{s}  = {s}{d:.6}{s}  err={s}{d:.4}%{s}\n", .{ GOLDEN, f2, RESET, WHITE, ext_fit.computed, RESET, c2, ext_fit.error_pct, RESET });

        if (ext_fit.error_pct < std_fit.error_pct * 0.5) {
            const improvement = std_fit.error_pct / ext_fit.error_pct;
            std.debug.print("\n  {s}>>> Extended is {d:.1}x better! <<<{s}\n", .{ GREEN, improvement, RESET });
        }
        std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
    } else {
        sacred_formula.printSacredConstantsTable();
    }
}

pub fn runBlindSpotsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    const report = try blind_spots_mod.generateDiscoveryReport(allocator);
    defer allocator.free(report);
    std.debug.print("{s}\n", .{report});
}

fn showMathHelp() !void {
    var wr = DirectWriter{};
    try wr.writeAll("+====================================================================+\n");
    try wr.writeAll("|                    SACRED MATHEMATICS v4.0                          |\n");
    try wr.writeAll("|            V = n × 3^k × π^m × φ^p × e^q                       |\n");
    try wr.writeAll("|                phi^2 + 1/phi^2 = 3 = TRINITY                       |\n");
    try wr.writeAll("+====================================================================+\n");
    try wr.writeAll("\n");
    try wr.writeAll("  SUBCOMMANDS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri math constants              Show all sacred constants\n");
    try wr.writeAll("  tri math eval phi <n>           Compute phi^n\n");
    try wr.writeAll("  tri math eval fib <n>           Fibonacci F(n) (BigInt)\n");
    try wr.writeAll("  tri math eval lucas <n>         Lucas L(n)\n");
    try wr.writeAll("  tri math compute spiral <n>     phi-spiral + ASCII plot\n");
    try wr.writeAll("  tri math compute verify         Verify all sacred identities\n");
    try wr.writeAll("  tri math compute compare <n>    Compare sequences\n");
    try wr.writeAll("  tri math bench                  Run benchmarks\n");
    try wr.writeAll("  tri math identities             Show phi-identities\n");
    try wr.writeAll("  tri math gematria <number|text> Coptic gematria + sacred formula\n");
    try wr.writeAll("  tri math formula <value>        Sacred formula decomposition\n");
    try wr.writeAll("  tri math sacred                 Show 60 constants + 15 predictions\n");
    try wr.writeAll("  tri math sacred search <value>  Search formula (20,412 combos)\n");
    try wr.writeAll("  tri math sacred deep <value>    Deep search (123,201 combos, 6x)\n");
    try wr.writeAll("\n");
    try wr.writeAll("  ALIASES (Quick Access)\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri constants      Same as 'tri math constants'\n");
    try wr.writeAll("  tri phi <n>        Same as 'tri math eval phi <n>'\n");
    try wr.writeAll("  tri fib <n>        Same as 'tri math eval fib <n>'\n");
    try wr.writeAll("  tri lucas <n>      Same as 'tri math eval lucas <n>'\n");
    try wr.writeAll("  tri spiral <n>     Same as 'tri math compute spiral <n>'\n");
    try wr.writeAll("  tri verify         Same as 'tri math compute verify'\n");
    try wr.writeAll("  tri gematria <n>   Same as 'tri math gematria <n>'\n");
    try wr.writeAll("  tri formula <v>    Same as 'tri math formula <v>'\n");
    try wr.writeAll("  tri sacred         Same as 'tri math sacred'\n");
    try wr.writeAll("  tri blindspots     Same as 'tri math blindspots'\n");
    try wr.writeAll("\n");
    try wr.writeAll("  FLAGS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  --plot             Show ASCII spiral plot\n");
    try wr.writeAll("\n");
    try wr.writeAll("+====================================================================+\n");
}
