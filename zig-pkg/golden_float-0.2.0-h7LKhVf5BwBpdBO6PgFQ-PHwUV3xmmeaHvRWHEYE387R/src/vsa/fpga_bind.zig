// 🤖 TRINITY v0.11.0: Suborbital Order
// FPGA VSA Bind Interface — Week 2
//
// Provides Zig interface to FPGA-accelerated VSA operations
// via UART communication with QMTECH XC7A100T

const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const HybridBigInt = common.HybridBigInt;
const Trit = common.Trit;

pub const Config = struct {
    /// UART device path
    device: []const u8,
    /// Baud rate
    baud: u32 = 115200,
    /// Vector dimension (must match FPGA)
    dimension: usize = 256,
    /// Timeout in milliseconds
    timeout_ms: u32 = 5000,
};

pub const FPGAInterface = struct {
    port: std.fs.File,
    config: Config,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize FPGA interface
    pub fn init(config: Config, allocator: std.mem.Allocator) !Self {
        const device_path = if (builtin.os.tag == .linux)
            "/dev/ttyUSB0"
        else if (builtin.os.tag == .macos)
            "/dev/tty.usbserial-.*"
        else
            return error.UnsupportedOS;

        // Try to open the UART device
        const port = std.fs.openFileAbsolute(device_path, .{
            .read = true,
            .write = true,
        }) catch |err| {
            std.log.err("Failed to open FPGA UART device: {}", .{err});
            return err;
        };

        return Self{
            .port = port,
            .config = config,
            .allocator = allocator,
        };
    }

    /// Close FPGA interface
    pub fn deinit(self: *Self) void {
        self.port.close();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // UART PROTOCOL
    // ═══════════════════════════════════════════════════════════════════════

    const Command = enum(u8) {
        BIND = 0x01,
        UNBIND = 0x02,
        BUNDLE2 = 0x03,
        BUNDLE3 = 0x04,
        SIMILARITY = 0x05,
        PING = 0xFF,
    };

    const Response = enum(u8) {
        OK = 0x00,
        ERROR = 0x01,
        BUSY = 0x02,
        PONG = 0xFF,
    };

    /// Send command to FPGA
    fn sendCommand(self: *Self, cmd: Command, data: []const u8) !void {
        var buffer: [1024]u8 = undefined;
        var offset: usize = 0;

        buffer[offset] = @intFromEnum(cmd);
        offset += 1;

        buffer[offset] = @intCast(data.len & 0xFF);
        offset += 1;

        @memcpy(buffer[offset..][0..data.len], data);
        offset += data.len;

        // Simple checksum
        var checksum: u8 = 0;
        for (buffer[0..offset]) |b| checksum ^= b;
        buffer[offset] = checksum;
        offset += 1;

        _ = try self.port.writeAll(buffer[0..offset]);
    }

    /// Receive response from FPGA
    fn recvResponse(self: *Self, expected_len: usize) ![]u8 {
        _ = expected_len;
        var buffer: [1024]u8 = undefined;
        const header_len = 2; // status + len

        const n = try self.port.readAll(buffer[0..header_len]);
        if (n < header_len) return error.ShortRead;

        const status = buffer[0];
        const len = buffer[1];

        if (status == @intFromEnum(Response.ERROR)) {
            return error.FPGAError;
        }

        if (len > 0) {
            const n2 = try self.port.readAll(buffer[header_len .. header_len + len]);
            if (n2 < len) return error.ShortRead;
        }

        // Verify checksum
        // ...

        return buffer[0 .. header_len + len];
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VSA OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// Bind two hypervectors on FPGA
    pub fn bind(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !HybridBigInt {
        a.ensureUnpacked();
        b.ensureUnpacked();

        const dim = @min(self.config.dimension, @max(a.trit_len, b.trit_len));

        // Pack trits into 2-bit format for FPGA
        const bytes_needed = (dim * 2 + 7) / 8;
        var buffer = try self.allocator.alloc(u8, bytes_needed * 2);
        defer self.allocator.free(buffer);

        // Pack vector A
        for (0..dim) |i| {
            const trit_val: i2 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const encoded = encodeTrit(trit_val);
            const byte_idx = (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            buffer[byte_idx] |= encoded << bit_offset;
            if (bit_offset >= 6) {
                buffer[byte_idx + 1] |= encoded >> (8 - bit_offset);
            }
        }

        // Pack vector B (offset by bytes_needed)
        const b_offset = bytes_needed;
        for (0..dim) |i| {
            const trit_val: i2 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            const encoded = encodeTrit(trit_val);
            const byte_idx = b_offset + (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            buffer[byte_idx] |= encoded << bit_offset;
            if (bit_offset >= 6) {
                buffer[byte_idx + 1] |= encoded >> (8 - bit_offset);
            }
        }

        // Send BIND command
        try self.sendCommand(Command.BIND, buffer[0 .. bytes_needed * 2]);

        // Receive result
        const response = try self.recvResponse(bytes_needed);

        // Unpack result
        var result = HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.trit_len = dim;

        for (0..dim) |i| {
            const byte_idx = 2 + (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            const encoded = (response[byte_idx] >> bit_offset) & 0x03;
            result.unpacked_cache[i] = decodeTrit(encoded);
        }

        return result;
    }

    /// Check if FPGA is responsive
    pub fn ping(self: *Self) !bool {
        try self.sendCommand(Command.PING, &[_]u8{});
        const response = try self.recvResponse(0);
        return response[0] == @intFromEnum(Response.PONG);
    }

    /// Bundle two hypervectors on FPGA (majority voting)
    pub fn bundle(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !HybridBigInt {
        a.ensureUnpacked();
        b.ensureUnpacked();

        const dim = @min(self.config.dimension, @max(a.trit_len, b.trit_len));
        const bytes_needed = (dim * 2 + 7) / 8;
        var buffer = try self.allocator.alloc(u8, bytes_needed * 2);
        defer self.allocator.free(buffer);

        // Pack vectors (same as bind)
        for (0..dim) |i| {
            const trit_val: i2 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const encoded = encodeTrit(trit_val);
            const byte_idx = (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            buffer[byte_idx] |= encoded << bit_offset;
            if (bit_offset >= 6) {
                buffer[byte_idx + 1] |= encoded >> (8 - bit_offset);
            }
        }

        const b_offset = bytes_needed;
        for (0..dim) |i| {
            const trit_val: i2 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            const encoded = encodeTrit(trit_val);
            const byte_idx = b_offset + (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            buffer[byte_idx] |= encoded << bit_offset;
            if (bit_offset >= 6) {
                buffer[byte_idx + 1] |= encoded >> (8 - bit_offset);
            }
        }

        // Send BUNDLE command
        try self.sendCommand(Command.BUNDLE2, buffer[0 .. bytes_needed * 2]);

        // Receive result (same format as bind)
        const response = try self.recvResponse(bytes_needed);

        // Unpack result
        var result = HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.trit_len = dim;

        for (0..dim) |i| {
            const byte_idx = 2 + (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            const encoded = (response[byte_idx] >> bit_offset) & 0x03;
            result.unpacked_cache[i] = decodeTrit(encoded);
        }

        return result;
    }

    /// Compute dot product similarity on FPGA
    pub fn similarity(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !f64 {
        a.ensureUnpacked();
        b.ensureUnpacked();

        const dim = @min(self.config.dimension, @max(a.trit_len, b.trit_len));
        const bytes_needed = (dim * 2 + 7) / 8;
        var buffer = try self.allocator.alloc(u8, bytes_needed * 2);
        defer self.allocator.free(buffer);

        // Pack vectors
        for (0..dim) |i| {
            const trit_val: i2 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const encoded = encodeTrit(trit_val);
            const byte_idx = (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            buffer[byte_idx] |= encoded << bit_offset;
            if (bit_offset >= 6) {
                buffer[byte_idx + 1] |= encoded >> (8 - bit_offset);
            }
        }

        const b_offset = bytes_needed;
        for (0..dim) |i| {
            const trit_val: i2 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            const encoded = encodeTrit(trit_val);
            const byte_idx = b_offset + (i * 2) / 8;
            const bit_offset = (i * 2) % 8;
            buffer[byte_idx] |= encoded << bit_offset;
            if (bit_offset >= 6) {
                buffer[byte_idx + 1] |= encoded >> (8 - bit_offset);
            }
        }

        // Send SIMILARITY command
        try self.sendCommand(Command.SIMILARITY, buffer[0 .. bytes_needed * 2]);

        // Receive result (3 bytes: status + dot LSB + dot MSB)
        const response = try self.recvResponse(3);

        // Parse dot product (signed 11-bit: -256 to +256)
        const dot_lsb = response[1];
        const dot_msb = response[2] & 0x07;
        var dot: i11 = @as(i11, @bitCast(@as(u11, @intCast(dot_msb)) << 8 | dot_lsb));
        // Sign extend
        if (dot_msb & 0x04) dot |= 0xF800;

        // Normalize by dimension (cosine similarity for unit vectors)
        // For raw similarity: just return dot / dim
        return @as(f64, @floatFromInt(dot)) / @as(f64, @floatFromInt(dim));
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TRIT ENCODING
    // ═══════════════════════════════════════════════════════════════════════

    /// Encode trit to 2-bit format
    inline fn encodeTrit(t: i2) u2 {
        return switch (t) {
            0 => 0b00,
            1 => 0b01,
            -1 => 0b10,
            else => unreachable,
        };
    }

    /// Decode trit from 2-bit format
    inline fn decodeTrit(e: u2) i2 {
        return switch (e) {
            0b00 => 0,
            0b01 => 1,
            0b10 => -1,
            else => 0,
        };
    }
};

// ═════════════════════════════════════════════════════════════════════════════
// CPU FALLBACK (when FPGA unavailable)
// ═════════════════════════════════════════════════════════════════════════════

pub const CpuFallback = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }

    /// Bind using CPU (simulates FPGA behavior)
    pub fn bind(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !HybridBigInt {
        _ = self;
        const core = @import("core.zig");
        return core.bind(a, b);
    }

    /// Bundle using CPU
    pub fn bundle(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !HybridBigInt {
        _ = self;
        const core = @import("core.zig");
        return core.bundle2(a, b);
    }

    /// Similarity using CPU
    pub fn similarity(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !f64 {
        _ = self;
        const core = @import("core.zig");
        return core.cosineSimilarity(a, b);
    }
};

// ═════════════════════════════════════════════════════════════════════════════
// UNIFIED INTERFACE (auto-detect FPGA)
// ═════════════════════════════════════════════════════════════════════════════

pub const AutoVSA = struct {
    fpga: ?FPGAInterface,
    cpu: CpuFallback,
    use_fpga: bool,

    const Self = @This();

    /// Initialize with auto-detection
    pub fn init(config: Config, allocator: std.mem.Allocator) Self {
        const fpga = FPGAInterface.init(config, allocator) catch |err| {
            std.log.warn("FPGA unavailable ({}), using CPU fallback", .{err});
            return Self{
                .fpga = null,
                .cpu = CpuFallback.init(allocator),
                .use_fpga = false,
            };
        };

        // Verify FPGA is responsive
        if (fpga.ping() catch false) {
            std.log.info("FPGA VSA accelerator detected", .{});
            return Self{
                .fpga = fpga,
                .cpu = CpuFallback.init(allocator),
                .use_fpga = true,
            };
        } else {
            fpga.deinit();
            std.log.warn("FPGA not responsive, using CPU fallback", .{});
            return Self{
                .fpga = null,
                .cpu = CpuFallback.init(allocator),
                .use_fpga = false,
            };
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.fpga) |*f| f.deinit();
    }

    /// Bind with automatic FPGA/CPU selection
    pub fn bind(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !HybridBigInt {
        if (self.use_fpga and self.fpga != null) {
            return self.fpga.?.bind(a, b);
        } else {
            return self.cpu.bind(a, b);
        }
    }

    /// Bundle with automatic FPGA/CPU selection
    pub fn bundle(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !HybridBigInt {
        if (self.use_fpga and self.fpga != null) {
            return self.fpga.?.bundle(a, b);
        } else {
            return self.cpu.bundle(a, b);
        }
    }

    /// Similarity with automatic FPGA/CPU selection
    pub fn similarity(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !f64 {
        if (self.use_fpga and self.fpga != null) {
            return self.fpga.?.similarity(a, b);
        } else {
            return self.cpu.similarity(a, b);
        }
    }
};

// Backward compatibility alias
pub const AutoBind = AutoVSA;

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "fpga bind: trit encoding" {
    const testing = std.testing;

    try testing.expectEqual(@as(u2, 0b00), FPGAInterface.encodeTrit(0));
    try testing.expectEqual(@as(u2, 0b01), FPGAInterface.encodeTrit(1));
    try testing.expectEqual(@as(u2, 0b10), FPGAInterface.encodeTrit(-1));
}

test "fpga bind: trit decoding" {
    const testing = std.testing;

    try testing.expectEqual(@as(i2, 0), FPGAInterface.decodeTrit(0b00));
    try testing.expectEqual(@as(i2, 1), FPGAInterface.decodeTrit(0b01));
    try testing.expectEqual(@as(i2, -1), FPGAInterface.decodeTrit(0b10));
}

test "fpga bind: cpu fallback" {
    const testing = std.testing;

    var cpu = CpuFallback.init(testing.allocator);

    var a = HybridBigInt.zero();
    a.mode = .unpacked_mode;
    a.trit_len = 16;

    var b = HybridBigInt.zero();
    b.mode = .unpacked_mode;
    b.trit_len = 16;

    // Fill with test data
    for (0..16) |i| {
        a.unpacked_cache[i] = @intCast(@rem(i, 3) - 1);
        b.unpacked_cache[i] = @intCast(@rem(i + 1, 3) - 1);
    }

    const result = try cpu.bind(&a, &b);
    try testing.expectEqual(@as(usize, 16), result.trit_len);
}

// φ² + 1/φ² = 3 = TRINITY
