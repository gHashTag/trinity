// =============================================================================
// TRINITY CANVAS v2.0 - HYPER TERMINAL STYLE (MODULAR)
// Colors imported from theme.zig - SINGLE SOURCE OF TRUTH
// Shift+1-8 = Panel Focus (Chat, Code, Tools, Settings, Vision, Voice, Finder, System)
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const photon = @import("photon.zig");
const theme = @import("trinity_canvas/theme.zig"); // SINGLE SOURCE OF TRUTH
const math = std.math;
const rl = @cImport({
    @cInclude("raylib.h");
});

// =============================================================================
// COSMIC CONSTANTS (from theme.zig)
// =============================================================================

const PHI: f32 = theme.PHI;
const PHI_INV: f32 = theme.PHI_INV;
const TAU: f32 = theme.TAU;

// Grid fills ENTIRE screen
var g_width: c_int = 1512;
var g_height: c_int = 982;
var g_pixel_size: c_int = 4;

// =============================================================================
// HYPER TERMINAL STYLE COLORS (from theme.zig - SINGLE SOURCE OF TRUTH)
// @bitCast converts theme.Color to rl.Color (same extern struct layout)
// =============================================================================

fn toRl(c: theme.Color) rl.Color {
    return @bitCast(c);
}

const BG_BLACK: rl.Color = @bitCast(theme.colors.bg);
const TEXT_WHITE: rl.Color = @bitCast(theme.colors.text);
const HYPER_MAGENTA: rl.Color = @bitCast(theme.colors.magenta);
const HYPER_CYAN: rl.Color = @bitCast(theme.colors.cyan);
const HYPER_GREEN: rl.Color = @bitCast(theme.colors.green);
const HYPER_YELLOW: rl.Color = @bitCast(theme.colors.yellow);
const HYPER_RED: rl.Color = @bitCast(theme.colors.red);
const MUTED_GRAY: rl.Color = @bitCast(theme.colors.text_muted);
const BORDER_SUBTLE: rl.Color = @bitCast(theme.colors.border);

// Legacy aliases (all point to theme.zig via @bitCast)
const VOID_BLACK: rl.Color = @bitCast(theme.colors.bg);
const ACCENT_GREEN: rl.Color = @bitCast(theme.colors.green);
const NEON_CYAN: rl.Color = @bitCast(theme.colors.cyan);
const NEON_MAGENTA: rl.Color = @bitCast(theme.colors.magenta);
const NEON_GREEN: rl.Color = @bitCast(theme.colors.green);
const NEON_GOLD: rl.Color = @bitCast(theme.colors.yellow);
const NEON_PURPLE: rl.Color = @bitCast(theme.colors.magenta);
const NOVA_WHITE: rl.Color = @bitCast(theme.colors.text);
const SINK_RED: rl.Color = @bitCast(theme.colors.red);

// Glass colors (from theme.zig via @bitCast)
const GLASS_BG: rl.Color = @bitCast(theme.colors.bg_panel);
const GLASS_BORDER: rl.Color = @bitCast(theme.colors.border);
const GLASS_GLOW: rl.Color = @bitCast(theme.colors.glow_magenta);

// Additional Hyper UI colors
const BG_SURFACE: rl.Color = @bitCast(theme.colors.bg_surface);
const BG_INPUT: rl.Color = @bitCast(theme.colors.bg_input);
const BG_BAR: rl.Color = @bitCast(theme.colors.bg_bar);
const BG_HOVER: rl.Color = @bitCast(theme.colors.bg_hover);
const SEPARATOR: rl.Color = @bitCast(theme.colors.separator);
const BORDER_LIGHT: rl.Color = @bitCast(theme.colors.border_light);
const TEXT_DIM: rl.Color = @bitCast(theme.colors.text_dim);
const TEXT_HINT: rl.Color = @bitCast(theme.colors.text_hint);
const CONTENT_TEXT: rl.Color = @bitCast(theme.colors.content_text);
const RECORDING_RED: rl.Color = @bitCast(theme.colors.recording_red);
const GOLD: rl.Color = @bitCast(theme.colors.gold);
const BLUE: rl.Color = @bitCast(theme.colors.blue);
const ORANGE: rl.Color = @bitCast(theme.colors.orange);
const PURPLE: rl.Color = @bitCast(theme.colors.purple);
const LOGO_GREEN: rl.Color = @bitCast(theme.colors.logo_green);

// Panel traffic light buttons
const BTN_CLOSE: rl.Color = @bitCast(theme.panel.btn_close);
const BTN_MINIMIZE: rl.Color = @bitCast(theme.panel.btn_minimize);
const BTN_MAXIMIZE: rl.Color = @bitCast(theme.panel.btn_maximize);

// File type colors (Hyper palette)
const FILE_FOLDER: rl.Color = @bitCast(theme.colors.file_folder);
const FILE_ZIG: rl.Color = @bitCast(theme.colors.file_zig);
const FILE_CODE: rl.Color = @bitCast(theme.colors.file_code);
const FILE_IMAGE: rl.Color = @bitCast(theme.colors.file_image);
const FILE_AUDIO: rl.Color = @bitCast(theme.colors.file_audio);
const FILE_DOCUMENT: rl.Color = @bitCast(theme.colors.file_document);
const FILE_DATA: rl.Color = @bitCast(theme.colors.file_data);
const FILE_UNKNOWN: rl.Color = @bitCast(theme.colors.file_unknown);

// Helper: apply runtime alpha to a color
fn withAlpha(c: rl.Color, alpha: u8) rl.Color {
    return rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = alpha };
}

// =============================================================================
// TRINITY LOGO ANIMATION — 27 BLOCKS ASSEMBLY
// Logo assembles from 27 triangular blocks flying from all sides
// =============================================================================

const LogoBlock = struct {
    // Polygon vertices (up to 5 points per shape)
    v: [5]rl.Vector2,
    count: u8,
    // Animation state
    offset: rl.Vector2, // Current animated offset from target
    rotation: f32, // Current rotation
    scale: f32, // Current scale
    delay: f32, // Animation start delay
    center: rl.Vector2, // Center of the block for positioning
    // Assembly animation velocity (spring physics)
    anim_vx: f32,
    anim_vy: f32,
    anim_vr: f32,
    // Cursor physics
    push_x: f32, // Current push displacement from cursor
    push_y: f32,
    push_rot: f32, // Rotation from cursor push
    vel_x: f32, // Velocity for spring-back
    vel_y: f32,
    vel_rot: f32,
};

const LogoAnimation = struct {
    blocks: [27]LogoBlock,
    time: f32,
    duration: f32,
    is_complete: bool,
    logo_scale: f32, // Scale the logo to fit screen
    logo_offset: rl.Vector2, // Center the logo on screen
    hovered_block: i32, // Index of block under cursor (-1 = none)

    // SVG viewBox: 596 x 526, center at ~298, 263
    const SVG_WIDTH: f32 = 596.0;
    const SVG_HEIGHT: f32 = 526.0;
    const SVG_CENTER_X: f32 = 298.0;
    const SVG_CENTER_Y: f32 = 263.0;

    pub fn init(screen_w: f32, screen_h: f32) LogoAnimation {
        var self = LogoAnimation{
            .blocks = undefined,
            .time = 0,
            .duration = 5.0, // Luxury slow animation (Apple-style)
            .is_complete = false,
            .logo_scale = @min(screen_w / SVG_WIDTH, screen_h / SVG_HEIGHT) * 0.35,
            .logo_offset = .{ .x = screen_w / 2, .y = screen_h / 2 },
            .hovered_block = -1,
        };

        // 27 blocks parsed from assets/999.svg
        const raw_blocks = [27][5][2]f32{
            // Block 0
            .{ .{ 296.767, 435.228 }, .{ 236.563, 329.491 }, .{ 211.501, 373.56 }, .{ 296.767, 523.496 }, .{ 0, 0 } },
            // Block 1
            .{ .{ 235.71, 328.065 }, .{ 177.201, 224.57 }, .{ 126.893, 224.57 }, .{ 210.755, 372.182 }, .{ 0, 0 } },
            // Block 2
            .{ .{ 116.304, 118.557 }, .{ 175.824, 223.238 }, .{ 126.022, 223.26 }, .{ 42.177, 74.909 }, .{ 0, 0 } },
            // Block 3
            .{ .{ 43.019, 73.555 }, .{ 117.106, 116.68 }, .{ 235.544, 116.68 }, .{ 211.46, 73.525 }, .{ 0, 0 } },
            // Block 4
            .{ .{ 213.1, 73.52 }, .{ 237.875, 116.409 }, .{ 356.58, 116.741 }, .{ 381.646, 73.509 }, .{ 0, 0 } },
            // Block 5
            .{ .{ 477.724, 116.854 }, .{ 358.701, 116.802 }, .{ 383.404, 73.803 }, .{ 550.969, 73.877 }, .{ 0, 0 } },
            // Block 6
            .{ .{ 477.056, 118.915 }, .{ 418.023, 223.109 }, .{ 468.886, 223.131 }, .{ 553.143, 74.338 }, .{ 0, 0 } },
            // Block 7
            .{ .{ 358.646, 327.197 }, .{ 384.221, 372.152 }, .{ 468.192, 224.521 }, .{ 416.976, 224.579 }, .{ 0, 0 } },
            // Block 8
            .{ .{ 298.138, 434.656 }, .{ 357.793, 328.533 }, .{ 383.376, 373.808 }, .{ 298.138, 523.876 }, .{ 0, 0 } },
            // Block 9
            .{ .{ 297.148, 352.965 }, .{ 260.326, 288.171 }, .{ 237.943, 327.796 }, .{ 297.148, 432.004 }, .{ 0, 0 } },
            // Block 10
            .{ .{ 259.613, 286.78 }, .{ 224.371, 224.818 }, .{ 179.6, 224.818 }, .{ 237.048, 326.301 }, .{ 0, 0 } },
            // Block 11
            .{ .{ 223.536, 223.354 }, .{ 187.285, 159.675 }, .{ 120.085, 120.508 }, .{ 178.781, 223.779 }, .{ 0, 0 } },
            // Block 12
            .{ .{ 121.863, 119.193 }, .{ 187.937, 158.358 }, .{ 260.042, 158.355 }, .{ 237.348, 118.746 }, .{ 0, 0 } },
            // Block 13
            .{ .{ 261.857, 158.313 }, .{ 333.559, 158.29 }, .{ 356.01, 118.829 }, .{ 239.269, 118.829 }, .{ 0, 0 } },
            // Block 14
            .{ .{ 335.294, 158.3 }, .{ 407.736, 158.226 }, .{ 474.496, 118.923 }, .{ 357.761, 118.923 }, .{ 0, 0 } },
            // Block 15
            .{ .{ 408.358, 159.547 }, .{ 372.034, 223.421 }, .{ 416.476, 223.315 }, .{ 475.012, 120.916 }, .{ 0, 0 } },
            // Block 16
            .{ .{ 336.052, 286.778 }, .{ 358.165, 325.872 }, .{ 415.649, 224.808 }, .{ 371.244, 224.759 }, .{ 0, 0 } },
            // Block 17
            .{ .{ 298.893, 352.826 }, .{ 335.156, 288.19 }, .{ 357.382, 327.328 }, .{ 298.893, 430.179 }, .{ 0, 0 } },
            // Block 18
            .{ .{ 296.258, 272.716 }, .{ 282.337, 248.309 }, .{ 260.496, 286.972 }, .{ 296.258, 349.653 }, .{ 0, 0 } },
            // Block 19
            .{ .{ 259.547, 285.675 }, .{ 281.633, 246.705 }, .{ 269.336, 225.016 }, .{ 225.274, 224.996 }, .{ 0, 0 } },
            // Block 20
            .{ .{ 254.956, 199.798 }, .{ 268.406, 223.578 }, .{ 224.465, 223.598 }, .{ 189.037, 161.206 }, .{ 0, 0 } },
            // Block 21
            .{ .{ 255.476, 198.549 }, .{ 282.068, 198.538 }, .{ 260.192, 160.039 }, .{ 189.751, 160.07 }, .{ 0, 0 } },
            // Block 22
            .{ .{ 261.646, 160.062 }, .{ 283.582, 198.505 }, .{ 309.702, 198.505 }, .{ 331.733, 160.062 }, .{ 0, 0 } },
            // Block 23
            .{ .{ 338.542, 198.607 }, .{ 311.435, 198.595 }, .{ 333.423, 160.068 }, .{ 404.244, 160.099 }, .{ 0, 0 } },
            // Block 24
            .{ .{ 338.85, 199.978 }, .{ 325.556, 223.591 }, .{ 369.518, 223.61 }, .{ 404.907, 161.243 }, .{ 0, 0 } },
            // Block 25
            .{ .{ 334.38, 285.625 }, .{ 312.392, 246.733 }, .{ 324.681, 224.989 }, .{ 368.779, 224.969 }, .{ 0, 0 } },
            // Block 26
            .{ .{ 298.025, 272.637 }, .{ 311.561, 248.279 }, .{ 333.297, 287.01 }, .{ 298.025, 349.402 }, .{ 0, 0 } },
        };
        const counts = [27]u8{ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 };

        for (0..27) |i| {
            var center_x: f32 = 0;
            var center_y: f32 = 0;
            const cnt = counts[i];

            // Convert raw vertices to rl.Vector2 and center relative to SVG center
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

            // Each block flies straight from its own direction — no chaos
            // Direction = from center through block's position, extended far out
            const dir_len = @sqrt(center_x * center_x + center_y * center_y);
            const norm_x = if (dir_len > 0.1) center_x / dir_len else @cos(@as(f32, @floatFromInt(i)) * TAU / 27.0);
            const norm_y = if (dir_len > 0.1) center_y / dir_len else @sin(@as(f32, @floatFromInt(i)) * TAU / 27.0);
            const distance: f32 = 1200.0; // Same distance for all — clean formation
            self.blocks[i].offset = .{
                .x = norm_x * distance,
                .y = norm_y * distance,
            };
            self.blocks[i].rotation = 0; // No rotation — flat, clean
            self.blocks[i].scale = 1.0; // Full size from start
            self.blocks[i].delay = 0; // All start simultaneously
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

            // Two phases:
            // Phase 1 (0–0.7): straight linear flight toward center
            // Phase 2 (0.7–1.0): spring compression + bounce
            const arrival = 0.7; // when blocks "arrive" and spring kicks in

            if (progress < arrival) {
                // Straight linear flight — each block slides to its place
                const speed = 2.0 * dt;
                block.offset.x -= block.offset.x * speed;
                block.offset.y -= block.offset.y * speed;

                // Carry momentum into spring phase
                block.anim_vx = -block.offset.x * 0.3;
                block.anim_vy = -block.offset.y * 0.3;
                block.anim_vr = 0;
            } else {
                // Spring phase — elastic bounce at destination
                const spring_k: f32 = 18.0;
                const damp: f32 = 0.90;

                // Spring force pulls offset to zero
                block.anim_vx += (-block.offset.x * spring_k) * dt;
                block.anim_vy += (-block.offset.y * spring_k) * dt;
                block.anim_vx *= damp;
                block.anim_vy *= damp;
                block.offset.x += block.anim_vx * dt * 60.0;
                block.offset.y += block.anim_vy * dt * 60.0;

                // Spring on rotation
                block.anim_vr += (-block.rotation * spring_k) * dt;
                block.anim_vr *= damp;
                block.rotation += block.anim_vr * dt * 60.0;

                // Scale settles to 1.0
                block.scale += (1.0 - block.scale) * 0.1;
            }

            // Check if settled
            const dist = @sqrt(block.offset.x * block.offset.x + block.offset.y * block.offset.y);
            const vel = @sqrt(block.anim_vx * block.anim_vx + block.anim_vy * block.anim_vy);
            if (dist > 0.3 or vel > 0.3 or @abs(block.rotation) > 0.003) {
                all_done = false;
            }
        }

        // Linger for 1.5s after assembly (Apple-style pause before transition)
        if (all_done and self.time > self.duration + 1.5) {
            self.is_complete = true;
        }
    }

    /// Point-in-polygon test (ray casting)
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

    /// Highlight block under cursor (no physics — just detect hover)
    pub fn applyMouse(self: *LogoAnimation, mouse_x: f32, mouse_y: f32, _: f32) void {
        const scale = self.logo_scale;
        const ox = self.logo_offset.x;
        const oy = self.logo_offset.y;

        self.hovered_block = -1;

        for (self.blocks, 0..) |block, i| {
            var verts: [5]rl.Vector2 = undefined;
            const cnt = block.count;

            for (0..cnt) |j| {
                const bx = block.v[j].x * block.scale + block.offset.x;
                const by = block.v[j].y * block.scale + block.offset.y;
                verts[j] = .{
                    .x = ox + bx * scale,
                    .y = oy + by * scale,
                };
            }

            if (pointInPoly(verts, cnt, mouse_x, mouse_y)) {
                self.hovered_block = @intCast(i);
            }
        }
    }

    pub fn draw(self: *const LogoAnimation) void {
        const scale = self.logo_scale;
        const ox = self.logo_offset.x;
        const oy = self.logo_offset.y;

        // Base color #08FAB5, highlight color #08FAE6
        const base_color = rl.Color{ .r = 0x08, .g = 0xFA, .b = 0xB5, .a = 255 };
        const highlight_color = rl.Color{ .r = 0xFF, .g = 0x69, .b = 0xB4, .a = 255 };

        // Black outline — clear separation between parts
        const outline_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

        for (self.blocks, 0..) |block, idx| {
            const fill_color = if (self.hovered_block >= 0 and idx == @as(usize, @intCast(self.hovered_block))) highlight_color else base_color;
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

                verts[j] = .{
                    .x = ox + bx * scale,
                    .y = oy + by * scale,
                };
            }

            // Fill
            if (cnt >= 3) {
                var k: usize = 1;
                while (k < cnt - 1) : (k += 1) {
                    rl.DrawTriangle(verts[0], verts[k], verts[k + 1], fill_color);
                    rl.DrawTriangle(verts[0], verts[k + 1], verts[k], fill_color);
                }
            }

            // Transparent outline
            var m: usize = 0;
            while (m < cnt) : (m += 1) {
                const next = (m + 1) % cnt;
                rl.DrawLineEx(verts[m], verts[next], 5.0, outline_color);
            }
        }
    }
};

// =============================================================================
// ADVANCED WINDOW SYSTEM - GLASSMORPHISM PANELS
// Floating невесомые windows with phi-based animations
// =============================================================================

const MAX_PANELS = 8;
const PANEL_RADIUS: f32 = 16.0;

const PanelState = enum {
    closed,
    opening,
    open,
    closing,
    minimizing,
    maximizing,
};

const PanelType = enum {
    chat, // Chat with AI - input/output
    code, // Code editor - syntax highlight
    tools, // Tool execution - list + run
    settings, // App settings - toggles
    vision, // Image analysis - load + describe
    voice, // Voice - STT/TTS waves
    finder, // Emergent Finder - wave-based file system
    system, // System monitor - CPU, Memory, Temperature
};

// =============================================================================
// EMERGENT FINDER - Wave-Based File System Visualization
// Folders = concentric rings, Files = orbiting photons
// =============================================================================

const FileType = enum {
    folder,
    code_zig,
    code_other,
    image,
    audio,
    document,
    data,
    unknown,

    pub fn fromName(name: []const u8) FileType {
        if (name.len < 2) return .unknown;
        // Check extension
        var i: usize = name.len - 1;
        while (i > 0) : (i -= 1) {
            if (name[i] == '.') break;
        }
        if (i == 0) return .folder; // No extension = likely folder
        const ext = name[i..];
        if (std.mem.eql(u8, ext, ".zig")) return .code_zig;
        if (std.mem.eql(u8, ext, ".rs") or std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".cpp") or std.mem.eql(u8, ext, ".h") or std.mem.eql(u8, ext, ".py") or std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".ts")) return .code_other;
        if (std.mem.eql(u8, ext, ".png") or std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".gif") or std.mem.eql(u8, ext, ".svg") or std.mem.eql(u8, ext, ".ico")) return .image;
        if (std.mem.eql(u8, ext, ".mp3") or std.mem.eql(u8, ext, ".wav") or std.mem.eql(u8, ext, ".ogg") or std.mem.eql(u8, ext, ".flac")) return .audio;
        if (std.mem.eql(u8, ext, ".md") or std.mem.eql(u8, ext, ".txt") or std.mem.eql(u8, ext, ".pdf") or std.mem.eql(u8, ext, ".doc")) return .document;
        if (std.mem.eql(u8, ext, ".json") or std.mem.eql(u8, ext, ".toml") or std.mem.eql(u8, ext, ".yaml") or std.mem.eql(u8, ext, ".xml")) return .data;
        return .unknown;
    }

    pub fn getColor(self: FileType) rl.Color {
        return switch (self) {
            .folder => FILE_FOLDER,
            .code_zig => FILE_ZIG,
            .code_other => FILE_CODE,
            .image => FILE_IMAGE,
            .audio => FILE_AUDIO,
            .document => FILE_DOCUMENT,
            .data => FILE_DATA,
            .unknown => FILE_UNKNOWN,
        };
    }

    pub fn getIcon(self: FileType) u8 {
        return switch (self) {
            .folder => 'D',
            .code_zig => 'Z',
            .code_other => 'C',
            .image => 'I',
            .audio => 'A',
            .document => 'T',
            .data => 'J',
            .unknown => '?',
        };
    }
};

const FinderEntry = struct {
    name: [128]u8,
    name_len: usize,
    is_dir: bool,
    file_type: FileType,
    orbit_angle: f32, // For wave animation
    orbit_radius: f32, // Distance from center

    pub fn init() FinderEntry {
        return .{
            .name = undefined,
            .name_len = 0,
            .is_dir = false,
            .file_type = .unknown,
            .orbit_angle = 0,
            .orbit_radius = 0,
        };
    }
};

const GlassPanel = struct {
    // Position & size
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    // Target position (for animations)
    target_x: f32,
    target_y: f32,
    target_w: f32,
    target_h: f32,

    // Animation
    state: PanelState,
    anim_t: f32, // 0..1
    opacity: f32,
    scale: f32,

    // Content
    panel_type: PanelType,
    title: [64]u8,
    title_len: usize,

    // Interaction
    dragging: bool,
    drag_offset_x: f32,
    drag_offset_y: f32,

    // Velocity for swipe inertia
    vel_x: f32,
    vel_y: f32,

    // Resize
    resizing: bool,
    resize_edge: u8, // 0=none, 1=right, 2=bottom, 4=left, 8=top, combos for corners

    // Content data
    content_text: [512]u8,
    content_len: usize,
    scroll_y: f32,

    // For tools panel
    tool_selected: usize,

    // For voice panel
    voice_amplitude: f32,
    voice_recording: bool,
    voice_wave_phase: f32,

    // For chat panel - multi-modal content
    chat_messages: [8][256]u8,
    chat_msg_lens: [8]usize,
    chat_msg_is_user: [8]bool,
    chat_msg_count: usize,
    chat_input: [256]u8,
    chat_input_len: usize,
    chat_ripple: f32, // Response ripple animation

    // For code panel - syntax waves
    code_wave_phase: f32,
    code_cursor_line: usize,

    // For vision panel
    vision_analyzing: bool,
    vision_progress: f32,
    vision_result: [256]u8,
    vision_result_len: usize,

    // Focus state for full-screen transitions
    is_focused: bool,
    focus_ripple: f32,
    pre_focus_x: f32,
    pre_focus_y: f32,
    pre_focus_w: f32,
    pre_focus_h: f32,

    // JARVIS spherical morph animation
    jarvis_morph: f32, // 0 = sphere, 1 = rectangle
    jarvis_glow_pulse: f32,
    jarvis_ring_rotation: f32,

    // For finder panel
    finder_path: [512]u8,
    finder_path_len: usize,
    finder_entries: [64]FinderEntry,
    finder_entry_count: usize,
    finder_selected: usize,
    finder_animation: f32,
    finder_ripple: f32, // 0-1 ripple animation on folder open

    // For system monitor panel
    sys_cpu_usage: f32, // 0-100%
    sys_mem_used: f32, // GB
    sys_mem_total: f32, // GB
    sys_cpu_temp: f32, // Celsius
    sys_update_timer: f32, // Timer for updates

    pub fn init(px: f32, py: f32, pw: f32, ph: f32, ptype: PanelType, title_str: []const u8) GlassPanel {
        var panel = GlassPanel{
            .x = px,
            .y = py,
            .width = pw,
            .height = ph,
            .target_x = px,
            .target_y = py,
            .target_w = pw,
            .target_h = ph,
            .state = .closed,
            .anim_t = 0,
            .opacity = 0,
            .scale = 0.8,
            .panel_type = ptype,
            .title = undefined,
            .title_len = @min(title_str.len, 63),
            .dragging = false,
            .drag_offset_x = 0,
            .drag_offset_y = 0,
            .vel_x = 0,
            .vel_y = 0,
            .resizing = false,
            .resize_edge = 0,
            .content_text = undefined,
            .content_len = 0,
            .scroll_y = 0,
            .tool_selected = 0,
            .voice_amplitude = 0,
            .voice_recording = false,
            .voice_wave_phase = 0,
            .chat_messages = undefined,
            .chat_msg_lens = .{0} ** 8,
            .chat_msg_is_user = .{false} ** 8,
            .chat_msg_count = 0,
            .chat_input = undefined,
            .chat_input_len = 0,
            .chat_ripple = 0,
            .code_wave_phase = 0,
            .code_cursor_line = 0,
            .vision_analyzing = false,
            .vision_progress = 0,
            .vision_result = undefined,
            .vision_result_len = 0,
            .is_focused = false,
            .focus_ripple = 0,
            .pre_focus_x = px,
            .pre_focus_y = py,
            .pre_focus_w = pw,
            .pre_focus_h = ph,
            .jarvis_morph = 1.0, // Start as rectangle
            .jarvis_glow_pulse = 0,
            .jarvis_ring_rotation = 0,
            .finder_path = undefined,
            .finder_path_len = 0,
            .finder_entries = undefined,
            .finder_entry_count = 0,
            .finder_selected = 0,
            .finder_animation = 0,
            .finder_ripple = 0,
            .sys_cpu_usage = 0,
            .sys_mem_used = 0,
            .sys_mem_total = 16.0, // Default 16GB
            .sys_cpu_temp = 45.0, // Default temp
            .sys_update_timer = 0,
        };
        @memcpy(panel.title[0..panel.title_len], title_str[0..panel.title_len]);
        panel.title[panel.title_len] = 0;

        // Initialize finder entries
        for (&panel.finder_entries) |*entry| {
            entry.* = FinderEntry.init();
        }

        // Default content based on type
        const default_content = switch (ptype) {
            .chat => "Type a message...",
            .code => "// Your code here\nfn main() void {\n    \n}",
            .tools => "inference\nembedding\nsearch\ngenerate",
            .settings => "Dark Mode: ON\nSound: OFF\nAnimations: ON",
            .vision => "Drop image or click to load...",
            .voice => "Press to speak...",
            .finder => "Loading directory...",
            .system => "System monitor",
        };

        // Initialize finder with current directory for finder panels
        if (ptype == .finder) {
            panel.loadDirectory(".");
        }
        const content_copy_len = @min(default_content.len, 511);
        @memcpy(panel.content_text[0..content_copy_len], default_content[0..content_copy_len]);
        panel.content_len = content_copy_len;

        return panel;
    }

    // Phi-based easing (smooth cosmic feel)
    fn easePhiInOut(t: f32) f32 {
        if (t < 0.5) {
            return 2.0 * t * t * PHI_INV;
        } else {
            const f = -2.0 * t + 2.0;
            return 1.0 - (f * f * PHI_INV) / 2.0;
        }
    }

    pub fn open(self: *GlassPanel) void {
        if (self.state == .closed or self.state == .closing) {
            self.state = .opening;
            self.anim_t = 0;
        }
    }

    pub fn close(self: *GlassPanel) void {
        if (self.state == .open or self.state == .opening) {
            self.state = .closing;
            self.anim_t = 0;
        }
    }

    pub fn minimize(self: *GlassPanel) void {
        if (self.state == .open) {
            self.state = .minimizing;
            self.anim_t = 0;
            self.target_y = @as(f32, @floatFromInt(g_height)) + 100;
        }
    }

    // Focus panel to full screen with cosmic transition
    pub fn focus(self: *GlassPanel) void {
        if (!self.is_focused and self.state == .open) {
            // Save current position for restoration
            self.pre_focus_x = self.x;
            self.pre_focus_y = self.y;
            self.pre_focus_w = self.width;
            self.pre_focus_h = self.height;
            // Set target to full screen with margin
            self.target_x = 20;
            self.target_y = 40;
            self.target_w = @as(f32, @floatFromInt(g_width)) - 40;
            self.target_h = @as(f32, @floatFromInt(g_height)) - 100;
            self.is_focused = true;
            self.focus_ripple = 1.0;
        }
    }

    // Unfocus panel - restore to previous position
    pub fn unfocus(self: *GlassPanel) void {
        if (self.is_focused) {
            self.target_x = self.pre_focus_x;
            self.target_y = self.pre_focus_y;
            self.target_w = self.pre_focus_w;
            self.target_h = self.pre_focus_h;
            self.is_focused = false;
            self.focus_ripple = 1.0;
            self.jarvis_morph = 1.0; // Rectangle
        }
    }

    // JARVIS-style focus with spherical morph animation
    pub fn jarvisFocus(self: *GlassPanel) void {
        // Save current position for restoration
        if (!self.is_focused) {
            self.pre_focus_x = self.x;
            self.pre_focus_y = self.y;
            self.pre_focus_w = self.width;
            self.pre_focus_h = self.height;
        }
        // Set target to full screen with margin
        self.target_x = 20;
        self.target_y = 40;
        self.target_w = @as(f32, @floatFromInt(g_width)) - 40;
        self.target_h = @as(f32, @floatFromInt(g_height)) - 100;
        self.is_focused = true;
        self.focus_ripple = 1.0;
        // Start from sphere (0) and morph to rectangle (1)
        self.jarvis_morph = 0;
        self.jarvis_glow_pulse = 1.0;
    }

    // Add chat message with response ripple
    pub fn addChatMessage(self: *GlassPanel, msg: []const u8, is_user: bool) void {
        if (self.chat_msg_count >= 8) {
            // Shift messages up
            for (0..7) |i| {
                @memcpy(&self.chat_messages[i], &self.chat_messages[i + 1]);
                self.chat_msg_lens[i] = self.chat_msg_lens[i + 1];
                self.chat_msg_is_user[i] = self.chat_msg_is_user[i + 1];
            }
            self.chat_msg_count = 7;
        }
        const idx = self.chat_msg_count;
        const copy_len = @min(msg.len, 255);
        @memcpy(self.chat_messages[idx][0..copy_len], msg[0..copy_len]);
        self.chat_msg_lens[idx] = copy_len;
        self.chat_msg_is_user[idx] = is_user;
        self.chat_msg_count += 1;
        // Trigger response ripple for AI responses
        if (!is_user) {
            self.chat_ripple = 1.0;
        }
    }

    pub fn update(self: *GlassPanel, dt: f32) void {
        const anim_speed: f32 = 3.0; // Animation duration ~0.33s

        switch (self.state) {
            .opening => {
                self.anim_t += dt * anim_speed;
                if (self.anim_t >= 1.0) {
                    self.anim_t = 1.0;
                    self.state = .open;
                }
                const e = easePhiInOut(self.anim_t);
                self.opacity = e;
                self.scale = 0.8 + e * 0.2;
            },
            .closing => {
                self.anim_t += dt * anim_speed;
                if (self.anim_t >= 1.0) {
                    self.anim_t = 1.0;
                    self.state = .closed;
                }
                const e = easePhiInOut(self.anim_t);
                self.opacity = 1.0 - e;
                self.scale = 1.0 - e * 0.2;
            },
            .minimizing => {
                self.anim_t += dt * anim_speed;
                if (self.anim_t >= 1.0) {
                    self.state = .closed;
                }
                const e = easePhiInOut(self.anim_t);
                self.y = self.y + (self.target_y - self.y) * e * 0.3;
                self.opacity = 1.0 - e;
                self.scale = 1.0 - e * 0.5;
            },
            .open => {
                self.opacity = 1.0;
                self.scale = 1.0;

                // === JARVIS FOCUS TRANSITION ANIMATION ===
                const focus_speed: f32 = 4.0; // Phi-smooth transition
                if (self.is_focused or self.focus_ripple > 0) {
                    // Animate position and size towards target
                    const lerp_factor = dt * focus_speed;
                    self.x += (self.target_x - self.x) * lerp_factor;
                    self.y += (self.target_y - self.y) * lerp_factor;
                    self.width += (self.target_w - self.width) * lerp_factor;
                    self.height += (self.target_h - self.height) * lerp_factor;
                    // Decay focus ripple
                    if (self.focus_ripple > 0) {
                        self.focus_ripple -= dt * 1.5;
                        if (self.focus_ripple < 0) self.focus_ripple = 0;
                    }
                }

                // JARVIS spherical morph (0 = sphere → 1 = rectangle)
                if (self.jarvis_morph < 1.0) {
                    self.jarvis_morph += dt * 2.5;
                    if (self.jarvis_morph > 1.0) self.jarvis_morph = 1.0;
                }

                // JARVIS glow pulse decay
                if (self.jarvis_glow_pulse > 0) {
                    self.jarvis_glow_pulse -= dt * 1.2;
                    if (self.jarvis_glow_pulse < 0) self.jarvis_glow_pulse = 0;
                }

                // JARVIS ring rotation (continuous)
                if (self.is_focused) {
                    self.jarvis_ring_rotation += dt * 2.0;
                }

                // === MULTI-MODAL CONTENT ANIMATIONS ===

                // Chat ripple animation
                if (self.chat_ripple > 0) {
                    self.chat_ripple -= dt * 2.0;
                    if (self.chat_ripple < 0) self.chat_ripple = 0;
                }

                // Code wave phase (continuous syntax animation)
                if (self.panel_type == .code) {
                    self.code_wave_phase += dt * 2.0;
                }

                // Vision analyzing progress
                if (self.vision_analyzing) {
                    self.vision_progress += dt * 0.5;
                    if (self.vision_progress >= 1.0) {
                        self.vision_analyzing = false;
                        self.vision_progress = 1.0;
                        // Set result
                        const result = "Cosmic image analyzed: wave patterns detected!";
                        @memcpy(self.vision_result[0..result.len], result);
                        self.vision_result_len = result.len;
                    }
                }

                // Voice wave phase and amplitude
                if (self.panel_type == .voice) {
                    self.voice_wave_phase += dt * 8.0;
                    if (self.voice_recording) {
                        // Simulate audio amplitude
                        self.voice_amplitude = 0.5 + @sin(self.voice_wave_phase) * 0.3;
                    } else {
                        self.voice_amplitude *= 0.9; // Decay
                    }
                }

                // Animate finder entries appearing
                if (self.panel_type == .finder and self.finder_animation < 1.0) {
                    self.finder_animation += dt * 2.0;
                    if (self.finder_animation > 1.0) self.finder_animation = 1.0;
                }

                // Animate finder ripple effect
                if (self.panel_type == .finder and self.finder_ripple > 0) {
                    self.finder_ripple -= dt * 1.5;
                    if (self.finder_ripple < 0) self.finder_ripple = 0;
                }

                // Apply velocity (swipe inertia) - only when not focused
                if (!self.dragging and !self.is_focused) {
                    self.x += self.vel_x * dt;
                    self.y += self.vel_y * dt;
                    // Friction
                    self.vel_x *= 0.92;
                    self.vel_y *= 0.92;

                    // Bounce off edges
                    const fw = @as(f32, @floatFromInt(g_width));
                    const fh = @as(f32, @floatFromInt(g_height));
                    if (self.x < 0) {
                        self.x = 0;
                        self.vel_x = -self.vel_x * 0.5;
                    }
                    if (self.x + self.width > fw) {
                        self.x = fw - self.width;
                        self.vel_x = -self.vel_x * 0.5;
                    }
                    if (self.y < 0) {
                        self.y = 0;
                        self.vel_y = -self.vel_y * 0.5;
                    }
                    if (self.y + self.height > fh - 60) {
                        self.y = fh - 60 - self.height;
                        self.vel_y = -self.vel_y * 0.5;
                    }
                }
            },
            .closed => {},
            .maximizing => {},
        }
    }

    pub fn draw(self: *const GlassPanel, time: f32, font: rl.Font) void {
        if (self.state == .closed) return;

        const cx = self.x + self.width / 2;
        const cy = self.y + self.height / 2;

        // Scale from center
        const sw = self.width * self.scale;
        const sh = self.height * self.scale;
        const sx = cx - sw / 2;
        const sy = cy - sh / 2;

        // Skip drawing if panel is not focused (teleportation effect - only show focused)
        if (!self.is_focused and self.state == .open) {
            return; // Hide unfocused panels completely
        }

        // Smoother rounded corners (Hyper style)
        const roundness = 0.06; // Slightly larger for smoother look

        // === FOCUS TRANSITION RIPPLE === REMOVED (Teleportation effect - instant switch)
        // if (self.focus_ripple > 0) {
        //     const ripple_progress = 1.0 - self.focus_ripple;
        //     const max_radius = @max(sw, sh);
        //     for (0..5) |ring| {
        //         const ring_f = @as(f32, @floatFromInt(ring));
        //         const ring_delay = ring_f * 0.1;
        //         const ring_progress = @max(0, @min(1.0, (ripple_progress - ring_delay) / 0.7));
        //         if (ring_progress > 0) {
        //             const ripple_radius = ring_progress * max_radius;
        //             const ripple_alpha: u8 = @intFromFloat(@max(0, self.opacity * 150 * (1.0 - ring_progress) * self.focus_ripple));
        //             const ripple_color = if (self.is_focused) rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ripple_alpha } else rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = ripple_alpha };
        //             rl.DrawCircleLines(@intFromFloat(cx), @intFromFloat(cy), ripple_radius, ripple_color);
        //         }
        //     }
        // }

        // === FOCUSED GLOW EFFECT === REMOVED (Hyper style - clean borders)
        // if (self.is_focused) {
        //     const glow_pulse = @sin(time * 3) * 0.2 + 0.8;
        //     const glow_alpha: u8 = @intFromFloat(self.opacity * 25 * glow_pulse);
        //     rl.DrawRectangleRounded(
        //         .{ .x = sx - 3, .y = sy - 3, .width = sw + 6, .height = sh + 6 },
        //         roundness, 16,
        //         rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = glow_alpha },
        //     );
        // }

        // === PROFESSIONAL GLASSMORPHISM ===

        // Shadow (soft, offset down-right)
        const shadow_offset: f32 = 4.0;
        const shadow_alpha: u8 = @intFromFloat(self.opacity * 40);
        rl.DrawRectangleRounded(
            .{ .x = sx + shadow_offset, .y = sy + shadow_offset, .width = sw, .height = sh },
            roundness, 32, // More segments for smoother corners
            rl.Color{ .r = 0, .g = 0, .b = 0, .a = shadow_alpha },
        );

        // Main glass background (Hyper style)
        const bg_alpha: u8 = @intFromFloat(self.opacity * 230);
        rl.DrawRectangleRounded(
            .{ .x = sx, .y = sy, .width = sw, .height = sh },
            roundness, 32,
            withAlpha(BG_SURFACE, bg_alpha),
        );

        // Gradient overlay REMOVED (clean Hyper style - no gradient)
        // const grad_alpha: u8 = @intFromFloat(self.opacity * 15);
        // rl.DrawRectangleRounded(
        //     .{ .x = sx, .y = sy, .width = sw, .height = sh / 3 },
        //     roundness, 32,
        //     withAlpha(TEXT_WHITE, grad_alpha),
        // );

        // Border (1px, subtle white like landing page)
        const border_alpha: u8 = @intFromFloat(self.opacity * 40);
        rl.DrawRectangleRoundedLinesEx(
            .{ .x = sx, .y = sy, .width = sw, .height = sh },
            roundness, 32, 1.0,
            rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = border_alpha },
        );

        // === TITLE BAR (Hyper style - no traffic lights) ===
        // Traffic light buttons REMOVED - use Shift+1-8 for panel switching
        // const btn_y = sy + 14;
        // const btn_spacing: f32 = 20;
        // rl.DrawCircle(@intFromFloat(sx + 16), @intFromFloat(btn_y), 6, withAlpha(BTN_CLOSE, alpha));
        // rl.DrawCircle(@intFromFloat(sx + 16 + btn_spacing), @intFromFloat(btn_y), 6, withAlpha(BTN_MINIMIZE, alpha));
        // rl.DrawCircle(@intFromFloat(sx + 16 + btn_spacing * 2), @intFromFloat(btn_y), 6, withAlpha(BTN_MAXIMIZE, alpha));

        // Title (centered)
        const title_alpha: u8 = @intFromFloat(self.opacity * 200);
        const title_width: f32 = @floatFromInt(rl.MeasureText(&self.title, 14));
        const title_x = sx + (sw - title_width) / 2;
        rl.DrawTextEx(font, &self.title, .{ .x = title_x, .y = sy + 6 }, 16, 0.5, rl.Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = title_alpha });

        // Title bar separator
        const sep_alpha: u8 = @intFromFloat(self.opacity * 30);
        rl.DrawLine(@intFromFloat(sx), @intFromFloat(sy + 32), @intFromFloat(sx + sw), @intFromFloat(sy + 32), rl.Color{ .r = 0x80, .g = 0x80, .b = 0x80, .a = sep_alpha });

        // === CONTENT AREA (Multi-Modal) ===
        const content_y = sy + 40;
        const content_h = sh - 50;
        const content_alpha: u8 = @intFromFloat(self.opacity * 180);
        const text_color = rl.Color{ .r = 0xC0, .g = 0xC8, .b = 0xD0, .a = content_alpha };

        switch (self.panel_type) {
            .chat => {
                // === MULTI-MODAL CHAT PANEL ===
                // Response ripple animation (cosmic wave on new AI message)
                if (self.chat_ripple > 0) {
                    const ripple_center_y = content_y + content_h / 2;
                    const ripple_progress = 1.0 - self.chat_ripple;
                    for (0..3) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = ripple_progress * sw * 0.5 + ring_f * 20;
                        const ring_alpha: u8 = @intFromFloat(@max(0, self.opacity * 120 * self.chat_ripple));
                        rl.DrawCircleLines(@intFromFloat(sx + sw / 2), @intFromFloat(ripple_center_y), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha });
                    }
                }

                // Messages area with scroll support
                const msg_area_h = content_h - 50;
                const msg_y_start = content_y + 5 - self.scroll_y;
                const line_spacing: f32 = 28;

                for (0..self.chat_msg_count) |i| {
                    const msg_y = msg_y_start + @as(f32, @floatFromInt(i)) * line_spacing;
                    // Skip messages outside visible area
                    if (msg_y < content_y - line_spacing) continue;
                    if (msg_y > content_y + msg_area_h) break;

                    const is_user = self.chat_msg_is_user[i];
                    const label_color = if (is_user) withAlpha(TEXT_WHITE, content_alpha) else withAlpha(HYPER_GREEN, content_alpha);
                    const label = if (is_user) "YOU:" else "AI:";

                    rl.DrawTextEx(font, label.ptr, .{ .x = sx + 12, .y = msg_y }, 11, 0.5, label_color);

                    // Message text
                    var msg_buf: [260:0]u8 = undefined;
                    const msg_len = self.chat_msg_lens[i];
                    const show_len = @min(msg_len, @as(usize, @intFromFloat((sw - 60) / 6)));
                    @memcpy(msg_buf[0..show_len], self.chat_messages[i][0..show_len]);
                    msg_buf[show_len] = 0;
                    rl.DrawTextEx(font, &msg_buf, .{ .x = sx + 45, .y = msg_y }, 11, 0.5, text_color);
                }

                // Welcome message if empty
                if (self.chat_msg_count == 0) {
                    rl.DrawTextEx(font, "AI:", .{ .x = sx + 12, .y = content_y + 10 }, 12, 0.5, withAlpha(HYPER_GREEN, content_alpha));
                    rl.DrawTextEx(font, "Hello! Type a message to chat.", .{ .x = sx + 12, .y = content_y + 28 }, 12, 0.5, text_color);
                }

                // Input area (bottom)
                const input_y = sy + sh - 40;
                rl.DrawRectangle(@intFromFloat(sx + 8), @intFromFloat(input_y), @intFromFloat(sw - 16), 30, withAlpha(BG_INPUT, content_alpha));
                rl.DrawRectangleLines(@intFromFloat(sx + 8), @intFromFloat(input_y), @intFromFloat(sw - 16), 30, withAlpha(BORDER_LIGHT, content_alpha));

                // Show current input or placeholder
                if (self.chat_input_len > 0) {
                    var input_buf: [260:0]u8 = undefined;
                    const show_len = @min(self.chat_input_len, 50);
                    @memcpy(input_buf[0..show_len], self.chat_input[0..show_len]);
                    // Cursor blink
                    if (@mod(@as(u32, @intFromFloat(time * 3)), 2) == 0) {
                        input_buf[show_len] = '_';
                        input_buf[show_len + 1] = 0;
                    } else {
                        input_buf[show_len] = 0;
                    }
                    rl.DrawTextEx(font, &input_buf, .{ .x = sx + 16, .y = input_y + 8 }, 12, 0.5, NOVA_WHITE);
                } else {
                    rl.DrawTextEx(font, "Type message... (click to focus)", .{ .x = sx + 16, .y = input_y + 8 }, 11, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                }
            },
            .code => {
                // === MULTI-MODAL CODE EDITOR WITH SYNTAX WAVES ===
                const line_h: f32 = 18;
                const code_lines = [_][]const u8{
                    "// TRINITY COSMIC ENGINE",
                    "const PHI: f32 = 1.618033988;",
                    "",
                    "fn main() !void {",
                    "    const grid = try init();",
                    "    defer grid.deinit();",
                    "",
                    "    // Cosmic infinity loop",
                    "    while (running) {",
                    "        update();",
                    "        render();",
                    "    }",
                    "}",
                };

                for (code_lines, 0..) |line, i| {
                    const fi = @as(f32, @floatFromInt(i));
                    // Wave offset for each line
                    const wave_offset = @sin(self.code_wave_phase + fi * 0.3) * 2;
                    const line_y = content_y + 10 + fi * line_h;
                    if (line_y > sy + sh - 20) break;

                    // Line number with wave glow
                    const ln_glow = @abs(@sin(self.code_wave_phase * 0.5 + fi * 0.5));
                    const ln_alpha: u8 = @intFromFloat(50 + ln_glow * 30);
                    var ln_buf: [8:0]u8 = undefined;
                    _ = std.fmt.bufPrintZ(&ln_buf, "{d:>3}", .{i + 1}) catch {};
                    rl.DrawTextEx(font, &ln_buf, .{ .x = sx + 8, .y = line_y }, 10, 0.5, rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = ln_alpha + content_alpha / 2 });

                    if (line.len == 0) continue;

                    // Syntax-based coloring with wave brightness modulation
                    const wave_brightness: f32 = 0.8 + @sin(self.code_wave_phase + fi * 0.2) * 0.2;

                    var code_color: rl.Color = undefined;
                    if (line[0] == '/' and line.len > 1 and line[1] == '/') {
                        // Comment - green with wave
                        code_color = rl.Color{ .r = @intFromFloat(0x50 * wave_brightness), .g = @intFromFloat(0xA0 * wave_brightness), .b = @intFromFloat(0x50 * wave_brightness), .a = content_alpha };
                    } else if (std.mem.startsWith(u8, line, "const") or std.mem.startsWith(u8, line, "fn ") or std.mem.startsWith(u8, line, "    const") or std.mem.startsWith(u8, line, "    defer") or std.mem.startsWith(u8, line, "    while")) {
                        // Keyword - green wave
                        code_color = rl.Color{ .r = @intFromFloat(0x00 * wave_brightness), .g = @intFromFloat(0xFF * wave_brightness), .b = @intFromFloat(0x88 * wave_brightness), .a = content_alpha };
                    } else if (std.mem.indexOf(u8, line, "PHI") != null or std.mem.indexOf(u8, line, "1.618") != null) {
                        // PHI constant - golden wave
                        code_color = rl.Color{ .r = @intFromFloat(0xFF * wave_brightness), .g = @intFromFloat(0xD7 * wave_brightness), .b = @intFromFloat(0x00 * wave_brightness), .a = content_alpha };
                    } else {
                        code_color = rl.Color{ .r = @intFromFloat(0xC0 * wave_brightness), .g = @intFromFloat(0xC8 * wave_brightness), .b = @intFromFloat(0xD0 * wave_brightness), .a = content_alpha };
                    }

                    // Draw code with wave offset
                    rl.DrawText(line.ptr, @intFromFloat(sx + 40 + wave_offset), @intFromFloat(line_y), 11, code_color);

                    // Trailing wave particles for active lines
                    if (i == self.code_cursor_line) {
                        const particle_x = sx + 40 + @as(f32, @floatFromInt(line.len)) * 7 + 10;
                        const particle_glow = @abs(@sin(self.code_wave_phase * 3));
                        rl.DrawCircle(@intFromFloat(particle_x), @intFromFloat(line_y + 6), 3 + particle_glow * 2, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 150) });
                    }
                }

                // Bottom status with wave
                const status_y = sy + sh - 25;
                const status_wave = @sin(time * 2) * 0.3 + 0.7;
                rl.DrawText("Zig | UTF-8 | phi^2 + 1/phi^2 = 3", @intFromFloat(sx + 12), @intFromFloat(status_y), 10, rl.Color{ .r = @intFromFloat(0x60 * status_wave), .g = @intFromFloat(0x70 * status_wave), .b = @intFromFloat(0x80 * status_wave), .a = content_alpha });
            },
            .tools => {
                // Tools list
                const tools_list = [_][]const u8{ "inference", "embedding", "search", "generate", "vision", "voice" };
                for (tools_list, 0..) |tool, i| {
                    const tool_y = content_y + 10 + @as(f32, @floatFromInt(i)) * 28;
                    const is_selected = i == self.tool_selected;
                    // Background
                    if (is_selected) {
                        rl.DrawRectangle(@intFromFloat(sx + 8), @intFromFloat(tool_y - 2), @intFromFloat(sw - 16), 24, rl.Color{ .r = 0x18, .g = 0x28, .b = 0x18, .a = content_alpha });
                    }
                    // Icon placeholder
                    rl.DrawCircle(@intFromFloat(sx + 22), @intFromFloat(tool_y + 10), 6, withAlpha(HYPER_GREEN, content_alpha));
                    // Text
                    rl.DrawText(tool.ptr, @intFromFloat(sx + 36), @intFromFloat(tool_y + 4), 12, if (is_selected) withAlpha(TEXT_WHITE, content_alpha) else text_color);
                }
            },
            .settings => {
                // Settings toggles
                const settings = [_]struct { name: []const u8, on: bool }{
                    .{ .name = "Dark Mode", .on = true },
                    .{ .name = "Animations", .on = true },
                    .{ .name = "Sound", .on = false },
                    .{ .name = "Auto-save", .on = true },
                    .{ .name = "Notifications", .on = false },
                };
                for (settings, 0..) |setting, i| {
                    const set_y = content_y + 10 + @as(f32, @floatFromInt(i)) * 32;
                    // Label
                    rl.DrawText(setting.name.ptr, @intFromFloat(sx + 16), @intFromFloat(set_y + 4), 12, text_color);
                    // Toggle
                    const toggle_x = sx + sw - 50;
                    const toggle_color = if (setting.on) rl.Color{ .r = 0x28, .g = 0xC8, .b = 0x40, .a = content_alpha } else rl.Color{ .r = 0x40, .g = 0x40, .b = 0x50, .a = content_alpha };
                    rl.DrawRectangleRounded(.{ .x = toggle_x, .y = set_y, .width = 36, .height = 20 }, 0.5, 8, toggle_color);
                    const knob_x = if (setting.on) toggle_x + 20 else toggle_x + 4;
                    rl.DrawCircle(@intFromFloat(knob_x + 6), @intFromFloat(set_y + 10), 8, withAlpha(TEXT_WHITE, content_alpha));
                }
            },
            .vision => {
                // === MULTI-MODAL VISION ANALYZER ===
                const img_size: f32 = @min(sw - 40, content_h - 80);
                const img_x = sx + (sw - img_size) / 2;
                const img_y = content_y + 10;
                const img_h = img_size * 0.6;

                // Image placeholder with scanning effect
                rl.DrawRectangleRounded(.{ .x = img_x, .y = img_y, .width = img_size, .height = img_h }, 0.02, 8, withAlpha(BG_INPUT, content_alpha));

                // Analyzing animation - scanning line + wave burst
                if (self.vision_analyzing) {
                    // Scanning line
                    const scan_y = img_y + (self.vision_progress * img_h);
                    rl.DrawLine(@intFromFloat(img_x + 5), @intFromFloat(scan_y), @intFromFloat(img_x + img_size - 5), @intFromFloat(scan_y), rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 200) });
                    // Glow
                    rl.DrawRectangle(@intFromFloat(img_x), @intFromFloat(scan_y - 2), @intFromFloat(img_size), 4, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 50) });

                    // Wave burst from scan position
                    const burst_rings: usize = 3;
                    for (0..burst_rings) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = 10 + ring_f * 15 + @sin(time * 5) * 5;
                        const ring_alpha: u8 = @intFromFloat(@max(0, self.opacity * 60 * (1.0 - ring_f / 3.0)));
                        rl.DrawCircleLines(@intFromFloat(img_x + img_size / 2), @intFromFloat(scan_y), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha });
                    }

                    // Progress bar
                    const progress_w = (sw - 40) * self.vision_progress;
                    rl.DrawRectangle(@intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 10), @intFromFloat(progress_w), 4, NEON_MAGENTA);
                    rl.DrawRectangleLines(@intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 10), @intFromFloat(sw - 40), 4, rl.Color{ .r = 0x40, .g = 0x40, .b = 0x50, .a = content_alpha });

                    rl.DrawText("Analyzing cosmic patterns...", @intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 20), 11, NEON_CYAN);
                } else if (self.vision_result_len > 0) {
                    // Show result with wave glow
                    const result_wave = @sin(time * 2) * 0.2 + 0.8;
                    var result_buf: [260:0]u8 = undefined;
                    @memcpy(result_buf[0..self.vision_result_len], self.vision_result[0..self.vision_result_len]);
                    result_buf[self.vision_result_len] = 0;
                    rl.DrawText(&result_buf, @intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 15), 11, rl.Color{ .r = @intFromFloat(0x80 * result_wave), .g = @intFromFloat(0xFF * result_wave), .b = @intFromFloat(0x80 * result_wave), .a = content_alpha });

                    // Success burst rings
                    for (0..3) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = 30 + ring_f * 25 + @sin(time * 2 + ring_f) * 10;
                        rl.DrawCircleLines(@intFromFloat(img_x + img_size / 2), @intFromFloat(img_y + img_h / 2), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 30) });
                    }
                } else {
                    // Drop zone
                    rl.DrawRectangleRoundedLinesEx(.{ .x = img_x, .y = img_y, .width = img_size, .height = img_h }, 0.02, 8, 2.0, rl.Color{ .r = 0x40, .g = 0x40, .b = 0x40, .a = @intFromFloat(self.opacity * 100) });
                    rl.DrawText("+", @intFromFloat(img_x + img_size / 2 - 15), @intFromFloat(img_y + img_h / 2 - 20), 40, rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = content_alpha });
                    rl.DrawText("Click to analyze image", @intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 15), 11, withAlpha(MUTED_GRAY, content_alpha));
                }
            },
            .voice => {
                // === MULTI-MODAL VOICE PANEL WITH STT RIPPLE ===
                const wave_center_y = content_y + content_h / 2 - 20;
                const wave_width = sw - 60;

                // Recording button (center top)
                const mic_btn_x = sx + sw / 2;
                const mic_btn_y = content_y + 30;
                const mic_btn_radius: f32 = if (self.voice_recording) 25 else 20;
                const mic_btn_pulse = @sin(self.voice_wave_phase) * 3;

                // Recording glow rings
                if (self.voice_recording) {
                    for (0..4) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = mic_btn_radius + 10 + ring_f * 15 + @sin(self.voice_wave_phase + ring_f) * 5;
                        const ring_alpha: u8 = @intFromFloat(@max(0, self.opacity * 80 * (1.0 - ring_f / 4.0)));
                        rl.DrawCircleLines(@intFromFloat(mic_btn_x), @intFromFloat(mic_btn_y), ring_radius, rl.Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = ring_alpha });
                    }
                }

                // Button
                const mic_btn_color = if (self.voice_recording) rl.Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = content_alpha } else withAlpha(HYPER_GREEN, content_alpha);
                rl.DrawCircle(@intFromFloat(mic_btn_x), @intFromFloat(mic_btn_y), mic_btn_radius + mic_btn_pulse, mic_btn_color);

                // Mic icon
                if (self.voice_recording) {
                    rl.DrawRectangle(@intFromFloat(mic_btn_x - 4), @intFromFloat(mic_btn_y - 8), 8, 12, withAlpha(TEXT_WHITE, content_alpha));
                } else {
                    rl.DrawCircle(@intFromFloat(mic_btn_x), @intFromFloat(mic_btn_y), 8, withAlpha(TEXT_WHITE, content_alpha));
                }

                // === WAVEFORM VISUALIZATION ===
                const num_bars: usize = 48;
                const bar_w = wave_width / @as(f32, @floatFromInt(num_bars));

                for (0..num_bars) |i| {
                    const fi = @as(f32, @floatFromInt(i));
                    // Multiple wave frequencies for complex waveform
                    const wave1 = @sin(fi * 0.3 + self.voice_wave_phase);
                    const wave2 = @sin(fi * 0.7 + self.voice_wave_phase * 1.5) * 0.5;
                    const wave3 = @sin(fi * 0.1 + self.voice_wave_phase * 0.3) * 0.3;
                    const combined = (wave1 + wave2 + wave3) / 1.8;

                    const bar_h = 15.0 + combined * 40.0 * (0.3 + self.voice_amplitude * 0.7);
                    const bar_x = sx + 30 + fi * bar_w;
                    const bar_y = wave_center_y - bar_h / 2;

                    // Color gradient based on position and amplitude
                    const hue = 200.0 + fi * 2.0 + self.voice_amplitude * 60;
                    const saturation = 0.6 + self.voice_amplitude * 0.3;
                    const rgb = hsvToRgb(hue, saturation, 0.9);

                    // Draw bar with glow
                    if (self.voice_amplitude > 0.3) {
                        rl.DrawRectangle(@intFromFloat(bar_x - 1), @intFromFloat(bar_y - 2), @intFromFloat(bar_w), @intFromFloat(bar_h + 4), rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = content_alpha / 4 });
                    }
                    rl.DrawRectangle(@intFromFloat(bar_x), @intFromFloat(bar_y), @intFromFloat(bar_w - 2), @intFromFloat(bar_h), rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = content_alpha });
                }

                // STT Ripple effect when amplitude high
                if (self.voice_amplitude > 0.4) {
                    const ripple_radius = 30 + self.voice_amplitude * 50;
                    for (0..2) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        rl.DrawCircleLines(@intFromFloat(sx + sw / 2), @intFromFloat(wave_center_y), ripple_radius + ring_f * 20, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 40) });
                    }
                }

                // Status text
                const status_y = sy + sh - 35;
                if (self.voice_recording) {
                    const blink = @mod(@as(u32, @intFromFloat(time * 2)), 2);
                    const rec_color = if (blink == 0) rl.Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = content_alpha } else rl.Color{ .r = 0x80, .g = 0x20, .b = 0x20, .a = content_alpha };
                    rl.DrawCircle(@intFromFloat(sx + 25), @intFromFloat(status_y + 5), 5, rec_color);
                    rl.DrawText("Recording... (click to stop)", @intFromFloat(sx + 38), @intFromFloat(status_y), 11, rl.Color{ .r = 0xFF, .g = 0x80, .b = 0x80, .a = content_alpha });
                } else {
                    rl.DrawText("Click mic to start recording", @intFromFloat(sx + 20), @intFromFloat(status_y), 11, withAlpha(MUTED_GRAY, content_alpha));
                }
            },
            .finder => {
                // EMERGENT FINDER - Wave-based file system visualization
                const center_x = sx + sw / 2;
                const center_y = content_y + content_h / 2;

                // === CENTRAL WAVE SOURCE (Current Directory) ===
                // Pulsating center representing the root
                const pulse = @sin(time * 3.0) * 0.3 + 0.7;
                const core_radius: f32 = 20 * pulse;

                // Glow rings emanating from center
                for (0..5) |ring| {
                    const ring_f = @as(f32, @floatFromInt(ring));
                    const ring_radius = 30 + ring_f * 20 + @sin(time * 2.0 - ring_f * 0.5) * 5;
                    const ring_alpha: u8 = @intFromFloat(@max(0, @min(255, self.opacity * (80 - ring_f * 15))));
                    rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha });
                }

                // Central core
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), core_radius, rl.Color{ .r = 0x00, .g = 0xCC, .b = 0x66, .a = @intFromFloat(self.opacity * 200) });
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), core_radius * 0.6, rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = @intFromFloat(self.opacity * 150) });

                // === COSMIC RIPPLE EFFECT (on folder navigation) ===
                if (self.finder_ripple > 0) {
                    const ripple_progress = 1.0 - self.finder_ripple;
                    const max_ripple_radius = @min(content_h, sw) * 0.8;
                    for (0..4) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_delay = ring_f * 0.15;
                        const ring_progress = @max(0, @min(1.0, (ripple_progress - ring_delay) / 0.6));
                        if (ring_progress > 0) {
                            const ripple_radius = ring_progress * max_ripple_radius;
                            const ripple_alpha: u8 = @intFromFloat(@max(0, self.opacity * 180 * (1.0 - ring_progress)));
                            rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), ripple_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ripple_alpha });
                            rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), ripple_radius + 2, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ripple_alpha / 2 });
                        }
                    }
                }

                // === ORBITING PHOTONS (Files and Folders) ===
                for (0..self.finder_entry_count) |i| {
                    const entry = &self.finder_entries[i];
                    const anim_progress = @min(1.0, self.finder_animation + @as(f32, @floatFromInt(i)) * 0.05);

                    // Calculate orbit position with animation
                    const angle = entry.orbit_angle + time * 0.3;
                    const radius = entry.orbit_radius * anim_progress;

                    const ex = center_x + @cos(angle) * radius;
                    const ey = center_y + @sin(angle) * radius;

                    // Get color based on file type
                    const base_color = entry.file_type.getColor();
                    const entry_alpha: u8 = @intFromFloat(self.opacity * 255 * anim_progress);

                    // Draw orbit trail (faint arc)
                    if (radius > 10) {
                        rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), radius, rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = @intFromFloat(self.opacity * 20) });
                    }

                    // Draw photon (size based on type)
                    const photon_size: f32 = if (entry.is_dir) 12 else 8;
                    const pulsate = @sin(time * 4.0 + entry.orbit_angle) * 2;

                    // Glow
                    rl.DrawCircle(@intFromFloat(ex), @intFromFloat(ey), photon_size + 4 + pulsate, rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = entry_alpha / 3 });
                    // Core
                    rl.DrawCircle(@intFromFloat(ex), @intFromFloat(ey), photon_size + pulsate, rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = entry_alpha });
                    // Highlight
                    if (i == self.finder_selected) {
                        rl.DrawCircleLines(@intFromFloat(ex), @intFromFloat(ey), photon_size + 6 + pulsate, rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = entry_alpha });
                    }

                    // Draw name on hover (if selected)
                    if (i == self.finder_selected and entry.name_len > 0) {
                        var name_buf: [130:0]u8 = undefined;
                        @memcpy(name_buf[0..entry.name_len], entry.name[0..entry.name_len]);
                        name_buf[entry.name_len] = 0;
                        const name_x = ex + photon_size + 8;
                        const name_y = ey - 6;
                        // Background
                        const name_width: f32 = @as(f32, @floatFromInt(entry.name_len)) * 7 + 4;
                        rl.DrawRectangle(@intFromFloat(name_x - 2), @intFromFloat(name_y - 2), @intFromFloat(@min(name_width, sw - 20)), 16, rl.Color{ .r = 0x10, .g = 0x10, .b = 0x10, .a = @intFromFloat(self.opacity * 200) });
                        rl.DrawText(&name_buf, @intFromFloat(name_x), @intFromFloat(name_y), 11, rl.Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = entry_alpha });
                    }
                }

                // === PATH DISPLAY ===
                if (self.finder_path_len > 0) {
                    var path_buf: [64:0]u8 = undefined;
                    const show_len = @min(self.finder_path_len, 60);
                    @memcpy(path_buf[0..show_len], self.finder_path[0..show_len]);
                    if (self.finder_path_len > 60) {
                        path_buf[57] = '.';
                        path_buf[58] = '.';
                        path_buf[59] = '.';
                        path_buf[60] = 0;
                    } else {
                        path_buf[show_len] = 0;
                    }
                    rl.DrawText(&path_buf, @intFromFloat(sx + 12), @intFromFloat(content_y + 5), 10, withAlpha(MUTED_GRAY, content_alpha));
                }

                // === LEGEND ===
                const legend_y = sy + sh - 25;
                rl.DrawCircle(@intFromFloat(sx + 15), @intFromFloat(legend_y), 4, withAlpha(HYPER_GREEN, content_alpha));
                rl.DrawText("DIR", @intFromFloat(sx + 22), @intFromFloat(legend_y - 4), 8, withAlpha(MUTED_GRAY, content_alpha));
                rl.DrawCircle(@intFromFloat(sx + 55), @intFromFloat(legend_y), 4, rl.Color{ .r = 0xF7, .g = 0xA4, .b = 0x1D, .a = content_alpha });
                rl.DrawText(".zig", @intFromFloat(sx + 62), @intFromFloat(legend_y - 4), 8, withAlpha(MUTED_GRAY, content_alpha));
                rl.DrawCircle(@intFromFloat(sx + 95), @intFromFloat(legend_y), 4, rl.Color{ .r = 0x80, .g = 0xFF, .b = 0xA0, .a = content_alpha });
                rl.DrawText("code", @intFromFloat(sx + 102), @intFromFloat(legend_y - 4), 8, withAlpha(MUTED_GRAY, content_alpha));

                // Count display
                var count_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&count_buf, "{d} items", .{self.finder_entry_count}) catch {};
                rl.DrawText(&count_buf, @intFromFloat(sx + sw - 70), @intFromFloat(legend_y - 4), 10, withAlpha(MUTED_GRAY, content_alpha));
            },
            .system => {
                // === SYSTEM MONITORING PANEL (Hyper Terminal Style) ===
                const row_h: f32 = 60;
                const bar_h: f32 = 8;
                const margin: f32 = 20;

                // Simulated system stats (computed from time for smooth animation)
                const cpu_usage = 25.0 + @sin(time * 0.5) * 15 + @sin(time * 1.3) * 8;
                const mem_used = 8.2 + @sin(time * 0.3) * 0.5;
                const mem_total: f32 = 16.0;
                const cpu_temp = 45.0 + @sin(time * 0.7) * 8;

                // === CPU Usage ===
                const cpu_y = content_y + 10;
                rl.DrawTextEx(font, "CPU", .{ .x = sx + margin, .y = cpu_y }, 14, 0.5, HYPER_CYAN);
                var cpu_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&cpu_buf, "{d:.1}%", .{cpu_usage}) catch {};
                rl.DrawTextEx(font, &cpu_buf, .{ .x = sx + sw - margin - 50, .y = cpu_y }, 14, 0.5, TEXT_WHITE);

                // CPU bar background (Hyper style)
                const cpu_bar_y = cpu_y + 22;
                const bar_w = sw - margin * 2;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(cpu_bar_y), @intFromFloat(bar_w), @intFromFloat(bar_h), withAlpha(BG_BAR, content_alpha));
                // CPU bar fill
                const cpu_fill = bar_w * (cpu_usage / 100.0);
                const cpu_color = if (cpu_usage > 80) HYPER_RED else if (cpu_usage > 50) HYPER_YELLOW else HYPER_GREEN;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(cpu_bar_y), @intFromFloat(cpu_fill), @intFromFloat(bar_h), cpu_color);

                // === Memory Usage ===
                const mem_y = content_y + row_h + 10;
                rl.DrawTextEx(font, "MEMORY", .{ .x = sx + margin, .y = mem_y }, 14, 0.5, HYPER_MAGENTA);
                var mem_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&mem_buf, "{d:.1} / {d:.0} GB", .{ mem_used, mem_total }) catch {};
                rl.DrawTextEx(font, &mem_buf, .{ .x = sx + sw - margin - 100, .y = mem_y }, 14, 0.5, TEXT_WHITE);

                // Memory bar (Hyper style)
                const mem_bar_y = mem_y + 22;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(mem_bar_y), @intFromFloat(bar_w), @intFromFloat(bar_h), withAlpha(BG_BAR, content_alpha));
                const mem_pct = mem_used / mem_total;
                const mem_fill = bar_w * mem_pct;
                const mem_color = if (mem_pct > 0.8) HYPER_RED else if (mem_pct > 0.5) HYPER_YELLOW else HYPER_MAGENTA;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(mem_bar_y), @intFromFloat(mem_fill), @intFromFloat(bar_h), mem_color);

                // === Temperature ===
                const temp_y = content_y + row_h * 2 + 10;
                rl.DrawTextEx(font, "TEMP", .{ .x = sx + margin, .y = temp_y }, 14, 0.5, HYPER_YELLOW);
                var temp_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&temp_buf, "{d:.0}C", .{cpu_temp}) catch {};
                rl.DrawTextEx(font, &temp_buf, .{ .x = sx + sw - margin - 40, .y = temp_y }, 14, 0.5, TEXT_WHITE);

                // Temperature bar (Hyper style)
                const temp_bar_y = temp_y + 22;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(temp_bar_y), @intFromFloat(bar_w), @intFromFloat(bar_h), withAlpha(BG_BAR, content_alpha));
                const temp_pct = @min(1.0, (cpu_temp - 30) / 70.0); // 30-100C range
                const temp_fill = bar_w * temp_pct;
                const temp_color = if (cpu_temp > 80) HYPER_RED else if (cpu_temp > 60) HYPER_YELLOW else HYPER_CYAN;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(temp_bar_y), @intFromFloat(temp_fill), @intFromFloat(bar_h), temp_color);

                // === System Info ===
                const info_y = content_y + row_h * 3 + 20;
                rl.DrawTextEx(font, "SYSTEM", .{ .x = sx + margin, .y = info_y }, 12, 0.5, MUTED_GRAY);
                rl.DrawTextEx(font, "macOS | Apple M1 Pro", .{ .x = sx + margin, .y = info_y + 18 }, 11, 0.5, withAlpha(SEPARATOR, content_alpha));
                rl.DrawTextEx(font, "TRINITY OS v1.8", .{ .x = sx + margin, .y = info_y + 36 }, 11, 0.5, rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = content_alpha });

                // Pulse effect for active monitoring
                const pulse_alpha: u8 = @intFromFloat(50 + @sin(time * 3) * 20);
                rl.DrawCircle(@intFromFloat(sx + sw - 30), @intFromFloat(content_y + 20), 4, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = pulse_alpha });
            },
        }

        // Resize handle (bottom-right corner)
        const handle_size: f32 = 12;
        const handle_x = sx + sw - handle_size;
        const handle_y = sy + sh - handle_size;
        for (0..3) |i| {
            const fi = @as(f32, @floatFromInt(i));
            rl.DrawLine(@intFromFloat(handle_x + fi * 4), @intFromFloat(handle_y + handle_size), @intFromFloat(handle_x + handle_size), @intFromFloat(handle_y + fi * 4), rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = @intFromFloat(self.opacity * 100) });
        }
    }

    pub fn isPointInside(self: *const GlassPanel, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + self.height;
    }

    pub fn isPointInTitleBar(self: *const GlassPanel, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + 36;
    }

    pub fn isPointOnClose(self: *const GlassPanel, px: f32, py: f32) bool {
        // Traffic light close button (left side, red)
        const close_x = self.x + 16;
        const close_y = self.y + 14;
        const dx = px - close_x;
        const dy = py - close_y;
        return dx * dx + dy * dy < 64; // radius 8

    }

    pub fn isPointOnResize(self: *const GlassPanel, px: f32, py: f32) bool {
        // Bottom-right corner resize handle
        const handle_size: f32 = 16;
        return px >= self.x + self.width - handle_size and
            px <= self.x + self.width and
            py >= self.y + self.height - handle_size and
            py <= self.y + self.height;
    }

    // Load directory for finder panel
    pub fn loadDirectory(self: *GlassPanel, path: []const u8) void {
        // Store path
        const path_copy_len = @min(path.len, 511);
        @memcpy(self.finder_path[0..path_copy_len], path[0..path_copy_len]);
        self.finder_path_len = path_copy_len;
        self.finder_entry_count = 0;
        self.finder_animation = 0;

        // Open directory using std.fs
        const dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
            // If can't open, add error entry
            const err_name = "Error: Cannot open directory";
            @memcpy(self.finder_entries[0].name[0..err_name.len], err_name);
            self.finder_entries[0].name_len = err_name.len;
            self.finder_entries[0].is_dir = false;
            self.finder_entries[0].file_type = .unknown;
            self.finder_entry_count = 1;
            return;
        };

        // Add parent directory entry (..)
        if (!std.mem.eql(u8, path, ".") and !std.mem.eql(u8, path, "/")) {
            const parent_name = "..";
            @memcpy(self.finder_entries[0].name[0..2], parent_name);
            self.finder_entries[0].name_len = 2;
            self.finder_entries[0].is_dir = true;
            self.finder_entries[0].file_type = .folder;
            self.finder_entries[0].orbit_angle = 0;
            self.finder_entries[0].orbit_radius = 50;
            self.finder_entry_count = 1;
        }

        // Iterate directory
        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            if (self.finder_entry_count >= 64) break;

            const idx = self.finder_entry_count;
            const name_len = @min(entry.name.len, 127);
            @memcpy(self.finder_entries[idx].name[0..name_len], entry.name[0..name_len]);
            self.finder_entries[idx].name_len = name_len;
            self.finder_entries[idx].is_dir = entry.kind == .directory;

            if (entry.kind == .directory) {
                self.finder_entries[idx].file_type = .folder;
            } else {
                self.finder_entries[idx].file_type = FileType.fromName(entry.name);
            }

            // Assign orbit position based on index
            const fi = @as(f32, @floatFromInt(idx));
            self.finder_entries[idx].orbit_angle = fi * 0.618033988 * TAU; // Golden angle
            self.finder_entries[idx].orbit_radius = 60 + fi * 8; // Expanding spiral

            self.finder_entry_count += 1;
        }
    }

    // Get clicked entry in finder
    pub fn getFinderEntryAt(self: *const GlassPanel, px: f32, py: f32, time: f32) ?usize {
        const center_x = self.x + self.width / 2;
        const center_y = self.y + self.height / 2 + 20;

        for (0..self.finder_entry_count) |i| {
            const entry = &self.finder_entries[i];
            const angle = entry.orbit_angle + time * 0.3 + self.finder_animation;
            const radius = entry.orbit_radius * (0.8 + self.finder_animation * 0.2);

            const ex = center_x + @cos(angle) * radius;
            const ey = center_y + @sin(angle) * radius;

            const dx = px - ex;
            const dy = py - ey;
            const dist = @sqrt(dx * dx + dy * dy);

            // Check if click is within entry circle
            const entry_size: f32 = if (entry.is_dir) 14 else 10;
            if (dist < entry_size + 5) {
                return i;
            }
        }
        return null;
    }
};

const PanelSystem = struct {
    panels: [MAX_PANELS]GlassPanel,
    count: usize,
    active_panel: ?usize,

    // Swipe tracking
    swipe_start_x: f32,
    swipe_start_y: f32,
    swiping: bool,

    pub fn init() PanelSystem {
        return .{
            .panels = undefined,
            .count = 0,
            .active_panel = null,
            .swipe_start_x = 0,
            .swipe_start_y = 0,
            .swiping = false,
        };
    }

    pub fn spawn(self: *PanelSystem, x: f32, y: f32, w: f32, h: f32, ptype: PanelType, title: []const u8) void {
        if (self.count >= MAX_PANELS) return;
        self.panels[self.count] = GlassPanel.init(x, y, w, h, ptype, title);
        self.panels[self.count].open();
        self.count += 1;
    }

    // Focus panel by type - if exists, focus it; otherwise spawn new
    pub fn focusByType(self: *PanelSystem, ptype: PanelType, x: f32, y: f32, w: f32, h: f32, title: []const u8) void {
        // First unfocus all panels
        for (0..self.count) |i| {
            if (self.panels[i].is_focused) {
                self.panels[i].unfocus();
            }
        }

        // Find existing panel of this type
        for (0..self.count) |i| {
            if (self.panels[i].panel_type == ptype and self.panels[i].state == .open) {
                self.panels[i].focus();
                self.active_panel = i;
                return;
            }
        }

        // No existing panel - spawn new and focus
        if (self.count < MAX_PANELS) {
            self.panels[self.count] = GlassPanel.init(x, y, w, h, ptype, title);
            self.panels[self.count].open();
            // Focus will be called after opening animation
            self.panels[self.count].is_focused = true;
            self.panels[self.count].focus_ripple = 1.0;
            self.panels[self.count].target_x = 20;
            self.panels[self.count].target_y = 40;
            self.panels[self.count].target_w = @as(f32, @floatFromInt(g_width)) - 40;
            self.panels[self.count].target_h = @as(f32, @floatFromInt(g_height)) - 100;
            self.active_panel = self.count;
            self.count += 1;
        }
    }

    // Unfocus all panels
    pub fn unfocusAll(self: *PanelSystem) void {
        for (0..self.count) |i| {
            if (self.panels[i].is_focused) {
                self.panels[i].unfocus();
            }
        }
    }

    // JARVIS-style focus with spherical morph animation
    // If panel of type exists: bring to front + refocus
    // If not: spawn new with JARVIS sphere → rectangle animation
    pub fn jarvisFocus(self: *PanelSystem, ptype: PanelType, x: f32, y: f32, w: f32, h: f32, title: []const u8) void {
        // First unfocus all panels
        for (0..self.count) |i| {
            if (self.panels[i].is_focused) {
                self.panels[i].unfocus();
            }
        }

        // Find existing panel of this type
        for (0..self.count) |i| {
            if (self.panels[i].panel_type == ptype and self.panels[i].state == .open) {
                // Bring to front by swapping with last panel
                if (i < self.count - 1) {
                    const temp = self.panels[i];
                    // Shift all panels down
                    var j: usize = i;
                    while (j < self.count - 1) : (j += 1) {
                        self.panels[j] = self.panels[j + 1];
                    }
                    self.panels[self.count - 1] = temp;
                }
                // JARVIS focus with spherical morph
                self.panels[self.count - 1].jarvisFocus();
                self.active_panel = self.count - 1;
                return;
            }
        }

        // No existing panel - spawn new with JARVIS animation
        if (self.count < MAX_PANELS) {
            self.panels[self.count] = GlassPanel.init(x, y, w, h, ptype, title);
            self.panels[self.count].open();
            self.panels[self.count].jarvisFocus();
            self.active_panel = self.count;
            self.count += 1;
        }
    }

    pub fn update(self: *PanelSystem, dt: f32, time: f32, mx: f32, my: f32, mouse_pressed: bool, mouse_down: bool, mouse_released: bool, mouse_wheel: f32) void {
        // Handle mouse interactions
        if (mouse_pressed) {
            // Check if clicking on any panel (reverse order for z-order)
            var i: usize = self.count;
            while (i > 0) {
                i -= 1;
                const panel = &self.panels[i];
                if (panel.state != .open) continue;

                // Close button (traffic light red)
                if (panel.isPointOnClose(mx, my)) {
                    panel.close();
                    return;
                }

                // Resize handle (bottom-right)
                if (panel.isPointOnResize(mx, my)) {
                    panel.resizing = true;
                    self.active_panel = i;
                    return;
                }

                // Title bar drag
                if (panel.isPointInTitleBar(mx, my)) {
                    panel.dragging = true;
                    panel.drag_offset_x = mx - panel.x;
                    panel.drag_offset_y = my - panel.y;
                    self.active_panel = i;
                    self.swipe_start_x = mx;
                    self.swipe_start_y = my;
                    return;
                }

                // Click inside panel
                if (panel.isPointInside(mx, my)) {
                    self.active_panel = i;

                    // Handle vision panel clicks - start analyzing
                    if (panel.panel_type == .vision and !panel.vision_analyzing and panel.vision_result_len == 0) {
                        panel.vision_analyzing = true;
                        panel.vision_progress = 0;
                    }

                    // Handle voice panel clicks - toggle recording
                    if (panel.panel_type == .voice) {
                        panel.voice_recording = !panel.voice_recording;
                        if (!panel.voice_recording) {
                            // Finished recording - simulate STT
                            panel.addChatMessage("Voice: [transcribed audio]", false);
                        }
                    }

                    // Handle finder panel clicks
                    if (panel.panel_type == .finder) {
                        // Pass time for calculating positions
                        if (panel.getFinderEntryAt(mx, my, time)) |entry_idx| {
                            const entry = &panel.finder_entries[entry_idx];
                            panel.finder_selected = entry_idx;

                            // Navigate into folder on click
                            if (entry.is_dir and entry.name_len > 0) {
                                // Build new path
                                var new_path: [1024]u8 = undefined;
                                var new_len: usize = 0;

                                // Check for parent directory (..)
                                if (entry.name_len == 2 and entry.name[0] == '.' and entry.name[1] == '.') {
                                    // Go up one level
                                    if (panel.finder_path_len > 0) {
                                        // Find last separator
                                        var sep_idx: usize = panel.finder_path_len;
                                        while (sep_idx > 0) : (sep_idx -= 1) {
                                            if (panel.finder_path[sep_idx - 1] == '/') {
                                                break;
                                            }
                                        }
                                        if (sep_idx > 1) {
                                            @memcpy(new_path[0 .. sep_idx - 1], panel.finder_path[0 .. sep_idx - 1]);
                                            new_len = sep_idx - 1;
                                        } else {
                                            new_path[0] = '.';
                                            new_len = 1;
                                        }
                                    }
                                } else {
                                    // Enter subdirectory
                                    if (panel.finder_path_len > 0 and panel.finder_path[0] != '.') {
                                        @memcpy(new_path[0..panel.finder_path_len], panel.finder_path[0..panel.finder_path_len]);
                                        new_path[panel.finder_path_len] = '/';
                                        new_len = panel.finder_path_len + 1;
                                    }
                                    @memcpy(new_path[new_len .. new_len + entry.name_len], entry.name[0..entry.name_len]);
                                    new_len += entry.name_len;
                                }

                                // Load new directory with ripple effect
                                panel.finder_ripple = 1.0; // Trigger cosmic ripple
                                panel.loadDirectory(new_path[0..new_len]);
                            }
                        }
                    }
                    return;
                }
            }

            // Start swipe on empty area
            self.swiping = true;
            self.swipe_start_x = mx;
            self.swipe_start_y = my;
        }

        if (mouse_down) {
            if (self.active_panel) |idx| {
                const panel = &self.panels[idx];

                // Resizing
                if (panel.resizing) {
                    const new_w = @max(200, mx - panel.x);
                    const new_h = @max(150, my - panel.y);
                    panel.width = new_w;
                    panel.height = new_h;
                }
                // Dragging
                else if (panel.dragging) {
                    const new_x = mx - panel.drag_offset_x;
                    const new_y = my - panel.drag_offset_y;
                    panel.vel_x = (new_x - panel.x) / dt;
                    panel.vel_y = (new_y - panel.y) / dt;
                    panel.x = new_x;
                    panel.y = new_y;
                }
            }
        }

        if (mouse_released) {
            // End dragging/resizing with snap-to-grid
            if (self.active_panel) |idx| {
                const panel = &self.panels[idx];
                panel.dragging = false;
                panel.resizing = false;

                // Snap to grid (32px)
                const grid_size: f32 = 32;
                panel.x = @round(panel.x / grid_size) * grid_size;
                panel.y = @round(panel.y / grid_size) * grid_size;
                panel.width = @round(panel.width / grid_size) * grid_size;
                panel.height = @round(panel.height / grid_size) * grid_size;

                // Ensure minimum size
                panel.width = @max(200, panel.width);
                panel.height = @max(150, panel.height);
            }

            // Check swipe gesture
            if (self.swiping) {
                const dx = mx - self.swipe_start_x;
                const dy = my - self.swipe_start_y;
                const swipe_threshold: f32 = 100;

                if (@abs(dy) > swipe_threshold and dy < 0) {
                    // Swipe UP - minimize all panels
                    for (&self.panels) |*p| {
                        if (p.state == .open) p.minimize();
                    }
                } else if (@abs(dx) > swipe_threshold) {
                    // Swipe LEFT/RIGHT - add velocity to open panels
                    const vel_boost: f32 = dx * 5.0;
                    for (&self.panels) |*p| {
                        if (p.state == .open) p.vel_x += vel_boost;
                    }
                }
            }

            self.swiping = false;
        }

        // Handle mouse wheel scroll for panel under cursor
        if (mouse_wheel != 0) {
            for (0..self.count) |i| {
                const panel = &self.panels[i];
                if (panel.state == .open and panel.isPointInside(mx, my)) {
                    // Scroll the panel content (30px per scroll unit)
                    panel.scroll_y -= mouse_wheel * 30.0;
                    // Clamp scroll (max 500px for now)
                    panel.scroll_y = @max(0, @min(panel.scroll_y, 500.0));
                    break;
                }
            }
        }

        // Update all panels
        for (0..self.count) |i| {
            self.panels[i].update(dt);
        }
    }

    pub fn draw(self: *const PanelSystem, time: f32, font: rl.Font) void {
        for (0..self.count) |i| {
            self.panels[i].draw(time, font);
        }
    }
};

// =============================================================================
// TRINITY MODES (Full functionality in canvas)
// =============================================================================

const TrinityMode = enum {
    idle, // Wave exploration
    chat, // Chat emerges as wave clusters
    code, // Code gen as structural spirals
    vision, // Image → wave perturbation
    voice, // Voice → frequency modulation
    tools, // Tool execution as orbiting clusters
    autonomous, // Self-directed emergence
};

// =============================================================================
// WAVE CLUSTER (Chat text as interference patterns)
// =============================================================================

const MAX_CLUSTERS = 32;
const MAX_CLUSTER_CHARS = 256;

const WaveCluster = struct {
    chars: [MAX_CLUSTER_CHARS]u8,
    len: usize,
    x: f32,
    y: f32,
    radius: f32,
    phase: f32,
    life: f32,
    hue: f32,
    is_user: bool, // User message vs AI response

    pub fn spawn(x: f32, y: f32, text: []const u8, is_user: bool) WaveCluster {
        var cluster = WaveCluster{
            .chars = undefined,
            .len = @min(text.len, MAX_CLUSTER_CHARS),
            .x = x,
            .y = y,
            .radius = 50.0,
            .phase = 0,
            .life = 1.0,
            .hue = if (is_user) 180.0 else 120.0, // Cyan for user, green for AI
            .is_user = is_user,
        };
        @memcpy(cluster.chars[0..cluster.len], text[0..cluster.len]);
        return cluster;
    }

    pub fn update(self: *WaveCluster, dt: f32) void {
        self.phase += dt * 2.0;
        self.radius += dt * 10.0; // Expand outward
        self.life -= dt * 0.1; // Slow fade
    }

    pub fn isAlive(self: *const WaveCluster) bool {
        return self.life > 0;
    }

    pub fn draw(self: *const WaveCluster, time: f32) void {
        if (!self.isAlive()) return;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));
        const rgb = hsvToRgb(self.hue, 0.8, 1.0);

        // Draw as concentric rings (wave interference)
        const num_rings: usize = @intFromFloat(@max(1, self.radius / 15.0));
        for (0..num_rings) |i| {
            const ring_r = @as(f32, @floatFromInt(i)) * 15.0 + @sin(time * 3.0 + self.phase) * 5.0;
            const ring_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(alpha)) * (1.0 - @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_rings))));
            rl.DrawCircleLines(
                @intFromFloat(self.x),
                @intFromFloat(self.y),
                ring_r,
                rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = ring_alpha },
            );
        }

        // Draw character glyphs around the cluster
        const chars_to_show = @min(self.len, 32);
        for (0..chars_to_show) |i| {
            const angle = @as(f32, @floatFromInt(i)) * TAU / @as(f32, @floatFromInt(chars_to_show)) + self.phase;
            const char_r = self.radius * 0.7;
            const cx = self.x + @cos(angle) * char_r;
            const cy = self.y + @sin(angle) * char_r;

            // Character as small circle (ASCII-based size)
            const char_val = self.chars[i];
            const char_size = 2.0 + @as(f32, @floatFromInt(char_val % 10)) * 0.3;
            rl.DrawCircle(
                @intFromFloat(cx),
                @intFromFloat(cy),
                char_size,
                rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha },
            );
        }
    }
};

const ClusterSystem = struct {
    clusters: [MAX_CLUSTERS]WaveCluster,
    count: usize,

    pub fn init() ClusterSystem {
        var sys = ClusterSystem{
            .clusters = undefined,
            .count = 0,
        };
        for (&sys.clusters) |*c| {
            c.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *ClusterSystem, x: f32, y: f32, text: []const u8, is_user: bool) void {
        // Find dead slot
        for (&self.clusters) |*c| {
            if (!c.isAlive()) {
                c.* = WaveCluster.spawn(x, y, text, is_user);
                return;
            }
        }
        // Overwrite oldest if full
        if (self.count < MAX_CLUSTERS) {
            self.clusters[self.count] = WaveCluster.spawn(x, y, text, is_user);
            self.count += 1;
        }
    }

    pub fn update(self: *ClusterSystem, dt: f32) void {
        for (&self.clusters) |*c| {
            if (c.isAlive()) {
                c.update(dt);
            }
        }
    }

    pub fn draw(self: *const ClusterSystem, time: f32) void {
        for (&self.clusters) |*c| {
            c.draw(time);
        }
    }
};

// =============================================================================
// CODE SPIRAL (Code gen as structural patterns)
// =============================================================================

const MAX_SPIRALS = 16;

const CodeSpiral = struct {
    x: f32,
    y: f32,
    turns: f32, // Number of spiral turns
    scale: f32,
    rotation: f32,
    life: f32,
    syntax_hue: f32, // Color based on syntax type

    const SyntaxType = enum {
        keyword, // Blue
        function, // Green
        variable, // Yellow
        literal, // Magenta
        operator, // Cyan
    };

    pub fn spawn(x: f32, y: f32, syntax: SyntaxType) CodeSpiral {
        const hue: f32 = switch (syntax) {
            .keyword => 240.0,
            .function => 120.0,
            .variable => 60.0,
            .literal => 300.0,
            .operator => 180.0,
        };
        return .{
            .x = x,
            .y = y,
            .turns = 3.0,
            .scale = 20.0,
            .rotation = 0,
            .life = 1.0,
            .syntax_hue = hue,
        };
    }

    pub fn update(self: *CodeSpiral, dt: f32) void {
        self.rotation += dt * PHI;
        self.scale += dt * 5.0;
        self.turns += dt * 0.5;
        self.life -= dt * 0.15;
    }

    pub fn isAlive(self: *const CodeSpiral) bool {
        return self.life > 0;
    }

    pub fn draw(self: *const CodeSpiral) void {
        if (!self.isAlive()) return;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));
        const rgb = hsvToRgb(self.syntax_hue, 0.9, 1.0);

        // Draw golden spiral
        const steps: usize = @intFromFloat(self.turns * 32);
        var prev_x: c_int = @intFromFloat(self.x);
        var prev_y: c_int = @intFromFloat(self.y);

        for (0..steps) |i| {
            const t = @as(f32, @floatFromInt(i)) * 0.1;
            const r = self.scale * @exp(t * PHI_INV * 0.1);
            const angle = t + self.rotation;

            const px: c_int = @intFromFloat(self.x + @cos(angle) * r);
            const py: c_int = @intFromFloat(self.y + @sin(angle) * r);

            rl.DrawLine(prev_x, prev_y, px, py, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha });

            prev_x = px;
            prev_y = py;
        }
    }
};

const SpiralSystem = struct {
    spirals: [MAX_SPIRALS]CodeSpiral,
    count: usize,

    pub fn init() SpiralSystem {
        var sys = SpiralSystem{
            .spirals = undefined,
            .count = 0,
        };
        for (&sys.spirals) |*s| {
            s.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *SpiralSystem, x: f32, y: f32, syntax: CodeSpiral.SyntaxType) void {
        for (&self.spirals) |*s| {
            if (!s.isAlive()) {
                s.* = CodeSpiral.spawn(x, y, syntax);
                return;
            }
        }
    }

    pub fn update(self: *SpiralSystem, dt: f32) void {
        for (&self.spirals) |*s| {
            if (s.isAlive()) {
                s.update(dt);
            }
        }
    }

    pub fn draw(self: *const SpiralSystem) void {
        for (&self.spirals) |*s| {
            s.draw();
        }
    }
};

// =============================================================================
// TOOL CLUSTER (Orbiting execution indicators)
// =============================================================================

const MAX_TOOLS = 8;

const ToolOrbit = struct {
    name: [32]u8,
    name_len: usize,
    cx: f32,
    cy: f32,
    radius: f32,
    angle: f32,
    speed: f32,
    status: ToolStatus,
    life: f32,

    const ToolStatus = enum {
        pending, // Yellow
        running, // Cyan pulse
        success, // Green nova
        failure, // Red sink
    };

    pub fn spawn(cx: f32, cy: f32, name: []const u8) ToolOrbit {
        var tool = ToolOrbit{
            .name = undefined,
            .name_len = @min(name.len, 32),
            .cx = cx,
            .cy = cy,
            .radius = 100.0 + @as(f32, @floatFromInt(name.len % 5)) * 20.0,
            .angle = @as(f32, @floatFromInt(name.len)) * 0.5,
            .speed = 1.0,
            .status = .pending,
            .life = 1.0,
        };
        @memcpy(tool.name[0..tool.name_len], name[0..tool.name_len]);
        return tool;
    }

    pub fn update(self: *ToolOrbit, dt: f32) void {
        self.angle += self.speed * dt;

        switch (self.status) {
            .running => self.speed = 3.0,
            .success => {
                self.radius += dt * 50.0;
                self.life -= dt * 0.5;
            },
            .failure => {
                self.radius -= dt * 30.0;
                self.life -= dt * 0.5;
            },
            else => {},
        }
    }

    pub fn isAlive(self: *const ToolOrbit) bool {
        return self.life > 0 and self.radius > 0;
    }

    pub fn draw(self: *const ToolOrbit, time: f32) void {
        if (!self.isAlive()) return;

        const x = self.cx + @cos(self.angle) * self.radius;
        const y = self.cy + @sin(self.angle) * self.radius;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));

        const color: rl.Color = switch (self.status) {
            .pending => rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha },
            .running => blk: {
                const pulse: u8 = @intFromFloat(128.0 + @sin(time * 10.0) * 127.0);
                break :blk rl.Color{ .r = 0x00, .g = pulse, .b = 0xFF, .a = alpha };
            },
            .success => rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = alpha },
            .failure => rl.Color{ .r = 0xFF, .g = 0x00, .b = 0x44, .a = alpha },
        };

        // Draw tool as pulsating circle
        const size = 8.0 + @sin(time * 5.0 + self.angle) * 3.0;
        rl.DrawCircle(@intFromFloat(x), @intFromFloat(y), size, color);

        // Draw orbit path (faint)
        rl.DrawCircleLines(@intFromFloat(self.cx), @intFromFloat(self.cy), self.radius, rl.Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha / 4 });
    }
};

const ToolSystem = struct {
    tools: [MAX_TOOLS]ToolOrbit,
    count: usize,

    pub fn init() ToolSystem {
        var sys = ToolSystem{
            .tools = undefined,
            .count = 0,
        };
        for (&sys.tools) |*t| {
            t.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *ToolSystem, cx: f32, cy: f32, name: []const u8) void {
        for (&self.tools) |*t| {
            if (!t.isAlive()) {
                t.* = ToolOrbit.spawn(cx, cy, name);
                return;
            }
        }
    }

    pub fn setStatus(self: *ToolSystem, name: []const u8, status: ToolOrbit.ToolStatus) void {
        for (&self.tools) |*t| {
            if (t.isAlive() and std.mem.eql(u8, t.name[0..t.name_len], name)) {
                t.status = status;
                return;
            }
        }
    }

    pub fn update(self: *ToolSystem, dt: f32) void {
        for (&self.tools) |*t| {
            if (t.isAlive()) {
                t.update(dt);
            }
        }
    }

    pub fn draw(self: *const ToolSystem, time: f32) void {
        for (&self.tools) |*t| {
            t.draw(time);
        }
    }
};

// =============================================================================
// COSMIC FEEDBACK (Nova/Sink effects)
// =============================================================================

const MAX_EFFECTS = 16;

const CosmicEffect = struct {
    x: f32,
    y: f32,
    radius: f32,
    life: f32,
    is_nova: bool, // true = success nova, false = failure sink

    pub fn spawnNova(x: f32, y: f32) CosmicEffect {
        return .{
            .x = x,
            .y = y,
            .radius = 10.0,
            .life = 1.0,
            .is_nova = true,
        };
    }

    pub fn spawnSink(x: f32, y: f32) CosmicEffect {
        return .{
            .x = x,
            .y = y,
            .radius = 100.0,
            .life = 1.0,
            .is_nova = false,
        };
    }

    pub fn update(self: *CosmicEffect, dt: f32) void {
        if (self.is_nova) {
            self.radius += dt * 200.0; // Expand
        } else {
            self.radius -= dt * 80.0; // Contract
        }
        self.life -= dt * 1.5;
    }

    pub fn isAlive(self: *const CosmicEffect) bool {
        return self.life > 0 and self.radius > 0;
    }

    pub fn draw(self: *const CosmicEffect) void {
        if (!self.isAlive()) return;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));

        if (self.is_nova) {
            // Success: bright expanding rings
            const num_rings: usize = 5;
            for (0..num_rings) |i| {
                const ring_r = self.radius * (1.0 - @as(f32, @floatFromInt(i)) * 0.15);
                const ring_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(alpha)) * (1.0 - @as(f32, @floatFromInt(i)) * 0.2));
                rl.DrawCircleLines(
                    @intFromFloat(self.x),
                    @intFromFloat(self.y),
                    ring_r,
                    rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha },
                );
            }
            // Center flash
            rl.DrawCircle(@intFromFloat(self.x), @intFromFloat(self.y), 10.0, rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = alpha });
        } else {
            // Failure: dark collapsing vortex
            const num_rings: usize = 5;
            for (0..num_rings) |i| {
                const ring_r = self.radius * (0.2 + @as(f32, @floatFromInt(i)) * 0.2);
                rl.DrawCircleLines(
                    @intFromFloat(self.x),
                    @intFromFloat(self.y),
                    ring_r,
                    rl.Color{ .r = 0xFF, .g = 0x00, .b = 0x44, .a = alpha },
                );
            }
            // Dark center
            rl.DrawCircle(@intFromFloat(self.x), @intFromFloat(self.y), self.radius * 0.3, rl.Color{ .r = 0x20, .g = 0x00, .b = 0x10, .a = alpha });
        }
    }
};

const EffectSystem = struct {
    effects: [MAX_EFFECTS]CosmicEffect,

    pub fn init() EffectSystem {
        var sys = EffectSystem{
            .effects = undefined,
        };
        for (&sys.effects) |*e| {
            e.life = 0;
        }
        return sys;
    }

    pub fn nova(self: *EffectSystem, x: f32, y: f32) void {
        for (&self.effects) |*e| {
            if (!e.isAlive()) {
                e.* = CosmicEffect.spawnNova(x, y);
                return;
            }
        }
    }

    pub fn sink(self: *EffectSystem, x: f32, y: f32) void {
        for (&self.effects) |*e| {
            if (!e.isAlive()) {
                e.* = CosmicEffect.spawnSink(x, y);
                return;
            }
        }
    }

    pub fn update(self: *EffectSystem, dt: f32) void {
        for (&self.effects) |*e| {
            if (e.isAlive()) {
                e.update(dt);
            }
        }
    }

    pub fn draw(self: *const EffectSystem) void {
        for (&self.effects) |*e| {
            e.draw();
        }
    }
};

// =============================================================================
// AUTONOMOUS GOAL (Self-directed wave growth)
// =============================================================================

const WaveSeed = struct {
    x: usize,
    y: usize,
    active: bool,
};

const AutonomousGoal = struct {
    text: [256]u8,
    len: usize,
    x: f32,
    y: f32,
    progress: f32, // 0.0 to 1.0
    wave_seeds: [8]WaveSeed,
    active: bool,

    pub fn init() AutonomousGoal {
        return .{
            .text = undefined,
            .len = 0,
            .x = 0,
            .y = 0,
            .progress = 0,
            .wave_seeds = [_]WaveSeed{.{ .x = 0, .y = 0, .active = false }} ** 8,
            .active = false,
        };
    }

    pub fn setGoal(self: *AutonomousGoal, goal: []const u8, x: f32, y: f32) void {
        self.len = @min(goal.len, 256);
        @memcpy(self.text[0..self.len], goal[0..self.len]);
        self.x = x;
        self.y = y;
        self.progress = 0;
        self.active = true;

        // Generate wave seeds based on goal text
        for (0..8) |i| {
            if (i < goal.len) {
                const c = goal[i % goal.len];
                self.wave_seeds[i] = .{
                    .x = @intCast((@as(usize, c) * 3 + i * 17) % 378),
                    .y = @intCast((@as(usize, c) * 7 + i * 23) % 245),
                    .active = true,
                };
            }
        }
    }

    pub fn update(self: *AutonomousGoal, grid: *photon.PhotonGrid, dt: f32) void {
        if (!self.active) return;

        // Inject waves at seed points
        for (&self.wave_seeds) |*seed| {
            if (seed.active and seed.x < grid.width and seed.y < grid.height) {
                grid.getMut(seed.x, seed.y).amplitude += @sin(self.progress * TAU) * 0.5;
            }
        }

        // Progress grows based on grid energy
        self.progress += dt * 0.05 * (1.0 + grid.total_energy * 0.0001);

        if (self.progress >= 1.0) {
            self.active = false;
        }
    }

    pub fn draw(self: *const AutonomousGoal, time: f32) void {
        if (!self.active) return;

        const alpha: u8 = @intFromFloat(150.0 + @sin(time * 2.0) * 50.0);

        // Draw progress arc
        const arc_radius: f32 = 150.0;
        const arc_steps: usize = @intFromFloat(self.progress * 64.0);

        for (0..arc_steps) |i| {
            const angle = @as(f32, @floatFromInt(i)) * TAU / 64.0 - TAU / 4.0;
            const px = self.x + @cos(angle) * arc_radius;
            const py = self.y + @sin(angle) * arc_radius;

            rl.DrawCircle(@intFromFloat(px), @intFromFloat(py), 3.0, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha });
        }

        // Draw seed points
        for (&self.wave_seeds) |seed| {
            if (seed.active) {
                const sx: c_int = @intCast(seed.x * @as(usize, @intCast(g_pixel_size)));
                const sy: c_int = @intCast(seed.y * @as(usize, @intCast(g_pixel_size)));
                rl.DrawCircle(sx, sy, 5.0 + @sin(time * 5.0) * 2.0, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 100 });
            }
        }
    }
};

// =============================================================================
// INPUT BUFFER (For text/goal input)
// =============================================================================

const InputBuffer = struct {
    buffer: [512]u8,
    len: usize,
    active: bool,
    mode: InputMode,

    const InputMode = enum {
        chat,
        goal,
        code,
    };

    pub fn init() InputBuffer {
        return .{
            .buffer = undefined,
            .len = 0,
            .active = true, // Start active - ready to type!
            .mode = .chat,
        };
    }

    pub fn start(self: *InputBuffer, mode: InputMode) void {
        self.len = 0;
        self.active = true;
        self.mode = mode;
    }

    pub fn addChar(self: *InputBuffer, c: u8) void {
        if (self.len < 511) {
            self.buffer[self.len] = c;
            self.len += 1;
        }
    }

    pub fn backspace(self: *InputBuffer) void {
        if (self.len > 0) {
            self.len -= 1;
        }
    }

    pub fn getText(self: *const InputBuffer) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn submit(self: *InputBuffer) []const u8 {
        const text = self.getText();
        self.active = false;
        return text;
    }

    pub fn draw(self: *const InputBuffer, time: f32) void {
        // Always draw input box (even when not active, show hint)
        const box_y = g_height - 60;
        rl.DrawRectangle(0, box_y, g_width, 60, withAlpha(BG_INPUT, 220));

        if (!self.active) {
            // Show hint when not active
            rl.DrawText("Press C=Chat, G=Goal, X=Code, ESC=Exit", 20, box_y + 20, 18, MUTED_GRAY);
            return;
        }

        const label = switch (self.mode) {
            .chat => "CHAT> ",
            .goal => "GOAL> ",
            .code => "CODE> ",
        };

        // Label with bright color
        rl.DrawText(label.ptr, 20, box_y + 20, 20, NEON_GREEN);

        // Text
        var display_buf: [520]u8 = undefined;
        const display_len = @min(self.len, 500);
        @memcpy(display_buf[0..display_len], self.buffer[0..display_len]);

        // Cursor blink
        if (@mod(@as(u32, @intFromFloat(time * 3.0)), 2) == 0) {
            display_buf[display_len] = '_';
            display_buf[display_len + 1] = 0;
        } else {
            display_buf[display_len] = 0;
        }

        rl.DrawText(@ptrCast(&display_buf), 90, box_y + 20, 20, NOVA_WHITE);

        // Show Enter hint
        rl.DrawText("Enter=Send | ESC=Cancel", g_width - 220, box_y + 20, 14, TEXT_HINT);
    }
};

// =============================================================================
// MAIN TRINITY CANVAS
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Raylib init - RESIZABLE WINDOW (responsive!)
    // High DPI + MSAA + TRANSPARENT background (see desktop through)
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT | rl.FLAG_WINDOW_HIGHDPI | rl.FLAG_WINDOW_TRANSPARENT);
    rl.InitWindow(1280, 800, "TRINITY v1.7 | Shift+1-7 = Panels | phi^2 + 1/phi^2 = 3");
    defer rl.CloseWindow();

    // Set minimum window size for responsive design
    rl.SetWindowMinSize(800, 600);

    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // Load custom font (Montserrat - clean modern like Outfit)
    // Load Outfit font (same as website landing page) - larger sizes for HiDPI
    const font = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", 48, null, 0);
    defer rl.UnloadFont(font);
    const font_small = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", 32, null, 0);
    defer rl.UnloadFont(font_small);
    // Enable texture filtering for smooth fonts
    rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_BILINEAR);
    rl.SetTextureFilter(font_small.texture, rl.TEXTURE_FILTER_BILINEAR);

    // Grid (fixed size - will scale to window)
    const grid_w: usize = 320;
    const grid_h: usize = 200;

    var grid = try photon.PhotonGrid.init(allocator, grid_w, grid_h);
    defer grid.deinit();

    // Systems
    var clusters = ClusterSystem.init();
    var spirals = SpiralSystem.init();
    var tools = ToolSystem.init();
    var effects = EffectSystem.init();
    var goal = AutonomousGoal.init();
    var panels = PanelSystem.init();

    // State
    var time: f32 = 0;
    var mode: TrinityMode = .idle; // Start in idle mode - fullscreen canvas
    var cursor_hue: f32 = 120;

    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();

    rl.SetTargetFPS(60);
    // Show cursor for window resizing
    rl.ShowCursor();
    // Focus window for keyboard input
    rl.SetWindowFocused();

    // Initialize logo animation
    var logo_anim = LogoAnimation.init(@floatFromInt(g_width), @floatFromInt(g_height));
    var loading_complete = false;

    // Main loop
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        time += dt;

        // Update window size (adaptive/resizable)
        g_width = rl.GetScreenWidth();
        g_height = rl.GetScreenHeight();

        // Calculate pixel size to fit grid in window
        const px_w = @divTrunc(g_width, @as(c_int, @intCast(grid.width)));
        const px_h = @divTrunc(g_height, @as(c_int, @intCast(grid.height)));
        g_pixel_size = @max(1, @min(px_w, px_h));

        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();
        const mx = @as(f32, @floatFromInt(mouse_x));
        const my = @as(f32, @floatFromInt(mouse_y));

        const gx = @as(usize, @intCast(@max(0, @min(@as(c_int, @intCast(grid.width - 1)), @divTrunc(mouse_x, g_pixel_size)))));
        const gy = @as(usize, @intCast(@max(0, @min(@as(c_int, @intCast(grid.height - 1)), @divTrunc(mouse_y, g_pixel_size)))));

        cursor_hue = @mod(cursor_hue + dt * 30.0, 360.0);

        // === INPUT HANDLING ===

        // Panel focus (Shift+1-7)
        const shift_held = rl.IsKeyDown(rl.KEY_LEFT_SHIFT) or rl.IsKeyDown(rl.KEY_RIGHT_SHIFT);

        // Calculate centered panel positions
        const screen_w = @as(f32, @floatFromInt(g_width));
        const screen_h = @as(f32, @floatFromInt(g_height));

        if (shift_held) {
            if (rl.IsKeyPressed(rl.KEY_ONE)) {
                const pw: f32 = 500;
                const ph: f32 = 400;
                panels.jarvisFocus(.chat, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "CHAT");
            }
            if (rl.IsKeyPressed(rl.KEY_TWO)) {
                const pw: f32 = 550;
                const ph: f32 = 450;
                panels.jarvisFocus(.code, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "CODE");
            }
            if (rl.IsKeyPressed(rl.KEY_THREE)) {
                const pw: f32 = 400;
                const ph: f32 = 350;
                panels.jarvisFocus(.tools, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "TOOLS");
            }
            if (rl.IsKeyPressed(rl.KEY_FOUR)) {
                const pw: f32 = 380;
                const ph: f32 = 320;
                panels.jarvisFocus(.settings, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "SETTINGS");
            }
            if (rl.IsKeyPressed(rl.KEY_FIVE)) {
                const pw: f32 = 450;
                const ph: f32 = 400;
                panels.jarvisFocus(.vision, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "VISION");
            }
            if (rl.IsKeyPressed(rl.KEY_SIX)) {
                const pw: f32 = 420;
                const ph: f32 = 350;
                panels.jarvisFocus(.voice, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "VOICE");
            }
            if (rl.IsKeyPressed(rl.KEY_SEVEN)) {
                const pw: f32 = 500;
                const ph: f32 = 450;
                panels.jarvisFocus(.finder, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "FINDER");
            }
            if (rl.IsKeyPressed(rl.KEY_EIGHT)) {
                const pw: f32 = 400;
                const ph: f32 = 320;
                panels.jarvisFocus(.system, (screen_w - pw) / 2, (screen_h - ph) / 2, pw, ph, "SYSTEM");
            }
        }

        // ESC unfocuses all panels
        if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
            panels.unfocusAll();
        }

        // === DIRECT CHAT PANEL INPUT ===
        // When chat panel is focused, input goes directly to panel (not global input box)
        const focused_chat_panel: ?*GlassPanel = blk: {
            if (panels.active_panel) |idx| {
                if (panels.panels[idx].is_focused and panels.panels[idx].panel_type == .chat) {
                    break :blk &panels.panels[idx];
                }
            }
            break :blk null;
        };

        if (focused_chat_panel) |chat_panel| {
            // Skip chat input when Shift is held (for panel switching Shift+N)
            const shift_held_for_input = rl.IsKeyDown(rl.KEY_LEFT_SHIFT) or rl.IsKeyDown(rl.KEY_RIGHT_SHIFT);
            if (!shift_held_for_input) {
                // Text input directly to chat panel
                var char_key = rl.GetCharPressed();
                while (char_key > 0) {
                    if (char_key >= 32 and char_key <= 126 and chat_panel.chat_input_len < 250) {
                        chat_panel.chat_input[chat_panel.chat_input_len] = @intCast(char_key);
                        chat_panel.chat_input_len += 1;
                    }
                    char_key = rl.GetCharPressed();
                }
            }

            // Backspace
            if (rl.IsKeyPressed(rl.KEY_BACKSPACE) and chat_panel.chat_input_len > 0) {
                chat_panel.chat_input_len -= 1;
            }

            // Enter sends message
            if (rl.IsKeyPressed(rl.KEY_ENTER) and chat_panel.chat_input_len > 0) {
                // Get text from chat panel's input
                var msg_buf: [256]u8 = undefined;
                @memcpy(msg_buf[0..chat_panel.chat_input_len], chat_panel.chat_input[0..chat_panel.chat_input_len]);

                // Add user message
                chat_panel.addChatMessage(msg_buf[0..chat_panel.chat_input_len], true);

                // Simulate AI response
                const responses = [_][]const u8{
                    "Cosmic patterns detected in your query!",
                    "Trinity wave processing complete.",
                    "phi^2 + 1/phi^2 = 3. Your message resonates.",
                    "Emergence acknowledged. Koschei responds.",
                    "Wave function collapsed. Answer manifest.",
                };
                const resp_idx = @as(usize, @intCast(@mod(@as(i32, @intFromFloat(time * 100)), 5)));
                chat_panel.addChatMessage(responses[resp_idx], false);

                // Nova effect at panel center
                effects.nova(chat_panel.x + chat_panel.width / 2, chat_panel.y + chat_panel.height / 2);

                // Clear input
                chat_panel.chat_input_len = 0;
            }
        } else {
            // Normal controls (no global input - use Shift+N for panels)

            // T = Tool spawn (demo)
            if (rl.IsKeyPressed(rl.KEY_T)) {
                const center_x = @as(f32, @floatFromInt(g_width)) / 2.0;
                const center_y = @as(f32, @floatFromInt(g_height)) / 2.0;
                tools.spawn(center_x, center_y, "inference");
                tools.setStatus("inference", .running);
                mode = .tools;
            }

            // V = Vision (inject image perturbation - demo)
            if (rl.IsKeyPressed(rl.KEY_V)) {
                // Simulate image loading as grid perturbation
                for (0..grid.height) |y| {
                    for (0..grid.width) |x| {
                        const px = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(grid.width));
                        const py = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(grid.height));
                        const pattern = @sin(px * TAU * 4.0) * @cos(py * TAU * 4.0);
                        grid.getMut(x, y).amplitude += pattern * 0.3;
                    }
                }
                clusters.spawn(mx, my, "VISION INPUT", false);
                mode = .vision;
            }

            // A = Voice/Audio mode (frequency modulation)
            if (rl.IsKeyPressed(rl.KEY_A)) {
                // Simulate voice as frequency modulation
                const freq_mod = @sin(time * 10.0) * 0.5;
                for (grid.photons[0..grid.width]) |*p| {
                    p.frequency += freq_mod;
                }
                clusters.spawn(mx, my, "VOICE INPUT", false);
                mode = .voice;
            }

            // N = Nova effect (success)
            if (rl.IsKeyPressed(rl.KEY_N)) {
                effects.nova(mx, my);
            }

            // S = Sink effect (failure)
            if (rl.IsKeyPressed(rl.KEY_S)) {
                effects.sink(mx, my);
            }

            // R = Reset
            if (rl.IsKeyPressed(rl.KEY_R)) {
                for (grid.photons) |*p| {
                    p.amplitude = 0;
                    p.interference = 0;
                }
                const center_x = @as(f32, @floatFromInt(g_width)) / 2.0;
                const center_y = @as(f32, @floatFromInt(g_height)) / 2.0;
                clusters.spawn(center_x, center_y, "REBIRTH", false);
                mode = .idle;
            }

            // Mouse interactions
            if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
                if (gx < grid.width and gy < grid.height) {
                    grid.setCursor(@floatFromInt(gx), @floatFromInt(gy), 1.0);
                }
            }

            if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_RIGHT)) {
                if (gx < grid.width and gy < grid.height) {
                    grid.getMut(gx, gy).amplitude = -1.0;
                }
            }
        }

        // === UPDATE ===
        grid.stepSIMD();
        clusters.update(dt);
        spirals.update(dt);
        tools.update(dt);
        effects.update(dt);
        goal.update(&grid, dt);

        // Update panels with mouse state
        const mouse_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
        const mouse_down_state = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT);
        const mouse_released = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);
        const mouse_wheel = rl.GetMouseWheelMove();
        panels.update(dt, time, mx, my, mouse_pressed, mouse_down_state, mouse_released, mouse_wheel);

        // Check autonomous goal completion
        if (goal.progress >= 1.0 and mode == .autonomous) {
            effects.nova(goal.x, goal.y);
            clusters.spawn(goal.x, goal.y, "GOAL ACHIEVED", false);
            mode = .idle;
        }

        // === RENDER ===
        rl.BeginDrawing();
        defer rl.EndDrawing();

        // Pure black background - landing page style (alpha = 180 for transparency)
        rl.ClearBackground(rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xF5 });

        // === LOGO LOADING ANIMATION (Apple-style luxury welcome) ===
        if (!loading_complete) {
            // Update logo animation
            logo_anim.logo_scale = @min(@as(f32, @floatFromInt(g_width)) / LogoAnimation.SVG_WIDTH, @as(f32, @floatFromInt(g_height)) / LogoAnimation.SVG_HEIGHT) * 0.35;
            logo_anim.logo_offset = .{ .x = @as(f32, @floatFromInt(g_width)) / 2, .y = @as(f32, @floatFromInt(g_height)) / 2 };
            logo_anim.update(dt);

            // Draw logo animation
            logo_anim.draw();

            // Check if animation complete
            if (logo_anim.is_complete) {
                loading_complete = true;
            }

            continue; // Skip main canvas rendering during loading
        }

        // Grid
        drawImmersiveGrid(&grid, time);

        // Systems
        clusters.draw(time);
        spirals.draw();
        tools.draw(time);
        effects.draw();
        goal.draw(time);

        // Static logo in center (small, glassmorphism green, stays after loading)
        logo_anim.logo_scale = @min(@as(f32, @floatFromInt(g_width)) / LogoAnimation.SVG_WIDTH, @as(f32, @floatFromInt(g_height)) / LogoAnimation.SVG_HEIGHT) * 0.35;
        logo_anim.logo_offset = .{ .x = @as(f32, @floatFromInt(g_width)) / 2, .y = @as(f32, @floatFromInt(g_height)) / 2 };
        logo_anim.applyMouse(mx, my, dt);
        logo_anim.draw();

        // Glass panels (on top of everything except UI)
        panels.draw(time, font);

        // Mode indicator - REMOVED (Hyper style doesn't need it)
        // drawModeIndicator(mode, time);

        // No global input box - all input is inside panel windows

        // Keyboard hint (minimal, top-left) - larger font
        rl.DrawTextEx(font_small, "Shift+1-8 = Panel | ESC = Unfocus", .{ .x = 10, .y = 10 }, 13, 1, withAlpha(TEXT_DIM, 180));

        // === STATUS BAR (Hyper terminal style, bottom) ===
        const status_bar_h: f32 = 24;
        const status_y: f32 = @as(f32, @floatFromInt(g_height)) - status_bar_h;

        // Status bar background (Hyper style)
        rl.DrawRectangle(0, @intFromFloat(status_y), g_width, @intFromFloat(status_bar_h), withAlpha(BG_SURFACE, 240));
        rl.DrawLine(0, @intFromFloat(status_y), g_width, @intFromFloat(status_y), BORDER_SUBTLE);

        // Get system stats (simulated with realistic values)
        const cpu_usage: f32 = 15.0 + @sin(time * 0.5) * 10;
        const mem_used: f32 = 8.2 + @sin(time * 0.3) * 0.5;
        _ = @as(f32, 16.0); // mem_total (unused in rainbow mode)
        const cpu_temp: f32 = 42.0 + @sin(time * 0.7) * 5;
        const disk_used: f32 = 256.0;
        _ = @as(f32, 512.0); // disk_total (unused in rainbow mode)
        const net_down: f32 = 1.2 + @abs(@sin(time * 0.8)) * 2;
        const net_up: f32 = 0.3 + @abs(@sin(time * 0.6)) * 0.5;
        const processes: u32 = 234;
        const uptime_sec: u32 = @intFromFloat(time);

        var stat_buf: [64:0]u8 = undefined;
        const sw = @as(f32, @floatFromInt(g_width));

        // Left: TRINITY label in GREEN
        rl.DrawTextEx(font_small, "TRINITY", .{ .x = 12, .y = status_y + 5 }, 13, 0.5, HYPER_GREEN);

        // All stats aligned to RIGHT, close together
        const spacing: f32 = 75;
        var x_pos: f32 = sw - 12; // Start from right edge

        // Time (rightmost)
        var time_buf: [16:0]u8 = undefined;
        const display_time = @mod(@as(u32, @intFromFloat(time)), 86400);
        const hours = display_time / 3600;
        const minutes = (display_time % 3600) / 60;
        const seconds = display_time % 60;
        _ = std.fmt.bufPrintZ(&time_buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch {};
        x_pos -= 70;
        rl.DrawTextEx(font_small, &time_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, HYPER_MAGENTA); // Rainbow: Magenta

        // Uptime
        const up_hours = uptime_sec / 3600;
        const up_mins = (uptime_sec % 3600) / 60;
        _ = std.fmt.bufPrintZ(&stat_buf, "UP {d}h{d}m", .{ up_hours, up_mins }) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, PURPLE); // Rainbow: Purple

        // Processes
        _ = std.fmt.bufPrintZ(&stat_buf, "PROC {d}", .{processes}) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, BLUE); // Rainbow: Blue

        // NET
        _ = std.fmt.bufPrintZ(&stat_buf, "NET {d:.1}M", .{net_down + net_up}) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, HYPER_CYAN); // Rainbow: Cyan

        // DISK
        _ = std.fmt.bufPrintZ(&stat_buf, "DISK {d:.0}G", .{disk_used}) catch {};
        x_pos -= spacing + 10;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, HYPER_GREEN); // Rainbow: Green

        // TEMP
        _ = std.fmt.bufPrintZ(&stat_buf, "{d:.0}C", .{cpu_temp}) catch {};
        x_pos -= spacing - 30;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, HYPER_YELLOW); // Rainbow: Yellow

        // MEM
        _ = std.fmt.bufPrintZ(&stat_buf, "MEM {d:.1}G", .{mem_used}) catch {};
        x_pos -= spacing + 5;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, ORANGE); // Rainbow: Orange

        // CPU
        _ = std.fmt.bufPrintZ(&stat_buf, "CPU {d:.0}%", .{cpu_usage}) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, HYPER_RED); // Rainbow: Red
    }
}

// Custom input box with font
fn drawInputBox(input: *const InputBuffer, font: rl.Font, time: f32) void {
    const box_y = g_height - 60;
    rl.DrawRectangle(0, box_y, g_width, 60, withAlpha(BG_INPUT, 220));

    if (!input.active) {
        rl.DrawTextEx(font, "Press C=Chat, G=Goal, X=Code", .{ .x = 20, .y = @floatFromInt(box_y + 18) }, 20, 1, MUTED_GRAY);
        return;
    }

    const label = switch (input.mode) {
        .chat => "CHAT> ",
        .goal => "GOAL> ",
        .code => "CODE> ",
    };

    // Label with bright color
    rl.DrawTextEx(font, label.ptr, .{ .x = 20, .y = @floatFromInt(box_y + 18) }, 22, 1, NEON_GREEN);

    // Text (sentinel-terminated array)
    var display_buf: [520:0]u8 = undefined;
    const display_len = @min(input.len, 500);
    @memcpy(display_buf[0..display_len], input.buffer[0..display_len]);

    // Cursor blink
    if (@mod(@as(u32, @intFromFloat(time * 3.0)), 2) == 0) {
        display_buf[display_len] = '_';
        display_buf[display_len + 1] = 0;
    } else {
        display_buf[display_len] = 0;
    }

    rl.DrawTextEx(font, &display_buf, .{ .x = 100, .y = @floatFromInt(box_y + 18) }, 22, 1, NOVA_WHITE);

    // Hint
    rl.DrawText("Enter=Send", g_width - 100, box_y + 22, 14, TEXT_HINT);
}

fn drawImmersiveGrid(grid: *photon.PhotonGrid, time: f32) void {
    for (0..grid.height) |y| {
        for (0..grid.width) |x| {
            const p = grid.get(x, y);

            if (@abs(p.amplitude) < 0.01) continue;

            const px: c_int = @intCast(x * @as(usize, @intCast(g_pixel_size)));
            const py: c_int = @intCast(y * @as(usize, @intCast(g_pixel_size)));

            const hue = @mod(p.hue + time * 20.0 + p.phase * 10.0, 360.0);
            const brightness = @min(1.0, @abs(p.amplitude));

            const rgb = hsvToRgb(hue, 0.8, brightness);
            const alpha: u8 = @intFromFloat(@min(255.0, @abs(p.amplitude) * 300.0));

            const color = rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha };

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
    const pulse = (@sin(time * 5.0) + 1.0) * 0.5;

    rl.DrawCircle(px, py, 20 + pulse * 10, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 30 });
    rl.DrawCircle(px, py, 12 + pulse * 5, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 60 });
    rl.DrawCircleLines(px, py, 8 + pulse * 3, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 200 });
    rl.DrawCircleLines(px, py, 4 + pulse * 2, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
    rl.DrawCircle(px, py, 2, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

fn drawModeIndicator(mode: TrinityMode, time: f32) void {
    const label = switch (mode) {
        .idle => "EXPLORE",
        .chat => "CHAT",
        .code => "CODE",
        .vision => "VISION",
        .voice => "VOICE",
        .tools => "TOOLS",
        .autonomous => "AUTONOMOUS",
    };

    const color = switch (mode) {
        .idle => NEON_GREEN,
        .chat => NEON_CYAN,
        .code => NEON_PURPLE,
        .vision => NEON_MAGENTA,
        .voice => NEON_GOLD,
        .tools => NEON_CYAN,
        .autonomous => NEON_GOLD,
    };

    const alpha: u8 = @intFromFloat(150.0 + @sin(time * 2.0) * 50.0);
    const final_color = rl.Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };

    rl.DrawText(label.ptr, g_width - 150, 20, 24, final_color);
}

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
