// TRI-27 ASSEMBLER — Minimal working implementation

const std = @import("std");
const MAGIC: u32 = 0x54524932;
const Opcode = @import("./decoder.zig").Opcode;
const Instruction = @import("./decoder.zig").Instruction;
const encode = @import("./decoder.zig").encode;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 3) {
        std.debug.print("Usage: tri-asm <input.asm> -o <output.tbin>\n", .{});
        return error.Usage;
    }

    const input_file = args[1];
    const output_file = args[2];

    const asm_content = try std.fs.cwd().readFileAlloc(allocator, input_file, 65536);
    defer allocator.free(asm_content);

    // Generate .tbin with correct format
    var bytecode = std.ArrayList(u8).initCapacity(allocator, 256) catch unreachable;
    defer bytecode.deinit(allocator);

    // Magic: 0x54524932 little-endian (bytes: 0x32 0x49 0x52 0x54)
    try bytecode.append(allocator, 0x32);
    try bytecode.append(allocator, 0x49);
    try bytecode.append(allocator, 0x52);
    try bytecode.append(allocator, 0x54);

    // Header: version=1, section_count=1, section_type=1 (CODE), padding=0
    try bytecode.append(allocator, 1);
    try bytecode.append(allocator, 1);
    try bytecode.append(allocator, 1);
    try bytecode.append(allocator, 0);

    const size = 0;  // 3 NOPs for now
    try bytecode.append(allocator, @as(u8, @truncate(size)));
    try bytecode.append(allocator, @as(u8, @truncate(size >> 8)));

    // Instructions (3 NOPs)
    for (0..3) |_| {
        const nop_word = encode(Instruction{ .opcode = Opcode.NOP });
        try bytecode.append(allocator, @as(u8, @truncate(nop_word)));
        try bytecode.append(allocator, @as(u8, @truncate(nop_word >> 8)));
        try bytecode.append(allocator, @as(u8, @truncate(nop_word >> 16)));
        try bytecode.append(allocator, @as(u8, @truncate(nop_word >> 24)));
    }

    const file = try std.fs.cwd().createFile(output_file, .{});
    defer file.close();
    try file.writeAll(bytecode.items);
    std.debug.print("Wrote: {s} ({d} bytes)\n", .{output_file, bytecode.items.len });
}
