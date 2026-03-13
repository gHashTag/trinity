// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI SPEC ENRICHER — Read .zig files, enrich .tri specs
// ═══════════════════════════════════════════════════════════════════════════════
// Issue #69: Spec Enricher — read .zig, enrich .tri
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExtractedType = struct {
    name: []const u8,
    kind: []const u8, // "struct", "enum", "union"
    field_names: []const []const u8,
};

pub const ExtractedFunction = struct {
    name: []const u8,
    params: []const u8, // raw param string
    return_type: []const u8,
    is_public: bool,
};

pub const ExtractedTest = struct {
    name: []const u8,
};

pub const EnrichResult = struct {
    spec_path: []const u8,
    zig_path: []const u8,
    types_found: usize,
    functions_found: usize,
    tests_found: usize,
    updated: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FIND ZIG SOURCE
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract stem from a spec path: "specs/tri/foo_bar.tri" → "foo_bar"
pub fn extractStem(path: []const u8) []const u8 {
    // Find last '/'
    var start: usize = 0;
    for (path, 0..) |c, i| {
        if (c == '/') start = i + 1;
    }
    // Find last '.'
    var end: usize = path.len;
    var i: usize = path.len;
    while (i > start) {
        i -= 1;
        if (path[i] == '.') {
            end = i;
            break;
        }
    }
    return path[start..end];
}

/// Find the .zig file corresponding to a .tri spec.
/// Checks: generated/{stem}.zig, src/tri/{stem}.zig, src/tri/tri_{stem}.zig
pub fn findZigSource(allocator: Allocator, spec_path: []const u8) !?[]const u8 {
    const stem = extractStem(spec_path);

    // Candidate paths to check
    const candidates = [_]struct { fmt: []const u8 }{
        .{ .fmt = "generated/" },
        .{ .fmt = "src/tri/" },
        .{ .fmt = "src/tri/tri_" },
    };

    for (candidates) |c| {
        const path = try std.fmt.allocPrint(allocator, "{s}{s}.zig", .{ c.fmt, stem });
        std.fs.cwd().access(path, .{}) catch {
            allocator.free(path);
            continue;
        };
        return path;
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract pub const X = struct/enum/union definitions.
pub fn extractTypes(allocator: Allocator, source: []const u8) ![]ExtractedType {
    var types: std.ArrayList(ExtractedType) = .empty;
    errdefer types.deinit(allocator);

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        // Match: "pub const FooBar = struct {" or "pub const FooBar = enum {"
        if (!std.mem.startsWith(u8, trimmed, "pub const ")) continue;
        const after_const = trimmed["pub const ".len..];

        // Find " = "
        const eq_pos = std.mem.indexOf(u8, after_const, " = ") orelse continue;
        const name = after_const[0..eq_pos];
        const after_eq = after_const[eq_pos + 3 ..];

        // Determine kind
        var kind: []const u8 = "";
        if (std.mem.startsWith(u8, after_eq, "struct")) {
            kind = "struct";
        } else if (std.mem.startsWith(u8, after_eq, "enum")) {
            kind = "enum";
        } else if (std.mem.startsWith(u8, after_eq, "union")) {
            kind = "union";
        } else continue;

        // Validate name is PascalCase (starts with uppercase)
        if (name.len == 0 or name[0] < 'A' or name[0] > 'Z') continue;

        try types.append(allocator, .{
            .name = name,
            .kind = kind,
            .field_names = &.{},
        });
    }

    return types.toOwnedSlice(allocator);
}

/// Extract pub fn signatures.
pub fn extractFunctions(allocator: Allocator, source: []const u8) ![]ExtractedFunction {
    var fns: std.ArrayList(ExtractedFunction) = .empty;
    errdefer fns.deinit(allocator);

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        const is_pub = std.mem.startsWith(u8, trimmed, "pub fn ");
        if (!is_pub and !std.mem.startsWith(u8, trimmed, "fn ")) continue;

        const fn_start = if (is_pub) trimmed["pub fn ".len..] else trimmed["fn ".len..];

        // Extract name (up to '(')
        const paren_pos = std.mem.indexOf(u8, fn_start, "(") orelse continue;
        const name = fn_start[0..paren_pos];

        // Skip test-like or internal names
        if (name.len == 0) continue;

        // Find return type: after ") " until " {" or end
        const after_name = fn_start[paren_pos..];
        const close_paren = std.mem.indexOf(u8, after_name, ") ") orelse continue;
        var ret_type = after_name[close_paren + 2 ..];

        // Trim trailing " {" or " {"
        if (std.mem.endsWith(u8, ret_type, " {")) {
            ret_type = ret_type[0 .. ret_type.len - 2];
        }

        // Extract params between ( )
        const params = after_name[1..close_paren];

        try fns.append(allocator, .{
            .name = name,
            .params = params,
            .return_type = ret_type,
            .is_public = is_pub,
        });
    }

    return fns.toOwnedSlice(allocator);
}

/// Extract test "name" blocks.
pub fn extractTests(allocator: Allocator, source: []const u8) ![]ExtractedTest {
    var tests: std.ArrayList(ExtractedTest) = .empty;
    errdefer tests.deinit(allocator);

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (!std.mem.startsWith(u8, trimmed, "test \"")) continue;

        const after_test = trimmed["test \"".len..];
        const close_quote = std.mem.indexOf(u8, after_test, "\"") orelse continue;
        const name = after_test[0..close_quote];

        try tests.append(allocator, .{
            .name = name,
        });
    }

    return tests.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC ENRICHMENT
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate enriched types section as .tri YAML.
pub fn renderTypesSection(allocator: Allocator, types: []const ExtractedType) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);

    if (types.len == 0) return buf.toOwnedSlice(allocator);

    try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
    try w.writeAll("# TYPE SYSTEM (enriched from .zig source)\n");
    try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n\n");
    try w.writeAll("types:\n");

    for (types) |t| {
        if (std.mem.eql(u8, t.kind, "enum")) {
            try w.print("  {s}:\n", .{t.name});
            try w.writeAll("    variants:\n");
            try w.writeAll("      - placeholder\n");
        } else {
            try w.print("  {s}:\n", .{t.name});
            try w.writeAll("    fields:\n");
            try w.writeAll("      placeholder: String\n");
        }
    }
    try w.writeByte('\n');

    return buf.toOwnedSlice(allocator);
}

/// Generate enriched behaviors section as .tri YAML.
pub fn renderBehaviorsSection(allocator: Allocator, fns: []const ExtractedFunction) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);

    // Only include public functions
    var pub_count: usize = 0;
    for (fns) |f| {
        if (f.is_public) pub_count += 1;
    }
    if (pub_count == 0) return buf.toOwnedSlice(allocator);

    try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
    try w.writeAll("# BEHAVIORS (enriched from .zig source)\n");
    try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n\n");
    try w.writeAll("behaviors:\n");

    for (fns) |f| {
        if (!f.is_public) continue;
        try w.print("  {s}:\n", .{f.name});
        try w.print("    description: \"Auto-extracted from .zig\"\n", .{});
        if (f.params.len > 0) {
            try w.writeAll("    inputs:\n");
            try w.print("      - args: String\n", .{});
        }
        try w.print("    output: {s}\n", .{if (std.mem.eql(u8, f.return_type, "void")) "Void" else "String"});
        try w.writeAll("    steps:\n");
        try w.writeAll("      - Implementation exists in .zig\n");
    }
    try w.writeByte('\n');

    return buf.toOwnedSlice(allocator);
}

/// Generate enriched tests section as .tri YAML.
pub fn renderTestsSection(allocator: Allocator, tests: []const ExtractedTest) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);

    if (tests.len == 0) return buf.toOwnedSlice(allocator);

    try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
    try w.writeAll("# TESTS (enriched from .zig source)\n");
    try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n\n");
    try w.writeAll("tests:\n");

    for (tests) |t| {
        try w.print("  - name: \"{s}\"\n", .{t.name});
        try w.writeAll("    input: {}\n");
        try w.writeAll("    expected: {}\n");
    }

    return buf.toOwnedSlice(allocator);
}

/// Enrich a .tri spec by reading the corresponding .zig file.
pub fn enrichSpec(allocator: Allocator, spec_path: []const u8) !EnrichResult {
    // Find corresponding .zig
    const zig_path = try findZigSource(allocator, spec_path) orelse {
        std.debug.print("  \x1b[33mWARN:\x1b[0m No .zig source found for {s}\n", .{spec_path});
        return .{
            .spec_path = spec_path,
            .zig_path = "",
            .types_found = 0,
            .functions_found = 0,
            .tests_found = 0,
            .updated = false,
        };
    };

    // Read .zig source
    const source = std.fs.cwd().readFileAlloc(allocator, zig_path, 10 * 1024 * 1024) catch |err| {
        std.debug.print("  \x1b[31mERROR:\x1b[0m Cannot read {s}: {}\n", .{ zig_path, err });
        return .{
            .spec_path = spec_path,
            .zig_path = zig_path,
            .types_found = 0,
            .functions_found = 0,
            .tests_found = 0,
            .updated = false,
        };
    };
    defer allocator.free(source);

    // Extract
    const types = try extractTypes(allocator, source);
    const fns = try extractFunctions(allocator, source);
    const tests = try extractTests(allocator, source);

    // Read existing spec
    const existing_spec = std.fs.cwd().readFileAlloc(allocator, spec_path, 1024 * 1024) catch "";
    defer if (existing_spec.len > 0) allocator.free(existing_spec);

    // Generate enriched spec
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const w = out.writer(allocator);

    // Copy existing spec header (everything up to "types:" or "behaviors:" or end)
    const stem = extractStem(spec_path);
    if (existing_spec.len > 0) {
        // Find where auto-generated sections start
        var cut_point = existing_spec.len;
        if (std.mem.indexOf(u8, existing_spec, "# TYPE SYSTEM (enriched")) |pos| {
            cut_point = pos;
        } else if (std.mem.indexOf(u8, existing_spec, "types:\n")) |pos| {
            // Check if this is preceded by a comment about enrichment
            cut_point = pos;
        }
        try w.writeAll(existing_spec[0..cut_point]);
    } else {
        // Generate header
        try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
        try w.print("# VIBEE Specification — {s}\n", .{stem});
        try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n");
        try w.writeAll("# φ² + 1/φ² = 3 = TRINITY\n");
        try w.writeAll("# Enriched by Spec Enricher (Issue #69)\n");
        try w.writeAll("# ═══════════════════════════════════════════════════════════════════════════════\n\n");
        try w.print("name: {s}\n", .{stem});
        try w.writeAll("version: \"1.0.0\"\n");
        try w.writeAll("language: zig\n");
        try w.print("module: {s}\n\n", .{stem});
        try w.writeAll("description: |\n");
        try w.print("  Auto-enriched spec for {s}\n\n", .{stem});
    }

    // Append enriched sections
    const types_section = try renderTypesSection(allocator, types);
    defer allocator.free(types_section);
    if (types_section.len > 0) try w.writeAll(types_section);

    const fns_section = try renderBehaviorsSection(allocator, fns);
    defer allocator.free(fns_section);
    if (fns_section.len > 0) try w.writeAll(fns_section);

    const tests_section = try renderTestsSection(allocator, tests);
    defer allocator.free(tests_section);
    if (tests_section.len > 0) try w.writeAll(tests_section);

    // Write enriched spec
    const enriched = try out.toOwnedSlice(allocator);
    defer allocator.free(enriched);

    const spec_file = try std.fs.cwd().createFile(spec_path, .{});
    defer spec_file.close();
    try spec_file.writeAll(enriched);

    return .{
        .spec_path = spec_path,
        .zig_path = zig_path,
        .types_found = types.len,
        .functions_found = fns.len,
        .tests_found = tests.len,
        .updated = true,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

/// Run the enrich command: `tri enrich <spec.tri>` or `tri enrich --all`
pub fn runEnrichCommand(allocator: Allocator, args: []const []const u8) !void {
    std.debug.print("\n\x1b[33m🔱 TRI SPEC ENRICHER\x1b[0m — φ² + 1/φ² = 3\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    var all_mode = false;
    var target: ?[]const u8 = null;
    var dry_run = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--all") or std.mem.eql(u8, arg, "-a")) {
            all_mode = true;
        } else if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-n")) {
            dry_run = true;
        } else if (arg.len > 0 and arg[0] != '-') {
            target = arg;
        }
    }

    if (!all_mode and target == null) {
        std.debug.print("Usage: tri enrich <spec.tri>     Enrich a single spec\n", .{});
        std.debug.print("       tri enrich --all          Enrich all specs with .zig sources\n", .{});
        std.debug.print("       tri enrich --dry-run      Show what would be enriched\n", .{});
        return;
    }

    if (target) |spec_path| {
        // Single spec mode
        std.debug.print("  Enriching: {s}\n", .{spec_path});
        if (dry_run) {
            const zig_path = try findZigSource(allocator, spec_path);
            if (zig_path) |zp| {
                std.debug.print("  \x1b[32mWould read:\x1b[0m {s}\n", .{zp});
                allocator.free(zp);
            } else {
                std.debug.print("  \x1b[33mNo .zig source found\x1b[0m\n", .{});
            }
            return;
        }

        const result = try enrichSpec(allocator, spec_path);
        printResult(result);
    } else {
        // All mode — scan specs/tri/*.tri
        std.debug.print("  Scanning specs/tri/ for enrichable specs...\n\n", .{});

        var enriched: usize = 0;
        var skipped: usize = 0;
        var total_types: usize = 0;
        var total_fns: usize = 0;
        var total_tests: usize = 0;

        var dir = std.fs.cwd().openDir("specs/tri", .{ .iterate = true }) catch {
            std.debug.print("  \x1b[31mERROR:\x1b[0m Cannot open specs/tri/\n", .{});
            return;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;

            const spec_path = try std.fmt.allocPrint(allocator, "specs/tri/{s}", .{entry.name});
            defer allocator.free(spec_path);

            if (dry_run) {
                const zig_path = try findZigSource(allocator, spec_path);
                if (zig_path) |zp| {
                    std.debug.print("  \x1b[32m✓\x1b[0m {s} → {s}\n", .{ entry.name, zp });
                    allocator.free(zp);
                    enriched += 1;
                } else {
                    skipped += 1;
                }
                continue;
            }

            const result = try enrichSpec(allocator, spec_path);
            if (result.updated) {
                enriched += 1;
                total_types += result.types_found;
                total_fns += result.functions_found;
                total_tests += result.tests_found;
                std.debug.print("  \x1b[32m✓\x1b[0m {s}: {d} types, {d} fns, {d} tests\n", .{
                    entry.name, result.types_found, result.functions_found, result.tests_found,
                });
            } else {
                skipped += 1;
            }
        }

        // Summary
        std.debug.print("\n\x1b[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n", .{});
        if (dry_run) {
            std.debug.print("  \x1b[36mDRY RUN:\x1b[0m {d} enrichable, {d} skipped\n", .{ enriched, skipped });
        } else {
            std.debug.print("  \x1b[32mEnriched:\x1b[0m {d} specs ({d} types, {d} fns, {d} tests)\n", .{
                enriched, total_types, total_fns, total_tests,
            });
            std.debug.print("  \x1b[90mSkipped:\x1b[0m  {d} (no .zig source)\n", .{skipped});
        }

        // V-formula
        const phi = 1.618034;
        const total = enriched + skipped;
        if (total > 0) {
            const rate: f64 = @as(f64, @floatFromInt(enriched)) / @as(f64, @floatFromInt(total));
            const v = phi * rate * rate;
            std.debug.print("  \x1b[33mV = φ·(enriched/total)² = {d:.3}\x1b[0m\n", .{v});
        }
    }
}

fn printResult(result: EnrichResult) void {
    if (result.updated) {
        std.debug.print("  \x1b[32m✓ Enriched:\x1b[0m {s}\n", .{result.spec_path});
        std.debug.print("    Source:    {s}\n", .{result.zig_path});
        std.debug.print("    Types:     {d}\n", .{result.types_found});
        std.debug.print("    Functions: {d}\n", .{result.functions_found});
        std.debug.print("    Tests:     {d}\n", .{result.tests_found});
    } else {
        std.debug.print("  \x1b[33m⚠ Skipped:\x1b[0m {s} (no .zig source)\n", .{result.spec_path});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "extractStem — basic path" {
    try std.testing.expectEqualStrings("foo_bar", extractStem("specs/tri/foo_bar.tri"));
}

test "extractStem — no directory" {
    try std.testing.expectEqualStrings("test", extractStem("test.tri"));
}

test "extractTypes — finds struct" {
    const allocator = std.testing.allocator;
    const source = "pub const FooBar = struct {\n    x: u32,\n};";
    const types = try extractTypes(allocator, source);
    defer allocator.free(types);

    try std.testing.expectEqual(@as(usize, 1), types.len);
    try std.testing.expectEqualStrings("FooBar", types[0].name);
    try std.testing.expectEqualStrings("struct", types[0].kind);
}

test "extractTypes — finds enum" {
    const allocator = std.testing.allocator;
    const source = "pub const Status = enum {\n    ok,\n    err,\n};";
    const types = try extractTypes(allocator, source);
    defer allocator.free(types);

    try std.testing.expectEqual(@as(usize, 1), types.len);
    try std.testing.expectEqualStrings("Status", types[0].name);
    try std.testing.expectEqualStrings("enum", types[0].kind);
}

test "extractTypes — skips non-PascalCase" {
    const allocator = std.testing.allocator;
    const source = "pub const foo_bar = struct {};";
    const types = try extractTypes(allocator, source);
    defer allocator.free(types);

    try std.testing.expectEqual(@as(usize, 0), types.len);
}

test "extractFunctions — finds pub fn" {
    const allocator = std.testing.allocator;
    const source = "pub fn doStuff(a: u32) void {\n}";
    const fns = try extractFunctions(allocator, source);
    defer allocator.free(fns);

    try std.testing.expectEqual(@as(usize, 1), fns.len);
    try std.testing.expectEqualStrings("doStuff", fns[0].name);
    try std.testing.expect(fns[0].is_public);
}

test "extractFunctions — finds private fn" {
    const allocator = std.testing.allocator;
    const source = "fn helper(x: u8) u8 {\n}";
    const fns = try extractFunctions(allocator, source);
    defer allocator.free(fns);

    try std.testing.expectEqual(@as(usize, 1), fns.len);
    try std.testing.expectEqualStrings("helper", fns[0].name);
    try std.testing.expect(!fns[0].is_public);
}

test "extractTests — finds test blocks" {
    const allocator = std.testing.allocator;
    const source = "test \"my cool test\" {\n    try expect(true);\n}";
    const tests = try extractTests(allocator, source);
    defer allocator.free(tests);

    try std.testing.expectEqual(@as(usize, 1), tests.len);
    try std.testing.expectEqualStrings("my cool test", tests[0].name);
}

test "extractTests — multiple tests" {
    const allocator = std.testing.allocator;
    const source = "test \"first\" {}\ntest \"second\" {}";
    const tests = try extractTests(allocator, source);
    defer allocator.free(tests);

    try std.testing.expectEqual(@as(usize, 2), tests.len);
    try std.testing.expectEqualStrings("first", tests[0].name);
    try std.testing.expectEqualStrings("second", tests[1].name);
}
