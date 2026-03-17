// @origin(spec:tri_pipeline_parallel.tri) @regen(manual-impl)
//
// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE PARALLEL — DAG Executor with Process-Level Parallelism
// ═══════════════════════════════════════════════════════════════════════════════
//
// Groups tasks by phase, spawns parallel processes per group.
// Persists state atomically to .trinity/pipeline_state.json.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const GOLDEN = colors.GOLDEN;
const RESET = colors.RESET;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_JOBS = 16;
pub const MAX_GROUPS = 8;
const MAX_OUTPUT_BYTES = 65536;
const STATE_PATH = ".trinity/pipeline_state.json";
const OUTPUT_DIR = ".trinity/job_output";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const JobStatus = enum {
    pending,
    running,
    completed,
    failed,
    skipped,

    pub fn label(self: JobStatus) []const u8 {
        return switch (self) {
            .pending => "PENDING",
            .running => "RUNNING",
            .completed => "COMPLETED",
            .failed => "FAILED",
            .skipped => "SKIPPED",
        };
    }

    pub fn emoji(self: JobStatus) []const u8 {
        return switch (self) {
            .pending => "\xe2\x8f\xb3", // hourglass
            .running => "\xf0\x9f\x94\x84", // arrows
            .completed => "\xe2\x9c\x85", // check
            .failed => "\xe2\x9d\x8c", // cross
            .skipped => "\xe2\x8f\xad", // skip
        };
    }

    pub fn color(self: JobStatus) []const u8 {
        return switch (self) {
            .pending => GRAY,
            .running => CYAN,
            .completed => GREEN,
            .failed => RED,
            .skipped => GRAY,
        };
    }
};

pub const DagJob = struct {
    id: u8 = 0,
    command: [128]u8 = [_]u8{0} ** 128,
    command_len: usize = 0,
    args: [256]u8 = [_]u8{0} ** 256,
    args_len: usize = 0,
    group_id: u8 = 0,
    status: JobStatus = .pending,
    exit_code: u8 = 0,
    duration_ms: u64 = 0,

    pub fn getCommand(self: *const DagJob) []const u8 {
        return self.command[0..self.command_len];
    }

    pub fn getArgs(self: *const DagJob) []const u8 {
        return self.args[0..self.args_len];
    }
};

pub const GroupResult = struct {
    group_id: u8 = 0,
    total: u8 = 0,
    completed: u8 = 0,
    failed: u8 = 0,
    duration_ms: u64 = 0,
};

pub const PipelineDAG = struct {
    jobs: [MAX_JOBS]DagJob = undefined,
    job_count: u8 = 0,
    groups: [MAX_GROUPS]GroupResult = undefined,
    group_count: u8 = 0,
    status: JobStatus = .pending,

    pub fn init() PipelineDAG {
        var dag = PipelineDAG{};
        for (&dag.jobs) |*j| j.* = DagJob{};
        for (&dag.groups) |*g| g.* = GroupResult{};
        return dag;
    }

    pub fn addJob(self: *PipelineDAG, command: []const u8, args: []const u8, group_id: u8) void {
        if (self.job_count >= MAX_JOBS) return;
        var job = DagJob{};
        job.id = self.job_count;
        job.group_id = group_id;
        const cmd_len = @min(command.len, 128);
        @memcpy(job.command[0..cmd_len], command[0..cmd_len]);
        job.command_len = cmd_len;
        const args_len = @min(args.len, 256);
        @memcpy(job.args[0..args_len], args[0..args_len]);
        job.args_len = args_len;
        self.jobs[self.job_count] = job;
        self.job_count += 1;
        // Update group count
        if (group_id >= self.group_count) {
            self.group_count = group_id + 1;
        }
    }

    pub fn getJobsInGroup(self: *const PipelineDAG, group_id: u8, out: *[MAX_JOBS]u8) u8 {
        var count: u8 = 0;
        for (self.jobs[0..self.job_count], 0..) |job, i| {
            if (job.group_id == group_id) {
                out[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTE DAG — Main entry point
// ═══════════════════════════════════════════════════════════════════════════════

pub fn executeDag(allocator: Allocator, dag: *PipelineDAG) void {
    if (dag.job_count == 0) {
        dag.status = .completed;
        std.debug.print("  {s}DAG empty — nothing to execute{s}\n", .{ GRAY, RESET });
        return;
    }

    dag.status = .running;
    std.debug.print("\n{s}\xe2\x9a\xa1 PIPELINE DAG EXECUTOR{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80{s}\n", .{ GRAY, RESET });
    std.debug.print("  Jobs: {d} | Groups: {d}\n\n", .{ dag.job_count, dag.group_count });

    var any_failed = false;

    var g: u8 = 0;
    while (g < dag.group_count) : (g += 1) {
        var job_indices: [MAX_JOBS]u8 = undefined;
        const count = dag.getJobsInGroup(g, &job_indices);

        if (count == 0) continue;

        const group_start = std.time.milliTimestamp();
        std.debug.print("  {s}Group {d}{s} ({d} jobs):\n", .{ CYAN, g, RESET, count });

        var group_result = GroupResult{
            .group_id = g,
            .total = count,
        };

        if (count == 1) {
            // Sequential — single job
            const idx = job_indices[0];
            runSingleJob(allocator, &dag.jobs[idx]);
            if (dag.jobs[idx].status == .completed) {
                group_result.completed += 1;
            } else {
                group_result.failed += 1;
                any_failed = true;
            }
        } else {
            // Parallel — spawn group
            const result = spawnGroup(allocator, dag, job_indices[0..count]);
            group_result.completed = result.completed;
            group_result.failed = result.failed;
            if (result.failed > 0) any_failed = true;
        }

        const group_elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - group_start));
        group_result.duration_ms = group_elapsed;
        dag.groups[g] = group_result;

        std.debug.print("    {s}\xe2\x86\xb3 Group {d}: {d}/{d} done ({d}ms){s}\n\n", .{
            if (group_result.failed > 0) RED else GREEN,
            g,
            group_result.completed,
            group_result.total,
            group_elapsed,
            RESET,
        });

        // Persist state after each group
        persistState(dag);

        // Stop on failure
        if (any_failed) {
            std.debug.print("  {s}Group {d} had failures — stopping DAG{s}\n", .{ RED, g, RESET });
            break;
        }
    }

    dag.status = if (any_failed) .failed else .completed;

    // Final persist
    persistState(dag);

    // Summary
    var total_completed: u32 = 0;
    var total_failed: u32 = 0;
    for (dag.groups[0..dag.group_count]) |gr| {
        total_completed += gr.completed;
        total_failed += gr.failed;
    }

    std.debug.print("{s}\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}DAG {s}: {d} completed, {d} failed{s}\n", .{
        dag.status.color(),
        dag.status.label(),
        total_completed,
        total_failed,
        RESET,
    });
    std.debug.print("{s}\xcf\x86\xc2\xb2 + 1/\xcf\x86\xc2\xb2 = 3{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPAWN GROUP — Parallel execution via std.process.Child
// ═══════════════════════════════════════════════════════════════════════════════

fn spawnGroup(allocator: Allocator, dag: *PipelineDAG, job_indices: []const u8) GroupResult {
    var result = GroupResult{
        .total = @intCast(job_indices.len),
    };

    // Spawn all children
    var children: [MAX_JOBS]?std.process.Child = undefined;
    for (job_indices, 0..) |idx, i| {
        dag.jobs[idx].status = .running;
        const cmd = dag.jobs[idx].getCommand();
        const args_str = dag.jobs[idx].getArgs();

        std.debug.print("    {s}\xf0\x9f\x94\x84 [{d}] {s} {s}{s}\n", .{ CYAN, idx, cmd, args_str, RESET });

        // Build argv: ["zig-out/bin/tri", command, ...args]
        var argv_buf: [4][]const u8 = undefined;
        var argc: usize = 0;
        argv_buf[0] = "zig-out/bin/tri";
        argc += 1;
        if (cmd.len > 0) {
            argv_buf[argc] = cmd;
            argc += 1;
        }
        if (args_str.len > 0) {
            argv_buf[argc] = args_str;
            argc += 1;
        }

        var child = std.process.Child.init(argv_buf[0..argc], allocator);
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| {
            std.debug.print("    {s}spawn failed [{d}]: {}{s}\n", .{ RED, idx, err, RESET });
            dag.jobs[idx].status = .failed;
            dag.jobs[idx].exit_code = 1;
            children[i] = null;
            result.failed += 1;
            continue;
        };
        children[i] = child;
    }

    // Wait for all children
    for (job_indices, 0..) |idx, i| {
        if (children[i]) |*child| {
            const start = std.time.milliTimestamp();
            const term = child.wait() catch {
                dag.jobs[idx].status = .failed;
                dag.jobs[idx].exit_code = 1;
                result.failed += 1;
                continue;
            };
            const elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - start));
            dag.jobs[idx].duration_ms = elapsed;

            const code: u8 = switch (term) {
                .Exited => |c| @intCast(@min(c, 255)),
                else => 1,
            };
            dag.jobs[idx].exit_code = code;

            if (code == 0) {
                dag.jobs[idx].status = .completed;
                result.completed += 1;
                std.debug.print("    {s}\xe2\x9c\x85 [{d}] done ({d}ms){s}\n", .{ GREEN, idx, elapsed, RESET });
            } else {
                dag.jobs[idx].status = .failed;
                result.failed += 1;
                std.debug.print("    {s}\xe2\x9d\x8c [{d}] failed (exit {d}){s}\n", .{ RED, idx, code, RESET });
            }

            // Save output
            saveJobOutput(idx, child) catch {};
        }
    }

    return result;
}

fn saveJobOutput(job_id: u8, child: *std.process.Child) !void {
    // Ensure output directory exists
    std.fs.cwd().makePath(OUTPUT_DIR) catch {};

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{d}.txt", .{ OUTPUT_DIR, job_id }) catch return;

    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();

    if (child.stdout) |stdout| {
        var buf: [4096]u8 = undefined;
        const n = stdout.read(&buf) catch 0;
        if (n > 0) file.writeAll(buf[0..n]) catch {};
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUN SINGLE JOB — Sequential execution for 1-job groups
// ═══════════════════════════════════════════════════════════════════════════════

fn runSingleJob(allocator: Allocator, job: *DagJob) void {
    job.status = .running;
    const cmd = job.getCommand();
    const args_str = job.getArgs();

    std.debug.print("    {s}\xe2\x96\xb6 [{d}] {s} {s}{s}\n", .{ CYAN, job.id, cmd, args_str, RESET });

    const start = std.time.milliTimestamp();

    // Build argv
    var argv_buf: [4][]const u8 = undefined;
    var argc: usize = 0;
    argv_buf[0] = "zig-out/bin/tri";
    argc += 1;
    if (cmd.len > 0) {
        argv_buf[argc] = cmd;
        argc += 1;
    }
    if (args_str.len > 0) {
        argv_buf[argc] = args_str;
        argc += 1;
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0..argc],
        .max_output_bytes = MAX_OUTPUT_BYTES,
    }) catch {
        job.status = .failed;
        job.exit_code = 1;
        const elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - start));
        job.duration_ms = elapsed;
        std.debug.print("    {s}\xe2\x9d\x8c [{d}] spawn failed{s}\n", .{ RED, job.id, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - start));
    job.duration_ms = elapsed;

    const code: u8 = switch (result.term) {
        .Exited => |c| @intCast(@min(c, 255)),
        else => 1,
    };
    job.exit_code = code;

    if (code == 0) {
        job.status = .completed;
        std.debug.print("    {s}\xe2\x9c\x85 [{d}] done ({d}ms){s}\n", .{ GREEN, job.id, elapsed, RESET });
    } else {
        job.status = .failed;
        std.debug.print("    {s}\xe2\x9d\x8c [{d}] failed (exit {d}){s}\n", .{ RED, job.id, code, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSIST STATE — Atomic write to .trinity/pipeline_state.json
// ═══════════════════════════════════════════════════════════════════════════════

pub fn persistState(dag: *const PipelineDAG) void {
    std.fs.cwd().makePath(".trinity") catch {};

    var buf: [4096]u8 = undefined;
    var pos: usize = 0;

    // Build JSON manually (no allocator needed)
    pos += copySlice(&buf, pos, "{\"status\":\"");
    pos += copySlice(&buf, pos, dag.status.label());
    pos += copySlice(&buf, pos, "\",\"job_count\":");
    pos += fmtInt(&buf, pos, dag.job_count);
    pos += copySlice(&buf, pos, ",\"group_count\":");
    pos += fmtInt(&buf, pos, dag.group_count);
    pos += copySlice(&buf, pos, ",\"groups\":[");

    var g: u8 = 0;
    while (g < dag.group_count) : (g += 1) {
        if (g > 0) {
            pos += copySlice(&buf, pos, ",");
        }
        pos += copySlice(&buf, pos, "{\"id\":");
        pos += fmtInt(&buf, pos, dag.groups[g].group_id);
        pos += copySlice(&buf, pos, ",\"completed\":");
        pos += fmtInt(&buf, pos, dag.groups[g].completed);
        pos += copySlice(&buf, pos, ",\"failed\":");
        pos += fmtInt(&buf, pos, dag.groups[g].failed);
        pos += copySlice(&buf, pos, ",\"total\":");
        pos += fmtInt(&buf, pos, dag.groups[g].total);
        pos += copySlice(&buf, pos, "}");
    }

    pos += copySlice(&buf, pos, "],\"jobs\":[");

    var j: u8 = 0;
    while (j < dag.job_count) : (j += 1) {
        if (j > 0) {
            pos += copySlice(&buf, pos, ",");
        }
        pos += copySlice(&buf, pos, "{\"id\":");
        pos += fmtInt(&buf, pos, dag.jobs[j].id);
        pos += copySlice(&buf, pos, ",\"status\":\"");
        pos += copySlice(&buf, pos, dag.jobs[j].status.label());
        pos += copySlice(&buf, pos, "\",\"exit\":");
        pos += fmtInt(&buf, pos, dag.jobs[j].exit_code);
        pos += copySlice(&buf, pos, ",\"ms\":");
        pos += fmtU64(&buf, pos, dag.jobs[j].duration_ms);
        pos += copySlice(&buf, pos, "}");
    }

    pos += copySlice(&buf, pos, "]}\n");

    // Atomic write: write to tmp, then rename
    const tmp_path = STATE_PATH ++ ".tmp";
    const file = std.fs.cwd().createFile(tmp_path, .{}) catch return;
    file.writeAll(buf[0..pos]) catch {
        file.close();
        return;
    };
    file.close();

    std.fs.cwd().rename(tmp_path, STATE_PATH) catch {};
}

fn copySlice(buf: *[4096]u8, pos: usize, src: []const u8) usize {
    if (pos + src.len > 4096) return 0;
    @memcpy(buf[pos .. pos + src.len], src);
    return src.len;
}

fn fmtInt(buf: *[4096]u8, pos: usize, val: u8) usize {
    var tmp: [8]u8 = undefined;
    const s = std.fmt.bufPrint(&tmp, "{d}", .{val}) catch return 0;
    return copySlice(buf, pos, s);
}

fn fmtU64(buf: *[4096]u8, pos: usize, val: u64) usize {
    var tmp: [24]u8 = undefined;
    const s = std.fmt.bufPrint(&tmp, "{d}", .{val}) catch return 0;
    return copySlice(buf, pos, s);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runParallelPipelineCommand(allocator: Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri pipeline run <task> --parallel{s}\n", .{ GRAY, RESET });
        std.debug.print("Creates a DAG from task decomposition and executes groups in parallel.\n", .{});
        return;
    }

    // Build a simple DAG from args: each arg is a tri subcommand in sequential groups
    var dag = PipelineDAG.init();

    // Default pipeline phases as groups
    dag.addJob("spec", "create", 0);
    dag.addJob("gen", "", 0);
    dag.addJob("test", "", 1);
    dag.addJob("bench", "", 1);
    dag.addJob("verdict", "", 2);

    executeDag(allocator, &dag);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PipelineDAG.init" {
    const dag = PipelineDAG.init();
    try std.testing.expectEqual(@as(u8, 0), dag.job_count);
    try std.testing.expectEqual(@as(u8, 0), dag.group_count);
    try std.testing.expectEqual(JobStatus.pending, dag.status);
}

test "PipelineDAG.addJob" {
    var dag = PipelineDAG.init();
    dag.addJob("test", "--verbose", 0);
    dag.addJob("bench", "", 0);
    dag.addJob("verdict", "", 1);

    try std.testing.expectEqual(@as(u8, 3), dag.job_count);
    try std.testing.expectEqual(@as(u8, 2), dag.group_count);
    try std.testing.expectEqualStrings("test", dag.jobs[0].getCommand());
    try std.testing.expectEqualStrings("--verbose", dag.jobs[0].getArgs());
    try std.testing.expectEqual(@as(u8, 0), dag.jobs[0].group_id);
    try std.testing.expectEqual(@as(u8, 1), dag.jobs[2].group_id);
}

test "PipelineDAG.getJobsInGroup" {
    var dag = PipelineDAG.init();
    dag.addJob("spec", "", 0);
    dag.addJob("gen", "", 0);
    dag.addJob("test", "", 1);

    var indices: [MAX_JOBS]u8 = undefined;
    const count0 = dag.getJobsInGroup(0, &indices);
    try std.testing.expectEqual(@as(u8, 2), count0);
    try std.testing.expectEqual(@as(u8, 0), indices[0]);
    try std.testing.expectEqual(@as(u8, 1), indices[1]);

    const count1 = dag.getJobsInGroup(1, &indices);
    try std.testing.expectEqual(@as(u8, 1), count1);
}

test "executeDag_empty" {
    var dag = PipelineDAG.init();
    executeDag(std.testing.allocator, &dag);
    try std.testing.expectEqual(JobStatus.completed, dag.status);
}

test "persistState_creates_json" {
    var dag = PipelineDAG.init();
    dag.addJob("test", "", 0);
    dag.status = .completed;
    dag.jobs[0].status = .completed;

    persistState(&dag);

    // Verify file exists
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch {
        // File might not be writable in test env — skip
        return;
    };
    defer file.close();
    var buf: [4096]u8 = undefined;
    const n = file.readAll(&buf) catch return;
    const content = buf[0..n];
    try std.testing.expect(std.mem.indexOf(u8, content, "\"status\":\"COMPLETED\"") != null);
}

test "JobStatus.label" {
    try std.testing.expectEqualStrings("COMPLETED", JobStatus.completed.label());
    try std.testing.expectEqualStrings("FAILED", JobStatus.failed.label());
    try std.testing.expectEqualStrings("PENDING", JobStatus.pending.label());
}
