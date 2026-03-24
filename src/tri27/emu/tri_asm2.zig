// @origin(spec:tri_asm.tri) @regen(manual-impl)
// TRI-27 ASSEMBLER v2 — Uses lexer + encoder for .tasm → .tbin
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("asm_lexer.zig").Lexer;
const encoder = @import("encoder_simple.zig");
const Opcode = encoder_simple.Opcode;

/// Magic number for .tbin files
const MAGIC: u32 = 0x54524937; // 'T' << 24 | 'R' << 16 | 'I' << 8 | '2' (big-endian "TRI2")

/// .tbin header structure
const TbinHeader = extern struct {
    magic: [4]u8,     // Bytes 0-3
    version: u8,           // Byte 4
    section_count: u8,     // Byte 5
    reserved: [3]u8,        // Bytes 6-8
    size: u32,             // Bytes 9-12 (little-endian)
};

/// Assembler error set
pub const AsmError = error{
    InvalidSyntax,
    UnknownOpcode,
    InvalidRegister,
    InvalidImmediate,
    DuplicateLabel,
    UndefinedLabel,
    EmptySource,
    OutOfMemory,
};

/// Assembler state
pub const AssemblerState = struct {
    allocator: Allocator,
    tokens: []const Lexer.Token,
    bytecode: std.ArrayList(u8),
    labels: std.StringHashMap(u32), // label -> address in bytecode

    fn init(allocator: Allocator, tokens: []const Lexer.Token) AssemblerState {
        return .{
            .allocator = allocator,
            .tokens = tokens,
            .bytecode = std.ArrayList(u8).init(allocator),
            .labels = std.StringHashMap(u32).init(allocator),
        };
    }

    fn deinit(self: *AssemblerState) void {
        self.bytecode.deinit(self.allocator);
        self.labels.deinit();
    }

    /// Find label address by name
    fn resolveLabel(self: *const AssemblerState, name: []const u8) !u32 {
        if (self.labels.get(name)) |addr| {
            return addr;
        } else {
            return AsmError.UndefinedLabel;
        }
    }

    /// Encode instruction to bytecode word
    fn encodeInstruction(self: *AssemblerState, token: Lexer.Token) !u32 {
        switch (token.type) {
            .Mnemonic => {
                const opcode_str = token.text;

                if (std.ascii.eqlIgnoreCase(opcode_str, "nop")) {
                    return encoder.encode_nop(0);
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "halt")) {
                    return encoder.encode_halt();
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "add")) {
                    // add dst, src1, src2
                    if (token.line < self.tokens.len - 1) return AsmError.InvalidSyntax;
                    const src1_token = self.tokens[token.line + 1];
                    const src2_token = self.tokens[token.line + 2];
                    if (src1_token.type != .Register or src2_token.type != .Register) {
                        return AsmError.InvalidSyntax;
                    }

                    const dst = try parseRegister(src1_token.text);
                    const src1 = try parseRegister(src2_token.text);
                    const src2 = if (token.line + 3 < self.tokens.len and self.tokens[token.line + 3].type == .Register)
                        try parseRegister(self.tokens[token.line + 3].text)
                    else
                        return AsmError.InvalidSyntax;

                    return encoder.encode_add(dst, src1, src2);
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "sub")) {
                    const src1 = try getRegister(self, token, token.line, 1);
                    const src2 = try getRegister(self, token, token.line, 2);
                    const dst = try getRegister(self, token, token.line, 3);
                    const src3 = try getRegister(self, token, token.line, 4);
                    return encoder.encode_sub(dst, src1, src2);
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "mul")) {
                    const src1 = try getRegister(self, token, token.line, 1);
                    const src2 = try getRegister(self, token, token.line, 2);
                    const dst = try getRegister(self, token, token.line, 3);
                    return encoder.encode_mul(dst, src1, src2);
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "tmul")) {
                    const src1 = try getRegister(self, token, token.line, 1);
                    const src2 = try getRegister(self, token, token.line, 2);
                    const dst = try getRegister(self, token, token.line, 3);
                    return encoder.encode_tmul(dst, src1, src2);
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "load_imm") or
                    std.ascii.eqlIgnoreCase(opcode_str, "ldi")) {
                    const dst = try getRegister(self, token, token.line, 1);
                    const imm = try getImmediate(self, token, token.line, 2);
                    if (std.ascii.eqlIgnoreCase(opcode_str, "load_imm")) {
                        return encoder.encode_load_imm(dst, imm);
                    } else {
                        return encoder.encode_ldi(dst, imm);
                    }
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "store") or
                    std.ascii.eqlIgnoreCase(opcode_str, "sti")) {
                    if (std.ascii.eqlIgnoreCase(opcode_str, "store")) {
                        const src = try getRegister(self, token, token.line, 1);
                        const addr = try getImmediate(self, token, token.line, 2);
                        return encoder.encode_store(src, @bitCast(addr));
                    } else {
                        const imm = try getImmediate(self, token, token.line, 1);
                        const addr = try getImmediate(self, token, token.line, 2);
                        return encoder.encode_sti(imm, @bitCast(addr));
                    }
                }
                if (std.ascii.eqlIgnoreCase(opcode_str, "load")) {
                    const dst = try getRegister(self, token, token.line, 1);
                    const addr = try getImmediate(self, token, token.line, 2);
                    return encoder.encode_load_mem(dst, @bitCast(addr));
                }
            },
            .LabelDef => {
                // Label: add to current address
                try self.labels.put(self.allocator, token.text, @as(u32, self.bytecode.items.len));
            },
            else => return AsmError.InvalidSyntax,
        }
    }

    /// Get register from token at offset
    fn getRegister(self: *const AssemblerState, token: Lexer.Token, token_line: usize, offset: usize) !u5 {
        const idx = token_line + offset;
        if (idx >= self.tokens.len) return AsmError.InvalidSyntax;
        const t = self.tokens[idx];
        if (t.type != .Register) return AsmError.InvalidSyntax;
        return parseRegister(t.text);
    }

    /// Get immediate from token at offset
    fn getImmediate(self: *const AssemblerState, token: Lexer.Token, token_line: usize, offset: usize) !i16 {
        const idx = token_line + offset;
        if (idx >= self.tokens.len) return AsmError.InvalidSyntax;
        const t = self.tokens[idx];
        if (t.type != .Immediate) return AsmError.InvalidSyntax;

        // Parse decimal or hex immediate
        const trimmed = std.mem.trim(u8, t.text, &std.ascii.whitespace);
        if (trimmed.len > 2 and trimmed[0] == '0' and (trimmed[1] == 'x' or trimmed[1] == 'X')) {
            return std.fmt.parseInt(i16, trimmed[2..], 16) catch AsmError.InvalidImmediate;
        } else {
            return std.fmt.parseInt(i16, trimmed, 10) catch AsmError.InvalidImmediate;
        }
    }

    /// Parse register string (r0-r31)
    fn parseRegister(reg_str: []const u8) !u5 {
        const trimmed = std.mem.trim(u8, reg_str, &std.ascii.whitespace);
        const num_str = if (trimmed.len > 1 and (trimmed[0] == 'r' or trimmed[0] == 'R' or trimmed[0] == 't' or trimmed[0] == 'T'))
            trimmed[1..]
        else
            trimmed;

        const num = std.fmt.parseInt(u8, num_str, 10) catch return AsmError.InvalidRegister;
        if (num > 31) return AsmError.InvalidRegister;
        return num;
    }

    /// Assemble .tasm source to .tbin bytecode
    pub fn assemble(allocator: Allocator, asm_source: []const u8) AsmError![]u8 {
        if (asm_source.len == 0) return AsmError.EmptySource;

        // Tokenize source
        var lexer = Lexer.init(allocator, asm_source);
        defer lexer.deinit();
        const tokens = try lexer.tokenize();

        if (tokens.len == 0) return AsmError.EmptySource;

        // Process tokens
        var state = AssemblerState.init(allocator, tokens);
        defer state.deinit();

        var token_idx: usize = 0;
        while (token_idx < tokens.len) {
            const token = tokens[token_idx];

            // Skip commas
            if (token.type == .Comma) {
                token_idx += 1;
                continue;
            }

            // Process instruction or label
            const word = try state.encodeInstruction(token);
            try state.bytecode.append(allocator, @as(u8, @truncate(word >> 24)));
            try state.bytecode.append(allocator, @as(u8, @truncate(word >> 16)));
            try state.bytecode.append(allocator, @as(u8, @truncate(word >> 8)));
            try state.bytecode.append(allocator, @as(u8, @truncate(word)));

            token_idx += 1;
        }

        return state.bytecode.toOwnedSlice(state.allocator);
    }
}

// Tests
test "assembler encodes nop" {
    const allocator = std.testing.allocator;
    const asm_source = "nop";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(u8, 0x00), result[0]);
}

test "assembler encodes add" {
    const allocator = std.testing.allocator;
    const asm_source = "add r5, r10, r15";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(u32, 0x10 | (5 << 8) | (10 << 11) | (15 << 14),
        (@as(u32, result[0]) << 24 | @as(u32, result[1]) << 16 | @as(u32, result[2]) << 8 | @as(u32, result[3])));
}

test "assembler encodes load_imm" {
    const allocator = std.testing.allocator;
    const asm_source = "load_imm r7, -42";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    // LD_IMM opcode = 0x84, r7 << 8, -42 immediate
    const expected: u32 = 0x84 | (7 << 8) | @as(u32, @bitCast(@as(i16, -42)) << 16);
    try std.testing.expectEqual(@as(u32, expected),
        (@as(u32, result[0]) << 24 | @as(u32, result[1]) << 16 | @as(u32, result[2]) << 8 | @as(u32, result[3])));
}

test "assembler encodes halt" {
    const allocator = std.testing.allocator;
    const asm_source = "halt";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(u32, 0x4D), result[0]);
}

test "assembler handles comments" {
    const allocator = std.testing.allocator;
    const asm_source = "nop ; comment\nadd r1, r2";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    // Only 2 instructions: nop and add (comments skipped)
    try std.testing.expectEqual(@as(usize, 8), result.len); // 4 bytes * 2
}

test "assembler handles labels" {
    const allocator = std.testing.allocator;
    const asm_source = "loop:\n  nop\n  jmp loop";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    // 2 instructions, JMP has no operand (should be resolved)
    try std.testing.expectEqual(@as(usize, 8), result.len);
}

test "assembler encodes tmul" {
    const allocator = std.testing.allocator;
    const asm_source = "tmul r1, r2, r3";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    // DOT opcode = 0x60
    const expected: u32 = 0x60 | (1 << 8) | (2 << 11) | (3 << 14);
    try std.testing.expectEqual(@as(u32, expected),
        (@as(u32, result[0]) << 24 | @as(u32, result[1]) << 16 | @as(u32, result[2]) << 8 | @as(u32, result[3])));
}
