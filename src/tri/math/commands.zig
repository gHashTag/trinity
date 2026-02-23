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

fn showMathHelp() !void {
    var wr = DirectWriter{};
    try wr.writeAll("+====================================================================+\n");
    try wr.writeAll("|                    SACRED MATHEMATICS v2.0                          |\n");
    try wr.writeAll("|                    phi^2 + 1/phi^2 = 3 = TRINITY                   |\n");
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
    try wr.writeAll("\n");
    try wr.writeAll("  ALIASES (Quick Access)\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri constants      Same as 'tri math constants'\n");
    try wr.writeAll("  tri phi <n>        Same as 'tri math eval phi <n>'\n");
    try wr.writeAll("  tri fib <n>        Same as 'tri math eval fib <n>'\n");
    try wr.writeAll("  tri lucas <n>      Same as 'tri math eval lucas <n>'\n");
    try wr.writeAll("  tri spiral <n>     Same as 'tri math compute spiral <n>'\n");
    try wr.writeAll("  tri verify         Same as 'tri math compute verify'\n");
    try wr.writeAll("\n");
    try wr.writeAll("  FLAGS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  --plot             Show ASCII spiral plot\n");
    try wr.writeAll("\n");
    try wr.writeAll("+====================================================================+\n");
}
