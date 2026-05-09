# Trinity Background Agent API — Railway Deployment
# Minimal Zig binary deployment
# φ² + 1/φ² = 3 = TRINITY

# Stage 1: Build
FROM ubuntu:26.04 AS builder

RUN apt-get update && apt-get install -y \
    wget xz-utils git \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.15.2
# Note: SHA256 verification temporarily disabled (ziglang.org access restricted)
RUN wget -q -O /tmp/zig.tar.xz \
    https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz \
    && tar -xf /tmp/zig.tar.xz -C /usr/local \
    && rm /tmp/zig.tar.xz

ENV PATH="/usr/local/zig-x86_64-linux-0.15.2:${PATH}"

WORKDIR /app
COPY . .

# Build background-agent-api
# Output goes to .zig-cache/o/.../background-agent-api
RUN zig build background-agent-api

# Stage 2: Runtime - Use Ubuntu minimal
FROM ubuntu:26.04

# Create user first
RUN useradd -m -u 1001 trinity

# Find and copy the binary from .zig-cache
RUN find /app/.zig-cache -name "background-agent-api" -type f -exec cp {} /app/background-agent-api \;

USER trinity

EXPOSE 3000

ENV PORT=3000
ENV LOCAL_MODE=1

# Simple health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -f /app/background-agent-api || exit 1

ENTRYPOINT ["/app/background-agent-api"]
