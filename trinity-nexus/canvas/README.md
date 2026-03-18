# trinity-canvas

**Visualization Module** — Photon engine, Trinity Canvas, UI framework

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

`trinity-canvas` provides **visualization and UI capabilities**:

- **Photon Engine** — Real-time visualization engine
- **Trinity Canvas** — Interactive canvas system
- **Theme System** — Sacred color palette
- **Panel System** — Modular UI components
- **UI Framework** — Cross-platform UI toolkit

---

## Quick Start

```zig
const canvas = @import("trinity-canvas");

// Initialize Photon engine
var photon = try canvas.photon.Photon.init(allocator, .{
    .width = 1920,
    .height = 1080,
    .title = "Trinity Canvas",
});
defer photon.deinit(allocator);

// Start render loop
while (!photon.shouldClose()) {
    try photon.beginFrame();
    try photon.clear(canvas.theme.Color.sacred_black);
    // ... rendering
    try photon.endFrame();
}
```

---

## Module Structure

```
trinity-nexus/canvas/src/
├── root.zig                    # Module exports
│
├── Photon Engine
├── photon.zig                  # Photon engine core
├── wave_scroll.zig             # Wave scroll effect
├── world_dots.zig              # World dots visualization
├── photon_demo.zig             # Demo programs
├── photon_immersive.zig        # Immersive mode
└── photon_terminal.zig         # Terminal renderer
│
├── Trinity Canvas Subsystem
├── trinity_canvas/
│   ├── theme.zig               # Sacred color system
│   ├── panel.zig               # Panel component
│   ├── panel_system.zig        # Panel manager
│   ├── sacred_worlds.zig       # Sacred worlds
│   ├── types.zig               # Canvas types
│   ├── main.zig                # Canvas main
│   └── world_docs.zig          # World documentation
│
└── UI Framework
├── trinity_ui.zig              # Core UI framework
├── trinity_raylib_ui.zig       # Raylib-based UI
└── claude_ui.zig               # Claude UI components
```

---

## API Reference

### Photon Engine

```zig
pub const Photon = struct {
    pub fn init(allocator: Allocator, config: Config) !Photon
    pub fn deinit(self: *Photon, allocator: Allocator) void

    pub fn beginFrame(self: *Photon) !void
    pub fn endFrame(self: *Photon) !void
    pub fn clear(self: *Photon, color: Color) !void

    pub fn drawCircle(self: *Photon, center: Point, radius: f32, color: Color) !void
    pub fn drawRect(self: *Photon, rect: Rect, color: Color) !void
    pub fn drawText(self: *Photon, text: []const u8, pos: Point, color: Color) !void

    pub fn shouldClose(self: *Photon) bool
};
```

### Theme System

```zig
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color
    pub fn fromHex(hex: u32) Color
};

pub const sacred_palette = struct {
    pub const sacred_black = Color.rgb(0, 0, 0);
    pub const sacred_white = Color.rgb(255, 255, 255);
    pub const phi_gold = Color.rgb(255, 215, 0);
    pub const trinity_cyan = Color.rgb(0, 204, 255);
    pub const spirit_purple = Color.rgb(170, 102, 255);
};
```

### Panel System

```zig
pub const Panel = struct {
    id: []const u8,
    bounds: Rect,
    children: []Panel,
    visible: bool,

    pub fn init(id: []const u8, bounds: Rect) Panel
    pub fn addChild(self: *Panel, child: Panel) !void
    pub fn draw(self: *Panel, photon: *Photon) !void
};

pub const PanelSystem = struct {
    root: Panel,
    focused: ?*Panel,

    pub fn init(allocator: Allocator) !PanelSystem
    pub fn deinit(self: *PanelSystem, allocator: Allocator) void
    pub fn update(self: *PanelSystem, dt: f32) !void
    pub fn draw(self: *PanelSystem, photon: *Photon) !void
};
```

---

## Examples

### Basic Photon Window

```zig
const canvas = @import("trinity-canvas");

var photon = try canvas.photon.Photon.init(allocator, .{
    .width = 800,
    .height = 600,
    .title = "Hello Photon",
});
defer photon.deinit(allocator);

while (!photon.shouldClose()) {
    try photon.beginFrame();
    defer photon.endFrame();

    try photon.clear(canvas.theme.Color.sacred_black);

    // Draw golden circle
    try photon.drawCircle(
        .{ .x = 400, .y = 300 },
        100,
        canvas.theme.sacred_palette.phi_gold
    );
}
```

### Panel Layout

```zig
const canvas = @import("trinity-canvas");

var root = canvas.panel.Panel.init(
    "root",
    canvas.types.Rect{ .x = 0, .y = 0, .w = 1920, .h = 1080 }
);

var left_panel = canvas.panel.Panel.init(
    "left",
    canvas.types.Rect{ .x = 0, .y = 0, .w = 640, .h = 1080 }
);

var right_panel = canvas.panel.Panel.init(
    "right",
    canvas.types.Rect{ .x = 640, .y = 0, .w = 1280, .h = 1080 }
);

try root.addChild(left_panel);
try root.addChild(right_panel);

var system = try canvas.panel_system.PanelSystem.init(allocator);
defer system.deinit(allocator);
system.root = root;
```

### Sacred Worlds

```zig
const canvas = @import("trinity-canvas");

// Create a sacred world
var world = try canvas.sacred_worlds.World.init(allocator, "Trinity");
defer world.deinit(allocator);

// Add sacred geometry
try world.addPattern(.spiral, .{
    .center = .{ .x = 0, .y = 0 },
    .radius = 100,
    .rotations = 13,
    .color = canvas.theme.sacred_palette.phi_gold,
});

// Render to photon
try world.renderTo(&photon);
```

---

## Theme System

### Sacred Colors

| Color Name | RGB | Hex | Meaning |
|------------|-----|-----|---------|
| sacred_black | 0,0,0 | #000000 | Void, potential |
| sacred_white | 255,255,255 | #FFFFFF | Light, truth |
| phi_gold | 255,215,0 | #FFD700 | Golden ratio φ |
| trinity_cyan | 0,204,255 | #00CCFF | Matter realm |
| spirit_purple | 170,102,255 | #AA66FF | Spirit realm |
| razim_gold | 255,215,0 | #FFD700 | Mind realm |

### Glass Effect

```zig
pub fn glassStyle(color: Color, alpha: f32) Color {
    return Color.rgba(
        color.r,
        color.g,
        color.b,
        @intFromFloat(alpha * 255)
    );
}
```

---

## Performance

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Clear screen | O(1) | GPU accelerated |
| Draw circle | O(r) | r = radius |
| Draw text | O(n) | n = characters |
| Panel update | O(d) | d = tree depth |
| Full frame | O(n) | n = drawables |

---

## Build & Test

```bash
# From workspace root
cd trinity-nexus

# Build canvas library
zig build trinity-canvas

# Run canvas tests
zig build test-canvas

# Run photon demo
zig build trinity-canvas -- demo
```

---

## Dependencies

- **trinity-core** — VSA operations, core types

---

## Rendering Pipeline

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Input      │────▶│   Update     │────▶│   Render     │
│  (Events)    │     │   (Logic)    │     │  (Photon)    │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   Panel      │
                     │   System     │
                     └──────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
    ┌──────────┐     ┌──────────┐     ┌──────────┐
    │   Left   │     │  Center  │     │  Right   │
    │  Panel   │     │  Panel   │     │  Panel   │
    └──────────┘     └──────────┘     └──────────┘
```

---

## Version

```
trinity-canvas v0.1.0
```

---

**φ² + 1/phi² = 3**
