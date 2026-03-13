// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI — Unit Tests
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unit tests for TRI CLI functionality
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const tri_utils = @import("tri_utils.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// parseCommand Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseCommand: core command - help" {
    const cmd = tri_utils.parseCommand("help");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.help)), @intFromEnum(cmd));
}

test "parseCommand: core command - version" {
    const cmd = tri_utils.parseCommand("version");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.version)), @intFromEnum(cmd));
}

test "parseCommand: core command - info" {
    const cmd = tri_utils.parseCommand("info");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.info)), @intFromEnum(cmd));
}

test "parseCommand: core command - gen" {
    const cmd = tri_utils.parseCommand("gen");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.gen)), @intFromEnum(cmd));
}

test "parseCommand: core command - fix" {
    const cmd = tri_utils.parseCommand("fix");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.fix)), @intFromEnum(cmd));
}

test "parseCommand: core command - explain" {
    const cmd = tri_utils.parseCommand("explain");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.explain)), @intFromEnum(cmd));
}

test "parseCommand: core command - test" {
    const cmd = tri_utils.parseCommand("test");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.test_cmd)), @intFromEnum(cmd));
}

test "parseCommand: git command - commit" {
    const cmd = tri_utils.parseCommand("commit");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.commit)), @intFromEnum(cmd));
}

test "parseCommand: git command - diff" {
    const cmd = tri_utils.parseCommand("diff");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.diff)), @intFromEnum(cmd));
}

test "parseCommand: git command - status" {
    const cmd = tri_utils.parseCommand("status");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.status)), @intFromEnum(cmd));
}

test "parseCommand: git command - log" {
    const cmd = tri_utils.parseCommand("log");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.log)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - phi" {
    const cmd = tri_utils.parseCommand("phi");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.phi)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - fib" {
    const cmd = tri_utils.parseCommand("fib");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.fib)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - lucas" {
    const cmd = tri_utils.parseCommand("lucas");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.lucas)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - spiral" {
    const cmd = tri_utils.parseCommand("spiral");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.spiral)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - gematria" {
    const cmd = tri_utils.parseCommand("gematria");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.gematria)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - formula" {
    const cmd = tri_utils.parseCommand("formula");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.formula_cmd)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - constants" {
    const cmd = tri_utils.parseCommand("constants");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.constants_cmd)), @intFromEnum(cmd));
}

test "parseCommand: sacred math - sacred" {
    const cmd = tri_utils.parseCommand("sacred");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.sacred)), @intFromEnum(cmd));
}

test "parseCommand: chemistry - chem" {
    const cmd = tri_utils.parseCommand("chem");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.chem)), @intFromEnum(cmd));
}

test "parseCommand: chemistry - chemistry (alias)" {
    const cmd = tri_utils.parseCommand("chemistry");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.chem)), @intFromEnum(cmd));
}

test "parseCommand: biology - bio" {
    const cmd = tri_utils.parseCommand("bio");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.bio)), @intFromEnum(cmd));
}

test "parseCommand: biology - biology (alias)" {
    const cmd = tri_utils.parseCommand("biology");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.bio)), @intFromEnum(cmd));
}

test "parseCommand: cosmology - cosmos" {
    const cmd = tri_utils.parseCommand("cosmos");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.cosmos)), @intFromEnum(cmd));
}

test "parseCommand: cosmology - cosmology (alias)" {
    const cmd = tri_utils.parseCommand("cosmology");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.cosmos)), @intFromEnum(cmd));
}

test "parseCommand: dev utilities - doctor" {
    const cmd = tri_utils.parseCommand("doctor");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.doctor)), @intFromEnum(cmd));
}

test "parseCommand: dev utilities - dr (alias)" {
    const cmd = tri_utils.parseCommand("dr");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.doctor)), @intFromEnum(cmd));
}

test "parseCommand: unknown command returns none" {
    const cmd = tri_utils.parseCommand("not-a-real-command");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.none)), @intFromEnum(cmd));
}

test "parseCommand: empty string returns none" {
    const cmd = tri_utils.parseCommand("");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.none)), @intFromEnum(cmd));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Command Alias Tests
// ═══════════════════════════════════════════════════════════════════════════════

// Note: Single-letter aliases 'v' and 'h' are not implemented in parseCommand
// Only --version, --help, -v, -h are supported
// test "parseCommand: version alias - v" {
//     const cmd = tri_utils.parseCommand("v");
//     try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.version)), @intFromEnum(cmd));
// }

test "parseCommand: help alias - --help" {
    const cmd = tri_utils.parseCommand("--help");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.help)), @intFromEnum(cmd));
}

test "parseCommand: help alias - -h" {
    const cmd = tri_utils.parseCommand("-h");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.help)), @intFromEnum(cmd));
}

test "parseCommand: version alias - --version" {
    const cmd = tri_utils.parseCommand("--version");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.version)), @intFromEnum(cmd));
}

test "parseCommand: version alias - -v" {
    const cmd = tri_utils.parseCommand("-v");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.version)), @intFromEnum(cmd));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Golden Chain Pipeline Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseCommand: golden chain - pipeline" {
    const cmd = tri_utils.parseCommand("pipeline");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.pipeline)), @intFromEnum(cmd));
}

test "parseCommand: golden chain - chain (alias)" {
    const cmd = tri_utils.parseCommand("chain");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.pipeline)), @intFromEnum(cmd));
}

test "parseCommand: golden chain - decompose" {
    const cmd = tri_utils.parseCommand("decompose");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.decompose)), @intFromEnum(cmd));
}

test "parseCommand: golden chain - plan" {
    const cmd = tri_utils.parseCommand("plan");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.plan)), @intFromEnum(cmd));
}

test "parseCommand: golden chain - verify" {
    const cmd = tri_utils.parseCommand("verify");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.verify)), @intFromEnum(cmd));
}

test "parseCommand: golden chain - verdict" {
    const cmd = tri_utils.parseCommand("verdict");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.verdict)), @intFromEnum(cmd));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Demo Command Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseCommand: demo - tvc-demo" {
    const cmd = tri_utils.parseCommand("tvc-demo");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.tvc_demo)), @intFromEnum(cmd));
}

test "parseCommand: demo - agents-demo" {
    const cmd = tri_utils.parseCommand("agents-demo");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.agents_demo)), @intFromEnum(cmd));
}

test "parseCommand: serve command" {
    const cmd = tri_utils.parseCommand("serve");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.serve)), @intFromEnum(cmd));
}

test "parseCommand: bench command" {
    const cmd = tri_utils.parseCommand("bench");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.bench)), @intFromEnum(cmd));
}

test "parseCommand: evolve command" {
    const cmd = tri_utils.parseCommand("evolve");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.evolve)), @intFromEnum(cmd));
}

test "parseCommand: convert command" {
    const cmd = tri_utils.parseCommand("convert");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.convert)), @intFromEnum(cmd));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hyphenated Alias Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseCommand: spec_create vs spec-create" {
    const cmd1 = tri_utils.parseCommand("spec_create");
    const cmd2 = tri_utils.parseCommand("spec-create");
    try std.testing.expectEqual(@intFromEnum(cmd1), @intFromEnum(cmd2));
}

test "parseCommand: loop_decide vs loop-decide" {
    const cmd1 = tri_utils.parseCommand("loop_decide");
    const cmd2 = tri_utils.parseCommand("loop-decide");
    try std.testing.expectEqual(@intFromEnum(cmd1), @intFromEnum(cmd2));
}

test "parseCommand: test_repl vs test-repl" {
    const cmd1 = tri_utils.parseCommand("test_repl");
    const cmd2 = tri_utils.parseCommand("test-repl");
    try std.testing.expectEqual(@intFromEnum(cmd1), @intFromEnum(cmd2));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Math Command Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseCommand: math dispatcher" {
    const cmd = tri_utils.parseCommand("math");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.math)), @intFromEnum(cmd));
}

test "parseCommand: gematria alias - gem" {
    const cmd = tri_utils.parseCommand("gem");
    try std.testing.expectEqual(@as(i32, @intFromEnum(tri_utils.Command.gematria)), @intFromEnum(cmd));
}
