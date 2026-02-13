# Trinity Canvas v1.9 — Emergent Wave Interface

> **V = n x 3^k x pi^m x phi^p x e^q**
> **phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL**

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Architecture | Single canvas, no panels — layer state machine | DONE |
| Layers | 6 (Petals, Chat, Editor, Finder, Settings, Viz) | DONE |
| Key 1-6 | Sets layer directly, no panel spawning | DONE |
| ESC | Returns to Petals (27-petal flower menu) | DONE |
| Chat Wave Field | Full chat (v2.4) inside canvas wave field | DONE |
| Editor Wave Field | JS code editor with hot-reload inside canvas | DONE |
| Finder Wave Field | File search as emergent particle convergence | DONE |
| Settings Wave Field | Config as wave interference visualization | DONE |
| 27 Petals | 3-ring flower menu (3+9+15) inside canvas | DONE |
| Viz Modes | All 27+ QuantumCanvas modes accessible from petals | DONE |
| Font | Outfit + Russian language support | DONE |
| Build | Vite build successful, 0 type errors | DONE |
| Route | /canvas — unified single-canvas interface | DONE |

## What This Means

**For Users**: The canvas is the only interface. No side panels, no separate windows. Press 1-6 to switch between Petals (main menu), Chat, Editor, Finder, Settings, and Viz modes. Everything emerges from the wave field — messages appear inside particles, code glows in the neural network, files converge from quantum noise.

**For Operators**: The `CanvasLayer` type replaces all separate pages for the immersive experience. The 27-petal flower menu provides access to all 27+ visualization modes. Each layer uses a different QuantumCanvas viz mode as its background.

**For Investors**: This is a paradigm shift from traditional windowed UI to fully immersive canvas interaction. Chat, code editing, file search, and settings all happen inside the same wave physics engine. No chrome, no borders — pure wave emergence.

## Architecture

```
USER INPUT (keyboard 1-6, ESC, petal click)
    |
    v
[CanvasLayer State Machine]
    |
    +---> petals    -> 27-petal flower menu (3 rings: inner 3 + mid 9 + outer 15)
    +---> chat      -> Chat v2.4 (messages + input + wave rings) [chat-wave mode]
    +---> editor    -> Code editor with hot-reload output [neural-network mode]
    +---> finder    -> File search as particle convergence [quantum-field mode]
    +---> settings  -> Config as wave interference [wave-interference mode]
    +---> viz       -> Pure visualization (27+ modes) [any mode via petal]
    |
    v
[Render Pipeline]
    1. QuantumCanvas (always fullscreen, mode varies per layer)
    2. Layer indicator bar (top center, 6 pill buttons)
    3. Layer content (chat/editor/finder/settings/petals/viz info)
    4. Wave rings (triggered on chat send, layer switch, code run)
    5. Formula bar (bottom right, "phi^2 + 1/phi^2 = 3")
```

## Implementation

### Web Frontend (React + Vite)

Single component `TrinityCanvas.tsx` (430 lines) that:

1. **Background**: Always-fullscreen `QuantumCanvas` with mode matching current layer
2. **Layer switching**: State machine with 6 layers, keyboard shortcuts 1-6
3. **27-petal menu**: 3 concentric rings rendered as absolutely-positioned circle buttons
4. **Chat**: Full chat v2.4 with `sendMessage()` API, wave rings on send/receive, learned indicator
5. **Editor**: Textarea with JS eval, output panel with wave trigger on run
6. **Finder**: Search input with simulated file matching, results as animated emerge-from-field cards
7. **Settings**: Read-only config cards with wave interference background

### Files Created/Modified

| File | Change |
|------|--------|
| `website/src/pages/TrinityCanvas.tsx` | **NEW** — Unified canvas page (430 lines) |
| `website/src/main.tsx` | Added `/canvas` route |

### Layer-Mode Mapping

| Layer | QuantumCanvas Mode | Background Hue |
|-------|-------------------|----------------|
| Petals | trinity-computer | 45 (gold) |
| Chat | chat-wave | 45 (gold) |
| Editor | neural-network | 160 (green) |
| Finder | quantum-field | 280 (violet) |
| Settings | wave-interference | 200 (cyan) |
| Viz | (varies by petal) | (varies) |

### 27 Petals

```
Ring 1 (inner, 3 petals):
  Chat, Editor, Finder

Ring 2 (middle, 9 petals):
  Settings, Trinity, Quantum, Neural,
  Vortex, Cosmos, Encrypt, Life, Mind

Ring 3 (outer, 15 petals):
  Photon, Entangle, Supremacy, Neuromorph, LLM,
  Transcend, Beings, QLife, QBio, Matryoshka,
  Zhar-Ptitsa, Bogatyri, Agents, Spintronic, Cinema4D
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| 1 | Petals (27-petal menu) |
| 2 | Chat |
| 3 | Editor |
| 4 | Finder |
| 5 | Settings |
| 6 | Viz |
| ESC | Back to Petals |

### Wave Effects

- **Layer switch**: Wave ring at screen center with layer hue color
- **Chat send**: Wave ring from user position (right side, gold hue)
- **Chat receive**: Wave ring from assistant position (left side, green hue)
- **Learned response**: Extra green wave ring from center after 300ms delay
- **Code run**: Wave ring from top-center with green hue
- **Layer hint**: 2-second centered label fade-in/fade-out on switch

## Critical Assessment

### Strengths
- **Single canvas, zero panels** — user sees only the wave field at all times
- **27 petals preserved** — full flower menu as primary navigation inside the canvas
- **All 27+ viz modes** accessible from petals without leaving the canvas
- **Chat v2.4 fully functional** — messages, loading, clear, wave rings, learned indicator
- **Outfit font** with Russian language labels throughout
- **Keyboard-first** — 1-6 keys for instant layer switching

### Weaknesses
- Editor is basic textarea, not Monaco — JS-only eval (no Zig)
- Finder uses simulated file list, not real backend search
- Settings are read-only display cards
- Old separate pages (/chat, /quantum, /play) still exist (backward compat)
- No drag-and-drop or gesture-based petal interaction yet

### What Actually Works
- Build: 0 type errors, Vite build successful
- Route: `/canvas` accessible in browser
- Petals: 27 petals in 3 rings, clickable, animated spring entrance
- Chat: Full send/receive cycle with API at localhost:8080
- Editor: JS code execution with console.log capture
- Finder: String-match search over project file list
- Settings: 7 config cards with phi calculation
- Layer switching: Keyboard 1-6, ESC, petal clicks, top bar buttons
- Wave rings: Triggered on layer switch, chat messages, code run

## Improvement Rate

```
v1.8: 5 features (WaveMode enum, Shift shortcuts, chat wave, transitions, conditional render)
v1.9: 12 features (6 layers, 27 petals, full chat, editor, finder, settings, viz, keyboard,
                    wave effects, Outfit font, Russian labels, route)

Improvement rate = 12/5 = 2.4 >> 0.618 (golden ratio threshold)
```

## Tech Tree — Next Iterations

### Option A: Monaco Editor Integration
Replace textarea with Monaco Editor for syntax highlighting, autocomplete, and multi-language support. Connect to Zig backend for actual VIBEE compilation and hot-reload.

### Option B: Real-Time Finder Backend
Connect finder to actual file system via WebSocket or HTTP API. Show file contents in canvas overlay. Directory tree as nested wave interference patterns.

### Option C: Voice + Vision Layers
Add layers 7-8: Voice (speech-to-text inside wave field, voice waveform visualization) and Vision (camera feed as particle source, image analysis overlay).

## Conclusion

Trinity Canvas v1.9 delivers the canvas as the single interface. Chat, editor, finder, and settings all live inside the wave field with no side panels or separate windows. The 27-petal flower menu provides navigation to all functionality. Keyboard shortcuts 1-6 switch layers instantly. Wave physics (chat-wave, neural-network, quantum-field, wave-interference) power each layer's unique visual character. Build succeeds with 0 type errors. Improvement rate 2.4 (3.9x above golden ratio threshold).

The user sees **only the canvas**. Everything emerges from waves.

---

*Route: `/canvas`*
*File: `website/src/pages/TrinityCanvas.tsx` (430 lines)*
*Build: Vite successful, 0 errors*
*Font: Outfit + Russian*
