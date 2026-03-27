//! tri/graph_bfs — Breadth-First Search for graphs
//! Auto-generated from specs/tri/tri_graph_bfs.tri
//! TTT Dogfood v0.2 Stage 176

const std = @import("std");

/// Adjacency list graph
pub const Graph = struct {
    adj: [][]usize,
    allocator: std.mem.Allocator,

    /// Create graph with n vertices
    pub fn init(allocator: std.mem.Allocator, vertex_count: usize) !Graph {
        const adj = try allocator.alloc([]usize, vertex_count);
        for (adj) |*row| {
            row.* = &[_]usize{};
        }
        return .{
            .adj = adj,
            .allocator = allocator,
        };
    }

    /// Add directed edge
    pub fn addEdge(graph: *Graph, from: usize, to: usize) !void {
        const new_list = try graph.allocator.alloc(usize, graph.adj[from].len + 1);
        @memcpy(new_list[0..graph.adj[from].len], graph.adj[from]);
        new_list[graph.adj[from].len] = to;

        if (graph.adj[from].len > 0) {
            graph.allocator.free(graph.adj[from]);
        }
        graph.adj[from] = new_list;
    }

    /// Free graph memory
    pub fn deinit(graph: *Graph) void {
        for (graph.adj) |row| {
            if (row.len > 0) {
                graph.allocator.free(row);
            }
        }
        graph.allocator.free(graph.adj);
    }
};

/// BFS traversal result
pub const BFSResult = struct {
    order: []usize,
    distance: []usize,
    allocator: std.mem.Allocator,

    /// Free result memory
    pub fn deinit(result: *BFSResult) void {
        result.allocator.free(result.order);
        result.allocator.free(result.distance);
    }
};

/// BFS from start vertex
pub fn traverse(graph: *Graph, start: usize, allocator: std.mem.Allocator) !BFSResult {
    const n = graph.adj.len;
    const order = try allocator.alloc(usize, n);
    const distance = try allocator.alloc(usize, n);
    @memset(distance, std.math.maxInt(usize));

    var visited = try allocator.alloc(bool, n);
    defer allocator.free(visited);
    @memset(visited, false);

    var queue = std.ArrayList(usize).initCapacity(allocator, n) catch unreachable;
    defer queue.deinit(allocator);

    try queue.append(allocator, start);
    visited[start] = true;
    distance[start] = 0;
    var order_idx: usize = 0;

    while (queue.items.len > 0) {
        const v = queue.orderedRemove(0);
        order[order_idx] = v;
        order_idx += 1;

        for (graph.adj[v]) |neighbor| {
            if (!visited[neighbor]) {
                visited[neighbor] = true;
                distance[neighbor] = distance[v] + 1;
                try queue.append(allocator, neighbor);
            }
        }
    }

    return .{
        .order = order,
        .distance = distance,
        .allocator = allocator,
    };
}

test "bfs traverse" {
    var graph = try Graph.init(std.testing.allocator, 4);
    defer graph.deinit();

    try graph.addEdge(0, 1);
    try graph.addEdge(0, 2);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 0);
    try graph.addEdge(2, 3);
    try graph.addEdge(3, 3);

    var result = try traverse(&graph, 2, std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.distance[2]);
    try std.testing.expectEqual(@as(usize, 1), result.distance[0]);
}

test "bfs single vertex" {
    var graph = try Graph.init(std.testing.allocator, 1);
    defer graph.deinit();

    var result = try traverse(&graph, 0, std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.order.len);
}
