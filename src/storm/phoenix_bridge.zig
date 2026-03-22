//! Phoenix Bridge — P4 Cell System Integration
//! Self-healing regeneration with .tri ↔ .zig sync verification

const std = @import("std");

pub const RegenDecision = enum {
    skip, // No regeneration needed
    regen, // Regenerate .zig from .tri (VIBEE codegen)
    destroy, // Delete .zig (corrupted), regenerate from .tri
};

pub const BiopsyResult = struct {
    decision: RegenDecision,
    reason: []const u8,
};

pub const PhoenixBridge = struct {
    allocator: std.mem.Allocator,
    cell_path: []const u8,
    checkpoint_dir: []const u8 = ".trinity/phoenix/checkpoints/",

    pub fn init(allocator: std.mem.Allocator, cell_path: []const u8) !PhoenixBridge {
        return .{
            .allocator = allocator,
            .cell_path = try allocator.dupe(u8, cell_path),
            .checkpoint_dir = try allocator.dupe(u8, ".trinity/phoenix/checkpoints/"),
        };
    }

    pub fn deinit(self: *PhoenixBridge) void {
        self.allocator.free(self.cell_path);
        self.allocator.free(self.checkpoint_dir);
    }

    /// Run BEFORE each wave — system health check + regen
    pub fn preWaveRegen(pb: *PhoenixBridge, wave_id: u4) !void {
        std.debug.print("\n🔥 Phoenix preWaveRegen for Wave {d}\n", .{wave_id});

        // Scan .trinity/ for .tri files that need regeneration
        var regen_count: u5 = 0;
        var skip_count: u5 = 0;

        // Check key specs directory
        var specs_dir = std.fs.cwd().openDir("specs", .{ .iterate = true }) catch |err| {
            std.log.warn("Failed to open specs/: {}", .{err});
            return;
        };
        defer specs_dir.close();

        var iter = specs_dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tri")) {
                // Build cell path (remove .tri extension)
                const base_name = entry.name[0 .. entry.name.len - 4];
                const cell_path = try std.fmt.allocPrint(pb.allocator, "specs/{s}", .{base_name});
                defer pb.allocator.free(cell_path);

                // Run biopsy
                const result = try pb.biopsy(cell_path);

                switch (result.decision) {
                    .skip => {
                        skip_count += 1;
                        std.debug.print("  ✓ {s}.tri: {s}\n", .{ base_name, result.reason });
                    },
                    .regen => {
                        regen_count += 1;
                        std.debug.print("  ⚠️  {s}.tri: {s} → VIBEE regen\n", .{ base_name, result.reason });
                        // TODO: Run VIBEE codegen: zig build vibee -- gen specs/{s}.tri
                    },
                    .destroy => {
                        regen_count += 1;
                        std.debug.print("  🔥 {s}.tri: {s} → destroy + regen\n", .{ base_name, result.reason });
                        // TODO: Delete .zig, run VIBEE codegen
                    },
                }
            }
        }

        // Check src/storm/ directory for self-consistency
        var storm_dir = std.fs.cwd().openDir("src/storm", .{ .iterate = true }) catch |err| {
            std.log.warn("Failed to open src/storm/: {}", .{err});
            return;
        };
        defer storm_dir.close();

        var storm_iter = storm_dir.iterate();
        while (try storm_iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
                // Skip test files
                if (std.mem.indexOf(u8, entry.name, "test_") != null) continue;

                // For each .zig in storm/, check if .tri exists
                const base_name = entry.name[0 .. entry.name.len - 4];
                const tri_path = try std.fmt.allocPrint(pb.allocator, "specs/storm/{s}.tri", .{base_name});
                defer pb.allocator.free(tri_path);

                // Check if .tri spec exists for this .zig file
                _ = std.fs.cwd().statFile(tri_path) catch |err| {
                    if (err == error.FileNotFound) {
                        std.debug.print("  ⚠️  {s} exists but no .tri spec (may be manually written)\n", .{entry.name});
                    }
                    return;
                };
            }
        }

        std.debug.print("\n🔥 Phoenix Wave {d} Summary: {d} skipped, {d} need regen\n", .{ wave_id, skip_count, regen_count });
    }

    /// Biopsy: analyze if cell needs regeneration
    /// Compares .tri vs .zig file timestamps
    pub fn biopsy(pb: *PhoenixBridge, cell_path: []const u8) !BiopsyResult {
        // Build file paths
        const tri_path = try std.fmt.allocPrint(pb.allocator, "{s}.tri", .{cell_path});
        const zig_path = try std.fmt.allocPrint(pb.allocator, "{s}.zig", .{cell_path});

        // Get .tri stat
        const tri_stat = std.fs.cwd().statFile(tri_path) catch |err| {
            return switch (err) {
                error.FileNotFound => BiopsyResult{
                    .decision = .skip,
                    .reason = "TRI file not found",
                },
                else => BiopsyResult{
                    .decision = .skip,
                    .reason = try std.fmt.allocPrint(pb.allocator, "TRI stat error: {}", .{err}),
                },
            };
        };

        // Get .zig stat
        const zig_stat = std.fs.cwd().statFile(zig_path) catch |err| {
            return switch (err) {
                error.FileNotFound => BiopsyResult{
                    .decision = .skip,
                    .reason = "ZIG file not found",
                },
                else => BiopsyResult{
                    .decision = .skip,
                    .reason = try std.fmt.allocPrint(pb.allocator, "ZIG stat error: {}", .{err}),
                },
            };
        };

        const tri_mtime = tri_stat.mtime;
        const zig_mtime = zig_stat.mtime;

        // Calculate difference
        const mtime_diff = if (tri_mtime > zig_mtime)
            tri_mtime - zig_mtime
        else
            zig_mtime - tri_mtime;

        // Decision logic
        // Allow 1 second tolerance for build time differences
        if (mtime_diff < 1_000_000_000) {
            return BiopsyResult{
                .decision = .skip,
                .reason = "Files in sync",
            };
        }

        // Check if .zig is significantly older than .tri (needs regen)
        if (zig_mtime + 5_000_000_000 < tri_mtime) {
            return BiopsyResult{
                .decision = .regen,
                .reason = "ZIG older, needs VIBEE regen",
            };
        }

        // Check if .tri is significantly older than .zig (stale .tri)
        if (tri_mtime + 60_000_000_000 < zig_mtime) {
            return BiopsyResult{
                .decision = .skip,
                .reason = "TRI stale (ZIG newer)",
            };
        }

        return BiopsyResult{
            .decision = .skip,
            .reason = "Files in sync (tolerance)",
        };
    }

    /// Save cell checkpoint
    pub fn saveCheckpoint(pb: *PhoenixBridge, cell_id: []const u8, state: []const u8) !void {
        const filename = try std.fmt.allocPrint(
            pb.allocator,
            "{s}/cell_{s}.json",
            .{ pb.checkpoint_dir, cell_id },
        );

        try std.fs.cwd().makePath(pb.checkpoint_dir);

        try std.fs.cwd().writeFile(.{
            .sub_path = filename,
            .data = state,
        });
    }
};

// ═════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════

test "RegenDecision variants" {
    try std.testing.expectEqual(RegenDecision.skip, RegenDecision.skip);
    try std.testing.expectEqual(RegenDecision.regen, RegenDecision.regen);
    try std.testing.expectEqual(RegenDecision.destroy, RegenDecision.destroy);
}

test "BiopsyResult defaults" {
    const result = BiopsyResult{
        .decision = .skip,
        .reason = "",
    };
    try std.testing.expectEqual(RegenDecision.skip, result.decision);
}

test "PhoenixBridge init" {
    const allocator = std.testing.allocator;
    var pb = try PhoenixBridge.init(allocator, "/tmp/cell");
    defer pb.deinit();

    try std.testing.expectEqualStrings("/tmp/cell", pb.cell_path);
    try std.testing.expectEqualStrings(".trinity/phoenix/checkpoints/", pb.checkpoint_dir);
}

test "biopsy handles non-existent files" {
    const allocator = std.testing.allocator;
    var pb = try PhoenixBridge.init(allocator, "/tmp/nonexistent");
    defer pb.deinit();

    const result = try pb.biopsy("/tmp/nonexistent");
    try std.testing.expectEqual(RegenDecision.skip, result.decision);
}
