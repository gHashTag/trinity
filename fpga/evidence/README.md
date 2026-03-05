# FPGA Visual Test Evidence

This folder contains photos and metadata from FPGA hardware testing sessions.

---

## File Format

Evidence consists of pairs:
- `<design>_<variant>_<timestamp>.jpg` - Photo
- `<design>_<variant>_<timestamp>.txt` - Metadata

### Example

```
led_on_forge_fix_20260304.jpg     # Photo
led_on_forge_fix_20260304.txt     # Metadata
```

---

## Metadata Template

When creating new evidence, use this format:

```text
FPGA Visual Test Evidence
=========================
Date:       YYYY-MM-DD HH:MM:SS
Design:     <design_name>
Board:      QMTECH Artix-7 XC7A100T-1FGG676C
Camera:     Device [<id>] (<description>)
Photo:      <photo_filename>
Git commit: <commit_hash>
Git branch: <branch_name>

Expected:
  - LED D6: <expected_state>
  - LED D5: <expected_state>
  - Other LEDs: <expected_state>

Actual:
  - LED D6: <actual_state>
  - LED D5: <actual_state>
  - Other LEDs: <actual_state>

Result: <PASS|FAIL>

Notes:
  <Additional observations>
```

### Example Entry

```text
FPGA Visual Test Evidence
=========================
Date:       2026-03-04 14:29:00
Design:     led_on
Board:      QMTECH Artix-7 XC7A100T-1FGG676C
Camera:     Device [2] (iPhone Continuity Camera)
Photo:      led_on_forge_fix_20260304.jpg
Git commit: f52bba80c
Git branch: main

Expected:
  - LED D6: ON
  - LED D5: OFF
  - Other LEDs: OFF

Actual:
  - LED D6: ON ✓
  - LED D5: OFF ✓
  - Other LEDs: OFF ✓

Result: PASS

Notes:
  First successful LED test after FORGE fix.
  Board powered via USB from Platform Cable.
  Photo taken under normal office lighting.
```

---

## Photo Guidelines

### Composition

- **Include entire board** in frame
- **LEDs clearly visible** (not overexposed)
- **Focus sharp** (use macro mode if available)
- **Neutral background** (avoid clutter)

### Lighting

- **Indirect lighting** preferred (no glare)
- **Avoid direct flash** (can wash out LEDs)
- **Consistent lighting** across sessions (for comparison)

### Naming Convention

```
<design>_<variant>_<timestamp>.jpg
```

| Component | Example | Description |
|-----------|---------|-------------|
| design | `led_on` | Design being tested |
| variant | `forge_fix` | Specific build/variant |
| timestamp | `20260304` | YYYYMMDD format |

### Variants

Common variant suffixes:
- `forge_fix` - After FORGE toolchain fix
- `closeup` - Close-up photo for detail
- `dark` - Low-light condition test
- `comparison` - Side-by-side comparison

---

## Existing Evidence

| Date | Design | Result | Photo |
|------|--------|--------|-------|
| 2026-03-04 | led_on | PASS | led_on_forge_fix_20260304.jpg |
| 2026-03-04 | led_on | PASS | led_on_forge_fix_closeup_20260304.jpg |

---

## Creating New Evidence

### Using test_with_camera.sh

```bash
# Full pipeline (auto-generates evidence)
./fpga/test_with_camera.sh --design <name>

# Photo only (manual metadata)
./fpga/test_with_camera.sh --photo-only
```

### Manual Process

```bash
# 1. Capture photo
./fpga/tools/cam_snapshot.sh /tmp/board.jpg

# 2. Copy to evidence folder
DESIGN="my_test"
TIMESTAMP=$(date +%Y%m%d)
cp /tmp/board.jpg "fpga/evidence/${DESIGN}_${TIMESTAMP}.jpg"

# 3. Create metadata file
cat > "fpga/evidence/${DESIGN}_${TIMESTAMP}.txt" << 'EOF'
FPGA Visual Test Evidence
...
EOF
```

---

## Analysis Guidelines

### Visual Inspection

1. **Identify board** - Confirm correct FPGA model
2. **Check LEDs** - Note which are lit/unlit
3. **Check orientation** - Verify pin locations
4. **Look for issues** - Burn marks, damage, etc.

### Documentation

Always document:
- What you expected to see
- What you actually saw
- Any discrepancies
- Environmental conditions (lighting, etc.)

---

## φ² + 1/φ² = 3 = TRINITY
