const std = @import("std");
const auto_parallel = @import("src/tri-lang/auto_parallel.zig");

test "debug_dag_linear_chain" {
    const allocator = std.testing.allocator;
    var dag = auto_parallel.Dag.init(allocator);
    defer dag.deinit();

    const id1 = try dag.addNode("a", "expr1", 10, .{ .line = 0, .column = 0 });
    const id2 = try dag.addNode("b", "expr2", 10, .{ .line = 0, .column = 0 });
    const id3 = try dag.addNode("c", "expr3", 10, .{ .line = 0, .column = 0 });

    std.debug.print("\n=== Initial state ===\n", .{});
    std.debug.print("entries: {any}\n", .{dag.entries.items});
    std.debug.print("exits: {any}\n", .{dag.exits.items});

    // a -> b
    try dag.addDependencyByName("a", "b");
    std.debug.print("\n=== After a -> b ===\n", .{});
    std.debug.print("entries: {any}\n", .{dag.entries.items});
    std.debug.print("exits: {any}\n", .{dag.exits.items});

    const node_a = dag.getNodeById(id1).?;
    const node_b = dag.getNodeById(id2).?;
    std.debug.print("a dependents: {any}\n", .{node_a.dependents});
    std.debug.print("b dependents: {any}\n", .{node_b.dependents});

    // b -> c
    try dag.addDependencyByName("b", "c");
    std.debug.print("\n=== After b -> c ===\n", .{});
    std.debug.print("entries: {any}\n", .{dag.entries.items});
    std.debug.print("exits: {any}\n", .{dag.exits.items});

    const node_a2 = dag.getNodeById(id1).?;
    const node_b2 = dag.getNodeById(id2).?;
    const node_c = dag.getNodeById(id3).?;
    std.debug.print("a dependents: {any}\n", .{node_a2.dependents});
    std.debug.print("b dependents: {any}\n", .{node_b2.dependents});
    std.debug.print("c dependents: {any}\n", .{node_c.dependents});
}
