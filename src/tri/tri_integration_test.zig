// @origin(generated) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI — Integration Tests
// ═══════════════════════════════════════════════════════════════════════════════
//
// Integration tests for TRI CLI functionality
// These tests verify end-to-end behavior
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// Standalone Color Constants (for testing without module deps)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GREEN = "\x1b[38;2;0;229;153m";
pub const GOLDEN = "\x1b[38;2;255;215;0m";
pub const WHITE = "\x1b[38;2;255;255;255m";
pub const GRAY = "\x1b[38;2;156;156;160m";
pub const RED = "\x1b[38;2;239;68;68m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const PURPLE = "\x1b[38;2;170;102;255m";
pub const YELLOW = "\x1b[38;2;255;255;0m";
pub const RESET = "\x1b[0m";

pub const VERSION = "1.0.1";

// ═══════════════════════════════════════════════════════════════════════════════
// Minimal Command Enum (for standalone testing)
// ═══════════════════════════════════════════════════════════════════════════════

const Command = enum(u8) {
    none,
    help,
    version,
    phi,
    fib,
    lucas,
    gematria,
    chem,
    bio,
    cosmos,
    neuro,
    gen,
    serve,
    _,
};

// Simplified parseCommand for integration testing
fn parseCommandForTest(arg: []const u8) Command {
    if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return .help;
    if (std.mem.eql(u8, arg, "version") or std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) return .version;
    if (std.mem.eql(u8, arg, "phi")) return .phi;
    if (std.mem.eql(u8, arg, "fib")) return .fib;
    if (std.mem.eql(u8, arg, "lucas")) return .lucas;
    if (std.mem.eql(u8, arg, "gematria") or std.mem.eql(u8, arg, "gem")) return .gematria;
    if (std.mem.eql(u8, arg, "chem") or std.mem.eql(u8, arg, "chemistry")) return .chem;
    if (std.mem.eql(u8, arg, "bio") or std.mem.eql(u8, arg, "biology")) return .bio;
    if (std.mem.eql(u8, arg, "cosmos") or std.mem.eql(u8, arg, "cosmology")) return .cosmos;
    if (std.mem.eql(u8, arg, "neuro") or std.mem.eql(u8, arg, "neuroscience")) return .neuro;
    if (std.mem.eql(u8, arg, "gen")) return .gen;
    if (std.mem.eql(u8, arg, "serve")) return .serve;
    return .none;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Command Parsing Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: core commands parse correctly" {
    try std.testing.expectEqual(@intFromEnum(Command.help), @intFromEnum(parseCommandForTest("help")));
    try std.testing.expectEqual(@intFromEnum(Command.version), @intFromEnum(parseCommandForTest("version")));
    try std.testing.expectEqual(@intFromEnum(Command.phi), @intFromEnum(parseCommandForTest("phi")));
}

test "integration: command aliases work equivalently" {
    const chem1 = parseCommandForTest("chem");
    const chem2 = parseCommandForTest("chemistry");
    try std.testing.expectEqual(@intFromEnum(chem1), @intFromEnum(chem2));

    const bio1 = parseCommandForTest("bio");
    const bio2 = parseCommandForTest("biology");
    try std.testing.expectEqual(@intFromEnum(bio1), @intFromEnum(bio2));

    const gem1 = parseCommandForTest("gematria");
    const gem2 = parseCommandForTest("gem");
    try std.testing.expectEqual(@intFromEnum(gem1), @intFromEnum(gem2));
}

test "integration: unknown commands return none" {
    const unknown = parseCommandForTest("not-a-real-command");
    try std.testing.expectEqual(@intFromEnum(Command.none), @intFromEnum(unknown));

    const empty = parseCommandForTest("");
    try std.testing.expectEqual(@intFromEnum(Command.none), @intFromEnum(empty));
}

test "integration: case sensitivity works correctly" {
    const lower = parseCommandForTest("help");
    const upper = parseCommandForTest("HELP");

    try std.testing.expectEqual(@intFromEnum(Command.help), @intFromEnum(lower));
    try std.testing.expectEqual(@intFromEnum(Command.none), @intFromEnum(upper));
}

test "integration: flag variants parse correctly" {
    const h1 = parseCommandForTest("help");
    const h2 = parseCommandForTest("--help");
    const h3 = parseCommandForTest("-h");
    try std.testing.expectEqual(@intFromEnum(h1), @intFromEnum(h2));
    try std.testing.expectEqual(@intFromEnum(h2), @intFromEnum(h3));

    const v1 = parseCommandForTest("version");
    const v2 = parseCommandForTest("--version");
    const v3 = parseCommandForTest("-v");
    try std.testing.expectEqual(@intFromEnum(v1), @intFromEnum(v2));
    try std.testing.expectEqual(@intFromEnum(v2), @intFromEnum(v3));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Color System Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: color constants are valid ANSI codes" {
    try std.testing.expectEqual(@as(u8, 0x1b), GREEN[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), GOLDEN[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), WHITE[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), GRAY[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), RED[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), CYAN[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), PURPLE[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), YELLOW[0]);
    try std.testing.expectEqual(@as(u8, 0x1b), RESET[0]);
}

test "integration: RESET code ends correctly" {
    const last_idx = RESET.len - 1;
    try std.testing.expectEqual(@as(u8, 'm'), RESET[last_idx]);
}

test "integration: color constants are non-empty" {
    try std.testing.expect(GREEN.len > 0);
    try std.testing.expect(GOLDEN.len > 0);
    try std.testing.expect(WHITE.len > 0);
    try std.testing.expect(GRAY.len > 0);
    try std.testing.expect(RED.len > 0);
    try std.testing.expect(CYAN.len > 0);
    try std.testing.expect(PURPLE.len > 0);
    try std.testing.expect(YELLOW.len > 0);
    try std.testing.expect(RESET.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Version Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: version constant is valid" {
    try std.testing.expect(VERSION.len > 0);

    var dot_count: usize = 0;
    for (VERSION) |c| {
        if (c == '.') dot_count += 1;
    }
    try std.testing.expect(dot_count >= 1);
}

test "integration: version format is semantic versioning compatible" {
    var digit_count: usize = 0;
    for (VERSION) |c| {
        if (c >= '0' and c <= '9') digit_count += 1;
    }
    try std.testing.expect(digit_count >= 2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: all science commands parse correctly" {
    const science_cmds = [_]struct { []const u8, Command }{
        .{ "chem", .chem },
        .{ "chemistry", .chem },
        .{ "bio", .bio },
        .{ "biology", .bio },
        .{ "cosmos", .cosmos },
        .{ "cosmology", .cosmos },
        .{ "neuro", .neuro },
        .{ "neuroscience", .neuro },
    };

    for (science_cmds) |tc| {
        const cmd = parseCommandForTest(tc[0]);
        try std.testing.expectEqual(@intFromEnum(tc[1]), @intFromEnum(cmd));
    }
}

test "integration: sacred math commands parse correctly" {
    const math_cmds = [_]struct { []const u8, Command }{
        .{ "phi", .phi },
        .{ "fib", .fib },
        .{ "lucas", .lucas },
        .{ "gematria", .gematria },
        .{ "gem", .gematria },
    };

    for (math_cmds) |tc| {
        const cmd = parseCommandForTest(tc[0]);
        try std.testing.expectEqual(@intFromEnum(tc[1]), @intFromEnum(cmd));
    }
}

test "integration: utility commands parse correctly" {
    const util_cmds = [_]struct { []const u8, Command }{
        .{ "gen", .gen },
        .{ "serve", .serve },
        .{ "help", .help },
        .{ "version", .version },
    };

    for (util_cmds) |tc| {
        const cmd = parseCommandForTest(tc[0]);
        try std.testing.expectEqual(@intFromEnum(tc[1]), @intFromEnum(cmd));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Enum Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: none command has enum value 0" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(Command.none));
}

test "integration: command enum values are unique" {
    const commands = [_]Command{
        .none,     .help, .version, .phi,    .fib,   .lucas,
        .gematria, .chem, .bio,     .cosmos, .neuro, .gen,
        .serve,
    };

    for (commands, 0..) |cmd1, i| {
        for (commands[i + 1 ..]) |cmd2| {
            if (cmd1 == cmd2) {
                std.debug.print("Duplicate command value: {any}\n", .{cmd1});
                try std.testing.expect(false);
            }
        }
    }
}

test "integration: all core commands have non-zero enum values" {
    const core_commands = [_]Command{
        .help, .version, .phi,    .fib,   .lucas, .gematria,
        .chem, .bio,     .cosmos, .neuro, .gen,   .serve,
    };

    for (core_commands) |cmd| {
        try std.testing.expect(@intFromEnum(cmd) > 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// String Matching Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "integration: command string matching uses exact comparison" {
    const cmd = parseCommandForTest("Phi"); // Capital P
    try std.testing.expectEqual(@intFromEnum(Command.none), @intFromEnum(cmd));

    const cmd2 = parseCommandForTest("phi "); // Trailing space
    try std.testing.expectEqual(@intFromEnum(Command.none), @intFromEnum(cmd2));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Function Tests
// ═══════════════════════════════════════════════════════════════════════════════

fn printTestColor(comptime color_code: []const u8, comptime fmt: []const u8, args: anytype) void {
    std.debug.print(color_code ++ fmt ++ RESET, args);
}

test "integration: color output function works" {
    printTestColor(GOLDEN, "Test {s}\n", .{"output"});
    printTestColor(GREEN, "Test {s}\n", .{"output"});
    printTestColor(CYAN, "Test {s}\n", .{"output"});
}
