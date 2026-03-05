# Terminal Video Capture Guide — TRINITY V1 Demo

## Quick Setup (5 minutes)

### Step 1: Terminal Configuration

**macOS (iTerm2 / Terminal.app)**:
```bash
# Set a hacker-friendly theme
# Preferences → Profiles → Colors → Preset → "Basic" or "Solarized Dark"

# Set font to JetBrains Mono or Fira Code (14pt)
# Preferences → Profiles → Text → Font → JetBrains Mono 14pt
```

**Linux (gnome-terminal)**:
```bash
# Install hacker fonts
sudo apt install fonts-jetbrains-mono

# Set profile preferences:
# Edit → Preferences → Profiles → Colors → Built-in schemes → Dark
# Text → Uncheck "Use the system fixed width font"
# → Select "JetBrains Mono Regular" 14
```

**Key Settings**:
| Setting | Value | Why |
|---------|-------|-----|
| Font | JetBrains Mono 14pt | Monospace, readable |
| Background | Black (#000000) | High contrast |
| Text | Green (#00FF00) | Classic terminal |
| Cursor | Block | Retro aesthetic |
| Transparency | 0% | Clean recording |

---

### Step 2: Terminal Recording

**Option A: macOS Screen Recording (Built-in)**

```bash
# Method 1: QuickTime Player
open -a "QuickTime Player"

# In QuickTime: File → New Screen Recording
# Click record arrow → Select window → Record
# Shortcut: Cmd+Shift+5 (modern macOS)

# Method 2: Built-in screenshot tool (macOS Mojave+)
Cmd+Shift+5 → Select "Record Selected Portion"
```

**Option B: asciinema (Cross-platform)**

```bash
# Install
brew install asciinema  # macOS
# OR
sudo apt install asciinema  # Linux

# Record terminal session
asciinema rec trinity_demo.cast

# Run your demo
./uart_host_v6 ping
./uart_host_v6 bind
./uart_host_v6 run-model 42

# Stop recording: Ctrl+D
# Upload to asciinema.org (optional)
asciinema upload trinity_demo.cast
```

**Option C: OBS Studio (Professional)**

```bash
# Install
brew install obs  # macOS
# OR
sudo apt install obs-studio  # Linux

# Setup in OBS:
# 1. Sources → + → Window Capture
# 2. Properties → Select [Terminal]
# 3. Audio: Disable (no narration needed)
# 4. Canvas Resolution: 1920×1080
# 5. Output Resolution: 1920×1080
# 6. FPS: 30
# 7. Start Recording
```

---

### Step 3: Demo Script (Copy-Paste)

**Setup**:
```bash
# Navigate to project
cd /Users/playra/trinity-w1/fpga/openxc7-synth

# Clear screen for clean start
clear

# Show Trinity banner
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY V1 — FPGA EDITION                                                ║"
echo "║  φ² + 1/φ² = 3 = TRINITY                                                  ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
```

**Demo Commands**:
```bash
# 1. Show bitstream
echo "=== BITSTREAM ==="
ls -lh trinity_v1.bit
echo ""

# 2. Show host binary
echo "=== HOST BINARY ==="
ls -lh uart_host_v6
echo ""

# 3. PING test
echo "=== UART PING ==="
./uart_host_v6 ping
echo ""

# 4. VSA BIND operation
echo "=== VSA BIND ==="
./uart_host_v6 bind
echo ""

# 5. VSA BUNDLE operation
echo "=== VSA BUNDLE ==="
./uart_host_v6 bundle
echo ""

# 6. VSA SIMILARITY
echo "=== VSA SIMILARITY ==="
./uart_host_v6 similarity
echo ""

# 7. BitNet Inference
echo "=== BITNET INFERENCE ==="
./uart_host_v6 run-model 42
echo ""

# 8. LED modes
echo "=== LED MODES ==="
./uart_host_v6 mode 0
sleep 2
./uart_host_v6 mode 1
echo ""

# 9. Benchmark
echo "=== BENCHMARK ==="
./uart_host_v6 benchmark
echo ""

# 10. Done
echo "=== TRINITY V1 OPERATIONAL ==="
```

---

### Step 4: Post-Production Overlays

**Text Overlay Template** (use your video editor):

| Time (0:00-0:30) | Text | Position |
|------------------|------|----------|
| 0:00-0:05 | `TRINITY V1` | Center top |
| 0:05-0:10 | `UART @ 115200 baud` | Left bottom |
| 0:10-0:20 | `VSA Operations` | Right bottom |
| 0:20-0:25 | `BitNet Inference` | Center bottom |
| 0:25-0:30 | `φ² + 1/φ² = 3` | Center |

**Font Recommendations**:
- Main text: JetBrains Mono, Fira Code, or Source Code Pro
- Styling: Green text on black background
- Size: 48-72px for 1080p

---

## Recording Checklist

Before recording:
- [ ] Terminal font set to JetBrains Mono 14pt
- [ ] Black background, green text
- [ ] Window sized to 80×25 or larger
- [ ] All commands tested (dry run OK)
- [ ] Script rehearsed (type at comfortable pace)
- [ ] Microphone disabled (no audio needed)

During recording:
- [ ] Camera/screen steady (no shaky movements)
- [ ] Typing visible (hands in frame if filming yourself)
- [ ] Commands execute successfully
- [ ] Errors handled gracefully (continue if one fails)

After recording:
- [ ] Footage backed up
- [ ] Text overlays added
- [ ] Export at 1080p, 30fps, H.264

---

## Quick Commands for Testing

```bash
# Dry run mode (without cable)
./uart_host_v6 ping  # Should show "DRY RUN" or timeout

# With cable (after it arrives)
./uart_host_v6 ping           # → PONG
./uart_host_v6 bind           # → PASS
./uart_host_v6 bundle         # → PASS
./uart_host_v6 similarity     # → score 0-255
./uart_host_v6 run-model 42   # → Token '!'
./uart_host_v6 mode 0         # → LED slow blink

# Full test suite
./trinity_first_run.sh
```

---

## Troubleshooting

**Issue**: Terminal text too small in video
**Fix**: Increase font size to 18pt or 20pt before recording

**Issue**: Screen recording is blurry
**Fix**: Use OBS at 1920×1080, export at high bitrate (10+ Mbps)

**Issue**: Commands fail (no cable)
**Fix**: Add "DRY RUN MODE" text overlay in post

**Issue**: Can't type fast enough
**Fix**: Pre-type commands in text editor, copy-paste during recording

---

## Export Settings (Final Video)

| Setting | Value |
|---------|-------|
| Resolution | 1920×1080 (1080p) |
| Frame Rate | 30 fps |
| Format | MP4 (H.264) |
| Bitrate | 8-10 Mbps |
| Audio | None (or add music in post) |
| Color | YUV 4:2:0 |

---

**φ² + 1/φ² = 3 = TRINITY**

**Made with sacred mathematics**
