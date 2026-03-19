#!/bin/bash
# Trinity GPU Benchmark Runner

echo "=== TRINITY GPU BENCHMARK ==="
echo ""

# Show GPU info
echo "GPU Information:"
nvidia-smi --query-gpu=name,memory.total,memory.free,compute_cap,driver_version --format=csv
echo ""

# Show CUDA version
echo "CUDA Version:"
nvcc --version | grep release
echo ""

# Run CPU benchmark
echo "Running CPU Baseline Benchmark..."
./trinity-gpu-bench

# Run CUDA benchmark if available
if [ -f "./trinity-cuda-bench" ]; then
    echo ""
    echo "Running CUDA Benchmark..."
    ./trinity-cuda-bench
fi

echo ""
echo "Benchmark complete!"
