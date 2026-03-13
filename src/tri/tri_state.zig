// ═══════════════════════════════════════════════════════════════════════════════
// TRI STATE — Shared utilities for persistent state and process management
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const TRINITY_DIR = ".trinity";

/// Ensure .trinity/ directory exists
pub fn ensureTrinityDir() !void {
    std.fs.cwd().makeDir(TRINITY_DIR) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
}

/// Run a subprocess and capture stdout
pub fn runProcessAndCapture(allocator: std.mem.Allocator, argv: []const []const u8) !struct { stdout: []const u8, exit_code: u8 } {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 1024 * 1024,
    });
    const r = try result;
    defer allocator.free(r.stderr);
    const code: u8 = switch (r.term) {
        .Exited => |c| c,
        else => 1,
    };
    return .{ .stdout = r.stdout, .exit_code = code };
}

/// Run a subprocess, inherit stdio, return exit code
pub fn runProcessInherit(allocator: std.mem.Allocator, argv: []const []const u8) !u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = try child.spawn();
    const result = try child.wait();
    return switch (result) {
        .Exited => |c| c,
        else => 1,
    };
}

/// Read file contents
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

/// Write content to file (creates dirs if needed)
pub fn writeFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}

/// Read .trinity/ state file
pub fn readStateFile(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ TRINITY_DIR, name }) catch return error.NameTooLong;
    return readFile(allocator, path);
}

/// Write .trinity/ state file
pub fn writeStateFile(name: []const u8, content: []const u8) !void {
    try ensureTrinityDir();
    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ TRINITY_DIR, name }) catch return error.NameTooLong;
    try writeFile(path, content);
}

/// Count files with given extension in directory (recursive)
pub fn countFiles(allocator: std.mem.Allocator, dir_path: []const u8, extension: []const u8) !usize {
    var count: usize = 0;
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            if (std.mem.endsWith(u8, entry.basename, extension)) {
                count += 1;
            }
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON STATE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Safeguards configuration (persisted in .trinity/safeguards.json)
pub const SafeguardsConfig = struct {
    auto_commit_dryrun: bool = true,
    ml_validation: bool = true,
    deploy_confirm: bool = true,
    selfhost_ratelimit: bool = true,
    sacred_validation: bool = true,
};

/// Per-link result snapshot for checkpoint recovery (v5.1)
pub const LinkResultSnapshot = struct {
    status: enum(u8) { pass = 0, fail = 1, skip = 2 } = .skip,
    duration_ms: u64 = 0,
    output_hash: u32 = 0,
};

/// Pipeline checkpoint (persisted in .trinity/pipeline_state.json)
/// v5.1: Extended with per-link results array for resume optimization.
pub const PipelineCheckpoint = struct {
    last_link: u8 = 0,
    task: []const u8 = "",
    status: []const u8 = "idle",
    timestamp: i64 = 0,
    /// Per-link results: 26 slots (one per chain link). null = not yet executed.
    link_results: [26]?LinkResultSnapshot = [_]?LinkResultSnapshot{null} ** 26,

    /// Check if a link already passed in this checkpoint.
    pub fn linkPassed(self: *const PipelineCheckpoint, link_idx: u8) bool {
        if (link_idx >= 26) return false;
        if (self.link_results[link_idx]) |snap| {
            return snap.status == .pass;
        }
        return false;
    }

    /// Record a link result in the checkpoint.
    pub fn recordLink(self: *PipelineCheckpoint, link_idx: u8, passed: bool, duration_ms: u64) void {
        if (link_idx >= 26) return;
        self.link_results[link_idx] = .{
            .status = if (passed) .pass else .fail,
            .duration_ms = duration_ms,
            .output_hash = 0,
        };
    }

    /// Count how many links already passed.
    pub fn passedCount(self: *const PipelineCheckpoint) u8 {
        var count: u8 = 0;
        for (self.link_results) |maybe_snap| {
            if (maybe_snap) |snap| {
                if (snap.status == .pass) count += 1;
            }
        }
        return count;
    }
};

/// Load safeguards config from .trinity/safeguards.json
pub fn loadSafeguards(allocator: std.mem.Allocator) SafeguardsConfig {
    const content = readStateFile(allocator, "safeguards.json") catch return SafeguardsConfig{};
    defer allocator.free(content);
    const parsed = std.json.parseFromSlice(SafeguardsConfig, allocator, content, .{
        .allocate = .alloc_if_needed,
    }) catch return SafeguardsConfig{};
    defer parsed.deinit();
    return parsed.value;
}

/// Save safeguards config to .trinity/safeguards.json
pub fn saveSafeguards(allocator: std.mem.Allocator, config: SafeguardsConfig) !void {
    _ = allocator;
    var buf: [512]u8 = undefined;
    const json_str = std.fmt.bufPrint(&buf,
        \\{{
        \\  "auto_commit_dryrun": {s},
        \\  "ml_validation": {s},
        \\  "deploy_confirm": {s},
        \\  "selfhost_ratelimit": {s},
        \\  "sacred_validation": {s}
        \\}}
    , .{
        if (config.auto_commit_dryrun) "true" else "false",
        if (config.ml_validation) "true" else "false",
        if (config.deploy_confirm) "true" else "false",
        if (config.selfhost_ratelimit) "true" else "false",
        if (config.sacred_validation) "true" else "false",
    }) catch return error.NameTooLong;
    try writeStateFile("safeguards.json", json_str);
}

/// Load pipeline checkpoint from .trinity/pipeline_state.json
pub fn loadPipelineCheckpoint(allocator: std.mem.Allocator) ?PipelineCheckpoint {
    const content = readStateFile(allocator, "pipeline_state.json") catch return null;
    defer allocator.free(content);
    const parsed = std.json.parseFromSlice(PipelineCheckpoint, allocator, content, .{
        .allocate = .alloc_if_needed,
    }) catch return null;
    defer parsed.deinit();
    return PipelineCheckpoint{
        .last_link = parsed.value.last_link,
        .task = allocator.dupe(u8, parsed.value.task) catch return null,
        .status = allocator.dupe(u8, parsed.value.status) catch return null,
        .timestamp = parsed.value.timestamp,
        .link_results = parsed.value.link_results,
    };
}

/// Save pipeline checkpoint to .trinity/pipeline_state.json
/// v5.1: Includes per-link results for resume optimization.
pub fn savePipelineCheckpoint(allocator: std.mem.Allocator, checkpoint: PipelineCheckpoint) !void {
    // Build JSON with per-link results
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    w.writeAll("{\n") catch return error.NameTooLong;
    std.fmt.format(w, "  \"last_link\": {d},\n", .{checkpoint.last_link}) catch return error.NameTooLong;
    std.fmt.format(w, "  \"task\": \"{s}\",\n", .{checkpoint.task}) catch return error.NameTooLong;
    std.fmt.format(w, "  \"status\": \"{s}\",\n", .{checkpoint.status}) catch return error.NameTooLong;
    std.fmt.format(w, "  \"timestamp\": {d},\n", .{checkpoint.timestamp}) catch return error.NameTooLong;

    // Write per-link results array
    w.writeAll("  \"link_results\": [") catch return error.NameTooLong;
    for (checkpoint.link_results, 0..) |maybe_snap, i| {
        if (maybe_snap) |snap| {
            const status_str: []const u8 = switch (snap.status) {
                .pass => "pass",
                .fail => "fail",
                .skip => "skip",
            };
            std.fmt.format(w, "{{\"status\":\"{s}\",\"duration_ms\":{d}}}", .{ status_str, snap.duration_ms }) catch return error.NameTooLong;
        } else {
            w.writeAll("null") catch return error.NameTooLong;
        }
        if (i < 25) w.writeByte(',') catch return error.NameTooLong;
    }
    w.writeAll("]\n}\n") catch return error.NameTooLong;

    _ = allocator;
    try writeStateFile("pipeline_state.json", fbs.getWritten());
}

/// Count lines in all files with given extension
pub fn countLines(allocator: std.mem.Allocator, dir_path: []const u8, extension: []const u8) !usize {
    var total: usize = 0;
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, extension)) {
            const file = dir.openFile(entry.path, .{}) catch continue;
            defer file.close();
            const content = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch continue;
            defer allocator.free(content);
            var lines: usize = 0;
            for (content) |c| {
                if (c == '\n') lines += 1;
            }
            total += lines;
        }
    }
    return total;
}

// =============================================================================
// TESTS
// =============================================================================

test "PipelineCheckpoint per-link tracking" {
    var cp = PipelineCheckpoint{};
    try std.testing.expectEqual(@as(u8, 0), cp.passedCount());
    try std.testing.expect(!cp.linkPassed(0));

    cp.recordLink(0, true, 100);
    try std.testing.expect(cp.linkPassed(0));
    try std.testing.expectEqual(@as(u8, 1), cp.passedCount());

    cp.recordLink(1, false, 50);
    try std.testing.expect(!cp.linkPassed(1));
    try std.testing.expectEqual(@as(u8, 1), cp.passedCount());

    cp.recordLink(2, true, 200);
    try std.testing.expectEqual(@as(u8, 2), cp.passedCount());
}

test "PipelineCheckpoint out of bounds" {
    var cp = PipelineCheckpoint{};
    cp.recordLink(30, true, 100); // should not crash
    try std.testing.expect(!cp.linkPassed(30)); // out of bounds returns false
}

test "LinkResultSnapshot default" {
    const snap = LinkResultSnapshot{};
    try std.testing.expectEqual(.skip, snap.status);
    try std.testing.expectEqual(@as(u64, 0), snap.duration_ms);
}
