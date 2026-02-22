const std = @import("std");
const Allocator = std.mem.Allocator;

const TypeDef = struct {
    name: []const u8,
    fields: []const struct { name: []const u8, type_name: []const u8 },
};

const Behavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
    implementation: []const u8 = "",
};

const ParsedSpec = struct {
    name: []const u8,
    version: []const u8,
    types: []const TypeDef,
    behaviors: []const Behavior,
};

pub fn generatePython(allocator: Allocator, spec: ParsedSpec) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    const w = result.writer(allocator);

    try w.print("# {s} v{s}\n", .{ spec.name, spec.version });
    try w.print("# φ² + 1/φ² = 3\n\n", .{});

    return result.toOwnedSlice(allocator);
}

test "simple test" {
    const allocator = std.testing.allocator;
    const spec = ParsedSpec{
        .name = "test",
        .version = "1.0.0",
        .types = &[_]TypeDef{},
        .behaviors = &[_]Behavior{},
    };
    const code = try generatePython(allocator, spec);
    defer allocator.free(code);
    try std.testing.expect(code.len > 0);
}
