//! Hard gate: canonical maintainer / author strings must not drift.
//! Paths listed in tools/config/author_attribution_guard.manifest.
//! Run: `zig build test` (this module is a dedicated test root).

const std = @import("std");

const MANIFEST_REL = "tools/config/author_attribution_guard.manifest";
const REQUIRED_NAME: []const u8 = "Dmitrii Vasilev";
const REQUIRED_HANDLE: []const u8 = "gHashTag";

const FORBIDDEN: []const []const u8 = &.{
    "Trinity Research Group",
    "Trinity Research Team",
};

fn trimLine(line: []const u8) []const u8 {
    return std.mem.trim(u8, line, " \t\r\n");
}

fn loadManifestPaths(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    const cwd = std.fs.cwd();
    const raw = try cwd.readFileAlloc(allocator, MANIFEST_REL, 1024 * 1024);
    defer allocator.free(raw);

    var paths: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (paths.items) |p| allocator.free(p);
        paths.deinit(allocator);
    }

    var iter = std.mem.splitScalar(u8, raw, '\n');
    while (iter.next()) |line| {
        const t = trimLine(line);
        if (t.len == 0) continue;
        if (t[0] == '#') continue;
        try paths.append(allocator, try allocator.dupe(u8, t));
    }
    return paths;
}

test "author attribution: manifest files contain canonical maintainer" {
    const allocator = std.testing.allocator;
    var paths = try loadManifestPaths(allocator);
    defer {
        for (paths.items) |p| allocator.free(p);
        paths.deinit(allocator);
    }

    try std.testing.expect(paths.items.len > 0);

    const cwd = std.fs.cwd();
    for (paths.items) |rel| {
        const content = cwd.readFileAlloc(allocator, rel, 50 * 1024 * 1024) catch |err| {
            std.debug.print("author_attribution_guard: missing or unreadable '{s}': {}\n", .{ rel, err });
            return err;
        };
        defer allocator.free(content);

        try std.testing.expect(std.mem.indexOf(u8, content, REQUIRED_NAME) != null);
        try std.testing.expect(std.mem.indexOf(u8, content, REQUIRED_HANDLE) != null);
    }
}

test "author attribution: manifest files must not contain deprecated author labels" {
    const allocator = std.testing.allocator;
    var paths = try loadManifestPaths(allocator);
    defer {
        for (paths.items) |p| allocator.free(p);
        paths.deinit(allocator);
    }

    const cwd = std.fs.cwd();
    for (paths.items) |rel| {
        const content = cwd.readFileAlloc(allocator, rel, 50 * 1024 * 1024) catch continue;
        defer allocator.free(content);
        for (FORBIDDEN) |bad| {
            if (std.mem.indexOf(u8, content, bad)) |_| {
                std.debug.print("author_attribution_guard: forbidden substring in '{s}': {s}\n", .{ rel, bad });
                return error.ForbiddenAuthorAttribution;
            }
        }
    }
}
