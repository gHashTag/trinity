//! tri/epoch_reclamation — Epoch-based reclamation
//! TTT Dogfood v0.2 Stage 230

const std = @import("std");

const EPOCH_COUNT = 3;

pub const EpochManager = struct {
    current_epoch: usize,
    counters: [EPOCH_COUNT]usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !EpochManager {
        _ = allocator;
        return .{
            .current_epoch = 0,
            .counters = [_]usize{0} ** EPOCH_COUNT,
            .allocator = allocator,
        };
    }

    pub fn enter(manager: *EpochManager) usize {
        const epoch = manager.current_epoch;
        manager.counters[epoch] += 1;
        return epoch;
    }

    pub fn exit(manager: *EpochManager, epoch: usize) void {
        manager.counters[epoch] -= 1;
        if (manager.counters[manager.current_epoch] == 0) {
            const next_epoch = (manager.current_epoch + 1) % EPOCH_COUNT;
            manager.current_epoch = next_epoch;
        }
    }

    pub fn deinit(manager: *EpochManager) void {
        _ = manager;
    }
};

test "epoch manager enter exit" {
    var manager = try EpochManager.init(std.testing.allocator);
    defer manager.deinit();
    const epoch = manager.enter();
    try std.testing.expect(epoch < EPOCH_COUNT);
    manager.exit(epoch);
}
