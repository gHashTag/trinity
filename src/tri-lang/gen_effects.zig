// ═══════════════════════════════════════════════════════════════════════════════
// Algebraic Effects + Handlers (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/tri-lang/effects.tri
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #412: Effects + Handlers
//
// Implements:
// - Algebraic effects (Koka/Roc style)
// - Effect handlers (resumable exceptions)
// - Platform effects (cpu/fpga/vm)
// - Error contexts (effectful error tracking)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ═══════════════════════════════════════════════════════════════════════
// EFFECT DEFINITIONS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Effect identifier (compile-time known)
pub const EffectId = enum(u8) {
    // I/O effects
    IO,
    File,
    Network,
    Database,

    // State effects
    State,
    Mutable,

    // Error effects
    Error,
    Fail,

    // Platform effects (for dual-target)
    PlatformCPU,
    PlatformFPGA,
    PlatformVM,

    // Async effects
    Async,

    // Custom user effects (128-255)
    User = 128,
};

/// Effect operation (e.g., read/write for State effect)
pub const EffectOp = struct {
    /// Operation name (e.g., "read", "write")
    name: []const u8,
    /// Payload type name (can be null for no-arg ops)
    payload_typename: ?[]const u8,
    loc: SourceLocation,
};

/// Effect definition (compile-time)
pub const Effect = struct {
    /// Unique effect identifier
    id: EffectId,
    /// Effect name (e.g., "State", "IO")
    name: []const u8,
    /// Operations supported by this effect
    operations: []const EffectOp,
};

// ═══════════════════════════════════════════════════════════════════════
// COMMON EFFECT DEFINITIONS
// ═════════════════════════════════════════════════════════════════════════════════════

/// State effect — mutable state operations
/// perform state { get(), set(x) }
pub const StateEffect = struct {
    pub const read = EffectOp{ .name = "get", .payload_typename = null, .loc = .{ .line = 0, .column = 0 } };
    pub const write = EffectOp{ .name = "set", .payload_typename = null, .loc = .{ .line = 0, .column = 0 } };
};

/// Error effect — effectful error tracking
/// perform error { throw(msg) }
pub const ErrorEffect = struct {
    pub const throw_op = EffectOp{ .name = "throw", .payload_typename = "[]const u8", .loc = .{ .line = 0, .column = 0 } };
};

/// Async effect — async/await operations
/// perform async { await() }
pub const AsyncEffect = struct {
    pub const await_op = EffectOp{ .name = "await", .payload_typename = null, .loc = .{ .line = 0, .column = 0 } };
};

/// Platform effect — dual-target code generation
pub const PlatformEffect = enum {
    /// CPU target (Zig codegen)
    CPU,
    /// FPGA target (Verilog codegen)
    FPGA,
    /// VM target (TRI-27 bytecode)
    VM,
};

// ═══════════════════════════════════════════════════════════════════════
// EFFECT HANDLERS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Effect handler — resumes computation with result
/// Generic handler that can handle multiple effect types
pub const Handler = struct {
    allocator: std.mem.Allocator,
    /// Optional state storage for State effect
    state_storage: ?i64,
    /// Optional error message for Error effect
    error_msg: ?[]const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .state_storage = null,
            .error_msg = null,
        };
    }

    /// Handle State.get operation
    /// Returns the current state value
    pub fn handleStateGet(self: *Self) !i64 {
        if (self.state_storage) |value| {
            return value;
        }
        return error.StateNotInitialized;
    }

    /// Handle State.set operation
    /// Updates state and signals to resume
    pub fn handleStateSet(self: *Self, value: i64) !void {
        self.state_storage = value;
    }

    /// Handle Error.throw operation
    /// Stores error message and returns error
    pub fn handleErrorThrow(self: *Self, msg: []const u8) !void {
        // Store the error message
        self.error_msg = try self.allocator.dupe(u8, msg);
        return error.EffectThrown;
    }

    /// Handle Async.await operation
    /// Placeholder for async effect handling
    pub fn handleAsyncAwait(self: *Self) !void {
        _ = self;
        // Full implementation would suspend until async operation completes
        return error.AsyncNotSupported;
    }

    /// Clean up allocated resources
    pub fn deinit(self: *Self) void {
        if (self.error_msg) |msg| {
            self.allocator.free(msg);
            self.error_msg = null;
        }
    }
};

/// Effect-specific errors
pub const EffectError = error{
    StateNotInitialized,
    EffectThrown,
    AsyncNotSupported,
    UnhandledEffect,
    NoHandler,
};

/// State handler implementation with actual state storage
pub const StateHandler = struct {
    allocator: std.mem.Allocator,
    state: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, initial_state: i64) Self {
        return Self{
            .allocator = allocator,
            .state = initial_state,
        };
    }

    pub fn handleGet(self: *Self) !i64 {
        return self.state;
    }

    pub fn handleSet(self: *Self, value: i64) !void {
        self.state = value;
    }
};

// ═══════════════════════════════════════════════════════════════════════
// EFFECT CONTEXT (Runtime)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Effect context — tracks active handlers
pub const EffectContext = struct {
    allocator: std.mem.Allocator,
    /// Stack of active handlers
    handlers: std.ArrayList(Handler),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var handlers = std.ArrayList(Handler){};
        handlers.ensureTotalCapacity(allocator, 4) catch {};
        return Self{
            .allocator = allocator,
            .handlers = handlers,
        };
    }

    pub fn deinit(self: *Self) void {
        self.handlers.deinit(self.allocator);
    }

    /// Push a new handler onto the stack
    pub fn pushHandler(self: *Self, handler: Handler) !void {
        try self.handlers.append(self.allocator, handler);
    }

    /// Pop the top handler from the stack
    pub fn popHandler(self: *Self) !Handler {
        if (self.handlers.items.len == 0) return error.NoHandler;
        return self.handlers.orderedRemove(self.handlers.items.len - 1);
    }

    /// Get the top handler
    pub fn topHandler(self: *const Self) ?Handler {
        if (self.handlers.items.len == 0) return null;
        return self.handlers.items[self.handlers.items.len - 1];
    }

    /// Handle an effect operation by dispatching to the appropriate handler
    pub fn handle(self: *Self, comptime effect_id: EffectId, op: []const u8, args: anytype) !?i64 {
        _ = self.topHandler() orelse return error.NoHandler;

        // Need mutable reference for handler methods
        // Get index and modify in-place
        const idx = self.handlers.items.len - 1;
        const handler = &self.handlers.items[idx];

        // Dispatch based on effect_id and operation name
        switch (effect_id) {
            .State => {
                if (std.mem.eql(u8, op, "get")) {
                    const value = try handler.handleStateGet();
                    return value;
                } else if (std.mem.eql(u8, op, "set")) {
                    // Extract value from args - assume struct with .value field
                    // For tests with empty struct, this will return 0
                    const value: i64 = blk: {
                        // Use @field with string - if field doesn't exist, catch at compile time
                        const T = @TypeOf(args);
                        if (comptime @typeInfo(T) == .@"struct") {
                            break :blk @field(args, "value");
                        }
                        break :blk 0;
                    };
                    try handler.handleStateSet(value);
                    return null;
                }
            },
            .Error => {
                if (std.mem.eql(u8, op, "throw")) {
                    const msg: []const u8 = blk: {
                        const T = @TypeOf(args);
                        if (comptime @typeInfo(T) == .@"struct") {
                            break :blk @field(args, "msg");
                        }
                        break :blk "unknown error";
                    };
                    try handler.handleErrorThrow(msg);
                    return null;
                }
            },
            .Async => {
                if (std.mem.eql(u8, op, "await")) {
                    try handler.handleAsyncAwait();
                    return null;
                }
            },
            else => {},
        }

        return error.UnhandledEffect;
    }
};

// ═══════════════════════════════════════════════════════════════════════
// AST NODES FOR EFFECTS
// ═════════════════════════════════════════════════════════════════════════════════════
//
// Note: AST nodes for effects (PerformExpr, HandleExpr, TryExpr, HandlerClause)
// are defined in ast.zig to avoid circular dependencies.
// This module provides the runtime support for effect handling.
// ═══════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "effect_context_init" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(usize, 0), ctx.handlers.items.len);
}

test "effect_context_push_pop" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    const handler = Handler.init(allocator);
    try ctx.pushHandler(handler);

    try std.testing.expectEqual(@as(usize, 1), ctx.handlers.items.len);

    const popped = try ctx.popHandler();
    try std.testing.expectEqual(@as(usize, 0), ctx.handlers.items.len);
    _ = popped;
}

test "effect_context_top_handler" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    try std.testing.expect(ctx.topHandler() == null);

    const handler = Handler.init(allocator);
    try ctx.pushHandler(handler);

    const top = ctx.topHandler();
    try std.testing.expect(top != null);
}

test "effect_id_values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(EffectId.IO));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(EffectId.State));
    try std.testing.expectEqual(@as(u8, 128), @intFromEnum(EffectId.User));
}

test "platform_effect_enum" {
    const type_info = @typeInfo(PlatformEffect);
    try std.testing.expectEqual(@as(usize, 3), type_info.@"enum".fields.len);
}

test "effect_operations" {
    const read_op = EffectOp{ .name = "get", .payload_typename = null, .loc = .{ .line = 0, .column = 0 } };
    try std.testing.expectEqualStrings("get", read_op.name);
    try std.testing.expect(read_op.payload_typename == null);
}

test "StateHandler init and get" {
    const allocator = std.testing.allocator;
    var handler = StateHandler.init(allocator, 42);

    const value = try handler.handleGet();
    try std.testing.expectEqual(@as(i64, 42), value);
}

test "StateHandler set and get" {
    const allocator = std.testing.allocator;
    var handler = StateHandler.init(allocator, 0);

    try handler.handleSet(99);
    const value = try handler.handleGet();
    try std.testing.expectEqual(@as(i64, 99), value);
}

// ═══════════════════════════════════════════════════════════════════════
// WAVE 3: EFFECT HANDLER IMPLEMENTATION TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "Handler init and deinit" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    try std.testing.expect(handler.state_storage == null);
    try std.testing.expect(handler.error_msg == null);
}

test "Handler handleStateGet returns initial value" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    handler.state_storage = 42;
    const value = try handler.handleStateGet();
    try std.testing.expectEqual(@as(i64, 42), value);
}

test "Handler handleStateGet uninitialized fails" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    const result = handler.handleStateGet();
    try std.testing.expectError(error.StateNotInitialized, result);
}

test "Handler handleStateSet updates state" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    try handler.handleStateSet(100);
    try std.testing.expectEqual(@as(?i64, 100), handler.state_storage);

    // Verify we can get the value back
    const value = try handler.handleStateGet();
    try std.testing.expectEqual(@as(i64, 100), value);
}

test "Handler handleErrorThrow stores message" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    const msg = "test error message";
    const result = handler.handleErrorThrow(msg);

    try std.testing.expectError(error.EffectThrown, result);
    try std.testing.expect(handler.error_msg != null);
    if (handler.error_msg) |stored_msg| {
        try std.testing.expectEqualStrings(msg, stored_msg);
    }
}

test "Handler handleAsyncAwait returns not supported" {
    const allocator = std.testing.allocator;
    var handler = Handler.init(allocator);
    defer handler.deinit();

    const result = handler.handleAsyncAwait();
    try std.testing.expectError(error.AsyncNotSupported, result);
}

test "EffectContext handle State.get" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    // Add a handler with initial state
    var handler = Handler.init(allocator);
    handler.state_storage = 42;
    try ctx.pushHandler(handler);

    const args = struct {};
    const result = try ctx.handle(.State, "get", args);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 42), result.?);
}

test "EffectContext handle State.set" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    const handler = Handler.init(allocator);
    try ctx.pushHandler(handler);

    const args = struct { value: i64 }{ .value = 99 };
    const result = try ctx.handle(.State, "set", args);
    try std.testing.expect(result == null); // set returns void

    // Verify state was updated via the handler
    const top = ctx.topHandler();
    try std.testing.expect(top != null);
    if (top) |h| {
        try std.testing.expectEqual(@as(?i64, 99), h.state_storage);
    }
}

test "EffectContext handle no handler fails" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    const args = struct {};
    const result = ctx.handle(.State, "get", args);
    try std.testing.expectError(error.NoHandler, result);
}

test "EffectContext handle unknown operation fails" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    const handler = Handler.init(allocator);
    try ctx.pushHandler(handler);

    const args = struct {};
    const result = ctx.handle(.State, "unknown_op", args);
    try std.testing.expectError(error.UnhandledEffect, result);
}

test "EffectContext handle Error.throw" {
    const allocator = std.testing.allocator;
    var ctx = EffectContext.init(allocator);
    defer ctx.deinit();

    const handler = Handler.init(allocator);
    try ctx.pushHandler(handler);

    const msg = "something went wrong";
    const args = struct { msg: []const u8 }{ .msg = msg };
    const result = ctx.handle(.Error, "throw", args);
    try std.testing.expectError(error.EffectThrown, result);

    // Verify error message was stored and clean up to prevent leak
    // Get mutable reference to handler from context
    if (ctx.handlers.items.len > 0) {
        const idx = ctx.handlers.items.len - 1;
        const h = &ctx.handlers.items[idx];
        try std.testing.expect(h.error_msg != null);
        if (h.error_msg) |stored_msg| {
            try std.testing.expectEqualStrings(msg, stored_msg);
            // Clean up the allocated error message to prevent leak
            allocator.free(stored_msg);
            h.error_msg = null;
        }
    }
}
