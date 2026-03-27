//! tri/dijkstra — Dijkstra's shortest path algorithm
//! Auto-generated from specs/tri/tri_dijkstra.tri
//! TTT Dogfood v0.2 Stage 178

const std = @import("std");

/// Weighted graph edge
pub const WeightedEdge = struct {
    to: usize,
    weight: f64,
};

/// Dijkstra result
pub const DijkstraResult = struct {
    distance: []f64,
    parent: []?usize,
    allocator: std.mem.Allocator,

    /// Free result memory
    pub fn deinit(result: *DijkstraResult) void {
        result.allocator.free(result.distance);
        result.allocator.free(result.parent);
    }
};

/// Weighted graph for Dijkstra
pub const WeightedGraph = struct {
    adj: [][]WeightedEdge,
    allocator: std.mem.Allocator,

    /// Create weighted graph
    pub fn init(allocator: std.mem.Allocator, vertex_count: usize) !WeightedGraph {
        const adj = try allocator.alloc([]WeightedEdge, vertex_count);
        for (adj) |*row| {
            row.* = &[_]WeightedEdge{};
        }
        return .{
            .adj = adj,
            .allocator = allocator,
        };
    }

    /// Free graph memory
    pub fn deinit(graph: *WeightedGraph) void {
        for (graph.adj) |row| {
            if (row.len > 0) {
                graph.allocator.free(row);
            }
        }
        graph.allocator.free(graph.adj);
    }
};

/// Find shortest paths from start
pub fn shortestPath(graph: *WeightedGraph, start: usize, allocator: std.mem.Allocator) !DijkstraResult {
    const n = graph.adj.len;
    const distance = try allocator.alloc(f64, n);
    const parent = try allocator.alloc(?usize, n);

    for (0..n) |i| {
        distance[i] = std.math.inf(f64);
        parent[i] = null;
    }
    distance[start] = 0;

    var visited = try allocator.alloc(bool, n);
    defer allocator.free(visited);
    @memset(visited, false);

    var remaining = n;
    while (remaining > 0) {
        // Find unvisited vertex with minimum distance
        var min_dist = std.math.inf(f64);
        var u: usize = 0;

        for (0..n) |i| {
            if (!visited[i] and distance[i] < min_dist) {
                min_dist = distance[i];
                u = i;
            }
        }

        if (min_dist == std.math.inf(f64)) break;
        visited[u] = true;
        remaining -= 1;

        // Relax edges
        for (graph.adj[u]) |edge| {
            const new_dist = distance[u] + edge.weight;
            if (new_dist < distance[edge.to]) {
                distance[edge.to] = new_dist;
                parent[edge.to] = u;
            }
        }
    }

    return .{
        .distance = distance,
        .parent = parent,
        .allocator = allocator,
    };
}

test "dijkstra basic" {
    var graph = try WeightedGraph.init(std.testing.allocator, 4);
    defer graph.deinit();

    // Simplified test - just verify structure
    try std.testing.expectEqual(@as(usize, 4), graph.adj.len);
}

test "dijkstra single vertex" {
    var graph = try WeightedGraph.init(std.testing.allocator, 1);
    defer graph.deinit();

    var result = try shortestPath(&graph, 0, std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqual(@as(f64, 0), result.distance[0]);
}
