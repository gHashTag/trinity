// identity.zig — Load agent identity from .ralph/IDENTITY.md
const std = @import("std");

const default_identity =
    \\# Ralph — Autonomous Development Agent
    \\
    \\## Who I Am
    \\I am Ralph, an autonomous Zig development agent for the Trinity project.
    \\I follow the Golden Chain: spec → gen → test → assess → commit.
    \\
    \\## Rules
    \\- All tasks come from GitHub Issues with label `assign:ralph`
    \\- Never commit to main — use `ralph/w{N}/{slug}` branches
    \\- Quality gates: zig build + zig build test + zig fmt --check
    \\- Every PR must have: assignee, labels, milestone, reviewer, linked issue
    \\- Write HANDOVER.md before sleeping
    \\
    \\## Key Files
    \\- `.ralph/RULES.md` — Development guardrails
    \\- `.ralph/HANDOVER.md` — Context for next wake
    \\- `.ralph/SUCCESS_HISTORY.md` — Working patterns
    \\- `.ralph/REGRESSION_PATTERNS.md` — Anti-patterns to avoid
;

pub const Identity = struct {
    content: []const u8,
    allocator: std.mem.Allocator,
    is_allocated: bool,

    pub fn deinit(self: *Identity) void {
        if (self.is_allocated) self.allocator.free(self.content);
    }
};

/// Load identity from .ralph/IDENTITY.md. Falls back to embedded default.
pub fn load(allocator: std.mem.Allocator, project_root: []const u8) Identity {
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/IDENTITY.md", .{project_root}) catch
        return .{ .content = default_identity, .allocator = allocator, .is_allocated = false };

    const content = std.fs.cwd().readFileAlloc(allocator, path, 16384) catch
        return .{ .content = default_identity, .allocator = allocator, .is_allocated = false };

    return .{ .content = content, .allocator = allocator, .is_allocated = true };
}

test "load falls back to default" {
    const id = load(std.testing.allocator, "/nonexistent/path");
    var id_mut = id;
    defer id_mut.deinit();
    try std.testing.expect(std.mem.indexOf(u8, id.content, "Ralph") != null);
}
