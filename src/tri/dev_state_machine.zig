// @origin(spec:trinity_dev_state_machine.tri) @regen(done)
//
// Trinity S³AI: Brain-Module Architecture & φ-Mathematics — State Machine Core
// S³ Level: Rigid Process Framework for all development operations
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;

/// Development session state for Trinity S³AI workflow enforcement
/// All commits must contain valid issue ID (#123 or ISSUE-123)
pub const DevSessionPath = ".trinity/dev_session.json";

/// Development workflow states for rigid process enforcement
pub const DevState = enum {
    /// No active task, clean working tree
    idle,

    /// Task selected, work in progress
    active,

    /// Files modified, not yet tested
    dirty,

    /// Tests passed, ready for commit
    tested,

    /// Committed locally, not yet pushed
    committed,

    /// Pushed to remote, PR merged/shipped
    shipped,

    /// Error state, requires manual intervention
    blocked,
};

/// Convert DevState to uppercase string representation
pub fn stateToString(state: DevState) []const u8 {
    return switch (state) {
        .idle => "IDLE",
        .active => "ACTIVE",
        .dirty => "DIRTY",
        .tested => "TESTED",
        .committed => "COMMITTED",
        .shipped => "SHIPPED",
        .blocked => "BLOCKED",
    };
}

/// Development session with state tracking and persistence
pub const DevSession = struct {
    state: DevState = .idle,
    issue_number: u32 = 0,
    branch: [64]u8 = [_]u8{0} ** 64,
    issue_title: [128]u8 = [_]u8{0} ** 128,
    issue_title_len: u8 = 0,
    files_modified: [32][64]u8 = undefined,
    files_count: usize = 0,
    tests_passed: bool = false,
    commit_hash: [64]u8 = [_]u8{0} ** 64,
    started_at: i64 = 0,
    last_updated: i64 = 0,

    /// Check if transition to target state is valid
    pub fn canTransition(self: *const DevSession, to: DevState) bool {
        return switch (self.state) {
            .idle => to == .active or to == .idle,
            .active => to == .dirty or to == .idle,
            .dirty => to == .tested or to == .active,
            .tested => to == .committed or to == .dirty,
            .committed => to == .shipped or to == .tested,
            .shipped => to == .idle,
            .blocked => to == .idle,
        };
    }

    /// Get issue title as null-terminated string
    pub fn issueTitleStr(self: *const DevSession) []const u8 {
        return if (self.issue_title_len > 0)
            self.issue_title[0..self.issue_title_len]
        else
            "";
    }

    /// Transition to new state with timestamp update
    pub fn transition(self: *DevSession, to: DevState) !void {
        if (!self.canTransition(to)) {
            return error.InvalidTransition;
        }
        self.state = to;
        self.last_updated = std.time.timestamp();
    }

    /// Save session state to JSON file
    pub fn save(self: *const DevSession) !void {
        var cwd = std.fs.cwd();
        const file = try cwd.createFile(DevSessionPath, .{ .read = true });
        defer file.close();

        const writer = file.writer();

        // Write JSON manually - simple approach
        try writer.print(
            \\{{{{
            \\  "state": "{s}",
            \\  "issue_number": {d},
            \\  "branch": "{s}",
            \\  "issue_title_len": {d},
            \\  "issue_title": "{s}",
            \\  "files_count": {d},
            \\  "tests_passed": {},
            \\  "commit_hash": "{s}",
            \\  "started_at": {d},
            \\  "last_updated": {d}
            \\}}}}
        , stateToString(self.state), self.issue_number, sanitizeString(self.branch[0..]), self.issue_title_len, sanitizeString(self.issueTitleStr()), self.files_count, self.tests_passed, sanitizeString(&self.commit_hash), self.started_at, self.last_updated);
    }

    /// Load session state from JSON file
    pub fn load(allocator: Allocator) !DevSession {
        var cwd = std.fs.cwd();
        const file = cwd.openFile(DevSessionPath, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return DevSession{}; // Default idle state
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 4096);
        defer allocator.free(content);

        var session = DevSession{};

        // Parse state
        if (std.mem.indexOf(u8, content, "\"state\": \"")) |idx| {
            const start = idx + "\"state\": \"".len;
            if (std.mem.indexOf(u8, content[start..], "\"")) |end_idx| {
                const state_str = content[start .. start + end_idx];
                if (std.mem.eql(u8, state_str, "IDLE")) session.state = .idle;
                if (std.mem.eql(u8, state_str, "ACTIVE")) session.state = .active;
                if (std.mem.eql(u8, state_str, "DIRTY")) session.state = .dirty;
                if (std.mem.eql(u8, state_str, "TESTED")) session.state = .tested;
                if (std.mem.eql(u8, state_str, "COMMITTED")) session.state = .committed;
                if (std.mem.eql(u8, state_str, "SHIPPED")) session.state = .shipped;
                if (std.mem.eql(u8, state_str, "BLOCKED")) session.state = .blocked;
            }
        }

        // Parse issue_number
        if (std.mem.indexOf(u8, content, "\"issue_number\": ")) |idx| {
            const start = idx + "\"issue_number\": ".len;
            if (std.mem.indexOf(u8, content[start..], ",")) |end_idx| {
                const num_str = content[start .. start + end_idx];
                session.issue_number = try std.fmt.parseInt(u32, num_str, 10);
            }
        }

        // Parse issue_title_len
        if (std.mem.indexOf(u8, content, "\"issue_title_len\": ")) |idx| {
            const start = idx + "\"issue_title_len\": ".len;
            if (std.mem.indexOf(u8, content[start..], ",")) |end_idx| {
                const num_str = content[start .. start + end_idx];
                session.issue_title_len = try std.fmt.parseInt(u8, num_str, 10);
            }
        }

        // Parse branch
        if (std.mem.indexOf(u8, content, "\"branch\": \"")) |idx| {
            const start = idx + "\"branch\": \"".len;
            if (std.mem.indexOf(u8, content[start..], "\"")) |end_idx| {
                const branch_str = content[start .. start + end_idx];
                @memcpy(&session.branch, branch_str);
            }
        }

        // Parse issue_title
        if (std.mem.indexOf(u8, content, "\"issue_title\": \"")) |idx| {
            const start = idx + "\"issue_title\": \"".len;
            if (std.mem.indexOf(u8, content[start..], "\"")) |end_idx| {
                const title_str = content[start .. start + end_idx];
                @memcpy(&session.issue_title, title_str);
                session.issue_title_len = @min(@as(u8, @intCast(title_str.len)), 127);
            }
        }

        // Parse files_count
        if (std.mem.indexOf(u8, content, "\"files_count\": ")) |idx| {
            const start = idx + "\"files_count\": ".len;
            if (std.mem.indexOf(u8, content[start..], ",")) |end_idx| {
                const num_str = content[start .. start + end_idx];
                session.files_count = try std.fmt.parseInt(usize, num_str, 10);
            }
        }

        // Parse tests_passed
        if (std.mem.indexOf(u8, content, "\"tests_passed\": ")) |idx| {
            const start = idx + "\"tests_passed\": ".len;
            if (std.mem.indexOf(u8, content[start..], ",")) |end_idx| {
                const bool_str = content[start .. start + end_idx];
                session.tests_passed = std.mem.eql(u8, bool_str, "true");
            }
        }

        // Parse commit_hash
        if (std.mem.indexOf(u8, content, "\"commit_hash\": \"")) |idx| {
            const start = idx + "\"commit_hash\": \"".len;
            if (std.mem.indexOf(u8, content[start..], "\"")) |end_idx| {
                const hash_str = content[start .. start + end_idx];
                @memcpy(&session.commit_hash, hash_str);
            }
        }

        // Parse started_at
        if (std.mem.indexOf(u8, content, "\"started_at\": ")) |idx| {
            const start = idx + "\"started_at\": ".len;
            if (std.mem.indexOf(u8, content[start..], ",")) |end_idx| {
                const num_str = content[start .. start + end_idx];
                session.started_at = try std.fmt.parseInt(i64, num_str, 10);
            }
        }

        // Parse last_updated
        if (std.mem.indexOf(u8, content, "\"last_updated\": ")) |idx| {
            const start = idx + "\"last_updated\": ".len;
            if (std.mem.indexOf(u8, content[start..], "\n")) |end_idx| {
                const num_str = content[start .. start + end_idx];
                session.last_updated = try std.fmt.parseInt(i64, num_str, 10);
            }
        }

        return session;
    }

    // Helper: sanitize string for JSON (escape nulls)
    fn sanitizeString(s: []const u8) []const u8 {
        // Find first null byte
        for (s, 0..) |c, i| {
            if (c == 0) return s[0..i];
        }
        return s;
    }
};
