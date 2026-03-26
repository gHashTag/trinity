// @origin(spec:queen_trinity.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN TRINITY — Lotus Cycle Protocol for Impure Event Purification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Queen Trinity oversees the purity of all three Strands by processing
// impure events through the Lotus Cycle (φ² + 1/φ² = 3).
//
// Strands:
//   I (Math)    — src/tri/math/, sacred calculations
//   II (Brain)  — src/brain/, telemetry, training
//   III (Lang)  — src/tri27/, fpga/, compilation, synthesis
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// STRAND ENUM
// ═══════════════════════════════════════════════════════════════════════════════

pub const Strand = enum(u2) {
    Math = 0, // Strand I: Sacred mathematics
    Brain = 1, // Strand II: Cognitive architecture
    Lang = 2, // Strand III: Language & Hardware Bridge
};

pub fn strandName(s: Strand) []const u8 {
    return switch (s) {
        .Math => "I",
        .Brain => "II",
        .Lang => "III",
    };
}

pub fn strandFullName(s: Strand) []const u8 {
    return switch (s) {
        .Math => "Mathematical Foundation",
        .Brain => "Cognitive Architecture",
        .Lang => "Language & Hardware Bridge",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMPURE EVENT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ImpureEventType = enum(u8) {
    BUILD_FAIL = 0x01,
    TEST_FAIL = 0x02,
    SPEC_MISMATCH = 0x03,
    GEN_FAIL = 0x04,
    VERIFY_FAIL = 0x05,
    DEPLOY_FAIL = 0x06,
    CHECKPOINT_FAIL = 0x07,
};

pub fn eventName(et: ImpureEventType) []const u8 {
    return switch (et) {
        .BUILD_FAIL => "BUILD_FAIL",
        .TEST_FAIL => "TEST_FAIL",
        .SPEC_MISMATCH => "SPEC_MISMATCH",
        .GEN_FAIL => "GEN_FAIL",
        .VERIFY_FAIL => "VERIFY_FAIL",
        .DEPLOY_FAIL => "DEPLOY_FAIL",
        .CHECKPOINT_FAIL => "CHECKPOINT_FAIL",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOTUS CYCLE STATE MACHINE (φ² + 1/φ² = 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub const LotusState = enum(u8) {
    Queued = 0, // Event waiting in queue
    Diagnosing = 1, // Analyzing the impurity
    Refining = 2, // Fixing the issue
    Verifying = 3, // Testing the fix
    Purified = 4, // Successfully resolved
    Blocked = 5, // Failed 3 times → manual intervention
};

pub fn lotusStateName(ls: LotusState) []const u8 {
    return switch (ls) {
        .Queued => "QUEUED",
        .Diagnosing => "DIAGNOSING",
        .Refining => "REFINING",
        .Verifying => "VERIFYING",
        .Purified => "PURIFIED",
        .Blocked => "BLOCKED",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMPURE EVENT STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ImpureEvent = struct {
    id: [64]u8 = undefined, // Unique event ID
    strand: Strand = .Math,
    event_type: ImpureEventType = .BUILD_FAIL,
    source_file: [256]u8 = undefined, // File that caused the issue
    source_file_len: u8 = 0,
    error_msg: [512]u8 = undefined, // Error message
    error_msg_len: u16 = 0,
    timestamp: i64 = 0,
    attempts: u8 = 0,
    state: LotusState = .Queued,

    pub fn sourceFileStr(self: *const ImpureEvent) []const u8 {
        return self.source_file[0..self.source_file_len];
    }

    pub fn errorMsgStr(self: *const ImpureEvent) []const u8 {
        return self.error_msg[0..self.error_msg_len];
    }

    pub fn canAttempt(self: *const ImpureEvent) bool {
        return self.attempts < 3 and self.state != .Blocked and self.state != .Purified;
    }

    pub fn shouldBlock(self: *const ImpureEvent) bool {
        return self.attempts >= 3;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT QUEUE
// ═══════════════════════════════════════════════════════════════════════════════

const IMPURE_DIR = ".trinity/impure";
const MAX_QUEUE_SIZE = 256;

pub const ImpureQueue = struct {
    allocator: Allocator,
    events: std.ArrayList(ImpureEvent),

    pub fn init(allocator: Allocator) ImpureQueue {
        return .{
            .allocator = allocator,
            .events = std.ArrayList(ImpureEvent).empty,
        };
    }

    pub fn deinit(self: *ImpureQueue) void {
        self.events.deinit(self.allocator);
    }

    pub fn load(self: *ImpureQueue) !void {
        self.events.clearRetainingCapacity();

        var dir = std.fs.cwd().openDir(IMPURE_DIR, .{ .iterate = true }) catch {
            // Directory doesn't exist yet - empty queue
            return;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            const content = dir.readFileAlloc(self.allocator, entry.name, 4096) catch continue;
            defer self.allocator.free(content);

            var event = ImpureEvent{};
            if (parseImpureEvent(&event, content)) {
                try self.events.append(event);
            }
        }
    }

    pub fn save(self: *const ImpureQueue) !void {
        std.fs.cwd().makePath(IMPURE_DIR) catch {};

        for (self.events.items) |event| {
            var fname_buf: [128]u8 = undefined;
            const fname = std.fmt.bufPrint(&fname_buf, "{s}.json", .{event.id[0..32]}) catch continue;

            const content = serializeImpureEvent(&event) catch continue;

            const file = try std.fs.cwd().createFile(fname, .{});
            defer file.close();
            try file.writeAll(content);
        }
    }

    pub fn enqueue(self: *ImpureQueue, event: ImpureEvent) !void {
        if (self.events.items.len >= MAX_QUEUE_SIZE) {
            return error.QueueFull;
        }
        try self.events.append(event);
    }

    pub fn dequeue(self: *ImpureQueue) ?ImpureEvent {
        if (self.events.items.len == 0) return null;

        // Find first queued event
        for (self.events.items, 0..) |*event, i| {
            if (event.state == .Queued) {
                const result = self.events.orderedRemove(i);
                return result;
            }
        }
        return null;
    }

    pub fn countByState(self: *const ImpureQueue, state: LotusState) usize {
        var count: usize = 0;
        for (self.events.items) |*event| {
            if (event.state == state) count += 1;
        }
        return count;
    }

    pub fn countByStrand(self: *const ImpureQueue, strand: Strand) usize {
        var count: usize = 0;
        for (self.events.items) |*event| {
            if (event.strand == strand) count += 1;
        }
        return count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SERIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

fn parseImpureEvent(event: *ImpureEvent, json: []const u8) bool {
    // Simple JSON parser for ImpureEvent
    // Extracts key string fields without full validation
    var i: usize = 0;

    // Skip whitespace
    while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}

    // Must start with '{'
    if (i >= json.len or json[i] != '{') return false;
    i += 1;

    while (i < json.len) : (i += 1) {
        // Skip whitespace
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}
        if (i >= json.len) return false;

        // Check for end of object
        if (json[i] == '}') break;

        // Find key
        if (json[i] != '"') return false;
        i += 1;
        const key_start = i;
        while (i < json.len and json[i] != '"') : (i += 1) {
            if (json[i] == '\\') {
                i += 1; // Skip escaped char
            }
        }
        if (i >= json.len) return false;
        const key = json[key_start..i];
        i += 1; // Skip closing quote

        // Skip colon and whitespace
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == ':')) : (i += 1) {}
        if (i >= json.len) return false;

        // Extract value based on key
        if (std.mem.eql(u8, key, "strand")) {
            if (json[i] != '"') return false;
            i += 1;
            const val_start = i;
            while (i < json.len and json[i] != '"') : (i += 1) {}
            const val = json[val_start..i];
            i += 1; // Skip closing quote
            event.strand = if (std.mem.eql(u8, val, "Brain")) .Brain else if (std.mem.eql(u8, val, "Lang")) .Lang else .Math;
        } else if (std.mem.eql(u8, key, "event_type")) {
            if (json[i] != '"') return false;
            i += 1;
            const val_start = i;
            while (i < json.len and json[i] != '"') : (i += 1) {}
            const val = json[val_start..i];
            i += 1; // Skip closing quote
            event.event_type = if (std.mem.eql(u8, val, "BUILD_FAIL")) .BUILD_FAIL else if (std.mem.eql(u8, val, "TEST_FAIL")) .TEST_FAIL else if (std.mem.eql(u8, val, "SPEC_MISMATCH")) .SPEC_MISMATCH else if (std.mem.eql(u8, val, "GEN_FAIL")) .GEN_FAIL else if (std.mem.eql(u8, val, "VERIFY_FAIL")) .VERIFY_FAIL else if (std.mem.eql(u8, val, "DEPLOY_FAIL")) .DEPLOY_FAIL else if (std.mem.eql(u8, val, "CHECKPOINT_FAIL")) .CHECKPOINT_FAIL else .BUILD_FAIL;
        } else if (std.mem.eql(u8, key, "state")) {
            if (json[i] != '"') return false;
            i += 1;
            const val_start = i;
            while (i < json.len and json[i] != '"') : (i += 1) {}
            const val = json[val_start..i];
            i += 1; // Skip closing quote
            event.state = if (std.mem.eql(u8, val, "Queued")) .Queued else if (std.mem.eql(u8, val, "Diagnosing")) .Diagnosing else if (std.mem.eql(u8, val, "Refining")) .Refining else if (std.mem.eql(u8, val, "Verifying")) .Verifying else if (std.mem.eql(u8, val, "Purified")) .Purified else if (std.mem.eql(u8, val, "Blocked")) .Blocked else .Queued;
        } else if (std.mem.eql(u8, key, "source_file")) {
            if (json[i] != '"') return false;
            i += 1;
            const val_start = i;
            while (i < json.len and json[i] != '"') : (i += 1) {
                if (json[i] == '\\') i += 1;
            }
            const val = json[val_start..i];
            i += 1; // Skip closing quote
            event.source_file_len = @min(255, val.len);
            @memcpy(event.source_file[0..event.source_file_len], val);
        } else if (std.mem.eql(u8, key, "error_msg")) {
            if (json[i] != '"') return false;
            i += 1;
            const val_start = i;
            while (i < json.len and json[i] != '"') : (i += 1) {
                if (json[i] == '\\') i += 1;
            }
            const val = json[val_start..i];
            i += 1; // Skip closing quote
            event.error_msg_len = @min(511, val.len);
            @memcpy(event.error_msg[0..event.error_msg_len], val);
        } else if (std.mem.eql(u8, key, "timestamp")) {
            while (i < json.len and (json[i] == ' ' or json[i] == '\t')) : (i += 1) {}
            const num_start = i;
            while (i < json.len and (json[i] == '-' or json[i] == '+' or (json[i] >= '0' and json[i] <= '9'))) : (i += 1) {}
            if (num_start < i) {
                const num_str = json[num_start..i];
                event.timestamp = std.fmt.parseInt(i64, num_str, 10) catch 0;
            }
        } else if (std.mem.eql(u8, key, "attempts")) {
            while (i < json.len and (json[i] == ' ' or json[i] == '\t')) : (i += 1) {}
            const num_start = i;
            while (i < json.len and (json[i] >= '0' and json[i] <= '9')) : (i += 1) {}
            if (num_start < i) {
                const num_str = json[num_start..i];
                event.attempts = std.fmt.parseInt(u8, num_str, 10) catch 0;
            }
        } else {
            // Skip unknown value
            while (i < json.len and json[i] != ',' and json[i] != '}') : (i += 1) {}
        }
    }

    return true;
}

fn serializeImpureEvent(allocator: Allocator, event: *const ImpureEvent) ![]u8 {
    var json_str = std.ArrayList(u8).initCapacity(allocator, 1024) catch return error.OutOfMemory;
    defer json_str.deinit(allocator);

    try json_str.append('{');

    // ID field (hex encoded, first 32 bytes)
    try json_str.appendSlice("\"id\": \"");
    for (0..32) |i| {
        try json_str.writer(allocator).print("{x:0>2}", .{event.id[i]});
    }
    try json_str.appendSlice("\",");

    // Strand
    const strand_name = switch (event.strand) {
        .Math => "Math",
        .Brain => "Brain",
        .Lang => "Lang",
    };
    try json_str.writer(allocator).print("\"strand\": \"{s}\",", .{strand_name});

    // Event type
    const event_type_name = eventName(event.event_type);
    try json_str.writer(allocator).print("\"event_type\": \"{s}\",", .{event_type_name});

    // Source file
    try json_str.appendSlice("\"source_file\": \"");
    if (event.source_file_len > 0) {
        const sf = event.source_file[0..event.source_file_len];
        for (sf) |c| {
            if (c == '\\' or c == '"') {
                try json_str.append('\\');
            }
            try json_str.append(c);
        }
    }
    try json_str.appendSlice("\",");

    // Error message
    try json_str.appendSlice("\"error_msg\": \"");
    if (event.error_msg_len > 0) {
        const em = event.error_msg[0..event.error_msg_len];
        for (em) |c| {
            if (c == '\\' or c == '"') {
                try json_str.append('\\');
            }
            try json_str.append(c);
        }
    }
    try json_str.appendSlice("\",");

    // Timestamp and attempts
    try json_str.writer(allocator).print("\"timestamp\": {d},", .{event.timestamp});
    try json_str.writer(allocator).print("\"attempts\": {d},", .{event.attempts});

    // State
    const state_name = lotusStateName(event.state);
    try json_str.writer(allocator).print("\"state\": \"{s}\"", .{state_name});

    try json_str.append('}');

    return allocator.dupe(u8, json_str.items);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runQueenCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        return runQueenStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "purify")) {
        return runQueenPurify(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "blocked")) {
        return runQueenBlocked(allocator);
    } else if (std.mem.eql(u8, subcmd, "start")) {
        return runQueenStart(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printQueenHelp();
    } else {
        std.debug.print("Unknown queen subcommand: {s}\n", .{subcmd});
        printQueenHelp();
    }
}

fn runQueenStatus(allocator: Allocator) !void {
    std.debug.print("\n👑 QUEEN TRINITY STATUS\n", .{});
    std.debug.print("═════════════════════════\n\n", .{});
    std.debug.print("Impure event queue: .trinity/impure/\n", .{});
    std.debug.print("Lotus Cycle: φ² + 1/φ² = 3\n\n", .{});

    // Load event queue
    var queue = ImpureQueue.init(allocator);
    defer queue.deinit();
    queue.load() catch {
        std.debug.print("No impure events found (queue empty or directory doesn't exist)\n", .{});
        return;
    };

    const total = queue.events.items.len;
    if (total == 0) {
        std.debug.print("No impure events tracked\n", .{});
        return;
    }

    // Count by state
    const queued = queue.countByState(.Queued);
    const diagnosing = queue.countByState(.Diagnosing);
    const refining = queue.countByState(.Refining);
    const verifying = queue.countByState(.Verifying);
    const purified = queue.countByState(.Purified);
    const blocked = queue.countByState(.Blocked);

    std.debug.print("Total events: {d}\n\n", .{total});

    std.debug.print("By State:\n", .{});
    std.debug.print("  Queued:     {d}\n", .{queued});
    std.debug.print("  Diagnosing: {d}\n", .{diagnosing});
    std.debug.print("  Refining:   {d}\n", .{refining});
    std.debug.print("  Verifying:  {d}\n", .{verifying});
    std.debug.print("  Purified:   {d}\n", .{purified});
    std.debug.print("  Blocked:    {d}\n", .{blocked});

    // Count by strand
    std.debug.print("\nBy Strand:\n", .{});
    const strands = [_]Strand{ .Math, .Brain, .Lang };
    for (strands) |strand| {
        const count = queue.countByStrand(strand);
        std.debug.print("  Strand {s}: {d}\n", .{ strandFullName(strand), count });
    }

    // Show blocked events if any
    if (blocked > 0) {
        std.debug.print("\n🚫 BLOCKED EVENTS:\n", .{});
        for (queue.events.items) |event| {
            if (event.state == .Blocked) {
                std.debug.print("  [{s}] {s}: {s}\n", .{
                    strandName(event.strand),
                    eventName(event.event_type),
                    event.errorMsgStr(),
                });
            }
        }
    }
}

fn runQueenPurify(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("🌸 LOTUS CYCLE PURIFICATION\n", .{});
    std.debug.print("═════════════════════════════\n\n", .{});
    std.debug.print("Purify mode: TODO - implement\n", .{});
}

fn runQueenBlocked(allocator: Allocator) !void {
    std.debug.print("\n🚫 BLOCKED EVENTS\n", .{});
    std.debug.print("══════════════════\n\n", .{});

    var queue = ImpureQueue.init(allocator);
    defer queue.deinit();
    queue.load() catch {
        std.debug.print("No impure events found (queue empty or directory doesn't exist)\n", .{});
        return;
    };

    const blocked_count = queue.countByState(.Blocked);
    if (blocked_count == 0) {
        std.debug.print("No blocked events — Lotus Cycle flowing freely! ✨\n", .{});
        return;
    }

    std.debug.print("Blocked events requiring manual intervention: {d}\n\n", .{blocked_count});
    for (queue.events.items) |event| {
        if (event.state == .Blocked) {
            std.debug.print("  [{s}] {s}: {s}\n", .{
                strandName(event.strand),
                eventName(event.event_type),
                event.errorMsgStr(),
            });
            if (event.source_file_len > 0) {
                std.debug.print("    File: {s}\n", .{event.sourceFileStr()});
            }
        }
    }
}

fn runQueenStart(allocator: Allocator, args: []const []const u8) !void {
    var daemon_mode = false;
    var god_mode = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--daemon") or std.mem.eql(u8, arg, "-d")) {
            daemon_mode = true;
        } else if (std.mem.eql(u8, arg, "--god-mode") or std.mem.eql(u8, arg, "-g")) {
            god_mode = true;
        }
    }

    // PID file for lifecycle management
    const pid = std.os.linux.getpid();
    {
        var f = try std.fs.cwd().createFile("/tmp/trinity-queen.pid", .{});
        defer f.close();
        var buf: [64]u8 = undefined;
        const pid_str = try std.fmt.bufPrintZ(&buf, "{d}", .{pid});
        try f.writeAll(pid_str);
    }
    defer std.fs.deleteFileAbsolute("/tmp/trinity-queen.pid") catch {};

    if (daemon_mode) {
        std.debug.print("👑 Queen starting in daemon mode...\n", .{});
        if (god_mode) {
            std.debug.print("   God-mode enabled\n", .{});
        }
        std.debug.print("   PID: {d}\n", .{pid});
        std.debug.print("   Heartbeat: .trinity/queen/heartbeat.json\n", .{});
    } else {
        std.debug.print("👑 Queen started (foreground mode)\n", .{});
        if (god_mode) {
            std.debug.print("   God-mode enabled\n", .{});
        }
        std.debug.print("   PID: {d}\n", .{pid});
        std.debug.print("   Press Ctrl+C to stop\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // DAEMON LOOP — φ² + 1/φ² = 3 — Eternal vigilance
    // ═══════════════════════════════════════════════════════════════════════════════
    var cycle: u64 = 0;

    while (true) {
        cycle += 1;
        const now = std.time.milliTimestamp();

        // OBSERVE
        const dirty = countDirtyFiles(allocator) catch 0;
        const build_ok = checkBuild(allocator) catch false;

        // DECIDE + ACT
        if (!build_ok) {
            try logToHive(allocator, cycle, "⚠️ Build broken", .{});
        } else if (dirty > 0) {
            try logToHive(allocator, cycle, "📝 Dirty files detected", .{});
        }

        // HEARTBEAT — every cycle
        try updateHeartbeat(allocator, cycle, now, dirty, build_ok);

        // SLEEP 60s
        std.Thread.sleep(60 * std.time.ns_per_s);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAEMON HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn countDirtyFiles(allocator: Allocator) !usize {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "status", "--short" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) return 0;

    // Count non-empty lines
    var count: usize = 0;
    var iter = std.mem.splitScalar(u8, result.stdout, '\n');
    while (iter.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn checkBuild(allocator: Allocator) !bool {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

fn updateHeartbeat(allocator: Allocator, cycle: u64, timestamp: i64, dirty: usize, build_ok: bool) !void {
    const heartbeat_dir = ".trinity/queen";
    try std.fs.cwd().makePath(heartbeat_dir);

    const heartbeat_path = try std.fs.path.join(allocator, &.{ heartbeat_dir, "heartbeat.json" });
    defer allocator.free(heartbeat_path);

    const content = try std.fmt.allocPrint(allocator,
        \\{{"cycle":{d},"timestamp":{d},"dirty":{d},"build_ok":{}}}
    , .{ cycle, timestamp, dirty, build_ok });
    defer allocator.free(content);

    try std.fs.cwd().writeFile(.{ .sub_path = heartbeat_path, .data = content });
}

fn logToHive(allocator: Allocator, cycle: u64, msg: []const u8, args: anytype) !void {
    _ = args;
    const hivedir = ".trinity/queen";
    try std.fs.cwd().makePath(hivedir);

    const hivepath = try std.fs.path.join(allocator, &.{ hivedir, "HIVELOG.md" });
    defer allocator.free(hivepath);

    // Read existing content, append new entry
    const existing = std.fs.cwd().readFileAlloc(allocator, hivepath, 4096) catch "";
    defer allocator.free(existing);

    const datetime = std.time.timestamp();
    const entry = try std.fmt.allocPrint(allocator,
        \\## Cycle {d} — {d}
        \\{s}
        \\
        \\
    , .{ cycle, datetime, msg });
    defer allocator.free(entry);

    const combined = try std.fmt.allocPrint(allocator, "{s}{s}", .{ existing, entry });
    defer allocator.free(combined);

    var file = try std.fs.cwd().createFile(hivepath, .{});
    defer file.close();
    try file.writeAll(combined);
}

fn printQueenHelp() void {
    std.debug.print("\n👑 QUEEN TRINITY — Lotus Cycle Protocol\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  tri queen status    Show impure event queue\n", .{});
    std.debug.print("  tri queen purify   Start Lotus Cycle purification\n", .{});
    std.debug.print("  tri queen blocked   Show events that need manual intervention\n", .{});
    std.debug.print("  tri queen start     Start Queen daemon [--daemon, --god-mode]\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen: strand names" {
    try std.testing.expectEqualStrings("I", strandName(.Math));
    try std.testing.expectEqualStrings("II", strandName(.Brain));
    try std.testing.expectEqualStrings("III", strandName(.Lang));
}

test "queen: event type names" {
    try std.testing.expectEqualStrings("BUILD_FAIL", eventName(.BUILD_FAIL));
    try std.testing.expectEqualStrings("TEST_FAIL", eventName(.TEST_FAIL));
}

test "queen: lotus state names" {
    try std.testing.expectEqualStrings("QUEUED", lotusStateName(.Queued));
    try std.testing.expectEqualStrings("PURIFIED", lotusStateName(.Purified));
    try std.testing.expectEqualStrings("BLOCKED", lotusStateName(.Blocked));
}

test "queen: canAttempt" {
    var event = ImpureEvent{ .attempts = 0, .state = .Queued };
    try std.testing.expect(event.canAttempt());

    event.attempts = 3;
    try std.testing.expect(!event.canAttempt());

    event.state = .Blocked;
    try std.testing.expect(!event.canAttempt());
}

test "queen: shouldBlock" {
    var event = ImpureEvent{ .attempts = 2 };
    try std.testing.expect(!event.shouldBlock());

    event.attempts = 3;
    try std.testing.expect(event.shouldBlock());
}
