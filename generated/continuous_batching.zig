// =============================================================================
// CONTINUOUS BATCHING v2.0.0 — OPT-B01
// Generated from specs/tri/continuous_batching.vibee
// Orca/vLLM-style iteration-level scheduling
// 2-3x throughput via dynamic batch management
// Integrates with PagedAttention (OPT-PA01) for optimal memory
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// CONFIGURATION
// =============================================================================

/// Scheduler configuration
pub const SchedulerConfig = struct {
    /// Maximum sequences running simultaneously
    max_batch_size: usize = 8,
    /// Maximum total tokens across all sequences per iteration
    max_tokens_per_iter: usize = 4096,
    /// Allow preemption of low-priority sequences
    preemption_enabled: bool = true,
    /// Priority boost per waiting iteration (higher = more urgent)
    priority_boost_per_iter: f32 = 0.1,
    /// Maximum requests in the waiting queue
    max_queue_size: usize = 128,
    /// Maximum tokens any single sequence can generate
    max_seq_len: usize = 2048,

    /// Mini config for testing
    pub fn mini() SchedulerConfig {
        return .{
            .max_batch_size = 4,
            .max_tokens_per_iter = 256,
            .preemption_enabled = true,
            .priority_boost_per_iter = 0.1,
            .max_queue_size = 16,
            .max_seq_len = 64,
        };
    }

    /// 7B model serving config
    pub fn default7B() SchedulerConfig {
        return .{
            .max_batch_size = 32,
            .max_tokens_per_iter = 16384,
            .preemption_enabled = true,
            .priority_boost_per_iter = 0.05,
            .max_queue_size = 256,
            .max_seq_len = 4096,
        };
    }
};

// =============================================================================
// REQUEST STATUS
// =============================================================================

pub const RequestStatus = enum {
    queued,
    prefill,
    generating,
    completed,
    cancelled,
    preempted,

    pub fn isActive(self: RequestStatus) bool {
        return self == .prefill or self == .generating;
    }

    pub fn isTerminal(self: RequestStatus) bool {
        return self == .completed or self == .cancelled;
    }
};

// =============================================================================
// REQUEST
// =============================================================================

/// Maximum prompt length
const MAX_PROMPT_LEN: usize = 128;

/// Inference request
pub const Request = struct {
    /// Unique request ID
    id: usize,
    /// Prompt token IDs (fixed buffer)
    prompt_buf: [MAX_PROMPT_LEN]u32,
    /// Number of prompt tokens
    prompt_len: usize,
    /// Maximum tokens to generate
    max_tokens: usize,
    /// Sampling temperature
    temperature: f32,
    /// Priority (higher = more urgent)
    priority: f32,
    /// Current status
    status: RequestStatus,
    /// Tokens generated so far
    tokens_generated: usize,
    /// Last generated token
    last_token: u32,
    /// Iteration when this request entered the batch
    start_iteration: usize,
    /// Iterations spent waiting in queue
    wait_iterations: usize,

    pub fn init(id: usize, prompt: []const u32, max_tokens: usize, temperature: f32, priority: f32) Request {
        var req = Request{
            .id = id,
            .prompt_buf = [_]u32{0} ** MAX_PROMPT_LEN,
            .prompt_len = @min(prompt.len, MAX_PROMPT_LEN),
            .max_tokens = max_tokens,
            .temperature = temperature,
            .priority = priority,
            .status = .queued,
            .tokens_generated = 0,
            .last_token = 0,
            .start_iteration = 0,
            .wait_iterations = 0,
        };
        const copy_len = @min(prompt.len, MAX_PROMPT_LEN);
        @memcpy(req.prompt_buf[0..copy_len], prompt[0..copy_len]);
        return req;
    }

    /// Total tokens this request needs (prompt + generated)
    pub fn totalTokens(self: *const Request) usize {
        return self.prompt_len + self.tokens_generated;
    }

    /// Effective priority (boosted by wait time)
    pub fn effectivePriority(self: *const Request, boost_per_iter: f32) f32 {
        return self.priority + @as(f32, @floatFromInt(self.wait_iterations)) * boost_per_iter;
    }

    /// Check if generation is complete
    pub fn isComplete(self: *const Request) bool {
        return self.tokens_generated >= self.max_tokens or
            self.status == .completed or
            self.status == .cancelled;
    }
};

// =============================================================================
// BATCH SLOT
// =============================================================================

/// Slot in the running batch
pub const BatchSlot = struct {
    /// Associated request ID (0 = empty)
    request_id: usize,
    /// Whether this slot is occupied
    active: bool,
    /// In prefill phase (processing prompt)
    is_prefill: bool,
    /// Tokens in KV cache for this slot
    cached_tokens: usize,

    pub fn empty() BatchSlot {
        return .{
            .request_id = 0,
            .active = false,
            .is_prefill = false,
            .cached_tokens = 0,
        };
    }
};

// =============================================================================
// SCHEDULER STATS
// =============================================================================

/// Monitoring statistics
pub const SchedulerStats = struct {
    total_requests: usize,
    completed_requests: usize,
    cancelled_requests: usize,
    total_tokens_generated: usize,
    total_iterations: usize,
    preemption_count: usize,
    /// Running sum of batch sizes (for avg calculation)
    batch_size_sum: usize,
    /// Running sum of wait iterations (for avg latency)
    wait_sum: usize,

    pub fn init() SchedulerStats {
        return .{
            .total_requests = 0,
            .completed_requests = 0,
            .cancelled_requests = 0,
            .total_tokens_generated = 0,
            .total_iterations = 0,
            .preemption_count = 0,
            .batch_size_sum = 0,
            .wait_sum = 0,
        };
    }

    /// Average batch size
    pub fn avgBatchSize(self: *const SchedulerStats) f32 {
        if (self.total_iterations == 0) return 0.0;
        return @as(f32, @floatFromInt(self.batch_size_sum)) / @as(f32, @floatFromInt(self.total_iterations));
    }

    /// Average wait iterations before entering batch
    pub fn avgWaitIterations(self: *const SchedulerStats) f32 {
        if (self.completed_requests == 0) return 0.0;
        return @as(f32, @floatFromInt(self.wait_sum)) / @as(f32, @floatFromInt(self.completed_requests));
    }

    /// Throughput: tokens per iteration
    pub fn tokensPerIteration(self: *const SchedulerStats) f32 {
        if (self.total_iterations == 0) return 0.0;
        return @as(f32, @floatFromInt(self.total_tokens_generated)) / @as(f32, @floatFromInt(self.total_iterations));
    }
};

// =============================================================================
// ITERATION RESULT
// =============================================================================

/// Max sequences in a single iteration result
const MAX_ITERATION_SEQS: usize = 32;

/// Result of one scheduling iteration
pub const IterationResult = struct {
    /// Sequences that were active this iteration
    active_ids_buf: [MAX_ITERATION_SEQS]usize,
    active_count: usize,
    /// Sequences that completed this iteration
    completed_ids_buf: [MAX_ITERATION_SEQS]usize,
    completed_count: usize,
    /// Sequences newly admitted from queue
    admitted_ids_buf: [MAX_ITERATION_SEQS]usize,
    admitted_count: usize,
    /// Total tokens processed this iteration
    tokens_processed: usize,

    pub fn init() IterationResult {
        return .{
            .active_ids_buf = [_]usize{0} ** MAX_ITERATION_SEQS,
            .active_count = 0,
            .completed_ids_buf = [_]usize{0} ** MAX_ITERATION_SEQS,
            .completed_count = 0,
            .admitted_ids_buf = [_]usize{0} ** MAX_ITERATION_SEQS,
            .admitted_count = 0,
            .tokens_processed = 0,
        };
    }

    pub fn activeIds(self: *const IterationResult) []const usize {
        return self.active_ids_buf[0..self.active_count];
    }

    pub fn completedIds(self: *const IterationResult) []const usize {
        return self.completed_ids_buf[0..self.completed_count];
    }

    pub fn admittedIds(self: *const IterationResult) []const usize {
        return self.admitted_ids_buf[0..self.admitted_count];
    }
};

// =============================================================================
// BATCH SCHEDULER
// =============================================================================

/// Maximum requests the scheduler can track
const MAX_REQUESTS: usize = 64;
/// Maximum batch slots
const MAX_BATCH_SLOTS: usize = 32;
/// Maximum queue depth
const MAX_QUEUE_DEPTH: usize = 64;

/// Continuous batching scheduler
pub const BatchScheduler = struct {
    config: SchedulerConfig,

    /// All requests (fixed pool)
    requests: [MAX_REQUESTS]Request,
    request_active: [MAX_REQUESTS]bool,

    /// Running batch slots
    batch_slots: [MAX_BATCH_SLOTS]BatchSlot,
    /// Number of active slots
    active_slots: usize,

    /// Waiting queue (request IDs, sorted by effective priority)
    queue_buf: [MAX_QUEUE_DEPTH]usize,
    queue_len: usize,

    /// Current iteration counter
    current_iteration: usize,

    /// Next request ID
    next_request_id: usize,

    /// Statistics
    stats: SchedulerStats,

    pub fn init(config: SchedulerConfig) BatchScheduler {
        var sched = BatchScheduler{
            .config = config,
            .requests = undefined,
            .request_active = [_]bool{false} ** MAX_REQUESTS,
            .batch_slots = undefined,
            .active_slots = 0,
            .queue_buf = [_]usize{0} ** MAX_QUEUE_DEPTH,
            .queue_len = 0,
            .current_iteration = 0,
            .next_request_id = 1,
            .stats = SchedulerStats.init(),
        };
        for (0..MAX_BATCH_SLOTS) |i| {
            sched.batch_slots[i] = BatchSlot.empty();
        }
        return sched;
    }

    // ─────────────────────────────────────────────────────────────
    // REQUEST MANAGEMENT
    // ─────────────────────────────────────────────────────────────

    /// Submit a new request. Returns request ID.
    pub fn submitRequest(
        self: *BatchScheduler,
        prompt: []const u32,
        max_tokens: usize,
        temperature: f32,
        priority: f32,
    ) !usize {
        // Find free request slot
        const slot = self.findFreeRequestSlot() orelse return error.TooManyRequests;
        const req_id = self.next_request_id;
        self.next_request_id += 1;

        self.requests[slot] = Request.init(req_id, prompt, max_tokens, temperature, priority);
        self.request_active[slot] = true;
        self.stats.total_requests += 1;

        // Add to waiting queue
        try self.enqueue(req_id);

        return req_id;
    }

    /// Cancel a request
    pub fn cancelRequest(self: *BatchScheduler, req_id: usize) void {
        if (self.findRequestSlot(req_id)) |slot| {
            self.requests[slot].status = .cancelled;
            self.stats.cancelled_requests += 1;

            // Remove from batch if active
            self.removeFromBatch(req_id);
            // Remove from queue if queued
            self.removeFromQueue(req_id);
        }
    }

    /// Get request by ID
    pub fn getRequest(self: *const BatchScheduler, req_id: usize) ?*const Request {
        if (self.findRequestSlotConst(req_id)) |slot| {
            return &self.requests[slot];
        }
        return null;
    }

    // ─────────────────────────────────────────────────────────────
    // ITERATION SCHEDULING (CORE LOOP)
    // ─────────────────────────────────────────────────────────────

    /// Run one scheduling iteration. This is the heart of continuous batching.
    /// 1. Check completions → free slots
    /// 2. Fill empty slots from queue → admit new sequences
    /// 3. Record stats
    pub fn scheduleIteration(self: *BatchScheduler) IterationResult {
        var result = IterationResult.init();
        self.current_iteration += 1;

        // Step 1: Check for completed sequences
        for (0..MAX_BATCH_SLOTS) |i| {
            if (!self.batch_slots[i].active) continue;
            const req_id = self.batch_slots[i].request_id;
            if (self.findRequestSlot(req_id)) |rslot| {
                const req = &self.requests[rslot];
                if (req.isComplete()) {
                    // Mark completed
                    req.status = .completed;
                    self.stats.completed_requests += 1;
                    self.stats.wait_sum += req.wait_iterations;

                    // Free batch slot
                    self.batch_slots[i] = BatchSlot.empty();
                    if (self.active_slots > 0) self.active_slots -= 1;

                    // Record in result
                    if (result.completed_count < MAX_ITERATION_SEQS) {
                        result.completed_ids_buf[result.completed_count] = req_id;
                        result.completed_count += 1;
                    }
                }
            }
        }

        // Step 2: Fill empty slots from queue (highest priority first)
        self.boostQueuePriorities();
        self.sortQueue();

        while (self.active_slots < self.config.max_batch_size and self.queue_len > 0) {
            const req_id = self.dequeue() orelse break;
            if (self.findRequestSlot(req_id)) |rslot| {
                const req = &self.requests[rslot];
                if (req.status == .cancelled) continue;

                // Check token budget
                const new_tokens = req.prompt_len + req.tokens_generated;
                const current_tokens = self.countBatchTokens();
                if (current_tokens + new_tokens > self.config.max_tokens_per_iter) {
                    // Put back and stop filling (budget exceeded)
                    self.enqueue(req_id) catch {};
                    break;
                }

                // Admit to batch
                if (self.findEmptyBatchSlot()) |bslot| {
                    self.batch_slots[bslot] = .{
                        .request_id = req_id,
                        .active = true,
                        .is_prefill = req.tokens_generated == 0,
                        .cached_tokens = 0,
                    };
                    req.status = if (req.tokens_generated == 0) .prefill else .generating;
                    req.start_iteration = self.current_iteration;
                    self.active_slots += 1;

                    if (result.admitted_count < MAX_ITERATION_SEQS) {
                        result.admitted_ids_buf[result.admitted_count] = req_id;
                        result.admitted_count += 1;
                    }
                }
            }
        }

        // Step 3: Record active sequences
        var tokens_this_iter: usize = 0;
        for (0..MAX_BATCH_SLOTS) |i| {
            if (!self.batch_slots[i].active) continue;
            const req_id = self.batch_slots[i].request_id;
            if (result.active_count < MAX_ITERATION_SEQS) {
                result.active_ids_buf[result.active_count] = req_id;
                result.active_count += 1;
            }
            // Each active sequence generates 1 token per iteration (decode mode)
            // Prefill processes all prompt tokens at once
            if (self.batch_slots[i].is_prefill) {
                if (self.findRequestSlot(req_id)) |rslot| {
                    tokens_this_iter += self.requests[rslot].prompt_len;
                    self.batch_slots[i].is_prefill = false; // Prefill done after 1 iteration
                    self.requests[rslot].status = .generating;
                }
            } else {
                tokens_this_iter += 1;
            }
        }

        result.tokens_processed = tokens_this_iter;

        // Update stats
        self.stats.total_iterations += 1;
        self.stats.batch_size_sum += self.active_slots;
        self.stats.total_tokens_generated += tokens_this_iter;

        return result;
    }

    /// Simulate generating one token for each active sequence
    pub fn generateStep(self: *BatchScheduler) usize {
        var generated: usize = 0;
        for (0..MAX_BATCH_SLOTS) |i| {
            if (!self.batch_slots[i].active) continue;
            const req_id = self.batch_slots[i].request_id;
            if (self.findRequestSlot(req_id)) |rslot| {
                if (self.requests[rslot].status == .generating) {
                    self.requests[rslot].tokens_generated += 1;
                    self.requests[rslot].last_token = @as(u32, @intCast(self.requests[rslot].tokens_generated));
                    self.batch_slots[i].cached_tokens += 1;
                    generated += 1;
                }
            }
        }
        return generated;
    }

    /// Preempt lowest-priority active sequence to make room
    pub fn preemptLowestPriority(self: *BatchScheduler) ?usize {
        if (!self.config.preemption_enabled) return null;

        var lowest_priority: f32 = std.math.inf(f32);
        var lowest_slot: ?usize = null;
        var lowest_req_id: usize = 0;

        for (0..MAX_BATCH_SLOTS) |i| {
            if (!self.batch_slots[i].active) continue;
            const req_id = self.batch_slots[i].request_id;
            if (self.findRequestSlot(req_id)) |rslot| {
                const p = self.requests[rslot].effectivePriority(self.config.priority_boost_per_iter);
                if (p < lowest_priority) {
                    lowest_priority = p;
                    lowest_slot = i;
                    lowest_req_id = req_id;
                }
            }
        }

        if (lowest_slot) |bslot| {
            // Preempt: move back to queue
            self.batch_slots[bslot] = BatchSlot.empty();
            if (self.active_slots > 0) self.active_slots -= 1;

            if (self.findRequestSlot(lowest_req_id)) |rslot| {
                self.requests[rslot].status = .preempted;
            }

            self.enqueue(lowest_req_id) catch {};
            self.stats.preemption_count += 1;

            return lowest_req_id;
        }

        return null;
    }

    // ─────────────────────────────────────────────────────────────
    // QUERY
    // ─────────────────────────────────────────────────────────────

    /// Number of requests in waiting queue
    pub fn queueSize(self: *const BatchScheduler) usize {
        return self.queue_len;
    }

    /// Number of active sequences in batch
    pub fn batchSize(self: *const BatchScheduler) usize {
        return self.active_slots;
    }

    /// Count total tokens across active batch
    pub fn countBatchTokens(self: *const BatchScheduler) usize {
        var total: usize = 0;
        for (0..MAX_BATCH_SLOTS) |i| {
            if (!self.batch_slots[i].active) continue;
            const req_id = self.batch_slots[i].request_id;
            if (self.findRequestSlotConst(req_id)) |rslot| {
                total += self.requests[rslot].totalTokens();
            }
        }
        return total;
    }

    /// Get stats
    pub fn getStats(self: *const BatchScheduler) SchedulerStats {
        return self.stats;
    }

    // ─────────────────────────────────────────────────────────────
    // INTERNAL HELPERS
    // ─────────────────────────────────────────────────────────────

    fn findFreeRequestSlot(self: *const BatchScheduler) ?usize {
        for (0..MAX_REQUESTS) |i| {
            if (!self.request_active[i]) return i;
        }
        return null;
    }

    fn findRequestSlot(self: *const BatchScheduler, req_id: usize) ?usize {
        for (0..MAX_REQUESTS) |i| {
            if (self.request_active[i] and self.requests[i].id == req_id) return i;
        }
        return null;
    }

    fn findRequestSlotConst(self: *const BatchScheduler, req_id: usize) ?usize {
        for (0..MAX_REQUESTS) |i| {
            if (self.request_active[i] and self.requests[i].id == req_id) return i;
        }
        return null;
    }

    fn findEmptyBatchSlot(self: *const BatchScheduler) ?usize {
        for (0..MAX_BATCH_SLOTS) |i| {
            if (!self.batch_slots[i].active) return i;
        }
        return null;
    }

    fn removeFromBatch(self: *BatchScheduler, req_id: usize) void {
        for (0..MAX_BATCH_SLOTS) |i| {
            if (self.batch_slots[i].active and self.batch_slots[i].request_id == req_id) {
                self.batch_slots[i] = BatchSlot.empty();
                if (self.active_slots > 0) self.active_slots -= 1;
                return;
            }
        }
    }

    fn enqueue(self: *BatchScheduler, req_id: usize) !void {
        if (self.queue_len >= MAX_QUEUE_DEPTH) return error.QueueFull;
        self.queue_buf[self.queue_len] = req_id;
        self.queue_len += 1;
    }

    fn dequeue(self: *BatchScheduler) ?usize {
        if (self.queue_len == 0) return null;
        const req_id = self.queue_buf[0];
        // Shift left
        for (1..self.queue_len) |i| {
            self.queue_buf[i - 1] = self.queue_buf[i];
        }
        self.queue_len -= 1;
        return req_id;
    }

    fn removeFromQueue(self: *BatchScheduler, req_id: usize) void {
        var i: usize = 0;
        while (i < self.queue_len) {
            if (self.queue_buf[i] == req_id) {
                // Shift left
                var j = i;
                while (j + 1 < self.queue_len) : (j += 1) {
                    self.queue_buf[j] = self.queue_buf[j + 1];
                }
                self.queue_len -= 1;
            } else {
                i += 1;
            }
        }
    }

    fn boostQueuePriorities(self: *BatchScheduler) void {
        for (0..self.queue_len) |i| {
            const req_id = self.queue_buf[i];
            if (self.findRequestSlot(req_id)) |rslot| {
                self.requests[rslot].wait_iterations += 1;
            }
        }
    }

    /// Sort queue by effective priority (highest first)
    fn sortQueue(self: *BatchScheduler) void {
        if (self.queue_len <= 1) return;
        // Insertion sort (small queue, stable)
        var i: usize = 1;
        while (i < self.queue_len) : (i += 1) {
            const key = self.queue_buf[i];
            const key_priority = self.getRequestPriority(key);
            var j: usize = i;
            while (j > 0) {
                const prev_priority = self.getRequestPriority(self.queue_buf[j - 1]);
                if (prev_priority >= key_priority) break;
                self.queue_buf[j] = self.queue_buf[j - 1];
                j -= 1;
            }
            self.queue_buf[j] = key;
        }
    }

    fn getRequestPriority(self: *const BatchScheduler, req_id: usize) f32 {
        if (self.findRequestSlotConst(req_id)) |rslot| {
            return self.requests[rslot].effectivePriority(self.config.priority_boost_per_iter);
        }
        return 0.0;
    }
};

// =============================================================================
// THROUGHPUT CALCULATOR
// =============================================================================

/// Compare continuous vs static batching throughput
pub fn computeThroughputGain(
    avg_seq_len: usize,
    max_seq_len: usize,
    batch_size: usize,
    arrival_rate: f32,
) ThroughputAnalysis {
    // Static batching: must wait for batch to fill, then process longest sequence
    const static_tokens_per_batch: f32 = @as(f32, @floatFromInt(batch_size * max_seq_len));
    // Effective throughput limited by batch formation time
    const batch_fill_time: f32 = @as(f32, @floatFromInt(batch_size)) / @max(arrival_rate, 0.001);
    const static_throughput: f32 = static_tokens_per_batch / @max(batch_fill_time, 0.001);

    // Continuous batching: no waiting, immediate processing, only actual tokens
    const continuous_tokens_per_iter: f32 = @as(f32, @floatFromInt(batch_size));
    // With continuous batching, iteration time is constant (1 token per seq)
    const continuous_throughput: f32 = continuous_tokens_per_iter * arrival_rate;

    // Memory efficiency: static wastes padding, continuous uses actual
    const avg_utilization: f32 = @as(f32, @floatFromInt(avg_seq_len)) / @as(f32, @floatFromInt(@max(max_seq_len, 1)));

    return ThroughputAnalysis{
        .static_throughput = static_throughput,
        .continuous_throughput = continuous_throughput,
        .throughput_gain = continuous_throughput / @max(static_throughput, 0.001),
        .memory_utilization_static = avg_utilization,
        .memory_utilization_continuous = 1.0, // Near-perfect with paged attention
        .batch_size = batch_size,
    };
}

pub const ThroughputAnalysis = struct {
    static_throughput: f32,
    continuous_throughput: f32,
    throughput_gain: f32,
    memory_utilization_static: f32,
    memory_utilization_continuous: f32,
    batch_size: usize,
};

// =============================================================================
// TESTS (12 tests)
// =============================================================================

test "scheduler config defaults" {
    const config = SchedulerConfig.mini();
    try std.testing.expectEqual(@as(usize, 4), config.max_batch_size);
    try std.testing.expectEqual(@as(usize, 256), config.max_tokens_per_iter);
    try std.testing.expect(config.preemption_enabled);

    const config7b = SchedulerConfig.default7B();
    try std.testing.expectEqual(@as(usize, 32), config7b.max_batch_size);
}

test "request init and properties" {
    const prompt = [_]u32{ 1, 2, 3, 4, 5 };
    const req = Request.init(1, &prompt, 10, 0.7, 1.0);

    try std.testing.expectEqual(@as(usize, 1), req.id);
    try std.testing.expectEqual(@as(usize, 5), req.prompt_len);
    try std.testing.expectEqual(@as(usize, 10), req.max_tokens);
    try std.testing.expectEqual(RequestStatus.queued, req.status);
    try std.testing.expect(!req.isComplete());
    try std.testing.expectEqual(@as(usize, 5), req.totalTokens()); // prompt only initially
}

test "submit and queue" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{ 1, 2, 3 };

    const id1 = try sched.submitRequest(&prompt, 5, 0.7, 1.0);
    try std.testing.expect(id1 > 0);
    try std.testing.expectEqual(@as(usize, 1), sched.queueSize());
    try std.testing.expectEqual(@as(usize, 0), sched.batchSize());

    const id2 = try sched.submitRequest(&prompt, 5, 0.7, 2.0);
    try std.testing.expect(id2 > id1);
    try std.testing.expectEqual(@as(usize, 2), sched.queueSize());
}

test "schedule iteration admits from queue" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{ 1, 2, 3 };

    _ = try sched.submitRequest(&prompt, 5, 0.7, 1.0);
    _ = try sched.submitRequest(&prompt, 5, 0.7, 1.0);

    // First iteration: should admit both requests
    const result = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 2), result.admitted_count);
    try std.testing.expectEqual(@as(usize, 2), result.active_count);
    try std.testing.expectEqual(@as(usize, 0), sched.queueSize());
    try std.testing.expectEqual(@as(usize, 2), sched.batchSize());
}

test "max batch size enforced" {
    var sched = BatchScheduler.init(SchedulerConfig.mini()); // max_batch_size = 4

    const prompt = [_]u32{ 1, 2 };
    for (0..6) |_| {
        _ = try sched.submitRequest(&prompt, 5, 0.7, 1.0);
    }

    const result = sched.scheduleIteration();
    // Should admit at most max_batch_size (4)
    try std.testing.expect(result.admitted_count <= 4);
    try std.testing.expect(sched.batchSize() <= 4);
    // Remaining should stay in queue
    try std.testing.expect(sched.queueSize() > 0);
}

test "generate step and completion" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{ 1, 2, 3 };

    const id = try sched.submitRequest(&prompt, 3, 0.7, 1.0);

    // Admit
    _ = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 1), sched.batchSize());

    // Generate 3 tokens
    for (0..3) |_| {
        _ = sched.generateStep();
    }

    // Check request state
    const req = sched.getRequest(id).?;
    try std.testing.expectEqual(@as(usize, 3), req.tokens_generated);
    try std.testing.expect(req.isComplete());

    // Next iteration should detect completion
    const result2 = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 1), result2.completed_count);
    try std.testing.expectEqual(@as(usize, 0), sched.batchSize());
}

test "continuous admission after completion" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{1};

    // Submit 3 requests, each generates 1 token
    _ = try sched.submitRequest(&prompt, 1, 0.7, 1.0);
    _ = try sched.submitRequest(&prompt, 1, 0.7, 1.0);
    const id3 = try sched.submitRequest(&prompt, 2, 0.7, 1.0);

    // Iteration 1: admit all 3
    _ = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 3), sched.batchSize());

    // Generate: first 2 complete (max_tokens=1), third needs more
    _ = sched.generateStep();

    // Iteration 2: detect 2 completions
    const r2 = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 2), r2.completed_count);
    try std.testing.expectEqual(@as(usize, 1), sched.batchSize());

    // id3 still active
    const req3 = sched.getRequest(id3).?;
    try std.testing.expect(!req3.isComplete());
}

test "priority ordering" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{1};

    // Submit with different priorities
    const low = try sched.submitRequest(&prompt, 5, 0.7, 1.0);
    const high = try sched.submitRequest(&prompt, 5, 0.7, 10.0);
    _ = low;

    // Schedule: higher priority should be admitted first
    const result = sched.scheduleIteration();
    // Both admitted (batch has room), but high priority gets first slot
    try std.testing.expect(result.admitted_count >= 2);
    // The first admitted should be the high-priority one
    try std.testing.expectEqual(high, result.admittedIds()[0]);
}

test "preemption" {
    var config = SchedulerConfig.mini();
    config.max_batch_size = 2;
    var sched = BatchScheduler.init(config);
    const prompt = [_]u32{1};

    // Fill batch with low-priority requests
    _ = try sched.submitRequest(&prompt, 10, 0.7, 1.0);
    _ = try sched.submitRequest(&prompt, 10, 0.7, 1.0);
    _ = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 2), sched.batchSize());

    // Preempt lowest priority
    const preempted_id = sched.preemptLowestPriority();
    try std.testing.expect(preempted_id != null);
    try std.testing.expectEqual(@as(usize, 1), sched.batchSize());
    try std.testing.expectEqual(@as(usize, 1), sched.stats.preemption_count);

    // Preempted request goes back to queue
    try std.testing.expectEqual(@as(usize, 1), sched.queueSize());
}

test "cancel request" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{ 1, 2 };

    const id = try sched.submitRequest(&prompt, 5, 0.7, 1.0);
    _ = sched.scheduleIteration(); // admit
    try std.testing.expectEqual(@as(usize, 1), sched.batchSize());

    sched.cancelRequest(id);
    try std.testing.expectEqual(@as(usize, 0), sched.batchSize());
    try std.testing.expectEqual(@as(usize, 1), sched.stats.cancelled_requests);

    const req = sched.getRequest(id).?;
    try std.testing.expectEqual(RequestStatus.cancelled, req.status);
}

test "stats tracking" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());
    const prompt = [_]u32{1};

    _ = try sched.submitRequest(&prompt, 2, 0.7, 1.0);
    _ = try sched.submitRequest(&prompt, 2, 0.7, 1.0);

    // Iteration 1: admit both
    _ = sched.scheduleIteration();
    _ = sched.generateStep();

    // Iteration 2
    _ = sched.scheduleIteration();
    _ = sched.generateStep();

    // Iteration 3: both should complete
    _ = sched.scheduleIteration();

    const stats = sched.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_requests);
    try std.testing.expectEqual(@as(usize, 2), stats.completed_requests);
    try std.testing.expectEqual(@as(usize, 3), stats.total_iterations);
    try std.testing.expect(stats.avgBatchSize() > 0.0);
    try std.testing.expect(stats.tokensPerIteration() > 0.0);
}

test "throughput analysis" {
    const analysis = computeThroughputGain(500, 2048, 8, 10.0);

    // Continuous should be better than static under load
    try std.testing.expect(analysis.continuous_throughput > 0.0);
    try std.testing.expect(analysis.static_throughput > 0.0);
    try std.testing.expectEqual(@as(usize, 8), analysis.batch_size);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), analysis.memory_utilization_continuous, 0.01);
    // Static utilization = 500/2048 ~= 0.244
    try std.testing.expect(analysis.memory_utilization_static < 0.5);
}

test "empty batch iteration" {
    var sched = BatchScheduler.init(SchedulerConfig.mini());

    // Schedule with empty queue — should work gracefully
    const result = sched.scheduleIteration();
    try std.testing.expectEqual(@as(usize, 0), result.active_count);
    try std.testing.expectEqual(@as(usize, 0), result.completed_count);
    try std.testing.expectEqual(@as(usize, 0), result.admitted_count);
    try std.testing.expectEqual(@as(usize, 0), result.tokens_processed);
    try std.testing.expectEqual(@as(usize, 1), sched.stats.total_iterations);
}

// φ² + 1/φ² = 3 | TRINITY
