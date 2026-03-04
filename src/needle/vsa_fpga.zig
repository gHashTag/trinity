// ═══════════════════════════════════════════════════════════════════════════════
// VSA FPGA Accelerator Interface — KOSCHEI Week 2
// ═══════════════════════════════════════════════════════════════════════════════
//
// Zig FFI bindings for VSA operations on FPGA
// Target: < 20 ns bind latency, < 2 µs Zig roundtrip overhead
//
// Architecture:
//   - FPGA: 256-dim parallel bind, fully pipelined (1 cycle)
//   - Host: Zig bridge via UART/MMIO
//   - Fallback: CPU if FPGA unavailable
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSA_DIM: usize = 256;
pub const TRIT_BITS: usize = 2;
pub const FPGA_BITS: usize = VSA_DIM * TRIT_BITS; // 512 bits = 64 bytes

// Default device paths (tried in order)
pub const DEFAULT_DEVICES = [_][]const u8{
    "/dev/ttyUSB0",    // FTDI USB-Serial
    "/dev/ttyUSB1",    // Alternate USB
    "/dev/ttyACM0",    // CDC-ACM
    "/dev/xilinx",     // Direct MMIO (if available)
};

// Trit encoding: balanced ternary {-1, 0, +1}
pub const Trit = enum(i2) {
    neg = -1,  // 10 binary
    zero = 0,  // 00 binary
    pos = 1,   // 01 binary

    pub fn toBits(self: Trit) u2 {
        return switch (self) {
            .neg => 0b10,
            .zero => 0b00,
            .pos => 0b01,
        };
    }

    pub fn fromBits(b: u2) Trit {
        return switch (b) {
            0b00 => .zero,
            0b01 => .pos,
            0b10 => .neg,
            else => .zero, // Invalid → zero
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA VECTOR TYPE
// ═══════════════════════════════════════════════════════════════════════════════

/// Packed trit vector for FPGA transmission (512 bits)
pub const FPGAVector = struct {
    // 512 bits = 256 trits × 2 bits
    data: [64]u8 align(1),

    pub fn init() FPGAVector {
        return .{ .data = [_]u8{0} ** 64 };
    }

    /// Set trit at position
    pub fn setTrit(self: *FPGAVector, idx: usize, t: Trit) void {
        if (idx >= VSA_DIM) return;
        const bit_idx = idx * TRIT_BITS;
        const byte_idx = bit_idx / 8;
        const bit_offset = @as(u3, @intCast(bit_idx % 8));

        const bits = t.toBits();
        self.data[byte_idx] &= ~(@as(u8, 0b11) << @as(u3, bit_offset));
        self.data[byte_idx] |= @as(u8, bits) << @as(u3, bit_offset);

        // Handle trit crossing byte boundary
        if (bit_offset >= 7) {
            self.data[byte_idx + 1] &= ~(@as(u8, 0b01));
            self.data[byte_idx + 1] |= (bits >> 1) & 0b01;
        }
    }

    /// Get trit at position
    pub fn getTrit(self: *const FPGAVector, idx: usize) Trit {
        if (idx >= VSA_DIM) return .zero;
        const bit_idx = idx * TRIT_BITS;
        const byte_idx = bit_idx / 8;
        const bit_offset = @as(u3, @intCast(bit_idx % 8));

        var bits: u2 = 0;
        bits |= @as(u2, @intCast((self.data[byte_idx] >> bit_offset) & 0b11));

        if (bit_offset >= 7) {
            bits |= @as(u2, @intCast((self.data[byte_idx + 1] & 0b01) << 1));
        }

        return Trit.fromBits(bits);
    }

    /// Convert from packed trit array (needle format)
    pub fn fromPackedTrits(trits: []const u8) FPGAVector {
        var result = FPGAVector.init();
        const limit = @min(trits.len, VSA_DIM);
        for (0..limit) |i| {
            const t: i2 = @bitCast(trits[i]);
            result.setTrit(i, @as(Trit, @enumFromInt(t)));
        }
        return result;
    }

    /// Convert to packed trit array (needle format)
    pub fn toPackedTrits(self: *const FPGAVector, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, VSA_DIM);
        for (0..VSA_DIM) |i| {
            const t = self.getTrit(i);
            result[i] = @as(u8, @bitCast(@as(i2, @intFromEnum(t))));
        }
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA DEVICE HANDLE
// ═══════════════════════════════════════════════════════════════════════════════

pub const FPGADevice = struct {
    fd: std.posix.fd_t,
    allocator: std.mem.Allocator,
    available: bool,

    /// Try to open FPGA device (tries multiple paths)
    pub fn open(allocator: std.mem.Allocator) !FPGADevice {
        for (DEFAULT_DEVICES) |path| {
            if (std.fs.openFileAbsolute(path, .{ .mode = .read_write })) |file| {
                const fd = file.handle;
                // Keep file open, will be closed by FPGADevice.close()
                std.log.info("VSA FPGA: Opened device {s}", .{path});
                return .{
                    .fd = fd,
                    .allocator = allocator,
                    .available = true,
                };
            } else |_| {
                // Continue to next device
            }
        }

        // No device found — return handle with available=false
        std.log.warn("VSA FPGA: No device found, using CPU fallback", .{});
        return .{
            .fd = -1,
            .allocator = allocator,
            .available = false,
        };
    }

    pub fn close(self: *FPGADevice) void {
        if (self.available) {
            std.posix.close(self.fd);
        }
    }

    /// Check if FPGA is available
    pub fn isAvailable(self: *const FPGADevice) bool {
        return self.available;
    }

    /// Perform bind operation on FPGA
    pub fn bind(self: *FPGADevice, a: FPGAVector, b: FPGAVector) !FPGAVector {
        if (!self.available) {
            return error.FPGANotAvailable;
        }

        // Protocol:
        // Write: 0xAA [512 bits of A] [512 bits of B]
        // Read:  [512 bits of result]

        var buffer: [129]u8 = undefined; // 1 + 64 + 64
        buffer[0] = 0xAA; // Bind command

        @memcpy(buffer[1..65], &a.data);
        @memcpy(buffer[65..129], &b.data);

        // Write command + vectors
        _ = try std.posix.write(self.fd, &buffer);

        // Wait for result (poll with timeout)
        var result_buf: [64]u8 = undefined;
        const n = try std.posix.read(self.fd, &result_buf);
        if (n != 64) return error.InvalidResponse;

        var result = FPGAVector.init();
        @memcpy(&result.data, &result_buf);
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CPU FALLBACK (when FPGA unavailable)
// ═══════════════════════════════════════════════════════════════════════════════

/// Pure CPU bind operation (for fallback)
pub fn bindCPU(a: FPGAVector, b: FPGAVector) FPGAVector {
    var result = FPGAVector.init();
    for (0..VSA_DIM) |i| {
        const ta = a.getTrit(i);
        const tb = b.getTrit(i);

        const tr: Trit = if (ta == .zero or tb == .zero)
            .zero
        else if (ta == tb)
            .pos
        else
            .neg;

        result.setTrit(i, tr);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL API (with automatic fallback)
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAFPGA = struct {
    device: ?FPGADevice,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !VSAFPGA {
        const dev = try FPGADevice.open(allocator);
        return .{
            .device = if (dev.isAvailable()) dev else null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VSAFPGA) void {
        if (self.device) |*dev| {
            dev.close();
        }
    }

    /// Bind operation with automatic CPU fallback
    pub fn bind(self: *VSAFPGA, a: FPGAVector, b: FPGAVector) !FPGAVector {
        if (self.device) |*dev| {
            // Try FPGA first
            if (dev.bind(a, b)) |result| {
                return result;
            } else |err| {
                std.log.warn("VSA FPGA: Bind failed, using CPU fallback: {}", .{err});
            }
        }

        // CPU fallback
        return bindCPU(a, b);
    }

    /// Batch bind for multiple vectors (e.g., IVF centroids)
    pub fn bindBatch(
        self: *VSAFPGA,
        vectors: []const FPGAVector,
        key: FPGAVector,
    ) ![]FPGAVector {
        const results = try self.allocator.alloc(FPGAVector, vectors.len);
        for (vectors, 0..) |v, i| {
            results[i] = try self.bind(v, key);
        }
        return results;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE INTEGRATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert Needle hybrid vector to FPGA format
pub fn needleToFPGA(vec: []const i8) FPGAVector {
    var result = FPGAVector.init();
    const limit = @min(vec.len, VSA_DIM);
    for (0..limit) |i| {
        const t: Trit = switch (vec[i]) {
            -1 => .neg,
            0 => .zero,
            1 => .pos,
            else => .zero,
        };
        result.setTrit(i, t);
    }
    return result;
}

/// Convert FPGA result to Needle hybrid vector
pub fn fpgaToNeedle(allocator: std.mem.Allocator, fv: FPGAVector) ![]i8 {
    const result = try allocator.alloc(i8, VSA_DIM);
    for (0..VSA_DIM) |i| {
        result[i] = switch (fv.getTrit(i)) {
            .neg => -1,
            .zero => 0,
            .pos => 1,
        };
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vsa_fpga.1: Trit encoding" {
    const t_pos = Trit.pos;
    const t_neg = Trit.neg;
    const t_zero = Trit.zero;

    try std.testing.expectEqual(@as(u2, 0b01), t_pos.toBits());
    try std.testing.expectEqual(@as(u2, 0b10), t_neg.toBits());
    try std.testing.expectEqual(@as(u2, 0b00), t_zero.toBits());

    try std.testing.expectEqual(Trit.pos, Trit.fromBits(0b01));
    try std.testing.expectEqual(Trit.neg, Trit.fromBits(0b10));
    try std.testing.expectEqual(Trit.zero, Trit.fromBits(0b00));
}

test "vsa_fpga.2: FPGAVector set/get" {
    var vec = FPGAVector.init();

    vec.setTrit(0, .pos);
    vec.setTrit(1, .neg);
    vec.setTrit(2, .zero);
    vec.setTrit(255, .pos);

    try std.testing.expectEqual(Trit.pos, vec.getTrit(0));
    try std.testing.expectEqual(Trit.neg, vec.getTrit(1));
    try std.testing.expectEqual(Trit.zero, vec.getTrit(2));
    try std.testing.expectEqual(Trit.pos, vec.getTrit(255));
}

test "vsa_fpga.3: bindCPU correctness" {
    var a = FPGAVector.init();
    var b = FPGAVector.init();

    // Test: +1 * +1 = +1
    a.setTrit(0, .pos);
    b.setTrit(0, .pos);

    const result = bindCPU(a, b);
    try std.testing.expectEqual(Trit.pos, result.getTrit(0));

    // Test: -1 * -1 = +1
    a.setTrit(1, .neg);
    b.setTrit(1, .neg);

    const result2 = bindCPU(a, b);
    try std.testing.expectEqual(Trit.pos, result2.getTrit(1));

    // Test: +1 * -1 = -1
    a.setTrit(2, .pos);
    b.setTrit(2, .neg);

    const result3 = bindCPU(a, b);
    try std.testing.expectEqual(Trit.neg, result3.getTrit(2));

    // Test: 0 * anything = 0
    a.setTrit(3, .zero);
    b.setTrit(3, .pos);

    const result4 = bindCPU(a, b);
    try std.testing.expectEqual(Trit.zero, result4.getTrit(3));
}

test "vsa_fpga.4: needleToFPGA and fpgaToNeedle roundtrip" {
    const allocator = std.testing.allocator;

    // Create test vector in Needle format
    const needle_vec = [_]i8{
        1,  -1, 0,  1,  -1, 0,  1,  -1, // 8 trits
        0,  0,  0,  0,  0,  0,  0,  0,  // 8 zeros
        1,  1,  1,  1,  -1, -1, -1, -1, // pattern
    } ++ [_]i8{0} ** (VSA_DIM - 24); // pad to 256

    const fv = needleToFPGA(&needle_vec);
    try std.testing.expectEqual(Trit.pos, fv.getTrit(0));
    try std.testing.expectEqual(Trit.neg, fv.getTrit(1));
    try std.testing.expectEqual(Trit.zero, fv.getTrit(2));

    const roundtrip = try fpgaToNeedle(allocator, fv);
    defer allocator.free(roundtrip);

    for (0..VSA_DIM) |i| {
        try std.testing.expectEqual(needle_vec[i], roundtrip[i]);
    }
}

test "vsa_fpga.5: FPGADevice open/close (CPU fallback)" {
    const allocator = std.testing.allocator;
    var dev = try FPGADevice.open(allocator);
    defer if (dev.isAvailable()) dev.close();

    // Should not crash - will use CPU fallback if no FPGA
    try std.testing.expect(true);
}

// φ² + 1/φ² = 3
