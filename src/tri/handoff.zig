// @origin(manual) @regen(pending)
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
    cost_tokens_in: u64 = 0,
    cost_tokens_out: u64 = 0,
    cost_usd: f64 = 0.0,
};

pub const CoderOutput = struct {
    issue_number: u32,
    branch: []const u8,
    files_modified: []const []const u8,
    commits: []const []const u8,
    lines_added: u32,
    lines_removed: u32,
    timestamp: i64,
    cost_tokens_in: u64 = 0,
    cost_tokens_out: u64 = 0,
    cost_usd: f64 = 0.0,
};

pub const ReviewerVerdict = struct {
    issue_number: u32,
    approved: bool,
    feedback: []const []const u8,
    iteration: u8,
    max_iterations: u8,
    files_reviewed: []const []const u8,
    timestamp: i64,
    cost_tokens_in: u64 = 0,
    cost_tokens_out: u64 = 0,
    cost_usd: f64 = 0.0,
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
    cost_tokens_in: u64 = 0,
    cost_tokens_out: u64 = 0,
    cost_usd: f64 = 0.0,
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
// HANDOFF VALIDATION — v5.1
// =============================================================================

pub const HandoffError = error{
    MissingSubtasks,
    InvalidTimestamp,
    EmptyBranch,
    EmptyApproach,
    InvalidIteration,
    NoTestResults,
    OutOfMemory,
    NameTooLong,
    FileNotFound,
    AccessDenied,
    Unexpected,
    SystemResources,
    IsDir,
    WouldBlock,
    FileBusy,
    PermissionDenied,
    InputOutput,
    BrokenPipe,
    InvalidArgument,
    OperationAborted,
    Unseekable,
    ConnectionResetByPeer,
    ConnectionTimedOut,
    NotOpenForWriting,
    LockViolation,
    NoSpaceLeft,
    DiskQuota,
    FileTooBig,
    DeviceBusy,
    NoDevice,
};

/// Validate a PlannerOutput before writing.
pub fn validatePlannerOutput(output: PlannerOutput) HandoffError!void {
    if (output.timestamp <= 0) return HandoffError.InvalidTimestamp;
    if (output.approach.len == 0) return HandoffError.EmptyApproach;
}

/// Validate a CoderOutput before writing.
pub fn validateCoderOutput(output: CoderOutput) HandoffError!void {
    if (output.timestamp <= 0) return HandoffError.InvalidTimestamp;
}

/// Validate a ReviewerVerdict before writing.
pub fn validateReviewerVerdict(verdict: ReviewerVerdict) HandoffError!void {
    if (verdict.timestamp <= 0) return HandoffError.InvalidTimestamp;
    if (verdict.iteration == 0 or verdict.iteration > verdict.max_iterations)
        return HandoffError.InvalidIteration;
}

/// Validate a TesterReport before writing.
pub fn validateTesterReport(report: TesterReport) HandoffError!void {
    if (report.timestamp <= 0) return HandoffError.InvalidTimestamp;
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

/// Write a JSON-escaped string (handles quotes, backslashes, control chars).
fn writeJsonEscapedStr(w: anytype, str: []const u8) !void {
    try w.writeByte('"');
    for (str) |c| switch (c) {
        '"' => try w.writeAll("\\\""),
        '\\' => try w.writeAll("\\\\"),
        '\n' => try w.writeAll("\\n"),
        '\r' => try w.writeAll("\\r"),
        '\t' => try w.writeAll("\\t"),
        0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => {
            const hex = "0123456789abcdef";
            try w.writeAll("\\u00");
            try w.writeByte(hex[c >> 4]);
            try w.writeByte(hex[c & 0x0f]);
        },
        else => try w.writeByte(c),
    };
    try w.writeByte('"');
}

/// Write a single JSON value based on its type.
fn writeJsonValue(w: anytype, comptime T: type, value: T) !void {
    if (T == []const u8) {
        try writeJsonEscapedStr(w, value);
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
            try writeJsonEscapedStr(w, item);
            if (idx < value.len - 1) try w.writeAll(", ");
        }
        try w.writeByte(']');
    } else if (T == []const BenchmarkEntry) {
        try w.writeByte('[');
        for (value, 0..) |entry, idx| {
            try w.writeAll("{\"name\": ");
            try writeJsonEscapedStr(w, entry.name);
            try w.writeAll(", \"value\": ");
            try std.fmt.format(w, "{d:.4}", .{entry.value});
            try w.writeAll(", \"unit\": ");
            try writeJsonEscapedStr(w, entry.unit);
            try w.writeAll(", \"baseline\": ");
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

fn readJsonFile(allocator: std.mem.Allocator, path: []const u8, comptime T: type) !?T {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 256 * 1024) catch |err| {
        std.debug.print("warn: failed to read {s}: {}\n", .{ path, err });
        return null;
    };
    defer allocator.free(content);

    const parsed = std.json.parseFromSlice(T, allocator, content, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.debug.print("warn: json parse error in {s}: {}\n", .{ path, err });
        return null;
    };

    // Note: caller must manage parsed.value lifetime. For now, copy scalar fields.
    // Slice fields ([]const u8, []const []const u8) point into parsed arena.
    // We return the parsed value — caller should use it immediately or dupe needed fields.
    // Note: we intentionally skip parsed.deinit() so pointers into the arena stay valid.
    // Caller should use the value immediately or dupe needed fields.
    return parsed.value;
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

test "validatePlannerOutput rejects empty approach" {
    const bad = PlannerOutput{
        .issue_number = 1,
        .subtasks = &.{},
        .files = &.{},
        .approach = "",
        .spec_path = "",
        .timestamp = 100,
    };
    try std.testing.expectError(HandoffError.EmptyApproach, validatePlannerOutput(bad));
}

test "validatePlannerOutput rejects invalid timestamp" {
    const bad = PlannerOutput{
        .issue_number = 1,
        .subtasks = &.{},
        .files = &.{},
        .approach = "test",
        .spec_path = "",
        .timestamp = 0,
    };
    try std.testing.expectError(HandoffError.InvalidTimestamp, validatePlannerOutput(bad));
}

test "validateReviewerVerdict rejects invalid iteration" {
    const bad = ReviewerVerdict{
        .issue_number = 1,
        .approved = true,
        .feedback = &.{},
        .iteration = 0,
        .max_iterations = 3,
        .files_reviewed = &.{},
        .timestamp = 100,
    };
    try std.testing.expectError(HandoffError.InvalidIteration, validateReviewerVerdict(bad));
}

test "validatePlannerOutput accepts valid" {
    const good = PlannerOutput{
        .issue_number = 1,
        .subtasks = &.{},
        .files = &.{},
        .approach = "implement feature",
        .spec_path = "specs/tri/test.tri",
        .timestamp = 1000,
    };
    try validatePlannerOutput(good);
}
