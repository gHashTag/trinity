// ═══════════════════════════════════════════════════════════════════════════════
// SYM-004: KG Pipeline — Extract triples from LLM responses, store in KG
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wraps triples_parser.extractTriples() + ChatKnowledgeGraph.addFact().
// Called from igla_hybrid_chat.respond() after LLM response.
//
// Tech Tree: SYM-004 (Symbolic branch, unlocks SYM-005)
// Generated from: specs/tri/igla_kg_pipeline.tri
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const triples_parser = @import("triples_parser.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MIN_EXTRACTION_CONFIDENCE: f64 = 0.6;
pub const MIN_LLM_CONFIDENCE: f64 = 0.5;

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE STATS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PipelineStats = struct {
    responses_processed: u64 = 0,
    triples_extracted: u64 = 0,
    triples_stored: u64 = 0,
    triples_skipped_low_conf: u64 = 0,
    triples_skipped_err: u64 = 0,
};

// Global stats (matches g_last_wave_state pattern in igla_hybrid_chat)
pub var g_pipeline_stats = PipelineStats{};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE PIPELINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract triples from LLM response text and store in KG.
/// Called from igla_hybrid_chat.respond() after reflection + VSA memory save.
/// KG interface: must have addFact(subject, relation, object) method.
pub fn extractAndStore(response_text: []const u8, kgraph: anytype) void {
    g_pipeline_stats.responses_processed += 1;

    const extraction = triples_parser.extractTriples(response_text);
    if (extraction.count == 0) return;

    for (0..extraction.count) |i| {
        if (extraction.get(i)) |triple| {
            // Filter by extraction confidence
            if (triple.confidence < MIN_EXTRACTION_CONFIDENCE) {
                g_pipeline_stats.triples_skipped_low_conf += 1;
                continue;
            }

            g_pipeline_stats.triples_extracted += 1;

            // Store in KG (silent fail — don't break chat flow)
            kgraph.addFact(
                triple.subject(),
                triple.predicate(),
                triple.object(),
            ) catch {
                g_pipeline_stats.triples_skipped_err += 1;
                continue;
            };

            g_pipeline_stats.triples_stored += 1;
        }
    }
}

/// Check if extraction should proceed based on reflection status and confidence.
pub fn shouldExtract(reflection_learned: bool, llm_confidence: f64) bool {
    return reflection_learned and llm_confidence >= MIN_LLM_CONFIDENCE;
}

/// Get current pipeline stats.
pub fn getStats() PipelineStats {
    return g_pipeline_stats;
}

/// Reset stats (for testing).
pub fn resetStats() void {
    g_pipeline_stats = PipelineStats{};
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Mock KG for testing (matches ChatKnowledgeGraph.addFact signature)
const MockKG = struct {
    facts: [32]MockFact = [_]MockFact{.{}} ** 32,
    count: usize = 0,
    fail_next: bool = false,

    const MockFact = struct {
        subject_buf: [128]u8 = [_]u8{0} ** 128,
        subject_len: usize = 0,
        relation_buf: [64]u8 = [_]u8{0} ** 64,
        relation_len: usize = 0,
        object_buf: [128]u8 = [_]u8{0} ** 128,
        object_len: usize = 0,
    };

    pub fn addFact(self: *MockKG, subject: []const u8, relation: []const u8, object: []const u8) !void {
        if (self.fail_next) return error.KGFull;
        if (self.count >= 32) return error.KGFull;
        var f = &self.facts[self.count];
        const sl = @min(subject.len, 128);
        @memcpy(f.subject_buf[0..sl], subject[0..sl]);
        f.subject_len = sl;
        const rl = @min(relation.len, 64);
        @memcpy(f.relation_buf[0..rl], relation[0..rl]);
        f.relation_len = rl;
        const ol = @min(object.len, 128);
        @memcpy(f.object_buf[0..ol], object[0..ol]);
        f.object_len = ol;
        self.count += 1;
    }
};

test "pipeline: extract and store single triple" {
    resetStats();
    var mock_kg = MockKG{};
    extractAndStore("Paris is the capital of France", &mock_kg);
    try std.testing.expectEqual(@as(usize, 1), mock_kg.count);
    try std.testing.expectEqualStrings("paris", mock_kg.facts[0].subject_buf[0..mock_kg.facts[0].subject_len]);
    try std.testing.expectEqualStrings("is_capital_of", mock_kg.facts[0].relation_buf[0..mock_kg.facts[0].relation_len]);
    try std.testing.expectEqualStrings("france", mock_kg.facts[0].object_buf[0..mock_kg.facts[0].object_len]);
    try std.testing.expectEqual(@as(u64, 1), g_pipeline_stats.responses_processed);
    try std.testing.expectEqual(@as(u64, 1), g_pipeline_stats.triples_stored);
}

test "pipeline: extract multiple triples from multi-sentence" {
    resetStats();
    var mock_kg = MockKG{};
    extractAndStore("Paris is the capital of France. Python is a programming language. Dogs are mammals.", &mock_kg);
    try std.testing.expectEqual(@as(usize, 3), mock_kg.count);
    try std.testing.expectEqual(@as(u64, 3), g_pipeline_stats.triples_stored);
}

test "pipeline: no triples from non-matching text" {
    resetStats();
    var mock_kg = MockKG{};
    extractAndStore("Hello world", &mock_kg);
    try std.testing.expectEqual(@as(usize, 0), mock_kg.count);
    try std.testing.expectEqual(@as(u64, 0), g_pipeline_stats.triples_extracted);
}

test "pipeline: shouldExtract logic" {
    try std.testing.expect(shouldExtract(true, 0.8));
    try std.testing.expect(shouldExtract(true, 0.5));
    try std.testing.expect(!shouldExtract(false, 0.8));
    try std.testing.expect(!shouldExtract(true, 0.3));
    try std.testing.expect(!shouldExtract(false, 0.3));
}

test "pipeline: KG error handling (silent fail)" {
    resetStats();
    var mock_kg = MockKG{};
    mock_kg.fail_next = true;
    extractAndStore("Paris is the capital of France", &mock_kg);
    try std.testing.expectEqual(@as(usize, 0), mock_kg.count);
    try std.testing.expectEqual(@as(u64, 1), g_pipeline_stats.triples_skipped_err);
}

test "pipeline: stats accumulate across calls" {
    resetStats();
    var mock_kg = MockKG{};
    extractAndStore("Paris is the capital of France", &mock_kg);
    extractAndStore("Dogs are mammals", &mock_kg);
    try std.testing.expectEqual(@as(u64, 2), g_pipeline_stats.responses_processed);
    try std.testing.expectEqual(@as(u64, 2), g_pipeline_stats.triples_stored);
    try std.testing.expectEqual(@as(usize, 2), mock_kg.count);
}
