// ═══════════════════════════════════════════════════════════════════════════════
// phi_structures v24.φ - Generated from specs/phi_structures.vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ-[CYR:[TRANSLATED]]and[EN]and[EN]and[EN]in[CYR:[EN]nye] with[CYR:[TRANSLATED]]to[CYR:[TRANSLATED]y] [CYR:data]
// Golden identity: φ² + 1/φ² = 3
//
// DO NOT EDIT - This file is auto-generated from .vibee specification
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const phi_core = @import("phi_core.zig");

const PHI = phi_core.PHI;
const PHI_INV = phi_core.PHI_INV;
const PHI_SQ = phi_core.PHI_SQ;
const TRINITY = phi_core.TRINITY;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[EN]A[TRANSLATED]] [CYR:[TRANSLATED]] WASM
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_NODES = 4096;
const MAX_EDGES = 16384;

var nodes_buffer: [MAX_NODES]PhiNode align(16) = undefined;
var edges_buffer: [MAX_EDGES]PhiEdge align(16) = undefined;
var node_count: u32 = 0;
var edge_count: u32 = 0;

fn get_nodes_ptr() [*]PhiNode {
    return &nodes_buffer;
}

fn get_edges_ptr() [*]PhiEdge {
    return &edges_buffer;
}

fn get_node_count() u32 {
    return node_count;
}

fn get_edge_count() u32 {
    return edge_count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[TRANSLATED]]
// ═══════════════════════════════════════════════════════════════════════════════

/// [CYR:[TRANSLATED]] with φ-in[EN]with[EN]
pub const PhiNode = extern struct {
    id: u64,
    value: f64,
    phi_weight: f64,
    phi_level: u32,
    parent: u32,      // and[CYR:[TRANSLATED]]towith [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]I] (MAX for to[CYR:[TRANSLATED]I])
    left_child: u32,  // and[CYR:[TRANSLATED]]towith [EN]in[CYR:[EN]go] [CYR:[TRANSLATED]]to[EN]
    right_child: u32, // and[CYR:[TRANSLATED]]towith [CYR:law]in[CYR:[EN]go] [CYR:[TRANSLATED]]to[EN]
    _padding: u32,
    
    pub const NONE: u32 = 0xFFFFFFFF;
    
    pub fn init(id: u64, value: f64, level: u32) PhiNode {
        return PhiNode{
            .id = id,
            .value = value,
            .phi_weight = phi_core.phi_power(-@as(i32, @intCast(level))),
            .phi_level = level,
            .parent = NONE,
            .left_child = NONE,
            .right_child = NONE,
            ._padding = 0,
        };
    }
};

/// [CYR:[TRANSLATED]] with φ-in[EN]with[EN]
pub const PhiEdge = extern struct {
    source: u64,
    target: u64,
    weight: f64,
    phi_factor: f64,
    
    pub fn init(source: u64, target: u64, fib_index: u32) PhiEdge {
        // [EN]with = F(k) / F(k+1) → 1/φ
        const fk = phi_core.fibonacci(fib_index);
        const fk1 = phi_core.fibonacci(fib_index + 1);
        const weight = if (fk1 > 0) @as(f64, @floatFromInt(fk)) / @as(f64, @floatFromInt(fk1)) else PHI_INV;
        
        return PhiEdge{
            .source = source,
            .target = target,
            .weight = weight,
            .phi_factor = PHI_INV,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// φ-TREE: [CYR:[TRANSLATED]]in[EN] with φ-[CYR:[TRANSLATED]]withand[EN]into[EN]
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialization φ-[CYR:[TRANSLATED]]in[EN]
fn phi_tree_init() void {
    node_count = 0;
    edge_count = 0;
}

/// [EN]with[EN]into[EN] in φ-[CYR:[TRANSLATED]]in[EN]
/// Returns and[CYR:[TRANSLATED]]towith [EN]in[CYR:[EN]go] [CYR:[TRANSLATED]]
fn phi_tree_insert(value: f64) u32 {
    if (node_count >= MAX_NODES) return PhiNode.NONE;
    
    const new_idx = node_count;
    
    if (node_count == 0) {
        // [CYR:[TRANSLATED]]
        nodes_buffer[new_idx] = PhiNode.init(new_idx, value, 0);
        node_count += 1;
        return new_idx;
    }
    
    // [EN]andwithto [CYR:[TRANSLATED]]and[EN]andand for inwith[EN]intoand (BST)
    var current: u32 = 0;
    var level: u32 = 0;
    
    while (true) {
        level += 1;
        const node = &nodes_buffer[current];
        
        if (value < node.value) {
            if (node.left_child == PhiNode.NONE) {
                // [EN]with[EN]in[CYR:[EN]I[EN]] with[EN]in[EN]
                nodes_buffer[new_idx] = PhiNode.init(new_idx, value, level);
                nodes_buffer[new_idx].parent = current;
                node.left_child = new_idx;
                node_count += 1;
                
                // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] φ-[CYR:[TRANSLATED]]with
                phi_tree_rebalance(current);
                return new_idx;
            }
            current = node.left_child;
        } else {
            if (node.right_child == PhiNode.NONE) {
                // [EN]with[EN]in[CYR:[EN]I[EN]] with[CYR:law]in[EN]
                nodes_buffer[new_idx] = PhiNode.init(new_idx, value, level);
                nodes_buffer[new_idx].parent = current;
                node.right_child = new_idx;
                node_count += 1;
                
                // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] φ-[CYR:[TRANSLATED]]with
                phi_tree_rebalance(current);
                return new_idx;
            }
            current = node.right_child;
        }
    }
}

/// [CYR:[TRANSLATED]]with[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in[EN] (and[CYR:[TRANSLATED]]andin[CYR:ny] with [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]]and[EN]y)
fn subtree_size(idx: u32) u32 {
    if (idx == PhiNode.NONE or idx >= node_count) return 0;
    
    // [CYR:[TRANSLATED]]andin[CYR:ny] [CYR:[TRANSLATED]]with[CYR:[TRANSLATED]] with andwith[CYR:[EN]l[EN]]in[EN]and[EN] with[EN]to[EN]
    var stack: [64]u32 = undefined;
    var stack_top: u32 = 0;
    var count: u32 = 0;
    
    stack[stack_top] = idx;
    stack_top += 1;
    
    while (stack_top > 0) {
        stack_top -= 1;
        const current = stack[stack_top];
        
        if (current == PhiNode.NONE or current >= node_count) continue;
        
        count += 1;
        const node = &nodes_buffer[current];
        
        if (stack_top < 62) { // [CYR:[TRANSLATED]]and[EN] from [CYR:[TRANSLATED]]not[EN]andI
            if (node.left_child != PhiNode.NONE and node.left_child < node_count) {
                stack[stack_top] = node.left_child;
                stack_top += 1;
            }
            if (node.right_child != PhiNode.NONE and node.right_child < node_count) {
                stack[stack_top] = node.right_child;
                stack_top += 1;
            }
        }
    }
    
    return count;
}

/// Check and in[EN]withwith[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]and[EN] φ-[CYR:[TRANSLATED]]with[EN] (and[CYR:[TRANSLATED]]andin[CYR:ny])
fn phi_tree_rebalance(start_idx: u32) void {
    var idx = start_idx;
    var iterations: u32 = 0;
    const max_iterations: u32 = 64; // [CYR:[TRANSLATED]]and[EN] from [EN]withto[EN]not[CYR:[TRANSLATED]go] [EN]andto[EN]
    
    while (idx != PhiNode.NONE and idx < node_count and iterations < max_iterations) : (iterations += 1) {
        const node = &nodes_buffer[idx];
        const left_size = subtree_size(node.left_child);
        const right_size = subtree_size(node.right_child);
        
        // φ-[CYR:[TRANSLATED]]with: |left - right × φ| < 1
        const left_f: f64 = @floatFromInt(left_size);
        const right_f: f64 = @floatFromInt(right_size);
        const imbalance = @abs(left_f - right_f * PHI);
        
        if (imbalance > 1.0) {
            if (left_f > right_f * PHI) {
                phi_rotate_right(idx);
            } else {
                phi_rotate_left(idx);
            }
        }
        
        // [CYR:[TRANSLATED]]and[EN] to [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]
        idx = node.parent;
    }
}

/// [CYR:[TRANSLATED]]in[EN]I [EN]from[EN]andI
fn phi_rotate_right(idx: u32) void {
    const node = &nodes_buffer[idx];
    const left_idx = node.left_child;
    if (left_idx == PhiNode.NONE) return;
    
    const left = &nodes_buffer[left_idx];
    
    // [CYR:[TRANSLATED]] [CYR:law]in[EN] [CYR:[TRANSLATED]]in[EN] left in [EN]in[EN] [CYR:[TRANSLATED]]in[EN] node
    node.left_child = left.right_child;
    if (left.right_child != PhiNode.NONE) {
        nodes_buffer[left.right_child].parent = idx;
    }
    
    // left with[CYR:[TRANSLATED]]inand[EN]withI [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] node
    left.parent = node.parent;
    if (node.parent != PhiNode.NONE) {
        const parent = &nodes_buffer[node.parent];
        if (parent.left_child == idx) {
            parent.left_child = left_idx;
        } else {
            parent.right_child = left_idx;
        }
    }
    
    left.right_child = idx;
    node.parent = left_idx;
    
    // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] φ-in[EN]with[EN]
    update_phi_weights(idx);
    update_phi_weights(left_idx);
}

/// [EN]in[EN]I [EN]from[EN]andI
fn phi_rotate_left(idx: u32) void {
    const node = &nodes_buffer[idx];
    const right_idx = node.right_child;
    if (right_idx == PhiNode.NONE) return;
    
    const right = &nodes_buffer[right_idx];
    
    node.right_child = right.left_child;
    if (right.left_child != PhiNode.NONE) {
        nodes_buffer[right.left_child].parent = idx;
    }
    
    right.parent = node.parent;
    if (node.parent != PhiNode.NONE) {
        const parent = &nodes_buffer[node.parent];
        if (parent.left_child == idx) {
            parent.left_child = right_idx;
        } else {
            parent.right_child = right_idx;
        }
    }
    
    right.left_child = idx;
    node.parent = right_idx;
    
    update_phi_weights(idx);
    update_phi_weights(right_idx);
}

/// [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]and[EN] φ-in[EN]with[EN]in [EN]with[EN] [EN]from[EN]andand
fn update_phi_weights(idx: u32) void {
    if (idx == PhiNode.NONE) return;
    
    var level: u32 = 0;
    var current = idx;
    
    // [EN]and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] from to[CYR:[TRANSLATED]I]
    while (nodes_buffer[current].parent != PhiNode.NONE) {
        current = nodes_buffer[current].parent;
        level += 1;
    }
    
    // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]]
    nodes_buffer[idx].phi_level = level;
    nodes_buffer[idx].phi_weight = phi_core.phi_power(-@as(i32, @intCast(level)));
}

/// [EN]andwithto in φ-[CYR:[TRANSLATED]]in[EN]
fn phi_tree_search(value: f64) u32 {
    var current: u32 = 0;
    
    while (current < node_count) {
        const node = &nodes_buffer[current];
        
        if (@abs(node.value - value) < 1e-10) {
            return current;
        }
        
        if (value < node.value) {
            if (node.left_child == PhiNode.NONE) return PhiNode.NONE;
            current = node.left_child;
        } else {
            if (node.right_child == PhiNode.NONE) return PhiNode.NONE;
            current = node.right_child;
        }
    }
    
    return PhiNode.NONE;
}

/// [CYR:[TRANSLATED]]andon φ-[CYR:[TRANSLATED]]in[EN]
fn phi_tree_depth() u32 {
    return compute_depth(0);
}

fn compute_depth(idx: u32) u32 {
    if (idx == PhiNode.NONE or idx >= node_count) return 0;
    
    const node = &nodes_buffer[idx];
    const left_depth = compute_depth(node.left_child);
    const right_depth = compute_depth(node.right_child);
    
    return 1 + @max(left_depth, right_depth);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIBONACCI HEAP
// ═══════════════════════════════════════════════════════════════════════════════

const FibNode = extern struct {
    key: f64,
    degree: u32,
    marked: bool,
    _pad1: u8,
    _pad2: u8,
    _pad3: u8,
    parent: u32,
    child: u32,
    left: u32,
    right: u32,
    
    pub const NONE: u32 = 0xFFFFFFFF;
};

var fib_nodes: [MAX_NODES]FibNode align(16) = undefined;
var fib_min: u32 = FibNode.NONE;
var fib_count: u32 = 0;
var fib_size: u32 = 0;

fn fib_heap_init() void {
    fib_min = FibNode.NONE;
    fib_count = 0;
    fib_size = 0;
}

/// [EN]with[EN]into[EN] in Fibonacci heap - O(1)
fn fib_heap_insert(key: f64) u32 {
    if (fib_count >= MAX_NODES) return FibNode.NONE;
    
    const idx = fib_count;
    fib_nodes[idx] = FibNode{
        .key = key,
        .degree = 0,
        .marked = false,
        ._pad1 = 0,
        ._pad2 = 0,
        ._pad3 = 0,
        .parent = FibNode.NONE,
        .child = FibNode.NONE,
        .left = idx,
        .right = idx,
    };
    
    if (fib_min == FibNode.NONE) {
        fib_min = idx;
    } else {
        // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] in to[EN]notin[EN] with[EN]andwith[EN]to
        fib_list_insert(fib_min, idx);
        if (fib_nodes[idx].key < fib_nodes[fib_min].key) {
            fib_min = idx;
        }
    }
    
    fib_count += 1;
    fib_size += 1;
    return idx;
}

/// [EN]with[EN]into[EN] in [EN]in[EN]within[CYR:I[EN]ny] with[EN]andwith[EN]to
fn fib_list_insert(list_node: u32, new_node: u32) void {
    const list = &fib_nodes[list_node];
    const new = &fib_nodes[new_node];
    
    new.right = list_node;
    new.left = list.left;
    fib_nodes[list.left].right = new_node;
    list.left = new_node;
}

/// [CYR:[TRANSLATED]]and[EN] [EN]and[EN]and[CYR:[TRANSLATED]] - O(1)
fn fib_heap_min() f64 {
    if (fib_min == FibNode.NONE) return math.inf(f64);
    return fib_nodes[fib_min].key;
}

/// [EN]in[CYR:[EN]chen]and[EN] [EN]and[EN]and[CYR:[TRANSLATED]] - O(log n) [CYR:[TRANSLATED]]and[EN]and[EN]in[CYR:[TRANSLATED]]
fn fib_heap_extract_min() f64 {
    if (fib_min == FibNode.NONE) return math.inf(f64);
    
    const min_idx = fib_min;
    const min_key = fib_nodes[min_idx].key;
    const min_node = &fib_nodes[min_idx];
    
    // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] [CYR:[TRANSLATED]] in to[EN]notin[EN] with[EN]andwith[EN]to
    if (min_node.child != FibNode.NONE) {
        var child = min_node.child;
        const first_child = child;
        
        while (true) {
            const next = fib_nodes[child].right;
            fib_nodes[child].parent = FibNode.NONE;
            fib_list_insert(fib_min, child);
            child = next;
            if (child == first_child) break;
        }
    }
    
    // [CYR:[TRANSLATED]I[EN]] min and[EN] to[EN]notin[CYR:[EN]go] with[EN]andwithto[EN]
    if (min_node.right == min_idx) {
        // [EN]and[EN]with[EN]in[CYR:[EN]ny] [CYR:[TRANSLATED]]
        fib_min = FibNode.NONE;
    } else {
        fib_nodes[min_node.left].right = min_node.right;
        fib_nodes[min_node.right].left = min_node.left;
        fib_min = min_node.right;
        fib_consolidate();
    }
    
    fib_size -= 1;
    return min_key;
}

/// [CYR:[TRANSLATED]]with[EN]and[CYR:[TRANSLATED]]andI to[EN]notin[CYR:[EN]go] with[EN]andwithto[EN]
fn fib_consolidate() void {
    if (fib_min == FibNode.NONE) return;
    
    // D(n) ≤ log_φ(n)
    const max_degree: u32 = 45; // log_φ(2^32)
    var degree_table: [max_degree]u32 = [_]u32{FibNode.NONE} ** max_degree;
    
    // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] inwith[EN] to[CYR:[TRANSLATED]]and
    var roots: [MAX_NODES]u32 = undefined;
    var root_count: u32 = 0;
    
    var current = fib_min;
    const start = current;
    while (true) {
        roots[root_count] = current;
        root_count += 1;
        current = fib_nodes[current].right;
        if (current == start) break;
    }
    
    // [CYR:[TRANSLATED]]and[CYR:[EN]I[EN]] [CYR:[TRANSLATED]]in[EN]I [EN]andonto[EN]in[EN] with[CYR:[TRANSLATED]]and
    var i: u32 = 0;
    while (i < root_count) : (i += 1) {
        var x = roots[i];
        var d = fib_nodes[x].degree;
        
        while (d < max_degree and degree_table[d] != FibNode.NONE) {
            var y = degree_table[d];
            
            // x [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]] [CYR:me[EN]]and[EN] to[CYR:[TRANSLATED]]
            if (fib_nodes[x].key > fib_nodes[y].key) {
                const tmp = x;
                x = y;
                y = tmp;
            }
            
            fib_link(y, x);
            degree_table[d] = FibNode.NONE;
            d += 1;
        }
        
        if (d < max_degree) {
            degree_table[d] = x;
        }
    }
    
    // [CYR:[TRANSLATED]]with[CYR:[TRANSLATED]]andin[CYR:[TRANSLATED]] to[EN]notin[EN] with[EN]andwith[EN]to and on[CYR:[TRANSLATED]]and[EN] [EN]iny[EN] [EN]and[EN]and[CYR:[TRANSLATED]]
    fib_min = FibNode.NONE;
    
    for (degree_table) |idx| {
        if (idx != FibNode.NONE) {
            fib_nodes[idx].left = idx;
            fib_nodes[idx].right = idx;
            
            if (fib_min == FibNode.NONE) {
                fib_min = idx;
            } else {
                fib_list_insert(fib_min, idx);
                if (fib_nodes[idx].key < fib_nodes[fib_min].key) {
                    fib_min = idx;
                }
            }
        }
    }
}

/// [EN]in[CYR:I[EN]y]in[EN]and[EN] [EN]in[EN] [CYR:[TRANSLATED]]in[EN]in
fn fib_link(child: u32, parent: u32) void {
    // [CYR:[TRANSLATED]I[EN]] child and[EN] to[EN]notin[CYR:[EN]go] with[EN]andwithto[EN]
    fib_nodes[fib_nodes[child].left].right = fib_nodes[child].right;
    fib_nodes[fib_nodes[child].right].left = fib_nodes[child].left;
    
    // [CYR:Doing[TRANSLATED]] child [CYR:[TRANSLATED]]to[EN] parent
    fib_nodes[child].parent = parent;
    fib_nodes[child].marked = false;
    
    if (fib_nodes[parent].child == FibNode.NONE) {
        fib_nodes[parent].child = child;
        fib_nodes[child].left = child;
        fib_nodes[child].right = child;
    } else {
        fib_list_insert(fib_nodes[parent].child, child);
    }
    
    fib_nodes[parent].degree += 1;
}

/// [CYR:[TRANSLATED]] to[EN]and
fn fib_heap_size() u32 {
    return fib_size;
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-GRAPH
// ═══════════════════════════════════════════════════════════════════════════════

var graph_node_count: u32 = 0;
var graph_edge_count: u32 = 0;

fn phi_graph_init() void {
    graph_node_count = 0;
    graph_edge_count = 0;
}

/// [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]] in [CYR:[TRANSLATED]]
fn phi_graph_add_node(value: f64) u32 {
    if (graph_node_count >= MAX_NODES) return PhiNode.NONE;
    
    const idx = graph_node_count;
    nodes_buffer[idx] = PhiNode.init(idx, value, 0);
    graph_node_count += 1;
    
    return idx;
}

/// [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]] with Fibonacci-in[EN]with[EN]
fn phi_graph_add_edge(source: u64, target: u64) u32 {
    if (graph_edge_count >= MAX_EDGES) return PhiNode.NONE;
    
    const idx = graph_edge_count;
    // [EN]with[CYR:[EN]l[TRANSLATED]] and[CYR:[TRANSLATED]]towith [CYR:[TRANSLATED]] for Fibonacci-in[EN]with[EN]
    edges_buffer[idx] = PhiEdge.init(source, target, @intCast(idx % 20 + 1));
    graph_edge_count += 1;
    
    return idx;
}

/// [EN]from[EN]with[EN] [CYR:[TRANSLATED]] ([CYR:[TRANSLATED]]and[CYR:[EN]l]onI ≈ n × φ [CYR:[TRANSLATED]])
fn phi_graph_density() f64 {
    if (graph_node_count == 0) return 0.0;
    const n: f64 = @floatFromInt(graph_node_count);
    const e: f64 = @floatFromInt(graph_edge_count);
    return e / (n * PHI);
}

/// [CYR:[TRANSLATED]]and[EN]with[EN]in[EN] [CYR:[TRANSLATED]]in
fn phi_graph_node_count() u32 {
    return graph_node_count;
}

/// [CYR:[TRANSLATED]]and[EN]with[EN]in[EN] [CYR:[TRANSLATED]]
fn phi_graph_edge_count() u32 {
    return graph_edge_count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_tree_insert_and_search" {
    phi_tree_init();
    
    // [EN]with[EN]in[CYR:[EN]I[EN]] elementy
    const idx1 = phi_tree_insert(5.0);
    const idx2 = phi_tree_insert(3.0);
    const idx3 = phi_tree_insert(8.0);
    
    // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] that inwith[EN]into[EN] [CYR:work]from[CYR:acts]
    try std.testing.expect(idx1 != PhiNode.NONE);
    try std.testing.expect(idx2 != PhiNode.NONE);
    try std.testing.expect(idx3 != PhiNode.NONE);
    try std.testing.expectEqual(node_count, 3);
    
    // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] that to[CYR:[TRANSLATED]] with[CYR:[TRANSLATED]]with[EN]in[CYR:[TRANSLATED]]
    try std.testing.expect(nodes_buffer[0].value == 5.0);
    
    // [EN]andwithto notwith[CYR:[TRANSLATED]]with[EN]in[CYR:[TRANSLATED]go] element[EN]
    try std.testing.expect(phi_tree_search(99.0) == PhiNode.NONE);
}

test "fib_heap_operations" {
    fib_heap_init();
    
    _ = fib_heap_insert(5.0);
    _ = fib_heap_insert(3.0);
    _ = fib_heap_insert(8.0);
    _ = fib_heap_insert(1.0);
    
    try std.testing.expectApproxEqAbs(fib_heap_min(), 1.0, 1e-10);
    try std.testing.expectEqual(fib_heap_size(), 4);
    
    const min1 = fib_heap_extract_min();
    try std.testing.expectApproxEqAbs(min1, 1.0, 1e-10);
    
    const min2 = fib_heap_extract_min();
    try std.testing.expectApproxEqAbs(min2, 3.0, 1e-10);
}

test "phi_graph_density" {
    phi_graph_init();
    
    // [CYR:[TRANSLATED]]in[CYR:[EN]I[EN]] 10 [CYR:[TRANSLATED]]in
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = phi_graph_add_node(@floatFromInt(i));
    }
    
    // [CYR:[TRANSLATED]]and[CYR:[EN]lno[EN]] to[EN]and[EN]with[EN]in[EN] [CYR:[TRANSLATED]] ≈ 10 × φ ≈ 16
    var j: u32 = 0;
    while (j < 16) : (j += 1) {
        _ = phi_graph_add_edge(j % 10, (j + 1) % 10);
    }
    
    const density = phi_graph_density();
    try std.testing.expect(density > 0.9 and density < 1.1);
}
