// Test configuration
const Config = struct {
    baud: u64,
    delay_ms: u32,
    timeout_ms: u32,
    verbose: bool,
    ping_mode: bool,
    auto_configure: bool,
    device: ?[]const u8,
    continuous: bool,
    json_output: bool,
};

// PING/PONG protocol
const PING_BYTE: u8 = 0x03; // Send PING
const PONG_BYTE: u8 = 0x83; // Expect PONG response

// Helper for formatted stderr output
fn printErr(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// Parse command line arguments
fn parseArgs() Config {
    var config = Config{
        .baud = DEFAULT_BAUD,
        .delay_ms = DEFAULT_DELAY_MS,
        .timeout_ms = DEFAULT_TIMEOUT_MS,
        .verbose = false,
        .ping_mode = false,
        .auto_configure = false,
        .device = null,
        .continuous = false,
        .json_output = false,
    };
