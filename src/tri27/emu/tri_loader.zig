// @origin(spec:tri27_isa.zig) @regen(manual-impl)
// TRI‑27 LOADER — .tbin Binary File Format Loader
//
// .tbin format:
// - Header: magic[4] (0x54524954 = "TRIT"), version[2], reserved[10]
// - Code section: offset[4], size[4], instruction_count[4]
// - Data section: offset[4], size[4]
// - Data: binary instruction stream
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Instruction = @import("tri_decode.zig").Instruction;
const Memory = @import("tri_memory.zig").Memory;

// ═══════════════════════════════════════════════════════════════════════════
// .tbin FILE FORMAT CONSTANTS
// ═════════════════════════════════════════════════════════════════════════════════════════
pub const MAGIC = @as(u32, 0x54524954);  // "TRIT" in ASCII
pub const HEADER_SIZE = 20;  // magic[4] + version[2] + reserved[10] + 3×section_header[8]

/// Section header format
pub const SectionHeader = packed struct {
    offset: u32,
    size: u32,
};

/// Main file header
pub const TBINHeader = packed struct {
    magic: u32,
    version: u16,
    reserved: [10]u8,

    pub const CODE_SECTION = 0;
    pub const DATA_SECTION = 1;
    pub const SYMTAB_SECTION = 2;

    pub fn isValid(self: TBINHeader) bool {
        return self.magic == MAGIC;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// LOADER ERROR
// ═══════════════════════════════════════════════════════════════════════════════════════
pub const LoaderError = error{
    InvalidMagic,
    UnsupportedVersion,
    CorruptedHeader,
    TruncatedFile,
    SectionOutOfBounds,
    InvalidInstruction,
    FileNotFound,
};

// ═════════════════════════════════════════════════════════════════════════
// LOAD RESULT — Information about loaded program
// ═════════════════════════════════════════════════════════════════════════════════════════
pub const LoadResult = struct {
    entry_point: u32,        // IP where execution starts
    code_size: usize,        // Size of code section in bytes
    data_size: usize,        // Size of data section in bytes
    instruction_count: u32, // Number of instructions
};

// ═══════════════════════════════════════════════════════════════════════════
// LOAD — Load .tbin file into memory
// ═══════════════════════════════════════════════════════════════════════════════════════════
pub fn load(path: []const u8, allocator: std.mem.Allocator, mem: *Memory) LoaderError!LoadResult {
    // Read entire file
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return LoaderError.FileNotFound;
        }
        return LoaderError.TruncatedFile;
    };
    defer file.close();

    const file_size = try file.getEndPos();

    // Read and parse header
    var header_buf: [HEADER_SIZE]u8 = undefined;
    const bytes_read = try file.readAll(&header_buf);

    if (bytes_read < HEADER_SIZE) {
        return LoaderError.CorruptedHeader;
    }

    const header = std.mem.bytesAsValue(TBINHeader, &header_buf);

    if (!header.isValid()) {
        return LoaderError.InvalidMagic;
    }

    if (header.version != 1) {
        return LoaderError.UnsupportedVersion;
    }

    // Read section headers (3 sections after main header)
    var code_header: SectionHeader = undefined;
    var data_header: SectionHeader = undefined;
    var symtab_header: SectionHeader = undefined;

    const header_bytes = bytes_read[HEADER_SIZE..];

    // Read section 0 (code)
    if (header_bytes.len >= 8) {
        code_header.offset = std.mem.readInt(u32, header_bytes[0..4], .little);
        code_header.size = std.mem.readInt(u32, header_bytes[4..8], .little);
    }

    // Read section 1 (data)
    if (header_bytes.len >= 16) {
        data_header.offset = std.mem.readInt(u32, header_bytes[8..12], .little);
        data_header.size = std.mem.readInt(u32, header_bytes[12..16], .little);
    }

    // Read section 2 (symbol table - optional)
    if (header_bytes.len >= 24) {
        symtab_header.offset = std.mem.readInt(u32, header_bytes[16..20], .little);
        symtab_header.size = std.mem.readInt(u32, header_bytes[20..24], .little);
    }

    // Calculate instruction count
    const instruction_count = code_header.size / @sizeOf(u32);

    // Validate file integrity
    if (file_size < code_header.offset + code_header.size) {
        return LoaderError.TruncatedFile;
    }

    // Seek to code section and load into memory
    try file.seekTo(code_header.offset, .start);
    const code_buf = try allocator.alloc(u8, code_header.size);
    defer allocator.free(code_buf);

    const code_bytes_read = try file.readAll(code_buf);
    if (code_bytes_read < code_header.size) {
        return LoaderError.TruncatedFile;
    }

    // Load instructions into memory starting at address 0
    const entry_point: u32 = 0;  // Default entry point

    for (0..instruction_count) |i| {
        const offset = i * @sizeOf(u32);
        const inst_word = std.mem.readInt(u32, code_buf[offset..][0..4], .little);
        const word_addr = @as(u32, i);

        // Verify address fits in memory
        if (word_addr >= @as(u32, mem.data.len / @sizeOf(u32))) {
            return LoaderError.SectionOutOfBounds;
        }

        // Write instruction word to memory
        const byte_addr = word_addr * @sizeOf(u32);
        if (byte_addr + 4 <= mem.data.len) {
            @memcpy(&mem.data[byte_addr], &inst_word, 4);
        }
    }

    // Load data section if present
    var data_size: usize = 0;
    if (data_header.size > 0 and data_header.offset + data_header.size <= file_size) {
        try file.seekTo(data_header.offset, .start);
        const data_buf = try allocator.alloc(u8, data_header.size);
        defer allocator.free(data_buf);

        const data_bytes_read = try file.readAll(data_buf);
        if (data_bytes_read < data_header.size) {
            return LoaderError.TruncatedFile;
        }

        // Data section follows code in memory
        const data_start_addr = instruction_count * @sizeOf(u32);
        if (data_start_addr + data_header.size <= mem.data.len) {
            @memcpy(&mem.data[data_start_addr], data_buf, data_header.size);
            data_size = data_header.size;
        }
    }

    return LoadResult{
        .entry_point = entry_point,
        .code_size = code_header.size,
        .data_size = data_size,
        .instruction_count = @as(u32, instruction_count),
    };
}

// ═════════════════════════════════════════════════════════════════════════
// LOAD FROM BYTES — Load program from byte array (for testing)
// ═══════════════════════════════════════════════════════════════════════════════════════
pub fn loadFromBytes(data: []const u8, allocator: std.mem.Allocator, mem: *Memory) LoaderError!LoadResult {
    if (data.len < HEADER_SIZE) {
        return LoaderError.CorruptedHeader;
    }

    const header = std.mem.bytesAsValue(TBINHeader, data[0..HEADER_SIZE]);

    if (!header.isValid()) {
        return LoaderError.InvalidMagic;
    }

    if (header.version != 1) {
        return LoaderError.UnsupportedVersion;
    }

    // Read section headers
    var code_header: SectionHeader = undefined;
    const header_bytes = data[HEADER_SIZE..];

    code_header.offset = std.mem.readInt(u32, header_bytes[0..4], .little);
    code_header.size = std.mem.readInt(u32, header_bytes[4..8], .little);

    const instruction_count = code_header.size / @sizeOf(u32);

    // Load code into memory
    const entry_point: u32 = 0;

    const code_offset = code_header.offset;
    if (code_offset + code_header.size > data.len) {
        return LoaderError.TruncatedFile;
    }

    for (0..instruction_count) |i| {
        const offset = code_offset + i * @sizeOf(u32);
        const inst_word = std.mem.readInt(u32, data[offset..][0..4], .little);
        const word_addr = @as(u32, i);

        if (word_addr * 4 + 4 <= mem.data.len) {
            const byte_addr = word_addr * 4;
            @memcpy(&mem.data[byte_addr], &inst_word, 4);
        }
    }

    return LoadResult{
        .entry_point = entry_point,
        .code_size = code_header.size,
        .data_size = 0,  // Not loaded from bytes
        .instruction_count = @as(u32, instruction_count),
    };
}

// ═════════════════════════════════════════════════════════════════════════════════════
// WRITE .tbin FILE — Create valid .tbin from instructions
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
pub fn writeFile(path: []const u8, instructions: []const Instruction) LoaderError!void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    // Write header
    const header = TBINHeader{
        .magic = MAGIC,
        .version = 1,
        .reserved = [_]u8{0} ** 10,
    };

    const code_size = instructions.len * @sizeOf(u32);
    var header_buf: [HEADER_SIZE]u8 = undefined;
    std.mem.copy(u8, &header_buf, std.mem.asBytes(&header));
    std.mem.writeInt(u32, header_buf[4..8], @as(u32, code_size), .little);
    std.mem.writeInt(u32, header_buf[12..16], @as(u32, 0), .little);  // Data section (empty)
    std.mem.writeInt(u32, header_buf[16..20], @as(u32, 0), .little);  // Symtab (empty)

    _ = try file.writeAll(&header_buf);

    // Write code section header
    const code_offset = @as(u32, HEADER_SIZE);
    var code_header_buf: [8]u8 = undefined;
    std.mem.writeInt(u32, code_header_buf[0..4], code_offset, .little);
    std.mem.writeInt(u32, code_header_buf[4..8], @as(u32, code_size), .little);
    _ = try file.writeAll(&code_header_buf);

    // Write instructions
    for (instructions) |inst| {
        const inst_word = inst.encode();
        var word_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &word_buf, inst_word, .little);
        _ = try file.writeAll(&word_buf);
    }
}

// ═════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════
test "TBINHeader isValid" {
    const valid = TBINHeader{
        .magic = MAGIC,
        .version = 1,
        .reserved = [_]u8{0} ** 10,
    };

    const invalid = TBINHeader{
        .magic = 0x12345678,
        .version = 1,
        .reserved = [_]u8{0} ** 10,
    };

    try std.testing.expect(valid.isValid());
    try std.testing.expect(!invalid.isValid());
}

test "TBINHeader unsupported version" {
    const header = TBINHeader{
        .magic = MAGIC,
        .version = 2,  // Unsupported
        .reserved = [_]u8{0} ** 10,
    };

    try std.testing.expect(!header.isValid());
}

test "loadFromBytes simple program" {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    // Create minimal .tbin header + one NOP instruction
    var data: [HEADER_SIZE + 4 + 8]u8 = undefined;

    // Header
    std.mem.writeInt(u32, data[0..4], MAGIC, .little);
    std.mem.writeInt(u16, data[4..6], 1, .little);  // version 1
    @memset(data[6..16], 0, 10);  // reserved

    // Code section header (offset=20, size=4)
    std.mem.writeInt(u32, data[20..24], 20, .little);  // offset
    std.mem.writeInt(u32, data[24..28], 4, .little);   // size

    // Data section (empty, offset=24, size=0)
    std.mem.writeInt(u32, data[28..32], 24, .little);
    std.mem.writeInt(u32, data[32..36], 0, .little);

    // Symtab (empty, offset=24, size=0)
    std.mem.writeInt(u32, data[36..40], 24, .little);
    std.mem.writeInt(u32, data[40..44], 0, .little);

    // NOP instruction = 0x00000000
    std.mem.writeInt(u32, data[44..48], 0, .little);

    const result = try loadFromBytes(data[0..48], allocator, &mem);

    try std.testing.expectEqual(@as(u32, 0), result.entry_point);
    try std.testing.expectEqual(@as(usize, 4), result.code_size);
    try std.testing.expectEqual(@as(u32, 1), result.instruction_count);

    // Verify NOP in memory
    const loaded_word = try mem.readWord(0);
    try std.testing.expectEqual(@as(u32, 0), loaded_word);
}

test "writeFile read roundtrip" {
    const allocator = std.testing.allocator;
    const tmp_file = "test_roundtrip.tbin";

    const instructions = [_]Instruction{
        .{ .opcode = .NOP, .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false },
        .{ .opcode = .HALT, .dst = 0, .src1 = 0, .src2 = 0, .immediate = 0, .has_imm = false },
    };

    try writeFile(tmp_file, &instructions);
    defer {
        std.fs.cwd().deleteFile(tmp_file) catch {};
    }

    // Load back
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);
    const result = try load(tmp_file, allocator, &mem);

    try std.testing.expectEqual(@as(u32, 2), result.instruction_count);

    // Verify instructions
    const nop_word = try mem.readWord(0);
    const halt_word = try mem.readWord(1);

    try std.testing.expectEqual(@as(u32, 0), nop_word);  // NOP = 0x00000000
    try std.testing.expectEqual(@as(u32, 0xFF000000), halt_word);  // HALT opcode
}

test "load invalid magic" {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    var data: [HEADER_SIZE]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], 0x12345678, .little);  // Wrong magic

    const result = loadFromBytes(data, allocator, &mem);

    try std.testing.expectError(LoaderError.InvalidMagic, result);
}

test "load unsupported version" {
    const allocator = std.testing.allocator;
    var mem = try Memory.initCustom(allocator, 100);
    defer mem.deinit(allocator);

    var data: [HEADER_SIZE]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], MAGIC, .little);
    std.mem.writeInt(u16, data[4..6], 2, .little);  // Version 2

    const result = loadFromBytes(data, allocator, &mem);

    try std.testing.expectError(LoaderError.UnsupportedVersion, result);
}
