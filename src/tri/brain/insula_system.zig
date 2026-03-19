// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// INSULA (Interoception) — System State Logs
// ═══════════════════════════════════════════════════════════════════════════════
//
// PROBLEM: No centralized logging for Ouroboros, Doctor, Night Guard decisions
// SOLUTION: Insula as interoceptive layer for all system events
//
// Insula logs all internal Trinity events for audit and post-mortem analysis.
// Stored in JSONL format for easy parsing and chronological order.
//
// NEUROANATOMY: Insula = Interoception (sensory input about internal state)
//     Homeostasis, emotions, visceral sensations. Here: system health monitoring.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═════════════════════════════════════════════════════════════════════════════

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
    critical,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .critical => "CRITICAL",
        };
    }

    pub fn icon(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "🔍",
            .info => "ℹ️",
            .warn => "⚠️",
            .err => "❌",
            .critical => "🚨",
        };
    }
};

pub const EventType = enum {
    decision_made,   // kill/restart/evolve decision
    error_occurred,  // panic, OOM, dataset not found
    state_change,    // night mode enabled/disabled
    circuit_break,  // safety trigger activated
    conflict_detected, // ACC conflict alert
    worker_lifecycle, // worker created/destroyed
    config_change, // configuration update

    pub fn toString(self: EventType) []const u8 {
        return switch (self) {
            .decision_made => "decision",
            .error_occurred => "error",
            .state_change => "state",
            .circuit_break => "circuit",
            .conflict_detected => "conflict",
            .worker_lifecycle => "lifecycle",
            .config_change => "config",
        };
    }
};

pub const SystemEvent = struct {
    timestamp: i64,
    level: LogLevel,
    component: []const u8, // "ouroboros", "doctor", "night-guard", "dlpfc", "thalamus"
    event_type: EventType,
    message: []const u8,
    metadata: ?std.json.Value,

    const Self = @This();

    /// Create a new system event
    pub fn create(
        allocator: Allocator,
        level: LogLevel,
        component: []const u8,
        event_type: EventType,
        message: []const u8,
    ) !SystemEvent {
        return .{
            .timestamp = std.time.timestamp(),
            .level = level,
            .component = try allocator.dupe(u8, component),
            .event_type = event_type,
            .message = try allocator.dupe(u8, message),
            .metadata = null,
        };
    }

    /// Create event with metadata
    pub fn createWithMetadata(
        allocator: Allocator,
        level: LogLevel,
        component: []const u8,
        event_type: EventType,
        message: []const u8,
        metadata: std.json.Value,
    ) !SystemEvent {
        return .{
            .timestamp = std.time.timestamp(),
            .level = level,
            .component = try allocator.dupe(u8, component),
            .event_type = event_type,
            .message = try allocator.dupe(u8, message),
            .metadata = metadata,
        };
    }

    /// Free allocated memory
    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.component);
        allocator.free(self.message);
        if (self.metadata) |m| {
            // Value doesn't own its internal allocations in current stdlib
            _ = m;
        }
    }
};

/// Fixed-buffer event for append-only writes
pub const EventBuffer = struct {
    timestamp: i64,
    level: LogLevel,
    component_buf: [32]u8 = undefined,
    component_len: u8 = 0,
    event_type: EventType,
    message_buf: [512]u8 = undefined,
    message_len: u16 = 0,
    metadata_buf: [2048]u8 = undefined,
    metadata_len: u16 = 0,

    /// Get component name
    pub fn component(self: *const EventBuffer) []const u8 {
        return self.component_buf[0..self.component_len];
    }

    /// Get message
    pub fn message(self: *const EventBuffer) []const u8 {
        return self.message_buf[0..self.message_len];
    }

    /// Get metadata JSON string
    pub fn metadataStr(self: *const EventBuffer) []const u8 {
        return self.metadata_buf[0..self.metadata_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INSULA API — System Event Logging
// ═════════════════════════════════════════════════════════════════════════════

pub const Insula = struct {
    allocator: Allocator,
    file_path: []const u8 = ".trinity/insula_events.jsonl",

    const Self = @This();

    /// Initialize Insula logging system
    pub fn init(allocator: Allocator) Self {
        // Ensure directory exists
        std.fs.cwd().makePath(".trinity") catch {};
        return .{
            .allocator = allocator,
        };
    }

    /// Log a system event (decision, error, alert)
    pub fn logEvent(self: *Self, event: *const SystemEvent) !void {
        // Serialize to JSON line
        var buf: [4096]u8 = undefined;
        const json_line = try serializeEvent(&buf, event);

        // Append to file (create if not exists)
        const file = try std.fs.cwd().createFile(self.file_path, .{ .truncate = false });
        defer file.close();
        try file.seekFromEnd(0);
        try file.writeAll(json_line);
        try file.writeAll("\n");
    }

    /// Log event without allocation (buffer-based)
    pub fn logEventBuffer(self: *Self, buffer: *const EventBuffer) !void {
        // Serialize to JSON line
        var buf: [4096]u8 = undefined;
        const json_line = try serializeEventBuffer(&buf, buffer);

        // Append to file
        const file = try std.fs.cwd().createFile(self.file_path, .{ .truncate = false });
        defer file.close();
        try file.seekFromEnd(0);
        try file.writeAll(json_line);
        try file.writeAll("\n");
    }

    /// Get recent events for debugging
    pub fn getRecentEvents(self: *Self, limit: usize) !std.ArrayList(SystemEvent) {
        const file = std.fs.cwd().openFile(self.file_path, .{}) catch {
            return std.ArrayList(SystemEvent).init(self.allocator);
        };
        defer file.close();

        var results = std.ArrayList(SystemEvent).init(self.allocator);

        const content = try file.readToEndAlloc(self.allocator, 65536);
        defer self.allocator.free(content);

        // Parse JSONL lines from end (reverse order for recent first)
        var lines = std.mem.splitScalar(u8, content, '\n');
        var lines_list = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (lines_list.items) |line| {
                self.allocator.free(line);
            }
            lines_list.deinit();
        }

        while (lines.next()) |line| {
            if (line.len == 0) continue;
            const line_copy = try self.allocator.dupe(u8, line);
            try lines_list.append(self.allocator, line_copy);
        }

        // Read from end (reverse)
        const start_idx = if (lines_list.items.len > limit) lines_list.items.len - limit else 0;
        _ = start_idx; // Calculated for future use in optimized reading

        var idx: usize = lines_list.items.len;
        while (idx > 0 and results.items.len < limit) : (idx -= 1) {
            const line = lines_list.items[idx - 1];
            const parsed = try std.json.parseFromSlice(self.allocator, line);
            defer parsed.deinit(self.allocator);

            if (parsed != .object) continue;

            const event = try parseEventFromJson(self.allocator, parsed.object);
            try results.append(self.allocator, event);
        }

        return results;
    }

    /// Get events by component filter
    pub fn getEventsByComponent(self: *Self, component: []const u8, limit: usize) !std.ArrayList(SystemEvent) {
        const all_events = try self.getRecentEvents(1000);
        defer {
            for (all_events.items) |e| {
                e.deinit(self.allocator);
            }
            all_events.deinit();
        }

        var filtered = std.ArrayList(SystemEvent).init(self.allocator);

        for (all_events.items) |e| {
            if (std.mem.eql(u8, e.component, component)) {
                const copy = try SystemEvent.create(
                    self.allocator,
                    e.level,
                    e.component,
                    e.event_type,
                    e.message,
                );
                try filtered.append(self.allocator, copy);
            }
        }

        if (filtered.items.len > limit) {
            filtered.shrinkRetainingCapacity(limit);
        }

        return filtered;
    }

    /// Get events by event type filter
    pub fn getEventsByType(self: *Self, event_type: EventType, limit: usize) !std.ArrayList(SystemEvent) {
        const all_events = try self.getRecentEvents(1000);
        defer {
            for (all_events.items) |e| {
                e.deinit(self.allocator);
            }
            all_events.deinit();
        }

        var filtered = std.ArrayList(SystemEvent).init(self.allocator);

        for (all_events.items) |e| {
            if (e.event_type == event_type) {
                const copy = try SystemEvent.create(
                    self.allocator,
                    e.level,
                    e.component,
                    e.event_type,
                    e.message,
                );
                try filtered.append(self.allocator, copy);
            }
        }

        if (filtered.items.len > limit) {
            filtered.shrinkRetainingCapacity(limit);
        }

        return filtered;
    }

    /// Get events by log level filter
    pub fn getEventsByLevel(self: *Self, level: LogLevel, limit: usize) !std.ArrayList(SystemEvent) {
        const all_events = try self.getRecentEvents(1000);
        defer {
            for (all_events.items) |e| {
                e.deinit(self.allocator);
            }
            all_events.deinit();
        }

        var filtered = std.ArrayList(SystemEvent).init(self.allocator);

        for (all_events.items) |e| {
            if (e.level == level) {
                const copy = try SystemEvent.create(
                    self.allocator,
                    e.level,
                    e.component,
                    e.event_type,
                    e.message,
                );
                try filtered.append(self.allocator, copy);
            }
        }

        if (filtered.items.len > limit) {
            filtered.shrinkRetainingCapacity(limit);
        }

        return filtered;
    }

    /// Count events by type for analytics
    pub fn countByType(self: *Self, event_type: EventType) !usize {
        const events = try self.getEventsByType(event_type, 10000);
        defer {
            for (events.items) |e| {
                e.deinit(self.allocator);
            }
            events.deinit();
        }
        return events.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SERIALIZATION HELPERS
// ═══════════════════════════════════════════════════════════════════════════

fn serializeEvent(buf: *[4096]u8, event: *const SystemEvent) ![]const u8 {
    var obj = std.json.ObjectMap.init(buf[0..]);
    try obj.putNoAlloc("timestamp", std.json.Value.number(@floatFromInt(event.timestamp)));
    try obj.putNoAlloc("level", std.json.Value.string(event.level.toString()));
    try obj.putNoAlloc("component", std.json.Value.string(event.component));
    try obj.putNoAlloc("event_type", std.json.Value.string(event.event_type.toString()));
    try obj.putNoAlloc("message", std.json.Value.string(event.message));

    if (event.metadata) |m| {
        try obj.putNoAlloc("metadata", m);
    } else {
        try obj.putNoAlloc("metadata", std.json.Value.null);
    }

    const json_str = try std.json.stringifyAlloc(buf[4096..], std.json.Value.object(std.json.Value{ .object = obj }), .{});
    return json_str;
}

fn serializeEventBuffer(buf: *[4096]u8, buffer: *const EventBuffer) ![]const u8 {
    var obj = std.json.ObjectMap.init(buf[0..]);
    try obj.putNoAlloc("timestamp", std.json.Value.number(@floatFromInt(buffer.timestamp)));
    try obj.putNoAlloc("level", std.json.Value.string(buffer.level.toString()));
    try obj.putNoAlloc("component", std.json.Value.string(buffer.component()));
    try obj.putNoAlloc("event_type", std.json.Value.string(buffer.event_type.toString()));
    try obj.putNoAlloc("message", std.json.Value.string(buffer.message()));

    if (buffer.metadata_len > 0) {
        try obj.putNoAlloc("metadata", std.json.Value.string(buffer.metadataStr()));
    } else {
        try obj.putNoAlloc("metadata", std.json.Value.null);
    }

    const json_str = try std.json.stringifyAlloc(buf[4096..], std.json.Value.object(std.json.Value{ .object = obj }), .{});
    return json_str;
}

fn parseEventFromJson(allocator: Allocator, obj: std.json.ObjectMap) !SystemEvent {
    const timestamp = obj.get("timestamp") orelse return error.MissingField;
    const level_str = obj.get("level") orelse return error.MissingField;
    const component = obj.get("component") orelse return error.MissingField;
    const event_type_str = obj.get("event_type") orelse return error.MissingField;
    const message = obj.get("message") orelse return error.MissingField;
    const metadata = obj.get("metadata");

    if (timestamp != .number or level_str != .string or component != .string or
        event_type_str != .string or message != .string)
    {
        return error.InvalidFormat;
    }

    const level = if (LogLevel.fromString(level_str.string)) |l| l else .info;
    const event_type = if (EventType.fromString(event_type_str.string)) |t| t else .error_occurred;

    const event = try SystemEvent.createWithMetadata(
        allocator,
        level,
        component.string,
        event_type,
        message.string,
        if (metadata) |m| m else null,
    );

    return event;
}

test "insula_log_event" {
    const allocator = std.testing.allocator;
    var insula = Insula.init(allocator);

    const event = try SystemEvent.create(
        allocator,
        .info,
        "test-component",
        .state_change,
        "Test event for Insula",
    );
    defer event.deinit(allocator);

    try insula.logEvent(&event);

    // Clean up test file
    std.fs.cwd().deleteFile(insula.file_path) catch {};
}

test "insula_buffer_serialization" {
    var buffer: EventBuffer = .{};
    buffer.timestamp = std.time.timestamp();
    buffer.level = .info;
    copyToFixed(32, &buffer.component_len, buffer.component_buf, "test");
    buffer.event_type = .state_change;
    copyToFixed(512, &buffer.message_len, buffer.message_buf, "Test message");

    var buf: [4096]u8 = undefined;
    const json = try serializeEventBuffer(&buf, &buffer);

    // Should contain our values
    try std.testing.expect(std.mem.indexOf(u8, json, "test") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Test message") != null);
}

pub const InsulaError = error{
    MissingField,
    InvalidFormat,
};

// Extend EventType with parsing
pub fn fromString(self: EventType, s: []const u8) ?EventType {
    return switch (self) {
        .decision_made => if (std.mem.eql(u8, s, "decision")) self else null,
        .error_occurred => if (std.mem.eql(u8, s, "error")) self else null,
        .state_change => if (std.mem.eql(u8, s, "state")) self else null,
        .circuit_break => if (std.mem.eql(u8, s, "circuit")) self else null,
        .conflict_detected => if (std.mem.eql(u8, s, "conflict")) self else null,
        .worker_lifecycle => if (std.mem.eql(u8, s, "lifecycle")) self else null,
        .config_change => if (std.mem.eql(u8, s, "config")) self else null,
    };
}

pub fn copyToFixed(comptime N: usize, dest: *[N]u8, len_ptr: anytype, src: []const u8) void {
    const copy_len = @min(src.len, N);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = @intCast(copy_len);
}
