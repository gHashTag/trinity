// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN SNAPSHOT TESTS for JSON Output (P0.2-E)
// ═══════════════════════════════════════════════════════════════════════════════
// Validates that JSON output remains stable across commits
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

test "golden snapshot: tri constants --json" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "constants"});
    defer allocator.free(result);

    const expected = @embedFile("snapshots/constants.json");
    const normalized_expected = try normalizeTimestamps(allocator, expected);
    defer allocator.free(normalized_expected);

    const normalized_result = try normalizeTimestamps(allocator, result);
    defer allocator.free(normalized_result);

    try std.testing.expectEqualStrings(normalized_expected, normalized_result);
}

test "golden snapshot: tri phi 0 --json" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "phi", "0"});
    defer allocator.free(result);

    const expected = @embedFile("snapshots/phi_0.json");
    const normalized_expected = try normalizeTimestamps(allocator, expected);
    defer allocator.free(normalized_expected);

    const normalized_result = try normalizeTimestamps(allocator, result);
    defer allocator.free(normalized_result);

    try std.testing.expectEqualStrings(normalized_expected, normalized_result);
}

test "golden snapshot: tri phi 5 --json" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "phi", "5"});
    defer allocator.free(result);

    const expected = @embedFile("snapshots/phi_5.json");
    const normalized_expected = try normalizeTimestamps(allocator, expected);
    defer allocator.free(normalized_expected);

    const normalized_result = try normalizeTimestamps(allocator, result);
    defer allocator.free(normalized_result);

    try std.testing.expectEqualStrings(normalized_expected, normalized_result);
}

// Note: bench test is skipped because benchmarks are non-deterministic
// The benchmark results (ops_per_sec, avg_time_ns, total_duration_ms) vary between runs

test "golden snapshot: tri test (no args) --json" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "test"});
    defer allocator.free(result);

    const expected = @embedFile("snapshots/test_no_args.json");
    const normalized_expected = try normalizeTimestamps(allocator, expected);
    defer allocator.free(normalized_expected);

    const normalized_result = try normalizeTimestamps(allocator, result);
    defer allocator.free(normalized_result);

    try std.testing.expectEqualStrings(normalized_expected, normalized_result);
}

test "golden snapshot: tri forge --json" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "forge"});
    defer allocator.free(result);

    const expected = @embedFile("snapshots/forge.json");
    const normalized_expected = try normalizeTimestamps(allocator, expected);
    defer allocator.free(normalized_expected);

    const normalized_result = try normalizeTimestamps(allocator, result);
    defer allocator.free(normalized_result);

    try std.testing.expectEqualStrings(normalized_expected, normalized_result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEGATIVE-PATH TESTS (P0.2-F) - Validate error handling and edge cases
// ═══════════════════════════════════════════════════════════════════════════════

test "negative: phi with invalid arg returns validation error JSON" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "phi", "invalid"});
    defer allocator.free(result);

    // Should contain error information
    try std.testing.expect(std.mem.indexOf(u8, result, "\"status\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"failure\"") != null);
}

test "negative: phi with missing arg returns validation error JSON" {
    const allocator = std.testing.allocator;
    const result = try runTriCommand(allocator, &.{"--json", "phi"});
    defer allocator.free(result);

    // Should contain error information
    try std.testing.expect(std.mem.indexOf(u8, result, "\"status\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"failure\"") != null);
}

// ── Helper: Normalize timestamps for comparison ──
// Replace "started_at":1234567890 and "finished_at":1234567890 with placeholder values

fn normalizeTimestamps(allocator: std.mem.Allocator, json: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, json.len);
    defer result.deinit(allocator);

    var i: usize = 0;
    while (i < json.len) : (i += 1) {
        // Look for "started_at" followed by ":"
        // "\"started_at\"" is 12 characters: " + started_at + "
        if (i + 13 <= json.len and
            std.mem.eql(u8, json[i..i+12], "\"started_at\"") and
            json[i+12] == ':')
        {
            // Copy the normalized key and value
            try result.appendSlice(allocator, "\"started_at\":0");
            // Skip past "started_at": and the number in input
            i += 13; // skip "started_at":
            while (i < json.len and json[i] >= '0' and json[i] <= '9') : (i += 1) {}
            i -= 1; // compensate for loop increment
        }
        // Look for "finished_at" followed by ":"
        // "\"finished_at\"" is 13 characters: " + finished_at + "
        else if (i + 14 <= json.len and
            std.mem.eql(u8, json[i..i+13], "\"finished_at\"") and
            json[i+13] == ':')
        {
            // Copy the normalized key and value
            try result.appendSlice(allocator, "\"finished_at\":0");
            // Skip past "finished_at": and the number in input
            i += 14; // skip "finished_at":
            while (i < json.len and json[i] >= '0' and json[i] <= '9') : (i += 1) {}
            i -= 1; // compensate for loop increment
        }
        else {
            try result.append(allocator, json[i]);
        }
    }

    return result.toOwnedSlice(allocator);
}

// ── Helper: Run TRI command and capture stdout ──
// Note: tri is only available as a run step via zig build tri -- <args>

fn runTriCommand(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    // Run via zig build tri -- <args>
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 3);
    defer argv.deinit(allocator);
    try argv.append(allocator, "zig");
    try argv.append(allocator, "build");
    try argv.append(allocator, "tri");
    try argv.append(allocator, "--");
    for (args) |arg| {
        try argv.append(allocator, arg);
    }

    var child = std.process.Child.init(argv.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore; // Ignore stderr for golden snapshots
    child.stdin_behavior = .Close;

    try child.spawn();

    // Zig 0.15: Manual read loop since Reader API changed
    var output = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer output.deinit(allocator);

    var read_buffer: [4096]u8 = undefined;
    const stdout_file = child.stdout.?;

    while (true) {
        const bytes_read = try stdout_file.read(&read_buffer);
        if (bytes_read == 0) break;
        try output.appendSlice(allocator, read_buffer[0..bytes_read]);
    }

    _ = try child.wait();
    return output.toOwnedSlice(allocator);
}
