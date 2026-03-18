// env_loader.zig — Load .env into process environment at startup
// Silently skips if .env not found. Process env always wins over .env values.

const std = @import("std");

const c = struct {
    extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
};

/// Parse a single .env line into key and value, or null if comment/blank/invalid.
pub fn parseLine(line: []const u8) ?struct { key: []const u8, value: []const u8 } {
    // Skip leading whitespace
    var s = std.mem.trimLeft(u8, line, " \t");

    // Skip empty lines and comments
    if (s.len == 0 or s[0] == '#') return null;

    // Skip optional "export " prefix
    if (std.mem.startsWith(u8, s, "export ")) {
        s = s["export ".len..];
        s = std.mem.trimLeft(u8, s, " \t");
    }

    // Find '='
    const eq = std.mem.indexOfScalar(u8, s, '=') orelse return null;
    const key = std.mem.trimRight(u8, s[0..eq], " \t");
    if (key.len == 0) return null;

    var value = std.mem.trimLeft(u8, s[eq + 1 ..], " \t");
    value = std.mem.trimRight(u8, value, " \t\r");

    // Strip matching quotes
    if (value.len >= 2) {
        const first = value[0];
        const last = value[value.len - 1];
        if ((first == '"' and last == '"') or (first == '\'' and last == '\'')) {
            value = value[1 .. value.len - 1];
        }
    }

    return .{ .key = key, .value = value };
}

/// Load .env from CWD into process environment. Process env takes precedence.
/// Silently returns if .env is missing or unreadable.
pub fn loadDotEnv(allocator: std.mem.Allocator) void {
    const file = std.fs.cwd().openFile(".env", .{}) catch return;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 32 * 1024) catch return;
    // intentionally leaked — process-lifetime data

    var iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        const parsed = parseLine(line) orelse continue;

        // Skip if already set in process environment
        if (std.posix.getenv(parsed.key) != null) continue;

        // dupeZ for null-terminated strings — intentionally leaked
        const key_z = allocator.dupeZ(u8, parsed.key) catch continue;
        const val_z = allocator.dupeZ(u8, parsed.value) catch continue;

        _ = c.setenv(key_z.ptr, val_z.ptr, 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseLine: basic KEY=VALUE" {
    const r = parseLine("FOO=bar").?;
    try std.testing.expectEqualStrings("FOO", r.key);
    try std.testing.expectEqualStrings("bar", r.value);
}

test "parseLine: quoted value" {
    const r = parseLine("KEY=\"hello world\"").?;
    try std.testing.expectEqualStrings("KEY", r.key);
    try std.testing.expectEqualStrings("hello world", r.value);
}

test "parseLine: single quoted" {
    const r = parseLine("K='val'").?;
    try std.testing.expectEqualStrings("val", r.value);
}

test "parseLine: skip comment" {
    try std.testing.expect(parseLine("# this is a comment") == null);
}

test "parseLine: skip blank" {
    try std.testing.expect(parseLine("") == null);
    try std.testing.expect(parseLine("   ") == null);
}

test "parseLine: export prefix" {
    const r = parseLine("export MY_VAR=123").?;
    try std.testing.expectEqualStrings("MY_VAR", r.key);
    try std.testing.expectEqualStrings("123", r.value);
}

test "parseLine: no equals sign" {
    try std.testing.expect(parseLine("NOEQUALS") == null);
}

test "parseLine: empty value" {
    const r = parseLine("EMPTY=").?;
    try std.testing.expectEqualStrings("EMPTY", r.key);
    try std.testing.expectEqualStrings("", r.value);
}

test "parseLine: spaces around equals" {
    const r = parseLine("KEY = value").?;
    try std.testing.expectEqualStrings("KEY", r.key);
    try std.testing.expectEqualStrings("value", r.value);
}

test "parseLine: carriage return trimmed" {
    const r = parseLine("KEY=value\r").?;
    try std.testing.expectEqualStrings("value", r.value);
}
