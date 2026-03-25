// ═══════════════════════════════════════════════════════════════════════════════════════
// type_env.zig - Type Environment for Tri Language
// ═══════════════════════════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Wave 2, Phase 1.2: Type Environment
//
// Implements:
// - TypeEnv — map from names to Type schemes
// - TypeEnv.extend() — add binding
// - TypeEnv.lookup() — resolve name
// - TypeEnv.instantiate() — instantiate scheme
//
// ═══════════════════════════════════════════════════════════════════════════════════════

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
            try result.appendSlice("α");
            _ = var_id; // TODO: proper var name
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

    /// Deinitialize environment
    pub fn deinit(self: *Self) void {
        self.bindings.deinit();
        // Note: parent is not owned, so we don't free it
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

        // Free type variables not in env
        const vars_to_free = try self.computeFreeVars(allocator, ftv.items, t);
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

    pub fn deinit(self: *Self) void {
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
    pub fn apply(self: *const Self, allocator: Allocator, t: Type) !Type {
        _ = allocator;
        _ = self;
        // TODO: implement full type traversal
        return t; // Placeholder
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════════════════

/// Compute free type variables — variables not in env
fn computeFreeVars(allocator: Allocator, ftv_vars: []const TypeId, t: Type) ![]TypeId {
    _ = t;

    // Start with all variables in ftv
    var result = std.ArrayList(TypeId).init(allocator);
    try result.appendSlice(ftv_vars);

    // TODO: filter out variables that appear in env
    // For now, return all ftv variables

    return result.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "type_env_init" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    try std.testing.expectEqual(@as(usize, 0), env.bindings.count());
    try std.testing.expect(env.parent == null);
}

test "type_env_extend_lookup" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

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
    defer parent.deinit();

    const int_type = Type{ .Int = {} };
    try parent.extend("x", Scheme{ .Mono = int_type });

    var child = TypeEnv.initWithParent(allocator, &parent);
    defer child.deinit();

    const found = child.lookup("x");
    try std.testing.expect(found != null);
    if (found) |s| {
        try std.testing.expect(s.Mono.eq(&int_type));
    }
}

test "type_env_not_found" {
    const allocator = std.testing.allocator;
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const found = env.lookup("y");
    try std.testing.expect(found == null);
}

test "subst_init" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit();

    try std.testing.expectEqual(@as(usize, 0), subst.map.count());
}

test "subst_extend" {
    const allocator = std.testing.allocator;
    var subst = Subst.init(allocator);
    defer subst.deinit();

    const var_id: TypeId = 1;
    const int_type = Type{ .Int = {} };

    try subst.extend(var_id, int_type);

    const found = subst.get(var_id);
    try std.testing.expect(found != null);
    if (found) |t| {
        try std.testing.expect(t.eq(&int_type));
    }
}
