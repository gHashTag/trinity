// Reticular Raphe Shell Wrapper — TRI-27 VM Interface
// DOGFOOD-1: Zig becomes transport layer for TRI-27 bytecode
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

// TRI-27 VM components
const CPUState = @import("../tri-lang/emu/cpu_state.zig").CPUState;
const executor = @import("../tri-lang/emu/executor.zig");
const Assembler = @import("../tri-lang/emu/asm_parser.zig").Assembler;

// Embedded .t27 assembly source
const t27_source = @embedFile("reticular_raphe.t27");

/// PPL Spike Analysis Result
pub const SpikeAnalysis = struct {
    is_spike: bool = false,
    is_regression: bool = false,
    recommendation: Recommendation = .wait,
    confidence: f32 = 0.0,
    rolling_ppl: f32 = 0.0,
};

pub const Recommendation = enum {
    ignore,
    wait,
    alert,
};

/// Run reticular raphe PPL spike analysis via TRI-27 VM
///
/// Parameters:
///   - allocator: Memory allocator for bytecode
///   - evaluations: Array of PPL values (Q16 fixed-point, scaled by 65536)
///
/// Returns: SpikeAnalysis with rolling PPL and recommendation
pub fn smoothPPLSpikes(
    allocator: Allocator,
    evaluations: []const i32,
) !SpikeAnalysis {
    // 1. Assemble .t27 source to .tbin bytecode
    const bytecode = try Assembler.assemble(allocator, t27_source);
    defer allocator.free(bytecode);

    // 2. Initialize VM
    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    // 3. Load bytecode into VM memory
    const mem = cpu.getBytesMut();
    if (bytecode.len > mem.len) return error.BytecodeTooLarge;
    @memcpy(mem[0..bytecode.len], bytecode);

    // 4. Set input: write evaluations to memory at MEM_EVALUATIONS (offset 16)
    const MEM_EVALUATIONS = 16;
    const max_evals = @min(evaluations.len, 20); // WINDOW_SIZE = 20

    for (0..max_evals) |i| {
        const addr = MEM_EVALUATIONS + i * 4; // 4 bytes per evaluation (32-bit)
        if (addr + 4 > mem.len) break;

        // Write evaluation value (little-endian)
        const eval = evaluations[i];
        mem[addr] = @as(u8, @intCast(eval & 0xFF));
        mem[addr + 1] = @as(u8, @intCast((eval >> 8) & 0xFF));
        mem[addr + 2] = @as(u8, @intCast((eval >> 16) & 0xFF));
        mem[addr + 3] = @as(u8, @intCast((eval >> 24) & 0xFF));
    }

    // 5. Execute until HALT
    try executor.run(&cpu, mem);

    // 6. Read output: t0 = rolling PPL (Q16 fixed-point)
    const rolling_ppl_q16 = @as(i32, @bitCast(@as(u32, @intCast(cpu.t27[0].trits))));
    const rolling_ppl = @as(f32, @floatFromInt(rolling_ppl_q16)) / 65536.0;

    // 7. Determine recommendation based on rolling PPL
    // Using simple thresholds (can be made more sophisticated)
    const analysis = SpikeAnalysis{
        .rolling_ppl = rolling_ppl,
        .is_spike = rolling_ppl > 5.0, // Threshold for spike
        .is_regression = rolling_ppl > 10.0, // Threshold for regression
        .recommendation = if (rolling_ppl > 10.0) .alert else if (rolling_ppl > 5.0) .wait else .ignore,
        .confidence = if (rolling_ppl > 10.0) 0.9 else if (rolling_ppl > 5.0) 0.6 else 0.3,
    };

    return analysis;
}

/// Calculate moving average (Zig fallback, no VM)
pub fn movingAverage(window: []const f32) f32 {
    if (window.len == 0) return 0.0;
    var sum: f32 = 0.0;
    for (window) |v| sum += v;
    return sum / @as(f32, @floatFromInt(window.len));
}

/// φ²-based patience cycles (constant, from φ² ≈ 2.618)
pub fn phiPatienceCycles() u32 {
    return 2; // floor(φ²) = floor(2.618) = 2
}

// Simple test
test "reticular raphe shell wrapper" {
    const allocator = std.testing.allocator;

    // Sample PPL evaluations (Q16: value * 65536)
    const evaluations = [_]i32{
        4.5 * 65536,
        4.6 * 65536,
        4.7 * 65536,
        5.2 * 65536, // Spike
        4.8 * 65536,
    };

    const result = try smoothPPLSpikes(allocator, &evaluations);
    try std.testing.expect(result.rolling_ppl > 0);
}
