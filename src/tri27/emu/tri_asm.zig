// TRI-27 ASSEMBLER — Phase 3: Labels + Line Numbers

const std = @import("std");
const Allocator = std.mem.Allocator;
const MAGIC: u32 = 0x54524932;
const Opcode = @import("./decoder.zig").Opcode;
const Instruction = @import("./decoder.zig").Instruction;
const encode = @import("./decoder.zig").encode;

/// Assemble error with line number
pub const AsmError = error{
    InvalidRegister,
    InvalidSyntax,
    InvalidImmediate,
    UnknownOpcode,
    UndefinedLabel,
    EmptyLine,
};

/// Parse register name (t0-t31) to index
fn parseRegister(name: []const u8) !u5 {
    if (std.mem.startsWith(u8, name, "t")) {
        const num_str = name[1..];
        const num = std.fmt.parseInt(u5, num_str, 10) catch return error.InvalidRegister;
        if (num < 32) return num;
    }
    return error.InvalidRegister;
}

/// Helper: Parse 3-register instruction (dst, src1, src2)
fn parseThreeOp(rest: []const u8) AsmError!struct { u8, u8, u8 } {
    var it2 = std.mem.splitScalar(u8, rest, ',');
    const dst_str = std.mem.trim(u8, it2.first(), " \t");
    const src1_str = std.mem.trim(u8, it2.rest(), " \t");

    const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
    const src2_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
    const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

    const dst = try parseRegister(dst_str);
    const src1 = try parseRegister(src1_str_trimmed);
    const src2 = try parseRegister(src2_str);

    return .{ dst, src1, src2 };
}

/// Label table: maps label name to instruction index
const LabelTable = std.StringHashMap(u32);

/// Parse instruction with label resolution
fn parseLineWithLabels(line: []const u8, labels: *const LabelTable, line_num: usize) AsmError!struct { u32, bool } {
    const trimmed = std.mem.trim(u8, line, " \t\r");

    // Strip inline comments (starting with ';')
    var rest_trimmed = trimmed;
    if (std.mem.indexOfScalar(u8, trimmed, ';')) |comment_idx| {
        rest_trimmed = trimmed[0..comment_idx];
    }
    rest_trimmed = std.mem.trimRight(u8, rest_trimmed, " \t");

    // Check for label definition (ends with ':')
    if (rest_trimmed.len > 0 and rest_trimmed[rest_trimmed.len - 1] == ':') {
        _ = std.mem.trimRight(u8, rest_trimmed[0 .. rest_trimmed.len - 1], " \t");
        return .{ 0, true }; // Flag that this was a label definition
    }

    if (rest_trimmed.len == 0 or rest_trimmed[0] == ';') return error.EmptyLine;

    var it = std.mem.splitScalar(u8, rest_trimmed, ' ');
    const op_str = it.first();

    var op_lower_buf: [32]u8 = undefined;
    const op_lower = std.ascii.lowerString(&op_lower_buf, op_str);

    const rest = std.mem.trimLeft(u8, it.rest(), " \t");

    // === CONTROL (NOP, HALT, JMP, JZ, JNZ, CALL, RET) ===
    if (std.mem.eql(u8, op_lower, "nop")) return .{ encode(Instruction{ .opcode = Opcode.NOP }), false };
    if (std.mem.eql(u8, op_lower, "halt")) return .{ encode(Instruction{ .opcode = Opcode.HALT }), false };

    if (std.mem.eql(u8, op_lower, "jmp")) {
        // JMP offset or label (unconditional jump)
        const offset = parseOperand(rest, labels, line_num) catch |err| return err;
        return .{ encode(Instruction{
            .opcode = Opcode.JMP,
            .immediate = offset,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "jz")) {
        // JZ dst, offset/label (jump if zero)
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const offset_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const offset = parseOperand(offset_str, labels, line_num) catch |err| return err;

        return .{ encode(Instruction{
            .opcode = Opcode.JZ,
            .dst = dst,
            .immediate = offset,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "jnz")) {
        // JNZ dst, offset/label (jump if not zero)
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const offset_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const offset = parseOperand(offset_str, labels, line_num) catch |err| return err;

        return .{ encode(Instruction{
            .opcode = Opcode.JNZ,
            .dst = dst,
            .immediate = offset,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "call")) {
        // CALL offset/label (call subroutine)
        const offset = parseOperand(rest, labels, line_num) catch |err| return err;
        return .{ encode(Instruction{
            .opcode = Opcode.CALL,
            .immediate = offset,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "ret")) {
        // RET (return from subroutine)
        return .{ encode(Instruction{ .opcode = Opcode.RET }), false };
    }

    // === ARITHMETIC (ADD, SUB, MUL, DIV, INC, DEC) ===
    if (std.mem.eql(u8, op_lower, "add")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.ADD,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "sub")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.SUB,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "mul")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.MUL,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "div")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.DIV,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "inc")) {
        const dst_str = std.mem.trim(u8, rest, " \t");
        const dst = try parseRegister(dst_str);
        return .{ encode(Instruction{
            .opcode = Opcode.INC,
            .dst = dst,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "dec")) {
        const dst_str = std.mem.trim(u8, rest, " \t");
        const dst = try parseRegister(dst_str);
        return .{ encode(Instruction{
            .opcode = Opcode.DEC,
            .dst = dst,
        }), false };
    }

    // === LOGIC (AND, OR, XOR, NOT, SHL, SHR) ===
    if (std.mem.eql(u8, op_lower, "and")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.AND,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "or")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.OR,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "xor")) {
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.XOR,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "not")) {
        const dst_str = std.mem.trim(u8, rest, " \t");
        const dst = try parseRegister(dst_str);
        return .{ encode(Instruction{
            .opcode = Opcode.NOT,
            .dst = dst,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "shl")) {
        // SHL dst, src1, shift
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const shift_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const shift = std.fmt.parseInt(i16, shift_str, 10) catch return error.InvalidImmediate;

        return .{ encode(Instruction{
            .opcode = Opcode.SHL,
            .dst = dst,
            .src1 = src1,
            .immediate = shift,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "shr")) {
        // SHR dst, src1, shift
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, src1_str, ',') orelse return error.InvalidSyntax;
        const shift_str = std.mem.trim(u8, src1_str[comma_idx + 1 ..], " \t");
        const src1_str_trimmed = std.mem.trim(u8, src1_str[0..comma_idx], " \t");

        const dst = try parseRegister(dst_str);
        const src1 = try parseRegister(src1_str_trimmed);
        const shift = std.fmt.parseInt(i16, shift_str, 10) catch return error.InvalidImmediate;

        return .{ encode(Instruction{
            .opcode = Opcode.SHR,
            .dst = dst,
            .src1 = src1,
            .immediate = shift,
            .has_imm = true,
        }), false };
    }

    // === MEMORY (LD, ST, LDI, STI) ===
    if (std.mem.eql(u8, op_lower, "ld")) {
        // LD dst, src
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const src_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const src = try parseRegister(src_str);

        return .{ encode(Instruction{
            .opcode = Opcode.LD,
            .dst = dst,
            .src1 = src,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "st")) {
        // ST src, dst
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const src_str = std.mem.trim(u8, it2.first(), " \t");
        const dst_str = std.mem.trim(u8, it2.rest(), " \t");

        const src = try parseRegister(src_str);
        const dst = try parseRegister(dst_str);

        return .{ encode(Instruction{
            .opcode = Opcode.ST,
            .src1 = src,
            .dst = dst,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "ldi")) {
        // LDI dst, imm
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const imm_str = std.mem.trim(u8, it2.rest(), " \t");

        const dst = try parseRegister(dst_str);
        const imm = std.fmt.parseInt(i16, imm_str, 10) catch return error.InvalidImmediate;

        return .{ encode(Instruction{
            .opcode = Opcode.LDI,
            .dst = dst,
            .immediate = imm,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "sti")) {
        // STI imm, dst (store immediate to memory)
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const imm_str = std.mem.trim(u8, it2.first(), " \t");
        const dst_str = std.mem.trim(u8, it2.rest(), " \t");

        const imm = std.fmt.parseInt(i16, imm_str, 10) catch return error.InvalidImmediate;
        const dst = try parseRegister(dst_str);

        return .{ encode(Instruction{
            .opcode = Opcode.STI,
            .dst = dst,
            .immediate = imm,
            .has_imm = true,
        }), false };
    }

    // === TERNARY (DOT, BIND, BUNDLE2, BUNDLE3) ===
    if (std.mem.eql(u8, op_lower, "dot")) {
        // DOT dst, v1, v2 — ternary dot product
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.DOT,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "bind")) {
        // BIND dst, v1, v2 — VSA bind operation
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.BIND,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "bundle2")) {
        // BUNDLE2 dst, v1, v2 — majority vote (2 vectors)
        const r = try parseThreeOp(rest);
        return .{ encode(Instruction{
            .opcode = Opcode.BUNDLE2,
            .dst = r[0],
            .src1 = r[1],
            .src2 = r[2],
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "bundle3")) {
        // BUNDLE3 dst, v1, v2, v3 — majority vote (3 vectors)
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const dst_str = std.mem.trim(u8, it2.first(), " \t");
        const v1_str = std.mem.trim(u8, it2.rest(), " \t");

        const comma1_idx = std.mem.indexOfScalar(u8, v1_str, ',') orelse return error.InvalidSyntax;
        const v2_str = std.mem.trim(u8, v1_str[0..comma1_idx], " \t");
        const rest_after_v2 = std.mem.trim(u8, v1_str[comma1_idx + 1 ..], " \t");

        const comma2_idx = std.mem.indexOfScalar(u8, rest_after_v2, ',') orelse return error.InvalidSyntax;
        const v3_str = std.mem.trim(u8, rest_after_v2[0..comma2_idx], " \t");

        const dst = try parseRegister(dst_str);
        const v1 = try parseRegister(v1_str);
        const v2 = try parseRegister(v2_str);
        const v3 = try parseRegister(v3_str);

        // For BUNDLE3, encode v3 in immediate (src2 field for v2)
        return .{ encode(Instruction{
            .opcode = Opcode.BUNDLE3,
            .dst = dst,
            .src1 = v1,
            .src2 = v2,
            .immediate = @as(i16, v3),
            .has_imm = true,
        }), false };
    }

    // === SACRED (PHI_CONST, PI_CONST, E_CONST, SACR) ===
    if (std.mem.eql(u8, op_lower, "phi_const")) {
        // PHI_CONST dst — load φ (golden ratio)
        const dst_str = std.mem.trim(u8, rest, " \t");
        const dst = try parseRegister(dst_str);
        return .{ encode(Instruction{
            .opcode = Opcode.PHI_CONST,
            .dst = dst,
            .immediate = 0,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "pi_const")) {
        // PI_CONST dst — load π
        const dst_str = std.mem.trim(u8, rest, " \t");
        const dst = try parseRegister(dst_str);
        return .{ encode(Instruction{
            .opcode = Opcode.PI_CONST,
            .dst = dst,
            .immediate = 0,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "e_const")) {
        // E_CONST dst — load e
        const dst_str = std.mem.trim(u8, rest, " \t");
        const dst = try parseRegister(dst_str);
        return .{ encode(Instruction{
            .opcode = Opcode.E_CONST,
            .dst = dst,
            .immediate = 0,
            .has_imm = true,
        }), false };
    }

    if (std.mem.eql(u8, op_lower, "sacr")) {
        // SACR op, dst, src — sacred arithmetic operation
        var it2 = std.mem.splitScalar(u8, rest, ',');
        const sacrop_str = std.mem.trim(u8, it2.first(), " \t");
        const rest_args = std.mem.trim(u8, it2.rest(), " \t");

        const comma_idx = std.mem.indexOfScalar(u8, rest_args, ',') orelse return error.InvalidSyntax;
        const dst_str = std.mem.trim(u8, rest_args[0..comma_idx], " \t");
        const src_str = std.mem.trim(u8, rest_args[comma_idx + 1 ..], " \t");

        const dst = try parseRegister(dst_str);
        const src = try parseRegister(src_str);

        // Encode sacred operation type in immediate
        var sacrop: i16 = 0;
        if (std.mem.eql(u8, sacrop_str, "add")) sacrop = 1;
        if (std.mem.eql(u8, sacrop_str, "mul")) sacrop = 2;
        if (std.mem.eql(u8, sacrop_str, "div")) sacrop = 3;
        if (std.mem.eql(u8, sacrop_str, "pow")) sacrop = 4;

        return .{ encode(Instruction{
            .opcode = Opcode.SACR,
            .dst = dst,
            .src1 = src,
            .immediate = sacrop,
            .has_imm = true,
        }), false };
    }

    return error.UnknownOpcode;
}

/// Parse operand: immediate number or label reference
fn parseOperand(text: []const u8, labels: *const LabelTable, line_num: usize) AsmError!i16 {
    const trimmed = std.mem.trim(u8, text, " \t");

    // Try as number first
    if (std.fmt.parseInt(i16, trimmed, 10)) |value| {
        return value;
    } else |_| {
        // Not a number, check if it's a label
        if (labels.get(trimmed)) |label_addr| {
            // Convert u32 to i16 (handle overflow by clamping)
            if (label_addr > 32767) {
                std.debug.print("Warning: label address 0x{x} exceeds i16 range, clamping\n", .{label_addr});
                return @as(i16, 32767);
            }
            return @bitCast(@as(u16, @truncate(label_addr)));
        }
        std.debug.print("Error: Undefined label '{s}' at line {d}\n", .{ trimmed, line_num });
        return error.UndefinedLabel;
    }
}

/// Two-pass assembler with label support
pub fn assemble(allocator: Allocator, source: []const u8) ![]u8 {
    var bytecode = std.ArrayList(u8).initCapacity(allocator, 256) catch unreachable;
    errdefer bytecode.deinit(allocator);

    // === PASS 1: Collect labels ===
    var labels = LabelTable.init(allocator);
    defer labels.deinit();

    var lines_iter = std.mem.splitScalar(u8, source, '\n');
    var line_num: usize = 1;
    var instr_idx: u32 = 2; // Instructions start at PC=2 (magic + header)

    while (lines_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Check for label definition
        if (trimmed.len > 0 and trimmed[trimmed.len - 1] == ':') {
            const label_name = std.mem.trimRight(u8, trimmed[0 .. trimmed.len - 1], " \t");
            try labels.put(label_name, instr_idx);
            line_num += 1;
            continue;
        }

        // Skip empty lines and comments
        if (trimmed.len == 0 or trimmed[0] == ';') {
            line_num += 1;
            continue;
        }

        instr_idx += 1;
        line_num += 1;
    }

    // === PASS 2: Parse and encode instructions ===
    bytecode.appendSliceAssumeCapacity(&.{ 0x32, 0x49, 0x52, 0x54 }); // Magic
    try bytecode.appendSlice(allocator, &.{ 1, 1, 1, 0 }); // Header
    try bytecode.appendSlice(allocator, &.{ 0, 0 }); // Size placeholder

    lines_iter = std.mem.splitScalar(u8, source, '\n');
    line_num = 1;
    var instr_count: u16 = 0;

    while (lines_iter.next()) |line| {
        const result = parseLineWithLabels(line, &labels, line_num) catch |err| switch (err) {
            error.EmptyLine => {
                line_num += 1;
                continue;
            },
            error.UnknownOpcode => {
                std.debug.print("Error: Unknown opcode on line {d}: {s}\n", .{ line_num, line });
                return err;
            },
            else => {
                std.debug.print("Error on line {d}: {}\n", .{ line_num, err });
                return err;
            },
        };

        // Skip label definitions in pass 2
        if (result[1]) {
            line_num += 1;
            continue;
        }

        const word = result[0];
        instr_count += 1;

        try bytecode.appendSlice(allocator, &[_]u8{
            @as(u8, @truncate(word)),
            @as(u8, @truncate(word >> 8)),
            @as(u8, @truncate(word >> 16)),
            @as(u8, @truncate(word >> 24)),
        });

        line_num += 1;
    }

    // Fill in size field
    const code_size: u16 = instr_count * 4;
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
    var output_idx: ?usize = null;
    for (args, 0..) |arg, idx| {
        if (std.mem.eql(u8, arg, "-o") and idx < args.len - 1) {
            output_idx = idx + 1;
            break;
        }
    }

    if (output_idx) |out_idx| {
        output_file = args[out_idx];
        // Find input file (first non-flag argument that's not -o or output file)
        for (args[1..], 1..) |arg, idx| {
            if (std.mem.eql(u8, arg, "-o") or idx == out_idx) continue;
            input_file = arg;
            break;
        }
    } else {
        input_file = args[1];
        output_file = args[2];
    }

    const source = try std.fs.cwd().readFileAlloc(allocator, input_file, 65536);
    defer allocator.free(source);

    try assembleToFile(allocator, source, output_file);
}
