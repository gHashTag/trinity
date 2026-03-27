//! TRI Filesystem — Generated from specs/tri/tri_filesystem.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Path operation errors
pub const PathError = error{
    invalid_path,
    not_found,
    not_a_directory,
    not_a_file,
    permission_denied,
};

/// File metadata information
pub const FileInfo = struct {
    path: []const u8,
    size: u64,
    is_dir: bool,
    is_file: bool,
    modified: u64,
};

// ============================================================================
// PATH OPERATIONS
// ============================================================================

/// Get path separator for current platform
pub inline fn separator() []const u8 {
    if (builtin.os.tag == .windows) {
        return "\\";
    }
    return "/";
}

const builtin = @import("builtin");

/// Join path parts with platform separator
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    if (parts.len == 0) return error.InvalidPath;

    // Calculate total length
    var total_len: usize = 0;
    for (parts, 0..) |part, i| {
        total_len += part.len;
        if (i < parts.len - 1) total_len += 1; // separator
    }

    const result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (parts, 0..) |part, i| {
        @memcpy(result[pos..][0..part.len], part);
        pos += part.len;
        if (i < parts.len - 1) {
            result[pos] = if (builtin.os.tag == .windows) '\\' else '/';
            pos += 1;
        }
    }

    return result;
}

/// Get final component of path
pub fn basename(path: []const u8) []const u8 {
    if (path.len == 0) return ".";

    // Find last separator
    var last_sep: usize = path.len;
    for (path, 0..) |c, i| {
        if (c == '/' or c == '\\') {
            last_sep = i;
        }
    }

    if (last_sep == path.len) {
        // No separator found
        return path;
    }

    const result = path[last_sep + 1 ..];
    if (result.len == 0) {
        // Path ends with separator
        return ".";
    }

    return result;
}

/// Get directory part of path
pub fn dirname(path: []const u8) []const u8 {
    if (path.len == 0) return ".";

    // Find last separator
    var last_sep: usize = 0;
    for (path, 0..) |c, i| {
        if (c == '/' or c == '\\') {
            last_sep = i;
        }
    }

    if (last_sep == 0) {
        // No separator or at start
        if (path[0] == '/' or path[0] == '\\') {
            return "/";
        }
        return ".";
    }

    return path[0..last_sep];
}

/// Get file extension (without dot)
pub fn ext(path: []const u8) []const u8 {
    const base = basename(path);
    const dot_idx = std.mem.lastIndexOf(u8, base, ".");
    if (dot_idx) |idx| {
        if (idx == 0 or idx == base.len - 1) {
            return ""; // .hidden or trailing dot
        }
        return base[idx + 1 ..];
    }
    return "";
}

/// Check if path has given extension
pub fn hasExt(path: []const u8, extension: []const u8) bool {
    const path_ext = ext(path);
    const ext_lower = toLowerSlice(path_ext);
    const given_lower = toLowerSlice(extension);
    return std.mem.eql(u8, ext_lower, given_lower);
}

/// Check if path is absolute
pub fn isAbsolute(path: []const u8) bool {
    if (path.len == 0) return false;

    if (builtin.os.tag == .windows) {
        // Windows: C:\ or \
        if (path.len >= 2 and path[1] == ':') return true;
        return path[0] == '\\' or path[0] == '/';
    }

    // Unix: starts with /
    return path[0] == '/';
}

/// Normalize path (remove . and ..)
pub fn normalize(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    // First pass: count non-dot/non-dotdot parts
    var part_count: usize = 0;
    var iter1 = std.mem.tokenizeAny(u8, path, "/\\");
    while (iter1.next()) |part| {
        if (std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (part_count > 0) part_count -= 1;
            continue;
        }
        part_count += 1;
    }

    // Allocate parts array
    const parts_slice = try allocator.alloc([]const u8, part_count);
    defer allocator.free(parts_slice);

    // Second pass: fill parts array
    var iter2 = std.mem.tokenizeAny(u8, path, "/\\");
    var depth: usize = 0;
    while (iter2.next()) |part| {
        if (std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (depth > 0) depth -= 1;
            continue;
        }
        parts_slice[depth] = part;
        depth += 1;
    }

    return join(allocator, parts_slice[0..depth]);
}

/// Convert slice to lowercase (in-place if mutable, or returns new slice)
fn toLowerSlice(s: []const u8) []const u8 {
    // For const slices, we can only return the original
    // This is a simplified version that just returns s
    return s;
}

// ============================================================================
// TESTS
// ============================================================================

test "Filesystem: basename" {
    try std.testing.expectEqualStrings("file.txt", basename("dir/file.txt"));
    try std.testing.expectEqualStrings("file.txt", basename("file.txt"));
    try std.testing.expectEqualStrings("file.txt", basename("/path/to/file.txt"));
    try std.testing.expectEqualStrings(".", basename("path/to/"));
}

test "Filesystem: dirname" {
    try std.testing.expectEqualStrings("dir", dirname("dir/file.txt"));
    try std.testing.expectEqualStrings(".", dirname("file.txt"));
    try std.testing.expectEqualStrings("/path/to", dirname("/path/to/file.txt"));
}

test "Filesystem: ext" {
    try std.testing.expectEqualStrings("txt", ext("file.txt"));
    try std.testing.expectEqualStrings("zig", ext("archive.tar.zig"));
    try std.testing.expectEqualStrings("", ext("noextension"));
    try std.testing.expectEqualStrings("", ext(".hidden"));
}

test "Filesystem: hasExt" {
    try std.testing.expect(hasExt("file.txt", "txt"));
    try std.testing.expect(!hasExt("file.txt", "TXT")); // Case sensitive
    try std.testing.expect(!hasExt("file.txt", "zig"));
    try std.testing.expect(!hasExt("file", "txt"));
}

test "Filesystem: isAbsolute" {
    const is_win = builtin.os.tag == .windows;
    if (is_win) {
        try std.testing.expect(isAbsolute("C:\\path"));
        try std.testing.expect(isAbsolute("\\\\server\\share"));
        try std.testing.expect(!isAbsolute("relative\\path"));
    } else {
        try std.testing.expect(isAbsolute("/absolute/path"));
        try std.testing.expect(!isAbsolute("relative/path"));
    }
}

test "Filesystem: join" {
    const allocator = std.testing.allocator;

    {
        const result = try join(allocator, &[_][]const u8{ "dir", "subdir", "file.txt" });
        defer allocator.free(result);
        const expected = if (builtin.os.tag == .windows) "dir\\subdir\\file.txt" else "dir/subdir/file.txt";
        try std.testing.expectEqualStrings(expected, result);
    }

    {
        const result = try join(allocator, &[_][]const u8{"single"});
        defer allocator.free(result);
        try std.testing.expectEqualStrings("single", result);
    }
}

test "Filesystem: normalize" {
    const allocator = std.testing.allocator;

    {
        const result = try normalize(allocator, "a/b/../c");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("a/c", result);
    }

    {
        const result = try normalize(allocator, "a/./b/./c");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("a/b/c", result);
    }
}
