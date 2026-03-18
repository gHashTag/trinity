// @origin(spec:cancellation.tri) @regen(manual-impl)
//! MCP Cancellation Module
//!
//! Provides cancellation support for long-running operations.
//! φ² + 1/φ² = 3 = TRINITY
// @origin(manual) @regen(pending)

const std = @import("std");

/// Cancellation token for tracking operations
pub const CancellationToken = struct {
    allocator: std.mem.Allocator,
    operation_id: []const u8,
    cancelled: std.atomic.Value(bool),
    process_id: ?std.posix.pid_t,

    pub fn init(allocator: std.mem.Allocator, operation_id: []const u8) !CancellationToken {
        const id_copy = try allocator.dupe(u8, operation_id);
        return .{
            .allocator = allocator,
            .operation_id = id_copy,
            .cancelled = std.atomic.Value(bool).init(false),
            .process_id = null,
        };
    }

    pub fn deinit(self: *CancellationToken) void {
        self.allocator.free(self.operation_id);
    }

    /// Check if operation is cancelled
    pub fn isCancelled(self: *const CancellationToken) bool {
        return self.cancelled.load(.acquire);
    }

    /// Mark operation as cancelled
    pub fn cancel(self: *CancellationToken) void {
        self.cancelled.store(true, .release);

        // Terminate subprocess if exists
        if (self.process_id) |pid| {
            std.posix.kill(pid, std.posix.SIG.TERM) catch |err| {
                std.log.debug("cancellation: failed to kill process: {}", .{err});
            };
        }
    }

    /// Attach process ID for cancellation
    pub fn attachProcess(self: *CancellationToken, pid: std.posix.pid_t) void {
        self.process_id = pid;
    }
};

/// Cancellation registry for tracking active operations
pub const CancellationRegistry = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    tokens: std.StringHashMap(*CancellationToken),

    pub fn init(allocator: std.mem.Allocator) CancellationRegistry {
        return .{
            .allocator = allocator,
            .mutex = std.Thread.Mutex{},
            .tokens = std.StringHashMap(*CancellationToken).init(allocator),
        };
    }

    pub fn deinit(self: *CancellationRegistry) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.tokens.valueIterator();
        while (iter.next()) |token| {
            token.deinit();
            self.allocator.destroy(token);
        }
        self.tokens.deinit();
    }

    /// Register a new operation
    pub fn register(self: *CancellationRegistry, token: *CancellationToken) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.tokens.put(token.operation_id, token);
    }

    /// Unregister an operation
    pub fn unregister(self: *CancellationRegistry, operation_id: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.tokens.fetchRemove(operation_id)) |entry| {
            entry.value.deinit();
            self.allocator.destroy(entry.value);
        }
    }

    /// Cancel an operation by ID
    pub fn cancel(self: *CancellationRegistry, operation_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.tokens.get(operation_id)) |token| {
            token.cancel();
            return true;
        }
        return false;
    }

    /// Check if an operation is cancelled
    pub fn isCancelled(self: *CancellationRegistry, operation_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.tokens.get(operation_id)) |token| {
            return token.isCancelled();
        }
        return false;
    }

    /// Get token by ID
    pub fn get(self: *CancellationRegistry, operation_id: []const u8) ?*CancellationToken {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.tokens.get(operation_id);
    }

    /// Generate unique operation ID
    pub fn generateId(self: *CancellationRegistry) ![]const u8 {
        const timestamp = std.time.nanoTimestamp();
        const random = std.crypto.random.int(u64);
        const id_str = try std.fmt.allocPrint(self.allocator, "cancel_{d}_{x}", .{ timestamp, random });
        return id_str;
    }

    /// Get list of active operation IDs
    pub fn listActive(self: *CancellationRegistry, allocator: std.mem.Allocator) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList([]const u8).init(allocator);
        var iter = self.tokens.keyIterator();
        while (iter.next()) |key| {
            try list.append(try allocator.dupe(u8, key.*));
        }
        return list.toOwnedSlice();
    }
};

/// Global cancellation registry
var global_registry: ?CancellationRegistry = null;
var registry_init = std.Thread.Once{};

/// Get or create global cancellation registry
pub fn getGlobalRegistry() *CancellationRegistry {
    registry_init.call(struct {
        fn init_(ctx: *std.Thread.Once) void {
            _ = ctx;
            global_registry = CancellationRegistry.init(std.heap.page_allocator);
        }
    }.init_);
    return &global_registry.?;
}

/// Cancel an operation by ID (convenience function)
pub fn cancelOperation(operation_id: []const u8) bool {
    return getGlobalRegistry().cancel(operation_id);
}

/// Check if an operation is cancelled (convenience function)
pub fn isOperationCancelled(operation_id: []const u8) bool {
    return getGlobalRegistry().isCancelled(operation_id);
}

/// Generate cancellation response JSON
pub fn formatCancellationResponse(allocator: std.mem.Allocator, operation_id: []const u8, cancelled: bool) ![]const u8 {
    if (cancelled) {
        return std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","result":{{"cancelled":true,"operationId":"{s}"}}}}
        , .{operation_id});
    } else {
        return std.fmt.allocPrint(allocator,
            \\{{"jsonrpc":"2.0","error":{{"code":-32602,"message":"Operation not found"}}}}
        , .{});
    }
}

/// Format list of active operations
pub fn formatActiveOperations(allocator: std.mem.Allocator, registry: *CancellationRegistry) ![]const u8 {
    const ids = try registry.listActive(allocator);
    defer {
        for (ids) |id| {
            allocator.free(id);
        }
        allocator.free(ids);
    }

    var json_list = std.array_list.Managed(u8).init(allocator);
    try json_list.appendSlice("{\"jsonrpc\":\"2.0\",\"result\":{\"operations\":[");

    for (ids, 0..) |id, i| {
        if (i > 0) try json_list.append(',');
        try json_list.print("\"{s}\"", .{id});
    }

    try json_list.appendSlice("]}}");
    return json_list.toOwnedSlice();
}
