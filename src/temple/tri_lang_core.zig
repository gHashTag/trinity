// TTT — Trusted Tri Temple — L0 Sacred Layer
// DO NOT MODIFY without TEMPLE_RITUAL
// Re-exports from: src/tri-lang/result_type.zig, src/tri-lang/bit_trit_patterns.zig,
//                src/tri-lang/linear_types.zig, src/tri-lang/effects.zig
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════
// RESULT TYPE (re-export from src/tri-lang/result_type.zig)
// ═══════════════════════════════════════════════════════════════════════════

/// Result<T, E> - Represents success (Ok) or error (Err)
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        Ok: T,
        Err: E,
    };
}

/// Common error types
pub const NeuroError = enum(u8) {
    InvalidInput = 0,
    BufferOverflow = 1,
    DivisionByZero = 2,
    TypeMismatch = 3,
    OutOfMemory = 4,
    InvalidState = 5,
    Timeout = 6,
    NetworkError = 7,
    Unknown = 255,
};

pub const ParseError = enum(u8) {
    UnexpectedEnd = 0,
    UnexpectedToken = 1,
    InvalidSyntax = 2,
    InvalidLiteral = 3,
};

/// Map over the Ok value, keep Err unchanged
pub fn map(comptime T: type, comptime U: type, comptime E: type, result: Result(T, E), mapper: fn (T) U) Result(U, E) {
    return switch (result) {
        .Ok => |v| Result(U, E){ .Ok = mapper(v) },
        .Err => |e| Result(U, E){ .Err = e },
    };
}

/// Chain: if Ok, apply function; if Err, keep error
pub fn andThen(comptime T: type, comptime U: type, comptime E: type, result: Result(T, E), mapper: fn (T) Result(U, E)) Result(U, E) {
    return switch (result) {
        .Ok => |v| mapper(v),
        .Err => |e| Result(U, E){ .Err = e },
    };
}

/// Get the Ok value, or default if Err
pub fn withDefault(comptime T: type, comptime E: type, result: Result(T, E), default: T) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => default,
    };
}

/// Unwrap: get Ok value, panic on Err
pub fn unwrap(comptime T: type, comptime E: type, result: Result(T, E)) T {
    return switch (result) {
        .Ok => |v| v,
        .Err => |e| {
            std.debug.panic("unwrap called on Err: {}", .{e});
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// BIT/TRIT PATTERNS (re-export from src/tri-lang/bit_trit_patterns.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

/// Bit-level pattern: 0b0010xxxx
pub const BitPattern = struct {
    bits: u64,
    mask: u64,
    width: u8,
    loc: SourceLocation,

    pub fn init(bits: u64, mask: u64, width: u8, loc: SourceLocation) BitPattern {
        return .{
            .bits = bits & ((@as(u64, 1) << @intCast(width)) - 1),
            .mask = mask & ((@as(u64, 1) << @intCast(width)) - 1),
            .width = width,
            .loc = loc,
        };
    }

    pub fn matches(self: BitPattern, value: u64) bool {
        const masked = value & self.mask;
        return masked == self.bits;
    }
};

/// Trit value: -1, 0, +1
pub const TritPat = enum(i2) {
    Neg = -1,
    Zero = 0,
    Pos = 1,

    pub fn fromChar(c: u8) !TritPat {
        return switch (c) {
            '-', 'N', 'n' => .Neg,
            '0', 'Z', 'z' => .Zero,
            '+', 'P', 'p' => .Pos,
            else => error.InvalidTrit,
        };
    }
};

/// Trit-level pattern: 0tPPN
pub const TritPattern = struct {
    trits: [27]i2,
    mask: [27]bool,
    width: u8,
    loc: SourceLocation,

    pub fn init(width: u8, loc: SourceLocation) TritPattern {
        return .{
            .trits = [_]i2{0} ** 27,
            .mask = [_]bool{false} ** 27,
            .width = width,
            .loc = loc,
        };
    }

    pub fn matches(self: TritPattern, value: []const i2) bool {
        if (value.len < self.width) return false;

        for (0..self.width) |i| {
            if (self.mask[i] and self.trits[i] != value[i]) {
                return false;
            }
        }
        return true;
    }
};

/// Typed hole: ?name
pub const Hole = struct {
    name: []const u8,
    expected_type: ?[]const u8,
    context: ?[]const u8,
    loc: SourceLocation,

    pub fn init(name: []const u8, loc: SourceLocation) Hole {
        return .{
            .name = name,
            .expected_type = null,
            .context = null,
            .loc = loc,
        };
    }

    pub fn isAnonymous(self: Hole) bool {
        return self.name.len == 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// LINEAR TYPES (re-export from src/tri-lang/linear_types.zig)
// ═══════════════════════════════════════════════════════════════════════════

/// Ownership mode for variables
pub const OwnershipMode = enum(u2) {
    Let = 0,    // immutable, can be read multiple times
    Inout = 1,  // mutable reference
    Sink = 2,   // consumes value, must be used exactly once
    Set = 3,    // mutable owned value

    pub fn isLinear(self: OwnershipMode) bool {
        return self == .Sink;
    }

    pub fn isMutable(self: OwnershipMode) bool {
        return self == .Inout or self == .Set;
    }

    pub fn canMove(self: OwnershipMode) bool {
        return self == .Sink or self == .Set;
    }
};

/// Bank identifier for Coptic register safety
pub const Bank = enum(u2) {
    ALU = 0,      // Bank 0: ALU registers (t0-t8)
    Sacred = 1,   // Bank 1: Sacred accumulators (t9-t17)
    Constant = 2,  // Bank 2: Constants (t18-t26) — immutable

    pub fn fromReg(reg: u5) Bank {
        return @enumFromInt(reg / 9);
    }
};

/// Linear type wrapper enforces consume-once semantics
pub fn Linear(comptime T: type) type {
    return struct {
        value: T,
        consumed: bool = false,

        const Self = @This();

        pub fn consume(self: *Self) !T {
            if (self.consumed) {
                return error.LinearValueAlreadyConsumed;
            }
            self.consumed = true;
            return self.value;
        }

        pub fn move(self: *Self) !Self {
            if (self.consumed) {
                return error.LinearValueAlreadyConsumed;
            }
            self.consumed = true;
            return Self{ .value = self.value, .consumed = false };
        }

        pub fn init(value: T) Self {
            return Self{ .value = value };
        }
    };
}

/// Must-use wrapper
pub fn MustUse(comptime T: type) type {
    return struct {
        value: T,
        used: bool = false,

        const Self = @This();

        pub fn get(self: *Self) T {
            self.used = true;
            return self.value;
        }

        pub fn init(value: T) Self {
            return Self{ .value = value };
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// EFFECTS + HANDLERS (re-export from src/tri-lang/effects.zig)
// ═══════════════════════════════════════════════════════════════════════════

/// Effect identifier
pub const EffectId = enum(u8) {
    IO,
    File,
    Network,
    Database,
    State,
    Mutable,
    Error,
    Fail,
    PlatformCPU,
    PlatformFPGA,
    PlatformVM,
    Async,
    User = 128,
};

/// Effect operation
pub const EffectOp = struct {
    name: []const u8,
    payload_typename: ?[]const u8,
    loc: SourceLocation,
};

/// Effect definition
pub const Effect = struct {
    id: EffectId,
    name: []const u8,
    operations: []const EffectOp,
};

/// Platform effect for dual-target code generation
pub const PlatformEffect = enum {
    CPU,
    FPGA,
    VM,
};

/// Effect context — tracks active handlers
pub const EffectContext = struct {
    count: usize,
    handlers: [8]Handler,

    pub fn init() EffectContext {
        return .{ .count = 0, .handlers = undefined };
    }

    pub fn pushHandler(self: *EffectContext, handler: Handler) !void {
        if (self.count >= 8) return error.HandlerStackOverflow;
        self.handlers[self.count] = handler;
        self.count += 1;
    }

    pub fn popHandler(self: *EffectContext) !Handler {
        if (self.count == 0) return error.NoHandler;
        self.count -= 1;
        const result = self.handlers[self.count];
        self.handlers[self.count] = undefined;
        return result;
    }

    pub fn topHandler(self: *const EffectContext) ?Handler {
        if (self.count == 0) return null;
        return &self.handlers[self.count - 1];
    }
};

/// Effect handler
pub const Handler = struct {
    allocator: std.mem.Allocator,
};

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "result ok" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };
    try std.testing.expectEqual(@as(i32, 42), result.Ok);
}

test "result err" {
    const result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    try std.testing.expectEqual(NeuroError.InvalidInput, result.Err);
}

test "result map" {
    const result: Result(i32, NeuroError) = .{ .Ok = 41 };
    const mapped = map(i32, i64, NeuroError, result, struct { fn inner(x: i32) i64 { return @intCast(x); } }.inner);
    try std.testing.expectEqual(@as(i64, 41), mapped.Ok);
}

test "result andThen" {
    const result: Result(i32, NeuroError) = .{ .Ok = 42 };
    const chained = andThen(i32, bool, NeuroError, result, struct { fn inner(_: i32) Result(bool, NeuroError) { return .{ .Ok = true }; } }.inner);
    try std.testing.expect(chained.Ok);
}

test "result withDefault" {
    const ok_result: Result(i32, NeuroError) = .{ .Ok = 42 };
    try std.testing.expectEqual(@as(i32, 42), withDefault(i32, NeuroError, ok_result, 0));

    const err_result: Result(i32, NeuroError) = .{ .Err = .InvalidInput };
    try std.testing.expectEqual(@as(i32, 0), withDefault(i32, NeuroError, err_result, 0));
}

test "bit pattern matches" {
    const pattern = BitPattern.init(0b1010, 0b1111, 4, .{ .line = 1, .column = 1 });
    try std.testing.expect(pattern.matches(0b1010));
    try std.testing.expect(!pattern.matches(0b0010));
}

test "trit pattern matches" {
    var pattern = TritPattern.init(3, .{ .line = 1, .column = 1 });
    pattern.trits[0] = 1;
    pattern.trits[1] = 0;
    pattern.trits[2] = -1;
    pattern.mask[0] = true;
    pattern.mask[1] = true;
    pattern.mask[2] = true;

    const value = [_]i2{ 1, 0, -1 };
    try std.testing.expect(pattern.matches(&value));
}

test "hole anonymous" {
    const hole = Hole.init("", .{ .line = 1, .column = 1 });
    try std.testing.expect(hole.isAnonymous());
}

test "ownership mode properties" {
    try std.testing.expect(OwnershipMode.Let.isLinear() == false);
    try std.testing.expect(OwnershipMode.Sink.isLinear() == true);
    try std.testing.expect(OwnershipMode.Let.isMutable() == false);
    try std.testing.expect(OwnershipMode.Inout.isMutable() == true);
    try std.testing.expect(OwnershipMode.Sink.canMove() == true);
}

test "bank from reg" {
    try std.testing.expectEqual(Bank.ALU, Bank.fromReg(0));
    try std.testing.expectEqual(Bank.ALU, Bank.fromReg(8));
    try std.testing.expectEqual(Bank.Sacred, Bank.fromReg(9));
    try std.testing.expectEqual(Bank.Constant, Bank.fromReg(18));
}

test "linear type consume" {
    const Lin = Linear(i32);
    var val = Lin.init(42);

    try std.testing.expectEqual(@as(i32, 42), val.consume());
    try std.testing.expectError(error.LinearValueAlreadyConsumed, val.consume());
}

test "must use annotation" {
    const Mu = MustUse(i32);
    var val = Mu.init(42);

    try std.testing.expect(!val.used);
    const v = val.get();
    try std.testing.expect(val.used);
    try std.testing.expectEqual(@as(i32, 42), v);
}

test "effect id values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(EffectId.IO));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(EffectId.State));
    try std.testing.expectEqual(@as(u8, 128), @intFromEnum(EffectId.User));
}

test "platform effect enum" {
    // Verify all platform effect values exist
    _ = PlatformEffect.CPU;
    _ = PlatformEffect.FPGA;
    _ = PlatformEffect.VM;
    try std.testing.expect(true);
}
