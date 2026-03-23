//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! AMYGDALA — Emotional Salience Detection v1.1 (Optimized)
//!
//! Detects emotionally significant events and prioritizes them.
//! Brain Region: Amygdala (Emotional Processing)
//!
//! v1.1 Optimizations:
//! - Zero-allocation salience analysis
//! - Static pattern matching for critical keywords
//! - Cached realm scores
//! - Performance counters

const std = @import("std");

/// Salience levels from none to critical
pub const SalienceLevel = enum(u3) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
    critical = 4,

    /// Convert numerical score to salience level
    pub fn fromScore(score: f32) SalienceLevel {
        return if (score < 20) .none else if (score < 40) .low else if (score < 60) .medium else if (score < 80) .high else .critical;
    }

    /// Get emoji representation
    pub fn emoji(self: SalienceLevel) []const u8 {
        return switch (self) {
            .none => "⚪",
            .low => "🟢",
            .medium => "🟡",
            .high => "🟠",
            .critical => "🔴",
        };
    }
};

/// Result of salience analysis
pub const EventSalience = struct {
    level: SalienceLevel,
    score: f32,
    reason: []const u8,
};

/// Predefined realm scores (zero-copy lookup)
const RealmScore = struct {
    name: []const u8,
    score: f32,
};

const REALM_SCORES = [_]RealmScore{
    .{ .name = "dukh", .score = 40 },
    .{ .name = "razum", .score = 30 },
    .{ .name = "sattva", .score = 0 },
};

/// Critical keywords with their impact scores
const KeywordScore = struct {
    keyword: []const u8,
    score: f32,
};

const CRITICAL_KEYWORDS = [_]KeywordScore{
    .{ .keyword = "critical", .score = 50 },
    .{ .keyword = "urgent", .score = 30 },
    .{ .keyword = "security", .score = 40 },
    .{ .keyword = "security-patch", .score = 45 },
};

/// Priority level scores
const PriorityScore = struct {
    name: []const u8,
    score: f32,
};

const PRIORITY_SCORES = [_]PriorityScore{
    .{ .name = "critical", .score = 30 },
    .{ .name = "high", .score = 20 },
    .{ .name = "medium", .score = 10 },
    .{ .name = "low", .score = 0 },
    .{ .name = "normal", .score = 0 },
};

/// Error severity patterns
const ErrorPattern = struct {
    pattern: []const u8,
    score: f32,
};

const CRITICAL_ERROR_PATTERNS = [_]ErrorPattern{
    .{ .pattern = "segfault", .score = 30 },
    .{ .pattern = "panic", .score = 30 },
    .{ .pattern = "out of memory", .score = 30 },
    .{ .pattern = "deadlock", .score = 30 },
    .{ .pattern = "corruption", .score = 30 },
    .{ .pattern = "security", .score = 30 },
    .{ .pattern = "authentication", .score = 30 },
    .{ .pattern = "injection", .score = 30 },
};

const HIGH_ERROR_PATTERNS = [_]ErrorPattern{
    .{ .pattern = "timeout", .score = 15 },
    .{ .pattern = "connection refused", .score = 15 },
    .{ .pattern = "not found", .score = 15 },
};

/// Performance statistics for amygdala operations
pub const Stats = struct {
    task_analyses: u64,
    error_analyses: u64,
    critical_events: u64,
};

var global_stats: Stats = .{
    .task_analyses = 0,
    .error_analyses = 0,
    .critical_events = 0,
};

/// Get global amygdala statistics
pub fn getStats() Stats {
    return global_stats;
}

/// Reset global statistics (for testing)
pub fn resetStats() void {
    global_stats = .{
        .task_analyses = 0,
        .error_analyses = 0,
        .critical_events = 0,
    };
}

/// Inline string equality check (avoids std.mem.eql function call overhead)
inline fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

/// Inline substring check (avoids std.mem.indexOf function call overhead)
inline fn contains(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    const max_start = haystack.len - needle.len;
    var i: usize = 0;
    while (i <= max_start) : (i += 1) {
        var j: usize = 0;
        while (j < needle.len) : (j += 1) {
            if (haystack[i + j] != needle[j]) break;
            if (j == needle.len - 1) return true;
        }
    }
    return false;
}

pub const Amygdala = struct {
    const Self = @This();

    /// Zero-allocation task salience analysis
    /// Uses static lookup tables and byte-by-byte comparison
    pub fn analyzeTask(task_id: []const u8, realm: []const u8, priority: []const u8) EventSalience {
        global_stats.task_analyses += 1;

        var score: f32 = 0;

        // Realm score (linear search - small array)
        inline for (REALM_SCORES) |realm_entry| {
            if (strEql(realm, realm_entry.name)) {
                score += realm_entry.score;
                break;
            }
        }

        // Critical keyword matching (case-sensitive substring search)
        for (CRITICAL_KEYWORDS) |keyword_entry| {
            if (contains(task_id, keyword_entry.keyword)) {
                score += keyword_entry.score;
            }
        }

        // Priority score (linear search - small array)
        inline for (PRIORITY_SCORES) |priority_entry| {
            if (strEql(priority, priority_entry.name)) {
                score += priority_entry.score;
                break;
            }
        }

        // Cap at 100
        if (score > 100) score = 100;

        const level = SalienceLevel.fromScore(score);
        if (level == .critical) {
            global_stats.critical_events += 1;
        }

        return .{
            .level = level,
            .score = score,
            .reason = "Computed from realm/priority/task",
        };
    }

    /// Zero-allocation error salience analysis
    pub fn analyzeError(err_msg: []const u8) EventSalience {
        global_stats.error_analyses += 1;

        var score: f32 = 20; // Base score for any error

        // Critical error patterns
        for (CRITICAL_ERROR_PATTERNS) |pattern| {
            if (contains(err_msg, pattern.pattern)) {
                score += pattern.score;
            }
        }

        // High severity patterns
        for (HIGH_ERROR_PATTERNS) |pattern| {
            if (contains(err_msg, pattern.pattern)) {
                score += pattern.score;
            }
        }

        // Cap at 100
        if (score > 100) score = 100;

        const level = SalienceLevel.fromScore(score);
        if (level == .critical) {
            global_stats.critical_events += 1;
        }

        return .{
            .level = level,
            .score = score,
            .reason = "Error severity",
        };
    }

    /// Check if event requires immediate attention
    pub fn requiresAttention(salience: EventSalience) bool {
        return salience.level == .critical or salience.level == .high;
    }

    /// Get urgency score (0-1, higher = more urgent)
    pub fn urgency(salience: EventSalience) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(salience.level))) / 4.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Optimized Amygdala task analysis" {
    const result = Amygdala.analyzeTask("urgent-security-fix", "dukh", "high");
    try std.testing.expect(result.score > 50);
    try std.testing.expect(result.level == .critical or result.level == .high);
}

test "Optimized Amygdala error analysis" {
    resetStats(); // Clear stats before test

    const result = Amygdala.analyzeError("segfault in critical module");
    try std.testing.expect(result.score >= 50); // Base 20 + segfault 30
    // segfault alone = 50 = .medium, which requires attention check
    try std.testing.expectEqual(SalienceLevel.medium, result.level);
}

test "Optimized Amygdala critical error analysis" {
    resetStats(); // Clear stats before test

    // Error with segfault (30) + timeout (15) = 65 -> should be .high
    // Timeout is a HIGH pattern worth 15 points
    const result = Amygdala.analyzeError("segfault with timeout");
    try std.testing.expect(result.score >= 65);
    try std.testing.expectEqual(SalienceLevel.high, result.level);
}

test "Optimized Amygdala stats tracking" {
    // Reset stats first
    resetStats();

    const initial_stats = getStats();
    try std.testing.expectEqual(@as(u64, 0), initial_stats.task_analyses);

    // Analyze some tasks
    _ = Amygdala.analyzeTask("task-1", "dukh", "high");
    _ = Amygdala.analyzeError("segfault");

    const final_stats = getStats();
    try std.testing.expectEqual(@as(u64, 1), final_stats.task_analyses);
    try std.testing.expectEqual(@as(u64, 1), final_stats.error_analyses);
}

test "Optimized Amygdala score capping" {
    const result = Amygdala.analyzeTask("urgent-critical-security-fix", "dukh", "critical");
    try std.testing.expect(result.score <= 100);
}

test "Optimized Amygdala empty input handling" {
    const result = Amygdala.analyzeTask("", "", "");
    try std.testing.expect(result.score >= 0);
    try std.testing.expect(result.level == .none);
}

test "Optimized Amygdala score boundaries" {
    const none_result = Amygdala.analyzeTask("task", "sattva", "normal");
    try std.testing.expect(none_result.score < 20);
    try std.testing.expect(none_result.level == .none);

    const critical_result = Amygdala.analyzeTask("critical-urgent-security", "dukh", "critical");
    try std.testing.expect(critical_result.level == .critical);
}

test "Optimized Amygdala SalienceLevel fromScore boundaries" {
    try std.testing.expectEqual(SalienceLevel.none, SalienceLevel.fromScore(0));
    try std.testing.expectEqual(SalienceLevel.none, SalienceLevel.fromScore(19.9));
    try std.testing.expectEqual(SalienceLevel.low, SalienceLevel.fromScore(20));
    try std.testing.expectEqual(SalienceLevel.low, SalienceLevel.fromScore(39.9));
    try std.testing.expectEqual(SalienceLevel.medium, SalienceLevel.fromScore(40));
    try std.testing.expectEqual(SalienceLevel.medium, SalienceLevel.fromScore(59.9));
    try std.testing.expectEqual(SalienceLevel.high, SalienceLevel.fromScore(60));
    try std.testing.expectEqual(SalienceLevel.high, SalienceLevel.fromScore(79.9));
    try std.testing.expectEqual(SalienceLevel.critical, SalienceLevel.fromScore(80));
    try std.testing.expectEqual(SalienceLevel.critical, SalienceLevel.fromScore(100));
}

test "Optimized Amygdala SalienceLevel emoji" {
    try std.testing.expectEqualStrings("⚪", SalienceLevel.none.emoji());
    try std.testing.expectEqualStrings("🟢", SalienceLevel.low.emoji());
    try std.testing.expectEqualStrings("🟡", SalienceLevel.medium.emoji());
    try std.testing.expectEqualStrings("🟠", SalienceLevel.high.emoji());
    try std.testing.expectEqualStrings("🔴", SalienceLevel.critical.emoji());
}

test "Optimized Amygdala strEql function" {
    const a = "hello";
    const b = "hello";
    const c = "world";
    const d: []const u8 = "";

    try std.testing.expect(strEql(a, b));
    try std.testing.expect(!strEql(a, c));
    try std.testing.expect(strEql(d, d));
    try std.testing.expect(!strEql("", "x"));
}

test "Optimized Amygdala contains function" {
    const haystack = "The quick brown fox jumps";
    try std.testing.expect(contains(haystack, "quick"));
    try std.testing.expect(contains(haystack, "The"));
    try std.testing.expect(contains(haystack, "jumps"));
    try std.testing.expect(!contains(haystack, "lazy"));
    try std.testing.expect(contains(haystack, "")); // Empty needle is always true
    try std.testing.expect(!contains("", "needle")); // Empty haystack with non-empty needle
}

test "Optimized Amygdala requiresAttention" {
    const none_salience = EventSalience{ .level = .none, .score = 0, .reason = "" };
    const low_salience = EventSalience{ .level = .low, .score = 20, .reason = "" };
    const medium_salience = EventSalience{ .level = .medium, .score = 40, .reason = "" };
    const high_salience = EventSalience{ .level = .high, .score = 70, .reason = "" };
    const critical_salience = EventSalience{ .level = .critical, .score = 90, .reason = "" };

    try std.testing.expect(!Amygdala.requiresAttention(none_salience));
    try std.testing.expect(!Amygdala.requiresAttention(low_salience));
    try std.testing.expect(!Amygdala.requiresAttention(medium_salience));
    try std.testing.expect(Amygdala.requiresAttention(high_salience));
    try std.testing.expect(Amygdala.requiresAttention(critical_salience));
}

test "Optimized Amygdala urgency score" {
    const none_salience = EventSalience{ .level = .none, .score = 0, .reason = "" };
    const low_salience = EventSalience{ .level = .low, .score = 20, .reason = "" };
    const medium_salience = EventSalience{ .level = .medium, .score = 40, .reason = "" };
    const high_salience = EventSalience{ .level = .high, .score = 70, .reason = "" };
    const critical_salience = EventSalience{ .level = .critical, .score = 90, .reason = "" };

    try std.testing.expectEqual(@as(f32, 0.0), Amygdala.urgency(none_salience));
    try std.testing.expectEqual(@as(f32, 0.25), Amygdala.urgency(low_salience));
    try std.testing.expectEqual(@as(f32, 0.5), Amygdala.urgency(medium_salience));
    try std.testing.expectEqual(@as(f32, 0.75), Amygdala.urgency(high_salience));
    try std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical_salience));
}

test "Optimized Amygdala realm scoring" {
    const sattva = Amygdala.analyzeTask("task", "sattva", "normal");
    try std.testing.expectEqual(@as(f32, 0), sattva.score);

    const razum = Amygdala.analyzeTask("task", "razum", "normal");
    try std.testing.expectEqual(@as(f32, 30), razum.score);

    const dukh = Amygdala.analyzeTask("task", "dukh", "normal");
    try std.testing.expectEqual(@as(f32, 40), dukh.score);
}

test "Optimized Amygdala priority scoring" {
    const normal = Amygdala.analyzeTask("task", "sattva", "normal");
    try std.testing.expectEqual(@as(f32, 0), normal.score);

    const low = Amygdala.analyzeTask("task", "sattva", "low");
    try std.testing.expectEqual(@as(f32, 0), low.score);

    const medium = Amygdala.analyzeTask("task", "sattva", "medium");
    try std.testing.expectEqual(@as(f32, 10), medium.score);

    const high = Amygdala.analyzeTask("task", "sattva", "high");
    try std.testing.expectEqual(@as(f32, 20), high.score);

    const critical_priority = Amygdala.analyzeTask("task", "sattva", "critical");
    try std.testing.expectEqual(@as(f32, 30), critical_priority.score);
}

test "Optimized Amygdala keyword detection" {
    const no_keyword = Amygdala.analyzeTask("task-123", "sattva", "normal");
    try std.testing.expectEqual(@as(f32, 0), no_keyword.score);

    const critical_keyword = Amygdala.analyzeTask("critical-task", "sattva", "normal");
    try std.testing.expectEqual(@as(f32, 50), critical_keyword.score);

    const urgent_keyword = Amygdala.analyzeTask("urgent-task", "sattva", "normal");
    try std.testing.expectEqual(@as(f32, 30), urgent_keyword.score);

    const security_keyword = Amygdala.analyzeTask("security-task", "sattva", "normal");
    try std.testing.expectEqual(@as(f32, 40), security_keyword.score);

    const security_patch = Amygdala.analyzeTask("security-patch-task", "sattva", "normal");
    // "security-patch-task" matches both "security" (40) and "security-patch" (45) = 85
    try std.testing.expectEqual(@as(f32, 85), security_patch.score);

    const multiple_keywords = Amygdala.analyzeTask("critical-urgent-security", "sattva", "normal");
    // 50 + 30 + 40 = 120, but capped at 100
    try std.testing.expectEqual(@as(f32, 100), multiple_keywords.score);
}

test "Optimized Amygdala error pattern detection" {
    const simple_error = Amygdala.analyzeError("something failed");
    try std.testing.expectEqual(@as(f32, 20), simple_error.score);
    // Score 20 < 40, so level is .low, not .medium
    try std.testing.expectEqual(SalienceLevel.low, simple_error.level);

    const segfault = Amygdala.analyzeError("segfault occurred");
    try std.testing.expectEqual(@as(f32, 50), segfault.score);
    // Score 50 < 60, so level is .medium, not .high
    try std.testing.expectEqual(SalienceLevel.medium, segfault.level);

    const panic = Amygdala.analyzeError("panic: index out of bounds");
    try std.testing.expectEqual(@as(f32, 50), panic.score);

    const out_of_memory = Amygdala.analyzeError("out of memory");
    try std.testing.expectEqual(@as(f32, 50), out_of_memory.score);

    const deadlock = Amygdala.analyzeError("deadlock detected");
    try std.testing.expectEqual(@as(f32, 50), deadlock.score);

    const corruption = Amygdala.analyzeError("data corruption detected");
    try std.testing.expectEqual(@as(f32, 50), corruption.score);

    const timeout = Amygdala.analyzeError("operation timeout");
    try std.testing.expectEqual(@as(f32, 35), timeout.score);
    // Score 35 < 40, so level is .low, not .medium
    try std.testing.expectEqual(SalienceLevel.low, timeout.level);

    const connection_refused = Amygdala.analyzeError("connection refused");
    try std.testing.expectEqual(@as(f32, 35), connection_refused.score);
}

test "Optimized Amygdala complex error patterns" {
    const segfault_timeout = Amygdala.analyzeError("segfault during timeout");
    try std.testing.expectEqual(@as(f32, 65), segfault_timeout.score); // 20 + 30 + 15
    try std.testing.expectEqual(SalienceLevel.high, segfault_timeout.level);

    const panic_injection = Amygdala.analyzeError("panic: sql injection detected");
    try std.testing.expectEqual(@as(f32, 80), panic_injection.score); // 20 + 30 + 30
    // Score 80 >= 80, so level is .critical, not .high
    try std.testing.expectEqual(SalienceLevel.critical, panic_injection.level);

    const security_corruption = Amygdala.analyzeError("security: memory corruption");
    try std.testing.expectEqual(@as(f32, 80), security_corruption.score);
}

test "Optimized Amygdala resetStats" {
    resetStats();
    _ = Amygdala.analyzeTask("task1", "dukh", "high");
    _ = Amygdala.analyzeError("error1");
    _ = Amygdala.analyzeTask("critical-task", "dukh", "critical");

    const before_reset = getStats();
    try std.testing.expect(before_reset.task_analyses > 0);
    try std.testing.expect(before_reset.error_analyses > 0);
    try std.testing.expect(before_reset.critical_events > 0);

    resetStats();

    const after_reset = getStats();
    try std.testing.expectEqual(@as(u64, 0), after_reset.task_analyses);
    try std.testing.expectEqual(@as(u64, 0), after_reset.error_analyses);
    try std.testing.expectEqual(@as(u64, 0), after_reset.critical_events);
}

// Performance benchmark
test "perf.benchmark.amygdala" {
    const iterations = 1_000_000;
    const start = std.time.nanoTimestamp();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        _ = Amygdala.analyzeTask("task-urgent", "dukh", "critical");
    }

    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    _ = std.debug.print("  Optimized Amygdala: {d:.0} OP/s ({d:.2} ns/op)\n", .{
        @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0),
        ns_per_op,
    });
}
