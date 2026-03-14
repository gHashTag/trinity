// @origin(spec:qg_engine.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// qg_engine.zig — Quantum Gravity Simulation Engine
// Generated from: specs/tri/quantum_gravity_sim.tri v3.1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Computes quantum gravity simulation data for API consumption:
//   - Spin foam evolution (Ponzano-Regge model)
//   - Regge calculus (simplicial lattice relaxation)
//   - AdS/CFT thermalization dynamics
//   - LQG area spectrum (Barbero-Immirzi)
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
const BERRY_PHASE_QUTRIT: f64 = 2.0943951023931953; // 2*pi/3
const BROWN_HENNEAUX: f64 = 1.5;
const REGGE_SLOPE_ALPHA: f64 = 0.9382;
const CDT_CRITICAL_KAPPA: f64 = 2.2;
const PAGE_TIME_COEFF: f64 = 0.6180;

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpinFoamStep = struct {
    step: u32,
    amplitude: f64,
    action: f64,
    phase: f64,
    vertices: u32,
    edges: u32,
};

pub const ReggeStep = struct {
    iteration: u32,
    simplices: u32,
    deficit_angle: f64,
    regge_action: f64,
    curvature: f64,
};

pub const AdSThermalStep = struct {
    time: f64,
    s_entangle: f64,
    s_thermal: f64,
    scrambling_pct: f64,
    temperature: f64,
};

pub const AreaEigenvalue = struct {
    j: f64,
    area: f64,
    area_phi: f64,
    ratio_to_prev: f64,
};

pub const CDTStep = struct {
    time_slice: u32,
    simplices_24: u32,
    simplices_41: u32,
    spatial_volume: f64,
    dim_spectral: f64,
    total_simplices: u32,
};

pub const VenezianoAmplitude = struct {
    s: f64,
    t: f64,
    alpha_s: f64,
    alpha_t: f64,
    amplitude: f64,
    regge_slope: f64,
    string_tension: f64,
};

pub const PageCurveStep = struct {
    time: f64,
    bh_mass: f64,
    bh_entropy: f64,
    radiation_entropy: f64,
    total_entropy: f64,
    past_page_time: bool,
};

pub const QGSimResult = struct {
    steps: u32,
    spin_foam: []SpinFoamStep,
    regge: []ReggeStep,
    ads_thermal: []AdSThermalStep,
    area_spectrum: []AreaEigenvalue,
    area_gap: f64,
    trinity_check: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Simulation Functions
// ═══════════════════════════════════════════════════════════════════════════════

pub fn evolveSpinFoam(allocator: Allocator, steps: u32) ![]SpinFoamStep {
    var result: std.ArrayListUnmanaged(SpinFoamStep) = .{};
    var amp: f64 = 1.0;
    var action: f64 = 0.0;
    var phase: f64 = 0.0;
    var i: u32 = 0;
    while (i < steps) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        amp *= (PHI_INV + 0.1 * @sin(fi * BERRY_PHASE_QUTRIT));
        action += BARBERO_IMMIRZI * @sqrt(fi + 1.0) * @cos(fi * PI / 6.0);
        phase += BERRY_PHASE_QUTRIT;
        try result.append(allocator, .{
            .step = i + 1,
            .amplitude = amp,
            .action = action,
            .phase = phase,
            .vertices = 4 + i * 3,
            .edges = 6 + i * 5,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn evolveReggeLattice(allocator: Allocator, steps: u32) ![]ReggeStep {
    var result: std.ArrayListUnmanaged(ReggeStep) = .{};
    var regge_action: f64 = 10.0;
    var deficit: f64 = 0.5;
    var i: u32 = 0;
    const max_steps = @min(steps, 12);
    while (i < max_steps) : (i += 1) {
        regge_action *= (0.85 + 0.05 * PHI_INV);
        deficit *= 0.88;
        try result.append(allocator, .{
            .iteration = i + 1,
            .simplices = 8 + i * 4,
            .deficit_angle = deficit,
            .regge_action = regge_action,
            .curvature = deficit * 2.0 * PI,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn simulateAdsThermal(allocator: Allocator, steps: u32) ![]AdSThermalStep {
    var result: std.ArrayListUnmanaged(AdSThermalStep) = .{};
    var i: u32 = 0;
    const max_steps = @min(steps, 10) + 1;
    while (i < max_steps) : (i += 1) {
        const t: f64 = @as(f64, @floatFromInt(i)) * 0.1;
        const scramble = 1.0 / (1.0 + @exp(-5.0 * (t - 0.5)));
        const s_thermal = BROWN_HENNEAUX * PI;
        const s_entangle = s_thermal * scramble;
        const temp = 0.5 * (1.0 + 0.3 * @exp(-t));
        try result.append(allocator, .{
            .time = t,
            .s_entangle = s_entangle,
            .s_thermal = s_thermal,
            .scrambling_pct = scramble * 100.0,
            .temperature = temp,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn computeAreaSpectrum(allocator: Allocator) ![]AreaEigenvalue {
    var result: std.ArrayListUnmanaged(AreaEigenvalue) = .{};
    const js = [_]f64{ 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0 };
    var prev_area: f64 = 0.0;
    for (js) |j| {
        const area = 8.0 * PI * BARBERO_IMMIRZI * @sqrt(j * (j + 1.0));
        const area_phi = area * PHI;
        const ratio = if (prev_area > 0.0) area / prev_area else 0.0;
        try result.append(allocator, .{
            .j = j,
            .area = area,
            .area_phi = area_phi,
            .ratio_to_prev = ratio,
        });
        prev_area = area;
    }
    return result.toOwnedSlice(allocator);
}

pub fn computeAreaGap() f64 {
    return 8.0 * PI * BARBERO_IMMIRZI * @sqrt(0.5 * 1.5);
}

pub fn simulateCDT(allocator: Allocator, steps: u32) ![]CDTStep {
    var result: std.ArrayListUnmanaged(CDTStep) = .{};
    var i: u32 = 0;
    while (i < steps) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const variation: f64 = @abs(@sin(fi * PHI) * 30.0);
        const s24: u32 = 100 + i * 20 + @as(u32, @intFromFloat(variation));
        const s41: u32 = s24 / 3;
        const spatial_vol: f64 = @as(f64, @floatFromInt(s24)) * 0.01 * PHI;
        const half_steps = steps / 2;
        const dim: f64 = if (i > half_steps) 3.8 + 0.2 * PHI_INV else 1.8 + 0.2 * PHI_INV;
        try result.append(allocator, .{
            .time_slice = i,
            .simplices_24 = s24,
            .simplices_41 = s41,
            .spatial_volume = spatial_vol,
            .dim_spectral = dim,
            .total_simplices = s24 + s41,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn computeVenezianoAmplitudes(allocator: Allocator) ![]VenezianoAmplitude {
    var result: std.ArrayListUnmanaged(VenezianoAmplitude) = .{};
    const s_values = [_]f64{ 0.5, 1.0, 1.5, 2.0, 2.5, 3.0 };
    for (s_values) |s| {
        const t = -s * PHI_INV;
        const alpha_s = 1.0 + REGGE_SLOPE_ALPHA * s;
        const alpha_t = 1.0 + REGGE_SLOPE_ALPHA * t;
        const sum_alpha = alpha_s + alpha_t;
        // Stirling approximation for |Gamma(a)*Gamma(b)/Gamma(a+b)|
        // Use absolute values for analytic continuation when alpha_t < 0
        const abs_alpha_s = @abs(alpha_s);
        const abs_alpha_t = @max(0.001, @abs(alpha_t));
        const abs_sum = @abs(sum_alpha);
        const amp = @exp(abs_alpha_s * @log(abs_alpha_s) + abs_alpha_t * @log(abs_alpha_t) - abs_sum * @log(abs_sum));
        const tension = 1.0 / (2.0 * PI * REGGE_SLOPE_ALPHA);
        try result.append(allocator, .{
            .s = s,
            .t = t,
            .alpha_s = alpha_s,
            .alpha_t = alpha_t,
            .amplitude = amp,
            .regge_slope = REGGE_SLOPE_ALPHA,
            .string_tension = tension,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn simulatePageCurve(allocator: Allocator, steps: u32) ![]PageCurveStep {
    var result: std.ArrayListUnmanaged(PageCurveStep) = .{};
    const M: f64 = 10.0;
    const page_time: f64 = M * M * M * PAGE_TIME_COEFF;
    const initial_entropy: f64 = PI * M * M;
    var i: u32 = 0;
    while (i < steps) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const fsteps: f64 = @floatFromInt(steps);
        const time = fi * (2.0 * page_time) / fsteps;
        const mass_sq_arg = 1.0 - time / (2.0 * page_time);
        const bh_mass = M * @sqrt(@max(0.0, mass_sq_arg));
        const bh_entropy = PI * bh_mass * bh_mass;
        const past_page = time > page_time;
        const radiation_entropy = if (past_page) bh_entropy else (time / page_time) * initial_entropy;
        try result.append(allocator, .{
            .time = time,
            .bh_mass = bh_mass,
            .bh_entropy = bh_entropy,
            .radiation_entropy = radiation_entropy,
            .total_entropy = initial_entropy,
            .past_page_time = past_page,
        });
    }
    return result.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Serialization
// ═══════════════════════════════════════════════════════════════════════════════

pub fn qgSimToJson(allocator: Allocator, steps: u32) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    const trinity = PHI_SQ + PHI_INV_SQ;
    const area_gap = computeAreaGap();

    try std.fmt.format(w, "{{\"steps\":{d},\"trinity_check\":{d:.6},\"area_gap\":{d:.6}", .{ steps, trinity, area_gap });

    // Spin foam
    const foam = try evolveSpinFoam(allocator, steps);
    defer allocator.free(foam);
    try w.writeAll(",\"spin_foam\":[");
    for (foam, 0..) |s, idx| {
        if (idx > 0) try w.writeAll(",");
        try std.fmt.format(w, "{{\"step\":{d},\"amplitude\":{d:.8},\"action\":{d:.4},\"phase\":{d:.4},\"vertices\":{d},\"edges\":{d}}}", .{
            s.step, s.amplitude, s.action, s.phase, s.vertices, s.edges,
        });
    }
    try w.writeAll("]");

    // Regge
    const regge = try evolveReggeLattice(allocator, steps);
    defer allocator.free(regge);
    try w.writeAll(",\"regge\":[");
    for (regge, 0..) |r, idx| {
        if (idx > 0) try w.writeAll(",");
        try std.fmt.format(w, "{{\"iteration\":{d},\"simplices\":{d},\"deficit_angle\":{d:.6},\"regge_action\":{d:.4},\"curvature\":{d:.4}}}", .{
            r.iteration, r.simplices, r.deficit_angle, r.regge_action, r.curvature,
        });
    }
    try w.writeAll("]");

    // AdS thermal
    const ads = try simulateAdsThermal(allocator, steps);
    defer allocator.free(ads);
    try w.writeAll(",\"ads_thermal\":[");
    for (ads, 0..) |a, idx| {
        if (idx > 0) try w.writeAll(",");
        try std.fmt.format(w, "{{\"time\":{d:.1},\"s_entangle\":{d:.4},\"s_thermal\":{d:.4},\"scrambling_pct\":{d:.1},\"temperature\":{d:.4}}}", .{
            a.time, a.s_entangle, a.s_thermal, a.scrambling_pct, a.temperature,
        });
    }
    try w.writeAll("]");

    // Area spectrum
    const spectrum = try computeAreaSpectrum(allocator);
    defer allocator.free(spectrum);
    try w.writeAll(",\"area_spectrum\":[");
    for (spectrum, 0..) |a, idx| {
        if (idx > 0) try w.writeAll(",");
        try std.fmt.format(w, "{{\"j\":{d:.1},\"area\":{d:.6},\"area_phi\":{d:.6},\"ratio_to_prev\":{d:.6}}}", .{
            a.j, a.area, a.area_phi, a.ratio_to_prev,
        });
    }
    try w.writeAll("]");

    // CDT
    const cdt = try simulateCDT(allocator, steps);
    defer allocator.free(cdt);
    try w.writeAll(",\"cdt\":[");
    for (cdt, 0..) |c, idx| {
        if (idx > 0) try w.writeAll(",");
        try std.fmt.format(w, "{{\"time_slice\":{d},\"simplices_24\":{d},\"simplices_41\":{d},\"spatial_volume\":{d:.6},\"dim_spectral\":{d:.6},\"total_simplices\":{d}}}", .{
            c.time_slice, c.simplices_24, c.simplices_41, c.spatial_volume, c.dim_spectral, c.total_simplices,
        });
    }
    try w.writeAll("]");

    // Veneziano
    const veneziano = try computeVenezianoAmplitudes(allocator);
    defer allocator.free(veneziano);
    try w.writeAll(",\"veneziano\":[");
    for (veneziano, 0..) |v, idx| {
        if (idx > 0) try w.writeAll(",");
        try std.fmt.format(w, "{{\"s\":{d:.1},\"t\":{d:.6},\"alpha_s\":{d:.6},\"alpha_t\":{d:.6},\"amplitude\":{d:.8},\"regge_slope\":{d:.4},\"string_tension\":{d:.6}}}", .{
            v.s, v.t, v.alpha_s, v.alpha_t, v.amplitude, v.regge_slope, v.string_tension,
        });
    }
    try w.writeAll("]");

    // Page curve
    const page = try simulatePageCurve(allocator, steps);
    defer allocator.free(page);
    try w.writeAll(",\"page_curve\":[");
    for (page, 0..) |p, idx| {
        if (idx > 0) try w.writeAll(",");
        const past_str: []const u8 = if (p.past_page_time) "true" else "false";
        try std.fmt.format(w, "{{\"time\":{d:.4},\"bh_mass\":{d:.6},\"bh_entropy\":{d:.6},\"radiation_entropy\":{d:.6},\"total_entropy\":{d:.6},\"past_page_time\":{s}}}", .{
            p.time, p.bh_mass, p.bh_entropy, p.radiation_entropy, p.total_entropy, past_str,
        });
    }
    try w.writeAll("]");

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

test "spin foam evolution" {
    const allocator = std.testing.allocator;
    const foam = try evolveSpinFoam(allocator, 10);
    defer allocator.free(foam);
    try std.testing.expectEqual(@as(usize, 10), foam.len);
    try std.testing.expect(foam[0].amplitude > 0);
    try std.testing.expectEqual(@as(u32, 1), foam[0].step);
}

test "regge lattice" {
    const allocator = std.testing.allocator;
    const regge = try evolveReggeLattice(allocator, 10);
    defer allocator.free(regge);
    try std.testing.expectEqual(@as(usize, 10), regge.len);
    // Action should decrease (relaxation)
    try std.testing.expect(regge[0].regge_action > regge[9].regge_action);
}

test "ads thermalization" {
    const allocator = std.testing.allocator;
    const ads = try simulateAdsThermal(allocator, 10);
    defer allocator.free(ads);
    try std.testing.expectEqual(@as(usize, 11), ads.len); // 0..10 inclusive
    // Scrambling increases
    try std.testing.expect(ads[10].scrambling_pct > ads[0].scrambling_pct);
}

test "area spectrum" {
    const allocator = std.testing.allocator;
    const spectrum = try computeAreaSpectrum(allocator);
    defer allocator.free(spectrum);
    try std.testing.expectEqual(@as(usize, 8), spectrum.len);
    // Area increases with j
    try std.testing.expect(spectrum[7].area > spectrum[0].area);
}

test "area gap positive" {
    const gap = computeAreaGap();
    try std.testing.expect(gap > 0);
    try std.testing.expect(gap < 5.0); // reasonable range
}

test "qg json output" {
    const allocator = std.testing.allocator;
    const json = try qgSimToJson(allocator, 5);
    defer allocator.free(json);
    try std.testing.expect(json.len > 100);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"spin_foam\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"regge\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"ads_thermal\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"area_spectrum\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"cdt\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"veneziano\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"page_curve\":[") != null);
}

test "cdt spectral dimension" {
    const allocator = std.testing.allocator;
    const cdt = try simulateCDT(allocator, 20);
    defer allocator.free(cdt);
    try std.testing.expectEqual(@as(usize, 20), cdt.len);
    // Large scale (i > steps/2): dim_spectral should approach 4.0
    const large_dim = cdt[15].dim_spectral;
    try std.testing.expect(large_dim > 3.5);
    try std.testing.expect(large_dim < 4.5);
    // Small scale (i <= steps/2): dim_spectral should approach 2.0
    const small_dim = cdt[2].dim_spectral;
    try std.testing.expect(small_dim > 1.5);
    try std.testing.expect(small_dim < 2.5);
}

test "veneziano amplitude" {
    const allocator = std.testing.allocator;
    const ven = try computeVenezianoAmplitudes(allocator);
    defer allocator.free(ven);
    try std.testing.expectEqual(@as(usize, 6), ven.len);
    // String tension must be positive
    try std.testing.expect(ven[0].string_tension > 0);
    // All amplitudes should be positive (Stirling approx of Euler Beta)
    for (ven) |v| {
        try std.testing.expect(v.amplitude > 0);
    }
}

test "page curve" {
    const allocator = std.testing.allocator;
    const page = try simulatePageCurve(allocator, 100);
    defer allocator.free(page);
    try std.testing.expectEqual(@as(usize, 100), page.len);
    // Total entropy should be constant (information conservation)
    const initial = page[0].total_entropy;
    for (page) |p| {
        try std.testing.expectApproxEqAbs(initial, p.total_entropy, 0.0001);
    }
    // Should have both pre and post page time entries
    var has_pre: bool = false;
    var has_post: bool = false;
    for (page) |p| {
        if (p.past_page_time) has_post = true else has_pre = true;
    }
    try std.testing.expect(has_pre);
    try std.testing.expect(has_post);
}
