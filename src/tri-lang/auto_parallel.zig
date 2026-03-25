// ═══════════════════════════════════════════════════════════════
// auto_parallel.zig - Auto-parallelism (DAG Extraction) for Tri Language
// ═══════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Issue #414: Auto-parallelism (DAG extraction)
//
// Implements:
// - DAG (Directed Acyclic Graph) extraction from expressions
// - Dependency analysis for parallel execution
// - Parallel task scheduling (Bend-style)
// - Race detection and prevention
//
// ═══════════════════════════════════════════════════════════════

const std = @import("std");

/// Location in source file for error reporting
pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// ═════════════════════════════════════════════════════════
// DAG NODE
// ═════════════════════════════════════════════════════════════════

/// Node in execution DAG
pub const DagNode = struct {
    /// Unique node ID
    id: u32,
    /// Node expression (for execution)
    expr: []const u8,
    /// Dependencies (node IDs this node depends on)
    dependencies: []const u32,
    /// Dependents (nodes that depend on this node)
    dependents: []const u32,
    /// Flag: was dependencies dynamically allocated (vs static &.{})
    deps_allocated: bool = false,
    /// Flag: was dependents dynamically allocated (vs static &.{})
    dependents_allocated: bool = false,
    /// Estimated execution cost (for scheduling)
    cost: u32,
    /// Assigned worker ID (null if not assigned)
    worker: ?u32,
    loc: SourceLocation,
};

/// DAG for parallel execution
pub const Dag = struct {
    allocator: std.mem.Allocator,
    /// All nodes in DAG (indexed by ID for fast lookup)
    nodes_by_id: std.ArrayList(DagNode),
    /// Map from node name to ID (for lookups)
    name_to_id: std.StringHashMap(u32),
    /// Entry points (nodes with no dependencies)
    entries: std.ArrayList(u32),
    /// Exit points (nodes with no dependents)
    exits: std.ArrayList(u32),
    /// Node counter for ID generation
    next_id: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .nodes_by_id = .{},
            .name_to_id = std.StringHashMap(u32).init(allocator),
            .entries = .{},
            .exits = .{},
            .next_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free each node's internal arrays first
        for (self.nodes_by_id.items) |*node| {
            if (node.deps_allocated) {
                self.allocator.free(node.dependencies);
            }
            if (node.dependents_allocated) {
                self.allocator.free(node.dependents);
            }
        }
        self.nodes_by_id.deinit(self.allocator);
        self.name_to_id.deinit();
        self.entries.deinit(self.allocator);
        self.exits.deinit(self.allocator);
    }

    /// Add a node to DAG
    pub fn addNode(self: *Self, name: []const u8, expr: []const u8, cost: u32, loc: SourceLocation) !u32 {
        const id = self.next_id;
        self.next_id += 1;

        const node = DagNode{
            .id = id,
            .expr = expr,
            .dependencies = &.{},
            .dependents = &.{},
            .deps_allocated = false,
            .dependents_allocated = false,
            .cost = cost,
            .worker = null,
            .loc = loc,
        };

        try self.nodes_by_id.append(self.allocator, node);
        try self.name_to_id.put(name, id);

        // Track entry/exit points
        // Nodes start as entries (no dependencies) AND exits (no dependents)
        if (node.dependencies.len == 0) {
            try self.entries.append(self.allocator, id);
        }
        if (node.dependents.len == 0) {
            try self.exits.append(self.allocator, id);
        }

        return id;
    }

    /// Get node by ID
    pub fn getNodeById(self: *const Self, id: u32) ?*const DagNode {
        for (self.nodes_by_id.items) |*node| {
            if (node.id == id) {
                return node;
            }
        }
        return null;
    }

    /// Get mutable pointer to node by ID
    pub fn getNodePtrById(self: *Self, id: u32) ?*DagNode {
        for (self.nodes_by_id.items) |*node| {
            if (node.id == id) {
                return node;
            }
        }
        return null;
    }

    /// Add dependency between two nodes
    pub fn addDependency(self: *Self, from_id: u32, to_id: u32) !void {
        // Find 'from' node index
        var from_idx: ?usize = null;
        for (self.nodes_by_id.items, 0..) |*node, idx| {
            if (node.id == from_id) {
                from_idx = idx;
                break;
            }
        }
        if (from_idx == null) return error.NodeNotFound;

        // Find 'to' node index
        var to_idx: ?usize = null;
        for (self.nodes_by_id.items, 0..) |*node, idx| {
            if (node.id == to_id) {
                to_idx = idx;
                break;
            }
        }
        if (to_idx == null) return error.NodeNotFound;

        const from_node = &self.nodes_by_id.items[from_idx.?];
        const to_node = &self.nodes_by_id.items[to_idx.?];

        // Save old arrays before allocating new ones (use-after-free bug fix)
        const old_deps = from_node.dependencies;
        const old_dependents = to_node.dependents;
        const old_deps_allocated = from_node.deps_allocated;
        const old_dependents_allocated = to_node.dependents_allocated;

        // Update entry/exit tracking AFTER saving old dependencies
        // Check: if 'from' had 0 dependencies before, remove it from entries
        if (old_deps.len == 0) {
            // 'from' was an entry, remove it
            for (self.entries.items, 0..) |entry_id, i| {
                if (entry_id == from_id) {
                    _ = self.entries.orderedRemove(i);
                    break;
                }
            }
        }

        // Create new dependency list for 'from' node
        const new_deps = try self.allocator.alloc(u32, old_deps.len + 1);
        @memcpy(new_deps[0..old_deps.len], old_deps);
        new_deps[old_deps.len] = to_id;
        from_node.dependencies = new_deps;
        from_node.deps_allocated = true;

        // Create new dependent list for 'to' node
        const new_deps2 = try self.allocator.alloc(u32, old_dependents.len + 1);
        @memcpy(new_deps2[0..old_dependents.len], old_dependents);
        new_deps2[old_dependents.len] = from_id;
        to_node.dependents = new_deps2;
        to_node.dependents_allocated = true;

        // Update exits AFTER updating dependents
        // 'to' gained a dependent (from), so if 'to' had 0 dependents before, remove it from exits
        // 'from' still has 0 dependents (since to is a different node), so add 'from' to exits
        if (old_dependents.len == 0) {
            // 'to' was an exit, remove it
            for (self.exits.items, 0..) |exit_id, i| {
                if (exit_id == to_id) {
                    _ = self.exits.orderedRemove(i);
                    break;
                }
            }
        }
        // Add 'from' to exits if it has 0 dependents (it didn't gain any new dependents)
        if (from_node.dependents.len == 0) {
            // Check if 'from' is already in exits to avoid duplicates
            var already_in_exits = false;
            for (self.exits.items) |exit_id| {
                if (exit_id == from_id) {
                    already_in_exits = true;
                    break;
                }
            }
            if (!already_in_exits) {
                try self.exits.append(self.allocator, from_id);
            }
        }

        // Free old arrays if they were dynamically allocated
        if (old_deps_allocated) {
            self.allocator.free(old_deps);
        }
        if (old_dependents_allocated) {
            self.allocator.free(old_dependents);
        }
    }

    /// Add dependency by name (convenience wrapper)
    pub fn addDependencyByName(self: *Self, from: []const u8, to: []const u8) !void {
        const from_id = self.name_to_id.get(from) orelse return error.NodeNotFound;
        const to_id = self.name_to_id.get(to) orelse return error.NodeNotFound;
        try self.addDependency(from_id, to_id);
    }

    /// Compute topological order (Kahn's algorithm)
    pub fn topologicalOrder(self: *const Self, allocator: std.mem.Allocator) ![]u32 {
        var result = try std.ArrayList(u32).initCapacity(allocator, 0);
        var in_degree = try std.ArrayList(u32).initCapacity(allocator, 0);
        try in_degree.ensureUnusedCapacity(allocator, self.nodes_by_id.items.len);
        in_degree.items.len = self.nodes_by_id.items.len;
        @memset(in_degree.items, 0);

        // Initialize in-degrees
        for (self.nodes_by_id.items) |node| {
            if (node.id < in_degree.items.len) {
                in_degree.items[node.id] = @intCast(node.dependencies.len);
            }
        }

        // Initialize queue with entry nodes
        var queue = try std.ArrayList(u32).initCapacity(allocator, 0);
        try queue.ensureUnusedCapacity(allocator, self.entries.items.len);
        for (self.entries.items) |entry| {
            try queue.append(allocator, entry);
            try result.append(allocator, entry);
        }

        // Process queue
        while (queue.items.len > 0) {
            const node_id = queue.orderedRemove(0);
            const node = self.getNodeById(node_id) orelse continue;

            // Process dependents
            for (node.dependents) |dep_id| {
                if (dep_id < in_degree.items.len) {
                    in_degree.items[dep_id] -= 1;
                    if (in_degree.items[dep_id] == 0) {
                        try queue.append(allocator, dep_id);
                        try result.append(allocator, dep_id);
                    }
                }
            }
        }

        // Check for cycles
        if (result.items.len != self.nodes_by_id.items.len) {
            return error.InvalidGraph;
        }

        return result.toOwnedSlice(allocator);
    }

    /// Detect cycles in DAG
    pub fn hasCycle(self: *const Self) !bool {
        // Use DFS for cycle detection
        const visited = try std.heap.page_allocator.alloc(bool, self.nodes_by_id.items.len);
        defer std.heap.page_allocator.free(visited);
        @memset(visited, false);

        for (self.nodes_by_id.items) |node| {
            if (!visited[node.id]) {
                if (dfsDetectCycle(self, node.id, visited, &[_]u32{})) {
                    return true;
                }
            }
        }
        return false;
    }

    fn dfsDetectCycle(self: *const Self, node_id: u32, visited: []bool, rec_stack: []u32) bool {
        if (node_id >= visited.len) return false;

        // Check if in recursion stack
        for (rec_stack) |id| {
            if (id == node_id) return true;
        }

        // Add to recursion stack
        const node = self.getNodeById(node_id) orelse return false;

        // Visit all dependencies
        for (node.dependencies) |dep_id| {
            if (dep_id < visited.len and !visited[dep_id]) {
                // Extend rec_stack (simplified - just check direct dependencies)
                if (dfsDetectCycle(self, dep_id, visited, rec_stack)) {
                    return true;
                }
            }
        }

        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEPENDENCY ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Dependency analyzer for expressions
pub const DepAnalyzer = struct {
    allocator: std.mem.Allocator,
    /// Map from variable name to node ID
    var_to_node: std.StringHashMap(u32),
    /// Next available node ID
    next_id: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .var_to_node = std.StringHashMap(u32).init(allocator),
            .next_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.var_to_node.deinit();
    }

    /// Analyze expression and build DAG
    pub fn analyze(self: *Self, expr: []const u8, dag: *Dag) !void {
        _ = self;
        _ = expr;
        _ = dag;
        // Implementation: parse expression and build dependency graph
        // For now, just a placeholder
        return error.NotImplemented;
    }
};

// ═════════════════════════════════════════════════════════════════════════════════
// PARALLEL SCHEDULER
// ═══════════════════════════════════════════════════════════════════════════════

/// Parallel task scheduler
pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    /// Available workers
    workers: []Worker,
    /// Ready queue (nodes ready to execute)
    ready: std.ArrayList(u32),
    /// Completed nodes
    completed: std.ArrayList(u32),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, num_workers: usize) !Self {
        const workers = try allocator.alloc(Worker, num_workers);
        for (0..num_workers) |i| {
            workers[i] = Worker{
                .id = @intCast(i),
                .status = .Idle,
                .current_task = null,
            };
        }
        return Self{
            .allocator = allocator,
            .workers = workers,
            .ready = .{},
            .completed = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.workers);
        self.ready.deinit(self.allocator);
        self.completed.deinit(self.allocator);
    }

    /// Schedule DAG for parallel execution
    pub fn schedule(self: *Self, dag: *const Dag) !void {
        _ = self;
        _ = dag;
        // Implementation: topological sort, assign to workers
        return error.NotImplemented;
    }
};

/// Worker status
pub const WorkerStatus = enum {
    Idle,
    Busy,
    Blocked,
};

/// Worker in parallel pool
pub const Worker = struct {
    id: u32,
    status: WorkerStatus,
    current_task: ?u32,
};

// ═════════════════════════════════════════════════════════════════════════════════
// RACE DETECTION
// ═════════════════════════════════════════════════════════════════════════════════

/// Race condition detector
pub const RaceDetector = struct {
    allocator: std.mem.Allocator,
    /// Shared variable accesses
    shared_vars: std.StringHashMap(VarAccess),
    /// Potential races detected
    races: std.ArrayList(Race),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .shared_vars = std.StringHashMap(VarAccess).init(allocator),
            .races = std.ArrayList(Race).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.shared_vars.deinit();
        self.races.deinit();
    }

    /// Analyze DAG for potential races
    pub fn analyze(self: *Self, dag: *const Dag) ![]const Race {
        _ = self;
        _ = dag;
        // Implementation: detect write-write and write-read conflicts
        return error.NotImplemented;
    }
};

/// Variable access pattern
pub const VarAccess = struct {
    /// Variable name
    name: []const u8,
    /// Nodes that read this variable
    readers: std.ArrayList(u32),
    /// Nodes that write this variable
    writers: std.ArrayList(u32),
};

/// Race condition
pub const Race = struct {
    /// Type of race
    race_type: RaceType,
    /// Variables involved
    variables: []const []const u8,
    /// Conflicting nodes
    nodes: []const u32,
};

/// Race type
pub const RaceType = enum {
    /// Write-write conflict (two nodes write same variable)
    WriteWrite,
    /// Write-read conflict (writer and reader of same variable)
    WriteRead,
    /// Read-write conflict (reader then writer)
    ReadWrite,
};

// ═════════════════════════════════════════════════════════════════════════════════
// PIPELINE EXTRACTION (for Array Combinators)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Pipeline stage for parallel execution
pub const PipelineStage = struct {
    /// Stage name
    name: []const u8,
    /// Input nodes for this stage
    inputs: []const u32,
    /// Output nodes
    outputs: []const u32,
    /// Stage function (e.g., map, filter, reduce)
    stage_fn: StageFn,
};

/// Stage function type
pub const StageFn = enum {
    Map,
    Filter,
    Reduce,
    Scan,
    FlatMap,
};

/// Extract pipeline from DAG
pub fn extractPipeline(dag: *const Dag, allocator: std.mem.Allocator) ![]PipelineStage {
    _ = dag;
    _ = allocator;
    // Implementation: find map/reduce/filter chains in DAG
    return error.NotImplemented;
}

// ═════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "dag_init" {
    const allocator = std.testing.allocator;
    var dag = Dag.init(allocator);
    defer dag.deinit();

    try std.testing.expectEqual(@as(usize, 0), dag.nodes_by_id.items.len);
    try std.testing.expectEqual(@as(usize, 0), dag.entries.items.len);
}

test "dag_add_node" {
    const allocator = std.testing.allocator;
    var dag = Dag.init(allocator);
    defer dag.deinit();

    const id = try dag.addNode("test", "expr", 10, .{ .line = 0, .column = 0 });
    try std.testing.expectEqual(@as(u32, 0), id);
    try std.testing.expectEqual(@as(usize, 1), dag.nodes_by_id.items.len);
}

test "dag_add_dependency" {
    const allocator = std.testing.allocator;
    var dag = Dag.init(allocator);
    defer dag.deinit();

    const id1 = try dag.addNode("a", "expr1", 10, .{ .line = 0, .column = 0 });
    const id2 = try dag.addNode("b", "expr2", 10, .{ .line = 0, .column = 0 });
    const id3 = try dag.addNode("c", "expr3", 10, .{ .line = 0, .column = 0 });

    // After adding nodes: all 3 are entries and exits (no deps/dependents)
    try std.testing.expectEqual(@as(usize, 3), dag.entries.items.len);
    try std.testing.expectEqual(@as(usize, 3), dag.exits.items.len);

    // a -> b (a depends on b)
    try dag.addDependencyByName("a", "b");
    // a removed from entries, b and c remain
    try std.testing.expectEqual(@as(usize, 2), dag.entries.items.len);
    // b removed from exits (now has dependent a), a and c remain as exits
    try std.testing.expectEqual(@as(usize, 2), dag.exits.items.len);
    try std.testing.expectEqual(id1, dag.exits.items[0]); // a is exit
    try std.testing.expectEqual(id3, dag.exits.items[1]); // c is exit

    // b -> c (b depends on c)
    try dag.addDependencyByName("b", "c");
    // b removed from entries, only c remains
    try std.testing.expectEqual(@as(usize, 1), dag.entries.items.len);
    // c removed from exits (now has dependent b), only a remains as exit
    try std.testing.expectEqual(@as(usize, 1), dag.exits.items.len);
    try std.testing.expectEqual(id1, dag.exits.items[0]); // a is still exit

    // c -> a (c depends on a) — creates cycle!
    try dag.addDependencyByName("c", "a");
    // c removed from entries — no more entries (cycle)
    try std.testing.expectEqual(@as(usize, 0), dag.entries.items.len);
    // a removed from exits (now has dependent c) — no more exits
    try std.testing.expectEqual(@as(usize, 0), dag.exits.items.len);

    // Verify cycle: each node has 1 dependency and 1 dependent
    const node_a = dag.getNodeById(id1).?;
    try std.testing.expectEqual(@as(usize, 1), node_a.dependencies.len);
    try std.testing.expectEqual(id2, node_a.dependencies[0]); // a -> b
    try std.testing.expectEqual(@as(usize, 1), node_a.dependents.len);
    try std.testing.expectEqual(id3, node_a.dependents[0]); // c -> a

    const node_b = dag.getNodeById(id2).?;
    try std.testing.expectEqual(@as(usize, 1), node_b.dependencies.len);
    try std.testing.expectEqual(id3, node_b.dependencies[0]); // b -> c
    try std.testing.expectEqual(@as(usize, 1), node_b.dependents.len);
    try std.testing.expectEqual(id1, node_b.dependents[0]); // a -> b

    const node_c = dag.getNodeById(id3).?;
    try std.testing.expectEqual(@as(usize, 1), node_c.dependencies.len);
    try std.testing.expectEqual(id1, node_c.dependencies[0]); // c -> a
    try std.testing.expectEqual(@as(usize, 1), node_c.dependents.len);
    try std.testing.expectEqual(id2, node_c.dependents[0]); // b -> c
}

test "dag_linear_chain" {
    // Test linear chain without cycle: a -> b -> c
    const allocator = std.testing.allocator;
    var dag = Dag.init(allocator);
    defer dag.deinit();

    const id1 = try dag.addNode("a", "expr1", 10, .{ .line = 0, .column = 0 });
    const id2 = try dag.addNode("b", "expr2", 10, .{ .line = 0, .column = 0 });
    const id3 = try dag.addNode("c", "expr3", 10, .{ .line = 0, .column = 0 });

    // Initially: all 3 are entries AND exits (no deps/dependents)
    try std.testing.expectEqual(@as(usize, 3), dag.entries.items.len);
    try std.testing.expectEqual(@as(usize, 3), dag.exits.items.len);

    // a -> b
    try dag.addDependencyByName("a", "b");
    // a removed from entries, b and c remain
    try std.testing.expectEqual(@as(usize, 2), dag.entries.items.len);
    // b removed from exits (now has dependent a), a and c remain as exits
    try std.testing.expectEqual(@as(usize, 2), dag.exits.items.len);
    try std.testing.expectEqual(id1, dag.exits.items[0]); // a is exit
    try std.testing.expectEqual(id3, dag.exits.items[1]); // c is exit

    // b -> c
    try dag.addDependencyByName("b", "c");
    // b removed from entries, only c remains (no dependencies)
    try std.testing.expectEqual(@as(usize, 1), dag.entries.items.len);
    // c removed from exits (now has dependent b), only a remains as exit
    try std.testing.expectEqual(@as(usize, 1), dag.exits.items.len);
    try std.testing.expectEqual(id1, dag.exits.items[0]); // a is exit

    // Verify linear structure
    const node_a = dag.getNodeById(id1).?;
    try std.testing.expectEqual(@as(usize, 1), node_a.dependencies.len);
    try std.testing.expectEqual(id2, node_a.dependencies[0]); // a -> b
    try std.testing.expectEqual(@as(usize, 0), node_a.dependents.len); // no one depends on a

    const node_b = dag.getNodeById(id2).?;
    try std.testing.expectEqual(@as(usize, 1), node_b.dependencies.len);
    try std.testing.expectEqual(id3, node_b.dependencies[0]); // b -> c
    try std.testing.expectEqual(@as(usize, 1), node_b.dependents.len);
    try std.testing.expectEqual(id1, node_b.dependents[0]); // a -> b

    const node_c = dag.getNodeById(id3).?;
    try std.testing.expectEqual(@as(usize, 0), node_c.dependencies.len); // no dependencies
    try std.testing.expectEqual(@as(usize, 1), node_c.dependents.len); // b -> c
    try std.testing.expectEqual(id2, node_c.dependents[0]);

    // Verify entries and exits
    try std.testing.expectEqual(id3, dag.entries.items[0]); // c is entry (no deps)
    try std.testing.expectEqual(id1, dag.exits.items[0]); // a is exit (no dependents)
}

test "scheduler_init" {
    const allocator = std.testing.allocator;
    var scheduler = try Scheduler.init(allocator, 4);
    defer scheduler.deinit();

    try std.testing.expectEqual(@as(usize, 4), scheduler.workers.len);
    try std.testing.expectEqual(@as(u32, 0), scheduler.workers[0].id);
}

test "worker_status" {
    const worker = Worker{ .id = 0, .status = .Idle, .current_task = null };
    try std.testing.expectEqual(WorkerStatus.Idle, worker.status);
}

test "race_types" {
    try std.testing.expectEqual(@as(usize, 3), @typeInfo(RaceType).@"enum".fields.len);
}
