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
