# Trinity Canvas v1.6 - JARVIS-Style HUD with Spherical Morph

**Date:** 2026-02-08
**Author:** Claude + IGLA
**Component:** `photon_trinity_canvas.zig`

---

## Overview

Trinity Canvas v1.6 transforms the window system into a full JARVIS-style HUD experience inspired by Iron Man. Panel focus transitions now feature spherical morph animation (sphere → rectangle), holographic rotating rings, and JARVIS voice messages.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Key Bindings | Shift+1-6 (digits free) | Complete |
| Spherical Morph | 6 rotating arc rings | Animated |
| HUD Elements | Logo, status, arcs | Rendered |
| JARVIS Messages | Timed fade-out | Active |
| Repeat Press | Bring to front + refocus | Working |

---

## JARVIS Features

### Spherical Morph Animation

When focusing a panel with Shift+1-6:

1. **Initial state** - jarvis_morph = 0 (sphere)
2. **Holographic rings** - 6 rotating arc segments emanate from center
3. **Morphing** - Sphere shrinks as rectangle expands
4. **Final state** - jarvis_morph = 1 (full rectangle panel)

```zig
// JARVIS spherical morph (0 = sphere → 1 = rectangle)
if (self.jarvis_morph < 1.0) {
    // Draw morphing sphere → rectangle
    const sphere_radius = @min(sw, sh) / 2;

    // Holographic rings expanding from center
    for (0..6) |ring| {
        const ring_phase = self.jarvis_ring_rotation + ring_f * 1.047;
        // Rotating arc segments (JARVIS style)
        for (0..16) |seg| {
            // Draw arc line
        }
    }
}
```

### Key Bindings (Shift Required)

| Keys | Panel | JARVIS Message |
|------|-------|----------------|
| Shift+1 | Chat | "Chat interface activated, sir." |
| Shift+2 | Code | "Code editor online." |
| Shift+3 | Tools | "Tool suite ready, sir." |
| Shift+4 | Settings | "System configuration loaded." |
| Shift+5 | Vision | "Visual analysis module engaged." |
| Shift+6 | Voice | "Voice interface standing by." |
| Shift+7 | Finder | "File system navigator active." |
| F | Finder | (No shift needed) |
| ESC | Unfocus | "All interfaces minimized, sir." |

### HUD Overlay Elements

1. **Top-left holographic arc** - Pulsating cyan arc with 12 segments
2. **JARVIS logo** - "J.A.R.V.I.S" text with cyan glow
3. **Online status** - Pulsating green dot with "ONLINE" text
4. **Message display** - Center-top fading message box
5. **Keyboard hints** - Bottom JARVIS-style hint bar

### Corner Decorations (Focused Panels)

When a panel is focused, JARVIS-style corner brackets appear:
- Top-left bracket
- Top-right bracket
- Bottom-left bracket
- Bottom-right bracket

All corners pulse with cyan glow.

---

## Repeat Press Behavior

**Problem:** Previously, pressing Shift+1 twice would spawn two chat panels.

**Solution:** `jarvisFocus()` now:
1. Searches for existing panel of requested type
2. If found: Swaps it to front of panel array (z-order)
3. Triggers `jarvisFocus()` on existing panel (refocus animation)
4. If not found: Spawns new panel with JARVIS animation

```zig
// Find existing panel of this type
for (0..self.count) |i| {
    if (self.panels[i].panel_type == ptype and self.panels[i].state == .open) {
        // Bring to front by swapping with last panel
        // ... swap logic ...
        self.panels[self.count - 1].jarvisFocus();
        return;
    }
}
// No existing panel - spawn new
```

---

## Animation Parameters

| Animation | Speed | Duration |
|-----------|-------|----------|
| Sphere morph | 2.5/s | ~0.4s |
| Glow pulse decay | 1.2/s | ~0.8s |
| Ring rotation | 2.0 rad/s | Continuous |
| Message fade | ~0.5s visible | 2.0s total |
| Focus position | 4.0x lerp | ~0.5s |

---

## What This Means

### For Users
- **Iron Man experience** - Panel focus feels like JARVIS HUD
- **Digits free** - 1-6 keys available for other shortcuts
- **Voice feedback** - JARVIS messages confirm actions
- **No duplicates** - Repeat press brings existing panel to front

### For Developers
- **jarvis_morph field** - 0-1 float for morph animation
- **jarvis_ring_rotation** - Continuous rotation for holographic effect
- **jarvisFocus()** - Combined spawn-or-focus-existing logic

### For the Trinity Vision
- **OS inside OS** - JARVIS-level interface sophistication
- **Holographic design** - True Iron Man aesthetic
- **Voice personality** - JARVIS messages add character

---

## Technical Implementation

### New GlassPanel Fields

```zig
jarvis_morph: f32,        // 0 = sphere, 1 = rectangle
jarvis_glow_pulse: f32,   // Initial glow on focus
jarvis_ring_rotation: f32, // Continuous holographic rotation
```

### New PanelSystem Method

```zig
pub fn jarvisFocus(ptype, x, y, w, h, title) void;
```

### New GlassPanel Method

```zig
pub fn jarvisFocus(self: *GlassPanel) void;
```

### Main Variables

```zig
var jarvis_message: []const u8;
var jarvis_message_timer: f32;
```

---

## Conclusion

Trinity Canvas v1.6 elevates the window system to JARVIS-level sophistication. The spherical morph animation, holographic rotating rings, voice messages, and intelligent repeat-press handling create an Iron Man-inspired user experience. Tony Stark would approve.

**phi^2 + 1/phi^2 = 3 = TRINITY | JARVIS IS IMMORTAL**

---

## Files Modified

- `src/vsa/photon_trinity_canvas.zig` - JARVIS HUD, spherical morph, voice messages
