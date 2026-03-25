// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// Wave 2: Type System Core — Type Representation
//
// Type enum with Unit, Bool, Int, Float, Fn, ADT, Var
// Type equality, substitution, free type variables
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Type identifier for unique types
pub const TypeId = u32;

/// Type variable counter (thread-local for type inference)
var next_type_var: TypeId = 1;

/// Fresh type variable generator
pub fn freshTypeVar() TypeId {
    const id = next_type_var;
    next_type_var += 1;
    return id;
}

/// Reset type variable counter (for testing)
pub fn resetTypeVar() void {
    next_type_var = 1;
}

/// Type representation
/// Following Hindley-Milner with algebraic data types
pub const Type = union(enum) {
    /// Unit type (only one value: {})
    Unit,

    /// Boolean type
    Bool,

    /// Integer type (signed, arbitrary precision in theory)
    Int,

    /// Float type (IEEE 754 double precision)
    Float,

    /// Function type: params -> return
    /// Arrow is right-associative: A -> B -> C means A -> (B -> C)
    Fn: struct {
        params: std.ArrayList(Type),
        return_type: *Type,
    },

    /// Algebraic Data Type
    /// Referenced by name to ADT definition
    ADT: struct {
        name: []const u8,
        type_args: std.ArrayList(Type),
    },

    /// Type variable (for polymorphism)
    /// Unification variable during inference
    Var: TypeId,

    /// Create a new Type owned by allocator
    pub fn init(allocator: std.mem.Allocator, tag: std.meta.Tag(Type)) !*Type {
        const t = try allocator.create(Type);
        t.* = switch (tag) {
            .Unit => .Unit,
            .Bool => .Bool,
            .Int => .Int,
            .Float => .Float,
            .Fn => .{
                .Fn = .{
                    .params = std.ArrayList(Type).init(allocator),
                    .return_type = undefined, // Will be set by caller
                },
            },
            .ADT => .{ .ADT = .{
                .name = "",
                .type_args = std.ArrayList(Type).init(allocator),
            } },
            .Var => .{ .Var = 0 }, // Placeholder, caller should set
        };
        return t;
    }

    /// Create a Var type with specific ID
    pub fn initVar(allocator: std.mem.Allocator, id: TypeId) !*Type {
        const t = try allocator.create(Type);
        t.* = .{ .Var = id };
        return t;
    }

    /// Deep copy a type
    pub fn clone(self: *const Type, allocator: std.mem.Allocator) !*Type {
        return switch (self.*) {
            .Unit => Type.init(allocator, .Unit),
            .Bool => Type.init(allocator, .Bool),
            .Int => Type.init(allocator, .Int),
            .Float => Type.init(allocator, .Float),
            .Fn => |fn_data| blk: {
                const new_fn = try allocator.create(Type.Fn);
                new_fn.* = .{
                    .params = std.ArrayList(Type).init(allocator),
                    .return_type = undefined,
                };
                for (fn_data.params.items) |param| {
                    try new_fn.params.append(try param.clone(allocator));
                }
                new_fn.return_type = try fn_data.return_type.clone(allocator);
                const t = try allocator.create(Type);
                t.* = .{ .Fn = new_fn.* };
                break :blk t;
            },
            .ADT => |adt_data| blk: {
                const new_adt = try allocator.create(Type.ADT);
                new_adt.* = .{
                    .name = try allocator.dupe(u8, adt_data.name),
                    .type_args = std.ArrayList(Type).init(allocator),
                };
                for (adt_data.type_args.items) |arg| {
                    try new_adt.type_args.append(try arg.clone(allocator));
                }
                const t = try allocator.create(Type);
                t.* = .{ .ADT = new_adt.* };
                break :blk t;
            },
            .Var => |id| Type.initVar(allocator, id),
        };
    }

    /// Free type and all nested allocations
    pub fn deinit(self: *Type, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Fn => |*fn_data| {
                for (fn_data.params.items) |*param| {
                    param.deinit(allocator);
                }
                fn_data.params.deinit(allocator);
                fn_data.return_type.deinit(allocator);
            },
            .ADT => |*adt_data| {
                allocator.free(adt_data.name);
                for (adt_data.type_args.items) |*arg| {
                    arg.deinit(allocator);
                }
                adt_data.type_args.deinit(allocator);
            },
            .Unit, .Bool, .Int, .Float, .Var => {},
        }
        allocator.destroy(self);
    }

    /// Type equality (structural)
    /// Returns true if types are structurally equivalent
    pub fn eq(self: *const Type, other: *const Type) bool {
        return switch (self.*) {
            .Unit => other.* == .Unit,
            .Bool => other.* == .Bool,
            .Int => other.* == .Int,
            .Float => other.* == .Float,
            .Fn => |fn_data| switch (other.*) {
                .Fn => |other_fn| blk: {
                    if (fn_data.params.items.len != other_fn.params.items.len) break :blk false;
                    for (fn_data.params.items, other_fn.params.items) |p1, p2| {
                        if (!p1.eq(&p2)) break :blk false;
                    }
                    break :blk fn_data.return_type.eq(other_fn.return_type);
                },
                else => false,
            },
            .ADT => |adt_data| switch (other.*) {
                .ADT => |other_adt| blk: {
                    if (!std.mem.eql(u8, adt_data.name, other_adt.name)) break :blk false;
                    if (adt_data.type_args.items.len != other_adt.type_args.items.len) break :blk false;
                    for (adt_data.type_args.items, other_adt.type_args.items) |a1, a2| {
                        if (!a1.eq(&a2)) break :blk false;
                    }
                    break :blk true;
                },
                else => false,
            },
            .Var => |id| switch (other.*) {
                .Var => |other_id| id == other_id,
                else => false,
            },
        };
    }

    /// Substitute type variable with another type
    /// Used during unification to replace type variables with concrete types
    pub fn subst(self: *Type, allocator: std.mem.Allocator, var_id: TypeId, replacement: *const Type) !*Type {
        return switch (self.*) {
            .Var => |id| if (id == var_id) try replacement.clone(allocator) else try self.clone(allocator),
            .Fn => |fn_data| blk: {
                const new_fn = try allocator.create(Type.Fn);
                new_fn.* = .{
                    .params = std.ArrayList(Type).init(allocator),
                    .return_type = undefined,
                };
                for (fn_data.params.items) |param| {
                    try new_fn.params.append(try param.subst(allocator, var_id, replacement));
                }
                new_fn.return_type = try fn_data.return_type.subst(allocator, var_id, replacement);
                const t = try allocator.create(Type);
                t.* = .{ .Fn = new_fn.* };
                break :blk t;
            },
            .ADT => |adt_data| blk: {
                const new_adt = try allocator.create(Type.ADT);
                new_adt.* = .{
                    .name = try allocator.dupe(u8, adt_data.name),
                    .type_args = std.ArrayList(Type).init(allocator),
                };
                for (adt_data.type_args.items) |arg| {
                    try new_adt.type_args.append(try arg.subst(allocator, var_id, replacement));
                }
                const t = try allocator.create(Type);
                t.* = .{ .ADT = new_adt.* };
                break :blk t;
            },
            else => try self.clone(allocator),
        };
    }

    /// Get free type variables in this type
    /// Returns a list of unique type variable IDs
    pub fn ftv(self: *const Type, allocator: std.mem.Allocator) !std.ArrayList(TypeId) {
        var result = std.ArrayList(TypeId).init(allocator);
        try self.ftvAppend(&result);
        // Deduplicate
        std.sort.sort(TypeId, result.items, {}, comptime std.sort.asc(TypeId));
        var i: usize = 1;
        while (i < result.items.len) {
            if (result.items[i] == result.items[i - 1]) {
                _ = result.orderedRemove(i);
            } else {
                i += 1;
            }
        }
        return result;
    }

    /// Helper: append free type variables to existing list
    fn ftvAppend(self: *const Type, list: *std.ArrayList(TypeId)) !void {
        switch (self.*) {
            .Var => |id| try list.append(id),
            .Fn => |fn_data| {
                for (fn_data.params.items) |param| {
                    try param.ftvAppend(list);
                }
                try fn_data.return_type.ftvAppend(list);
            },
            .ADT => |adt_data| {
                for (adt_data.type_args.items) |arg| {
                    try arg.ftvAppend(list);
                }
            },
            .Unit, .Bool, .Int, .Float => {},
        }
    }

    /// String representation for debugging
    pub fn format(self: *const Type, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.*) {
            .Unit => allocator.dupe(u8, "()"),
            .Bool => allocator.dupe(u8, "Bool"),
            .Int => allocator.dupe(u8, "Int"),
            .Float => allocator.dupe(u8, "Float"),
            .Var => |id| std.fmt.allocPrint(allocator, "'{d}", .{id}),
            .Fn => |fn_data| blk: {
                const params_str = try self.formatParams(fn_data, allocator);
                const ret_str = try fn_data.return_type.format(allocator);
                break :blk std.fmt.allocPrint(allocator, "{s} -> {s}", .{ params_str, ret_str });
            },
            .ADT => |adt_data| blk: {
                if (adt_data.type_args.items.len == 0) {
                    break :blk allocator.dupe(u8, adt_data.name);
                }
                const args_str = try self.formatTypeArgs(adt_data, allocator);
                break :blk std.fmt.allocPrint(allocator, "{s}<{s}>", .{ adt_data.name, args_str });
            },
        };
    }

    fn formatParams(fn_data: Type.Fn, allocator: std.mem.Allocator) ![]const u8 {
        if (fn_data.params.items.len == 0) {
            return allocator.dupe(u8, "()");
        }
        var buf = std.ArrayList(u8).init(allocator);
        for (fn_data.params.items, 0..) |param, i| {
            if (i > 0) try buf.appendSlice(" * ");
            const param_str = try param.format(allocator);
            try buf.appendSlice(param_str);
        }
        return buf.toOwnedSlice();
    }

    fn formatTypeArgs(adt_data: Type.ADT, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        for (adt_data.type_args.items, 0..) |arg, i| {
            if (i > 0) try buf.appendSlice(", ");
            const arg_str = try arg.format(allocator);
            try buf.appendSlice(arg_str);
        }
        return buf.toOwnedSlice();
    }
};

/// Type equality test (alias for eq)
pub const TypeEq = Type.eq;

// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "Type.primitive equality" {
    const allocator = std.testing.allocator;

    const unit = try Type.init(allocator, .Unit);
    defer unit.deinit(allocator);

    const bool_t = try Type.init(allocator, .Bool);
    defer bool_t.deinit(allocator);

    const int_t = try Type.init(allocator, .Int);
    defer int_t.deinit(allocator);

    const float_t = try Type.init(allocator, .Float);
    defer float_t.deinit(allocator);

    const unit2 = try Type.init(allocator, .Unit);
    defer unit2.deinit(allocator);

    try std.testing.expect(unit.eq(unit2));
    try std.testing.expect(!unit.eq(bool_t));
    try std.testing.expect(!int_t.eq(float_t));
}

test "Type.var equality" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const v1 = try Type.init(allocator, .{ .Var = freshTypeVar() });
    defer v1.deinit(allocator);

    const v2 = try Type.init(allocator, .{ .Var = freshTypeVar() });
    defer v2.deinit(allocator);

    const v1_copy = try Type.init(allocator, .{ .Var = 1 }); // Same as v1
    defer v1_copy.deinit(allocator);

    try std.testing.expect(!v1.eq(v2)); // Different vars
    try std.testing.expect(v1.eq(v1_copy)); // Same var ID
}

test "Type.format primitives" {
    const allocator = std.testing.allocator;

    const unit = try Type.init(allocator, .Unit);
    defer unit.deinit(allocator);
    const unit_str = try unit.format(allocator);
    defer allocator.free(unit_str);
    try std.testing.expectEqualStrings("()", unit_str);

    const bool_t = try Type.init(allocator, .Bool);
    defer bool_t.deinit(allocator);
    const bool_str = try bool_t.format(allocator);
    defer allocator.free(bool_str);
    try std.testing.expectEqualStrings("Bool", bool_str);

    const int_t = try Type.init(allocator, .Int);
    defer int_t.deinit(allocator);
    const int_str = try int_t.format(allocator);
    defer allocator.free(int_str);
    try std.testing.expectEqualStrings("Int", int_str);

    const float_t = try Type.init(allocator, .Float);
    defer float_t.deinit(allocator);
    const float_str = try float_t.format(allocator);
    defer allocator.free(float_str);
    try std.testing.expectEqualStrings("Float", float_str);
}

test "Type.format var" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const v1 = try Type.init(allocator, .{ .Var = freshTypeVar() });
    defer v1.deinit(allocator);
    const v1_str = try v1.format(allocator);
    defer allocator.free(v1_str);
    try std.testing.expectEqualStrings("'1", v1_str);
}

test "Type.ftv primitive" {
    const allocator = std.testing.allocator;

    const int_t = try Type.init(allocator, .Int);
    defer int_t.deinit(allocator);

    const ftv = try int_t.ftv(allocator);
    defer ftv.deinit();
    try std.testing.expectEqual(@as(usize, 0), ftv.items.len);
}

test "Type.ftv var" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const v1 = try Type.init(allocator, .{ .Var = freshTypeVar() });
    defer v1.deinit(allocator);

    const ftv = try v1.ftv(allocator);
    defer ftv.deinit();
    try std.testing.expectEqual(@as(usize, 1), ftv.items.len);
    try std.testing.expectEqual(@as(TypeId, 1), ftv.items[0]);
}

test "Type.ftv function" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const v1 = try Type.init(allocator, .{ .Var = freshTypeVar() });
    defer v1.deinit(allocator);

    const int_t = try Type.init(allocator, .Int);
    defer int_t.deinit(allocator);

    // Int -> '1
    const fn_t = try Type.init(allocator, .Fn);
    defer fn_t.deinit(allocator);
    fn_t.Fn.params.append(int_t.*) catch unreachable;
    fn_t.Fn.return_type = v1;

    const ftv = try fn_t.ftv(allocator);
    defer ftv.deinit();
    try std.testing.expectEqual(@as(usize, 1), ftv.items.len);
    try std.testing.expectEqual(@as(TypeId, 1), ftv.items[0]);
}

test "Type.subst var" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const v1 = try Type.init(allocator, .{ .Var = freshTypeVar() });
    defer v1.deinit(allocator);

    const int_t = try Type.init(allocator, .Int);
    defer int_t.deinit(allocator);

    // Replace '1 with Int
    const result = try v1.subst(allocator, 1, int_t);
    defer result.deinit(allocator);

    try std.testing.expect(result.eq(int_t));
}

test "Type.clone primitive" {
    const allocator = std.testing.allocator;

    const int_t = try Type.init(allocator, .Int);
    defer int_t.deinit(allocator);

    const cloned = try int_t.clone(allocator);
    defer cloned.deinit(allocator);

    try std.testing.expect(int_t.eq(cloned));
}

test "freshTypeVar increments" {
    defer resetTypeVar();
    const v1 = freshTypeVar();
    const v2 = freshTypeVar();
    const v3 = freshTypeVar();

    try std.testing.expectEqual(@as(TypeId, 1), v1);
    try std.testing.expectEqual(@as(TypeId, 2), v2);
    try std.testing.expectEqual(@as(TypeId, 3), v3);
}
