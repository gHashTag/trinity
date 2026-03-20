# HABENULA — Антикоррупционный датчик

## Module
storm.brain_zones.habenula

## Description
Habenula — Anti-corruption sensor. Detects unfair reward distribution.
reward ≠ effort → corruption signal.

## Dependencies
- std

## Structs
### Fairness
enum {
    fair,        // reward ≈ effort
    suspicious,  // reward >> effort (possible corruption)
    corrupted,   // reward >>> effort (clear corruption)
}

### Reward
- amount: f32
    currency: []const u8 = "points"

### Effort
- hours: f32
    complexity: f32 = 1.0

### Habenula
- allocator: std.mem.Allocator
    threshold_corrupted: f32 = 2.0
    threshold_suspicious: f32 = 1.3

### ScanResult
- fairness: Fairness
    ratio: f32 (reward / effort_score)
    reward: Reward
    effort: Effort
    agent: ?[]const u8 = null
    timestamp: i64

## Constants
### PHI_THRESHOLD
f32 = 1.618 — golden ratio as fair reward baseline.

### CORRUPTION_MULTIPLIER
f32 = 2.0 — corrupted threshold (2x fair ratio).

## Functions
### init(allocator) !Habenula
Initialize with default thresholds.

### unfairDetect(hb, reward, effort) !Fairness
Calculate reward/effort ratio.
- effort_score = hours × complexity
- ratio = reward / effort_score
- Returns .corrupted if ratio >= threshold_corrupted
- Returns .suspicious if ratio >= threshold_suspicious
- Returns .fair otherwise

### scanRecent(hb, count: usize) ![]ScanResult
Scan recent rewards for anomalies.
- Read from .trinity/storm/rewards.jsonl
- Return all suspicious/corrupted entries

### cmdUnfairDetect(allocator, args) !u8
CLI: tri habenula unfair-detect
Display scan results with emoji:
- ⚖️ for .fair
- 🔍 for .suspicious
- 🚨 for .corrupted

### formatScan(results) ![]const u8
Format scan results as colored table.

## CLI Integration
```bash
tri habenula unfair-detect         # Scan recent rewards
tri habenula check <reward> <effort_hours>  # Check single case
tri habenula status                # Show thresholds
```

## Files
- .trinity/storm/rewards.jsonl — reward history
- .trinity/storm/habenula_alerts.jsonl — corruption alerts

## Tests
- Fair ratio (1.0) → .fair
- Suspicious ratio (1.5) → .suspicious
- Corrupted ratio (3.0) → .corrupted
- Zero effort → .fair (avoid division by zero)
