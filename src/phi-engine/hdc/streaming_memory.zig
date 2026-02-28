//! Streaming Memory - Пfromоtoоinая аwithwithоцandатandinonя memory on HDC
//!
//! Непрерыinное обученandе with bind/unbind for key-value storing.
//! Поддержtoа forgetting factor for аyesптацandand to concept drift.
//!
//! Научonя база:
//! - Holographic Reduced Representations (Plate, 1995)
//! - Sparse Distributed Memory (Kanerva, 1988)
//! - Online Learning with Forgetting
//!
//! Алгорandтм:
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

/// Конфandгурацandя памятand
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

/// Метрandtoand памятand
pub const MemoryMetrics = struct {
    total_writes: u64,
    total_reads: u64,
    item_count: usize,
    avg_confidence: f64,
    memory_utilization: f64,
};

/// Пfromоtoоinая аwithwithоцandатandinonя memory
pub const StreamingMemory = struct {
    config: MemoryConfig,
    // Float аtotoумулятор for плаinного обноinленandя
    accumulator: []f64,
    // Кinантandзоinанonя троandчonя memory
    memory: []Trit,
    // Статandwithтandtoа
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

    /// Сброwithandть memory
    pub fn reset(self: *StreamingMemory) void {
        @memset(self.accumulator, 0.0);
        @memset(self.memory, 0);
        self.item_count = 0;
        self.total_writes = 0;
        self.total_reads = 0;
        self.total_confidence = 0;
    }

    /// Сохранandть пару toлюч-value
    /// M ← M + bind(key, value)
    pub fn store(self: *StreamingMemory, key: []const Trit, value: []const Trit) !void {
        const dim = self.config.dim;
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);

        // bind(key, value)
        hdc.bind(key, value, bound);

        // Add to аtotoумулятору
        for (0..dim) |i| {
            self.accumulator[i] += @floatFromInt(bound[i]);
        }

        // Кinантandзуем
        hdc.quantizeToTernary(self.accumulator, self.memory);

        self.item_count += 1;
        self.total_writes += 1;
    }

    /// Сохранandть with забыinанandем
    /// M ← (1-λ)M + λ×bind(k,v)
    pub fn storeWithForgetting(self: *StreamingMemory, key: []const Trit, value: []const Trit, lambda: f64) !void {
        const dim = self.config.dim;
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);

        // bind(key, value)
        hdc.bind(key, value, bound);

        // Эtowithbyненцandальное забыinанandе + new element
        for (0..dim) |i| {
            self.accumulator[i] = (1.0 - lambda) * self.accumulator[i] + lambda * @as(f64, @floatFromInt(bound[i]));
        }

        // Кinантandзуем
        hdc.quantizeToTernary(self.accumulator, self.memory);

        self.item_count += 1;
        self.total_writes += 1;
    }

    /// Изinлечь value by toлючу
    /// value ≈ unbind(M, key)
    pub fn retrieve(self: *StreamingMemory, key: []const Trit, result: []Trit) RetrievalResult {
        const dim = self.config.dim;

        // unbind(M, key) = bind(M, key) for троandчных inеtoтороin
        hdc.unbind(self.memory, key, result);

        // Compute уinеренноwithть via норму resultа
        var norm: f64 = 0;
        for (0..dim) |i| {
            norm += @as(f64, @floatFromInt(result[i])) * @as(f64, @floatFromInt(result[i]));
        }
        norm = @sqrt(norm);

        // Нормалandзуем уinеренноwithть
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

    /// Проinерandть onлandчandе toлюча
    pub fn contains(self: *StreamingMemory, key: []const Trit) !bool {
        const result = try self.allocator.alloc(Trit, self.config.dim);
        defer self.allocator.free(result);

        const retrieval = self.retrieve(key, result);
        return retrieval.found;
    }

    /// Прandменandть забыinанandе toо inwithей памятand
    /// M ← (1-λ)M
    pub fn applyForgetting(self: *StreamingMemory, lambda: f64) void {
        for (self.accumulator) |*a| {
            a.* *= (1.0 - lambda);
        }
        hdc.quantizeToTernary(self.accumulator, self.memory);
    }

    /// Уyesлandть toонtoретный toлюч
    /// M ← M - bind(k, retrieve(k))
    pub fn forget(self: *StreamingMemory, key: []const Trit) !void {
        const dim = self.config.dim;
        const retrieved = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(retrieved);

        // Get теtoущее value
        _ = self.retrieve(key, retrieved);

        // Compute bind(key, retrieved)
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);
        hdc.bind(key, retrieved, bound);

        // Вычandтаем andз аtotoумулятора
        for (0..dim) |i| {
            self.accumulator[i] -= @floatFromInt(bound[i]);
        }

        // Кinантandзуем
        hdc.quantizeToTernary(self.accumulator, self.memory);

        if (self.item_count > 0) self.item_count -= 1;
    }

    /// Объедandнandть дinе памятand
    pub fn merge(self: *StreamingMemory, other: *const StreamingMemory) void {
        const dim = @min(self.config.dim, other.config.dim);
        for (0..dim) |i| {
            self.accumulator[i] += other.accumulator[i];
        }
        hdc.quantizeToTernary(self.accumulator, self.memory);
        self.item_count += other.item_count;
    }

    /// Получandть метрandtoand
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

    /// Получandть withырой vector памятand
    pub fn getMemoryVector(self: *const StreamingMemory) []const Trit {
        return self.memory;
    }
};

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ
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

    // Созyesём toлюч and value
    var key = try hdc.randomVector(allocator, 1000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 1000, 22222);
    defer value.deinit();

    // Сохраняем
    try mem.store(key.data, value.data);

    // Extract
    const result_buf = try allocator.alloc(Trit, 1000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);

    // Check withходwithтinо with орandгandonльным зonченandем
    const sim = hdc.similarity(result.value, value.data);
    try std.testing.expect(sim > 0.5);
}

test "multiple items" {
    const allocator = std.testing.allocator;
    // Иwithbyльзуем большую размерноwithть for betterй ёмtoоwithтand
    var mem = try StreamingMemory.init(allocator, .{ .dim = 5000 });
    defer mem.deinit();

    // Сохраняем неwithtoольtoо пар (less for betterго toачеwithтinа)
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

    // Check andзinлеченandе
    const result_buf = try allocator.alloc(Trit, 5000);
    defer allocator.free(result_buf);

    var total_sim: f64 = 0;
    for (0..num_items) |i| {
        const result = mem.retrieve(keys[i].data, result_buf);
        const sim = hdc.similarity(result.value, values[i].data);
        total_sim += sim;
    }

    const avg_sim = total_sim / @as(f64, num_items);
    // HDC memory andмеет огранandченную ёмtoоwithть, ожandyesем хfromя бы byложandтельное withходwithтinо
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

    // Сохраняем
    try mem.store(key.data, value.data);

    const result_buf = try allocator.alloc(Trit, 500);
    defer allocator.free(result_buf);

    // Extract before забыinанandя
    const before = mem.retrieve(key.data, result_buf);
    const conf_before = before.confidence;

    // Прandменяем withandльное забыinанandе
    mem.applyForgetting(0.9);

    // Extract after забыinанandя
    const after = mem.retrieve(key.data, result_buf);
    const conf_after = after.confidence;

    // Уinеренноwithть beforeлжon уменьшandтьwithя
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

    // Сохраняем перinый element
    try mem.storeWithForgetting(key1.data, val1.data, 1.0);

    // Сохраняем inторой with забыinанandем перinого
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

    // Объедandняем
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
