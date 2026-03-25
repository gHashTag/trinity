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
    try compileExpr(cg, expr.value);
    for (expr.arms) |arm| {
        try compileExpr(cg, arm.body);
    }
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
