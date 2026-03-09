// ═══════════════════════════════════════════════════════════════════════════════
// BSD VERIFICATION PIPELINE - Test on LMFDB data
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub fn runVerifyLMFDBCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║   BSD VERIFICATION PIPELINE - LMFDB Data Test          ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    if (args.len < 1) {
        std.debug.print("USAGE:\n", .{});
        std.debug.print("  tri bsd verify <json_file>   Verify BSD formula for curves in JSON\n", .{});
        std.debug.print("  tri bsd verify --test        Use built-in test data (bsd_test_curves.json)\n\n", .{});
        return;
    }

    const arg = args[0];
    const json_path = if (std.mem.eql(u8, arg, "--test"))
        "bsd_test_curves.json"
    else
        arg;

    std.debug.print("{s}Loading curves from: {s}{s}\n", .{ CYAN, json_path, RESET });

    const db = try @import("lmfdb_parser.zig").LMFDBDatabase.fromJson(allocator, json_path);
    defer db.deinit();

    std.debug.print("{s}Loaded {d} curves{s}\n\n", .{ GREEN, db.curves.len, RESET });

    // Run verification for rank 0 curves
    var verified: usize = 0;
    var failed: usize = 0;

    std.debug.print("{s}═════════════════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s} BSD VERIFICATION RESULTS (Rank 0){s}\n", .{ GOLD, RESET });
    std.debug.print("{s}═════════════════════════════════════════════════════════{s}\n\n", .{ GOLD, RESET });

    std.debug.print("{s}{s:<20} {s:>12} {s:>12} {s:>12} {s:>12}{s}\n", .{ CYAN, "Curve", "L(E,1)", "Sha(calc)", "Sha(data)", "Status", RESET });
    std.debug.print("{s}{s: <20} {s: <12} {s: <12} {s: <12} {s: <12}{s}\n", .{ CYAN, "--------------------", "------------", "------------", "------------", "------------", RESET });

    for (db.curves) |curve| {
        if (curve.rank != 0) continue;

        // Compute Sha from BSD formula: Ш = L(E,1) * (torsion^2) / (Omega * c_p)
        const torsion_sq = @as(f64, @floatFromInt(curve.torsion_order * curve.torsion_order));
        const tamagawa = @as(f64, @floatFromInt(curve.tamagawa_product));

        // special_value = L(E,1)/Omega, so L = special_value * Omega
        // Then: Sha = L * torsion^2 / (Omega * c_p) = special_value * torsion^2 / c_p
        const sha_from_formula = curve.special_value * torsion_sq / tamagawa;

        // Check if it matches the known Sha
        const diff = @abs(sha_from_formula - @as(f64, @floatFromInt(curve.sha_order)));
        const status = if (diff < 0.5) "✅ OK" else "❌ FAIL";

        if (diff < 0.5) verified += 1 else failed += 1;

        std.debug.print("{s}{s:<20} {d:>12.6} {d:>12.2} {d:>12.0} {s}{s}\n", .{
            CYAN, curve.lmfdb_label, sha_from_formula, sha_from_formula, @as(f64, @floatFromInt(curve.sha_order)), status, RESET,
        });
    }

    std.debug.print("\n{s}═════════════════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s} SUMMARY:{s}\n", .{ GOLD, RESET });
    std.debug.print("  Verified: {d}/{d}\n", .{ verified, verified + failed });
    std.debug.print("  Failed: {d}/{d}\n", .{ failed, verified + failed });

    if (failed == 0) {
        std.debug.print("\n{s}✅ ALL CURVES PASSED BSD VERIFICATION!{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}⚠️  SOME CURVES FAILED - CHECK IMPLEMENTATION{s}\n", .{ RED, RESET });
    }

    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}
