// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TRI-27 LOADER — Load .tbin bytecode files into CPU state
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// .tbin: Binary format for TRI-27 bytecode
// Header: magic (4 bytes) + version (1 byte) + section_count (1 byte)
// Sections: 1=Code, 2=Constants, 3=Data, 4=BSS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

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

    const magic = std.mem.readInt(u32, bytes[0..4], .little);
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
    while (section_idx < section_count) : (section_idx += 1) {
        if (offset + 1 > code.len) return LoadError.Truncated;

        const section_type = code[offset];
        offset += 1;

        switch (section_type) {
            1 => { // CODE section
                if (offset + 3 > code.len) return LoadError.Truncated;

                const size = std.mem.readInt(u16, code[offset .. offset + 2], .little);
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

                const data_size = std.mem.readInt(u16, code[offset .. offset + 2], .little);
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

                const bss_size = std.mem.readInt(u16, code[offset .. offset + 2], .little);
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
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "Loader: validateMagic valid" {
    const valid_magic = [_]u8{ 0x37, 0x32, 0x49, 0x52 }; // "TRI27" little-endian
    try validateMagic(&valid_magic);
}

test "Loader: validateMagic invalid" {
    const invalid_magic = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
    try std.testing.expectError(LoadError.InvalidMagic, validateMagic(&invalid_magic));
}

test "Loader: validateVersion valid" {
    try validateVersion(1);
}

test "Loader: validateVersion invalid" {
    try std.testing.expectError(LoadError.InvalidVersion, validateVersion(255));
}

test "Loader: load minimal code" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // Minimal .tbin: magic + version + 0 sections
    const code = [_]u8{
        0x37, 0x32, 0x49, 0x52, // magic
        0x01, // version
        0x00, // section_count = 0
    };

    try load(&cpu, &code, &[_]f64{});

    try std.testing.expectEqual(@as(u32, 0), cpu.pc);
}

test "Loader: load with code section" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    // .tbin with code section containing HALT (0x4D)
    const code = [_]u8{
        0x37, 0x32, 0x49, 0x52, // magic
        0x01, // version
        0x01, // section_count = 1
        0x01, // type = CODE
        0x01, 0x00, // size = 1
        0x00, // padding
        0x4D, // HALT opcode
    };

    try load(&cpu, &code, &[_]f64{});

    try std.testing.expectEqual(@as(u32, 0), cpu.pc);
    try std.testing.expectEqual(@as(u8, 0x4D), cpu.memory[0]);
}

test "Loader: load with constants" {
    var cpu = try cpu_state.CPUState.init(std.testing.allocator, 1024);
    defer cpu.deinit();

    const PI = 3.14159265358979323846;

    // .tbin with constants section
    const code = [_]u8{
        0x37, 0x32, 0x49, 0x52, // magic
        0x01, // version
        0x01, // section_count = 1
        0x02, // type = CONSTANTS
        0x01, // num_constants = 1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x40, // PI as f64 (placeholder)
    };

    const constants = [_]f64{PI};

    try load(&cpu, &code, &constants);

    try std.testing.expectEqual(PI, cpu.floats[0]);
}
