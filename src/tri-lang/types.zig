// Wave 2: Type System Core — Type Representation
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const TypeId = u32;

var next_type_var: TypeId = 1;

pub fn freshTypeVar() TypeId {
    const id = next_type_var;
    next_type_var += 1;
    return id;
}

pub fn resetTypeVar() void {
    next_type_var = 1;
}

pub const Type = union(enum) {
    Unit,
    Bool,
    Int,
    Float,
    Fn: struct {
        params: std.ArrayList(Type),
        return_type: *Type,
    },
    ADT: struct {
        name: []const u8,
        type_args: std.ArrayList(Type),
    },
    Var: TypeId,

    pub fn initVar(allocator: std.mem.Allocator, id: TypeId) !*Type {
        const t = try allocator.create(Type);
        t.* = .{ .Var = id };
        return t;
    }

    pub fn deinit(self: *Type, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Fn => |*fn_data| {
                for (fn_data.params.items) |*param| {
                    param.deinit(allocator);
                }
                fn_data.params.deinit(allocator);
                allocator.destroy(fn_data.return_type);
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

    pub fn eq(self: *const Type, other: *const Type) bool {
        return switch (self.*) {
            .Unit => other.* == .Unit,
            .Bool => other.* == .Bool,
            .Int => other.* == .Int,
            .Float => other.* == .Float,
            .Fn => |fn_data| switch (other.*) {
                .Fn => |other_fn| blk: {
                    if (fn_data.params.items.len != other_fn.params.items.len) break :blk false;
                    for (fn_data.params.items, other_fn.params.items) |p1, *p2| {
                        if (!p1.eq(p2)) break :blk false;
                    }
                    break :blk fn_data.return_type.eq(other_fn.return_type);
                },
                else => false,
            },
            .ADT => |adt_data| switch (other.*) {
                .ADT => |other_adt| blk: {
                    if (!std.mem.eql(u8, adt_data.name, other_adt.name)) break :blk false;
                    if (adt_data.type_args.items.len != other_adt.type_args.items.len) break :blk false;
                    for (adt_data.type_args.items, other_adt.type_args.items) |a1, *a2| {
                        if (!a1.eq(a2)) break :blk false;
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

    pub fn format(self: *const Type, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.*) {
            .Unit => allocator.dupe(u8, "()"),
            .Bool => allocator.dupe(u8, "Bool"),
            .Int => allocator.dupe(u8, "Int"),
            .Float => allocator.dupe(u8, "Float"),
            .Var => |id| std.fmt.allocPrint(allocator, "'{d}", .{id}),
            .Fn => |fn_data| blk: {
                const ret_str = try fn_data.return_type.format(allocator);
                defer allocator.free(ret_str);
                break :blk std.fmt.allocPrint(allocator, "[...] -> {s}", .{ret_str});
            },
            .ADT => |adt_data| blk: {
                if (adt_data.type_args.items.len == 0) {
                    break :blk allocator.dupe(u8, adt_data.name);
                }
                break :blk std.fmt.allocPrint(allocator, "{s}<...>", .{adt_data.name});
            },
        };
    }

    pub fn ftv(self: *const Type, allocator: std.mem.Allocator) !std.ArrayList(TypeId) {
        var result = std.ArrayList(TypeId).init(allocator);
        try self.ftvAppend(&result);
        std.sort.insertion(TypeId, result.items, {}, comptime std.sort.asc(TypeId));
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

    fn ftvAppend(self: *const Type, list: *std.ArrayList(TypeId)) !void {
        switch (self.*) {
            .Var => |id| try list.append(id),
            .Fn => |fn_data| {
                for (fn_data.params.items) |*param| {
                    try param.ftvAppend(list);
                }
                try fn_data.return_type.ftvAppend(list);
            },
            .ADT => |adt_data| {
                for (adt_data.type_args.items) |*arg| {
                    try arg.ftvAppend(list);
                }
            },
            .Unit, .Bool, .Int, .Float => {},
        }
    }
};

test "Type.primitive equality" {
    const allocator = std.testing.allocator;

    const unit = try Type.initVar(allocator, 1);
    defer unit.deinit(allocator);
    unit.* = .Unit;

    const bool_t = try Type.initVar(allocator, 2);
    defer bool_t.deinit(allocator);
    bool_t.* = .Bool;

    try std.testing.expect(!unit.eq(bool_t));
}

test "Type.var equality" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const v1 = try Type.initVar(allocator, freshTypeVar());
    defer v1.deinit(allocator);

    const v2 = try Type.initVar(allocator, freshTypeVar());
    defer v2.deinit(allocator);

    try std.testing.expect(!v1.eq(v2));
}

test "Type.format primitives" {
    const allocator = std.testing.allocator;

    const unit = try Type.initVar(allocator, 1);
    defer unit.deinit(allocator);
    unit.* = .Unit;
    const unit_str = try unit.format(allocator);
    defer allocator.free(unit_str);
    try std.testing.expectEqualStrings("()", unit_str);

    const bool_t = try Type.initVar(allocator, 2);
    defer bool_t.deinit(allocator);
    bool_t.* = .Bool;
    const bool_str = try bool_t.format(allocator);
    defer allocator.free(bool_str);
    try std.testing.expectEqualStrings("Bool", bool_str);
}

test "Type.ftv primitive" {
    const allocator = std.testing.allocator;

    const int_t = try Type.initVar(allocator, 1);
    defer int_t.deinit(allocator);
    int_t.* = .Int;

    const ftv = try int_t.ftv(allocator);
    defer ftv.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), ftv.items.len);
}

test "Type.ftv var" {
    const allocator = std.testing.allocator;
    defer resetTypeVar();

    const id = freshTypeVar();
    const v1 = try Type.initVar(allocator, id);
    defer v1.deinit(allocator);

    const ftv = try v1.ftv(allocator);
    defer ftv.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), ftv.items.len);
    try std.testing.expectEqual(@as(TypeId, 1), ftv.items[0]);
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
