// TRINITY FORMAT (.tri) - Бинарный формат троичных моделей
// Упакованные триты: 4 трита на байт = 16x сжатие
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const prometheus = @import("prometheus_seed.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// FORMAT CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAGIC: [4]u8 = .{ 'T', 'R', 'I', '1' };
pub const VERSION: u32 = 1;
pub const HEADER_SIZE: usize = 64;

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityHeader = struct {
    magic: [4]u8 = MAGIC,
    version: u32 = VERSION,
    total_params: u64 = 0,
    vocab_size: u32 = 0,
    hidden_size: u32 = 0,
    intermediate_size: u32 = 0,
    num_layers: u32 = 0,
    num_heads: u32 = 0,
    num_kv_heads: u32 = 0,
    num_tensors: u32 = 0,
    reserved: [20]u8 = [_]u8{0} ** 20,

    pub fn write(self: *const TrinityHeader, writer: anytype) !void {
        try writer.writeAll(&self.magic);
        try writer.writeInt(u32, self.version, .little);
        try writer.writeInt(u64, self.total_params, .little);
        try writer.writeInt(u32, self.vocab_size, .little);
        try writer.writeInt(u32, self.hidden_size, .little);
        try writer.writeInt(u32, self.intermediate_size, .little);
        try writer.writeInt(u32, self.num_layers, .little);
        try writer.writeInt(u32, self.num_heads, .little);
        try writer.writeInt(u32, self.num_kv_heads, .little);
        try writer.writeInt(u32, self.num_tensors, .little);
        try writer.writeAll(&self.reserved);
    }

    pub fn read(reader: anytype) !TrinityHeader {
        var header = TrinityHeader{};

        _ = try reader.readAll(&header.magic);
        if (!std.mem.eql(u8, &header.magic, &MAGIC)) {
            return error.InvalidMagic;
        }

        header.version = try reader.readInt(u32, .little);
        if (header.version != VERSION) {
            return error.UnsupportedVersion;
        }

        header.total_params = try reader.readInt(u64, .little);
        header.vocab_size = try reader.readInt(u32, .little);
        header.hidden_size = try reader.readInt(u32, .little);
        header.intermediate_size = try reader.readInt(u32, .little);
        header.num_layers = try reader.readInt(u32, .little);
        header.num_heads = try reader.readInt(u32, .little);
        header.num_kv_heads = try reader.readInt(u32, .little);
        header.num_tensors = try reader.readInt(u32, .little);
        _ = try reader.readAll(&header.reserved);

        return header;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR INDEX ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const TensorIndexEntry = struct {
    name: []const u8,
    shape: []const u32,
    data_offset: u64,
    data_size: u64,

    pub fn write(self: *const TensorIndexEntry, writer: anytype) !void {
        // Name
        try writer.writeInt(u32, @intCast(self.name.len), .little);
        try writer.writeAll(self.name);

        // Shape
        try writer.writeInt(u32, @intCast(self.shape.len), .little);
        for (self.shape) |dim| {
            try writer.writeInt(u32, dim, .little);
        }

        // Offsets
        try writer.writeInt(u64, self.data_offset, .little);
        try writer.writeInt(u64, self.data_size, .little);
    }

    pub fn read(allocator: std.mem.Allocator, reader: anytype) !TensorIndexEntry {
        // Name
        const name_len = try reader.readInt(u32, .little);
        const name = try allocator.alloc(u8, name_len);
        _ = try reader.readAll(name);

        // Shape
        const num_dims = try reader.readInt(u32, .little);
        const shape = try allocator.alloc(u32, num_dims);
        for (shape) |*dim| {
            dim.* = try reader.readInt(u32, .little);
        }

        // Offsets
        const data_offset = try reader.readInt(u64, .little);
        const data_size = try reader.readInt(u64, .little);

        return TensorIndexEntry{
            .name = name,
            .shape = shape,
            .data_offset = data_offset,
            .data_size = data_size,
        };
    }

    pub fn deinit(self: *TensorIndexEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.shape);
    }

    pub fn numElements(self: *const TensorIndexEntry) usize {
        var total: usize = 1;
        for (self.shape) |dim| {
            total *= dim;
        }
        return total;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT PACKING - 4 трита на байт
// ═══════════════════════════════════════════════════════════════════════════════

/// Упаковка тритов: 4 трита на байт
/// trit value: -1 -> 0, 0 -> 1, +1 -> 2
pub fn packTrits(allocator: std.mem.Allocator, trits: []const prometheus.TritWeight) ![]u8 {
    const packed_size = (trits.len + 3) / 4;
    const result = try allocator.alloc(u8, packed_size);
    @memset(result, 0);

    for (trits, 0..) |trit, i| {
        const byte_idx = i / 4;
        const bit_offset: u3 = @intCast((i % 4) * 2);
        const value: u8 = @intCast(@as(i8, trit.toInt()) + 1); // -1->0, 0->1, +1->2
        result[byte_idx] |= value << bit_offset;
    }

    return result;
}

/// Распаковка тритов
pub fn unpackTrits(allocator: std.mem.Allocator, packed_data: []const u8, num_trits: usize) ![]prometheus.TritWeight {
    const trits = try allocator.alloc(prometheus.TritWeight, num_trits);

    for (0..num_trits) |i| {
        const byte_idx = i / 4;
        const bit_offset: u3 = @intCast((i % 4) * 2);
        const value: u8 = (packed_data[byte_idx] >> bit_offset) & 0x3;
        const trit_val: i8 = @as(i8, @intCast(value)) - 1; // 0->-1, 1->0, 2->+1

        trits[i] = switch (trit_val) {
            -1 => .neg,
            0 => .zero,
            1 => .pos,
            else => .zero,
        };
    }

    return trits;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FILE WRITER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityWriter = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    header: TrinityHeader,
    index: std.ArrayList(TensorIndexEntry),
    data_buffer: std.ArrayList(u8),
    current_offset: u64,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !TrinityWriter {
        const file = try std.fs.cwd().createFile(path, .{});

        return TrinityWriter{
            .allocator = allocator,
            .file = file,
            .header = TrinityHeader{},
            .index = std.ArrayList(TensorIndexEntry).init(allocator),
            .data_buffer = std.ArrayList(u8).init(allocator),
            .current_offset = 0,
        };
    }

    pub fn deinit(self: *TrinityWriter) void {
        self.file.close();
        for (self.index.items) |*entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.shape);
        }
        self.index.deinit();
        self.data_buffer.deinit();
    }

    pub fn setConfig(
        self: *TrinityWriter,
        vocab_size: u32,
        hidden_size: u32,
        intermediate_size: u32,
        num_layers: u32,
        num_heads: u32,
        num_kv_heads: u32,
    ) void {
        self.header.vocab_size = vocab_size;
        self.header.hidden_size = hidden_size;
        self.header.intermediate_size = intermediate_size;
        self.header.num_layers = num_layers;
        self.header.num_heads = num_heads;
        self.header.num_kv_heads = num_kv_heads;
    }

    /// Добавление тензора
    pub fn addTensor(self: *TrinityWriter, name: []const u8, shape: []const usize, trits: []const prometheus.TritWeight) !void {
        // Упаковываем триты
        const packed_trits = try packTrits(self.allocator, trits);
        defer self.allocator.free(packed_trits);

        // Копируем shape
        const shape_u32 = try self.allocator.alloc(u32, shape.len);
        for (shape, 0..) |dim, i| {
            shape_u32[i] = @intCast(dim);
        }

        // Создаём запись индекса
        const entry = TensorIndexEntry{
            .name = try self.allocator.dupe(u8, name),
            .shape = shape_u32,
            .data_offset = self.current_offset,
            .data_size = packed_trits.len,
        };

        try self.index.append(entry);

        // Добавляем данные в буфер
        try self.data_buffer.appendSlice(packed_trits);
        self.current_offset += packed_trits.len;

        // Обновляем статистику
        self.header.total_params += trits.len;
        self.header.num_tensors += 1;
    }

    /// Финализация и запись файла
    pub fn finalize(self: *TrinityWriter) !void {
        const writer = self.file.writer();

        // 1. Записываем заголовок
        try self.header.write(writer);

        // 2. Записываем индекс
        for (self.index.items) |*entry| {
            try entry.write(writer);
        }

        // 3. Записываем данные
        try writer.writeAll(self.data_buffer.items);

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY FILE WRITTEN                               ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Total params:     {d:>12}                               ║\n", .{self.header.total_params});
        std.debug.print("║ Num tensors:      {d:>12}                               ║\n", .{self.header.num_tensors});
        std.debug.print("║ Data size:        {d:>12} bytes                         ║\n", .{self.data_buffer.items.len});
        std.debug.print("║ Compression:      16x (2 bits per trit)                      ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FILE READER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityReader = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    header: TrinityHeader,
    index: std.ArrayList(TensorIndexEntry),
    data_start: u64,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !TrinityReader {
        const file = try std.fs.cwd().openFile(path, .{});
        const reader = file.reader();

        // Читаем заголовок
        const header = try TrinityHeader.read(reader);

        // Читаем индекс
        var index = std.ArrayList(TensorIndexEntry).init(allocator);
        for (0..header.num_tensors) |_| {
            const entry = try TensorIndexEntry.read(allocator, reader);
            try index.append(entry);
        }

        // Запоминаем начало данных
        const data_start = try file.getPos();

        return TrinityReader{
            .allocator = allocator,
            .file = file,
            .header = header,
            .index = index,
            .data_start = data_start,
        };
    }

    pub fn deinit(self: *TrinityReader) void {
        self.file.close();
        for (self.index.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.index.deinit();
    }

    /// Получение тензора по имени
    pub fn getTensor(self: *TrinityReader, name: []const u8) ![]prometheus.TritWeight {
        // Ищем в индексе
        for (self.index.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return self.readTensorData(&entry);
            }
        }
        return error.TensorNotFound;
    }

    /// Получение тензора по индексу
    pub fn getTensorByIndex(self: *TrinityReader, idx: usize) ![]prometheus.TritWeight {
        if (idx >= self.index.items.len) return error.IndexOutOfBounds;
        return self.readTensorData(&self.index.items[idx]);
    }

    fn readTensorData(self: *TrinityReader, entry: *const TensorIndexEntry) ![]prometheus.TritWeight {
        // Переходим к данным
        try self.file.seekTo(self.data_start + entry.data_offset);

        // Читаем упакованные данные
        const packed_bytes = try self.allocator.alloc(u8, entry.data_size);
        defer self.allocator.free(packed_bytes);
        _ = try self.file.reader().readAll(packed_bytes);

        // Распаковываем
        const num_elements = entry.numElements();
        return unpackTrits(self.allocator, packed_bytes, num_elements);
    }

    /// Список всех тензоров
    pub fn listTensors(self: *const TrinityReader) []const TensorIndexEntry {
        return self.index.items;
    }

    /// Печать информации
    pub fn printInfo(self: *const TrinityReader) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY MODEL INFO                                 ║\n", .{});
        std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Version:          {d:>12}                               ║\n", .{self.header.version});
        std.debug.print("║ Total params:     {d:>12}                               ║\n", .{self.header.total_params});
        std.debug.print("║ Vocab size:       {d:>12}                               ║\n", .{self.header.vocab_size});
        std.debug.print("║ Hidden size:      {d:>12}                               ║\n", .{self.header.hidden_size});
        std.debug.print("║ Intermediate:     {d:>12}                               ║\n", .{self.header.intermediate_size});
        std.debug.print("║ Num layers:       {d:>12}                               ║\n", .{self.header.num_layers});
        std.debug.print("║ Num heads:        {d:>12}                               ║\n", .{self.header.num_heads});
        std.debug.print("║ Num KV heads:     {d:>12}                               ║\n", .{self.header.num_kv_heads});
        std.debug.print("║ Num tensors:      {d:>12}                               ║\n", .{self.header.num_tensors});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});

        for (self.index.items) |entry| {
            var shape_buf: [64]u8 = undefined;
            var shape_len: usize = 0;
            shape_buf[shape_len] = '[';
            shape_len += 1;
            for (entry.shape, 0..) |dim, i| {
                if (i > 0) {
                    shape_buf[shape_len] = ',';
                    shape_len += 1;
                }
                const dim_str = std.fmt.bufPrint(shape_buf[shape_len..], "{d}", .{dim}) catch break;
                shape_len += dim_str.len;
            }
            shape_buf[shape_len] = ']';
            shape_len += 1;

            std.debug.print("║ {s:<30} {s:<20} ║\n", .{
                entry.name[0..@min(entry.name.len, 30)],
                shape_buf[0..shape_len],
            });
        }

        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "pack and unpack trits" {
    const allocator = std.testing.allocator;

    const trits = [_]prometheus.TritWeight{ .pos, .neg, .zero, .pos, .neg, .neg, .zero, .pos };

    const packed_data = try packTrits(allocator, &trits);
    defer allocator.free(packed_data);

    try std.testing.expectEqual(@as(usize, 2), packed_data.len); // 8 trits = 2 bytes

    const unpacked = try unpackTrits(allocator, packed_data, trits.len);
    defer allocator.free(unpacked);

    for (trits, unpacked) |expected, actual| {
        try std.testing.expectEqual(expected, actual);
    }
}

test "header write and read" {
    const allocator = std.testing.allocator;

    var header = TrinityHeader{
        .total_params = 1000000,
        .vocab_size = 32000,
        .hidden_size = 4096,
        .num_layers = 32,
    };

    // Записываем в буфер
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try header.write(buffer.writer());

    // Читаем обратно
    var stream = std.io.fixedBufferStream(buffer.items);
    const read_header = try TrinityHeader.read(stream.reader());

    try std.testing.expectEqual(header.total_params, read_header.total_params);
    try std.testing.expectEqual(header.vocab_size, read_header.vocab_size);
    try std.testing.expectEqual(header.hidden_size, read_header.hidden_size);
    try std.testing.expectEqual(header.num_layers, read_header.num_layers);
}

test "tensor index entry" {
    _ = std.testing.allocator; // unused but kept for consistency

    const shape = [_]u32{ 256, 64 };
    const entry = TensorIndexEntry{
        .name = "test_tensor",
        .shape = &shape,
        .data_offset = 0,
        .data_size = 4096,
    };

    try std.testing.expectEqual(@as(usize, 16384), entry.numElements());
}

test "write and read trinity file" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_trinity.tri";

    // Create test data
    const trits = [_]prometheus.TritWeight{ .pos, .neg, .zero, .pos, .neg, .neg, .zero, .pos, .pos, .zero, .neg, .pos };
    const shape = [_]usize{ 3, 4 };

    // Write
    {
        var writer = try TrinityWriter.init(allocator, test_path);
        defer writer.deinit();

        writer.setConfig(32000, 4096, 11008, 32, 32, 8);
        try writer.addTensor("test_layer", &shape, &trits);
        try writer.finalize();
    }

    // Read back
    {
        var reader = try TrinityReader.init(allocator, test_path);
        defer reader.deinit();

        // Verify header
        try std.testing.expectEqual(@as(u32, 32000), reader.header.vocab_size);
        try std.testing.expectEqual(@as(u32, 4096), reader.header.hidden_size);
        try std.testing.expectEqual(@as(u32, 1), reader.header.num_tensors);

        // Verify tensor
        const loaded = try reader.getTensor("test_layer");
        defer allocator.free(loaded);

        try std.testing.expectEqual(trits.len, loaded.len);
        for (trits, loaded) |expected, actual| {
            try std.testing.expectEqual(expected, actual);
        }
    }

    // Cleanup
    std.fs.cwd().deleteFile(test_path) catch {};
}
