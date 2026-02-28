# Trinity Eternal Monitoring System

**φ-based 24/7 monitoring for Trinity infrastructure**

## Overview

The Eternal Monitor provides continuous health monitoring for all Trinity components using sacred φ-based intervals (1.618 seconds). It auto-heals degraded services and provides real-time alerts.

## Quick Start

### Start Monitoring

```bash
# Start eternal monitoring (background daemon)
./scripts/eternal_monitor.sh start

# Check status
./scripts/eternal_monitor.sh status

# View live logs
./scripts/eternal_monitor.sh logs
```

### Stop Monitoring

```bash
# Graceful shutdown
./scripts/eternal_monitor.sh stop

# Or force kill
./scripts/eternal_monitor.sh stop
```

### One-Time Health Check

```bash
# Run health check (no monitoring)
./zig-out/bin/tri monitor --health

# View recent alerts
./zig-out/bin/tri monitor --alerts
```

## Commands

### Manager Script (`./scripts/eternal_monitor.sh`)

| Command | Description |
|---------|-------------|
| `start` | Start eternal monitoring (default) |
| `stop` | Stop monitoring gracefully |
| `restart` | Restart monitoring |
| `status` | Show detailed status with health check |
| `logs` | View live logs (tail -f) |
| `health` | Run one-time health check |
| `alerts` | Show recent alerts |
| `help` | Show help message |

### Direct CLI (`./zig-out/bin/tri monitor`)

| Command | Description |
|---------|-------------|
| `--eternal` | Run monitoring forever (until Ctrl+C) |
| `--health` | One-time health check (default) |
| `--alerts` | Display recent alerts |
| `-v, --verbose` | Enable verbose output |
| `--no-heal` | Disable auto-healing |

## Monitoring Components

The monitor tracks 6 core components:

| Component | Health Check |
|-----------|--------------|
| **Memory** | Available RAM |
| **CPU** | Processor load |
| **Disk** | Storage space |
| **VSA System** | Vector Symbolic Architecture integrity |
| **VM System** | Ternary Virtual Machine state |
| **Firebird LLM** | LLM engine availability |

## Sacred Mathematics

### Monitoring Interval

```
φ = 1.6180339887498948482
Monitor checks every φ seconds (1.618s)
```

### Health Metrics

| Metric | Formula | Threshold |
|--------|---------|-----------|
| **Sacred Ratio** | failures / checks | < 0.0618 (χ) ideal |
| **Overall Health** | healthy / total | 100% target |
| **Response Time** | avg component check time | < 10ms alert |

### Alert Levels

| Severity | Color | Trigger |
|----------|-------|---------|
| Info | Cyan | Auto-heal attempts |
| Warning | Yellow | Slow responses (>10ms) |
| Error | Red | Health check failure |
| Critical | Magenta | Max retries exceeded |

## Auto-Healing

When a component fails:
1. Increment failure counter
2. Attempt auto-heal after φ/2 second wait
3. Retry health check
4. If failed 3+ times → Critical alert

## Log Files

| Location | Purpose |
|----------|---------|
| `~/.trinity/eternal-monitor.log` | Full monitoring output |
| `/tmp/trinity-eternal-monitor.pid` | Process ID file |

## Examples

### Basic Monitoring

```bash
# Start in background
./scripts/eternal_monitor.sh start

# Check if running
./scripts/eternal_monitor.sh status

# View real-time logs
./scripts/eternal_monitor.sh logs
```

### Foreground Monitoring

```bash
# Run in foreground (Ctrl+C to stop)
./zig-out/bin/tri monitor --eternal

# With verbose output
./zig-out/bin/tri monitor --eternal --verbose
```

### Health Checks

```bash
# One-time health check
./zig-out/bin/tri monitor --health

# Show last 20 alerts
./zig-out/bin/tri monitor --alerts

# Via manager script
./scripts/eternal_monitor.sh health
./scripts/eternal_monitor.sh alerts
```

### Production Deployment

```bash
# 1. Build release binary
zig build tri

# 2. Start monitoring
./scripts/eternal_monitor.sh start

# 3. Verify status
./scripts/eternal_monitor.sh status

# 4. Set up log rotation (optional)
logrotate -f /etc/logrotate.d/trinity-monitor
```

## Status Display

### Eternal Mode (Continuous)

```
╔════════════════════════════════════════════════════════════╗
║            TRINITY ETERNAL MONITOR — φ² + 1/φ² = 3         ║
╠════════════════════════════════════════════════════════════╣
║ Uptime:  360.5s  │  Checks:   223  │  Sacred Ratio: 0.0045 ║
╠════════════════════════════════════════════════════════════╣
║ ✓ Memory                0ms  [0/3 failures]               ║
║ ✓ CPU                   1ms  [0/3 failures]               ║
║ ✓ Disk                  0ms  [0/3 failures]               ║
║ ✓ VSA System            2ms  [0/3 failures]               ║
║ ✓ VM System             1ms  [0/3 failures]               ║
║ ✓ Firebird LLM          3ms  [0/3 failures]               ║
╠════════════════════════════════════════════════════════════╣
║ Recent Alerts (2/2):                                        ║
║ [123.456][Memory] Attempting auto-heal for Memory          ║
║ [124.123][CPU] Slow response: 15ms                         ║
╚════════════════════════════════════════════════════════════╝
```

### Health Report (One-Time)

```
╔══════════════════════════════════════════════════════╗
║          TRINITY HEALTH REPORT — φ Balance         ║
╚══════════════════════════════════════════════════════╝

✓ Memory —   0ms | Failures: 0/3
✓ CPU —    1ms | Failures: 0/3
✓ Disk —   0ms | Failures: 0/3
✓ VSA System —  2ms | Failures: 0/3
✓ VM System —   1ms | Failures: 0/3
✓ Firebird LLM — 3ms | Failures: 0/3

Summary: 6 Healthy, 0 Degraded, 0 Failed
Overall Health: 100.0%

Sacred Metrics:
  φ Interval:  1.618s
  Uptime:      360.5s
  Checks:      223
  Avg Response: 1.17ms
  Sacred Ratio: 0.0045 (closer to 0 = better)

✓ System in perfect harmony (ratio < χ = 0.0618)
```

## Troubleshooting

### Monitor Won't Start

```bash
# Check if already running
cat /tmp/trinity-eternal-monitor.pid
ps aux | grep "tri monitor"

# Force stop if needed
kill -9 $(cat /tmp/trinity-eternal-monitor.pid)
rm /tmp/trinity-eternal-monitor.pid

# Try again
./scripts/eternal_monitor.sh start
```

### High Failure Rate

```bash
# Check alerts
./zig-out/bin/tri monitor --alerts

# View logs
tail -100 ~/.trinity/eternal-monitor.log

# Check individual component
./zig-out/bin/tri monitor --health
```

### Monitor Not Responding

```bash
# Check process status
cat /tmp/trinity-eternal-monitor.pid
ps -p $(cat /tmp/trinity-eternal-monitor.pid) -o pid,etime,cmd

# Restart if needed
./scripts/eternal_monitor.sh restart
```

## Configuration

Edit `src/tri/eternal_monitor.zig` to customize:

```zig
pub const Config = struct {
    interval_ms: u64 = 1618,           // φ seconds in ms
    health_timeout_ms: u64 = 5000,     // Health check timeout
    alert_threshold_ms: u64 = 10000,   // Slow response alert
    max_retries: u32 = 3,              // Auto-heal attempts
    auto_heal: bool = true,            // Enable auto-healing
    verbose: bool = false,             // Verbose logging
};
```

Rebuild after changes:

```bash
zig build tri
./scripts/eternal_monitor.sh restart
```

## Integration

### With TRI Dashboard

The Eternal Monitor integrates with the TRI Canvas Mirror dashboard:

- **RAZUM (Gold)**: Routing decisions, intelligence logs
- **MATERIYA (Cyan)**: Infrastructure health, storage metrics
- **DUKH (Purple)**: Alert actions, heal operations

### With Ralph

Ralph autonomous development consults monitor data:

```bash
# Ralph checks health before builds
ralph --monitor

# Auto-triggered on threshold breach
Sacred Ratio > ε → Ralph pauses builds
```

## Advanced Usage

### Custom Health Checks

Add custom components in `eternal_monitor.zig`:

```zig
fn checkCustomService(allocator: std.mem.Allocator) !HealthStatus {
    // Your check logic here
    return .healthy;
}

// Register in createDefaultMonitor()
try monitor.registerComponent(SystemComponent.init(
    "Custom Service",
    checkCustomService
));
```

### Alert Webhooks

Extend `addAlert()` to send webhooks:

```zig
try sendWebhook(alert);
```

### Metrics Export

Export metrics for Prometheus/Grafana:

```zig
fn exportMetrics(metrics: Metrics) !void {
    // Write to /metrics endpoint
}
```

## φ-Based Scheduling

The monitor uses φ for timing:

| Operation | Duration |
|-----------|----------|
| Check interval | φ = 1.618s |
| Auto-heal wait | φ/2 = 0.809s |
| Alert threshold | φ×6 = 9.708s |

This creates sacred harmonic resonance in the monitoring cycle.

## License

MIT License — Part of Trinity Project

## References

- `/Users/playra/trinity-w1/src/tri/eternal_monitor.zig` — Core implementation
- `/Users/playra/trinity-w1/src/tri/main.zig` — CLI integration
- `/Users/playra/trinity-w1/scripts/eternal_monitor.sh` — Manager script
- `CLAUDE.md` — TRI CLI documentation

---

**φ² + 1/φ² = 3 = TRINITY**
