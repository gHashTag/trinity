#!/bin/bash
# Trinity Cognitive Probes — Overnight Full Run
# 7 models × 11,400 items × 5 tracks = ~9.5 hours, $0
#
# Usage:
#   chmod +x run_overnight.sh
#   ./run_overnight.sh

set -e

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Models to run (verified working March 2026)
MODELS=(
    "nemotron-super"      # nvidia/nemotron-3-super-120b:free - 120B
    "qwen3-next"          # qwen/qwen3-next-80b-a3b-instruct:free - 80B
    "llama-3.3"           # meta-llama/llama-3.3-70b-instruct:free - 70B
    "mistral-small"       # mistralai/mistral-small-3.1-24b-instruct:free - 24B
    "gpt-oss-120b"        # openai/gpt-oss-120b:free - 120B
    "glm-4.5-air"         # z-ai/glm-4.5-air:free - multilingual
    "trinity-mini"        # arcee-ai/trinity-mini:free - small but capable
)

# Create output directories
mkdir -p results/baselines
mkdir -p logs

echo "======================================"
echo "Trinity Cognitive Probes — Full Run"
echo "======================================"
echo "Start: $(date)"
echo "Models: ${#MODELS[@]}"
echo "Items per model: 11,400"
echo "Total requests: $((11400 * ${#MODELS[@]}))"
echo "Estimated time: ~9.5 hours"
echo "======================================"

# Launch each model in background
for model in "${MODELS[@]}"; do
    echo "[$(date +%H:%M:%S)] Starting $model..."

    python3 run_free_baselines.py \
        --model "$model" \
        --max-items 11400 \
        --output-dir results/baselines \
        > "logs/${model}_$(date +%Y%m%d_%H%M%S).log" 2>&1 &

    PID=$!
    echo "[$(date +%H:%M:%S)] $model running (PID: $PID)"
    echo "$PID" > "logs/${model}.pid"

    # Stagger starts to avoid rate limit collisions
    sleep 10
done

echo ""
echo "======================================"
echo "All models launched!"
echo "======================================"
echo ""
echo "Monitor progress:"
echo "  tail -f logs/*.log"
echo ""
echo "Check status:"
echo "  ps aux | grep run_free_baselines"
echo ""
echo "Kill specific model:"
echo "  kill \$(cat logs/<model>.pid)"
echo ""
echo "Waiting for completion..."
echo ""

# Wait for all background processes
wait

echo ""
echo "======================================"
echo "ALL DONE at $(date)"
echo "======================================"
echo ""
echo "Results:"
ls -lh results/baselines/*.csv 2>/dev/null || echo "No CSV files yet"
echo ""
echo "Logs:"
ls -lh logs/*.log
