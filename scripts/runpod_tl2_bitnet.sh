#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RunPod TL2 Kernel Build — BitNet b1.58-2B-4T
# Target: 100-200 tok/s with TL2 lookup-table kernels on x86_64
# Usage: bash scripts/runpod_tl2_bitnet.sh
#
# THREE CRITICAL PATCHES applied to upstream bitnet.cpp:
#   1. setup_env.py:  BITNET_X86_TL2=OFF → ON  (enable TL2 kernels in cmake)
#   2. convert-hf-to-gguf-bitnet.py: _set_vocab_sentencepiece → try/except
#      fallback to _set_vocab_gpt2 (BPE tokenizer support)
#   3. convert-hf-to-gguf-bitnet.py: Add @Model.register("BitNetForCausalLM")
#      for capital-N architecture name in config.json
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

BITNET_DIR="/root/BitNet"
REPORT="/root/bitnet_tl2_results.txt"
METRICS="/root/bitnet_tl2_metrics.json"

echo "═══════════════════════════════════════════════════════════════"
echo "  BitNet b1.58-2B-4T — TL2 Kernel Build + Benchmark"
echo "  Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "═══════════════════════════════════════════════════════════════"

# ── Step 0: Verify hardware ──────────────────────────────────────
echo ""
echo "=== Hardware Check ==="
echo "CPU: $(lscpu | grep 'Model name' | sed 's/.*: *//')"
echo "Cores: $(nproc)"
echo "Arch: $(uname -m)"

if [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: TL2 kernels require x86_64"
    exit 1
fi

AVX512=$(lscpu | grep -c avx512 || true)
if [ "$AVX512" -gt 0 ]; then
    echo "AVX-512: YES ($(lscpu | grep -o 'avx512[a-z_]*' | tr '\n' ' '))"
else
    echo "AVX-512: NO (AVX2 only — TL2 still works but slower)"
fi

VNNI=$(lscpu | grep -c avx512vnni || true)
if [ "$VNNI" -gt 0 ]; then
    echo "AVX-512 VNNI: YES (optimal for TL2)"
else
    echo "AVX-512 VNNI: NO"
fi

GPU=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "No GPU")
echo "GPU: $GPU (CPU-only inference)"
echo ""

# ── Step 1: Install dependencies ─────────────────────────────────
echo "=== Step 1: Dependencies ==="
apt-get update -qq && apt-get install -y -qq clang cmake git python3-venv 2>/dev/null | tail -1

# Create venv (PEP 668 on Ubuntu 24.04)
if [ ! -d "/root/bitnet_venv" ]; then
    python3 -m venv /root/bitnet_venv
fi
source /root/bitnet_venv/bin/activate

pip install --quiet huggingface_hub torch --index-url https://download.pytorch.org/whl/cpu
pip install --quiet transformers sentencepiece gguf numpy safetensors
echo "Dependencies installed."

# Create huggingface-cli wrapper (v1.4.0+ uses 'hf' binary)
if ! command -v huggingface-cli &>/dev/null; then
    HF_BIN=$(which hf 2>/dev/null || echo "/root/bitnet_venv/bin/hf")
    if [ -f "$HF_BIN" ]; then
        cat > /usr/local/bin/huggingface-cli << WRAP
#!/bin/bash
exec "$HF_BIN" "\$@"
WRAP
        chmod +x /usr/local/bin/huggingface-cli
        echo "Created huggingface-cli wrapper → $HF_BIN"
    fi
fi

# ── Step 2: Clone bitnet.cpp ─────────────────────────────────────
echo ""
echo "=== Step 2: Clone bitnet.cpp ==="
if [ ! -d "$BITNET_DIR" ]; then
    git clone --recursive https://github.com/microsoft/BitNet.git "$BITNET_DIR"
fi
cd "$BITNET_DIR"
echo "BitNet repo ready."

# ── Step 3: Apply THREE critical patches ─────────────────────────
echo ""
echo "=== Step 3: Apply TL2 Patches ==="

# ─── PATCH 1: Enable TL2 in cmake (setup_env.py) ───
echo "Patch 1: Enable BITNET_X86_TL2=ON in setup_env.py..."
if grep -q 'DBITNET_X86_TL2=OFF' setup_env.py; then
    sed -i 's/-DBITNET_X86_TL2=OFF/-DBITNET_X86_TL2=ON/g' setup_env.py
    echo "  ✓ Changed -DBITNET_X86_TL2=OFF → ON"
else
    echo "  - Already patched or flag not found"
fi

# Verify patch
if grep -q 'DBITNET_X86_TL2=ON' setup_env.py; then
    echo "  ✓ Verified: TL2=ON in setup_env.py"
else
    echo "  ✗ WARNING: TL2 flag not found in setup_env.py"
fi

# ─── PATCH 2: Fix architecture name (convert-hf-to-gguf-bitnet.py) ───
CONVERT_SCRIPT="utils/convert-hf-to-gguf-bitnet.py"
echo ""
echo "Patch 2: Add BitNetForCausalLM (capital N) registration..."
if [ -f "$CONVERT_SCRIPT" ]; then
    # Add second @Model.register decorator for capital-N variant
    if grep -q 'BitNetForCausalLM' "$CONVERT_SCRIPT"; then
        echo "  - BitNetForCausalLM already registered"
    else
        # Add decorator line BEFORE the existing @Model.register("BitnetForCausalLM")
        sed -i 's/@Model.register("BitnetForCausalLM")/@Model.register("BitNetForCausalLM")\n@Model.register("BitnetForCausalLM")/' "$CONVERT_SCRIPT"
        echo "  ✓ Added @Model.register(\"BitNetForCausalLM\") decorator"
    fi
else
    echo "  ✗ WARNING: $CONVERT_SCRIPT not found"
fi

# ─── PATCH 3: Fix BPE tokenizer support (convert-hf-to-gguf-bitnet.py) ───
echo ""
echo "Patch 3: Fix set_vocab() for BPE tokenizer (LLaMA 3 style)..."
if [ -f "$CONVERT_SCRIPT" ]; then
    # Replace hardcoded _set_vocab_sentencepiece() with try/except fallback
    # Pattern: exactly match the original set_vocab method
    python3 << 'PYEOF'
import re

with open("utils/convert-hf-to-gguf-bitnet.py", "r") as f:
    content = f.read()

# Find and replace the set_vocab method in BitnetModel
old_pattern = r'(class BitnetModel\(Model\):.*?)(    def set_vocab\(self\):\s*\n\s*self\._set_vocab_sentencepiece\(\))'
new_set_vocab = '''    def set_vocab(self):
        try:
            self._set_vocab_sentencepiece()
        except FileNotFoundError:
            try:
                self._set_vocab_llama_hf()
            except (FileNotFoundError, TypeError):
                # BitNet b1.58-2B-4T uses BPE tokenizer (tokenizer.json)
                self._set_vocab_gpt2()'''

# Simple string replacement approach
old_method = "    def set_vocab(self):\n        self._set_vocab_sentencepiece()"
if old_method in content:
    content = content.replace(old_method, new_set_vocab)
    with open("utils/convert-hf-to-gguf-bitnet.py", "w") as f:
        f.write(content)
    print("  ✓ Replaced set_vocab with try/except fallback (SP → LlamaHF → GPT2/BPE)")
else:
    print("  - set_vocab already patched or pattern differs")
PYEOF
else
    echo "  ✗ WARNING: $CONVERT_SCRIPT not found"
fi

# Show patched state
echo ""
echo "=== Patch verification ==="
echo "--- setup_env.py TL2 flag ---"
grep -n "BITNET_X86_TL2" setup_env.py || echo "  not found"
echo "--- convert-hf-to-gguf-bitnet.py Model.register ---"
grep -n "Model.register" "$CONVERT_SCRIPT" | head -5 || echo "  not found"
echo "--- convert-hf-to-gguf-bitnet.py set_vocab ---"
grep -A5 "def set_vocab" "$CONVERT_SCRIPT" | head -10 || echo "  not found"

# ── Step 4: Fix const-correctness bug ────────────────────────────
echo ""
echo "=== Step 4: Fix const-correctness bug ==="
if [ -f "src/ggml-bitnet-mad.cpp" ]; then
    sed -i 's/int8_t \* y_col = y + col \* by;/const int8_t * y_col = y + col * by;/g' src/ggml-bitnet-mad.cpp
    sed -i 's/const const int8_t/const int8_t/g' src/ggml-bitnet-mad.cpp
    echo "Fixed const-correctness in ggml-bitnet-mad.cpp"
fi

# ── Step 5: Run setup_env.py with TL2 ────────────────────────────
echo ""
echo "=== Step 5: Build with TL2 (setup_env.py -q tl2) ==="
rm -rf build

PYTHON=$(which python3)
echo "Python: $PYTHON"
echo "Running: setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q tl2"
echo "This will: codegen TL2 kernels → cmake with TL2=ON → convert model to TL2 GGUF"
echo ""

$PYTHON setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q tl2 2>&1 | tee /root/tl2_build_log.txt

# Check build success
LLAMA="$BITNET_DIR/build/bin/llama-cli"
if [ ! -f "$LLAMA" ]; then
    echo "ERROR: llama-cli not built!"
    echo "Build log:"
    tail -30 /root/tl2_build_log.txt
    exit 1
fi
echo "Build successful: $LLAMA"

# Find TL2 model
MODEL_GGUF=$(find "$BITNET_DIR/models" -name "*.gguf" -type f | head -1)
if [ -z "$MODEL_GGUF" ]; then
    echo "ERROR: No GGUF model found after conversion!"
    echo "Checking models directory..."
    find "$BITNET_DIR/models" -type f
    exit 1
fi
echo "Model: $MODEL_GGUF ($(ls -lh "$MODEL_GGUF" | awk '{print $5}'))"

# ── Step 6: Quick smoke test ─────────────────────────────────────
echo ""
echo "=== Step 6: Smoke Test (50 tokens) ==="
$LLAMA -m "$MODEL_GGUF" \
    -p "The capital of France is" \
    -n 50 -b 1 -t 4 --temp 0.0 \
    --override-kv "tokenizer.ggml.pre=str:llama-bpe" \
    2>&1 | tee /root/tl2_smoke_test.txt

SMOKE_TOKS=$(grep "eval time" /root/tl2_smoke_test.txt | grep -oP '[\d.]+(?= tokens per second)' | tail -1)
echo ""
echo "Smoke test speed: ${SMOKE_TOKS:-FAILED} tok/s"

if [ -z "$SMOKE_TOKS" ]; then
    echo "WARNING: Smoke test may have failed. Checking output..."
    tail -20 /root/tl2_smoke_test.txt
fi

# ── Step 7: Thread scaling ───────────────────────────────────────
echo ""
echo "=== Step 7: Thread Scaling Test ==="
NCPU=$(nproc)

for THREADS in 1 2 4 8 16 20; do
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

# ── Step 8: Full benchmark (12 prompts × 500 tokens) ─────────────
echo ""
echo "=== Step 8: Full TL2 Benchmark ==="

# Determine optimal thread count
BEST_T=$(( NCPU < 16 ? NCPU : 16 ))
echo "Using $BEST_T threads"

# Write benchmark script directly (avoids bash array escaping issues)
cat > /root/tl2_bench.py << 'PYEOF'
import subprocess, json, time, re, sys

LLAMA = sys.argv[1]
MODEL = sys.argv[2]
THREADS = int(sys.argv[3])

PROMPTS = [
    "The capital of France is",
    "Microsoft Corporation is an American multinational",
    "In the year 2025, artificial intelligence",
    "The theory of relativity states that",
    "Once upon a time in a small village",
    "The three most important programming languages are",
    "Water is composed of hydrogen and oxygen",
    "The human brain contains approximately",
    "Bitcoin was created by Satoshi Nakamoto in",
    "The Fibonacci sequence starts with 0, 1, and each",
    "Explain step by step how photosynthesis works:",
    "List 3 reasons why machine learning is important:",
]

results = []
total_toks = 0.0
count = 0

for i, prompt in enumerate(PROMPTS):
    n = i + 1
    print(f"\n--- Test {n}/{len(PROMPTS)}: \"{prompt[:50]}...\" ---")

    start = time.time()
    proc = subprocess.run(
        [LLAMA, "-m", MODEL, "-p", prompt, "-n", "500", "-b", "1",
         "-t", str(THREADS), "--temp", "0.0",
         "--override-kv", "tokenizer.ggml.pre=str:llama-bpe"],
        capture_output=True, text=True, timeout=120
    )
    elapsed_ms = int((time.time() - start) * 1000)

    stdout = proc.stdout
    stderr = proc.stderr

    # Extract tok/s
    eval_match = re.findall(r'eval time.*?([\d.]+)\s*tokens per second', stderr)
    prompt_match = re.findall(r'prompt eval time.*?([\d.]+)\s*tokens per second', stderr)

    eval_toks = float(eval_match[-1]) if eval_match else 0
    prompt_toks = float(prompt_match[-1]) if prompt_match else 0

    preview = stdout[:150].replace('\n', ' ')
    print(f"  Output: {preview}...")
    print(f"  Speed: {eval_toks:.2f} tok/s eval, {prompt_toks:.2f} tok/s prompt, {elapsed_ms}ms")

    results.append({
        "test": n,
        "prompt": prompt,
        "eval_tok_s": eval_toks,
        "prompt_tok_s": prompt_toks,
        "elapsed_ms": elapsed_ms,
        "output_preview": stdout[:500],
        "coherent": len(stdout.strip()) > 50
    })

    if eval_toks > 0:
        total_toks += eval_toks
        count += 1

# Summary
avg = total_toks / count if count > 0 else 0
max_t = max(r["eval_tok_s"] for r in results) if results else 0
min_t = min(r["eval_tok_s"] for r in results if r["eval_tok_s"] > 0) if results else 0
coherent = sum(1 for r in results if r["coherent"])

print(f"\n{'='*60}")
print(f"  TL2 BENCHMARK RESULTS")
print(f"{'='*60}")
print(f"  Average: {avg:.2f} tok/s")
print(f"  Peak:    {max_t:.2f} tok/s")
print(f"  Min:     {min_t:.2f} tok/s")
print(f"  Coherent: {coherent}/{len(results)}")
print(f"  Threads: {THREADS}")
print(f"{'='*60}")

# Save metrics
metrics = {
    "kernel": "TL2",
    "threads": THREADS,
    "avg_tok_s": round(avg, 2),
    "peak_tok_s": round(max_t, 2),
    "min_tok_s": round(min_t, 2),
    "coherent": f"{coherent}/{len(results)}",
    "tests": results
}

with open("/root/bitnet_tl2_metrics.json", "w") as f:
    json.dump(metrics, f, indent=2)

# Save report
with open("/root/bitnet_tl2_results.txt", "w") as f:
    f.write(f"BitNet b1.58-2B-4T TL2 Benchmark\n")
    f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}\n")
    f.write(f"Kernel: TL2 (Table Lookup Level 2)\n")
    f.write(f"Threads: {THREADS}\n")
    f.write(f"Average: {avg:.2f} tok/s\n")
    f.write(f"Peak: {max_t:.2f} tok/s\n")
    f.write(f"Min: {min_t:.2f} tok/s\n")
    f.write(f"Coherent: {coherent}/{len(results)}\n")
    f.write(f"{'='*50}\n\n")
    for r in results:
        f.write(f"=== Test {r['test']}: \"{r['prompt']}\" ===\n")
        f.write(f"Speed: {r['eval_tok_s']:.2f} tok/s eval, {r['prompt_tok_s']:.2f} tok/s prompt\n")
        f.write(f"Time: {r['elapsed_ms']}ms\n")
        f.write(f"Coherent: {r['coherent']}\n")
        f.write(f"Output: {r['output_preview'][:300]}\n\n")

print(f"\nResults: /root/bitnet_tl2_results.txt")
print(f"Metrics: /root/bitnet_tl2_metrics.json")
PYEOF

$PYTHON /root/tl2_bench.py "$LLAMA" "$MODEL_GGUF" "$BEST_T"

# ── Step 9: Compare I2_S vs TL2 ──────────────────────────────────
echo ""
echo "=== Step 9: I2_S Comparison (if available) ==="

# Also build I2_S for direct comparison
I2S_GGUF=$(find "$BITNET_DIR/models" -name "*i2_s*" -type f | head -1)
if [ -n "$I2S_GGUF" ]; then
    echo "Found I2_S model: $I2S_GGUF"
    echo "NOTE: I2_S model with TL2 kernels will NOT work."
    echo "For I2_S comparison, use the I2_S benchmark from B200 report (52.67 tok/s)."
else
    echo "No I2_S model found (expected — TL2 conversion produces different format)"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  TL2 BENCHMARK COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo "Results: /root/bitnet_tl2_results.txt"
echo "Metrics: /root/bitnet_tl2_metrics.json"
echo "Build log: /root/tl2_build_log.txt"
echo ""
echo "Copy results back:"
echo "  scp -P <PORT> root@<IP>:/root/bitnet_tl2_results.txt docs/"
echo "  scp -P <PORT> root@<IP>:/root/bitnet_tl2_metrics.json docs/"
echo ""
echo "REMEMBER: Stop the pod when done!"
echo ""
echo "KOSCHEI IS IMMORTAL | TL2 KERNELS DEPLOYED | TARGET: 100+ tok/s"
