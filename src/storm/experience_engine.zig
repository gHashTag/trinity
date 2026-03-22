//! Experience Engine — P3: Memory and Speed
//! Consult experience, save episodes, similarity search via Levenshtein

const std = @import("std");

/// Error entry for blacklist
pub const Error = struct {
    code: []const u8,
    message: []const u8,
};

/// Episode data stored in JSON
pub const EpisodeData = struct {
    task: []const u8,
    timestamp: u64,
    results: []const Result,
};

pub const Result = struct {
    success: bool,
    message: []const u8,
    duration_ms: u64,
    exit_code: u32,
};

/// Simplified consult result for P3
pub const ConsultResult = struct {
    is_blacklisted: bool,
};

pub const SimilarTask = struct {
    task: []const u8,
    distance: usize,
};

/// Experience Engine for STORM P3
pub const ExperienceEngine = struct {
    allocator: std.mem.Allocator,
    episodes_dir: []const u8,
    blacklist: std.StringHashMap(Error),

    pub fn init(allocator: std.mem.Allocator) !ExperienceEngine {
        const episodes_dir = ".trinity/experience/episodes";
        std.fs.cwd().makePath(episodes_dir) catch {};

        return ExperienceEngine{
            .allocator = allocator,
            .episodes_dir = episodes_dir,
            .blacklist = std.StringHashMap(Error).init(allocator),
        };
    }

    pub fn deinit(self: *ExperienceEngine) void {
        self.blacklist.deinit();
    }

    /// Consult experience - check if task is blacklisted
    /// P3 stub implementation
    pub fn consult(self: *ExperienceEngine, task: []const u8) !ConsultResult {
        const is_blacklisted = self.blacklist.get(task) != null;

        return .{
            .is_blacklisted = is_blacklisted,
        };
    }
};
