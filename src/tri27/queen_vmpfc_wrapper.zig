// @origin(manual) @regen(manual-impl)
// QUEEN VMPFC WRAPPER — ROI (Return On Investment) Scoring
//
// Shell wrapper for queen_vmpfc.t27 TRI-27 module.
// Loads and executes the assembly program for computing
// ROI score based on cost, reward, and confidence.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const emu = @import("emu");
const CPUState = emu.cpu_state.CPUState;
const executor = emu.executor;
const decoder = emu.decoder;
const asm_parser = emu.asm_parser;

/// ROI decision classification
pub const DecisionClass = enum(u2) {
    average = 0,
    terrible = 1,
    good = 2,
    excellent = 3,
};

/// Queen VMPFC program wrapper
pub const QueenVMPFC = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) QueenVMPFC {
        return .{ .allocator = allocator };
    }

    /// Load queen_vmpfc.t27 from source file
    pub fn loadFromFile(self: *const QueenVMPFC, path: []const u8) ![]u8 {
        const source = try std.fs.cwd().readFileAlloc(self.allocator, path, 10240);
        defer self.allocator.free(source);
        return self.assembleSource(source);
    }

    /// Assemble TRI-27 source code to bytecode
    fn assembleSource(self: *const QueenVMPFC, source: []const u8) ![]u8 {
        return asm_parser.assemble(self.allocator, source);
    }

    /// Execute queen_vmpfc program with given cost, reward, confidence
    /// Returns decision classification
    pub fn execute(self: *const QueenVMPFC, bytecode: []const u8, reward: f64, cost: f64, confidence: f64) !DecisionClass {
        var cpu = try CPUState.init(self.allocator);
        defer cpu.deinit();

        // Allocate memory (4KB, 8-byte aligned)
        var memory_stack: [4096]u8 align(8) = undefined;
        @memset(&memory_stack, 0);
        var memory = memory_stack[0..];

        // Write reward (Q16) at MEM_REWARD (offset 0)
        const reward_q16 = @as(u16, @intFromFloat(@max(0, @min(1.0, reward)) * 65536.0));
        memory[0] = @as(u8, @truncate(reward_q16));
        memory[1] = @as(u8, @truncate(reward_q16 >> 8));

        // Write cost (Q16) at MEM_COST (offset 4)
        const cost_q16 = @as(u16, @intFromFloat(@max(0, @min(1.0, cost)) * 65536.0));
        memory[4] = @as(u8, @truncate(cost_q16));
        memory[5] = @as(u8, @truncate(cost_q16 >> 8));

        // Write confidence (Q16) at MEM_CONFIDENCE (offset 8)
        const conf_q16 = @as(u16, @intFromFloat(@max(0, @min(1.0, confidence)) * 65536.0));
        memory[8] = @as(u8, @truncate(conf_q16));
        memory[9] = @as(u8, @truncate(conf_q16 >> 8));

        // Initialize ROI history (all 0)
        const mem_history = 12;
        @memset(memory[mem_history..][0..16], 0); // 8× 16-bit = 16 bytes

        // Load bytecode into instruction memory
        for (bytecode, 0..) |byte, i| {
            if (i < memory.len) {
                memory[i] = byte;
            }
        }

        cpu.pc = 0;

        // Execute until HALT
        while (true) {
            if (cpu.flags.H) break;

            const mem_offset = cpu.pc * 4;
            if (mem_offset + 4 > memory.len) return error.InvalidMemory;

            const word: u32 = memory[mem_offset] |
                @as(u32, memory[mem_offset + 1]) << 8 |
                @as(u32, memory[mem_offset + 2]) << 16 |
                @as(u32, memory[mem_offset + 3]) << 24;

            const inst = decoder.decode(word);
            executor.execute(&cpu, inst, memory) catch |err| {
                if (err == executor.ExecError.Halted) break;
                return err;
            };
        }

        // Return classification from t0
        const result_raw = cpu.t27[0].trits;
        const class_val = @as(u2, @truncate(@as(u64, @bitCast(result_raw)) & 0x3));
        return @as(DecisionClass, @enumFromInt(class_val));
    }

    /// Convenience function: score action ROI
    pub fn scoreROI(self: *const QueenVMPFC, reward: f64, cost: f64, confidence: f64, source: []const u8) !DecisionClass {
        const bytecode = try self.assembleSource(source);
        defer self.allocator.free(bytecode);

        return try self.execute(bytecode, reward, cost, confidence);
    }

    /// Get decision class name
    pub fn className(class: DecisionClass) []const u8 {
        return switch (class) {
            .average => "AVERAGE",
            .terrible => "TERRIBLE",
            .good => "GOOD",
            .excellent => "EXCELLENT",
        };
    }

    /// Get numeric ROI threshold for class
    pub fn classThreshold(class: DecisionClass) f64 {
        return switch (class) {
            .excellent => 0.5,
            .good => 0.25,
            .average => 0.0,
            .terrible => -0.25,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_vmpfc_wrapper init" {
    const allocator = std.testing.allocator;
    const wrapper = QueenVMPFC.init(allocator);
    try std.testing.expectEqual(@as(Allocator, allocator), wrapper.allocator);
}

test "queen_vmpfc_wrapper class_names" {
    try std.testing.expectEqualStrings("AVERAGE", QueenVMPFC.className(.average));
    try std.testing.expectEqualStrings("TERRIBLE", QueenVMPFC.className(.terrible));
    try std.testing.expectEqualStrings("GOOD", QueenVMPFC.className(.good));
    try std.testing.expectEqualStrings("EXCELLENT", QueenVMPFC.className(.excellent));
}

test "queen_vmpfc_wrapper thresholds" {
    try std.testing.expectApproxEqRel(0.5, QueenVMPFC.classThreshold(.excellent), 0.01);
    try std.testing.expectApproxEqRel(0.25, QueenVMPFC.classThreshold(.good), 0.01);
    try std.testing.expectApproxEqRel(0.0, QueenVMPFC.classThreshold(.average), 0.01);
    try std.testing.expectApproxEqRel(-0.25, QueenVMPFC.classThreshold(.terrible), 0.01);
}

test "queen_vmpfc_wrapper execute" {
    const allocator = std.testing.allocator;
    var wrapper = QueenVMPFC.init(allocator);

    // Simple program: load and halt (just verify execution works)
    const source = "LDI t0, 0\nHALT";
    const bytecode = try wrapper.assembleSource(source);
    defer allocator.free(bytecode);

    // Just verify it doesn't crash - the actual classification
    // depends on the full program logic
    const decision = try wrapper.execute(bytecode, 0.8, 0.3, 0.9);
    // With LDI t0, 0, we expect AVERAGE (0)
    try std.testing.expectEqual(DecisionClass.average, decision);
}
