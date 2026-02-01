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
    BF16 = 30,
    _,
};

// Block sizes for quantization types
pub fn getBlockSize(t: GGMLType) usize {
    return switch (t) {
        .Q4_0, .Q4_1, .Q5_0, .Q5_1, .Q8_0, .Q8_1 => 32,
        .Q2_K, .Q3_K, .Q4_K, .Q5_K, .Q6_K, .Q8_K => 256,
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
        else => 0,
    };
}

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
