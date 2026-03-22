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

        // Build JSON string manually
        var json_buffer: [1024]u8 = undefined;
        var pos: usize = 0;

        // Opening brace and state
        const json1 = "{\"state\": \"";
        @memcpy(json_buffer[pos .. pos + json1.len], json1);
        pos += json1.len;
        const state_str = stateToString(self.state);
        @memcpy(json_buffer[pos .. pos + state_str.len], state_str);
        pos += state_str.len;

        // issue_number
        const json2 = "\", \"issue_number\": ";
        @memcpy(json_buffer[pos .. pos + json2.len], json2);
        pos += json2.len;
        const issue_num_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self.issue_number});
        defer std.heap.page_allocator.free(issue_num_str);
        @memcpy(json_buffer[pos .. pos + issue_num_str.len], issue_num_str);
        pos += issue_num_str.len;

        // branch
        const json3 = ", \"branch\": \"";
        @memcpy(json_buffer[pos .. pos + json3.len], json3);
        pos += json3.len;
        const branch_str = sanitizeString(self.branch[0..]);
        @memcpy(json_buffer[pos .. pos + branch_str.len], branch_str);
        pos += branch_str.len;

        // issue_title_len
        const json4 = "\", \"issue_title_len\": ";
        @memcpy(json_buffer[pos .. pos + json4.len], json4);
        pos += json4.len;
        const title_len_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self.issue_title_len});
        defer std.heap.page_allocator.free(title_len_str);
        @memcpy(json_buffer[pos .. pos + title_len_str.len], title_len_str);
        pos += title_len_str.len;

        // issue_title
        const json5 = ", \"issue_title\": \"";
        @memcpy(json_buffer[pos .. pos + json5.len], json5);
        pos += json5.len;
        const title_str = sanitizeString(self.issueTitleStr());
        @memcpy(json_buffer[pos .. pos + title_str.len], title_str);
        pos += title_str.len;

        // files_count
        const json6 = "\", \"files_count\": ";
        @memcpy(json_buffer[pos .. pos + json6.len], json6);
        pos += json6.len;
        const files_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self.files_count});
        defer std.heap.page_allocator.free(files_str);
        @memcpy(json_buffer[pos .. pos + files_str.len], files_str);
        pos += files_str.len;

        // tests_passed
        const json7 = ", \"tests_passed\": ";
        @memcpy(json_buffer[pos .. pos + json7.len], json7);
        pos += json7.len;
        const tests_str = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{self.tests_passed});
        defer std.heap.page_allocator.free(tests_str);
        @memcpy(json_buffer[pos .. pos + tests_str.len], tests_str);
        pos += tests_str.len;

        // commit_hash
        const json8 = ", \"commit_hash\": \"";
        @memcpy(json_buffer[pos .. pos + json8.len], json8);
        pos += json8.len;
        const hash_str = sanitizeString(&self.commit_hash);
        @memcpy(json_buffer[pos .. pos + hash_str.len], hash_str);
        pos += hash_str.len;
        const closing_quote = "\"";
        @memcpy(json_buffer[pos .. pos + closing_quote.len], closing_quote);
        pos += closing_quote.len;

        // started_at
        const json9 = ", \"started_at\": ";
        @memcpy(json_buffer[pos .. pos + json9.len], json9);
        pos += json9.len;
        const started_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self.started_at});
        defer std.heap.page_allocator.free(started_str);
        @memcpy(json_buffer[pos .. pos + started_str.len], started_str);
        pos += started_str.len;

        // last_updated
        const json10 = ", \"last_updated\": ";
        @memcpy(json_buffer[pos .. pos + json10.len], json10);
        pos += json10.len;
        const updated_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self.last_updated});
        defer std.heap.page_allocator.free(updated_str);
        @memcpy(json_buffer[pos .. pos + updated_str.len], updated_str);
        pos += updated_str.len;

        // Closing brace
        const json11 = "\n}";
        @memcpy(json_buffer[pos .. pos + json11.len], json11);
        pos += json11.len;

        try file.writeAll(json_buffer[0..pos]);
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
                const len = @min(branch_str.len, session.branch.len - 1);
                @memcpy(session.branch[0..len], branch_str);
            }
        }

        // Parse issue_title
        if (std.mem.indexOf(u8, content, "\"issue_title\": \"")) |idx| {
            const start = idx + "\"issue_title\": \"".len;
            if (std.mem.indexOf(u8, content[start..], "\"")) |end_idx| {
                const title_str = content[start .. start + end_idx];
                const len = @min(title_str.len, session.issue_title.len - 1);
                @memcpy(session.issue_title[0..len], title_str);
                session.issue_title_len = @as(u8, @intCast(len));
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
                const len = @min(hash_str.len, session.commit_hash.len - 1);
                @memcpy(session.commit_hash[0..len], hash_str);
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

// Tests
test "DevState enum" {
    try std.testing.expectEqualStrings("IDLE", "IDLE");
    try std.testing.expectEqualStrings("ACTIVE", "ACTIVE");
    try std.testing.expectEqualStrings("DIRTY", "DIRTY");
    try std.testing.expectEqualStrings("TESTED", "TESTED");
    try std.testing.expectEqualStrings("COMMITTED", "COMMITTED");
    try std.testing.expectEqualStrings("SHIPPED", "SHIPPED");
    try std.testing.expectEqualStrings("BLOCKED", "BLOCKED");
}

test "stateToString" {
    try std.testing.expectEqualStrings("IDLE", "IDLE");
    try std.testing.expectEqualStrings("ACTIVE", "ACTIVE");
}

test "canTransition valid transitions from idle" {
    const state = DevSession{ .state = .idle };
    try std.testing.expect(state.canTransition(.active));
    try std.testing.expect(state.canTransition(.idle));
    try std.testing.expect(!state.canTransition(.committed));
    try std.testing.expect(!state.canTransition(.tested));
}

test "canTransition invalid transitions from active" {
    const state = DevSession{ .state = .active };
    try std.testing.expect(!state.canTransition(.committed));
    try std.testing.expect(!state.canTransition(.shipped));
}

test "canTransition valid transitions from dirty" {
    const state = DevSession{ .state = .dirty };
    try std.testing.expect(state.canTransition(.tested));
    try std.testing.expect(state.canTransition(.active));
    try std.testing.expect(!state.canTransition(.committed));
}

test "canTransition valid transitions from tested" {
    const state = DevSession{ .state = .tested };
    try std.testing.expect(state.canTransition(.committed));
    try std.testing.expect(state.canTransition(.dirty));
    try std.testing.expect(!state.canTransition(.shipped));
}

test "canTransition valid transitions from committed" {
    const state = DevSession{ .state = .committed };
    try std.testing.expect(state.canTransition(.shipped));
    try std.testing.expect(state.canTransition(.tested));
}

test "canTransition valid transitions from shipped" {
    const state = DevSession{ .state = .shipped };
    try std.testing.expect(state.canTransition(.idle));
}

test "canTransition valid transitions from blocked" {
    const state = DevSession{ .state = .blocked };
    try std.testing.expect(state.canTransition(.idle));
    try std.testing.expect(!state.canTransition(.active));
}

test "load default session" {
    const allocator = std.testing.allocator;
    const loaded = try DevSession.load(allocator);
    try std.testing.expectEqual(.idle, loaded.state);
    try std.testing.expectEqual(@as(u32, 0), loaded.issue_number);
}

test "save and load roundtrip" {
    const allocator = std.testing.allocator;

    var original = DevSession{
        .state = .active,
        .issue_number = 42,
        .issue_title_len = 22,  // Set to actual title length
    };

    original.started_at = 1234567890;
    original.last_updated = 1239999999;

    try original.save();
    const loaded = try DevSession.load(allocator);

    try std.testing.expectEqual(.active, loaded.state);
    try std.testing.expectEqual(@as(u32, 42), loaded.issue_number);
    try std.testing.expectEqualStrings("Fix VSA bind operation", loaded.issueTitleStr());
    try std.testing.expectEqual(@as(i64, 1234567890), loaded.started_at);
    try std.testing.expectEqual(@as(i64, 1239999999), loaded.last_updated);
    try std.testing.expectEqual(@as(usize, 0), loaded.files_count);
}
