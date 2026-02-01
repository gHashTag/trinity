// SAFETENSORS PARSER - Парсер формата Safetensors
// Загрузка весов нейросетей из .safetensors файлов
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// SAFETENSORS FORMAT
// ═══════════════════════════════════════════════════════════════════════════════
//
// Формат файла:
// [8 байт]  - размер заголовка (u64 little-endian)
// [N байт]  - JSON заголовок с метаданными
// [остаток] - сырые данные тензоров
//
// JSON заголовок:
// {
//   "tensor_name": {
//     "dtype": "F32",
//     "shape": [dim1, dim2, ...],
//     "data_offsets": [start, end]
//   },
//   ...
// }
// ═══════════════════════════════════════════════════════════════════════════════

pub const DType = enum {
    F16,
    BF16,
    F32,
    F64,
    I8,
    I16,
    I32,
    I64,
    U8,
    U16,
    U32,
    U64,
    BOOL,

    pub fn fromString(s: []const u8) ?DType {
        if (std.mem.eql(u8, s, "F16")) return .F16;
        if (std.mem.eql(u8, s, "BF16")) return .BF16;
        if (std.mem.eql(u8, s, "F32")) return .F32;
        if (std.mem.eql(u8, s, "F64")) return .F64;
        if (std.mem.eql(u8, s, "I8")) return .I8;
        if (std.mem.eql(u8, s, "I16")) return .I16;
        if (std.mem.eql(u8, s, "I32")) return .I32;
        if (std.mem.eql(u8, s, "I64")) return .I64;
        if (std.mem.eql(u8, s, "U8")) return .U8;
        if (std.mem.eql(u8, s, "U16")) return .U16;
        if (std.mem.eql(u8, s, "U32")) return .U32;
        if (std.mem.eql(u8, s, "U64")) return .U64;
        if (std.mem.eql(u8, s, "BOOL")) return .BOOL;
        return null;
    }

    pub fn byteSize(self: DType) usize {
        return switch (self) {
            .F16, .BF16, .I16, .U16 => 2,
            .F32, .I32, .U32 => 4,
            .F64, .I64, .U64 => 8,
            .I8, .U8, .BOOL => 1,
        };
    }
};

pub const TensorInfo = struct {
    name: []const u8,
    dtype: DType,
    shape: []const usize,
    data_offset_start: usize,
    data_offset_end: usize,

    pub fn numElements(self: *const TensorInfo) usize {
        var total: usize = 1;
        for (self.shape) |dim| {
            total *= dim;
        }
        return total;
    }

    pub fn byteSize(self: *const TensorInfo) usize {
        return self.numElements() * self.dtype.byteSize();
    }
};

pub const SafetensorsFile = struct {
    allocator: std.mem.Allocator,
    tensors: std.StringHashMap(TensorInfo),
    header_size: usize,
    data: []const u8,
    file_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) SafetensorsFile {
        return SafetensorsFile{
            .allocator = allocator,
            .tensors = std.StringHashMap(TensorInfo).init(allocator),
            .header_size = 0,
            .data = &[_]u8{},
            .file_path = "",
        };
    }

    pub fn deinit(self: *SafetensorsFile) void {
        var it = self.tensors.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.shape);
        }
        self.tensors.deinit();
        if (self.data.len > 0) {
            self.allocator.free(self.data);
        }
    }

    /// Открытие и парсинг safetensors файла
    pub fn open(allocator: std.mem.Allocator, path: []const u8) !SafetensorsFile {
        var self = SafetensorsFile.init(allocator);
        errdefer self.deinit();

        self.file_path = path;

        // Читаем файл
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        self.data = try allocator.alloc(u8, file_size);
        _ = try file.readAll(@constCast(self.data));

        // Парсим заголовок
        if (self.data.len < 8) return error.InvalidFormat;

        // Размер заголовка (little-endian u64)
        self.header_size = std.mem.readInt(u64, self.data[0..8], .little);

        if (self.header_size + 8 > self.data.len) return error.InvalidFormat;

        // JSON заголовок
        const header_json = self.data[8 .. 8 + self.header_size];

        // Парсим JSON
        try self.parseHeader(header_json);

        return self;
    }

    fn parseHeader(self: *SafetensorsFile, json_data: []const u8) !void {
        // Простой парсер JSON для safetensors
        // Формат: {"tensor_name": {"dtype": "F32", "shape": [d1, d2], "data_offsets": [start, end]}, ...}

        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json_data,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidFormat;

        var it = root.object.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            // Пропускаем __metadata__
            if (std.mem.eql(u8, name, "__metadata__")) continue;

            if (value != .object) continue;

            const tensor_obj = value.object;

            // dtype
            const dtype_val = tensor_obj.get("dtype") orelse continue;
            if (dtype_val != .string) continue;
            const dtype = DType.fromString(dtype_val.string) orelse continue;

            // shape
            const shape_val = tensor_obj.get("shape") orelse continue;
            if (shape_val != .array) continue;
            var shape = try self.allocator.alloc(usize, shape_val.array.items.len);
            for (shape_val.array.items, 0..) |dim, i| {
                if (dim != .integer) {
                    self.allocator.free(shape);
                    continue;
                }
                shape[i] = @intCast(dim.integer);
            }

            // data_offsets
            const offsets_val = tensor_obj.get("data_offsets") orelse {
                self.allocator.free(shape);
                continue;
            };
            if (offsets_val != .array or offsets_val.array.items.len != 2) {
                self.allocator.free(shape);
                continue;
            }
            const start: usize = @intCast(offsets_val.array.items[0].integer);
            const end: usize = @intCast(offsets_val.array.items[1].integer);

            const name_copy = try self.allocator.dupe(u8, name);

            try self.tensors.put(name_copy, TensorInfo{
                .name = name_copy,
                .dtype = dtype,
                .shape = shape,
                .data_offset_start = start,
                .data_offset_end = end,
            });
        }
    }

    /// Получение сырых данных тензора
    pub fn getTensorData(self: *const SafetensorsFile, name: []const u8) ?[]const u8 {
        const info = self.tensors.get(name) orelse return null;
        const data_start = 8 + self.header_size + info.data_offset_start;
        const data_end = 8 + self.header_size + info.data_offset_end;

        if (data_end > self.data.len) return null;

        return self.data[data_start..data_end];
    }

    /// Получение тензора как float32
    pub fn getTensorF32(self: *const SafetensorsFile, allocator: std.mem.Allocator, name: []const u8) ![]f32 {
        const info = self.tensors.get(name) orelse return error.TensorNotFound;
        const raw_data = self.getTensorData(name) orelse return error.TensorNotFound;

        const num_elements = info.numElements();
        var result = try allocator.alloc(f32, num_elements);

        switch (info.dtype) {
            .F32 => {
                // Копирование побайтово (без требований к выравниванию)
                for (0..num_elements) |i| {
                    const offset = i * 4;
                    const bytes = raw_data[offset..][0..4];
                    result[i] = @bitCast(bytes.*);
                }
            },
            .F16 => {
                // Конвертация F16 -> F32
                for (0..num_elements) |i| {
                    const offset = i * 2;
                    const bytes = raw_data[offset..][0..2];
                    const f16_val: f16 = @bitCast(bytes.*);
                    result[i] = @floatCast(f16_val);
                }
            },
            .BF16 => {
                // Конвертация BF16 -> F32
                for (0..num_elements) |i| {
                    const offset = i * 2;
                    const bytes = raw_data[offset..][0..2];
                    const u16_val: u16 = @bitCast(bytes.*);
                    // BF16: верхние 16 бит F32
                    const bits: u32 = @as(u32, u16_val) << 16;
                    result[i] = @bitCast(bits);
                }
            },
            else => {
                allocator.free(result);
                return error.UnsupportedDType;
            },
        }

        return result;
    }

    /// Список всех тензоров
    pub fn listTensors(self: *const SafetensorsFile) !std.ArrayList([]const u8) {
        var list = std.ArrayList([]const u8).init(self.allocator);
        var it = self.tensors.keyIterator();
        while (it.next()) |key| {
            try list.append(key.*);
        }
        return list;
    }

    /// Печать информации о файле
    pub fn printInfo(self: *const SafetensorsFile) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           SAFETENSORS FILE INFO                              ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ File: {s:<54} ║\n", .{self.file_path});
        std.debug.print("║ Header size: {d:<47} ║\n", .{self.header_size});
        std.debug.print("║ Tensors: {d:<51} ║\n", .{self.tensors.count()});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});

        var total_params: usize = 0;
        var it = self.tensors.iterator();
        while (it.next()) |entry| {
            const info = entry.value_ptr.*;
            const params = info.numElements();
            total_params += params;

            // Форматируем shape
            var shape_buf: [64]u8 = undefined;
            var shape_len: usize = 0;
            shape_buf[shape_len] = '[';
            shape_len += 1;
            for (info.shape, 0..) |dim, i| {
                if (i > 0) {
                    shape_buf[shape_len] = ',';
                    shape_len += 1;
                }
                const dim_str = std.fmt.bufPrint(shape_buf[shape_len..], "{d}", .{dim}) catch break;
                shape_len += dim_str.len;
            }
            shape_buf[shape_len] = ']';
            shape_len += 1;

            std.debug.print("║ {s:<30} {s:<20} {d:>8} ║\n", .{
                info.name[0..@min(info.name.len, 30)],
                shape_buf[0..shape_len],
                params,
            });
        }

        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Total parameters: {d:<42} ║\n", .{total_params});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "dtype from string" {
    try std.testing.expectEqual(DType.F32, DType.fromString("F32").?);
    try std.testing.expectEqual(DType.F16, DType.fromString("F16").?);
    try std.testing.expectEqual(DType.BF16, DType.fromString("BF16").?);
    try std.testing.expect(DType.fromString("INVALID") == null);
}

test "dtype byte size" {
    try std.testing.expectEqual(@as(usize, 4), DType.F32.byteSize());
    try std.testing.expectEqual(@as(usize, 2), DType.F16.byteSize());
    try std.testing.expectEqual(@as(usize, 8), DType.F64.byteSize());
}

test "safetensors file init" {
    var sf = SafetensorsFile.init(std.testing.allocator);
    defer sf.deinit();

    try std.testing.expectEqual(@as(usize, 0), sf.tensors.count());
}

test "tensor info num elements" {
    const shape = [_]usize{ 2, 3, 4 };
    const info = TensorInfo{
        .name = "test",
        .dtype = .F32,
        .shape = &shape,
        .data_offset_start = 0,
        .data_offset_end = 96,
    };

    try std.testing.expectEqual(@as(usize, 24), info.numElements());
    try std.testing.expectEqual(@as(usize, 96), info.byteSize());
}
