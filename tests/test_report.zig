// ═══════════════════════════════════════════════════════════════════════════════
// TEST REPORT FORMATTER — Unified test result reporting
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const TestReport = struct {
    total_tests: usize = 0,
    passed: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
    start_time: i64 = 0,
    end_time: i64 = 0,
    failures: std.StringArrayHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) TestReport {
        return .{
            .failures = std.StringArrayHashMap([]const u8).init(allocator),
            .start_time = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *TestReport) void {
        self.failures.deinit();
    }

    pub fn recordPass(self: *TestReport) void {
        self.total_tests += 1;
        self.passed += 1;
    }

    pub fn recordFail(self: *TestReport, test_name: []const u8, reason: []const u8) !void {
        self.total_tests += 1;
        self.failed += 1;
        try self.failures.put(test_name, reason);
    }

    pub fn recordSkip(self: *TestReport) void {
        self.total_tests += 1;
        self.skipped += 1;
    }

    pub fn finish(self: *TestReport) void {
        self.end_time = std.time.timestamp();
    }

    pub fn getDuration(self: *const TestReport) i64 {
        return self.end_time - self.start_time;
    }

    pub fn getPassRate(self: *const TestReport) f64 {
        if (self.total_tests == 0) return 0;
        return @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(self.total_tests)) * 100;
    }

    pub fn formatTerminal(self: *const TestReport, writer: anytype) !void {
        const duration = self.getDuration();
        const pass_rate = self.getPassRate();

        try writer.writeAll(
            \\╔════════════════════════════════════════════════════════════════╗
            \\║                    TRINITY TEST REPORT                         ║
            \\╚════════════════════════════════════════════════════════════════╝
            \\
        );

        try writer.print("  Total Tests:    {d}\n", .{self.total_tests});
        try writer.print("  Passed:         {d} ({d:.1}%)\n", .{ self.passed, pass_rate });
        try writer.print("  Failed:         {d}\n", .{self.failed});
        try writer.print("  Skipped:        {d}\n", .{self.skipped});
        try writer.print("  Duration:       {d}s\n", .{duration});

        // Status bar
        const status = if (self.failed == 0) "✅ ALL PASS" else "❌ HAS FAILURES";
        const status_color = if (self.failed == 0) "\x1b[38;2;0;255;0m" else "\x1b[38;2;255;0;0m";
        try writer.print("\n  {s}{s}{s}\n", .{ status_color, status, "\x1b[0m" });

        // Failures detail
        if (self.failed > 0) {
            try writer.writeAll("\n  Failures:\n");
            var iter = self.failures.iterator();
            while (iter.next()) |entry| {
                try writer.print("    ❌ {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        }

        try writer.writeAll(
            \\
            \\╔════════════════════════════════════════════════════════════════╗
            \\║  φ² + 1/φ² = 3 = TRINITY                                     ║
            \\╚════════════════════════════════════════════════════════════════╝
            \\
        );
    }

    pub fn formatJson(self: *const TestReport, allocator: std.mem.Allocator) ![]const u8 {
        const duration = self.getDuration();
        const pass_rate = self.getPassRate();

        var failures_array = std.ArrayList([]const u8).init(allocator);
        defer {
            for (failures_array.items) |item| allocator.free(item);
            failures_array.deinit();
        }

        var iter = self.failures.iterator();
        while (iter.next()) |entry| {
            const failure_str = try std.fmt.allocPrint(allocator, "{{\"test\":\"{s}\",\"reason\":\"{s}\"}}", .{ entry.key_ptr.*, entry.value_ptr.* });
            try failures_array.append(failure_str);
        }

        const failures_str = if (failures_array.items.len > 0)
            try std.mem.join(allocator, ",", failures_array.items)
        else
            "[]";

        const result = try std.fmt.allocPrint(allocator,
            \\{{"total":{d},"passed":{d},"failed":{d},"skipped":{d},"pass_rate":{d:.2},"duration_seconds":{d},"failures":[{s}]}}
        , .{ self.total_tests, self.passed, self.failed, self.skipped, pass_rate, duration, failures_str });

        allocator.free(failures_str);
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TestReport records passes correctly" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    report.recordPass();
    report.recordPass();
    report.finish();

    try std.testing.expectEqual(@as(usize, 2), report.total_tests);
    try std.testing.expectEqual(@as(usize, 2), report.passed);
    try std.testing.expectEqual(@as(usize, 0), report.failed);
}

test "TestReport calculates pass rate" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    report.recordPass();
    report.recordPass();
    report.recordPass();
    report.recordFail("test1", "assertion failed") catch {};
    report.finish();

    try std.testing.expectApproxEqAbs(@as(f64, 75.0), report.getPassRate(), 0.01);
}

test "TestReport formats JSON" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    report.recordPass();
    report.recordFail("my_test", "something broke") catch {};
    report.finish();

    const json = try report.formatJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"total\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"passed\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"failed\":1") != null);
}

test "TestReport tracks duration" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    report.recordPass();
    std.time.sleep(100 * std.time.ns_per_ms); // 100ms
    report.finish();

    const duration = report.getDuration();
    try std.testing.expect(duration >= 0);
}
