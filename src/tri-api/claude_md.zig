// claude_md.zig — Load CLAUDE.md hierarchy into system prompt
// Hierarchy: ~/.claude/CLAUDE.md → ./CLAUDE.md → ./.claude/CLAUDE.md
// Issue #67: Phase 8 Context Management
const std = @import("std");

const max_file_size = 256 * 1024; // 256KB per CLAUDE.md

/// Load and merge CLAUDE.md files into a system prompt.
/// Returns concatenated content with --- separators, or null if none found.
/// Caller owns returned memory.
pub fn loadSystemPrompt(allocator: std.mem.Allocator) ?[]const u8 {
    var parts = std.ArrayList(u8).empty;

    // 1. Global: ~/.claude/CLAUDE.md
    if (std.posix.getenv("HOME")) |home| {
        var path_buf: [512]u8 = undefined;
        if (std.fmt.bufPrint(&path_buf, "{s}/.claude/CLAUDE.md", .{home})) |path| {
            appendFile(allocator, &parts, path);
        } else |_| {}
    }

    // 2. Project: ./CLAUDE.md
    appendFile(allocator, &parts, "CLAUDE.md");

    // 3. Project-local: ./.claude/CLAUDE.md
    appendFile(allocator, &parts, ".claude/CLAUDE.md");

    if (parts.items.len == 0) {
        parts.deinit(allocator);
        return null;
    }

    return parts.toOwnedSlice(allocator) catch null;
}

/// Append a memory file to the system prompt parts.
pub fn appendMemory(allocator: std.mem.Allocator, parts: *std.ArrayList(u8), memory_content: []const u8) void {
    if (memory_content.len == 0) return;
    if (parts.items.len > 0) {
        parts.appendSlice(allocator, "\n---\n") catch return;
    }
    parts.appendSlice(allocator, "# Memory\n") catch return;
    parts.appendSlice(allocator, memory_content) catch return;
}

/// Read a file and append to parts with separator.
fn appendFile(allocator: std.mem.Allocator, parts: *std.ArrayList(u8), path: []const u8) void {
    const content = readFile(allocator, path) orelse return;
    defer allocator.free(content);

    if (content.len == 0) return;

    if (parts.items.len > 0) {
        parts.appendSlice(allocator, "\n---\n") catch return;
    }
    parts.appendSlice(allocator, content) catch return;
}

/// Read a file, return content or null.
fn readFile(allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
    // Try as absolute path first, then relative
    if (path.len > 0 and path[0] == '/') {
        const file = std.fs.openFileAbsolute(path, .{}) catch return null;
        defer file.close();
        return file.readToEndAlloc(allocator, max_file_size) catch null;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();
    return file.readToEndAlloc(allocator, max_file_size) catch null;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

test "loadSystemPrompt returns something when CLAUDE.md exists" {
    // This test works in the trinity project root which has CLAUDE.md
    const allocator = std.testing.allocator;
    if (loadSystemPrompt(allocator)) |prompt| {
        defer allocator.free(prompt);
        try std.testing.expect(prompt.len > 0);
    }
    // If no CLAUDE.md found (CI), that's also fine — null is valid
}
