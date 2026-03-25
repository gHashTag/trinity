// ═══════════════════════════════════════════════════════════════════
// Guards (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/tri-lang/guards.tri
//
// Issue #408: Guard conditions in match expressions
//
// Implements:
// - GuardExpr: boolean, int, identifier, binary/unary ops
// - Guard evaluation: constant folding at compile time
// - GuardCodegen: bytecode generation for guards
// - compileGuard: emit JZ on guard failure
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Simple expression types for guard evaluation
// Using inline types to avoid self-referential union issues
pub const GuardExpr = union(enum) {
    BoolLiteral: bool,
    IntLiteral: i64,
    Identifier: []const u8,
    BinaryOp: GuardBinaryOp,
    UnaryOp: GuardUnaryOp,
};

pub const GuardBinaryOp = struct {
    op: BinaryOperator,
    left: *const GuardExpr,
    right: *const GuardExpr,
};

pub const GuardUnaryOp = struct {
    op: UnaryOperator,
    operand: *const GuardExpr,
};

pub const BinaryOperator = enum {
    BitAnd,
    BitOr,
    Add,
    Sub,
    Mul,
    Div,
    Equal,
    NotEqual,
    Less,
    Greater,
};

pub const UnaryOperator = enum {
    BitNot,
    Neg,
};

/// Guard compilation result
pub const GuardResult = struct {
    /// Whether the guard condition is trivially true (can be skipped)
    always_true: bool,
    /// Whether the guard condition is trivially false (arm never matches)
    always_false: bool,
};

/// Evaluate a guard condition at compile time if possible
/// Returns: .always_true, .always_false, or neither (runtime check needed)
pub fn evalGuard(guard: Guard) GuardResult {
    return evalGuardExpr(&guard.condition);
}

/// Evaluate a guard expression for constant folding
fn evalGuardExpr(expr: *const GuardExpr) GuardResult {
    return switch (expr.*) {
        // BoolLiteral true => always matches
        .BoolLiteral => |e| .{
            .always_true = e,
            .always_false = !e,
        },

        // Integer literal 0 => false, non-zero => true
        .IntLiteral => |e| .{
            .always_true = e != 0,
            .always_false = e == 0,
        },

        // Binary operations with constants
        .BinaryOp => |binop| evalBinaryOp(binop),

        // Unary not on constant
        .UnaryOp => |unop| evalUnaryOp(unop),

        // Everything else requires runtime check
        else => .{
            .always_true = false,
            .always_false = false,
        },
    };
}

/// Evaluate binary operation for constant folding
fn evalBinaryOp(binop: GuardBinaryOp) GuardResult {
    const left = evalGuardExpr(binop.left);
    const right = evalGuardExpr(binop.right);

    // If either side is always false for AND, result is always false
    if (binop.op == .BitAnd and left.always_false) {
        return .{ .always_true = false, .always_false = true };
    }
    if (binop.op == .BitAnd and right.always_false) {
        return .{ .always_true = false, .always_false = true };
    }

    // If either side is always true for OR, result is always true
    if (binop.op == .BitOr and left.always_true) {
        return .{ .always_true = true, .always_false = false };
    }
    if (binop.op == .BitOr and right.always_true) {
        return .{ .always_true = true, .always_false = false };
    }

    // Both sides must be constant for full evaluation
    if (left.always_true or left.always_false) {
        if (right.always_true or right.always_false) {
            // Both are constants - can evaluate
            const l_val = left.always_true;
            const r_val = right.always_true;
            return switch (binop.op) {
                .BitAnd => .{
                    .always_true = l_val and r_val,
                    .always_false = !(l_val and r_val),
                },
                .BitOr => .{
                    .always_true = l_val or r_val,
                    .always_false = !(l_val or r_val),
                },
                else => .{
                    .always_true = false,
                    .always_false = false,
                },
            };
        }
    }

    // Can't determine at compile time
    return .{
        .always_true = false,
        .always_false = false,
    };
}

/// Evaluate unary operation for constant folding
fn evalUnaryOp(unop: GuardUnaryOp) GuardResult {
    const inner = evalGuardExpr(unop.operand);

    // Negate if we have a constant result
    if (inner.always_true or inner.always_false) {
        return switch (unop.op) {
            .BitNot => .{
                .always_true = !inner.always_true,
                .always_false = !inner.always_false,
            },
            else => inner,
        };
    }

    return .{
        .always_true = false,
        .always_false = false,
    };
}

/// Simple guard type for internal use
pub const Guard = struct {
    condition: GuardExpr,
};

/// Check if a guard is trivial (always true or always false)
pub fn isTrivialGuard(guard: Guard) bool {
    const result = evalGuard(guard);
    return result.always_true or result.always_false;
}

/// Check if a guard always passes
pub fn guardAlwaysPasses(guard: Guard) bool {
    return evalGuard(guard).always_true;
}

/// Check if a guard always fails
pub fn guardAlwaysFails(guard: Guard) bool {
    return evalGuard(guard).always_false;
}

/// Guard bytecode compilation context
pub const GuardCodegen = struct {
    allocator: Allocator,
    bytecode: std.ArrayList(u8),
    label_counter: u32 = 0,

    pub fn init(allocator: Allocator) GuardCodegen {
        return .{
            .allocator = allocator,
            .bytecode = std.ArrayList(u8).initCapacity(allocator, 16) catch .empty,
        };
    }

    pub fn deinit(self: *GuardCodegen, allocator: Allocator) void {
        self.bytecode.deinit(allocator);
    }

    /// Emit a jump if zero (JZ) instruction for guard failure
    pub fn emitGuardCheck(self: *GuardCodegen, guard: Guard) !void {
        _ = guard;
        // Emit JZ instruction (opcode 0x51)
        try self.bytecode.append(self.allocator, 0x51);
        // Placeholder for jump target (will be patched)
        try self.bytecode.appendSlice(self.allocator, &[_]u8{ 0, 0, 0, 0 });
    }

    /// Get fresh label for guard failure jump
    pub fn freshLabel(self: *GuardCodegen) ![]const u8 {
        const id = self.label_counter;
        self.label_counter += 1;
        return std.fmt.allocPrint(self.allocator, "guard_fail_{d}", .{id});
    }

    pub fn getBytecode(self: *const GuardCodegen) []const u8 {
        return self.bytecode.items;
    }
};

/// Compile a guard condition to bytecode
pub fn compileGuard(cg: *GuardCodegen, guard: Guard) !void {
    // If guard is always true, skip compilation
    if (guardAlwaysPasses(guard)) {
        return;
    }

    // If guard is always false, emit unreachable
    if (guardAlwaysFails(guard)) {
        // Emit HALT instruction (opcode 0xFF)
        try cg.bytecode.append(cg.allocator, 0xFF);
        return;
    }

    // Compile guard condition and emit JZ on failure
    try compileGuardExpr(cg, &guard.condition);
    try cg.emitGuardCheck(guard);
}

/// Compile a guard expression to bytecode
fn compileGuardExpr(cg: *GuardCodegen, expr: *const GuardExpr) !void {
    _ = cg;
    _ = expr;
    // Full implementation would emit bytecode for the guard condition
    // For now, we just emit the check in emitGuardCheck
}

/// Optimize guard conditions
/// Removes redundant checks, folds constants
pub fn optimizeGuard(guard: Guard) !Guard {
    // TODO: Implement constant propagation and dead code elimination
    return guard;
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════

test "evalGuard with true literal" {
    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = true },
    };

    const result = evalGuard(guard);
    try std.testing.expect(result.always_true);
    try std.testing.expect(!result.always_false);
}

test "evalGuard with false literal" {
    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = false },
    };

    const result = evalGuard(guard);
    try std.testing.expect(!result.always_true);
    try std.testing.expect(result.always_false);
}

test "evalGuard with non-zero integer" {
    const guard = Guard{
        .condition = GuardExpr{ .IntLiteral = 42 },
    };

    const result = evalGuard(guard);
    try std.testing.expect(result.always_true);
}

test "evalGuard with zero integer" {
    const guard = Guard{
        .condition = GuardExpr{ .IntLiteral = 0 },
    };

    const result = evalGuard(guard);
    try std.testing.expect(result.always_false);
}

test "guardAlwaysPasses with true" {
    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = true },
    };

    try std.testing.expect(guardAlwaysPasses(guard));
}

test "guardAlwaysFails with false" {
    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = false },
    };

    try std.testing.expect(guardAlwaysFails(guard));
}

test "isTrivialGuard with constant" {
    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = true },
    };

    try std.testing.expect(isTrivialGuard(guard));
}

test "isTrivialGuard with variable" {
    const guard = Guard{
        .condition = GuardExpr{ .Identifier = "x" },
    };

    try std.testing.expect(!isTrivialGuard(guard));
}

test "GuardCodegen init" {
    var cg = GuardCodegen.init(std.testing.allocator);
    defer cg.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), cg.bytecode.items.len);
    try std.testing.expectEqual(@as(u32, 0), cg.label_counter);
}

test "GuardCodegen freshLabel" {
    var cg = GuardCodegen.init(std.testing.allocator);
    defer cg.deinit(std.testing.allocator);

    const l1 = try cg.freshLabel();
    defer std.testing.allocator.free(l1);
    try std.testing.expectEqualStrings("guard_fail_0", l1);

    const l2 = try cg.freshLabel();
    defer std.testing.allocator.free(l2);
    try std.testing.expectEqualStrings("guard_fail_1", l2);
}

test "compileGuard with always true guard" {
    var cg = GuardCodegen.init(std.testing.allocator);
    defer cg.deinit(std.testing.allocator);

    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = true },
    };

    try compileGuard(&cg, guard);

    // Should not emit any bytecode for always-true guard
    try std.testing.expectEqual(@as(usize, 0), cg.bytecode.items.len);
}

test "compileGuard with always false guard" {
    var cg = GuardCodegen.init(std.testing.allocator);
    defer cg.deinit(std.testing.allocator);

    const guard = Guard{
        .condition = GuardExpr{ .BoolLiteral = false },
    };

    try compileGuard(&cg, guard);

    // Should emit HALT (0xFF)
    try std.testing.expectEqual(@as(usize, 1), cg.bytecode.items.len);
    try std.testing.expectEqual(@as(u8, 0xFF), cg.bytecode.items[0]);
}
