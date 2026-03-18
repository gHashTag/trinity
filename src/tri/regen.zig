// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// REGEN — Immune System for Trinity (Wave 5)
// ═══════════════════════════════════════════════════════════════════════════════
//
// The immune system scans for codebase issues and auto-generates fix plans.
// Part of Phoenix sleep cycle: after dream replay, analyze and heal.
//
// Commands:
//   tri regen analyze     — scan and show analysis without executing
//   tri regen plan        — view current fix_plan.md
//   tri regen execute     — run the fix plan
//   tri regen status      — immune system stats
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const hippocampus = @import("hippocampus.zig");
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const MAGENTA = "\x1b[35m";

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const FixItem = struct {
    id: [64]u8 = undefined,
    id_len: u8 = 0,
    summary: [256]u8 = undefined,
    summary_len: u16 = 0,
    priority: Priority = .medium,
    source: FixSource = .doctor,
    status: FixStatus = .pending,

    pub fn idStr(self: *const FixItem) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn summaryStr(self: *const FixItem) []const u8 {
        return self.summary[0..self.summary_len];
    }
};

pub const Priority = enum(u8) {
    critical = 0, // Build breaks, crashes
    high = 1, // Test failures, security issues
    medium = 2, // Doctor violations, style issues
    low = 3, // Optimizations, nice-to-haves

    pub fn color(self: Priority) []const u8 {
        return switch (self) {
            .critical => RED,
            .high => MAGENTA,
            .medium => YELLOW,
            .low => CYAN,
        };
    }

    pub fn tag(self: Priority) []const u8 {
        return switch (self) {
            .critical => "P0",
            .high => "P1",
            .medium => "P2",
            .low => "P3",
        };
    }
};

pub const FixSource = enum {
    doctor, // .doctor/scan_results.json violations
    hippocampus, // Error memories from hippocampus
    pipeline, // Failed pipeline runs
    manual, // User-reported

    pub fn label(self: FixSource) []const u8 {
        return switch (self) {
            .doctor => "DOCTOR",
            .hippocampus => "MEMORY",
            .pipeline => "PIPELINE",
            .manual => "MANUAL",
        };
    }

    pub fn icon(self: FixSource) []const u8 {
        return switch (self) {
            .doctor => "🩺",
            .hippocampus => "🧬",
            .pipeline => "🔧",
            .manual => "✍️",
        };
    }
};

pub const FixStatus = enum {
    pending,
    in_progress,
    completed,
    failed,

    pub fn icon(self: FixStatus) []const u8 {
        return switch (self) {
            .pending => "⏳",
            .in_progress => "🔄",
            .completed => "✅",
            .failed => "❌",
        };
    }
};

pub const RegenAnalysis = struct {
    violations_count: u32 = 0,
    infected_files: u32 = 0,
    manual_ratio: f32 = 0.0,
    error_memories: u32 = 0,
    fix_items: [32]FixItem = undefined,
    fix_count: u8 = 0,
    timestamp: i64 = 0,
    health_score: u8 = 0,

    pub fn deinit(self: *RegenAnalysis, allocator: Allocator) void {
        _ = self;
        _ = allocator;
        // Stack-allocated, nothing to free
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE API
// ═══════════════════════════════════════════════════════════════════════════════

/// Analyze codebase health and generate fix items
pub fn analyze(allocator: Allocator) !RegenAnalysis {
    var result = RegenAnalysis{
        .timestamp = std.time.timestamp(),
    };

    // 1. Scan doctor violations
    scanDoctorViolations(allocator, &result) catch |err| {
        print("  {s}⚠️  Doctor scan failed: {}{s}\n", .{ YELLOW, err, RESET });
    };

    // 2. Read hippocampus error memories
    scanErrorMemories(allocator, &result) catch |err| {
        print("  {s}⚠️  Memory scan failed: {}{s}\n", .{ YELLOW, err, RESET });
    };

    // 3. Calculate health score
    result.health_score = calculateHealthScore(&result);

    return result;
}

/// Execute fix plan: iterate items and apply fixes
pub fn executeFixPlan(allocator: Allocator, plan: *const RegenAnalysis) !void {
    print("\n{s}🛡️ IMMUNE RESPONSE{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var completed: u8 = 0;
    var failed: u8 = 0;

    for (plan.fix_items[0..plan.fix_count], 0..) |item, idx| {
        if (item.status == .completed) continue;

        print("{s}[{d}/{d}]{s} {s} {s} {s}{s} {s}\n", .{
            DIM,                idx + 1,             plan.fix_count,        RESET,
            item.source.icon(), item.priority.tag(), item.priority.color(), item.summaryStr(),
            RESET,
        });

        const success = try executeFix(allocator, item);
        if (success) {
            completed += 1;
            // Write successful fix as rule to hippocampus
            var buf: [256]u8 = undefined;
            var data_buf: [128]u8 = undefined;
            const summary = std.fmt.bufPrint(&buf, "FIXED: {s}", .{item.summaryStr()}) catch "fixed";
            const data = std.fmt.bufPrint(&data_buf, "{{\"source\":\"{s}\",\"priority\":\"{s}\"}}", .{
                item.source.label(),
                @tagName(item.priority),
            }) catch "{}";
            hippocampus.writeRule(allocator, "immune_system", summary, data) catch |err| {
                print("  {s}⚠️  Failed to write rule: {}{s}\n", .{ YELLOW, err, RESET });
            };
            print("  {s}✅{s} Fixed and stored as rule\n\n", .{ GREEN, RESET });
        } else {
            failed += 1;
            // Write error back to hippocampus for retry
            var buf: [256]u8 = undefined;
            const error_summary = std.fmt.bufPrint(&buf, "FAILED: {s}", .{item.summaryStr()}) catch "failed";
            hippocampus.writeError(allocator, "immune_system", error_summary, "{}") catch {};
            print("  {s}❌{s} Failed (will retry in next cycle)\n\n", .{ RED, RESET });
        }
    }

    // Log immune response
    var buf: [256]u8 = undefined;
    var data_buf: [128]u8 = undefined;
    const response_summary = std.fmt.bufPrint(&buf, "IMMUNE: {d} fixes completed, {d} failed", .{ completed, failed }) catch "immune";
    const response_data = std.fmt.bufPrint(&data_buf, "{{\"completed\":{d},\"failed\":{d}}}", .{ completed, failed }) catch "{}";
    hippocampus.writeObservation(allocator, "immune_system", response_summary, response_data) catch {};

    print("{s}═══════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}📊 Immune response: {d} healed, {d} deferred{s}\n\n", .{ BOLD, completed, failed, RESET });
}

/// Show immune system status
pub fn showStatus(allocator: Allocator) !void {
    print("\n{s}🛡️ IMMUNE SYSTEM STATUS{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Read latest immune observations
    var results = hippocampus.read(allocator, .{
        .agent = "immune_system",
        .kind = .observation,
        .limit = 5,
    }) catch {
        print("  {s}⚠️  No immune activity found{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer results.deinit(allocator);

    if (results.items.len == 0) {
        print("  {s}⊙{s} No immune activity yet\n", .{ DIM, RESET });
        return;
    }

    print("{s}Recent immune responses:{s}\n\n", .{ CYAN, RESET });
    for (results.items) |rec| {
        const rec_ts: i64 = @intCast(rec.ts);
        const dt = std.time.timestamp() - rec_ts;
        var ago_buf: [32]u8 = undefined;
        const ago = if (dt < 60) "just now" else if (dt < 3600) std.fmt.bufPrint(&ago_buf, "{d}m ago", .{@divTrunc(dt, 60)}) catch "?" else std.fmt.bufPrint(&ago_buf, "{d}h ago", .{@divTrunc(dt, 3600)}) catch "?";
        print("  {s}{s}{s} {s}\n", .{ DIM, ago, RESET, rec.summary() });
    }

    // Count rules learned
    var rules = hippocampus.read(allocator, .{
        .agent = "immune_system",
        .kind = .rule,
        .limit = 1000,
    }) catch {
        return;
    };
    defer rules.deinit(allocator);

    print("\n{s}Rules learned: {d}{s}\n", .{ GREEN, rules.items.len, RESET });
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn scanDoctorViolations(allocator: Allocator, result: *RegenAnalysis) !void {
    _ = allocator; // Not used, but kept for API consistency
    const file = std.fs.cwd().openFile(".trinity/scan_results.json", .{}) catch {
        // No scan results yet
        return;
    };
    defer file.close();

    var buf: [16384]u8 = undefined;
    const content_len = try file.readAll(&buf);
    const content = buf[0..content_len];

    // Simple JSON parsing for doctor results
    // Looking for patterns like "violations": N, "infected": N
    if (std.mem.indexOf(u8, content, "\"violations\"")) |idx| {
        const num_start = idx + "\"violations\":".len;
        var num_end = num_start;
        while (num_end < content.len and content[num_end] >= '0' and content[num_end] <= '9') : (num_end += 1) {}
        if (num_end > num_start) {
            result.violations_count = std.fmt.parseInt(u32, content[num_start..num_end], 10) catch 0;
        }
    }

    if (std.mem.indexOf(u8, content, "\"infected\"")) |idx| {
        const num_start = idx + "\"infected\":".len;
        var num_end = num_start;
        while (num_end < content.len and content[num_end] >= '0' and content[num_end] <= '9') : (num_end += 1) {}
        if (num_end > num_start) {
            result.infected_files = std.fmt.parseInt(u32, content[num_start..num_end], 10) catch 0;
        }
    }

    if (std.mem.indexOf(u8, content, "\"manual_ratio\"")) |idx| {
        const num_start = idx + "\"manual_ratio\":".len;
        var num_end = num_start;
        while (num_end < content.len and (content[num_end] >= '0' and content[num_end] <= '9' or content[num_end] == '.')) : (num_end += 1) {}
        if (num_end > num_start) {
            result.manual_ratio = std.fmt.parseFloat(f32, content[num_start..num_end]) catch 0.0;
        }
    }

    // Add fix items for critical violations
    if (result.violations_count > 0 and result.fix_count < 32) {
        var item = FixItem{
            .source = .doctor,
            .priority = if (result.violations_count > 10) .critical else .medium,
        };
        const id = std.fmt.bufPrint(&item.id, "doctor_violations_{d}", .{result.violations_count}) catch "doctor";
        item.id_len = @intCast(id.len);
        const summary = std.fmt.bufPrint(&item.summary, "Fix {d} doctor violations", .{result.violations_count}) catch "Fix violations";
        item.summary_len = @intCast(summary.len);
        result.fix_items[result.fix_count] = item;
        result.fix_count += 1;
    }
}

fn scanErrorMemories(allocator: Allocator, result: *RegenAnalysis) !void {
    var errors = hippocampus.read(allocator, .{
        .kind = .@"error",
        .limit = 10,
    }) catch {
        return;
    };
    defer errors.deinit(allocator);

    result.error_memories = @intCast(errors.items.len);

    // Add recent errors to fix plan
    const now: i64 = std.time.timestamp();
    for (errors.items) |err| {
        if (result.fix_count >= 32) break;
        const err_ts: i64 = @intCast(err.ts);
        if (now - err_ts > 7 * 24 * 3600) continue; // Only recent errors

        var item = FixItem{
            .source = .hippocampus,
            .priority = .high,
        };
        const id = std.fmt.bufPrint(&item.id, "mem_{s}", .{err.id()}) catch "mem";
        item.id_len = @intCast(id.len);
        const summary = std.fmt.bufPrint(&item.summary, "{s}", .{err.summary()}) catch "error";
        item.summary_len = @intCast(summary.len);
        result.fix_items[result.fix_count] = item;
        result.fix_count += 1;
    }
}

fn calculateHealthScore(analysis: *const RegenAnalysis) u8 {
    // Health score: 0-100 based on violations and manual ratio
    var score: u8 = 100;

    // Lose points for violations
    if (analysis.violations_count > 0) {
        const loss = @min(50, analysis.violations_count * 2);
        score -|= loss;
    }

    // Lose points for high manual ratio (>50% is bad)
    if (analysis.manual_ratio > 0.5) {
        const ratio_loss = @as(u8, @intFromFloat((analysis.manual_ratio - 0.5) * 100));
        score -|= @min(30, ratio_loss);
    }

    // Lose points for error memories
    if (analysis.error_memories > 0) {
        score -|= @min(20, analysis.error_memories * 2);
    }

    return score;
}

fn executeFix(allocator: Allocator, item: FixItem) !bool {
    switch (item.source) {
        .doctor => {
            // Run tri doctor heal
            const result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "tri", "doctor", "heal" },
                .max_output_bytes = 1_000_000,
            }) catch return false;
            defer {
                allocator.free(result.stdout);
                allocator.free(result.stderr);
            }
            return result.term.Exited == 0;
        },
        .hippocampus => {
            // For error memories, try to diagnose
            // This would require more sophisticated analysis
            // For now, just run tests to see if still broken
            const test_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "tri", "test" },
                .max_output_bytes = 1_000_000,
            }) catch return false;
            defer {
                allocator.free(test_result.stdout);
                allocator.free(test_result.stderr);
            }
            // If tests pass, consider it fixed (maybe externally)
            return test_result.term.Exited == 0;
        },
        .pipeline => {
            // Retry pipeline run
            return false; // Not implemented yet
        },
        .manual => {
            // Can't auto-fix manual items
            return false;
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runRegenCLI(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        printUsage();
        return;
    }

    const subcommand = args[1];

    if (std.mem.eql(u8, subcommand, "analyze")) {
        const analysis = try analyze(allocator);
        try renderAnalysis(&analysis);
    } else if (std.mem.eql(u8, subcommand, "plan")) {
        try showFixPlan();
    } else if (std.mem.eql(u8, subcommand, "execute")) {
        const analysis = try analyze(allocator);
        try executeFixPlan(allocator, &analysis);
    } else if (std.mem.eql(u8, subcommand, "status")) {
        try showStatus(allocator);
    } else {
        printUsage();
    }
}

fn printUsage() void {
    print("\n{s}🛡️ IMMUNE SYSTEM — Auto-Healing{s}\n", .{ BOLD, RESET });
    print("\n", .{});
    print("  {s}tri regen analyze{s}   Scan and show analysis\n", .{ CYAN, RESET });
    print("  {s}tri regen plan{s}      View current fix_plan.md\n", .{ CYAN, RESET });
    print("  {s}tri regen execute{s}   Run the fix plan\n", .{ CYAN, RESET });
    print("  {s}tri regen status{s}    Immune system stats\n", .{ CYAN, RESET });
    print("{s}\n", .{""});
}

fn renderAnalysis(analysis: *const RegenAnalysis) !void {
    print("\n{s}🛡️ IMMUNE ANALYSIS{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Health score
    const health_color = if (analysis.health_score >= 80) GREEN else if (analysis.health_score >= 50) YELLOW else RED;
    print("{s}Health Score:{s} {s}{d:3}/100{s}\n", .{ BOLD, RESET, health_color, analysis.health_score, RESET });

    // Metrics
    print("\n{s}Metrics:{s}\n", .{ CYAN, RESET });
    print("  Violations:     {d}\n", .{analysis.violations_count});
    print("  Infected files: {d}\n", .{analysis.infected_files});
    print("  Manual ratio:   {d:.1}%\n", .{analysis.manual_ratio * 100});
    print("  Error memories: {d}\n", .{analysis.error_memories});

    // Fix items
    if (analysis.fix_count > 0) {
        print("\n{s}Fix Queue ({d}):{s}\n\n", .{ BOLD, analysis.fix_count, RESET });
        for (analysis.fix_items[0..analysis.fix_count], 0..) |item, idx| {
            print("  [{d:2}] {s} {s} {s}{s} {s}\n", .{
                idx + 1,
                item.source.icon(),
                item.priority.tag(),
                item.priority.color(),
                item.summaryStr(),
                RESET,
            });
        }
    } else {
        print("\n{s}✅ No fixes needed{s}\n", .{ GREEN, RESET });
    }

    print("\n", .{});
}

fn showFixPlan() !void {
    const file = std.fs.cwd().openFile(".phoenix/fix_plan.md", .{}) catch {
        print("\n{s}⊙{s} No fix plan exists yet\n", .{ DIM, RESET });
        return;
    };
    defer file.close();

    var buf: [16384]u8 = undefined;
    const content_len = try file.readAll(&buf);
    const content = buf[0..content_len];

    print("\n{s}📋 FIX PLAN{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("{s}", .{content});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RegenAnalysis initialization" {
    const analysis = RegenAnalysis{};
    try std.testing.expectEqual(@as(u32, 0), analysis.violations_count);
    try std.testing.expectEqual(@as(u8, 0), analysis.fix_count);
}

test "Priority colors" {
    try std.testing.expectEqual(RED, Priority.critical.color());
    try std.testing.expectEqual(MAGENTA, Priority.high.color());
    try std.testing.expectEqual(YELLOW, Priority.medium.color());
    try std.testing.expectEqual(CYAN, Priority.low.color());
}

test "FixSource labels" {
    try std.testing.expectEqual("DOCTOR", FixSource.doctor.label());
    try std.testing.expectEqual("MEMORY", FixSource.hippocampus.label());
    try std.testing.expectEqual("PIPELINE", FixSource.pipeline.label());
    try std.testing.expectEqual("MANUAL", FixSource.manual.label());
}

test "calculateHealthScore with violations" {
    var analysis = RegenAnalysis{
        .violations_count = 5,
        .manual_ratio = 0.3,
        .error_memories = 0,
    };
    const score = calculateHealthScore(&analysis);
    try std.testing.expect(score >= 80 and score <= 100); // 5 violations = -10 points
}
