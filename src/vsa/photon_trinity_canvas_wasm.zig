// =============================================================================
// TRINITY CANVAS WASM v1.0 - Minimal Emscripten-Compatible Build
// Renders: 27-petal logo + 42 formula particles + theme toggle + status bar
// Compile: zig build (with emscripten target) or native desktop fallback
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const builtin = @import("builtin");
const theme = @import("trinity_canvas/theme.zig");
const math = std.math;

const rl = @cImport({
    @cInclude("raylib.h");
});

// Emscripten header (only on wasm target)
const emc = if (builtin.os.tag == .emscripten)
    @cImport(@cInclude("emscripten/emscripten.h"))
else
    struct {};

// Chat engine stubs — mapped via build.zig to no-op modules for WASM
const igla_chat = @import("igla_chat");
const fluent_chat = @import("igla_fluent_chat");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const tvc = @import("tvc_corpus");
const auto_shard = @import("auto_shard");

// =============================================================================
// COSMIC CONSTANTS
// =============================================================================

const PHI: f32 = theme.PHI;
const PHI_INV: f32 = theme.PHI_INV;
const TAU: f32 = theme.TAU;

// =============================================================================
// GLOBAL STATE
// =============================================================================

var g_width: c_int = 1280;
var g_height: c_int = 800;
var g_font_scale: f32 = 1.0;
var g_dpi_scale: f32 = 1.0;

// Global chat engines (stub interfaces for WASM)
var g_chat_engine: igla_chat.IglaLocalChat = igla_chat.IglaLocalChat.init();
var g_fluent_engine: fluent_chat.FluentChatEngine = undefined;
var g_hybrid_engine: ?igla_hybrid_chat.IglaHybridChat = null;

// =============================================================================
// COLOR HELPERS
// =============================================================================

fn toRl(c: theme.Color) rl.Color {
    return @bitCast(c);
}

fn withAlpha(c: rl.Color, alpha: u8) rl.Color {
    return rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = alpha };
}

fn accentText(accent: rl.Color, alpha: u8) rl.Color {
    return if (theme.isDark()) withAlpha(accent, alpha) else rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = alpha };
}

// === SWITCHABLE surface colors (var -- re-read from theme on toggle) ===
var BG_BLACK: rl.Color = @bitCast(theme.colors.bg);
var TEXT_WHITE: rl.Color = @bitCast(theme.colors.text);
var MUTED_GRAY: rl.Color = @bitCast(theme.colors.text_muted);
var BORDER_SUBTLE: rl.Color = @bitCast(theme.colors.border);
var VOID_BLACK: rl.Color = @bitCast(theme.colors.bg);
var NOVA_WHITE: rl.Color = @bitCast(theme.colors.text);
var BG_SURFACE: rl.Color = @bitCast(theme.colors.bg_surface);
var TEXT_DIM: rl.Color = @bitCast(theme.colors.text_dim);
var TEXT_HINT: rl.Color = @bitCast(theme.colors.text_hint);

// === ACCENT colors (const -- same in dark and light) ===
const HYPER_MAGENTA: rl.Color = @bitCast(theme.accents.magenta);
const HYPER_CYAN: rl.Color = @bitCast(theme.accents.cyan);
const HYPER_GREEN: rl.Color = @bitCast(theme.accents.green);
const HYPER_YELLOW: rl.Color = @bitCast(theme.accents.yellow);
const HYPER_RED: rl.Color = @bitCast(theme.accents.red);
const NEON_GREEN: rl.Color = @bitCast(theme.accents.green);
const GOLD: rl.Color = @bitCast(theme.accents.gold);
const BLUE: rl.Color = @bitCast(theme.accents.blue);
const ORANGE: rl.Color = @bitCast(theme.accents.orange);
const PURPLE: rl.Color = @bitCast(theme.accents.purple);
const LOGO_GREEN: rl.Color = @bitCast(theme.accents.logo_green);

// Reload all var aliases from theme after toggle()
fn reloadThemeAliases() void {
    BG_BLACK = @bitCast(theme.bg);
    TEXT_WHITE = @bitCast(theme.text);
    MUTED_GRAY = @bitCast(theme.text_muted);
    BORDER_SUBTLE = @bitCast(theme.border);
    VOID_BLACK = @bitCast(theme.bg);
    NOVA_WHITE = @bitCast(theme.text);
    BG_SURFACE = @bitCast(theme.bg_surface);
    TEXT_DIM = @bitCast(theme.text_dim);
    TEXT_HINT = @bitCast(theme.text_hint);
}

// =============================================================================
// LOGO BLOCK + LOGO ANIMATION (27 petals -- exact copy from original)
// =============================================================================

const LogoBlock = struct {
    v: [5]rl.Vector2,
    count: u8,
    offset: rl.Vector2,
    rotation: f32,
    scale: f32,
    delay: f32,
    center: rl.Vector2,
    anim_vx: f32,
    anim_vy: f32,
    anim_vr: f32,
    push_x: f32,
    push_y: f32,
    push_rot: f32,
    vel_x: f32,
    vel_y: f32,
    vel_rot: f32,
};

const LogoAnimation = struct {
    blocks: [27]LogoBlock,
    time: f32,
    duration: f32,
    is_complete: bool,
    logo_scale: f32,
    logo_offset: rl.Vector2,
    hovered_block: i32,
    clicked_block: i32,

    const SVG_WIDTH: f32 = 596.0;
    const SVG_HEIGHT: f32 = 526.0;
    const SVG_CENTER_X: f32 = 298.0;
    const SVG_CENTER_Y: f32 = 263.0;

    pub fn init(screen_w: f32, screen_h: f32) LogoAnimation {
        var self = LogoAnimation{
            .blocks = undefined,
            .time = 0,
            .duration = 2.5,
            .is_complete = false,
            .logo_scale = @min(screen_w / SVG_WIDTH, screen_h / SVG_HEIGHT) * 0.35,
            .logo_offset = .{ .x = screen_w / 2, .y = screen_h / 2 },
            .hovered_block = -1,
            .clicked_block = -1,
        };

        // 27 blocks parsed from assets/999.svg
        const raw_blocks = [27][5][2]f32{
            .{ .{ 296.767, 435.228 }, .{ 236.563, 329.491 }, .{ 211.501, 373.56 }, .{ 296.767, 523.496 }, .{ 0, 0 } },
            .{ .{ 235.71, 328.065 }, .{ 177.201, 224.57 }, .{ 126.893, 224.57 }, .{ 210.755, 372.182 }, .{ 0, 0 } },
            .{ .{ 116.304, 118.557 }, .{ 175.824, 223.238 }, .{ 126.022, 223.26 }, .{ 42.177, 74.909 }, .{ 0, 0 } },
            .{ .{ 43.019, 73.555 }, .{ 117.106, 116.68 }, .{ 235.544, 116.68 }, .{ 211.46, 73.525 }, .{ 0, 0 } },
            .{ .{ 213.1, 73.52 }, .{ 237.875, 116.409 }, .{ 356.58, 116.741 }, .{ 381.646, 73.509 }, .{ 0, 0 } },
            .{ .{ 477.724, 116.854 }, .{ 358.701, 116.802 }, .{ 383.404, 73.803 }, .{ 550.969, 73.877 }, .{ 0, 0 } },
            .{ .{ 477.056, 118.915 }, .{ 418.023, 223.109 }, .{ 468.886, 223.131 }, .{ 553.143, 74.338 }, .{ 0, 0 } },
            .{ .{ 358.646, 327.197 }, .{ 384.221, 372.152 }, .{ 468.192, 224.521 }, .{ 416.976, 224.579 }, .{ 0, 0 } },
            .{ .{ 298.138, 434.656 }, .{ 357.793, 328.533 }, .{ 383.376, 373.808 }, .{ 298.138, 523.876 }, .{ 0, 0 } },
            .{ .{ 297.148, 352.965 }, .{ 260.326, 288.171 }, .{ 237.943, 327.796 }, .{ 297.148, 432.004 }, .{ 0, 0 } },
            .{ .{ 259.613, 286.78 }, .{ 224.371, 224.818 }, .{ 179.6, 224.818 }, .{ 237.048, 326.301 }, .{ 0, 0 } },
            .{ .{ 223.536, 223.354 }, .{ 187.285, 159.675 }, .{ 120.085, 120.508 }, .{ 178.781, 223.779 }, .{ 0, 0 } },
            .{ .{ 121.863, 119.193 }, .{ 187.937, 158.358 }, .{ 260.042, 158.355 }, .{ 237.348, 118.746 }, .{ 0, 0 } },
            .{ .{ 261.857, 158.313 }, .{ 333.559, 158.29 }, .{ 356.01, 118.829 }, .{ 239.269, 118.829 }, .{ 0, 0 } },
            .{ .{ 335.294, 158.3 }, .{ 407.736, 158.226 }, .{ 474.496, 118.923 }, .{ 357.761, 118.923 }, .{ 0, 0 } },
            .{ .{ 408.358, 159.547 }, .{ 372.034, 223.421 }, .{ 416.476, 223.315 }, .{ 475.012, 120.916 }, .{ 0, 0 } },
            .{ .{ 336.052, 286.778 }, .{ 358.165, 325.872 }, .{ 415.649, 224.808 }, .{ 371.244, 224.759 }, .{ 0, 0 } },
            .{ .{ 298.893, 352.826 }, .{ 335.156, 288.19 }, .{ 357.382, 327.328 }, .{ 298.893, 430.179 }, .{ 0, 0 } },
            .{ .{ 296.258, 272.716 }, .{ 282.337, 248.309 }, .{ 260.496, 286.972 }, .{ 296.258, 349.653 }, .{ 0, 0 } },
            .{ .{ 259.547, 285.675 }, .{ 281.633, 246.705 }, .{ 269.336, 225.016 }, .{ 225.274, 224.996 }, .{ 0, 0 } },
            .{ .{ 254.956, 199.798 }, .{ 268.406, 223.578 }, .{ 224.465, 223.598 }, .{ 189.037, 161.206 }, .{ 0, 0 } },
            .{ .{ 255.476, 198.549 }, .{ 282.068, 198.538 }, .{ 260.192, 160.039 }, .{ 189.751, 160.07 }, .{ 0, 0 } },
            .{ .{ 261.646, 160.062 }, .{ 283.582, 198.505 }, .{ 309.702, 198.505 }, .{ 331.733, 160.062 }, .{ 0, 0 } },
            .{ .{ 338.542, 198.607 }, .{ 311.435, 198.595 }, .{ 333.423, 160.068 }, .{ 404.244, 160.099 }, .{ 0, 0 } },
            .{ .{ 338.85, 199.978 }, .{ 325.556, 223.591 }, .{ 369.518, 223.61 }, .{ 404.907, 161.243 }, .{ 0, 0 } },
            .{ .{ 334.38, 285.625 }, .{ 312.392, 246.733 }, .{ 324.681, 224.989 }, .{ 368.779, 224.969 }, .{ 0, 0 } },
            .{ .{ 298.025, 272.637 }, .{ 311.561, 248.279 }, .{ 333.297, 287.01 }, .{ 298.025, 349.402 }, .{ 0, 0 } },
        };
        const counts = [27]u8{ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 };

        for (0..27) |i| {
            var center_x: f32 = 0;
            var center_y: f32 = 0;
            const cnt = counts[i];

            for (0..cnt) |j| {
                const x = raw_blocks[i][j][0] - SVG_CENTER_X;
                const y = raw_blocks[i][j][1] - SVG_CENTER_Y;
                self.blocks[i].v[j] = .{ .x = x, .y = y };
                center_x += x;
                center_y += y;
            }
            center_x /= @floatFromInt(cnt);
            center_y /= @floatFromInt(cnt);
            self.blocks[i].count = cnt;
            self.blocks[i].center = .{ .x = center_x, .y = center_y };

            const dir_len = @sqrt(center_x * center_x + center_y * center_y);
            const norm_x = if (dir_len > 0.1) center_x / dir_len else @cos(@as(f32, @floatFromInt(i)) * TAU / 27.0);
            const norm_y = if (dir_len > 0.1) center_y / dir_len else @sin(@as(f32, @floatFromInt(i)) * TAU / 27.0);
            const distance: f32 = 800.0;
            self.blocks[i].offset = .{ .x = norm_x * distance, .y = norm_y * distance };
            self.blocks[i].rotation = 0;
            self.blocks[i].scale = 1.0;
            self.blocks[i].delay = 0;
            self.blocks[i].anim_vx = 0;
            self.blocks[i].anim_vy = 0;
            self.blocks[i].anim_vr = 0;
            self.blocks[i].push_x = 0;
            self.blocks[i].push_y = 0;
            self.blocks[i].push_rot = 0;
            self.blocks[i].vel_x = 0;
            self.blocks[i].vel_y = 0;
            self.blocks[i].vel_rot = 0;
        }

        return self;
    }

    pub fn update(self: *LogoAnimation, dt: f32) void {
        if (self.is_complete) return;

        self.time += dt;

        var all_done = true;
        for (&self.blocks) |*block| {
            const t = @max(0, self.time - block.delay);
            const progress = @min(1.0, t / self.duration);

            const arrival = 0.7;

            if (progress < arrival) {
                const speed = 4.5 * dt;
                block.offset.x -= block.offset.x * speed;
                block.offset.y -= block.offset.y * speed;
                block.anim_vx = -block.offset.x * 0.4;
                block.anim_vy = -block.offset.y * 0.4;
                block.anim_vr = 0;
            } else {
                const spring_k: f32 = 28.0;
                const damp: f32 = 0.86;
                block.anim_vx += (-block.offset.x * spring_k) * dt;
                block.anim_vy += (-block.offset.y * spring_k) * dt;
                block.anim_vx *= damp;
                block.anim_vy *= damp;
                block.offset.x += block.anim_vx * dt * 60.0;
                block.offset.y += block.anim_vy * dt * 60.0;
                block.anim_vr += (-block.rotation * spring_k) * dt;
                block.anim_vr *= damp;
                block.rotation += block.anim_vr * dt * 60.0;
                block.scale += (1.0 - block.scale) * 0.1;
            }

            const dist = @sqrt(block.offset.x * block.offset.x + block.offset.y * block.offset.y);
            const vel = @sqrt(block.anim_vx * block.anim_vx + block.anim_vy * block.anim_vy);
            if (dist > 0.3 or vel > 0.3 or @abs(block.rotation) > 0.003) {
                all_done = false;
            }
        }

        if (all_done and self.time > self.duration + 0.5) {
            self.is_complete = true;
        }
    }

    fn pointInPoly(verts: [5]rl.Vector2, cnt: u8, px: f32, py: f32) bool {
        var inside = false;
        var j: usize = cnt - 1;
        var i: usize = 0;
        while (i < cnt) : (i += 1) {
            const yi = verts[i].y;
            const yj = verts[j].y;
            const xi = verts[i].x;
            const xj = verts[j].x;
            if (((yi > py) != (yj > py)) and
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi))
            {
                inside = !inside;
            }
            j = i;
        }
        return inside;
    }

    pub fn applyMouse(self: *LogoAnimation, mouse_x: f32, mouse_y: f32, _: f32, mouse_pressed: bool) void {
        const scale = self.logo_scale;
        const ox = self.logo_offset.x;
        const oy = self.logo_offset.y;

        self.hovered_block = -1;
        self.clicked_block = -1;

        for (self.blocks, 0..) |block, i| {
            var verts: [5]rl.Vector2 = undefined;
            const cnt = block.count;

            const cos_r = @cos(block.rotation);
            const sin_r = @sin(block.rotation);

            for (0..cnt) |j| {
                var bx = block.v[j].x * block.scale;
                var by = block.v[j].y * block.scale;
                const ddx = bx - block.center.x * block.scale;
                const ddy = by - block.center.y * block.scale;
                bx = block.center.x * block.scale + ddx * cos_r - ddy * sin_r;
                by = block.center.y * block.scale + ddx * sin_r + ddy * cos_r;
                bx += block.offset.x;
                by += block.offset.y;
                verts[j] = .{ .x = ox + bx * scale, .y = oy + by * scale };
            }

            if (pointInPoly(verts, cnt, mouse_x, mouse_y)) {
                self.hovered_block = @intCast(i);
                if (mouse_pressed) {
                    self.clicked_block = @intCast(i);
                }
            }
        }
    }

    pub fn draw(self: *const LogoAnimation) void {
        const scale = self.logo_scale;
        const ox = self.logo_offset.x;
        const oy = self.logo_offset.y;

        const highlight_color: rl.Color = @bitCast(theme.logo_highlight);
        const petal_color: rl.Color = @bitCast(theme.logo_petal);
        const outline_color: rl.Color = @bitCast(theme.logo_outline);

        for (self.blocks, 0..) |block, idx| {
            const fill_color = if (self.hovered_block >= 0 and idx == @as(usize, @intCast(self.hovered_block))) highlight_color else petal_color;
            var verts: [5]rl.Vector2 = undefined;
            const cnt = block.count;

            const cos_r = @cos(block.rotation);
            const sin_r = @sin(block.rotation);

            for (0..cnt) |j| {
                var bx = block.v[j].x * block.scale;
                var by = block.v[j].y * block.scale;
                const ddx = bx - block.center.x * block.scale;
                const ddy = by - block.center.y * block.scale;
                bx = block.center.x * block.scale + ddx * cos_r - ddy * sin_r;
                by = block.center.y * block.scale + ddx * sin_r + ddy * cos_r;
                bx += block.offset.x;
                by += block.offset.y;
                verts[j] = .{ .x = ox + bx * scale, .y = oy + by * scale };
            }

            // Fill triangles
            if (cnt >= 3) {
                var k: usize = 1;
                while (k < cnt - 1) : (k += 1) {
                    rl.DrawTriangle(verts[0], verts[k], verts[k + 1], fill_color);
                    rl.DrawTriangle(verts[0], verts[k + 1], verts[k], fill_color);
                }
            }

            // Outline
            var m: usize = 0;
            while (m < cnt) : (m += 1) {
                const next = (m + 1) % cnt;
                rl.DrawLineEx(verts[m], verts[next], 1.0, outline_color);
            }
        }
    }
};

// =============================================================================
// FORMULA PARTICLE (42 sacred formulas in Fibonacci spiral -- exact copy)
// =============================================================================

const FormulaParticle = struct {
    text: [48:0]u8,
    text_len: u8,
    desc: [80:0]u8,
    desc_len: u8,
    base_angle: f32,
    orbit_radius: f32,
    orbit_speed: f32,
    angle_offset: f32,
    expanded: bool,
    expand_anim: f32,

    fn init(text_src: []const u8, desc_src: []const u8, base_angle_val: f32, radius: f32, speed: f32) FormulaParticle {
        var p: FormulaParticle = undefined;
        const tlen = @min(text_src.len, 47);
        @memcpy(p.text[0..tlen], text_src[0..tlen]);
        p.text[tlen] = 0;
        p.text_len = @intCast(tlen);
        const dlen = @min(desc_src.len, 79);
        @memcpy(p.desc[0..dlen], desc_src[0..dlen]);
        p.desc[dlen] = 0;
        p.desc_len = @intCast(dlen);
        p.base_angle = base_angle_val;
        p.orbit_radius = radius;
        p.orbit_speed = speed;
        p.angle_offset = 0;
        p.expanded = false;
        p.expand_anim = 0;
        return p;
    }

    fn getPos(self: *const FormulaParticle, time_val: f32, cx: f32, cy: f32) struct { x: f32, y: f32 } {
        const angle = self.base_angle + time_val * self.orbit_speed + self.angle_offset;
        return .{
            .x = cx + @cos(angle) * self.orbit_radius,
            .y = cy + @sin(angle) * self.orbit_radius,
        };
    }

    fn update(self: *FormulaParticle, dt: f32, time_val: f32, mouse_x: f32, mouse_y: f32, mouse_pressed: bool, cx: f32, cy: f32) void {
        const pos = self.getPos(time_val, cx, cy);

        const ddx = pos.x - mouse_x;
        const ddy = pos.y - mouse_y;
        const dist = @sqrt(ddx * ddx + ddy * ddy + 1.0);
        const hover_radius: f32 = 60.0;

        if (dist < hover_radius) {
            self.angle_offset -= self.orbit_speed * dt;
        }

        if (dist >= hover_radius) {
            self.angle_offset *= (1.0 - 0.8 * dt);
        }

        if (mouse_pressed) {
            const tw = @as(f32, @floatFromInt(self.text_len)) * 8.0;
            const half_tw = tw / 2;
            if (mouse_x >= pos.x - half_tw - 5 and mouse_x <= pos.x + half_tw + 5 and
                mouse_y >= pos.y - 10 and mouse_y <= pos.y + 18)
            {
                self.expanded = !self.expanded;
            }
        }

        if (self.expanded and self.expand_anim < 1.0) {
            self.expand_anim = @min(1.0, self.expand_anim + dt * 4.0);
        } else if (!self.expanded and self.expand_anim > 0.0) {
            self.expand_anim = @max(0.0, self.expand_anim - dt * 4.0);
        }
    }

    fn draw(self: *const FormulaParticle, time_val: f32, cx: f32, cy: f32, font: rl.Font) void {
        const pos = self.getPos(time_val, cx, cy);
        const text_color = withAlpha(@as(rl.Color, @bitCast(theme.formula_text)), 160);
        const tw = @as(f32, @floatFromInt(self.text_len)) * 8.0;

        rl.DrawTextEx(font, &self.text, .{ .x = pos.x - tw / 2, .y = pos.y - 7 }, 14, 0.5, text_color);

        if (self.expand_anim > 0.3) {
            const desc_alpha: u8 = @intFromFloat(@min(self.expand_anim, 1.0) * 200.0);
            const desc_accent = @as(rl.Color, @bitCast(theme.accents.logo_green));
            const desc_color = if (theme.isDark()) withAlpha(desc_accent, desc_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.text)), desc_alpha);
            const dw = @as(f32, @floatFromInt(self.desc_len)) * 7.0;
            rl.DrawTextEx(font, &self.desc, .{ .x = pos.x - dw / 2, .y = pos.y + 12 }, 12, 0.5, desc_color);
        }
    }
};

const MAX_FORMULA_PARTICLES = 42;

// =============================================================================
// GAME STATE -- persists across Emscripten frames
// =============================================================================

const GameState = struct {
    logo_anim: LogoAnimation,
    formula_particles: [MAX_FORMULA_PARTICLES]FormulaParticle,
    loading_complete: bool,
    time: f32,
    font: rl.Font,
    font_small: rl.Font,
};

// Global pointer for Emscripten callback
var g_state: ?*GameState = null;

// =============================================================================
// FORMULA DATA (42 sacred formulas)
// =============================================================================

const formula_texts = [42][]const u8{
    "phi = 1.618",              "pi*phi*e = 13.82",      "L(10) = 123",
    "1/alpha = 137.036",        "phi^2 = 2.618",         "Feigenbaum = 4.669",
    "F(7) = 13",                "sqrt(5) = 2.236",       "999 = 37 x 27",
    "pi = 3.14159",             "27 = 3^3",              "CHSH = 2*sqrt(2)",
    "m_p/m_e = 1836",           "pi^2 = 9.87",           "e^pi = 23.14",
    "E8 = 248 dim",             "603 = 67*9",            "76 photons",
    "phi^2+1/phi^2 = 3",        "tau = 6.283",           "Menger = 2.727",
    "mu = 0.0382",              "chi = 0.0618",          "sigma = phi",
    "e = 2.71828",              "13.82 Gyr",             "H0 = 70.74",
    "V = n*3^k*pi^m*phi^p*e^q", "1.58 bits/trit",        "phi = (1+sqrt(5))/2",
    "e^(i*pi) + 1 = 0",         "3 = phi^2 + 1/phi^2",   "F(n) = F(n-1)+F(n-2)",
    "hbar = 1.054e-34",         "c = 299792458 m/s",     "G = 6.674e-11",
    "L(n): 2,1,3,4,7,11,18...", "tau/phi = 3.883",       "pi*e = 8.539",
    "phi^phi = 2.390",          "3^3^3 = 7625597484987", "sqrt(2) = 1.414",
};

const formula_descs = [42][]const u8{
    "Golden ratio -- nature's proportion", "Product of transcendentals",  "10th Lucas number",
    "Fine structure constant inverse",     "Golden ratio squared",        "Feigenbaum chaos constant",
    "7th Fibonacci number",                "Square root of five",         "Sacred number 999",
    "Circle ratio",                        "Cube of trinity",             "Quantum Bell bound",
    "Proton-electron mass ratio",          "Basel problem result",        "Euler to pi",
    "E8 Lie group dimension",              "Energy efficiency",           "Quantum advantage",
    "TRINITY IDENTITY",                    "Full turn tau",               "Menger sponge fractal",
    "Mutation rate from phi",              "Crossover rate from phi",     "Selection = phi",
    "Euler's number",                      "Age of universe",             "Hubble constant",
    "Trinity value formula",               "Ternary information density", "Golden ratio definition",
    "Euler's identity",                    "Trinity identity",            "Fibonacci recurrence",
    "Reduced Planck constant",             "Speed of light",              "Gravitational constant",
    "Lucas sequence",                      "Tau over phi",                "Pi times e",
    "Phi to phi power",                    "Tower of threes",             "Pythagoras' constant",
};

// =============================================================================
// BACKGROUND: simplified wave grid (subtle dots)
// =============================================================================

fn drawSubtleDotGrid(time_val: f32) void {
    const sw = @as(f32, @floatFromInt(g_width));
    const sh = @as(f32, @floatFromInt(g_height));
    const spacing: f32 = 40.0;
    const dot_color = if (theme.isDark())
        rl.Color{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 0xFF }
    else
        rl.Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = 0xFF };

    var y: f32 = 0;
    while (y < sh) : (y += spacing) {
        var x: f32 = 0;
        while (x < sw) : (x += spacing) {
            // Subtle wave distortion
            const wave = @sin(x * 0.02 + time_val * 0.5) * @cos(y * 0.02 + time_val * 0.3) * 2.0;
            const px = x + wave;
            const py = y + wave * 0.7;
            rl.DrawCircle(@intFromFloat(px), @intFromFloat(py), 1.0, dot_color);
        }
    }
}

// =============================================================================
// SUN/MOON THEME TOGGLE (top-right)
// =============================================================================

fn drawThemeToggle() void {
    const toggle_cx: f32 = @as(f32, @floatFromInt(g_width)) - 35;
    const toggle_cy: f32 = 30;
    const toggle_r: f32 = 10;
    if (theme.isDark()) {
        const moon_color = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 220 };
        rl.DrawCircle(@intFromFloat(toggle_cx), @intFromFloat(toggle_cy), toggle_r, moon_color);
        rl.DrawCircle(@intFromFloat(toggle_cx + 5), @intFromFloat(toggle_cy - 3), toggle_r - 1, @as(rl.Color, @bitCast(theme.clear_bg)));
    } else {
        const sun_color = rl.Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 220 };
        rl.DrawCircle(@intFromFloat(toggle_cx), @intFromFloat(toggle_cy), toggle_r - 2, sun_color);
        var ray: usize = 0;
        while (ray < 8) : (ray += 1) {
            const angle = @as(f32, @floatFromInt(ray)) * (TAU / 8.0);
            const rx1 = toggle_cx + @cos(angle) * (toggle_r + 1);
            const ry1 = toggle_cy + @sin(angle) * (toggle_r + 1);
            const rx2 = toggle_cx + @cos(angle) * (toggle_r + 5);
            const ry2 = toggle_cy + @sin(angle) * (toggle_r + 5);
            rl.DrawLineEx(.{ .x = rx1, .y = ry1 }, .{ .x = rx2, .y = ry2 }, 1.5, sun_color);
        }
    }
}

fn handleThemeToggleClick() void {
    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
        const tcx: f32 = @as(f32, @floatFromInt(g_width)) - 35;
        const tcy: f32 = 30;
        const tmx = @as(f32, @floatFromInt(rl.GetMouseX()));
        const tmy = @as(f32, @floatFromInt(rl.GetMouseY()));
        const dx_t = tmx - tcx;
        const dy_t = tmy - tcy;
        if (dx_t * dx_t + dy_t * dy_t <= 14 * 14) {
            theme.toggle();
            reloadThemeAliases();
        }
    }
    // Ctrl+D / Cmd+D toggle (Ctrl for WASM since no Super key in browsers)
    if ((rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL) or
        rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER)) and
        rl.IsKeyPressed(rl.KEY_D))
    {
        theme.toggle();
        reloadThemeAliases();
    }
}

// =============================================================================
// STATUS BAR (simplified -- bottom bar with key stats)
// =============================================================================

fn drawStatusBar(state: *const GameState) void {
    const status_bar_h: f32 = 24;
    const status_y: f32 = @as(f32, @floatFromInt(g_height)) - status_bar_h;
    const sw = @as(f32, @floatFromInt(g_width));
    const time_val = state.time;

    // Background
    rl.DrawRectangle(0, @intFromFloat(status_y), g_width, @intFromFloat(status_bar_h), withAlpha(BG_SURFACE, 240));
    rl.DrawLine(0, @intFromFloat(status_y), g_width, @intFromFloat(status_y), BORDER_SUBTLE);

    const stat_text_color = if (theme.isDark()) @as(?rl.Color, null) else TEXT_WHITE;

    // Left: TRINITY label
    rl.DrawTextEx(state.font_small, "TRINITY WASM", .{ .x = 12, .y = status_y + 5 }, 13, 0.5, stat_text_color orelse HYPER_GREEN);

    // Simulated stats (right-aligned)
    var stat_buf: [64:0]u8 = undefined;
    const spacing: f32 = 75;
    var x_pos: f32 = sw - 12;

    // Time
    var time_buf: [16:0]u8 = undefined;
    const display_time = @mod(@as(u32, @intFromFloat(time_val)), 86400);
    const hours = display_time / 3600;
    const minutes = (display_time % 3600) / 60;
    const seconds = display_time % 60;
    _ = std.fmt.bufPrintZ(&time_buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch {};
    x_pos -= 70;
    rl.DrawTextEx(state.font_small, &time_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_MAGENTA);

    // FPS
    const fps = rl.GetFPS();
    _ = std.fmt.bufPrintZ(&stat_buf, "FPS {d}", .{fps}) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(state.font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse PURPLE);

    // Formulas count
    _ = std.fmt.bufPrintZ(&stat_buf, "F=42", .{}) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(state.font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse BLUE);

    // Petals
    _ = std.fmt.bufPrintZ(&stat_buf, "P=27", .{}) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(state.font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_CYAN);

    // phi^2+1/phi^2=3
    _ = std.fmt.bufPrintZ(&stat_buf, "phi^2+1/phi^2=3", .{}) catch {};
    x_pos -= spacing + 40;
    rl.DrawTextEx(state.font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse GOLD);
}

// =============================================================================
// FRAME CALLBACK (Emscripten-compatible)
// =============================================================================

fn updateDrawFrame() callconv(.c) void {
    const state = g_state orelse return;

    const dt = rl.GetFrameTime();
    state.time += dt;

    // Update window size (responsive)
    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // Mouse state
    const mx = @as(f32, @floatFromInt(rl.GetMouseX()));
    const my = @as(f32, @floatFromInt(rl.GetMouseY()));
    const mouse_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);

    // Handle theme toggle input
    handleThemeToggleClick();

    // Update logo
    state.logo_anim.logo_scale = @min(
        @as(f32, @floatFromInt(g_width)) / LogoAnimation.SVG_WIDTH,
        @as(f32, @floatFromInt(g_height)) / LogoAnimation.SVG_HEIGHT,
    ) * 0.35;
    state.logo_anim.logo_offset = .{
        .x = @as(f32, @floatFromInt(g_width)) / 2,
        .y = @as(f32, @floatFromInt(g_height)) / 2,
    };

    if (!state.loading_complete) {
        state.logo_anim.update(dt);
        if (state.logo_anim.is_complete) {
            state.loading_complete = true;
        }
    }

    // --- DRAWING ---
    rl.BeginDrawing();
    defer rl.EndDrawing();

    // Theme-aware background
    rl.ClearBackground(@as(rl.Color, @bitCast(theme.clear_bg)));

    if (!state.loading_complete) {
        // Loading: just the logo assembling
        state.logo_anim.draw();
        return;
    }

    // Subtle dot grid background
    drawSubtleDotGrid(state.time);

    // Logo with hover interaction
    state.logo_anim.applyMouse(mx, my, dt, mouse_pressed);
    state.logo_anim.draw();

    // Formula particles orbiting in Fibonacci spiral
    {
        const fcx = @as(f32, @floatFromInt(g_width)) / 2;
        const fcy = @as(f32, @floatFromInt(g_height)) / 2;
        const formula_click = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
        for (&state.formula_particles) |*fp| {
            fp.update(dt, state.time, mx, my, formula_click, fcx, fcy);
            fp.draw(state.time, fcx, fcy, state.font_small);
        }
    }

    // Theme toggle button (top-right)
    drawThemeToggle();

    // Keyboard hint (top-left)
    rl.DrawTextEx(state.font_small, "TRINITY Canvas WASM | Click petals | Click formulas", .{ .x = 10, .y = 10 }, 13, 1, withAlpha(TEXT_DIM, 180));

    // Status bar (bottom)
    drawStatusBar(state);
}

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================

// Entry point: pub fn main for std.start (native), comptime @export for emscripten.
pub fn main() void {
    trinityMain();
}

fn trinityMain() void {
    // Raylib init
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(1280, 800, "TRINITY WASM v1.0 | phi^2 + 1/phi^2 = 3");

    rl.SetExitKey(0);
    rl.SetWindowMinSize(800, 600);

    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // HiDPI detection (skip on Emscripten -- browser handles scaling)
    if (builtin.os.tag != .emscripten) {
        const dpi_scale_v = rl.GetWindowScaleDPI();
        g_dpi_scale = @max(dpi_scale_v.x, dpi_scale_v.y);
        if (g_dpi_scale < 1.0) g_dpi_scale = 1.0;
    }

    const font_size_large: c_int = @intFromFloat(48.0 * g_dpi_scale);
    const font_size_small: c_int = @intFromFloat(32.0 * g_dpi_scale);

    // Load fonts
    const font = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", font_size_large, null, 0);
    const font_small = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", font_size_small, null, 0);
    rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_BILINEAR);
    rl.SetTextureFilter(font_small.texture, rl.TEXTURE_FILTER_BILINEAR);

    rl.SetTargetFPS(60);
    rl.ShowCursor();

    // Initialize logo animation
    const logo_anim = LogoAnimation.init(@floatFromInt(g_width), @floatFromInt(g_height));

    // Initialize formula particles (Fibonacci spiral)
    var formula_particles: [MAX_FORMULA_PARTICLES]FormulaParticle = undefined;
    const golden_angle: f32 = 2.0 * std.math.pi / (1.618 * 1.618);
    const min_radius: f32 = 240.0;
    for (0..42) |fi| {
        const n = @as(f32, @floatFromInt(fi));
        const angle = n * golden_angle;
        const radius = min_radius + n * 14.0;
        const layer = fi / 9;
        const direction: f32 = if (layer % 2 == 0) 1.0 else -1.0;
        const speed: f32 = direction * (0.03 - n * 0.0003);
        formula_particles[fi] = FormulaParticle.init(
            formula_texts[fi],
            formula_descs[fi],
            angle,
            radius,
            speed,
        );
    }

    // Build state struct
    var state = GameState{
        .logo_anim = logo_anim,
        .formula_particles = formula_particles,
        .loading_complete = false,
        .time = 0,
        .font = font,
        .font_small = font_small,
    };

    g_state = &state;

    // Emscripten main loop vs native loop
    if (builtin.os.tag == .emscripten) {
        emc.emscripten_set_main_loop(updateDrawFrame, 0, true);
    } else {
        while (!rl.WindowShouldClose()) {
            updateDrawFrame();
        }
    }

    // Cleanup (only reached on native)
    rl.UnloadFont(font);
    rl.UnloadFont(font_small);
    rl.CloseWindow();
}
