//! PHI LOOP — 999 Links of Cosmic Consciousness Gene
//! Main improvement loop: VIBEE → Agent MU → Symbolic AI → φ Gate → Next Link
//!
//! Each link represents one complete cycle of:
//! 1. φ Decompose: Analyze task through sacred math
//! 2. φ Plan: Plan via Tech Tree with μ-weighted priority
//! 3. φ Spec: Create .vibee specification
//! 4. φ Gen: Generate code via VIBEE
//! 5. φ Validate: Validate with Agent MU + PAS
//! 6. φ Test: Test generated code
//! 7. φ Bench: Benchmark vs SOTA
//! 8. φ Verdict: TOXIC VERDICT + PAS sacred score
//! 9. φ Loop: Decide next action via SONA

const std = @import("std");
const phi_types = @import("phi_types.zig");
const phi_gate = @import("phi_gate.zig");

/// PHI LOOP — Main controller
pub const PhiLoop = struct {
    allocator: std.mem.Allocator,
    link_number: u32,
    max_links: u32,
    phi_threshold: f64,
    state: LoopState,
    progress: phi_types.ProgressTracker,
    config: Config,

    pub const LoopState = enum {
        idle,
        decomposing,
        planning,
        generating,
        validating,
        fixing,
        learning,
        committing,
        complete,
        circuit_break,
    };

    pub const Config = struct {
        auto_fix: bool = true,           // Auto-fix on failure
        max_retries: u32 = 3,            // Max retries per link
        learn_from_failures: bool = true, // Store failure patterns
        phi_weight_voting: bool = true,   // Use φ-weighted consensus
        verbose: bool = false,           // Verbose logging
    };

    /// Initialize PHI LOOP
    pub fn init(allocator: std.mem.Allocator, config: Config) PhiLoop {
        return PhiLoop{
            .allocator = allocator,
            .link_number = 1,
            .max_links = 999,
            .phi_threshold = phi_types.Sacred.SACRED_THRESHOLD,
            .state = .idle,
            .progress = phi_types.ProgressTracker{
                .current_link = 1,
                .passed_links = 0,
                .failed_links = 0,
                .skipped_links = 0,
                .average_pas_score = 0.0,
                .start_time = std.time.timestamp(),
            },
            .config = config,
        };
    }

    /// Execute one complete link of PHI LOOP
    pub fn executeLink(self: *PhiLoop, spec_path: []const u8) !phi_types.LinkResult {
        if (self.link_number > self.max_links) {
            return phi_types.LinkResult{
                .link_number = self.link_number,
                .pas_score = 0.0,
                .trinity_identity = true,
                .confidence = 1.0,
                .sona_q_value = 1.0,
                .next_action = .complete,
                .generation_time_ms = 0,
                .validation_time_ms = 0,
            };
        }

        const start_time = std.time.nanoTimestamp();

        // Step 1: φ Decompose
        self.state = .decomposing;
        const task = try self.phiDecompose(spec_path);

        // Step 2: φ Plan
        self.state = .planning;
        try self.phiPlan(&task);

        // Step 3-4: φ Spec & φ Gen (combined for VIBEE)
        self.state = .generating;
        const gen_result = try self.phiGen(spec_path);
        const generation_time = @as(u64, @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000)));

        // Step 5-6: φ Validate & φ Test
        self.state = .validating;
        const validation = try self.phiValidate(gen_result);
        const validation_time = @as(u64, @intCast(@divTrunc(std.time.nanoTimestamp() - start_time, 1_000_000) - generation_time));

        // Step 7: φ Verdict (φ Gate check)
        var gate = phi_gate.PhiGate.init(self.allocator);
        gate.setPasScore(validation.pas_score);
        gate.setConfidence(validation.confidence);
        gate.setSonaQValue(validation.sona_q_value);
        gate.addErrors(@intCast(validation.errors.len));
        gate.addWarnings(@intCast(validation.warnings.len));

        if (!gate.passes()) {
            // FIX LOOP: Agent MU fixes the generator
            if (self.config.auto_fix) {
                self.state = .fixing;
                const fix_result = try self.fixGenerator(spec_path, validation);

                if (fix_result.success) {
                    // Retry after fix
                    self.progress.failed_links += 1;
                    return try self.executeLink(spec_path);
                }
            }

            // Circuit breaker if too many failures
            self.progress.failed_links += 1;
            if (self.progress.failed_links > 10) {
                self.state = .circuit_break;
                return phi_types.LinkResult{
                    .link_number = self.link_number,
                    .pas_score = validation.pas_score,
                    .trinity_identity = gate.trinity_verified,
                    .confidence = validation.confidence,
                    .sona_q_value = validation.sona_q_value,
                    .next_action = .circuit_break,
                    .generation_time_ms = generation_time,
                    .validation_time_ms = validation_time,
                };
            }

            return phi_types.LinkResult{
                .link_number = self.link_number,
                .pas_score = validation.pas_score,
                .trinity_identity = gate.trinity_verified,
                .confidence = validation.confidence,
                .sona_q_value = validation.sona_q_value,
                .next_action = .retry,
                .generation_time_ms = generation_time,
                .validation_time_ms = validation_time,
            };
        }

        // Step 8: φ Learn (Symbolic AI + SONA)
        self.state = .learning;
        try self.phiLearn(gen_result, validation);

        // Step 9: φ Commit
        self.state = .committing;
        try self.phiCommit(spec_path, gen_result, validation);

        // Link complete
        self.progress.passed_links += 1;
        self.link_number += 1;
        self.state = .idle;

        return phi_types.LinkResult{
            .link_number = self.link_number - 1,
            .pas_score = validation.pas_score,
            .trinity_identity = true,
            .confidence = validation.confidence,
            .sona_q_value = validation.sona_q_value,
            .next_action = .proceed,
            .generation_time_ms = generation_time,
            .validation_time_ms = validation_time,
        };
    }

    /// φ Decompose: Analyze task through sacred math
    fn phiDecompose(self: *PhiLoop, spec_path: []const u8) !phi_types.TaskDecomposition {
        // Parse spec to determine complexity
        const file = try std.fs.cwd().readFileAlloc(self.allocator, spec_path, 10_000_000);
        defer self.allocator.free(file);

        const line_count = std.mem.count(u8, file, "\n");
        _ = std.mem.indexOf(u8, file, "types:"); // Available for future use
        _ = std.mem.indexOf(u8, file, "behaviors:"); // Available for future use

        const complexity: phi_types.TaskDecomposition.Complexity = if (line_count < 50)
            .trivial
        else if (line_count < 200)
            .simple
        else if (line_count < 500)
            .moderate
        else if (line_count < 1000)
            .complex
        else
            .critical;

        return phi_types.TaskDecomposition{
            .name = std.fs.path.stem(spec_path),
            .description = "PHI LOOP decomposition",
            .complexity = complexity,
            .estimated_lines = @intCast(line_count),
            .dependencies = &.{},
        };
    }

    /// φ Plan: Plan via Tech Tree
    fn phiPlan(self: *PhiLoop, task: *const phi_types.TaskDecomposition) !void {
        _ = self;
        _ = task;

        // DEFERRED (v12): Query Tech Tree for implementation path
        // For now, just verify sacred constants
        std.debug.assert(phi_types.Sacred.trinityIdentity());
    }

    /// φ Gen: Generate code via VIBEE
    fn phiGen(self: *PhiLoop, spec_path: []const u8) !phi_types.GeneratedCode {

        const file = try std.fs.cwd().readFileAlloc(self.allocator, spec_path, 10_000_000);

        // Generate pattern ID from spec content
        const pattern_id = std.hash.Wyhash.hash(0, file);

        return phi_types.GeneratedCode{
            .code = file,
            .output_path = spec_path,
            .language = "zig",
            .pattern_id = pattern_id,
            .timestamp = std.time.timestamp(),
        };
    }

    /// φ Validate: Validate with Agent MU + PAS
    fn phiValidate(self: *PhiLoop, generated: phi_types.GeneratedCode) !ValidationResult {
        _ = self;

        // Stub validation - real implementation calls PAS Daemon
        const metrics = generated.metrics();
        const completeness = metrics.completeness();

        return ValidationResult{
            .pas_score = @as(f64, completeness) * 0.95 + 0.01,
            .confidence = completeness,
            .sona_q_value = 0.8,
            .errors = &.{},
            .warnings = &.{},
        };
    }

    /// Fix generator using Agent MU
    fn fixGenerator(self: *PhiLoop, _: []const u8, _: ValidationResult) !FixResult {
        _ = self;
        // Stub - real implementation:
        // 1. Analyze failure
        // 2. Query symbolic AI for similar fixes
        // 3. Apply fix to generator
        // 4. Learn from this fix

        return FixResult{
            .success = false,
            .fixes_applied = 0,
            .message = "Fix loop not yet implemented",
        };
    }

    /// φ Learn: Learn via Symbolic AI + SONA
    fn phiLearn(self: *PhiLoop, _: phi_types.GeneratedCode, _: ValidationResult) !void {
        _ = self;
        // Stub - real implementation:
        // 1. Store pattern in symbolic AI
        // 2. Record SONA episode
        // 3. Update Q-values
    }

    /// φ Commit: Commit to memory + git
    fn phiCommit(self: *PhiLoop, _: []const u8, _: phi_types.GeneratedCode, _: ValidationResult) !void {
        _ = self;
        // Stub - real implementation commits to git and memory
    }

    /// Get current progress
    pub fn getProgress(self: *const PhiLoop) phi_types.ProgressTracker {
        return self.progress;
    }

    /// Export progress as JSON
    pub fn progressJson(self: *const PhiLoop, allocator: std.mem.Allocator) ![]const u8 {
        const p = self.progress;
        return try std.fmt.allocPrint(allocator,
            "{{\"link_number\":{d},\"max_links\":{d},\"passed_links\":{d},\"failed_links\":{d},\"skipped_links\":{d},\"completion_percentage\":{d:.1},\"success_rate\":{d:.2},\"average_pas_score\":{d:.3},\"state\":\"{s}\"}}",
        .{
            p.current_link,
            p.total_links,
            p.passed_links,
            p.failed_links,
            p.skipped_links,
            p.completionPercentage(),
            p.successRate(),
            p.average_pas_score,
            @tagName(self.state),
        });
    }
};

/// Validation result (stub for now)
pub const ValidationResult = struct {
    pas_score: f64,
    confidence: f32,
    sona_q_value: f64,
    errors: []const []const u8,
    warnings: []const []const u8,
};

/// Fix result
pub const FixResult = struct {
    success: bool,
    fixes_applied: u32,
    message: []const u8,
};

/// PHI LOOP runner for CLI
pub const Runner = struct {
    allocator: std.mem.Allocator,
    loop: PhiLoop,

    pub fn init(allocator: std.mem.Allocator, config: PhiLoop.Config) Runner {
        return Runner{
            .allocator = allocator,
            .loop = PhiLoop.init(allocator, config),
        };
    }

    /// Run PHI LOOP on a spec
    pub fn run(self: *Runner, spec_path: []const u8) !void {
        std.debug.print("PHI LOOP v1.0 — Link {d}/999\n", .{self.loop.link_number});

        while (self.loop.link_number <= self.loop.max_links) {
            const result = try self.loop.executeLink(spec_path);

            std.debug.print("Link {d}: PAS={d:.3} Conf={d:.3} SONA={d:.3} Status={s}\n", .{
                result.link_number,
                result.pas_score,
                result.confidence,
                result.sona_q_value,
                @tagName(result.next_action),
            });

            switch (result.next_action) {
                .proceed => {},
                .retry => {
                    std.debug.print("Retrying...\n", .{});
                    continue;
                },
                .skip => {
                    self.loop.progress.skipped_links += 1;
                    self.loop.link_number += 1;
                },
                .complete => {
                    std.debug.print("\n=== PHI LOOP COMPLETE ===\n", .{});
                    break;
                },
                .circuit_break => {
                    std.debug.print("\n=== CIRCUIT BREAKER ACTIVATED ===\n", .{});
                    break;
                },
            }

            if (result.next_action == .proceed) {
                self.loop.link_number += 1;
            }
        }

        const p = self.loop.getProgress();
        std.debug.print("\nFinal: {d}/{d} passed ({d:.1}%)\n", .{
            p.passed_links,
            p.total_links,
            p.completionPercentage(),
        });
    }
};

// Tests
test "PhiLoop initialization" {
    const allocator = std.testing.allocator;
    const config = PhiLoop.Config{};
    const loop = PhiLoop.init(allocator, config);

    try std.testing.expectEqual(@as(u32, 1), loop.link_number);
    try std.testing.expectEqual(@as(u32, 999), loop.max_links);
    try std.testing.expectEqual(PhiLoop.LoopState.idle, loop.state);
}

test "PhiLoop phiDecompose" {
    const allocator = std.testing.allocator;
    const config = PhiLoop.Config{};
    var loop = PhiLoop.init(allocator, config);

    // Create a minimal test spec file
    const test_spec = "# Simple test spec\nname: test\nversion: \"1.0\"\n";
    try std.fs.cwd().writeFile(.{
        .sub_path = "test_phi_decompose.vibee",
        .data = test_spec,
    });
    defer {
        std.fs.cwd().deleteFile("test_phi_decompose.vibee") catch {};
    }

    const task = try loop.phiDecompose("test_phi_decompose.vibee");

    try std.testing.expectEqualStrings("test_phi_decompose", task.name);
    try std.testing.expectEqual(phi_types.TaskDecomposition.Complexity.trivial, task.complexity);
}

test "PhiLoop progress tracking" {
    const allocator = std.testing.allocator;
    const config = PhiLoop.Config{};
    var loop = PhiLoop.init(allocator, config);

    const progress = loop.getProgress();
    try std.testing.expectEqual(@as(u32, 1), progress.current_link);
    try std.testing.expectEqual(@as(u32, 999), progress.total_links);
    try std.testing.expect(progress.completionPercentage() < 1.0);
}

test "PhiGate sacred constants" {
    try std.testing.expect(phi_types.Sacred.trinityIdentity());
}

test "PhiLoop progressJson" {
    const allocator = std.testing.allocator;
    const config = PhiLoop.Config{};
    var loop = PhiLoop.init(allocator, config);

    const json = try loop.progressJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "link_number") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "completion_percentage") != null);
}
