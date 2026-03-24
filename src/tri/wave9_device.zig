// @origin(spec:wave9_device.tri) @regen(manual-impl)

// ═════════════════════════════════════════════════════════════════════════════
// WAVE 9 DEVICE — Device-specific docker-compose generation
// ═════════════════════════════════════════════════════════════════════════════
//
// Thin adapter to wave9_generator for device-specific compose files.
// Generates docker-compose.wave9-mac-{device_id}.yml with assigned worker range.
//
// Usage: Generated via tri farm local-wave9 device-init
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const wave9_gen = @import("wave9_generator.zig");

const BASE_SEED = 1000;

const WorkerRange = struct { start: usize, count: usize };

// Local copy of generateWorker from wave9_generator
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
    try buf.appendSlice(allocator, "      dockerfile: deploy/Dockerfile.hslm-train-local.arm64-test\n");
    try buf.writer(allocator).print("    container_name: wave9-w{d}\n", .{worker_id});
    try buf.appendSlice(allocator, "    volumes:\n");
    try buf.writer(allocator).print("      - ../../data/wave9/worker-{d}:/data/checkpoints\n", .{worker_id});
    try buf.appendSlice(allocator, "      - ../../data/tinystories:/data/tinystories:ro\n");
    try buf.appendSlice(allocator, "    environment:\n");

    // S3 MultiObj vars (from wave9_generator)
    try buf.appendSlice(allocator, "      - HSLM_PROFILE=s3-multiobj\n");
    try buf.appendSlice(allocator, "      - HSLM_CTX=81\n");
    try buf.appendSlice(allocator, "      - HSLM_NTP_WEIGHT=0.50\n");
    try buf.appendSlice(allocator, "      - HSLM_JEPA_WEIGHT=0.25\n");
    try buf.appendSlice(allocator, "      - HSLM_NCA_WEIGHT=0.25\n");
    try buf.appendSlice(allocator, "      - HSLM_CRASH_TOLERANCE=0.05\n");
    try buf.appendSlice(allocator, "      - HSLM_WAVE=9\n");
    try buf.appendSlice(allocator, "      - HSLM_LR=1e-3\n");
    try buf.appendSlice(allocator, "      - HSLM_LR_SCHEDULE=cosine\n");
    try buf.appendSlice(allocator, "      - HSLM_OPTIMIZER=lamb\n");
    try buf.appendSlice(allocator, "      - HSLM_BATCH=66\n");
    try buf.appendSlice(allocator, "      - HSLM_STEPS=100000\n");
    try buf.appendSlice(allocator, "      - HSLM_WARMUP=2000\n");
    try buf.appendSlice(allocator, "      - HSLM_WD=0.01\n");
    try buf.appendSlice(allocator, "      - HSLM_GRAD_CLIP=1.0\n");
    try buf.appendSlice(allocator, "      - HSLM_FRESH=0\n");

    try buf.appendSlice(allocator, "      - HSLM_SEED=");
    try buf.appendSlice(allocator, seed_str);
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "    restart: unless-stopped\n");
    try buf.appendSlice(allocator, "    networks:\n");
    try buf.appendSlice(allocator, "      - wave9-net\n");

    return buf.toOwnedSlice(allocator);
}

/// Generate device-specific docker-compose for Mac cluster
/// device_id: Mac node ID (0, 1, 2, ...)
/// worker_range: { .start = global_worker_id, .count = num_workers }
pub fn generateDeviceCompose(allocator: Allocator, device_id: usize, worker_range: WorkerRange) ![]const u8 {
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    // Header
    try buf.appendSlice(allocator, "# Wave 9 — Mac Cluster Device ");
    try buf.writer(allocator).print("{d}\n", .{device_id});
    try buf.appendSlice(allocator, "# φ² + 1/φ² = 3 = TRINITY\n");
    try buf.appendSlice(allocator, "#\n");
    try buf.writer(allocator).print("# Device: mac-{d} | Workers: {d}-{d} ({d} workers)\n", .{
        device_id,
        worker_range.start,
        worker_range.start + worker_range.count - 1,
        worker_range.count,
    });
    try buf.appendSlice(allocator, "#\n");
    try buf.appendSlice(allocator, "# Usage:\n");
    try buf.writer(allocator).print(
        \\#   docker-compose -f docker-compose.wave9-mac-{d}.yml up -d
        \\#   docker-compose -f docker-compose.wave9-mac-{d}.yml stop
        \\#   docker-compose -f docker-compose.wave9-mac-{d}.yml logs -f w9-1
        \\
    , .{ device_id, device_id, device_id });
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "version: '3.8'\n");
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "services:\n");

    // Generate workers using local generateWorker
    for (0..worker_range.count) |i| {
        const global_worker_id = worker_range.start + i;
        const worker = try generateWorker(allocator, global_worker_id);
        defer allocator.free(worker);
        try buf.appendSlice(allocator, worker);
        if (i < worker_range.count - 1) {
            try buf.appendSlice(allocator, "\n");
        }
    }

    // Networks
    try buf.appendSlice(allocator, "\n");
    try buf.appendSlice(allocator, "networks:\n");
    try buf.writer(allocator).print("  wave9-net-mac-{d}:\n", .{device_id});
    try buf.appendSlice(allocator, "    driver: bridge\n");

    return buf.toOwnedSlice(allocator);
}

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "generateDeviceCompose" {
    const allocator = std.testing.allocator;
    const compose = try generateDeviceCompose(allocator, 0, .{ .start = 1, .count = 2 });
    defer allocator.free(compose);

    try std.testing.expect(std.mem.indexOf(u8, compose, "w9-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "w9-2") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "HSLM_SEED=1001") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "HSLM_SEED=1002") != null);
    try std.testing.expect(std.mem.indexOf(u8, compose, "mac-0") != null);
}
