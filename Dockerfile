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

# Download Mistral-7B-Instruct Q4_K_M (best open source model for quality)
# Size: ~4.4GB, excellent instruction following
RUN echo "Downloading Mistral-7B-Instruct-v0.2 Q4_K_M..." && \
    curl -L -o /app/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf \
    "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf"

# Set environment
ENV MODEL_PATH=/app/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf
ENV TEMPERATURE=0.7
ENV TOP_P=0.9

# Expose port (for future HTTP API)
EXPOSE 8080

# Run chat
CMD ["/app/vibee", "chat", "--model", "/app/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf", "--temperature", "0.7", "--top-p", "0.9"]
