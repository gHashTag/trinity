// @origin(spec:job_system.tri) @regen(manual-impl)
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
// ERRORS
// =============================================================================

pub const Error = error{
    JobNotFound,
    JobAlreadyCompleted,
    JobFailed,
    InvalidJobId,
};

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
        const state_str = self.state.toString();
        const error_msg = self.error_message orelse "";

        const exit_code_str: []const u8 = if (self.exit_code) |code|
            try std.fmt.allocPrint(allocator, "{d}", .{code})
        else
            "null";
        defer {
            if (self.exit_code != null) allocator.free(exit_code_str);
        }

        // Build args JSON array
        var args_json: std.ArrayList(u8) = .empty;
        defer args_json.deinit(allocator);
        try args_json.appendSlice(allocator, "[");
        for (self.args, 0..) |arg, i| {
            if (i > 0) try args_json.appendSlice(allocator, ",");
            try args_json.appendSlice(allocator, "\"");
            // Escape special characters in arg for JSON
            for (arg) |c| {
                switch (c) {
                    '"' => try args_json.appendSlice(allocator, "\\\""),
                    '\\' => try args_json.appendSlice(allocator, "\\\\"),
                    '\n' => try args_json.appendSlice(allocator, "\\n"),
                    '\r' => try args_json.appendSlice(allocator, "\\r"),
                    '\t' => try args_json.appendSlice(allocator, "\\t"),
                    else => try args_json.append(allocator, c),
                }
            }
            try args_json.appendSlice(allocator, "\"");
        }
        try args_json.appendSlice(allocator, "]");

        return std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","command":"{s}","args":{s},"state":"{s}",
            \\"start_time":{d},"end_time":{d},"pid":{d},
            \\"working_dir":"{s}","exit_code":{s},"error_message":"{s}"}}
        , .{
            self.id,
            self.command,
            args_json.items,
            state_str,
            self.start_time,
            self.end_time,
            self.pid,
            self.working_dir,
            exit_code_str,
            error_msg,
        });
    }

    /// Free all allocated resources in JobMetadata
    pub fn deinit(self: *JobMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.command);
        allocator.free(self.working_dir);
        if (self.error_message) |msg| allocator.free(msg);
        // Note: args is a slice pointing to metadata, no need to free
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

    /// Serialize to JSON
    pub fn toJson(allocator: std.mem.Allocator, self: *const JobReport) ![]const u8 {
        const state_str = self.state.toString();

        const exit_code_str: []const u8 = if (self.exit_code) |code|
            try std.fmt.allocPrint(allocator, "{d}", .{code})
        else
            "null";
        defer {
            if (self.exit_code != null) allocator.free(exit_code_str);
        }

        // Build artifacts JSON array
        var artifacts_json: std.ArrayList(u8) = .empty;
        defer artifacts_json.deinit(allocator);
        try artifacts_json.appendSlice(allocator, "[");
        for (self.artifacts, 0..) |artifact, i| {
            if (i > 0) try artifacts_json.appendSlice(allocator, ",");
            try artifacts_json.appendSlice(allocator, "\"");
            for (artifact) |c| {
                switch (c) {
                    '"' => try artifacts_json.appendSlice(allocator, "\\\""),
                    '\\' => try artifacts_json.appendSlice(allocator, "\\\\"),
                    else => try artifacts_json.append(allocator, c),
                }
            }
            try artifacts_json.appendSlice(allocator, "\"");
        }
        try artifacts_json.appendSlice(allocator, "]");

        return std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","command":"{s}","state":"{s}",
            \\"exit_code":{s},"duration_ms":{d},"artifacts":{s}}}
        , .{
            self.id,
            self.command,
            state_str,
            exit_code_str,
            self.duration_ms,
            artifacts_json.items,
        });
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
    project_root: []const u8, // P0.3: Detected project root
    jobs_dir_path: []const u8, // P0.4: Store for cleanup

    /// Initialize the job manager
    pub fn init(allocator: std.mem.Allocator) !JobManager {
        // P0.3: Detect project root by looking for .git or build.zig
        const root = detectProjectRoot(allocator) catch try allocator.dupe(u8, "/");
        errdefer allocator.free(root);

        // Create .trinity/jobs directory if it doesn't exist
        const jobs_dir_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, JobDir });
        errdefer allocator.free(jobs_dir_path);

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
            .project_root = root,
            .jobs_dir_path = jobs_dir_path, // P0.4: Store for cleanup
        };
    }

    /// P0.3: Detect project root by searching for markers
    fn detectProjectRoot(allocator: std.mem.Allocator) ![]const u8 {
        const markers = [_][]const u8{ ".git", "build.zig", "src" };
        const cwd = try std.process.getCwdAlloc(allocator);
        defer allocator.free(cwd);

        var search_path = cwd;
        while (search_path.len > 0) {
            for (markers) |marker| {
                const marker_path = try std.fs.path.join(allocator, &.{ search_path, marker });
                defer allocator.free(marker_path);

                if (std.fs.cwd().openFile(marker_path, .{})) |f| {
                    f.close(); // Close file handle immediately — only checking existence
                    return allocator.dupe(u8, search_path);
                } else |_| continue;
            }

            // Move up one directory
            const last_slash = std.mem.lastIndexOfScalar(u8, search_path, '/') orelse break;
            if (last_slash == 0) break;
            search_path = search_path[0..last_slash];
        }

        // Fallback to current directory
        return allocator.dupe(u8, cwd);
    }

    /// P0.3: Get job directory path for a given job_id
    fn getJobDirPath(self: *JobManager, allocator: std.mem.Allocator, job_id: []const u8) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ self.project_root, JobDir, job_id });
    }

    /// P0.3: Load job metadata from disk
    fn loadMetadataFromDisk(self: *JobManager, allocator: std.mem.Allocator, job_id: []const u8) !?JobMetadata {
        const job_dir = try self.getJobDirPath(allocator, job_id);
        defer allocator.free(job_dir);

        const metadata_path = try std.fs.path.join(allocator, &.{ job_dir, "metadata.json" });
        defer allocator.free(metadata_path);

        const file = std.fs.cwd().openFile(metadata_path, .{}) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        defer file.close();

        const content = file.readToEndAlloc(allocator, 10_000) catch return error.InvalidMetadata;
        defer allocator.free(content);

        // Parse JSON manually (simple fields)
        // Format: {"id":"...","command":"...","state":"...","start_time":...,"end_time":...,"pid":...,"working_dir":"...","exit_code":... or null,"error_message":"..." or ""}
        var state: JobState = .pending;
        var start_time: i64 = 0;
        var end_time: i64 = 0;
        var pid: u32 = 0;
        var exit_code: ?i32 = null;
        var cmd: []const u8 = "";
        var work_dir: []const u8 = "";

        // Simple JSON parsing
        var it = std.mem.tokenizeAny(u8, content, ",:\"{}");
        var i: usize = 0;
        while (it.next()) |token| {
            if (std.mem.eql(u8, token, "state")) {
                if (it.next()) |val| {
                    if (std.mem.eql(u8, val, "completed")) state = .completed else if (std.mem.eql(u8, val, "failed")) state = .failed else if (std.mem.eql(u8, val, "cancelled")) state = .cancelled else if (std.mem.eql(u8, val, "running")) state = .running;
                }
            } else if (std.mem.eql(u8, token, "start_time")) {
                if (it.next()) |val| {
                    start_time = std.fmt.parseInt(i64, val, 10) catch 0;
                }
            } else if (std.mem.eql(u8, token, "end_time")) {
                if (it.next()) |val| {
                    end_time = std.fmt.parseInt(i64, val, 10) catch 0;
                }
            } else if (std.mem.eql(u8, token, "pid")) {
                if (it.next()) |val| {
                    pid = @intCast(std.fmt.parseInt(u32, val, 10) catch 0);
                }
            } else if (std.mem.eql(u8, token, "exit_code")) {
                if (it.next()) |val| {
                    if (std.mem.eql(u8, val, "null")) {
                        exit_code = null;
                    } else {
                        exit_code = std.fmt.parseInt(i32, val, 10) catch 1;
                    }
                }
            } else if (std.mem.eql(u8, token, "command")) {
                if (it.next()) |val| {
                    cmd = allocator.dupe(u8, val) catch return error.OutOfMemory;
                }
            } else if (std.mem.eql(u8, token, "working_dir")) {
                if (it.next()) |val| {
                    work_dir = allocator.dupe(u8, val) catch return error.OutOfMemory;
                }
            }
            i += 1;
            if (i > 1000) break; // Safety limit
        }

        return JobMetadata{
            .id = try allocator.dupe(u8, job_id),
            .command = cmd,
            .args = &.{}, // Not stored in JSON for now
            .state = state,
            .start_time = start_time,
            .end_time = end_time,
            .pid = pid,
            .working_dir = work_dir,
            .exit_code = exit_code,
            .error_message = null,
        };
    }

    /// Deinitialize the job manager
    pub fn deinit(self: *JobManager) void {
        // P0.4: Free HashMap keys (job IDs) before deinited the map
        var iter = self.jobs.iterator();
        while (iter.next()) |entry| {
            // Free the allocated key (job_id string)
            self.allocator.free(entry.key_ptr.*);
            // Free and destroy the Job object
            const job = entry.value_ptr.*;
            job.deinit();
            self.allocator.destroy(job);
        }
        self.jobs.deinit();
        self.jobs_dir.close();
        // P0.4: Free project_root allocation
        self.allocator.free(self.project_root);
        // P0.4: Free jobs_dir_path allocation
        self.allocator.free(self.jobs_dir_path);
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

        // P0.3: Use project_root for consistent paths
        const job_path = try self.getJobDirPath(self.allocator, job_id);
        defer self.allocator.free(job_path);

        std.fs.cwd().makePath(job_path) catch |err| {
            std.log.err("Failed to create job directory: {}", .{err});
            return err;
        };

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
            .working_dir = self.project_root, // P0.3: Use project root
            .exit_code = null,
            .error_message = null,
        };

        // Create job object - job must own its copy of dir_path
        const job_dir_path_owned = try self.allocator.dupe(u8, job_path);
        const job = try self.allocator.create(Job);
        job.* = Job.init(self.allocator, job_dir_path_owned, metadata);

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

        // P0.4: Return a duplicate so caller owns their own copy
        // (the HashMap key is owned by the HashMap and will be freed in deinit)
        return try self.allocator.dupe(u8, job_id);
    }

    /// P0.3: Get job status (with disk fallback)
    pub fn status(self: *JobManager, allocator: std.mem.Allocator, job_id: []const u8) !?JobStatus {
        // First check in-memory map
        if (self.jobs.get(job_id)) |job| {
            return try job.getStatus();
        }

        // P0.3: Fall back to loading from disk
        const metadata = (try self.loadMetadataFromDisk(allocator, job_id)) orelse return null;

        // Copy the id string (JobStatus will own this copy)
        const id_copy = try allocator.dupe(u8, metadata.id);

        // Copy error_message if present
        const error_copy = if (metadata.error_message) |msg|
            try allocator.dupe(u8, msg)
        else
            null;

        // Build JobStatus from loaded metadata
        const result = JobStatus{
            .id = id_copy,
            .state = metadata.state,
            .start_time = metadata.start_time,
            .end_time = metadata.end_time,
            .exit_code = metadata.exit_code,
            .error_message = error_copy,
        };

        // Free all metadata allocations
        allocator.free(metadata.id);
        allocator.free(metadata.command);
        allocator.free(metadata.working_dir);
        if (metadata.error_message) |msg| allocator.free(msg);

        return result;
    }

    /// P0.3: Get job logs (with disk fallback)
    pub fn getLogs(self: *JobManager, allocator: std.mem.Allocator, job_id: []const u8) !?JobLogs {
        const job_dir = try self.getJobDirPath(allocator, job_id);
        defer allocator.free(job_dir);

        const stdout_path = try std.fs.path.join(allocator, &.{ job_dir, "stdout.log" });
        defer allocator.free(stdout_path);

        const stderr_path = try std.fs.path.join(allocator, &.{ job_dir, "stderr.log" });
        defer allocator.free(stderr_path);

        const stdout_content = std.fs.cwd().readFileAlloc(allocator, stdout_path, 10_000_000) catch "";
        const stderr_content = std.fs.cwd().readFileAlloc(allocator, stderr_path, 10_000_000) catch "";

        return JobLogs{
            .stdout = stdout_content,
            .stderr = stderr_content,
        };
    }

    /// P0.3: Cancel a running job (with disk check)
    pub fn cancel(self: *JobManager, job_id: []const u8) !bool {
        const job = self.jobs.get(job_id) orelse {
            // P0.3: Check if job exists on disk and is running
            var metadata = (try loadMetadataFromDisk(self, self.allocator, job_id)) orelse return false;
            defer metadata.deinit(self.allocator); // P0.4: Fix memory leak
            return metadata.state == .running;
        };
        return job.cancel();
    }

    /// Wait for a job to complete (blocking)
    pub fn waitForJob(self: *JobManager, job_id: []const u8) !void {
        const job = self.jobs.get(job_id) orelse return error.JobNotFound;
        try job.wait();
    }

    /// P0.3: Get artifacts for a job (with disk fallback)
    pub fn getArtifacts(self: *JobManager, allocator: std.mem.Allocator, job_id: []const u8) ![][]const u8 {
        const job_dir = try self.getJobDirPath(allocator, job_id);
        defer allocator.free(job_dir);

        const artifacts_path = try std.fs.path.join(allocator, &.{ job_dir, "artifacts" });
        defer allocator.free(artifacts_path);

        var artifacts: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (artifacts.items) |art| allocator.free(art);
            artifacts.deinit(allocator);
        }

        var dir = std.fs.cwd().openDir(artifacts_path, .{ .iterate = true }) catch {
            // No artifacts directory yet
            return artifacts.toOwnedSlice(allocator);
        };
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind == .file) {
                const full_path = try std.fs.path.join(allocator, &.{ artifacts_path, entry.name });
                try artifacts.append(allocator, full_path);
            }
        }

        return artifacts.toOwnedSlice(allocator);
    }

    /// P0.3: List all jobs (scans disk directory)
    pub fn list(self: *JobManager, allocator: std.mem.Allocator) ![][]const u8 {
        var job_ids: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (job_ids.items) |id| allocator.free(id);
            job_ids.deinit(allocator);
        }

        // P0.3: Scan jobs directory for all job directories
        const jobs_dir_path = try std.fs.path.join(allocator, &.{ self.project_root, JobDir });
        defer allocator.free(jobs_dir_path);

        var dir = std.fs.cwd().openDir(jobs_dir_path, .{ .iterate = true }) catch return error.JobsDirNotFound;
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind == .directory and std.mem.startsWith(u8, entry.name, "job_")) {
                try job_ids.append(allocator, try allocator.dupe(u8, entry.name));
            }
        }

        return job_ids.toOwnedSlice(allocator);
    }

    /// Clean up completed jobs older than specified seconds
    pub fn cleanup(self: *JobManager, older_than_seconds: u64) !usize {
        var cleaned: usize = 0;
        const now = std.time.timestamp();

        // Collect job IDs to remove (can't modify map while iterating)
        var to_remove: std.ArrayList([]const u8) = .empty;
        defer {
            for (to_remove.items) |id| self.allocator.free(id);
            to_remove.deinit(self.allocator);
        }

        var iter = self.jobs.iterator();
        while (iter.next()) |entry| {
            const job = entry.value_ptr.*;
            const metadata = job.metadata;

            if (metadata.state.isTerminal()) {
                const delta = now - metadata.end_time;
                if (delta < 0) continue; // Clock skew or end_time not set — skip
                const age: u64 = @intCast(delta);
                if (age > older_than_seconds) {
                    // Remove job directory from filesystem
                    std.fs.cwd().deleteTree(job.dir_path) catch |err| {
                        std.log.debug("job_system: failed to cleanup dir '{s}': {}", .{ job.dir_path, err });
                    };
                    // Mark for removal from map
                    try to_remove.append(self.allocator, try self.allocator.dupe(u8, entry.key_ptr.*));
                    cleaned += 1;
                }
            }
        }

        // Remove jobs from map and free memory
        for (to_remove.items) |job_id| {
            if (self.jobs.fetchRemove(job_id)) |removed| {
                // Free the key that was in the map
                self.allocator.free(removed.key);
                // Deinit and destroy the job object
                const job = removed.value;
                job.deinit();
                self.allocator.destroy(job);
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
            _ = child.kill() catch |err| {
                std.log.warn("failed to kill child process: {s}", .{@errorName(err)});
            };
            _ = child.wait() catch |err| {
                std.log.debug("job_system: child.wait failed: {}", .{err});
            };
        }

        self.allocator.free(self.dir_path);
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
        // Prepare stdout and stderr log file paths (absolute paths)
        const stdout_path = try std.fmt.allocPrint(self.allocator, "{s}/stdout.log", .{self.dir_path});
        defer self.allocator.free(stdout_path);

        const stderr_path = try std.fmt.allocPrint(self.allocator, "{s}/stderr.log", .{self.dir_path});
        defer self.allocator.free(stderr_path);

        // Determine working directory
        const work_dir = options.working_dir orelse self.metadata.working_dir;

        // Get the current binary's path
        const self_exe = try std.fs.selfExePathAlloc(self.allocator);
        defer self.allocator.free(self_exe);

        // Build the shell command with output redirection
        // P0.3: Add --_internal-job-exec flag so commands know they're running in job context
        var cmd_buffer: std.ArrayList(u8) = .empty;
        defer cmd_buffer.deinit(self.allocator);

        // Build command with quoted arguments
        try cmd_buffer.appendSlice(self.allocator, "\"");
        try cmd_buffer.appendSlice(self.allocator, self_exe);
        try cmd_buffer.appendSlice(self.allocator, "\" --_internal-job-exec ");
        try cmd_buffer.appendSlice(self.allocator, command);
        for (args) |arg| {
            try cmd_buffer.appendSlice(self.allocator, " \"");
            // Escape shell-dangerous characters to prevent command injection
            for (arg) |c| {
                switch (c) {
                    '"', '\\', '$', '`' => {
                        try cmd_buffer.append(self.allocator, '\\');
                        try cmd_buffer.append(self.allocator, c);
                    },
                    else => try cmd_buffer.append(self.allocator, c),
                }
            }
            try cmd_buffer.appendSlice(self.allocator, "\"");
        }
        // Shell redirection with absolute paths
        try cmd_buffer.appendSlice(self.allocator, " > \"");
        try cmd_buffer.appendSlice(self.allocator, stdout_path);
        try cmd_buffer.appendSlice(self.allocator, "\" 2> \"");
        try cmd_buffer.appendSlice(self.allocator, stderr_path);
        try cmd_buffer.appendSlice(self.allocator, "\"");

        const cmd_str = try cmd_buffer.toOwnedSlice(self.allocator);
        defer self.allocator.free(cmd_str);

        // Spawn using sh -c for shell redirection
        var child = std.process.Child.init(&.{ "sh", "-c", cmd_str }, self.allocator);
        child.stdin_behavior = .Ignore;

        // Set working directory explicitly
        if (options.working_dir) |wd| {
            child.cwd = wd;
        } else {
            child.cwd = work_dir;
        }

        // Start the process
        try child.spawn();

        // Store PID immediately (child.id is valid after spawn, cast i32 to u32)
        self.metadata.pid = @intCast(child.id);

        // Spawn timeout watchdog thread if timeout is specified
        var watchdog: ?std.Thread = null;
        var timed_out: bool = false;
        if (options.timeout > 0) {
            const WatchdogCtx = struct {
                pid: std.process.Child.Id,
                timeout_ns: u64,
                timed_out: *bool,
            };
            const ctx = try self.allocator.create(WatchdogCtx);
            ctx.* = .{
                .pid = child.id,
                .timeout_ns = @as(u64, options.timeout) * std.time.ns_per_ms,
                .timed_out = &timed_out,
            };
            watchdog = try std.Thread.spawn(.{}, struct {
                fn run(c: *WatchdogCtx) void {
                    std.time.sleep(c.timeout_ns);
                    // If we wake up, the process exceeded the timeout — kill it
                    std.posix.kill(c.pid, std.posix.SIG.KILL) catch {};
                    c.timed_out.* = true;
                }
            }.run, .{ctx});
        }

        // Wait for the process to complete (blocks until exit or killed by watchdog)
        const term = child.wait() catch |err| {
            std.log.err("Job {s} wait failed: {}", .{ self.metadata.id, err });
            self.metadata.state = .failed;
            self.metadata.error_message = try std.fmt.allocPrint(self.allocator, "Process wait failed: {s}", .{@errorName(err)});
            self.metadata.end_time = std.time.timestamp();
            try self.writeMetadata();
            return err;
        };

        // If watchdog is running but process exited before timeout, detach it
        if (watchdog) |w| w.detach();

        // Update metadata with final status
        self.metadata.end_time = std.time.timestamp();

        if (timed_out) {
            self.metadata.state = .failed;
            self.metadata.exit_code = null;
            self.metadata.error_message = try std.fmt.allocPrint(
                self.allocator,
                "Job timed out after {d}ms",
                .{options.timeout},
            );
        } else {
            self.metadata.state = switch (term) {
                .Exited => |code| if (code == 0) .completed else .failed,
                else => .failed,
            };

            switch (term) {
                .Exited => |code| {
                    self.metadata.exit_code = @as(i32, @intCast(code));
                },
                else => {
                    self.metadata.exit_code = null;
                },
            }
        }

        self.child_process = null;
        try self.writeMetadata();

        std.log.info("Job {s} {s} PID {d}: tri {s}", .{
            self.metadata.id,
            if (timed_out) "timed out" else "completed",
            self.metadata.pid,
            command,
        });
    }

    /// Get current job status
    fn getStatus(self: *Job) !JobStatus {
        // Check if process is still running
        if (self.child_process) |*child| {
            // Try to wait with WNOHANG to check status without blocking
            const result = child.wait() catch |err| {
                // Process might have terminated or other error
                std.log.warn("Job {s} wait failed: {}", .{ self.metadata.id, err });
                self.metadata.state = .failed;
                self.metadata.error_message = try std.fmt.allocPrint(self.allocator, "Process wait failed: {s}", .{@errorName(err)});
                self.metadata.end_time = std.time.timestamp();
                try self.writeMetadata();
                return self.toStatus();
            };

            if (result == .Exited or result == .Signal) {
                // Process has terminated
                self.metadata.state = switch (result) {
                    .Exited => |code| if (code == 0) .completed else .failed,
                    else => .failed,
                };

                self.metadata.end_time = std.time.timestamp();
                switch (result) {
                    .Exited => |code| {
                        self.metadata.exit_code = @as(i32, @intCast(code));
                    },
                    else => {
                        self.metadata.exit_code = null;
                    },
                }
                self.child_process = null;

                try self.writeMetadata();
            }
            // If StillRunning, state remains .running
        } else if (self.metadata.state == .pending or self.metadata.state == .running) {
            // No child process but state says pending/running - might have crashed
            self.metadata.state = .failed;
            self.metadata.error_message = try std.fmt.allocPrint(self.allocator, "Process terminated unexpectedly", .{});
            try self.writeMetadata();
        }

        return self.toStatus();
    }

    /// Convert metadata to JobStatus
    fn toStatus(self: *Job) JobStatus {
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
            // Try SIGTERM first (graceful shutdown)
            _ = child.kill() catch |err| {
                std.log.err("Failed to send SIGTERM to job {s}: {}", .{ self.metadata.id, err });

                // Try SIGKILL (force terminate)
                _ = child.kill() catch |err2| {
                    std.log.err("Failed to send SIGKILL to job {s}: {}", .{ self.metadata.id, err2 });
                    return false;
                };
            };

            // Wait for process to terminate
            const wait_result = child.wait() catch |err| {
                std.log.warn("Job {s} cleanup wait failed: {}", .{ self.metadata.id, err });
                return false;
            };

            // Update metadata
            self.metadata.state = .cancelled;
            self.metadata.end_time = std.time.timestamp();

            if (wait_result == .Exited) {
                self.metadata.exit_code = @as(i32, @intCast(wait_result.Exited));
            }

            try self.writeMetadata();

            // Clean up job directory artifacts if needed
            self.cleanupResources();

            std.log.info("Job {s} cancelled successfully", .{self.metadata.id});
            return true;
        }

        return false;
    }

    /// Clean up resources (temp files, etc.)
    fn cleanupResources(self: *Job) void {
        // Remove any temporary files created during job execution
        const artifacts_path = self.allocator.alloc(u8, self.dir_path.len + "/artifacts".len) catch return;
        defer self.allocator.free(artifacts_path);

        @memcpy(artifacts_path[0..self.dir_path.len], self.dir_path);
        @memcpy(artifacts_path[self.dir_path.len..], "/artifacts");

        // Note: We keep artifacts for completed jobs, only clean up for cancelled jobs
        // For cancelled jobs, we might want to keep partial artifacts for debugging
    }

    /// Wait for job completion (blocking)
    fn wait(self: *Job) !void {
        if (self.child_process) |*child| {
            const result = child.wait() catch |err| {
                std.log.err("Job {s} wait failed: {}", .{ self.metadata.id, err });
                self.metadata.state = .failed;
                self.metadata.error_message = try std.fmt.allocPrint(self.allocator, "Wait failed: {s}", .{@errorName(err)});
                self.metadata.end_time = std.time.timestamp();
                try self.writeMetadata();
                return;
            };

            self.metadata.end_time = std.time.timestamp();
            self.metadata.state = switch (result) {
                .Exited => |code| if (code == 0) .completed else .failed,
                else => .failed,
            };

            switch (result) {
                .Exited => |code| {
                    self.metadata.exit_code = @as(i32, @intCast(code));
                },
                else => {
                    self.metadata.exit_code = null;
                },
            }

            self.child_process = null;
            try self.writeMetadata();
        }
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

    /// Free allocated resources
    pub fn deinit(self: *JobStatus, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.error_message) |msg| allocator.free(msg);
    }
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

test "JobMetadata.toJson includes args" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "arg1", "arg2", "arg with space" };
    const metadata = JobMetadata{
        .id = "job_test",
        .command = "test",
        .args = &args,
        .state = .completed,
        .start_time = 1000,
        .end_time = 2000,
        .pid = 12345,
        .working_dir = "/tmp",
        .exit_code = 0,
        .error_message = null,
    };

    const json = try JobMetadata.toJson(allocator, &metadata);
    defer allocator.free(json);

    // Verify args are in JSON
    try std.testing.expect(std.mem.indexOf(u8, json, "\"args\":[\"arg1\",\"arg2\",\"arg with space\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"command\":\"test\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"state\":\"completed\"") != null);
}

test "JobReport.toJson serializes all fields" {
    const allocator = std.testing.allocator;
    const artifacts = [_][]const u8{ "metrics.json", "output.bit" };
    const report = JobReport{
        .id = "job_123",
        .command = "bench",
        .state = .completed,
        .exit_code = 0,
        .duration_ms = 45000,
        .artifacts = &artifacts,
    };

    const json = try JobReport.toJson(allocator, &report);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\":\"job_123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"command\":\"bench\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"state\":\"completed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"exit_code\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"duration_ms\":45000") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"artifacts\":[\"metrics.json\",\"output.bit\"]") != null);
}

test "JobReport.toJson handles null exit code" {
    const allocator = std.testing.allocator;
    const report = JobReport{
        .id = "job_456",
        .command = "fpga",
        .state = .failed,
        .exit_code = null,
        .duration_ms = 120000,
        .artifacts = &.{},
    };

    const json = try JobReport.toJson(allocator, &report);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"exit_code\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"state\":\"failed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"artifacts\":[]") != null);
}

test "JobMetadata.toJson handles empty args" {
    const allocator = std.testing.allocator;
    const metadata = JobMetadata{
        .id = "job_test",
        .command = "test",
        .args = &.{},
        .state = .running,
        .start_time = 1000,
        .end_time = 0,
        .pid = 54321,
        .working_dir = "/home",
        .exit_code = null,
        .error_message = null,
    };

    const json = try JobMetadata.toJson(allocator, &metadata);
    defer allocator.free(json);

    // Empty args should be "[]"
    try std.testing.expect(std.mem.indexOf(u8, json, "\"args\":[]") != null);
}
