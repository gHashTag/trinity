//! tri/file_watcher — File system watcher
//! TTT Dogfood v0.2 Stage 261

const std = @import("std");

pub const FileWatcher = struct {
    path: []const u8,

    pub fn init(path: []const u8) FileWatcher {
        return .{ .path = path };
    }

    pub fn watch(watcher: *FileWatcher) !bool {
        _ = watcher;
        return true;
    }
};

test "file watcher" {
    const watcher = FileWatcher.init("/tmp");
    try std.testing.expect(watcher.path.len > 0);
}
