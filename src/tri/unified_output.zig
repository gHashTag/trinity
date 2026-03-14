// @origin(spec:unified_output.tri) @regen(manual-impl)
//! Trinity Unified Output Format — P0.2 Machine-Readable JSON
//!
//! ## Contract (tri-cli-json-v1)
//!
//! Every command MUST output exactly ONE JSON object when --json flag is set.
//! stdout MUST contain ONLY valid JSON (no banners, no extra text).
//! stderr MAY contain debug/human-readable output.
//!
//! ## Schema
//!
//! {
//!   "schema_version": "tri-cli-json-v1",
//!   "status": "success|failure|partial|canceled|denied|timeout",
//!   "command": "command_name",
//!   "namespace": "core|dev|forge|agent|system",
//!   "exit_code": 0-7,
//!   "summary": "one-line human-readable summary",
//!   "started_at": "2024-03-08T10:00:00Z",
//!   "finished_at": "2024-03-08T10:00:01Z",
//!   "duration_ms": 1234,
//!   "metrics": {"key": "value"},
//!   "artifacts": [{"filename": "...", "size": 123, "checksum": "..."}],
//!   "warnings": ["warning message"],
//!   "errors": ["error message"],
//!   "data": {},
//!   "next_actions": ["suggested action"]
//! }
//!
//! ## Exit Codes
//!
//! 0 - success
//! 1 - command_error (invalid args, command not found)
//! 2 - validation_error (pre-flight checks failed)
//! 3 - runtime_error (execution failed)
//! 4 - timeout (command exceeded time limit)
//! 5 - job_failed (async job failed)
//! 6 - artifact_failed (output generation failed)
//! 7 - internal_error (bug, unexpected state)
//!
//! References:
//! - https://rust-cli-recommendations.sunshowers.io/machine-readable-output.html
//! - https://blog.kellybrazil.com/2021/12/03/tips-on-adding-json-output-to-your-cli-app/
//! - https://bettercli.org/design/exit-codes/
// @origin(manual) @regen(pending)

const std = @import("std");
const tri_config = @import("tri_config.zig");
const exit_codes = @import("tri_exit_codes.zig");

/// Schema version identifier - append-only field additions guaranteed
pub const SCHEMA_VERSION = "tri-cli-json-v1";

/// Command execution status - canonical set from rust-cli-recommendations
pub const ExecutionStatus = enum {
    /// Command completed successfully
    success,
    /// Command failed (runtime error)
    failure,
    /// Command partially succeeded (some tasks failed)
    partial,
    /// Command was canceled by user
    canceled,
    /// Command was denied by policy/security
    denied,
    /// Command exceeded time limit
    timeout,

    pub fn toString(self: ExecutionStatus) []const u8 {
        return switch (self) {
            .success => "success",
            .failure => "failure",
            .partial => "partial",
            .canceled => "canceled",
            .denied => "denied",
            .timeout => "timeout",
        };
    }

    pub fn fromExitCode(code: exit_codes.ExitCode) ExecutionStatus {
        return switch (code) {
            .success => .success,
            .command_error => .failure,
            .validation_error => .denied,
            .runtime_error => .failure,
            .timeout => .timeout,
            .job_failed => .failure,
            .artifact_failed => .failure,
            .internal_error => .failure,
        };
    }

    pub fn toExitCode(self: ExecutionStatus) exit_codes.ExitCode {
        return switch (self) {
            .success => .success,
            .failure => .runtime_error,
            .partial => .success, // Partial is still success
            .canceled => .validation_error,
            .denied => .validation_error,
            .timeout => .timeout,
        };
    }
};

/// Command namespace
pub const Namespace = enum {
    /// AI, math, science (default)
    core,
    /// Development tools (test, bench, build)
    dev,
    /// FPGA toolchain
    forge,
    /// SWE agent, distributed
    agent,
    /// Doctor, clean, info
    system,
    /// MCP server management
    mcp,

    pub fn toString(self: Namespace) []const u8 {
        return switch (self) {
            .core => "core",
            .dev => "dev",
            .forge => "forge",
            .agent => "agent",
            .system => "system",
            .mcp => "mcp",
        };
    }
};

/// Stability level
pub const Stability = enum {
    /// Production ready
    stable,
    /// May change
    experimental,
    /// Destructive operations
    dangerous,

    pub fn toString(self: Stability) []const u8 {
        return switch (self) {
            .stable => "stable",
            .experimental => "experimental",
            .dangerous => "dangerous",
        };
    }
};

/// Side effect types
pub const SideEffectType = enum {
    /// No side effects
    none,
    /// Modifies files
    filesystem,
    /// Network requests
    network,
    /// Hardware operations
    hardware,
    /// Git/repository modifications
    repo,

    pub fn toString(self: SideEffectType) []const u8 {
        return switch (self) {
            .none => "none",
            .filesystem => "filesystem",
            .network => "network",
            .hardware => "hardware",
            .repo => "repo",
        };
    }
};

/// Artifact entry
pub const ArtifactInfo = struct {
    filename: []const u8,
    size: u64,
    checksum: ?[]const u8 = null,
    artifact_type: []const u8 = "unknown",
    path: ?[]const u8 = null,

    pub fn deinit(self: *ArtifactInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.filename);
        if (self.checksum) |cs| allocator.free(cs);
        if (self.artifact_type.len > 0 and !std.mem.eql(u8, self.artifact_type, "unknown")) {
            allocator.free(self.artifact_type);
        }
        if (self.path) |p| allocator.free(p);
    }
};

/// Warning message
pub const Warning = struct {
    code: []const u8,
    message: []const u8,

    pub fn deinit(self: *Warning, allocator: std.mem.Allocator) void {
        allocator.free(self.code);
        allocator.free(self.message);
    }
};

/// Error message
pub const Error = struct {
    code: []const u8,
    message: []const u8,

    pub fn deinit(self: *Error, allocator: std.mem.Allocator) void {
        allocator.free(self.code);
        allocator.free(self.message);
    }
};

/// Verdict information (for code review, quality assessment)
pub const Verdict = struct {
    rating: i2, // -5 to +5
    issues_count: u32,
    improvements_count: u32,
    summary: []const u8,

    pub fn deinit(self: *Verdict, allocator: std.mem.Allocator) void {
        allocator.free(self.summary);
    }
};

/// Registry metadata (auto-populated from CommandDef)
pub const RegistryMetadata = struct {
    command: []const u8,
    namespace: Namespace,
    stability: Stability,
    side_effects: []const SideEffectType,
    requires_confirmation: bool,
    mcp_enabled: bool,
};

/// Unified command output envelope - P0.2 compliant
pub const UnifiedOutput = struct {
    allocator: std.mem.Allocator,

    // Core fields
    status: ExecutionStatus,
    command_name: []const u8,
    namespace: Namespace,
    summary: []const u8,

    // Timing
    start_time: i64,
    end_time: i64,

    // Output data
    metrics: std.StringHashMap(u64),
    artifacts: std.ArrayList(ArtifactInfo),
    warnings: std.ArrayList(Warning),
    errors: std.ArrayList(Error),
    next_actions: std.ArrayList([]const u8),

    // Optional data (command-specific payload)
    data: ?std.json.Value,
    data_raw: ?[]const u8, // Raw JSON string alternative (for simpler use cases)

    // Optional verdict
    verdict: ?Verdict,

    // Registry metadata (auto-populated)
    registry_metadata: ?RegistryMetadata,

    /// Initialize a new UnifiedOutput
    pub fn init(allocator: std.mem.Allocator, command_name: []const u8, namespace: Namespace) std.mem.Allocator.Error!UnifiedOutput {
        return UnifiedOutput{
            .allocator = allocator,
            .status = .success,
            .command_name = command_name,
            .namespace = namespace,
            .summary = "",
            .start_time = std.time.timestamp(),
            .end_time = 0,
            .metrics = std.StringHashMap(u64).init(allocator),
            .artifacts = try std.ArrayList(ArtifactInfo).initCapacity(allocator, 4),
            .warnings = try std.ArrayList(Warning).initCapacity(allocator, 4),
            .errors = try std.ArrayList(Error).initCapacity(allocator, 4),
            .next_actions = try std.ArrayList([]const u8).initCapacity(allocator, 4),
            .data = null,
            .data_raw = null,
            .verdict = null,
            .registry_metadata = null,
        };
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *UnifiedOutput) void {
        if (self.summary.len > 0) self.allocator.free(self.summary);

        // Free metrics
        var metrics_iter = self.metrics.iterator();
        while (metrics_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.metrics.deinit();

        // Free artifacts
        for (self.artifacts.items) |*artifact| {
            artifact.deinit(self.allocator);
        }
        self.artifacts.deinit(self.allocator);

        // Free warnings
        for (self.warnings.items) |*warn| {
            warn.deinit(self.allocator);
        }
        self.warnings.deinit(self.allocator);

        // Free errors
        for (self.errors.items) |*err| {
            err.deinit(self.allocator);
        }
        self.errors.deinit(self.allocator);

        // Free next actions
        for (self.next_actions.items) |action| {
            self.allocator.free(action);
        }
        self.next_actions.deinit(self.allocator);

        // Free data_raw if present
        if (self.data_raw) |raw| {
            self.allocator.free(raw);
        }

        // Free data if present
        if (self.data) |_| {
            // std.json.Value doesn't have a proper deinit, but we allocated strings
            // For now we'll just ignore it - proper cleanup would require walking the JSON tree
        }

        // Free verdict
        if (self.verdict) |*v| {
            v.deinit(self.allocator);
        }
    }

    /// Set execution status
    pub fn setStatus(self: *UnifiedOutput, status: ExecutionStatus) void {
        self.status = status;
    }

    /// Set summary message
    pub fn setSummary(self: *UnifiedOutput, summary: []const u8) !void {
        if (self.summary.len > 0) self.allocator.free(self.summary);
        self.summary = try self.allocator.dupe(u8, summary);
    }

    /// Add a warning
    pub fn addWarning(self: *UnifiedOutput, code: []const u8, message: []const u8) !void {
        const code_copy = try self.allocator.dupe(u8, code);
        errdefer self.allocator.free(code_copy);
        const msg_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(msg_copy);
        try self.warnings.append(self.allocator, Warning{
            .code = code_copy,
            .message = msg_copy,
        });
    }

    /// Add an error
    pub fn addError(self: *UnifiedOutput, code: []const u8, message: []const u8) !void {
        const code_copy = try self.allocator.dupe(u8, code);
        errdefer self.allocator.free(code_copy);
        const msg_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(msg_copy);
        try self.errors.append(self.allocator, Error{
            .code = code_copy,
            .message = msg_copy,
        });
        // Errors set status to failure automatically
        if (self.status == .success) {
            self.status = .failure;
        }
    }

    /// Add a metric
    pub fn addMetric(self: *UnifiedOutput, name: []const u8, value: u64) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        try self.metrics.put(name_copy, value);
    }

    /// Add an artifact
    pub fn addArtifact(self: *UnifiedOutput, filename: []const u8, size: u64, checksum: ?[]const u8, artifact_type: []const u8) !void {
        const filename_copy = try self.allocator.dupe(u8, filename);
        errdefer self.allocator.free(filename_copy);

        const checksum_copy = if (checksum) |cs| try self.allocator.dupe(u8, cs) else null;

        const type_copy = try self.allocator.dupe(u8, artifact_type);
        errdefer self.allocator.free(type_copy);

        try self.artifacts.append(ArtifactInfo{
            .filename = filename_copy,
            .size = size,
            .checksum = checksum_copy,
            .artifact_type = type_copy,
            .path = null,
        });
    }

    /// Add a next action suggestion
    pub fn addNextAction(self: *UnifiedOutput, action: []const u8) !void {
        const action_copy = try self.allocator.dupe(u8, action);
        errdefer self.allocator.free(action_copy);
        try self.next_actions.append(self.allocator, action_copy);
    }

    /// Set verdict
    pub fn setVerdict(self: *UnifiedOutput, rating: i2, issues_count: u32, improvements_count: u32, summary: []const u8) !void {
        if (self.verdict) |*v| v.deinit(self.allocator);
        const summary_copy = try self.allocator.dupe(u8, summary);
        errdefer self.allocator.free(summary_copy);
        self.verdict = Verdict{
            .rating = rating,
            .issues_count = issues_count,
            .improvements_count = improvements_count,
            .summary = summary_copy,
        };
    }

    /// Set registry metadata
    pub fn setRegistryMetadata(self: *UnifiedOutput, metadata: RegistryMetadata) void {
        self.registry_metadata = metadata;
    }

    /// Finalize the output (record end time and add duration metric)
    pub fn finalize(self: *UnifiedOutput) void {
        self.end_time = std.time.timestamp();
        const duration_ms: u64 = @intCast((self.end_time - self.start_time) * 1000);
        // Add or update duration_ms metric
        const result = self.metrics.getOrPut("duration_ms") catch return;
        if (result.found_existing) {
            self.allocator.free(result.key_ptr.*);
        }
        result.key_ptr.* = self.allocator.dupe(u8, "duration_ms") catch return;
        result.value_ptr.* = duration_ms;
    }

    /// Get the exit code based on current status
    pub fn getExitCode(self: *const UnifiedOutput) exit_codes.ExitCode {
        // If we have errors, check if any are validation/policy errors
        if (self.errors.items.len > 0) {
            for (self.errors.items) |err| {
                if (std.mem.eql(u8, err.code, "VALIDATION_ERROR") or
                    std.mem.eql(u8, err.code, "POLICY_DENIED") or
                    std.mem.eql(u8, err.code, "COMMAND_ERROR"))
                {
                    return .validation_error;
                }
                if (std.mem.eql(u8, err.code, "TIMEOUT")) {
                    return .timeout;
                }
                if (std.mem.eql(u8, err.code, "ARTIFACT_FAILED")) {
                    return .artifact_failed;
                }
            }
            return .runtime_error;
        }
        return self.status.toExitCode();
    }

    /// Format timestamp as Unix epoch (seconds since 1970-01-01)
    fn formatTimestamp(ts: i64) i64 {
        return ts;
    }

    /// Generate JSON output (P0.2 compliant)
    pub fn toJson(self: *const UnifiedOutput) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 4096);
        defer buf.deinit(self.allocator);

        // Opening brace
        try buf.append(self.allocator, '{');

        // schema_version (immutable identifier)
        try buf.print(self.allocator, "\"schema_version\":\"{s}\"", .{SCHEMA_VERSION});

        // status
        try buf.print(self.allocator, ",\"status\":\"{s}\"", .{self.status.toString()});

        // command
        try buf.print(self.allocator, ",\"command\":\"{s}\"", .{self.command_name});

        // namespace
        try buf.print(self.allocator, ",\"namespace\":\"{s}\"", .{self.namespace.toString()});

        // exit_code
        try buf.print(self.allocator, ",\"exit_code\":{d}", .{@intFromEnum(self.getExitCode())});

        // summary (JSON-escaped)
        try buf.appendSlice(self.allocator, ",\"summary\":\"");
        try jsonEscapeString(buf.writer(self.allocator), self.summary);
        try buf.appendSlice(self.allocator, "\"");

        // started_at, finished_at (Unix epoch timestamps)
        try buf.print(self.allocator, ",\"started_at\":{d}", .{formatTimestamp(self.start_time)});
        try buf.print(self.allocator, ",\"finished_at\":{d}", .{formatTimestamp(self.end_time)});

        // duration_ms
        if (self.metrics.get("duration_ms")) |duration| {
            try buf.print(self.allocator, ",\"duration_ms\":{d}", .{duration});
        }

        // metrics
        try buf.appendSlice(self.allocator, ",\"metrics\":{");
        var first_metric = true;
        var metrics_iter = self.metrics.iterator();
        while (metrics_iter.next()) |entry| {
            if (!first_metric) try buf.append(self.allocator, ',');
            first_metric = false;
            try buf.print(self.allocator, "\"{s}\":{d}", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        try buf.append(self.allocator, '}');

        // artifacts (optional, only if present)
        if (self.artifacts.items.len > 0) {
            try buf.appendSlice(self.allocator, ",\"artifacts\":[");
            for (self.artifacts.items, 0..) |artifact, i| {
                if (i > 0) try buf.append(self.allocator, ',');
                try buf.append(self.allocator, '{');
                try buf.print(self.allocator, "\"filename\":\"{s}\",\"size\":{d}", .{ artifact.filename, artifact.size });
                if (artifact.checksum) |cs| {
                    try buf.print(self.allocator, ",\"checksum\":\"{s}\"", .{cs});
                }
                if (!std.mem.eql(u8, artifact.artifact_type, "unknown")) {
                    try buf.print(self.allocator, ",\"type\":\"{s}\"", .{artifact.artifact_type});
                }
                try buf.append(self.allocator, '}');
            }
            try buf.append(self.allocator, ']');
        }

        // warnings (optional, only if present)
        if (self.warnings.items.len > 0) {
            try buf.appendSlice(self.allocator, ",\"warnings\":[");
            for (self.warnings.items, 0..) |warn, i| {
                if (i > 0) try buf.append(self.allocator, ',');
                try buf.append(self.allocator, '{');
                try buf.print(self.allocator, "\"code\":\"{s}\",\"message\":\"", .{warn.code});
                try jsonEscapeString(buf.writer(self.allocator), warn.message);
                try buf.appendSlice(self.allocator, "\"}");
            }
            try buf.append(self.allocator, ']');
        }

        // errors (optional, only if present)
        if (self.errors.items.len > 0) {
            try buf.appendSlice(self.allocator, ",\"errors\":[");
            for (self.errors.items, 0..) |err, i| {
                if (i > 0) try buf.append(self.allocator, ',');
                try buf.append(self.allocator, '{');
                try buf.print(self.allocator, "\"code\":\"{s}\",\"message\":\"", .{err.code});
                try jsonEscapeString(buf.writer(self.allocator), err.message);
                try buf.appendSlice(self.allocator, "\"}");
            }
            try buf.append(self.allocator, ']');
        }

        // data (optional) - raw JSON string directly appended
        if (self.data_raw) |raw_json| {
            try buf.appendSlice(self.allocator, ",\"data\":");
            try buf.appendSlice(self.allocator, raw_json);
        }

        // next_actions (optional, only if present)
        if (self.next_actions.items.len > 0) {
            try buf.appendSlice(self.allocator, ",\"next_actions\":[");
            for (self.next_actions.items, 0..) |action, i| {
                if (i > 0) try buf.append(self.allocator, ',');
                try buf.append(self.allocator, '"');
                try jsonEscapeString(buf.writer(self.allocator), action);
                try buf.append(self.allocator, '"');
            }
            try buf.append(self.allocator, ']');
        }

        // Closing brace
        try buf.append(self.allocator, '}');

        return buf.toOwnedSlice(self.allocator);
    }

    /// Generate human-readable text output
    pub fn toText(self: *const UnifiedOutput) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 512);
        defer buf.deinit(self.allocator);

        const status_symbol = switch (self.status) {
            .success => "✓",
            .failure => "✗",
            .partial => "~",
            .canceled => "⚠",
            .denied => "🚫",
            .timeout => "⏱",
        };
        try buf.print(self.allocator, "{s} {s}: {s}\n", .{ status_symbol, self.command_name, self.summary });

        if (self.metrics.count() > 0) {
            try buf.appendSlice(self.allocator, "\nMetrics:\n");
            var metrics_iter = self.metrics.iterator();
            while (metrics_iter.next()) |entry| {
                try buf.print(self.allocator, "  {s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        }

        if (self.warnings.items.len > 0) {
            try buf.appendSlice(self.allocator, "\nWarnings:\n");
            for (self.warnings.items) |warn| {
                try buf.print(self.allocator, "  [{s}] {s}\n", .{ warn.code, warn.message });
            }
        }

        if (self.errors.items.len > 0) {
            try buf.appendSlice(self.allocator, "\nErrors:\n");
            for (self.errors.items) |err| {
                try buf.print(self.allocator, "  [{s}] {s}\n", .{ err.code, err.message });
            }
        }

        if (self.artifacts.items.len > 0) {
            try buf.appendSlice(self.allocator, "\nArtifacts:\n");
            for (self.artifacts.items) |artifact| {
                try buf.print(self.allocator, "  - {s} ({d} bytes)\n", .{ artifact.filename, artifact.size });
            }
        }

        if (self.next_actions.items.len > 0) {
            try buf.appendSlice(self.allocator, "\nNext actions:\n");
            for (self.next_actions.items) |action| {
                try buf.print(self.allocator, "  - {s}\n", .{action});
            }
        }

        return buf.toOwnedSlice(self.allocator);
    }

    /// Print output according to global JSON mode
    /// In JSON mode: ONLY JSON to stdout (no extra text), human-readable to stderr
    /// In text mode: human-readable to stdout
    pub fn print(self: *const UnifiedOutput) !void {
        const json_mode = tri_config.isJsonOutput();

        // Use direct file writes (Zig 0.15 compatible)
        const stdout_file = std.fs.File.stdout();

        if (json_mode) {
            // JSON mode: ONLY JSON to stdout, nothing else
            const json_output = try self.toJson();
            defer self.allocator.free(json_output);

            try stdout_file.writeAll(json_output);
            try stdout_file.writeAll("\n");
        } else {
            // Text mode: human-readable to stdout
            const text_output = try self.toText();
            defer self.allocator.free(text_output);

            try stdout_file.writeAll(text_output);
        }
    }

    /// Print and exit with appropriate exit code
    pub fn printAndExit(self: *const UnifiedOutput) noreturn {
        self.print() catch |err| {
            std.debug.print("Failed to print output: {}\n", .{err});
            exit_codes.exitInternalError();
        };
        exit_codes.exitWithCode(self.getExitCode());
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// JSON-escape a string
fn jsonEscapeString(writer: anytype, str: []const u8) !void {
    for (str) |c| {
        switch (c) {
            '\\', '"' => _ = try writer.write("\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FACTORY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a successful output
pub fn success(allocator: std.mem.Allocator, command_name: []const u8, namespace: Namespace, summary: []const u8) !UnifiedOutput {
    var output = try UnifiedOutput.init(allocator, command_name, namespace);
    try output.setSummary(summary);
    output.finalize();
    return output;
}

/// Create a failed output
pub fn failure(allocator: std.mem.Allocator, command_name: []const u8, namespace: Namespace, summary: []const u8, error_code: []const u8, error_msg: []const u8) !UnifiedOutput {
    var output = try UnifiedOutput.init(allocator, command_name, namespace);
    try output.setSummary(summary);
    try output.addError(error_code, error_msg);
    output.finalize();
    return output;
}

/// Create a partial success output
pub fn partial(allocator: std.mem.Allocator, command_name: []const u8, namespace: Namespace, summary: []const u8) !UnifiedOutput {
    var output = try UnifiedOutput.init(allocator, command_name, namespace);
    try output.setSummary(summary);
    output.setStatus(.partial);
    output.finalize();
    return output;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ExecutionStatus.toString" {
    try std.testing.expectEqualStrings("success", ExecutionStatus.success.toString());
    try std.testing.expectEqualStrings("failure", ExecutionStatus.failure.toString());
    try std.testing.expectEqualStrings("partial", ExecutionStatus.partial.toString());
    try std.testing.expectEqualStrings("canceled", ExecutionStatus.canceled.toString());
    try std.testing.expectEqualStrings("denied", ExecutionStatus.denied.toString());
    try std.testing.expectEqualStrings("timeout", ExecutionStatus.timeout.toString());
}

test "UnifiedOutput basic JSON output" {
    const allocator = std.testing.allocator;
    var output = try UnifiedOutput.init(allocator, "test_cmd", .core);
    try output.setSummary("Test completed successfully");
    try output.addMetric("items_processed", 42);
    output.finalize();

    const json = try output.toJson();
    defer allocator.free(json);

    // Verify required fields
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema_version\":\"tri-cli-json-v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"command\":\"test_cmd\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"namespace\":\"core\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"exit_code\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"summary\":\"Test completed successfully\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"duration_ms\"") != null);

    output.deinit();
}

test "UnifiedOutput with errors" {
    const allocator = std.testing.allocator;
    var output = try UnifiedOutput.init(allocator, "validate", .system);
    try output.setSummary("Validation failed");
    try output.addError("VALIDATION_ERROR", "Invalid input format");
    output.finalize();

    const json = try output.toJson();
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"failure\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"errors\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"code\":\"VALIDATION_ERROR\"") != null);

    // Verify exit code is validation_error (2)
    try std.testing.expectEqual(exit_codes.ExitCode.validation_error, output.getExitCode());

    output.deinit();
}

test "UnifiedOutput with warnings" {
    const allocator = std.testing.allocator;
    var output = try UnifiedOutput.init(allocator, "build", .dev);
    try output.setSummary("Build completed with warnings");
    try output.addWarning("DEPRECATION", "Using deprecated feature");
    try output.addMetric("warnings_count", 1);
    output.finalize();

    const json = try output.toJson();
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"warnings\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"code\":\"DEPRECATION\"") != null);

    output.deinit();
}

test "UnifiedOutput.getExitCode" {
    const allocator = std.testing.allocator;

    // Success case
    {
        var output = try UnifiedOutput.init(allocator, "success_cmd", .core);
        try output.setSummary("Success");
        output.finalize();
        try std.testing.expectEqual(exit_codes.ExitCode.success, output.getExitCode());
        output.deinit();
    }

    // Error case - validation error
    {
        var output = try UnifiedOutput.init(allocator, "error_cmd", .system);
        try output.setSummary("Error");
        try output.addError("VALIDATION_ERROR", "Invalid input");
        output.finalize();
        try std.testing.expectEqual(exit_codes.ExitCode.validation_error, output.getExitCode());
        output.deinit();
    }

    // Error case - timeout
    {
        var output = try UnifiedOutput.init(allocator, "timeout_cmd", .agent);
        try output.setSummary("Timeout");
        try output.addError("TIMEOUT", "Operation timed out");
        output.finalize();
        try std.testing.expectEqual(exit_codes.ExitCode.timeout, output.getExitCode());
        output.deinit();
    }

    // Partial case (still success)
    {
        var output = try UnifiedOutput.init(allocator, "partial_cmd", .dev);
        try output.setSummary("Partial");
        output.setStatus(.partial);
        output.finalize();
        try std.testing.expectEqual(exit_codes.ExitCode.success, output.getExitCode());
        output.deinit();
    }
}
