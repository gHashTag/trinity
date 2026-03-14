// ═══════════════════════════════════════════════════════════════════════════════
// EXPERIENCE HOOKS — Auto-save experience episodes for key commands
// ═══════════════════════════════════════════════════════════════════════════════
//
// Fire-and-forget experience tracking. Call autoSaveExperience() at the end
// of any command handler to record what happened.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_experience = @import("tri_experience.zig");
const Episode = tri_experience.Episode;

const print = std.debug.print;
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

/// Fire-and-forget experience save. Never fails the caller.
pub fn autoSaveExperience(command: []const u8, detail: []const u8, success: bool) void {
    var episode = Episode{};
    episode.timestamp = std.time.timestamp();

    // Set task = "command: detail" or just "command"
    var task_buf: [256]u8 = undefined;
    const task = if (detail.len > 0)
        std.fmt.bufPrint(&task_buf, "{s}: {s}", .{ command, detail }) catch command
    else
        command;

    tri_experience.copyToFixed(&episode.task, &episode.task_len, task);

    // Set verdict
    const verdict: []const u8 = if (success) "PASS" else "FAIL";
    tri_experience.copyToFixed(&episode.verdict, &episode.verdict_len, verdict);

    // Set iterations = 1
    episode.iterations = 1;

    // Save (fire-and-forget)
    tri_experience.saveEpisode(episode) catch {};

    print("  {s}[experience: {s} → {s}]{s}\n", .{ DIM, command, verdict, RESET });
}

/// Auto-save with a mistake recorded
pub fn autoSaveWithMistake(command: []const u8, detail: []const u8, mistake: []const u8) void {
    var episode = Episode{};
    episode.timestamp = std.time.timestamp();

    tri_experience.copyToFixed(&episode.task, &episode.task_len, command);

    const verdict: []const u8 = "FAIL";
    tri_experience.copyToFixed(&episode.verdict, &episode.verdict_len, verdict);

    if (detail.len > 0) {
        tri_experience.copyToFixed(&episode.learnings[0], &episode.learning_lens[0], detail);
        episode.learning_count = 1;
    }

    if (mistake.len > 0) {
        tri_experience.copyToFixed(&episode.mistakes[0], &episode.mistake_lens[0], mistake);
        episode.mistake_count = 1;
    }

    episode.iterations = 1;

    tri_experience.saveEpisode(episode) catch {};

    print("  {s}[experience: {s} → FAIL: {s}]{s}\n", .{ DIM, command, mistake, RESET });
}
