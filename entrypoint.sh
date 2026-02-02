#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY LLM - Entrypoint Script
# Downloads model to NVMe volume on first run
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

set -e

MODEL_DIR="/data/models"
MODEL_FILE="smollm2-1.7b-instruct-q8_0.gguf"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
MODEL_URL="https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q8_0.gguf"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           TRINITY LLM - Volume Initialization                ║"
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
echo ""

# Start the server
exec /app/vibee serve --model "${MODEL_PATH}" --port 8080
