# TRINITY LLM - Zig-based LLM Inference Engine
# phi^2 + 1/phi^2 = 3 = TRINITY

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

# Create models directory
RUN mkdir -p /app/models

# Download TinyLlama-1.1B Q8_0 (supported quantization format)
# Size: ~1.1GB, fast inference, good for testing
RUN echo "Downloading TinyLlama-1.1B-Chat Q8_0..." && \
    curl -L -o /app/models/tinyllama-1.1b-chat-v1.0.Q8_0.gguf \
    "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf"

# Set environment
ENV MODEL_PATH=/app/models/tinyllama-1.1b-chat-v1.0.Q8_0.gguf
ENV TEMPERATURE=0.7
ENV TOP_P=0.9

# Keep container running for SSH access
CMD ["/bin/sleep", "infinity"]
