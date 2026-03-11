#!/bin/sh
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
BATCH="${HSLM_BATCH:-64}"
WARMUP="${HSLM_WARMUP:-5000}"

echo "[entrypoint] HSLM Training Service"
echo "[entrypoint] Checkpoint dir: $CHECKPOINT_DIR"
echo "[entrypoint] Data dir: $DATA_DIR"

# Step 1: Prepare dataset if not present
if [ ! -f "$TRAIN_FILE" ]; then
    echo "[entrypoint] Training data not found, preparing TinyStories..."
    cd /data
    # prepare_tinystories.sh uses relative path data/tinystories/
    mkdir -p data
    ln -sf /data/tinystories data/tinystories 2>/dev/null || true
    DATA_DIR="data/tinystories" /usr/local/bin/prepare_tinystories.sh
    cd /data
    echo "[entrypoint] Dataset ready"
else
    LINES=$(wc -l < "$TRAIN_FILE" | tr -d ' ')
    echo "[entrypoint] Dataset exists: $TRAIN_FILE ($LINES stories)"
fi

# Step 2: Find latest checkpoint for auto-resume
RESUME_FLAG=""
if [ -d "$CHECKPOINT_DIR" ]; then
    LATEST=$(ls -t "$CHECKPOINT_DIR"/hslm_step_*.bin 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo "[entrypoint] Resuming from checkpoint: $LATEST"
        RESUME_FLAG="--resume $LATEST"
    else
        echo "[entrypoint] No checkpoint found, starting fresh"
    fi
fi

# Step 3: Run training (foreground — Docker tracks this process)
echo "[entrypoint] Starting training: steps=$STEPS lr=$LR batch=$BATCH"
exec /usr/local/bin/hslm-train \
    --data "$TRAIN_FILE" \
    --steps "$STEPS" \
    --lr "$LR" \
    --batch "$BATCH" \
    --warmup "$WARMUP" \
    --checkpoint-dir "$CHECKPOINT_DIR" \
    $RESUME_FLAG
