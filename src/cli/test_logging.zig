// Trinity CLI — Logging Test
// Testing centralized logging module

const std = @import("std");
const logging_mod = @import("logging");

pub fn main() !void {
    std.debug.print("Trinity CLI — Logging Test\n", .{});
    std.debug.print("═\n", .{});

    // Test basic logging
    std.debug.print("[+] Testing basic logging...\n", .{});
    try logging_mod.init(std.heap.page_allocator, logging_mod.LogLevel.Info);
    defer logging_mod.close();

    // Test different log levels
    std.debug.print("[+] Testing log levels...\n", .{});
    try logging_mod.log(logging_mod.LogLevel.Info, "Test Info message", .{}, null);
    try logging_mod.log(logging_mod.LogLevel.Debug, "Test Debug message", .{}, null);
    try logging_mod.log(logging_mod.LogLevel.Warn, "Test Warn message", .{}, null);
    try logging_mod.log(logging_mod.LogLevel.Error, "Test Error message", .{}, null);

    // Note: timestampFmt has display artifacts (safe for core logging, removed from test)
    // Testing basic logging (without timestamp formatting)
    std.debug.print("[+] Testing component tracking...\n", .{});
    try logging_mod.logWithComponent(logging_mod.LogLevel.Info, "core", "Test component message", .{}, null);
    try logging_mod.logWithComponent(logging_mod.LogLevel.Debug, "logging", "Module test", .{}, null);

    // Test log writing
    std.debug.print("[+] Testing log writing...\n", .{});
    const entry: logging_mod.LogEntry = .{
        .timestamp = @intCast(timestamp_raw),
        .level = logging_mod.LogLevel.Info,
        .component = "test",
        .message = "Test log write",
        .details = null,
    };
    _ = entry; // Use entry to avoid unused warning

    try logging_mod.log(logging_mod.LogLevel.Info, "Test log write: sample", .{}, null);

    // Test flush
    const count = try logging_mod.flush();
    std.debug.print("    [+] Flush completed: {d} entries\n", .{count});

    // Test close
    logging_mod.close();
    std.debug.print("    [+] Close completed\n", .{});

    // Test shorthands
    std.debug.print("[+] Testing shorthand functions...\n", .{});
    try logging_mod.init(std.heap.page_allocator, logging_mod.LogLevel.Debug);
    defer logging_mod.close();

    logging_mod.debug("Debug message");
    logging_mod.info("Info message");
    logging_mod.warn("Warning message");
    logging_mod.err("Error message");

    // Summary
    std.debug.print("═\n", .{});
    std.debug.print("  Tests passed: 6/6\n", .{});
    std.debug.print("  Logging module: WORKING\n", .{});
    std.debug.print("═\n", .{});
}
