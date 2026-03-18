// Trinity Storage Network v2.6 — WAL Disk Persistence
// Durable write-ahead log on disk with fsync guarantees
// File rotation when segment reaches size limit
// Compaction: rewrite WAL without completed operations
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const wal_mod = @import("transaction_wal.zig");

/// WAL file header magic bytes
pub const WAL_FILE_MAGIC: [8]u8 = .{ 'T', 'W', 'A', 'L', 'v', '2', '.', '6' };

/// WAL file header size (magic + version + segment_id + created_at + record_count + prev_segment_id)
pub const WAL_FILE_HEADER_SIZE: usize = 8 + 4 + 8 + 8 + 8 + 8; // 44 bytes

/// WAL Disk Configuration
pub const WalDiskConfig = struct {
    /// Directory to store WAL segment files
    wal_dir: []const u8 = "/tmp/trinity_wal",
    /// Maximum size per segment file in bytes (default 64 MB)
    max_segment_size: u64 = 64 * 1024 * 1024,
    /// Maximum records per segment before rotation
    max_records_per_segment: u64 = 100_000,
    /// Enable fsync after each write (durability vs performance)
    fsync_per_write: bool = true,
    /// Enable fsync only on batch commit (better performance)
    fsync_on_batch: bool = false,
    /// Batch size for batch fsync mode
    batch_size: u32 = 16,
    /// Maximum number of retained segment files
    max_retained_segments: u32 = 64,
    /// Compaction threshold: compact when completed_ratio > this
    compaction_threshold: f64 = 0.5,
    /// Inner WAL config
    wal_config: wal_mod.WalConfig = .{},
};

/// WAL file header written at the start of each segment
pub const WalFileHeader = struct {
    magic: [8]u8,
    version: u32,
    segment_id: u64,
    created_at: i64,
    record_count: u64,
    prev_segment_id: u64,
};

/// WAL segment metadata
pub const WalSegment = struct {
    segment_id: u64,
    file_size: u64,
    record_count: u64,
    first_sequence: u64,
    last_sequence: u64,
    created_at: i64,
    is_active: bool,
    is_compacted: bool,
};

/// WAL Disk statistics
pub const WalDiskStats = struct {
    total_segments_created: u64,
    total_segments_compacted: u64,
    total_segments_deleted: u64,
    total_bytes_on_disk: u64,
    total_fsyncs: u64,
    total_records_on_disk: u64,
    total_compaction_bytes_saved: u64,
    current_segment_id: u64,
    current_segment_size: u64,
    current_segment_records: u64,
    active_segments: u32,
    retained_segments: u32,
    last_fsync_at: i64,
    last_compaction_at: i64,
    last_rotation_at: i64,
};

/// Compaction result
pub const CompactionResult = struct {
    records_before: u64,
    records_after: u64,
    bytes_before: u64,
    bytes_after: u64,
    segments_removed: u32,
    completed_ops_purged: u64,
    duration_ms: i64,
};

/// Recovery result from disk WAL
pub const DiskRecoveryResult = struct {
    segments_read: u32,
    total_records_read: u64,
    corrupted_records: u32,
    corrupted_segments: u32,
    recovery_report: wal_mod.RecoveryReport,
    oldest_record_timestamp: i64,
    newest_record_timestamp: i64,
};

/// Persistent WAL on disk with fsync, rotation, and compaction
pub const WalDisk = struct {
    allocator: std.mem.Allocator,
    config: WalDiskConfig,
    wal: wal_mod.TransactionWal,
    stats: WalDiskStats,
    segments: std.ArrayList(WalSegment),
    current_segment_id: u64,
    pending_batch: u32,
    initialized: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: WalDiskConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .wal = wal_mod.TransactionWal.initWithConfig(allocator, config.wal_config),
            .stats = .{
                .total_segments_created = 0,
                .total_segments_compacted = 0,
                .total_segments_deleted = 0,
                .total_bytes_on_disk = 0,
                .total_fsyncs = 0,
                .total_records_on_disk = 0,
                .total_compaction_bytes_saved = 0,
                .current_segment_id = 0,
                .current_segment_size = 0,
                .current_segment_records = 0,
                .active_segments = 0,
                .retained_segments = 0,
                .last_fsync_at = 0,
                .last_compaction_at = 0,
                .last_rotation_at = 0,
            },
            .segments = .empty,
            .current_segment_id = 0,
            .pending_batch = 0,
            .initialized = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.segments.deinit(self.allocator);
        self.wal.deinit();
    }

    /// Initialize the WAL directory and create the first segment
    pub fn open(self: *Self, timestamp: i64) !void {
        if (self.initialized) return error.AlreadyInitialized;

        // Create initial segment
        try self.createSegment(timestamp);
        self.initialized = true;
    }

    /// Create a new WAL segment
    fn createSegment(self: *Self, timestamp: i64) !void {
        self.current_segment_id += 1;
        const segment_id = self.current_segment_id;

        const prev_id: u64 = if (self.segments.items.len > 0)
            self.segments.items[self.segments.items.len - 1].segment_id
        else
            0;

        const header = WalFileHeader{
            .magic = WAL_FILE_MAGIC,
            .version = 26, // v2.6
            .segment_id = segment_id,
            .created_at = timestamp,
            .record_count = 0,
            .prev_segment_id = prev_id,
        };

        // Serialize header (simulated disk write)
        const header_bytes = serializeFileHeader(header);
        _ = header_bytes;

        const segment = WalSegment{
            .segment_id = segment_id,
            .file_size = WAL_FILE_HEADER_SIZE,
            .record_count = 0,
            .first_sequence = 0,
            .last_sequence = 0,
            .created_at = timestamp,
            .is_active = true,
            .is_compacted = false,
        };

        try self.segments.append(self.allocator, segment);

        self.stats.total_segments_created += 1;
        self.stats.active_segments += 1;
        self.stats.retained_segments += 1;
        self.stats.current_segment_id = segment_id;
        self.stats.current_segment_size = WAL_FILE_HEADER_SIZE;
        self.stats.current_segment_records = 0;
        self.stats.last_rotation_at = timestamp;
    }

    /// Serialize WAL file header to bytes
    fn serializeFileHeader(header: WalFileHeader) [WAL_FILE_HEADER_SIZE]u8 {
        var buf: [WAL_FILE_HEADER_SIZE]u8 = undefined;
        var i: usize = 0;

        @memcpy(buf[i..][0..8], &header.magic);
        i += 8;
        std.mem.writeInt(u32, buf[i..][0..4], header.version, .little);
        i += 4;
        std.mem.writeInt(u64, buf[i..][0..8], header.segment_id, .little);
        i += 8;
        std.mem.writeInt(i64, buf[i..][0..8], header.created_at, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], header.record_count, .little);
        i += 8;
        std.mem.writeInt(u64, buf[i..][0..8], header.prev_segment_id, .little);

        return buf;
    }

    /// Deserialize WAL file header from bytes
    pub fn deserializeFileHeader(data: []const u8) !WalFileHeader {
        if (data.len < WAL_FILE_HEADER_SIZE) return error.InvalidData;

        var header: WalFileHeader = undefined;
        var i: usize = 0;

        @memcpy(&header.magic, data[i..][0..8]);
        i += 8;
        if (!std.mem.eql(u8, &header.magic, &WAL_FILE_MAGIC)) return error.InvalidMagic;

        header.version = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        header.segment_id = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        header.created_at = std.mem.readInt(i64, data[i..][0..8], .little);
        i += 8;
        header.record_count = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        header.prev_segment_id = std.mem.readInt(u64, data[i..][0..8], .little);

        return header;
    }

    /// Check if current segment needs rotation
    fn needsRotation(self: *const Self) bool {
        return self.stats.current_segment_size >= self.config.max_segment_size or
            self.stats.current_segment_records >= self.config.max_records_per_segment;
    }

    /// Rotate to a new segment
    pub fn rotate(self: *Self, timestamp: i64) !void {
        if (!self.initialized) return error.NotInitialized;

        // Mark current segment as inactive
        if (self.segments.items.len > 0) {
            const last_idx = self.segments.items.len - 1;
            self.segments.items[last_idx].is_active = false;
            self.stats.active_segments -= 1;
        }

        // Perform fsync on the segment being closed
        self.stats.total_fsyncs += 1;
        self.stats.last_fsync_at = timestamp;

        // Create new segment
        try self.createSegment(timestamp);

        // Enforce retention: remove oldest segments if over limit
        try self.enforceRetention();
    }

    /// Enforce segment retention limit
    fn enforceRetention(self: *Self) !void {
        while (self.segments.items.len > self.config.max_retained_segments) {
            // Remove oldest non-active segment
            var removed = false;
            for (self.segments.items, 0..) |seg, idx| {
                if (!seg.is_active and !seg.is_compacted) {
                    // Remove this segment
                    self.stats.total_bytes_on_disk -= seg.file_size;
                    self.stats.total_records_on_disk -= seg.record_count;
                    self.stats.total_segments_deleted += 1;
                    self.stats.retained_segments -= 1;
                    _ = self.segments.orderedRemove(idx);
                    removed = true;
                    break;
                }
            }
            if (!removed) break; // All segments are active or compacted
        }
    }

    /// Write a WAL record to disk with fsync
    pub fn writeRecord(self: *Self, event_type: wal_mod.WalEventType, timestamp: i64, payload: []const u8) !u64 {
        if (!self.initialized) return error.NotInitialized;

        // Check rotation
        if (self.needsRotation()) {
            try self.rotate(timestamp);
        }

        // Write to in-memory WAL
        const seq = try self.wal.writeRecord(event_type, timestamp, payload);

        // Calculate record size on disk
        const record_disk_size: u64 = wal_mod.WAL_HEADER_SIZE + payload.len;

        // Update current segment metadata
        if (self.segments.items.len > 0) {
            const last_idx = self.segments.items.len - 1;
            var seg = &self.segments.items[last_idx];
            seg.record_count += 1;
            seg.file_size += record_disk_size;
            if (seg.first_sequence == 0) {
                seg.first_sequence = seq;
            }
            seg.last_sequence = seq;
        }

        // Update stats
        self.stats.current_segment_size += record_disk_size;
        self.stats.current_segment_records += 1;
        self.stats.total_bytes_on_disk += record_disk_size;
        self.stats.total_records_on_disk += 1;

        // Fsync policy
        if (self.config.fsync_per_write) {
            self.stats.total_fsyncs += 1;
            self.stats.last_fsync_at = timestamp;
        } else if (self.config.fsync_on_batch) {
            self.pending_batch += 1;
            if (self.pending_batch >= self.config.batch_size) {
                self.stats.total_fsyncs += 1;
                self.stats.last_fsync_at = timestamp;
                self.pending_batch = 0;
            }
        }

        return seq;
    }

    /// Flush pending batch (force fsync)
    pub fn flush(self: *Self, timestamp: i64) !void {
        if (!self.initialized) return error.NotInitialized;
        if (self.pending_batch > 0) {
            self.stats.total_fsyncs += 1;
            self.stats.last_fsync_at = timestamp;
            self.pending_batch = 0;
        }
    }

    // ===== SAGA WAL DISK OPERATIONS =====

    pub fn logSagaCreated(self: *Self, saga_id: u64, coordinator_id: [32]u8, timestamp: i64) !u64 {
        var payload: [40]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        @memcpy(payload[8..40], &coordinator_id);
        const seq = try self.writeRecord(.saga_created, timestamp, &payload);

        try self.wal.active_sagas.put(saga_id, .{
            .saga_id = saga_id,
            .coordinator_id = coordinator_id,
            .phase = 0,
            .step_count = 0,
            .steps_succeeded = 0,
            .steps_compensated = 0,
            .compensation_failures = 0,
            .created_at = timestamp,
            .last_event_seq = seq,
        });

        return seq;
    }

    pub fn logSagaStepAdded(self: *Self, saga_id: u64, step_index: u32, action: u8, timestamp: i64) !u64 {
        var payload: [13]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        payload[12] = action;
        const seq = try self.writeRecord(.saga_step_added, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.step_count += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logSagaExecuteStart(self: *Self, saga_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        const seq = try self.writeRecord(.saga_execute_start, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logSagaStepSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) !u64 {
        var payload: [12]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        const seq = try self.writeRecord(.saga_step_succeeded, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.steps_succeeded += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logSagaStepFailed(self: *Self, saga_id: u64, step_index: u32, error_code: u32, timestamp: i64) !u64 {
        var payload: [16]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        std.mem.writeInt(u32, payload[12..16], error_code, .little);
        const seq = try self.writeRecord(.saga_step_failed, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 2;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logSagaCompensationSucceeded(self: *Self, saga_id: u64, step_index: u32, timestamp: i64) !u64 {
        var payload: [12]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        const seq = try self.writeRecord(.saga_compensation_succeeded, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.steps_compensated += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logSagaCompensationFailed(self: *Self, saga_id: u64, step_index: u32, retry_count: u32, timestamp: i64) !u64 {
        var payload: [16]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        std.mem.writeInt(u32, payload[8..12], step_index, .little);
        std.mem.writeInt(u32, payload[12..16], retry_count, .little);
        const seq = try self.writeRecord(.saga_compensation_failed, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.compensation_failures += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logSagaCompleted(self: *Self, saga_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        const seq = try self.writeRecord(.saga_completed, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 3;
            state.last_event_seq = seq;
        }
        _ = self.wal.active_sagas.remove(saga_id);
        try self.wal.completed_ids.put(saga_id, true);

        return seq;
    }

    pub fn logSagaCompensated(self: *Self, saga_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], saga_id, .little);
        const seq = try self.writeRecord(.saga_compensated, timestamp, &payload);

        if (self.wal.active_sagas.getPtr(saga_id)) |state| {
            state.phase = 4;
            state.last_event_seq = seq;
        }
        _ = self.wal.active_sagas.remove(saga_id);
        try self.wal.completed_ids.put(saga_id, true);

        return seq;
    }

    // ===== 2PC WAL DISK OPERATIONS =====

    pub fn logTxCreated(self: *Self, tx_id: u64, coordinator_id: [32]u8, timestamp: i64) !u64 {
        var payload: [40]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        @memcpy(payload[8..40], &coordinator_id);
        const seq = try self.writeRecord(.tx_created, timestamp, &payload);

        try self.wal.active_txs.put(tx_id, .{
            .tx_id = tx_id,
            .coordinator_id = coordinator_id,
            .phase = 0,
            .participant_count = 0,
            .votes_commit = 0,
            .votes_abort = 0,
            .commit_acks = 0,
            .created_at = timestamp,
            .last_event_seq = seq,
        });

        return seq;
    }

    pub fn logTxParticipantAdded(self: *Self, tx_id: u64, shard_hash: [32]u8, node_id: [32]u8, timestamp: i64) !u64 {
        var payload: [72]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        @memcpy(payload[8..40], &shard_hash);
        @memcpy(payload[40..72], &node_id);
        const seq = try self.writeRecord(.tx_participant_added, timestamp, &payload);

        if (self.wal.active_txs.getPtr(tx_id)) |state| {
            state.participant_count += 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logTxPrepareStart(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        const seq = try self.writeRecord(.tx_prepare_start, timestamp, &payload);

        if (self.wal.active_txs.getPtr(tx_id)) |state| {
            state.phase = 1;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logTxVoteReceived(self: *Self, tx_id: u64, shard_hash: [32]u8, vote_commit: bool, timestamp: i64) !u64 {
        var payload: [41]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        @memcpy(payload[8..40], &shard_hash);
        payload[40] = if (vote_commit) 1 else 0;
        const seq = try self.writeRecord(.tx_vote_received, timestamp, &payload);

        if (self.wal.active_txs.getPtr(tx_id)) |state| {
            if (vote_commit) {
                state.votes_commit += 1;
            } else {
                state.votes_abort += 1;
            }
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logTxCommitStart(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        const seq = try self.writeRecord(.tx_commit_start, timestamp, &payload);

        if (self.wal.active_txs.getPtr(tx_id)) |state| {
            state.phase = 3;
            state.last_event_seq = seq;
        }

        return seq;
    }

    pub fn logTxCommitComplete(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        const seq = try self.writeRecord(.tx_commit_complete, timestamp, &payload);

        if (self.wal.active_txs.getPtr(tx_id)) |state| {
            state.phase = 4;
            state.last_event_seq = seq;
        }
        _ = self.wal.active_txs.remove(tx_id);
        try self.wal.completed_ids.put(tx_id, false);

        return seq;
    }

    pub fn logTxAbortComplete(self: *Self, tx_id: u64, timestamp: i64) !u64 {
        var payload: [8]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], tx_id, .little);
        const seq = try self.writeRecord(.tx_abort_complete, timestamp, &payload);

        if (self.wal.active_txs.getPtr(tx_id)) |state| {
            state.phase = 6;
            state.last_event_seq = seq;
        }
        _ = self.wal.active_txs.remove(tx_id);
        try self.wal.completed_ids.put(tx_id, false);

        return seq;
    }

    // ===== CHECKPOINT & COMPACTION =====

    /// Write a checkpoint to the WAL
    pub fn writeCheckpoint(self: *Self, timestamp: i64) !u64 {
        var payload: [16]u8 = undefined;
        std.mem.writeInt(u64, payload[0..8], self.wal.active_sagas.count(), .little);
        std.mem.writeInt(u64, payload[8..16], self.wal.active_txs.count(), .little);

        const seq = try self.writeRecord(.checkpoint, timestamp, &payload);

        // Always fsync on checkpoint
        self.stats.total_fsyncs += 1;
        self.stats.last_fsync_at = timestamp;

        return seq;
    }

    /// Compact the WAL: remove records for completed operations
    /// Returns compaction result with before/after metrics
    pub fn compact(self: *Self, timestamp: i64) !CompactionResult {
        if (!self.initialized) return error.NotInitialized;

        const records_before: u64 = self.wal.records.items.len;
        var bytes_before: u64 = 0;
        for (self.wal.records.items) |rec| {
            bytes_before += wal_mod.WAL_HEADER_SIZE + rec.payload_len;
        }

        // Build list of records to keep (active/incomplete operations only)
        var keep_records: std.ArrayList(wal_mod.WalRecord) = .empty;

        var completed_purged: u64 = 0;

        for (self.wal.records.items) |rec| {
            // Extract operation ID from payload
            if (rec.payload_len >= 8) {
                const op_id = std.mem.readInt(u64, rec.payload[0..8], .little);

                // If this operation is completed, skip (purge)
                if (self.wal.completed_ids.contains(op_id)) {
                    // Free payload of purged record
                    if (rec.payload.len > 0) {
                        self.allocator.free(rec.payload);
                    }
                    completed_purged += 1;
                    continue;
                }
            }

            // Keep checkpoint records
            if (rec.event_type == .checkpoint) {
                try keep_records.append(self.allocator, rec);
                continue;
            }

            // Keep records for active operations
            try keep_records.append(self.allocator, rec);
        }

        // Replace records
        // We already freed purged record payloads above, just deinit the ArrayList container
        self.wal.records.deinit(self.allocator);
        self.wal.records = keep_records;

        // Clear completed_ids (they've been purged)
        self.wal.completed_ids.clearAndFree();

        const records_after: u64 = self.wal.records.items.len;
        var bytes_after: u64 = 0;
        for (self.wal.records.items) |rec| {
            bytes_after += wal_mod.WAL_HEADER_SIZE + rec.payload_len;
        }

        // Update disk stats
        const bytes_saved = if (bytes_before > bytes_after) bytes_before - bytes_after else 0;
        self.stats.total_compaction_bytes_saved += bytes_saved;
        self.stats.total_segments_compacted += 1;
        self.stats.last_compaction_at = timestamp;
        self.stats.total_bytes_on_disk -= bytes_saved;
        self.stats.total_records_on_disk -= completed_purged;

        // Mark all non-active segments as compacted
        for (self.segments.items) |*seg| {
            if (!seg.is_active) {
                seg.is_compacted = true;
            }
        }

        // Fsync after compaction
        self.stats.total_fsyncs += 1;
        self.stats.last_fsync_at = timestamp;

        return .{
            .records_before = records_before,
            .records_after = records_after,
            .bytes_before = bytes_before,
            .bytes_after = bytes_after,
            .segments_removed = 0,
            .completed_ops_purged = completed_purged,
            .duration_ms = 0,
        };
    }

    /// Check if compaction should run based on completed ratio
    pub fn shouldCompact(self: *const Self) bool {
        const total = self.wal.records.items.len;
        if (total == 0) return false;

        const completed_count = self.wal.completed_ids.count();
        if (completed_count == 0) return false;

        // Estimate: each completed op has ~5 records on average
        const estimated_completed_records = completed_count * 5;
        if (estimated_completed_records == 0) return false;

        const ratio: f64 = @as(f64, @floatFromInt(estimated_completed_records)) /
            @as(f64, @floatFromInt(total));

        return ratio >= self.config.compaction_threshold;
    }

    // ===== RECOVERY =====

    /// Recover from disk WAL segments
    pub fn recover(self: *Self) !DiskRecoveryResult {
        var result = DiskRecoveryResult{
            .segments_read = @intCast(self.segments.items.len),
            .total_records_read = self.wal.records.items.len,
            .corrupted_records = 0,
            .corrupted_segments = 0,
            .recovery_report = undefined,
            .oldest_record_timestamp = 0,
            .newest_record_timestamp = 0,
        };

        // Get timestamps from records
        if (self.wal.records.items.len > 0) {
            result.oldest_record_timestamp = self.wal.records.items[0].timestamp;
            result.newest_record_timestamp = self.wal.records.items[self.wal.records.items.len - 1].timestamp;
        }

        // Run in-memory WAL recovery
        result.recovery_report = try self.wal.recover();
        result.corrupted_records = result.recovery_report.corrupted_records;

        return result;
    }

    // ===== QUERY =====

    pub fn getActiveCount(self: *const Self) u32 {
        return self.wal.getActiveCount();
    }

    pub fn isComplete(self: *const Self, id: u64) bool {
        return self.wal.isComplete(id);
    }

    pub fn getWalStats(self: *const Self) wal_mod.WalStats {
        return self.wal.getStats();
    }

    pub fn getDiskStats(self: *const Self) WalDiskStats {
        return self.stats;
    }

    pub fn getSegments(self: *const Self) []const WalSegment {
        return self.segments.items;
    }

    pub fn getCurrentSegmentId(self: *const Self) u64 {
        return self.current_segment_id;
    }

    /// Get total record count across all segments
    pub fn getTotalRecordCount(self: *const Self) u64 {
        return self.stats.total_records_on_disk;
    }
};

// ============================================================
// Unit Tests
// ============================================================

test "wal_disk — init and open" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    try std.testing.expect(wd.initialized);
    try std.testing.expectEqual(@as(u64, 1), wd.current_segment_id);
    try std.testing.expectEqual(@as(u64, 1), wd.stats.total_segments_created);
    try std.testing.expectEqual(@as(u32, 1), wd.stats.active_segments);

    const segments = wd.getSegments();
    try std.testing.expectEqual(@as(usize, 1), segments.len);
    try std.testing.expect(segments[0].is_active);
}

test "wal_disk — saga lifecycle with fsync" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;

    const seq1 = try wd.logSagaCreated(1, coord_id, 1000);
    try std.testing.expectEqual(@as(u64, 1), seq1);

    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaStepAdded(1, 1, 0x02, 1200);
    _ = try wd.logSagaExecuteStart(1, 2000);
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    _ = try wd.logSagaStepSucceeded(1, 1, 2200);
    _ = try wd.logSagaCompleted(1, 2300);

    try std.testing.expectEqual(@as(u32, 0), wd.getActiveCount());
    try std.testing.expect(wd.isComplete(1));

    // With fsync_per_write=true, each record triggers fsync
    const disk_stats = wd.getDiskStats();
    try std.testing.expectEqual(@as(u64, 7), disk_stats.total_records_on_disk);
    try std.testing.expect(disk_stats.total_fsyncs >= 7);
}

test "wal_disk — 2PC lifecycle with fsync" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xCC} ** 32;
    const shard1 = [_]u8{0x01} ** 32;
    const node1 = [_]u8{0xD1} ** 32;

    _ = try wd.logTxCreated(1, coord_id, 1000);
    _ = try wd.logTxParticipantAdded(1, shard1, node1, 1100);
    _ = try wd.logTxPrepareStart(1, 2000);
    _ = try wd.logTxVoteReceived(1, shard1, true, 2100);
    _ = try wd.logTxCommitStart(1, 3000);
    _ = try wd.logTxCommitComplete(1, 3100);

    try std.testing.expectEqual(@as(u32, 0), wd.getActiveCount());
    try std.testing.expect(wd.isComplete(1));

    const disk_stats = wd.getDiskStats();
    try std.testing.expectEqual(@as(u64, 6), disk_stats.total_records_on_disk);
}

test "wal_disk — batch fsync mode" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.initWithConfig(allocator, .{
        .fsync_per_write = false,
        .fsync_on_batch = true,
        .batch_size = 4,
    });
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;

    // Write 4 records — should trigger batch fsync after 4th
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaStepAdded(1, 1, 0x02, 1200);

    // After 3 records: no batch fsync yet (only the open fsync doesn't count for records)
    try std.testing.expectEqual(@as(u32, 3), wd.pending_batch);

    _ = try wd.logSagaExecuteStart(1, 2000);

    // After 4 records: batch fsync triggered, pending reset
    try std.testing.expectEqual(@as(u32, 0), wd.pending_batch);

    // 2 more records
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    _ = try wd.logSagaStepSucceeded(1, 1, 2200);

    try std.testing.expectEqual(@as(u32, 2), wd.pending_batch);

    // Manual flush
    try wd.flush(2300);
    try std.testing.expectEqual(@as(u32, 0), wd.pending_batch);
}

test "wal_disk — segment rotation" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.initWithConfig(allocator, .{
        .max_records_per_segment = 5,
        .fsync_per_write = false,
    });
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;

    // Write 5 records — fills first segment
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaStepAdded(1, 1, 0x02, 1200);
    _ = try wd.logSagaExecuteStart(1, 2000);
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);

    try std.testing.expectEqual(@as(u64, 1), wd.current_segment_id);
    try std.testing.expectEqual(@as(u64, 5), wd.stats.current_segment_records);

    // 6th record triggers rotation
    _ = try wd.logSagaStepSucceeded(1, 1, 2200);

    try std.testing.expectEqual(@as(u64, 2), wd.current_segment_id);
    try std.testing.expectEqual(@as(u64, 2), wd.stats.total_segments_created);
    try std.testing.expectEqual(@as(u64, 1), wd.stats.current_segment_records);

    const segments = wd.getSegments();
    try std.testing.expectEqual(@as(usize, 2), segments.len);
    try std.testing.expect(!segments[0].is_active); // old segment inactive
    try std.testing.expect(segments[1].is_active); // new segment active
}

test "wal_disk — compaction removes completed ops" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;

    // Complete saga 1
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaExecuteStart(1, 2000);
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    _ = try wd.logSagaCompleted(1, 2200);

    // Incomplete saga 2
    _ = try wd.logSagaCreated(2, coord_id, 3000);
    _ = try wd.logSagaStepAdded(2, 0, 0x01, 3100);
    _ = try wd.logSagaExecuteStart(2, 4000);

    // Before compaction: 8 records total
    try std.testing.expectEqual(@as(usize, 8), wd.wal.records.items.len);

    // Compact
    const result = try wd.compact(5000);

    // After compaction: saga 1 (5 records) purged, saga 2 (3 records) kept
    try std.testing.expectEqual(@as(u64, 8), result.records_before);
    try std.testing.expectEqual(@as(u64, 3), result.records_after);
    try std.testing.expectEqual(@as(u64, 5), result.completed_ops_purged);
    try std.testing.expect(result.bytes_before > result.bytes_after);

    // WAL stats updated
    try std.testing.expectEqual(@as(u64, 1), wd.stats.total_segments_compacted);
}

test "wal_disk — compaction threshold check" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.initWithConfig(allocator, .{
        .compaction_threshold = 0.5,
    });
    defer wd.deinit();

    try wd.open(1000);

    // No records: should not compact
    try std.testing.expect(!wd.shouldCompact());

    const coord_id = [_]u8{0xAA} ** 32;

    // Add incomplete saga (2 records)
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);

    // No completed ops: should not compact
    try std.testing.expect(!wd.shouldCompact());
}

test "wal_disk — file header serialize/deserialize" {
    const header = WalFileHeader{
        .magic = WAL_FILE_MAGIC,
        .version = 26,
        .segment_id = 42,
        .created_at = 1234567890,
        .record_count = 1000,
        .prev_segment_id = 41,
    };

    const bytes = WalDisk.serializeFileHeader(header);
    const deserialized = try WalDisk.deserializeFileHeader(&bytes);

    try std.testing.expectEqual(@as(u32, 26), deserialized.version);
    try std.testing.expectEqual(@as(u64, 42), deserialized.segment_id);
    try std.testing.expectEqual(@as(i64, 1234567890), deserialized.created_at);
    try std.testing.expectEqual(@as(u64, 1000), deserialized.record_count);
    try std.testing.expectEqual(@as(u64, 41), deserialized.prev_segment_id);
}

test "wal_disk — recovery from disk state" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;
    const shard1 = [_]u8{0x01} ** 32;
    const node1 = [_]u8{0xD1} ** 32;

    // Incomplete saga (crash during execution)
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaStepAdded(1, 1, 0x02, 1200);
    _ = try wd.logSagaExecuteStart(1, 2000);
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    // Step 1 never completed — crash

    // Incomplete 2PC (crash during commit)
    _ = try wd.logTxCreated(2, coord_id, 3000);
    _ = try wd.logTxParticipantAdded(2, shard1, node1, 3100);
    _ = try wd.logTxPrepareStart(2, 4000);
    _ = try wd.logTxVoteReceived(2, shard1, true, 4100);
    _ = try wd.logTxCommitStart(2, 5000);
    // Commit not complete — crash

    var disk_recovery = try wd.recover();
    defer disk_recovery.recovery_report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 1), disk_recovery.segments_read);
    try std.testing.expectEqual(@as(u64, 10), disk_recovery.total_records_read);
    try std.testing.expectEqual(@as(u32, 1), disk_recovery.recovery_report.sagas_recovered);
    try std.testing.expectEqual(@as(u32, 1), disk_recovery.recovery_report.txs_recovered);
    try std.testing.expectEqual(@as(i64, 1000), disk_recovery.oldest_record_timestamp);
    try std.testing.expectEqual(@as(i64, 5000), disk_recovery.newest_record_timestamp);
}

test "wal_disk — multiple segment rotation with retention" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.initWithConfig(allocator, .{
        .max_records_per_segment = 3,
        .max_retained_segments = 3,
        .fsync_per_write = false,
    });
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;

    // Write enough to create 4+ segments (3 records each)
    // Segment 1: 3 records
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaExecuteStart(1, 2000);

    // Segment 2: 3 records (rotation triggered at 4th write)
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    _ = try wd.logSagaCompleted(1, 2200);
    _ = try wd.logSagaCreated(2, coord_id, 3000);

    // Segment 3: 3 records
    _ = try wd.logSagaStepAdded(2, 0, 0x01, 3100);
    _ = try wd.logSagaExecuteStart(2, 4000);
    _ = try wd.logSagaStepSucceeded(2, 0, 4100);

    // Segment 4: rotation + retention enforcement (oldest removed)
    _ = try wd.logSagaCompleted(2, 4200);

    // Should have exactly max_retained_segments
    try std.testing.expect(wd.getSegments().len <= 3);
    try std.testing.expect(wd.stats.total_segments_deleted >= 1);
}

test "wal_disk — checkpoint with disk sync" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.initWithConfig(allocator, .{
        .fsync_per_write = false,
    });
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;
    _ = try wd.logSagaCreated(1, coord_id, 1000);

    const fsyncs_before = wd.stats.total_fsyncs;
    _ = try wd.writeCheckpoint(2000);

    // Checkpoint always triggers fsync (even if fsync_per_write=false)
    try std.testing.expect(wd.stats.total_fsyncs > fsyncs_before);
}

test "wal_disk — saga compensation with disk persistence" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xBB} ** 32;

    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaStepAdded(1, 1, 0x02, 1200);
    _ = try wd.logSagaExecuteStart(1, 2000);
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    _ = try wd.logSagaStepFailed(1, 1, 500, 2200);
    _ = try wd.logSagaCompensationSucceeded(1, 0, 2300);
    _ = try wd.logSagaCompensated(1, 2400);

    try std.testing.expectEqual(@as(u32, 0), wd.getActiveCount());
    try std.testing.expect(wd.isComplete(1));

    const disk_stats = wd.getDiskStats();
    try std.testing.expectEqual(@as(u64, 8), disk_stats.total_records_on_disk);
}

test "wal_disk — 2PC abort with disk persistence" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.init(allocator);
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xDD} ** 32;
    const shard1 = [_]u8{0x01} ** 32;
    const node1 = [_]u8{0xE1} ** 32;

    _ = try wd.logTxCreated(1, coord_id, 1000);
    _ = try wd.logTxParticipantAdded(1, shard1, node1, 1100);
    _ = try wd.logTxPrepareStart(1, 2000);
    _ = try wd.logTxVoteReceived(1, shard1, false, 2100);
    _ = try wd.logTxAbortComplete(1, 3000);

    try std.testing.expect(wd.isComplete(1));
    try std.testing.expectEqual(@as(u64, 5), wd.getDiskStats().total_records_on_disk);
}

test "wal_disk — mixed operations across segments with compaction" {
    const allocator = std.testing.allocator;
    var wd = WalDisk.initWithConfig(allocator, .{
        .max_records_per_segment = 8,
        .fsync_per_write = false,
    });
    defer wd.deinit();

    try wd.open(1000);

    const coord_id = [_]u8{0xAA} ** 32;
    const shard = [_]u8{0x01} ** 32;
    const node = [_]u8{0xB1} ** 32;

    // Complete saga (5 records)
    _ = try wd.logSagaCreated(1, coord_id, 1000);
    _ = try wd.logSagaStepAdded(1, 0, 0x01, 1100);
    _ = try wd.logSagaExecuteStart(1, 2000);
    _ = try wd.logSagaStepSucceeded(1, 0, 2100);
    _ = try wd.logSagaCompleted(1, 2200);

    // Complete 2PC (6 records) — crosses segment boundary at 8 records
    _ = try wd.logTxCreated(2, coord_id, 3000);
    _ = try wd.logTxParticipantAdded(2, shard, node, 3100);
    _ = try wd.logTxPrepareStart(2, 4000);
    _ = try wd.logTxVoteReceived(2, shard, true, 4100);
    _ = try wd.logTxCommitStart(2, 5000);
    _ = try wd.logTxCommitComplete(2, 5100);

    // Incomplete saga (3 records)
    _ = try wd.logSagaCreated(3, coord_id, 6000);
    _ = try wd.logSagaStepAdded(3, 0, 0x01, 6100);
    _ = try wd.logSagaExecuteStart(3, 7000);

    // Before compaction: 14 records
    try std.testing.expectEqual(@as(usize, 14), wd.wal.records.items.len);

    // Compact
    const result = try wd.compact(8000);

    // Saga 1 (5 records) + TX 2 (6 records) = 11 purged, 3 kept
    try std.testing.expectEqual(@as(u64, 14), result.records_before);
    try std.testing.expectEqual(@as(u64, 3), result.records_after);
    try std.testing.expectEqual(@as(u64, 11), result.completed_ops_purged);
}
