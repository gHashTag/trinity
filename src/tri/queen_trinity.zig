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
    allocator: std.mem.Allocator,
    events: std.ArrayList(ImpureEvent),

    pub fn init(allocator: std.mem.Allocator) ImpureQueue {
        return .{
            .allocator = allocator,
            .events = std.ArrayList(ImpureEvent).init(allocator),
        };
    }

    pub fn deinit(self: *ImpureQueue) void {
        self.events.deinit();
    }

    pub fn load(self: *ImpureQueue) !void {
        self.events.clearRetainingCapacity();

        const dir = std.fs.cwd().openDir(IMPURE_DIR, .{ .iterate = true }) catch {
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

            const content = try serializeImpureEvent(&event, self.allocator);
            defer self.allocator.free(content);

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

fn parseImpureEvent(event: *ImpureEvent, json_str: []const u8) bool {
    const Parse = struct {
        id: []const u8,
        strand: []const u8,
        event_type: []const u8,
        source_file: []const u8,
        error_msg: []const u8,
        timestamp: i64,
        attempts: u8,
        state: []const u8,
    };

    const parsed = std.json.parse(Parse, json_str, .{ .ignore_unknown_fields = true }) catch {
        return false;
    };

    // Copy id (truncate if needed)
    const id_len = @min(parsed.id.len, event.id.len);
    @memcpy(event.id[0..id_len], parsed.id[0..id_len]);

    // Parse strand
    event.strand = std.meta.stringToEnum(Strand, parsed.strand) orelse .Math;

    // Parse event_type
    event.event_type = std.meta.stringToEnum(ImpureEventType, parsed.event_type) orelse .BUILD_FAIL;

    // Copy source_file
    const sf_len = @min(parsed.source_file.len, event.source_file.len);
    @memcpy(event.source_file[0..sf_len], parsed.source_file[0..sf_len]);
    event.source_file_len = @intCast(sf_len);

    // Copy error_msg
    const em_len = @min(parsed.error_msg.len, event.error_msg.len);
    @memcpy(event.error_msg[0..em_len], parsed.error_msg[0..em_len]);
    event.error_msg_len = @intCast(em_len);

    event.timestamp = parsed.timestamp;
    event.attempts = parsed.attempts;

    // Parse state
    event.state = std.meta.stringToEnum(LotusState, parsed.state) orelse .Queued;

    return true;
}

fn serializeImpureEvent(event: *const ImpureEvent, allocator: std.mem.Allocator) ![]u8 {
    const strand_str = strandName(event.strand);
    const type_str = eventName(event.event_type);

    const state_str = switch (event.state) {
        .Queued => "Queued",
        .Diagnosing => "Diagnosing",
        .Refining => "Refining",
        .Verifying => "Verifying",
        .Purified => "Purified",
        .Blocked => "Blocked",
    };

    return std.fmt.allocPrint(allocator,
        \\{{"id":"{s}","strand":"{s}","event_type":"{s}","source_file":"{s}","error_msg":"{s}","timestamp":{d},"attempts":{d},"state":"{s}"}}
    , .{
        event.id[0..64],
        strand_str,
        type_str,
        std.zig.fmtEscapes(event.sourceFileStr()),
        std.zig.fmtEscapes(event.errorMsgStr()),
        event.timestamp,
        event.attempts,
        state_str,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runQueenCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "status")) {
        return runQueenStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "start")) {
        return runQueenStart(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "purify")) {
        return runQueenPurify(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "blocked")) {
        return runQueenBlocked(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printQueenHelp();
    } else {
        std.debug.print("Unknown queen subcommand: {s}\n", .{subcmd});
        printQueenHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAEMON MODE — Queen Trinity Supervision Loop
// ═══════════════════════════════════════════════════════════════════════════════

const PID_FILE = "/tmp/trinity-queen.pid";
const HEARTBEAT_FILE = ".trinity/queen/heartbeat.json";
const DAEMON_SLEEP_SEC = 60;

// ═══════════════════════════════════════════════════════════════════════════════
// GITHUB INTEGRATION — Queen works on issues!
// ═══════════════════════════════════════════════════════════════════════════════

fn workOnGithubIssue(allocator: std.mem.Allocator, cycle: u64) !bool {
    _ = cycle;

    // Fetch open GitHub issues
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "issue", "list", "--state", "open", "--limit", "1", "--json", "number,title" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0 or result.stdout.len == 0) {
        return false; // No issues or gh error
    }

    // Parse JSON to get issue number
    const issue_str = result.stdout;
    if (std.mem.indexOf(u8, issue_str, "\"number\":") == null) {
        return false;
    }

    // Extract issue number (simple parsing)
    const number_start = std.mem.indexOf(u8, issue_str, "\"number\":") orelse return false;
    const num_part = issue_str[number_start + 9 ..];
    const number_end = std.mem.indexOf(u8, num_part, ",") orelse num_part.len;
    const number_str = num_part[0..number_end];

    // Extract title
    const title_start = std.mem.indexOf(u8, issue_str, "\"title\":") orelse return false;
    const title_part = issue_str[title_start + 9 ..];
    const title_end = std.mem.indexOf(u8, title_part, "\"}") orelse title_part.len;
    const title_json = title_part[0..title_end];

    std.debug.print("🔧 Queen working on issue #{s}: {s}\n", .{ number_str, title_json });

    // TODO: Actually work on the issue
    // For now, just comment that Queen is aware
    const comment = try std.fmt.allocPrint(allocator, "👑 Queen acknowledges issue #{s} (cycle check)", .{number_str});
    defer allocator.free(comment);

    // Comment on issue (disabled for now - uncomment when ready)
    // _ = std.process.Child.run(.{
    //     .allocator = allocator,
    //     .argv = &.{ "gh", "issue", "comment", number_str, "--body", comment },
    // });

    return true;
}

fn runQueenStart(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    // Create PID file
    const pid = std.c.getpid();
    {
        var f = try std.fs.cwd().createFile(PID_FILE, .{});
        defer f.close();
        var buf: [32]u8 = undefined;
        const pid_str = try std.fmt.bufPrint(&buf, "{d}", .{pid});
        try f.writeAll(pid_str);
    }
    defer std.fs.deleteFileAbsolute(PID_FILE) catch {};

    // Create heartbeat directory
    std.fs.cwd().makePath(".trinity/queen") catch {};

    std.debug.print("👑 Queen Trinity starting daemon mode (PID {d})\n", .{pid});

    var cycle: u64 = 0;

    // DAEMON LOOP — infinite until killed
    while (true) {
        cycle += 1;
        const now = std.time.milliTimestamp();

        // OBSERVE: check system state
        const dirty = countDirtyFiles(allocator) catch 0;
        const build_ok = checkBuild(allocator) catch false;

        // GITHUB INTEGRATION: work on issues!
        if (build_ok and dirty == 0) {
            // System clean — work on GitHub issues
            const issue_worked = try workOnGithubIssue(allocator, cycle);
            if (issue_worked) {
                try logToHive(allocator, cycle, "🔧 Worked on GitHub issue", .{});
            }
        }

        // DECIDE + ACT: log issues
        if (!build_ok) {
            try logToHive(allocator, cycle, "⚠️ Build broken", .{});
        } else if (dirty > 0) {
            try logToHive(allocator, cycle, "📝 Dirty files detected", .{});
        } else {
            try logToHive(allocator, cycle, "✅ System stable", .{});
        }

        // HEARTBEAT: update liveness
        try updateHeartbeat(allocator, cycle, now);

        // SLEEP until next cycle
        std.Thread.sleep(DAEMON_SLEEP_SEC * 1000_000_000);
    }
}

fn countDirtyFiles(allocator: std.mem.Allocator) !usize {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "status", "--short" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    var count: usize = 0;
    var iter = std.mem.splitScalar(u8, result.stdout, '\n');
    while (iter.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn checkBuild(allocator: std.mem.Allocator) !bool {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build" },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    // Check if process exited cleanly (exit code 0)
    return result.term == .Exited and result.term.Exited == 0;
}

fn updateHeartbeat(allocator: std.mem.Allocator, cycle: u64, timestamp: i64) !void {
    const content = try std.fmt.allocPrint(allocator, "{{\"cycle\":{d},\"timestamp\":{d}}}\n", .{ cycle, timestamp });
    defer allocator.free(content);

    var f = try std.fs.cwd().createFile(HEARTBEAT_FILE, .{ .truncate = true });
    defer f.close();
    try f.writeAll(content);
}

fn logToHive(allocator: std.mem.Allocator, cycle: u64, msg: []const u8, args: anytype) !void {
    _ = args;
    const timestamp = std.time.milliTimestamp();
    const formatted = try std.fmt.allocPrint(allocator, "[{d}] Cycle {d}: {s}\n", .{ timestamp, cycle, msg });
    defer allocator.free(formatted);

    const log_file = ".trinity/queen/HIVELOG.md";
    std.fs.cwd().makePath(".trinity/queen") catch {};

    // Try to append to existing file, or create new one
    var f = std.fs.cwd().openFile(log_file, .{ .mode = .write_only }) catch {
        // File doesn't exist, create it with header
        var new_f = try std.fs.cwd().createFile(log_file, .{});
        defer new_f.close();
        try new_f.writeAll("# Queen Trinity Hive Log\n\n");
        try new_f.writeAll(formatted);
        return;
    };
    defer f.close();

    // Seek to end before writing (append mode)
    try f.seekFromEnd(0);
    try f.writeAll(formatted);
}

fn runQueenStatus(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print("\n👑 QUEEN TRINITY STATUS\n", .{});
    std.debug.print("═════════════════════════\n\n", .{});
    std.debug.print("Impure event queue: .trinity/impure/\n", .{});
    std.debug.print("Lotus Cycle: φ² + 1/φ² = 3\n\n", .{});
    std.debug.print("Status: TODO - implement event loading\n", .{});
}

fn runQueenPurify(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    std.debug.print("🌸 LOTUS CYCLE PURIFICATION\n", .{});
    std.debug.print("═════════════════════════════\n\n", .{});
    std.debug.print("Purify mode: TODO - implement\n", .{});
}

fn runQueenBlocked(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print("🚫 BLOCKED EVENTS\n", .{});
    std.debug.print("══════════════════\n\n", .{});
    std.debug.print("No blocked events tracked yet.\n", .{});
}

fn printQueenHelp() void {
    std.debug.print("\n👑 QUEEN TRINITY — Lotus Cycle Protocol\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  tri queen status    Show impure event queue\n", .{});
    std.debug.print("  tri queen start     Start daemon mode (PID file + heartbeat)\n", .{});
    std.debug.print("  tri queen purify   Start Lotus Cycle purification\n", .{});
    std.debug.print("  tri queen blocked   Show events that need manual intervention\n\n", .{});
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
