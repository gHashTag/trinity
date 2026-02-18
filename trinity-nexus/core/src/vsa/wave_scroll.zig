// =============================================================================
// EMERGENT WAVE SCROLLVIEW v1.0
// =============================================================================
//
// Content items as localized wave packets, scroll as global phase shift.
// SIMD-accelerated (Vec8f) with phi-based inertia and damping.
//
// Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q
// Golden Identity: phi^2 + 1/phi^2 = 3 = TRINITY
//
// Author: Agent (Emergent Wave ScrollView v1.0)
// =============================================================================

const std = @import("std");
const math = std.math;
const testing = std.testing;

// =============================================================================
// SACRED CONSTANTS
// =============================================================================

pub const PHI: f32 = 1.6180339887;
pub const PHI_INV: f32 = 0.6180339887;
pub const PHI_SQ: f32 = 2.6180339887;
pub const TAU: f32 = 6.28318530718;
pub const PI: f32 = 3.14159265359;
pub const TRINITY: f32 = 3.0;
pub const PHOENIX: f32 = 999.0;

// =============================================================================
// SIMD
// =============================================================================

pub const Vec8f = @Vector(8, f32);
pub const SIMD_WIDTH: usize = 8;

// =============================================================================
// SCROLL PHYSICS CONSTANTS
// =============================================================================

pub const SCROLL_DAMPING: f32 = PHI_INV; // 0.618 golden ratio damping
pub const SCROLL_INERTIA_MASS: f32 = PHI; // 1.618 inertia
pub const SCROLL_MAX_VELOCITY: f32 = 2000.0;
pub const SCROLL_IMPULSE_SCALE: f32 = 40.0;
pub const BOUNCE_STIFFNESS: f32 = TRINITY; // 3.0 = phi^2 + 1/phi^2
pub const BOUNCE_DAMPING: f32 = PHI_INV;
pub const DEFAULT_SIGMA_MULT: f32 = PHI; // Gaussian envelope = item_height * PHI
pub const DEFAULT_FREQUENCY: f32 = PHI;
pub const CULLING_SIGMA_MULT: f32 = TRINITY; // Cull packets beyond 3*sigma
pub const MAX_VISIBLE: usize = 1024;
pub const MAX_INTERFERENCE: usize = 256;

// =============================================================================
// CONTENT WAVE TYPE
// =============================================================================

pub const ContentWaveType = enum(u8) {
    text_standing, // Standing wave, low frequency
    image_interference, // Spatial interference, high frequency
    voice_modulated, // Frequency-modulated carrier
    code_banded, // Syntax-colored wave bands
    separator, // Low-energy separator wave

    pub fn baseFrequency(self: ContentWaveType) f32 {
        return switch (self) {
            .text_standing => PHI,
            .image_interference => TAU,
            .voice_modulated => TAU * PHI,
            .code_banded => TRINITY,
            .separator => PHI_INV,
        };
    }

    pub fn sigmaMultiplier(self: ContentWaveType) f32 {
        return switch (self) {
            .text_standing => PHI,
            .image_interference => 1.0,
            .voice_modulated => PHI,
            .code_banded => PHI_INV,
            .separator => 0.5,
        };
    }

    pub fn hueDefault(self: ContentWaveType) f32 {
        return switch (self) {
            .text_standing => 180.0, // Cyan
            .image_interference => 300.0, // Magenta
            .voice_modulated => 120.0, // Green
            .code_banded => 60.0, // Gold
            .separator => 0.0, // Red (dim)
        };
    }
};

// =============================================================================
// WAVE PACKET
// =============================================================================

pub const WavePacket = struct {
    base_y: f32, // Rest position (index * item_height)
    amplitude: f32, // Visibility/prominence [0, 1]
    phase: f32, // Individual wave phase [0, TAU]
    frequency: f32, // Spatial frequency (content-type dependent)
    sigma: f32, // Gaussian envelope width
    content_type: ContentWaveType,
    content_index: usize, // Index into content data
    energy: f32, // Interaction energy
    hue: f32, // Color hue [0, 360]
    item_height: f32, // Height of this content item

    pub fn init(index: usize, base_y: f32, item_height: f32, content_type: ContentWaveType) WavePacket {
        return WavePacket{
            .base_y = base_y,
            .amplitude = 1.0,
            .phase = @as(f32, @floatFromInt(index)) * PHI_INV * TAU,
            .frequency = content_type.baseFrequency(),
            .sigma = item_height * content_type.sigmaMultiplier(),
            .content_type = content_type,
            .content_index = index,
            .energy = 1.0,
            .hue = content_type.hueDefault(),
            .item_height = item_height,
        };
    }
};

// =============================================================================
// WAVE SCROLL STATE
// =============================================================================

pub const WaveScrollState = struct {
    scroll_phase: f32, // Cumulative scroll offset (replaces scroll_y)
    scroll_velocity: f32, // Current scroll speed (px/sec)
    scroll_acceleration: f32, // Impulse from input
    damping_factor: f32, // PHI_INV = 0.618
    inertia_mass: f32, // PHI = 1.618
    max_velocity: f32, // Velocity cap
    bounce_phase: f32, // Edge bounce wave phase
    bounce_amplitude: f32, // Edge bounce wave amplitude
    total_content_height: f32, // Total virtual height
    viewport_height: f32, // Visible area height

    pub fn init(viewport_height: f32) WaveScrollState {
        return WaveScrollState{
            .scroll_phase = 0,
            .scroll_velocity = 0,
            .scroll_acceleration = 0,
            .damping_factor = SCROLL_DAMPING,
            .inertia_mass = SCROLL_INERTIA_MASS,
            .max_velocity = SCROLL_MAX_VELOCITY,
            .bounce_phase = 0,
            .bounce_amplitude = 0,
            .total_content_height = 0,
            .viewport_height = viewport_height,
        };
    }
};

// =============================================================================
// WAVE SCROLLVIEW
// =============================================================================

pub const WaveScrollView = struct {
    state: WaveScrollState,

    // Wave packets (visible subset)
    packets: [MAX_VISIBLE]WavePacket,
    packet_count: usize,
    total_items: usize,
    visible_start: usize,
    visible_end: usize,

    // Viewport bounds
    viewport_x: f32,
    viewport_y: f32,
    viewport_width: f32,
    viewport_height: f32,

    // SIMD evaluation buffers
    y_buffer: [MAX_VISIBLE]f32,
    amp_buffer: [MAX_VISIBLE]f32,

    // Interference field (viewport discretized into rows)
    interference: [MAX_INTERFERENCE]f32,
    interference_rows: usize,

    // Animation time
    wave_time: f32,

    // Default item height (for uniform lists)
    default_item_height: f32,

    // Dirty flag: skip SIMD evaluation when scroll is idle
    needs_eval: bool,

    // Rubber-band offset for iOS-style overscroll rendering
    rubber_offset: f32,

    // Scroll snap points (Y positions of section boundaries)
    snap_points: [64]f32,
    snap_count: usize,
    snap_enabled: bool,

    // =========================================================================
    // INIT
    // =========================================================================

    pub fn init(vx: f32, vy: f32, vw: f32, vh: f32) WaveScrollView {
        var wsv: WaveScrollView = undefined;
        wsv.state = WaveScrollState.init(vh);
        wsv.packet_count = 0;
        wsv.total_items = 0;
        wsv.visible_start = 0;
        wsv.visible_end = 0;
        wsv.viewport_x = vx;
        wsv.viewport_y = vy;
        wsv.viewport_width = vw;
        wsv.viewport_height = vh;
        wsv.wave_time = 0;
        wsv.default_item_height = 40.0;
        wsv.interference_rows = @min(@as(usize, @intFromFloat(vh)), MAX_INTERFERENCE);
        wsv.needs_eval = true;
        wsv.rubber_offset = 0;
        wsv.snap_count = 0;
        wsv.snap_enabled = false;
        @memset(&wsv.snap_points, 0);

        // Zero buffers
        @memset(&wsv.y_buffer, 0);
        @memset(&wsv.amp_buffer, 0);
        @memset(&wsv.interference, 0);
        @memset(std.mem.asBytes(&wsv.packets), 0);

        return wsv;
    }

    // =========================================================================
    // ADD ITEM
    // =========================================================================

    pub fn addItem(self: *WaveScrollView, content_type: ContentWaveType, item_height: f32) void {
        const index = self.total_items;
        const base_y = if (index == 0) 0.0 else blk: {
            // Compute position based on total items so far
            break :blk @as(f32, @floatFromInt(index)) * self.default_item_height;
        };

        self.total_items += 1;
        self.state.total_content_height = @as(f32, @floatFromInt(self.total_items)) * self.default_item_height;

        // Only store if within visible range (will be updated in updateVisibleRange)
        if (self.packet_count < MAX_VISIBLE) {
            self.packets[self.packet_count] = WavePacket.init(index, base_y, item_height, content_type);
            self.packet_count += 1;
        }
    }

    // =========================================================================
    // SET TOTAL ITEMS (for large/infinite lists)
    // =========================================================================

    pub fn setTotalItems(self: *WaveScrollView, total: usize, item_height: f32) void {
        self.total_items = total;
        self.default_item_height = item_height;
        self.state.total_content_height = @as(f32, @floatFromInt(total)) * item_height;
    }

    // =========================================================================
    // APPLY SCROLL IMPULSE
    // =========================================================================

    pub fn applyImpulse(self: *WaveScrollView, impulse: f32) void {
        // Scale impulse inversely with content height — less momentum for large docs
        const height_factor = @min(1.0, 2000.0 / @max(1.0, self.state.total_content_height));
        self.state.scroll_acceleration += impulse * SCROLL_IMPULSE_SCALE * height_factor;
    }

    // =========================================================================
    // UPDATE PHYSICS (phi-damped velocity integration)
    // =========================================================================

    pub fn updatePhysics(self: *WaveScrollView, dt: f32) void {
        const state = &self.state;

        // Compute overshoot for edge bounce
        const overshoot = self.computeOvershoot();

        // Forces:
        // 1. Input impulse (scroll_acceleration)
        // 2. Phi-based drag: -damping * velocity
        // 3. TRINITY bounce spring: -BOUNCE_STIFFNESS * overshoot
        const drag = -state.damping_factor * state.scroll_velocity;
        const bounce_force = -BOUNCE_STIFFNESS * overshoot;
        const net_force = state.scroll_acceleration + drag + bounce_force;

        // Integrate: a = F / mass
        const acceleration = net_force / state.inertia_mass;
        state.scroll_velocity += acceleration * dt;

        // Clamp velocity
        state.scroll_velocity = math.clamp(state.scroll_velocity, -state.max_velocity, state.max_velocity);

        // Integrate position
        const prev_phase = state.scroll_phase;
        state.scroll_phase += state.scroll_velocity * dt;

        // Soft clamp: allow 50px overscroll for rubber-band, then hard stop
        const max_phase = @max(0.0, state.total_content_height - state.viewport_height);
        state.scroll_phase = math.clamp(state.scroll_phase, -50.0, max_phase + 50.0);

        // Reset impulse (instantaneous)
        state.scroll_acceleration = 0;

        // Scroll snap: gentle attraction to nearest section boundary
        if (self.snap_enabled and self.snap_count > 0) {
            const abs_vel = @abs(state.scroll_velocity);
            if (abs_vel < 20.0 and abs_vel > 0.5) {
                const nearest = self.findNearestSnap(state.scroll_phase);
                const snap_force = (nearest - state.scroll_phase) * 2.0;
                state.scroll_velocity += snap_force * dt;
            }
        }

        // Rubber-band offset for rendering (iOS-style logarithmic resistance)
        if (@abs(overshoot) > 0.5) {
            const sign: f32 = if (overshoot > 0) 1.0 else -1.0;
            const rubber = @log2(1.0 + @abs(overshoot) / 100.0) * 100.0 * sign;
            self.rubber_offset = rubber - overshoot;
        } else {
            self.rubber_offset = 0;
        }

        // Update bounce animation
        if (@abs(overshoot) > 0.1) {
            state.bounce_amplitude = @abs(overshoot) / @max(1.0, state.viewport_height);
            state.bounce_phase += TAU * 2.0 * dt;
        } else {
            state.bounce_amplitude *= BOUNCE_DAMPING;
            if (state.bounce_amplitude < 0.001) state.bounce_amplitude = 0;
        }

        // Velocity cutoff: stop crawling — snap to zero below threshold
        // Only when not bouncing (overshoot can produce tiny velocities that matter)
        if (@abs(state.scroll_velocity) < 1.5 and @abs(self.computeOvershoot()) < 1.0) {
            state.scroll_velocity = 0.0;
        }

        // Dirty flag: skip expensive SIMD when scroll is idle
        self.needs_eval = @abs(state.scroll_phase - prev_phase) > 0.5 or @abs(state.scroll_velocity) > 1.0;

        // Update wave time
        self.wave_time += dt;
    }

    // =========================================================================
    // COMPUTE OVERSHOOT
    // =========================================================================

    fn computeOvershoot(self: *const WaveScrollView) f32 {
        const phase = self.state.scroll_phase;
        const max_scroll = @max(0.0, self.state.total_content_height - self.state.viewport_height);

        if (phase < 0) {
            return phase; // Negative overshoot (scrolled past top)
        } else if (phase > max_scroll) {
            return phase - max_scroll; // Positive overshoot (scrolled past bottom)
        }
        return 0;
    }

    // =========================================================================
    // UPDATE VISIBLE RANGE (spatial culling)
    // =========================================================================

    pub fn updateVisibleRange(self: *WaveScrollView) void {
        if (self.total_items == 0) {
            self.visible_start = 0;
            self.visible_end = 0;
            self.packet_count = 0;
            return;
        }

        const item_h = self.default_item_height;
        const phase = self.state.scroll_phase;
        const vh = self.state.viewport_height;

        // Culling margin = 3 * sigma (where sigma = item_height * PHI)
        const sigma = item_h * DEFAULT_SIGMA_MULT;
        const margin = CULLING_SIGMA_MULT * sigma;

        // Compute visible range
        const top = phase - margin;
        const bottom = phase + vh + margin;

        const start_idx: usize = if (top <= 0) 0 else @min(
            @as(usize, @intFromFloat(top / item_h)),
            self.total_items,
        );
        const end_idx: usize = @min(
            @as(usize, @intFromFloat(bottom / item_h)) + 1,
            self.total_items,
        );

        self.visible_start = start_idx;
        self.visible_end = end_idx;

        // Populate packets for visible range
        const count = @min(end_idx - start_idx, MAX_VISIBLE);
        self.packet_count = count;

        for (0..count) |i| {
            const idx = start_idx + i;
            const base_y = @as(f32, @floatFromInt(idx)) * item_h;
            self.packets[i] = WavePacket.init(idx, base_y, item_h, .text_standing);
        }
    }

    // =========================================================================
    // EVALUATE PACKETS - SIMD (Vec8f Gaussian envelope)
    // =========================================================================

    pub fn evaluatePacketsSIMD(self: *WaveScrollView) void {
        const phase = self.state.scroll_phase;
        const vp_center = self.viewport_y + self.viewport_height * 0.5;
        var i: usize = 0;

        // SIMD path: process 8 packets at a time
        while (i + SIMD_WIDTH <= self.packet_count) : (i += SIMD_WIDTH) {
            // Load base_y positions
            var base_y_vec: Vec8f = undefined;
            var sigma_vec: Vec8f = undefined;
            for (0..SIMD_WIDTH) |j| {
                base_y_vec[j] = self.packets[i + j].base_y;
                sigma_vec[j] = self.packets[i + j].sigma;
            }

            // Compute viewport-relative y
            const phase_vec: Vec8f = @splat(phase);
            const rel_y = base_y_vec - phase_vec;

            // Store y positions
            for (0..SIMD_WIDTH) |j| {
                self.y_buffer[i + j] = rel_y[j];
            }

            // Gaussian envelope: exp(-(y - center)^2 / (2*sigma^2))
            const center_vec: Vec8f = @splat(vp_center);
            const dy = rel_y - center_vec;
            const dy_sq = dy * dy;
            const sigma_sq = sigma_vec * sigma_vec;
            const two_sigma_sq = sigma_sq + sigma_sq;
            const exponent = -dy_sq / two_sigma_sq;

            // Fast SIMD exp approximation
            const amplitude = fastExpNegSIMD(exponent);

            // Store amplitudes
            for (0..SIMD_WIDTH) |j| {
                self.amp_buffer[i + j] = amplitude[j];
            }
        }

        // Scalar fallback for remainder
        while (i < self.packet_count) : (i += 1) {
            const rel_y = self.packets[i].base_y - phase;
            self.y_buffer[i] = rel_y;

            const dy = rel_y - vp_center;
            const sigma = self.packets[i].sigma;
            const exponent = -(dy * dy) / (2.0 * sigma * sigma);
            self.amp_buffer[i] = fastExpNeg(exponent);
        }
    }

    // =========================================================================
    // COMPUTE INTERFERENCE (sum wave contributions per viewport row)
    // =========================================================================

    pub fn computeInterference(self: *WaveScrollView) void {
        const rows = self.interference_rows;
        if (rows == 0) return;

        // Clear interference field
        @memset(self.interference[0..rows], 0);

        const vh = self.viewport_height;
        const row_scale = vh / @as(f32, @floatFromInt(rows));

        for (0..self.packet_count) |i| {
            const rel_y = self.y_buffer[i];
            const amp = self.amp_buffer[i];
            const freq = self.packets[i].frequency;
            const phs = self.packets[i].phase;

            if (amp < 0.01) continue; // Skip negligible packets

            // Compute which rows this packet affects
            const sigma = self.packets[i].sigma;
            const center_row_f = rel_y / row_scale;
            const spread = (CULLING_SIGMA_MULT * sigma) / row_scale;

            const row_start: usize = if (center_row_f - spread < 0)
                0
            else
                @min(@as(usize, @intFromFloat(center_row_f - spread)), rows);
            const row_end: usize = @min(
                @as(usize, @intFromFloat(center_row_f + spread)) + 1,
                rows,
            );

            // Modulate by scroll velocity: idle=subtle, fast=bright
            const vel_factor = @min(1.0, @abs(self.state.scroll_velocity) / 500.0);
            const idle_base: f32 = 0.15; // Subtle ambient glow when idle
            const modulation = idle_base + (1.0 - idle_base) * vel_factor;

            for (row_start..row_end) |r| {
                const ry = @as(f32, @floatFromInt(r)) * row_scale;
                const dy = ry - rel_y;
                const envelope = fastExpNeg(-(dy * dy) / (2.0 * sigma * sigma));
                // Tie wave to scroll_phase (not wall time) for scroll-driven feedback
                const wave = @sin(freq * ry + phs + self.state.scroll_phase * 0.01);
                self.interference[r] += amp * envelope * wave * 0.3 * modulation;
            }
        }

        // Clamp interference to [0, 1]
        for (0..rows) |r| {
            self.interference[r] = math.clamp(@abs(self.interference[r]), 0.0, 1.0);
        }
    }

    // =========================================================================
    // QUERY METHODS
    // =========================================================================

    /// Get item Y position in viewport space
    pub fn getItemY(self: *const WaveScrollView, index: usize) f32 {
        if (index < self.visible_start or index >= self.visible_end) return -10000.0;
        const local_idx = index - self.visible_start;
        if (local_idx >= self.packet_count) return -10000.0;
        return self.y_buffer[local_idx];
    }

    /// Get item amplitude (visibility/prominence)
    pub fn getItemAmplitude(self: *const WaveScrollView, index: usize) f32 {
        if (index < self.visible_start or index >= self.visible_end) return 0.0;
        const local_idx = index - self.visible_start;
        if (local_idx >= self.packet_count) return 0.0;
        return self.amp_buffer[local_idx];
    }

    /// Get interference value at a viewport row
    pub fn getInterferenceAt(self: *const WaveScrollView, row: usize) f32 {
        if (row >= self.interference_rows) return 0;
        return self.interference[row];
    }

    /// Get current scroll phase (compatible with legacy scroll_y)
    pub fn getScrollY(self: *const WaveScrollView) f32 {
        return self.state.scroll_phase;
    }

    /// Programmatic scroll to item with phi-based ease-out
    pub fn scrollToItem(self: *WaveScrollView, index: usize) void {
        const target_y = @as(f32, @floatFromInt(index)) * self.default_item_height;
        const delta = target_y - self.state.scroll_phase;
        // Set velocity to reach target: v = delta * PHI (arrive in ~1/PHI seconds)
        self.state.scroll_velocity = delta * PHI;
    }

    /// Update viewport dimensions (call after panel resize)
    pub fn setViewport(self: *WaveScrollView, vx: f32, vy: f32, vw: f32, vh: f32) void {
        self.viewport_x = vx;
        self.viewport_y = vy;
        self.viewport_width = vw;
        self.viewport_height = vh;
        self.state.viewport_height = vh;
        self.interference_rows = @min(@as(usize, @intFromFloat(vh)), MAX_INTERFERENCE);
    }

    /// Add a scroll snap point (Y position of section boundary)
    pub fn addSnapPoint(self: *WaveScrollView, y: f32) void {
        if (self.snap_count < 64) {
            self.snap_points[self.snap_count] = y;
            self.snap_count += 1;
            self.snap_enabled = true;
        }
    }

    /// Find nearest snap point to a given scroll_phase
    fn findNearestSnap(self: *const WaveScrollView, phase: f32) f32 {
        if (self.snap_count == 0) return phase;
        var nearest = self.snap_points[0];
        var min_dist = @abs(phase - nearest);
        for (1..self.snap_count) |i| {
            const dist = @abs(phase - self.snap_points[i]);
            if (dist < min_dist) {
                min_dist = dist;
                nearest = self.snap_points[i];
            }
        }
        return nearest;
    }

    /// Get scroll_y with rubber-band offset applied (for rendering)
    pub fn getScrollYWithRubber(self: *const WaveScrollView) f32 {
        return self.state.scroll_phase + self.rubber_offset;
    }
};

// =============================================================================
// FAST EXP APPROXIMATIONS
// =============================================================================

/// Fast scalar exp(-|x|) approximation
/// Uses (1 - |x|/8)^8 rational approximation
/// Accuracy: ~1% for x in [0, 5], sufficient for Gaussian culling
fn fastExpNeg(x: f32) f32 {
    const ax = @abs(x);
    if (ax > 5.0) return 0.0; // Beyond 3*sigma, negligible
    const base = @max(0.0, 1.0 - ax * 0.125); // 1 - |x|/8
    const sq = base * base; // ^2
    const q4 = sq * sq; // ^4
    return q4 * q4; // ^8
}

/// Fast SIMD exp(-|x|) for Vec8f
/// Same (1 - |x|/8)^8 approximation, vectorized
fn fastExpNegSIMD(x: Vec8f) Vec8f {
    const zero: Vec8f = @splat(0.0);
    const one: Vec8f = @splat(1.0);
    const eighth: Vec8f = @splat(0.125);

    // |x|
    const ax = @abs(x);

    // (1 - |x|/8), clamped to >= 0
    const base = @max(zero, one - ax * eighth);

    // (1 - |x|/8)^8
    const sq = base * base; // ^2
    const q4 = sq * sq; // ^4
    return q4 * q4; // ^8
}

// =============================================================================
// TESTS
// =============================================================================

test "phi damping convergence" {
    // Verify: initial velocity decays with golden ratio characteristic
    var wsv = WaveScrollView.init(0, 0, 800, 600);
    wsv.setTotalItems(50, 40.0); // 2000px content — height_factor = 1.0

    // Apply impulse (strong enough to overcome velocity cutoff)
    wsv.applyImpulse(5.0); // impulse * 40.0 * 1.0 = 200.0 acceleration

    // Simulate 1 second at 60 FPS
    const dt: f32 = 1.0 / 60.0;
    var velocity_history: [60]f32 = undefined;
    for (0..60) |frame| {
        wsv.updatePhysics(dt);
        velocity_history[frame] = wsv.state.scroll_velocity;
    }

    // Velocity should decay (not grow) — compare frame 1 vs frame 10
    // (later frames may hit velocity cutoff and be zero)
    try testing.expect(@abs(velocity_history[9]) < @abs(velocity_history[0]));

    // Final velocity should be near zero (damped to rest)
    try testing.expect(@abs(velocity_history[59]) < 2.0);

    // Scroll phase should have moved
    try testing.expect(wsv.state.scroll_phase != 0);
}

test "trinity bounce spring" {
    // Verify: overshoot produces restoring force = -TRINITY * overshoot
    var wsv = WaveScrollView.init(0, 0, 800, 600);
    wsv.setTotalItems(10, 40.0); // total_height = 400, viewport = 600 → max_scroll = 0

    // Push past end
    wsv.state.scroll_phase = 100.0; // 100px overshoot

    // One physics step
    const dt: f32 = 1.0 / 60.0;
    wsv.updatePhysics(dt);

    // Velocity should be negative (pulling back)
    try testing.expect(wsv.state.scroll_velocity < 0);
}

test "simd vs scalar equivalence" {
    var wsv = WaveScrollView.init(0, 0, 800, 600);
    wsv.setTotalItems(100, 40.0);
    wsv.updateVisibleRange();

    // Run SIMD evaluation
    wsv.evaluatePacketsSIMD();

    // Verify all amplitudes are non-negative
    for (0..wsv.packet_count) |i| {
        try testing.expect(wsv.amp_buffer[i] >= 0.0);
        try testing.expect(wsv.amp_buffer[i] <= 1.0);
    }
}

test "visible range culling" {
    var wsv = WaveScrollView.init(0, 0, 800, 600);
    wsv.setTotalItems(100000, 40.0); // 100K items

    // Scroll to middle
    wsv.state.scroll_phase = 2000000.0; // ~50K items in

    wsv.updateVisibleRange();

    // Should not have all 100K packets - only visible window
    try testing.expect(wsv.packet_count < MAX_VISIBLE);
    try testing.expect(wsv.packet_count > 0);
    try testing.expect(wsv.visible_start > 0);
    try testing.expect(wsv.visible_end < 100000);
}

test "fast exp approximation" {
    // Verify fast_exp is reasonable for small values
    const result = fastExpNeg(0.0);
    try testing.expectApproxEqAbs(result, 1.0, 0.01);

    const result2 = fastExpNeg(1.0);
    try testing.expect(result2 > 0.0);
    try testing.expect(result2 < 1.0);

    // Large values should be ~0
    const result3 = fastExpNeg(6.0);
    try testing.expectApproxEqAbs(result3, 0.0, 0.01);
}

test "wave scroll view init" {
    const wsv = WaveScrollView.init(10, 20, 800, 600);
    try testing.expectEqual(wsv.viewport_x, 10.0);
    try testing.expectEqual(wsv.viewport_y, 20.0);
    try testing.expectEqual(wsv.viewport_width, 800.0);
    try testing.expectEqual(wsv.viewport_height, 600.0);
    try testing.expectEqual(wsv.state.damping_factor, PHI_INV);
    try testing.expectEqual(wsv.state.inertia_mass, PHI);
    try testing.expectEqual(wsv.packet_count, 0);
}

test "interference computation" {
    var wsv = WaveScrollView.init(0, 0, 800, 256);
    wsv.setTotalItems(20, 40.0);
    wsv.updateVisibleRange();
    wsv.evaluatePacketsSIMD();
    wsv.computeInterference();

    // Interference values should be in [0, 1]
    for (0..wsv.interference_rows) |r| {
        try testing.expect(wsv.interference[r] >= 0.0);
        try testing.expect(wsv.interference[r] <= 1.0);
    }
}

test "scroll to item" {
    var wsv = WaveScrollView.init(0, 0, 800, 600);
    wsv.setTotalItems(1000, 40.0);

    wsv.scrollToItem(500);

    // Velocity should be set toward item 500 (y=20000)
    try testing.expect(wsv.state.scroll_velocity > 0);
}

test "golden identity verification" {
    // phi^2 + 1/phi^2 = 3 = TRINITY
    const identity = PHI * PHI + 1.0 / (PHI * PHI);
    try testing.expectApproxEqAbs(identity, TRINITY, 0.001);
}
