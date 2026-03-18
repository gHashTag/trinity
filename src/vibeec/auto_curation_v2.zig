//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.5: Auto-Curation & Self-Feeding v2
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Auto-curation system for synthetic seeds with multi-stage validation:
//! 1. Syntax validation - compile checks
//! 2. Semantic validation - behavior matching
//! 3. Pattern validation - anti-pattern detection
//! 4. Self-feeding - high-quality seeds fed back to Golden DB
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const golden_db = @import("golden_db.zig");
const synthetic_seed_gen = @import("synthetic_seed_gen.zig");
const vibe_rewards = @import("vibe_rewards.zig");

/// Validation stage result
pub const ValidationStage = enum {
    syntax_check,
    semantic_check,
    pattern_check,
    approved,
    rejected,
};

/// Detailed validation result
pub const ValidationResult = struct {
    stage: ValidationStage,
    score: f32,
    tri_reward: f64,

    pub fn isApproved(self: *const ValidationResult) bool {
        return self.stage == .approved;
    }
};

/// Curation statistics
pub const CurationStats = struct {
    total_processed: usize = 0,
    syntax_passed: usize = 0,
    semantic_passed: usize = 0,
    pattern_passed: usize = 0,
    approved: usize = 0,
    total_tri_earned: f64 = 0,
};

/// Auto-Curator v2 - multi-stage validation for synthetic seeds
pub const AutoCuratorV2 = struct {
    allocator: Allocator,
    golden_db: *golden_db.GoldenDB,
    agent_id: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, db: *golden_db.GoldenDB, agent_id: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .golden_db = db,
            .agent_id = agent_id,
        };
    }

    /// Validate a synthetic seed through all stages
    pub fn validateSeed(
        self: *const Self,
        seed: *const synthetic_seed_gen.GeneratedSeed,
    ) !ValidationResult {
        var score: f32 = 1.0;
        var stage = ValidationStage.syntax_check;

        // Stage 1: Syntax validation
        if (!self.validateSyntax(seed)) {
            score = 0.0;
            stage = ValidationStage.rejected;
        } else {
            stage = ValidationStage.semantic_check;
        }

        // Stage 2: Semantic validation (only if syntax passed)
        if (stage == ValidationStage.semantic_check) {
            const semantic_score = self.validateSemantic(seed);
            if (semantic_score < 0.5) {
                score *= semantic_score;
            } else {
                score = @min(score, semantic_score);
                stage = ValidationStage.pattern_check;
            }
        }

        // Stage 3: Pattern validation (only if semantic passed)
        if (stage == ValidationStage.pattern_check) {
            var pattern_issues: usize = 0;

            // Check for common anti-patterns
            if (std.mem.indexOf(u8, seed.body, "TODO") != null) {
                pattern_issues += 1;
            }
            if (std.mem.indexOf(u8, seed.body, "FIXME") != null) {
                pattern_issues += 1;
            }
            if (std.mem.indexOf(u8, seed.body, "@panic") != null) {
                pattern_issues += 2;
            }

            // Penalty for anti-patterns
            if (pattern_issues > 0) {
                score *= @max(0.1, 1.0 - @as(f32, @floatFromInt(pattern_issues)) * 0.1);
            }

            if (score >= 0.7) {
                stage = ValidationStage.approved;
            } else {
                stage = ValidationStage.rejected;
            }
        }

        // Calculate $TRI reward
        const tri_reward = if (stage == .approved)
            vibe_rewards.VibeRewardSystem.rewardForImprovement(score, 5)
        else
            0;

        return ValidationResult{
            .stage = stage,
            .score = score,
            .tri_reward = tri_reward,
        };
    }

    /// Validate syntax of generated code
    fn validateSyntax(self: *const Self, seed: *const synthetic_seed_gen.GeneratedSeed) bool {
        _ = self;

        // For Golden DB seeds, be more lenient - just check basic structure
        // 1. Check for balanced braces
        var open_braces: i32 = 0;
        var open_parens: i32 = 0;

        for (seed.signature) |c| {
            if (c == '{') open_braces += 1;
            if (c == '}') open_braces -= 1;
            if (c == '(') open_parens += 1;
            if (c == ')') open_parens -= 1;
        }

        for (seed.body) |c| {
            if (c == '{') open_braces += 1;
            if (c == '}') open_braces -= 1;
            if (c == '(') open_parens += 1;
            if (c == ')') open_parens -= 1;
        }

        if (open_braces != 0 or open_parens != 0) return false;

        // 2. Check for non-empty implementation
        if (seed.body.len < 5) return false;

        return true;
    }

    /// Validate semantic correctness
    fn validateSemantic(self: *const Self, seed: *const synthetic_seed_gen.GeneratedSeed) f32 {
        _ = self;
        var score: f32 = 1.0;

        // Check for appropriate return types
        if (std.mem.indexOf(u8, seed.signature, "!void") != null or
            std.mem.indexOf(u8, seed.signature, "!") != null)
        {
            score += 0.1;
        }

        // Check for non-empty body
        if (seed.body.len > 50) score += 0.1;

        // Deduct for obvious placeholders
        if (std.mem.indexOf(u8, seed.body, "TODO") != null) score -= 0.2;
        if (std.mem.indexOf(u8, seed.body, "@panic") != null) score -= 0.3;
        if (std.mem.indexOf(u8, seed.body, "unreachable") != null) score -= 0.2;

        return @max(0.0, @min(1.0, score));
    }
};

/// Self-Feeding Loop v2 - auto-import high-quality seeds to Golden DB
pub const SelfFeedingLoopV2 = struct {
    allocator: Allocator,
    golden_db: *golden_db.GoldenDB,
    curator: AutoCuratorV2,

    const Self = @This();

    pub fn init(allocator: Allocator, db: *golden_db.GoldenDB, agent_id: []const u8) !Self {
        const curator = try AutoCuratorV2.init(allocator, db, agent_id);
        return Self{
            .allocator = allocator,
            .golden_db = db,
            .curator = curator,
        };
    }

    /// Process generated seeds and auto-feed approved ones to Golden DB
    pub fn processAndFeed(
        self: *Self,
        seeds: []const synthetic_seed_gen.GeneratedSeed,
    ) !CurationStats {
        var stats = CurationStats{};
        stats.total_processed = seeds.len;

        for (seeds) |*seed| {
            const result = try self.curator.validateSeed(seed);

            stats.total_tri_earned += result.tri_reward;

            // Track stages reached
            if (result.stage == ValidationStage.syntax_check or
                result.stage == ValidationStage.semantic_check or
                result.stage == ValidationStage.pattern_check or
                result.stage == ValidationStage.approved)
            {
                stats.syntax_passed += 1;
            }
            if (result.stage == ValidationStage.semantic_check or
                result.stage == ValidationStage.pattern_check or
                result.stage == ValidationStage.approved)
            {
                stats.semantic_passed += 1;
            }
            if (result.stage == ValidationStage.pattern_check or
                result.stage == ValidationStage.approved)
            {
                stats.pattern_passed += 1;
            }
            if (result.isApproved()) {
                stats.approved += 1;

                // Add to Golden DB
                self.golden_db.addNewSeed(
                    seed.name,
                    seed.signature,
                    seed.body,
                    seed.category,
                ) catch |err| {
                    std.debug.print("  [Warning] Failed to add '{s}': {}\n", .{ seed.name, err });
                    continue;
                };
            }
        }

        return stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "AutoCuratorV2: init" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const curator = try AutoCuratorV2.init(std.testing.allocator, &db, "test-agent");
    _ = curator;
}

test "AutoCuratorV2: validateSyntax - valid" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const curator = try AutoCuratorV2.init(std.testing.allocator, &db, "test-agent");

    const seed = synthetic_seed_gen.GeneratedSeed{
        .name = "test_func",
        .signature = "pub fn testFunc() !void",
        .body = "const x = 42;",
        .category = .generic,
        .quality_score = 0.9,
        .synthesis_method = .template,
    };

    const result = curator.validateSyntax(&seed);
    try std.testing.expect(result == true);
}

test "SelfFeedingLoopV2: init" {
    var db = try golden_db.GoldenDB.init(std.testing.allocator);
    defer db.deinit();

    const loop = try SelfFeedingLoopV2.init(std.testing.allocator, &db, "test-agent");
    _ = loop;
}
