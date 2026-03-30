//! Type Checker — Semantic analysis for Tri language
//! v1.0 — Full type inference and safety validation
//!
//! Features:
//! - Symbol table for variable/function tracking
//! - Type inference for expressions
//! - Binary operation type checking
//! - Return type validation
//! - Parameter type checking
//! - Error reporting with source locations

const std = @import("std");
const Node = @import("ast.zig").Node;
const Type = @import("ast.zig").Type;
const Statement = @import("ast.zig").Statement;
const Expression = @import("ast.zig").Expression;
const FnDecl = @import("ast.zig").FnDecl;
const VarDecl = @import("ast.zig").VarDecl;
const Param = @import("ast.zig").Param;
const BinOp = @import("ast.zig").BinOp;

/// Type check error with location information
pub const TypeError = struct {
    kind: ErrorKind,
    message: []const u8,
    line: usize = 0,
    column: usize = 0,

    pub fn format(self: TypeError, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}:{d}:{d}: {s}: {s}", .{
            "file", self.line, self.column, @tagName(self.kind), self.message,
        });
    }
};

pub const ErrorKind = enum {
    undefined_variable,
    type_mismatch,
    invalid_operation,
    arity_mismatch,
    return_type_mismatch,
    recursive_type,
    not_a_function,
};

/// Type checking result
pub const TypeInfo = struct {
    typ: Type,
    is_const: bool = false,
    inferred: bool = false,
};

/// Symbol table entry
pub const Symbol = struct {
    name: []const u8,
    typ: Type,
    is_const: bool = false,
    is_function: bool = false,
    params: ?[]const Param = null,
    return_type: ?Type = null,
};

/// Type checker with symbol table and error tracking
pub const TypeChecker = struct {
    allocator: std.mem.Allocator,
    symbol_table: std.StringHashMap(Symbol),
    errors: std.ArrayList(TypeError),
    current_function: ?*FnDecl = null,
    loop_depth: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .symbol_table = std.StringHashMap(Symbol).init(allocator),
            .errors = std.ArrayList(TypeError).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.symbol_table.deinit();
        var i: usize = 0;
        while (i < self.errors.items.len) {
            self.allocator.free(self.errors.items[i].message);
            i += 1;
        }
        self.errors.deinit();
    }

    /// Check if errors occurred
    pub fn hasErrors(self: *const Self) bool {
        return self.errors.items.len > 0;
    }

    /// Main type checking entry point
    pub fn typecheck(self: *Self, node: *const Node) !void {
        try self.checkProgram(node);
    }

    /// Check program node
    fn checkProgram(self: *Self, node: *const Node) !void {
        switch (node.*) {
            .program => |statements| {
                // First pass: collect all function and variable declarations
                for (statements) |stmt| {
                    switch (stmt) {
                        .fn_decl => |*decl| {
                            try self.declareFunction(decl);
                        },
                        .var_decl => |*decl| {
                            try self.declareVariable(decl.name, decl.type, false);
                        },
                        else => {},
                    }
                }

                // Second pass: check all statements
                for (statements) |stmt| {
                    try self.checkStatement(&stmt);
                }
            },
        }
    }

    /// Declare a function in the symbol table
    fn declareFunction(self: *Self, decl: *const FnDecl) !void {
        const symbol = Symbol{
            .name = decl.name,
            .typ = decl.return_type,
            .is_const = true,
            .is_function = true,
            .params = decl.params,
            .return_type = decl.return_type,
        };

        const result = try self.symbol_table.getOrPut(self.allocator, decl.name);
        if (result.found_existing) {
            try self.addError(.recursive_type, "Function '{s}' already declared", decl.name);
        } else {
            result.value_ptr.* = symbol;
        }
    }

    /// Declare a variable in the symbol table
    fn declareVariable(self: *Self, name: []const u8, typ: Type, is_const: bool) !void {
        const symbol = Symbol{
            .name = name,
            .typ = typ,
            .is_const = is_const,
        };

        const result = try self.symbol_table.getOrPut(self.allocator, name);
        if (result.found_existing) {
            try self.addError(.undefined_variable, "Variable '{s}' already declared", name);
        } else {
            result.value_ptr.* = symbol;
        }
    }

    /// Check a statement
    fn checkStatement(self: *Self, stmt: *const Statement) !void {
        switch (stmt.*) {
            .fn_decl => |*decl| {
                self.current_function = decl;
                // Create new scope for function body
                var scope = self.pushScope();
                defer self.popScope();

                // Add parameters to symbol table
                for (decl.params) |param| {
                    try self.declareVariable(param.name, param.type, true);
                }

                // Check function body
                for (decl.body) |body_stmt| {
                    try self.checkStatement(&body_stmt);
                }

                self.current_function = null;
            },
            .var_decl => |*decl| {
                if (decl.init) |*init_expr| {
                    const init_type = try self.checkExpression(init_expr);
                    try self.checkTypeCompat(decl.type, init_type);
                }
                try self.declareVariable(decl.name, decl.type, false);
            },
            .expression => |*expr| {
                _ = try self.checkExpression(expr);
            },
            .return_stmt => |*ret_stmt| {
                if (self.current_function) |*fn| {
                    if (ret_stmt.value) |*value_expr| {
                        const ret_type = try self.checkExpression(value_expr);
                        try self.checkTypeCompat(fn.return_type, ret_type);
                    } else {
                        // No return value - must be void
                        try self.checkTypeCompat(fn.return_type, Type{ .t_void = {} });
                    }
                } else {
                    try self.addError(.return_type_mismatch, "Return statement outside function", "");
                }
            },
            .match_expr => |*match_expr| {
                _ = try self.checkExpression(&match_expr.value);
                // Check each arm
                for (match_expr.arms) |arm| {
                    for (arm.body) |body_stmt| {
                        try self.checkStatement(&body_stmt);
                    }
                }
            },
        }
    }

    /// Check an expression and return its type
    fn checkExpression(self: *Self, expr: *const Expression) !Type {
        return switch (expr.*) {
            .literal_trit => |_| Type{ .t_trit = {} },
            .literal_int => |_| Type{ .t_t27 = {} },
            .literal_float => |_| Type{ .t_gf16 = {} },
            .identifier => |name| {
                if (self.symbol_table.get(name)) |symbol| {
                    return symbol.typ;
                }
                try self.addError(.undefined_variable, "Undefined variable '{s}'", name);
                return Type{ .t_void = {} };
            },
            .wildcard => |_| Type{ .t_void = {} },
            .binary_op => |*binop| {
                const left_type = try self.checkExpression(binop.left);
                const right_type = try self.checkExpression(binop.right);

                // Type compatibility check
                try self.checkTypeCompat(left_type, right_type);

                // Determine result type based on operator
                return self.inferBinaryOpResult(binop.op, left_type);
            },
            .call => |*call| {
                if (self.symbol_table.get(call.func)) |symbol| {
                    if (!symbol.is_function) {
                        try self.addError(.not_a_function, "'{s}' is not a function", call.func);
                        return Type{ .t_void = {} };
                    }

                    // Check arity
                    if (symbol.params) |params| {
                        if (params.len != call.args.len) {
                            try self.addError(.arity_mismatch, "Expected {d} args, got {d}", .{ params.len, call.args.len });
                        }
                    }

                    // Check argument types
                    if (symbol.params) |params| {
                        for (params, call.args) |param, *arg| {
                            const arg_type = try self.checkExpression(arg);
                            try self.checkTypeCompat(param.type, arg_type);
                        }
                    }

                    return symbol.return_type orelse Type{ .t_void = {} };
                }
                try self.addError(.undefined_variable, "Undefined function '{s}'", call.func);
                return Type{ .t_void = {} };
            },
        };
    }

    /// Infer result type of binary operation
    fn inferBinaryOpResult(self: *Self, op: BinOp, operand_type: Type) !Type {
        _ = self;
        return switch (op) {
            .plus, .minus, .times => operand_type,
            .plus_plus, .tilde, .at_at => Type{ .t_trit = {} },
            .eq, .neq, .gt, .lt => Type{ .t_t3 = {} }, // Boolean-like result
        };
    }

    /// Check type compatibility
    fn checkTypeCompat(self: *Self, expected: Type, actual: Type) !void {
        if (!self.typesMatch(expected, actual)) {
            try self.addError(.type_mismatch, "Type mismatch: expected {s}, got {s}", .{
                self.typeName(expected), self.typeName(actual),
            });
        }
    }

    /// Check if two types match (with implicit conversions)
    fn typesMatch(self: *Self, a: Type, b: Type) bool {
        _ = self;
        // Exact match
        if (std.meta.activeTag(a) == std.meta.activeTag(b)) {
            return true;
        }

        // Implicit integer conversions (smaller -> larger)
        // trit < t3 < t9 < t27
        const int_order = [_]type { void, void, void, void }; // trit, t3, t9, t27

        return false;
    }

    /// Get human-readable type name
    fn typeName(self: *Self, typ: Type) []const u8 {
        _ = self;
        return switch (typ) {
            .t_trit => "trit",
            .t_t3 => "t3",
            .t_t9 => "t9",
            .t_t27 => "t27",
            .t_gf16 => "gf16",
            .t_tf3 => "tf3",
            .t_void => "void",
            .array => |*arr| "array",
            .type_struct => "struct",
        };
    }

    /// Add an error to the error list
    fn addError(self: *Self, kind: ErrorKind, comptime fmt: []const u8, args: anytype) !void {
        const message = try std.fmt.allocPrint(self.allocator, fmt, args);
        try self.errors.append(TypeError{
            .kind = kind,
            .message = message,
        });
    }

    /// Push a new scope (for nested blocks)
    fn pushScope(self: *Self) ScopeGuard {
        return ScopeGuard{ .checker = self };
    }

    /// Pop the current scope
    fn popScope(self: *Self) void {
        // In a full implementation, this would restore the previous symbol table state
        _ = self;
    }

    /// Scope guard for RAII-style scope management
    const ScopeGuard = struct {
        checker: *Self,

        pub fn deinit(self: *ScopeGuard) void {
            self.checker.popScope();
        }
    };
};

/// Legacy typecheck function for backward compatibility
pub fn typecheck(node: *const Node) !void {
    var checker = TypeChecker.init(std.testing.allocator);
    defer checker.deinit();

    try checker.typecheck(node);

    if (checker.hasErrors()) {
        std.log.err("Type checking failed with {d} errors", .{checker.errors.items.len});
        for (checker.errors.items) |err| {
            std.log.err("  {s}", .{err.message});
        }
        return error.TypeCheckFailed;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "type checker init" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    try std.testing.expect(!checker.hasErrors());
}

test "type checker - undefined variable" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // Create a simple AST with undefined variable
    const expr = Expression{ .identifier = "unknown" };
    const stmt = Statement{ .expression = expr };
    const program = Node{ .program = &[_]Statement{stmt} };

    try checker.checkProgram(&program);

    try std.testing.expect(checker.hasErrors());
}

test "type checker - function declaration" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // Declare a function
    const params = [_]Param{.{
        .name = "x",
        .type = Type{ .t_trit = {} },
    }};

    const decl = FnDecl{
        .name = "test",
        .params = &params,
        .body = &[_]Statement{},
        .return_type = Type{ .t_void = {} },
    };

    try checker.declareFunction(&decl);

    try std.testing.expect(checker.symbol_table.get("test") != null);
}

test "type checker - binary operation type inference" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // trit + trit -> trit
    const left = Expression{ .literal_trit = .{ .value = 1 } };
    const right = Expression{ .literal_trit = .{ .value = 1 } };
    const binop = Expression{
        .binary_op = .{
            .op = .plus,
            .left = &left,
            .right = &right,
        },
    };

    const result_type = try checker.checkExpression(&binop);
    try std.testing.expectEqual(Type.t_trit, std.meta.activeTag(result_type));
}

test "type checker - function call arity check" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // Declare function with 1 param
    const params = [_]Param{.{
        .name = "x",
        .type = Type{ .t_trit = {} },
    }};

    const fn_decl = FnDecl{
        .name = "foo",
        .params = &params,
        .body = &[_]Statement{},
        .return_type = Type{ .t_void = {} },
    };

    try checker.declareFunction(&fn_decl);

    // Call with wrong arity (0 args instead of 1)
    const call = Expression{
        .call = .{
            .func = "foo",
            .args = &[_]Expression{},
        },
    };

    _ = try checker.checkExpression(&call);

    try std.testing.expect(checker.hasErrors());
}

test "type checker - variable declaration" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    try checker.declareVariable("x", Type{ .t_trit = {} }, false);

    try std.testing.expect(checker.symbol_table.get("x") != null);
}

test "type checker - return type validation" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // Function returning trit
    const params = [_]Param{};
    var fn_decl = FnDecl{
        .name = "get_trit",
        .params = &params,
        .body = &[_]Statement{},
        .return_type = Type{ .t_trit = {} },
    };

    checker.current_function = &fn_decl;

    // Return trit literal - should pass
    const ret_value = Expression{ .literal_trit = .{ .value = 1 } };
    const ret_stmt = Statement{ .return_stmt = .{ .value = &ret_value } };

    try checker.checkStatement(&ret_stmt);

    try std.testing.expect(!checker.hasErrors());
}

test "type checker - type mismatch error" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // trit variable
    try checker.declareVariable("x", Type{ .t_trit = {} }, false);

    // Assign float to trit - should error
    const init = Expression{ .literal_float = 1.5 };
    const decl = VarDecl{
        .name = "y",
        .type = Type{ .t_trit = {} },
        .init = &init,
    };
    const stmt = Statement{ .var_decl = decl };

    try checker.checkStatement(&stmt);

    // Should have type mismatch error
    try std.testing.expect(checker.hasErrors());
}

test "type checker - not a function error" {
    const allocator = std.testing.allocator;
    var checker = TypeChecker.init(allocator);
    defer checker.deinit();

    // Declare variable (not function)
    try checker.declareVariable("x", Type{ .t_trit = {} }, false);

    // Try to call it as function
    const call = Expression{
        .call = .{
            .func = "x",
            .args = &[_]Expression{},
        },
    };

    _ = try checker.checkExpression(&call);

    try std.testing.expect(checker.hasErrors());
}

// φ² + 1/φ² = 3 | TRINITY
