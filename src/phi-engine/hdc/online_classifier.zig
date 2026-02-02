//! Online HDC Classifier - Самообучающийся классификатор
//! на основе гиперразмерных вычислений с онлайн-обновлением.
//!
//! Алгоритм:
//! 1. Кодирование входа в гипервектор
//! 2. Поиск ближайшего прототипа
//! 3. Онлайн обновление: P ← P + η(v - P)
//! 4. Квантизация в троичное представление
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const hdc = @import("hdc_core.zig");

pub const Trit = hdc.Trit;
pub const HyperVector = hdc.HyperVector;

/// Конфигурация классификатора
pub const ClassifierConfig = struct {
    dim: usize = hdc.DEFAULT_DIM,
    learning_rate: f64 = hdc.LEARNING_RATE,
    similarity_threshold: f64 = hdc.SIMILARITY_THRESHOLD,
    max_prototypes: usize = 1000,
};

/// Прототип класса с онлайн-обновлением
pub const ClassPrototype = struct {
    label: []const u8,
    accumulator: []f64,
    vector: []Trit,
    sample_count: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, label: []const u8, dim: usize) !ClassPrototype {
        const acc = try allocator.alloc(f64, dim);
        @memset(acc, 0.0);
        const vec = try allocator.alloc(Trit, dim);
        @memset(vec, 0);
        const label_copy = try allocator.dupe(u8, label);

        return .{
            .label = label_copy,
            .accumulator = acc,
            .vector = vec,
            .sample_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ClassPrototype) void {
        self.allocator.free(self.accumulator);
        self.allocator.free(self.vector);
        self.allocator.free(@constCast(self.label));
    }

    /// Онлайн обновление прототипа
    pub fn update(self: *ClassPrototype, input: []const Trit, lr: f64) void {
        hdc.onlineUpdate(self.accumulator, input, lr);
        hdc.quantizeToTernary(self.accumulator, self.vector);
        self.sample_count += 1;
    }
};

/// Результат предсказания
pub const PredictionResult = struct {
    label: []const u8,
    confidence: f64,
    is_new_class: bool,
};

/// Метрики обучения
pub const LearningMetrics = struct {
    samples_seen: u64,
    num_prototypes: usize,
    avg_confidence: f64,
    last_accuracy: f64,
};

/// Онлайн HDC классификатор
pub const OnlineClassifier = struct {
    config: ClassifierConfig,
    prototypes: std.StringHashMap(ClassPrototype),
    dim: usize,
    samples_seen: u64,
    correct_predictions: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: ClassifierConfig) OnlineClassifier {
        return .{
            .config = config,
            .prototypes = std.StringHashMap(ClassPrototype).init(allocator),
            .dim = config.dim,
            .samples_seen = 0,
            .correct_predictions = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OnlineClassifier) void {
        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            var proto = entry.value_ptr;
            proto.deinit();
        }
        self.prototypes.deinit();
    }

    /// Предсказание класса
    pub fn predict(self: *OnlineClassifier, input: []const Trit) PredictionResult {
        var best_sim: f64 = -2.0;
        var best_label: []const u8 = "";

        var iter = self.prototypes.iterator();
        while (iter.next()) |entry| {
            const sim = hdc.similarity(input, entry.value_ptr.vector);
            if (sim > best_sim) {
                best_sim = sim;
                best_label = entry.key_ptr.*;
            }
        }

        if (best_sim < self.config.similarity_threshold) {
            return .{
                .label = "",
                .confidence = 0.0,
                .is_new_class = true,
            };
        }

        return .{
            .label = best_label,
            .confidence = best_sim,
            .is_new_class = false,
        };
    }

    /// Обучение на размеченном примере
    pub fn train(self: *OnlineClassifier, input: []const Trit, label: []const u8) !void {
        self.samples_seen += 1;

        if (self.prototypes.getPtr(label)) |proto| {
            proto.update(input, self.config.learning_rate);
        } else {
            var new_proto = try ClassPrototype.init(self.allocator, label, self.dim);
            new_proto.update(input, 1.0); // Первый пример - полное обновление
            try self.prototypes.put(label, new_proto);
        }
    }

    /// Самообучение на неразмеченном примере
    pub fn trainUnlabeled(self: *OnlineClassifier, input: []const Trit) !void {
        const pred = self.predict(input);

        if (!pred.is_new_class and pred.confidence > self.config.similarity_threshold) {
            if (self.prototypes.getPtr(pred.label)) |proto| {
                proto.update(input, self.config.learning_rate * 0.5);
            }
        }
    }

    /// Получить метрики
    pub fn getMetrics(self: *OnlineClassifier) LearningMetrics {
        const total_conf: f64 = 0.0;
        var count: usize = 0;

        var iter = self.prototypes.iterator();
        while (iter.next()) |_| {
            count += 1;
        }

        const accuracy = if (self.samples_seen > 0)
            @as(f64, @floatFromInt(self.correct_predictions)) / @as(f64, @floatFromInt(self.samples_seen))
        else
            0.0;

        return .{
            .samples_seen = self.samples_seen,
            .num_prototypes = count,
            .avg_confidence = if (count > 0) total_conf / @as(f64, @floatFromInt(count)) else 0.0,
            .last_accuracy = accuracy,
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// КОДИРОВАНИЕ ВХОДНЫХ ДАННЫХ
// ═══════════════════════════════════════════════════════════════

/// Кодирование байтов в гипервектор
pub fn encodeBytes(allocator: std.mem.Allocator, data: []const u8, dim: usize) !HyperVector {
    const result = try hdc.zeroVector(allocator, dim);

    // Используем хеширование для создания детерминированного вектора
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(data);
    const hash = hasher.final();

    var rng = std.Random.DefaultPrng.init(hash);
    const random = rng.random();

    for (result.data) |*t| {
        t.* = @as(Trit, @intCast(random.intRangeAtMost(i8, -1, 1)));
    }

    return result;
}

/// Кодирование последовательности с позиционным binding
pub fn encodeSequence(allocator: std.mem.Allocator, tokens: []const []const u8, dim: usize) !HyperVector {
    var result = try hdc.zeroVector(allocator, dim);
    var temp = try hdc.HyperVector.init(allocator, dim);
    defer temp.deinit();
    var permuted = try hdc.HyperVector.init(allocator, dim);
    defer permuted.deinit();

    for (tokens, 0..) |token, pos| {
        var token_vec = try encodeBytes(allocator, token, dim);
        defer token_vec.deinit();

        hdc.permute(token_vec.data, pos, permuted.data);

        // Накапливаем
        for (0..dim) |i| {
            const sum: i16 = @as(i16, result.data[i]) + @as(i16, permuted.data[i]);
            if (sum > 1) {
                result.data[i] = 1;
            } else if (sum < -1) {
                result.data[i] = -1;
            } else {
                result.data[i] = @intCast(sum);
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════

test "classifier init/deinit" {
    const allocator = std.testing.allocator;
    var clf = OnlineClassifier.init(allocator, .{ .dim = 100 });
    defer clf.deinit();

    try std.testing.expectEqual(@as(usize, 100), clf.dim);
    try std.testing.expectEqual(@as(u64, 0), clf.samples_seen);
}

test "classifier train and predict" {
    const allocator = std.testing.allocator;
    var clf = OnlineClassifier.init(allocator, .{ .dim = 100 });
    defer clf.deinit();

    // Создаём тренировочные данные
    var class_a = try hdc.randomVector(allocator, 100, 11111);
    defer class_a.deinit();
    var class_b = try hdc.randomVector(allocator, 100, 22222);
    defer class_b.deinit();

    // Обучаем
    try clf.train(class_a.data, "class_a");
    try clf.train(class_b.data, "class_b");

    // Предсказываем
    const pred_a = clf.predict(class_a.data);
    try std.testing.expectEqualStrings("class_a", pred_a.label);
    try std.testing.expect(pred_a.confidence > 0.5);
}

test "encode bytes deterministic" {
    const allocator = std.testing.allocator;
    const data = "hello world";

    var vec1 = try encodeBytes(allocator, data, 100);
    defer vec1.deinit();
    var vec2 = try encodeBytes(allocator, data, 100);
    defer vec2.deinit();

    const sim = hdc.similarity(vec1.data, vec2.data);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "online learning improves" {
    const allocator = std.testing.allocator;
    var clf = OnlineClassifier.init(allocator, .{ .dim = 100, .learning_rate = 0.1 });
    defer clf.deinit();

    // Создаём прототип класса
    var proto = try hdc.randomVector(allocator, 100, 33333);
    defer proto.deinit();

    // Обучаем несколько раз
    for (0..10) |_| {
        try clf.train(proto.data, "test_class");
    }

    // Проверяем что прототип стал похож на входные данные
    const pred = clf.predict(proto.data);
    try std.testing.expect(pred.confidence > 0.8);
}
