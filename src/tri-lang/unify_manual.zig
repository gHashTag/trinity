// Wave 2: Type System Core — Unification
//
// Hindley-Melner unification algorithm for type inference
// Unifies two types, performs occurs check, reports type errors
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const types = @import("types.zig");
const type_env = @import("type_env.zig");

pub const Type = types.Type;
pub const TypeId = types.TypeId;
pub const freshTypeVar = types.freshTypeVar;
pub const resetTypeVar = types.resetTypeVar;

/// Unification result
pub const UnifyResult = union(enum) {
    /// Unification succeeded
    Ok: Subst,
    /// Unification failed with type mismatch
    Error: TypeError,
};

/// Type error with details
pub const TypeError = struct {
    /// Expected type
    expected: *Type,
    /// Actual type
    actual: *Type,
    /// Error message
    msg: []const u8,

    pub fn format(self: *const TypeError, allocator: std.mem.Allocator) ![]const u8 {
        const expected_str = try self.expected.format(allocator);
        defer allocator.free(expected_str);
        const actual_str = try self.actual.format(allocator);
        defer allocator.free(actual_str);
        return std.fmt.allocPrint(allocator, "{s}: expected {s}, got {s}", .{
            self.msg, expected_str, actual_str,
        });
    }
};

/// Substitution — maps type variables to types
pub const Subst = struct {
    /// Map from TypeId to Type
    map: std.AutoHashMap(TypeId, Type),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .map = std.AutoHashMap(TypeId, Type).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }

    /// Empty substitution (identity) - requires explicit deinit
    pub fn empty(allocator: std.mem.Allocator) Self {
        return Self{
            .map = std.AutoHashMap(TypeId, Type).init(allocator),
        };
    }

    /// Clone substitution
    pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
        var result = Self.init(allocator);
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            try result.map.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        return result;
    }

    /// Extend substitution with new binding
    pub fn extend(self: *Self, var_id: TypeId, t: Type) !void {
        try self.map.put(var_id, t);
    }

    /// Look up substitution for type variable
    pub fn get(self: *const Self, var_id: TypeId) ?Type {
        return self.map.get(var_id);
    }

    /// Compose two substitutions: (σ₁ ∘ σ₂)(x) = σ₁(σ₂(x))
    pub fn compose(self: *const Self, other: *const Subst, allocator: std.mem.Allocator) !Self {
        var result = Self.init(allocator);
        var iter = other.map.iterator();
        while (iter.next()) |entry| {
            const t2 = entry.value_ptr.*;
            // Apply self to t2
            const t1 = try self.apply(allocator, t2);
            try result.map.put(entry.key_ptr.*, t1);
        }
        // Add bindings from self that aren't in other
        iter = self.map.iterator();
        while (iter.next()) |entry| {
            if (!other.map.contains(entry.key_ptr.*)) {
                try result.map.put(entry.key_ptr.*, entry.value_ptr.*.*);
            }
        }
        return result;
    }

    /// Apply substitution to a type
    pub fn apply(self: *const Self, allocator: std.mem.Allocator, t: Type) !Type {
        return switch (t) {
            .Var => |id| self.*.get(id) orelse t,
            .Fn => |fn_data| {
                var new_params = std.ArrayList(Type).empty;
                errdefer new_params.deinit(allocator);
                for (fn_data.params.items) |param| {
                    try new_params.append(allocator, try self.apply(allocator, param));
                }
                const new_return = try self.apply(allocator, fn_data.return_type.*);
                const return_ptr = try allocator.create(Type);
                return_ptr.* = new_return;
                return Type{ .Fn = .{
                    .params = new_params,
                    .return_type = return_ptr,
                } };
            },
            .ADT => |adt_data| {
                var new_args = std.ArrayList(Type).empty;
                errdefer new_args.deinit(allocator);
                for (adt_data.type_args.items) |arg| {
                    try new_args.append(allocator, try self.apply(allocator, arg));
                }
                return Type{ .ADT = .{
                    .name = adt_data.name,
                    .type_args = new_args,
                } };
            },
            else => t, // Unit, Bool, Int, Float are unchanged
        };
    }
};

/// Occurs check — prevent infinite types
/// Returns true if type variable occurs in type (preventing α → α cycles)
pub fn occursIn(tv: TypeId, t: *const Type) bool {
    return switch (t.*) {
        .Var => |id| id == tv,
        .Fn => |fn_data| {
            for (fn_data.params.items) |param| {
                if (occursIn(tv, &param)) return true;
            }
            return occursIn(tv, fn_data.return_type);
        },
        .ADT => |adt_data| {
            for (adt_data.type_args.items) |arg| {
                if (occursIn(tv, &arg)) return true;
            }
            return false;
        },
        else => false, // Unit, Bool, Int, Float don't contain type vars
    };
}

/// Main unification function
/// Unifies two types, returns substitution or error
pub fn unify(allocator: std.mem.Allocator, t1: *const Type, t2: *const Type) !UnifyResult {
    return unifyWithSubst(allocator, Subst.empty(allocator), t1, t2);
}

/// Unify with existing substitution
pub fn unifyWithSubst(allocator: std.mem.Allocator, subst: Subst, t1: *const Type, t2: *const Type) !UnifyResult {
    // First, handle t1 being a type variable
    if (t1.* == .Var) {
        const v1 = t1.Var;
        // Both type variables — unify them
        if (t2.* == .Var) {
            const v2 = t2.Var;
            if (v1 == v2) {
                return UnifyResult{ .Ok = subst };
            }
            // α = β: bind α to β
            var new_subst = try subst.clone(allocator);
            try new_subst.extend(v1, .{ .Var = v2 });
            return UnifyResult{ .Ok = new_subst };
        }
        // Left is type variable, right is concrete
        if (occursIn(v1, t2)) {
            const expected_ptr = try allocator.create(Type);
            expected_ptr.* = .{ .Var = v1 };
            const actual_ptr = try allocator.create(Type);
            actual_ptr.* = t2.*;
            return UnifyResult{ .Error = TypeError{
                .expected = expected_ptr,
                .actual = actual_ptr,
                .msg = "Cannot construct infinite type",
            } };
        }
        // Bind variable to type
        var new_subst = try subst.clone(allocator);
        try new_subst.extend(v1, t2.*);
        return UnifyResult{ .Ok = new_subst };
    }

    // Right is type variable, left is concrete
    if (t2.* == .Var) {
        const v2 = t2.Var;
        if (occursIn(v2, t1)) {
            const expected_ptr = try allocator.create(Type);
            expected_ptr.* = t1.*;
            const actual_ptr = try allocator.create(Type);
            actual_ptr.* = .{ .Var = v2 };
            return UnifyResult{ .Error = TypeError{
                .expected = expected_ptr,
                .actual = actual_ptr,
                .msg = "Cannot construct infinite type",
            } };
        }
        var new_subst = try subst.clone(allocator);
        try new_subst.extend(v2, t1.*);
        return UnifyResult{ .Ok = new_subst };
    }

    // Both are concrete types — check by tag
    if (std.meta.activeTag(t1.*) != std.meta.activeTag(t2.*)) {
        const expected_ptr = try allocator.create(Type);
        expected_ptr.* = t1.*;
        const actual_ptr = try allocator.create(Type);
        actual_ptr.* = t2.*;
        return UnifyResult{ .Error = TypeError{
            .expected = expected_ptr,
            .actual = actual_ptr,
            .msg = "Type mismatch",
        } };
    }

    // Same tag — handle each case
    return switch (t1.*) {
        // Both are the same primitive type
        .Unit => UnifyResult{ .Ok = subst },
        .Bool => UnifyResult{ .Ok = subst },
        .Int => UnifyResult{ .Ok = subst },
        .Float => UnifyResult{ .Ok = subst },

        // Function types
        .Fn => |f1| {
            const f2 = t2.Fn;
            if (f1.params.items.len != f2.params.items.len) {
                const expected_ptr = try allocator.create(Type);
                expected_ptr.* = t1.*;
                const actual_ptr = try allocator.create(Type);
                actual_ptr.* = t2.*;
                return UnifyResult{ .Error = TypeError{
                    .expected = expected_ptr,
                    .actual = actual_ptr,
                    .msg = "Arity mismatch",
                } };
            }

            // Unify parameters left-to-right
            var current_subst = subst;
            for (f1.params.items, f2.params.items) |p1, p2| {
                const result = try unifyWithSubst(allocator, current_subst, &p1, &p2);
                if (result != .Ok) return result;
                current_subst = result.Ok;
            }

            // Unify return types
            return unifyWithSubst(allocator, current_subst, f1.return_type, f2.return_type);
        },

        // ADT types
        .ADT => |a1| {
            const a2 = t2.ADT;
            if (!std.mem.eql(u8, a1.name, a2.name)) {
                const expected_ptr = try allocator.create(Type);
                expected_ptr.* = t1.*;
                const actual_ptr = try allocator.create(Type);
                actual_ptr.* = t2.*;
                return UnifyResult{ .Error = TypeError{
                    .expected = expected_ptr,
                    .actual = actual_ptr,
                    .msg = "Different ADT constructors",
                } };
            }
            if (a1.type_args.items.len != a2.type_args.items.len) {
                const expected_ptr = try allocator.create(Type);
                expected_ptr.* = t1.*;
                const actual_ptr = try allocator.create(Type);
                actual_ptr.* = t2.*;
                return UnifyResult{ .Error = TypeError{
                    .expected = expected_ptr,
                    .actual = actual_ptr,
                    .msg = "Type argument count mismatch",
                } };
            }

            // Unify type arguments
            var current_subst = subst;
            for (a1.type_args.items, a2.type_args.items) |arg1, arg2| {
                const result = try unifyWithSubst(allocator, current_subst, &arg1, &arg2);
                if (result != .Ok) return result;
                current_subst = result.Ok;
            }

            return UnifyResult{ .Ok = current_subst };
        },

        // Should never reach here (Var handled earlier)
        .Var => unreachable,
    };
}

// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "unify same primitives" {
    const allocator = std.testing.allocator;

    const int_t = try types.Type.initVar(allocator, 1);
    defer int_t.deinit(allocator);
    int_t.* = .Int;

    const result = try unify(allocator, int_t, int_t);
    try std.testing.expect(result == .Ok);
    // Note: testing allocator handles cleanup
}

test "unify different primitives fails" {
    const allocator = std.testing.allocator;

    const int_t = try types.Type.initVar(allocator, 1);
    defer int_t.deinit(allocator);
    int_t.* = .Int;

    const bool_t = try types.Type.initVar(allocator, 2);
    defer bool_t.deinit(allocator);
    bool_t.* = .Bool;

    const result = try unify(allocator, int_t, bool_t);
    try std.testing.expect(result == .Error);
    // Clean up error pointers
    if (result == .Error) {
        allocator.destroy(result.Error.expected);
        allocator.destroy(result.Error.actual);
    }
}

test "unify var with concrete" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const var_t = try types.Type.initVar(allocator, freshTypeVar());
    defer var_t.deinit(allocator);

    const int_t = try types.Type.initVar(allocator, 2);
    defer int_t.deinit(allocator);
    int_t.* = .Int;

    const result = try unify(allocator, var_t, int_t);
    try std.testing.expect(result == .Ok);
    var s = result.Ok;
    s.deinit();
}

test "occurs check prevents infinite types" {
    defer resetTypeVar();

    const tv1 = freshTypeVar();
    // Same var should unify successfully (no infinite type)
    const result = try unify(std.testing.allocator, &Type{ .Var = tv1 }, &Type{ .Var = tv1 });
    try std.testing.expect(result == .Ok);
    var s = result.Ok;
    s.deinit();
}

test "subst empty" {
    var subst = Subst.init(std.testing.allocator);
    defer subst.deinit();

    try std.testing.expectEqual(@as(usize, 0), subst.map.count());
}

test "subst extend and lookup" {
    const allocator = std.testing.allocator;

    var subst = Subst.init(allocator);
    defer subst.deinit();

    const int_t = Type{ .Int = {} };
    try subst.extend(1, int_t);

    const found = subst.get(1);
    try std.testing.expect(found != null);
    if (found) |t| {
        try std.testing.expect(t == .Int);
    }
}
test "unify function types" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    // Create function type: Int -> Int
    const return_ptr = try allocator.create(Type);
    return_ptr.* = .Int;

    // Use empty and ensureTotalCapacity for unmanaged ArrayList
    var params = std.ArrayList(Type).empty;
    try params.ensureTotalCapacity(allocator, 1);
    params.appendAssumeCapacity(.Int);

    const fn1 = try allocator.create(Type);
    fn1.* = .{ .Fn = .{
        .params = params,
        .return_type = return_ptr,
    } };
    defer {
        // Manual cleanup to avoid double-free issues
        params.deinit(allocator);
        allocator.destroy(fn1.Fn.return_type);
        allocator.destroy(fn1);
    }

    const result = try unify(allocator, fn1, fn1);
    try std.testing.expect(result == .Ok);
}
