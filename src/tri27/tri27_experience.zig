// TRI‑27 Experience — Episode tracking for TRI‑27 operations
// Self-contained implementation (no external dependencies)
// ═════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const EPISODES_DIR = ".trinity/tri27/episodes";

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// ═════════════════════════════════════════════════════════════════════════════════

pub const EventLogSize = 32;

pub const Tri27Operation = enum(u8) {
    assemble = 1,
    disassemble = 2,
    run = 3,
    validate = 4,

    pub fn toStr(self: Tri27Operation) []const u8 {
        return switch (self) {
            .assemble => "ASSEMBLE",
            .disassemble => "DISASSEMBLE",
            .run => "RUN",
            .validate => "VALIDATE",
        };
    }
};

pub const Tri27Status = enum(u8) {
    queued = 1,
    in_progress = 2,
    success = 3,
    failure = 4,

    pub fn toStr(self: Tri27Status) []const u8 {
        return switch (self) {
            .queued => "QUEUED",
            .in_progress => "IN_PROGRESS",
            .success => "SUCCESS",
            .failure => "FAILURE",
        };
    }

    pub fn isSuccess(self: Tri27Status) bool {
        return self == .success;
    }
};

pub const Tri27Event = struct {
    timestamp: i64,
    operation: Tri27Operation,
    input_file: [256]u8,
    output_file: [256]u8,
    status: Tri27Status,
    cycles: u32 = 0,
    instructions: u32 = 0,
    error_msg: [512]u8 = undefined,
    has_error: bool = false,

    pub fn statusStr(self: Tri27Event) []const u8 {
        return self.status.toStr();
    }

    pub fn inputFile(self: Tri27Event) []const u8 {
        const len = self.indexOfNull(self.input_file);
        return self.input_file[0..len];
    }

    pub fn outputFile(self: Tri27Event) []const u8 {
        const len = self.indexOfNull(self.output_file);
        return self.output_file[0..len];
    }

    pub fn errorMsg(self: Tri27Event) []const u8 {
        if (!self.has_error) return "";
        const len = self.indexOfNull(self.error_msg);
        return self.error_msg[0..len];
    }

    fn indexOfNull(buf: []const u8) usize {
        var i: usize = 0;
        while (i < buf.len) {
            if (buf[i] == 0) return i;
            i += 1;
        }
        return buf.len;
    }
};

// Simple Episode struct for TRI‑27 (self-contained)
const Episode = struct {
    issue: u32 = 0,
    task: [256]u8 = undefined,
    task_len: u8 = 0,
    verdict: [16]u8 = undefined,
    timestamp: i64 = 0,

    pub fn save(self: Episode) !void {
        // Ensure directory exists
        std.fs.cwd().makePath(EPISODES_DIR) catch {};

        // Build filename: {issue}_{timestamp}.json
        var fname_buf: [64]u8 = undefined;
        const fname = std.fmt.bufPrint(&fname_buf, "{d}_{d}.json", .{
            self.issue,
            self.timestamp,
        }) catch return error.OutOfMemory;

        // Build JSON
        var buf: [8192]u8 = undefined;
        var pos: usize = 0;

        pos += (std.fmt.bufPrint(buf[pos..], "{{\"issue\":{d},\"task\":\"{s}\",\"verdict\":\"{s}\",\"timestamp\":{d}}}", .{
            self.issue,
            self.task[0..self.task_len],
            self.verdict[0..],
            self.timestamp,
        }) catch return error.OutOfMemory).len;

        // Write to file
        var dir = try std.fs.cwd().openDir(EPISODES_DIR, .{});
        defer dir.close();
        var file = try dir.createFile(fname, .{});
        defer file.close();
        try file.writeAll(buf[0..pos]);
    }
};

// Circular event buffer for TRI‑27 operations
var event_buffer: [EventLogSize]Tri27Event = undefined;
var event_count: usize = 0;
var buffer_initialized: bool = false;

pub fn initEventLog() void {
    event_count = 0;
    buffer_initialized = true;
    // Reset buffer with default events
    var i: usize = 0;
    while (i < EventLogSize) : (i += 1) {
        event_buffer[i] = .{
            .timestamp = 0,
            .operation = .assemble,
            .input_file = [_]u8{0} ** 256,
            .output_file = [_]u8{0} ** 256,
            .status = .queued,
            .cycles = 0,
            .instructions = 0,
            .error_msg = [_]u8{0} ** 512,
            .has_error = false,
        };
    }
}

pub fn logEvent(event: Tri27Event) void {
    if (!buffer_initialized) initEventLog();

    event_buffer[event_count] = event;
    event_count = (event_count + 1) % EventLogSize;
}

pub fn getLastEvent() ?*const Tri27Event {
    if (event_count == 0 and !buffer_initialized) {
        return null;
    }
    const idx = if (event_count == 0) EventLogSize - 1 else event_count - 1;
    return &event_buffer[idx];
}

pub fn recordEpisodeFromEvent(event: Tri27Event, issue: u32) !void {
    var episode = Episode{};
    episode.issue = issue;
    episode.timestamp = event.timestamp;

    // Build task: "{op} {input}"
    const op_str = event.operation.toStr();
    const input_str = event.inputFile();
    var task_fmt_buf: [256]u8 = undefined;
    const task_len = std.fmt.bufPrint(&task_fmt_buf, "{s} {s}", .{ op_str, input_str }) catch "";
    // Copy task to episode
    var i: usize = 0;
    while (i < task_len) : (i += 1) {
        episode.task[i] = task_fmt_buf[i];
    }
    episode.task_len = @intCast(task_len);

    // Set verdict based on status
    const is_success = std.mem.eql(u8, event.statusStr(), "SUCCESS") or
        std.mem.eql(u8, event.statusStr(), "PASS") or
        std.mem.eql(u8, event.statusStr(), "COMPLETED");
    if (is_success) {
        std.mem.copyFor(u8, episode.verdict[0..], "SUCCESS");
    } else {
        std.mem.copyFor(u8, episode.verdict[0..], "FAILURE");
    }

    // Save episode directly
    try episode.save();
}

pub fn runStatus() !void {
    if (event_count == 0) {
        print("{s}No TRI‑27 events recorded\n", .{CYAN});
        return;
    }

    print("{s}═══ TRI‑27 Event History ({d} events) ═══{s}\n", .{ BOLD, event_count, RESET });
    var i: usize = 0;
    const start_idx = if (event_count >= EventLogSize) event_count - EventLogSize else 0;
    const display_count = @min(EventLogSize, event_count);

    while (i < display_count) : (i += 1) {
        const idx = (start_idx + i) % EventLogSize;
        const event = &event_buffer[idx];
        const status_color = if (event.status.isSuccess()) GREEN else RED;
        const status_text = event.statusStr();

        print("  [{d}] {s}{s}{s} {s}{s} → {s}{s}{s}\n", .{
            i + 1,        DIM,               RESET, opToString(event.operation),
            BOLD,         event.inputFile(), DIM,   RESET,
            status_color, status_text,       RESET,
        });
    }
}

fn opToString(op: Tri27Operation) []const u8 {
    return switch (op) {
        .assemble => "ASM",
        .disassemble => "DISASM",
        .run => "RUN",
        .validate => "VAL",
    };
}

pub fn runTri27ExperienceCommand(_: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printUsage();
        return;
    }

    const subcmd = args[0];

    if (std.mem.eql(u8, subcmd, "init")) {
        initEventLog();
        print("{s}TRI‑27 experience log initialized\n", .{GREEN});
    } else if (std.mem.eql(u8, subcmd, "log")) {
        try logCommand(args[1..]);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        try runStatus();
    } else if (std.mem.eql(u8, subcmd, "record")) {
        try recordCommand(args[1..]);
    } else {
        print("{s}Unknown command: {s}\n", .{ RED, subcmd });
        printUsage();
    }
}

fn logCommand(args: []const []const u8) !void {
    const input_file = if (args.len > 0) args[0] else "";
    const operation_str = if (args.len > 1) args[1] else "RUN";

    var event = Tri27Event{};
    event.timestamp = std.time.timestamp();
    event.operation = parseOperation(operation_str);

    var i: usize = 0;
    const copy_len = @min(255, input_file.len);
    while (i < copy_len) : (i += 1) {
        event.input_file[i] = input_file[i];
    }
    if (copy_len < 255) {
        event.input_file[copy_len] = 0;
    }

    event.status = .success;
    logEvent(event);

    print("{s}Logged: {s} {s} → {s}\n", .{ GREEN, event.operation.toStr(), input_file, RESET });
}

fn recordCommand(args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri27-tri27-experience record <issue_number>\n", .{YELLOW});
        return;
    }

    const issue_str = args[0];
    const issue_num = try std.fmt.parseInt(u32, issue_str, 10);

    const event_opt = getLastEvent();
    const event = if (event_opt) |ev| ev else {
        print("{s}No events to record. Use 'log' first.\n", .{YELLOW});
        return;
    };

    try recordEpisodeFromEvent(event.*, issue_num);
    print("{s}Episode #{d} recorded for issue #{d}\n", .{ GREEN, event.timestamp, issue_num });
}

pub fn parseOperation(str: []const u8) Tri27Operation {
    if (std.mem.eql(u8, str, "ASM")) return .assemble;
    if (std.mem.eql(u8, str, "DISASM")) return .disassemble;
    if (std.mem.eql(u8, str, "RUN")) return .run;
    if (std.mem.eql(u8, str, "VAL")) return .validate;
    return .run; // default
}

fn printUsage() void {
    print("{s}TRI‑27 Experience Module\n", .{BOLD});
    print("\n{s}Commands:\n", .{DIM});
    print("  {s}init{s}                    Initialize event log\n", .{ GREEN, RESET });
    print("  {s}log <file> [ASM|DISASM|RUN|VAL]{s}  Log operation\n", .{ GREEN, RESET });
    print("  {s}status{s}                   Show event history\n", .{ GREEN, RESET });
    print("  {s}record <issue>{s}            Record episode from last event\n", .{ GREEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════

test "Tri27Operation toStr roundtrip" {
    const op = Tri27Operation.assemble;
    const str = op.toStr();
    try std.testing.expectEqualStrings("ASSEMBLE", str);
}
