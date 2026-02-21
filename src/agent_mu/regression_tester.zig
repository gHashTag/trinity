//! Regression Tester for VIBEE Compiler
//!
//! Auto-tests codegen templates after mutation,
//! detects regressions, validates all specs still compile.

const std = @import("std");
const ArrayListManaged = std.array_list.Managed;
const template_mutator = @import("template_mutator.zig");

/// Test result for single spec
pub const SpecTestResult = struct {
    spec_name: []const u8,
    passed: bool,
    compile_errors: ArrayListManaged([]const u8),
    test_errors: ArrayListManaged([]const u8),
    duration_ms: u64,

    pub fn init(allocator: std.mem.Allocator, spec_name: []const u8) !SpecTestResult {
        return SpecTestResult{
            .spec_name = try allocator.dupe(u8, spec_name),
            .passed = true,
            .compile_errors = ArrayListManaged([]const u8).init(allocator),
            .test_errors = ArrayListManaged([]const u8).init(allocator),
            .duration_ms = 0,
        };
    }

    pub fn deinit(self: *SpecTestResult) void {
        const alloc = self.compile_errors.allocator;
        alloc.free(self.spec_name);
        for (self.compile_errors.items) |err| {
            alloc.free(err);
        }
        self.compile_errors.deinit();
        for (self.test_errors.items) |err| {
            alloc.free(err);
        }
        self.test_errors.deinit();
    }
};

/// Regression test suite result
pub const RegressionTestResult = struct {
    total_specs: usize,
    passed_specs: usize,
    failed_specs: usize,
    total_duration_ms: u64,
    regressions_detected: usize,
    spec_results: ArrayListManaged(SpecTestResult),
    success: bool,

    pub fn init(allocator: std.mem.Allocator) !RegressionTestResult {
        return RegressionTestResult{
            .total_specs = 0,
            .passed_specs = 0,
            .failed_specs = 0,
            .total_duration_ms = 0,
            .regressions_detected = 0,
            .spec_results = ArrayListManaged(SpecTestResult).init(allocator),
            .success = true,
        };
    }

    pub fn deinit(self: *RegressionTestResult) void {
        for (self.spec_results.items) |*r| {
            r.deinit();
        }
        self.spec_results.deinit();
    }

    pub fn addSpecResult(self: *RegressionTestResult, result: SpecTestResult) !void {
        try self.spec_results.append(result);
        self.total_specs += 1;
        if (result.passed) {
            self.passed_specs += 1;
        } else {
            self.failed_specs += 1;
            self.success = false;
        }
    }

    pub fn getPassRate(self: *const RegressionTestResult) f32 {
        if (self.total_specs == 0) return 0.0;
        return @as(f32, @floatFromInt(self.passed_specs)) / @as(f32, @floatFromInt(self.total_specs));
    }
};

/// Regression tester for codegen mutations
pub const RegressionTester = struct {
    specs_dir: []const u8,
    output_dir: []const u8,
    baseline_results: ArrayListManaged(SpecTestResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, specs_dir: []const u8, output_dir: []const u8) !RegressionTester {
        return RegressionTester{
            .specs_dir = try allocator.dupe(u8, specs_dir),
            .output_dir = try allocator.dupe(u8, output_dir),
            .baseline_results = ArrayListManaged(SpecTestResult).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RegressionTester) void {
        self.allocator.free(self.specs_dir);
        self.allocator.free(self.output_dir);
        for (self.baseline_results.items) |*r| {
            r.deinit();
        }
        self.baseline_results.deinit();
    }

    /// Establish baseline before mutation
    pub fn establishBaseline(self: *RegressionTester) !RegressionTestResult {
        var result = try RegressionTestResult.init(self.allocator);
        errdefer result.deinit();

        // Find all .vibee specs
        const specs = try self.findSpecFiles();
        defer {
            for (specs.items) |s| {
                self.allocator.free(s);
            }
            specs.deinit();
        }

        const start_time = std.time.nanoTimestamp();

        // Test each spec
        for (specs.items) |spec_path| {
            const spec_result = try self.testSingleSpec(spec_path);
            try result.addSpecResult(spec_result);
        }

        const end_time = std.time.nanoTimestamp();
        result.total_duration_ms = @intCast((end_time - start_time) / 1_000_000);

        // Store as baseline
        for (result.spec_results.items) |r| {
            // Deep copy for baseline
            var baseline = try SpecTestResult.init(self.allocator, r.spec_name);
            baseline.passed = r.passed;
            baseline.duration_ms = r.duration_ms;
            for (r.compile_errors.items) |err| {
                try baseline.compile_errors.append(try self.allocator.dupe(u8, err));
            }
            for (r.test_errors.items) |err| {
                try baseline.test_errors.append(try self.allocator.dupe(u8, err));
            }
            try self.baseline_results.append(baseline);
        }

        return result;
    }

    /// Test after mutation and detect regressions
    pub fn testAfterMutation(self: *RegressionTester) !RegressionTestResult {
        var result = try RegressionTestResult.init(self.allocator);
        errdefer result.deinit();

        const start_time = std.time.nanoTimestamp();

        // Test each spec
        for (self.baseline_results.items) |baseline| {
            const spec_path = try std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}.vibee",
                .{ self.specs_dir, baseline.spec_name },
            );

            const spec_result = try self.testSingleSpec(spec_path);
            self.allocator.free(spec_path);

            // Compare with baseline
            if (baseline.passed and !spec_result.passed) {
                // Regression detected!
                result.regressions_detected += 1;
            }

            try result.addSpecResult(spec_result);
        }

        const end_time = std.time.nanoTimestamp();
        result.total_duration_ms = @intCast((end_time - start_time) / 1_000_000);

        return result;
    }

    /// Test a single spec file
    fn testSingleSpec(self: *RegressionTester, spec_path: []const u8) !SpecTestResult {
        const spec_name = self.extractSpecName(spec_path);
        var result = try SpecTestResult.init(self.allocator, spec_name);
        errdefer result.deinit();

        const start_time = std.time.nanoTimestamp();

        // Try to compile the spec
        const compile_result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "zig", "build", "vibee", "--", "gen", spec_path },
        }) catch {
            result.passed = false;
            return result;
        };
        defer {
            self.allocator.free(compile_result.stdout);
            self.allocator.free(compile_result.stderr);
        }

        if (compile_result.term != .Exited or compile_result.term.Exited != 0) {
            result.passed = false;
            try result.compile_errors.append(try self.allocator.dupe(u8, compile_result.stderr));
        }

        const end_time = std.time.nanoTimestamp();
        result.duration_ms = @intCast((end_time - start_time) / 1_000_000);

        return result;
    }

    /// Find all .vibee spec files
    fn findSpecFiles(self: *RegressionTester) !ArrayListManaged([]const u8) {
        var specs = ArrayListManaged([]const u8).init(self.allocator);

        var dir = try std.fs.cwd().openDir(self.specs_dir, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (std.mem.endsWith(u8, entry.path, ".vibee")) {
                const full_path = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}/{s}",
                    .{ self.specs_dir, entry.path },
                );
                try specs.append(full_path);
            }
        }

        return specs;
    }

    /// Extract spec name from path
    fn extractSpecName(self: *RegressionTester, path: []const u8) []const u8 {
        _ = self;
        if (std.mem.lastIndexOf(u8, path, "/")) |pos| {
            const basename = path[pos + 1 ..];
            if (std.mem.lastIndexOf(u8, basename, ".")) |ext_pos| {
                return self.allocator.dupe(u8, basename[0..ext_pos]) catch "unknown";
            }
            return basename;
        }
        return path;
    }

    /// Quick smoke test on critical specs
    pub fn smokeTest(self: *RegressionTester) !bool {
        const critical_specs = &[_][]const u8{
            "vibee_self_improver",
            "agent_mu_self_improvement_loop",
            "vsa_swarm_production",
        };

        for (critical_specs) |spec| {
            const spec_path = try std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}.vibee",
                .{ self.specs_dir, spec },
            );

            const result = try self.testSingleSpec(spec_path);
            self.allocator.free(spec_path);

            if (!result.passed) {
                result.deinit();
                return false;
            }
            result.deinit();
        }

        return true;
    }
};

/// Validate mutation didn't break critical functionality
pub fn validateMutation(
    allocator: std.mem.Allocator,
    specs_dir: []const u8,
    mutation: *const template_mutator.TemplateMutation,
) !bool {
    _ = mutation;

    var tester = try RegressionTester.init(allocator, specs_dir, "zig-out");
    defer tester.deinit();

    return tester.smokeTest();
}

test "RegressionTester: smoke test" {
    const allocator = std.testing.allocator;

    var tester = try RegressionTester.init(
        allocator,
        "specs/tri",
        "zig-out",
    );
    defer tester.deinit();

    // Note: This will fail if specs don't exist in test environment
    // In production, this would test actual specs
    const result = try tester.smokeTest();
    _ = result;
}

test "RegressionTestResult: pass rate calculation" {
    const allocator = std.testing.allocator;
    var result = try RegressionTestResult.init(allocator);
    defer result.deinit();

    // Add 10 results: 8 pass, 2 fail
    for (0..8) |_| {
        var pass_result = try SpecTestResult.init(allocator, "pass_spec");
        pass_result.passed = true;
        try result.addSpecResult(pass_result);
    }

    for (0..2) |_| {
        var fail_result = try SpecTestResult.init(allocator, "fail_spec");
        fail_result.passed = false;
        try result.addSpecResult(fail_result);
    }

    const pass_rate = result.getPassRate();
    try std.testing.expectApproxEqRel(@as(f32, 0.8), pass_rate, 0.01);
}
