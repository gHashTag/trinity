# VIBEE v8 - Production Swarm Runtime Dockerfile
# Multi-stage build for minimal image size

# Stage 1: Build stage
FROM ziglang/zig:0.15.2-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git musl-dev

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Generate production swarm code
RUN zig build vibee -- gen specs/tri/vsa_swarm_production_32.vibee

# Build the swarm runtime binary
RUN zig build -Drelease-safe=true swarm-runtime

# Stage 2: Runtime stage (minimal Alpine)
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    ca-certificates

# Create non-root user
RUN addgroup -g 1000 trinity && \
    adduser -D -u 1000 -G trinity trinity

# Copy binary from builder
COPY --from=builder /app/zig-out/bin/swarm-runtime /usr/local/bin/swarm-runtime

# Copy generated code (for self-improvement analysis)
COPY --from=builder /app/generated /app/generated

# Create directories for specs
RUN mkdir -p /app/specs/tri

# Set permissions
RUN chown -R trinity:trinity /app /usr/local/bin/swarm-runtime

# Switch to non-root user
USER trinity

# Set working directory
WORKDIR /app

# Expose Prometheus metrics port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:9090/metrics || exit 1

# Default command
CMD ["swarm-runtime"]
