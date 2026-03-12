// =============================================================================
// HANDOFF PROTOCOL — v5.0 Role Split Inter-Role Communication
// =============================================================================
//
// Each role writes its output artifact to .trinity/handoff/issue-{N}/:
//   planner_output.json   — subtasks, files, approach, spec_path
//   coder_output.json     — branch, files_modified, commits
//   reviewer_verdict.json — approved, feedback, iteration
//   tester_report.json    — tests_passed, tests_total, benchmarks, regressions
//
// JSON schemas are simple structs serialized via std.json.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const golden_chain = @import("golden_chain.zig");

const AgentRole = golden_chain.AgentRole;

// =============================================================================
// HANDOFF ARTIFACT TYPES
// =============================================================================

pub const PlannerOutput = struct {
    issue_number: u32,
    subtasks: []const []const u8,
    files: []const []const u8,
    approach: []const u8,
    spec_path: []const u8,
    timestamp: i64,
};

pub const CoderOutput = struct {
    issue_number: u32,
    branch: []const u8,
    files_modified: []const []const u8,
    commits: []const []const u8,
    lines_added: u32,
    lines_removed: u32,
    timestamp: i64,
};

pub const ReviewerVerdict = struct {
    issue_number: u32,
    approved: bool,
    feedback: []const []const u8,
    iteration: u8,
    max_iterations: u8,
    files_reviewed: []const []const u8,
    timestamp: i64,
};

pub const TesterReport = struct {
    issue_number: u32,
    tests_passed: u32,
    tests_total: u32,
    tests_failed_names: []const []const u8,
    build_success: bool,
    fmt_clean: bool,
    benchmarks: []const BenchmarkEntry,
    regressions: []const []const u8,
    timestamp: i64,
};

pub const BenchmarkEntry = struct {
    name: []const u8,
    value: f64,
    unit: []const u8,
    baseline: f64,
    delta_pct: f64,
};

// =============================================================================
// HANDOFF DIRECTORY MANAGEMENT
// =============================================================================

const HANDOFF_BASE = ".trinity/handoff";

/// Build the handoff directory path for an issue: .trinity/handoff/issue-{N}
pub fn getHandoffDir(buf: *[256]u8, issue_number: u32) []const u8 {
    return std.fmt.bufPrint(buf, HANDOFF_BASE ++ "/issue-{d}", .{issue_number}) catch HANDOFF_BASE;
}

/// Ensure the handoff directory exists for a given issue.
pub fn ensureHandoffDir(issue_number: u32) !void {
    var buf: [256]u8 = undefined;
    const dir_path = getHandoffDir(&buf, issue_number);
    try std.fs.cwd().makePath(dir_path);
}

/// Get the artifact filename for a given role.
pub fn getArtifactFilename(role: AgentRole) []const u8 {
    return switch (role) {
        .planner => "planner_output.json",
        .coder => "coder_output.json",
        .reviewer => "reviewer_verdict.json",
        .tester => "tester_report.json",
        .integrator => "integrator_summary.json",
    };
}

/// Build the full artifact path: .trinity/handoff/issue-{N}/<artifact>.json
pub fn getArtifactPath(buf: *[512]u8, issue_number: u32, role: AgentRole) []const u8 {
    var dir_buf: [256]u8 = undefined;
    const dir_path = getHandoffDir(&dir_buf, issue_number);
    const filename = getArtifactFilename(role);
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ dir_path, filename }) catch "";
}

// =============================================================================
// WRITE ARTIFACTS
// =============================================================================

/// Write a PlannerOutput artifact to the handoff directory.
pub fn writePlannerOutput(issue_number: u32, output: PlannerOutput) !void {
    try ensureHandoffDir(issue_number);
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .planner);
    try writeJsonFile(path, PlannerOutput, output);
}

/// Write a CoderOutput artifact to the handoff directory.
pub fn writeCoderOutput(issue_number: u32, output: CoderOutput) !void {
    try ensureHandoffDir(issue_number);
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .coder);
    try writeJsonFile(path, CoderOutput, output);
}

/// Write a ReviewerVerdict artifact to the handoff directory.
pub fn writeReviewerVerdict(issue_number: u32, verdict: ReviewerVerdict) !void {
    try ensureHandoffDir(issue_number);
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .reviewer);
    try writeJsonFile(path, ReviewerVerdict, verdict);
}

/// Write a TesterReport artifact to the handoff directory.
pub fn writeTesterReport(issue_number: u32, report: TesterReport) !void {
    try ensureHandoffDir(issue_number);
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .tester);
    try writeJsonFile(path, TesterReport, report);
}

// =============================================================================
// READ ARTIFACTS
// =============================================================================

/// Read a ReviewerVerdict from the handoff directory.
/// Returns null if the file does not exist.
pub fn readReviewerVerdict(allocator: std.mem.Allocator, issue_number: u32) !?ReviewerVerdict {
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .reviewer);
    return readJsonFile(allocator, path, ReviewerVerdict);
}

/// Read a PlannerOutput from the handoff directory.
pub fn readPlannerOutput(allocator: std.mem.Allocator, issue_number: u32) !?PlannerOutput {
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .planner);
    return readJsonFile(allocator, path, PlannerOutput);
}

/// Read a CoderOutput from the handoff directory.
pub fn readCoderOutput(allocator: std.mem.Allocator, issue_number: u32) !?CoderOutput {
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .coder);
    return readJsonFile(allocator, path, CoderOutput);
}

/// Read a TesterReport from the handoff directory.
pub fn readTesterReport(allocator: std.mem.Allocator, issue_number: u32) !?TesterReport {
    var path_buf: [512]u8 = undefined;
    const path = getArtifactPath(&path_buf, issue_number, .tester);
    return readJsonFile(allocator, path, TesterReport);
}

// =============================================================================
// JSON SERIALIZATION HELPERS
// =============================================================================

fn writeJsonFile(path: []const u8, comptime T: type, value: T) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const w = file.writer();

    try w.writeAll("{\n");
    try writeJsonFields(w, T, value);
    try w.writeAll("}\n");
}

/// Write struct fields as JSON key-value pairs.
fn writeJsonFields(w: anytype, comptime T: type, value: T) !void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        try w.writeAll("  \"");
        try w.writeAll(field.name);
        try w.writeAll("\": ");

        const fv = @field(value, field.name);
        try writeJsonValue(w, field.type, fv);

        if (i < fields.len - 1) {
            try w.writeAll(",\n");
        } else {
            try w.writeByte('\n');
        }
    }
}

/// Write a single JSON value based on its type.
fn writeJsonValue(w: anytype, comptime T: type, value: T) !void {
    if (T == []const u8) {
        try w.writeByte('"');
        try w.writeAll(value);
        try w.writeByte('"');
    } else if (T == bool) {
        try w.writeAll(if (value) "true" else "false");
    } else if (T == u8 or T == u32 or T == u64) {
        try std.fmt.format(w, "{d}", .{value});
    } else if (T == i64) {
        try std.fmt.format(w, "{d}", .{value});
    } else if (T == f64) {
        try std.fmt.format(w, "{d:.4}", .{value});
    } else if (T == []const []const u8) {
        try w.writeByte('[');
        for (value, 0..) |item, idx| {
            try w.writeByte('"');
            try w.writeAll(item);
            try w.writeByte('"');
            if (idx < value.len - 1) try w.writeAll(", ");
        }
        try w.writeByte(']');
    } else if (T == []const BenchmarkEntry) {
        try w.writeByte('[');
        for (value, 0..) |entry, idx| {
            try w.writeAll("{\"name\": \"");
            try w.writeAll(entry.name);
            try w.writeAll("\", \"value\": ");
            try std.fmt.format(w, "{d:.4}", .{entry.value});
            try w.writeAll(", \"unit\": \"");
            try w.writeAll(entry.unit);
            try w.writeAll("\", \"baseline\": ");
            try std.fmt.format(w, "{d:.4}", .{entry.baseline});
            try w.writeAll(", \"delta_pct\": ");
            try std.fmt.format(w, "{d:.4}", .{entry.delta_pct});
            try w.writeByte('}');
            if (idx < value.len - 1) try w.writeAll(", ");
        }
        try w.writeByte(']');
    } else {
        try w.writeAll("null");
    }
}

fn readJsonFile(_: std.mem.Allocator, path: []const u8, comptime T: type) !?T {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    file.close();
    // For now, just check the file exists (reading JSON into typed structs
    // with nested slices requires allocator-managed memory).
    // The write path is the primary interface; reading is for future use.
    return null;
}

// =============================================================================
// HANDOFF STATUS DISPLAY
// =============================================================================

const RESET = "\x1b[0m";
const GREEN = "\x1b[38;2;0;229;153m";
const RED = "\x1b[38;2;239;68;68m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const CYAN = "\x1b[38;2;0;255;255m";
const GRAY = "\x1b[38;2;156;156;160m";

/// Print the handoff status for an issue — which artifacts exist.
pub fn printHandoffStatus(issue_number: u32) void {
    std.debug.print("\n{s}Handoff Status — Issue #{d}{s}\n", .{ GOLDEN, issue_number, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    for (golden_chain.ALL_ROLES) |role| {
        var path_buf: [512]u8 = undefined;
        const path = getArtifactPath(&path_buf, issue_number, role);

        const exists = blk: {
            const f = std.fs.cwd().openFile(path, .{}) catch break :blk false;
            f.close();
            break :blk true;
        };

        const status_sym = if (exists) GREEN ++ "\xe2\x97\x8f" else GRAY ++ "\xe2\x97\x8b";
        std.debug.print("  {s}{s} {s}: {s}{s}\n", .{
            status_sym,
            RESET,
            role.getName(),
            getArtifactFilename(role),
            RESET,
        });
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// TESTS
// =============================================================================

test "getHandoffDir" {
    var buf: [256]u8 = undefined;
    const path = getHandoffDir(&buf, 42);
    try std.testing.expectEqualStrings(".trinity/handoff/issue-42", path);
}

test "getArtifactPath" {
    var buf: [512]u8 = undefined;
    const path = getArtifactPath(&buf, 99, .reviewer);
    try std.testing.expectEqualStrings(".trinity/handoff/issue-99/reviewer_verdict.json", path);
}

test "getArtifactFilename" {
    try std.testing.expectEqualStrings("planner_output.json", getArtifactFilename(.planner));
    try std.testing.expectEqualStrings("coder_output.json", getArtifactFilename(.coder));
    try std.testing.expectEqualStrings("reviewer_verdict.json", getArtifactFilename(.reviewer));
    try std.testing.expectEqualStrings("tester_report.json", getArtifactFilename(.tester));
    try std.testing.expectEqualStrings("integrator_summary.json", getArtifactFilename(.integrator));
}
