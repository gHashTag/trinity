// ═══════════════════════════════════════════════════════════════════
// TypeEnv (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/tri-lang/type_env.tri
//
// Wave 2, Phase 1.2: Type Environment
//
// Implements:
// - Scheme: Mono/Poly type schemes
// - Poly: Polymorphic type with bound vars and body
// - Binding: name -> Scheme mapping
// - TypeEnv: Lexical scopes with parent links
// - Subst: Type substitution (TypeId -> Type)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const Type = @import("types.zig").Type;
const TypeId = @import("types.zig").TypeId;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE SCHEME
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Type Scheme — possibly polymorphic type
/// In HM typing, a type is either:
/// - Monomorphic: Type (concrete type like Int, Bool, Fn)
/// - Polymorphic: ∀α.T (type with type variables)
pub const Scheme = union(enum) {
    /// Monomorphic type (no ∀-quantifiers)
    Mono: Type,
    /// Polymorphic type: ∀α₁...αₙ.T
    Poly: Poly,

    pub fn format(self: Scheme, allocator: Allocator) ![]u8 {
        return switch (self) {
            .Mono => |t| t.format(allocator),
            .Poly => |p| p.format(allocator),
        };
    }
};

/// Polymorphic type: ∀α₁...αₙ.T
pub const Poly = struct {
    /// Bound type variables (indices into fresh_type_var sequence)
    vars: []const TypeId,
    /// Body type (may contain type variables)
    body: Type,

    const Self = @This();

    pub fn format(self: Self, allocator: Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        try result.appendSlice("∀");

        for (self.vars, 0..) |var_id, i| {
            if (i > 0) try result.appendSlice(",");
            // Convert var_id to greek letter (α, β, γ, δ, ε, ...)
            // TypeId is just an index, so we map 0→α, 1→β, 2→γ, etc.
            const greek = &[8]u8{ 'α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ' };
            if (var_id < greek.len) {
                try result.appendSlice(&[1]u8{greek[var_id]});
            } else {
                // For vars beyond θ, use α₁, α₂, etc.
                try result.appendSlice("α");
                if (var_id > 0) {
                    const num = try std.fmt.allocPrint(allocator, "{d}", .{var_id + 1});
                    defer allocator.free(num);
                    try result.appendSlice(num);
                }
            }
        }

        try result.appendSlice(".");
        try result.appendSlice(self.body.format(allocator));

        return result.toOwnedSlice();
    }
};

/// Binding: name -> Scheme
pub const Binding = struct {
    name: []const u8,
    scheme: Scheme,
};

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TYPE ENVIRONMENT
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Type Environment — chain of scopes
/// Implements lexical scoping with parent links
pub const TypeEnv = struct {
    /// Bindings in this scope
    bindings: std.StringHashMap(Scheme),
    /// Parent environment (null for global scope)
    parent: ?*const TypeEnv,

    const Self = @This();

    /// Create new empty environment
    pub fn init(allocator: Allocator) Self {
        return Self{
            .bindings = std.StringHashMap(Scheme).init(allocator),
            .parent = null,
        };
    }

    /// Create new environment with parent
    pub fn initWithParent(allocator: Allocator, parent: *const TypeEnv) Self {
        return Self{
            .bindings = std.StringHashMap(Scheme).init(allocator),
            .parent = parent,
        };
    }

    /// Deinitialize environment and clean up all Types
    pub fn deinit(self: *Self, allocator: Allocator) void {
        // Clean up all Types in bindings
        var iter = self.bindings.iterator();
        while (iter.next()) |entry| {
            // Clean up heap-allocated data within Types
            cleanupScheme(allocator, &entry.value_ptr.*);
        }
        self.bindings.deinit();
        // Note: parent is not owned, so we don't free it
    }

    /// Clean up heap-allocated data within a Scheme
    fn cleanupScheme(allocator: Allocator, scheme: *Scheme) void {
        switch (scheme.*) {
            .Mono => |*t| cleanupType(allocator, t),
            .Poly => |*p| cleanupType(allocator, &p.body),
        }
    }

    /// Clean up heap-allocated data within a Type (without freeing the Type itself)
    fn cleanupType(allocator: Allocator, t: *Type) void {
        switch (t.*) {
            .Fn => |*fn_data| {
                for (fn_data.params.items) |*param| {
                    cleanupType(allocator, param);
                }
                fn_data.params.deinit(allocator);
                allocator.destroy(fn_data.return_type);
            },
            .ADT => |*adt_data| {
                allocator.free(adt_data.name);
                for (adt_data.type_args.items) |*arg| {
                    cleanupType(allocator, arg);
                }
                adt_data.type_args.deinit(allocator);
            },
            .Unit, .Bool, .Int, .Float, .Var => {},
        }
    }

    /// Add binding to this environment
    pub fn extend(self: *Self, name: []const u8, scheme: Scheme) !void {
        try self.bindings.put(name, scheme);
    }

    /// Look up name in environment chain
    pub fn lookup(self: *const Self, name: []const u8) ?Scheme {
        // Check local scope
        if (self.bindings.get(name)) |scheme| {
            return scheme;
        }
        // Check parent scope
        if (self.parent) |parent| {
            return parent.lookup(name);
        }
        return null;
    }

    /// Instantiate scheme with substitution
    /// Replaces type variables with actual types
    pub fn instantiate(self: *const Self, allocator: Allocator, scheme: Poly, subst: *const Subst) !Scheme {
        _ = self;
        // Apply substitution to body
        const new_body = try subst.apply(allocator, scheme.body);
        return Scheme{ .Poly = Poly{ .vars = scheme.vars, .body = new_body } };
    }

    /// Generalize type to polymorphic scheme
    /// Free all type variables in t that don't appear in env
    pub fn generalize(self: *const Self, allocator: Allocator, t: Type) !Scheme {
        const ftv = try t.ftv(allocator);
        defer ftv.deinit();

        // Free type variables not in env - filter out bound vars
        const vars_to_free = try computeFreeVars(allocator, self, ftv.items);
        defer allocator.free(vars_to_free);

        return Scheme{ .Poly = Poly{ .vars = vars_to_free, .body = t } };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════
// SUBSTITUTION
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Type substitution — maps type variables to types
pub const Subst = struct {
    /// Map from TypeId to Type (substitutions)
    map: std.AutoHashMap(TypeId, Type),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .map = std.AutoHashMap(TypeId, Type).init(allocator),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        // Clean up all Types in the map
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            // Clean up heap-allocated data within Type (not the Type itself)
            cleanupType(allocator, &entry.value_ptr.*);
        }
        self.map.deinit();
    }

    /// Extend substitution with new binding
    pub fn extend(self: *Self, var_id: TypeId, t: Type) !void {
        try self.map.put(var_id, t);
    }

    /// Look up substitution for type variable
    pub fn get(self: *const Self, var_id: TypeId) ?Type {
        return self.map.get(var_id);
    }

    /// Apply substitution to type
    /// Recursively replaces type variables with their substitutions
    /// Returns Type by value. For Fn/ADT types, contains heap-allocated data that needs deinit.
    /// For primitive/Var types, returned by value, no deinit needed.
    pub fn apply(self: *const Self, allocator: Allocator, t: Type) !Type {
        switch (t) {
            // Type variables: look up in substitution
            .Var => |var_id| {
                if (self.get(var_id)) |sub| {
                    // Recursively apply in case substitution contains variables
                    return self.apply(allocator, sub);
                }
                // No substitution found, return the var as-is
                return t;
            },
            // Function types: apply to params and return type
            .Fn => |fn_data| {
                var new_params = std.ArrayList(Type).empty;
                defer {
                    for (new_params.items) |*p| {
                        cleanupType(allocator, p);
                    }
                    new_params.deinit(allocator);
                }

                for (fn_data.params.items) |param| {
                    const new_param = try self.apply(allocator, param);
                    try new_params.append(allocator, new_param);
                }

                const new_return = try self.apply(allocator, fn_data.return_type.*);
                const return_ptr = try allocator.create(Type);
                return_ptr.* = new_return;

                return Type{
                    .Fn = .{
                        .params = new_params,
                        .return_type = return_ptr,
                    },
                };
            },
            // ADT types: apply to type arguments
            .ADT => |adt_data| {
                var new_args = std.ArrayList(Type).empty;
                defer {
                    for (new_args.items) |*a| {
                        cleanupType(allocator, a);
                    }
                    new_args.deinit(allocator);
                }

                for (adt_data.type_args.items) |arg| {
                    const new_arg = try self.apply(allocator, arg);
                    try new_args.append(allocator, new_arg);
                }

                const name_copy = try allocator.dupe(u8, adt_data.name);

                return Type{
                    .ADT = .{
                        .name = name_copy,
                        .type_args = new_args,
                    },
                };
            },
            // Primitive types: unchanged
            .Unit, .Bool, .Int, .Float => return t,
        }
    }

    /// Helper: cleanup Type if it has internal allocations
    /// Only calls deinit on Fn/ADT types
    fn cleanupType(allocator: Allocator, t: *Type) void {
        switch (t.*) {
            .Fn => |*fn_data| {
                for (fn_data.params.items) |*p| {
                    cleanupType(allocator, p);
                }
                fn_data.params.deinit(allocator);
                allocator.destroy(fn_data.return_type);
            },
            .ADT => |*adt_data| {
                allocator.free(adt_data.name);
                for (adt_data.type_args.items) |*a| {
                    cleanupType(allocator, a);
                }
                adt_data.type_args.deinit(allocator);
            },
            .Unit, .Bool, .Int, .Float, .Var => {},
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════════════════

/// Compute free type variables — variables not in env
/// Returns ftv_vars filtered to exclude any variables bound in the environment
fn computeFreeVars(allocator: Allocator, env: *const TypeEnv, ftv_vars: []const TypeId) ![]TypeId {
    var result = std.ArrayList(TypeId).init(allocator);

    // Collect all type variables bound in the environment
    var bound_vars = std.ArrayList(TypeId).init(allocator);
    defer bound_vars.deinit();
    try collectBoundVars(env, &bound_vars);

    // Filter ftv_vars to exclude bound variables
    for (ftv_vars) |var_id| {
        var is_bound = false;
        for (bound_vars.items) |bound| {
            if (bound == var_id) {
                is_bound = true;
                break;
            }
        }
        if (!is_bound) {
            try result.append(var_id);
        }
    }

    return result.toOwnedSlice();
}

/// Collect all type variables bound in the environment (recursively through parent chain)
fn collectBoundVars(env: *const TypeEnv, result: *std.ArrayList(TypeId)) !void {
    // Iterate through all bindings in this scope
    var iter = env.bindings.iterator();
    while (iter.next()) |entry| {
        // Collect type variables from the scheme
        try collectVarsFromScheme(result, &entry.value_ptr.*);
    }

    // Recursively collect from parent scope
    if (env.parent) |parent| {
        try collectBoundVars(parent, result);
    }
}

/// Collect type variables from a scheme (handles both Mono and Poly)
fn collectVarsFromScheme(result: *std.ArrayList(TypeId), scheme: *const Scheme) !void {
    switch (scheme.*) {
        .Mono => |t| try collectVarsFromType(result, t),
        .Poly => |p| {
            // Add bound vars from the poly type itself
            try result.appendSlice(p.vars);
            // Also collect vars from the body
            try collectVarsFromType(result, p.body);
        },
    }
}

/// Collect all type variables from a type (recursively)
fn collectVarsFromType(result: *std.ArrayList(TypeId), t: Type) !void {
    switch (t) {
        .Var => |var_id| {
            // Check if already in result to avoid duplicates
            for (result.items) |v| {
                if (v == var_id) return;
            }
            try result.append(var_id);
        },
        .Fn => |fn_data| {
            for (fn_data.params.items) |param| {
                try collectVarsFromType(result, param);
            }
            try collectVarsFromType(result, fn_data.return_type.*);
        },
        .ADT => |adt_data| {
            for (adt_data.type_args.items) |arg| {
                try collectVarsFromType(result, arg);
            }
        },
        .Unit, .Bool, .Int, .Float => {},
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "type_env_init" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), env.bindings.count());
    try std.testing.expect(env.parent == null);
}

test "type_env_extend_lookup" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit(allocator);

    const int_type = Type{ .Int = {} };
    const scheme = Scheme{ .Mono = int_type };

    try env.extend("x", scheme);

    const found = env.lookup("x");
    try std.testing.expect(found != null);
    if (found) |s| {
        try std.testing.expect(s.Mono.eq(&int_type));
    }
}

test "type_env_parent_lookup" {
    const allocator = std.testing.allocator;
    var parent = TypeEnv.init(allocator);
    defer parent.deinit(allocator);

    const int_type = Type{ .Int = {} };
    try parent.extend("x", Scheme{ .Mono = int_type });

    var child = TypeEnv.initWithParent(allocator, &parent);
    defer child.deinit(allocator);

    const found = child.lookup("x");
    try std.testing.expect(found != null);
    if (found) |s| {
        try std.testing.expect(s.Mono.eq(&int_type));
    }
}

test "type_env_not_found" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit(allocator);

    const found = env.lookup("y");
    try std.testing.expect(found == null);
}

test "subst_init" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), subst.map.count());
}

test "subst_extend" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit(allocator);

    const var_id: TypeId = 1;
    const int_type = Type{ .Int = {} };

    try subst.extend(var_id, int_type);

    const found = subst.get(var_id);
    try std.testing.expect(found != null);
    if (found) |t| {
        try std.testing.expect(t.eq(&int_type));
    }
}

test "subst_apply_var" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit(allocator);

    const var_id: TypeId = 1;
    const int_type = Type{ .Int = {} };
    try subst.extend(var_id, int_type);

    const var_type = Type{ .Var = var_id };
    const result = try subst.apply(allocator, var_type);
    // Primitive type, no cleanup needed

    try std.testing.expect(result.eq(&int_type));
}

test "subst_apply_primitive" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit(allocator);

    const int_type = Type{ .Int = {} };
    const result = try subst.apply(allocator, int_type);
    // Primitive type, no cleanup needed

    try std.testing.expect(result.eq(&int_type));
}

test "subst_apply_no_binding" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit(allocator);

    const var_id: TypeId = 999;
    const var_type = Type{ .Var = var_id };
    const result = try subst.apply(allocator, var_type);
    // Var type, no cleanup needed

    try std.testing.expect(result.eq(&var_type));
}
