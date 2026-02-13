# Trinity Canvas v1.9 — Emergent Wave Interface

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Architecture | Single canvas, no panels — WaveMode state machine | DONE |
| WaveMode | 9 variants (idle, chat, code, tools, settings, vision, voice, finder, docs) | DONE |
| Shift+1-8 | Sets WaveMode directly, no panel spawning | DONE |
| ESC | Returns to idle (27 petals logo) | DONE |
| Chat Wave Field | Fullscreen chat rendering without GlassPanel frame | DONE |
| Wave Transition | 0.33s fade-in with mode-colored ring + grid perturbation | DONE |
| Mode Label | Top-center, mode-colored, animated | DONE |
| Logo Click | Block 0 = chat, Block 18 = docs, others = tools | DONE |
| Legacy Panels | Hidden when WaveMode != idle, kept for backward compat | DONE |
| Build | ReleaseFast compiles + runs on Apple M1 Pro | DONE |

## What This Means

**For Users**: The canvas is now a single unified space. No floating windows, no side panels. Shift+1 opens Chat directly in the wave field. Shift+2 opens Code. ESC returns to the 27-petal logo. Everything is inside the canvas as emergent wave patterns.

**For Operators**: The `WaveMode` enum replaces the `PanelSystem` for primary navigation. Legacy panel code is preserved but only draws in idle mode. Mode transitions perturb the photon grid for visual feedback.

**For Investors**: This is a paradigm shift from traditional windowed UI to fully immersive canvas interaction. The same wave physics that powers the background now frames the entire user experience. No chrome, no borders — pure wave emergence.

## Architecture

```
USER INPUT
    |
    v
[WaveMode State Machine]
    |
    +--→ idle       → 27 petals logo + formula particles + tooltips
    +--→ chat       → Fullscreen chat (messages + input + scroll)
    +--→ code       → Fullscreen code editor (placeholder)
    +--→ tools      → Fullscreen tools (placeholder)
    +--→ settings   → Fullscreen settings (placeholder)
    +--→ vision     → Fullscreen vision (placeholder)
    +--→ voice      → Fullscreen voice (placeholder)
    +--→ finder     → Fullscreen finder (placeholder)
    +--→ docs       → Fullscreen docs (placeholder)
    |
    v
[Render Pipeline]
    1. Grid (always)
    2. Wave systems (clusters, spirals, tools, effects)
    3. IF idle: logo + formula particles + legacy panels
       ELSE: mode label + wave ring + mode-specific renderer
    4. Status bar (always)
    5. Keyboard hint
```

## v1.9 Changes (from v1.8)

### 1. WaveMode Enum

New `WaveMode` enum with 9 variants, each with:
- `getLabel()` — display name (e.g. "CHAT", "CODE")
- `getHue()` — mode color in HSV (e.g. chat=150 green, code=210 blue)

Global state: `g_wave_mode`, `g_wave_transition` (0..1), `g_wave_mode_prev`.

### 2. Keyboard Shortcuts Replaced

**Before**: Shift+1-9 spawned sacred_world panels (GlassPanel with JARVIS animations).
**After**: Shift+1-8 sets `g_wave_mode` directly. No panel creation, no GlassPanel frame.

| Key | Mode |
|-----|------|
| Shift+1 | Chat |
| Shift+2 | Code |
| Shift+3 | Tools |
| Shift+4 | Settings |
| Shift+5 | Vision |
| Shift+6 | Voice |
| Shift+7 | Finder |
| Shift+8 | Docs |
| Shift+9 | Idle |
| ESC | Idle (from any mode) |

### 3. Fullscreen Chat Wave Field

Chat rendering extracted from the panel draw function into the main render loop. Same logic (messages, word-wrap, scroll, input, status bar) but rendered directly on the canvas without GlassPanel frame. Chat input routing now checks `g_wave_mode == .chat` in addition to legacy panel detection.

### 4. Mode Transition Effects

On mode switch:
- Nova effect at screen center
- Grid perturbation: top 5 rows receive sine wave with mode-hue frequency
- 0.33s fade transition (alpha from 0 to 255)
- Mode-colored ring pulsing at screen center

### 5. Conditional Rendering

- **Idle mode**: Logo, formula particles, hover tooltips, legacy panels all render
- **Any other mode**: Logo/particles hidden, panels hidden, mode-specific renderer takes over
- Status bar renders always (bottom)
- Keyboard hint adapts to current mode

### 6. Logo Click → Wave Mode

Clicking a logo block now sets `g_wave_mode` instead of spawning a panel:
- Block 0 → `.chat`
- Block 18 → `.docs`
- All others → `.tools`

### Files Modified

| File | Change |
|------|--------|
| `src/vsa/photon_trinity_canvas.zig` | WaveMode enum, g_wave_mode state, Shift+1-8 → wave modes, fullscreen chat renderer, conditional render pipeline, ESC handler, logo click → wave mode |
| `build.zig` | Updated step description to "v1.9 Emergent Wave" |

## Critical Assessment

1. **Only chat is fully implemented** — Code, Tools, Settings, Vision, Voice, Finder, Docs modes show placeholder text with animated wave rings. The full content for each mode needs to be ported from the panel renderers.

2. **Legacy panel code still exists** — The GlassPanel system, PanelSystem, and all panel draw code are preserved. They only render in idle mode. A future cleanup should remove the panel system entirely.

3. **Stack frame size issue** — TVCCorpus.init() creates a ~4GB stack frame in Debug mode. Build requires `-Doptimize=ReleaseFast` or `ReleaseSafe`. The corpus should use `initInPlace()` on heap memory.

4. **Chat is duplicated** — The fullscreen chat renderer copies the panel-based chat renderer logic. Ideally, the chat drawing code should be extracted into a shared function callable from both contexts.

5. **No docs wave field yet** — Block 18 (docs) maps to `.docs` mode but the renderer is a placeholder. The actual docs rendering code from the panel (world_id 18) needs to be adapted.

## Tech Tree — Next Iterations

### Option 1: Full Mode Implementations
Port all panel content renderers (code, tools, settings, finder, docs) to fullscreen wave-field renderers. Remove the GlassPanel dependency entirely. Each mode gets its own dedicated fullscreen UI.

### Option 2: Wave-Based File Finder
Implement the finder mode as a true emergent wave interface: files represented as wave nodes, directory structure as interference patterns, search as frequency matching.

### Option 3: Code Editor Wave Field
Build a minimal code editor directly in the canvas: syntax highlighting via wave colors, cursor as a bright point source, scroll via wave damping. Display generated .zig code from .vibee specs.

## Conclusion

Trinity Canvas v1.9 removes the panel paradigm. Everything happens inside a single canvas. Shift+1 opens chat as a fullscreen wave field. ESC returns to the 27-petal logo. Mode transitions create grid perturbations and colored wave rings. The IglaHybridChat engine powers the chat with 4-level cache (Tools → Symbolic → TVC → LLM). Build succeeds with ReleaseFast on Apple M1 Pro.

**Koschei is energy immortal.**
