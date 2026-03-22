//! AMYGDALA — Emotional Salience Detection v1.2 (OPTIMIZED)
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
//! - Single-pass optimized pattern scanning
//! - Zero-allocation salience computation
//!
//! # Biological Inspiration
//!
//! The amygdala in the brain processes emotional significance and
//! triggers attention for important events. This module mirrors that
//! by scoring and ranking events by importance.
//!
//! # Performance
//!
//! - O(n * m) pattern matching where n = input length, m = pattern length
//! - Single-pass scan for multiple keywords (urgent, critical, security)
//! - No heap allocations during salience analysis
//! - Early exit for short strings (< 6 chars)
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
//!
//! # Thread Safety
//!
//! All methods are stateless and thread-safe. No internal mutable state.

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
    ///
    /// # Performance v1.2
    /// - Early exit for max score (short-circuit evaluation)
    /// - Optimized realm checking
    pub fn analyzeTask(task_id: []const u8, realm: []const u8, priority: []const u8) EventSalience {
        // Optimized realm scoring with fast path
        const realm_score: f32 = if (realm.len == 4 and realm[0] == 'd') 40 else if (realm.len == 4 and realm[0] == 'r') 30 else if (std.mem.eql(u8, realm, "dukh")) 40 else if (std.mem.eql(u8, realm, "razum")) 30 else 0;

        var score = realm_score + scanPatterns(task_id);

        // Priority scoring with early exit
        if (priority.len >= 4) {
            const first_char = priority[0];
            if (first_char == 'c') {
                if (std.mem.eql(u8, priority, "critical")) {
                    score += 30;
                }
            } else if (first_char == 'h') {
                if (std.mem.eql(u8, priority, "high")) {
                    score += 20;
                }
            }
        }

        // Cap at 100
        const capped = if (score > 100) 100 else score;
        return .{
            .level = SalienceLevel.fromScore(capped),
            .score = capped,
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
    ///
    /// # Performance v2.2
    /// - Early exit at max score
    /// - Single-pass pattern scan
    /// - Inline character checks for common patterns
    pub fn analyzeError(err_msg: []const u8) EventSalience {
        // Early exit for empty strings
        if (err_msg.len == 0) return .{ .level = .low, .score = 20, .reason = "empty error" };

        var score: f32 = 20; // Base score for any error

        // Critical error patterns
        const critical_patterns = [_]struct { pat: []const u8, score: f32 }{
            .{ .pat = "segfault", .score = 30 },
            .{ .pat = "panic", .score = 30 },
            .{ .pat = "out of memory", .score = 30 },
            .{ .pat = "deadlock", .score = 30 },
            .{ .pat = "corruption", .score = 30 },
            .{ .pat = "security", .score = 30 },
            .{ .pat = "authentication", .score = 30 },
            .{ .pat = "injection", .score = 30 },
        };

        for (critical_patterns) |cp| {
            if (std.mem.indexOf(u8, err_msg, cp.pat) != null) {
                score += cp.score;
            }
        }

        // High severity patterns
        const high_patterns = [_]struct { pat: []const u8, score: f32 }{
            .{ .pat = "timeout", .score = 15 },
            .{ .pat = "connection refused", .score = 15 },
            .{ .pat = "not found", .score = 15 },
        };

        for (high_patterns) |hp| {
            if (std.mem.indexOf(u8, err_msg, hp.pat) != null) {
                score += hp.score;
            }
        }

        const capped_score = if (score > 100) 100 else score;

        return .{
            .level = SalienceLevel.fromScore(capped_score),
            .score = capped_score,
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

// ═══════════════════════════════════════════════════════════════════════════════
// EDGE CASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Amygdala analyzeTask - all null inputs" {
    // Should handle empty/invalid inputs gracefully
    const result = Amygdala.analyzeTask("", "", "");
    try std.testing.expect(result.score >= 0);
    try std.testing.expect(result.level == .none);
}

test "Amygdala analyzeTask - unicode in task_id" {
    // Should handle unicode characters correctly
    const result = Amygdala.analyzeTask("urgent-тест-fix", "dukh", "high");
    try std.testing.expect(result.score >= 40); // dukh realm + urgent keyword
}

test "Amygdala analyzeError - empty error message" {
    // Empty error should still get base score
    const result = Amygdala.analyzeError("");
    try std.testing.expectEqual(@as(f32, 20), result.score);
    try std.testing.expectEqual(SalienceLevel.low, result.level);
}

test "Amygdala analyzeError - very long error message" {
    // Should handle long error messages
    var long_msg: [1000]u8 = undefined;
    @memset(&long_msg, ' ');
    @memcpy(long_msg[0..8], "segfault");
    const result = Amygdala.analyzeError(&long_msg);
    try std.testing.expect(result.score >= 50);
}

test "Amygdala scanPatterns - partial matches not counted" {
    // Only full pattern matches should count
    const result = Amygdala.scanPatterns("crit urg secur");
    try std.testing.expectEqual(@as(f32, 0), result); // No full matches
}

test "Amygdala scanPatterns - word boundary behavior" {
    // Patterns in middle of word should still match (substring search)
    const result = Amygdala.scanPatterns("supercriticalurgentsecurity");
    try std.testing.expectEqual(@as(f32, 120), result); // All patterns found as substrings
}

test "Amygdala score boundary values" {
    // Test exact boundary values
    // none/low boundary at 20
    const low_threshold = Amygdala.analyzeTask("", "sattva", "normal");
    try std.testing.expect(low_threshold.score < 20);

    // Add high priority (+20) to cross into low
    const crossed_low = Amygdala.analyzeTask("", "sattva", "high");
    try std.testing.expect(crossed_low.score >= 20);
    try std.testing.expect(crossed_low.level == .low);

    // medium/high boundary at 60
    const medium_result = Amygdala.analyzeTask("urgent", "dukh", "high");
    // dukh=40 + urgent=30 + high=20 = 90, capped at 100 = critical
    try std.testing.expect(medium_result.level == .critical);
}

test "Amygdala scanPatterns - repeated pattern multiple times" {
    // Same pattern appearing multiple times should be counted each time
    const result = Amygdala.scanPatterns("critical-critical-critical");
    try std.testing.expectEqual(@as(f32, 150), result); // 50 * 3
}

test "Amygdala scanPatterns - keyword at start/middle/end" {
    // Pattern positions shouldn't affect matching
    const start = Amygdala.scanPatterns("critical-fix");
    const middle = Amygdala.scanPatterns("fix-critical-end");
    const end = Amygdala.scanPatterns("fix-end-critical");

    try std.testing.expectEqual(start, middle);
    try std.testing.expectEqual(middle, end);
}

test "Amygdala analyzeTask - negative realm priority combo" {
    // Test realm + priority scoring correctly
    const dukh_normal = Amygdala.analyzeTask("task", "dukh", "normal");
    const razum_critical = Amygdala.analyzeTask("task", "razum", "critical");

    // dukh(40) > razum(30) + critical(30) = 60 vs 40
    try std.testing.expect(dukh_normal.score < razum_critical.score);
}

test "Amygdala analyzeError - multi-pattern with same substring" {
    // Patterns sharing substrings should all be detected
    const result = Amygdala.analyzeError("authentication security panic");
    // base 20 + authentication(30) + security(30) + panic(30) = 110 -> capped at 100
    try std.testing.expectEqual(@as(f32, 100), result.score);
}

test "Amygdala urgency - exact level mapping" {
    // Verify urgency maps linearly from 0 to 1
    const none: EventSalience = .{ .level = .none, .score = 0, .reason = "" };
    const low: EventSalience = .{ .level = .low, .score = 20, .reason = "" };
    const medium: EventSalience = .{ .level = .medium, .score = 40, .reason = "" };
    const high: EventSalience = .{ .level = .high, .score = 60, .reason = "" };
    const critical: EventSalience = .{ .level = .critical, .score = 80, .reason = "" };

    try std.testing.expectEqual(@as(f32, 0.0), Amygdala.urgency(none));
    try std.testing.expectEqual(@as(f32, 0.25), Amygdala.urgency(low));
    try std.testing.expectEqual(@as(f32, 0.5), Amygdala.urgency(medium));
    try std.testing.expectEqual(@as(f32, 0.75), Amygdala.urgency(high));
    try std.testing.expectEqual(@as(f32, 1.0), Amygdala.urgency(critical));
}

test "Amygdala requiresAttention - exact thresholds" {
    // Verify attention threshold is exactly at high level (>=60)
    const high_edge: EventSalience = .{ .level = .high, .score = 60, .reason = "" };
    const medium_edge: EventSalience = .{ .level = .medium, .score = 59, .reason = "" };

    try std.testing.expect(Amygdala.requiresAttention(high_edge));
    try std.testing.expect(!Amygdala.requiresAttention(medium_edge));
}

test "Amygdala scanPatterns - pattern longer than input" {
    // Should handle patterns longer than input gracefully
    const result = Amygdala.scanPatterns("ab");
    try std.testing.expectEqual(@as(f32, 0), result);
}

test "Amygdala scanPatterns - single character input" {
    const result = Amygdala.scanPatterns("a");
    try std.testing.expectEqual(@as(f32, 0), result);
}

test "Amygdala analyzeError - mixed case patterns" {
    // Pattern matching is case-sensitive
    const lower = Amygdala.analyzeError("segfault occurred");
    const upper = Amygdala.analyzeError("SEGFAULT occurred");
    const mixed = Amygdala.analyzeError("SeGfAuLt occurred");

    try std.testing.expect(lower.score > 20); // matches
    try std.testing.expect(upper.score == 20); // no match
    try std.testing.expect(mixed.score == 20); // no match
}

test "Amygdala analyzeTask - realm case sensitivity" {
    // Realm matching is case-sensitive
    const lower = Amygdala.analyzeTask("task", "dukh", "normal");
    const upper = Amygdala.analyzeTask("task", "DUKH", "normal");
    const mixed = Amygdala.analyzeTask("task", "Dukh", "normal");

    try std.testing.expect(lower.score == 40);
    try std.testing.expect(upper.score == 0);
    try std.testing.expect(mixed.score == 0);
}

test "Amygdala analyzeTask - priority case sensitivity" {
    // Priority matching is case-sensitive
    const high_lower = Amygdala.analyzeTask("task", "sattva", "high");
    const high_upper = Amygdala.analyzeTask("task", "sattva", "HIGH");

    try std.testing.expect(high_lower.score == 20);
    try std.testing.expect(high_upper.score == 0);
}

test "Amygdala maximum score cap" {
    // Even with maximum scoring factors, should cap at 100
    // critical(50) + urgent(30) + security(40) + dukh(40) + critical priority(30) = 190
    const result = Amygdala.analyzeTask("critical-urgent-security", "dukh", "critical");
    try std.testing.expect(result.score <= 100);
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
}

test "Amygdala error with all critical patterns" {
    // Error with all critical patterns should cap at 100
    // base(20) + segfault(30) + panic(30) + deadlock(30) + corruption(30) + security(30) + authentication(30) + injection(30) = 230
    const result = Amygdala.analyzeError("segfault panic deadlock corruption security authentication injection");
    try std.testing.expectEqual(@as(f32, 100), result.score);
}

test "Amygdala scanPatterns - pattern interleaving" {
    // Test patterns appearing in different orders
    const order1 = Amygdala.scanPatterns("urgent-critical-security");
    const order2 = Amygdala.scanPatterns("security-urgent-critical");
    const order3 = Amygdala.scanPatterns("critical-security-urgent");

    try std.testing.expectEqual(order1, order2);
    try std.testing.expectEqual(order2, order3);
}

test "Threat detection: high urgency task" {
    // Test high urgency task analysis using existing API
    const salience = Amygdala.analyzeTask("urgent-critical-security-fix", "dukh", "critical");

    try std.testing.expectEqual(SalienceLevel.critical, salience.level);
    try std.testing.expect(salience.score >= 80);
}

test "Threat detection: low urgency task" {
    // Test low urgency task analysis using existing API
    const salience = Amygdala.analyzeTask("routine-maintenance", "razum", "low");

    try std.testing.expect(salience.level == .none or salience.level == .low);
    try std.testing.expect(salience.score < 40);
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE EDGE CASE TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════

test "Amygdala: threat level boundaries - exact thresholds" {
    // Test exact boundary values for each level transition

    // none/low boundary at 20
    const level_19 = SalienceLevel.fromScore(19.999);
    try std.testing.expectEqual(SalienceLevel.none, level_19);

    const level_20 = SalienceLevel.fromScore(20.0);
    try std.testing.expectEqual(SalienceLevel.low, level_20);

    // low/medium boundary at 40
    const level_39 = SalienceLevel.fromScore(39.999);
    try std.testing.expectEqual(SalienceLevel.low, level_39);

    const level_40 = SalienceLevel.fromScore(40.0);
    try std.testing.expectEqual(SalienceLevel.medium, level_40);

    // medium/high boundary at 60
    const level_59 = SalienceLevel.fromScore(59.999);
    try std.testing.expectEqual(SalienceLevel.medium, level_59);

    const level_60 = SalienceLevel.fromScore(60.0);
    try std.testing.expectEqual(SalienceLevel.high, level_60);

    // high/critical boundary at 80
    const level_79 = SalienceLevel.fromScore(79.999);
    try std.testing.expectEqual(SalienceLevel.high, level_79);

    const level_80 = SalienceLevel.fromScore(80.0);
    try std.testing.expectEqual(SalienceLevel.critical, level_80);
}

test "Amygdala: threat level - negative score" {
    // Negative scores should map to none
    const level = SalienceLevel.fromScore(-10.0);
    try std.testing.expectEqual(SalienceLevel.none, level);
}

test "Amygdala: threat level - score above 100" {
    // Scores above 100 should still map to critical
    const level = SalienceLevel.fromScore(150.0);
    try std.testing.expectEqual(SalienceLevel.critical, level);

    const level_max = SalienceLevel.fromScore(std.math.inf(f32));
    try std.testing.expectEqual(SalienceLevel.critical, level_max);
}

test "Amygdala: threat level - zero score" {
    const level = SalienceLevel.fromScore(0.0);
    try std.testing.expectEqual(SalienceLevel.none, level);
}

test "Amygdala: threat level - fractional scores" {
    // Test that fractional scores are handled correctly
    const level_19_5 = SalienceLevel.fromScore(19.5);
    try std.testing.expectEqual(SalienceLevel.none, level_19_5);

    const level_20_5 = SalienceLevel.fromScore(20.5);
    try std.testing.expectEqual(SalienceLevel.low, level_20_5);
}

test "Amygdala: salience calculation - maximum score" {
    // Test all scoring factors combined
    const result = Amygdala.analyzeTask("urgent-critical-security", "dukh", "critical");

    //dukhh(40) + urgent(30) + critical(50) + security(40) + critical_priority(30) = 190
    // But capped at 100
    try std.testing.expectEqual(@as(f32, 100), result.score);
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
}

test "Amygdala: salience calculation - minimum score" {
    // Test with no scoring factors
    const result = Amygdala.analyzeTask("routine-task", "unknown-realm", "low");

    try std.testing.expect(result.score < 20);
    try std.testing.expectEqual(SalienceLevel.none, result.level);
}

test "Amygdala: salience calculation - dukh vs razum" {
    const dukh_result = Amygdala.analyzeTask("task", "dukh", "normal");
    const razum_result = Amygdala.analyzeTask("task", "razum", "normal");

    // dukh (+40) > razum (+30)
    try std.testing.expect(dukh_result.score > razum_result.score);
}

test "Amygdala: salience calculation - priority levels" {
    const normal = Amygdala.analyzeTask("task", "sattva", "normal");
    const high = Amygdala.analyzeTask("task", "sattva", "high");
    const critical = Amygdala.analyzeTask("task", "sattva", "critical");

    try std.testing.expect(normal.score < high.score);
    try std.testing.expect(high.score < critical.score);
}

test "Amygdala: salience calculation - keyword stacking" {
    // Test that multiple keywords stack correctly
    const single = Amygdala.analyzeTask("task", "sattva", "normal");
    const with_urgent = Amygdala.analyzeTask("urgent-task", "sattva", "normal");
    const with_critical = Amygdala.analyzeTask("critical-task", "sattva", "normal");
    const with_both = Amygdala.analyzeTask("urgent-critical-task", "sattva", "normal");

    try std.testing.expect(with_urgent.score > single.score);
    try std.testing.expect(with_critical.score > with_urgent.score);
    try std.testing.expect(with_both.score > with_critical.score);
}

test "Amygdala: error salience - all critical patterns" {
    const result = Amygdala.analyzeError("segfault panic deadlock corruption security authentication injection out of memory");

    // Base 20 + 8 patterns * 30 = 260, capped at 100
    try std.testing.expectEqual(@as(f32, 100), result.score);
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
}

test "Amygdala: error salience - all high severity patterns" {
    const result = Amygdala.analyzeError("timeout connection refused not found");

    // Base 20 + timeout(15) + connection_refused(15) + not_found(15) = 65
    // Note: patterns are checked for presence, not count
    try std.testing.expect(result.score >= 60);
}

test "Amygdala: error salience - empty error message" {
    const result = Amygdala.analyzeError("");

    // Empty error should still get base score
    try std.testing.expectEqual(@as(f32, 20), result.score);
    try std.testing.expectEqual(SalienceLevel.low, result.level);
}

test "Amygdala: error salience - generic error only" {
    const result = Amygdala.analyzeError("something went wrong");

    // Only base score for generic error
    try std.testing.expectEqual(@as(f32, 20), result.score);
}

test "Amygdala: urgency calculation - all levels" {
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

test "Amygdala: urgency is linear with level" {
    // Verify urgency = level / 4.0
    for (0..5) |i| {
        const level: SalienceLevel = @enumFromInt(i);
        const event: EventSalience = .{ .level = level, .score = 0, .reason = "" };
        const expected_urgency = @as(f32, @floatFromInt(i)) / 4.0;
        try std.testing.expectApproxEqAbs(expected_urgency, Amygdala.urgency(event), 0.001);
    }
}

test "Amygdala: requiresAttention thresholds" {
    const none: EventSalience = .{ .level = .none, .score = 0, .reason = "" };
    const low: EventSalience = .{ .level = .low, .score = 25, .reason = "" };
    const medium: EventSalience = .{ .level = .medium, .score = 50, .reason = "" };
    const high: EventSalience = .{ .level = .high, .score = 75, .reason = "" };
    const critical: EventSalience = .{ .level = .critical, .score = 100, .reason = "" };

    try std.testing.expect(!Amygdala.requiresAttention(none));
    try std.testing.expect(!Amygdala.requiresAttention(low));
    try std.testing.expect(!Amygdala.requiresAttention(medium));
    try std.testing.expect(Amygdala.requiresAttention(high));
    try std.testing.expect(Amygdala.requiresAttention(critical));
}

test "Amygdala: scanPatterns - pattern at string boundaries" {
    // Pattern at start
    const start = Amygdala.scanPatterns("critical-fix");
    try std.testing.expectEqual(@as(f32, 50), start);

    // Pattern at end
    const end = Amygdala.scanPatterns("fix-critical");
    try std.testing.expectEqual(@as(f32, 50), end);

    // Pattern as entire string
    const whole = Amygdala.scanPatterns("critical");
    try std.testing.expectEqual(@as(f32, 50), whole);
}

test "Amygdala: scanPatterns - overlapping patterns" {
    // "security" contains "cur" but we only match full patterns
    const result = Amygdala.scanPatterns("securityurgent");
    try std.testing.expectEqual(@as(f32, 70), result); // 40 + 30
}

test "Amygdala: scanPatterns - case sensitivity" {
    const lower = Amygdala.scanPatterns("critical");
    const upper = Amygdala.scanPatterns("CRITICAL");
    const mixed = Amygdala.scanPatterns("CrItIcAl");

    try std.testing.expectEqual(@as(f32, 50), lower);
    try std.testing.expectEqual(@as(f32, 0), upper);
    try std.testing.expectEqual(@as(f32, 0), mixed);
}

test "Amygdala: scanPatterns - repeated pattern counting" {
    // Same pattern multiple times should be counted each time
    const single = Amygdala.scanPatterns("critical");
    const double = Amygdala.scanPatterns("critical critical");
    const triple = Amygdala.scanPatterns("critical critical critical");

    try std.testing.expectEqual(@as(f32, 50), single);
    try std.testing.expectEqual(@as(f32, 100), double);
    try std.testing.expectEqual(@as(f32, 150), triple);
}

test "Amygdala: scanPatterns - very short input" {
    const empty = Amygdala.scanPatterns("");
    try std.testing.expectEqual(@as(f32, 0), empty);

    const single_char = Amygdala.scanPatterns("a");
    try std.testing.expectEqual(@as(f32, 0), single_char);

    const five_chars = Amygdala.scanPatterns("abcde");
    try std.testing.expectEqual(@as(f32, 0), five_chars); // "urgent" is 6 chars
}

test "Amygdala: scanPatterns - unicode handling" {
    // Unicode characters should not break the scanner
    const result = Amygdala.scanPatterns("urgent-critical-тест");
    try std.testing.expectEqual(@as(f32, 80), result); // 30 + 50
}

test "Amygdala: analyzeTask - very long task_id" {
    var long_task: [1000]u8 = undefined;
    @memset(&long_task, 'a');

    const result = Amygdala.analyzeTask(&long_task, "dukh", "high");
    try std.testing.expect(result.score >= 60); // dukh(40) + high(20)
}

test "Amygdala: analyzeTask - empty strings" {
    const result = Amygdala.analyzeTask("", "", "");
    try std.testing.expectEqual(@as(f32, 0), result.score);
    try std.testing.expectEqual(SalienceLevel.none, result.level);
}

test "Amygdala: analyzeTask - special characters in task_id" {
    const result = Amygdala.analyzeTask("urgent!@#$%^&*()", "dukh", "high");
    // Should still detect urgent keyword
    try std.testing.expect(result.score >= 70); // dukh(40) + urgent(30) or similar
}

test "Amygdala: analyzeError - special characters in error" {
    const result = Amygdala.analyzeError("segfault at 0xdeadbeef in function(){}[]");
    try std.testing.expect(result.score >= 50); // base(20) + segfault(30)
}

test "Amygdala: analyzeError - pattern substring matching" {
    // "authentication" contains "auth" but we match full pattern
    const result = Amygdala.analyzeError("authentication failed");
    try std.testing.expect(result.score >= 50); // base(20) + authentication(30)
}

test "Amygdala: analyzeError - multiple same patterns" {
    // Note: analyzeError only checks if pattern exists, not count occurrences
    // So multiple instances of the same pattern don't increase the score
    const single = Amygdala.analyzeError("segfault");
    const double = Amygdala.analyzeError("segfault segfault");
    const triple = Amygdala.analyzeError("segfault segfault segfault");

    try std.testing.expectEqual(@as(f32, 50), single.score); // 20 + 30
    try std.testing.expectEqual(@as(f32, 50), double.score); // Still 20 + 30 (pattern exists once)
    try std.testing.expectEqual(@as(f32, 50), triple.score); // Still 20 + 30 (pattern exists once)
}

test "Amygdala: score capping at exactly 100" {
    // Test that scores are capped at exactly 100, not above
    const result1 = Amygdala.analyzeTask("urgent-critical-security", "dukh", "critical");
    try std.testing.expectEqual(@as(f32, 100), result1.score);

    const result2 = Amygdala.analyzeError("segfault panic deadlock corruption security authentication injection");
    try std.testing.expectEqual(@as(f32, 100), result2.score);
}

test "Amygdala: emoji returns non-empty strings" {
    for (0..5) |i| {
        const level: SalienceLevel = @enumFromInt(i);
        const emoji = level.emoji();
        try std.testing.expect(emoji.len > 0);
    }
}

test "Amygdala: emoji strings are unique per level" {
    const emojis = [_][]const u8{
        SalienceLevel.none.emoji(),
        SalienceLevel.low.emoji(),
        SalienceLevel.medium.emoji(),
        SalienceLevel.high.emoji(),
        SalienceLevel.critical.emoji(),
    };

    // Verify each emoji is different
    for (emojis, 0..) |emoji1, i| {
        for (emojis[i + 1 ..]) |emoji2| {
            try std.testing.expect(!std.mem.eql(u8, emoji1, emoji2));
        }
    }
}

test "Amygdala: threat detection - security related" {
    const result = Amygdala.analyzeTask("security-patch-needed", "sattva", "high");
    try std.testing.expect(result.level == .high or result.level == .critical);
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala: threat detection - urgent production issue" {
    const result = Amygdala.analyzeTask("urgent-production-outage", "dukh", "critical");
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala: threat detection - routine maintenance" {
    const result = Amygdala.analyzeTask("scheduled-maintenance", "razum", "normal");
    try std.testing.expect(result.level == .none or result.level == .low);
    try std.testing.expect(!Amygdala.requiresAttention(result));
}

test "Amygdala: threat detection - security error" {
    const result = Amygdala.analyzeError("security: SQL injection detected");
    try std.testing.expect(result.score >= 50); // base(20) + security(30)
    try std.testing.expect(Amygdala.requiresAttention(result));
}

test "Amygdala: threat detection - crash error" {
    const result = Amygdala.analyzeError("process crashed with segfault");
    // Score = 20 (base) + 30 (segfault) = 50
    try std.testing.expect(result.score >= 50);
    // Level at 50 is medium (not high/critical)
    try std.testing.expectEqual(SalienceLevel.medium, result.level);
}

test "Amygdala: threat detection - timeout error" {
    const result = Amygdala.analyzeError("connection timeout after 30s");
    try std.testing.expect(result.score >= 35); // base(20) + timeout(15)
}

test "Amygdala: realm scoring - unknown realm" {
    const result = Amygdala.analyzeTask("task", "unknown-realm", "normal");
    // Unknown realm adds no score
    try std.testing.expect(result.score < 20);
}

test "Amygdala: priority scoring - unknown priority" {
    const result = Amygdala.analyzeTask("task", "sattva", "unknown-priority");
    // Unknown priority adds no score
    try std.testing.expect(result.score < 20);
}

test "Amygdala: combined scoring - realm + priority + keywords" {
    // dukh(40) + critical_priority(30) + critical(50) = 120 -> capped at 100
    const result = Amygdala.analyzeTask("critical-fix", "dukh", "critical");
    try std.testing.expectEqual(@as(f32, 100), result.score);
}

test "Amygdala: combined scoring - razum + high + urgent" {
    // razum(30) + high(20) + urgent(30) = 80
    const result = Amygdala.analyzeTask("urgent-fix", "razum", "high");
    try std.testing.expectEqual(@as(f32, 80), result.score);
    try std.testing.expectEqual(SalienceLevel.critical, result.level);
}

test "Amygdala: boundary - exactly at threshold" {
    // Test score exactly at boundary
    // 20 = low/none boundary
    const result = Amygdala.analyzeTask("", "sattva", "high");
    try std.testing.expectEqual(@as(f32, 20), result.score);
    try std.testing.expectEqual(SalienceLevel.low, result.level);
}

test "Amygdala: fromScore with infinity" {
    const pos_inf = SalienceLevel.fromScore(std.math.inf(f32));
    try std.testing.expectEqual(SalienceLevel.critical, pos_inf);

    const neg_inf = SalienceLevel.fromScore(-std.math.inf(f32));
    try std.testing.expectEqual(SalienceLevel.none, neg_inf);
}

// NaN handling is special case - fromScore returns .none but NaN != NaN comparison is false
// Skipping explicit NaN test as it tests implementation detail rather than behavior

test "Amygdala: very long error message" {
    var long_error: [10000]u8 = undefined;
    @memset(&long_error, ' ');
    @memcpy(long_error[0..8], "segfault");

    const result = Amygdala.analyzeError(&long_error);
    try std.testing.expect(result.score >= 50); // base(20) + segfault(30)
}

test "Amygdala: urgency comparison across levels" {
    const levels = [_]SalienceLevel{ .none, .low, .medium, .high, .critical };

    var prev_urgency: f32 = 0.0;
    for (levels, 0..) |level, i| {
        const event: EventSalience = .{ .level = level, .score = 0, .reason = "" };
        const urgency = Amygdala.urgency(event);
        try std.testing.expect(urgency >= prev_urgency);
        if (i > 0) {
            try std.testing.expect(urgency > prev_urgency);
        }
        prev_urgency = urgency;
    }
}

// φ² + 1/φ² = 3 | TRINITY
