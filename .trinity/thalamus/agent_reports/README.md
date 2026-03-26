# Agent Reports — Thalamus Layer

Thalamus routes sensory input to appropriate cortex regions. Here: structured agent reports for Queen visibility.

## JSON Schema

```json
{
  "id": "mem_<timestamp>_<agent>_<hash>",
  "agent": "ralph|mu|scholar|oracle|queen",
  "issue": "NNN",
  "task": "short description",
  "status": "in_progress|completed|blocked|failed",
  "steps": [...],
  "files_modified": [...],
  "tests_passing": 42,
  "tests_total": 42,
  "commit_hash": "abc123def",
  "timestamp": 1234567890,
  "ttt_touched": false,
  "metadata": {...}
}
```

## Example Report

See `.trinity/thalamus/agent_reports/example_2026-03-25.json`
