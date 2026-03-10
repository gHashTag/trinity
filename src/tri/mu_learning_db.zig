// ═══════════════════════════════════════════════════════════════════════════════
// MU LEARNING DB — Accumulate error patterns → auto-fix rules
// ═══════════════════════════════════════════════════════════════════════════════
// Issue #74: Pattern DB from error logs. Auto-fix known patterns.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const AutoFixRule = struct {
    id: []const u8,
    pattern: []const u8, // what to match in error message or generated code
    replacement: []const u8, // what to replace with (empty = delete)
    category: []const u8, // error category this fixes
    description: []const u8,
    apply_count: usize,
    success_count: usize,
};

pub const LearnResult = struct {
    rules_total: usize,
    new_rules: usize,
    updated_rules: usize,
    errors_scanned: usize,
};

pub const FixResult = struct {
    spec: []const u8,
    rules_applied: usize,
    fixes_made: usize,
    compile_before: bool,
    compile_after: bool,
};

const ERRORS_DIR = ".trinity/mu/errors";
const DB_PATH = ".trinity/mu/learning_db.json";

// ═══════════════════════════════════════════════════════════════════════════════
// BUILT-IN RULES (10+ from REGENERATION_REPORT known patterns)
// ═══════════════════════════════════════════════════════════════════════════════

pub const BUILTIN_RULES = [_]AutoFixRule{
    // Rule 1: Int64 → i64
    .{ .id = "type_int64", .pattern = "Int64", .replacement = "i64", .category = "TYPE_MAPPING", .description = "Map Int64 to Zig i64", .apply_count = 0, .success_count = 0 },
    // Rule 2: Float32 → f32
    .{ .id = "type_float32", .pattern = "Float32", .replacement = "f32", .category = "TYPE_MAPPING", .description = "Map Float32 to Zig f32", .apply_count = 0, .success_count = 0 },
    // Rule 3: Float64 → f64
    .{ .id = "type_float64", .pattern = "Float64", .replacement = "f64", .category = "TYPE_MAPPING", .description = "Map Float64 to Zig f64", .apply_count = 0, .success_count = 0 },
    // Rule 4: String → []const u8
    .{ .id = "type_string", .pattern = ": String", .replacement = ": []const u8", .category = "TYPE_MAPPING", .description = "Map String to Zig []const u8", .apply_count = 0, .success_count = 0 },
    // Rule 5: Boolean → bool
    .{ .id = "type_boolean", .pattern = "Boolean", .replacement = "bool", .category = "TYPE_MAPPING", .description = "Map Boolean to Zig bool", .apply_count = 0, .success_count = 0 },
    // Rule 6: List(X) → []const X
    .{ .id = "type_list", .pattern = "List(", .replacement = "[]const ", .category = "TYPE_MAPPING", .description = "Map List(T) to Zig []const T", .apply_count = 0, .success_count = 0 },
    // Rule 7: Optional(X) → ?X
    .{ .id = "type_optional", .pattern = "Optional(", .replacement = "?", .category = "TYPE_MAPPING", .description = "Map Optional(T) to Zig ?T", .apply_count = 0, .success_count = 0 },
    // Rule 8: Map(K,V) → std.StringHashMap
    .{ .id = "type_map", .pattern = "Map(", .replacement = "std.StringHashMap(", .category = "TYPE_MAPPING", .description = "Map Map(K,V) to StringHashMap", .apply_count = 0, .success_count = 0 },
    // Rule 9: YAML comment in generated code
    .{ .id = "yaml_comment", .pattern = "# ", .replacement = "// ", .category = "SYNTAX_ERROR", .description = "Convert YAML comments to Zig comments", .apply_count = 0, .success_count = 0 },
    // Rule 10: Integer → i32
    .{ .id = "type_integer", .pattern = "Integer", .replacement = "i32", .category = "TYPE_MAPPING", .description = "Map Integer to Zig i32", .apply_count = 0, .success_count = 0 },
    // Rule 11: Void in struct field → void
    .{ .id = "type_void", .pattern = ": Void", .replacement = ": void", .category = "TYPE_MAPPING", .description = "Map Void to Zig void (lowercase)", .apply_count = 0, .success_count = 0 },
    // Rule 12: Double → f64
    .{ .id = "type_double", .pattern = "Double", .replacement = "f64", .category = "TYPE_MAPPING", .description = "Map Double to Zig f64", .apply_count = 0, .success_count = 0 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// LEARNING
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan .trinity/mu/errors/*.json, extract patterns, update learning DB.
pub fn learnFromErrors(allocator: Allocator) !LearnResult {
    var result = LearnResult{
        .rules_total = BUILTIN_RULES.len,
        .new_rules = 0,
        .updated_rules = 0,
        .errors_scanned = 0,
    };

    // Scan error files
    var dir = std.fs.cwd().openDir(ERRORS_DIR, .{ .iterate = true }) catch {
        return result; // No errors dir = nothing to learn
    };
    defer dir.close();

    // Count errors by category for frequency analysis
    var category_counts: [9]usize = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    var total_errors: usize = 0;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        total_errors += 1;

        const content = dir.readFileAlloc(allocator, entry.name, 64 * 1024) catch continue;
        defer allocator.free(content);

        // Extract category
        if (std.mem.indexOf(u8, content, "\"error_category\": \"")) |pos| {
            const start = pos + "\"error_category\": \"".len;
            if (std.mem.indexOfScalarPos(u8, content, start, '"')) |end| {
                const cat_str = content[start..end];
                const idx = categoryIndex(cat_str);
                if (idx < 9) category_counts[idx] += 1;
            }
        }
    }

    result.errors_scanned = total_errors;

    // For now, rules come from builtins + frequency analysis
    // Future: extract new patterns from error_message clustering
    // Count updated = categories with errors matching our rules
    for (category_counts) |count| {
        if (count > 0) result.updated_rules += 1;
    }

    // Save learning state
    try saveDB(allocator, category_counts, total_errors);

    return result;
}

fn categoryIndex(cat_str: []const u8) usize {
    const cats = [_][]const u8{
        "TYPE_MAPPING", "UNDEFINED_IDENTIFIER", "SYNTAX_ERROR",
        "FORMAT_ERROR", "IMPORT_ERROR", "MEMORY_ERROR",
        "TEST_FAILURE", "GEN_FAILURE", "UNKNOWN",
    };
    for (cats, 0..) |c, i| {
        if (std.mem.eql(u8, cat_str, c)) return i;
    }
    return 8; // unknown
}

/// Save learning DB to .trinity/mu/learning_db.json
fn saveDB(allocator: Allocator, category_counts: [9]usize, total_errors: usize) !void {
    std.fs.cwd().makePath(".trinity/mu") catch {};

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\n");
    try w.print("  \"version\": \"1.0.0\",\n", .{});
    try w.print("  \"total_errors_scanned\": {d},\n", .{total_errors});
    try w.print("  \"rules_count\": {d},\n", .{BUILTIN_RULES.len});
    try w.writeAll("  \"category_frequency\": {\n");

    const cats = [_][]const u8{
        "TYPE_MAPPING", "UNDEFINED_IDENTIFIER", "SYNTAX_ERROR",
        "FORMAT_ERROR", "IMPORT_ERROR", "MEMORY_ERROR",
        "TEST_FAILURE", "GEN_FAILURE", "UNKNOWN",
    };
    for (cats, 0..) |c, i| {
        try w.print("    \"{s}\": {d}", .{ c, category_counts[i] });
        if (i < cats.len - 1) try w.writeAll(",");
        try w.writeAll("\n");
    }
    try w.writeAll("  },\n");

    // Rules
    try w.writeAll("  \"rules\": [\n");
    for (BUILTIN_RULES, 0..) |rule, i| {
        try w.print("    {{\"id\": \"{s}\", \"pattern\": \"{s}\", \"replacement\": \"{s}\", \"category\": \"{s}\", \"description\": \"{s}\"}}", .{
            rule.id, rule.pattern, rule.replacement, rule.category, rule.description,
        });
        if (i < BUILTIN_RULES.len - 1) try w.writeAll(",");
        try w.writeAll("\n");
    }
    try w.writeAll("  ]\n");
    try w.writeAll("}\n");

    const json = try buf.toOwnedSlice(allocator);
    defer allocator.free(json);

    const file = try std.fs.cwd().createFile(DB_PATH, .{});
    defer file.close();
    try file.writeAll(json);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIXING
// ═══════════════════════════════════════════════════════════════════════════════

/// Apply auto-fix rules to a generated file.
/// Returns how many fixes were applied.
pub fn applyFixes(allocator: Allocator, generated_path: []const u8) !FixResult {
    var result = FixResult{
        .spec = generated_path,
        .rules_applied = 0,
        .fixes_made = 0,
        .compile_before = false,
        .compile_after = false,
    };

    // Check compile status before
    result.compile_before = checkCompile(allocator, generated_path);

    // Read generated file
    const content = std.fs.cwd().readFileAlloc(allocator, generated_path, 10 * 1024 * 1024) catch {
        return result;
    };
    defer allocator.free(content);

    // Apply each rule that matches
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, content);

    for (BUILTIN_RULES) |rule| {
        // Check if pattern exists in current content
        if (std.mem.indexOf(u8, output.items, rule.pattern) != null) {
            result.rules_applied += 1;
            // Apply replacement (all occurrences)
            var new_output: std.ArrayList(u8) = .empty;
            var pos: usize = 0;
            while (std.mem.indexOfPos(u8, output.items, pos, rule.pattern)) |idx| {
                try new_output.appendSlice(allocator, output.items[pos..idx]);
                try new_output.appendSlice(allocator, rule.replacement);
                pos = idx + rule.pattern.len;
                result.fixes_made += 1;
            }
            try new_output.appendSlice(allocator, output.items[pos..]);
            output.deinit(allocator);
            output = new_output;
        }
    }

    if (result.fixes_made > 0) {
        // Write fixed file
        const file = try std.fs.cwd().createFile(generated_path, .{});
        defer file.close();
        try file.writeAll(output.items);
    }

    // Check compile status after
    result.compile_after = checkCompile(allocator, generated_path);

    return result;
}

/// Check if a .zig file compiles (ast-check).
fn checkCompile(allocator: Allocator, path: []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "ast-check", path },
    }) catch return false;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return result.term.Exited == 0;
}

/// Apply fixes to all generated files from specs.
pub fn applyFixesAll(allocator: Allocator) !struct { total: usize, fixed: usize, already_ok: usize } {
    var total: usize = 0;
    var fixed: usize = 0;
    var already_ok: usize = 0;

    var dir = std.fs.cwd().openDir("generated", .{ .iterate = true }) catch {
        return .{ .total = 0, .fixed = 0, .already_ok = 0 };
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        total += 1;

        const path = try std.fmt.allocPrint(allocator, "generated/{s}", .{entry.name});
        defer allocator.free(path);

        const result = try applyFixes(allocator, path);
        if (result.compile_before) {
            already_ok += 1;
        } else if (result.compile_after and !result.compile_before) {
            fixed += 1;
        }
    }

    return .{ .total = total, .fixed = fixed, .already_ok = already_ok };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Run `tri mu learn` — scan errors, build pattern DB.
pub fn runMuLearnCommand(allocator: Allocator) !void {
    std.debug.print("\n\x1b[33m🧠 MU LEARNING DB\x1b[0m — scanning error logs\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    const result = try learnFromErrors(allocator);

    std.debug.print("  \x1b[36mErrors scanned:\x1b[0m  {d}\n", .{result.errors_scanned});
    std.debug.print("  \x1b[36mRules total:\x1b[0m     {d} ({d} builtin)\n", .{ result.rules_total, BUILTIN_RULES.len });
    std.debug.print("  \x1b[36mCategories hit:\x1b[0m  {d}\n", .{result.updated_rules});

    std.debug.print("\n  \x1b[33mBuilt-in Auto-Fix Rules:\x1b[0m\n", .{});
    std.debug.print("  ┌──────────────────┬──────────────────────┬──────────────────────┐\n", .{});
    std.debug.print("  │ ID               │ Pattern              │ Fix                  │\n", .{});
    std.debug.print("  ├──────────────────┼──────────────────────┼──────────────────────┤\n", .{});
    for (BUILTIN_RULES) |rule| {
        std.debug.print("  │ {s:<16} │ {s:<20} │ {s:<20} │\n", .{
            rule.id, rule.pattern[0..@min(rule.pattern.len, 20)], rule.replacement[0..@min(rule.replacement.len, 20)],
        });
    }
    std.debug.print("  └──────────────────┴──────────────────────┴──────────────────────┘\n", .{});

    std.debug.print("\n  \x1b[90mDB saved to: {s}\x1b[0m\n", .{DB_PATH});

    const phi = 1.618034;
    if (result.errors_scanned > 0) {
        const coverage: f64 = @as(f64, @floatFromInt(result.rules_total)) / @as(f64, @floatFromInt(@max(result.errors_scanned, 1)));
        const v = phi * @min(coverage, 1.0) * @min(coverage, 1.0);
        std.debug.print("  \x1b[33mV = φ·(rules/errors)² = {d:.3}\x1b[0m\n", .{v});
    }
}

/// Run `tri mu fix <spec>` — apply known fixes.
pub fn runMuFixCommand(allocator: Allocator, args: []const []const u8) !void {
    std.debug.print("\n\x1b[33m🧠 MU AUTO-FIX\x1b[0m — applying known patterns\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    if (args.len > 0 and std.mem.eql(u8, args[0], "--all")) {
        // Fix all generated files
        const result = try applyFixesAll(allocator);
        std.debug.print("  \x1b[36mTotal files:\x1b[0m    {d}\n", .{result.total});
        std.debug.print("  \x1b[32mAlready OK:\x1b[0m     {d}\n", .{result.already_ok});
        std.debug.print("  \x1b[33mFixed:\x1b[0m          {d}\n", .{result.fixed});
        std.debug.print("  \x1b[31mStill broken:\x1b[0m   {d}\n", .{result.total - result.already_ok - result.fixed});
        return;
    }

    if (args.len == 0) {
        std.debug.print("  Usage: tri mu fix <generated-file.zig>\n", .{});
        std.debug.print("         tri mu fix --all\n", .{});
        return;
    }

    const path = args[0];
    const result = try applyFixes(allocator, path);

    std.debug.print("  \x1b[36mFile:\x1b[0m           {s}\n", .{path});
    std.debug.print("  \x1b[36mRules matched:\x1b[0m  {d}\n", .{result.rules_applied});
    std.debug.print("  \x1b[36mFixes applied:\x1b[0m  {d}\n", .{result.fixes_made});
    std.debug.print("  \x1b[36mBefore:\x1b[0m         {s}\n", .{if (result.compile_before) "\x1b[32m✅ PASS" else "\x1b[31m❌ FAIL"});
    std.debug.print("  \x1b[36mAfter:\x1b[0m          {s}\x1b[0m\n", .{if (result.compile_after) "\x1b[32m✅ PASS" else "\x1b[31m❌ FAIL"});

    if (!result.compile_before and result.compile_after) {
        std.debug.print("\n  \x1b[32m🎉 AUTO-FIX SUCCESS — file now compiles!\x1b[0m\n", .{});
    } else if (result.compile_before) {
        std.debug.print("\n  \x1b[32m✅ File already compiles — no fix needed.\x1b[0m\n", .{});
    } else {
        std.debug.print("\n  \x1b[31m⚠️  Still broken after {d} fixes. Manual intervention needed.\x1b[0m\n", .{result.fixes_made});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BUILTIN_RULES — count >= 10" {
    try std.testing.expect(BUILTIN_RULES.len >= 10);
}

test "BUILTIN_RULES — Int64 rule exists" {
    var found = false;
    for (BUILTIN_RULES) |rule| {
        if (std.mem.eql(u8, rule.pattern, "Int64")) {
            try std.testing.expect(std.mem.eql(u8, rule.replacement, "i64"));
            found = true;
        }
    }
    try std.testing.expect(found);
}

test "BUILTIN_RULES — String rule exists" {
    var found = false;
    for (BUILTIN_RULES) |rule| {
        if (std.mem.eql(u8, rule.pattern, ": String")) {
            try std.testing.expect(std.mem.eql(u8, rule.replacement, ": []const u8"));
            found = true;
        }
    }
    try std.testing.expect(found);
}

test "BUILTIN_RULES — Optional rule exists" {
    var found = false;
    for (BUILTIN_RULES) |rule| {
        if (std.mem.eql(u8, rule.pattern, "Optional(")) {
            try std.testing.expect(std.mem.eql(u8, rule.replacement, "?"));
            found = true;
        }
    }
    try std.testing.expect(found);
}

test "BUILTIN_RULES — all have descriptions" {
    for (BUILTIN_RULES) |rule| {
        try std.testing.expect(rule.description.len > 0);
        try std.testing.expect(rule.id.len > 0);
        try std.testing.expect(rule.category.len > 0);
    }
}

test "learnFromErrors — no errors dir" {
    const allocator = std.testing.allocator;
    const result = try learnFromErrors(allocator);
    try std.testing.expectEqual(BUILTIN_RULES.len, result.rules_total);
}

test "categoryIndex — known categories" {
    try std.testing.expectEqual(@as(usize, 0), categoryIndex("TYPE_MAPPING"));
    try std.testing.expectEqual(@as(usize, 2), categoryIndex("SYNTAX_ERROR"));
    try std.testing.expectEqual(@as(usize, 8), categoryIndex("UNKNOWN"));
    try std.testing.expectEqual(@as(usize, 8), categoryIndex("NONSENSE"));
}
