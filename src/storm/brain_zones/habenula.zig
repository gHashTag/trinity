//! HABENULA (Reticular Formation) — Reward/Effort Ratio
//! Detects unfair reward (effort >> reward) -> SUSPICIOUS

const std = @import("std");

pub const Reason = struct {
    reward_ratio: f32,
    message: []const u8,
};

pub fn cmdUnfairDetect(allocator: std.mem.Allocator, args: []const u8) !u8 {
    _ = allocator;
    _ = args;

    const MIN_RATIO: f32 = 2.0; // effort >> 2x reward = SUSPICIOUS

    std.debug.print("🧠 HABENULA unfair-detect: P1 TODO\n");

    // Calculate reward/effort ratio from experience
    // TODO: Integrate with experience engine
    const reward_ratio: f32 = 1.0; // Mock for now

    return try std.fmt.allocPrint(allocator, "HABENULA: reward/effort = {d:.2} (ratio >= {d:.1} = SUSPICIOUS", .{
        reward_ratio, MIN_RATIO,
    });
}
