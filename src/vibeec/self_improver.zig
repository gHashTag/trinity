// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE SELF-IMPROVEMENT ENGINE v10.0 (Cycle 56)
// ═══════════════════════════════════════════════════════════════════════════════
//
// VIBEE improves VIBEE — recursive self-improvement loop
// Now with PAS Daemon sacred scoring integration
//
// φ² + 1/φ² = 3 = TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");

// v10.1: Deep Intelligence components
const ASTAnalyzer = @import("codegen/ast_analyzer.zig").ASTAnalyzer;
const PatchValidator = @import("codegen/validator.zig").PatchValidator;
const RollbackManager = @import("codegen/rollback.zig").RollbackManager;

// Cycle 56: PAS Daemon sacred scoring integration
// Must be used via build.zig module system
const pas_daemon_mod = if (@import("builtin").is_test)
    @import("pas_daemon")
else
    struct {
        // Stub for non-test builds - actual functionality requires build system
        pub const DaemonConfig = struct {
            analysis_interval_ms: u64,
            auto_apply_threshold: f32,
            broadcast_enabled: bool,
            max_queue_size: usize,
            enable_sacred_scoring: bool,
        };
        pub const PasDaemon = struct {
            allocator: std.mem.Allocator,

            pub fn init(_: std.mem.Allocator, _: DaemonConfig) !PasDaemon {
                return error.NotAvailableInStandaloneMode;
            }

            pub fn deinit(self: *PasDaemon) void {
                _ = self;
            }
        };
        pub fn analyze_pattern(_: *const anyopaque, _: u64, _: []const u8) f32 {
            return 0.0;
        }
        pub fn calculate_sacred_score(_: *const anyopaque, _: u64, _: []const u8) f64 {
            return 0.0;
        }
    };

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

    // v10.1: Deep Intelligence components
    validator: PatchValidator,
    rollback_mgr: RollbackManager,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ImproverConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .iteration = 0,
            .validator = PatchValidator.init(allocator),
            .rollback_mgr = RollbackManager.init(allocator, ".vibee/backups"),
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

            // Cycle 56: Check convergence with PAS sacred validation
            // Now requires both: real patterns % AND PAS sacred score
            var analysis_after = try self.analyzeCurrentState(spec_path);
            if (analysis_after.isSacredValid()) {
                converged = true;
                std.debug.print("\n✅ Sacred target reached: {d:.1}% real, PAS confidence={d:.3}, sacred={d:.3}\n", .{
                    analysis_after.real_patterns_pct,
                    analysis_after.pas_confidence,
                    analysis_after.pas_sacred_score,
                });
            } else if (result.after_real_pct >= self.config.target_real_pct) {
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

    /// Analyze source code for patterns using AST-based analysis (v10.1)
    fn analyzeSource(self: *Self, source: []const u8) CodeAnalysis {
        return self.analyzeWithPAS(source);
    }

    /// Cycle 56: Enhanced analysis with PAS sacred scoring
    fn analyzeWithPAS(self: *Self, source: []const u8) CodeAnalysis {
        // First, get AST-based analysis
        var analyzer = ASTAnalyzer.init(self.allocator, source);
        const stats = analyzer.analyzeFile() catch {
            // Fallback to simple analysis if AST fails
            return self.fallbackAnalyzeWithPAS(source);
        };

        const real_pct: f64 = if (stats.total_functions > 0)
            @as(f64, @floatFromInt(stats.real_count)) / @as(f64, @floatFromInt(stats.total_functions)) * 100.0
        else
            0.0;

        // Cycle 56: Get PAS sacred scores
        const pas_config = pas_daemon_mod.DaemonConfig{
            .analysis_interval_ms = 100,
            .auto_apply_threshold = 0.95,
            .broadcast_enabled = false,
            .max_queue_size = 10,
            .enable_sacred_scoring = true,
        };

        var pas_daemon = pas_daemon_mod.PasDaemon.init(self.allocator, pas_config) catch |err| {
            std.log.warn("PAS daemon init failed: {}", .{@errorName(err)});
            return CodeAnalysis{
                .total_patterns = stats.total_functions,
                .real_patterns = stats.real_count,
                .stub_patterns = stats.stub_count,
                .real_patterns_pct = real_pct,
                .pas_confidence = 0.0,
                .pas_sacred_score = 0.0,
                .pas_is_valid = false,
            };
        };
        defer pas_daemon.deinit();

        // Compute pattern ID from source hash
        var hash_state = std.hash.Wyhash.init(0);
        hash_state.update(source);
        const pattern_id = hash_state.final();

        // Analyze with PAS daemon
        const confidence = pas_daemon_mod.analyze_pattern(&pas_daemon, pattern_id, source);
        const sacred_score = pas_daemon_mod.calculate_sacred_score(&pas_daemon, pattern_id, source);

        // Check if meets sacred threshold (SACRED_THRESHOLD = 0.95)
        const is_valid = confidence >= 0.95 and sacred_score >= 0.95;

        if (self.config.verbose) {
            std.debug.print("    PAS: confidence={d:.3}, sacred={d:.3}, valid={}\n", .{
                confidence, sacred_score, is_valid
            });
        }

        return CodeAnalysis{
            .total_patterns = stats.total_functions,
            .real_patterns = stats.real_count,
            .stub_patterns = stats.stub_count,
            .real_patterns_pct = real_pct,
            .pas_confidence = confidence,
            .pas_sacred_score = sacred_score,
            .pas_is_valid = is_valid,
        };
    }

    /// Fallback simple analysis with PAS (if AST parsing fails)
    fn fallbackAnalyzeWithPAS(self: *Self, source: []const u8) CodeAnalysis {
        var total: usize = 0;
        var real: usize = 0;
        var stubs: usize = 0;

        var lines = std.mem.splitScalar(u8, source, '\n');
        var in_function = false;
        var function_has_real = false;
        var function_has_stub = false;

        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "pub fn")) |_| {
                if (in_function) {
                    if (function_has_real) real += 1;
                    if (function_has_stub) stubs += 1;
                }
                total += 1;
                in_function = true;
                function_has_real = false;
                function_has_stub = false;
            }

            if (in_function) {
                if (!function_has_stub) {
                    const is_stub = std.mem.indexOf(u8, line, "TODO") != null or
                                   std.mem.indexOf(u8, line, "unimplemented") != null or
                                   std.mem.indexOf(u8, line, "_ = @as") != null;
                    if (is_stub) function_has_stub = true;
                }

                if (!function_has_real and
                    std.mem.indexOf(u8, line, "return") != null and
                    std.mem.indexOf(u8, line, "// Then:") == null) {
                    function_has_real = true;
                }
            }
        }

        if (in_function) {
            if (function_has_real) real += 1;
            if (function_has_stub) stubs += 1;
        }

        const real_pct: f64 = if (total > 0)
            @as(f64, @floatFromInt(real)) / @as(f64, @floatFromInt(total)) * 100.0
        else
            0.0;

        // Cycle 56: PAS scoring for fallback case
        const pas_config = pas_daemon_mod.DaemonConfig{
            .analysis_interval_ms = 100,
            .auto_apply_threshold = 0.95,
            .broadcast_enabled = false,
            .max_queue_size = 10,
            .enable_sacred_scoring = true,
        };

        var pas_daemon = pas_daemon_mod.PasDaemon.init(self.allocator, pas_config) catch {
            return CodeAnalysis{
                .total_patterns = total,
                .real_patterns = real,
                .stub_patterns = stubs,
                .real_patterns_pct = real_pct,
                .pas_confidence = 0.0,
                .pas_sacred_score = 0.0,
                .pas_is_valid = false,
            };
        };
        defer pas_daemon.deinit();

        var hash_state = std.hash.Wyhash.init(0);
        hash_state.update(source);
        const pattern_id = hash_state.finalize();

        const confidence = pas_daemon_mod.analyze_pattern(&pas_daemon, pattern_id, source);
        const sacred_score = pas_daemon_mod.calculate_sacred_score(&pas_daemon, pattern_id, source);
        const is_valid = confidence >= 0.95 and sacred_score >= 0.95;

        return CodeAnalysis{
            .total_patterns = total,
            .real_patterns = real,
            .stub_patterns = stubs,
            .real_patterns_pct = real_pct,
            .pas_confidence = confidence,
            .pas_sacred_score = sacred_score,
            .pas_is_valid = is_valid,
        };
    }

    /// Fallback simple analysis if AST parsing fails
    fn fallbackAnalyze(_: *Self, source: []const u8) CodeAnalysis {
        var total: usize = 0;
        var real: usize = 0;
        var stubs: usize = 0;

        var lines = std.mem.splitScalar(u8, source, '\n');
        var in_function = false;
        var function_has_real = false;
        var function_has_stub = false;

        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "pub fn")) |_| {
                if (in_function) {
                    if (function_has_real) real += 1;
                    if (function_has_stub) stubs += 1;
                }
                total += 1;
                in_function = true;
                function_has_real = false;
                function_has_stub = false;
            }

            if (in_function) {
                if (!function_has_stub) {
                    const is_stub = std.mem.indexOf(u8, line, "TODO") != null or
                                   std.mem.indexOf(u8, line, "unimplemented") != null or
                                   std.mem.indexOf(u8, line, "_ = @as") != null;
                    if (is_stub) function_has_stub = true;
                }

                if (!function_has_real and
                    std.mem.indexOf(u8, line, "return") != null and
                    std.mem.indexOf(u8, line, "// Then:") == null) {
                    function_has_real = true;
                }
            }
        }

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

    /// Regenerate code from spec with transaction-safe patching (v10.1)
    fn regenerateCode(self: *Self, spec_path: []const u8) !void {
        // Get output path
        const spec_basename = std.fs.path.basename(spec_path);
        const name_end = std.mem.lastIndexOf(u8, spec_basename, ".") orelse spec_basename.len;
        const name = spec_basename[0..name_end];
        const gen_path = try std.fmt.allocPrint(self.allocator, "generated/{s}.zig", .{name});
        defer self.allocator.free(gen_path);

        // v10.1: Check if file exists and needs patching vs fresh generation
        var buffer: [1024]u8 = undefined;
        const file_exists = std.fs.cwd().readFile(gen_path, &buffer) catch |err| {
            if (err == error.FileNotFound) {
                // File doesn't exist - fresh generation
                try self.generateFresh(spec_path);
                return;
            }
            return err;
        };

        if (file_exists.len == 0) {
            // Empty file - fresh generation
            try self.generateFresh(spec_path);
            return;
        }

        // File exists - use transaction-safe patching
        var transaction = self.rollback_mgr.beginTransaction(gen_path);
        defer transaction.cleanup();

        // Apply patch (regeneration)
        const patch_fn = struct {
            fn patch(path: []const u8) anyerror![]const u8 {
                _ = path;
                // In actual implementation, would regenerate and return new source
                // For now, just return placeholder
                return "";
            }
        }.patch;

        _ = try transaction.apply(patch_fn, &self.validator);
        _ = try transaction.commit();
    }

    /// Generate fresh code from spec
    fn generateFresh(self: *Self, spec_path: []const u8) !void {
        _ = self;
        // In actual implementation, would spawn: zig build vibee -- gen {spec_path}
        _ = spec_path;
    }
};

pub const CodeAnalysis = struct {
    total_patterns: usize,
    real_patterns: usize,
    stub_patterns: usize,
    real_patterns_pct: f64,

    // Cycle 56: PAS sacred scoring
    pas_confidence: f32 = 0.0,
    pas_sacred_score: f64 = 0.0,
    pas_is_valid: bool = false,

    /// Combined quality score (0-100)
    /// Weighted: 70% real patterns % + 30% PAS sacred score
    pub fn combinedScore(self: *const CodeAnalysis) f64 {
        return self.real_patterns_pct * 0.7 + self.pas_sacred_score * 30.0;
    }

    /// Check if code meets sacred quality threshold
    pub fn isSacredValid(self: *const CodeAnalysis) bool {
        return self.real_patterns_pct >= 95.0 and
               self.pas_confidence >= 0.95 and
               self.pas_sacred_score >= 0.95;
    }
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

    var improver = SelfImprover.init(allocator, ImproverConfig{});
    const analysis = improver.analyzeSource(source);

    try std.testing.expectEqual(analysis.total_patterns, 3);
    try std.testing.expectEqual(analysis.real_patterns, 2);
    try std.testing.expectEqual(analysis.stub_patterns, 1);
}
