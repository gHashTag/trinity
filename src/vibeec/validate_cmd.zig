// ===============================================================================
// VIBEE SPECIFICATION VALIDATOR - Consolidated Linter (Issue #68)
// Implements all 6 behaviors from specs/tri/spec_lint.tri
// ===============================================================================

const std = @import("std");

const alloc = std.heap.page_allocator;

pub const Severity = enum {
    err,
    warning,
};

pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    line: usize,
    severity: Severity,
};

// Known base types for type validation
const known_base_types = [_][]const u8{
    // Primitives
    "f64",    "f32",       "i32",    "i64",       "u32",      "u64",
    "u8",     "u16",       "usize",  "bool",
    // VIBEE types
         "String",   "Int",
    "Float",  "Bool",      "Bytes",  "Timestamp", "Duration", "Any",
    "Void",   "Error",
    // Aliases
        "string", "int",       "float",
    // Extended
       "Int64",
    "Int32",  "Int16",     "Int8",   "UInt",      "UInt64",   "UInt32",
    "UInt16", "UInt8",     "UInt4",  "Float32",   "Float64",
    // Case variants (common in specs)
     "Uint64",
    "Uint32", "Uint16",    "Uint8",  "U32",       "U64",      "U8",
    "U16",
    // Common Zig stdlib types
       "Allocator", "Writer", "Reader",    "Thread",   "Mutex",
};

fn matchesNumericType(name: []const u8) bool {
    // Matches: Int<N>, UInt<N>, Float<N>, i<N>, u<N>, f<N> where N is digits
    const prefixes = [_][]const u8{ "Int", "UInt", "Uint", "Float", "i", "u", "f" };
    for (&prefixes) |prefix| {
        if (std.mem.startsWith(u8, name, prefix) and name.len > prefix.len) {
            const rest = name[prefix.len..];
            var all_digits = true;
            for (rest) |c| {
                if (!std.ascii.isDigit(c)) {
                    all_digits = false;
                    break;
                }
            }
            if (all_digits) return true;
        }
    }
    return false;
}

fn isKnownType(type_str: []const u8, spec_types: []const []const u8) bool {
    const trimmed = std.mem.trim(u8, type_str, " \t");
    if (trimmed.len == 0) return true;

    // Raw Zig types: slices, pointers, optionals
    if (trimmed[0] == '[' or trimmed[0] == '*' or trimmed[0] == '?') return true;

    // Suffix ? for optionals (e.g. "Int?", "String?")
    if (trimmed[trimmed.len - 1] == '?') {
        return isKnownType(trimmed[0 .. trimmed.len - 1], spec_types);
    }

    // Quoted types (e.g. "\"u8\"")
    if (trimmed[0] == '"') return true;

    // Std-qualified types (e.g. "std.mem.Allocator")
    if (std.mem.startsWith(u8, trimmed, "std.")) return true;

    // Numeric bit-width types: Int2, UInt3, Int128, etc.
    if (matchesNumericType(trimmed)) return true;

    // Check known base types
    for (&known_base_types) |known| {
        if (std.mem.eql(u8, trimmed, known)) return true;
    }

    // Check spec-defined types
    for (spec_types) |st| {
        if (std.mem.eql(u8, trimmed, st)) return true;
    }

    // Generic wrappers with angle brackets: List<T>, Map<K,V>, Option<T>
    if (std.mem.indexOf(u8, trimmed, "<")) |open| {
        const wrapper = trimmed[0..open];
        const valid_wrappers = [_][]const u8{ "List", "Map", "Option", "Set", "Result", "HashMap", "Vec", "Ptr", "list", "map", "set" };
        for (&valid_wrappers) |w| {
            if (std.mem.eql(u8, wrapper, w)) return true;
        }
        // Even if wrapper not in list, check inner types
        if (std.mem.lastIndexOfScalar(u8, trimmed, '>')) |close| {
            const inner = trimmed[open + 1 .. close];
            var parts = std.mem.splitScalar(u8, inner, ',');
            while (parts.next()) |part| {
                if (!isKnownType(part, spec_types)) return false;
            }
            return true;
        }
    }

    // Generic wrappers with parens: List(T), Map(K, V), Option(T)
    if (std.mem.indexOf(u8, trimmed, "(")) |open| {
        const wrapper = trimmed[0..open];
        const valid_wrappers = [_][]const u8{ "List", "Map", "Option", "Set", "Result", "HashMap", "Vec", "Ptr", "list", "map", "set" };
        for (&valid_wrappers) |w| {
            if (std.mem.eql(u8, wrapper, w)) return true;
        }
        if (std.mem.lastIndexOfScalar(u8, trimmed, ')')) |close| {
            const inner = trimmed[open + 1 .. close];
            var parts = std.mem.splitScalar(u8, inner, ',');
            while (parts.next()) |part| {
                if (!isKnownType(part, spec_types)) return false;
            }
            return true;
        }
    }

    // Array[T][N] or bracket syntax
    if (std.mem.indexOf(u8, trimmed, "[")) |_| {
        return true; // Accept array/bracket syntax broadly
    }

    return false;
}

fn hasSpaceSeparatedGeneric(type_str: []const u8) bool {
    const trimmed = std.mem.trim(u8, type_str, " \t");
    if (trimmed.len == 0) return false;

    // If it contains spaces but no generic/array/paren syntax, it's likely space-separated
    if (std.mem.indexOfScalar(u8, trimmed, ' ') != null) {
        if (std.mem.indexOfScalar(u8, trimmed, '<') == null and
            std.mem.indexOfScalar(u8, trimmed, '[') == null and
            std.mem.indexOfScalar(u8, trimmed, '(') == null)
        {
            return true;
        }
    }
    return false;
}

fn isPascalCase(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!std.ascii.isUpper(name[0])) return false;
    if (std.mem.indexOfScalar(u8, name, '_') != null) return false;
    return true;
}

fn isSnakeCase(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if (std.ascii.isUpper(c)) return false;
    }
    return true;
}

const BehaviorState = struct {
    name: []const u8,
    has_given: bool,
    has_when: bool,
    has_then: bool,
    line: usize,
};

const Section = enum {
    none,
    types,
    behaviors,
    fields,
    other,
};

pub fn validateSpec(source: []const u8, file_path: []const u8) ![]const ValidationError {
    var errors: std.ArrayList(ValidationError) = .{};

    // ---- Pass 1: collect all spec-defined type names ----
    var spec_types: std.ArrayList([]const u8) = .{};
    {
        var pre_section: Section = .none;
        var pre_lines = std.mem.splitScalar(u8, source, '\n');
        while (pre_lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            var indent: usize = 0;
            for (line) |c| {
                if (c == ' ') {
                    indent += 1;
                } else if (c == '\t') {
                    indent += 2;
                } else break;
            }

            if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
                const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");
                const value = if (colon_idx + 1 < trimmed.len)
                    std.mem.trim(u8, trimmed[colon_idx + 1 ..], " ")
                else
                    "";

                if (indent == 0 and std.mem.eql(u8, key, "types")) {
                    pre_section = .types;
                } else if (indent == 0 and !std.mem.eql(u8, key, "types")) {
                    if (!std.mem.eql(u8, key, "name") and
                        !std.mem.eql(u8, key, "version") and
                        !std.mem.eql(u8, key, "language") and
                        !std.mem.eql(u8, key, "module") and
                        !std.mem.eql(u8, key, "output") and
                        !std.mem.eql(u8, key, "description") and
                        !std.mem.eql(u8, key, "dependencies") and
                        !std.mem.eql(u8, key, "imports"))
                    {
                        pre_section = .other;
                    }
                }

                if (pre_section == .types and indent == 2 and value.len == 0) {
                    try spec_types.append(alloc, key);
                }
            }
        }
    }

    // ---- Pass 2: full validation ----
    var line_num: usize = 0;
    var has_name = false;
    var has_version = false;
    var has_output = false;

    // Section tracking
    var current_section: Section = .none;
    var in_type_fields = false;

    // Behavior tracking
    var behaviors: std.ArrayList(BehaviorState) = .{};
    var current_behavior: ?BehaviorState = null;

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        line_num += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Calculate indentation level
        var indent: usize = 0;
        for (line) |c| {
            if (c == ' ') {
                indent += 1;
            } else if (c == '\t') {
                indent += 2;
            } else break;
        }

        // Parse key:value
        if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon_idx| {
            const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");
            const value = if (colon_idx + 1 < trimmed.len)
                std.mem.trim(u8, trimmed[colon_idx + 1 ..], " ")
            else
                "";

            // Top-level field detection
            if (std.mem.eql(u8, key, "name")) has_name = true;
            if (std.mem.eql(u8, key, "version")) has_version = true;
            if (std.mem.eql(u8, key, "output")) has_output = true;

            // Section tracking (top-level sections at indent 0)
            if (indent == 0) {
                // Flush current behavior if switching sections
                if (current_behavior) |b| {
                    try behaviors.append(alloc, b);
                    current_behavior = null;
                }

                if (std.mem.eql(u8, key, "types")) {
                    current_section = .types;
                    in_type_fields = false;
                } else if (std.mem.eql(u8, key, "behaviors")) {
                    current_section = .behaviors;
                    in_type_fields = false;
                } else if (std.mem.eql(u8, key, "name") or
                    std.mem.eql(u8, key, "version") or
                    std.mem.eql(u8, key, "language") or
                    std.mem.eql(u8, key, "module") or
                    std.mem.eql(u8, key, "output") or
                    std.mem.eql(u8, key, "description") or
                    std.mem.eql(u8, key, "dependencies") or
                    std.mem.eql(u8, key, "imports"))
                {
                    // Known top-level keys, don't change section
                } else {
                    current_section = .other;
                    in_type_fields = false;
                }
            }

            // Type definitions (indent 2 under types:)
            if (current_section == .types and indent == 2 and value.len == 0) {
                in_type_fields = false;

                // Check PascalCase for type names
                if (!isPascalCase(key)) {
                    try errors.append(alloc, .{
                        .code = "naming_type",
                        .message = "Type name should be PascalCase",
                        .line = line_num,
                        .severity = .warning,
                    });
                }
            }

            // Fields section under a type
            if (current_section == .types and indent == 4 and std.mem.eql(u8, key, "fields")) {
                in_type_fields = true;
            }

            // Field type validation (indent 6 under fields:)
            if (current_section == .types and in_type_fields and indent == 6 and value.len > 0) {
                // Strip default value (e.g. "Bool = true" → "Bool")
                // Strip inline comment (e.g. "f64  # range 0-1" → "f64")
                const type_value = blk: {
                    var v = value;
                    if (std.mem.indexOf(u8, v, " = ")) |eq| v = v[0..eq];
                    if (std.mem.indexOf(u8, v, " #")) |hash| v = v[0..hash];
                    break :blk std.mem.trim(u8, v, " \t");
                };
                // Check for space-separated generics
                if (hasSpaceSeparatedGeneric(type_value)) {
                    try errors.append(alloc, .{
                        .code = "space_generic",
                        .message = "Space-separated generic detected. Use proper generic syntax like List<Float> or Array<Array<Float>>",
                        .line = line_num,
                        .severity = .err,
                    });
                } else if (!isKnownType(type_value, spec_types.items)) {
                    try errors.append(alloc, .{
                        .code = "unknown_type",
                        .message = "Unknown type reference",
                        .line = line_num,
                        .severity = .err,
                    });
                }
            }

            // Behavior tracking
            if (current_section == .behaviors and indent == 2 and value.len == 0) {
                // Flush previous behavior
                if (current_behavior) |b| {
                    try behaviors.append(alloc, b);
                }
                current_behavior = .{
                    .name = key,
                    .has_given = false,
                    .has_when = false,
                    .has_then = false,
                    .line = line_num,
                };

                // Check snake_case for behavior names
                if (!isSnakeCase(key)) {
                    try errors.append(alloc, .{
                        .code = "naming_behavior",
                        .message = "Behavior name should be snake_case",
                        .line = line_num,
                        .severity = .warning,
                    });
                }
            }

            // Track given/when/then inside behaviors
            if (current_section == .behaviors and indent >= 4) {
                if (current_behavior) |*b| {
                    if (std.mem.eql(u8, key, "given")) b.has_given = true;
                    if (std.mem.eql(u8, key, "when")) b.has_when = true;
                    if (std.mem.eql(u8, key, "then")) b.has_then = true;
                }
            }
        }
    }

    // Flush last behavior
    if (current_behavior) |b| {
        try behaviors.append(alloc, b);
    }

    // Check 1: output: is only a warning (most specs don't have it)
    if (!has_output) {
        try errors.append(alloc, .{
            .code = "missing_output",
            .message = "Missing 'output:' key (optional but recommended)",
            .line = 1,
            .severity = .warning,
        });
    }

    // Check 2: Root folder forbidden
    const tri_idx = std.mem.indexOf(u8, file_path, "specs/tri/") orelse 0;
    if (tri_idx != 0) {
        const after_tri = file_path[tri_idx + "specs/tri/".len ..];
        if (std.mem.indexOfScalar(u8, after_tri, '/') == null) {
            try errors.append(alloc, .{
                .code = "root_folder",
                .message = "Spec must be in subfolder (core/, compiler/, runtime/, etc.)",
                .line = 1,
                .severity = .err,
            });
        }
    }

    // Check 3: Double .tri.tri extension only
    if (std.mem.endsWith(u8, file_path, ".tri.tri")) {
        try errors.append(alloc, .{
            .code = "double_extension",
            .message = "File has double .tri.tri extension",
            .line = 1,
            .severity = .err,
        });
    }

    // Check 4: Mandatory name: field
    if (!has_name) {
        try errors.append(alloc, .{
            .code = "missing_name",
            .message = "Missing mandatory 'name:' field",
            .line = 1,
            .severity = .err,
        });
    }

    // Check 5: Mandatory version: field
    if (!has_version) {
        try errors.append(alloc, .{
            .code = "missing_version",
            .message = "Missing mandatory 'version:' field",
            .line = 1,
            .severity = .err,
        });
    }

    // Check 6: Behavior format validation — given/when/then required
    for (behaviors.items) |b| {
        if (!b.has_given) {
            try errors.append(alloc, .{
                .code = "missing_given",
                .message = "Behavior missing 'given:' clause",
                .line = b.line,
                .severity = .err,
            });
        }
        if (!b.has_when) {
            try errors.append(alloc, .{
                .code = "missing_when",
                .message = "Behavior missing 'when:' clause",
                .line = b.line,
                .severity = .err,
            });
        }
        if (!b.has_then) {
            try errors.append(alloc, .{
                .code = "missing_then",
                .message = "Behavior missing 'then:' clause",
                .line = b.line,
                .severity = .err,
            });
        }
    }

    if (errors.items.len > 0) {
        return try alloc.dupe(ValidationError, errors.items);
    }

    return &.{};
}

// ===============================================================================
// CLI COMMAND
// ===============================================================================

pub fn runValidation(args: []const []const u8) !u8 {
    if (args.len < 2) {
        std.debug.print("Usage: vibee validate <spec.tri>\n", .{});
        std.debug.print("       vibee validate <dir/>       # Validate all specs in directory\n", .{});
        std.debug.print("       vibee lint <spec.tri>        # Alias for validate\n", .{});
        return 1;
    }

    const file_path = args[1];

    // Check if path is a directory by trying to open it
    if (std.fs.cwd().openDir(file_path, .{ .iterate = true })) |dir| {
        var d = dir;
        d.close();
        return lintDirectory(file_path);
    } else |_| {}

    return lintSingleFile(file_path);
}

fn lintSingleFile(file_path: []const u8) !u8 {
    const source = std.fs.cwd().readFileAlloc(alloc, file_path, 1024 * 1024) catch |err| {
        std.debug.print("Error reading file: {}\n   Path: {s}\n", .{ err, file_path });
        return 1;
    };
    defer alloc.free(source);

    const validation_errors = try validateSpec(source, file_path);

    if (validation_errors.len > 0) {
        std.debug.print("\n--- {s} ---\n", .{file_path});

        var err_count: usize = 0;
        var warn_count: usize = 0;

        for (validation_errors) |ve| {
            const prefix: []const u8 = switch (ve.severity) {
                .err => "ERROR",
                .warning => "WARN ",
            };
            switch (ve.severity) {
                .err => err_count += 1,
                .warning => warn_count += 1,
            }
            std.debug.print("  [{s}] L{d}: {s} ({s})\n", .{ prefix, ve.line, ve.message, ve.code });
        }

        std.debug.print("  {d} error(s), {d} warning(s)\n", .{ err_count, warn_count });

        if (err_count > 0) return 1;
    } else {
        std.debug.print("PASS {s}\n", .{file_path});
    }

    return 0;
}

fn lintDirectory(dir_path: []const u8) !u8 {
    var total_files: usize = 0;
    var failed_files: usize = 0;

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error opening directory: {}\n   Path: {s}\n", .{ err, dir_path });
        return 1;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;

        // Build full path
        const full_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ dir_path, entry.name });

        total_files += 1;
        const result = lintSingleFile(full_path) catch 1;
        if (result != 0) failed_files += 1;
    }

    std.debug.print("\n{d} file(s) checked, {d} failed\n", .{ total_files, failed_files });

    if (failed_files > 0) return 1;
    return 0;
}

// ===============================================================================
// TESTS
// ===============================================================================

test "valid spec passes" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\language: zig
        \\module: core
        \\output: src/test.zig
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    try std.testing.expectEqual(@as(usize, 0), errs.len);
}

test "missing name detected" {
    const source =
        \\version: 1.0.0
        \\language: zig
        \\output: src/test.zig
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "missing_name")) found = true;
    }
    try std.testing.expect(found);
}

test "missing version detected" {
    const source =
        \\name: test_spec
        \\language: zig
        \\output: src/test.zig
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "missing_version")) found = true;
    }
    try std.testing.expect(found);
}

test "missing given/when/then detected" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\behaviors:
        \\  incomplete_behavior:
        \\    given: something
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found_when = false;
    var found_then = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "missing_when")) found_when = true;
        if (std.mem.eql(u8, e.code, "missing_then")) found_then = true;
    }
    try std.testing.expect(found_when);
    try std.testing.expect(found_then);
}

test "unknown type reference detected" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\types:
        \\  MyType:
        \\    fields:
        \\      value: CompletelyFakeType
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "unknown_type")) found = true;
    }
    try std.testing.expect(found);
}

test "space-separated generic detected" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\types:
        \\  MyType:
        \\    fields:
        \\      data: 2D Array Float
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "space_generic")) found = true;
    }
    try std.testing.expect(found);
}

test "PascalCase type naming enforced" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\types:
        \\  bad_type_name:
        \\    fields:
        \\      x: Int
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "naming_type")) found = true;
    }
    try std.testing.expect(found);
}

test "snake_case behavior naming enforced" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\behaviors:
        \\  BadBehaviorName:
        \\    given: x
        \\    when: y
        \\    then: z
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "naming_behavior")) found = true;
    }
    try std.testing.expect(found);
}

test "spec-defined types accepted" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\types:
        \\  CustomConfig:
        \\    fields:
        \\      name: String
        \\  AppState:
        \\    fields:
        \\      config: CustomConfig
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    // Should have no unknown_type errors
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "unknown_type")) {
            try std.testing.expect(false); // Should not reach
        }
    }
}

test ".tri files not falsely flagged as duplicate (bug regression)" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "duplicate_tri")) {
            try std.testing.expect(false); // Should not flag .tri files
        }
    }
}

test "double .tri.tri extension flagged" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri.tri");
    var found = false;
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "double_extension")) found = true;
    }
    try std.testing.expect(found);
}

test "forward-referenced types accepted (two-pass)" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
        \\output: src/test.zig
        \\types:
        \\  TypeA:
        \\    fields:
        \\      ref: TypeB
        \\  TypeB:
        \\    fields:
        \\      value: String
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "unknown_type")) {
            try std.testing.expect(false); // TypeB should be found via two-pass
        }
    }
}

test "output missing is warning not error" {
    const source =
        \\name: test_spec
        \\version: 1.0.0
    ;
    const errs = try validateSpec(source, "specs/tri/core/test.tri");
    for (errs) |e| {
        if (std.mem.eql(u8, e.code, "missing_output")) {
            try std.testing.expectEqual(Severity.warning, e.severity);
        }
    }
}
