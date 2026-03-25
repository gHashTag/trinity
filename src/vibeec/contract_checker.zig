// ═════════════════════════════════════════════════════════════════════════
// CONTRACT CHECKER — Type-checking and Verification for Contracts
// ═════════════════════════════════════════════════════════════════════════════
//
// Type-checks @require/@ensure expressions against function signatures
// Verifies contracts at compile-time (for provable contracts)
// Generates runtime assertion code from contracts
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const dsl = @import("contract_dsl.zig");
const ExprNode = dsl.ExprNode;

// ═════════════════════════════════════════════════════════════════════════════════════
// Type System
// ═════════════════════════════════════════════════════════════════════════════════════════════════

pub const ContractType = enum {
    bool,      // Boolean expression (require/ensure)
    numeric,   // Numeric comparison or computation
    void,       // No value (side effect check only)
};

pub const Param = struct {
    name: []const u8,
    type_name: []const u8,
};

pub const CheckResult = struct {
    is_valid: bool,
    error_message: ?[]const u8 = null,
    inferred_type: ?ContractType = null,
};

pub const VerifyResult = struct {
    is_provable: bool,
    proof_steps: ArrayList([]const u8),
    remaining_goals: ArrayList([]const u8),
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// Type-checking
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

/// Type-check a contract expression against function signature
pub fn checkContract(
    allocator: Allocator,
    contract: []const u8,
    params: []const Param,
    returns: ?ContractType,
) !CheckResult {
    var result = CheckResult{
        .is_valid = false,
        .error_message = null,
        .inferred_type = null,
    };

    // Parse contract expression
    const expr = dsl.parseContract(allocator, contract) catch |err| {
        result.error_message = try std.fmt.allocPrint(allocator, "Parse error: {any}", .{err});
        return result;
    };
    defer {
        // Free AST nodes
        // TODO: Implement proper AST cleanup
    }

    // Infer expression type
    const inferred = try inferExpressionType(allocator, expr, params);
    result.inferred_type = inferred;

    // For require/ensure, expect bool type
    if (returns) |expected_type| {
        if (inferred != expected_type) {
            result.error_message = try std.fmt.allocPrint(
                allocator,
                "Type mismatch: contract is {s}, expected {s}",
                .{@tagName(inferred), @tagName(expected_type)},
            );
            return result;
        }
    }

    result.is_valid = true;
    return result;
}

/// Infer type of an expression
fn inferExpressionType(
    allocator: Allocator,
    expr: *const ExprNode,
    params: []const Param,
) !ContractType {
    _ = allocator;

    return switch (expr.*) {
        .int_lit => .numeric,
        .float_lit => .numeric,
        .bool_lit => .bool,

        // Variable lookup
        .identifier => |ident| {
            // Check if identifier is a parameter
            for (params) |p| {
                if (std.mem.eql(u8, p.name, ident)) {
                    return inferTypeNameToType(p.type_name);
                }
            }
            // Unknown variable
            return .numeric; // Default assumption
        },

        // Binary operations
        .add, .sub, .mul, .div, .mod => .numeric,
        .eq, .ne, .lt, .le, .gt, .ge => .bool,
        .logical_and, .logical_or, .kw_in => .bool,
        .not => .bool,
        .neg => .numeric,

        // Other: default to bool
        else => .bool,
    };
}

/// Convert type name to ContractType
fn inferTypeNameToType(type_name: []const u8) ContractType {
    if (std.mem.startsWith(u8, type_name, "u") or
        std.mem.startsWith(u8, type_name, "i") or
        std.mem.eql(u8, type_name, "usize") or
        std.mem.eql(u8, type_name, "isize"))
    {
        return .numeric;
    }

    if (std.mem.eql(u8, type_name, "bool")) {
        return .bool;
    }

    if (std.mem.eql(u8, type_name, "void")) {
        return .void;
    }

    // Default
    return .numeric;
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// Verification
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Verify a contract at compile-time (for provable contracts)
pub fn verifyContract(
    allocator: Allocator,
    contract: []const u8,
    inputs: []const []const u8,
) !bool {
    _ = allocator;
    _ = contract;
    _ = inputs;

    // TODO: Implement theorem prover integration
    // For now, always return false (not provable)
    return false;
}

/// Generate runtime assertion code from a contract
pub fn generateAssertion(
    allocator: Allocator,
    contract: []const u8,
) ![]const u8 {
    var code = ArrayList(u8){};

    // Parse contract to check for range expressions
    const expr = dsl.parseContract(allocator, contract) catch {
        // Fallback: simple assertion
        try appendStr(allocator, &code, "debug.assert(");
        try appendStr(allocator, &code, contract);
        try appendStr(allocator, &code, ", \"contract not satisfied\")");
        try code.append(allocator, '\n');
        return code.toOwnedSlice(allocator);
    };
    defer {
        // AST cleanup would go here
        _ = expr;
    }

    // Convert range expression x in [min, max] to x >= min and x <= max
    // For now, just wrap contract in debug.assert
    try appendStr(allocator, &code, "debug.assert(");
    try appendStr(allocator, &code, contract);
    try appendStr(allocator, &code, ", \"contract not satisfied\")");
    try code.append(allocator, '\n');

    return code.toOwnedSlice(allocator);
}

/// Helper to append string slice to ArrayList
fn appendStr(allocator: Allocator, list: *ArrayList(u8), str: []const u8) !void {
    for (str) |c| {
        try list.append(allocator, c);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Tests
// ═════════════════════════════════════════════════════════════════════════════════════════════════

test "infer type from int literal" {
    const allocator = std.testing.allocator;
    const params = [_]Param{};
    const expr: ExprNode = .{ .int_lit = 42 };

    const inferred = try inferExpressionType(allocator, &expr, &params);
    try std.testing.expectEqual(ContractType.numeric, inferred);
}

test "infer type from bool literal" {
    const allocator = std.testing.allocator;
    const params = [_]Param{};
    const expr: ExprNode = .{ .bool_lit = true };

    const inferred = try inferExpressionType(allocator, &expr, &params);
    try std.testing.expectEqual(ContractType.bool, inferred);
}

test "infer type from comparison" {
    const allocator = std.testing.allocator;
    const params = [_]Param{};

    // Create AST nodes for "x < 0"
    const x_node = try allocator.create(ExprNode);
    x_node.* = .{ .identifier = "x" };

    const zero_node = try allocator.create(ExprNode);
    zero_node.* = .{ .int_lit = 0 };

    const binop = try allocator.create(ExprNode.BinOp);
    binop.* = .{ .left = x_node, .right = zero_node };

    const expr: ExprNode = .{ .lt = binop };

    const inferred = try inferExpressionType(allocator, &expr, &params);
    try std.testing.expectEqual(ContractType.bool, inferred);
}

test "infer type from parameter name" {
    const allocator = std.testing.allocator;
    const params = [_]Param{
        .{ .name = "count", .type_name = "u32" },
    };
    const expr: ExprNode = .{ .identifier = "count" };

    const inferred = try inferExpressionType(allocator, &expr, &params);
    try std.testing.expectEqual(ContractType.numeric, inferred);
}

test "infer type from bool parameter" {
    const allocator = std.testing.allocator;
    const params = [_]Param{
        .{ .name = "flag", .type_name = "bool" },
    };
    const expr: ExprNode = .{ .identifier = "flag" };

    const inferred = try inferExpressionType(allocator, &expr, &params);
    try std.testing.expectEqual(ContractType.bool, inferred);
}

test "generate assertion code" {
    const allocator = std.testing.allocator;
    const contract = "x >= 0";

    const code = try generateAssertion(allocator, contract);
    defer allocator.free(code);

    try std.testing.expectEqualStrings(
        \\debug.assert(x >= 0, "contract not satisfied")
        \\
    ,
        code,
    );
}
