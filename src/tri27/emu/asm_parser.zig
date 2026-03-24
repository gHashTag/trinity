// @origin(spec:tri_asm.tri) @regen(manual-impl)
// TRI-27 ASSEMBLER PARSER — Uses lexer + encoder for .tasm → .tbin
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const coptic = @import("../coptic.zig");
const CopticReg = coptic.CopticReg;
const glyphToReg = coptic.glyphToReg;

const Lexer = @import("asm_lexer.zig");
const TokenType = Lexer.TokenType;
const Token = Lexer.Token;
const encoder = @import("encoder_simple.zig");

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
    // Bank validation errors (Issue #407)
    SacredOpRequiresBank1,    // FADD/FMUL require Bank 1
    AluOpRequiresBank0,       // ADD/SUB require Bank 0
    CannotStoreToConstantBank, // ST_F rejects Bank 2
};

/// Parsed instruction
pub const ParsedInstruction = struct {
    opcode_str: []const u8,
    operands: std.ArrayList([]const u8),
    line: u32,

    pub fn deinit(self: *ParsedInstruction, allocator: Allocator) void {
        for (self.operands.items) |op| {
            allocator.free(op);
        }
        self.operands.deinit(allocator);
    }
};

/// Assembler state
pub const Assembler = struct {
    allocator: Allocator,
    tokens: []Token,
    bytecode: std.ArrayList(u8),
    labels: std.StringHashMap(u32),

    pub fn init(allocator: Allocator, tokens: []Token) Assembler {
        return .{
            .allocator = allocator,
            .tokens = tokens,
            .bytecode = std.ArrayList(u8).initCapacity(allocator, 128) catch unreachable,
            .labels = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Assembler) void {
        self.bytecode.deinit(self.allocator);
        // StringHashMap.deinit() frees all keys automatically
        self.labels.deinit();
    }

    /// Parse mnemonic and operands from tokens starting at index
    /// Supports Coptic glyph names (Ⲁ-Ϥ) as register aliases
    fn parseOperands(self: *Assembler, start_idx: usize) !ParsedInstruction {
        const start_token = self.tokens[start_idx];
        if (start_token.type != .Mnemonic) return AsmError.InvalidSyntax;

        var inst = ParsedInstruction{
            .opcode_str = start_token.text,
            .operands = std.ArrayList([]const u8).initCapacity(self.allocator, 8) catch unreachable,
            .line = start_token.line,
        };

        var i = start_idx + 1;
        var prev_was_comma = false;
        while (i < self.tokens.len) {
            const t = self.tokens[i];
            // Stop at end of input, comments, or next instruction (but allow one mnemonic after comma as label ref)
            if (t.type == .EOF or t.type == .Comment or t.type == .LabelDef) break;
            if (t.type == .Mnemonic and !prev_was_comma) break;
            if (t.type == .Comma) {
                i += 1;
                prev_was_comma = true;
                continue;
            }

            // Copy token text for operands
            const text_copy = try self.allocator.dupe(u8, t.text);
            try inst.operands.append(self.allocator, text_copy);
            i += 1;
            prev_was_comma = false;
        }

        return inst;
    }

    /// Encode mnemonic and operands to u32
    fn encode(self: *Assembler, mnemonic: []const u8, operands: []const []const u8) !u32 {
        const op_lower = std.ascii.allocLowerString(self.allocator, mnemonic) catch return AsmError.OutOfMemory;
        defer self.allocator.free(op_lower);

        if (std.mem.eql(u8, op_lower, "nop")) {
            return encoder.encode_nop(0);
        }

        if (std.mem.eql(u8, op_lower, "halt")) {
            return encoder.encode_halt();
        }

        // R-type: op dst, src1, src2
        if (std.mem.eql(u8, op_lower, "add")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_add(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "sub")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_sub(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "mul")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_mul(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "tmul")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_tmul(dst, src1, src2);
        }

        // I-type: op dst, imm
        if (std.mem.eql(u8, op_lower, "load_imm") or std.mem.eql(u8, op_lower, "ldi")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const imm = try parseImmediate(operands[1]);
            if (std.mem.eql(u8, op_lower, "load_imm")) {
                return encoder.encode_load_imm(dst, imm);
            } else {
                return encoder.encode_ldi(dst, imm);
            }
        }

        // M-type: op src, addr
        if (std.mem.eql(u8, op_lower, "store")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const src = try parseRegister(operands[0]);
            const addr = try parseImmediateU16(operands[1]);
            return encoder.encode_store(src, addr);
        }

        if (std.mem.eql(u8, op_lower, "sti")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const imm = try parseImmediate(operands[0]);
            const addr_u16 = try parseImmediateU16(operands[1]);
            const addr: u8 = @intCast(addr_u16 & 0xFF);
            return encoder.encode_sti(imm, addr);
        }

        if (std.mem.eql(u8, op_lower, "load")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const addr = try parseImmediateU16(operands[1]);
            return encoder.encode_load_mem(dst, addr);
        }

        // J-type: Jump instructions
        if (std.mem.eql(u8, op_lower, "jmp")) {
            if (operands.len != 1) return AsmError.InvalidSyntax;
            const imm = try resolveImmediateOrLabel(self, operands[0]);
            return encoder.encode_jmp(imm);
        }

        if (std.mem.eql(u8, op_lower, "jz")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const rd = try parseRegister(operands[0]);
            const imm = try resolveImmediateOrLabel(self, operands[1]);
            return encoder.encode_jz(rd, imm);
        }

        if (std.mem.eql(u8, op_lower, "jnz")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const rd = try parseRegister(operands[0]);
            const imm = try resolveImmediateOrLabel(self, operands[1]);
            return encoder.encode_jnz(rd, imm);
        }

        if (std.mem.eql(u8, op_lower, "call")) {
            if (operands.len != 1) return AsmError.InvalidSyntax;
            const imm = try resolveImmediateOrLabel(self, operands[0]);
            return encoder.encode_call(imm);
        }

        if (std.mem.eql(u8, op_lower, "ret")) {
            if (operands.len != 0) return AsmError.InvalidSyntax;
            return encoder.encode_ret();
        }

        // Logic opcodes (R-type like arithmetic)
        if (std.mem.eql(u8, op_lower, "and")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_and(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "or")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_or(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "xor")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_xor(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "not")) {
            if (operands.len != 1) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            return encoder.encode_not(dst);
        }

        if (std.mem.eql(u8, op_lower, "shl")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const shift_amt = try parseRegister(operands[1]); // Use register for shift amount
            return encoder.encode_shl(dst, shift_amt);
        }

        if (std.mem.eql(u8, op_lower, "shr")) {
            if (operands.len != 2) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const shift_amt = try parseRegister(operands[1]); // Use register for shift amount
            return encoder.encode_shr(dst, shift_amt);
        }

        // Additional arithmetic opcodes
        if (std.mem.eql(u8, op_lower, "div")) {
            if (operands.len != 3) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            const src1 = try parseRegister(operands[1]);
            const src2 = try parseRegister(operands[2]);
            return encoder.encode_div(dst, src1, src2);
        }

        if (std.mem.eql(u8, op_lower, "inc")) {
            if (operands.len != 1) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            return encoder.encode_inc(dst);
        }

        if (std.mem.eql(u8, op_lower, "dec")) {
            if (operands.len != 1) return AsmError.InvalidSyntax;
            const dst = try parseRegister(operands[0]);
            return encoder.encode_dec(dst);
        }

        return AsmError.UnknownOpcode;
    }

    /// Parse register string (r0-r31, t0-t26, or Coptic glyph Ⲁ-Ϥ)
    fn parseRegister(reg_str: []const u8) !u5 {
        const trimmed = std.mem.trim(u8, reg_str, &std.ascii.whitespace);

        // Try Coptic glyph first (Issue #407)
        if (glyphToReg(trim)) |reg| {
            return reg.regIndex();
        } else |_| {
            // Not a Coptic glyph, try ASCII format
            const num_str = if (trimmed.len > 1 and (trimmed[0] == 'r' or trimmed[0] == 'R' or trimmed[0] == 't' or trimmed[0] == 'T'))
                trimmed[1..]
            else
                trimmed;

            const num = std.fmt.parseInt(u8, num_str, 10) catch return AsmError.InvalidRegister;
            if (num > 31) return AsmError.InvalidRegister;
            return @as(u5, @intCast(num));
        }
    }

    /// Get bank for register number (0-26)
    fn getBank(reg: u5) u2 {
        return @intCast(reg / 9);
    }

    /// Validate sacred operation (FADD/FMUL require Bank 1)
    fn validateSacredOp(dst: u5, src: u5) !void {
        if (getBank(dst) != 1 or getBank(src) != 1) {
            return AsmError.SacredOpRequiresBank1;
        }
    }

    /// Validate ALU operation (ADD/SUB require Bank 0)
    fn validateAluOp(dst: u5, src1: u5, src2: u5) !void {
        if (getBank(dst) != 0 or getBank(src1) != 0 or getBank(src2) != 0) {
            return AsmError.AluOpRequiresBank0;
        }
    }

    /// Validate store to register (cannot store to Bank 2 constants)
    fn validateStore(dst: u5) !void {
        if (getBank(dst) == 2) {
            return AsmError.CannotStoreToConstantBank;
        }
    }

    /// Parse immediate value (decimal or hex)
    fn parseImmediate(imm_str: []const u8) !i16 {
        const trimmed = std.mem.trim(u8, imm_str, &std.ascii.whitespace);

        if (trimmed.len > 2 and trimmed[0] == '0' and (trimmed[1] == 'x' or trimmed[1] == 'X')) {
            return std.fmt.parseInt(i16, trimmed[2..], 16) catch return AsmError.InvalidImmediate;
        } else {
            return std.fmt.parseInt(i16, trimmed, 10) catch return AsmError.InvalidImmediate;
        }
    }

    /// Parse unsigned immediate (for addresses)
    fn parseImmediateU16(imm_str: []const u8) !u16 {
        const trimmed = std.mem.trim(u8, imm_str, &std.ascii.whitespace);

        if (trimmed.len > 2 and trimmed[0] == '0' and (trimmed[1] == 'x' or trimmed[1] == 'X')) {
            return std.fmt.parseInt(u16, trimmed[2..], 16) catch return AsmError.InvalidImmediate;
        } else {
            return std.fmt.parseInt(u16, trimmed, 10) catch return AsmError.InvalidImmediate;
        }
    }

    /// Resolve immediate or label reference
    fn resolveImmediateOrLabel(self: *Assembler, imm_str: []const u8) !i16 {
        const trimmed = std.mem.trim(u8, imm_str, &std.ascii.whitespace);

        // First try as immediate value
        if (trimmed.len > 2 and trimmed[0] == '0' and (trimmed[1] == 'x' or trimmed[1] == 'X')) {
            return std.fmt.parseInt(i16, trimmed[2..], 16) catch return AsmError.InvalidImmediate;
        }

        if (std.fmt.parseInt(i16, trimmed, 10)) |parsed| {
            return parsed;
        } else |_| {
            // If parsing as number fails, try as label
            if (self.labels.get(trimmed)) |addr| {
                // Calculate relative offset
                const current_addr: i32 = @intCast(self.bytecode.items.len);
                const target_addr: i32 = @intCast(addr);
                return @as(i16, @intCast(target_addr - current_addr));
            }
            return AsmError.UndefinedLabel;
        }
    }

    /// Write u32 as little-endian bytes
    fn writeWord(self: *Assembler, word: u32) !void {
        try self.bytecode.append(self.allocator, @as(u8, @truncate(word)));
        try self.bytecode.append(self.allocator, @as(u8, @truncate(word >> 8)));
        try self.bytecode.append(self.allocator, @as(u8, @truncate(word >> 16)));
        try self.bytecode.append(self.allocator, @as(u8, @truncate(word >> 24)));
    }

    /// Count instruction size without encoding (for label resolution)
    fn countInstructionSize(self: *Assembler, start_idx: usize) !usize {
        _ = self;
        _ = start_idx;
        // All instructions are 4 bytes
        return 4;
    }

    /// First pass: collect all labels and their addresses
    fn firstPass(self: *Assembler) !void {
        var i: usize = 0;
        var addr: u32 = 0;

        while (i < self.tokens.len) {
            const token = self.tokens[i];

            switch (token.type) {
                .EOF, .Comment, .EOL => {
                    i += 1;
                    continue;
                },
                .Comma => {
                    i += 1;
                    continue;
                },
                .LabelDef => {
                    // Record label at current address
                    try self.labels.put(token.text, addr);
                    i += 1;
                },
                .Mnemonic => {
                    // Each instruction is 4 bytes
                    addr += 4;
                    i += 1;
                    // Skip operands (including potential label references which are Mnemonic tokens)
                    var prev_was_comma = false;
                    while (i < self.tokens.len) {
                        const t = self.tokens[i];
                        if (t.type == .EOF or t.type == .Comment or t.type == .LabelDef) break;
                        if (t.type == .Mnemonic and !prev_was_comma) break;
                        if (t.type == .Comma) {
                            i += 1;
                            prev_was_comma = true;
                            continue;
                        }
                        i += 1;
                        prev_was_comma = false;
                    }
                },
                else => {
                    i += 1;
                },
            }
        }
    }

    /// Second pass: encode all instructions with resolved labels
    fn secondPass(self: *Assembler) !void {
        var i: usize = 0;

        while (i < self.tokens.len) {
            const token = self.tokens[i];

            switch (token.type) {
                .EOF, .Comment, .EOL => {
                    i += 1;
                    continue;
                },
                .Comma => {
                    i += 1;
                    continue;
                },
                .LabelDef => {
                    // Skip labels in second pass
                    i += 1;
                },
                .Mnemonic => {
                    // Parse operands
                    var inst = try self.parseOperands(i);
                    defer inst.deinit(self.allocator);

                    // Encode instruction (with label resolution)
                    const word = try self.encode(inst.opcode_str, inst.operands.items);

                    // Write to bytecode
                    try self.writeWord(word);

                    // Move to next token and skip operands
                    i += 1;
                    var prev_was_comma = false;
                    while (i < self.tokens.len) {
                        const t = self.tokens[i];
                        if (t.type == .EOF or t.type == .Comment or t.type == .LabelDef) break;
                        if (t.type == .Mnemonic and !prev_was_comma) break;
                        if (t.type == .Comma) {
                            i += 1;
                            prev_was_comma = true;
                            continue;
                        }
                        i += 1;
                        prev_was_comma = false;
                    }
                },
                else => {
                    i += 1;
                },
            }
        }
    }

    /// Main assemble function - two-pass for label resolution
    pub fn assemble(self: *Assembler) ![]u8 {
        if (self.tokens.len == 0) return AsmError.EmptySource;

        // First pass: collect all labels
        try self.firstPass();

        // Second pass: encode with resolved labels
        try self.secondPass();

        if (self.bytecode.items.len == 0) {
            return AsmError.EmptySource;
        }

        return self.bytecode.toOwnedSlice(self.allocator);
    }
};

test "assembler handles t-registers with LDI" {
    const allocator = std.testing.allocator;
    const source = "LDI t0, 1";
    const bytecode = try assemble(allocator, source);
    defer allocator.free(bytecode);
    try std.testing.expect(true); // If we got here without error, it worked
}

test "assembler handles t-registers with INC" {
    const allocator = std.testing.allocator;
    const source = "INC t0";
    const bytecode = try assemble(allocator, source);
    defer allocator.free(bytecode);
    try std.testing.expect(true); // If we got here without error, it worked
}

/// Public assemble function
pub fn assemble(allocator: Allocator, asm_source: []const u8) AsmError![]u8 {
    if (asm_source.len == 0) return AsmError.EmptySource;

    // Tokenize
    var lexer = Lexer.Lexer.init(allocator, asm_source);
    defer lexer.deinit();
    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    // Assemble
    var assembler = Assembler.init(allocator, tokens);
    const result = try assembler.assemble();
    assembler.deinit(); // Clean up assembler resources before returning
    return result;
}

// Tests
test "assembler encodes nop" {
    const allocator = std.testing.allocator;
    const asm_source = "nop";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(u8, 0x00), result[0]); // NOP opcode
}

test "assembler encodes add" {
    const allocator = std.testing.allocator;
    const asm_source = "add r5, r10, r15";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x10 | (5 << 8) | (10 << 13) | (15 << 18);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes sub" {
    const allocator = std.testing.allocator;
    const asm_source = "sub r1, r2, r3";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x11 | (1 << 8) | (2 << 13) | (3 << 18);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes load_imm" {
    const allocator = std.testing.allocator;
    const asm_source = "load_imm r7, -42";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const imm_u16: u16 = @bitCast(@as(i16, -42));
    const expected: u32 = 0x84 | (7 << 8) | (@as(u32, imm_u16) << 16);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes halt" {
    const allocator = std.testing.allocator;
    const asm_source = "halt";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(@as(u8, 0x4D), result[0]); // HALT opcode
}

test "assembler encodes tmul" {
    const allocator = std.testing.allocator;
    const asm_source = "tmul r1, r2, r3";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x60 | (1 << 8) | (2 << 13) | (3 << 18);
    try std.testing.expectEqual(expected, word);
}

test "assembler handles comments" {
    const allocator = std.testing.allocator;
    const asm_source = "nop ; this is a comment\nhalt";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 8), result.len); // 2 instructions
    try std.testing.expectEqual(@as(u8, 0x00), result[0]); // NOP
    try std.testing.expectEqual(@as(u8, 0x4D), result[4]); // HALT
}

test "assembler handles multi-line" {
    const allocator = std.testing.allocator;
    const asm_source = "nop\nadd r1, r2, r3\nhalt";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 12), result.len); // 3 instructions
}

test "assembler handles labels" {
    const allocator = std.testing.allocator;
    const asm_source = "loop: nop\nhalt";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 8), result.len);
}

test "assembler encodes store" {
    const allocator = std.testing.allocator;
    const asm_source = "store r5, 0x1000";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x03 | (5 << 8) | (0x1000 << 16);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes jmp" {
    const allocator = std.testing.allocator;
    const asm_source = "jmp 100";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x40 | (100 << 8);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes jz" {
    const allocator = std.testing.allocator;
    const asm_source = "jz r0, 10";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x41 | (10 << 16); // JZ opcode = 0x41, rd=0, imm=10 at bit 16
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes jnz" {
    const allocator = std.testing.allocator;
    const asm_source = "jnz r5, 20";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x42 | (5 << 8) | (20 << 16);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes call" {
    const allocator = std.testing.allocator;
    const asm_source = "call 50";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    const expected: u32 = 0x43 | (50 << 8);
    try std.testing.expectEqual(expected, word);
}

test "assembler encodes ret" {
    const allocator = std.testing.allocator;
    const asm_source = "ret";
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 4), result.len);
    const word = @as(u32, result[0]) | (@as(u32, result[1]) << 8) | (@as(u32, result[2]) << 16) | (@as(u32, result[3]) << 24);
    try std.testing.expectEqual(@as(u32, 0x4B), word);
}

test "assembler handles control flow with labels" {
    const allocator = std.testing.allocator;
    const asm_source =
        \\ldi r0, 1
        \\loop:
        \\ldi r1, 0
        \\jz r1, loop
        \\halt
    ;
    const result = try assemble(allocator, asm_source);
    defer allocator.free(result);

    // Should have 4 instructions (4 bytes each) = 16 bytes
    try std.testing.expectEqual(@as(usize, 16), result.len);
}
