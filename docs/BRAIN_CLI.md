# S3AI Brain CLI Documentation

**Version:** v5.1.0-igla-ready
**Last Updated:** 2026-03-20

## Overview

The S3AI (Sacred Symbolic Self-Improving AI) Brain is a neuroanatomy-inspired system for autonomous agent swarm coordination. This document provides comprehensive CLI documentation for all brain-related commands.

**Sacred Formula:** phi^2 + 1/phi^2 = 3 = TRINITY

---

## Quick Start

```bash
# Show all brain commands
tri brain --help

# Check brain alerts
tri brain --alerts list

# Run a smoke test simulation
tri brain simulate smoke

# View brain visualization dashboard
tri brain --viz preset
```

---

## Command Reference

### `tri brain --alerts [list|stats|check|test]`

Brain alerts system for monitoring critical health states and sending notifications when thresholds are crossed.

#### Subcommands

##### `tri brain --alerts list [--level <LVL>] [--n <N>]`

List recent brain alerts with optional filtering.

**Parameters:**
- `--level <LVL>` - Filter by alert level: `info`, `warning`, `critical`
- `--n <N>` - Number of recent alerts to show (default: 10)

**Output Format:**
```
Recent Alerts (5):
  1. [CRIT] [Health Low] Brain health below threshold (Basal Ganglia)
  2. [WARN] [Events Buffered] Event buffer filling up (Reticular Formation)
  3. [INFO] [Region Unavailable] Thalamus logs disconnected
  ...
```

**Alert Levels:**
- `[INFO]` - Informational: system is working as expected
- `[WARN]` - Warning: attention needed but system is functional
- `[CRIT]` - Critical: immediate action required

**Examples:**
```bash
# List last 10 alerts
tri brain --alerts list

# List only critical alerts
tri brain --alerts list --level critical

# List last 50 warnings
tri brain --alerts list --level warning --n 50
```

---

##### `tri brain --alerts stats`

Show alert statistics and summary information.

**Output Format:**
```
Alert Statistics:
  Total alerts: 127
  By level:
    INFO: 85
    WARN: 32
    CRITICAL: 10
  Active: 5
  Resolved: 122
```

**Examples:**
```bash
tri brain --alerts stats
```

---

##### `tri brain --alerts check [--health <H>] [--events <E>] [--claims <C>]`

Check brain health and trigger alerts based on current metrics.

**Parameters:**
- `--health <H>` - Health score (0-100, default: 100.0)
- `--events <E>` - Number of buffered events (default: auto-detected)
- `--claims <C>` - Number of active task claims (default: auto-detected)

**Output Format:**
```
Checking brain health: health=85.0, events=1200, claims=4500

[WARN] Health Low: Brain health below warning threshold (80.0)
[WARN] Events Buffered: Event buffer above warning threshold (1000)

Health check complete
Run 'tri brain --alerts list' to see any generated alerts
```

**Alert Thresholds:**
| Condition | Warning | Critical |
|-----------|---------|----------|
| Health | < 80.0 | < 50.0 |
| Events Buffered | > 1000 | > 5000 |
| Claims Overflow | > 5000 | > 10000 |

**Examples:**
```bash
# Auto-detect metrics from global brain state
tri brain --alerts check

# Manually specify metrics for testing
tri brain --alerts check --health 45.0 --events 6000 --claims 12000
```

---

##### `tri brain --alerts test`

Generate test alerts at all levels to verify the alert system is working.

**Output Format:**
```
Generating test alerts...

[CRIT] Health Low: Critical health threshold breached
[CRIT] Events Buffered: Event buffer critical
[CRIT] Claims Overflow: Task claims at critical capacity

Generated test alerts
Run 'tri brain --alerts list' to view them
```

**Examples:**
```bash
tri brain --alerts test
```

---

### `tri brain simulate [smoke|competition|storm|partition|crash] [--json]`

Run realistic workload simulations to validate brain circuit behavior.

#### Scenarios

##### `tri brain simulate smoke`

Quick smoke test with 10 agents and 100 tasks.

**Purpose:** Fast validation of basic brain circuit functionality.

**Output Format:**
```
S3AI BRAIN SIMULATION — Smoke Test

Configuration:
  Agents: 10
  Tasks: 100
  Duration: 5000ms

Results:
  Tasks completed: 100/100
  Success rate: 100.0%
  Avg task duration: 45.2ms
  Health score: 95.0/100
```

**Examples:**
```bash
tri brain simulate smoke
tri brain simulate smoke --json
```

---

##### `tri brain simulate competition`

Simulate 100 agents competing for 1000 tasks.

**Purpose:** Test action selection under high contention.

**Output Format:**
```
S3AI BRAIN SIMULATION — Agent Competition

Configuration:
  Agents: 100
  Tasks: 1000
  Contention: High

Results:
  Tasks completed: 987/1000
  Success rate: 98.7%
  Claims denied: 23
  Health score: 82.0/100
```

**Examples:**
```bash
tri brain simulate competition
tri brain simulate competition --json
```

---

##### `tri brain simulate storm`

Event storm simulation with 1000 events/second.

**Purpose:** Test event bus throughput and buffer management.

**Output Format:**
```
S3AI BRAIN SIMULATION — Event Storm

Configuration:
  Event rate: 1000 events/sec
  Duration: 10s
  Total events: 10000

Results:
  Events published: 10000
  Events processed: 9987
  Events dropped: 13
  Buffer overflow: 0
  Health score: 78.5/100
```

**Examples:**
```bash
tri brain simulate storm
tri brain simulate storm --json
```

---

##### `tri brain simulate partition`

Network partition simulation.

**Purpose:** Test brain resilience to network failures.

**Output Format:**
```
S3AI BRAIN SIMULATION — Network Partition

Configuration:
  Partition duration: 5000ms
  Affected regions: 3

Results:
  Dropped messages: 127
  Recovery time: 234ms
  Claims orphaned: 5
  Health score: 65.0/100
```

**Examples:**
```bash
tri brain simulate partition
tri brain simulate partition --json
```

---

##### `tri brain simulate crash`

Agent crash simulation.

**Purpose:** Test brain recovery from agent failures.

**Output Format:**
```
S3AI BRAIN SIMULATION — Agent Crash

Configuration:
  Agents to crash: 5 (random)
  Crash timing: Mid-simulation

Results:
  Agents crashed: 5
  Claims recovered: 42
  Claims lost: 3
  Recovery time: 156ms
  Health score: 72.0/100
```

**Examples:**
```bash
tri brain simulate crash
tri brain simulate crash --json
```

---

#### JSON Output Format

When `--json` is specified, all simulations output structured JSON:

```json
{
  "scenario": "smoke",
  "timestamp": 1710892800000,
  "config": {
    "agents": 10,
    "tasks": 100,
    "duration_ms": 5000
  },
  "results": {
    "tasks_completed": 100,
    "success_rate": 100.0,
    "avg_duration_ms": 45.2,
    "health_score": 95.0
  }
}
```

---

### `tri brain --viz [map|sparkline|connections|heatmap|3d|preset]`

Brain visualizations using ASCII art and terminal colors.

#### Visualization Modes

##### `tri brain --viz map`

ASCII brain map with color-coded regions.

**Output Format:**
```
                    Thalamus
                    [95%]
                       |
          Basal Ganglia---Reticular Formation
            [88%]            [92%]
```

**Color Legend:**
- Green - Healthy (>= 80%)
- Yellow - Warning (50-79%)
- Red - Critical (< 50%)

**Examples:**
```bash
tri brain --viz map
```

---

##### `tri brain --viz sparkline`

Health trend sparkline showing brain health over time.

**Output Format:**
```
Brain Health (last 10 checks)
82%  84%  83%  86%  88%  87%  89%  91%  90%  88%
```

**Examples:**
```bash
tri brain --viz sparkline
```

---

##### `tri brain --viz connections`

Region connection diagram showing inter-region dependencies.

**Output Format:**
```
Thalamus --[0.9]--> Prefrontal Cortex
    ^                     |
    |[0.8]              [0.7]
    |                     v
Basal Ganglia <--[0.8]-- Reticular Formation
```

**Connection strength:**
- 0.9-1.0: Strong connection
- 0.7-0.9: Normal connection
- < 0.7: Weak connection

**Examples:**
```bash
tri brain --viz connections
```

---

##### `tri brain --viz heatmap`

Real-time activity heatmap showing which brain regions are most active.

**Output Format:**
```
Activity Heatmap
  0%                    50%                   100%
  |---------------------|---------------------|
BG [████████████████░░░░] 80%
RF [██████████████████░░] 90%
TH [███████████████░░░░░] 75%
```

**Examples:**
```bash
tri brain --viz heatmap
```

---

##### `tri brain --viz 3d`

Text-based 3D brain visualization.

**Output Format:**
```
       /-----------\
     /   Thalamus    \
   /-------------------\
  |  BG      [88%]  RF  |
   \-------------------/
     \_______________/
```

**Examples:**
```bash
tri brain --viz 3d
```

---

##### `tri brain --viz preset`

Predefined visualization dashboard (default when no mode specified).

**Output Format:**
```
╔════════════════════════════════════════╗
║     S3AI BRAIN DASHBOARD v5.1         ║
╠════════════════════════════════════════╣
║ Overall Health: 88/100                 ║
║ Active Claims: 4,521                   ║
║ Buffered Events: 1,234                 ║
╠════════════════════════════════════════╣
║ [ASCII brain map]                      ║
║ [sparkline]                            ║
║ [connection diagram]                   ║
╚════════════════════════════════════════╝
```

**Examples:**
```bash
# Default mode
tri brain --viz

# Explicit preset
tri brain --viz preset
```

---

## Troubleshooting

### "Brain state recovery module not implemented yet"

The default `tri brain` command without subcommands currently shows this message. Use one of the documented subcommands instead:

```bash
# Instead of:
tri brain

# Use:
tri brain --alerts list
tri brain simulate smoke
tri brain --viz preset
```

### No alerts found

If `tri brain --alerts list` returns "No alerts found", the alert log may be empty. Generate test alerts:

```bash
tri brain --alerts test
tri brain --alerts list
```

### Permission denied on alerts log

Alerts are stored in `.trinity/brain_alerts.jsonl`. Ensure you have write permissions:

```bash
ls -la .trinity/brain_alerts.jsonl
```

### Visualization colors not showing

Ensure your terminal supports ANSI color codes. Try:

```bash
# Test color support
echo -e "\x1b[31mRed text\x1b[0m"

# If colors don't show, try a different terminal
```

### Simulation returns errors

Simulations require global brain regions to be initialized. If you see errors:

1. Check that brain modules are compiled: `zig build tri`
2. Verify global instances exist for basal_ganglia, reticular_formation, and locus_coeruleus
3. Try the smoke test first (lightest workload)

---

## Brain Region Reference

The S3AI Brain consists of 20+ neuroanatomy-inspired regions:

| Region | Function | CLI Integration |
|--------|----------|-----------------|
| Basal Ganglia | Action Selection (Task Claim Registry) | Simulations |
| Reticular Formation | Broadcast Alerting (Event Bus) | Simulations |
| Locus Coeruleus | Arousal Regulation (Backoff Policy) | Simulations |
| Hippocampus | Memory Persistence (JSONL Logging) | Alerts logging |
| Amygdala | Emotional Salience | Alert prioritization |
| Prefrontal Cortex | Executive Function | Decision making |
| Thalamus | Sensory Relay | Railway logs |
| Microglia | Immune Surveillance | Pruning/health |
| Cerebellum | Motor Learning | Performance patterns |
| Corpus Callosum | Inter-Hemispheric | Federation/coordination |
| Visual Cortex | Spatial Representation | All `--viz` commands |
| Alerts | Critical Health Notification | All `--alerts` commands |
| Simulation | Synthetic Workload Testing | All `simulate` commands |

For full API documentation, see `docs/BRAIN_API.md`.

---

## See Also

- `docs/BRAIN_ARCHITECTURE.md` - Overall brain architecture
- `docs/BRAIN_API.md` - Complete API reference
- `docs/BRAIN_ATLAS.md` - Detailed region descriptions
- `docs/PERFORMANCE.md` - Performance metrics and benchmarks
