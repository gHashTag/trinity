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
    has_ensure: bool,
    has_example: bool,
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

pub fn scanBehaviorAnnotations(_: Allocator, content: []const u8) !FileAudit {
    var file_audit = FileAudit{
        .path = "",
        .has_spec = false,
        .has_require = false,
        .has_ensure = false,
        .has_example = false,
        .behavior_count = 0,
    };

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line);
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.eql(u8, trimmed, "@spec")) {
            file_audit.has_spec = true;
            file_audit.behavior_count += 1;
        } else if (std.mem.eql(u8, trimmed, "@require")) {
            file_audit.has_require = true;
        } else if (std.mem.eql(u8, trimmed, "@ensure")) {
            file_audit.has_ensure = true;
        } else if (std.mem.eql(u8, trimmed, "@example")) {
            file_audit.has_example = true;
        }
    }

    return file_audit;
}

pub fn auditSpecDirectory(_: Allocator, dir_path: []const u8) !SpecAuditReport {
    _ = dir_path;
    // TODO: Implement directory scanning for Zig 0.15
    return SpecAuditReport{
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
}

pub fn printAuditReport(report: SpecAuditReport) void {
    std.debug.print("\n{s}TRI-27 IDIOM 11 — SPEC ANNOTATION AUDIT{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}══════════════════════════════════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n{s}TODO: Implement audit report printing{s}\n", .{ YELLOW, RESET });
    std.debug.print("Files: {d}, Behaviors: {d}\n", .{ report.total_files, report.total_behaviors });
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
