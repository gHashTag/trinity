//! Single workspace root for `.trinity/` state: walk up from cwd until `build.zig`
//! is found, then `chdir` there. Prevents `src/.trinity`, `fpga/.trinity`, etc.
//!
//! Override: absolute path in `TRINITY_REPO_ROOT` (directory that contains `.trinity/`).

const std = @import("std");

/// Best-effort: never fail startup if discovery fails (stay in cwd).
pub fn cdToRepoRootSilent() void {
    cdToRepoRoot() catch {};
}

pub fn cdToRepoRoot() !void {
    const page = std.heap.page_allocator;
    if (std.process.getEnvVarOwned(page, "TRINITY_REPO_ROOT")) |root| {
        defer page.free(root);
        try std.process.changeCurDir(root);
        return;
    } else |_| {}

    var scratch: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_full = try std.fs.cwd().realpath(".", &scratch);
    var cur_len = cwd_full.len;
    while (cur_len > 0) {
        const cur = scratch[0..cur_len];
        const sep_len = std.fs.path.sep_str.len;
        const need = cur.len + sep_len + "build.zig".len;
        if (need > scratch.len) return error.NameTooLong;
        @memcpy(scratch[cur.len..][0..sep_len], std.fs.path.sep_str);
        @memcpy(scratch[cur.len + sep_len ..][0.."build.zig".len], "build.zig");
        const probe = scratch[0..need];
        std.fs.accessAbsolute(probe, .{}) catch {
            const parent = std.fs.path.dirname(cur) orelse return;
            if (parent.len == cur.len) return;
            cur_len = parent.len;
            continue;
        };
        try std.process.changeCurDir(cur);
        return;
    }
}
