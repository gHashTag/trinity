//! MCP Streaming Module
//!
//! Provides progress reporting for long-running commands.
//! φ² + 1/φ² = 3 = TRINITY
// @origin(manual) @regen(pending)

const std = @import("std");

/// Progress reporting state
pub const ProgressState = enum {
    idle,
    running,
    complete,
    errored,
};

/// Progress update
pub const ProgressUpdate = struct {
    state: ProgressState,
    message: []const u8,
    progress: f64 = 0.0, // 0.0 to 1.0
    total: ?usize = null,
    current: ?usize = null,
};

/// Streaming context for long-running operations
pub const StreamingContext = struct {
    allocator: std.mem.Allocator,
    operation_id: []const u8,
    state: ProgressState = .idle,
    start_time: i64,
    last_update: i64,

    pub fn init(allocator: std.mem.Allocator, operation_id: []const u8) !StreamingContext {
        const id_copy = try allocator.dupe(u8, operation_id);
        const now = std.time.nanoTimestamp();
        return .{
            .allocator = allocator,
            .operation_id = id_copy,
            .start_time = now,
            .last_update = now,
        };
    }

    pub fn deinit(self: *StreamingContext) void {
        self.allocator.free(self.operation_id);
    }

    /// Format progress as JSON-RPC notification
    pub fn formatProgress(self: *StreamingContext, update: ProgressUpdate, writer: anytype) !void {
        const now = std.time.nanoTimestamp();
        self.last_update = now;
        self.state = update.state;

        // Calculate percentage (guard: total=0 → use progress field)
        const percentage = if (update.total != null and update.current != null and update.total.? > 0)
            @as(f64, @floatFromInt(update.current.?)) / @as(f64, @floatFromInt(update.total.?)) * 100.0
        else
            update.progress * 100.0;

        // Calculate elapsed time
        const elapsed_ms = (now - self.start_time) / 1_000_000;

        try writer.print(
            \\{{"jsonrpc":"2.0","method":"notifications/progress","params":{{
            \\  "operationId":"{s}",
            \\  "state":"{s}",
            \\  "message":"{s}",
            \\  "progress":{d:.1},
            \\  "elapsedMs":{d}
        , .{
            self.operation_id,
            @tagName(update.state),
            update.message,
            percentage,
            elapsed_ms,
        });

        if (update.current) |current| {
            try writer.print(",\"current\":{d}", .{current});
        }
        if (update.total) |total| {
            try writer.print(",\"total\":{d}", .{total});
        }

        try writer.writeAll("}}\n");
    }

    /// Send completion notification
    pub fn sendComplete(self: *StreamingContext, output: []const u8, writer: anytype) !void {
        const update = ProgressUpdate{
            .state = .complete,
            .message = "Operation completed",
            .progress = 1.0,
        };
        try self.formatProgress(update, writer);

        // Send final result
        try writer.print(
            \\{{"jsonrpc":"2.0","result":{{"output":"{s}"}}}}
        , .{output});
    }

    /// Send error notification
    pub fn sendError(self: *StreamingContext, error_msg: []const u8, writer: anytype) !void {
        const update = ProgressUpdate{
            .state = .errored,
            .message = error_msg,
            .progress = 0.0,
        };
        try self.formatProgress(update, writer);

        try writer.print(
            \\{{"jsonrpc":"2.0","error":{{"code":-32603,"message":"{s}"}}}}
        , .{error_msg});
    }
};

/// Active streaming operations registry
pub const StreamingRegistry = struct {
    allocator: std.mem.Allocator,
    operations: std.StringHashMap(*StreamingContext),

    pub fn init(allocator: std.mem.Allocator) StreamingRegistry {
        return .{
            .allocator = allocator,
            .operations = std.StringHashMap(*StreamingContext).init(allocator),
        };
    }

    pub fn deinit(self: *StreamingRegistry) void {
        var iter = self.operations.valueIterator();
        while (iter.next()) |ctx| {
            ctx.deinit();
            self.allocator.destroy(ctx);
        }
        self.operations.deinit();
    }

    /// Register a new streaming operation
    pub fn register(self: *StreamingRegistry, ctx: *StreamingContext) !void {
        try self.operations.put(ctx.operation_id, ctx);
    }

    /// Unregister a streaming operation
    pub fn unregister(self: *StreamingRegistry, operation_id: []const u8) void {
        if (self.operations.fetchRemove(operation_id)) |entry| {
            entry.value.deinit();
            self.allocator.destroy(entry.value);
        }
    }

    /// Get operation by ID
    pub fn get(self: *StreamingRegistry, operation_id: []const u8) ?*StreamingContext {
        return self.operations.get(operation_id);
    }

    /// Generate unique operation ID
    pub fn generateId(self: *StreamingRegistry) ![]const u8 {
        const timestamp = std.time.nanoTimestamp();
        const id_str = try std.fmt.allocPrint(self.allocator, "op_{d}", .{timestamp});
        return id_str;
    }
};

/// Progress callback type for long-running operations
pub const ProgressCallback = *const fn (progress: ProgressUpdate) void;

/// Execute a function with progress reporting
pub fn executeWithProgress(
    allocator: std.mem.Allocator,
    operation_id: []const u8,
    comptime func: anytype,
    args: anytype,
    writer: anytype,
) !void {
    var ctx = try StreamingContext.init(allocator, operation_id);
    defer ctx.deinit();

    // Send initial progress
    const start_update = ProgressUpdate{
        .state = .running,
        .message = "Starting operation...",
        .progress = 0.0,
    };
    try ctx.formatProgress(start_update, writer);

    // Execute the function
    // TODO: This is a stub - actual implementation needs async/await or callback-based execution
    _ = func;
    _ = args;

    // Send completion
    try ctx.sendComplete("Operation completed", writer);
}

/// Check if a command supports streaming
pub fn supportsStreaming(cmd_name: []const u8) bool {
    // Long-running commands that support progress reporting
    const streamable_commands = [_][]const u8{
        "tri_gen",
        "tri_pipeline",
        "tri_verify",
        "tri_bench",
        "tri_decompose",
        "tri_plan",
    };

    for (streamable_commands) |cmd| {
        if (std.mem.eql(u8, cmd_name, cmd)) {
            return true;
        }
    }
    return false;
}
