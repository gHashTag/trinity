// ═══════════════════════════════════════════════════════════════════════
// TRI-27 CPU STATE — Ternary RISC Processor State
// ═══════════════════════════════════════════════════════════════════════════
// 27 Trit Registers + 3 Float Registers + PC + SP + FP + Flags
// Pure functional, no OOP — aligns with Tri language specification
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
// Trit type: {-1, 0, +1} — stored as i8 for efficiency
pub const Trit = i8;

/// CPU Flags Register
pub const CPUFlags = packed struct {
    zero: bool = false,
    negative: bool = false,
    positive: bool = false,
    _padding: u5 = 0,

    /// Set flags from comparison result
    pub fn fromCmp(a: i64, b: i64) CPUFlags {
        return .{
            .zero = a == b,
            .negative = a < b,
            .positive = a > b,
            ._padding = 0,
        };
    }

    /// Check if any flag is set
    pub fn anySet(self: CPUFlags) bool {
        return self.zero or self.negative or self.positive;
    }

    /// Clear all flags
    pub fn clear(self: *CPUFlags) void {
        self.* = .{};
    }
};

/// Call stack frame (for CALL/RET)
pub const CallFrame = struct {
    return_addr: u32 = 0,
};

/// Maximum call stack depth
pub const CALL_STACK_MAX: usize = 4096;

/// TRI-27 CPU State
/// 27 trinary registers (t0-t26) + 3 float registers (f0-f2)
pub const CPUState = struct {
    // === TRINARY REGISTERS (t0-t26) ===
    // Stores ternary values {-1, 0, +1}
    trits: [27]Trit,

    // === FLOAT REGISTERS (f0-f2) ===
    // Stores IEEE 754 16-bit floats for sacred math operations
    floats: [3]f64,

    // === CONTROL REGISTERS ===
    pc: u32, // Program counter
    sp: u32, // Stack pointer
    fp: u32, // Frame pointer (for calls)
    flags: CPUFlags, // Condition flags
    call_stack: [CALL_STACK_MAX]CallFrame, // Call stack

    // === MEMORY ===
    /// Direct memory access (byte-addressable)
    /// In real TRI-27, this maps to TMU/Sacred ALU memory
    memory: []u8,
    memory_len: usize,

    // === METRICS ===
    instructions_executed: u64,
    start_time: i128,
    end_time: i128,

    const Self = @This();

    /// Initialize CPU state
    pub fn init(allocator: std.mem.Allocator, memory_size: usize) !Self {
        const memory = try allocator.alloc(u8, memory_size);
        errdefer allocator.free(memory);

        return Self{
            .trits = [_]Trit{0} ** 27,
            .floats = [_]f64{0.0} ** 3,
            .pc = 0,
            .sp = 0,
            .fp = 0,
            .flags = CPUFlags{},
            .call_stack = [_]CallFrame{ .return_addr = 0 } ** CALL_STACK_MAX,
            .memory = memory,
            .memory_len = memory_size,
            .instructions_executed = 0,
            .start_time = 0,
            .end_time = 0,
        };
    }

    /// Deinitialize CPU state
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.memory.len > 0) {
            allocator.free(self.memory);
        }
    }

    /// Reset execution state (keeps memory, resets pc/sp/fp/flags)
    pub fn resetExecution(self: *Self) void {
        self.pc = 0;
        self.sp = 0;
        self.fp = 0;
        self.flags.clear();
        self.instructions_executed = 0;
        self.start_time = 0;
        self.end_time = 0;
    }

    /// Get execution time in nanoseconds
    pub fn getExecutionTimeNs(self: *const Self) u64 {
        return @intCast(@max(0, self.end_time - self.start_time));
    }

    /// Get instructions per second
    pub fn getIPS(self: *const Self) f64 {
        const time_ns = self.getExecutionTimeNs();
        if (time_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.instructions_executed)) / (@as(f64, @floatFromInt(time_ns)) / 1_000_000_000.0);
    }

    /// Get execution time in milliseconds
    pub fn getExecutionTimeMs(self: *const Self) u64 {
        return self.getExecutionTimeNs() / 1_000_000;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "CPUState init" {
    var cpu = try CPUState.init(std.testing.allocator, 4096);
    defer cpu.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 27), cpu.trits.len);
    try std.testing.expectEqual(@as(usize, 3), cpu.floats.len);
    try std.testing.expectEqual(@as(u32, 0), cpu.pc);
    try std.testing.expectEqual(@as(u32, 0), cpu.sp);
    try std.testing.expectEqual(@as(u32, 0), cpu.fp);
    try std.testing.expect(!cpu.flags.anySet());

    try std.testing.expectEqual(@as(usize, 4096), cpu.memory.len);
    try std.testing.expectEqual(@as(usize, 0), cpu.instructions_executed);
}

test "CPUState resetExecution" {
    var cpu = try CPUState.init(std.testing.allocator, 4096);
    defer cpu.deinit(std.testing.allocator);

    // Set some state
    cpu.pc = 100;
    cpu.sp = 50;
    cpu.fp = 25;
    cpu.trits[5] = 1;
    cpu.trits[10] = -1;
    cpu.flags = CPUFlags.fromCmp(5, 10);

    // Reset
    cpu.resetExecution();

    try std.testing.expectEqual(@as(u32, 0), cpu.pc);
    try std.testing.expectEqual(@as(u32, 0), cpu.sp);
    try std.testing.expectEqual(@as(u32, 0), cpu.fp);
    try std.testing.expect(!cpu.flags.anySet());

    try std.testing.expectEqual(@as(usize, 0), cpu.instructions_executed);
}

test "CPUState metrics" {
    var cpu = try CPUState.init(std.testing.allocator, 4096);
    defer cpu.deinit(std.testing.allocator);

    cpu.start_time = std.time.nanoTimestamp();

    // Simulate execution
    cpu.pc = 100;
    cpu.instructions_executed = 100;

    cpu.end_time = std.time.nanoTimestamp();

    const time_ns = cpu.getExecutionTimeNs();
    const ips = cpu.getIPS();

    try std.testing.expect(time_ns > 0);
    try std.testing.expectEqual(@as(usize, 100), cpu.instructions_executed);
    try std.testing.expect(ips > 0);
}
