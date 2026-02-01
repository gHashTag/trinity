// Maxwell Daemon - Memory Store
// Долгосрочная память агента для обучения
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Опыт выполнения задачи
pub const Experience = struct {
    id: u64,
    task_type: []const u8,
    task_description: []const u8,
    approach: []const u8,
    outcome: Outcome,
    lessons: std.ArrayList([]const u8),
    duration_ms: u64,
    timestamp: i64,

    pub const Outcome = enum {
        Success,
        Partial,
        Failure,

        pub fn toString(self: Outcome) []const u8 {
            return switch (self) {
                .Success => "success",
                .Partial => "partial",
                .Failure => "failure",
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator) Experience {
        return Experience{
            .id = 0,
            .task_type = "",
            .task_description = "",
            .approach = "",
            .outcome = .Success,
            .lessons = std.ArrayList([]const u8).init(allocator),
            .duration_ms = 0,
            .timestamp = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Experience) void {
        self.lessons.deinit();
    }
};

/// Выученный паттерн
pub const Pattern = struct {
    id: u64,
    name: []const u8,
    trigger: []const u8, // Когда применять
    solution: []const u8, // Что делать
    confidence: f32, // 0.0 - 1.0
    usage_count: u32,
    success_count: u32,
    last_used: i64,

    pub fn successRate(self: *const Pattern) f32 {
        if (self.usage_count == 0) return 0.0;
        return @as(f32, @floatFromInt(self.success_count)) / @as(f32, @floatFromInt(self.usage_count));
    }
};

/// Запись об ошибке
pub const ErrorRecord = struct {
    id: u64,
    error_type: []const u8,
    error_message: []const u8,
    context: []const u8,
    solution_attempted: []const u8,
    resolved: bool,
    timestamp: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY STORE
// ═══════════════════════════════════════════════════════════════════════════════

pub const MemoryStore = struct {
    allocator: std.mem.Allocator,
    
    // Storage
    experiences: std.ArrayList(Experience),
    patterns: std.ArrayList(Pattern),
    errors: std.ArrayList(ErrorRecord),
    
    // Indices for fast lookup
    pattern_by_trigger: std.StringHashMap(u64),
    
    // Counters
    next_experience_id: u64,
    next_pattern_id: u64,
    next_error_id: u64,
    
    // Persistence
    storage_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) MemoryStore {
        return MemoryStore{
            .allocator = allocator,
            .experiences = std.ArrayList(Experience).init(allocator),
            .patterns = std.ArrayList(Pattern).init(allocator),
            .errors = std.ArrayList(ErrorRecord).init(allocator),
            .pattern_by_trigger = std.StringHashMap(u64).init(allocator),
            .next_experience_id = 1,
            .next_pattern_id = 1,
            .next_error_id = 1,
            .storage_path = null,
        };
    }

    pub fn deinit(self: *MemoryStore) void {
        for (self.experiences.items) |*exp| {
            exp.deinit();
        }
        self.experiences.deinit();
        self.patterns.deinit();
        self.errors.deinit();
        self.pattern_by_trigger.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXPERIENCE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Записать опыт
    pub fn recordExperience(self: *MemoryStore, exp: Experience) !u64 {
        var new_exp = exp;
        new_exp.id = self.next_experience_id;
        self.next_experience_id += 1;

        try self.experiences.append(new_exp);

        // Auto-extract patterns from successful experiences
        if (exp.outcome == .Success) {
            try self.extractPattern(&new_exp);
        }

        return new_exp.id;
    }

    /// Найти похожий опыт
    pub fn findSimilarExperience(self: *MemoryStore, task_type: []const u8, keywords: []const []const u8) ?*Experience {
        var best_match: ?*Experience = null;
        var best_score: u32 = 0;

        for (self.experiences.items) |*exp| {
            if (!std.mem.eql(u8, exp.task_type, task_type)) continue;

            var score: u32 = 0;
            for (keywords) |keyword| {
                if (std.mem.indexOf(u8, exp.task_description, keyword) != null) {
                    score += 1;
                }
            }

            if (score > best_score) {
                best_score = score;
                best_match = exp;
            }
        }

        return best_match;
    }

    /// Получить успешные опыты по типу задачи
    pub fn getSuccessfulExperiences(self: *MemoryStore, task_type: []const u8) !std.ArrayList(*Experience) {
        var result = std.ArrayList(*Experience).init(self.allocator);

        for (self.experiences.items) |*exp| {
            if (std.mem.eql(u8, exp.task_type, task_type) and exp.outcome == .Success) {
                try result.append(exp);
            }
        }

        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PATTERNS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Добавить паттерн
    pub fn addPattern(self: *MemoryStore, pattern: Pattern) !u64 {
        var new_pattern = pattern;
        new_pattern.id = self.next_pattern_id;
        self.next_pattern_id += 1;

        try self.patterns.append(new_pattern);
        try self.pattern_by_trigger.put(pattern.trigger, new_pattern.id);

        return new_pattern.id;
    }

    /// Найти паттерн по триггеру
    pub fn findPattern(self: *MemoryStore, trigger: []const u8) ?*Pattern {
        // Exact match
        if (self.pattern_by_trigger.get(trigger)) |id| {
            for (self.patterns.items) |*p| {
                if (p.id == id) return p;
            }
        }

        // Partial match
        for (self.patterns.items) |*p| {
            if (std.mem.indexOf(u8, trigger, p.trigger) != null or
                std.mem.indexOf(u8, p.trigger, trigger) != null)
            {
                return p;
            }
        }

        return null;
    }

    /// Обновить статистику паттерна
    pub fn updatePatternStats(self: *MemoryStore, pattern_id: u64, success: bool) void {
        for (self.patterns.items) |*p| {
            if (p.id == pattern_id) {
                p.usage_count += 1;
                if (success) p.success_count += 1;
                p.last_used = std.time.timestamp();

                // Update confidence based on success rate
                p.confidence = p.successRate();
                return;
            }
        }
    }

    /// Получить лучшие паттерны
    pub fn getTopPatterns(self: *MemoryStore, limit: usize) !std.ArrayList(*Pattern) {
        var result = std.ArrayList(*Pattern).init(self.allocator);

        // Sort by confidence * usage_count
        var sorted = try self.allocator.alloc(*Pattern, self.patterns.items.len);
        defer self.allocator.free(sorted);

        for (self.patterns.items, 0..) |*p, i| {
            sorted[i] = p;
        }

        std.mem.sort(*Pattern, sorted, {}, struct {
            fn lessThan(_: void, a: *Pattern, b: *Pattern) bool {
                const score_a = a.confidence * @as(f32, @floatFromInt(a.usage_count));
                const score_b = b.confidence * @as(f32, @floatFromInt(b.usage_count));
                return score_a > score_b;
            }
        }.lessThan);

        const count = @min(limit, sorted.len);
        for (sorted[0..count]) |p| {
            try result.append(p);
        }

        return result;
    }

    /// Извлечь паттерн из опыта
    fn extractPattern(self: *MemoryStore, exp: *Experience) !void {
        // Simple pattern extraction: task_type -> approach
        const existing = self.findPattern(exp.task_type);
        if (existing != null) return; // Already have a pattern

        const pattern = Pattern{
            .id = 0,
            .name = exp.task_type,
            .trigger = exp.task_type,
            .solution = exp.approach,
            .confidence = 0.5, // Initial confidence
            .usage_count = 1,
            .success_count = 1,
            .last_used = std.time.timestamp(),
        };

        _ = try self.addPattern(pattern);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Записать ошибку
    pub fn recordError(self: *MemoryStore, error_type: []const u8, message: []const u8, context: []const u8) !u64 {
        const record = ErrorRecord{
            .id = self.next_error_id,
            .error_type = error_type,
            .error_message = message,
            .context = context,
            .solution_attempted = "",
            .resolved = false,
            .timestamp = std.time.timestamp(),
        };

        self.next_error_id += 1;
        try self.errors.append(record);

        return record.id;
    }

    /// Найти похожую ошибку (для повторного использования решения)
    pub fn findSimilarError(self: *MemoryStore, error_type: []const u8, message: []const u8) ?*ErrorRecord {
        for (self.errors.items) |*err| {
            if (std.mem.eql(u8, err.error_type, error_type) and
                err.resolved and
                std.mem.indexOf(u8, err.error_message, message) != null)
            {
                return err;
            }
        }
        return null;
    }

    /// Отметить ошибку как решённую
    pub fn resolveError(self: *MemoryStore, error_id: u64, solution: []const u8) void {
        for (self.errors.items) |*err| {
            if (err.id == error_id) {
                err.resolved = true;
                err.solution_attempted = solution;
                return;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PERSISTENCE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Сохранить память в файл
    pub fn save(self: *MemoryStore, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var writer = file.writer();

        // Write header
        try writer.writeAll("MAXWELL_MEMORY_V1\n");

        // Write experiences count
        try writer.print("EXPERIENCES:{d}\n", .{self.experiences.items.len});

        // Write patterns count
        try writer.print("PATTERNS:{d}\n", .{self.patterns.items.len});

        // Write errors count
        try writer.print("ERRORS:{d}\n", .{self.errors.items.len});

        // TODO: Serialize actual data
    }

    /// Загрузить память из файла
    pub fn load(self: *MemoryStore, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch return;
        defer file.close();

        var reader = file.reader();
        var buf: [1024]u8 = undefined;

        // Read header
        const header = reader.readUntilDelimiter(&buf, '\n') catch return;
        if (!std.mem.eql(u8, header, "MAXWELL_MEMORY_V1")) return;

        // TODO: Deserialize actual data
        _ = self;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getStats(self: *MemoryStore) MemoryStats {
        var total_success: u32 = 0;
        var total_failure: u32 = 0;

        for (self.experiences.items) |exp| {
            switch (exp.outcome) {
                .Success => total_success += 1,
                .Failure => total_failure += 1,
                .Partial => {},
            }
        }

        return MemoryStats{
            .total_experiences = @intCast(self.experiences.items.len),
            .total_patterns = @intCast(self.patterns.items.len),
            .total_errors = @intCast(self.errors.items.len),
            .success_rate = if (total_success + total_failure > 0)
                @as(f32, @floatFromInt(total_success)) / @as(f32, @floatFromInt(total_success + total_failure))
            else
                0.0,
        };
    }

    pub const MemoryStats = struct {
        total_experiences: u32,
        total_patterns: u32,
        total_errors: u32,
        success_rate: f32,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MemoryStore init and deinit" {
    var store = MemoryStore.init(std.testing.allocator);
    defer store.deinit();

    try std.testing.expectEqual(@as(usize, 0), store.experiences.items.len);
}

test "MemoryStore record experience" {
    var store = MemoryStore.init(std.testing.allocator);
    defer store.deinit();

    var exp = Experience.init(std.testing.allocator);
    exp.task_type = "feature";
    exp.outcome = .Success;

    const id = try store.recordExperience(exp);
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(@as(usize, 1), store.experiences.items.len);
}

test "MemoryStore pattern matching" {
    var store = MemoryStore.init(std.testing.allocator);
    defer store.deinit();

    const pattern = Pattern{
        .id = 0,
        .name = "crud",
        .trigger = "create delete",
        .solution = "Use CRUD template",
        .confidence = 0.8,
        .usage_count = 5,
        .success_count = 4,
        .last_used = 0,
    };

    _ = try store.addPattern(pattern);

    const found = store.findPattern("create delete");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("crud", found.?.name);
}
