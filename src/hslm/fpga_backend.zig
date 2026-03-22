// @origin(spec:fpga_backend.tri) @regen(manual-impl)
// FPGA BACKEND — Unified Interface for FPGA ALU Operations
//
// Phase 5: Trinity Integration (Bridge between Zig and Sacred ALU)
//
// Provides transparent switching between hardware (FPGA) and software fallback.
// Software mode uses reference implementations from intraparietal_sulcus.zig.
// Hardware mode stub (JTAG/memory-mapped access to be implemented).
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const intraparietal_sulcus = @import("intraparietal_sulcus.zig");

// ═══════════════════════════════════════════════════════════════════════
// BACKEND MODE — Hardware or Software fallback
// ═════════════════════════════════════════════════════════════════════

pub const Backend = enum {
    /// Hardware mode: FPGA ALU via JTAG/memory-mapped access
    hardware,
    /// Software mode: CPU fallback using reference implementations
    software,
};

// ═════════════════════════════════════════════════════════════════════
// SACRED ALU MODES — Matches sacred_alu.v encoding
// ═════════════════════════════════════════════════════════════════════

/// Mode bits for sacred_alu.v (2-bit encoding)
pub const AluMode = enum(u2) {
    /// GF16 Addition (mode 00)
    gf16_add = 0b00,
    /// GF16 Multiplication (mode 01)
    gf16_mul = 0b01,
    /// Ternary Float Addition (mode 10)
    tf3_add = 0b10,
    /// Ternary Float Dot Product (mode 11)
    tf3_dot = 0b11,
};

// ═══════════════════════════════════════════════════════════════════════
// FPGA ALU — Unified backend interface
// ═════════════════════════════════════════════════════════════════════════

pub const FpgaAlu = struct {
    mode: Backend,

    /// Initialize FPGA ALU with automatic backend detection.
    /// Attempts hardware detection, falls back to software if unavailable.
    pub fn init(allocator: std.mem.Allocator) !FpgaAlu {
        _ = allocator;

        // TODO: Implement FPGA detection (JTAG cable check, device ID read)
        // For now, default to software mode
        return FpgaAlu{ .mode = .software };
    }

    /// Check if FPGA hardware is available.
    pub fn isHardwareAvailable(self: *const FpgaAlu) bool {
        return self.mode == .hardware;
    }

    /// Switch to hardware mode (requires FPGA connection).
    pub fn enableHardware(self: *FpgaAlu) !void {
        // TODO: Verify FPGA connection before switching
        self.mode = .hardware;
    }

    /// Switch to software fallback mode.
    pub fn enableSoftware(self: *FpgaAlu) void {
        // Switch to software mode (no-op if already software)
        self.mode = .software;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GF16 OPERATIONS — 16-bit operations on Golden Float 16 format
    // ═════════════════════════════════════════════════════════════════════════════

    /// GF16 Addition: a + b
    /// Returns GoldenFloat16 packed as u16.
    /// Hardware: sacred_alu.v mode 00, cycles = 4 (4-stage pipeline)
    /// Software: f32 addition → gf16 conversion
    pub fn gf16Add(self: *const FpgaAlu, a: u16, b: u16) u16 {
        return switch (self.mode) {
            .hardware => {
                @panic("FPGA hardware mode not yet implemented — use JTAG/memory-mapped access");
            },
            .software => {
                // Software fallback: f32 addition, then convert to GF16
                const a_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(a));
                const b_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(b));

                const a_f32 = intraparietal_sulcus.gf16ToF32(a_gf16);
                const b_f32 = intraparietal_sulcus.gf16ToF32(b_gf16);
                const sum_f32 = a_f32 + b_f32;

                const sum_gf16 = intraparietal_sulcus.gf16FromF32(sum_f32);
                return @bitCast(sum_gf16);
            },
        };
    }

    /// GF16 Multiplication: a × b
    /// Returns GoldenFloat16 packed as u16.
    /// Hardware: sacred_alu.v mode 01, cycles = 1 (DSP48E1 single-cycle)
    /// Software: f32 multiplication → gf16 conversion
    pub fn gf16Mul(self: *const FpgaAlu, a: u16, b: u16) u16 {
        return switch (self.mode) {
            .hardware => {
                @panic("FPGA hardware mode not yet implemented — use JTAG/memory-mapped access");
            },
            .software => {
                // Software fallback: f32 multiplication, then convert to GF16
                const a_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(a));
                const b_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(b));

                const a_f32 = intraparietal_sulcus.gf16ToF32(a_gf16);
                const b_f32 = intraparietal_sulcus.gf16ToF32(b_gf16);
                const prod_f32 = a_f32 * b_f32;

                const prod_gf16 = intraparietal_sulcus.gf16FromF32(prod_f32);
                return @bitCast(prod_gf16);
            },
        };
    }

    // ═══════════════════════════════════════════════════════════════════
    // TF3 OPERATIONS — Ternary Float operations (-1, 0, +1)
    // ═════════════════════════════════════════════════════════════════════════

    /// Ternary Float Addition: a + b (saturating to {-1, 0, +1})
    /// Returns trit value encoded as u2 (00=0, 01=-1, 10=+1).
    /// Hardware: sacred_alu.v mode 10, single cycle saturating adder
    /// Software: integer addition with clamp to ternary
    pub fn tf3Add(self: *const FpgaAlu, a: u2, b: u2) u2 {
        return switch (self.mode) {
            .hardware => {
                @panic("FPGA hardware mode not yet implemented — use JTAG/memory-mapped access");
            },
            .software => {
                // Software fallback: decode trits, add with saturation
                const a_trit = decodeTrit(a);
                const b_trit = decodeTrit(b);
                const sum: i8 = @as(i8, a_trit) + @as(i8, b_trit);

                // Saturate to {-1, 0, +1}
                const sat_sum = std.math.clamp(sum, -1, 1);
                const sat_i2: i2 = @intCast(sat_sum);
                return encodeTrit(sat_i2);
            },
        };
    }

    /// Ternary Float Dot Product: Σ(a_i × b_i)
    /// Returns accumulated result as i32.
    /// Hardware: sacred_alu.v mode 11, accumulates via TF3 multiplier
    /// Software: integer accumulation with ternary product
    pub fn tf3Dot(self: *const FpgaAlu, a: []const u2, b: []const u2) i32 {
        std.debug.assert(a.len == b.len);

        return switch (self.mode) {
            .hardware => {
                @panic("FPGA hardware mode not yet implemented — use JTAG/memory-mapped access");
            },
            .software => {
                // Software fallback: integer dot product
                var acc: i32 = 0;
                for (0..a.len) |i| {
                    const a_trit = decodeTrit(a[i]);
                    const b_trit = decodeTrit(b[i]);
                    const prod: i8 = @as(i8, a_trit) * @as(i8, b_trit);
                    acc += @as(i32, prod);
                }
                return acc;
            },
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIRECT FPGA HARDWARE ACCESS — Mode-specific operations
    // ═════════════════════════════════════════════════════════════════════════════

    /// Direct GF16 addition via sacred_alu.v mode 00
    /// Hardware: 4-cycle pipeline, returns result in u16 GF16 format
    /// Software: software fallback via gf16Add
    pub fn gf16AddDirect(self: *const FpgaAlu, a: u16, b: u16) u16 {
        // TODO: Hardware path - write mode 00 to ALU, read result
        // Software path - reuse existing gf16Add
        return self.gf16Add(a, b);
    }

    /// Direct GF16 multiplication via sacred_alu.v mode 01
    /// Hardware: DSP48E1 single-cycle, returns result in u16 GF16 format
    /// Software: software fallback via gf16Mul
    pub fn gf16MulDirect(self: *const FpgaAlu, a: u16, b: u16) u16 {
        // TODO: Hardware path - write mode 01 to ALU, read result
        // Software path - reuse existing gf16Mul
        return self.gf16Mul(a, b);
    }

    /// Direct ternary addition via sacred_alu.v mode 10
    /// Hardware: single-cycle saturating adder
    /// Software: software fallback via tf3Add
    pub fn tf3AddDirect(self: *const FpgaAlu, a: u2, b: u2) u2 {
        // TODO: Hardware path - write mode 10 to ALU, read result
        // Software path - reuse existing tf3Add
        return self.tf3Add(a, b);
    }

    /// Batch ternary dot product via sacred_alu.v mode 11
    /// Hardware: accumulator in ALU, returns accumulated sum
    /// Software: sequential dot product via tf3Dot
    pub fn tf3DotBatch(self: *const FpgaAlu, a: []const u2, b: []const u2) i32 {
        // TODO: Hardware path - write mode 11, feed pairs to ALU
        // Software path - reuse existing tf3Dot
        return self.tf3Dot(a, b);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TRIT ENCODING — 2-bit encoding for {-1, 0, +1}
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Decode 2-bit trit to i8: 00=0, 01=-1, 10=+1
    pub fn decodeTrit(code: u2) i8 {
        return switch (code) {
            0b00 => 0,
            0b01 => -1,
            0b10 => 1,
            else => 0, // Invalid, treat as 0
        };
    }

    /// Encode i8 trit to 2-bit: -1=01, 0=00, +1=10
    pub fn encodeTrit(val: i2) u2 {
        return switch (val) {
            -1 => 0b01,
            0 => 0b00,
            1 => 0b10,
            else => 0b00, // Invalid, treat as 0
        };
    }

    /// Get backend mode name (for debugging/logging).
    pub fn modeName(self: *const FpgaAlu) []const u8 {
        return switch (self.mode) {
            .hardware => "FPGA Hardware",
            .software => "Software Fallback",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "FpgaAlu init defaults to software" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    try std.testing.expectEqual(.software, alu.mode);
    try std.testing.expect(!alu.isHardwareAvailable());
}

test "FpgaAlu enable hardware" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    try alu.enableHardware();
    try std.testing.expectEqual(.hardware, alu.mode);
    try std.testing.expect(alu.isHardwareAvailable());
}

test "FpgaAlu enable software" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    _ = alu.enableHardware() catch {};
    alu.enableSoftware();
    try std.testing.expectEqual(.software, alu.mode);
    try std.testing.expect(!alu.isHardwareAvailable());
}

test "gf16Add software basic" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: 1.0 + 2.0 = 3.0
    const one = intraparietal_sulcus.gf16FromF32(1.0);
    const two = intraparietal_sulcus.gf16FromF32(2.0);
    const result_raw = alu.gf16Add(@bitCast(one), @bitCast(two));
    const result_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(result_raw));
    const result_f32 = intraparietal_sulcus.gf16ToF32(result_gf16);

    try std.testing.expectApproxEqAbs(3.0, result_f32, 0.01);
}

test "gf16Add software negative" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: -1.5 + 0.5 = -1.0
    const neg = intraparietal_sulcus.gf16FromF32(-1.5);
    const pos = intraparietal_sulcus.gf16FromF32(0.5);
    const result_raw = alu.gf16Add(@bitCast(neg), @bitCast(pos));
    const result_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(result_raw));
    const result_f32 = intraparietal_sulcus.gf16ToF32(result_gf16);

    try std.testing.expectApproxEqAbs(-1.0, result_f32, 0.01);
}

test "gf16Mul software basic" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: 3.0 × 4.0 = 12.0
    const three = intraparietal_sulcus.gf16FromF32(3.0);
    const four = intraparietal_sulcus.gf16FromF32(4.0);
    const result_raw = alu.gf16Mul(@bitCast(three), @bitCast(four));
    const result_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(result_raw));
    const result_f32 = intraparietal_sulcus.gf16ToF32(result_gf16);

    try std.testing.expectApproxEqAbs(12.0, result_f32, 0.05);
}

test "gf16Mul software zero" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: 0.0 × 5.0 = 0.0
    const zero = intraparietal_sulcus.gf16FromF32(0.0);
    const five = intraparietal_sulcus.gf16FromF32(5.0);
    const result_raw = alu.gf16Mul(@bitCast(zero), @bitCast(five));
    const result_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(result_raw));
    const result_f32 = intraparietal_sulcus.gf16ToF32(result_gf16);

    try std.testing.expectApproxEqAbs(0.0, result_f32, 0.01);
}

test "tf3Add software basic" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: +1 + -1 = 0
    const pos = FpgaAlu.encodeTrit(1);
    const neg = FpgaAlu.encodeTrit(-1);
    const result = alu.tf3Add(pos, neg);

    try std.testing.expectEqual(@as(u2, 0b00), result); // 0
}

test "tf3Add software saturating" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: +1 + +1 should saturate to +1
    const pos = FpgaAlu.encodeTrit(1);
    const result = alu.tf3Add(pos, pos);

    try std.testing.expectEqual(@as(u2, 0b10), result); // +1
}

test "tf3Add software underflow" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: -1 + -1 should saturate to -1
    const neg = FpgaAlu.encodeTrit(-1);
    const result = alu.tf3Add(neg, neg);

    try std.testing.expectEqual(@as(u2, 0b01), result); // -1
}

test "tf3Dot software basic" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: [1, -1, 0] · [1, 1, -1] = 1 + -1 + 0 = 0
    const a = [_]u2{ FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(-1), FpgaAlu.encodeTrit(0) };
    const b = [_]u2{ FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(-1) };

    const result = alu.tf3Dot(&a, &b);

    try std.testing.expectEqual(@as(i32, 0), result);
}

test "tf3Dot software identity" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: [1, 0, -1] · [1, 0, -1] = 1 + 0 + 1 = 2
    const a = [_]u2{ FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(0), FpgaAlu.encodeTrit(-1) };
    const b = [_]u2{ FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(0), FpgaAlu.encodeTrit(-1) };

    const result = alu.tf3Dot(&a, &b);

    try std.testing.expectEqual(@as(i32, 2), result);
}

test "trit encode decode roundtrip" {
    // Test all valid trit values
    for ([_]i2{ -1, 0, 1 }) |val| {
        const encoded = FpgaAlu.encodeTrit(val);
        const decoded = FpgaAlu.decodeTrit(encoded);
        try std.testing.expectEqual(val, decoded);
    }
}

test "modeName returns correct string" {
    var alu = try FpgaAlu.init(std.testing.allocator);

    const sw_name = alu.modeName();
    try std.testing.expectEqualStrings("Software Fallback", sw_name);

    try alu.enableHardware();
    const hw_name = alu.modeName();
    try std.testing.expectEqualStrings("FPGA Hardware", hw_name);
}

test "gf16AddDirect software fallback" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    const a = intraparietal_sulcus.gf16FromF32(1.5);
    const b = intraparietal_sulcus.gf16FromF32(2.5);
    const result_raw = alu.gf16AddDirect(@bitCast(a), @bitCast(b));
    const result_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(result_raw));
    const result_f32 = intraparietal_sulcus.gf16ToF32(result_gf16);

    // Verify matches gf16Add behavior (should be ~4.0)
    try std.testing.expectApproxEqAbs(4.0, result_f32, 0.01);
}

test "gf16MulDirect software fallback" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    const a = intraparietal_sulcus.gf16FromF32(3.0);
    const b = intraparietal_sulcus.gf16FromF32(4.0);
    const result_raw = alu.gf16MulDirect(@bitCast(a), @bitCast(b));
    const result_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(result_raw));
    const result_f32 = intraparietal_sulcus.gf16ToF32(result_gf16);

    // Verify matches gf16Mul behavior (should be ~12.0)
    try std.testing.expectApproxEqAbs(12.0, result_f32, 0.05);
}

test "tf3AddDirect software fallback" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    const pos = FpgaAlu.encodeTrit(1);
    const neg = FpgaAlu.encodeTrit(-1);
    const result = alu.tf3AddDirect(pos, neg);

    try std.testing.expectEqual(@as(u2, 0b00), result); // 0
}

test "tf3DotBatch software fallback" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test: [1, -1, 0] · [1, 1, -1] = 1 + -1 + 0 = 0
    const a = [_]u2{ FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(-1), FpgaAlu.encodeTrit(0) };
    const b = [_]u2{ FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(1), FpgaAlu.encodeTrit(-1) };

    const result = alu.tf3DotBatch(&a, &b);

    try std.testing.expectEqual(@as(i32, 0), result);
}

test "FpgaAlu integration with GoldenFloat16" {
    var alu = try FpgaAlu.init(std.testing.allocator);
    alu.enableSoftware();

    // Test GF16 arithmetic preserves format properties
    const a_f32 = 1.5;
    const b_f32 = 2.25;
    const a = intraparietal_sulcus.gf16FromF32(a_f32);
    const b = intraparietal_sulcus.gf16FromF32(b_f32);

    // Add
    const sum_raw = alu.gf16Add(@bitCast(a), @bitCast(b));
    const sum_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(sum_raw));
    const sum_f32 = intraparietal_sulcus.gf16ToF32(sum_gf16);

    // Verify result is close to expected
    try std.testing.expectApproxEqAbs(3.75, sum_f32, 0.02);

    // Multiply
    const prod_raw = alu.gf16Mul(@bitCast(a), @bitCast(b));
    const prod_gf16 = @as(intraparietal_sulcus.GoldenFloat16, @bitCast(prod_raw));
    const prod_f32 = intraparietal_sulcus.gf16ToF32(prod_gf16);

    // Verify result is close to expected
    try std.testing.expectApproxEqAbs(3.375, prod_f32, 0.02);
}

// φ² + 1/φ² = 3 | TRINITY
