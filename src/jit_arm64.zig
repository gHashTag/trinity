// Trinity JIT Compiler - ARM64 (AArch64) Backend
// Compiles VSA operations to native ARM64 machine code
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// ARM64 JIT COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if we're on ARM64
pub const is_arm64 = builtin.cpu.arch == .aarch64;

/// ARM64 JIT Compiler
pub const Arm64JitCompiler = struct {
    code: std.ArrayList(u8),
    allocator: std.mem.Allocator,
    exec_mem: ?[]align(16384) u8 = null, // ARM64 page size can be 16KB

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .code = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        if (self.exec_mem) |mem| {
            std.posix.munmap(mem);
        }
    }

    pub fn reset(self: *Self) void {
        self.code.clearRetainingCapacity();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARM64 INSTRUCTION ENCODING HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emit a 32-bit ARM64 instruction (little-endian)
    fn emit32(self: *Self, instr: u32) !void {
        try self.code.appendSlice(self.allocator, &std.mem.toBytes(instr));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ARM64 REGISTER ENCODING
    // ═══════════════════════════════════════════════════════════════════════════

    // X registers (64-bit): x0-x30, sp=31, xzr=31
    // W registers (32-bit): w0-w30, wzr=31
    const x0: u5 = 0;
    const x1: u5 = 1;
    const x2: u5 = 2;
    const x3: u5 = 3;
    const x8: u5 = 8;   // indirect result
    const x9: u5 = 9;   // temp
    const x10: u5 = 10; // temp
    const x11: u5 = 11; // temp
    const x19: u5 = 19; // callee-saved
    const x20: u5 = 20; // callee-saved
    const x21: u5 = 21; // callee-saved
    const x22: u5 = 22; // callee-saved
    const x29: u5 = 29; // frame pointer (fp)
    const x30: u5 = 30; // link register (lr)
    const sp: u5 = 31;  // stack pointer
    const xzr: u5 = 31; // zero register

    // ═══════════════════════════════════════════════════════════════════════════
    // ARM64 INSTRUCTION BUILDERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// STP (Store Pair) - stp Xt1, Xt2, [Xn, #imm]!  (pre-index)
    fn stpPreIndex(self: *Self, rt1: u5, rt2: u5, rn: u5, imm7: i7) !void {
        // STP (pre-index, 64-bit): 1 01 0 100 1 1 imm7 Rt2 Rn Rt1
        const uimm: u7 = @bitCast(imm7);
        const instr: u32 = 0xA9800000 |
            (@as(u32, uimm) << 15) |
            (@as(u32, rt2) << 10) |
            (@as(u32, rn) << 5) |
            @as(u32, rt1);
        try self.emit32(instr);
    }

    /// LDP (Load Pair) - ldp Xt1, Xt2, [Xn], #imm  (post-index)
    fn ldpPostIndex(self: *Self, rt1: u5, rt2: u5, rn: u5, imm7: i7) !void {
        // LDP (post-index, 64-bit): 1 01 0 100 0 1 1 imm7 Rt2 Rn Rt1
        const uimm: u7 = @bitCast(imm7);
        const instr: u32 = 0xA8C00000 |
            (@as(u32, uimm) << 15) |
            (@as(u32, rt2) << 10) |
            (@as(u32, rn) << 5) |
            @as(u32, rt1);
        try self.emit32(instr);
    }

    /// MOV (register) - mov Xd, Xn  (actually ORR Xd, XZR, Xn)
    fn movReg(self: *Self, rd: u5, rn: u5) !void {
        // ORR (shifted register): 1 01 01010 00 0 Rm 000000 Rn Rd
        const instr: u32 = 0xAA000000 |
            (@as(u32, rn) << 16) |
            (@as(u32, xzr) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// MOV (immediate) - mov Xd, #imm16
    fn movImm16(self: *Self, rd: u5, imm16: u16, shift: u2) !void {
        // MOVZ: 1 10 100101 hw imm16 Rd
        const instr: u32 = 0xD2800000 |
            (@as(u32, shift) << 21) |
            (@as(u32, imm16) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// MOVK (keep) - movk Xd, #imm16, lsl #shift
    fn movkImm16(self: *Self, rd: u5, imm16: u16, shift: u2) !void {
        // MOVK: 1 11 100101 hw imm16 Rd
        const instr: u32 = 0xF2800000 |
            (@as(u32, shift) << 21) |
            (@as(u32, imm16) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// Load 64-bit immediate into register
    fn loadImm64(self: *Self, rd: u5, imm: u64) !void {
        const imm0: u16 = @truncate(imm);
        const imm1: u16 = @truncate(imm >> 16);
        const imm2: u16 = @truncate(imm >> 32);
        const imm3: u16 = @truncate(imm >> 48);

        try self.movImm16(rd, imm0, 0);
        if (imm1 != 0) try self.movkImm16(rd, imm1, 1);
        if (imm2 != 0) try self.movkImm16(rd, imm2, 2);
        if (imm3 != 0) try self.movkImm16(rd, imm3, 3);
    }

    /// ADD (immediate) - add Xd, Xn, #imm12
    fn addImm(self: *Self, rd: u5, rn: u5, imm12: u12) !void {
        // ADD (imm): 1 00 100010 0 imm12 Rn Rd
        const instr: u32 = 0x91000000 |
            (@as(u32, imm12) << 10) |
            (@as(u32, rn) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// SUB (immediate) - sub Xd, Xn, #imm12
    fn subImm(self: *Self, rd: u5, rn: u5, imm12: u12) !void {
        // SUB (imm): 1 10 100010 0 imm12 Rn Rd
        const instr: u32 = 0xD1000000 |
            (@as(u32, imm12) << 10) |
            (@as(u32, rn) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// ADD (register) - add Xd, Xn, Xm
    fn addReg(self: *Self, rd: u5, rn: u5, rm: u5) !void {
        // ADD (reg): 1 00 01011 00 0 Rm 000000 Rn Rd
        const instr: u32 = 0x8B000000 |
            (@as(u32, rm) << 16) |
            (@as(u32, rn) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// MUL - mul Xd, Xn, Xm  (actually MADD Xd, Xn, Xm, XZR)
    fn mul(self: *Self, rd: u5, rn: u5, rm: u5) !void {
        // MADD: 1 00 11011 000 Rm 0 Ra Rn Rd
        const instr: u32 = 0x9B000000 |
            (@as(u32, rm) << 16) |
            (@as(u32, xzr) << 10) |
            (@as(u32, rn) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// SMULL - smull Xd, Wn, Wm (signed multiply long)
    fn smull(self: *Self, rd: u5, rn: u5, rm: u5) !void {
        // SMULL: 1 00 11011 0 01 Rm 0 11111 Rn Rd
        const instr: u32 = 0x9B207C00 |
            (@as(u32, rm) << 16) |
            (@as(u32, rn) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// LDRSB (register) - ldrsb Wt, [Xn, Xm]
    fn ldrsbReg(self: *Self, rt: u5, rn: u5, rm: u5) !void {
        // LDRSB (reg, 32-bit): 00 111 0 00 11 1 Rm 011 0 10 Rn Rt
        const instr: u32 = 0x38E06800 |
            (@as(u32, rm) << 16) |
            (@as(u32, rn) << 5) |
            @as(u32, rt);
        try self.emit32(instr);
    }

    /// LDRB (register) - ldrb Wt, [Xn, Xm]
    fn ldrbReg(self: *Self, rt: u5, rn: u5, rm: u5) !void {
        // LDRB (reg): 00 111 0 00 01 1 Rm 011 0 10 Rn Rt
        const instr: u32 = 0x38606800 |
            (@as(u32, rm) << 16) |
            (@as(u32, rn) << 5) |
            @as(u32, rt);
        try self.emit32(instr);
    }

    /// STRB (register) - strb Wt, [Xn, Xm]
    fn strbReg(self: *Self, rt: u5, rn: u5, rm: u5) !void {
        // STRB (reg): 00 111 0 00 00 1 Rm 011 0 10 Rn Rt
        const instr: u32 = 0x38206800 |
            (@as(u32, rm) << 16) |
            (@as(u32, rn) << 5) |
            @as(u32, rt);
        try self.emit32(instr);
    }

    /// CMP (immediate) - cmp Xn, #imm12
    fn cmpImm(self: *Self, rn: u5, imm12: u12) !void {
        // SUBS XZR, Xn, #imm12
        const instr: u32 = 0xF1000000 |
            (@as(u32, imm12) << 10) |
            (@as(u32, rn) << 5) |
            @as(u32, xzr);
        try self.emit32(instr);
    }

    /// CMP (register) - cmp Xn, Xm
    fn cmpReg(self: *Self, rn: u5, rm: u5) !void {
        // SUBS XZR, Xn, Xm
        const instr: u32 = 0xEB000000 |
            (@as(u32, rm) << 16) |
            (@as(u32, rn) << 5) |
            @as(u32, xzr);
        try self.emit32(instr);
    }

    /// B.cond - conditional branch
    fn bcond(self: *Self, cond: u4, offset: i19) !void {
        // B.cond: 0101010 0 imm19 0 cond
        const uoffset: u19 = @bitCast(offset);
        const instr: u32 = 0x54000000 |
            (@as(u32, uoffset) << 5) |
            @as(u32, cond);
        try self.emit32(instr);
    }

    /// B - unconditional branch
    fn b(self: *Self, offset: i26) !void {
        // B: 0 00101 imm26
        const uoffset: u26 = @bitCast(offset);
        const instr: u32 = 0x14000000 | @as(u32, uoffset);
        try self.emit32(instr);
    }

    /// RET - return
    fn retInstr(self: *Self) !void {
        // RET {Xn}: 1101011 0 0 10 11111 0000 0 0 Rn 00000
        const instr: u32 = 0xD65F0000 | (@as(u32, x30) << 5);
        try self.emit32(instr);
    }

    /// CSET - cset Xd, cond
    fn cset(self: *Self, rd: u5, cond: u4) !void {
        // CSINC Xd, XZR, XZR, invert(cond)
        const inv_cond = cond ^ 1;
        const instr: u32 = 0x9A9F0400 |
            (@as(u32, inv_cond) << 12) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    /// CSNEG - conditional select negate
    fn csneg(self: *Self, rd: u5, rn: u5, rm: u5, cond: u4) !void {
        // CSNEG: 1 1 0 11010100 Rm cond 0 1 Rn Rd
        const instr: u32 = 0xDA800400 |
            (@as(u32, rm) << 16) |
            (@as(u32, cond) << 12) |
            (@as(u32, rn) << 5) |
            @as(u32, rd);
        try self.emit32(instr);
    }

    // Condition codes
    const COND_EQ: u4 = 0;  // Equal
    const COND_NE: u4 = 1;  // Not equal
    const COND_GE: u4 = 10; // Signed >=
    const COND_LT: u4 = 11; // Signed <
    const COND_GT: u4 = 12; // Signed >
    const COND_LE: u4 = 13; // Signed <=

    // ═══════════════════════════════════════════════════════════════════════════
    // NEON SIMD REGISTERS AND INSTRUCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    // NEON vector registers V0-V31 (128-bit)
    // Use same encoding as X registers (0-31)
    const v0: u5 = 0;
    const v1: u5 = 1;
    const v2: u5 = 2;
    const v3: u5 = 3;
    const v4: u5 = 4;
    const v5: u5 = 5;
    const v6: u5 = 6;
    const v7: u5 = 7;
    const v16: u5 = 16; // callee-saved v8-v15, so use v16+ for temps
    const v17: u5 = 17;
    const v18: u5 = 18;
    const v19: u5 = 19;

    /// LD1 {Vt.16B}, [Xn] - Load 16 bytes into vector register
    fn ld1_16b(self: *Self, vt: u5, xn: u5) !void {
        // LD1 (single structure, no offset): 0 1 001100 0 10 0000 0111 00 Rn Rt
        // Q=1 (128-bit), size=00 (8-bit), opcode=0111
        const instr: u32 = 0x4C407000 |
            (@as(u32, xn) << 5) |
            @as(u32, vt);
        try self.emit32(instr);
    }

    /// LD1 {Vt.16B}, [Xn], #16 - Load 16 bytes with post-increment
    fn ld1_16b_post(self: *Self, vt: u5, xn: u5) !void {
        // LD1 (single structure, post-index, imm): 0 1 001100 1 10 11111 0111 00 Rn Rt
        const instr: u32 = 0x4CDF7000 |
            (@as(u32, xn) << 5) |
            @as(u32, vt);
        try self.emit32(instr);
    }

    /// SDOT Vd.4S, Vn.16B, Vm.16B - Signed dot product (ARMv8.4-A)
    /// Computes 4 dot products of 4 signed i8 values each, accumulates into 4 x i32
    fn sdot_4s(self: *Self, vd: u5, vn: u5, vm: u5) !void {
        // SDOT: 0 1 0 01110 10 0 Rm 1 0010 1 Rn Rd
        // Q=1 (128-bit), size=10, Rm, opcode=10010, U=0 (signed)
        const instr: u32 = 0x4E809400 |
            (@as(u32, vm) << 16) |
            (@as(u32, vn) << 5) |
            @as(u32, vd);
        try self.emit32(instr);
    }

    /// ADDV Sd, Vn.4S - Add across vector lanes to scalar
    fn addv_4s(self: *Self, vd: u5, vn: u5) !void {
        // ADDV: 0 1 0 01110 10 11000 1 1011 10 Rn Rd
        const instr: u32 = 0x4EB1B800 |
            (@as(u32, vn) << 5) |
            @as(u32, vd);
        try self.emit32(instr);
    }

    /// SMOV Xd, Vn.S[index] - Signed move from vector element to GPR
    fn smov_s(self: *Self, xd: u5, vn: u5, index: u2) !void {
        // SMOV: 0 1 0 0111 0 00 0 imm5 0 0101 1 Rn Rd
        // For S (32-bit) element, imm5 = (index << 3) | 0b00100
        const imm5: u5 = (@as(u5, index) << 3) | 0b00100;
        const instr: u32 = 0x4E002C00 |
            (@as(u32, imm5) << 16) |
            (@as(u32, vn) << 5) |
            @as(u32, xd);
        try self.emit32(instr);
    }

    /// MOVI Vd.4S, #0 - Move immediate to vector (zero vector)
    fn movi_4s_zero(self: *Self, vd: u5) !void {
        // MOVI: 0 1 0 01111 00000 cmode=0000 op=0 1 a:b:c:d:e:f:g:h Rd
        // For all zeros: cmode=0000, imm8=0
        const instr: u32 = 0x4F000400 |
            @as(u32, vd);
        try self.emit32(instr);
    }

    /// DUP Vd.4S, Xn - Duplicate GPR to all vector lanes
    fn dup_4s_gpr(self: *Self, vd: u5, xn: u5) !void {
        // DUP (general): 0 1 0 01110 00 0 imm5 0 0001 1 Rn Rd
        // For 4S, imm5 = 00100
        const instr: u32 = 0x4E040C00 |
            (@as(u32, xn) << 5) |
            @as(u32, vd);
        try self.emit32(instr);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VSA OPERATION COMPILATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Compile dot product for ARM64
    /// Returns i64 in x0
    pub fn compileDotProduct(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue: save fp, lr
        try self.stpPreIndex(x29, x30, sp, -2); // stp x29, x30, [sp, #-16]!
        try self.movReg(x29, sp);               // mov x29, sp

        // Save callee-saved registers
        try self.stpPreIndex(x19, x20, sp, -2); // stp x19, x20, [sp, #-16]!
        try self.stpPreIndex(x21, x22, sp, -2); // stp x21, x22, [sp, #-16]!

        // x19 = a pointer (first arg is in x0)
        // x20 = b pointer (second arg is in x1)
        // x21 = accumulator
        // x22 = loop counter
        try self.movReg(x19, x0);
        try self.movReg(x20, x1);
        try self.movImm16(x21, 0, 0);  // accumulator = 0
        try self.movImm16(x22, 0, 0);  // counter = 0

        // Load dimension into x9
        if (dimension <= 0xFFFF) {
            try self.movImm16(x9, @intCast(dimension), 0);
        } else {
            try self.loadImm64(x9, dimension);
        }

        // Loop start
        const loop_start = self.code.items.len;

        // Compare counter with dimension
        try self.cmpReg(x22, x9);

        // B.GE to loop end (will patch)
        const bge_offset = self.code.items.len;
        try self.bcond(COND_GE, 0); // placeholder

        // Load a[i] sign-extended into w10
        try self.ldrsbReg(x10, x19, x22);

        // Load b[i] sign-extended into w11
        try self.ldrsbReg(x11, x20, x22);

        // Multiply: x10 = x10 * x11
        try self.smull(x10, x10, x11);

        // Add to accumulator: x21 = x21 + x10
        try self.addReg(x21, x21, x10);

        // Increment counter
        try self.addImm(x22, x22, 1);

        // Branch back to loop start
        const loop_end_check = self.code.items.len;
        const back_offset: i26 = @intCast(@divExact(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(loop_end_check)), 4));
        try self.b(back_offset);

        // Loop end - patch the conditional branch
        const loop_end = self.code.items.len;
        const forward_offset: i19 = @intCast(@divExact(@as(i32, @intCast(loop_end)) - @as(i32, @intCast(bge_offset)), 4));
        const patched_instr: u32 = 0x54000000 |
            (@as(u32, @as(u19, @bitCast(forward_offset))) << 5) |
            @as(u32, COND_GE);
        @memcpy(self.code.items[bge_offset..][0..4], &std.mem.toBytes(patched_instr));

        // Move result to x0
        try self.movReg(x0, x21);

        // Restore callee-saved registers
        try self.ldpPostIndex(x21, x22, sp, 2); // ldp x21, x22, [sp], #16
        try self.ldpPostIndex(x19, x20, sp, 2); // ldp x19, x20, [sp], #16

        // Function epilogue
        try self.ldpPostIndex(x29, x30, sp, 2); // ldp x29, x30, [sp], #16
        try self.retInstr();
    }

    /// Compile SIMD dot product using NEON SDOT instruction (ARMv8.4-A)
    /// Processes 16 elements per iteration (4x speedup potential)
    /// Requires: dimension >= 16 and dimension % 16 == 0
    pub fn compileDotProductSIMD(self: *Self, dimension: usize) !void {
        if (dimension < 16 or dimension % 16 != 0) {
            return error.InvalidDimension;
        }

        self.reset();

        // Function prologue
        try self.stpPreIndex(x29, x30, sp, -2);
        try self.movReg(x29, sp);
        try self.stpPreIndex(x19, x20, sp, -2);

        // x19 = a pointer, x20 = b pointer
        try self.movReg(x19, x0);
        try self.movReg(x20, x1);

        // v0 = accumulator (initialized to zero)
        try self.movi_4s_zero(v0);

        // x9 = dimension / 16 (number of SIMD iterations)
        const num_iters = dimension / 16;
        if (num_iters <= 0xFFFF) {
            try self.movImm16(x9, @intCast(num_iters), 0);
        } else {
            try self.loadImm64(x9, num_iters);
        }

        // x10 = loop counter
        try self.movImm16(x10, 0, 0);

        // SIMD loop: process 16 elements per iteration
        const loop_start = self.code.items.len;

        // Compare counter with num_iters
        try self.cmpReg(x10, x9);
        const bge_offset = self.code.items.len;
        try self.bcond(COND_GE, 0); // placeholder, patch later

        // Load 16 bytes from a into v1
        try self.ld1_16b_post(v1, x19);

        // Load 16 bytes from b into v2
        try self.ld1_16b_post(v2, x20);

        // SDOT: v0.4s += dot(v1.16b, v2.16b)
        // This computes 4 dot products of 4 i8 values each
        try self.sdot_4s(v0, v1, v2);

        // Increment counter
        try self.addImm(x10, x10, 1);

        // Branch back to loop start
        const loop_end_check = self.code.items.len;
        const back_offset: i26 = @intCast(@divExact(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(loop_end_check)), 4));
        try self.b(back_offset);

        // Loop end - patch conditional branch
        const loop_end = self.code.items.len;
        const forward_offset: i19 = @intCast(@divExact(@as(i32, @intCast(loop_end)) - @as(i32, @intCast(bge_offset)), 4));
        const patched_instr: u32 = 0x54000000 |
            (@as(u32, @as(u19, @bitCast(forward_offset))) << 5) |
            @as(u32, COND_GE);
        @memcpy(self.code.items[bge_offset..][0..4], &std.mem.toBytes(patched_instr));

        // Horizontal add: sum all 4 lanes of v0.4s into scalar
        try self.addv_4s(v0, v0); // v0.s[0] = sum of all lanes

        // Move result from vector to x0 (sign-extended)
        try self.smov_s(x0, v0, 0);

        // Restore callee-saved registers
        try self.ldpPostIndex(x19, x20, sp, 2);

        // Function epilogue
        try self.ldpPostIndex(x29, x30, sp, 2);
        try self.retInstr();
    }

    /// Compile hybrid SIMD + scalar dot product for ANY dimension
    /// Uses SIMD for (dim/16)*16 elements, scalar for remainder
    pub fn compileDotProductHybrid(self: *Self, dimension: usize) !void {
        self.reset();

        const simd_iters = dimension / 16;
        const remainder = dimension % 16;

        // Function prologue
        try self.stpPreIndex(x29, x30, sp, -2);
        try self.movReg(x29, sp);
        try self.stpPreIndex(x19, x20, sp, -2);
        try self.stpPreIndex(x21, x22, sp, -2);

        // x19 = a pointer, x20 = b pointer
        try self.movReg(x19, x0);
        try self.movReg(x20, x1);

        // v0 = SIMD accumulator (zero)
        try self.movi_4s_zero(v0);

        // x21 = scalar accumulator (zero)
        try self.movImm16(x21, 0, 0);

        // ═══════════════════════════════════════════════════════════════
        // SIMD LOOP: Process 16 elements per iteration
        // ═══════════════════════════════════════════════════════════════
        if (simd_iters > 0) {
            // x9 = number of SIMD iterations
            if (simd_iters <= 0xFFFF) {
                try self.movImm16(x9, @intCast(simd_iters), 0);
            } else {
                try self.loadImm64(x9, simd_iters);
            }

            // x10 = SIMD loop counter
            try self.movImm16(x10, 0, 0);

            const simd_loop_start = self.code.items.len;

            // Compare counter with num_iters
            try self.cmpReg(x10, x9);
            const simd_bge_offset = self.code.items.len;
            try self.bcond(COND_GE, 0); // placeholder

            // Load 16 bytes from a into v1, post-increment x19
            try self.ld1_16b_post(v1, x19);

            // Load 16 bytes from b into v2, post-increment x20
            try self.ld1_16b_post(v2, x20);

            // SDOT: v0.4s += dot(v1.16b, v2.16b)
            try self.sdot_4s(v0, v1, v2);

            // Increment counter
            try self.addImm(x10, x10, 1);

            // Branch back to loop start
            const simd_loop_end_check = self.code.items.len;
            const simd_back_offset: i26 = @intCast(@divExact(@as(i32, @intCast(simd_loop_start)) - @as(i32, @intCast(simd_loop_end_check)), 4));
            try self.b(simd_back_offset);

            // Patch SIMD loop exit
            const simd_loop_end = self.code.items.len;
            const simd_forward_offset: i19 = @intCast(@divExact(@as(i32, @intCast(simd_loop_end)) - @as(i32, @intCast(simd_bge_offset)), 4));
            const simd_patched_instr: u32 = 0x54000000 |
                (@as(u32, @as(u19, @bitCast(simd_forward_offset))) << 5) |
                @as(u32, COND_GE);
            @memcpy(self.code.items[simd_bge_offset..][0..4], &std.mem.toBytes(simd_patched_instr));

            // Horizontal add SIMD result to scalar
            try self.addv_4s(v0, v0);
            try self.smov_s(x21, v0, 0);
        }

        // ═══════════════════════════════════════════════════════════════
        // SCALAR LOOP: Process remaining elements one by one
        // ═══════════════════════════════════════════════════════════════
        if (remainder > 0) {
            // x9 = remainder count
            try self.movImm16(x9, @intCast(remainder), 0);

            // x10 = scalar loop counter
            try self.movImm16(x10, 0, 0);

            const scalar_loop_start = self.code.items.len;

            // Compare counter with remainder
            try self.cmpReg(x10, x9);
            const scalar_bge_offset = self.code.items.len;
            try self.bcond(COND_GE, 0); // placeholder

            // Load a[i] sign-extended
            try self.ldrsbReg(x11, x19, x10);

            // Load b[i] sign-extended
            try self.ldrsbReg(x22, x20, x10);

            // Multiply
            try self.smull(x11, x11, x22);

            // Add to accumulator
            try self.addReg(x21, x21, x11);

            // Increment counter
            try self.addImm(x10, x10, 1);

            // Branch back
            const scalar_loop_end_check = self.code.items.len;
            const scalar_back_offset: i26 = @intCast(@divExact(@as(i32, @intCast(scalar_loop_start)) - @as(i32, @intCast(scalar_loop_end_check)), 4));
            try self.b(scalar_back_offset);

            // Patch scalar loop exit
            const scalar_loop_end = self.code.items.len;
            const scalar_forward_offset: i19 = @intCast(@divExact(@as(i32, @intCast(scalar_loop_end)) - @as(i32, @intCast(scalar_bge_offset)), 4));
            const scalar_patched_instr: u32 = 0x54000000 |
                (@as(u32, @as(u19, @bitCast(scalar_forward_offset))) << 5) |
                @as(u32, COND_GE);
            @memcpy(self.code.items[scalar_bge_offset..][0..4], &std.mem.toBytes(scalar_patched_instr));
        }

        // Move result to x0
        try self.movReg(x0, x21);

        // Restore callee-saved registers
        try self.ldpPostIndex(x21, x22, sp, 2);
        try self.ldpPostIndex(x19, x20, sp, 2);

        // Function epilogue
        try self.ldpPostIndex(x29, x30, sp, 2);
        try self.retInstr();
    }

    /// Compile bind operation for ARM64
    pub fn compileBindDirect(self: *Self, dimension: usize) !void {
        self.reset();

        // Function prologue
        try self.stpPreIndex(x29, x30, sp, -2);
        try self.movReg(x29, sp);
        try self.stpPreIndex(x19, x20, sp, -2);
        try self.stpPreIndex(x21, x22, sp, -2);

        // x19 = a pointer, x20 = b pointer, x21 = dimension, x22 = counter
        try self.movReg(x19, x0);
        try self.movReg(x20, x1);
        try self.movImm16(x22, 0, 0);

        if (dimension <= 0xFFFF) {
            try self.movImm16(x21, @intCast(dimension), 0);
        } else {
            try self.loadImm64(x21, dimension);
        }

        const loop_start = self.code.items.len;
        try self.cmpReg(x22, x21);

        const bge_offset = self.code.items.len;
        try self.bcond(COND_GE, 0);

        // Load a[i] and b[i]
        try self.ldrsbReg(x10, x19, x22);
        try self.ldrsbReg(x11, x20, x22);

        // Multiply (for ternary: -1*-1=1, -1*1=-1, 1*-1=-1, 1*1=1, 0*x=0)
        try self.smull(x10, x10, x11);

        // Store result
        try self.strbReg(x10, x19, x22);

        try self.addImm(x22, x22, 1);

        const loop_end_check = self.code.items.len;
        const back_offset: i26 = @intCast(@divExact(@as(i32, @intCast(loop_start)) - @as(i32, @intCast(loop_end_check)), 4));
        try self.b(back_offset);

        const loop_end = self.code.items.len;
        const forward_offset: i19 = @intCast(@divExact(@as(i32, @intCast(loop_end)) - @as(i32, @intCast(bge_offset)), 4));
        const patched_instr: u32 = 0x54000000 |
            (@as(u32, @as(u19, @bitCast(forward_offset))) << 5) |
            @as(u32, COND_GE);
        @memcpy(self.code.items[bge_offset..][0..4], &std.mem.toBytes(patched_instr));

        try self.ldpPostIndex(x21, x22, sp, 2);
        try self.ldpPostIndex(x19, x20, sp, 2);
        try self.ldpPostIndex(x29, x30, sp, 2);
        try self.retInstr();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Make code executable and return function pointer
    pub fn finalize(self: *Self) !*const fn (*anyopaque, *anyopaque) callconv(std.builtin.CallingConvention.c) i64 {
        const code_size = self.code.items.len;
        if (code_size == 0) return error.EmptyCode;

        // ARM64 can have 16KB pages on Apple Silicon
        const page_size: usize = 16384;
        const alloc_size = std.mem.alignForward(usize, code_size, page_size);

        const mem = try std.posix.mmap(
            null,
            alloc_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );

        @memcpy(mem[0..code_size], self.code.items);

        try std.posix.mprotect(mem, std.posix.PROT.READ | std.posix.PROT.EXEC);

        self.exec_mem = mem;

        return @ptrCast(mem.ptr);
    }

    pub fn codeSize(self: *const Self) usize {
        return self.code.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ARM64 JIT compiler init and deinit" {
    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    try std.testing.expectEqual(@as(usize, 0), compiler.codeSize());
}

test "ARM64 JIT dot product compilation" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileDotProduct(dim);

    // Code should be generated
    try std.testing.expect(compiler.codeSize() > 0);
    // ARM64 instructions are 4 bytes each
    try std.testing.expect(compiler.codeSize() % 4 == 0);
}

test "ARM64 JIT dot product execution" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileDotProduct(dim);

    const func = try compiler.finalize();

    // Create test data
    const a = [dim]i8{ 1, -1, 1, 0, 1, -1, 0, 1 };
    const b = [dim]i8{ 1, 1, -1, 1, 1, 1, 1, -1 };

    // Expected: 1*1 + (-1)*1 + 1*(-1) + 0*1 + 1*1 + (-1)*1 + 0*1 + 1*(-1)
    //         = 1 - 1 - 1 + 0 + 1 - 1 + 0 - 1 = -2
    const expected: i64 = -2;

    var a_mut = a;
    var b_mut = b;
    const result = func(@ptrCast(&a_mut), @ptrCast(&b_mut));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 JIT bind compilation" {
    if (!is_arm64) {
        return;
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 8;
    try compiler.compileBindDirect(dim);

    try std.testing.expect(compiler.codeSize() > 0);
    try std.testing.expect(compiler.codeSize() % 4 == 0);
}

test "ARM64 NEON SIMD dot product compilation" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 64; // Must be multiple of 16
    try compiler.compileDotProductSIMD(dim);

    try std.testing.expect(compiler.codeSize() > 0);
    try std.testing.expect(compiler.codeSize() % 4 == 0);
}

test "ARM64 NEON SIMD dot product execution" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 16; // Minimum SIMD dimension
    try compiler.compileDotProductSIMD(dim);

    const func = try compiler.finalize();

    // Create test data: all 1s dot all 1s = 16
    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    for (0..dim) |i| {
        a[i] = 1;
        b[i] = 1;
    }

    const expected: i64 = 16;
    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 NEON SIMD dot product with mixed values" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 32;
    try compiler.compileDotProductSIMD(dim);

    const func = try compiler.finalize();

    // Create test data: alternating 1, -1
    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    for (0..dim) |i| {
        a[i] = if (i % 2 == 0) 1 else -1;
        b[i] = 1;
    }
    // Expected: 16 * 1 + 16 * (-1) = 0
    const expected: i64 = 0;
    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 NEON SIMD dot product large dimension" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 256; // 16 SIMD iterations
    try compiler.compileDotProductSIMD(dim);

    const func = try compiler.finalize();

    // Create test data
    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;
    for (0..dim) |i| {
        // Ternary values: -1, 0, 1
        const val_a: i8 = @intCast(@as(i32, @intCast(i % 3)) - 1);
        const val_b: i8 = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
        a[i] = val_a;
        b[i] = val_b;
        expected += @as(i64, val_a) * @as(i64, val_b);
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 NEON SIMD benchmark vs scalar" {
    if (!is_arm64) {
        return; // Skip on non-ARM64
    }

    const dim = 1024; // Large dimension for meaningful benchmark
    const iterations = 10000;

    // Prepare test data
    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    for (0..dim) |i| {
        a[i] = @intCast(@as(i32, @intCast(i % 3)) - 1);
        b[i] = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
    }

    // Compile scalar version
    var scalar_compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer scalar_compiler.deinit();
    try scalar_compiler.compileDotProduct(dim);
    const scalar_func = try scalar_compiler.finalize();

    // Compile SIMD version
    var simd_compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer simd_compiler.deinit();
    try simd_compiler.compileDotProductSIMD(dim);
    const simd_func = try simd_compiler.finalize();

    // Benchmark scalar
    var timer = std.time.Timer.start() catch unreachable;
    var scalar_result: i64 = 0;
    for (0..iterations) |_| {
        scalar_result = scalar_func(@ptrCast(&a), @ptrCast(&b));
    }
    const scalar_ns = timer.read();

    // Benchmark SIMD
    timer.reset();
    var simd_result: i64 = 0;
    for (0..iterations) |_| {
        simd_result = simd_func(@ptrCast(&a), @ptrCast(&b));
    }
    const simd_ns = timer.read();

    // Verify results match
    try std.testing.expectEqual(scalar_result, simd_result);

    // Print benchmark results
    const scalar_ms = @as(f64, @floatFromInt(scalar_ns)) / 1_000_000.0;
    const simd_ms = @as(f64, @floatFromInt(simd_ns)) / 1_000_000.0;
    const speedup = scalar_ms / simd_ms;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("           ARM64 NEON SIMD BENCHMARK RESULTS\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Dimension: {d} elements\n", .{dim});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Scalar:  {d:.3} ms ({d:.0} ns/iter)\n", .{ scalar_ms, @as(f64, @floatFromInt(scalar_ns)) / @as(f64, iterations) });
    std.debug.print("  SIMD:    {d:.3} ms ({d:.0} ns/iter)\n", .{ simd_ms, @as(f64, @floatFromInt(simd_ns)) / @as(f64, iterations) });
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  SPEEDUP: {d:.2}x\n", .{speedup});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    // Assert SIMD is faster (at least 1.5x for this dimension)
    try std.testing.expect(speedup > 1.5);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID SIMD + SCALAR TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ARM64 hybrid dot product - aligned dimension (32)" {
    if (!is_arm64) return;

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 32; // Aligned: 2 SIMD iters, 0 scalar
    try compiler.compileDotProductHybrid(dim);
    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;
    for (0..dim) |i| {
        a[i] = 1;
        b[i] = 1;
        expected += 1;
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 hybrid dot product - non-aligned dimension (17)" {
    if (!is_arm64) return;

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 17; // Non-aligned: 1 SIMD iter + 1 scalar
    try compiler.compileDotProductHybrid(dim);
    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;
    for (0..dim) |i| {
        a[i] = 1;
        b[i] = 1;
        expected += 1;
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 hybrid dot product - small dimension (7)" {
    if (!is_arm64) return;

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 7; // Pure scalar: 0 SIMD iters, 7 scalar
    try compiler.compileDotProductHybrid(dim);
    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;
    for (0..dim) |i| {
        const val_a: i8 = if (i % 2 == 0) 1 else -1;
        a[i] = val_a;
        b[i] = 1;
        expected += val_a;
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 hybrid dot product - dimension 100" {
    if (!is_arm64) return;

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 100; // 6 SIMD iters + 4 scalar
    try compiler.compileDotProductHybrid(dim);
    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;
    for (0..dim) |i| {
        const val_a: i8 = @intCast(@as(i32, @intCast(i % 3)) - 1);
        const val_b: i8 = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
        a[i] = val_a;
        b[i] = val_b;
        expected += @as(i64, val_a) * @as(i64, val_b);
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 hybrid dot product - dimension 1000" {
    if (!is_arm64) return;

    var compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer compiler.deinit();

    const dim = 1000; // 62 SIMD iters + 8 scalar
    try compiler.compileDotProductHybrid(dim);
    const func = try compiler.finalize();

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    var expected: i64 = 0;
    for (0..dim) |i| {
        const val_a: i8 = @intCast(@as(i32, @intCast(i % 3)) - 1);
        const val_b: i8 = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
        a[i] = val_a;
        b[i] = val_b;
        expected += @as(i64, val_a) * @as(i64, val_b);
    }

    const result = func(@ptrCast(&a), @ptrCast(&b));
    try std.testing.expectEqual(expected, result);
}

test "ARM64 hybrid benchmark vs pure scalar" {
    if (!is_arm64) return;

    const dim = 1000; // Non-aligned dimension
    const iterations = 10000;

    var a: [dim]i8 = undefined;
    var b: [dim]i8 = undefined;
    for (0..dim) |i| {
        a[i] = @intCast(@as(i32, @intCast(i % 3)) - 1);
        b[i] = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
    }

    // Compile pure scalar
    var scalar_compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer scalar_compiler.deinit();
    try scalar_compiler.compileDotProduct(dim);
    const scalar_func = try scalar_compiler.finalize();

    // Compile hybrid
    var hybrid_compiler = Arm64JitCompiler.init(std.testing.allocator);
    defer hybrid_compiler.deinit();
    try hybrid_compiler.compileDotProductHybrid(dim);
    const hybrid_func = try hybrid_compiler.finalize();

    // Benchmark scalar
    var timer = std.time.Timer.start() catch unreachable;
    var scalar_result: i64 = 0;
    for (0..iterations) |_| {
        scalar_result = scalar_func(@ptrCast(&a), @ptrCast(&b));
    }
    const scalar_ns = timer.read();

    // Benchmark hybrid
    timer.reset();
    var hybrid_result: i64 = 0;
    for (0..iterations) |_| {
        hybrid_result = hybrid_func(@ptrCast(&a), @ptrCast(&b));
    }
    const hybrid_ns = timer.read();

    // Verify results match
    try std.testing.expectEqual(scalar_result, hybrid_result);

    const scalar_ms = @as(f64, @floatFromInt(scalar_ns)) / 1_000_000.0;
    const hybrid_ms = @as(f64, @floatFromInt(hybrid_ns)) / 1_000_000.0;
    const speedup = scalar_ms / hybrid_ms;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("        ARM64 HYBRID SIMD+SCALAR BENCHMARK (dim=1000)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  SIMD iters: {d}, Scalar remainder: {d}\n", .{ dim / 16, dim % 16 });
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Pure Scalar: {d:.3} ms ({d:.0} ns/iter)\n", .{ scalar_ms, @as(f64, @floatFromInt(scalar_ns)) / @as(f64, iterations) });
    std.debug.print("  Hybrid:      {d:.3} ms ({d:.0} ns/iter)\n", .{ hybrid_ms, @as(f64, @floatFromInt(hybrid_ns)) / @as(f64, iterations) });
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  SPEEDUP: {d:.2}x\n", .{speedup});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    // Hybrid should be faster
    try std.testing.expect(speedup > 1.5);
}
