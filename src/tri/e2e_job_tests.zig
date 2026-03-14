// @origin(spec:e2e_job_tests.tri) @regen(manual-impl)
//! E2E Job System Tests - P0.3 Production Readiness
//!
//! Tests the complete job lifecycle:
//! - Happy path: start → status → logs → artifacts
//! - Replayable state from disk
//! - Project root normalization
//! - List jobs
// @origin(generated) @regen(done)

const std = @import("std");
const job_system = @import("job_system.zig");

// =============================================================================
// TEST 1: Happy Path - Complete Job Lifecycle
// =============================================================================

test "e2e.job.happy_path_constants_command" {
    const allocator = std.testing.allocator;

    // Create a temporary job directory for testing
    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    // Start a job (runs synchronously, blocks until complete)
    const job_id = try job_manager.start("constants", &.{}, .{});
    defer allocator.free(job_id);

    // Check status - should be completed
    const status_opt = try job_manager.status(allocator, job_id);
    try std.testing.expect(status_opt != null);
    const status = status_opt.?;
    try std.testing.expectEqual(job_system.JobState.completed, status.state);
    try std.testing.expectEqual(@as(i32, 0), status.exit_code.?);

    // Get logs - should have stdout content
    const logs_opt = try job_manager.getLogs(allocator, job_id);
    try std.testing.expect(logs_opt != null);
    const logs = logs_opt.?;
    try std.testing.expect(logs.stdout.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, logs.stdout, "Golden Ratio") != null);

    // Get artifacts - constants doesn't generate artifacts but should return empty list
    const artifacts = try job_manager.getArtifacts(allocator, job_id);
    defer {
        for (artifacts) |art| allocator.free(art);
        allocator.free(artifacts);
    }
    // Artifacts may be empty or contain files depending on implementation

    std.log.info("OK E2E Job Happy Path: constants command completed successfully", .{});
}

// =============================================================================
// TEST 2: Replayable State - Status from New Process
// =============================================================================

test "e2e.job.replayable_state_from_disk" {
    const allocator = std.testing.allocator;

    // Create job manager and start a job
    var job_manager1 = try job_system.JobManager.init(allocator);
    defer job_manager1.deinit();

    const job_id = try job_manager1.start("constants", &.{}, .{});
    defer allocator.free(job_id);

    // Create a NEW job manager instance (simulating new CLI invocation)
    var job_manager2 = try job_system.JobManager.init(allocator);
    defer job_manager2.deinit();

    // The job should NOT be in the in-memory map of job_manager2
    try std.testing.expect(job_manager2.jobs.get(job_id) == null);

    // But status should still be retrievable from disk
    const status_opt = try job_manager2.status(allocator, job_id);
    try std.testing.expect(status_opt != null);
    const status = status_opt.?;
    try std.testing.expectEqual(job_system.JobState.completed, status.state);

    // Logs should also be retrievable from disk
    const logs_opt = try job_manager2.getLogs(allocator, job_id);
    try std.testing.expect(logs_opt != null);

    std.log.info("OK E2E Job Replayable State: Status/Logs loaded from disk", .{});
}

// =============================================================================
// TEST 3: Project Root Normalization
// =============================================================================

test "e2e.job.project_root_normalized" {
    const allocator = std.testing.allocator;

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    // The project_root should be detected correctly
    try std.testing.expect(job_manager.project_root.len > 0);

    // Jobs should be stored under project_root/.trinity/jobs/
    const jobs_dir_path = try std.fs.path.join(allocator, &.{ job_manager.project_root, ".trinity", "jobs" });
    defer allocator.free(jobs_dir_path);

    var jobs_dir = std.fs.cwd().openDir(jobs_dir_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try std.testing.expect(false);
            return;
        }
        return err;
    };
    defer jobs_dir.close();

    std.log.info("OK E2E Job Project Root: {s}", .{job_manager.project_root});
}

// =============================================================================
// TEST 4: List Jobs - Scans Disk Directory
// =============================================================================

test "e2e.job.list_scans_disk" {
    const allocator = std.testing.allocator;

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    // Start a job to ensure there's at least one
    const job_id = try job_manager.start("constants", &.{}, .{});
    defer allocator.free(job_id);

    // List all jobs - should scan disk directory
    const job_ids = try job_manager.list(allocator);
    defer {
        for (job_ids) |id| allocator.free(id);
        allocator.free(job_ids);
    }

    try std.testing.expect(job_ids.len >= 1);

    // The job we just started should be in the list
    var found = false;
    for (job_ids) |id| {
        if (std.mem.eql(u8, id, job_id)) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);

    std.log.info("OK E2E Job List: Found {d} jobs on disk", .{job_ids.len});
}

// =============================================================================
// TEST 5: Job Cancel Scenario
// =============================================================================

test "e2e.job.cancel_completed_job" {
    const allocator = std.testing.allocator;

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    // Start a job that completes quickly
    const job_id = try job_manager.start("constants", &.{}, .{});
    defer allocator.free(job_id);

    // Try to cancel - should return false since job is already completed
    const cancelled = try job_manager.cancel(job_id);
    try std.testing.expect(!cancelled);

    // Status should still be completed
    const status_opt = try job_manager.status(allocator, job_id);
    try std.testing.expect(status_opt != null);
    const status = status_opt.?;
    try std.testing.expectEqual(job_system.JobState.completed, status.state);

    std.log.info("OK E2E Job Cancel: API works correctly for completed jobs", .{});
}
