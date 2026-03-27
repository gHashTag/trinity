// ═══════════════════════════════════════════════════════════════════════════════
// Zenodo V17: Environmental Impact Tracking (MLSys 2025 Requirement)
// ═══════════════════════════════════════════════════════════════════════════════
//
// NEW REQUIREMENT: MLSys 2025 requires environmental impact disclosure
// - Carbon emissions (kg CO2e)
// - Hardware efficiency (GFLOPS/W)
// - Regional carbon intensity
//
// Reference: MLSys 2025 Call for Papers, Section 3.4 (Environmental Disclosure)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Carbon intensity by region (g CO2/kWh)
/// Source: Ember's Global Electricity Review 2024
pub const RegionCarbonIntensity = struct {
    region: []const u8,
    g_co2_per_kwh: f64,
    description: []const u8,
};

/// Known regions with their carbon intensity
pub const REGIONS = [_]RegionCarbonIntensity{
    .{ .region = "us-west", .g_co2_per_kwh = 250.0, .description = "California (clean grid)" },
    .{ .region = "us-east", .g_co2_per_kwh = 400.0, .description = "Virginia (mixed grid)" },
    .{ .region = "us-central", .g_co2_per_kwh = 550.0, .description = "Texas (fossil-heavy)" },
    .{ .region = "eu-central", .g_co2_per_kwh = 350.0, .description = "Germany (transitioning)" },
    .{ .region = "eu-north", .g_co2_per_kwh = 150.0, .description = "Nordics (renewable)" },
    .{ .region = "asia-east", .g_co2_per_kwh = 550.0, .description = "China (coal-heavy)" },
    .{ .region = "asia-south", .g_co2_per_kwh = 700.0, .description = "India (coal-heavy)" },
    .{ .region = "asia-southeast", .g_co2_per_kwh = 500.0, .description = "Singapore (gas-heavy)" },
    .{ .region = "australia", .g_co2_per_kwh = 600.0, .description = "Australia (fossil-heavy)" },
    .{ .region = "global", .g_co2_per_kwh = 450.0, .description = "Global average" },
};

/// Hardware power consumption (Watts)
pub const HardwareSpec = struct {
    name: []const u8,
    power_watts: f64,
    gflops: f64,
    efficiency_gflops_per_w: f64,

    pub fn init(name: []const u8, power_watts: f64, gflops: f64) HardwareSpec {
        return .{
            .name = name,
            .power_watts = power_watts,
            .gflops = gflops,
            .efficiency_gflops_per_w = gflops / power_watts,
        };
    }
};

/// Common hardware specifications
pub const HARDWARE = struct {
    pub const A100 = HardwareSpec.init("NVIDIA A100 80GB", 300.0, 312.0 * 1000.0);
    pub const H100 = HardwareSpec.init("NVIDIA H100", 700.0, 990.0 * 1000.0);
    pub const V100 = HardwareSpec.init("NVIDIA V100", 300.0, 125.5 * 1000.0);
    pub const RTX_4090 = HardwareSpec.init("NVIDIA RTX 4090", 450.0, 165.0 * 1000.0);
    pub const T4 = HardwareSpec.init("NVIDIA T4", 70.0, 75.4 * 1000.0);
};

/// Environmental Impact Metrics
pub const EnvironmentalImpact = struct {
    /// Compute hours
    gpu_hours: f64,
    cpu_hours: f64,

    /// Carbon emissions (kg CO2e)
    carbon_kg: f64,

    /// Hardware location (affects grid carbon intensity)
    region: []const u8,

    /// Hardware used
    hardware: []const u8,

    /// Hardware efficiency (GFLOPS/W)
    hardware_efficiency: f64,

    /// PUE (Power Usage Effectiveness) of datacenter
    pue: f64 = 1.5,

    /// Create environmental impact record
    pub fn init(
        gpu_hours: f64,
        cpu_hours: f64,
        region: []const u8,
        hardware: []const u8,
    ) EnvironmentalImpact {
        const carbon = calculateEmissions(gpu_hours, cpu_hours, region, 1.5);
        const spec = getHardwareSpec(hardware);

        return .{
            .gpu_hours = gpu_hours,
            .cpu_hours = cpu_hours,
            .carbon_kg = carbon,
            .region = region,
            .hardware = hardware,
            .hardware_efficiency = spec.efficiency_gflops_per_w,
        };
    }

    /// Calculate carbon emissions from compute
    pub fn calculateEmissions(
        gpu_hours: f64,
        cpu_hours: f64,
        region: []const u8,
        pue: f64,
    ) f64 {
        const intensity = getCarbonIntensity(region);

        // GPU power (average 300W per GPU)
        const gpu_kwh_calc = gpu_hours * 0.3 * pue;

        // CPU power (average 100W per core equivalent)
        const cpu_kwh_calc = cpu_hours * 0.1 * pue;

        // Total emissions
        const total_kwh = gpu_kwh_calc + cpu_kwh_calc;
        return (total_kwh * intensity) / 1000.0; // Convert to kg CO2
    }

    /// Format for MLSys submission
    pub fn formatMLSys(self: EnvironmentalImpact, allocator: std.mem.Allocator) ![]const u8 {
        const header = "Environmental Impact (MLSys 2025 Disclosure):\n";
        const separator = "─────────────────────────────────────────────────────────────\n";

        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, header);
        try buffer.appendSlice(allocator, separator);
        try buffer.print("Compute:\n", .{});
        try buffer.print("  • GPU Hours: {d:.1} hours\n", .{self.gpu_hours});
        try buffer.print("  • CPU Hours: {d:.1} hours\n", .{self.cpu_hours});
        try buffer.print("  • Hardware: {s}\n", .{self.hardware});
        try buffer.print("  • Region: {s}\n", .{self.region});
        try buffer.print("\n", .{});

        try buffer.print("Carbon Emissions:\n", .{});
        try buffer.print("  • Total: {d:.2} kg CO2e\n", .{self.carbon_kg});
        try buffer.print("  • GPU Contribution: {d:.2} kg CO2e\n", .{self.gpu_kwh() * getCarbonIntensity(self.region) / 1000.0});
        try buffer.print("  • CPU Contribution: {d:.2} kg CO2e\n", .{self.cpu_kwh() * getCarbonIntensity(self.region) / 1000.0});
        try buffer.print("\n", .{});

        try buffer.print("Efficiency:\n", .{});
        try buffer.print("  • Hardware Efficiency: {d:.1} GFLOPS/W\n", .{self.hardware_efficiency});
        try buffer.print("  • Datacenter PUE: {d:.2}\n", .{self.pue});
        try buffer.print("\n", .{});

        try buffer.print("Equivalent Impact:\n", .{});
        try buffer.print("  • Kilometers driven by average car: {d:.1} km\n", .{self.carbon_kg * 4.5});
        try buffer.print("  • Smartphone charges: {d:.0} charges\n", .{self.carbon_kg * 1000.0 / 0.05});
        try buffer.print("  • Trees needed for 1 year sequestration: {d:.2} trees\n", .{self.carbon_kg / 25.0});
        try buffer.appendSlice(allocator, separator);

        return buffer.toOwnedSlice();
    }

    /// GPU kWh
    fn gpu_kwh(self: EnvironmentalImpact) f64 {
        return self.gpu_hours * 0.3 * self.pue;
    }

    /// CPU kWh
    fn cpu_kwh(self: EnvironmentalImpact) f64 {
        return self.cpu_hours * 0.1 * self.pue;
    }

    /// Compare to baseline
    pub fn compare(self: EnvironmentalImpact, baseline: EnvironmentalImpact) Comparison {
        return .{
            .emissions_ratio = self.carbon_kg / baseline.carbon_kg,
            .efficiency_gain = (self.hardware_efficiency - baseline.hardware_efficiency)
                               / baseline.hardware_efficiency * 100.0,
            .hours_saved = baseline.gpu_hours - self.gpu_hours,
        };
    }
};

/// Comparison result
pub const Comparison = struct {
    emissions_ratio: f64,
    efficiency_gain: f64,
    hours_saved: f64,

    pub fn format(self: Comparison, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\Comparison to Baseline:
            \\  • Emissions Ratio: {d:.2}x ({s}{d:.0}%)
            \\  • Efficiency Gain: {s}{d:.1}%
            \\  • GPU Hours Saved: {d:.1} hours
        , .{
            self.emissions_ratio,
            if (self.emissions_ratio < 1.0) "↓ " else "↑ ",
            @abs(self.emissions_ratio - 1.0) * 100.0,
            if (self.efficiency_gain > 0.0) "+" else "",
            self.efficiency_gain,
            self.hours_saved,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get carbon intensity for region (g CO2/kWh)
pub fn getCarbonIntensity(region: []const u8) f64 {
    for (REGIONS) |r| {
        if (std.mem.eql(u8, r.region, region)) {
            return r.g_co2_per_kwh;
        }
    }
    // Default to global average
    return 450.0;
}

/// Get hardware specification
pub fn getHardwareSpec(name: []const u8) HardwareSpec {
    if (std.mem.indexOf(u8, name, "A100") != null) return HARDWARE.A100;
    if (std.mem.indexOf(u8, name, "H100") != null) return HARDWARE.H100;
    if (std.mem.indexOf(u8, name, "V100") != null) return HARDWARE.V100;
    if (std.mem.indexOf(u8, name, "4090") != null) return HARDWARE.RTX_4090;
    if (std.mem.indexOf(u8, name, "T4") != null) return HARDWARE.T4;

    // Default: generic GPU
    return HardwareSpec.init("Generic GPU", 300.0, 100.0 * 1000.0);
}

/// List all available regions
pub fn listRegions() []const RegionCarbonIntensity {
    return &REGIONS;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Environmental: carbon calculation us-west" {
    const emissions = EnvironmentalImpact.calculateEmissions(100.0, 10.0, "us-west", 1.5);
    // 100 GPU-hours * 0.3kW * 1.5 PUE * 250 g/kWh / 1000 = 11.25 kg
    const expected: f64 = 11.25;
    try std.testing.expectApproxEqAbs(expected, emissions, 0.5);
}

test "Environmental: carbon calculation eu-nord lower than us-west" {
    const emissions_eu = EnvironmentalImpact.calculateEmissions(100.0, 10.0, "eu-north", 1.5);
    const emissions_us = EnvironmentalImpact.calculateEmissions(100.0, 10.0, "us-west", 1.5);
    try std.testing.expect(emissions_eu < emissions_us);
}

test "Environmental: hardware efficiency" {
    try std.testing.expect(HARDWARE.H100.efficiency_gflops_per_w > HARDWARE.A100.efficiency_gflops_per_w);
    try std.testing.expect(HARDWARE.A100.efficiency_gflops_per_w > HARDWARE.V100.efficiency_gflops_per_w);
}

test "Environmental: MLSys formatting" {
    const impact = EnvironmentalImpact.init(152.0, 8.0, "us-west", "NVIDIA A100");
    const formatted = try impact.formatMLSys(std.testing.allocator);
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "MLSys 2025") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "152.0") != null);
}

test "Environmental: comparison formatting" {
    const impact1 = EnvironmentalImpact.init(100.0, 10.0, "us-west", "NVIDIA A100");
    const impact2 = EnvironmentalImpact.init(50.0, 5.0, "eu-north", "NVIDIA H100");

    const comparison = impact2.compare(impact1);
    try std.testing.expect(comparison.emissions_ratio < 1.0); // Lower emissions
    try std.testing.expect(comparison.efficiency_gain > 0.0); // Higher efficiency
}

test "Environmental: region lookup" {
    const us_west = getCarbonIntensity("us-west");
    try std.testing.expectApproxEqAbs(@as(f64, 250.0), us_west, 1.0);

    const unknown = getCarbonIntensity("unknown-region");
    try std.testing.expectApproxEqAbs(@as(f64, 450.0), unknown, 1.0); // Global avg
}

// φ² + 1/φ² = 3 | TRINITY
