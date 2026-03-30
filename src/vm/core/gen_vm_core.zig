//! VM Core — Generated from specs/vm/core.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from core.tri spec
//! Modify spec and regenerate: tri vibee-gen vm_core

const std = @import("std");

/// ═════════════════════════════════════════════════════════════════════════════════════════════
/// CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════════════════════════
/// Default stack size in bytes
pub const DEFAULT_STACK_SIZE: u32 = 65536;

/// Maximum instructions before forced halt
pub const MAX_INSTRUCTIONS: u64 = 1000000;

/// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
/// VM STATE STRUCTURE
/// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
/// Common VM state structure
/// Shared base for all VM implementations
pub const VMState = struct {
    /// Program counter
    pc: u32 = 0,

    /// Instruction pointer (for stack-based VMs)
    ip: u32 = 0,

    /// Stack pointer (for stack-based VMs)
    sp: u32 = 0,

    /// Frame pointer (for register-based VMs)
    fp: u32 = 0,

    /// Halted flag
    halted: bool = false,

    /// Execution metrics
    instructions_executed: u64 = 0,

    /// Execution timing
    start_time: i128 = 0,
    end_time: i128 = 0,

    /// Reset execution state
    pub fn resetExecution(self: *VMState) void {
        self.pc = 0;
        self.ip = 0;
        self.sp = 0;
        self.fp = 0;
        self.halted = false;
        self.instructions_executed = 0;
        self.start_time = 0;
        self.end_time = 0;
    }

    /// Get execution time in nanoseconds
    pub fn getExecutionTimeNs(self: *const VMState) u64 {
        return @intCast(@max(0, self.end_time - self.start_time));
    }

    /// Get instructions per second
    pub fn getIPS(self: *const VMState) f64 {
        const time_ns = self.getExecutionTimeNs();
        if (time_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.instructions_executed)) / (@as(f64, @floatFromInt(time_ns)) / 1000000000.0);
    }

    /// Halt execution
    pub fn halt(self: *VMState) void {
        self.halted = true;
        self.end_time = std.time.nanoTimestamp();
    }

    /// Step execution (increment PC and instruction count)
    pub fn step(self: *VMState) void {
        if (!self.halted) {
            self.pc += 1;
            self.instructions_executed += 1;

            if (self.instructions_executed >= MAX_INSTRUCTIONS) {
                self.halt();
            }
        }
    }

    /// Check if VM can execute
    pub fn canExecute(self: *const VMState) bool {
        return !self.halted and self.instructions_executed < MAX_INSTRUCTIONS;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "VMState init defaults" {
    const vm_state = VMState{};
    try std.testing.expectEqual(@as(u32, 0), vm_state.pc);
    try std.testing.expectEqual(@as(u32, 0), vm_state.ip);
    try std.testing.expectEqual(@as(u32, 0), vm_state.sp);
    try std.testing.expectEqual(@as(u32, 0), vm_state.fp);
    try std.testing.expect(!vm_state.halted);
    try std.testing.expectEqual(@as(u64, 0), vm_state.instructions_executed);
}

test "VMState resetExecution" {
    var vm_state = VMState{
        .pc = 100,
        .ip = 200,
        .sp = 50,
        .fp = 10,
        .halted = true,
        .instructions_executed = 1000,
    };

    vm_state.resetExecution();

    try std.testing.expectEqual(@as(u32, 0), vm_state.pc);
    try std.testing.expectEqual(@as(u32, 0), vm_state.ip);
    try std.testing.expectEqual(@as(u32, 0), vm_state.sp);
    try std.testing.expectEqual(@as(u32, 0), vm_state.fp);
    try std.testing.expect(!vm_state.halted);
    try std.testing.expectEqual(@as(u64, 0), vm_state.instructions_executed);
}

test "VMState getExecutionTimeNs" {
    var vm_state = VMState{
        .start_time = 100,
        .end_time = 250,
    };
    try std.testing.expectEqual(@as(u64, 150), vm_state.getExecutionTimeNs());
}

test "VMState getIPS" {
    var vm_state = VMState{
        .instructions_executed = 1000,
        .start_time = 0,
        .end_time = 500_000_000, // 0.5 seconds
    };
    try std.testing.expectApproxEqAbs(@as(f64, 2000.0), vm_state.getIPS(), 0.1);
}

test "VMState halt" {
    var vm_state = VMState{};
    try std.testing.expect(!vm_state.halted);

    vm_state.halt();
    try std.testing.expect(vm_state.halted);
}

test "VMState step" {
    var vm_state = VMState{};
    try std.testing.expectEqual(@as(u32, 0), vm_state.pc);
    try std.testing.expectEqual(@as(u64, 0), vm_state.instructions_executed);

    vm_state.step();
    try std.testing.expectEqual(@as(u32, 1), vm_state.pc);
    try std.testing.expectEqual(@as(u64, 1), vm_state.instructions_executed);

    vm_state.step();
    try std.testing.expectEqual(@as(u32, 2), vm_state.pc);
    try std.testing.expectEqual(@as(u64, 2), vm_state.instructions_executed);
}

test "VMState canExecute" {
    var vm_state = VMState{};
    try std.testing.expect(vm_state.canExecute());

    vm_state.halted = true;
    try std.testing.expect(!vm_state.canExecute());
}

test "DEFAULT_STACK_SIZE constant" {
    try std.testing.expectEqual(@as(u32, 65536), DEFAULT_STACK_SIZE);
}

test "MAX_INSTRUCTIONS constant" {
    try std.testing.expectEqual(@as(u64, 1000000), MAX_INSTRUCTIONS);
}
