// ============================================================================
// STREAMING OUTPUT - Real-time Token Display
// Generated from specs/tri/streaming_output.vibee via Golden Chain
// phi^2 + 1/phi^2 = 3 = TRINITY
// ============================================================================

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

pub const StreamConfig = struct {
    enabled: bool = false,
    delay_ms: u32 = 10,
    show_cursor: bool = true,
    color_enabled: bool = true,
};

pub const StreamState = struct {
    is_streaming: bool = false,
    chars_written: u64 = 0,
    start_time: i64 = 0,
};

pub const StreamStats = struct {
    total_chars: u64 = 0,
    duration_ms: u64 = 0,
    chars_per_second: f64 = 0.0,
};

// ============================================================================
// STREAMING OUTPUT IMPLEMENTATION
// ============================================================================

pub const StreamingOutput = struct {
    config: StreamConfig,
    state: StreamState,

    const Self = @This();

    /// Initialize streaming output
    pub fn init(config: StreamConfig) Self {
        return .{
            .config = config,
            .state = .{
                .is_streaming = false,
                .chars_written = 0,
                .start_time = std.time.milliTimestamp(),
            },
        };
    }

    /// Stream a single character with optional delay
    pub fn streamChar(self: *Self, char: u8) void {
        std.debug.print("{c}", .{char});
        self.state.chars_written += 1;

        if (self.config.delay_ms > 0) {
            std.Thread.sleep(self.config.delay_ms * std.time.ns_per_ms);
        }
    }

    /// Stream text with real-time output effect
    pub fn streamText(self: *Self, text: []const u8) void {
        self.state.is_streaming = true;
        self.state.start_time = std.time.milliTimestamp();

        for (text) |char| {
            self.streamChar(char);
        }

        self.state.is_streaming = false;
    }

    /// Stream text with newline at end
    pub fn streamLine(self: *Self, text: []const u8) void {
        self.streamText(text);
        self.streamChar('\n');
    }

    /// Flush output immediately (no delay)
    pub fn flush(self: *Self, text: []const u8) void {
        std.debug.print("{s}", .{text});
        self.state.chars_written += text.len;
    }

    /// Get streaming statistics
    pub fn getStats(self: *const Self) StreamStats {
        const now = std.time.milliTimestamp();
        const duration = @as(u64, @intCast(@max(0, now - self.state.start_time)));
        const chars_per_sec = if (duration > 0)
            @as(f64, @floatFromInt(self.state.chars_written)) / (@as(f64, @floatFromInt(duration)) / 1000.0)
        else
            0.0;

        return .{
            .total_chars = self.state.chars_written,
            .duration_ms = duration,
            .chars_per_second = chars_per_sec,
        };
    }

    /// Print with streaming effect (convenience function)
    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, fmt, args) catch return;
        self.streamText(text);
    }

    /// Print line with streaming effect
    pub fn println(self: *Self, comptime fmt: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, fmt, args) catch return;
        self.streamLine(text);
    }
};

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

/// Create a streaming output with default config (10ms delay)
pub fn createStreaming() StreamingOutput {
    return StreamingOutput.init(.{
        .enabled = true,
        .delay_ms = 10,
        .show_cursor = true,
        .color_enabled = true,
    });
}

/// Create a fast streaming output (1ms delay)
pub fn createFastStreaming() StreamingOutput {
    return StreamingOutput.init(.{
        .enabled = true,
        .delay_ms = 1,
        .show_cursor = true,
        .color_enabled = true,
    });
}

/// Stream text to stderr with default settings
pub fn streamToStderr(text: []const u8) void {
    var stream = createStreaming();
    stream.streamText(text);
}

// ============================================================================
// TESTS
// ============================================================================

test "StreamingOutput init" {
    const stream = StreamingOutput.init(.{});
    try std.testing.expect(!stream.state.is_streaming);
    try std.testing.expectEqual(@as(u64, 0), stream.state.chars_written);
}

test "StreamConfig defaults" {
    const config = StreamConfig{};
    try std.testing.expect(!config.enabled);
    try std.testing.expectEqual(@as(u32, 10), config.delay_ms);
}
