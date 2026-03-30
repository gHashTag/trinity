// ═════════════════════════════════════════════════════════════════════════════
// VM MEMORY - Common Memory Operations
// ═════════════════════════════════════════════════════════════════════════════
// Shared memory operations for all Trinity VMs
// Reduces duplication between stack and register-based implementations
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Memory error types
pub const MemoryError = error{
    InvalidAddress,
    StackOverflow,
    StackUnderflow,
    OutOfBounds,
};

/// Generic VM Memory interface
/// Works with both stack-based and register-based VMs
pub const VMMemory = struct {
    /// Byte array backing store
    memory: []u8 = &.{},

    /// Current memory size
    size: usize = 0,

    const Self = @This();

    /// Initialize memory with given size
    pub fn init(allocator: Allocator, size: usize) !Self {
        const mem = try allocator.alloc(u8, size);
        return Self{
            .memory = mem,
            .size = size,
        };
    }

    /// Deallocate memory
    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.memory);
        self.* = .{};
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // BASIC LOAD/STORE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════════════════════════

    /// Load byte from memory at address
    pub inline fn loadU8(self: *const Self, address: usize) !u8 {
        if (address >= self.size) return MemoryError.InvalidAddress;
        return self.memory[address];
    }

    /// Store byte to memory at address
    pub inline fn storeU8(self: *Self, address: usize, value: u8) !void {
        if (address >= self.size) return MemoryError.InvalidAddress;
        self.memory[address] = value;
    }

    /// Load 16-bit value from memory (little-endian)
    pub inline fn loadU16(self: *const Self, address: usize) !u16 {
        if (address + 1 >= self.size) return MemoryError.InvalidAddress;
        const lo = self.memory[address];
        const hi = self.memory[address + 1];
        return (@as(u16, hi) << 8) | @as(u16, lo);
    }

    /// Store 16-bit value to memory (little-endian)
    pub inline fn storeU16(self: *Self, address: usize, value: u16) !void {
        if (address + 1 >= self.size) return MemoryError.InvalidAddress;
        self.memory[address] = @truncate(value);
        self.memory[address + 1] = @truncate(value >> 8);
    }

    /// Load 32-bit value from memory (little-endian)
    pub inline fn loadU32(self: *const Self, address: usize) !u32 {
        if (address + 3 >= self.size) return MemoryError.InvalidAddress;
        const b0 = self.memory[address];
        const b1 = self.memory[address + 1];
        const b2 = self.memory[address + 2];
        const b3 = self.memory[address + 3];
        return (@as(u32, b3) << 24) |
            (@as(u32, b2) << 16) |
            (@as(u32, b1) << 8) |
            @as(u32, b0);
    }

    /// Store 32-bit value to memory (little-endian)
    pub inline fn storeU32(self: *Self, address: usize, value: u32) !void {
        if (address + 3 >= self.size) return MemoryError.InvalidAddress;
        self.memory[address] = @truncate(value);
        self.memory[address + 1] = @truncate(value >> 8);
        self.memory[address + 2] = @truncate(value >> 16);
        self.memory[address + 3] = @truncate(value >> 24);
    }

    /// Load signed 64-bit value from memory (little-endian)
    pub inline fn loadI64(self: *const Self, address: usize) !i64 {
        if (address + 7 >= self.size) return MemoryError.InvalidAddress;
        var result: i64 = 0;
        inline for (0..8) |i| {
            result |= @as(i64, self.memory[address + i]) << (i * 8);
        }
        return result;
    }

    /// Store 64-bit value to memory (little-endian)
    pub inline fn storeI64(self: *Self, address: usize, value: i64) !void {
        if (address + 7 >= self.size) return MemoryError.InvalidAddress;
        inline for (0..8) |i| {
            self.memory[address + i] = @truncate(@as(u64, @bitCast(value >> @as(i32, i * 8))));
        }
    }

    /// Load f64 from memory (little-endian)
    pub inline fn loadF64(self: *const Self, address: usize) !f64 {
        if (address + 7 >= self.size) return MemoryError.InvalidAddress;
        const bits = try self.loadU64(address);
        return @bitCast(bits);
    }

    /// Store f64 to memory (little-endian)
    pub inline fn storeF64(self: *Self, address: usize, value: f64) !void {
        if (address + 7 >= self.size) return MemoryError.InvalidAddress;
        const bits: u64 = @bitCast(value);
        try self.storeU64(address, bits);
    }

    /// Load unsigned 64-bit from memory
    pub inline fn loadU64(self: *const Self, address: usize) !u64 {
        if (address + 7 >= self.size) return MemoryError.InvalidAddress;
        var result: u64 = 0;
        inline for (0..8) |i| {
            result |= @as(u64, self.memory[address + i]) << (i * 8);
        }
        return result;
    }

    /// Store unsigned 64-bit to memory
    pub inline fn storeU64(self: *Self, address: usize, value: u64) !void {
        if (address + 7 >= self.size) return MemoryError.InvalidAddress;
        inline for (0..8) |i| {
            self.memory[address + i] = @truncate(value >> (i * 8));
        }
    }

    // ═════════════════════════════════════════════════════════════════════════════════════════
    // STACK OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════════════════════

    /// Generic stack push (caller manages stack storage)
    /// StackT should be an array type like [N]T
    pub inline fn pushStack(comptime StackT: type, stack: *StackT, sp: *usize, value: std.meta.Elem(StackT)) !void {
        if (sp.* >= stack.len) return MemoryError.StackOverflow;
        stack[sp.*] = value;
        sp.* += 1;
    }

    /// Generic stack pop (caller manages stack storage)
    /// StackT should be an array type like [N]T
    pub inline fn popStack(comptime StackT: type, stack: *StackT, sp: *usize) !std.meta.Elem(StackT) {
        if (sp.* == 0) return MemoryError.StackUnderflow;
        sp.* -= 1;
        return stack[sp.*];
    }

    /// Generic stack peek (caller manages stack storage)
    /// StackT should be an array type like [N]T
    pub inline fn peekStack(comptime StackT: type, stack: *StackT, sp: *const usize) !std.meta.Elem(StackT) {
        if (sp.* == 0) return MemoryError.StackUnderflow;
        return stack[sp.* - 1];
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════════
    // ADDRESS HELPERS
    // ═════════════════════════════════════════════════════════════════════════════════════════════════════

    /// Calculate aligned address
    pub inline fn alignDown(address: usize, alignment: usize) usize {
        return address & ~(alignment - 1);
    }

    /// Calculate aligned address (round up)
    pub inline fn alignUp(address: usize, alignment: usize) usize {
        return (address + alignment - 1) & ~(alignment - 1);
    }

    /// Check if address is aligned
    pub inline fn isAligned(address: usize, alignment: usize) bool {
        return (address & (alignment - 1)) == 0;
    }

    /// Safe address calculation with bounds checking
    pub inline fn calculateAddress(base: usize, offset: isize, size: usize, max_size: usize) !usize {
        // Handle negative offset
        var result: usize = undefined;
        if (offset < 0) {
            if (@as(isize, base) < -offset) {
                result = 0;
            } else {
                result = base - @as(usize, @bitCast(-offset));
            }
        } else {
            result = base + @as(usize, @bitCast(offset));
        }

        // Check bounds
        if (result + size > max_size) return MemoryError.InvalidAddress;
        return result;
    }

    /// Copy memory region
    pub fn copyMemory(self: *Self, dst: usize, src: usize, count: usize) !void {
        if (dst + count > self.size) return MemoryError.InvalidAddress;
        if (src + count > self.size) return MemoryError.InvalidAddress;
        @memcpy(self.memory[dst..][0..count], self.memory[src..][0..count]);
    }

    /// Fill memory with value
    pub fn fillMemory(self: *Self, dst: usize, value: u8, count: usize) !void {
        if (dst + count > self.size) return MemoryError.InvalidAddress;
        @memset(self.memory[dst..][0..count], value);
    }

    /// Zero out memory region
    pub fn zeroMemory(self: *Self, dst: usize, count: usize) !void {
        if (dst + count > self.size) return MemoryError.InvalidAddress;
        @memset(self.memory[dst..][0..count], 0);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "VMMemory init" {
    var mem = try VMMemory.init(std.testing.allocator, 1024);
    defer mem.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1024), mem.size);
}

test "VMMemory loadU8 storeU8" {
    var mem = try VMMemory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    try mem.storeU8(5, 0x42);
    const val = try mem.loadU8(5);
    try std.testing.expectEqual(@as(u8, 0x42), val);
}

test "VMMemory loadU16 storeU16" {
    var mem = try VMMemory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    try mem.storeU16(0, 0x1234);
    const val = try mem.loadU16(0);
    try std.testing.expectEqual(@as(u16, 0x1234), val);
}

test "VMMemory loadU32 storeU32" {
    var mem = try VMMemory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    try mem.storeU32(0, 0x12345678);
    const val = try mem.loadU32(0);
    try std.testing.expectEqual(@as(u32, 0x12345678), val);
}

test "VMMemory loadI64 storeI64" {
    var mem = try VMMemory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    try mem.storeI64(0, -12345678901234);
    const val = try mem.loadI64(0);
    try std.testing.expectEqual(@as(i64, -12345678901234), val);
}

test "VMMemory loadF64 storeF64" {
    var mem = try VMMemory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    try mem.storeF64(0, 3.14159265358979323846);
    const val = try mem.loadF64(0);
    try std.testing.expectApproxEqAbs(3.14159265358979323846, val, 1e-15);
}

test "VMMemory pushStack popStack" {
    const StackSize = 16;
    var stack: [StackSize]u32 = undefined;

    var sp: usize = 0;

    try VMMemory.pushStack([StackSize]u32, &stack, &sp, @as(u32, 42));
    try VMMemory.pushStack([StackSize]u32, &stack, &sp, @as(u32, 100));

    try std.testing.expectEqual(@as(usize, 2), sp);

    const val = try VMMemory.popStack([StackSize]u32, &stack, &sp);
    try std.testing.expectEqual(@as(u32, 100), val);
    try std.testing.expectEqual(@as(usize, 1), sp);
}

test "VMMemory invalid address" {
    var mem = try VMMemory.init(std.testing.allocator, 16);
    defer mem.deinit(std.testing.allocator);

    _ = mem.loadU8(16) catch |err| {
        try std.testing.expectEqual(MemoryError.InvalidAddress, err);
        return;
    };
    try std.testing.expect(false); // Should not reach here
}

test "VMMemory alignDown alignUp" {
    try std.testing.expectEqual(@as(usize, 0), VMMemory.alignDown(0, 8));
    try std.testing.expectEqual(@as(usize, 8), VMMemory.alignDown(8, 8));
    try std.testing.expectEqual(@as(usize, 8), VMMemory.alignDown(10, 8));
    try std.testing.expectEqual(@as(usize, 8), VMMemory.alignDown(13, 8));

    try std.testing.expectEqual(@as(usize, 0), VMMemory.alignUp(0, 8));
    try std.testing.expectEqual(@as(usize, 8), VMMemory.alignUp(8, 8));
    try std.testing.expectEqual(@as(usize, 16), VMMemory.alignUp(10, 8));
    try std.testing.expectEqual(@as(usize, 16), VMMemory.alignUp(13, 8));
}

test "VMMemory isAligned" {
    try std.testing.expect(VMMemory.isAligned(0, 8));
    try std.testing.expect(VMMemory.isAligned(8, 8));
    try std.testing.expect(VMMemory.isAligned(16, 8));
    try std.testing.expect(!VMMemory.isAligned(10, 8));
    try std.testing.expect(!VMMemory.isAligned(13, 8));
}

test "VMMemory calculateAddress" {
    const result = try VMMemory.calculateAddress(100, 10, 4, 1024);
    try std.testing.expectEqual(@as(usize, 110), result);

    // Test offset that goes out of bounds
    _ = VMMemory.calculateAddress(1022, 10, 4, 1024) catch |err| {
        try std.testing.expectEqual(MemoryError.InvalidAddress, err);
        return;
    };
    try std.testing.expect(false);
}

test "VMMemory copyMemory" {
    var mem = try VMMemory.init(std.testing.allocator, 256);
    defer mem.deinit(std.testing.allocator);

    // Setup source data
    try mem.storeU32(100, 0x12345678);
    try mem.storeU32(104, 0x9ABCDEF0);

    // Copy to destination
    try mem.copyMemory(0, 100, 8);

    // Verify
    try std.testing.expectEqual(@as(u32, 0x12345678), try mem.loadU32(0));
    try std.testing.expectEqual(@as(u32, 0x9ABCDEF0), try mem.loadU32(4));
}
