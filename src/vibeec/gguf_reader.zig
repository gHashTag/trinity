// GGUF READER - TRINITY FORMAT BRIDGE
// Read pre-quantized models from llama.cpp ecosystem
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// GGUF Constants
pub const GGUF_MAGIC: u32 = 0x46554747; // "GGUF" little-endian
pub const GGUF_VERSION: u32 = 3;
pub const DEFAULT_ALIGNMENT: u32 = 32;

// GGUF Value Types
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
};

// GGML Tensor Types
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
    // BitNet ternary types
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
    IQ1_M = 29,
    BF16 = 30,
    Q4_0_4_4 = 31,
    Q4_0_4_8 = 32,
    Q4_0_8_8 = 33,
    TQ1_0 = 34, // Ternary {-1, 0, +1} packed
    TQ2_0 = 35, // Ternary with scale
    I2_S = 36,  // BitNet 2-bit integer with scale (ternary: -1, 0, +1)
    I8_S = 37,
    TL1 = 38,   // BitNet TL1
    TL2 = 39,   // BitNet TL2
    _,
};

// Block sizes for quantization types
pub fn getBlockSize(t: GGMLType) usize {
    return switch (t) {
        .Q4_0, .Q4_1, .Q5_0, .Q5_1, .Q8_0, .Q8_1 => 32,
        .Q2_K, .Q3_K, .Q4_K, .Q5_K, .Q6_K, .Q8_K => 256,
        .TQ1_0, .TQ2_0 => 32, // BitNet ternary block size
        .I2_S, .TL1, .TL2 => 4, // 4 values per byte (2 bits each)
        else => 1,
    };
}

// Type size in bytes per block
pub fn getTypeSize(t: GGMLType) usize {
    return switch (t) {
        .F32 => 4,
        .F16, .BF16 => 2,
        .Q4_0 => 18,  // 2 + 32*4/8
        .Q4_1 => 20,  // 2 + 2 + 32*4/8
        .Q5_0 => 22,  // 2 + 4 + 32*5/8
        .Q5_1 => 24,  // 2 + 2 + 4 + 32*5/8
        .Q8_0 => 34,  // 2 + 32
        .Q8_1 => 36,  // 2 + 2 + 32
        .Q4_K => 144, // Complex
        .Q5_K => 176,
        .Q6_K => 210,
        // BitNet ternary: 32 trits * 2 bits / 8 = 8 bytes per block
        .TQ1_0 => 8,  // Pure ternary, no scale
        .TQ2_0 => 10, // Ternary with 2-byte scale
        // I2_S: 2-bit packed, 4 values per byte
        // Block size 4, type size 1 => 1 byte per 4 elements
        .I2_S => 1,
        .TL1 => 1,
        .TL2 => 1,
        .IQ2_S => 10,
        .IQ2_XXS => 8,
        .IQ3_S => 12,
        else => 0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET TERNARY OPERATIONS
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

/// Lookup table for 2-bit trit encoding: 00=0, 01=+1, 10=-1, 11=0 (unused)
pub const TRIT_LUT: [4]i8 = .{ 0, 1, -1, 0 };
pub const TRIT_LUT_F32: [4]f32 = .{ 0.0, 1.0, -1.0, 0.0 };

/// Pack array of trits {-1, 0, +1} into bytes (4 trits per byte)
pub fn packTrits(trits: []const i8, output: []u8) void {
    var byte_idx: usize = 0;
    var trit_idx: usize = 0;
    
    while (trit_idx < trits.len) {
        var byte: u8 = 0;
        var shift: u3 = 0;
        
        while (shift < 8 and trit_idx < trits.len) {
            const trit = trits[trit_idx];
            const encoded: u8 = switch (trit) {
                0 => 0b00,
                1 => 0b01,
                -1 => 0b10,
                else => 0b00,
            };
            byte |= encoded << shift;
            shift +%= 2;
            trit_idx += 1;
        }
        
        output[byte_idx] = byte;
        byte_idx += 1;
    }
}

/// Unpack bytes into array of trits {-1, 0, +1}
pub fn unpackTrits(data: []const u8, output: []i8, num_trits: usize) void {
    var trit_idx: usize = 0;
    
    for (data) |byte| {
        var shift: u3 = 0;
        while (shift < 8 and trit_idx < num_trits) {
            const encoded = (byte >> shift) & 0x3;
            output[trit_idx] = TRIT_LUT[encoded];
            shift +%= 2;
            trit_idx += 1;
        }
    }
}

/// Ternary matrix-vector multiply using lookup (no actual multiplication!)
/// output[i] = sum_j(weights[i,j] * input[j]) where weights are {-1, 0, +1}
pub fn ternaryMatVec(output: []f32, packed_weights: []const u8, input: []const f32, rows: usize, cols: usize) void {
    const cols_packed = (cols + 3) / 4; // 4 trits per byte
    
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;
        var col: usize = 0;
        
        // Process 4 columns at a time (1 byte)
        for (0..cols_packed) |byte_idx| {
            if (row_start + byte_idx >= packed_weights.len) break;
            const byte = packed_weights[row_start + byte_idx];
            
            // Unroll 4 trits from byte
            inline for (0..4) |shift_idx| {
                if (col >= cols) break;
                const shift: u3 = @intCast(shift_idx * 2);
                const trit = (byte >> shift) & 0x3;
                sum += input[col] * TRIT_LUT_F32[trit];
                col += 1;
            }
        }
        
        output[row] = sum;
    }
}

/// SIMD-optimized ternary matmul (8 elements at a time)
pub fn ternaryMatVecSIMD(output: []f32, packed_weights: []const u8, input: []const f32, rows: usize, cols: usize) void {
    const Vec8 = @Vector(8, f32);
    const cols_packed = (cols + 3) / 4;
    
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;
        var col: usize = 0;
        
        // SIMD loop: process 8 columns (2 bytes) at a time
        while (col + 8 <= cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx + 1 >= packed_weights.len) break;
            
            const b0 = packed_weights[byte_idx];
            const b1 = packed_weights[byte_idx + 1];
            
            const in_vec: Vec8 = input[col..][0..8].*;
            const signs: Vec8 = .{
                TRIT_LUT_F32[(b0 >> 0) & 0x3],
                TRIT_LUT_F32[(b0 >> 2) & 0x3],
                TRIT_LUT_F32[(b0 >> 4) & 0x3],
                TRIT_LUT_F32[(b0 >> 6) & 0x3],
                TRIT_LUT_F32[(b1 >> 0) & 0x3],
                TRIT_LUT_F32[(b1 >> 2) & 0x3],
                TRIT_LUT_F32[(b1 >> 4) & 0x3],
                TRIT_LUT_F32[(b1 >> 6) & 0x3],
            };
            
            sum += @reduce(.Add, in_vec * signs);
            col += 8;
        }
        
        // Scalar tail
        while (col < cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= packed_weights.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (packed_weights[byte_idx] >> shift) & 0x3;
            sum += input[col] * TRIT_LUT_F32[trit];
        }
        
        output[row] = sum;
    }
}

/// Check if tensor type is BitNet ternary
pub fn isTernaryType(t: GGMLType) bool {
    return t == .TQ1_0 or t == .TQ2_0;
}

/// Calculate memory savings vs FP16
pub fn ternaryMemorySavings(num_elements: u64) struct { ternary_bytes: u64, fp16_bytes: u64, ratio: f32 } {
    const ternary_bytes = (num_elements + 3) / 4; // 4 trits per byte
    const fp16_bytes = num_elements * 2;
    const ratio = @as(f32, @floatFromInt(fp16_bytes)) / @as(f32, @floatFromInt(ternary_bytes));
    return .{ .ternary_bytes = ternary_bytes, .fp16_bytes = fp16_bytes, .ratio = ratio };
}

// ═══════════════════════════════════════════════════════════════════════════════

// GGUF Header
pub const GGUFHeader = struct {
    magic: u32,
    version: u32,
    tensor_count: u64,
    metadata_kv_count: u64,
};

// Tensor Info
pub const TensorInfo = struct {
    name: []const u8,
    n_dims: u32,
    dims: [4]u64,
    tensor_type: GGMLType,
    offset: u64,

    pub fn numElements(self: *const TensorInfo) u64 {
        var n: u64 = 1;
        var i: usize = 0;
        while (i < self.n_dims) : (i += 1) {
            n *= self.dims[i];
        }
        return n;
    }

    pub fn dataSize(self: *const TensorInfo) u64 {
        const ne = self.numElements();
        const bs = getBlockSize(self.tensor_type);
        const ts = getTypeSize(self.tensor_type);
        if (bs == 1) return ne * ts;
        return (ne / bs) * ts;
    }
};

// Metadata Value
pub const MetadataValue = union(enum) {
    uint8: u8,
    int8: i8,
    uint16: u16,
    int16: i16,
    uint32: u32,
    int32: i32,
    float32: f32,
    bool_: bool,
    string: []const u8,
    uint64: u64,
    int64: i64,
    float64: f64,
    array: []MetadataValue,
};

// GGUF Reader
pub const GGUFReader = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    header: GGUFHeader,
    metadata: std.StringHashMap(MetadataValue),
    tensors: std.ArrayList(TensorInfo),
    alignment: u32,
    data_offset: u64,
    tensor_names: std.ArrayList([]u8),

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !GGUFReader {
        const file = try std.fs.cwd().openFile(path, .{});
        errdefer file.close();

        var reader = GGUFReader{
            .allocator = allocator,
            .file = file,
            .header = undefined,
            .metadata = std.StringHashMap(MetadataValue).init(allocator),
            .tensors = std.ArrayList(TensorInfo).init(allocator),
            .alignment = DEFAULT_ALIGNMENT,
            .data_offset = 0,
            .tensor_names = std.ArrayList([]u8).init(allocator),
        };

        try reader.parseHeader();
        try reader.parseMetadata();
        try reader.parseTensorInfos();

        return reader;
    }

    pub fn deinit(self: *GGUFReader) void {
        for (self.tensor_names.items) |name| {
            self.allocator.free(name);
        }
        self.tensor_names.deinit();
        self.tensors.deinit();
        // Free metadata strings
        var it = self.metadata.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.metadata.deinit();
        self.file.close();
    }

    fn parseHeader(self: *GGUFReader) !void {
        const r = self.file.reader();
        self.header.magic = try r.readInt(u32, .little);
        if (self.header.magic != GGUF_MAGIC) {
            return error.InvalidMagic;
        }
        self.header.version = try r.readInt(u32, .little);
        if (self.header.version < 2 or self.header.version > 3) {
            return error.UnsupportedVersion;
        }
        self.header.tensor_count = try r.readInt(u64, .little);
        self.header.metadata_kv_count = try r.readInt(u64, .little);
    }

    fn readString(self: *GGUFReader) ![]u8 {
        const r = self.file.reader();
        const len = try r.readInt(u64, .little);
        if (len > 1024 * 1024) return error.StringTooLong;
        const str = try self.allocator.alloc(u8, @intCast(len));
        const bytes_read = try r.readAtLeast(str, str.len);
        if (bytes_read != str.len) {
            self.allocator.free(str);
            return error.UnexpectedEof;
        }
        return str;
    }

    fn readMetadataValue(self: *GGUFReader, vtype: GGUFValueType) !MetadataValue {
        const r = self.file.reader();
        return switch (vtype) {
            .UINT8 => MetadataValue{ .uint8 = try r.readInt(u8, .little) },
            .INT8 => MetadataValue{ .int8 = try r.readInt(i8, .little) },
            .UINT16 => MetadataValue{ .uint16 = try r.readInt(u16, .little) },
            .INT16 => MetadataValue{ .int16 = try r.readInt(i16, .little) },
            .UINT32 => MetadataValue{ .uint32 = try r.readInt(u32, .little) },
            .INT32 => MetadataValue{ .int32 = try r.readInt(i32, .little) },
            .FLOAT32 => MetadataValue{ .float32 = @bitCast(try r.readInt(u32, .little)) },
            .BOOL => MetadataValue{ .bool_ = (try r.readInt(u8, .little)) != 0 },
            .STRING => MetadataValue{ .string = try self.readString() },
            .UINT64 => MetadataValue{ .uint64 = try r.readInt(u64, .little) },
            .INT64 => MetadataValue{ .int64 = try r.readInt(i64, .little) },
            .FLOAT64 => MetadataValue{ .float64 = @bitCast(try r.readInt(u64, .little)) },
            .ARRAY => blk: {
                const arr_type: GGUFValueType = @enumFromInt(try r.readInt(u32, .little));
                const arr_len = try r.readInt(u64, .little);
                if (arr_len > 1024 * 1024) return error.ArrayTooLong;
                const arr = try self.allocator.alloc(MetadataValue, @intCast(arr_len));
                for (arr, 0..) |*item, i| {
                    _ = i;
                    item.* = try self.readMetadataValue(arr_type);
                }
                break :blk MetadataValue{ .array = arr };
            },
        };
    }

    fn parseMetadata(self: *GGUFReader) !void {
        var i: u64 = 0;
        while (i < self.header.metadata_kv_count) : (i += 1) {
            const key = try self.readString();
            defer self.allocator.free(key);

            const vtype: GGUFValueType = @enumFromInt(try self.file.reader().readInt(u32, .little));
            const value = try self.readMetadataValue(vtype);

            // Check for alignment
            if (std.mem.eql(u8, key, "general.alignment")) {
                if (value == .uint32) {
                    self.alignment = value.uint32;
                }
            }

            // Store with owned key
            const owned_key = try self.allocator.dupe(u8, key);
            try self.metadata.put(owned_key, value);
        }
    }

    fn parseTensorInfos(self: *GGUFReader) !void {
        const r = self.file.reader();

        var i: u64 = 0;
        while (i < self.header.tensor_count) : (i += 1) {
            const name = try self.readString();
            try self.tensor_names.append(name);

            const n_dims = try r.readInt(u32, .little);
            var dims = [_]u64{1} ** 4;

            var d: usize = 0;
            while (d < n_dims) : (d += 1) {
                dims[d] = try r.readInt(u64, .little);
            }

            const tensor_type: GGMLType = @enumFromInt(try r.readInt(u32, .little));
            const offset = try r.readInt(u64, .little);

            try self.tensors.append(TensorInfo{
                .name = name,
                .n_dims = n_dims,
                .dims = dims,
                .tensor_type = tensor_type,
                .offset = offset,
            });
        }

        // Calculate data offset (aligned)
        const pos = try self.file.getPos();
        self.data_offset = alignOffset(pos, self.alignment);
    }

    fn alignOffset(offset: u64, alignment: u32) u64 {
        const a: u64 = alignment;
        return offset + (a - (offset % a)) % a;
    }

    // Get tensor by name
    pub fn getTensor(self: *const GGUFReader, name: []const u8) ?*const TensorInfo {
        for (self.tensors.items) |*t| {
            if (std.mem.eql(u8, t.name, name)) {
                return t;
            }
        }
        return null;
    }

    // Read tensor data
    pub fn readTensorData(self: *GGUFReader, info: *const TensorInfo) ![]u8 {
        const size = info.dataSize();
        const data = try self.allocator.alloc(u8, @intCast(size));
        errdefer self.allocator.free(data);

        try self.file.seekTo(self.data_offset + info.offset);
        const bytes_read = try self.file.reader().readAtLeast(data, data.len);
        if (bytes_read != data.len) {
            return error.UnexpectedEof;
        }
        return data;
    }

    // Get metadata string
    pub fn getMetadataString(self: *const GGUFReader, key: []const u8) ?[]const u8 {
        if (self.metadata.get(key)) |v| {
            if (v == .string) return v.string;
        }
        return null;
    }

    // Get metadata u32
    pub fn getMetadataU32(self: *const GGUFReader, key: []const u8) ?u32 {
        if (self.metadata.get(key)) |v| {
            return switch (v) {
                .uint32 => v.uint32,
                .uint64 => @intCast(v.uint64),
                .int32 => @intCast(v.int32),
                else => null,
            };
        }
        return null;
    }

    // Get metadata u64
    pub fn getMetadataU64(self: *const GGUFReader, key: []const u8) ?u64 {
        if (self.metadata.get(key)) |v| {
            return switch (v) {
                .uint64 => v.uint64,
                .uint32 => v.uint32,
                .int64 => @intCast(v.int64),
                else => null,
            };
        }
        return null;
    }

    // Get metadata f32
    pub fn getMetadataF32(self: *const GGUFReader, key: []const u8) ?f32 {
        if (self.metadata.get(key)) |v| {
            if (v == .float32) return v.float32;
        }
        return null;
    }

    // Print info
    pub fn printInfo(self: *const GGUFReader) void {
        std.debug.print("\n", .{});
        std.debug.print("GGUF FILE INFO\n", .{});
        std.debug.print("  Version:        {d}\n", .{self.header.version});
        std.debug.print("  Tensors:        {d}\n", .{self.header.tensor_count});
        std.debug.print("  Metadata KVs:   {d}\n", .{self.header.metadata_kv_count});
        std.debug.print("  Alignment:      {d}\n", .{self.alignment});
        std.debug.print("  Data offset:    {d}\n", .{self.data_offset});

        if (self.getMetadataString("general.architecture")) |arch| {
            std.debug.print("  Architecture:   {s}\n", .{arch});
        }
        if (self.getMetadataString("general.name")) |name| {
            std.debug.print("  Name:           {s}\n", .{name});
        }
        
        // BitNet detection
        if (self.hasTernaryTensors()) {
            std.debug.print("  BitNet:         YES (ternary weights detected)\n", .{});
            const stats = self.getTernaryStats();
            std.debug.print("  Ternary tensors: {d}\n", .{stats.ternary_count});
            std.debug.print("  Memory savings: {d:.1}x vs FP16\n", .{stats.compression_ratio});
        }
    }
    
    /// Check if model has any ternary (BitNet) tensors
    pub fn hasTernaryTensors(self: *const GGUFReader) bool {
        for (self.tensors.items) |tensor| {
            if (isTernaryType(tensor.tensor_type)) {
                return true;
            }
        }
        return false;
    }
    
    /// Get statistics about ternary tensors
    pub fn getTernaryStats(self: *const GGUFReader) struct { 
        ternary_count: usize, 
        total_elements: u64, 
        ternary_bytes: u64,
        fp16_bytes: u64,
        compression_ratio: f32,
    } {
        var ternary_count: usize = 0;
        var total_elements: u64 = 0;
        
        for (self.tensors.items) |tensor| {
            if (isTernaryType(tensor.tensor_type)) {
                ternary_count += 1;
                total_elements += tensor.numElements();
            }
        }
        
        const savings = ternaryMemorySavings(total_elements);
        return .{
            .ternary_count = ternary_count,
            .total_elements = total_elements,
            .ternary_bytes = savings.ternary_bytes,
            .fp16_bytes = savings.fp16_bytes,
            .compression_ratio = savings.ratio,
        };
    }
    
    /// Check if this is a BitNet model by architecture name
    pub fn isBitNetModel(self: *const GGUFReader) bool {
        if (self.getMetadataString("general.architecture")) |arch| {
            // Check for known BitNet architectures
            if (std.mem.indexOf(u8, arch, "bitnet") != null) return true;
            if (std.mem.indexOf(u8, arch, "BitNet") != null) return true;
            if (std.mem.indexOf(u8, arch, "ternary") != null) return true;
        }
        // Also check if model has ternary tensors
        return self.hasTernaryTensors();
    }
    
    /// Read ternary tensor data and return packed bytes
    pub fn readTernaryTensor(self: *GGUFReader, info: *const TensorInfo) ![]u8 {
        if (!isTernaryType(info.tensor_type)) {
            return error.NotTernaryTensor;
        }
        return self.readTensorData(info);
    }
};

// Dequantize Q4_0 block
pub fn dequantizeQ4_0(block: []const u8, output: []f32) void {
    if (block.len < 18 or output.len < 32) return;

    // First 2 bytes are scale (f16)
    const scale_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
    const scale = f16ToF32(scale_bits);

    // Next 16 bytes are 32 4-bit values
    var i: usize = 0;
    while (i < 32) : (i += 2) {
        const byte = block[2 + i / 2];
        const lo: i8 = @as(i8, @intCast(byte & 0x0F)) - 8;
        const hi: i8 = @as(i8, @intCast(byte >> 4)) - 8;
        output[i] = @as(f32, @floatFromInt(lo)) * scale;
        output[i + 1] = @as(f32, @floatFromInt(hi)) * scale;
    }
}

// Dequantize Q8_0 block
pub fn dequantizeQ8_0(block: []const u8, output: []f32) void {
    if (block.len < 34 or output.len < 32) return;

    // First 2 bytes are scale (f16)
    const scale_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
    const scale = f16ToF32(scale_bits);

    // Next 32 bytes are 32 8-bit values
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        const val: i8 = @bitCast(block[2 + i]);
        output[i] = @as(f32, @floatFromInt(val)) * scale;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// K-QUANTIZATION DEQUANTIZATION (Q4_K, Q5_K, Q6_K)
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

/// Q4_K block structure constants
pub const Q4_K_BLOCK_SIZE: usize = 256;
pub const Q4_K_BYTE_SIZE: usize = 144;
pub const Q5_K_BYTE_SIZE: usize = 176;
pub const Q6_K_BYTE_SIZE: usize = 210;
pub const K_SCALE_SIZE: usize = 12;
pub const QK_K: usize = 256;

/// Extract 6-bit scale from packed scales array
/// Scales are packed: 8 scales (6 bits each) + 4 mins (6 bits each) = 72 bits = 9 bytes
/// But llama.cpp uses 12 bytes with different packing
fn getQ4KScale(scales: []const u8, i: usize) f32 {
    // Lower 4 bits of scales[i] + upper 2 bits from scales[8 + i/2]
    const lo = scales[i] & 0x3F;
    return @floatFromInt(lo);
}

fn getQ4KMin(scales: []const u8, i: usize) f32 {
    // Upper 2 bits of scales[i] shifted + bits from scales[10 + i/2]
    const hi = (scales[i] >> 6) & 0x03;
    const extra_idx = 8 + i / 2;
    const shift: u3 = @intCast((i % 2) * 4);
    const extra = if (extra_idx < scales.len) (scales[extra_idx] >> shift) & 0x0F else 0;
    return @floatFromInt((@as(u8, hi) << 4) | extra);
}

/// Dequantize Q4_K block (256 elements from 144 bytes)
/// Format: d(f16) + dmin(f16) + scales[12] + qs[128]
pub fn dequantizeQ4_K(block: []const u8, output: []f32) void {
    if (block.len < Q4_K_BYTE_SIZE or output.len < Q4_K_BLOCK_SIZE) return;

    // Read super-block scale and min (f16)
    const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
    const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
    const d = f16ToF32(d_bits);
    const dmin = f16ToF32(dmin_bits);

    // Scales are in bytes 4-15 (12 bytes)
    const scales = block[4..16];
    
    // Quantized values are in bytes 16-143 (128 bytes = 256 4-bit values)
    const qs = block[16..144];

    // Process 8 sub-blocks of 32 elements each
    var out_idx: usize = 0;
    for (0..8) |sb| {
        const sc = getQ4KScale(scales, sb);
        const m = getQ4KMin(scales, sb);
        
        const scale = d * sc;
        const min_val = dmin * m;
        
        // Each sub-block has 32 elements = 16 bytes of 4-bit values
        const qs_start = sb * 16;
        
        for (0..16) |j| {
            const byte = qs[qs_start + j];
            const lo: i8 = @intCast(byte & 0x0F);
            const hi: i8 = @intCast(byte >> 4);
            
            output[out_idx] = @as(f32, @floatFromInt(lo)) * scale - min_val;
            output[out_idx + 1] = @as(f32, @floatFromInt(hi)) * scale - min_val;
            out_idx += 2;
        }
    }
}

/// Dequantize Q5_K block (256 elements from 176 bytes)
/// Format: d(f16) + dmin(f16) + scales[12] + qh[32] + qs[128]
pub fn dequantizeQ5_K(block: []const u8, output: []f32) void {
    if (block.len < Q5_K_BYTE_SIZE or output.len < Q4_K_BLOCK_SIZE) return;

    const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
    const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
    const d = f16ToF32(d_bits);
    const dmin = f16ToF32(dmin_bits);

    const scales = block[4..16];
    const qh = block[16..48];  // High bits (32 bytes)
    const qs = block[48..176]; // Low 4 bits (128 bytes)

    var out_idx: usize = 0;
    for (0..8) |sb| {
        const sc = getQ4KScale(scales, sb);
        const m = getQ4KMin(scales, sb);
        
        const scale = d * sc;
        const min_val = dmin * m;
        
        const qs_start = sb * 16;
        const qh_start = sb * 4;
        
        for (0..16) |j| {
            const byte = qs[qs_start + j];
            const lo4: u8 = byte & 0x0F;
            const hi4: u8 = byte >> 4;
            
            // Get 5th bit from qh
            const qh_byte = qh[qh_start + j / 4];
            const qh_shift_lo: u3 = @intCast((j * 2) % 8);
            const qh_shift_hi: u3 = @intCast((j * 2 + 1) % 8);
            const lo5: u8 = ((qh_byte >> qh_shift_lo) & 1) << 4;
            const hi5: u8 = ((qh_byte >> qh_shift_hi) & 1) << 4;
            
            const lo: i8 = @intCast(lo4 | lo5);
            const hi: i8 = @intCast(hi4 | hi5);
            
            output[out_idx] = @as(f32, @floatFromInt(lo)) * scale - min_val;
            output[out_idx + 1] = @as(f32, @floatFromInt(hi)) * scale - min_val;
            out_idx += 2;
        }
    }
}

/// Dequantize Q6_K block (256 elements from 210 bytes)
/// Format: ql[128] + qh[64] + scales[16] + d(f16)
pub fn dequantizeQ6_K(block: []const u8, output: []f32) void {
    if (block.len < Q6_K_BYTE_SIZE or output.len < Q4_K_BLOCK_SIZE) return;

    const ql = block[0..128];    // Low 4 bits
    const qh = block[128..192];  // High 2 bits
    const scales = block[192..208]; // 16 scales (8-bit each)
    const d_bits = @as(u16, block[208]) | (@as(u16, block[209]) << 8);
    const d = f16ToF32(d_bits);

    var out_idx: usize = 0;
    for (0..16) |sb| {
        const scale: i8 = @bitCast(scales[sb]);
        const sc = d * @as(f32, @floatFromInt(scale));
        
        const ql_start = sb * 8;
        const qh_start = sb * 4;
        
        for (0..8) |j| {
            const ql_byte = ql[ql_start + j];
            const lo4: u8 = ql_byte & 0x0F;
            const hi4: u8 = ql_byte >> 4;
            
            // Get high 2 bits from qh
            const qh_byte = qh[qh_start + j / 2];
            const qh_shift_lo: u3 = @intCast((j % 2) * 4);
            const qh_shift_hi: u3 = @intCast((j % 2) * 4 + 2);
            const lo_hi: u8 = ((qh_byte >> qh_shift_lo) & 0x03) << 4;
            const hi_hi: u8 = ((qh_byte >> qh_shift_hi) & 0x03) << 4;
            
            // Combine to 6-bit value, subtract 32 for signed
            const lo: i8 = @as(i8, @intCast(lo4 | lo_hi)) - 32;
            const hi: i8 = @as(i8, @intCast(hi4 | hi_hi)) - 32;
            
            output[out_idx] = @as(f32, @floatFromInt(lo)) * sc;
            output[out_idx + 1] = @as(f32, @floatFromInt(hi)) * sc;
            out_idx += 2;
        }
    }
}

/// SIMD-optimized Q4_K dequantization (8 elements at a time)
pub fn dequantizeQ4_K_SIMD(block: []const u8, output: []f32) void {
    if (block.len < Q4_K_BYTE_SIZE or output.len < Q4_K_BLOCK_SIZE) return;

    const Vec8 = @Vector(8, f32);
    
    const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
    const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
    const d = f16ToF32(d_bits);
    const dmin = f16ToF32(dmin_bits);

    const scales = block[4..16];
    const qs = block[16..144];

    var out_idx: usize = 0;
    for (0..8) |sb| {
        const sc = getQ4KScale(scales, sb);
        const m = getQ4KMin(scales, sb);
        
        const scale = d * sc;
        const min_val = dmin * m;
        const scale_vec: Vec8 = @splat(scale);
        const min_vec: Vec8 = @splat(min_val);
        
        const qs_start = sb * 16;
        
        // Process 8 elements at a time (4 bytes)
        var j: usize = 0;
        while (j + 4 <= 16) : (j += 4) {
            // Unpack 8 4-bit values from 4 bytes
            const b0 = qs[qs_start + j];
            const b1 = qs[qs_start + j + 1];
            const b2 = qs[qs_start + j + 2];
            const b3 = qs[qs_start + j + 3];
            
            const vals: Vec8 = .{
                @floatFromInt(@as(i8, @intCast(b0 & 0x0F))),
                @floatFromInt(@as(i8, @intCast(b0 >> 4))),
                @floatFromInt(@as(i8, @intCast(b1 & 0x0F))),
                @floatFromInt(@as(i8, @intCast(b1 >> 4))),
                @floatFromInt(@as(i8, @intCast(b2 & 0x0F))),
                @floatFromInt(@as(i8, @intCast(b2 >> 4))),
                @floatFromInt(@as(i8, @intCast(b3 & 0x0F))),
                @floatFromInt(@as(i8, @intCast(b3 >> 4))),
            };
            
            const result = vals * scale_vec - min_vec;
            
            // Store 8 results
            inline for (0..8) |k| {
                output[out_idx + k] = result[k];
            }
            out_idx += 8;
        }
    }
}

/// Check if type is K-quantized
pub fn isKQuantType(t: GGMLType) bool {
    return switch (t) {
        .Q2_K, .Q3_K, .Q4_K, .Q5_K, .Q6_K, .Q8_K => true,
        else => false,
    };
}

/// Dequantize any supported block type
pub fn dequantizeBlock(block: []const u8, output: []f32, tensor_type: GGMLType) !void {
    switch (tensor_type) {
        .Q4_0 => dequantizeQ4_0(block, output),
        .Q8_0 => dequantizeQ8_0(block, output),
        .Q4_K => dequantizeQ4_K(block, output),
        .Q5_K => dequantizeQ5_K(block, output),
        .Q6_K => dequantizeQ6_K(block, output),
        .TQ1_0, .TQ2_0 => {
            // Ternary: unpack and convert to float
            var trits: [256]i8 = undefined;
            unpackTrits(block, &trits, @min(output.len, 256));
            for (0..@min(output.len, 256)) |i| {
                output[i] = @floatFromInt(trits[i]);
            }
        },
        .F16 => {
            // Direct f16 to f32
            var i: usize = 0;
            while (i < output.len and i * 2 + 1 < block.len) : (i += 1) {
                const bits = @as(u16, block[i * 2]) | (@as(u16, block[i * 2 + 1]) << 8);
                output[i] = f16ToF32(bits);
            }
        },
        .F32 => {
            // Direct copy
            const f32_slice = std.mem.bytesAsSlice(f32, block);
            @memcpy(output[0..@min(output.len, f32_slice.len)], f32_slice[0..@min(output.len, f32_slice.len)]);
        },
        else => return error.UnsupportedQuantization,
    }
}

// ═══════════════════════════════════════════════════════════════════════════════

// F16 to F32 conversion
pub fn f16ToF32(h: u16) f32 {
    const sign: u32 = (@as(u32, h) & 0x8000) << 16;
    const exp: u32 = (@as(u32, h) >> 10) & 0x1F;
    const mant: u32 = @as(u32, h) & 0x3FF;

    if (exp == 0) {
        if (mant == 0) {
            return @bitCast(sign);
        }
        // Denormalized
        var e: u32 = 1;
        var m = mant;
        while ((m & 0x400) == 0) {
            m <<= 1;
            e += 1;
        }
        m &= 0x3FF;
        return @bitCast(sign | ((127 - 15 + 1 - e) << 23) | (m << 13));
    } else if (exp == 31) {
        // Inf or NaN
        return @bitCast(sign | 0x7F800000 | (mant << 13));
    }

    return @bitCast(sign | ((exp + 127 - 15) << 23) | (mant << 13));
}

// Tests
test "gguf_magic" {
    try std.testing.expectEqual(GGUF_MAGIC, 0x46554747);
}

test "block_sizes" {
    try std.testing.expectEqual(getBlockSize(.Q4_0), 32);
    try std.testing.expectEqual(getBlockSize(.Q4_K), 256);
    try std.testing.expectEqual(getTypeSize(.Q4_0), 18);
}

test "f16_to_f32" {
    // Test 1.0 in f16 (0x3C00)
    const one = f16ToF32(0x3C00);
    try std.testing.expectApproxEqAbs(one, 1.0, 0.001);

    // Test 0.5 in f16 (0x3800)
    const half = f16ToF32(0x3800);
    try std.testing.expectApproxEqAbs(half, 0.5, 0.001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET TERNARY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ternary_block_sizes" {
    try std.testing.expectEqual(getBlockSize(.TQ1_0), 32);
    try std.testing.expectEqual(getBlockSize(.TQ2_0), 32);
    try std.testing.expectEqual(getTypeSize(.TQ1_0), 8);  // 32 trits * 2 bits / 8
    try std.testing.expectEqual(getTypeSize(.TQ2_0), 10); // + 2 byte scale
}

test "pack_unpack_trits" {
    // Test packing: [+1, -1, 0, +1] should become 0b01_10_00_01 = 0x59
    const trits = [_]i8{ 1, -1, 0, 1 };
    var pack_buf: [1]u8 = undefined;
    packTrits(&trits, &pack_buf);
    
    // Encoding: +1=01, -1=10, 0=00
    // Byte: (01) | (10 << 2) | (00 << 4) | (01 << 6) = 0x49
    try std.testing.expectEqual(pack_buf[0], 0x49);
    
    // Test unpacking
    var unpacked: [4]i8 = undefined;
    unpackTrits(&pack_buf, &unpacked, 4);
    try std.testing.expectEqual(unpacked[0], 1);
    try std.testing.expectEqual(unpacked[1], -1);
    try std.testing.expectEqual(unpacked[2], 0);
    try std.testing.expectEqual(unpacked[3], 1);
}

test "ternary_matvec_basic" {
    // 2x4 matrix with all +1 weights
    // Packed: 4 trits of +1 = 0b01_01_01_01 = 0x55
    const weights = [_]u8{ 0x55, 0x55 }; // 2 rows, 4 cols each
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;
    
    ternaryMatVec(&output, &weights, &input, 2, 4);
    
    // Each row: 1*1 + 1*2 + 1*3 + 1*4 = 10
    try std.testing.expectApproxEqAbs(output[0], 10.0, 0.01);
    try std.testing.expectApproxEqAbs(output[1], 10.0, 0.01);
}

test "ternary_matvec_mixed" {
    // Row with [+1, -1, +1, -1]
    // Packed: 0b10_01_10_01 = 0x69
    const weights = [_]u8{ 0x69 };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [1]f32 = undefined;
    
    ternaryMatVec(&output, &weights, &input, 1, 4);
    
    // 1*1 + (-1)*2 + 1*3 + (-1)*4 = 1 - 2 + 3 - 4 = -2
    try std.testing.expectApproxEqAbs(output[0], -2.0, 0.01);
}

test "ternary_matvec_simd" {
    // 1x8 matrix with alternating +1, -1
    // Packed: 2 bytes of 0x69 each
    const weights = [_]u8{ 0x69, 0x69 };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    var output: [1]f32 = undefined;
    
    ternaryMatVecSIMD(&output, &weights, &input, 1, 8);
    
    // (1-2+3-4) + (5-6+7-8) = -2 + -2 = -4
    try std.testing.expectApproxEqAbs(output[0], -4.0, 0.01);
}

test "ternary_memory_savings" {
    const savings = ternaryMemorySavings(1_000_000);
    try std.testing.expectEqual(savings.ternary_bytes, 250_000);
    try std.testing.expectEqual(savings.fp16_bytes, 2_000_000);
    try std.testing.expectApproxEqAbs(savings.ratio, 8.0, 0.01);
}

test "is_ternary_type" {
    try std.testing.expect(isTernaryType(.TQ1_0));
    try std.testing.expect(isTernaryType(.TQ2_0));
    try std.testing.expect(!isTernaryType(.Q8_0));
    try std.testing.expect(!isTernaryType(.F16));
}

// ═══════════════════════════════════════════════════════════════════════════════
// K-QUANTIZATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "k_quant_block_sizes" {
    try std.testing.expectEqual(getBlockSize(.Q4_K), 256);
    try std.testing.expectEqual(getBlockSize(.Q5_K), 256);
    try std.testing.expectEqual(getBlockSize(.Q6_K), 256);
    try std.testing.expectEqual(getTypeSize(.Q4_K), 144);
    try std.testing.expectEqual(getTypeSize(.Q5_K), 176);
    try std.testing.expectEqual(getTypeSize(.Q6_K), 210);
}

test "is_k_quant_type" {
    try std.testing.expect(isKQuantType(.Q4_K));
    try std.testing.expect(isKQuantType(.Q5_K));
    try std.testing.expect(isKQuantType(.Q6_K));
    try std.testing.expect(isKQuantType(.Q2_K));
    try std.testing.expect(!isKQuantType(.Q4_0));
    try std.testing.expect(!isKQuantType(.F16));
}

test "dequantize_q4_k_basic" {
    // Create a minimal Q4_K block (144 bytes)
    var block: [144]u8 = undefined;
    @memset(&block, 0);
    
    // Set d = 1.0 (f16: 0x3C00)
    block[0] = 0x00;
    block[1] = 0x3C;
    // Set dmin = 0.0
    block[2] = 0x00;
    block[3] = 0x00;
    // Set first scale to 1 (6-bit value)
    block[4] = 0x01;
    // Set first quantized value to 0x55 (5 and 5)
    block[16] = 0x55;
    
    var output: [256]f32 = undefined;
    dequantizeQ4_K(&block, &output);
    
    // First two values should be 5 * 1.0 * 1 - 0 = 5.0
    try std.testing.expectApproxEqAbs(output[0], 5.0, 0.1);
    try std.testing.expectApproxEqAbs(output[1], 5.0, 0.1);
}

test "dequantize_q4_k_simd_matches_scalar" {
    // Create a test Q4_K block
    var block: [144]u8 = undefined;
    @memset(&block, 0);
    
    // Set d = 1.0
    block[0] = 0x00;
    block[1] = 0x3C;
    // Set scales
    for (4..16) |i| {
        block[i] = 0x01;
    }
    // Set quantized values
    for (16..144) |i| {
        block[i] = @intCast((i - 16) % 256);
    }
    
    var output_scalar: [256]f32 = undefined;
    var output_simd: [256]f32 = undefined;
    
    dequantizeQ4_K(&block, &output_scalar);
    dequantizeQ4_K_SIMD(&block, &output_simd);
    
    // Results should match
    for (0..256) |i| {
        try std.testing.expectApproxEqAbs(output_scalar[i], output_simd[i], 0.001);
    }
}

test "dequantize_block_dispatch" {
    // Test Q4_0
    var q4_block: [18]u8 = undefined;
    @memset(&q4_block, 0);
    q4_block[0] = 0x00;
    q4_block[1] = 0x3C; // scale = 1.0
    
    var output: [32]f32 = undefined;
    try dequantizeBlock(&q4_block, &output, .Q4_0);
    
    // Should not error
    try std.testing.expect(true);
}

test "dequantize_block_unsupported" {
    var block: [10]u8 = undefined;
    var output: [32]f32 = undefined;
    
    // Q2_K is not implemented yet
    const result = dequantizeBlock(&block, &output, .Q2_K);
    try std.testing.expectError(error.UnsupportedQuantization, result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY-MAPPED GGUF READER
// Near-instant loading via mmap, shared memory across processes
// ═══════════════════════════════════════════════════════════════════════════════

/// Memory-mapped file handle
pub const MmapFile = struct {
    data: []align(std.mem.page_size) u8,
    size: usize,

    pub fn init(path: []const u8) !MmapFile {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const size = stat.size;

        if (size == 0) {
            return error.EmptyFile;
        }

        const data = try std.posix.mmap(
            null,
            size,
            std.posix.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );

        return MmapFile{
            .data = data,
            .size = size,
        };
    }

    pub fn deinit(self: *MmapFile) void {
        std.posix.munmap(self.data);
    }

    /// Get slice at offset
    pub fn slice(self: *const MmapFile, offset: usize, len: usize) []const u8 {
        if (offset + len > self.size) {
            return &[_]u8{};
        }
        return self.data[offset..][0..len];
    }

    /// Read u32 at offset (little-endian)
    pub fn readU32(self: *const MmapFile, offset: usize) u32 {
        if (offset + 4 > self.size) return 0;
        return std.mem.readInt(u32, self.data[offset..][0..4], .little);
    }

    /// Read u64 at offset (little-endian)
    pub fn readU64(self: *const MmapFile, offset: usize) u64 {
        if (offset + 8 > self.size) return 0;
        return std.mem.readInt(u64, self.data[offset..][0..8], .little);
    }
};

/// Memory-mapped GGUF reader (zero-copy tensor access)
pub const MmapGGUFReader = struct {
    allocator: std.mem.Allocator,
    mmap: MmapFile,
    header: GGUFHeader,
    metadata: std.StringHashMap(MetadataValue),
    tensors: std.ArrayList(TensorInfo),
    tensor_names: std.ArrayList([]u8),
    data_offset: u64,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !MmapGGUFReader {
        var mmap = try MmapFile.init(path);
        errdefer mmap.deinit();

        var reader = MmapGGUFReader{
            .allocator = allocator,
            .mmap = mmap,
            .header = undefined,
            .metadata = std.StringHashMap(MetadataValue).init(allocator),
            .tensors = std.ArrayList(TensorInfo).init(allocator),
            .tensor_names = std.ArrayList([]u8).init(allocator),
            .data_offset = 0,
        };

        try reader.parseHeader();
        try reader.parseMetadata();
        try reader.parseTensorInfos();

        return reader;
    }

    pub fn deinit(self: *MmapGGUFReader) void {
        for (self.tensor_names.items) |name| {
            self.allocator.free(name);
        }
        self.tensor_names.deinit();
        self.tensors.deinit();
        var it = self.metadata.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.metadata.deinit();
        self.mmap.deinit();
    }

    fn parseHeader(self: *MmapGGUFReader) !void {
        if (self.mmap.size < 24) return error.FileTooSmall;

        self.header.magic = self.mmap.readU32(0);
        if (self.header.magic != GGUF_MAGIC) {
            return error.InvalidMagic;
        }

        self.header.version = self.mmap.readU32(4);
        self.header.tensor_count = self.mmap.readU64(8);
        self.header.metadata_kv_count = self.mmap.readU64(16);
    }

    fn parseMetadata(self: *MmapGGUFReader) !void {
        var offset: usize = 24; // After header

        var i: u64 = 0;
        while (i < self.header.metadata_kv_count) : (i += 1) {
            // Read key length
            const key_len = self.mmap.readU64(offset);
            offset += 8;

            // Read key
            const key_data = self.mmap.slice(offset, @intCast(key_len));
            offset += @intCast(key_len);

            // Allocate and copy key
            const key = try self.allocator.alloc(u8, key_data.len);
            @memcpy(key, key_data);

            // Read value type
            const vtype: GGUFValueType = @enumFromInt(self.mmap.readU32(offset));
            offset += 4;

            // Read value based on type
            const value: MetadataValue = switch (vtype) {
                .UINT32 => blk: {
                    const v = self.mmap.readU32(offset);
                    offset += 4;
                    break :blk .{ .uint32 = v };
                },
                .INT32 => blk: {
                    const v: i32 = @bitCast(self.mmap.readU32(offset));
                    offset += 4;
                    break :blk .{ .int32 = v };
                },
                .UINT64 => blk: {
                    const v = self.mmap.readU64(offset);
                    offset += 8;
                    break :blk .{ .uint64 = v };
                },
                .FLOAT32 => blk: {
                    const bits = self.mmap.readU32(offset);
                    offset += 4;
                    break :blk .{ .float32 = @bitCast(bits) };
                },
                .STRING => blk: {
                    const str_len = self.mmap.readU64(offset);
                    offset += 8;
                    const str_data = self.mmap.slice(offset, @intCast(str_len));
                    offset += @intCast(str_len);
                    const str = try self.allocator.alloc(u8, str_data.len);
                    @memcpy(str, str_data);
                    break :blk .{ .string = str };
                },
                .ARRAY => {
                    // Skip array for now
                    const arr_type: GGUFValueType = @enumFromInt(self.mmap.readU32(offset));
                    offset += 4;
                    const arr_len = self.mmap.readU64(offset);
                    offset += 8;
                    // Skip array elements
                    const elem_size: usize = switch (arr_type) {
                        .UINT32, .INT32, .FLOAT32 => 4,
                        .UINT64, .INT64, .FLOAT64 => 8,
                        else => 1,
                    };
                    offset += @intCast(arr_len * elem_size);
                    self.allocator.free(key);
                    continue;
                },
                else => {
                    self.allocator.free(key);
                    continue;
                },
            };

            try self.metadata.put(key, value);
        }

        self.data_offset = offset;
    }

    fn parseTensorInfos(self: *MmapGGUFReader) !void {
        var offset = self.data_offset;

        var i: u64 = 0;
        while (i < self.header.tensor_count) : (i += 1) {
            // Read name
            const name_len = self.mmap.readU64(offset);
            offset += 8;
            const name_data = self.mmap.slice(offset, @intCast(name_len));
            offset += @intCast(name_len);

            const name = try self.allocator.alloc(u8, name_data.len);
            @memcpy(name, name_data);
            try self.tensor_names.append(name);

            // Read dimensions
            const n_dims = self.mmap.readU32(offset);
            offset += 4;

            var dims: [4]u64 = .{ 1, 1, 1, 1 };
            var j: usize = 0;
            while (j < n_dims and j < 4) : (j += 1) {
                dims[j] = self.mmap.readU64(offset);
                offset += 8;
            }

            // Read type and offset
            const tensor_type: GGMLType = @enumFromInt(self.mmap.readU32(offset));
            offset += 4;
            const tensor_offset = self.mmap.readU64(offset);
            offset += 8;

            try self.tensors.append(TensorInfo{
                .name = name,
                .n_dims = n_dims,
                .dims = dims,
                .tensor_type = tensor_type,
                .offset = tensor_offset,
            });
        }

        // Align data offset
        const alignment: u64 = DEFAULT_ALIGNMENT;
        self.data_offset = (offset + alignment - 1) & ~(alignment - 1);
    }

    /// Get tensor info by name
    pub fn getTensor(self: *const MmapGGUFReader, name: []const u8) ?*const TensorInfo {
        for (self.tensors.items) |*info| {
            if (std.mem.eql(u8, info.name, name)) {
                return info;
            }
        }
        return null;
    }

    /// Get tensor data slice (ZERO-COPY!)
    pub fn getTensorData(self: *const MmapGGUFReader, info: *const TensorInfo) []const u8 {
        const size = info.dataSize();
        return self.mmap.slice(@intCast(self.data_offset + info.offset), @intCast(size));
    }

    /// Get metadata string
    pub fn getMetadataString(self: *const MmapGGUFReader, key: []const u8) ?[]const u8 {
        if (self.metadata.get(key)) |v| {
            if (v == .string) return v.string;
        }
        return null;
    }

    /// Get metadata u32
    pub fn getMetadataU32(self: *const MmapGGUFReader, key: []const u8) ?u32 {
        if (self.metadata.get(key)) |v| {
            return switch (v) {
                .uint32 => v.uint32,
                .uint64 => @intCast(v.uint64),
                .int32 => @intCast(v.int32),
                else => null,
            };
        }
        return null;
    }

    /// Get metadata f32
    pub fn getMetadataF32(self: *const MmapGGUFReader, key: []const u8) ?f32 {
        if (self.metadata.get(key)) |v| {
            if (v == .float32) return v.float32;
        }
        return null;
    }
};

test "mmap_file" {
    // Create a test file
    const test_data = "Hello, mmap!";
    {
        const file = try std.fs.cwd().createFile("/tmp/mmap_test.bin", .{});
        defer file.close();
        try file.writeAll(test_data);
    }

    // Test mmap
    var mmap = try MmapFile.init("/tmp/mmap_test.bin");
    defer mmap.deinit();

    try std.testing.expectEqual(test_data.len, mmap.size);
    try std.testing.expectEqualStrings(test_data, mmap.slice(0, test_data.len));

    // Cleanup
    try std.fs.cwd().deleteFile("/tmp/mmap_test.bin");
}

test "benchmark_mmap_vs_read" {
    const allocator = std.testing.allocator;

    // Create a test file (1MB)
    const file_size: usize = 1024 * 1024;
    const test_path = "/tmp/mmap_bench.bin";
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        const data = try allocator.alloc(u8, file_size);
        defer allocator.free(data);
        for (data, 0..) |*b, i| b.* = @truncate(i);
        try file.writeAll(data);
    }
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const iterations: usize = 100;

    // Benchmark standard file read
    var timer = std.time.Timer.start() catch unreachable;
    for (0..iterations) |_| {
        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();
        const data = try allocator.alloc(u8, file_size);
        defer allocator.free(data);
        _ = try file.readAll(data);
        std.mem.doNotOptimizeAway(data);
    }
    const read_time = timer.read();

    // Benchmark mmap
    timer.reset();
    for (0..iterations) |_| {
        var mmap = try MmapFile.init(test_path);
        defer mmap.deinit();
        // Access first and last byte to ensure mapping is established
        std.mem.doNotOptimizeAway(mmap.data[0]);
        std.mem.doNotOptimizeAway(mmap.data[file_size - 1]);
    }
    const mmap_time = timer.read();

    const read_us = @as(f64, @floatFromInt(read_time)) / @as(f64, @floatFromInt(iterations)) / 1000.0;
    const mmap_us = @as(f64, @floatFromInt(mmap_time)) / @as(f64, @floatFromInt(iterations)) / 1000.0;
    const speedup = read_us / mmap_us;

    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           MMAP vs READ BENCHMARK (1MB file)                 ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  File read:   {d:>10.1} us/iter                            ║\n", .{read_us});
    std.debug.print("║  mmap:        {d:>10.1} us/iter                            ║\n", .{mmap_us});
    std.debug.print("║  Speedup:     {d:>10.1}x                                   ║\n", .{speedup});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    try std.testing.expect(true);
}
