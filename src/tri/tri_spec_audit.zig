// @origin(manual) @regen(pending)
// TRI SPEC AUDIT — L1 Queen Caste (Doctor)

const std = @import("std");
const Allocator = std.mem.Allocator;

const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const GOLDEN = "\x1b[93m";
const GRAY = "\x1b[90m";
const RESET = "\x1b[0m";

pub const AnnotationType = enum {
    spec,
    require,
    ensure,
    example,
};

pub const MissingAnnotation = struct {
    file_path: []const u8,
    behavior_name: []const u8,
    missing: std.ArrayListUnmanaged(AnnotationType),
    recommendation: []const u8,
};

pub const SpecAuditReport = struct {
    total_files: usize,
    total_behaviors: usize,
    with_spec: usize,
    with_require: usize,
    with_ensure: usize,
    with_example: usize,
    spec_coverage: f64,
    require_coverage: f64,
    ensure_coverage: f64,
    example_coverage: f64,
    files_missing_annotations: std.ArrayListUnmanaged(MissingAnnotation),
};

pub const FileAudit = struct {
    path: []const u8,
    has_spec: bool,
    has_require: bool,
    has_require_count: usize = 0,
    has_ensure: bool,
    has_ensure_count: usize = 0,
    has_example: bool,
    has_example_count: usize = 0,
    behavior_count: usize,
};

fn gradeBar(percentage: f64) []const u8 {
    const filled: usize = @intFromFloat(@min(percentage * 20.0 / 100.0, 20.0));
    var bar: [40]u8 = undefined;
    @memset(&bar, '-');
    for (0..filled) |i| {
        bar[i] = '#';
    }
    return bar[0..40];
}

fn gradeEmoji(percentage: f64) []const u8 {
    return if (percentage >= 100.0) "✅" else if (percentage >= 80.0) "🟢" else if (percentage >= 60.0) "🟡" else if (percentage >= 40.0) "🟠" else "🔴";
}

/// Count behaviors by finding '- name:' list items at indent 2
fn countBehaviors(content: []const u8) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        // Count '- name:' keys at indent 2 (behavior list item)
        // Format: "  - name: behaviorName"
        if (line.len >= 9 and line[0] == ' ' and line[1] == ' ' and line[2] == '-' and line[3] == ' ' and line[4] == 'n' and line[5] == 'a' and line[6] == 'm' and line[7] == 'e' and line[8] == ':') {
            count += 1;
        }
    }
    return count;
}

/// Scan YAML format for spec annotations
/// Detects: spec:, require:, ensure:, example: at indent 4 within behavior blocks
pub fn scanBehaviorAnnotations(_: Allocator, content: []const u8) !FileAudit {
    var file_audit = FileAudit{
        .path = "",
        .has_spec = false,
        .has_require = false,
        .has_require_count = 0,
        .has_ensure = false,
        .has_ensure_count = 0,
        .has_example = false,
        .has_example_count = 0,
        .behavior_count = countBehaviors(content),
    };

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        // Check for keys at indent 4 (within behavior block)
        // Format: "    key: value"
        if (line.len >= 6 and line[0] == ' ' and line[1] == ' ' and line[2] == ' ' and line[3] == ' ' and line[4] != ' ') {
            const rest = line[4..];
            if (std.mem.startsWith(u8, rest, "spec:")) {
                file_audit.has_spec = true;
            } else if (std.mem.startsWith(u8, rest, "require:")) {
                file_audit.has_require = true;
                file_audit.has_require_count += 1;
            } else if (std.mem.startsWith(u8, rest, "ensure:")) {
                file_audit.has_ensure = true;
                file_audit.has_ensure_count += 1;
            } else if (std.mem.startsWith(u8, rest, "example:")) {
                file_audit.has_example = true;
                file_audit.has_example_count += 1;
            }
        }
    }

    return file_audit;
}

pub fn auditSpecDirectory(allocator: Allocator, dir_path: []const u8) !SpecAuditReport {
    var report = SpecAuditReport{
        .total_files = 0,
        .total_behaviors = 0,
        .with_spec = 0,
        .with_require = 0,
        .with_ensure = 0,
        .with_example = 0,
        .spec_coverage = 0.0,
        .require_coverage = 0.0,
        .ensure_coverage = 0.0,
        .example_coverage = 0.0,
        .files_missing_annotations = .{},
    };
    var missing_list = std.ArrayListUnmanaged(MissingAnnotation){};

    // Use openDir with iterate for Zig 0.15
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        // If directory doesn't exist or can't be opened, return empty report
        return report;
    };
    defer dir.close();

    var walker = dir.walk(allocator) catch {
        // If walk fails, return empty report
        return report;
    };
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const ext = std.fs.path.extension(entry.path);
        if (!std.mem.eql(u8, ext, ".tri")) continue;

        report.total_files += 1;

        const full_path = try std.fs.path.join(allocator, &.{ dir_path, "/", entry.path });
        defer allocator.free(full_path);

        const content = std.fs.cwd().readFileAlloc(allocator, full_path, 1024 * 1024) catch continue;
        defer allocator.free(content);

        const file_audit = try scanBehaviorAnnotations(allocator, content);
        report.total_behaviors += file_audit.behavior_count;

        // Count behaviors with each annotation (not files)
        if (file_audit.has_spec) report.with_spec += 1;
        report.with_require += file_audit.has_require_count;
        report.with_ensure += file_audit.has_ensure_count;
        report.with_example += file_audit.has_example_count;

        // Track missing annotations
        var missing_types = std.ArrayListUnmanaged(AnnotationType){};
        if (!file_audit.has_spec and file_audit.behavior_count > 0) {
            try missing_types.append(allocator, .spec);
        }
        if (!file_audit.has_require and file_audit.behavior_count > 0) {
            try missing_types.append(allocator, .require);
        }
        if (!file_audit.has_ensure and file_audit.behavior_count > 0) {
            try missing_types.append(allocator, .ensure);
        }
        if (!file_audit.has_example and file_audit.behavior_count > 0) {
            try missing_types.append(allocator, .example);
        }

        if (missing_types.items.len > 0) {
            try missing_list.append(allocator, .{
                .file_path = try allocator.dupe(u8, full_path),
                .behavior_name = try allocator.dupe(u8, entry.path),
                .missing = missing_types,
                .recommendation = "Add @spec, @require, @ensure, @example annotations",
            });
        }
    }

    report.files_missing_annotations = missing_list;

    if (report.total_behaviors > 0) {
        report.spec_coverage = @as(f64, @floatFromInt(report.with_spec)) * 100.0 / @as(f64, @floatFromInt(report.total_behaviors));
        report.require_coverage = @as(f64, @floatFromInt(report.with_require)) * 100.0 / @as(f64, @floatFromInt(report.total_behaviors));
        report.ensure_coverage = @as(f64, @floatFromInt(report.with_ensure)) * 100.0 / @as(f64, @floatFromInt(report.total_behaviors));
        report.example_coverage = @as(f64, @floatFromInt(report.with_example)) * 100.0 / @as(f64, @floatFromInt(report.total_behaviors));
    }

    return report;
}

pub fn printAuditReport(report: SpecAuditReport) void {
    std.debug.print("\n{s}TRI-27 IDIOM 11 — SPEC ANNOTATION AUDIT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}══════════════════════════════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    std.debug.print("\n{s}Summary{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Files scanned: {d}\n", .{report.total_files});
    std.debug.print("  Behaviors: {d}\n", .{report.total_behaviors});

    std.debug.print("\n{s}Coverage{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}@spec{s}:    {s} {d:.1}%\n", .{ GREEN, RESET, gradeEmoji(report.spec_coverage), report.spec_coverage });
    std.debug.print("  {s}@require{s}: {s} {d:.1}%\n", .{ GREEN, RESET, gradeEmoji(report.require_coverage), report.require_coverage });
    std.debug.print("  {s}@ensure{s}:  {s} {d:.1}%\n", .{ GREEN, RESET, gradeEmoji(report.ensure_coverage), report.ensure_coverage });
    std.debug.print("  {s}@example{s}: {s} {d:.1}%\n", .{ GREEN, RESET, gradeEmoji(report.example_coverage), report.example_coverage });

    if (report.files_missing_annotations.items.len > 0) {
        std.debug.print("\n{s}Files Missing Annotations{s}\n", .{ YELLOW, RESET });
        for (report.files_missing_annotations.items) |missing| {
            std.debug.print("  {s}<--{s} {s}\n", .{ GRAY, RESET, missing.file_path });
            std.debug.print("    Missing: ", .{});
            for (missing.missing.items) |t| {
                const label = switch (t) {
                    .spec => "@spec",
                    .require => "@require",
                    .ensure => "@ensure",
                    .example => "@example",
                };
                std.debug.print("{s}{s}{s} ", .{ RED, label, RESET });
            }
            std.debug.print("\n\n", .{});
        }
    }

    const overall = (report.spec_coverage + report.require_coverage + report.ensure_coverage + report.example_coverage) / 4.0;
    std.debug.print("\n{s}Overall: {s} {d:.1}%{s}\n", .{ GOLDEN, gradeEmoji(overall), overall, RESET });
    std.debug.print("{s}══════════════════════════════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n", .{});
}

pub fn auditSpecs(allocator: Allocator, dir_path: []const u8) !SpecAuditReport {
    return auditSpecDirectory(allocator, dir_path);
}

test "scan empty file" {
    const allocator = std.testing.allocator;
    const content = "";
    const result = scanBehaviorAnnotations(allocator, content);
    try std.testing.expectEqual(@as(usize, 0), result.behavior_count);
    try std.testing.expectEqual(false, result.has_spec);
    try std.testing.expectEqual(false, result.has_require);
    try std.testing.expectEqual(false, result.has_ensure);
    try std.testing.expectEqual(false, result.has_example);
}
