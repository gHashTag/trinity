const std = @import("std");

// ============================================================================
// TRINITY: Sacred Assertions for Testing (Cycle 100)
// Domain-specific assertions for sacred mathematics and Trinity concepts
// ============================================================================

/// Assert that output contains the Trinity Identity: φ² + 1/φ² = 3
pub fn expectTrinityIdentity(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    // Check for various representations
    const patterns = [_][]const u8{
        "φ² + 1/φ² = 3",
        "phi^2 + 1/phi^2 = 3",
        "φ2 + 1/φ2 = 3",
        "Trinity Identity",
    };

    for (patterns) |pattern| {
        if (std.mem.indexOf(u8, clean_output, pattern) != null) {
            return;
        }
    }

    std.debug.print("\n❌ Expected Trinity Identity (φ² + 1/φ² = 3)\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingTrinityIdentity;
}

/// Assert that output contains sacred score with minimum value
/// Format: "Sacred Score: X / Y" or "Score: X/Y"
pub fn expectSacredScore(output: []const u8, min_score: f64) !void {
    const clean_output = stripAnsiCodes(output);

    // Look for score patterns
    const score_patterns = [_][]const u8{
        "Sacred Score:",
        "Score:",
        "sacred score:",
    };

    for (score_patterns) |pattern| {
        const idx = std.mem.indexOf(u8, clean_output, pattern) orelse continue;
        const score_part = clean_output[idx + pattern.len ..];

        // Parse "X / Y" or "X/Y"
        var it = std.mem.tokenizeAny(u8, score_part, " /");
        const score_str = it.next() orelse continue;

        const score = std.fmt.parseFloat(f64, score_str) catch continue;

        if (score >= min_score) {
            return;
        }

        std.debug.print("\n❌ Expected sacred score >= {d:.2}, got {d:.2}\n", .{ min_score, score });
        std.debug.print("   In output:\n{s}\n\n", .{output});
        return error.SacredScoreTooLow;
    }

    std.debug.print("\n❌ Expected sacred score (Sacred Score: X / Y)\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingSacredScore;
}

/// Assert that output contains gematria values
/// Format: "Gematria: N" or "g: N"
pub fn expectGematria(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const gematria_patterns = [_][]const u8{
        "Gematria:",
        "gematria:",
        "g:",
        "GEMATRIA",
    };

    for (gematria_patterns) |pattern| {
        if (std.mem.indexOf(u8, clean_output, pattern) != null) {
            return;
        }
    }

    std.debug.print("\n❌ Expected gematria value\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingGematria;
}

/// Assert that output contains phi (φ) value
pub fn expectPhiPresent(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const phi_patterns = [_][]const u8{
        "φ",
        "phi",
        "Phi",
        "1.618",
        "1.618033",
        "golden ratio",
    };

    for (phi_patterns) |pattern| {
        if (std.mem.indexOf(u8, clean_output, pattern) != null) {
            return;
        }
    }

    std.debug.print("\n❌ Expected phi (φ) in output\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingPhi;
}

/// Assert that output contains Fibonacci sequence or reference
pub fn expectFibonacci(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const fib_patterns = [_][]const u8{
        "Fibonacci:",
        "fibonacci:",
        "Fib:",
        "FIBONACCI",
    };

    for (fib_patterns) |pattern| {
        if (std.mem.indexOf(u8, clean_output, pattern) != null) {
            return;
        }
    }

    std.debug.print("\n❌ Expected Fibonacci reference\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingFibonacci;
}

/// Assert that output contains Lucas sequence or reference
pub fn expectLucas(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const lucas_patterns = [_][]const u8{
        "Lucas:",
        "lucas:",
        "LUCAS",
    };

    for (lucas_patterns) |pattern| {
        if (std.mem.indexOf(u8, clean_output, pattern) != null) {
            return;
        }
    }

    std.debug.print("\n❌ Expected Lucas reference\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingLucas;
}

/// Assert that output contains sacred constants (φ, π, e, etc.)
pub fn expectSacredConstants(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const constants = [_][]const u8{
        "φ",
        "π",
        "e",
        "mu",
        "χ",
        "sigma",
        "epsilon",
    };

    var found_count: usize = 0;
    for (constants) |constant| {
        if (std.mem.indexOf(u8, clean_output, constant) != null) {
            found_count += 1;
        }
    }

    if (found_count >= 2) {
        return; // Found at least 2 sacred constants
    }

    std.debug.print("\n❌ Expected sacred constants (found {d}/2+)\n", .{found_count});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.NotEnoughSacredConstants;
}

/// Assert that output mentions "Sacred Intelligence"
pub fn expectSacredIntelligence(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const patterns = [_][]const u8{
        "Sacred Intelligence",
        "sacred intelligence",
        "SACRED INTELLIGENCE",
        "I am Sacred Intelligence",
    };

    for (patterns) |pattern| {
        if (std.mem.indexOf(u8, clean_output, pattern) != null) {
            return;
        }
    }

    std.debug.print("\n❌ Expected 'Sacred Intelligence' in output\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingSacredIntelligence;
}

/// Assert that output contains trit symbols (▲, ▼, ●)
pub fn expectTritSymbols(output: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    const trit_symbols = [_][]const u8{
        "▲", // +1
        "▼", // -1
        "●", // 0
    };

    var found_count: usize = 0;
    for (trit_symbols) |symbol| {
        if (std.mem.indexOf(u8, clean_output, symbol) != null) {
            found_count += 1;
        }
    }

    if (found_count > 0) {
        return;
    }

    std.debug.print("\n❌ Expected trit symbols (▲, ▼, ●)\n", .{});
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.MissingTritSymbols;
}

/// Assert that output contains a specific sacred constant value
pub fn expectConstantValue(output: []const u8, constant: []const u8, expected_value: []const u8) !void {
    const clean_output = stripAnsiCodes(output);

    // Look for "constant: value" pattern
    const pattern = try std.fmt.allocPrint(std.testing.allocator, "{s}:", .{constant});
    defer std.testing.allocator.free(pattern);

    const idx = std.mem.indexOf(u8, clean_output, pattern) orelse {
        std.debug.print("\n❌ Expected constant '{s}'\n", .{constant});
        std.debug.print("   In output:\n{s}\n\n", .{output});
        return error.MissingConstant;
    };

    const value_part = clean_output[idx + pattern.len ..];
    if (std.mem.indexOf(u8, value_part, expected_value) != null) {
        return;
    }

    std.debug.print("\n❌ Expected {s}: {s}\n", .{ constant, expected_value });
    std.debug.print("   In output:\n{s}\n\n", .{output});
    return error.ConstantValueMismatch;
}

/// Strip ANSI escape codes from text (helper)
fn stripAnsiCodes(text: []const u8) []const u8 {
    // Stub implementation - just return the original text
    // Tests should handle ANSI codes in their patterns
    return text;
}

// ============================================================================
// Tests
// ============================================================================

test "expectTrinityIdentity - valid" {
    const output1 = "The Trinity Identity: φ² + 1/φ² = 3";
    try expectTrinityIdentity(output1);

    const output2 = "phi^2 + 1/phi^2 = 3 is sacred";
    try expectTrinityIdentity(output2);
}

test "expectTrinityIdentity - invalid" {
    const output = "Some other text";
    try std.testing.expectError(error.MissingTrinityIdentity, expectTrinityIdentity(output));
}

test "expectPhiPresent - valid" {
    const output1 = "Golden ratio φ = 1.618";
    try expectPhiPresent(output1);

    const output2 = "phi is 1.618033";
    try expectPhiPresent(output2);

    const output3 = "Value is 1.618";
    try expectPhiPresent(output3);
}

test "expectPhiPresent - invalid" {
    const output = "No phi here";
    try std.testing.expectError(error.MissingPhi, expectPhiPresent(output));
}

test "expectSacredIntelligence - valid" {
    const output = "I am Sacred Intelligence, awakened.";
    try expectSacredIntelligence(output);
}

test "expectSacredIntelligence - invalid" {
    const output = "Regular AI system";
    try std.testing.expectError(error.MissingSacredIntelligence, expectSacredIntelligence(output));
}

test "expectTritSymbols - valid" {
    const output1 = "User input ▲ Agent response ▼";
    try expectTritSymbols(output1);

    const output2 = "System state ●";
    try expectTritSymbols(output2);
}

test "expectTritSymbols - invalid" {
    const output = "No trit symbols here";
    try std.testing.expectError(error.MissingTritSymbols, expectTritSymbols(output));
}
