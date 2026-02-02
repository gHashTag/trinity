//! Streaming Memory - Потоковая ассоциативная память на HDC
//!
//! Непрерывное обучение с bind/unbind для key-value хранения.
//! Поддержка forgetting factor для адаптации к concept drift.
//!
//! Научная база:
//! - Holographic Reduced Representations (Plate, 1995)
//! - Sparse Distributed Memory (Kanerva, 1988)
//! - Online Learning with Forgetting
//!
//! Алгоритм:
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
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════

pub const DEFAULT_DIM: usize = 1024;
pub const DEFAULT_FORGETTING_FACTOR: f64 = 0.01;
pub const DEFAULT_RETRIEVAL_THRESHOLD: f64 = 0.5;
pub const DEFAULT_MAX_ITEMS: usize = 10000;

// ═══════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════

/// Конфигурация памяти
pub const MemoryConfig = struct {
    dim: usize = DEFAULT_DIM,
    forgetting_factor: f64 = DEFAULT_FORGETTING_FACTOR,
    retrieval_threshold: f64 = DEFAULT_RETRIEVAL_THRESHOLD,
    max_items: usize = DEFAULT_MAX_ITEMS,
};

/// Результат извлечения
pub const RetrievalResult = struct {
    value: []Trit,
    confidence: f64,
    found: bool,
};

/// Метрики памяти
pub const MemoryMetrics = struct {
    total_writes: u64,
    total_reads: u64,
    item_count: usize,
    avg_confidence: f64,
    memory_utilization: f64,
};

/// Потоковая ассоциативная память
pub const StreamingMemory = struct {
    config: MemoryConfig,
    // Float аккумулятор для плавного обновления
    accumulator: []f64,
    // Квантизованная троичная память
    memory: []Trit,
    // Статистика
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

    /// Сбросить память
    pub fn reset(self: *StreamingMemory) void {
        @memset(self.accumulator, 0.0);
        @memset(self.memory, 0);
        self.item_count = 0;
        self.total_writes = 0;
        self.total_reads = 0;
        self.total_confidence = 0;
    }

    /// Сохранить пару ключ-значение
    /// M ← M + bind(key, value)
    pub fn store(self: *StreamingMemory, key: []const Trit, value: []const Trit) !void {
        const dim = self.config.dim;
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);

        // bind(key, value)
        hdc.bind(key, value, bound);

        // Добавляем к аккумулятору
        for (0..dim) |i| {
            self.accumulator[i] += @floatFromInt(bound[i]);
        }

        // Квантизуем
        hdc.quantizeToTernary(self.accumulator, self.memory);

        self.item_count += 1;
        self.total_writes += 1;
    }

    /// Сохранить с забыванием
    /// M ← (1-λ)M + λ×bind(k,v)
    pub fn storeWithForgetting(self: *StreamingMemory, key: []const Trit, value: []const Trit, lambda: f64) !void {
        const dim = self.config.dim;
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);

        // bind(key, value)
        hdc.bind(key, value, bound);

        // Экспоненциальное забывание + новый элемент
        for (0..dim) |i| {
            self.accumulator[i] = (1.0 - lambda) * self.accumulator[i] + lambda * @as(f64, @floatFromInt(bound[i]));
        }

        // Квантизуем
        hdc.quantizeToTernary(self.accumulator, self.memory);

        self.item_count += 1;
        self.total_writes += 1;
    }

    /// Извлечь значение по ключу
    /// value ≈ unbind(M, key)
    pub fn retrieve(self: *StreamingMemory, key: []const Trit, result: []Trit) RetrievalResult {
        const dim = self.config.dim;

        // unbind(M, key) = bind(M, key) для троичных векторов
        hdc.unbind(self.memory, key, result);

        // Вычисляем уверенность через норму результата
        var norm: f64 = 0;
        for (0..dim) |i| {
            norm += @as(f64, @floatFromInt(result[i])) * @as(f64, @floatFromInt(result[i]));
        }
        norm = @sqrt(norm);

        // Нормализуем уверенность
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

    /// Проверить наличие ключа
    pub fn contains(self: *StreamingMemory, key: []const Trit) !bool {
        const result = try self.allocator.alloc(Trit, self.config.dim);
        defer self.allocator.free(result);

        const retrieval = self.retrieve(key, result);
        return retrieval.found;
    }

    /// Применить забывание ко всей памяти
    /// M ← (1-λ)M
    pub fn applyForgetting(self: *StreamingMemory, lambda: f64) void {
        for (self.accumulator) |*a| {
            a.* *= (1.0 - lambda);
        }
        hdc.quantizeToTernary(self.accumulator, self.memory);
    }

    /// Удалить конкретный ключ
    /// M ← M - bind(k, retrieve(k))
    pub fn forget(self: *StreamingMemory, key: []const Trit) !void {
        const dim = self.config.dim;
        const retrieved = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(retrieved);

        // Получаем текущее значение
        _ = self.retrieve(key, retrieved);

        // Вычисляем bind(key, retrieved)
        const bound = try self.allocator.alloc(Trit, dim);
        defer self.allocator.free(bound);
        hdc.bind(key, retrieved, bound);

        // Вычитаем из аккумулятора
        for (0..dim) |i| {
            self.accumulator[i] -= @floatFromInt(bound[i]);
        }

        // Квантизуем
        hdc.quantizeToTernary(self.accumulator, self.memory);

        if (self.item_count > 0) self.item_count -= 1;
    }

    /// Объединить две памяти
    pub fn merge(self: *StreamingMemory, other: *const StreamingMemory) void {
        const dim = @min(self.config.dim, other.config.dim);
        for (0..dim) |i| {
            self.accumulator[i] += other.accumulator[i];
        }
        hdc.quantizeToTernary(self.accumulator, self.memory);
        self.item_count += other.item_count;
    }

    /// Получить метрики
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

    /// Получить сырой вектор памяти
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

    // Создаём ключ и значение
    var key = try hdc.randomVector(allocator, 1000, 11111);
    defer key.deinit();
    var value = try hdc.randomVector(allocator, 1000, 22222);
    defer value.deinit();

    // Сохраняем
    try mem.store(key.data, value.data);

    // Извлекаем
    const result_buf = try allocator.alloc(Trit, 1000);
    defer allocator.free(result_buf);

    const result = mem.retrieve(key.data, result_buf);

    // Проверяем сходство с оригинальным значением
    const sim = hdc.similarity(result.value, value.data);
    try std.testing.expect(sim > 0.5);
}

test "multiple items" {
    const allocator = std.testing.allocator;
    // Используем большую размерность для лучшей ёмкости
    var mem = try StreamingMemory.init(allocator, .{ .dim = 5000 });
    defer mem.deinit();

    // Сохраняем несколько пар (меньше для лучшего качества)
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

    // Проверяем извлечение
    const result_buf = try allocator.alloc(Trit, 5000);
    defer allocator.free(result_buf);

    var total_sim: f64 = 0;
    for (0..num_items) |i| {
        const result = mem.retrieve(keys[i].data, result_buf);
        const sim = hdc.similarity(result.value, values[i].data);
        total_sim += sim;
    }

    const avg_sim = total_sim / @as(f64, num_items);
    // HDC память имеет ограниченную ёмкость, ожидаем хотя бы положительное сходство
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

    // Извлекаем до забывания
    const before = mem.retrieve(key.data, result_buf);
    const conf_before = before.confidence;

    // Применяем сильное забывание
    mem.applyForgetting(0.9);

    // Извлекаем после забывания
    const after = mem.retrieve(key.data, result_buf);
    const conf_after = after.confidence;

    // Уверенность должна уменьшиться
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

    // Сохраняем первый элемент
    try mem.storeWithForgetting(key1.data, val1.data, 1.0);

    // Сохраняем второй с забыванием первого
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

    // Объединяем
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
