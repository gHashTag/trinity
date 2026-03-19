#!/bin/bash
# Trinity HSLM Training Entrypoint
# - Downloads TinyStories if missing (persistent volume keeps it)
# - Auto-resumes from latest checkpoint on redeploy
# - All state lives on /data (Railway persistent volume)

set -e

DATA_DIR="/data/tinystories"
CHECKPOINT_DIR="/data/checkpoints"
TRAIN_FILE="$DATA_DIR/train_100k.txt"

# Training hyperparameters (override via env vars)
STEPS="${HSLM_STEPS:-100000}"
LR="${HSLM_LR:-3e-4}"
LR_MIN="${HSLM_LR_MIN:-1e-6}"
BATCH="${HSLM_BATCH:-64}"
WARMUP="${HSLM_WARMUP:-5000}"
WD="${HSLM_WD:-0.1}"
DROPOUT="${HSLM_DROPOUT:-0.0}"
SEED="${HSLM_SEED:-0}"
STE_MODE="${HSLM_STE:-none}"
STE_THRESHOLD="${HSLM_STE_THRESHOLD:-0.5}"
STE_WARMUP="${HSLM_STE_WARMUP:-10000}"

echo "[entrypoint] HSLM Training Service v7"
echo "[entrypoint] Checkpoint dir: $CHECKPOINT_DIR"
echo "[entrypoint] Data: $TRAIN_FILE"
echo "[entrypoint] Config: steps=$STEPS lr=$LR lr_min=$LR_MIN batch=$BATCH warmup=$WARMUP wd=$WD dropout=$DROPOUT ste=$STE_MODE"

mkdir -p "$DATA_DIR" "$CHECKPOINT_DIR"

# Step 1: Prepare dataset if not present
if [ ! -f "$TRAIN_FILE" ]; then
    echo "[entrypoint] Dataset not found, downloading TinyStories..."

    ARCHIVE="$DATA_DIR/TinyStories_all_data.tar.gz"
    URL="https://huggingface.co/datasets/roneneldan/TinyStories/resolve/main/TinyStories_all_data.tar.gz"

    if [ ! -f "$ARCHIVE" ]; then
        echo "[entrypoint] Downloading ~500MB from HuggingFace..."
        curl -L --progress-bar -o "$ARCHIVE" "$URL"
        echo "[entrypoint] Download complete"
    fi

    echo "[entrypoint] Extracting..."
    mkdir -p "$DATA_DIR/raw"
    tar -xzf "$ARCHIVE" -C "$DATA_DIR/raw"

    echo "[entrypoint] Converting JSON to text..."
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
                story = ' '.join(story.split())
                if len(story) > 20:
                    out.write(story + '\n')
                    count += 1
    except Exception as e:
        print(f'Warning: {fname}: {e}', file=sys.stderr)
out.close()
print(f'[entrypoint] Converted {count} stories')
"
    head -100000 "$DATA_DIR/train.txt" > "$TRAIN_FILE"
    echo "[entrypoint] Dataset ready: $(wc -l < "$TRAIN_FILE") stories"
else
    echo "[entrypoint] Dataset exists: $(wc -l < "$TRAIN_FILE") stories"
fi

# Step 2: Find latest checkpoint for auto-resume
RESUME_FLAG=""
if [ -d "$CHECKPOINT_DIR" ]; then
    LATEST=$(ls -t "$CHECKPOINT_DIR"/hslm_step_*.bin 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo "[entrypoint] Resuming from: $LATEST"
        RESUME_FLAG="--resume $LATEST"
    else
        echo "[entrypoint] No checkpoint, starting fresh"
    fi
fi

# Step 3: Run training (foreground — PID 1)
echo "[entrypoint] Starting training..."
# Build extra flags
EXTRA_FLAGS=""
if [ "$WD" != "0.1" ]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --wd $WD"
fi
if [ "$DROPOUT" != "0.0" ]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --dropout $DROPOUT"
fi
if [ "$SEED" != "0" ]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --seed $SEED"
fi
if [ "$STE_MODE" != "none" ]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --ste $STE_MODE --ste-threshold $STE_THRESHOLD --ste-warmup $STE_WARMUP"
fi

exec /usr/local/bin/hslm-train \
    --data "$TRAIN_FILE" \
    --steps "$STEPS" \
    --lr "$LR" \
    --lr-min "$LR_MIN" \
    --batch "$BATCH" \
    --warmup "$WARMUP" \
    --checkpoint-dir "$CHECKPOINT_DIR" \
    $RESUME_FLAG $EXTRA_FLAGS
