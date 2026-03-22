const std = @import("std");

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
    try std.testing.expect(state.canTransition(&state, .active));
    try std.testing.expect(state.canTransition(&state, .idle));
    try std.testing.expect(!state.canTransition(&state, .committed));
    try std.testing.expect(!state.canTransition(&state, .tested));
}

test "canTransition invalid transitions from active" {
    const state = DevSession{ .state = .active };
    try std.testing.expect(!state.canTransition(&state, .committed));
    try std.testing.expect(!state.canTransition(&state, .shipped));
}

test "canTransition valid transitions from dirty" {
    const state = DevSession{ .state = .dirty };
    try std.testing.expect(state.canTransition(&state, .tested));
    try std.testing.expect(state.canTransition(&state, .active));
    try std.testing.expect(!state.canTransition(&state, .committed));
}

test "canTransition valid transitions from tested" {
    const state = DevSession{ .state = .tested };
    try std.testing.expect(state.canTransition(&state, .committed));
    try std.testing.expect(state.canTransition(&state, .dirty));
    try std.testing.expect(!state.canTransition(&state, .shipped));
}

test "canTransition valid transitions from committed" {
    const state = DevSession{ .state = .committed };
    try std.testing.expect(state.canTransition(&state, .shipped));
    try std.testing.expect(state.canTransition(&state, .tested));
}

test "canTransition valid transitions from shipped" {
    const state = DevSession{ .state = .shipped };
    try std.testing.expect(state.canTransition(&state, .idle));
}

test "canTransition valid transitions from blocked" {
    const state = DevSession{ .state = .blocked };
    try std.testing.expect(state.canTransition(&state, .idle));
    try std.testing.expect(!state.canTransition(&state, .active));
}

test "load default session" {
    const allocator = std.testing.allocator;
    const loaded = DevSession.load(allocator);
    try std.testing.expectEqual(.idle, loaded.state);
    try std.testing.expectEqual(@as(u32, 0), loaded.issue_number);
}

test "save and load roundtrip" {
    const allocator = std.testing.allocator;

    var original = DevSession{
        .state = .active,
        .issue_number = 42,
        .issue_title_len = 16,
    };

    @memcpy(original.issue_title, "Fix VSA bind operation");
    original.started_at = 1234567890;
    original.last_updated = 1239999999;

    try original.save();
    const loaded = DevSession.load(allocator);

    try std.testing.expectEqual(.active, loaded.state);
    try std.testing.expectEqual(@as(u32, 42), loaded.issue_number);
    try std.testing.expectEqualStrings("Fix VSA bind operation", loaded.issueTitleStr());
    try std.testing.expectEqual(@as(i64, 1234567890), loaded.started_at);
    try std.testing.expectEqual(@as(i64, 1239999999), loaded.last_updated);
    try std.testing.expectEqual(@as(usize, 0), loaded.files_count);
}
