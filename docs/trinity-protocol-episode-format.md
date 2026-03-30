# Trinity Protocol v2 — Episode Format

## Overview

This document defines the episode format used by Trinity agents when reporting actions to Queen. Episodes represent discrete units of work (e.g., fixing a bug, implementing a feature, responding to a task).

## Episode Structure

Each episode is a JSON object with the following fields:

```json
{
  "episode_id": "uuid-v4",
  "agent": "alpha|beta|gamma|...|omega|sampi|sho",
  "episode_type": "task|observation|action|error",
  "timestamp": "2026-03-31T12:00:00Z",
  "title": "Short human-readable title",
  "data": {
    "domain": "alpha|gamma|...|omega",
    "action": "created|deleted|completed|failed",
    "error_code": "string|number",
    "error_message": "string",
    "metrics": {
      "loss": 0.0,
      "accuracy": 0.95,
      "latency_ms": 120
    },
    "context": {
      "related_episode_id": "uuid-of-parent-episode",
      "issue_id": "#123",
      "files": ["src/file1.zig", "src/file2.zig"]
    },
    "thought": "Why did the agent take this action?",
    "next_step": "Verify on Railway Dashboard"
}
```

## Episode Types

### task
An atomic unit of work with clear success/failure criteria.
- Used for: Implementing a feature, fixing a bug, running a test.

### observation
Data collected or measurements from the environment.
- Used for: Benchmarking results, test outcomes, system metrics.

### action
State change or result of an operation.
- Used for: Code committed, test passed, deployment succeeded.

### error
Problem encountered during execution.
- Used for: Compilation failures, network errors, deployment issues.

## Episode Format for Agents (gamma, delta, etc.)

### Episode Header
```json
{
  "episode_id": "alpha_episode_2026_03_31_12_00_00",
  "agent": "gamma",
  "episode_type": "task",
  "timestamp": "2026-03-31T12:00:00Z",
  "title": "Implement caching layer for VSA bundle operations",
  "data": {
    "domain": "gamma",
    "action": "completed",
    "thought": "Bundle operations can be slow, need to cache frequently accessed vectors",
    "next_step": "Add cache invalidation logic"
  }
}
```

### Observation/Action Data

```json
{
  "domain": "gamma",
  "action": "completed",
  "file": "src/vsa/bundle.zig",
  "metrics": {
    "latency_ms": 45
  },
  "timestamp": "2026-03-31T12:05:00Z"
}
```

## Error Handling

### Standard Error Codes

| Code | Description | Example |
|------|-------------|---------|
| COMPILATION_FAILED | Zig compilation failed | {"code": "COMPILATION_FAILED", "message": "Zig compiler error output"} |
| RUNTIME_ERROR | Agent crashed during execution | {"code": "RUNTIME_ERROR", "message": "Process terminated unexpectedly"} |
| NETWORK_ERROR | HTTP request failed | {"code": "NETWORK_ERROR", "message": "Failed to connect to Queen API"} |
| VALIDATION_ERROR | Invalid input or malformed data | {"code": "VALIDATION_ERROR", "message": "Invalid episode format"} |

## Queen Episode Format

### Episode Header
```json
{
  "episode_id": "queen_episode_001",
  "agent": "queen",
  "episode_type": "orchestration|observation|action",
  "timestamp": "2026-03-31T12:00:00Z",
  "title": "Deployed Trinity Grid to Railway",
  "data": {
    "agent": "queen",
    "action": "created",
    "domain": "omega",
    "thought": "Initiating deployment of 27 agent services via Railway matrix strategy",
    "next_step": "Wait for agents to register with Queen"
  }
}
```

### Episode Action (Agent Registration)
```json
{
  "agent": "alpha",
  "action": "registered",
  "timestamp": "2026-03-31T12:30:15Z",
  "domain": "alpha",
  "episode_id": "alpha_reg_episode_001",
  "data": {
    "port": 9001,
    "agent_binary": "trinity-agent:latest",
    "queen_url": "http://queen:8080"
  }
}
```

### Episode Action (Agent Health Check)
```json
{
  "agent": "beta",
  "action": "healthy",
  "timestamp": "2026-03-31T12:30:20Z",
  "domain": "beta",
  "data": {
    "uptime_seconds": 3600,
    "http_status": 200
    "response_time_ms": 45
  }
}
```

## Agent Episode Format for Task Completion

When an agent completes a task successfully:

```json
{
  "episode_id": "gamma_task_2026_03_31_14_15:00Z",
  "agent": "gamma",
  "episode_type": "task",
  "timestamp": "2026-03-31T14:15:00Z",
  "title": "Implemented VSA caching layer",
  "data": {
    "action": "completed",
    "thought": "Bundle operations can be slow, need to cache frequently accessed vectors",
    "next_step": "Add cache invalidation logic",
    "metrics": {
      "latency_ms": 45,
      "throughput_per_sec": 1250
    },
    "files_modified": ["src/vsa/bundle.zig", "src/vsa/cache.zig"]
  }
}
```

## Notes

- Episode IDs must be version 4 UUIDs for deduplication across Trinity components
- Agent name should be one of the 27 Coptic alphabet domains (alpha through sho)
- Queen uses agent domain "omega"
- Timestamps should be ISO 8601 (RFC 3339) format: `YYYY-MM-DDTHH:MM:SS.sssZ` where milliseconds are always 3 digits

## Next Steps

1. Implement episode formatting in `src/tri/orchestration/` module
2. Add episode submission endpoints in Queen HTTP API
3. Create agent agent wrapper in `src/tri/agent/` for standardized episode logging
4. Design AutoImprove architecture around episode-based learning
