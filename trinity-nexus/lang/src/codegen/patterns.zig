// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN MATCHING - Modular DSL/VSA/ML/Lifecycle code generation patterns
// ═══════════════════════════════════════════════════════════════════════════════
//
// PAS (Predictive Algorithmic Systematics) Distribution:
//   D&C (Lifecycle/Control): 31% → lifecycle.zig
//   ALG (Generic/Algorithms): 22% → generic.zig
//   PRE (I/O/Preprocessing): 16% → io.zig
//   FDT (Data Transform): 13% → data.zig
//   MLS (ML/Statistics): 6% → ml.zig
//   TEN (VSA/Tensors): 6% → vsa.zig
//   HSH (Hashing): 4% → data.zig
//   PRB (Probabilistic): 2% → ml.zig
//
// Total patterns: 141+ across 7 modules
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const builder_mod = @import("builder.zig");

// Import modular pattern system
const patterns_mod = @import("patterns/mod.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

// Re-export category modules for direct access
pub const dsl = patterns_mod.dsl;
pub const lifecycle = patterns_mod.lifecycle;
pub const generic = patterns_mod.generic;
pub const io = patterns_mod.io;
pub const data = patterns_mod.data;
pub const ml = patterns_mod.ml;
pub const vsa = patterns_mod.vsa;

// Re-export types
pub const Category = patterns_mod.Category;
pub const MatchResult = patterns_mod.MatchResult;

/// PatternMatcher - Unified interface for code generation from behaviors
pub const PatternMatcher = struct {
    builder: *CodeBuilder,

    const Self = @This();

    pub fn init(builder: *CodeBuilder) Self {
        return Self{ .builder = builder };
    }

    /// Try to generate code from DSL patterns like $fs.*, $http.*, etc.
    pub fn generateFromDsLPattern(self: *Self, b: *const Behavior) !bool {
        return try dsl.match(self.builder, b);
    }

    /// Try to generate code from when/then pattern matching
    /// Delegates to modular pattern system
    pub fn generateFromWhenThenPattern(self: *Self, b: *const Behavior) !bool {
        // Try all pattern categories in PAS frequency order
        return try patterns_mod.matchAll(self.builder, b);
    }

    /// Match with category information for statistics
    pub fn matchWithCategory(self: *Self, b: *const Behavior) !MatchResult {
        return try patterns_mod.matchWithCategory(self.builder, b);
    }

    /// Get pattern statistics
    pub fn getStats() struct {
        dsl: u32,
        lifecycle: u32,
        generic: u32,
        io: u32,
        data: u32,
        ml: u32,
        vsa: u32,
        total: u32,
    } {
        return patterns_mod.getPatternCounts();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PatternMatcher init" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    const matcher = PatternMatcher.init(&builder);
    try testing.expect(matcher.builder == &builder);
}

test "DSL pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "readFile",
        .given = "path",
        .when = "$fs.read file",
        .then = "content",
    };

    const matched = try matcher.generateFromDsLPattern(&b);
    try testing.expect(matched);
}

test "Lifecycle pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "init",
        .given = "allocator",
        .when = "system starts",
        .then = "initialized",
    };

    const matched = try matcher.generateFromWhenThenPattern(&b);
    try testing.expect(matched);
}

test "ML pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "predict",
        .given = "input",
        .when = "model ready",
        .then = "output",
    };

    const matched = try matcher.generateFromWhenThenPattern(&b);
    try testing.expect(matched);
}

test "VSA pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "bindVectors",
        .given = "two vectors",
        .when = "bind operation",
        .then = "bound vector",
    };

    const matched = try matcher.generateFromWhenThenPattern(&b);
    try testing.expect(matched);
}

test "Generic pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "getValue",
        .given = "key",
        .when = "lookup",
        .then = "value",
    };

    const matched = try matcher.generateFromWhenThenPattern(&b);
    try testing.expect(matched);
}

test "I/O pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "readData",
        .given = "source",
        .when = "read from source",
        .then = "data",
    };

    const matched = try matcher.generateFromWhenThenPattern(&b);
    try testing.expect(matched);
}

test "Data transform pattern matching" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "encodeData",
        .given = "input",
        .when = "encode",
        .then = "encoded",
    };

    const matched = try matcher.generateFromWhenThenPattern(&b);
    try testing.expect(matched);
}

test "Pattern stats" {
    const testing = std.testing;
    const stats = PatternMatcher.getStats();
    try testing.expect(stats.total > 100);
}

test "Match with category" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);
    var matcher = PatternMatcher.init(&builder);

    const b = Behavior{
        .name = "trainModel",
        .given = "data",
        .when = "training",
        .then = "trained model",
    };

    const result = try matcher.matchWithCategory(&b);
    try testing.expect(result.matched);
    try testing.expectEqual(Category.ml, result.category);
}
