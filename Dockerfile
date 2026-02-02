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

# Download SmolLM-135M Q8_0 (official HuggingFace model)
# Size: ~145MB, loads in <1 second, good for demos
RUN echo "Downloading SmolLM-135M-Instruct Q8_0..." && \
    curl -L -o /app/models/smollm-135m-instruct-q8_0.gguf \
    "https://huggingface.co/HuggingFaceTB/smollm-135M-instruct-v0.2-Q8_0-GGUF/resolve/main/smollm-135m-instruct-add-basics-q8_0.gguf" && \
    ls -la /app/models/

# Set environment
ENV MODEL_PATH=/app/models/smollm-135m-instruct-q8_0.gguf
ENV TEMPERATURE=0.7
ENV TOP_P=0.9

# Run HTTP API server
EXPOSE 8080
CMD ["/app/vibee", "serve", "--model", "/app/models/smollm-135m-instruct-q8_0.gguf", "--port", "8080"]
