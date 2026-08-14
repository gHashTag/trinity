const std = @import("std");

pub const CheckpointConfig = struct {
    checkpoint_every_n: usize = 2,
    max_checkpoints: usize = 64,
};

pub const CheckpointStore = struct {
    allocator: std.mem.Allocator,
    checkpoints: std.ArrayList([]f32),
    layer_sizes: []const usize,
    config: CheckpointConfig,
    num_layers: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        layer_sizes: []const usize,
        config: CheckpointConfig,
    ) !CheckpointStore {
        var total_layers: usize = 0;
        for (layer_sizes[1..]) |_| total_layers += 1;

        return .{
            .allocator = allocator,
            .checkpoints = std.ArrayList([]f32).init(allocator),
            .layer_sizes = layer_sizes,
            .config = config,
            .num_layers = total_layers,
        };
    }

    pub fn deinit(self: *CheckpointStore) void {
        for (self.checkpoints.items) |cp| {
            self.allocator.free(cp);
        }
        self.checkpoints.deinit();
    }

    pub fn saveCheckpoint(self: *CheckpointStore, layer_idx: usize, activation: []const f32) !void {
        if (layer_idx % self.config.checkpoint_every_n != 0) return;

        if (self.checkpoints.items.len >= self.config.max_checkpoints) {
            const oldest = self.checkpoints.orderedRemove(0);
            self.allocator.free(oldest);
        }

        const copy = try self.allocator.dupe(f32, activation);
        try self.checkpoints.append(copy);
    }

    pub fn recompute(self: *CheckpointStore, from_layer: usize, to_layer: usize, activations: [][]f32) void {
        _ = from_layer;
        _ = to_layer;
        _ = activations;
    }

    pub fn memoryUsedMB(self: *const CheckpointStore) f64 {
        var total: usize = 0;
        for (self.checkpoints.items) |cp| {
            total += cp.len * @sizeOf(f32);
        }
        return @as(f64, @floatFromInt(total)) / (1024.0 * 1024.0);
    }

    pub fn savedMemoryMB(self: *const CheckpointStore, full_activations_size: usize) f64 {
        const full_mb: f64 = @floatFromInt(full_activations_size * @sizeOf(f32) * self.num_layers);
        return full_mb - self.memoryUsedMB();
    }

    pub fn checkpointCount(self: *const CheckpointStore) usize {
        return self.checkpoints.items.len;
    }
};

pub const MemoryBudget = struct {
    total_bytes: usize,
    model_bytes: usize,
    optimizer_bytes: usize,
    gradient_bytes: usize,
    activation_bytes: usize,

    pub fn availableForCheckpoints(self: MemoryBudget) usize {
        const used = self.model_bytes + self.optimizer_bytes + self.gradient_bytes + self.activation_bytes;
        return if (self.total_bytes > used) self.total_bytes - used else 0;
    }

    pub fn recommendedCheckpointEvery(self: MemoryBudget, num_layers: usize, layer_activation_bytes: usize) usize {
        const available = self.availableForCheckpoints();
        const max_storable = available / @max(layer_activation_bytes, 1);
        if (max_storable >= num_layers) return 1;
        if (max_storable == 0) return num_layers;
        return @max(num_layers / max_storable, 1);
    }
};

test "checkpoint store saves and counts" {
    const allocator = std.testing.allocator;
    const sizes = [_]usize{ 4, 8, 4 };
    var store = try CheckpointStore.init(allocator, &sizes, .{ .checkpoint_every_n = 1 });
    defer store.deinit();

    const act1 = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    try store.saveCheckpoint(0, &act1);
    try std.testing.expectEqual(@as(usize, 1), store.checkpointCount());

    const act2 = [_]f32{ 0.1, 0.2, 0.3, 0.4 };
    try store.saveCheckpoint(1, &act2);
    try std.testing.expectEqual(@as(usize, 2), store.checkpointCount());
}

test "checkpoint store skips non-checkpoint layers" {
    const allocator = std.testing.allocator;
    const sizes = [_]usize{ 4, 8, 4 };
    var store = try CheckpointStore.init(allocator, &sizes, .{ .checkpoint_every_n = 2 });
    defer store.deinit();

    const act = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    try store.saveCheckpoint(0, &act);
    try store.saveCheckpoint(1, &act);
    try store.saveCheckpoint(2, &act);

    try std.testing.expectEqual(@as(usize, 2), store.checkpointCount());
}

test "checkpoint store evicts oldest when full" {
    const allocator = std.testing.allocator;
    const sizes = [_]usize{ 4, 8, 4 };
    var store = try CheckpointStore.init(allocator, &sizes, .{ .checkpoint_every_n = 1, .max_checkpoints = 2 });
    defer store.deinit();

    const act1 = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    const act2 = [_]f32{ 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0 };
    const act3 = [_]f32{ 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 };

    try store.saveCheckpoint(0, &act1);
    try store.saveCheckpoint(1, &act2);
    try store.saveCheckpoint(2, &act3);

    try std.testing.expectEqual(@as(usize, 2), store.checkpointCount());
}

test "memory tracking" {
    const allocator = std.testing.allocator;
    const sizes = [_]usize{ 4, 8, 4 };
    var store = try CheckpointStore.init(allocator, &sizes, .{ .checkpoint_every_n = 1 });
    defer store.deinit();

    const act = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    try store.saveCheckpoint(0, &act);

    const mb = store.memoryUsedMB();
    try std.testing.expect(mb > 0);
    try std.testing.expect(mb < 1.0);
}

test "memory budget recommended checkpoint interval" {
    const budget = MemoryBudget{
        .total_bytes = 1024 * 1024 * 1024,
        .model_bytes = 512 * 1024 * 1024,
        .optimizer_bytes = 256 * 1024 * 1024,
        .gradient_bytes = 128 * 1024 * 1024,
        .activation_bytes = 64 * 1024 * 1024,
    };

    const available = budget.availableForCheckpoints();
    try std.testing.expect(available > 0);

    const every = budget.recommendedCheckpointEvery(12, 1024 * 1024);
    try std.testing.expect(every >= 1);
}
