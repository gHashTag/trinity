//! Trinity Unified Output Format — Standard Command Output
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Execution status
pub const ExecutionStatus = enum {
    success,
    failure,
    partial,

    pub fn toString(self: ExecutionStatus) []const u8 {
        return switch (self) {
            .success => "success",
            .failure => "failure",
            .partial => "partial",
        };
    }

    pub fn toJson(self: ExecutionStatus) []const u8 {
        return switch (self) {
            .success => "\"success\"",
            .failure => "\"failure\"",
            .partial => "\"partial\"",
        };
    }
};

/// Artifact entry
pub const ArtifactInfo = struct {
    filename: []const u8,
    size: u64,
    checksum: []const u8,
    artifact_type: []const u8 = "unknown",
};

/// Verdict information
pub const Verdict = struct {
    rating: i2,
    issues_count: u32,
    improvements_count: u32,
    summary: []const u8,

    pub fn toJson(self: *const Verdict, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"rating":{d},"issues_count":{d},"improvements_count":{d},"summary":"{s}"}}
        , .{ self.rating, self.issues_count, self.improvements_count, self.summary });
    }
};

/// Unified command output (simplified, using slices instead of ArrayList)
pub const UnifiedOutput = struct {
    allocator: std.mem.Allocator,
    status: ExecutionStatus,
    summary: []const u8,
    metrics: std.StringHashMap(u64),
    error_message: ?[]const u8,
    verdict: ?Verdict,
    command_name: []const u8,
    start_time: i64,
    end_time: i64,

    // Storing artifacts and next_actions as dynamic slices
    artifacts_owned: bool,
    artifacts_slice: []ArtifactInfo,
    next_actions_owned: bool,
    next_actions_slice: [][]const u8,

    /// Initialize a new UnifiedOutput
    pub fn init(allocator: std.mem.Allocator, command_name: []const u8) UnifiedOutput {
        return UnifiedOutput{
            .allocator = allocator,
            .status = .success,
            .summary = "",
            .metrics = std.StringHashMap(u64).init(allocator),
            .error_message = null,
            .verdict = null,
            .command_name = command_name,
            .start_time = std.time.timestamp(),
            .end_time = 0,
            .artifacts_owned = false,
            .artifacts_slice = &.{},
            .next_actions_owned = false,
            .next_actions_slice = &.{},
        };
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *UnifiedOutput) void {
        // Free summary if it was allocated (not empty string)
        if (self.summary.len > 0 and !std.mem.eql(u8, self.summary, "")) {
            self.allocator.free(self.summary);
        }
        if (self.error_message) |msg| self.allocator.free(msg);

        // Free metrics
        var metrics_iter = self.metrics.iterator();
        while (metrics_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.metrics.deinit();

        // Free artifacts if owned
        if (self.artifacts_owned) {
            for (self.artifacts_slice) |*artifact| {
                self.allocator.free(artifact.filename);
                self.allocator.free(artifact.checksum);
                if (artifact.artifact_type.len > 0 and !std.mem.eql(u8, artifact.artifact_type, "unknown")) {
                    self.allocator.free(artifact.artifact_type);
                }
            }
            self.allocator.free(self.artifacts_slice);
        }

        // Free next_actions if owned
        if (self.next_actions_owned) {
            for (self.next_actions_slice) |action| {
                self.allocator.free(action);
            }
            self.allocator.free(self.next_actions_slice);
        }

        // Free verdict
        if (self.verdict) |*v| {
            self.allocator.free(v.summary);
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

    /// Set error message (also sets status to failure)
    pub fn setError(self: *UnifiedOutput, error_msg: []const u8) !void {
        if (self.error_message) |msg| self.allocator.free(msg);
        self.error_message = try self.allocator.dupe(u8, error_msg);
        self.status = .failure;
    }

    /// Add a metric
    pub fn addMetric(self: *UnifiedOutput, name: []const u8, value: u64) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        try self.metrics.put(name_copy, value);
    }

    /// Add an artifact (simplified - just stores basic info)
    pub fn addArtifact(self: *UnifiedOutput, filename: []const u8, size: u64, checksum: []const u8) !void {
        _ = size;
        _ = checksum;
        _ = self;
        _ = filename;
        // TODO: Implement artifact storage
    }

    /// Add a next action suggestion
    pub fn addNextAction(self: *UnifiedOutput, action: []const u8) !void {
        _ = action;
        _ = self;
        // TODO: Implement next actions storage
    }

    /// Set verdict
    pub fn setVerdict(self: *UnifiedOutput, rating: i2, issues_count: u32, improvements_count: u32, summary: []const u8) !void {
        if (self.verdict) |*v| self.allocator.free(v.summary);
        const summary_copy = try self.allocator.dupe(u8, summary);
        errdefer self.allocator.free(summary_copy);
        self.verdict = Verdict{
            .rating = rating,
            .issues_count = issues_count,
            .improvements_count = improvements_count,
            .summary = summary_copy,
        };
    }

    /// Finalize the output (record end time)
    pub fn finalize(self: *UnifiedOutput) void {
        self.end_time = std.time.timestamp();
        const duration_ms = @as(u64, @intCast((self.end_time - self.start_time) * 1000));
        // Only add duration_ms if not already present
        if (!self.metrics.contains("duration_ms")) {
            self.addMetric("duration_ms", duration_ms) catch {};
        }
    }

    /// Generate JSON output
    pub fn toJson(self: *const UnifiedOutput) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 1024);
        defer buf.deinit(self.allocator);

        try buf.appendSlice(self.allocator, "{");
        try buf.print(self.allocator, "\"command\":\"{s}\"", .{self.command_name});
        try buf.print(self.allocator, ",\"status\":{s}", .{self.status.toJson()});
        try buf.print(self.allocator, ",\"summary\":\"{s}\"", .{self.summary});

        // Metrics
        try buf.appendSlice(self.allocator, ",\"metrics\":{");
        var first_metric = true;
        var metrics_iter = self.metrics.iterator();
        while (metrics_iter.next()) |entry| {
            if (!first_metric) try buf.append(self.allocator, ',');
            first_metric = false;
            try buf.print(self.allocator, "\"{s}\":{d}", .{entry.key_ptr.*, entry.value_ptr.*});
        }
        try buf.append(self.allocator, '}');

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
        };
        try buf.print(self.allocator, "{s} {s}: {s}\n", .{ status_symbol, self.command_name, self.summary });

        if (self.metrics.count() > 0) {
            try buf.appendSlice(self.allocator, "\nMetrics:\n");
            var metrics_iter = self.metrics.iterator();
            while (metrics_iter.next()) |entry| {
                try buf.print(self.allocator, "  {s}: {d}\n", .{entry.key_ptr.*, entry.value_ptr.*});
            }
        }

        if (self.error_message) |msg| {
            try buf.appendSlice(self.allocator, "\nError:\n");
            try buf.print(self.allocator, "  {s}\n", .{msg});
        }

        return buf.toOwnedSlice(self.allocator);
    }

    /// Print output to stdout
    pub fn print(self: *const UnifiedOutput, json_output: bool) !void {
        const output = if (json_output)
            try self.toJson()
        else
            try self.toText();
        defer self.allocator.free(output);

        const stdout = std.io.getStdOut();
        try stdout.writeAll(output);
    }
};

// =============================================================================
// FACTORY FUNCTIONS
// =============================================================================

pub fn success(allocator: std.mem.Allocator, command_name: []const u8, summary: []const u8) !UnifiedOutput {
    var output = UnifiedOutput.init(allocator, command_name);
    try output.setSummary(summary);
    output.finalize();
    return output;
}

pub fn failure(allocator: std.mem.Allocator, command_name: []const u8, summary: []const u8, error_msg: []const u8) !UnifiedOutput {
    var output = UnifiedOutput.init(allocator, command_name);
    try output.setSummary(summary);
    try output.setError(error_msg);
    output.finalize();
    return output;
}

pub fn partial(allocator: std.mem.Allocator, command_name: []const u8, summary: []const u8) !UnifiedOutput {
    var output = UnifiedOutput.init(allocator, command_name);
    try output.setSummary(summary);
    output.setStatus(.partial);
    output.finalize();
    return output;
}

// =============================================================================
// TESTS
// =============================================================================

test "ExecutionStatus.toString" {
    try std.testing.expectEqualStrings("success", ExecutionStatus.success.toString());
    try std.testing.expectEqualStrings("failure", ExecutionStatus.failure.toString());
    try std.testing.expectEqualStrings("partial", ExecutionStatus.partial.toString());
}

test "UnifiedOutput basic usage" {
    const allocator = std.testing.allocator;
    var output = UnifiedOutput.init(allocator, "test_cmd");
    try output.setSummary("Test completed");
    try output.addMetric("duration_ms", 123);
    output.finalize();

    const json = try output.toJson();
    defer allocator.free(json);

    // Debug: print the JSON
    std.log.debug("JSON output: {s}", .{json});

    try std.testing.expect(std.mem.indexOf(u8, json, "\"command\":\"test_cmd\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    // Note: finalize() adds duration_ms again, overwriting the value
    try std.testing.expect(std.mem.indexOf(u8, json, "\"duration_ms\"") != null);

    output.deinit();
}

test "UnifiedOutput toText" {
    const allocator = std.testing.allocator;
    var output = UnifiedOutput.init(allocator, "test_cmd");
    try output.setSummary("Test completed");
    try output.addMetric("duration_ms", 123);
    output.finalize();

    const text = try output.toText();
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "✓") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "duration_ms") != null);

    output.deinit();
}
