// ═══════════════════════════════════════════════════════════════════════════════
// WASM BINARY PARSER - Parse WebAssembly binaries for B2T conversion
// Part of ЖАР ПТИЦА (FIREBIRD) - Ternary Virtual Anti-Detect Browser
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const b2t = @import("b2t_integration.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// WASM CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const WASM_MAGIC: [4]u8 = .{ 0x00, 0x61, 0x73, 0x6D }; // \0asm
pub const WASM_VERSION: [4]u8 = .{ 0x01, 0x00, 0x00, 0x00 }; // version 1

pub const SectionId = enum(u8) {
    custom = 0,
    type_section = 1,
    import_section = 2,
    function_section = 3,
    table_section = 4,
    memory_section = 5,
    global_section = 6,
    export_section = 7,
    start_section = 8,
    element_section = 9,
    code_section = 10,
    data_section = 11,
    data_count_section = 12,
};

pub const ValueType = enum(u8) {
    i32 = 0x7F,
    i64 = 0x7E,
    f32 = 0x7D,
    f64 = 0x7C,
    funcref = 0x70,
    externref = 0x6F,
};

// ═══════════════════════════════════════════════════════════════════════════════
// WASM STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const WasmFunction = struct {
    type_idx: u32,
    locals: std.ArrayList(ValueType),
    code: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, type_idx: u32) WasmFunction {
        return WasmFunction{
            .type_idx = type_idx,
            .locals = std.ArrayList(ValueType).init(allocator),
            .code = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *WasmFunction) void {
        self.locals.deinit();
        self.code.deinit();
    }
};

pub const WasmFuncType = struct {
    params: std.ArrayList(ValueType),
    results: std.ArrayList(ValueType),

    pub fn init(allocator: std.mem.Allocator) WasmFuncType {
        return WasmFuncType{
            .params = std.ArrayList(ValueType).init(allocator),
            .results = std.ArrayList(ValueType).init(allocator),
        };
    }

    pub fn deinit(self: *WasmFuncType) void {
        self.params.deinit();
        self.results.deinit();
    }
};

pub const WasmModule = struct {
    allocator: std.mem.Allocator,
    types: std.ArrayList(WasmFuncType),
    functions: std.ArrayList(WasmFunction),
    func_type_indices: std.ArrayList(u32),
    memory_min: u32,
    memory_max: ?u32,

    pub fn init(allocator: std.mem.Allocator) WasmModule {
        return WasmModule{
            .allocator = allocator,
            .types = std.ArrayList(WasmFuncType).init(allocator),
            .functions = std.ArrayList(WasmFunction).init(allocator),
            .func_type_indices = std.ArrayList(u32).init(allocator),
            .memory_min = 0,
            .memory_max = null,
        };
    }

    pub fn deinit(self: *WasmModule) void {
        for (self.types.items) |*t| {
            t.deinit();
        }
        self.types.deinit();

        for (self.functions.items) |*f| {
            f.deinit();
        }
        self.functions.deinit();

        self.func_type_indices.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WASM PARSER
// ═══════════════════════════════════════════════════════════════════════════════

pub const WasmParser = struct {
    allocator: std.mem.Allocator,
    data: []const u8,
    pos: usize,

    pub fn init(allocator: std.mem.Allocator, data: []const u8) WasmParser {
        return WasmParser{
            .allocator = allocator,
            .data = data,
            .pos = 0,
        };
    }

    /// Parse WASM binary into WasmModule
    pub fn parse(self: *WasmParser) !WasmModule {
        var module = WasmModule.init(self.allocator);
        errdefer module.deinit();

        // Verify magic number
        if (self.data.len < 8) return error.InvalidWasm;
        if (!std.mem.eql(u8, self.data[0..4], &WASM_MAGIC)) return error.InvalidMagic;
        if (!std.mem.eql(u8, self.data[4..8], &WASM_VERSION)) return error.InvalidVersion;
        self.pos = 8;

        // Parse sections
        while (self.pos < self.data.len) {
            const section_id = self.readByte() orelse break;
            const section_size = try self.readLEB128u32();
            const section_end = self.pos + section_size;

            switch (@as(SectionId, @enumFromInt(section_id))) {
                .type_section => try self.parseTypeSection(&module),
                .function_section => try self.parseFunctionSection(&module),
                .memory_section => try self.parseMemorySection(&module),
                .code_section => try self.parseCodeSection(&module),
                else => {
                    // Skip unknown sections
                    self.pos = section_end;
                },
            }

            // Ensure we're at section end
            if (self.pos < section_end) {
                self.pos = section_end;
            }
        }

        return module;
    }

    fn parseTypeSection(self: *WasmParser, module: *WasmModule) !void {
        const count = try self.readLEB128u32();

        for (0..count) |_| {
            const form = self.readByte() orelse return error.UnexpectedEnd;
            if (form != 0x60) return error.InvalidFuncType; // 0x60 = func type

            var func_type = WasmFuncType.init(self.allocator);
            errdefer func_type.deinit();

            // Parse params
            const param_count = try self.readLEB128u32();
            for (0..param_count) |_| {
                const vtype = self.readByte() orelse return error.UnexpectedEnd;
                try func_type.params.append(@enumFromInt(vtype));
            }

            // Parse results
            const result_count = try self.readLEB128u32();
            for (0..result_count) |_| {
                const vtype = self.readByte() orelse return error.UnexpectedEnd;
                try func_type.results.append(@enumFromInt(vtype));
            }

            try module.types.append(func_type);
        }
    }

    fn parseFunctionSection(self: *WasmParser, module: *WasmModule) !void {
        const count = try self.readLEB128u32();

        for (0..count) |_| {
            const type_idx = try self.readLEB128u32();
            try module.func_type_indices.append(type_idx);
        }
    }

    fn parseMemorySection(self: *WasmParser, module: *WasmModule) !void {
        const count = try self.readLEB128u32();
        if (count == 0) return;

        const flags = self.readByte() orelse return error.UnexpectedEnd;
        module.memory_min = try self.readLEB128u32();

        if (flags & 0x01 != 0) {
            module.memory_max = try self.readLEB128u32();
        }
    }

    fn parseCodeSection(self: *WasmParser, module: *WasmModule) !void {
        const count = try self.readLEB128u32();

        for (0..count) |i| {
            const func_size = try self.readLEB128u32();
            const func_end = self.pos + func_size;

            const type_idx = if (i < module.func_type_indices.items.len)
                module.func_type_indices.items[i]
            else
                0;

            var func = WasmFunction.init(self.allocator, type_idx);
            errdefer func.deinit();

            // Parse locals
            const local_count = try self.readLEB128u32();
            for (0..local_count) |_| {
                const n = try self.readLEB128u32();
                const vtype = self.readByte() orelse return error.UnexpectedEnd;
                for (0..n) |_| {
                    try func.locals.append(@enumFromInt(vtype));
                }
            }

            // Copy code bytes
            const code_len = func_end - self.pos;
            for (0..code_len) |_| {
                const byte = self.readByte() orelse break;
                try func.code.append(byte);
            }

            try module.functions.append(func);
            self.pos = func_end;
        }
    }

    fn readByte(self: *WasmParser) ?u8 {
        if (self.pos >= self.data.len) return null;
        const b = self.data[self.pos];
        self.pos += 1;
        return b;
    }

    fn readLEB128u32(self: *WasmParser) !u32 {
        var result: u32 = 0;
        var shift: u5 = 0;

        while (true) {
            const byte = self.readByte() orelse return error.UnexpectedEnd;
            result |= @as(u32, byte & 0x7F) << shift;

            if (byte & 0x80 == 0) break;
            shift +%= 7;
            if (shift > 28) return error.LEB128Overflow;
        }

        return result;
    }

    fn readLEB128i32(self: *WasmParser) !i32 {
        var result: i32 = 0;
        var shift: u5 = 0;
        var byte: u8 = 0;

        while (true) {
            byte = self.readByte() orelse return error.UnexpectedEnd;
            result |= @as(i32, @intCast(byte & 0x7F)) << shift;
            shift +%= 7;

            if (byte & 0x80 == 0) break;
            if (shift > 28) return error.LEB128Overflow;
        }

        // Sign extend
        if (shift < 32 and (byte & 0x40) != 0) {
            result |= @as(i32, -1) << shift;
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WASM TO TVC CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const WasmToTVC = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) WasmToTVC {
        return WasmToTVC{ .allocator = allocator };
    }

    /// Convert WasmModule to TVCModule
    pub fn convert(self: *WasmToTVC, wasm: *const WasmModule, name: []const u8) !b2t.TVCModule {
        var tvc = b2t.TVCModule.init(self.allocator, name);
        errdefer tvc.deinit();

        // Convert each function to a TVC block
        for (wasm.functions.items, 0..) |*func, i| {
            var label_buf: [32]u8 = undefined;
            const label = std.fmt.bufPrint(&label_buf, "func_{d}", .{i}) catch "func";

            const block = try tvc.addBlock(label);
            try self.convertFunction(func, block);
        }

        return tvc;
    }

    fn convertFunction(self: *WasmToTVC, func: *const WasmFunction, block: *b2t.TVCBlock) !void {
        _ = self;
        var pos: usize = 0;

        while (pos < func.code.items.len) {
            const opcode = func.code.items[pos];
            pos += 1;

            // Read operand if needed
            var operand: i32 = 0;
            if (needsOperand(opcode)) {
                const result = readLEB128i32FromSlice(func.code.items[pos..]);
                operand = result.value;
                pos += result.bytes_read;
            }

            const instr = b2t.liftWasmOpcode(opcode, operand);
            try block.addInstruction(instr);

            // Stop at end opcode
            if (opcode == 0x0B) break;
        }
    }
};

fn needsOperand(opcode: u8) bool {
    return switch (opcode) {
        0x0C, 0x0D, 0x10 => true, // br, br_if, call
        0x20, 0x21, 0x22, 0x23, 0x24 => true, // local.get/set/tee, global.get/set
        0x28, 0x36 => true, // i32.load, i32.store (simplified)
        0x41 => true, // i32.const
        else => false,
    };
}

fn readLEB128i32FromSlice(data: []const u8) struct { value: i32, bytes_read: usize } {
    var result: i32 = 0;
    var shift: u5 = 0;
    var byte: u8 = 0;
    var bytes_read: usize = 0;

    for (data) |b| {
        byte = b;
        bytes_read += 1;
        result |= @as(i32, @intCast(byte & 0x7F)) << shift;
        shift +%= 7;

        if (byte & 0x80 == 0) break;
        if (shift > 28) break;
    }

    // Sign extend
    if (shift < 32 and (byte & 0x40) != 0) {
        result |= @as(i32, -1) << shift;
    }

    return .{ .value = result, .bytes_read = bytes_read };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE I/O
// ═══════════════════════════════════════════════════════════════════════════════

/// Load WASM file from disk
pub fn loadWasmFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(data);

    const bytes_read = try file.readAll(data);
    if (bytes_read != stat.size) {
        return error.IncompleteRead;
    }

    return data;
}

/// Save TVC IR to file (simple binary format)
pub fn saveTVCFile(allocator: std.mem.Allocator, module: *const b2t.TVCModule, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var writer = file.writer();

    // Write header
    try writer.writeAll("TVC1"); // Magic
    try writer.writeInt(u32, @intCast(module.blocks.items.len), .little);

    // Write each block
    for (module.blocks.items) |*block| {
        // Write label length and label
        try writer.writeInt(u16, @intCast(block.label.len), .little);
        try writer.writeAll(block.label);

        // Write instruction count
        try writer.writeInt(u32, @intCast(block.instructions.items.len), .little);

        // Write instructions
        for (block.instructions.items) |*instr| {
            try writer.writeByte(@intFromEnum(instr.opcode));
            try writer.writeInt(i32, instr.operand1, .little);
            try writer.writeInt(i32, instr.operand2, .little);
            try writer.writeInt(i32, instr.operand3, .little);
        }
    }

    _ = allocator;
}

/// Load TVC IR from file
pub fn loadTVCFile(allocator: std.mem.Allocator, path: []const u8) !b2t.TVCModule {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var reader = file.reader();

    // Read and verify header
    var magic: [4]u8 = undefined;
    _ = try reader.readAll(&magic);
    if (!std.mem.eql(u8, &magic, "TVC1")) {
        return error.InvalidTVCFile;
    }

    const block_count = try reader.readInt(u32, .little);

    var module = b2t.TVCModule.init(allocator, "loaded");
    errdefer module.deinit();

    // Read each block
    for (0..block_count) |_| {
        const label_len = try reader.readInt(u16, .little);
        const label = try allocator.alloc(u8, label_len);
        defer allocator.free(label);
        _ = try reader.readAll(label);

        const block = try module.addBlock(label);

        const instr_count = try reader.readInt(u32, .little);
        for (0..instr_count) |_| {
            const opcode_byte = try reader.readByte();
            const op1 = try reader.readInt(i32, .little);
            const op2 = try reader.readInt(i32, .little);
            const op3 = try reader.readInt(i32, .little);

            try block.addInstruction(.{
                .opcode = @enumFromInt(opcode_byte),
                .operand1 = op1,
                .operand2 = op2,
                .operand3 = op3,
            });
        }
    }

    return module;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse minimal wasm" {
    const allocator = std.testing.allocator;

    // Minimal valid WASM: magic + version only
    const minimal_wasm = WASM_MAGIC ++ WASM_VERSION;

    var parser = WasmParser.init(allocator, &minimal_wasm);
    var module = try parser.parse();
    defer module.deinit();

    try std.testing.expectEqual(@as(usize, 0), module.functions.items.len);
}

test "parse wasm with type section" {
    const allocator = std.testing.allocator;

    // WASM with one function type: () -> i32
    const wasm_data = WASM_MAGIC ++ WASM_VERSION ++
        [_]u8{
        0x01, // type section
        0x05, // section size
        0x01, // 1 type
        0x60, // func type
        0x00, // 0 params
        0x01, // 1 result
        0x7F, // i32
    };

    var parser = WasmParser.init(allocator, &wasm_data);
    var module = try parser.parse();
    defer module.deinit();

    try std.testing.expectEqual(@as(usize, 1), module.types.items.len);
    try std.testing.expectEqual(@as(usize, 0), module.types.items[0].params.items.len);
    try std.testing.expectEqual(@as(usize, 1), module.types.items[0].results.items.len);
}

test "wasm to tvc conversion" {
    const allocator = std.testing.allocator;

    // Create a simple WASM module manually
    var wasm = WasmModule.init(allocator);
    defer wasm.deinit();

    var func = WasmFunction.init(allocator, 0);
    // i32.const 42, i32.const 10, i32.add, end
    try func.code.append(0x41); // i32.const
    try func.code.append(42); // 42
    try func.code.append(0x41); // i32.const
    try func.code.append(10); // 10
    try func.code.append(0x6A); // i32.add
    try func.code.append(0x0B); // end
    try wasm.functions.append(func);

    var converter = WasmToTVC.init(allocator);
    var tvc = try converter.convert(&wasm, "test");
    defer tvc.deinit();

    try std.testing.expectEqual(@as(usize, 1), tvc.blocks.items.len);
    try std.testing.expect(tvc.blocks.items[0].instructions.items.len >= 3);
}

test "leb128 encoding" {
    // Test small value
    const result1 = readLEB128i32FromSlice(&[_]u8{42});
    try std.testing.expectEqual(@as(i32, 42), result1.value);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_read);

    // Test multi-byte value (624485 = 0xE5 0x8E 0x26)
    const result2 = readLEB128i32FromSlice(&[_]u8{ 0xE5, 0x8E, 0x26 });
    try std.testing.expectEqual(@as(i32, 624485), result2.value);
    try std.testing.expectEqual(@as(usize, 3), result2.bytes_read);
}
