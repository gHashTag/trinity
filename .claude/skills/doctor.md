# Doctor Daemon — Health Monitor & Watchdog

Doctor daemon monitors Queen process health and automatically applies treatments when issues are detected.

## Commands

```bash
# Start doctor daemon
tri doctor start [--daemon] [--interval <sec>] [--verbose]

# Stop doctor daemon
tri doctor stop

# Show current health status
tri doctor status

# Run one-time diagnosis
tri doctor diagnose [--dry-run] [--verbose]

# Show treatment history
tri doctor history

# Show help
tri doctor help
```

## Diagnoses & Treatments

| Diagnosis | Detection | Treatment | Auto-applied |
|-----------|-----------|-----------|---------------|
| `dead` | PID not running | `restart` | ✅ |
| `crash_loop` | launcher.err > 512KB | `purge_logs → restart` | ✅ |
| `stuck` | heartbeat > 60s | `reset_state → restart` | ✅ |
| `memory_leak` | RSS > 512MB | `kill_and_restart` | ✅ |
| `log_overflow` | .err > 256KB | `purge_logs` | ✅ |
| `healthy` | all checks passed | `none` | - |

## Files

| Path | Purpose |
|------|---------|
| `.trinity/doctor/doctor.pid` | Doctor daemon PID |
| `.trinity/doctor/doctor.log` | Treatment history log |
| `.trinity/queen/heartbeat` | Queen heartbeat timestamp |
| `.trinity/queen/supervisor.pid` | Queen PID |
| `.trinity/queen/launcher.err` | Queen error log |

## Integration Points

### Queen Heartbeat
Queen writes heartbeat after each Lotus Cycle phase:
```zig
fn writeHeartbeat() !void {
    const f = try std.fs.cwd().createFile(".trinity/queen/heartbeat", .{});
    defer f.close();
    try f.writer().print("{d}\n", .{std.time.milliTimestamp()});
}
```

### Log Format
```
<TIMESTAMP> DIAGNOSIS: <diagnosis> TREATMENT: <treatment> REASON: <reason>
<TIMESTAMP> TREATMENT: <action>
<TIMESTAMP> TREATMENT_APPLIED: <treatment>
```

## Launchd Integration

```bash
# Load daemon
launchctl bootstrap gui/$(id -u)/~/Library/LaunchAgents/com.trinity.doctor.plist

# Unload daemon
launchctl bootout gui/$(id -u)/com.trinity.doctor

# Check status
launchctl list | grep com.trinity.doctor
```

## Development

Source files:
- `src/tri/doctor/doctor_types.zig` — Types, constants, configuration
- `src/tri/doctor/doctor_cli.zig` — CLI router
- `src/tri/doctor/doctor.zig` — Core logic (health check, diagnose, treat)

Build:
```bash
zig build tri
./zig-out/bin/tri doctor status
```
