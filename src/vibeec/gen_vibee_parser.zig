//! VIBEE Parser — Generated from specs/vibee/vibee_parser.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from vibee_parser.tri spec
//!
//! Simple YAML-based parser for .tri specification files

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const parser_types = @import("gen_parser_types.zig");

// Re-export key types
pub const VibeeSpec = parser_types.VibeeSpec;
pub const TypeDef = parser_types.TypeDef;
pub const Behavior = parser_types.Behavior;
pub const Field = parser_types.Field;
pub const TestCase = parser_types.TestCase;

// ============================================================================
// PARSE RESULT
// ============================================================================

/// Result of parsing operation
pub const ParseResult = struct {
    spec: VibeeSpec,
    errors: ArrayList([]const u8),
    warnings: ArrayList([]const u8),

    pub fn init(allocator: Allocator) ParseResult {
        return .{
            .spec = VibeeSpec.init(allocator),
            .errors = .{},
            .warnings = .{},
        };
    }

    pub fn deinit(self: *ParseResult, allocator: Allocator) void {
        self.spec.deinit(allocator);
        for (self.errors.items) |err| allocator.free(err);
        self.errors.deinit(allocator);
        for (self.warnings.items) |warn| allocator.free(warn);
        self.warnings.deinit(allocator);
    }

    pub fn hasErrors(self: *const ParseResult) bool {
        return self.errors.items.len > 0;
    }

    pub fn success(self: *const ParseResult) bool {
        return self.errors.items.len == 0;
    }
};

// ============================================================================
// YAML PARSING HELPERS
// ============================================================================

/// Parse a key-value pair from YAML line
/// Returns: key, value, new_position
pub fn parseKeyValue(line: []const u8) struct { []const u8, []const u8, bool } {
    const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse return .{ "", "", false };

    const key = std.mem.trim(u8, line[0..colon_idx], " \t");
    var value: []const u8 = "";

    if (colon_idx + 1 < line.len) {
        value = std.mem.trim(u8, line[colon_idx + 1 ..], " \t\r\n");
    }

    // Handle quoted strings
    if (value.len >= 2 and ((value[0] == '"' and value[value.len - 1] == '"') or (value[0] == '\'' and value[value.len - 1] == '\''))) {
        value = value[1 .. value.len - 1];
    }

    return .{ key, value, true };
}

/// Check if line is a comment
pub fn isComment(line: []const u8) bool {
    const trimmed = std.mem.trimLeft(u8, line, " \t");
    return trimmed.len > 0 and trimmed[0] == '#';
}

/// Check if line is empty (whitespace only)
pub fn isEmptyLine(line: []const u8) bool {
    return std.mem.trim(u8, line, " \t\r\n").len == 0;
}

/// Get indentation level (number of leading spaces)
pub fn getIndentLevel(line: []const u8) usize {
    var level: usize = 0;
    for (line) |c| {
        if (c == ' ') level += 1 else break;
    }
    return level / 2; // Assuming 2-space indentation
}

/// Check if line starts a list item (-)
pub fn isListItem(line: []const u8) bool {
    const trimmed = std.mem.trimLeft(u8, line, " \t");
    return trimmed.len > 0 and trimmed[0] == '-';
}

/// Extract list item value after '-'
pub fn extractListItem(line: []const u8) []const u8 {
    const trimmed = std.mem.trimLeft(u8, line, " \t");
    if (trimmed.len > 0 and trimmed[0] == '-') {
        const rest = std.mem.trimLeft(u8, trimmed[1..], " \t");
        // Remove quotes if present
        if (rest.len >= 2 and ((rest[0] == '"' and rest[rest.len - 1] == '"') or (rest[0] == '\'' and rest[rest.len - 1] == '\''))) {
            return rest[1 .. rest.len - 1];
        }
        return std.mem.trim(u8, rest, " \t\r\n");
    }
    return "";
}

// ============================================================================
// SECTION PARSING
// ============================================================================

const Section = enum {
    none,
    header,
    types,
    behaviors,
    constants,
    functions,
    algorithms,
    imports,
    tests,
};

/// Identify section from YAML key
pub fn identifySection(key: []const u8) Section {
    if (std.mem.eql(u8, key, "name") or
        std.mem.eql(u8, key, "version") or
        std.mem.eql(u8, key, "language") or
        std.mem.eql(u8, key, "module") or
        std.mem.eql(u8, key, "description") or
        std.mem.eql(u8, key, "author") or
        std.mem.eql(u8, key, "license"))
        return .header;

    if (std.mem.eql(u8, key, "types")) return .types;
    if (std.mem.eql(u8, key, "behaviors") or std.mem.eql(u8, key, "functions")) return .behaviors;
    if (std.mem.eql(u8, key, "constants")) return .constants;
    if (std.mem.eql(u8, key, "algorithms")) return .algorithms;
    if (std.mem.eql(u8, key, "imports")) return .imports;
    if (std.mem.eql(u8, key, "test_cases") or std.mem.eql(u8, key, "tests")) return .tests;

    return .none;
}

// ============================================================================
// MAIN PARSER
// ============================================================================

/// Parse .tri specification file from source string
pub fn parse(allocator: Allocator, source: []const u8) !ParseResult {
    var result = ParseResult.init(allocator);
    errdefer result.deinit(allocator);

    var lines = std.mem.splitScalar(u8, source, '\n');
    var current_section: Section = .none;
    var current_type_name: []const u8 = "";
    var current_behavior_name: []const u8 = "";

    while (lines.next()) |line| {
        // Skip comments and empty lines
        if (isComment(line) or isEmptyLine(line)) continue;

        const indent = getIndentLevel(line);

        // Top-level keys
        if (indent == 0) {
            if (isListItem(line)) {
                // List item at top level - could be type or behavior
                const item_name = extractListItem(line);
                if (item_name.len > 0) {
                    // Will be processed by section handler
                    if (current_section == .types) {
                        current_type_name = item_name;
                    } else if (current_section == .behaviors) {
                        current_behavior_name = item_name;
                    }
                }
            } else {
                const key, const value1, const ok = parseKeyValue(line);
                _ = value1;
                if (!ok) continue;

                const section = identifySection(key);
                if (section != .none) {
                    current_section = section;
                }

                // Set header fields
                if (section == .header) {
                    const key2, const value, const _ok2 = parseKeyValue(line);
                    _ = key2;
                    _ = _ok2;
                    if (std.mem.eql(u8, key, "name")) {
                        result.spec.name = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "version")) {
                        result.spec.version = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "language")) {
                        result.spec.language = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "module")) {
                        result.spec.module = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "description")) {
                        result.spec.description = try allocator.dupe(u8, value);
                    }
                }
            }
        }
    }

    return result;
}

/// Parse .tri specification from file
pub fn parseFile(allocator: Allocator, file_path: []const u8) !ParseResult {
    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(source);

    return parse(allocator, source);
}

// ============================================================================
// VALIDATION
// ============================================================================

/// Validate parsed specification
pub fn validate(allocator: Allocator, spec: *const VibeeSpec) !ArrayList([]const u8) {
    var errors = try ArrayList([]const u8).initCapacity(allocator, 10);

    // Check required fields
    if (spec.name.len == 0) {
        try errors.append(allocator, try allocator.dupe(u8, "Missing required field: name"));
    }
    if (spec.module.len == 0) {
        try errors.append(allocator, try allocator.dupe(u8, "Missing required field: module"));
    }

    // Check language is supported
    if (!std.mem.eql(u8, spec.language, "zig") and
        !std.mem.eql(u8, spec.language, "varlog") and
        !std.mem.eql(u8, spec.language, "python"))
    {
        try errors.append(allocator, try allocator.dupe(u8, "Unsupported language (must be: zig, varlog, or python)"));
    }

    return errors;
}

// ============================================================================
// TESTS
// ============================================================================

test "VIBEE Parser: parseKeyValue basic" {
    const line = "name: my_module";
    const key, const value, const ok = parseKeyValue(line);

    try std.testing.expect(ok);
    try std.testing.expectEqualStrings("name", key);
    try std.testing.expectEqualStrings("my_module", value);
}

test "VIBEE Parser: parseKeyValue with quotes" {
    const line = "description: \"A test module\"";
    const key, const value, const ok = parseKeyValue(line);

    try std.testing.expect(ok);
    try std.testing.expectEqualStrings("description", key);
    try std.testing.expectEqualStrings("A test module", value);
}

test "VIBEE Parser: isComment" {
    try std.testing.expect(isComment("# This is a comment"));
    try std.testing.expect(isComment("  # Indented comment"));
    try std.testing.expect(!isComment("not_a_comment = value"));
}

test "VIBEE Parser: isEmptyLine" {
    try std.testing.expect(isEmptyLine(""));
    try std.testing.expect(isEmptyLine("   "));
    try std.testing.expect(isEmptyLine("\t\n"));
    try std.testing.expect(!isEmptyLine("key = value"));
}

test "VIBEE Parser: getIndentLevel" {
    try std.testing.expectEqual(@as(usize, 0), getIndentLevel("key: value"));
    try std.testing.expectEqual(@as(usize, 1), getIndentLevel("  key: value"));
    try std.testing.expectEqual(@as(usize, 2), getIndentLevel("    key: value"));
}

test "VIBEE Parser: isListItem" {
    try std.testing.expect(isListItem("- item1"));
    try std.testing.expect(isListItem("  - item2"));
    try std.testing.expect(!isListItem("key: value"));
}

test "VIBEE Parser: extractListItem" {
    try std.testing.expectEqualStrings("item1", extractListItem("- item1"));
    try std.testing.expectEqualStrings("my_value", extractListItem("- my_value"));
    try std.testing.expectEqualStrings("unquoted", extractListItem("- \"unquoted\""));
}

test "VIBEE Parser: parse minimal spec" {
    const allocator = std.testing.allocator;
    const source =
        \\name: test_module
        \\version: "1.0.0"
        \\language: zig
        \\module: test.module
        \\description: "Test module"
    ;

    var result = try parse(allocator, source);
    defer result.deinit(allocator);

    try std.testing.expect(result.success());
    try std.testing.expectEqualStrings("test_module", result.spec.name);
    try std.testing.expectEqualStrings("zig", result.spec.language);
}

test "VIBEE Parser: validate missing name" {
    const allocator = std.testing.allocator;
    var spec = VibeeSpec.init(allocator);
    defer spec.deinit(allocator);

    spec.module = "test.module";
    spec.language = "zig";

    var errors = try validate(allocator, &spec);
    defer {
        for (errors.items) |err| allocator.free(err);
        errors.deinit(allocator);
    }

    try std.testing.expect(errors.items.len > 0);
}
