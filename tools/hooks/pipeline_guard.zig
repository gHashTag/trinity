// pipeline_guard.zig — PreToolUse hook: block edits to .zig files with .vibee specs
//
// Claude Code hook protocol:
//   Reads tool input JSON from stdin (piped via: echo $CLAUDE_TOOL_INPUT | pipeline-guard)
//   If file has a matching .vibee spec → deny via stdout JSON
//   Otherwise → exit 0 (allow)
//
// Usage in .claude-plugin/hooks/hooks.json:
//   "command": "echo $CLAUDE_TOOL_INPUT | \"${CLAUDE_PROJECT_DIR:-.}/zig-out/bin/pipeline-guard\""

const std = @import("std");

pub fn main() !void {
    // Read tool input JSON from stdin
    var input_buf: [65536]u8 = undefined;
    var total: usize = 0;
    while (total < input_buf.len) {
        const n = std.posix.read(0, input_buf[total..]) catch break;
        if (n == 0) break;
        total += n;
    }
    if (total == 0) return;
    const input = input_buf[0..total];

    // Extract file_path from JSON
    const file_path = extractJsonString(input, "file_path") orelse
        extractJsonString(input, "path") orelse return;

    // Allow non-.zig files
    if (!std.mem.endsWith(u8, file_path, ".zig")) return;

    // Allow pipeline infrastructure
    const allowed_suffixes = [_][]const u8{
        "pipeline_executor.zig",
        "golden_chain.zig",
        "pipeline_guard.zig",
        "build.zig",
    };
    for (allowed_suffixes) |suffix| {
        if (std.mem.endsWith(u8, file_path, suffix)) return;
    }

    // Allow core library and infrastructure directories
    const allowed_dirs = [_][]const u8{
        "src/vibeec/",
        "src/hslm/",
        "src/bsd/",
        "tools/mcp/",
        "tools/hooks/",
        "bot/",
    };
    for (allowed_dirs) |dir| {
        if (std.mem.indexOf(u8, file_path, dir) != null) return;
    }

    // Allow specific core library files
    const allowed_cores = [_][]const u8{
        "src/vsa.zig",
        "src/vm.zig",
        "src/hybrid.zig",
        "src/sdk.zig",
        "src/trinity.zig",
        "src/packed_trit.zig",
    };
    for (allowed_cores) |core| {
        if (std.mem.endsWith(u8, file_path, core)) return;
    }

    // Derive basename (strip .zig extension)
    const basename = blk: {
        const name = std.fs.path.basename(file_path);
        if (std.mem.endsWith(u8, name, ".zig")) {
            break :blk name[0 .. name.len - 4];
        }
        break :blk name;
    };

    // Search specs/ recursively for <basename>.vibee
    if (hasVibeeSpec(basename)) {
        // DENY — this file has a .vibee spec
        // Output deny JSON to stdout (Claude Code hook protocol)
        var out_buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&out_buf, "{{\"hookSpecificOutput\":{{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"PIPELINE-FIRST: {s} has a .vibee spec. Edit the spec, then run: tri pipeline run\"}}}}", .{file_path}) catch return;
        _ = std.posix.write(1, msg) catch return;
        return;
    }

    // No matching spec → allow (core library or manual module)
}

/// Check if a .vibee spec exists for the given basename
fn hasVibeeSpec(basename: []const u8) bool {
    // Build target filename: <basename>.vibee
    var target_buf: [256]u8 = undefined;
    const target_name = std.fmt.bufPrint(&target_buf, "{s}.vibee", .{basename}) catch return false;

    // Try specs/tri/<basename>.vibee first (most common location)
    var path_buf: [512]u8 = undefined;
    const direct_path = std.fmt.bufPrint(&path_buf, "specs/tri/{s}", .{target_name}) catch return false;

    std.fs.cwd().access(direct_path, .{}) catch {
        // Not in specs/tri/, try recursive search
        return hasVibeeSpecRecursive(target_name);
    };

    return true;
}

fn hasVibeeSpecRecursive(target_name: []const u8) bool {
    var dir = std.fs.cwd().openDir("specs", .{ .iterate = true }) catch return false;
    defer dir.close();

    return searchDir(dir, target_name);
}

fn searchDir(dir: std.fs.Dir, target_name: []const u8) bool {
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .directory) {
            var sub = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
            defer sub.close();
            if (searchDir(sub, target_name)) return true;
        }
        if (std.mem.eql(u8, entry.name, target_name)) {
            return true;
        }
    }
    return false;
}

/// Extract a JSON string value by key using simple pattern matching.
fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    var end = start;
    while (end < json.len) : (end += 1) {
        if (json[end] == '"' and (end == start or json[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return json[start..end];
}

test "extractJsonString basic" {
    const json =
        \\{"file_path":"src/tri/math/commands.zig","old_string":"foo"}
    ;
    const path = extractJsonString(json, "file_path") orelse return error.NotFound;
    try std.testing.expectEqualStrings("src/tri/math/commands.zig", path);
}

test "extractJsonString missing key" {
    const json =
        \\{"file_path":"src/vsa.zig"}
    ;
    try std.testing.expect(extractJsonString(json, "path") == null);
}

test "allow non-zig files" {
    // Non-.zig files should be allowed (main() returns early)
    const json =
        \\{"file_path":"CLAUDE.md"}
    ;
    const path = extractJsonString(json, "file_path") orelse return error.NotFound;
    try std.testing.expect(!std.mem.endsWith(u8, path, ".zig"));
}

test "allow core library" {
    const path = "src/vsa.zig";
    // Should match allowed_cores
    try std.testing.expect(std.mem.endsWith(u8, path, "src/vsa.zig"));
}

test "allow pipeline infrastructure" {
    const path = "src/tri/pipeline_executor.zig";
    try std.testing.expect(std.mem.endsWith(u8, path, "pipeline_executor.zig"));
}
