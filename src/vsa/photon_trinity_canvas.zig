// =============================================================================
// TRINITY CANVAS v2.0 - HYPER TERMINAL STYLE (MODULAR)
// Colors imported from theme.zig - SINGLE SOURCE OF TRUTH
// Shift+1-8 = Panel Focus (Chat, Code, Tools, Settings, Vision, Voice, Finder, System)
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const photon = @import("photon.zig");
const wave_scroll = @import("wave_scroll.zig"); // Emergent Wave ScrollView v1.0
const theme = @import("trinity_canvas/theme.zig"); // SINGLE SOURCE OF TRUTH
const world_docs = @import("trinity_canvas/world_docs.zig");
const igla_chat = @import("igla_chat");
const fluent_chat = @import("igla_fluent_chat");
const auto_shard = @import("auto_shard");
const world_dots = @import("world_dots.zig");
const math = std.math;
const rl = @cImport({
    @cInclude("raylib.h");
});

// Global chat engines
var g_chat_engine: igla_chat.IglaLocalChat = igla_chat.IglaLocalChat.init();
var g_fluent_engine: fluent_chat.FluentChatEngine = undefined;
var g_fluent_engine_inited: bool = false;


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
// Adaptive font scale: proportional to screen width (reference: 1280px)
var g_font_scale: f32 = 1.0;
// HiDPI scale factor (2.0 on Retina, 1.0 on standard displays)
var g_dpi_scale: f32 = 1.0;
// Chat font (Montserrat with Cyrillic) — set in main()
var g_font_chat: rl.Font = undefined;

// ── Persistent chat state (survives panel close/reopen) ──
const MAX_CHAT_MSGS = 64;
const ChatMsgType = enum { user, ai, log };
var g_chat_messages: [MAX_CHAT_MSGS][256]u8 = undefined;
var g_chat_msg_lens: [MAX_CHAT_MSGS]usize = .{0} ** MAX_CHAT_MSGS;
var g_chat_msg_types: [MAX_CHAT_MSGS]ChatMsgType = .{.ai} ** MAX_CHAT_MSGS;
var g_chat_msg_count: usize = 0;
var g_chat_input: [256]u8 = undefined;
var g_chat_input_len: usize = 0;
var g_backspace_timer: f32 = 0;
var g_chat_scroll_y: f32 = 0;
var g_chat_scroll_target: f32 = 0;

fn addGlobalChatMessage(msg: []const u8, msg_type: ChatMsgType) void {
    if (g_chat_msg_count >= MAX_CHAT_MSGS) {
        // Shift messages up (drop oldest)
        for (0..MAX_CHAT_MSGS - 1) |i| {
            @memcpy(&g_chat_messages[i], &g_chat_messages[i + 1]);
            g_chat_msg_lens[i] = g_chat_msg_lens[i + 1];
            g_chat_msg_types[i] = g_chat_msg_types[i + 1];
        }
        g_chat_msg_count = MAX_CHAT_MSGS - 1;
    }
    const idx = g_chat_msg_count;
    const copy_len = @min(msg.len, 255);
    @memcpy(g_chat_messages[idx][0..copy_len], msg[0..copy_len]);
    g_chat_msg_lens[idx] = copy_len;
    g_chat_msg_types[idx] = msg_type;
    g_chat_msg_count += 1;
}

fn addChatLogMessage(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch "...";
    addGlobalChatMessage(text, .log);
}

// =============================================================================
// HYPER TERMINAL STYLE COLORS (from theme.zig - SINGLE SOURCE OF TRUTH)
// @bitCast converts theme.Color to rl.Color (same extern struct layout)
// =============================================================================

fn toRl(c: theme.Color) rl.Color {
    return @bitCast(c);
}

// === SWITCHABLE surface colors (var — re-read from theme on toggle) ===
// Initialized with comptime dark defaults; reloadThemeAliases() updates at runtime.
var BG_BLACK: rl.Color = @bitCast(theme.colors.bg);
var TEXT_WHITE: rl.Color = @bitCast(theme.colors.text);
var MUTED_GRAY: rl.Color = @bitCast(theme.colors.text_muted);
var BORDER_SUBTLE: rl.Color = @bitCast(theme.colors.border);
var VOID_BLACK: rl.Color = @bitCast(theme.colors.bg);
var NOVA_WHITE: rl.Color = @bitCast(theme.colors.text);
var GLASS_BG: rl.Color = @bitCast(theme.colors.bg_panel);
var GLASS_BORDER: rl.Color = @bitCast(theme.colors.border);
var BG_SURFACE: rl.Color = @bitCast(theme.colors.bg_surface);
var BG_INPUT: rl.Color = @bitCast(theme.colors.bg_input);
var BG_BAR: rl.Color = @bitCast(theme.colors.bg_bar);
var BG_HOVER: rl.Color = @bitCast(theme.colors.bg_hover);
var SEPARATOR: rl.Color = @bitCast(theme.colors.separator);
var BORDER_LIGHT: rl.Color = @bitCast(theme.colors.border_light);
var TEXT_DIM: rl.Color = @bitCast(theme.colors.text_dim);
var TEXT_HINT: rl.Color = @bitCast(theme.colors.text_hint);
var CONTENT_TEXT: rl.Color = @bitCast(theme.colors.content_text);

// Chat panel colors (theme-switchable)
var CHAT_TEXT: rl.Color = @bitCast(theme.colors.chat_text);
var CHAT_LABEL_USER: rl.Color = @bitCast(theme.colors.chat_label_user);
var CHAT_LABEL_AI: rl.Color = @bitCast(theme.colors.chat_label_ai);
var CHAT_BUBBLE_USER: rl.Color = @bitCast(theme.colors.chat_bubble_user);
var CHAT_BUBBLE_AI: rl.Color = @bitCast(theme.colors.chat_bubble_ai);
var CHAT_BUBBLE_BORDER: rl.Color = @bitCast(theme.colors.chat_bubble_border);
var CHAT_INPUT_BG: rl.Color = @bitCast(theme.colors.chat_input_bg);
var CHAT_INPUT_BORDER: rl.Color = @bitCast(theme.colors.chat_input_border);
var CHAT_INPUT_TEXT: rl.Color = @bitCast(theme.colors.chat_input_text);
var SACRED_HEADER_BG: rl.Color = @bitCast(theme.colors.sacred_header_bg);
var SACRED_HEADER_TEXT: rl.Color = @bitCast(theme.colors.sacred_header_text);

// === ACCENT colors (const — same in dark and light) ===
const HYPER_MAGENTA: rl.Color = @bitCast(theme.accents.magenta);
const HYPER_CYAN: rl.Color = @bitCast(theme.accents.cyan);
const HYPER_GREEN: rl.Color = @bitCast(theme.accents.green);
const HYPER_YELLOW: rl.Color = @bitCast(theme.accents.yellow);
const HYPER_RED: rl.Color = @bitCast(theme.accents.red);
const ACCENT_GREEN: rl.Color = @bitCast(theme.accents.green);
const NEON_CYAN: rl.Color = @bitCast(theme.accents.cyan);
const NEON_MAGENTA: rl.Color = @bitCast(theme.accents.magenta);
const NEON_GREEN: rl.Color = @bitCast(theme.accents.green);
const NEON_GOLD: rl.Color = @bitCast(theme.accents.yellow);
const NEON_PURPLE: rl.Color = @bitCast(theme.accents.magenta);
const SINK_RED: rl.Color = @bitCast(theme.accents.red);
const GLASS_GLOW: rl.Color = @bitCast(theme.accents.glow_magenta);
const RECORDING_RED: rl.Color = @bitCast(theme.accents.recording_red);
const GOLD: rl.Color = @bitCast(theme.accents.gold);
const BLUE: rl.Color = @bitCast(theme.accents.blue);
const ORANGE: rl.Color = @bitCast(theme.accents.orange);
const PURPLE: rl.Color = @bitCast(theme.accents.purple);
const LOGO_GREEN: rl.Color = @bitCast(theme.accents.logo_green);

// Panel traffic light buttons (const — always same)
const BTN_CLOSE: rl.Color = @bitCast(theme.panel.btn_close);
const BTN_MINIMIZE: rl.Color = @bitCast(theme.panel.btn_minimize);
const BTN_MAXIMIZE: rl.Color = @bitCast(theme.panel.btn_maximize);

// File type colors (const — accent-based)
const FILE_FOLDER: rl.Color = @bitCast(theme.accents.file_folder);
const FILE_ZIG: rl.Color = @bitCast(theme.accents.file_zig);
const FILE_CODE: rl.Color = @bitCast(theme.accents.file_code);
const FILE_IMAGE: rl.Color = @bitCast(theme.accents.file_image);
const FILE_AUDIO: rl.Color = @bitCast(theme.accents.file_audio);
const FILE_DOCUMENT: rl.Color = @bitCast(theme.accents.file_document);
const FILE_DATA: rl.Color = @bitCast(theme.accents.file_data);
const FILE_UNKNOWN: rl.Color = @bitCast(theme.accents.file_unknown);

// Helper: apply runtime alpha to a color
fn withAlpha(c: rl.Color, alpha: u8) rl.Color {
    return rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = alpha };
}

// Accent text color — vivid on dark theme, dark monochrome on light theme
// Use for any text that would be accent-colored; keeps icons/borders/decorative elements vivid.
fn accentText(accent: rl.Color, alpha: u8) rl.Color {
    // Dark theme: vivid accent color. Light theme: pure black for max contrast
    return if (theme.isDark()) withAlpha(accent, alpha) else rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = alpha };
}

// Reload all var aliases from theme after toggle()
fn reloadThemeAliases() void {
    BG_BLACK = @bitCast(theme.bg);
    TEXT_WHITE = @bitCast(theme.text);
    MUTED_GRAY = @bitCast(theme.text_muted);
    BORDER_SUBTLE = @bitCast(theme.border);
    VOID_BLACK = @bitCast(theme.bg);
    NOVA_WHITE = @bitCast(theme.text);
    GLASS_BG = @bitCast(theme.bg_panel);
    GLASS_BORDER = @bitCast(theme.border);
    BG_SURFACE = @bitCast(theme.bg_surface);
    BG_INPUT = @bitCast(theme.bg_input);
    BG_BAR = @bitCast(theme.bg_bar);
    BG_HOVER = @bitCast(theme.bg_hover);
    SEPARATOR = @bitCast(theme.separator);
    BORDER_LIGHT = @bitCast(theme.border_light);
    TEXT_DIM = @bitCast(theme.text_dim);
    TEXT_HINT = @bitCast(theme.text_hint);
    CONTENT_TEXT = @bitCast(theme.content_text);
    CHAT_TEXT = @bitCast(theme.chat_text);
    CHAT_LABEL_USER = @bitCast(theme.chat_label_user);
    CHAT_LABEL_AI = @bitCast(theme.chat_label_ai);
    CHAT_BUBBLE_USER = @bitCast(theme.chat_bubble_user);
    CHAT_BUBBLE_AI = @bitCast(theme.chat_bubble_ai);
    CHAT_BUBBLE_BORDER = @bitCast(theme.chat_bubble_border);
    CHAT_INPUT_BG = @bitCast(theme.chat_input_bg);
    CHAT_INPUT_BORDER = @bitCast(theme.chat_input_border);
    CHAT_INPUT_TEXT = @bitCast(theme.chat_input_text);
    SACRED_HEADER_BG = @bitCast(theme.sacred_header_bg);
    SACRED_HEADER_TEXT = @bitCast(theme.sacred_header_text);
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

const sacred_worlds = @import("trinity_canvas/sacred_worlds.zig");

const LogoAnimation = struct {
    blocks: [27]LogoBlock,
    time: f32,
    duration: f32,
    is_complete: bool,
    logo_scale: f32, // Scale the logo to fit screen
    logo_offset: rl.Vector2, // Center the logo on screen
    hovered_block: i32, // Index of block under cursor (-1 = none)
    clicked_block: i32, // Block clicked this frame (-1 = none)

    // SVG viewBox: 596 x 526, center at ~298, 263
    const SVG_WIDTH: f32 = 596.0;
    const SVG_HEIGHT: f32 = 526.0;
    const SVG_CENTER_X: f32 = 298.0;
    const SVG_CENTER_Y: f32 = 263.0;

    pub fn init(screen_w: f32, screen_h: f32) LogoAnimation {
        var self = LogoAnimation{
            .blocks = undefined,
            .time = 0,
            .duration = 2.5, // Fast assembly animation
            .is_complete = false,
            .logo_scale = @min(screen_w / SVG_WIDTH, screen_h / SVG_HEIGHT) * 0.35,
            .logo_offset = .{ .x = screen_w / 2, .y = screen_h / 2 },
            .hovered_block = -1,
            .clicked_block = -1,
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
            const distance: f32 = 800.0; // Shorter travel distance — faster entrance
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
                // Straight flight — exponential ease-in toward center
                const speed = 4.5 * dt;
                block.offset.x -= block.offset.x * speed;
                block.offset.y -= block.offset.y * speed;

                // Carry momentum into spring phase
                block.anim_vx = -block.offset.x * 0.4;
                block.anim_vy = -block.offset.y * 0.4;
                block.anim_vr = 0;
            } else {
                // Spring phase — snappy elastic settle
                const spring_k: f32 = 28.0;
                const damp: f32 = 0.86;

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

        // Brief pause after assembly before transitioning
        if (all_done and self.time > self.duration + 0.5) {
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

    /// Highlight block under cursor + detect clicks
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

                // Apply rotation around block center (must match draw())
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

        // Hover color: highlight petal on hover (switches with theme)
        const highlight_color: rl.Color = @bitCast(theme.logo_highlight);

        // Petals — spider web look (switches with theme: black on dark, white on light)
        const petal_color: rl.Color = @bitCast(theme.logo_petal);

        // Outline — spider web threads (switches with theme)
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

            // Outline — integer-width line to avoid sub-pixel artifacts
            var m: usize = 0;
            while (m < cnt) : (m += 1) {
                const next = (m + 1) % cnt;
                rl.DrawLineEx(verts[m], verts[next], 1.0, outline_color);
            }
        }
    }
};

// =============================================================================
// =============================================================================
// SACRED FORMULA PARTICLES - Fibonacci spiral orbiting formulas
// =============================================================================

const FormulaParticle = struct {
    text: [48:0]u8,
    text_len: u8,
    desc: [80:0]u8,
    desc_len: u8,
    // Fibonacci spiral parameters
    base_angle: f32, // base position on spiral
    orbit_radius: f32, // distance from center
    orbit_speed: f32, // angular velocity (rad/s)
    angle_offset: f32, // current offset from mouse push
    expanded: bool,
    expand_anim: f32,

    fn init(text: []const u8, desc: []const u8, base_angle_val: f32, radius: f32, speed: f32) FormulaParticle {
        var p: FormulaParticle = undefined;
        const tlen = @min(text.len, 47);
        @memcpy(p.text[0..tlen], text[0..tlen]);
        p.text[tlen] = 0;
        p.text_len = @intCast(tlen);
        const dlen = @min(desc.len, 79);
        @memcpy(p.desc[0..dlen], desc[0..dlen]);
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

        // Check if mouse is near this formula
        const ddx = pos.x - mouse_x;
        const ddy = pos.y - mouse_y;
        const dist = @sqrt(ddx * ddx + ddy * ddy + 1.0);
        const hover_radius: f32 = 60.0;

        if (dist < hover_radius) {
            // STOP: counter the orbital rotation so formula stays in place
            self.angle_offset -= self.orbit_speed * dt;
        }

        // Slowly return angle_offset to 0 when not hovered
        if (dist >= hover_radius) {
            self.angle_offset *= (1.0 - 0.8 * dt);
        }

        // Click to expand
        if (mouse_pressed) {
            const tw = @as(f32, @floatFromInt(self.text_len)) * 8.0;
            const half_tw = tw / 2;
            if (mouse_x >= pos.x - half_tw - 5 and mouse_x <= pos.x + half_tw + 5 and
                mouse_y >= pos.y - 10 and mouse_y <= pos.y + 18)
            {
                self.expanded = !self.expanded;
            }
        }

        // Expand animation
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

        // Draw formula text (centered)
        rl.DrawTextEx(font, &self.text, .{ .x = pos.x - tw / 2, .y = pos.y - 7 }, 14, 0.5, text_color);

        // Expanded description (no background rect — clean text only)
        if (self.expand_anim > 0.3) {
            const desc_alpha: u8 = @intFromFloat(@min(self.expand_anim, 1.0) * 200.0);
            // On light theme: dark text (accent green invisible on white)
            const desc_accent = @as(rl.Color, @bitCast(theme.accents.logo_green));
            const desc_color = if (theme.isDark()) withAlpha(desc_accent, desc_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.text)), desc_alpha);
            const dw = @as(f32, @floatFromInt(self.desc_len)) * 7.0;
            rl.DrawTextEx(font, &self.desc, .{ .x = pos.x - dw / 2, .y = pos.y + 12 }, 12, 0.5, desc_color);
        }
    }
};

const MAX_FORMULA_PARTICLES = 42;

// ADVANCED WINDOW SYSTEM - GLASSMORPHISM PANELS
// Floating невесомые windows with phi-based animations
// =============================================================================

const MAX_PANELS = 12;
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
    sacred_world, // Sacred Mathematics world panel (27 worlds)
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

// =============================================================================
// NETWORK ADMIN — Node connection tracking for distributed inference
// =============================================================================

const NodeStatus = enum {
    offline,
    connecting,
    online,
    degraded,
    error_state,

    pub fn label(self: NodeStatus) []const u8 {
        return switch (self) {
            .offline => "OFFLINE",
            .connecting => "CONNECTING",
            .online => "ONLINE",
            .degraded => "DEGRADED",
            .error_state => "ERROR",
        };
    }
};

const NetworkNode = struct {
    name: [32]u8,
    name_len: u8,
    address: [48]u8,
    address_len: u8,
    location: [32]u8,
    location_len: u8,
    geo_lat: f32, // latitude (-90..90)
    geo_lon: f32, // longitude (-180..180)
    status: NodeStatus,
    layers_start: u8,
    layers_end: u8,
    ram_mb: u16,
    latency_ms: u16,
    tokens_processed: u32,
    role: [16]u8,
    role_len: u8,
    session_time_ms: u32,
    is_local: bool,

    pub fn init() NetworkNode {
        return .{
            .name = undefined,
            .name_len = 0,
            .address = undefined,
            .address_len = 0,
            .location = undefined,
            .location_len = 0,
            .geo_lat = 0,
            .geo_lon = 0,
            .status = .offline,
            .layers_start = 0,
            .layers_end = 0,
            .ram_mb = 0,
            .latency_ms = 0,
            .tokens_processed = 0,
            .role = undefined,
            .role_len = 0,
            .session_time_ms = 0,
            .is_local = true,
        };
    }
};

fn mkNode(name: []const u8, addr: []const u8, role: []const u8, loc: []const u8, glat: f32, glon: f32, status: NodeStatus, l_start: u8, l_end: u8, ram: u16, latency: u16, tokens: u32, session: u32, local: bool) NetworkNode {
    var n = NetworkNode.init();
    const nl = @min(name.len, 31);
    @memcpy(n.name[0..nl], name[0..nl]);
    n.name_len = @intCast(nl);
    const al = @min(addr.len, 47);
    @memcpy(n.address[0..al], addr[0..al]);
    n.address_len = @intCast(al);
    const rl2 = @min(role.len, 15);
    @memcpy(n.role[0..rl2], role[0..rl2]);
    n.role_len = @intCast(rl2);
    const ll = @min(loc.len, 31);
    @memcpy(n.location[0..ll], loc[0..ll]);
    n.location_len = @intCast(ll);
    n.geo_lat = glat;
    n.geo_lon = glon;
    n.status = status;
    n.layers_start = l_start;
    n.layers_end = l_end;
    n.ram_mb = ram;
    n.latency_ms = latency;
    n.tokens_processed = tokens;
    n.session_time_ms = session;
    n.is_local = local;
    return n;
}

// Mercator projection: geo coords -> pixel position within map rect
fn geoToMap(lat: f32, lon: f32, map_x: f32, map_y: f32, map_w: f32, map_h: f32) struct { x: f32, y: f32 } {
    // lon: -180..180 -> 0..map_w
    const mx = map_x + ((lon + 180.0) / 360.0) * map_w;
    // lat: 90..-90 -> 0..map_h (simple equirectangular)
    const my = map_y + ((90.0 - lat) / 180.0) * map_h;
    return .{ .x = mx, .y = my };
}

// ── Runtime network state (detected at startup, updated dynamically) ──
const MAX_NETWORK_NODES = 8;
var g_network_nodes: [MAX_NETWORK_NODES]NetworkNode = [_]NetworkNode{NetworkNode.init()} ** MAX_NETWORK_NODES;
var g_network_node_count: usize = 0;
var g_network_total_layers: u8 = 0;
var g_network_model_name: [64]u8 = [_]u8{0} ** 64;
var g_network_model_name_len: usize = 0;
var g_network_initialized: bool = false;
var g_network_uptime_ms: u64 = 0;
var g_network_probe_thread: ?std.Thread = null;
var g_network_probe_done: bool = false;
var g_net_scroll_y: f32 = 0;
var g_net_scroll_target: f32 = 0;

// ── Timezone → Geo mapping (offline, instant, ~country-level accuracy) ──
const TzGeo = struct { tz: []const u8, lat: f32, lon: f32, city: []const u8 };
const TZ_MAP = [_]TzGeo{
    .{ .tz = "Asia/Bangkok", .lat = 13.75, .lon = 100.52, .city = "Bangkok, TH" },
    .{ .tz = "Asia/Ho_Chi_Minh", .lat = 10.82, .lon = 106.63, .city = "Ho Chi Minh, VN" },
    .{ .tz = "Asia/Singapore", .lat = 1.35, .lon = 103.82, .city = "Singapore, SG" },
    .{ .tz = "Asia/Tokyo", .lat = 35.68, .lon = 139.69, .city = "Tokyo, JP" },
    .{ .tz = "Asia/Shanghai", .lat = 31.23, .lon = 121.47, .city = "Shanghai, CN" },
    .{ .tz = "Asia/Kolkata", .lat = 28.61, .lon = 77.23, .city = "Delhi, IN" },
    .{ .tz = "Asia/Dubai", .lat = 25.20, .lon = 55.27, .city = "Dubai, AE" },
    .{ .tz = "Asia/Seoul", .lat = 37.57, .lon = 126.98, .city = "Seoul, KR" },
    .{ .tz = "Asia/Taipei", .lat = 25.03, .lon = 121.57, .city = "Taipei, TW" },
    .{ .tz = "Asia/Jakarta", .lat = -6.21, .lon = 106.85, .city = "Jakarta, ID" },
    .{ .tz = "Asia/Manila", .lat = 14.60, .lon = 120.98, .city = "Manila, PH" },
    .{ .tz = "Europe/Moscow", .lat = 55.76, .lon = 37.62, .city = "Moscow, RU" },
    .{ .tz = "Europe/London", .lat = 51.51, .lon = -0.13, .city = "London, UK" },
    .{ .tz = "Europe/Berlin", .lat = 52.52, .lon = 13.41, .city = "Berlin, DE" },
    .{ .tz = "Europe/Paris", .lat = 48.86, .lon = 2.35, .city = "Paris, FR" },
    .{ .tz = "Europe/Istanbul", .lat = 41.01, .lon = 28.98, .city = "Istanbul, TR" },
    .{ .tz = "Europe/Kyiv", .lat = 50.45, .lon = 30.52, .city = "Kyiv, UA" },
    .{ .tz = "Europe/Warsaw", .lat = 52.23, .lon = 21.01, .city = "Warsaw, PL" },
    .{ .tz = "Europe/Amsterdam", .lat = 52.37, .lon = 4.90, .city = "Amsterdam, NL" },
    .{ .tz = "Europe/Lisbon", .lat = 38.72, .lon = -9.14, .city = "Lisbon, PT" },
    .{ .tz = "America/New_York", .lat = 40.71, .lon = -74.01, .city = "New York, US" },
    .{ .tz = "America/Chicago", .lat = 41.88, .lon = -87.63, .city = "Chicago, US" },
    .{ .tz = "America/Denver", .lat = 39.74, .lon = -104.99, .city = "Denver, US" },
    .{ .tz = "America/Los_Angeles", .lat = 34.05, .lon = -118.24, .city = "Los Angeles, US" },
    .{ .tz = "America/Sao_Paulo", .lat = -23.55, .lon = -46.63, .city = "Sao Paulo, BR" },
    .{ .tz = "America/Toronto", .lat = 43.65, .lon = -79.38, .city = "Toronto, CA" },
    .{ .tz = "America/Mexico_City", .lat = 19.43, .lon = -99.13, .city = "Mexico City, MX" },
    .{ .tz = "America/Argentina/Buenos_Aires", .lat = -34.60, .lon = -58.38, .city = "Buenos Aires, AR" },
    .{ .tz = "Australia/Sydney", .lat = -33.87, .lon = 151.21, .city = "Sydney, AU" },
    .{ .tz = "Pacific/Auckland", .lat = -36.85, .lon = 174.76, .city = "Auckland, NZ" },
    .{ .tz = "Africa/Cairo", .lat = 30.04, .lon = 31.24, .city = "Cairo, EG" },
    .{ .tz = "Africa/Lagos", .lat = 6.52, .lon = 3.38, .city = "Lagos, NG" },
    .{ .tz = "Africa/Johannesburg", .lat = -26.20, .lon = 28.04, .city = "Johannesburg, ZA" },
};

/// Detect local geo coordinates from system timezone (offline, instant).
/// Reads /etc/localtime symlink on macOS/Linux → extracts TZ name → looks up in TZ_MAP.
/// Returns null if timezone cannot be determined.
fn detectTimezoneGeo() ?TzGeo {
    // macOS: /etc/localtime -> /var/db/timezone/zoneinfo/Asia/Bangkok
    // Linux: /etc/localtime -> /usr/share/zoneinfo/Asia/Bangkok
    var link_buf: [256]u8 = undefined;
    const link = std.fs.cwd().readLink("/etc/localtime", &link_buf) catch return null;

    // Extract timezone part after "zoneinfo/"
    const marker = "zoneinfo/";
    const idx = std.mem.indexOf(u8, link, marker) orelse return null;
    const tz_name = link[idx + marker.len ..];
    if (tz_name.len == 0) return null;

    // Look up in table
    for (TZ_MAP) |entry| {
        if (std.mem.eql(u8, entry.tz, tz_name)) return entry;
    }
    return null;
}

/// Geo result from IP API
const IpGeoResult = struct {
    lat: f32,
    lon: f32,
    city: [48]u8,
    city_len: usize,
};

/// Fetch geo coordinates via ip-api.com (online, city-level accuracy).
/// Uses curl subprocess with 3-second timeout. Pass null for local public IP.
/// Works from background thread — uses page_allocator.
fn fetchIpGeo(ip: ?[]const u8) ?IpGeoResult {
    const allocator = std.heap.page_allocator;

    // Build URL: ip-api.com/json or ip-api.com/json/{ip}?fields=lat,lon,city,country
    var url_buf: [128]u8 = undefined;
    const url = if (ip) |addr|
        std.fmt.bufPrint(&url_buf, "http://ip-api.com/json/{s}?fields=lat,lon,city,country", .{addr}) catch return null
    else
        std.fmt.bufPrint(&url_buf, "http://ip-api.com/json/?fields=lat,lon,city,country", .{}) catch return null;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-s", "-m", "3", url },
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) return null;

    // Parse JSON: {"lat":7.8804,"lon":98.3923,"city":"Phuket","country":"Thailand"}
    return parseIpApiJson(result.stdout);
}

/// Simple JSON field extractor — avoids needing full JSON parser.
/// Extracts "lat", "lon", "city", "country" from ip-api.com response.
fn parseIpApiJson(json: []const u8) ?IpGeoResult {
    const lat = parseJsonFloat(json, "\"lat\":") orelse return null;
    const lon = parseJsonFloat(json, "\"lon\":") orelse return null;

    var res = IpGeoResult{ .lat = lat, .lon = lon, .city = [_]u8{0} ** 48, .city_len = 0 };

    // Extract city
    if (extractJsonString(json, "\"city\":\"")) |city| {
        // Extract country
        if (extractJsonString(json, "\"country\":\"")) |country| {
            const cl = @min(city.len, 40);
            @memcpy(res.city[0..cl], city[0..cl]);
            res.city_len = cl;
            // Append ", XX"
            if (cl + 2 + country.len <= 48) {
                res.city[cl] = ',';
                res.city[cl + 1] = ' ';
                const co = @min(country.len, 48 - cl - 2);
                @memcpy(res.city[cl + 2 .. cl + 2 + co], country[0..co]);
                res.city_len = cl + 2 + co;
            }
        } else {
            const cl = @min(city.len, 48);
            @memcpy(res.city[0..cl], city[0..cl]);
            res.city_len = cl;
        }
    }

    return res;
}

fn parseJsonFloat(json: []const u8, key: []const u8) ?f32 {
    const idx = std.mem.indexOf(u8, json, key) orelse return null;
    const start = idx + key.len;
    // Find end: comma, }, or whitespace
    var end = start;
    while (end < json.len) : (end += 1) {
        const c = json[end];
        if (c == ',' or c == '}' or c == ' ' or c == '\n') break;
    }
    if (end == start) return null;
    return std.fmt.parseFloat(f32, json[start..end]) catch return null;
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    const idx = std.mem.indexOf(u8, json, key) orelse return null;
    const start = idx + key.len;
    // Find closing quote
    const end_off = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end_off];
}

/// Known worker endpoints to probe via TCP
const ProbeTarget = struct {
    host: []const u8,
    port: u16,
    name: []const u8,
    role: []const u8,
    location: []const u8,
    geo_lat: f32,
    geo_lon: f32,
    is_local: bool,
};
const PROBE_TARGETS = [_]ProbeTarget{
    .{ .host = "199.68.196.38", .port = 9335, .name = "VPS Worker", .role = "worker", .location = "Buffalo, US", .geo_lat = 42.89, .geo_lon = -78.88, .is_local = false },
    .{ .host = "127.0.0.1", .port = 9337, .name = "Local Relay", .role = "relay", .location = "local", .geo_lat = 0, .geo_lon = 0, .is_local = true },
    .{ .host = "127.0.0.1", .port = 9335, .name = "Local Worker", .role = "worker", .location = "local", .geo_lat = 0, .geo_lon = 0, .is_local = true },
};

/// Background TCP probe: try connecting to known endpoints + IP geo refinement
fn probeNetworkNodes() void {
    // Step 2: Refine local node (index 0) via IP API (city-level accuracy)
    if (fetchIpGeo(null)) |geo| {
        g_network_nodes[0].geo_lat = geo.lat;
        g_network_nodes[0].geo_lon = geo.lon;
        if (geo.city_len > 0) {
            const cl = @min(geo.city_len, 31);
            @memcpy(g_network_nodes[0].location[0..cl], geo.city[0..cl]);
            g_network_nodes[0].location_len = @intCast(cl);
        }
    }

    // Step 3: Probe remote/local endpoints via TCP
    for (PROBE_TARGETS) |target| {
        // Try TCP connect with short timeout
        const addr = std.net.Address.parseIp4(target.host, target.port) catch continue;
        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0) catch continue;
        defer std.posix.close(sock);

        // Set send timeout to 2 seconds as connect timeout proxy
        const timeout = std.posix.timeval{ .sec = 2, .usec = 0 };
        std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout)) catch {};
        std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout)) catch {};

        // Attempt connect
        std.posix.connect(sock, &addr.any, addr.getOsSockLen()) catch continue;

        // Connection succeeded — node is alive
        if (g_network_node_count >= MAX_NETWORK_NODES) break;
        var node = NetworkNode.init();
        const nl2 = @min(target.name.len, 31);
        @memcpy(node.name[0..nl2], target.name[0..nl2]);
        node.name_len = @intCast(nl2);

        var addr_str: [48]u8 = [_]u8{0} ** 48;
        const al2 = std.fmt.bufPrint(&addr_str, "{s}:{d}", .{ target.host, target.port }) catch continue;
        @memcpy(node.address[0..al2.len], al2);
        node.address_len = @intCast(al2.len);

        const rl3 = @min(target.role.len, 15);
        @memcpy(node.role[0..rl3], target.role[0..rl3]);
        node.role_len = @intCast(rl3);

        // For remote nodes: use IP API for accurate geo; for local: copy from local node
        if (!target.is_local) {
            if (fetchIpGeo(target.host)) |geo| {
                node.geo_lat = geo.lat;
                node.geo_lon = geo.lon;
                if (geo.city_len > 0) {
                    const cl = @min(geo.city_len, 31);
                    @memcpy(node.location[0..cl], geo.city[0..cl]);
                    node.location_len = @intCast(cl);
                } else {
                    const ll2 = @min(target.location.len, 31);
                    @memcpy(node.location[0..ll2], target.location[0..ll2]);
                    node.location_len = @intCast(ll2);
                }
            } else {
                // Fallback to static coords from probe target
                node.geo_lat = target.geo_lat;
                node.geo_lon = target.geo_lon;
                const ll2 = @min(target.location.len, 31);
                @memcpy(node.location[0..ll2], target.location[0..ll2]);
                node.location_len = @intCast(ll2);
            }
        } else {
            // Local node: copy geo from local coordinator (already refined)
            node.geo_lat = g_network_nodes[0].geo_lat;
            node.geo_lon = g_network_nodes[0].geo_lon;
            const ll3 = g_network_nodes[0].location_len;
            @memcpy(node.location[0..ll3], g_network_nodes[0].location[0..ll3]);
            node.location_len = ll3;
        }

        node.status = .online;
        node.is_local = target.is_local;
        node.latency_ms = if (target.is_local) 1 else 95;

        g_network_nodes[g_network_node_count] = node;
        g_network_node_count += 1;
    }
    g_network_probe_done = true;
}

/// Detect local machine and spawn background probe for remote nodes.
/// Called once when the Network panel is first opened.
fn initNetworkState() void {
    if (g_network_initialized) return;
    g_network_initialized = true;

    // Query real system RAM via auto_shard (sysctl on macOS, /proc/meminfo on Linux)
    const sys_mem = auto_shard.getSystemMemory() catch auto_shard.SystemMemory{
        .total_bytes = 0,
        .available_bytes = 0,
    };
    const ram_mb: u16 = @intCast(@min(sys_mem.total_bytes / (1024 * 1024), 65535));

    // Get hostname via POSIX
    var hostname_buf: [64]u8 = [_]u8{0} ** 64;
    var hostname_len: usize = 0;
    if (std.c.gethostname(&hostname_buf, hostname_buf.len) == 0) {
        for (hostname_buf, 0..) |c, i| {
            if (c == 0) {
                hostname_len = i;
                break;
            }
        }
        if (hostname_len == 0) hostname_len = hostname_buf.len;
    } else {
        const fallback = "localhost";
        @memcpy(hostname_buf[0..fallback.len], fallback);
        hostname_len = fallback.len;
    }

    // Create local node entry with real detected values
    var local_node = NetworkNode.init();
    const nl = @min(hostname_len, 31);
    @memcpy(local_node.name[0..nl], hostname_buf[0..nl]);
    local_node.name_len = @intCast(nl);
    const addr = "127.0.0.1:9336";
    @memcpy(local_node.address[0..addr.len], addr);
    local_node.address_len = @intCast(addr.len);
    const role = "coordinator";
    @memcpy(local_node.role[0..role.len], role);
    local_node.role_len = @intCast(role.len);

    // Step 1: Detect geo from timezone (instant, offline, ~country-level)
    if (detectTimezoneGeo()) |tz_geo| {
        local_node.geo_lat = tz_geo.lat;
        local_node.geo_lon = tz_geo.lon;
        const cl = @min(tz_geo.city.len, 31);
        @memcpy(local_node.location[0..cl], tz_geo.city[0..cl]);
        local_node.location_len = @intCast(cl);
    } else {
        const loc = "Unknown";
        @memcpy(local_node.location[0..loc.len], loc);
        local_node.location_len = @intCast(loc.len);
    }

    local_node.status = .online;
    local_node.ram_mb = ram_mb;
    local_node.latency_ms = 0;
    local_node.is_local = true;
    local_node.layers_start = 0;
    local_node.layers_end = 0;

    g_network_nodes[0] = local_node;
    g_network_node_count = 1;

    const no_model = "Scanning network...";
    @memcpy(g_network_model_name[0..no_model.len], no_model);
    g_network_model_name_len = no_model.len;

    // Spawn background thread to probe known endpoints + refine geo via IP API
    g_network_probe_thread = std.Thread.spawn(.{}, probeNetworkNodes, .{}) catch null;
}

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
    scroll_target: f32, // Smooth scroll target (lerp toward this)

    // For tools panel
    tool_selected: usize,

    // For voice panel
    voice_amplitude: f32,
    voice_recording: bool,
    voice_wave_phase: f32,

    // For chat panel - multi-modal content
    chat_messages: [32][256]u8,
    chat_msg_lens: [32]usize,
    chat_msg_is_user: [32]bool,
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

    // For sacred world panel (27 worlds of 999 kingdom)
    world_id: u8, // Block index 0-26
    world_anim_phase: f32, // phi-spiral animation

    // Emergent Wave ScrollView v1.0
    // When enabled, replaces legacy lerp scroll with phi-damped wave physics
    wave_scroll_enabled: bool,
    wave_sv: wave_scroll.WaveScrollView,

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
            .scroll_target = 0,
            .tool_selected = 0,
            .voice_amplitude = 0,
            .voice_recording = false,
            .voice_wave_phase = 0,
            .chat_messages = undefined,
            .chat_msg_lens = .{0} ** 32,
            .chat_msg_is_user = .{false} ** 32,
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
            .world_id = 0,
            .world_anim_phase = 0,
            .wave_scroll_enabled = false,
            .wave_sv = wave_scroll.WaveScrollView.init(px, py + 32.0, pw, ph - 32.0),
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
            .sacred_world => "Sacred Mathematics",
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
        if (self.chat_msg_count >= 32) {
            // Shift messages up (drop oldest)
            for (0..31) |i| {
                @memcpy(&self.chat_messages[i], &self.chat_messages[i + 1]);
                self.chat_msg_lens[i] = self.chat_msg_lens[i + 1];
                self.chat_msg_is_user[i] = self.chat_msg_is_user[i + 1];
            }
            self.chat_msg_count = 31;
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

        // Shadow (soft, offset down-right — darker on light theme for visibility)
        const shadow_offset: f32 = 4.0;
        const shadow_strength: f32 = if (theme.isDark()) 40 else 80;
        const shadow_alpha: u8 = @intFromFloat(self.opacity * shadow_strength);
        const shadow_color = rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = shadow_alpha };
        rl.DrawRectangleRounded(
            .{ .x = sx + shadow_offset, .y = sy + shadow_offset, .width = sw, .height = sh },
            roundness, 32, // More segments for smoother corners
            shadow_color,
        );

        // Main glass background (Hyper style)
        // Dark theme: semi-transparent glass effect (230 alpha)
        // Light theme: fully opaque (255 alpha) — no dark bleed-through
        const bg_base_alpha: f32 = if (self.panel_type == .sacred_world) 255 else if (theme.isDark()) 230 else 255;
        const bg_alpha: u8 = @intFromFloat(self.opacity * bg_base_alpha);
        const bg_color = if (self.panel_type == .sacred_world) @as(rl.Color, @bitCast(theme.sacred_world_bg)) else BG_SURFACE;
        rl.DrawRectangleRounded(
            .{ .x = sx, .y = sy, .width = sw, .height = sh },
            roundness, 32,
            withAlpha(bg_color, bg_alpha),
        );

        // Gradient overlay REMOVED (clean Hyper style - no gradient)
        // const grad_alpha: u8 = @intFromFloat(self.opacity * 15);
        // rl.DrawRectangleRounded(
        //     .{ .x = sx, .y = sy, .width = sw, .height = sh / 3 },
        //     roundness, 32,
        //     withAlpha(TEXT_WHITE, grad_alpha),
        // );

        // Border — visible on both themes (stronger on light)
        const border_strength: f32 = if (theme.isDark()) 40 else 180;
        const border_alpha: u8 = @intFromFloat(self.opacity * border_strength);
        rl.DrawRectangleRoundedLinesEx(
            .{ .x = sx, .y = sy, .width = sw, .height = sh },
            roundness, 32, 1.0,
            withAlpha(@as(rl.Color, @bitCast(theme.border)), border_alpha),
        );

        // Wave scroll: animated cyan border pulse (Emergent Wave ScrollView v1.0)
        if (self.wave_scroll_enabled) {
            const wave_border_pulse = @sin(self.wave_sv.wave_time * 2.0) * 0.3 + 0.4;
            const wb_alpha: u8 = @intFromFloat(@max(0, @min(255.0, wave_border_pulse * 50.0 * self.opacity)));
            rl.DrawRectangleRoundedLinesEx(
                .{ .x = sx - 1, .y = sy - 1, .width = sw + 2, .height = sh + 2 },
                roundness, 32, 1.0,
                rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = wb_alpha },
            );
        }

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
        rl.DrawTextEx(font, &self.title, .{ .x = title_x, .y = sy + 6 }, 16, 0.5, withAlpha(@as(rl.Color, @bitCast(theme.panel_title)), title_alpha));

        // Title bar separator
        const sep_alpha: u8 = @intFromFloat(self.opacity * 30);
        rl.DrawLine(@intFromFloat(sx), @intFromFloat(sy + 32), @intFromFloat(sx + sw), @intFromFloat(sy + 32), withAlpha(@as(rl.Color, @bitCast(theme.panel_title_sep)), sep_alpha));

        // === CONTENT AREA (Multi-Modal) ===
        const content_y = sy + 40;
        const content_h = sh - 50;
        const content_alpha: u8 = @intFromFloat(self.opacity * theme.panel_content_alpha);
        const text_color = withAlpha(CONTENT_TEXT, content_alpha);

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
                    rl.DrawTextEx(font, &ln_buf, .{ .x = sx + 8, .y = line_y }, 10, 0.5, withAlpha(@as(rl.Color, @bitCast(theme.line_number)), ln_alpha + content_alpha / 2));

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
                        rl.DrawRectangle(@intFromFloat(sx + 8), @intFromFloat(tool_y - 2), @intFromFloat(sw - 16), 24, withAlpha(@as(rl.Color, @bitCast(theme.tool_selected_bg)), content_alpha));
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
                    const toggle_color = if (setting.on) withAlpha(@as(rl.Color, @bitCast(theme.settings_toggle_on)), content_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.settings_toggle_off)), content_alpha);
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

            .sacred_world => {
                // === SACRED WORLD PANEL — Route by world_id ===
                const world = sacred_worlds.getWorldByBlock(self.world_id);
                const realm = sacred_worlds.blockToRealm(self.world_id);
                const realm_r = sacred_worlds.realmColorR(realm);
                const realm_g = sacred_worlds.realmColorG(realm);
                const realm_b = sacred_worlds.realmColorB(realm);
                const rc = rl.Color{ .r = realm_r, .g = realm_g, .b = realm_b, .a = content_alpha };
                const margin: f32 = 20 * g_font_scale;
                const fs = g_font_scale;

                // ── Common header for all sacred_world panels ──
                const header_h: f32 = 36 * fs;
                // Header: fully opaque (never transparent)
                rl.DrawRectangle(@intFromFloat(sx), @intFromFloat(content_y), @intFromFloat(sw), @intFromFloat(header_h), SACRED_HEADER_BG);
                rl.DrawCircle(@intFromFloat(sx + 12 * fs), @intFromFloat(content_y + header_h / 2), 4 * fs, rc);
                rl.DrawLine(@intFromFloat(sx), @intFromFloat(content_y + header_h), @intFromFloat(sx + sw), @intFromFloat(content_y + header_h), rc);

                const ri = @intFromEnum(realm);
                const rn_len = sacred_worlds.REALM_NAME_LENS[ri];
                var realm_buf: [16:0]u8 = undefined;
                @memcpy(realm_buf[0..rn_len], sacred_worlds.REALM_NAMES[ri][0..rn_len]);
                realm_buf[rn_len] = 0;
                rl.DrawTextEx(font, &realm_buf, .{ .x = sx + margin + 4, .y = content_y + 10 * fs }, 14 * fs, 0.5, SACRED_HEADER_TEXT);

                const rs_len = sacred_worlds.REALM_SYMBOL_LENS[ri];
                var sym_buf: [8:0]u8 = undefined;
                @memcpy(sym_buf[0..rs_len], sacred_worlds.REALM_SYMBOLS[ri][0..rs_len]);
                sym_buf[rs_len] = 0;
                rl.DrawTextEx(font, &sym_buf, .{ .x = sx + sw - margin - 30 * fs, .y = content_y + 10 * fs }, 14 * fs, 0.5, SACRED_HEADER_TEXT);

                // Content area below header
                const body_y = content_y + header_h + 4 * fs;
                const body_h = content_h - header_h - 4 * fs;

                // ── ROUTE BY WORLD_ID ──
                if (self.world_id == 0) {
                    // ════════════════════════════════════════════
                    // CHAT PANEL (world_id 0) — Trinity Chat
                    // Uses GLOBAL chat state (persistent across panel reopen)
                    // ════════════════════════════════════════════

                    // Smooth scroll (global)
                    const chat_dt = rl.GetFrameTime();
                    g_chat_scroll_y += (g_chat_scroll_target - g_chat_scroll_y) * @min(1.0, 8.0 * chat_dt);

                    const chat_top = body_y + 8 * fs;
                    const input_h: f32 = 48 * fs;
                    const chat_bottom = content_y + content_h - input_h - 8 * fs;
                    const msg_area_h = chat_bottom - chat_top;
                    const line_h: f32 = 22 * fs;
                    const chat_font = g_font_chat;
                    const msg_font_size: f32 = 17 * fs;
                    const bubble_pad: f32 = 14 * fs;
                    const chat_margin: f32 = 70 * fs; // Extra padding for chat messages and input
                    const max_text_w = sw - chat_margin * 2 - bubble_pad * 2;
                    // Chat colors: from theme (dark=white-on-dark, light=dark-on-light)
                    const chat_text_color = withAlpha(CHAT_TEXT, content_alpha);
                    _ = CHAT_BUBBLE_USER; // reserved for future use

                    // Scissor clip for messages
                    rl.BeginScissorMode(@intFromFloat(sx), @intFromFloat(chat_top), @intFromFloat(sw), @intFromFloat(@max(1, msg_area_h)));

                    // Clamp scroll before rendering
                    g_chat_scroll_target = @max(0, g_chat_scroll_target);

                    if (g_chat_msg_count == 0) {
                        // Welcome message
                        const welcome_y = chat_top + msg_area_h * 0.3;
                        rl.DrawTextEx(chat_font, "Trinity AI", .{ .x = sx + chat_margin, .y = welcome_y }, 18 * fs, 0.5, withAlpha(HYPER_GREEN, content_alpha));
                        rl.DrawTextEx(chat_font, "Type a message below to start chatting.", .{ .x = sx + chat_margin, .y = welcome_y + 24 * fs }, 14 * fs, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                        g_chat_scroll_target = 0;
                        g_chat_scroll_y = 0;
                    } else {
                        // Render messages with simple line-based rendering (no word-wrap byte corruption)
                        var render_y: f32 = chat_top + 6 * fs - g_chat_scroll_y;
                        var mi: usize = 0;
                        while (mi < g_chat_msg_count) : (mi += 1) {
                            const msg_type = g_chat_msg_types[mi];
                            const msg_len = g_chat_msg_lens[mi];
                            const msg_data = g_chat_messages[mi][0..msg_len];

                            // Log messages: small dimmed text, no label
                            if (msg_type == .log) {
                                if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                    var log_z: [256:0]u8 = undefined;
                                    @memcpy(log_z[0..msg_len], msg_data);
                                    log_z[msg_len] = 0;
                                    const log_font_size: f32 = 13 * fs;
                                    const log_color = rl.Color{ .r = 120, .g = 120, .b = 140, .a = 180 };
                                    rl.DrawTextEx(chat_font, &log_z, .{ .x = sx + chat_margin, .y = render_y }, log_font_size, 0.3, log_color);
                                }
                                render_y += 18 * fs;
                                continue;
                            }

                            const is_user = msg_type == .user;

                            // Label — user on right, Trinity on left
                            if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                const label_color = if (is_user) withAlpha(CHAT_LABEL_USER, content_alpha) else withAlpha(CHAT_LABEL_AI, content_alpha);
                                if (is_user) {
                                    const you_w = rl.MeasureTextEx(chat_font, "You", 16 * fs, 0.5).x;
                                    rl.DrawTextEx(chat_font, "You", .{ .x = sx + sw - chat_margin - you_w, .y = render_y }, 16 * fs, 0.5, label_color);
                                } else {
                                    rl.DrawTextEx(chat_font, "Trinity", .{ .x = sx + chat_margin, .y = render_y }, 16 * fs, 0.5, label_color);
                                }
                            }
                            render_y += 18 * fs;

                            // Measure actual text width for bubble sizing
                            var full_z: [256:0]u8 = undefined;
                            @memcpy(full_z[0..msg_len], msg_data);
                            full_z[msg_len] = 0;
                            const text_size = rl.MeasureTextEx(chat_font, &full_z, msg_font_size, 0.5);

                            // Bubble alignment: user=right, Trinity=left
                            const needs_wrap = text_size.x > max_text_w;

                            if (!needs_wrap) {
                                if (is_user) {
                                    // User: plain text, right-aligned (no bubble)
                                    const text_x = sx + sw - chat_margin - text_size.x;
                                    if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                        // Fake bold
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = text_x, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = text_x + 0.6, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                    }
                                    render_y += line_h + 8 * fs;
                                } else {
                                    // Trinity: clean text, no bubble, left-aligned
                                    if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = sx + chat_margin, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = sx + chat_margin + 0.6, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                    }
                                    render_y += line_h + 8 * fs;
                                }
                            } else {
                                // Multi-line: UTF-8-safe word wrap
                                // First pass: count lines
                                var n_lines: f32 = 0;
                                {
                                    var pos: usize = 0;
                                    while (pos < msg_data.len) {
                                        // Find how many bytes fit in max_text_w
                                        var end = pos;
                                        var last_space: usize = pos;
                                        while (end < msg_data.len) {
                                            // Advance one UTF-8 char
                                            var next = end + 1;
                                            while (next < msg_data.len and (msg_data[next] & 0xC0) == 0x80) next += 1;
                                            // Measure width up to 'next'
                                            var tmp: [256:0]u8 = undefined;
                                            const seg_len = @min(next - pos, 255);
                                            @memcpy(tmp[0..seg_len], msg_data[pos..pos + seg_len]);
                                            tmp[seg_len] = 0;
                                            const w = rl.MeasureTextEx(chat_font, &tmp, msg_font_size, 0.5).x;
                                            if (w > max_text_w and end > pos) break;
                                            if (msg_data[end] == ' ') last_space = end;
                                            end = next;
                                        }
                                        // Wrap at last space if possible
                                        if (end < msg_data.len and last_space > pos) end = last_space + 1 else if (end == pos) end = pos + 1;
                                        n_lines += 1;
                                        pos = end;
                                        // Skip leading space on next line
                                        while (pos < msg_data.len and msg_data[pos] == ' ') pos += 1;
                                    }
                                    if (n_lines == 0) n_lines = 1;
                                }

                                const bubble_h = n_lines * line_h;
                                const bubble_x = sx + chat_margin;

                                // Second pass: render lines (no bubble for either side)
                                var text_y = render_y;
                                var pos2: usize = 0;
                                var line_buf_chat: [256:0]u8 = undefined;
                                while (pos2 < msg_data.len) {
                                    var end2 = pos2;
                                    var last_sp2: usize = pos2;
                                    while (end2 < msg_data.len) {
                                        var next2 = end2 + 1;
                                        while (next2 < msg_data.len and (msg_data[next2] & 0xC0) == 0x80) next2 += 1;
                                        var tmp2: [256:0]u8 = undefined;
                                        const seg_len2 = @min(next2 - pos2, 255);
                                        @memcpy(tmp2[0..seg_len2], msg_data[pos2..pos2 + seg_len2]);
                                        tmp2[seg_len2] = 0;
                                        const w2 = rl.MeasureTextEx(chat_font, &tmp2, msg_font_size, 0.5).x;
                                        if (w2 > max_text_w and end2 > pos2) break;
                                        if (msg_data[end2] == ' ') last_sp2 = end2;
                                        end2 = next2;
                                    }
                                    if (end2 < msg_data.len and last_sp2 > pos2) end2 = last_sp2 + 1 else if (end2 == pos2) end2 = pos2 + 1;

                                    if (text_y >= chat_top - line_h and text_y <= chat_bottom + line_h) {
                                        const ln_len = @min(end2 - pos2, 255);
                                        @memcpy(line_buf_chat[0..ln_len], msg_data[pos2..pos2 + ln_len]);
                                        // Trim trailing space
                                        var tlen = ln_len;
                                        while (tlen > 0 and line_buf_chat[tlen - 1] == ' ') tlen -= 1;
                                        line_buf_chat[tlen] = 0;
                                        // Fake bold: double draw
                                        rl.DrawTextEx(chat_font, &line_buf_chat, .{ .x = bubble_x + bubble_pad, .y = text_y }, msg_font_size, 0.5, chat_text_color);
                                        rl.DrawTextEx(chat_font, &line_buf_chat, .{ .x = bubble_x + bubble_pad + 0.6, .y = text_y }, msg_font_size, 0.5, chat_text_color);
                                    }

                                    text_y += line_h;
                                    pos2 = end2;
                                    while (pos2 < msg_data.len and msg_data[pos2] == ' ') pos2 += 1;
                                }

                                render_y += bubble_h + 8 * fs;
                            }
                        }

                        // Calculate total content height for scroll clamping
                        const total_content_h = render_y + g_chat_scroll_y - (chat_top + 6 * fs);
                        const max_scroll = @max(0, total_content_h - msg_area_h + 20 * fs);
                        g_chat_scroll_target = @min(g_chat_scroll_target, max_scroll);
                        g_chat_scroll_y = @min(g_chat_scroll_y, max_scroll + 10 * fs);
                    }

                    rl.EndScissorMode();

                    // Mouse wheel scroll in chat
                    {
                        const cmx = @as(f32, @floatFromInt(rl.GetMouseX()));
                        const cmy = @as(f32, @floatFromInt(rl.GetMouseY()));
                        if (cmx >= sx and cmx <= sx + sw and cmy >= chat_top and cmy <= chat_bottom) {
                            g_chat_scroll_target -= rl.GetMouseWheelMove() * 40.0 * fs;
                            g_chat_scroll_target = @max(0, g_chat_scroll_target);
                        }
                    }

                    // Input area (bottom) — terminal style with separator lines
                    const input_y = chat_bottom + 4 * fs;
                    const sep_color = rl.Color{ .r = 100, .g = 100, .b = 110, .a = 120 };

                    // Background fill
                    rl.DrawRectangle(
                        @intFromFloat(sx + chat_margin),
                        @intFromFloat(input_y),
                        @intFromFloat(sw - chat_margin * 2),
                        @intFromFloat(input_h),
                        CHAT_INPUT_BG,
                    );
                    // Top separator line
                    rl.DrawLineEx(
                        .{ .x = sx + chat_margin, .y = input_y },
                        .{ .x = sx + sw - chat_margin, .y = input_y },
                        1.0, sep_color,
                    );
                    // Bottom separator line
                    rl.DrawLineEx(
                        .{ .x = sx + chat_margin, .y = input_y + input_h },
                        .{ .x = sx + sw - chat_margin, .y = input_y + input_h },
                        1.0, sep_color,
                    );

                    // ">" prompt
                    const prompt_color = rl.Color{ .r = 150, .g = 150, .b = 160, .a = 220 };
                    const prompt_y = input_y + 14 * fs;
                    const prompt_sz: f32 = 17 * fs;
                    rl.DrawTextEx(chat_font, ">", .{ .x = sx + chat_margin + 6 * fs, .y = prompt_y }, prompt_sz, 0.5, prompt_color);

                    // "↵ send" hint (right side)
                    const send_sz: f32 = 13 * fs;
                    const send_color = rl.Color{ .r = 140, .g = 140, .b = 150, .a = 180 };
                    const send_w = rl.MeasureTextEx(chat_font, "enter to send", send_sz, 0.5).x;
                    rl.DrawTextEx(chat_font, "enter to send", .{ .x = sx + sw - chat_margin - send_w - 10 * fs, .y = input_y + 16 * fs }, send_sz, 0.5, send_color);

                    if (g_chat_input_len > 0) {
                        var input_disp: [260:0]u8 = undefined;
                        const show_input = @min(g_chat_input_len, 255);
                        @memcpy(input_disp[0..show_input], g_chat_input[0..show_input]);
                        input_disp[show_input] = 0;
                        const ix = sx + chat_margin + 22 * fs;
                        const iy = input_y + 14 * fs;
                        const isz: f32 = 17 * fs;
                        rl.DrawTextEx(chat_font, &input_disp, .{ .x = ix, .y = iy }, isz, 0.5, CHAT_INPUT_TEXT);
                        rl.DrawTextEx(chat_font, &input_disp, .{ .x = ix + 0.5, .y = iy }, isz, 0.5, CHAT_INPUT_TEXT);
                        // Blinking rectangle cursor after text
                        if (@mod(@as(u32, @intFromFloat(time * 3)), 2) == 0) {
                            const text_w = rl.MeasureTextEx(chat_font, &input_disp, isz, 0.5).x;
                            const cur_x: i32 = @intFromFloat(ix + text_w + 2 * fs);
                            const cur_y: i32 = @intFromFloat(iy);
                            const cur_w: i32 = @intFromFloat(2 * fs);
                            const cur_h: i32 = @intFromFloat(isz);
                            rl.DrawRectangle(cur_x, cur_y, cur_w, cur_h, CHAT_INPUT_TEXT);
                        }
                    } else {
                        // Empty input: blinking rect cursor after ">"
                        const ph_x = sx + chat_margin + 22 * fs;
                        const ph_y = input_y + 14 * fs;
                        const ph_sz: f32 = 17 * fs;
                        if (@mod(@as(u32, @intFromFloat(time * 2)), 2) == 0) {
                            rl.DrawRectangle(@intFromFloat(ph_x), @intFromFloat(ph_y), @intFromFloat(2 * fs), @intFromFloat(ph_sz), CHAT_INPUT_TEXT);
                        }
                    }

                    // Status bar below input — real system info
                    {
                        const status_y = input_y + input_h + 3 * fs;
                        const status_sz: f32 = 11 * fs;
                        const status_color = rl.Color{ .r = 100, .g = 100, .b = 115, .a = 160 };
                        const fps_val = rl.GetFPS();

                        // Left: FPS + engine stats
                        var status_buf: [256:0]u8 = undefined;
                        if (g_fluent_engine_inited) {
                            const st = g_fluent_engine.getStats();
                            const sl = std.fmt.bufPrint(status_buf[0..255], "{d}fps | fluent {d:.0}% | {s} | {s} | s:{d:.1}", .{
                                fps_val,
                                st.fluent_rate * 100,
                                st.current_language.getName(),
                                st.current_topic.getName(),
                                st.sentiment,
                            }) catch "...";
                            status_buf[sl.len] = 0;
                        } else {
                            const sl = std.fmt.bufPrint(status_buf[0..255], "{d}fps | trinity v2.0 | ready", .{fps_val}) catch "...";
                            status_buf[sl.len] = 0;
                        }
                        rl.DrawTextEx(chat_font, &status_buf, .{ .x = sx + chat_margin + 4 * fs, .y = status_y }, status_sz, 0.3, status_color);

                        // Right: message count
                        var count_buf: [64:0]u8 = undefined;
                        const ct = std.fmt.bufPrint(count_buf[0..63], "{d} msgs", .{g_chat_msg_count}) catch "0";
                        count_buf[ct.len] = 0;
                        const count_w = rl.MeasureTextEx(chat_font, &count_buf, status_sz, 0.3).x;
                        rl.DrawTextEx(chat_font, &count_buf, .{ .x = sx + sw - chat_margin - count_w - 4 * fs, .y = status_y }, status_sz, 0.3, status_color);
                    }
                } else if (self.world_id == 18) {
                    // ════════════════════════════════════════════
                    // DOCS PANEL (world_id 18) — All 27 docs consolidated
                    // ════════════════════════════════════════════

                    rl.DrawTextEx(font, "ALL DOCUMENTATION", .{ .x = sx + margin, .y = body_y + 4 * fs }, 18 * fs, 0.5, accentText(rc, content_alpha));

                    const doc_top = body_y + 30 * fs;
                    const doc_h = body_h - 34 * fs;
                    const doc_x = sx + margin;
                    const doc_w = sw - margin * 2;
                    const line_h: f32 = 18 * fs;
                    const font_size_doc: f32 = 13 * fs;
                    const char_w: f32 = 7.0 * fs;
                    const chars_per_line: usize = @max(20, @as(usize, @intFromFloat(doc_w / char_w)));

                    rl.BeginScissorMode(@intFromFloat(sx), @intFromFloat(doc_top), @intFromFloat(sw), @intFromFloat(@max(1, doc_h)));

                    var render_y: f32 = doc_top - self.scroll_y;
                    var line_buf: [256:0]u8 = undefined;

                    // Render ALL 27 docs sequentially
                    var doc_idx: usize = 0;
                    while (doc_idx < 27) : (doc_idx += 1) {
                        const doc = world_docs.WORLD_DOCS[doc_idx];
                        const dworld = sacred_worlds.getWorldByBlock(doc_idx);

                        // Section header: "N. WORLD_NAME — subtitle"
                        var section_hdr: [80:0]u8 = undefined;
                        _ = std.fmt.bufPrintZ(&section_hdr, "{d}. {s}", .{ doc_idx + 1, dworld.name[0..dworld.name_len] }) catch {};

                        if (render_y >= doc_top - line_h and render_y <= doc_top + doc_h) {
                            const drealm = sacred_worlds.blockToRealm(doc_idx);
                            const sec_color = rl.Color{
                                .r = sacred_worlds.realmColorR(drealm),
                                .g = sacred_worlds.realmColorG(drealm),
                                .b = sacred_worlds.realmColorB(drealm),
                                .a = content_alpha,
                            };
                            rl.DrawTextEx(font, &section_hdr, .{ .x = doc_x, .y = render_y }, font_size_doc + 4, 0.5, accentText(sec_color, content_alpha));
                        }
                        render_y += line_h * 1.5;

                        // Subtitle
                        var sub_buf: [64:0]u8 = undefined;
                        const slen = @min(doc.subtitle.len, 63);
                        @memcpy(sub_buf[0..slen], doc.subtitle[0..slen]);
                        sub_buf[slen] = 0;
                        if (render_y >= doc_top - line_h and render_y <= doc_top + doc_h) {
                            rl.DrawTextEx(font, &sub_buf, .{ .x = doc_x, .y = render_y }, font_size_doc - 1, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                        }
                        render_y += line_h;

                        // Doc content (markdown rendered)
                        var iter = world_docs.LineIterator.init(doc.raw);
                        var in_fm = false;
                        while (iter.next()) |raw_line| {
                            const trimmed = blk: {
                                var ti: usize = 0;
                                while (ti < raw_line.len and (raw_line[ti] == ' ' or raw_line[ti] == '\t')) : (ti += 1) {}
                                break :blk raw_line[ti..];
                            };
                            if (trimmed.len >= 3 and trimmed[0] == '-' and trimmed[1] == '-' and trimmed[2] == '-') {
                                in_fm = !in_fm;
                                continue;
                            }
                            if (in_fm) continue;
                            if (world_docs.isNoiseLine(raw_line)) continue;

                            const heading_stripped = world_docs.stripHeading(raw_line);
                            const is_heading = (heading_stripped.ptr != raw_line.ptr or heading_stripped.len != raw_line.len);

                            var stripped_buf: [512]u8 = undefined;
                            const stripped_len = world_docs.stripInline(heading_stripped, &stripped_buf);
                            const display_line = stripped_buf[0..stripped_len];

                            var line_start: usize = 0;
                            while (line_start < display_line.len or line_start == 0) {
                                const remaining = if (line_start < display_line.len) display_line[line_start..] else "";
                                const chunk_len = if (remaining.len <= chars_per_line) remaining.len else blk2: {
                                    var best: usize = chars_per_line;
                                    var scan: usize = chars_per_line;
                                    while (scan > 0) {
                                        scan -= 1;
                                        if (remaining[scan] == ' ') {
                                            best = scan;
                                            break;
                                        }
                                    }
                                    break :blk2 best;
                                };

                                if (render_y >= doc_top - line_h and render_y <= doc_top + doc_h) {
                                    const copy_len = @min(chunk_len, 255);
                                    @memcpy(line_buf[0..copy_len], remaining[0..copy_len]);
                                    line_buf[copy_len] = 0;

                                    const doc_text_color = if (is_heading and line_start == 0)
                                        accentText(rc, content_alpha)
                                    else
                                        withAlpha(CONTENT_TEXT, content_alpha);
                                    const fsize: f32 = if (is_heading and line_start == 0) font_size_doc + 3 else font_size_doc;
                                    rl.DrawTextEx(font, &line_buf, .{ .x = doc_x, .y = render_y }, fsize, 0.5, doc_text_color);
                                }

                                render_y += line_h;
                                if (chunk_len == 0) break;
                                line_start += chunk_len;
                                if (line_start < display_line.len and display_line[line_start] == ' ') line_start += 1;
                                if (remaining.len <= chars_per_line) break;
                            }
                        }
                        // Gap between docs
                        render_y += line_h * 2;
                    }

                    rl.EndScissorMode();

                    // Scroll indicator
                    const total_text_h = render_y + self.scroll_y - doc_top;
                    if (total_text_h > doc_h) {
                        const scroll_track_x = sx + sw - 6;
                        const max_scroll_val = total_text_h - doc_h;
                        const scroll_pct = if (max_scroll_val > 0) self.scroll_y / max_scroll_val else 0;
                        const thumb_h = @max(20.0, doc_h * (doc_h / total_text_h));
                        const thumb_y = doc_top + scroll_pct * (doc_h - thumb_h);
                        rl.DrawRectangleRounded(
                            .{ .x = scroll_track_x, .y = thumb_y, .width = 4, .height = thumb_h },
                            1.0, 4,
                            withAlpha(rc, 60),
                        );
                    }
                } else if (self.world_id == 16) {
                    // ════════════════════════════════════════════
                    // NETWORK ADMIN PANEL (world_id 16 = monitor)
                    // Runtime-detected node data (no static/fake data)
                    // Ctrl+8 to open
                    // ════════════════════════════════════════════

                    // Initialize network state on first render (detects local machine)
                    initNetworkState();
                    // Update uptime counter
                    g_network_uptime_ms +|= @intFromFloat(rl.GetFrameTime() * 1000);

                    const pad = margin * 1.5;

                    // Update status when probe finishes
                    if (g_network_probe_done and std.mem.eql(u8, g_network_model_name[0..g_network_model_name_len], "Scanning network...")) {
                        if (g_network_node_count > 1) {
                            const done_msg = "Network detected";
                            @memcpy(g_network_model_name[0..done_msg.len], done_msg);
                            g_network_model_name_len = done_msg.len;
                        } else {
                            const done_msg = "No peers found";
                            @memcpy(g_network_model_name[0..done_msg.len], done_msg);
                            g_network_model_name_len = done_msg.len;
                        }
                    }

                    // ── Scrollable content area ──
                    const net_top = body_y + 4 * fs;
                    const net_area_h = content_h - (net_top - content_y) - 4 * fs;

                    // Smooth scroll (uses global vars, draw receives const self)
                    const net_dt = rl.GetFrameTime();
                    g_net_scroll_y += (g_net_scroll_target - g_net_scroll_y) * @min(1.0, 8.0 * net_dt);

                    // Scissor clip — all content clipped to panel body
                    rl.BeginScissorMode(@intFromFloat(sx), @intFromFloat(net_top), @intFromFloat(sw), @intFromFloat(@max(1, net_area_h)));

                    var render_y: f32 = net_top + 8 * fs - g_net_scroll_y;

                    // ── HEADER ──
                    rl.DrawTextEx(font, "NETWORK", .{ .x = sx + pad, .y = render_y }, 22 * fs, 0.5, accentText(rc, content_alpha));
                    var summary_buf: [64:0]u8 = undefined;
                    var online_count: usize = 0;
                    for (0..g_network_node_count) |ni| {
                        if (g_network_nodes[ni].status == .online) online_count += 1;
                    }
                    _ = std.fmt.bufPrintZ(&summary_buf, "{d} nodes | {d} online", .{ g_network_node_count, online_count }) catch {};
                    rl.DrawTextEx(font, &summary_buf, .{ .x = sx + sw - pad - 160 * fs, .y = render_y + 4 * fs }, 11 * fs, 0.5, withAlpha(HYPER_GREEN, content_alpha));
                    if (!g_network_probe_done) {
                        const spin_pulse: u8 = @intFromFloat(120 + @sin(time * 6) * 120);
                        rl.DrawCircle(@intFromFloat(sx + sw - pad - 170 * fs), @intFromFloat(render_y + 12 * fs), 3 * fs, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = spin_pulse });
                    } else {
                        const pulse_a: u8 = @intFromFloat(120 + @sin(time * 4) * 80);
                        rl.DrawCircle(@intFromFloat(sx + sw - pad - 170 * fs), @intFromFloat(render_y + 12 * fs), 3 * fs, rl.Color{ .r = 0x50, .g = 0xFA, .b = 0x7B, .a = pulse_a });
                    }
                    render_y += 32 * fs;

                    // ── 3D GLOBE ──
                    const globe_size = @min(sw - pad * 2, 420 * fs); // cap size for quality
                    const globe_r = globe_size / 2.0;
                    const globe_cx = sx + sw / 2.0;
                    const globe_cy = render_y + globe_r;

                    // Colors (Aceternity GitHub Globe exact palette)
                    const GLOBE_BASE = rl.Color{ .r = 0x06, .g = 0x20, .b = 0x56, .a = 0xFF };
                    const GLOBE_EMISSIVE = rl.Color{ .r = 0x08, .g = 0x28, .b = 0x68, .a = 0xFF };
                    const GLOBE_DOT_LAND = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xB3 }; // rgba(255,255,255,0.7)
                    const ATMO_WHITE = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF }; // atmosphereColor: #FFFFFF
                    const ATMO_BLUE = rl.Color{ .r = 0x38, .g = 0xBD, .b = 0xF8, .a = 0xFF }; // ambientLight: #38bdf8

                    const rot_angle = time * 0.12; // autoRotateSpeed: 0.5

                    // Outer atmosphere glow — wide soft halo (atmosphereAltitude: 0.1)
                    {
                        var ai: u32 = 0;
                        while (ai < 20) : (ai += 1) {
                            const af = @as(f32, @floatFromInt(ai));
                            const ar = globe_r + (af + 1.0) * 1.5 * fs;
                            const falloff = (1.0 - af / 20.0);
                            const aa: u8 = @intFromFloat(@max(0.0, falloff * falloff * 25.0 * @as(f32, @floatFromInt(content_alpha)) / 255.0));
                            rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, ar, withAlpha(ATMO_WHITE, aa));
                        }
                        // Inner blue tint atmosphere
                        var bi: u32 = 0;
                        while (bi < 6) : (bi += 1) {
                            const bf = @as(f32, @floatFromInt(bi));
                            const br = globe_r + (bf + 0.5) * 2.0 * fs;
                            const ba: u8 = @intFromFloat(@max(0.0, (1.0 - bf / 6.0) * 18.0 * @as(f32, @floatFromInt(content_alpha)) / 255.0));
                            rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, br, withAlpha(ATMO_BLUE, ba));
                        }
                    }

                    // Globe sphere: gradient fill (emissive: #062056 center, lighter edges)
                    rl.DrawCircle(@intFromFloat(globe_cx), @intFromFloat(globe_cy), globe_r, withAlpha(GLOBE_BASE, content_alpha));
                    // Emissive inner glow (lighter center)
                    rl.DrawCircle(@intFromFloat(globe_cx - globe_r * 0.15), @intFromFloat(globe_cy - globe_r * 0.15), globe_r * 0.6, withAlpha(GLOBE_EMISSIVE, content_alpha / 5));

                    // Latitude/longitude grid lines on sphere (shininess wireframe effect)
                    {
                        const GRID_COLOR = rl.Color{ .r = 0x20, .g = 0x50, .b = 0x80, .a = 0x18 };
                        // Latitude circles (every 30 deg)
                        var lat_i: i32 = -60;
                        while (lat_i <= 60) : (lat_i += 30) {
                            const lat_r = @as(f32, @floatFromInt(lat_i)) * math.pi / 180.0;
                            const circle_r = globe_r * @cos(lat_r);
                            const circle_y_off = globe_cy - globe_r * @sin(lat_r);
                            // Draw ellipse as line segments
                            var gi: u32 = 0;
                            while (gi < 48) : (gi += 1) {
                                const ga0 = @as(f32, @floatFromInt(gi)) / 48.0 * math.pi * 2.0 + rot_angle;
                                const ga1 = @as(f32, @floatFromInt(gi + 1)) / 48.0 * math.pi * 2.0 + rot_angle;
                                const gz0 = @sin(ga0);
                                const gz1 = @sin(ga1);
                                if (gz0 < -0.05 and gz1 < -0.05) continue;
                                const gx0 = globe_cx + @cos(ga0) * circle_r;
                                const gx1 = globe_cx + @cos(ga1) * circle_r;
                                const d0: u8 = @intFromFloat(@max(0.0, (gz0 + 0.05) / 1.05 * 0.4) * @as(f32, @floatFromInt(content_alpha)));
                                rl.DrawLineEx(.{ .x = gx0, .y = circle_y_off }, .{ .x = gx1, .y = circle_y_off }, 0.8, withAlpha(GRID_COLOR, d0));
                            }
                        }
                        // Longitude meridians (every 30 deg)
                        var lon_i: i32 = 0;
                        while (lon_i < 180) : (lon_i += 30) {
                            const lon_r = @as(f32, @floatFromInt(lon_i)) * math.pi / 180.0 + rot_angle;
                            var gi: u32 = 0;
                            while (gi < 48) : (gi += 1) {
                                const la0 = (@as(f32, @floatFromInt(gi)) / 48.0 - 0.5) * math.pi;
                                const la1 = (@as(f32, @floatFromInt(gi + 1)) / 48.0 - 0.5) * math.pi;
                                const z0 = @cos(la0) * @sin(lon_r);
                                const z1 = @cos(la1) * @sin(lon_r);
                                if (z0 < -0.05 and z1 < -0.05) continue;
                                const mx0 = globe_cx + @cos(la0) * @cos(lon_r) * globe_r;
                                const my0 = globe_cy - @sin(la0) * globe_r;
                                const mx1 = globe_cx + @cos(la1) * @cos(lon_r) * globe_r;
                                const my1 = globe_cy - @sin(la1) * globe_r;
                                const d0: u8 = @intFromFloat(@max(0.0, (z0 + 0.05) / 1.05 * 0.4) * @as(f32, @floatFromInt(content_alpha)));
                                rl.DrawLineEx(.{ .x = mx0, .y = my0 }, .{ .x = mx1, .y = my1 }, 0.8, withAlpha(GRID_COLOR, d0));
                            }
                        }
                    }

                    // Land dots on sphere (pointSize: 4, polygonColor: rgba(255,255,255,0.7))
                    const dot_base_r: f32 = @max(1.5, globe_r / 80.0);
                    {
                        var row: u32 = 0;
                        while (row < world_dots.ROWS) : (row += 2) {
                            const lat_rad = (90.0 - @as(f32, @floatFromInt(row)) * 2.0) * math.pi / 180.0;
                            const cos_lat = @cos(lat_rad);
                            const sin_lat = @sin(lat_rad);
                            var col: u32 = 0;
                            while (col < world_dots.COLS) : (col += 2) {
                                const lon_rad = (-180.0 + @as(f32, @floatFromInt(col)) * 2.0) * math.pi / 180.0 + rot_angle;
                                const gx3 = cos_lat * @cos(lon_rad);
                                const gy3 = sin_lat;
                                const gz3 = cos_lat * @sin(lon_rad);
                                if (gz3 < -0.05) continue;

                                const scr_x = globe_cx + gx3 * globe_r;
                                const scr_y = globe_cy - gy3 * globe_r;
                                const depth = @max(0.0, gz3 + 0.05) / 1.05;

                                if (world_dots.isLand(row, col)) {
                                    const da: u8 = @intFromFloat(depth * @as(f32, @floatFromInt(content_alpha)) * 0.75);
                                    const dr = dot_base_r * (0.7 + depth * 0.6);
                                    rl.DrawCircle(@intFromFloat(scr_x), @intFromFloat(scr_y), dr, withAlpha(GLOBE_DOT_LAND, da));
                                }
                            }
                        }
                    }

                    // Rim light (shininess: 0.9)
                    rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, globe_r, withAlpha(ATMO_WHITE, content_alpha / 8));
                    rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, globe_r - 0.5, withAlpha(ATMO_BLUE, content_alpha / 6));

                    // ── Arc connections (arcTime: 1000, arcLength: 0.9) ──
                    if (g_network_node_count > 1) {
                        const local_nd = g_network_nodes[0];
                        var ci: usize = 1;
                        while (ci < g_network_node_count) : (ci += 1) {
                            const remote_nd = g_network_nodes[ci];
                            if (remote_nd.is_local) continue;

                            const lat1 = local_nd.geo_lat * math.pi / 180.0;
                            const lon1 = local_nd.geo_lon * math.pi / 180.0 + rot_angle;
                            const lat2 = remote_nd.geo_lat * math.pi / 180.0;
                            const lon2 = remote_nd.geo_lon * math.pi / 180.0 + rot_angle;

                            // Arc colors cycle: #06b6d4, #3b82f6, #6366f1
                            const arc_colors = [_][3]u8{ .{ 0x06, 0xB6, 0xD4 }, .{ 0x3B, 0x82, 0xF6 }, .{ 0x63, 0x66, 0xF1 } };
                            const ac = arc_colors[ci % 3];

                            const ARC_SEGS: u32 = 32;
                            const arc_phase = @mod(time * 1.0 + @as(f32, @floatFromInt(ci)) * 1.5, 1.0); // arcTime: 1000ms
                            var seg: u32 = 0;
                            while (seg < ARC_SEGS) : (seg += 1) {
                                const t0 = @as(f32, @floatFromInt(seg)) / @as(f32, @floatFromInt(ARC_SEGS));
                                const t1 = @as(f32, @floatFromInt(seg + 1)) / @as(f32, @floatFromInt(ARC_SEGS));

                                const alt0 = 1.0 + 0.12 * @sin(t0 * math.pi);
                                const alt1 = 1.0 + 0.12 * @sin(t1 * math.pi);
                                const la0 = lat1 + (lat2 - lat1) * t0;
                                const lo0 = lon1 + (lon2 - lon1) * t0;
                                const la1_v = lat1 + (lat2 - lat1) * t1;
                                const lo1_v = lon1 + (lon2 - lon1) * t1;

                                const px0 = globe_cx + @cos(la0) * @cos(lo0) * globe_r * alt0;
                                const py0 = globe_cy - @sin(la0) * globe_r * alt0;
                                const pz0 = @cos(la0) * @sin(lo0);
                                const px1 = globe_cx + @cos(la1_v) * @cos(lo1_v) * globe_r * alt1;
                                const py1 = globe_cy - @sin(la1_v) * globe_r * alt1;
                                const pz1 = @cos(la1_v) * @sin(lo1_v);
                                if (pz0 < -0.15 and pz1 < -0.15) continue;

                                // arcLength: 0.9 — traveling bright band
                                const seg_mid = (t0 + t1) / 2.0;
                                const pulse_d = @abs(seg_mid - arc_phase);
                                const pulse_b = @max(0.0, 1.0 - pulse_d * 4.0); // wide band

                                const ca: u8 = @intFromFloat(@min(255.0, 30.0 + pulse_b * 220.0));
                                const thick = 1.5 * fs + pulse_b * 2.0 * fs;
                                rl.DrawLineEx(.{ .x = px0, .y = py0 }, .{ .x = px1, .y = py1 }, thick, rl.Color{ .r = ac[0], .g = ac[1], .b = ac[2], .a = ca });
                            }
                        }
                    }

                    // ── Node markers (rings: 1, maxRings: 3) ──
                    for (0..g_network_node_count) |ni| {
                        const node = g_network_nodes[ni];
                        const nlat = node.geo_lat * math.pi / 180.0;
                        const nlon = node.geo_lon * math.pi / 180.0 + rot_angle;
                        const nz = @cos(nlat) * @sin(nlon);
                        if (nz < -0.05) continue;
                        const nx_g = globe_cx + @cos(nlat) * @cos(nlon) * globe_r;
                        const ny_g = globe_cy - @sin(nlat) * globe_r;
                        const depth = @max(0.0, nz + 0.05) / 1.05;
                        const nc: rl.Color = switch (node.status) {
                            .online => @bitCast(theme.accents.node_online),
                            .connecting => @bitCast(theme.accents.node_connecting),
                            .degraded => @bitCast(theme.accents.node_degraded),
                            .error_state => @bitCast(theme.accents.node_error),
                            .offline => @bitCast(theme.accents.node_offline),
                        };
                        // Expanding rings
                        var ring: u32 = 0;
                        while (ring < 3) : (ring += 1) {
                            const phase = @mod(time * 1.0 + @as(f32, @floatFromInt(ring)) * 0.33 + @as(f32, @floatFromInt(ni)) * 0.7, 1.0);
                            const rr = 3.0 * fs + phase * 16.0 * fs;
                            const ra: u8 = @intFromFloat(@max(0.0, (1.0 - phase) * 50.0 * depth));
                            rl.DrawCircleLinesV(.{ .x = nx_g, .y = ny_g }, rr, withAlpha(nc, ra));
                        }
                        const dot_a: u8 = @intFromFloat(depth * @as(f32, @floatFromInt(content_alpha)));
                        rl.DrawCircle(@intFromFloat(nx_g), @intFromFloat(ny_g), 5.0 * fs, withAlpha(nc, dot_a));
                        rl.DrawCircle(@intFromFloat(nx_g), @intFromFloat(ny_g), 8.0 * fs, withAlpha(nc, dot_a / 4));
                        // Label
                        if (depth > 0.4) {
                            var loc_buf: [36:0]u8 = undefined;
                            @memcpy(loc_buf[0..node.location_len], node.location[0..node.location_len]);
                            loc_buf[node.location_len] = 0;
                            rl.DrawTextEx(font, &loc_buf, .{ .x = nx_g + 12 * fs, .y = ny_g - 6 * fs }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, dot_a));
                        }
                    }

                    render_y += globe_size + 20 * fs;

                    // ── CONNECTED NODES ──
                    rl.DrawLine(@intFromFloat(sx + pad), @intFromFloat(render_y), @intFromFloat(sx + sw - pad), @intFromFloat(render_y), withAlpha(BORDER_SUBTLE, content_alpha / 3));
                    render_y += 12 * fs;
                    rl.DrawTextEx(font, "CONNECTED NODES", .{ .x = sx + pad, .y = render_y }, 12 * fs, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                    render_y += 20 * fs;

                    for (0..g_network_node_count) |ni| {
                        const node = g_network_nodes[ni];
                        const node_color: rl.Color = switch (node.status) {
                            .online => @bitCast(theme.accents.node_online),
                            .connecting => @bitCast(theme.accents.node_connecting),
                            .degraded => @bitCast(theme.accents.node_degraded),
                            .error_state => @bitCast(theme.accents.node_error),
                            .offline => @bitCast(theme.accents.node_offline),
                        };

                        // Card background
                        rl.DrawRectangleRounded(.{ .x = sx + pad, .y = render_y, .width = sw - pad * 2, .height = 56 * fs }, 0.08, 4, withAlpha(BG_INPUT, content_alpha));
                        rl.DrawRectangleRoundedLinesEx(.{ .x = sx + pad, .y = render_y, .width = sw - pad * 2, .height = 56 * fs }, 0.08, 4, 1.0, withAlpha(node_color, content_alpha / 3));

                        // Status dot
                        rl.DrawCircle(@intFromFloat(sx + pad + 14 * fs), @intFromFloat(render_y + 16 * fs), 4 * fs, withAlpha(node_color, content_alpha));

                        // Name + role
                        var name_buf: [36:0]u8 = undefined;
                        @memcpy(name_buf[0..node.name_len], node.name[0..node.name_len]);
                        name_buf[node.name_len] = 0;
                        rl.DrawTextEx(font, &name_buf, .{ .x = sx + pad + 28 * fs, .y = render_y + 6 * fs }, 12 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));

                        var role_buf: [20:0]u8 = undefined;
                        @memcpy(role_buf[0..node.role_len], node.role[0..node.role_len]);
                        role_buf[node.role_len] = 0;
                        rl.DrawTextEx(font, &role_buf, .{ .x = sx + pad + 28 * fs, .y = render_y + 24 * fs }, 10 * fs, 0.5, withAlpha(HYPER_CYAN, content_alpha));

                        // Location
                        var loc_buf2: [36:0]u8 = undefined;
                        @memcpy(loc_buf2[0..node.location_len], node.location[0..node.location_len]);
                        loc_buf2[node.location_len] = 0;
                        rl.DrawTextEx(font, &loc_buf2, .{ .x = sx + pad + 28 * fs, .y = render_y + 40 * fs }, 9 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                        // Right side: RAM + address
                        var ram_buf: [16:0]u8 = undefined;
                        _ = std.fmt.bufPrintZ(&ram_buf, "{d}MB", .{node.ram_mb}) catch {};
                        rl.DrawTextEx(font, &ram_buf, .{ .x = sx + sw - pad - 70 * fs, .y = render_y + 6 * fs }, 11 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));

                        var addr_buf: [52:0]u8 = undefined;
                        @memcpy(addr_buf[0..node.address_len], node.address[0..node.address_len]);
                        addr_buf[node.address_len] = 0;
                        rl.DrawTextEx(font, &addr_buf, .{ .x = sx + sw - pad - 140 * fs, .y = render_y + 24 * fs }, 9 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                        const lr_text: [*:0]const u8 = if (node.is_local) "LOCAL" else "REMOTE";
                        const lr_c = if (node.is_local) withAlpha(@as(rl.Color, @bitCast(theme.accents.node_local)), content_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.accents.node_remote)), content_alpha);
                        rl.DrawTextEx(font, lr_text, .{ .x = sx + sw - pad - 50 * fs, .y = render_y + 40 * fs }, 9 * fs, 0.5, lr_c);

                        render_y += 62 * fs;
                    }

                    // ── JOIN NETWORK ──
                    render_y += 8 * fs;
                    rl.DrawLine(@intFromFloat(sx + pad), @intFromFloat(render_y), @intFromFloat(sx + sw - pad), @intFromFloat(render_y), withAlpha(BORDER_SUBTLE, content_alpha / 3));
                    render_y += 12 * fs;
                    rl.DrawTextEx(font, "JOIN NETWORK", .{ .x = sx + pad, .y = render_y }, 14 * fs, 0.5, accentText(rc, content_alpha));
                    render_y += 22 * fs;
                    rl.DrawTextEx(font, "1. zig build tri", .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));
                    render_y += 16 * fs;
                    rl.DrawTextEx(font, "2. ./zig-out/bin/tri node --worker", .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));
                    render_y += 16 * fs;
                    rl.DrawTextEx(font, "3. Auto-discover via UDP 9333", .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));
                    render_y += 24 * fs;
                    const uptime_s = g_network_uptime_ms / 1000;
                    var uptime_buf: [32:0]u8 = undefined;
                    _ = std.fmt.bufPrintZ(&uptime_buf, "uptime: {d}s", .{uptime_s}) catch {};
                    rl.DrawTextEx(font, &uptime_buf, .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));
                    render_y += 20 * fs;

                    // Scroll bounds clamping
                    const total_content_ht = render_y + g_net_scroll_y - (net_top + 8 * fs);
                    const max_scroll_net = @max(0, total_content_ht - net_area_h + 20 * fs);
                    g_net_scroll_target = @min(g_net_scroll_target, max_scroll_net);
                    g_net_scroll_target = @max(0, g_net_scroll_target);
                    g_net_scroll_y = @min(g_net_scroll_y, max_scroll_net + 10 * fs);

                    rl.EndScissorMode();

                    // Mouse wheel scroll
                    {
                        const cmx = @as(f32, @floatFromInt(rl.GetMouseX()));
                        const cmy = @as(f32, @floatFromInt(rl.GetMouseY()));
                        if (cmx >= sx and cmx <= sx + sw and cmy >= net_top and cmy <= net_top + net_area_h) {
                            g_net_scroll_target -= rl.GetMouseWheelMove() * 40.0 * fs;
                            g_net_scroll_target = @max(0, g_net_scroll_target);
                        }
                    }

                    // Scrollbar indicator
                    if (total_content_ht > net_area_h) {
                        const scroll_track_x = sx + sw - 6;
                        const scroll_pct = if (max_scroll_net > 0) g_net_scroll_y / max_scroll_net else 0;
                        const thumb_h = @max(20.0, net_area_h * (net_area_h / total_content_ht));
                        const thumb_y = net_top + scroll_pct * (net_area_h - thumb_h);
                        rl.DrawRectangleRounded(.{ .x = scroll_track_x, .y = thumb_y, .width = 4, .height = thumb_h }, 1.0, 4, withAlpha(rc, 60));
                    }
                } else {
                    // ════════════════════════════════════════════
                    // PLACEHOLDER PANEL — Coming Soon
                    // ════════════════════════════════════════════

                    const center_x = sx + sw / 2;
                    const center_y_pos = body_y + body_h * 0.35;

                    // World name (large, centered)
                    var title_buf: [28:0]u8 = undefined;
                    @memcpy(title_buf[0..world.name_len], world.name[0..world.name_len]);
                    title_buf[world.name_len] = 0;
                    const title_w = @as(f32, @floatFromInt(rl.MeasureText(&title_buf, @intFromFloat(24 * fs))));
                    rl.DrawTextEx(font, &title_buf, .{ .x = center_x - title_w / 2, .y = center_y_pos }, 24 * fs, 1, accentText(rc, content_alpha));

                    // Subtitle (description)
                    const doc = world_docs.WORLD_DOCS[self.world_id];
                    var subtitle_buf: [64:0]u8 = undefined;
                    const sub_len = @min(doc.subtitle.len, 63);
                    @memcpy(subtitle_buf[0..sub_len], doc.subtitle[0..sub_len]);
                    subtitle_buf[sub_len] = 0;
                    const sub_w = @as(f32, @floatFromInt(rl.MeasureText(&subtitle_buf, @intFromFloat(13 * fs))));
                    rl.DrawTextEx(font, &subtitle_buf, .{ .x = center_x - sub_w / 2, .y = center_y_pos + 34 * fs }, 13 * fs, 0.5, withAlpha(MUTED_GRAY, content_alpha));

                    // "Coming Soon" badge
                    const badge_y = center_y_pos + 64 * fs;
                    const badge_text = "Coming Soon";
                    const badge_w = @as(f32, @floatFromInt(rl.MeasureText(badge_text, @intFromFloat(12 * fs))));
                    rl.DrawRectangleRounded(
                        .{ .x = center_x - badge_w / 2 - 12 * fs, .y = badge_y - 4 * fs, .width = badge_w + 24 * fs, .height = 24 * fs },
                        0.5, 4,
                        withAlpha(BORDER_SUBTLE, content_alpha / 2),
                    );
                    rl.DrawTextEx(font, badge_text, .{ .x = center_x - badge_w / 2, .y = badge_y }, 12 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                    // Domain name
                    const di = @intFromEnum(world.domain);
                    const dn_len = sacred_worlds.DOMAIN_NAME_LENS[di];
                    var domain_buf: [20:0]u8 = undefined;
                    @memcpy(domain_buf[0..dn_len], sacred_worlds.DOMAIN_NAMES[di][0..dn_len]);
                    domain_buf[dn_len] = 0;
                    const dom_w = @as(f32, @floatFromInt(rl.MeasureText(&domain_buf, @intFromFloat(11 * fs))));
                    rl.DrawTextEx(font, &domain_buf, .{ .x = center_x - dom_w / 2, .y = center_y_pos + 100 * fs }, 11 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                    // Formula decoration (bottom)
                    var formula_buf: [52:0]u8 = undefined;
                    @memcpy(formula_buf[0..world.formula_len], world.formula[0..world.formula_len]);
                    formula_buf[world.formula_len] = 0;
                    const formula_w = @as(f32, @floatFromInt(rl.MeasureText(&formula_buf, @intFromFloat(11 * fs))));
                    rl.DrawTextEx(font, &formula_buf, .{ .x = center_x - formula_w / 2, .y = center_y_pos + 130 * fs }, 11 * fs, 0.5, withAlpha(TEXT_HINT, content_alpha));

                    // Block badge
                    var idx_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrintZ(&idx_buf, "Block {d}/27", .{@as(u32, self.world_id) + 1}) catch {};
                    const bidx_w = @as(f32, @floatFromInt(rl.MeasureText(&idx_buf, @intFromFloat(10 * fs))));
                    rl.DrawTextEx(font, &idx_buf, .{ .x = center_x - bidx_w / 2, .y = center_y_pos + 152 * fs }, 10 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                    // Animated realm-color spiral (decorative)
                    const spiral_cx = center_x;
                    const spiral_cy = center_y_pos - 60 * fs;
                    var sp: u32 = 0;
                    while (sp < 20) : (sp += 1) {
                        const n = @as(f32, @floatFromInt(sp));
                        const angle = n * PHI * std.math.pi + time * 0.3;
                        const radius_sp = (5.0 + n * 1.5) * fs;
                        const px = spiral_cx + @cos(angle) * radius_sp;
                        const py = spiral_cy + @sin(angle) * radius_sp;
                        const dot_alpha: u8 = @intFromFloat(@max(20, @as(f32, @floatFromInt(content_alpha)) * (1.0 - n / 20.0)));
                        rl.DrawCircle(@intFromFloat(px), @intFromFloat(py), 2.0 * fs, rl.Color{ .r = realm_r, .g = realm_g, .b = realm_b, .a = dot_alpha });
                    }
                }
            },
        }

        // ═══════════════════════════════════════════════════════════════
        // EMERGENT WAVE SCROLLVIEW v1.0 — Visual Effects on Panel Card
        // phi^2 + 1/phi^2 = 3 = TRINITY
        // ═══════════════════════════════════════════════════════════════
        if (self.wave_scroll_enabled) {
            const wsv = &self.wave_sv;
            const wave_content_y = sy + 34; // Below title bar
            const wave_content_h = sh - 44; // Content area height

            // Velocity-dependent visual intensity: idle=subtle, fast=bright
            const vel_intensity = @min(1.0, @abs(wsv.state.scroll_velocity) / 1000.0);
            const idle_base: f32 = 0.15;
            const visual_intensity = idle_base + (1.0 - idle_base) * vel_intensity;

            // 1. INTERFERENCE GLOW LINES — horizontal wave bands across panel
            if (wsv.interference_rows > 0) {
                const row_scale = wave_content_h / @as(f32, @floatFromInt(wsv.interference_rows));
                for (0..wsv.interference_rows) |row| {
                    const intensity = wsv.interference[row];
                    if (intensity > 0.03) {
                        const iy = wave_content_y + @as(f32, @floatFromInt(row)) * row_scale;
                        if (iy < sy or iy > sy + sh) continue;
                        const glow_a = @min(@as(f32, 80.0), intensity * 100.0 * visual_intensity) * self.opacity;
                        const glow_alpha: u8 = @intFromFloat(@max(0, glow_a));
                        if (glow_alpha > 2) {
                            rl.DrawLineEx(
                                .{ .x = sx + 4, .y = iy },
                                .{ .x = sx + sw - 4, .y = iy },
                                1.0,
                                rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = glow_alpha },
                            );
                        }
                    }
                }
            }

            // 2. WAVE VELOCITY INDICATOR — edge glow when scrolling fast
            const vel = @abs(wsv.state.scroll_velocity);
            if (vel > 50.0) {
                const vel_norm = @min(1.0, vel / 2000.0);
                const edge_alpha: u8 = @intFromFloat(@max(0, vel_norm * 140.0 * self.opacity));
                if (wsv.state.scroll_velocity > 0) {
                    for (0..3) |gi| {
                        const gf = @as(f32, @floatFromInt(gi));
                        const ga: u8 = edge_alpha / (@as(u8, @intCast(gi)) + 1);
                        rl.DrawLineEx(
                            .{ .x = sx + 8, .y = sy + sh - 2 - gf * 2 },
                            .{ .x = sx + sw - 8, .y = sy + sh - 2 - gf * 2 },
                            2.0,
                            rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ga },
                        );
                    }
                } else {
                    for (0..3) |gi| {
                        const gf = @as(f32, @floatFromInt(gi));
                        const ga: u8 = edge_alpha / (@as(u8, @intCast(gi)) + 1);
                        rl.DrawLineEx(
                            .{ .x = sx + 8, .y = sy + 34 + gf * 2 },
                            .{ .x = sx + sw - 8, .y = sy + 34 + gf * 2 },
                            2.0,
                            rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ga },
                        );
                    }
                }
            }

            // 3. BOUNCE GLOW — magenta flash on overscroll
            if (wsv.state.bounce_amplitude > 0.01) {
                const bounce_a: u8 = @intFromFloat(@min(255.0, wsv.state.bounce_amplitude * 400.0 * self.opacity));
                const bounce_pulse = @sin(wsv.state.bounce_phase) * 0.5 + 0.5;
                const bp_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(bounce_a)) * bounce_pulse);
                rl.DrawRectangleRoundedLinesEx(
                    .{ .x = sx + 1, .y = sy + 1, .width = sw - 2, .height = sh - 2 },
                    roundness, 32, 2.0,
                    rl.Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = bp_alpha },
                );
            }

            // 4. WAVE SCROLL POSITION INDICATOR
            const max_scroll_w = @max(1.0, wsv.state.total_content_height - wsv.state.viewport_height);
            const scroll_pct = @min(1.0, @max(0.0, wsv.state.scroll_phase / max_scroll_w));
            const indicator_h: f32 = @max(20.0, wave_content_h * (wsv.state.viewport_height / @max(1.0, wsv.state.total_content_height)));
            const indicator_y = wave_content_y + scroll_pct * (wave_content_h - indicator_h);
            const wave_pulse = @sin(wsv.wave_time * 3.0) * 0.3 + 0.7;
            const ind_alpha: u8 = @intFromFloat(@max(0, @min(255.0, wave_pulse * (40.0 + 60.0 * visual_intensity) * self.opacity)));
            rl.DrawRectangleRounded(
                .{ .x = sx + sw - 6, .y = indicator_y, .width = 3, .height = indicator_h },
                0.5, 8,
                rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ind_alpha },
            );

            // 5. EDGE FADE — gradient masking at top/bottom content edges
            const fade_bg = if (self.panel_type == .sacred_world) @as(rl.Color, @bitCast(theme.sacred_world_bg)) else BG_SURFACE;
            for (0..6) |fi| {
                const fade_f = @as(f32, @floatFromInt(6 - fi));
                const fade_a: u8 = @intFromFloat(@max(0, @min(255.0, self.opacity * fade_f * 40.0)));
                // Top edge fade
                rl.DrawLineEx(
                    .{ .x = sx + 2, .y = sy + 34 + @as(f32, @floatFromInt(fi)) },
                    .{ .x = sx + sw - 2, .y = sy + 34 + @as(f32, @floatFromInt(fi)) },
                    1.0,
                    withAlpha(fade_bg, fade_a),
                );
                // Bottom edge fade
                rl.DrawLineEx(
                    .{ .x = sx + 2, .y = sy + sh - @as(f32, @floatFromInt(fi)) },
                    .{ .x = sx + sw - 2, .y = sy + sh - @as(f32, @floatFromInt(fi)) },
                    1.0,
                    withAlpha(fade_bg, fade_a),
                );
            }
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
                    if (panel.wave_scroll_enabled) {
                        // Emergent Wave ScrollView: apply impulse (phi-damped physics)
                        panel.wave_sv.applyImpulse(-mouse_wheel);
                    } else {
                        // Legacy lerp scroll
                        panel.scroll_target -= mouse_wheel * 30.0;
                        // Dynamic max scroll for sacred_world panels
                        const max_scroll: f32 = if (panel.panel_type == .sacred_world) blk_scroll: {
                            if (panel.world_id == 0) {
                                break :blk_scroll 0.0;
                            } else if (panel.world_id == 18) {
                                var total: u32 = 0;
                                var di: usize = 0;
                                while (di < 27) : (di += 1) {
                                    total += world_docs.countVisibleLines(world_docs.WORLD_DOCS[di].raw);
                                    total += 4;
                                }
                                break :blk_scroll @as(f32, @floatFromInt(total)) * 18.0 * g_font_scale;
                            } else {
                                break :blk_scroll 0.0;
                            }
                        } else 500.0;
                        panel.scroll_target = @max(0, @min(panel.scroll_target, max_scroll));
                    }
                    break;
                }
            }
        }

        // Scroll update: wave or legacy
        for (0..self.count) |i| {
            const panel = &self.panels[i];
            if (panel.state == .open) {
                if (panel.wave_scroll_enabled) {
                    // Sync viewport bounds after panel move/resize
                    panel.wave_sv.setViewport(panel.x, panel.y + 32.0, panel.width, panel.height - 32.0);
                    // Emergent Wave ScrollView: phi-damped SIMD physics
                    panel.wave_sv.updatePhysics(dt);
                    // Dirty-flag: skip expensive SIMD when scroll is idle
                    if (panel.wave_sv.needs_eval) {
                        panel.wave_sv.updateVisibleRange();
                        panel.wave_sv.evaluatePacketsSIMD();
                        panel.wave_sv.computeInterference();
                    }
                    // Sync scroll_y for render compatibility (with rubber-band)
                    panel.scroll_y = panel.wave_sv.getScrollYWithRubber();
                } else {
                    // Legacy smooth scroll interpolation (lerp toward target)
                    const diff = panel.scroll_target - panel.scroll_y;
                    if (@abs(diff) > 0.5) {
                        panel.scroll_y += diff * @min(1.0, dt * 12.0);
                    } else {
                        panel.scroll_y = panel.scroll_target;
                    }
                }
            }
        }

        // Adaptive resize: update focused panel targets to current window size
        const cur_w = @as(f32, @floatFromInt(g_width));
        const cur_h = @as(f32, @floatFromInt(g_height));
        const card_margin: f32 = 40; // Card padding from edges
        const card_top: f32 = 50; // Top margin (space for status bar)
        const card_bottom: f32 = 50; // Bottom margin
        for (0..self.count) |i| {
            const p = &self.panels[i];
            if ((p.state == .open or p.state == .opening) and p.is_focused) {
                p.target_x = card_margin;
                p.target_y = card_top;
                p.target_w = cur_w - card_margin * 2;
                p.target_h = cur_h - card_top - card_bottom;
                // Snap sacred_world panels immediately (no animation lag on resize)
                if (p.panel_type == .sacred_world) {
                    p.x = p.target_x;
                    p.y = p.target_y;
                    p.width = p.target_w;
                    p.height = p.target_h;
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
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT | rl.FLAG_WINDOW_HIGHDPI | rl.FLAG_WINDOW_TRANSPARENT | rl.FLAG_WINDOW_MAXIMIZED);
    rl.InitWindow(1280, 800, "TRINITY v1.7 | Shift+1-7 = Panels | phi^2 + 1/phi^2 = 3");
    defer rl.CloseWindow();

    // Disable ESC auto-close — ESC hides panels, Cmd+Q quits
    rl.SetExitKey(0);

    // Set minimum window size for responsive design
    rl.SetWindowMinSize(800, 600);

    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // ── HiDPI / Retina detection ──
    // GetWindowScaleDPI returns (sx, sy) — 2.0 on Mac Retina, 1.0 on standard
    const dpi_scale_v = rl.GetWindowScaleDPI();
    g_dpi_scale = @max(dpi_scale_v.x, dpi_scale_v.y);
    if (g_dpi_scale < 1.0) g_dpi_scale = 1.0;

    // Load fonts at physical pixel size for crisp Retina text
    // Base sizes: 48pt (headings), 32pt (body) — on 2x Retina → 96pt, 64pt atlas
    const font_size_large: c_int = @intFromFloat(48.0 * g_dpi_scale);
    const font_size_small: c_int = @intFromFloat(32.0 * g_dpi_scale);

    // UI fonts: Outfit (original, Latin-only, perfect metrics)
    const font = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", font_size_large, null, 0);
    defer rl.UnloadFont(font);
    const font_small = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", font_size_small, null, 0);
    defer rl.UnloadFont(font_small);
    // Enable bilinear filtering for smooth text at all sizes
    rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_BILINEAR);
    rl.SetTextureFilter(font_small.texture, rl.TEXTURE_FILTER_BILINEAR);

    // Chat font: Montserrat (Latin + Cyrillic) at LARGE atlas size for crisp rendering
    var chat_codepoints: [95 + 256]c_int = undefined;
    for (0..95) |i| chat_codepoints[i] = @intCast(32 + i); // ASCII 32-126
    for (0..256) |i| chat_codepoints[95 + i] = @intCast(0x400 + i); // Cyrillic U+0400-U+04FF
    g_font_chat = rl.LoadFontEx("assets/fonts/SFPro.ttf", font_size_large, &chat_codepoints, chat_codepoints.len);
    defer rl.UnloadFont(g_font_chat);
    rl.SetTextureFilter(g_font_chat.texture, rl.TEXTURE_FILTER_BILINEAR);

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

    // Sacred formula particles — Fibonacci spiral orbit
    const formula_texts = [42][]const u8{
        // 27 world formulas
        "phi = 1.618", "pi*phi*e = 13.82", "L(10) = 123",
        "1/alpha = 137.036", "phi^2 = 2.618", "Feigenbaum = 4.669",
        "F(7) = 13", "sqrt(5) = 2.236", "999 = 37 x 27",
        "pi = 3.14159", "27 = 3^3", "CHSH = 2*sqrt(2)",
        "m_p/m_e = 1836", "pi^2 = 9.87", "e^pi = 23.14",
        "E8 = 248 dim", "603 = 67*9", "76 photons",
        "phi^2+1/phi^2 = 3", "tau = 6.283", "Menger = 2.727",
        "mu = 0.0382", "chi = 0.0618", "sigma = phi",
        "e = 2.71828", "13.82 Gyr", "H0 = 70.74",
        // 15 extra sacred formulas
        "V = n*3^k*pi^m*phi^p*e^q", "1.58 bits/trit",
        "phi = (1+sqrt(5))/2", "e^(i*pi) + 1 = 0",
        "3 = phi^2 + 1/phi^2", "F(n) = F(n-1)+F(n-2)",
        "hbar = 1.054e-34", "c = 299792458 m/s",
        "G = 6.674e-11", "L(n): 2,1,3,4,7,11,18...",
        "tau/phi = 3.883", "pi*e = 8.539",
        "phi^phi = 2.390", "3^3^3 = 7625597484987",
        "sqrt(2) = 1.414",
    };
    const formula_descs = [42][]const u8{
        "Golden ratio — nature's proportion", "Product of transcendentals", "10th Lucas number",
        "Fine structure constant inverse", "Golden ratio squared", "Feigenbaum chaos constant",
        "7th Fibonacci number", "Square root of five", "Sacred number 999",
        "Circle ratio", "Cube of trinity", "Quantum Bell bound",
        "Proton-electron mass ratio", "Basel problem result", "Euler to pi",
        "E8 Lie group dimension", "Energy efficiency", "Quantum advantage",
        "TRINITY IDENTITY", "Full turn tau", "Menger sponge fractal",
        "Mutation rate from phi", "Crossover rate from phi", "Selection = phi",
        "Euler's number", "Age of universe", "Hubble constant",
        "Trinity value formula", "Ternary information density",
        "Golden ratio definition", "Euler's identity",
        "Trinity identity", "Fibonacci recurrence",
        "Reduced Planck constant", "Speed of light",
        "Gravitational constant", "Lucas sequence",
        "Tau over phi", "Pi times e",
        "Phi to phi power", "Tower of threes",
        "Pythagoras' constant",
    };
    var formula_particles: [MAX_FORMULA_PARTICLES]FormulaParticle = undefined;
    // Golden angle = 2*pi/phi^2 ~ 137.508 degrees — Fibonacci spiral
    const golden_angle: f32 = 2.0 * std.math.pi / (1.618 * 1.618);
    const min_radius: f32 = 240.0; // avoid overlapping the logo
    for (0..42) |fi| {
        const n = @as(f32, @floatFromInt(fi));
        const angle = n * golden_angle;
        const radius = min_radius + n * 14.0; // Wider spacing — each formula separate
        // Alternate direction: even layers clockwise, odd layers counter-clockwise
        const layer = fi / 9; // 0..4 layers of ~9
        const direction: f32 = if (layer % 2 == 0) 1.0 else -1.0;
        const speed: f32 = direction * (0.03 - n * 0.0003);
        formula_particles[fi] = FormulaParticle.init(
            formula_texts[fi],
            formula_descs[fi],
            angle, radius, speed,
        );
    }

    // Main loop
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        time += dt;

        // Cmd+Q to quit (replaces ESC)
        if ((rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER)) and rl.IsKeyPressed(rl.KEY_Q)) {
            break;
        }

        // Cmd+D = toggle dark/light theme
        if ((rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER)) and rl.IsKeyPressed(rl.KEY_D)) {
            theme.toggle();
            reloadThemeAliases();
        }

        // Click on sun/moon toggle button (top-right)
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

        // Update window size (adaptive/resizable)
        g_width = rl.GetScreenWidth();
        g_height = rl.GetScreenHeight();

        // Adaptive font scale: proportional to screen width (ref 1280px)
        // Trinity rule: scale by phi^(log3(w/1280)) for ternary harmony
        g_font_scale = @max(0.75, @min(2.0, @as(f32, @floatFromInt(g_width)) / 1280.0));

        // Calculate pixel size to COVER full window (no gaps at edges)
        const grid_w_c: c_int = @intCast(grid.width);
        const grid_h_c: c_int = @intCast(grid.height);
        const px_w = @divTrunc(g_width + grid_w_c - 1, grid_w_c); // ceil division
        const px_h = @divTrunc(g_height + grid_h_c - 1, grid_h_c);
        g_pixel_size = @max(1, @max(px_w, px_h));

        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();
        const mx = @as(f32, @floatFromInt(mouse_x));
        const my = @as(f32, @floatFromInt(mouse_y));

        const gx = @as(usize, @intCast(@max(0, @min(@as(c_int, @intCast(grid.width - 1)), @divTrunc(mouse_x, g_pixel_size)))));
        const gy = @as(usize, @intCast(@max(0, @min(@as(c_int, @intCast(grid.height - 1)), @divTrunc(mouse_y, g_pixel_size)))));

        cursor_hue = @mod(cursor_hue + dt * 30.0, 360.0);

        // === INPUT HANDLING ===

        // Detect if chat panel is open (to disable hotkeys while typing)
        const chat_is_open: bool = blk_chat: {
            if (panels.active_panel) |idx| {
                const p = &panels.panels[idx];
                const is_visible = (p.state == .open or p.state == .opening);
                if (is_visible and p.panel_type == .chat) break :blk_chat true;
                if (is_visible and p.panel_type == .sacred_world and p.world_id == 0) break :blk_chat true;
            }
            break :blk_chat false;
        };

        // Sacred Worlds keyboard shortcuts:
        // Shift+1-9 = Realm RAZUM (blocks 0-8)
        // Ctrl+1-9  = Realm MATERIYA (blocks 9-17)
        // Cmd+1-9   = Realm DUKH (blocks 18-26)
        // DISABLED when chat panel is open (so user can type freely)
        const shift_held = rl.IsKeyDown(rl.KEY_LEFT_SHIFT) or rl.IsKeyDown(rl.KEY_RIGHT_SHIFT);
        const ctrl_held = rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL);
        const cmd_held = rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER);

        // Calculate fullscreen panel positions
        const screen_w = @as(f32, @floatFromInt(g_width));
        const screen_h = @as(f32, @floatFromInt(g_height));

        // Number keys 1-9
        const key_nums = [9]c_int{ rl.KEY_ONE, rl.KEY_TWO, rl.KEY_THREE, rl.KEY_FOUR, rl.KEY_FIVE, rl.KEY_SIX, rl.KEY_SEVEN, rl.KEY_EIGHT, rl.KEY_NINE };

        // Detect which number key was pressed (ONLY when chat is NOT open)
        if (!chat_is_open) {
            var pressed_num: ?usize = null;
            for (key_nums, 0..) |key, idx| {
                if (rl.IsKeyPressed(key)) {
                    pressed_num = idx;
                    break;
                }
            }

            if (pressed_num) |num| {
                var world_idx: ?usize = null;

                if (shift_held) {
                    // Shift+1-9 = Realm RAZUM (blocks 0-8)
                    world_idx = num; // 0-8
                } else if (ctrl_held) {
                    // Ctrl+1-9 = Realm MATERIYA (blocks 9-17)
                    world_idx = 9 + num; // 9-17
                } else if (cmd_held) {
                    // Cmd+1-9 = Realm DUKH (blocks 18-26)
                    world_idx = 18 + num; // 18-26
                }

                if (world_idx) |wi| {
                    const world = sacred_worlds.getWorldByBlock(wi);
                    const title_slice = world.name[0..world.name_len];

                    // Close all other sacred_world panels first (one world at a time)
                    for (0..panels.count) |pi| {
                        if (panels.panels[pi].panel_type == .sacred_world) {
                            panels.panels[pi].state = .closed;
                            panels.panels[pi].is_focused = false;
                        }
                    }

                    // Find a closed slot to reuse, or append if space available
                    var slot: ?usize = null;
                    for (0..panels.count) |pi| {
                        if (panels.panels[pi].state == .closed) {
                            slot = pi;
                            break;
                        }
                    }
                    if (slot == null and panels.count < MAX_PANELS) {
                        slot = panels.count;
                        panels.count += 1;
                    }
                    if (slot) |si| {
                        panels.panels[si] = GlassPanel.init(
                            0, 0, screen_w, screen_h,
                            .sacred_world, title_slice,
                        );
                        panels.panels[si].world_id = @intCast(wi);
                        // Enable Emergent Wave ScrollView for scrollable panels (not chat)
                        if (wi != 0) {
                            panels.panels[si].wave_scroll_enabled = true;
                            if (wi == 18) {
                                // Docs panel: calculate real content size from all 27 docs
                                var total_lines: u32 = 0;
                                var dci: usize = 0;
                                while (dci < 27) : (dci += 1) {
                                    total_lines += world_docs.countVisibleLines(world_docs.WORLD_DOCS[dci].raw);
                                    total_lines += 4;
                                }
                                panels.panels[si].wave_sv.setTotalItems(total_lines, 18.0 * g_font_scale);
                            } else {
                                // Other worlds: placeholder content
                                panels.panels[si].wave_sv.setTotalItems(15, 20.0);
                            }
                        }
                        panels.panels[si].open();
                        panels.panels[si].jarvisFocus();
                        panels.active_panel = si;
                    }
                }
            }
        }

        // Keyboard scroll for active sacred_world panel (docs/chat only)
        if (panels.active_panel) |ap_idx| {
            const ap = &panels.panels[ap_idx];
            if (ap.panel_type == .sacred_world and ap.state == .open and ap.world_id != 0) {
                // Skip keyboard scroll for chat panel (world_id 0) — keys go to text input
                const max_scroll_kb: f32 = if (ap.world_id == 18) blk_ks: {
                    var total: u32 = 0;
                    var dsi: usize = 0;
                    while (dsi < 27) : (dsi += 1) {
                        total += world_docs.countVisibleLines(world_docs.WORLD_DOCS[dsi].raw);
                        total += 4;
                    }
                    break :blk_ks @as(f32, @floatFromInt(total)) * 18.0 * g_font_scale;
                } else 0.0;
                if (ap.wave_scroll_enabled) {
                    // Wave scroll: keyboard impulses
                    if (rl.IsKeyPressed(rl.KEY_DOWN) or rl.IsKeyDown(rl.KEY_DOWN)) ap.wave_sv.applyImpulse(0.1);
                    if (rl.IsKeyPressed(rl.KEY_UP) or rl.IsKeyDown(rl.KEY_UP)) ap.wave_sv.applyImpulse(-0.1);
                    if (rl.IsKeyPressed(rl.KEY_PAGE_DOWN)) ap.wave_sv.applyImpulse(7.5);
                    if (rl.IsKeyPressed(rl.KEY_PAGE_UP)) ap.wave_sv.applyImpulse(-7.5);
                    if (rl.IsKeyPressed(rl.KEY_HOME)) ap.wave_sv.scrollToItem(0);
                    if (rl.IsKeyPressed(rl.KEY_END)) ap.wave_sv.scrollToItem(ap.wave_sv.total_items -| 1);
                } else {
                    // Legacy lerp scroll: keyboard targets
                    if (rl.IsKeyPressed(rl.KEY_DOWN) or rl.IsKeyDown(rl.KEY_DOWN)) ap.scroll_target += 4.0;
                    if (rl.IsKeyPressed(rl.KEY_UP) or rl.IsKeyDown(rl.KEY_UP)) ap.scroll_target -= 4.0;
                    if (rl.IsKeyPressed(rl.KEY_PAGE_DOWN)) ap.scroll_target += 300;
                    if (rl.IsKeyPressed(rl.KEY_PAGE_UP)) ap.scroll_target -= 300;
                    if (rl.IsKeyPressed(rl.KEY_HOME)) ap.scroll_target = 0;
                    if (rl.IsKeyPressed(rl.KEY_END)) ap.scroll_target = max_scroll_kb;
                    ap.scroll_target = @max(0, @min(ap.scroll_target, max_scroll_kb));
                }
            }
        }

        // ESC unfocuses all panels
        if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
            panels.unfocusAll();
            // Close all sacred world panels
            for (0..panels.count) |pi| {
                if (panels.panels[pi].panel_type == .sacred_world) {
                    panels.panels[pi].close();
                }
            }
        }

        // Click outside any panel = close all panels (return to logo menu)
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT) and !shift_held and !ctrl_held and !cmd_held) {
            var clicked_on_panel = false;
            for (0..panels.count) |pi| {
                const p = &panels.panels[pi];
                if (p.state == .open or p.state == .opening) {
                    if (mx >= p.x and mx <= p.x + p.width and my >= p.y and my <= p.y + p.height) {
                        clicked_on_panel = true;
                        break;
                    }
                }
            }
            // Also check if click is on the logo (don't close if clicking logo)
            const on_logo = logo_anim.hovered_block >= 0;
            if (!clicked_on_panel and !on_logo) {
                // Close all panels — return to main logo menu
                for (0..panels.count) |pi| {
                    panels.panels[pi].close();
                    panels.panels[pi].is_focused = false;
                }
                panels.unfocusAll();
            }
        }

        // === DIRECT CHAT PANEL INPUT ===
        // When a chat-capable panel is active and visible, input goes directly to it.
        // Accepts: .chat panels (legacy) and .sacred_world with world_id == 0 (CHAT)
        const focused_chat_panel: ?*GlassPanel = blk: {
            if (panels.active_panel) |idx| {
                const p = &panels.panels[idx];
                const is_visible = (p.state == .open or p.state == .opening);
                if (is_visible and p.panel_type == .chat) {
                    break :blk p;
                }
                if (is_visible and p.panel_type == .sacred_world and p.world_id == 0) {
                    break :blk p;
                }
            }
            break :blk null;
        };

        if (focused_chat_panel) |chat_panel| {
            _ = chat_panel; // Chat uses global state now
            // All panel-switching hotkeys are disabled when chat is open (see chat_is_open above)
            {
                // Text input: Unicode codepoints → UTF-8 encoded into global buffer
                // Skip character input when Ctrl/Cmd is held (prevents Ctrl+O etc from interfering)
                const skip_char_input = (rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL) or
                    rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER));
                var char_key = rl.GetCharPressed();
                while (char_key > 0) {
                    const cp: u21 = @intCast(char_key);
                    if (cp >= 32 and !skip_char_input) {
                        // Encode UTF-8
                        var utf8_buf: [4]u8 = undefined;
                        const utf8_len: usize = if (cp < 0x80) blk_u: {
                            utf8_buf[0] = @intCast(cp);
                            break :blk_u 1;
                        } else if (cp < 0x800) blk_u: {
                            utf8_buf[0] = @intCast(0xC0 | (cp >> 6));
                            utf8_buf[1] = @intCast(0x80 | (cp & 0x3F));
                            break :blk_u 2;
                        } else if (cp < 0x10000) blk_u: {
                            utf8_buf[0] = @intCast(0xE0 | (cp >> 12));
                            utf8_buf[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
                            utf8_buf[2] = @intCast(0x80 | (cp & 0x3F));
                            break :blk_u 3;
                        } else blk_u: {
                            utf8_buf[0] = @intCast(0xF0 | (cp >> 18));
                            utf8_buf[1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
                            utf8_buf[2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
                            utf8_buf[3] = @intCast(0x80 | (cp & 0x3F));
                            break :blk_u 4;
                        };
                        if (g_chat_input_len + utf8_len < 250) {
                            @memcpy(g_chat_input[g_chat_input_len..][0..utf8_len], utf8_buf[0..utf8_len]);
                            g_chat_input_len += utf8_len;
                            // Typing wave effect
                            effects.sink(screen_w / 2, screen_h * 0.9);
                        }
                    }
                    char_key = rl.GetCharPressed();
                }
            }

            // Backspace — delete UTF-8 characters (with key repeat for hold)
            {
                const bs_pressed = rl.IsKeyPressed(rl.KEY_BACKSPACE);
                const bs_held = rl.IsKeyDown(rl.KEY_BACKSPACE);
                if (bs_pressed) {
                    g_backspace_timer = 0.4; // Initial delay before repeat
                }
                var do_delete = bs_pressed;
                if (bs_held and !bs_pressed) {
                    g_backspace_timer -= rl.GetFrameTime();
                    if (g_backspace_timer <= 0) {
                        do_delete = true;
                        g_backspace_timer = 0.04; // Repeat rate (25 chars/sec)
                    }
                }
                if (!bs_held) g_backspace_timer = 0;
                if (do_delete and g_chat_input_len > 0) {
                    var del: usize = 1;
                    while (del < g_chat_input_len and
                        (g_chat_input[g_chat_input_len - del] & 0xC0) == 0x80)
                    {
                        del += 1;
                    }
                    g_chat_input_len -= del;
                }
            }

            // Ctrl+O clears the input
            if ((rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL)) and rl.IsKeyPressed(rl.KEY_O)) {
                g_chat_input_len = 0;
            }

            // Enter sends message
            if (rl.IsKeyPressed(rl.KEY_ENTER) and g_chat_input_len > 0) {
                // Lazy init FluentChatEngine (self-referential struct)
                if (!g_fluent_engine_inited) {
                    g_fluent_engine = fluent_chat.FluentChatEngine{
                        .message_store = fluent_chat.LightMessageStore.init(),
                        .context = fluent_chat.ConversationContext.init(),
                        .generator = undefined,
                        .fluent_enabled = true,
                        .total_turns = 0,
                        .fluent_responses = 0,
                        .high_quality_count = 0,
                    };
                    g_fluent_engine.generator = fluent_chat.ResponseGenerator.init(&g_fluent_engine.context);
                    g_fluent_engine_inited = true;
                }

                // 1. Add user message
                addGlobalChatMessage(g_chat_input[0..g_chat_input_len], .user);

                // 2. FluentChatEngine response (context-aware with intent/topic/sentiment)
                const result = g_fluent_engine.respond(g_chat_input[0..g_chat_input_len]);

                // 3. Add AI response text
                addGlobalChatMessage(result.getText(), .ai);

                // 4. Transparent log with metadata
                const stats = g_fluent_engine.getStats();
                const ms = @divFloor(result.execution_time_ns, @as(i64, 1_000_000));
                addChatLogMessage("{s} | {s} | {s} | q:{d:.0}% | {d}ms | s:{d:.2} | e:{d:.2}", .{
                    result.intent.getName(),
                    result.topic.getName(),
                    result.language.getName(),
                    result.quality * 100,
                    ms,
                    stats.sentiment,
                    stats.engagement,
                });

                // Nova effect at screen center
                effects.nova(screen_w / 2, screen_h / 2);

                // Auto-scroll: set to a large value, renderer will clamp
                g_chat_scroll_target = 99999.0;

                // Clear input
                g_chat_input_len = 0;
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

        // Theme-aware background with transparency
        rl.ClearBackground(@as(rl.Color, @bitCast(theme.clear_bg)));

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

        // Static logo in center (realm-colored, stays after loading)
        logo_anim.logo_scale = @min(@as(f32, @floatFromInt(g_width)) / LogoAnimation.SVG_WIDTH, @as(f32, @floatFromInt(g_height)) / LogoAnimation.SVG_HEIGHT) * 0.35;
        logo_anim.logo_offset = .{ .x = @as(f32, @floatFromInt(g_width)) / 2, .y = @as(f32, @floatFromInt(g_height)) / 2 };
        logo_anim.applyMouse(mx, my, dt, mouse_pressed);
        logo_anim.draw();

        // === SACRED FORMULA PARTICLES — Fibonacci spiral orbit ===
        {
            const fcx = @as(f32, @floatFromInt(g_width)) / 2;
            const fcy = @as(f32, @floatFromInt(g_height)) / 2;
            const formula_click = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
            for (&formula_particles) |*fp| {
                fp.update(dt, time, mx, my, formula_click, fcx, fcy);
                fp.draw(time, fcx, fcy, font_small);
            }
        }

        // Handle logo block click — open sacred world panel
        if (logo_anim.clicked_block >= 0) {
            const block_idx = @as(usize, @intCast(logo_anim.clicked_block));
            const world = sacred_worlds.getWorldByBlock(block_idx);

            // Close all other sacred_world panels (one at a time)
            for (0..panels.count) |pi| {
                if (panels.panels[pi].panel_type == .sacred_world) {
                    panels.panels[pi].state = .closed;
                    panels.panels[pi].is_focused = false;
                }
            }

            // Find a closed slot to reuse, or append if space available
            var slot: ?usize = null;
            for (0..panels.count) |pi| {
                if (panels.panels[pi].state == .closed) {
                    slot = pi;
                    break;
                }
            }
            if (slot == null and panels.count < MAX_PANELS) {
                slot = panels.count;
                panels.count += 1;
            }
            if (slot) |si| {
                const title_slice = world.name[0..world.name_len];
                panels.panels[si] = GlassPanel.init(
                    0, 0, screen_w, screen_h,
                    .sacred_world,
                    title_slice,
                );
                panels.panels[si].world_id = @intCast(block_idx);
                // Enable Emergent Wave ScrollView for scrollable panels (not chat)
                if (block_idx != 0) {
                    panels.panels[si].wave_scroll_enabled = true;
                    if (block_idx == 18) {
                        // Docs panel: calculate real content size from all 27 docs
                        var total_lines: u32 = 0;
                        var dci: usize = 0;
                        while (dci < 27) : (dci += 1) {
                            total_lines += world_docs.countVisibleLines(world_docs.WORLD_DOCS[dci].raw);
                            total_lines += 4;
                        }
                        panels.panels[si].wave_sv.setTotalItems(total_lines, 18.0 * g_font_scale);
                    } else {
                        // Other worlds: placeholder content
                        panels.panels[si].wave_sv.setTotalItems(15, 20.0);
                    }
                }
                panels.panels[si].open();
                panels.panels[si].jarvisFocus();
                panels.active_panel = si;
            }
        }

        // Hover tooltip: show world name + realm color
        if (logo_anim.hovered_block >= 0) {
            const hi = @as(usize, @intCast(logo_anim.hovered_block));
            const world = sacred_worlds.getWorldByBlock(hi);

            // Tooltip: adapts to theme (white bg/black text on dark, dark bg/white text on light)
            const tw: f32 = @as(f32, @floatFromInt(world.name_len)) * 9.0 + 30;
            const tx = mx + 15;
            const ty = my - 28;
            const tt_bg: rl.Color = @bitCast(theme.tooltip_bg);
            const tt_text: rl.Color = @bitCast(theme.tooltip_text);
            rl.DrawRectangleRounded(.{ .x = tx, .y = ty, .width = tw, .height = 24 }, 0.3, 8, tt_bg);

            // Dot + world name
            rl.DrawCircle(@intFromFloat(tx + 10), @intFromFloat(ty + 12), 4, tt_text);
            var tooltip_buf: [28:0]u8 = undefined;
            @memcpy(tooltip_buf[0..world.name_len], world.name[0..world.name_len]);
            tooltip_buf[world.name_len] = 0;
            rl.DrawTextEx(font_small, &tooltip_buf, .{ .x = tx + 20, .y = ty + 5 }, 13, 0.5, tt_text);
        }

        // Glass panels (on top of everything except UI)
        panels.draw(time, font);

        // Keyboard hint (minimal, top-left)
        rl.DrawTextEx(font_small, "Shift+1-9 RAZUM | Ctrl+1-9 MATERIYA | Cmd+1-9 DUKH | ESC", .{ .x = 10, .y = 10 }, 13, 1, withAlpha(TEXT_DIM, 180));


        // === SUN/MOON THEME TOGGLE (top-right, 20px from top) ===
        {
            const toggle_cx: f32 = @as(f32, @floatFromInt(g_width)) - 35;
            const toggle_cy: f32 = 30; // 20px margin from top + radius
            const toggle_r: f32 = 10;
            if (theme.isDark()) {
                // Crescent moon: white circle + bg-colored circle offset
                const moon_color = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 220 };
                rl.DrawCircle(@intFromFloat(toggle_cx), @intFromFloat(toggle_cy), toggle_r, moon_color);
                rl.DrawCircle(@intFromFloat(toggle_cx + 5), @intFromFloat(toggle_cy - 3), toggle_r - 1, @as(rl.Color, @bitCast(theme.clear_bg)));
            } else {
                // Sun: black on light theme (visible on white background)
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

        // Status bar text: rainbow on dark, dark text on light
        const stat_text_color = if (theme.isDark()) @as(?rl.Color, null) else TEXT_WHITE; // null = use per-stat color

        // Left: TRINITY label
        rl.DrawTextEx(font_small, "TRINITY", .{ .x = 12, .y = status_y + 5 }, 13, 0.5, stat_text_color orelse HYPER_GREEN);

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
        rl.DrawTextEx(font_small, &time_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_MAGENTA);

        // Uptime
        const up_hours = uptime_sec / 3600;
        const up_mins = (uptime_sec % 3600) / 60;
        _ = std.fmt.bufPrintZ(&stat_buf, "UP {d}h{d}m", .{ up_hours, up_mins }) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse PURPLE);

        // Processes
        _ = std.fmt.bufPrintZ(&stat_buf, "PROC {d}", .{processes}) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse BLUE);

        // NET
        _ = std.fmt.bufPrintZ(&stat_buf, "NET {d:.1}M", .{net_down + net_up}) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_CYAN);

        // DISK
        _ = std.fmt.bufPrintZ(&stat_buf, "DISK {d:.0}G", .{disk_used}) catch {};
        x_pos -= spacing + 10;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_GREEN);

        // TEMP
        _ = std.fmt.bufPrintZ(&stat_buf, "{d:.0}C", .{cpu_temp}) catch {};
        x_pos -= spacing - 30;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_YELLOW);

        // MEM
        _ = std.fmt.bufPrintZ(&stat_buf, "MEM {d:.1}G", .{mem_used}) catch {};
        x_pos -= spacing + 5;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse ORANGE);

        // CPU
        _ = std.fmt.bufPrintZ(&stat_buf, "CPU {d:.0}%", .{cpu_usage}) catch {};
        x_pos -= spacing;
        rl.DrawTextEx(font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_RED);
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
