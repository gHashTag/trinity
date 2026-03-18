// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI EVENTS — Cell Event Bus
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wires cell.tri `contributes.events` into a runtime event bus.
// Events are auto-discovered from cells and logged to .trinity/events.jsonl.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const cell_parser = @import("ribosome.zig");

const EVENTS_LOG = ".trinity/events.jsonl";
const MAX_HANDLERS_PER_EVENT = 32;
const MAX_EVENTS = 256;

pub const EventHandler = struct {
    cell_id: []const u8,
    callback_type: CallbackType,

    pub const CallbackType = enum {
        log_jsonl, // Write to .trinity/events.jsonl
        notify_telegram, // Send via tri notify
        custom, // Cell-specific handler
    };
};

pub const EventBus = struct {
    allocator: Allocator,
    handlers: std.StringHashMap(std.array_list.Managed(EventHandler)),
    registered_events: std.array_list.Managed([]const u8),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .handlers = std.StringHashMap(std.array_list.Managed(EventHandler)).init(allocator),
            .registered_events = std.array_list.Managed([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.handlers.deinit();
        self.registered_events.deinit();
    }

    /// Subscribe to an event
    pub fn subscribe(self: *Self, event: []const u8, handler: EventHandler) !void {
        const result = try self.handlers.getOrPut(event);
        if (!result.found_existing) {
            result.value_ptr.* = std.array_list.Managed(EventHandler).init(self.allocator);
            try self.registered_events.append(event);
        }
        if (result.value_ptr.items.len < MAX_HANDLERS_PER_EVENT) {
            try result.value_ptr.append(handler);
        }
    }

    /// Emit an event with data payload
    pub fn emit(self: *Self, event: []const u8, data: []const u8) void {
        // Always log to JSONL
        logEvent(self.allocator, event, data);

        // Call registered handlers
        if (self.handlers.get(event)) |handler_list| {
            for (handler_list.items) |handler| {
                switch (handler.callback_type) {
                    .log_jsonl => {}, // Already logged above
                    .notify_telegram => {
                        sendTelegramNotification(self.allocator, event, data, handler.cell_id);
                    },
                    .custom => {}, // Future: cell-specific handlers
                }
            }
        }
    }

    /// List all registered events
    pub fn listEvents(self: *const Self) []const []const u8 {
        return self.registered_events.items;
    }

    /// Get handler count for an event
    pub fn handlerCount(self: *const Self, event: []const u8) usize {
        if (self.handlers.get(event)) |handler_list| {
            return handler_list.items.len;
        }
        return 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-SUBSCRIBE FROM CELLS
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan all cells and register event handlers from contributes.events.
/// Default behavior: all events get a JSONL log handler.
/// Events containing "elo" or "update" also get Telegram notification.
pub fn autoSubscribeFromCells(allocator: Allocator, bus: *EventBus) !void {
    const cells = try cell_parser.discoverAll(allocator);
    defer allocator.free(cells);

    for (cells) |cell| {
        const m = cell.manifest;
        if (!m.hasEvents()) continue;

        var ev_iter = cell_parser.ArrayIterator.init(m.contributes_events);
        while (ev_iter.next()) |trimmed| {
            // Every event gets JSONL logging
            try bus.subscribe(trimmed, .{
                .cell_id = m.id,
                .callback_type = .log_jsonl,
            });

            // Events with "elo" or "update" in name also trigger Telegram
            if (std.mem.indexOf(u8, trimmed, "elo") != null or
                std.mem.indexOf(u8, trimmed, "update") != null)
            {
                try bus.subscribe(trimmed, .{
                    .cell_id = m.id,
                    .callback_type = .notify_telegram,
                });
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND — `tri events [list|emit|status]`
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEventsCommand(allocator: Allocator, args: []const []const u8) !void {
    const sub = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, sub, "list")) {
        var bus = EventBus.init(allocator);
        defer bus.deinit();
        try autoSubscribeFromCells(allocator, &bus);

        std.debug.print("\n\x1b[36m📡 CELL EVENT REGISTRY\x1b[0m\n\n", .{});
        std.debug.print("  \x1b[36m{s:<30} {s:<8}\x1b[0m\n", .{ "EVENT", "HANDLERS" });
        std.debug.print("  \x1b[90m{s:->30} {s:->8}\x1b[0m\n", .{ "", "" });

        for (bus.listEvents()) |ev| {
            std.debug.print("  {s:<30} {d}\n", .{ ev, bus.handlerCount(ev) });
        }
        std.debug.print("\n", .{});
    } else if (std.mem.eql(u8, sub, "emit")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri events emit <event-name> [data]\n", .{});
            return;
        }
        const event_name = args[1];
        const data = if (args.len > 2) args[2] else "{}";

        var bus = EventBus.init(allocator);
        defer bus.deinit();
        try autoSubscribeFromCells(allocator, &bus);
        bus.emit(event_name, data);
        std.debug.print("\x1b[32m✓\x1b[0m Emitted event: {s}\n", .{event_name});
    } else {
        // status — show recent events from log
        std.debug.print("\n\x1b[36m📡 EVENT BUS STATUS\x1b[0m\n\n", .{});

        const log_content = std.fs.cwd().readFileAlloc(allocator, EVENTS_LOG, 262144) catch {
            std.debug.print("  No events logged yet ({s})\n\n", .{EVENTS_LOG});
            return;
        };
        defer allocator.free(log_content);

        // Show last 20 events
        var line_count: usize = 0;
        var total_lines: usize = 0;
        var lines_iter = std.mem.splitScalar(u8, log_content, '\n');
        while (lines_iter.next()) |line| {
            if (line.len > 0) total_lines += 1;
        }

        var lines = std.mem.splitScalar(u8, log_content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            line_count += 1;
            if (total_lines > 20 and line_count <= total_lines - 20) continue;
            std.debug.print("  {s}\n", .{line});
        }
        std.debug.print("\n  Total events: {d}\n\n", .{total_lines});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn logEvent(allocator: Allocator, event: []const u8, data: []const u8) void {
    std.fs.cwd().makePath(".trinity") catch {};

    const file = std.fs.cwd().createFile(EVENTS_LOG, .{ .truncate = false }) catch return;
    defer file.close();
    file.seekFromEnd(0) catch return;

    const timestamp = std.time.timestamp();
    const line = std.fmt.allocPrint(
        allocator,
        "{{\"ts\":{d},\"event\":\"{s}\",\"data\":{s}}}\n",
        .{ timestamp, event, if (data.len > 0) data else "{}" },
    ) catch return;
    defer allocator.free(line);

    file.writeAll(line) catch {};
}

fn sendTelegramNotification(allocator: Allocator, event: []const u8, data: []const u8, cell_id: []const u8) void {
    const msg = std.fmt.allocPrint(
        allocator,
        "📡 Event: {s}\nCell: {s}\nData: {s}",
        .{ event, cell_id, data },
    ) catch return;
    defer allocator.free(msg);

    // Use tri notify to send
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig-out/bin/tri", "notify", msg },
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "event bus init and deinit" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();
    try std.testing.expectEqual(@as(usize, 0), bus.listEvents().len);
}

test "event bus subscribe and count" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.subscribe("test_event", .{ .cell_id = "test.cell", .callback_type = .log_jsonl });
    try bus.subscribe("test_event", .{ .cell_id = "test.cell2", .callback_type = .notify_telegram });

    try std.testing.expectEqual(@as(usize, 1), bus.listEvents().len);
    try std.testing.expectEqual(@as(usize, 2), bus.handlerCount("test_event"));
    try std.testing.expectEqual(@as(usize, 0), bus.handlerCount("nonexistent"));
}

test "shared parser — cell events" {
    const content =
        \\[cell]
        \\id = "trinity.arena"
        \\
        \\[contributes]
        \\events = ["on_battle_complete", "on_elo_update"]
    ;
    const m = cell_parser.parse(content);
    try std.testing.expectEqualStrings("trinity.arena", m.id);
    try std.testing.expect(m.hasEvents());
}

test "shared parser — no events" {
    const content =
        \\[cell]
        \\id = "trinity.vsa"
        \\
        \\[contributes]
        \\commands = ["verify"]
    ;
    const m = cell_parser.parse(content);
    try std.testing.expectEqualStrings("trinity.vsa", m.id);
    try std.testing.expect(!m.hasEvents());
}
