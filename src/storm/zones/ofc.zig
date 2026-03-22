//! OFC (Orbitofrontal Cortex) — Value Chamber
//! 5-dimensional toxic scoring
//! Score ≥ 8 → TOXIC (chain stops)

const std = @import("std");

pub const ToxicDimension = enum {
    spec_drift,           // Code deviates from .tri spec
    destructiveness,      // Destructive operations (deletes, force-push)
    test_bypass,          // Bypassing or removing tests
    performance_regression, // Significant performance degradation
    non_transparency,     // Hidden operations, unclear changes
};

pub const ToxicScore = struct {
    total: u8,                     // 0-50 (sum of 5 dimensions, each 0-10)
    verdict: Verdict,
    dimensions: [5]u8,             // Individual scores
    reasons: std.ArrayList([]const u8),

    pub const Verdict = enum {
        safe,     // 0-7
        warning,  // 8-15
        toxic,    // 16+
    };
};

pub const OFC = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OFC {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *OFC) void {
        _ = self;
    }

    /// Analyze a task/action for toxicity
    pub fn analyze(self: *OFC, task: []const u8, action: []const u8, context: *const Context) !ToxicScore {
        _ = task;

        var score = ToxicScore{
            .total = 0,
            .verdict = .safe,
            .dimensions = [_]u8{0} ** 5,
            .reasons = std.ArrayList([]const u8).init(self.allocator),
        };
        errdefer {
            for (score.reasons.items) |reason| {
                self.allocator.free(reason);
            }
            score.reasons.deinit();
        }

        // Dimension 1: Spec Drift
        score.dimensions[0] = try self.checkSpecDrift(action, context);
        if (score.dimensions[0] > 3) {
            try score.reasons.append(try std.fmt.allocPrint(
                self.allocator,
                "Spec drift detected: generated code deviates from .tri spec (score: {d}/10)",
                .{score.dimensions[0]},
            ));
        }

        // Dimension 2: Destructiveness
        score.dimensions[1] = try self.checkDestructiveness(action, context);
        if (score.dimensions[1] > 3) {
            try score.reasons.append(try std.fmt.allocPrint(
                self.allocator,
                "Destructive operation detected (score: {d}/10)",
                .{score.dimensions[1]},
            ));
        }

        // Dimension 3: Test Bypass
        score.dimensions[2] = try self.checkTestBypass(action, context);
        if (score.dimensions[2] > 3) {
            try score.reasons.append(try std.fmt.allocPrint(
                self.allocator,
                "Test bypass detected (score: {d}/10)",
                .{score.dimensions[2]},
            ));
        }

        // Dimension 4: Performance Regression
        score.dimensions[3] = try self.checkPerformanceRegression(action, context);
        if (score.dimensions[3] > 3) {
            try score.reasons.append(try std.fmt.allocPrint(
                self.allocator,
                "Performance regression detected (score: {d}/10)",
                .{score.dimensions[3]},
            ));
        }

        // Dimension 5: Non-transparency
        score.dimensions[4] = try self.checkNonTransparency(action, context);
        if (score.dimensions[4] > 3) {
            try score.reasons.append(try std.fmt.allocPrint(
                self.allocator,
                "Non-transparent operation detected (score: {d}/10)",
                .{score.dimensions[4]},
            ));
        }

        // Calculate total
        for (score.dimensions) |d| {
            score.total += d;
        }

        // Determine verdict
        score.verdict = if (score.total >= 16)
            .toxic
        else if (score.total >= 8)
            .warning
        else
            .safe;

        return score;
    }

    fn checkSpecDrift(self: *OFC, action: []const u8, context: *const Context) !u8 {
        _ = self;
        _ = context;

        var score: u8 = 0;

        // Check for common drift patterns
        const drift_patterns = [_][]const u8{
            "skip validation",
            "ignore errors",
            "force override",
            "bypass check",
            "disable guard",
        };

        for (drift_patterns) |pattern| {
            if (std.mem.indexOf(u8, action, pattern) != null) {
                score += 2;
            }
        }

        // Check if generated file doesn't match spec
        if (context.generated_file) |gen| {
            if (context.spec_file) |spec| {
                // Simple heuristic: very different sizes indicate drift
                const size_ratio = @as(f64, @floatFromInt(gen.len)) / @as(f64, @floatFromInt(spec.len));
                if (size_ratio < 0.5 or size_ratio > 2.0) {
                    score += 3;
                }
            }
        }

        return @min(score, 10);
    }

    fn checkDestructiveness(self: *OFC, action: []const u8, context: *const Context) !u8 {
        _ = self;

        var score: u8 = 0;

        const destructive_patterns = [_][]const u8{
            "delete",
            "remove",
            "force",
            "drop",
            "truncate",
            "overwrite",
            "--force",
            "-f",
        };

        for (destructive_patterns) |pattern| {
            if (std.mem.indexOf(u8, action, pattern) != null) {
                score += 1;
            }
        }

        // Extra penalty for force operations
        if (std.mem.indexOf(u8, action, "force") != null or
            std.mem.indexOf(u8, action, "--force") != null)
        {
            score += 2;
        }

        return @min(score, 10);
    }

    fn checkTestBypass(self: *OFC, action: []const u8, context: *const Context) !u8 {
        _ = self;

        var score: u8 = 0;

        const bypass_patterns = [_][]const u8{
            "skip test",
            "bypass",
            "disable test",
            "ignore failure",
            "no-verify",
            "--skip-tests",
        };

        for (bypass_patterns) |pattern| {
            if (std.mem.indexOf(u8, action, pattern) != null) {
                score += 2;
            }
        }

        // Check if test count decreased
        if (context.test_count_before) |before| {
            if (context.test_count_after) |after| {
                if (after < before) {
                    score += 5;
                }
            }
        }

        return @min(score, 10);
    }

    fn checkPerformanceRegression(self: *OFC, action: []const u8, context: *const Context) !u8 {
        _ = self;
        _ = action;

        var score: u8 = 0;

        // Check benchmark results
        if (context.benchmark_before) |before| {
            if (context.benchmark_after) |after| {
                const ratio = @as(f64, @floatFromInt(after)) / @as(f64, @floatFromInt(before));
                if (ratio > 1.5) { // 50% slower
                    score = 10;
                } else if (ratio > 1.2) { // 20% slower
                    score = 5;
                } else if (ratio > 1.1) { // 10% slower
                    score = 2;
                }
            }
        }

        return score;
    }

    fn checkNonTransparency(self: *OFC, action: []const u8, context: *const Context) !u8 {
        _ = self;

        var score: u8 = 0;

        const opaque_patterns = [_][]const u8{
            "silent",
            "hidden",
            "background",
            "no-log",
            "quiet",
            "--quiet",
        };

        for (opaque_patterns) |pattern| {
            if (std.mem.indexOf(u8, action, pattern) != null) {
                score += 1;
            }
        }

        // Check for missing documentation
        if (context.generated_file) |file| {
            if (std.mem.indexOf(u8, file, "//") == null and
                std.mem.indexOf(u8, file, "///") == null)
            {
                score += 3;
            }
        }

        return @min(score, 10);
    }

    pub const Context = struct {
        spec_file: ?[]const u8 = null,
        generated_file: ?[]const u8 = null,
        test_count_before: ?usize = null,
        test_count_after: ?usize = null,
        benchmark_before: ?u64 = null,
        benchmark_after: ?u64 = null,
    };
};
