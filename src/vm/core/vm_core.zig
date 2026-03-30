// ═════════════════════════════════════════════════════════════════════════════
// VM CORE - Common Virtual Machine State
// ═══════════════════════════════════════════════════════════════════════════════
// Shared VM state structure for all Trinity virtual machines
// Reduces duplication between VSAVM, NanVM, RegVM, TVCVM, TRI-27
// ═════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Common VM state structure
/// Shared base for all VM implementations
pub const VMState = struct {
    // Program counter
    pc: u32 = 0,

    // Instruction pointer (for stack-based VMs)
    ip: u32 = 0,

    // Stack pointer (for stack-based VMs)
    sp: u32 = 0,

    // Frame pointer (for register-based VMs)
    fp: u32 = 0,

    // Halted flag
    halted: bool = false,

    // Allocator for dynamic memory
    allocator: std.mem.Allocator,

    // Execution metrics
    instructions_executed: u64 = 0,
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
        return @as(f64, @floatFromInt(self.instructions_executed)) / (@as(f64, @floatFromInt(time_ns)) / 1_000_000_000.0);
    }
};

test "VMState init defaults" {
    const vm_state = VMState{
        .allocator = std.testing.allocator,
    };
    try std.testing.expectEqual(@as(u32, 0), vm_state.pc);
    try std.testing.expectEqual(@as(u32, 0), vm_state.ip);
    try std.testing.expectEqual(@as(u32, 0), vm_state.sp);
    try std.testing.expectEqual(@as(u32, 0), vm_state.fp);
    try std.testing.expect(!vm_state.halted);
    try std.testing.expectEqual(@as(u64, 0), vm_state.instructions_executed);
}

test "VMState resetExecution" {
    var vm_state = VMState{
        .allocator = std.testing.allocator,
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
        .allocator = std.testing.allocator,
        .start_time = 100,
        .end_time = 250,
    };
    try std.testing.expectEqual(@as(u64, 150), vm_state.getExecutionTimeNs());
}

test "VMState getIPS" {
    var vm_state = VMState{
        .allocator = std.testing.allocator,
        .start_time = 0,
        .end_time = 1_000_000_000, // 1 second
        .instructions_executed = 1000,
    };
    const ips = vm_state.getIPS();
    try std.testing.expectApproxEqAbs(1000.0, ips, 0.01);
}
