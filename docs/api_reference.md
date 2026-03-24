# Trinity API Reference

Complete reference for Trinity HTTP API, CLI API, and MCP servers.

---

## HTTP API

### Base URL
```
http://localhost:8080
```

### Authentication

#### Wallet-Based Authentication
Include your wallet address in headers:
```http
X-Wallet: 0xYOUR_WALLET_ADDRESS
```

#### API Keys
If using API keys:
```http
Authorization: Bearer YOUR_API_KEY
```

### Endpoints

#### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "ok",
  "version": "1.0.2"
}
```

#### Server Info
```http
GET /
```

**Response:**
```json
{
  "name": "Trinity Node",
  "version": "1.0.2",
  "uptime": 3600,
  "models": ["trinity-llm", "hslm-tiny"]
}
```

#### Chat Completion
```http
POST /v1/chat/completions
```

**Headers:**
```
Content-Type: application/json
X-Wallet: 0xYOUR_WALLET_ADDRESS
```

**Body:**
```json
{
  "model": "trinity-llm",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "max_tokens": 100,
  "temperature": 0.7
}
```

**Response:**
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "trinity-llm",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you today?"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 9,
    "completion_tokens": 12,
    "total_tokens": 21
  }
}
```

#### Node Statistics
```http
GET /v1/node/stats
```

**Response:**
```json
{
  "wallet": "0xYOUR_WALLET",
  "tier": "Power",
  "earnings": {
    "total": 123.456,
    "available": 45.678,
    "staked": 77.778
  },
  "uptime": 86400,
  "requests_served": 1234
}
```

#### Wallet Tier Info
```http
GET /v1/node/tier
```

**Response:**
```json
{
  "wallet": "0xYOUR_WALLET",
  "tier": "Power",
  "staked": 1000,
  "rate_limit": {
    "requests_per_minute": 300,
    "current_usage": 45
  },
  "reward_multiplier": 2.0
}
```

#### Claim Rewards
```http
POST /v1/node/claim
```

**Response:**
```json
{
  "claimed": 12.345,
  "remaining": 33.333,
  "tx_hash": "0xabc123..."
}
```

#### Storage: Put Shard
```http
POST /v1/storage/put
```

**Headers:**
```
Content-Type: application/octet-stream
```

**Body:** Binary data

**Response:**
```json
{
  "hash": "QmXxx...",
  "size": 1024
}
```

#### Storage: Get Shard
```http
GET /v1/storage/get/:hash
```

**Response:** Binary data

#### Storage: Status
```http
GET /v1/storage/status
```

**Response:**
```json
{
  "stored_shards": 123,
  "total_size": 12582912,
  "replication_factor": 3
}
```

### Error Responses

All endpoints may return errors in this format:

```json
{
  "error": {
    "message": "Error description",
    "type": "invalid_request_error",
    "code": "E0501"
  }
}
```

### Error Codes

| Code | Description |
|------|-------------|
| E0401 | Unauthorized |
| E0403 | Forbidden |
| E0404 | Not found |
| E0501 | Memory management error |
| E0502 | Allocator leak |
| E0601 | UART timeout |
| E0701 | Training configuration error |
| E0801 | Agent token expired |

---

## CLI API

### Basic Usage
```bash
tri <command> [subcommand] [options]
```

### Global Options

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Enable verbose output |
| `--dry-run` | | Show what would be done without doing it |
| `--yes` | `-y` | Auto-confirm prompts |
| `--json` | | Output in JSON format |
| `--output <format>` | | Output format: json, yaml, text |
| `--help` | `-h` | Show help |

### Command Categories

See [README.md](../README.md#all-commands-30-command-groups) for complete command reference.

---

## MCP Servers

### Trinity MCP Server

**Location:** `tools/mcp/trinity_mcp/`

**Tools:** 47+

**Configuration:**
```json
{
  "mcpServers": {
    "trinity": {
      "command": "zig",
      "args": ["build", "trinity-mcp"],
      "env": {
        "TRINITY_PROJECT_PATH": "/path/to/trinity"
      }
    }
  }
}
```

### Needle MCP Server

**Tools:** 6 (structural_replace, search, quality_gates)

### Zig-Docs MCP Server

**Tools:** 4 (builtins, std lib search)

---

## Examples

### Chat Completion with Python
```python
import requests

headers = {
    "Content-Type": "application/json",
    "X-Wallet": "0xYOUR_WALLET"
}

data = {
    "model": "trinity-llm",
    "messages": [{"role": "user", "content": "Explain VSA"}]
}

response = requests.post("http://localhost:8080/v1/chat/completions", 
                        json=data, headers=headers)
print(response.json())
```

### Chat Completion with curl
```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "X-Wallet: 0xYOUR_WALLET" \
  -d '{
    "model": "trinity-llm",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## Rate Limiting

By tier (wallet-based):

| Tier | Staked | Rate Limit |
|------|--------|------------|
| Free | 0 | 10 req/min |
| Staker | 100+ | 60 req/min |
| Power | 1,000+ | 300 req/min |
| Whale | 10,000+ | Unlimited |

---

## WebSocket API (Planned)

Future versions will support WebSocket connections for real-time streaming.

---

*Last updated: 2026-03-24*
