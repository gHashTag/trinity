// =============================================================================
// PAGED ATTENTION v1.0.0 — OPT-PA01
// Generated from specs/tri/paged_attention.vibee
// vLLM-style block-based KV cache memory management
// 4-10x memory efficiency, eliminates fragmentation
// Combined with ternary: 64x total compression vs static f32 allocation
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// CONFIGURATION
// =============================================================================

/// Configuration for paged attention blocks
pub const BlockConfig = struct {
    /// Tokens per block (default: 16)
    block_size: usize = 16,
    /// Number of attention heads
    num_heads: usize = 32,
    /// Dimension per head
    head_dim: usize = 128,
    /// Number of transformer layers
    num_layers: usize = 32,
    /// Maximum blocks in pool
    max_blocks: usize = 4096,

    /// Memory per KV block in bytes (K + V)
    pub fn blockMemoryBytes(self: *const BlockConfig) usize {
        return self.block_size * self.num_heads * self.head_dim * 2 * @sizeOf(f32);
    }

    /// Total pool memory in bytes
    pub fn totalPoolMemory(self: *const BlockConfig) usize {
        return self.max_blocks * self.blockMemoryBytes();
    }

    /// Maximum tokens the pool can hold
    pub fn maxTokenCapacity(self: *const BlockConfig) usize {
        return self.max_blocks * self.block_size;
    }

    /// 7B model defaults
    pub fn default7B() BlockConfig {
        return .{
            .block_size = 16,
            .num_heads = 32,
            .head_dim = 128,
            .num_layers = 32,
            .max_blocks = 4096,
        };
    }

    /// Mini config for testing
    pub fn mini() BlockConfig {
        return .{
            .block_size = 4,
            .num_heads = 4,
            .head_dim = 8,
            .num_layers = 2,
            .max_blocks = 32,
        };
    }
};

// =============================================================================
// KV BLOCK
// =============================================================================

/// Single KV cache block — holds block_size tokens of K and V vectors
pub const KVBlock = struct {
    /// Unique block identifier
    block_id: usize,
    /// Reference count for copy-on-write sharing
    ref_count: usize,
    /// Key cache: [block_size * num_heads * head_dim]
    k_cache: []f32,
    /// Value cache: [block_size * num_heads * head_dim]
    v_cache: []f32,
    /// Actual tokens stored (0 to block_size)
    num_tokens: usize,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: *const BlockConfig, block_id: usize) !KVBlock {
        const size = config.block_size * config.num_heads * config.head_dim;
        const k_cache = try allocator.alloc(f32, size);
        @memset(k_cache, 0.0);
        const v_cache = try allocator.alloc(f32, size);
        @memset(v_cache, 0.0);

        return KVBlock{
            .block_id = block_id,
            .ref_count = 0,
            .k_cache = k_cache,
            .v_cache = v_cache,
            .num_tokens = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *KVBlock) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }

    /// Check if block is full
    pub fn isFull(self: *const KVBlock, block_size: usize) bool {
        return self.num_tokens >= block_size;
    }

    /// Append K,V for one token at a specific head
    pub fn appendToken(
        self: *KVBlock,
        k: []const f32,
        v: []const f32,
        num_heads: usize,
        head_dim: usize,
    ) !void {
        const kv_size = num_heads * head_dim;
        if (k.len != kv_size or v.len != kv_size) return error.InvalidSize;

        const offset = self.num_tokens * kv_size;
        if (offset + kv_size > self.k_cache.len) return error.BlockFull;

        @memcpy(self.k_cache[offset..][0..kv_size], k);
        @memcpy(self.v_cache[offset..][0..kv_size], v);
        self.num_tokens += 1;
    }

    /// Get K vector for a specific token position and head
    pub fn getK(self: *const KVBlock, token_idx: usize, head_idx: usize, num_heads: usize, head_dim: usize) []const f32 {
        const offset = token_idx * num_heads * head_dim + head_idx * head_dim;
        return self.k_cache[offset..][0..head_dim];
    }

    /// Get V vector for a specific token position and head
    pub fn getV(self: *const KVBlock, token_idx: usize, head_idx: usize, num_heads: usize, head_dim: usize) []const f32 {
        const offset = token_idx * num_heads * head_dim + head_idx * head_dim;
        return self.v_cache[offset..][0..head_dim];
    }

    /// Copy data from another block
    pub fn copyFrom(self: *KVBlock, other: *const KVBlock) void {
        @memcpy(self.k_cache, other.k_cache);
        @memcpy(self.v_cache, other.v_cache);
        self.num_tokens = other.num_tokens;
    }

    /// Reset block for reuse
    pub fn reset(self: *KVBlock) void {
        @memset(self.k_cache, 0.0);
        @memset(self.v_cache, 0.0);
        self.num_tokens = 0;
        self.ref_count = 0;
    }
};

// =============================================================================
// BLOCK TABLE (per-sequence page mapping)
// =============================================================================

/// Max blocks per sequence (fixed-size buffer, no ArrayList)
const MAX_BLOCKS_PER_SEQ: usize = 512;

/// Maps a sequence's logical positions to physical block IDs
pub const BlockTable = struct {
    /// Sequence identifier
    seq_id: usize,
    /// Ordered list of physical block IDs for this sequence (fixed buffer)
    block_ids_buf: [MAX_BLOCKS_PER_SEQ]usize,
    /// Number of valid block IDs
    block_count: usize,
    /// Total tokens in this sequence
    num_tokens: usize,

    pub fn init(seq_id: usize) BlockTable {
        return BlockTable{
            .seq_id = seq_id,
            .block_ids_buf = [_]usize{0} ** MAX_BLOCKS_PER_SEQ,
            .block_count = 0,
            .num_tokens = 0,
        };
    }

    /// Append a block ID
    pub fn appendBlock(self: *BlockTable, block_id: usize) !void {
        if (self.block_count >= MAX_BLOCKS_PER_SEQ) return error.TooManyBlocks;
        self.block_ids_buf[self.block_count] = block_id;
        self.block_count += 1;
    }

    /// Get block IDs slice
    pub fn blockIds(self: *const BlockTable) []const usize {
        return self.block_ids_buf[0..self.block_count];
    }

    /// Get mutable block IDs slice
    pub fn blockIdsMut(self: *BlockTable) []usize {
        return self.block_ids_buf[0..self.block_count];
    }

    /// Get block index for a given token position
    pub fn getBlockForToken(self: *const BlockTable, token_pos: usize, block_size: usize) ?usize {
        const block_num = token_pos / block_size;
        if (block_num >= self.block_count) return null;
        return self.block_ids_buf[block_num];
    }

    /// Get position within the block for a given token
    pub fn positionInBlock(token_pos: usize, block_size: usize) usize {
        return token_pos % block_size;
    }

    /// Number of blocks used by this sequence
    pub fn numBlocks(self: *const BlockTable) usize {
        return self.block_count;
    }
};

// =============================================================================
// BLOCK POOL (memory allocator)
// =============================================================================

/// Max free stack size
const MAX_FREE_STACK: usize = 8192;

/// Memory pool for KV cache blocks — pre-allocates and manages blocks
pub const BlockPool = struct {
    allocator: std.mem.Allocator,
    config: BlockConfig,
    /// All pre-allocated blocks
    blocks: []KVBlock,
    /// Stack of free block indices (LIFO for cache locality)
    free_stack_buf: []usize,
    /// Number of entries in free stack
    free_count: usize,
    /// Number of currently allocated blocks
    num_allocated: usize,
    /// Cumulative copy-on-write operations
    cow_copies: usize,
    /// Cumulative eviction count
    evictions: usize,

    pub fn init(allocator: std.mem.Allocator, config: BlockConfig) !BlockPool {
        const blocks = try allocator.alloc(KVBlock, config.max_blocks);
        const free_stack_buf = try allocator.alloc(usize, config.max_blocks);

        // Pre-allocate all blocks and add to free stack
        for (0..config.max_blocks) |i| {
            blocks[i] = try KVBlock.init(allocator, &config, i);
            free_stack_buf[i] = i;
        }

        return BlockPool{
            .allocator = allocator,
            .config = config,
            .blocks = blocks,
            .free_stack_buf = free_stack_buf,
            .free_count = config.max_blocks,
            .num_allocated = 0,
            .cow_copies = 0,
            .evictions = 0,
        };
    }

    pub fn deinit(self: *BlockPool) void {
        for (self.blocks) |*block| {
            block.deinit();
        }
        self.allocator.free(self.blocks);
        self.allocator.free(self.free_stack_buf);
    }

    /// Allocate a block from the pool. Returns block_id or null if exhausted.
    pub fn allocateBlock(self: *BlockPool) ?usize {
        if (self.free_count == 0) return null;
        self.free_count -= 1;
        const block_id = self.free_stack_buf[self.free_count];
        self.blocks[block_id].ref_count = 1;
        self.blocks[block_id].num_tokens = 0;
        self.num_allocated += 1;
        return block_id;
    }

    /// Free a block. Decrements ref_count; returns to pool if zero.
    pub fn freeBlock(self: *BlockPool, block_id: usize) void {
        if (block_id >= self.blocks.len) return;
        if (self.blocks[block_id].ref_count == 0) return;

        self.blocks[block_id].ref_count -= 1;
        if (self.blocks[block_id].ref_count == 0) {
            self.blocks[block_id].reset();
            if (self.free_count < self.free_stack_buf.len) {
                self.free_stack_buf[self.free_count] = block_id;
                self.free_count += 1;
            }
            if (self.num_allocated > 0) self.num_allocated -= 1;
        }
    }

    /// Get mutable block reference by ID
    pub fn getBlock(self: *BlockPool, block_id: usize) ?*KVBlock {
        if (block_id >= self.blocks.len) return null;
        return &self.blocks[block_id];
    }

    /// Copy-on-write: if block is shared (ref_count > 1), copy to new block
    pub fn copyOnWrite(self: *BlockPool, block_id: usize) ?usize {
        if (block_id >= self.blocks.len) return null;

        const block = &self.blocks[block_id];
        if (block.ref_count <= 1) return block_id; // Not shared, no copy needed

        // Allocate new block
        const new_id = self.allocateBlock() orelse return null;
        const new_block = &self.blocks[new_id];

        // Copy data
        new_block.copyFrom(block);

        // Decrement old block ref count
        block.ref_count -= 1;
        self.cow_copies += 1;

        return new_id;
    }

    /// Increment ref count for block sharing (e.g., beam search fork)
    pub fn shareBlock(self: *BlockPool, block_id: usize) void {
        if (block_id < self.blocks.len) {
            self.blocks[block_id].ref_count += 1;
        }
    }

    /// Number of free blocks remaining
    pub fn numFree(self: *const BlockPool) usize {
        return self.free_count;
    }

    /// Pool utilization percentage
    pub fn utilization(self: *const BlockPool) f32 {
        if (self.config.max_blocks == 0) return 0.0;
        return @as(f32, @floatFromInt(self.num_allocated)) / @as(f32, @floatFromInt(self.config.max_blocks)) * 100.0;
    }

    /// Get comprehensive stats
    pub fn getStats(self: *const BlockPool) PagedAttentionStats {
        const mem_per_block = self.config.blockMemoryBytes();
        return PagedAttentionStats{
            .total_blocks = self.config.max_blocks,
            .allocated_blocks = self.num_allocated,
            .free_blocks = self.numFree(),
            .memory_used_bytes = self.num_allocated * mem_per_block,
            .memory_total_bytes = self.config.max_blocks * mem_per_block,
            .utilization_percent = self.utilization(),
            .cow_copies = self.cow_copies,
            .evictions = self.evictions,
        };
    }
};

// =============================================================================
// PAGED ATTENTION STATS
// =============================================================================

/// Monitoring statistics for paged attention
pub const PagedAttentionStats = struct {
    total_blocks: usize,
    allocated_blocks: usize,
    free_blocks: usize,
    memory_used_bytes: usize,
    memory_total_bytes: usize,
    utilization_percent: f32,
    cow_copies: usize,
    evictions: usize,

    /// Memory efficiency vs static allocation
    pub fn savingsVsStatic(self: *const PagedAttentionStats, max_seq_len: usize, batch_size: usize, bytes_per_token: usize) f32 {
        const static_bytes = max_seq_len * batch_size * bytes_per_token;
        if (self.memory_used_bytes == 0) return 0.0;
        return @as(f32, @floatFromInt(static_bytes)) / @as(f32, @floatFromInt(self.memory_used_bytes));
    }
};

// =============================================================================
// PAGED KV CACHE MANAGER
// =============================================================================

/// Max concurrent sequences
const MAX_SEQUENCES: usize = 256;

/// Manages multiple sequences with paged KV cache
pub const PagedKVCacheManager = struct {
    allocator: std.mem.Allocator,
    config: BlockConfig,
    pool: BlockPool,
    /// Active sequence block tables (fixed-size array)
    tables_buf: [MAX_SEQUENCES]BlockTable,
    /// Which table slots are active
    table_active: [MAX_SEQUENCES]bool,
    /// Next sequence ID
    next_seq_id: usize,
    /// Number of active sequences
    active_count: usize,

    pub fn init(allocator: std.mem.Allocator, config: BlockConfig) !PagedKVCacheManager {
        var mgr = PagedKVCacheManager{
            .allocator = allocator,
            .config = config,
            .pool = try BlockPool.init(allocator, config),
            .tables_buf = undefined,
            .table_active = [_]bool{false} ** MAX_SEQUENCES,
            .next_seq_id = 0,
            .active_count = 0,
        };
        for (0..MAX_SEQUENCES) |i| {
            mgr.tables_buf[i] = BlockTable.init(i);
        }
        return mgr;
    }

    pub fn deinit(self: *PagedKVCacheManager) void {
        for (0..MAX_SEQUENCES) |i| {
            if (self.table_active[i]) {
                const table = &self.tables_buf[i];
                for (table.blockIds()) |block_id| {
                    self.pool.freeBlock(block_id);
                }
            }
        }
        self.pool.deinit();
    }

    /// Find table slot by seq_id
    fn findSlot(self: *const PagedKVCacheManager, seq_id: usize) ?usize {
        for (0..MAX_SEQUENCES) |i| {
            if (self.table_active[i] and self.tables_buf[i].seq_id == seq_id) return i;
        }
        return null;
    }

    /// Find free slot
    fn findFreeSlot(self: *const PagedKVCacheManager) ?usize {
        for (0..MAX_SEQUENCES) |i| {
            if (!self.table_active[i]) return i;
        }
        return null;
    }

    /// Create a new sequence, returns seq_id
    pub fn createSequence(self: *PagedKVCacheManager) !usize {
        const seq_id = self.next_seq_id;
        self.next_seq_id += 1;
        const slot = self.findFreeSlot() orelse return error.TooManySequences;
        self.tables_buf[slot] = BlockTable.init(seq_id);
        self.table_active[slot] = true;
        self.active_count += 1;
        return seq_id;
    }

    /// Append a token's KV to a sequence
    pub fn appendToken(
        self: *PagedKVCacheManager,
        seq_id: usize,
        k: []const f32,
        v: []const f32,
    ) !void {
        const slot = self.findSlot(seq_id) orelse return error.SequenceNotFound;
        const table = &self.tables_buf[slot];
        const block_size = self.config.block_size;
        const num_heads = self.config.num_heads;
        const head_dim = self.config.head_dim;

        // Check if we need a new block
        const current_block_num = table.num_tokens / block_size;
        if (current_block_num >= table.block_count) {
            // Allocate new block
            const block_id = self.pool.allocateBlock() orelse return error.PoolExhausted;
            try table.appendBlock(block_id);
        }

        // Get current block
        const block_id = table.block_ids_buf[current_block_num];
        const block = self.pool.getBlock(block_id) orelse return error.InvalidBlock;

        // Check copy-on-write
        if (block.ref_count > 1) {
            const new_id = self.pool.copyOnWrite(block_id) orelse return error.PoolExhausted;
            table.block_ids_buf[current_block_num] = new_id;
            const new_block = self.pool.getBlock(new_id) orelse return error.InvalidBlock;
            try new_block.appendToken(k, v, num_heads, head_dim);
        } else {
            try block.appendToken(k, v, num_heads, head_dim);
        }

        table.num_tokens += 1;
    }

    /// Fork a sequence (for beam search) — shares all blocks via ref counting
    pub fn forkSequence(self: *PagedKVCacheManager, src_seq_id: usize) !usize {
        const src_slot = self.findSlot(src_seq_id) orelse return error.SequenceNotFound;
        const src_table = &self.tables_buf[src_slot];

        const new_seq_id = self.next_seq_id;
        self.next_seq_id += 1;

        const new_slot = self.findFreeSlot() orelse return error.TooManySequences;
        self.tables_buf[new_slot] = BlockTable.init(new_seq_id);
        self.table_active[new_slot] = true;
        self.active_count += 1;

        var new_table = &self.tables_buf[new_slot];
        new_table.num_tokens = src_table.num_tokens;

        // Share all blocks (increment ref counts)
        for (src_table.blockIds()) |block_id| {
            self.pool.shareBlock(block_id);
            try new_table.appendBlock(block_id);
        }

        return new_seq_id;
    }

    /// Remove a sequence, freeing its blocks
    pub fn removeSequence(self: *PagedKVCacheManager, seq_id: usize) void {
        const slot = self.findSlot(seq_id) orelse return;
        const table = &self.tables_buf[slot];
        for (table.blockIds()) |block_id| {
            self.pool.freeBlock(block_id);
        }
        self.table_active[slot] = false;
        if (self.active_count > 0) self.active_count -= 1;
    }

    /// Compute paged attention for a query against a sequence
    pub fn pagedAttention(
        self: *PagedKVCacheManager,
        output: []f32,
        query: []const f32,
        seq_id: usize,
        head_idx: usize,
        scale: f32,
    ) !void {
        const slot = self.findSlot(seq_id) orelse return error.SequenceNotFound;
        const table = &self.tables_buf[slot];
        const head_dim = self.config.head_dim;
        const num_heads = self.config.num_heads;
        const block_size = self.config.block_size;
        const num_tokens = table.num_tokens;

        if (num_tokens == 0) {
            @memset(output, 0.0);
            return;
        }

        // Allocate scores buffer
        const scores = try self.allocator.alloc(f32, num_tokens);
        defer self.allocator.free(scores);

        // Phase 1: Q @ K^T — compute attention scores
        for (0..num_tokens) |pos| {
            const block_num = pos / block_size;
            const pos_in_block = pos % block_size;

            if (block_num >= table.block_count) {
                scores[pos] = -std.math.inf(f32);
                continue;
            }

            const bid = table.block_ids_buf[block_num];
            const blk = &self.pool.blocks[bid];

            if (pos_in_block >= blk.num_tokens) {
                scores[pos] = -std.math.inf(f32);
                continue;
            }

            const k_vec = blk.getK(pos_in_block, head_idx, num_heads, head_dim);

            // Dot product Q · K
            var dot: f32 = 0.0;
            for (0..head_dim) |d| {
                dot += query[d] * k_vec[d];
            }
            scores[pos] = dot * scale;
        }

        // Phase 2: Softmax
        var max_score: f32 = -std.math.inf(f32);
        for (scores) |s| {
            if (s > max_score) max_score = s;
        }

        var sum_exp: f32 = 0.0;
        for (scores) |*s| {
            if (s.* > -std.math.inf(f32)) {
                s.* = @exp(s.* - max_score);
                sum_exp += s.*;
            } else {
                s.* = 0.0;
            }
        }

        if (sum_exp > 0.0) {
            for (scores) |*s| {
                s.* /= sum_exp;
            }
        }

        // Phase 3: Weighted sum of V
        @memset(output, 0.0);
        for (0..num_tokens) |pos| {
            if (scores[pos] == 0.0) continue;

            const block_num = pos / block_size;
            const pos_in_block = pos % block_size;

            if (block_num >= table.block_count) continue;

            const bid = table.block_ids_buf[block_num];
            const blk = &self.pool.blocks[bid];

            if (pos_in_block >= blk.num_tokens) continue;

            const v_vec = blk.getV(pos_in_block, head_idx, num_heads, head_dim);
            const weight = scores[pos];

            for (0..head_dim) |d| {
                output[d] += weight * v_vec[d];
            }
        }
    }

    /// Get pool stats
    pub fn getStats(self: *const PagedKVCacheManager) PagedAttentionStats {
        return self.pool.getStats();
    }

    /// Number of active sequences
    pub fn numSequences(self: *const PagedKVCacheManager) usize {
        return self.active_count;
    }

    /// Total tokens across all sequences
    pub fn totalTokens(self: *const PagedKVCacheManager) usize {
        var total: usize = 0;
        for (0..MAX_SEQUENCES) |i| {
            if (self.table_active[i]) {
                total += self.tables_buf[i].num_tokens;
            }
        }
        return total;
    }
};

// =============================================================================
// MEMORY ANALYSIS
// =============================================================================

/// Compute memory savings of paged vs static allocation
pub fn computeMemorySavings(
    config: *const BlockConfig,
    num_sequences: usize,
    avg_seq_len: usize,
    max_seq_len: usize,
) MemoryAnalysis {
    const bytes_per_token = config.num_heads * config.head_dim * 2 * @sizeOf(f32);

    // Static: allocate max_seq_len for every sequence
    const static_bytes = num_sequences * max_seq_len * bytes_per_token;

    // Paged: only allocate what's actually used (rounded up to block_size)
    const blocks_per_seq = (avg_seq_len + config.block_size - 1) / config.block_size;
    const paged_bytes = num_sequences * blocks_per_seq * config.block_size * bytes_per_token;

    // Paged + ternary: 16x compression on top
    const paged_ternary_bytes = paged_bytes / 16;

    return MemoryAnalysis{
        .static_bytes = static_bytes,
        .paged_bytes = paged_bytes,
        .paged_ternary_bytes = paged_ternary_bytes,
        .paged_savings_ratio = @as(f32, @floatFromInt(static_bytes)) / @as(f32, @floatFromInt(@max(paged_bytes, 1))),
        .total_savings_ratio = @as(f32, @floatFromInt(static_bytes)) / @as(f32, @floatFromInt(@max(paged_ternary_bytes, 1))),
        .bytes_per_token = bytes_per_token,
    };
}

pub const MemoryAnalysis = struct {
    static_bytes: usize,
    paged_bytes: usize,
    paged_ternary_bytes: usize,
    paged_savings_ratio: f32,
    total_savings_ratio: f32,
    bytes_per_token: usize,
};

// =============================================================================
// TESTS (14 tests)
// =============================================================================

test "block config memory calculations" {
    const config = BlockConfig.mini(); // 4 tokens, 4 heads, 8 dim
    const block_mem = config.blockMemoryBytes();
    // 4 tokens * 4 heads * 8 dim * 2 (K+V) * 4 bytes = 1024
    try std.testing.expectEqual(@as(usize, 1024), block_mem);
    try std.testing.expectEqual(@as(usize, 128), config.maxTokenCapacity()); // 32 blocks * 4 tokens
}

test "block init and append" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var block = try KVBlock.init(allocator, &config, 0);
    defer block.deinit();

    try std.testing.expectEqual(@as(usize, 0), block.num_tokens);
    try std.testing.expect(!block.isFull(config.block_size));

    // Append token
    var k = [_]f32{1.0} ** 32; // 4 heads * 8 dim
    var v = [_]f32{2.0} ** 32;
    try block.appendToken(&k, &v, config.num_heads, config.head_dim);

    try std.testing.expectEqual(@as(usize, 1), block.num_tokens);

    // Verify K retrieval
    const k_head0 = block.getK(0, 0, config.num_heads, config.head_dim);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), k_head0[0], 0.001);
}

test "block table token mapping" {
    var table = BlockTable.init(0);

    try table.appendBlock(5);
    try table.appendBlock(12);

    // Token 0-3 -> block 5, token 4-7 -> block 12
    try std.testing.expectEqual(@as(usize, 5), table.getBlockForToken(0, 4).?);
    try std.testing.expectEqual(@as(usize, 5), table.getBlockForToken(3, 4).?);
    try std.testing.expectEqual(@as(usize, 12), table.getBlockForToken(4, 4).?);
    try std.testing.expect(table.getBlockForToken(8, 4) == null);

    try std.testing.expectEqual(@as(usize, 3), BlockTable.positionInBlock(7, 4));
}

test "pool allocate and free" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    try std.testing.expectEqual(@as(usize, 32), pool.numFree());
    try std.testing.expectEqual(@as(usize, 0), pool.num_allocated);

    // Allocate
    const id1 = pool.allocateBlock();
    try std.testing.expect(id1 != null);
    try std.testing.expectEqual(@as(usize, 31), pool.numFree());
    try std.testing.expectEqual(@as(usize, 1), pool.num_allocated);

    const id2 = pool.allocateBlock();
    try std.testing.expect(id2 != null);
    try std.testing.expect(id1.? != id2.?);

    // Free
    pool.freeBlock(id1.?);
    try std.testing.expectEqual(@as(usize, 1), pool.num_allocated);
    try std.testing.expectEqual(@as(usize, 31), pool.numFree());
}

test "copy on write" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    const id = pool.allocateBlock().?;

    // Add data to block
    var k = [_]f32{3.0} ** 32;
    var v = [_]f32{7.0} ** 32;
    try pool.blocks[id].appendToken(&k, &v, config.num_heads, config.head_dim);

    // Not shared — CoW returns same ID
    const cow1 = pool.copyOnWrite(id);
    try std.testing.expectEqual(id, cow1.?);
    try std.testing.expectEqual(@as(usize, 0), pool.cow_copies);

    // Share the block
    pool.shareBlock(id);
    try std.testing.expectEqual(@as(usize, 2), pool.blocks[id].ref_count);

    // Now CoW should copy
    const cow2 = pool.copyOnWrite(id);
    try std.testing.expect(cow2 != null);
    try std.testing.expect(cow2.? != id);
    try std.testing.expectEqual(@as(usize, 1), pool.cow_copies);
    try std.testing.expectEqual(@as(usize, 1), pool.blocks[id].ref_count);

    // New block should have same data
    const new_k = pool.blocks[cow2.?].getK(0, 0, config.num_heads, config.head_dim);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), new_k[0], 0.001);
}

test "manager create sequence and append" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var mgr = try PagedKVCacheManager.init(allocator, config);
    defer mgr.deinit();

    const seq0 = try mgr.createSequence();
    try std.testing.expectEqual(@as(usize, 0), seq0);
    try std.testing.expectEqual(@as(usize, 1), mgr.numSequences());

    // Append tokens
    var k = [_]f32{1.0} ** 32;
    var v = [_]f32{2.0} ** 32;

    for (0..6) |_| {
        try mgr.appendToken(seq0, &k, &v);
    }

    try std.testing.expectEqual(@as(usize, 6), mgr.totalTokens());

    // 6 tokens / 4 block_size = 2 blocks
    const stats = mgr.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.allocated_blocks);
}

test "manager fork sequence" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var mgr = try PagedKVCacheManager.init(allocator, config);
    defer mgr.deinit();

    const seq0 = try mgr.createSequence();
    var k = [_]f32{1.0} ** 32;
    var v = [_]f32{2.0} ** 32;

    // Append 3 tokens (block not full, block_size=4) so fork shares incomplete block
    for (0..3) |_| {
        try mgr.appendToken(seq0, &k, &v);
    }

    // Fork
    const seq1 = try mgr.forkSequence(seq0);
    try std.testing.expectEqual(@as(usize, 2), mgr.numSequences());

    // Forked sequence shares blocks (ref_count > 1)
    const src_slot = mgr.findSlot(seq0).?;
    const block_id = mgr.tables_buf[src_slot].block_ids_buf[0];
    try std.testing.expect(mgr.pool.blocks[block_id].ref_count >= 2);

    // Append to forked sequence — triggers CoW on the shared block
    var k2 = [_]f32{9.0} ** 32;
    var v2 = [_]f32{8.0} ** 32;
    try mgr.appendToken(seq1, &k2, &v2);

    // CoW should have been triggered (shared block was written to)
    try std.testing.expect(mgr.pool.cow_copies > 0);
}

test "manager remove sequence" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var mgr = try PagedKVCacheManager.init(allocator, config);
    defer mgr.deinit();

    const seq0 = try mgr.createSequence();
    var k = [_]f32{1.0} ** 32;
    var v = [_]f32{2.0} ** 32;

    for (0..8) |_| {
        try mgr.appendToken(seq0, &k, &v);
    }

    const before = mgr.getStats();
    try std.testing.expect(before.allocated_blocks > 0);

    mgr.removeSequence(seq0);
    try std.testing.expectEqual(@as(usize, 0), mgr.numSequences());

    const after = mgr.getStats();
    try std.testing.expectEqual(@as(usize, 0), after.allocated_blocks);
}

test "paged attention single token" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini(); // 4 heads, 8 dim
    var mgr = try PagedKVCacheManager.init(allocator, config);
    defer mgr.deinit();

    const seq0 = try mgr.createSequence();

    // K = all 1s, V = all 2s
    var k = [_]f32{1.0} ** 32;
    var v = [_]f32{2.0} ** 32;
    try mgr.appendToken(seq0, &k, &v);

    // Query = all 1s, head 0
    var query = [_]f32{1.0} ** 8;
    var output: [8]f32 = undefined;

    try mgr.pagedAttention(&output, &query, seq0, 0, 1.0);

    // Single token: weight = 1.0 after softmax, output = V values for head 0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), output[0], 0.01);
}

test "paged attention multi-block" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var mgr = try PagedKVCacheManager.init(allocator, config);
    defer mgr.deinit();

    const seq0 = try mgr.createSequence();

    // Append 8 tokens across 2 blocks
    for (0..8) |i| {
        var k_buf: [32]f32 = undefined;
        var v_buf: [32]f32 = undefined;
        @memset(&k_buf, @as(f32, @floatFromInt(i)));
        @memset(&v_buf, @as(f32, @floatFromInt(i * 10)));
        try mgr.appendToken(seq0, &k_buf, &v_buf);
    }

    var query: [8]f32 = undefined;
    @memset(&query, 1.0);
    var output: [8]f32 = undefined;

    try mgr.pagedAttention(&output, &query, seq0, 0, 0.1);

    // Output should be weighted sum of V values, not NaN
    for (output) |o| {
        try std.testing.expect(!std.math.isNan(o));
    }
    try std.testing.expect(output[0] > 0.0);
}

test "memory analysis 7B model" {
    const config = BlockConfig.default7B();
    const analysis = computeMemorySavings(&config, 8, 500, 2048);

    // Static: 8 * 2048 * bytes_per_token
    // Paged should be ~4x better
    try std.testing.expect(analysis.paged_savings_ratio > 3.0);

    // Paged + ternary should be ~64x better
    try std.testing.expect(analysis.total_savings_ratio > 50.0);
}

test "pool exhaustion" {
    const allocator = std.testing.allocator;
    var config = BlockConfig.mini();
    config.max_blocks = 4; // Very small pool
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    // Allocate all 4
    for (0..4) |_| {
        try std.testing.expect(pool.allocateBlock() != null);
    }

    // 5th should fail
    try std.testing.expect(pool.allocateBlock() == null);

    // Free one, allocate again should work
    pool.freeBlock(0);
    try std.testing.expect(pool.allocateBlock() != null);
}

test "block reset" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var block = try KVBlock.init(allocator, &config, 0);
    defer block.deinit();

    var k = [_]f32{5.0} ** 32;
    var v = [_]f32{7.0} ** 32;
    try block.appendToken(&k, &v, config.num_heads, config.head_dim);
    try std.testing.expectEqual(@as(usize, 1), block.num_tokens);

    block.reset();
    try std.testing.expectEqual(@as(usize, 0), block.num_tokens);
    try std.testing.expectEqual(@as(usize, 0), block.ref_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), block.k_cache[0], 0.001);
}

test "utilization tracking" {
    const allocator = std.testing.allocator;
    const config = BlockConfig.mini();
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), pool.utilization(), 0.1);

    _ = pool.allocateBlock();
    // 1/32 = 3.125%
    try std.testing.expect(pool.utilization() > 2.0);

    for (0..15) |_| {
        _ = pool.allocateBlock();
    }
    // 16/32 = 50%
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), pool.utilization(), 1.0);
}

// φ² + 1/φ² = 3 | TRINITY
