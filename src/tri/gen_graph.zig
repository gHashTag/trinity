//! tri/graph — Graph data structures
//! Auto-generated from specs/tri/tri_graph.tri
//! TTT Dogfood v0.2 Stage 128

const std = @import("std");

/// Directed graph with adjacency list representation
pub fn Graph(comptime T: type) type {
    return struct {
        nodes: std.StringHashMap(std.ArrayList(T)),
        directed: bool,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create empty graph
        pub fn empty(directed: bool, allocator: std.mem.Allocator) !Self {
            return .{
                .nodes = std.StringHashMap(std.ArrayList(T)).init(allocator),
                .directed = directed,
                .allocator = allocator,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self) void {
            var iter = self.nodes.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            self.nodes.deinit();
        }

        /// Add node to graph
        pub fn addNode(self: *Self, node: T, allocator: std.mem.Allocator) !void {
            const key = try std.fmt.allocPrint(allocator, "{}", .{node});
            errdefer allocator.free(key);

            try self.nodes.put(key, std.ArrayList(T).initCapacity(allocator, 0) catch unreachable);
        }

        /// Add edge between nodes
        pub fn addEdge(self: *Self, from: T, to: T, allocator: std.mem.Allocator) !void {
            const from_key = try std.fmt.allocPrint(allocator, "{}", .{from});
            const to_key = try std.fmt.allocPrint(allocator, "{}", .{to});

            if (self.nodes.getPtr(from_key)) |adj_list| {
                try adj_list.append(allocator, to);
            }

            if (!self.directed) {
                if (self.nodes.getPtr(to_key)) |adj_list| {
                    try adj_list.append(allocator, from);
                }
            }
        }

        /// Get neighbors of a node
        pub fn getNeighbors(self: *const Self, node: T) ?[]const T {
            const key = std.fmt.allocPrint(self.allocator, "{}", .{node}) catch return null;
            defer self.allocator.free(key);

            if (self.nodes.get(key)) |list| {
                return list.items;
            }
            return null;
        }
    };
}

test "graph empty" {
    var graph = try Graph(i32).empty(true, std.testing.allocator);
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 0), graph.nodes.count());
}

test "graph add node" {
    var graph = try Graph(i32).empty(true, std.testing.allocator);
    defer graph.deinit();

    try graph.addNode(1, std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), graph.nodes.count());
}

test "graph add edge" {
    var graph = try Graph(i32).empty(false, std.testing.allocator);
    defer graph.deinit();

    try graph.addNode(1, std.testing.allocator);
    try graph.addNode(2, std.testing.allocator);
    try graph.addEdge(1, 2, std.testing.allocator);

    const neighbors = graph.getNeighbors(1);
    try std.testing.expect(neighbors != null);
    if (neighbors) |n| {
        try std.testing.expectEqual(@as(usize, 1), n.len);
    }
}
