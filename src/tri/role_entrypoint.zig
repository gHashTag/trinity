// @origin(manual) @regen(pending)
// =============================================================================
// ROLE ENTRYPOINT -- v5.0 Role Split
// =============================================================================
//
// 5-role agent decomposition: Planner -> Coder -> Reviewer -> Tester -> Integrator
// Each role executes a subset of Golden Chain links.
// Tester requires NO LLM -- pure Zig binary (build test + benchmark).
//
// v5.0 additions:
//   - Handoff protocol: each role writes JSON artifact to .trinity/handoff/
//   - Supervisor loop: Reviewer -> Coder feedback (max 3 iterations)
//   - Tester no-LLM: detects role:tester and skips LLM phase entirely
//
// Pattern: RTADev (ACL 2025) -- each role supervises the previous.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const golden_chain = @import("golden_chain.zig");
const pipeline_executor = @import("pipeline_executor.zig");
const handoff = @import("handoff.zig");

const AgentRole = golden_chain.AgentRole;
const ChainLink = golden_chain.ChainLink;
const LinkMetrics = golden_chain.LinkMetrics;

// =============================================================================
// COLORS
// =============================================================================

const RESET = "\x1b[0m";
const GREEN = "\x1b[38;2;0;229;153m";
const RED = "\x1b[38;2;239;68;68m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const CYAN = "\x1b[38;2;0;255;255m";
const GRAY = "\x1b[38;2;156;156;160m";

// =============================================================================
// CONSTANTS
// =============================================================================

/// Maximum Reviewer -> Coder feedback iterations before giving up.
pub const MAX_REVIEW_ITERATIONS: u8 = 3;

// =============================================================================
// PUBLIC API
// =============================================================================

pub const RoleResult = struct {
    role: AgentRole,
    links_executed: u8,
    links_passed: u8,
    links_failed: u8,
    total_duration_ms: u64,
    status: enum { success, partial, failed },
};

/// Execute all chain links owned by a given role.
pub fn runRole(allocator: std.mem.Allocator, role: AgentRole, task: []const u8) RoleResult {
    const range = role.getLinkRange();

    var executor = pipeline_executor.PipelineExecutor.init(allocator, 1, task);
    defer executor.deinit();

    var result = RoleResult{
        .role = role,
        .links_executed = 0,
        .links_passed = 0,
        .links_failed = 0,
        .total_duration_ms = 0,
        .status = .success,
    };

    std.debug.print("\n{s} {s} -- executing links {d}-{d}\n", .{
        role.getEmoji(), role.getName(), range.start, range.end - 1,
    });

    var link_idx: u8 = range.start;
    while (link_idx < range.end) : (link_idx += 1) {
        const link: ChainLink = @enumFromInt(link_idx);

        // Skip optional links if not applicable
        if (!link.isMandatory()) {
            std.debug.print("  [{d}] {s} -- optional, skipping\n", .{ link_idx, link.getCliName() });
            continue;
        }

        const metrics = executor.executeSingleLink(link) catch |err| {
            result.links_executed += 1;
            result.links_failed += 1;

            if (link.isCritical()) {
                std.debug.print("  [{d}] {s} -- CRITICAL FAILURE: {}\n", .{ link_idx, link.getCliName(), err });
                result.status = .failed;
                return result;
            } else {
                std.debug.print("  [{d}] {s} -- failed (non-critical): {}\n", .{ link_idx, link.getCliName(), err });
                continue;
            }
        };

        result.links_executed += 1;
        result.links_passed += 1;
        result.total_duration_ms += metrics.duration_ms;
        std.debug.print("  [{d}] {s} -- OK ({d}ms)\n", .{ link_idx, link.getCliName(), metrics.duration_ms });
    }

    if (result.links_failed > 0 and result.status != .failed) {
        result.status = .partial;
    }

    std.debug.print("\n{s} {s} complete: {d}/{d} passed ({d}ms)\n", .{
        role.getEmoji(),          role.getName(),
        result.links_passed,      result.links_executed,
        result.total_duration_ms,
    });

    return result;
}

/// Detect role from a list of issue labels.
pub fn detectRoleFromLabels(labels: []const []const u8) ?AgentRole {
    for (labels) |label| {
        if (AgentRole.fromLabel(label)) |role| return role;
    }
    return null;
}

// =============================================================================
// SUBPROCESS HELPER
// =============================================================================

/// Run a subprocess, print status, return true if exit code == 0.
fn runSubprocess(allocator: std.mem.Allocator, argv: []const []const u8, desc: []const u8, step: []const u8) bool {
    std.debug.print("  [{s}] {s} ... ", .{ step, desc });
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawn() catch {
        std.debug.print("{s}FAIL (spawn){s}\n", .{ RED, RESET });
        return false;
    };
    const term = child.wait() catch {
        std.debug.print("{s}FAIL (wait){s}\n", .{ RED, RESET });
        return false;
    };
    const success = switch (term) {
        .Exited => |c| c == 0,
        else => false,
    };
    if (success) {
        std.debug.print("{s}OK{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}FAIL{s}\n", .{ RED, RESET });
    }
    return success;
}

// =============================================================================
// TESTER NO-LLM EXECUTION
// =============================================================================

/// Run the tester role without invoking any LLM.
/// Executes: zig build, zig fmt --check, zig build test, writes tester_report.json.
/// Returns a RoleResult with test outcomes.
pub fn runTesterNoLLM(allocator: std.mem.Allocator, issue_number: u32) RoleResult {
    var result = RoleResult{
        .role = .tester,
        .links_executed = 0,
        .links_passed = 0,
        .links_failed = 0,
        .total_duration_ms = 0,
        .status = .success,
    };

    std.debug.print("\n{s}TESTER (no-LLM){s} -- pure Zig build + test\n", .{ CYAN, RESET });

    const start_ns = std.time.nanoTimestamp();

    // Step 1: zig build
    const build_success = runSubprocess(allocator, &.{ "zig", "build" }, "zig build", "1/3");
    result.links_executed += 1;
    if (build_success) {
        result.links_passed += 1;
    } else {
        result.links_failed += 1;
    }

    // Step 2: zig fmt --check src/
    const fmt_clean = runSubprocess(allocator, &.{ "zig", "fmt", "--check", "src/" }, "zig fmt --check", "2/3");
    result.links_executed += 1;
    if (fmt_clean) {
        result.links_passed += 1;
    } else {
        result.links_failed += 1;
    }

    // Step 3: zig build test
    const test_success = runSubprocess(allocator, &.{ "zig", "build", "test" }, "zig build test", "3/3");
    result.links_executed += 1;
    var tests_passed: u32 = 0;
    const tests_total: u32 = 1;
    if (test_success) {
        result.links_passed += 1;
        tests_passed = 1;
    } else {
        result.links_failed += 1;
    }

    const elapsed_ns = std.time.nanoTimestamp() - start_ns;
    const elapsed_ms = @divTrunc(elapsed_ns, std.time.ns_per_ms);
    result.total_duration_ms = if (elapsed_ms > 0) @intCast(elapsed_ms) else 0;

    if (result.links_failed > 0) {
        result.status = if (result.links_passed > 0) .partial else .failed;
    }

    // Write tester report handoff artifact
    const report = handoff.TesterReport{
        .issue_number = issue_number,
        .tests_passed = tests_passed,
        .tests_total = tests_total,
        .tests_failed_names = &.{},
        .build_success = build_success,
        .fmt_clean = fmt_clean,
        .benchmarks = &.{},
        .regressions = &.{},
        .timestamp = std.time.timestamp(),
    };
    handoff.writeTesterReport(issue_number, report) catch |err| {
        std.debug.print("{s}Warning: could not write tester report: {}{s}\n", .{ GRAY, err, RESET });
    };

    std.debug.print("\n{s}TESTER complete:{s} {d}/{d} checks passed ({d}ms)\n\n", .{
        CYAN,                     RESET,
        result.links_passed,      result.links_executed,
        result.total_duration_ms,
    });

    return result;
}

// =============================================================================
// SUPERVISOR LOOP: Reviewer -> Coder Feedback
// =============================================================================

/// Run the Coder -> Reviewer supervisor loop with up to MAX_REVIEW_ITERATIONS.
///
/// Flow:
///   1. Coder runs its links (7-8)
///   2. Reviewer runs its links (8-10) and writes reviewer_verdict.json
///   3. If verdict.approved == false and iteration < MAX_REVIEW_ITERATIONS:
///      - Coder re-runs with reviewer feedback
///      - Go to step 2
///   4. If still not approved after MAX_REVIEW_ITERATIONS, return the last result
///
/// Returns the final RoleResult from the last Coder or Reviewer execution.
pub fn runCoderReviewerLoop(
    allocator: std.mem.Allocator,
    task: []const u8,
    issue_number: u32,
) !RoleResult {
    var iteration: u8 = 1;
    var last_coder_result: RoleResult = undefined;

    while (iteration <= MAX_REVIEW_ITERATIONS) : (iteration += 1) {
        std.debug.print("\n{s}=== Coder-Reviewer iteration {d}/{d} ==={s}\n", .{
            GOLDEN, iteration, MAX_REVIEW_ITERATIONS, RESET,
        });

        // --- CODER PHASE ---
        last_coder_result = runRole(allocator, .coder, task);

        // Write coder output handoff
        const coder_output = handoff.CoderOutput{
            .issue_number = issue_number,
            .branch = "",
            .files_modified = &.{},
            .commits = &.{},
            .lines_added = 0,
            .lines_removed = 0,
            .timestamp = std.time.timestamp(),
        };
        handoff.writeCoderOutput(issue_number, coder_output) catch |err| {
            std.log.warn("handoff: writeCoderOutput failed: {}", .{err});
        };

        if (last_coder_result.status == .failed) {
            std.debug.print("{s}Coder failed on iteration {d}, aborting loop{s}\n", .{
                RED, iteration, RESET,
            });
            return last_coder_result;
        }

        // --- REVIEWER PHASE ---
        const reviewer_result = runRole(allocator, .reviewer, task);

        if (reviewer_result.status == .failed) {
            // Reviewer found critical issues
            const verdict = handoff.ReviewerVerdict{
                .issue_number = issue_number,
                .approved = false,
                .feedback = &.{"Critical reviewer failure"},
                .iteration = iteration,
                .max_iterations = MAX_REVIEW_ITERATIONS,
                .files_reviewed = &.{},
                .timestamp = std.time.timestamp(),
            };
            handoff.writeReviewerVerdict(issue_number, verdict) catch |err| {
            std.log.warn("handoff: writeReviewerVerdict failed: {}", .{err});
        };

            if (iteration < MAX_REVIEW_ITERATIONS) {
                std.debug.print("{s}Reviewer rejected (iteration {d}/{d}), re-running Coder...{s}\n", .{
                    RED, iteration, MAX_REVIEW_ITERATIONS, RESET,
                });
                continue;
            } else {
                std.debug.print("{s}Reviewer rejected after {d} iterations, giving up{s}\n", .{
                    RED, MAX_REVIEW_ITERATIONS, RESET,
                });
                return reviewer_result;
            }
        }

        // Reviewer approved
        const verdict = handoff.ReviewerVerdict{
            .issue_number = issue_number,
            .approved = true,
            .feedback = &.{},
            .iteration = iteration,
            .max_iterations = MAX_REVIEW_ITERATIONS,
            .files_reviewed = &.{},
            .timestamp = std.time.timestamp(),
        };
        handoff.writeReviewerVerdict(issue_number, verdict) catch |err| {
            std.log.warn("handoff: writeReviewerVerdict failed: {}", .{err});
        };

        std.debug.print("{s}Reviewer approved on iteration {d}{s}\n", .{
            GREEN, iteration, RESET,
        });
        return last_coder_result;
    }

    return last_coder_result;
}

// =============================================================================
// FULL ROLE PIPELINE (with supervisor loop + tester optimization)
// =============================================================================

/// Run the full 5-role pipeline in sequence (single-process mode).
/// Uses the supervisor loop for Coder->Reviewer and no-LLM for Tester.
pub fn runFullRolePipeline(allocator: std.mem.Allocator, task: []const u8) !void {
    return runFullRolePipelineWithIssue(allocator, task, 0);
}

/// Run the full 5-role pipeline with an explicit issue number for handoff.
pub fn runFullRolePipelineWithIssue(allocator: std.mem.Allocator, task: []const u8, issue_number: u32) !void {
    std.debug.print("\n{s}=== Role Pipeline v5.0 ==={s}\n", .{ GOLDEN, RESET });
    std.debug.print("Task: {s}\n", .{task});
    if (issue_number > 0) {
        std.debug.print("Issue: #{d}\n", .{issue_number});
    }
    std.debug.print("\n", .{});

    // --- PLANNER ---
    {
        const result = runRole(allocator, .planner, task);
        if (result.status == .failed) {
            std.debug.print("\n{s}Pipeline halted at PLANNER{s}\n", .{ RED, RESET });
            return error.RoleFailed;
        }

        // Write planner handoff
        if (issue_number > 0) {
            const planner_output = handoff.PlannerOutput{
                .issue_number = issue_number,
                .subtasks = &.{},
                .files = &.{},
                .approach = task,
                .spec_path = "",
                .timestamp = std.time.timestamp(),
            };
            handoff.writePlannerOutput(issue_number, planner_output) catch |err| {
            std.log.warn("handoff: writePlannerOutput failed: {}", .{err});
        };
        }

        std.debug.print("\n-> Handoff: PLANNER -> CODER\n", .{});
    }

    // --- CODER + REVIEWER (supervisor loop) ---
    {
        const result = runCoderReviewerLoop(allocator, task, issue_number) catch |err| {
            std.debug.print("\n{s}Pipeline halted at CODER/REVIEWER loop: {}{s}\n", .{ RED, err, RESET });
            return error.RoleFailed;
        };

        if (result.status == .failed) {
            std.debug.print("\n{s}Pipeline halted at CODER/REVIEWER{s}\n", .{ RED, RESET });
            return error.RoleFailed;
        }

        std.debug.print("\n-> Handoff: REVIEWER -> TESTER\n", .{});
    }

    // --- TESTER (no-LLM optimization) ---
    {
        const result = if (issue_number > 0)
            runTesterNoLLM(allocator, issue_number)
        else
            runRole(allocator, .tester, task);

        if (result.status == .failed) {
            std.debug.print("\n{s}Pipeline halted at TESTER{s}\n", .{ RED, RESET });
            return error.RoleFailed;
        }

        std.debug.print("\n-> Handoff: TESTER -> INTEGRATOR\n", .{});
    }

    // --- INTEGRATOR ---
    {
        const result = runRole(allocator, .integrator, task);
        if (result.status == .failed) {
            std.debug.print("\n{s}Pipeline halted at INTEGRATOR{s}\n", .{ RED, RESET });
            return error.RoleFailed;
        }
    }

    // Print handoff status if we have an issue
    if (issue_number > 0) {
        handoff.printHandoffStatus(issue_number);
    }

    std.debug.print("\n{s}=== All 5 roles complete ==={s}\n\n", .{ GREEN, RESET });
}

// =============================================================================
// SINGLE ROLE DISPATCH (for container entrypoint)
// =============================================================================

/// Execute a single role, writing its handoff artifact.
/// Called from agent-entrypoint when a container has a specific role label.
/// v5.1: Model roulette — sets CLAUDE_MODEL based on role-specific env var.
pub fn dispatchRole(allocator: std.mem.Allocator, role: AgentRole, task: []const u8, issue_number: u32) !RoleResult {
    // v5.1: Model roulette — set model env var based on role
    const model_buf = golden_chain.getModelForRole(role);
    const model = golden_chain.getModelSlice(&model_buf);
    if (model.len > 0) {
        std.debug.print("\n{s}Model roulette: {s} -> {s}{s}\n", .{
            CYAN, role.getName(), model, RESET,
        });
    }

    std.debug.print("\n{s}=== Dispatching role: {s} (issue #{d}) ==={s}\n", .{
        GOLDEN, role.getName(), issue_number, RESET,
    });

    // Tester gets the no-LLM fast path
    if (role == .tester) {
        return runTesterNoLLM(allocator, issue_number);
    }

    // Coder gets the supervisor loop with reviewer
    if (role == .coder) {
        return runCoderReviewerLoop(allocator, task, issue_number) catch |err| {
            std.debug.print("{s}Coder-Reviewer loop failed: {}{s}\n", .{ RED, err, RESET });
            return RoleResult{
                .role = .coder,
                .links_executed = 0,
                .links_passed = 0,
                .links_failed = 1,
                .total_duration_ms = 0,
                .status = .failed,
            };
        };
    }

    // All other roles run normally
    const result = runRole(allocator, role, task);

    // Write handoff artifact based on role
    if (issue_number > 0) {
        switch (role) {
            .planner => {
                const output = handoff.PlannerOutput{
                    .issue_number = issue_number,
                    .subtasks = &.{},
                    .files = &.{},
                    .approach = task,
                    .spec_path = "",
                    .timestamp = std.time.timestamp(),
                };
                handoff.writePlannerOutput(issue_number, output) catch |err| {
            std.log.warn("handoff: writePlannerOutput failed: {}", .{err});
        };
            },
            .reviewer => {
                const verdict = handoff.ReviewerVerdict{
                    .issue_number = issue_number,
                    .approved = result.status != .failed,
                    .feedback = &.{},
                    .iteration = 1,
                    .max_iterations = MAX_REVIEW_ITERATIONS,
                    .files_reviewed = &.{},
                    .timestamp = std.time.timestamp(),
                };
                handoff.writeReviewerVerdict(issue_number, verdict) catch |err| {
            std.log.warn("handoff: writeReviewerVerdict failed: {}", .{err});
        };
            },
            .integrator => {
                // Integrator just logs completion
            },
            .coder, .tester => {}, // Handled above
        }
    }

    return result;
}

// =============================================================================
// TESTS
// =============================================================================

test "detectRoleFromLabels" {
    const labels = [_][]const u8{ "bug", "role:tester", "priority:high" };
    const role = detectRoleFromLabels(&labels);
    try std.testing.expectEqual(AgentRole.tester, role.?);
}

test "detectRoleFromLabels none" {
    const labels = [_][]const u8{ "bug", "agent:ralph" };
    const role = detectRoleFromLabels(&labels);
    try std.testing.expect(role == null);
}

test "MAX_REVIEW_ITERATIONS is 3" {
    try std.testing.expectEqual(@as(u8, 3), MAX_REVIEW_ITERATIONS);
}

test "handoff artifact filenames" {
    try std.testing.expectEqualStrings("planner_output.json", handoff.getArtifactFilename(.planner));
    try std.testing.expectEqualStrings("reviewer_verdict.json", handoff.getArtifactFilename(.reviewer));
    try std.testing.expectEqualStrings("tester_report.json", handoff.getArtifactFilename(.tester));
}

test "handoff directory path" {
    var buf: [256]u8 = undefined;
    const path = handoff.getHandoffDir(&buf, 123);
    try std.testing.expectEqualStrings(".trinity/handoff/issue-123", path);
}
