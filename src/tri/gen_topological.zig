//! tri/topological — Topological sort for DAGs
//! Auto-generated from specs/tri/tri_topological.tri
//! TTT Dogfood v0.2 Stage 145

const std = @import("std");

/// Simple directed graph for topological sort
pub const DirectedGraph = struct {
    vertices: usize,
    adj_list: std.ArrayList(std.ArrayList(usize)),
    in_degree: std.ArrayList(usize),
    allocator: std.mem.Allocator,

    /// Create graph
    pub fn init(vertex_count: usize, allocator: std.mem.Allocator) !DirectedGraph {
        var adj_list = std.ArrayList(std.ArrayList(usize)).initCapacity(allocator, vertex_count) catch unreachable;
        var in_degree = std.ArrayList(usize).initCapacity(allocator, vertex_count) catch unreachable;

        for (0..vertex_count) |_| {
            try adj_list.append(allocator, std.ArrayList(usize).initCapacity(allocator, 0) catch unreachable);
            try in_degree.append(allocator, 0);
        }

        return .{
            .vertices = vertex_count,
            .adj_list = adj_list,
            .in_degree = in_degree,
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *DirectedGraph) void {
        for (self.adj_list.items) |*list| {
            list.deinit(self.allocator);
        }
        self.adj_list.deinit(self.allocator);
        self.in_degree.deinit(self.allocator);
    }

    /// Add directed edge
    pub fn addEdge(self: *DirectedGraph, from: usize, to: usize) !void {
        if (from >= self.vertices or to >= self.vertices) return error.OutOfBounds;

        try self.adj_list.items[from].append(self.allocator, to);
        self.in_degree.items[to] += 1;
    }

    /// Get neighbors
    pub fn neighbors(self: *const DirectedGraph, vertex: usize) []const usize {
        if (vertex >= self.vertices) return &[_]usize{};
        return self.adj_list.items[vertex].items;
    }
};

/// Topological sort result
pub const TopologicalSort = struct {
    order: []usize,
    has_cycle: bool,
    allocator: std.mem.Allocator,

    /// Free resources
    pub fn deinit(self: *TopologicalSort) void {
        self.allocator.free(self.order);
    }
};

/// Kahn's algorithm for topological sorting
pub fn sort(graph: *const DirectedGraph, allocator: std.mem.Allocator) !TopologicalSort {
    var order = std.ArrayList(usize).initCapacity(allocator, graph.vertices) catch unreachable;
    var in_degree = std.ArrayList(usize).initCapacity(allocator, graph.vertices) catch unreachable;

    // Copy in-degrees
    for (graph.in_degree.items) |deg| {
        try in_degree.append(allocator, deg);
    }

    // Find all vertices with in-degree 0
    var queue = std.ArrayList(usize).initCapacity(allocator, 10) catch unreachable;
    defer queue.deinit(allocator);

    for (0..graph.vertices) |v| {
        if (in_degree.items[v] == 0) {
            try queue.append(allocator, v);
        }
    }

    var visited_count: usize = 0;

    while (queue.items.len > 0) {
        const v = queue.orderedRemove(0);
        try order.append(allocator, v);
        visited_count += 1;

        // Reduce in-degree for all neighbors
        for (graph.neighbors(v)) |neighbor| {
            in_degree.items[neighbor] -= 1;
            if (in_degree.items[neighbor] == 0) {
                try queue.append(allocator, neighbor);
            }
        }
    }

    const has_cycle = visited_count != graph.vertices;

    return .{
        .order = order.toOwnedSlice(allocator) catch unreachable,
        .has_cycle = has_cycle,
        .allocator = allocator,
    };
}

/// Verify ordering respects edges
pub fn isValid(result: TopologicalSort, graph: *const DirectedGraph) bool {
    if (result.has_cycle) return false;

    var position = std.AutoHashMap(usize, usize).init(std.testing.allocator);
    defer position.deinit();

    for (result.order, 0..) |v, i| {
        position.put(v, i) catch unreachable;
    }

    for (0..graph.vertices) |from| {
        for (graph.neighbors(from)) |to| {
            const pos_from = position.get(from) orelse return false;
            const pos_to = position.get(to) orelse return false;
            if (pos_from >= pos_to) return false;
        }
    }

    return true;
}

test "topological sort simple dag" {
    var graph = try DirectedGraph.init(4, std.testing.allocator);
    defer graph.deinit();

    try graph.addEdge(0, 1);
    try graph.addEdge(0, 2);
    try graph.addEdge(1, 3);
    try graph.addEdge(2, 3);

    var result = try sort(&graph, std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(!result.has_cycle);
    try std.testing.expectEqual(@as(usize, 4), result.order.len);
}

test "topological sort cycle detection" {
    var graph = try DirectedGraph.init(3, std.testing.allocator);
    defer graph.deinit();

    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 0); // Cycle

    var result = try sort(&graph, std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(result.has_cycle);
}
