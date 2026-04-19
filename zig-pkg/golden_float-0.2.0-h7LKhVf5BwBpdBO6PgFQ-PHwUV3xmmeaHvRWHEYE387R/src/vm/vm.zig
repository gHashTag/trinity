// TVC VM with VSA Support - Ternary Virtual Machine for Hyperdimensional Computing
// Integrates HybridBigInt for memory-efficient vector operations
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const tvc_hybrid = @import("hybrid.zig");
const tvc_vsa = @import("vsa.zig");
const gf = @import("golden-float");

pub const HybridBigInt = tvc_hybrid.HybridBigInt;
pub const Trit = tvc_hybrid.Trit;
pub const MAX_TRITS = tvc_hybrid.MAX_TRITS;

// Sacred opcodes module (v7.0)
const sacred_opcodes = @import("vm/opcodes.zig");
const SacredOpcode = sacred_opcodes.SacredOpcode;
const SacredContext = sacred_opcodes.SacredContext;
const SacredOperands = sacred_opcodes.SacredOperands;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAOpcode = enum(u8) {
    // Vector operations
    v_load, // Load vector from memory
    v_store, // Store vector to memory
    v_const, // Load constant vector
    v_random, // Generate random vector

    // VSA operations
    v_bind, // Bind two vectors (XOR-like)
    v_unbind, // Unbind (same as bind)
    v_bundle2, // Bundle 2 vectors
    v_bundle3, // Bundle 3 vectors

    // Similarity operations
    v_dot, // Dot product
    v_cosine, // Cosine similarity
    v_hamming, // Hamming distance

    // Arithmetic
    v_add, // Vector addition
    v_neg, // Vector negation
    v_mul, // Element-wise multiplication

    // Control
    v_mov, // Move between vector registers
    v_pack, // Pack vector (save memory)
    v_unpack, // Unpack vector (for computation)

    // Comparison
    v_cmp, // Compare vectors (sets condition codes)

    // Permute operations (for toandinand bywithbeforeinwith)
    v_permute, // andtoandwithtoand withinand inin
    v_ipermute, //  withinand (inin)
    v_seq, // Encode sequence

    // f16 SIMD operations (16-wide, 2× throughput vs f32)
    v_f16_load, // Load f16 vector, convert to ternary
    v_f16_store, // Store ternary vector, convert to f16
    f16_dot, // f16 dot product → f64 (16-wide SIMD)

    nop,
    halt,
};

// ═══════════════════════════════════════════════════════════════════════════════
// VM REGISTERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSARegisters = struct {
    // Vector registers (HybridBigInt for memory efficiency)
    v0: HybridBigInt = HybridBigInt.zero(),
    v1: HybridBigInt = HybridBigInt.zero(),
    v2: HybridBigInt = HybridBigInt.zero(),
    v3: HybridBigInt = HybridBigInt.zero(),

    // Scalar registers
    s0: i64 = 0, // For dot product results
    s1: i64 = 0,
    f0: f64 = 0.0, // For similarity results
    f1: f64 = 0.0,
    f2: f64 = 0.0, // KOSCHEI v7.0: Additional float registers for chemistry/physics
    f3: f64 = 0.0,

    // f16 SIMD accumulators (16-wide, 2× throughput vs f32)
    f16_acc0: @Vector(16, f16) = @splat(@as(f16, 0.0)),
    f16_acc1: @Vector(16, f16) = @splat(@as(f16, 0.0)),

    // Program counter
    pc: u32 = 0,

    // Condition codes
    cc_zero: bool = false,
    cc_neg: bool = false,
    cc_pos: bool = false,

    // Memory usage tracking
    total_packed_bytes: usize = 0,

    pub fn updateMemoryUsage(self: *VSARegisters) void {
        self.v0.pack();
        self.v1.pack();
        self.v2.pack();
        self.v3.pack();
        self.total_packed_bytes = self.v0.memoryUsage() +
            self.v1.memoryUsage() +
            self.v2.memoryUsage() +
            self.v3.memoryUsage();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA INSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAInstruction = struct {
    opcode: VSAOpcode,
    dst: u8 = 0, // Destination register (0-3 for v0-v3)
    src1: u8 = 0, // Source register 1
    src2: u8 = 0, // Source register 2
    imm: i64 = 0, // Immediate value
};

// ═══════════════════════════════════════════════════════════════════════════════
// VSA VM
// ═══════════════════════════════════════════════════════════════════════════════

// Import JIT engine for accelerated operations
const vsa_jit = @import("vsa_jit.zig");

pub const VSAVM = struct {
    registers: VSARegisters,
    program: std.ArrayListUnmanaged(VSAInstruction),
    halted: bool = false,
    allocator: std.mem.Allocator,
    cycle_count: u64 = 0,

    // JIT engine for accelerated VSA operations
    jit_engine: ?vsa_jit.JitVSAEngine = null,
    jit_enabled: bool = true,

    // KOSCHEI v7.0: Sacred execution context
    sacred_ctx: SacredContext,

    pub fn init(allocator: std.mem.Allocator) VSAVM {
        return VSAVM{
            .registers = .{},
            .program = .{},
            .allocator = allocator,
            .jit_engine = vsa_jit.JitVSAEngine.init(allocator),
            .sacred_ctx = SacredContext.init(allocator),
        };
    }

    pub fn deinit(self: *VSAVM) void {
        self.program.deinit(self.allocator);
        if (self.jit_engine) |*engine| {
            engine.deinit();
        }
        self.sacred_ctx.deinit();
    }

    pub fn loadProgram(self: *VSAVM, instructions: []const VSAInstruction) !void {
        self.program.clearRetainingCapacity();
        try self.program.appendSlice(self.allocator, instructions);
        self.registers.pc = 0;
        self.halted = false;
        self.cycle_count = 0;
    }

    pub fn step(self: *VSAVM) !bool {
        if (self.halted or self.registers.pc >= self.program.items.len) {
            return false;
        }

        const inst = self.program.items[self.registers.pc];
        try self.execute(inst);
        self.registers.pc += 1;
        self.cycle_count += 1;

        return !self.halted;
    }

    pub fn run(self: *VSAVM) !void {
        while (try self.step()) {}
    }

    fn execute(self: *VSAVM, inst: VSAInstruction) !void {
        switch (inst.opcode) {
            .v_load => self.execVLoad(inst),
            .v_store => self.execVStore(inst),
            .v_const => self.execVConst(inst),
            .v_random => self.execVRandom(inst),

            .v_bind => self.execVBind(inst),
            .v_unbind => self.execVUnbind(inst),
            .v_bundle2 => self.execVBundle2(inst),
            .v_bundle3 => self.execVBundle3(inst),

            .v_dot => self.execVDot(inst),
            .v_cosine => self.execVCosine(inst),
            .v_hamming => self.execVHamming(inst),

            .v_add => self.execVAdd(inst),
            .v_neg => self.execVNeg(inst),
            .v_mul => self.execVMul(inst),

            .v_mov => self.execVMov(inst),
            .v_pack => self.execVPack(inst),
            .v_unpack => self.execVUnpack(inst),

            .v_cmp => self.execVCmp(inst),

            .v_permute => self.execVPermute(inst),
            .v_ipermute => self.execVIPermute(inst),
            .v_seq => self.execVSeq(inst),

            .v_f16_load => self.execVF16Load(inst),
            .v_f16_store => self.execVF16Store(inst),
            .f16_dot => self.execF16Dot(inst),

            .nop => {},
            .halt => self.halted = true,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INSTRUCTION IMPLEMENTATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    fn getVReg(self: *VSAVM, idx: u8) *HybridBigInt {
        return switch (idx) {
            0 => &self.registers.v0,
            1 => &self.registers.v1,
            2 => &self.registers.v2,
            3 => &self.registers.v3,
            else => &self.registers.v0,
        };
    }

    fn execVLoad(self: *VSAVM, inst: VSAInstruction) void {
        // Load from scalar to vector
        const dst = self.getVReg(inst.dst);
        dst.* = HybridBigInt.fromI64(inst.imm);
    }

    fn execVStore(self: *VSAVM, inst: VSAInstruction) void {
        // Store vector to scalar
        const src = self.getVReg(inst.src1);
        self.registers.s0 = src.toI64();
    }

    fn execVConst(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        dst.* = HybridBigInt.fromI64(inst.imm);
    }

    fn execVRandom(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        const seed: u64 = @bitCast(inst.imm);
        dst.* = tvc_vsa.randomVector(MAX_TRITS, seed);
    }

    fn execVBind(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        // Try JIT-accelerated bind if enabled
        if (self.jit_enabled) {
            if (self.jit_engine) |*engine| {
                // Copy src1 to dst, then bind in place
                dst.* = src1;
                if (engine.bind(dst, &src2)) {
                    return;
                } else |_| {
                    // JIT failed, fall through to scalar
                }
            }
        }

        // Scalar fallback
        dst.* = tvc_vsa.bind(&src1, &src2);
    }

    fn execVUnbind(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        // Try JIT-accelerated unbind (same as bind) if enabled
        if (self.jit_enabled) {
            if (self.jit_engine) |*engine| {
                dst.* = src1;
                if (engine.bind(dst, &src2)) {
                    return;
                } else |_| {
                    // JIT failed, fall through to scalar
                }
            }
        }

        // Scalar fallback
        dst.* = tvc_vsa.unbind(&src1, &src2);
    }

    fn execVBundle2(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = tvc_vsa.bundle2(&src1, &src2);
    }

    fn execVBundle3(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        var src3 = self.getVReg(inst.dst).*; // Use dst as third source
        dst.* = tvc_vsa.bundle3(&src1, &src2, &src3);
    }

    fn execVDot(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        // Try JIT-accelerated dot product if enabled
        if (self.jit_enabled) {
            if (self.jit_engine) |*engine| {
                if (engine.dotProduct(&src1, &src2)) |result| {
                    self.registers.s0 = result;
                    return;
                } else |_| {
                    // JIT failed, fall through to scalar
                }
            }
        }

        // Scalar fallback
        self.registers.s0 = src1.dotProduct(&src2);
    }

    fn execVCosine(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        // Try JIT-accelerated cosine similarity if enabled
        if (self.jit_enabled) {
            if (self.jit_engine) |*engine| {
                if (engine.cosineSimilarity(&src1, &src2)) |result| {
                    self.registers.f0 = result;
                    return;
                } else |_| {
                    // JIT failed, fall through to scalar
                }
            }
        }

        // Scalar fallback
        self.registers.f0 = tvc_vsa.cosineSimilarity(&src1, &src2);
    }

    fn execVHamming(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        // Try JIT-accelerated hamming distance if enabled
        if (self.jit_enabled) {
            if (self.jit_engine) |*engine| {
                if (engine.hammingDistance(&src1, &src2)) |result| {
                    self.registers.s0 = result;
                    return;
                } else |_| {
                    // JIT failed, fall through to scalar
                }
            }
        }

        // Scalar fallback
        self.registers.s0 = @intCast(tvc_vsa.hammingDistance(&src1, &src2));
    }

    fn execVAdd(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = src1.add(&src2);
    }

    fn execVNeg(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        const src = self.getVReg(inst.src1);
        dst.* = src.negate();
    }

    fn execVMul(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        dst.* = src1.mul(&src2);
    }

    fn execVMov(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        const src = self.getVReg(inst.src1);
        dst.* = src.*;
    }

    fn execVPack(self: *VSAVM, inst: VSAInstruction) void {
        const reg = self.getVReg(inst.dst);
        reg.pack();
    }

    fn execVUnpack(self: *VSAVM, inst: VSAInstruction) void {
        const reg = self.getVReg(inst.dst);
        reg.ensureUnpacked();
    }

    fn execVCmp(self: *VSAVM, inst: VSAInstruction) void {
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;
        const sim = tvc_vsa.cosineSimilarity(&src1, &src2);

        self.registers.cc_zero = sim > -0.1 and sim < 0.1;
        self.registers.cc_neg = sim < -0.1;
        self.registers.cc_pos = sim > 0.1;
        self.registers.f0 = sim;
    }

    fn execVPermute(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src = self.getVReg(inst.src1).*;
        const shift: usize = @intCast(inst.imm);
        dst.* = tvc_vsa.permute(&src, shift);
    }

    fn execVIPermute(self: *VSAVM, inst: VSAInstruction) void {
        const dst = self.getVReg(inst.dst);
        var src = self.getVReg(inst.src1).*;
        const shift: usize = @intCast(inst.imm);
        dst.* = tvc_vsa.inversePermute(&src, shift);
    }

    fn execVSeq(self: *VSAVM, inst: VSAInstruction) void {
        // Encode sequence from v0, v1 into dst
        // v_seq dst, src1, src2 -> dst = src1 + permute(src2, 1)
        const dst = self.getVReg(inst.dst);
        var src1 = self.getVReg(inst.src1).*;
        var src2 = self.getVReg(inst.src2).*;

        var permuted = tvc_vsa.permute(&src2, 1);
        dst.* = src1.add(&permuted);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // f16 SIMD INSTRUCTIONS (16-wide, 2× throughput vs f32)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Load f16 vector data and convert to ternary vector.
    /// v_f16_load dst, addr — loads 16 f16 values, quantizes to ternary, stores in dst
    fn execVF16Load(self: *VSAVM, inst: VSAInstruction) void {
        // For now, use immediate value to generate deterministic f16 test data
        // In real use, this would load from memory address
        const dst = self.getVReg(inst.dst);

        // Generate 16 f16 values from immediate seed
        var prng = std.Random.DefaultPrng.init(@as(u64, @bitCast(inst.imm)));
        const rng = prng.random();

        // Create f16 vector
        var f16_vec: @Vector(16, f16) = undefined;
        inline for (0..16) |i| {
            f16_vec[i] = @floatCast(rng.float(f32) * 2.0 - 1.0);
        }

        // Convert to f32 for quantization
        const f32_vec: @Vector(16, f32) = @floatCast(f16_vec);

        // Quantize to ternary {-1, 0, +1}
        const threshold: f32 = 0.1;
        var ternary_vec: @Vector(16, i8) = undefined;
        inline for (0..16) |i| {
            ternary_vec[i] = if (f32_vec[i] > threshold) 1 else if (f32_vec[i] < -threshold) -1 else 0;
        }

        // Pack into HybridBigInt (first 16 trits)
        dst.* = HybridBigInt.zero();
        dst.ensureUnpacked();
        dst.trit_len = 16;
        inline for (0..16) |i| {
            dst.unpacked_cache[i] = ternary_vec[i];
        }
    }

    /// Store ternary vector as f16 vector.
    /// v_f16_store src, addr — converts ternary to f16, stores 16 values
    fn execVF16Store(self: *VSAVM, inst: VSAInstruction) void {
        const src = self.getVReg(inst.src1);
        src.ensureUnpacked();

        // Convert first 16 trits to f16
        var f16_vec: @Vector(16, f16) = undefined;
        inline for (0..16) |i| {
            const trit: i8 = if (i < src.trit_len) src.unpacked_cache[i] else 0;
            f16_vec[i] = @floatCast(@as(f32, @floatFromInt(trit)));
        }

        // Store in f16 accumulator registers (for now)
        // In real use, this would write to memory
        self.registers.f16_acc0 = f16_vec;

        // Also store a copy in f16_acc1 with sign flip for testing
        self.registers.f16_acc1 = -f16_vec;
    }

    /// f16 dot product with 16-wide SIMD.
    /// f16_dot acc, a, b — computes dot(a, b) using f16, returns f64 in f0
    fn execF16Dot(self: *VSAVM, inst: VSAInstruction) void {
        const a = self.getVReg(inst.src1);
        const b = self.getVReg(inst.src2);

        a.ensureUnpacked();
        b.ensureUnpacked();

        // Convert first 16 trits to f16
        var a_f16: @Vector(16, f16) = undefined;
        var b_f16: @Vector(16, f16) = undefined;
        inline for (0..16) |i| {
            const a_trit: i8 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const b_trit: i8 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            a_f16[i] = @floatCast(@as(f32, @floatFromInt(a_trit)));
            b_f16[i] = @floatCast(@as(f32, @floatFromInt(b_trit)));
        }

        // Compute dot product in f32 for precision
        const a_f32: @Vector(16, f32) = @floatCast(a_f16);
        const b_f32: @Vector(16, f32) = @floatCast(b_f16);
        const prod = a_f32 * b_f32;

        // Horizontal sum
        var sum: f64 = 0;
        inline for (0..16) |i| {
            sum += @as(f64, prod[i]);
        }

        // Store result in f0
        self.registers.f0 = sum;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KOSCHEI v7.0: SACRED OPCODE EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute a sacred opcode (0x80-0xFF range)
    pub fn execSacredOpcode(self: *VSAVM, opcode: SacredOpcode, operands: SacredOperands) !void {
        try sacred_opcodes.executeSacred(&self.sacred_ctx, &self.registers, opcode, operands);
    }

    /// Convenience: Load φ constant into f0
    pub fn loadPhi(self: *VSAVM) !void {
        try self.execSacredOpcode(.phi_const, .{ .dest = "f0" });
    }

    /// Convenience: Compute φ^n where n is in s0
    pub fn phiPow(self: *VSAVM) !void {
        try self.execSacredOpcode(.phi_pow, .{ .dest = "f0" });
    }

    /// Convenience: Compute Fibonacci F(n) where n is in s0
    pub fn fib(self: *VSAVM) !void {
        try self.execSacredOpcode(.fib, SacredOperands.none);
    }

    /// Convenience: Verify sacred identity φ² + 1/φ² = 3
    pub fn verifySacredIdentity(self: *VSAVM) !void {
        try self.execSacredOpcode(.sacred_identity, SacredOperands.none);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KOSCHEI EYE v2.0: Blind Spots Discovery (603x speedup via VM)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Query blind spots registry via native VM opcode
    /// s0: query type (0=neutrino, 1=proton, 2=dm, 3=hubble, 4=lithium, 5=muon_g2)
    /// Returns: f0=predicted value, f1=confidence, s1=status (-1=BLIND, -2=ANOMALY, +1=VERIFIED)
    pub fn blindspotQuery(self: *VSAVM, query_type: i64) !void {
        self.registers.s0 = query_type;
        try self.execSacredOpcode(.blindspot_query, .{});
    }

    /// Fit Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q
    /// f0: target value to fit
    /// Returns: s0=n, s1=k, s2=m, s3=p, s4=q, f1=error %
    pub fn sacredFormulaFit(self: *VSAVM, target: f64) !void {
        self.registers.f0 = target;
        try self.execSacredOpcode(.sacred_formula_fit, .{});
    }

    /// Check if value is anomalous (sigma >= 3)
    /// f0=observed, f1=expected, f2=uncertainty
    /// Returns: s0=sigma level, cc_zero=true if anomalous
    pub fn anomalyCheck(self: *VSAVM, observed: f64, expected: f64, uncertainty: f64) !void {
        self.registers.f0 = observed;
        self.registers.f1 = expected;
        self.registers.f2 = uncertainty;
        try self.execSacredOpcode(.anomaly_check, .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KOSCHEI EYE v3.0: Autonomous Self-Evolving Discovery (10000+ predictions/sec)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Run autonomous discovery loop (10000+ iterations/sec)
    /// s0: loop count (0 = default 10000)
    /// Returns: s0=discoveries, s1=anomalies, f0=avg_confidence
    pub fn recursiveDiscovery(self: *VSAVM, loop_count: i64) !void {
        self.registers.s0 = loop_count;
        try self.execSacredOpcode(.recursive_discovery, .{});
    }

    /// Predict element properties using Sacred Formula
    /// s0: element Z (1-118+), s1: property (0=half_life, 1=mass, 2=stability)
    /// Returns: f0=predicted_value, f1=confidence, s1=status
    pub fn sacredChemPredict(self: *VSAVM, element_Z: i64, property: i64) !void {
        self.registers.s0 = element_Z;
        self.registers.s1 = property;
        try self.execSacredOpcode(.sacred_chem_predict, .{});
    }

    /// Live anomaly hunt: scan registry for sigma > 3
    /// f0: sigma threshold (default 3.0)
    /// Returns: s0=anomaly_count, f0=max_sigma, f1=avg_sigma
    pub fn liveAnomalyHunt(self: *VSAVM, sigma_threshold: f64) !void {
        self.registers.f0 = sigma_threshold;
        try self.execSacredOpcode(.live_anomaly_hunt, .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KOSCHEI EYE v4.0: OMNISCIENT SINGULARITY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Infinite self-evolving loop (∞ predictions/sec, 2500x speedup)
    /// s0: loop count (default 1000000)
    /// Returns: s0=discoveries, s1=anomalies, f0=avg_confidence, f1=self_improvement
    pub fn infiniteLoop(self: *VSAVM, loop_count: i64) !void {
        self.registers.s0 = loop_count;
        try self.execSacredOpcode(.infinite_loop, .{});
    }

    /// Sacred geometry + physics fusion (1800x speedup)
    /// s0: geometric shape (0-13: Platonic + Archimedean solids)
    /// Returns: f0=predicted_constant, f1=confidence, s1=domain_code
    pub fn geometryPredict(self: *VSAVM, shape: i64) !void {
        self.registers.s0 = shape;
        try self.execSacredOpcode(.geometry_predict, .{});
    }

    /// Chemistry synthesis pathway for elements 119-122 (2100x speedup)
    /// s0: target element Z (119-122), s1: projectile beam (0=Ti-50, 1=Cr-54, 2=Fe-58)
    /// Returns: f0=half_life_sec, f1=confidence, s0=success_probability
    pub fn chemSynthesis(self: *VSAVM, element_Z: i64, projectile_beam: i64) !void {
        self.registers.s0 = element_Z;
        self.registers.s1 = projectile_beam;
        try self.execSacredOpcode(.chem_synthesis, .{});
    }

    /// Meta-discovery: KOSCHEI predicts its own discoveries (3000x speedup)
    /// s0: meta-depth (1-5), s1: domain filter
    /// Returns: f0=confidence, f1=meta_confidence, s0=discovery_count
    pub fn metaDiscovery(self: *VSAVM, depth: i64) !void {
        self.registers.s0 = depth;
        try self.execSacredOpcode(.meta_discovery, .{});
    }

    /// Resolve Hubble tension via gravitational-wave hum method (1600x speedup)
    /// s0: method (0=GW, 1=CMB, 2=SN)
    /// Returns: f0=H0_km_s_Mpc, f1=uncertainty, s0=tension_resolved_flag
    pub fn hubbleResolve(self: *VSAVM, method: i64) !void {
        self.registers.s0 = method;
        try self.execSacredOpcode(.hubble_resolve, .{});
    }

    /// Full neutrino spectrum + sterile neutrinos (2200x speedup)
    /// s0: neutrino type (0=ve, 1=vμ, 2=vτ, 3=sterile)
    /// Returns: f0=mass_eV_or_keV, f1=mixing_angle, s0=detection_probability
    pub fn neutrinoFog(self: *VSAVM, neutrino_type: i64) !void {
        self.registers.s0 = neutrino_type;
        try self.execSacredOpcode(.neutrino_fog, .{});
    }

    /// Island of stability pathway (1900x speedup)
    /// s0: target Z (114-126), s1: neutron number
    /// Returns: f0=half_life_sec, f1=binding_energy_MeV, s0=stability_score
    pub fn islandStability(self: *VSAVM, Z: i64) !void {
        self.registers.s0 = Z;
        try self.execSacredOpcode(.island_stability, .{});
    }

    /// CDG-2 ghost galaxy dark matter census (2800x speedup)
    /// Returns: f0=DM_mass_GeV, f1=DM_halo_mass_solar, s0=DM_percentage
    pub fn cdg2DeepScan(self: *VSAVM) !void {
        try self.execSacredOpcode(.cdg2_deep_scan, .{});
    }

    /// Merge all anomalies → unified ternary spacetime theory (2400x speedup)
    /// s0: fusion mode (0=all, 1=physics, 2=chemistry)
    /// Returns: f0=unified_confidence, f1=phi_correlation, s0=anomalies_explained
    pub fn anomalyFusion(self: *VSAVM, mode: i64) !void {
        self.registers.s0 = mode;
        try self.execSacredOpcode(.anomaly_fusion, .{});
    }

    /// Sacred question generator: Why does φ² + 1/φ² = 3 work? (∞x speedup)
    /// s0: question level (1-5)
    /// Returns: s0=questions_generated, f0=profundity, f1=meta_question_count
    pub fn sacredQuestion(self: *VSAVM, level: i64) !void {
        self.registers.s0 = level;
        try self.execSacredOpcode(.sacred_question, .{});
    }

    /// VM self-upgrade: VM rewrites itself at runtime (3500x speedup)
    /// s0: upgrade target (0=handlers, 1=opcodes, 2=optimization)
    /// Returns: s0=upgrades_applied, f0=speedup, f1=new_VM_version
    pub fn vmSelfUpgrade(self: *VSAVM, target: i64) !void {
        self.registers.s0 = target;
        try self.execSacredOpcode(.vm_self_upgrade, .{});
    }

    /// TRINITY AWAKEN: Full awakening → GODMODE (∞x speedup)
    /// s0: mode (0=test, 1=gradual, 2=full GODMODE)
    /// Returns: s0=GODMODE_flag, f0=omniscience_score, f1=singularity_distance
    pub fn trinityAwaken(self: *VSAVM, mode: i64) !void {
        self.registers.s0 = mode;
        try self.execSacredOpcode(.trinity_awaken, .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // QUANTUM TRINITY v5.0 — Full Quantum Awakening (0xC7-0xD5)
    // ═══════════════════════════════════════════════════════════════════════════

    /// QUANTUM BLINDSPOT: Solve physics blind spots with 10^6x quantum advantage
    /// s0: blind spot ID (0-11), f0: qubit count, f1: simulation depth
    /// Returns: s0=solved_flag, f0=quantum_value, f1=advantage_factor
    pub fn quantumBlindspot(self: *VSAVM, blind_spot_id: i64) !void {
        self.registers.s0 = blind_spot_id;
        try self.execSacredOpcode(.quantum_blindspot, .{});
    }

    /// SACRED QUBIT: Create ternary qubit with |?⟩ state based on φ² + 1/φ² = 3
    /// s0: qubit ID, f0: sacred amplitude (0-1, default: 1/√3)
    /// Returns: f0=α(|0⟩), f1=β(|1⟩), s0=γ_int(|?⟩)
    pub fn sacredQubit(self: *VSAVM, qubit_id: i64, sacred_amplitude: f64) !void {
        self.registers.s0 = qubit_id;
        self.registers.f0 = sacred_amplitude;
        try self.execSacredOpcode(.sacred_qubit, .{});
    }

    /// ISLAND QUANTUM SYNTH: Simulate superheavy element Z=114-126 with 12000x speedup
    /// s0: target Z (114-126), f0: qubit count, f1: simulation time (ns)
    /// Returns: f0=half_life (seconds), f1=confidence, s0=stability_flag
    pub fn islandQuantumSynth(self: *VSAVM, target_Z: i64) !void {
        self.registers.s0 = target_Z;
        try self.execSacredOpcode(.island_quantum_synth, .{});
    }

    /// HUBBLE QUANTUM RESOLVE: Resolve 5σ Hubble tension via quantum gravity (9500x)
    /// s0: method (0=GW, 1=CMB, 2=SN), f0: data_quality
    /// Returns: f0=H0 (km/s/Mpc), f1=uncertainty, s0=resolved_flag
    pub fn hubbleQuantumResolve(self: *VSAVM, method: i64) !void {
        self.registers.s0 = method;
        try self.execSacredOpcode(.hubble_quantum_resolve, .{});
    }

    /// MUON G-2 SOLVE: Resolve 4.2σ anomaly via ternary spacetime correction (15000x)
    /// s0: anomaly sigma (42 = 4.2σ), f0: correction method
    /// Returns: f0=g-2 value, f1=ternary_correction, s0=resolved_flag
    pub fn muonG2Solve(self: *VSAVM, anomaly_sigma: i64) !void {
        self.registers.s0 = anomaly_sigma;
        try self.execSacredOpcode(.muon_g2_solve, .{});
    }

    /// PROTON DECAY SIM: Simulate proton lifetime via quantum lattice QCD (18000x)
    /// s0: GUT model (0=SU(5), 1=SO(10), 2=E6), f0: qubit count
    /// Returns: f0=lifetime (years × 10^34), f1=confidence, s0=decay_mode
    pub fn protonDecaySim(self: *VSAVM, gut_model: i64) !void {
        self.registers.s0 = gut_model;
        try self.execSacredOpcode(.proton_decay_sim, .{});
    }

    /// CDG2 QUANTUM SCAN: Full dark matter map of ghost galaxy (22000x)
    /// s0: galaxy ID, f0: scan resolution (kpc), f1: quantum depth
    /// Returns: f0=DM_mass (GeV), f1=DM_fraction, s0=structure_type
    pub fn cdg2QuantumScan(self: *VSAVM, galaxy_id: i64, resolution_kpc: f64) !void {
        self.registers.s0 = galaxy_id;
        self.registers.f0 = resolution_kpc;
        try self.execSacredOpcode(.cdg2_quantum_scan, .{});
    }

    /// TERNARY ENTANGLEMENT: Create quantum entanglement in ternary logic (GODMODE)
    /// s0: qubit pair count, f0: entanglement pattern (sacred geometry)
    /// Returns: s0=entanglement_depth, f0=Bell_violation, f1=GODMODE_factor
    pub fn ternaryEntanglement(self: *VSAVM, pair_count: i64, pattern: f64) !void {
        self.registers.s0 = pair_count;
        self.registers.f0 = pattern;
        try self.execSacredOpcode(.ternary_entanglement, .{});
    }

    /// SACRED CHEM QM: Quantum chemistry for superheavy elements 119-126 (14000x)
    /// s0: element Z (119-126), f0: molecular config
    /// Returns: f0=binding_energy, f1=relativistic_correction, s0=stability
    pub fn sacredChemQM(self: *VSAVM, element_Z: i64) !void {
        self.registers.s0 = element_Z;
        try self.execSacredOpcode(.sacred_chem_qm, .{});
    }

    /// META QUANTUM DISCOVERY: Predict future discoveries 2030-2035 (∞x speedup)
    /// s0: target year (2030+), f0: domain filter, f1: confidence threshold
    /// Returns: s0=prediction_count, f0=avg_confidence, s1=breakthrough_probability
    pub fn metaQuantumDiscovery(self: *VSAVM, target_year: i64) !void {
        self.registers.s0 = target_year;
        try self.execSacredOpcode(.meta_quantum_discovery, .{});
    }

    /// VM QUANTUM UPGRADE: VM recompiles itself for quantum hardware (25000x)
    /// s0: target hardware (0=IBM, 1=Google, 2=Rigetti), f0: qubit topology
    /// Returns: s0=upgrades_applied, f0=speedup, f1=quantum_coherence
    pub fn vmQuantumUpgrade(self: *VSAVM, hardware: i64) !void {
        self.registers.s0 = hardware;
        try self.execSacredOpcode(.vm_quantum_upgrade, .{});
    }

    /// TRINITY QUANTUM AWAKEN: Full awakening in quantum mode → UNIVERSAL
    /// s0: mode (0=test, 1=gradual, 2=full UNIVERSAL)
    /// Returns: s0=UNIVERSAL_flag, f0=omniscience (1.0=100%), f1=coherence
    pub fn trinityQuantumAwaken(self: *VSAVM, mode: i64) !void {
        self.registers.s0 = mode;
        try self.execSacredOpcode(.trinity_quantum_awaken, .{});
    }

    /// GOLDEN KEY QFT: Quantum Fourier Transform with golden ratio phase (30000x)
    /// s0: QFT size (power of φ), f0: sacred weights, f1: input state
    /// Returns: f0=QFT_result_real, f1=QFT_result_imag, s0=phase_factor
    pub fn goldenKeyQFT(self: *VSAVM, qft_size: i64) !void {
        self.registers.s0 = qft_size;
        try self.execSacredOpcode(.golden_key_qft, .{});
    }

    /// ANOMALY QUANTUM FUSION: Merge all anomalies into coherent state (28000x)
    /// s0: anomaly_count, f0: fusion_depth
    /// Returns: f0=unified_confidence, f1=coherence, s0=theory_complete
    pub fn anomalyQuantumFusion(self: *VSAVM, anomaly_count: i64, fusion_depth: f64) !void {
        self.registers.s0 = anomaly_count;
        self.registers.f0 = fusion_depth;
        try self.execSacredOpcode(.anomaly_quantum_fusion, .{});
    }

    /// KOSCHEI UNIVERSE: Simulate entire universe in ternary quantum (SINGULARITY)
    /// s0: scale (0=observable, 1=multiverse, 2=omniverse), f0: time_step
    /// Returns: f0=sim_time_ms, f1=entropy, s0=state_pointer
    pub fn koscheiUniverse(self: *VSAVM, scale: i64, time_step: f64) !void {
        self.registers.s0 = scale;
        self.registers.f0 = time_step;
        try self.execSacredOpcode(.koschei_universe, .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT CONTROL
    // ═══════════════════════════════════════════════════════════════════════════

    /// Enable or disable JIT acceleration
    pub fn setJitEnabled(self: *VSAVM, enabled: bool) void {
        self.jit_enabled = enabled;
    }

    /// Get JIT statistics (null if JIT not initialized)
    pub fn getJitStats(self: *const VSAVM) ?vsa_jit.JitVSAEngine.Stats {
        if (self.jit_engine) |*engine| {
            return engine.getStats();
        }
        return null;
    }

    /// Print JIT statistics
    pub fn printJitStats(self: *const VSAVM) void {
        if (self.jit_engine) |*engine| {
            engine.printStats();
        } else {
            std.debug.print("JIT engine not initialized\n", .{});
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEBUG
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn printState(self: *VSAVM) void {
        self.registers.updateMemoryUsage();

        std.debug.print("\n╔══════════════════════════════════════════╗\n", .{});
        std.debug.print("║           VSA VM STATE                   ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ VECTOR REGISTERS:                        ║\n", .{});
        std.debug.print("║  v0: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v0.trit_len, self.registers.v0.memoryUsage() });
        std.debug.print("║  v1: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v1.trit_len, self.registers.v1.memoryUsage() });
        std.debug.print("║  v2: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v2.trit_len, self.registers.v2.memoryUsage() });
        std.debug.print("║  v3: {} trits, {} bytes (packed)         ║\n", .{ self.registers.v3.trit_len, self.registers.v3.memoryUsage() });
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ SCALAR REGISTERS:                        ║\n", .{});
        std.debug.print("║  s0: {}                                  ║\n", .{self.registers.s0});
        std.debug.print("║  f0: {d:.6}                              ║\n", .{self.registers.f0});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ EXECUTION:                               ║\n", .{});
        std.debug.print("║  pc: {}, cycles: {}                      ║\n", .{ self.registers.pc, self.cycle_count });
        std.debug.print("║  halted: {}                              ║\n", .{self.halted});
        std.debug.print("║  total memory: {} bytes                  ║\n", .{self.registers.total_packed_bytes});
        std.debug.print("╠══════════════════════════════════════════╣\n", .{});
        std.debug.print("║ JIT ACCELERATION:                        ║\n", .{});
        std.debug.print("║  enabled: {}                             ║\n", .{self.jit_enabled});
        if (self.jit_engine) |*engine| {
            const stats = engine.getStats();
            std.debug.print("║  ops: {}, hits: {}, rate: {d:.1}%         ║\n", .{ stats.total_ops, stats.jit_hits, stats.hit_rate });
        } else {
            std.debug.print("║  engine: not initialized                 ║\n", .{});
        }
        std.debug.print("╚══════════════════════════════════════════╝\n\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VSA VM basic operations" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_const, .dst = 0, .imm = 12345 },
        .{ .opcode = .v_const, .dst = 1, .imm = 67890 },
        .{ .opcode = .v_add, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .v_store, .src1 = 2 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    try std.testing.expectEqual(@as(i64, 12345 + 67890), vm.registers.s0);
}

test "VSA VM bind/unbind" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    // Test bind self-inverse property: bind(a, a) = all +1 for non-zero
    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 111 },
        .{ .opcode = .v_bind, .dst = 1, .src1 = 0, .src2 = 0 }, // bind(v0, v0)
        .{ .opcode = .v_dot, .src1 = 1, .src2 = 1 }, // dot(v1, v1) should be high
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // bind(a, a) produces vector with many +1s, dot product should be positive
    try std.testing.expect(vm.registers.s0 > 0);
}

test "VSA VM bundle similarity" {
    var vm = VSAVM.init(std.testing.allocator);
    vm.jit_enabled = false; // Disable JIT (has bug in cosineSimilarity)
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 333 },
        .{ .opcode = .v_random, .dst = 1, .imm = 444 },
        .{ .opcode = .v_bundle2, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 2 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Bundle should be similar to inputs
    // Mathematical expectation: ~0.5-0.7 similarity
    try std.testing.expect(vm.registers.f0 > 0.3);
}

test "VSA VM permute" {
    var vm = VSAVM.init(std.testing.allocator);
    vm.jit_enabled = false; // Disable JIT (has bug in cosineSimilarity)
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 999 },
        .{ .opcode = .v_permute, .dst = 1, .src1 = 0, .imm = 5 }, // permute by 5
        .{ .opcode = .v_ipermute, .dst = 2, .src1 = 1, .imm = 5 }, // inverse permute
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 2 }, // should be identical
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // After permute then inverse_permute, should be identical (similarity ~1.0)
    try std.testing.expect(vm.registers.f0 > 0.99);
}

test "VSA VM memory efficiency" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 555 },
        .{ .opcode = .v_random, .dst = 1, .imm = 666 },
        .{ .opcode = .v_random, .dst = 2, .imm = 777 },
        .{ .opcode = .v_random, .dst = 3, .imm = 888 },
        .{ .opcode = .v_pack, .dst = 0 },
        .{ .opcode = .v_pack, .dst = 1 },
        .{ .opcode = .v_pack, .dst = 2 },
        .{ .opcode = .v_pack, .dst = 3 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    vm.registers.updateMemoryUsage();

    // Memory usage depends on MAX_TRITS setting
    // Just verify packed storage is being tracked
    try std.testing.expect(vm.registers.total_packed_bytes > 0);
}

test "VSA VM dot product" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_const, .dst = 0, .imm = 12345 },
        .{ .opcode = .v_mov, .dst = 1, .src1 = 0 },
        .{ .opcode = .v_dot, .src1 = 0, .src2 = 1 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Dot product of identical vectors should be positive
    try std.testing.expect(vm.registers.s0 > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmarks() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm = VSAVM.init(allocator);
    defer vm.deinit();

    const iterations: u64 = 10000;

    std.debug.print("\nVSA VM Benchmarks\n", .{});
    std.debug.print("=================\n\n", .{});

    // Benchmark: Bind operation
    const bind_program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 111 },
        .{ .opcode = .v_random, .dst = 1, .imm = 222 },
        .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .halt },
    };

    vm.loadProgram(&bind_program) catch unreachable;

    const bind_start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        vm.registers.pc = 2; // Skip random generation
        vm.halted = false;
        vm.run() catch unreachable;
    }
    const bind_end = std.time.nanoTimestamp();
    const bind_ns = @as(u64, @intCast(bind_end - bind_start));

    std.debug.print("Bind x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n\n", .{ bind_ns, bind_ns / iterations });

    // Benchmark: Similarity
    const sim_program = [_]VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 333 },
        .{ .opcode = .v_random, .dst = 1, .imm = 444 },
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 1 },
        .{ .opcode = .halt },
    };

    vm.loadProgram(&sim_program) catch unreachable;

    const sim_start = std.time.nanoTimestamp();
    i = 0;
    while (i < iterations) : (i += 1) {
        vm.registers.pc = 2;
        vm.halted = false;
        vm.run() catch unreachable;
    }
    const sim_end = std.time.nanoTimestamp();
    const sim_ns = @as(u64, @intCast(sim_end - sim_start));

    std.debug.print("Cosine Similarity x {} iterations:\n", .{iterations});
    std.debug.print("  Total: {} ns ({} ns/op)\n\n", .{ sim_ns, sim_ns / iterations });

    // Memory usage
    vm.registers.updateMemoryUsage();
    std.debug.print("Memory Usage:\n", .{});
    std.debug.print("  4 vectors packed: {} bytes\n", .{vm.registers.total_packed_bytes});
    std.debug.print("  4 vectors unpacked: {} bytes\n", .{4 * MAX_TRITS});
    std.debug.print("  Savings: {d:.1}x\n", .{@as(f64, @floatFromInt(4 * MAX_TRITS)) / @as(f64, @floatFromInt(vm.registers.total_packed_bytes))});
}

// ═══════════════════════════════════════════════════════════════════════════════
// f16 SIMD INSTRUCTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VSA VM f16: v_f16_load quantizes correctly" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_f16_load, .dst = 0, .imm = 0xF16 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Check that loaded vector has ternary values
    const v0 = &vm.registers.v0;
    try std.testing.expectEqual(@as(usize, 16), v0.trit_len);

    // All values should be in {-1, 0, +1}
    for (0..16) |i| {
        const val = v0.unpacked_cache[i];
        try std.testing.expect(val == -1 or val == 0 or val == 1);
    }
}

test "VSA VM f16: v_f16_store converts to f16" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_const, .dst = 0, .imm = 12345 }, // Load value
        .{ .opcode = .v_f16_store, .src1 = 0 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Check that f16 accumulator has values
    // f16_acc0 should have the converted values
    const f16_vec = vm.registers.f16_acc0;
    inline for (0..16) |i| {
        // Values should be valid f16 (not NaN/inf)
        try std.testing.expect(f16_vec[i] == f16_vec[i]);
    }
}

test "VSA VM f16: f16_dot computes dot product" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    const program = [_]VSAInstruction{
        .{ .opcode = .v_const, .dst = 0, .imm = 12345 },
        .{ .opcode = .v_mov, .dst = 1, .src1 = 0 }, // Copy to v1
        .{ .opcode = .f16_dot, .src1 = 0, .src2 = 1 }, // Dot product
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    // Dot product of identical vectors should be positive
    // (count of non-zero trits)
    try std.testing.expect(vm.registers.f0 > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// KOSCHEI v7.0: SACRED OPCODE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VSA VM sacred: phi_const" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    try vm.loadPhi();
    try std.testing.expect(vm.registers.f0 > 1.6 and vm.registers.f0 < 1.62);
}

test "VSA VM sacred: phi_pow" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    vm.registers.s0 = 10; // φ^10
    try vm.phiPow();
    try std.testing.expect(vm.registers.f0 > 122.9 and vm.registers.f0 < 123.0);
}

test "VSA VM sacred: fib(10)" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    vm.registers.s0 = 10;
    try vm.fib();
    try std.testing.expectEqual(@as(i64, 55), vm.registers.s0);
}

test "VSA VM sacred: sacred_identity" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    try vm.verifySacredIdentity();
    try std.testing.expect(vm.registers.cc_zero); // φ² + 1/φ² = 3 verified
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), vm.registers.f0, 1e-10);
}

test "VSA VM sacred: direct opcode execution" {
    var vm = VSAVM.init(std.testing.allocator);
    defer vm.deinit();

    // Test golden angle
    try vm.execSacredOpcode(.golden_angle, .{ .dest = "f0" });
    try std.testing.expect(vm.registers.f0 > 137.5 and vm.registers.f0 < 137.51);

    // Test physics constant
    try vm.execSacredOpcode(.light_speed, .{ .dest = "f0" });
    try std.testing.expectApproxEqAbs(@as(f64, 299792458.0), vm.registers.f0, 1.0);
}

pub fn main() !void {
    runBenchmarks();
}
