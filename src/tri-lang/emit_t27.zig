// ═══════════════════════════════════════════════════════════════════════════════
// emit_t27.zig - TRI-27 Bytecode Emitter
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Wave 2, Phase 3: emit_t27 Bytecode Generation
//
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const TypedExpr = @import("typechecker.zig").TypedExpr;
const IntExpr = @import("typechecker.zig").IntExpr;
const BoolExpr = @import("typechecker.zig").BoolExpr;
const VarExpr = @import("typechecker.zig").VarExpr;
const BinOpExpr = @import("typechecker.zig").BinOpExpr;
const IfExpr = @import("typechecker.zig").IfExpr;
const LetExpr = @import("typechecker.zig").LetExpr;
const FnExpr = @import("typechecker.zig").FnExpr;
const FnCallExpr = @import("typechecker.zig").FnCallExpr;
const ADTExpr = @import("typechecker.zig").ADTExpr;
const MatchExpr = @import("typechecker.zig").MatchExpr;
const PipeExpr = @import("typechecker.zig").PipeExpr;
const MatchPattern = @import("typechecker.zig").MatchPattern;
const MatchArm = @import("typechecker.zig").MatchArm;

const BinaryOperator = @import("ast.zig").BinaryOperator;

// ═══════════════════════════════════════════════════════════════════════════════
// TRI-27 OPCODES
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    NOP = 0x00,
    PUSH = 0x01,
    POP = 0x02,
    LOADI = 0x10,
    LOADB = 0x11,
    MOV = 0x20,
    ADD = 0x30,
    SUB = 0x31,
    MUL = 0x32,
    DIV = 0x33,
    EQ = 0x40,
    NE = 0x41,
    LT = 0x42,
    GT = 0x44,
    JUMP = 0x50,
    JZ = 0x51,
    CALL = 0x60,
    RET = 0x61,
    ADTN = 0x70,
    ADTD = 0x71,

    // Wave 2: Result type opcodes
    RESULT_OK = 0x72, // Ok(value)
    RESULT_ERR = 0x73, // Err(error)

    // Wave 2: Linear type opcodes
    LINEAR_CONSUME = 0x74, // Mark as consumed
    LINEAR_BORROW = 0x75, // Shared borrow
    LINEAR_MOVE = 0x76, // Transfer ownership

    // Wave 2: Array opcodes
    ARRAY_GET = 0x77, // Bounds-checked get
    ARRAY_LEN = 0x78, // Get compile-time length
    ARRAY_SET = 0x79, // Bounds-checked set

    HALT = 0xFF,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE BUFFER
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const BytecodeBuffer = struct {
    bytes: std.ArrayList(u8),
    labels: std.StringHashMap(usize),
    allocator: Allocator,

    pub fn init(allocator: Allocator) BytecodeBuffer {
        return .{
            .bytes = std.ArrayList(u8).empty,
            .labels = std.StringHashMap(usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BytecodeBuffer) void {
        self.bytes.deinit(self.allocator);
        self.labels.deinit();
    }

    pub fn emitByte(self: *BytecodeBuffer, byte: u8) !void {
        try self.bytes.append(self.allocator, byte);
    }

    pub fn emit(self: *BytecodeBuffer, op: Opcode) !void {
        try self.bytes.append(self.allocator, @intFromEnum(op));
    }

    pub fn emitWord(self: *BytecodeBuffer, value: i32) !void {
        const bytes = @as([4]u8, @bitCast(value));
        try self.bytes.appendSlice(self.allocator, &bytes);
    }

    pub fn emitJumpPlaceholder(self: *BytecodeBuffer) !usize {
        const offset = self.bytes.items.len;
        try self.emitWord(0);
        return offset;
    }

    pub fn patchJump(self: *BytecodeBuffer, offset: usize, target: usize) !void {
        const jump_offset = @as(i32, @intCast(target)) - @as(i32, @intCast(offset + 4));
        const bytes = @as([4]u8, @bitCast(jump_offset));
        @memcpy(self.bytes.items[offset..][0..4], &bytes);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN STATE
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const Codegen = struct {
    allocator: Allocator,
    code: BytecodeBuffer,
    next_label: u32,

    pub fn init(allocator: Allocator) Codegen {
        return .{
            .allocator = allocator,
            .code = BytecodeBuffer.init(allocator),
            .next_label = 0,
        };
    }

    pub fn deinit(self: *Codegen) void {
        self.code.deinit();
    }

    pub fn freshLabel(self: *Codegen) ![]const u8 {
        const id = self.next_label;
        self.next_label += 1;
        return std.fmt.allocPrint(self.allocator, "L{d}", .{id});
    }

    pub fn getBytecode(self: *const Codegen) []const u8 {
        return self.code.bytes.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPRESSION COMPILATION
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const CodegenError = error{
    OutOfMemory,
    UnsupportedExpression,
};

pub fn compileExpr(cg: *Codegen, expr: *const TypedExpr) CodegenError!void {
    switch (expr.*) {
        .Int => |e| try compileIntLiteral(cg, e),
        .Bool => |e| try compileBoolLiteral(cg, e),
        .Var => |e| try compileVar(cg, e),
        .BinOp => |e| try compileBinOp(cg, e),
        .If => |e| try compileIf(cg, e),
        .Let => |e| try compileLet(cg, e),
        .Fn => |e| try compileFn(cg, e),
        .FnCall => |e| try compileFnCall(cg, e),
        .ADT => |e| try compileADT(cg, e),
        .Match => |e| try compileMatch(cg, e),
        .Pipe => |e| try compilePipe(cg, e),
    }
}

fn compileIntLiteral(cg: *Codegen, expr: IntExpr) CodegenError!void {
    try cg.code.emit(Opcode.LOADI);
    try cg.code.emitWord(@intCast(expr.value));
}

fn compileBoolLiteral(cg: *Codegen, expr: BoolExpr) CodegenError!void {
    try cg.code.emit(Opcode.LOADB);
    try cg.code.emitByte(@intFromBool(expr.value));
}

fn compileVar(cg: *Codegen, expr: VarExpr) CodegenError!void {
    _ = expr;
    try cg.code.emit(Opcode.MOV);
    try cg.code.emitByte(0);
}

fn compileBinOp(cg: *Codegen, expr: BinOpExpr) CodegenError!void {
    try compileExpr(cg, expr.left);
    try cg.code.emit(Opcode.PUSH);
    try compileExpr(cg, expr.right);
    try cg.code.emit(Opcode.POP);
    try cg.code.emit(getBinOpOpcode(expr.op));
}

fn getBinOpOpcode(op: BinaryOperator) Opcode {
    return switch (op) {
        .Add => Opcode.ADD,
        .Sub => Opcode.SUB,
        .Mul => Opcode.MUL,
        .Div => Opcode.DIV,
        .Equal => Opcode.EQ,
        .NotEqual => Opcode.NE,
        .Less => Opcode.LT,
        .Greater => Opcode.GT,
        else => Opcode.NOP,
    };
}

fn compileIf(cg: *Codegen, expr: IfExpr) CodegenError!void {
    try compileExpr(cg, expr.condition);
    _ = try cg.freshLabel();
    try cg.code.emit(Opcode.JZ);
    const else_jump = try cg.code.emitJumpPlaceholder();
    try compileExpr(cg, expr.then_branch);
    _ = try cg.freshLabel();
    try cg.code.emit(Opcode.JUMP);
    const end_jump = try cg.code.emitJumpPlaceholder();
    const else_pos = cg.code.bytes.items.len;
    try cg.code.patchJump(else_jump, else_pos);
    try compileExpr(cg, expr.else_branch);
    const end_pos = cg.code.bytes.items.len;
    try cg.code.patchJump(end_jump, end_pos);
}

fn compileLet(cg: *Codegen, expr: LetExpr) CodegenError!void {
    // Compile the value expression first
    try compileExpr(cg, expr.value);
    // For now, just emit the value and continue with body
    // In a full implementation, we'd store the value in a register/stack slot
    try compileExpr(cg, expr.body);
}

fn compileFn(cg: *Codegen, expr: FnExpr) CodegenError!void {
    _ = expr;
    try cg.code.emit(Opcode.NOP);
}

fn compileFnCall(cg: *Codegen, expr: FnCallExpr) CodegenError!void {
    for (expr.args) |arg| {
        try compileExpr(cg, arg);
        try cg.code.emit(Opcode.PUSH);
    }
    try compileExpr(cg, expr.func);
    try cg.code.emit(Opcode.CALL);
}

fn compileADT(cg: *Codegen, expr: ADTExpr) CodegenError!void {
    if (expr.data) |data| {
        try compileExpr(cg, data);
        try cg.code.emit(Opcode.ADTD);
    } else {
        try cg.code.emit(Opcode.ADTN);
    }
}

fn compileMatch(cg: *Codegen, expr: MatchExpr) CodegenError!void {
    // 1. Compile the value expression and push it
    try compileExpr(cg, expr.value);
    try cg.code.emit(Opcode.PUSH);

    // 2. For each arm, compile pattern match, guard, and body
    var arm_jump_targets = std.ArrayListAligned(usize, null).initCapacity(cg.allocator, expr.arms.len) catch {
        return error.OutOfMemory;
    };
    defer arm_jump_targets.deinit(cg.allocator);

    for (expr.arms) |arm| {
        // Compile pattern matching for this arm
        try compilePatternMatch(cg, arm.pattern);

        // If guard exists, compile guard condition
        // For now, guards are not in the simplified TypedExpr
        // Full implementation would check guard and JZ if false

        // Compile the arm body
        try compileExpr(cg, arm.body);

        // Jump to end after body (skip other arms)
        try cg.code.emit(Opcode.JUMP);
        try arm_jump_targets.append(cg.allocator, try cg.code.emitJumpPlaceholder());
    }

    // 3. Emit runtime error if no match (non-exhaustive match)
    // For now, just emit a NOP
    try cg.code.emit(Opcode.NOP);

    // 4. Patch all jump targets to the end
    const end_pos = cg.code.bytes.items.len;
    for (arm_jump_targets.items) |offset| {
        try cg.code.patchJump(offset, end_pos);
    }
}

/// Compile pattern matching for a match arm
fn compilePatternMatch(cg: *Codegen, pattern: MatchPattern) CodegenError!void {
    _ = cg;
    _ = pattern;
    // Full implementation would:
    // - Pop the value
    // - Check if pattern matches
    // - Emit JZ to next arm if no match
    // - Bind pattern variables to registers
    // For now, we assume all patterns match
    return;
}

/// Compile pipe expression: source |> stage1 |> stage2 |> ... |> stageN
/// Desugars to: stageN(...stage2(stage1(source))...)
fn compilePipe(cg: *Codegen, expr: PipeExpr) CodegenError!void {
    // Compile the source expression
    try compileExpr(cg, expr.source);

    // For each stage, emit a function call
    // a |> b |> c becomes: call(b, a), then call(c, result)
    for (expr.stages) |stage| {
        // Push current value
        try cg.code.emit(Opcode.PUSH);

        // Compile the stage (should be a function)
        try compileExpr(cg, stage);

        // Emit CALL instruction
        try cg.code.emit(Opcode.CALL);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: RESULT TYPE COMPILATION
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Compile Ok(value) constructor
pub fn compileResultOk(cg: *Codegen, value_expr: *const TypedExpr) CodegenError!void {
    try compileExpr(cg, value_expr);
    try cg.code.emit(Opcode.RESULT_OK);
}

/// Compile Err(error) constructor
pub fn compileResultErr(cg: *Codegen, error_expr: *const TypedExpr) CodegenError!void {
    try compileExpr(cg, error_expr);
    try cg.code.emit(Opcode.RESULT_ERR);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: LINEAR TYPE COMPILATION
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Compile linear value consumption
pub fn compileLinearConsume(cg: *Codegen, var_name: []const u8) CodegenError!void {
    _ = var_name;
    // Emit consume opcode
    try cg.code.emit(Opcode.LINEAR_CONSUME);
}

/// Compile linear value move (transfer ownership)
pub fn compileLinearMove(cg: *Codegen, source_expr: *const TypedExpr) CodegenError!void {
    try compileExpr(cg, source_expr);
    try cg.code.emit(Opcode.LINEAR_MOVE);
}

/// Compile linear value borrow (shared reference)
pub fn compileLinearBorrow(cg: *Codegen, source_expr: *const TypedExpr) CodegenError!void {
    try compileExpr(cg, source_expr);
    try cg.code.emit(Opcode.LINEAR_BORROW);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: ARRAY COMPILATION
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Compile array get operation with bounds checking
pub fn compileArrayGet(cg: *Codegen, array_expr: *const TypedExpr, index_expr: *const TypedExpr) CodegenError!void {
    try compileExpr(cg, array_expr);
    try cg.code.emit(Opcode.PUSH);
    try compileExpr(cg, index_expr);
    try cg.code.emit(Opcode.ARRAY_GET);
}

/// Compile array set operation with bounds checking
pub fn compileArraySet(cg: *Codegen, array_expr: *const TypedExpr, index_expr: *const TypedExpr, value_expr: *const TypedExpr) CodegenError!void {
    try compileExpr(cg, array_expr);
    try cg.code.emit(Opcode.PUSH);
    try compileExpr(cg, index_expr);
    try cg.code.emit(Opcode.PUSH);
    try compileExpr(cg, value_expr);
    try cg.code.emit(Opcode.ARRAY_SET);
}

/// Compile array length operation (compile-time constant)
pub fn compileArrayLen(cg: *Codegen, size: usize) CodegenError!void {
    _ = size;
    try cg.code.emit(Opcode.ARRAY_LEN);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "codegen init" {
    const a = std.testing.allocator;
    var cg = Codegen.init(a);
    defer cg.deinit();
    try std.testing.expectEqual(@as(usize, 0), cg.code.bytes.items.len);
}

test "emit LOADI" {
    const a = std.testing.allocator;
    var cg = Codegen.init(a);
    defer cg.deinit();

    const expr = TypedExpr{ .Int = .{ .value = 42 } };
    try compileExpr(&cg, &expr);

    try std.testing.expectEqual(@as(usize, 5), cg.code.bytes.items.len);
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.LOADI)), cg.code.bytes.items[0]);
}

test "emit LOADB true" {
    const a = std.testing.allocator;
    var cg = Codegen.init(a);
    defer cg.deinit();

    const expr = TypedExpr{ .Bool = .{ .value = true } };
    try compileExpr(&cg, &expr);

    try std.testing.expectEqual(@as(usize, 2), cg.code.bytes.items.len);
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.LOADB)), cg.code.bytes.items[0]);
    try std.testing.expectEqual(@as(u8, 1), cg.code.bytes.items[1]);
}

test "fresh label" {
    const a = std.testing.allocator;
    var cg = Codegen.init(a);
    defer cg.deinit();

    const l1 = try cg.freshLabel();
    defer a.free(l1);
    try std.testing.expectEqualStrings("L0", l1);

    const l2 = try cg.freshLabel();
    defer a.free(l2);
    try std.testing.expectEqualStrings("L1", l2);
}

test "compile pipe single stage" {
    const a = std.testing.allocator;
    const src = try a.create(TypedExpr);
    defer a.destroy(src);
    src.* = TypedExpr{ .Int = .{ .value = 42 } };

    const stage = try a.create(TypedExpr);
    defer a.destroy(stage);
    stage.* = TypedExpr{ .Int = .{ .value = 1 } };

    const stages = &[_]*const TypedExpr{stage};
    const expr = TypedExpr{ .Pipe = .{ .source = src, .stages = stages } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileExpr(&cg, &expr);

    // Should have LOADI + PUSH + LOADI + CALL
    try std.testing.expect(cg.code.bytes.items.len > 0);
}

test "compile match expression" {
    const a = std.testing.allocator;
    const val = try a.create(TypedExpr);
    defer a.destroy(val);
    val.* = TypedExpr{ .Int = .{ .value = 42 } };

    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Int = .{ .value = 0 } };

    const arms = &[_]MatchArm{
        .{ .pattern = .Wildcard, .body = body },
    };
    const expr = TypedExpr{ .Match = .{ .value = val, .arms = arms } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileExpr(&cg, &expr);

    // Should have LOADI + PUSH + NOP (simplified match)
    try std.testing.expect(cg.code.bytes.items.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 2: TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "compile Result Ok" {
    const a = std.testing.allocator;
    const val = try a.create(TypedExpr);
    defer a.destroy(val);
    val.* = TypedExpr{ .Int = .{ .value = 42 } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileResultOk(&cg, val);

    try std.testing.expect(cg.code.bytes.items.len > 0);
    // Last byte should be RESULT_OK opcode
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.RESULT_OK)), cg.code.bytes.items[cg.code.bytes.items.len - 1]);
}

test "compile Result Err" {
    const a = std.testing.allocator;
    const err = try a.create(TypedExpr);
    defer a.destroy(err);
    err.* = TypedExpr{ .Int = .{ .value = 1 } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileResultErr(&cg, err);

    try std.testing.expect(cg.code.bytes.items.len > 0);
    // Last byte should be RESULT_ERR opcode
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.RESULT_ERR)), cg.code.bytes.items[cg.code.bytes.items.len - 1]);
}

test "compile Linear Consume" {
    const a = std.testing.allocator;
    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileLinearConsume(&cg, "x");

    try std.testing.expectEqual(@as(usize, 1), cg.code.bytes.items.len);
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.LINEAR_CONSUME)), cg.code.bytes.items[0]);
}

test "compile Linear Move" {
    const a = std.testing.allocator;
    const val = try a.create(TypedExpr);
    defer a.destroy(val);
    val.* = TypedExpr{ .Int = .{ .value = 42 } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileLinearMove(&cg, val);

    try std.testing.expect(cg.code.bytes.items.len > 0);
    // Last byte should be LINEAR_MOVE opcode
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.LINEAR_MOVE)), cg.code.bytes.items[cg.code.bytes.items.len - 1]);
}

test "compile Linear Borrow" {
    const a = std.testing.allocator;
    const val = try a.create(TypedExpr);
    defer a.destroy(val);
    val.* = TypedExpr{ .Int = .{ .value = 42 } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileLinearBorrow(&cg, val);

    try std.testing.expect(cg.code.bytes.items.len > 0);
    // Last byte should be LINEAR_BORROW opcode
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.LINEAR_BORROW)), cg.code.bytes.items[cg.code.bytes.items.len - 1]);
}

test "compile Array Get" {
    const a = std.testing.allocator;
    const arr = try a.create(TypedExpr);
    defer a.destroy(arr);
    arr.* = TypedExpr{ .Int = .{ .value = 0 } };

    const idx = try a.create(TypedExpr);
    defer a.destroy(idx);
    idx.* = TypedExpr{ .Int = .{ .value = 5 } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileArrayGet(&cg, arr, idx);

    try std.testing.expect(cg.code.bytes.items.len > 0);
    // Last byte should be ARRAY_GET opcode
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.ARRAY_GET)), cg.code.bytes.items[cg.code.bytes.items.len - 1]);
}

test "compile Array Set" {
    const a = std.testing.allocator;
    const arr = try a.create(TypedExpr);
    defer a.destroy(arr);
    arr.* = TypedExpr{ .Int = .{ .value = 0 } };

    const idx = try a.create(TypedExpr);
    defer a.destroy(idx);
    idx.* = TypedExpr{ .Int = .{ .value = 5 } };

    const val = try a.create(TypedExpr);
    defer a.destroy(val);
    val.* = TypedExpr{ .Int = .{ .value = 99 } };

    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileArraySet(&cg, arr, idx, val);

    try std.testing.expect(cg.code.bytes.items.len > 0);
    // Last byte should be ARRAY_SET opcode
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.ARRAY_SET)), cg.code.bytes.items[cg.code.bytes.items.len - 1]);
}

test "compile Array Len" {
    const a = std.testing.allocator;
    var cg = Codegen.init(a);
    defer cg.deinit();

    try compileArrayLen(&cg, 16);

    try std.testing.expectEqual(@as(usize, 1), cg.code.bytes.items.len);
    try std.testing.expectEqual(@as(u8, @intFromEnum(Opcode.ARRAY_LEN)), cg.code.bytes.items[0]);
}

test "Wave 2 opcodes are distinct" {
    try std.testing.expectEqual(@as(u8, 0x72), @intFromEnum(Opcode.RESULT_OK));
    try std.testing.expectEqual(@as(u8, 0x73), @intFromEnum(Opcode.RESULT_ERR));
    try std.testing.expectEqual(@as(u8, 0x74), @intFromEnum(Opcode.LINEAR_CONSUME));
    try std.testing.expectEqual(@as(u8, 0x75), @intFromEnum(Opcode.LINEAR_BORROW));
    try std.testing.expectEqual(@as(u8, 0x76), @intFromEnum(Opcode.LINEAR_MOVE));
    try std.testing.expectEqual(@as(u8, 0x77), @intFromEnum(Opcode.ARRAY_GET));
    try std.testing.expectEqual(@as(u8, 0x78), @intFromEnum(Opcode.ARRAY_LEN));
    try std.testing.expectEqual(@as(u8, 0x79), @intFromEnum(Opcode.ARRAY_SET));
}
