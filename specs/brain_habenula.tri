# tri brain habenula — Anti-Corruption

## Module
tri.brain.habenula

## Description
Epithalamus structure. Detects unfair reward distribution (corruption signal).

## Subcommand
`tri brain habenula unfair-detect`

## Neuroanatomy
Habenula — encodes negative reward prediction errors.

## Structs
### Unfairness
enum { FAIR, SUSPICIOUS, CORRUPTED }

### Reward
- agent_id: []const u8
- amount: f64
- proof: []const u8

### Effort
- agent_id: []const u8
- steps_completed: u32
- time_spent_ms: u64
- complexity_score: f32

## Functions
### unfairDetect(reward, effort) !Unfairness
Detect if reward ≠ expected effort.

### cmdUnfairDetect(args) !u8
Scan rewards, flag anomalies.

## Thresholds
CORRUPTION_THRESHOLD: 1.0 (100% deviation)
SUSPICION_THRESHOLD: 0.5 (50% deviation)
ALPHA: 0.1 (smoothing)
