// ═══════════════════════════════════════════════════════════════════════════════
// holographic_engine.zig — Holographic Renderer Engine
// Generated from: specs/tri/holographic_renderer.vibee v3.1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Computes holographic physics data for API consumption:
//   - AdS/CFT bulk-boundary layers with entropy density
//   - Spin network nodes with area eigenvalues
//   - Penrose tiling properties (kite/dart ratios)
//   - Bekenstein-Hawking entropy surface
//   - Hawking radiation frames
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = 2.6180339887498948482;
const PHI_INV: f64 = 0.6180339887498948482;
const PHI_INV_SQ: f64 = 0.3819660112501051518;
const PI: f64 = 3.14159265358979323846;
const BARBERO_IMMIRZI: f64 = 0.1273840231409480;
const BEKENSTEIN_RATIO: f64 = 0.25;
const HOLOGRAPHIC_BITS: f64 = 0.3606737602222408;
const BROWN_HENNEAUX: f64 = 1.5;

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const HoloMode = enum {
    ads,
    spin_network,
    penrose,
    entropy,
    hawking,
};

pub const BulkLayer = struct {
    z: f64,
    width: u32,
    entropy_density: f64,
    region: []const u8, // "boundary", "near", "mid", "deep"
};

pub const SpinNode = struct {
    id: u8,
    spin: f64,
    area_eigenvalue: f64,
    volume_eigenvalue: f64,
};

pub const PenroseProperty = struct {
    name: []const u8,
    value: f64,
    description: []const u8,
};

pub const EntropySurface = struct {
    radius: u32,
    formula: []const u8,
    solar_mass_entropy_log10: f64,
    holographic_bits: f64,
};

pub const HawkingFrame = struct {
    frame: u8,
    mass: f64,
    temperature: f64,
    radius: u32,
};

pub const HolographicResult = struct {
    mode: []const u8,
    layers: ?[]BulkLayer,
    spin_nodes: ?[]SpinNode,
    penrose_props: ?[]PenroseProperty,
    entropy_surface: ?EntropySurface,
    hawking_frames: ?[]HawkingFrame,
    trinity_check: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Computation Functions
// ═══════════════════════════════════════════════════════════════════════════════

pub fn computeAdsLayers(allocator: Allocator) ![]BulkLayer {
    var result: std.ArrayListUnmanaged(BulkLayer) = .{};
    var z: u32 = 0;
    while (z < 12) : (z += 1) {
        const zf: f64 = @as(f64, @floatFromInt(z)) * 0.1 + 0.05;
        const width: u32 = 60 - z * 4;
        const entropy = BEKENSTEIN_RATIO / (zf * zf);
        const region: []const u8 = if (z == 0) "boundary" else if (z < 4) "near" else if (z < 8) "mid" else "deep";
        try result.append(allocator, .{
            .z = zf,
            .width = width,
            .entropy_density = entropy,
            .region = region,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn computeSpinNetwork(allocator: Allocator) ![]SpinNode {
    var result: std.ArrayListUnmanaged(SpinNode) = .{};
    const spins = [_]f64{ 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5 };
    for (spins, 0..) |j, idx| {
        const area = 8.0 * PI * BARBERO_IMMIRZI * @sqrt(j * (j + 1.0));
        const volume = @sqrt(j * (j + 1.0) * (2.0 * j + 1.0)) * 0.056;
        try result.append(allocator, .{
            .id = @intCast(idx),
            .spin = j,
            .area_eigenvalue = area,
            .volume_eigenvalue = volume,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn computePenroseProps(allocator: Allocator) ![]PenroseProperty {
    var result: std.ArrayListUnmanaged(PenroseProperty) = .{};
    try result.append(allocator, .{ .name = "kite_dart_ratio", .value = PHI, .description = "Kite/Dart area ratio = phi" });
    try result.append(allocator, .{ .name = "long_short_edge", .value = PHI, .description = "Long/Short edge ratio = phi" });
    try result.append(allocator, .{ .name = "inflation_factor", .value = PHI_SQ, .description = "Inflation factor = phi^2" });
    try result.append(allocator, .{ .name = "cos_2pi_5", .value = (PHI - 1.0) / 2.0, .description = "cos(2pi/5) = (phi-1)/2" });
    try result.append(allocator, .{ .name = "vertex_types", .value = 7.0, .description = "7 distinct vertex configurations" });
    try result.append(allocator, .{ .name = "symmetry_order", .value = 5.0, .description = "5-fold rotational symmetry" });
    return result.toOwnedSlice(allocator);
}

pub fn computeEntropySurface() EntropySurface {
    return .{
        .radius = 10,
        .formula = "S = A / (4 * l_P^2)",
        .solar_mass_entropy_log10 = 77.0,
        .holographic_bits = HOLOGRAPHIC_BITS,
    };
}

pub fn computeHawkingFrames(allocator: Allocator) ![]HawkingFrame {
    var result: std.ArrayListUnmanaged(HawkingFrame) = .{};
    var frame: u8 = 0;
    while (frame < 6) : (frame += 1) {
        const mass = 1.0 - @as(f64, @floatFromInt(frame)) * 0.15;
        const temp = 1.0 / (8.0 * PI * mass);
        const radius: u32 = @intFromFloat(8.0 * mass);
        try result.append(allocator, .{
            .frame = frame + 1,
            .mass = mass,
            .temperature = temp,
            .radius = radius,
        });
    }
    return result.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Serialization
// ═══════════════════════════════════════════════════════════════════════════════

pub fn holoToJson(allocator: Allocator, mode_str: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    const trinity = PHI_SQ + PHI_INV_SQ;

    try w.writeAll("{");
    try std.fmt.format(w, "\"mode\":\"{s}\",\"trinity_check\":{d:.6}", .{ mode_str, trinity });

    if (std.mem.eql(u8, mode_str, "ads")) {
        const layers = try computeAdsLayers(allocator);
        defer allocator.free(layers);
        try w.writeAll(",\"layers\":[");
        for (layers, 0..) |layer, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"z\":{d:.2},\"width\":{d},\"entropy_density\":{d:.4},\"region\":\"{s}\"}}", .{
                layer.z, layer.width, layer.entropy_density, layer.region,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "spin_network")) {
        const nodes = try computeSpinNetwork(allocator);
        defer allocator.free(nodes);
        try w.writeAll(",\"spin_nodes\":[");
        for (nodes, 0..) |node, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"id\":{d},\"spin\":{d:.1},\"area_eigenvalue\":{d:.6},\"volume_eigenvalue\":{d:.6}}}", .{
                node.id, node.spin, node.area_eigenvalue, node.volume_eigenvalue,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "penrose")) {
        const props = try computePenroseProps(allocator);
        defer allocator.free(props);
        try w.writeAll(",\"properties\":[");
        for (props, 0..) |prop, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"name\":\"{s}\",\"value\":{d:.10},\"description\":\"{s}\"}}", .{
                prop.name, prop.value, prop.description,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "entropy")) {
        const surface = computeEntropySurface();
        try std.fmt.format(w, ",\"entropy_surface\":{{\"radius\":{d},\"formula\":\"{s}\",\"solar_mass_entropy_log10\":{d:.1},\"holographic_bits\":{d:.10}}}", .{
            surface.radius, surface.formula, surface.solar_mass_entropy_log10, surface.holographic_bits,
        });
    } else if (std.mem.eql(u8, mode_str, "hawking")) {
        const frames = try computeHawkingFrames(allocator);
        defer allocator.free(frames);
        try w.writeAll(",\"hawking_frames\":[");
        for (frames, 0..) |frame, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"frame\":{d},\"mass\":{d:.4},\"temperature\":{d:.6},\"radius\":{d}}}", .{
                frame.frame, frame.mass, frame.temperature, frame.radius,
            });
        }
        try w.writeAll("]");
    } else {
        try w.writeAll(",\"modes\":[\"ads\",\"spin_network\",\"penrose\",\"entropy\",\"hawking\"]");
    }

    try w.writeAll("}");
    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity identity" {
    const trinity = PHI_SQ + PHI_INV_SQ;
    try std.testing.expectApproxEqAbs(trinity, 3.0, 0.0001);
}

test "ads layers count" {
    const allocator = std.testing.allocator;
    const layers = try computeAdsLayers(allocator);
    defer allocator.free(layers);
    try std.testing.expectEqual(@as(usize, 12), layers.len);
}

test "ads boundary layer" {
    const allocator = std.testing.allocator;
    const layers = try computeAdsLayers(allocator);
    defer allocator.free(layers);
    try std.testing.expectEqualStrings("boundary", layers[0].region);
    try std.testing.expectEqual(@as(u32, 60), layers[0].width);
}

test "spin network area eigenvalues" {
    const allocator = std.testing.allocator;
    const nodes = try computeSpinNetwork(allocator);
    defer allocator.free(nodes);
    try std.testing.expectEqual(@as(usize, 7), nodes.len);
    // j=0.5: A = 8*pi*gamma*sqrt(0.5*1.5) = 8*pi*0.1274*0.866 = ~2.76
    try std.testing.expect(nodes[0].area_eigenvalue > 0);
    // Area should increase with spin
    try std.testing.expect(nodes[1].area_eigenvalue > nodes[0].area_eigenvalue);
}

test "penrose properties" {
    const allocator = std.testing.allocator;
    const props = try computePenroseProps(allocator);
    defer allocator.free(props);
    try std.testing.expectEqual(@as(usize, 6), props.len);
    try std.testing.expectApproxEqAbs(PHI, props[0].value, 0.0001);
}

test "hawking frames" {
    const allocator = std.testing.allocator;
    const frames = try computeHawkingFrames(allocator);
    defer allocator.free(frames);
    try std.testing.expectEqual(@as(usize, 6), frames.len);
    try std.testing.expect(frames[0].mass > frames[5].mass);
    try std.testing.expect(frames[0].temperature < frames[5].temperature);
}

test "ads json output" {
    const allocator = std.testing.allocator;
    const json = try holoToJson(allocator, "ads");
    defer allocator.free(json);
    try std.testing.expect(json.len > 50);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"ads\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"layers\":[") != null);
}

test "spin_network json output" {
    const allocator = std.testing.allocator;
    const json = try holoToJson(allocator, "spin_network");
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"spin_nodes\":[") != null);
}

test "entropy surface" {
    const surface = computeEntropySurface();
    try std.testing.expectEqual(@as(u32, 10), surface.radius);
    try std.testing.expectApproxEqAbs(@as(f64, 77.0), surface.solar_mass_entropy_log10, 0.1);
}
