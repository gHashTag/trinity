const std = @import("std");
const telegram_pulse = @import("telegram_pulse.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Testing RALPH PULSE OF LIFE...\n", .{});

    // Load config from environment
    const config = try telegram_pulse.loadConfig(allocator);
    if (!config.enabled) {
        std.debug.print("Pulse disabled. Set RALPH_PULSE_ENABLED=true\n", .{});
        return;
    }

    // Test all pulse types
    try telegram_pulse.sendPulse(allocator, config, .thought, "Ralph is thinking about fix_plan.md");

    try telegram_pulse.sendPulse(allocator, config, .action, "Running: zig build vibee");

    try telegram_pulse.sendPulse(allocator, config, .state_change, "idle -> analyzing");

    try telegram_pulse.sendPulse(allocator, config, .heartbeat, "Loop 1 | API calls: 5");

    try telegram_pulse.sendPulse(allocator, config, .milestone, "RALPH PULSE OF LIFE v1.0 is WORKING!");

    std.debug.print("All pulses sent! Check Telegram @vibee_dev_bot\n", .{});
}
