// Trinity Storage Network v2.4 — Transaction Write-Ahead Log
// Durable log for crash recovery of in-flight sagas and 2PC operations
// Write-before-act: log event → transition state → confirm
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");

/// WAL magic bytes for record validation
pub const WAL_MAGIC: [4]u8 = .{ 'W', 'A', 'L', '!' };

/// WAL record header size (magic + event_type + sequence + timestamp + payload_len + checksum)
pub const WAL_HEADER_SIZE: usize = 4 + 1 + 8 + 8 + 4 + 4; // 29 bytes

/// Types of events logged to the WAL
pub const WalEventType = enum(u8) {
    // Saga events (0x01–0x0F)
    saga_created = 0x01,
    saga_step_added = 0x02,
    saga_execute_start = 0x03,
    saga_step_succeeded = 0x04,
    saga_step_failed = 0x05,
    saga_compensation_start = 0x06,
    saga_compensation_succeeded = 0x07,
    saga_compensation_failed = 0x08,
    saga_completed = 0x09,
    saga_compensated = 0x0A,
    saga_aborted = 0x0B,

    // 2PC events (0x10–0x1F)
    tx_created = 0x10,
    tx_participant_added = 0x11,
    tx_prepare_start = 0x12,
    tx_vote_received = 0x13,
    tx_commit_start = 0x14,
    tx_commit_complete = 0x15,
    tx_abort_start = 0x16,
    tx_abort_complete = 0x17,
    tx_rollback_start = 0x18,
    tx_rollback_complete = 0x19,

    // WAL management (0xF0–0xFF)
    checkpoint = 0xF0,
};

/// A single WAL record (in-memory representation)
pub const WalRecord = struct {
    magic: [4]u8,
    event_type: WalEventType,
    sequence: u64,
    timestamp: i64,
    payload_len: u32,
    checksum: u32, // CRC32 of payload
    payload: []const u8,
};

/// WAL configuration
pub const WalConfig = struct {
    max_records: u64 = 1_000_000,
    max_payload_size: u32 = 4096,
    checkpoint_interval: u64 = 10_000, // Checkpoint every N records
    enable_checksums: bool = true,
};

/// Recovery action determined during WAL replay
pub const RecoveryAction = enum(u8) {
    saga_resume_execute, // Resume forward execution
    saga_resume_compensate, // Resume compensation
    saga_complete, // Already completed, skip
    tx_resume_commit, // Resume 2PC commit
    tx_resume_abort, // Resume 2PC abort
    tx_complete, // Already completed, skip
    no_action, // Nothing to do
};

/// Recovery entry for a single saga or transaction
pub const RecoveryEntry = struct {
    id: u64, // saga_id or tx_id
    is_saga: bool, // true = saga, false = 2PC tx
    action: RecoveryAction,
    last_sequence: u64,
    coordinator_id: [32]u8,
    step_count: u32, // For sagas: number of steps
    steps_succeeded: u32, // For sagas: completed forward steps
    timestamp: i64,
};

/// Recovery report after WAL replay
pub const RecoveryReport = struct {
    total_records_replayed: u64,
    sagas_recovered: u32,
    txs_recovered: u32,
    sagas_already_complete: u32,
    txs_already_complete: u32,
    checkpoints_found: u32,
    corrupted_records: u32,
    recovery_entries: std.ArrayList(RecoveryEntry),
};

/// WAL statistics
pub const WalStats = struct {
    total_records_written: u64,
    total_bytes_written: u64,
    saga_events: u64,
    tx_events: u64,
    checkpoints: u64,
    corrupted_on_recovery: u64,
    recoveries_performed: u64,
    last_sequence: u64,
    last_checkpoint_seq: u64,
};

/// Transaction Write-Ahead Log
/// Provides durable logging for crash recovery of sagas and 2PC transactions
pub const TransactionWal = struct {
    allocator: std.mem.Allocator,
    config: WalConfig,
    records: std.ArrayList(WalRecord),
    next_sequence: u64,
    stats: WalStats,
    // Track active (incomplete) operations
    active_sagas: std.AutoHashMap(u64, SagaWalState),
    active_txs: std.AutoHashMap(u64, TxWalState),
    // Completed IDs (for checkpoint trimming)
    completed_ids: std.AutoHashMap(u64, bool), // id → is_saga

    const Self = @This();

    /// In-memory saga state reconstructed from WAL
    pub const SagaWalState = struct {
        saga_id: u64,
        coordinator_id: [32]u8,
        phase: u8, // 0=created, 1=executing, 2=compensating, 3=completed, 4=compensated, 5=failed
        step_count: u32,
        steps_succeeded: u32,
        steps_compensated: u32,
        compensation_failures: u32,
        created_at: i64,
        last_event_seq: u64,
    };

    /// In-memory 2PC state reconstructed from WAL
    pub const TxWalState = struct {
        tx_id: u64,
        coordinator_id: [32]u8,
        phase: u8, // 0=created, 1=preparing, 2=prepared, 3=committing, 4=committed, 5=aborting, 6=aborted, 7=rolled_back
        participant_count: u32,
        votes_commit: u32,
        votes_abort: u32,
        commit_acks: u32,
        created_at: i64,
        last_event_seq: u64,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: WalConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .records = .empty,
            .next_sequence = 1,
            .stats = .{
                .total_records_written = 0,
                .total_bytes_written = 0,
                .saga_events = 0,
                .tx_events = 0,
                .checkpoints = 0,
                .corrupted_on_recovery = 0,
                .recoveries_performed = 0,
                .last_sequence = 0,
                .last_checkpoint_seq = 0,
            },
            .active_sagas = std.AutoHashMap(u64, SagaWalState).init(allocator),
            .active_txs = std.AutoHashMap(u64, TxWalState).init(allocator),
            .completed_ids = std.AutoHashMap(u64, bool).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.records.items) |rec| {
            if (rec.payload.len > 0) {
                self.allocator.free(rec.payload);
            }
        }
        self.records.deinit(self.allocator);
        self.active_sagas.deinit();
        self.active_txs.deinit();
        self.completed_ids.deinit();
    }

    /// Compute CRC32 checksum of payload
    fn computeChecksum(payload: []const u8) u32 {
        if (payload.len == 0) return 0;
        var crc: u32 = 0xFFFFFFFF;
        for (payload) |byte| {
            crc ^= @as(u32, byte);
            for (0..8) |_| {
                if (crc & 1 == 1) {
                    crc = (crc >> 1) ^ 0xEDB88320;
                } else {
                    crc = crc >> 1;
                }
            }
        }
        return crc ^ 0xFFFFFFFF;
    }

    /// Serialize a WAL record to bytes
    pub fn serializeRecord(self: *Self, record: WalRecord) ![]u8 {
        const total_size = WAL_HEADER_SIZE + record.payload_len;
        const buf = try self.allocator.alloc(u8, total_size);

        var i: usize = 0;
        // Magic
        @memcpy(buf[i..][0..4], &record.magic);
        i += 4;
        // Event type
        buf[i] = @intFromEnum(record.event_type);
        i += 1;
        // Sequence
        std.mem.writeInt(u64, buf[i..][0..8], record.sequence, .little);
        i += 8;
        // Timestamp
        std.mem.writeInt(i64, buf[i..][0..8], record.timestamp, .little);
        i += 8;
        // Payload length
        std.mem.writeInt(u32, buf[i..][0..4], record.payload_len, .little);
        i += 4;
        // Checksum
        std.mem.writeInt(u32, buf[i..][0..4], record.checksum, .little);
        i += 4;
        // Payload
        if (record.payload_len > 0) {
            @memcpy(buf[i..][0..record.payload_len], record.payload[0..record.payload_len]);
        }

        return buf;
    }

    /// Deserialize a WAL record from bytes
    pub fn deserializeRecord(_: *Self, data: []const u8) !WalRecord {
        if (data.len < WAL_HEADER_SIZE) return error.InvalidData;

        var record: WalRecord = undefined;
        var i: usize = 0;

        // Magic
        @memcpy(&record.magic, data[i..][0..4]);
        i += 4;
        if (!std.mem.eql(u8, &record.magic, &WAL_MAGIC)) return error.InvalidMagic;

        // Event type
        record.event_type = @enumFromInt(data[i]);
        i += 1;

        // Sequence
        record.sequence = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;

        // Timestamp
        record.timestamp = std.mem.readInt(i64, data[i..][0..8], .little);
        i += 8;

        // Payload length
        record.payload_len = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;

        // Checksum
        record.checksum = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;

        // Payload
        if (data.len < WAL_HEADER_SIZE + record.payload_len) return error.InvalidData;
        record.payload = data[i .. i + record.payload_len];

        return record;
    }

    /// Write a WAL record (the core write-ahead operation)
    pub fn writeRecord(self: *Self, event_type: WalEventType, timestamp: i64, payload: []const u8) !u64 {
        if (payload.len > self.config.max_payload_size) return error.PayloadTooLarge;

        const seq = self.next_sequence;
        self.next_sequence += 1;

        const checksum: u32 = if (self.config.enable_checksums) computeChecksum(payload) else 0;

        // Copy payload for storage
        const payload_copy = try self.allocator.alloc(u8, payload.len);
        @memcpy(payload_copy, payload);

        const record = WalRecord{
            .magic = WAL_MAGIC,
            .event_type = event_type,
            .sequence = seq,
            .timestamp = timestamp,
            .payload_len = @intCast(payload.len),
            .checksum = checksum,
            .payload = payload_copy,
        };

        try self.records.append(self.allocator, record);

        // Update stats
        self.stats.total_records_written += 1;
        self.stats.total_bytes_written += WAL_HEADER_SIZE + payload.len;
        self.stats.last_sequence = seq;

        const evt_u8 = @intFromEnum(event_type);
        if (evt_u8 >= 0x01 and evt_u8 <= 0x0F) {
            self.stats.saga_events += 1;
        } else if (evt_u8 >= 0x10 and evt_u8 <= 0x1F) {
            self.stats.tx_events += 1;
        } else if (event_type == .checkpoint) {
            self.stats.checkpoints += 1;
            self.stats.last_checkpoint_seq = seq;
        }

        return seq;
    }

    // ===== SAGA WAL OPERATIONS =====

    /// Log saga creation
    pub fn logSagaCreated(self: *Self, saga_id: u64, coordinator_id: [32]u8, timestamp: i64) !u64 {
        var payload: [40]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        @memcpy(payload[8..40], &coordinator_id);

        const seq = try self.writeRecord(.saga_created, timestamp, &payload);

        try self.active_sagas.put(saga_id, .{
            .saga_id = saga_id,
            .coordinator_id = coordinator_id,
            .phase = 0, // created
            .step_count = 0,
            .steps_succeeded = 0,
            .steps_compensated = 0,
            .compensation_failures = 0,
            .created_at = timestamp,
            .last_event_seq = seq,
        });

        return seq;
    }

    /// Log saga step added
    pub fn logSagaStepAdded(self: *Self, saga_id: u64, step_index: u32, action: u8, timestamp: i64) !u64 {
        var payload: [13]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        payload[12] = action;

        const seq = try self.writeRecord(.saga_step_added, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.step_count += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log saga execution start
    pub fn logSagaExecuteStart(self: *Self, saga_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);

        const seq = try self.writeRecord(.saga_execute_start, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 1; // executing
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log saga step succeeded
    pub fn logSagaStepSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) !u64 {
        var payload: [12]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);

        const seq = try self.writeRecord(.saga_step_succeeded, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.steps_succeeded += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log saga step failed
    pub fn logSagaStepFailed(self: *Self, saga_id: u64, step_index: u32, error_code: u32, timestamp: i64) !u64 {
        var payload: [16]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        std.mem.writeInt(u32, payload[12..16], error_code, .little);

        const seq = try self.writeRecord(.saga_step_failed, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 2; // compensating
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log saga compensation succeeded for a step
    pub fn logSagaCompensationSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) !u64 {
        var payload: [12]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);

        const seq = try self.writeRecord(.saga_compensation_succeeded, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.steps_compensated += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log saga compensation failed for a step
    pub fn logSagaCompensationFailed(self: *Self, saga_id: u64, step_index: u32, retry_count: u32, timestamp: i64) !u64 {
        var payload: [16]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        std.mem.writeInt(u32, payload[12..16], retry_count, .little);

        const seq = try self.writeRecord(.saga_compensation_failed, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.compensation_failures += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log saga completed successfully
    pub fn logSagaCompleted(self: *Self, saga_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);

        const seq = try self.writeRecord(.saga_completed, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 3; // completed
            state.last_event_seq = seq;
        }
        _ = self.active_sagas.remove(saga_id);
        try self.completed_ids.put(saga_id, true);

        return seq;
    }

    /// Log saga fully compensated
    pub fn logSagaCompensated(self: *Self, saga_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);

        const seq = try self.writeRecord(.saga_compensated, timestamp, &payload);

        if (self.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 4; // compensated
            state.last_event_seq = seq;
        }
        _ = self.active_sagas.remove(saga_id);
        try self.completed_ids.put(saga_id, true);

        return seq;
    }

    // ===== 2PC WAL OPERATIONS =====

    /// Log 2PC transaction created
    pub fn logTxCreated(self: *Self, tx_id: u64, coordinator_id: [32]u8, timestamp: i64) !u64 {
        var payload: [40]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        @memcpy(payload[8..40], &coordinator_id);

        const seq = try self.writeRecord(.tx_created, timestamp, &payload);

        try self.active_txs.put(tx_id, .{
            .tx_id = tx_id,
            .coordinator_id = coordinator_id,
            .phase = 0, // created
            .participant_count = 0,
            .votes_commit = 0,
            .votes_abort = 0,
            .commit_acks = 0,
            .created_at = timestamp,
            .last_event_seq = seq,
        });

        return seq;
    }

    /// Log 2PC participant added
    pub fn logTxParticipantAdded(self: *Self, tx_id: u64, shard_hash: [32]u8, node_id: [32]u8, timestamp: i64) !u64 {
        var payload: [72]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        @memcpy(payload[8..40], &shard_hash);
        @memcpy(payload[40..72], &node_id);

        const seq = try self.writeRecord(.tx_participant_added, timestamp, &payload);

        if (self.active_txs.getPtr(tx_id)) |state| {
            state.participant_count += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log 2PC prepare start
    pub fn logTxPrepareStart(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);

        const seq = try self.writeRecord(.tx_prepare_start, timestamp, &payload);

        if (self.active_txs.getPtr(tx_id)) |state| {
            state.phase = 1; // preparing
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log 2PC vote received
    pub fn logTxVoteReceived(self: *Self, tx_id: u64, shard_hash: [32]u8, vote_commit: bool, timestamp: i64) !u64 {
        var payload: [41]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        @memcpy(payload[8..40], &shard_hash);
        payload[40] = if (vote_commit) 1 else 0;

        const seq = try self.writeRecord(.tx_vote_received, timestamp, &payload);

        if (self.active_txs.getPtr(tx_id)) |state| {
            if (vote_commit) {
                state.votes_commit += 1;
            } else {
                state.votes_abort += 1;
            }
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log 2PC commit start
    pub fn logTxCommitStart(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);

        const seq = try self.writeRecord(.tx_commit_start, timestamp, &payload);

        if (self.active_txs.getPtr(tx_id)) |state| {
            state.phase = 3; // committing
            state.last_event_seq = seq;
        }

        return seq;
    }

    /// Log 2PC commit complete
    pub fn logTxCommitComplete(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);

        const seq = try self.writeRecord(.tx_commit_complete, timestamp, &payload);

        if (self.active_txs.getPtr(tx_id)) |state| {
            state.phase = 4; // committed
            state.last_event_seq = seq;
        }
        _ = self.active_txs.remove(tx_id);
        try self.completed_ids.put(tx_id, false);

        return seq;
    }

    /// Log 2PC abort complete
    pub fn logTxAbortComplete(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);

        const seq = try self.writeRecord(.tx_abort_complete, timestamp, &payload);

        if (self.active_txs.getPtr(tx_id)) |state| {
            state.phase = 6; // aborted
            state.last_event_seq = seq;
        }
        _ = self.active_txs.remove(tx_id);
        try self.completed_ids.put(tx_id, false);

        return seq;
    }

    // ===== CHECKPOINT & RECOVERY =====

    /// Write a checkpoint marker (allows trimming old records on recovery)
    pub fn writeCheckpoint(self: *Self, timestamp: i64) !u64 {
        // Payload: number of active sagas + txs
        var payload: [16]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], self.active_sagas.count(), .little);
        std.mem.writeInt(u64, payload[8..16], self.active_txs.count(), .little);

        return try self.writeRecord(.checkpoint, timestamp, &payload);
    }

    /// Recover state by replaying WAL records
    /// Returns a RecoveryReport with actions needed for incomplete operations
    pub fn recover(self: *Self) !RecoveryReport {
        var report = RecoveryReport{
            .total_records_replayed = 0,
            .sagas_recovered = 0,
            .txs_recovered = 0,
            .sagas_already_complete = 0,
            .txs_already_complete = 0,
            .checkpoints_found = 0,
            .corrupted_records = 0,
            .recovery_entries = .empty,
        };

        // Replay all records to reconstruct state
        for (self.records.items) |record| {
            report.total_records_replayed += 1;

            // Verify checksum
            if (self.config.enable_checksums and record.payload_len > 0) {
                const expected = computeChecksum(record.payload);
                if (expected != record.checksum) {
                    report.corrupted_records += 1;
                    self.stats.corrupted_on_recovery += 1;
                    continue;
                }
            }

            if (record.event_type == .checkpoint) {
                report.checkpoints_found += 1;
            }
        }

        // Determine recovery actions for active sagas
        var saga_it = self.active_sagas.iterator();
        while (saga_it.next()) |kv| {
            const state = kv.value_ptr;
            const action: RecoveryAction = switch (state.phase) {
                0 => .no_action, // created but not started — nothing to recover
                1 => .saga_resume_execute, // executing — resume from last step
                2 => .saga_resume_compensate, // compensating — resume compensation
                3 => blk: {
                    report.sagas_already_complete += 1;
                    break :blk .saga_complete;
                },
                4 => blk: {
                    report.sagas_already_complete += 1;
                    break :blk .saga_complete;
                },
                else => .no_action,
            };

            if (action != .saga_complete and action != .no_action) {
                report.sagas_recovered += 1;
            }

            try report.recovery_entries.append(self.allocator, .{
                .id = state.saga_id,
                .is_saga = true,
                .action = action,
                .last_sequence = state.last_event_seq,
                .coordinator_id = state.coordinator_id,
                .step_count = state.step_count,
                .steps_succeeded = state.steps_succeeded,
                .timestamp = state.created_at,
            });
        }

        // Determine recovery actions for active 2PC transactions
        var tx_it = self.active_txs.iterator();
        while (tx_it.next()) |kv| {
            const state = kv.value_ptr;
            const action: RecoveryAction = switch (state.phase) {
                0 => .no_action, // created — nothing to recover
                1 => .tx_resume_abort, // preparing — timeout, abort
                2 => .tx_resume_commit, // prepared (all voted commit) — must commit
                3 => .tx_resume_commit, // committing — resume commit
                4 => blk: {
                    report.txs_already_complete += 1;
                    break :blk .tx_complete;
                },
                5 => .tx_resume_abort, // aborting — resume abort
                6 => blk: {
                    report.txs_already_complete += 1;
                    break :blk .tx_complete;
                },
                else => .no_action,
            };

            if (action != .tx_complete and action != .no_action) {
                report.txs_recovered += 1;
            }

            try report.recovery_entries.append(self.allocator, .{
                .id = state.tx_id,
                .is_saga = false,
                .action = action,
                .last_sequence = state.last_event_seq,
                .coordinator_id = state.coordinator_id,
                .step_count = state.participant_count,
                .steps_succeeded = state.commit_acks,
                .timestamp = state.created_at,
            });
        }

        self.stats.recoveries_performed += 1;
        return report;
    }

    /// Get count of active (incomplete) operations
    pub fn getActiveCount(self: *const Self) u32 {
        return @intCast(self.active_sagas.count() + self.active_txs.count());
    }

    /// Check if an operation is complete
    pub fn isComplete(self: *const Self, id: u64) bool {
        return self.completed_ids.contains(id);
    }

    pub fn getStats(self: *const Self) WalStats {
        return self.stats;
    }
};

// ============================================================
// Unit Tests
// ============================================================

test "wal — init and config" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const stats = wal.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.total_records_written);
    try std.testing.expectEqual(@as(u64, 0), stats.last_sequence);
    try std.testing.expectEqual(@as(u32, 0), wal.getActiveCount());
}

test "wal — saga lifecycle logging" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xAA} ** 32;

    // Log saga creation
    const seq1 = try wal.logSagaCreated(1, coord_id, 1000);
    try std.testing.expectEqual(@as(u64, 1), seq1);
    try std.testing.expectEqual(@as(u32, 1), wal.getActiveCount());

    // Log steps
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 1100); // shard_write
    _ = try wal.logSagaStepAdded(1, 1, 0x03, 1200); // lock_acquire

    // Log execution
    _ = try wal.logSagaExecuteStart(1, 2000);
    _ = try wal.logSagaStepSucceeded(1, 0, 2100);
    _ = try wal.logSagaStepSucceeded(1, 1, 2200);

    // Log completion
    _ = try wal.logSagaCompleted(1, 2300);

    try std.testing.expectEqual(@as(u32, 0), wal.getActiveCount());
    try std.testing.expect(wal.isComplete(1));

    const stats = wal.getStats();
    try std.testing.expectEqual(@as(u64, 7), stats.total_records_written);
    try std.testing.expectEqual(@as(u64, 7), stats.saga_events);
}

test "wal — saga compensation logging" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xBB} ** 32;

    _ = try wal.logSagaCreated(1, coord_id, 1000);
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wal.logSagaStepAdded(1, 1, 0x02, 1200);
    _ = try wal.logSagaExecuteStart(1, 2000);
    _ = try wal.logSagaStepSucceeded(1, 0, 2100);
    _ = try wal.logSagaStepFailed(1, 1, 500, 2200);

    // Verify phase is compensating
    const state = wal.active_sagas.get(1).?;
    try std.testing.expectEqual(@as(u8, 2), state.phase); // compensating

    _ = try wal.logSagaCompensationSucceeded(1, 0, 2300);
    _ = try wal.logSagaCompensated(1, 2400);

    try std.testing.expectEqual(@as(u32, 0), wal.getActiveCount());
    try std.testing.expect(wal.isComplete(1));
}

test "wal — 2PC lifecycle logging" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xCC} ** 32;
    const shard1 = [_]u8{0x01} ** 32;
    const shard2 = [_]u8{0x02} ** 32;
    const node1 = [_]u8{0xD1} ** 32;
    const node2 = [_]u8{0xD2} ** 32;

    _ = try wal.logTxCreated(1, coord_id, 1000);
    try std.testing.expectEqual(@as(u32, 1), wal.getActiveCount());

    _ = try wal.logTxParticipantAdded(1, shard1, node1, 1100);
    _ = try wal.logTxParticipantAdded(1, shard2, node2, 1200);

    _ = try wal.logTxPrepareStart(1, 2000);
    _ = try wal.logTxVoteReceived(1, shard1, true, 2100);
    _ = try wal.logTxVoteReceived(1, shard2, true, 2200);

    _ = try wal.logTxCommitStart(1, 3000);
    _ = try wal.logTxCommitComplete(1, 3100);

    try std.testing.expectEqual(@as(u32, 0), wal.getActiveCount());
    try std.testing.expect(wal.isComplete(1));

    const stats = wal.getStats();
    try std.testing.expectEqual(@as(u64, 8), stats.tx_events);
}

test "wal — 2PC abort logging" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xDD} ** 32;
    const shard1 = [_]u8{0x01} ** 32;
    const node1 = [_]u8{0xE1} ** 32;

    _ = try wal.logTxCreated(1, coord_id, 1000);
    _ = try wal.logTxParticipantAdded(1, shard1, node1, 1100);
    _ = try wal.logTxPrepareStart(1, 2000);
    _ = try wal.logTxVoteReceived(1, shard1, false, 2100); // vote abort

    _ = try wal.logTxAbortComplete(1, 3000);

    try std.testing.expect(wal.isComplete(1));
    const tx_state = wal.active_txs.get(1);
    try std.testing.expect(tx_state == null); // removed after completion
}

test "wal — recovery of incomplete saga" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xAA} ** 32;

    // Saga 1: executing (incomplete — crash before completion)
    _ = try wal.logSagaCreated(1, coord_id, 1000);
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wal.logSagaStepAdded(1, 1, 0x02, 1200);
    _ = try wal.logSagaExecuteStart(1, 2000);
    _ = try wal.logSagaStepSucceeded(1, 0, 2100);
    // Step 1 never completed — simulates crash

    // Saga 2: completed normally
    _ = try wal.logSagaCreated(2, coord_id, 3000);
    _ = try wal.logSagaStepAdded(2, 0, 0x01, 3100);
    _ = try wal.logSagaExecuteStart(2, 4000);
    _ = try wal.logSagaStepSucceeded(2, 0, 4100);
    _ = try wal.logSagaCompleted(2, 4200);

    // Run recovery
    var report = try wal.recover();
    defer report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 10), report.total_records_replayed);
    try std.testing.expectEqual(@as(u32, 1), report.sagas_recovered); // saga 1

    // Find saga 1 recovery entry
    var found_saga1 = false;
    for (report.recovery_entries.items) |entry| {
        if (entry.id == 1 and entry.is_saga) {
            try std.testing.expectEqual(RecoveryAction.saga_resume_execute, entry.action);
            try std.testing.expectEqual(@as(u32, 1), entry.steps_succeeded);
            found_saga1 = true;
        }
    }
    try std.testing.expect(found_saga1);
}

test "wal — recovery of incomplete 2PC" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xBB} ** 32;
    const shard1 = [_]u8{0x01} ** 32;
    const shard2 = [_]u8{0x02} ** 32;
    const node1 = [_]u8{0xC1} ** 32;
    const node2 = [_]u8{0xC2} ** 32;

    // TX 1: committing phase (crash after commit_start, before commit_complete)
    _ = try wal.logTxCreated(1, coord_id, 1000);
    _ = try wal.logTxParticipantAdded(1, shard1, node1, 1100);
    _ = try wal.logTxParticipantAdded(1, shard2, node2, 1200);
    _ = try wal.logTxPrepareStart(1, 2000);
    _ = try wal.logTxVoteReceived(1, shard1, true, 2100);
    _ = try wal.logTxVoteReceived(1, shard2, true, 2200);
    _ = try wal.logTxCommitStart(1, 3000);
    // Crash here — commit not complete

    // TX 2: completed
    _ = try wal.logTxCreated(2, coord_id, 4000);
    _ = try wal.logTxParticipantAdded(2, shard1, node1, 4100);
    _ = try wal.logTxPrepareStart(2, 5000);
    _ = try wal.logTxVoteReceived(2, shard1, true, 5100);
    _ = try wal.logTxCommitStart(2, 6000);
    _ = try wal.logTxCommitComplete(2, 6100);

    var report = try wal.recover();
    defer report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 1), report.txs_recovered); // tx 1

    var found_tx1 = false;
    for (report.recovery_entries.items) |entry| {
        if (entry.id == 1 and !entry.is_saga) {
            try std.testing.expectEqual(RecoveryAction.tx_resume_commit, entry.action);
            try std.testing.expectEqual(@as(u32, 2), entry.step_count); // 2 participants
            found_tx1 = true;
        }
    }
    try std.testing.expect(found_tx1);
}

test "wal — serialize and deserialize record" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xAA} ** 32;
    _ = try wal.logSagaCreated(42, coord_id, 9999);

    const record = wal.records.items[0];
    const bytes = try wal.serializeRecord(record);
    defer allocator.free(bytes);

    var deserialized = try wal.deserializeRecord(bytes);
    try std.testing.expectEqual(WalEventType.saga_created, deserialized.event_type);
    try std.testing.expectEqual(@as(u64, 1), deserialized.sequence);
    try std.testing.expectEqual(@as(i64, 9999), deserialized.timestamp);
    try std.testing.expectEqual(@as(u32, 40), deserialized.payload_len);

    // Verify payload contains saga_id
    const saga_id = std.mem.readInt(u64, deserialized.payload[0..8], .little);
    try std.testing.expectEqual(@as(u64, 42), saga_id);
}

test "wal — checksum detects corruption" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.initWithConfig(allocator, .{
        .enable_checksums = true,
    });
    defer wal.deinit();

    const coord_id = [_]u8{0xAA} ** 32;

    // Normal saga
    _ = try wal.logSagaCreated(1, coord_id, 1000);
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wal.logSagaExecuteStart(1, 2000);

    // Corrupt the second record's checksum
    wal.records.items[1].checksum = 0xDEADBEEF;

    var report = try wal.recover();
    defer report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 1), report.corrupted_records);
}

test "wal — checkpoint" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xAA} ** 32;
    _ = try wal.logSagaCreated(1, coord_id, 1000);

    const cp_seq = try wal.writeCheckpoint(2000);
    try std.testing.expect(cp_seq > 0);

    const stats = wal.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.checkpoints);
    try std.testing.expectEqual(cp_seq, stats.last_checkpoint_seq);
}

test "wal — mixed saga and 2PC operations" {
    const allocator = std.testing.allocator;
    var wal = TransactionWal.init(allocator);
    defer wal.deinit();

    const coord_id = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    // Saga
    _ = try wal.logSagaCreated(1, coord_id, 1000);
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wal.logSagaExecuteStart(1, 2000);
    _ = try wal.logSagaStepSucceeded(1, 0, 2100);
    _ = try wal.logSagaCompleted(1, 2200);

    // 2PC
    _ = try wal.logTxCreated(2, coord_id, 3000);
    _ = try wal.logTxParticipantAdded(2, shard, node, 3100);
    _ = try wal.logTxPrepareStart(2, 4000);
    _ = try wal.logTxVoteReceived(2, shard, true, 4100);
    _ = try wal.logTxCommitStart(2, 5000);
    _ = try wal.logTxCommitComplete(2, 5100);

    try std.testing.expectEqual(@as(u32, 0), wal.getActiveCount());
    try std.testing.expect(wal.isComplete(1));
    try std.testing.expect(wal.isComplete(2));

    const stats = wal.getStats();
    try std.testing.expectEqual(@as(u64, 5), stats.saga_events);
    try std.testing.expectEqual(@as(u64, 6), stats.tx_events);
    try std.testing.expectEqual(@as(u64, 11), stats.total_records_written);
}
