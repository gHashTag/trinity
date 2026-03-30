// @origin manual

// ═══════════════════════════════════════════════════════════════════════════════
// MATCHER — Answer matching with multiple strategies
// ═══════════════════════════════════════════════════════════════════════════════
//
// Strategies:
//   0. StripParenthetical — Remove (parentheses) and [brackets]
//   1. ExactMatch — Case-insensitive exact match
//   2. McLetter — A/B/C/D letter match
//   3. Substring — Response contains expected (for short expected)
//   4. WordBoundary — Match on word boundaries
//   5. SequentialWord — Sequential word matching with tolerance
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const MatchStrategy = enum(u3) {
    StripParenthetical = 0,
    ExactMatch = 1,
    McLetter = 2,
    Substring = 3,
    WordBoundary = 4,
    SequentialWord = 5,
};

pub const MatchResult = struct {
    matched: bool,
    strategy: MatchStrategy,
    confidence: f64,
};

pub const Matcher = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Matcher {
        return .{ .allocator = allocator };
    }

    /// Try all strategies, return first successful match
    pub fn match(self: *const Matcher, response: []const u8, expected: []const u8) MatchResult {
        // Normalize inputs
        const response_clean = self.cleanResponse(response);
        defer self.allocator.free(response_clean);

        const expected_clean = self.cleanResponse(expected);
        defer self.allocator.free(expected_clean);

        // Strategy 0: Strip parenthetical annotations
        if (self.tryStripParenthetical(response_clean, expected_clean)) |result| {
            return result;
        }

        // Strategy 1: Exact match (case-insensitive)
        if (self.tryExactMatch(response_clean, expected_clean)) |result| {
            return result;
        }

        // Strategy 2: MC letter match
        if (self.tryMcLetter(response_clean, expected_clean)) |result| {
            return result;
        }

        // Strategy 3: Substring match (for short expected values)
        if (self.trySubstring(response_clean, expected_clean)) |result| {
            return result;
        }

        // Strategy 4: Word boundary match
        if (self.tryWordBoundary(response_clean, expected_clean)) |result| {
            return result;
        }

        // Strategy 5: Sequential word match
        if (self.trySequentialWord(response_clean, expected_clean)) |result| {
            return result;
        }

        return .{
            .matched = false,
            .strategy = .ExactMatch,
            .confidence = 0.0,
        };
    }

    fn cleanResponse(self: *const Matcher, s: []const u8) []const u8 {
        // Trim whitespace and normalize
        var trimmed = std.mem.trim(u8, s, " \t\r\n");

        // Remove common prefix patterns
        const patterns = [3][]const u8{
            "The answer is: ",
            "Answer: ",
            "Result: ",
        };

        for (patterns) |pat| {
            if (std.mem.startsWith(u8, trimmed, pat)) {
                trimmed = trimmed[pat.len..];
                trimmed = std.mem.trim(u8, trimmed, " \t\r\n");
            }
        }

        return self.allocator.dupe(u8, trimmed) catch trimmed;
    }

    fn tryStripParenthetical(self: *const Matcher, response: []const u8, expected: []const u8) ?MatchResult {
        _ = self;

        // Strip parenthetical content from response
        var stripped = std.ArrayList(u8).init(self.allocator);
        defer stripped.deinit();

        var in_parens: usize = 0;
        for (response) |c| {
            if (c == '(' or c == '[') {
                in_parens += 1;
            } else if (c == ')' or c == ']') {
                if (in_parens > 0) in_parens -= 1;
            } else if (in_parens == 0) {
                stripped.append(c) catch {};
            }
        }

        const cleaned = std.mem.trim(u8, stripped.items, " \t\r\n");

        // Compare with expected
        if (caseInsensitiveEql(cleaned, expected)) {
            return .{
                .matched = true,
                .strategy = .StripParenthetical,
                .confidence = 0.95,
            };
        }

        return null;
    }

    fn tryExactMatch(self: *const Matcher, response: []const u8, expected: []const u8) ?MatchResult {
        _ = self;

        if (caseInsensitiveEql(response, expected)) {
            return .{
                .matched = true,
                .strategy = .ExactMatch,
                .confidence = 1.0,
            };
        }

        return null;
    }

    fn tryMcLetter(self: *const Matcher, response: []const u8, expected: []const u8) ?MatchResult {
        _ = self;

        // Check if response is a single letter A-D
        const resp_trimmed = std.mem.trim(u8, response, " \t\r\n");
        const exp_trimmed = std.mem.trim(u8, expected, " \t\r\n");

        if (resp_trimmed.len == 1 and exp_trimmed.len == 1) {
            const r = std.ascii.toUpper(resp_trimmed[0]);
            const e = std.ascii.toUpper(exp_trimmed[0]);

            if (r >= 'A' and r <= 'D' and e >= 'A' and e <= 'D') {
                if (r == e) {
                    return .{
                        .matched = true,
                        .strategy = .McLetter,
                        .confidence = 1.0,
                    };
                }
            }
        }

        return null;
    }

    fn trySubstring(self: *const Matcher, response: []const u8, expected: []const u8) ?MatchResult {
        // Only use for short expected values (< 30 chars)
        if (expected.len > 30) return null;

        if (caseInsensitiveIndexOf(response, expected) != null) {
            return .{
                .matched = true,
                .strategy = .Substring,
                .confidence = 0.8,
            };
        }

        // Also try reverse: expected contains response
        if (response.len < 30) {
            if (caseInsensitiveIndexOf(expected, response) != null) {
                return .{
                    .matched = true,
                    .strategy = .Substring,
                    .confidence = 0.7,
                };
            }
        }

        return null;
    }

    fn tryWordBoundary(self: *const Matcher, response: []const u8, expected: []const u8) ?MatchResult {
        // Check if expected appears as a complete word in response
        var iter = std.mem.tokenizeScalar(u8, response, ' ');
        while (iter.next()) |word| {
            const w = std.mem.trim(u8, word, ".,!?;:");
            if (caseInsensitiveEql(w, expected)) {
                return .{
                    .matched = true,
                    .strategy = .WordBoundary,
                    .confidence = 0.9,
                };
            }
        }

        return null;
    }

    fn trySequentialWord(self: *const Matcher, response: []const u8, expected: []const u8) ?MatchResult {
        // Extract words from expected
        var exp_words = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (exp_words.items) |w| self.allocator.free(w);
            exp_words.deinit();
        }

        var iter = std.mem.tokenizeScalar(u8, expected, ' ');
        while (iter.next()) |word| {
            const w = std.mem.trim(u8, word, ".,!?;:");
            try exp_words.append(try self.allocator.dupe(u8, w));
        }

        if (exp_words.items.len < 2) return null;

        // Check if we can find at least 2 consecutive words in response
        var consecutive: usize = 0;
        var response_idx: usize = 0;

        for (exp_words.items) |exp_word| {
            const found = caseInsensitiveIndexOf(response[response_idx..], exp_word);
            if (found) |idx| {
                consecutive += 1;
                response_idx += idx + exp_word.len;
                if (consecutive >= 2) {
                    return .{
                        .matched = true,
                        .strategy = .SequentialWord,
                        .confidence = 0.75,
                    };
                }
            } else {
                consecutive = 0;
            }
        }

        return null;
    }

    fn caseInsensitiveEql(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |ca, cb| {
            if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
        }
        return true;
    }

    fn caseInsensitiveIndexOf(haystack: []const u8, needle: []const u8) ?usize {
        if (needle.len > haystack.len) return null;
        if (needle.len == 0) return 0;

        var i: usize = 0;
        while (i <= haystack.len - needle.len) : (i += 1) {
            var match = true;
            for (needle, 0..) |n, j| {
                if (i + j >= haystack.len or
                    std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(n)) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }

        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "exact match" {
    const allocator = std.testing.allocator;
    const matcher = Matcher.init(allocator);

    const result = matcher.match("Tashkent", "Tashkent");
    try std.testing.expect(result.matched);
    try std.testing.expectEqual(MatchStrategy.ExactMatch, result.strategy);
}

test "case insensitive match" {
    const allocator = std.testing.allocator;
    const matcher = Matcher.init(allocator);

    const result = matcher.match("tashkent", "TASHKENT");
    try std.testing.expect(result.matched);
}

test "mc letter match" {
    const allocator = std.testing.allocator;
    const matcher = Matcher.init(allocator);

    const result = matcher.match("A", "A");
    try std.testing.expect(result.matched);
    try std.testing.expectEqual(MatchStrategy.McLetter, result.strategy);
}

test "substring match" {
    const allocator = std.testing.allocator;
    const matcher = Matcher.init(allocator);

    const result = matcher.match("The capital is Tashkent", "Tashkent");
    try std.testing.expect(result.matched);
    try std.testing.expectEqual(MatchStrategy.Substring, result.strategy);
}

test "strip parenthetical" {
    const allocator = std.testing.allocator;
    const matcher = Matcher.init(allocator);

    const result = matcher.match("Tashkent (capital of Uzbekistan)", "Tashkent");
    try std.testing.expect(result.matched);
    try std.testing.expectEqual(MatchStrategy.StripParenthetical, result.strategy);
}
