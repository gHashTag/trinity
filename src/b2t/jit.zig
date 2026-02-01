// JIT Compiler - TIR to x86_64 Native Code
// Compiles TIR bytecode to native machine code for 10-100x speedup
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_codegen = @import("b2t_codegen.zig");
const TritOpcode = b2t_codegen.TritOpcode;

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTER ALLOCATION - LIVE RANGE ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Virtual register representing a value
pub const VReg = u16;

/// Live range for a virtual register
pub const LiveRange = struct {
    vreg: VReg,
    start: u32, // First use (definition)
    end: u32, // Last use
    spilled: bool,
    physical_reg: ?PhysReg,

    pub fn overlaps(self: LiveRange, other: LiveRange) bool {
        return self.start < other.end and other.start < self.end;
    }
};

/// Physical x86_64 registers available for allocation
pub const PhysReg = enum(u8) {
    RAX = 0,
    RCX = 1,
    RDX = 2,
    RBX = 3,
    RSI = 6,
    RDI = 7,
    R8 = 8,
    R9 = 9,
    R10 = 10,
    R11 = 11,
    // R12-R15 are callee-saved, avoid for now
    // RSP, RBP reserved for stack

    pub fn encoding(self: PhysReg) u8 {
        return @intFromEnum(self);
    }

    pub fn needsRex(self: PhysReg) bool {
        return @intFromEnum(self) >= 8;
    }
};

/// Allocatable registers (caller-saved, not reserved)
pub const ALLOCATABLE_REGS = [_]PhysReg{
    .RAX, .RCX, .RDX, .RBX, .RSI, .RDI, .R8, .R9, .R10, .R11,
};

/// Live Range Analyzer - computes live ranges from TIR bytecode
pub const LiveRangeAnalyzer = struct {
    ranges: std.ArrayList(LiveRange),
    vreg_count: VReg,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LiveRangeAnalyzer {
        return LiveRangeAnalyzer{
            .ranges = std.ArrayList(LiveRange).init(allocator),
            .vreg_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LiveRangeAnalyzer) void {
        self.ranges.deinit();
    }

    /// Analyze TIR bytecode and compute live ranges
    pub fn analyze(self: *LiveRangeAnalyzer, tir: []const u8) !void {
        self.ranges.clearRetainingCapacity();
        self.vreg_count = 0;

        // Stack simulation to track virtual registers
        var stack: [256]VReg = undefined;
        var sp: usize = 0;
        var pc: u32 = 0;

        var i: usize = 0;
        while (i < tir.len) {
            const op = @as(TritOpcode, @enumFromInt(tir[i]));
            const instr_pc = pc;
            pc += 1;

            switch (op) {
                .T_CONST => {
                    // Creates a new value
                    const vreg = self.newVReg(instr_pc);
                    stack[sp] = vreg;
                    sp += 1;
                    i += 5; // opcode + 4 bytes immediate
                },
                .T_ADD, .T_SUB, .T_MUL, .T_DIV, .T_MOD => {
                    // Consumes two values, produces one
                    if (sp >= 2) {
                        sp -= 1;
                        const b = stack[sp];
                        sp -= 1;
                        const a = stack[sp];
                        self.extendRange(a, instr_pc);
                        self.extendRange(b, instr_pc);

                        const result = self.newVReg(instr_pc);
                        stack[sp] = result;
                        sp += 1;
                    }
                    i += 1;
                },
                .T_NEG => {
                    // Consumes one, produces one
                    if (sp >= 1) {
                        const a = stack[sp - 1];
                        self.extendRange(a, instr_pc);

                        const result = self.newVReg(instr_pc);
                        stack[sp - 1] = result;
                    }
                    i += 1;
                },
                .T_LOAD => {
                    // Load creates a new value
                    const vreg = self.newVReg(instr_pc);
                    stack[sp] = vreg;
                    sp += 1;
                    i += 5;
                },
                .T_STORE => {
                    // Store consumes a value
                    if (sp >= 1) {
                        sp -= 1;
                        const a = stack[sp];
                        self.extendRange(a, instr_pc);
                    }
                    i += 5;
                },
                .T_DUP => {
                    // Duplicate extends the range
                    if (sp >= 1) {
                        const a = stack[sp - 1];
                        self.extendRange(a, instr_pc);
                        stack[sp] = a; // Same vreg
                        sp += 1;
                    }
                    i += 1;
                },
                .T_DROP => {
                    if (sp >= 1) {
                        sp -= 1;
                        const a = stack[sp];
                        self.extendRange(a, instr_pc);
                    }
                    i += 1;
                },
                .T_RET => {
                    // Return consumes top of stack
                    if (sp >= 1) {
                        sp -= 1;
                        const a = stack[sp];
                        self.extendRange(a, instr_pc);
                    }
                    i += 1;
                },
                .T_JMP, .T_JZ, .T_JNZ => {
                    // Jumps may consume a value (conditional)
                    if (op != .T_JMP and sp >= 1) {
                        sp -= 1;
                        const a = stack[sp];
                        self.extendRange(a, instr_pc);
                    }
                    i += 5;
                },
                .T_CMP_EQ, .T_CMP_LT, .T_CMP_GT => {
                    // Compare consumes two, produces one
                    if (sp >= 2) {
                        sp -= 1;
                        const b = stack[sp];
                        sp -= 1;
                        const a = stack[sp];
                        self.extendRange(a, instr_pc);
                        self.extendRange(b, instr_pc);

                        const result = self.newVReg(instr_pc);
                        stack[sp] = result;
                        sp += 1;
                    }
                    i += 1;
                },
                else => {
                    i += 1;
                },
            }
        }
    }

    fn newVReg(self: *LiveRangeAnalyzer, pc: u32) VReg {
        const vreg = self.vreg_count;
        self.vreg_count += 1;

        self.ranges.append(LiveRange{
            .vreg = vreg,
            .start = pc,
            .end = pc + 1,
            .spilled = false,
            .physical_reg = null,
        }) catch {};

        return vreg;
    }

    fn extendRange(self: *LiveRangeAnalyzer, vreg: VReg, pc: u32) void {
        for (self.ranges.items) |*range| {
            if (range.vreg == vreg) {
                if (pc + 1 > range.end) {
                    range.end = pc + 1;
                }
                return;
            }
        }
    }

    /// Get all live ranges
    pub fn getRanges(self: *LiveRangeAnalyzer) []LiveRange {
        return self.ranges.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTERFERENCE GRAPH
// ═══════════════════════════════════════════════════════════════════════════════

/// Interference graph for register allocation
/// Two virtual registers interfere if their live ranges overlap
pub const InterferenceGraph = struct {
    /// Adjacency matrix: edges[i][j] = true if vreg i and j interfere
    edges: [][]bool,
    /// Number of virtual registers
    num_vregs: usize,
    /// Degree of each node (number of neighbors)
    degrees: []u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, num_vregs: usize) !InterferenceGraph {
        var edges = try allocator.alloc([]bool, num_vregs);
        for (0..num_vregs) |i| {
            edges[i] = try allocator.alloc(bool, num_vregs);
            @memset(edges[i], false);
        }

        const degrees = try allocator.alloc(u32, num_vregs);
        @memset(degrees, 0);

        return InterferenceGraph{
            .edges = edges,
            .num_vregs = num_vregs,
            .degrees = degrees,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InterferenceGraph) void {
        for (self.edges) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.edges);
        self.allocator.free(self.degrees);
    }

    /// Build interference graph from live ranges
    pub fn buildFromRanges(self: *InterferenceGraph, ranges: []LiveRange) void {
        // Reset
        for (0..self.num_vregs) |i| {
            @memset(self.edges[i], false);
            self.degrees[i] = 0;
        }

        // For each pair of ranges, check if they overlap
        for (0..ranges.len) |i| {
            for (i + 1..ranges.len) |j| {
                if (ranges[i].overlaps(ranges[j])) {
                    self.addEdge(ranges[i].vreg, ranges[j].vreg);
                }
            }
        }
    }

    /// Add an interference edge between two vregs
    pub fn addEdge(self: *InterferenceGraph, a: VReg, b: VReg) void {
        if (a >= self.num_vregs or b >= self.num_vregs) return;
        if (a == b) return;

        if (!self.edges[a][b]) {
            self.edges[a][b] = true;
            self.edges[b][a] = true;
            self.degrees[a] += 1;
            self.degrees[b] += 1;
        }
    }

    /// Check if two vregs interfere
    pub fn interferes(self: *InterferenceGraph, a: VReg, b: VReg) bool {
        if (a >= self.num_vregs or b >= self.num_vregs) return false;
        return self.edges[a][b];
    }

    /// Get degree of a vreg
    pub fn degree(self: *InterferenceGraph, vreg: VReg) u32 {
        if (vreg >= self.num_vregs) return 0;
        return self.degrees[vreg];
    }

    /// Get neighbors of a vreg
    pub fn neighbors(self: *InterferenceGraph, vreg: VReg, buf: []VReg) []VReg {
        if (vreg >= self.num_vregs) return buf[0..0];

        var count: usize = 0;
        for (0..self.num_vregs) |i| {
            if (self.edges[vreg][i] and count < buf.len) {
                buf[count] = @intCast(i);
                count += 1;
            }
        }
        return buf[0..count];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GRAPH COLORING REGISTER ALLOCATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Graph coloring register allocator using Chaitin-Briggs algorithm
pub const GraphColoringAllocator = struct {
    graph: InterferenceGraph,
    ranges: []LiveRange,
    num_colors: usize, // Number of physical registers
    allocator: std.mem.Allocator,

    // Simplify worklist
    simplify_worklist: std.ArrayList(VReg),
    // Spill worklist (high degree nodes)
    spill_worklist: std.ArrayList(VReg),
    // Stack for coloring
    select_stack: std.ArrayList(VReg),
    // Removed nodes
    removed: []bool,

    pub fn init(allocator: std.mem.Allocator, ranges: []LiveRange) !GraphColoringAllocator {
        const num_vregs = ranges.len;
        var graph = try InterferenceGraph.init(allocator, num_vregs);
        graph.buildFromRanges(ranges);

        const removed = try allocator.alloc(bool, num_vregs);
        @memset(removed, false);

        return GraphColoringAllocator{
            .graph = graph,
            .ranges = ranges,
            .num_colors = ALLOCATABLE_REGS.len,
            .allocator = allocator,
            .simplify_worklist = std.ArrayList(VReg).init(allocator),
            .spill_worklist = std.ArrayList(VReg).init(allocator),
            .select_stack = std.ArrayList(VReg).init(allocator),
            .removed = removed,
        };
    }

    pub fn deinit(self: *GraphColoringAllocator) void {
        self.graph.deinit();
        self.simplify_worklist.deinit();
        self.spill_worklist.deinit();
        self.select_stack.deinit();
        self.allocator.free(self.removed);
    }

    /// Run the allocator
    pub fn allocate(self: *GraphColoringAllocator) !void {
        // Phase 1: Build worklists
        self.buildWorklists();

        // Phase 2: Simplify - remove low-degree nodes
        while (self.simplify_worklist.items.len > 0 or self.spill_worklist.items.len > 0) {
            if (self.simplify_worklist.items.len > 0) {
                self.simplify();
            } else {
                // Select a node to spill (highest degree)
                self.selectSpill();
            }
        }

        // Phase 3: Select - assign colors
        try self.select();
    }

    fn buildWorklists(self: *GraphColoringAllocator) void {
        self.simplify_worklist.clearRetainingCapacity();
        self.spill_worklist.clearRetainingCapacity();

        for (0..self.ranges.len) |i| {
            const vreg: VReg = @intCast(i);
            if (self.graph.degree(vreg) < self.num_colors) {
                self.simplify_worklist.append(vreg) catch {};
            } else {
                self.spill_worklist.append(vreg) catch {};
            }
        }
    }

    fn simplify(self: *GraphColoringAllocator) void {
        if (self.simplify_worklist.items.len == 0) return;

        // Remove a low-degree node
        const vreg = self.simplify_worklist.pop();
        self.select_stack.append(vreg) catch {};
        self.removed[vreg] = true;

        // Update degrees of neighbors
        var neighbor_buf: [64]VReg = undefined;
        const neighbors = self.graph.neighbors(vreg, &neighbor_buf);

        for (neighbors) |n| {
            if (self.removed[n]) continue;

            // Decrement effective degree
            // If neighbor moves from spill to simplify worklist
            const old_degree = self.effectiveDegree(n);
            if (old_degree == self.num_colors) {
                // Move from spill to simplify
                self.removeFromSpillWorklist(n);
                self.simplify_worklist.append(n) catch {};
            }
        }
    }

    fn selectSpill(self: *GraphColoringAllocator) void {
        if (self.spill_worklist.items.len == 0) return;

        // Select node with highest degree (potential spill)
        var max_degree: u32 = 0;
        var max_idx: usize = 0;

        for (self.spill_worklist.items, 0..) |vreg, idx| {
            const deg = self.effectiveDegree(vreg);
            if (deg > max_degree) {
                max_degree = deg;
                max_idx = idx;
            }
        }

        const vreg = self.spill_worklist.orderedRemove(max_idx);
        self.select_stack.append(vreg) catch {};
        self.removed[vreg] = true;
    }

    fn select(self: *GraphColoringAllocator) !void {
        // Pop nodes from stack and assign colors
        while (self.select_stack.items.len > 0) {
            const vreg = self.select_stack.pop();
            self.removed[vreg] = false;

            // Find available color
            var used_colors: [16]bool = [_]bool{false} ** 16;

            var neighbor_buf: [64]VReg = undefined;
            const neighbors = self.graph.neighbors(vreg, &neighbor_buf);

            for (neighbors) |n| {
                if (self.ranges[n].physical_reg) |reg| {
                    const color = @intFromEnum(reg);
                    if (color < used_colors.len) {
                        used_colors[color] = true;
                    }
                }
            }

            // Assign first available color
            var assigned = false;
            for (ALLOCATABLE_REGS) |reg| {
                const color = reg.encoding();
                if (!used_colors[color]) {
                    self.ranges[vreg].physical_reg = reg;
                    assigned = true;
                    break;
                }
            }

            if (!assigned) {
                // Must spill
                self.ranges[vreg].spilled = true;
            }
        }
    }

    fn effectiveDegree(self: *GraphColoringAllocator, vreg: VReg) u32 {
        var count: u32 = 0;
        for (0..self.ranges.len) |i| {
            if (!self.removed[i] and self.graph.edges[vreg][i]) {
                count += 1;
            }
        }
        return count;
    }

    fn removeFromSpillWorklist(self: *GraphColoringAllocator, vreg: VReg) void {
        for (self.spill_worklist.items, 0..) |v, idx| {
            if (v == vreg) {
                _ = self.spill_worklist.orderedRemove(idx);
                return;
            }
        }
    }

    /// Get allocation result for a vreg
    pub fn getAllocation(self: *GraphColoringAllocator, vreg: VReg) ?PhysReg {
        if (vreg >= self.ranges.len) return null;
        return self.ranges[vreg].physical_reg;
    }

    /// Check if vreg was spilled
    pub fn isSpilled(self: *GraphColoringAllocator, vreg: VReg) bool {
        if (vreg >= self.ranges.len) return true;
        return self.ranges[vreg].spilled;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP DETECTION AND COMPILATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Basic block for CFG analysis
pub const BasicBlock = struct {
    start: u32, // Start offset in bytecode
    end: u32, // End offset (exclusive)
    successors: [2]?u32, // Up to 2 successors (fall-through, jump target)
    predecessors: std.ArrayList(u32),
    is_loop_header: bool,
    loop_depth: u32,
    execution_count: u64, // For hot loop detection

    pub fn init(allocator: std.mem.Allocator, start: u32) BasicBlock {
        return BasicBlock{
            .start = start,
            .end = start,
            .successors = [_]?u32{ null, null },
            .predecessors = std.ArrayList(u32).init(allocator),
            .is_loop_header = false,
            .loop_depth = 0,
            .execution_count = 0,
        };
    }

    pub fn deinit(self: *BasicBlock) void {
        self.predecessors.deinit();
    }
};

/// Loop information
pub const LoopInfo = struct {
    header: u32, // Block index of loop header
    back_edge_source: u32, // Block that jumps back to header
    body_blocks: std.ArrayList(u32), // All blocks in the loop
    depth: u32, // Nesting depth
    trip_count_estimate: ?u64, // Estimated iterations if known

    pub fn init(allocator: std.mem.Allocator, header: u32, back_edge: u32) LoopInfo {
        return LoopInfo{
            .header = header,
            .back_edge_source = back_edge,
            .body_blocks = std.ArrayList(u32).init(allocator),
            .depth = 1,
            .trip_count_estimate = null,
        };
    }

    pub fn deinit(self: *LoopInfo) void {
        self.body_blocks.deinit();
    }
};

/// Control Flow Graph analyzer
pub const CFGAnalyzer = struct {
    blocks: std.ArrayList(BasicBlock),
    loops: std.ArrayList(LoopInfo),
    block_map: std.AutoHashMap(u32, u32), // offset -> block index
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CFGAnalyzer {
        return CFGAnalyzer{
            .blocks = std.ArrayList(BasicBlock).init(allocator),
            .loops = std.ArrayList(LoopInfo).init(allocator),
            .block_map = std.AutoHashMap(u32, u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CFGAnalyzer) void {
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.deinit();
        for (self.loops.items) |*loop| {
            loop.deinit();
        }
        self.loops.deinit();
        self.block_map.deinit();
    }

    /// Build CFG from TIR bytecode
    pub fn buildCFG(self: *CFGAnalyzer, tir: []const u8) !void {
        // Clear previous state
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.clearRetainingCapacity();
        self.block_map.clearRetainingCapacity();

        // Pass 1: Find all block leaders (targets of jumps, after jumps)
        var leaders = std.AutoHashMap(u32, void).init(self.allocator);
        defer leaders.deinit();

        try leaders.put(0, {}); // First instruction is always a leader

        var i: usize = 0;
        while (i < tir.len) {
            const op = @as(TritOpcode, @enumFromInt(tir[i]));
            const offset: u32 = @intCast(i);

            switch (op) {
                .T_JMP, .T_JZ, .T_JNZ => {
                    if (i + 4 < tir.len) {
                        const target = std.mem.readInt(i32, tir[i + 1 ..][0..4], .little);
                        const target_offset: u32 = @intCast(@as(i64, offset) + 5 + target);
                        try leaders.put(target_offset, {});
                        try leaders.put(@intCast(i + 5), {}); // Fall-through
                    }
                    i += 5;
                },
                .T_RET => {
                    if (i + 1 < tir.len) {
                        try leaders.put(@intCast(i + 1), {});
                    }
                    i += 1;
                },
                .T_CONST, .T_LOAD, .T_STORE => i += 5,
                else => i += 1,
            }
        }

        // Pass 2: Create basic blocks
        var sorted_leaders = std.ArrayList(u32).init(self.allocator);
        defer sorted_leaders.deinit();

        var leader_iter = leaders.keyIterator();
        while (leader_iter.next()) |leader| {
            try sorted_leaders.append(leader.*);
        }
        std.mem.sort(u32, sorted_leaders.items, {}, std.sort.asc(u32));

        for (sorted_leaders.items, 0..) |leader, idx| {
            var block = BasicBlock.init(self.allocator, leader);
            if (idx + 1 < sorted_leaders.items.len) {
                block.end = sorted_leaders.items[idx + 1];
            } else {
                block.end = @intCast(tir.len);
            }
            try self.block_map.put(leader, @intCast(self.blocks.items.len));
            try self.blocks.append(block);
        }

        // Pass 3: Connect blocks (successors/predecessors)
        for (self.blocks.items, 0..) |*block, block_idx| {
            const last_instr_offset = self.findLastInstruction(tir, block.start, block.end);
            if (last_instr_offset >= tir.len) continue;

            const op = @as(TritOpcode, @enumFromInt(tir[last_instr_offset]));

            switch (op) {
                .T_JMP => {
                    const target = std.mem.readInt(i32, tir[last_instr_offset + 1 ..][0..4], .little);
                    const target_offset: u32 = @intCast(@as(i64, last_instr_offset) + 5 + target);
                    if (self.block_map.get(target_offset)) |target_idx| {
                        block.successors[0] = target_idx;
                        try self.blocks.items[target_idx].predecessors.append(@intCast(block_idx));
                    }
                },
                .T_JZ, .T_JNZ => {
                    // Conditional: fall-through and jump target
                    const target = std.mem.readInt(i32, tir[last_instr_offset + 1 ..][0..4], .little);
                    const target_offset: u32 = @intCast(@as(i64, last_instr_offset) + 5 + target);
                    const fall_through: u32 = @intCast(last_instr_offset + 5);

                    if (self.block_map.get(fall_through)) |ft_idx| {
                        block.successors[0] = ft_idx;
                        try self.blocks.items[ft_idx].predecessors.append(@intCast(block_idx));
                    }
                    if (self.block_map.get(target_offset)) |target_idx| {
                        block.successors[1] = target_idx;
                        try self.blocks.items[target_idx].predecessors.append(@intCast(block_idx));
                    }
                },
                .T_RET => {
                    // No successors
                },
                else => {
                    // Fall through to next block
                    if (block_idx + 1 < self.blocks.items.len) {
                        block.successors[0] = @intCast(block_idx + 1);
                        try self.blocks.items[block_idx + 1].predecessors.append(@intCast(block_idx));
                    }
                },
            }
        }
    }

    /// Detect loops via back edges (edge from B to A where A dominates B)
    pub fn detectLoops(self: *CFGAnalyzer) !void {
        for (self.loops.items) |*loop| {
            loop.deinit();
        }
        self.loops.clearRetainingCapacity();

        // Simple back edge detection: edge to a block with lower index
        // (approximation - proper dominance analysis would be more accurate)
        for (self.blocks.items, 0..) |block, block_idx| {
            for (block.successors) |succ_opt| {
                if (succ_opt) |succ_idx| {
                    // Back edge: successor has lower or equal index
                    if (succ_idx <= block_idx) {
                        self.blocks.items[succ_idx].is_loop_header = true;

                        var loop = LoopInfo.init(self.allocator, succ_idx, @intCast(block_idx));

                        // Find all blocks in the loop (natural loop)
                        try self.findLoopBody(&loop, succ_idx, @intCast(block_idx));

                        try self.loops.append(loop);
                    }
                }
            }
        }

        // Calculate loop depths for nested loops
        self.calculateLoopDepths();
    }

    fn findLoopBody(self: *CFGAnalyzer, loop: *LoopInfo, header: u32, back_edge_src: u32) !void {
        // Natural loop: all blocks that can reach back_edge_src without going through header
        var visited = std.AutoHashMap(u32, void).init(self.allocator);
        defer visited.deinit();

        var worklist = std.ArrayList(u32).init(self.allocator);
        defer worklist.deinit();

        try visited.put(header, {});
        try loop.body_blocks.append(header);

        if (back_edge_src != header) {
            try worklist.append(back_edge_src);
            try visited.put(back_edge_src, {});
            try loop.body_blocks.append(back_edge_src);
        }

        while (worklist.items.len > 0) {
            const block_idx = worklist.pop();

            for (self.blocks.items[block_idx].predecessors.items) |pred| {
                if (!visited.contains(pred)) {
                    try visited.put(pred, {});
                    try loop.body_blocks.append(pred);
                    try worklist.append(pred);
                }
            }
        }
    }

    fn calculateLoopDepths(self: *CFGAnalyzer) void {
        // Reset depths
        for (self.blocks.items) |*block| {
            block.loop_depth = 0;
        }

        // For each loop, increment depth of contained blocks
        for (self.loops.items) |loop| {
            for (loop.body_blocks.items) |block_idx| {
                self.blocks.items[block_idx].loop_depth += 1;
            }
        }

        // Update loop depths
        for (self.loops.items) |*loop| {
            loop.depth = self.blocks.items[loop.header].loop_depth;
        }
    }

    fn findLastInstruction(self: *CFGAnalyzer, tir: []const u8, start: u32, end: u32) u32 {
        _ = self;
        var last: u32 = start;
        var i: u32 = start;

        while (i < end and i < tir.len) {
            last = i;
            const op = @as(TritOpcode, @enumFromInt(tir[i]));
            switch (op) {
                .T_CONST, .T_LOAD, .T_STORE, .T_JMP, .T_JZ, .T_JNZ => i += 5,
                else => i += 1,
            }
        }
        return last;
    }

    /// Get hot loops (execution count above threshold)
    pub fn getHotLoops(self: *CFGAnalyzer, threshold: u64) []LoopInfo {
        var count: usize = 0;
        for (self.loops.items) |loop| {
            if (self.blocks.items[loop.header].execution_count >= threshold) {
                count += 1;
            }
        }
        // Return all loops for now (profiling would filter)
        return self.loops.items;
    }

    /// Increment execution count for a block (for profiling)
    pub fn recordExecution(self: *CFGAnalyzer, offset: u32) void {
        if (self.block_map.get(offset)) |block_idx| {
            self.blocks.items[block_idx].execution_count += 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HOT LOOP COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

/// Compiles hot loops to native code with optimizations
pub const LoopCompiler = struct {
    code: MachineCode,
    allocator: std.mem.Allocator,
    loop_code_cache: std.AutoHashMap(u32, CompiledLoop),

    pub const CompiledLoop = struct {
        code_offset: usize,
        code_len: usize,
        entry_func: *const fn (i32, i32) callconv(.C) i32,
    };

    pub fn init(allocator: std.mem.Allocator) !LoopCompiler {
        return LoopCompiler{
            .code = try MachineCode.init(allocator, 64 * 1024), // 64KB for loops
            .allocator = allocator,
            .loop_code_cache = std.AutoHashMap(u32, CompiledLoop).init(allocator),
        };
    }

    pub fn deinit(self: *LoopCompiler) void {
        self.code.deinit();
        self.loop_code_cache.deinit();
    }

    /// Compile a loop to native code
    pub fn compileLoop(self: *LoopCompiler, tir: []const u8, loop: *const LoopInfo, cfg: *const CFGAnalyzer) !void {
        const header = loop.header;
        if (self.loop_code_cache.contains(header)) return; // Already compiled

        const start_offset = self.code.len;

        // Prologue: save callee-saved registers
        self.emitPrologue();

        // Compile loop body
        _ = &cfg.blocks.items[header]; // header_block
        var compiled_blocks = std.AutoHashMap(u32, usize).init(self.allocator);
        defer compiled_blocks.deinit();

        // Record where each block starts in native code
        try compiled_blocks.put(header, self.code.len);

        // Compile blocks in loop
        for (loop.body_blocks.items) |body_block_idx| {
            const block = &cfg.blocks.items[body_block_idx];
            try compiled_blocks.put(body_block_idx, self.code.len);

            // Compile instructions in block
            var i: usize = block.start;
            while (i < block.end and i < tir.len) {
                const op = @as(TritOpcode, @enumFromInt(tir[i]));
                try self.compileInstruction(tir, &i, op);
            }
        }

        // Epilogue
        self.emitEpilogue();

        // Make executable
        try self.code.makeExecutable();

        // Cache the compiled loop
        const func_ptr: *const fn (i32, i32) callconv(.C) i32 = @ptrCast(@alignCast(self.code.code.ptr + start_offset));
        try self.loop_code_cache.put(header, CompiledLoop{
            .code_offset = start_offset,
            .code_len = self.code.len - start_offset,
            .entry_func = func_ptr,
        });
    }

    fn emitPrologue(self: *LoopCompiler) void {
        // push rbp
        self.code.emit(0x55);
        // mov rbp, rsp
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0xE5 });
        // push rbx (callee-saved)
        self.code.emit(0x53);
    }

    fn emitEpilogue(self: *LoopCompiler) void {
        // pop rbx
        self.code.emit(0x5B);
        // pop rbp
        self.code.emit(0x5D);
        // ret
        self.code.emit(0xC3);
    }

    fn compileInstruction(self: *LoopCompiler, tir: []const u8, i: *usize, op: TritOpcode) !void {
        switch (op) {
            .T_CONST => {
                const value = std.mem.readInt(i32, tir[i.* + 1 ..][0..4], .little);
                // mov eax, imm32
                self.code.emit(0xB8);
                self.code.emitImm32(value);
                // push rax
                self.code.emit(0x50);
                i.* += 5;
            },
            .T_ADD => {
                // pop rcx
                self.code.emit(0x59);
                // pop rax
                self.code.emit(0x58);
                // add eax, ecx
                self.code.emitBytes(&[_]u8{ 0x01, 0xC8 });
                // push rax
                self.code.emit(0x50);
                i.* += 1;
            },
            .T_SUB => {
                // pop rcx
                self.code.emit(0x59);
                // pop rax
                self.code.emit(0x58);
                // sub eax, ecx
                self.code.emitBytes(&[_]u8{ 0x29, 0xC8 });
                // push rax
                self.code.emit(0x50);
                i.* += 1;
            },
            .T_MUL => {
                // pop rcx
                self.code.emit(0x59);
                // pop rax
                self.code.emit(0x58);
                // imul eax, ecx
                self.code.emitBytes(&[_]u8{ 0x0F, 0xAF, 0xC1 });
                // push rax
                self.code.emit(0x50);
                i.* += 1;
            },
            .T_CMP_LT => {
                // pop rcx
                self.code.emit(0x59);
                // pop rax
                self.code.emit(0x58);
                // cmp eax, ecx
                self.code.emitBytes(&[_]u8{ 0x39, 0xC8 });
                // setl al
                self.code.emitBytes(&[_]u8{ 0x0F, 0x9C, 0xC0 });
                // movzx eax, al
                self.code.emitBytes(&[_]u8{ 0x0F, 0xB6, 0xC0 });
                // push rax
                self.code.emit(0x50);
                i.* += 1;
            },
            .T_LOAD => {
                const slot = std.mem.readInt(i32, tir[i.* + 1 ..][0..4], .little);
                // mov eax, [rbp + offset]
                self.code.emitBytes(&[_]u8{ 0x8B, 0x45 });
                self.code.emit(@intCast(@as(i8, @truncate(-8 - slot * 8))));
                // push rax
                self.code.emit(0x50);
                i.* += 5;
            },
            .T_STORE => {
                const slot = std.mem.readInt(i32, tir[i.* + 1 ..][0..4], .little);
                // pop rax
                self.code.emit(0x58);
                // mov [rbp + offset], eax
                self.code.emitBytes(&[_]u8{ 0x89, 0x45 });
                self.code.emit(@intCast(@as(i8, @truncate(-8 - slot * 8))));
                i.* += 5;
            },
            .T_JMP => {
                // jmp rel32 (placeholder - needs patching)
                self.code.emit(0xE9);
                self.code.emitImm32(0); // Will be patched
                i.* += 5;
            },
            .T_JZ => {
                // pop rax
                self.code.emit(0x58);
                // test eax, eax
                self.code.emitBytes(&[_]u8{ 0x85, 0xC0 });
                // jz rel32 (placeholder)
                self.code.emitBytes(&[_]u8{ 0x0F, 0x84 });
                self.code.emitImm32(0);
                i.* += 5;
            },
            .T_JNZ => {
                // pop rax
                self.code.emit(0x58);
                // test eax, eax
                self.code.emitBytes(&[_]u8{ 0x85, 0xC0 });
                // jnz rel32 (placeholder)
                self.code.emitBytes(&[_]u8{ 0x0F, 0x85 });
                self.code.emitImm32(0);
                i.* += 5;
            },
            .T_RET => {
                // pop rax (return value)
                self.code.emit(0x58);
                i.* += 1;
            },
            else => {
                i.* += 1;
            },
        }
    }

    /// Execute a compiled loop
    pub fn executeLoop(self: *LoopCompiler, header: u32, arg0: i32, arg1: i32) ?i32 {
        if (self.loop_code_cache.get(header)) |compiled| {
            return compiled.entry_func(arg0, arg1);
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP INVARIANT CODE MOTION (LICM)
// ═══════════════════════════════════════════════════════════════════════════════

/// Instruction for LICM analysis
pub const LICMInstruction = struct {
    offset: u32,
    opcode: TritOpcode,
    operand: ?i32,
    is_invariant: bool,
    depends_on: [2]?u32, // Offsets of instructions this depends on
};

/// Loop Invariant Code Motion optimizer
pub const LICM = struct {
    instructions: std.ArrayList(LICMInstruction),
    invariants: std.ArrayList(u32), // Offsets of invariant instructions
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LICM {
        return LICM{
            .instructions = std.ArrayList(LICMInstruction).init(allocator),
            .invariants = std.ArrayList(u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LICM) void {
        self.instructions.deinit();
        self.invariants.deinit();
    }

    /// Analyze a loop for invariant code
    pub fn analyze(self: *LICM, tir: []const u8, loop: *const LoopInfo, cfg: *const CFGAnalyzer) !void {
        self.instructions.clearRetainingCapacity();
        self.invariants.clearRetainingCapacity();

        // Collect all instructions in loop
        for (loop.body_blocks.items) |block_idx| {
            const block = &cfg.blocks.items[block_idx];
            var i: usize = block.start;

            while (i < block.end and i < tir.len) {
                const op = @as(TritOpcode, @enumFromInt(tir[i]));
                var instr = LICMInstruction{
                    .offset = @intCast(i),
                    .opcode = op,
                    .operand = null,
                    .is_invariant = false,
                    .depends_on = [_]?u32{ null, null },
                };

                switch (op) {
                    .T_CONST => {
                        instr.operand = std.mem.readInt(i32, tir[i + 1 ..][0..4], .little);
                        instr.is_invariant = true; // Constants are always invariant
                        i += 5;
                    },
                    .T_LOAD => {
                        instr.operand = std.mem.readInt(i32, tir[i + 1 ..][0..4], .little);
                        // Load is invariant if the slot is not modified in the loop
                        instr.is_invariant = !self.isSlotModifiedInLoop(tir, loop, cfg, instr.operand.?);
                        i += 5;
                    },
                    .T_STORE => {
                        instr.operand = std.mem.readInt(i32, tir[i + 1 ..][0..4], .little);
                        instr.is_invariant = false; // Stores are never invariant
                        i += 5;
                    },
                    .T_ADD, .T_SUB, .T_MUL, .T_DIV => {
                        // Binary ops are invariant if both operands are invariant
                        // (simplified - would need proper data flow analysis)
                        i += 1;
                    },
                    else => {
                        i += 1;
                    },
                }

                try self.instructions.append(instr);
            }
        }

        // Iteratively mark invariants
        var changed = true;
        while (changed) {
            changed = false;
            for (self.instructions.items) |*instr| {
                if (!instr.is_invariant and self.canBeInvariant(instr)) {
                    instr.is_invariant = true;
                    changed = true;
                }
            }
        }

        // Collect invariant instruction offsets
        for (self.instructions.items) |instr| {
            if (instr.is_invariant) {
                try self.invariants.append(instr.offset);
            }
        }
    }

    fn isSlotModifiedInLoop(self: *LICM, tir: []const u8, loop: *const LoopInfo, cfg: *const CFGAnalyzer, slot: i32) bool {
        _ = self;
        for (loop.body_blocks.items) |block_idx| {
            const block = &cfg.blocks.items[block_idx];
            var i: usize = block.start;

            while (i < block.end and i < tir.len) {
                const op = @as(TritOpcode, @enumFromInt(tir[i]));
                if (op == .T_STORE) {
                    const store_slot = std.mem.readInt(i32, tir[i + 1 ..][0..4], .little);
                    if (store_slot == slot) return true;
                }
                switch (op) {
                    .T_CONST, .T_LOAD, .T_STORE, .T_JMP, .T_JZ, .T_JNZ => i += 5,
                    else => i += 1,
                }
            }
        }
        return false;
    }

    fn canBeInvariant(self: *LICM, instr: *const LICMInstruction) bool {
        // Check if all dependencies are invariant
        for (instr.depends_on) |dep_opt| {
            if (dep_opt) |dep_offset| {
                var found = false;
                for (self.instructions.items) |other| {
                    if (other.offset == dep_offset) {
                        if (!other.is_invariant) return false;
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
        }
        return true;
    }

    /// Get instructions that can be hoisted out of the loop
    pub fn getHoistableInstructions(self: *LICM) []u32 {
        return self.invariants.items;
    }

    /// Apply LICM transformation to TIR
    pub fn transform(self: *LICM, tir: []const u8, output: *std.ArrayList(u8), loop: *const LoopInfo) !void {
        _ = loop;
        // Emit hoisted instructions first (before loop)
        for (self.invariants.items) |offset| {
            for (self.instructions.items) |instr| {
                if (instr.offset == offset) {
                    try self.emitInstruction(output, tir, instr);
                    break;
                }
            }
        }

        // Emit remaining instructions (skip hoisted ones)
        for (self.instructions.items) |instr| {
            if (!instr.is_invariant) {
                try self.emitInstruction(output, tir, instr);
            }
        }
    }

    fn emitInstruction(self: *LICM, output: *std.ArrayList(u8), tir: []const u8, instr: LICMInstruction) !void {
        _ = self;
        const op = instr.opcode;
        try output.append(@intFromEnum(op));

        switch (op) {
            .T_CONST, .T_LOAD, .T_STORE, .T_JMP, .T_JZ, .T_JNZ => {
                // Copy 4-byte operand
                for (0..4) |j| {
                    try output.append(tir[instr.offset + 1 + j]);
                }
            },
            else => {},
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE CACHING
// ═══════════════════════════════════════════════════════════════════════════════

/// Call site state for inline caching
pub const CallSiteState = enum {
    Uninitialized, // Never called
    Monomorphic, // Always same target
    Polymorphic, // Multiple targets (up to N)
    Megamorphic, // Too many targets, use slow path
};

/// Inline cache entry
pub const InlineCacheEntry = struct {
    target_id: u32, // Function/method identifier
    native_code: ?*const fn () callconv(.C) i32, // Cached native code pointer
    hit_count: u64,
};

/// Monomorphic inline cache for a single call site
pub const MonomorphicIC = struct {
    state: CallSiteState,
    cached_target: ?u32,
    cached_code: ?*const fn (i32) callconv(.C) i32,
    miss_count: u64,

    pub fn init() MonomorphicIC {
        return MonomorphicIC{
            .state = .Uninitialized,
            .cached_target = null,
            .cached_code = null,
            .miss_count = 0,
        };
    }

    /// Check cache and return native code if hit
    pub fn lookup(self: *MonomorphicIC, target_id: u32) ?*const fn (i32) callconv(.C) i32 {
        switch (self.state) {
            .Uninitialized => {
                return null;
            },
            .Monomorphic => {
                if (self.cached_target == target_id) {
                    return self.cached_code;
                }
                self.miss_count += 1;
                if (self.miss_count > 10) {
                    self.state = .Megamorphic;
                }
                return null;
            },
            .Megamorphic => {
                return null; // Always miss, use slow path
            },
            else => return null,
        }
    }

    /// Update cache with new target
    pub fn update(self: *MonomorphicIC, target_id: u32, code: *const fn (i32) callconv(.C) i32) void {
        switch (self.state) {
            .Uninitialized => {
                self.state = .Monomorphic;
                self.cached_target = target_id;
                self.cached_code = code;
            },
            .Monomorphic => {
                if (self.cached_target != target_id) {
                    // Different target - transition to polymorphic
                    self.state = .Polymorphic;
                    self.cached_target = target_id;
                    self.cached_code = code;
                }
            },
            else => {},
        }
    }

    /// Reset cache
    pub fn reset(self: *MonomorphicIC) void {
        self.state = .Uninitialized;
        self.cached_target = null;
        self.cached_code = null;
        self.miss_count = 0;
    }
};

/// Polymorphic inline cache (PIC) - caches multiple targets
pub const PolymorphicIC = struct {
    const MAX_ENTRIES = 4;

    entries: [MAX_ENTRIES]?InlineCacheEntry,
    num_entries: usize,
    state: CallSiteState,
    total_calls: u64,

    pub fn init() PolymorphicIC {
        return PolymorphicIC{
            .entries = [_]?InlineCacheEntry{null} ** MAX_ENTRIES,
            .num_entries = 0,
            .state = .Uninitialized,
            .total_calls = 0,
        };
    }

    /// Lookup target in cache
    pub fn lookup(self: *PolymorphicIC, target_id: u32) ?*const fn () callconv(.C) i32 {
        self.total_calls += 1;

        for (&self.entries) |*entry_opt| {
            if (entry_opt.*) |*entry| {
                if (entry.target_id == target_id) {
                    entry.hit_count += 1;
                    return entry.native_code;
                }
            }
        }
        return null;
    }

    /// Add or update entry
    pub fn update(self: *PolymorphicIC, target_id: u32, code: *const fn () callconv(.C) i32) void {
        // Check if already exists
        for (&self.entries) |*entry_opt| {
            if (entry_opt.*) |*entry| {
                if (entry.target_id == target_id) {
                    entry.native_code = code;
                    return;
                }
            }
        }

        // Add new entry
        if (self.num_entries < MAX_ENTRIES) {
            self.entries[self.num_entries] = InlineCacheEntry{
                .target_id = target_id,
                .native_code = code,
                .hit_count = 0,
            };
            self.num_entries += 1;

            self.state = if (self.num_entries == 1) .Monomorphic else .Polymorphic;
        } else {
            // Evict least used entry
            var min_hits: u64 = std.math.maxInt(u64);
            var min_idx: usize = 0;

            for (self.entries, 0..) |entry_opt, idx| {
                if (entry_opt) |entry| {
                    if (entry.hit_count < min_hits) {
                        min_hits = entry.hit_count;
                        min_idx = idx;
                    }
                }
            }

            self.entries[min_idx] = InlineCacheEntry{
                .target_id = target_id,
                .native_code = code,
                .hit_count = 0,
            };

            self.state = .Megamorphic;
        }
    }

    /// Get cache hit rate
    pub fn hitRate(self: *PolymorphicIC) f64 {
        if (self.total_calls == 0) return 0.0;

        var total_hits: u64 = 0;
        for (self.entries) |entry_opt| {
            if (entry_opt) |entry| {
                total_hits += entry.hit_count;
            }
        }
        return @as(f64, @floatFromInt(total_hits)) / @as(f64, @floatFromInt(self.total_calls));
    }
};

/// Inline cache manager for all call sites
pub const InlineCacheManager = struct {
    monomorphic_caches: std.AutoHashMap(u32, MonomorphicIC),
    polymorphic_caches: std.AutoHashMap(u32, PolymorphicIC),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InlineCacheManager {
        return InlineCacheManager{
            .monomorphic_caches = std.AutoHashMap(u32, MonomorphicIC).init(allocator),
            .polymorphic_caches = std.AutoHashMap(u32, PolymorphicIC).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InlineCacheManager) void {
        self.monomorphic_caches.deinit();
        self.polymorphic_caches.deinit();
    }

    /// Get or create monomorphic cache for a call site
    pub fn getMonomorphicCache(self: *InlineCacheManager, call_site: u32) *MonomorphicIC {
        const result = self.monomorphic_caches.getOrPut(call_site) catch unreachable;
        if (!result.found_existing) {
            result.value_ptr.* = MonomorphicIC.init();
        }
        return result.value_ptr;
    }

    /// Get or create polymorphic cache for a call site
    pub fn getPolymorphicCache(self: *InlineCacheManager, call_site: u32) *PolymorphicIC {
        const result = self.polymorphic_caches.getOrPut(call_site) catch unreachable;
        if (!result.found_existing) {
            result.value_ptr.* = PolymorphicIC.init();
        }
        return result.value_ptr;
    }

    /// Invalidate all caches (e.g., after code modification)
    pub fn invalidateAll(self: *InlineCacheManager) void {
        var mono_iter = self.monomorphic_caches.valueIterator();
        while (mono_iter.next()) |cache| {
            cache.reset();
        }

        self.polymorphic_caches.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const JIT_CODE_SIZE: usize = 4096; // 4KB per function
pub const JIT_MAX_FUNCTIONS: usize = 256;

// x86_64 System V AMD64 ABI:
// Arguments: rdi, rsi, rdx, rcx, r8, r9
// Return: rax
// Callee-saved: rbx, rbp, r12-r15
// Caller-saved: rax, rcx, rdx, rsi, rdi, r8-r11

// Register encoding for ModR/M
const REG_RAX: u8 = 0;
const REG_RCX: u8 = 1;
const REG_RDX: u8 = 2;
const REG_RBX: u8 = 3;
const REG_RSP: u8 = 4;
const REG_RBP: u8 = 5;
const REG_RSI: u8 = 6;
const REG_RDI: u8 = 7;

// ═══════════════════════════════════════════════════════════════════════════════
// MACHINE CODE BUFFER
// ═══════════════════════════════════════════════════════════════════════════════

pub const MachineCode = struct {
    code: []align(4096) u8,
    len: usize,
    allocator: std.mem.Allocator,
    executable: bool,

    pub fn init(allocator: std.mem.Allocator, size: usize) !MachineCode {
        // Allocate page-aligned memory for executable code
        const code = try allocator.alignedAlloc(u8, 4096, size);
        @memset(code, 0xCC); // Fill with INT3 (breakpoint) for safety

        return MachineCode{
            .code = code,
            .len = 0,
            .allocator = allocator,
            .executable = false,
        };
    }

    pub fn deinit(self: *MachineCode) void {
        if (self.executable) {
            // Make writable again before freeing
            self.makeWritable() catch {};
        }
        self.allocator.free(self.code);
    }

    /// Emit a single byte
    pub fn emit(self: *MachineCode, byte: u8) void {
        if (self.len < self.code.len) {
            self.code[self.len] = byte;
            self.len += 1;
        }
    }

    /// Emit multiple bytes
    pub fn emitBytes(self: *MachineCode, bytes: []const u8) void {
        for (bytes) |b| {
            self.emit(b);
        }
    }

    /// Emit a 32-bit immediate (little-endian)
    pub fn emitImm32(self: *MachineCode, value: i32) void {
        const bytes = std.mem.asBytes(&value);
        self.emitBytes(bytes);
    }

    /// Emit a 64-bit immediate (little-endian)
    pub fn emitImm64(self: *MachineCode, value: i64) void {
        const bytes = std.mem.asBytes(&value);
        self.emitBytes(bytes);
    }

    /// Make code executable (Linux mprotect)
    pub fn makeExecutable(self: *MachineCode) !void {
        if (self.executable) return;

        // Use raw syscall for mprotect
        const PROT_READ: usize = 0x1;
        const PROT_EXEC: usize = 0x4;

        const addr = @intFromPtr(self.code.ptr);
        const len = self.code.len;

        // syscall: mprotect(addr, len, prot)
        const result = std.os.linux.syscall3(.mprotect, addr, len, PROT_READ | PROT_EXEC);
        if (result != 0) {
            return error.MprotectFailed;
        }

        self.executable = true;
    }

    /// Make code writable again
    pub fn makeWritable(self: *MachineCode) !void {
        if (!self.executable) return;

        const PROT_READ: usize = 0x1;
        const PROT_WRITE: usize = 0x2;

        const addr = @intFromPtr(self.code.ptr);
        const len = self.code.len;

        const result = std.os.linux.syscall3(.mprotect, addr, len, PROT_READ | PROT_WRITE);
        if (result != 0) {
            return error.MprotectFailed;
        }

        self.executable = false;
    }

    /// Get function pointer to execute the code
    pub fn getFunction(self: *MachineCode, comptime T: type) T {
        return @ptrCast(self.code.ptr);
    }

    /// Reset for reuse
    pub fn reset(self: *MachineCode) void {
        self.len = 0;
        @memset(self.code, 0xCC);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// X86_64 CODE GENERATION HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const X86_64 = struct {
    /// REX prefix for 64-bit operations
    pub fn rex_w() u8 {
        return 0x48; // REX.W
    }

    /// REX prefix with register extension
    pub fn rex_wr(reg: u8) u8 {
        return 0x48 | ((reg >> 3) & 1); // REX.W + REX.R if reg >= 8
    }

    /// ModR/M byte: mod=11 (register), reg, rm
    pub fn modrm_reg(reg: u8, rm: u8) u8 {
        return 0xC0 | ((reg & 7) << 3) | (rm & 7);
    }

    /// ModR/M byte: mod=00 (memory [rm]), reg
    pub fn modrm_mem(reg: u8, rm: u8) u8 {
        return 0x00 | ((reg & 7) << 3) | (rm & 7);
    }

    /// ModR/M byte: mod=01 (memory [rm + disp8]), reg
    pub fn modrm_mem_disp8(reg: u8, rm: u8) u8 {
        return 0x40 | ((reg & 7) << 3) | (rm & 7);
    }

    /// ModR/M byte: mod=10 (memory [rm + disp32]), reg
    pub fn modrm_mem_disp32(reg: u8, rm: u8) u8 {
        return 0x80 | ((reg & 7) << 3) | (rm & 7);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const JitCompiler = struct {
    code: MachineCode,
    allocator: std.mem.Allocator,
    stack_offset: i32, // Current stack offset for locals

    pub fn init(allocator: std.mem.Allocator) !JitCompiler {
        return JitCompiler{
            .code = try MachineCode.init(allocator, JIT_CODE_SIZE),
            .allocator = allocator,
            .stack_offset = 0,
        };
    }

    pub fn deinit(self: *JitCompiler) void {
        self.code.deinit();
    }

    /// Compile TIR bytecode to native x86_64
    pub fn compile(self: *JitCompiler, tir: []const u8) !void {
        self.code.reset();
        self.stack_offset = 0;

        // Function prologue
        self.emitPrologue();

        // Compile TIR instructions
        var pc: usize = 0;
        while (pc < tir.len) {
            const opcode = tir[pc];
            pc += 1;

            if (opcode == @intFromEnum(TritOpcode.T_CONST)) {
                // Push constant onto stack
                if (pc + 4 > tir.len) break;
                const value = std.mem.readInt(i32, tir[pc..][0..4], .little);
                pc += 4;
                self.emitPushConst(value);
            } else if (opcode == @intFromEnum(TritOpcode.T_ADD)) {
                self.emitAdd();
            } else if (opcode == @intFromEnum(TritOpcode.T_SUB)) {
                self.emitSub();
            } else if (opcode == @intFromEnum(TritOpcode.T_MUL)) {
                self.emitMul();
            } else if (opcode == @intFromEnum(TritOpcode.T_DIV)) {
                self.emitDiv();
            } else if (opcode == @intFromEnum(TritOpcode.T_RET)) {
                self.emitReturn();
                break;
            } else if (opcode == @intFromEnum(TritOpcode.T_LOAD)) {
                if (pc + 4 > tir.len) break;
                const idx = std.mem.readInt(u32, tir[pc..][0..4], .little);
                pc += 4;
                self.emitLoad(idx);
            } else if (opcode == @intFromEnum(TritOpcode.T_STORE)) {
                if (pc + 4 > tir.len) break;
                const idx = std.mem.readInt(u32, tir[pc..][0..4], .little);
                pc += 4;
                self.emitStore(idx);
            } else if (opcode == @intFromEnum(TritOpcode.T_NOP)) {
                // NOP - do nothing
            } else if (opcode == @intFromEnum(TritOpcode.T_HALT)) {
                self.emitReturn();
                break;
            }
        }

        // Make executable
        try self.code.makeExecutable();
    }

    /// Emit function prologue
    fn emitPrologue(self: *JitCompiler) void {
        // push rbp
        self.code.emit(0x55);
        // mov rbp, rsp
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0xE5 });
        // sub rsp, 256 (reserve space for locals)
        self.code.emitBytes(&[_]u8{ 0x48, 0x81, 0xEC });
        self.code.emitImm32(256);
        // Save first argument (rdi) to local 0
        // mov [rbp-8], rdi
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0x7D, 0xF8 });
    }

    /// Emit function epilogue and return
    fn emitReturn(self: *JitCompiler) void {
        // Pop result into rax
        self.emitPopRax();
        // mov rsp, rbp
        self.code.emitBytes(&[_]u8{ 0x48, 0x89, 0xEC });
        // pop rbp
        self.code.emit(0x5D);
        // ret
        self.code.emit(0xC3);
    }

    /// Push constant onto evaluation stack (using rax)
    fn emitPushConst(self: *JitCompiler, value: i32) void {
        // mov eax, imm32
        self.code.emit(0xB8);
        self.code.emitImm32(value);
        // push rax
        self.code.emit(0x50);
        self.stack_offset += 8;
    }

    /// Pop into rax
    fn emitPopRax(self: *JitCompiler) void {
        // pop rax
        self.code.emit(0x58);
        self.stack_offset -= 8;
    }

    /// Pop into rcx
    fn emitPopRcx(self: *JitCompiler) void {
        // pop rcx
        self.code.emit(0x59);
        self.stack_offset -= 8;
    }

    /// Push rax
    fn emitPushRax(self: *JitCompiler) void {
        // push rax
        self.code.emit(0x50);
        self.stack_offset += 8;
    }

    /// Add: pop two, push result
    fn emitAdd(self: *JitCompiler) void {
        // pop rcx (second operand)
        self.emitPopRcx();
        // pop rax (first operand)
        self.emitPopRax();
        // add eax, ecx
        self.code.emitBytes(&[_]u8{ 0x01, 0xC8 });
        // push rax
        self.emitPushRax();
    }

    /// Sub: pop two, push result
    fn emitSub(self: *JitCompiler) void {
        // pop rcx (second operand)
        self.emitPopRcx();
        // pop rax (first operand)
        self.emitPopRax();
        // sub eax, ecx
        self.code.emitBytes(&[_]u8{ 0x29, 0xC8 });
        // push rax
        self.emitPushRax();
    }

    /// Mul: pop two, push result
    fn emitMul(self: *JitCompiler) void {
        // pop rcx (second operand)
        self.emitPopRcx();
        // pop rax (first operand)
        self.emitPopRax();
        // imul eax, ecx
        self.code.emitBytes(&[_]u8{ 0x0F, 0xAF, 0xC1 });
        // push rax
        self.emitPushRax();
    }

    /// Div: pop two, push result
    fn emitDiv(self: *JitCompiler) void {
        // pop rcx (divisor)
        self.emitPopRcx();
        // pop rax (dividend)
        self.emitPopRax();
        // cdq (sign-extend eax into edx:eax)
        self.code.emit(0x99);
        // idiv ecx
        self.code.emitBytes(&[_]u8{ 0xF7, 0xF9 });
        // push rax (quotient)
        self.emitPushRax();
    }

    /// Load local variable onto stack
    fn emitLoad(self: *JitCompiler, idx: u32) void {
        // mov eax, [rbp - 8 - idx*8]
        const offset: i8 = @intCast(-8 - @as(i32, @intCast(idx)) * 8);
        self.code.emitBytes(&[_]u8{ 0x8B, 0x45 });
        self.code.emit(@bitCast(offset));
        // push rax
        self.emitPushRax();
    }

    /// Store top of stack to local variable
    fn emitStore(self: *JitCompiler, idx: u32) void {
        // pop rax
        self.emitPopRax();
        // mov [rbp - 8 - idx*8], eax
        const offset: i8 = @intCast(-8 - @as(i32, @intCast(idx)) * 8);
        self.code.emitBytes(&[_]u8{ 0x89, 0x45 });
        self.code.emit(@bitCast(offset));
    }

    /// Execute compiled code with argument
    pub fn execute(self: *JitCompiler, arg: i32) i32 {
        const func = self.code.getFunction(*const fn (i32) callconv(.C) i32);
        return func(arg);
    }

    /// Execute compiled code without arguments
    pub fn executeNoArgs(self: *JitCompiler) i32 {
        const func = self.code.getFunction(*const fn () callconv(.C) i32);
        return func();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JIT compile constant" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 42, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x2A, 0x00, 0x00, 0x00, // push 42
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile add" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 10, push 32, add, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x0A, 0x00, 0x00, 0x00, // push 10
        @intFromEnum(TritOpcode.T_CONST), 0x20, 0x00, 0x00, 0x00, // push 32
        @intFromEnum(TritOpcode.T_ADD),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile sub" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 50, push 8, sub, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x32, 0x00, 0x00, 0x00, // push 50
        @intFromEnum(TritOpcode.T_CONST), 0x08, 0x00, 0x00, 0x00, // push 8
        @intFromEnum(TritOpcode.T_SUB),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile mul" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 6, push 7, mul, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x06, 0x00, 0x00, 0x00, // push 6
        @intFromEnum(TritOpcode.T_CONST), 0x07, 0x00, 0x00, 0x00, // push 7
        @intFromEnum(TritOpcode.T_MUL),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile div" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: push 84, push 2, div, ret
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x54, 0x00, 0x00, 0x00, // push 84
        @intFromEnum(TritOpcode.T_CONST), 0x02, 0x00, 0x00, 0x00, // push 2
        @intFromEnum(TritOpcode.T_DIV),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile complex expression" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: (10 + 5) * 3 - 3 = 42
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_CONST), 0x0A, 0x00, 0x00, 0x00, // push 10
        @intFromEnum(TritOpcode.T_CONST), 0x05, 0x00, 0x00, 0x00, // push 5
        @intFromEnum(TritOpcode.T_ADD), // 15
        @intFromEnum(TritOpcode.T_CONST), 0x03, 0x00, 0x00, 0x00, // push 3
        @intFromEnum(TritOpcode.T_MUL), // 45
        @intFromEnum(TritOpcode.T_CONST), 0x03, 0x00, 0x00, 0x00, // push 3
        @intFromEnum(TritOpcode.T_SUB), // 42
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.executeNoArgs();
    try std.testing.expectEqual(@as(i32, 42), result);
}

test "JIT compile load/store" {
    var jit = try JitCompiler.init(std.testing.allocator);
    defer jit.deinit();

    // TIR: load arg0, push 2, mul, ret (double the argument)
    const tir = [_]u8{
        @intFromEnum(TritOpcode.T_LOAD), 0x00, 0x00, 0x00, 0x00, // load local 0 (arg)
        @intFromEnum(TritOpcode.T_CONST), 0x02, 0x00, 0x00, 0x00, // push 2
        @intFromEnum(TritOpcode.T_MUL),
        @intFromEnum(TritOpcode.T_RET),
    };

    try jit.compile(&tir);
    const result = jit.execute(21);
    try std.testing.expectEqual(@as(i32, 42), result);
}
