// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN ENGINE - Core Pattern Application for VIBEE Code Generation
// ═══════════════════════════════════════════════════════════════════════════════
// Applies code patterns to behavior specifications to generate implementation code
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Pattern = struct {
    name: []const u8,
    category: []const u8, // e.g., "dsl", "vsa", "metal", "algorithm", "datastructure"
    template: []const u8,
    placeholders: []const []const u8, // Variable names in template (e.g., {"type", "func"})
    description: []const u8,

    pub fn init(allocator: Allocator, name: []const u8, category: []const u8) Pattern {
        _ = allocator;
        return Pattern{
            .name = name,
            .category = category,
            .template = "",
            .placeholders = &.{},
            .description = "",
        };
    }

    pub fn deinit(self: Pattern, allocator: Allocator) void {
        _ = self;
        _ = allocator;
        // Strings are slices, no deallocation needed
        // placeholder list is const slice, no deallocation
    }
};

pub const GeneratedCode = struct {
    code: []const u8,
    language: []const u8,
    metadata: CodeMetadata,

    pub fn init(allocator: Allocator, code: []const u8, language: []const u8) GeneratedCode {
        _ = allocator;
        return GeneratedCode{
            .code = code,
            .language = language,
            .metadata = CodeMetadata{},
        };
    }

    pub fn deinit(self: GeneratedCode, allocator: Allocator) void {
        allocator.free(self.code);
        // Deinit metadata (need mutable reference)
        var metadata_mut = self.metadata;
        metadata_mut.deinit(allocator);
    }
};

pub const CodeMetadata = struct {
    patterns_used: ArrayList([]const u8),
    confidence: f64,
    generation_time_ns: u64,

    pub fn init() CodeMetadata {
        return CodeMetadata{
            .patterns_used = .{},
            .confidence = 0.0,
            .generation_time_ns = 0,
        };
    }

    pub fn deinit(self: *CodeMetadata, allocator: Allocator) void {
        for (self.patterns_used.items) |p| {
            allocator.free(p);
        }
        self.patterns_used.deinit(allocator);
    }
};

pub const Context = struct {
    allocator: Allocator,
    spec_name: []const u8,
    target_language: []const u8,
    variables: std.StringHashMap([]const u8),
    imports: ArrayList([]const u8),

    pub fn init(allocator: Allocator, spec_name: []const u8, target_language: []const u8) Context {
        return Context{
            .allocator = allocator,
            .spec_name = spec_name,
            .target_language = target_language,
            .variables = std.StringHashMap([]const u8).init(allocator),
            .imports = .{},
        };
    }

    pub fn deinit(self: *Context) void {
        var iter = self.variables.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.variables.deinit();

        for (self.imports.items) |imp| {
            self.allocator.free(imp);
        }
        self.imports.deinit(self.allocator);
    }

    pub fn setVariable(self: *Context, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        // Remove old value if exists
        if (self.variables.fetchRemove(key)) |old_entry| {
            self.allocator.free(old_entry.value);
            self.allocator.free(old_entry.key);
        }

        try self.variables.put(key_copy, value_copy);
    }

    pub fn getVariable(self: *const Context, key: []const u8) ?[]const u8 {
        return self.variables.get(key);
    }

    pub fn addImport(self: *Context, import_stmt: []const u8) !void {
        const import_copy = try self.allocator.dupe(u8, import_stmt);
        try self.imports.append(self.allocator, import_copy);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const PatternEngine = struct {
    allocator: Allocator,
    patterns: std.StringHashMap(Pattern),

    const Self = @This();

    pub fn init(allocator: Allocator) PatternEngine {
        return PatternEngine{
            .allocator = allocator,
            .patterns = std.StringHashMap(Pattern).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.patterns.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.patterns.deinit();
    }

    /// Register a pattern in the engine
    pub fn registerPattern(self: *Self, pattern: Pattern) !void {
        const name_copy = try self.allocator.dupe(u8, pattern.name);
        errdefer self.allocator.free(name_copy);

        // Remove old pattern if exists
        if (self.patterns.fetchRemove(pattern.name)) |old_entry| {
            old_entry.value.deinit(self.allocator);
            self.allocator.free(old_entry.key);
        }

        try self.patterns.put(name_copy, pattern);
    }

    /// Find best matching pattern for a behavior description
    pub fn findPattern(self: *const Self, given: []const u8, when: []const u8, then: []const u8) !?Pattern {
        const combined = try std.fmt.allocPrint(self.allocator, "{s} {s} {s}", .{ given, when, then });
        defer self.allocator.free(combined);

        var best_pattern: ?Pattern = null;
        var best_score: f64 = 0.0;

        var iter = self.patterns.iterator();
        while (iter.next()) |entry| {
            const pattern = entry.value_ptr.*;
            const score = computeSimilarity(combined, pattern.description);

            if (score > best_score and score > 0.3) { // Threshold for pattern match
                best_score = score;
                best_pattern = pattern;
            }
        }

        return best_pattern;
    }

    /// Apply a pattern to generate code from behavior spec
    pub fn applyPattern(self: *Self, pattern: Pattern, behavior: anytype) !GeneratedCode {
        const start_time = std.time.nanoTimestamp();

        // Create context
        var ctx = Context.init(self.allocator, behavior.name, "zig");
        defer {
            // Clean up variables before deinit
            var var_iter = ctx.variables.iterator();
            while (var_iter.next()) |entry| {
                self.allocator.free(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            ctx.variables.deinit();

            for (ctx.imports.items) |imp| {
                self.allocator.free(imp);
            }
            ctx.imports.deinit(self.allocator);
        }

        // Extract variables from behavior
        try ctx.setVariable("name", behavior.name);
        try ctx.setVariable("given", behavior.given);
        try ctx.setVariable("when", behavior.when);
        try ctx.setVariable("then", behavior.then);

        // Apply template substitution
        const code = try self.substituteTemplate(pattern.template, &ctx);

        var metadata = CodeMetadata.init();
        metadata.generation_time_ns = @intCast(std.time.nanoTimestamp() - start_time);
        metadata.confidence = 1.0; // Direct pattern application

        try metadata.patterns_used.append(self.allocator, try self.allocator.dupe(u8, pattern.name));

        return GeneratedCode{
            .code = code,
            .language = "zig",
            .metadata = metadata,
        };
    }

    /// Substitute placeholders in template with context variables
    fn substituteTemplate(self: *const Self, template: []const u8, ctx: *const Context) ![]u8 {
        // Estimate size: template length * 1.5 for substitutions
        var result = try self.allocator.alloc(u8, template.len * 3 / 2);
        var result_len: usize = 0;

        var i: usize = 0;
        while (i < template.len) {
            if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '{') {
                // Found placeholder start
                const end_idx = std.mem.indexOf(u8, template[i..], "}}") orelse return error.InvalidTemplate;
                const placeholder_name = template[i + 2 .. i + end_idx];

                // Look up variable
                const value = ctx.getVariable(placeholder_name) orelse "";

                // Substitute
                if (result_len + value.len > result.len) {
                    // Need to grow
                    const new_len = result.len * 2;
                    const new_result = try self.allocator.realloc(result, new_len);
                    result = new_result;
                }
                @memcpy(result[result_len..][0..value.len], value);
                result_len += value.len;

                i += end_idx + 2;
            } else {
                if (result_len >= result.len) {
                    const new_len = result.len * 2;
                    const new_result = try self.allocator.realloc(result, new_len);
                    result = new_result;
                }
                result[result_len] = template[i];
                result_len += 1;
                i += 1;
            }
        }

        return self.allocator.realloc(result, result_len);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute similarity between two text descriptions (simplified Jaccard)
fn computeSimilarity(text1: []const u8, text2: []const u8) f64 {
    // Simple word overlap for now
    var words1 = std.StringHashMap(void).init(std.heap.page_allocator);
    defer words1.deinit();

    var words2 = std.StringHashMap(void).init(std.heap.page_allocator);
    defer words2.deinit();

    // Tokenize (split by whitespace)
    {
        var iter = std.mem.tokenizeScalar(u8, text1, ' ');
        while (iter.next()) |word| {
            words1.put(word, {}) catch {};
        }
    }

    {
        var iter = std.mem.tokenizeScalar(u8, text2, ' ');
        while (iter.next()) |word| {
            words2.put(word, {}) catch {};
        }
    }

    // Compute intersection
    var intersection: usize = 0;
    var iter = words1.iterator();
    while (iter.next()) |entry| {
        if (words2.contains(entry.key_ptr.*)) {
            intersection += 1;
        }
    }

    // Jaccard similarity: |A ∩ B| / |A ∪ B|
    const union_count = words1.count() + words2.count() - intersection;
    if (union_count == 0) return 0.0;

    return @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(union_count));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PatternEngine - register and retrieve pattern" {
    var engine = PatternEngine.init(std.testing.allocator);
    defer engine.deinit();

    var pattern = Pattern.init(std.testing.allocator, "test_pattern", "test");
    pattern.template = "pub fn {{name}}() void {{ return; }}";
    pattern.description = "A simple function";

    try engine.registerPattern(pattern);

    const retrieved = engine.patterns.get("test_pattern");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("test_pattern", retrieved.?.name);
}

test "PatternEngine - substitute template" {
    var engine = PatternEngine.init(std.testing.allocator);
    defer engine.deinit();

    var ctx = Context.init(std.testing.allocator, "test", "zig");
    defer ctx.deinit();

    try ctx.setVariable("name", "myFunc");

    const template = "const NAME = {{name}};";
    const result = try engine.substituteTemplate(template, &ctx);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("const NAME = myFunc;", result);
}

test "PatternEngine - apply pattern to behavior" {
    var engine = PatternEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Create a test pattern
    var pattern = Pattern.init(std.testing.allocator, "simple_function", "test");
    pattern.template = "pub fn {{name}}() void {\n    // {{given}}\n    // {{when}}\n    // {{then}}\n}";
    pattern.description = "A simple function with documentation";

    try engine.registerPattern(pattern);

    // Create test behavior
    const TestBehavior = struct {
        name: []const u8,
        given: []const u8,
        when: []const u8,
        then: []const u8,
    };

    const behavior = TestBehavior{
        .name = "testFunc",
        .given = "input is valid",
        .when = "called",
        .then = "returns success",
    };

    const generated = try engine.applyPattern(pattern, behavior);
    defer generated.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("zig", generated.language);
    try std.testing.expect(std.mem.indexOf(u8, generated.code, "pub fn testFunc()") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated.code, "// input is valid") != null);
}

test "computeSimilarity - identical text" {
    const text = "hello world";
    const sim = computeSimilarity(text, text);
    try std.testing.expectApproxEqAbs(1.0, sim, 0.01);
}

test "computeSimilarity - different text" {
    const text1 = "hello world";
    const text2 = "goodbye moon";
    const sim = computeSimilarity(text1, text2);
    try std.testing.expect(sim < 0.5);
}

test "computeSimilarity - partial overlap" {
    const text1 = "hello world test";
    const text2 = "hello universe";
    const sim = computeSimilarity(text1, text2);
    try std.testing.expect(sim > 0.2 and sim < 0.8);
}

test "PatternEngine - find best pattern" {
    var engine = PatternEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Register patterns
    {
        var pattern1 = Pattern.init(std.testing.allocator, "vector_function", "vsa");
        pattern1.template = "pub fn {{name}}(a: Hypervector, b: Hypervector) Hypervector {{}}";
        pattern1.description = "vector operation binding two vectors together";
        try engine.registerPattern(pattern1);
    }

    {
        var pattern2 = Pattern.init(std.testing.allocator, "simple_math", "math");
        pattern2.template = "pub fn {{name}}(a: f64, b: f64) f64 {{}}";
        pattern2.description = "simple mathematical calculation addition";
        try engine.registerPattern(pattern2);
    }

    // Find pattern for vector operation
    const pattern = try engine.findPattern("Given two vectors", "When binding them together", "Then return bound result");
    try std.testing.expect(pattern != null);
    try std.testing.expectEqualStrings("vector_function", pattern.?.name);
}
