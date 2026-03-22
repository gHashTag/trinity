// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 MEMORY — 3^9 = 19683 Word Address Space
//
// Memory model:
// - Word-aligned: 32-bit words (holds 2 Trit27 or instruction)
// - Addressable: byte-addressed with 4-byte word alignment
// - Size: 3^9 = 19683 words = 78732 bytes
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Trit27 = @import("tri_cpu.zig").Trit27;

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY CONFIGURATION
// ═════════════════════════════════════════════════════════════════════════════════════════
pub const MEMORY_SIZE_WORDS = 19683;  // 3^9 words
pub const MEMORY_SIZE_BYTES = MEMORY_SIZE_WORDS * 4;  // 78732 bytes
pub const WORD_SIZE = @sizeOf(u32);

// Memory protection boundaries
pub const STACK_START = MEMORY_SIZE_WORDS - 512;  // Stack at end
pub const STACK_SIZE_WORDS = 512;

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY ERROR — Memory operation failures
// ═════════════════════════════════════════════════════════════════════════════════════════
pub const MemError = error{
    AddressOutOfBounds,
    UnalignedAccess,
    InvalidWrite,
};

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY — TRI-27 Memory Interface
// ═════════════════════════════════════════════════════════════════════════════════════════
pub const Memory = struct {
    data: []u8,

    /// Create memory with default size
    pub fn init(allocator: std.mem.Allocator) !Memory {
        const data = try allocator.alloc(u8, MEMORY_SIZE_BYTES);
        @memset(data.ptr, 0, MEMORY_SIZE_BYTES);
        return .{ .data = data };
    }

    /// Create memory with custom size (for testing)
    pub fn initCustom(allocator: std.mem.Allocator, size_words: usize) !Memory {
        const data = try allocator.alloc(u8, size_words * WORD_SIZE);
        @memset(data.ptr, 0, size_words * WORD_SIZE);
        return .{ .data = data };
    }

    /// Read 32-bit word at word address
    pub fn readWord(self: *const Memory, word_addr: u32) MemError!u32 {
        if (word_addr >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const byte_addr = word_addr * WORD_SIZE;
        const ptr = self.data[byte_addr..];

        // Little-endian read
        var result: u32 = 0;
        for (0..WORD_SIZE) |i| {
            result |= @as(u32, ptr[i]) << (i * 8);
        }

        return result;
    }

    /// Write 32-bit word at word address
    pub fn writeWord(self: *Memory, word_addr: u32, value: u32) MemError!void {
        if (word_addr >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const byte_addr = word_addr * WORD_SIZE;
        const ptr = self.data[byte_addr..];

        // Little-endian write
        for (0..WORD_SIZE) |i| {
            ptr[i] = @as(u8, (value >> (i * 8)) & 0xFF);
        }
    }

    /// Read byte at byte address
    pub fn readByte(self: *const Memory, byte_addr: u32) MemError!u8 {
        if (byte_addr >= MEMORY_SIZE_BYTES) {
            return MemError.AddressOutOfBounds;
        }
        return self.data[byte_addr];
    }

    /// Write byte at byte address
    pub fn writeByte(self: *Memory, byte_addr: u32, value: u8) MemError!void {
        if (byte_addr >= MEMORY_SIZE_BYTES) {
            return MemError.AddressOutOfBounds;
        }
        self.data[byte_addr] = value;
    }

    /// Read Trit27 value (packed as i64 in 2 words)
    pub fn readTrit27(self: *const Memory, word_addr: u32) MemError!Trit27 {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const lo = try self.readWord(word_addr);
        const hi = try self.readWord(word_addr + 1);

        // Pack into i64 (54 bits used)
        const packed: i64 = @as(i64, lo) | (@as(i64, hi) << 32);
        return .{ .trits = packed };
    }

    /// Write Trit27 value (packed as i64 in 2 words)
    pub fn writeTrit27(self: *Memory, word_addr: u32, value: Trit27) MemError!void {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const packed = value.trits;
        const lo = @as(u32, @truncate(packed));
        const hi = @as(u32, @truncate(packed >> 32));

        try self.writeWord(word_addr, lo);
        try self.writeWord(word_addr + 1, hi);
    }

    /// Zero-fill memory region
    pub fn zeroFill(self: *Memory, word_addr: u32, size_words: u32) MemError!void {
        if (word_addr + size_words > MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const byte_addr = word_addr * WORD_SIZE;
        @memset(self.data[byte_addr..].ptr, 0, size_words * WORD_SIZE);
    }

    /// Get memory statistics
    pub fn stats(self: *const Memory) struct {
        used_words: usize,
        free_words: usize,
        stack_ptr: u32,
    } {
        // Calculate used based on highest non-zero word
        var max_used: usize = 0;
        for (0..MEMORY_SIZE_WORDS) |i| {
            if (self.readWord(@as(u32, i)) catch |e| {
                std.debug.panic("Memory read failed during stats: {}", .{e});
            } != 0) {
                max_used = i + 1;
            }
        }

        return .{
            .used_words = max_used,
            .free_words = MEMORY_SIZE_WORDS - max_used,
            .stack_ptr = 0,  // Placeholder - managed by CPU
        };
    }

    /// Deallocate memory
    pub fn deinit(self: *Memory, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════
test "Memory init zeros all bytes" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    // Check first and last bytes are zero
    try std.testing.expectEqual(@as(u8, 0), mem.data[0]);
    try std.testing.expectEqual(@as(u8, 0), mem.data[MEMORY_SIZE_BYTES - 1]);
}

test "Memory readWord writeWord roundtrip" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    const test_val: u32 = 0xDEADBEEF;
    try mem.writeWord(100, test_val);
    const read_val = try mem.readWord(100);

    try std.testing.expectEqual(test_val, read_val);
}

test "Memory readByte writeByte roundtrip" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    const test_val: u8 = 0xAB;
    try mem.writeByte(37, test_val);
    const read_val = try mem.readByte(37);

    try std.testing.expectEqual(test_val, read_val);
}

test "Memory out of bounds readWord" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    const result = mem.readWord(MEMORY_SIZE_WORDS);

    try std.testing.expectError(MemError.AddressOutOfBounds, result);
}

test "Memory out of bounds writeWord" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    const result = mem.writeWord(MEMORY_SIZE_WORDS, 0x12345678);

    try std.testing.expectError(MemError.AddressOutOfBounds, result);
}

test "Memory readTrit27 writeTrit27 roundtrip" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    const trit_val = Trit27.fromI8(1);
    try mem.writeTrit27(50, trit_val);
    const read_trit = try mem.readTrit27(50);

    try std.testing.expectEqual(trit_val.trits, read_trit.trits);
}

test "Memory zeroFill" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    // Write some values
    try mem.writeWord(0, 0xFFFFFFFF);
    try mem.writeWord(10, 0x12345678);
    try mem.writeWord(20, 0xDEADBEEF);

    // Zero-fill region
    try mem.zeroFill(10, 5);

    // Check region is zeroed
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), try mem.readWord(0));
    try std.testing.expectEqual(@as(u32, 0), try mem.readWord(10));
    try std.testing.expectEqual(@as(u32, 0), try mem.readWord(11));
    try std.testing.expectEqual(@as(u32, 0), try mem.readWord(12));
    try std.testing.expectEqual(@as(u32, 0), try mem.readWord(13));
    try std.testing.expectEqual(@as(u32, 0), try mem.readWord(14));
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try mem.readWord(20));  // Outside fill region
}

test "Memory initCustom for testing" {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    try mem.writeWord(99, 0xCAFEBABE);
    const read_val = try mem.readWord(99);

    try std.testing.expectEqual(@as(u32, 0xCAFEBABE), read_val);
}

test "Memory stats" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    // Write at addresses 0, 10, 100
    try mem.writeWord(0, 0x11111111);
    try mem.writeWord(10, 0x22222222);
    try mem.writeWord(100, 0x33333333);

    const stats = mem.stats();

    try std.testing.expectEqual(@as(usize, 101), stats.used_words);  // 100 + 1
    try std.testing.expectEqual(@as(usize, MEMORY_SIZE_WORDS - 101), stats.free_words);
}

test "Memory endianness littleEndian" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit(allocator);

    // Write 0x11223344
    try mem.writeWord(0, 0x11223344);

    // Read bytes and verify little-endian
    try std.testing.expectEqual(@as(u8, 0x44), try mem.readByte(0));
    try std.testing.expectEqual(@as(u8, 0x33), try mem.readByte(1));
    try std.testing.expectEqual(@as(u8, 0x22), try mem.readByte(2));
    try std.testing.expectEqual(@as(u8, 0x11), try mem.readByte(3));
}
