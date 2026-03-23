// WAVE 9 DOCKER-COMPOSE GENERATOR
// Generates docker-compose.wave9.yml with N workers (default 48)
//
// Usage: zig build wave9-gen
// Output: deploy/docker/docker-compose.wave9.yml
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const MAX_WORKERS = 48;
const BASE_SEED = 1000;

const EnvVar = struct {
    name: []const u8,
    value: []const u8,
};

const S3MultiObjConfig = &[_]EnvVar{
    .{ .name = "HSLM_PROFILE", .value = "s3-multiobj" },
    .{ .name = "HSLM_CTX", .value = "81" },
    .{ .name = "HSLM_NTP_WEIGHT", .value = "0.50" },
    .{ .name = "HSLM_JEPA_WEIGHT", .value = "0.25" },
    .{ .name = "HSLM_NCA_WEIGHT", .value = "0.25" },
    .{ .name = "HSLM_CRASH_TOLERANCE", .value = "0.05" },
    .{ .name = "HSLM_WAVE", .value = "9" },
    .{ .name = "HSLM_LR", .value = "1e-3" },
    .{ .name = "HSLM_LR_SCHEDULE", .value = "cosine" },
    .{ .name = "HSLM_OPTIMIZER", .value = "lamb" },
    .{ .name = "HSLM_BATCH", .value = "66" },
    .{ .name = "HSLM_STEPS", .value = "100000" },
    .{ .name = "HSLM_WARMUP", .value = "2000" },
    .{ .name = "HSLM_WD", .value = "0.01" },
    .{ .name = "HSLM_GRAD_CLIP", .value = "1.0" },
    .{ .name = "HSLM_FRESH", .value = "0" },
};

fn generateWorker(allocator: Allocator, worker_id: usize) ![]const u8 {
    const seed = BASE_SEED + worker_id;
    const seed_str = try std.fmt.allocPrint(allocator, "{d}", .{seed});
    defer allocator.free(seed_str);

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    try buf.appendSlice(allocator, "  w9-");
    try buf.writer(allocator).print("{d}:\n", .{worker_id});
    try buf.appendSlice(allocator, "    build:\n");
    try buf.appendSlice(allocator, "      context: ../../\n");
    try buf.appendSlice(allocator, "      dockerfile: deploy/Dockerfile.hslm-train\n");
    try buf.appendSlice(allocator, "    container_name: wave9-w");
    try buf.writer(allocator).print("{d}\n", .{worker_id});
    try buf.appendSlice(allocator, "    volumes:\n");
    try buf.appendSlice(allocator, "      - ../../data/wave9/worker-");
    try buf.writer(allocator).print("{d}:/data/checkpoints\n", .{worker_id});
    try buf.appendSlice(allocator, "      - ../../data/tinystories:/data/tinystories:ro\n");
    try buf.appendSlice(allocator, "    environment:\n");

    for (S3MultiObjConfig) |env| {
        try buf.appendSlice(allocator, "      - ");
        try buf.appendSlice(allocator, env.name);
        try buf.appendSlice(allocator, "=");
        try buf.appendSlice(allocator, env.value);
        try buf.appendSlice(allocator, "\n");
    }

    try buf.appendSlice(allocator, "      - HSLM_SEED=");
    try buf.appendSlice(allocator, seed_str);
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "    restart: unless-stopped\n");
    try buf.appendSlice(allocator, "    networks:\n");
    try buf.appendSlice(allocator, "      - wave9-net\n");

    return buf.toOwnedSlice(allocator);
}

pub fn generateCompose(allocator: Allocator, num_workers: usize) ![]const u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    try buf.appendSlice(allocator, "# Wave 9 — S3 MultiObj Local Training\n");
    try buf.appendSlice(allocator, "# φ² + 1/φ² = 3 = TRINITY\n");
    try buf.appendSlice(allocator, "#\n");
    try buf.writer(allocator).print("# {d} workers with NTP 50% + JEPA 25% + NCA 25% objective\n", .{num_workers});
    try buf.appendSlice(allocator, "#\n");
    try buf.appendSlice(allocator, "# Usage:\n");
    try buf.appendSlice(allocator, "#   docker-compose -f docker-compose.wave9.yml up -d              # Start all\n");
    try buf.appendSlice(allocator, "#   docker-compose -f docker-compose.wave9.yml up -d w9-1         # Start specific\n");
    try buf.appendSlice(allocator, "#   docker-compose -f docker-compose.wave9.yml stop                # Stop all\n");
    try buf.appendSlice(allocator, "#   docker-compose -f docker-compose.wave9.yml logs -f w9-1       # Follow logs\n");
    try buf.appendSlice(allocator, "#   docker-compose -f docker-compose.wave9.yml down -v             # Stop + clean volumes\n");
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "version: '3.8'\n");
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "services:\n");

    for (1..num_workers + 1) |i| {
        const worker = try generateWorker(allocator, i);
        defer allocator.free(worker);
        try buf.appendSlice(allocator, worker);
        if (i < num_workers) {
            try buf.appendSlice(allocator, "\n");
        }
    }

    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "networks:\n");
    try buf.appendSlice(allocator, "  wave9-net:\n");
    try buf.appendSlice(allocator, "    driver: bridge\n");

    return buf.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var num_workers: usize = 48;
    var output_path: []const u8 = "deploy/docker/docker-compose.wave9.yml";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--workers") and i + 1 < args.len) {
            i += 1;
            num_workers = std.fmt.parseInt(usize, args[i], 10) catch 48;
        } else if (std.mem.eql(u8, args[i], "--output") and i + 1 < args.len) {
            i += 1;
            output_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            std.debug.print(
                \\Wave 9 Docker-Compose Generator
                \\Usage: {s} [--workers N] [--output PATH]
                \\
                \\Options:
                \\  --workers N      Number of workers (default: 48, max: 48)
                \\  --output PATH    Output file path (default: deploy/docker/docker-compose.wave9.yml)
                \\  -h, --help       Show this help
                \\
                \\S3 MultiObj Config:
                \\  NTP weight: 0.50, JEPA weight: 0.25, NCA weight: 0.25
                \\  Context length: 81, LR: 1e-3, Schedule: cosine
                \\  Optimizer: lamb, Batch size: 66, Steps: 100K
                \\
            , .{args[0]});
            return;
        }
    }

    if (num_workers > MAX_WORKERS) {
        std.debug.print("Error: max workers is {d}\n", .{MAX_WORKERS});
        return error.TooManyWorkers;
    }

    const compose = try generateCompose(allocator, num_workers);
    defer allocator.free(compose);

    // Ensure output directory exists
    const output_dir = std.fs.path.dirname(output_path) orelse ".";
    std.fs.cwd().makeDir(output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Write compose file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(compose);

    std.debug.print("✓ Generated docker-compose for {d} workers: {s}\n", .{ num_workers, output_path });
}

test "generateWorker" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const worker = try generateWorker(gpa.allocator(), 1);
    defer gpa.allocator().free(worker);
    try std.testing.expect(std.mem.indexOf(u8, worker, "HSLM_SEED=1001") != null);
}

test "generateCompose minimal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const compose = try generateCompose(gpa.allocator(), 2);
    defer gpa.allocator().free(compose);
    try std.testing.expect(std.mem.indexOf(u8, compose, "w9-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "w9-2") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "HSLM_SEED=1001") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "HSLM_SEED=1002") != null);
}
