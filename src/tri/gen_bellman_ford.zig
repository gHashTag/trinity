//! tri/bellman_ford — Bellman-Ford shortest path with negative weights
//! Auto-generated from specs/tri/tri_bellman_ford.tri
//! TTT Dogfood v0.2 Stage 179

const std = @import("std");

/// Weighted edge
pub const Edge = struct {
    from: usize,
    to: usize,
    weight: i64,
};

/// Find shortest paths, detect negative cycles
pub fn shortestPath(edges: []const Edge, vertex_count: usize, start: usize, allocator: std.mem.Allocator) ![]i64 {
    const INF = std.math.maxInt(i64);

    const distance = try allocator.alloc(i64, vertex_count);
    defer allocator.free(distance);

    for (0..vertex_count) |i| {
        distance[i] = INF;
    }
    distance[start] = 0;

    // Relax all edges V-1 times
    var i: usize = 0;
    while (i < vertex_count - 1) : (i += 1) {
        for (edges) |edge| {
            if (distance[edge.from] != INF and distance[edge.from] + edge.weight < distance[edge.to]) {
                distance[edge.to] = distance[edge.from] + edge.weight;
            }
        }
    }

    // Check for negative cycles
    for (edges) |edge| {
        if (distance[edge.from] != INF and distance[edge.from] + edge.weight < distance[edge.to]) {
            // Negative cycle detected
            const result = try allocator.alloc(i64, vertex_count);
            @memset(result, 0);
            result[0] = -1; // Signal negative cycle
            return result;
        }
    }

    // Copy result to output
    const result = try allocator.alloc(i64, vertex_count);
    @memcpy(result, distance);
    return result;
}

test "bellman ford basic" {
    const edges = [_]Edge{
        .{ .from = 0, .to = 1, .weight = 4 },
        .{ .from = 0, .to = 2, .weight = 1 },
        .{ .from = 2, .to = 1, .weight = 2 },
        .{ .from = 1, .to = 3, .weight = 1 },
    };

    const result = try shortestPath(&edges, 4, 0, std.testing.allocator);
    defer std.testing.allocator.free(result);

    // Distance from 0 to 3 should be 4 (0->2->1->3)
    try std.testing.expectEqual(@as(i64, 4), result[3]);
}

test "bellman ford negative cycle" {
    const edges = [_]Edge{
        .{ .from = 0, .to = 1, .weight = -1 },
        .{ .from = 1, .to = 2, .weight = -1 },
        .{ .from = 2, .to = 0, .weight = -1 },
    };

    const result = try shortestPath(&edges, 3, 0, std.testing.allocator);
    defer std.testing.allocator.free(result);

    // First element should be -1 to signal negative cycle
    try std.testing.expectEqual(@as(i64, -1), result[0]);
}

test "bellman ford empty graph" {
    const edges = [_]Edge{};
    const result = try shortestPath(&edges, 1, 0, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(i64, 0), result[0]);
}
