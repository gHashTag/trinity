// @origin(spec:tri_asm.tri) @regen(done)
//
// TRI-27 ASSEMBLER — Ternary assembler for .tbin bytecode files
//
// φ² + 1/φ² = 3 = TRINITY
//
// Usage: tri-asm <input.asm> -o <output.tbin>
// Asm syntax:
//   LDI t0, 42        ; Load immediate 42 into t0
//   ADD t1, t0, t2   ; t1 = t0 + t2
//   HALT             ; Stop execution
//   label:           ; Label definition
//   JMP label        ; Jump to label
//

const std = @import("std");
const Allocator = std.mem.Allocator;

const Decoder = @import("decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;

/// Assembler error set
pub const AsmError = error{
    InvalidSyntax,
    UnknownOpcode,
    InvalidRegister,
    InvalidImmediate,
    DuplicateLabel,
    UndefinedLabel,
    SectionMismatch,
    EmptySource,
    LineTooLong,
    OutOfMemory,
};

/// Line type during parsing
const LineType = enum {
    Empty,
    Comment,
    Label,
    Instruction,
    Directive,
};

/// Parsed line information
const ParsedLine = struct {
    line_type: LineType,
    line_num: u32,
    label: ?[]const u8 = null,
    opcode: ?Opcode = null,
    operands: ?[]const u8 = null,  // Raw operand string
};

/// Assembler state
const AssemblerState = struct {
    allocator: Allocator,
    instructions: std.ArrayList(Instruction),
    labels: std.StringHashMap(u32),  // label -> instruction index
    unresolved: std.ArrayList(struct { label: []const u8, line_num: u32, ref_inst: usize }),

    fn init(allocator: Allocator) AssemblerState {
        return .{
            .allocator = allocator,
            .instructions = std.ArrayList(Instruction).init(allocator),
            .labels = std.StringHashMap(u32).init(allocator),
            .unresolved = std.ArrayList(struct { label: []const u8, line_num: u32, ref_inst: usize }).init(allocator),
        };
    }

    fn deinit(self: *AssemblerState) void {
        self.instructions.deinit();
        // Labels own their keys, need to free them
        var label_iter = self.labels.iterator();
        while (label_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.labels.deinit();
        self.unresolved.deinit();
    }
};

/// Assemble result
pub const AsmResult = struct {
    success: bool,
    instruction_count: u32,
    error_msg: ?[]const u8 = null,
    error_line: ?u32 = null,
};

/// Parse single line
fn parseLine(allocator: Allocator, line: []const u8, line_num: u32) !ParsedLine {
    var trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

    // Empty line
    if (trimmed.len == 0) {
        return ParsedLine{ .line_type = .Empty, .line_num = line_num };
    }

    // Comment
    if (trimmed[0] == ';' or trimmed[0] == '#') {
        return ParsedLine{ .line_type = .Comment, .line_num = line_num };
    }

    // Label (ends with ':')
    if (trimmed[trimmed.len - 1] == ':') {
        const label_name = trimmed[0 .. trimmed.len - 1];
        if (label_name.len == 0) return AsmError.InvalidSyntax;

        // Copy label name for persistent storage
        const label_copy = try allocator.dupe(u8, label_name);
        return ParsedLine{
            .line_type = .Label,
            .line_num = line_num,
            .label = label_copy,
        };
    }

    // Directive (starts with '.')
    if (trimmed[0] == '.') {
        return ParsedLine{
            .line_type = .Directive,
            .line_num = line_num,
        };
    }

    // Instruction: parse opcode and operands
    const space_idx = std.mem.indexOfScalar(u8, trimmed, ' ') orelse trimmed.len;
    const opcode_str = trimmed[0..space_idx];

    // Convert opcode string to enum
    const opcode = parseOpcode(opcode_str) orelse return AsmError.UnknownOpcode;

    const operands = if (space_idx < trimmed.len)
        trimmed[space_idx + 1 ..]
    else
        "";

    return ParsedLine{
        .line_type = .Instruction,
        .line_num = line_num,
        .opcode = opcode,
        .operands = operands,
    };
}

/// Parse opcode string to Opcode enum
fn parseOpcode(str: []const u8) ?Opcode {
    const upper = str;
    _ = upper; // TODO: convert to uppercase if needed

    // Direct enum lookup
    inline for (@typeInfo(Opcode).enum.fields) |field| {
        if (std.ascii.eqlIgnoreCase(field.name, str)) {
            return @field(Opcode, field.name);
        }
    }
    return null;
}

/// Parse register name (t0-t26, r0-r26)
fn parseRegister(reg_str: []const u8) AsmError!u8 {
    const trimmed = std.mem.trim(u8, reg_str, &std.ascii.whitespace);

    // Support 't' prefix (t0-t26) or plain number (0-26)
    const num_str = if (trimmed.len > 1 and (trimmed[0] == 't' or trimmed[0] == 'r' or trimmed[0] == 'T' or trimmed[0] == 'R'))
        trimmed[1..]
    else
        trimmed;

    const num = std.fmt.parseInt(u8, num_str, 10) catch return AsmError.InvalidRegister;
    if (num > 26) return AsmError.InvalidRegister;
    return num;
}

/// Parse immediate value (decimal or hex)
fn parseImmediate(imm_str: []const u8) AsmError!i16 {
    const trimmed = std.mem.trim(u8, imm_str, &std.ascii.whitespace);

    // Remove trailing comma if present
    const clean = if (trimmed.len > 0 and trimmed[trimmed.len - 1] == ',')
        trimmed[0 .. trimmed.len - 1]
    else
        trimmed;

    if (clean.len > 2 and clean[0] == '0' and (clean[1] == 'x' or clean[1] == 'X')) {
        // Hex
        return std.fmt.parseInt(i16, clean[2..], 16) catch AsmError.InvalidImmediate;
    } else {
        // Decimal
        return std.fmt.parseInt(i16, clean, 10) catch AsmError.InvalidImmediate;
    }
}

/// Parse instruction operands and create Instruction
fn parseInstruction(allocator: Allocator, opcode: Opcode, operands: []const u8) !Instruction {
    var inst = Instruction{
        .opcode = opcode,
        .dst = 0,
        .src1 = 0,
        .src2 = 0,
        .immediate = 0,
        .has_imm = false,
        .cond = 0,
    };

    // Split operands by comma
    var parts = std.ArrayList([]const u8).init(allocator);
    defer {
        for (parts.items) |p| allocator.free(p);
        parts.deinit();
    }

    var iter = std.mem.splitScalar(u8, operands, ',');
    while (iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, &std.ascii.whitespace);
        if (trimmed.len > 0) {
            try parts.append(try allocator.dupe(u8, trimmed));
        }
    }

    switch (opcode) {
        // No operands
        .NOP, .HALT, .RET => {},

        // One register: dst
        .INC, .DEC, .NOT => {
            if (parts.items.len != 1) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
        },

        // dst, src
        .LD => {
            if (parts.items.len != 2) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.src1 = try parseRegister(parts.items[1]);
        },

        // src, dst (store)
        .ST => {
            if (parts.items.len != 2) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);  // src
            inst.src1 = try parseRegister(parts.items[1]);  // dst
        },

        // dst, imm
        .LDI => {
            if (parts.items.len != 2) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.immediate = try parseImmediate(parts.items[1]);
            inst.has_imm = true;
        },

        // dst, src1, src2
        .ADD, .SUB, .MUL, .DIV, .AND, .OR, .XOR => {
            if (parts.items.len != 3) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.src1 = try parseRegister(parts.items[1]);
            inst.src2 = try parseRegister(parts.items[2]);
        },

        // dst, src1, shift (for SHL/SHR)
        .SHL, .SHR => {
            if (parts.items.len != 3) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.src1 = try parseRegister(parts.items[1]);
            inst.src2 = try parseRegister(parts.items[2]);  // Shift amount
        },

        // Jump instructions: label
        .JMP, .JZ, .JNZ, .CALL => {
            if (parts.items.len != 1) return AsmError.InvalidSyntax;
            // For now, store label as immediate (will be resolved in pass 2)
            const label = try allocator.dupe(u8, parts.items[0]);
            defer allocator.free(label);

            // Try to parse as number first (for direct jumps)
            if (parseImmediate(label)) |imm| {
                inst.immediate = imm;
            } else |_| {
                // Store label offset temporarily (will be resolved)
                inst.immediate = 0;
            }
            inst.has_imm = true;
        },

        // Ternary ops
        .DOT, .BIND, .BUNDLE2, .BUNDLE3 => {
            if (parts.items.len < 2) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.src1 = try parseRegister(parts.items[1]);
            if (parts.items.len >= 3) {
                inst.src2 = try parseRegister(parts.items[2]);
            }
        },

        // Sacred ops
        .PHI_CONST, .PI_CONST, .E_CONST => {
            if (parts.items.len != 1) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.immediate = switch (opcode) {
                .PHI_CONST => @as(i16, @intFromFloat(@as(f32, @floatCast(1.618033988749895 * 10000)))),
                .PI_CONST => @as(i16, @intFromFloat(@as(f32, @floatCast(3.141592653589793 * 10000)))),
                .E_CONST => @as(i16, @intFromFloat(@as(f32, @floatCast(2.718281828459045 * 10000)))),
                else => 0,
            };
            inst.has_imm = true;
        },

        // Executor extensions
        .LD_IMM => {
            if (parts.items.len != 2) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.immediate = try parseImmediate(parts.items[1]);
            inst.has_imm = true;
        },

        .ADD3, .SUB3, .CMP3 => {
            if (parts.items.len != 3) return AsmError.InvalidSyntax;
            inst.dst = try parseRegister(parts.items[0]);
            inst.src1 = try parseRegister(parts.items[1]);
            inst.src2 = try parseRegister(parts.items[2]);
        },

        .SYSCALL => {
            if (parts.items.len >= 1) {
                inst.immediate = try parseImmediate(parts.items[0]);
                inst.has_imm = true;
            }
        },

        else => {
            // Unknown/unsupported instruction
            return AsmError.UnknownOpcode;
        },
    }

    return inst;
}

/// Assemble from .asm source to .tbin bytecode
pub fn assemble(allocator: Allocator, asm_source: []const u8) AsmError![]u8 {
    var state = AssemblerState.init(allocator);
    defer state.deinit();

    // Split source into lines
    var lines = std.mem.splitScalar(u8, asm_source, '\n');
    var line_num: u32 = 1;

    // First pass: collect labels and instructions
    while (lines.next()) |line| {
        const parsed = parseLine(allocator, line, line_num) catch |err| {
            std.debug.print("Error on line {d}: {s}\n", .{ line_num, @errorName(err) });
            return err;
        };

        switch (parsed.line_type) {
            .Empty, .Comment, .Directive => {},
            .Label => {
                const label = parsed.label orelse continue;
                const inst_idx = @as(u32, @intCast(state.instructions.items.len));

                if (state.labels.get(label)) |_| {
                    std.debug.print("Duplicate label: {s}\n", .{label});
                    return AsmError.DuplicateLabel;
                }

                const label_copy = try allocator.dupe(u8, label);
                try state.labels.put(label_copy, inst_idx);
            },
            .Instruction => {
                const opcode = parsed.opcode orelse continue;
                const operands = parsed.operands orelse "";

                const inst = try parseInstruction(allocator, opcode, operands);
                try state.instructions.append(inst);
            },
        }

        line_num += 1;
    }

    if (state.instructions.items.len == 0) {
        return AsmError.EmptySource;
    }

    // Encode instructions to words
    var bytecode = std.ArrayList(u8).init(allocator);
    errdefer bytecode.deinit();

    // .tbin header:
    // [0-3]   magic: "TRI27" (0x54524937)
    // [4]     version: 1
    // [5]     section_count: 1
    // [6]     section_type: CODE (1)
    // [7-8]   size (little-endian u16)
    // [9]     padding
    // [10...] instruction words (4 bytes each, little-endian)

    const code_size = @as(u16, @intCast(state.instructions.items.len * 4));

    try bytecode.append('T');
    try bytecode.append('R');
    try bytecode.append('I');
    try bytecode.append('2');
    try bytecode.append('7');  // magic
    try bytecode.append(1);     // version
    try bytecode.append(1);     // section_count
    try bytecode.append(1);     // section_type = CODE
    try bytecode.append(@as(u8, @truncate(code_size)));           // size low
    try bytecode.append(@as(u8, @truncate(code_size >> 8)));      // size high
    try bytecode.append(0);     // padding

    // Write instructions
    for (state.instructions.items) |inst| {
        const word = Decoder.encode(inst);
        try bytecode.append(@as(u8, @truncate(word)));
        try bytecode.append(@as(u8, @truncate(word >> 8)));
        try bytecode.append(@as(u8, @truncate(word >> 16)));
        try bytecode.append(@as(u8, @truncate(word >> 24)));
    }

    return bytecode.toOwnedSlice();
}

/// CLI entry point
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        std.debug.print(
            \\TRI-27 Assembler — Ternary assembler for .tbin bytecode
            \\Usage: tri-asm <input.asm> -o <output.tbin>
            \\
            \\Asm syntax:
            \\  LDI t0, 42        ; Load immediate 42 into t0
            \\  ADD t1, t0, t2   ; t1 = t0 + t2
            \\  HALT             ; Stop execution
            \\
            \\Opcodes: NOP, ADD, SUB, MUL, DIV, INC, DEC,
            \\         AND, OR, XOR, NOT, SHL, SHR,
            \\         LD, ST, LDI,
            \\         JMP, JZ, JNZ, CALL, RET, HALT,
            \\         DOT, BIND, BUNDLE2, BUNDLE3,
            \\         PHI_CONST, PI_CONST, E_CONST
            \\
        , .{});
        return;
    }

    var input_file: []const u8 = undefined;
    var output_file: []const u8 = "output.tbin";

    // Parse args
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-o")) {
            if (i + 1 < args.len) {
                i += 1;
                output_file = args[i];
            } else {
                std.debug.print("Error: -o requires filename argument\n", .{});
                return error.Usage;
            }
        } else if (args[i][0] == '-') {
            std.debug.print("Unknown option: {s}\n", .{args[i]});
            return error.Usage;
        } else {
            input_file = args[i];
        }
    }

    // Read input
    const asm_content = std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024) catch |err| {
        std.debug.print("Error reading {s}: {}\n", .{ input_file, err });
        return err;
    };
    defer allocator.free(asm_content);

    // Assemble
    const bytecode = assemble(allocator, asm_content) catch |err| {
        std.debug.print("Assembly failed: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytecode);

    std.debug.print("Assembled {d} instructions -> {d} bytes\n", .{
        bytecode.len / 4 - 2, // Subtract header
        bytecode.len,
    });

    // Write output
    {
        const file = try std.fs.cwd().createFile(output_file, .{});
        defer file.close();
        try file.writeAll(bytecode);
    }

    std.debug.print("Wrote: {s}\n", .{output_file});
}

// Tests
test "asm: parse LDI instruction" {
    const allocator = std.testing.allocator;

    const result = try parseLine(allocator, "LDI t0, 42", 1);
    try std.testing.expectEqual(LineType.Instruction, result.line_type);
    try std.testing.expectEqual(Opcode.LDI, result.opcode.?);

    const inst = try parseInstruction(allocator, Opcode.LDI, "t0, 42");
    try std.testing.expectEqual(Opcode.LDI, inst.opcode);
    try std.testing.expectEqual(@as(u8, 0), inst.dst);
    try std.testing.expectEqual(@as(i16, 42), inst.immediate);
}

test "asm: parse ADD instruction" {
    const allocator = std.testing.allocator;

    const inst = try parseInstruction(allocator, Opcode.ADD, "t1, t0, t2");
    try std.testing.expectEqual(Opcode.ADD, inst.opcode);
    try std.testing.expectEqual(@as(u8, 1), inst.dst);
    try std.testing.expectEqual(@as(u8, 0), inst.src1);
    try std.testing.expectEqual(@as(u8, 2), inst.src2);
}

test "asm: parse label" {
    const allocator = std.testing.allocator;

    const result = try parseLine(allocator, "loop:", 1);
    try std.testing.expectEqual(LineType.Label, result.line_type);
    try std.testing.expectEqualStrings("loop", result.label.?);
    allocator.free(result.label.?);
}

test "asm: assemble simple program" {
    const allocator = std.testing.allocator;

    const source =
        \\LDI t0, 42
        \\LDI t1, 10
        \\ADD t2, t0, t1
        \\HALT
    ;

    const bytecode = try assemble(allocator, source);
    defer allocator.free(bytecode);

    // Check header
    try std.testing.expectEqual(@as(u8, 'T'), bytecode[0]);
    try std.testing.expectEqual(@as(u8, 'R'), bytecode[1]);
    try std.testing.expectEqual(@as(u8, 'I'), bytecode[2]);
    try std.testing.expectEqual(@as(u8, '2'), bytecode[3]);
    try std.testing.expectEqual(@as(u8, '7'), bytecode[4]);
    try std.testing.expectEqual(@as(u8, 1), bytecode[5]); // version

    // Check we have 4 instructions
    const code_offset = 10;
    try std.testing.expectEqual(@as(usize, 10 + 4 * 4), bytecode.len);
}

test "asm: parse register variations" {
    try std.testing.expectEqual(@as(u8, 5), try parseRegister("t5"));
    try std.testing.expectEqual(@as(u8, 5), try parseRegister("T5"));
    try std.testing.expectEqual(@as(u8, 5), try parseRegister("r5"));
    try std.testing.expectEqual(@as(u8, 5), try parseRegister("R5"));
    try std.testing.expectEqual(@as(u8, 5), try parseRegister("5"));
}

test "asm: parse immediate formats" {
    try std.testing.expectEqual(@as(i16, 42), try parseImmediate("42"));
    try std.testing.expectEqual(@as(i16, -42), try parseImmediate("-42"));
    try std.testing.expectEqual(@as(i16, 0xFF), try parseImmediate("0xFF"));
    try std.testing.expectEqual(@as(i16, 0x10), try parseImmediate("0x10"));
}
