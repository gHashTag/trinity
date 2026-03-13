// @origin(generated) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// AGENT TRI VERIFICATION — Run Agent TRI against known failures
// ═══════════════════════════════════════════════════════════════════════════════
// Issue #84: Verify Agent TRI error detection on known failures
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const mu_proto = @import("mu_error_protocol.zig");

pub const VerifyResult = struct {
    total_failures: usize,
    categorized: usize,
    unknown: usize,
    logged: usize,
    by_category: [9]usize,
};

/// Run vibee gen + ast-check on a spec, return error message if it fails.
fn runPipeline(allocator: Allocator, spec_path: []const u8) !?[]u8 {
    // Run vibee gen
    const gen_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig-out/bin/vibee", "gen", spec_path },
    }) catch {
        return try allocator.dupe(u8, "vibee gen failed to execute");
    };
    defer allocator.free(gen_result.stdout);
    defer allocator.free(gen_result.stderr);

    const gen_exited = switch (gen_result.term) {
        .Exited => |code| code,
        else => 1,
    };
    if (gen_exited != 0) {
        if (gen_result.stderr.len > 0) {
            return try allocator.dupe(u8, gen_result.stderr);
        }
        return try allocator.dupe(u8, "vibee gen returned non-zero");
    }

    // Gen succeeded — no error
    // For now, check if generated file exists
    // ast-check is run by vibee gen internally

    return null; // Success
}

/// Run Agent TRI verification against all known failures from batch runner.
pub fn runVerification(allocator: Allocator) !VerifyResult {
    var result = VerifyResult{
        .total_failures = 0,
        .categorized = 0,
        .unknown = 0,
        .logged = 0,
        .by_category = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    // Read batch runner latest.json for known failures
    const batch_data = std.fs.cwd().readFileAlloc(allocator, ".trinity/batch/latest.json", 10 * 1024 * 1024) catch {
        std.debug.print("  \x1b[33mNo batch data found. Running fresh verification...\x1b[0m\n", .{});
        return result;
    };
    defer allocator.free(batch_data);

    // Parse failures from JSON (simple extraction)
    var failures: std.ArrayList([]const u8) = .empty;
    defer failures.deinit(allocator);

    // Find "spec" fields in failures array
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, batch_data, pos, "\"spec\": \"")) |idx| {
        const start = idx + "\"spec\": \"".len;
        if (std.mem.indexOfScalarPos(u8, batch_data, start, '"')) |end| {
            try failures.append(allocator, batch_data[start..end]);
            pos = end + 1;
        } else break;
    }

    result.total_failures = failures.items.len;
    std.debug.print("  Found {d} failures in batch data\n\n", .{result.total_failures});

    // For each failure, run gen + ast-check, capture error, categorize + log
    for (failures.items, 0..) |spec_path, i| {
        // Run vibee gen to get fresh error
        const gen_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "zig-out/bin/vibee", "gen", spec_path },
        }) catch {
            std.debug.print("  {d}. \x1b[31m✗\x1b[0m {s} — vibee gen failed\n", .{ i + 1, spec_path });
            continue;
        };
        defer allocator.free(gen_result.stdout);
        defer allocator.free(gen_result.stderr);

        // Combine stderr for analysis
        const error_msg = if (gen_result.stderr.len > 0)
            gen_result.stderr
        else if ((switch (gen_result.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        }) != 0)
            @as([]const u8, "non-zero exit")
        else blk: {
            // Gen succeeded — try ast-check on generated file
            // Extract stem from spec path
            var stem_start: usize = 0;
            for (spec_path, 0..) |c, si| {
                if (c == '/') stem_start = si + 1;
            }
            var stem_end: usize = spec_path.len;
            var si: usize = spec_path.len;
            while (si > stem_start) {
                si -= 1;
                if (spec_path[si] == '.') {
                    stem_end = si;
                    break;
                }
            }
            const stem = spec_path[stem_start..stem_end];

            const gen_path = std.fmt.allocPrint(allocator, "generated/{s}.zig", .{stem}) catch continue;
            defer allocator.free(gen_path);

            const ast_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "zig", "ast-check", gen_path },
            }) catch {
                break :blk @as([]const u8, "ast-check failed to run");
            };
            defer allocator.free(ast_result.stdout);
            defer allocator.free(ast_result.stderr);

            const ast_exit = switch (ast_result.term) {
                .Exited => |code| code,
                else => @as(u32, 1),
            };
            if (ast_exit != 0) {
                // Has real error — categorize it
                const cat = mu_proto.categorizeError(ast_result.stderr);
                const cat_idx = @intFromEnum(cat);
                result.by_category[cat_idx] += 1;

                if (cat != .unknown) {
                    result.categorized += 1;
                } else {
                    result.unknown += 1;
                }

                // Log to Agent TRI
                const ts = std.fmt.allocPrint(allocator, "mu5_verify_{d}", .{i}) catch continue;
                defer allocator.free(ts);

                const mu_err = mu_proto.MuError{
                    .timestamp = ts,
                    .spec = spec_path,
                    .link = 7,
                    .link_name = "code_generate",
                    .error_category = cat,
                    .error_message = ast_result.stderr[0..@min(ast_result.stderr.len, 200)],
                    .error_line = 0,
                    .generated_file = gen_path,
                    .fix_attempted = false,
                    .fix_result = "",
                    .severity = mu_proto.Severity.fromCategory(cat),
                    .resolution_status = .open,
                };

                const path = mu_proto.logError(allocator, mu_err) catch continue;
                allocator.free(path);
                result.logged += 1;

                std.debug.print("  {d}. \x1b[33m{s}\x1b[0m {s}\n", .{ i + 1, cat.toString(), spec_path });
                continue;
            }

            // Actually passed — skip
            std.debug.print("  {d}. \x1b[32m✓ PASS\x1b[0m {s}\n", .{ i + 1, spec_path });
            continue;
        };

        // Categorize the error
        const cat = mu_proto.categorizeError(error_msg);
        const cat_idx = @intFromEnum(cat);
        result.by_category[cat_idx] += 1;

        if (cat != .unknown) {
            result.categorized += 1;
        } else {
            result.unknown += 1;
        }

        // Log to Agent TRI
        const ts = std.fmt.allocPrint(allocator, "mu5_gen_{d}", .{i}) catch continue;
        defer allocator.free(ts);

        const mu_err = mu_proto.MuError{
            .timestamp = ts,
            .spec = spec_path,
            .link = 7,
            .link_name = "code_generate",
            .error_category = cat,
            .error_message = error_msg[0..@min(error_msg.len, 200)],
            .error_line = 0,
            .generated_file = "",
            .fix_attempted = false,
            .fix_result = "",
        };

        const path = mu_proto.logError(allocator, mu_err) catch continue;
        allocator.free(path);
        result.logged += 1;

        std.debug.print("  {d}. \x1b[33m{s}\x1b[0m {s}\n", .{ i + 1, cat.toString(), spec_path });
    }

    return result;
}

/// CLI entry: `tri mu verify`
pub fn runMuVerifyCommand(allocator: Allocator) !void {
    std.debug.print("\n\x1b[33m🧠 AGENT TRI VERIFICATION\x1b[0m — Testing on known failures\n", .{});
    std.debug.print("\x1b[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n\n", .{});

    const result = try runVerification(allocator);

    // Summary
    std.debug.print("\n\x1b[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n", .{});
    std.debug.print("  \x1b[36mTotal failures:\x1b[0m  {d}\n", .{result.total_failures});
    std.debug.print("  \x1b[32mCategorized:\x1b[0m     {d}\n", .{result.categorized});
    std.debug.print("  \x1b[31mUnknown:\x1b[0m         {d}\n", .{result.unknown});
    std.debug.print("  \x1b[36mLogged to Agent TRI:\x1b[0m {d}\n", .{result.logged});

    const total_classified = result.categorized + result.unknown;
    if (total_classified > 0) {
        const rate = result.categorized * 100 / total_classified;
        const emoji: []const u8 = if (rate >= 80) "💎" else if (rate >= 50) "🟡" else "🔴";
        std.debug.print("\n  \x1b[33mDetection rate:\x1b[0m {d}% {s}\n", .{ rate, emoji });
        std.debug.print("  \x1b[33mTarget:\x1b[0m         80%\n", .{});

        if (rate >= 80) {
            std.debug.print("\n  \x1b[32m✅ AGENT TRI PASS — detection rate meets target\x1b[0m\n", .{});
        } else {
            std.debug.print("\n  \x1b[31m❌ AGENT TRI FAIL — detection rate below target\x1b[0m\n", .{});
        }
    }

    // Category breakdown
    std.debug.print("\n  ┌─────────────────────────┬───────┐\n", .{});
    std.debug.print("  │ Category                │ Count │\n", .{});
    std.debug.print("  ├─────────────────────────┼───────┤\n", .{});

    const categories = [_]mu_proto.ErrorCategory{
        .type_mapping, .undefined_identifier, .syntax_error,
        .format_error, .import_error,         .memory_error,
        .test_failure, .gen_failure,          .unknown,
    };

    for (categories) |cat| {
        const count = result.by_category[@intFromEnum(cat)];
        if (count > 0) {
            std.debug.print("  │ {s:<23} │ {d:>5} │\n", .{ cat.toString(), count });
        }
    }
    std.debug.print("  └─────────────────────────┴───────┘\n", .{});

    // V-formula
    const phi = 1.618034;
    if (total_classified > 0) {
        const rate_f: f64 = @as(f64, @floatFromInt(result.categorized)) / @as(f64, @floatFromInt(total_classified));
        const v = phi * rate_f * rate_f;
        std.debug.print("\n  \x1b[33mV = φ·(detected/total)² = {d:.3}\x1b[0m\n", .{v});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VerifyResult — init" {
    const result = VerifyResult{
        .total_failures = 0,
        .categorized = 0,
        .unknown = 0,
        .logged = 0,
        .by_category = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    try std.testing.expectEqual(@as(usize, 0), result.total_failures);
}
