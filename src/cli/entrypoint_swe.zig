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

    // Step 4: Run pipeline
    log.info("Step 4: Running pipeline with links {s}...", .{config.pipeline_links});

    const pipeline_exit = runCmd(allocator, &.{
        "tri", "pipeline", "run", "--links", config.pipeline_links, "--issue", issue_num_str,
    }) catch {
        log.err("Pipeline execution failed", .{});
        reportFailure(allocator, config, "Pipeline execution crashed");
        return error.PipelineFailed;
    };

    const success = pipeline_exit == 0;
    log.info("Pipeline exit code: {d} (success={s})", .{ pipeline_exit, if (success) "true" else "false" });

    // Step 5: Report results
    log.info("Step 5: Reporting results...", .{});
    if (success) {
        reportSuccess(allocator, config);
    } else {
        reportFailure(allocator, config, "Pipeline returned non-zero exit code");
    }

    log.info("=== SWE Agent Entrypoint done ===", .{});
}

fn reportSuccess(allocator: std.mem.Allocator, config: EntrypointConfig) void {
    const comment = std.fmt.allocPrint(allocator,
        \\✅ **SWE Agent Complete**
        \\- Issue: #{d}
        \\- Role: {s}
        \\- Model: {s}
        \\- Links: {s}
        \\- Status: SUCCESS
    , .{ config.issue_number, config.agent_role, config.model, config.pipeline_links }) catch return;
    defer allocator.free(comment);

    const issue_str = std.fmt.allocPrint(allocator, "{d}", .{config.issue_number}) catch return;
    defer allocator.free(issue_str);

    _ = runCmd(allocator, &.{
        "gh", "issue", "comment", issue_str, "--body", comment, "--repo", "gHashTag/trinity",
    }) catch {};
}

fn reportFailure(allocator: std.mem.Allocator, config: EntrypointConfig, reason: []const u8) void {
    const comment = std.fmt.allocPrint(allocator,
        \\❌ **SWE Agent Failed**
        \\- Issue: #{d}
        \\- Role: {s}
        \\- Model: {s}
        \\- Error: {s}
    , .{ config.issue_number, config.agent_role, config.model, reason }) catch return;
    defer allocator.free(comment);

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
