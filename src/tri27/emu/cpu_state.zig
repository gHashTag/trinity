// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI-27 CPU STATE — Ternary RISC Processor State
// ═════════════════════════════════════════════════════════════════════════════════════════
// 27 Trit Registers + 3 Float Registers + 8 GF16 + 16 Vector registers + PC + SP + FP + Flags
// Pure functional, no OOP — aligns with Tri language specification
// ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const Memory = @import("tri_memory.zig").Memory;
const Word = @import("tri_memory.zig").Word;

pub const MEMORY_SIZE_WORDS: usize = 19683;

// Trit type from tri_cpu.zig
const Trit27 = @import("tri_cpu.zig").Trit27;

/// CPU Flags Register (compatible with executor.zig)
pub const Flags = packed struct {
    Z: bool = false, // Zero result flag
    N: bool = false, // Negative result flag
    V: bool = false, // Overflow flag
    H: bool = false, // Halted flag
    _: u4 = 0, // Reserved bits
};

/// Call stack frame (for CALL/RET)
pub const CallFrame = struct {
    return_addr: u32 = 0,
};

pub const DEFAULT_CALL_FRAME: CallFrame = .{ .return_addr = 0 };

/// Maximum call stack depth
pub const CALL_STACK_MAX: usize = 4096;

/// MemoryView adapter for byte access on Word-based memory
/// Provides []const u8 interface on top of []Word storage
pub const MemoryView = struct {
    memory: []const Word,
    memory_len: usize,

    /// Create memory view from Word array
    pub fn init(mem: []const Word, mem_len: usize) MemoryView {
        return .{
            .memory = mem,
            .memory_len = mem_len,
        };
    }

    /// Read byte at address (little-endian from u64 word_value)
    pub fn readByte(self: *const MemoryView, addr: usize) u8 {
        const word_idx = addr / 8;
        const byte_idx = addr % 8;
        if (word_idx >= self.memory.len) return 0;
        const word_value = self.memory[word_idx].word_value;
        const shifted = word_value >> @as(u6, byte_idx * 8);
        return @as(u8, shifted & 0xFF);
    }

    /// Write byte at address (little-endian into u64 word_value)
    pub fn writeByte(self: *MemoryView, addr: usize, value: u8) void {
        const word_idx = addr / 8;
        const byte_idx = addr % 8;
        if (word_idx >= self.memory.len) return;
        const mask = @as(u64, 0xFF) << @as(u6, byte_idx * 8);
        const shifted = @as(u64, value) << @as(u6, byte_idx * 8);
        const word_ptr: *Word = @ptrCast(&self.memory[word_idx]);
        const mut_ptr = @constCast(word_ptr);
        mut_ptr.word_value = (mut_ptr.word_value & ~mask) | shifted;
    }

    /// Get byte slice length (total bytes in memory)
    pub fn getByteLen(self: *const MemoryView) usize {
        return self.memory.len * 8;
    }

    /// Check if address is in bounds
    pub fn inBounds(self: *const MemoryView, addr: usize) bool {
        return addr < self.memory.len * 8;
    }
};

/// TRI-27 CPU State
/// Unified interface compatible with executor.zig and tri_emu_main.zig
pub const CPUState = struct {
    // === TRINARY REGISTERS (t0-t26, executor.zig: t27) ===
    // Stores ternary values {-1, 0, +1} as Trit27
    t27: [27]Trit27,

    // === GF16 REGISTERS (f0-f7, executor.zig: f) ===
    // Stores 16-bit GF16 values for floating-point
    f: [8]u16,

    // === VECTOR REGISTERS (v0-v15, executor.zig: v) ===
    // 16 vector registers, each is 16×GF16
    v: [16][16]u16,

    // === CONTROL REGISTERS ===
    pc: u32, // Program counter (executor.zig: ip)
    sp: u32, // Stack pointer
    fp: u32, // Frame pointer (for calls)
    flags: Flags, // Condition flags (Z/N/V/H)

    // === MEMORY ===
    /// Direct memory access (byte-addressable)
    /// In real TRI-27, this maps to TMU/Sacred ALU memory
    memory: []Word, // Direct reference to Word array
    memory_len: usize,

    // === METRICS ===
    instructions_executed: u64,
    cycles: u64,

    // === ALLOCATOR ===
    /// For dynamic operations (compatible with executor.zig)
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize CPU state
    pub fn init(allocator: std.mem.Allocator) !Self {
        const memory = try allocator.alloc(Word, MEMORY_SIZE_WORDS);
        errdefer allocator.free(memory);

        // Zero initialize all words
        for (0..MEMORY_SIZE_WORDS) |i| {
            memory[i] = Word{ .word_value = 0 };
        }

        return Self{
            .t27 = undefined,
            .f = [_]u16{0} ** 8,
            .v = undefined, // Zero initialize array
            .pc = 3, // Skip 10-byte header (aligns to byte 12, first instruction)
            .sp = 0,
            .fp = 0,
            .flags = Flags{},
            .memory = memory,
            .memory_len = MEMORY_SIZE_WORDS,
            .instructions_executed = 0,
            .cycles = 0,
            .allocator = allocator,
        };
    }

    /// Deinitialize CPU state
    pub fn deinit(self: *Self) void {
        if (self.memory.len > 0) {
            self.allocator.free(self.memory);
        }
    }

    /// Reset execution state (keeps memory, resets pc/sp/fp/flags)
    pub fn resetExecution(self: *Self) void {
        self.pc = 3; // Skip 10-byte header (aligns to byte 12, first instruction)
        self.sp = 0;
        self.fp = 0;
        self.flags = Flags{};
        self.instructions_executed = 0;
        self.cycles = 0;
    }

    /// Get memory as byte view (for executor compatibility)
    pub fn getBytes(self: *const Self) []align(8) const u8 {
        return std.mem.sliceAsBytes(self.memory);
    }

    /// Get mutable memory as byte slice (for executor writes)
    pub fn getBytesMut(self: *Self) []align(8) u8 {
        return std.mem.sliceAsBytes(self.memory);
    }

    /// Get memory view as MemoryView for direct byte access
    pub fn getMemoryView(self: *const Self) MemoryView {
        return MemoryView.init(self.memory, self.memory_len);
    }
};
