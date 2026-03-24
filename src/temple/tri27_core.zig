// TTT — Trusted Tri Temple — L0 Sacred Layer
// DO NOT MODIFY without TEMPLE_RITUAL
// Re-exports from: src/tri27/emu/*.zig, src/vm/opcodes.zig
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 TRIT27 TYPE (re-export from src/tri27/emu/tri_cpu.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const Trit27 = struct {
    trits: i64,

    pub fn fromI8(value: i8) Trit27 {
        const clamped = std.math.clamp(@as(i32, value), @as(i32, -1), @as(i32, 1));
        return .{ .trits = @as(i64, clamped) };
    }

    pub fn toI8Clamped(self: Trit27) i8 {
        if (self.trits == 0) return 0;
        if (self.trits < 0) return -1;
        return 1;
    }

    pub fn add(self: Trit27, other: Trit27) Trit27 {
        const sum = self.trits + other.trits;
        const half_carry = sum >> 54;
        const base: i64 = 19683; // 3^27
        const result = @rem(sum, base) + half_carry;
        return .{ .trits = result };
    }

    pub fn sub(self: Trit27, other: Trit27) Trit27 {
        return self.add(Trit27{ .trits = -other.trits });
    }

    pub fn cmp(self: Trit27, other: Trit27) struct { lt: bool, eq: bool } {
        if (self.trits == other.trits) {
            return .{ .lt = false, .eq = true };
        }
        return .{ .lt = self.trits < other.trits, .eq = false };
    }
};

pub const ZERO = Trit27{ .trits = 0 };
pub const ONE = Trit27{ .trits = 1 };
pub const MINUS_ONE = Trit27{ .trits = -1 };

// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 MEMORY (re-export from src/tri27/emu/tri_memory.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const MEMORY_SIZE_WORDS: usize = 19683;
pub const MEMORY_SIZE_BYTES: usize = 78732;

pub const Trit27Mem = i54;

pub const MemError = error{
    AddressOutOfBounds,
    WordAlignmentError,
    InvalidTrit27,
};

pub const Word = struct {
    word_value: u64 = 0,
};

pub const Memory = struct {
    allocator: std.mem.Allocator,
    data: []Word,

    pub fn init(allocator: std.mem.Allocator) !Memory {
        const data = try allocator.alloc(Word, MEMORY_SIZE_WORDS);
        errdefer allocator.free(data);

        for (0..MEMORY_SIZE_WORDS) |i| {
            data[i] = Word{ .word_value = 0 };
        }

        return .{
            .allocator = allocator,
            .data = data,
        };
    }

    pub fn deinit(self: *Memory) void {
        self.allocator.free(self.data);
    }

    pub fn readWord(self: *Memory, byte_addr: u32) MemError!u32 {
        const word_addr = byte_addr / 4;

        if (word_addr >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        if (byte_addr % 4 != 0) {
            return MemError.WordAlignmentError;
        }

        return @as(u32, @truncate(self.data[word_addr].word_value));
    }

    pub fn writeWord(self: *Memory, byte_addr: u32, value: u32) MemError!void {
        const word_addr = byte_addr / 4;

        if (word_addr >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        if (byte_addr % 4 != 0) {
            return MemError.WordAlignmentError;
        }

        self.data[word_addr].word_value = value;
    }

    pub fn readTrit27(self: *Memory, word_addr: u32) MemError!Trit27Mem {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const lo = try self.readWord(word_addr * 4);
        const hi = try self.readWord((word_addr + 1) * 4);

        const combined: i64 = @as(i64, lo) | (@as(i64, hi) << 32);
        return @intCast(combined);
    }

    pub fn writeTrit27(self: *Memory, word_addr: u32, value: Trit27Mem) MemError!void {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const lo: u32 = @intCast(@as(i64, value) & 0xFFFFFFFF);
        const hi: u32 = @intCast((@as(i64, value) >> 32) & 0xFFFFFFFF);

        try self.writeWord(word_addr * 4, lo);
        try self.writeWord((word_addr + 1) * 4, hi);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 CPU FLAGS (re-export from src/tri27/emu/tri_exec.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const Flags = packed struct {
    Z: bool = false,
    N: bool = false,
    V: bool = false,
    H: bool = false,
    _: u4 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 OPCODES (simplified from src/vm/opcodes.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u5) {
    NOP = 0x00,
    LD_IMM = 0x01,
    ST = 0x02,
    ADD3 = 0x03,
    SUB3 = 0x04,
    CMP3 = 0x05,
    JMP = 0x06,
    CALL = 0x07,
    RET = 0x08,
    HALT = 0x09,
    SYSCALL = 0x0A,
};

pub const Instruction = struct {
    opcode: Opcode,
    dst: u5,
    src1: u5,
    src2: u5,
    immediate: i32,
    has_imm: bool,
};

// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 EXECUTION (re-export from src/tri27/emu/tri_exec.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const ExecError = error{
    InvalidRegister,
    InvalidMemory,
    DivisionByZero,
    StackOverflow,
    StackUnderflow,
    InvalidOpcode,
    Halted,
};

pub fn estimateCycles(opcode: Opcode) u64 {
    return switch (opcode) {
        .NOP => 1,
        .LD_IMM => 1,
        .ST => 2,
        .ADD3 => 2,
        .SUB3 => 2,
        .CMP3 => 2,
        .JMP => 1,
        .CALL => 3,
        .RET => 3,
        .HALT => 1,
        .SYSCALL => 10,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// TRI-27 LOADER (re-export from src/tri27/emu/tri_loader.zig)
// ═══════════════════════════════════════════════════════════════════════════

pub const LoadError = error{
    InvalidMagic,
    FileTooLarge,
    OutOfBounds,
};

pub const LoadResult = struct {
    entry_point: u32,
    instruction_count: u32,
    code_size: u32,
    data_size: u32,
};

pub fn loadBinary(path: []const u8, mem: *Memory, allocator: std.mem.Allocator) !LoadResult {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > 65536) return LoadError.FileTooLarge;

    const data = try file.readToEndAlloc(allocator, 65536);
    defer allocator.free(data);

    const entry: u32 = std.mem.readInt(u32, data[0..4], .little);

    for (data[4..], 0..) |_, i| {
        const word: u32 = @intCast(i);
        try mem.writeWord(@intCast(i * 4), word);
    }

    return .{
        .entry_point = entry,
        .instruction_count = 0,
        .code_size = @intCast(data.len - 4),
        .data_size = 0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "Trit27 constants" {
    try std.testing.expectEqual(@as(i64, 0), ZERO.trits);
    try std.testing.expectEqual(@as(i64, 1), ONE.trits);
    try std.testing.expectEqual(@as(i64, -1), MINUS_ONE.trits);
}

test "Trit27 fromI8 toI8Clamped" {
    const pos = Trit27.fromI8(1);
    try std.testing.expectEqual(@as(i8, 1), pos.toI8Clamped());

    const neg = Trit27.fromI8(-1);
    try std.testing.expectEqual(@as(i8, -1), neg.toI8Clamped());

    const zero = Trit27.fromI8(0);
    try std.testing.expectEqual(@as(i8, 0), zero.toI8Clamped());
}

test "Trit27 add" {
    const a = Trit27.fromI8(1);
    const b = Trit27.fromI8(0);
    const result = a.add(b);
    try std.testing.expectEqual(@as(i8, 1), result.toI8Clamped());
}

test "Trit27 cmp" {
    const a = Trit27.fromI8(1);
    const b = Trit27.fromI8(0);
    const cmp_result = a.cmp(b);
    try std.testing.expect(!cmp_result.lt);
    try std.testing.expect(!cmp_result.eq);
}

test "Memory init" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit();

    try std.testing.expectEqual(MEMORY_SIZE_WORDS, mem.data.len);
}

test "Memory readWrite word" {
    const allocator = std.testing.allocator;
    var mem = try Memory.init(allocator);
    defer mem.deinit();

    try mem.writeWord(0, 0xDEADBEEF);
    const value = try mem.readWord(0);
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), value);
}

test "estimateCycles" {
    try std.testing.expectEqual(@as(u64, 1), estimateCycles(.NOP));
    try std.testing.expectEqual(@as(u64, 2), estimateCycles(.ADD3));
    try std.testing.expectEqual(@as(u64, 3), estimateCycles(.CALL));
}

test "Opcode values" {
    try std.testing.expectEqual(@as(u5, 0), @intFromEnum(Opcode.NOP));
    try std.testing.expectEqual(@as(u5, 3), @intFromEnum(Opcode.ADD3));
    try std.testing.expectEqual(@as(u5, 9), @intFromEnum(Opcode.HALT));
}
