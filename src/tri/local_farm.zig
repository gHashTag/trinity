// LOCAL FARM MANAGEMENT — Wave 9 S3 MultiObj
// Tracks local Docker workers, checkpoints, PPL, crash history
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

const STATE_FILE = ".trinity/local_farm.json";
const MAX_WORKERS = 48;

pub const WorkerStatus = enum {
    stopped,
    starting,
    training,
    crashed,
    finished,
    unknown,
};

pub const Worker = struct {
    id: usize,
    container_name: []const u8,
    status: WorkerStatus,
    step: u64,
    ppl: f32,
    loss: f32,
    seed: u32,
    created_at: i64,
    updated_at: i64,
    crash_count: u8,
    last_error: ?[]const u8,
};

pub const LocalFarm = struct {
    workers: std.ArrayListUnmanaged(Worker),
    created_at: i64,
    updated_at: i64,
    total_steps: u64,
    avg_ppl: f32,
    best_ppl: f32,
    best_worker_id: ?usize,

    const Self = @This();

    pub fn init(_: Allocator) !Self {
        return Self{
            .workers = std.ArrayListUnmanaged(Worker){},
            .created_at = 0,
            .updated_at = 0,
            .total_steps = 0,
            .avg_ppl = 0.0,
            .best_ppl = std.math.inf(f32),
            .best_worker_id = null,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.workers.items) |*w| {
            if (w.last_error) |err| {
                allocator.free(err);
            }
        }
        self.workers.deinit(allocator);
    }

    pub fn load(allocator: Allocator) !Self {
        const file = std.fs.cwd().openFile(STATE_FILE, .{}) catch |err| switch (err) {
            error.FileNotFound => return init(allocator),
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
        defer allocator.free(content);

        const parsed = try std.json.parseFromSlice(Self, allocator, content, .{});
        defer parsed.deinit();

        // Convert managed to unmanaged
        var result = try init(allocator);
        for (parsed.value.workers.items) |w| {
            try result.workers.append(allocator, w);
        }
        result.created_at = parsed.value.created_at;
        result.updated_at = parsed.value.updated_at;
        result.total_steps = parsed.value.total_steps;
        result.avg_ppl = parsed.value.avg_ppl;
        result.best_ppl = parsed.value.best_ppl;
        result.best_worker_id = parsed.value.best_worker_id;

        return result;
    }

    pub fn save(self: *const Self, allocator: Allocator) !void {
        // Use inline slice for JSON serialization
        const json_farm = struct {
            workers: []const Worker,
            created_at: i64,
            updated_at: i64,
            total_steps: u64,
            avg_ppl: f32,
            best_ppl: f32,
            best_worker_id: ?usize,
        }{
            .workers = self.workers.items,
            .created_at = self.created_at,
            .updated_at = self.updated_at,
            .total_steps = self.total_steps,
            .avg_ppl = self.avg_ppl,
            .best_ppl = self.best_ppl,
            .best_worker_id = self.best_worker_id,
        };

        const state_dir = std.fs.path.dirname(STATE_FILE) orelse ".";
        std.fs.cwd().makeDir(state_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const file = try std.fs.cwd().createFile(STATE_FILE, .{});
        defer file.close();

        const json_str = try std.json.Stringify.valueAlloc(allocator, json_farm, .{ .whitespace = .indent_2 });
        defer allocator.free(json_str);
        try file.writeAll(json_str);
    }

    pub fn addWorker(self: *Self, allocator: Allocator, id: usize, seed: u32) !void {
        const container_name = try std.fmt.allocPrint(allocator, "wave9-w{d}", .{id});
        const now = std.time.timestamp();

        try self.workers.append(allocator, .{
            .id = id,
            .container_name = container_name,
            .status = .stopped,
            .step = 0,
            .ppl = std.math.inf(f32),
            .loss = std.math.inf(f32),
            .seed = seed,
            .created_at = now,
            .updated_at = now,
            .crash_count = 0,
            .last_error = null,
        });

        self.updated_at = now;
    }

    pub fn getWorker(self: *Self, id: usize) ?*Worker {
        for (self.workers.items) |*w| {
            if (w.id == id) return w;
        }
        return null;
    }

    pub fn updateWorkerStatus(self: *Self, id: usize, status: WorkerStatus) !void {
        if (self.getWorker(id)) |w| {
            w.status = status;
            w.updated_at = std.time.timestamp();
        }
    }

    pub fn updateWorkerMetrics(self: *Self, id: usize, step: u64, ppl: f32, loss: f32) !void {
        if (self.getWorker(id)) |w| {
            w.step = step;
            w.ppl = ppl;
            w.loss = loss;
            w.updated_at = std.time.timestamp();

            if (ppl < self.best_ppl) {
                self.best_ppl = ppl;
                self.best_worker_id = id;
            }

            self.recalculateAggregates();
        }
    }

    fn recalculateAggregates(self: *Self) void {
        var active_count: usize = 0;
        var sum_ppl: f32 = 0.0;
        self.total_steps = 0;

        for (self.workers.items) |w| {
            if (w.status == .training or w.status == .finished) {
                if (w.ppl < std.math.inf(f32)) {
                    sum_ppl += w.ppl;
                    active_count += 1;
                }
                self.total_steps += w.step;
            }
        }

        self.avg_ppl = if (active_count > 0) sum_ppl / @as(f32, @floatFromInt(active_count)) else 0.0;
    }

    pub fn countByStatus(self: *const Self, status: WorkerStatus) usize {
        var count: usize = 0;
        for (self.workers.items) |w| {
            if (w.status == status) count += 1;
        }
        return count;
    }

    pub fn displayStatus(self: *const Self) void {
        print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
        print("{s}WAVE 9 LOCAL FARM — S3 MultiObj{s}\n", .{ BOLD, RESET });
        print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

        print("{s}Workers: {d}/{d}  {s}│{s}  Avg PPL: {d:5.2}  {s}│{s}  Best PPL: {d:5.2} (w{d})  {s}│{s}  Total Steps: {d}\n\n", .{ CYAN, self.workers.items.len, MAX_WORKERS, RESET, GREEN, self.avg_ppl, RESET, GREEN, self.best_ppl, self.best_worker_id orelse 0, RESET, CYAN, self.total_steps });

        print("{s}Status Breakdown:{s}\n", .{ DIM, RESET });
        print("  {s}🟢 Training:{s}   {d:2}  {s}🔄 Starting:{s} {d:2}  {s}✅ Finished:{s} {d:2}  {s}💀 Crashed:{s}  {d:2}  {s}⏸️ Stopped:{s}  {d:2}\n\n", .{ GREEN, RESET, self.countByStatus(.training), YELLOW, RESET, self.countByStatus(.starting), GREEN, RESET, self.countByStatus(.finished), RED, RESET, self.countByStatus(.crashed), DIM, RESET, self.countByStatus(.stopped) });

        print("{s}Workers:{s}\n", .{ BOLD, RESET });
        for (self.workers.items) |w| {
            const status_emoji = switch (w.status) {
                .stopped => "⏸️",
                .starting => "🔄",
                .training => "🟢",
                .crashed => "💀",
                .finished => "✅",
                .unknown => "❓",
            };
            const status_color = switch (w.status) {
                .stopped => DIM,
                .starting => YELLOW,
                .training => GREEN,
                .crashed => RED,
                .finished => GREEN,
                .unknown => DIM,
            };
            print("  {s}{s} w{d:2} {s}step={d:6} PPL={d:5.2} loss={d:6.3} seed={d:4}{s}\n", .{ status_color, status_emoji, w.id, RESET, w.step, w.ppl, w.loss, w.seed, RESET });
            if (w.crash_count > 0) {
                print("    {s}[crashes: {d}]{s}\n", .{ RED, w.crash_count, RESET });
            }
        }
        print("\n", .{});
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// DOCKER COMMAND WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

pub const DockerResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u32,
};

pub fn runDockerCompose(allocator: Allocator, args: []const []const u8) !DockerResult {
    var argv = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, args.len + 1);
    defer argv.deinit(allocator);
    try argv.append(allocator, "docker-compose");
    try argv.appendSlice(allocator, args);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
    });

    return DockerResult{
        .stdout = result.stdout,
        .stderr = result.stderr,
        .exit_code = if (result.term == .Exited) @as(u32, @intCast(result.term.Exited)) else 1,
    };
}

pub fn composeUp(allocator: Allocator, compose_file: []const u8, workers: ?[]const u8) !DockerResult {
    var args = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, 5);
    defer args.deinit(allocator);

    try args.append(allocator, "-f");
    try args.append(allocator, compose_file);
    try args.append(allocator, "up");
    try args.append(allocator, "-d");

    if (workers) |w| {
        try args.append(allocator, w);
    }

    return runDockerCompose(allocator, try args.toOwnedSlice(allocator));
}

pub fn composeStop(allocator: Allocator, compose_file: []const u8, workers: ?[]const u8) !DockerResult {
    var args = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, 4);
    defer args.deinit(allocator);

    try args.append(allocator, "-f");
    try args.append(allocator, compose_file);
    try args.append(allocator, "stop");

    if (workers) |w| {
        try args.append(allocator, w);
    }

    return runDockerCompose(allocator, try args.toOwnedSlice(allocator));
}

pub fn composeLogs(allocator: Allocator, compose_file: []const u8, worker: []const u8, follow: bool) !DockerResult {
    var args = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, 5);
    defer args.deinit(allocator);

    try args.append(allocator, "-f");
    try args.append(allocator, compose_file);
    try args.append(allocator, "logs");
    if (follow) try args.append(allocator, "-f");
    try args.append(allocator, worker);

    return runDockerCompose(allocator, try args.toOwnedSlice(allocator));
}

pub fn composePs(allocator: Allocator, compose_file: []const u8) !DockerResult {
    const args = &[_][]const u8{ "-f", compose_file, "ps" };
    return runDockerCompose(allocator, args[0..args.len]);
}

pub fn containerExec(allocator: Allocator, container: []const u8, cmd: []const u8) !DockerResult {
    const args = &[_][]const u8{ "exec", container, "sh", "-c", cmd };
    return runDockerCompose(allocator, args[0..args.len]);
}
