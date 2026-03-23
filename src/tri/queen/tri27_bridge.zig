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

/// TRI-27 operation types
pub const Tri27Operation = enum(u8) {
    assemble,
    disassemble,
    run,
    @"test",
    flash,
    dump,
};

/// TRI-27 status
pub const Tri27Status = enum(u8) {
    queued,
    running,
    success,
    failed,
    timeout,
    cancelled,
};

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
    const success = event.status == .success;
    var result = Result{
        .success = success,
        .@"error" = if (event.has_error)
            try allocator.dupe(u8, event.errorMsg())
        else
            null,
        .timing = Timing{
            .start_ns = timestamp_ns,
            .duration_ns = event.cycles * 1000, // Approx: 1 cycle = 1μs
        },
        .output = if (success)
            try allocator.dupe(u8, event.outputFile())
        else
            null,
        .new_senses = SensorsSnapshot{},
    };

    // Create episode with TRI-27 source
    return Episode{
        .id = @as(u64, @bitCast(std.time.nanoTimestamp())),
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
