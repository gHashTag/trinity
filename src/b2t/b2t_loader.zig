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
    imported,
    exported,
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
            const sh_offset = std.mem.readInt(u64, data[strtab_offset + 24 ..][0..8], .little);
            const sh_size_val = std.mem.readInt(u64, data[strtab_offset + 32 ..][0..8], .little);
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

        const sh_name_idx = std.mem.readInt(u32, data[sh_off..][0..4], .little);
        const sh_type = std.mem.readInt(u32, data[sh_off + 4 ..][0..4], .little);
        const sh_flags = std.mem.readInt(u64, data[sh_off + 8 ..][0..8], .little);
        const sh_addr = std.mem.readInt(u64, data[sh_off + 16 ..][0..8], .little);
        const sh_offset = std.mem.readInt(u64, data[sh_off + 24 ..][0..8], .little);
        const sh_size_val = std.mem.readInt(u64, data[sh_off + 32 ..][0..8], .little);

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
    const num_sections = std.mem.readInt(u16, data[coff_offset + 2 ..][0..2], .little);
    const optional_header_size = std.mem.readInt(u16, data[coff_offset + 16 ..][0..2], .little);

    // Parse optional header
    const opt_offset = coff_offset + 20;
    if (opt_offset + optional_header_size > data.len) return LoadError.TruncatedFile;

    // Check PE32+ (64-bit)
    const magic = std.mem.readInt(u16, data[opt_offset..][0..2], .little);
    if (magic != 0x20B) return LoadError.UnsupportedArchitecture; // PE32+ magic

    // Entry point
    const entry_rva = std.mem.readInt(u32, data[opt_offset + 16 ..][0..4], .little);
    const image_base = std.mem.readInt(u64, data[opt_offset + 24 ..][0..8], .little);
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

        const virtual_size = std.mem.readInt(u32, data[sh_off + 8 ..][0..4], .little);
        const virtual_addr = std.mem.readInt(u32, data[sh_off + 12 ..][0..4], .little);
        const raw_size = std.mem.readInt(u32, data[sh_off + 16 ..][0..4], .little);
        const raw_ptr = std.mem.readInt(u32, data[sh_off + 20 ..][0..4], .little);
        const characteristics = std.mem.readInt(u32, data[sh_off + 36 ..][0..4], .little);

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
// MACH-O LOADER (64-bit)
// ═══════════════════════════════════════════════════════════════════════════════

// Mach-O constants
const MH_MAGIC_64: u32 = 0xFEEDFACF;
const MH_CIGAM_64: u32 = 0xCFFAEDFE; // Big-endian
const CPU_TYPE_X86_64: u32 = 0x01000007;
const CPU_TYPE_ARM64: u32 = 0x0100000C;
const LC_SEGMENT_64: u32 = 0x19;
const LC_SYMTAB: u32 = 0x02;
const LC_MAIN: u32 = 0x80000028;

pub fn loadMachO64(allocator: std.mem.Allocator, data: []const u8) LoadError!LoadedBinary {
    if (data.len < 32) return LoadError.TruncatedFile;

    // Verify Mach-O magic
    const magic = std.mem.readInt(u32, data[0..4], .little);
    if (magic != MH_MAGIC_64 and magic != MH_CIGAM_64) {
        return LoadError.InvalidMagic;
    }

    const is_big_endian = magic == MH_CIGAM_64;
    const endian: std.builtin.Endian = if (is_big_endian) .big else .little;

    var binary = LoadedBinary.init(allocator);
    binary.format = .macho64;
    binary.raw_data = data;

    // Parse Mach-O header (32 bytes for 64-bit)
    const cpu_type = std.mem.readInt(u32, data[4..8], endian);
    const ncmds = std.mem.readInt(u32, data[16..20], endian);
    // const sizeofcmds = std.mem.readInt(u32, data[20..24], endian);

    // Determine architecture
    binary.architecture = switch (cpu_type) {
        CPU_TYPE_X86_64 => .x86_64,
        CPU_TYPE_ARM64 => .arm64,
        else => .unknown,
    };

    // Parse load commands
    var cmd_offset: usize = 32; // After mach_header_64
    var i: u32 = 0;
    while (i < ncmds and cmd_offset + 8 <= data.len) : (i += 1) {
        const cmd = std.mem.readInt(u32, data[cmd_offset..][0..4], endian);
        const cmdsize = std.mem.readInt(u32, data[cmd_offset + 4 ..][0..4], endian);

        if (cmdsize < 8 or cmd_offset + cmdsize > data.len) break;

        switch (cmd) {
            LC_SEGMENT_64 => {
                // segment_command_64 structure
                if (cmdsize < 72) {
                    cmd_offset += cmdsize;
                    continue;
                }

                // Segment name (16 bytes)
                const seg_name_bytes = data[cmd_offset + 8 .. cmd_offset + 24];
                const seg_null_pos = std.mem.indexOf(u8, seg_name_bytes, &[_]u8{0}) orelse 16;
                const seg_name = seg_name_bytes[0..seg_null_pos];

                const vmaddr = std.mem.readInt(u64, data[cmd_offset + 24 ..][0..8], endian);
                const vmsize = std.mem.readInt(u64, data[cmd_offset + 32 ..][0..8], endian);
                const fileoff = std.mem.readInt(u64, data[cmd_offset + 40 ..][0..8], endian);
                const filesize = std.mem.readInt(u64, data[cmd_offset + 48 ..][0..8], endian);
                const maxprot = std.mem.readInt(u32, data[cmd_offset + 56 ..][0..4], endian);
                const nsects = std.mem.readInt(u32, data[cmd_offset + 64 ..][0..4], endian);

                // Add segment as section
                var seg_data: []const u8 = &[_]u8{};
                if (fileoff + filesize <= data.len) {
                    seg_data = data[fileoff .. fileoff + filesize];
                }

                const segment = Section{
                    .name = seg_name,
                    .virtual_address = vmaddr,
                    .virtual_size = vmsize,
                    .raw_data = seg_data,
                    .characteristics = maxprot,
                    .is_executable = (maxprot & 0x04) != 0, // VM_PROT_EXECUTE
                    .is_writable = (maxprot & 0x02) != 0, // VM_PROT_WRITE
                };
                binary.sections.append(segment) catch return LoadError.OutOfMemory;

                // Parse sections within segment
                var sect_offset = cmd_offset + 72;
                var s: u32 = 0;
                while (s < nsects and sect_offset + 80 <= data.len) : (s += 1) {
                    // section_64 structure (80 bytes)
                    const sect_name_bytes = data[sect_offset .. sect_offset + 16];
                    const sect_null_pos = std.mem.indexOf(u8, sect_name_bytes, &[_]u8{0}) orelse 16;
                    const sect_name = sect_name_bytes[0..sect_null_pos];

                    const sect_addr = std.mem.readInt(u64, data[sect_offset + 32 ..][0..8], endian);
                    const sect_size = std.mem.readInt(u64, data[sect_offset + 40 ..][0..8], endian);
                    const sect_offset_val = std.mem.readInt(u32, data[sect_offset + 48 ..][0..4], endian);
                    const sect_flags = std.mem.readInt(u32, data[sect_offset + 64 ..][0..4], endian);

                    var sect_data: []const u8 = &[_]u8{};
                    if (sect_offset_val + sect_size <= data.len) {
                        sect_data = data[sect_offset_val .. sect_offset_val + sect_size];
                    }

                    // Check if section is executable (in __TEXT segment or has execute flag)
                    const is_text = std.mem.eql(u8, seg_name, "__TEXT");
                    const is_exec = is_text or (sect_flags & 0x80000000) != 0;

                    const section = Section{
                        .name = sect_name,
                        .virtual_address = sect_addr,
                        .virtual_size = sect_size,
                        .raw_data = sect_data,
                        .characteristics = sect_flags,
                        .is_executable = is_exec,
                        .is_writable = !is_text,
                    };
                    binary.sections.append(section) catch return LoadError.OutOfMemory;

                    sect_offset += 80;
                }
            },
            LC_MAIN => {
                // entry_point_command
                if (cmdsize >= 16) {
                    const entryoff = std.mem.readInt(u64, data[cmd_offset + 8 ..][0..8], endian);
                    binary.entry_point = entryoff;
                }
            },
            else => {},
        }

        cmd_offset += cmdsize;
    }

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

// Minimal ELF64 binary for testing
// Layout:
//   0-63:   ELF header (64 bytes)
//   64-119: Program header (56 bytes)
//   120-127: Padding (8 bytes)
//   128-191: Section header 0 - NULL (64 bytes)
//   192-255: Section header 1 - .text (64 bytes)
//   256-319: Section header 2 - .shstrtab (64 bytes)
//   320-323: .text data (4 bytes)
//   324-340: .shstrtab data (17 bytes)
const TEST_ELF64 = [_]u8{
    // ELF Header (64 bytes) at offset 0
    0x7F, 'E', 'L', 'F', // e_ident[0..4]: magic
    0x02, // e_ident[4]: class = 64-bit
    0x01, // e_ident[5]: data = little endian
    0x01, // e_ident[6]: version = 1
    0x00, // e_ident[7]: OS/ABI = SYSV
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_ident[8..16]: padding
    0x02, 0x00, // e_type = ET_EXEC (executable)
    0x3E, 0x00, // e_machine = x86_64
    0x01, 0x00, 0x00, 0x00, // e_version = 1
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_entry = 0x1000
    0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_phoff = 64
    0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_shoff = 128
    0x00, 0x00, 0x00, 0x00, // e_flags = 0
    0x40, 0x00, // e_ehsize = 64
    0x38, 0x00, // e_phentsize = 56
    0x01, 0x00, // e_phnum = 1
    0x40, 0x00, // e_shentsize = 64
    0x03, 0x00, // e_shnum = 3 (null + .text + .shstrtab)
    0x02, 0x00, // e_shstrndx = 2

    // Program Header (56 bytes) at offset 64
    0x01, 0x00, 0x00, 0x00, // p_type = PT_LOAD
    0x05, 0x00, 0x00, 0x00, // p_flags = PF_R | PF_X
    0x40, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_offset = 320
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_vaddr = 0x1000
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_paddr = 0x1000
    0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_filesz = 4
    0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_memsz = 4
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_align = 0x1000

    // Padding to offset 128 (8 bytes)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

    // Section Header 0: NULL (64 bytes) at offset 128
    0x00, 0x00, 0x00, 0x00, // sh_name = 0
    0x00, 0x00, 0x00, 0x00, // sh_type = SHT_NULL
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_flags = 0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_addr = 0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_offset = 0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_size = 0
    0x00, 0x00, 0x00, 0x00, // sh_link = 0
    0x00, 0x00, 0x00, 0x00, // sh_info = 0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_addralign = 0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_entsize = 0

    // Section Header 1: .text (64 bytes) at offset 192
    0x01, 0x00, 0x00, 0x00, // sh_name = 1 (offset in shstrtab)
    0x01, 0x00, 0x00, 0x00, // sh_type = SHT_PROGBITS
    0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_flags = SHF_ALLOC | SHF_EXECINSTR
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_addr = 0x1000
    0x40, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_offset = 320
    0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_size = 4
    0x00, 0x00, 0x00, 0x00, // sh_link = 0
    0x00, 0x00, 0x00, 0x00, // sh_info = 0
    0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_addralign = 16
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_entsize = 0

    // Section Header 2: .shstrtab (64 bytes) at offset 256
    0x07, 0x00, 0x00, 0x00, // sh_name = 7 (offset in shstrtab)
    0x03, 0x00, 0x00, 0x00, // sh_type = SHT_STRTAB
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_flags = 0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_addr = 0
    0x44, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_offset = 324
    0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_size = 17
    0x00, 0x00, 0x00, 0x00, // sh_link = 0
    0x00, 0x00, 0x00, 0x00, // sh_info = 0
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_addralign = 1
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sh_entsize = 0

    // .text section data (4 bytes) at offset 320
    0xB8, 0x01, 0x00, 0x00, // mov eax, 1 (x86_64)

    // .shstrtab section data (17 bytes) at offset 324
    0x00, // null
    '.', 't', 'e', 'x', 't', 0x00, // .text
    '.', 's', 'h', 's', 't', 'r', 't', 'a', 'b', 0x00, // .shstrtab
};

test "load minimal ELF64" {
    var binary = try loadElf64(std.testing.allocator, &TEST_ELF64);
    defer binary.deinit();

    try std.testing.expectEqual(BinaryFormat.elf64, binary.format);
    try std.testing.expectEqual(Architecture.x86_64, binary.architecture);
    try std.testing.expectEqual(@as(u64, 0x1000), binary.entry_point);
}

test "ELF64 section parsing" {
    var binary = try loadElf64(std.testing.allocator, &TEST_ELF64);
    defer binary.deinit();

    // Should have 3 sections (null, .text, .shstrtab)
    try std.testing.expectEqual(@as(usize, 3), binary.sections.items.len);

    // Find .text section
    var found_text = false;
    for (binary.sections.items) |section| {
        if (std.mem.eql(u8, section.name, ".text")) {
            found_text = true;
            try std.testing.expect(section.is_executable);
            try std.testing.expectEqual(@as(u64, 0x1000), section.virtual_address);
            try std.testing.expectEqual(@as(u64, 4), section.virtual_size);
        }
    }
    try std.testing.expect(found_text);
}

test "ELF64 .text extraction" {
    var binary = try loadElf64(std.testing.allocator, &TEST_ELF64);
    defer binary.deinit();

    // Find .text section and verify code
    for (binary.sections.items) |section| {
        if (std.mem.eql(u8, section.name, ".text")) {
            // Should contain "mov eax, 1" (0xB8 0x01 0x00 0x00)
            try std.testing.expectEqual(@as(usize, 4), section.raw_data.len);
            try std.testing.expectEqual(@as(u8, 0xB8), section.raw_data[0]);
            try std.testing.expectEqual(@as(u8, 0x01), section.raw_data[1]);
            return;
        }
    }
    try std.testing.expect(false); // .text not found
}

// Minimal Mach-O 64-bit binary for testing
// Layout:
//   0-31:   mach_header_64 (32 bytes)
//   32-103: segment_command_64 for __TEXT (72 bytes)
//   104-183: section_64 for __text (80 bytes)
//   184-199: LC_MAIN (16 bytes)
//   200-203: code (4 bytes)
const TEST_MACHO64 = [_]u8{
    // mach_header_64 (32 bytes)
    0xCF, 0xFA, 0xED, 0xFE, // magic = MH_MAGIC_64
    0x07, 0x00, 0x00, 0x01, // cputype = CPU_TYPE_X86_64
    0x03, 0x00, 0x00, 0x00, // cpusubtype = CPU_SUBTYPE_X86_64_ALL
    0x02, 0x00, 0x00, 0x00, // filetype = MH_EXECUTE
    0x02, 0x00, 0x00, 0x00, // ncmds = 2
    0xA8, 0x00, 0x00, 0x00, // sizeofcmds = 168 (72+80+16)
    0x00, 0x00, 0x00, 0x00, // flags = 0
    0x00, 0x00, 0x00, 0x00, // reserved

    // segment_command_64 for __TEXT (72 bytes)
    0x19, 0x00, 0x00, 0x00, // cmd = LC_SEGMENT_64
    0x98, 0x00, 0x00, 0x00, // cmdsize = 152 (72 + 80)
    '_', '_', 'T', 'E', 'X', 'T', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // segname
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // vmaddr = 0x1000
    0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // vmsize = 4
    0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // fileoff = 200
    0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // filesize = 4
    0x07, 0x00, 0x00, 0x00, // maxprot = VM_PROT_ALL
    0x05, 0x00, 0x00, 0x00, // initprot = VM_PROT_READ | VM_PROT_EXECUTE
    0x01, 0x00, 0x00, 0x00, // nsects = 1
    0x00, 0x00, 0x00, 0x00, // flags = 0

    // section_64 for __text (80 bytes)
    '_', '_', 't', 'e', 'x', 't', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // sectname
    '_', '_', 'T', 'E', 'X', 'T', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // segname
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // addr = 0x1000
    0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // size = 4
    0xC8, 0x00, 0x00, 0x00, // offset = 200
    0x02, 0x00, 0x00, 0x00, // align = 2
    0x00, 0x00, 0x00, 0x00, // reloff = 0
    0x00, 0x00, 0x00, 0x00, // nreloc = 0
    0x00, 0x00, 0x00, 0x80, // flags = S_ATTR_PURE_INSTRUCTIONS
    0x00, 0x00, 0x00, 0x00, // reserved1
    0x00, 0x00, 0x00, 0x00, // reserved2
    0x00, 0x00, 0x00, 0x00, // reserved3

    // LC_MAIN (16 bytes)
    0x28, 0x00, 0x00, 0x80, // cmd = LC_MAIN
    0x10, 0x00, 0x00, 0x00, // cmdsize = 16
    0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // entryoff = 200

    // Code at offset 200 (4 bytes)
    0xB8, 0x01, 0x00, 0x00, // mov eax, 1
};

test "detect Mach-O format" {
    const macho_data = [_]u8{ 0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01 };
    try std.testing.expectEqual(BinaryFormat.macho64, detectFormat(&macho_data));
}

test "load minimal Mach-O 64" {
    var binary = try loadMachO64(std.testing.allocator, &TEST_MACHO64);
    defer binary.deinit();

    try std.testing.expectEqual(BinaryFormat.macho64, binary.format);
    try std.testing.expectEqual(Architecture.x86_64, binary.architecture);
    try std.testing.expectEqual(@as(u64, 200), binary.entry_point);
}

test "Mach-O section parsing" {
    var binary = try loadMachO64(std.testing.allocator, &TEST_MACHO64);
    defer binary.deinit();

    // Should have __TEXT segment + __text section
    try std.testing.expect(binary.sections.items.len >= 2);

    // Find __text section
    var found_text = false;
    for (binary.sections.items) |section| {
        if (std.mem.eql(u8, section.name, "__text")) {
            found_text = true;
            try std.testing.expect(section.is_executable);
            try std.testing.expectEqual(@as(u64, 0x1000), section.virtual_address);
        }
    }
    try std.testing.expect(found_text);
}
