---
sidebar_label: 'API Reference'
title: 'Node HTTP API'
description: 'REST API endpoints for Trinity Node'
---

# Node HTTP API Reference

:::info Testnet
All example responses below show testnet values. Actual values will vary based on your node's activity and network state.
:::

Every Trinity node exposes an HTTP API on port **8080** (configurable). The API is OpenAI-compatible for chat completions and provides additional endpoints for node management, storage, and DePIN operations.

## Base URL

```
http://localhost:8080
```

## Endpoints Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Server info and metrics |
| `GET` | `/health` | Health check |
| `POST` | `/v1/chat/completions` | Chat completion (OpenAI-compatible) |
| `GET` | `/v1/node/stats` | Node statistics and earnings |
| `POST` | `/v1/node/claim` | Claim pending $TRI rewards |
| `POST` | `/v1/storage/put` | Store a data shard |
| `GET` | `/v1/storage/get/:hash` | Retrieve a data shard |
| `GET` | `/v1/storage/status` | Storage layer status |
| `GET` | `/metrics` | Prometheus metrics (port 9090) |
| `OPTIONS` | `/v1/chat/completions` | CORS preflight |

---

## GET /

Returns server identification and runtime metrics.

**Request:**

```bash
curl http://localhost:8080/
```

**Response:**

```json
{
  "name": "TRINITY LLM",
  "version": "1.4.0",
  "endpoints": ["/v1/chat/completions", "/health", "/metrics"],
  "metrics": {
    "total_requests": 1523,
    "active_requests": 2,
    "total_tokens": 48210,
    "throughput_tok_s": 14.72
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Server name |
| `version` | string | Server version |
| `endpoints` | string[] | Available endpoints |
| `metrics.total_requests` | number | Total requests served since startup |
| `metrics.active_requests` | number | Currently processing requests |
| `metrics.total_tokens` | number | Total tokens generated |
| `metrics.throughput_tok_s` | number | Current throughput in tokens/second |

---

## GET /health

Lightweight health check. Use this for load balancers and monitoring.

**Request:**

```bash
curl http://localhost:8080/health
```

**Response:**

```json
{
  "status": "ok",
  "model": "loaded"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | `"ok"` when healthy |
| `model` | string | `"loaded"` when model is ready for inference |

**Status Codes:**

| Code | Meaning |
|------|---------|
| 200 | Node is healthy |
| 503 | Node is starting up or unhealthy |

---

## POST /v1/chat/completions

OpenAI-compatible chat completion endpoint. Supports both standard and streaming responses.

### Standard Request

**Request:**

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "trinity-llm",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is ternary computing?"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

**Response:**

```json
{
  "id": "chatcmpl-trinity",
  "object": "chat.completion",
  "created": 1700000000,
  "model": "trinity-llm",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Ternary computing uses three-valued logic {-1, 0, +1} instead of binary {0, 1}..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 24,
    "completion_tokens": 50,
    "total_tokens": 74
  }
}
```

### Streaming Request

Set `"stream": true` to receive Server-Sent Events (SSE).

**Request:**

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "trinity-llm",
    "messages": [
      {"role": "user", "content": "Explain VSA in one sentence."}
    ],
    "stream": true
  }'
```

**Response (SSE):**

```
data: {"choices":[{"delta":{"content":"Vector"},"index":0}]}

data: {"choices":[{"delta":{"content":" Symbolic"},"index":0}]}

data: {"choices":[{"delta":{"content":" Architecture"},"index":0}]}

data: [DONE]
```

### Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `model` | string | No | `"trinity-llm"` | Model identifier |
| `messages` | array | Yes | -- | Chat messages array |
| `messages[].role` | string | Yes | -- | `"system"`, `"user"`, or `"assistant"` |
| `messages[].content` | string | Yes | -- | Message content |
| `temperature` | number | No | 0.7 | Sampling temperature (0.0 = greedy) |
| `top_p` | number | No | 0.9 | Nucleus sampling threshold |
| `top_k` | number | No | 40 | Top-k sampling |
| `max_tokens` | number | No | 100 | Maximum tokens to generate |
| `stream` | boolean | No | false | Enable SSE streaming |
| `repeat_penalty` | number | No | 1.1 | Repetition penalty |

---

## GET /v1/node/stats

Returns current node statistics including earnings and operational metrics.

**Request:**

```bash
curl http://localhost:8080/v1/node/stats
```

**Response:**

```json
{
  "status": "earning",
  "operations": 4521,
  "earned_tri": 12.847,
  "pending_tri": 0.093,
  "uptime_hours": 168.3,
  "wallet": "0x1a2b3c4d5e6f7890abcdef1234567890abcdef12"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Node status: `"offline"`, `"syncing"`, `"online"`, `"earning"` |
| `operations` | number | Total operations completed |
| `earned_tri` | number | Total $TRI earned (claimed + pending) |
| `pending_tri` | number | Unclaimed $TRI rewards |
| `uptime_hours` | number | Total uptime in hours |
| `wallet` | string | Node wallet address (hex) |

---

## POST /v1/node/claim

Claims all pending $TRI rewards and moves them to the wallet balance.

**Request:**

```bash
curl -X POST http://localhost:8080/v1/node/claim
```

**Response:**

```json
{
  "claimed": 0.093,
  "new_balance": 12.940,
  "nonce": 47,
  "tx_hash": "0xabc123..."
}
```

| Field | Type | Description |
|-------|------|-------------|
| `claimed` | number | Amount of $TRI claimed |
| `new_balance` | number | Updated wallet balance |
| `nonce` | number | Transaction nonce |
| `tx_hash` | string | On-chain transaction hash |

---

## POST /v1/storage/put

Store a data shard on the network. The shard is Reed-Solomon encoded and replicated.

**Request:**

```bash
curl -X POST http://localhost:8080/v1/storage/put \
  -H "Content-Type: application/octet-stream" \
  --data-binary @myfile.bin
```

**Response:**

```json
{
  "hash": "0xdeadbeef...",
  "size_bytes": 4096,
  "shards": 3,
  "replicas": 3,
  "ttl_hours": 720
}
```

| Field | Type | Description |
|-------|------|-------------|
| `hash` | string | Content hash (used for retrieval) |
| `size_bytes` | number | Original data size |
| `shards` | number | Number of erasure-coded shards |
| `replicas` | number | Replication factor |
| `ttl_hours` | number | Time-to-live before expiry |

---

## GET /v1/storage/get/:hash

Retrieve a stored data shard by its content hash.

**Request:**

```bash
curl http://localhost:8080/v1/storage/get/0xdeadbeef...
```

**Response:**

Binary data with `Content-Type: application/octet-stream`.

**Status Codes:**

| Code | Meaning |
|------|---------|
| 200 | Shard found and returned |
| 404 | Shard not found on this node |
| 410 | Shard expired (TTL exceeded) |

---

## GET /v1/storage/status

Returns storage layer statistics.

**Request:**

```bash
curl http://localhost:8080/v1/storage/status
```

**Response:**

```json
{
  "total_shards": 1247,
  "total_size_mb": 512.3,
  "lru_cache_size": 256,
  "lru_hit_rate": 0.847,
  "reed_solomon_overhead": 1.5
}
```

| Field | Type | Description |
|-------|------|-------------|
| `total_shards` | number | Number of shards stored locally |
| `total_size_mb` | number | Total storage used in MB |
| `lru_cache_size` | number | LRU cache entries |
| `lru_hit_rate` | number | Cache hit rate (0.0 -- 1.0) |
| `reed_solomon_overhead` | number | Storage overhead multiplier |

---

## GET /metrics (Port 9090)

Prometheus-compatible metrics endpoint served on port 9090.

**Request:**

```bash
curl http://localhost:9090/metrics
```

**Response (Prometheus format):**

```
# HELP trinity_operations_total Total DePIN operations completed
# TYPE trinity_operations_total counter
trinity_operations_total{type="evolution"} 1200
trinity_operations_total{type="navigation"} 3400
trinity_operations_total{type="storage_hosting"} 800
trinity_operations_total{type="benchmark"} 120

# HELP trinity_earned_tri_total Total $TRI earned
# TYPE trinity_earned_tri_total counter
trinity_earned_tri_total 12.847

# HELP trinity_uptime_seconds Node uptime in seconds
# TYPE trinity_uptime_seconds gauge
trinity_uptime_seconds 605880

# HELP trinity_peers_connected Number of connected peers
# TYPE trinity_peers_connected gauge
trinity_peers_connected 7

# HELP trinity_inference_throughput_tokens_per_second Current inference throughput
# TYPE trinity_inference_throughput_tokens_per_second gauge
trinity_inference_throughput_tokens_per_second 14.72
```

---

## OPTIONS /v1/chat/completions

CORS preflight handler. Returns appropriate headers for cross-origin requests.

**Response Headers:**

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST, GET, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## Error Codes

All errors return JSON with an `error` field.

| HTTP Code | Error | Description |
|-----------|-------|-------------|
| 400 | `Bad Request` | Malformed JSON or missing required fields |
| 404 | `Not Found` | Endpoint does not exist |
| 405 | `Method Not Allowed` | Wrong HTTP method for endpoint |
| 413 | `Payload Too Large` | Request body exceeds 16 KB limit |
| 429 | `Too Many Requests` | Rate limit exceeded |
| 500 | `Internal Server Error` | Unexpected server error |
| 503 | `Service Unavailable` | Model not loaded or node is syncing |

**Error response format:**

```json
{
  "error": "Not Found"
}
```

---

## Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/v1/chat/completions` | 60 requests | per minute |
| `/v1/storage/put` | 100 requests | per minute |
| `/v1/storage/get/:hash` | 300 requests | per minute |
| `/v1/node/claim` | 1 request | per minute |
| All other endpoints | 120 requests | per minute |

Rate limits are applied per IP address. Exceeding the limit returns HTTP 429.

---

## Authentication (Future)

:::info Coming Soon
API key authentication is planned for a future release. Currently, the API is unauthenticated and should only be exposed on trusted networks.
:::

When authentication is enabled, include the API key in the `Authorization` header:

```bash
curl -H "Authorization: Bearer tri_your_api_key_here" \
  http://localhost:8080/v1/chat/completions
```

## Next Steps

- [Quick Start](./quickstart.md) -- get your node running
- [Architecture](./architecture.md) -- understand the network internals
- [Rewards](./rewards.md) -- how API operations translate to earnings
