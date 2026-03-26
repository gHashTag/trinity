// Test: JSONL serialization for TRI-27 episodes
const std = @import("std");

const episodes = @import("episodes.zig");
const Tri27Event = episodes.Tri27Event;
const Tri27Operation = episodes.Tri27Operation;
const Tri27Status = episodes.Tri27Status;
const Source = episodes.Source;
const Outcome = episodes.Outcome;

test "episodes: recordTri27Episode JSONL serialization" {
    const allocator = std.testing.allocator;

    // Create test Tri27Event
    const tri27_event = Tri27Event{
        .timestamp = 1234567890,
        .operation = .assemble,
        .input_file = "test.tasm",
        .output_file = "test.tbin",
        .status = .success,
        .cycles = 1000,
        .instructions = 25,
        .error_msg = "",
        .has_error = false,
    };

    // Record episode
    const summary = try episodes.recordTri27Episode(allocator, tri27_event);

    // Verify JSONL contains required fields
    try std.testing.expectEqual(Source.tri27, summary.source);
    try std.testing.expectEqualStrings("tri27_op", summary.action_type);
    try std.testing.expectEqualStrings("test.tasm", summary.input_file);
    try std.testing.expectEqualStrings("assemble", summary.tri27_operation);
    try std.testing.expect(summary.success);
    try std.testing.expectEqual(Outcome.success, summary.outcome);
    try std.testing.expectEqual(@as(u64, 1), summary.duration_ms); // 1000 cycles / 1000 = 1ms
}
