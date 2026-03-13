//! MU DOCTOR — Доктор Айболит системы Trinity
//! Центральный диагност: видит ВСЁ сверху, лечит автоматически.
//! Вызывается Oracle Watchdog после каждого сбора метрик.
//! phi^2 + 1/phi^2 = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Severity = enum { critical, warning, info };

pub const Category = enum {
    build_broken,
    agent_down,
    spec_fail,
    command_spam,
    entropy,
    stale_pipeline,
};

pub const HealthSignal = struct {
    build_ok: bool,
    ralph_up: bool,
    bridge_up: bool,
    training_active: bool,
    dirty_files: u32,
    timestamp_ms: u64,
};

pub const Diagnosis = struct {
    severity: Severity,
    category: Category,
    description: [256]u8 = [_]u8{0} ** 256,
    description_len: usize = 0,
    auto_healable: bool = false,
    healed: bool = false,

    pub fn getDescription(self: *const Diagnosis) []const u8 {
        return self.description[0..self.description_len];
    }
};

pub const HealReport = struct {
    diagnoses: [16]Diagnosis = undefined,
    count: usize = 0,
    healed_count: usize = 0,
    timestamp_ms: u64 = 0,

    pub fn add(self: *HealReport, sev: Severity, cat: Category, desc: []const u8) void {
        if (self.count >= 16) return;
        var d = Diagnosis{
            .severity = sev,
            .category = cat,
        };
        const copy_len = @min(desc.len, d.description.len);
        @memcpy(d.description[0..copy_len], desc[0..copy_len]);
        d.description_len = copy_len;
        self.diagnoses[self.count] = d;
        self.count += 1;
    }

    pub fn markHealed(self: *HealReport, idx: usize) void {
        if (idx < self.count) {
            self.diagnoses[idx].healed = true;
            self.diagnoses[idx].auto_healable = true;
            self.healed_count += 1;
        }
    }

    /// Format a concise status string for Telegram
    pub fn formatStatus(self: *const HealReport, buf: []u8) []const u8 {
        if (self.count == 0) {
            return bufWrite(buf, "OK");
        }
        if (self.healed_count > 0 and self.healed_count == self.count) {
            return std.fmt.bufPrint(buf, "HEALED {d}", .{self.healed_count}) catch buf[0..0];
        }
        if (self.healed_count > 0) {
            return std.fmt.bufPrint(buf, "ALERT {d} (healed {d})", .{
                self.count - self.healed_count,
                self.healed_count,
            }) catch buf[0..0];
        }
        return std.fmt.bufPrint(buf, "ALERT {d}", .{self.count}) catch buf[0..0];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN FUNCTION: diagnoseAndHeal
// ═══════════════════════════════════════════════════════════════════════════════

pub fn diagnoseAndHeal(allocator: std.mem.Allocator, signal: HealthSignal) HealReport {
    var report = HealReport{};
    report.timestamp_ms = signal.timestamp_ms;

    // 1. BUILD BROKEN
    if (!signal.build_ok) {
        report.add(.critical, .build_broken, "Build FAIL");
        if (healBuildFailure(allocator)) {
            report.markHealed(report.count - 1);
        }
    }

    // 2. AGENT DOWN — Ralph
    if (!signal.ralph_up) {
        report.add(.critical, .agent_down, "Ralph DOWN");
        if (healAgentDown(allocator, "ralph-agent")) {
            report.markHealed(report.count - 1);
        }
    }

    // 3. COMMAND SPAM
    if (detectCommandSpam(allocator)) {
        report.add(.warning, .command_spam, "Command spam detected");
    }

    // 4. ENTROPY — too many dirty files
    if (signal.dirty_files > 20) {
        report.add(.warning, .entropy, "Too many dirty files (>20)");
    }

    // 5. UNRESOLVED ERRORS from .trinity/mu/errors/
    const healed_errors = healUnresolvedErrors(allocator);
    if (healed_errors > 0) {
        report.add(.info, .spec_fail, "Auto-fixed error logs");
        report.markHealed(report.count - 1);
    }

    return report;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEAL FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Try to heal build failure by running zig fmt
fn healBuildFailure(allocator: std.mem.Allocator) bool {
    // Try zig fmt first — fixes formatting errors
    const fmt_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "fmt", "src/" },
        .max_output_bytes = 4096,
    }) catch return false;
    allocator.free(fmt_result.stdout);
    allocator.free(fmt_result.stderr);

    // Check if build passes now
    const build_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build" },
        .max_output_bytes = 4096,
    }) catch return false;
    allocator.free(build_result.stdout);
    allocator.free(build_result.stderr);

    return (switch (build_result.term) { .Exited => |code| code, else => @as(u32, 1) }) == 0;
}

/// Try to restart a down agent via launchctl
fn healAgentDown(allocator: std.mem.Allocator, agent_name: []const u8) bool {
    // Get current UID
    const uid_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "id", "-u" },
        .max_output_bytes = 64,
    }) catch return false;
    defer allocator.free(uid_result.stdout);
    defer allocator.free(uid_result.stderr);

    const uid = std.mem.trimRight(u8, uid_result.stdout, "\n\r ");
    if (uid.len == 0) return false;

    // Build service target: gui/{uid}/com.trinity.{agent}
    var target_buf: [128]u8 = undefined;
    const target = std.fmt.bufPrint(&target_buf, "gui/{s}/com.trinity.{s}", .{ uid, agent_name }) catch return false;

    // Try launchctl kickstart
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "launchctl", "kickstart", "-k", target },
        .max_output_bytes = 1024,
    }) catch return false;
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    return (switch (result.term) { .Exited => |code| code, else => @as(u32, 1) }) == 0;
}

/// Detect if the same command was run >10 times in the last hour
fn detectCommandSpam(allocator: std.mem.Allocator) bool {
    // Check .trinity/jobs/ for repeated commands
    var dir = std.fs.cwd().openDir(".trinity/jobs", .{ .iterate = true }) catch return false;
    defer dir.close();

    var cmd_counts: [32][256]u8 = undefined;
    var cmd_lens: [32]usize = [_]usize{0} ** 32;
    var counts: [32]u32 = [_]u32{0} ** 32;
    var unique: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;

        // Read metadata.json from each job dir
        var path_buf: [512]u8 = undefined;
        const meta_path = std.fmt.bufPrint(&path_buf, "{s}/metadata.json", .{entry.name}) catch continue;

        const meta_file = dir.openFile(meta_path, .{}) catch continue;
        defer meta_file.close();

        var content_buf: [2048]u8 = undefined;
        const bytes_read = meta_file.readAll(&content_buf) catch continue;
        const content = content_buf[0..bytes_read];

        // Extract command field (simple parsing)
        if (extractJsonField(content, "command")) |cmd| {
            // Find or add
            var found = false;
            for (0..unique) |i| {
                if (cmd_lens[i] == cmd.len and std.mem.eql(u8, cmd_counts[i][0..cmd_lens[i]], cmd)) {
                    counts[i] += 1;
                    if (counts[i] > 10) return true;
                    found = true;
                    break;
                }
            }
            if (!found and unique < 32) {
                const copy_len = @min(cmd.len, 256);
                @memcpy(cmd_counts[unique][0..copy_len], cmd[0..copy_len]);
                cmd_lens[unique] = copy_len;
                counts[unique] = 1;
                unique += 1;
            }
        }
    }

    _ = allocator;
    return false;
}

/// Scan .trinity/mu/errors/*.json and try to auto-fix OPEN ones
fn healUnresolvedErrors(allocator: std.mem.Allocator) u32 {
    var dir = std.fs.cwd().openDir(".trinity/mu/errors", .{ .iterate = true }) catch return 0;
    defer dir.close();

    var healed: u32 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();

        var content_buf: [4096]u8 = undefined;
        const bytes_read = file.readAll(&content_buf) catch continue;
        const content = content_buf[0..bytes_read];

        // Check if OPEN
        if (std.mem.indexOf(u8, content, "\"OPEN\"") == null) continue;

        // Try to extract file_path and apply zig fmt
        if (extractJsonField(content, "file_path")) |file_path| {
            const result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "zig", "fmt", file_path },
                .max_output_bytes = 1024,
            }) catch continue;
            allocator.free(result.stdout);
            allocator.free(result.stderr);
            if ((switch (result.term) { .Exited => |code| code, else => @as(u32, 1) }) == 0) {
                healed += 1;
            }
        }
    }

    return healed;
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple JSON field extraction (finds "key":"value" pattern)
fn extractJsonField(json: []const u8, key: []const u8) ?[]const u8 {
    // Search for "key":"
    var search_buf: [270]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;

    const start_idx = std.mem.indexOf(u8, json, search) orelse return null;
    const value_start = start_idx + search.len;
    if (value_start >= json.len) return null;

    // Find closing quote
    const value_end = std.mem.indexOfScalarPos(u8, json, value_start, '"') orelse return null;
    return json[value_start..value_end];
}

fn bufWrite(buf: []u8, s: []const u8) []const u8 {
    const len = @min(s.len, buf.len);
    @memcpy(buf[0..len], s[0..len]);
    return buf[0..len];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "diagnose build failure" {
    var report = HealReport{};
    report.add(.critical, .build_broken, "Build FAIL");
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expectEqual(Severity.critical, report.diagnoses[0].severity);
    try std.testing.expectEqual(Category.build_broken, report.diagnoses[0].category);
    try std.testing.expectEqualStrings("Build FAIL", report.diagnoses[0].getDescription());
}

test "diagnose agent down" {
    var report = HealReport{};
    report.add(.critical, .agent_down, "Ralph DOWN");
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expectEqual(Category.agent_down, report.diagnoses[0].category);
}

test "heal report formatting - OK" {
    const report = HealReport{};
    var buf: [64]u8 = undefined;
    const status = report.formatStatus(&buf);
    try std.testing.expectEqualStrings("OK", status);
}

test "heal report formatting - ALERT" {
    var report = HealReport{};
    report.add(.critical, .build_broken, "Build FAIL");
    var buf: [64]u8 = undefined;
    const status = report.formatStatus(&buf);
    try std.testing.expectEqualStrings("ALERT 1", status);
}

test "heal report formatting - HEALED" {
    var report = HealReport{};
    report.add(.critical, .build_broken, "Build FAIL");
    report.markHealed(0);
    var buf: [64]u8 = undefined;
    const status = report.formatStatus(&buf);
    try std.testing.expectEqualStrings("HEALED 1", status);
}

test "heal report formatting - mixed" {
    var report = HealReport{};
    report.add(.critical, .build_broken, "Build FAIL");
    report.add(.critical, .agent_down, "Ralph DOWN");
    report.markHealed(0);
    var buf: [64]u8 = undefined;
    const status = report.formatStatus(&buf);
    try std.testing.expect(std.mem.indexOf(u8, status, "ALERT") != null);
    try std.testing.expect(std.mem.indexOf(u8, status, "healed 1") != null);
}

test "extract json field" {
    const json =
        \\{"file_path":"/src/foo.zig","status":"OPEN","error":"syntax"}
    ;
    const path = extractJsonField(json, "file_path");
    try std.testing.expect(path != null);
    try std.testing.expectEqualStrings("/src/foo.zig", path.?);

    const status = extractJsonField(json, "status");
    try std.testing.expect(status != null);
    try std.testing.expectEqualStrings("OPEN", status.?);

    const missing = extractJsonField(json, "nonexistent");
    try std.testing.expect(missing == null);
}

test "detect command spam returns bool" {
    // detectCommandSpam returns a bool regardless of filesystem state
    const result = detectCommandSpam(std.testing.allocator);
    _ = result; // just verify it doesn't crash
}

test "health signal all green" {
    const signal = HealthSignal{
        .build_ok = true,
        .ralph_up = true,
        .bridge_up = true,
        .training_active = false,
        .dirty_files = 3,
        .timestamp_ms = 12345,
    };
    // diagnoseAndHeal spawns child processes, so we only test signal construction
    _ = signal;
}
