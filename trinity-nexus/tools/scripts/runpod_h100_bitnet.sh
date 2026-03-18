#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RunPod H100 SXM - BitNet b1.58-2B-4T Full Inference Benchmark
# Target: 80-300 tok/s with AVX-512 VNNI + TL2 kernels
# Usage: bash scripts/runpod_h100_bitnet.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

BITNET_DIR="/root/BitNet"
REPORT="/root/bitnet_h100_results.txt"
METRICS="/root/bitnet_h100_metrics.json"

echo "═══════════════════════════════════════════════════════════════"
echo "  BitNet b1.58-2B-4T — H100 SXM Benchmark"
echo "  Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "═══════════════════════════════════════════════════════════════"

# ── Step 0: Verify hardware ──────────────────────────────────────
echo ""
echo "=== Hardware Check ==="
echo "CPU: $(lscpu | grep 'Model name' | sed 's/.*: *//')"
echo "Cores: $(nproc)"
echo "Arch: $(uname -m)"

AVX512=$(lscpu | grep -c avx512 || true)
if [ "$AVX512" -gt 0 ]; then
    echo "AVX-512: YES ($(lscpu | grep -o 'avx512[a-z_]*' | tr '\n' ' '))"
else
    echo "AVX-512: NO (AVX2 only — performance will be lower)"
fi

VNNI=$(lscpu | grep -c avx512vnni || true)
if [ "$VNNI" -gt 0 ]; then
    echo "AVX-512 VNNI: YES (optimal for BitNet I2_S kernel)"
else
    echo "AVX-512 VNNI: NO"
fi

GPU=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "No GPU")
echo "GPU: $GPU"
echo ""

# ── Step 1: Install dependencies ─────────────────────────────────
echo "=== Step 1: Dependencies ==="
apt-get update -qq && apt-get install -y -qq clang cmake 2>/dev/null | tail -1
pip3 install huggingface_hub 2>/dev/null | tail -1
echo "Done."

# ── Step 2: Clone and build ──────────────────────────────────────
echo ""
echo "=== Step 2: Clone & Build ==="
if [ ! -d "$BITNET_DIR" ]; then
    git clone --recursive https://github.com/microsoft/BitNet.git "$BITNET_DIR"
fi
cd "$BITNET_DIR"

# Fix const-correctness bug in upstream code
sed -i 's/int8_t \* y_col = y + col \* by;/const int8_t * y_col = y + col * by;/g' src/ggml-bitnet-mad.cpp
# Fix double-const if any
sed -i 's/const const int8_t/const int8_t/g' src/ggml-bitnet-mad.cpp

# Install python deps for the correct python
PYTHON=$(which python3)
$PYTHON -m pip install torch --index-url https://download.pytorch.org/whl/cpu 2>/dev/null | tail -3
$PYTHON -m pip install transformers huggingface_hub sentencepiece gguf numpy safetensors 2>/dev/null | tail -3

# Try official setup first (with TL2 if x86_64)
echo "Building bitnet.cpp..."
rm -rf build

# Try TL2 build first (faster kernels)
if [ "$AVX512" -gt 0 ]; then
    echo "AVX-512 detected — attempting TL2 build..."
    $PYTHON setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q i2_s 2>&1 | tail -5 || true
fi

# If setup_env failed or no build, do manual cmake
if [ ! -f "build/bin/llama-cli" ]; then
    echo "Falling back to manual cmake build..."
    cmake -B build \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_BUILD_TYPE=Release \
        .
    cmake --build build --config Release -j$(nproc) 2>&1 | tail -5
fi

# ── Step 3: Download pre-converted GGUF ──────────────────────────
echo ""
echo "=== Step 3: Download Model ==="
MODEL_DIR="$BITNET_DIR/models/BitNet-b1.58-2B-4T"
MODEL_GGUF="$MODEL_DIR/ggml-model-i2_s.gguf"
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_GGUF" ]; then
    $PYTHON -c "
from huggingface_hub import hf_hub_download
hf_hub_download('microsoft/bitnet-b1.58-2B-4T-gguf', 'ggml-model-i2_s.gguf', local_dir='$MODEL_DIR')
"
fi
echo "Model: $(ls -lh $MODEL_GGUF | awk '{print $5}')"

# ── Step 4: Find optimal thread count ────────────────────────────
LLAMA="$BITNET_DIR/build/bin/llama-cli"
NCPU=$(nproc)
echo ""
echo "=== Step 4: Thread Scaling Test ==="

# Test with 1, 2, 4, 8, 16, max threads
for THREADS in 1 2 4 8 16 $NCPU; do
    if [ "$THREADS" -gt "$NCPU" ]; then continue; fi
    echo -n "  Threads=$THREADS: "

    OUTPUT=$($LLAMA -m "$MODEL_GGUF" \
        -p "The capital of France is" \
        -n 50 -b 1 -t $THREADS --temp 0.0 \
        --override-kv "tokenizer.ggml.pre=str:llama-bpe" \
        2>&1)

    TOKS=$(echo "$OUTPUT" | grep "eval time" | grep -oP '[\d.]+(?= tokens per second)' | tail -1)
    echo "${TOKS:-N/A} tok/s"
done

# ── Step 5: Full generation test (best thread count) ─────────────
echo ""
echo "=== Step 5: Full Generation Test ==="

# Use nproc/2 or 16, whichever is smaller
BEST_T=$(( NCPU < 16 ? NCPU : 16 ))

PROMPTS=(
    "The capital of France is"
    "Microsoft Corporation is an American multinational"
    "In the year 2025, artificial intelligence"
    "The theory of relativity states that"
    "Once upon a time in a small village"
    "The three most important programming languages are"
    "Water is composed of hydrogen and oxygen"
    "The human brain contains approximately"
    "Bitcoin was created by Satoshi Nakamoto in"
    "The Fibonacci sequence starts with 0, 1, and each"
    "Explain step by step how photosynthesis works:"
    "List 3 reasons why machine learning is important:"
)

echo "BitNet b1.58-2B-4T H100 SXM Benchmark" > "$REPORT"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$REPORT"
echo "CPU: $(lscpu | grep 'Model name' | sed 's/.*: *//')" >> "$REPORT"
echo "Cores: $(nproc), Threads used: $BEST_T" >> "$REPORT"
echo "AVX-512: $([ $AVX512 -gt 0 ] && echo YES || echo NO)" >> "$REPORT"
echo "GPU: $GPU" >> "$REPORT"
echo "=========================================" >> "$REPORT"
echo "" >> "$REPORT"

echo '{"tests": [' > "$METRICS"
FIRST=true

for i in "${!PROMPTS[@]}"; do
    P="${PROMPTS[$i]}"
    N=$((i + 1))
    echo "--- Test $N/${#PROMPTS[@]}: \"${P:0:50}...\" ---"

    START_NS=$(date +%s%N)

    FULL_OUT=$($LLAMA -m "$MODEL_GGUF" \
        -p "$P" \
        -n 500 -b 1 -t $BEST_T --temp 0.0 \
        --override-kv "tokenizer.ggml.pre=str:llama-bpe" \
        2>/tmp/stderr_h100_${N}.txt || true)

    END_NS=$(date +%s%N)
    ELAPSED_MS=$(( (END_NS - START_NS) / 1000000 ))

    TOKS=$(grep "eval time" /tmp/stderr_h100_${N}.txt | grep -oP '[\d.]+(?= tokens per second)' | tail -1)
    PROMPT_TOKS=$(grep "prompt eval time" /tmp/stderr_h100_${N}.txt | grep -oP '[\d.]+(?= tokens per second)' | tail -1)

    echo "  Output: ${FULL_OUT:0:120}..."
    echo "  Speed: ${TOKS:-N/A} tok/s eval, ${PROMPT_TOKS:-N/A} tok/s prompt, ${ELAPSED_MS}ms total"

    echo "=== Test $N: \"$P\" ===" >> "$REPORT"
    echo "Speed: ${TOKS:-N/A} tok/s eval, ${PROMPT_TOKS:-N/A} tok/s prompt" >> "$REPORT"
    echo "Time: ${ELAPSED_MS}ms" >> "$REPORT"
    echo "Output:" >> "$REPORT"
    echo "$FULL_OUT" >> "$REPORT"
    echo "" >> "$REPORT"

    if [ "$FIRST" = false ]; then echo "," >> "$METRICS"; fi
    FIRST=false

    ESCAPED=$(echo "${FULL_OUT:0:500}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"error\"")
    cat >> "$METRICS" << JEOF
  {"test": $N, "prompt": $(python3 -c "import json; print(json.dumps('''$P'''))" 2>/dev/null || echo "\"$P\""), "tok_s": "${TOKS:-0}", "prompt_tok_s": "${PROMPT_TOKS:-0}", "ms": $ELAPSED_MS, "output": $ESCAPED}
JEOF
done

echo "]}" >> "$METRICS"

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  BENCHMARK COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo "Results: $REPORT"
echo "Metrics: $METRICS"
echo ""
echo "=== Quick Summary ==="
head -30 "$REPORT"
echo ""
echo "REMEMBER: Stop the pod when done!"
