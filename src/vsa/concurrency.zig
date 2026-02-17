// 🤖 TRINITY v0.11.0: Suborbital Order
// Concurrency and Parallel Processing layer for VSA
const std = @import("std");
const common = @import("common.zig");
const HybridBigInt = common.HybridBigInt;

// CONSTANTS
pub const POOL_SIZE = 4;
pub const DEQUE_CAPACITY = 128;
pub const MAX_WORKERS = 8;
pub const PRIORITY_LEVELS = 5;
pub const PRIORITY_QUEUE_CAPACITY = 256;
pub const MAX_JOB_AGE = 100;
pub const MAX_DAG_NODES = 256;
pub const MAX_DEPENDENCIES = 16;
pub const PHI_INVERSE: f64 = 0.618033988749895;

// TYPES
pub const JobFn = *const fn (context: *anyopaque) void;
pub const PoolJob = struct { func: JobFn, context: *anyopaque };
pub const PriorityLevel = enum(u8) { critical = 0, high = 1, normal = 2, low = 3, background = 4 };
pub const JobPriority = PriorityLevel;
pub const TaskState = enum(u8) { pending = 0, ready = 1, running = 2, completed = 3, failed = 4 };

pub const TaskNode = struct {
    id: u32,
    func: JobFn,
    context: *anyopaque,
    dependencies: [MAX_DEPENDENCIES]u32,
    dep_count: usize,
    dependents: [MAX_DEPENDENCIES]u32,
    dependent_count: usize,
    state: TaskState,
    priority: JobPriority,
    deadline: ?i64,
    wait_count: std.atomic.Value(usize),

    pub fn init(id: u32, func: JobFn, context: *anyopaque) TaskNode {
        return TaskNode{
            .id = id,
            .func = func,
            .context = context,
            .dependencies = undefined,
            .dep_count = 0,
            .dependents = undefined,
            .dependent_count = 0,
            .state = .pending,
            .priority = .normal,
            .deadline = null,
            .wait_count = std.atomic.Value(usize).init(0),
        };
    }
    pub fn addDependency(self: *TaskNode, dep_id: u32) bool {
        if (self.dep_count >= MAX_DEPENDENCIES) return false;
        self.dependencies[self.dep_count] = dep_id;
        self.dep_count += 1;
        _ = self.wait_count.fetchAdd(1, .monotonic);
        return true;
    }
    pub fn addDependent(self: *TaskNode, dep_id: u32) bool {
        if (self.dependent_count >= MAX_DEPENDENCIES) return false;
        self.dependents[self.dependent_count] = dep_id;
        self.dependent_count += 1;
        return true;
    }
    pub fn satisfyDependency(self: *TaskNode) bool {
        const remaining = self.wait_count.fetchSub(1, .release) - 1;
        if (remaining == 0) {
            std.atomic.fence(.acquire);
            self.state = .ready;
            return true;
        }
        return false;
    }
    pub fn getEffectivePriority(self: *const TaskNode) f64 {
        const base = switch (self.priority) {
            .critical => 1.0,
            .high => 0.8,
            .normal => 0.6,
            .low => 0.4,
            .background => 0.2,
        };
        if (self.deadline) |dl| {
            const now = std.time.nanoTimestamp();
            const remaining = dl - now;
            if (remaining < 0) return 2.0;
            const boost = 1.0 / (@as(f64, @floatFromInt(remaining)) / 1e9 + 1.0);
            return base + boost;
        }
        return base;
    }
};

pub const DAGStats = struct {
    total: usize,
    completed: usize,
    failed: usize,
    pending: usize,
    ready: usize,
    completion_rate: f64,
};

// CHASE-LEV DEQUE & WORK-STEALING POOL
pub const ChaseLevDeque = struct {
    jobs: [DEQUE_CAPACITY]PoolJob,
    bottom: usize,
    top: usize,

    pub fn init() ChaseLevDeque {
        return ChaseLevDeque{ .jobs = undefined, .bottom = 0, .top = 0 };
    }
    pub fn push(self: *ChaseLevDeque, job: PoolJob) bool {
        const b = @atomicLoad(usize, &self.bottom, .seq_cst);
        const t = @atomicLoad(usize, &self.top, .seq_cst);
        if (b - t >= DEQUE_CAPACITY) return false;
        self.jobs[b % DEQUE_CAPACITY] = job;
        @atomicStore(usize, &self.bottom, b + 1, .seq_cst);
        return true;
    }
    pub fn pop(self: *ChaseLevDeque) ?PoolJob {
        var b = @atomicLoad(usize, &self.bottom, .seq_cst);
        if (b == 0) return null;
        b -= 1;
        @atomicStore(usize, &self.bottom, b, .seq_cst);
        const t = @atomicLoad(usize, &self.top, .seq_cst);
        if (t <= b) {
            const job = self.jobs[b % DEQUE_CAPACITY];
            if (t == b) {
                const result = @cmpxchgWeak(usize, &self.top, t, t + 1, .seq_cst, .seq_cst);
                if (result == null) {
                    @atomicStore(usize, &self.bottom, t + 1, .seq_cst);
                    return job;
                } else {
                    @atomicStore(usize, &self.bottom, t + 1, .seq_cst);
                    return null;
                }
            }
            return job;
        } else {
            @atomicStore(usize, &self.bottom, t, .seq_cst);
            return null;
        }
    }
    pub fn steal(self: *ChaseLevDeque) ?PoolJob {
        const t = @atomicLoad(usize, &self.top, .seq_cst);
        const b = @atomicLoad(usize, &self.bottom, .seq_cst);
        if (t >= b) return null;
        const job = self.jobs[t % DEQUE_CAPACITY];
        const result = @cmpxchgWeak(usize, &self.top, t, t + 1, .seq_cst, .seq_cst);
        if (result == null) return job;
        return null;
    }
    pub fn size(self: *ChaseLevDeque) usize {
        const b = @atomicLoad(usize, &self.bottom, .seq_cst);
        const t = @atomicLoad(usize, &self.top, .seq_cst);
        return if (b > t) b - t else 0;
    }
    pub fn reset(self: *ChaseLevDeque) void {
        @atomicStore(usize, &self.bottom, 0, .seq_cst);
        @atomicStore(usize, &self.top, 0, .seq_cst);
    }
};

pub const ThreadPool = struct {
    workers: [MAX_WORKERS]ChaseLevDeque,
    count: usize,
    pub fn init() ThreadPool {
        return ThreadPool{ .workers = undefined, .count = 0 };
    }
};

// DEPENDENCY GRAPH (DAG)
pub const DependencyGraph = struct {
    nodes: [MAX_DAG_NODES]?TaskNode,
    node_count: usize,
    ready_queue: [MAX_DAG_NODES]u32,
    ready_count: std.atomic.Value(usize),
    completed_count: usize,
    failed_count: usize,
    execution_order: [MAX_DAG_NODES]u32,
    order_computed: bool,

    const Self = @This();
    pub fn init() Self {
        return Self{
            .nodes = .{null} ** MAX_DAG_NODES,
            .node_count = 0,
            .ready_queue = .{0} ** MAX_DAG_NODES,
            .ready_count = std.atomic.Value(usize).init(0),
            .completed_count = 0,
            .failed_count = 0,
            .execution_order = .{0} ** MAX_DAG_NODES,
            .order_computed = false,
        };
    }
    pub fn addTask(self: *Self, func: JobFn, context: *anyopaque) ?u32 {
        if (self.node_count >= MAX_DAG_NODES) return null;
        const id: u32 = @intCast(self.node_count);
        self.nodes[id] = TaskNode.init(id, func, context);
        self.node_count += 1;
        self.order_computed = false;
        return id;
    }
    pub fn addTaskWithPriority(self: *Self, func: JobFn, context: *anyopaque, priority: JobPriority) ?u32 {
        const id = self.addTask(func, context) orelse return null;
        if (self.nodes[id]) |*node| node.priority = priority;
        return id;
    }
    pub fn addDependency(self: *Self, from_id: u32, to_id: u32) bool {
        if (from_id >= self.node_count or to_id >= self.node_count) return false;
        if (from_id == to_id) return false;
        if (self.nodes[from_id]) |*from_node| {
            if (!from_node.addDependent(to_id)) return false;
        } else return false;
        if (self.nodes[to_id]) |*to_node| {
            if (!to_node.addDependency(from_id)) return false;
        } else return false;
        self.order_computed = false;
        return true;
    }
    pub fn computeTopologicalOrder(self: *Self) bool {
        if (self.order_computed) return true;
        var in_degree: [MAX_DAG_NODES]usize = .{0} ** MAX_DAG_NODES;
        var queue: [MAX_DAG_NODES]u32 = .{0} ** MAX_DAG_NODES;
        var queue_start: usize = 0;
        var queue_end: usize = 0;
        var order_idx: usize = 0;
        for (0..self.node_count) |i| {
            if (self.nodes[i]) |node| {
                in_degree[i] = node.dep_count;
                if (in_degree[i] == 0) {
                    queue[queue_end] = @intCast(i);
                    queue_end += 1;
                }
            }
        }
        while (queue_start < queue_end) {
            const current = queue[queue_start];
            queue_start += 1;
            self.execution_order[order_idx] = current;
            order_idx += 1;
            if (self.nodes[current]) |node| {
                for (0..node.dependent_count) |i| {
                    const dep_id = node.dependents[i];
                    in_degree[dep_id] -= 1;
                    if (in_degree[dep_id] == 0) {
                        queue[queue_end] = dep_id;
                        queue_end += 1;
                    }
                }
            }
        }
        if (order_idx != self.node_count) return false;
        self.order_computed = true;
        return true;
    }
    pub fn executeAll(self: *Self) struct { completed: usize, failed: usize } {
        if (!self.computeTopologicalOrder()) return .{ .completed = 0, .failed = self.node_count };
        var completed: usize = 0;
        for (0..self.node_count) |order_idx| {
            const id = self.execution_order[order_idx];
            if (self.nodes[id]) |node| {
                node.func(node.context);
                completed += 1;
            }
        }
        self.completed_count = completed;
        return .{ .completed = completed, .failed = 0 };
    }
};

var global_pool: ?ThreadPool = null;
pub fn getGlobalPool() *ThreadPool {
    if (global_pool == null) global_pool = ThreadPool.init();
    return &global_pool.?;
}
var global_dag: ?DependencyGraph = null;
pub fn getDAG() *DependencyGraph {
    if (global_dag == null) global_dag = DependencyGraph.init();
    return &global_dag.?;
}
pub fn shutdownDAG() void {
    global_dag = null;
}
pub fn hasDAG() bool {
    return global_dag != null;
}

// φ² + 1/φ² = 3 | TRINITY
