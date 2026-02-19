//! FPGA Acceleration — Ternary Hardware Backend + Host-Side Driver
//! Generated from specs/tri/fpga_acceleration.vibee
//! HW-003: FPGA pipeline model for VSA operations
//! phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

pub const VECTOR_DIM: usize = 256;
pub const TRIT_BITS: usize = 2;
pub const TRITS_PER_WORD: usize = 16;
pub const WORDS_PER_VECTOR: usize = VECTOR_DIM / TRITS_PER_WORD;
pub const AXI_DATA_WIDTH: usize = 32;
pub const DEFAULT_CLOCK_MHZ: u32 = 100;
pub const MAX_CLOCK_MHZ: u32 = 200;

pub const FPGADevice = enum(u8) {
    artix7_35t,
    artix7_100t,
    zynq_7020,
    zynq_7045,

    pub fn name(self: FPGADevice) []const u8 {
        return switch (self) {
            .artix7_35t => "Artix-7 XC7A35T",
            .artix7_100t => "Artix-7 XC7A100T",
            .zynq_7020 => "Zynq-7020",
            .zynq_7045 => "Zynq-7045",
        };
    }
};

pub const FPGAOperation = enum(u8) {
    bind,
    bundle,
    dot_product,
    permute,
    matvec,
    cosine,

    pub fn name(self: FPGAOperation) []const u8 {
        return switch (self) {
            .bind => "BIND",
            .bundle => "BUNDLE",
            .dot_product => "DOT_PRODUCT",
            .permute => "PERMUTE",
            .matvec => "MATVEC",
            .cosine => "COSINE",
        };
    }
};

pub const TritEncoding = struct {
    pub const ZERO: u2 = 0b00;
    pub const POS: u2 = 0b01;
    pub const NEG: u2 = 0b10;
    pub const INVALID: u2 = 0b11;

    pub fn encode(value: i8) u2 {
        return switch (value) {
            0 => ZERO,
            1 => POS,
            -1 => NEG,
            else => INVALID,
        };
    }

    pub fn decode(encoded: u2) i8 {
        return switch (encoded) {
            ZERO => 0,
            POS => 1,
            NEG => -1,
            else => 0,
        };
    }

    pub fn encodeVector(output: []u32, input: []const i8, dim: usize) void {
        const num_words = (dim + TRITS_PER_WORD - 1) / TRITS_PER_WORD;
        for (0..num_words) |w| {
            var word: u32 = 0;
            for (0..TRITS_PER_WORD) |t| {
                const idx = w * TRITS_PER_WORD + t;
                if (idx < dim) {
                    const enc: u32 = @intCast(encode(input[idx]));
                    word |= enc << @intCast(t * TRIT_BITS);
                }
            }
            output[w] = word;
        }
    }

    pub fn decodeVector(output: []i8, input: []const u32, dim: usize) void {
        const num_words = (dim + TRITS_PER_WORD - 1) / TRITS_PER_WORD;
        for (0..num_words) |w| {
            const word = input[w];
            for (0..TRITS_PER_WORD) |t| {
                const idx = w * TRITS_PER_WORD + t;
                if (idx < dim) {
                    const bits: u2 = @truncate(word >> @intCast(t * TRIT_BITS));
                    output[idx] = decode(bits);
                }
            }
        }
    }

    pub fn encodedBytes(dim: usize) usize {
        return ((dim + TRITS_PER_WORD - 1) / TRITS_PER_WORD) * 4;
    }
};

pub const DeviceResources = struct {
    total_luts: u32,
    total_ffs: u32,
    total_bram_kb: u32,
    total_dsp: u32,

    pub fn forDevice(device: FPGADevice) DeviceResources {
        return switch (device) {
            .artix7_35t => .{ .total_luts = 20800, .total_ffs = 41600, .total_bram_kb = 225, .total_dsp = 90 },
            .artix7_100t => .{ .total_luts = 63400, .total_ffs = 126800, .total_bram_kb = 607, .total_dsp = 240 },
            .zynq_7020 => .{ .total_luts = 53200, .total_ffs = 106400, .total_bram_kb = 630, .total_dsp = 220 },
            .zynq_7045 => .{ .total_luts = 218600, .total_ffs = 437200, .total_bram_kb = 2180, .total_dsp = 900 },
        };
    }
};

pub const ResourceUsage = struct {
    luts: u32,
    ffs: u32,
    bram_kb: u32,
    dsp: u32,

    pub fn utilization(self: *const ResourceUsage, available: DeviceResources) f32 {
        const lut_pct = @as(f32, @floatFromInt(self.luts)) / @as(f32, @floatFromInt(available.total_luts));
        const ff_pct = @as(f32, @floatFromInt(self.ffs)) / @as(f32, @floatFromInt(available.total_ffs));
        const bram_pct = @as(f32, @floatFromInt(self.bram_kb)) / @as(f32, @floatFromInt(available.total_bram_kb));
        return @max(lut_pct, @max(ff_pct, bram_pct));
    }
};

pub const PipelineLatency = struct {
    bind_cycles: u32,
    bundle_cycles: u32,
    dot_product_cycles: u32,
    permute_cycles: u32,
    matvec_cycles: u32,

    pub fn forOperation(op: FPGAOperation, vector_dim: u32) PipelineLatency {
        _ = op;
        _ = vector_dim;
        return .{ .bind_cycles = 1, .bundle_cycles = 1, .dot_product_cycles = 3, .permute_cycles = 1, .matvec_cycles = 4 };
    }

    pub fn cosine_cycles(self: *const PipelineLatency) u32 {
        return self.dot_product_cycles * 3 + 2;
    }
};

pub const FPGAConfig = struct {
    device: FPGADevice,
    clock_mhz: u32,
    vector_dim: u32,
    num_mac_units: u32,
    bram_depth: u32,
};

pub const RegisterMap = struct {
    pub const CTRL: u12 = 0x000;
    pub const STATUS: u12 = 0x004;
    pub const VECTOR_DIM_REG: u12 = 0x008;
    pub const SHIFT_AMT: u12 = 0x00C;
    pub const DATA_A_BASE: u12 = 0x100;
    pub const DATA_B_BASE: u12 = 0x140;
    pub const DATA_OUT_BASE: u12 = 0x180;
    pub const PERF_BIND_OPS: u12 = 0x200;
    pub const PERF_BUNDLE_OPS: u12 = 0x204;
    pub const PERF_DOT_OPS: u12 = 0x208;
    pub const PERF_PERMUTE_OPS: u12 = 0x20C;
    pub const PERF_TOTAL_CYCLES: u12 = 0x210;
    pub const PERF_STALL_CYCLES: u12 = 0x214;
};

pub const FPGAPerformanceCounters = struct {
    bind_ops: u32,
    bundle_ops: u32,
    dot_ops: u32,
    permute_ops: u32,
    matvec_ops: u32,
    total_cycles: u32,
    stall_cycles: u32,

    pub fn init() FPGAPerformanceCounters {
        return .{ .bind_ops = 0, .bundle_ops = 0, .dot_ops = 0, .permute_ops = 0, .matvec_ops = 0, .total_cycles = 0, .stall_cycles = 0 };
    }

    pub fn totalOps(self: *const FPGAPerformanceCounters) u32 {
        return self.bind_ops + self.bundle_ops + self.dot_ops + self.permute_ops + self.matvec_ops;
    }

    pub fn throughput(self: *const FPGAPerformanceCounters, clock_mhz: u32) f64 {
        if (self.total_cycles == 0) return 0;
        const cycles_per_sec: f64 = @as(f64, @floatFromInt(clock_mhz)) * 1_000_000;
        const ops: f64 = @floatFromInt(self.totalOps());
        const cycles: f64 = @floatFromInt(self.total_cycles);
        return ops / cycles * cycles_per_sec;
    }

    pub fn stallRate(self: *const FPGAPerformanceCounters) f32 {
        if (self.total_cycles == 0) return 0;
        return @as(f32, @floatFromInt(self.stall_cycles)) / @as(f32, @floatFromInt(self.total_cycles));
    }

    pub fn reset(self: *FPGAPerformanceCounters) void {
        self.* = init();
    }
};

pub const FPGABackend = struct {
    config: FPGAConfig,
    counters: FPGAPerformanceCounters,
    latency: PipelineLatency,

    pub fn init(config: FPGAConfig) FPGABackend {
        return .{
            .config = config,
            .counters = FPGAPerformanceCounters.init(),
            .latency = PipelineLatency.forOperation(.bind, config.vector_dim),
        };
    }

    pub fn initDefault() FPGABackend {
        return init(.{ .device = .artix7_100t, .clock_mhz = DEFAULT_CLOCK_MHZ, .vector_dim = VECTOR_DIM, .num_mac_units = 16, .bram_depth = 4096 });
    }

    pub fn bind(self: *FPGABackend, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        for (0..dim) |i| {
            const prod = @as(i16, a[i]) * @as(i16, b[i]);
            output[i] = @as(i8, @intCast(std.math.clamp(prod, -1, 1)));
        }
        self.counters.bind_ops += 1;
        self.counters.total_cycles += self.latency.bind_cycles;
    }

    pub fn bundle(self: *FPGABackend, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        for (0..dim) |i| {
            const sum = @as(i16, a[i]) + @as(i16, b[i]);
            output[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else @as(i8, 0);
        }
        self.counters.bundle_ops += 1;
        self.counters.total_cycles += self.latency.bundle_cycles;
    }

    pub fn dotProduct(self: *FPGABackend, a: []const i8, b: []const i8, dim: usize) i32 {
        var acc: i32 = 0;
        for (0..dim) |i| {
            acc += @as(i32, a[i]) * @as(i32, b[i]);
        }
        self.counters.dot_ops += 1;
        self.counters.total_cycles += self.latency.dot_product_cycles;
        return acc;
    }

    pub fn permute(self: *FPGABackend, output: []i8, input: []const i8, dim: usize, shift: u32) void {
        for (0..dim) |i| {
            const src = (i + shift) % dim;
            output[i] = input[src];
        }
        self.counters.permute_ops += 1;
        self.counters.total_cycles += self.latency.permute_cycles;
    }

    pub fn cosineSimilarity(self: *FPGABackend, a: []const i8, b: []const i8, dim: usize) f32 {
        var dot: i64 = 0;
        var norm_a: i64 = 0;
        var norm_b: i64 = 0;
        for (0..dim) |i| {
            dot += @as(i64, a[i]) * @as(i64, b[i]);
            norm_a += @as(i64, a[i]) * @as(i64, a[i]);
            norm_b += @as(i64, b[i]) * @as(i64, b[i]);
        }
        const denom = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));
        self.counters.dot_ops += 1;
        self.counters.total_cycles += self.latency.cosine_cycles();
        if (denom == 0.0) return 0.0;
        return @floatCast(@as(f64, @floatFromInt(dot)) / denom);
    }

    pub fn ternaryMatVec(self: *FPGABackend, output: []f32, matrix: []const i8, vector: []const f32, rows: usize, cols: usize) void {
        for (0..rows) |r| {
            var acc: f32 = 0.0;
            for (0..cols) |c| {
                const w = matrix[r * cols + c];
                if (w == 1) acc += vector[c] else if (w == -1) acc -= vector[c];
            }
            output[r] = acc;
        }
        self.counters.matvec_ops += 1;
        self.counters.total_cycles += self.latency.matvec_cycles * @as(u32, @intCast(rows));
    }

    pub fn getCounters(self: *const FPGABackend) FPGAPerformanceCounters {
        return self.counters;
    }

    pub fn resetCounters(self: *FPGABackend) void {
        self.counters.reset();
    }
};

pub const ResourceEstimator = struct {
    pub fn estimateTotal(vector_dim: u32, num_mac_units: u32) ResourceUsage {
        const control_luts: u32 = 200;
        const total_luts = vector_dim * 4 + 968 * num_mac_units + control_luts;
        return .{ .luts = total_luts, .ffs = total_luts / 2, .bram_kb = 36, .dsp = 0 };
    }
};

pub const FPGASynthesisReport = struct {
    device: FPGADevice,
    clock_mhz: u32,
    resource_usage: ResourceUsage,
    device_resources: DeviceResources,
    latency: PipelineLatency,
    throughput_ops_per_sec: u64,
    power_watts: f32,
    utilization_pct: f32,

    pub fn generate(device: FPGADevice, clock_mhz: u32, vector_dim: u32, num_mac_units: u32) FPGASynthesisReport {
        const dev_res = DeviceResources.forDevice(device);
        const usage = ResourceEstimator.estimateTotal(vector_dim, num_mac_units);
        const latency = PipelineLatency.forOperation(.bind, vector_dim);
        const ops_per_sec: u64 = @as(u64, clock_mhz) * 1_000_000;
        const power = 0.5 + @as(f32, @floatFromInt(usage.luts)) * 0.003 / 1000.0;
        return .{
            .device = device,
            .clock_mhz = clock_mhz,
            .resource_usage = usage,
            .device_resources = dev_res,
            .latency = latency,
            .throughput_ops_per_sec = ops_per_sec,
            .power_watts = power,
            .utilization_pct = usage.utilization(dev_res) * 100.0,
        };
    }

    pub fn fitsOnDevice(self: *const FPGASynthesisReport) bool {
        return self.utilization_pct < 95.0;
    }

    pub fn energyEfficiency(self: *const FPGASynthesisReport) f64 {
        if (self.power_watts == 0) return 0;
        return @as(f64, @floatFromInt(self.throughput_ops_per_sec)) / @as(f64, self.power_watts);
    }
};

pub const FPGAController = struct {
    backend: FPGABackend,
    registers: [256]u32,
    is_busy: bool,
    has_error: bool,

    pub fn init(device: FPGADevice, clock_mhz: u32) FPGAController {
        var ctrl: FPGAController = undefined;
        @memset(&ctrl.registers, 0);
        ctrl.backend = FPGABackend.init(.{ .device = device, .clock_mhz = clock_mhz, .vector_dim = VECTOR_DIM, .num_mac_units = 16, .bram_depth = 4096 });
        ctrl.is_busy = false;
        ctrl.has_error = false;
        return ctrl;
    }

    pub fn initDefault() FPGAController {
        return init(.artix7_100t, DEFAULT_CLOCK_MHZ);
    }

    pub fn writeRegister(self: *FPGAController, offset: u12, value: u32) void {
        const idx = @as(usize, offset) / 4;
        if (idx < self.registers.len) self.registers[idx] = value;
    }

    pub fn readRegister(self: *const FPGAController, offset: u12) u32 {
        const idx = @as(usize, offset) / 4;
        if (idx < self.registers.len) return self.registers[idx];
        return 0;
    }

    pub fn dispatchBind(self: *FPGAController, output: []i8, a: []const i8, b: []const i8, dim: usize) void {
        self.is_busy = true;
        self.backend.bind(output, a, b, dim);
        self.is_busy = false;
        self.registers[@as(usize, RegisterMap.STATUS) / 4] = 0x02;
    }

    pub fn dispatchDotProduct(self: *FPGAController, a: []const i8, b: []const i8, dim: usize) i32 {
        self.is_busy = true;
        const result = self.backend.dotProduct(a, b, dim);
        self.is_busy = false;
        self.registers[@as(usize, RegisterMap.STATUS) / 4] = 0x02;
        return result;
    }

    pub fn dispatchCosine(self: *FPGAController, a: []const i8, b: []const i8, dim: usize) f32 {
        self.is_busy = true;
        const result = self.backend.cosineSimilarity(a, b, dim);
        self.is_busy = false;
        self.registers[@as(usize, RegisterMap.STATUS) / 4] = 0x02;
        return result;
    }

    pub fn getCounters(self: *const FPGAController) FPGAPerformanceCounters {
        return self.backend.getCounters();
    }

    pub fn getSynthesisReport(self: *const FPGAController) FPGASynthesisReport {
        return FPGASynthesisReport.generate(self.backend.config.device, self.backend.config.clock_mhz, self.backend.config.vector_dim, self.backend.config.num_mac_units);
    }

    pub fn isBusy(self: *const FPGAController) bool {
        return self.is_busy;
    }
};

pub const ComparisonReport = struct {
    cpu_ops_per_sec: f64,
    fpga_ops_per_sec: f64,
    cpu_power_watts: f32,
    fpga_power_watts: f32,

    pub fn speedup(self: *const ComparisonReport) f64 {
        if (self.cpu_ops_per_sec == 0) return 0;
        return self.fpga_ops_per_sec / self.cpu_ops_per_sec;
    }

    pub fn energyRatio(self: *const ComparisonReport) f64 {
        if (self.fpga_ops_per_sec == 0 or self.cpu_power_watts == 0) return 0;
        const cpu_energy = @as(f64, self.cpu_power_watts) / self.cpu_ops_per_sec;
        const fpga_energy = @as(f64, self.fpga_power_watts) / self.fpga_ops_per_sec;
        if (fpga_energy == 0) return 0;
        return cpu_energy / fpga_energy;
    }

    pub fn forBind256() ComparisonReport {
        return .{ .cpu_ops_per_sec = 50_000_000, .fpga_ops_per_sec = 100_000_000, .cpu_power_watts = 65.0, .fpga_power_watts = 0.5 };
    }
};

test "trit encoding roundtrip" {
    try std.testing.expectEqual(TritEncoding.decode(TritEncoding.encode(0)), 0);
    try std.testing.expectEqual(TritEncoding.decode(TritEncoding.encode(1)), 1);
    try std.testing.expectEqual(TritEncoding.decode(TritEncoding.encode(-1)), -1);
}

test "trit vector encoding roundtrip" {
    const original = [_]i8{ 1, -1, 0, 1, -1, -1, 0, 1, 1, 0, -1, 1, 0, 0, 1, -1 };
    var encoded: [1]u32 = undefined;
    var decoded: [16]i8 = undefined;
    TritEncoding.encodeVector(&encoded, &original, 16);
    TritEncoding.decodeVector(&decoded, &encoded, 16);
    try std.testing.expectEqualSlices(i8, &original, &decoded);
}

test "device resources" {
    try std.testing.expectEqual(DeviceResources.forDevice(.artix7_35t).total_luts, 20800);
    try std.testing.expectEqual(DeviceResources.forDevice(.artix7_100t).total_luts, 63400);
}

test "pipeline latency" {
    const lat = PipelineLatency.forOperation(.bind, 256);
    try std.testing.expectEqual(lat.bind_cycles, 1);
    try std.testing.expectEqual(lat.dot_product_cycles, 3);
}

test "FPGA backend bind" {
    var fpga = FPGABackend.initDefault();
    const a = [_]i8{ 1, -1, 1, 0 };
    const b = [_]i8{ 1, 1, -1, 1 };
    var out: [4]i8 = undefined;
    fpga.bind(&out, &a, &b, 4);
    try std.testing.expectEqualSlices(i8, &[_]i8{ 1, -1, -1, 0 }, &out);
}

test "FPGA backend dot product" {
    var fpga = FPGABackend.initDefault();
    const a = [_]i8{ 1, -1, 1, -1 };
    const b = [_]i8{ 1, -1, 1, -1 };
    try std.testing.expectEqual(fpga.dotProduct(&a, &b, 4), 4);
}

test "FPGA backend cosine" {
    var fpga = FPGABackend.initDefault();
    const a = [_]i8{ 1, -1, 1, -1 };
    try std.testing.expectApproxEqAbs(fpga.cosineSimilarity(&a, &a, 4), 1.0, 0.001);
}

test "FPGA backend permute" {
    var fpga = FPGABackend.initDefault();
    const input = [_]i8{ 1, -1, 0 };
    var out: [3]i8 = undefined;
    fpga.permute(&out, &input, 3, 1);
    try std.testing.expectEqualSlices(i8, &[_]i8{ -1, 0, 1 }, &out);
}

test "FPGA backend matvec" {
    var fpga = FPGABackend.initDefault();
    const matrix = [_]i8{ 1, -1, 0, 0, 1, -1 };
    const vector = [_]f32{ 3, 2, 1 };
    var out: [2]f32 = undefined;
    fpga.ternaryMatVec(&out, &matrix, &vector, 2, 3);
    try std.testing.expectApproxEqAbs(out[0], 1.0, 0.01);
    try std.testing.expectApproxEqAbs(out[1], 1.0, 0.01);
}

test "FPGA performance counters" {
    var fpga = FPGABackend.initDefault();
    const a = [_]i8{ 1, -1 };
    const b = [_]i8{ 1, 1 };
    var out: [2]i8 = undefined;
    fpga.bind(&out, &a, &b, 2);
    try std.testing.expectEqual(fpga.getCounters().bind_ops, 1);
}

test "resource estimation" {
    const usage = ResourceEstimator.estimateTotal(256, 16);
    try std.testing.expect(usage.luts > 5000);
    try std.testing.expectEqual(usage.dsp, 0);
}

test "synthesis report" {
    const report = FPGASynthesisReport.generate(.artix7_100t, 100, 256, 16);
    try std.testing.expect(report.fitsOnDevice());
    try std.testing.expect(report.throughput_ops_per_sec > 0);
}

test "FPGA controller" {
    var ctrl = FPGAController.initDefault();
    const a = [_]i8{ 1, -1 };
    const b = [_]i8{ 1, 1 };
    var out: [2]i8 = undefined;
    ctrl.dispatchBind(&out, &a, &b, 2);
    try std.testing.expectEqualSlices(i8, &[_]i8{ 1, -1 }, &out);
    try std.testing.expectEqual(ctrl.dispatchDotProduct(&a, &b, 2), 0);
}

test "FPGA controller cosine" {
    var ctrl = FPGAController.initDefault();
    const a = [_]i8{ 1, -1, 1 };
    try std.testing.expectApproxEqAbs(ctrl.dispatchCosine(&a, &a, 3), 1.0, 0.001);
}

test "comparison report" {
    const cmp = ComparisonReport.forBind256();
    try std.testing.expect(cmp.speedup() >= 1.5);
    try std.testing.expect(cmp.energyRatio() > 100);
}

test "device names" {
    try std.testing.expectEqualSlices(u8, "Artix-7 XC7A35T", FPGADevice.artix7_35t.name());
    try std.testing.expectEqualSlices(u8, "Zynq-7045", FPGADevice.zynq_7045.name());
}

test "operation names" {
    try std.testing.expectEqualSlices(u8, "BIND", FPGAOperation.bind.name());
    try std.testing.expectEqualSlices(u8, "DOT_PRODUCT", FPGAOperation.dot_product.name());
}

// phi^2 + 1/phi^2 = 3 | TRINITY
