// TRI-27 → Queen Episode Bridge
// Maps Tri27Event to Queen Episode format

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Context = @import("observe.zig").Context;
pub const Result = @import("act.zig").Result;
pub const Outcome = @import("act.zig").Outcome;
pub const Timing = @import("act.zig").Timing;
pub const SensorsSnapshot = @import("act.zig").SensorsSnapshot;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const Episode = @import("episodes.zig").Episode;
pub const Source = @import("episodes.zig").Source;
pub const Tri27Operation = @import("episodes.zig").Tri27Operation;
pub const Tri27Status = @import("episodes.zig").Tri27Status;

/// TRI-27 Event (from tri27_experience.zig)
pub const Tri27Event = struct {
    timestamp: i64,
    operation: Tri27Operation,
    input_file: [256]u8,
    output_file: [256]u8,
    status: Tri27Status,
    cycles: u32 = 0,
    instructions: u32 = 0,
    error_msg: [512]u8 = undefined,
    has_error: bool = false,

    pub fn inputFile(self: Tri27Event) []const u8 {
        const len = indexOfNull(&self.input_file);
        return self.input_file[0..len];
    }

    pub fn outputFile(self: Tri27Event) []const u8 {
        const len = indexOfNull(&self.output_file);
        return self.output_file[0..len];
    }

    pub fn errorMsg(self: Tri27Event) []const u8 {
        if (!self.has_error) return "";
        const len = indexOfNull(&self.error_msg);
        return self.error_msg[0..len];
    }
};

fn indexOfNull(buf: []const u8) usize {
    var i: usize = 0;
    while (i < buf.len) {
        if (buf[i] == 0) return i;
        i += 1;
    }
    return buf.len;
}

/// Map Tri27Event to Queen Episode
pub fn fromTri27Event(allocator: Allocator, event: Tri27Event, issue_id: ?u64) !Episode {
    const timestamp_ns = @as(u64, @intCast(@abs(event.timestamp))) * 1_000_000;

    // Create default context
    var context = Context{
        .timestamp_ns = timestamp_ns,
        .policy = PolicySnapshot{},
        .senses = SensorsSnapshot{},
        .active_issues = &[_]u64{},
        .recalled_episodes = &[_]Episode{},
    };

    // If issue_id provided, add to active_issues
    if (issue_id) |id| {
        const issues = try allocator.create(u64);
        issues.* = id;
        context.active_issues = issues[0..1];
    }

    // Map Tri27Status to Outcome
    const outcome: Outcome = switch (event.status) {
        .success => .success,
        .failed => if (event.has_error)
            .failure_learned // We have an error message = lesson learned
        else
            .failure_unknown,
        .timeout => .blocked,
        .cancelled => .blocked,
        .queued, .running => .partial, // Incomplete = partial
    };

    // Map Tri27Status to Result
    const error_msg = if (event.has_error)
        try allocator.dupe(u8, event.errorMsg())
    else
        null;

    const output_msg = if (event.status == .success)
        try allocator.dupe(u8, event.outputFile())
    else
        null;

    const result = Result{
        .success = event.status == .success,
        .@"error" = error_msg,
        .timing = Timing{
            .start_ns = timestamp_ns,
            .end_ns = timestamp_ns + event.cycles * 1000,
            .duration_ms = event.cycles / 1000, // Approx: cycles to ms
        },
        .output = output_msg,
        .new_senses = SensorsSnapshot{},
    };

    // Create episode with TRI-27 source
    return Episode{
        .id = @as(u64, @intCast(std.time.nanoTimestamp())),
        .timestamp = timestamp_ns,
        .source = .tri27, // Will add this to Source enum
        .context = context,
        .action = .{
            .tri27_op = .{
                .operation = event.operation,
                .input_file = try allocator.dupe(u8, event.inputFile()),
                .output_file = try allocator.dupe(u8, event.outputFile()),
                .cycles = event.cycles,
                .instructions = event.instructions,
            },
        },
        .result = result,
        .outcome = outcome,
    };
}

test "tri27_bridge: Tri27Event helper methods work correctly" {
    var input_buf: [256]u8 = undefined;
    var output_buf: [256]u8 = undefined;
    @memset(input_buf[0..256], 0);
    @memset(output_buf[0..256], 0);
    @memcpy(input_buf[0..15], "test_input.tasm");
    @memcpy(output_buf[0..16], "test_output.tbin");

    const event = Tri27Event{
        .timestamp = 1234567890,
        .operation = .run,
        .input_file = input_buf,
        .output_file = output_buf,
        .status = .success,
        .cycles = 100,
        .instructions = 25,
        .error_msg = [_]u8{0} ** 512,
        .has_error = false,
    };

    try std.testing.expectEqual(@as(usize, 15), event.inputFile().len);
    try std.testing.expectEqualStrings("test_input.tasm", event.inputFile());
    try std.testing.expectEqual(@as(usize, 16), event.outputFile().len);
    try std.testing.expectEqualStrings("test_output.tbin", event.outputFile());
    try std.testing.expectEqualStrings("", event.errorMsg());
}

test "tri27_bridge: fromTri27Event creates valid episode" {
    const allocator = std.testing.allocator;

    var input_buf: [256]u8 = undefined;
    var output_buf: [256]u8 = undefined;
    @memcpy(input_buf[0..9], "test.tasm");
    input_buf[8] = 0;
    @memcpy(output_buf[0..9], "test.tbin");
    output_buf[8] = 0;

    const event = Tri27Event{
        .timestamp = 1234567890,
        .operation = .run,
        .input_file = input_buf,
        .output_file = output_buf,
        .status = .success,
        .cycles = 100,
        .instructions = 25,
        .error_msg = [_]u8{0} ** 512,
        .has_error = false,
    };

    const episode = try fromTri27Event(allocator, event, null);
    defer {
        allocator.free(episode.context.active_issues);
        if (episode.result.output) |o| allocator.free(o);
        if (episode.action.tri27_op.input_file.len > 0) allocator.free(episode.action.tri27_op.input_file);
        if (episode.action.tri27_op.output_file.len > 0) allocator.free(episode.action.tri27_op.output_file);
    }

    try std.testing.expect(episode.id != 0);
    try std.testing.expectEqual(Source.tri27, episode.source);
    try std.testing.expectEqual(.success, episode.outcome);
    try std.testing.expect(episode.result.success);
    try std.testing.expectEqual(@as(u64, 0), episode.result.timing.duration_ms);
}

test "tri27_bridge: fromTri27Event maps failed status correctly" {
    const allocator = std.testing.allocator;

    var input_buf: [256]u8 = undefined;
    var output_buf: [256]u8 = undefined;
    var error_buf: [512]u8 = undefined;
    @memcpy(input_buf[0..9], "test.tasm");
    input_buf[8] = 0;
    @memset(output_buf[0..256], 0);
    @memcpy(error_buf[0..22], "Syntax error at line 5");
    error_buf[21] = 0;

    const event = Tri27Event{
        .timestamp = 1234567890,
        .operation = .assemble,
        .input_file = input_buf,
        .output_file = output_buf,
        .status = .failed,
        .cycles = 50,
        .instructions = 10,
        .error_msg = error_buf,
        .has_error = true,
    };

    const episode = try fromTri27Event(allocator, event, null);
    defer {
        allocator.free(episode.context.active_issues);
        if (episode.result.@"error") |e| allocator.free(e);
        if (episode.action.tri27_op.input_file.len > 0) allocator.free(episode.action.tri27_op.input_file);
    }

    try std.testing.expectEqual(.failure_learned, episode.outcome);
    try std.testing.expect(!episode.result.success);
    try std.testing.expect(episode.result.@"error" != null);
}

// Extension: Add TRI-27 source to episodes module
// This should be added to src/tri/queen/episodes.zig Source enum:
//
// pub const Source = enum {
//     lotus_cycle,
//     external,
//     scheduled,
//     experience_recall,
//     tri27,  // <-- Add this
// };

// Extension: Add TRI-27 action to episodes module
// This should be added to src/tri/queen/episodes.zig Action union:
//
// pub const Action = union(enum) {
//     scale_up: struct { key: []const u8, quality_score: f64 },
//     scale_down: struct { key: []const u8, quality_score: f64 },
//     trigger: struct { key: []const u8 },
//     set: struct { key: []const u8, value: union { bool: bool, f64: f64 } },
//     wait: void,
//     tri27_op: struct {  // <-- Add this
//         operation: Tri27Operation,
//         input_file: []const u8,
//         output_file: []const u8,
//         cycles: u32,
//         instructions: u32,
//     },
// };
