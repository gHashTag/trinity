// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY STORAGE PROVIDER v1.4 - Reed-Solomon + Connection Pooling + Manifest DHT
// Production storage: in-memory cache + LRU eviction + disk persistence + pinning + RS
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const crypto = @import("crypto.zig");
const protocol = @import("protocol.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// HASH HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

const hex_chars = "0123456789abcdef";

/// Convert a 32-byte hash to a 64-char hex string (filesystem-safe)
pub fn hashToHex(hash: [32]u8) [64]u8 {
    var result: [64]u8 = undefined;
    for (hash, 0..) |byte, i| {
        result[i * 2] = hex_chars[byte >> 4];
        result[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
    return result;
}

/// Convert a 64-char hex string back to a 32-byte hash
pub fn hexToHash(hex: [64]u8) ?[32]u8 {
    var result: [32]u8 = undefined;
    for (0..32) |i| {
        const hi: u8 = hexDigit(hex[i * 2]) orelse return null;
        const lo: u8 = hexDigit(hex[i * 2 + 1]) orelse return null;
        result[i] = (hi << 4) | lo;
    }
    return result;
}

fn hexDigit(c: u8) ?u4 {
    if (c >= '0' and c <= '9') return @intCast(c - '0');
    if (c >= 'a' and c <= 'f') return @intCast(c - 'a' + 10);
    if (c >= 'A' and c <= 'F') return @intCast(c - 'A' + 10);
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const StorageConfig = struct {
    max_bytes: u64 = 10 * 1024 * 1024 * 1024, // 10 GB default
    shard_size: u32 = 65536, // 64 KB per shard
    replication_factor: u8 = 3,
    storage_dir: ?[]const u8 = null, // null = in-memory only, non-null = disk-backed
    max_memory_shards: u32 = 1000, // Max shards in memory before LRU eviction
    rs_parity_ratio: f32 = 0.5, // v1.4: RS parity shards = ceil(data_shards * ratio)
};

pub const DEFAULT_CONFIG = StorageConfig{};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD TRACKER
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardStats = struct {
    shards_hosted: u64,
    retrievals_served: u64,
    hosting_hours: f64,
    earned_tri: f64,
    bytes_uploaded: u64,
    bytes_downloaded: u64,
};

pub const RewardTracker = struct {
    shards_hosted: u64,
    retrievals_served: u64,
    hosting_start: i64,
    // v1.3: Bandwidth metering
    bytes_uploaded: u64,
    bytes_downloaded: u64,

    // Duplicated from depin.zig (src/firebird/depin.zig) to avoid cross-directory import
    // 0.00005 TRI per shard per hour (in wei: 50_000_000_000_000)
    const REWARD_SHARD_HOUR: u128 = 50_000_000_000_000;
    // 0.0005 TRI per retrieval (in wei: 500_000_000_000_000)
    const REWARD_RETRIEVAL: u128 = 500_000_000_000_000;
    // v1.3: 0.05 TRI per GB uploaded (in wei: 50_000_000_000_000_000)
    const REWARD_PER_GB_UPLOAD: u128 = 50_000_000_000_000_000;
    // v1.3: 0.03 TRI per GB downloaded (in wei: 30_000_000_000_000_000)
    const REWARD_PER_GB_DOWNLOAD: u128 = 30_000_000_000_000_000;
    const TRI_DECIMALS: f64 = 1_000_000_000_000_000_000.0; // 1e18
    const BYTES_PER_GB: u128 = 1024 * 1024 * 1024;

    pub fn init() RewardTracker {
        return .{
            .shards_hosted = 0,
            .retrievals_served = 0,
            .hosting_start = std.time.timestamp(),
            .bytes_uploaded = 0,
            .bytes_downloaded = 0,
        };
    }

    /// Record bytes uploaded to remote peers
    pub fn recordUpload(self: *RewardTracker, bytes: u64) void {
        self.bytes_uploaded += bytes;
    }

    /// Record bytes downloaded from remote peers
    pub fn recordDownload(self: *RewardTracker, bytes: u64) void {
        self.bytes_downloaded += bytes;
    }

    /// Calculate bandwidth reward (in wei)
    pub fn calculateBandwidthRewardWei(self: *const RewardTracker) u128 {
        const upload_reward = (@as(u128, self.bytes_uploaded) * REWARD_PER_GB_UPLOAD) / BYTES_PER_GB;
        const download_reward = (@as(u128, self.bytes_downloaded) * REWARD_PER_GB_DOWNLOAD) / BYTES_PER_GB;
        return upload_reward + download_reward;
    }

    /// Calculate total earned TRI (in wei)
    pub fn calculateEarnedWei(self: *const RewardTracker) u128 {
        const now = std.time.timestamp();
        const elapsed_secs: u64 = if (now > self.hosting_start)
            @intCast(now - self.hosting_start)
        else
            0;
        const hours: u128 = elapsed_secs / 3600;

        const hosting_reward = self.shards_hosted * hours * REWARD_SHARD_HOUR;
        const retrieval_reward = self.retrievals_served * REWARD_RETRIEVAL;
        const bandwidth_reward = self.calculateBandwidthRewardWei();

        return hosting_reward + retrieval_reward + bandwidth_reward;
    }

    /// Calculate earned TRI as float
    pub fn calculateEarnedTri(self: *const RewardTracker) f64 {
        const wei = self.calculateEarnedWei();
        return @as(f64, @floatFromInt(wei)) / TRI_DECIMALS;
    }

    /// Get reward stats
    pub fn getStats(self: *const RewardTracker) RewardStats {
        const now = std.time.timestamp();
        const elapsed_secs: u64 = if (now > self.hosting_start)
            @intCast(now - self.hosting_start)
        else
            0;
        const hours: f64 = @as(f64, @floatFromInt(elapsed_secs)) / 3600.0;

        return .{
            .shards_hosted = self.shards_hosted,
            .retrievals_served = self.retrievals_served,
            .hosting_hours = hours,
            .earned_tri = self.calculateEarnedTri(),
            .bytes_uploaded = self.bytes_uploaded,
            .bytes_downloaded = self.bytes_downloaded,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FILE MANIFEST - Metadata about a stored file
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardLocation = struct {
    shard_hash: [32]u8,
    node_ids: [3][32]u8, // Up to 3 replicas
    replica_count: u8,
};

pub const FileManifest = struct {
    file_id: [32]u8, // SHA256 of original file
    file_name: [256]u8,
    file_name_len: u16,
    original_size: u64,
    shard_count: u32,
    shard_size: u32,
    encryption_nonce: [12]u8, // AES-256-GCM nonce
    encryption_tag: [16]u8, // AES-256-GCM tag
    created_at: i64,
    parity_hash: [32]u8, // v1.2: XOR parity shard hash (all zeros = no parity)
    // v1.4: Reed-Solomon parameters
    rs_data_shards: u32, // k (number of data shards, 0 = no RS)
    rs_parity_shards: u32, // m (number of parity shards)
    rs_last_shard_len: u32, // actual length of last data shard before padding
    shard_hashes: []const [32]u8, // SHA256 of each shard (data + parity for v1.4)

    // v1.1 header: 32+256+2+8+4+4+12+16+8 = 342
    // v1.2 header: 342 + 32 (parity_hash) = 374
    // v1.4 header: 374 + 12 (3 x u32 RS fields) = 386
    const HEADER_SIZE_V11: usize = 342;
    const HEADER_SIZE_V12: usize = 374;
    const HEADER_SIZE_V14: usize = 386;

    pub fn serialize(self: *const FileManifest, allocator: std.mem.Allocator) ![]u8 {
        const total = HEADER_SIZE_V14 + self.shard_count * 32;
        const buf = try allocator.alloc(u8, total);

        var i: usize = 0;
        @memcpy(buf[i..][0..32], &self.file_id);
        i += 32;
        @memcpy(buf[i..][0..256], &self.file_name);
        i += 256;
        std.mem.writeInt(u16, buf[i..][0..2], self.file_name_len, .little);
        i += 2;
        std.mem.writeInt(u64, buf[i..][0..8], self.original_size, .little);
        i += 8;
        std.mem.writeInt(u32, buf[i..][0..4], self.shard_count, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.shard_size, .little);
        i += 4;
        @memcpy(buf[i..][0..12], &self.encryption_nonce);
        i += 12;
        @memcpy(buf[i..][0..16], &self.encryption_tag);
        i += 16;
        std.mem.writeInt(i64, buf[i..][0..8], self.created_at, .little);
        i += 8;
        @memcpy(buf[i..][0..32], &self.parity_hash);
        i += 32;
        // v1.4: Reed-Solomon parameters
        std.mem.writeInt(u32, buf[i..][0..4], self.rs_data_shards, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.rs_parity_shards, .little);
        i += 4;
        std.mem.writeInt(u32, buf[i..][0..4], self.rs_last_shard_len, .little);
        i += 4;

        for (0..self.shard_count) |s| {
            @memcpy(buf[i..][0..32], &self.shard_hashes[s]);
            i += 32;
        }

        return buf;
    }

    pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !FileManifest {
        if (data.len < HEADER_SIZE_V11) return error.InvalidData;

        var manifest: FileManifest = undefined;
        var i: usize = 0;

        @memcpy(&manifest.file_id, data[i..][0..32]);
        i += 32;
        @memcpy(&manifest.file_name, data[i..][0..256]);
        i += 256;
        manifest.file_name_len = std.mem.readInt(u16, data[i..][0..2], .little);
        i += 2;
        manifest.original_size = std.mem.readInt(u64, data[i..][0..8], .little);
        i += 8;
        manifest.shard_count = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        manifest.shard_size = std.mem.readInt(u32, data[i..][0..4], .little);
        i += 4;
        @memcpy(&manifest.encryption_nonce, data[i..][0..12]);
        i += 12;
        @memcpy(&manifest.encryption_tag, data[i..][0..16]);
        i += 16;
        manifest.created_at = std.mem.readInt(i64, data[i..][0..8], .little);
        i += 8;

        // Backward compatibility: check which version format
        const shard_data_size = manifest.shard_count * 32;
        if (data.len >= HEADER_SIZE_V14 + shard_data_size) {
            // v1.4 format: has parity_hash + RS fields
            @memcpy(&manifest.parity_hash, data[i..][0..32]);
            i += 32;
            manifest.rs_data_shards = std.mem.readInt(u32, data[i..][0..4], .little);
            i += 4;
            manifest.rs_parity_shards = std.mem.readInt(u32, data[i..][0..4], .little);
            i += 4;
            manifest.rs_last_shard_len = std.mem.readInt(u32, data[i..][0..4], .little);
            i += 4;
        } else if (data.len >= HEADER_SIZE_V12 + shard_data_size) {
            // v1.2 format: has parity_hash, no RS
            @memcpy(&manifest.parity_hash, data[i..][0..32]);
            i += 32;
            manifest.rs_data_shards = 0;
            manifest.rs_parity_shards = 0;
            manifest.rs_last_shard_len = 0;
        } else if (data.len >= HEADER_SIZE_V11 + shard_data_size) {
            // v1.1 format: no parity_hash, no RS
            manifest.parity_hash = [_]u8{0} ** 32;
            manifest.rs_data_shards = 0;
            manifest.rs_parity_shards = 0;
            manifest.rs_last_shard_len = 0;
        } else {
            return error.InvalidData;
        }

        const hashes = try allocator.alloc([32]u8, manifest.shard_count);
        for (0..manifest.shard_count) |s| {
            @memcpy(&hashes[s], data[i..][0..32]);
            i += 32;
        }
        manifest.shard_hashes = hashes;

        return manifest;
    }

    /// Check if this manifest has a valid parity shard
    pub fn hasParity(self: *const FileManifest) bool {
        const zero = [_]u8{0} ** 32;
        return !std.mem.eql(u8, &self.parity_hash, &zero);
    }

    /// Check if this manifest uses Reed-Solomon erasure coding (v1.4+)
    pub fn hasReedSolomon(self: *const FileManifest) bool {
        return self.rs_data_shards > 0;
    }

    pub fn getFileName(self: *const FileManifest) []const u8 {
        return self.file_name[0..self.file_name_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STORAGE PROVIDER - In-Memory Cache + Disk Persistence
// ═══════════════════════════════════════════════════════════════════════════════

pub const StorageStats = struct {
    total_shards: u32,
    used_bytes: u64,
    available_bytes: u64,
    max_bytes: u64,
};

pub const StorageProvider = struct {
    allocator: std.mem.Allocator,
    config: StorageConfig,
    shards: std.AutoHashMap([32]u8, []u8), // in-memory cache
    disk_index: std.AutoHashMap([32]u8, bool), // tracks shards on disk (not loaded)
    access_times: std.AutoHashMap([32]u8, u64), // LRU: monotonic access counter per shard
    access_counter: u64, // Monotonically increasing counter for LRU ordering
    pinned_shards: std.AutoHashMap([32]u8, bool), // v1.3: pinned shards (non-evictable)
    used_bytes: u64,
    reward_tracker: RewardTracker,

    pub fn init(allocator: std.mem.Allocator, config: StorageConfig) StorageProvider {
        return .{
            .allocator = allocator,
            .config = config,
            .shards = std.AutoHashMap([32]u8, []u8).init(allocator),
            .disk_index = std.AutoHashMap([32]u8, bool).init(allocator),
            .access_times = std.AutoHashMap([32]u8, u64).init(allocator),
            .access_counter = 0,
            .pinned_shards = std.AutoHashMap([32]u8, bool).init(allocator),
            .used_bytes = 0,
            .reward_tracker = RewardTracker.init(),
        };
    }

    pub fn deinit(self: *StorageProvider) void {
        var iter = self.shards.valueIterator();
        while (iter.next()) |val| {
            self.allocator.free(val.*);
        }
        self.shards.deinit();
        self.disk_index.deinit();
        self.access_times.deinit();
        self.pinned_shards.deinit();
    }

    /// Store a shard (in memory + optionally on disk). Returns true on success.
    pub fn storeShard(self: *StorageProvider, shard_hash: [32]u8, data: []const u8) !bool {
        // Check capacity
        if (self.used_bytes + data.len > self.config.max_bytes) {
            return false;
        }

        // Verify hash
        const actual_hash = crypto.sha256(data);
        if (!std.mem.eql(u8, &actual_hash, &shard_hash)) {
            return error.HashMismatch;
        }

        // Check if already stored (memory or disk)
        if (self.shards.contains(shard_hash) or self.disk_index.contains(shard_hash)) {
            return true; // Already have it
        }

        // Copy and store in memory
        const stored = try self.allocator.alloc(u8, data.len);
        @memcpy(stored, data);
        try self.shards.put(shard_hash, stored);
        self.used_bytes += data.len;
        self.reward_tracker.shards_hosted += 1;

        // Track access time for LRU
        self.touchShard(shard_hash);

        // Persist to disk if configured
        if (self.config.storage_dir != null) {
            self.persistShardToDisk(shard_hash, data) catch |write_err| {
                std.log.warn("storage: failed to persist shard to disk: {}", .{write_err});
            };
        }

        // Evict oldest shard if over memory limit
        self.evictLruIfNeeded();

        return true;
    }

    /// Retrieve a shard by hash (checks memory first, then disk)
    pub fn retrieveShard(self: *StorageProvider, shard_hash: [32]u8) ?[]const u8 {
        // Check memory cache first
        if (self.shards.get(shard_hash)) |data| {
            self.reward_tracker.retrievals_served += 1;
            self.touchShard(shard_hash);
            return data;
        }

        // Try lazy load from disk
        if (self.disk_index.contains(shard_hash)) {
            if (self.loadShardFromDisk(shard_hash)) |data| {
                // Cache in memory
                self.shards.put(shard_hash, data) catch {
                    self.allocator.free(data);
                    return null;
                };
                self.used_bytes += data.len;
                self.reward_tracker.retrievals_served += 1;
                self.touchShard(shard_hash);

                // Evict oldest shard if over memory limit after lazy load
                self.evictLruIfNeeded();

                return data;
            }
        }

        return null;
    }

    /// Check if a shard is stored (memory or disk)
    pub fn hasShard(self: *const StorageProvider, shard_hash: [32]u8) bool {
        return self.shards.contains(shard_hash) or self.disk_index.contains(shard_hash);
    }

    /// Get available bytes
    pub fn getAvailableBytes(self: *const StorageProvider) u64 {
        if (self.config.max_bytes > self.used_bytes) {
            return self.config.max_bytes - self.used_bytes;
        }
        return 0;
    }

    /// Get storage stats
    pub fn getStats(self: *const StorageProvider) StorageStats {
        return .{
            .total_shards = @intCast(self.shards.count() + self.disk_index.count()),
            .used_bytes = self.used_bytes,
            .available_bytes = self.getAvailableBytes(),
            .max_bytes = self.config.max_bytes,
        };
    }

    /// Get reward stats
    pub fn getRewardStats(self: *const StorageProvider) RewardStats {
        return self.reward_tracker.getStats();
    }

    /// Handle incoming StoreRequest
    pub fn handleStoreRequest(self: *StorageProvider, req: protocol.StoreRequest, node_id: [32]u8) !protocol.StoreResponse {
        const success = try self.storeShard(req.shard_hash, req.data);
        return protocol.StoreResponse{
            .shard_hash = req.shard_hash,
            .success = success,
            .node_id = node_id,
        };
    }

    /// Handle incoming RetrieveRequest
    pub fn handleRetrieveRequest(self: *StorageProvider, req: protocol.RetrieveRequest) protocol.RetrieveResponse {
        if (self.retrieveShard(req.shard_hash)) |data| {
            return .{
                .shard_hash = req.shard_hash,
                .found = true,
                .data = data,
            };
        }
        return .{
            .shard_hash = req.shard_hash,
            .found = false,
            .data = "",
        };
    }

    // ═════════════════════════════════════════════════════════════════════════
    // LRU EVICTION
    // ═════════════════════════════════════════════════════════════════════════

    /// Update access counter for a shard (LRU tracking)
    fn touchShard(self: *StorageProvider, shard_hash: [32]u8) void {
        self.access_counter += 1;
        self.access_times.put(shard_hash, self.access_counter) catch |access_err| {
            std.log.debug("storage: failed to update access time: {}", .{access_err});
        };
    }

    /// Evict the least-recently-used shard from memory if over max_memory_shards.
    /// Only evicts shards that are persisted on disk (to avoid data loss).
    /// v1.3: Skips pinned shards (non-evictable).
    fn evictLruIfNeeded(self: *StorageProvider) void {
        while (self.shards.count() > self.config.max_memory_shards) {
            // Only evict if disk persistence is enabled
            if (self.config.storage_dir == null) return;

            // Find shard with oldest access counter (skip pinned)
            var oldest_hash: ?[32]u8 = null;
            var oldest_time: u64 = std.math.maxInt(u64);

            var key_iter = self.shards.keyIterator();
            while (key_iter.next()) |key| {
                // v1.3: Skip pinned shards
                if (self.pinned_shards.contains(key.*)) continue;

                const access_time = self.access_times.get(key.*) orelse 0;
                if (access_time < oldest_time) {
                    oldest_time = access_time;
                    oldest_hash = key.*;
                }
            }

            if (oldest_hash) |hash| {
                // Remove from memory
                if (self.shards.fetchRemove(hash)) |kv| {
                    self.used_bytes -= kv.value.len;
                    self.allocator.free(kv.value);
                }
                // Remove access time entry
                _ = self.access_times.remove(hash);
                // Mark as on-disk only
                self.disk_index.put(hash, true) catch |idx_err| {
                    std.log.warn("storage: failed to mark shard as on-disk: {}", .{idx_err});
                };
            } else {
                break; // No evictable shard found (all pinned or empty)
            }
        }
    }

    /// Get the number of shards currently in memory
    pub fn getMemoryShardCount(self: *const StorageProvider) u32 {
        return @intCast(self.shards.count());
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SHARD PINNING (v1.3)
    // ═════════════════════════════════════════════════════════════════════════

    /// Pin a shard to prevent LRU eviction
    pub fn pinShard(self: *StorageProvider, shard_hash: [32]u8) void {
        self.pinned_shards.put(shard_hash, true) catch |pin_err| {
            std.log.warn("storage: failed to pin shard: {}", .{pin_err});
        };
    }

    /// Unpin a shard to allow LRU eviction
    pub fn unpinShard(self: *StorageProvider, shard_hash: [32]u8) void {
        _ = self.pinned_shards.remove(shard_hash);
    }

    /// Check if a shard is pinned
    pub fn isShardPinned(self: *const StorageProvider, shard_hash: [32]u8) bool {
        return self.pinned_shards.contains(shard_hash);
    }

    /// Get the number of pinned shards
    pub fn getPinnedShardCount(self: *const StorageProvider) u32 {
        return @intCast(self.pinned_shards.count());
    }

    // ═════════════════════════════════════════════════════════════════════════
    // DISK PERSISTENCE
    // ═════════════════════════════════════════════════════════════════════════

    /// Persist a shard to disk: {storage_dir}/{hash_hex}.shard
    fn persistShardToDisk(self: *StorageProvider, shard_hash: [32]u8, data: []const u8) !void {
        const dir_path = self.config.storage_dir orelse return;

        // Ensure storage directory exists
        std.fs.cwd().makePath(dir_path) catch {};

        const hex = hashToHex(shard_hash);
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.shard", .{ dir_path, hex });
        defer self.allocator.free(file_path);

        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        try file.writeAll(data);
    }

    /// Load a shard from disk into memory
    fn loadShardFromDisk(self: *StorageProvider, shard_hash: [32]u8) ?[]u8 {
        const dir_path = self.config.storage_dir orelse return null;

        const hex = hashToHex(shard_hash);
        const file_path = std.fmt.allocPrint(self.allocator, "{s}/{s}.shard", .{ dir_path, hex }) catch return null;
        defer self.allocator.free(file_path);

        const file = std.fs.cwd().openFile(file_path, .{}) catch return null;
        defer file.close();

        const stat = file.stat() catch return null;
        if (stat.size > 256 * 1024 * 1024) return null; // max 256MB shard
        const data = self.allocator.alloc(u8, stat.size) catch return null;
        const bytes_read = file.readAll(data) catch {
            self.allocator.free(data);
            return null;
        };

        if (bytes_read != stat.size) {
            self.allocator.free(data);
            return null;
        }

        // Verify hash
        const actual_hash = crypto.sha256(data);
        if (!std.mem.eql(u8, &actual_hash, &shard_hash)) {
            self.allocator.free(data);
            return null;
        }

        // Remove from disk_index since it's now in memory
        _ = self.disk_index.remove(shard_hash);

        return data;
    }

    /// Scan storage directory and rebuild disk index (startup recovery)
    /// Does NOT load shard data into memory — lazy loading on retrieve
    pub fn loadFromDisk(self: *StorageProvider) !u32 {
        const dir_path = self.config.storage_dir orelse return 0;

        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return 0;
        defer dir.close();

        var count: u32 = 0;
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;

            // Check for .shard extension
            const name = entry.name;
            if (name.len != 70) continue; // 64 hex chars + ".shard" = 70
            if (!std.mem.endsWith(u8, name, ".shard")) continue;

            const hex_part = name[0..64];
            var hex_buf: [64]u8 = undefined;
            @memcpy(&hex_buf, hex_part);

            if (hexToHash(hex_buf)) |hash| {
                // Skip if already in memory
                if (!self.shards.contains(hash)) {
                    try self.disk_index.put(hash, true);
                    count += 1;
                }
            }
        }

        return count;
    }

    /// Persist a FileManifest to disk: {storage_dir}/../manifests/{file_id_hex}.manifest
    pub fn persistManifest(self: *StorageProvider, manifest: *const FileManifest) !void {
        const dir_path = self.config.storage_dir orelse return;

        // Build manifests directory path (sibling to shards dir)
        const manifests_dir = try std.fmt.allocPrint(self.allocator, "{s}/../manifests", .{dir_path});
        defer self.allocator.free(manifests_dir);

        // Ensure directory exists
        std.fs.cwd().makePath(manifests_dir) catch |path_err| {
            std.log.debug("storage: could not create manifests directory: {}", .{path_err});
        };

        const hex = hashToHex(manifest.file_id);
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.manifest", .{ manifests_dir, hex });
        defer self.allocator.free(file_path);

        const data = try manifest.serialize(self.allocator);
        defer self.allocator.free(data);

        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        try file.writeAll(data);
    }

    /// Load a FileManifest from disk
    pub fn loadManifest(self: *StorageProvider, file_id: [32]u8) !FileManifest {
        const dir_path = self.config.storage_dir orelse return error.NoDiskStorage;

        const manifests_dir = try std.fmt.allocPrint(self.allocator, "{s}/../manifests", .{dir_path});
        defer self.allocator.free(manifests_dir);

        const hex = hashToHex(file_id);
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.manifest", .{ manifests_dir, hex });
        defer self.allocator.free(file_path);

        const file = std.fs.cwd().openFile(file_path, .{}) catch return error.ManifestNotFound;
        defer file.close();

        const stat = try file.stat();
        if (stat.size > 16 * 1024 * 1024) return error.InvalidData; // max 16MB manifest
        const data = try self.allocator.alloc(u8, stat.size);
        defer self.allocator.free(data);

        const bytes_read = try file.readAll(data);
        if (bytes_read != stat.size) return error.InvalidData;

        return FileManifest.deserialize(data[0..bytes_read], self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate a unique test directory path to avoid race conditions between
/// parallel test binaries that all include storage.zig via transitive imports.
fn uniqueTestDir(comptime prefix: []const u8) [prefix.len + 16]u8 {
    var buf: [prefix.len + 16]u8 = undefined;
    @memcpy(buf[0..prefix.len], prefix);
    var random_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    const hex = std.fmt.bytesToHex(random_bytes, .lower);
    @memcpy(buf[prefix.len..], &hex);
    return buf;
}

test "storage provider store and retrieve" {
    const allocator = std.testing.allocator;
    var sp = StorageProvider.init(allocator, .{ .max_bytes = 1024 * 1024 });
    defer sp.deinit();

    const data = "Hello, Trinity Storage!";
    const hash = crypto.sha256(data);

    const ok = try sp.storeShard(hash, data);
    try std.testing.expect(ok);
    try std.testing.expect(sp.hasShard(hash));

    const retrieved = sp.retrieveShard(hash);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualSlices(u8, data, retrieved.?);
}

test "storage provider capacity tracking" {
    const allocator = std.testing.allocator;
    var sp = StorageProvider.init(allocator, .{ .max_bytes = 100 });
    defer sp.deinit();

    const data = "Small shard data here!"; // 22 bytes
    const hash = crypto.sha256(data);
    const ok = try sp.storeShard(hash, data);
    try std.testing.expect(ok);

    const stats = sp.getStats();
    try std.testing.expectEqual(@as(u32, 1), stats.total_shards);
    try std.testing.expectEqual(@as(u64, 22), stats.used_bytes);
    try std.testing.expectEqual(@as(u64, 78), stats.available_bytes);
}

test "storage provider rejects when full" {
    const allocator = std.testing.allocator;
    var sp = StorageProvider.init(allocator, .{ .max_bytes = 10 });
    defer sp.deinit();

    const data = "This is more than 10 bytes!";
    const hash = crypto.sha256(data);
    const ok = try sp.storeShard(hash, data);
    try std.testing.expect(!ok); // Should fail - over capacity
}

test "storage provider hash verification" {
    const allocator = std.testing.allocator;
    var sp = StorageProvider.init(allocator, .{ .max_bytes = 1024 });
    defer sp.deinit();

    var fake_hash: [32]u8 = undefined;
    @memset(&fake_hash, 0xFF);
    const result = sp.storeShard(fake_hash, "data does not match hash");
    try std.testing.expectError(error.HashMismatch, result);
}

test "storage provider handle store request" {
    const allocator = std.testing.allocator;
    var sp = StorageProvider.init(allocator, .{ .max_bytes = 1024 * 1024 });
    defer sp.deinit();

    const data = "shard data for store request";
    var node_id: [32]u8 = undefined;
    @memset(&node_id, 0x42);

    const req = protocol.StoreRequest{
        .shard_hash = crypto.sha256(data),
        .file_id = [_]u8{0xAA} ** 32,
        .shard_index = 0,
        .total_shards = 1,
        .data = data,
    };

    const resp = try sp.handleStoreRequest(req, node_id);
    try std.testing.expect(resp.success);
    try std.testing.expectEqualSlices(u8, &node_id, &resp.node_id);
}

test "storage provider handle retrieve request" {
    const allocator = std.testing.allocator;
    var sp = StorageProvider.init(allocator, .{ .max_bytes = 1024 * 1024 });
    defer sp.deinit();

    const data = "shard data for retrieval";
    const hash = crypto.sha256(data);
    _ = try sp.storeShard(hash, data);

    var requester: [32]u8 = undefined;
    @memset(&requester, 0x11);

    const req = protocol.RetrieveRequest{
        .shard_hash = hash,
        .requester_id = requester,
    };

    const resp = sp.handleRetrieveRequest(req);
    try std.testing.expect(resp.found);
    try std.testing.expectEqualSlices(u8, data, resp.data);
}

test "file manifest serialize/deserialize" {
    const allocator = std.testing.allocator;
    const hashes = try allocator.alloc([32]u8, 2);
    defer allocator.free(hashes);
    @memset(&hashes[0], 0x11);
    @memset(&hashes[1], 0x22);

    var name_buf: [256]u8 = [_]u8{0} ** 256;
    const file_name = "test_file.bin";
    @memcpy(name_buf[0..file_name.len], file_name);

    const manifest = FileManifest{
        .file_id = [_]u8{0xAA} ** 32,
        .file_name = name_buf,
        .file_name_len = file_name.len,
        .original_size = 12345,
        .shard_count = 2,
        .shard_size = 65536,
        .encryption_nonce = [_]u8{0xCC} ** 12,
        .encryption_tag = [_]u8{0xDD} ** 16,
        .created_at = 1700000000,
        .parity_hash = [_]u8{0xEE} ** 32,
        .rs_data_shards = 0,
        .rs_parity_shards = 0,
        .rs_last_shard_len = 0,
        .shard_hashes = hashes,
    };

    const bytes = try manifest.serialize(allocator);
    defer allocator.free(bytes);

    const parsed = try FileManifest.deserialize(bytes, allocator);
    defer allocator.free(parsed.shard_hashes);

    try std.testing.expectEqualSlices(u8, &manifest.file_id, &parsed.file_id);
    try std.testing.expectEqual(manifest.file_name_len, parsed.file_name_len);
    try std.testing.expectEqual(manifest.original_size, parsed.original_size);
    try std.testing.expectEqual(manifest.shard_count, parsed.shard_count);
    try std.testing.expectEqualSlices(u8, file_name, parsed.getFileName());
    try std.testing.expectEqualSlices(u8, &manifest.parity_hash, &parsed.parity_hash);
    try std.testing.expect(parsed.hasParity());
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.1 TESTS - Disk Persistence & Rewards
// ═══════════════════════════════════════════════════════════════════════════════

test "hashToHex and hexToHash roundtrip" {
    var hash: [32]u8 = undefined;
    for (0..32) |i| hash[i] = @intCast(i * 7 + 3);

    const hex = hashToHex(hash);
    const recovered = hexToHash(hex);
    try std.testing.expect(recovered != null);
    try std.testing.expectEqualSlices(u8, &hash, &recovered.?);

    // Test all zeros
    const zero_hash = [_]u8{0} ** 32;
    const zero_hex = hashToHex(zero_hash);
    for (zero_hex) |c| {
        try std.testing.expectEqual(@as(u8, '0'), c);
    }
    const zero_back = hexToHash(zero_hex);
    try std.testing.expect(zero_back != null);
    try std.testing.expectEqualSlices(u8, &zero_hash, &zero_back.?);

    // Test all 0xFF
    const ff_hash = [_]u8{0xFF} ** 32;
    const ff_hex = hashToHex(ff_hash);
    for (ff_hex) |c| {
        try std.testing.expectEqual(@as(u8, 'f'), c);
    }
}

test "reward tracker calculation" {
    var tracker = RewardTracker{
        .shards_hosted = 100,
        .retrievals_served = 10,
        .hosting_start = std.time.timestamp() - 3600, // 1 hour ago
        .bytes_uploaded = 0,
        .bytes_downloaded = 0,
    };

    const stats = tracker.getStats();
    try std.testing.expectEqual(@as(u64, 100), stats.shards_hosted);
    try std.testing.expectEqual(@as(u64, 10), stats.retrievals_served);

    // After 1 hour with 100 shards:
    // hosting = 100 * 1 * 50_000_000_000_000 = 5_000_000_000_000_000 wei = 0.005 TRI
    // retrieval = 10 * 500_000_000_000_000 = 5_000_000_000_000_000 wei = 0.005 TRI
    // total = 0.01 TRI
    const earned = tracker.calculateEarnedTri();
    try std.testing.expect(earned >= 0.009); // Allow some timing tolerance
    try std.testing.expect(earned <= 0.011);
}

test "disk persistence - store and recover" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_st_sr_");
    const test_dir: []const u8 = &test_dir_buf;

    // Clean up from any previous run
    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after test: {}", .{defer_err});
    };

    const data = "Hello, disk persistence!";
    const hash = crypto.sha256(data);

    // Store with disk persistence
    {
        var sp = StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .storage_dir = test_dir,
        });
        defer sp.deinit();

        const ok = try sp.storeShard(hash, data);
        try std.testing.expect(ok);
    }

    // Create a NEW provider pointed at the same directory
    {
        var sp2 = StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .storage_dir = test_dir,
        });
        defer sp2.deinit();

        // Should have nothing in memory
        try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(sp2.shards.count())));

        // Load from disk
        const recovered_count = try sp2.loadFromDisk();
        try std.testing.expectEqual(@as(u32, 1), recovered_count);

        // Should be in disk_index
        try std.testing.expect(sp2.hasShard(hash));

        // Retrieve (lazy load from disk)
        const retrieved = sp2.retrieveShard(hash);
        try std.testing.expect(retrieved != null);
        try std.testing.expectEqualSlices(u8, data, retrieved.?);
    }
}

test "lazy disk loading" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_lazy_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before lazy test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after lazy test: {}", .{defer_err});
    };

    const data1 = "First shard data for lazy test";
    const hash1 = crypto.sha256(data1);
    const data2 = "Second shard data for lazy test";
    const hash2 = crypto.sha256(data2);

    // Store two shards to disk
    {
        var sp = StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .storage_dir = test_dir,
        });
        defer sp.deinit();

        _ = try sp.storeShard(hash1, data1);
        _ = try sp.storeShard(hash2, data2);
    }

    // New provider - load index only (lazy)
    {
        var sp2 = StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .storage_dir = test_dir,
        });
        defer sp2.deinit();

        const count = try sp2.loadFromDisk();
        try std.testing.expectEqual(@as(u32, 2), count);

        // Nothing in memory yet
        try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(sp2.shards.count())));
        try std.testing.expectEqual(@as(u64, 0), sp2.used_bytes);

        // Retrieve shard1 - triggers lazy load
        const r1 = sp2.retrieveShard(hash1);
        try std.testing.expect(r1 != null);
        try std.testing.expectEqualSlices(u8, data1, r1.?);

        // Now 1 in memory, 1 still on disk only
        try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(sp2.shards.count())));

        // Retrieve shard2
        const r2 = sp2.retrieveShard(hash2);
        try std.testing.expect(r2 != null);
        try std.testing.expectEqualSlices(u8, data2, r2.?);

        // Both in memory now
        try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(sp2.shards.count())));
    }
}

test "manifest persist and load" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_mani_");
    const test_dir: []const u8 = &test_dir_buf;
    const shards_dir = try std.fmt.allocPrint(allocator, "{s}/shards", .{test_dir});
    defer allocator.free(shards_dir);
    const manifests_dir = try std.fmt.allocPrint(allocator, "{s}/manifests", .{test_dir});
    defer allocator.free(manifests_dir);

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before manifest test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(shards_dir);
    try std.fs.cwd().makePath(manifests_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after manifest test: {}", .{defer_err});
    };

    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .storage_dir = shards_dir,
    });
    defer sp.deinit();

    // Create a manifest
    const hashes = try allocator.alloc([32]u8, 2);
    defer allocator.free(hashes);
    @memset(&hashes[0], 0x11);
    @memset(&hashes[1], 0x22);

    var name_buf: [256]u8 = [_]u8{0} ** 256;
    const file_name = "persisted.bin";
    @memcpy(name_buf[0..file_name.len], file_name);

    const manifest = FileManifest{
        .file_id = [_]u8{0xBB} ** 32,
        .file_name = name_buf,
        .file_name_len = file_name.len,
        .original_size = 99999,
        .shard_count = 2,
        .shard_size = 65536,
        .encryption_nonce = [_]u8{0xCC} ** 12,
        .encryption_tag = [_]u8{0xDD} ** 16,
        .created_at = 1700000000,
        .parity_hash = [_]u8{0} ** 32,
        .rs_data_shards = 0,
        .rs_parity_shards = 0,
        .rs_last_shard_len = 0,
        .shard_hashes = hashes,
    };

    // Persist
    try sp.persistManifest(&manifest);

    // Load
    const loaded = try sp.loadManifest([_]u8{0xBB} ** 32);
    defer allocator.free(loaded.shard_hashes);

    try std.testing.expectEqualSlices(u8, &manifest.file_id, &loaded.file_id);
    try std.testing.expectEqual(manifest.original_size, loaded.original_size);
    try std.testing.expectEqual(manifest.shard_count, loaded.shard_count);
    try std.testing.expectEqualSlices(u8, file_name, loaded.getFileName());
}

test "loadFromDisk recovery with multiple shards" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_recv_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before recovery test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after recovery test: {}", .{defer_err});
    };

    // Store 5 shards
    const shard_data = [_][]const u8{
        "Shard zero data for recovery test!",
        "Shard one data for recovery test!!",
        "Shard two data for recovery test!!",
        "Shard three data for recovery!!!",
        "Shard four data for recovery!!!!",
    };

    var shard_hashes: [5][32]u8 = undefined;
    {
        var sp = StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .storage_dir = test_dir,
        });
        defer sp.deinit();

        for (shard_data, 0..) |data, i| {
            shard_hashes[i] = crypto.sha256(data);
            _ = try sp.storeShard(shard_hashes[i], data);
        }

        try std.testing.expectEqual(@as(u32, 5), @as(u32, @intCast(sp.shards.count())));
    }

    // New provider - recovery
    {
        var sp2 = StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .storage_dir = test_dir,
        });
        defer sp2.deinit();

        const count = try sp2.loadFromDisk();
        try std.testing.expectEqual(@as(u32, 5), count);

        // Verify all shards are retrievable
        for (shard_data, 0..) |data, i| {
            const retrieved = sp2.retrieveShard(shard_hashes[i]);
            try std.testing.expect(retrieved != null);
            try std.testing.expectEqualSlices(u8, data, retrieved.?);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.2 TESTS - LRU Eviction
// ═══════════════════════════════════════════════════════════════════════════════

test "LRU eviction triggers when over limit" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_lru1_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before LRU test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after LRU test: {}", .{defer_err});
    };

    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .storage_dir = test_dir,
        .max_memory_shards = 3,
    });
    defer sp.deinit();

    // Store 5 shards — should trigger eviction after 3
    const shard_data = [_][]const u8{
        "LRU shard zero data for eviction!",
        "LRU shard one data for eviction!!",
        "LRU shard two data for eviction!!",
        "LRU shard three data for eviction",
        "LRU shard four data for eviction!",
    };
    var hashes: [5][32]u8 = undefined;
    for (shard_data, 0..) |data, i| {
        hashes[i] = crypto.sha256(data);
        _ = try sp.storeShard(hashes[i], data);
    }

    // Should have at most 3 in memory
    try std.testing.expect(sp.getMemoryShardCount() <= 3);

    // Evicted shards should be in disk_index
    try std.testing.expect(sp.disk_index.count() >= 2);

    // All shards should still be accessible (from memory or disk)
    for (shard_data, 0..) |data, i| {
        try std.testing.expect(sp.hasShard(hashes[i]));
        const retrieved = sp.retrieveShard(hashes[i]);
        try std.testing.expect(retrieved != null);
        try std.testing.expectEqualSlices(u8, data, retrieved.?);
    }
}

test "LRU evicts oldest accessed shard" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_lru2_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before LRU2 test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after LRU2 test: {}", .{defer_err});
    };

    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .storage_dir = test_dir,
        .max_memory_shards = 2,
    });
    defer sp.deinit();

    // Store A, then B (fills limit of 2)
    const data_a = "Shard A oldest access LRU test!!";
    const hash_a = crypto.sha256(data_a);
    _ = try sp.storeShard(hash_a, data_a);

    const data_b = "Shard B second access LRU test!!";
    const hash_b = crypto.sha256(data_b);
    _ = try sp.storeShard(hash_b, data_b);

    // Both should be in memory now (limit=2)
    try std.testing.expectEqual(@as(u32, 2), sp.getMemoryShardCount());

    // Store C — should evict A (oldest)
    const data_c = "Shard C third access, triggers LRU";
    const hash_c = crypto.sha256(data_c);
    _ = try sp.storeShard(hash_c, data_c);

    // A should have been evicted from memory to disk
    try std.testing.expect(sp.getMemoryShardCount() <= 2);

    // A should still be accessible via disk
    const retrieved_a = sp.retrieveShard(hash_a);
    try std.testing.expect(retrieved_a != null);
    try std.testing.expectEqualSlices(u8, data_a, retrieved_a.?);
}

test "evicted shard still retrievable from disk" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_lru3_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before LRU3 test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after LRU3 test: {}", .{defer_err});
    };

    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .storage_dir = test_dir,
        .max_memory_shards = 1, // Only 1 shard in memory at a time
    });
    defer sp.deinit();

    // Store two shards — second evicts first from memory
    const data1 = "First shard for disk retrieval test";
    const hash1 = crypto.sha256(data1);
    _ = try sp.storeShard(hash1, data1);

    const data2 = "Second shard evicts first from memory";
    const hash2 = crypto.sha256(data2);
    _ = try sp.storeShard(hash2, data2);

    // Only 1 in memory
    try std.testing.expectEqual(@as(u32, 1), sp.getMemoryShardCount());

    // First shard should be on disk_index
    try std.testing.expect(sp.disk_index.contains(hash1));

    // Retrieve first shard — triggers lazy load from disk
    const retrieved = sp.retrieveShard(hash1);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualSlices(u8, data1, retrieved.?);

    // Now first is back in memory (and second was evicted)
    try std.testing.expect(sp.shards.contains(hash1));
}

test "LRU eviction skipped without disk storage" {
    const allocator = std.testing.allocator;

    // No storage_dir — eviction would lose data, so it should be skipped
    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .max_memory_shards = 2,
        .storage_dir = null,
    });
    defer sp.deinit();

    // Store 4 shards — no eviction should happen (no disk)
    const shard_data = [_][]const u8{
        "No disk: shard zero for LRU skip!",
        "No disk: shard one for LRU skip!!",
        "No disk: shard two for LRU skip!!",
        "No disk: shard three LRU skip!!!",
    };
    var hashes: [4][32]u8 = undefined;
    for (shard_data, 0..) |data, i| {
        hashes[i] = crypto.sha256(data);
        _ = try sp.storeShard(hashes[i], data);
    }

    // All 4 should remain in memory (no eviction without disk)
    try std.testing.expectEqual(@as(u32, 4), sp.getMemoryShardCount());
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(sp.disk_index.count())));
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.3 TESTS - Shard Pinning + Bandwidth Metering
// ═══════════════════════════════════════════════════════════════════════════════

test "pinned shard not evicted by LRU" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_pin1_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before pin test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after pin test: {}", .{defer_err});
    };

    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .storage_dir = test_dir,
        .max_memory_shards = 2,
    });
    defer sp.deinit();

    // Store A (pinned), B, C — C should evict B (not A since A is pinned)
    const data_a = "Pinned shard A should not evict!!";
    const hash_a = crypto.sha256(data_a);
    _ = try sp.storeShard(hash_a, data_a);
    sp.pinShard(hash_a); // Pin A

    const data_b = "Shard B unpinned should be evicted";
    const hash_b = crypto.sha256(data_b);
    _ = try sp.storeShard(hash_b, data_b);

    try std.testing.expectEqual(@as(u32, 2), sp.getMemoryShardCount());

    // Store C — should evict B (oldest unpinned), not A (pinned)
    const data_c = "Shard C triggers eviction of B!!!!";
    const hash_c = crypto.sha256(data_c);
    _ = try sp.storeShard(hash_c, data_c);

    // A should still be in memory (pinned)
    try std.testing.expect(sp.shards.contains(hash_a));
    try std.testing.expect(sp.isShardPinned(hash_a));
    try std.testing.expectEqual(@as(u32, 1), sp.getPinnedShardCount());

    // B should have been evicted to disk
    try std.testing.expect(sp.disk_index.contains(hash_b));

    // C should be in memory
    try std.testing.expect(sp.shards.contains(hash_c));
}

test "unpin allows eviction" {
    const allocator = std.testing.allocator;
    const test_dir_buf = uniqueTestDir("/tmp/trinity_pin2_");
    const test_dir: []const u8 = &test_dir_buf;

    std.fs.cwd().deleteTree(test_dir) catch |cleanup_err| {
        std.log.debug("storage test: cleanup before unpin test: {}", .{cleanup_err});
    };
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch |defer_err| {
        std.log.debug("storage test: cleanup after unpin test: {}", .{defer_err});
    };

    var sp = StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .storage_dir = test_dir,
        .max_memory_shards = 2,
    });
    defer sp.deinit();

    // Store A (pinned), B
    const data_a = "Shard A pinned then unpinned test!";
    const hash_a = crypto.sha256(data_a);
    _ = try sp.storeShard(hash_a, data_a);
    sp.pinShard(hash_a);

    const data_b = "Shard B stays in memory for unpin!";
    const hash_b = crypto.sha256(data_b);
    _ = try sp.storeShard(hash_b, data_b);

    // Unpin A
    sp.unpinShard(hash_a);
    try std.testing.expect(!sp.isShardPinned(hash_a));
    try std.testing.expectEqual(@as(u32, 0), sp.getPinnedShardCount());

    // Store C — should evict A (oldest, now unpinned)
    const data_c = "Shard C after unpin triggers evict!";
    const hash_c = crypto.sha256(data_c);
    _ = try sp.storeShard(hash_c, data_c);

    // A should have been evicted (unpinned, oldest)
    try std.testing.expect(!sp.shards.contains(hash_a));
    try std.testing.expect(sp.disk_index.contains(hash_a));
}

test "bandwidth metering tracks bytes" {
    var tracker = RewardTracker.init();

    tracker.recordUpload(1024);
    tracker.recordUpload(2048);
    tracker.recordDownload(512);
    tracker.recordDownload(256);

    try std.testing.expectEqual(@as(u64, 3072), tracker.bytes_uploaded);
    try std.testing.expectEqual(@as(u64, 768), tracker.bytes_downloaded);

    const stats = tracker.getStats();
    try std.testing.expectEqual(@as(u64, 3072), stats.bytes_uploaded);
    try std.testing.expectEqual(@as(u64, 768), stats.bytes_downloaded);
}

test "bandwidth reward calculation" {
    var tracker = RewardTracker{
        .shards_hosted = 0,
        .retrievals_served = 0,
        .hosting_start = std.time.timestamp(),
        .bytes_uploaded = 1024 * 1024 * 1024, // 1 GB uploaded
        .bytes_downloaded = 1024 * 1024 * 1024, // 1 GB downloaded
    };

    // 1 GB upload = 0.05 TRI = 50_000_000_000_000_000 wei
    // 1 GB download = 0.03 TRI = 30_000_000_000_000_000 wei
    // Total bandwidth = 0.08 TRI = 80_000_000_000_000_000 wei
    const bw_wei = tracker.calculateBandwidthRewardWei();
    try std.testing.expectEqual(@as(u128, 80_000_000_000_000_000), bw_wei);

    const earned = tracker.calculateEarnedTri();
    try std.testing.expect(earned >= 0.079);
    try std.testing.expect(earned <= 0.081);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.4 TESTS - Reed-Solomon FileManifest
// ═══════════════════════════════════════════════════════════════════════════════

test "FileManifest v1.4 RS roundtrip" {
    const allocator = std.testing.allocator;
    const hashes = try allocator.alloc([32]u8, 6); // 4 data + 2 parity
    defer allocator.free(hashes);
    for (0..6) |idx| @memset(&hashes[idx], @as(u8, @intCast(0x10 + idx)));

    var name_buf: [256]u8 = [_]u8{0} ** 256;
    const file_name = "rs_test.bin";
    @memcpy(name_buf[0..file_name.len], file_name);

    const manifest = FileManifest{
        .file_id = [_]u8{0xAA} ** 32,
        .file_name = name_buf,
        .file_name_len = file_name.len,
        .original_size = 32768,
        .shard_count = 6, // 4 data + 2 parity
        .shard_size = 8192,
        .encryption_nonce = [_]u8{0xCC} ** 12,
        .encryption_tag = [_]u8{0xDD} ** 16,
        .created_at = 1700000000,
        .parity_hash = [_]u8{0xEE} ** 32,
        .rs_data_shards = 4,
        .rs_parity_shards = 2,
        .rs_last_shard_len = 7000,
        .shard_hashes = hashes,
    };

    const bytes = try manifest.serialize(allocator);
    defer allocator.free(bytes);

    const parsed = try FileManifest.deserialize(bytes, allocator);
    defer allocator.free(parsed.shard_hashes);

    try std.testing.expect(parsed.hasReedSolomon());
    try std.testing.expectEqual(@as(u32, 4), parsed.rs_data_shards);
    try std.testing.expectEqual(@as(u32, 2), parsed.rs_parity_shards);
    try std.testing.expectEqual(@as(u32, 7000), parsed.rs_last_shard_len);
    try std.testing.expectEqual(@as(u32, 6), parsed.shard_count);
    try std.testing.expectEqualSlices(u8, &manifest.file_id, &parsed.file_id);
    try std.testing.expect(parsed.hasParity());
}

test "FileManifest v1.2 backward compat with v1.4 deserialize" {
    const allocator = std.testing.allocator;
    const hashes = try allocator.alloc([32]u8, 2);
    defer allocator.free(hashes);
    @memset(&hashes[0], 0x11);
    @memset(&hashes[1], 0x22);

    var name_buf: [256]u8 = [_]u8{0} ** 256;
    const file_name = "old_file.bin";
    @memcpy(name_buf[0..file_name.len], file_name);

    // Create a v1.2-sized buffer manually (374 + 2*32 = 438 bytes)
    // This simulates a v1.2 manifest (no RS fields)
    const v12_size = FileManifest.HEADER_SIZE_V12 + 2 * 32;
    const buf = try allocator.alloc(u8, v12_size);
    defer allocator.free(buf);

    // Write header fields manually
    var i: usize = 0;
    @memset(buf[i..][0..32], 0xAA); // file_id
    i += 32;
    @memcpy(buf[i..][0..256], &name_buf); // file_name
    i += 256;
    std.mem.writeInt(u16, buf[i..][0..2], file_name.len, .little);
    i += 2;
    std.mem.writeInt(u64, buf[i..][0..8], 5000, .little); // original_size
    i += 8;
    std.mem.writeInt(u32, buf[i..][0..4], 2, .little); // shard_count
    i += 4;
    std.mem.writeInt(u32, buf[i..][0..4], 65536, .little); // shard_size
    i += 4;
    @memset(buf[i..][0..12], 0xCC); // nonce
    i += 12;
    @memset(buf[i..][0..16], 0xDD); // tag
    i += 16;
    std.mem.writeInt(i64, buf[i..][0..8], 1700000000, .little); // created_at
    i += 8;
    @memset(buf[i..][0..32], 0xEE); // parity_hash
    i += 32;
    // shard hashes
    @memset(buf[i..][0..32], 0x11);
    i += 32;
    @memset(buf[i..][0..32], 0x22);
    i += 32;

    // Deserialize as v1.4 code — should handle v1.2 gracefully
    const parsed = try FileManifest.deserialize(buf, allocator);
    defer allocator.free(parsed.shard_hashes);

    try std.testing.expect(!parsed.hasReedSolomon()); // No RS in v1.2
    try std.testing.expectEqual(@as(u32, 0), parsed.rs_data_shards);
    try std.testing.expectEqual(@as(u32, 0), parsed.rs_parity_shards);
    try std.testing.expectEqual(@as(u32, 0), parsed.rs_last_shard_len);
    try std.testing.expectEqual(@as(u32, 2), parsed.shard_count);
    try std.testing.expect(parsed.hasParity()); // parity_hash is 0xEE, not zero
}
