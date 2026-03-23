// @origin(manual) @regen(pending)
// Trinity Hardware Deploy — tri hardware single/multi/status/stop-all
// Migrated from scripts/hardware-deploy.sh, fpga_benchmark_compare.sh, validate_verilog.sh
//
// Multi-node deployment, platform detection, PID management, FPGA benchmarking

const std = @import("std");

pub const Platform = enum {
    raspberry_pi,
    macos,
    linux,
    unknown,

    pub fn toString(self: Platform) []const u8 {
        return switch (self) {
            .raspberry_pi => "Raspberry Pi",
            .macos => "macOS",
            .linux => "Linux",
            .unknown => "Unknown",
        };
    }
};

pub const Arch = enum {
    arm64,
    x86_64,
    unknown,

    pub fn toString(self: Arch) []const u8 {
        return switch (self) {
            .arm64 => "arm64",
            .x86_64 => "x86_64",
            .unknown => "unknown",
        };
    }
};

pub const NodeConfig = struct {
    port: u16 = 9001,
    daemon: bool = true,
    binary_path: []const u8 = "./zig-out/bin/tri",
    pid_dir: []const u8 = ".trinity/multi",
    max_nodes: u32 = 50,
};

pub const NodeStatus = struct {
    id: u32,
    port: u16,
    pid: ?u32 = null,
    running: bool = false,
    healthy: bool = false,
};

/// FPGA benchmark configuration (theoretical calculations)
pub const FpgaBenchConfig = struct {
    vector_width: u32 = 256,
    mac_units: u32 = 16,
    clock_mhz: u32 = 100,
    cycles_per_op: u32 = 13,
};

/// Calculate theoretical FPGA throughput (ops/sec)
pub fn fpgaThroughput(config: FpgaBenchConfig) f64 {
    const ops_per_cycle = @as(f64, @floatFromInt(config.mac_units));
    const clock = @as(f64, @floatFromInt(config.clock_mhz)) * 1e6;
    const cycles = @as(f64, @floatFromInt(config.cycles_per_op));
    return ops_per_cycle * clock / cycles;
}

/// Calculate CPU vs FPGA speedup factor
pub fn speedupFactor(fpga_ops: f64, cpu_ops: f64) f64 {
    if (cpu_ops == 0) return 0;
    return fpga_ops / cpu_ops;
}

/// Detect host platform
pub fn detectPlatform() Platform {
    const os = @import("builtin").os.tag;
    return switch (os) {
        .macos => .macos,
        .linux => .linux,
        else => .unknown,
    };
}

/// Detect CPU architecture
pub fn detectArch() Arch {
    const arch = @import("builtin").cpu.arch;
    return switch (arch) {
        .aarch64 => .arm64,
        .x86_64 => .x86_64,
        else => .unknown,
    };
}

/// Generate port for node N (base_port + N)
pub fn nodePort(base_port: u16, node_id: u32) u16 {
    return base_port + @as(u16, @intCast(node_id));
}

test "fpga throughput" {
    const config = FpgaBenchConfig{};
    const throughput = fpgaThroughput(config);
    // 16 MACs * 100MHz / 13 cycles ≈ 123M ops/s
    try std.testing.expect(throughput > 1e8);
}

test "speedup factor" {
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), speedupFactor(200.0, 10.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), speedupFactor(200.0, 0.0), 0.01);
}

test "node port" {
    try std.testing.expectEqual(@as(u16, 9001), nodePort(9001, 0));
    try std.testing.expectEqual(@as(u16, 9005), nodePort(9001, 4));
}

test "detect platform" {
    const platform = detectPlatform();
    try std.testing.expect(platform != .unknown);
}
