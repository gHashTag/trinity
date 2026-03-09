// memory.zig — Persistent memory for tri-api
// Stores learnings in ~/.tri-api/MEMORY.md, loads first 200 lines into system prompt.
// Issue #67: Phase 8 Context Management
const std = @import("std");

const max_lines = 200;
const max_file_size = 256 * 1024; // 256KB

pub const Memory = struct {
    allocator: std.mem.Allocator,
    base_dir: [512]u8 = undefined,
    base_dir_len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Memory {
        var mem = Memory{ .allocator = allocator };

        // Resolve ~/.tri-api/
        if (std.posix.getenv("HOME")) |home| {
            if (std.fmt.bufPrint(&mem.base_dir, "{s}/.tri-api", .{home})) |path| {
                mem.base_dir_len = path.len;
            } else |_| {}
        }

        return mem;
    }

    /// Load first 200 lines from MEMORY.md. Caller owns memory.
    pub fn load(self: *Memory) ?[]const u8 {
        if (self.base_dir_len == 0) return null;

        var path_buf: [560]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/MEMORY.md", .{self.base_dir[0..self.base_dir_len]}) catch return null;

        const file = std.fs.openFileAbsolute(path, .{}) catch return null;
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, max_file_size) catch return null;

        // Limit to first 200 lines
        var line_count: u32 = 0;
        var end: usize = 0;
        while (end < content.len) : (end += 1) {
            if (content[end] == '\n') {
                line_count += 1;
                if (line_count >= max_lines) {
                    end += 1;
                    break;
                }
            }
        }

        if (end < content.len) {
            // Truncate to 200 lines
            const truncated = self.allocator.dupe(u8, content[0..end]) catch {
                self.allocator.free(content);
                return null;
            };
            self.allocator.free(content);
            return truncated;
        }

        return content;
    }

    /// Append a learning entry with timestamp.
    pub fn append(self: *Memory, text: []const u8) void {
        if (self.base_dir_len == 0) return;
        if (text.len == 0) return;

        // Ensure directory exists
        const dir_path = self.base_dir[0..self.base_dir_len];
        std.fs.makeDirAbsolute(dir_path) catch {};

        var path_buf: [560]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/MEMORY.md", .{dir_path}) catch return;

        // Open for appending (create if needed)
        const file = std.fs.createFileAbsolute(path, .{ .truncate = false }) catch return;
        defer file.close();

        // Seek to end
        file.seekFromEnd(0) catch {};

        // Write entry with separator
        file.writeAll("\n---\n") catch {};
        file.writeAll(text) catch {};
        file.writeAll("\n") catch {};
    }
};

// ─── Tests ───────────────────────────────────────────────────────────────────

test "Memory init" {
    const allocator = std.testing.allocator;
    const mem = Memory.init(allocator);
    // Should resolve base_dir if HOME is set
    if (std.posix.getenv("HOME")) |_| {
        try std.testing.expect(mem.base_dir_len > 0);
    }
}
