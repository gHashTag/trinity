// B2T Codegen - Binary-to-Ternary Converter
// Generates ternary code (.trit) from TVC IR
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_lifter = @import("b2t_lifter.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT FILE FORMAT
// ═══════════════════════════════════════════════════════════════════════════════
//
// .trit file structure:
// ┌─────────────────────────────────────────┐
// │ Magic: "TRIT" (4 bytes)                 │
// │ Version: 1 (4 bytes)                    │
// │ Flags: (4 bytes)                        │
// │ Entry Point: (4 bytes)                  │
// │ Num Functions: (4 bytes)                │
// │ Num Globals: (4 bytes)                  │
// ├─────────────────────────────────────────┤
// │ Function Table                          │
// │   - Offset (4 bytes)                    │
// │   - Size (4 bytes)                      │
// │   - Num Params (2 bytes)                │
// │   - Num Locals (2 bytes)                │
// ├─────────────────────────────────────────┤
// │ Code Section                            │
// │   - Ternary instructions                │
// └─────────────────────────────────────────┘

pub const TRIT_MAGIC: u32 = 0x54524954; // "TRIT"
pub const TRIT_VERSION: u32 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY INSTRUCTION ENCODING
// ═══════════════════════════════════════════════════════════════════════════════
//
// Each instruction is encoded as balanced ternary:
// - Opcode: 6 trits (729 possible opcodes)
// - Operands: variable length
//
// Trit encoding in bytes: 5 trits per byte (3^5 = 243 < 256)

pub const TritOpcode = enum(u8) {
    // Ternary Logic
    T_NOT = 0,
    T_AND = 1,
    T_OR = 2,
    T_XOR = 3,

    // Arithmetic
    T_ADD = 10,
    T_SUB = 11,
    T_MUL = 12,
    T_DIV = 13,
    T_MOD = 14,
    T_NEG = 15,

    // Comparison (returns trit: -1, 0, +1)
    T_CMP = 20,
    T_EQ = 21,
    T_LT = 22,
    T_GT = 23,

    // Memory
    T_LOAD = 30,
    T_STORE = 31,
    T_ALLOCA = 32,

    // Control
    T_CALL = 40,
    T_RET = 41,
    T_BR = 42,
    T_BR_TRIT = 43, // 3-way branch!
    T_SWITCH = 44,

    // Stack
    T_PUSH = 50,
    T_POP = 51,
    T_DUP = 52,
    T_DROP = 53,

    // Constants
    T_CONST = 60,

    // Special
    T_NOP = 70,
    T_HALT = 71,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODEGEN
// ═══════════════════════════════════════════════════════════════════════════════

pub const Codegen = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    function_offsets: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) Codegen {
        return Codegen{
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
            .function_offsets = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Codegen) void {
        self.output.deinit();
        self.function_offsets.deinit();
    }

    pub fn generate(self: *Codegen, module: *const b2t_lifter.TVCModule) ![]const u8 {
        // Write header
        try self.writeHeader(module);

        // Write function table placeholder
        const func_table_offset = self.output.items.len;
        for (module.functions.items) |_| {
            try self.writeU32(0); // offset placeholder
            try self.writeU32(0); // size placeholder
            try self.writeU16(0); // num params
            try self.writeU16(0); // num locals
        }

        // Generate code for each function
        for (module.functions.items, 0..) |func, i| {
            const func_offset: u32 = @intCast(self.output.items.len);
            try self.function_offsets.append(func_offset);

            const func_size = try self.generateFunction(&func);

            // Update function table
            const table_entry = func_table_offset + i * 12;
            std.mem.writeInt(u32, self.output.items[table_entry..][0..4], func_offset, .little);
            std.mem.writeInt(u32, self.output.items[table_entry + 4 ..][0..4], func_size, .little);
            std.mem.writeInt(u16, self.output.items[table_entry + 8 ..][0..2], @intCast(func.params.items.len), .little);
            std.mem.writeInt(u16, self.output.items[table_entry + 10 ..][0..2], @intCast(func.locals.items.len), .little);
        }

        return self.output.items;
    }

    fn writeHeader(self: *Codegen, module: *const b2t_lifter.TVCModule) !void {
        // Magic
        try self.writeU32(TRIT_MAGIC);

        // Version
        try self.writeU32(TRIT_VERSION);

        // Flags
        try self.writeU32(0);

        // Entry point
        try self.writeU32(module.entry_point orelse 0);

        // Num functions
        try self.writeU32(@intCast(module.functions.items.len));

        // Num globals
        try self.writeU32(@intCast(module.globals.items.len));
    }

    fn generateFunction(self: *Codegen, func: *const b2t_lifter.TVCFunction) !u32 {
        const start_offset = self.output.items.len;

        for (func.blocks.items) |block| {
            for (block.instructions.items) |inst| {
                try self.generateInstruction(&inst);
            }
        }

        // Add function end marker
        try self.writeTritOpcode(.T_RET);
        try self.writeU32(0); // return value 0

        return @intCast(self.output.items.len - start_offset);
    }

    fn generateInstruction(self: *Codegen, inst: *const b2t_lifter.TVCInstruction) !void {
        switch (inst.opcode) {
            .t_const => {
                try self.writeTritOpcode(.T_CONST);
                try self.writeU32(inst.dest orelse 0);
                try self.writeI32(@intCast(inst.operands[0]));
            },

            .t_add => {
                try self.writeTritOpcode(.T_ADD);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_sub => {
                try self.writeTritOpcode(.T_SUB);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_mul => {
                try self.writeTritOpcode(.T_MUL);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_div => {
                try self.writeTritOpcode(.T_DIV);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_and => {
                try self.writeTritOpcode(.T_AND);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_or => {
                try self.writeTritOpcode(.T_OR);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_xor => {
                try self.writeTritOpcode(.T_XOR);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_cmp => {
                try self.writeTritOpcode(.T_CMP);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_eq => {
                try self.writeTritOpcode(.T_EQ);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
                try self.writeU32(inst.operands[1]);
            },

            .t_load => {
                try self.writeTritOpcode(.T_LOAD);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]);
            },

            .t_store => {
                try self.writeTritOpcode(.T_STORE);
                try self.writeU32(inst.operands[0]); // address
                try self.writeU32(inst.operands[1]); // value
            },

            .t_call => {
                try self.writeTritOpcode(.T_CALL);
                try self.writeU32(inst.dest orelse 0);
                try self.writeU32(inst.operands[0]); // function index
            },

            .t_ret => {
                try self.writeTritOpcode(.T_RET);
                try self.writeU32(inst.operands[0]); // return value
            },

            .t_br => {
                try self.writeTritOpcode(.T_BR);
                try self.writeU32(inst.operands[0]); // target
            },

            .t_br_trit => {
                try self.writeTritOpcode(.T_BR_TRIT);
                try self.writeU32(inst.operands[0]); // condition
                try self.writeU32(inst.operands[1]); // target
            },

            .t_drop => {
                try self.writeTritOpcode(.T_DROP);
            },

            .t_nop => {
                try self.writeTritOpcode(.T_NOP);
            },

            .t_unreachable => {
                try self.writeTritOpcode(.T_HALT);
            },

            else => {
                try self.writeTritOpcode(.T_NOP);
            },
        }
    }

    fn writeTritOpcode(self: *Codegen, opcode: TritOpcode) !void {
        try self.output.append(@intFromEnum(opcode));
    }

    fn writeU32(self: *Codegen, value: u32) !void {
        var buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &buf, value, .little);
        try self.output.appendSlice(&buf);
    }

    fn writeI32(self: *Codegen, value: i32) !void {
        var buf: [4]u8 = undefined;
        std.mem.writeInt(i32, &buf, value, .little);
        try self.output.appendSlice(&buf);
    }

    fn writeU16(self: *Codegen, value: u16) !void {
        var buf: [2]u8 = undefined;
        std.mem.writeInt(u16, &buf, value, .little);
        try self.output.appendSlice(&buf);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT FILE WRITER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn writeToFile(allocator: std.mem.Allocator, module: *const b2t_lifter.TVCModule, path: []const u8) !void {
    var codegen = Codegen.init(allocator);
    defer codegen.deinit();

    const code = try codegen.generate(module);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(code);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRIT FILE READER (for verification)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritFile = struct {
    magic: u32,
    version: u32,
    flags: u32,
    entry_point: u32,
    num_functions: u32,
    num_globals: u32,
    code: []const u8,

    pub fn parse(data: []const u8) !TritFile {
        if (data.len < 24) return error.TruncatedFile;

        const magic = std.mem.readInt(u32, data[0..4], .little);
        if (magic != TRIT_MAGIC) return error.InvalidMagic;

        return TritFile{
            .magic = magic,
            .version = std.mem.readInt(u32, data[4..8], .little),
            .flags = std.mem.readInt(u32, data[8..12], .little),
            .entry_point = std.mem.readInt(u32, data[12..16], .little),
            .num_functions = std.mem.readInt(u32, data[16..20], .little),
            .num_globals = std.mem.readInt(u32, data[20..24], .little),
            .code = data[24..],
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISASSEMBLER (for debugging)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn disassembleTrit(allocator: std.mem.Allocator, code: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    errdefer output.deinit();

    var writer = output.writer();
    var offset: usize = 0;

    while (offset < code.len) {
        const opcode_byte = code[offset];
        offset += 1;

        try writer.print("{x:04}: ", .{offset - 1});

        // Simple opcode dispatch
        if (opcode_byte == @intFromEnum(TritOpcode.T_NOP)) {
            try writer.print("T_NOP\n", .{});
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_HALT)) {
            try writer.print("T_HALT\n", .{});
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_DROP)) {
            try writer.print("T_DROP\n", .{});
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_CONST)) {
            if (offset + 8 <= code.len) {
                const dest = std.mem.readInt(u32, code[offset..][0..4], .little);
                const value = std.mem.readInt(i32, code[offset + 4 ..][0..4], .little);
                try writer.print("T_CONST v{} = {}\n", .{ dest, value });
                offset += 8;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_ADD)) {
            if (offset + 12 <= code.len) {
                const dest = std.mem.readInt(u32, code[offset..][0..4], .little);
                const op1 = std.mem.readInt(u32, code[offset + 4 ..][0..4], .little);
                const op2 = std.mem.readInt(u32, code[offset + 8 ..][0..4], .little);
                try writer.print("T_ADD v{} = v{}, v{}\n", .{ dest, op1, op2 });
                offset += 12;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_RET)) {
            if (offset + 4 <= code.len) {
                const value = std.mem.readInt(u32, code[offset..][0..4], .little);
                try writer.print("T_RET v{}\n", .{value});
                offset += 4;
            }
        } else if (opcode_byte == @intFromEnum(TritOpcode.T_LOAD)) {
            if (offset + 8 <= code.len) {
                const dest = std.mem.readInt(u32, code[offset..][0..4], .little);
                const addr = std.mem.readInt(u32, code[offset + 4 ..][0..4], .little);
                try writer.print("T_LOAD v{} = [{}]\n", .{ dest, addr });
                offset += 8;
            }
        } else {
            try writer.print("OP(0x{x:02})\n", .{opcode_byte});
        }
    }

    return try output.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "generate empty module" {
    var codegen = Codegen.init(std.testing.allocator);
    defer codegen.deinit();

    var module = b2t_lifter.TVCModule.init(std.testing.allocator);
    defer module.deinit();

    const code = try codegen.generate(&module);

    // Check magic
    const magic = std.mem.readInt(u32, code[0..4], .little);
    try std.testing.expectEqual(TRIT_MAGIC, magic);

    // Check version
    const version = std.mem.readInt(u32, code[4..8], .little);
    try std.testing.expectEqual(TRIT_VERSION, version);
}

test "parse trit file" {
    var codegen = Codegen.init(std.testing.allocator);
    defer codegen.deinit();

    var module = b2t_lifter.TVCModule.init(std.testing.allocator);
    defer module.deinit();

    const code = try codegen.generate(&module);
    const trit_file = try TritFile.parse(code);

    try std.testing.expectEqual(TRIT_MAGIC, trit_file.magic);
    try std.testing.expectEqual(TRIT_VERSION, trit_file.version);
}
