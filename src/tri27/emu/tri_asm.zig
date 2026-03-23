// TRI-27 ASSEMBLER — Minimal working implementation

const std = @import("std");
const Allocator = std.mem.Allocator;
const MAGIC: u32 = 0x54524932;
const Opcode = @import("./decoder.zig").Opcode;
const Instruction = @import("./decoder.zig").Instruction;
const encode = @import("./decoder.zig").encode;

/// Parse register name (t0-t31) to index
fn parseRegister(name: []const u8) !u5 {
    if (std.mem.startsWith(u8, name, "t")) {
        const num_str = name[1..];
        const num = std.fmt.parseInt(u5, num_str, 10) catch return error.InvalidRegister;
        if (num < 32) return num;
    }
    return error.InvalidRegister;
}

/// Parse instruction line to encoded word
fn parseLine(line: []const u8) !u32 {
    const trimmed = std.mem.trim(u8, line, " \t\r");
    if (trimmed.len == 0 or trimmed[0] == ';') return error.EmptyLine;

    // Split instruction by space
    var it = std.mem.splitScalar(u8, trimmed, ' ');
    const op_str = it.first();

    // Check for opcodes (case-insensitive) - use stack buffer
    var op_lower_buf: [32]u8 = undefined;
    const op_lower = std.ascii.lowerString(&op_lower_buf, op_str);

    if (std.mem.eql(u8, op_lower, "nop")) {
        return encode(Instruction{ .opcode = Opcode.NOP });
    }

    if (std.mem.eql(u8, op_lower, "halt")) {
        return encode(Instruction{ .opcode = Opcode.HALT });
    }

    if (std.mem.eql(u8, op_lower, "ldi")) {
        // LDI dst, imm
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const imm_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const imm = std.fmt.parseInt(i16, imm_str, 10) catch return error.InvalidImmediate;

        return encode(Instruction{
            .opcode = Opcode.LDI,
            .dst = dst,
            .immediate = imm,
            .has_imm = true,
        });
    }

    if (std.mem.eql(u8, op_lower, "add")) {
        // ADD dst, src1, src2
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        // Find second comma
        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const src2_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const src2 = try parseRegister(src2_str);

        return encode(Instruction{
            .opcode = Opcode.ADD,
            .dst = dst,
            .src1 = src1,
            .src2 = src2,
        });
    }

    // === LOGIC OPERATIONS (3-register format: dst, src1, src2) ===
    if (std.mem.eql(u8, op_lower, "and")) {
        // AND dst, src1, src2
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const src2_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const src2 = try parseRegister(src2_str);

        return encode(Instruction{
            .opcode = Opcode.AND,
            .dst = dst,
            .src1 = src1,
            .src2 = src2,
        });
    }

    if (std.mem.eql(u8, op_lower, "or")) {
        // OR dst, src1, src2
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const src2_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const src2 = try parseRegister(src2_str);

        return encode(Instruction{
            .opcode = Opcode.OR,
            .dst = dst,
            .src1 = src1,
            .src2 = src2,
        });
    }

    if (std.mem.eql(u8, op_lower, "xor")) {
        // XOR dst, src1, src2
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const src2_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const src2 = try parseRegister(src2_str);

        return encode(Instruction{
            .opcode = Opcode.XOR,
            .dst = dst,
            .src1 = src1,
            .src2 = src2,
        });
    }

    if (std.mem.eql(u8, op_lower, "not")) {
        // NOT dst
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        const dst_str = std.mem.trim(u8, rest, " \t");

        const dst = try parseRegister(dst_str);

        return encode(Instruction{
            .opcode = Opcode.NOT,
            .dst = dst,
        });
    }

    if (std.mem.eql(u8, op_lower, "shl")) {
        // SHL dst, src1, shift_imm
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const shift_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const shift = std.fmt.parseInt(i16, shift_str, 10) catch return error.InvalidImmediate;

        return encode(Instruction{
            .opcode = Opcode.SHL,
            .dst = dst,
            .src1 = src1,
            .immediate = shift,
            .has_imm = true,
        });
    }

    if (std.mem.eql(u8, op_lower, "shr")) {
        // SHR dst, src1, shift_imm
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const shift_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const shift = std.fmt.parseInt(i16, shift_str, 10) catch return error.InvalidImmediate;

        return encode(Instruction{
            .opcode = Opcode.SHR,
            .dst = dst,
            .src1 = src1,
            .immediate = shift,
            .has_imm = true,
        });
    }

    // === MEMORY OPERATIONS ===
    if (std.mem.eql(u8, op_lower, "ld")) {
        // LD dst, src (load from memory to register)
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const src = try parseRegister(src_str);

        return encode(Instruction{
            .opcode = Opcode.LD,
            .dst = dst,
            .src1 = src,
        });
    }

    if (std.mem.eql(u8, op_lower, "st")) {
        // ST src, dst (store register to memory)
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const src_str = std.mem.trim(u8, it2.first(), " \t");
        const dst_str = std.mem.trim(u8, it2.rest(), " \t");

        const src = try parseRegister(src_str);
        const dst = try parseRegister(dst_str);

        return encode(Instruction{
            .opcode = Opcode.ST,
            .src1 = src,
            .dst = dst,
        });
    }

    // === CONTROL OPERATIONS ===
    if (std.mem.eql(u8, op_lower, "jz")) {
        // JZ dst, offset (jump if zero)
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const offset_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const offset = std.fmt.parseInt(i16, offset_str, 10) catch return error.InvalidImmediate;

        return encode(Instruction{
            .opcode = Opcode.JZ,
            .dst = dst,
            .immediate = offset,
            .has_imm = true,
        });
    }

    if (std.mem.eql(u8, op_lower, "jnz")) {
        // JNZ dst, offset (jump if not zero)
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const offset_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const offset = std.fmt.parseInt(i16, offset_str, 10) catch return error.InvalidImmediate;

        return encode(Instruction{
            .opcode = Opcode.JNZ,
            .dst = dst,
            .immediate = offset,
            .has_imm = true,
        });
    }

    // === ARITHMETIC OPERATIONS (2-register format) ===
    if (std.mem.eql(u8, op_lower, "div")) {
        // DIV dst, src1, src2
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const src2_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const src2 = try parseRegister(src2_str);

        return encode(Instruction{
            .opcode = Opcode.DIV,
            .dst = dst,
            .src1 = src1,
            .src2 = src2,
        });
    }

    if (std.mem.eql(u8, op_lower, "inc")) {
        // INC dst
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        const dst_str = std.mem.trim(u8, rest, " \t");

        const dst = try parseRegister(dst_str);

        return encode(Instruction{
            .opcode = Opcode.INC,
            .dst = dst,
        });
    }

    if (std.mem.eql(u8, op_lower, "dec")) {
        // DEC dst
        const rest = std.mem.trimLeft(u8, it.rest(), " \t");
        const dst_str = std.mem.trim(u8, rest, " \t");

        const dst = try parseRegister(dst_str);

        return encode(Instruction{
            .opcode = Opcode.DEC,
            .dst = dst,
        });
    }

    return error.UnknownOpcode;
}

/// Assemble assembly source to .tbin bytecode
pub fn assemble(allocator: Allocator, source: []const u8) ![]u8 {
    var bytecode = std.ArrayList(u8).initCapacity(allocator, 256) catch unreachable;
    errdefer bytecode.deinit(allocator);

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

    // Reserve space for size field (2 bytes) before appending instructions
    // This ensures instructions start at offset 10 (not offset 8)
    try bytecode.append(allocator, 0);
    try bytecode.append(allocator, 0);

    // Parse and encode instructions
    var lines = std.mem.splitScalar(u8, source, '\n');
    var instr_count: u16 = 0;
    while (lines.next()) |line| {
        const word = parseLine(line) catch |err| switch (err) {
            error.EmptyLine => continue,
            else => return err,
        };
        instr_count += 1;

        try bytecode.append(allocator, @as(u8, @truncate(word)));
        try bytecode.append(allocator, @as(u8, @truncate(word >> 8)));
        try bytecode.append(allocator, @as(u8, @truncate(word >> 16)));
        try bytecode.append(allocator, @as(u8, @truncate(word >> 24)));
    }

    // Fill in size (now at correct offset 8-9)
    const code_size: u16 = @as(u16, @intCast(instr_count * 4));
    bytecode.items[8] = @as(u8, @truncate(code_size));
    bytecode.items[9] = @as(u8, @truncate(code_size >> 8));

    return try bytecode.toOwnedSlice(allocator);
}

/// Assemble source and write to file
pub fn assembleToFile(allocator: Allocator, source: []const u8, output_path: []const u8) !void {
    const bytecode = try assemble(allocator, source);
    defer allocator.free(bytecode);

    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(bytecode);
    std.debug.print("Wrote: {s} ({d} bytes)\n", .{ output_path, bytecode.len });
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 3) {
        std.debug.print("Usage: tri-asm <input.asm> -o <output.tbin>\n", .{});
        return error.Usage;
    }

    var input_file: []const u8 = args[1];
    var output_file: []const u8 = args[2];

    // Parse -o flag (search for -o anywhere in args)
    var o_index: ?usize = null;
    var o_next: ?usize = null;
    for (args, 0..) |arg, idx| {
        if (std.mem.eql(u8, arg, "-o")) {
            if (idx < args.len - 1 and std.mem.eql(u8, args[idx + 1], "-o")) {
                // Found "-o -o" pattern, use second file as output
                o_index = idx;
                o_next = idx + 2;
            } else {
                // Found "-o <input>" pattern, use next file as output
                o_index = idx;
                o_next = idx + 1;
            }
            break;
        }
    }

    if (o_index) |o_next| {
        if (o_next) |o_index| {
            input_file = args[o_next orelse o_next];
            output_file = args[o_index orelse o_next];
        }
    } else {
        input_file = args[1];
        output_file = args[2];
    }
}
