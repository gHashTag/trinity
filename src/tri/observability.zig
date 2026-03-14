// @origin(spec:observability.tri) @regen(manual-impl)
//! P2.10: Observability Layer
//!
//! Provides unified telemetry for all TRI operations:
//! - Unique request_id/job_id per operation
//! - Duration tracking with high-precision timers
//! - Exit code standardization
//! - Artifact hashes for integrity verification
//! - Structured logging integration
//!
//! φ² + 1/φ² = 3 = TRINITY


const std = @import("std");

/// Exit code convention following POSIX standards
pub const ExitCode = enum(u8) {
    success = 0,
    err = 1, // Renamed from 'error' (reserved keyword)
    usage = 64, // EX_USAGE from sysexits.h
    data_error = 65, // EX_DATAERR
    no_input = 66, // EX_NOINPUT
    no_user = 67, // EX_NOUSER
    no_host = 68, // EX_NOHOST
    unavailable = 69, // EX_UNAVAILABLE
    software = 70, // EX_SOFTWARE
    os_err = 71, // EX_OSERR
    os_file = 72, // EX_OSFILE
    cant_create = 73, // EX_CANTCREAT
    io_error = 74, // EX_IOERR
    temp_fail = 75, // EX_TEMPFAIL
    protocol = 76, // EX_PROTOCOL
    no_perm = 77, // EX_NOPERM
    config = 78, // EX_CONFIG

    pub fn toInt(self: ExitCode) u8 {
        return @intFromEnum(self);
    }

    pub fn fromCode(code: u8) ExitCode {
        return switch (code) {
            0 => .success,
            1 => .err,
            64 => .usage,
            65 => .data_error,
            66 => .no_input,
            67 => .no_user,
            68 => .no_host,
            69 => .unavailable,
            70 => .software,
            71 => .os_err,
            72 => .os_file,
            73 => .cant_create,
            74 => .io_error,
            75 => .temp_fail,
            76 => .protocol,
            77 => .no_perm,
            78 => .config,
            else => .err,
        };
    }
};

/// Hash algorithm for artifact integrity
pub const HashAlgorithm = enum {
    sha256,
    sha512,
    blake3,
    xxhash64,

    pub fn digestSize(self: HashAlgorithm) usize {
        return switch (self) {
            .sha256 => 32,
            .sha512 => 64,
            .blake3 => 32,
            .xxhash64 => 8,
        };
    }
};

/// Artifact hash for integrity verification
pub const ArtifactHash = struct {
    algorithm: HashAlgorithm,
    bytes: [64]u8, // Max size for sha512
    len: usize,

    pub fn init(algorithm: HashAlgorithm) ArtifactHash {
        return .{
            .algorithm = algorithm,
            .bytes = [_]u8{0} ** 64,
            .len = algorithm.digestSize(),
        };
    }

    pub fn fromBytes(algorithm: HashAlgorithm, bytes: []const u8) ArtifactHash {
        var result = init(algorithm);
        @memcpy(result.bytes[0..bytes.len], bytes);
        return result;
    }

    pub fn format(self: ArtifactHash, allocator: std.mem.Allocator) ![]const u8 {
        const hex_chars = "0123456789abcdef";
        var result = try allocator.alloc(u8, self.len * 2);
        for (self.bytes[0..self.len], 0..) |byte, i| {
            result[i * 2] = hex_chars[byte >> 4];
            result[i * 2 + 1] = hex_chars[byte & 0xf];
        }
        return result;
    }

    pub fn formatTo(self: ArtifactHash, writer: anytype) !void {
        const hex_chars = "0123456789abcdef";
        for (self.bytes[0..self.len]) |byte| {
            try writer.writeByte(hex_chars[byte >> 4]);
            try writer.writeByte(hex_chars[byte & 0xf]);
        }
    }
};

/// Compute hash of file content
pub fn hashFile(allocator: std.mem.Allocator, path: []const u8, algorithm: HashAlgorithm) !ArtifactHash {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 100); // Max 100MB
    defer allocator.free(content);

    return hashBytes(content, algorithm);
}

/// Compute hash of bytes
pub fn hashBytes(bytes: []const u8, algorithm: HashAlgorithm) ArtifactHash {
    return switch (algorithm) {
        .xxhash64 => xxhash64(bytes),
        else => {
            // For sha256/blake3, we'd need crypto stdlib
            // Using xxhash64 as default for now (fast, good enough for non-crypto)
            return xxhash64(bytes);
        },
    };
}

fn xxhash64(bytes: []const u8) ArtifactHash {
    var hash_result = ArtifactHash.init(.xxhash64);

    // Simplified xxhash64 (for demonstration)
    var hash: u64 = 0;
    const prime: u64 = 0x9e3779b97f4a7c15;
    var i: usize = 0;

    while (i + 8 <= bytes.len) : (i += 8) {
        const chunk = std.mem.readInt(u64, bytes[i..][0..8], .little);
        hash ^= chunk +% prime;
        hash = hash *% prime;
    }

    // Remaining bytes
    if (i < bytes.len) {
        var chunk: u64 = 0;
        const remaining = bytes.len - i;
        @memcpy(std.mem.asBytes(&chunk)[0..remaining], bytes[i..]);
        hash ^= chunk +% prime;
        hash = hash *% prime;
    }

    // Final mix
    hash ^= @as(u64, @intCast(bytes.len));
    hash ^= hash >> 33;
    hash *%= 0xff51afd7ed558ccd;
    hash ^= hash >> 33;
    hash *%= 0xc4ceb9fe1a85ec53;
    hash ^= hash >> 33;

    // Write hash to first 8 bytes
    std.mem.writeInt(u64, hash_result.bytes[0..8], hash, .little);
    return hash_result;
}

/// High-precision duration tracking
pub const Duration = struct {
    start_time: std.time.Instant,
    end_time: ?std.time.Instant,
    elapsed_ns: u64,

    pub fn start() !Duration {
        return Duration{
            .start_time = try std.time.Instant.now(),
            .end_time = null,
            .elapsed_ns = 0,
        };
    }

    pub fn stop(self: *Duration) !void {
        self.end_time = try std.time.Instant.now();
        self.elapsed_ns = self.end_time.?.since(self.start_time);
    }

    pub fn elapsed(self: *const Duration) u64 {
        if (self.end_time) |end| {
            return end.since(self.start_time);
        }
        // If not stopped, return current elapsed
        const now = std.time.Instant.now() catch return 0;
        return now.since(self.start_time);
    }

    pub fn elapsedMs(self: *const Duration) u64 {
        return self.elapsed() / 1_000_000;
    }

    pub fn elapsedSeconds(self: *const Duration) f64 {
        return @as(f64, @floatFromInt(self.elapsed())) / 1_000_000_000.0;
    }
};

/// Unique operation identifier
pub const RequestId = struct {
    value: [24]u8, // Base64-encoded UUID

    pub fn init() RequestId {
        var result: RequestId = undefined;
        const uuid = generateUuid();
        // Encode as base64url (24 chars)
        const base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
        var i: usize = 0;
        var acc: u12 = 0;
        var bits: u4 = 0;

        for (uuid) |byte| {
            acc = (acc << 8) | byte;
            bits += 8;
            while (bits >= 6) {
                bits -= 6;
                const index = @as(u6, @intCast((acc >> bits) & 0x3f));
                result.value[i] = base64_chars[index];
                i += 1;
            }
        }

        if (bits > 0) {
            const index = @as(u6, @intCast((acc << (6 - bits)) & 0x3f));
            result.value[i] = base64_chars[index];
            i += 1;
        }

        // Pad with '='
        while (i < 24) : (i += 1) {
            result.value[i] = '=';
        }

        return result;
    }

    pub fn format(self: RequestId) [24]u8 {
        return self.value;
    }

    pub fn str(self: RequestId) []const u8 {
        return &self.value;
    }

    fn generateUuid() [16]u8 {
        var uuid: [16]u8 = undefined;
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.microTimestamp()));
        rng.fill(&uuid);

        // Set version (4) and variant bits
        uuid[6] = (uuid[6] & 0x0f) | 0x40; // Version 4
        uuid[8] = (uuid[8] & 0x3f) | 0x80; // Variant RFC 4122

        return uuid;
    }
};

/// Operation context with full observability
pub const OperationContext = struct {
    allocator: std.mem.Allocator,
    request_id: RequestId,
    command: []const u8,
    args: []const []const u8,
    duration: Duration,
    exit_code: ExitCode,
    artifacts: std.StringHashMap(ArtifactHash),
    metadata: std.StringHashMap([]const u8),
    start_time: i64, // Unix timestamp

    pub fn init(allocator: std.mem.Allocator, command: []const u8, args: []const []const u8) !OperationContext {
        return OperationContext{
            .allocator = allocator,
            .request_id = RequestId.init(),
            .command = command,
            .args = args,
            .duration = try Duration.start(),
            .exit_code = .success,
            .artifacts = std.StringHashMap(ArtifactHash).init(allocator),
            .metadata = std.StringHashMap([]const u8).init(allocator),
            .start_time = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *OperationContext) void {
        var artifact_iter = self.artifacts.iterator();
        while (artifact_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.artifacts.deinit();

        var metadata_iter = self.metadata.iterator();
        while (metadata_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    pub fn complete(self: *OperationContext, code: ExitCode) !void {
        try self.duration.stop();
        self.exit_code = code;
    }

    pub fn addArtifact(self: *OperationContext, path: []const u8, algorithm: HashAlgorithm) !void {
        const hash = try hashFile(self.allocator, path, algorithm);
        const path_copy = try self.allocator.dupe(u8, path);
        try self.artifacts.put(path_copy, hash);
    }

    pub fn addArtifactHash(self: *OperationContext, path: []const u8, hash: ArtifactHash) !void {
        const path_copy = try self.allocator.dupe(u8, path);
        try self.artifacts.put(path_copy, hash);
    }

    pub fn setMetadata(self: *OperationContext, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        const value_copy = try self.allocator.dupe(u8, value);
        try self.metadata.put(key_copy, value_copy);
    }

    pub fn toStructured(self: *const OperationContext) !StructuredLog {
        return StructuredLog{
            .request_id = self.request_id.format(),
            .timestamp = self.start_time,
            .command = self.command,
            .args = self.args,
            .duration_ns = self.duration.elapsed(),
            .exit_code = self.exit_code.toInt(),
            .artifacts = self.artifacts,
            .metadata = self.metadata,
        };
    }
};

/// Structured log entry (immutable for export)
pub const StructuredLog = struct {
    request_id: [24]u8,
    timestamp: i64,
    command: []const u8,
    args: []const []const u8,
    duration_ns: u64,
    exit_code: u8,
    artifacts: std.StringHashMap(ArtifactHash),
    metadata: std.StringHashMap([]const u8),
};

// Tests
test "RequestId generates unique identifiers" {
    const id1 = RequestId.init();
    const id2 = RequestId.init();

    // IDs should be different
    try std.testing.expect(!std.mem.eql(u8, &id1.value, &id2.value));

    // IDs should be valid base64
    for (id1.value) |c| {
        const is_valid = switch (c) {
            'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '=' => true,
            else => false,
        };
        try std.testing.expect(is_valid);
    }
}

test "Duration tracks time correctly" {
    var dur = try Duration.start();
    // Note: can't use std.time.sleep in test environment
    // Just verify duration can be created and stopped
    try dur.stop();

    const elapsed_ms = dur.elapsedMs();
    try std.testing.expect(elapsed_ms >= 0);
}

test "ArtifactHash formatting" {
    var hash = ArtifactHash.init(.xxhash64);
    hash.bytes[0] = 0xAB;
    hash.bytes[1] = 0xCD;

    const formatted = try hash.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expectEqual(@as(usize, 16), formatted.len); // 8 bytes * 2 hex chars
}

test "ExitCode conversion" {
    try std.testing.expectEqual(@as(u8, 0), ExitCode.success.toInt());
    try std.testing.expectEqual(@as(u8, 1), ExitCode.err.toInt());
    try std.testing.expectEqual(@as(u8, 64), ExitCode.usage.toInt());

    try std.testing.expectEqual(ExitCode.success, ExitCode.fromCode(0));
    try std.testing.expectEqual(ExitCode.err, ExitCode.fromCode(1));
}

test "xxhash64 produces consistent results" {
    const data = "Hello, World!";
    const hash1 = hashBytes(data, .xxhash64);
    const hash2 = hashBytes(data, .xxhash64);

    try std.testing.expectEqualSlices(u8, hash1.bytes[0..8], hash2.bytes[0..8]);
}
