// TRI-27 ASSEMBLER — Simple .tbin bytecode generator
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Magic number for .tbin files: "TRI27" (big-endian)
const MAGIC: u32 = 0x54524932; // 'T' << 24 | 'R' << 16 | 'I' << 8 | '2'

const Opcode = @import("../decoder.zig").Opcode;
const Instruction = @import("../decoder.zig").Instruction;
const encode = @import("../decoder.zig").encode;

/// Assemble from .asm source to .tbin
pub fn assemble(allocator: std.mem.Allocator, asm_source: []const u8) ![]u8 {
    var instructions = std.ArrayList(Instruction).init(allocator);

    // Parse line by line
    var lines = std.mem.splitScalar(u8, asm_source, '\n');

    var line_num: u32 = 1;
    while (lines.next()) |line| {
        var trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        // Skip empty and comments
        if (trimmed.len == 0 or trimmed[0] == ';' or trimmed[0] == '#') continue;

        // Parse: LDI t0, 42
        var parts = std.mem.splitScalar(u8, trimmed, ',');
        const mnemonic = parts.first() orelse continue;

        // Simple LDI: t0, 42
        if (parts.items.len == 2) {
            const reg_str = parts.items[1];
            const imm_str = parts.items[2];

            // Parse register
            const reg = if (reg_str.len > 0 and reg_str[0] == 't')
                try std.fmt.parseInt(u8, reg_str[1..], 10)
            else
                try std.fmt.parseInt(u8, reg_str, 10);

            // Parse immediate
            const imm = try std.fmt.parseInt(i16, imm_str, 10);

            const inst = Instruction{
                .opcode = Opcode.LDI,
                .dst = @as(u8, reg),
                .immediate = imm,
                .has_imm = true,
                .src1 = 0,
                .src2 = 0,
                .cond = 0,
            };

            try instructions.append(inst);
        } else {
            std.debug.print("Syntax error on line {d}: {s}\n", .{ line_num, line });
            return error.InvalidSyntax;
        }

        line_num += 1;
    }

    // Build bytecode
    var bytecode = std.ArrayList(u8).initCapacity(allocator, 512) catch unreachable;
    defer bytecode.deinit();

    // Write magic: "TRI2" (big-endian)
    try bytecode.append(allocator, 'T'); // 0x54
    try bytecode.append(allocator, 'R'); // 0x49
    try bytecode.append(allocator, 'I'); // 0x32
    try bytecode.append(allocator, '2'); // 0x52

    // Write header
    try bytecode.append(allocator, 1); // version
    try bytecode.append(allocator, 1); // section_count
    try bytecode.append(allocator, 1); // section_type = CODE
    try bytecode.append(allocator, @as(u8, @truncate(instructions.items.len * 4))); // size low
    try bytecode.append(allocator, @as(u8, @truncate((instructions.items.len * 4) >> 8))); // size high
    try bytecode.append(allocator, 0); // padding

    // Write instructions (4 bytes each, big-endian)
    for (instructions.items) |inst| {
        const word = encode(inst);
        try bytecode.append(allocator, @as(u8, @truncate(word)));
        try bytecode.append(allocator, @as(u8, @truncate(word >> 8)));
        try bytecode.append(allocator, @as(u8, @truncate(word >> 16)));
        try bytecode.append(allocator, @as(u8, @truncate(word >> 24)));
    }

    std.debug.print("Assembled {d} instructions -> {d} bytes\n", .{
        instructions.items.len,
        bytecode.items.len,
    });

    return bytecode.toOwnedSlice(allocator);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        std.debug.print(
            \\TRI-27 Assembler — Simple .tbin bytecode generator
            \\Usage: tri-asm <input.asm> -o <output.tbin>
            \\
            \\Syntax: LDI t0, 42    ; Load immediate
            \\       ADD t1, t0, t2 ; t1 = t0 + t2
            \\       HALT            ; Stop
        );
        return error.Usage;
    }

    const input_file = args[1];
    var output_file: []const u8 = "output.tbin";

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-o")) {
            i += 1;
            if (i < args.len) {
                output_file = args[i];
                i += 1;
            }
        }
    }

    // Read input
    const asm_content = std.fs.cwd().readFileAlloc(allocator, input_file, 65536) catch |err| {
        std.debug.print("Error reading {s}: {}\n", .{ input_file, err });
        return err;
    };
    defer allocator.free(asm_content);

    // Assemble
    const bytecode = try assemble(allocator, asm_content) catch |err| {
        std.debug.print("Assembly failed: {}\n", .{ err });
        return;
    };
    defer allocator.free(bytecode);

    // Write output
    const file = try std.fs.cwd().createFile(output_file, .{}) catch |err| {
        std.debug.print("Error writing {s}: {}\n", .{ output_file, err });
        return err;
    };
    defer file.close();

    std.debug.print("Wrote: {s} ({d} bytes)\n", .{ output_file, bytecode.items.len });
}
}
