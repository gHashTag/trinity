# Trinity Eternal Monitor — Quick Reference

## TL;DR

```bash
# Start monitoring
./scripts/eternal_monitor.sh start

# Check status
./scripts/eternal_monitor.sh status

# View logs
./scripts/eternal_monitor.sh logs

# Stop monitoring
./scripts/eternal_monitor.sh stop
```

## Status: ✅ OPERATIONAL

- **Location**: `/Users/playra/trinity-w1/src/tri/eternal_monitor.zig`
- **PID File**: `/tmp/trinity-eternal-monitor.pid`
- **Log File**: `~/.trinity/eternal-monitor.log`
- **Interval**: φ = 1.618 seconds
- **Memory**: ~1.5 MB
- **CPU**: < 1%

## Commands

### Manager Script (`./scripts/eternal_monitor.sh`)

| Command | Action |
|---------|--------|
| `start` | Start eternal monitoring daemon |
| `stop` | Stop monitoring gracefully |
| `restart` | Restart monitoring |
| `status` | Show PID, uptime, memory, health |
| `logs` | Tail log file (Ctrl+C to exit) |
| `health` | One-time health check |
| `alerts` | Show recent alerts |
| `help` | Show help message |

### Direct CLI (`./zig-out/bin/tri monitor`)

| Command | Action |
|---------|--------|
| `--eternal` | Run forever (Ctrl+C to stop) |
| `--health` | One-time health check |
| `--alerts` | Show recent alerts |
| `-v, --verbose` | Enable verbose output |
| `--no-heal` | Disable auto-healing |

## Components Monitored

- ✅ Memory
- ✅ CPU
- ✅ Disk
- ✅ VSA System
- ✅ VM System
- ✅ Firebird LLM

## Sacred Metrics

| Metric | Formula | Ideal |
|--------|---------|-------|
| Sacred Ratio | failures/checks | < 0.0618 (χ) |
| Overall Health | healthy/total | 100% |
| Response Time | avg check | < 10ms |

## Alert Levels

| Severity | Color | Trigger |
|----------|-------|---------|
| Info | Cyan | Auto-heal attempts |
| Warning | Yellow | Slow response (>10ms) |
| Error | Red | Health check failed |
| Critical | Magenta | 3/3 retries failed |

## Example Output

```
╔════════════════════════════════════════════════════════════╗
║            TRINITY ETERNAL MONITOR — φ² + 1/φ² = 3         ║
╠════════════════════════════════════════════════════════════╣
║ Uptime:   11.3s  │  Checks:     8  │  Sacred Ratio: 0.0000 ║
╠════════════════════════════════════════════════════════════╣
║ ✓ Memory                 +0ms  [ 0/ 3 failures]           ║
║ ✓ CPU                    +0ms  [ 0/ 3 failures]           ║
║ ✓ Disk                   +0ms  [ 0/ 3 failures]           ║
║ ✓ VSA System             +0ms  [ 0/ 3 failures]           ║
║ ✓ VM System              +0ms  [ 0/ 3 failures]           ║
║ ✓ Firebird LLM           +0ms  [ 0/ 3 failures]           ║
╠════════════════════════════════════════════════════════════╣
║ Recent Alerts (0/0):                                    ║
║ No alerts — System in perfect harmony                      ║
╚════════════════════════════════════════════════════════════╝
```

## Troubleshooting

### Monitor won't start
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

### High failure rate
```bash
# Check alerts
./zig-out/bin/tri monitor --alerts

# View logs
tail -100 ~/.trinity/eternal-monitor.log
```

## Documentation

- **User Guide**: `/Users/playra/trinity-w1/docs/ETERNAL_MONITOR.md`
- **Implementation**: `/Users/playra/trinity-w1/docs/ETERNAL_MONITOR_SUMMARY.md`
- **Source Code**: `/Users/playra/trinity-w1/src/tri/eternal_monitor.zig`

---

**φ² + 1/φ² = 3 = TRINITY**
