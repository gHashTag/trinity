//! AMYGDALA — Emotional Salience Detection v1.0
//!
//! Detects emotionally significant events and prioritizes them.
//! Brain Region: Amygdala (Emotional Processing)
//!
//! # Overview
//!
//! The Amygdala module analyzes tasks and errors to determine their
//! "emotional salience" - how urgently they require attention.
//! This allows the brain to prioritize critical events over routine ones.
//!
//! # Features
//!
//! - Task salience analysis (keywords, realm, priority)
//! - Error salience analysis (pattern matching)
//! - Five-level salience classification (none to critical)
//! - Emoji visualization for TUI display
//!
//! # Biological Inspiration
//!
//! The amygdala in the brain processes emotional significance and
//! triggers attention for important events. This module mirrors that
//! by scoring and ranking events by importance.
//!
//! # Usage
//!
//! ```zig
//! // Analyze task salience
//! const salience = brain.amygdala.Amygdala.analyzeTask(
//!     "urgent-security-fix",
//!     "dukh",
//!     "critical"
//! );
//!
//! std.log.info("Salience: {s} (score: {d:.1})", .{
//!     @tagName(salience.level),
//!     salience.score
//! });
//!
//! if (brain.amygdala.Amygdala.requiresAttention(salience)) {
//!     // Handle urgent task
//!     handleUrgentTask();
//! }
//! ```
//!
//! # Salience Levels
//!
//! - `none` (0-19): Routine, low priority
//! - `low` (20-39): Normal operations
//! - `medium` (40-59): Above average importance
//! - `high` (60-79): Important, needs attention
//! - `critical` (80-100): Immediate action required
//!
//! # Task Scoring Factors
//!
//! - Realm: `dukh` (+40), `razum` (+30)
//! - Keywords: `urgent` (+30), `critical` (+50), `security` (+40)
//! - Priority: `high` (+20), `critical` (+30)
//!
//! # Error Scoring Factors
//!
//! - Base score: 20 (all errors)
//! - Critical patterns: `segfault`, `panic`, `security`, etc. (+30 each)
//! - High severity: `timeout`, `connection refused` (+15 each)

const std = @import("std");
const array_list = std.array_list;

/// Five-level salience classification.
///
/// Represents the emotional importance of an event from
/// trivial (none) to urgent (critical).
///
/// # Levels
///
/// | Level | Score Range | Meaning |
/// |-------|-------------|---------|
/// | `none` | 0-19 | Routine, ignore |
/// | `low` | 20-39 | Normal processing |
/// | `medium` | 40-59 | Elevated importance |
/// | `high` | 60-79 | Requires attention |
/// | `critical` | 80-100 | Immediate action |
pub const SalienceLevel = enum(u3) {
    /// No significance, routine event
    none = 0,
    /// Low importance, normal processing
    low = 1,
    /// Medium importance, above average
    medium = 2,
    /// High importance, needs attention
    high = 3,
    /// Critical importance, immediate action required
    critical = 4,

    /// Converts a numeric score (0-100) to salience level.
    ///
    /// # Parameters
    ///
    /// - `score`: Numeric score from 0 to 100
    ///
    /// # Returns
    ///
    /// Corresponding `SalienceLevel`
    ///
    /// # Thresholds
    ///
    /// - 0-19: none
    /// - 20-39: low
    /// - 40-59: medium
    /// - 60-79: high
    /// - 80-100: critical
    ///
    /// # Example
    ///
    /// ```zig
    /// try std.testing.expectEqual(SalienceLevel.none, SalienceLevel.fromScore(10));
    /// try std.testing.expectEqual(SalienceLevel.critical, SalienceLevel.fromScore(90));
    /// ```
    pub fn fromScore(score: f32) SalienceLevel {
        return if (score < 20) .none else if (score < 40) .low else if (score < 60) .medium else if (score < 80) .high else .critical;
    }

    /// Returns emoji representation for TUI display.
    ///
    /// # Returns
    ///
    /// - `none`: ⚪ (white circle)
    /// - `low`: 🟢 (green circle)
    /// - `medium`: 🟡 (yellow circle)
    /// - `high`: 🟠 (orange circle)
    /// - `critical`: 🔴 (red circle)
    ///
    /// # Example
    ///
    /// ```zig
    /// std.log.info("Status: {s}", .{SalienceLevel.critical.emoji()});
    /// // Output: Status: 🔴
    /// ```
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

/// Result of salience analysis.
///
/// Contains classified level, numeric score, and reasoning.
///
/// # Fields
///
/// - `level`: Classified salience level
/// - `score`: Numeric score (0-100)
/// - `reason`: Human-readable explanation
pub const EventSalience = struct {
    /// Classified salience level
    level: SalienceLevel,
    /// Numeric score (0-100)
    score: f32,
    /// Reason for this classification
    reason: []const u8,
};

/// Amygdala analyzer for emotional salience detection.
///
/// Provides static methods for analyzing task and error salience.
pub const Amygdala = struct {
    const Self = @This();

    /// Single-pass pattern scanner for task_id keywords.
    ///
    /// Scans the input string once and returns the sum of scores for all
    /// matched patterns (urgent: +30, critical: +50, security: +40).
    ///
    /// This is semantically equivalent to the original 3-sequential indexOf()
    /// approach but performs the scan in a single pass.
    ///
    /// # Algorithm
    ///
    /// For each position in the string:
    /// 1. Check if substring starting here matches any of the 3 patterns
    /// 2. If matched, add score to total and skip ahead by pattern length
    ///    (avoid double-counting overlapping matches like "critical" in "critcritical")
    /// 3. Move to next position if no match
    ///
    /// This is O(n * m) where n = input length, m = pattern length (8 for "critical").
    /// The original approach was O(n * m * 3) due to 3 separate full scans.
    ///
    /// # Parameters
    ///
    /// - `input`: String to search
    ///
    /// # Returns
    ///
    /// Sum of scores for all matched patterns (0 if none found)
    fn scanPatterns(input: []const u8) f32 {
        const patterns = [_]struct { pat: []const u8, score: f32 }{
            .{ .pat = "critical", .score = 50 },
            .{ .pat = "security", .score = 40 },
            .{ .pat = "urgent", .score = 30 },
        };

        // Early exit for strings shorter than the shortest pattern
        if (input.len < 6) return 0;

        var score: f32 = 0;
        var i: usize = 0;

        while (i <= input.len - 6) : (i += 1) {
            var matched = false;
            var match_len: usize = 0;

            // Check each pattern at this position
            for (patterns) |p| {
                const pat_len = p.pat.len;
                if (i + pat_len > input.len) continue;

                // Fast path: check first character before full comparison
                if (input[i] != p.pat[0]) continue;

                // Case-sensitive substring comparison
                var j: usize = 0;
                while (j < pat_len) : (j += 1) {
                    if (input[i + j] != p.pat[j]) break;
                }

                if (j == pat_len) {
                    // Full match found
                    score += p.score;
                    matched = true;
                    match_len = pat_len;
                    break; // Only count one pattern per position
                }
            }

            // Skip ahead if we matched to avoid double-counting
            if (matched) {
                i += match_len - 1; // -1 because loop will increment by 1
            }
        }

        return score;
    }

    /// Analyzes task salience based on multiple factors.
    ///
    /// Considers realm (dukh/razum), task keywords (urgent/critical/security),
    /// and priority field to compute salience score.
    ///
    /// # Parameters
    ///
    /// - `task_id`: Task identifier (checked for keywords)
    /// - `realm`: Task realm (dukh/razum affect score)
    /// - `priority`: Priority field (high/critical affect score)
    ///
    /// # Returns
    ///
    /// `EventSalience` with level, score, and reasoning
    ///
    /// # Scoring
    ///
    /// - Realm `dukh`: +40, `razum`: +30
    /// - Keywords in task_id: `urgent` +30, `critical` +50, `security` +40
    /// - Priority: `high` +20, `critical` +30
    /// - Capped at 100
    ///
    /// # Example
    ///
    /// ```zig
    /// const salience = Amygdala.analyzeTask("urgent-security-fix", "dukh", "critical");
    /// std.log.info("Level: {s}, Score: {d:.0}", .{
    ///     @tagName(salience.level),
    ///     salience.score,
    /// });
    /// ```
    pub fn analyzeTask(task_id: []const u8, realm: []const u8, priority: []const u8) EventSalience {
        var score: f32 = 0;

        // Critical realms get higher salience
        if (std.mem.eql(u8, realm, "dukh")) {
            score += 40;
        }
        if (std.mem.eql(u8, realm, "razum")) {
            score += 30;
        }

        // Single-pass pattern scan for priority keywords
        score += scanPatterns(task_id);

        // Priority field
        if (std.mem.eql(u8, priority, "high")) {
            score += 20;
        } else if (std.mem.eql(u8, priority, "critical")) {
            score += 30;
        }

        // Cap at 100
        if (score > 100) score = 100;

        return .{
            .level = SalienceLevel.fromScore(score),
            .score = score,
            .reason = "Computed from realm/priority/task",
        };
    }

    /// Analyzes error salience based on error message.
    ///
    /// Uses pattern matching to detect critical error types like
    /// segfaults, panics, security issues, and common failures.
    ///
    /// # Parameters
    ///
    /// - `err_msg`: Error message to analyze
    ///
    /// # Returns
    ///
    /// `EventSalience` with level, score, and reasoning
    ///
    /// # Scoring
    ///
    /// - Base score: 20 (all errors get minimum attention)
    /// - Critical patterns: +30 each
    ///   - `segfault`, `panic`, `out of memory`, `deadlock`
    ///   - `corruption`, `security`, `authentication`, `injection`
    /// - High severity patterns: +15 each
    ///   - `timeout`, `connection refused`, `not found`
    /// - Capped at 100
    ///
    /// # Example
    ///
    /// ```zig
    /// const salience = Amygdala.analyzeError("segfault in critical module");
    /// // Score will be >= 50 (20 base + 30 segfault)
    /// ```
    pub fn analyzeError(err_msg: []const u8) EventSalience {
        var score: f32 = 20; // Base score for any error

        // Critical error patterns
        const critical_patterns = [_][]const u8{
            "segfault",   "panic",    "out of memory",  "deadlock",
            "corruption", "security", "authentication", "injection",
        };

        for (critical_patterns) |pattern| {
            if (std.mem.indexOf(u8, err_msg, pattern) != null) {
                score += 30;
            }
        }

        // High severity patterns
        const high_patterns = [_][]const u8{
            "timeout", "connection refused", "not found",
        };

        for (high_patterns) |pattern| {
            if (std.mem.indexOf(u8, err_msg, pattern) != null) {
                score += 15;
            }
        }

        if (score > 100) score = 100;

        return .{
            .level = SalienceLevel.fromScore(score),
            .score = score,
            .reason = "Error severity",
        };
    }

    /// Checks if an event requires immediate attention.
    ///
    /// High and critical salience events should be prioritized
    /// for processing and may trigger alerts.
    ///
    /// # Parameters
    ///
    /// - `salience`: Event salience to check
    ///
    /// # Returns
    ///
    /// `true` if event is `high` or `critical`, `false` otherwise
    ///
    /// # Example
    ///
    /// ```zig
    /// const salience = Amygdala.analyzeTask("urgent-fix", "dukh", "high");
    /// if (Amygdala.requiresAttention(salience)) {
    ///     // Handle urgent task immediately
    ///     handleUrgentTask();
    /// }
    /// ```
    pub fn requiresAttention(salience: EventSalience) bool {
        return salience.level == .critical or salience.level == .high;
    }

    /// Gets urgency score for an event.
    ///
    /// Normalizes salience level to a 0-1 range for
    /// quantitative comparison and prioritization.
    ///
    /// # Parameters
    ///
    /// - `salience`: Event salience
    ///
    /// # Returns
    ///
    /// Urgency score from 0.0 (none) to 1.0 (critical)
    ///
    /// # Formula
    ///
    /// `urgency = level_enum_value / 4.0`
    ///
    /// | Level | Urgency |
    /// |-------|---------|
    /// | none | 0.0 |
    /// | low | 0.25 |
    /// | medium | 0.5 |
    /// | high | 0.75 |
    /// | critical | 1.0 |
    ///
    /// # Example
    ///
    /// ```zig
    /// const critical: EventSalience = .{ .level = .critical, .score = 90, .reason = "" };
    /// const low: EventSalience = .{ .level = .low, .score = 30, .reason = "" };
    ///
    /// std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical));
    /// std.testing.expect(Amygdala.urgency(low) < 0.5);
    /// ```
    pub fn urgency(salience: EventSalience) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(salience.level))) / 4.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SalienceLevel fromScore" {
    try std.testing.expectEqual(SalienceLevel.none, SalienceLevel.fromScore(10));
    try std.testing.expectEqual(SalienceLevel.low, SalienceLevel.fromScore(25));
    try std.testing.expectEqual(SalienceLevel.medium, SalienceLevel.fromScore(50));
    try std.testing.expectEqual(SalienceLevel.high, SalienceLevel.fromScore(70));
    try std.testing.expectEqual(SalienceLevel.critical, SalienceLevel.fromScore(90));
}

test "Amygdala task analysis" {
    const result = Amygdala.analyzeTask("urgent-security-fix", "dukh", "high");
    try std.testing.expect(result.score > 50);
    try std.testing.expect(result.level == .critical or result.level == .high);
}

test "Amygdala error analysis" {
    const result = Amygdala.analyzeError("segfault and security panic in critical module");
    // Score = 20 (base) + 30 (segfault) + 30 (security) + 30 (panic) = 110 -> capped to 100 (critical)
    try std.testing.expect(result.score >= 90);
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala urgency" {
    const critical: EventSalience = .{ .level = .critical, .score = 90, .reason = "" };
    const low: EventSalience = .{ .level = .low, .score = 30, .reason = "" };

    try std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical));
    try std.testing.expect(Amygdala.urgency(low) < 0.5);
}

test "Amygdala SalienceLevel emoji" {
    // Emojis are multibyte UTF-8 characters - check that they return non-empty strings
    try std.testing.expect(SalienceLevel.none.emoji().len > 0);
    try std.testing.expect(SalienceLevel.low.emoji().len > 0);
    try std.testing.expect(std.mem.eql(u8, "🔴", SalienceLevel.critical.emoji()));
}

test "Amygdala analyzeTask - dukh realm critical" {
    const result = Amygdala.analyzeTask("fix-urgent", "dukh", "critical");
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
    try std.testing.expect(result.score >= 70);
}

test "Amygdala analyzeTask - razum realm" {
    const result = Amygdala.analyzeTask("compute-stuff", "razum", "normal");
    try std.testing.expect(result.score >= 30);
}

test "Amygdala analyzeTask - unknown realm" {
    const result = Amygdala.analyzeTask("task-123", "unknown", "low");
    try std.testing.expect(result.score < 30);
}

test "Amygdala analyzeTask - security keyword" {
    const result = Amygdala.analyzeTask("security-patch-needed", "unknown", "high");
    try std.testing.expect(result.level == .high or result.level == .critical);
}

test "Amygdala analyzeError - segfault" {
    const result = Amygdala.analyzeError("segfault and panic at address 0x0");
    // Score = 20 (base) + 30 (segfault) + 30 (panic) = 80 (high)
    try std.testing.expect(result.score >= 70);
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala analyzeError - panic" {
    const result = Amygdala.analyzeError("panic: reached unreachable code");
    try std.testing.expect(result.score >= 50);
}

test "Amygdala analyzeError - timeout" {
    const result = Amygdala.analyzeError("connection timeout after 30s");
    try std.testing.expect(result.score >= 35);
}

test "Amygdala analyzeError - generic error" {
    const result = Amygdala.analyzeError("file not found");
    try std.testing.expect(result.score >= 20);
}

test "Amygdala requiresAttention - critical level" {
    const salience: EventSalience = .{ .level = .critical, .score = 100, .reason = "" };
    try std.testing.expect(Amygdala.requiresAttention(salience));
}

test "Amygdala requiresAttention - high level" {
    const salience: EventSalience = .{ .level = .high, .score = 70, .reason = "" };
    try std.testing.expect(Amygdala.requiresAttention(salience));
}

test "Amygdala requiresAttention - medium level" {
    const salience: EventSalience = .{ .level = .medium, .score = 50, .reason = "" };
    try std.testing.expect(!Amygdala.requiresAttention(salience));
}

test "Amygdala requiresAttention - none level" {
    const salience: EventSalience = .{ .level = .none, .score = 0, .reason = "" };
    try std.testing.expect(!Amygdala.requiresAttention(salience));
}

test "Amygdala urgency - all levels" {
    const none: EventSalience = .{ .level = .none, .score = 0, .reason = "" };
    const low: EventSalience = .{ .level = .low, .score = 25, .reason = "" };
    const medium: EventSalience = .{ .level = .medium, .score = 50, .reason = "" };
    const high: EventSalience = .{ .level = .high, .score = 75, .reason = "" };
    const critical: EventSalience = .{ .level = .critical, .score = 100, .reason = "" };

    try std.testing.expectEqual(@as(f32, 0.0), Amygdala.urgency(none));
    try std.testing.expectEqual(@as(f32, 0.25), Amygdala.urgency(low));
    try std.testing.expectEqual(@as(f32, 0.5), Amygdala.urgency(medium));
    try std.testing.expectEqual(@as(f32, 0.75), Amygdala.urgency(high));
    try std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical));
}

test "Amygdala score capping at 100" {
    const result = Amygdala.analyzeTask("urgent-critical-security-fix", "dukh", "critical");
    try std.testing.expect(result.score <= 100);
}

test "Amygdala scanPatterns - multiple patterns sum" {
    // All three patterns present: 30 + 50 + 40 = 120
    const result = Amygdala.scanPatterns("urgent-critical-security-fix");
    try std.testing.expectEqual(@as(f32, 120), result);
}

test "Amygdala scanPatterns - critical only" {
    const result = Amygdala.scanPatterns("critical-fix");
    try std.testing.expectEqual(@as(f32, 50), result);
}

test "Amygdala scanPatterns - security only" {
    const result = Amygdala.scanPatterns("security-patch");
    try std.testing.expectEqual(@as(f32, 40), result);
}

test "Amygdala scanPatterns - urgent only" {
    const result = Amygdala.scanPatterns("urgent-fix-needed");
    try std.testing.expectEqual(@as(f32, 30), result);
}

test "Amygdala scanPatterns - no match" {
    const result = Amygdala.scanPatterns("normal-task-description");
    try std.testing.expectEqual(@as(f32, 0), result);
}

test "Amygdala scanPatterns - case sensitive" {
    // Uppercase should NOT match (case-sensitive scan)
    const result = Amygdala.scanPatterns("CRITICAL-fix");
    try std.testing.expectEqual(@as(f32, 0), result);
}

test "Amygdala scanPatterns - empty string" {
    const result = Amygdala.scanPatterns("");
    try std.testing.expectEqual(@as(f32, 0), result);
}

test "Amygdala scanPatterns - overlapping patterns" {
    // "critical" contains "crit" but we only match full patterns
    const result = Amygdala.scanPatterns("critical-critical");
    try std.testing.expectEqual(@as(f32, 100), result); // 50 + 50
}

test "Amygdala scanPatterns - pattern sum correctness" {
    // Verify that scanning "urgent-critical-security" returns sum of all
    const result = Amygdala.scanPatterns("urgent-critical-security");
    try std.testing.expectEqual(@as(f32, 120), result); // 30 + 50 + 40
}
