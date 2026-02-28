// ═══════════════════════════════════════════════════════════════════════════════
// phi_structures v24.φ - Generated from specs/phi_structures.vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ-[CYR:опт]andмandзandроin[CYR:анные] with[CYR:тру]to[CYR:туры] [CYR:данных]
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
// [CYR:ПАМЯТЬ] [CYR:ДЛЯ] WASM
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
// [CYR:ТИПЫ]
// ═══════════════════════════════════════════════════════════════════════════════

/// [CYR:Узел] with φ-inеwithом
pub const PhiNode = extern struct {
    id: u64,
    value: f64,
    phi_weight: f64,
    phi_level: u32,
    parent: u32,      // and[CYR:нде]towith [CYR:род]and[CYR:теля] (MAX for to[CYR:орня])
    left_child: u32,  // and[CYR:нде]towith леin[CYR:ого] [CYR:ребён]toа
    right_child: u32, // and[CYR:нде]towith [CYR:пра]in[CYR:ого] [CYR:ребён]toа
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

/// [CYR:Ребро] with φ-inеwithом
pub const PhiEdge = extern struct {
    source: u64,
    target: u64,
    weight: f64,
    phi_factor: f64,
    
    pub fn init(source: u64, target: u64, fib_index: u32) PhiEdge {
        // Веwith = F(k) / F(k+1) → 1/φ
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
// φ-TREE: [CYR:Дере]inо with φ-[CYR:балан]withandроintoой
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialization φ-[CYR:дере]inа
fn phi_tree_init() void {
    node_count = 0;
    edge_count = 0;
}

/// Вwithтаintoа in φ-[CYR:дере]inо
/// Returns and[CYR:нде]towith ноin[CYR:ого] [CYR:узла]
fn phi_tree_insert(value: f64) u32 {
    if (node_count >= MAX_NODES) return PhiNode.NONE;
    
    const new_idx = node_count;
    
    if (node_count == 0) {
        // [CYR:Корень]
        nodes_buffer[new_idx] = PhiNode.init(new_idx, value, 0);
        node_count += 1;
        return new_idx;
    }
    
    // Поandwithto [CYR:поз]andцandand for inwithтаintoand (BST)
    var current: u32 = 0;
    var level: u32 = 0;
    
    while (true) {
        level += 1;
        const node = &nodes_buffer[current];
        
        if (value < node.value) {
            if (node.left_child == PhiNode.NONE) {
                // Вwithтаin[CYR:ляем] withлеinа
                nodes_buffer[new_idx] = PhiNode.init(new_idx, value, level);
                nodes_buffer[new_idx].parent = current;
                node.left_child = new_idx;
                node_count += 1;
                
                // [CYR:Про]in[CYR:еряем] φ-[CYR:балан]with
                phi_tree_rebalance(current);
                return new_idx;
            }
            current = node.left_child;
        } else {
            if (node.right_child == PhiNode.NONE) {
                // Вwithтаin[CYR:ляем] with[CYR:пра]inа
                nodes_buffer[new_idx] = PhiNode.init(new_idx, value, level);
                nodes_buffer[new_idx].parent = current;
                node.right_child = new_idx;
                node_count += 1;
                
                // [CYR:Про]in[CYR:еряем] φ-[CYR:балан]with
                phi_tree_rebalance(current);
                return new_idx;
            }
            current = node.right_child;
        }
    }
}

/// [CYR:Под]with[CYR:чёт] [CYR:размера] [CYR:поддере]inа (and[CYR:терат]andin[CYR:ный] with [CYR:огран]and[CYR:чен]andем [CYR:глуб]andны)
fn subtree_size(idx: u32) u32 {
    if (idx == PhiNode.NONE or idx >= node_count) return 0;
    
    // [CYR:Итерат]andin[CYR:ный] [CYR:под]with[CYR:чёт] with andwith[CYR:пользо]inанandем withтеtoа
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
        
        if (stack_top < 62) { // [CYR:Защ]andта from [CYR:перепол]notнandя
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

/// Check and inоwithwith[CYR:тано]in[CYR:лен]andе φ-[CYR:балан]withа (and[CYR:терат]andin[CYR:ный])
fn phi_tree_rebalance(start_idx: u32) void {
    var idx = start_idx;
    var iterations: u32 = 0;
    const max_iterations: u32 = 64; // [CYR:Защ]andта from беwithtoоnot[CYR:чного] цandtoла
    
    while (idx != PhiNode.NONE and idx < node_count and iterations < max_iterations) : (iterations += 1) {
        const node = &nodes_buffer[idx];
        const left_size = subtree_size(node.left_child);
        const right_size = subtree_size(node.right_child);
        
        // φ-[CYR:балан]with: |left - right × φ| < 1
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
        
        // [CYR:Переход]andм to [CYR:род]and[CYR:телю]
        idx = node.parent;
    }
}

/// [CYR:Пра]inая рfromацandя
fn phi_rotate_right(idx: u32) void {
    const node = &nodes_buffer[idx];
    const left_idx = node.left_child;
    if (left_idx == PhiNode.NONE) return;
    
    const left = &nodes_buffer[left_idx];
    
    // [CYR:Перемещаем] [CYR:пра]inое [CYR:поддере]inо left in леinое [CYR:поддере]inо node
    node.left_child = left.right_child;
    if (left.right_child != PhiNode.NONE) {
        nodes_buffer[left.right_child].parent = idx;
    }
    
    // left with[CYR:тано]inandтwithя [CYR:род]and[CYR:телем] node
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
    
    // [CYR:Обно]in[CYR:ляем] φ-inеwithа
    update_phi_weights(idx);
    update_phi_weights(left_idx);
}

/// Леinая рfromацandя
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

/// [CYR:Обно]in[CYR:лен]andе φ-inеwithоin поwithле рfromацandand
fn update_phi_weights(idx: u32) void {
    if (idx == PhiNode.NONE) return;
    
    var level: u32 = 0;
    var current = idx;
    
    // Счand[CYR:таем] [CYR:уро]in[CYR:ень] from to[CYR:орня]
    while (nodes_buffer[current].parent != PhiNode.NONE) {
        current = nodes_buffer[current].parent;
        level += 1;
    }
    
    // [CYR:Обно]in[CYR:ляем]
    nodes_buffer[idx].phi_level = level;
    nodes_buffer[idx].phi_weight = phi_core.phi_power(-@as(i32, @intCast(level)));
}

/// Поandwithto in φ-[CYR:дере]inе
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

/// [CYR:Глуб]andon φ-[CYR:дере]inа
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

/// Вwithтаintoа in Fibonacci heap - O(1)
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
        // [CYR:Доба]in[CYR:ляем] in toорnotinой withпandwithоto
        fib_list_insert(fib_min, idx);
        if (fib_nodes[idx].key < fib_nodes[fib_min].key) {
            fib_min = idx;
        }
    }
    
    fib_count += 1;
    fib_size += 1;
    return idx;
}

/// Вwithтаintoа in дinуwithin[CYR:язный] withпandwithоto
fn fib_list_insert(list_node: u32, new_node: u32) void {
    const list = &fib_nodes[list_node];
    const new = &fib_nodes[new_node];
    
    new.right = list_node;
    new.left = list.left;
    fib_nodes[list.left].right = new_node;
    list.left = new_node;
}

/// [CYR:Получен]andе мandнand[CYR:мума] - O(1)
fn fib_heap_min() f64 {
    if (fib_min == FibNode.NONE) return math.inf(f64);
    return fib_nodes[fib_min].key;
}

/// Изin[CYR:лечен]andе мandнand[CYR:мума] - O(log n) [CYR:аморт]andзandроin[CYR:анно]
fn fib_heap_extract_min() f64 {
    if (fib_min == FibNode.NONE) return math.inf(f64);
    
    const min_idx = fib_min;
    const min_key = fib_nodes[min_idx].key;
    const min_node = &fib_nodes[min_idx];
    
    // [CYR:Доба]in[CYR:ляем] [CYR:детей] in toорnotinой withпandwithоto
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
    
    // [CYR:Удаляем] min andз toорnotin[CYR:ого] withпandwithtoа
    if (min_node.right == min_idx) {
        // Едandнwithтin[CYR:енный] [CYR:узел]
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

/// [CYR:Кон]withолand[CYR:дац]andя toорnotin[CYR:ого] withпandwithtoа
fn fib_consolidate() void {
    if (fib_min == FibNode.NONE) return;
    
    // D(n) ≤ log_φ(n)
    const max_degree: u32 = 45; // log_φ(2^32)
    var degree_table: [max_degree]u32 = [_]u32{FibNode.NONE} ** max_degree;
    
    // [CYR:Соб]and[CYR:раем] inwithе to[CYR:орн]and
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
    
    // [CYR:Объед]and[CYR:няем] [CYR:дере]inья одandontoоinой with[CYR:тепен]and
    var i: u32 = 0;
    while (i < root_count) : (i += 1) {
        var x = roots[i];
        var d = fib_nodes[x].degree;
        
        while (d < max_degree and degree_table[d] != FibNode.NONE) {
            var y = degree_table[d];
            
            // x [CYR:должен] and[CYR:меть] [CYR:меньш]andй to[CYR:люч]
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
    
    // [CYR:Пере]with[CYR:тра]andin[CYR:аем] toорnotinой withпandwithоto and on[CYR:ход]andм ноinый мandнand[CYR:мум]
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

/// Сin[CYR:язы]inанandе дinух [CYR:дере]inьеin
fn fib_link(child: u32, parent: u32) void {
    // [CYR:Удаляем] child andз toорnotin[CYR:ого] withпandwithtoа
    fib_nodes[fib_nodes[child].left].right = fib_nodes[child].right;
    fib_nodes[fib_nodes[child].right].left = fib_nodes[child].left;
    
    // [CYR:Делаем] child [CYR:ребён]toом parent
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

/// [CYR:Размер] toучand
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

/// [CYR:Доба]in[CYR:лен]andе [CYR:узла] in [CYR:граф]
fn phi_graph_add_node(value: f64) u32 {
    if (graph_node_count >= MAX_NODES) return PhiNode.NONE;
    
    const idx = graph_node_count;
    nodes_buffer[idx] = PhiNode.init(idx, value, 0);
    graph_node_count += 1;
    
    return idx;
}

/// [CYR:Доба]in[CYR:лен]andе [CYR:ребра] with Fibonacci-inеwithом
fn phi_graph_add_edge(source: u64, target: u64) u32 {
    if (graph_edge_count >= MAX_EDGES) return PhiNode.NONE;
    
    const idx = graph_edge_count;
    // Иwith[CYR:пользуем] and[CYR:нде]towith [CYR:ребра] for Fibonacci-inеwithа
    edges_buffer[idx] = PhiEdge.init(source, target, @intCast(idx % 20 + 1));
    graph_edge_count += 1;
    
    return idx;
}

/// Плfromноwithть [CYR:графа] ([CYR:опт]and[CYR:маль]onя ≈ n × φ [CYR:рёбер])
fn phi_graph_density() f64 {
    if (graph_node_count == 0) return 0.0;
    const n: f64 = @floatFromInt(graph_node_count);
    const e: f64 = @floatFromInt(graph_edge_count);
    return e / (n * PHI);
}

/// [CYR:Кол]andчеwithтinо [CYR:узло]in
fn phi_graph_node_count() u32 {
    return graph_node_count;
}

/// [CYR:Кол]andчеwithтinо [CYR:рёбер]
fn phi_graph_edge_count() u32 {
    return graph_edge_count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_tree_insert_and_search" {
    phi_tree_init();
    
    // Вwithтаin[CYR:ляем] elementы
    const idx1 = phi_tree_insert(5.0);
    const idx2 = phi_tree_insert(3.0);
    const idx3 = phi_tree_insert(8.0);
    
    // [CYR:Про]in[CYR:еряем] that inwithтаintoа [CYR:раб]from[CYR:ает]
    try std.testing.expect(idx1 != PhiNode.NONE);
    try std.testing.expect(idx2 != PhiNode.NONE);
    try std.testing.expect(idx3 != PhiNode.NONE);
    try std.testing.expectEqual(node_count, 3);
    
    // [CYR:Про]in[CYR:еряем] that to[CYR:орень] with[CYR:уще]withтin[CYR:ует]
    try std.testing.expect(nodes_buffer[0].value == 5.0);
    
    // Поandwithto notwith[CYR:уще]withтin[CYR:ующего] elementа
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
    
    // [CYR:Доба]in[CYR:ляем] 10 [CYR:узло]in
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = phi_graph_add_node(@floatFromInt(i));
    }
    
    // [CYR:Опт]and[CYR:мальное] toолandчеwithтinо [CYR:рёбер] ≈ 10 × φ ≈ 16
    var j: u32 = 0;
    while (j < 16) : (j += 1) {
        _ = phi_graph_add_edge(j % 10, (j + 1) % 10);
    }
    
    const density = phi_graph_density();
    try std.testing.expect(density > 0.9 and density < 1.1);
}
