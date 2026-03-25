// ═══════════════════════════════════════════════════════════════════════════
// effects.zig - Algebraic Effects + Handlers for Tri Language
// ═══════════════════════════════════════════════════════════════════════════
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
// ═══════════════════════════════════════════════════════════════════════════

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
    pub const read = EffectOp{ .name = "get", .payload_type = void, .loc = .{ .line = 0, .column = 0 } };
    pub const write = EffectOp{ .name = "set", .payload_type = void, .loc = .{ .line = 0, .column = 0 } };
};

/// Error effect — effectful error tracking
/// perform error { throw(msg) }
pub const ErrorEffect = struct {
    pub const throw_op = EffectOp{ .name = "throw", .payload_type = []const u8, .loc = .{ .line = 0, .column = 0 } };
};

/// Async effect — async/await operations
/// perform async { await() }
pub const AsyncEffect = struct {
    pub const await_op = EffectOp{ .name = "await", .payload_type = void, .loc = .{ .line = 0, .column = 0 } };
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
pub const Handler = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Handle State.get operation
    pub fn handleStateGet(self: *Self, state: anytype) !void {
        _ = self;
        _ = state;
        // Implementation: return current state value
        return error.NotImplemented;
    }

    /// Handle State.set operation
    pub fn handleStateSet(self: *Self, state: anytype, value: anytype) !void {
        _ = self;
        _ = state;
        _ = value;
        // Implementation: update state and resume
        return error.NotImplemented;
    }

    /// Handle Error.throw operation
    pub fn handleErrorThrow(self: *Self, msg: []const u8) !void {
        _ = self;
        _ = msg;
        // Implementation: propagate error with context
        return error.NotImplemented;
    }

    /// Handle Async.await operation
    pub fn handleAsyncAwait(self: *Self) !void {
        _ = self;
        // Implementation: suspend until async operation completes
        return error.NotImplemented;
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
        try self.handlers.append(handler);
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

    /// Handle an effect operation
    pub fn handle(self: *Self, comptime effect_id: EffectId, op: []const u8) !void {
        const handler = self.topHandler() orelse return error.UnhandledEffect;
        _ = effect_id;
        _ = op;
        _ = handler;
        // Implementation: dispatch to handler based on effect_id and op
        return error.NotImplemented;
    }
};

// ═══════════════════════════════════════════════════════════════════════
// AST NODES FOR EFFECTS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Perform expression — perform effect { operation }
pub const PerformExpr = struct {
    /// Effect to perform
    effect_id: EffectId,
    /// Operation name
    operation: []const u8,
    /// Operation arguments
    args: []const Expr,
    loc: SourceLocation,
};

/// Handle expression — handle effect with handler
pub const HandleExpr = struct {
    /// Effect to handle
    effect_id: EffectId,
    /// Handler body (clauses for each operation)
    clauses: []const HandlerClause,
    /// Computation to run under this handler
    body: Expr,
    loc: SourceLocation,
};

/// Handler clause — pattern for operation + body
pub const HandlerClause = struct {
    /// Operation name pattern
    operation: []const u8,
    /// Parameter pattern (e.g., "msg" for throw(msg))
    param_pattern: Pattern,
    /// Handler body
    body: Expr,
    loc: SourceLocation,
};

/// Try expression — perform effect { ... } with handler
pub const TryExpr = struct {
    /// Computation that may perform effects
    computation: Expr,
    /// Handler clauses
    handlers: []const HandlerClause,
    loc: SourceLocation,
};

// ═══════════════════════════════════════════════════════════════════════
// SUPPORTING TYPES (forward references)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Expression (minimal definition to avoid circular dependency)
pub const Expr = union(enum) {
    Perform: PerformExpr,
    Handle: HandleExpr,
    Try: TryExpr,
    // ... other expression types
};

/// Pattern (minimal definition)
pub const Pattern = union(enum) {
    Identifier: []const u8,
    // ... other pattern types
};

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

    const handler = Handler{ .allocator = allocator };
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

    const handler = Handler{ .allocator = allocator };
    try ctx.pushHandler(handler);

    const top = ctx.topHandler();
    try std.testing.expect(top != null);
}

test "effect_id_values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(EffectId.IO));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(EffectId.State));
    try std.testing.expectEqual(@as(u8, 128), @intFromEnum(EffectId.User));
}

test "platform_effect_enum" {
    try std.testing.expectEqual(@as(usize, 3), @typeInfo(PlatformEffect).Enum.fields.len);
}

test "effect_operations" {
    const read_op = EffectOp{ .name = "get", .payload_type = void, .loc = .{ .line = 0, .column = 0 } };
    try std.testing.expectEqualStrings("get", read_op.name);
    try std.testing.expect(read_op.payload_type == void);
}
