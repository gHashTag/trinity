# Trinity HSLM Training — Local Docker Build
# Builds from source (no prebuilt binaries required)
#
# φ² + 1/φ² = 3 = TRINITY

FROM ubuntu:24.04

# Install Zig build dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates curl wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.15.2
RUN wget -q https://ziglang.org/download/0.15.2/zig-linux-x86_64.tar.xz \
    -O /tmp/zig.tar.xz \
    && tar -xf /tmp/zig.tar.xz -C /usr/local \
    && rm /tmp/zig.tar.xz

# Set PATH for Zig
ENV PATH="/usr/local/zig-linux-x86_64-0.15.2:${PATH}"

# Copy Trinity source code
COPY . /trinity
WORKDIR /trinity

# Build HSLM training binaries
RUN zig build hslm-train hslm-entrypoint -Doptimize=ReleaseFast

# Setup data directories
RUN mkdir -p /data/tinystories /data/checkpoints

# Download TinyStories dataset (baked into image)
RUN wget -q "https://huggingface.co/datasets/roneneldan/TinyStories/resolve/main/TinyStoriesV2-GPT4-train.txt" \
    -O /data/tinystories/train_100k.txt && \
    echo "Dataset downloaded: $(wc -l < /data/tinystories/train_100k.txt) lines"

WORKDIR /data

ENTRYPOINT ["/trinity/zig-out/bin/hslm-entrypoint"]

LABEL version="2.3.0-local" \
      description="Trinity HSLM Training — ternary language model on TinyStories (local build)" \
      trinity.identity="phi^2 + 1/phi^2 = 3" \
      trinity.service="ai-training" \
      trinity.purpose="nlp-research"
