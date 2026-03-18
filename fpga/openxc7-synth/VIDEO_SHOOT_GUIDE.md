# TRINITY V1 — Video Shoot Preparation Guide

## "Waiting for Cable" Video (30-60 seconds)

**Equipment Needed**:
- Camera (phone or DSLR)
- Tripod (optional but recommended)
- Good lighting (natural window light or softbox)
- QMTECH XC7A100T FPGA board
- Computer with terminal

---

## Shot List (Practical)

### Shot 1: Title Card (0:00-0:05)
**What to film**: Black screen with text overlay (add in post)

**Text to add**:
```
TRINITY V1 — FPGA EDITION
φ² + 1/φ² = 3 = TRINITY
VSA + BitNet + Quantum + UART
```

**Tips**:
- Keep it simple
- Font: JetBrains Mono or similar
- Fade in over 2 seconds

---

### Shot 2: Board Reveal (0:05-0:15)
**What to film**: QMTECH XC7A100T board

**Camera setup**:
- Position: Top-down or slight angle
- Distance: ~30cm from board
- Focus: Sharp on FPGA chip
- Background: Clean (table mat, plain surface)

**What we want to see**:
1. Board overview (full board visible)
2. LED D6 blinking (if flashed, otherwise mention it will blink)
3. Clock oscillator area
4. USB JTAG cable (if connected)

**Duration**: Pan slowly across board, ~10 seconds

**Overlay text** (add in post):
```
TARGET: QMTECH XC7A100T
FPGA: Artix-7 100T
RESOURCES: 0.1% (80 LUT + 50 FF)
```

---

### Shot 3: Terminal Demo (0:15-0:25)
**What to film**: Screen recording of terminal

**Before filming**:
1. Open terminal
2. Set font to JetBrains Mono 14pt
3. Set background to black, text to green
4. Resize window to 80×25 minimum

**What to run**:
```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth

# Quick demo (even if cable not connected)
./uart_host_v6                    # Show help
ls -lh trinity_v1.bit               # Show bitstream size
```

**If you have the cable**:
```bash
./trinity_first_run.sh              # Full test
```

**Duration**: 10 seconds of scrolling/commands

**Overlay text**:
```
COMMAND: 0x05 (BITNET)
PROMPT_ID: 42
TOKEN: '!' ← THE ANSWER
```

---

### Shot 4: LED Close-up (0:25-0:35)
**What to film**: Close-up of LED D6 (T23)

**Camera setup**:
- Distance: ~10cm from LED
- Focus: Sharp on LED
- Stability: Use tripod or rest phone on surface

**What to capture**:
1. LED in default mode (slow breathing/heartbeat)
2. Test different modes if cable available:
   - `./uart_host_v6 mode 0` → slow blink
   - `./uart_host_v6 mode 1` → chaotic flicker
   - `./uart_host_v6 mode 2` → medium pulse

**Duration**: 10 seconds, let LED behavior speak for itself

**Overlay text**:
```
LED T23 = STATUS INDICATOR
MODES: Separable | Violation | Zero | Negative
"I'M ALIVE" = Breathing pattern (waiting mode)
```

---

### Shot 5: Split Screen (0:35-0:45)
**What to film**: Board + Terminal side by side

**Setup options**:
A. Film board, then film terminal, combine in post
B. Position board next to monitor, film both together

**What to show**:
- Left: Board with LED blinking
- Right: Terminal showing `./uart_host_v6 ping` (or waiting message)

**Overlay text** (center):
```
⏳ ЖДЁМ UART КАБЕЛЬ ⏳
WAITING FOR CABLE
```

**Duration**: 10 seconds

---

### Shot 6: Architecture (0:45-0:55)
**What to create**: Animated diagram (create in software)

**Tools**:
- Keynote, PowerPoint, or similar
- Or draw on paper and film it
- Or use code-generated diagrams

**Content**:
```
┌─────────────────────────────┐
│  UART @ 115200 baud         │
│  ↓                           │
│  COMMAND DECODER (6 cmds)   │
│  ↓                           │
│  VSA ENGINE (16-trit)       │
│  ↓                           │
│  BITNET (prompt→token)       │
│  ↓                           │
│  LED CONTROLLER              │
└─────────────────────────────┘
```

**Animation**: Build up block by block, add labels

**Duration**: 10 seconds

---

### Shot 7: End Card (0:55-1:00)
**What to film**: Black screen with text (add in post)

**Text**:
```
КАБЕЛЬ СКОРО БУДЕТ
TRINITY V1 GOVORIT

github.com/gHashTag/trinity

φ² + 1/φ² = 3 = TRINITY
Cycle 124 — Ko Samui
```

**Duration**: 5 seconds

---

## Post-Production Guide

### Editing Software
- iMovie (free, macOS)
- DaVinci Resolve (free)
- Final Cut Pro (paid)
- Premiere Pro (paid)

### Effects to Add
1. **Text overlays** — Use box-drawing characters
2. **Transitions** — Hard cuts only (no fades)
3. **Color grading** — Slight warmth/teal tint
4. **Music** — Ambient electronic (free options: YouTube Audio Library)

### Export Settings
- Resolution: 1920×1080 (1080p)
- Frame rate: 30fps
- Format: MP4 (H.264)
- Bitrate: 8-10 Mbps
- Audio: AAC 192kbps

---

## Quick Checklist

Before filming:
- [ ] Board powered on
- [ ] LED is visible (room not too bright)
- [ ] Camera battery charged
- [ ] Terminal font set up correctly
- [ ] Script rehearsed

During filming:
- [ ] Keep camera steady
- [ ] Good lighting on board
- [ ] Capture LED clearly
- [ ] Terminal text is readable

After filming:
- [ ] Footage transferred to computer
- [ ] Backed up to cloud/storage
- [ ] Text overlays prepared
- [ ] Music selected

---

## Filming Tips

### Lighting
- Natural light from window (best: indirect, not direct)
- Or use desk lamp with white LED
- Avoid overhead shadows
- Board should be evenly lit

### Camera
- Use highest resolution available
- Enable grid if available (for level shots)
- Clean lens before filming
- Use manual focus if possible (lock focus)

### Audio
- No narration needed (text overlays + music only)
- If adding voiceover, record in quiet room
- Use microphone if available (phone mic is OK for demo)

### Background
- Clean table surface
- Remove clutter
- Plain background (wall, table mat, poster board)
- Neutral colors work best

---

## Alternative: Simulated Video (Without Cable)

If cable hasn't arrived yet, you can still make the video:

**Modifications**:
- Shot 2: Show board without LED active (explain in voiceover/text)
- Shot 3: Dry-run mode (terminal shows "DRY RUN" messages)
- Shot 4: Mention "LED will blink when flashed"
- Shot 5: Add "(SIMULATION)" to overlay

**Narration option**:
- Add voiceover explaining current status
- "Cable in transit, system ready for testing"
- Show preparation for when cable arrives

---

## Distribution

**Where to post**:
- GitHub: Release video with tag
- Twitter/X: Short clip with link
- YouTube: Full video with description
- Project README: Embed video

**Description template**:
```
TRINITY V1 — FPGA with VSA + BitNet + Quantum Violation

Status: PRODUCTION READY, waiting for UART cable
Hardware: QMTECH XC7A100T Artix-7 (0.1% resources used)
Features: UART console, VSA accelerator, Tiny BitNet, Quantum LED

Documentation: https://github.com/gHashTag/trinity
φ² + 1/φ² = 3 = TRINITY
```

---

**Made with sacred mathematics**
**φ² + 1/φ² = 3 = TRINITY**
