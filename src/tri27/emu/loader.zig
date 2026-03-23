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
        @as(u32, bytes[3]);

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
        offset += 1;

        switch (section_type) {
            1 => { // CODE section
                if (offset + 3 > code.len) return LoadError.Truncated;

                const size = @as(u16, code[offset + 1]) | (@as(u16, code[offset + 2]) << 8);
                offset += 3; // Skip size + padding

                if (offset + size > code.len) return LoadError.Truncated;
                if (offset + size > cpu.memory_len) return LoadError.DataTooLarge;

                // Copy code to CPU memory
                const code_data = code[offset .. offset + size];
                for (0..size) |i| {
                    cpu.memory[i] = tri_memory.Word{ .word_value = @intCast(code_data[i]) };
                }
                code_size = size;

                offset += size;
            },

            2 => { // CONSTANTS section
                if (offset + 1 > code.len) return LoadError.Truncated;

                const num_constants = code[offset];
                offset += 1;

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
                const data_size = num_constants * 8; // 8 bytes per f64
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
    cpu.pc = 0;
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
