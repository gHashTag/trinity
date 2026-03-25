// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// THALAMUS CONTRACTS — Worker view and status structures
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Worker view with source and staleness markers
pub const WorkerView = struct {
    name: []const u8,
    status: []const u8,
    source: Source,
    stale: bool,
    metrics: WorkerMetrics,

    pub const Source = enum {
        live,
        cache,
    };

    pub const WorkerMetrics = struct {
        steps: u64 = 0,
        loss: f64 = 0,
        ppl: f64 = 0,
        timestamp: i64 = 0,
    };

    pub fn fromLive(
        alloc: Allocator,
        name_: []const u8,
        status_: []const u8,
        metrics_: WorkerLiveState,
    ) WorkerView {
        return .{
            .name = alloc.dupe(u8, name_) catch name_,
            .status = alloc.dupe(u8, status_) catch status_,
            .source = .live,
            .stale = false,
            .metrics = .{
                .steps = metrics_.step,
                .loss = metrics_.loss,
                .ppl = metrics_.ppl,
                .timestamp = std.time.timestamp(),
            },
        };
    }
};

/// Worker live state (from Railway logs)
pub const WorkerLiveState = struct {
    status: []const u8,
    step: u64 = 0,
    loss: f64 = 0,
    ppl: f64 = 0,
    timestamp: i64 = 0,
};
