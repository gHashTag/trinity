# Trinity HTTP API Status

## Implementation Status

**Last Updated**: 2026-03-26

## Overview

Trinity includes **multiple HTTP server implementations** for different purposes:

| Server | Location | Purpose | Status |
|--------|----------|---------|--------|
| **VIBEE HTTP Server** | `src/vibeec/http_server.zig` | OpenAI-compatible LLM API | ✅ Implemented |
| **DePIN Node API** | `src/trinity_node/http_api.zig` | Storage/rewards/metrics | ✅ Implemented |
| **Unified API Layer** | `src/api/unified_server.zig` | REST + GraphQL + gRPC + WebSocket registry | ✅ Implemented |

## Endpoints

### VIBEE HTTP Server (`src/vibeec/http_server.zig`)

```
POST /v1/chat/completions  - OpenAI-compatible chat completion (streaming + non-streaming)
GET  /health               - Health check
GET  /healthz              - Liveness probe (K8s style)
GET  /readyz               - Readiness probe
GET  /metrics              - Prometheus metrics
GET  /                     - Server info and metrics
POST /vsa/bundle           - Bundle vectors (batched)
POST /vsa/bind             - Bind vectors
POST /vsa/unbind           - Unbind vectors
GET  /api/agent-mu/status  - Intelligence metrics
GET  /api/agent-mu/history - Intelligence history
GET  /api/agent-mu/forecast - Predictive forecasting
GET  /api/agent-mu/evolution-tree - Evolution tree
GET  /api/agent-mu/sacred-math - Sacred constants
```

### DePIN Node API (`src/trinity_node/http_api.zig`)

```
GET  /health               - Health check
GET  /node/status          - Node status
GET  /node/stats           - Statistics and earnings
POST /node/claim           - Claim rewards
GET  /node/tier            - Wallet tier info
GET  /rewards/rates        - Reward rates
GET  /rewards/history      - Reward history
GET  /storage/stats        - Storage statistics
POST /search               - Search shards
GET  /wallet/balance       - Wallet balance
GET  /metrics              - Prometheus metrics
```

## Version Notes

- **CLI Version**: v1.0.2 "HEARTBEAT" (see CHANGELOG.md)
- **Research Bundle Version**: v5.2 (see Zenodo publications)
- These serve different purposes:
  - CLI version tracks the command-line tool releases
  - Research bundle version tracks scientific publication bundles

## Running the Servers

```bash
# Build the servers
zig build

# Run VIBEE HTTP server (chat completions)
./zig-out/bin/vibeec-http-server --model-path ./models/model.gguf --port 8080

# Run DePIN node (includes HTTP API)
./zig-out/bin/trinity-node --http-port 8080
```

## API Documentation

- Full API reference: [docs/api_reference.md](../docs/api_reference.md)
- DePIN architecture: [docs/depin/architecture](../docs/depin/architecture)

## Notes

- All servers support CORS (`Access-Control-Allow-Origin: *`)
- Prometheus metrics available at `/metrics` endpoint
- OpenAI-compatible format for `/v1/chat/completions`
