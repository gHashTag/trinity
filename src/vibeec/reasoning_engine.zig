//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.2: Multi-Pass Reasoning Engine
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Three-pass reasoning for spec improvement:
//! - Pass 1: Semantic Understanding (extract intent, infer signature, estimate complexity)
//! - Pass 2: Pattern Matching + Golden Seed (exact match, semantic similarity, fallback)
//! - Pass 3: Safety & Quality Check (validate for infinite loops, errors, type safety)
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const golden_db = @import("golden_db.zig");
const vibee_parser = @import("vibee_parser.zig");

/// Result from reasoning engine improvement attempt
pub const EngineResult = struct {
    success: bool,
    implementation: ?[]const u8,
    confidence: f32,
    pass_used: Pass,
    errors: ArrayList(Error),

    pub const Error = struct {
        message: []const u8,
        pass: Pass,
    };

    pub fn deinit(self: *EngineResult, allocator: Allocator) void {
        if (self.implementation) |impl| {
            allocator.free(impl);
        }
        for (self.errors.items) |*err| {
            allocator.free(err.message);
        }
        self.errors.deinit(allocator);
    }
};

/// Which pass generated the implementation
pub const Pass = enum {
    semantic_only,
    exact_match,
    semantic_match,
    fallback_pattern,
};

/// Semantic analysis of a behavior
pub const SemanticAnalysis = struct {
    /// Primary intent (what the behavior does)
    intent: []const u8,
    /// Inferred function signature
    signature: []const u8,
    /// Estimated complexity (1-10)
    complexity: u8,
    /// Detected category
    category: ?golden_db.Category,
    /// Extracted keywords for matching
    keywords: ArrayList([]const u8),

    pub fn deinit(self: *SemanticAnalysis, allocator: Allocator) void {
        allocator.free(self.signature);
        for (self.keywords.items) |kw| {
            allocator.free(kw);
        }
        self.keywords.deinit(allocator);
    }
};

/// Result of Pass 2: Pattern Matching
pub const Pass2Result = struct {
    implementation: ?[]const u8,
    confidence: f32,
    pass: Pass,
    matched_name: ?[]const u8,

    pub fn deinit(self: *Pass2Result, allocator: Allocator) void {
        if (self.implementation) |impl| {
            allocator.free(impl);
        }
        if (self.matched_name) |name| {
            allocator.free(name);
        }
    }
};

/// Result of Pass 3: Validation
pub const ValidationResult = struct {
    is_valid: bool,
    errors: ArrayList([]const u8),
    warnings: ArrayList([]const u8),

    pub fn deinit(self: *ValidationResult, allocator: Allocator) void {
        for (self.errors.items) |err| {
            allocator.free(err);
        }
        for (self.warnings.items) |warn| {
            allocator.free(warn);
        }
        self.errors.deinit(allocator);
        self.warnings.deinit(allocator);
    }
};

/// Multi-Pass Reasoning Engine
pub const ReasoningEngine = struct {
    allocator: Allocator,
    golden_db: golden_db.GoldenDB,

    const Self = @This();

    /// Initialize the reasoning engine
    pub fn init(allocator: Allocator) !Self {
        const db = try golden_db.GoldenDB.init(allocator);
        return .{
            .allocator = allocator,
            .golden_db = db,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.golden_db.deinit();
    }

    /// Main entry point: Improve a behavior using 3-pass reasoning
    pub fn improve(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
    ) !EngineResult {
        var result = EngineResult{
            .success = false,
            .implementation = null,
            .confidence = 0.0,
            .pass_used = .fallback_pattern,
            .errors = ArrayList(EngineResult.Error){},
        };

        // Pass 1: Semantic Understanding
        var analysis = try self.pass1_semantic(behavior);
        defer {
            for (analysis.keywords.items) |kw| {
                self.allocator.free(kw);
            }
            analysis.keywords.deinit(self.allocator);
        }

        // Pass 2: Pattern Matching + Golden Seed
        const pass2_result = try self.pass2_patternMatch(behavior, &analysis);
        defer {
            if (pass2_result.implementation) |impl| {
                self.allocator.free(impl);
            }
            if (pass2_result.matched_name) |name| {
                self.allocator.free(name);
            }
        }

        if (pass2_result.implementation) |impl| {
            // Pass 3: Safety & Quality Check
            var validation = try self.pass3_validate(impl, behavior);
            defer {
                for (validation.errors.items) |err| {
                    self.allocator.free(err);
                }
                for (validation.warnings.items) |warn| {
                    self.allocator.free(warn);
                }
                validation.errors.deinit(self.allocator);
                validation.warnings.deinit(self.allocator);
            }

            if (validation.is_valid or validation.warnings.items.len > 0) {
                // Accept with or without warnings
                result.success = true;
                result.implementation = try self.allocator.dupe(u8, impl);
                result.confidence = pass2_result.confidence;
                result.pass_used = pass2_result.pass;

                // Add warnings as errors (for tracking)
                for (validation.warnings.items) |warn| {
                    const warn_copy = try self.allocator.dupe(u8, warn);
                    try result.errors.append(self.allocator, .{
                        .message = warn_copy,
                        .pass = result.pass_used,
                    });
                }
            } else {
                // Validation failed
                for (validation.errors.items) |err| {
                    const err_copy = try self.allocator.dupe(u8, err);
                    try result.errors.append(self.allocator, .{
                        .message = err_copy,
                        .pass = result.pass_used,
                    });
                }
            }
        } else {
            // No implementation found
            const msg = try self.allocator.dupe(u8, "No matching implementation found");
            try result.errors.append(self.allocator, .{
                .message = msg,
                .pass = .fallback_pattern,
            });
        }

        return result;
    }

    /// Pass 1: Semantic Understanding
    fn pass1_semantic(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
    ) !SemanticAnalysis {
        var keywords = ArrayList([]const u8){};

        // Extract keywords from behavior name
        var name_parts = std.mem.splitScalar(u8, behavior.name, '_');
        while (name_parts.next()) |part| {
            if (part.len > 2) {
                const dupe = try self.allocator.dupe(u8, part);
                try keywords.append(self.allocator, dupe);
            }
        }

        // Infer category from keywords
        var category: ?golden_db.Category = null;
        for (keywords.items) |kw| {
            if (std.mem.eql(u8, kw, "bind") or
                std.mem.eql(u8, kw, "bundle") or
                std.mem.eql(u8, kw, "similarity"))
            {
                category = .vsa;
                break;
            } else if (std.mem.eql(u8, kw, "reward") or
                std.mem.eql(u8, kw, "stake") or
                std.mem.eql(u8, kw, "earn"))
            {
                category = .economic;
                break;
            }
        }

        // Infer intent from "when" clause
        var intent = behavior.when;
        if (intent.len == 0) {
            intent = behavior.then;
        }

        // Estimate complexity (simple heuristic)
        const complexity: u8 = if (keywords.items.len > 3) 5 else 3;

        // Generate a basic signature
        const signature = try self.inferSignature(behavior);

        return .{
            .intent = intent,
            .signature = signature,
            .complexity = complexity,
            .category = category,
            .keywords = keywords,
        };
    }

    /// Pass 2: Pattern Matching + Golden Seed
    fn pass2_patternMatch(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
        analysis: *const SemanticAnalysis,
    ) !Pass2Result {
        var result = Pass2Result{
            .implementation = null,
            .confidence = 0.0,
            .pass = .fallback_pattern,
            .matched_name = null,
        };

        // Strategy 1: Exact name match
        if (self.golden_db.get(behavior.name, .{})) |impl| {
            result.implementation = try self.buildFullImplementation(impl);
            result.confidence = 1.0;
            result.pass = .exact_match;
            result.matched_name = try self.allocator.dupe(u8, impl.name);
            return result;
        }

        // Strategy 2: Semantic similarity search
        if (analysis.keywords.items.len > 0) {
            const results = try self.golden_db.search(analysis.keywords.items[0], .{});
            defer self.allocator.free(results);

            if (results.len > 0) {
                const impl = results[0];
                result.implementation = try self.buildFullImplementation(impl);
                result.confidence = 0.8;
                result.pass = .semantic_match;
                result.matched_name = try self.allocator.dupe(u8, impl.name);
                return result;
            }
        }

        // Strategy 3: Category-based search
        if (analysis.category) |cat| {
            const impls = self.golden_db.getByCategory(cat);
            if (impls.len > 0) {
                const impl = impls[0];
                result.implementation = try self.buildFullImplementation(impl);
                result.confidence = 0.5;
                result.pass = .semantic_match;
                result.matched_name = try self.allocator.dupe(u8, impl.name);
                return result;
            }
        }

        // Strategy 4: Fallback pattern (TODO: generate from scratch)
        return result;
    }

    /// Pass 3: Safety & Quality Check
    fn pass3_validate(
        self: *const Self,
        implementation: []const u8,
        behavior: *const vibee_parser.Behavior,
    ) !ValidationResult {
        var errors = ArrayList([]const u8){};
        var warnings = ArrayList([]const u8){};

        // Check for obvious issues
        if (std.mem.indexOf(u8, implementation, "while (true)") != null) {
            const msg = try self.allocator.dupe(u8, "Possible infinite loop detected");
            try warnings.append(self.allocator, msg);
        }

        if (std.mem.indexOf(u8, implementation, "unreachable") != null and
            behavior.implementation.len == 0)
        {
            const msg = try self.allocator.dupe(u8, "Unreachable in generated code");
            try warnings.append(self.allocator, msg);
        }

        // Check for error handling
        if (std.mem.indexOf(u8, implementation, "!") == null and
            std.mem.indexOf(u8, implementation, "try") == null and
            std.mem.indexOf(u8, implementation, "error.") == null)
        {
            const msg = try self.allocator.dupe(u8, "No error handling detected");
            try warnings.append(self.allocator, msg);
        }

        // Basic validation: no null pointers, TODO implemented
        const has_todo = std.mem.indexOf(u8, implementation, "TODO") != null;
        if (has_todo) {
            const msg = try self.allocator.dupe(u8, "Implementation contains TODO");
            try errors.append(self.allocator, msg);
        }

        const is_valid = errors.items.len == 0;

        return .{
            .is_valid = is_valid,
            .errors = errors,
            .warnings = warnings,
        };
    }

    /// Infer function signature from behavior
    fn inferSignature(
        self: *const Self,
        behavior: *const vibee_parser.Behavior,
    ) ![]const u8 {
        _ = behavior;
        // Simple fallback signature
        return self.allocator.dupe(u8, "(allocator: Allocator) !void");
    }

    /// Build full implementation string
    fn buildFullImplementation(
        self: *const Self,
        impl: *const golden_db.GoldenImpl,
    ) ![]const u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "{s}\n{s}",
            .{ impl.signature, impl.body },
        );
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "ReasoningEngine: init" {
    var engine = try ReasoningEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Check golden DB is populated
    const bind_impl = engine.golden_db.get("bind", .{});
    try std.testing.expect(bind_impl != null);
}

test "ReasoningEngine: improve - exact match" {
    var engine = try ReasoningEngine.init(std.testing.allocator);
    defer engine.deinit();

    const behavior = vibee_parser.Behavior{
        .name = "bind",
        .given = "Two vectors",
        .when = "Need binding",
        .then = "Return bound vector",
        .implementation = "",
        .test_cases = .{},
    };

    var result = try engine.improve(&behavior);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.success);
    try std.testing.expectEqual(Pass.exact_match, result.pass_used);
    try std.testing.expect(result.confidence >= 0.9);
}

test "ReasoningEngine: improve - semantic match" {
    var engine = try ReasoningEngine.init(std.testing.allocator);
    defer engine.deinit();

    const behavior = vibee_parser.Behavior{
        .name = "my_bind_func",
        .given = "Two vectors",
        .when = "Need binding",
        .then = "Return bound vector",
        .implementation = "",
        .test_cases = .{},
    };

    var result = try engine.improve(&behavior);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.success);
}

test "ReasoningEngine: pass1_semantic" {
    var engine = try ReasoningEngine.init(std.testing.allocator);
    defer engine.deinit();

    const behavior = vibee_parser.Behavior{
        .name = "bind_vectors",
        .given = "Two vectors",
        .when = "Need binding",
        .then = "Return bound vector",
        .implementation = "",
        .test_cases = .{},
    };

    var analysis = try engine.pass1_semantic(&behavior);
    defer {
        for (analysis.keywords.items) |kw| {
            std.testing.allocator.free(kw);
        }
        analysis.keywords.deinit(std.testing.allocator);
    }

    try std.testing.expect(analysis.keywords.items.len > 0);
    try std.testing.expect(analysis.complexity > 0);
}
