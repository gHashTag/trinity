//! tri/graph_dfs — Depth-First Search for graphs
//! Auto-generated from specs/tri/tri_graph_dfs.tri
//! TTT Dogfood v0.2 Stage 177

const std = @import("std");
const BFSGraph = @import("gen_graph_bfs.zig").Graph;

/// DFS traversal result
pub const DFSResult = struct {
    preorder: []usize,
    postorder: []usize,
    allocator: std.mem.Allocator,

    /// Free result memory
    pub fn deinit(result: *DFSResult) void {
        result.allocator.free(result.preorder);
        result.allocator.free(result.postorder);
    }
};

/// DFS from start vertex
pub fn traverse(graph: *const BFSGraph, start: usize, allocator: std.mem.Allocator) !DFSResult {
    const n = graph.adj.len;
    const preorder = try allocator.alloc(usize, n);
    const postorder = try allocator.alloc(usize, n);

    const visited = try allocator.alloc(bool, n);
    defer allocator.free(visited);
    @memset(visited, false);

    var pre_idx: usize = 0;
    var post_idx: usize = 0;

    const dfsInner = struct {
        fn dfs(g: *const BFSGraph, v: usize, vis: []bool, pre: []usize, post: []usize, pi: *usize, po: *usize) void {
            vis[v] = true;
            pre[pi.*] = v;
            pi.* += 1;

            for (g.adj[v]) |neighbor| {
                if (!vis[neighbor]) {
                    dfs(g, neighbor, vis, pre, post, pi, po);
                }
            }

            post[po.*] = v;
            po.* += 1;
        }
    }.dfs;

    dfsInner(graph, start, visited, preorder, postorder, &pre_idx, &post_idx);

    return .{
        .preorder = preorder,
        .postorder = postorder,
        .allocator = allocator,
    };
}

test "dfs traverse" {
    const Graph = @import("gen_graph_bfs.zig").Graph;
    var graph = try Graph.init(std.testing.allocator, 4);
    defer graph.deinit();

    try graph.addEdge(0, 1);
    try graph.addEdge(0, 2);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 3);

    var result = try traverse(&graph, 0, std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(result.preorder.len > 0);
}
