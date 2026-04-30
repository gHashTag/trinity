const std = @import("std");

pub fn DoubleBufferedPrefetch(comptime T: type, comptime buffer_size: usize) type {
    return struct {
        const Self = @This();

        buffers: [2][buffer_size]T,
        active: usize,
        ready: [2]bool,
        loading: bool,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .buffers = .{[_]T{0} ** buffer_size, [_]T{0} ** buffer_size},
                .active = 0,
                .ready = .{ false, false },
                .loading = false,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            _ = self;
        }

        pub fn getActive(self: *const Self) []const T {
            return &self.buffers[self.active];
        }

        pub fn getBackBuffer(self: *Self) []T {
            return &self.buffers[1 - self.active];
        }

        pub fn swap(self: *Self) bool {
            const back = 1 - self.active;
            if (!self.ready[back]) return false;
            self.ready[self.active] = false;
            self.active = back;
            return true;
        }

        pub fn markBackReady(self: *Self) void {
            self.ready[1 - self.active] = true;
            self.loading = false;
        }

        pub fn startLoad(self: *Self) void {
            self.loading = true;
        }

        pub fn isLoading(self: *const Self) bool {
            return self.loading;
        }

        pub fn isBackReady(self: *const Self) bool {
            return self.ready[1 - self.active];
        }

        pub fn loadFromSlice(self: *Self, data: []const T, offset: usize) bool {
            const back = 1 - self.active;
            const copy_len = @min(buffer_size, data.len - offset);
            if (copy_len == 0) return false;

            for (0..copy_len) |i| {
                self.buffers[back][i] = data[offset + i];
            }
            self.ready[back] = true;
            self.loading = false;
            return true;
        }
    };
}

pub const BatchPrefetcher = struct {
    allocator: std.mem.Allocator,
    buffer_a: []f32,
    buffer_b: []f32,
    active: usize,
    batch_size: usize,
    seq_len: usize,
    feature_dim: usize,
    stride: usize,

    pub fn init(allocator: std.mem.Allocator, batch_size: usize, seq_len: usize, feature_dim: usize) !BatchPrefetcher {
        const stride = batch_size * seq_len * feature_dim;
        const buffer_a = try allocator.alloc(f32, stride);
        const buffer_b = try allocator.alloc(f32, stride);

        return .{
            .allocator = allocator,
            .buffer_a = buffer_a,
            .buffer_b = buffer_b,
            .active = 0,
            .batch_size = batch_size,
            .seq_len = seq_len,
            .feature_dim = feature_dim,
            .stride = stride,
        };
    }

    pub fn deinit(self: *BatchPrefetcher) void {
        self.allocator.free(self.buffer_a);
        self.allocator.free(self.buffer_b);
    }

    pub fn loadBatch(self: *BatchPrefetcher, dataset: []const f32, batch_idx: usize) bool {
        const offset = batch_idx * self.stride;
        if (offset + self.stride > dataset.len) return false;

        const back: usize = 1 - self.active;
        const dst = if (back == 0) self.buffer_a else self.buffer_b;
        const src = dataset[offset..][0..self.stride];

        @memcpy(dst[0..self.stride], src);
        self.active = back;
        return true;
    }

    pub fn getActiveBatch(self: *const BatchPrefetcher) []const f32 {
        if (self.active == 0) return self.buffer_a;
        return self.buffer_b;
    }

    pub fn prefetchAsync(self: *BatchPrefetcher, dataset: []const f32, batch_idx: usize) bool {
        const offset = batch_idx * self.stride;
        if (offset + self.stride > dataset.len) return false;

        const back: usize = 1 - self.active;
        const dst = if (back == 0) self.buffer_a else self.buffer_b;
        const src = dataset[offset..][0..self.stride];
        @memcpy(dst[0..self.stride], src);
        return true;
    }

    pub fn swap(self: *BatchPrefetcher) void {
        self.active = 1 - self.active;
    }

    pub fn batchCount(self: *const BatchPrefetcher, dataset_len: usize) usize {
        return dataset_len / self.stride;
    }
};

test "double buffer swap" {
    var db = DoubleBufferedPrefetch(f32, 4).init(std.testing.allocator);
    defer db.deinit();

    const data = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    _ = db.loadFromSlice(&data, 0);

    try std.testing.expect(db.isBackReady());
    try std.testing.expect(db.swap());

    const active = db.getActive();
    try std.testing.expectEqual(@as(f32, 1.0), active[0]);
}

test "double buffer double swap" {
    var db = DoubleBufferedPrefetch(f32, 4).init(std.testing.allocator);
    defer db.deinit();

    const data1 = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const data2 = [_]f32{ 5.0, 6.0, 7.0, 8.0 };

    _ = db.loadFromSlice(&data1, 0);
    _ = db.swap();

    _ = db.loadFromSlice(&data2, 0);
    _ = db.swap();

    const active = db.getActive();
    try std.testing.expectEqual(@as(f32, 5.0), active[0]);
}

test "double buffer swap fails when back not ready" {
    var db = DoubleBufferedPrefetch(f32, 4).init(std.testing.allocator);
    defer db.deinit();

    try std.testing.expect(!db.swap());
}

test "batch prefetcher load and get" {
    const allocator = std.testing.allocator;
    var pf = try BatchPrefetcher.init(allocator, 2, 3, 4);
    defer pf.deinit();

    var dataset = [_]f32{0} ** 48;
    for (&dataset, 0..) |*d, i| d.* = @floatFromInt(i);

    try std.testing.expect(pf.loadBatch(&dataset, 0));
    const batch = pf.getActiveBatch();
    try std.testing.expectEqual(@as(f32, 0.0), batch[0]);
    try std.testing.expectEqual(@as(f32, 23.0), batch[23]);
}

test "batch prefetcher handles out of range" {
    const allocator = std.testing.allocator;
    var pf = try BatchPrefetcher.init(allocator, 2, 3, 4);
    defer pf.deinit();

    const dataset = [_]f32{0} ** 24;
    try std.testing.expect(!pf.loadBatch(&dataset, 1));
}

test "batch prefetcher async prefetch and swap" {
    const allocator = std.testing.allocator;
    var pf = try BatchPrefetcher.init(allocator, 2, 3, 4);
    defer pf.deinit();

    var dataset = [_]f32{0} ** 48;
    for (&dataset, 0..) |*d, i| d.* = @floatFromInt(i);

    try std.testing.expect(pf.loadBatch(&dataset, 0));
    try std.testing.expect(pf.prefetchAsync(&dataset, 1));
    pf.swap();

    const batch = pf.getActiveBatch();
    try std.testing.expectEqual(@as(f32, 24.0), batch[0]);
}

test "batch count" {
    const allocator = std.testing.allocator;
    var pf = try BatchPrefetcher.init(allocator, 2, 3, 4);
    defer pf.deinit();

    const dataset_len: usize = 96;
    try std.testing.expectEqual(@as(usize, 2), pf.batchCount(dataset_len));
}
