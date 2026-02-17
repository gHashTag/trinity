// =============================================================================
// TRINITY NEXUS -- Canvas Module (trinity-canvas)
// Photon visualization engine, Trinity Canvas, UI framework
// =============================================================================
// Migrated from src/vsa/, src/vsa/trinity_canvas/, src/vibeec/, src/trinity_node/
// 26 files, 20910 lines -- Photon engine + Canvas subsystem + UI framework
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");

pub const VERSION = "0.1.0";
pub const MODULE = "trinity-canvas";

// --- Photon Engine --------------------------------------------------------
pub const photon = @import("photon.zig");
pub const wave_scroll = @import("wave_scroll.zig");
pub const world_dots = @import("world_dots.zig");
pub const photon_demo = @import("photon_demo.zig");
pub const photon_immersive = @import("photon_immersive.zig");
pub const photon_terminal = @import("photon_terminal.zig");

// --- Trinity Canvas Subsystem ---------------------------------------------
pub const theme = @import("trinity_canvas/theme.zig");
pub const panel = @import("trinity_canvas/panel.zig");
pub const panel_system = @import("trinity_canvas/panel_system.zig");
pub const sacred_worlds = @import("trinity_canvas/sacred_worlds.zig");
pub const canvas_types = @import("trinity_canvas/types.zig");
pub const canvas_main = @import("trinity_canvas/main.zig");
pub const world_docs = @import("trinity_canvas/world_docs.zig");

// --- UI Framework ---------------------------------------------------------
pub const trinity_ui = @import("trinity_ui.zig");
pub const trinity_raylib_ui = @import("trinity_raylib_ui.zig");
pub const claude_ui = @import("claude_ui.zig");

// --- Deferred (external pkg deps, wired in NEXUS-008) ---------------------
// pub const photon_trinity_canvas = @import("photon_trinity_canvas.zig");
// pub const photon_wasm = @import("photon_trinity_canvas_wasm.zig");
// pub const ralph_loop = @import("ralph_loop.zig");
// pub const node_ui = @import("node_ui.zig");
// pub const main_gui = @import("main_gui.zig");

// --- Re-exported types ----------------------------------------------------
pub const Photon = photon.Photon;
pub const Color = theme.Color;

test {
    // Photon engine (self-contained, std-only)
    _ = photon;
    _ = wave_scroll;
    _ = world_dots;
    _ = photon_demo;
    _ = photon_immersive;
    _ = photon_terminal;

    // Trinity Canvas subsystem
    _ = theme;
    _ = panel;
    _ = panel_system;
    _ = sacred_worlds;
    _ = canvas_types;
    _ = canvas_main;

    // UI framework
    _ = trinity_ui;
    _ = trinity_raylib_ui;
    _ = claude_ui;
}

test "trinity-canvas module identity" {
    try std.testing.expectEqualStrings("trinity-canvas", MODULE);
    try std.testing.expectEqualStrings("0.1.0", VERSION);
}

test "trinity-canvas photon available" {
    const P = photon.Photon;
    _ = P;
}

test "trinity-canvas theme available" {
    const C = theme.Color;
    _ = C;
}
