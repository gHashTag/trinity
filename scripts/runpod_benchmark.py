#!/usr/bin/env python3
"""
Trinity GPU Benchmark Script for RunPod
Runs inference, mining, and noise robustness tests on GPU
"""

import subprocess
import time
import json
import os

def run_cmd(cmd, timeout=300):
    """Run command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except Exception as e:
        return f"ERROR: {e}"

def get_gpu_info():
    """Get GPU information via nvidia-smi"""
    info = run_cmd("nvidia-smi --query-gpu=name,memory.total,memory.used,power.draw,temperature.gpu --format=csv,noheader,nounits")
    return info.strip()

def get_gpu_power():
    """Get current GPU power draw"""
    power = run_cmd("nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits")
    try:
        return float(power.strip())
    except:
        return 0.0

def benchmark_inference():
    """Run inference benchmark"""
    results = {
        "test": "inference",
        "gpu_info": get_gpu_info(),
        "tokens_generated": 0,
        "tokens_per_second": 0,
        "latency_ms": 0,
        "memory_used_gb": 0,
        "power_watts": 0
    }
    
    # Check if Trinity inference binary exists
    if os.path.exists("/workspace/trinity/bin/vibee"):
        # Run actual inference test
        start = time.time()
        output = run_cmd("cd /workspace/trinity && ./bin/vibee run examples/inference_test.999 2>&1", timeout=120)
        elapsed = time.time() - start
        
        results["raw_output"] = output[:1000]
        results["elapsed_seconds"] = elapsed
        results["power_watts"] = get_gpu_power()
    else:
        # Simulated test with PyTorch to verify GPU works
        test_code = '''
import torch
import time

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device: {device}")
print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A'}")

# Matrix multiplication benchmark (simulates inference workload)
size = 4096
a = torch.randn(size, size, device=device)
b = torch.randn(size, size, device=device)

# Warmup
for _ in range(10):
    c = torch.matmul(a, b)
torch.cuda.synchronize()

# Benchmark
start = time.time()
iterations = 100
for _ in range(iterations):
    c = torch.matmul(a, b)
torch.cuda.synchronize()
elapsed = time.time() - start

tflops = (2 * size**3 * iterations) / elapsed / 1e12
print(f"Matrix mult {size}x{size}: {elapsed:.3f}s for {iterations} iterations")
print(f"Performance: {tflops:.2f} TFLOPS")
print(f"Memory allocated: {torch.cuda.memory_allocated()/1e9:.2f} GB")
'''
        with open("/tmp/gpu_test.py", "w") as f:
            f.write(test_code)
        
        output = run_cmd("python3 /tmp/gpu_test.py 2>&1")
        results["raw_output"] = output
        results["power_watts"] = get_gpu_power()
        
        # Parse TFLOPS from output
        for line in output.split("\n"):
            if "TFLOPS" in line:
                try:
                    results["tflops"] = float(line.split(":")[1].strip().split()[0])
                except:
                    pass
    
    return results

def benchmark_mining():
    """Run TriHash mining benchmark"""
    results = {
        "test": "mining",
        "gpu_info": get_gpu_info(),
        "hashrate_mh_s": 0,
        "power_watts": 0,
        "efficiency_mh_per_watt": 0
    }
    
    # GPU hashing benchmark using CUDA
    test_code = '''
import torch
import time
import hashlib

device = torch.device("cuda")
print(f"Mining benchmark on {torch.cuda.get_device_name(0)}")

# Simulate ternary hash computation with tensor operations
# TriHash uses ternary (-1, 0, 1) values
batch_size = 1000000
trit_width = 256

# Generate random ternary data
data = torch.randint(-1, 2, (batch_size, trit_width), device=device, dtype=torch.int8)

# Warmup
for _ in range(5):
    # Ternary operations: balanced ternary arithmetic
    result = torch.sum(data * data, dim=1)  # Simple hash-like operation
torch.cuda.synchronize()

# Benchmark
start = time.time()
iterations = 100
for _ in range(iterations):
    # Simulate TriHash v2_opt operations
    h1 = torch.sum(data * data, dim=1)
    h2 = torch.sum(torch.abs(data), dim=1)
    combined = h1 ^ h2.int()
torch.cuda.synchronize()
elapsed = time.time() - start

total_hashes = batch_size * iterations
hashrate = total_hashes / elapsed / 1e6  # MH/s
print(f"Processed {total_hashes:,} hashes in {elapsed:.3f}s")
print(f"Hashrate: {hashrate:.2f} MH/s")
'''
    with open("/tmp/mining_test.py", "w") as f:
        f.write(test_code)
    
    output = run_cmd("python3 /tmp/mining_test.py 2>&1")
    results["raw_output"] = output
    results["power_watts"] = get_gpu_power()
    
    # Parse hashrate
    for line in output.split("\n"):
        if "MH/s" in line:
            try:
                results["hashrate_mh_s"] = float(line.split(":")[1].strip().split()[0])
            except:
                pass
    
    if results["power_watts"] > 0 and results["hashrate_mh_s"] > 0:
        results["efficiency_mh_per_watt"] = results["hashrate_mh_s"] / results["power_watts"]
    
    return results

def benchmark_noise_robustness():
    """Test noise robustness with trit flipping"""
    results = {
        "test": "noise_robustness",
        "gpu_info": get_gpu_info(),
        "noise_levels": [],
        "accuracy_retention": []
    }
    
    test_code = '''
import torch
import numpy as np

device = torch.device("cuda")
print(f"Noise robustness test on {torch.cuda.get_device_name(0)}")

# Create ternary weight matrix (simulating .tri model)
size = 1024
weights = torch.randint(-1, 2, (size, size), device=device, dtype=torch.float32)
input_data = torch.randn(100, size, device=device)

# Baseline inference
baseline = torch.matmul(input_data, weights)

noise_levels = [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30]
results = []

for noise in noise_levels:
    # Apply noise (flip trits with probability = noise)
    mask = torch.rand_like(weights) < noise
    flip_values = torch.randint(-1, 2, weights.shape, device=device, dtype=torch.float32)
    noisy_weights = torch.where(mask, flip_values, weights)
    
    # Inference with noisy weights
    noisy_output = torch.matmul(input_data, noisy_weights)
    
    # Calculate accuracy (cosine similarity)
    cos_sim = torch.nn.functional.cosine_similarity(
        baseline.flatten().unsqueeze(0),
        noisy_output.flatten().unsqueeze(0)
    ).item()
    
    accuracy = max(0, cos_sim) * 100
    results.append((noise * 100, accuracy))
    print(f"Noise {noise*100:.0f}%: Accuracy retention {accuracy:.1f}%")

print("\\nSummary:")
for noise, acc in results:
    print(f"  {noise:.0f}% noise -> {acc:.1f}% accuracy")
'''
    with open("/tmp/noise_test.py", "w") as f:
        f.write(test_code)
    
    output = run_cmd("python3 /tmp/noise_test.py 2>&1")
    results["raw_output"] = output
    
    # Parse results
    for line in output.split("\n"):
        if "Noise" in line and "Accuracy" in line:
            try:
                parts = line.split(":")
                noise = float(parts[0].split()[-1].replace("%", ""))
                acc = float(parts[1].strip().split()[0].replace("%", ""))
                results["noise_levels"].append(noise)
                results["accuracy_retention"].append(acc)
            except:
                pass
    
    return results

def main():
    """Run all benchmarks and output results"""
    print("=" * 60)
    print("TRINITY GPU BENCHMARK - RunPod RTX 4090")
    print("=" * 60)
    
    all_results = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        "gpu_info": get_gpu_info(),
        "benchmarks": {}
    }
    
    print("\n[1/3] Running inference benchmark...")
    all_results["benchmarks"]["inference"] = benchmark_inference()
    
    print("\n[2/3] Running mining benchmark...")
    all_results["benchmarks"]["mining"] = benchmark_mining()
    
    print("\n[3/3] Running noise robustness test...")
    all_results["benchmarks"]["noise"] = benchmark_noise_robustness()
    
    print("\n" + "=" * 60)
    print("BENCHMARK COMPLETE")
    print("=" * 60)
    
    # Output JSON results
    print("\n--- JSON RESULTS ---")
    print(json.dumps(all_results, indent=2))
    
    return all_results

if __name__ == "__main__":
    main()
