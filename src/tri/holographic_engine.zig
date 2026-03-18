// @origin(spec:holographic_engine.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// holographic_engine.zig — Holographic Renderer Engine
// Generated from: specs/tri/holographic_renderer.tri v3.1.0
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
const STRING_LANDSCAPE_LOG: f64 = 500.0;
const CALABI_YAU_EULER: f64 = 480.0;
const VACUUM_DECAY_RATE: f64 = 0.00618;

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

pub const MultiverseBubble = struct {
    id: u8,
    cosmological_constant: f64,
    tunneling_prob: f64,
    radius: f64,
    inflation_rate: f64,
    is_our_vacuum: bool,
};

pub const StringLandscapePoint = struct {
    modulus_x: f64,
    modulus_y: f64,
    energy: f64,
    flux_config: u16,
    is_minimum: bool,
    tunneling_to: ?u8,
};

pub const RyuTakayanagi = struct {
    boundary_start: f64,
    boundary_end: f64,
    geodesic_length: f64,
    entanglement_entropy: f64,
    phi_correction: f64,
    area_over_4g: f64,
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

pub fn computeMultiverseBubbles(allocator: Allocator) ![]MultiverseBubble {
    var result: std.ArrayListUnmanaged(MultiverseBubble) = .{};
    var i: u8 = 0;
    while (i < 7) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const is_ours = (i == 3);
        const cc: f64 = if (is_ours) 0.685 else (fi - 3.0) * 0.5;
        const tunneling = VACUUM_DECAY_RATE * @exp(-fi * PHI);
        var radius: f64 = 1.0;
        var k: u8 = 0;
        while (k < i + 1) : (k += 1) {
            radius *= PHI;
        }
        const inflation = 67.4 * (1.0 + 0.1 * @sin(fi * 2.0 * PI / 7.0));
        try result.append(allocator, .{
            .id = i,
            .cosmological_constant = cc,
            .tunneling_prob = tunneling,
            .radius = radius,
            .inflation_rate = inflation,
            .is_our_vacuum = is_ours,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn computeStringLandscape(allocator: Allocator) ![]StringLandscapePoint {
    var result: std.ArrayListUnmanaged(StringLandscapePoint) = .{};
    var i: u8 = 0;
    while (i < 9) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const mx = @cos(fi * 2.0 * PI / 9.0) * (1.0 + 0.3 * PHI);
        const my = @sin(fi * 2.0 * PI / 9.0) * (1.0 + 0.3 * PHI_INV);
        const energy = -PHI_SQ + 0.5 * fi + 0.1 * @sin(fi * PI / 3.0);
        const mod3 = i % 3;
        var flux: u16 = 1;
        var k: u8 = 0;
        while (k < mod3 + 1) : (k += 1) {
            flux *= 27;
        }
        const is_min = (mod3 == 0);
        const tunnel: ?u8 = if (is_min) null else (i / 3) * 3;
        try result.append(allocator, .{
            .modulus_x = mx,
            .modulus_y = my,
            .energy = energy,
            .flux_config = flux,
            .is_minimum = is_min,
            .tunneling_to = tunnel,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn computeRyuTakayanagi(allocator: Allocator) ![]RyuTakayanagi {
    var result: std.ArrayListUnmanaged(RyuTakayanagi) = .{};
    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const b_start = 0.1 * fi;
        const b_end = 0.1 * fi + 0.1 * (fi + 1.0);
        const interval = b_end - b_start;
        const geodesic = 2.0 * @log(interval / 0.01);
        const entropy = (BROWN_HENNEAUX / 3.0) * @log(interval / 0.01);
        const phi_corr = PHI_INV * @exp(-geodesic / PHI_SQ);
        const area = entropy * (1.0 + phi_corr);
        try result.append(allocator, .{
            .boundary_start = b_start,
            .boundary_end = b_end,
            .geodesic_length = geodesic,
            .entanglement_entropy = entropy,
            .phi_correction = phi_corr,
            .area_over_4g = area,
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
    } else if (std.mem.eql(u8, mode_str, "multiverse")) {
        const bubbles = try computeMultiverseBubbles(allocator);
        defer allocator.free(bubbles);
        try w.writeAll(",\"bubbles\":[");
        for (bubbles, 0..) |bubble, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"id\":{d},\"cosmological_constant\":{d:.6},\"tunneling_prob\":{d:.10},\"radius\":{d:.6},\"inflation_rate\":{d:.4},\"is_our_vacuum\":{s}}}", .{
                bubble.id, bubble.cosmological_constant, bubble.tunneling_prob, bubble.radius, bubble.inflation_rate, if (bubble.is_our_vacuum) "true" else "false",
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "string_landscape")) {
        const points = try computeStringLandscape(allocator);
        defer allocator.free(points);
        try w.writeAll(",\"landscape\":[");
        for (points, 0..) |point, idx| {
            if (idx > 0) try w.writeAll(",");
            if (point.tunneling_to) |t| {
                try std.fmt.format(w, "{{\"modulus_x\":{d:.6},\"modulus_y\":{d:.6},\"energy\":{d:.6},\"flux_config\":{d},\"is_minimum\":{s},\"tunneling_to\":{d}}}", .{
                    point.modulus_x, point.modulus_y, point.energy, point.flux_config, if (point.is_minimum) "true" else "false", t,
                });
            } else {
                try std.fmt.format(w, "{{\"modulus_x\":{d:.6},\"modulus_y\":{d:.6},\"energy\":{d:.6},\"flux_config\":{d},\"is_minimum\":{s},\"tunneling_to\":null}}", .{
                    point.modulus_x, point.modulus_y, point.energy, point.flux_config, if (point.is_minimum) "true" else "false",
                });
            }
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "ryu_takayanagi")) {
        const geodesics = try computeRyuTakayanagi(allocator);
        defer allocator.free(geodesics);
        try w.writeAll(",\"geodesics\":[");
        for (geodesics, 0..) |geo, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"boundary_start\":{d:.4},\"boundary_end\":{d:.4},\"geodesic_length\":{d:.6},\"entanglement_entropy\":{d:.6},\"phi_correction\":{d:.10},\"area_over_4g\":{d:.6}}}", .{
                geo.boundary_start, geo.boundary_end, geo.geodesic_length, geo.entanglement_entropy, geo.phi_correction, geo.area_over_4g,
            });
        }
        try w.writeAll("]");
    } else {
        try w.writeAll(",\"modes\":[\"ads\",\"spin_network\",\"penrose\",\"entropy\",\"hawking\",\"multiverse\",\"string_landscape\",\"ryu_takayanagi\"]");
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

test "multiverse bubbles" {
    const allocator = std.testing.allocator;
    const bubbles = try computeMultiverseBubbles(allocator);
    defer allocator.free(bubbles);
    try std.testing.expectEqual(@as(usize, 7), bubbles.len);
    // Our vacuum is at id=3
    try std.testing.expectEqual(true, bubbles[3].is_our_vacuum);
    try std.testing.expectApproxEqAbs(@as(f64, 0.685), bubbles[3].cosmological_constant, 0.001);
    // Other bubbles are not our vacuum
    try std.testing.expectEqual(false, bubbles[0].is_our_vacuum);
    try std.testing.expectEqual(false, bubbles[6].is_our_vacuum);
    // All radii should be positive (PHI^n)
    for (bubbles) |bubble| {
        try std.testing.expect(bubble.radius > 0);
        try std.testing.expect(bubble.tunneling_prob > 0);
        try std.testing.expect(bubble.inflation_rate > 0);
    }
}

test "string landscape" {
    const allocator = std.testing.allocator;
    const points = try computeStringLandscape(allocator);
    defer allocator.free(points);
    try std.testing.expectEqual(@as(usize, 9), points.len);
    // Count minima: indices 0, 3, 6 (i%3==0) = 3 minima
    var minima_count: usize = 0;
    for (points) |point| {
        if (point.is_minimum) minima_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), minima_count);
    // Minima have null tunneling_to
    try std.testing.expectEqual(@as(?u8, null), points[0].tunneling_to);
    try std.testing.expectEqual(@as(?u8, null), points[3].tunneling_to);
    try std.testing.expectEqual(@as(?u8, null), points[6].tunneling_to);
    // Non-minima have tunneling target
    try std.testing.expect(points[1].tunneling_to != null);
    try std.testing.expect(points[2].tunneling_to != null);
}

test "ryu takayanagi" {
    const allocator = std.testing.allocator;
    const geodesics = try computeRyuTakayanagi(allocator);
    defer allocator.free(geodesics);
    try std.testing.expectEqual(@as(usize, 5), geodesics.len);
    // All entanglement entropies should be positive
    for (geodesics) |geo| {
        try std.testing.expect(geo.entanglement_entropy > 0);
        try std.testing.expect(geo.geodesic_length > 0);
        try std.testing.expect(geo.area_over_4g > 0);
        try std.testing.expect(geo.phi_correction > 0);
        // boundary_end > boundary_start
        try std.testing.expect(geo.boundary_end > geo.boundary_start);
    }
    // Entropy should increase with interval size
    try std.testing.expect(geodesics[4].entanglement_entropy > geodesics[1].entanglement_entropy);
}
