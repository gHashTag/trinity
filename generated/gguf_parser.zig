// GGUF PARSER — TRINITY FORMAT BRIDGE
// Read pre-quantized models from llama.cpp ecosystem
// Generated from specs/tri/gguf_reader.vibee
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const GGUF_MAGIC: u32 = 0x46554747; // "GGUF" little-endian
pub const GGUF_VERSION: u32 = 3;
pub const DEFAULT_ALIGNMENT: u32 = 32;
pub const MAX_TENSOR_NAME_LEN: usize = 64;
pub const MAX_DIMS: usize = 4;
pub const MAX_TENSORS: usize = 512;
pub const MAX_METADATA: usize = 256;
pub const MAX_STRING_LEN: usize = 256;

// ═══════════════════════════════════════════════════════════════════════════════
// GGUF VALUE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const GGUFValueType = enum(u32) {
    UINT8 = 0,
    INT8 = 1,
    UINT16 = 2,
    INT16 = 3,
    UINT32 = 4,
    INT32 = 5,
    FLOAT32 = 6,
    BOOL = 7,
    STRING = 8,
    ARRAY = 9,
    UINT64 = 10,
    INT64 = 11,
    FLOAT64 = 12,
    _,
};

// ═══════════════════════════════════════════════════════════════════════════════
// GGML TENSOR TYPES (quantization formats)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GGMLType = enum(u32) {
    F32 = 0,
    F16 = 1,
    Q4_0 = 2,
    Q4_1 = 3,
    Q5_0 = 6,
    Q5_1 = 7,
    Q8_0 = 8,
    Q8_1 = 9,
    Q2_K = 10,
    Q3_K = 11,
    Q4_K = 12,
    Q5_K = 13,
    Q6_K = 14,
    Q8_K = 15,
    IQ2_XXS = 16,
    IQ2_XS = 17,
    IQ3_XXS = 18,
    IQ1_S = 19,
    IQ4_NL = 20,
    IQ3_S = 21,
    IQ2_S = 22,
    IQ4_XS = 23,
    I8 = 24,
    I16 = 25,
    I32 = 26,
    I64 = 27,
    F64 = 28,
    BF16 = 30,
    TQ1_0 = 34, // Ternary {-1, 0, +1} packed
    TQ2_0 = 35, // Ternary with scale
    _,
};

/// Block size for each quantization type
pub fn getBlockSize(t: GGMLType) usize {
    return switch (t) {
        .F32 => 1,
        .F16, .BF16 => 1,
        .Q4_0, .Q4_1, .Q5_0, .Q5_1, .Q8_0, .Q8_1 => 32,
        .Q2_K, .Q3_K, .Q4_K, .Q5_K, .Q6_K, .Q8_K => 256,
        .TQ1_0, .TQ2_0 => 32,
        else => 1,
    };
}

/// Byte size per block for quantization type
pub fn getTypeSize(t: GGMLType) usize {
    return switch (t) {
        .F32 => 4,
        .F16, .BF16 => 2,
        .F64 => 8,
        .Q4_0 => 18, // 2 scale + 16 data (32*4/8)
        .Q4_1 => 20, // 2 scale + 2 min + 16 data
        .Q5_0 => 22,
        .Q5_1 => 24,
        .Q8_0 => 34, // 2 scale + 32 data
        .Q8_1 => 36,
        .Q4_K => 144,
        .Q5_K => 176,
        .Q6_K => 210,
        .TQ1_0 => 8, // 32 trits * 2 bits / 8 = 8 bytes
        .TQ2_0 => 10, // 8 + 2 byte scale
        .I8 => 1,
        .I16 => 2,
        .I32 => 4,
        .I64 => 8,
        else => 0,
    };
}

/// Calculate total bytes for tensor data
pub fn tensorBytes(t: GGMLType, num_elements: u64) u64 {
    const bs = getBlockSize(t);
    const ts = getTypeSize(t);
    if (bs == 0 or ts == 0) return 0;
    const num_blocks = (num_elements + bs - 1) / bs;
    return num_blocks * ts;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GGUF HEADER
// ═══════════════════════════════════════════════════════════════════════════════

pub const GGUFHeader = struct {
    magic: u32,
    version: u32,
    tensor_count: u64,
    metadata_kv_count: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// METADATA VALUE
// ═══════════════════════════════════════════════════════════════════════════════

pub const MetadataValue = union(enum) {
    uint8_val: u8,
    int8_val: i8,
    uint16_val: u16,
    int16_val: i16,
    uint32_val: u32,
    int32_val: i32,
    float32_val: f32,
    bool_val: bool,
    string_val: [MAX_STRING_LEN]u8,
    uint64_val: u64,
    int64_val: i64,
    float64_val: f64,
    array_val: ArrayMeta,

    pub const ArrayMeta = struct {
        elem_type: u32, // GGUFValueType
        count: u64,
        // Array elements not stored inline — too variable
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// METADATA KEY-VALUE ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const MetadataKV = struct {
    key_buf: [MAX_STRING_LEN]u8 = .{0} ** MAX_STRING_LEN,
    key_len: usize = 0,
    value_type: GGUFValueType = @enumFromInt(0),
    value: MetadataValue = .{ .uint32_val = 0 },
    string_len: usize = 0, // For string values: actual length

    pub fn key(self: *const MetadataKV) []const u8 {
        return self.key_buf[0..self.key_len];
    }

    pub fn getU32(self: *const MetadataKV) ?u32 {
        return switch (self.value) {
            .uint32_val => |v| v,
            .int32_val => |v| if (v >= 0) @intCast(v) else null,
            .uint64_val => |v| if (v <= std.math.maxInt(u32)) @intCast(v) else null,
            else => null,
        };
    }

    pub fn getU64(self: *const MetadataKV) ?u64 {
        return switch (self.value) {
            .uint64_val => |v| v,
            .uint32_val => |v| @intCast(v),
            .int64_val => |v| if (v >= 0) @intCast(v) else null,
            else => null,
        };
    }

    pub fn getF32(self: *const MetadataKV) ?f32 {
        return switch (self.value) {
            .float32_val => |v| v,
            .float64_val => |v| @floatCast(v),
            else => null,
        };
    }

    pub fn getString(self: *const MetadataKV) ?[]const u8 {
        return switch (self.value) {
            .string_val => self.key_buf[0..0], // Placeholder — use string_buf
            else => null,
        };
    }

    pub fn getStringValue(self: *const MetadataKV) ?[]const u8 {
        if (self.value_type != .STRING) return null;
        const sv = self.value.string_val;
        return sv[0..self.string_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const TensorInfo = struct {
    name_buf: [MAX_TENSOR_NAME_LEN]u8 = .{0} ** MAX_TENSOR_NAME_LEN,
    name_len: usize = 0,
    n_dims: u32 = 0,
    dims: [MAX_DIMS]u64 = .{0} ** MAX_DIMS,
    tensor_type: GGMLType = .F32,
    offset: u64 = 0, // Offset within tensor data section

    pub fn name(self: *const TensorInfo) []const u8 {
        return self.name_buf[0..self.name_len];
    }

    pub fn numElements(self: *const TensorInfo) u64 {
        if (self.n_dims == 0) return 0;
        var total: u64 = 1;
        for (0..self.n_dims) |i| {
            total *= self.dims[i];
        }
        return total;
    }

    pub fn dataBytes(self: *const TensorInfo) u64 {
        return tensorBytes(self.tensor_type, self.numElements());
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL CONFIG (extracted from metadata)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModelConfig = struct {
    arch_buf: [64]u8 = .{0} ** 64,
    arch_len: usize = 0,
    name_buf: [128]u8 = .{0} ** 128,
    name_len: usize = 0,
    vocab_size: u32 = 0,
    hidden_size: u32 = 0,
    intermediate_size: u32 = 0,
    num_layers: u32 = 0,
    num_heads: u32 = 0,
    num_kv_heads: u32 = 0,
    context_length: u32 = 0,
    head_dim: u32 = 0,
    rope_theta: f32 = 10000.0,
    rms_norm_eps: f32 = 1e-5,

    pub fn arch(self: *const ModelConfig) []const u8 {
        return self.arch_buf[0..self.arch_len];
    }

    pub fn modelName(self: *const ModelConfig) []const u8 {
        return self.name_buf[0..self.name_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GGUF FILE (parsed result)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GGUFFile = struct {
    header: GGUFHeader = .{ .magic = 0, .version = 0, .tensor_count = 0, .metadata_kv_count = 0 },
    metadata: [MAX_METADATA]MetadataKV = undefined,
    metadata_count: usize = 0,
    tensors: [MAX_TENSORS]TensorInfo = undefined,
    tensor_count: usize = 0,
    alignment: u32 = DEFAULT_ALIGNMENT,
    data_offset: u64 = 0, // Offset to tensor data section
    config: ModelConfig = .{},

    /// Find metadata by key
    pub fn findMetadata(self: *const GGUFFile, target_key: []const u8) ?*const MetadataKV {
        for (0..self.metadata_count) |i| {
            if (std.mem.eql(u8, self.metadata[i].key(), target_key)) {
                return &self.metadata[i];
            }
        }
        return null;
    }

    /// Find tensor by name
    pub fn findTensor(self: *const GGUFFile, target_name: []const u8) ?*const TensorInfo {
        for (0..self.tensor_count) |i| {
            if (std.mem.eql(u8, self.tensors[i].name(), target_name)) {
                return &self.tensors[i];
            }
        }
        return null;
    }

    /// Get total model size in bytes
    pub fn totalModelBytes(self: *const GGUFFile) u64 {
        var total: u64 = 0;
        for (0..self.tensor_count) |i| {
            total += self.tensors[i].dataBytes();
        }
        return total;
    }

    /// Count tensors of each type
    pub fn tensorTypeCounts(self: *const GGUFFile) [64]u32 {
        var counts: [64]u32 = .{0} ** 64;
        for (0..self.tensor_count) |i| {
            const idx: usize = @intFromEnum(self.tensors[i].tensor_type);
            if (idx < 64) counts[idx] += 1;
        }
        return counts;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BYTE READER (in-memory parsing from buffer)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ByteReader = struct {
    data: []const u8,
    pos: usize,

    pub fn init(data: []const u8) ByteReader {
        return .{ .data = data, .pos = 0 };
    }

    pub fn remaining(self: *const ByteReader) usize {
        if (self.pos >= self.data.len) return 0;
        return self.data.len - self.pos;
    }

    pub fn readU8(self: *ByteReader) !u8 {
        if (self.remaining() < 1) return error.UnexpectedEof;
        const v = self.data[self.pos];
        self.pos += 1;
        return v;
    }

    pub fn readU16(self: *ByteReader) !u16 {
        if (self.remaining() < 2) return error.UnexpectedEof;
        const v = std.mem.readInt(u16, self.data[self.pos..][0..2], .little);
        self.pos += 2;
        return v;
    }

    pub fn readU32(self: *ByteReader) !u32 {
        if (self.remaining() < 4) return error.UnexpectedEof;
        const v = std.mem.readInt(u32, self.data[self.pos..][0..4], .little);
        self.pos += 4;
        return v;
    }

    pub fn readI32(self: *ByteReader) !i32 {
        if (self.remaining() < 4) return error.UnexpectedEof;
        const v = std.mem.readInt(i32, self.data[self.pos..][0..4], .little);
        self.pos += 4;
        return v;
    }

    pub fn readU64(self: *ByteReader) !u64 {
        if (self.remaining() < 8) return error.UnexpectedEof;
        const v = std.mem.readInt(u64, self.data[self.pos..][0..8], .little);
        self.pos += 8;
        return v;
    }

    pub fn readI64(self: *ByteReader) !i64 {
        if (self.remaining() < 8) return error.UnexpectedEof;
        const v = std.mem.readInt(i64, self.data[self.pos..][0..8], .little);
        self.pos += 8;
        return v;
    }

    pub fn readF32(self: *ByteReader) !f32 {
        if (self.remaining() < 4) return error.UnexpectedEof;
        const bits = std.mem.readInt(u32, self.data[self.pos..][0..4], .little);
        self.pos += 4;
        return @bitCast(bits);
    }

    pub fn readF64(self: *ByteReader) !f64 {
        if (self.remaining() < 8) return error.UnexpectedEof;
        const bits = std.mem.readInt(u64, self.data[self.pos..][0..8], .little);
        self.pos += 8;
        return @bitCast(bits);
    }

    pub fn readBytes(self: *ByteReader, n: usize) ![]const u8 {
        if (self.remaining() < n) return error.UnexpectedEof;
        const slice = self.data[self.pos .. self.pos + n];
        self.pos += n;
        return slice;
    }

    /// Read GGUF string: u64 length + bytes (NOT null-terminated)
    pub fn readGGUFString(self: *ByteReader, buf: []u8) !usize {
        const len = try self.readU64();
        if (len > buf.len) return error.StringTooLong;
        if (self.remaining() < len) return error.UnexpectedEof;
        const actual_len: usize = @intCast(len);
        @memcpy(buf[0..actual_len], self.data[self.pos .. self.pos + actual_len]);
        self.pos += actual_len;
        return actual_len;
    }

    /// Align position to boundary
    pub fn alignTo(self: *ByteReader, alignment: u32) void {
        const a: usize = @intCast(alignment);
        if (a <= 1) return;
        const remainder = self.pos % a;
        if (remainder != 0) {
            self.pos += a - remainder;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse GGUF header from buffer
pub fn parseHeader(reader: *ByteReader) !GGUFHeader {
    const magic = try reader.readU32();
    if (magic != GGUF_MAGIC) return error.InvalidMagic;
    const version = try reader.readU32();
    if (version < 2 or version > 3) return error.UnsupportedVersion;
    const tensor_count = try reader.readU64();
    const metadata_kv_count = try reader.readU64();
    return GGUFHeader{
        .magic = magic,
        .version = version,
        .tensor_count = tensor_count,
        .metadata_kv_count = metadata_kv_count,
    };
}

/// Parse a single metadata value
pub fn parseMetadataValue(reader: *ByteReader, value_type: GGUFValueType) !MetadataValue {
    return switch (value_type) {
        .UINT8 => .{ .uint8_val = try reader.readU8() },
        .INT8 => .{ .int8_val = @bitCast(try reader.readU8()) },
        .UINT16 => .{ .uint16_val = try reader.readU16() },
        .INT16 => .{ .int16_val = @bitCast(try reader.readU16()) },
        .UINT32 => .{ .uint32_val = try reader.readU32() },
        .INT32 => .{ .int32_val = try reader.readI32() },
        .FLOAT32 => .{ .float32_val = try reader.readF32() },
        .BOOL => .{ .bool_val = (try reader.readU8()) != 0 },
        .STRING => blk: {
            var sv: [MAX_STRING_LEN]u8 = .{0} ** MAX_STRING_LEN;
            _ = try reader.readGGUFString(&sv);
            break :blk .{ .string_val = sv };
        },
        .ARRAY => blk: {
            const elem_type = try reader.readU32();
            const count = try reader.readU64();
            // Skip array elements — we record metadata only
            const et: GGUFValueType = @enumFromInt(elem_type);
            for (0..@as(usize, @intCast(count))) |_| {
                _ = try skipMetadataValue(reader, et);
            }
            break :blk .{ .array_val = .{ .elem_type = elem_type, .count = count } };
        },
        .UINT64 => .{ .uint64_val = try reader.readU64() },
        .INT64 => .{ .int64_val = try reader.readI64() },
        .FLOAT64 => .{ .float64_val = try reader.readF64() },
        _ => error.UnsupportedValueType,
    };
}

/// Skip a metadata value (advance reader position without storing)
fn skipMetadataValue(reader: *ByteReader, value_type: GGUFValueType) !void {
    switch (value_type) {
        .UINT8, .INT8, .BOOL => _ = try reader.readU8(),
        .UINT16, .INT16 => _ = try reader.readU16(),
        .UINT32, .INT32, .FLOAT32 => _ = try reader.readU32(),
        .UINT64, .INT64, .FLOAT64 => _ = try reader.readU64(),
        .STRING => {
            const len = try reader.readU64();
            _ = try reader.readBytes(@intCast(len));
        },
        .ARRAY => {
            const elem_type = try reader.readU32();
            const count = try reader.readU64();
            const et: GGUFValueType = @enumFromInt(elem_type);
            for (0..@as(usize, @intCast(count))) |_| {
                try skipMetadataValue(reader, et);
            }
        },
        _ => return error.UnsupportedValueType,
    }
}

/// Parse a single metadata key-value pair
pub fn parseMetadataKV(reader: *ByteReader) !MetadataKV {
    var kv = MetadataKV{};
    kv.key_len = try reader.readGGUFString(&kv.key_buf);
    const vtype_raw = try reader.readU32();
    kv.value_type = @enumFromInt(vtype_raw);

    // For STRING values, read into string_val and track length
    if (kv.value_type == .STRING) {
        const len = try reader.readU64();
        const actual_len: usize = @intCast(len);
        if (actual_len > MAX_STRING_LEN) return error.StringTooLong;
        if (reader.remaining() < actual_len) return error.UnexpectedEof;
        var sv: [MAX_STRING_LEN]u8 = .{0} ** MAX_STRING_LEN;
        @memcpy(sv[0..actual_len], reader.data[reader.pos .. reader.pos + actual_len]);
        reader.pos += actual_len;
        kv.value = .{ .string_val = sv };
        kv.string_len = actual_len;
    } else {
        kv.value = try parseMetadataValue(reader, kv.value_type);
    }
    return kv;
}

/// Parse tensor info entry
pub fn parseTensorInfo(reader: *ByteReader) !TensorInfo {
    var ti = TensorInfo{};
    ti.name_len = try reader.readGGUFString(&ti.name_buf);
    ti.n_dims = try reader.readU32();
    if (ti.n_dims > MAX_DIMS) return error.TooManyDimensions;
    for (0..ti.n_dims) |i| {
        ti.dims[i] = try reader.readU64();
    }
    const type_raw = try reader.readU32();
    ti.tensor_type = @enumFromInt(type_raw);
    ti.offset = try reader.readU64();
    return ti;
}

/// Parse complete GGUF file from buffer
pub fn parseGGUF(data: []const u8) !GGUFFile {
    var reader = ByteReader.init(data);
    var file = GGUFFile{};

    // 1. Parse header
    file.header = try parseHeader(&reader);

    // 2. Parse metadata
    const md_count: usize = @intCast(file.header.metadata_kv_count);
    if (md_count > MAX_METADATA) return error.TooManyMetadata;
    for (0..md_count) |i| {
        file.metadata[i] = try parseMetadataKV(&reader);
        file.metadata_count += 1;
    }

    // 3. Check for alignment override in metadata
    if (file.findMetadata("general.alignment")) |align_kv| {
        if (align_kv.getU32()) |v| {
            file.alignment = v;
        }
    }

    // 4. Parse tensor info
    const t_count: usize = @intCast(file.header.tensor_count);
    if (t_count > MAX_TENSORS) return error.TooManyTensors;
    for (0..t_count) |i| {
        file.tensors[i] = try parseTensorInfo(&reader);
        file.tensor_count += 1;
    }

    // 5. Align to tensor data start
    reader.alignTo(file.alignment);
    file.data_offset = reader.pos;

    // 6. Extract model config from metadata
    file.config = extractModelConfig(&file);

    return file;
}

/// Extract model config from parsed metadata
pub fn extractModelConfig(file: *const GGUFFile) ModelConfig {
    var config = ModelConfig{};

    // Architecture
    if (file.findMetadata("general.architecture")) |kv| {
        if (kv.getStringValue()) |s| {
            const len = @min(s.len, config.arch_buf.len);
            @memcpy(config.arch_buf[0..len], s[0..len]);
            config.arch_len = len;
        }
    }

    // Model name
    if (file.findMetadata("general.name")) |kv| {
        if (kv.getStringValue()) |s| {
            const len = @min(s.len, config.name_buf.len);
            @memcpy(config.name_buf[0..len], s[0..len]);
            config.name_len = len;
        }
    }

    // Get arch prefix for keyed lookups
    const arch_prefix = config.arch();

    // Architecture-specific keys
    config.vocab_size = findArchU32(file, arch_prefix, "vocab_size") orelse 0;
    config.hidden_size = findArchU32(file, arch_prefix, "embedding_length") orelse 0;
    config.intermediate_size = findArchU32(file, arch_prefix, "feed_forward_length") orelse 0;
    config.num_layers = findArchU32(file, arch_prefix, "block_count") orelse 0;
    config.num_heads = findArchU32(file, arch_prefix, "attention.head_count") orelse 0;
    config.num_kv_heads = findArchU32(file, arch_prefix, "attention.head_count_kv") orelse config.num_heads;
    config.context_length = findArchU32(file, arch_prefix, "context_length") orelse 2048;

    // Head dim
    if (config.hidden_size > 0 and config.num_heads > 0) {
        config.head_dim = config.hidden_size / config.num_heads;
    }

    // Float parameters
    if (findArchF32(file, arch_prefix, "rope.freq_base")) |v| {
        config.rope_theta = v;
    }
    if (findArchF32(file, arch_prefix, "attention.layer_norm_rms_epsilon")) |v| {
        config.rms_norm_eps = v;
    }

    return config;
}

/// Find u32 metadata with arch prefix: "{arch}.{suffix}"
fn findArchU32(file: *const GGUFFile, arch: []const u8, suffix: []const u8) ?u32 {
    var key_buf: [128]u8 = undefined;
    if (arch.len + 1 + suffix.len > key_buf.len) return null;
    @memcpy(key_buf[0..arch.len], arch);
    key_buf[arch.len] = 0x2E;
    @memcpy(key_buf[arch.len + 1 ..][0..suffix.len], suffix);
    const full_key = key_buf[0 .. arch.len + 1 + suffix.len];
    if (file.findMetadata(full_key)) |kv| {
        return kv.getU32();
    }
    return null;
}

/// Find f32 metadata with arch prefix
fn findArchF32(file: *const GGUFFile, arch: []const u8, suffix: []const u8) ?f32 {
    var key_buf: [128]u8 = undefined;
    if (arch.len + 1 + suffix.len > key_buf.len) return null;
    @memcpy(key_buf[0..arch.len], arch);
    key_buf[arch.len] = 0x2E;
    @memcpy(key_buf[arch.len + 1 ..][0..suffix.len], suffix);
    const full_key = key_buf[0 .. arch.len + 1 + suffix.len];
    if (file.findMetadata(full_key)) |kv| {
        return kv.getF32();
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEQUANTIZATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f16 (IEEE 754 half-precision) to f32
pub fn f16ToF32(h: u16) f32 {
    const sign: u32 = @as(u32, h >> 15) << 31;
    const exponent: u32 = (h >> 10) & 0x1F;
    const mantissa: u32 = h & 0x3FF;

    if (exponent == 0) {
        // Subnormal or zero
        if (mantissa == 0) return @bitCast(sign); // +/- 0
        // Subnormal: convert to normalized f32
        var m = mantissa;
        var e: u32 = 127 - 14;
        while (m & 0x400 == 0) {
            m <<= 1;
            e -= 1;
        }
        m &= 0x3FF;
        return @bitCast(sign | (e << 23) | (m << 13));
    } else if (exponent == 31) {
        // Inf or NaN
        return @bitCast(sign | (0xFF << 23) | (mantissa << 13));
    }

    // Normal number
    const f32_exp: u32 = exponent + (127 - 15);
    return @bitCast(sign | (f32_exp << 23) | (mantissa << 13));
}

/// Dequantize Q4_0 block: scale(f16) + 32 x 4-bit values
/// Block layout: [scale: f16(2 bytes)][16 bytes = 32 x 4-bit quants]
pub fn dequantizeQ4_0(block_data: []const u8, output: []f32) void {
    if (block_data.len < 18 or output.len < 32) return;
    const scale_bits = std.mem.readInt(u16, block_data[0..2], .little);
    const scale = f16ToF32(scale_bits);

    for (0..32) |i| {
        const byte_idx = 2 + i / 2;
        const raw: u8 = if (i % 2 == 0)
            block_data[byte_idx] & 0x0F
        else
            block_data[byte_idx] >> 4;
        // Q4_0: values are unsigned 0-15, center at 8
        const val: f32 = @as(f32, @floatFromInt(@as(i8, @intCast(raw)))) - 8.0;
        output[i] = val * scale;
    }
}

/// Dequantize Q8_0 block: scale(f16) + 32 x int8 values
/// Block layout: [scale: f16(2 bytes)][32 bytes = 32 x int8 quants]
pub fn dequantizeQ8_0(block_data: []const u8, output: []f32) void {
    if (block_data.len < 34 or output.len < 32) return;
    const scale_bits = std.mem.readInt(u16, block_data[0..2], .little);
    const scale = f16ToF32(scale_bits);

    for (0..32) |i| {
        const quant: i8 = @bitCast(block_data[2 + i]);
        output[i] = @as(f32, @floatFromInt(quant)) * scale;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GGUF BUILDER (for testing — construct valid GGUF buffers in memory)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GGUFBuilder = struct {
    buf: [8192]u8 = .{0} ** 8192,
    len: usize = 0,

    pub fn init() GGUFBuilder {
        return .{};
    }

    fn writeBytes(self: *GGUFBuilder, bytes: []const u8) void {
        if (self.len + bytes.len > self.buf.len) return;
        @memcpy(self.buf[self.len..][0..bytes.len], bytes);
        self.len += bytes.len;
    }

    fn writeU32(self: *GGUFBuilder, v: u32) void {
        var tmp: [4]u8 = undefined;
        std.mem.writeInt(u32, &tmp, v, .little);
        self.writeBytes(&tmp);
    }

    fn writeU64(self: *GGUFBuilder, v: u64) void {
        var tmp: [8]u8 = undefined;
        std.mem.writeInt(u64, &tmp, v, .little);
        self.writeBytes(&tmp);
    }

    fn writeI32(self: *GGUFBuilder, v: i32) void {
        var tmp: [4]u8 = undefined;
        std.mem.writeInt(i32, &tmp, v, .little);
        self.writeBytes(&tmp);
    }

    fn writeF32(self: *GGUFBuilder, v: f32) void {
        const bits: u32 = @bitCast(v);
        self.writeU32(bits);
    }

    fn writeGGUFString(self: *GGUFBuilder, s: []const u8) void {
        self.writeU64(s.len);
        self.writeBytes(s);
    }

    /// Write GGUF header
    pub fn writeHeader(self: *GGUFBuilder, tensor_count: u64, metadata_count: u64) void {
        self.writeU32(GGUF_MAGIC);
        self.writeU32(GGUF_VERSION);
        self.writeU64(tensor_count);
        self.writeU64(metadata_count);
    }

    /// Write metadata KV: string key
    pub fn writeMetadataString(self: *GGUFBuilder, key: []const u8, value: []const u8) void {
        self.writeGGUFString(key);
        self.writeU32(@intFromEnum(GGUFValueType.STRING));
        self.writeGGUFString(value);
    }

    /// Write metadata KV: u32
    pub fn writeMetadataU32(self: *GGUFBuilder, key: []const u8, value: u32) void {
        self.writeGGUFString(key);
        self.writeU32(@intFromEnum(GGUFValueType.UINT32));
        self.writeU32(value);
    }

    /// Write metadata KV: f32
    pub fn writeMetadataF32(self: *GGUFBuilder, key: []const u8, value: f32) void {
        self.writeGGUFString(key);
        self.writeU32(@intFromEnum(GGUFValueType.FLOAT32));
        self.writeF32(value);
    }

    /// Write tensor info
    pub fn writeTensorInfo(self: *GGUFBuilder, name: []const u8, dims: []const u64, tensor_type: GGMLType, offset: u64) void {
        self.writeGGUFString(name);
        self.writeU32(@intCast(dims.len));
        for (dims) |d| {
            self.writeU64(d);
        }
        self.writeU32(@intFromEnum(tensor_type));
        self.writeU64(offset);
    }

    /// Align to boundary
    pub fn alignTo(self: *GGUFBuilder, alignment: u32) void {
        const a: usize = @intCast(alignment);
        if (a <= 1) return;
        const remainder = self.len % a;
        if (remainder != 0) {
            const padding = a - remainder;
            for (0..padding) |_| {
                if (self.len < self.buf.len) {
                    self.buf[self.len] = 0;
                    self.len += 1;
                }
            }
        }
    }

    pub fn data(self: *const GGUFBuilder) []const u8 {
        return self.buf[0..self.len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GGUF magic constant" {
    try std.testing.expectEqual(GGUF_MAGIC, 0x46554747);
    // "GGUF" in ASCII: G=0x47, G=0x47, U=0x55, F=0x46
    // Little-endian u32: first byte = 0x47 (LSB)
    const bytes = std.mem.toBytes(GGUF_MAGIC);
    try std.testing.expectEqual(bytes[0], 0x47); // G
    try std.testing.expectEqual(bytes[1], 0x47); // G
    try std.testing.expectEqual(bytes[2], 0x55); // U
    try std.testing.expectEqual(bytes[3], 0x46); // F
}

test "GGMLType block and type sizes" {
    try std.testing.expectEqual(getBlockSize(.F32), 1);
    try std.testing.expectEqual(getTypeSize(.F32), 4);
    try std.testing.expectEqual(getBlockSize(.F16), 1);
    try std.testing.expectEqual(getTypeSize(.F16), 2);
    try std.testing.expectEqual(getBlockSize(.Q4_0), 32);
    try std.testing.expectEqual(getTypeSize(.Q4_0), 18);
    try std.testing.expectEqual(getBlockSize(.Q8_0), 32);
    try std.testing.expectEqual(getTypeSize(.Q8_0), 34);
    try std.testing.expectEqual(getBlockSize(.Q4_K), 256);
    try std.testing.expectEqual(getTypeSize(.Q4_K), 144);
    try std.testing.expectEqual(getBlockSize(.TQ1_0), 32);
    try std.testing.expectEqual(getTypeSize(.TQ1_0), 8);
}

test "tensorBytes calculation" {
    // F32: 1000 elements * 4 bytes = 4000
    try std.testing.expectEqual(tensorBytes(.F32, 1000), 4000);
    // Q4_0: 1000 elements, 32 per block = ceil(1000/32)=32 blocks * 18 bytes = 576
    try std.testing.expectEqual(tensorBytes(.Q4_0, 1000), 576);
    // Q8_0: 1024 elements, 32 per block = 32 blocks * 34 = 1088
    try std.testing.expectEqual(tensorBytes(.Q8_0, 1024), 1088);
    // TQ1_0 (ternary): 1024 elements, 32 per block = 32 blocks * 8 = 256
    try std.testing.expectEqual(tensorBytes(.TQ1_0, 1024), 256);
}

test "ByteReader primitives" {
    var tmp: [32]u8 = .{0} ** 32;
    std.mem.writeInt(u32, tmp[0..4], 42, .little);
    std.mem.writeInt(u64, tmp[4..12], 9999, .little);
    std.mem.writeInt(i32, tmp[12..16], -7, .little);

    var reader = ByteReader.init(&tmp);
    try std.testing.expectEqual(try reader.readU32(), 42);
    try std.testing.expectEqual(try reader.readU64(), 9999);
    try std.testing.expectEqual(try reader.readI32(), -7);
    try std.testing.expectEqual(reader.pos, 16);
}

test "ByteReader GGUF string" {
    // GGUF string = u64 length + bytes
    var tmp: [32]u8 = .{0} ** 32;
    std.mem.writeInt(u64, tmp[0..8], 5, .little); // length = 5
    @memcpy(tmp[8..13], "hello");

    var reader = ByteReader.init(&tmp);
    var buf: [64]u8 = undefined;
    const len = try reader.readGGUFString(&buf);
    try std.testing.expectEqual(len, 5);
    try std.testing.expectEqualStrings("hello", buf[0..len]);
}

test "ByteReader alignment" {
    const tmp: [64]u8 = .{0} ** 64;
    var reader = ByteReader.init(&tmp);
    reader.pos = 5;
    reader.alignTo(32);
    try std.testing.expectEqual(reader.pos, 32);

    reader.pos = 32;
    reader.alignTo(32);
    try std.testing.expectEqual(reader.pos, 32); // Already aligned
}

test "parseHeader valid" {
    var builder = GGUFBuilder.init();
    builder.writeHeader(10, 3);

    var reader = ByteReader.init(builder.data());
    const header = try parseHeader(&reader);
    try std.testing.expectEqual(header.magic, GGUF_MAGIC);
    try std.testing.expectEqual(header.version, GGUF_VERSION);
    try std.testing.expectEqual(header.tensor_count, 10);
    try std.testing.expectEqual(header.metadata_kv_count, 3);
}

test "parseHeader invalid magic" {
    var tmp: [24]u8 = .{0} ** 24;
    std.mem.writeInt(u32, tmp[0..4], 0xDEADBEEF, .little); // bad magic

    var reader = ByteReader.init(&tmp);
    const result = parseHeader(&reader);
    try std.testing.expectError(error.InvalidMagic, result);
}

test "parse metadata KV — u32" {
    var builder = GGUFBuilder.init();
    builder.writeMetadataU32("llama.vocab_size", 32000);

    var reader = ByteReader.init(builder.data());
    const kv = try parseMetadataKV(&reader);
    try std.testing.expectEqualStrings("llama.vocab_size", kv.key());
    try std.testing.expectEqual(kv.value_type, .UINT32);
    try std.testing.expectEqual(kv.getU32().?, 32000);
}

test "parse metadata KV — string" {
    var builder = GGUFBuilder.init();
    builder.writeMetadataString("general.architecture", "llama");

    var reader = ByteReader.init(builder.data());
    const kv = try parseMetadataKV(&reader);
    try std.testing.expectEqualStrings("general.architecture", kv.key());
    try std.testing.expectEqual(kv.value_type, .STRING);
    try std.testing.expectEqualStrings("llama", kv.getStringValue().?);
}

test "parse metadata KV — f32" {
    var builder = GGUFBuilder.init();
    builder.writeMetadataF32("llama.rope.freq_base", 10000.0);

    var reader = ByteReader.init(builder.data());
    const kv = try parseMetadataKV(&reader);
    try std.testing.expectEqualStrings("llama.rope.freq_base", kv.key());
    try std.testing.expectEqual(kv.value_type, .FLOAT32);
    try std.testing.expectApproxEqAbs(kv.getF32().?, 10000.0, 0.01);
}

test "parseTensorInfo" {
    var builder = GGUFBuilder.init();
    const dims = [_]u64{ 4096, 4096 };
    builder.writeTensorInfo("blk.0.attn.wq.weight", &dims, .Q4_0, 0);

    var reader = ByteReader.init(builder.data());
    const ti = try parseTensorInfo(&reader);
    try std.testing.expectEqualStrings("blk.0.attn.wq.weight", ti.name());
    try std.testing.expectEqual(ti.n_dims, 2);
    try std.testing.expectEqual(ti.dims[0], 4096);
    try std.testing.expectEqual(ti.dims[1], 4096);
    try std.testing.expectEqual(ti.tensor_type, .Q4_0);
    try std.testing.expectEqual(ti.numElements(), 4096 * 4096);
}

test "TensorInfo dataBytes" {
    var ti = TensorInfo{};
    ti.n_dims = 2;
    ti.dims[0] = 4096;
    ti.dims[1] = 4096;
    ti.tensor_type = .Q4_0;
    // 4096*4096 = 16M elements, block_size=32 => 524288 blocks * 18 = 9437184
    try std.testing.expectEqual(ti.dataBytes(), 9437184);

    ti.tensor_type = .F32;
    // 16M elements * 4 bytes = 64MB
    try std.testing.expectEqual(ti.dataBytes(), 67108864);

    ti.tensor_type = .TQ1_0;
    // 16M elements, 32 per block = 524288 blocks * 8 = 4194304
    try std.testing.expectEqual(ti.dataBytes(), 4194304);
}

test "parseGGUF complete file" {
    var builder = GGUFBuilder.init();
    // Header: 2 tensors, 4 metadata
    builder.writeHeader(2, 4);

    // Metadata
    builder.writeMetadataString("general.architecture", "llama");
    builder.writeMetadataString("general.name", "TinyLlama-1.1B");
    builder.writeMetadataU32("llama.vocab_size", 32000);
    builder.writeMetadataU32("llama.embedding_length", 2048);

    // Tensor info
    const dims1 = [_]u64{ 32000, 2048 };
    builder.writeTensorInfo("token_embd.weight", &dims1, .Q4_0, 0);
    const dims2 = [_]u64{ 2048, 2048 };
    builder.writeTensorInfo("blk.0.attn.wq.weight", &dims2, .Q8_0, 1024);

    // Align to data section
    builder.alignTo(DEFAULT_ALIGNMENT);

    const file = try parseGGUF(builder.data());
    try std.testing.expectEqual(file.header.tensor_count, 2);
    try std.testing.expectEqual(file.metadata_count, 4);
    try std.testing.expectEqual(file.tensor_count, 2);

    // Check metadata lookup
    const arch_kv = file.findMetadata("general.architecture").?;
    try std.testing.expectEqualStrings("llama", arch_kv.getStringValue().?);

    // Check tensor lookup
    const embd = file.findTensor("token_embd.weight").?;
    try std.testing.expectEqual(embd.tensor_type, .Q4_0);
    try std.testing.expectEqual(embd.numElements(), 32000 * 2048);

    // Check model config extraction
    try std.testing.expectEqualStrings("llama", file.config.arch());
    try std.testing.expectEqual(file.config.vocab_size, 32000);
    try std.testing.expectEqual(file.config.hidden_size, 2048);
}

test "f16 to f32 conversion" {
    // Test zero
    try std.testing.expectEqual(f16ToF32(0x0000), 0.0);
    // Test 1.0 (f16: sign=0, exp=15, mantissa=0 => 0x3C00)
    try std.testing.expectApproxEqAbs(f16ToF32(0x3C00), 1.0, 0.001);
    // Test -1.0 (sign=1, exp=15, mantissa=0 => 0xBC00)
    try std.testing.expectApproxEqAbs(f16ToF32(0xBC00), -1.0, 0.001);
    // Test 0.5 (f16: sign=0, exp=14, mantissa=0 => 0x3800)
    try std.testing.expectApproxEqAbs(f16ToF32(0x3800), 0.5, 0.001);
}

test "dequantize Q4_0" {
    // Build a Q4_0 block: scale(f16=1.0) + 16 bytes of quant data
    var block: [18]u8 = .{0} ** 18;
    // Scale = 1.0 in f16 = 0x3C00
    std.mem.writeInt(u16, block[0..2], 0x3C00, .little);
    // Quant data: each byte has 2 x 4-bit values
    // Set all to 0x88 => lower nibble=8 (val=0), upper nibble=8 (val=0)
    for (2..18) |i| {
        block[i] = 0x88; // Both nibbles = 8 => value = 0 after centering
    }

    var output: [32]f32 = undefined;
    dequantizeQ4_0(&block, &output);

    // All values should be (8 - 8) * 1.0 = 0.0
    for (0..32) |i| {
        try std.testing.expectApproxEqAbs(output[i], 0.0, 0.001);
    }

    // Now set first byte to 0x0F => lower=0x0F=15 (val=7), upper=0x00=0 (val=-8)
    block[2] = 0xF0;
    dequantizeQ4_0(&block, &output);
    // index 0: lower nibble of block[2] = 0x0 => (0-8)*1.0 = -8.0
    // index 1: upper nibble of block[2] = 0xF=15 => (15-8)*1.0 = 7.0
    try std.testing.expectApproxEqAbs(output[0], -8.0, 0.001);
    try std.testing.expectApproxEqAbs(output[1], 7.0, 0.001);
}

test "dequantize Q8_0" {
    // Build a Q8_0 block: scale(f16=0.5) + 32 int8 values
    var block: [34]u8 = .{0} ** 34;
    // Scale = 0.5 in f16 = 0x3800
    std.mem.writeInt(u16, block[0..2], 0x3800, .little);
    // Set quant values: alternating +1, -1
    for (0..32) |i| {
        if (i % 2 == 0) {
            block[2 + i] = @bitCast(@as(i8, 1));
        } else {
            block[2 + i] = @bitCast(@as(i8, -1));
        }
    }

    var output: [32]f32 = undefined;
    dequantizeQ8_0(&block, &output);

    // Even indices: 1 * 0.5 = 0.5
    // Odd indices: -1 * 0.5 = -0.5
    for (0..32) |i| {
        const expected: f32 = if (i % 2 == 0) 0.5 else -0.5;
        try std.testing.expectApproxEqAbs(output[i], expected, 0.001);
    }
}

test "GGUFFile tensor type counts" {
    var builder = GGUFBuilder.init();
    builder.writeHeader(3, 0);
    const dims = [_]u64{1024};
    builder.writeTensorInfo("t1", &dims, .Q4_0, 0);
    builder.writeTensorInfo("t2", &dims, .Q4_0, 100);
    builder.writeTensorInfo("t3", &dims, .Q8_0, 200);
    builder.alignTo(DEFAULT_ALIGNMENT);

    const file = try parseGGUF(builder.data());
    const counts = file.tensorTypeCounts();
    try std.testing.expectEqual(counts[@intFromEnum(GGMLType.Q4_0)], 2);
    try std.testing.expectEqual(counts[@intFromEnum(GGMLType.Q8_0)], 1);
    try std.testing.expectEqual(counts[@intFromEnum(GGMLType.F32)], 0);
}

test "GGUFFile total model bytes" {
    var builder = GGUFBuilder.init();
    builder.writeHeader(2, 0);
    const dims1 = [_]u64{1024};
    builder.writeTensorInfo("small", &dims1, .F32, 0);
    const dims2 = [_]u64{2048};
    builder.writeTensorInfo("big", &dims2, .Q4_0, 4096);
    builder.alignTo(DEFAULT_ALIGNMENT);

    const file = try parseGGUF(builder.data());
    // small: 1024 * 4 = 4096 bytes
    // big: ceil(2048/32) * 18 = 64 * 18 = 1152 bytes
    try std.testing.expectEqual(file.totalModelBytes(), 4096 + 1152);
}

test "model config extraction" {
    var builder = GGUFBuilder.init();
    builder.writeHeader(0, 7);
    builder.writeMetadataString("general.architecture", "llama");
    builder.writeMetadataString("general.name", "TestModel");
    builder.writeMetadataU32("llama.vocab_size", 32000);
    builder.writeMetadataU32("llama.embedding_length", 4096);
    builder.writeMetadataU32("llama.block_count", 32);
    builder.writeMetadataU32("llama.attention.head_count", 32);
    builder.writeMetadataU32("llama.context_length", 2048);
    builder.alignTo(DEFAULT_ALIGNMENT);

    const file = try parseGGUF(builder.data());
    try std.testing.expectEqualStrings("llama", file.config.arch());
    try std.testing.expectEqualStrings("TestModel", file.config.modelName());
    try std.testing.expectEqual(file.config.vocab_size, 32000);
    try std.testing.expectEqual(file.config.hidden_size, 4096);
    try std.testing.expectEqual(file.config.num_layers, 32);
    try std.testing.expectEqual(file.config.num_heads, 32);
    try std.testing.expectEqual(file.config.context_length, 2048);
    try std.testing.expectEqual(file.config.head_dim, 128); // 4096/32
}

// phi^2 + 1/phi^2 = 3 | TRINITY
