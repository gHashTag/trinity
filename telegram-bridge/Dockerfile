# Build stage - use latest Go with auto toolchain
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git ca-certificates

# Enable automatic toolchain download
ENV GOTOOLCHAIN=auto

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /telegram-bridge ./cmd/server

# Runtime stage
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Create sessions directory
RUN mkdir -p /app/sessions

# Copy binary from builder
COPY --from=builder /telegram-bridge /app/telegram-bridge

# Non-root user
RUN adduser -D -u 1000 vibee
RUN chown -R vibee:vibee /app
USER vibee

EXPOSE 9000

CMD ["/app/telegram-bridge"]
