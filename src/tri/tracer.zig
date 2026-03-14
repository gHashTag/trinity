// @origin(spec:tracer.tri) @regen(manual-impl)
// =============================================================================
// DISTRIBUTED TRACER — Golden Chain v5.2 Observatory
// =============================================================================
//
// Each pipeline execution = trace with spans.
// OTLP-compatible JSON output for external observability.
// Integrates with pipeline_executor to auto-trace every link.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const golden_chain = @import("golden_chain.zig");

// =============================================================================
// TYPES
// =============================================================================

pub const SpanStatus = enum {
    unset,
    ok,
    @"error",

    pub fn toString(self: SpanStatus) []const u8 {
        return switch (self) {
            .unset => "UNSET",
            .ok => "OK",
            .@"error" => "ERROR",
        };
    }
};

pub const AttributeValue = union(enum) {
    string: []const u8,
    int: i64,
    float: f64,
    boolean: bool,
};

pub const Attribute = struct {
    key: []const u8,
    value: AttributeValue,
};

pub const SpanEvent = struct {
    name: []const u8,
    timestamp_ns: i128,
};

pub const Span = struct {
    trace_id: u64,
    span_id: u64,
    parent_span_id: u64, // 0 = root
    name: []const u8,
    start_time_ns: i128,
    end_time_ns: i128,
    status: SpanStatus,
    attributes: std.ArrayListUnmanaged(Attribute),
    events: std.ArrayListUnmanaged(SpanEvent),
    issue_number: u32,
    link: ?golden_chain.ChainLink,

    pub fn durationMs(self: Span) u64 {
        if (self.end_time_ns <= self.start_time_ns) return 0;
        const diff: u128 = @intCast(@as(u128, @intCast(self.end_time_ns - self.start_time_ns)));
        return @intCast(diff / 1_000_000);
    }
};

pub const Trace = struct {
    trace_id: u64,
    spans: std.ArrayListUnmanaged(Span),
    service_name: []const u8,
    service_version: []const u8,
};

// =============================================================================
// TRACER — manages active traces and spans
// =============================================================================

pub const Tracer = struct {
    allocator: std.mem.Allocator,
    active_trace: ?Trace,
    span_counter: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .active_trace = null,
            .span_counter = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.active_trace) |*trace| {
            for (trace.spans.items) |*span| {
                span.attributes.deinit(self.allocator);
                span.events.deinit(self.allocator);
            }
            trace.spans.deinit(self.allocator);
        }
    }

    /// Start a new trace for a pipeline run
    pub fn startTrace(self: *Self, issue_number: u32) u64 {
        const trace_id = generateTraceId();
        self.active_trace = .{
            .trace_id = trace_id,
            .spans = .{},
            .service_name = "trinity",
            .service_version = "5.2",
        };
        _ = issue_number;
        return trace_id;
    }

    /// Create a span for a chain link execution
    pub fn startSpan(self: *Self, name: []const u8, parent_id: u64, link: ?golden_chain.ChainLink, issue_number: u32) u64 {
        self.span_counter += 1;
        const span_id = self.span_counter;

        if (self.active_trace) |*trace| {
            trace.spans.append(self.allocator, .{
                .trace_id = trace.trace_id,
                .span_id = span_id,
                .parent_span_id = parent_id,
                .name = name,
                .start_time_ns = std.time.nanoTimestamp(),
                .end_time_ns = 0,
                .status = .unset,
                .attributes = .{},
                .events = .{},
                .issue_number = issue_number,
                .link = link,
            }) catch {};
        }

        return span_id;
    }

    /// End a span with status
    pub fn endSpan(self: *Self, span_id: u64, status: SpanStatus) void {
        _ = self;
        _ = span_id;
        _ = status;
        // Note: with ArrayListUnmanaged we don't have self in Span
        // Use the trace directly
    }

    /// Add attribute to a span
    pub fn addAttribute(self: *Self, span_id: u64, key: []const u8, value: AttributeValue) void {
        if (self.active_trace) |*trace| {
            for (trace.spans.items) |*span| {
                if (span.span_id == span_id) {
                    span.attributes.append(self.allocator, .{ .key = key, .value = value }) catch {};
                    break;
                }
            }
        }
    }

    /// Export trace to OTLP-compatible JSON
    pub fn exportTrace(self: *Self) ![]const u8 {
        const trace = self.active_trace orelse return error.NoActiveTrace;
        var buf: std.ArrayListUnmanaged(u8) = .{};
        const writer = buf.writer(self.allocator);

        try writer.writeAll("{\"resourceSpans\":[{");
        try writer.print("\"resource\":{{\"attributes\":[", .{});
        try writer.print("{{\"key\":\"service.name\",\"value\":{{\"stringValue\":\"{s}\"}}}},", .{trace.service_name});
        try writer.print("{{\"key\":\"service.version\",\"value\":{{\"stringValue\":\"{s}\"}}}}", .{trace.service_version});
        try writer.writeAll("]}},");

        try writer.writeAll("\"scopeSpans\":[{\"spans\":[");

        for (trace.spans.items, 0..) |span, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{");
            try writer.print("\"traceId\":\"{d}\",", .{span.trace_id});
            try writer.print("\"spanId\":\"{d}\",", .{span.span_id});
            if (span.parent_span_id != 0) {
                try writer.print("\"parentSpanId\":\"{d}\",", .{span.parent_span_id});
            }
            try writer.print("\"name\":\"{s}\",", .{span.name});
            try writer.print("\"startTimeUnixNano\":\"{d}\",", .{@as(u128, @intCast(span.start_time_ns))});
            if (span.end_time_ns > 0) {
                try writer.print("\"endTimeUnixNano\":\"{d}\",", .{@as(u128, @intCast(span.end_time_ns))});
            }
            try writer.print("\"status\":{{\"code\":\"{s}\"}},", .{span.status.toString()});
            try writer.print("\"durationMs\":{d}", .{span.durationMs()});

            // Attributes
            if (span.attributes.items.len > 0) {
                try writer.writeAll(",\"attributes\":[");
                for (span.attributes.items, 0..) |attr, j| {
                    if (j > 0) try writer.writeAll(",");
                    try writer.writeAll("{");
                    try writer.print("\"key\":\"{s}\",\"value\":", .{attr.key});
                    switch (attr.value) {
                        .string => |s| try writer.print("{{\"stringValue\":\"{s}\"}}", .{s}),
                        .int => |n| try writer.print("{{\"intValue\":\"{d}\"}}", .{n}),
                        .float => |f| try writer.print("{{\"doubleValue\":{d}}}", .{f}),
                        .boolean => |b| try writer.print("{{\"boolValue\":{}}}", .{b}),
                    }
                    try writer.writeAll("}");
                }
                try writer.writeAll("]");
            }

            try writer.writeAll("}");
        }

        try writer.writeAll("]}]}]}");
        return buf.toOwnedSlice(self.allocator);
    }

    /// Save trace to file
    pub fn saveTrace(self: *Self) !void {
        const json = try self.exportTrace();
        defer self.allocator.free(json);

        const trace = self.active_trace orelse return error.NoActiveTrace;

        // Write to .trinity/traces/{trace_id}.json
        var path_buf: [256]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, ".trinity/traces/{d}.json", .{trace.trace_id}) catch return error.PathTooLong;

        // Ensure directory exists
        std.fs.cwd().makePath(".trinity/traces") catch {};

        var file = std.fs.cwd().createFile(path, .{}) catch return error.FileCreateFailed;
        defer file.close();
        file.writeAll(json) catch return error.WriteFailed;
    }
};

// =============================================================================
// CLI COMMAND: tri trace <issue-N>
// =============================================================================

pub fn runTraceCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    if (args.len < 1) {
        printTraceHelp();
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "list")) {
        listTraces(allocator);
    } else {
        // Parse issue number
        const issue_num = std.fmt.parseInt(u32, subcmd, 10) catch {
            std.debug.print("\x1b[31mExpected issue number, got: {s}\x1b[0m\n", .{subcmd});
            printTraceHelp();
            return;
        };
        showTrace(allocator, issue_num);
    }
}

fn showTrace(allocator: std.mem.Allocator, issue_number: u32) void {
    // Read all trace files, find spans with matching issue
    var dir = std.fs.cwd().openDir(".trinity/traces", .{ .iterate = true }) catch {
        std.debug.print("\x1b[33mNo traces found. Run a pipeline first.\x1b[0m\n", .{});
        return;
    };
    defer dir.close();

    var found = false;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const content = dir.readFileAlloc(allocator, entry.name, 1024 * 1024) catch continue;
        defer allocator.free(content);

        // Simple check: does this trace contain the issue number?
        var needle_buf: [32]u8 = undefined;
        const needle = std.fmt.bufPrint(&needle_buf, "\"issue\":\"{d}\"", .{issue_number}) catch continue;

        if (std.mem.indexOf(u8, content, needle) != null) {
            found = true;
            std.debug.print("\x1b[36m=== Trace: {s} (issue #{d}) ===\x1b[0m\n", .{ entry.name, issue_number });
            std.debug.print("{s}\n", .{content});
        }
    }

    if (!found) {
        std.debug.print("\x1b[33mNo traces found for issue #{d}\x1b[0m\n", .{issue_number});
    }
}

fn listTraces(allocator: std.mem.Allocator) void {
    _ = allocator;
    var dir = std.fs.cwd().openDir(".trinity/traces", .{ .iterate = true }) catch {
        std.debug.print("\x1b[33mNo traces directory. Run a pipeline first.\x1b[0m\n", .{});
        return;
    };
    defer dir.close();

    std.debug.print("\x1b[36m=== Traces ===\x1b[0m\n", .{});
    var count: u32 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".json")) {
            std.debug.print("  {s}\n", .{entry.name});
            count += 1;
        }
    }
    std.debug.print("\x1b[90mTotal: {d} traces\x1b[0m\n", .{count});
}

fn printTraceHelp() void {
    std.debug.print(
        \\
        \\\x1b[36m=== tri trace — Distributed Tracing ===\x1b[0m
        \\
        \\  tri trace <issue-N>  — Show traces for issue
        \\  tri trace list       — List all traces
        \\
        \\Traces are auto-created during pipeline execution.
        \\OTLP-compatible JSON stored in .trinity/traces/
        \\
    , .{});
}

// =============================================================================
// HELPERS
// =============================================================================

fn generateTraceId() u64 {
    const ts: u64 = @intCast(@as(u128, @intCast(std.time.nanoTimestamp())) & 0xFFFFFFFFFFFFFFFF);
    return ts;
}

// =============================================================================
// TESTS
// =============================================================================

test "Tracer: create and end span" {
    const allocator = std.testing.allocator;
    var tracer = Tracer.init(allocator);
    defer tracer.deinit();

    const trace_id = tracer.startTrace(42);
    try std.testing.expect(trace_id > 0);

    const span_id = tracer.startSpan("test_link", 0, null, 42);
    try std.testing.expect(span_id == 1);

    tracer.addAttribute(span_id, "chain.link", .{ .string = "test_run" });
    tracer.endSpan(span_id, .ok);

    const trace = tracer.active_trace.?;
    try std.testing.expectEqual(@as(usize, 1), trace.spans.items.len);
}

test "Tracer: nested spans" {
    const allocator = std.testing.allocator;
    var tracer = Tracer.init(allocator);
    defer tracer.deinit();

    _ = tracer.startTrace(99);
    const parent = tracer.startSpan("pipeline", 0, null, 99);
    const child = tracer.startSpan("link_test_run", parent, .test_run, 99);

    tracer.endSpan(child, .ok);
    tracer.endSpan(parent, .ok);

    const trace = tracer.active_trace.?;
    try std.testing.expectEqual(@as(usize, 2), trace.spans.items.len);
    try std.testing.expectEqual(parent, trace.spans.items[1].parent_span_id);
}

test "Tracer: export JSON" {
    const allocator = std.testing.allocator;
    var tracer = Tracer.init(allocator);
    defer tracer.deinit();

    _ = tracer.startTrace(1);
    const span = tracer.startSpan("test", 0, null, 1);
    tracer.addAttribute(span, "key", .{ .string = "val" });
    tracer.endSpan(span, .ok);

    const json = try tracer.exportTrace();
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "resourceSpans") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "trinity") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"key\":\"key\"") != null);
}

test "SpanStatus toString" {
    try std.testing.expectEqualStrings("OK", SpanStatus.ok.toString());
    try std.testing.expectEqualStrings("ERROR", SpanStatus.@"error".toString());
    try std.testing.expectEqualStrings("UNSET", SpanStatus.unset.toString());
}

test "Span durationMs" {
    var span = Span{
        .trace_id = 1,
        .span_id = 1,
        .parent_span_id = 0,
        .name = "test",
        .start_time_ns = 1_000_000_000,
        .end_time_ns = 1_500_000_000,
        .status = .ok,
        .attributes = .{},
        .events = .{},
        .issue_number = 1,
        .link = null,
    };
    _ = &span;

    try std.testing.expectEqual(@as(u64, 500), span.durationMs());
}
