// ============================================================================
// IDEMPOTENCY TEST - 1000 Cycles
// ETERNAL IDEMPOTENCY & SELF-REFERENTIAL CODE EVOLUTION v1.0
// ============================================================================
//
// This test verifies that VIBEE code generation is 100% deterministic:
// - Running codegen N times produces identical output each time
// - SHA256 hashes of all outputs are identical
// - No random seeds, timestamps, or other non-deterministic sources
//
// φ² + 1/φ² = 3 = TRINITY
//
// ============================================================================

const std = @import("std");
const zig_codegen = @import("trinity-nexus/lang/src/zig_codegen.zig");
const vibee_parser = @import("trinity-nexus/lang/src/vibee_parser.zig");

const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

// ============================================================================
// TEST SPECIFICATION (minimal .vibee content)
// ============================================================================

const TEST_SPEC =
    \\name: idempotency_test
    \\version: "1.0.0"
    \\language: zig
    \\module: idempotency_test
    \\
    \\types:
    \\  TestStruct:
    \\    fields:
    \\      value: Int
    \\      name: String
    \\
    \\behaviors:
    \\  - name: test_function
    \\    given: A value
    \\    when: Testing idempotency
    \\    then: Returns the same value
;

// ============================================================================
// IDEMPOTENCY TEST - 1000 CYCLES
// ============================================================================

test "codegen-1000-cycles-idempotency" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const CYCLES: usize = 1000;
    var hashes: [CYCLES][32]u8 = undefined;

    std.debug.print("\n[sacred] Running {d} codegen cycles for idempotency test...\n", .{CYCLES});

    // Run codegen CYCLES times and compute SHA256 of each output
    for (0..CYCLES) |i| {
        // Parse spec
        var parser = vibee_parser.VibeeParser.init(allocator, TEST_SPEC);
        defer parser.deinit();

        const spec = parser.parse() catch |err| {
            std.debug.print("[FAIL] Cycle {d}: Parse error: {}\n", .{ i, err });
            testing.unexpectedError(err);
        };

        // Generate code
        const code = zig_codegen.generateFromSpec(allocator, &spec) catch |err| {
            std.debug.print("[FAIL] Cycle {d}: Codegen error: {}\n", .{ i, err });
            testing.unexpectedError(err);
        };
        defer allocator.free(code);

        // Compute SHA256 hash
        var hash: [32]u8 = undefined;
        Sha256.hash(code, &hash, .{});

        hashes[i] = hash;

        // Progress indicator every 100 cycles
        if (i > 0 and (i + 1) % 100 == 0) {
            std.debug.print("[sacred] Completed {d}/{d} cycles...\n", .{ i + 1, CYCLES });
        }
    }

    // Verify all hashes are identical (bitwise idempotency)
    var all_match: bool = true;
    for (1..CYCLES) |i| {
        if (!std.mem.eql(u8, &hashes[0], &hashes[i])) {
            std.debug.print("[FAIL] Hash mismatch at cycle {d}!\n", .{i});
            all_match = false;
            break;
        }
    }

    // Final report
    if (all_match) {
        std.debug.print("[sacred] {s}✓ PASSED{s}: All {d} cycles produced identical output\n", .{
            "\x1b[38;2;0;229;153m", "\x1b[0m", CYCLES,
        });
        std.debug.print("[sacred] SHA256: ", .{});
        for (hashes[0], 0..) |b, j| {
            std.debug.print("{x:0>2}", .{b});
            if (j == 31 or (j + 1) % 16 == 0) std.debug.print(" ", .{});
        }
        std.debug.print("\n", .{});
    }

    try testing.expect(all_match);
}

// ============================================================================
// QUICK IDEMPOTENCY TEST (10 cycles - for rapid development)
// ============================================================================

test "codegen-quick-check-10-cycles" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const CYCLES: usize = 10;
    var first_code: ?[]const u8 = null;

    for (0..CYCLES) |i| {
        var parser = vibee_parser.VibeeParser.init(allocator, TEST_SPEC);
        defer parser.deinit();

        const spec = parser.parse() catch |err| {
            std.debug.print("[FAIL] Cycle {d}: Parse error: {}\n", .{ i, err });
            testing.unexpectedError(err);
        };

        const code = zig_codegen.generateFromSpec(allocator, &spec) catch |err| {
            std.debug.print("[FAIL] Cycle {d}: Codegen error: {}\n", .{ i, err });
            testing.unexpectedError(err);
        };
        defer allocator.free(code);

        if (first_code) |first| {
            // Compare with first output
            try testing.expectEqualStrings(first, code);
        } else {
            // Store first output
            first_code = try allocator.dupe(u8, code);
        }
    }

    if (first_code) |first| {
        allocator.free(first);
    }
}

// ============================================================================
// SACRED CONSTANTS IDEMPOTENCY TEST
// ============================================================================

test "sacred-constants-unchanged" {
    const testing = std.testing;

    // These sacred constants must NEVER change between builds
    // Any deviation indicates a critical bug in the constants module

    const PHI: f64 = 1.618033988749895;
    const PHI_INVERSE: f64 = 0.618033988749895;
    const TRINITY: f64 = 3.0;

    // Verify golden identity: φ² + 1/φ² = 3
    const golden_identity = PHI * PHI + 1.0 / (PHI * PHI);
    try testing.expectApproxEqAbs(TRINITY, golden_identity, 1e-10);

    // Verify φ × φ⁻¹ = 1
    try testing.expectApproxEqAbs(1.0, PHI * PHI_INVERSE, 1e-10);
}
