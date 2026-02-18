# Trinity GPU Benchmark Dockerfile
# CUDA 12.x + Zig for ternary matmul benchmarks

FROM nvidia/cuda:12.2.0-devel-ubuntu22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.13.0
RUN curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ -C /opt
ENV PATH="/opt/zig-linux-x86_64-0.13.0:${PATH}"

WORKDIR /app

# Copy benchmark code
COPY benchmark.zig .
COPY run_benchmark.sh .

RUN chmod +x run_benchmark.sh

# Build benchmark
RUN zig build-exe benchmark.zig -O ReleaseFast -o trinity-gpu-bench

CMD ["./run_benchmark.sh"]
