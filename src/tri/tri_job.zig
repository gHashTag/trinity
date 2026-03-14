// @origin(spec:tri_job.tri) @regen(manual-impl)
//! TRI Job Runtime CLI — P0.3: Async Long-Running Commands
//! φ² + 1/φ² = 3 = TRINITY
// @origin(manual) @regen(pending)

const std = @import("std");

const job_system = @import("job_system.zig");
const job_artifact = @import("job_artifact.zig");
const unified_output = @import("unified_output.zig");
const tri_exit_codes = @import("tri_exit_codes.zig");

// Map JobState to ExitCode per P0.3 specification
pub fn jobStateToExitCode(state: job_system.JobState) tri_exit_codes.ExitCode {
    return switch (state) {
        .pending, .running => .timeout,
        .completed => .success,
        .failed => .job_failed,
        .cancelled => .job_failed,
    };
}

/// Escape a string for JSON output
fn escapeJsonString(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, str.len * 2) catch |err| return err;
    errdefer result.deinit(allocator);

    for (str) |c| {
        switch (c) {
            '\\', '"' => {
                try result.append(allocator, '\\');
                try result.append(allocator, c);
            },
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice(allocator);
}

pub fn runJobStart(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-start", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary("Usage: tri job start <command> [args...]");
        try output.addError("VALIDATION_ERROR", "Missing command argument");
        try output.print();
        return;
    }

    const command = args[0];
    const command_args = args[1..];

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const job_id = job_manager.start(command, command_args, .{}) catch |err| {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-start", .agent);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Failed to start job: {}", .{err}));
        try output.addError("RUNTIME_ERROR", try std.fmt.allocPrint(allocator, "Job start failed", .{}));
        try output.print();
        return;
    };

    var output = try unified_output.UnifiedOutput.init(allocator, "job-start", .agent);
    defer output.deinit();

    try output.setSummary(try std.fmt.allocPrint(allocator, "Job {s} started", .{job_id}));
    output.setStatus(.partial);

    // P0.3: Add job-specific data for JSON mode
    output.data_raw = try std.fmt.allocPrint(allocator, "{{\"job_id\":\"{s}\",\"command\":\"{s}\",\"job_state\":\"pending\"}}", .{ job_id, command });

    try output.print();
}

pub fn runJobStatus(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-status", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary("Usage: tri job status <job_id>");
        try output.addError("VALIDATION_ERROR", "Missing job_id");
        try output.print();
        return;
    }

    const job_id = args[0];

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const status_opt = try job_manager.status(allocator, job_id);
    if (status_opt == null) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-status", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Job not found: {s}", .{job_id}));
        try output.addError("NOT_FOUND", "Job does not exist");
        try output.print();
        return;
    }

    var status = status_opt.?;
    defer status.deinit(allocator);

    var output = try unified_output.UnifiedOutput.init(allocator, "job-status", .agent);
    defer output.deinit();

    const exec_status: unified_output.ExecutionStatus = switch (status.state) {
        .pending, .running => .partial,
        .completed => .success,
        .failed => .failure,
        .cancelled => .canceled,
    };
    output.setStatus(exec_status);

    try output.setSummary(try std.fmt.allocPrint(allocator, "Job {s}: {s}", .{ job_id, status.state.toString() }));

    // P0.3: Add job-specific data for JSON mode
    const exit_code_str = if (status.exit_code) |code| try std.fmt.allocPrint(allocator, "{d}", .{code}) else try allocator.dupe(u8, "null");
    defer allocator.free(exit_code_str);
    output.data_raw = try std.fmt.allocPrint(allocator, "{{\"job_id\":\"{s}\",\"job_state\":\"{s}\",\"start_time\":{d},\"end_time\":{d},\"exit_code\":{s}}}", .{ job_id, status.state.toString(), status.start_time, status.end_time, exit_code_str });

    try output.print();
}

pub fn runJobLogs(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-logs", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary("Usage: tri job logs <job_id>");
        try output.addError("VALIDATION_ERROR", "Missing job_id");
        try output.print();
        return;
    }

    const job_id = args[0];

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const logs_opt = try job_manager.getLogs(allocator, job_id);
    if (logs_opt == null) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-logs", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Job not found: {s}", .{job_id}));
        try output.addError("NOT_FOUND", "Job does not exist");
        try output.print();
        return;
    }

    const logs = logs_opt.?;

    var output = try unified_output.UnifiedOutput.init(allocator, "job-logs", .agent);
    defer output.deinit();

    try output.setSummary(try std.fmt.allocPrint(allocator, "Logs for job {s}", .{job_id}));

    const max_log_size = 100_000;
    const stdout_trunc = if (logs.stdout.len > max_log_size)
        try std.fmt.allocPrint(allocator, "{s}... (truncated)", .{logs.stdout[0..max_log_size]})
    else
        logs.stdout;

    const stderr_trunc = if (logs.stderr.len > max_log_size)
        try std.fmt.allocPrint(allocator, "{s}... (truncated)", .{logs.stderr[0..max_log_size]})
    else
        logs.stderr;

    // P0.3: Add job-specific data for JSON mode
    const stdout_escaped = try escapeJsonString(allocator, stdout_trunc);
    defer allocator.free(stdout_escaped);
    const stderr_escaped = try escapeJsonString(allocator, stderr_trunc);
    defer allocator.free(stderr_escaped);

    output.data_raw = try std.fmt.allocPrint(allocator, "{{\"job_id\":\"{s}\",\"stdout_log\":\"{s}\",\"stderr_log\":\"{s}\",\"truncated\":{}}}", .{ job_id, stdout_escaped, stderr_escaped, logs.stdout.len > max_log_size or logs.stderr.len > max_log_size });

    try output.print();

    if (logs.stdout.len != stdout_trunc.len) allocator.free(stdout_trunc);
    if (logs.stderr.len != stderr_trunc.len) allocator.free(stderr_trunc);
}

pub fn runJobArtifacts(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-artifacts", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary("Usage: tri job artifacts <job_id>");
        try output.addError("VALIDATION_ERROR", "Missing job_id");
        try output.print();
        return;
    }

    const job_id = args[0];

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    _ = job_manager.getArtifacts(allocator, job_id) catch |err| {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-artifacts", .agent);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Failed to get artifacts: {}", .{err}));
        try output.addError("RUNTIME_ERROR", "Artifact collection failed");
        try output.print();
        return;
    };

    var collector = job_artifact.ArtifactCollector.init(allocator, job_id) catch |err| {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-artifacts", .agent);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Failed to open artifacts: {}", .{err}));
        try output.addError("RUNTIME_ERROR", "Could not open artifacts directory");
        try output.print();
        return;
    };
    defer collector.deinit();

    const manifest = collector.collect(&.{}) catch |err| {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-artifacts", .agent);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Failed to collect artifacts: {}", .{err}));
        try output.addError("RUNTIME_ERROR", "Artifact collection failed");
        try output.print();
        return;
    };
    defer {
        allocator.free(manifest.job_id);
        for (manifest.artifacts) |*a| {
            allocator.free(a.filename);
            allocator.free(a.checksum);
            if (a.description.len > 0) allocator.free(a.description);
        }
        allocator.free(manifest.artifacts);
    }

    var output = try unified_output.UnifiedOutput.init(allocator, "job-artifacts", .agent);
    defer output.deinit();

    try output.setSummary(try std.fmt.allocPrint(allocator, "Artifacts for job {s}: {d} files", .{ job_id, manifest.artifacts.len }));

    var artifact_list = std.ArrayList(u8).initCapacity(allocator, 0) catch |err| return err;
    try artifact_list.append(allocator, '[');
    for (manifest.artifacts, 0..) |artifact, i| {
        if (i > 0) try artifact_list.append(allocator, ',');
        const artifact_json = try artifact.toJson(allocator);
        defer allocator.free(artifact_json);
        try artifact_list.appendSlice(allocator, artifact_json);
    }
    try artifact_list.append(allocator, ']');

    const list_slice = try artifact_list.toOwnedSlice(allocator);
    defer allocator.free(list_slice);

    // P0.3: Add job-specific data for JSON mode
    output.data_raw = try std.fmt.allocPrint(allocator, "{{\"job_id\":\"{s}\",\"artifacts\":{s},\"count\":{d}}}", .{ job_id, list_slice, manifest.artifacts.len });

    try output.print();
}

pub fn runJobCancel(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-cancel", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary("Usage: tri job cancel <job_id>");
        try output.addError("VALIDATION_ERROR", "Missing job_id");
        try output.print();
        return;
    }

    const job_id = args[0];

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const cancelled = job_manager.cancel(job_id) catch |err| {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-cancel", .agent);
        defer output.deinit();
        output.setStatus(.failure);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Failed to cancel job: {}", .{err}));
        try output.addError("RUNTIME_ERROR", "Cancel failed");
        try output.print();
        return;
    };

    if (!cancelled) {
        var output = try unified_output.UnifiedOutput.init(allocator, "job-cancel", .agent);
        defer output.deinit();
        output.setStatus(.denied);
        try output.setSummary(try std.fmt.allocPrint(allocator, "Job not running: {s}", .{job_id}));
        try output.addError("NOT_RUNNING", "Job is not running");
        try output.print();
        return;
    }

    var output = try unified_output.UnifiedOutput.init(allocator, "job-cancel", .agent);
    defer output.deinit();

    // Exit code is set by setStatus(.canceled)
    output.setStatus(.canceled);
    try output.setSummary(try std.fmt.allocPrint(allocator, "Job {s} cancelled", .{job_id}));

    // P0.3: Add job-specific data for JSON mode
    output.data_raw = try std.fmt.allocPrint(allocator, "{{\"job_id\":\"{s}\",\"cancelled\":true}}", .{job_id});

    try output.print();
}

pub fn runJobList(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const job_ids = try job_manager.list(allocator);
    defer {
        for (job_ids) |id| allocator.free(id);
        allocator.free(job_ids);
    }

    var output = try unified_output.UnifiedOutput.init(allocator, "job-list", .agent);
    defer output.deinit();

    try output.setSummary(try std.fmt.allocPrint(allocator, "{d} jobs", .{job_ids.len}));

    var job_list = std.ArrayList(u8).initCapacity(allocator, 0) catch |err| return err;
    try job_list.append(allocator, '[');
    for (job_ids, 0..) |job_id, i| {
        if (i > 0) try job_list.append(allocator, ',');
        try job_list.append(allocator, '"');
        try job_list.appendSlice(allocator, job_id);
        try job_list.append(allocator, '"');
    }
    try job_list.append(allocator, ']');

    const list_slice = try job_list.toOwnedSlice(allocator);
    defer allocator.free(list_slice);

    // P0.3: Add job-specific data for JSON mode
    output.data_raw = try std.fmt.allocPrint(allocator, "{{\"jobs\":{s},\"count\":{d}}}", .{ list_slice, job_ids.len });

    try output.print();
}
