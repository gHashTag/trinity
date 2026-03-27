//! Compile-time Guards against known anti-patterns.
//! If code violates guard — compile error.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const sacred_types = @import("sacred_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE GUARDS — Forbid raw types instead of Sacred Types
// ═══════════════════════════════════════════════════════════════════════════════

/// Forbid direct use of raw containers for formats.
/// Use Sacred Types (GF16, TF3) instead of u16, i8.
pub fn forbidRawFormat(comptime T: type, comptime ctx: []const u8) void {
    comptime {
        const is_raw = T == u16 or T == u32 or T == i8 or T == u8;
        if (is_raw) {
            @compileError("Raw " ++ @typeName(T) ++ " forbidden in " ++ ctx ++
                " — use GF16/TF3/FormatId instead.");
        }
    }
}

/// Verify type is Sacred Type
pub fn requireSacredType(comptime T: type, comptime ctx: []const u8) void {
    comptime {
        const is_sacred = T == sacred_types.GF16 or T == sacred_types.TF3;
        if (!is_sacred) {
            @compileError(ctx ++ ": requires Sacred Type (GF16 or TF3)");
        }
    }
}

/// Forbid raw f32 in Sacred layers
pub fn forbidRawF32(comptime T: type, comptime ctx: []const u8) void {
    comptime {
        if (T == f32 or T == f64) {
            @compileError(ctx ++ ": raw f32/f64 forbidden here; use GF16/TF3 or F32Sacred wrapper");
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIMENSION GUARDS — Forbid magic dimension numbers
// ═══════════════════════════════════════════════════════════════════════════════

/// Forbid "random" dimensions for ternary / Sacred blocks
pub fn assertTernaryDim(comptime dim: usize, comptime ctx: []const u8) void {
    comptime {
        if (dim == 0) @compileError(ctx ++ ": dim cannot be zero");
        var n = dim;
        while (n % 3 == 0 and n > 1) n /= 3;
        if (n != 1)
            @compileError(ctx ++ ": dim must be 3^k for ternary resonance");
    }
}

/// Verify dimension is in Sacred Dimensions
pub fn assertSacredDim(comptime dim: usize, comptime ctx: []const u8) void {
    comptime {
        const sacred_dims = [_]usize{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049 };
        for (sacred_dims) |d| {
            if (d == dim) return;
        }
        @compileError(ctx ++ ": dimension must be Sacred Dimension (3^k)");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALLOCATION GUARDS — Forbid direct alloc/free
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify ArenaAllocator or other scoped allocator is used
pub fn forbidStdPageAllocator(comptime ctx: []const u8) void {
    comptime {
        @compileError(ctx ++ ": use ArenaAllocator or GPA, not std.heap.page_allocator directly");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZER GUARDS — Forbid dangerous settings
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify LR schedule is not flat
pub fn assertNotFlatLR(comptime schedule: []const u8, comptime ctx: []const u8) void {
    comptime {
        if (std.mem.eql(u8, schedule, "flat")) {
            @compileError(ctx ++ ": flat LR schedule KILLS models by 20K steps! Use cosine/sacred.");
        }
    }
}

/// Verify kill_ppl_30k is correct
pub fn assertKillPPL(comptime kill_ppl: comptime_int, comptime ctx: []const u8) void {
    comptime {
        if (kill_ppl < 400) {
            @compileError(ctx ++ ": kill_ppl_30k must be >= 400 (not 50) — early kill bug!");
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA GUARDS — Forbid dangerous operations
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify fxload is used before JTAG
pub fn assertFxloadBeforeJTAG(comptime fxload_done: bool, comptime ctx: []const u8) void {
    comptime {
        if (!fxload_done) {
            @compileError(ctx ++ ": fxload MUST run before JTAG (PID 0x0013→0x0008)");
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RAILWAY GUARDS — Service configuration validation
// ═══════════════════════════════════════════════════════════════════════════════

/// Railway service configuration validator (comptime struct check)
pub fn validateRailwayConfig(comptime T: type) void {
    comptime {
        // Check field presence
        if (!@hasField(T, "startCommand")) {
            @compileError("Railway config missing startCommand field");
        }

        // For training services startCommand must be null
        // (runtime check, but guard here as reminder)
    }
}

/// Runtime Railway config checker
pub const RailwayConfigGuard = struct {
    /// Verify startCommand is null (training services)
    pub fn assertNoStartCommand(_: RailwayConfigGuard, startCommand: ?[]const u8, ctx: []const u8) !void {
        if (startCommand != null) {
            return error.StartCommandNotNull;
        }
        _ = ctx;
    }

    /// Verify kill_ppl_30k >= 400
    pub fn assertKillPPLSafe(_: RailwayConfigGuard, kill_ppl_30k: i64) !void {
        if (kill_ppl_30k < 400) {
            return error.KillPPLTooLow;
        }
    }

    /// Verify builder = NIXPACKS
    pub fn assertNixpacksBuilder(_: RailwayConfigGuard, builder: []const u8) !void {
        if (!std.mem.eql(u8, builder, "NIXPACKS")) {
            return error.WrongBuilder;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HSLM TRAINING GUARDS
// ═══════════════════════════════════════════════════════════════════════════════

/// HSLM training configuration validator
pub const HSLMConfigGuard = struct {
    pub const Error = error{
        FlatLRSchedule,
        KillPPLTooLow,
        ContextNotTritResonance,
        BatchSizeNotMultiple,
    };

    /// Verify LR schedule
    pub fn assertLRSchedule(_: HSLMConfigGuard, schedule: []const u8) Error!void {
        if (std.mem.eql(u8, schedule, "flat")) {
            return Error.FlatLRSchedule;
        }
    }

    /// Verify context length
    pub fn assertContextLength(_: HSLMConfigGuard, ctx_len: usize) Error!void {
        var n = ctx_len;
        while (n % 3 == 0 and n > 1) n /= 3;
        if (n != 1) {
            return Error.ContextNotTritResonance;
        }
    }

    /// Verify batch size (must be multiple of 3 for ternary)
    pub fn assertBatchSize(_: HSLMConfigGuard, batch: usize) Error!void {
        if (batch % 3 != 0) {
            return Error.BatchSizeNotMultiple;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "assertTernaryDim accepts 3^k" {
    comptime {
        assertTernaryDim(3, "test");
        assertTernaryDim(9, "test");
        assertTernaryDim(81, "test");
    }
    try std.testing.expect(true);
}

test "assertSacredDim accepts sacred dimensions" {
    comptime {
        assertSacredDim(81, "test");
        assertSacredDim(243, "test");
        assertSacredDim(729, "test");
    }
    try std.testing.expect(true);
}

test "assertNotFlatLR allows valid schedules" {
    comptime {
        assertNotFlatLR("cosine", "test");
        assertNotFlatLR("sacred", "test");
        assertNotFlatLR("warmup_cosine", "test");
    }
    try std.testing.expect(true);
}

test "assertKillPPL accepts safe values" {
    comptime {
        assertKillPPL(400, "test");
        assertKillPPL(500, "test");
        assertKillPPL(1000, "test");
    }
    try std.testing.expect(true);
}

test "RailwayConfigGuard runtime checks" {
    const guard = RailwayConfigGuard{};

    // startCommand null should pass
    try guard.assertNoStartCommand(null, "test");

    // startCommand non-null should fail
    try std.testing.expectError(
        error.StartCommandNotNull,
        guard.assertNoStartCommand("some command", "test"),
    );

    // kill_ppl checks
    try guard.assertKillPPLSafe(400);
    try guard.assertKillPPLSafe(500);
    try std.testing.expectError(error.KillPPLTooLow, guard.assertKillPPLSafe(50));

    // builder checks
    try guard.assertNixpacksBuilder("NIXPACKS");
    try std.testing.expectError(error.WrongBuilder, guard.assertNixpacksBuilder("RAILPACK"));
}

test "HSLMConfigGuard validates training config" {
    const guard = HSLMConfigGuard{};

    // LR schedule checks
    try guard.assertLRSchedule("cosine");
    try guard.assertLRSchedule("sacred");
    try std.testing.expectError(error.FlatLRSchedule, guard.assertLRSchedule("flat"));

    // Context length checks
    try guard.assertContextLength(81);
    try guard.assertContextLength(243);
    try std.testing.expectError(error.ContextNotTritResonance, guard.assertContextLength(100));

    // Batch size checks
    try guard.assertBatchSize(66); // 66 = 3 * 22
    try guard.assertBatchSize(99); // 99 = 3 * 33
    try std.testing.expectError(error.BatchSizeNotMultiple, guard.assertBatchSize(64));
}

// φ² + 1/φ² = 3 | TRINITY
