// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 MEMORY — 3^9 = 19683 Word Address Space
//
// Memory model:
// - Word-aligned: 32-bit words (holds 2 Trit27s or instruction)
// - Addressable: byte-addressed with 4-byte word alignment
// - Size: 3^9 = 19683 words = 78732 bytes
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ══════════════════════════════════════════════════════════════════════════════════════════
pub const MEMORY_SIZE_WORDS: usize = 19683;
pub const MEMORY_SIZE_BYTES: usize = 78732;

// ══════════════════════════════════════════════════════════════════════════════════════════════
pub const Trit27 = i54;

// ══════════════════════════════════════════════════════════════════════════════════════════
pub const MemError = error{
    AddressOutOfBounds,
    WordAlignmentError,
    InvalidTrit27,
};

// ════════════════════════════════════════════════════════════════════════════════════════
/// Memory word structure (32-bit)
pub const Word = struct {
    trits: Trit27,
};

/// Convert 2 words to Trit27 (27 trits)
pub fn wordsToTrit27(word0: u32, word1: u32) Trit27 {
    const combined: i64 = @as(i64, word0) | (@as(i64, word1) << 32);
    return @truncate(combined);
}

/// Convert Trit27 to 2 words
pub fn trit27ToWords(value: Trit27) struct { u32, u32 } {
    const packed_val = @as(i64, value);
    return .{
        .lo = @as(u32, @truncate(packed_val)),
        .hi = @as(u32, @truncate(packed_val >> 32)),
    };
}

// ══════════════════════════════════════════════════════════════════════════════════════
pub const Memory = struct {
    allocator: std.mem.Allocator,
    data: []Word,

    /// Initialize memory with default size
    pub fn init(allocator: std.mem.Allocator) !Memory {
        const data = try allocator.alloc(Word, MEMORY_SIZE_WORDS);
        errdefer allocator.free(data);

        // Zero initialize all words
        for (0..MEMORY_SIZE_WORDS) |i| {
            data[i] = Word{ .trits = 0 };
        }

        return .{
            .allocator = allocator,
            .data = data,
        };
    }

    /// Cleanup
    pub fn deinit(self: *Memory) void {
        self.allocator.free(self.data);
    }

    /// Read a word at byte-aligned address
    pub fn readWord(self: *Memory, byte_addr: u32) MemError!u32 {
        const word_addr = byte_addr / 4;

        if (word_addr >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        if (byte_addr % 4 != 0) {
            return MemError.WordAlignmentError;
        }

        return self.data[word_addr].trits;
    }

    /// Write a word at byte-aligned address
    pub fn writeWord(self: *Memory, byte_addr: u32, value: u32) MemError!void {
        const word_addr = byte_addr / 4;

        if (word_addr >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        if (byte_addr % 4 != 0) {
            return MemError.WordAlignmentError;
        }

        self.data[word_addr].trits = wordsToTrit27(value, 0).trits;
    }

    /// Read Trit27 value (packed as 2 words)
    pub fn readTrit27(self: *Memory, word_addr: u32) MemError!Trit27 {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const lo = self.readWord(word_addr * 4) catch |err| return err;
        const hi = self.readWord((word_addr + 1) * 4) catch |err| return err;

        return wordsToTrit27(lo, hi);
    }

    /// Write Trit27 value (packed as 2 words)
    pub fn writeTrit27(self: *Memory, word_addr: u32, value: Trit27) MemError!void {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const words = trit27ToWords(value);
        try self.writeWord(word_addr * 4, words.lo);
        try self.writeWord((word_addr + 1) * 4, words.hi);
    }
};
