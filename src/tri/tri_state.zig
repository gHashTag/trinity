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

/// Pipeline checkpoint (persisted in .trinity/pipeline_state.json)
pub const PipelineCheckpoint = struct {
    last_link: u8 = 0,
    task: []const u8 = "",
    status: []const u8 = "idle",
    timestamp: i64 = 0,
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
    };
}

/// Save pipeline checkpoint to .trinity/pipeline_state.json
pub fn savePipelineCheckpoint(allocator: std.mem.Allocator, checkpoint: PipelineCheckpoint) !void {
    // Manual JSON building to avoid stringify issues with slices
    var buf: [1024]u8 = undefined;
    const json_str = std.fmt.bufPrint(&buf,
        \\{{
        \\  "last_link": {d},
        \\  "task": "{s}",
        \\  "status": "{s}",
        \\  "timestamp": {d}
        \\}}
    , .{ checkpoint.last_link, checkpoint.task, checkpoint.status, checkpoint.timestamp }) catch return error.NameTooLong;
    _ = allocator;
    try writeStateFile("pipeline_state.json", json_str);
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
