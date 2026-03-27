// Zenodo V17: Environmental Impact Tracking (MLSys 2025)
const std = @import("std");

pub const HardwareSpec = struct {
    name: []const u8,
    tdp_w: f64,
    performance_gflops: f64,

    pub fn init(name: []const u8, tdp_w: f64, performance_gflops: f64) HardwareSpec {
        return .{ .name = name, .tdp_w = tdp_w, .performance_gflops = performance_gflops };
    }

    pub fn efficiencyGflopsPerW(self: HardwareSpec) f64 {
        return self.performance_gflops / self.tdp_w;
    }
};

pub const HARDWARE = struct {
    pub const A100 = HardwareSpec.init("NVIDIA A100 80GB", 300.0, 312.0 * 1000.0);
    pub const H100 = HardwareSpec.init("NVIDIA H100", 700.0, 990.0 * 1000.0);
    pub const V100 = HardwareSpec.init("NVIDIA V100", 300.0, 125.5 * 1000.0);
};

pub const EnvironmentalImpact = struct {
    gpu_hours: f64,
    cpu_hours: f64,
    carbon_kg: f64,
    region: []const u8,
    hardware: []const u8,

    pub fn init(gpu_hours: f64, cpu_hours: f64, region: []const u8, hardware: []const u8) EnvironmentalImpact {
        const intensity = getCarbonIntensity(region);
        const gpu_kwh = gpu_hours * 0.3 * 1.5;
        const cpu_kwh = cpu_hours * 0.1 * 1.5;
        const carbon_kg = (gpu_kwh + cpu_kwh) * intensity / 1000.0;
        return .{
            .gpu_hours = gpu_hours,
            .cpu_hours = cpu_hours,
            .carbon_kg = carbon_kg,
            .region = region,
            .hardware = hardware,
        };
    }
};

pub fn getCarbonIntensity(region: []const u8) f64 {
    if (std.mem.eql(u8, region, "us-west")) return 250.0;
    if (std.mem.eql(u8, region, "us-east")) return 400.0;
    if (std.mem.eql(u8, region, "eu-north")) return 50.0;
    return 450.0;
}

test "Environmental: carbon calculation" {
    const impact = EnvironmentalImpact.init(100.0, 10.0, "us-west", "NVIDIA A100");
    try std.testing.expect(impact.carbon_kg > 10);
}

test "Environmental: eu-nord lower than us-west" {
    const eu = EnvironmentalImpact.init(100.0, 10.0, "eu-north", "NVIDIA A100");
    const us = EnvironmentalImpact.init(100.0, 10.0, "us-west", "NVIDIA A100");
    try std.testing.expect(eu.carbon_kg < us.carbon_kg);
}

// φ² + 1/φ² = 3 | TRINITY
