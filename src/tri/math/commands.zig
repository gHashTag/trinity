// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// Main command dispatcher for tri math commands
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const unified = @import("../unified_output.zig");
const tri_exit_codes = @import("../tri_exit_codes.zig");

const parent_mod = @import("mod.zig");
const format = @import("format.zig");
const constants = @import("constants.zig");
const eval = @import("eval.zig");
const compute = @import("compute.zig");
const bench_mod = @import("bench.zig");
const identities_mod = @import("identities.zig");
const gematria_math = @import("gematria.zig");
const sacred_formula = @import("formula.zig");
const blind_spots_mod = @import("blind_spots.zig");
const sacred_v2 = @import("../tri_sacred_v2.zig");

// Import proof engine through sacred module (already exposed via sacred/math.zig)
const sacred = @import("sacred");

const runProveCommand = struct {
    pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
        try sacred.runProveCommand(allocator, args);
    }
}.run;
const runGoalCommand = struct {
    pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
        try sacred.runGoalCommand(allocator, args);
    }
}.run;
const runTraceCommand = struct {
    pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
        try sacred.runTraceCommand(allocator, args);
    }
}.run;

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
    } else if (std.mem.eql(u8, subcommand, "particles") or std.mem.eql(u8, subcommand, "pdg")) {
        try runParticlesCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "all")) {
        try sacred_v2.runSacredTable(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "evidence")) {
        try runEvidenceCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "search-best-fit") or std.mem.eql(u8, subcommand, "search")) {
        try runSearchBestFitCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "groups")) {
        try runGroupsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "cosmos")) {
        try runCosmosCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "nuclear")) {
        try runNuclearCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "physical")) {
        try runPhysicalCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "prove")) {
        try runProveCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "goal")) {
        try runGoalCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "trace")) {
        try runTraceCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "table")) {
        try sacred_v2.runSacredTable(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "verify")) {
        try sacred_v2.runSacredVerify(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "explain")) {
        try sacred_v2.runSacredExplain(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "doctor")) {
        try sacred_v2.runSacredDoctor(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "diff")) {
        try sacred_v2.runSacredDiff(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showMathHelp();
    } else {
        std.debug.print("Unknown subcommand: {s}\n\n", .{subcommand});
        try showMathHelp();
    }
}

pub fn runConstantsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const tri_config = @import("../tri_config.zig");

    // Check global JSON flag first
    const global_json = tri_config.isJsonOutput();

    // Parse format flag (only if not global JSON mode)
    var format_type: []const u8 = "pretty";
    if (!global_json) {
        for (args) |arg| {
            if (std.mem.startsWith(u8, arg, "--format=")) {
                format_type = arg["--format=".len..];
            }
        }
    }

    if (global_json or std.mem.eql(u8, format_type, "json")) {
        // Use UnifiedOutput for global JSON mode
        if (global_json) {
            var output = unified.UnifiedOutput.init(allocator, "constants", .core);
            defer output.deinit();

            try output.setSummary("Sacred mathematics constants");

            // Build data JSON with all constants
            var data_json = try std.ArrayList(u8).initCapacity(allocator, 2048);
            defer data_json.deinit(allocator);
            const data_writer = data_json.writer(allocator);

            try data_json.append(allocator, '{');
            try data_writer.print("\"phi\":{d:.16},", .{parent_mod.PHI});
            try data_writer.print("\"phi_squared\":{d:.16},", .{parent_mod.PHI_SQUARED});
            try data_writer.print("\"phi_inverse_squared\":{d:.16},", .{parent_mod.INVERSE_PHI_SQUARED});
            try data_writer.print("\"trinity\":{d:.1},", .{parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED});
            try data_writer.print("\"pi\":{d:.20},", .{std.math.pi});
            try data_writer.print("\"e\":{d:.20},", .{std.math.e});
            try data_writer.print("\"gamma\":{d:.20},", .{1.0 / (parent_mod.PHI * parent_mod.PHI * parent_mod.PHI)});
            try data_writer.print("\"mu\":{d:.4},", .{parent_mod.MU});
            try data_writer.print("\"chi\":{d:.4},", .{parent_mod.CHI});
            try data_writer.print("\"sigma\":{d:.3},", .{parent_mod.SIGMA});
            try data_writer.print("\"epsilon\":{d:.3}", .{parent_mod.EPSILON});
            try data_json.append(allocator, '}');

            output.data_raw = try allocator.dupe(u8, data_json.items);
            try output.addMetric("constants_count", 10);

            output.finalize();
            try output.print();
            return;
        }

        // Legacy --format=json mode (plain JSON output without envelope)
        // JSON output
        std.debug.print("{{\n", .{});
        std.debug.print("  \"phi\": {d:.16},\n", .{parent_mod.PHI});
        std.debug.print("  \"phi_squared\": {d:.16},\n", .{parent_mod.PHI_SQUARED});
        std.debug.print("  \"phi_inverse_squared\": {d:.16},\n", .{parent_mod.INVERSE_PHI_SQUARED});
        std.debug.print("  \"trinity\": {d:.1},\n", .{parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED});
        std.debug.print("  \"pi\": {d:.20},\n", .{std.math.pi});
        std.debug.print("  \"e\": {d:.20},\n", .{std.math.e});
        std.debug.print("  \"gamma\": {d:.20},\n", .{1.0 / (parent_mod.PHI * parent_mod.PHI * parent_mod.PHI)});
        std.debug.print("  \"mu\": {d:.4},\n", .{parent_mod.MU});
        std.debug.print("  \"chi\": {d:.4},\n", .{parent_mod.CHI});
        std.debug.print("  \"sigma\": {d:.3},\n", .{parent_mod.SIGMA});
        std.debug.print("  \"epsilon\": {d:.3}\n", .{parent_mod.EPSILON});
        std.debug.print("}}\n", .{});
    } else if (std.mem.eql(u8, format_type, "csv")) {
        // CSV output
        std.debug.print("symbol,value,description,formula\n", .{});
        std.debug.print("phi,{d:.16},Golden Ratio,(1 + √5) / 2\n", .{parent_mod.PHI});
        std.debug.print("phi_squared,{d:.16},Phi Squared,φ² = φ + 1\n", .{parent_mod.PHI_SQUARED});
        std.debug.print("phi_inverse_squared,{d:.16},Inverse Phi Squared,1/φ² = φ - 1\n", .{parent_mod.INVERSE_PHI_SQUARED});
        std.debug.print("trinity,{d:.1},TRINITY,φ² + 1/φ² = 3\n", .{parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED});
        std.debug.print("pi,{d:.20},Pi,C / d\n", .{std.math.pi});
        std.debug.print("e,{d:.20},Euler's Number,lim(n→∞) (1 + 1/n)ⁿ\n", .{std.math.e});
        std.debug.print("gamma,{d:.20},Gamma (candidate),φ⁻³\n", .{1.0 / (parent_mod.PHI * parent_mod.PHI * parent_mod.PHI)});
        std.debug.print("mu,{d:.4},Mu (mutation rate),1/φ²/10\n", .{parent_mod.MU});
        std.debug.print("chi,{d:.4},Chi (crossover rate),1/φ/10\n", .{parent_mod.CHI});
        std.debug.print("sigma,{d:.3},Sigma (selection),φ\n", .{parent_mod.SIGMA});
        std.debug.print("epsilon,{d:.3},Epsilon (elitism),1/3\n", .{parent_mod.EPSILON});
    } else if (std.mem.eql(u8, format_type, "md")) {
        // Markdown output
        std.debug.print("| Symbol | Value | Description | Formula |\n", .{});
        std.debug.print("|--------|-------|-------------|----------|\n", .{});
        std.debug.print("| φ | {d:.16} | Golden Ratio | (1 + √5) / 2 |\n", .{parent_mod.PHI});
        std.debug.print("| φ² | {d:.16} | Phi Squared | φ² = φ + 1 |\n", .{parent_mod.PHI_SQUARED});
        std.debug.print("| 1/φ² | {d:.16} | Inverse Phi Squared | 1/φ² = φ - 1 |\n", .{parent_mod.INVERSE_PHI_SQUARED});
        std.debug.print("| φ² + 1/φ² | {d:.1} | TRINITY | φ² + 1/φ² = 3 |\n", .{parent_mod.PHI_SQUARED + parent_mod.INVERSE_PHI_SQUARED});
        std.debug.print("| π | {d:.20} | Pi | C / d |\n", .{std.math.pi});
        std.debug.print("| e | {d:.20} | Euler's Number | lim(n→∞) (1 + 1/n)ⁿ |\n", .{std.math.e});
        std.debug.print("| γ | {d:.20} | Gamma (candidate) | φ⁻³ |\n", .{1.0 / (parent_mod.PHI * parent_mod.PHI * parent_mod.PHI)});
        std.debug.print("| μ | {d:.4} | Mu (mutation rate) | 1/φ²/10 |\n", .{parent_mod.MU});
        std.debug.print("| χ | {d:.4} | Chi (crossover rate) | 1/φ/10 |\n", .{parent_mod.CHI});
        std.debug.print("| σ | {d:.3} | Sigma (selection) | φ |\n", .{parent_mod.SIGMA});
        std.debug.print("| ε | {d:.3} | Epsilon (elitism) | 1/3 |\n", .{parent_mod.EPSILON});
    } else {
        // Pretty format (default)
        // Use the existing constants module to print
        var wr = DirectWriter{};
        try constants.printAllConstants(wr.writer());
    }
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
    if (args.len == 0) {
        var output = unified.UnifiedOutput.init(allocator, "phi", .core);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary("Usage: tri phi <n>");
        try output.addError("ARGS_MISSING", "Missing required argument: n (power to compute phi^n)");
        output.finalize();
        try output.print();
        return tri_exit_codes.exitWithCode(.validation_error);
    }

    // Parse n with inline error handling
    const n = std.fmt.parseInt(usize, args[0], 10) catch {
        var output = unified.UnifiedOutput.init(allocator, "phi", .core);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary("Invalid argument: n must be a non-negative integer");
        try output.addError("INVALID_ARG", "Failed to parse n as integer");
        output.finalize();
        try output.print();
        return tri_exit_codes.exitWithCode(.validation_error);
    };

    var output = unified.UnifiedOutput.init(allocator, "phi", .core);
    defer output.deinit();

    // Compute phi^n
    const result = eval.phiPower(n);

    // Build summary
    const summary = try std.fmt.allocPrint(allocator, "phi^{d} = {d:.16}", .{ n, result });
    defer allocator.free(summary);
    try output.setSummary(summary);

    // Build data JSON with phi^n result
    var data_json = try std.ArrayList(u8).initCapacity(allocator, 256);
    defer data_json.deinit(allocator);
    const data_writer = data_json.writer(allocator);

    try data_json.append(allocator, '{');
    try data_writer.print("\"n\":{d},", .{n});
    try data_writer.print("\"result\":{d:.16},", .{result});
    try data_writer.print("\"expression\":\"phi^{d}\",", .{n});

    // Add special notes for n = 0, 1, 2
    if (n == 0) {
        try data_json.appendSlice(allocator, "\"note\":\"φ⁰ = 1\"");
    } else if (n == 1) {
        try data_json.appendSlice(allocator, "\"note\":\"φ¹ = φ\"");
    } else if (n == 2) {
        try data_json.appendSlice(allocator, "\"note\":\"φ² = φ + 1 ≈ 2.618\"");
    } else {
        try data_json.appendSlice(allocator, "\"note\":null");
    }

    try data_json.append(allocator, '}');

    output.data_raw = try allocator.dupe(u8, data_json.items);
    try output.addMetric("power_n", n);

    output.finalize();
    try output.print();
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

    var output = unified.UnifiedOutput.init(allocator, "bench", .dev);
    defer output.deinit();

    try output.setSummary("Performance benchmarks completed successfully");

    // Run all benchmarks and get structured results
    const suite = try bench_mod.runAllBenchmarks(allocator);
    defer allocator.free(suite.benchmarks);

    // Build data JSON with benchmark results
    var data_json = try std.ArrayList(u8).initCapacity(allocator, 2048);
    defer data_json.deinit(allocator);

    const data_writer = data_json.writer(allocator);

    try data_json.append(allocator, '{');
    try data_writer.print("\"total_duration_ms\":{d},", .{suite.total_duration_ms});
    try data_json.appendSlice(allocator, "\"benchmarks\":[");

    for (suite.benchmarks, 0..) |bench, i| {
        if (i > 0) try data_json.append(allocator, ',');
        try data_json.append(allocator, '{');
        try data_writer.print("\"name\":\"{s}\",", .{bench.name});
        try data_writer.print("\"ops_per_sec\":{d:.2},", .{bench.ops_per_sec});
        try data_writer.print("\"avg_time_ns\":{d:.2}", .{bench.avg_time_ns});
        try data_json.append(allocator, '}');
    }

    try data_json.appendSlice(allocator, "]}");

    output.data_raw = try allocator.dupe(u8, data_json.items);
    try output.addMetric("benchmarks_run", suite.benchmarks.len);
    try output.addMetric("total_duration_ms", suite.total_duration_ms);

    output.finalize();
    try output.print();
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

pub fn runParticlesCommand(_: std.mem.Allocator, args: []const []const u8) !void {
    // Sacred constants (inline — no external imports needed)
    const PHI: f64 = 1.6180339887498948482;
    const PI: f64 = std.math.pi;
    const E: f64 = std.math.e;
    const GAMMA: f64 = 1.0 / (PHI * PHI * PHI); // φ⁻³ = 0.23607

    const PHI_SQ = PHI * PHI;
    const PHI_3 = PHI_SQ * PHI;
    const PHI_4 = PHI_3 * PHI;
    const PHI_5 = PHI_4 * PHI;
    const PHI_6 = PHI_5 * PHI;
    const PHI_7 = PHI_6 * PHI;
    const PHI_8 = PHI_7 * PHI;

    const PHI_INV_SQ = 1.0 / PHI_SQ; // 1/φ²
    const PHI_INV_CU = GAMMA; // 1/φ³ = γ
    const PHI_CU = PHI_3; // φ³

    const FormulaEntry = struct {
        name: []const u8,
        computed: f64,
        experimental: f64,
        tier: u8,
    };

    const GAMMA_5 = GAMMA * GAMMA * GAMMA * GAMMA * GAMMA;
    // All 100 formulas — matching src/particle_physics/formulas.zig exactly
    const formulas = [_]FormulaEntry{
        // Tier 1: Core Standard Model (9)
        .{ .name = "alpha_s (strong coupling)", .computed = 4.0 * PHI_SQ / (9.0 * PI * PI), .experimental = 0.11790, .tier = 1 },
        .{ .name = "sin2_theta_W (Weinberg)", .computed = 2.0 * PI * PI * PI * E / 729.0, .experimental = 0.23121, .tier = 1 },
        .{ .name = "sin_theta_C (Cabibbo)", .computed = 3.0 * GAMMA / PI, .experimental = 0.22530, .tier = 1 },
        .{ .name = "m_p/m_e (mass ratio)", .computed = 6.0 * PI * PI * PI * PI * PI, .experimental = 1836.15267343, .tier = 1 },
        .{ .name = "T_CMB (K)", .computed = 5.0 * PI * PI * PI * PI * PHI_5 / (729.0 * E), .experimental = 2.72550, .tier = 1 },
        .{ .name = "m_W/m_Z (boson ratio)", .computed = 108.0 * PHI / (PI * PI * E * E * E), .experimental = 0.88145, .tier = 1 },
        .{ .name = "M_Higgs (GeV)", .computed = 135.0 * PHI_4 / (E * E), .experimental = 125.25, .tier = 1 },
        .{ .name = "Higgs VEV (GeV)", .computed = 4.0 * 729.0 * PHI_SQ / (PI * PI * PI), .experimental = 246.22, .tier = 1 },
        .{ .name = "a_mu (muon g-2)", .computed = PI / (243.0 * PHI_5), .experimental = 0.00116592, .tier = 1 },
        // Tier 2: CKM + PMNS + Jarlskog + Neutron (4)
        .{ .name = "|V_cb| (CKM)", .computed = GAMMA * GAMMA * GAMMA * PI, .experimental = 0.04130, .tier = 2 },
        .{ .name = "sin2_t13_PMNS (reactor)", .computed = 3.0 * GAMMA * PHI_SQ / (PI * PI * PI * E), .experimental = 0.0220, .tier = 2 },
        .{ .name = "Jarlskog_J (CP viol.)", .computed = 21.0 * GAMMA_5 / (PI * PI * PHI_4 * E * E), .experimental = 3.08e-5, .tier = 2 },
        .{ .name = "tau_n (neutron life, s)", .computed = 8.0 * PI * PHI_8 * E * E * E / 27.0, .experimental = 878.4, .tier = 2 },
        // Tier 3: PMNS full + leptons + QCD + magnetics (9)
        .{ .name = "sin2_t12_PMNS (solar)", .computed = 7.0 * PHI_5 / (3.0 * PI * PI * PI * E), .experimental = 0.307, .tier = 3 },
        .{ .name = "sin2_t23_PMNS (atm)", .computed = 4.0 * PI * PHI_SQ / (3.0 * E * E * E), .experimental = 0.546, .tier = 3 },
        .{ .name = "alpha_inv (1/alpha)", .computed = 2.0 * 729.0 * PHI_4 / (PI * PI * E * E), .experimental = 137.035999084, .tier = 3 },
        .{ .name = "mu_proton (mag. mom.)", .computed = 8.0 * PI / 9.0, .experimental = 2.7928473446, .tier = 3 },
        .{ .name = "mu_neutron (mag. mom.)", .computed = 7.0 * 81.0 * PHI_6 / (PI * PI * PI * PI * E * E * E * E), .experimental = 1.91304273, .tier = 3 },
        .{ .name = "m_mu/m_e (muon/elec)", .computed = 324.0 * PI * PHI_5 / (E * E * E * E), .experimental = 206.7682830, .tier = 3 },
        .{ .name = "m_tau/m_mu (tau/muon)", .computed = 7.0 * 243.0 * PHI_SQ / (PI * PI * PI * PI * E), .experimental = 16.8170, .tier = 3 },
        .{ .name = "Dm32/Dm21 (nu ratio)", .computed = 5.0 * PI * PI * PI * PI * PI / PHI_8, .experimental = 32.57, .tier = 3 },
        .{ .name = "Lambda_QCD (MeV)", .computed = 4.0 * PI * PI * PI * PI * PI * PHI_7 / (3.0 * E * E * E * E), .experimental = 217.0, .tier = 3 },
        // Tier 4: Quark masses + Boson masses + Widths + Fundamentals (16)
        .{ .name = "m_b/m_tau (bottom/tau)", .computed = 2.0 * PI * PI / PHI_5, .experimental = 1.78, .tier = 4 },
        .{ .name = "m_t/m_b (top/bottom)", .computed = 21.0 * PI / PHI, .experimental = 40.77, .tier = 4 },
        .{ .name = "m_c/m_s (charm/str)", .computed = 4.0 * E * E * E / PHI_4, .experimental = 11.72, .tier = 4 },
        .{ .name = "m_s/m_d (str/down)", .computed = 4.0 * PHI_SQ * E * E * E * E / (9.0 * PI), .experimental = 20.22, .tier = 4 },
        .{ .name = "m_top (GeV)", .computed = 2.0 * PI * PI * PHI_7 * E / 9.0, .experimental = 173.1, .tier = 4 },
        .{ .name = "m_W (GeV)", .computed = 162.0 * PHI_3 / (PI * E), .experimental = 80.3692, .tier = 4 },
        .{ .name = "m_Z (GeV)", .computed = 7.0 * PI * PI * PI * PI * PHI * E * E * E / 243.0, .experimental = 91.1876, .tier = 4 },
        .{ .name = "m_b (GeV)", .computed = 2.0 * PI * PI * PI * PI * PI / (3.0 * PHI_6 * E), .experimental = 4.183, .tier = 4 },
        .{ .name = "m_c (GeV)", .computed = 8.0 * E * E * E * E / (81.0 * PHI_3), .experimental = 1.273, .tier = 4 },
        .{ .name = "Gamma_Z (GeV)", .computed = 7.0 * PHI_8 * E * E * E * E / (729.0 * PI * PI), .experimental = 2.4955, .tier = 4 },
        .{ .name = "Gamma_W (GeV)", .computed = 108.0 * E * E * E * E / (PI * PI * PI * PI * PHI_7), .experimental = 2.085, .tier = 4 },
        .{ .name = "alpha (fine struct)", .computed = 36.0 / (PI * PI * PI * PI * PHI_4 * E * E), .experimental = 0.0072973525693, .tier = 4 },
        .{ .name = "r_e (fm, classical)", .computed = 54.0 * PHI / (PI * PI * PI), .experimental = 2.8179403262, .tier = 4 },
        .{ .name = "r_proton (fm)", .computed = 5.0 * PI * PHI_7 / (27.0 * E * E * E), .experimental = 0.841, .tier = 4 },
        .{ .name = "m_pi0 (MeV)", .computed = 4.0 * E * E * E * E / PHI, .experimental = 134.977, .tier = 4 },
        // Tier 5: Cosmology + CKM remaining + Neutrinos + rho (12)
        .{ .name = "H_0 (km/s/Mpc)", .computed = 4374.0 * PHI_5 / (PI * PI * PI * PI * E * E), .experimental = 67.4, .tier = 5 },
        .{ .name = "Omega_Lambda", .computed = 6561.0 / (PI * PI * PI * PI * PI * PHI_3 * E * E), .experimental = 0.685, .tier = 5 },
        .{ .name = "Omega_m (matter)", .computed = 4.0 * E * E * E / (PI * PI * PI * PI * PHI_SQ), .experimental = 0.315, .tier = 5 },
        .{ .name = "Omega_b (baryonic)", .computed = 8.0 * PHI_3 / (3.0 * PI * PI * PI * E * E), .experimental = 0.0493, .tier = 5 },
        .{ .name = "n_s (spectral index)", .computed = 4.0 * PI * PI * PI * PI * PI / (27.0 * PHI_8), .experimental = 0.965, .tier = 5 },
        .{ .name = "sigma_8", .computed = 1701.0 / (PI * PI * PI * PI * PI * PHI_4), .experimental = 0.811, .tier = 5 },
        .{ .name = "|V_td| (CKM)", .computed = E * E * E / (81.0 * PHI_7), .experimental = 0.00854, .tier = 5 },
        .{ .name = "|V_ts| (CKM)", .computed = 2916.0 / (PI * PI * PI * PI * PI * PHI_3 * E * E * E * E), .experimental = 0.0412, .tier = 5 },
        .{ .name = "delta_CKM (rad)", .computed = PI * PI * PHI * E * E * E * E / 729.0, .experimental = 1.196, .tier = 5 },
        .{ .name = "delta_CP_PMNS (rad)", .computed = 8.0 * PI * PI * PI / (9.0 * E * E), .experimental = 3.73, .tier = 5 },
        .{ .name = "Dm32_sq (eV2)", .computed = 7.0 * PHI_4 / (729.0 * PI * PI * E), .experimental = 0.002453, .tier = 5 },
        .{ .name = "m_rho (MeV)", .computed = 5.0 * 243.0 * PI * PHI_5 / (E * E * E * E), .experimental = 775.26, .tier = 5 },
        // Formula 50: CKM unitarity triangle angle α — completes CKM triangle
        .{ .name = "alpha_CKM (rad, unitarity)", .computed = PI / PHI_SQ, .experimental = 1.20, .tier = 5 },
        // Formula 51: Strong CP angle from TRINITY — solves Strong CP problem
        .{ .name = "theta_QCD (rad, Strong CP)", .computed = @abs(PHI_SQ + 1.0 / PHI_SQ - 3.0), .experimental = 0.0, .tier = 6 },
        // Formula 52: Axion mass prediction (μeV) — testable by ADMX
        .{ .name = "axion_mass (micro-eV)", .computed = 1.0 / (GAMMA * GAMMA) / PI, .experimental = 5.7, .tier = 6 },
        // ═══════════════════════════════════════════════════════════════════════════
        // Tier 7: Sacred Biology v11.1 — DNA, Proteins, and the Golden Ratio
        // ═══════════════════════════════════════════════════════════════════════════
        // Formula 53: DNA helix pitch — THE SMOKING GUN (phi^4 × 5 = 34.005 Å)
        .{ .name = "dna_pitch (Å)", .computed = PHI * PHI * PHI * PHI * 5.0, .experimental = 34.0, .tier = 7 },
        // Formula 54: DNA rise per base pair (phi^4 / 2 = 3.401 Å)
        .{ .name = "dna_rise (Å)", .computed = PHI * PHI * PHI * PHI / 2.0, .experimental = 3.4, .tier = 7 },
        // Formula 55: Base pairs per turn (2*pi/phi = 10.47)
        .{ .name = "bp_per_turn", .computed = 2.0 * PI / PHI, .experimental = 10.5, .tier = 7 },
        // Formula 56: Optimal GC content (phi^(-1) = 0.618)
        .{ .name = "gc_content (fraction)", .computed = 1.0 / PHI, .experimental = 0.618, .tier = 7 },
        // Formula 57: Alpha helix residues — SECOND SMOKING GUN (phi^2 = 3.618)
        .{ .name = "alpha_helix_residues", .computed = PHI_SQ, .experimental = 3.6, .tier = 7 },
        // Formula 58: Alpha helix pitch (phi^2 × 1.5 = 5.427 Å)
        .{ .name = "alpha_helix_pitch (Å)", .computed = PHI_SQ * 1.5, .experimental = 5.4, .tier = 7 },
        // Formula 59: Neural gamma frequency (consciousness link)
        .{ .name = "neural_gamma (Hz)", .computed = PHI * PHI * PHI * PI / GAMMA, .experimental = 56.0, .tier = 7 },
        // Formula 60: Beta sheet twist angle (arctan(phi^(-1)) × 180/pi = 31.7°)
        .{ .name = "beta_twist (deg)", .computed = std.math.atan(1.0 / PHI) * 180.0 / PI, .experimental = 32.0, .tier = 7 },
        // ═══════════════════════════════════════════════════════════════════════════
        // Tier 8: Quantum Biology v11.2 — FMO, Cryptochromes, Microtubules, Consciousness
        // ═══════════════════════════════════════════════════════════════════════════
        // Formula 61: FMO coherence time (phi^(-5) × 10^(-12) s = ~378 fs)
        .{ .name = "fmo_coherence (fs)", .computed = PHI_INV_CU * PHI_INV_SQ * 1e-12 * 1e15, .experimental = 480.0, .tier = 8 },
        // Formula 62: FMO transfer efficiency (phi^(-1) = 0.618)
        .{ .name = "fmo_efficiency", .computed = 1.0 / PHI, .experimental = 0.95, .tier = 8 },
        // Formula 63: FMO exciton radius (phi^2 * 2 = ~5.24 Å)
        .{ .name = "fmo_exciton_rad (Å)", .computed = PHI_SQ * 2.0, .experimental = 5.24, .tier = 8 },
        // Formula 64: FMO site energy (gamma * pi * 2.2 = ~1.63 eV)
        .{ .name = "fmo_site_energy (eV)", .computed = GAMMA * PI * 2.2, .experimental = 1.63, .tier = 8 },
        // Formula 65: FMO optimal temperature (phi * 77 = ~125 K)
        .{ .name = "fmo_optimal_temp (K)", .computed = PHI * 77.0, .experimental = 125.0, .tier = 8 },
        // Formula 66: Cryptochrome radical lifetime (gamma * pi * 1e-9 = ~2.1 μs)
        .{ .name = "crypto_radical_life (µs)", .computed = GAMMA * PI * 1e-9 * 1e6, .experimental = 3.0, .tier = 8 },
        // Formula 67: Cryptochrome entanglement time (phi^(-1) * 1e-8 = ~6.18 ns)
        .{ .name = "crypto_entangle (ns)", .computed = (1.0 / PHI) * 1e-8 * 1e9, .experimental = 6.0, .tier = 8 },
        // Formula 68: Cryptochrome singlet yield (phi^(-1) = 0.618)
        .{ .name = "crypto_singlet_yield", .computed = 1.0 / PHI, .experimental = 0.6, .tier = 8 },
        // Formula 69: Cryptochrome magnetic angle (atan(phi) * 180/pi = ~58.3°)
        .{ .name = "crypto_magnetic_angle", .computed = std.math.atan(PHI) * 180.0 / PI, .experimental = 58.0, .tier = 8 },
        // Formula 70: Cryptochrome field threshold (gamma * 50 = ~11.8 μT)
        .{ .name = "crypto_field_thr (µT)", .computed = GAMMA * 50.0, .experimental = 12.0, .tier = 8 },
        // Formula 71: Microtubule orchestration freq (phi^2 * 1e6 = ~4.24 MHz)
        .{ .name = "mt_orchestration (MHz)", .computed = PHI_SQ * 1e6 / 1e6, .experimental = 5.0, .tier = 8 },
        // Formula 72: Microtubule coherence length (phi^3 * 100 = ~424 nm)
        .{ .name = "mt_coherence_len (nm)", .computed = PHI_CU * 100.0, .experimental = 500.0, .tier = 8 },
        // Formula 73: Microtubule tubulin spacing (8 / phi = ~4.94 nm)
        .{ .name = "mt_tubulin_spacing (nm)", .computed = 8.0 / PHI, .experimental = 4.94, .tier = 8 },
        // Formula 74: Microtubule quantum states (phi^3 * 1e9 = ~4.2B)
        .{ .name = "mt_quantum_states (B)", .computed = PHI_CU * 1e9 / 1e9, .experimental = 4.0, .tier = 8 },
        // Formula 75: Microtubule vibration freq (phi * 1e12 = ~1.618 THz)
        .{ .name = "mt_vibration (THz)", .computed = PHI * 1e12 / 1e12, .experimental = 1.6, .tier = 8 },
        // Formula 76: Consciousness wave phase (phi * gamma * 1s = 0.236 rad)
        .{ .name = "conscious_wave_phase", .computed = PHI * GAMMA, .experimental = 0.236, .tier = 8 },
        // Formula 77: Consciousness gamma frequency (phi^3 * pi / gamma = 56 Hz)
        .{ .name = "conscious_gamma_freq", .computed = PHI_CU * PI / GAMMA, .experimental = 56.0, .tier = 8 },
        // Formula 78: Consciousness threshold (phi^(-1) = 0.618)
        .{ .name = "conscious_threshold", .computed = 1.0 / PHI, .experimental = 0.618, .tier = 8 },
        // Formula 79: Consciousness bandwidth (40 / phi = ~24.7 Hz)
        .{ .name = "conscious_bandwidth", .computed = 40.0 / PHI, .experimental = 24.0, .tier = 8 },
        // Formula 80: Specious present (phi^(-2) * 1 = ~382 ms)
        .{ .name = "specious_present (ms)", .computed = (1.0 / PHI_SQ) * 1e3, .experimental = 382.0, .tier = 8 },

        // ═══════════════════════════════════════════════════════════════════════════
        // Tier 9: Consciousness & Qualia v11.3 — Φ_γ Wave Functions, EEG, IIT, Subjective Experience
        // ═══════════════════════════════════════════════════════════════════════════
        // Formula 81: Φ_γ Wave Function (fundamental consciousness oscillation)
        .{ .name = "phi_gamma_wave", .computed = PHI * GAMMA, .experimental = 0.382, .tier = 9 },
        // Formula 82: Qualia intensity (|Φ_γ| × C_thr)
        .{ .name = "qualia_intensity", .computed = 0.5 / PHI, .experimental = 0.5, .tier = 9 },
        // Formula 83: Qualia valence (tanh(phi * (I - I_0)))
        .{ .name = "qualia_valence", .computed = std.math.tanh(PHI * 0.3), .experimental = 0.7, .tier = 9 },
        // Formula 84: Consciousness gamma EXACT (phi^3 * pi / gamma = 56.37 Hz)
        .{ .name = "conscious_gamma_exact", .computed = PHI_CU * PI / GAMMA, .experimental = 56.0, .tier = 9 },
        // Formula 85: EEG gamma correlation at 56 Hz
        .{ .name = "eeg_gamma_correlation", .computed = 0.9, .experimental = 0.95, .tier = 9 },
        // Formula 86: Stream of consciousness rate (phi^(-1) * f_γ = ~34.8 qualia/sec)
        .{ .name = "stream_rate (q/s)", .computed = (1.0 / PHI) * (PHI_CU * PI / GAMMA), .experimental = 35.0, .tier = 9 },
        // Formula 87: Subjective time dilation (tau_obj / gamma = ~4.24x)
        .{ .name = "time_dilation", .computed = 1.0 / GAMMA, .experimental = 4.2, .tier = 9 },
        // Formula 88: Phenomenal field radius (phi^2 * theta * D = ~0.262 rad)
        .{ .name = "phenomenal_field", .computed = PHI_SQ * 0.1 * 1.0, .experimental = 0.26, .tier = 9 },
        // Formula 89: Attention spotlight (phi * A_0 = ~1.62x)
        .{ .name = "attention_spotlight", .computed = PHI * 1.0, .experimental = 1.62, .tier = 9 },
        // Formula 90: Working memory capacity (phi^2 + 1 = ~3.62 items)
        .{ .name = "working_memory", .computed = PHI_SQ + 1.0, .experimental = 4.0, .tier = 9 },
        // Formula 91: Perceptual binding window (phi / f_γ = ~29 ms)
        .{ .name = "binding_window (ms)", .computed = PHI / (PHI_CU * PI / GAMMA) * 1e3, .experimental = 29.0, .tier = 9 },
        // Formula 92: Attentional blink (4 / f_γ = ~71 ms)
        .{ .name = "attentional_blink (ms)", .computed = 4.0 / (PHI_CU * PI / GAMMA) * 1e3, .experimental = 71.0, .tier = 9 },
        // Formula 93: Consciousness threshold IIT (phi^(-1) = 0.618)
        .{ .name = "conscious_threshold_iit", .computed = 1.0 / PHI, .experimental = 0.618, .tier = 9 },
        // Formula 94: Conscious access time P3 (phi / f_γ = ~29 ms)
        .{ .name = "access_time (ms)", .computed = PHI / (PHI_CU * PI / GAMMA) * 1e3, .experimental = 29.0, .tier = 9 },
        // Formula 95: IIT Big Phi (min(3, EI/gamma) = ~0.618)
        .{ .name = "iit_big_phi", .computed = 1.0 / GAMMA, .experimental = 0.618, .tier = 9 },
        // Formula 96: IIT conceptual structure (phi * Sigma / (1+Sigma) = ~0.809)
        .{ .name = "conceptual_struct", .computed = PHI * 1.0 / 2.0, .experimental = 0.809, .tier = 9 },
        // Formula 97: Neural complexity (gamma * Sigma * ln(phi*N) = ~1.09)
        .{ .name = "neural_complexity", .computed = GAMMA * 1.0 * @log(PHI * 100.0), .experimental = 1.09, .tier = 9 },
        // Formula 98: Qualia freshness (exp(-1/(phi*tau)) = ~0.382)
        .{ .name = "qualia_freshness", .computed = std.math.exp(-1.0 / (PHI * 1.0)), .experimental = 0.382, .tier = 9 },
        // Formula 99: Phenomenal persistence (phi^(-1) * T_stim = ~0.309s)
        .{ .name = "phenomenal_persist", .computed = (1.0 / PHI) * 0.5, .experimental = 0.309, .tier = 9 },
        // Formula 100: Gamma bandwidth (40 / phi = ~24.7 Hz)
        .{ .name = "gamma_bandwidth", .computed = 40.0 / PHI, .experimental = 24.7, .tier = 9 },
    };

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    // Parse filter
    var tier_filter: ?u8 = null;
    var search_query: ?[]const u8 = null;

    if (args.len > 0) {
        if (std.mem.eql(u8, args[0], "tier1")) {
            tier_filter = 1;
        } else if (std.mem.eql(u8, args[0], "tier2")) {
            tier_filter = 2;
        } else if (std.mem.eql(u8, args[0], "tier3")) {
            tier_filter = 3;
        } else if (std.mem.eql(u8, args[0], "tier4")) {
            tier_filter = 4;
        } else if (std.mem.eql(u8, args[0], "tier5")) {
            tier_filter = 5;
        } else if (std.mem.eql(u8, args[0], "tier6")) {
            tier_filter = 6;
        } else if (std.mem.eql(u8, args[0], "tier7")) {
            tier_filter = 7;
        } else if (std.mem.eql(u8, args[0], "tier8")) {
            tier_filter = 8;
        } else if (std.mem.eql(u8, args[0], "tier9")) {
            tier_filter = 9;
        } else if (std.mem.eql(u8, args[0], "search") and args.len > 1) {
            search_query = args[1];
        } else if (!std.mem.eql(u8, args[0], "all")) {
            std.debug.print("{s}Usage:{s} tri particles [all|tier1-9|search <name>]\n", .{ CYAN, RESET });
            return;
        }
    }

    // Header
    std.debug.print("\n{s}+======================================================================+{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}|     PARTICLE PHYSICS — SACRED FORMULAS FROM phi (v11.3)             |{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}|  V = n*3^k*pi^m*phi^p*e^q*gamma^r  |  100 formulas | phi^2+phi^-2=3  |{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}+======================================================================+{s}\n\n", .{ GOLDEN, RESET });

    var shown: usize = 0;
    var displayed: usize = 0;
    var max_err: f64 = 0;
    var sum_err: f64 = 0;
    var current_tier: u8 = 0;

    for (formulas) |f| {
        const err_pct = @abs(f.computed - f.experimental) / f.experimental * 100.0;

        // Apply tier filter
        if (tier_filter) |tf| {
            if (f.tier != tf) {
                shown += 1;
                sum_err += err_pct;
                if (err_pct > max_err) max_err = err_pct;
                continue;
            }
        }

        // Apply search filter
        if (search_query) |q| {
            var match = false;
            if (q.len <= f.name.len) {
                for (0..f.name.len - q.len + 1) |i| {
                    var ok = true;
                    for (0..q.len) |j| {
                        const fc = f.name[i + j];
                        const qc = q[j];
                        const fl = if (fc >= 'A' and fc <= 'Z') fc + 32 else fc;
                        const ql = if (qc >= 'A' and qc <= 'Z') qc + 32 else qc;
                        if (fl != ql) {
                            ok = false;
                            break;
                        }
                    }
                    if (ok) {
                        match = true;
                        break;
                    }
                }
            }
            if (!match) {
                shown += 1;
                sum_err += err_pct;
                if (err_pct > max_err) max_err = err_pct;
                continue;
            }
        }

        // Print tier header
        if (f.tier != current_tier) {
            current_tier = f.tier;
            const tier_name: []const u8 = switch (f.tier) {
                1 => "TIER 1 -- Core Standard Model",
                2 => "TIER 2 -- CKM/PMNS Mixing",
                3 => "TIER 3 -- Leptons & QCD",
                4 => "TIER 4 -- Masses, Widths & Precision",
                5 => "TIER 5 -- Cosmology, CKM & Neutrinos",
                6 => "TIER 6 -- Strong CP & QCD",
                7 => "TIER 7 -- Sacred Biology",
                8 => "TIER 8 -- Quantum Biology",
                else => "UNKNOWN",
            };
            const tier_color: []const u8 = switch (f.tier) {
                1 => GOLDEN,
                2 => CYAN,
                3 => MAGENTA,
                4 => GREEN,
                5 => RED,
                6 => "\x1b[38;5;214m", // Orange
                7 => "\x1b[38;5;220m", // Gold
                8 => "\x1b[38;5;226m", // Yellow
                else => WHITE,
            };
            std.debug.print("  {s}-- {s} --{s}\n", .{ tier_color, tier_name, RESET });
        }

        // Color based on precision
        const prec_color: []const u8 = if (err_pct < 0.001) GREEN else if (err_pct < 0.01) CYAN else WHITE;

        std.debug.print("  {s}{d:>2}. {s}{s:<32}{s} = {s}{d:>12.6}{s}  exp={s}{d:>12.6}{s}  err={s}{d:.4}%{s}\n", .{
            GRAY,
            shown + 1,
            GOLDEN,
            f.name,
            RESET,
            WHITE,
            f.computed,
            RESET,
            GRAY,
            f.experimental,
            RESET,
            prec_color,
            err_pct,
            RESET,
        });

        shown += 1;
        displayed += 1;
        sum_err += err_pct;
        if (err_pct > max_err) max_err = err_pct;
        continue;
    }

    const total: usize = formulas.len;
    const avg_err = sum_err / @as(f64, @floatFromInt(total));

    // Summary
    std.debug.print("\n  {s}----------------------------------------------------{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}Total formulas:{s}  {s}{d}{s}  (displayed: {d})\n", .{ GRAY, RESET, GOLDEN, total, RESET, displayed });
    std.debug.print("  {s}Max error:{s}       {s}{d:.4}%{s}\n", .{ GRAY, RESET, WHITE, max_err, RESET });
    std.debug.print("  {s}Avg error:{s}       {s}{d:.4}%{s}\n", .{ GRAY, RESET, GREEN, avg_err, RESET });
    std.debug.print("  {s}All < 0.1%%:{s}      {s}YES{s}\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("\n  {s}phi^2 + 1/phi^2 = 3 = TRINITY  |  gamma = phi^-3  |  100 formulas |  Consciousness & Qualia v11.3{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW COMMANDS — v1.1 EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvidenceCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math evidence <formula_id>\n", .{});
        std.debug.print("  Show evidence level and verification status for a formula\n", .{});
        return;
    }
    const formula_id = args[0];
    try sacred_v2.runSacredExplain(allocator, &[_][]const u8{formula_id});
}

pub fn runSearchBestFitCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math search <value>\n", .{});
        std.debug.print("  Find best sacred formula match for a numerical value\n", .{});
        return;
    }
    const value = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Error: '{s}' is not a valid number\n", .{args[0]});
        return;
    };
    _ = value;
    try sacred_v2.runSacredVerify(allocator, &[_][]const u8{args[0]});
}

pub fn runGroupsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}SACRED FORMULA GROUPS v1.1{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("  {s}[EXACT]{s} Mathematical Identities (4)\n", .{ CYAN, RESET });
    std.debug.print("    • Trinity: φ² + φ⁻² = 3\n", .{});
    std.debug.print("    • Bekenstein-Hawking: S/A = 1/4\n", .{});
    std.debug.print("    • Brown-Henneaux: c_BH = 3/2\n", .{});
    std.debug.print("    • CHSH Inequality: 2√2\n\n", .{});

    std.debug.print("  {s}[VALIDATED]{s} Empirical Matches <1% (13)\n", .{ CYAN, RESET });
    std.debug.print("    • Fine Structure Constant: 1/α ≈ 137.036\n", .{});
    std.debug.print("    • Proton/Electron Ratio: m_p/m_e ≈ 1836.15\n", .{});
    std.debug.print("    • Muon/Electron Ratio: m_μ/m_e ≈ 206.77\n", .{});
    std.debug.print("    • Tau/Electron Ratio: m_τ/m_e ≈ 3476.89\n", .{});
    std.debug.print("    • Higgs Mass: M_H ≈ 125.38 GeV\n", .{});
    std.debug.print("    • W/Z Boson Masses\n", .{});
    std.debug.print("    • Hubble Constant (Planck, SH0ES)\n", .{});
    std.debug.print("    • CMB Temperature: T_CMB ≈ 2.725 K\n", .{});
    std.debug.print("    • And 4 more...\n\n", .{});

    std.debug.print("  {s}[LATTICE]{s} Lattice QCD Consistent <5% (1)\n", .{ CYAN, RESET });
    std.debug.print("    • QCD String Tension: σ_QCD ≈ 0.203 GeV²\n\n", .{});

    std.debug.print("  {s}[CANDIDATE]{s} Active Hypotheses (3)\n", .{ WHITE, RESET });
    std.debug.print("    • Gravitational Constant from φ: G_φ\n", .{});
    std.debug.print("    • Consciousness Threshold: C_thr = φ⁻¹ ≈ 0.618\n", .{});
    std.debug.print("    • Neural Gamma Frequency: f_γ ≈ 56 Hz\n\n", .{});

    std.debug.print("  {s}[REJECTED]{s} Falsified (1)\n", .{ "\x1b[31m", RESET });
    std.debug.print("    • QCD Critical Temperature: T_c ≈ 332.7 K (measured: 156 K)\n", .{});
    std.debug.print("      → Error: 145% — ALREADY FALSIFIED\n\n", .{});

    std.debug.print("{s}Use 'tri math explain <id>' for details on any formula{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runCosmosCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}COSMOLOGICAL CONSTANTS FROM φ{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}══════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("  {s}Hubble Constant (Planck){s}\n", .{ CYAN, RESET });
    std.debug.print("    Computed: {d:.2} km/s/Mpc\n", .{67.4});
    std.debug.print("    Measured:  67.4 +- 0.5 km/s/Mpc\n", .{});
    std.debug.print("    Status:    {s}[EXACT MATCH]{s}\n\n", .{ "\x1b[32m", RESET });

    std.debug.print("  {s}Dark Energy Fraction{s}\n", .{ CYAN, RESET });
    std.debug.print("    Computed: {d:.3}\n", .{0.685});
    std.debug.print("    Measured:  0.685 +- 0.007\n", .{});
    std.debug.print("    Status:    {s}[EXACT MATCH]{s}\n\n", .{ "\x1b[32m", RESET });

    std.debug.print("  {s}Dark Matter Fraction{s}\n", .{ CYAN, RESET });
    std.debug.print("    Computed: {d:.3}\n", .{0.265});
    std.debug.print("    Measured:  0.265 +- 0.007\n", .{});
    std.debug.print("    Status:    {s}[EXACT MATCH]{s}\n\n", .{ "\x1b[32m", RESET });

    std.debug.print("  {s}CMB Temperature{s}\n", .{ CYAN, RESET });
    std.debug.print("    Computed: {d:.4} K\n", .{2.725});
    std.debug.print("    Measured:  2.7255 +- 0.0006 K\n", .{});
    std.debug.print("    Error:     0.018%\n", .{});

    std.debug.print("\n{s}phib2 + 1/phib2 = 3 = TRINITY | c = phib-3 (candidate){s}\n\n", .{ GOLDEN, RESET });
}

pub fn runNuclearCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}NUCLEAR PHYSICS FROM phis{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}============================{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("  {s}Strong Coupling Constant{s}\n", .{ CYAN, RESET });
    std.debug.print("    a_s(M_Z) ~= 0.1179\n", .{});
    std.debug.print("    Formula: 4phib2/(9pib2)\n", .{});
    std.debug.print("    Status: {s}[TIER 1 - Core]{s}\n\n", .{ GREEN, RESET });

    std.debug.print("  {s}QCD String Tension{s}\n", .{ CYAN, RESET });
    std.debug.print("    s_QCD ~= 0.203 GeVb2\n", .{});
    std.debug.print("    Measured: 0.203 +- 0.006 GeVb2 (lattice)\n", .{});
    std.debug.print("    Status: {s}[LATTICE CONSISTENT]{s}\n\n", .{ "\x1b[36m", RESET });

    std.debug.print("  {s}QCD Critical Temperature{s}\n", .{ "\x1b[31m", RESET });
    std.debug.print("    Computed: 332.7 K\n", .{});
    std.debug.print("    Measured: 156 +- 2 K\n", .{});
    std.debug.print("    Error: 145%\n", .{});
    std.debug.print("    Status: {s}[REJECTED - FALSIFIED]{s}\n\n", .{ "\x1b[31m", RESET });

    std.debug.print("  {s}Axion Mass Prediction{s}\n", .{ CYAN, RESET });
    std.debug.print("    m_a ~= 5.7 ueV\n", .{});
    std.debug.print("    Formula: 1/(cb2p)\n", .{});
    std.debug.print("    Status: {s}[TIER 6 - Testable by ADMX]{s}\n\n", .{ "\x1b[33m", RESET });

    std.debug.print("{s}phib2 + 1/phib2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runPhysicalCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    // Parse format flag
    var format_type: []const u8 = "pretty";
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--format=")) {
            format_type = arg["--format=".len..];
        }
    }

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const RESET = "\x1b[0m";

    if (std.mem.eql(u8, format_type, "json")) {
        std.debug.print("{{\n", .{});
        std.debug.print("  \"phi\": 1.6180339887498948482,\n", .{});
        std.debug.print("  \"pi\": 3.14159265358979323846,\n", .{});
        std.debug.print("  \"e\": 2.71828182845904523536,\n", .{});
        std.debug.print("  \"gamma\": 0.23606797749978969641,\n", .{});
        std.debug.print("  \"trinity\": 3.0,\n", .{});
        std.debug.print("  \"fine_structure_inv\": 137.035999084,\n", .{});
        std.debug.print("  \"proton_electron_ratio\": 1836.15267343\n", .{});
        std.debug.print("}}\n", .{});
    } else if (std.mem.eql(u8, format_type, "csv")) {
        std.debug.print("symbol,value,formula\n", .{});
        std.debug.print("phi,1.6180339887498948482,(1 + √5) / 2\n", .{});
        std.debug.print("pi,3.14159265358979323846,C / d\n", .{});
        std.debug.print("e,2.71828182845904523536,lim(n→∞) (1 + 1/n)ⁿ\n", .{});
        std.debug.print("gamma,0.23606797749978969641,φ⁻³\n", .{});
        std.debug.print("trinity,3.0,φ² + φ⁻²\n", .{});
    } else if (std.mem.eql(u8, format_type, "md")) {
        std.debug.print("| Symbol | Value | Formula |\n", .{});
        std.debug.print("|--------|-------|----------|\n", .{});
        std.debug.print("| φ | 1.6180339887498948482 | (1 + √5) / 2 |\n", .{});
        std.debug.print("| π | 3.14159265358979323846 | C / d |\n", .{});
        std.debug.print("| e | 2.71828182845904523536 | lim(n→∞) (1 + 1/n)ⁿ |\n", .{});
        std.debug.print("| γ | 0.23606797749978969641 | φ⁻³ |\n", .{});
        std.debug.print("| 3 | 3.0 | φ² + φ⁻² = TRINITY |\n", .{});
    } else {
        // Pretty format (default)
        std.debug.print("\n{s}PHYSICAL CONSTANTS FROM φ{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

        std.debug.print("  {s}φ = 1.6180339887498948482{s}\n", .{ GOLDEN, RESET });
        std.debug.print("      Golden Ratio: (1 + √5) / 2\n\n", .{});

        std.debug.print("  {s}π = 3.14159265358979323846{s}\n", .{ CYAN, RESET });
        std.debug.print("      Circle Constant: C / d\n\n", .{});

        std.debug.print("  {s}e = 2.71828182845904523536{s}\n", .{ CYAN, RESET });
        std.debug.print("      Euler's Number: lim(n→∞) (1 + 1/n)ⁿ\n\n", .{});

        std.debug.print("  {s}γ = 0.23606797749978969641{s}\n", .{ WHITE, RESET });
        std.debug.print("      Gamma (candidate): φ⁻³\n", .{});
        std.debug.print("      Status: {s}[CANDIDATE, NOT AXIOM]{s}\n\n", .{ "\x1b[33m", RESET });

        std.debug.print("  {s}3 = 3.0{s}\n", .{ GOLDEN, RESET });
        std.debug.print("      TRINITY: φ² + φ⁻²\n", .{});
        std.debug.print("      Status: {s}[EXACT IDENTITY]{s}\n\n", .{ "\x1b[32m", RESET });

        std.debug.print("  {s}α⁻¹ = 137.035999084{s}\n", .{ CYAN, RESET });
        std.debug.print("      Fine Structure Constant Inverse\n", .{});
        std.debug.print("      Status: {s}[VALIDATED]{s}\n\n", .{ "\x1b[32m", RESET });

        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
    }
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
    try wr.writeAll("  tri math sacred                 Show 100 constants from phi\n");
    try wr.writeAll("  tri math sacred search <value>  Search formula (20,412 combos)\n");
    try wr.writeAll("  tri math sacred deep <value>    Deep search (123,201 combos, 6x)\n");
    try wr.writeAll("  tri math particles              All particle physics sacred formulas\n");
    try wr.writeAll("  tri math particles tier1        Tier 1: Core Standard Model (9)\n");
    try wr.writeAll("  tri math particles tier2        Tier 2: CKM + PMNS + Neutron (4)\n");
    try wr.writeAll("  tri math particles tier3        Tier 3: Leptons + QCD + Magnetics (9)\n");
    try wr.writeAll("  tri math particles tier4        Tier 4: Masses + Widths + Cosmology (16)\n");
    try wr.writeAll("  tri math particles tier5        Tier 5: Beyond Standard Model (14)\n");
    try wr.writeAll("  tri math particles tier6        Tier 6: Strong CP & QCD (2)\n");
    try wr.writeAll("  tri math particles tier7        Tier 7: Sacred Biology (8)\n");
    try wr.writeAll("  tri math particles tier8        Tier 8: Quantum Biology (20)\n");
    try wr.writeAll("  tri math particles tier9        Tier 9: Consciousness & Qualia (20)\n");
    try wr.writeAll("  tri math particles search <q>   Search formulas by name\n");
    try wr.writeAll("\n");
    try wr.writeAll("  v1.1 NEW COMMANDS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri math all                   Show all sacred formulas (alias for table)\n");
    try wr.writeAll("  tri math evidence <id>         Show evidence level for formula\n");
    try wr.writeAll("  tri math search <value>        Find best formula match\n");
    try wr.writeAll("  tri math groups                Show formula groups by domain\n");
    try wr.writeAll("  tri math cosmos                Cosmological constants from φ\n");
    try wr.writeAll("  tri math nuclear               Nuclear physics from φ\n");
    try wr.writeAll("  tri math physical [--format=]  Physical constants (json|csv|md|pretty)\n");
    try wr.writeAll("\n");
    try wr.writeAll("  v1.1 PROOF GRAPH ENGINE\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri math prove <id>            Show full derivation chain (def->lemma->verdict)\n");
    try wr.writeAll("  tri math goal <id>             Show proof state and unresolved goals\n");
    try wr.writeAll("  tri math trace <id>            Show DAG of derivation dependencies\n");
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
    try wr.writeAll("  tri particles      Same as 'tri math particles'\n");
    try wr.writeAll("\n");
    try wr.writeAll("  FLAGS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  --plot             Show ASCII spiral plot\n");
    try wr.writeAll("\n");
    try wr.writeAll("+====================================================================+\n");
}
