# SWE Arena Benchmark Tasks

Standardized benchmark suite for evaluating SWE agents.

## Tasks

| ID | Difficulty | Title |
|----|-----------|-------|
| E1 | Easy | Fix unused variable warning |
| E2 | Easy | Add missing error handling |
| E3 | Easy | Fix string formatting |
| M1 | Medium | Add new CLI subcommand |
| M2 | Medium | Implement config file parser |
| M3 | Medium | Add HTTP health endpoint |
| M4 | Medium | Implement retry logic |
| H1 | Hard | New module with full pipeline |
| H2 | Hard | Cross-module refactor |
| H3 | Hard | Multi-file feature implementation |

## Usage

```
tri dev arena list          # List all tasks
tri dev arena run E1        # Run single task
tri dev arena run all       # Run all tasks
tri dev arena compare       # Compare results
```

## Scoring

- solve_rate = tasks_solved / total_tasks
- Ranked by: solve_rate > avg_time > avg_cost
