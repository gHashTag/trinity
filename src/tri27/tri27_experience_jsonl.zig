// TRI‑27 Experience — Episode/JSONL Integration for TRI‑27 operations
// ══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const tri27_exp = @import("tri27_experience.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

// ══════════════════════════════════════════════════════════════════════

// TRI‑27 specific extensions for Episode
pub const Tri27EventKind = enum(u8) {
    assemble = 1,
    disassemble = 2,
    run = 3,
    @"test" = 4,
    validate = 5,
    flash = 6,
    dump = 7,

    pub fn toStr(self: Tri27EventKind) []const u8 {
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

// Save TRI‑27 episode to Episode/JSONL storage
pub fn saveTri27Episode(
    allocator: Allocator,
    kind: Tri27EventKind,
    input_file: []const u8,
    output_file: []const u8,
    status: tri27_exp.Tri27Status,
    cycles: u32,
    instructions: u32,
    error_msg: []const u8,
) !void {
    _ = allocator;
    _ = output_file;
    _ = error_msg;

    // Create event and record via tri27_experience
    var event = tri27_exp.Tri27Event{
        .timestamp = std.time.timestamp(),
        .operation = switch (kind) {
            .assemble => .assemble,
            .disassemble => .disassemble,
            .run => .run,
            .@"test" => .@"test",
            .validate => .validate,
            .flash => .flash,
            .dump => .dump,
        },
        .input_file = [_]u8{0} ** 256,
        .output_file = [_]u8{0} ** 256,
        .status = status,
        .cycles = cycles,
        .instructions = instructions,
        .error_msg = [_]u8{0} ** 512,
        .has_error = false,
    };

    // Copy input file path
    const copy_len = @min(255, input_file.len);
    @memcpy(event.input_file[0..copy_len], input_file[0..copy_len]);
    if (copy_len < 255) event.input_file[copy_len] = 0;

    tri27_exp.logEvent(event);
    print("{s}✅ TRI‑27 episode logged ({s} {s}){s}\n", .{
        GREEN, kind.toStr(), input_file, RESET,
    });
}
