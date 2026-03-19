#!/bin/bash
# HSLM — TinyStories Dataset Preparation
# Downloads, extracts, and converts TinyStories for HSLM training
# Source: https://huggingface.co/datasets/roneneldan/TinyStories
# phi^2 + 1/phi^2 = 3 = TRINITY

set -e

DATA_DIR="data/tinystories"
ARCHIVE="TinyStories_all_data.tar.gz"
URL="https://huggingface.co/datasets/roneneldan/TinyStories/resolve/main/$ARCHIVE"

echo "================================================================"
echo "  HSLM — TinyStories Dataset Preparation"
echo "  2M+ stories, ~1500 word vocabulary"
echo "  Perfect for 1M-param ternary language models"
echo "================================================================"
echo ""

mkdir -p "$DATA_DIR"

# Step 1: Download
if [ -f "$DATA_DIR/$ARCHIVE" ]; then
    echo "[OK] Archive already downloaded: $DATA_DIR/$ARCHIVE"
else
    echo "[1/4] Downloading TinyStories (~500MB)..."
    echo "      URL: $URL"
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$DATA_DIR/$ARCHIVE" "$URL"
    elif command -v wget &> /dev/null; then
        wget --show-progress -O "$DATA_DIR/$ARCHIVE" "$URL"
    else
        echo "[ERROR] Neither curl nor wget available"
        exit 1
    fi
    echo "[OK] Downloaded"
fi

# Step 2: Extract
if [ -d "$DATA_DIR/raw" ] && [ "$(ls -A $DATA_DIR/raw/*.json 2>/dev/null | head -1)" ]; then
    echo "[OK] Already extracted to $DATA_DIR/raw/"
else
    echo "[2/4] Extracting archive..."
    mkdir -p "$DATA_DIR/raw"
    tar -xzf "$DATA_DIR/$ARCHIVE" -C "$DATA_DIR/raw"
    echo "[OK] Extracted"
fi

# Step 3: Convert JSON to plain text (one story per line)
if [ -f "$DATA_DIR/train.txt" ]; then
    LINES=$(wc -l < "$DATA_DIR/train.txt" | tr -d ' ')
    echo "[OK] train.txt already exists ($LINES stories)"
else
    echo "[3/4] Converting JSON to plain text..."
    python3 -c "
import json, glob, sys

out = open('$DATA_DIR/train.txt', 'w')
count = 0

for fname in sorted(glob.glob('$DATA_DIR/raw/*.json')):
    try:
        with open(fname) as f:
            data = json.load(f)
        for item in data:
            story = item.get('story', item.get('text', ''))
            if story:
                # Clean: one story per line, strip whitespace
                story = ' '.join(story.split())
                if len(story) > 20:  # Skip very short entries
                    out.write(story + '\n')
                    count += 1
    except Exception as e:
        print(f'  Warning: {fname}: {e}', file=sys.stderr)

out.close()
print(f'[OK] Wrote {count} stories to $DATA_DIR/train.txt')
"
fi

# Step 4: Create small subset for quick training (100K stories)
if [ -f "$DATA_DIR/train_100k.txt" ]; then
    LINES=$(wc -l < "$DATA_DIR/train_100k.txt" | tr -d ' ')
    echo "[OK] train_100k.txt already exists ($LINES stories)"
else
    echo "[4/4] Creating 100K story subset..."
    head -100000 "$DATA_DIR/train.txt" > "$DATA_DIR/train_100k.txt"
    LINES=$(wc -l < "$DATA_DIR/train_100k.txt" | tr -d ' ')
    echo "[OK] Created train_100k.txt ($LINES stories)"
fi

# Summary
echo ""
echo "================================================================"
echo "  Dataset Ready!"
echo "================================================================"
FULL_SIZE=$(du -sh "$DATA_DIR/train.txt" 2>/dev/null | cut -f1 || echo "N/A")
SUB_SIZE=$(du -sh "$DATA_DIR/train_100k.txt" 2>/dev/null | cut -f1 || echo "N/A")
echo "  Full dataset: $DATA_DIR/train.txt ($FULL_SIZE)"
echo "  100K subset:  $DATA_DIR/train_100k.txt ($SUB_SIZE)"
echo ""
echo "  Train HSLM:"
echo "    zig build hslm-train -- --data $DATA_DIR/train_100k.txt --steps 50000"
echo ""
echo "phi^2 + 1/phi^2 = 3 = TRINITY"
