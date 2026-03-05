// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA Simulation Framework — JSON Reporter
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generate machine-readable JSON test reports
//
// Output format:
// {
//   "timestamp": "2026-03-05T22:00:00Z",
//   "test_suite": "trinity_simulation",
//   "git_commit": "abc123...",
//   "tests": [...],
//   "summary": {...}
// }
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const TestStatus = enum {
    pass,
    fail,
    skip,

    pub fn jsonString(self: TestStatus) []const u8 {
        return switch (self) {
            .pass => "PASS",
            .fail => "FAIL",
            .skip => "SKIP",
        };
    }
};

pub const TestResult = struct {
    name: []const u8,
    status: TestStatus,
    duration_ms: f64,
    details: Details,

    pub const Details = struct {
        vector_a: ?[]const u8 = null,
        vector_b: ?[]const u8 = null,
        expected: ?[]const u8 = null,
        actual: ?[]const u8 = null,
        result_match: ?bool = null,
        ops_per_sec: ?u64 = null,
        error_message: ?[]const u8 = null,
        metrics: ?std.StringHashMap([]const u8) = null,
    };
};

pub const TestReport = struct {
    timestamp: []const u8,
    test_suite: []const u8,
    git_commit: []const u8,
    tests: std.ArrayList(TestResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, suite_name: []const u8) !TestReport {
        // Simple timestamp - use current Unix time
        const timestamp = try std.fmt.allocPrint(allocator, "{d}", .{std.time.timestamp()});

        // Get git commit (short hash) - simplify to avoid complexity
        const git_commit = "dev";

        return .{
            .timestamp = timestamp,
            .test_suite = suite_name,
            .git_commit = git_commit,
            .tests = std.ArrayList(TestResult){},
            .allocator = allocator,
        };
    }

    pub fn addTest(self: *TestReport, result: TestResult) !void {
        try self.tests.append(self.allocator, result);
    }

    pub fn summary(self: *const TestReport) Summary {
        var total: usize = 0;
        var passed: usize = 0;
        var failed: usize = 0;
        var skipped: usize = 0;

        for (self.tests.items) |t| {
            total += 1;
            switch (t.status) {
                .pass => passed += 1,
                .fail => failed += 1,
                .skip => skipped += 1,
            }
        }

        return .{
            .total = total,
            .passed = passed,
            .failed = failed,
            .skipped = skipped,
            .success_rate = if (total > 0)
                @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total))
            else
                0.0,
        };
    }

    pub fn writeJson(self: *const TestReport, writer: anytype) !void {
        const sum = self.summary();

        try writer.writeAll("{\n");
        try writer.print("  \"timestamp\": \"{s}\",\n", .{self.timestamp});
        try writer.print("  \"test_suite\": \"{s}\",\n", .{self.test_suite});
        try writer.print("  \"git_commit\": \"{s}\",\n", .{self.git_commit});
        try writer.writeAll("  \"tests\": [\n");

        for (self.tests.items, 0..) |test_item, i| {
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{test_item.name});
            try writer.print("      \"status\": \"{s}\",\n", .{test_item.status.jsonString()});
            try writer.print("      \"duration_ms\": {d:.2},\n", .{test_item.duration_ms});
            try writer.writeAll("      \"details\": {");

            // Write details
            var detail_count: usize = 0;
            if (test_item.details.vector_a) |v| {
                try writer.print(" \"vector_a\": \"{s}\"", .{v});
                detail_count += 1;
            }
            if (test_item.details.vector_b) |v| {
                if (detail_count > 0) try writer.writeAll(",");
                try writer.print(" \"vector_b\": \"{s}\"", .{v});
                detail_count += 1;
            }
            if (test_item.details.expected) |e| {
                if (detail_count > 0) try writer.writeAll(",");
                try writer.print(" \"expected\": \"{s}\"", .{e});
                detail_count += 1;
            }
            if (test_item.details.actual) |a| {
                if (detail_count > 0) try writer.writeAll(",");
                try writer.print(" \"actual\": \"{s}\"", .{a});
                detail_count += 1;
            }
            if (test_item.details.result_match) |m| {
                if (detail_count > 0) try writer.writeAll(",");
                try writer.print(" \"result_match\": {}", .{m});
                detail_count += 1;
            }
            if (test_item.details.ops_per_sec) |ops| {
                if (detail_count > 0) try writer.writeAll(",");
                try writer.print(" \"ops_per_sec\": {d}", .{ops});
                detail_count += 1;
            }
            if (test_item.details.error_message) |msg| {
                if (detail_count > 0) try writer.writeAll(",");
                try writer.print(" \"error_message\": \"{s}\"", .{msg});
                detail_count += 1;
            }

            try writer.writeAll(" }\n");

            if (i < self.tests.items.len - 1) {
                try writer.writeAll("    },\n");
            } else {
                try writer.writeAll("    }\n");
            }
        }

        try writer.writeAll("  ],\n");
        try writer.writeAll("  \"summary\": {\n");
        try writer.print("    \"total\": {d},\n", .{sum.total});
        try writer.print("    \"passed\": {d},\n", .{sum.passed});
        try writer.print("    \"failed\": {d},\n", .{sum.failed});
        try writer.print("    \"skipped\": {d},\n", .{sum.skipped});
        try writer.print("    \"success_rate\": {d:.2}\n", .{sum.success_rate});
        try writer.writeAll("  }\n");
        try writer.writeAll("}\n");
    }

    pub fn writeFile(self: *const TestReport, path: []const u8) !void {
        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 4096);
        defer buffer.deinit(self.allocator);

        const writer = buffer.writer(self.allocator);
        try self.writeJson(writer);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(buffer.items);
    }

    pub const Summary = struct {
        total: usize,
        passed: usize,
        failed: usize,
        skipped: usize,
        success_rate: f64,
    };
};

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

pub fn passResult(allocator: std.mem.Allocator, name: []const u8, duration_ms: f64) TestResult {
    return .{
        .name = allocator.dupe(u8, name) catch name,
        .status = .pass,
        .duration_ms = duration_ms,
        .details = .{},
    };
}

pub fn failResult(allocator: std.mem.Allocator, name: []const u8, duration_ms: f64, error_msg: []const u8) TestResult {
    return .{
        .name = allocator.dupe(u8, name) catch name,
        .status = .fail,
        .duration_ms = duration_ms,
        .details = .{ .error_message = error_msg },
    };
}

pub fn skipResult(allocator: std.mem.Allocator, name: []const u8) TestResult {
    return .{
        .name = allocator.dupe(u8, name) catch name,
        .status = .skip,
        .duration_ms = 0.0,
        .details = .{},
    };
}
