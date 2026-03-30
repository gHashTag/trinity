// ═══════════════════════════════════════════════════════════════════════════════
// VM DISPATCH - Generic Dispatch Loop Template
// ═══════════════════════════════════════════════════════════════════════════════════════
// Shared dispatch pattern for all Trinity VMs
// Supports fast-path optimization and extensible opcode handling
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Dispatch configuration
pub const DispatchConfig = struct {
    /// Enable fast-path inlining for common opcodes
    enable_fast_path: bool = true,

    /// Maximum instructions before forced halt (for testing)
    max_instructions: ?u64 = null,

    /// Enable tracing
    enable_tracing: bool = false,

    /// Trace callback (function pointer)
    trace_fn: ?*const fn (opcode: u8, ip: u32) void = null,
};

/// Dispatch statistics
pub const DispatchStats = struct {
    total_opcodes: u64 = 0,
    fast_path_hits: u64 = 0,
    slow_path_hits: u64 = 0,
    branches_taken: u64 = 0,
    branches_not_taken: u64 = 0,

    /// Get fast-path hit rate
    pub fn getFastPathRate(self: *const DispatchStats) f64 {
        if (self.total_opcodes == 0) return 0;
        return @as(f64, @floatFromInt(self.fast_path_hits)) /
            @as(f64, @floatFromInt(self.total_opcodes));
    }

    /// Reset statistics
    pub fn reset(self: *DispatchStats) void {
        self.* = .{};
    }
};

/// Generic dispatch loop template
/// Type-erased dispatch for any VM type with:
/// - pc: u32 (program counter)
/// - ip: u32 (instruction pointer)
/// - halted: bool
/// - code: []const u8
/// - instructions_executed: u64
pub fn dispatchLoop(
    comptime VMType: type,
    vm: *VMType,
    config: DispatchConfig,
    executeFn: anytype,
) !void {
    var stats = DispatchStats{};

    // Main dispatch loop
    while (!vm.halted and vm.ip < vm.code.len) {
        const op = vm.code[vm.ip];
        vm.ip += 1;

        // Trace if enabled
        if (config.enable_tracing) {
            if (config.trace_fn) |trace_fn| {
                trace_fn(op, vm.ip - 1);
            }
        }

        // Check max instruction limit
        if (config.max_instructions) |limit| {
            if (vm.instructions_executed >= limit) break;
        }

        // Execute opcode
        executeFn(vm, op, &stats);
        vm.instructions_executed += 1;
        stats.total_opcodes += 1;
    }

    // Store statistics back to VM if needed
    // (VM can add stats field for this)
    _ = &stats;
}

/// Optimized dispatch for register-based VMs
/// Specialized template for RegVM-like architectures
pub fn registerDispatchLoop(
    comptime VMType: type,
    vm: *VMType,
    config: DispatchConfig,
    executeFn: anytype,
) !void {
    var stats = DispatchStats{};

    // Register-optimized dispatch
    while (!vm.halted and vm.ip < vm.code.len) {
        const op = vm.code[vm.ip];
        vm.ip += 1;

        if (config.enable_tracing) {
            if (config.trace_fn) |trace_fn| {
                trace_fn(op, vm.ip - 1);
            }
        }

        if (config.max_instructions) |limit| {
            if (vm.instructions_executed >= limit) break;
        }

        executeFn(vm, op, &stats);
        vm.instructions_executed += 1;
        stats.total_opcodes += 1;
    }

    _ = stats;
}

/// Stack-based dispatch template
/// Specialized for NanVM-like stack machines
pub fn stackDispatchLoop(
    comptime VMType: type,
    vm: *VMType,
    config: DispatchConfig,
    executeFn: anytype,
) !void {
    const pc_offset = @offsetOf(VMType, "pc");
    const sp_offset = @offsetOf(VMType, "sp");
    const halted_offset = @offsetOf(VMType, "halted");
    const code_offset = @offsetOf(VMType, "code");
    const exec_offset = @offsetOf(VMType, "instructions_executed");

    const pc_ptr: *u32 = @ptrCast(@as([*]u8, @intFromPtr(vm)) + pc_offset);
    const sp_ptr: *u32 = @ptrCast(@as([*]u8, @intFromPtr(vm)) + sp_offset);
    const halted_ptr: *bool = @ptrCast(@as([*]u8, @intFromPtr(vm)) + halted_offset);
    const code_ptr: *const []const u8 = @ptrCast(@as([*]u8, @intFromPtr(vm)) + code_offset);
    const exec_ptr: *u64 = @ptrCast(@as([*]u8, @intFromPtr(vm)) + exec_offset);

    var stats = DispatchStats{};

    while (!halted_ptr.* and pc_ptr.* < code_ptr.*.len) {
        const op = code_ptr.*[pc_ptr.*];
        pc_ptr.* += 1;

        if (config.enable_tracing) {
            if (config.trace_fn) |trace_fn| {
                trace_fn(op, pc_ptr.* - 1);
            }
        }

        if (config.max_instructions) |limit| {
            if (exec_ptr.* >= limit) break;
        }

        executeFn(vm, op, &stats);
        exec_ptr.* += 1;
        stats.total_opcodes += 1;
    }

    _ = stats;
}

// ═════════════════════════════════════════════════════════════════════════════════════
// FAST PATH HELPERS
// ═════════════════════════════════════════════════════════════════════════════════════════════

/// Check if opcode is a jump/branch instruction
/// Used for branch prediction hints
pub fn isBranchOpcode(opcode: u8) bool {
    return switch (opcode) {
        0x40...0x44 => true, // JMP, JZ, JNZ, JLT, JLE, JGT, JGE
        else => false,
    };
}

/// Get opcode name for debugging
pub fn getOpcodeName(opcode: u8) []const u8 {
    return switch (opcode) {
        0x00 => "NOP",
        0x01 => "MOV_RR",
        0x02 => "MOV_RI",
        0x03 => "LOAD_CONST",
        0x04 => "LOAD_LOCAL",
        0x05 => "STORE_LOCAL",
        0x10 => "ADD",
        0x11 => "SUB",
        0x12 => "MUL",
        0x13 => "DIV",
        0x14 => "INC",
        0x1E => "INC_R",
        0x1F => "DEC_R",
        0x20...0x29 => "CMP_***",
        0x40 => "JMP",
        0x41 => "JZ",
        0x42 => "JNZ",
        0x43 => "JLT",
        0x44 => "JLE",
        0x4B => "RET",
        0x4D => "HALT",
        0x4E => "CALL_NATIVE",
        0x49 => "CALL",
        0x50 => "LOAD_LOCAL",
        0x51 => "STORE_LOCAL",
        0x80...0xFF => "SACRED_*",
        0xA0 => "INC_CMP_JLT",
        0x90...0x92 => "LOAD_PHI/PI/E",
        else => "UNKNOWN",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "DispatchStats init" {
    const stats = DispatchStats{};
    try std.testing.expectEqual(@as(u64, 0), stats.total_opcodes);
    try std.testing.expectEqual(@as(u64, 0), stats.fast_path_hits);
    try std.testing.expectEqual(@as(u64, 0), stats.slow_path_hits);
}

test "DispatchStats getFastPathRate" {
    var stats = DispatchStats{ .total_opcodes = 100, .fast_path_hits = 75 };
    const rate = stats.getFastPathRate();
    try std.testing.expectApproxEqAbs(0.75, rate, 0.01);
}

test "DispatchStats reset" {
    var stats = DispatchStats{ .total_opcodes = 100, .fast_path_hits = 75 };
    stats.reset();
    try std.testing.expectEqual(@as(u64, 0), stats.total_opcodes);
    try std.testing.expectEqual(@as(u64, 0), stats.fast_path_hits);
}

test "isBranchOpcode" {
    try std.testing.expect(isBranchOpcode(0x40)); // JMP
    try std.testing.expect(isBranchOpcode(0x41)); // JZ
    try std.testing.expect(isBranchOpcode(0x42)); // JNZ
    try std.testing.expect(!isBranchOpcode(0x10)); // ADD
    try std.testing.expect(!isBranchOpcode(0x4D)); // HALT
}

test "getOpcodeName" {
    try std.testing.expectEqualStrings("NOP", getOpcodeName(0x00));
    try std.testing.expectEqualStrings("MOV_RR", getOpcodeName(0x01));
    try std.testing.expectEqualStrings("ADD", getOpcodeName(0x10));
    try std.testing.expectEqualStrings("HALT", getOpcodeName(0x4D));
    try std.testing.expectEqualStrings("UNKNOWN", getOpcodeName(0xFF));
}
