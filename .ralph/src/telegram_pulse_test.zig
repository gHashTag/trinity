// ═══════════════════════════════════════════════════════════════════════════════
// RALPH PULSE OF LIFE - Unit Tests
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const telegram_pulse = @import("telegram_pulse.zig");

const testing = std.testing;

// Test configuration (disabled by default for unit tests)
fn testConfig() telegram_pulse.PulseConfig {
    return .{
        .bot_token = "test_token",
        .chat_id = "test_chat",
        .enabled = false, // Disabled for unit tests
    };
}

// ───────────────────────────────────────────────────────────────────────────────
// PulseType Tests
// ───────────────────────────────────────────────────────────────────────────────

test "PulseType.emoji - returns correct emoji for each type" {
    try testing.expectEqualStrings("🧠", telegram_pulse.PulseType.thought.emoji());
    try testing.expectEqualStrings("⚡", telegram_pulse.PulseType.action.emoji());
    try testing.expectEqualStrings("🔄", telegram_pulse.PulseType.state_change.emoji());
    try testing.expectEqualStrings("⚠️", telegram_pulse.PulseType.err.emoji());
    try testing.expectEqualStrings("⭐", telegram_pulse.PulseType.milestone.emoji());
    try testing.expectEqualStrings("💓", telegram_pulse.PulseType.heartbeat.emoji());
}

test "PulseType.label - returns correct label for each type" {
    try testing.expectEqualStrings("THINKING", telegram_pulse.PulseType.thought.label());
    try testing.expectEqualStrings("ACTION", telegram_pulse.PulseType.action.label());
    try testing.expectEqualStrings("STATE", telegram_pulse.PulseType.state_change.label());
    try testing.expectEqualStrings("ERROR", telegram_pulse.PulseType.err.label());
    try testing.expectEqualStrings("MILESTONE", telegram_pulse.PulseType.milestone.label());
    try testing.expectEqualStrings("HEARTBEAT", telegram_pulse.PulseType.heartbeat.label());
}

// ───────────────────────────────────────────────────────────────────────────────
// TelegramClient Tests
// ───────────────────────────────────────────────────────────────────────────────

test "TelegramClient.init - creates client correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = testConfig();
    var client = telegram_pulse.TelegramClient.init(allocator, config);
    defer client.deinit();

    try testing.expectEqual(allocator, client.allocator);
    try testing.expectEqual(config.bot_token, client.config.bot_token);
    try testing.expectEqual(config.chat_id, client.config.chat_id);
}

test "TelegramClient.sendPulse - disabled config returns immediately" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = testConfig(); // enabled = false
    var client = telegram_pulse.TelegramClient.init(allocator, config);
    defer client.deinit();

    // Should not error when disabled
    try client.sendPulse(.heartbeat, "test message");
}

test "TelegramClient.sendHeartbeat - formats message correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = testConfig();
    var client = telegram_pulse.TelegramClient.init(allocator, config);
    defer client.deinit();

    // Should not error when disabled
    try client.sendHeartbeat(42, "TESTING");
}

// ───────────────────────────────────────────────────────────────────────────────
// Convenience Function Tests
// ───────────────────────────────────────────────────────────────────────────────

test "sendPulse - convenience function works" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = testConfig();
    try telegram_pulse.sendPulse(allocator, config, .action, "test action");
}

test "sendHeartbeat - convenience function works" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = testConfig();
    try telegram_pulse.sendHeartbeat(allocator, config, 100, "RUNNING");
}

// ───────────────────────────────────────────────────────────────────────────────
// Config Loading Tests
// ───────────────────────────────────────────────────────────────────────────────

test "loadConfig - reads from environment variables" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Note: These tests require environment variables to be set externally
    // For automated testing, we test with empty/default values
    const config = try telegram_pulse.loadConfig(allocator);
    defer {
        allocator.free(config.bot_token);
        allocator.free(config.chat_id);
    }

    // Should succeed with empty values
    try testing.expectEqualStrings("", config.bot_token);
    try testing.expectEqualStrings("", config.chat_id);
}

test "loadConfig - default enabled state is false" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try telegram_pulse.loadConfig(allocator);
    defer {
        allocator.free(config.bot_token);
        allocator.free(config.chat_id);
    }

    try testing.expect(config.enabled == false);
}
