// =============================================================================
// EMERGENT PHOTON AI v0.3 - IMMERSIVE COSMIC CANVAS
// No UI panels. No buttons. No text. Pure emergent wave intelligence.
// The entire screen IS the AI. Information emerges from interference.
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const photon = @import("photon.zig");
const math = std.math;
const rl = @cImport({
    @cInclude("raylib.h");
});

// =============================================================================
// COSMIC CONSTANTS
// =============================================================================

const PHI: f32 = 1.6180339887;
const PHI_INV: f32 = 0.6180339887;
const TAU: f32 = 6.28318530718;

// Grid fills ENTIRE screen
var g_width: c_int = 1512;
var g_height: c_int = 982;
var g_pixel_size: c_int = 4; // Smaller pixels = higher resolution

// =============================================================================
// COSMIC COLORS (Neon on void)
// =============================================================================

const VOID_BLACK = rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
const NEON_CYAN = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = 0xFF };
const NEON_MAGENTA = rl.Color{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = 0xFF };
const NEON_GREEN = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = 0xFF };
const NEON_GOLD = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF };
const NEON_PURPLE = rl.Color{ .r = 0x8B, .g = 0x5C, .b = 0xF6, .a = 0xFF };

// =============================================================================
// PARTICLE SYSTEM (Orbiting stats, trails)
// =============================================================================

const MAX_PARTICLES = 512;

const Particle = struct {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    life: f32, // 0-1, decays over time
    hue: f32, // Color
    size: f32,
    orbit_center_x: f32,
    orbit_center_y: f32,
    orbit_radius: f32,
    orbit_speed: f32,
    orbit_angle: f32,
    is_orbiting: bool,

    pub fn update(self: *Particle, dt: f32) void {
        if (self.is_orbiting) {
            // Orbital motion
            self.orbit_angle += self.orbit_speed * dt;
            self.x = self.orbit_center_x + self.orbit_radius * @cos(self.orbit_angle);
            self.y = self.orbit_center_y + self.orbit_radius * @sin(self.orbit_angle);
        } else {
            // Free motion with decay
            self.x += self.vx * dt;
            self.y += self.vy * dt;
            self.vx *= 0.98;
            self.vy *= 0.98;
        }
        self.life -= dt * 0.3; // Slow decay
    }

    pub fn isAlive(self: *const Particle) bool {
        return self.life > 0;
    }
};

const ParticleSystem = struct {
    particles: [MAX_PARTICLES]Particle,
    count: usize,

    pub fn init() ParticleSystem {
        var sys = ParticleSystem{
            .particles = undefined,
            .count = 0,
        };
        for (&sys.particles) |*p| {
            p.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *ParticleSystem, x: f32, y: f32, hue: f32) void {
        if (self.count >= MAX_PARTICLES) {
            // Find dead particle to reuse
            for (&self.particles) |*p| {
                if (!p.isAlive()) {
                    p.* = createParticle(x, y, hue);
                    return;
                }
            }
            return;
        }

        self.particles[self.count] = createParticle(x, y, hue);
        self.count += 1;
    }

    pub fn spawnOrbiting(self: *ParticleSystem, cx: f32, cy: f32, radius: f32, speed: f32, hue: f32) void {
        if (self.count >= MAX_PARTICLES) return;

        var p = createParticle(cx + radius, cy, hue);
        p.is_orbiting = true;
        p.orbit_center_x = cx;
        p.orbit_center_y = cy;
        p.orbit_radius = radius;
        p.orbit_speed = speed;
        p.orbit_angle = 0;
        p.life = 10.0; // Long life for orbiting particles

        self.particles[self.count] = p;
        self.count += 1;
    }

    pub fn update(self: *ParticleSystem, dt: f32) void {
        for (&self.particles) |*p| {
            if (p.isAlive()) {
                p.update(dt);
            }
        }
    }

    pub fn draw(self: *const ParticleSystem) void {
        for (&self.particles) |*p| {
            if (p.isAlive()) {
                const alpha: u8 = @intFromFloat(@min(255.0, p.life * 255.0));
                const rgb = hsvToRgb(p.hue, 1.0, 1.0);
                const color = rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha };

                const px: c_int = @intFromFloat(p.x);
                const py: c_int = @intFromFloat(p.y);
                const size: c_int = @intFromFloat(p.size * p.life);

                // Glow effect
                rl.DrawCircle(px, py, @floatFromInt(size + 2), rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = @divTrunc(alpha, 4) });
                rl.DrawCircle(px, py, @floatFromInt(size), color);
            }
        }
    }

    fn createParticle(x: f32, y: f32, hue: f32) Particle {
        const angle = @as(f32, @floatFromInt(std.crypto.random.int(u32) % 360)) * TAU / 360.0;
        const speed = 20.0 + @as(f32, @floatFromInt(std.crypto.random.int(u32) % 50));

        return Particle{
            .x = x,
            .y = y,
            .vx = @cos(angle) * speed,
            .vy = @sin(angle) * speed,
            .life = 1.0,
            .hue = hue,
            .size = 3.0 + @as(f32, @floatFromInt(std.crypto.random.int(u32) % 5)),
            .orbit_center_x = 0,
            .orbit_center_y = 0,
            .orbit_radius = 0,
            .orbit_speed = 0,
            .orbit_angle = 0,
            .is_orbiting = false,
        };
    }
};

// =============================================================================
// TRAIL SYSTEM (Cursor trails, wave paths)
// =============================================================================

const MAX_TRAIL_POINTS = 256;

const TrailPoint = struct {
    x: f32,
    y: f32,
    life: f32,
    hue: f32,
};

const Trail = struct {
    points: [MAX_TRAIL_POINTS]TrailPoint,
    head: usize,
    count: usize,

    pub fn init() Trail {
        return Trail{
            .points = undefined,
            .head = 0,
            .count = 0,
        };
    }

    pub fn add(self: *Trail, x: f32, y: f32, hue: f32) void {
        self.points[self.head] = TrailPoint{
            .x = x,
            .y = y,
            .life = 1.0,
            .hue = hue,
        };
        self.head = (self.head + 1) % MAX_TRAIL_POINTS;
        if (self.count < MAX_TRAIL_POINTS) self.count += 1;
    }

    pub fn update(self: *Trail, dt: f32) void {
        for (&self.points) |*p| {
            if (p.life > 0) {
                p.life -= dt * 2.0;
            }
        }
    }

    pub fn draw(self: *const Trail) void {
        for (&self.points) |*p| {
            if (p.life > 0) {
                const alpha: u8 = @intFromFloat(p.life * 200.0);
                const rgb = hsvToRgb(p.hue, 0.8, 1.0);

                const px: c_int = @intFromFloat(p.x);
                const py: c_int = @intFromFloat(p.y);

                // Glow
                rl.DrawCircle(px, py, 8, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = @divTrunc(alpha, 4) });
                rl.DrawCircle(px, py, 4, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha });
            }
        }
    }
};

// =============================================================================
// EMERGENT TEXT (Standing wave patterns)
// =============================================================================

const EmergentGlyph = struct {
    x: f32,
    y: f32,
    char: u8,
    amplitude: f32,
    phase: f32,
    life: f32,
};

const MAX_GLYPHS = 128;

const EmergentText = struct {
    glyphs: [MAX_GLYPHS]EmergentGlyph,
    count: usize,

    pub fn init() EmergentText {
        return EmergentText{
            .glyphs = undefined,
            .count = 0,
        };
    }

    pub fn spawnText(self: *EmergentText, text: []const u8, cx: f32, cy: f32) void {
        const spacing: f32 = 30.0;
        const start_x = cx - @as(f32, @floatFromInt(text.len)) * spacing / 2.0;

        for (text, 0..) |c, i| {
            if (self.count >= MAX_GLYPHS) break;

            self.glyphs[self.count] = EmergentGlyph{
                .x = start_x + @as(f32, @floatFromInt(i)) * spacing,
                .y = cy,
                .char = c,
                .amplitude = 0.0,
                .phase = @as(f32, @floatFromInt(i)) * PHI,
                .life = 5.0,
            };
            self.count += 1;
        }
    }

    pub fn update(self: *EmergentText, dt: f32, time: f32) void {
        var i: usize = 0;
        while (i < self.count) {
            var g = &self.glyphs[i];

            // Fade in
            if (g.amplitude < 1.0) {
                g.amplitude += dt * 2.0;
            }

            // Update phase
            g.phase += dt * TAU * 0.5;

            // Wave motion
            g.y += @sin(time * 2.0 + g.phase) * 0.5;

            // Decay
            g.life -= dt * 0.2;

            if (g.life <= 0) {
                // Remove glyph
                self.glyphs[i] = self.glyphs[self.count - 1];
                self.count -= 1;
            } else {
                i += 1;
            }
        }
    }

    pub fn draw(self: *const EmergentText, time: f32) void {
        for (self.glyphs[0..self.count]) |g| {
            const alpha: u8 = @intFromFloat(@min(255.0, g.life * 100.0 * g.amplitude));

            // Oscillating color
            const hue = @mod(time * 50.0 + g.phase * 30.0, 360.0);
            const rgb = hsvToRgb(hue, 0.7, 1.0);

            const px: c_int = @intFromFloat(g.x);
            const py: c_int = @intFromFloat(g.y);

            // Glow
            const glow_size: c_int = @intFromFloat(20.0 * g.amplitude);
            rl.DrawCircle(px, py, @floatFromInt(glow_size), rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = @divTrunc(alpha, 6) });

            // Character as simple shape (wave node)
            const wave_offset = @sin(time * 3.0 + g.phase) * 5.0 * g.amplitude;
            const final_y: c_int = @intFromFloat(g.y + wave_offset);

            // Draw character representation as concentric rings
            const rings: usize = 3;
            for (0..rings) |r| {
                const radius = @as(f32, @floatFromInt(r + 1)) * 4.0 * g.amplitude;
                const ring_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(alpha)) * (1.0 - @as(f32, @floatFromInt(r)) / @as(f32, @floatFromInt(rings))));
                rl.DrawCircleLines(px, final_y, radius, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = ring_alpha });
            }
        }
    }
};

// =============================================================================
// MAIN - IMMERSIVE EXPERIENCE
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Raylib init FIRST - BORDERLESS WINDOWED for NATIVE resolution (no upscaling!)
    rl.SetConfigFlags(rl.FLAG_BORDERLESS_WINDOWED_MODE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(0, 0, "EMERGENT PHOTON AI v0.3 | IMMERSIVE COSMIC CANVAS");
    defer rl.CloseWindow();

    // Get native screen resolution AFTER window init
    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // Calculate grid size to fill screen
    const grid_w: usize = @intCast(@divTrunc(g_width, g_pixel_size));
    const grid_h: usize = @intCast(@divTrunc(g_height, g_pixel_size));

    // Initialize photon grid to fill entire screen
    var grid = try photon.PhotonGrid.init(allocator, grid_w, grid_h);
    defer grid.deinit();

    // Particle system
    var particles = ParticleSystem.init();

    // Cursor trail
    var cursor_trail = Trail.init();

    // Emergent text
    var emergent_text = EmergentText.init();

    // State
    var time: f32 = 0;
    var cursor_hue: f32 = 120; // Start with green

    // Create orbiting stat particles
    const cx = @as(f32, @floatFromInt(g_width)) / 2.0;
    const cy = @as(f32, @floatFromInt(g_height)) / 2.0;

    particles.spawnOrbiting(cx, cy, 100.0, 1.0, 0); // Red orbit
    particles.spawnOrbiting(cx, cy, 150.0, -0.8, 120); // Green orbit
    particles.spawnOrbiting(cx, cy, 200.0, 0.6, 240); // Blue orbit

    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();

    rl.SetTargetFPS(60);
    rl.HideCursor(); // Hide system cursor for immersion

    // Initial text
    emergent_text.spawnText("WELCOME TO THE VOID", cx, cy - 100);

    // Main loop - PURE IMMERSION
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        time += dt;

        // Cursor position
        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();
        const mx = @as(f32, @floatFromInt(mouse_x));
        const my = @as(f32, @floatFromInt(mouse_y));

        // Grid coordinates
        const gx = @as(usize, @intCast(@divTrunc(mouse_x, g_pixel_size)));
        const gy = @as(usize, @intCast(@divTrunc(mouse_y, g_pixel_size)));

        // Evolving cursor hue
        cursor_hue = @mod(cursor_hue + dt * 30.0, 360.0);

        // === CURSOR INTERACTIONS ===

        // LMB = Wave source (positive perturbation)
        if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            if (gx < grid.width and gy < grid.height) {
                grid.setCursor(@floatFromInt(gx), @floatFromInt(gy), 1.0);
            }
            // Spawn particles at cursor
            particles.spawn(mx, my, cursor_hue);
            // Add trail point
            cursor_trail.add(mx, my, cursor_hue);
        }

        // RMB = Wave sink (negative perturbation)
        if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_RIGHT)) {
            if (gx < grid.width and gy < grid.height) {
                grid.getMut(gx, gy).amplitude = -1.0;
            }
            particles.spawn(mx, my, @mod(cursor_hue + 180.0, 360.0));
        }

        // Mouse wheel = frequency modulation
        const wheel = rl.GetMouseWheelMove();
        if (wheel != 0 and gx < grid.width and gy < grid.height) {
            grid.getMut(gx, gy).frequency += wheel * 0.5;
        }

        // === KEYBOARD SHORTCUTS (minimal, for emergent triggers) ===

        // T = Spawn emergent text at cursor
        if (rl.IsKeyPressed(rl.KEY_T)) {
            emergent_text.spawnText("EMERGENCE", mx, my);
        }

        // G = Golden spiral injection
        if (rl.IsKeyPressed(rl.KEY_G)) {
            grid.injectWave(.{ .golden_spiral = .{
                .center_x = gx,
                .center_y = gy,
                .scale = 3.0,
                .amplitude = 1.0,
            } });
            emergent_text.spawnText("PHI", mx, my);
        }

        // W = Wave pulse
        if (rl.IsKeyPressed(rl.KEY_W)) {
            grid.injectWave(.{ .circle = .{
                .center_x = gx,
                .center_y = gy,
                .radius = 20,
                .amplitude = 1.0,
            } });
        }

        // R = Reset (cosmic rebirth)
        if (rl.IsKeyPressed(rl.KEY_R)) {
            for (grid.photons) |*p| {
                p.amplitude = 0;
                p.interference = 0;
            }
            emergent_text.spawnText("REBIRTH", cx, cy);
        }

        // I = Export image (PPM)
        if (rl.IsKeyPressed(rl.KEY_I)) {
            const exporter = photon.ImageExporter.init(&grid);
            if (exporter.exportPPM(allocator)) |ppm| {
                defer allocator.free(ppm);
                const timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
                var path_buf: [128]u8 = undefined;
                const path = std.fmt.bufPrint(&path_buf, "photon_{d}.ppm", .{timestamp}) catch "photon.ppm";
                const file = std.fs.cwd().createFile(path, .{}) catch {
                    emergent_text.spawnText("EXPORT FAILED", mx, my);
                    continue;
                };
                defer file.close();
                file.writeAll(ppm) catch {};
                emergent_text.spawnText("IMAGE SAVED", mx, my);
            } else |_| {
                emergent_text.spawnText("EXPORT FAILED", mx, my);
            }
        }

        // A = Export audio (WAV)
        if (rl.IsKeyPressed(rl.KEY_A)) {
            const synth = photon.AudioSynthesizer.init(&grid);
            if (synth.generatePCM16(allocator, 1000)) |samples| {
                defer allocator.free(samples);
                const header = photon.WavHeader.init(44100, @intCast(samples.len));
                const timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
                var path_buf: [128]u8 = undefined;
                const path = std.fmt.bufPrint(&path_buf, "photon_{d}.wav", .{timestamp}) catch "photon.wav";
                const file = std.fs.cwd().createFile(path, .{}) catch {
                    emergent_text.spawnText("AUDIO FAILED", mx, my);
                    continue;
                };
                defer file.close();
                file.writeAll(&header.toBytes()) catch {};
                file.writeAll(std.mem.sliceAsBytes(samples)) catch {};
                emergent_text.spawnText("AUDIO SAVED", mx, my);
            } else |_| {
                emergent_text.spawnText("AUDIO FAILED", mx, my);
            }
        }

        // === PHYSICS UPDATE ===
        grid.stepSIMD();
        particles.update(dt);
        cursor_trail.update(dt);
        emergent_text.update(dt, time);

        // Update orbiting particles to reflect stats
        // Energy → orbit radius pulsation
        const energy_factor = 1.0 + grid.total_energy * 0.0001;
        for (&particles.particles) |*p| {
            if (p.is_orbiting and p.isAlive()) {
                p.orbit_radius *= 0.99 + energy_factor * 0.01;
            }
        }

        // Note: last_mouse_x/y available for velocity calculations if needed

        // === RENDER ===
        rl.BeginDrawing();
        defer rl.EndDrawing();

        // Pure void background
        rl.ClearBackground(VOID_BLACK);

        // Draw photon grid (fills entire screen)
        drawImmersiveGrid(&grid, time);

        // Draw cursor trail
        cursor_trail.draw();

        // Draw particles
        particles.draw();

        // Draw emergent text
        emergent_text.draw(time);

        // Draw custom cursor (photon probe)
        drawPhotonCursor(mx, my, cursor_hue, time);

        // Subtle corner indicators (barely visible, emergent feel)
        drawCornerGlyphs(time);
    }
}

fn drawImmersiveGrid(grid: *photon.PhotonGrid, time: f32) void {
    for (0..grid.height) |y| {
        for (0..grid.width) |x| {
            const p = grid.get(x, y);

            // Skip very low amplitude (performance + visual)
            if (@abs(p.amplitude) < 0.01) continue;

            const px: c_int = @intCast(x * @as(usize, @intCast(g_pixel_size)));
            const py: c_int = @intCast(y * @as(usize, @intCast(g_pixel_size)));

            // Color based on amplitude + phase + time
            const hue = @mod(p.hue + time * 20.0 + p.phase * 10.0, 360.0);
            const saturation: f32 = 0.8;
            const brightness = @min(1.0, @abs(p.amplitude));

            const rgb = hsvToRgb(hue, saturation, brightness);

            // Alpha based on amplitude
            const alpha: u8 = @intFromFloat(@min(255.0, @abs(p.amplitude) * 300.0));

            const color = rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha };

            // Draw pixel with slight glow for high amplitude
            if (@abs(p.amplitude) > 0.5) {
                const glow_alpha: u8 = @intFromFloat(@min(100.0, @abs(p.amplitude) * 100.0));
                rl.DrawRectangle(px - 1, py - 1, g_pixel_size + 2, g_pixel_size + 2, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = glow_alpha });
            }

            rl.DrawRectangle(px, py, g_pixel_size - 1, g_pixel_size - 1, color);
        }
    }
}

fn drawPhotonCursor(x: f32, y: f32, hue: f32, time: f32) void {
    const px: c_int = @intFromFloat(x);
    const py: c_int = @intFromFloat(y);

    const rgb = hsvToRgb(hue, 1.0, 1.0);

    // Pulsating rings
    const pulse = (@sin(time * 5.0) + 1.0) * 0.5;

    // Outer glow
    rl.DrawCircle(px, py, 20 + pulse * 10, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 30 });
    rl.DrawCircle(px, py, 12 + pulse * 5, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 60 });

    // Inner rings
    rl.DrawCircleLines(px, py, 8 + pulse * 3, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 200 });
    rl.DrawCircleLines(px, py, 4 + pulse * 2, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });

    // Center dot
    rl.DrawCircle(px, py, 2, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

fn drawCornerGlyphs(time: f32) void {
    const alpha: u8 = @intFromFloat(30.0 + @sin(time * 0.5) * 20.0);
    const color = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = alpha };

    // Top-left: phi symbol hint
    rl.DrawText("phi", 10, 10, 12, color);

    // Top-right: trinity
    rl.DrawText("3", g_width - 20, 10, 12, color);

    // Bottom-left
    rl.DrawText("v0.3", 10, g_height - 20, 10, color);

    // Bottom-right
    rl.DrawText("ESC", g_width - 30, g_height - 20, 10, color);
}

// =============================================================================
// UTILITY
// =============================================================================

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
