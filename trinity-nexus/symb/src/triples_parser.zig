// ═══════════════════════════════════════════════════════════════════════════════
// SYM-002: LLM Triples Extractor — Pattern-based (Subject, Predicate, Object)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Auto-extracts knowledge triples from LLM response text.
// Sentence splitting → SVO pattern matching → confidence scoring → normalized output.
// Integrates with ChatKnowledgeGraph via addFact API.
//
// Tech Tree: SYM-002 (Symbolic branch, unlocks SYM-003/004/005)
// Generated from: specs/tri/llm_triples_extractor.vibee
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_TRIPLES_PER_RESPONSE: usize = 16;
pub const MAX_ENTITY_LEN: usize = 128;
pub const MAX_PREDICATE_LEN: usize = 64;
pub const MIN_ENTITY_LEN: usize = 2;
pub const BASE_CONFIDENCE: f64 = 0.7;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExtractedTriple = struct {
    subject_buf: [MAX_ENTITY_LEN]u8 = [_]u8{0} ** MAX_ENTITY_LEN,
    subject_len: usize = 0,
    predicate_buf: [MAX_PREDICATE_LEN]u8 = [_]u8{0} ** MAX_PREDICATE_LEN,
    predicate_len: usize = 0,
    object_buf: [MAX_ENTITY_LEN]u8 = [_]u8{0} ** MAX_ENTITY_LEN,
    object_len: usize = 0,
    confidence: f64 = 0.0,

    pub fn subject(self: *const ExtractedTriple) []const u8 {
        return self.subject_buf[0..self.subject_len];
    }

    pub fn predicate(self: *const ExtractedTriple) []const u8 {
        return self.predicate_buf[0..self.predicate_len];
    }

    pub fn object(self: *const ExtractedTriple) []const u8 {
        return self.object_buf[0..self.object_len];
    }
};

pub const ExtractionResult = struct {
    triples: [MAX_TRIPLES_PER_RESPONSE]ExtractedTriple = [_]ExtractedTriple{.{}} ** MAX_TRIPLES_PER_RESPONSE,
    count: usize = 0,
    source_len: usize = 0,

    pub fn get(self: *const ExtractionResult, idx: usize) ?*const ExtractedTriple {
        if (idx >= self.count) return null;
        return &self.triples[idx];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN TYPES — strength ordering for confidence scoring
// ═══════════════════════════════════════════════════════════════════════════════

const PatternType = enum {
    copula_identity, // "X is Y" / "X is a Y"
    copula_the, // "X is the Y of Z"
    plural_copula, // "X are Y"
    has_verb, // "X has Y"
    contains_verb, // "X contains Y"
    generic_verb, // Other SVO patterns

    fn strength(self: PatternType) f64 {
        return switch (self) {
            .copula_the => 0.95, // "X is the capital of Y" — strongest
            .copula_identity => 0.90, // "X is a Y" — strong
            .plural_copula => 0.85, // "X are Y"
            .has_verb => 0.80, // "X has Y"
            .contains_verb => 0.80, // "X contains Y"
            .generic_verb => 0.65, // Fallback
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ARTICLES to strip from entities
// ═══════════════════════════════════════════════════════════════════════════════

const ARTICLES = [_][]const u8{ "the ", "a ", "an " };

// ═══════════════════════════════════════════════════════════════════════════════
// CORE BEHAVIORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract all triples from an LLM response text.
/// Splits text into sentences (on '.', '!', '?', newline), parses each for SVO patterns.
pub fn extractTriples(text: []const u8) ExtractionResult {
    var result = ExtractionResult{};
    result.source_len = text.len;

    if (text.len == 0) return result;

    // Split into sentences
    var start: usize = 0;
    for (text, 0..) |ch, i| {
        const is_end = (ch == '.' or ch == '!' or ch == '?' or ch == '\n');
        if (is_end or i == text.len - 1) {
            const end = if (is_end) i else i + 1;
            if (end > start) {
                const sentence = text[start..end];
                if (parseSentence(sentence)) |triple| {
                    if (result.count < MAX_TRIPLES_PER_RESPONSE) {
                        result.triples[result.count] = triple;
                        result.count += 1;
                    }
                }
            }
            start = if (is_end) i + 1 else end;
        }
    }

    return result;
}

/// Parse a single sentence for SVO triple patterns.
/// Returns null if no pattern matches.
pub fn parseSentence(sentence: []const u8) ?ExtractedTriple {
    // Normalize to lowercase for matching
    var lower_buf: [1024]u8 = undefined;
    const trimmed = trimWhitespace(sentence);
    if (trimmed.len < 5 or trimmed.len > 1024) return null;

    const lower = toLower(trimmed, &lower_buf);

    // Try patterns in priority order (strongest first)

    // Pattern 1: "X is the Y of Z" → (X, is_Y_of, Z)
    if (tryCopulaThePattern(lower)) |t| return t;

    // Pattern 2: "X is a/an Y" → (X, is_a, Y)
    if (tryCopulaArticlePattern(lower)) |t| return t;

    // Pattern 3: "X is Y" → (X, is, Y)
    if (tryCopulaPattern(lower)) |t| return t;

    // Pattern 4: "X are Y" → (X, are, Y)
    if (tryPluralCopulaPattern(lower)) |t| return t;

    // Pattern 5: "X has Y" → (X, has, Y)
    if (tryHasPattern(lower)) |t| return t;

    // Pattern 6: "X contains Y" → (X, contains, Y)
    if (tryContainsPattern(lower)) |t| return t;

    return null;
}

/// Normalize an entity: trim whitespace, lowercase, remove leading articles.
pub fn normalizeEntity(raw: []const u8, buf: []u8) []const u8 {
    const trimmed = trimWhitespace(raw);
    if (trimmed.len == 0) return "";

    // Lowercase into buf
    const lower = toLower(trimmed, buf);

    // Strip leading articles
    var result = lower;
    for (ARTICLES) |article| {
        if (result.len > article.len and std.mem.startsWith(u8, result, article)) {
            result = result[article.len..];
            break;
        }
    }

    // Trim trailing whitespace again
    result = trimWhitespace(result);

    return result;
}

/// Score confidence based on subject/predicate/object lengths and pattern type.
pub fn scoreConfidence(subj_len: usize, pred_len: usize, obj_len: usize, pattern: PatternType) f64 {
    var score = pattern.strength();

    // Penalize very short entities (< 3 chars)
    if (subj_len < 3) score -= 0.1;
    if (obj_len < 3) score -= 0.1;

    // Penalize very long predicates (> 30 chars — probably not a clean predicate)
    if (pred_len > 30) score -= 0.15;

    // Boost when both entities have reasonable length (3-40 chars)
    if (subj_len >= 3 and subj_len <= 40 and obj_len >= 3 and obj_len <= 40) {
        score += 0.05;
    }

    // Clamp to [0.0, 1.0]
    return @max(0.0, @min(1.0, score));
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN MATCHERS
// ═══════════════════════════════════════════════════════════════════════════════

fn tryCopulaThePattern(sentence: []const u8) ?ExtractedTriple {
    // "X is the Y of Z" → (X, is_Y_of, Z)
    const is_pos = std.mem.indexOf(u8, sentence, " is the ") orelse return null;
    const after_is = is_pos + 8; // len(" is the ")
    const of_pos = std.mem.indexOf(u8, sentence[after_is..], " of ") orelse return null;
    const abs_of = after_is + of_pos;

    const raw_subject = sentence[0..is_pos];
    const relation_noun = sentence[after_is..abs_of];
    const raw_object = sentence[abs_of + 4 ..]; // len(" of ")

    var subj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    var obj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    const subj = normalizeEntity(raw_subject, &subj_buf);
    const obj = normalizeEntity(raw_object, &obj_buf);

    if (subj.len < MIN_ENTITY_LEN or obj.len < MIN_ENTITY_LEN) return null;

    // Build predicate: "is_<relation>_of"
    var pred_buf: [MAX_PREDICATE_LEN]u8 = undefined;
    var pred_len: usize = 0;
    const prefix = "is_";
    const suffix = "_of";
    if (prefix.len + relation_noun.len + suffix.len > MAX_PREDICATE_LEN) return null;

    @memcpy(pred_buf[0..prefix.len], prefix);
    pred_len += prefix.len;
    @memcpy(pred_buf[pred_len .. pred_len + relation_noun.len], relation_noun);
    // Replace spaces in relation with underscores
    for (pred_buf[pred_len .. pred_len + relation_noun.len]) |*c| {
        if (c.* == ' ') c.* = '_';
    }
    pred_len += relation_noun.len;
    @memcpy(pred_buf[pred_len .. pred_len + suffix.len], suffix);
    pred_len += suffix.len;

    const conf = scoreConfidence(subj.len, pred_len, obj.len, .copula_the);

    return buildTriple(subj, pred_buf[0..pred_len], obj, conf);
}

fn tryCopulaArticlePattern(sentence: []const u8) ?ExtractedTriple {
    // "X is a Y" or "X is an Y"
    const patterns = [_][]const u8{ " is a ", " is an " };
    for (patterns) |pat| {
        if (std.mem.indexOf(u8, sentence, pat)) |pos| {
            const raw_subject = sentence[0..pos];
            const raw_object = sentence[pos + pat.len ..];

            var subj_buf: [MAX_ENTITY_LEN]u8 = undefined;
            var obj_buf: [MAX_ENTITY_LEN]u8 = undefined;
            const subj = normalizeEntity(raw_subject, &subj_buf);
            const obj = normalizeEntity(raw_object, &obj_buf);

            if (subj.len < MIN_ENTITY_LEN or obj.len < MIN_ENTITY_LEN) return null;

            const pred = "is_a";
            const conf = scoreConfidence(subj.len, pred.len, obj.len, .copula_identity);
            return buildTriple(subj, pred, obj, conf);
        }
    }
    return null;
}

fn tryCopulaPattern(sentence: []const u8) ?ExtractedTriple {
    // "X is Y" (simple copula, must not match "is the" or "is a/an")
    const is_pos = std.mem.indexOf(u8, sentence, " is ") orelse return null;
    const after_is = is_pos + 4;

    // Skip if this is actually "is the" or "is a" pattern
    if (sentence.len > after_is + 4) {
        if (std.mem.startsWith(u8, sentence[after_is..], "the ")) return null;
        if (std.mem.startsWith(u8, sentence[after_is..], "a ")) return null;
        if (std.mem.startsWith(u8, sentence[after_is..], "an ")) return null;
    }

    const raw_subject = sentence[0..is_pos];
    const raw_object = sentence[after_is..];

    var subj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    var obj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    const subj = normalizeEntity(raw_subject, &subj_buf);
    const obj = normalizeEntity(raw_object, &obj_buf);

    if (subj.len < MIN_ENTITY_LEN or obj.len < MIN_ENTITY_LEN) return null;

    const pred = "is";
    const conf = scoreConfidence(subj.len, pred.len, obj.len, .copula_identity);
    return buildTriple(subj, pred, obj, conf);
}

fn tryPluralCopulaPattern(sentence: []const u8) ?ExtractedTriple {
    // "X are Y"
    const pos = std.mem.indexOf(u8, sentence, " are ") orelse return null;
    const raw_subject = sentence[0..pos];
    const raw_object = sentence[pos + 5 ..];

    var subj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    var obj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    const subj = normalizeEntity(raw_subject, &subj_buf);
    const obj = normalizeEntity(raw_object, &obj_buf);

    if (subj.len < MIN_ENTITY_LEN or obj.len < MIN_ENTITY_LEN) return null;

    const pred = "are";
    const conf = scoreConfidence(subj.len, pred.len, obj.len, .plural_copula);
    return buildTriple(subj, pred, obj, conf);
}

fn tryHasPattern(sentence: []const u8) ?ExtractedTriple {
    // "X has Y" / "X has a Y"
    const pos = std.mem.indexOf(u8, sentence, " has ") orelse return null;
    const raw_subject = sentence[0..pos];
    var raw_object = sentence[pos + 5 ..];

    // Strip "a " / "an " from object
    if (std.mem.startsWith(u8, raw_object, "a ")) raw_object = raw_object[2..];
    if (std.mem.startsWith(u8, raw_object, "an ")) raw_object = raw_object[3..];

    var subj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    var obj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    const subj = normalizeEntity(raw_subject, &subj_buf);
    const obj = normalizeEntity(raw_object, &obj_buf);

    if (subj.len < MIN_ENTITY_LEN or obj.len < MIN_ENTITY_LEN) return null;

    const pred = "has";
    const conf = scoreConfidence(subj.len, pred.len, obj.len, .has_verb);
    return buildTriple(subj, pred, obj, conf);
}

fn tryContainsPattern(sentence: []const u8) ?ExtractedTriple {
    // "X contains Y"
    const pos = std.mem.indexOf(u8, sentence, " contains ") orelse return null;
    const raw_subject = sentence[0..pos];
    const raw_object = sentence[pos + 10 ..];

    var subj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    var obj_buf: [MAX_ENTITY_LEN]u8 = undefined;
    const subj = normalizeEntity(raw_subject, &subj_buf);
    const obj = normalizeEntity(raw_object, &obj_buf);

    if (subj.len < MIN_ENTITY_LEN or obj.len < MIN_ENTITY_LEN) return null;

    const pred = "contains";
    const conf = scoreConfidence(subj.len, pred.len, obj.len, .contains_verb);
    return buildTriple(subj, pred, obj, conf);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn buildTriple(subj: []const u8, pred: []const u8, obj: []const u8, confidence: f64) ExtractedTriple {
    var t = ExtractedTriple{};

    const s_len = @min(subj.len, MAX_ENTITY_LEN);
    @memcpy(t.subject_buf[0..s_len], subj[0..s_len]);
    t.subject_len = s_len;

    const p_len = @min(pred.len, MAX_PREDICATE_LEN);
    @memcpy(t.predicate_buf[0..p_len], pred[0..p_len]);
    t.predicate_len = p_len;

    const o_len = @min(obj.len, MAX_ENTITY_LEN);
    @memcpy(t.object_buf[0..o_len], obj[0..o_len]);
    t.object_len = o_len;

    t.confidence = confidence;
    return t;
}

fn toLower(input: []const u8, buf: []u8) []const u8 {
    const len = @min(input.len, buf.len);
    for (0..len) |i| {
        buf[i] = if (input[i] >= 'A' and input[i] <= 'Z') input[i] + 32 else input[i];
    }
    return buf[0..len];
}

fn trimWhitespace(s: []const u8) []const u8 {
    var start: usize = 0;
    while (start < s.len and (s[start] == ' ' or s[start] == '\t' or s[start] == '\n' or s[start] == '\r')) {
        start += 1;
    }
    var end: usize = s.len;
    while (end > start and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\n' or s[end - 1] == '\r')) {
        end -= 1;
    }
    return s[start..end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — from spec test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "extract: Paris is the capital of France" {
    const result = extractTriples("Paris is the capital of France");
    try std.testing.expectEqual(@as(usize, 1), result.count);
    const t = result.get(0).?;
    try std.testing.expectEqualStrings("paris", t.subject());
    try std.testing.expectEqualStrings("is_capital_of", t.predicate());
    try std.testing.expectEqualStrings("france", t.object());
    try std.testing.expect(t.confidence >= 0.7);
}

test "extract: Python is a programming language" {
    const result = extractTriples("Python is a programming language");
    try std.testing.expectEqual(@as(usize, 1), result.count);
    const t = result.get(0).?;
    try std.testing.expectEqualStrings("python", t.subject());
    try std.testing.expectEqualStrings("is_a", t.predicate());
    try std.testing.expectEqualStrings("programming language", t.object());
    try std.testing.expect(t.confidence >= 0.7);
}

test "extract: The Earth has a diameter of 12742 km" {
    const result = extractTriples("The Earth has a diameter of 12742 km");
    try std.testing.expectEqual(@as(usize, 1), result.count);
    const t = result.get(0).?;
    try std.testing.expectEqualStrings("earth", t.subject());
    try std.testing.expectEqualStrings("has", t.predicate());
    try std.testing.expectEqualStrings("diameter of 12742 km", t.object());
    try std.testing.expect(t.confidence >= 0.6);
}

test "extract: Dogs are mammals" {
    const result = extractTriples("Dogs are mammals");
    try std.testing.expectEqual(@as(usize, 1), result.count);
    const t = result.get(0).?;
    try std.testing.expectEqualStrings("dogs", t.subject());
    try std.testing.expectEqualStrings("are", t.predicate());
    try std.testing.expectEqualStrings("mammals", t.object());
    try std.testing.expect(t.confidence >= 0.7);
}

test "extract: Water contains hydrogen and oxygen" {
    const result = extractTriples("Water contains hydrogen and oxygen");
    try std.testing.expectEqual(@as(usize, 1), result.count);
    const t = result.get(0).?;
    try std.testing.expectEqualStrings("water", t.subject());
    try std.testing.expectEqualStrings("contains", t.predicate());
    try std.testing.expectEqualStrings("hydrogen and oxygen", t.object());
    try std.testing.expect(t.confidence >= 0.7);
}

test "extract: multiple sentences" {
    const text = "Paris is the capital of France. Python is a programming language. Dogs are mammals.";
    const result = extractTriples(text);
    try std.testing.expectEqual(@as(usize, 3), result.count);
    try std.testing.expectEqualStrings("paris", result.get(0).?.subject());
    try std.testing.expectEqualStrings("python", result.get(1).?.subject());
    try std.testing.expectEqualStrings("dogs", result.get(2).?.subject());
}

test "extract: empty and short inputs" {
    const empty = extractTriples("");
    try std.testing.expectEqual(@as(usize, 0), empty.count);

    const short = extractTriples("Hi");
    try std.testing.expectEqual(@as(usize, 0), short.count);
}

test "normalizeEntity strips articles and lowercases" {
    var buf: [MAX_ENTITY_LEN]u8 = undefined;
    try std.testing.expectEqualStrings("earth", normalizeEntity("The Earth", &buf));

    var buf2: [MAX_ENTITY_LEN]u8 = undefined;
    try std.testing.expectEqualStrings("apple", normalizeEntity("  An Apple  ", &buf2));

    var buf3: [MAX_ENTITY_LEN]u8 = undefined;
    try std.testing.expectEqualStrings("cat", normalizeEntity("A Cat", &buf3));
}

test "scoreConfidence ranges" {
    // Strong copula_the pattern with good entity lengths
    const strong = scoreConfidence(5, 12, 6, .copula_the);
    try std.testing.expect(strong >= 0.9);

    // Weak generic pattern with short entity
    const weak = scoreConfidence(1, 10, 1, .generic_verb);
    try std.testing.expect(weak < 0.6);

    // All scores in [0, 1]
    const s = scoreConfidence(0, 0, 0, .generic_verb);
    try std.testing.expect(s >= 0.0 and s <= 1.0);
}

test "parseSentence returns null for non-matching" {
    try std.testing.expect(parseSentence("Hello world") == null);
    try std.testing.expect(parseSentence("Just some random text here") == null);
    try std.testing.expect(parseSentence("") == null);
}
