// @origin(spec) @regen(done)
// SWE Agent Entrypoint v1 — Pure Zig replacement for agent-entrypoint.sh
//
// Reads env vars, clones repo, reads GitHub issue, runs pipeline, reports fitness.
// Pattern from: src/cli/entrypoint_train.zig
//
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const posix = std.posix;
const log = std.log.scoped(.swe_entrypoint);

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from swe_entrypoint.tri)
// ═══════════════════════════════════════════════════════════════════════════════

const ExitReport = struct {
    issue_number: u32 = 0,
    success: bool = false,
    test_pass_rate: f32 = 0.0,
    tests_passed: u32 = 0,
    tests_total: u32 = 0,
    build_ok: bool = false,
    time_seconds: u32 = 0,
    error_msg: []const u8 = "",
};

const EntrypointConfig = struct {
    issue_number: u32 = 0,
    github_token: []const u8 = "",
    api_key: []const u8 = "",
    agent_role: []const u8 = "coder",
    pipeline_links: []const u8 = "6,7,11,17",
    model: []const u8 = "claude-sonnet-4-20250514",
    repo_url: []const u8 = "https://github.com/gHashTag/trinity",
    branch_prefix: []const u8 = "feat/issue-",
    timeout_minutes: u32 = 60,
    work_dir: []const u8 = "/workspace",
};

fn envStr(key: []const u8, default: []const u8) []const u8 {
    return posix.getenv(key) orelse default;
}

fn readConfig() EntrypointConfig {
    return .{
        .issue_number = std.fmt.parseInt(u32, envStr("ISSUE_NUMBER", "0"), 10) catch 0,
        .github_token = envStr("GITHUB_TOKEN", ""),
        .api_key = envStr("ANTHROPIC_API_KEY", envStr("ZAI_KEY_1", "")),
        .agent_role = envStr("AGENT_ROLE", "coder"),
        .pipeline_links = envStr("PIPELINE_LINKS", "6,7,11,17"),
        .model = envStr("TRINITY_MODEL_CODER", "claude-sonnet-4-20250514"),
        .repo_url = envStr("REPO_URL", "https://github.com/gHashTag/trinity"),
        .branch_prefix = envStr("BRANCH_PREFIX", "feat/issue-"),
        .timeout_minutes = std.fmt.parseInt(u32, envStr("TIMEOUT_MINUTES", "60"), 10) catch 60,
        .work_dir = envStr("WORK_DIR", "/workspace"),
    };
}

/// Run a child process and return exit code
fn runCmd(allocator: std.mem.Allocator, argv: []const []const u8) !u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();
    return switch (term) {
        .Exited => |code| code,
        else => 1,
    };
}

/// Run a child process and capture stdout
fn runCmdCapture(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    _ = try child.spawn();

    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stderr_buf.deinit(allocator);

    try child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1 * 1024 * 1024);
    _ = try child.wait();

    return try stdout_buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION — build + test check
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse zig test output for pass/fail counts
fn parseTestOutput(output: []const u8) struct { passed: u32, total: u32 } {
    // Pattern 1: "All N tests passed"
    if (std.mem.indexOf(u8, output, "All ")) |all_pos| {
        const after = output[all_pos + 4 ..];
        if (std.mem.indexOf(u8, after, " tests passed")) |_| {
            const end = std.mem.indexOf(u8, after, " ") orelse return .{ .passed = 0, .total = 0 };
            const n = std.fmt.parseInt(u32, after[0..end], 10) catch return .{ .passed = 0, .total = 0 };
            return .{ .passed = n, .total = n };
        }
    }

    // Pattern 2: "N/M test...OK" lines — find highest total
    var best_total: u32 = 0;
    var best_passed: u32 = 0;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "/")) |slash| {
            if (slash == 0) continue;
            // Find start of number before slash
            var s = slash;
            while (s > 0 and line[s - 1] >= '0' and line[s - 1] <= '9') s -= 1;
            const num = std.fmt.parseInt(u32, line[s..slash], 10) catch continue;
            // Find end of number after slash
            var e = slash + 1;
            while (e < line.len and line[e] >= '0' and line[e] <= '9') e += 1;
            const total = std.fmt.parseInt(u32, line[slash + 1 .. e], 10) catch continue;

            if (total > best_total) best_total = total;
            if (std.mem.indexOf(u8, line, "...OK") != null and num > best_passed) {
                best_passed = num;
            }
        }
    }
    return .{ .passed = best_passed, .total = best_total };
}

/// Run build validation: zig build + zig build test
fn validateBuild(allocator: std.mem.Allocator, work_dir: []const u8) ExitReport {
    var report = ExitReport{};

    // Step 1: zig build
    log.info("Validation: zig build...", .{});
    const build_exit = runCmd(allocator, &.{ "zig", "build", "-Dwork-dir", work_dir }) catch {
        report.error_msg = "zig build crashed";
        return report;
    };
    report.build_ok = build_exit == 0;

    if (!report.build_ok) {
        report.error_msg = "zig build failed";
        return report;
    }

    // Step 2: zig build test
    log.info("Validation: zig build test...", .{});
    const test_output = runCmdCapture(allocator, &.{ "zig", "build", "test" }) catch {
        report.error_msg = "zig build test crashed";
        return report;
    };
    defer allocator.free(test_output);

    const test_stats = parseTestOutput(test_output);
    report.tests_passed = test_stats.passed;
    report.tests_total = test_stats.total;
    report.test_pass_rate = if (test_stats.total > 0)
        @as(f32, @floatFromInt(test_stats.passed)) / @as(f32, @floatFromInt(test_stats.total))
    else
        0.0;
    report.success = report.build_ok and (test_stats.total == 0 or test_stats.passed == test_stats.total);

    return report;
}

/// Format ExitReport as markdown for GitHub issue comment
fn formatReport(allocator: std.mem.Allocator, config: EntrypointConfig, report: ExitReport) []const u8 {
    if (report.success) {
        return std.fmt.allocPrint(allocator,
            \\✅ **SWE Agent Complete**
            \\- Issue: #{d}
            \\- Role: {s}
            \\- Model: {s}
            \\- Links: {s}
            \\- Build: PASS
            \\- Tests: {d}/{d} ({d:.0}%)
            \\- Time: {d}s
            \\- Status: **SUCCESS**
        , .{
            config.issue_number,         config.agent_role,   config.model,
            config.pipeline_links,       report.tests_passed, report.tests_total,
            report.test_pass_rate * 100, report.time_seconds,
        }) catch return "Report formatting failed";
    } else {
        return std.fmt.allocPrint(allocator,
            \\❌ **SWE Agent Failed**
            \\- Issue: #{d}
            \\- Role: {s}
            \\- Model: {s}
            \\- Build: {s}
            \\- Tests: {d}/{d}
            \\- Error: {s}
        , .{
            config.issue_number,                     config.agent_role,   config.model,
            if (report.build_ok) "PASS" else "FAIL", report.tests_passed, report.tests_total,
            report.error_msg,
        }) catch return "Report formatting failed";
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = readConfig();

    // Banner
    log.info("=== SWE Agent Entrypoint v1 (Zig) ===", .{});
    log.info("Issue: #{d}", .{config.issue_number});
    log.info("Role: {s}", .{config.agent_role});
    log.info("Model: {s}", .{config.model});
    log.info("Links: {s}", .{config.pipeline_links});
    log.info("Timeout: {d}min", .{config.timeout_minutes});

    // Validate required config
    if (config.issue_number == 0) {
        log.err("ISSUE_NUMBER not set or invalid", .{});
        return error.MissingConfig;
    }
    if (config.github_token.len == 0) {
        log.err("GITHUB_TOKEN not set", .{});
        return error.MissingConfig;
    }
    if (config.api_key.len == 0) {
        log.err("ANTHROPIC_API_KEY / ZAI_KEY_1 not set", .{});
        return error.MissingConfig;
    }

    // Step 1: Clone repo
    log.info("Step 1: Cloning {s}...", .{config.repo_url});
    const clone_url = try std.fmt.allocPrint(allocator, "https://x-access-token:{s}@github.com/gHashTag/trinity.git", .{config.github_token});
    defer allocator.free(clone_url);

    const clone_exit = runCmd(allocator, &.{ "git", "clone", "--depth", "1", clone_url, config.work_dir }) catch {
        log.err("git clone failed", .{});
        return error.CloneFailed;
    };
    if (clone_exit != 0) {
        log.err("git clone exited with code {d}", .{clone_exit});
        return error.CloneFailed;
    }

    // Step 2: Create branch
    const branch_name = try std.fmt.allocPrint(allocator, "{s}{d}", .{ config.branch_prefix, config.issue_number });
    defer allocator.free(branch_name);

    log.info("Step 2: Creating branch {s}", .{branch_name});
    _ = runCmd(allocator, &.{ "git", "-C", config.work_dir, "checkout", "-b", branch_name }) catch {};

    // Step 3: Read issue
    log.info("Step 3: Reading issue #{d}...", .{config.issue_number});
    const issue_num_str = try std.fmt.allocPrint(allocator, "{d}", .{config.issue_number});
    defer allocator.free(issue_num_str);

    const issue_body = runCmdCapture(allocator, &.{
        "gh", "issue", "view", issue_num_str, "--json", "title,body,labels", "--repo", "gHashTag/trinity",
    }) catch |err| {
        log.err("Failed to read issue: {}", .{err});
        return error.IssueFetchFailed;
    };
    defer allocator.free(issue_body);

    log.info("Issue body length: {d} bytes", .{issue_body.len});

    // Step 4: Run pipeline (optional — tri binary may not be in container)
    log.info("Step 4: Running pipeline with links {s}...", .{config.pipeline_links});

    const start_time = std.time.timestamp();

    var pipeline_ok = false;
    if (runCmd(allocator, &.{
        "tri", "pipeline", "run", "--links", config.pipeline_links, "--issue", issue_num_str,
    })) |exit_code| {
        pipeline_ok = exit_code == 0;
    } else |err| {
        log.warn("Pipeline not available ({s}) — skipping to build validation", .{@errorName(err)});
    }
    log.info("Pipeline result: {s}", .{if (pipeline_ok) "OK" else "skipped/failed"});

    // Step 5: Validate build + tests (always runs)
    log.info("Step 5: Validating build...", .{});
    var report = validateBuild(allocator, config.work_dir);
    report.issue_number = config.issue_number;
    report.time_seconds = @intCast(@as(u64, @intCast(std.time.timestamp() - start_time)));

    log.info("Build: {s} | Tests: {d}/{d} | Pass rate: {d:.1}%", .{
        if (report.build_ok) "OK" else "FAIL",
        report.tests_passed,
        report.tests_total,
        report.test_pass_rate * 100,
    });

    // Step 6: Report results
    log.info("Step 6: Reporting results...", .{});
    postReport(allocator, config, report);

    // Step 7: Write fitness to Railway variables (bridge → tri dev fitness sync)
    log.info("Step 7: Writing fitness to Railway variables...", .{});
    writeFitness(allocator, report);

    log.info("=== SWE Agent Entrypoint done (success={s}) ===", .{
        if (report.success) "true" else "false",
    });
}

/// Write AGENT_FITNESS_* variables to Railway via GraphQL variableCollectionUpsert.
/// This is the WRITE side of the fitness bridge — tri dev fitness sync reads these.
fn writeFitness(allocator: std.mem.Allocator, report: ExitReport) void {
    const api_token = envStr("RAILWAY_API_TOKEN", "");
    const service_id = envStr("RAILWAY_SERVICE_ID", "");
    const project_id = envStr("RAILWAY_PROJECT_ID", "");
    const env_id = envStr("RAILWAY_ENVIRONMENT_ID", "");

    if (api_token.len == 0 or service_id.len == 0 or project_id.len == 0 or env_id.len == 0) {
        log.warn("Missing RAILWAY_* env vars — skipping fitness write", .{});
        return;
    }

    // Compute fitness values
    const test_pass = report.test_pass_rate; // 0.0-1.0
    const spec_compliance: f32 = if (report.build_ok) 1.0 else 0.0;
    const time_hours = @as(f32, @floatFromInt(report.time_seconds)) / 3600.0;

    // Build GraphQL payload
    const body = std.fmt.allocPrint(allocator,
        \\{{"query":"mutation($input: VariableCollectionUpsertInput!) {{ variableCollectionUpsert(input: $input) }}","variables":{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"AGENT_FITNESS_TEST_PASS":"{d:.4}","AGENT_FITNESS_SPEC":"{d:.1}","AGENT_FITNESS_TIME":"{d:.2}","AGENT_FITNESS_MERGED":"false"}}}}}}}}
    , .{ project_id, service_id, env_id, test_pass, spec_compliance, time_hours }) catch return;
    defer allocator.free(body);

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{api_token}) catch return;
    defer allocator.free(auth_header);

    const exit = runCmd(allocator, &.{
        "curl", "-s", "-X", "POST",
        "-H", "Content-Type: application/json",
        "-H", auth_header,
        "-d", body,
        "https://backboard.railway.com/graphql/v2",
    }) catch {
        log.warn("curl failed for fitness write", .{});
        return;
    };

    if (exit == 0) {
        log.info("Fitness written: tp={d:.2} sc={d:.1} t={d:.2}h", .{ test_pass, spec_compliance, time_hours });
    } else {
        log.warn("Fitness write curl exited {d}", .{exit});
    }
}

fn postReport(allocator: std.mem.Allocator, config: EntrypointConfig, report: ExitReport) void {
    const comment = formatReport(allocator, config, report);

    const issue_str = std.fmt.allocPrint(allocator, "{d}", .{config.issue_number}) catch return;
    defer allocator.free(issue_str);

    _ = runCmd(allocator, &.{
        "gh", "issue", "comment", issue_str, "--body", comment, "--repo", "gHashTag/trinity",
    }) catch {};
}

test "readConfig defaults" {
    const config = readConfig();
    try std.testing.expectEqual(@as(u32, 60), config.timeout_minutes);
    try std.testing.expectEqualStrings("coder", config.agent_role);
    try std.testing.expectEqualStrings("6,7,11,17", config.pipeline_links);
}

test "parseTestOutput all passed" {
    const output = "All 42 tests passed.";
    const stats = parseTestOutput(output);
    try std.testing.expectEqual(@as(u32, 42), stats.passed);
    try std.testing.expectEqual(@as(u32, 42), stats.total);
}

test "parseTestOutput line format" {
    const output = "1/5 test.a...OK\n2/5 test.b...OK\n3/5 test.c...OK\n4/5 test.d...OK\n5/5 test.e...OK\nAll 5 tests passed.";
    const stats = parseTestOutput(output);
    try std.testing.expectEqual(@as(u32, 5), stats.passed);
    try std.testing.expectEqual(@as(u32, 5), stats.total);
}

test "parseTestOutput empty" {
    const stats = parseTestOutput("");
    try std.testing.expectEqual(@as(u32, 0), stats.passed);
    try std.testing.expectEqual(@as(u32, 0), stats.total);
}

test "formatReport success" {
    const allocator = std.testing.allocator;
    const config = EntrypointConfig{ .issue_number = 42 };
    const report = ExitReport{
        .success = true,
        .build_ok = true,
        .tests_passed = 10,
        .tests_total = 10,
        .test_pass_rate = 1.0,
        .time_seconds = 120,
    };
    const result = formatReport(allocator, config, report);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "SUCCESS") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "10/10") != null);
}

test "formatReport failure" {
    const allocator = std.testing.allocator;
    const config = EntrypointConfig{ .issue_number = 42 };
    const report = ExitReport{
        .success = false,
        .build_ok = false,
        .error_msg = "build failed",
    };
    const result = formatReport(allocator, config, report);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "build failed") != null);
}

test "ExitReport defaults" {
    const r = ExitReport{};
    try std.testing.expect(!r.success);
    try std.testing.expect(!r.build_ok);
    try std.testing.expectEqual(@as(f32, 0.0), r.test_pass_rate);
}

test "writeFitness skips without RAILWAY vars" {
    // writeFitness should silently return when RAILWAY_* env vars are missing
    // (they're only present inside Railway containers)
    const allocator = std.testing.allocator;
    writeFitness(allocator, ExitReport{});
    // No crash = success — it logged "Missing RAILWAY_* env vars" and returned
}
