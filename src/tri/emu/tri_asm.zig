// @origin(spec:tri_asm.tri) @regen(done)
//
// TRI-27 ASSEMBLER
// Ternary assembler for .tbin bytecode files
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Instruction opcode encoding
pub const Opcode = enum(u8) {
    nop = 0x00,
    // TODO: Add more opcodes
};

/// Parse result
pub const ParseResult = struct {
    success: bool,
    instruction_count: u32,
};

/// Assembler state
const AssemblerState = struct {
    instructions: std.ArrayList(Instruction),
    labels: std.StringHashMap([]const u8, void),
};

/// Parse single instruction
fn parseInstruction(line: []const u8) !?Instruction {
    // TODO: Implement parsing
    _ = line;
    return null;
}

/// Assemble from .asm source
pub fn assemble(allocator: Allocator, asm_source: []const u8) ![]u8 {
    _ = allocator;
    errdefer _.free(asm_source);

    var state = AssemblerState{
        .instructions = std.ArrayList(Instruction).init(allocator),
        .labels = std.StringHashMap([]const u8, void).init(allocator),
    };

    var line_num: u32 = 1;
    for (asm_source) |line| {
        if (line.len == 0 or line[0] == ';' or line[0] == '#') continue;

        // TODO: Parse instruction and add to state
        line_num += 1;
    }

    std.debug.print("Assembled {} instructions\n", .{state.instructions.items.len});

    // Emit .tbin format (TRI-27 bytecode format)
    const output_path = try std.mem.concat(allocator, &.{ input_file, ".tbin" });
    defer allocator.free(output_path);

    const tbin_header = .{
        .magic = 0x54524494, // "TDI" in hex (Trinity Bytecode)
        .version = 1,
        .num_instructions = @as(u32, @intCast(state.instructions.items.len)),
        .num_symbols = @as(u32, @intCast(state.symbols.count())),
        .entry_point = state.entry_point orelse 0,
    };

    const file = try std.fs.cwd().createFile(output_path, .{ .read = false });
    defer file.close();

    const writer = file.writer();

    // Write header
    try writer.writeInt(u32, tbin_header.magic);
    try writer.writeInt(u32, tbin_header.version);
    try writer.writeInt(u32, tbin_header.num_instructions);
    try writer.writeInt(u32, tbin_header.num_symbols);
    try writer.writeInt(u32, tbin_header.entry_point);

    // Write symbol table
    var symbol_iter = state.symbols.iterator();
    while (symbol_iter.next()) |entry| {
        try writer.writeAll(entry.key_ptr.*);
        try writer.writeByte(0); // null terminator
        try writer.writeInt(u32, @intCast(entry.value_ptr.*));
    }

    // Write instructions
    for (state.instructions.items) |instr| {
        try writer.writeInt(u32, @intFromEnum(instr.opcode));
        try writer.writeInt(u32, @intCast(instr.rd));
        try writer.writeInt(u32, @intCast(instr.rs));
        try writer.writeInt(u32, @intCast(instr.rt));
        try writer.writeInt(u32, instr.immediate orelse 0);
    }

    try writer.flush();
    std.debug.print("Emitted .tbin format to {s}\n", .{output_path});

    return ParseResult{ .success = true, .instruction_count = state.instructions.items.len };
}

/// Main entry point
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 1) {
        std.debug.print("Usage: tri-asm <input.asm> [options]\n", .{});
        return error.Usage;
    }

    const input_file = args[0];
    const asm_content = try std.fs.cwd().readFileAlloc(allocator, input_file);
    defer allocator.free(asm_content);

    const result = assemble(allocator, asm_content);

    if (result.success) {
        const output_path = try std.fs.path.join(allocator, &[_][]const u8{ input_file, ".tbin" });
        defer allocator.free(output_path);

        std.debug.print("Writing .tbin: {}\n", .{output_path});
        // TODO: Write actual binary
        try std.fs.cwd().writeFileAlloc(allocator, output_path, &[_]u8{ 0xAA, 0x55, 0xAA }); // placeholder
    }

    return result;
}

test "tri_asm_smoke" {
    // TODO: Add tests
}
// TODO: Implement actual .asm parsing
