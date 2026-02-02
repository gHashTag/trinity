# TRINITY LLM - Zig-based LLM Inference Engine
# phi^2 + 1/phi^2 = 3 = TRINITY
# 
# Uses Fly.io Volumes for NVMe SSD storage (16x faster than ephemeral)

FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and install Zig 0.14.0
RUN curl -L https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz | tar -xJ -C /opt \
    && ln -s /opt/zig-linux-x86_64-0.14.0/zig /usr/local/bin/zig

WORKDIR /build

# Copy source code
COPY src/ src/

# Build the binary with release optimizations
RUN zig build-exe src/vibeec/gen_cmd.zig --name vibee -OReleaseFast \
    && chmod +x vibee

# Runtime stage - minimal image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/vibee /app/vibee

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set environment
# MODEL_PATH points to volume mount (NVMe SSD)
ENV MODEL_PATH=/data/models/smollm2-1.7b-instruct-q8_0.gguf
ENV TEMPERATURE=0.7
ENV TOP_P=0.9
ENV NUM_THREADS=16

# Run HTTP API server
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
