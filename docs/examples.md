# Trinity Queen — Usage Examples

## Basic Queen Cycle Output

### One-Shot Cycle

```bash
$ tri queen once
```

**Output:**
```
👑 Queen NORMAL — Cycle #1

🧬 Farm: 45/108 active, PPL 4.6 (R33)
🧠 Build: OK | Wake #1524
No action needed
```

### With Decision

```
👑 Queen ALERT — Cycle #2

🧬 Farm: 40/108 active, PPL 4.6 (R33)
🧠 Build: OK | Wake #1525
🔧 Action: farm recycle (Farm has idle/crashed workers ▼)
  Result: OK (1842ms)
```

### With Trend Analysis

```
👑 Queen ALARM — Cycle #3

🧬 Farm: 35/108 active, PPL 5.2 (R45)
🧠 Build: FAIL | Wake #1526
🔧 Action: doctor quick (Build broken, needs healing 🚨)
  Result: OK (523ms)
```

## Auto-Healing Scenario

### Initial State (Mass Crash)

```
Cycle #10: 🚨 ALARM
Farm: 12/108 active (86 crashed!)
Build: OK
Action: farm_recycle → User approval required
```

### User Approval

```bash
# Via Telegram
/queen approve

# Or via CLI
tri queen approve --cycle 10
```

### Recovery Sequence

```
Cycle #11: 🔧 ACTING
Farm: 12/108 → 45/108 (recycled 33 idle)
Build: OK
Action: farm_recycle → OK

Cycle #12: ✅ STABLE
Farm: 78/108 active
Build: OK
Action: None (system healthy)
```

## GitHub Issue Creation Flow

### Trigger: Blocked Issue Detected

```
Cycle #25: 🛑 BLOCKED
Issue: #357 (Training farm tracker)
Blocked: 3 days
Action: issue_comment → OK
```

### Auto-Comment Posted

```markdown
@issue-title Farm health declining

📊 Status:
- Active: 45/108 (was 78/108)
- PPL: 5.2 (↑ from 4.6)
- Crashed: 12

🤖 Queen suggests: `tri farm recycle --idle-only`
```

### Follow-Up Issue Created (if critical)

```
Cycle #26: 📋 NEW ISSUE
Created: #420 "Farm mass crash - needs investigation"
Labels: agent:spawn, priority:critical
```

## Telegram Command Reference

### Basic Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/status` | Show current Queen state | `/status` |
| `/cycle` | Force immediate cycle | `/cycle` |
| `/approve` | Approve pending L2 action | `/approve` |
| `/deny` | Deny pending action | `/deny` |
| `/config` | Show current config | `/config` |

### Query Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/farm` | Show farm status | `/farm` |
| `/build` | Show build health | `/build` |
| `/memory` | Show memory usage | `/memory` |
| `/issues` | List open issues | `/issues` |
| `/arena` | Show arena status | `/arena` |

### Advanced Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/god` | Enable god mode | `/god` (requires confirmation) |
| `/sleep` | Enter sleep mode | `/sleep` |
| `/wake` | Exit sleep mode | `/wake` |
| `/audit` | Show audit trail | `/audit` |

### Telegram Message Format

**Heartbeat (hourly):**
```
👑 Queen NORMAL — Hourly Heartbeat

📊 Ouroboros: 67.2 (↑ 2.1)
🧬 Farm: 78/108 active, PPL 4.6
🧠 Build: OK (92% test rate)
📝 Dirty: 12 files
🤖 Agents: 8 alive
⏰ Uptime: 5h 23m
```

**Alert (instant):**
```
🚨 BUILD BROKEN

zig build failed with 3 errors
Channel: #trinity-builds
Action: doctor_quick (auto-approved)
```

**Daily Summary:**
```
📊 Daily Summary — 2026-03-19

Cycles: 144 (24h)
Actions: 12 (8 auto-approved)
Decisions: farm_recycle×3, doctor_quick×5, notify×4
Best PPL: 4.2 (R33)
Build failures: 2 (both healed)
```

## Daemon Mode

### Start Daemon

```bash
# 5-minute cycles, auto-actions L1 only
tri queen start --daemon --interval 300

# Full auto (L2 actions, no approval needed)
tri queen start --daemon --interval 300 --allow-auto-actions --max-level 2 --no-approval
```

### Stop Daemon

```bash
# Graceful shutdown
tri queen stop

# Force kill
tri queen kill
```

### Check Daemon Status

```bash
$ tri queen status
```

**Output:**
```
👑 Queen Daemon Status

PID: 15234
Uptime: 5h 23m
Cycles: 144
Last cycle: 2m ago
Mode: AUTO (L2 enabled)
State: RUNNING
```

## Insula Metrics Output

### Internal State Display

```bash
$ tri queen insula
```

**Output:**
```
🧠 Insula — Interoception Report

Timing:
  Cycle latency: 125ms ✓
  Thalamus: 45ms ✓
  DLPFC decision: 32ms ✓

Memory:
  Allocated: 45.2MB / 75MB
  Alloc count: 1,234

Activity:
  Actions taken: 12 (8.3% rate)
  Actions suppressed: 3

Status: HEALTHY
```

### Insula Alert

```
🚨 INSULA ALERT

Memory pressure detected: 82MB > 75MB threshold
Suggested: tri memory gc
Locus Coeruleus: EMERGENCY
```

## Troubleshooting

### Queen Not Responding

```bash
# Check if daemon is running
tri queen status

# If stuck, force restart
tri queen kill
tri queen start --daemon
```

### High Memory Usage

```bash
# Check Insula metrics
tri queen insula

# Run garbage collection
tri memory gc --agent queen

# If still high, restart
tri queen restart
```

### Build Loop (doctor_quick keeps failing)

```bash
# Check failure count
tri queen audit | grep doctor_quick

# If >3 failures, manual intervention needed
tri doctor heal --manual
```

## φ² + 1/φ² = 3 = TRINITY

All examples follow the READ → THINK → ACT → SPEAK cycle:
- **READ**: Thalamus collects 18 senses
- **THINK**: DLPFC decides action
- **ACT**: Motor executes command
- **SPEAK**: OFC formats report
