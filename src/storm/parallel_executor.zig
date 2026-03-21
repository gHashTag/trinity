//! P10: Parallel Executor — ThreadPool wrapper for wave execution
//! Replaces "simulated parallel" with real std.Thread.Pool

const std = @import("std");

pub const ParallelExecutor = struct {
    allocator: std.mem.Allocator,
    pool: *std.Thread.Pool,
    max_threads: usize,

    pub const Task = struct {
        id: usize,
        name: []const u8,
        func: *const fn (allocator: std.mem.Allocator, context: []const u8) anyerror!void,
        context: []const u8,
        result: ?TaskResult = null,
    };

    pub const TaskResult = struct {
        success: bool,
        duration_ms: u64,
        error_msg: ?[]const u8 = null,
    };

    pub const WaveConfig = struct {
        wave_id: u4,
        agent_count: u8,
        tasks: []Task,
    };

    /// Initialize parallel executor with thread pool
    pub fn init(allocator: std.mem.Allocator, max_threads: usize) !ParallelExecutor {
        var pool = try allocator.create(std.Thread.Pool);
        pool.* = std.Thread.Pool{
            .allocator = allocator,
        };

        try pool.init(.{
            .n_jobs = @intCast(max_threads),
        });

        return .{
            .allocator = allocator,
            .pool = pool,
            .max_threads = max_threads,
        };
    }

    /// Clean up thread pool
    pub fn deinit(self: *ParallelExecutor) void {
        self.pool.deinit();
        self.allocator.destroy(self.pool);
    }

    /// Execute tasks in parallel using thread pool
    pub fn executeWave(self: *ParallelExecutor, config: WaveConfig) ![]TaskResult {
        std.debug.print("\n🌊 Wave {d}: Executing {d} tasks with {d} threads\n", .{
            config.wave_id,
            config.tasks.len,
            @min(self.max_threads, config.tasks.len),
        });

        // Allocate results array
        const results = try self.allocator.alloc(TaskResult, config.tasks.len);

        // Use WaitGroup for synchronization
        var wg = std.Thread.WaitGroup{};
        defer wg.wait();

        // Spawn tasks in thread pool
        for (config.tasks, 0..) |task, i| {
            const task_ptr = &config.tasks[i];
            const result_ptr = &results[i];

            wg.spawn(
                struct {
                    fn run(t: *Task, r: *TaskResult, g: *std.Thread.WaitGroup) void {
                        defer g.done();
                        const start = std.time.nanoTimestamp();

                        r.* = TaskResult{
                            .success = false,
                            .duration_ms = 0,
                        };

                        // Execute task function
                        if (t.func(std.heap.page_allocator, t.context)) {
                            const end = std.time.nanoTimestamp();
                            const duration_ms = @as(u64, @intFromFloat(@divTrunc(
                                @as(f128, @floatFromInt(end - start)),
                                1_000_000
                            )));

                            r.* = .{
                                .success = true,
                                .duration_ms = duration_ms,
                            };

                            std.debug.print("  ✅ [{d}] {s} completed in {}ms\n", .{
                                t.id, t.name, duration_ms,
                            });
                        } else |err| {
                            const end = std.time.nanoTimestamp();
                            const duration_ms = @as(u64, @intFromFloat(@divTrunc(
                                @as(f128, @floatFromInt(end - start)),
                                1_000_000
                            )));

                            r.* = .{
                                .success = false,
                                .duration_ms = duration_ms,
                                .error_msg = std.fmt.allocPrint(
                                    std.heap.page_allocator,
                                    "{}",
                                    .{err}
                                ) catch null,
                            };

                            std.debug.print("  ❌ [{d}] {s} failed: {}\n", .{
                                t.id, t.name, err,
                            });
                        }
                    }
                }.run,
                .{ task_ptr, result_ptr, &wg },
            );
        }

        return results;
    }

    /// Execute tasks sequentially (fallback for single-threaded mode)
    pub fn executeSequential(self: *ParallelExecutor, tasks: []Task) ![]TaskResult {
        _ = self;

        const results = try self.allocator.alloc(TaskResult, tasks.len);

        for (tasks, 0..) |task, i| {
            const start = std.time.nanoTimestamp();

            results[i] = TaskResult{
                .success = false,
                .duration_ms = 0,
            };

            if (task.func(self.allocator, task.context)) {
                const end = std.time.nanoTimestamp();
                const duration_ms = @as(u64, @intFromFloat(@divTrunc(
                    @as(f128, @floatFromInt(end - start)),
                    1_000_000
                )));

                results[i] = .{
                    .success = true,
                    .duration_ms = duration_ms,
                };

                std.debug.print("  ✅ [{d}] {s} completed in {}ms\n", .{
                    task.id, task.name, duration_ms,
                });
            } else |err| {
                const end = std.time.nanoTimestamp();
                const duration_ms = @as(u64, @intFromFloat(@divTrunc(
                    @as(f128, @floatFromInt(end - start)),
                    1_000_000
                )));

                results[i] = .{
                    .success = false,
                    .duration_ms = duration_ms,
                    .error_msg = std.fmt.allocPrint(
                        self.allocator,
                        "{}",
                        .{err}
                    ) catch null,
                };

                std.debug.print("  ❌ [{d}] {s} failed: {}\n", .{
                    task.id, task.name, err,
                });
            }
        }

        return results;
    }
};
