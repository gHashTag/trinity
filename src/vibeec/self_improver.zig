// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE SELF-IMPROVEMENT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// VIBEE improves VIBEE — recursive self-improvement loop
//
// φ² + 1/φ² = 3 = TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");

const Allocator = std.mem.Allocator;

/// Configuration for self-improvement loop
pub const ImproverConfig = struct {
    max_iterations: usize = 5,
    target_real_pct: f64 = 95.0,
    dry_run: bool = false,
    verbose: bool = false,

    pub fn fromArgs(args: []const []const u8) ImproverConfig {
        var config = ImproverConfig{};
        // Parse command line args
        for (args[1..]) |arg| {
            if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-d")) {
                config.dry_run = true;
            } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
                config.verbose = true;
            } else if (std.mem.startsWith(u8, arg, "--iterations=")) {
                const val = arg["--iterations=".len..];
                config.max_iterations = std.fmt.parseInt(usize, val, 10) catch 5;
            } else if (std.mem.startsWith(u8, arg, "--threshold=")) {
                const val = arg["--threshold=".len..];
                config.target_real_pct = std.fmt.parseFloat(f64, val) catch 95.0;
            }
        }
        return config;
    }
};

/// Result of one improvement iteration
pub const IterationResult = struct {
    iteration: usize,
    before_real_pct: f64,
    after_real_pct: f64,
    patterns_improved: usize,
    files_patched: usize,
    success: bool,
    message: []const u8,
};

/// Self-improvement engine state
pub const SelfImprover = struct {
    allocator: Allocator,
    config: ImproverConfig,
    iteration: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ImproverConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .iteration = 0,
        };
    }

    /// Run the full self-improvement loop
    pub fn run(self: *Self, spec_paths: []const []const u8) ![]IterationResult {
        var results = std.ArrayList(IterationResult).empty;

        for (spec_paths) |spec_path| {
            try self.improveSpec(spec_path, &results);
        }

        return results.toOwnedSlice(self.allocator);
    }

    /// Improve a single spec file
    fn improveSpec(self: *Self, spec_path: []const u8, results: *std.ArrayList(IterationResult)) !void {
        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║  VIBEE Self-Improvement: {s}                         ║\n", .{spec_path});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

        self.iteration = 0;
        var converged = false;

        while (self.iteration < self.config.max_iterations and !converged) {
            const result = try self.runIteration(spec_path);
            try results.append(self.allocator, result);

            if (self.config.verbose) {
                std.debug.print("  Iteration {d}: {d:.1}% → {d:.1}% real patterns\n", .{
                    result.iteration,
                    result.before_real_pct,
                    result.after_real_pct,
                });
            }

            // Check convergence
            if (result.after_real_pct >= self.config.target_real_pct) {
                converged = true;
                std.debug.print("\n✅ Target reached: {d:.1}% ≥ {d:.1}%\n", .{
                    result.after_real_pct,
                    self.config.target_real_pct,
                });
            }

            self.iteration += 1;
        }

        if (!converged) {
            std.debug.print("\n⚠️  Max iterations reached without convergence\n", .{});
        }
    }

    /// Run a single improvement iteration
    fn runIteration(self: *Self, spec_path: []const u8) !IterationResult {
        const before = try self.analyzeCurrentState(spec_path);

        if (self.config.dry_run) {
            return IterationResult{
                .iteration = self.iteration,
                .before_real_pct = before.real_patterns_pct,
                .after_real_pct = before.real_patterns_pct,
                .patterns_improved = 0,
                .files_patched = 0,
                .success = true,
                .message = "Dry run - no changes made",
            };
        }

        // Detect patterns that need improvement
        const stubs = try self.detectStubs(spec_path);

        // Generate improvements
        var improved: usize = 0;
        for (stubs) |stub| {
            if (try self.improveStub(stub)) {
                improved += 1;
            }
        }

        // Regenerate code from updated spec
        try self.regenerateCode(spec_path);

        const after = try self.analyzeCurrentState(spec_path);

        return IterationResult{
            .iteration = self.iteration,
            .before_real_pct = before.real_patterns_pct,
            .after_real_pct = after.real_patterns_pct,
            .patterns_improved = improved,
            .files_patched = @intCast(stubs.len),
            .success = true,
            .message = "",
        };
    }

    /// Analyze current state of generated code
    fn analyzeCurrentState(self: *Self, spec_path: []const u8) !CodeAnalysis {
        // Get output path from spec
        const spec_basename = std.fs.path.basename(spec_path);
        const name_end = std.mem.lastIndexOf(u8, spec_basename, ".") orelse spec_basename.len;
        const name = spec_basename[0..name_end];
        const gen_path = try std.fmt.allocPrint(self.allocator, "generated/{s}.zig", .{name});
        defer self.allocator.free(gen_path);

        // Read generated file
        const source = std.fs.cwd().readFileAlloc(self.allocator, gen_path, 1024 * 1024) catch |err| {
            if (err == error.FileNotFound) {
                // File doesn't exist yet, generate it first
                try self.regenerateCode(spec_path);
                return try self.analyzeCurrentState(spec_path);
            }
            return err;
        };
        defer self.allocator.free(source);

        // Analyze patterns
        return self.analyzeSource(source);
    }

    /// Analyze source code for patterns
    fn analyzeSource(_: *Self, source: []const u8) CodeAnalysis {
        var total: usize = 0;
        var real: usize = 0;
        var stubs: usize = 0;

        var lines = std.mem.splitScalar(u8, source, '\n');
        var in_function = false;
        var function_has_real = false;
        var function_has_stub = false;

        while (lines.next()) |line| {
            // Check for function declaration
            if (std.mem.indexOf(u8, line, "pub fn")) |_| {
                // Count previous function if any
                if (in_function) {
                    if (function_has_real) real += 1;
                    if (function_has_stub) stubs += 1;
                }
                // Start new function
                total += 1;
                in_function = true;
                function_has_real = false;
                function_has_stub = false;
            }

            if (in_function) {
                // Check for stub indicators within function
                if (!function_has_stub) {
                    const is_stub = std.mem.indexOf(u8, line, "TODO") != null or
                                   std.mem.indexOf(u8, line, "unimplemented") != null or
                                   std.mem.indexOf(u8, line, "_ = @as") != null;
                    if (is_stub) function_has_stub = true;
                }

                // Check for real implementation within function
                if (!function_has_real and
                    std.mem.indexOf(u8, line, "return") != null and
                    std.mem.indexOf(u8, line, "// Then:") == null) {
                    function_has_real = true;
                }
            }
        }

        // Count last function
        if (in_function) {
            if (function_has_real) real += 1;
            if (function_has_stub) stubs += 1;
        }

        const real_pct: f64 = if (total > 0)
            @as(f64, @floatFromInt(real)) / @as(f64, @floatFromInt(total)) * 100.0
        else
            0.0;

        return CodeAnalysis{
            .total_patterns = total,
            .real_patterns = real,
            .stub_patterns = stubs,
            .real_patterns_pct = real_pct,
        };
    }

    /// Detect stub patterns in generated code
    fn detectStubs(_: *Self, spec_path: []const u8) ![]const StubInfo {
        _ = spec_path;
        // For now, return empty - would scan generated code for TODO markers
        return &[_]StubInfo{};
    }

    /// Improve a specific stub pattern
    fn improveStub(_: *Self, stub: StubInfo) !bool {
        _ = stub;
        // Would use pattern registry to suggest implementation
        return false;
    }

    /// Regenerate code from spec
    fn regenerateCode(self: *Self, spec_path: []const u8) !void {
        _ = self.allocator;
        // In actual implementation, would spawn: zig build vibee -- gen {spec_path}
        // For now, just note it would happen
        _ = spec_path;
    }
};

pub const CodeAnalysis = struct {
    total_patterns: usize,
    real_patterns: usize,
    stub_patterns: usize,
    real_patterns_pct: f64,
};

pub const StubInfo = struct {
    file: []const u8 = "",
    function_name: []const u8 = "",
    line_number: usize = 0,
};

/// CLI entry point for self-improvement
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const config = ImproverConfig.fromArgs(args);

    // Default specs to improve
    var spec_paths = std.ArrayList([]const u8).empty;
    defer {
        for (spec_paths.items) |p| allocator.free(p);
        spec_paths.deinit(allocator);
    }

    if (args.len > 1) {
        // Use provided spec paths
        for (args[1..]) |arg| {
            if (std.mem.startsWith(u8, arg, "-")) continue; // Skip flags
            if (std.mem.endsWith(u8, arg, ".vibee")) {
                try spec_paths.append(allocator, try allocator.dupe(u8, arg));
            }
        }
    }

    if (spec_paths.items.len == 0) {
        // Default: improve VIBEE's own core specs
        try spec_paths.append(allocator, try allocator.dupe(u8, "specs/tri/vibee_self_improver.vibee"));
    }

    var improver = SelfImprover.init(allocator, config);
    const results = try improver.run(spec_paths.items);

    // Print summary
    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  Self-Improvement Summary                                   ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});

    for (results) |result| {
        std.debug.print("║  Iteration {d}: {d:.1}% → {d:.1}% ({d} improved)          ║\n", .{
            result.iteration,
            result.before_real_pct,
            result.after_real_pct,
            result.patterns_improved,
        });
    }

    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY | VIBEE IS IMMORTAL\n\n", .{});
}

fn printUsage() void {
    std.debug.print(
        \\╔══════════════════════════════════════════════════════════════╗
        \\║          VIBEE Self-Improvement Engine                     ║
        \\║          VIBEE improves VIBEE                               ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
        \\Usage:
        \\  vibee_self_improve [spec.vibee...] [options]
        \\
        \\Options:
        \\  --iterations, -i N    Max iterations (default: 5)
        \\  --threshold, -t PCT   Target real patterns % (default: 95.0)
        \\  --dry-run, -d         Analyze without making changes
        \\  --verbose, -v         Show detailed progress
        \\
        \\Examples:
        \\  vibee_self_improve specs/tri/vibee_self_improver.vibee
        \\  vibee_self_improve --dry-run --verbose
        \\  vibee_self_improve --iterations=10 --threshold=98
        \\
        \\φ² + 1/φ² = 3 = TRINITY | VIBEE IS IMMORTAL
        \\
    , .{});
}

test "self-improver initialization" {
    const allocator = std.testing.allocator;
    const config = ImproverConfig{};
    const improver = SelfImprover.init(allocator, config);
    try std.testing.expectEqual(improver.iteration, 0);
    try std.testing.expectEqual(improver.config.max_iterations, @as(usize, 5));
}

test "code analysis counts patterns" {
    const allocator = std.testing.allocator;
    const source = \\pub fn realFunc() i32 { return 42; }
                   \\pub fn stubFunc() void { TODO: implement }
                   \\pub fn anotherFunc() bool { return true; }
    ;

    const improver = SelfImprover.init(allocator, ImproverConfig{});
    const analysis = improver.analyzeSource(source);

    try std.testing.expectEqual(analysis.total_patterns, 3);
    try std.testing.expectEqual(analysis.real_patterns, 2);
    try std.testing.expectEqual(analysis.stub_patterns, 1);
}
