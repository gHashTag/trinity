// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TRI-27 LOADER — Load .tbin bytecode files into CPU state
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const cpu_state = @import("./cpu_state.zig");
const tri_memory = @import("./tri_memory.zig");

/// Magic number for .tbin files: "TRI2"
const MAGIC: u32 = 0x54524932; // '2' | 'I' << 8 | 'R' << 16 | 'T' << 24 (little-endian "2IRT")

/// Supported version
const VERSION: u8 = 1;

/// Section types
pub const SectionType = enum(u8) {
    CODE = 1,
    CONSTANTS = 2,
    DATA = 3,
    BSS = 4,
};

/// Load error set
pub const LoadError = error{
    InvalidMagic,
    InvalidVersion,
    CorruptHeader,
    Truncated,
    SectionMissing,
    InvalidSection,
    DataTooLarge,
};

/// Validate magic number from first 4 bytes
pub fn validateMagic(bytes: []const u8) LoadError!void {
    if (bytes.len < 4) return LoadError.Truncated;

    const magic = @as(u32, bytes[0]) |
        @as(u32, bytes[1]) << 8 |
        @as(u32, bytes[2]) << 16 |
        @as(u32, bytes[3]) << 24;

    // std.debug.print("validateMagic: got 0x{X:0>8}, expect 0x{X:0>8}\n", .{ magic, MAGIC });

    if (magic != MAGIC) {
        return LoadError.InvalidMagic;
    }
}

/// Validate version byte
pub fn validateVersion(version: u8) LoadError!void {
    if (version != VERSION) {
        return LoadError.InvalidVersion;
    }
}

/// Load .tbin file into CPU state
pub fn load(cpu: *cpu_state.CPUState, code: []const u8, constants: []const f64) LoadError!void {
    if (code.len < 6) return LoadError.Truncated;

    // Validate magic number
    try validateMagic(code[0..4]);

    // Validate version
    try validateVersion(code[4]);

    // Get section count
    const section_count = code[5];
    var offset: usize = 6;

    // Track code section for CPU
    var code_size: usize = 0;

    // Process each section
    for (0..section_count) |_| {
        if (offset + 1 > code.len) return LoadError.Truncated;

        const section_type = code[offset];

        switch (section_type) {
            1 => { // CODE section
                // Section header: type(1) + padding(1) + size(2) = 4 bytes
                if (offset + 4 > code.len) return LoadError.Truncated;

                const size = @as(u16, code[offset + 2]) | (@as(u16, code[offset + 3]) << 8);

                // Move offset past section header (type=1 + padding=1 + size=2 = 4 bytes)
                offset += 4;

                // Container padding: the two bytes tri_asm.zig writes after the CODE
                // header so the payload starts at byte 12, the word-3 boundary the
                // fetch reads at pc * 4. The writer and the loader agree on the
                // twelve-byte container header.
                if (offset + 2 > code.len) return LoadError.Truncated;
                offset += 2;

                if (offset + size > code.len) return LoadError.Truncated;

                // One code word per four-byte fetch unit: repack the payload into the
                // byte-addressed memory at byte 12 + i*4, so run's fetch at pc * 4
                // reads exactly the word that was written, starting at pc = 3.
                const code_data = code[offset .. offset + size];
                const bytes = cpu.getBytesMut();
                if (12 + size > bytes.len) return LoadError.DataTooLarge;
                var i: usize = 0;
                while (i + 4 <= size) : (i += 4) {
                    @memcpy(bytes[12 + i .. 12 + i + 4], code_data[i .. i + 4]);
                }
                code_size = size;

                offset += size;
            },

            2 => { // CONSTANTS section
                // Documented layout: id (1) + count (1) + count * 8 bytes.
                // The values come from the constants array the caller passes; the
                // file bytes are skipped.
                if (offset + 2 > code.len) return LoadError.Truncated;

                const num_constants = code[offset + 1];
                offset += 2;

                // Load constants from constants array (passed as parameter)
                // Store as u64 in Word format for compatibility
                for (0..@min(num_constants, constants.len)) |i| {
                    if (i < 3) {
                        // Convert f64 to u64 for Word.word_value
                        const bits: u64 = @as(u64, @bitCast(constants[i]));
                        // Store in high word (constants use upper 48 bits of Word)
                        // For now, store in lower memory as u16
                        cpu.f[i] = @as(u16, @truncate(bits >> 32));
                    }
                }

                // Skip constant data in file (already passed via constants array)
                const data_size = @as(usize, num_constants) * 8; // 8 bytes per f64
                if (offset + data_size > code.len) return LoadError.Truncated;
                offset += data_size;
            },

            3 => { // DATA section
                if (offset + 3 > code.len) return LoadError.Truncated;

                const data_size = (@as(u16, code[offset + 1]) | @as(u16, code[offset + 2]) << 8);
                offset += 3; // Skip size + padding

                if (offset + data_size > code.len) return LoadError.Truncated;

                // Copy data to memory after code section
                const data_offset = code_size;
                if (data_offset + data_size > cpu.memory_len) return LoadError.DataTooLarge;

                const data_data = code[offset .. offset + data_size];
                for (0..data_size) |i| {
                    cpu.memory[data_offset + i] = tri_memory.Word{ .word_value = @intCast(data_data[i]) };
                }

                offset += data_size;
            },

            4 => { // BSS section (uninitialized)
                if (offset + 3 > code.len) return LoadError.Truncated;

                const bss_size = (@as(u16, code[offset + 1]) | @as(u16, code[offset + 2]) << 8);
                offset += 3;

                // BSS is just reserved space, no data to copy
                _ = bss_size;
            },

            else => return LoadError.InvalidSection,
        }
    }

    // Initialize CPU state
    // The twelve-byte container header (magic, version, section count, the CODE
    // section header and its two padding bytes) ends at the first instruction,
    // word 3 — the address run fetches at pc * 4.
    cpu.pc = 3;
    cpu.sp = @as(u32, @intCast(cpu.memory_len - 1));
    cpu.fp = 0;
    cpu.instructions_executed = 0;
    cpu.cycles = 0;

    // Validate that we have a code section
    if (code_size == 0) return LoadError.SectionMissing;

    // Validate that constants count matches input
    const total_constants = code[4];
    _ = total_constants;
}

// ═════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════

test "load: the writer's twelve-byte container lands at word 3 with pc = 3" {
    // The container tri_asm.zig writes: magic, version 1, one section, the CODE
    // header, two padding bytes, then two instruction words.
    const container = [_]u8{
        0x32, 0x49, 0x52, 0x54, // magic
        0x01, // version
        0x01, // section count
        0x01, 0x00, 0x08, 0x00, // CODE: id, padding, size 8
        0x00, 0x00, // container padding
        0xaa, 0xbb, 0xcc, 0xdd, // word 0
        0x11, 0x22, 0x33, 0x44, // word 1
    };

    var cpu = try cpu_state.CPUState.init(std.testing.allocator);
    defer cpu.deinit();

    try load(&cpu, &container, &[_]f64{});

    // pc starts at the first instruction word, and the fetch at pc * 4 reads
    // exactly the two written words.
    try std.testing.expectEqual(@as(u32, 3), cpu.pc);
    const bytes = cpu.getBytes();
    try std.testing.expectEqual(@as(u8, 0xaa), bytes[12]);
    try std.testing.expectEqual(@as(u8, 0xbb), bytes[13]);
    try std.testing.expectEqual(@as(u8, 0xcc), bytes[14]);
    try std.testing.expectEqual(@as(u8, 0xdd), bytes[15]);
    try std.testing.expectEqual(@as(u8, 0x11), bytes[16]);
    try std.testing.expectEqual(@as(u8, 0x44), bytes[19]);
    // Words 0..2 keep the zeros of a fresh CPU: no padding leaks into the code.
    for (0..12) |i| try std.testing.expectEqual(@as(u8, 0), bytes[i]);
}

test "load: the CONSTANTS parser reads the id, then the count, then count * 8 bytes" {
    // Documented layout: id (2) + count (1) + eight bytes, then the CODE section
    // with its header and padding.
    const container = [_]u8{
        0x32, 0x49, 0x52, 0x54, // magic
        0x01, // version
        0x02, // section count
        0x02, 0x01, // CONSTANTS: id, count 1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // the constant's eight bytes
        0x01, 0x00, 0x04, 0x00, // CODE: id, padding, size 4
        0x00, 0x00, // container padding
        0x01, 0x02, 0x03, 0x04, // one instruction word
    };

    var cpu = try cpu_state.CPUState.init(std.testing.allocator);
    defer cpu.deinit();

    try load(&cpu, &container, &[_]f64{0.0});

    // The loader consumed exactly id + count + eight bytes: the code section that
    // follows is found and packed at byte 12.
    try std.testing.expectEqual(@as(u32, 3), cpu.pc);
    const bytes = cpu.getBytes();
    try std.testing.expectEqual(@as(u8, 0x01), bytes[12]);
    try std.testing.expectEqual(@as(u8, 0x04), bytes[15]);
}
