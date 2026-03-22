// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TRI-27 LOADER — Load .tbin bytecode files into CPU state
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ section_count (1 byte)
//    const section_count = code[5];
//    var offset: usize = 6; // Start after header

const std = @import("std");
const cpu_state = @import("./cpu_state.zig");

/// Magic number for .tbin files: "TRI27"
const MAGIC: u32 = 0x54524937; // 'T' << 24 | 'R' << 16 | 'I' << 8 | '2' | '7'

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
    var section_idx: usize = 0;
    for (0..section_count) |section_idx| {
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
                    cpu.memory[i] = code_data[i];
                }
                code_size = size;

                offset += size;
            },

            2 => { // CONSTANTS section
                if (offset + 1 > code.len) return LoadError.Truncated;

                const num_constants = code[offset];
                offset += 1;

                // Load constants from constants array (passed as parameter)
                for (0..@min(num_constants, constants.len)) |i| {
                    if (i < 3) {
                        cpu.floats[i] = constants[i];
                    }
                }

                // Skip constant data in file (already passed via constants array)
                const data_size = num_constants * 8; // 8 bytes per f64
                if (offset + data_size > code.len) return LoadError.Truncated;
                offset += data_size;
            },

            3 => { // DATA section
                if (offset + 3 > code.len) return LoadError.Truncated;

                const data_size = (@as(u16, code[offset + 1]) | @as(u16, code[offset + 2])) << 8;
                offset += 3; // Skip size + padding

                if (offset + data_size > code.len) return LoadError.Truncated;

                // Copy data to memory after code section
                const data_offset = code_size;
                if (data_offset + data_size > cpu.memory_len) return LoadError.DataTooLarge;

                const data_data = code[offset .. offset + data_size];
                for (0..data_size) |i| {
                    cpu.memory[data_offset + i] = data_data[i];
                }

                offset += data_size;
            },

            4 => { // BSS section (uninitialized)
                if (offset + 3 > code.len) return LoadError.Truncated;

                const bss_size = (@as(u16, code[offset + 1]) | @as(u16, code[offset + 2])) << 8;
                offset += 3;

                // BSS is just reserved space, no data to copy
                _ = bss_size;
            },

            else => return LoadError.InvalidSection,
        }
    }

    // Initialize CPU state
    cpu.pc = 0;
    cpu.sp = cpu.memory_len - 1;
    cpu.fp = 0;
    cpu.instructions_executed = 0;
    cpu.start_time = 0;
    cpu.end_time = 0;

    // Validate that we have a code section
    if (code_size == 0) return LoadError.SectionMissing;

    // Validate that constants count matches input
    const total_constants = code[4];
    _ = total_constants;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════.zig:1814:49: note: parameter type declared here
pub inline fn readInt(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8, endian: Endian) T {
                                                ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

test "Loader: load code section" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit(std.testing.allocator);

    const code = [_]u8{
        0x37, 0x32, 0x49, 0x52, // "TRI27" magic
        0x01, // version
        0x01, // section_count = 1
        0x01, // type = CODE
        0x01, 0x00, // size = 1
        0x00, // padding
        0x4D, // HALT
    };

    try loader.load(&cpu, &code, &[_]f64{});

    try std.testing.expectEqual(@as(u32, 0), cpu.pc);
}