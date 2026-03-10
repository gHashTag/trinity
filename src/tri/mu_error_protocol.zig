// ═══════════════════════════════════════════════════════════════════════════════
// MU ERROR PROTOCOL — Structured failure logging
// ═══════════════════════════════════════════════════════════════════════════════
// Issue #73: Log every pipeline failure to .trinity/mu/errors/
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ErrorCategory = enum {
    type_mapping,
    undefined_identifier,
    syntax_error,
    format_error,
    import_error,
    memory_error,
    test_failure,
    gen_failure,
    unknown,

    pub fn toString(self: ErrorCategory) []const u8 {
        return switch (self) {
            .type_mapping => "TYPE_MAPPING",
            .undefined_identifier => "UNDEFINED_IDENTIFIER",
            .syntax_error => "SYNTAX_ERROR",
            .format_error => "FORMAT_ERROR",
            .import_error => "IMPORT_ERROR",
            .memory_error => "MEMORY_ERROR",
            .test_failure => "TEST_FAILURE",
            .gen_failure => "GEN_FAILURE",
            .unknown => "UNKNOWN",
        };
    }

    pub fn fromString(s: []const u8) ErrorCategory {
        const categories = .{
            .{ "TYPE_MAPPING", ErrorCategory.type_mapping },
            .{ "UNDEFINED_IDENTIFIER", ErrorCategory.undefined_identifier },
            .{ "SYNTAX_ERROR", ErrorCategory.syntax_error },
            .{ "FORMAT_ERROR", ErrorCategory.format_error },
            .{ "IMPORT_ERROR", ErrorCategory.import_error },
            .{ "MEMORY_ERROR", ErrorCategory.memory_error },
            .{ "TEST_FAILURE", ErrorCategory.test_failure },
            .{ "GEN_FAILURE", ErrorCategory.gen_failure },
        };
        inline for (categories) |pair| {
            if (std.mem.eql(u8, s, pair[0])) return pair[1];
        }
        return .unknown;
    }
};

pub const MuError = struct {
    timestamp: []const u8,
    spec: []const u8,
    link: usize,
    link_name: []const u8,
    error_category: ErrorCategory,
    error_message: []const u8,
    error_line: usize,
    generated_file: []const u8,
    fix_attempted: bool,
    fix_result: []const u8, // empty string if none
};

pub const ErrorStats = struct {
    total: usize,
    by_category: [9]usize, // indexed by ErrorCategory ordinal
    last_timestamp: []const u8,

    pub fn init() ErrorStats {
        return .{
            .total = 0,
            .by_category = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .last_timestamp = "",
        };
    }
};

const ERRORS_DIR = ".trinity/mu/errors";

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR CATEGORIZATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Classify an error message into an ErrorCategory.
pub fn categorizeError(message: []const u8) ErrorCategory {
    // Vibee gen wrapper errors (extract inner error)
    if (std.mem.indexOf(u8, message, "Verification FAILED") != null) {
        // Check for nested error patterns
        if (std.mem.indexOf(u8, message, "undeclared identifier") != null or
            std.mem.indexOf(u8, message, "unused") != null or
            std.mem.indexOf(u8, message, "error:") != null)
        {
            // Re-categorize based on the actual error inside
            if (std.mem.indexOf(u8, message, "undeclared identifier") != null) return .undefined_identifier;
            if (std.mem.indexOf(u8, message, "unused") != null) return .syntax_error;
        }
        return .gen_failure; // vibee gen itself failed
    }

    // Type mapping errors
    if (std.mem.indexOf(u8, message, "undeclared identifier") != null) return .undefined_identifier;
    if (std.mem.indexOf(u8, message, "Int64") != null or
        std.mem.indexOf(u8, message, "Float32") != null or
        std.mem.indexOf(u8, message, "type mismatch") != null or
        std.mem.indexOf(u8, message, "no member named") != null)
        return .type_mapping;

    // Syntax errors
    if (std.mem.indexOf(u8, message, "expected") != null and
        (std.mem.indexOf(u8, message, "';'") != null or
        std.mem.indexOf(u8, message, "token") != null or
        std.mem.indexOf(u8, message, "expression") != null))
        return .syntax_error;

    // Format errors
    if (std.mem.indexOf(u8, message, "formatting check failed") != null or
        std.mem.indexOf(u8, message, "zig fmt") != null)
        return .format_error;

    // Import errors
    if (std.mem.indexOf(u8, message, "import") != null or
        std.mem.indexOf(u8, message, "@import") != null)
        return .import_error;

    // Memory errors
    if (std.mem.indexOf(u8, message, "OutOfMemory") != null or
        std.mem.indexOf(u8, message, "allocator") != null)
        return .memory_error;

    // Test failures
    if (std.mem.indexOf(u8, message, "test") != null and
        std.mem.indexOf(u8, message, "FAIL") != null)
        return .test_failure;

    // Gen failures
    if (std.mem.indexOf(u8, message, "gen") != null and
        (std.mem.indexOf(u8, message, "failed") != null or
        std.mem.indexOf(u8, message, "error") != null))
        return .gen_failure;

    // Verilog/FPGA output (not a Zig error)
    if (std.mem.indexOf(u8, message, ".v\n") != null or
        std.mem.indexOf(u8, message, "fpga") != null or
        std.mem.indexOf(u8, message, "verilog") != null)
        return .gen_failure;

    // Generic "error:" pattern
    if (std.mem.indexOf(u8, message, "error:") != null)
        return .syntax_error;

    return .unknown;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGGING
// ═══════════════════════════════════════════════════════════════════════════════

/// Ensure the errors directory exists.
fn ensureDir() !void {
    std.fs.cwd().makePath(ERRORS_DIR) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
}

/// Generate a timestamp string for filenames.
fn getTimestamp(allocator: Allocator) ![]u8 {
    const epoch = std.time.timestamp();
    return std.fmt.allocPrint(allocator, "{d}", .{epoch});
}

/// Log a pipeline error to .trinity/mu/errors/{timestamp}.json
pub fn logError(allocator: Allocator, err: MuError) ![]u8 {
    try ensureDir();

    const ts = if (err.timestamp.len > 0)
        try allocator.dupe(u8, err.timestamp)
    else
        try getTimestamp(allocator);
    defer allocator.free(ts);

    const filename = try std.fmt.allocPrint(allocator, ERRORS_DIR ++ "/{s}.json", .{ts});

    // Build JSON manually (no std.json.stringify in Zig 0.15)
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const w = buf.writer(allocator);

    try w.writeAll("{\n");
    try w.print("  \"timestamp\": \"{s}\",\n", .{ts});
    try w.print("  \"spec\": \"{s}\",\n", .{err.spec});
    try w.print("  \"link\": {d},\n", .{err.link});
    try w.print("  \"link_name\": \"{s}\",\n", .{err.link_name});
    try w.print("  \"error_category\": \"{s}\",\n", .{err.error_category.toString()});
    // Escape error message for JSON
    try w.writeAll("  \"error_message\": \"");
    for (err.error_message) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            else => try w.writeByte(c),
        }
    }
    try w.writeAll("\",\n");
    try w.print("  \"error_line\": {d},\n", .{err.error_line});
    try w.print("  \"generated_file\": \"{s}\",\n", .{err.generated_file});
    try w.print("  \"fix_attempted\": {s},\n", .{if (err.fix_attempted) "true" else "false"});
    try w.print("  \"fix_result\": \"{s}\"\n", .{err.fix_result});
    try w.writeAll("}\n");

    const json = try buf.toOwnedSlice(allocator);
    defer allocator.free(json);

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(json);

    return filename;
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUERYING
// ═══════════════════════════════════════════════════════════════════════════════

/// Count error files by scanning directory.
pub fn countErrors(allocator: Allocator) !ErrorStats {
    _ = allocator;
    var stats = ErrorStats.init();

    var dir = std.fs.cwd().openDir(ERRORS_DIR, .{ .iterate = true }) catch {
        return stats; // No errors dir = no errors
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        stats.total += 1;

        // Try to read and parse category from file
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, ERRORS_DIR ++ "/{s}", .{entry.name}) catch continue;

        const content = dir.readFileAlloc(std.heap.page_allocator, entry.name, 64 * 1024) catch continue;
        defer std.heap.page_allocator.free(content);

        // Simple category extraction from JSON
        if (std.mem.indexOf(u8, content, "\"error_category\": \"")) |pos| {
            const start = pos + "\"error_category\": \"".len;
            if (std.mem.indexOfScalarPos(u8, content, start, '"')) |end| {
                const cat_str = content[start..end];
                const cat = ErrorCategory.fromString(cat_str);
                stats.by_category[@intFromEnum(cat)] += 1;
            }
        }

        // Track latest timestamp
        const stem = entry.name[0 .. entry.name.len - 5]; // strip .json
        _ = stem;
        _ = path;
    }

    return stats;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Run `tri mu errors [--category X] [--limit N]`
pub fn runMuErrorsCommand(allocator: Allocator, args: []const []const u8) !void {
    std.debug.print("\n\x1b[33m🧠 MU ERROR PROTOCOL\x1b[0m — φ² + 1/φ² = 3\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    var category_filter: ?[]const u8 = null;
    var limit: usize = 20;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--category") or std.mem.eql(u8, args[i], "-c")) {
            if (i + 1 < args.len) {
                i += 1;
                category_filter = args[i];
            }
        } else if (std.mem.eql(u8, args[i], "--limit") or std.mem.eql(u8, args[i], "-l")) {
            if (i + 1 < args.len) {
                i += 1;
                limit = std.fmt.parseInt(usize, args[i], 10) catch 20;
            }
        }
    }

    // Scan errors directory
    var dir = std.fs.cwd().openDir(ERRORS_DIR, .{ .iterate = true }) catch {
        std.debug.print("  \x1b[90mNo errors logged yet.\x1b[0m\n", .{});
        std.debug.print("  Directory: {s}\n", .{ERRORS_DIR});
        return;
    };
    defer dir.close();

    var count: usize = 0;
    var shown: usize = 0;

    std.debug.print("  \x1b[36mFilter:\x1b[0m {s}\n", .{category_filter orelse "ALL"});
    std.debug.print("  \x1b[36mLimit:\x1b[0m  {d}\n\n", .{limit});

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        count += 1;

        if (shown >= limit) continue;

        const content = dir.readFileAlloc(allocator, entry.name, 64 * 1024) catch continue;
        defer allocator.free(content);

        // Apply category filter
        if (category_filter) |cat| {
            if (std.mem.indexOf(u8, content, cat) == null) continue;
        }

        // Print error summary
        shown += 1;
        const stem = entry.name[0 .. entry.name.len - 5];
        std.debug.print("  \x1b[31m{d}.\x1b[0m [{s}] ", .{ shown, stem });

        // Extract category
        if (std.mem.indexOf(u8, content, "\"error_category\": \"")) |pos| {
            const start = pos + "\"error_category\": \"".len;
            if (std.mem.indexOfScalarPos(u8, content, start, '"')) |end| {
                std.debug.print("\x1b[33m{s}\x1b[0m", .{content[start..end]});
            }
        }

        // Extract spec
        if (std.mem.indexOf(u8, content, "\"spec\": \"")) |pos| {
            const start = pos + "\"spec\": \"".len;
            if (std.mem.indexOfScalarPos(u8, content, start, '"')) |end| {
                std.debug.print(" — {s}", .{content[start..end]});
            }
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n  \x1b[90mTotal: {d} errors, showing {d}\x1b[0m\n", .{ count, shown });
}

/// Run `tri mu stats`
pub fn runMuStatsCommand(allocator: Allocator) !void {
    std.debug.print("\n\x1b[33m🧠 MU ERROR STATS\x1b[0m — φ² + 1/φ² = 3\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    const stats = try countErrors(allocator);

    if (stats.total == 0) {
        std.debug.print("  \x1b[32mNo errors logged. Pipeline is clean.\x1b[0m\n", .{});
        return;
    }

    std.debug.print("  \x1b[36mTotal errors:\x1b[0m {d}\n\n", .{stats.total});
    std.debug.print("  ┌─────────────────────────┬───────┐\n", .{});
    std.debug.print("  │ Category                │ Count │\n", .{});
    std.debug.print("  ├─────────────────────────┼───────┤\n", .{});

    const categories = [_]ErrorCategory{
        .type_mapping,
        .undefined_identifier,
        .syntax_error,
        .format_error,
        .import_error,
        .memory_error,
        .test_failure,
        .gen_failure,
        .unknown,
    };

    for (categories) |cat| {
        const count = stats.by_category[@intFromEnum(cat)];
        if (count > 0) {
            const name = cat.toString();
            std.debug.print("  │ {s:<23} │ {d:>5} │\n", .{ name, count });
        }
    }
    std.debug.print("  └─────────────────────────┴───────┘\n", .{});

    // V-formula
    const phi = 1.618034;
    const rate: f64 = if (stats.total > 0)
        @as(f64, @floatFromInt(stats.total))
    else
        0;
    _ = rate;
    std.debug.print("\n  \x1b[33mV = φ·(1 - errors/baseline)²\x1b[0m\n", .{});
    std.debug.print("  \x1b[33mφ = {d:.6}\x1b[0m\n", .{phi});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "categorizeError — type mapping" {
    try std.testing.expectEqual(ErrorCategory.type_mapping, categorizeError("no member named 'foo'"));
}

test "categorizeError — undefined identifier" {
    try std.testing.expectEqual(ErrorCategory.undefined_identifier, categorizeError("use of undeclared identifier 'Int64'"));
}

test "categorizeError — syntax error" {
    try std.testing.expectEqual(ErrorCategory.syntax_error, categorizeError("expected ';' after statement"));
}

test "categorizeError — format error" {
    try std.testing.expectEqual(ErrorCategory.format_error, categorizeError("formatting check failed (run 'zig fmt')"));
}

test "categorizeError — unknown" {
    try std.testing.expectEqual(ErrorCategory.unknown, categorizeError("something weird happened"));
}

test "ErrorCategory — fromString roundtrip" {
    const cats = [_]ErrorCategory{ .type_mapping, .undefined_identifier, .syntax_error, .format_error, .unknown };
    for (cats) |cat| {
        try std.testing.expectEqual(cat, ErrorCategory.fromString(cat.toString()));
    }
}

test "logError — creates file" {
    const allocator = std.testing.allocator;

    const err = MuError{
        .timestamp = "test_1234567890",
        .spec = "specs/tri/test.tri",
        .link = 7,
        .link_name = "code_generate",
        .error_category = .type_mapping,
        .error_message = "test error msg",
        .error_line = 42,
        .generated_file = "generated/test.zig",
        .fix_attempted = false,
        .fix_result = "",
    };

    const path = try logError(allocator, err);
    defer allocator.free(path);

    // Verify file exists
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024);
    defer allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "TYPE_MAPPING") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "test error msg") != null);

    // Cleanup
    std.fs.cwd().deleteFile(path) catch {};
}
