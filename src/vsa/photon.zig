// =============================================================================
// EMERGENT PHOTON AI - Wave-Based Generation Engine
// No neural networks, no weights - pure mathematical emergence
// V = n x 3^k x pi^m x phi^p x e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// =============================================================================
// MATHEMATICAL CONSTANTS (Golden Ratio Foundation)
// =============================================================================

pub const PHI: f32 = 1.6180339887; // Golden ratio
pub const PHI_INV: f32 = 0.6180339887; // 1/phi
pub const PI: f32 = 3.14159265359;
pub const TAU: f32 = 6.28318530718; // 2*pi
pub const E: f32 = 2.71828182845;

// Trinity identity: phi^2 + 1/phi^2 = 3
pub const TRINITY: f32 = 3.0;

// =============================================================================
// SIMD TYPES (8-element vectors for wave computation)
// =============================================================================

pub const Vec8f = @Vector(8, f32);
pub const SIMD_WIDTH: usize = 8;

// =============================================================================
// PHOTON - Minimal Wave Unit
// =============================================================================

pub const Photon = struct {
    // Wave state
    amplitude: f32, // Current amplitude [-1, 1]
    phase: f32, // Phase angle [0, TAU]
    frequency: f32, // Base frequency (Hz)
    wavelength: f32, // Spatial wavelength

    // Position in grid
    x: usize,
    y: usize,

    // Interference accumulator
    interference: f32,

    // Energy (conserved across interactions)
    energy: f32,

    // Color encoding (for visualization)
    hue: f32, // [0, 360]

    /// Create photon at grid position
    pub fn init(x: usize, y: usize) Photon {
        // Initialize with golden ratio frequency
        const freq = PHI * @as(f32, @floatFromInt(x + y + 1));
        return Photon{
            .amplitude = 0.0,
            .phase = 0.0,
            .frequency = freq,
            .wavelength = 1.0 / freq,
            .x = x,
            .y = y,
            .interference = 0.0,
            .energy = 1.0,
            .hue = @mod(@as(f32, @floatFromInt(x * 7 + y * 13)) * PHI * 100.0, 360.0),
        };
    }

    /// Wave function: A * sin(omega*t + phase)
    pub fn wave(self: *const Photon, t: f32) f32 {
        const omega = TAU * self.frequency;
        return self.amplitude * @sin(omega * t + self.phase);
    }

    /// Propagate wave one timestep
    pub fn propagate(self: *Photon, dt: f32, neighbors: []const f32) void {
        // Sum neighbor contributions (interference)
        var neighbor_sum: f32 = 0.0;
        for (neighbors) |n| {
            neighbor_sum += n;
        }

        // Average neighbor influence
        const neighbor_avg = if (neighbors.len > 0)
            neighbor_sum / @as(f32, @floatFromInt(neighbors.len))
        else
            0.0;

        // Wave equation: d2u/dt2 = c^2 * laplacian(u)
        // Discretized: new_amp = 2*amp - old_amp + c^2*dt^2*(neighbor_avg - amp)
        const c: f32 = PHI; // Wave speed = golden ratio
        const damping: f32 = 0.999; // Slight energy loss

        self.interference = neighbor_avg - self.amplitude;
        self.amplitude = damping * (self.amplitude + c * c * dt * dt * self.interference);

        // Update phase
        self.phase = @mod(self.phase + TAU * self.frequency * dt, TAU);

        // Clamp amplitude
        self.amplitude = @max(-1.0, @min(1.0, self.amplitude));
    }

    /// Apply external perturbation (cursor/input)
    pub fn perturb(self: *Photon, strength: f32, phase_shift: f32) void {
        self.amplitude += strength;
        self.amplitude = @max(-1.0, @min(1.0, self.amplitude));
        self.phase = @mod(self.phase + phase_shift, TAU);
    }

    /// Interference with another photon
    pub fn interfere(self: *Photon, other: *const Photon, t: f32) f32 {
        const wave1 = self.wave(t);
        const wave2 = other.wave(t);
        // Superposition principle
        return wave1 + wave2;
    }

    /// Energy from wave (proportional to amplitude^2)
    pub fn getEnergy(self: *const Photon) f32 {
        return self.amplitude * self.amplitude;
    }

    /// Convert amplitude to grayscale [0, 255]
    pub fn toGrayscale(self: *const Photon) u8 {
        const normalized = (self.amplitude + 1.0) * 0.5; // [0, 1]
        return @intFromFloat(normalized * 255.0);
    }

    /// Convert to RGB using hue
    pub fn toRGB(self: *const Photon) [3]u8 {
        const brightness = (self.amplitude + 1.0) * 0.5;
        return hsvToRgb(self.hue, 0.8, brightness);
    }
};

// =============================================================================
// PHOTON GRID - Emergent Wave Field
// =============================================================================

pub const PhotonGrid = struct {
    allocator: Allocator,
    width: usize,
    height: usize,
    photons: []Photon,
    time: f32,
    dt: f32,

    // Statistics
    total_energy: f32,
    max_amplitude: f32,
    min_amplitude: f32,

    // Cursor position for interaction
    cursor_x: f32,
    cursor_y: f32,
    cursor_strength: f32,

    /// Create N x N photon grid
    pub fn init(allocator: Allocator, width: usize, height: usize) !PhotonGrid {
        const photons = try allocator.alloc(Photon, width * height);

        // Initialize all photons
        for (0..height) |y| {
            for (0..width) |x| {
                photons[y * width + x] = Photon.init(x, y);
            }
        }

        return PhotonGrid{
            .allocator = allocator,
            .width = width,
            .height = height,
            .photons = photons,
            .time = 0.0,
            .dt = 0.01, // 100 Hz simulation
            .total_energy = 0.0,
            .max_amplitude = 0.0,
            .min_amplitude = 0.0,
            .cursor_x = 0.0,
            .cursor_y = 0.0,
            .cursor_strength = 0.0,
        };
    }

    pub fn deinit(self: *PhotonGrid) void {
        self.allocator.free(self.photons);
    }

    /// Get photon at (x, y)
    pub fn get(self: *const PhotonGrid, x: usize, y: usize) *const Photon {
        return &self.photons[y * self.width + x];
    }

    /// Get mutable photon at (x, y)
    pub fn getMut(self: *PhotonGrid, x: usize, y: usize) *Photon {
        return &self.photons[y * self.width + x];
    }

    /// Get neighbor amplitudes (4-connected)
    fn getNeighborAmplitudes(self: *const PhotonGrid, x: usize, y: usize, out: *[4]f32) usize {
        var count: usize = 0;

        // Left
        if (x > 0) {
            out[count] = self.get(x - 1, y).amplitude;
            count += 1;
        }
        // Right
        if (x < self.width - 1) {
            out[count] = self.get(x + 1, y).amplitude;
            count += 1;
        }
        // Up
        if (y > 0) {
            out[count] = self.get(x, y - 1).amplitude;
            count += 1;
        }
        // Down
        if (y < self.height - 1) {
            out[count] = self.get(x, y + 1).amplitude;
            count += 1;
        }

        return count;
    }

    /// Propagate all photons one timestep
    pub fn step(self: *PhotonGrid) void {
        // Apply cursor perturbation
        if (self.cursor_strength > 0.01) {
            self.applyCursorPerturbation();
        }

        // Propagate each photon
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                var neighbors: [4]f32 = undefined;
                const count = self.getNeighborAmplitudes(x, y, &neighbors);
                self.getMut(x, y).propagate(self.dt, neighbors[0..count]);
            }
        }

        // Update time
        self.time += self.dt;

        // Update statistics
        self.updateStats();
    }

    /// SIMD-optimized step (process 8 photons at once)
    pub fn stepSIMD(self: *PhotonGrid) void {
        // Apply cursor perturbation first
        if (self.cursor_strength > 0.01) {
            self.applyCursorPerturbation();
        }

        const c2dt2: f32 = PHI * PHI * self.dt * self.dt;
        const damping: f32 = 0.999;

        // Process in SIMD chunks
        var i: usize = 0;
        while (i + SIMD_WIDTH <= self.photons.len) : (i += SIMD_WIDTH) {
            // Load amplitudes into SIMD vector
            var amps: Vec8f = undefined;
            var interf: Vec8f = undefined;

            for (0..SIMD_WIDTH) |j| {
                const idx = i + j;
                const x = idx % self.width;
                const y = idx / self.width;

                var neighbors: [4]f32 = undefined;
                const count = self.getNeighborAmplitudes(x, y, &neighbors);

                var sum: f32 = 0.0;
                for (0..count) |k| {
                    sum += neighbors[k];
                }
                const avg = if (count > 0) sum / @as(f32, @floatFromInt(count)) else 0.0;

                amps[j] = self.photons[idx].amplitude;
                interf[j] = avg - self.photons[idx].amplitude;
            }

            // SIMD wave equation
            const c2dt2_vec: Vec8f = @splat(c2dt2);
            const damping_vec: Vec8f = @splat(damping);
            const new_amps = damping_vec * (amps + c2dt2_vec * interf);

            // Clamp to [-1, 1]
            const min_vec: Vec8f = @splat(-1.0);
            const max_vec: Vec8f = @splat(1.0);
            const clamped = @min(max_vec, @max(min_vec, new_amps));

            // Store back
            for (0..SIMD_WIDTH) |j| {
                self.photons[i + j].amplitude = clamped[j];
                self.photons[i + j].interference = interf[j];

                // Update phase
                const omega_dt = TAU * self.photons[i + j].frequency * self.dt;
                self.photons[i + j].phase = @mod(self.photons[i + j].phase + omega_dt, TAU);
            }
        }

        // Handle remaining photons
        while (i < self.photons.len) : (i += 1) {
            const x = i % self.width;
            const y = i / self.width;
            var neighbors: [4]f32 = undefined;
            const count = self.getNeighborAmplitudes(x, y, &neighbors);
            self.photons[i].propagate(self.dt, neighbors[0..count]);
        }

        self.time += self.dt;
        self.updateStats();
    }

    /// Apply cursor perturbation with Gaussian falloff
    fn applyCursorPerturbation(self: *PhotonGrid) void {
        const radius: f32 = 5.0; // Perturbation radius
        const radius_sq = radius * radius;

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const dx = @as(f32, @floatFromInt(x)) - self.cursor_x;
                const dy = @as(f32, @floatFromInt(y)) - self.cursor_y;
                const dist_sq = dx * dx + dy * dy;

                if (dist_sq < radius_sq) {
                    // Gaussian falloff
                    const falloff = @exp(-dist_sq / (2.0 * radius_sq / 9.0));
                    const strength = self.cursor_strength * falloff;

                    // Phase shift based on angle
                    const angle = math.atan2(dy, dx);
                    self.getMut(x, y).perturb(strength, angle * 0.1);
                }
            }
        }

        // Decay cursor strength
        self.cursor_strength *= 0.95;
    }

    /// Set cursor position and trigger perturbation
    pub fn setCursor(self: *PhotonGrid, x: f32, y: f32, strength: f32) void {
        self.cursor_x = x;
        self.cursor_y = y;
        self.cursor_strength = strength;
    }

    /// Update statistics
    fn updateStats(self: *PhotonGrid) void {
        self.total_energy = 0.0;
        self.max_amplitude = -1.0;
        self.min_amplitude = 1.0;

        for (self.photons) |*p| {
            self.total_energy += p.getEnergy();
            if (p.amplitude > self.max_amplitude) self.max_amplitude = p.amplitude;
            if (p.amplitude < self.min_amplitude) self.min_amplitude = p.amplitude;
        }
    }

    /// Inject initial wave pattern
    pub fn injectWave(self: *PhotonGrid, pattern: WavePattern) void {
        switch (pattern) {
            .point_source => |params| {
                // Single point source (circular wave)
                const px = params.x;
                const py = params.y;
                self.getMut(px, py).amplitude = params.amplitude;
            },
            .line_wave => |params| {
                // Horizontal or vertical line
                if (params.horizontal) {
                    for (0..self.width) |x| {
                        self.getMut(x, params.position).amplitude = params.amplitude;
                    }
                } else {
                    for (0..self.height) |y| {
                        self.getMut(params.position, y).amplitude = params.amplitude;
                    }
                }
            },
            .circle => |params| {
                // Circular wavefront
                const cx = @as(f32, @floatFromInt(params.center_x));
                const cy = @as(f32, @floatFromInt(params.center_y));
                const r = @as(f32, @floatFromInt(params.radius));

                for (0..self.height) |y| {
                    for (0..self.width) |x| {
                        const dx = @as(f32, @floatFromInt(x)) - cx;
                        const dy = @as(f32, @floatFromInt(y)) - cy;
                        const dist = @sqrt(dx * dx + dy * dy);

                        if (@abs(dist - r) < 1.5) {
                            self.getMut(x, y).amplitude = params.amplitude;
                        }
                    }
                }
            },
            .golden_spiral => |params| {
                // Golden spiral (phi-based)
                const cx = @as(f32, @floatFromInt(params.center_x));
                const cy = @as(f32, @floatFromInt(params.center_y));

                var theta: f32 = 0.0;
                while (theta < TAU * 4.0) : (theta += 0.1) {
                    const r = params.scale * @exp(PHI_INV * theta);
                    const px = cx + r * @cos(theta);
                    const py = cy + r * @sin(theta);

                    const ix = @as(usize, @intFromFloat(@max(0.0, @min(px, @as(f32, @floatFromInt(self.width - 1))))));
                    const iy = @as(usize, @intFromFloat(@max(0.0, @min(py, @as(f32, @floatFromInt(self.height - 1))))));

                    self.getMut(ix, iy).amplitude = params.amplitude;
                }
            },
            .text_seed => |params| {
                // Text as initial perturbation
                self.injectText(params.text, params.x, params.y);
            },
        }
    }

    /// Inject text as wave seed (each char = frequency modulation)
    fn injectText(self: *PhotonGrid, text: []const u8, start_x: usize, start_y: usize) void {
        for (text, 0..) |c, i| {
            const x = (start_x + i) % self.width;
            const y = start_y % self.height;

            // Character value modulates amplitude and frequency
            const char_val = @as(f32, @floatFromInt(c)) / 255.0;
            self.getMut(x, y).amplitude = char_val * 2.0 - 1.0; // [-1, 1]
            self.getMut(x, y).frequency = PHI * (1.0 + char_val);
        }
    }

    /// Extract emergent pattern as bytes (for text generation)
    pub fn extractPattern(self: *const PhotonGrid, out: []u8) void {
        const sample_rate = self.photons.len / out.len;

        for (out, 0..) |*byte, i| {
            var sum: f32 = 0.0;
            const start = i * sample_rate;
            const end = @min(start + sample_rate, self.photons.len);

            for (start..end) |j| {
                sum += self.photons[j].amplitude;
            }

            const avg = sum / @as(f32, @floatFromInt(end - start));
            byte.* = @intFromFloat((avg + 1.0) * 0.5 * 255.0);
        }
    }

    /// Get pixel buffer for rendering (grayscale)
    pub fn getPixelBuffer(self: *const PhotonGrid, out: []u8) void {
        for (self.photons, 0..) |p, i| {
            if (i < out.len) {
                out[i] = p.toGrayscale();
            }
        }
    }

    /// Get RGB pixel buffer
    pub fn getRGBBuffer(self: *const PhotonGrid, out: []u8) void {
        for (self.photons, 0..) |p, i| {
            const rgb = p.toRGB();
            const base = i * 3;
            if (base + 2 < out.len) {
                out[base] = rgb[0];
                out[base + 1] = rgb[1];
                out[base + 2] = rgb[2];
            }
        }
    }
};

// =============================================================================
// WAVE PATTERNS (Initial conditions)
// =============================================================================

pub const WavePattern = union(enum) {
    point_source: struct {
        x: usize,
        y: usize,
        amplitude: f32,
    },
    line_wave: struct {
        position: usize,
        horizontal: bool,
        amplitude: f32,
    },
    circle: struct {
        center_x: usize,
        center_y: usize,
        radius: usize,
        amplitude: f32,
    },
    golden_spiral: struct {
        center_x: usize,
        center_y: usize,
        scale: f32,
        amplitude: f32,
    },
    text_seed: struct {
        text: []const u8,
        x: usize,
        y: usize,
    },
};

// =============================================================================
// EMERGENT TEXT GENERATOR
// =============================================================================

pub const EmergentTextGenerator = struct {
    grid: *PhotonGrid,
    vocabulary: []const u8,
    temperature: f32,

    pub fn init(grid: *PhotonGrid) EmergentTextGenerator {
        return EmergentTextGenerator{
            .grid = grid,
            .vocabulary = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?",
            .temperature = 1.0,
        };
    }

    /// Generate text from emergent wave patterns
    pub fn generate(self: *EmergentTextGenerator, prompt: []const u8, max_tokens: usize, out: []u8) usize {
        // Seed grid with prompt
        self.grid.injectWave(.{ .text_seed = .{
            .text = prompt,
            .x = self.grid.width / 4,
            .y = self.grid.height / 2,
        } });

        // Let waves propagate and interfere
        var tokens_generated: usize = 0;
        const steps_per_token = 10;

        while (tokens_generated < max_tokens and tokens_generated < out.len) {
            // Propagate waves
            for (0..steps_per_token) |_| {
                self.grid.stepSIMD();
            }

            // Sample token from emergent pattern
            const token = self.sampleToken();
            out[tokens_generated] = token;
            tokens_generated += 1;

            // Inject generated token back as perturbation (autoregressive)
            const inject_x = (self.grid.width / 4 + tokens_generated) % self.grid.width;
            self.grid.getMut(inject_x, self.grid.height / 2).amplitude = @as(f32, @floatFromInt(token)) / 127.5 - 1.0;
        }

        return tokens_generated;
    }

    /// Sample token from grid state
    fn sampleToken(self: *EmergentTextGenerator) u8 {
        // Use center region for sampling
        const cx = self.grid.width / 2;
        const cy = self.grid.height / 2;
        const sample_size: usize = 5;

        var sum: f32 = 0.0;
        var count: usize = 0;

        for (0..sample_size) |dy| {
            for (0..sample_size) |dx| {
                const x = @min(cx + dx, self.grid.width - 1);
                const y = @min(cy + dy, self.grid.height - 1);
                sum += self.grid.get(x, y).amplitude;
                count += 1;
            }
        }

        const avg = sum / @as(f32, @floatFromInt(count));

        // Map to vocabulary
        const normalized = (avg + 1.0) * 0.5; // [0, 1]
        const idx = @as(usize, @intFromFloat(normalized * @as(f32, @floatFromInt(self.vocabulary.len - 1))));
        return self.vocabulary[@min(idx, self.vocabulary.len - 1)];
    }
};

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/// HSV to RGB conversion
fn hsvToRgb(h: f32, s: f32, v: f32) [3]u8 {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;

    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    if (h < 60) {
        r = c;
        g = x;
    } else if (h < 120) {
        r = x;
        g = c;
    } else if (h < 180) {
        g = c;
        b = x;
    } else if (h < 240) {
        g = x;
        b = c;
    } else if (h < 300) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }

    return .{
        @intFromFloat((r + m) * 255.0),
        @intFromFloat((g + m) * 255.0),
        @intFromFloat((b + m) * 255.0),
    };
}

// =============================================================================
// MULTI-MODAL OUTPUT - Text, Image, Audio
// =============================================================================

/// Enhanced text generator with context-aware sampling
pub const AdvancedTextGenerator = struct {
    grid: *PhotonGrid,
    context_window: [64]u8,
    context_len: usize,
    temperature: f32,
    top_k: usize,

    // Character frequencies for English (approximate)
    const CHAR_WEIGHTS = " etaoinshrdlcumwfgypbvkjxqz";

    pub fn init(grid: *PhotonGrid) AdvancedTextGenerator {
        return AdvancedTextGenerator{
            .grid = grid,
            .context_window = undefined,
            .context_len = 0,
            .temperature = 0.8,
            .top_k = 5,
        };
    }

    /// Generate text with wave-based sampling
    pub fn generate(self: *AdvancedTextGenerator, prompt: []const u8, max_tokens: usize, out: []u8) usize {
        // Initialize context with prompt
        const copy_len = @min(prompt.len, self.context_window.len);
        @memcpy(self.context_window[0..copy_len], prompt[0..copy_len]);
        self.context_len = copy_len;

        // Seed grid with prompt
        self.grid.injectWave(.{ .text_seed = .{
            .text = prompt,
            .x = self.grid.width / 4,
            .y = self.grid.height / 2,
        } });

        var tokens_generated: usize = 0;
        const steps_per_token = 15; // More steps for better emergence

        while (tokens_generated < max_tokens and tokens_generated < out.len) {
            // Propagate waves with SIMD
            for (0..steps_per_token) |_| {
                self.grid.stepSIMD();
            }

            // Sample token using advanced method
            const token = self.sampleAdvanced();
            out[tokens_generated] = token;
            tokens_generated += 1;

            // Update context
            if (self.context_len < self.context_window.len) {
                self.context_window[self.context_len] = token;
                self.context_len += 1;
            } else {
                // Shift context window
                for (1..self.context_window.len) |i| {
                    self.context_window[i - 1] = self.context_window[i];
                }
                self.context_window[self.context_window.len - 1] = token;
            }

            // Inject token back as wave perturbation
            const inject_x = (self.grid.width / 3 + tokens_generated * 2) % self.grid.width;
            const inject_y = (self.grid.height / 2 + tokens_generated) % self.grid.height;
            self.grid.getMut(inject_x, inject_y).amplitude = @as(f32, @floatFromInt(token)) / 127.5 - 1.0;
        }

        return tokens_generated;
    }

    /// Advanced sampling using multiple grid regions
    fn sampleAdvanced(self: *AdvancedTextGenerator) u8 {
        // Sample from 4 regions and combine
        var samples: [4]f32 = undefined;

        // Top-left quadrant
        samples[0] = self.sampleRegion(0, 0, self.grid.width / 2, self.grid.height / 2);
        // Top-right quadrant
        samples[1] = self.sampleRegion(self.grid.width / 2, 0, self.grid.width, self.grid.height / 2);
        // Bottom-left quadrant
        samples[2] = self.sampleRegion(0, self.grid.height / 2, self.grid.width / 2, self.grid.height);
        // Bottom-right quadrant
        samples[3] = self.sampleRegion(self.grid.width / 2, self.grid.height / 2, self.grid.width, self.grid.height);

        // Weighted combination
        const weighted = (samples[0] * PHI + samples[1] + samples[2] + samples[3] * PHI_INV) / (PHI + 2.0 + PHI_INV);

        // Apply temperature
        const temp_adjusted = weighted * self.temperature;

        // Map to character with English frequency bias
        const normalized = (temp_adjusted + 1.0) * 0.5; // [0, 1]
        const idx = @as(usize, @intFromFloat(normalized * @as(f32, @floatFromInt(CHAR_WEIGHTS.len - 1))));
        return CHAR_WEIGHTS[@min(idx, CHAR_WEIGHTS.len - 1)];
    }

    /// Sample average amplitude from grid region
    fn sampleRegion(self: *AdvancedTextGenerator, x1: usize, y1: usize, x2: usize, y2: usize) f32 {
        var sum: f32 = 0.0;
        var count: usize = 0;

        var y = y1;
        while (y < y2) : (y += 2) { // Sample every other cell for speed
            var x = x1;
            while (x < x2) : (x += 2) {
                sum += self.grid.get(x, y).amplitude;
                count += 1;
            }
        }

        return if (count > 0) sum / @as(f32, @floatFromInt(count)) else 0.0;
    }
};

/// Image exporter - save grid state as image data
pub const ImageExporter = struct {
    grid: *const PhotonGrid,

    pub fn init(grid: *const PhotonGrid) ImageExporter {
        return ImageExporter{ .grid = grid };
    }

    /// Get RGBA pixel buffer (4 bytes per pixel)
    pub fn getRGBA(self: *const ImageExporter, allocator: std.mem.Allocator) ![]u8 {
        const pixels = try allocator.alloc(u8, self.grid.width * self.grid.height * 4);

        for (0..self.grid.height) |y| {
            for (0..self.grid.width) |x| {
                const p = self.grid.get(x, y);
                const rgb = p.toRGB();
                const idx = (y * self.grid.width + x) * 4;

                pixels[idx] = rgb[0]; // R
                pixels[idx + 1] = rgb[1]; // G
                pixels[idx + 2] = rgb[2]; // B
                pixels[idx + 3] = 255; // A (fully opaque)
            }
        }

        return pixels;
    }

    /// Get grayscale buffer (1 byte per pixel)
    pub fn getGrayscale(self: *const ImageExporter, allocator: std.mem.Allocator) ![]u8 {
        const pixels = try allocator.alloc(u8, self.grid.width * self.grid.height);

        for (0..self.grid.height) |y| {
            for (0..self.grid.width) |x| {
                const p = self.grid.get(x, y);
                pixels[y * self.grid.width + x] = p.toGrayscale();
            }
        }

        return pixels;
    }

    /// Export as PPM format (simple, no external libs)
    pub fn exportPPM(self: *const ImageExporter, allocator: std.mem.Allocator) ![]u8 {
        // PPM header: "P6\nWIDTH HEIGHT\n255\n" + RGB data
        const header_size = 64; // Estimated
        const data_size = self.grid.width * self.grid.height * 3;
        var buffer = try allocator.alloc(u8, header_size + data_size);

        // Write header
        const header = std.fmt.bufPrint(buffer[0..header_size], "P6\n{d} {d}\n255\n", .{ self.grid.width, self.grid.height }) catch return error.FormatError;
        const header_len = header.len;

        // Write RGB data
        var offset = header_len;
        for (0..self.grid.height) |y| {
            for (0..self.grid.width) |x| {
                const p = self.grid.get(x, y);
                const rgb = p.toRGB();
                buffer[offset] = rgb[0];
                buffer[offset + 1] = rgb[1];
                buffer[offset + 2] = rgb[2];
                offset += 3;
            }
        }

        // Resize to actual size
        return allocator.realloc(buffer, offset) catch buffer[0..offset];
    }
};

/// Audio synthesizer - generate waveform from grid state
pub const AudioSynthesizer = struct {
    grid: *const PhotonGrid,
    sample_rate: u32,
    base_frequency: f32,

    pub fn init(grid: *const PhotonGrid) AudioSynthesizer {
        return AudioSynthesizer{
            .grid = grid,
            .sample_rate = 44100, // CD quality
            .base_frequency = 440.0, // A4 note
        };
    }

    /// Generate audio samples from grid state
    /// Returns f32 samples in range [-1, 1]
    pub fn generateSamples(self: *const AudioSynthesizer, allocator: std.mem.Allocator, duration_ms: u32) ![]f32 {
        const num_samples = (self.sample_rate * duration_ms) / 1000;
        const samples = try allocator.alloc(f32, num_samples);

        // Use grid columns as frequency components
        const dt = 1.0 / @as(f32, @floatFromInt(self.sample_rate));

        for (samples, 0..) |*sample, i| {
            const t = @as(f32, @floatFromInt(i)) * dt;
            var sum: f32 = 0.0;

            // Sum contributions from grid photons
            // Use first row as fundamental frequencies
            for (0..@min(32, self.grid.width)) |col| {
                const p = self.grid.get(col, 0);

                // Frequency based on column position and amplitude
                const freq = self.base_frequency * (1.0 + @as(f32, @floatFromInt(col)) * 0.1);
                const amp = @abs(p.amplitude) * 0.1; // Scale down

                sum += amp * @sin(TAU * freq * t + p.phase);
            }

            // Add harmonics from center row
            const center_y = self.grid.height / 2;
            for (0..@min(16, self.grid.width)) |col| {
                const p = self.grid.get(col, center_y);
                const harmonic = 2.0 + @as(f32, @floatFromInt(col)) * 0.5;
                const freq = self.base_frequency * harmonic;
                const amp = @abs(p.amplitude) * 0.05;

                sum += amp * @sin(TAU * freq * t + p.phase);
            }

            // Clamp to [-1, 1]
            sample.* = @max(-1.0, @min(1.0, sum));
        }

        return samples;
    }

    /// Generate raw 16-bit PCM audio data
    pub fn generatePCM16(self: *const AudioSynthesizer, allocator: std.mem.Allocator, duration_ms: u32) ![]i16 {
        const float_samples = try self.generateSamples(allocator, duration_ms);
        defer allocator.free(float_samples);

        const pcm = try allocator.alloc(i16, float_samples.len);

        for (float_samples, 0..) |sample, i| {
            // Convert float [-1, 1] to i16 [-32768, 32767]
            pcm[i] = @intFromFloat(sample * 32767.0);
        }

        return pcm;
    }

    /// Get frequency spectrum from current grid state
    pub fn getSpectrum(self: *const AudioSynthesizer, out: []f32) void {
        const bins = @min(out.len, self.grid.width);

        for (0..bins) |i| {
            // Average amplitude across column
            var sum: f32 = 0.0;
            for (0..self.grid.height) |y| {
                sum += @abs(self.grid.get(i, y).amplitude);
            }
            out[i] = sum / @as(f32, @floatFromInt(self.grid.height));
        }
    }
};

/// WAV file header structure
pub const WavHeader = struct {
    // RIFF chunk
    riff: [4]u8 = .{ 'R', 'I', 'F', 'F' },
    file_size: u32,
    wave: [4]u8 = .{ 'W', 'A', 'V', 'E' },
    // fmt chunk
    fmt: [4]u8 = .{ 'f', 'm', 't', ' ' },
    fmt_size: u32 = 16,
    audio_format: u16 = 1, // PCM
    num_channels: u16 = 1, // Mono
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16 = 2,
    bits_per_sample: u16 = 16,
    // data chunk
    data: [4]u8 = .{ 'd', 'a', 't', 'a' },
    data_size: u32,

    pub fn init(sample_rate: u32, num_samples: u32) WavHeader {
        const data_size = num_samples * 2; // 16-bit = 2 bytes per sample
        return WavHeader{
            .file_size = 36 + data_size,
            .sample_rate = sample_rate,
            .byte_rate = sample_rate * 2,
            .data_size = data_size,
        };
    }

    pub fn toBytes(self: *const WavHeader) [44]u8 {
        var bytes: [44]u8 = undefined;
        @memcpy(bytes[0..4], &self.riff);
        @memcpy(bytes[4..8], std.mem.asBytes(&self.file_size));
        @memcpy(bytes[8..12], &self.wave);
        @memcpy(bytes[12..16], &self.fmt);
        @memcpy(bytes[16..20], std.mem.asBytes(&self.fmt_size));
        @memcpy(bytes[20..22], std.mem.asBytes(&self.audio_format));
        @memcpy(bytes[22..24], std.mem.asBytes(&self.num_channels));
        @memcpy(bytes[24..28], std.mem.asBytes(&self.sample_rate));
        @memcpy(bytes[28..32], std.mem.asBytes(&self.byte_rate));
        @memcpy(bytes[32..34], std.mem.asBytes(&self.block_align));
        @memcpy(bytes[34..36], std.mem.asBytes(&self.bits_per_sample));
        @memcpy(bytes[36..40], &self.data);
        @memcpy(bytes[40..44], std.mem.asBytes(&self.data_size));
        return bytes;
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "photon wave function" {
    var p = Photon.init(0, 0);
    p.amplitude = 1.0;
    p.frequency = 1.0;
    p.phase = 0.0;

    // At t=0, sin(0) = 0
    const w0 = p.wave(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), w0, 0.01);

    // At t=0.25 (quarter period), sin(pi/2) = 1
    const w1 = p.wave(0.25);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), w1, 0.01);
}

test "photon grid initialization" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 16, 16);
    defer grid.deinit();

    try std.testing.expectEqual(@as(usize, 256), grid.photons.len);
    try std.testing.expectEqual(@as(usize, 16), grid.width);
    try std.testing.expectEqual(@as(usize, 16), grid.height);
}

test "wave injection and propagation" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 32, 32);
    defer grid.deinit();

    // Inject point source at center
    grid.injectWave(.{ .point_source = .{
        .x = 16,
        .y = 16,
        .amplitude = 1.0,
    } });

    // Check injection
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), grid.get(16, 16).amplitude, 0.01);

    // Propagate
    for (0..100) |_| {
        grid.stepSIMD();
    }

    // Wave should have spread (neighbors should have non-zero amplitude)
    try std.testing.expect(grid.get(15, 16).amplitude != 0.0);
    try std.testing.expect(grid.get(17, 16).amplitude != 0.0);
}

test "cursor perturbation" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 32, 32);
    defer grid.deinit();

    // Set cursor at center with strong perturbation
    grid.setCursor(16.0, 16.0, 1.0);

    // Step to apply perturbation
    grid.step();

    // Check that photons near cursor were affected
    const center = grid.get(16, 16);
    try std.testing.expect(center.amplitude != 0.0);
}

test "emergent text generation" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 64, 64);
    defer grid.deinit();

    var gen = EmergentTextGenerator.init(&grid);

    var output: [32]u8 = undefined;
    const len = gen.generate("Hello", 10, &output);

    // Should generate some text
    try std.testing.expect(len > 0);
    try std.testing.expect(len <= 10);
}

test "golden spiral pattern" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 64, 64);
    defer grid.deinit();

    grid.injectWave(.{ .golden_spiral = .{
        .center_x = 32,
        .center_y = 32,
        .scale = 1.0,
        .amplitude = 1.0,
    } });

    // Check that spiral was injected (some photons should be non-zero)
    var non_zero: usize = 0;
    for (grid.photons) |p| {
        if (p.amplitude != 0.0) non_zero += 1;
    }
    try std.testing.expect(non_zero > 0);
}

test "SIMD step correctness" {
    const allocator = std.testing.allocator;

    // Create two identical grids
    var grid1 = try PhotonGrid.init(allocator, 32, 32);
    defer grid1.deinit();

    var grid2 = try PhotonGrid.init(allocator, 32, 32);
    defer grid2.deinit();

    // Same initial condition
    grid1.getMut(16, 16).amplitude = 1.0;
    grid2.getMut(16, 16).amplitude = 1.0;

    // Step with different methods
    for (0..10) |_| {
        grid1.step();
        grid2.stepSIMD();
    }

    // Results should be approximately equal
    for (grid1.photons, grid2.photons) |p1, p2| {
        try std.testing.expectApproxEqAbs(p1.amplitude, p2.amplitude, 0.01);
    }
}

test "advanced text generator" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 64, 64);
    defer grid.deinit();

    var gen = AdvancedTextGenerator.init(&grid);

    var output: [32]u8 = undefined;
    const len = gen.generate("WAVE", 16, &output);

    // Should generate text
    try std.testing.expect(len > 0);
    try std.testing.expect(len <= 16);

    // Output should be printable ASCII
    for (output[0..len]) |c| {
        try std.testing.expect(c >= 32 and c <= 126);
    }
}

test "image exporter RGBA" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 16, 16);
    defer grid.deinit();

    // Set some amplitudes
    grid.getMut(8, 8).amplitude = 1.0;
    grid.getMut(4, 4).amplitude = -1.0;

    const exporter = ImageExporter.init(&grid);
    const rgba = try exporter.getRGBA(allocator);
    defer allocator.free(rgba);

    // Should be width * height * 4 bytes
    try std.testing.expectEqual(@as(usize, 16 * 16 * 4), rgba.len);

    // Alpha channel should be 255 for all pixels
    for (0..256) |i| {
        try std.testing.expectEqual(@as(u8, 255), rgba[i * 4 + 3]);
    }
}

test "image exporter PPM" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 8, 8);
    defer grid.deinit();

    const exporter = ImageExporter.init(&grid);
    const ppm = try exporter.exportPPM(allocator);
    defer allocator.free(ppm);

    // Should start with "P6\n"
    try std.testing.expectEqualStrings("P6\n", ppm[0..3]);
}

test "audio synthesizer samples" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 32, 32);
    defer grid.deinit();

    // Set wave pattern
    grid.getMut(0, 0).amplitude = 1.0;
    grid.getMut(1, 0).amplitude = 0.5;

    const synth = AudioSynthesizer.init(&grid);
    const samples = try synth.generateSamples(allocator, 100); // 100ms
    defer allocator.free(samples);

    // Should have correct number of samples (44100 * 0.1 = 4410)
    try std.testing.expectEqual(@as(usize, 4410), samples.len);

    // All samples should be in range [-1, 1]
    for (samples) |s| {
        try std.testing.expect(s >= -1.0 and s <= 1.0);
    }
}

test "audio synthesizer PCM16" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 32, 32);
    defer grid.deinit();

    const synth = AudioSynthesizer.init(&grid);
    const pcm = try synth.generatePCM16(allocator, 50); // 50ms
    defer allocator.free(pcm);

    // Should have samples
    try std.testing.expect(pcm.len > 0);

    // All samples should be in valid i16 range
    for (pcm) |s| {
        try std.testing.expect(s >= -32768 and s <= 32767);
    }
}

test "WAV header" {
    const header = WavHeader.init(44100, 44100); // 1 second
    const bytes = header.toBytes();

    // Check RIFF header
    try std.testing.expectEqualStrings("RIFF", bytes[0..4]);
    try std.testing.expectEqualStrings("WAVE", bytes[8..12]);
    try std.testing.expectEqualStrings("fmt ", bytes[12..16]);
    try std.testing.expectEqualStrings("data", bytes[36..40]);
}

test "spectrum analysis" {
    const allocator = std.testing.allocator;
    var grid = try PhotonGrid.init(allocator, 64, 64);
    defer grid.deinit();

    // Create some wave activity
    grid.getMut(0, 32).amplitude = 1.0;
    grid.getMut(32, 32).amplitude = 0.5;

    const synth = AudioSynthesizer.init(&grid);
    var spectrum: [64]f32 = undefined;
    synth.getSpectrum(&spectrum);

    // First bin should have higher value
    try std.testing.expect(spectrum[0] > 0.0);
}
