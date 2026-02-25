//! JIT Compilation Pipeline — Multi-Tier Compilation for Ternary VSA Operations
//! Generated from specs/tri/jit_compilation.vibee
//! CORE-004: Tiered JIT (Interpreter -> Baseline -> Optimizing)
//! phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const builtin = @import("builtin");

// ============================================================
// CONSTANTS
// ============================================================

const TIER1_THRESHOLD: u32 = 100;
const TIER2_THRESHOLD: u32 = 10000;
const OSR_THRESHOLD: u32 = 500;
const MAX_FUNCTIONS: usize = 256;
const MAX_QUEUE_SIZE: usize = 64;
const MAX_CODE_CACHE: usize = 128;
const DEOPT_LIMIT: u32 = 3;

// ============================================================
// ENUMS
// ============================================================

pub const CompilationTier = enum(u8) {
    interpreter,
    baseline,
    optimizing,

    pub fn name(self: CompilationTier) []const u8 {
        return switch (self) {
            .interpreter => "interpreter",
            .baseline => "baseline",
            .optimizing => "optimizing",
        };
    }
};

pub const FunctionState = enum(u8) {
    cold,
    warm,
    hot,
    deoptimized,
};

pub const TypeFeedback = enum(u8) {
    unknown,
    monomorphic,
    polymorphic,
    megamorphic,
};

pub const VSAOpKind = enum(u8) {
    bind,
    unbind,
    bundle2,
    bundle3,
    dot,
    cosine,
    hamming,
    permute,
    matvec,

    pub fn name(self: VSAOpKind) []const u8 {
        return switch (self) {
            .bind => "bind",
            .unbind => "unbind",
            .bundle2 => "bundle2",
            .bundle3 => "bundle3",
            .dot => "dot",
            .cosine => "cosine",
            .hamming => "hamming",
            .permute => "permute",
            .matvec => "matvec",
        };
    }
};

// ============================================================
// PROFILING
// ============================================================

pub const FunctionProfile = struct {
    func_id: u32,
    call_count: u32,
    loop_iterations: u32,
    tier: CompilationTier,
    state: FunctionState,
    type_feedback: TypeFeedback,
    deopt_count: u32,
    dimension: u32,
    primary_op: VSAOpKind,

    pub fn init(func_id: u32, dimension: u32, op: VSAOpKind) FunctionProfile {
        return .{
            .func_id = func_id,
            .call_count = 0,
            .loop_iterations = 0,
            .tier = .interpreter,
            .state = .cold,
            .type_feedback = .unknown,
            .deopt_count = 0,
            .dimension = dimension,
            .primary_op = op,
        };
    }

    pub fn recordCall(self: *FunctionProfile) void {
        self.call_count += 1;
        if (self.call_count >= TIER2_THRESHOLD) {
            self.state = .hot;
        } else if (self.call_count >= TIER1_THRESHOLD) {
            self.state = .warm;
        }
    }

    pub fn recordLoopIteration(self: *FunctionProfile) void {
        self.loop_iterations += 1;
    }

    pub fn shouldPromote(self: *const FunctionProfile) bool {
        return switch (self.tier) {
            .interpreter => self.call_count >= TIER1_THRESHOLD,
            .baseline => self.call_count >= TIER2_THRESHOLD,
            .optimizing => false,
        };
    }

    pub fn shouldOSR(self: *const FunctionProfile) bool {
        return self.loop_iterations >= OSR_THRESHOLD and self.tier == .interpreter;
    }

    pub fn nextTier(self: *const FunctionProfile) CompilationTier {
        return switch (self.tier) {
            .interpreter => .baseline,
            .baseline => .optimizing,
            .optimizing => .optimizing,
        };
    }

    pub fn shouldRecompile(self: *const FunctionProfile) bool {
        return self.deopt_count < DEOPT_LIMIT and self.state == .hot;
    }
};

// ============================================================
// COMPILATION QUEUE (priority-based)
// ============================================================

pub const CompilationRequest = struct {
    func_id: u32,
    target_tier: CompilationTier,
    priority: u32,
    dimension: u32,
    op_kind: VSAOpKind,
};

pub const CompilationQueue = struct {
    requests: [MAX_QUEUE_SIZE]CompilationRequest,
    count: usize,

    pub fn init() CompilationQueue {
        return .{
            .requests = undefined,
            .count = 0,
        };
    }

    pub fn enqueue(self: *CompilationQueue, req: CompilationRequest) bool {
        if (self.count >= MAX_QUEUE_SIZE) return false;
        // Insert sorted by priority (highest first)
        var pos: usize = self.count;
        while (pos > 0 and self.requests[pos - 1].priority < req.priority) {
            self.requests[pos] = self.requests[pos - 1];
            pos -= 1;
        }
        self.requests[pos] = req;
        self.count += 1;
        return true;
    }

    pub fn dequeue(self: *CompilationQueue) ?CompilationRequest {
        if (self.count == 0) return null;
        const req = self.requests[0];
        // Shift remaining
        var i: usize = 1;
        while (i < self.count) : (i += 1) {
            self.requests[i - 1] = self.requests[i];
        }
        self.count -= 1;
        return req;
    }

    pub fn isEmpty(self: *const CompilationQueue) bool {
        return self.count == 0;
    }

    pub fn len(self: *const CompilationQueue) usize {
        return self.count;
    }
};

// ============================================================
// COMPILED FUNCTION REGISTRY
// ============================================================

pub const CompiledFunction = struct {
    func_id: u32,
    tier: CompilationTier,
    dimension: u32,
    op_kind: VSAOpKind,
    hit_count: u32,
    // We store computed results for the compiled operation
    // In a real JIT, this would be a function pointer to native code
    // For this implementation, we use the compiled tier to select optimized paths
    is_valid: bool,

    pub fn init(func_id: u32, tier: CompilationTier, dim: u32, op: VSAOpKind) CompiledFunction {
        return .{
            .func_id = func_id,
            .tier = tier,
            .dimension = dim,
            .op_kind = op,
            .hit_count = 0,
            .is_valid = true,
        };
    }

    pub fn recordHit(self: *CompiledFunction) void {
        self.hit_count += 1;
    }

    pub fn invalidate(self: *CompiledFunction) void {
        self.is_valid = false;
    }
};

// ============================================================
// CODE CACHE (LRU eviction)
// ============================================================

pub const CodeCacheStats = struct {
    total_entries: u32,
    cache_hits: u32,
    cache_misses: u32,
    evictions: u32,

    pub fn hitRate(self: *const CodeCacheStats) f32 {
        const total = self.cache_hits + self.cache_misses;
        if (total == 0) return 0.0;
        return @as(f32, @floatFromInt(self.cache_hits)) / @as(f32, @floatFromInt(total));
    }
};

pub const CodeCache = struct {
    entries: [MAX_CODE_CACHE]?CompiledFunction,
    access_order: [MAX_CODE_CACHE]u32, // LRU tracking (timestamp)
    count: usize,
    clock: u32,
    stats: CodeCacheStats,

    pub fn init() CodeCache {
        var cache: CodeCache = undefined;
        for (&cache.entries) |*e| {
            e.* = null;
        }
        @memset(&cache.access_order, 0);
        cache.count = 0;
        cache.clock = 0;
        cache.stats = .{
            .total_entries = 0,
            .cache_hits = 0,
            .cache_misses = 0,
            .evictions = 0,
        };
        return cache;
    }

    pub fn lookup(self: *CodeCache, func_id: u32) ?*CompiledFunction {
        for (&self.entries, 0..) |*entry, i| {
            if (entry.*) |*func| {
                if (func.func_id == func_id and func.is_valid) {
                    self.clock += 1;
                    self.access_order[i] = self.clock;
                    func.recordHit();
                    self.stats.cache_hits += 1;
                    return func;
                }
            }
        }
        self.stats.cache_misses += 1;
        return null;
    }

    pub fn insert(self: *CodeCache, func: CompiledFunction) void {
        // Find empty slot or evict LRU
        var slot: usize = 0;
        var found_empty = false;

        for (self.entries, 0..) |entry, i| {
            if (entry == null) {
                slot = i;
                found_empty = true;
                break;
            }
        }

        if (!found_empty) {
            // Evict LRU
            slot = self.findLRU();
            self.stats.evictions += 1;
        }

        self.entries[slot] = func;
        self.clock += 1;
        self.access_order[slot] = self.clock;
        self.count += 1;
        self.stats.total_entries = @intCast(self.count);
    }

    fn findLRU(self: *const CodeCache) usize {
        var min_time: u32 = std.math.maxInt(u32);
        var min_idx: usize = 0;
        for (self.access_order, 0..) |time, i| {
            if (self.entries[i] != null and time < min_time) {
                min_time = time;
                min_idx = i;
            }
        }
        return min_idx;
    }

    pub fn invalidate(self: *CodeCache, func_id: u32) void {
        for (&self.entries) |*entry| {
            if (entry.*) |*func| {
                if (func.func_id == func_id) {
                    func.invalidate();
                }
            }
        }
    }

    pub fn getStats(self: *const CodeCache) CodeCacheStats {
        return self.stats;
    }
};

// ============================================================
// BASELINE COMPILER — Ternary VSA Operations
// ============================================================

pub const BaselineCompiler = struct {
    compilations: u32,

    pub fn init() BaselineCompiler {
        return .{ .compilations = 0 };
    }

    /// Compile bind: c[i] = clamp(a[i] * b[i], -1, 1)
    pub fn compileBind(self: *BaselineCompiler, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        _ = self;
        for (0..dim) |i| {
            const prod = @as(i16, a[i]) * @as(i16, b[i]);
            output[i] = @as(i8, @intCast(std.math.clamp(prod, -1, 1)));
        }
    }

    /// Compile unbind: same as bind (self-inverse)
    pub fn compileUnbind(self: *BaselineCompiler, output: []i8, bound: []const i8, key: []const i8, dim: usize) void {
        self.compileBind(output, bound, key, dim);
    }

    /// Compile bundle2: c[i] = sign(a[i] + b[i])
    pub fn compileBundle2(self: *BaselineCompiler, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        _ = self;
        for (0..dim) |i| {
            const sum = @as(i16, a[i]) + @as(i16, b[i]);
            output[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else @as(i8, 0);
        }
    }

    /// Compile bundle3: c[i] = majority(a[i], b[i], c_vec[i])
    pub fn compileBundle3(self: *BaselineCompiler, output: []i8, a: []const i8, b: []const i8, c_vec: []const i8, dim: usize) void {
        _ = self;
        for (0..dim) |i| {
            const sum = @as(i16, a[i]) + @as(i16, b[i]) + @as(i16, c_vec[i]);
            output[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else @as(i8, 0);
        }
    }

    /// Compile dot product
    pub fn compileDotProduct(self: *BaselineCompiler, a: []const i8, b: []const i8, dim: usize) i64 {
        _ = self;
        var acc: i64 = 0;
        for (0..dim) |i| {
            acc += @as(i64, a[i]) * @as(i64, b[i]);
        }
        return acc;
    }

    /// Compile cosine similarity
    pub fn compileCosineSimilarity(self: *BaselineCompiler, a: []const i8, b: []const i8, dim: usize) f32 {
        _ = self;
        var dot: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;
        for (0..dim) |i| {
            dot += @as(i64, a[i]) * @as(i64, b[i]);
            norm_a += @as(i64, a[i]) * @as(i64, a[i]);
            norm_b += @as(i64, b[i]) * @as(i64, b[i]);
        }
        const denom = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));
        if (denom == 0.0) return 0.0;
        return @floatCast(@as(f64, @floatFromInt(dot)) / denom);
    }

    /// Compile hamming distance
    pub fn compileHammingDistance(self: *BaselineCompiler, a: []const i8, b: []const i8, dim: usize) u32 {
        _ = self;
        var dist: u32 = 0;
        for (0..dim) |i| {
            if (a[i] != b[i]) dist += 1;
        }
        return dist;
    }

    /// Compile permute (cyclic rotation)
    pub fn compilePermute(self: *BaselineCompiler, output: []i8, input: []const i8, dim: usize, shift: u32) void {
        _ = self;
        for (0..dim) |i| {
            const src_idx = (i + shift) % dim;
            output[i] = input[src_idx];
        }
    }

    /// Compile ternary matrix-vector product (add-only, no multiply for {-1,0,+1})
    pub fn compileTernaryMatVec(self: *BaselineCompiler, output: []f32, matrix: []const i8, vector: []const f32, rows: usize, cols: usize) void {
        _ = self;
        for (0..rows) |r| {
            var acc: f32 = 0.0;
            for (0..cols) |c_idx| {
                const w = matrix[r * cols + c_idx];
                if (w == 1) {
                    acc += vector[c_idx];
                } else if (w == -1) {
                    acc -= vector[c_idx];
                }
                // w == 0: skip (add-only optimization)
            }
            output[r] = acc;
        }
    }

    pub fn recordCompilation(self: *BaselineCompiler) void {
        self.compilations += 1;
    }
};

// ============================================================
// OPTIMIZING COMPILER — Enhanced paths for hot functions
// ============================================================

pub const OptimizingCompiler = struct {
    compilations: u32,

    pub fn init() OptimizingCompiler {
        return .{ .compilations = 0 };
    }

    /// Optimized bind using 4-way unrolling
    pub fn optimizedBind(self: *OptimizingCompiler, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        _ = self;
        // 4-way unrolled loop
        const chunks = dim / 4;
        const remainder = dim % 4;
        var i: usize = 0;
        for (0..chunks) |_| {
            output[i] = @as(i8, @intCast(std.math.clamp(@as(i16, a[i]) * @as(i16, b[i]), -1, 1)));
            output[i + 1] = @as(i8, @intCast(std.math.clamp(@as(i16, a[i + 1]) * @as(i16, b[i + 1]), -1, 1)));
            output[i + 2] = @as(i8, @intCast(std.math.clamp(@as(i16, a[i + 2]) * @as(i16, b[i + 2]), -1, 1)));
            output[i + 3] = @as(i8, @intCast(std.math.clamp(@as(i16, a[i + 3]) * @as(i16, b[i + 3]), -1, 1)));
            i += 4;
        }
        for (0..remainder) |_| {
            output[i] = @as(i8, @intCast(std.math.clamp(@as(i16, a[i]) * @as(i16, b[i]), -1, 1)));
            i += 1;
        }
    }

    /// Optimized cosine similarity: fused dot + norm (single pass)
    pub fn optimizedCosineSimilarity(self: *OptimizingCompiler, a: []const i8, b: []const i8, dim: usize) f32 {
        _ = self;
        var dot: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;
        // Fused: compute all three in one pass (cache-friendly)
        const chunks = dim / 4;
        const remainder = dim % 4;
        var i: usize = 0;
        for (0..chunks) |_| {
            const a0: i64 = a[i];
            const b0: i64 = b[i];
            const a1: i64 = a[i + 1];
            const b1: i64 = b[i + 1];
            const a2: i64 = a[i + 2];
            const b2: i64 = b[i + 2];
            const a3: i64 = a[i + 3];
            const b3: i64 = b[i + 3];
            dot += a0 * b0 + a1 * b1 + a2 * b2 + a3 * b3;
            norm_a += a0 * a0 + a1 * a1 + a2 * a2 + a3 * a3;
            norm_b += b0 * b0 + b1 * b1 + b2 * b2 + b3 * b3;
            i += 4;
        }
        for (0..remainder) |_| {
            const av: i64 = a[i];
            const bv: i64 = b[i];
            dot += av * bv;
            norm_a += av * av;
            norm_b += bv * bv;
            i += 1;
        }
        const denom = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));
        if (denom == 0.0) return 0.0;
        return @floatCast(@as(f64, @floatFromInt(dot)) / denom);
    }

    /// Optimized ternary matvec: branch-free using sign arithmetic
    pub fn optimizedTernaryMatVec(self: *OptimizingCompiler, output: []f32, matrix: []const i8, vector: []const f32, rows: usize, cols: usize) void {
        _ = self;
        for (0..rows) |r| {
            var acc: f32 = 0.0;
            const row_base = r * cols;
            // Unrolled by 4
            const chunks = cols / 4;
            const remainder = cols % 4;
            var c_idx: usize = 0;
            for (0..chunks) |_| {
                // Branch-free: multiply by sign (-1, 0, +1)
                acc += @as(f32, @floatFromInt(matrix[row_base + c_idx])) * vector[c_idx];
                acc += @as(f32, @floatFromInt(matrix[row_base + c_idx + 1])) * vector[c_idx + 1];
                acc += @as(f32, @floatFromInt(matrix[row_base + c_idx + 2])) * vector[c_idx + 2];
                acc += @as(f32, @floatFromInt(matrix[row_base + c_idx + 3])) * vector[c_idx + 3];
                c_idx += 4;
            }
            for (0..remainder) |_| {
                acc += @as(f32, @floatFromInt(matrix[row_base + c_idx])) * vector[c_idx];
                c_idx += 1;
            }
            output[r] = acc;
        }
    }

    pub fn recordCompilation(self: *OptimizingCompiler) void {
        self.compilations += 1;
    }
};

// ============================================================
// JIT CONTROLLER — Unified API
// ============================================================

pub const JitStats = struct {
    functions_compiled: u32,
    tier1_compilations: u32,
    tier2_compilations: u32,
    osr_triggers: u32,
    deoptimizations: u32,
    cache_stats: CodeCacheStats,

    pub fn totalCompilations(self: *const JitStats) u32 {
        return self.tier1_compilations + self.tier2_compilations;
    }
};

pub const JitController = struct {
    profiles: [MAX_FUNCTIONS]?FunctionProfile,
    profile_count: usize,
    queue: CompilationQueue,
    cache: CodeCache,
    baseline: BaselineCompiler,
    optimizing: OptimizingCompiler,
    stats: JitStats,
    next_func_id: u32,

    pub fn init() JitController {
        var ctrl: JitController = undefined;
        for (&ctrl.profiles) |*p| {
            p.* = null;
        }
        ctrl.profile_count = 0;
        ctrl.queue = CompilationQueue.init();
        ctrl.cache = CodeCache.init();
        ctrl.baseline = BaselineCompiler.init();
        ctrl.optimizing = OptimizingCompiler.init();
        ctrl.stats = .{
            .functions_compiled = 0,
            .tier1_compilations = 0,
            .tier2_compilations = 0,
            .osr_triggers = 0,
            .deoptimizations = 0,
            .cache_stats = .{ .total_entries = 0, .cache_hits = 0, .cache_misses = 0, .evictions = 0 },
        };
        ctrl.next_func_id = 0;
        return ctrl;
    }

    /// Register a new function for profiling, returns func_id
    pub fn registerFunction(self: *JitController, dim: u32, op: VSAOpKind) u32 {
        const id = self.next_func_id;
        self.next_func_id += 1;
        if (self.profile_count < MAX_FUNCTIONS) {
            self.profiles[self.profile_count] = FunctionProfile.init(id, dim, op);
            self.profile_count += 1;
        }
        return id;
    }

    /// Record a function call and handle tier promotion
    pub fn recordCall(self: *JitController, func_id: u32) void {
        if (self.findProfile(func_id)) |prof| {
            prof.recordCall();
            if (prof.shouldPromote()) {
                self.promoteFunction(prof);
            }
        }
    }

    /// Record a loop iteration (for OSR)
    pub fn recordLoopIteration(self: *JitController, func_id: u32) void {
        if (self.findProfile(func_id)) |prof| {
            prof.recordLoopIteration();
            if (prof.shouldOSR()) {
                self.triggerOSR(prof);
            }
        }
    }

    /// Execute bind operation through JIT pipeline
    pub fn executeBind(self: *JitController, func_id: u32, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        self.recordCall(func_id);
        const tier = self.getActiveTier(func_id);
        switch (tier) {
            .optimizing => self.optimizing.optimizedBind(output, a, b, dim),
            else => self.baseline.compileBind(output, a, b, dim),
        }
    }

    /// Execute cosine similarity through JIT pipeline
    pub fn executeCosineSimilarity(self: *JitController, func_id: u32, a: []const i8, b: []const i8, dim: usize) f32 {
        self.recordCall(func_id);
        const tier = self.getActiveTier(func_id);
        return switch (tier) {
            .optimizing => self.optimizing.optimizedCosineSimilarity(a, b, dim),
            else => self.baseline.compileCosineSimilarity(a, b, dim),
        };
    }

    /// Execute dot product through JIT pipeline
    pub fn executeDotProduct(self: *JitController, func_id: u32, a: []const i8, b: []const i8, dim: usize) i64 {
        self.recordCall(func_id);
        return self.baseline.compileDotProduct(a, b, dim);
    }

    /// Execute ternary matvec through JIT pipeline
    pub fn executeTernaryMatVec(self: *JitController, func_id: u32, output: []f32, matrix: []const i8, vector: []const f32, rows: usize, cols: usize) void {
        self.recordCall(func_id);
        const tier = self.getActiveTier(func_id);
        switch (tier) {
            .optimizing => self.optimizing.optimizedTernaryMatVec(output, matrix, vector, rows, cols),
            else => self.baseline.compileTernaryMatVec(output, matrix, vector, rows, cols),
        }
    }

    /// Deoptimize a function (speculation failed)
    pub fn deoptimize(self: *JitController, func_id: u32) void {
        if (self.findProfile(func_id)) |prof| {
            prof.deopt_count += 1;
            prof.tier = .interpreter;
            prof.state = .deoptimized;
            self.cache.invalidate(func_id);
            self.stats.deoptimizations += 1;
        }
    }

    /// Get active compilation tier for a function
    pub fn getActiveTier(self: *JitController, func_id: u32) CompilationTier {
        // Check cache first
        if (self.cache.lookup(func_id)) |cached| {
            return cached.tier;
        }
        // Fall back to profile tier
        if (self.findProfile(func_id)) |prof| {
            return prof.tier;
        }
        return .interpreter;
    }

    /// Get JIT statistics
    pub fn getStats(self: *JitController) JitStats {
        var s = self.stats;
        s.cache_stats = self.cache.getStats();
        return s;
    }

    /// Process compilation queue (compile next pending function)
    pub fn processQueue(self: *JitController) bool {
        if (self.queue.dequeue()) |req| {
            self.compileFunction(req);
            return true;
        }
        return false;
    }

    /// Reset all state
    pub fn reset(self: *JitController) void {
        for (&self.profiles) |*p| p.* = null;
        self.profile_count = 0;
        self.queue = CompilationQueue.init();
        self.cache = CodeCache.init();
        self.baseline = BaselineCompiler.init();
        self.optimizing = OptimizingCompiler.init();
        self.stats = .{
            .functions_compiled = 0,
            .tier1_compilations = 0,
            .tier2_compilations = 0,
            .osr_triggers = 0,
            .deoptimizations = 0,
            .cache_stats = .{ .total_entries = 0, .cache_hits = 0, .cache_misses = 0, .evictions = 0 },
        };
        self.next_func_id = 0;
    }

    // --- Internal ---

    fn findProfile(self: *JitController, func_id: u32) ?*FunctionProfile {
        for (self.profiles[0..self.profile_count]) |*maybe_prof| {
            if (maybe_prof.*) |*prof| {
                if (prof.func_id == func_id) return prof;
            }
        }
        return null;
    }

    fn promoteFunction(self: *JitController, prof: *FunctionProfile) void {
        const target = prof.nextTier();
        if (target == prof.tier) return; // Already at max

        const req = CompilationRequest{
            .func_id = prof.func_id,
            .target_tier = target,
            .priority = prof.call_count,
            .dimension = prof.dimension,
            .op_kind = prof.primary_op,
        };
        _ = self.queue.enqueue(req);
    }

    fn triggerOSR(self: *JitController, prof: *FunctionProfile) void {
        prof.tier = .baseline;
        self.stats.osr_triggers += 1;

        const compiled = CompiledFunction.init(
            prof.func_id,
            .baseline,
            prof.dimension,
            prof.primary_op,
        );
        self.cache.insert(compiled);
        self.stats.functions_compiled += 1;
        self.stats.tier1_compilations += 1;
        self.baseline.recordCompilation();
    }

    fn compileFunction(self: *JitController, req: CompilationRequest) void {
        const compiled = CompiledFunction.init(
            req.func_id,
            req.target_tier,
            req.dimension,
            req.op_kind,
        );
        self.cache.insert(compiled);

        // Update profile tier
        if (self.findProfile(req.func_id)) |prof| {
            prof.tier = req.target_tier;
        }

        self.stats.functions_compiled += 1;
        switch (req.target_tier) {
            .baseline => {
                self.stats.tier1_compilations += 1;
                self.baseline.recordCompilation();
            },
            .optimizing => {
                self.stats.tier2_compilations += 1;
                self.optimizing.recordCompilation();
            },
            .interpreter => {},
        }
    }
};

// ============================================================
// SPEEDUP ANALYSIS
// ============================================================

pub const SpeedupAnalysis = struct {
    interpreter_ops_per_sec: f64,
    baseline_ops_per_sec: f64,
    optimizing_ops_per_sec: f64,

    pub fn baselineSpeedup(self: *const SpeedupAnalysis) f64 {
        if (self.interpreter_ops_per_sec == 0) return 0;
        return self.baseline_ops_per_sec / self.interpreter_ops_per_sec;
    }

    pub fn optimizingSpeedup(self: *const SpeedupAnalysis) f64 {
        if (self.interpreter_ops_per_sec == 0) return 0;
        return self.optimizing_ops_per_sec / self.interpreter_ops_per_sec;
    }

    /// Theoretical speedup for ternary operations
    pub fn theoreticalTernarySpeedup() SpeedupAnalysis {
        // Interpreter: ~1 op/cycle (branch + load + compute)
        // Baseline JIT: ~5 ops/cycle (no branch, straight-line code)
        // Optimizing JIT: ~20 ops/cycle (SIMD + unrolling + fusion)
        return .{
            .interpreter_ops_per_sec = 1_000_000, // 1M ops/s baseline
            .baseline_ops_per_sec = 5_000_000, // 5M ops/s (5x)
            .optimizing_ops_per_sec = 20_000_000, // 20M ops/s (20x)
        };
    }
};

// ============================================================
// TESTS
// ============================================================

test "function profile init" {
    const prof = FunctionProfile.init(0, 1024, .bind);
    try std.testing.expectEqual(prof.func_id, 0);
    try std.testing.expectEqual(prof.call_count, 0);
    try std.testing.expectEqual(prof.tier, .interpreter);
    try std.testing.expectEqual(prof.state, .cold);
    try std.testing.expectEqual(prof.dimension, 1024);
}

test "function profile tier promotion thresholds" {
    var prof = FunctionProfile.init(1, 256, .dot);

    // Not yet promotable
    try std.testing.expect(!prof.shouldPromote());

    // Reach tier 1 threshold
    for (0..TIER1_THRESHOLD) |_| {
        prof.recordCall();
    }
    try std.testing.expect(prof.shouldPromote());
    try std.testing.expectEqual(prof.state, .warm);
    try std.testing.expectEqual(prof.nextTier(), .baseline);

    // Promote to baseline
    prof.tier = .baseline;

    // Not yet promotable to tier 2
    try std.testing.expect(!prof.shouldPromote());

    // Reach tier 2 threshold
    while (prof.call_count < TIER2_THRESHOLD) {
        prof.recordCall();
    }
    try std.testing.expect(prof.shouldPromote());
    try std.testing.expectEqual(prof.state, .hot);
    try std.testing.expectEqual(prof.nextTier(), .optimizing);
}

test "OSR detection" {
    var prof = FunctionProfile.init(2, 128, .matvec);

    try std.testing.expect(!prof.shouldOSR());

    for (0..OSR_THRESHOLD) |_| {
        prof.recordLoopIteration();
    }
    try std.testing.expect(prof.shouldOSR());
}

test "compilation queue priority ordering" {
    var queue = CompilationQueue.init();

    // Insert with different priorities
    try std.testing.expect(queue.enqueue(.{
        .func_id = 1,
        .target_tier = .baseline,
        .priority = 100,
        .dimension = 256,
        .op_kind = .bind,
    }));
    try std.testing.expect(queue.enqueue(.{
        .func_id = 2,
        .target_tier = .baseline,
        .priority = 500,
        .dimension = 256,
        .op_kind = .dot,
    }));
    try std.testing.expect(queue.enqueue(.{
        .func_id = 3,
        .target_tier = .baseline,
        .priority = 200,
        .dimension = 256,
        .op_kind = .cosine,
    }));

    // Should dequeue highest priority first
    const first = queue.dequeue().?;
    try std.testing.expectEqual(first.func_id, 2); // priority 500
    try std.testing.expectEqual(first.priority, 500);

    const second = queue.dequeue().?;
    try std.testing.expectEqual(second.func_id, 3); // priority 200

    const third = queue.dequeue().?;
    try std.testing.expectEqual(third.func_id, 1); // priority 100

    try std.testing.expect(queue.isEmpty());
}

test "code cache lookup and LRU eviction" {
    var cache = CodeCache.init();

    // Insert some entries
    cache.insert(CompiledFunction.init(0, .baseline, 256, .bind));
    cache.insert(CompiledFunction.init(1, .baseline, 256, .dot));
    cache.insert(CompiledFunction.init(2, .optimizing, 512, .cosine));

    // Lookup should find entries
    const found = cache.lookup(1);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(found.?.func_id, 1);

    // Miss should return null
    const miss = cache.lookup(999);
    try std.testing.expect(miss == null);

    // Stats
    const stats = cache.getStats();
    try std.testing.expectEqual(stats.cache_hits, 1);
    try std.testing.expectEqual(stats.cache_misses, 1);
}

test "code cache hit rate" {
    var stats = CodeCacheStats{
        .total_entries = 10,
        .cache_hits = 80,
        .cache_misses = 20,
        .evictions = 0,
    };
    try std.testing.expectApproxEqAbs(stats.hitRate(), 0.8, 0.001);
}

test "baseline compiler bind" {
    var compiler = BaselineCompiler.init();
    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0 };
    const b = [_]i8{ 1, 1, -1, 1, -1, 0, 1, -1 };
    var out: [8]i8 = undefined;

    compiler.compileBind(&out, &a, &b, 8);

    // Expected: element-wise multiply clamped
    const expected = [_]i8{ 1, -1, -1, 0, 1, 0, -1, 0 };
    try std.testing.expectEqualSlices(i8, &expected, &out);
}

test "baseline compiler unbind is inverse of bind" {
    var compiler = BaselineCompiler.init();
    // Key must be non-zero {-1, +1} for unbind to perfectly invert bind
    const original = [_]i8{ 1, -1, 1, -1, 0, 1 };
    const key = [_]i8{ -1, 1, 1, -1, 1, -1 };
    var bound: [6]i8 = undefined;
    var recovered: [6]i8 = undefined;

    compiler.compileBind(&bound, &original, &key, 6);
    compiler.compileUnbind(&recovered, &bound, &key, 6);
    try std.testing.expectEqualSlices(i8, &original, &recovered);
}

test "baseline compiler cosine similarity" {
    var compiler = BaselineCompiler.init();

    // Identical vectors
    const a = [_]i8{ 1, -1, 1, -1, 1, -1, 1, -1 };
    const sim = compiler.compileCosineSimilarity(&a, &a, 8);
    try std.testing.expectApproxEqAbs(sim, 1.0, 0.001);

    // Opposite vectors
    const b = [_]i8{ -1, 1, -1, 1, -1, 1, -1, 1 };
    const sim_opp = compiler.compileCosineSimilarity(&a, &b, 8);
    try std.testing.expectApproxEqAbs(sim_opp, -1.0, 0.001);
}

test "baseline compiler hamming distance" {
    var compiler = BaselineCompiler.init();
    const a = [_]i8{ 1, -1, 1, -1, 0, 1 };
    const b = [_]i8{ 1, 1, 1, -1, 0, -1 };
    const dist = compiler.compileHammingDistance(&a, &b, 6);
    try std.testing.expectEqual(dist, 2); // positions 1 and 5 differ
}

test "baseline compiler ternary matvec" {
    var compiler = BaselineCompiler.init();

    // 2x3 matrix, 3-vector
    const matrix = [_]i8{ 1, -1, 0, 0, 1, -1 };
    const vector = [_]f32{ 3.0, 2.0, 1.0 };
    var output: [2]f32 = undefined;

    compiler.compileTernaryMatVec(&output, &matrix, &vector, 2, 3);

    // Row 0: 1*3 + (-1)*2 + 0*1 = 1.0
    try std.testing.expectApproxEqAbs(output[0], 1.0, 0.001);
    // Row 1: 0*3 + 1*2 + (-1)*1 = 1.0
    try std.testing.expectApproxEqAbs(output[1], 1.0, 0.001);
}

test "optimizing compiler bind matches baseline" {
    var baseline = BaselineCompiler.init();
    var opt = OptimizingCompiler.init();

    const a = [_]i8{ 1, -1, 1, 0, -1, 1, -1, 0, 1, 1 };
    const b = [_]i8{ -1, 1, 1, 1, -1, 0, 1, -1, 0, 1 };
    var base_out: [10]i8 = undefined;
    var opt_out: [10]i8 = undefined;

    baseline.compileBind(&base_out, &a, &b, 10);
    opt.optimizedBind(&opt_out, &a, &b, 10);

    try std.testing.expectEqualSlices(i8, &base_out, &opt_out);
}

test "optimizing compiler cosine matches baseline" {
    var baseline = BaselineCompiler.init();
    var opt = OptimizingCompiler.init();

    const a = [_]i8{ 1, -1, 1, -1, 0, 1, -1, 0, 1, -1, 1, 0 };
    const b = [_]i8{ -1, 1, 0, -1, 1, 1, 0, -1, 1, 1, -1, 1 };

    const base_sim = baseline.compileCosineSimilarity(&a, &b, 12);
    const opt_sim = opt.optimizedCosineSimilarity(&a, &b, 12);

    try std.testing.expectApproxEqAbs(base_sim, opt_sim, 0.001);
}

test "optimizing compiler matvec matches baseline" {
    var baseline = BaselineCompiler.init();
    var opt = OptimizingCompiler.init();

    // 3x5 matrix
    const matrix = [_]i8{
        1,  -1, 0, 1,  -1,
        0,  1,  1, -1, 0,
        -1, 0,  1, 0,  1,
    };
    const vector = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    var base_out: [3]f32 = undefined;
    var opt_out: [3]f32 = undefined;

    baseline.compileTernaryMatVec(&base_out, &matrix, &vector, 3, 5);
    opt.optimizedTernaryMatVec(&opt_out, &matrix, &vector, 3, 5);

    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(base_out[i], opt_out[i], 0.001);
    }
}

test "JIT controller register and profile" {
    var ctrl = JitController.init();

    const id = ctrl.registerFunction(256, .bind);
    try std.testing.expectEqual(id, 0);

    // Record calls
    for (0..50) |_| {
        ctrl.recordCall(id);
    }

    const prof = ctrl.findProfile(id).?;
    try std.testing.expectEqual(prof.call_count, 50);
    try std.testing.expectEqual(prof.tier, .interpreter);
}

test "JIT controller tier promotion" {
    var ctrl = JitController.init();
    const id = ctrl.registerFunction(128, .dot);

    // Drive past tier 1 threshold
    for (0..TIER1_THRESHOLD + 1) |_| {
        ctrl.recordCall(id);
    }

    // Should have queued compilation
    try std.testing.expect(!ctrl.queue.isEmpty());

    // Process queue
    const compiled = ctrl.processQueue();
    try std.testing.expect(compiled);

    // Check stats
    const stats = ctrl.getStats();
    try std.testing.expectEqual(stats.functions_compiled, 1);
    try std.testing.expectEqual(stats.tier1_compilations, 1);
}

test "JIT controller deoptimization" {
    var ctrl = JitController.init();
    const id = ctrl.registerFunction(64, .cosine);

    // Promote to baseline
    for (0..TIER1_THRESHOLD + 1) |_| {
        ctrl.recordCall(id);
    }
    _ = ctrl.processQueue();

    // Deoptimize
    ctrl.deoptimize(id);

    const prof = ctrl.findProfile(id).?;
    try std.testing.expectEqual(prof.tier, .interpreter);
    try std.testing.expectEqual(prof.state, .deoptimized);
    try std.testing.expectEqual(prof.deopt_count, 1);
    try std.testing.expectEqual(ctrl.stats.deoptimizations, 1);
}

test "JIT controller OSR trigger" {
    var ctrl = JitController.init();
    const id = ctrl.registerFunction(512, .matvec);

    for (0..OSR_THRESHOLD) |_| {
        ctrl.recordLoopIteration(id);
    }

    // OSR should have been triggered
    try std.testing.expectEqual(ctrl.stats.osr_triggers, 1);
    try std.testing.expectEqual(ctrl.stats.tier1_compilations, 1);

    const prof = ctrl.findProfile(id).?;
    try std.testing.expectEqual(prof.tier, .baseline);
}

test "JIT controller execute bind" {
    var ctrl = JitController.init();
    const id = ctrl.registerFunction(8, .bind);

    const a = [_]i8{ 1, -1, 1, -1, 1, -1, 1, -1 };
    const b = [_]i8{ 1, 1, -1, -1, 1, 1, -1, -1 };
    var out: [8]i8 = undefined;

    ctrl.executeBind(id, &out, &a, &b, 8);

    const expected = [_]i8{ 1, -1, -1, 1, 1, -1, -1, 1 };
    try std.testing.expectEqualSlices(i8, &expected, &out);
}

test "JIT controller execute cosine similarity" {
    var ctrl = JitController.init();
    const id = ctrl.registerFunction(6, .cosine);

    const a = [_]i8{ 1, -1, 1, -1, 1, -1 };
    const sim = ctrl.executeCosineSimilarity(id, &a, &a, 6);
    try std.testing.expectApproxEqAbs(sim, 1.0, 0.001);
}

test "JIT controller reset" {
    var ctrl = JitController.init();
    _ = ctrl.registerFunction(64, .bind);
    _ = ctrl.registerFunction(128, .dot);

    ctrl.reset();

    try std.testing.expectEqual(ctrl.profile_count, 0);
    try std.testing.expectEqual(ctrl.next_func_id, 0);
    try std.testing.expect(ctrl.queue.isEmpty());
}

test "speedup analysis" {
    const analysis = SpeedupAnalysis.theoreticalTernarySpeedup();
    try std.testing.expectApproxEqAbs(analysis.baselineSpeedup(), 5.0, 0.01);
    try std.testing.expectApproxEqAbs(analysis.optimizingSpeedup(), 20.0, 0.01);
}

test "deopt recompile check" {
    var prof = FunctionProfile.init(0, 256, .bind);
    prof.state = .hot;
    prof.deopt_count = 1;
    try std.testing.expect(prof.shouldRecompile());

    prof.deopt_count = DEOPT_LIMIT;
    try std.testing.expect(!prof.shouldRecompile());
}

test "compilation tier names" {
    try std.testing.expectEqualSlices(u8, "interpreter", CompilationTier.interpreter.name());
    try std.testing.expectEqualSlices(u8, "baseline", CompilationTier.baseline.name());
    try std.testing.expectEqualSlices(u8, "optimizing", CompilationTier.optimizing.name());
}

test "vsa op kind names" {
    try std.testing.expectEqualSlices(u8, "bind", VSAOpKind.bind.name());
    try std.testing.expectEqualSlices(u8, "cosine", VSAOpKind.cosine.name());
    try std.testing.expectEqualSlices(u8, "matvec", VSAOpKind.matvec.name());
}

// phi^2 + 1/phi^2 = 3 | TRINITY
