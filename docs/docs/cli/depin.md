# DePIN Node Protocol

Phase 1: Treat Railway services as DePIN nodes.

## Node Types

| Type | Pattern | Description |
|------|---------|-------------|
| TRAIN | `hslm-*`, `*train*` | Training workloads |
| CODE | `agent-*`, `*code*` | Code generation agents |
| INFER | everything else | Inference/API services |

## Commands

### `tri depin status`

Network overview dashboard showing:
- Accounts online (out of 3)
- Total nodes and active count
- Node distribution by type
- Network health percentage and grade

### `tri depin nodes`

Detailed list of all nodes with type, status, account, and name.

### `tri depin fitness`

Aggregate fitness by node type with active/total ratios.

## Health Grades

| Score | Grade |
|-------|-------|
| 80%+ | HEALTHY |
| 50-79% | DEGRADED |
| 0-49% | CRITICAL |
