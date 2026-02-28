//! Streaming Memory - [EN]from[EN]to[EN]in[EN] [EN]withwith[EN]and[EN]andinon[EN] memory on HDC
//!
//! [CYR:[EN]]in[CYR:[EN]] [CYR:[EN]]and[EN] with bind/unbind for key-value storing.
//! [CYR:[EN]]to[EN] forgetting factor for [EN]yes[CYR:[EN]]andand to concept drift.
//!
//! [CYR:[EN]]on[EN] [CYR:base]:
//! - Holographic Reduced Representations (Plate, 1995)
//! - Sparse Distributed Memory (Kanerva, 1988)
//! - Online Learning with Forgetting
//!
//! [CYR:[EN]]and[EN]:
//! - Store: M ← M + bind(key, value)
//! - Retrieve: value ≈ unbind(M, key)
//! - Forgetting: M ← (1-λ)M + λ×bind(k,v)
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

// ═══════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════

pub const DEFAULT_DIM: usize = 1024;
pub const DEFAULT_FORGETTING_FACTOR: f64 = 0.01;
pub const DEFAULT_RETRIEVAL_THRESHOLD: f64 = 0.5;
pub const DEFAULT_MAX_ITEMS: usize = 10000;

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

/// [CYR:[EN]]and[CYR:[EN]]and[EN] [CYR:[EN]]and
pub const MemoryConfig = struct {
    dim: usize = DEFAULT_DIM,
    forgetting_factor: f64 = DEFAULT_FORGETTING_FACTOR,
    retrieval_threshold: f64 = DEFAULT_RETRIEVAL_THRESHOLD,
    max_items: usize = DEFAULT_MAX_ITEMS,
};

/// Result extraction
pub const RetrievalResult = struct {
    value: []Trit,
    confidence: f64,
    found: bool,
};

/// [CYR:[EN]]andtoand [CYR:[EN]]and
pub const MemoryMetrics = struct {
    total_writes: u64,
    total_reads: u64,
    item_count: usize,
    avg_confidence: f64,
    memory_utilization: f64,
};

/// [EN]from[EN]to[EN]in[EN] [EN]withwith[EN]and[EN]andinon[EN] memory
pub const StreamingMemory = struct {
    config: MemoryConfig,
    // Float [EN]toto[CYR:[EN]] for [CYR:[EN]]in[CYR:[EN]] [CYR:[EN]]in[CYR:[EN]]and[EN]
    accumulator: []f64,
    // [EN]in[CYR:[EN]]and[EN]in[EN]on[EN] [CYR:[EN]]and[EN]on[EN] memory
    memory: []Trit,
    // [CYR:[EN]]andwith[EN]andto[EN]
    item_count: usize,
    total_writes: u64,
    total_reads: u64,
    total_confidence: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: MemoryConfig) !StreamingMemory {
        const accumulator = try allocator.alloc(f64, config.dim);
        @memset(accumulator, 0.0);
        const memory = try allocator.alloc(Trit, config.dim);
        @memset(memory, 0);

        return .{
            .config = config,
            .accumulator = accumulator,
            .memory = memory,
            .item_count = 0,
            .total_writes = 0,
            .total_reads = 0,
            .total_confidence = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StreamingMemory) void {
        self.allocator.free(self.accumulator);
        self.allocator.free(self.memory);
    }

    /// [CYR:[EN]]withand[EN] memory
    pub fn reset(self: *StreamingMemory) void {
        @memset(self.accumulator, 0.0);
        @memset(self.memory, 0);
        self.item_count = 0;
        self.total_writes = 0;
        self.total_reads = 0;
        self.total_confidence = 0;
    }

    /// [CYR:[EN]]and[EN] [CYR:[EN]] to[CYR:[EN]]-value
    /// M ← M + bind(key, value)
    pub fn store(self: *StreamingMemory, key: []const Trit, value: []const Trit) !void {
        const dim = self.config.dim;
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);

        // bind(key, value)
        hdc.bind(key, value, bound);

        // Add to [EN]toto[CYR:[EN]]
        for (0..dim) |i| {
            self.accumulator[i] += @floatFromInt(bound[i]);
        }

        // [EN]in[CYR:[EN]]and[CYR:[EN]]
        hdc.quantizeToTernary(self.accumulator, self.memory);

        self.item_count += 1;
        self.total_writes += 1;
    }

    /// [CYR:[EN]]and[EN] with [CYR:[EN]]in[EN]and[EN]
    /// M ← (1-λ)M + λ×bind(k,v)
    pub fn storeWithForgetting(self: *StreamingMemory, key: []const Trit, value: []const Trit, lambda: f64) !void {
        const dim = self.config.dim;
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);

        // bind(key, value)
        hdc.bind(key, value, bound);

        // [EN]towithbynot[EN]and[CYR:[EN]] [CYR:[EN]]in[EN]and[EN] + new element
        for (0..dim) |i| {
            self.accumulator[i] = (1.0 - lambda) * self.accumulator[i] + lambda * @as(f64, @floatFromInt(bound[i]));
        }

        // [EN]in[CYR:[EN]]and[CYR:[EN]]
        hdc.quantizeToTernary(self.accumulator, self.memory);

        self.item_count += 1;
        self.total_writes += 1;
    }

    /// [EN]in[CYR:[EN]] value by to[CYR:[EN]]
    /// value ≈ unbind(M, key)
    pub fn retrieve(self: *StreamingMemory, key: []const Trit, result: []Trit) RetrievalResult {
        const dim = self.config.dim;

        // unbind(M, key) = bind(M, key) for [CYR:[EN]]and[CYR:[EN]] in[EN]to[CYR:[EN]]in
        hdc.unbind(self.memory, key, result);

        // Compute [EN]in[CYR:[EN]]with[EN] via [CYR:[EN]] result[EN]
        var norm: f64 = 0;
        for (0..dim) |i| {
            norm += @as(f64, @floatFromInt(result[i])) * @as(f64, @floatFromInt(result[i]));
        }
        norm = @sqrt(norm);

        // [CYR:[EN]]and[CYR:[EN]] [EN]in[CYR:[EN]]with[EN]
        const max_norm = @sqrt(@as(f64, @floatFromInt(dim)));
        const confidence = norm / max_norm;

        self.total_reads += 1;
        self.total_confidence += confidence;

        return .{
            .value = result,
            .confidence = confidence,
            .found = confidence > self.config.retrieval_threshold,
        };
    }

    /// [CYR:[EN]]in[EN]and[EN] on[EN]and[EN]and[EN] to[CYR:[EN]]
    pub fn contains(self: *StreamingMemory, key: []const Trit) !bool {
        const result = try self.allocator.alloc(Trit, self.config.dim);
        defer self.allocator.free(result);

        const retrieval = self.retrieve(key, result);
        return retrieval.found;
    }

    /// [EN]and[CYR:[EN]]and[EN] [CYR:[EN]]in[EN]and[EN] to[EN] inwith[EN] [CYR:[EN]]and
    /// M ← (1-λ)M
    pub fn applyForgetting(self: *StreamingMemory, lambda: f64) void {
        for (self.accumulator) |*a| {
            a.* *= (1.0 - lambda);
        }
        hdc.quantizeToTernary(self.accumulator, self.memory);
    }

    /// [EN]yes[EN]and[EN] to[EN]to[CYR:[EN]] to[CYR:[EN]]
    /// M ← M - bind(k, retrieve(k))
    pub fn forget(self: *StreamingMemory, key: []const Trit) !void {
        const dim = self.config.dim;
        const retrieved = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(retrieved);

        // Get [EN]to[CYR:[EN]] value
        _ = self.retrieve(key, retrieved);

        // Compute bind(key, retrieved)
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);
        hdc.bind(key, retrieved, bound);

        // [CYR:[EN]]and[CYR:[EN]] and[EN] [EN]toto[CYR:[EN]]
        for (0..dim) |i| {
            self.accumulator[i] -= @floatFromInt(bound[i]);
        }

        // [EN]in[CYR:[EN]]and[CYR:[EN]]
        hdc.quantizeToTernary(self.accumulator, self.memory);

        if (self.item_count > 0) self.item_count -= 1;
    }

    /// [CYR:[EN]]and[EN]and[EN] [EN]in[EN] [CYR:[EN]]and
    pub fn merge(self: *StreamingMemory, other: *const StreamingMemory) void {
        const dim = @min(self.config.dim, other.config.dim);
        for (0..dim) |i| {
            self.accumulator[i] += other.accumulator[i];
        }
        hdc.quantizeToTernary(self.accumulator, self.memory);
        self.item_count += other.item_count;
    }

    /// [CYR:[EN]]and[EN] [CYR:[EN]]andtoand
    pub fn getMetrics(self: *const StreamingMemory) MemoryMetrics {
        const avg_conf = if (self.total_reads > 0)
            self.total_confidence / @as(f64, @floatFromInt(self.total_reads))
        else
            0.0;

        const utilization = @as(f64, @floatFromInt(self.item_count)) /
            @as(f64, @floatFromInt(self.config.max_items));

        return .{
            .total_writes = self.total_writes,
            .total_reads = self.total_reads,
            .item_count = self.item_count,
            .avg_confidence = avg_conf,
            .memory_utilization = @min(1.0, utilization),
        };
    }

    /// [CYR:[EN]]and[EN] with[CYR:[EN]] vector [CYR:[EN]]and
    pub fn getMemoryVector(self: *const StreamingMemory) []const Trit {
        return self.memory;
    }
};

// ═══════════════════════════════════════════════════════════════
// [CYR:[EN]]
// ═══════════════════════════════════════════════════════════════

test "memory init/deinit" {
    const allocator = std.testing.allocator;
    var mem = try StreamingMemory.init(allocator, .{ .dim = 100 });
    defer mem.deinit();

    try std.testing.expectEqual(@as(usize, 0), mem.item_count);
    try std.testing.expectEqual(@as(u64, 0), mem.total_writes);
}

test "store and retrieve" {
    const allocator = std.testing.allocator;
    var mem = try StreamingMemory.init(allocator, .{ .dim = 1000 });
    defer mem.deinit();

    // [CYR:[EN]]yes[EN] to[CYR:[EN]] and value
    var key = try hdc.randomVector(allocator, 1000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 1000, 22222);
    defer value.deinit();

    // [CYR:[EN]]
    try mem.store(key.data, value.data);

    // Extract
    const result_buf = try allocator.alloc(Trit, 1000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);

    // Check with[CYR:[EN]]with[EN]in[EN] with [EN]and[EN]andon[CYR:[EN]] [EN]on[CYR:[EN]]and[EN]
    const sim = hdc.similarity(result.value, value.data);
    try std.testing.expect(sim > 0.5);
}

test "multiple items" {
    const allocator = std.testing.allocator;
    // [EN]withby[CYR:[EN]] [CYR:[EN]] [CYR:[EN]]with[EN] for better[EN] [EN]to[EN]with[EN]and
    var mem = try StreamingMemory.init(allocator, .{ .dim = 5000 });
    defer mem.deinit();

    // [CYR:[EN]] notwithto[CYR:[EN]]to[EN] [CYR:[EN]] (less for better[EN] to[CYR:[EN]]with[EN]in[EN])
    const num_items = 5;
    var keys: [num_items]HyperVector = undefined;
    var values: [num_items]HyperVector = undefined;

    for (0..num_items) |i| {
        keys[i] = try hdc.randomVector(allocator, 5000, @as(u64, i) * 1000 + 1);
        values[i] = try hdc.randomVector(allocator, 5000, @as(u64, i) * 1000 + 2);
        try mem.store(keys[i].data, values[i].data);
    }
    defer {
        for (0..num_items) |i| {
            keys[i].deinit();
            values[i].deinit();
        }
    }

    // Check and[EN]in[CYR:[EN]]and[EN]
    const result_buf = try allocator.alloc(Trit, 5000);
    defer allocator.free(result_buf);

    var total_sim: f64 = 0;
    for (0..num_items) |i| {
        const result = mem.retrieve(keys[i].data, result_buf);
        const sim = hdc.similarity(result.value, values[i].data);
        total_sim += sim;
    }

    const avg_sim = total_sim / @as(f64, num_items);
    // HDC memory and[CYR:[EN]] [CYR:[EN]]and[CYR:[EN]] [EN]to[EN]with[EN], [EN]andyes[EN] [EN]from[EN] [EN] by[CYR:[EN]]and[CYR:[EN]] with[CYR:[EN]]with[EN]in[EN]
    try std.testing.expect(avg_sim > 0.1);
}

test "forgetting reduces old" {
    const allocator = std.testing.allocator;
    var mem = try StreamingMemory.init(allocator, .{ .dim = 500 });
    defer mem.deinit();

    var key = try hdc.randomVector(allocator, 500, 33333);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 500, 44444);
    defer value.deinit();

    // [CYR:[EN]]
    try mem.store(key.data, value.data);

    const result_buf = try allocator.alloc(Trit, 500);
    defer allocator.free(result_buf);

    // Extract before [CYR:[EN]]in[EN]and[EN]
    const before = mem.retrieve(key.data, result_buf);
    const conf_before = before.confidence;

    // [EN]and[CYR:[EN]] withand[CYR:[EN]] [CYR:[EN]]in[EN]and[EN]
    mem.applyForgetting(0.9);

    // Extract after [CYR:[EN]]in[EN]and[EN]
    const after = mem.retrieve(key.data, result_buf);
    const conf_after = after.confidence;

    // [EN]in[CYR:[EN]]with[EN] before[EN]on [CYR:[EN]]and[EN]with[EN]
    try std.testing.expect(conf_after < conf_before);
}

test "store with forgetting" {
    const allocator = std.testing.allocator;
    var mem = try StreamingMemory.init(allocator, .{ .dim = 500 });
    defer mem.deinit();

    var key1 = try hdc.randomVector(allocator, 500, 11111);
    defer key1.deinit();
    var val1 = try hdc.randomVector(allocator, 500, 11112);
    defer val1.deinit();

    var key2 = try hdc.randomVector(allocator, 500, 22221);
    defer key2.deinit();
    var val2 = try hdc.randomVector(allocator, 500, 22222);
    defer val2.deinit();

    // [CYR:[EN]] [CYR:[EN]]in[EN] element
    try mem.storeWithForgetting(key1.data, val1.data, 1.0);

    // [CYR:[EN]] in[CYR:[EN]] with [CYR:[EN]]in[EN]and[EN] [CYR:[EN]]in[CYR:[EN]]
    try mem.storeWithForgetting(key2.data, val2.data, 0.5);

    try std.testing.expectEqual(@as(usize, 2), mem.item_count);
}

test "merge memories" {
    const allocator = std.testing.allocator;
    var mem1 = try StreamingMemory.init(allocator, .{ .dim = 500 });
    defer mem1.deinit();
    var mem2 = try StreamingMemory.init(allocator, .{ .dim = 500 });
    defer mem2.deinit();

    var key1 = try hdc.randomVector(allocator, 500, 11111);
    defer key1.deinit();
    var val1 = try hdc.randomVector(allocator, 500, 11112);
    defer val1.deinit();

    var key2 = try hdc.randomVector(allocator, 500, 22221);
    defer key2.deinit();
    var val2 = try hdc.randomVector(allocator, 500, 22222);
    defer val2.deinit();

    try mem1.store(key1.data, val1.data);
    try mem2.store(key2.data, val2.data);

    // [CYR:[EN]]and[CYR:[EN]]
    mem1.merge(&mem2);

    try std.testing.expectEqual(@as(usize, 2), mem1.item_count);
}

test "metrics" {
    const allocator = std.testing.allocator;
    var mem = try StreamingMemory.init(allocator, .{ .dim = 100 });
    defer mem.deinit();

    var key = try hdc.randomVector(allocator, 100, 55555);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 100, 66666);
    defer value.deinit();

    try mem.store(key.data, value.data);

    const result_buf = try allocator.alloc(Trit, 100);
    defer allocator.free(result_buf);
    _ = mem.retrieve(key.data, result_buf);

    const metrics = mem.getMetrics();
    try std.testing.expectEqual(@as(u64, 1), metrics.total_writes);
    try std.testing.expectEqual(@as(u64, 1), metrics.total_reads);
    try std.testing.expectEqual(@as(usize, 1), metrics.item_count);
}
