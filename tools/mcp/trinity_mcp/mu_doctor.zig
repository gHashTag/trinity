// @origin(generated) @regen(done)
//! MU DOCTOR — Thin MCP wrapper around `tri doctor`
//! Single source of truth: src/tri/tri_doctor.zig
//! phi^2 + 1/phi^2 = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (kept for MCP compatibility)
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

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN: delegates to tri doctor CLI
// ═══════════════════════════════════════════════════════════════════════════════

/// Diagnose system health — delegates to `tri doctor scan && tri doctor report`
pub fn diagnoseAndHeal(allocator: std.mem.Allocator, signal: HealthSignal) HealReport {
    var report = HealReport{};
    report.timestamp_ms = signal.timestamp_ms;

    // Delegate scan to tri doctor
    const scan_result = runTriDoctor(allocator, "scan");
    if (!scan_result) {
        report.add(.warning, .stale_pipeline, "tri doctor scan failed");
    }

    // Original health checks (kept for Oracle compatibility)
    if (!signal.build_ok) {
        report.add(.critical, .build_broken, "Build FAIL");
    }
    if (!signal.ralph_up) {
        report.add(.critical, .agent_down, "Ralph DOWN");
    }
    if (signal.dirty_files > 20) {
        report.add(.warning, .entropy, "Too many dirty files (>20)");
    }

    return report;
}

fn runTriDoctor(allocator: std.mem.Allocator, subcommand: []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "tri", "doctor", subcommand },
        .max_output_bytes = 8192,
    }) catch return false;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return (switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    }) == 0;
}

fn bufWrite(buf: []u8, s: []const u8) []const u8 {
    const len = @min(s.len, buf.len);
    @memcpy(buf[0..len], s[0..len]);
    return buf[0..len];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

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
