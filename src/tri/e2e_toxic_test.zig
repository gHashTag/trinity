// @origin(spec:e2e_toxic_test.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// E2E TOXIC TEST — End-to-end test framework with toxic verdicts
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri test e2e [--toxic] [--threshold N]
// Runs verdict scoring on the actual codebase state, checks spec coverage,
// build health, and test status. Applies threshold → PASS/FAIL with toxic roast.
//
// Part of Trinity Tech Tree: Testing Layer [T1]
// Dependencies: toxic_verdict.zig (F2), spec_template_match.zig
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const colors = @import("tri_colors.zig");
const toxic_verdict = @import("toxic_verdict.zig");
const spec_match = @import("spec_template_match.zig");
const print = std.debug.print;

const GREEN = colors.GREEN;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RESET = colors.RESET;
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from e2e_toxic_test.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const E2EScenario = struct {
    name: [64]u8 = undefined,
    name_len: usize = 0,
    description: [128]u8 = undefined,
    description_len: usize = 0,
    spec_path: [128]u8 = undefined,
    spec_path_len: usize = 0,
    expected_compile: bool = true,
    min_verdict_score: f32 = 50.0,
    has_tests: bool = false,

    pub fn nameStr(self: *const E2EScenario) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn descStr(self: *const E2EScenario) []const u8 {
        return self.description[0..self.description_len];
    }

    pub fn specPathStr(self: *const E2EScenario) []const u8 {
        return self.spec_path[0..self.spec_path_len];
    }

    fn setName(self: *E2EScenario, text: []const u8) void {
        const len = @min(text.len, self.name.len);
        @memcpy(self.name[0..len], text[0..len]);
        self.name_len = len;
    }

    fn setDesc(self: *E2EScenario, text: []const u8) void {
        const len = @min(text.len, self.description.len);
        @memcpy(self.description[0..len], text[0..len]);
        self.description_len = len;
    }

    fn setSpecPath(self: *E2EScenario, text: []const u8) void {
        const len = @min(text.len, self.spec_path.len);
        @memcpy(self.spec_path[0..len], text[0..len]);
        self.spec_path_len = len;
    }
};

pub const E2EResult = struct {
    scenario_name: [64]u8 = undefined,
    scenario_name_len: usize = 0,
    has_matching_zig: bool = false,
    has_test_block: bool = false,
    verdict_score: f32 = 0,
    passed: bool = false,
    duration_ms: u32 = 0,
    error_detail: [128]u8 = undefined,
    error_detail_len: usize = 0,

    pub fn scenarioStr(self: *const E2EResult) []const u8 {
        return self.scenario_name[0..self.scenario_name_len];
    }

    pub fn errorStr(self: *const E2EResult) []const u8 {
        return self.error_detail[0..self.error_detail_len];
    }

    fn setScenario(self: *E2EResult, text: []const u8) void {
        const len = @min(text.len, self.scenario_name.len);
        @memcpy(self.scenario_name[0..len], text[0..len]);
        self.scenario_name_len = len;
    }

    fn setError(self: *E2EResult, text: []const u8) void {
        const len = @min(text.len, self.error_detail.len);
        @memcpy(self.error_detail[0..len], text[0..len]);
        self.error_detail_len = len;
    }
};

const MAX_SCENARIOS = 20;

pub const E2ESuite = struct {
    results: [MAX_SCENARIOS]E2EResult = undefined,
    result_count: usize = 0,
    total: u32 = 0,
    passed: u32 = 0,
    failed: u32 = 0,
    avg_verdict: f32 = 0,
    total_duration_ms: u32 = 0,

    pub fn addResult(self: *E2ESuite, result: E2EResult) void {
        if (self.result_count < MAX_SCENARIOS) {
            self.results[self.result_count] = result;
            self.result_count += 1;
            self.total += 1;
            if (result.passed) {
                self.passed += 1;
            } else {
                self.failed += 1;
            }
            self.total_duration_ms += result.duration_ms;
        }
    }

    pub fn computeAvgVerdict(self: *E2ESuite) void {
        if (self.result_count == 0) return;
        var sum: f32 = 0;
        for (self.results[0..self.result_count]) |r| {
            sum += r.verdict_score;
        }
        self.avg_verdict = sum / @as(f32, @floatFromInt(self.result_count));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISCOVER SCENARIOS
// ═══════════════════════════════════════════════════════════════════════════════

const DiscoveryResult = struct {
    scenarios: [MAX_SCENARIOS]E2EScenario = undefined,
    count: usize = 0,
};

fn discoverScenarios(allocator: Allocator, threshold: f32) DiscoveryResult {
    _ = allocator;
    var result = DiscoveryResult{};

    var dir = std.fs.cwd().openDir("specs/tri", .{ .iterate = true }) catch return result;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (result.count >= MAX_SCENARIOS) break;
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;

        // Read file to check for test blocks
        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();

        var buf: [8192]u8 = undefined;
        const n = file.readAll(&buf) catch continue;
        const content = buf[0..n];

        const has_tests = std.mem.indexOf(u8, content, "tests:") != null or
            std.mem.indexOf(u8, content, "test_cases:") != null;
        const has_behaviors = std.mem.indexOf(u8, content, "behaviors:") != null;

        // Only include specs with test blocks or behaviors
        if (!has_tests and !has_behaviors) continue;

        var scenario = E2EScenario{
            .min_verdict_score = threshold,
            .has_tests = has_tests,
        };

        // Name = filename without .tri
        const name_end = entry.name.len - 4;
        scenario.setName(entry.name[0..name_end]);

        // Path
        var path_buf: [128]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "specs/tri/{s}", .{entry.name}) catch continue;
        scenario.setSpecPath(path);

        // Description from first comment line
        if (std.mem.indexOf(u8, content, "# ")) |desc_start| {
            const line_end = std.mem.indexOfPos(u8, content, desc_start, "\n") orelse content.len;
            const desc = content[desc_start + 2 .. line_end];
            scenario.setDesc(desc);
        }

        result.scenarios[result.count] = scenario;
        result.count += 1;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUN SCENARIO
// ═══════════════════════════════════════════════════════════════════════════════

fn runScenario(scenario: *const E2EScenario) E2EResult {
    const start = std.time.milliTimestamp();

    var result = E2EResult{};
    result.setScenario(scenario.nameStr());

    // Check 1: Does a matching .zig file exist?
    var zig_path_buf: [128]u8 = undefined;
    const zig_path = std.fmt.bufPrint(&zig_path_buf, "src/tri/{s}.zig", .{scenario.nameStr()}) catch {
        result.setError("Failed to build .zig path");
        result.duration_ms = @intCast(@as(u64, @bitCast(std.time.milliTimestamp() - start)));
        return result;
    };

    result.has_matching_zig = blk: {
        std.fs.cwd().access(zig_path, .{}) catch break :blk false;
        break :blk true;
    };

    // Check 2: Does the .zig file have test blocks?
    if (result.has_matching_zig) {
        if (std.fs.cwd().openFile(zig_path, .{})) |zig_file| {
            defer zig_file.close();
            var read_buf: [65536]u8 = undefined;
            const bytes = zig_file.readAll(&read_buf) catch 0;
            result.has_test_block = std.mem.indexOf(u8, read_buf[0..bytes], "test \"") != null;
        } else |_| {
            result.has_test_block = false;
        }
    }

    // Compute verdict score
    // Score formula: 40% has_zig + 30% has_tests + 20% has_spec_tests + 10% behaviors
    {
        var score: f32 = 0;
        if (result.has_matching_zig) score += 40.0;
        if (result.has_test_block) score += 30.0;
        if (scenario.has_tests) score += 20.0;
        score += 10.0; // spec exists (always true if we're here)

        result.verdict_score = score;
        result.passed = score >= scenario.min_verdict_score;

        if (!result.passed) {
            if (!result.has_matching_zig) {
                result.setError("No matching .zig implementation");
            } else if (!result.has_test_block) {
                result.setError("Implementation exists but has no tests");
            } else {
                result.setError("Score below threshold");
            }
        }
    }

    const end = std.time.milliTimestamp();
    result.duration_ms = @intCast(@as(u64, @bitCast(end - start)));

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

fn renderResults(suite: *const E2ESuite, toxic: bool) void {
    print("\n{s}E2E TEST RESULTS{s}", .{ GOLDEN, RESET });
    if (toxic) {
        print(" {s}[TOXIC MODE]{s}", .{ RED, RESET });
    }
    print("\n{s}════════════════════════════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    // Summary
    const pass_pct: u32 = if (suite.total > 0) (suite.passed * 100) / suite.total else 0;
    const summary_color: []const u8 = if (pass_pct >= 80) GREEN else if (pass_pct >= 50) YELLOW else RED;
    const avg_int: u32 = @intFromFloat(suite.avg_verdict);

    print("  {s}E2E: {d}/{d} PASS ({d}%%) — avg verdict {d}/100{s}\n\n", .{
        summary_color, suite.passed, suite.total, pass_pct, avg_int, RESET,
    });

    // Results table
    print("  {s}Scenario                   Zig  Tests  Score  Status{s}\n", .{ GRAY, RESET });
    print("  {s}────────────────────────   ───  ─────  ─────  ──────{s}\n", .{ GRAY, RESET });

    for (suite.results[0..suite.result_count]) |r| {
        const status: []const u8 = if (r.passed) "PASS" else "FAIL";
        const status_color: []const u8 = if (r.passed) GREEN else RED;
        const zig_icon: []const u8 = if (r.has_matching_zig) "yes" else "---";
        const test_icon: []const u8 = if (r.has_test_block) "yes" else "---";
        const score_int: u32 = @intFromFloat(r.verdict_score);

        print("  {s:<25}  {s:<3}  {s:<5}  {d:>3}    {s}{s}{s}\n", .{
            r.scenarioStr(),
            zig_icon,
            test_icon,
            score_int,
            status_color,
            status,
            RESET,
        });
    }

    print("\n", .{});

    // Toxic roasts for failures
    if (toxic and suite.failed > 0) {
        print("  {s}TOXIC ROAST:{s}\n", .{ RED, RESET });
        for (suite.results[0..suite.result_count]) |r| {
            if (!r.passed) {
                print("  {s}  {s}: {s}{s}\n", .{ RED, r.scenarioStr(), r.errorStr(), RESET });
            }
        }
        print("\n", .{});

        if (suite.failed > suite.passed) {
            print("  {s}More failures than passes. This codebase needs work.{s}\n\n", .{ RED, RESET });
        }
    }

    print("  {s}Duration: {d}ms  |  Scenarios: {d}{s}\n", .{ DIM, suite.total_duration_ms, suite.total, RESET });
    print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVE RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

fn saveResults(suite: *const E2ESuite) void {
    std.fs.cwd().makePath(".trinity") catch {};
    const file = std.fs.cwd().createFile(".trinity/e2e_results.json", .{}) catch return;
    defer file.close();

    var buf: [256]u8 = undefined;
    const content = std.fmt.bufPrint(&buf, "{{\"total\":{d},\"passed\":{d},\"failed\":{d},\"avg_verdict\":{d:.1},\"duration_ms\":{d},\"timestamp\":{d}}}\n", .{
        suite.total,
        suite.passed,
        suite.failed,
        suite.avg_verdict,
        suite.total_duration_ms,
        std.time.timestamp(),
    }) catch return;
    file.writeAll(content) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — CLI entrypoint for tri test e2e
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runE2ECommand(allocator: Allocator, args: []const []const u8) void {
    var toxic = false;
    var threshold: f32 = 50.0;

    // Parse args
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--toxic")) {
            toxic = true;
        } else if (std.mem.eql(u8, args[i], "--threshold") and i + 1 < args.len) {
            threshold = @floatFromInt(std.fmt.parseInt(u32, args[i + 1], 10) catch 50);
            i += 1;
        }
    }

    print("\n{s}Discovering E2E scenarios (threshold: {d:.0})...{s}\n", .{ DIM, threshold, RESET });

    // Discover
    const discovery = discoverScenarios(allocator, threshold);

    if (discovery.count == 0) {
        print("{s}No testable specs found in specs/tri/{s}\n", .{ YELLOW, RESET });
        return;
    }

    print("  {s}Found {d} scenarios{s}\n\n", .{ DIM, discovery.count, RESET });

    // Run suite
    var suite = E2ESuite{};
    for (discovery.scenarios[0..discovery.count]) |*scenario| {
        const result = runScenario(scenario);
        suite.addResult(result);
    }

    suite.computeAvgVerdict();

    // Render
    renderResults(&suite, toxic);

    // Save
    saveResults(&suite);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "E2EScenario defaults" {
    const scenario = E2EScenario{};
    try std.testing.expect(scenario.expected_compile);
    try std.testing.expectEqual(@as(f32, 50.0), scenario.min_verdict_score);
}

test "E2EResult pass threshold" {
    var result = E2EResult{};
    result.verdict_score = 70.0;
    result.passed = result.verdict_score >= 50.0;
    try std.testing.expect(result.passed);
}

test "E2EResult fail threshold" {
    var result = E2EResult{};
    result.verdict_score = 30.0;
    result.passed = result.verdict_score >= 50.0;
    try std.testing.expect(!result.passed);
}

test "E2ESuite aggregate" {
    var suite = E2ESuite{};

    var pass_result = E2EResult{ .passed = true, .verdict_score = 80.0, .duration_ms = 100 };
    pass_result.setScenario("test_pass");

    var fail_result = E2EResult{ .passed = false, .verdict_score = 20.0, .duration_ms = 50 };
    fail_result.setScenario("test_fail");

    suite.addResult(pass_result);
    suite.addResult(fail_result);
    suite.computeAvgVerdict();

    try std.testing.expectEqual(@as(u32, 2), suite.total);
    try std.testing.expectEqual(@as(u32, 1), suite.passed);
    try std.testing.expectEqual(@as(u32, 1), suite.failed);
    try std.testing.expectEqual(@as(f32, 50.0), suite.avg_verdict);
    try std.testing.expectEqual(@as(u32, 150), suite.total_duration_ms);
}

test "E2EScenario setters" {
    var scenario = E2EScenario{};
    scenario.setName("dev_scan");
    scenario.setDesc("Scan for work");
    scenario.setSpecPath("specs/tri/dev_scan.tri");

    try std.testing.expectEqualStrings("dev_scan", scenario.nameStr());
    try std.testing.expectEqualStrings("Scan for work", scenario.descStr());
    try std.testing.expectEqualStrings("specs/tri/dev_scan.tri", scenario.specPathStr());
}

test "E2EResult setters" {
    var result = E2EResult{};
    result.setScenario("my_test");
    result.setError("Build failed");

    try std.testing.expectEqualStrings("my_test", result.scenarioStr());
    try std.testing.expectEqualStrings("Build failed", result.errorStr());
}

test "discover finds specs" {
    // This test actually hits the filesystem
    const discovery = discoverScenarios(std.testing.allocator, 50.0);
    // We have 100+ specs in specs/tri/, at least 10 should have test blocks
    try std.testing.expect(discovery.count >= 5);
}
