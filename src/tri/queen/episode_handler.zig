const std = @import("std");

pub const EpisodeType = enum { task, observation, action, @"error" };

pub const EpisodeDataRequest = struct {
    domain: []const u8,
    action: ?[]const u8 = null,
    thought: ?[]const u8 = null,
    next_step: ?[]const u8 = null,
};

pub const EpisodeRequest = struct {
    episode_id: []const u8,
    agent: []const u8,
    episode_type: EpisodeType,
    timestamp: []const u8,
    title: []const u8,
    parent_episode_id: ?[]const u8 = null,
    correlation_id: ?[]const u8 = null,
    data: EpisodeDataRequest,
};

/// Parse JSON body into EpisodeRequest. Caller owns returned parsed value.
pub fn parseEpisode(
    allocator: std.mem.Allocator,
    body: []const u8,
) !std.json.Parsed(EpisodeRequest) {
    return try std.json.parseFromSlice(
        EpisodeRequest,
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    );
}
