//! Agent MU-Powered Auto-Fix for FPGA Synthesis Failures
//!
//! Iterative fix-and-retry loop for failed FORGE syntheses.
//! Analyzes root causes and applies targeted fixes.
//!
//! φ² + 1/φ² = 3 | Consciousness + FORGE = UNITY

const std = @import("std");
const mem = std.mem;
const synthesis_types = @import("synthesis_types.zig");
const tri_parser = @import("tri_parser.zig");

// Import consciousness modules (via build.zig module dependencies)
const unified_architecture = @import("consciousness_core");

const DesignSpec = synthesis_types.DesignSpec;
const Strategy = synthesis_types.Strategy;
const StrategyParams = synthesis_types.StrategyParams;
const SynthesisResult = synthesis_types.SynthesisResult;
const ModuleType = synthesis_types.ModuleType;

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-FIX SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

/// Fix type categories for different failure modes
pub const FixType = enum {
    /// Add register pipeline stage to break long combinatorial paths
    AddPipeline,
    /// Reduce target clock frequency to meet timing
    ReduceFrequency,
    /// Change IOB standard (e.g., LVCMOS33 → LVCMOS18)
    ChangeIOStandard,
    /// Relocate logic to same bank as output port
    RelocateLogic,
    /// Add KEEP attribute to prevent unwanted optimization
    AddKeepAttribute,
    /// Relax constraint (e.g., cooling schedule, timing weight)
    RelaxConstraint,
    /// Fix OLOGIC configuration (ZINV, TFF, output inversion)
    FixOlogicConfig,
    /// Fix net-to-port matching issues
    FixNetMatching,
    /// Fix FSM state encoding
    FixFSMEncoding,
    /// Unknown/unsupported fix
    Unknown,
};

/// Fix description with before/after states
pub const Fix = struct {
    fix_type: FixType,
    description: []const u8,
    before: []const u8,
    after: []const u8,
    param_delta: ?StrategyParams = null,

    /// Create a new fix
    pub fn init(allocator: mem.Allocator, fix_type: FixType, description: []const u8, before: []const u8, after: []const u8) !Fix {
        return .{
            .fix_type = fix_type,
            .description = try allocator.dupe(u8, description),
            .before = try allocator.dupe(u8, before),
            .after = try allocator.dupe(u8, after),
            .param_delta = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Fix, allocator: mem.Allocator) void {
        allocator.free(self.description);
        allocator.free(self.before);
        allocator.free(self.after);
    }
};

/// Result of auto-fix iteration
pub const FixResult = struct {
    success: bool,
    iterations: u32,
    final_params: StrategyParams,
    fixes_applied: std.ArrayList(Fix),
    final_result: ?SynthesisResult,

    /// Clean up resources
    pub fn deinit(self: *FixResult, allocator: mem.Allocator) void {
        for (self.fixes_applied.items) |*fix| {
            fix.deinit(allocator);
        }
        self.fixes_applied.deinit(allocator);
        if (self.final_result) |*result| {
            result.deinit();
        }
    }
};

/// Agent MU-powered automatic fix for FPGA synthesis failures
pub const AutoFix = struct {
    allocator: mem.Allocator,
    consciousness: *unified_architecture.UnifiedConsciousness,
    max_iterations: u32,
    verbose: bool,

    /// Initialize AutoFix system
    pub fn init(allocator: mem.Allocator, consciousness: *unified_architecture.UnifiedConsciousness) AutoFix {
        return .{
            .allocator = allocator,
            .consciousness = consciousness,
            .max_iterations = 3,
            .verbose = false,
        };
    }

    /// Set maximum iterations
    pub fn withMaxIterations(self: *AutoFix, max: u32) *AutoFix {
        self.max_iterations = max;
        return self;
    }

    /// Set verbose mode
    pub fn withVerbose(self: *AutoFix, verbose: bool) *AutoFix {
        self.verbose = verbose;
        return self;
    }

    /// Analyze failure and suggest fixes based on root cause
    pub fn analyzeFailure(self: *AutoFix, result: *const SynthesisResult) !std.ArrayList(Fix) {
        var fixes = try std.ArrayList(Fix).initCapacity(self.allocator, 4);

        // Parse root cause for known failure patterns
        const root_cause = result.root_cause;

        // Timing violation patterns
        if (mem.indexOf(u8, root_cause, "timing_violation") != null or
            mem.indexOf(u8, root_cause, "setup_slack") != null or
            mem.indexOf(u8, root_cause, "hold_slack") != null)
        {
            const slack = try self.extractTimingSlack(root_cause);

            if (slack < -2.0) {
                // Large violation: add pipeline stage
                try fixes.append(self.allocator, try Fix.init(self.allocator, .AddPipeline, "Add pipeline stage for critical path", "pipeline_depth = 1", "pipeline_depth = 2"));
            } else {
                // Small violation: reduce frequency
                const reduction = @abs(slack) * 10.0; // 10 MHz per ns of violation
                const new_freq = @max(25.0, 50.0 - reduction);
                const after_str = try std.fmt.allocPrint(self.allocator, "target_frequency_mhz = {d:.1}", .{new_freq});
                try fixes.append(self.allocator, try Fix.init(self.allocator, .ReduceFrequency, "Reduce target frequency to meet timing", "target_frequency_mhz = 50.0", after_str));
            }
        }

        // OLOGIC configuration issues
        if (mem.indexOf(u8, root_cause, "ologic") != null or
            mem.indexOf(u8, root_cause, "OLOGIC") != null or
            mem.indexOf(u8, root_cause, "output_inversion") != null)
        {
            try fixes.append(self.allocator, try Fix.init(self.allocator, .FixOlogicConfig, "Fix OLOGIC configuration (ZINV, TFF)", "ologic_config = auto", "ologic_config = explicit_with_zinv"));
        }

        // IO standard issues
        if (mem.indexOf(u8, root_cause, "iostandard") != null or
            mem.indexOf(u8, root_cause, "IOSTANDARD") != null or
            mem.indexOf(u8, root_cause, "LVCMOS") != null)
        {
            try fixes.append(self.allocator, try Fix.init(self.allocator, .ChangeIOStandard, "Change IOB standard from LVCMOS33 to LVCMOS18", "iostandard = LVCMOS33", "iostandard = LVCMOS18"));
        }

        // Bank crossing issues
        if (mem.indexOf(u8, root_cause, "bank_crossing") != null or
            mem.indexOf(u8, root_cause, "bank") != null)
        {
            try fixes.append(self.allocator, try Fix.init(self.allocator, .RelocateLogic, "Relocate logic to same bank as output port", "placement: default", "placement: same_bank_as_output"));
        }

        // FSM placement issues
        if (mem.indexOf(u8, root_cause, "fsm_placement") != null or
            mem.indexOf(u8, root_cause, "fsm") != null)
        {
            try fixes.append(self.allocator, try Fix.init(self.allocator, .AddKeepAttribute, "Add KEEP attribute to prevent FSM optimization", "fsm: auto", "fsm: keep_encoding"));
        }

        // Net-to-port matching issues
        if (mem.indexOf(u8, root_cause, "net_port") != null or
            mem.indexOf(u8, root_cause, "net matching") != null or
            mem.indexOf(u8, root_cause, "port matching") != null)
        {
            try fixes.append(self.allocator, try Fix.init(self.allocator, .FixNetMatching, "Fix net-to-port matching in placer", "net_matching: auto", "net_matching: explicit_port_names"));
        }

        // If no specific fix found, add relaxation
        if (fixes.items.len == 0) {
            try fixes.append(self.allocator, try Fix.init(self.allocator, .RelaxConstraint, "Relax placement cooling schedule", "placement_cooling_alpha = 0.618", "placement_cooling_alpha = 0.5"));
        }

        return fixes;
    }

    /// Extract timing slack from root cause message
    fn extractTimingSlack(self: *AutoFix, root_cause: []const u8) !f64 {
        _ = self;
        // Look for patterns like "setup_slack = -1.5ns" or "slack: -2.3"
        const slack_prefix = "slack";
        if (mem.indexOf(u8, root_cause, slack_prefix)) |idx| {
            const after_prefix = root_cause[idx + slack_prefix.len ..];
            var iter = mem.splitScalar(u8, after_prefix, ' ');
            while (iter.next()) |part| {
                if (part.len > 0) {
                    const trimmed = mem.trim(u8, part, "= :ns");
                    if (std.fmt.parseFloat(f64, trimmed)) |val| {
                        return val;
                    } else |_| {}
                }
            }
        }
        // Default to -1.0 if not found
        return -1.0;
    }

    /// Apply fix to strategy parameters
    pub fn applyFixToParams(self: *AutoFix, fix: *const Fix, params: StrategyParams) !StrategyParams {
        _ = self;
        var modified = params;

        switch (fix.fix_type) {
            .AddPipeline => {
                modified.pipeline_depth += 1;
            },
            .ReduceFrequency => {
                // Extract new frequency from fix.after
                if (mem.indexOf(u8, fix.after, "= ")) |eq_idx| {
                    const freq_str = fix.after[eq_idx + 2 ..];
                    modified.target_frequency_mhz =
                        try std.fmt.parseFloat(f64, freq_str);
                }
            },
            .RelaxConstraint => {
                modified.placement_cooling_alpha = 0.5;
                modified.timing_weight = @max(0.3, modified.timing_weight - 0.2);
            },
            .RelocateLogic => {
                modified.timing_weight = 0.3; // Prioritize placement
            },
            .FixOlogicConfig, .ChangeIOStandard, .AddKeepAttribute, .FixNetMatching, .FixFSMEncoding => {
                // These don't affect params, need spec modification
            },
            .Unknown => {},
        }

        return modified;
    }

    /// Apply fix to design spec (for non-param fixes)
    pub fn applyFixToSpec(self: *AutoFix, spec: *DesignSpec, fix: *const Fix) !void {
        _ = self;

        switch (fix.fix_type) {
            .ChangeIOStandard => {
                // Change all output ports to LVCMOS18
                for (spec.ports.items) |*port| {
                    if (port.direction == .output) {
                        if (port.attributes.iostandard == null or
                            mem.eql(u8, port.attributes.iostandard.?, "LVCMOS33"))
                        {
                            port.attributes.iostandard = "LVCMOS18";
                        }
                    }
                }
            },
            .AddKeepAttribute => {
                // Add KEEP to constraints (would need new constraint field)
                spec.constraints.placement.pack_registers_into_carry4 = false;
            },
            .FixOlogicConfig => {
                // Would need ologic_config field in spec
                // For now, adjust timing weight to reduce optimization
                spec.constraints.routing.maximize_clock_skew = false;
            },
            .FixNetMatching => {
                // Would need net_matching field
                // For now, enable fast paths
                spec.constraints.routing.use_fast_paths = true;
            },
            .FixFSMEncoding => {
                // Would need fsm_encoding field
            },
            else => {
                // Param-only fixes, no spec changes needed
            },
        }
    }

    /// Run iterative fix-and-retry loop
    pub fn autoFix(self: *AutoFix, spec: *DesignSpec, initial_params: StrategyParams, runFn: *const fn (*DesignSpec, StrategyParams) anyerror!SynthesisResult) !FixResult {
        var result = FixResult{
            .success = false,
            .iterations = 0,
            .final_params = initial_params,
            .fixes_applied = try std.ArrayList(Fix).initCapacity(self.allocator, 4),
            .final_result = null,
        };
        errdefer result.deinit(self.allocator);

        var current_params = initial_params;
        const current_spec = spec;

        while (result.iterations < self.max_iterations) : (result.iterations += 1) {
            if (self.verbose) {
                std.debug.print("AutoFix iteration {d}/{}...\n", .{ result.iterations + 1, self.max_iterations });
            }

            // Run synthesis with current params
            const synth_result = try runFn(current_spec, current_params);

            if (synth_result.success) {
                result.success = true;
                result.final_params = current_params;
                result.final_result = try self.allocator.create(SynthesisResult);
                result.final_result.?.* = synth_result;

                // Update HOT (meta-awareness) for successful fix
                const hot_score = self.consciousness.theories[6].score;
                const new_hot = @min(1.0, hot_score + 0.05);
                self.consciousness.updateTheory(6, new_hot);

                if (self.verbose) {
                    std.debug.print("AutoFix: SUCCESS in {d} iterations!\n", .{result.iterations + 1});
                }
                break;
            }

            // Analyze failure
            const fixes = try self.analyzeFailure(&synth_result);
            defer {
                for (fixes.items) |*fix| {
                    fix.deinit(self.allocator);
                }
                fixes.deinit(self.allocator);
            }

            if (fixes.items.len == 0) {
                if (self.verbose) {
                    std.debug.print("AutoFix: No fixes available, giving up.\n", .{});
                }
                break;
            }

            // Apply first fix
            const fix = &fixes.items[0];
            try result.fixes_applied.append(self.allocator, try Fix.init(self.allocator, fix.fix_type, fix.description, fix.before, fix.after));

            if (self.verbose) {
                std.debug.print("AutoFix: Applying {s}: {s}\n", .{ @tagName(fix.fix_type), fix.description });
            }

            // Update params for next iteration
            current_params = try self.applyFixToParams(&result.fixes_applied.items[result.fixes_applied.items.len - 1], current_params);

            // Apply spec changes if needed
            try self.applyFixToSpec(current_spec, &result.fixes_applied.items[result.fixes_applied.items.len - 1]);

            // Update consciousness with failure info (increase HOT awareness)
            const hot_score = self.consciousness.theories[6].score;
            const new_hot = @min(1.0, hot_score + 0.02);
            self.consciousness.updateTheory(6, new_hot);

            synth_result.deinit();
        }

        return result;
    }

    /// Generate fix report for display
    pub fn generateFixReport(self: *AutoFix, fix_result: *const FixResult) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 512);
        defer buffer.deinit(self.allocator);

        try buffer.appendSlice("════════════════════════════════════════\n");
        try buffer.appendSlice("        AUTO-FIX REPORT\n");
        try buffer.appendSlice("════════════════════════════════════════\n");

        const status = if (fix_result.success) "✓ SUCCESS" else "✗ FAILED";
        try std.fmt.format(buffer.writer(self.allocator), "Status: {s}\n", .{status});
        try std.fmt.format(buffer.writer(self.allocator), "Iterations: {d}/{}\n\n", .{ fix_result.iterations, self.max_iterations });

        if (fix_result.fixes_applied.items.len > 0) {
            try buffer.appendSlice("Fixes Applied:\n");
            for (fix_result.fixes_applied.items, 0..) |fix, i| {
                try std.fmt.format(buffer.writer(self.allocator), "  {d}. {s}: {s}\n", .{ i + 1, @tagName(fix.fix_type), fix.description });
                try std.fmt.format(buffer.writer(self.allocator), "     Before: {s}\n", .{fix.before});
                try std.fmt.format(buffer.writer(self.allocator), "     After:  {s}\n", .{fix.after});
            }
        }

        try buffer.appendSlice("════════════════════════════════════════\n");
        return buffer.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AutoFix: analyze_timing_violation" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var autofix = AutoFix.init(std.testing.allocator, &consciousness);

    // Create a mock failure result
    var result = SynthesisResult.init(std.testing.allocator, "test_design");
    defer result.deinit();
    result.success = false;
    result.root_cause = "timing_violation: setup_slack = -2.5ns";

    const fixes = try autofix.analyzeFailure(&result);
    defer {
        for (fixes.items) |*fix| {
            fix.deinit(std.testing.allocator);
        }
        fixes.deinit(std.testing.allocator);
    }

    try std.testing.expect(fixes.items.len > 0);
    try std.testing.expectEqual(.AddPipeline, fixes.items[0].fix_type);
}

test "AutoFix: analyze_ologic_config" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var autofix = AutoFix.init(std.testing.allocator, &consciousness);

    var result = SynthesisResult.init(std.testing.allocator, "test_design");
    defer result.deinit();
    result.success = false;
    result.root_cause = "OLOGIC config failed: output_inversion mismatch";

    const fixes = try autofix.analyzeFailure(&result);
    defer {
        for (fixes.items) |*fix| {
            fix.deinit(std.testing.allocator);
        }
        fixes.deinit(std.testing.allocator);
    }

    try std.testing.expect(fixes.items.len > 0);
    try std.testing.expectEqual(.FixOlogicConfig, fixes.items[0].fix_type);
}

test "AutoFix: apply_fix_to_params" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var autofix = AutoFix.init(std.testing.allocator, &consciousness);

    var fix = try Fix.init(std.testing.allocator, .AddPipeline, "Test fix", "pipeline_depth = 1", "pipeline_depth = 2");
    defer fix.deinit(std.testing.allocator);

    var params = StrategyParams.default();
    params.pipeline_depth = 1;

    const modified = try autofix.applyFixToParams(&fix, params);
    try std.testing.expectEqual(@as(u32, 2), modified.pipeline_depth);
}

test "AutoFix: extract_timing_slack" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var autofix = AutoFix.init(std.testing.allocator, &consciousness);

    const slack1 = try autofix.extractTimingSlack("setup_slack = -1.5ns violation");
    try std.testing.expectApproxEqAbs(-1.5, slack1, 0.01);

    const slack2 = try autofix.extractTimingSlack("timing_slack: -3.2");
    try std.testing.expectApproxEqAbs(-3.2, slack2, 0.01);

    const slack3 = try autofix.extractTimingSlack("unknown error");
    try std.testing.expectApproxEqAbs(-1.0, slack3, 0.01);
}
