//! COMPTIME EMBEDDINGS v8.16 — Zero-Allocation Pattern Matching
//!
//! Pre-calculates 384-dim embeddings for common error patterns at compile time.
//! Enables fast pattern matching without runtime allocation.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");
const FixType = diagnostic.FixType;

/// Simple hash function for comptime embedding generation
fn simpleHash(str: []const u8, seed: usize) usize {
    @setEvalBranchQuota(5000);
    var h: usize = seed;
    for (str) |c| {
        h = h *% 31 +% @as(usize, @intCast(c));
    }
    return h;
}

/// Generate a 384-dimensional embedding at comptime
pub fn comptimeEmbedding(pattern: []const u8) [384]f64 {
    @setEvalBranchQuota(50000);
    var result: [384]f64 = undefined;

    for (0..384) |i| {
        // Simple pseudo-embedding based on pattern hash + position
        const hash_val = simpleHash(pattern, i);
        // Normalize to [0, 1]
        result[i] = @as(f64, @floatFromInt(hash_val % 10000)) / 10000.0;
    }

    return result;
}

/// Cosine similarity between two embeddings
pub fn cosineSimilarity(a: []const f64, b: []const f64) f64 {
    std.debug.assert(a.len == b.len);

    var dot: f64 = 0.0;
    var norm_a: f64 = 0.0;
    var norm_b: f64 = 0.0;

    for (0..a.len) |i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    if (norm_a == 0 or norm_b == 0) return 0.0;
    return dot / (@sqrt(norm_a) * @sqrt(norm_b));
}

/// Pre-computed error pattern with embedding
pub const ErrorPattern = struct {
    template: []const u8,
    fix_type: FixType,
    embedding: []const f64,

    /// Match confidence against error message
    pub fn matchConfidence(self: *const ErrorPattern, error_msg: []const u8) f64 {
        // Check if template is contained in error message
        if (std.mem.indexOf(u8, error_msg, self.template) != null) {
            return 0.95; // High confidence for direct match
        }

        // Calculate embedding similarity (only if no direct match)
        const error_embedding = comptimeEmbedding(error_msg);
        const similarity = cosineSimilarity(self.embedding, &error_embedding);

        // Higher threshold for similarity match (0.85 instead of 0.7)
        if (similarity > 0.85) {
            return similarity;
        }

        return 0.0;
    }
};

/// Pattern match result
pub const PatternMatch = struct {
    pattern: *const ErrorPattern,
    confidence: f64,
};

/// Best matching pattern from a list
pub fn findBestPattern(error_msg: []const u8, patterns: []const ErrorPattern) ?PatternMatch {
    if (patterns.len == 0) return null;

    var best_index: ?usize = null;
    var best_confidence: f64 = 0.6; // Higher minimum threshold

    for (patterns, 0..) |pattern, i| {
        const conf = pattern.matchConfidence(error_msg);
        // Prefer exact matches over partial matches
        if (conf > best_confidence or (conf == 0.95 and best_confidence == 0.95)) {
            best_confidence = conf;
            best_index = i;
        }
    }

    if (best_index) |idx| {
        return .{
            .pattern = &patterns[idx],
            .confidence = best_confidence,
        };
    }

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Comptime Pattern Library
// ═══════════════════════════════════════════════════════════════════════════════

/// Syntax error patterns
pub const SYNTAX_PATTERNS = [_]ErrorPattern{
    .{
        .template = "expected ';', found",
        .fix_type = .SYNTAX_FIX,
        .embedding = &comptimeEmbedding("expected ';', found"),
    },
    .{
        .template = "expected '}'",
        .fix_type = .SYNTAX_FIX,
        .embedding = &comptimeEmbedding("expected '}'"),
    },
    .{
        .template = "expected ','",
        .fix_type = .SYNTAX_FIX,
        .embedding = &comptimeEmbedding("expected ','"),
    },
    .{
        .template = "expected '('",
        .fix_type = .SYNTAX_FIX,
        .embedding = &comptimeEmbedding("expected '('"),
    },
    .{
        .template = "missing semicolon",
        .fix_type = .SYNTAX_FIX,
        .embedding = &comptimeEmbedding("missing semicolon"),
    },
};

/// Type error patterns
pub const TYPE_PATTERNS = [_]ErrorPattern{
    .{
        .template = "expected type",
        .fix_type = .TYPE_FIX,
        .embedding = &comptimeEmbedding("expected type"),
    },
    .{
        .template = "type mismatch",
        .fix_type = .TYPE_FIX,
        .embedding = &comptimeEmbedding("type mismatch"),
    },
    .{
        .template = "cannot convert",
        .fix_type = .TYPE_FIX,
        .embedding = &comptimeEmbedding("cannot convert"),
    },
    .{
        .template = "no member named",
        .fix_type = .TYPE_FIX,
        .embedding = &comptimeEmbedding("no member named"),
    },
};

/// Allocator error patterns
pub const ALLOCATOR_PATTERNS = [_]ErrorPattern{
    .{
        .template = "'allocator' in struct",
        .fix_type = .ALLOCATOR_FIX,
        .embedding = &comptimeEmbedding("'allocator' in struct"),
    },
    .{
        .template = "missing parameter: allocator",
        .fix_type = .ALLOCATOR_FIX,
        .embedding = &comptimeEmbedding("missing parameter: allocator"),
    },
    .{
        .template = "expected type parameter",
        .fix_type = .ALLOCATOR_FIX,
        .embedding = &comptimeEmbedding("expected type parameter"),
    },
};

/// Import error patterns
pub const IMPORT_PATTERNS = [_]ErrorPattern{
    .{
        .template = "no member named '",
        .fix_type = .IMPORT_FIX,
        .embedding = &comptimeEmbedding("no member named"),
    },
    .{
        .template = "undeclared identifier",
        .fix_type = .IMPORT_FIX,
        .embedding = &comptimeEmbedding("undeclared identifier"),
    },
    .{
        .template = "use of undeclared",
        .fix_type = .IMPORT_FIX,
        .embedding = &comptimeEmbedding("use of undeclared"),
    },
};

/// Comptime error patterns
pub const COMPTIME_PATTERNS = [_]ErrorPattern{
    .{
        .template = "expected type expression, found '",
        .fix_type = .COMPTIME_FIX,
        .embedding = &comptimeEmbedding("expected type expression, found"),
    },
    .{
        .template = "unable to evaluate comptime expression",
        .fix_type = .COMPTIME_FIX,
        .embedding = &comptimeEmbedding("unable to evaluate comptime expression"),
    },
    .{
        .template = "@setEvalBranchQuota",
        .fix_type = .COMPTIME_QUOTA_FIX,
        .embedding = &comptimeEmbedding("@setEvalBranchQuota"),
    },
};

/// All comptime patterns combined
pub const ALL_PATTERNS = blk: {
    @setEvalBranchQuota(500000);

    const total = SYNTAX_PATTERNS.len +
        TYPE_PATTERNS.len +
        ALLOCATOR_PATTERNS.len +
        IMPORT_PATTERNS.len +
        COMPTIME_PATTERNS.len;

    var all: [total]ErrorPattern = undefined;
    var idx: usize = 0;

    for (SYNTAX_PATTERNS) |p| {
        all[idx] = p;
        idx += 1;
    }
    for (TYPE_PATTERNS) |p| {
        all[idx] = p;
        idx += 1;
    }
    for (ALLOCATOR_PATTERNS) |p| {
        all[idx] = p;
        idx += 1;
    }
    for (IMPORT_PATTERNS) |p| {
        all[idx] = p;
        idx += 1;
    }
    for (COMPTIME_PATTERNS) |p| {
        all[idx] = p;
        idx += 1;
    }

    break :blk all;
};

/// Find best matching pattern from comptime library
pub fn findPattern(error_msg: []const u8) ?PatternMatch {
    return findBestPattern(error_msg, &ALL_PATTERNS);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "comptime embedding: deterministic" {
    const emb1 = comptimeEmbedding("expected ';'");
    const emb2 = comptimeEmbedding("expected ';'");

    try std.testing.expectEqualSlices(f64, &emb1, &emb2);
}

test "comptime embedding: different patterns" {
    const emb1 = comptimeEmbedding("expected ';'");
    const emb2 = comptimeEmbedding("expected '}'");

    // Should be different
    var equal_count: usize = 0;
    for (0..384) |i| {
        if (emb1[i] == emb2[i]) equal_count += 1;
    }

    // Less than 50% should be equal (statistically)
    try std.testing.expect(equal_count < 200);
}

test "cosine similarity: identical vectors" {
    const vec = [_]f64{ 1.0, 2.0, 3.0, 4.0 };
    const sim = cosineSimilarity(&vec, &vec);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), sim, 0.001);
}

test "cosine similarity: orthogonal vectors" {
    const v1 = [_]f64{ 1.0, 0.0, 0.0 };
    const v2 = [_]f64{ 0.0, 1.0, 0.0 };
    const sim = cosineSimilarity(&v1, &v2);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), sim, 0.001);
}

test "find pattern: direct match" {
    const result = findPattern("error: expected ';', found '}'");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(FixType.SYNTAX_FIX, result.?.pattern.fix_type);
    try std.testing.expect(result.?.confidence > 0.9);
}

test "find pattern: no match" {
    const result = findPattern("this is a completely unrelated error message");
    try std.testing.expect(result == null);
}

test "find pattern: allocator error" {
    const result = findPattern("error: missing parameter: allocator");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(FixType.ALLOCATOR_FIX, result.?.pattern.fix_type);
}

test "find pattern: type mismatch" {
    const result = findPattern("error: type mismatch: expected 'u32', found 'i32'");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(FixType.TYPE_FIX, result.?.pattern.fix_type);
}

test "ALL_PATTERNS: populated" {
    try std.testing.expect(ALL_PATTERNS.len > 0);

    // Verify all patterns have valid FixType
    for (ALL_PATTERNS) |pattern| {
        // Just ensure we can access the fix_type
        _ = pattern.fix_type;
    }
}
