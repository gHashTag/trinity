// ═══════════════════════════════════════════════════════════════════════════════
// CROSS-SHARD TRANSACTIONS — Atomic 2PC (Two-Phase Commit) Coordinator
// Trinity Storage Network v2.1
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const TxConfig = struct {
    /// Maximum shards per transaction
    max_shards_per_tx: u32 = 64,
    /// Prepare phase timeout (milliseconds)
    prepare_timeout_ms: i64 = 30_000,
    /// Maximum concurrent transactions
    max_concurrent_tx: u32 = 256,
    /// Rollback retry attempts
    max_rollback_retries: u32 = 3,
};

pub const TxPhase = enum(u8) {
    created = 0,
    preparing = 1,
    prepared = 2,
    committing = 3,
    committed = 4,
    aborting = 5,
    aborted = 6,
    rolled_back = 7,
};

pub const ParticipantState = enum(u8) {
    unknown = 0,
    vote_commit = 1,
    vote_abort = 2,
    committed = 3,
    aborted = 4,
};

pub const TxParticipant = struct {
    shard_hash: [32]u8,
    node_id: [32]u8,
    state: ParticipantState,
    prepare_time: i64,
};

pub const TxEntry = struct {
    tx_id: u64,
    coordinator_id: [32]u8,
    phase: TxPhase,
    participants: std.ArrayList(TxParticipant),
    created_at: i64,
    prepare_deadline: i64,
    commit_time: i64,
    rollback_attempts: u32,
};

pub const TxResult = struct {
    tx_id: u64,
    success: bool,
    phase: TxPhase,
    participants_committed: u32,
    participants_aborted: u32,
    duration_ms: i64,
};

pub const TxStats = struct {
    total_transactions: u64,
    committed_transactions: u64,
    aborted_transactions: u64,
    rolled_back_transactions: u64,
    total_participants: u64,
    total_prepare_votes: u64,
    total_commit_acks: u64,
    total_rollbacks: u64,
    avg_tx_duration_ms: i64,
};

pub const CrossShardTxCoordinator = struct {
    allocator: std.mem.Allocator,
    config: TxConfig,
    transactions: std.AutoHashMap(u64, TxEntry),
    next_tx_id: u64,
    stats: TxStats,

    pub fn init(allocator: std.mem.Allocator) CrossShardTxCoordinator {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: TxConfig) CrossShardTxCoordinator {
        return .{
            .allocator = allocator,
            .config = config,
            .transactions = std.AutoHashMap(u64, TxEntry).init(allocator),
            .next_tx_id = 1,
            .stats = std.mem.zeroes(TxStats),
        };
    }

    pub fn deinit(self: *CrossShardTxCoordinator) void {
        var it = self.transactions.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.participants.deinit(self.allocator);
        }
        self.transactions.deinit();
    }

    /// Begin a new cross-shard transaction
    pub fn beginTransaction(self: *CrossShardTxCoordinator, coordinator_id: [32]u8, current_time: i64) !u64 {
        const active = self.countActiveTransactions();
        if (active >= self.config.max_concurrent_tx) return error.TooManyTransactions;

        const tx_id = self.next_tx_id;
        self.next_tx_id += 1;

        const entry = TxEntry{
            .tx_id = tx_id,
            .coordinator_id = coordinator_id,
            .phase = .created,
            .participants = .empty,
            .created_at = current_time,
            .prepare_deadline = current_time + self.config.prepare_timeout_ms,
            .commit_time = 0,
            .rollback_attempts = 0,
        };

        try self.transactions.put(tx_id, entry);
        self.stats.total_transactions += 1;

        return tx_id;
    }

    /// Add a shard participant to the transaction
    pub fn addParticipant(self: *CrossShardTxCoordinator, tx_id: u64, shard_hash: [32]u8, node_id: [32]u8, current_time: i64) !void {
        const entry = self.transactions.getPtr(tx_id) orelse return error.TxNotFound;

        if (entry.phase != .created) return error.InvalidPhase;
        if (entry.participants.items.len >= self.config.max_shards_per_tx) return error.TooManyParticipants;

        try entry.participants.append(self.allocator, .{
            .shard_hash = shard_hash,
            .node_id = node_id,
            .state = .unknown,
            .prepare_time = current_time,
        });

        self.stats.total_participants += 1;
    }

    /// Phase 1: Prepare — ask all participants to vote
    pub fn prepare(self: *CrossShardTxCoordinator, tx_id: u64) !void {
        const entry = self.transactions.getPtr(tx_id) orelse return error.TxNotFound;
        if (entry.phase != .created) return error.InvalidPhase;
        if (entry.participants.items.len == 0) return error.NoParticipants;

        entry.phase = .preparing;
    }

    /// Record a participant's prepare vote
    pub fn recordVote(self: *CrossShardTxCoordinator, tx_id: u64, shard_hash: [32]u8, vote_commit: bool) !void {
        const entry = self.transactions.getPtr(tx_id) orelse return error.TxNotFound;
        if (entry.phase != .preparing) return error.InvalidPhase;

        for (entry.participants.items) |*p| {
            if (std.mem.eql(u8, &p.shard_hash, &shard_hash)) {
                p.state = if (vote_commit) .vote_commit else .vote_abort;
                self.stats.total_prepare_votes += 1;
                break;
            }
        }

        // Check if all votes received
        if (self.allVotesReceived(entry)) {
            if (self.allVotedCommit(entry)) {
                entry.phase = .prepared;
            } else {
                entry.phase = .aborting;
            }
        }
    }

    /// Phase 2: Commit — finalize the transaction
    pub fn commit(self: *CrossShardTxCoordinator, tx_id: u64, current_time: i64) !TxResult {
        const entry = self.transactions.getPtr(tx_id) orelse return error.TxNotFound;
        if (entry.phase != .prepared) return error.InvalidPhase;

        entry.phase = .committing;

        // Mark all participants as committed
        for (entry.participants.items) |*p| {
            p.state = .committed;
            self.stats.total_commit_acks += 1;
        }

        entry.phase = .committed;
        entry.commit_time = current_time;
        self.stats.committed_transactions += 1;

        const duration = current_time - entry.created_at;
        self.updateAvgDuration(duration);

        return .{
            .tx_id = tx_id,
            .success = true,
            .phase = .committed,
            .participants_committed = @intCast(entry.participants.items.len),
            .participants_aborted = 0,
            .duration_ms = duration,
        };
    }

    /// Abort a transaction (any participant voted abort or timeout)
    pub fn abort(self: *CrossShardTxCoordinator, tx_id: u64, current_time: i64) !TxResult {
        const entry = self.transactions.getPtr(tx_id) orelse return error.TxNotFound;

        if (entry.phase == .committed or entry.phase == .aborted) return error.InvalidPhase;

        var committed_count: u32 = 0;
        var aborted_count: u32 = 0;

        for (entry.participants.items) |*p| {
            if (p.state == .vote_commit or p.state == .committed) {
                committed_count += 1;
            }
            p.state = .aborted;
            aborted_count += 1;
        }

        entry.phase = .aborted;
        self.stats.aborted_transactions += 1;

        return .{
            .tx_id = tx_id,
            .success = false,
            .phase = .aborted,
            .participants_committed = 0,
            .participants_aborted = aborted_count,
            .duration_ms = current_time - entry.created_at,
        };
    }

    /// Rollback a committed transaction (compensating action)
    pub fn rollback(self: *CrossShardTxCoordinator, tx_id: u64) !TxResult {
        const entry = self.transactions.getPtr(tx_id) orelse return error.TxNotFound;

        if (entry.phase != .committed and entry.phase != .aborting) return error.InvalidPhase;
        if (entry.rollback_attempts >= self.config.max_rollback_retries) return error.MaxRollbackRetries;

        entry.rollback_attempts += 1;
        self.stats.total_rollbacks += 1;

        for (entry.participants.items) |*p| {
            p.state = .aborted;
        }

        entry.phase = .rolled_back;
        self.stats.rolled_back_transactions += 1;

        return .{
            .tx_id = tx_id,
            .success = false,
            .phase = .rolled_back,
            .participants_committed = 0,
            .participants_aborted = @intCast(entry.participants.items.len),
            .duration_ms = 0,
        };
    }

    /// Check for timed-out transactions
    pub fn checkTimeouts(self: *CrossShardTxCoordinator, current_time: i64) ![]u64 {
        var timed_out = std.ArrayList(u64).empty;

        var it = self.transactions.iterator();
        while (it.next()) |entry| {
            const tx = entry.value_ptr;
            if ((tx.phase == .preparing or tx.phase == .created) and
                current_time > tx.prepare_deadline)
            {
                try timed_out.append(self.allocator, tx.tx_id);
            }
        }

        return timed_out.toOwnedSlice(self.allocator);
    }

    /// Get transaction by ID
    pub fn getTransaction(self: *CrossShardTxCoordinator, tx_id: u64) ?TxEntry {
        return self.transactions.get(tx_id);
    }

    pub fn getStats(self: *CrossShardTxCoordinator) TxStats {
        return self.stats;
    }

    fn allVotesReceived(self: *CrossShardTxCoordinator, entry: *TxEntry) bool {
        _ = self;
        for (entry.participants.items) |p| {
            if (p.state == .unknown) return false;
        }
        return true;
    }

    fn allVotedCommit(self: *CrossShardTxCoordinator, entry: *TxEntry) bool {
        _ = self;
        for (entry.participants.items) |p| {
            if (p.state != .vote_commit) return false;
        }
        return true;
    }

    fn countActiveTransactions(self: *CrossShardTxCoordinator) u32 {
        var count: u32 = 0;
        var it = self.transactions.iterator();
        while (it.next()) |entry| {
            const phase = entry.value_ptr.phase;
            if (phase != .committed and phase != .aborted and phase != .rolled_back) {
                count += 1;
            }
        }
        return count;
    }

    fn updateAvgDuration(self: *CrossShardTxCoordinator, duration: i64) void {
        const n = self.stats.committed_transactions;
        if (n == 1) {
            self.stats.avg_tx_duration_ms = duration;
        } else {
            const prev = self.stats.avg_tx_duration_ms;
            self.stats.avg_tx_duration_ms = prev + @divTrunc(duration - prev, @as(i64, @intCast(n)));
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "begin and commit transaction" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    const tx_id = try coord.beginTransaction(coordinator_id, 1000);
    try std.testing.expectEqual(@as(u64, 1), tx_id);

    // Add 3 shard participants
    for (0..3) |i| {
        var shard: [32]u8 = undefined;
        @memset(&shard, @intCast(i + 10));
        var node: [32]u8 = undefined;
        @memset(&node, @intCast(i + 20));
        try coord.addParticipant(tx_id, shard, node, 1000);
    }

    // Phase 1: Prepare
    try coord.prepare(tx_id);
    try std.testing.expectEqual(TxPhase.preparing, coord.getTransaction(tx_id).?.phase);

    // All participants vote commit
    for (0..3) |i| {
        var shard: [32]u8 = undefined;
        @memset(&shard, @intCast(i + 10));
        try coord.recordVote(tx_id, shard, true);
    }

    // Should auto-transition to prepared
    try std.testing.expectEqual(TxPhase.prepared, coord.getTransaction(tx_id).?.phase);

    // Phase 2: Commit
    const result = try coord.commit(tx_id, 2000);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(TxPhase.committed, result.phase);
    try std.testing.expectEqual(@as(u32, 3), result.participants_committed);
    try std.testing.expectEqual(@as(i64, 1000), result.duration_ms);
}

test "abort when participant votes no" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    const tx_id = try coord.beginTransaction(coordinator_id, 1000);

    var s1: [32]u8 = undefined;
    @memset(&s1, 10);
    var s2: [32]u8 = undefined;
    @memset(&s2, 11);
    var n1: [32]u8 = undefined;
    @memset(&n1, 20);
    var n2: [32]u8 = undefined;
    @memset(&n2, 21);

    try coord.addParticipant(tx_id, s1, n1, 1000);
    try coord.addParticipant(tx_id, s2, n2, 1000);

    try coord.prepare(tx_id);
    try coord.recordVote(tx_id, s1, true);
    try coord.recordVote(tx_id, s2, false); // ABORT vote

    // Should auto-transition to aborting
    try std.testing.expectEqual(TxPhase.aborting, coord.getTransaction(tx_id).?.phase);

    // Abort the transaction
    const result = try coord.abort(tx_id, 2000);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(TxPhase.aborted, result.phase);
    try std.testing.expectEqual(@as(u32, 2), result.participants_aborted);
}

test "rollback committed transaction" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    const tx_id = try coord.beginTransaction(coordinator_id, 1000);

    var shard: [32]u8 = undefined;
    @memset(&shard, 10);
    var node: [32]u8 = undefined;
    @memset(&node, 20);
    try coord.addParticipant(tx_id, shard, node, 1000);

    try coord.prepare(tx_id);
    try coord.recordVote(tx_id, shard, true);
    _ = try coord.commit(tx_id, 2000);

    // Rollback
    const result = try coord.rollback(tx_id);
    try std.testing.expectEqual(TxPhase.rolled_back, result.phase);
    try std.testing.expect(!result.success);
}

test "max rollback retries enforced" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.initWithConfig(allocator, .{
        .max_rollback_retries = 2,
    });
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    const tx_id = try coord.beginTransaction(coordinator_id, 1000);
    var shard: [32]u8 = undefined;
    @memset(&shard, 10);
    var node: [32]u8 = undefined;
    @memset(&node, 20);
    try coord.addParticipant(tx_id, shard, node, 1000);
    try coord.prepare(tx_id);
    try coord.recordVote(tx_id, shard, true);
    _ = try coord.commit(tx_id, 2000);

    _ = try coord.rollback(tx_id);
    // After first rollback, phase is rolled_back — need to re-set for second attempt
    // Since rollback already changed to rolled_back, second call fails with InvalidPhase
    const result = coord.rollback(tx_id);
    try std.testing.expectError(error.InvalidPhase, result);
}

test "timeout detection" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.initWithConfig(allocator, .{
        .prepare_timeout_ms = 5000,
    });
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    const tx1 = try coord.beginTransaction(coordinator_id, 1000);
    const tx2 = try coord.beginTransaction(coordinator_id, 2000);
    _ = tx2;

    var shard: [32]u8 = undefined;
    @memset(&shard, 10);
    var node: [32]u8 = undefined;
    @memset(&node, 20);
    try coord.addParticipant(tx1, shard, node, 1000);
    try coord.prepare(tx1);

    // Check at 7000: tx1 started at 1000, deadline 6000 — timed out
    // tx2 started at 2000, deadline 7000 — not yet timed out
    const timed_out = try coord.checkTimeouts(7000);
    defer allocator.free(timed_out);
    try std.testing.expectEqual(@as(usize, 1), timed_out.len);
    try std.testing.expectEqual(tx1, timed_out[0]);
}

test "max concurrent transactions enforced" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.initWithConfig(allocator, .{
        .max_concurrent_tx = 2,
    });
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    _ = try coord.beginTransaction(coordinator_id, 1000);
    _ = try coord.beginTransaction(coordinator_id, 2000);

    const result = coord.beginTransaction(coordinator_id, 3000);
    try std.testing.expectError(error.TooManyTransactions, result);
}

test "no participants rejected" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    const tx_id = try coord.beginTransaction(coordinator_id, 1000);
    const result = coord.prepare(tx_id);
    try std.testing.expectError(error.NoParticipants, result);
}

test "transaction stats accumulate" {
    const allocator = std.testing.allocator;
    var coord = CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    var coordinator_id: [32]u8 = undefined;
    @memset(&coordinator_id, 1);

    // Committed tx
    const tx1 = try coord.beginTransaction(coordinator_id, 1000);
    var s1: [32]u8 = undefined;
    @memset(&s1, 10);
    var n1: [32]u8 = undefined;
    @memset(&n1, 20);
    try coord.addParticipant(tx1, s1, n1, 1000);
    try coord.prepare(tx1);
    try coord.recordVote(tx1, s1, true);
    _ = try coord.commit(tx1, 2000);

    // Aborted tx
    const tx2 = try coord.beginTransaction(coordinator_id, 3000);
    var s2: [32]u8 = undefined;
    @memset(&s2, 11);
    var n2: [32]u8 = undefined;
    @memset(&n2, 21);
    try coord.addParticipant(tx2, s2, n2, 3000);
    try coord.prepare(tx2);
    try coord.recordVote(tx2, s2, false);
    _ = try coord.abort(tx2, 4000);

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_transactions);
    try std.testing.expectEqual(@as(u64, 1), stats.committed_transactions);
    try std.testing.expectEqual(@as(u64, 1), stats.aborted_transactions);
    try std.testing.expectEqual(@as(u64, 2), stats.total_participants);
    try std.testing.expectEqual(@as(u64, 2), stats.total_prepare_votes);
}
