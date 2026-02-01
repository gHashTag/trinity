// B2T Loader - Binary-to-Ternary Converter
// Loads PE, ELF, Mach-O, WASM binaries
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const BinaryFormat = enum {
    pe64,
    elf64,
    macho64,
    wasm,
    unknown,
};

pub const Section = struct {
    name: []const u8,
    virtual_address: u64,
    virtual_size: u64,
    raw_data: []const u8,
    characteristics: u32,
    is_executable: bool,
    is_writable: bool,
};

pub const Symbol = struct {
    name: []const u8,
    address: u64,
    size: u64,
    symbol_type: SymbolType,
};

pub const SymbolType = enum {
    function,
    data,
    import,
    export,
    unknown,
};

pub const Relocation = struct {
    offset: u64,
    reloc_type: u32,
    symbol_index: u32,
    addend: i64,
};

pub const LoadedBinary = struct {
    allocator: std.mem.Allocator,
    format: BinaryFormat,
    architecture: Architecture,
    entry_point: u64,
    sections: std.ArrayList(Section),
    symbols: std.ArrayList(Symbol),
    relocations: std.ArrayList(Relocation),
    raw_data: []const u8,

    pub fn init(allocator: std.mem.Allocator) LoadedBinary {
        return LoadedBinary{
            .allocator = allocator,
            .format = .unknown,
            .architecture = .unknown,
            .entry_point = 0,
            .sections = std.ArrayList(Section).init(allocator),
            .symbols = std.ArrayList(Symbol).init(allocator),
            .relocations = std.ArrayList(Relocation).init(allocator),
            .raw_data = &[_]u8{},
        };
    }

    pub fn deinit(self: *LoadedBinary) void {
        self.sections.deinit();
        self.symbols.deinit();
        self.relocations.deinit();
    }

    pub fn getCodeSections(self: *const LoadedBinary) []const Section {
        var code_sections = std.ArrayList(Section).init(self.allocator);
        defer code_sections.deinit();

        for (self.sections.items) |section| {
            if (section.is_executable) {
                code_sections.append(section) catch continue;
            }
        }

        return code_sections.toOwnedSlice() catch &[_]Section{};
    }
};

pub const Architecture = enum {
    x86_64,
    arm64,
    wasm,
    unknown,
};

pub const LoadError = error{
    FileNotFound,
    InvalidFormat,
    UnsupportedArchitecture,
    CorruptedBinary,
    OutOfMemory,
    InvalidMagic,
    TruncatedFile,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAGIC NUMBERS
// ═══════════════════════════════════════════════════════════════════════════════

const PE_MAGIC: u16 = 0x5A4D; // "MZ"
const ELF_MAGIC: u32 = 0x464C457F; // "\x7FELF"
const MACHO_MAGIC_64: u32 = 0xFEEDFACF;
const WASM_MAGIC: u32 = 0x6D736100; // "\0asm"

// ═══════════════════════════════════════════════════════════════════════════════
// FORMAT DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn detectFormat(data: []const u8) BinaryFormat {
    if (data.len < 4) return .unknown;

    // Check WASM magic (little-endian: 00 61 73 6D)
    if (data[0] == 0x00 and data[1] == 0x61 and data[2] == 0x73 and data[3] == 0x6D) {
        return .wasm;
    }

    // Check ELF magic
    if (data[0] == 0x7F and data[1] == 'E' and data[2] == 'L' and data[3] == 'F') {
        return .elf64;
    }

    // Check PE magic (MZ header)
    if (data[0] == 'M' and data[1] == 'Z') {
        return .pe64;
    }

    // Check Mach-O magic
    const magic32 = std.mem.readInt(u32, data[0..4], .little);
    if (magic32 == MACHO_MAGIC_64) {
        return .macho64;
    }

    return .unknown;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN LOADER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn load(allocator: std.mem.Allocator, path: []const u8) LoadError!LoadedBinary {
    // Read file
    const file = std.fs.cwd().openFile(path, .{}) catch return LoadError.FileNotFound;
    defer file.close();

    const stat = file.stat() catch return LoadError.FileNotFound;
    const data = allocator.alloc(u8, stat.size) catch return LoadError.OutOfMemory;
    _ = file.readAll(data) catch return LoadError.CorruptedBinary;

    return loadFromMemory(allocator, data);
}

pub fn loadFromMemory(allocator: std.mem.Allocator, data: []const u8) LoadError!LoadedBinary {
    const format = detectFormat(data);

    return switch (format) {
        .wasm => loadWasm(allocator, data),
        .elf64 => loadElf64(allocator, data),
        .pe64 => loadPe64(allocator, data),
        .macho64 => loadMachO64(allocator, data),
        .unknown => LoadError.InvalidFormat,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// WASM LOADER (MVP)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadWasm(allocator: std.mem.Allocator, data: []const u8) LoadError!LoadedBinary {
    if (data.len < 8) return LoadError.TruncatedFile;

    // Verify magic
    if (data[0] != 0x00 or data[1] != 0x61 or data[2] != 0x73 or data[3] != 0x6D) {
        return LoadError.InvalidMagic;
    }

    // Verify version (1)
    if (data[4] != 0x01 or data[5] != 0x00 or data[6] != 0x00 or data[7] != 0x00) {
        return LoadError.UnsupportedArchitecture;
    }

    var binary = LoadedBinary.init(allocator);
    binary.format = .wasm;
    binary.architecture = .wasm;
    binary.raw_data = data;

    // Parse WASM sections
    var offset: usize = 8;
    while (offset < data.len) {
        if (offset >= data.len) break;

        const section_id = data[offset];
        offset += 1;

        // Read section size (LEB128)
        const size_result = readLeb128(data[offset..]);
        const section_size = size_result.value;
        offset += size_result.bytes_read;

        const section_data = data[offset .. offset + section_size];

        // Create section based on ID
        const section_name = switch (section_id) {
            0 => "custom",
            1 => "type",
            2 => "import",
            3 => "function",
            4 => "table",
            5 => "memory",
            6 => "global",
            7 => "export",
            8 => "start",
            9 => "element",
            10 => "code",
            11 => "data",
            else => "unknown",
        };

        const section = Section{
            .name = section_name,
            .virtual_address = offset,
            .virtual_size = section_size,
            .raw_data = section_data,
            .characteristics = section_id,
            .is_executable = section_id == 10, // code section
            .is_writable = section_id == 11, // data section
        };

        binary.sections.append(section) catch return LoadError.OutOfMemory;

        // Handle start section (entry point)
        if (section_id == 8 and section_size > 0) {
            const start_result = readLeb128(section_data);
            binary.entry_point = start_result.value;
        }

        offset += section_size;
    }

    return binary;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ELF64 LOADER (Phase 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadElf64(allocator: std.mem.Allocator, data: []const u8) LoadError!LoadedBinary {
    if (data.len < 64) return LoadError.TruncatedFile;

    // Verify ELF magic
    if (data[0] != 0x7F or data[1] != 'E' or data[2] != 'L' or data[3] != 'F') {
        return LoadError.InvalidMagic;
    }

    // Check 64-bit
    if (data[4] != 2) return LoadError.UnsupportedArchitecture;

    var binary = LoadedBinary.init(allocator);
    binary.format = .elf64;
    binary.architecture = .x86_64;
    binary.raw_data = data;

    // Parse ELF header
    const e_entry = std.mem.readInt(u64, data[24..32], .little);
    const e_phoff = std.mem.readInt(u64, data[32..40], .little);
    const e_shoff = std.mem.readInt(u64, data[40..48], .little);
    const e_phnum = std.mem.readInt(u16, data[56..58], .little);
    const e_shnum = std.mem.readInt(u16, data[60..62], .little);
    const e_shstrndx = std.mem.readInt(u16, data[62..64], .little);

    binary.entry_point = e_entry;

    // Parse section headers
    const sh_size: usize = 64; // ELF64 section header size
    var shstrtab: []const u8 = &[_]u8{};

    // First pass: find string table
    if (e_shstrndx < e_shnum) {
        const strtab_offset = e_shoff + @as(u64, e_shstrndx) * sh_size;
        if (strtab_offset + sh_size <= data.len) {
            const sh_offset = std.mem.readInt(u64, data[strtab_offset + 24 .. strtab_offset + 32], .little);
            const sh_size_val = std.mem.readInt(u64, data[strtab_offset + 32 .. strtab_offset + 40], .little);
            if (sh_offset + sh_size_val <= data.len) {
                shstrtab = data[sh_offset .. sh_offset + sh_size_val];
            }
        }
    }

    // Second pass: parse all sections
    var i: u16 = 0;
    while (i < e_shnum) : (i += 1) {
        const sh_off = e_shoff + @as(u64, i) * sh_size;
        if (sh_off + sh_size > data.len) break;

        const sh_name_idx = std.mem.readInt(u32, data[sh_off .. sh_off + 4], .little);
        const sh_type = std.mem.readInt(u32, data[sh_off + 4 .. sh_off + 8], .little);
        const sh_flags = std.mem.readInt(u64, data[sh_off + 8 .. sh_off + 16], .little);
        const sh_addr = std.mem.readInt(u64, data[sh_off + 16 .. sh_off + 24], .little);
        const sh_offset = std.mem.readInt(u64, data[sh_off + 24 .. sh_off + 32], .little);
        const sh_size_val = std.mem.readInt(u64, data[sh_off + 32 .. sh_off + 40], .little);

        // Get section name
        var name: []const u8 = "unknown";
        if (sh_name_idx < shstrtab.len) {
            const name_start = shstrtab[sh_name_idx..];
            const null_pos = std.mem.indexOf(u8, name_start, &[_]u8{0}) orelse name_start.len;
            name = name_start[0..null_pos];
        }

        // Get section data
        var section_data: []const u8 = &[_]u8{};
        if (sh_type != 8 and sh_offset + sh_size_val <= data.len) { // SHT_NOBITS = 8
            section_data = data[sh_offset .. sh_offset + sh_size_val];
        }

        const section = Section{
            .name = name,
            .virtual_address = sh_addr,
            .virtual_size = sh_size_val,
            .raw_data = section_data,
            .characteristics = sh_type,
            .is_executable = (sh_flags & 0x4) != 0, // SHF_EXECINSTR
            .is_writable = (sh_flags & 0x1) != 0, // SHF_WRITE
        };

        binary.sections.append(section) catch return LoadError.OutOfMemory;
    }

    _ = e_phoff;
    _ = e_phnum;

    return binary;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PE64 LOADER (Phase 2)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadPe64(allocator: std.mem.Allocator, data: []const u8) LoadError!LoadedBinary {
    if (data.len < 64) return LoadError.TruncatedFile;

    // Verify MZ magic
    if (data[0] != 'M' or data[1] != 'Z') {
        return LoadError.InvalidMagic;
    }

    var binary = LoadedBinary.init(allocator);
    binary.format = .pe64;
    binary.architecture = .x86_64;
    binary.raw_data = data;

    // Get PE header offset
    const pe_offset = std.mem.readInt(u32, data[0x3C..0x40], .little);
    if (pe_offset + 24 > data.len) return LoadError.TruncatedFile;

    // Verify PE signature
    if (data[pe_offset] != 'P' or data[pe_offset + 1] != 'E' or
        data[pe_offset + 2] != 0 or data[pe_offset + 3] != 0)
    {
        return LoadError.InvalidMagic;
    }

    // Parse COFF header
    const coff_offset = pe_offset + 4;
    const num_sections = std.mem.readInt(u16, data[coff_offset + 2 .. coff_offset + 4], .little);
    const optional_header_size = std.mem.readInt(u16, data[coff_offset + 16 .. coff_offset + 18], .little);

    // Parse optional header
    const opt_offset = coff_offset + 20;
    if (opt_offset + optional_header_size > data.len) return LoadError.TruncatedFile;

    // Check PE32+ (64-bit)
    const magic = std.mem.readInt(u16, data[opt_offset .. opt_offset + 2], .little);
    if (magic != 0x20B) return LoadError.UnsupportedArchitecture; // PE32+ magic

    // Entry point
    const entry_rva = std.mem.readInt(u32, data[opt_offset + 16 .. opt_offset + 20], .little);
    const image_base = std.mem.readInt(u64, data[opt_offset + 24 .. opt_offset + 32], .little);
    binary.entry_point = image_base + entry_rva;

    // Parse section headers
    const section_offset = opt_offset + optional_header_size;
    const section_size: usize = 40;

    var i: u16 = 0;
    while (i < num_sections) : (i += 1) {
        const sh_off = section_offset + @as(usize, i) * section_size;
        if (sh_off + section_size > data.len) break;

        // Section name (8 bytes, null-padded)
        const name_bytes = data[sh_off .. sh_off + 8];
        const null_pos = std.mem.indexOf(u8, name_bytes, &[_]u8{0}) orelse 8;
        const name = name_bytes[0..null_pos];

        const virtual_size = std.mem.readInt(u32, data[sh_off + 8 .. sh_off + 12], .little);
        const virtual_addr = std.mem.readInt(u32, data[sh_off + 12 .. sh_off + 16], .little);
        const raw_size = std.mem.readInt(u32, data[sh_off + 16 .. sh_off + 20], .little);
        const raw_ptr = std.mem.readInt(u32, data[sh_off + 20 .. sh_off + 24], .little);
        const characteristics = std.mem.readInt(u32, data[sh_off + 36 .. sh_off + 40], .little);

        var section_data: []const u8 = &[_]u8{};
        if (raw_ptr + raw_size <= data.len) {
            section_data = data[raw_ptr .. raw_ptr + raw_size];
        }

        const section = Section{
            .name = name,
            .virtual_address = image_base + virtual_addr,
            .virtual_size = virtual_size,
            .raw_data = section_data,
            .characteristics = characteristics,
            .is_executable = (characteristics & 0x20000000) != 0, // IMAGE_SCN_MEM_EXECUTE
            .is_writable = (characteristics & 0x80000000) != 0, // IMAGE_SCN_MEM_WRITE
        };

        binary.sections.append(section) catch return LoadError.OutOfMemory;
    }

    return binary;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MACH-O LOADER (Phase 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadMachO64(allocator: std.mem.Allocator, data: []const u8) LoadError!LoadedBinary {
    _ = data;
    var binary = LoadedBinary.init(allocator);
    binary.format = .macho64;
    binary.architecture = .arm64;
    // TODO: Implement Mach-O parsing
    return binary;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

const Leb128Result = struct {
    value: u64,
    bytes_read: usize,
};

fn readLeb128(data: []const u8) Leb128Result {
    var result: u64 = 0;
    var shift: u6 = 0;
    var i: usize = 0;

    while (i < data.len and i < 10) {
        const byte = data[i];
        result |= @as(u64, byte & 0x7F) << shift;
        i += 1;

        if ((byte & 0x80) == 0) break;
        shift += 7;
    }

    return Leb128Result{ .value = result, .bytes_read = i };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "detect WASM format" {
    const wasm_data = [_]u8{ 0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00 };
    try std.testing.expectEqual(BinaryFormat.wasm, detectFormat(&wasm_data));
}

test "detect ELF format" {
    const elf_data = [_]u8{ 0x7F, 'E', 'L', 'F', 0x02, 0x01, 0x01, 0x00 };
    try std.testing.expectEqual(BinaryFormat.elf64, detectFormat(&elf_data));
}

test "detect PE format" {
    const pe_data = [_]u8{ 'M', 'Z', 0x90, 0x00 };
    try std.testing.expectEqual(BinaryFormat.pe64, detectFormat(&pe_data));
}

test "load minimal WASM" {
    const wasm_data = [_]u8{
        0x00, 0x61, 0x73, 0x6D, // magic
        0x01, 0x00, 0x00, 0x00, // version
    };

    var binary = try loadWasm(std.testing.allocator, &wasm_data);
    defer binary.deinit();

    try std.testing.expectEqual(BinaryFormat.wasm, binary.format);
    try std.testing.expectEqual(Architecture.wasm, binary.architecture);
}
