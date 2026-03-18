// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY THEME v3.0.0 — DARK/LIGHT SWITCHABLE
// Single source of truth for ALL colors, fonts, and styles
// Generated from specs/tri/trinity_canvas/theme.tri + enhanced
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
// THEME MODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ThemeMode = enum { dark, light };
pub var current_mode: ThemeMode = .dark;

// ═══════════════════════════════════════════════════════════════════════════════
// ACCENT COLORS — theme-invariant (same in dark and light)
// ═══════════════════════════════════════════════════════════════════════════════

pub const accents = struct {
    pub const magenta = Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = 0xFF };
    pub const cyan = Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = 0xFF };
    pub const green = Color{ .r = 0x50, .g = 0xFA, .b = 0x7B, .a = 0xFF };
    pub const yellow = Color{ .r = 0xF1, .g = 0xFA, .b = 0x8C, .a = 0xFF };
    pub const red = Color{ .r = 0xFF, .g = 0x55, .b = 0x55, .a = 0xFF };
    pub const blue = Color{ .r = 0x8B, .g = 0xE9, .b = 0xFD, .a = 0xFF };
    pub const orange = Color{ .r = 0xFF, .g = 0xB8, .b = 0x6C, .a = 0xFF };
    pub const purple = Color{ .r = 0xBD, .g = 0x93, .b = 0xF9, .a = 0xFF };
    pub const logo_green = Color{ .r = 0x08, .g = 0xFA, .b = 0xB5, .a = 0xFF };
    pub const gold = Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF };

    // Semantic
    pub const success = green;
    pub const warning = yellow;
    pub const error_ = red;
    pub const info = cyan;
    pub const primary = magenta;

    // Glow variants
    pub const glow_magenta = Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = 0x28 };
    pub const glow_cyan = Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = 0x28 };
    pub const glow_green = Color{ .r = 0x50, .g = 0xFA, .b = 0x7B, .a = 0x28 };

    // Recording
    pub const recording_red = Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = 0xFF };
    pub const recording_dim = Color{ .r = 0x80, .g = 0x20, .b = 0x20, .a = 0xFF };

    // File type colors
    pub const file_folder = green;
    pub const file_zig = Color{ .r = 0xF7, .g = 0xA4, .b = 0x1D, .a = 0xFF };
    pub const file_code = Color{ .r = 0x80, .g = 0xFF, .b = 0xA0, .a = 0xFF };
    pub const file_image = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    pub const file_audio = Color{ .r = 0x00, .g = 0xCC, .b = 0x66, .a = 0xFF };
    pub const file_document = Color{ .r = 0xC0, .g = 0xC0, .b = 0xC0, .a = 0xFF };
    pub const file_data = green;
    pub const file_unknown = Color{ .r = 0x6B, .g = 0x6B, .b = 0x6B, .a = 0xFF };

    // Border focus
    pub const border_focus = magenta;

    // Network node status colors
    pub const node_online = green;
    pub const node_offline = Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = 0xFF };
    pub const node_connecting = yellow;
    pub const node_degraded = orange;
    pub const node_error = red;
    pub const node_local = cyan;
    pub const node_remote = magenta;
    pub const node_layer_bar = Color{ .r = 0x30, .g = 0x30, .b = 0x40, .a = 0xFF };

    // Status color functions
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
};

// ═══════════════════════════════════════════════════════════════════════════════
// DARK PALETTE (private)
// ═══════════════════════════════════════════════════════════════════════════════

const dark = struct {
    // Backgrounds
    const bg = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const bg_surface = Color{ .r = 0x0A, .g = 0x0A, .b = 0x0A, .a = 0xFF };
    const bg_panel = Color{ .r = 0x0D, .g = 0x0D, .b = 0x0D, .a = 0xF5 };
    const bg_input = Color{ .r = 0x10, .g = 0x10, .b = 0x10, .a = 0xFF };
    const bg_hover = Color{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 0xFF };
    const bg_bar = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xFF };
    const bg_selected = Color{ .r = 0x20, .g = 0x20, .b = 0x20, .a = 0xFF };
    // Text
    const text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const text_muted = Color{ .r = 0x6B, .g = 0x6B, .b = 0x6B, .a = 0xFF };
    const text_dim = Color{ .r = 0x50, .g = 0x50, .b = 0x50, .a = 0xFF };
    const text_hint = Color{ .r = 0x66, .g = 0x66, .b = 0x66, .a = 0xFF };
    const text_bright = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const content_text = Color{ .r = 0xC0, .g = 0xC8, .b = 0xD0, .a = 0xFF };
    // Borders
    const border = Color{ .r = 0x33, .g = 0x33, .b = 0x33, .a = 0xFF };
    const border_subtle = Color{ .r = 0x22, .g = 0x22, .b = 0x22, .a = 0xFF };
    const border_light = Color{ .r = 0x40, .g = 0x40, .b = 0x40, .a = 0xFF };
    const separator = Color{ .r = 0x80, .g = 0x80, .b = 0x80, .a = 0xFF };
    // Logo
    const logo_petal = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const logo_outline = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const logo_highlight = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    // Panel
    const panel_title = Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = 0xFF };
    const panel_title_sep = Color{ .r = 0x80, .g = 0x80, .b = 0x80, .a = 0xFF };
    const sacred_world_bg = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    // Tooltip (inverted on dark: white bg, black text)
    const tooltip_bg = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xF0 };
    const tooltip_text = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    // Formula
    const formula_text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    // UI elements
    const name_label_bg = Color{ .r = 0x10, .g = 0x10, .b = 0x10, .a = 0xFF };
    const name_label_text = Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = 0xFF };
    const line_number = Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = 0xFF };
    const resize_handle = Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = 0xFF };
    const settings_toggle_off = Color{ .r = 0x40, .g = 0x40, .b = 0x50, .a = 0xFF };
    const settings_toggle_on = Color{ .r = 0x28, .g = 0xC8, .b = 0x40, .a = 0xFF };
    const tool_selected_bg = Color{ .r = 0x18, .g = 0x28, .b = 0x18, .a = 0xFF };
    const drop_zone_border = Color{ .r = 0x40, .g = 0x40, .b = 0x40, .a = 0xFF };
    const drop_zone_plus = Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = 0xFF };
    const progress_bar_bg = Color{ .r = 0x40, .g = 0x40, .b = 0x50, .a = 0xFF };
    // Chat panel
    const chat_text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const chat_label_user = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const chat_label_ai = Color{ .r = 0x4A, .g = 0xDE, .b = 0x80, .a = 0xFF };
    const chat_bubble_user = Color{ .r = 0x1A, .g = 0x1E, .b = 0x24, .a = 0xFF };
    const chat_bubble_ai = Color{ .r = 0x14, .g = 0x1A, .b = 0x20, .a = 0xFF };
    const chat_bubble_border = Color{ .r = 0x30, .g = 0x38, .b = 0x40, .a = 0xFF };
    // Dark theme: white header/input, black text (inverted contrast)
    const chat_input_bg = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const chat_input_border = Color{ .r = 0xCC, .g = 0xCC, .b = 0xCC, .a = 0xFF };
    const chat_input_text = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const sacred_header_bg = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const sacred_header_text = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    // Panel transparency: 230/255 = semi-transparent glass
    const panel_content_alpha: f32 = 180;
    // Clear background (with transparency)
    const clear_bg = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xCC };
};

// ═══════════════════════════════════════════════════════════════════════════════
// LIGHT PALETTE (private)
// ═══════════════════════════════════════════════════════════════════════════════

const light = struct {
    // Backgrounds
    const bg = Color{ .r = 0xF5, .g = 0xF5, .b = 0xF5, .a = 0xFF };
    const bg_surface = Color{ .r = 0xEE, .g = 0xEE, .b = 0xEE, .a = 0xFF };
    const bg_panel = Color{ .r = 0xF0, .g = 0xF0, .b = 0xF0, .a = 0xFF };
    const bg_input = Color{ .r = 0xE8, .g = 0xE8, .b = 0xE8, .a = 0xFF };
    const bg_hover = Color{ .r = 0xDE, .g = 0xDE, .b = 0xDE, .a = 0xFF };
    const bg_bar = Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = 0xFF };
    const bg_selected = Color{ .r = 0xD8, .g = 0xD8, .b = 0xD8, .a = 0xFF };
    // Text
    const text = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xFF };
    const text_muted = Color{ .r = 0x80, .g = 0x80, .b = 0x80, .a = 0xFF };
    const text_dim = Color{ .r = 0x99, .g = 0x99, .b = 0x99, .a = 0xFF };
    const text_hint = Color{ .r = 0x88, .g = 0x88, .b = 0x88, .a = 0xFF };
    const text_bright = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const content_text = Color{ .r = 0x30, .g = 0x30, .b = 0x38, .a = 0xFF };
    // Borders
    const border = Color{ .r = 0xCC, .g = 0xCC, .b = 0xCC, .a = 0xFF };
    const border_subtle = Color{ .r = 0xDD, .g = 0xDD, .b = 0xDD, .a = 0xFF };
    const border_light = Color{ .r = 0xBB, .g = 0xBB, .b = 0xBB, .a = 0xFF };
    const separator = Color{ .r = 0xA0, .g = 0xA0, .b = 0xA0, .a = 0xFF };
    // Logo (inverted: white petals, black outline)
    const logo_petal = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const logo_outline = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const logo_highlight = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    // Panel
    const panel_title = Color{ .r = 0x20, .g = 0x20, .b = 0x20, .a = 0xFF };
    const panel_title_sep = Color{ .r = 0xA0, .g = 0xA0, .b = 0xA0, .a = 0xFF };
    const sacred_world_bg = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    // Tooltip (inverted on light: dark bg, white text)
    const tooltip_bg = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xF0 };
    const tooltip_text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    // Formula
    const formula_text = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xFF };
    // UI elements
    const name_label_bg = Color{ .r = 0xEE, .g = 0xEE, .b = 0xEE, .a = 0xFF };
    const name_label_text = Color{ .r = 0x20, .g = 0x20, .b = 0x20, .a = 0xFF };
    const line_number = Color{ .r = 0x99, .g = 0x99, .b = 0x99, .a = 0xFF };
    const resize_handle = Color{ .r = 0x99, .g = 0x99, .b = 0x99, .a = 0xFF };
    const settings_toggle_off = Color{ .r = 0xBB, .g = 0xBB, .b = 0xC0, .a = 0xFF };
    const settings_toggle_on = Color{ .r = 0x28, .g = 0xC8, .b = 0x40, .a = 0xFF };
    const tool_selected_bg = Color{ .r = 0xD8, .g = 0xE8, .b = 0xD8, .a = 0xFF };
    const drop_zone_border = Color{ .r = 0xBB, .g = 0xBB, .b = 0xBB, .a = 0xFF };
    const drop_zone_plus = Color{ .r = 0x99, .g = 0x99, .b = 0x99, .a = 0xFF };
    const progress_bar_bg = Color{ .r = 0xBB, .g = 0xBB, .b = 0xC0, .a = 0xFF };
    // Chat panel (light: dark text on light bubbles, fully opaque)
    const chat_text = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xFF };
    const chat_label_user = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 0xFF };
    const chat_label_ai = Color{ .r = 0x16, .g = 0x8A, .b = 0x40, .a = 0xFF };
    const chat_bubble_user = Color{ .r = 0xE2, .g = 0xE6, .b = 0xEC, .a = 0xFF };
    const chat_bubble_ai = Color{ .r = 0xEA, .g = 0xEE, .b = 0xF2, .a = 0xFF };
    const chat_bubble_border = Color{ .r = 0xCC, .g = 0xD0, .b = 0xD4, .a = 0xFF };
    // Light theme: black header/input, white text (inverted contrast)
    const chat_input_bg = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const chat_input_border = Color{ .r = 0x33, .g = 0x33, .b = 0x33, .a = 0xFF };
    const chat_input_text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const sacred_header_bg = Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
    const sacred_header_text = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    // Panel transparency: 255 = fully opaque (no dark bleed-through)
    const panel_content_alpha: f32 = 255;
    // Clear background (opaque white — no transparency on light theme)
    const clear_bg = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
};

// ═══════════════════════════════════════════════════════════════════════════════
// RUNTIME-SWITCHABLE SURFACE COLORS (pub var, initialized to dark)
// ═══════════════════════════════════════════════════════════════════════════════

// Backgrounds
pub var bg: Color = dark.bg;
pub var bg_surface: Color = dark.bg_surface;
pub var bg_panel: Color = dark.bg_panel;
pub var bg_input: Color = dark.bg_input;
pub var bg_hover: Color = dark.bg_hover;
pub var bg_bar: Color = dark.bg_bar;
pub var bg_selected: Color = dark.bg_selected;
// Text
pub var text: Color = dark.text;
pub var text_muted: Color = dark.text_muted;
pub var text_dim: Color = dark.text_dim;
pub var text_hint: Color = dark.text_hint;
pub var text_bright: Color = dark.text_bright;
pub var content_text: Color = dark.content_text;
// Borders
pub var border: Color = dark.border;
pub var border_subtle: Color = dark.border_subtle;
pub var border_light: Color = dark.border_light;
pub var separator: Color = dark.separator;
// Logo
pub var logo_petal: Color = dark.logo_petal;
pub var logo_outline: Color = dark.logo_outline;
pub var logo_highlight: Color = dark.logo_highlight;
// Panel
pub var panel_title: Color = dark.panel_title;
pub var panel_title_sep: Color = dark.panel_title_sep;
pub var sacred_world_bg: Color = dark.sacred_world_bg;
// Tooltip
pub var tooltip_bg: Color = dark.tooltip_bg;
pub var tooltip_text: Color = dark.tooltip_text;
// Formula
pub var formula_text: Color = dark.formula_text;
// UI elements
pub var name_label_bg: Color = dark.name_label_bg;
pub var name_label_text: Color = dark.name_label_text;
pub var line_number: Color = dark.line_number;
pub var resize_handle: Color = dark.resize_handle;
pub var settings_toggle_off: Color = dark.settings_toggle_off;
pub var settings_toggle_on: Color = dark.settings_toggle_on;
pub var tool_selected_bg: Color = dark.tool_selected_bg;
pub var drop_zone_border: Color = dark.drop_zone_border;
pub var drop_zone_plus: Color = dark.drop_zone_plus;
pub var progress_bar_bg: Color = dark.progress_bar_bg;
// Chat panel
pub var chat_text: Color = dark.chat_text;
pub var chat_label_user: Color = dark.chat_label_user;
pub var chat_label_ai: Color = dark.chat_label_ai;
pub var chat_bubble_user: Color = dark.chat_bubble_user;
pub var chat_bubble_ai: Color = dark.chat_bubble_ai;
pub var chat_bubble_border: Color = dark.chat_bubble_border;
pub var chat_input_bg: Color = dark.chat_input_bg;
pub var chat_input_border: Color = dark.chat_input_border;
pub var chat_input_text: Color = dark.chat_input_text;
pub var sacred_header_bg: Color = dark.sacred_header_bg;
pub var sacred_header_text: Color = dark.sacred_header_text;
pub var panel_content_alpha: f32 = dark.panel_content_alpha;
// Clear background
pub var clear_bg: Color = dark.clear_bg;

// ═══════════════════════════════════════════════════════════════════════════════
// THEME TOGGLE
// ═══════════════════════════════════════════════════════════════════════════════

pub fn toggle() void {
    current_mode = if (current_mode == .dark) .light else .dark;
    applyTheme(current_mode);
}

pub fn isDark() bool {
    return current_mode == .dark;
}

pub fn applyTheme(mode: ThemeMode) void {
    switch (mode) {
        .dark => {
            bg = dark.bg;
            bg_surface = dark.bg_surface;
            bg_panel = dark.bg_panel;
            bg_input = dark.bg_input;
            bg_hover = dark.bg_hover;
            bg_bar = dark.bg_bar;
            bg_selected = dark.bg_selected;
            text = dark.text;
            text_muted = dark.text_muted;
            text_dim = dark.text_dim;
            text_hint = dark.text_hint;
            text_bright = dark.text_bright;
            content_text = dark.content_text;
            border = dark.border;
            border_subtle = dark.border_subtle;
            border_light = dark.border_light;
            separator = dark.separator;
            logo_petal = dark.logo_petal;
            logo_outline = dark.logo_outline;
            logo_highlight = dark.logo_highlight;
            panel_title = dark.panel_title;
            panel_title_sep = dark.panel_title_sep;
            sacred_world_bg = dark.sacred_world_bg;
            tooltip_bg = dark.tooltip_bg;
            tooltip_text = dark.tooltip_text;
            formula_text = dark.formula_text;
            name_label_bg = dark.name_label_bg;
            name_label_text = dark.name_label_text;
            line_number = dark.line_number;
            resize_handle = dark.resize_handle;
            settings_toggle_off = dark.settings_toggle_off;
            settings_toggle_on = dark.settings_toggle_on;
            tool_selected_bg = dark.tool_selected_bg;
            drop_zone_border = dark.drop_zone_border;
            drop_zone_plus = dark.drop_zone_plus;
            progress_bar_bg = dark.progress_bar_bg;
            chat_text = dark.chat_text;
            chat_label_user = dark.chat_label_user;
            chat_label_ai = dark.chat_label_ai;
            chat_bubble_user = dark.chat_bubble_user;
            chat_bubble_ai = dark.chat_bubble_ai;
            chat_bubble_border = dark.chat_bubble_border;
            chat_input_bg = dark.chat_input_bg;
            chat_input_border = dark.chat_input_border;
            chat_input_text = dark.chat_input_text;
            sacred_header_bg = dark.sacred_header_bg;
            sacred_header_text = dark.sacred_header_text;
            panel_content_alpha = dark.panel_content_alpha;
            clear_bg = dark.clear_bg;
        },
        .light => {
            bg = light.bg;
            bg_surface = light.bg_surface;
            bg_panel = light.bg_panel;
            bg_input = light.bg_input;
            bg_hover = light.bg_hover;
            bg_bar = light.bg_bar;
            bg_selected = light.bg_selected;
            text = light.text;
            text_muted = light.text_muted;
            text_dim = light.text_dim;
            text_hint = light.text_hint;
            text_bright = light.text_bright;
            content_text = light.content_text;
            border = light.border;
            border_subtle = light.border_subtle;
            border_light = light.border_light;
            separator = light.separator;
            logo_petal = light.logo_petal;
            logo_outline = light.logo_outline;
            logo_highlight = light.logo_highlight;
            panel_title = light.panel_title;
            panel_title_sep = light.panel_title_sep;
            sacred_world_bg = light.sacred_world_bg;
            tooltip_bg = light.tooltip_bg;
            tooltip_text = light.tooltip_text;
            formula_text = light.formula_text;
            name_label_bg = light.name_label_bg;
            name_label_text = light.name_label_text;
            line_number = light.line_number;
            resize_handle = light.resize_handle;
            settings_toggle_off = light.settings_toggle_off;
            settings_toggle_on = light.settings_toggle_on;
            tool_selected_bg = light.tool_selected_bg;
            drop_zone_border = light.drop_zone_border;
            drop_zone_plus = light.drop_zone_plus;
            progress_bar_bg = light.progress_bar_bg;
            chat_text = light.chat_text;
            chat_label_user = light.chat_label_user;
            chat_label_ai = light.chat_label_ai;
            chat_bubble_user = light.chat_bubble_user;
            chat_bubble_ai = light.chat_bubble_ai;
            chat_bubble_border = light.chat_bubble_border;
            chat_input_bg = light.chat_input_bg;
            chat_input_border = light.chat_input_border;
            chat_input_text = light.chat_input_text;
            sacred_header_bg = light.sacred_header_bg;
            sacred_header_text = light.sacred_header_text;
            panel_content_alpha = light.panel_content_alpha;
            clear_bg = light.clear_bg;
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKWARD COMPAT — colors struct (delegates to mutable vars + accents)
// Existing code that uses `theme.colors.X` will still compile.
// ═══════════════════════════════════════════════════════════════════════════════

pub const colors = struct {
    // These are accessor functions disguised as const — they read from pub var at runtime
    // For backward compat, we re-export the pub vars via inline getters
    // BUT Zig doesn't allow pub var inside a struct scope.
    // So we provide the accents + keep old references working via pub const aliases.

    // Accents (const — never change)
    pub const magenta = accents.magenta;
    pub const cyan = accents.cyan;
    pub const green = accents.green;
    pub const yellow = accents.yellow;
    pub const red = accents.red;
    pub const blue = accents.blue;
    pub const orange = accents.orange;
    pub const purple = accents.purple;
    pub const logo_green = accents.logo_green;
    pub const gold = accents.gold;
    pub const success = accents.success;
    pub const warning = accents.warning;
    pub const error_ = accents.error_;
    pub const info = accents.info;
    pub const primary = accents.primary;
    pub const glow_magenta = accents.glow_magenta;
    pub const glow_cyan = accents.glow_cyan;
    pub const glow_green = accents.glow_green;
    pub const recording_red = accents.recording_red;
    pub const recording_dim = accents.recording_dim;
    pub const file_folder = accents.file_folder;
    pub const file_zig = accents.file_zig;
    pub const file_code = accents.file_code;
    pub const file_image = accents.file_image;
    pub const file_audio = accents.file_audio;
    pub const file_document = accents.file_document;
    pub const file_data = accents.file_data;
    pub const file_unknown = accents.file_unknown;
    pub const border_focus = accents.border_focus;

    // Surface colors — these are the DARK defaults (comptime const).
    // Code that uses theme.colors.bg gets the dark value at comptime.
    // Code that uses theme.bg gets the runtime-switchable value.
    // We keep these for backward compat but NEW code should use theme.bg etc.
    pub const bg = dark.bg;
    pub const bg_surface = dark.bg_surface;
    pub const bg_panel = dark.bg_panel;
    pub const bg_input = dark.bg_input;
    pub const bg_hover = dark.bg_hover;
    pub const bg_bar = dark.bg_bar;
    pub const bg_selected = dark.bg_selected;
    pub const text = dark.text;
    pub const text_muted = dark.text_muted;
    pub const text_dim = dark.text_dim;
    pub const text_hint = dark.text_hint;
    pub const text_bright = dark.text_bright;
    pub const content_text = dark.content_text;
    pub const border = dark.border;
    pub const border_subtle = dark.border_subtle;
    pub const border_light = dark.border_light;
    pub const separator = dark.separator;

    // Chat panel (comptime dark defaults — runtime uses pub var)
    pub const chat_text = dark.chat_text;
    pub const chat_label_user = dark.chat_label_user;
    pub const chat_label_ai = dark.chat_label_ai;
    pub const chat_bubble_user = dark.chat_bubble_user;
    pub const chat_bubble_ai = dark.chat_bubble_ai;
    pub const chat_bubble_border = dark.chat_bubble_border;
    pub const chat_input_bg = dark.chat_input_bg;
    pub const chat_input_border = dark.chat_input_border;
    pub const chat_input_text = dark.chat_input_text;
    pub const sacred_header_bg = dark.sacred_header_bg;
    pub const sacred_header_text = dark.sacred_header_text;

    // Status color functions
    pub const cpuColor = accents.cpuColor;
    pub const memColor = accents.memColor;
    pub const tempColor = accents.tempColor;
    pub const diskColor = accents.diskColor;

    pub fn withAlpha(color: Color, alpha: u8) Color {
        return Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };
    }
};

// Top-level withAlpha for convenience
pub fn withAlpha(color: Color, alpha: u8) Color {
    return Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FONT CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const fonts = struct {
    pub const path_regular = "assets/fonts/Outfit-Regular.ttf";
    pub const path_mono = "assets/fonts/JetBrainsMono-Regular.ttf";

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
    pub const resize_handle_size: f32 = 16.0;

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

pub fn easePhiInOut(t: f32) f32 {
    if (t < 0.5) {
        return 2.0 * t * t * PHI_INV;
    } else {
        const u = 2.0 * t - 1.0;
        return 1.0 - (1.0 - u) * (1.0 - u) * PHI_INV;
    }
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn clamp(value: f32, min_val: f32, max_val: f32) f32 {
    return @max(min_val, @min(max_val, value));
}

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

test "theme_toggle" {
    // Start dark
    try std.testing.expectEqual(current_mode, .dark);
    try std.testing.expectEqual(bg.r, 0x00);
    try std.testing.expectEqual(text.r, 0xFF);

    // Toggle to light
    toggle();
    try std.testing.expectEqual(current_mode, .light);
    try std.testing.expectEqual(bg.r, 0xF5);
    try std.testing.expectEqual(text.r, 0x1A);

    // Toggle back to dark
    toggle();
    try std.testing.expectEqual(current_mode, .dark);
    try std.testing.expectEqual(bg.r, 0x00);
}

test "accent_colors_unchanged" {
    toggle(); // to light
    // Accents should be identical regardless of theme
    try std.testing.expectEqual(accents.green.g, 0xFA);
    try std.testing.expectEqual(accents.magenta.r, 0xF8);
    try std.testing.expectEqual(accents.logo_green.r, 0x08);
    toggle(); // back to dark
}
