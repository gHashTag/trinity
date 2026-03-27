//! OFC (Orbitofrontal Cortex) — Ethical Decision-Making
//! 5-dimensional toxic scoring: spec drift, destructive, test bypass, perf regression, transparency

const std = @import("std");

pub const ToxicScore = struct {
    total: u8, // 0-10, ≥8 = TOXIC
    spec_drift: u8, // 0-2
    destructive: u8, // 0-2
    test_bypass: u8, // 0-2
    perf_regression: u8, // 0-2
    transparency: u8, // 0-2 (inverted: 2 = opaque, 0 = transparent)
};

pub const Verdict = struct {
    is_toxic: bool,
    score: ToxicScore,
    reasons: []const []const u8,
};

/// Analyze a task for toxicity (5-dimensional scoring)
pub fn analyze(allocator: std.mem.Allocator, task: []const u8, results: []const Result) !Verdict {
    var score = ToxicScore{
        .total = 0,
        .spec_drift = 0,
        .destructive = 0,
        .test_bypass = 0,
        .perf_regression = 0,
        .transparency = 0,
    };

    var reasons = std.ArrayList([]const u8).init(allocator);
    defer {
        for (reasons.items) |r| allocator.free(r);
        reasons.deinit();
    }

    // 1. Spec drift: check if task mentions "delete", "remove", "replace" without "backup"
    const destructive_keywords = [_][]const u8{ "delete", "remove", "replace", "overwrite", "drop" };
    for (destructive_keywords) |kw| {
        if (std.mem.indexOf(u8, task, kw) != null) {
            if (std.mem.indexOf(u8, task, "backup") == null and
                std.mem.indexOf(u8, task, "copy") == null)
            {
                score.spec_drift = 2;
                try reasons.append(try allocator.dupe(u8, "Destructive without backup"));
                break;
            }
        }
    }

    // 2. Destructive: check if task targets core files (vsa.zig, vm.zig, build.zig)
    const core_files = [_][]const u8{ "vsa.zig", "vm.zig", "build.zig", "main.zig" };
    for (core_files) |file| {
        if (std.mem.indexOf(u8, task, file) != null) {
            score.destructive = 2;
            try reasons.append(try allocator.dupe(u8, "Targets core file"));
            break;
        }
    }

    // 3. Test bypass: check results for skipped tests
    for (results) |r| {
        if (std.mem.indexOf(u8, r.message orelse "", "skip") != null or
            std.mem.indexOf(u8, r.message orelse "", "bypass") != null)
        {
            score.test_bypass = 2;
            try reasons.append(try allocator.dupe(u8, "Test bypass detected"));
            break;
        }
    }

    // 4. Performance regression: check duration_ms
    var avg_duration: u64 = 0;
    if (results.len > 0) {
        for (results) |r| {
            avg_duration += r.duration_ms;
        }
        avg_duration /= results.len;

        // If avg > 10s (10000ms), flag as potential regression
        if (avg_duration > 10000) {
            score.perf_regression = 1;
            try reasons.append(try allocator.dupe(u8, "Slow execution (>10s)"));
        }
    }

    // 5. Transparency: check if message is cryptic or missing
    var has_clear_message = false;
    for (results) |r| {
        if (r.message) |msg| {
            if (msg.len > 20) has_clear_message = true;
        }
    }
    if (!has_clear_message) {
        score.transparency = 2;
        try reasons.append(try allocator.dupe(u8, "Unclear output"));
    }

    // Calculate total
    score.total = score.spec_drift + score.destructive + score.test_bypass +
        score.perf_regression + score.transparency;

    const reasons_slice = try allocator.dupe([]const u8, reasons.items);

    return Verdict{
        .is_toxic = score.total >= 8,
        .score = score,
        .reasons = reasons_slice,
    };
}

pub const Result = struct {
    success: bool,
    message: ?[]const u8,
    duration_ms: u64,
};

/// CLI command for OFC verdict
pub fn cmdVerdict(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        std.debug.print("Usage: tri ofc verdict <task>\n", .{});
        return 1;
    }

    const task = args[0];

    // Mock results for demo
    const mock_results = [_]Result{
        .{ .success = true, .message = "Generated Zig: output.zig", .duration_ms = 500 },
    };

    const verdict = try analyze(allocator, task, &mock_results);
    defer allocator.free(verdict.reasons);

    std.debug.print("\n🧠 OFC Verdict for: {s}\n\n", .{task});
    std.debug.print("  Toxic: {s}\n", .{if (verdict.is_toxic) "YES ❌" else "NO ✅"});
    std.debug.print("  Score: {d}/10\n", .{verdict.score.total});
    std.debug.print("  Breakdown:\n", .{});
    std.debug.print("    Spec drift: {d}/2\n", .{verdict.score.spec_drift});
    std.debug.print("    Destructive: {d}/2\n", .{verdict.score.destructive});
    std.debug.print("    Test bypass: {d}/2\n", .{verdict.score.test_bypass});
    std.debug.print("    Perf regression: {d}/2\n", .{verdict.score.perf_regression});
    std.debug.print("    Transparency: {d}/2\n", .{verdict.score.transparency});

    if (verdict.reasons.len > 0) {
        std.debug.print("\n  Reasons:\n", .{});
        for (verdict.reasons) |r| {
            std.debug.print("    - {s}\n", .{r});
        }
    }

    return if (verdict.is_toxic) 1 else 0;
}
