//! Trinity Job System — Async Long-Running Command Execution
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY
//!
//! Job lifecycle:
//!   start → status → logs → artifacts → cancel
//!
//! Job directory structure:
//!   .trinity/jobs/{job-id}/
//!   ├── metadata.json    - Job metadata (command, start_time, etc.)
//!   ├── report.json      - Final execution report
//!   ├── stdout.log       - Standard output capture
//!   ├── stderr.log       - Standard error capture
//!   └── artifacts/       - Generated files (.bit, .xml, metrics.json, etc.)
//!
//! Usage:
//!   const job_id = try JobManager.start(allocator, command_name, args);
//!   const status = try JobManager.status(job_id);
//!   const logs = try JobManager.getLogs(allocator, job_id);
//!   try JobManager.cancel(job_id);

const std = @import("std");
const builtin = @import("builtin");

// =============================================================================
// JOB STATE
// =============================================================================

/// Job execution state
pub const JobState = enum {
    /// Job queued but not yet started
    pending,
    /// Job currently executing
    running,
    /// Job completed successfully
    completed,
    /// Job failed with error
    failed,
    /// Job cancelled by user
    cancelled,

    pub fn toString(self: JobState) []const u8 {
        return switch (self) {
            .pending => "pending",
            .running => "running",
            .completed => "completed",
            .failed => "failed",
            .cancelled => "cancelled",
        };
    }

    pub fn isTerminal(self: JobState) bool {
        return switch (self) {
            .completed, .failed, .cancelled => true,
            .pending, .running => false,
        };
    }
};

// =============================================================================
// JOB METADATA
// =============================================================================

/// Job metadata stored in metadata.json
pub const JobMetadata = struct {
    /// Unique job identifier (UUID or timestamp-based)
    id: []const u8,
    /// Command name (e.g., "bench", "fpga", "test")
    command: []const u8,
    /// Command arguments
    args: []const []const u8,
    /// Current job state
    state: JobState,
    /// Job start time (Unix timestamp)
    start_time: i64,
    /// Job end time (0 if still running)
    end_time: i64,
    /// Process ID (0 if not started)
    pid: u32,
    /// Working directory
    working_dir: []const u8,
    /// Exit code (null if not completed)
    exit_code: ?i32,
    /// Error message (null if no error)
    error_message: ?[]const u8,

    /// Serialize to JSON
    pub fn toJson(allocator: std.mem.Allocator, self: *const JobMetadata) ![]const u8 {
        _ = self.args; // TODO: include args in JSON
        const state_str = self.state.toString();
        const error_msg = self.error_message orelse "";

        const exit_code_str: []const u8 = if (self.exit_code) |code|
            try std.fmt.allocPrint(allocator, "{d}", .{code})
        else
            "null";

        return std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","command":"{s}","args":[],"state":"{s}",
            \\"start_time":{d},"end_time":{d},"pid":{d},
            \\"working_dir":"{s}","exit_code":{s},"error_message":"{s}"}}
        , .{
            self.id,
            self.command,
            state_str,
            self.start_time,
            self.end_time,
            self.pid,
            self.working_dir,
            exit_code_str,
            error_msg,
        });
    }
};

/// Final job report stored in report.json
pub const JobReport = struct {
    /// Job ID
    id: []const u8,
    /// Command name
    command: []const u8,
    /// Final state
    state: JobState,
    /// Exit code (null if not exited)
    exit_code: ?i32,
    /// Duration in milliseconds
    duration_ms: u64,
    /// Artifact files generated
    artifacts: []const []const u8,
    /// Metrics (command-specific)
    metrics: std.StringDict,

    /// Serialize to JSON
    pub fn toJson(allocator: std.mem.Allocator, self: *const JobReport) ![]const u8 {
        _ = allocator;
        _ = self;
        return error.NotImplemented;
    }
};

// =============================================================================
// JOB MANAGER
// =============================================================================

/// Job manager - singleton for managing all jobs
pub const JobManager = struct {
    const JobsMap = std.StringHashMap(*Job);
    const JobDir = ".trinity/jobs";

    allocator: std.mem.Allocator,
    jobs: JobsMap,
    jobs_dir: std.fs.Dir,

    /// Initialize the job manager
    pub fn init(allocator: std.mem.Allocator) !JobManager {
        // Create .trinity/jobs directory if it doesn't exist
        const jobs_dir_path = JobDir;

        std.fs.cwd().makePath(jobs_dir_path) catch |err| {
            std.log.err("Failed to create jobs directory: {}", .{err});
            return err;
        };

        const jobs_dir = try std.fs.cwd().openDir(jobs_dir_path, .{});
        errdefer jobs_dir.close();

        return JobManager{
            .allocator = allocator,
            .jobs = JobsMap.init(allocator),
            .jobs_dir = jobs_dir,
        };
    }

    /// Deinitialize the job manager
    pub fn deinit(self: *JobManager) void {
        var iter = self.jobs.iterator();
        while (iter.next()) |entry| {
            const job = entry.value_ptr.*;
            job.deinit();
            self.allocator.destroy(job);
        }
        self.jobs.deinit();
        self.jobs_dir.close();
    }

    /// Start a new job
    pub fn start(
        self: *JobManager,
        command: []const u8,
        args: []const []const u8,
        options: StartOptions,
    ) ![]const u8 {
        // Generate unique job ID
        const job_id = try generateJobId(self.allocator);

        // Create job directory path
        const job_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ JobDir, job_id });
        defer self.allocator.free(job_path);

        std.fs.cwd().makePath(job_path) catch |err| {
            std.log.err("Failed to create job directory: {}", .{err});
            return err;
        };

        var job_dir = try std.fs.cwd().openDir(job_path, .{});
        defer job_dir.close();

        // Get current working directory
        const cwd = std.process.getCwdAlloc(self.allocator) catch ".";

        // Create job metadata
        const metadata = try self.allocator.create(JobMetadata);
        metadata.* = JobMetadata{
            .id = try self.allocator.dupe(u8, job_id),
            .command = try self.allocator.dupe(u8, command),
            .args = try duplicateStringSlice(self.allocator, args),
            .state = .pending,
            .start_time = std.time.timestamp(),
            .end_time = 0,
            .pid = 0,
            .working_dir = cwd, // Now owned by metadata
            .exit_code = null,
            .error_message = null,
        };

        // Create job object
        const job = try self.allocator.create(Job);
        job.* = Job.init(self.allocator, job_path, metadata);

        // Store in jobs map
        try self.jobs.put(job_id, job);

        // Write initial metadata
        try job.writeMetadata();

        // Spawn job process
        if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
            try job.spawnProcess(command, args, options);
        } else {
            return error.PlatformNotSupported;
        }

        return job_id;
    }

    /// Get job status
    pub fn status(self: *JobManager, job_id: []const u8) !?JobStatus {
        const job = self.jobs.get(job_id) orelse return null;
        const s = try job.getStatus();
        return s;
    }

    /// Get job logs
    pub fn getLogs(self: *JobManager, allocator: std.mem.Allocator, job_id: []const u8) !?JobLogs {
        const job = self.jobs.get(job_id) orelse return null;
        return job.getLogs(allocator);
    }

    /// Cancel a running job
    pub fn cancel(self: *JobManager, job_id: []const u8) !bool {
        const job = self.jobs.get(job_id) orelse return false;
        return job.cancel();
    }

    /// List all jobs
    pub fn list(self: *JobManager, allocator: std.mem.Allocator) ![][]const u8 {
        var job_ids = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (job_ids.items) |id| allocator.free(id);
            job_ids.deinit();
        }

        var iter = self.jobs.iterator();
        while (iter.next()) |entry| {
            try job_ids.append(try self.allocator.dupe(u8, entry.key_ptr.*));
        }

        return job_ids.toOwnedSlice();
    }

    /// Clean up completed jobs older than specified seconds
    pub fn cleanup(self: *JobManager, older_than_seconds: u64) !usize {
        var cleaned: usize = 0;
        const now = std.time.timestamp();

        var iter = self.jobs.iterator();
        while (iter.next()) |entry| {
            const job = entry.value_ptr.*;
            const metadata = job.metadata;

            if (metadata.state.isTerminal()) {
                const age = @as(u64, @intCast(now - metadata.end_time));
                if (age > older_than_seconds) {
                    // TODO: Remove job directory and free memory
                    cleaned += 1;
                }
            }
        }

        return cleaned;
    }

};

// =============================================================================
// JOB
// =============================================================================

/// Individual job instance
pub const Job = struct {
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    metadata: *JobMetadata,
    child_process: ?std.process.Child,

    /// Initialize a new job
    fn init(allocator: std.mem.Allocator, dir_path: []const u8, metadata: *JobMetadata) Job {
        return Job{
            .allocator = allocator,
            .dir_path = dir_path,
            .metadata = metadata,
            .child_process = null,
        };
    }

    /// Deinitialize job
    fn deinit(self: *Job) void {
        if (self.child_process) |*child| {
            _ = child.kill() catch {};
            _ = child.wait() catch {};
        }

        self.allocator.free(self.metadata.id);
        self.allocator.free(self.metadata.command);
        for (self.metadata.args) |arg| self.allocator.free(arg);
        self.allocator.free(self.metadata.args);
        self.allocator.free(self.metadata.working_dir);
        if (self.metadata.error_message) |msg| self.allocator.free(msg);

        self.allocator.destroy(self.metadata);
    }

    /// Write metadata to disk
    fn writeMetadata(self: *Job) !void {
        const json = try JobMetadata.toJson(self.allocator, self.metadata);
        defer self.allocator.free(json);

        const metadata_path = try std.fmt.allocPrint(self.allocator, "{s}/metadata.json", .{self.dir_path});
        defer self.allocator.free(metadata_path);

        const file = try std.fs.cwd().createFile(metadata_path, .{});
        defer file.close();

        try file.writeAll(json);
    }

    /// Spawn job process (Unix-only for now)
    fn spawnProcess(self: *Job, command: []const u8, args: []const []const u8, options: StartOptions) !void {
        _ = args;
        _ = options;

        // Prepare stdout and stderr log files
        const stdout_path = try std.fmt.allocPrint(self.allocator, "{s}/stdout.log", .{self.dir_path});
        defer self.allocator.free(stdout_path);

        const stderr_path = try std.fmt.allocPrint(self.allocator, "{s}/stderr.log", .{self.dir_path});
        defer self.allocator.free(stderr_path);

        // Open log files
        const stdout_file = try std.fs.cwd().createFile(stdout_path, .{});
        defer stdout_file.close();

        const stderr_file = try std.fs.cwd().createFile(stderr_path, .{});
        defer stderr_file.close();

        // TODO: Spawn child process with stdout/stderr redirected to log files
        // For now, mark as running (actual process spawning depends on use case)
        self.metadata.state = .running;
        try self.writeMetadata();

        std.log.info("Job {s} started: command={s}", .{ self.metadata.id, command });
    }

    /// Get current job status
    fn getStatus(self: *Job) !JobStatus {
        // Check if process is still running
        if (self.child_process) |*child| {
            // In Zig 0.15, poll() was removed. For now, if we have a child process,
            // assume it's running. A more complete implementation would use
            // waitpid with WNOHANG for non-blocking status checks.
            _ = child;
        } else if (self.metadata.state == .pending or self.metadata.state == .running) {
            // No child process but state says pending/running - might have crashed
            self.metadata.state = .failed;
        }

        return JobStatus{
            .id = self.metadata.id,
            .state = self.metadata.state,
            .start_time = self.metadata.start_time,
            .end_time = self.metadata.end_time,
            .exit_code = self.metadata.exit_code,
            .error_message = self.metadata.error_message,
        };
    }

    /// Get job logs
    fn getLogs(self: *Job, allocator: std.mem.Allocator) !JobLogs {
        const stdout_path = try std.fmt.allocPrint(allocator, "{s}/stdout.log", .{self.dir_path});
        defer allocator.free(stdout_path);

        const stderr_path = try std.fmt.allocPrint(allocator, "{s}/stderr.log", .{self.dir_path});
        defer allocator.free(stderr_path);

        const stdout_content = std.fs.cwd().readFileAlloc(allocator, stdout_path, 10_000_000) catch "";
        const stderr_content = std.fs.cwd().readFileAlloc(allocator, stderr_path, 10_000_000) catch "";

        return JobLogs{
            .stdout = stdout_content,
            .stderr = stderr_content,
        };
    }

    /// Cancel the job
    fn cancel(self: *Job) !bool {
        if (self.metadata.state != .running) return false;

        if (self.child_process) |*child| {
            child.kill() catch |err| {
                std.log.err("Failed to kill job {s}: {}", .{ self.metadata.id, err });
                return false;
            };

            self.metadata.state = .cancelled;
            self.metadata.end_time = std.time.timestamp();
            try self.writeMetadata();

            return true;
        }

        return false;
    }
};

// =============================================================================
// JOB STATUS
// =============================================================================

/// Job status snapshot
pub const JobStatus = struct {
    /// Job ID
    id: []const u8,
    /// Current state
    state: JobState,
    /// Start time (Unix timestamp)
    start_time: i64,
    /// End time (0 if running)
    end_time: i64,
    /// Exit code (null if not exited)
    exit_code: ?i32,
    /// Error message (null if no error)
    error_message: ?[]const u8,
};

/// Job logs output
pub const JobLogs = struct {
    /// Standard output
    stdout: []const u8,
    /// Standard error
    stderr: []const u8,
};

/// Job start options
pub const StartOptions = struct {
    /// Timeout in seconds (0 = no timeout)
    timeout: u32 = 0,
    /// Working directory (null = current)
    working_dir: ?[]const u8 = null,
};

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/// Generate a unique job ID
fn generateJobId(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp = std.time.timestamp();
    const random = std.crypto.random.int(u32);
    return std.fmt.allocPrint(allocator, "job_{d}_{x}", .{ timestamp, random });
}

/// Duplicate a slice of strings
fn duplicateStringSlice(allocator: std.mem.Allocator, slice: []const []const u8) ![][]const u8 {
    const duped = try allocator.alloc([]const u8, slice.len);
    for (slice, 0..) |s, i| {
        duped[i] = try allocator.dupe(u8, s);
    }
    return duped;
}

// =============================================================================
// TESTS
// =============================================================================

test "JobState.isTerminal" {
    try std.testing.expect(!JobState.pending.isTerminal());
    try std.testing.expect(!JobState.running.isTerminal());
    try std.testing.expect(JobState.completed.isTerminal());
    try std.testing.expect(JobState.failed.isTerminal());
    try std.testing.expect(JobState.cancelled.isTerminal());
}

test "JobState.toString" {
    try std.testing.expectEqualStrings("pending", JobState.pending.toString());
    try std.testing.expectEqualStrings("running", JobState.running.toString());
    try std.testing.expectEqualStrings("completed", JobState.completed.toString());
    try std.testing.expectEqualStrings("failed", JobState.failed.toString());
    try std.testing.expectEqualStrings("cancelled", JobState.cancelled.toString());
}

test "generateJobId format" {
    const allocator = std.testing.allocator;
    const id = try generateJobId(allocator);
    defer allocator.free(id);

    try std.testing.expect(id.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, id, "job_"));
}
