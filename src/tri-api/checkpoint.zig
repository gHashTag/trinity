// checkpoint.zig — Git-based checkpoints for tri-api write safety
// Creates a git stash snapshot before each write_file, supports undo.
// Issue #65: Phase 6 permissions + checkpoints
const std = @import("std");

const stash_prefix = "tri-api checkpoint: ";

pub const CheckpointEntry = struct {
    index: u32,
    path: []const u8,
};

pub const Checkpoint = struct {
    allocator: std.mem.Allocator,

    /// Create a checkpoint before writing to file_path.
    /// Strategy: git stash push -m "tri-api checkpoint: {path}" -- {path}
    /// This creates a recoverable snapshot in git stash.
    pub fn createBeforeWrite(self: *Checkpoint, file_path: []const u8) void {
        // Only checkpoint files that exist (new files have nothing to checkpoint)
        std.fs.cwd().access(file_path, .{}) catch return;

        // Check if we're in a git repo
        _ = runGit(self.allocator, &.{ "git", "rev-parse", "--git-dir" }) catch return;

        // Stage the file's current state and stash it
        _ = runGit(self.allocator, &.{ "git", "stash", "push", "-m", stashMessage(self.allocator, file_path) catch return, "--", file_path }) catch |err| {
            std.debug.print("[tri-api] checkpoint: stash failed: {s}\n", .{@errorName(err)});
        };
    }

    /// Restore the most recent checkpoint for a file path.
    /// Uses: git checkout -- {file_path}
    pub fn restoreFile(self: *Checkpoint, file_path: []const u8) !void {
        _ = try runGit(self.allocator, &.{ "git", "checkout", "--", file_path });
    }

    /// Restore from the most recent tri-api stash entry.
    pub fn restoreLatest(self: *Checkpoint) ![]const u8 {
        // Find latest tri-api stash
        const stash_list = try runGit(self.allocator, &.{ "git", "stash", "list", "--format=%gd %s" });
        defer self.allocator.free(stash_list);

        // Find first line with our prefix
        var pos: usize = 0;
        while (pos < stash_list.len) {
            var line_end = pos;
            while (line_end < stash_list.len and stash_list[line_end] != '\n') : (line_end += 1) {}
            const line = stash_list[pos..line_end];

            if (std.mem.indexOf(u8, line, stash_prefix)) |prefix_idx| {
                // Extract stash ref (e.g. "stash@{0}")
                const space_idx = std.mem.indexOf(u8, line, " ") orelse {
                    pos = line_end + 1;
                    continue;
                };
                const stash_ref = line[0..space_idx];
                const file_path = line[prefix_idx + stash_prefix.len ..];

                // Pop this stash
                _ = runGit(self.allocator, &.{ "git", "stash", "pop", stash_ref }) catch |err| {
                    std.debug.print("[tri-api] undo: stash pop failed: {s}\n", .{@errorName(err)});
                    return err;
                };

                return self.allocator.dupe(u8, file_path) catch return error.OutOfMemory;
            }

            pos = line_end + 1;
        }

        return error.FileNotFound;
    }

    /// List recent checkpoints as formatted text. Caller owns memory.
    pub fn list(self: *Checkpoint) ?[]const u8 {
        const stash_list = runGit(self.allocator, &.{ "git", "stash", "list", "--format=%gd %s" }) catch return null;
        defer self.allocator.free(stash_list);

        var out: std.ArrayList(u8) = .empty;
        out.appendSlice(self.allocator, "Checkpoints:\n") catch return null;

        var pos: usize = 0;
        var count: u32 = 0;
        while (pos < stash_list.len and count < 20) {
            var line_end = pos;
            while (line_end < stash_list.len and stash_list[line_end] != '\n') : (line_end += 1) {}
            const line = stash_list[pos..line_end];

            if (std.mem.indexOf(u8, line, stash_prefix) != null) {
                count += 1;
                out.appendSlice(self.allocator, "  ") catch break;
                out.appendSlice(self.allocator, line) catch break;
                out.append(self.allocator, '\n') catch break;
            }

            pos = line_end + 1;
        }

        if (count == 0) {
            out.appendSlice(self.allocator, "  (no checkpoints)\n") catch {};
        }

        return out.toOwnedSlice(self.allocator) catch null;
    }
};

/// Build stash message: "tri-api checkpoint: {path}"
fn stashMessage(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ stash_prefix, file_path });
}

/// Run a git command, return stdout. Caller owns memory.
fn runGit(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 64 * 1024,
    });
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return error.ProcessFailed;
    }

    return result.stdout;
}
