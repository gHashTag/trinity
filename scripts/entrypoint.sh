#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY LLM - Entrypoint Script
# Downloads model to NVMe volume on first run
# Supports multiple model sizes via MODEL_SIZE env var
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

set -e

MODEL_DIR="/data/models"

# Model selection based on MODEL_SIZE env var
# Options: 360m (fast), 1.7b (default/quality)
MODEL_SIZE="${MODEL_SIZE:-1.7b}"

case "${MODEL_SIZE}" in
    "360m"|"360M"|"fast")
        MODEL_FILE="smollm2-360m-instruct-q8_0.gguf"
        MODEL_URL="https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q8_0.gguf"
        MODEL_DESC="SmolLM2-360M (fast, 0.39GB)"
        ;;
    "1.7b"|"1.7B"|"quality"|*)
        MODEL_FILE="smollm2-1.7b-instruct-q8_0.gguf"
        MODEL_URL="https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q8_0.gguf"
        MODEL_DESC="SmolLM2-1.7B (quality, 1.7GB)"
        ;;
esac

MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           TRINITY LLM - Volume Initialization                ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Model: ${MODEL_DESC}"
echo "╚══════════════════════════════════════════════════════════════╝"

# Create models directory on volume
mkdir -p "${MODEL_DIR}"

# Check if model exists on volume
if [ -f "${MODEL_PATH}" ]; then
    echo "✓ Model found on NVMe volume: ${MODEL_PATH}"
    ls -lh "${MODEL_PATH}"
else
    echo "⚡ Model not found on volume. Downloading to NVMe SSD..."
    echo "   This is a one-time operation. Future starts will be instant."
    echo ""
    echo "   Downloading: ${MODEL_FILE}"
    echo "   From: ${MODEL_URL}"
    echo ""
    
    # Download with progress
    curl -L --progress-bar -o "${MODEL_PATH}" "${MODEL_URL}"
    
    echo ""
    echo "✓ Download complete!"
    ls -lh "${MODEL_PATH}"
fi

echo ""
echo "Starting TRINITY LLM server..."
echo "Model: ${MODEL_PATH}"
echo "Size: ${MODEL_SIZE}"
echo ""

# Start the server
exec /app/vibee serve --model "${MODEL_PATH}" --port 8080
