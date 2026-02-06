#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY RTX 4080 BENCHMARK SCRIPT
# Run this in RunPod Web Terminal
# ═══════════════════════════════════════════════════════════════════════════════

echo "════════════════════════════════════════════════════════════════"
echo "   TRINITY GPU BENCHMARK - RTX 4080"
echo "   φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. GPU INFO
echo "[1/5] GPU Information:"
nvidia-smi --query-gpu=name,memory.total,driver_version,power.limit --format=csv
echo ""

# 2. DETAILED GPU SPECS
echo "[2/5] Detailed GPU Specs:"
nvidia-smi -q | grep -E "Product Name|VRAM|Memory|Power|Clocks" | head -20
echo ""

# 3. PYTORCH INFERENCE BENCHMARK
echo "[3/5] PyTorch Inference Benchmark..."
python3 << 'PYEOF'
import torch
import time
import sys

print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    device = torch.device("cuda")
    gpu_name = torch.cuda.get_device_name(0)
    vram = torch.cuda.get_device_properties(0).total_memory / (1024**3)
    print(f"GPU: {gpu_name}")
    print(f"VRAM: {vram:.1f} GB")

    # Warmup
    print("\nWarming up...")
    a = torch.randn(4096, 4096, device=device)
    b = torch.randn(4096, 4096, device=device)
    for _ in range(10):
        c = torch.matmul(a, b)
    torch.cuda.synchronize()

    # Matrix multiplication benchmark (simulates transformer inference)
    print("\nRunning inference benchmark (4096x4096 matmul)...")
    iterations = 100
    start = time.time()
    for _ in range(iterations):
        c = torch.matmul(a, b)
    torch.cuda.synchronize()
    elapsed = time.time() - start

    # Calculate TFLOPS (2 * n^3 flops for matmul)
    flops_per_iter = 2 * 4096**3
    total_flops = flops_per_iter * iterations
    tflops = total_flops / elapsed / 1e12

    print(f"Time: {elapsed:.3f}s for {iterations} iterations")
    print(f"Performance: {tflops:.2f} TFLOPS")

    # Ternary simulation (BitNet-style)
    print("\nRunning ternary inference simulation...")
    batch_size = 32
    seq_len = 512
    hidden_dim = 4096

    # Quantize to ternary-ish values
    weights = torch.randint(-1, 2, (hidden_dim, hidden_dim), device=device, dtype=torch.float16)
    inputs = torch.randn(batch_size, seq_len, hidden_dim, device=device, dtype=torch.float16)

    # Warmup
    for _ in range(10):
        out = torch.matmul(inputs, weights.T)
    torch.cuda.synchronize()

    # Benchmark
    iterations = 100
    start = time.time()
    for _ in range(iterations):
        out = torch.matmul(inputs, weights.T)
    torch.cuda.synchronize()
    elapsed = time.time() - start

    tokens_processed = batch_size * seq_len * iterations
    tokens_per_sec = tokens_processed / elapsed
    latency_ms = elapsed / iterations * 1000

    print(f"Batch size: {batch_size}")
    print(f"Sequence length: {seq_len}")
    print(f"Hidden dimension: {hidden_dim}")
    print(f"Tokens/second: {tokens_per_sec:,.0f}")
    print(f"Latency: {latency_ms:.2f} ms/batch")

    # Memory usage
    allocated = torch.cuda.memory_allocated() / (1024**3)
    reserved = torch.cuda.memory_reserved() / (1024**3)
    print(f"\nMemory allocated: {allocated:.2f} GB")
    print(f"Memory reserved: {reserved:.2f} GB")
else:
    print("ERROR: CUDA not available!")
    sys.exit(1)
PYEOF
echo ""

# 4. POWER MONITORING
echo "[4/5] Power & Temperature:"
nvidia-smi --query-gpu=power.draw,temperature.gpu,utilization.gpu --format=csv
echo ""

# 5. MINING HASHRATE SIMULATION
echo "[5/5] TriHash Mining Simulation..."
python3 << 'PYEOF'
import torch
import time
import hashlib

if torch.cuda.is_available():
    device = torch.device("cuda")

    # Simulate mining workload (SHA256-like on GPU)
    print("Running hash computation benchmark...")

    # Create random data to hash
    batch_size = 1_000_000
    data = torch.randint(0, 256, (batch_size, 32), device=device, dtype=torch.uint8)

    # Warmup
    for _ in range(5):
        # GPU tensor operations (simulate hash computation)
        hashed = torch.sum(data.float() * torch.arange(32, device=device).float(), dim=1)
        hashed = hashed % 256
    torch.cuda.synchronize()

    # Benchmark
    iterations = 50
    start = time.time()
    for _ in range(iterations):
        hashed = torch.sum(data.float() * torch.arange(32, device=device).float(), dim=1)
        hashed = hashed % 256
    torch.cuda.synchronize()
    elapsed = time.time() - start

    total_hashes = batch_size * iterations
    hashrate_mhs = total_hashes / elapsed / 1e6

    print(f"Total hashes: {total_hashes:,}")
    print(f"Time: {elapsed:.3f}s")
    print(f"Hashrate: {hashrate_mhs:.2f} MH/s")
else:
    print("CUDA not available!")
PYEOF
echo ""

# SUMMARY
echo "════════════════════════════════════════════════════════════════"
echo "   BENCHMARK COMPLETE"
echo "════════════════════════════════════════════════════════════════"
nvidia-smi --query-gpu=name,memory.total,power.draw,temperature.gpu --format=csv
echo ""
echo "Copy these results for the report!"
echo "φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL"
