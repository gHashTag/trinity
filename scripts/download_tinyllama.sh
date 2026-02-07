#!/bin/bash
# Download TinyLlama-1.1B-Chat Q4_K_M GGUF for fluent local fallback
# phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL

set -e

MODEL_DIR="models"
MODEL_NAME="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     TRINITY - TinyLlama GGUF Download                        ║"
echo "║     Fluent Local Fallback for Hybrid Chat                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Create models directory if needed
mkdir -p "$MODEL_DIR"

# Check if already exists
if [ -f "$MODEL_DIR/$MODEL_NAME" ]; then
    echo "[INFO] Model already exists: $MODEL_DIR/$MODEL_NAME"
    ls -lh "$MODEL_DIR/$MODEL_NAME"
    exit 0
fi

echo "[INFO] Downloading TinyLlama-1.1B-Chat Q4_K_M (638MB)..."
echo "[INFO] URL: $MODEL_URL"
echo ""

# Download with progress
if command -v wget &> /dev/null; then
    wget -O "$MODEL_DIR/$MODEL_NAME" "$MODEL_URL"
elif command -v curl &> /dev/null; then
    curl -L -o "$MODEL_DIR/$MODEL_NAME" "$MODEL_URL"
else
    echo "[ERROR] Neither wget nor curl found!"
    exit 1
fi

# Verify download
if [ -f "$MODEL_DIR/$MODEL_NAME" ]; then
    SIZE=$(ls -lh "$MODEL_DIR/$MODEL_NAME" | awk '{print $5}')
    echo ""
    echo "[SUCCESS] Downloaded: $MODEL_DIR/$MODEL_NAME ($SIZE)"
    echo ""
    echo "Run hybrid chat test:"
    echo "  ./test_hybrid_chat models/$MODEL_NAME"
else
    echo "[ERROR] Download failed!"
    exit 1
fi

echo ""
echo "phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL"
