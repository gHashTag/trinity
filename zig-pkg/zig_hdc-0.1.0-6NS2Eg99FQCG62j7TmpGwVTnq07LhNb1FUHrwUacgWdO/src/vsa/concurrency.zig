//! Re-export. The implementation lives in gHashTag/zig-golden-float.
//!
//! This file used to be a second copy of that one. Both repositories carried
//! src/vsa/concurrency.zig, they were edited independently, and they diverged -- which is
//! why repairing sixteen defects in golden-float (#97) left every one of them
//! standing here. Two maintained copies of the same code is how that happens,
//! and it happens quietly, because nothing reports it.
//!
//! The names are listed one by one because `usingnamespace` was removed in Zig
//! 0.15, which is the version this package targets. That is a cost: a name added
//! there does not appear here until it is added here too. It is still cheaper
//! than a second implementation, and unlike a second implementation it fails
//! loudly -- the name is simply missing rather than quietly different.
const upstream = @import("zig_golden_float").vsa_concurrency;

pub const POOL_SIZE = upstream.POOL_SIZE;
pub const DEQUE_CAPACITY = upstream.DEQUE_CAPACITY;
pub const MAX_WORKERS = upstream.MAX_WORKERS;
pub const PRIORITY_LEVELS = upstream.PRIORITY_LEVELS;
pub const PRIORITY_QUEUE_CAPACITY = upstream.PRIORITY_QUEUE_CAPACITY;
pub const MAX_JOB_AGE = upstream.MAX_JOB_AGE;
pub const MAX_DAG_NODES = upstream.MAX_DAG_NODES;
pub const MAX_DEPENDENCIES = upstream.MAX_DEPENDENCIES;
pub const PHI_INVERSE = upstream.PHI_INVERSE;
pub const JobFn = upstream.JobFn;
pub const PoolJob = upstream.PoolJob;
pub const PriorityLevel = upstream.PriorityLevel;
pub const JobPriority = upstream.JobPriority;
pub const TaskState = upstream.TaskState;
pub const TaskNode = upstream.TaskNode;
pub const DAGStats = upstream.DAGStats;
pub const ChaseLevDeque = upstream.ChaseLevDeque;
pub const ThreadPool = upstream.ThreadPool;
pub const DependencyGraph = upstream.DependencyGraph;
pub const getGlobalPool = upstream.getGlobalPool;
pub const getDAG = upstream.getDAG;
pub const shutdownDAG = upstream.shutdownDAG;
pub const hasDAG = upstream.hasDAG;
