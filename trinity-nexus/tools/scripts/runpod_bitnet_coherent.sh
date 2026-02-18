#!/bin/bash
# RunPod BitNet b1.58-2B-4T Coherent Generation Test
# Run this script INSIDE the RunPod pod (x86_64 with AVX2/AVX512)
# Usage: bash scripts/runpod_bitnet_coherent.sh
#
# Prerequisites: RunPod pod with RTX 4090 or A100, Ubuntu 22.04
# Expected runtime: ~15 minutes (setup + generation)

set -euo pipefail

WORKSPACE="/workspace"
BITNET_DIR="${WORKSPACE}/BitNet"
MODEL_DIR="${WORKSPACE}/models/BitNet-b1.58-2B-4T"
REPORT_FILE="${WORKSPACE}/bitnet_coherent_results.txt"
METRICS_FILE="${WORKSPACE}/bitnet_coherent_metrics.json"

echo "=========================================="
echo "BitNet b1.58-2B-4T Coherent Generation"
echo "Platform: $(uname -m) $(uname -s)"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=========================================="

# Verify x86_64
if [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: This script requires x86_64 (got $(uname -m))"
    echo "BitNet I2_S kernel has known ARM bug (issue #198)"
    exit 1
fi

# Check for AVX2 support
if grep -q avx2 /proc/cpuinfo 2>/dev/null; then
    echo "AVX2: supported"
else
    echo "WARNING: AVX2 not detected, performance may be degraded"
fi

# Step 1: Clone and build bitnet.cpp
echo ""
echo "=== Step 1: Clone and build bitnet.cpp ==="
cd "${WORKSPACE}"

if [ ! -d "${BITNET_DIR}" ]; then
    git clone --recursive https://github.com/microsoft/BitNet.git
    cd "${BITNET_DIR}"
else
    cd "${BITNET_DIR}"
    git pull
fi

# Install Python dependencies
pip install -r requirements.txt 2>/dev/null || pip install huggingface_hub

# Run official setup (downloads model + builds)
python setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q i2_s

# Find the built binary and model
LLAMA_CLI="${BITNET_DIR}/build/bin/llama-cli"
MODEL_GGUF=$(find "${BITNET_DIR}/models" -name "*.gguf" -type f | head -1)

if [ ! -f "${LLAMA_CLI}" ]; then
    echo "ERROR: llama-cli not found at ${LLAMA_CLI}"
    echo "Trying alternate path..."
    LLAMA_CLI=$(find "${BITNET_DIR}/build" -name "llama-cli" -type f | head -1)
fi

if [ -z "${MODEL_GGUF}" ]; then
    echo "ERROR: No GGUF model found"
    exit 1
fi

echo "Binary: ${LLAMA_CLI}"
echo "Model: ${MODEL_GGUF}"

# Step 2: Run coherent generation tests
echo ""
echo "=== Step 2: Coherent Generation Tests ==="

# 10 diverse prompts for coherent testing
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
)

# Clear results file
echo "BitNet b1.58-2B-4T Coherent Generation Results" > "${REPORT_FILE}"
echo "Platform: $(uname -m) $(uname -s)" >> "${REPORT_FILE}"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "${REPORT_FILE}"
echo "Model: ${MODEL_GGUF}" >> "${REPORT_FILE}"
echo "=========================================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# JSON metrics start
echo '{"tests": [' > "${METRICS_FILE}"
FIRST_TEST=true

for i in "${!PROMPTS[@]}"; do
    PROMPT="${PROMPTS[$i]}"
    TEST_NUM=$((i + 1))
    echo ""
    echo "--- Test ${TEST_NUM}/10: \"${PROMPT}\" ---"

    # Run generation with timing
    START_TIME=$(date +%s%N)

    OUTPUT=$(${LLAMA_CLI} \
        -m "${MODEL_GGUF}" \
        -p "${PROMPT}" \
        -n 500 \
        -b 1 \
        -t 4 \
        --temp 0.0 \
        --override-kv "tokenizer.ggml.pre=str:llama-bpe" \
        2>/tmp/bitnet_stderr_${TEST_NUM}.txt || true)

    END_TIME=$(date +%s%N)
    ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))

    # Extract tokens/sec from stderr
    TOKENS_PER_SEC=$(grep -oP 'eval.*?(\d+\.\d+) tokens per second' /tmp/bitnet_stderr_${TEST_NUM}.txt | grep -oP '\d+\.\d+' | tail -1 || echo "N/A")

    echo "Output (first 200 chars): ${OUTPUT:0:200}"
    echo "Time: ${ELAPSED_MS}ms, Tokens/s: ${TOKENS_PER_SEC}"

    # Write to report
    echo "=== Test ${TEST_NUM}: \"${PROMPT}\" ===" >> "${REPORT_FILE}"
    echo "Tokens/s: ${TOKENS_PER_SEC}" >> "${REPORT_FILE}"
    echo "Time: ${ELAPSED_MS}ms" >> "${REPORT_FILE}"
    echo "Output:" >> "${REPORT_FILE}"
    echo "${OUTPUT}" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"

    # Write JSON metrics
    if [ "${FIRST_TEST}" = false ]; then
        echo "," >> "${METRICS_FILE}"
    fi
    FIRST_TEST=false

    # Escape output for JSON
    ESCAPED_OUTPUT=$(echo "${OUTPUT:0:500}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"error\"")

    cat >> "${METRICS_FILE}" << JSONEOF
  {
    "test_num": ${TEST_NUM},
    "prompt": $(python3 -c "import json; print(json.dumps('${PROMPT}'))" 2>/dev/null || echo "\"${PROMPT}\""),
    "tokens_per_sec": "${TOKENS_PER_SEC}",
    "elapsed_ms": ${ELAPSED_MS},
    "output_preview": ${ESCAPED_OUTPUT}
  }
JSONEOF
done

# Close JSON
echo "" >> "${METRICS_FILE}"
echo "]}" >> "${METRICS_FILE}"

# Step 3: Summary
echo ""
echo "=========================================="
echo "=== GENERATION COMPLETE ==="
echo "=========================================="
echo "Results: ${REPORT_FILE}"
echo "Metrics: ${METRICS_FILE}"
echo ""
echo "Copy results back:"
echo "  scp -P <PORT> root@<IP>:${REPORT_FILE} docs/bitnet_runpod_results.txt"
echo "  scp -P <PORT> root@<IP>:${METRICS_FILE} docs/bitnet_runpod_metrics.json"
echo ""
echo "REMEMBER: Stop the pod when done to save costs!"

# Print quick summary
echo ""
echo "=== Quick Summary ==="
cat "${REPORT_FILE}" | head -60
