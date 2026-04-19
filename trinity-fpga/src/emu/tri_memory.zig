// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 MEMORY — 3^9 = 19683 Word Address Space
//
// Memory model:
// - Word-aligned: 32-bit words (raw instruction words for fetch)
// - Data: stores Trit27 in 54-bit words (sign-extended)
// - Addressable: byte-addressed with 4-byte word alignment
// - Size: 3^9 = 19683 words = 78732 bytes
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ════════════════════════════════════════════════════════════════════════════════════════
pub const MEMORY_SIZE_WORDS: usize = 19683;
pub const MEMORY_SIZE_BYTES: usize = 78732;

// ════════════════════════════════════════════════════════════════════════════════════════
pub const Trit27 = i54;

// ════════════════════════════════════════════════════════════════════════════════════════
pub const MemError = error{
    AddressOutOfBounds,
    WordAlignmentError,
    InvalidTrit27,
};

// ══════════════════════════════════════════════════════════════════════════════════════════════
/// Memory word structure (32-bit)
/// For instructions: stores raw 32-bit instruction word
/// For data: stores Trit27 in 54-bit words (sign-extended in i64)
pub const Word = struct {
    /// Raw word value (u32 for instructions, i64 for Trit27 data)
    word_value: u64 = 0,
};

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
pub const Memory = struct {
    allocator: std.mem.Allocator,
    data: []Word,

    /// Initialize memory with default size
    pub fn init(allocator: std.mem.Allocator) !Memory {
        const data = try allocator.alloc(Word, MEMORY_SIZE_WORDS);
        errdefer allocator.free(data);

        // Zero initialize all words
        for (0..MEMORY_SIZE_WORDS) |i| {
            data[i] = Word{ .word_value = 0 };
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

        // Return lower 32 bits of word (u32 for instructions)
        return @as(u32, @truncate(self.data[word_addr].word_value));
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

        // Store raw 32-bit word
        self.data[word_addr].word_value = value;
    }

    /// Read Trit27 value (packed as 2 words)
    pub fn readTrit27(self: *Memory, word_addr: u32) MemError!Trit27 {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const lo = try self.readWord(word_addr * 4);
        const hi = try self.readWord((word_addr + 1) * 4);

        // Combine two 32-bit words into 54-bit Trit27
        // lo:bits[0:31], hi:bits[32:63] (but we only use bits for Trit27)
        const combined: i64 = @as(i64, lo) | (@as(i64, hi) << 32);
        return @truncate(combined);
    }

    /// Write Trit27 value (packed as 2 words)
    pub fn writeTrit27(self: *Memory, word_addr: u32, value: Trit27) MemError!void {
        if (word_addr + 1 >= MEMORY_SIZE_WORDS) {
            return MemError.AddressOutOfBounds;
        }

        const lo: u32 = @as(u32, @truncate(value));
        const hi: u32 = @as(u32, @truncate(value >> 32));

        try self.writeWord(word_addr * 4, lo);
        try self.writeWord((word_addr + 1) * 4, hi);
    }
};
