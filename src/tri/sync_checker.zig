// ═══════════════════════════════════════════════════════════════════════════════
// SPEC ↔ CODE SYNC CHECKER — Detect drift between .tri and .zig
// ═══════════════════════════════════════════════════════════════════════════════
// Issue #71: Compare .tri spec definitions against .zig code.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const SyncResult = struct {
    spec_path: []const u8,
    code_path: []const u8,
    spec_types: std.ArrayList([]const u8),
    spec_behaviors: std.ArrayList([]const u8),
    code_types: std.ArrayList([]const u8),
    code_functions: std.ArrayList([]const u8),
    missing_in_code: std.ArrayList([]const u8),
    missing_in_spec: std.ArrayList([]const u8),
    matched: std.ArrayList([]const u8),
    is_synced: bool,

    pub fn init(allocator: Allocator) SyncResult {
        _ = allocator;
        return .{
            .spec_path = "",
            .code_path = "",
            .spec_types = .empty,
            .spec_behaviors = .empty,
            .code_types = .empty,
            .code_functions = .empty,
            .missing_in_code = .empty,
            .missing_in_spec = .empty,
            .matched = .empty,
            .is_synced = true,
        };
    }

    pub fn deinit(self: *SyncResult, allocator: Allocator) void {
        for (self.spec_types.items) |s| allocator.free(s);
        self.spec_types.deinit(allocator);
        for (self.spec_behaviors.items) |s| allocator.free(s);
        self.spec_behaviors.deinit(allocator);
        for (self.code_types.items) |s| allocator.free(s);
        self.code_types.deinit(allocator);
        for (self.code_functions.items) |s| allocator.free(s);
        self.code_functions.deinit(allocator);
        // missing/matched are borrowed pointers, don't free
        self.missing_in_code.deinit(allocator);
        self.missing_in_spec.deinit(allocator);
        self.matched.deinit(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC PARSING
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse .tri spec file → extract type names and behavior names.
pub fn parseSpec(allocator: Allocator, spec_path: []const u8) !SyncResult {
    var result = SyncResult.init(allocator);
    result.spec_path = spec_path;

    const content = std.fs.cwd().readFileAlloc(allocator, spec_path, 1024 * 1024) catch {
        return result;
    };
    defer allocator.free(content);

    var in_types = false;
    var in_behaviors = false;
    var indent_level: usize = 0;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimLeft(u8, line, " ");

        // Detect section headers
        if (std.mem.startsWith(u8, trimmed, "types:")) {
            in_types = true;
            in_behaviors = false;
            continue;
        }
        if (std.mem.startsWith(u8, trimmed, "behaviors:")) {
            in_behaviors = true;
            in_types = false;
            continue;
        }
        // Other top-level sections end types/behaviors
        if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "#") and
            !std.mem.startsWith(u8, trimmed, "-") and
            !std.mem.startsWith(u8, trimmed, " "))
        {
            // Check if it's a top-level key (no leading space in original)
            if (line.len > 0 and line[0] != ' ' and line[0] != '#') {
                in_types = false;
                in_behaviors = false;
            }
        }

        // Count leading spaces
        indent_level = 0;
        for (line) |c| {
            if (c == ' ') {
                indent_level += 1;
            } else break;
        }

        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // In types section: 2-space indent = type name (e.g. "  ErrorCategory:")
        if (in_types and indent_level == 2 and std.mem.endsWith(u8, trimmed, ":")) {
            const name = trimmed[0 .. trimmed.len - 1];
            try result.spec_types.append(allocator, try allocator.dupe(u8, name));
        }

        // In behaviors section: 2-space indent = behavior name (e.g. "  log_error:")
        if (in_behaviors and indent_level == 2 and std.mem.endsWith(u8, trimmed, ":")) {
            const name = trimmed[0 .. trimmed.len - 1];
            try result.spec_behaviors.append(allocator, try allocator.dupe(u8, name));
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CODE PARSING
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse .zig source file → extract pub types and pub functions.
pub fn parseCode(allocator: Allocator, code_path: []const u8, result: *SyncResult) !void {
    result.code_path = code_path;

    const content = std.fs.cwd().readFileAlloc(allocator, code_path, 10 * 1024 * 1024) catch {
        return;
    };
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimLeft(u8, line, " ");

        // pub const X = struct/enum/union
        if (std.mem.startsWith(u8, trimmed, "pub const ")) {
            const rest = trimmed["pub const ".len..];
            if (std.mem.indexOf(u8, rest, " = struct") != null or
                std.mem.indexOf(u8, rest, " = enum") != null or
                std.mem.indexOf(u8, rest, " = union") != null)
            {
                // Extract name
                if (std.mem.indexOfScalar(u8, rest, ' ')) |space| {
                    try result.code_types.append(allocator, try allocator.dupe(u8, rest[0..space]));
                }
            }
        }

        // pub fn name(
        if (std.mem.startsWith(u8, trimmed, "pub fn ")) {
            const rest = trimmed["pub fn ".len..];
            if (std.mem.indexOfScalar(u8, rest, '(')) |paren| {
                try result.code_functions.append(allocator, try allocator.dupe(u8, rest[0..paren]));
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

/// Compare spec items vs code items, populate missing/matched lists.
pub fn compare(allocator: Allocator, result: *SyncResult) !void {
    // All spec items (types + behaviors) should be in code
    // Types → code_types, Behaviors → code_functions

    // Check spec types against code types
    for (result.spec_types.items) |spec_type| {
        if (contains(result.code_types.items, spec_type)) {
            try result.matched.append(allocator, spec_type);
        } else {
            try result.missing_in_code.append(allocator, spec_type);
        }
    }

    // Check spec behaviors against code functions
    for (result.spec_behaviors.items) |behavior| {
        if (contains(result.code_functions.items, behavior)) {
            try result.matched.append(allocator, behavior);
        } else {
            try result.missing_in_code.append(allocator, behavior);
        }
    }

    // Check code items not in spec (informational)
    for (result.code_types.items) |code_type| {
        if (!contains(result.spec_types.items, code_type)) {
            try result.missing_in_spec.append(allocator, code_type);
        }
    }
    for (result.code_functions.items) |code_fn| {
        if (!contains(result.spec_behaviors.items, code_fn)) {
            try result.missing_in_spec.append(allocator, code_fn);
        }
    }

    result.is_synced = (result.missing_in_code.items.len == 0);
}

fn contains(items: []const []const u8, needle: []const u8) bool {
    for (items) |item| {
        if (std.mem.eql(u8, item, needle)) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESOLVE CODE PATH
// ═══════════════════════════════════════════════════════════════════════════════

/// Find the .zig file corresponding to a .tri spec.
/// Checks: generated/{stem}.zig, src/tri/{stem}.zig, src/tri/tri_{stem}.zig
pub fn findCodePath(allocator: Allocator, spec_path: []const u8) !?[]u8 {
    // Extract stem
    var stem_start: usize = 0;
    for (spec_path, 0..) |c, i| {
        if (c == '/') stem_start = i + 1;
    }
    var stem_end: usize = spec_path.len;
    var i: usize = spec_path.len;
    while (i > stem_start) {
        i -= 1;
        if (spec_path[i] == '.') {
            stem_end = i;
            break;
        }
    }
    const stem = spec_path[stem_start..stem_end];

    // Try paths in order
    inline for (.{ "generated/{s}.zig", "src/tri/{s}.zig", "src/tri/tri_{s}.zig" }) |template| {
        const path = try std.fmt.allocPrint(allocator, template, .{stem});
        if (std.fs.cwd().access(path, .{})) |_| {
            return path;
        } else |_| {
            allocator.free(path);
        }
    }

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════════

/// Run `tri sync-check <spec.tri>` or `tri sync-check --all`
pub fn runSyncCheckCommand(allocator: Allocator, args: []const []const u8) !u8 {
    std.debug.print("\n\x1b[33m🔄 SPEC ↔ CODE SYNC CHECKER\x1b[0m — φ² + 1/φ² = 3\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    if (args.len > 0 and std.mem.eql(u8, args[0], "--all")) {
        return try runSyncCheckAll(allocator);
    }

    if (args.len == 0) {
        std.debug.print("  Usage: tri sync-check <spec.tri>\n", .{});
        std.debug.print("         tri sync-check --all\n", .{});
        return 0;
    }

    const spec_path = args[0];
    return try runSyncCheckSingle(allocator, spec_path);
}

fn runSyncCheckSingle(allocator: Allocator, spec_path: []const u8) !u8 {
    var result = try parseSpec(allocator, spec_path);
    defer result.deinit(allocator);

    // Find code path
    const code_path = try findCodePath(allocator, spec_path) orelse {
        std.debug.print("  \x1b[31m❌ No code file found for {s}\x1b[0m\n", .{spec_path});
        std.debug.print("     Checked: generated/, src/tri/, src/tri/tri_\n", .{});
        return 1;
    };
    defer allocator.free(code_path);

    try parseCode(allocator, code_path, &result);
    try compare(allocator, &result);

    // Print report
    std.debug.print("  \x1b[36mSpec:\x1b[0m  {s}\n", .{spec_path});
    std.debug.print("  \x1b[36mCode:\x1b[0m  {s}\n\n", .{code_path});

    std.debug.print("  \x1b[36mSpec types:\x1b[0m      {d}\n", .{result.spec_types.items.len});
    std.debug.print("  \x1b[36mSpec behaviors:\x1b[0m  {d}\n", .{result.spec_behaviors.items.len});
    std.debug.print("  \x1b[36mCode types:\x1b[0m      {d}\n", .{result.code_types.items.len});
    std.debug.print("  \x1b[36mCode functions:\x1b[0m  {d}\n", .{result.code_functions.items.len});

    std.debug.print("\n  \x1b[32mMatched:\x1b[0m         {d}\n", .{result.matched.items.len});
    for (result.matched.items) |m| {
        std.debug.print("    ✅ {s}\n", .{m});
    }

    if (result.missing_in_code.items.len > 0) {
        std.debug.print("\n  \x1b[31mMissing in code:\x1b[0m {d}\n", .{result.missing_in_code.items.len});
        for (result.missing_in_code.items) |m| {
            std.debug.print("    ❌ {s}\n", .{m});
        }
    }

    if (result.missing_in_spec.items.len > 0) {
        std.debug.print("\n  \x1b[90mExtra in code (not in spec):\x1b[0m {d}\n", .{result.missing_in_spec.items.len});
        for (result.missing_in_spec.items) |m| {
            std.debug.print("    ➕ {s}\n", .{m});
        }
    }

    if (result.is_synced) {
        std.debug.print("\n  \x1b[32m✅ SYNCED — spec and code are aligned\x1b[0m\n", .{});
        return 0;
    } else {
        std.debug.print("\n  \x1b[31m❌ DRIFT DETECTED — {d} items in spec not in code\x1b[0m\n", .{result.missing_in_code.items.len});
        return 1;
    }
}

fn runSyncCheckAll(allocator: Allocator) !u8 {
    var dir = std.fs.cwd().openDir("specs/tri", .{ .iterate = true }) catch {
        std.debug.print("  \x1b[31mNo specs/tri directory found\x1b[0m\n", .{});
        return 1;
    };
    defer dir.close();

    var total: usize = 0;
    var synced: usize = 0;
    var drifted: usize = 0;
    var no_code: usize = 0;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;
        total += 1;

        const spec_path = try std.fmt.allocPrint(allocator, "specs/tri/{s}", .{entry.name});
        defer allocator.free(spec_path);

        var result = try parseSpec(allocator, spec_path);
        defer result.deinit(allocator);

        const code_path = try findCodePath(allocator, spec_path);
        if (code_path) |cp| {
            defer allocator.free(cp);
            try parseCode(allocator, cp, &result);
            try compare(allocator, &result);

            if (result.is_synced) {
                synced += 1;
                std.debug.print("  ✅ {s}\n", .{entry.name});
            } else {
                drifted += 1;
                std.debug.print("  ❌ {s} — {d} missing\n", .{ entry.name, result.missing_in_code.items.len });
            }
        } else {
            no_code += 1;
            std.debug.print("  ⚪ {s} — no code file\n", .{entry.name});
        }
    }

    std.debug.print("\n  \x1b[36mTotal specs:\x1b[0m  {d}\n", .{total});
    std.debug.print("  \x1b[32mSynced:\x1b[0m       {d}\n", .{synced});
    std.debug.print("  \x1b[31mDrifted:\x1b[0m      {d}\n", .{drifted});
    std.debug.print("  \x1b[90mNo code:\x1b[0m      {d}\n", .{no_code});

    if (total > 0) {
        const rate = (synced * 100) / total;
        std.debug.print("\n  \x1b[33mSync rate: {d}%\x1b[0m\n", .{rate});
    }

    return if (drifted > 0) @as(u8, 1) else @as(u8, 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parseSpec — mu_error_protocol.tri" {
    const allocator = std.testing.allocator;
    var result = try parseSpec(allocator, "specs/tri/mu_error_protocol.tri");
    defer result.deinit(allocator);

    // Should find at least ErrorCategory, MuError, Severity, ResolutionStatus, ErrorStats
    try std.testing.expect(result.spec_types.items.len >= 4);
    try std.testing.expect(contains(result.spec_types.items, "ErrorCategory"));
    try std.testing.expect(contains(result.spec_types.items, "Severity"));

    // Should find behaviors
    try std.testing.expect(result.spec_behaviors.items.len >= 3);
}

test "parseCode — mu_error_protocol.zig" {
    const allocator = std.testing.allocator;
    var result = SyncResult.init(allocator);
    defer result.deinit(allocator);

    try parseCode(allocator, "src/tri/mu_error_protocol.zig", &result);

    // Should find ErrorCategory, Severity, ResolutionStatus, MuError, ErrorStats
    try std.testing.expect(result.code_types.items.len >= 4);
    try std.testing.expect(contains(result.code_types.items, "ErrorCategory"));
    try std.testing.expect(contains(result.code_types.items, "Severity"));

    // Should find pub fns
    try std.testing.expect(result.code_functions.items.len >= 3);
    try std.testing.expect(contains(result.code_functions.items, "categorizeError"));
    try std.testing.expect(contains(result.code_functions.items, "logError"));
}

test "compare — finds matches" {
    const allocator = std.testing.allocator;
    var result = SyncResult.init(allocator);
    defer result.deinit(allocator);

    try result.spec_types.append(allocator, try allocator.dupe(u8, "Foo"));
    try result.spec_types.append(allocator, try allocator.dupe(u8, "Bar"));
    try result.code_types.append(allocator, try allocator.dupe(u8, "Foo"));
    try result.code_types.append(allocator, try allocator.dupe(u8, "Baz"));

    try compare(allocator, &result);

    try std.testing.expectEqual(@as(usize, 1), result.matched.items.len);
    try std.testing.expectEqual(@as(usize, 1), result.missing_in_code.items.len); // Bar
    try std.testing.expectEqual(@as(usize, 1), result.missing_in_spec.items.len); // Baz
    try std.testing.expect(!result.is_synced);
}

test "compare — fully synced" {
    const allocator = std.testing.allocator;
    var result = SyncResult.init(allocator);
    defer result.deinit(allocator);

    try result.spec_types.append(allocator, try allocator.dupe(u8, "X"));
    try result.code_types.append(allocator, try allocator.dupe(u8, "X"));

    try compare(allocator, &result);

    try std.testing.expect(result.is_synced);
    try std.testing.expectEqual(@as(usize, 1), result.matched.items.len);
    try std.testing.expectEqual(@as(usize, 0), result.missing_in_code.items.len);
}

test "contains — basic" {
    const items = [_][]const u8{ "a", "b", "c" };
    try std.testing.expect(contains(&items, "b"));
    try std.testing.expect(!contains(&items, "d"));
}

test "findCodePath — mu_error_protocol" {
    const allocator = std.testing.allocator;
    const path = try findCodePath(allocator, "specs/tri/mu_error_protocol.tri");
    try std.testing.expect(path != null);
    if (path) |p| {
        defer allocator.free(p);
        try std.testing.expect(std.mem.endsWith(u8, p, "mu_error_protocol.zig"));
    }
}
