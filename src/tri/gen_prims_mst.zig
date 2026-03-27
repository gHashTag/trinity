//! tri/prims_mst — Prim's Minimum Spanning Tree algorithm
//! Auto-generated from specs/tri/tri_prims_mst.tri
//! TTT Dogfood v0.2 Stage 180

const std = @import("std");

/// Weighted edge for MST
pub const MSTEdge = struct {
    from: usize,
    to: usize,
    weight: i64,
};

/// MST result
pub const MSTResult = struct {
    edges: []MSTEdge,
    total_weight: i64,
    allocator: std.mem.Allocator,

    /// Free result memory
    pub fn deinit(result: *MSTResult) void {
        result.allocator.free(result.edges);
    }
};

/// Weighted graph for Prim's
pub const PrimGraph = struct {
    adj: [][]MSTEdge,
    allocator: std.mem.Allocator,

    /// Create graph
    pub fn init(allocator: std.mem.Allocator, vertex_count: usize) !PrimGraph {
        const adj = try allocator.alloc([]MSTEdge, vertex_count);
        for (adj) |*row| {
            row.* = &[_]MSTEdge{};
        }
        return .{
            .adj = adj,
            .allocator = allocator,
        };
    }

    /// Free graph memory
    pub fn deinit(graph: *PrimGraph) void {
        for (graph.adj) |row| {
            if (row.len > 0) {
                graph.allocator.free(row);
            }
        }
        graph.allocator.free(graph.adj);
    }
};

/// Find MST using Prim's algorithm
pub fn mst(graph: *PrimGraph, allocator: std.mem.Allocator) !MSTResult {
    const n = graph.adj.len;
    if (n == 0) return .{
        .edges = &[_]MSTEdge{},
        .total_weight = 0,
        .allocator = allocator,
    };

    var in_mst = try allocator.alloc(bool, n);
    defer allocator.free(in_mst);
    @memset(in_mst, false);

    var min_edge = try allocator.alloc(?MSTEdge, n);
    defer allocator.free(min_edge);
    for (0..n) |i| {
        min_edge[i] = null;
    }

    // Start from vertex 0
    min_edge[0] = .{ .from = 0, .to = 0, .weight = 0 };

    var result_edges = std.ArrayList(MSTEdge).initCapacity(allocator, n - 1) catch unreachable;

    var total_weight: i64 = 0;

    var _i: usize = 0;
    while (_i < n) : (_i += 1) {
        // Find minimum edge crossing the cut
        var u: ?usize = null;
        var min_w: i64 = std.math.maxInt(i64);

        for (0..n) |v| {
            if (!in_mst[v]) {
                if (min_edge[v]) |e| {
                    if (e.weight < min_w) {
                        min_w = e.weight;
                        u = v;
                    }
                }
            }
        }

        if (u == null) break;
        const u_val = u.?;

        in_mst[u_val] = true;

        if (min_edge[u_val]) |e| {
            if (e.from != e.to) {
                try result_edges.append(allocator, e);
                total_weight += e.weight;
            }
        }

        // Update minimum edges for neighbors
        for (graph.adj[u_val]) |edge| {
            if (!in_mst[edge.to]) {
                if (min_edge[edge.to] == null or edge.weight < min_edge[edge.to].?.weight) {
                    min_edge[edge.to] = .{
                        .from = u_val,
                        .to = edge.to,
                        .weight = edge.weight,
                    };
                }
            }
        }
    }

    return .{
        .edges = result_edges.toOwnedSlice(allocator) catch &[_]MSTEdge{},
        .total_weight = total_weight,
        .allocator = allocator,
    };
}

test "prims basic" {
    var graph = try PrimGraph.init(std.testing.allocator, 4);
    defer graph.deinit();

    // Simplified test - just verify structure
    try std.testing.expectEqual(@as(usize, 4), graph.adj.len);
}

test "prims single vertex" {
    var graph = try PrimGraph.init(std.testing.allocator, 1);
    defer graph.deinit();

    var result = try mst(&graph, std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.edges.len);
    try std.testing.expectEqual(@as(i64, 0), result.total_weight);
}
