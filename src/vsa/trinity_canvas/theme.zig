// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY THEME v2.0.0 — HYPER TERMINAL STYLE
// Single source of truth for ALL colors, fonts, and styles
// Generated from specs/tri/trinity_canvas/theme.vibee + enhanced
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// MATH CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f32 = 1.6180339887;
pub const PHI_INV: f32 = 0.6180339887;
pub const TAU: f32 = 6.28318530718;
pub const PHI_SQ: f32 = 2.618033988749895;
pub const TRINITY: f32 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR TYPE (compatible with any cImport of raylib)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR PALETTE — HYPER TERMINAL STYLE
// Single source of truth for all UI colors
// ═══════════════════════════════════════════════════════════════════════════════

pub const colors = struct {
    // === BACKGROUNDS ===
    pub const bg = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    pub const bg_surface = Color{ .r = 0x0A, .g = 0x0A, .b = 0x0A, .a = 0xFF }; // Slightly above pure black
    pub const bg_panel = Color{ .r = 0x0D, .g = 0x0D, .b = 0x0D, .a = 0xF5 };
    pub const bg_input = Color{ .r = 0x10, .g = 0x10, .b = 0x10, .a = 0xFF };
    pub const bg_hover = Color{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 0xFF };
    pub const bg_bar = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xFF };
    pub const bg_selected = Color{ .r = 0x20, .g = 0x20, .b = 0x20, .a = 0xFF };

    // === TEXT ===
    pub const text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    pub const text_muted = Color{ .r = 0x6B, .g = 0x6B, .b = 0x6B, .a = 0xFF };
    pub const text_dim = Color{ .r = 0x50, .g = 0x50, .b = 0x50, .a = 0xFF };
    pub const text_hint = Color{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xFF }; // Hint text
    pub const text_bright = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };

    // === BORDERS ===
    pub const border = Color{ .r = 0x33, .g = 0x33, .b = 0x33, .a = 0xFF };
    pub const border_focus = Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = 0xFF };
    pub const border_subtle = Color{ .r = 0x22, .g = 0x22, .b = 0x22, .a = 0xFF };
    pub const border_light = Color{ .r = 0x40, .g = 0x40, .b = 0x40, .a = 0xFF };

    // === HYPER ACCENT COLORS ===
    pub const magenta = Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = 0xFF };
    pub const cyan = Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = 0xFF };
    pub const green = Color{ .r = 0x50, .g = 0xFA, .b = 0x7B, .a = 0xFF };
    pub const yellow = Color{ .r = 0xF1, .g = 0xFA, .b = 0x8C, .a = 0xFF };
    pub const red = Color{ .r = 0xFF, .g = 0x55, .b = 0x55, .a = 0xFF };
    pub const blue = Color{ .r = 0x8B, .g = 0xE9, .b = 0xFD, .a = 0xFF };
    pub const orange = Color{ .r = 0xFF, .g = 0xB8, .b = 0x6C, .a = 0xFF };
    pub const purple = Color{ .r = 0xBD, .g = 0x93, .b = 0xF9, .a = 0xFF };

    // === LOGO COLOR ===
    pub const logo_green = Color{ .r = 0x08, .g = 0xFA, .b = 0xB5, .a = 0xFF }; // #08FAB5

    // === SEMANTIC COLORS ===
    pub const success = green;
    pub const warning = yellow;
    pub const error_ = red;
    pub const info = cyan;
    pub const primary = magenta;

    // === GLOW COLORS (with alpha) ===
    pub const glow_magenta = Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = 0x28 };
    pub const glow_cyan = Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = 0x28 };
    pub const glow_green = Color{ .r = 0x50, .g = 0xFA, .b = 0x7B, .a = 0x28 };

    // === FILE TYPE COLORS (Hyper palette) ===
    pub const file_folder = green; // Folders = green
    pub const file_zig = Color{ .r = 0xF7, .g = 0xA4, .b = 0x1D, .a = 0xFF }; // Zig orange (brand)
    pub const file_code = Color{ .r = 0x80, .g = 0xFF, .b = 0xA0, .a = 0xFF }; // Light green
    pub const file_image = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF }; // White
    pub const file_audio = Color{ .r = 0x00, .g = 0xCC, .b = 0x66, .a = 0xFF }; // Dark green
    pub const file_document = Color{ .r = 0xC0, .g = 0xC0, .b = 0xC0, .a = 0xFF }; // Silver
    pub const file_data = green;
    pub const file_unknown = text_muted;

    // === ADDITIONAL UI COLORS ===
    pub const separator = Color{ .r = 0x80, .g = 0x80, .b = 0x80, .a = 0xFF };
    pub const content_text = Color{ .r = 0xC0, .g = 0xC8, .b = 0xD0, .a = 0xFF };
    pub const recording_red = Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = 0xFF };
    pub const recording_dim = Color{ .r = 0x80, .g = 0x20, .b = 0x20, .a = 0xFF };
    pub const gold = Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF };

    // === STATUS COLOR FUNCTIONS ===
    pub fn cpuColor(usage: f32) Color {
        if (usage > 80) return red;
        if (usage > 50) return yellow;
        return green;
    }

    pub fn memColor(pct: f32) Color {
        if (pct > 0.8) return red;
        if (pct > 0.5) return yellow;
        return magenta;
    }

    pub fn tempColor(temp: f32) Color {
        if (temp > 80) return red;
        if (temp > 60) return yellow;
        return cyan;
    }

    pub fn diskColor(pct: f32) Color {
        if (pct > 0.9) return red;
        if (pct > 0.7) return yellow;
        return blue;
    }

    pub fn withAlpha(color: Color, alpha: u8) Color {
        return Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FONT CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const fonts = struct {
    pub const path_regular = "assets/fonts/Outfit-Regular.ttf";
    pub const path_mono = "assets/fonts/JetBrainsMono-Regular.ttf";

    // Increased font sizes for better readability (Hyper style)
    pub const size_title: c_int = 16;
    pub const size_body: c_int = 14;
    pub const size_small: c_int = 13;
    pub const size_tiny: c_int = 12;
    pub const size_code: c_int = 13;
    pub const size_large: c_int = 20;

    pub const spacing: f32 = 0.5;
};

// ═══════════════════════════════════════════════════════════════════════════════
// PANEL STYLES
// ═══════════════════════════════════════════════════════════════════════════════

pub const panel = struct {
    pub const radius: f32 = 12.0;
    pub const border_width: f32 = 1.0;
    pub const title_height: f32 = 32.0;
    pub const padding: f32 = 16.0;
    pub const glow_alpha: u8 = 40;
    pub const min_width: f32 = 200.0;
    pub const min_height: f32 = 150.0;
    pub const resize_handle: f32 = 16.0;

    // Traffic light buttons (macOS style)
    pub const btn_close = Color{ .r = 0xFF, .g = 0x5F, .b = 0x57, .a = 0xFF };
    pub const btn_minimize = Color{ .r = 0xFE, .g = 0xBC, .b = 0x2E, .a = 0xFF };
    pub const btn_maximize = Color{ .r = 0x28, .g = 0xC8, .b = 0x40, .a = 0xFF };
    pub const btn_radius: f32 = 6.0;
    pub const btn_spacing: f32 = 20.0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS BAR
// ═══════════════════════════════════════════════════════════════════════════════

pub const status_bar = struct {
    pub const height: f32 = 24.0;
    pub const padding: f32 = 12.0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANIMATION PARAMETERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const anim = struct {
    pub const morph_speed: f32 = 2.5;
    pub const glow_decay: f32 = 1.2;
    pub const ring_rotation: f32 = 2.0;
    pub const focus_lerp: f32 = 4.0;
    pub const fade_speed: f32 = 3.0;
    pub const pulse_speed: f32 = 3.0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYSTEM PANEL THRESHOLDS
// ═══════════════════════════════════════════════════════════════════════════════

pub const thresholds = struct {
    pub const cpu_warning: f32 = 50.0;
    pub const cpu_critical: f32 = 80.0;
    pub const mem_warning: f32 = 0.5;
    pub const mem_critical: f32 = 0.8;
    pub const temp_warning: f32 = 60.0;
    pub const temp_critical: f32 = 80.0;
    pub const disk_warning: f32 = 0.7;
    pub const disk_critical: f32 = 0.9;
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYOUT CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const layout = struct {
    pub const bar_height: f32 = 8.0;
    pub const row_height: f32 = 50.0;
    pub const margin: f32 = 20.0;
    pub const icon_size: f32 = 16.0;
    pub const spacing: f32 = 8.0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// φ-based easing function (smooth cosmic feel)
pub fn easePhiInOut(t: f32) f32 {
    if (t < 0.5) {
        return 2.0 * t * t * PHI_INV;
    } else {
        const u = 2.0 * t - 1.0;
        return 1.0 - (1.0 - u) * (1.0 - u) * PHI_INV;
    }
}

/// Linear interpolation
pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

/// Clamp value between min and max
pub fn clamp(value: f32, min_val: f32, max_val: f32) f32 {
    return @max(min_val, @min(max_val, value));
}

/// HSV to RGB conversion
pub fn hsvToRgb(h: f32, s: f32, v: f32) [3]u8 {
    const c = v * s;
    const h_prime = @mod(h / 60.0, 6.0);
    const x = c * (1.0 - @abs(@mod(h_prime, 2.0) - 1.0));
    const m = v - c;

    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    if (h_prime < 1) {
        r = c;
        g = x;
    } else if (h_prime < 2) {
        r = x;
        g = c;
    } else if (h_prime < 3) {
        g = c;
        b = x;
    } else if (h_prime < 4) {
        g = x;
        b = c;
    } else if (h_prime < 5) {
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

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_constants" {
    const trinity_check = PHI * PHI + 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqAbs(trinity_check, 3.0, 0.0001);
}

test "color_functions" {
    // CPU color thresholds
    try std.testing.expectEqual(colors.cpuColor(30).g, colors.green.g);
    try std.testing.expectEqual(colors.cpuColor(60).g, colors.yellow.g);
    try std.testing.expectEqual(colors.cpuColor(90).g, colors.red.g);
}
