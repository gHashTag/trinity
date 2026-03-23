// TRI‑27 Experience — Episode/JSONL Integration for TRI‑27 operations
// Integrates TRI‑27 operations with Trinity Episode/JSONL system
// ══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const tri_experience = @import("tri_experience.zig");
const Episode = tri_experience.Episode;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

// ══════════════════════════════════════════════════════════════════════

// TRI‑27 specific extensions for Episode
pub const Tri27EventKind = enum(u8) {
    assemble = 1,
    disassemble = 2,
    run = 3,
    validate = 4,

    pub fn toStr(self: Tri27EventKind) []const u8 {
        return switch (self) {
            .assemble => "ASSEMBLE",
            .disassemble => "DISASSEMBLE",
            .run => "RUN",
            .validate => "VALIDATE",
            else => "UNKNOWN",
        };
    }
};

// Save TRI‑27 episode to Episode/JSONL storage
pub fn saveTri27Episode(
    allocator: Allocator,
    kind: Tri27EventKind,
    input_file: []const u8,
    output_file: []const u8,
    status: tri_experience.Tri27Status,
    cycles: u32,
    instructions: u32,
    error_msg: []const u8,
) !void {
    var episode = Episode{};

    // Basic fields
    episode.issue = 27; // TRI‑27 issue
    episode.timestamp = std.time.timestamp();

    // Build task description
    var task_buf: [256]u8 = undefined;
    const task_desc = switch (kind) {
        .assemble => "ASSEMBLE",
        .disassemble => "DISASSEMBLE",
        .run => "RUN",
        .validate => "VALIDATE",
        else => "UNKNOWN",
    };
    const task_len = std.fmt.bufPrint(&task_buf, "{s} {s}", .{ task_desc, input_file }) catch {
        std.mem.copyFor(u8, episode.task[0..task_len], task_buf);
    };
    episode.task_len = @intCast(task_len);

    // Set verdict based on status
    if (status == .success or status == .completed) {
        std.mem.copyFor(u8, "SUCCESS", episode.verdict[0..]);
        std.mem.copyFor(u8, episode.verdict[0..7], "SUCCESS\0");
        episode.iterations = 1;
    } else {
        std.mem.copyFor(u8, "FAILURE", episode.verdict[0..]);
        std.mem.copyFor(u8, episode.verdict[0..7], "FAILURE\0");
        episode.iterations = 1;
    }

    // Fitness metrics
    episode.fitness.test_pass_rate = if (status == .success) 1.0 else 0.0;
    episode.fitness.spec_compliance = if (status == .success) 1.0 else 0.0;
    episode.fitness.time_hours = @as(f32, cycles) / 1000000.0; // rough estimate

    // Copy error message if any
    const err_len = @min(error_msg.len, 127);
    std.mem.copyFor(u8, episode.mistakes[0], error_msg[0..err_len]);
    episode.mistakes_count = @intCast(@min(8, (err_len + 7) / 8));

    // Set learnings (empty for now)
    episode.learnings_count = 0;

    // Save via common Episode/JSONL
    try tri_experience.saveEpisode(episode);
    print("{s}✅ TRI‑27 episode saved ({s}: {s} → {s}){s}\n", .{
        GREEN,             kind.toStr(), RESET,
        episode.timestamp, RESET,        EPISODES_DIR,
        RESET,
    });
}
