// TRI‑27 Experience — Episode tracking for TRI‑27 operations
// Self-contained implementation (no external dependencies)
// ═════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Queen episode integration
const queen_episodes = @import("queen_episodes");

const EPISODES_DIR = ".trinity/tri27/episodes";

const print = std.debug.print;

pub const FormatError = error{FormatError};

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
    @"test" = 4,
    validate = 5,
    flash = 6,
    dump = 7,

    pub fn toStr(self: Tri27Operation) []const u8 {
        return switch (self) {
            .assemble => "ASSEMBLE",
            .disassemble => "DISASSEMBLE",
            .run => "RUN",
            .@"test" => "TEST",
            .validate => "VALIDATE",
            .flash => "FLASH",
            .dump => "DUMP",
        };
    }
};

pub const Tri27Status = enum(u8) {
    queued = 1,
    running = 2,
    success = 3,
    failed = 4,
    timeout = 5,
    cancelled = 6,

    pub fn toStr(self: Tri27Status) []const u8 {
        return switch (self) {
            .queued => "QUEUED",
            .running => "RUNNING",
            .success => "SUCCESS",
            .failed => "FAILED",
            .timeout => "TIMEOUT",
            .cancelled => "CANCELLED",
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
        const len = indexOfNull(&self.input_file);
        return self.input_file[0..len];
    }

    pub fn outputFile(self: Tri27Event) []const u8 {
        const len = indexOfNull(&self.output_file);
        return self.output_file[0..len];
    }

    pub fn errorMsg(self: Tri27Event) []const u8 {
        if (!self.has_error) return "";
        const len = indexOfNull(&self.error_msg);
        return self.error_msg[0..len];
    }
};

fn indexOfNull(buf: []const u8) usize {
    var i: usize = 0;
    while (i < buf.len) {
        if (buf[i] == 0) return i;
        i += 1;
    }
    return buf.len;
}

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
    @memset(std.mem.sliceAsBytes(&event_buffer), 0);
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
    const task_len = blk: {
        const result = std.fmt.bufPrint(&task_fmt_buf, "{s} {s}", .{ op_str, input_str }) catch |err| {
            std.debug.print("Error formatting task: {}\n", .{err});
            break :blk @as(usize, 0);
        };
        break :blk result.len;
    };
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
        @memcpy(episode.verdict[0..7], "SUCCESS");
        episode.verdict[7] = 0;
    } else {
        episode.verdict[0] = 'F';
        episode.verdict[1] = 'A';
        episode.verdict[2] = 'I';
        episode.verdict[3] = 'L';
        episode.verdict[4] = 'U';
        episode.verdict[5] = 'R';
        episode.verdict[6] = 'E';
    }

    // Save episode directly
    try episode.save();
}

/// Record TRI‑27 event to Queen episode system
/// This integrates tri27_experience with Queen Episode framework
pub fn recordToQueenEpisodes(allocator: Allocator, event: Tri27Event) !void {
    // Debug: check what inputFile() returns
    const input_slice = event.inputFile();
    std.debug.print("DEBUG: inputFile() len={d}, content='{s}'\n", .{ input_slice.len, input_slice });

    // Convert to Queen Tri27Event format
    const queen_event = queen_episodes.Tri27Event{
        .timestamp = event.timestamp,
        .operation = switch (event.operation) {
            .assemble => .assemble,
            .disassemble => .disassemble,
            .run => .run,
            .@"test" => .@"test",
            .validate => .validate,
            .flash => .flash,
            .dump => .dump,
        },
        .input_file = event.inputFile(),
        .output_file = event.outputFile(),
        .status = switch (event.status) {
            .queued => .queued,
            .running => .running,
            .success => .success,
            .failed => .failed,
            .timeout => .timeout,
            .cancelled => .cancelled,
        },
        .cycles = event.cycles,
        .instructions = event.instructions,
        .error_msg = event.errorMsg(),
        .has_error = event.has_error,
    };

    // Record to Queen episodes.jsonl
    _ = try queen_episodes.recordTri27Episode(allocator, queen_event);
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
            i + 1, DIM,               RESET,        opToString(event.operation),
            BOLD,  event.inputFile(), status_color, status_text,
            RESET,
        });
    }
}

fn opToString(op: Tri27Operation) []const u8 {
    return switch (op) {
        .assemble => "ASM",
        .disassemble => "DISASM",
        .run => "RUN",
        .@"test" => "TEST",
        .validate => "VAL",
        .flash => "FLASH",
        .dump => "DUMP",
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
    if (std.mem.eql(u8, str, "TEST")) return .@"test";
    if (std.mem.eql(u8, str, "VAL")) return .validate;
    if (std.mem.eql(u8, str, "FLASH")) return .flash;
    if (std.mem.eql(u8, str, "DUMP")) return .dump;
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

test "tri27_experience: recordToQueenEpisodes integration" {
    const allocator = std.testing.allocator;

    // Create test event directly with queen_episodes.Tri27Event
    const queen_event = queen_episodes.Tri27Event{
        .timestamp = 1234567890,
        .operation = .assemble,
        .input_file = "test.tasm",
        .output_file = "test.tbin",
        .status = .success,
        .cycles = 42,
        .instructions = 10,
        .error_msg = "",
        .has_error = false,
    };

    // Record to Queen episodes
    _ = try queen_episodes.recordTri27Episode(allocator, queen_event);

    // Verify episodes.jsonl was created and contains the event
    const file_path = ".trinity/queen/episodes.jsonl";
    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        std.debug.print("Error: episodes.jsonl not created\n", .{});
        return error.FileNotFound;
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 4096) catch "";
    defer allocator.free(contents);

    // Verify JSON contains expected fields
    const has_input = std.mem.indexOf(u8, contents, "test.tasm") != null;
    const has_operation = std.mem.indexOf(u8, contents, "assemble") != null;
    const has_source = std.mem.indexOf(u8, contents, "tri27") != null;
    const has_success = std.mem.indexOf(u8, contents, "\"success\":true") != null;

    try std.testing.expect(has_input);
    try std.testing.expect(has_operation);
    try std.testing.expect(has_source);
    try std.testing.expect(has_success);
}
